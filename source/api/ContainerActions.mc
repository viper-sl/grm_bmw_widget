// F14 — foreground "Delete container" action.
// Chains ensureValidToken -> DELETE the FULL container -> DELETE the lean BG container;
// drops the local id/name for each so the next sync re-bootstraps both (A3 path).
// The cached Vehicle State is left intact (last-known data stays visible).
using Toybox.Application;
using Toybox.Lang;

class ContainerDeleter {

    var _token;
    var _boot;
    var _onDone;
    var _at;
    var _bgCid;
    var _fullOk;   // did the full-container DELETE succeed (or was there none to delete)?

    function initialize() {
        _token  = new TokenManager();
        _boot   = new CarDataBootstrap();   // deleteContainer now lives here (foreground-only)
    }

    function run(onDone) {
        _onDone = onDone;
        _token.ensureValidToken(method(:onToken));
    }

    function onToken(success as Lang.Boolean) as Void {
        if (!success) { _finish(false); return; }
        _at = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
        if (_at == null) { _finish(false); return; }
        // Remember the bg container to delete after the full one.
        _bgCid = CarDataClient.cachedBgContainerId();
        var cid = CarDataClient.cachedContainerId();
        if (cid == null) { cid = Application.Properties.getValue("containerId"); }
        if (cid == null || cid.equals("")) {
            // No full container — go straight to the bg container.
            onFullDeleted(200, null);
        } else {
            _boot.deleteContainer(cid, _at, method(:onFullDeleted));
        }
    }

    function onFullDeleted(responseCode as Lang.Number, data) as Void {
        // 200 (verified) or 204 (no content) mean success; clear the full id/name.
        _fullOk = (responseCode == 200 || responseCode == 204);
        if (_fullOk) {
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_NAME);
        }
        // Then delete the lean bg container (regardless of the full result).
        if (_bgCid != null && !_bgCid.equals("")) {
            _boot.deleteContainer(_bgCid, _at, method(:onBgDeleted));
        } else {
            onBgDeleted(200, null);
        }
    }

    function onBgDeleted(responseCode as Lang.Number, data) as Void {
        var bgOk = (responseCode == 200 || responseCode == 204);
        if (bgOk) {
            Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_NAME);
        }
        // Report success only if BOTH deletes actually succeeded — otherwise the menu
        // shows "Failed — retry" instead of falsely claiming the container was deleted.
        _finish(_fullOk && bgOk);
    }

    function _finish(success) {
        if (_onDone != null) { _onDone.invoke(success); }
    }

}
