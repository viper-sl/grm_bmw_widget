// Main widget view — page manager with isVisible() skip navigation.
// Pages: [PageVehicle(hidden), PageRangeFuel, PageLock, PageOdometer, PageTyres]
// Navigation dots drawn on left edge. Re-link prompt when NEEDS_REBOOTSTRAP.
// No slide animation — instant page switch for Fenix 6 CPU performance.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class BmwWidgetView extends WatchUi.View {

    var _pages;
    var _pageIdx;
    var _autoSyncStarted;
    var _autoSyncFailed;
    var _sync;

    function initialize() {
        View.initialize();
        _pages = [
            new PageVehicle(),
            new PageRangeFuel(),
            new PageLock(),
            new PageOdometer(),
            new PageTyres()
        ];
        _pageIdx         = _firstVisibleIndex();
        _autoSyncStarted = false;
        _autoSyncFailed  = false;
    }

    function retryAutoSync() {
        _autoSyncStarted = true;
        _autoSyncFailed  = false;
        _sync = new ForegroundSync();
        _sync.run(method(:onAutoSyncDone));
        WatchUi.requestUpdate();
    }

    function onAutoSyncDone(success) {
        _autoSyncFailed = !success;
        WatchUi.requestUpdate();
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var tokenState = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (tokenState != null && tokenState.equals("NEEDS_REBOOTSTRAP")) {
            _drawRelinkPrompt(dc);
            return;
        }

        var hasVisible = false;
        for (var i = 0; i < _pages.size(); i++) {
            if (_pages[i].isVisible()) { hasVisible = true; break; }
        }
        if (!hasVisible) {
            var paired = (tokenState != null && tokenState.equals("NORMAL"));
            if (paired && !_autoSyncStarted) {
                _autoSyncStarted = true;
                _sync = new ForegroundSync();
                _sync.run(method(:onAutoSyncDone));
            }
            if (_autoSyncStarted && !_autoSyncFailed) {
                _drawLoading(dc);
            } else {
                _drawSetupPrompt(dc);
            }
            return;
        }

        if (!_pages[_pageIdx].isVisible()) {
            _pageIdx = _firstVisibleIndex();
        }

        if (_pageIdx >= 0 && _pageIdx < _pages.size()) {
            _pages[_pageIdx].onUpdate(dc);
        }

        _drawNavDots(dc);
    }

    function onNextPage() {
        var start = _pageIdx;
        var count = _pages.size();
        var i = (_pageIdx + 1) % count;
        while (i != start) {
            if (_pages[i].isVisible()) {
                _pageIdx = i;
                WatchUi.requestUpdate();
                return true;
            }
            i = (i + 1) % count;
        }
        return false;
    }

    function onPreviousPage() {
        var start = _pageIdx;
        var count = _pages.size();
        var i = (_pageIdx - 1 + count) % count;
        while (i != start) {
            if (_pages[i].isVisible()) {
                _pageIdx = i;
                WatchUi.requestUpdate();
                return true;
            }
            i = (i - 1 + count) % count;
        }
        return false;
    }

    function onSelect() {
        if (_autoSyncFailed) {
            retryAutoSync();
            return true;
        }
        if (_pageIdx >= 0 && _pageIdx < _pages.size() && _pages[_pageIdx].isVisible()) {
            return _pages[_pageIdx].onSelect();
        }
        return false;
    }

    function needsAuth() {
        var tokenState = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (tokenState != null && tokenState.equals("NORMAL")) { return false; }
        if (tokenState != null && tokenState.equals("NEEDS_REBOOTSTRAP")) { return true; }
        for (var i = 0; i < _pages.size(); i++) {
            if (_pages[i].isVisible()) { return false; }
        }
        return true;
    }

    function _firstVisibleIndex() {
        for (var i = 0; i < _pages.size(); i++) {
            if (_pages[i].isVisible()) { return i; }
        }
        return 0;
    }

    function _drawNavDots(dc) {
        var count = _pages.size();
        var dotR = 3;
        var spacing = 10;
        var totalH = (count - 1) * spacing;
        var startY = (dc.getHeight() - totalH) / 2;
        var x = 8;
        for (var i = 0; i < count; i++) {
            if (!_pages[i].isVisible()) { continue; }
            var y = startY + i * spacing;
            if (i == _pageIdx) {
                dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
                dc.fillCircle(x, y, dotR);
            } else {
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawCircle(x, y, dotR);
            }
        }
    }

    function _drawLoading(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.drawText(cx, cy - 8, Graphics.FONT_SMALL, "Loading…",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(cx, cy + 14, Graphics.FONT_XTINY, "fetching vehicle data",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawSetupPrompt(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.drawText(cx, cy - 18, Graphics.FONT_SMALL, "BMW Widget",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(cx, cy + 8, Graphics.FONT_TINY, "Press START to connect",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawRelinkPrompt(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, cy - 18, Graphics.FONT_SMALL, "Re-auth needed",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(cx, cy + 8, Graphics.FONT_TINY, "Press START to re-pair",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
