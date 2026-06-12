// Glance surface — Garmin native-widget style: BMW icon on the left, three compact
// rows on the right.
//   row 1:  LOCKED            653 km     (white)
//   row 2:  ▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭  fuel bar (red, width = fuel %)
//   row 3:  70%               1d ago     (fuel orange, age dimmed)
// Low fuel (<50%): fuel cell shows "XX% (+YYL)" instead of just "XX%" — the "+"
// marks YY as litres still needed to fill the tank, not litres currently in it.
// Read-only from VehicleCache. No network I/O.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.WatchUi;

(:glance)
class BmwWidgetGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var state = VehicleCache.read();

        // NOTE: the BMW branding shows as the launcher icon the system renders in the
        // glance carousel (launcher_icon.png was swapped to the BMW logo). Glance scope
        // cannot resolve Rez.Drawables, so we do NOT loadResource here (it faults).
        var textX = 4;

        if (state == null) {
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(textX, h / 2, Graphics.FONT_TINY, "Press to set up",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var font = Graphics.FONT_GLANCE;
        var lineH = dc.getFontHeight(font);
        var barH  = 7;
        // Total block = row1 + gap + bar + gap + row3. Center it vertically in h.
        var gap = 5;
        var blockH = lineH + gap + barH + gap + lineH;
        var top = (h - blockH) / 2;
        var row1Y = top + lineH / 2;
        var barY  = top + lineH + gap;
        var row3Y = barY + barH + gap + lineH / 2;
        var rightX = w - 4;

        var rangeKm     = state.hasKey("rangeKm") ? state["rangeKm"] : null;
        var fuelPercent = state.hasKey("fuelPercent") ? state["fuelPercent"] : null;
        var fuelLitres  = state.hasKey("fuelLitres")  ? state["fuelLitres"]  : null;

        // ── row 1: lock state (left) + range (right) — pure white ──
        var row1Color = Theme.COLOR_WHITE;
        if (state.hasKey("doorsLocked")) {
            dc.setColor(row1Color, Theme.COLOR_BG);
            dc.drawText(textX, row1Y, font, state["doorsLocked"] ? "LOCKED" : "OPEN",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var numStr  = (rangeKm != null) ? rangeKm.toString() : "--";
        var unitStr = " km";
        var unitW   = dc.getTextDimensions(unitStr, font)[0];
        dc.setColor(row1Color, Theme.COLOR_BG);
        dc.drawText(rightX - unitW, row1Y, Graphics.FONT_GLANCE_NUMBER, numStr,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(rightX, row1Y, font, unitStr,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── row 2: fuel bar — fill width = fuel % of the row width ──
        // Bar is always colored when data is available, even if stale — the age
        // indicator in row 3 already tells the user the data is old. Grey bar
        // is reserved for "no fuel data at all" to distinguish it from 0 % fuel.
        var barX = textX;
        var barW = rightX - barX;
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.fillRectangle(barX, barY, barW, barH);
        if (fuelPercent != null) {
            var pct = fuelPercent / 100.0;
            if (pct < 0.0) { pct = 0.0; }
            if (pct > 1.0) { pct = 1.0; }
            var fillColor = (fuelPercent <= 20) ? Theme.COLOR_WARN : Theme.COLOR_ACCENT;
            dc.setColor(fillColor, Theme.COLOR_BG);
            dc.fillRectangle(barX, barY, (barW * pct).toNumber(), barH);
        }

        // ── row 3: fuel (left, ORANGE) + age (right, DIMMED) ──
        var fuelStr;
        if (fuelPercent != null && fuelPercent < 50 && fuelLitres != null) {
            var tankProp = Application.Properties.getValue("tankLitres");
            var tank = (tankProp != null) ? tankProp : 52;
            var toFill = tank - fuelLitres;
            if (toFill < 0) { toFill = 0; }
            fuelStr = fuelPercent.toString() + "% (+" + toFill.toString() + "L)";
        } else if (fuelPercent != null) {
            fuelStr = fuelPercent.toString() + "%";
        } else {
            fuelStr = "FUEL --";
        }
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
        dc.drawText(textX, row3Y, font, fuelStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (state.hasKey("lastUpdated")) {
            var ageSec = Time.now().value() - state["lastUpdated"];
            dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
            dc.drawText(rightX, row3Y, font, _ageString(ageSec),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Self-contained (glance scope only loads (:glance) classes; don't depend on PageChrome).
    function _ageString(sec) {
        if (sec < 60)    { return sec.toString() + "s ago"; }
        if (sec < 3600)  { return (sec / 60).toString() + "m ago"; }
        if (sec < 86400) { return (sec / 3600).toString() + "h ago"; }
        return (sec / 86400).toString() + "d ago";
    }

}
