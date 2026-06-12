// Foreground data sync — runs the full cold-start chain so the user sees data right
// after pairing (and on every manual refresh), without waiting for the background poll.
//
// Chain (each step auto-resolves what's missing):
//   ensureValidToken
//   -> VIN        : Storage/Settings, else discover via /mappings
//   -> container  : Storage/Settings, else create via POST /customers/containers
//   -> basicData  : vehicle name + About-car snapshot
//   -> telematic  : full vehicle state -> VehicleCache
//
// Foreground only. The owning view passes an onDone(success) callback.
using Toybox.Application;
using Toybox.Lang;

class ForegroundSync {

    var _client;
    var _token;
    var _onDone;
    var _vin;
    var _containerId;
    var _accessToken;
    var _tyreKm;

    function initialize() {
        _client = new CarDataClient();
        _token  = new TokenManager();
    }

    static const COOLDOWN_SECONDS = 60;   // minimum gap between foreground refreshes
    static const KEY_LAST_FG = "lastForegroundSync";

    function run(onDone) {
        _onDone = onDone;
        // 1-minute cooldown guard — prevents rapid re-taps from hammering the API.
        var lastSync = Application.Storage.getValue(KEY_LAST_FG);
        if (lastSync != null && (Time.now().value() - lastSync) < COOLDOWN_SECONDS) {
            _finish(false);
            return;
        }
        // Access tokens last ~1h; ensure a valid one (refresh if needed) first.
        _token.ensureValidToken(method(:onToken));
    }

    function onToken(success as Lang.Boolean) as Void {
        if (!success) { _finish(false); return; }
        _accessToken = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
        if (_accessToken == null) { _finish(false); return; }

        // Step 1: VIN — resolve, else discover.
        _vin = _resolveVin();
        if (_vin == null) {
            _client.fetchMappings(_accessToken, method(:onVin));
        } else {
            onVin(200, _vin);
        }
    }

    function onVin(responseCode as Lang.Number, vin) as Void {
        if (vin == null) { _finish(false); return; }
        _vin = vin;

        // Step 2: container — use a known one, else discover existing, else create.
        _containerId = _resolveContainer();
        if (_containerId != null) {
            onContainer(200, _containerId);
        } else {
            _client.fetchContainers(_accessToken, method(:onContainerList));
        }
    }

    // Reuse an existing container if the account already has one; otherwise create it.
    function onContainerList(responseCode as Lang.Number, containerId) as Void {
        if (containerId != null) {
            onContainer(200, containerId);
        } else {
            _client.createContainer(_accessToken, method(:onContainer));
        }
    }

    function onContainer(responseCode as Lang.Number, containerId) as Void {
        if (containerId == null) { _finish(false); return; }
        _containerId = containerId;

        // Step 3: basicData (best-effort), then telematic.
        _client.fetchBasicData(_vin, _accessToken, method(:onBasic));
    }

    function onBasic(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        _client.fetchTyreDiagnosis(_vin, _accessToken, method(:onTyreDiag));
    }

    function onTyreDiag(responseCode as Lang.Number, tyreKm as Lang.Dictionary or Null) as Void {
        _tyreKm = tyreKm;  // best-effort — proceed regardless of success
        _client.fetchTelematicData(_vin, _containerId, _accessToken, method(:onTelematic));
    }

    function onTelematic(responseCode as Lang.Number, state as Lang.Dictionary or Null) as Void {
        if (responseCode == 200 && state != null) {
            // Merge tyre wear km (from separate endpoint) into the telematic state before writing.
            if (_tyreKm != null) {
                var wkeys = ["tyreWearKmFL", "tyreWearKmFR", "tyreWearKmRL", "tyreWearKmRR"];
                for (var i = 0; i < wkeys.size(); i++) {
                    if (_tyreKm.hasKey(wkeys[i])) { state[wkeys[i]] = _tyreKm[wkeys[i]]; }
                }
            }
            VehicleCache.write(state);
            QuotaGuard.updateAfterFetch();
            Application.Storage.setValue(KEY_LAST_FG, Time.now().value());
            // Re-assert the background poll schedule. Manual mode's daily 10:00
            // event is one-shot; if its re-registration in onTemporalEvent ever
            // failed silently, the chain stays broken until the app re-registers —
            // any successful manual refresh is a natural point to re-arm it.
            Application.getApp()._applyUpdateMode();
            _finish(true);
        } else if (responseCode == 429) {
            // Manual refresh hit the quota — apply the same 24h block as the background service.
            QuotaGuard.onQuotaExceeded();
            _finish(false);
        } else {
            _finish(false);
        }
    }

    // Storage-first (auto-discovered) values, falling back to manual Settings.
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

    function _finish(success) {
        if (_onDone != null) { _onDone.invoke(success); }
    }

}
