// F14 — foreground "Delete container" action.
// Chains ensureValidToken -> DELETE /customers/containers/{id}; on success drops the
// local container id/name so the next poll re-bootstraps a fresh container (A3 path).
// The cached Vehicle State is left intact (last-known data stays visible).
using Toybox.Application;
using Toybox.Lang;

class ContainerDeleter {

    var _token;
    var _client;
    var _onDone;

    function initialize() {
        _token  = new TokenManager();
        _client = new CarDataClient();
    }

    function run(onDone) {
        _onDone = onDone;
        _token.ensureValidToken(method(:onToken));
    }

    function onToken(success as Lang.Boolean) as Void {
        if (!success) { _finish(false); return; }
        var at  = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
        var cid = CarDataClient.cachedContainerId();
        if (cid == null) { cid = Application.Properties.getValue("containerId"); }
        if (at == null || cid == null || cid.equals("")) { _finish(false); return; }
        _client.deleteContainer(cid, at, method(:onDeleted));
    }

    function onDeleted(responseCode as Lang.Number, data) as Void {
        // 200 (verified) or 204 (no content) both mean success.
        if (responseCode == 200 || responseCode == 204) {
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_NAME);
            _finish(true);
        } else {
            _finish(false);
        }
    }

    function _finish(success) {
        if (_onDone != null) { _onDone.invoke(success); }
    }

}
