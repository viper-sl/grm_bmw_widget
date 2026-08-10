using Toybox.WatchUi;

class PageNav {

    static var _v0 = null;  // PageRangeFuel
    static var _v1 = null;  // PageLock
    static var _v2 = null;  // PageOdometer
    static var _v3 = null;  // PageTyres
    static var _idx = 0;

    // ── Map page slot — build-variant, index 4 / last (FR-37) ────────────────
    // (:mapPage) compiles on the 32 map-capable products; (:noMapPage) on the
    // four without onboard cartography. See monkey.jungle. A static const cannot
    // carry a per-build value, so the page count is a function pair.
    (:mapPage) static var _v4 = null;  // PageMap

    (:mapPage)   static function _pageCount() { return 5; }
    (:noMapPage) static function _pageCount() { return 4; }

    // The `has` check is defence in depth, not belt-and-braces theatre: compiling
    // map code for a map-incapable device SUCCEEDS (verified against fenix6), so a
    // missing jungle exclusion would ship a page that breaks on the watch rather
    // than failing the build. Guarding instantiation keeps _v4 null there, and
    // _isVisibleExtra then hides the page. Required while fenix6s/fr745 have no
    // exclusion line (see the TODO in monkey.jungle).
    (:mapPage)   static function _initExtra() {
        if (_v4 == null && (WatchUi has :MapView)) { _v4 = new PageMap(); }
    }
    (:noMapPage) static function _initExtra() { }

    (:mapPage)   static function _isVisibleExtra(i) { return i == 4 && _v4 != null && _v4.isVisible(); }
    (:noMapPage) static function _isVisibleExtra(i) { return false; }

    (:mapPage)   static function _switchExtra(i, transition) {
        if (i == 4 && _v4 != null) {
            WatchUi.switchToView(_v4, new MapPageDelegate(_v4), transition);
            return true;
        }
        return false;
    }
    (:noMapPage) static function _switchExtra(i, transition) { return false; }

    (:mapPage)   static function _selectExtra(i) {
        if (i == 4 && _v4 != null) { return _v4.onSelect(); }
        return false;
    }
    (:noMapPage) static function _selectExtra(i) { return false; }

    static function initialize() {
        if (_v0 == null) {
            _v0 = new PageRangeFuel();
            _v1 = new PageLock();
            _v2 = new PageOdometer();
            _v3 = new PageTyres();
            _initExtra();
        }
        if (!_isVisible(_idx)) { _idx = _firstVisible(); }
    }

    static function hasVisible() {
        var n = _pageCount();
        for (var i = 0; i < n; i++) {
            if (_isVisible(i)) { return true; }
        }
        return false;
    }

    static function advance(dir) {
        var n = _pageCount();
        var start = _idx;
        var i = (_idx + dir + n) % n;
        while (i != start) {
            if (_isVisible(i)) {
                _idx = i;
                var t = (dir > 0) ? WatchUi.SLIDE_UP : WatchUi.SLIDE_DOWN;
                _switchTo(_idx, t);
                return true;
            }
            i = (i + dir + n) % n;
        }
        return false;
    }

    static function switchToCurrent(transition) {
        _switchTo(_idx, transition);
    }

    static function selectCurrent() {
        if (_idx == 0 && _v0 != null) { return _v0.onSelect(); }
        if (_idx == 1 && _v1 != null) { return _v1.onSelect(); }
        if (_idx == 2 && _v2 != null) { return _v2.onSelect(); }
        if (_idx == 3 && _v3 != null) { return _v3.onSelect(); }
        return _selectExtra(_idx);
    }

    static function visibleCount() {
        var n = _pageCount();
        var count = 0;
        for (var i = 0; i < n; i++) {
            if (_isVisible(i)) { count++; }
        }
        return count;
    }

    static function activeRank() {
        var n = _pageCount();
        var rank = 0;
        for (var i = 0; i < n; i++) {
            if (!_isVisible(i)) { continue; }
            if (i == _idx) { return rank; }
            rank++;
        }
        return 0;
    }

    static function _isVisible(i) {
        if (i == 0) { return _v0 != null && _v0.isVisible(); }
        if (i == 1) { return _v1 != null && _v1.isVisible(); }
        if (i == 2) { return _v2 != null && _v2.isVisible(); }
        if (i == 3) { return _v3 != null && _v3.isVisible(); }
        return _isVisibleExtra(i);
    }

    static function _firstVisible() {
        var n = _pageCount();
        for (var i = 0; i < n; i++) {
            if (_isVisible(i)) { return i; }
        }
        return 0;
    }

    static function _switchTo(i, transition) {
        if (_switchExtra(i, transition)) { return; }
        if (i == 0 && _v0 != null) { WatchUi.switchToView(_v0, new PageDelegate(), transition); }
        else if (i == 1 && _v1 != null) { WatchUi.switchToView(_v1, new PageDelegate(), transition); }
        else if (i == 2 && _v2 != null) { WatchUi.switchToView(_v2, new PageDelegate(), transition); }
        else if (i == 3 && _v3 != null) { WatchUi.switchToView(_v3, new PageDelegate(), transition); }
    }

}
