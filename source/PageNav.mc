// Static page registry for switchToView()-based navigation.
// Owns the page instances and current index so all delegates share state.
class PageNav {

    static var _pages = null;
    static var _idx   = 0;

    static function initialize() {
        if (_pages == null) {
            _pages = [
                new PageVehicle(),
                new PageRangeFuel(),
                new PageLock(),
                new PageOdometer(),
                new PageTyres()
            ];
        }
        // re-anchor idx to a visible page on every call (data may have changed)
        if (!_pages[_idx].isVisible()) {
            _idx = _firstVisible();
        }
    }

    // Current visible page (null if none visible yet).
    static function current() {
        if (_pages == null) { return null; }
        var p = _pages[_idx];
        return p.isVisible() ? p : null;
    }

    // Advance by dir (+1 = next, -1 = prev). Returns true if moved.
    static function advance(dir) {
        if (_pages == null) { return false; }
        var count = _pages.size();
        var start = _idx;
        var i     = (_idx + dir + count) % count;
        while (i != start) {
            if (_pages[i].isVisible()) { _idx = i; return true; }
            i = (i + dir + count) % count;
        }
        return false;
    }

    // [visibleTotal, activeRank] for nav dots.
    static function visibleInfo() {
        if (_pages == null) { return [0, 0]; }
        var total = 0;
        var rank  = 0;
        for (var i = 0; i < _pages.size(); i++) {
            if (!_pages[i].isVisible()) { continue; }
            if (i == _idx) { rank = total; }
            total++;
        }
        return [total, rank];
    }

    static function _firstVisible() {
        if (_pages == null) { return 0; }
        for (var i = 0; i < _pages.size(); i++) {
            if (_pages[i].isVisible()) { return i; }
        }
        return 0;
    }

}
