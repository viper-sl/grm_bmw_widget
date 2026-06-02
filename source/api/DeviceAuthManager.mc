// On-device OAuth 2.0 Device Authorization Grant (RFC 8628) with PKCE.
// Foreground only — interactive: shows a user code, polls for approval, stores tokens.
// Mirrors the reference bmw_cardata_probe.py device_flow().
//
// Flow:
//   1. POST /gcdm/oauth/device/code  (client_id, response_type=device_code, scope,
//      code_challenge, code_challenge_method=S256)  -> user_code + verification URL + device_code
//   2. Show user_code on screen; user approves on BMW site in a browser.
//   3. Poll POST /gcdm/oauth/token (grant_type=device_code, client_id, device_code,
//      code_verifier) every `interval` s until access_token is returned.
//   4. Persist tokens to Storage; set tokenState = NORMAL.
//
// The owning View polls getState()/getUserCode() to render progress.
using Toybox.Application;
using Toybox.Communications;
using Toybox.Cryptography;
using Toybox.Lang;
using Toybox.StringUtil;
using Toybox.Time;
using Toybox.Timer;

class DeviceAuthManager {

    static const _AUTH_HOST   = "https://customer.bmwgroup.com";
    static const _DEVICE_URL  = "https://customer.bmwgroup.com/gcdm/oauth/device/code";
    static const _TOKEN_URL   = "https://customer.bmwgroup.com/gcdm/oauth/token";
    static const _SCOPE       = "authenticate_user openid cardata:streaming:read cardata:api:read";

    // FSM states (also drive the auth View rendering).
    static const IDLE        = 0;  // not started
    static const REQUESTING  = 1;  // device-code request in flight
    static const PENDING     = 2;  // showing user code, polling for approval
    static const SUCCESS     = 3;  // tokens stored
    static const FAILED      = 4;  // unrecoverable (bad client id, expired, network)

    var _state;
    var _userCode;          // shown to the user
    var _verificationUri;   // where the user approves
    var _deviceCode;        // polled back to the token endpoint
    var _codeVerifier;      // PKCE verifier (kept for the token exchange)
    var _interval;          // poll seconds (server-provided)
    var _expiresAt;         // epoch when the device code dies
    var _pollTimer;
    var _errMsg;
    var _onChange;          // callback the View registers to trigger a redraw

    function initialize() {
        _state = IDLE;
        _userCode = null;
        _verificationUri = null;
        _errMsg = null;
    }

    function getState()       { return _state; }
    function getUserCode()    { return _userCode; }
    function getVerifyUri()   { return _verificationUri; }
    function getError()       { return _errMsg; }

    // The View passes a method() here; we invoke it whenever state changes so it can requestUpdate.
    function setOnChange(cb)  { _onChange = cb; }

    function _notify() {
        if (_onChange != null) { _onChange.invoke(); }
    }

    // Kick off the device flow. clientId from Settings, else the baked-in personal value.
    function start() {
        var clientId = Config.clientId();
        if (clientId == null || clientId.equals("")) {
            _state = FAILED;
            _errMsg = "No client ID in settings";
            _notify();
            return;
        }

        _codeVerifier = _makePkceVerifier();
        var challenge = _pkceChallenge(_codeVerifier);

        _state = REQUESTING;
        _notify();

        Communications.makeWebRequest(
            _DEVICE_URL,
            {
                "client_id"             => clientId,
                "response_type"         => "device_code",
                "scope"                 => _SCOPE,
                "code_challenge"        => challenge,
                "code_challenge_method" => "S256"
            },
            {
                :method       => Communications.HTTP_REQUEST_METHOD_POST,
                :headers      => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onDeviceCodeResponse)
        );
    }

    function onDeviceCodeResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        if (responseCode != 200 || data == null || !data.hasKey("device_code")) {
            _state = FAILED;
            _errMsg = "Device code HTTP " + responseCode;
            _notify();
            return;
        }

