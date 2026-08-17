// Background Service orchestrator. Runs in a separate heap from the foreground app.
// Only one Background.exit() call per execution path — it terminates the service.
// (:background) annotation: only this class loads in the background process.
using Toybox.Application;
using Toybox.Background;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time;

(:background)
class BmwWidgetServiceDelegate extends System.ServiceDelegate {

    var _tokenManager;
    var _carDataClient;

    function initialize() {
        ServiceDelegate.initialize();
        _tokenManager = new TokenManager();
        _carDataClient = new CarDataClient();
    }

    function onTemporalEvent() {
        // Tier-split scheduling: re-register the manual daily event and/or gate the
        // adaptive tick. Returns false when this tick must skip (adaptive off-hours).
        if (!_rescheduleAndGate()) {
            Background.exit(null);
            return;
        }

        // Steady-state poll ONLY. Bootstrap (VIN discovery, container create/list,
        // basicData) is the foreground's job (ForegroundSync) — keeping that heavy
        // code path unreachable from the background process so its code image stays
        // small and the telematicData response can fit the ~28 KB background heap.
        // (The background -403 NETWORK_RESPONSE_OUT_OF_MEMORY was the response not
        // fitting alongside the loaded bg code.) If setup hasn't happened yet, exit;
        // opening the app once bootstraps and every later poll just refreshes.
        if (_resolveVin() == null || _resolveContainer() == null) {
            Background.exit(null);
            return;
        }
        _runPollCycle();
    }

    // TIER SPLIT: exactly one variant survives each device build (see monkey.jungle).
    //
    // Full tier (API 6.0+): FR-25 — manual mode's daily 10:00 event is Moment-based,
    // hence one-shot; re-register tomorrow's 10:00 immediately so the daily cadence
    // continues without requiring the user to reopen the app. Adaptive mode (2) fires
    // every 30 min but should only fetch at chosen hours; returning false skips
    // ticks that don't match the schedule to conserve quota/battery.
    (:bgPoll)
    function _rescheduleAndGate() {
        var mode = Application.Properties.getValue("updateMode");
        if (mode == null || mode == 0) {
            try {
                Background.registerForTemporalEvent(BmwWidgetApp._nextTenAmMoment());
            } catch (e instanceof Lang.Exception) {}
        }
        if (mode != null && mode == 2 && !_adaptiveShouldFetch()) {
            return false;
        }
        return true;
    }

    // Legacy tier (API < 6.0): always manual + daily — re-register tomorrow's 10:00
    // unconditionally (any persisted mode 1/2 from an older install is ignored) and
    // never gate the tick.
    (:manualOnly)
    function _rescheduleAndGate() {
        try {
            Background.registerForTemporalEvent(BmwWidgetApp._nextTenAmMoment());
        } catch (e instanceof Lang.Exception) {}
        return true;
    }

    // Adaptive schedule: fetch overnight at 00:00, the morning ramp 06/07/08:00,
    // then every 30 min through the active day until 22:00, plus a 23:00 top-up.
    // (The temporal tick is 30 min, so we gate on the local hour/minute here.)
    (:bgPoll)
    function _adaptiveShouldFetch() {
        var now = System.getClockTime();
        var h = now.hour;
        var m = now.min;
        // Overnight + morning ramp: only on the hour.
        if (h == 0 || h == 6 || h == 7 || h == 8 || h == 23) {
            return (m < 30);  // the top-of-hour tick
        }
        // Active day 09:00–22:00: every 30-min tick.
        if (h >= 9 && h <= 22) {
            return true;
        }
        // 01:00–05:00, 24h quiet: skip.
        return false;
    }

    // VIN/container resolution: auto-discovered (Storage) takes precedence over a
    // manually-entered value (Properties), so the auto path "wins" once it runs.
    function _resolveVin() {
        var v = Application.Storage.getValue(StorageKeys.KEY_VIN);
        if (v == null) { v = Application.Properties.getValue("vin"); }
        if (v != null && v.equals("")) { v = null; }
        return v;
    }

    // Background polls the LEAN container (cachedBgContainerId) so the response fits
    // the ~28 KB background heap. It's created by the foreground (ForegroundSync); if
    // absent (fresh install / pre-update), onTemporalEvent exits until the app is opened.
    function _resolveContainer() {
        var c = CarDataClient.cachedBgContainerId();
        if (c != null && c.equals("")) { c = null; }
        return c;
    }

    // Phase 2: backoff → token → quota → fetch → exit
    function _runPollCycle() {
        // Error backoff gate
        var backoffUntil = Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL);
        if (backoffUntil != null && Time.now().value() < backoffUntil) {
            Background.exit(null);
            return;
        }
        _tokenManager.ensureValidToken(method(:onTokenReady));
    }

    function onTokenReady(success as Lang.Boolean) as Void {
        if (!success) {
            Background.exit(null);
            return;
        }
        if (!QuotaGuard.canFetch()) {
            Background.exit(null);
            return;
        }
        var vin = _resolveVin();
        var containerId = _resolveContainer();
        var accessToken = _tokenManager.getAccessToken();
        if (vin == null || containerId == null || accessToken == null) {
            Background.exit(null);
            return;
        }
        _carDataClient.fetchTelematicData(vin, containerId, accessToken, method(:onDataFetchComplete));
    }

    function onDataFetchComplete(responseCode as Lang.Number, state as Lang.Dictionary or Null) as Void {
        if (responseCode == 200 && state != null) {
            // "last upd" = fetch time (temporary): stamp at fetch completion so the
            // age resets when the background poll succeeds, not just on field changes.
            state["lastUpdated"] = Time.now().value();
            QuotaGuard.updateAfterFetch();
            Background.exit(state);
        } else if (responseCode == 429) {
            QuotaGuard.onQuotaExceeded();
            Background.exit(null);
        } else {
            // Transient error: advance quota gate + apply error backoff
            QuotaGuard.updateAfterFetch();
            _incrementBackoff();
            Background.exit(null);
        }
    }

    // Double backoff delay; cap 4h. Mirrors TokenManager._incrementBackoff().
    function _incrementBackoff() {
        var current = Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL);
        var now = Time.now().value();
        var delay = 2400; // base: 40 min
        if (current != null && current > now) {
            var remaining = current - now;
            delay = remaining * 2;
            if (delay > 14400) { delay = 14400; }
        }
        Application.Storage.setValue(StorageKeys.KEY_BACKOFF_UNTIL, now + delay);
    }

}
