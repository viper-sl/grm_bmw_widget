// On-device auth screen. Drives DeviceAuthManager and renders its FSM state.
// Opened from the widget when tokenState is NEEDS_REBOOTSTRAP/UNCONFIGURED, or from
// the glance/setup prompt. Shows the user code to enter on the BMW site, then polls.
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

    function initialize(auth) {
        View.initialize();
        _auth = auth;
        _synced = false;
        _rateLimited = false;
        _cleaning = false;
        _cleanupFailed = false;
    }

    function onLayout(dc) {}

    function onShow() {
        // Redraw whenever the device-flow state advances.
        _auth.setOnChange(method(:onAuthChange));
        if (_auth.getState() == DeviceAuthManager.IDLE) {
            _auth.start();
        }
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
        _deleter = null;
        if (success) {
            // Containers cleared — retry the full onboarding fetch (re-creates the pair).
            _sync = new ForegroundSync();
            _sync.run(method(:onSyncDone), true);
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

        if (st == DeviceAuthManager.REQUESTING || st == DeviceAuthManager.IDLE) {
            _center(dc, cx, cy, Graphics.FONT_SMALL, Theme.COLOR_TEXT, "Connecting…");
            return;
        }

        if (st == DeviceAuthManager.PENDING) {
            // Title
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(cx, cy - 58, Graphics.FONT_XTINY, "Pair on bmw site",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            // The code the user types on the BMW pairing page. Use a TEXT font, not
            // FONT_NUMBER_* — user codes are alphanumeric and number fonts have no letters.
            dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
            dc.drawText(cx, cy - 16, Graphics.FONT_LARGE, _auth.getUserCode(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            // Hint
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(cx, cy + 30, Graphics.FONT_XTINY, "Waiting for approval…",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx, cy + 50, Graphics.FONT_XTINY, "customer.bmwgroup.com",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (st == DeviceAuthManager.SUCCESS) {
            if (_cleaning) {
                _center(dc, cx, cy - 10, Graphics.FONT_SMALL, Theme.COLOR_TEXT, "Cleaning up…");
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawText(cx, cy + 16, Graphics.FONT_XTINY, "deleting containers",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
            if (_cleanupFailed) {
                _center(dc, cx, cy - 12, Graphics.FONT_SMALL, Theme.COLOR_WARN, "Cleanup failed");
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawText(cx, cy + 14, Graphics.FONT_XTINY, "BACK to exit, then retry",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
            if (_rateLimited) {
                // Paired OK, but the daily API limit blocks the first fetch.
                _center(dc, cx, cy - 22, Graphics.FONT_SMALL, Theme.COLOR_OK, "Paired");
                dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
                dc.drawText(cx, cy + 2, Graphics.FONT_XTINY, "Daily API limit reached",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawText(cx, cy + 22, Graphics.FONT_XTINY, "Data loads tomorrow",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.drawText(cx, cy + 42, Graphics.FONT_XTINY, "BACK to exit",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
            _center(dc, cx, cy - 10, Graphics.FONT_SMALL, Theme.COLOR_OK, "Paired");
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(cx, cy + 16, Graphics.FONT_XTINY, "Fetching data…",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // FAILED
        _center(dc, cx, cy - 12, Graphics.FONT_SMALL, Theme.COLOR_WARN, "Auth failed");
        var msg = _auth.getError();
        if (msg != null) {
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(cx, cy + 14, Graphics.FONT_XTINY, msg,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx, cy + 34, Graphics.FONT_XTINY, "BACK to retry",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function _center(dc, x, y, font, color, text) {
        dc.setColor(color, Theme.COLOR_BG);
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
