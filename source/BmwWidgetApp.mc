// Application entry point. Foreground only — NO makeWebRequest calls here.
// Bootstrap and network I/O happen exclusively in BmwWidgetServiceDelegate.
using Toybox.Application;
using Toybox.Background;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

(:background)
class BmwWidgetApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _applyUpdateMode();
    }

    // GCM / on-watch settings changed while the app was already loaded.
    // Without this hook the running instance keeps its first-run state — most
    // importantly a tokenState left at "UNCONFIGURED" by a launch that happened
    // BEFORE a clientId was set. That lockout then makes every later token path
    // short-circuit to failure even once a valid clientId arrives, so pairing
    // behaves differently depending on whether the clientId was set before or
    // after the first run. Clearing it here makes both orderings equivalent.
    function onSettingsChanged() {
        // A changed clientId retires the stored grant outright — BMW rejects a
        // refresh_token presented by a client that did not issue it. Handle it here so
        // the prompt appears the moment the user saves, not hours later once the
        // strike ladder has worked it out (ensureValidToken repeats the check for
        // edits made while the widget was closed).
        TokenManager.syncClient();

        var clientId = Config.clientId();
        if (clientId != null && !clientId.equals("")) {
            var ts = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
            // "UNCONFIGURED" = never had creds. Now we do — drop it so the fresh
            // first-run/auth path applies. Leave NORMAL and NEEDS_REBOOTSTRAP
            // (those are real paired / re-link states, not a missing-creds lockout).
            if (ts != null && ts.equals("UNCONFIGURED")) {
                Application.Storage.deleteValue(StorageKeys.KEY_TOKEN_STATE);
            }
        }
        _applyUpdateMode();
        WatchUi.requestUpdate();
    }

    // updateMode: 0 = manual (no hourly/adaptive poll; user refreshes via OK on the
    //                 image page, plus one daily 10:00 fetch — FR-25 — to keep the
    //                 OAuth token pair alive)
    //             1 = auto hourly
    //             2 = auto adaptive (fires every 30 min, but the ServiceDelegate only
    //                 actually fetches at the adaptive hours — see _adaptiveShouldFetch).
    // CIQ registerForTemporalEvent only supports a fixed interval, so adaptive gating
    // lives in the service delegate, not here. Default manual.
    // Wrapped: Background APIs throw in glance scope.
    //
    // TIER SPLIT: exactly one variant survives each device build (see monkey.jungle).
    //   (:bgPoll)     — full tier (API 6.0+ devices): all three modes.
    //   (:manualOnly) — legacy tier (API < 6.0): always manual + daily 10:00,
    //                   even if a mode 1/2 value survives from an older install.
    (:bgPoll)
    function _applyUpdateMode() {
        try {
            var mode = Application.Properties.getValue("updateMode");
            if (mode != null && mode == 1) {
                Background.registerForTemporalEvent(new Time.Duration(3600)); // hourly
            } else if (mode != null && mode == 2) {
                Background.registerForTemporalEvent(new Time.Duration(1800)); // 30 min tick; gated
            } else {
                // FR-25: Manual mode — one daily fetch at ~10:00 local. Moment-based
                // events are one-shot; ServiceDelegate.onTemporalEvent() re-registers
                // the next day's 10:00 occurrence.
                Background.registerForTemporalEvent(_nextTenAmMoment());
            }
        } catch (e instanceof Lang.Exception) {
            // glance scope — background registration unavailable; ignore
        }
    }

    (:manualOnly)
    function _applyUpdateMode() {
        try {
            // Legacy tier: manual + daily 10:00 regardless of any persisted mode.
            Background.registerForTemporalEvent(_nextTenAmMoment());
        } catch (e instanceof Lang.Exception) {
            // glance scope — background registration unavailable; ignore
        }
    }

    // Next occurrence of 10:00 local time — today if not yet passed, else tomorrow.
    static function _nextTenAmMoment() as Time.Moment {
        var now = Time.now();
        var today = Gregorian.info(now, Time.FORMAT_SHORT);
        var tenToday = Gregorian.moment({
            :year => today.year, :month => today.month, :day => today.day,
            :hour => 10, :minute => 0, :second => 0
        });
        if (tenToday.value() > now.value()) {
            return tenToday;
        }
        return tenToday.add(new Time.Duration(86400));
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BmwWidgetView();
        return [view, new BmwWidgetDelegate(view)];
    }

    function getGlanceView() {
        return [new BmwWidgetGlanceView()];
    }

    // REQUIRED: returns the Background Service delegate the OS runs on each temporal event.
    // Without this, registerForTemporalEvent fires but no poll code executes.
    function getServiceDelegate() {
        return [new BmwWidgetServiceDelegate()];
    }

    function onBackgroundData(data) {
        if (data != null) {
            VehicleCache.write(data);
            WatchUi.requestUpdate();
        }
    }

}
