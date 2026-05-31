// Application entry point. Foreground only — NO makeWebRequest calls here.
// Bootstrap and network I/O happen exclusively in BmwWidgetServiceDelegate.
// (:glance) annotation: App participates in the glance scope (matches SDK WidgetGlanceView sample).
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
        // Register 40-minute background poll. Wrapped: Background APIs throw in glance scope.
        try {
            Background.registerForTemporalEvent(new Time.Duration(2400));
        } catch (e instanceof Lang.Exception) {
            // glance scope — background registration unavailable; ignore
        }
        _seedDebugData();
    }

    // Debug builds (simulator): seed a realistic Vehicle State so the UI renders without
    // network/settings. Compiled out of release builds.
    (:debug)
    function _seedDebugData() {
        if (Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME) == null) {
            Application.Storage.setValue(StorageKeys.KEY_VEHICLE_NAME, "BMW 218i");
        }
        if (VehicleCache.read() == null) {
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
                "lastUpdated"       => Time.now().value()
            });
        }
    }

    (:release)
    function _seedDebugData() {
        // no-op in production builds
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new BmwWidgetView();
        return [view, new BmwWidgetDelegate(view, false)];
    }

    function getGlanceView() {
        return [new BmwWidgetGlanceView()];
    }

    // REQUIRED: returns the Background Service delegate the OS runs on each temporal event.
    // Without this, registerForTemporalEvent fires but no poll code executes.
    // (Matches OpenWeatherMapWidget / HomeAssistant reference pattern.)
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
