// OAuth2 token lifecycle manager for BMW CarData.
// Async design: ensureValidToken() dispatches the refresh and returns immediately;
// the _callback fires when the token is ready (or on failure).
// RULE: Always use StorageKeys.KEY_* constants — never inline Storage key strings.
// RULE: On token rotation, write KEY_REFRESH_TOKEN BEFORE KEY_ACCESS_TOKEN.
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

(:background)
class TokenManager {

    // Holds the completion callback across the async HTTP round-trip.
    var _callback;

    // Entry point called by Background Service before every Data Fetch.
    // Invokes callback(true)  — valid Access Token available (existing or freshly refreshed).
    // Invokes callback(false) — UNCONFIGURED, NEEDS_REBOOTSTRAP, or failed refresh.
    function ensureValidToken(callback) {
        _callback = callback;

        var tokenState = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);

        // Guard: no token or permanent auth failure — no network call
        if (tokenState == null
                || tokenState.equals("UNCONFIGURED")
                || tokenState.equals("NEEDS_REBOOTSTRAP")) {
            _callback.invoke(false);
            return;
        }

        // Proactive expiry check — avoids spending a quota call on a stale token
        var expiry = Application.Storage.getValue(StorageKeys.KEY_ACCESS_EXPIRY);
        if (expiry == null || Time.now().value() >= expiry) {
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NEEDS_REFRESH");
            _refreshToken();
        } else {
            _callback.invoke(true); // Access Token still valid
        }
    }

    // POST token refresh to auth host (customer.bmwgroup.com — quota-exempt).
    function _refreshToken() {
        var clientId = Application.Properties.getValue("clientId");

        // Storage-first fallback: first-run uses Settings value; subsequent runs use rotated token
        var refreshToken = Application.Storage.getValue(StorageKeys.KEY_REFRESH_TOKEN);
        if (refreshToken == null) {
            refreshToken = Application.Properties.getValue("refreshToken");
        }

        if (clientId == null || refreshToken == null) {
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "UNCONFIGURED");
            _callback.invoke(false);
            return;
        }

        Communications.makeWebRequest(
            "https://customer.bmwgroup.com/gcdm/oauth/token",
            {
                "grant_type"    => "refresh_token",
                "client_id"     => clientId,
                "refresh_token" => refreshToken
            },
            {
                :method       => Communications.HTTP_REQUEST_METHOD_POST,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onTokenRefreshResponse)
        );
    }

    // CIQ runtime invokes this when the token refresh HTTP response arrives.
    function onTokenRefreshResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        if (responseCode == 200 && data != null && data.hasKey("access_token")) {
            // Atomic rotation: Refresh Token MUST be persisted before Access Token is used.
            // If interrupted after step 1 but before step 2, the user can still re-auth.
            Application.Storage.setValue(StorageKeys.KEY_REFRESH_TOKEN, data["refresh_token"]);
            Application.Storage.setValue(StorageKeys.KEY_ACCESS_TOKEN,  data["access_token"]);
            var expiresIn = (data.hasKey("expires_in") && data["expires_in"] != null)
                ? data["expires_in"].toNumber() : 3600;
            Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY,
                Time.now().value() + expiresIn);
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");
            data = null; // parse-and-discard
            _callback.invoke(true);

        } else if (responseCode == 400
                && data != null
                && data.hasKey("error")
                && data["error"] != null
                && data["error"].equals("invalid_grant")) {
            // Permanent auth failure — user must re-run Device Flow off-watch
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NEEDS_REBOOTSTRAP");
            data = null;
            _callback.invoke(false);

        } else {
            // Transient failure (5xx, network error, timeout) — back off and retry later
            _incrementBackoff();
            data = null;
            _callback.invoke(false);
        }
    }

    // Doubles the current backoff delay; cap at 4 hours (A-4).
    // Schedule: ~40 min → ~80 min → ~160 min → 240 min (cap).
    function _incrementBackoff() {
        var current = Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL);
        var now = Time.now().value();
        var delay = 2400; // base: 40 min (= poll interval)

        if (current != null && current > now) {
            // Active backoff: double the remaining wait time
            var remaining = current - now;
            delay = remaining * 2;
            if (delay > 14400) { delay = 14400; } // cap: 4h
        }
        Application.Storage.setValue(StorageKeys.KEY_BACKOFF_UNTIL, now + delay);
    }

    // Returns the current Access Token from Storage, or null.
    function getAccessToken() {
        return Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
    }

    // Returns the current token FSM state string from Storage, or null.
    function getTokenState() {
        return Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
    }

}
