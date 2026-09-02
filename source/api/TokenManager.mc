// OAuth2 token lifecycle manager for BMW CarData.
// Async design: ensureValidToken() dispatches the refresh and returns immediately;
// the _callback fires when the token is ready (or on failure).
// RULE: Always use StorageKeys.KEY_* constants — never inline Storage key strings.
// RULE: On token rotation, write KEY_REFRESH_TOKEN BEFORE KEY_ACCESS_TOKEN.
// RULE: A 200 that omits refresh_token must NOT clear the stored one.
// RULE: NEEDS_REBOOTSTRAP is a one-way door (ensureValidToken short-circuits on it
//       before any network call) — only latch it on corroborated evidence.
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

(:background)
class TokenManager {

    // Refresh this many seconds BEFORE the access token actually expires. A token
    // that is still valid when the request leaves the watch can be expired by the
    // time it reaches BMW over a slow phone bridge; the data path reads that 401 as
    // a transient error and never retries, so the widget would sit stale until the
    // next poll.
    static const EXPIRY_SKEW_SECONDS = 300;

    // How long a dispatched refresh POST counts as "in flight". BMW rotates the
    // refresh token on every refresh, so two overlapping refreshes race: the first
    // rotates, the second presents a token BMW has already burned and gets 400
    // invalid_grant. Foreground views and the background service are separate
    // processes but share Storage, so this stamp serializes them across both. A
    // process killed mid-refresh leaves the stamp behind — the TTL is what makes
    // it self-heal.
    static const INFLIGHT_TTL_SECONDS = 90;

    // Consecutive invalid_grant responses required before the refresh token is
    // declared dead. One is not proof: a refresh whose RESPONSE was lost in transit
    // (BMW rotated, the watch never received the new token) produces exactly one
    // invalid_grant on the next attempt, and so does a mid-air collision between
    // the foreground and the background poll. Latching early turns a bad BLE moment
    // into a permanent "Re-auth needed", so demand a clear run of them.
    //
    // The threshold depends on WHO asked, because the cost of a false latch differs.
    // After a START press the user is watching: they have just seen the refresh fail
    // repeatedly, and the re-auth prompt is something they can act on immediately, so
    // a shorter run is enough. An unattended refresh gets the longer one — nobody is
    // there to judge, and a wrong latch is a one-way door discovered hours later.
    //
    // Either way the cost is a delayed prompt, never lost data: below the threshold
    // the widget keeps showing cached values under a "No connection" note, and
    // Settings -> Re-pair is always available. The strikes are shared, so a run that
    // starts in the background can be finished by a START press (and vice versa).
    static const GRANT_STRIKES_MANUAL     = 3;
    static const GRANT_STRIKES_UNATTENDED = 5;

    // Holds the completion callback across the async HTTP round-trip.
    var _callback;

    // True when a START press is driving this refresh — selects the strike threshold.
    var _manual;

    function initialize() {
        _manual = false;   // default: background poll / auto sync on app open
    }

    // Callers that know a user is watching say so before ensureValidToken().
    function setManual(isManual) { _manual = isManual; }

    function _strikeLimit() {
        return (_manual == true) ? GRANT_STRIKES_MANUAL : GRANT_STRIKES_UNATTENDED;
    }

    // Entry point called by Background Service before every Data Fetch.
    // Invokes callback(true)  — valid Access Token available (existing or freshly refreshed).
    // Invokes callback(false) — UNCONFIGURED, NEEDS_REBOOTSTRAP, or failed refresh.
    function ensureValidToken(callback) {
        _callback = callback;

        var tokenState = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);

        // Guard: permanent auth failure — no network call.
        if (tokenState != null
                && (tokenState.equals("UNCONFIGURED")
                    || tokenState.equals("NEEDS_REBOOTSTRAP"))) {
            _callback.invoke(false);
            return;
        }

        // First run: tokenState == null but a refresh token may be configured in Settings.
        // Attempt a refresh — _refreshToken() falls back to UNCONFIGURED if creds are absent.
        if (tokenState == null) {
            _refreshToken();
            return;
        }

