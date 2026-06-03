// Page: Tyres compact — matches UX mock page 5.
// Header "BMW 218i · Tyres" · 2x2 grid: position (muted) / bar value (white) / OK|LOW status.
// Warning (amber "LOW") if actual < target - 0.2 bar.
using Toybox.Graphics;
using Toybox.WatchUi;

class PageTyres extends WatchUi.View {

    var _showTarget;   // false = actual pressures, true = target pressures
    var _cache;
    var _cacheKey;     // lastUpdated * 10 + (_showTarget ? 1 : 0)

    function initialize() {
        View.initialize();
        _showTarget = false;
        _cache      = null;
        _cacheKey   = null;
    }

    function onSelect() {
        _showTarget = !_showTarget;
        _cache = null; // invalidate cache on mode toggle
        WatchUi.requestUpdate();
        return true;
    }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("tyrePressureFL");
    }

    function getCachedBitmap(dc) {
        var state = VehicleCache.read();
        if (state == null) { return null; }
        var epoch = state.hasKey("lastUpdated") ? state["lastUpdated"] : 0;
        var key   = epoch * 10 + (_showTarget ? 1 : 0);
        if (_cache == null || key != _cacheKey) {
            _renderToCache(state);
            _cacheKey = key;
        }
        return _cache;
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();
        var state = VehicleCache.read();
        if (state == null) { return; }
        var bmp = getCachedBitmap(dc);
        if (bmp != null) {
            PageChrome.blitBuffer(dc, 0, 0, bmp);
        } else {
            _renderDirect(dc, state);
        }
    }

    function _renderToCache(state) {
        var w = System.getDeviceSettings().screenWidth;
        var h = System.getDeviceSettings().screenHeight;
        var bdc;
        if (Graphics has :createBufferedBitmap) {
            _cache = Graphics.createBufferedBitmap({:width => w, :height => h});
            var locked = _cache.get();
            if (locked == null) { _cache = null; return; }
            bdc = locked.getDc();
        } else {
            _cache = new Graphics.BufferedBitmap({:width => w, :height => h});
            bdc = _cache.getDc();
        }
        bdc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        bdc.clear();
        _renderDirect(bdc, state);
    }

    function _renderDirect(dc, state) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        PageChrome.drawAccent(dc);
        PageChrome.drawHeader(dc, null);

        PageChrome.drawLabel(dc, _showTarget ? "TARGET (BAR)" : "TYRES (BAR)", cy - 56);

        var colL = cx - 44;
        var colR = cx + 44;
        var row1 = cy - 16;
        var row2 = cy + 36;

        _cell(dc, colL, row1, "FRONT L", state, "tyrePressureFL", "tyreTargetFL");
        _cell(dc, colR, row1, "FRONT R", state, "tyrePressureFR", "tyreTargetFR");
        _cell(dc, colL, row2, "REAR L",  state, "tyrePressureRL", "tyreTargetRL");
        _cell(dc, colR, row2, "REAR R",  state, "tyrePressureRR", "tyreTargetRR");

        PageChrome.drawAge(dc, state);
        PageChrome.drawSelectHint(dc);
    }

    function _cell(dc, x, y, name, state, pKey, tKey) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(x, y - 12, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var actual = state.hasKey(pKey) ? state[pKey] : null;
        var target = state.hasKey(tKey) ? state[tKey] : null;
        var value = _showTarget ? target : actual;

        if (value == null) {
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(x, y + 12, Graphics.FONT_TINY, "--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var color;
        if (_showTarget) {
            color = Theme.COLOR_MUTED;
        } else {
            var low = (target != null && actual < (target - 0.2));
            color = low ? Theme.COLOR_WARN : Theme.COLOR_OK;
        }
        dc.setColor(color, Theme.COLOR_BG);
        dc.drawText(x, y + 12, Graphics.FONT_TINY, PageChrome.oneDecimal(value),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
