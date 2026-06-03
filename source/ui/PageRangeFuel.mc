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

    function initialize() {
        View.initialize();
        var saved = Application.Storage.getValue("fuelDisplayMode");
        _fuelMode = (saved != null) ? saved : FUEL_MODE_PERCENT;
    }

    function onSelect() {
        _fuelMode = (_fuelMode == FUEL_MODE_PERCENT) ? FUEL_MODE_LITERS : FUEL_MODE_PERCENT;
        Application.Storage.setValue("fuelDisplayMode", _fuelMode);
        WatchUi.requestUpdate();
        return true;
    }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("rangeKm") && state.hasKey("fuelPercent");
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();
        var state = VehicleCache.read();
        if (state == null) { return; }
        _renderDirect(dc, state);
    }

    function _renderDirect(dc, state) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        PageChrome.drawAccent(dc);
        PageChrome.drawHeader(dc, null);

        var rangeKm     = state.hasKey("rangeKm")    ? state["rangeKm"]    : null;
        var fuelPercent = state.hasKey("fuelPercent") ? state["fuelPercent"] : null;

        var lowFuel  = (fuelPercent != null && fuelPercent < 50);
        var barColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_ACCENT;

        PageChrome.drawLabel(dc, "RANGE (KM)", cy - 58);
        PageChrome.drawValue(dc, (rangeKm != null) ? rangeKm.toString() : "--",
            Graphics.FONT_NUMBER_MEDIUM, cy - 8, Theme.COLOR_WHITE);

        var pct = (rangeKm != null) ? (rangeKm.toFloat() / 700.0) : 0.0;
        PageChrome.drawBar(dc, pct, cy + 40, barColor);

        if (_fuelMode == FUEL_MODE_LITERS) {
            var tankProp = Application.Properties.getValue("tankLitres");
            var tank = (tankProp != null) ? tankProp : 52;
            // Derive liters in tank from percent × capacity for consistency.
            // fuelLitres from API can disagree with fuelPercent when tank size differs.
            var inTank = (fuelPercent != null) ? ((tank * fuelPercent) / 100) : null;
            var fuelStr;
            var fuelColor;
            if (inTank != null) {
                var fill = tank - inTank;
                if (fill < 0) { fill = 0; }
                fuelStr   = inTank.toNumber().toString() + "L in  " + fill.toNumber().toString() + "L to fill";
                fuelColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_WHITE;
            } else {
                fuelStr   = "FUEL  --";
                fuelColor = Theme.COLOR_MUTED;
            }
            dc.setColor(fuelColor, Theme.COLOR_BG);
            dc.drawText(cx, cy + 62, Graphics.FONT_XTINY, fuelStr,
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