        // Proactive expiry check — avoids spending a quota call on a stale token.
        // The skew makes it "expiring soon", not "expired" (see EXPIRY_SKEW_SECONDS).
        var expiry = Application.Storage.getValue(StorageKeys.KEY_ACCESS_EXPIRY);
        if (expiry == null || Time.now().value() + EXPIRY_SKEW_SECONDS >= expiry) {
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NEEDS_REFRESH");
            _refreshToken();
        } else {
            _callback.invoke(true); // Access Token still valid
        }
    }

    // Recovery entry point for the re-link prompt: ignores the permanent-failure
    // guard and spends one (quota-exempt) refresh before the user is dragged through
    // the device flow. A latched NEEDS_REBOOTSTRAP can be a false positive — see
    // the strike constants — and a successful refresh here clears it outright.
    function retryAfterRebootstrap(callback) {
        _callback = callback;
        _manual   = true;   // always a user action, from the re-link prompt

        // The user's explicit "try again" — start the strike count over so the
        // corroboration rule applies to this attempt too.
        Application.Storage.deleteValue(StorageKeys.KEY_GRANT_STRIKES);
        _refreshToken();
    }

    // POST token refresh to auth host (customer.bmwgroup.com — quota-exempt).
    function _refreshToken() {
        // Serialize refreshes across views and processes (see INFLIGHT_TTL_SECONDS).
        // Checked first: a refresh being in flight already proves the credentials are
        // there, and a caller arriving mid-refresh must fail TRANSIENTLY — the token
        // state is left untouched, so this reads as "try again", never as "re-pair".
        var now = Time.now().value();
        var inFlight = Application.Storage.getValue(StorageKeys.KEY_REFRESH_INFLIGHT);
        if (inFlight != null && inFlight <= now && now - inFlight < INFLIGHT_TTL_SECONDS) {
            _callback.invoke(false);
            return;
        }

        var clientId = Config.clientId();

        // Storage-first fallback: first-run uses Settings value; subsequent runs use rotated token
        var refreshToken = Application.Storage.getValue(StorageKeys.KEY_REFRESH_TOKEN);
        if (refreshToken == null) {
            refreshToken = Application.Properties.getValue("refreshToken");
        }

        // An unset String Setting reads back as "", not null — normalize, as the VIN
        // and container resolvers do. Posting an empty refresh_token just earns a 400.
        if (clientId != null && clientId.equals(""))         { clientId = null; }
        if (refreshToken != null && refreshToken.equals("")) { refreshToken = null; }

        if (clientId == null || refreshToken == null) {
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "UNCONFIGURED");
            _callback.invoke(false);
            return;
        }

        Application.Storage.setValue(StorageKeys.KEY_REFRESH_INFLIGHT, now);

        // BMW's OAuth token endpoint requires application/x-www-form-urlencoded.
        // Without an explicit Content-Type header, makeWebRequest sends the params
        // as JSON, which BMW rejects with HTTP 400 invalid_request.
        Communications.makeWebRequest(
            "https://customer.bmwgroup.com/gcdm/oauth/token",
            {
                "grant_type"    => "refresh_token",
                "client_id"     => clientId,
                "refresh_token" => refreshToken
            },
            {
                :method       => Communications.HTTP_REQUEST_METHOD_POST,
                :headers      => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onTokenRefreshResponse)
        );
    }

    // CIQ runtime invokes this when the token refresh HTTP response arrives.
    function onTokenRefreshResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        // The round-trip is over however it ended — release the in-flight lock first
        // so an early return can't strand it for the full TTL.
        Application.Storage.deleteValue(StorageKeys.KEY_REFRESH_INFLIGHT);

        if (responseCode == 200 && data != null && data.hasKey("access_token")) {
            // Atomic rotation: Refresh Token MUST be persisted before Access Token is used.
            // If interrupted after step 1 but before step 2, the user can still re-auth.
            // Guarded write: a 200 that omits refresh_token would otherwise store null
            // over the live one and strand the widget in UNCONFIGURED on the next call.
            if (data.hasKey("refresh_token") && data["refresh_token"] != null) {
                Application.Storage.setValue(StorageKeys.KEY_REFRESH_TOKEN, data["refresh_token"]);
            }
            Application.Storage.setValue(StorageKeys.KEY_ACCESS_TOKEN,  data["access_token"]);
            var expiresIn = (data.hasKey("expires_in") && data["expires_in"] != null)
                ? data["expires_in"].toNumber() : 3600;
            Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY,
                Time.now().value() + expiresIn);
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");
            // Success retires both failure ledgers. Without the backoff clear a bad
            // patch of connectivity keeps the background poll gated for up to 4h
            // after the link is back (QuotaGuard's documented contract).
            QuotaGuard.clearBackoff();
            Application.Storage.deleteValue(StorageKeys.KEY_GRANT_STRIKES);
            data = null;
            _callback.invoke(true);

        } else if (responseCode == 400
                && data != null
                && data.hasKey("error")
                && data["error"] != null
                && data["error"].equals("invalid_grant")) {
            // Probably-permanent auth failure — but corroborate before latching the
            // one-way state (see _strikeLimit). Until then it behaves like
            // any transient failure: back off and let the next attempt decide.
            var strikes = Application.Storage.getValue(StorageKeys.KEY_GRANT_STRIKES);
            strikes = (strikes == null) ? 1 : strikes + 1;
            Application.Storage.setValue(StorageKeys.KEY_GRANT_STRIKES, strikes);
            if (strikes >= _strikeLimit()) {
                // Confirmed: user must re-run Device Flow.
                Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NEEDS_REBOOTSTRAP");
            } else {
                _incrementBackoff();
            }
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

    // A data call was rejected with 401: the access token is not accepted, whatever
    // the stored expiry claims. Drop the expiry so the next ensureValidToken()
    // refreshes instead of replaying a token the server has already refused.
    static function invalidateAccessToken() {
        Application.Storage.deleteValue(StorageKeys.KEY_ACCESS_EXPIRY);
    }

}