        _deviceCode      = data["device_code"];
        _userCode        = data.hasKey("user_code") ? data["user_code"] : "?";
        _verificationUri = data.hasKey("verification_uri_complete")
                            ? data["verification_uri_complete"]
                            : (data.hasKey("verification_uri") ? data["verification_uri"] : _AUTH_HOST);
        _interval        = data.hasKey("interval") ? data["interval"] : 5;
        var expiresIn    = data.hasKey("expires_in") ? data["expires_in"] : 300;
        _expiresAt       = Time.now().value() + expiresIn;

        _state = PENDING;
        _notify();

        _schedulePoll();
    }

    function _schedulePoll() {
        if (_pollTimer == null) { _pollTimer = new Timer.Timer(); }
        // Timer in ms; _interval is seconds.
        _pollTimer.start(method(:_poll), _interval * 1000, false);
    }

    function _poll() as Void {
        if (Time.now().value() >= _expiresAt) {
            _state = FAILED;
            _errMsg = "Code expired — retry";
            _notify();
            return;
        }
        var clientId = Config.clientId();
        Communications.makeWebRequest(
            _TOKEN_URL,
            {
                "grant_type"    => "urn:ietf:params:oauth:grant-type:device_code",
                "client_id"     => clientId,
                "device_code"   => _deviceCode,
                "code_verifier" => _codeVerifier
            },
            {
                :method       => Communications.HTTP_REQUEST_METHOD_POST,
                :headers      => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onPollResponse)
        );
    }

    function onPollResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        if (responseCode == 200 && data != null && data.hasKey("access_token")) {
            // Persist tokens (refresh token first — atomic rotation rule).
            if (data.hasKey("refresh_token") && data["refresh_token"] != null) {
                Application.Storage.setValue(StorageKeys.KEY_REFRESH_TOKEN, data["refresh_token"]);
            }
            Application.Storage.setValue(StorageKeys.KEY_ACCESS_TOKEN, data["access_token"]);
            var expiresIn = (data.hasKey("expires_in") && data["expires_in"] != null)
                ? data["expires_in"].toNumber() : 3600;
            Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY, Time.now().value() + expiresIn);
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");

            _state = SUCCESS;
            _notify();
            return;
        }

        // RFC 8628: authorization_pending (keep polling), slow_down (back off), else fail.
        var err = (data != null && data.hasKey("error")) ? data["error"] : "";
        if (err.equals("authorization_pending") || responseCode == 403) {
            _schedulePoll();
        } else if (err.equals("slow_down")) {
            _interval += 5;
            _schedulePoll();
        } else {
            _state = FAILED;
            _errMsg = err.equals("") ? ("HTTP " + responseCode) : err;
            _notify();
        }
    }

    function stop() {
        if (_pollTimer != null) { _pollTimer.stop(); }
    }

    // --- PKCE helpers (S256) ---

    // 32 random bytes -> base64url (no padding). Doubles as both the verifier value.
    function _makePkceVerifier() {
        var raw = Cryptography.randomBytes(32);
        return _base64Url(raw);
    }

    // challenge = base64url( SHA256( ASCII(verifier) ) )
    function _pkceChallenge(verifier) {
        var hash = new Cryptography.Hash({ :algorithm => Cryptography.HASH_SHA256 });
        hash.update(_asciiBytes(verifier));
        return _base64Url(hash.digest());
    }

    // String -> ByteArray of its UTF-8/ASCII bytes.
    function _asciiBytes(s) {
        var arr = s.toUtf8Array();
        var ba = new [arr.size()]b;
        for (var i = 0; i < arr.size(); i++) { ba[i] = arr[i]; }
        return ba;
    }

    // ByteArray -> base64url string (standard base64 then +/ -> -_ , strip '=').
    function _base64Url(bytes) {
        var b64 = StringUtil.convertEncodedString(bytes, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation   => StringUtil.REPRESENTATION_STRING_BASE64
        });
        var out = "";
        for (var i = 0; i < b64.length(); i++) {
            var c = b64.substring(i, i + 1);
            if (c.equals("+"))      { out += "-"; }
            else if (c.equals("/")) { out += "_"; }
            else if (c.equals("=")) { /* drop padding */ }
            else                    { out += c; }
        }
        return out;
    }

}
