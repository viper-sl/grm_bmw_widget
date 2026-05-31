// Glance surface — widget carousel line. Read-only from VehicleCache. No network I/O.
// CIQ 3.4.x (fēnix 6 Pro): fonts are Graphics.FONT_*, justification is Graphics.TEXT_JUSTIFY_*.
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
        var state = VehicleCache.read();

        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cy = h / 2;

        if (state == null) {
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(4, cy, Graphics.FONT_TINY, "BMW — setup needed",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var isStale = false;
        if (state.hasKey("lastUpdated")) {
            isStale = (Time.now().value() - state["lastUpdated"]) > 3600;
        }
        var textColor = isStale ? Theme.COLOR_MUTED : Theme.COLOR_TEXT;

        var rangeKm = state.hasKey("rangeKm") ? state["rangeKm"] : null;

        // Range bar (bottom, full width)
        if (rangeKm != null) {
            var barH = 4;
            var barY = h - barH;
            var barW = rangeKm * w / 700;
            if (barW > w) { barW = w; }
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.fillRectangle(0, barY, w, barH);
            dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
            dc.fillRectangle(0, barY, barW, barH);
        }

        // Status line: lock · range · fuel
        var lineY = cy - 6;
        var xPos  = 4;
        var font  = Graphics.FONT_TINY;

        if (state.hasKey("doorsLocked")) {
            var lockStr = state["doorsLocked"] ? "[L] " : "[U] ";
            dc.setColor(state["doorsLocked"] ? Theme.COLOR_OK : Theme.COLOR_WARN, Theme.COLOR_BG);
            dc.drawText(xPos, lineY, font, lockStr, Graphics.TEXT_JUSTIFY_LEFT);
            xPos += dc.getTextWidthInPixels(lockStr, font);
        }

        dc.setColor(textColor, Theme.COLOR_BG);
        var rangeStr = (rangeKm != null) ? (rangeKm.toString() + "km ") : "--km ";
        dc.drawText(xPos, lineY, font, rangeStr, Graphics.TEXT_JUSTIFY_LEFT);
        xPos += dc.getTextWidthInPixels(rangeStr, font);

        var fuelPercent = state.hasKey("fuelPercent") ? state["fuelPercent"] : null;
        var fuelLitres  = state.hasKey("fuelLitres")  ? state["fuelLitres"]  : null;
        var fuelStr;
        if (fuelPercent != null && fuelPercent < 50 && fuelLitres != null) {
            var tank = Application.Properties.getValue("tankLitres");
            if (tank == null) { tank = 52; }
            fuelStr = (tank - fuelLitres).toString() + "L+";
            dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
        } else if (fuelPercent != null) {
            fuelStr = fuelPercent.toString() + "%";
            dc.setColor(textColor, Theme.COLOR_BG);
        } else {
            fuelStr = "--%";
            dc.setColor(textColor, Theme.COLOR_BG);
        }
        dc.drawText(xPos, lineY, font, fuelStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

}
