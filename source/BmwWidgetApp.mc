// Application entry point. Foreground only — NO makeWebRequest calls here.
// Bootstrap and network I/O happen exclusively in BmwWidgetServiceDelegate.
using Toybox.Application;
using Toybox.Background;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

(:background)
class BmwWidgetApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _applyUpdateMode();
        _seedDebugData();
    }

    // updateMode: 0 = manual (no background poll; user refreshes via OK on the image page)
    //             1 = auto hourly
    //             2 = auto adaptive (fires every 30 min, but the ServiceDelegate only
    //                 actually fetches at the adaptive hours — see _adaptiveShouldFetch).
    // CIQ registerForTemporalEvent only supports a fixed interval, so adaptive gating
    // lives in the service delegate, not here. Default manual.
    // Wrapped: Background APIs throw in glance scope.
    function _applyUpdateMode() {
        try {
            var mode = Application.Properties.getValue("updateMode");
            if (mode != null && mode == 1) {
                Background.registerForTemporalEvent(new Time.Duration(3600)); // hourly
            } else if (mode != null && mode == 2) {
                Background.registerForTemporalEvent(new Time.Duration(1800)); // 30 min tick; gated
            } else {
                // Manual: ensure no stale temporal event keeps firing.
                Background.deleteTemporalEvent();
            }
        } catch (e instanceof Lang.Exception) {
            // glance scope — background registration unavailable; ignore
        }
    }

    // Debug builds (simulator): seed a realistic Vehicle State so the UI renders without
    // network/settings. Compiled out of release builds.
    (:debug)
    function _seedDebugData() {
        // Unconditional overwrite: a partial cache left by the background service (or an
        // older build) must not survive, or the UI gets stuck showing only one page.
        Application.Storage.setValue(StorageKeys.KEY_VEHICLE_NAME, "BMW 218i");
        VehicleCache.write({
            "doorsLocked"       => true,
            "rangeKm"           => 653,
            "fuelPercent"       => 95,
            "fuelLitres"        => 21,
            "doorFLOpen"        => false,
            "doorFROpen"        => false,
            "trunkOpen"         => false,
            "hoodOpen"          => false,
            "odometerKm"        => 40926,
            "serviceDistanceKm" => 22000,
            "displayUnit"       => "km",
            "tyrePressureFL"    => 2.3,
            "tyrePressureFR"    => 2.3,
            "tyrePressureRL"    => 2.2,
            "tyrePressureRR"    => 2.3,
            "tyreTargetFL"      => 2.2,
            "tyreTargetFR"      => 2.2,
            "tyreTargetRL"      => 2.2,
            "tyreTargetRR"      => 2.2,
            "tyreWearKmFL"      => 11500,
            "tyreWearKmFR"      => 11500,
            "tyreWearKmRL"      => 10500,
            "tyreWearKmRR"      => 10500,
            "lastUpdated"       => Time.now().value()
        });
    }

    (:release)
    function _seedDebugData() {
        // no-op in production builds
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
