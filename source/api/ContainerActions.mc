// F14 — foreground "Delete all containers" action.
// Chains ensureValidToken -> GET /customers/containers (list ALL ids) -> DELETE each ->
// clear the local full + bg container ids/names so the next sync re-bootstraps fresh.
// Deletes EVERY container on the account (incl. orphaned old-version ones), not just the
// two this build tracks. The cached Vehicle State is left intact (last-known data shows).
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

class ContainerDeleter {

    // Delete-all makes ~1 list + N delete calls; a second run soon after would burn the
    // daily quota. The Manage button throttles to once per hour (KEY_LAST_DELETE is
    // stamped on every run() — incl. onboarding cleanup — and checked by the button).
    static const COOLDOWN_SECONDS = 3600;
    static const KEY_LAST_DELETE  = "lastDeleteAll";

    var _token;
    var _boot;
    var _onDone;
    var _at;
    var _ids;          // every container id on the account
    var _idx;          // current delete index
    var _allOk;        // did every DELETE succeed?
    var _rateLimited;  // list/delete hit BMW's daily rate limit (CU-429)

    function initialize() {
        _token  = new TokenManager();
        _boot   = new CarDataBootstrap();   // list + delete live here (foreground-only)
        _rateLimited = false;
    }

    // True when the action stopped because BMW's daily limit was reached — the caller
    // shows "daily limit" rather than "retry".
    function isRateLimited() { return _rateLimited; }

    function run(onDone) {
        _onDone = onDone;
        // Start the 1h throttle window for the Manage button (a run = ~1 + N API calls).
        Application.Storage.setValue(KEY_LAST_DELETE, Time.now().value());
        _token.ensureValidToken(method(:onToken));
    }

    function onToken(success as Lang.Boolean) as Void {
        if (!success) { _finish(false); return; }
        _at = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
        if (_at == null) { _finish(false); return; }
        _boot.fetchContainerIds(_at, method(:onList));
    }

    function onList(responseCode as Lang.Number, ids) as Void {
        if (responseCode == 429) {
            // Daily limit reached — can't list/delete today. Back off and tell the user.
            _rateLimited = true;
            QuotaGuard.onQuotaExceeded();
            _finish(false);
            return;
        }
        // Could not list (network / error) — fail so the menu shows "retry".
        if (responseCode != 200) { _finish(false); return; }
        _ids   = ids;
        _idx   = 0;
        _allOk = true;
        _deleteNext();
    }

    function _deleteNext() as Void {
        if (_ids == null || _idx >= _ids.size()) {
            // All attempted — drop local ids/names for both containers so the next sync
            // re-creates them. (A still-existing container is reused by name on re-sync.)
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_NAME);
            Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_NAME);
            _finish(_allOk);
            return;
        }
        _boot.deleteContainer(_ids[_idx], _at, method(:onOneDeleted));
    }

    function onOneDeleted(responseCode as Lang.Number, data) as Void {
        if (responseCode == 429) {
            // Daily limit hit mid-delete — the remaining deletes would all fail too. Stop.
            _rateLimited = true;
            QuotaGuard.onQuotaExceeded();
            _finish(false);
            return;
        }
        // 200 (verified) or 204 (no content) both mean success.
        if (!(responseCode == 200 || responseCode == 204)) { _allOk = false; }
        _idx++;
        _deleteNext();
    }

    function _finish(success) {
        if (_onDone != null) { _onDone.invoke(success); }
    }

}
