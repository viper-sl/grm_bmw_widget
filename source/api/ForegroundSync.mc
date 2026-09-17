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
using Toybox.System;
using Toybox.Time;

class ForegroundSync {

    var _client;
    var _boot;
    var _token;
    var _onDone;
    var _vin;
    var _containerId;     // FULL container (foreground telematic + About-car detail)
    var _bgContainerId;   // lean container the background service polls
    var _accessToken;
    var _tyreKm;
    var _rateLimited;     // set if any step hit BMW's daily rate limit (CU-429)
    var _authFailed;      // set if the failure was credential-level, not link-level
    var _failReason;      // WHY the run failed (FAIL_* below)
    var _lastCode;        // last non-200 response code seen, for the failure text
    var _retried401;      // guard: re-run the chain at most once after a 401
    var _retried403;      // guard: re-discover containers at most once after a 403
    var _createFailed;    // set if a container create failed with a cap-like error
    var _fullFetch;       // true → fetch the FULL container (About-car etc.); false → just ensure containers

    function initialize() {
        _client = new CarDataClient();      // lean (:background) telematic poll
        _boot   = new CarDataBootstrap();   // foreground-only cold-start/maintenance calls
        _token  = new TokenManager();
        _rateLimited = false;
        _authFailed  = false;
        _failReason  = FAIL_NONE;
        _lastCode    = 0;
        _retried401  = false;
        _retried403  = false;
        _createFailed = false;
        _fullFetch   = false;
    }

    // True when the sync failed because BMW's daily API rate limit was reached.
    // The owning view reads this to show a distinct "limit reached" message instead
    // of the generic setup/auth prompt.
    function isRateLimited() { return _rateLimited; }

    // Why the last run failed. One opaque "it failed" made a dropped phone link, a
    // press inside the cooldown, a container-cap rejection and a real server error all
    // render identically as "No connection — retry" — indistinguishable on the wrist
    // and undiagnosable in the field, which is exactly how a working watch and a
    // capped account looked the same.
    static const FAIL_NONE       = 0;
    static const FAIL_NO_PHONE   = 1;
    static const FAIL_COOLDOWN   = 2;
    static const FAIL_AUTH       = 3;
    static const FAIL_RATE_LIMIT = 4;
    static const FAIL_CONTAINER  = 5;
    static const FAIL_NETWORK    = 6;
    static const FAIL_STALE_AUTH = 7;

    function failReason() { return _failReason; }

    // Short, wrist-readable reason for the failure banner.
    function failText() {
        if (_failReason == FAIL_NO_PHONE)   { return "No phone link"; }
        if (_failReason == FAIL_COOLDOWN)   { return "Just updated — wait"; }
        if (_failReason == FAIL_CONTAINER)  { return "Container limit — MENU"; }
        if (_failReason == FAIL_RATE_LIMIT) { return "Daily limit — try tomorrow"; }
        // A rejected refresh is a sign-in problem, not a server fault. "Server error
        // 400" told the user nothing and hid the fact that re-pairing is the way out.
        if (_failReason == FAIL_STALE_AUTH) { return "Sign-in expired — retry to re-pair"; }
        // A real transport/server failure: name it. B9 says never show a bare "-104",
        // and _friendlyError is the existing mapping that turns codes into words.
        if (_lastCode != 0) { return DeviceAuthManager._friendlyError(_lastCode); }
        return "Update failed — retry";
    }

    // True when the sync stopped because the stored credentials are unusable
    // (UNCONFIGURED / NEEDS_REBOOTSTRAP) rather than because the phone link or the
    // API was momentarily unavailable. ONLY this justifies sending the user through
    // pairing: a BLE dropout, a timeout or a 5xx also fail the chain, and treating
    // those as an auth failure is what made the widget demand a re-auth after a
    // spell of poor connectivity.
    function authFailed() { return _authFailed; }

    // True when a container could not be created because the account is at the container
    // cap (not a bad descriptor). Onboarding offers "delete all containers and retry".
    function containerCreateFailed() { return _createFailed; }

