// Page: Range & Fuel — matches UX mock page 2.
// Header "BMW 218i" · label "RANGE" · big white km · red bar · fuel row.
// Low fuel (<50%): bar+fuel turn amber, shows "{tank-litres}L to fill".
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class PageRangeFuel extends WatchUi.View {

    function initialize() { View.initialize(); }

    function onSelect() { return false; } // no OK action on this page

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("rangeKm") && state.hasKey("fuelPercent");
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var state = VehicleCache.read();
        if (state == null) { return; }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        PageChrome.drawAccent(dc);
        PageChrome.drawHeader(dc, null);

        var rangeKm     = state.hasKey("rangeKm") ? state["rangeKm"] : null;
        var fuelPercent = state.hasKey("fuelPercent") ? state["fuelPercent"] : null;
        var fuelLitres  = state.hasKey("fuelLitres") ? state["fuelLitres"] : null;

        var lowFuel = (fuelPercent != null && fuelPercent < 50);
        var barColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_ACCENT;

        // Label · big value (no standalone unit line — RANGE label implies km, and the
        // number font is tall; a unit row here forces collisions on a 260px screen).
        PageChrome.drawLabel(dc, "RANGE (KM)", cy - 58);
        PageChrome.drawValue(dc, (rangeKm != null) ? rangeKm.toString() : "--",
            Graphics.FONT_NUMBER_MEDIUM, cy - 8, Theme.COLOR_TEXT);

        // Range bar (% of ~700 km)
        var pct = (rangeKm != null) ? (rangeKm.toFloat() / 700.0) : 0.0;
        PageChrome.drawBar(dc, pct, cy + 40, barColor);

        // Fuel row
        var fuelStr;
        var fuelColor;
        if (lowFuel && fuelLitres != null) {
            var tank = Application.Properties.getValue("tankLitres");
            if (tank == null) { tank = 52; }
            var fill = tank - fuelLitres;
            if (fill < 0) { fill = 0; }
            fuelStr = fuelPercent.toString() + "%  " + fill.toString() + "L to fill";
            fuelColor = Theme.COLOR_WARN;
        } else if (fuelPercent != null) {
            fuelStr = "FUEL  " + fuelPercent.toString() + "%";
            fuelColor = Theme.COLOR_TEXT;
        } else {
            fuelStr = "FUEL  --";
            fuelColor = Theme.COLOR_MUTED;
        }
        dc.setColor(fuelColor, Theme.COLOR_BG);
        dc.drawText(cx, cy + 60, Graphics.FONT_TINY, fuelStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        PageChrome.drawAge(dc, state);
    }

}
