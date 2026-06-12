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
        var mode = Application.Properties.getValue("updateMode");

        // FR-25: Manual mode's daily 10:00 event is Moment-based, hence one-shot —
        // re-register tomorrow's 10:00 occurrence immediately so the daily cadence
        // continues without requiring the user to reopen the app.
        if (mode == null || mode == 0) {
            try {
                Background.registerForTemporalEvent(BmwWidgetApp._nextTenAmMoment());
            } catch (e instanceof Lang.Exception) {}
        }

        // Adaptive mode (2) fires every 30 min but should only fetch at chosen hours;
        // skip ticks that don't match the schedule to conserve quota/battery.
        if (mode != null && mode == 2 && !_adaptiveShouldFetch()) {
            Background.exit(null);
            return;
        }

        // Phase 1: bootstrap on first run / Storage wipe (KEY_VEHICLE_NAME absent),
        // or on container schema migration — cachedContainerId() invalidates an id
        // stored under an older container name, and the bootstrap chain recreates
        // it under the current name with the expanded descriptor set.
        if (Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME) == null
                || _resolveContainer() == null) {
            _runBootstrap();
            return; // Background.exit() called from onBootstrapComplete
        }
        // Phase 2: normal poll cycle
        _runPollCycle();
    }

    // Adaptive schedule: fetch overnight at 00:00, the morning ramp 06/07/08:00,
    // then every 30 min through the active day until 22:00, plus a 23:00 top-up.
    // (The temporal tick is 30 min, so we gate on the local hour/minute here.)
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

    // Cold-start chain (each step exits on failure, else advances):
    //   token -> VIN (discover if missing) -> container (create if missing) -> basicData
    // On first run only a refresh token exists (in Properties) — mint an access token
    // via ensureValidToken BEFORE any API call.
    function _runBootstrap() {
        _tokenManager.ensureValidToken(method(:onBootstrapTokenReady));
    }

    function onBootstrapTokenReady(success as Lang.Boolean) as Void {
        if (!success || _tokenManager.getAccessToken() == null) {
            Background.exit(null);
            return;
        }
        // Step 1: VIN — use a resolved one if present, else discover via /mappings.
        if (_resolveVin() == null) {
            _carDataClient.fetchMappings(_tokenManager.getAccessToken(), method(:onBootstrapVin));
        } else {
            onBootstrapVin(200, _resolveVin());
        }
    }

    function onBootstrapVin(responseCode as Lang.Number, vin) as Void {
        if (vin == null) { Background.exit(null); return; }
        // Step 2: container — known one, else discover existing, else create.
        if (_resolveContainer() != null) {
            onBootstrapContainer(200, _resolveContainer());
        } else {
            _carDataClient.fetchContainers(_tokenManager.getAccessToken(), method(:onBootstrapContainerList));
        }
    }

    function onBootstrapContainerList(responseCode as Lang.Number, containerId) as Void {
        if (containerId != null) {
            onBootstrapContainer(200, containerId);
        } else {
            _carDataClient.createContainer(_tokenManager.getAccessToken(), method(:onBootstrapContainer));
        }
    }

    function onBootstrapContainer(responseCode as Lang.Number, containerId) as Void {
        if (containerId == null) { Background.exit(null); return; }
        // Step 3: basicData (vehicle name + About-car snapshot).
        _carDataClient.fetchBasicData(_resolveVin(), _tokenManager.getAccessToken(), method(:onBootstrapComplete));
    }

    function onBootstrapComplete(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        // CarDataClient.onBasicDataResponse already wrote KEY_VEHICLE_NAME + basicData.
        Background.exit(null);
    }

    // VIN/container resolution: auto-discovered (Storage) takes precedence over a
    // manually-entered value (Properties), so the auto path "wins" once it runs.
    function _resolveVin() {
        var v = Application.Storage.getValue(StorageKeys.KEY_VIN);
        if (v == null) { v = Application.Properties.getValue("vin"); }
        if (v != null && v.equals("")) { v = null; }
        return v;
    }

    function _resolveContainer() {
        var c = CarDataClient.cachedContainerId();
        if (c == null) { c = Application.Properties.getValue("containerId"); }
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