    // Any data call returning 429 (incl. BMW's 403+CU-429, normalized upstream) means
    // the daily limit is hit: record it, block the background poll until tomorrow, and
    // stop the chain. Returns true when it handled (rate-limited) the step.
    function _stop429(responseCode) {
        if (responseCode == 429) {
            _rateLimited = true;
            _failReason  = FAIL_RATE_LIMIT;
            QuotaGuard.onQuotaExceeded();
            // Start the foreground cooldown so a rate-limited refresh can't be re-tapped
            // immediately and re-run the token/container chain on every press.
            Application.Storage.setValue(KEY_LAST_FG, Time.now().value());
            _finish(false);
            return true;
        }
        return false;
    }

    // A 401 means BMW rejected the access token even though the stored expiry said it
    // was good (clock skew, or a token invalidated server-side). Nothing else would
    // recover: ensureValidToken trusts KEY_ACCESS_EXPIRY, and the generic error path
    // just backs off. Invalidate the token and re-run the chain once with a fresh one.
    // Returns true when it handled (restarted or stopped) the step.
    function _stop401(responseCode) {
        if (responseCode != 401) { return false; }
        TokenManager.invalidateAccessToken();
        if (_retried401) {
            _finish(false);
            return true;
        }
        _retried401 = true;
        _token.ensureValidToken(method(:onToken));
        return true;
    }

    // A 403 whose body did not explain itself. On this API that is usually a container
    // the current client cannot use: containers belong to the client that created them,
    // and a re-pair leaves the cached ids untouched — which is exactly why re-pairing
    // alone kept returning 403 while signing out (which DOES drop the ids) fixed it.
    // Re-discover once, which is what signing out achieved by hand. Only a SECOND 403,
    // now with freshly resolved containers, is read as BMW's daily limit — reading the
    // first one that way would arm a 24-hour block over a one-call fix.
    function _stop403(responseCode) {
        if (responseCode != 403) { return false; }
        if (!_retried403) {
            _retried403    = true;
            CarDataClient.invalidateContainers();
            _containerId   = null;
            _bgContainerId = null;
            _token.ensureValidToken(method(:onToken));
            return true;
        }
        _rateLimited = true;
        _failReason  = FAIL_RATE_LIMIT;
        QuotaGuard.onQuotaExceeded();
        Application.Storage.setValue(KEY_LAST_FG, Time.now().value());
        _finish(false);
        return true;
    }

    static const COOLDOWN_SECONDS = 60;         // minimum gap between full foreground refreshes
    static const FULL_INTERVAL_SECONDS = 86400; // auto full (About-car) fetch at most once/day
    static const KEY_LAST_FG   = "lastForegroundSync";
    static const KEY_LAST_FULL = "lastFullFetch";

    // isManual: a START-button refresh always does a FULL fetch (all pages + About-car).
    // Auto (on app open) does a full fetch only once per day; otherwise it just ensures the
    // containers exist and lets the background poll keep the live fields fresh.
    function run(onDone, isManual) {
        _onDone = onDone;
        // The invalid_grant strike threshold depends on who asked: after a START press
        // the user is watching and can act on a re-auth prompt now; the auto sync on
        // app open is unattended and gets the longer run (TokenManager._strikeLimit).
        _token.setManual(isManual);
        // Pre-flight the phone link. Without it every request returns -104
        // BLE_CONNECTION_UNAVAILABLE and the chain fails in a way that is
        // indistinguishable, to the caller, from an auth failure.
        if (!System.getDeviceSettings().phoneConnected) {
            _failReason = FAIL_NO_PHONE;
            _finish(false);
            return;
        }
        // Respect BMW's daily limit. The foreground is deliberately exempt from the
        // routine 40-minute gate — a START press should fetch — but not from the daily
        // block: retrying into an API that is already refusing burns nothing but the
        // budget and keeps the limit from clearing.
        if (QuotaGuard.isDailyBlocked()) {
            _rateLimited = true;
            _failReason  = FAIL_RATE_LIMIT;
            _finish(false);
            return;
        }
        var now = Time.now().value();
        var lastFull = Application.Storage.getValue(KEY_LAST_FULL);
        var dailyDue = (lastFull == null) || (now - lastFull >= FULL_INTERVAL_SECONDS);
        _fullFetch = isManual || dailyDue;
        // 1-minute cooldown guard for full fetches — prevents rapid re-taps hammering the API.
        if (_fullFetch) {
            var lastSync = Application.Storage.getValue(KEY_LAST_FG);
            if (lastSync != null && (now - lastSync) < COOLDOWN_SECONDS) {
                _failReason = FAIL_COOLDOWN;
                _finish(false);
                return;
            }
        }
        // Access tokens last ~1h; ensure a valid one (refresh if needed) first.
        _token.ensureValidToken(method(:onToken));
    }

