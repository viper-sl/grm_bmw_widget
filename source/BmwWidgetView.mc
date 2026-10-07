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
    var _offline;         // auto-sync failed for a non-credential reason
    var _offlineText;     // why, in words (ForegroundSync.failText)
    var _lastWasManual;   // the last run came from a START press, not app open
    var _sync;

    function initialize() {
        View.initialize();
        _autoSyncStarted = false;
        _autoSyncFailed  = false;
        _rateLimited     = false;
        _offline         = false;
        _offlineText     = null;
        _lastWasManual   = false;
    }

    function retryAutoSync() {
        _autoSyncStarted = true;
        _autoSyncFailed  = false;
        _rateLimited     = false;
        _offline         = false;
        _offlineText     = null;
        // Only ever reached from onSelect() — a START press IS a manual refresh. Passing
        // false here judged the user's own retries at the unattended strike threshold
        // and skipped the full fetch they were asking for.
        _lastWasManual   = true;
        _sync = new ForegroundSync();
        _sync.run(method(:onAutoSyncDone), true);
        WatchUi.requestUpdate();
    }

    function onAutoSyncDone(success) {
        _autoSyncFailed = !success;
        _rateLimited    = (!success && _sync != null && _sync.isRateLimited());
        // BMW rejected the refresh outright and the user asked for this. Offer pairing
        // now: it is cheap and reversible (BACK comes straight back here), unlike
        // latching NEEDS_REBOOTSTRAP, which the strike ladder still governs. Making
        // them press START N times to earn the only screen that fixes it is not a
        // safety property. Never on the unattended open-sync.
        if (!success && _lastWasManual && _sync != null
                && _sync.failReason() == ForegroundSync.FAIL_STALE_AUTH) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);
            return;
        }
        // A link-level failure must not fall through to the setup prompt: telling a
        // paired user to "press START to connect" because the phone was out of range
        // is how a dropout turns into an unnecessary re-pair.
        _offline        = (!success && _sync != null
                            && !_sync.isRateLimited() && !_sync.authFailed());
        _offlineText    = _offline ? _sync.failText() : null;
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
            _lastWasManual = false;
            _sync = new ForegroundSync();
            _sync.run(method(:onAutoSyncDone), false);  // auto: full fetch only once/day
        }
        if (_autoSyncStarted && !_autoSyncFailed) {
            _drawLoading(dc);
        } else if (_rateLimited) {
            _drawRateLimited(dc);
        } else if (_offline) {
            _drawOffline(dc);
        } else {
            _drawSetupPrompt(dc);
        }
    }

    function needsAuth() {
        var ts = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (ts != null && ts.equals("NEEDS_REBOOTSTRAP")) { return true;  }
        // A known link-level failure is not an auth problem — START retries instead
        // (see onSelect). Checked before NORMAL so it also covers a paired watch left
        // in NEEDS_REFRESH by a refresh that never got an answer.
        if (_offline)                                     { return false; }
        if (ts != null && ts.equals("NORMAL"))            { return false; }
        return !PageNav.hasVisible();
    }

    // START on the offline notice retries the sync (there is no page to hand it to,
    // and needsAuth() is false here, so the press would otherwise do nothing).
    function onSelect() {
        if (_offline) {
            retryAutoSync();
            return true;
        }
        return false;
    }
    function onNextPage()     { return false; }
    function onPreviousPage() { return false; }

    // NOTE: prompt screens draw stacked lines with TRANSPARENT text background —
    // the usual (fg, Theme.COLOR_BG) pair makes drawText erase its line box,
    // clipping the neighbor line's descenders on tall AMOLED fonts (the cut-off
    // "g" bug). dc.clear() above already painted the background.
    function _drawLoading(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - PageChrome.s(dc, 8), Graphics.FONT_SMALL, "Loading…",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + PageChrome.s(dc, 14), Graphics.FONT_XTINY, "fetching vehicle data",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawSetupPrompt(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - PageChrome.s(dc, 18), Graphics.FONT_SMALL, "BMW Widget",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + PageChrome.s(dc, 8), Graphics.FONT_TINY, "Press START to connect",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Daily BMW API limit reached — distinct from "not set up". Shows cached data
    // normally (this only renders when no page is visible yet, i.e. no cached data).
    function _drawRateLimited(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_WARN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - PageChrome.s(dc, 18), Graphics.FONT_SMALL, "Daily limit reached",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + PageChrome.s(dc, 8), Graphics.FONT_TINY, "Try again tomorrow",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Paired, but the fetch could not reach BMW (no phone link, timeout, 5xx).
    // Deliberately NOT the setup prompt — nothing about the pairing is wrong.
    function _drawOffline(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - PageChrome.s(dc, 24), Graphics.FONT_SMALL, "Update failed",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_WARN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_XTINY,
            (_offlineText != null) ? _offlineText : "Retry",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + PageChrome.s(dc, 22), Graphics.FONT_TINY, "Press START to retry",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawRelinkPrompt(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_WARN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - PageChrome.s(dc, 18), Graphics.FONT_SMALL, "Re-auth needed",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + PageChrome.s(dc, 8), Graphics.FONT_TINY, "Press START to re-pair",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
