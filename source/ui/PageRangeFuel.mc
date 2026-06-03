// Page: Range & Fuel — matches UX mock page 2.
// Header "BMW 218i" · label "RANGE" · big white km · red bar · fuel row.
// OK/START toggles fuel display: percent mode (default) ↔ liters mode.
// Low fuel (<50%): bar+fuel turn amber in both modes.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class PageRangeFuel extends WatchUi.View {

    static const FUEL_MODE_PERCENT = 0;
    static const FUEL_MODE_LITERS  = 1;

    var _fuelMode;
    var _cache;
    var _cacheKey;   // lastUpdated * 10 + _fuelMode

    function initialize() {
        View.initialize();
        var saved = Application.Storage.getValue("fuelDisplayMode");
        _fuelMode = (saved != null) ? saved : FUEL_MODE_PERCENT;
        _cache    = null;
        _cacheKey = null;
    }

    function onSelect() {
        _fuelMode = (_fuelMode == FUEL_MODE_PERCENT) ? FUEL_MODE_LITERS : FUEL_MODE_PERCENT;
        Application.Storage.setValue("fuelDisplayMode", _fuelMode);
        _cache = null; // invalidate cache on mode toggle
        WatchUi.requestUpdate();
        return true;
    }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("rangeKm") && state.hasKey("fuelPercent");
    }

    // Returns cached bitmap, re-rendering if data or mode changed.
    function getCachedBitmap(dc) {
        var state = VehicleCache.read();
        if (state == null) { return null; }
        var epoch = state.hasKey("lastUpdated") ? state["lastUpdated"] : 0;
        var key   = epoch * 10 + _fuelMode;
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

        var rangeKm     = state.hasKey("rangeKm")     ? state["rangeKm"]     : null;
        var fuelPercent = state.hasKey("fuelPercent")  ? state["fuelPercent"] : null;
        var fuelLitres  = state.hasKey("fuelLitres")   ? state["fuelLitres"]  : null;

        var lowFuel  = (fuelPercent != null && fuelPercent < 50);
        var barColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_ACCENT;

        PageChrome.drawLabel(dc, "RANGE (KM)", cy - 58);
        PageChrome.drawValue(dc, (rangeKm != null) ? rangeKm.toString() : "--",
            Graphics.FONT_NUMBER_MEDIUM, cy - 8, Theme.COLOR_WHITE);

        var pct = (rangeKm != null) ? (rangeKm.toFloat() / 700.0) : 0.0;
        PageChrome.drawBar(dc, pct, cy + 40, barColor);

        if (_fuelMode == FUEL_MODE_LITERS && fuelLitres != null) {
            var tankProp = Application.Properties.getValue("tankLitres");
            var tank = (tankProp != null) ? tankProp : 52;
            var fill = tank - fuelLitres;
            if (fill < 0) { fill = 0; }
            var valueColor   = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_WHITE;
            var captionColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_MUTED;
            dc.setColor(valueColor, Theme.COLOR_BG);
            dc.drawText(cx, cy + 50, Graphics.FONT_TINY, fuelLitres.toNumber().toString() + "L in tank",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(captionColor, Theme.COLOR_BG);
            dc.drawText(cx, cy + 68, Graphics.FONT_XTINY, fill.toNumber().toString() + "L to fill",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var fuelStr;
            var fuelColor;
            if (fuelPercent != null) {
                fuelStr   = "FUEL  " + fuelPercent.toString() + "%";
                fuelColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_TEXT;
            } else {
                fuelStr   = "FUEL  --";
                fuelColor = Theme.COLOR_MUTED;
            }
            dc.setColor(fuelColor, Theme.COLOR_BG);
            dc.drawText(cx, cy + 60, Graphics.FONT_TINY, fuelStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        PageChrome.drawAge(dc, state);
        PageChrome.drawSelectHint(dc);
    }

}
