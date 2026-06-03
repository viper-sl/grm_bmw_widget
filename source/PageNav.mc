// Static page registry for switchToView()-based navigation.
//
// MONKEY C TYPE RULE: array subscript _pages[i] returns Object — custom
// methods like isVisible() / onSelect() don't exist on Object and cause
// Symbol Not Found at runtime. Solution: store each page in a named typed
// var so Monkey C infers the concrete type from the assignment, then
// dispatch with if-else rather than indexing.
using Toybox.WatchUi;

class PageNav {

    static var _v0 = null;  // PageVehicle  (type inferred from new PageVehicle())
    static var _v1 = null;  // PageRangeFuel
    static var _v2 = null;  // PageLock
    static var _v3 = null;  // PageOdometer
    static var _v4 = null;  // PageTyres
    static var _idx = 0;
    static const _N = 5;

    static function initialize() {
        if (_v0 == null) {
            _v0 = new PageVehicle();
            _v1 = new PageRangeFuel();
            _v2 = new PageLock();
            _v3 = new PageOdometer();
            _v4 = new PageTyres();
        }
        if (!_isVisible(_idx)) { _idx = _firstVisible(); }
    }

    // True when at least one data page has visible content.
    static function hasVisible() {
        for (var i = 0; i < _N; i++) {
            if (_isVisible(i)) { return true; }
        }
        return false;
    }

    // Advance by dir (+1 = next/DOWN, -1 = prev/UP) and switchToView with the
    // appropriate slide direction. Returns false if no other visible page.
    static function advance(dir) {
        var start = _idx;
        var i = (_idx + dir + _N) % _N;
        while (i != start) {
            if (_isVisible(i)) {
                _idx = i;
                var t = (dir > 0) ? WatchUi.SLIDE_UP : WatchUi.SLIDE_DOWN;
                _switchTo(_idx, t);
                return true;
            }
            i = (i + dir + _N) % _N;
        }
        return false;
    }

    // Switch to the current page. Call this once from BmwWidgetView when data arrives.
    static function switchToCurrent(transition) {
        _switchTo(_idx, transition);
    }

    // Route onSelect() to the current page with full type safety.
    static function selectCurrent() {
        if (_idx == 0 && _v0 != null) { return _v0.onSelect(); }
        if (_idx == 1 && _v1 != null) { return _v1.onSelect(); }
        if (_idx == 2 && _v2 != null) { return _v2.onSelect(); }
        if (_idx == 3 && _v3 != null) { return _v3.onSelect(); }
        if (_idx == 4 && _v4 != null) { return _v4.onSelect(); }
        return false;
    }

    // Number of visible pages (for nav dots).
    static function visibleCount() {
        var n = 0;
        for (var i = 0; i < _N; i++) {
            if (_isVisible(i)) { n++; }
        }
        return n;
    }

    // 0-based rank of current page among visible pages (for active nav dot).
    static function activeRank() {
        var rank = 0;
        for (var i = 0; i < _N; i++) {
            if (!_isVisible(i)) { continue; }
            if (i == _idx) { return rank; }
            rank++;
        }
        return 0;
    }

    // ── private helpers ───────────────────────────────────────────────────────

    // Each branch uses a typed var so isVisible() dispatches correctly.
    static function _isVisible(i) {
        if (i == 0) { return _v0 != null && _v0.isVisible(); }
        if (i == 1) { return _v1 != null && _v1.isVisible(); }
        if (i == 2) { return _v2 != null && _v2.isVisible(); }
        if (i == 3) { return _v3 != null && _v3.isVisible(); }
        if (i == 4) { return _v4 != null && _v4.isVisible(); }
        return false;
    }

    static function _firstVisible() {
        for (var i = 0; i < _N; i++) {
            if (_isVisible(i)) { return i; }
        }
        return 0;
    }

    // switchToView with typed view reference so no Object-method dispatch.
    static function _switchTo(i, transition) {
        if (i == 0 && _v0 != null) { WatchUi.switchToView(_v0, new PageDelegate(), transition); }
        else if (i == 1 && _v1 != null) { WatchUi.switchToView(_v1, new PageDelegate(), transition); }
        else if (i == 2 && _v2 != null) { WatchUi.switchToView(_v2, new PageDelegate(), transition); }
        else if (i == 3 && _v3 != null) { WatchUi.switchToView(_v3, new PageDelegate(), transition); }
        else if (i == 4 && _v4 != null) { WatchUi.switchToView(_v4, new PageDelegate(), transition); }
    }

}
