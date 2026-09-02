// On-device auth screen. Drives DeviceAuthManager and renders its FSM state.
// Opened from the widget when tokenState is NEEDS_REBOOTSTRAP/UNCONFIGURED, or from
// the glance/setup prompt. Shows the user code to enter on the BMW site, then polls.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class AuthView extends WatchUi.View {

    var _auth;
    var _sync;
    var _synced;        // guard: run the post-auth fetch only once
    var _rateLimited;   // post-pair fetch failed because BMW's daily limit was reached
    var _deleter;       // keeps the async ContainerDeleter alive during cleanup
    var _cleaning;      // cleanup (delete-all) in progress
    var _cleanupFailed; // the delete-all could not complete
    var _token;         // keeps the async TokenManager alive during recovery
    var _recovering;    // silent refresh attempt in progress (pre-device-flow)
    var _recoverOk;     // the silent refresh worked — no device flow needed
    var _recoverTried;  // guard: attempt the silent refresh at most once
    var _allowRecover;  // false when the user explicitly asked to re-pair

    function initialize(auth) {
        View.initialize();
        _auth = auth;
        _synced = false;
        _rateLimited = false;
        _cleaning = false;
        _cleanupFailed = false;
        _recovering = false;
        _recoverOk = false;
        _recoverTried = false;
        _allowRecover = true;
    }

    // Called by the Settings "Re-pair" item: the user asked for the device flow by
    // name, so don't quietly resolve it with a token refresh instead.
    function setAllowRecover(allow) { _allowRecover = allow; }

    function onLayout(dc) {}

    function onShow() {
        // Redraw whenever the device-flow state advances.
        _auth.setOnChange(method(:onAuthChange));
        if (_auth.getState() != DeviceAuthManager.IDLE) { return; }

        // A latched NEEDS_REBOOTSTRAP is not always real: a refresh whose response was
        // lost in transit leaves the watch holding a rotated-away token and produces
        // the same 400 as a dead grant. Spend one quota-exempt refresh before making
        // the user re-pair — if it succeeds the latch clears and the widget carries on.
        var ts = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (_allowRecover && !_recoverTried
                && ts != null && ts.equals("NEEDS_REBOOTSTRAP")) {
            _recoverTried = true;
            _recovering   = true;
            _token = new TokenManager();
            _token.retryAfterRebootstrap(method(:onRecoverDone));
            WatchUi.requestUpdate();
            return;
        }
        _auth.start();
    }

    // Silent-refresh outcome: on success the stored grant was fine all along, so fetch
    // data and drop back to the widget; on failure fall through to the device flow.
    function onRecoverDone(success) {
        _recovering = false;
        _recoverOk  = success;
        if (success) {
            _synced = true;
            _sync = new ForegroundSync();
            _sync.run(method(:onSyncDone), true);
        } else {
            _auth.start();
        }
        WatchUi.requestUpdate();
    }

    function onHide() {
        _auth.setOnChange(null);
    }

    function onAuthChange() {
        // On first SUCCESS, immediately fetch data in the foreground so the user
        // sees their vehicle right after pairing.
        if (_auth.getState() == DeviceAuthManager.SUCCESS && !_synced) {
            _synced = true;
            _sync = new ForegroundSync();
            _sync.run(method(:onSyncDone), true);  // post-pair: do a full fetch
        }
        WatchUi.requestUpdate();
    }

    function onSyncDone(success) {
        // Rate-limited: pairing succeeded but BMW's daily API limit blocks the fetch.
        // Stay on this view to show a clear message rather than dropping to a blank widget.
        if (!success && _sync != null && _sync.isRateLimited()) {
            _rateLimited = true;
            WatchUi.requestUpdate();
            return;
        }
        // Container cap: pairing worked but a container can't be created because the BMW
        // account is at its container limit. Ask the user before wiping all containers.
        if (!success && _sync != null && _sync.containerCreateFailed()) {
            WatchUi.pushView(
                new WatchUi.Confirmation("Container limit reached. Delete all containers and retry?"),
                new ContainerLimitDelegate(method(:onCleanupConfirmed)),
                WatchUi.SLIDE_UP);
            return;
        }
        // Data is now in VehicleCache (or not). Pop back to the widget either way;
        // the carousel will show pages if the fetch populated the cache.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // User confirmed the cleanup: delete every container, then retry onboarding.
    function onCleanupConfirmed() {
        _cleaning = true;
        _cleanupFailed = false;
        WatchUi.requestUpdate();
        _deleter = new ContainerDeleter();
        _deleter.run(method(:onCleanupDone));
    }

    function onCleanupDone(success) {
        _cleaning = false;
        var limited = (_deleter != null && _deleter.isRateLimited());
        _deleter = null;
        if (success) {
            // Containers cleared — retry the full onboarding fetch (re-creates the pair).
            _sync = new ForegroundSync();
            _sync.run(method(:onSyncDone), true);
        } else if (limited) {
            // Hit the daily limit while clearing — show the rate-limit message.
            _rateLimited = true;
        } else {
            _cleanupFailed = true;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();
        PageChrome.drawAccent(dc);

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var st = _auth.getState();

        if (_recovering) {
            _center(dc, cx, cy - PageChrome.s(dc, 10), Graphics.FONT_SMALL, Theme.COLOR_TEXT, "Reconnecting…");
            dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + PageChrome.s(dc, 16), Graphics.FONT_XTINY, "checking saved login",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (st == DeviceAuthManager.REQUESTING || st == DeviceAuthManager.IDLE) {
            if (_recoverOk) {
                // Recovered without re-pairing — the post-recovery fetch is running.
                _center(dc, cx, cy - PageChrome.s(dc, 10), Graphics.FONT_SMALL, Theme.COLOR_OK, "Reconnected");
                dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy + PageChrome.s(dc, 16), Graphics.FONT_XTINY, "Fetching data…",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
            _center(dc, cx, cy, Graphics.FONT_SMALL, Theme.COLOR_TEXT, "Connecting…");
            return;
        }

        if (st == DeviceAuthManager.PENDING) {
            // Title + full verification URL (domain / path on two lines so the
            // whole customer.bmwgroup.com/oneid/#/link fits from 260px to 454px).
            dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - PageChrome.s(dc, 64), Graphics.FONT_XTINY, "Enter code at",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - PageChrome.s(dc, 48), Graphics.FONT_XTINY, "customer.bmwgroup.com",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx, cy - PageChrome.s(dc, 34), Graphics.FONT_XTINY, "/oneid/#/link",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            // The code the user types on the BMW pairing page. Use a TEXT font, not
            // FONT_NUMBER_* — user codes are alphanumeric and number fonts have no letters.
            dc.setColor(Theme.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - PageChrome.s(dc, 6), Graphics.FONT_LARGE, _auth.getUserCode(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            // Hint
            dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + PageChrome.s(dc, 42), Graphics.FONT_XTINY, "Waiting for approval…",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (st == DeviceAuthManager.SUCCESS) {
            if (_cleaning) {
                _center(dc, cx, cy - PageChrome.s(dc, 10), Graphics.FONT_SMALL, Theme.COLOR_TEXT, "Cleaning up…");
                dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy + PageChrome.s(dc, 16), Graphics.FONT_XTINY, "deleting containers",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
            if (_cleanupFailed) {
                _center(dc, cx, cy - PageChrome.s(dc, 12), Graphics.FONT_SMALL, Theme.COLOR_WARN, "Cleanup failed");
                dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy + PageChrome.s(dc, 14), Graphics.FONT_XTINY, "BACK to exit, then retry",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
            if (_rateLimited) {
                // Paired OK, but the daily API limit blocks the first fetch.
                _center(dc, cx, cy - PageChrome.s(dc, 22), Graphics.FONT_SMALL, Theme.COLOR_OK, "Paired");
                dc.setColor(Theme.COLOR_WARN, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy + PageChrome.s(dc, 2), Graphics.FONT_XTINY, "Daily limit reached",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy + PageChrome.s(dc, 22), Graphics.FONT_XTINY, "Try again tomorrow",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.drawText(cx, cy + PageChrome.s(dc, 42), Graphics.FONT_XTINY, "BACK to exit",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
            _center(dc, cx, cy - PageChrome.s(dc, 10), Graphics.FONT_SMALL, Theme.COLOR_OK, "Paired");
            dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + PageChrome.s(dc, 16), Graphics.FONT_XTINY, "Fetching data…",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // FAILED
        _center(dc, cx, cy - PageChrome.s(dc, 40), Graphics.FONT_SMALL, Theme.COLOR_WARN, "Auth failed");
        var msg = _auth.getError();
        if (msg != null) {
            // Word-wrap: BMW's error_description is a full sentence and clips on
            // the round screen as one line. Draw it over as many lines as needed.
            dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
            var bottom = _drawWrapped(dc, cx, cy - PageChrome.s(dc, 14),
                (dc.getWidth() * 82) / 100, Graphics.FONT_XTINY, msg);
            dc.setColor(Theme.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bottom + lineH, Graphics.FONT_XTINY, "BACK to retry",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Greedy word-wrap. Draws `text` centered at x, top-anchored at y, wrapping
    // to maxW. Returns the y of the last line drawn (for placing text below it).
    function _drawWrapped(dc, x, y, maxW, font, text) {
        var words = _split(text, " ");
        var lineH = dc.getFontHeight(font);
        var line = "";
        var cursorY = y;
        for (var i = 0; i < words.size(); i++) {
            var candidate = line.equals("") ? words[i] : line + " " + words[i];
            if (dc.getTextWidthInPixels(candidate, font) > maxW && !line.equals("")) {
                dc.drawText(x, cursorY, font, line,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                cursorY += lineH;
                line = words[i];
            } else {
                line = candidate;
            }
        }
        if (!line.equals("")) {
            dc.drawText(x, cursorY, font, line,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        return cursorY;
    }

    // Minimal splitter (Monkey C strings have no split()).
    function _split(s, sep) {
        var out = [];
        var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var c = s.substring(i, i + 1);
            if (c.equals(sep)) {
                if (!cur.equals("")) { out.add(cur); cur = ""; }
            } else {
                cur += c;
            }
        }
        if (!cur.equals("")) { out.add(cur); }
        return out;
    }

    function _center(dc, x, y, font, color, text) {
        // TRANSPARENT bg: avoid line-box erasure clipping neighbors (see BmwWidgetView)
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}

// Closes the auth view on BACK (and stops polling). On SUCCESS the widget will
// re-evaluate and show data; on FAILED, BACK lets the user exit/retry.
class AuthDelegate extends WatchUi.BehaviorDelegate {

    var _auth;

    function initialize(auth) {
        BehaviorDelegate.initialize();
        _auth = auth;
    }

    function onBack() {
        _auth.stop();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

}

// Yes/No dialog shown when onboarding hits the container cap. On "Yes" it invokes the
// supplied callback (which deletes all containers and retries); "No" just dismisses.
class ContainerLimitDelegate extends WatchUi.ConfirmationDelegate {

    var _onYes;

    function initialize(onYes) {
        ConfirmationDelegate.initialize();
        _onYes = onYes;
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            _onYes.invoke();
        }
        return true;
    }

}
