// Setup / loading shell view.
// Handles the pre-data states (loading, setup prompt, re-link prompt).
// As soon as a data page becomes visible it switches to it via switchToView,
// handing off to PageDelegate for all subsequent navigation.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class BmwWidgetView extends WatchUi.View {

    var _autoSyncStarted;
    var _autoSyncFailed;
    var _rateLimited;     // auto-sync failed because BMW's daily API limit was reached
    var _sync;

    function initialize() {
        View.initialize();
        _autoSyncStarted = false;
        _autoSyncFailed  = false;
        _rateLimited     = false;
    }

    function retryAutoSync() {
        _autoSyncStarted = true;
        _autoSyncFailed  = false;
        _rateLimited     = false;
        _sync = new ForegroundSync();
        _sync.run(method(:onAutoSyncDone), false);  // auto: full fetch only once/day
        WatchUi.requestUpdate();
    }

    function onAutoSyncDone(success) {
        _autoSyncFailed = !success;
        _rateLimited    = (!success && _sync != null && _sync.isRateLimited());
        WatchUi.requestUpdate();
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        // Seed the lean glance projection from the full state if an upgrade left it
        // missing (foreground 64 KB heap — safe to touch the full dict here).
        VehicleCache.ensureGlanceSummary();

        var tokenState = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);

        // Re-link prompt.
        if (tokenState != null && tokenState.equals("NEEDS_REBOOTSTRAP")) {
            dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
            dc.clear();
            _drawRelinkPrompt(dc);
            return;
        }

        // Transition to first data page as soon as one is visible.
        PageNav.initialize();
        if (PageNav.hasVisible()) {
            PageNav.switchToCurrent(WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        // No visible pages yet — draw loading / setup.
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();
        var paired = (tokenState != null && tokenState.equals("NORMAL"));
        if (paired && !_autoSyncStarted) {
            _autoSyncStarted = true;
            _sync = new ForegroundSync();
            _sync.run(method(:onAutoSyncDone), false);  // auto: full fetch only once/day
        }
        if (_autoSyncStarted && !_autoSyncFailed) {
            _drawLoading(dc);
        } else if (_rateLimited) {
            _drawRateLimited(dc);
        } else {
            _drawSetupPrompt(dc);
        }
    }

    function needsAuth() {
        var ts = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (ts != null && ts.equals("NORMAL"))            { return false; }
        if (ts != null && ts.equals("NEEDS_REBOOTSTRAP")) { return true;  }
        return !PageNav.hasVisible();
    }

    function onSelect()       { return false; }
    function onNextPage()     { return false; }
    function onPreviousPage() { return false; }

    function _drawLoading(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.drawText(cx, cy - PageChrome.s(dc, 8), Graphics.FONT_SMALL, "Loading…",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(cx, cy + PageChrome.s(dc, 14), Graphics.FONT_XTINY, "fetching vehicle data",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawSetupPrompt(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.drawText(cx, cy - PageChrome.s(dc, 18), Graphics.FONT_SMALL, "BMW Widget",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(cx, cy + PageChrome.s(dc, 8), Graphics.FONT_TINY, "Press START to connect",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Daily BMW API limit reached — distinct from "not set up". Shows cached data
    // normally (this only renders when no page is visible yet, i.e. no cached data).
    function _drawRateLimited(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, cy - PageChrome.s(dc, 18), Graphics.FONT_SMALL, "Daily limit reached",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(cx, cy + PageChrome.s(dc, 8), Graphics.FONT_TINY, "Try again tomorrow",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawRelinkPrompt(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, cy - PageChrome.s(dc, 18), Graphics.FONT_SMALL, "Re-auth needed",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(cx, cy + PageChrome.s(dc, 8), Graphics.FONT_TINY, "Press START to re-pair",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
