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
        // Phase 1: one-time bootstrap (KEY_VEHICLE_NAME absent = first run or Storage wipe)
        if (Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME) == null) {
            _runBootstrap();
            return; // Background.exit() called from onBootstrapComplete
        }
        // Phase 2: normal poll cycle
        _runPollCycle();
    }

    // Phase 1: fetch vehicle name + driveType from basicData; store; exit.
    // Next temporal event will run Phase 2.
    // On first run only a refresh token exists (in Properties) — must mint an access
    // token via ensureValidToken BEFORE attempting basicData, or accessToken is null.
    function _runBootstrap() {
        _tokenManager.ensureValidToken(method(:onBootstrapTokenReady));
    }

    function onBootstrapTokenReady(success as Lang.Boolean) as Void {
        var vin = Application.Properties.getValue("vin");
        var accessToken = _tokenManager.getAccessToken();
        if (!success || vin == null || accessToken == null) {
            Background.exit(null);
            return;
        }
        _carDataClient.fetchBasicData(vin, accessToken, method(:onBootstrapComplete));
    }

    function onBootstrapComplete(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        // CarDataClient.onBasicDataResponse already wrote KEY_VEHICLE_NAME + KEY_DRIVE_TYPE
        Background.exit(null);
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
        var vin = Application.Properties.getValue("vin");
        var containerId = Application.Properties.getValue("containerId");
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
