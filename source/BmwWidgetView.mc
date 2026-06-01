// Main widget view — page manager with isVisible() skip navigation.
// Pages: [PageVehicle(hidden), PageRangeFuel, PageLock, PageOdometer, PageTyres]
// Navigation dots drawn on left edge. Re-link prompt when NEEDS_REBOOTSTRAP.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class BmwWidgetView extends WatchUi.View {

    var _pages;
    var _pageIdx;

    function initialize() {
        View.initialize();
        _pages = [
            new PageVehicle(),
            new PageRangeFuel(),
            new PageLock(),
            new PageOdometer(),
            new PageTyres()
        ];
        _pageIdx = _firstVisibleIndex();
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        // Re-link prompt: token needs re-authentication
        var tokenState = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (tokenState != null && tokenState.equals("NEEDS_REBOOTSTRAP")) {
            _drawRelinkPrompt(dc);
            return;
        }

        // Empty cache or all pages invisible — show setup prompt
        var hasVisible = false;
        for (var i = 0; i < _pages.size(); i++) {
            if (_pages[i].isVisible()) { hasVisible = true; break; }
        }
        if (!hasVisible) {
            _drawSetupPrompt(dc);
            return;
        }

        // Ensure _pageIdx points to a visible page
        if (!_pages[_pageIdx].isVisible()) {
            _pageIdx = _firstVisibleIndex();
        }

        // Delegate to current page
        if (_pageIdx >= 0 && _pageIdx < _pages.size()) {
            _pages[_pageIdx].onUpdate(dc);
        }

        // Navigation dots (left edge, vertical)
        _drawNavDots(dc);
    }

    // Advance to next visible page
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

    // Go back to previous visible page
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

    // START/OK pressed on a data page — route to the active page. Each page
    // implements onSelect() returning true if it handled it (image -> refresh,
    // tyres -> toggle target). Pages without behavior return false.
    function onSelect() {
        if (_pageIdx >= 0 && _pageIdx < _pages.size() && _pages[_pageIdx].isVisible()) {
            return _pages[_pageIdx].onSelect();
        }
        return false;
    }

    // True when the widget is showing the setup or re-link prompt — i.e. the user
    // should be able to launch on-device auth (START). Drives BmwWidgetDelegate.onSelect.
    function needsAuth() {
        var tokenState = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (tokenState != null && tokenState.equals("NEEDS_REBOOTSTRAP")) {
            return true;
        }
        for (var i = 0; i < _pages.size(); i++) {
            if (_pages[i].isVisible()) { return false; }
        }
        return true; // no visible pages -> setup prompt is showing
    }

    // Find the first visible page index (skipping hidden pages like PageVehicle)
    function _firstVisibleIndex() {
        for (var i = 0; i < _pages.size(); i++) {
            if (_pages[i].isVisible()) { return i; }
        }
        return 0;
    }

    // Draw vertical navigation dots on left edge (x=8)
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
