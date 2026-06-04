using Toybox.WatchUi;

class PageNav {

    static var _v0 = null;  // PageRangeFuel
    static var _v1 = null;  // PageLock
    static var _v2 = null;  // PageOdometer
    static var _v3 = null;  // PageTyres
    static var _idx = 0;
    static const _N = 4;

    static function initialize() {
        if (_v0 == null) {
            _v0 = new PageRangeFuel();
            _v1 = new PageLock();
            _v2 = new PageOdometer();
            _v3 = new PageTyres();
        }
        if (!_isVisible(_idx)) { _idx = _firstVisible(); }
    }

    static function hasVisible() {
        for (var i = 0; i < _N; i++) {
            if (_isVisible(i)) { return true; }
        }
        return false;
    }

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

    static function switchToCurrent(transition) {
        _switchTo(_idx, transition);
    }

    static function selectCurrent() {
        if (_idx == 0 && _v0 != null) { return _v0.onSelect(); }
        if (_idx == 1 && _v1 != null) { return _v1.onSelect(); }
        if (_idx == 2 && _v2 != null) { return _v2.onSelect(); }
        if (_idx == 3 && _v3 != null) { return _v3.onSelect(); }
        return false;
    }

    static function visibleCount() {
        var n = 0;
        for (var i = 0; i < _N; i++) {
            if (_isVisible(i)) { n++; }
        }
        return n;
    }

    static function activeRank() {
        var rank = 0;
        for (var i = 0; i < _N; i++) {
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
        return false;
    }

    static function _firstVisible() {
        for (var i = 0; i < _N; i++) {
            if (_isVisible(i)) { return i; }
        }
        return 0;
    }

    static function _switchTo(i, transition) {
        if (i == 0 && _v0 != null) { WatchUi.switchToView(_v0, new PageDelegate(), transition); }
        else if (i == 1 && _v1 != null) { WatchUi.switchToView(_v1, new PageDelegate(), transition); }
        else if (i == 2 && _v2 != null) { WatchUi.switchToView(_v2, new PageDelegate(), transition); }
        else if (i == 3 && _v3 != null) { WatchUi.switchToView(_v3, new PageDelegate(), transition); }
    }

}