    function onToken(success as Lang.Boolean) as Void {
        if (!success) {
            // The refresh knows why it failed; the chain otherwise loses that entirely.
            _lastCode = _token.getLastResponseCode();
            // A 400 here is BMW rejecting the grant, not a server fault — say so, and
            // say what fixes it. Each attempt is also a strike, so repeating it reaches
            // the re-pair prompt (TokenManager._strikeLimit).
            if (_lastCode == 400) { _failReason = FAIL_STALE_AUTH; }
            _finish(false);
            return;
        }
        _accessToken = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
        if (_accessToken == null) { _finish(false); return; }

        // Step 1: VIN — resolve, else discover.
        _vin = _resolveVin();
        if (_vin == null) {
            _boot.fetchMappings(_accessToken, method(:onVin));
        } else {
            onVin(200, _vin);
        }
    }

    function onVin(responseCode as Lang.Number, vin) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        if (_stop401(responseCode)) { return; }
        if (vin == null) { _finish(false); return; }
        _vin = vin;

        // Step 2a: FULL container (foreground telematic incl. About-car detail) —
        // use a known one, else discover existing, else create.
        _containerId = _resolveFullContainer();
        if (_containerId != null) {
            onFullContainer(200, _containerId);
        } else {
            _boot.fetchContainers(_accessToken, CarDataClient._CONTAINER_NAME, false, method(:onFullContainerList));
        }
    }

    function onFullContainerList(responseCode as Lang.Number, containerId) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        if (_stop401(responseCode)) { return; }
        if (containerId != null) {
            onFullContainer(200, containerId);
        } else {
            _boot.createContainer(_accessToken, CarDataClient._CONTAINER_NAME,
                CarDataBootstrap._containerDescriptors(), false, method(:onFullContainer));
        }
    }

    function onFullContainer(responseCode as Lang.Number, containerId) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        if (_stop401(responseCode)) { return; }
        if (containerId == null) {
            // Couldn't resolve/create the full container — flag the cap case for onboarding.
            _createFailed = _boot.createCapFailure();
            if (_createFailed) { _failReason = FAIL_CONTAINER; }
            _finish(false);
            return;
        }
        _containerId = containerId;

        // Step 2b: LEAN background container — ensure it exists so the background poll
        // has a small-enough response to deserialize. Resolve, else discover, else create.
        _bgContainerId = _resolveBgContainer();
        if (_bgContainerId != null) {
            onBgContainer(200, _bgContainerId);
        } else {
            _boot.fetchContainers(_accessToken, CarDataClient._BG_CONTAINER_NAME, true, method(:onBgContainerList));
        }
    }

    function onBgContainerList(responseCode as Lang.Number, containerId) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        if (_stop401(responseCode)) { return; }
        if (containerId != null) {
            onBgContainer(200, containerId);
        } else {
            _boot.createContainer(_accessToken, CarDataClient._BG_CONTAINER_NAME,
                CarDataBootstrap._bgContainerDescriptors(), true, method(:onBgContainer));
        }
    }

    // Best-effort: a failed bg container must NOT block the foreground sync (which still
    // shows data now). If it failed, the background poll simply has no container until
    // the next successful sync.
    function onBgContainer(responseCode as Lang.Number, containerId) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        if (_stop401(responseCode)) { return; }
        // A bg-container create rejected by the cap blocks onboarding too (so cleanup can be
        // offered). A non-cap bg failure stays best-effort — the foreground still proceeds.
        if (containerId == null && _boot.createCapFailure()) {
            _createFailed = true;
            _failReason   = FAIL_CONTAINER;
            _finish(false);
            return;
        }
        // Containers now exist. A FULL fetch (basicData + tyre + full telematic) runs only
        // on a manual START or once/day; otherwise the background poll keeps live fields
        // fresh and we stop here without spending a data call.
        if (!_fullFetch) {
            _finish(true);
            return;
        }
        // On a 401 retry the About-car extras were already fetched (or already failed)
        // on the first pass. Re-issuing them would double the quota cost of every 401
        // — go straight to the telematic call the retry exists for.
        if (_retried401) {
            _client.fetchTelematicData(_vin, _containerId, _accessToken, method(:onTelematic));
            return;
        }
        // Step 3: basicData (best-effort), then tyre, then full telematic.
        _boot.fetchBasicData(_vin, _accessToken, method(:onBasic));
    }

    function onBasic(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        // Best-effort for ordinary failures, but a 401 means every remaining call is
        // doomed too — refresh now instead of burning them.
        if (_stop401(responseCode)) { return; }
        _boot.fetchTyreDiagnosis(_vin, _accessToken, method(:onTyreDiag));
    }

    function onTyreDiag(responseCode as Lang.Number, tyreKm as Lang.Dictionary or Null) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        if (_stop401(responseCode)) { return; }
        _tyreKm = tyreKm;  // best-effort — proceed regardless of success
        _client.fetchTelematicData(_vin, _containerId, _accessToken, method(:onTelematic));
    }

    function onTelematic(responseCode as Lang.Number, state as Lang.Dictionary or Null) as Void {
        if (responseCode != 200) { _lastCode = responseCode; }
        if (_stop429(responseCode)) { return; }
        if (_stop403(responseCode)) { return; }
        if (_stop401(responseCode)) { return; }
        if (responseCode == 200 && state != null) {
            // Merge tyre wear km (from separate endpoint) into the telematic state before writing.
            if (_tyreKm != null) {
                var wkeys = ["tyreWearKmFL", "tyreWearKmFR", "tyreWearKmRL", "tyreWearKmRR"];
                for (var i = 0; i < wkeys.size(); i++) {
                    if (_tyreKm.hasKey(wkeys[i])) { state[wkeys[i]] = _tyreKm[wkeys[i]]; }
                }
            }
            // "last upd" tracks the latest successful FETCH time (temporary, until the
            // pipeline stabilizes) — stamp now so the age resets on every fetch.
            state["lastUpdated"] = Time.now().value();
            VehicleCache.write(state);
            // Vehicle data is in hand — THIS is what proves the current grant works, so
            // the pre-rotation refresh token held as a fallback can finally be retired.
            TokenManager.confirmGrant();
            QuotaGuard.updateAfterFetch();
            QuotaGuard.clearBackoff();   // a working link retires any error backoff
            Application.Storage.setValue(KEY_LAST_FG, Time.now().value());
            Application.Storage.setValue(KEY_LAST_FULL, Time.now().value());
            // Re-assert the background poll schedule. Manual mode's daily 10:00
            // event is one-shot; if its re-registration in onTemporalEvent ever
            // failed silently, the chain stays broken until the app re-registers —
            // any successful manual refresh is a natural point to re-arm it.
            Application.getApp()._applyUpdateMode();
            _finish(true);
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

    function _resolveFullContainer() {
        var c = CarDataClient.cachedContainerId();
        if (c == null) { c = Application.Properties.getValue("containerId"); }
        if (c != null && c.equals("")) { c = null; }
        return c;
    }

    // Auto-created/-discovered only — no manual Settings fallback for the bg container.
    function _resolveBgContainer() {
        var c = CarDataClient.cachedBgContainerId();
        if (c != null && c.equals("")) { c = null; }
        return c;
    }

    function _finish(success) {
        if (!success) {
            // Classify the failure for the caller (see authFailed()). Only a
            // credential-level token state counts as an auth failure; a null state
            // means a first-run refresh never got an answer, which is transient.
            var ts = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
            _authFailed = (ts != null
                && (ts.equals("UNCONFIGURED") || ts.equals("NEEDS_REBOOTSTRAP")));
            // Only fill in a reason if no specific one was recorded on the way here.
            if (_failReason == FAIL_NONE) {
                _failReason = _authFailed ? FAIL_AUTH : FAIL_NETWORK;
            }
        }
        if (_onDone != null) { _onDone.invoke(success); }
    }

}
