// One-shot foreground data fetch. Used after on-device auth and for the manual
// refresh (OK on the image page) so the user sees fresh data immediately instead
// of waiting for the next background poll.
// Chain: ensureValidToken -> basicData (vehicle name) -> telematicData -> VehicleCache.
// Foreground only. The owning view passes an onDone callback to redraw / pop.
using Toybox.Application;
using Toybox.Lang;

class ForegroundSync {

    var _client;
    var _token;
    var _onDone;     // invoked (success:Boolean) when the chain finishes
    var _vin;
    var _containerId;
    var _accessToken;

    function initialize() {
        _client = new CarDataClient();
        _token  = new TokenManager();
    }

    function run(onDone) {
        _onDone = onDone;
        // Access tokens last ~1h; the stored one is often stale by refresh time.
        // Ensure a valid token (refreshing if needed) BEFORE fetching.
        _token.ensureValidToken(method(:onToken));
    }

    function onToken(success as Lang.Boolean) as Void {
        if (!success) { _finish(false); return; }

        _vin         = Application.Properties.getValue("vin");
        _containerId = Application.Properties.getValue("containerId");
        _accessToken = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);

        if (_vin == null || _containerId == null || _accessToken == null) {
            _finish(false);
            return;
        }
        // Bootstrap first so the page header has the vehicle name.
        _client.fetchBasicData(_vin, _accessToken, method(:onBasic));
    }

    function onBasic(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        // basicData is best-effort; proceed to telematic regardless.
        _client.fetchTelematicData(_vin, _containerId, _accessToken, method(:onTelematic));
    }

    function onTelematic(responseCode as Lang.Number, state as Lang.Dictionary or Null) as Void {
        if (responseCode == 200 && state != null) {
            VehicleCache.write(state);
            QuotaGuard.updateAfterFetch();
            _finish(true);
        } else {
            _finish(false);
        }
    }

    function _finish(success) {
        if (_onDone != null) { _onDone.invoke(success); }
    }

}
