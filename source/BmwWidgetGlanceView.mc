// Glance surface — Garmin native-widget style: BMW icon on the left, three compact
// rows on the right.
//   row 1:  LOCKED            653 km     (white)
//   row 2:  ▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭  fuel bar (red, width = fuel %)
//   row 3:  70%               1d ago     (fuel orange, age dimmed)
// A yellow ⚠ sits left of the age once the last few fetches failed (WarnIcon).
// Low fuel (<50%): fuel cell shows "XX% (+YYL)" instead of just "XX%" — the "+"
// marks YY as litres still needed to fill the tank, not litres currently in it.
// YY comes from FuelMath (percent × tank setting), the same source the Range &
// Fuel page uses, so the glance and the page always quote the same litres.
// Read-only: reads the lean KEY_GLANCE_STATE projection straight from Storage (NOT via
// VehicleCache — see onUpdate). No network I/O.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
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
        // Read the lean glance projection straight from Storage — deliberately NOT via
        // VehicleCache: referencing that class would pull its full write/merge bytecode
        // into the glance code image (the glance gets its own ~28 KB partition). The key
        // is produced by VehicleCache._writeGlanceSummary on every cache write. Reading
        // the full ~40-key Vehicle State here would OOM (won't fit) — the 2026-06-15 crash.
        var state = Application.Storage.getValue(StorageKeys.KEY_GLANCE_STATE) as Lang.Dictionary or Null;

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

        // ── row 1: lock state (left) + range (right) — pure white ──
        // B1: always draw a label. When doorsLocked is known, LOCKED/OPEN; when it's
        // absent (INVALID/UNKNOWN/no-signal) draw a muted "—" so the row never goes blank.
        var row1Color = Theme.COLOR_WHITE;
        if (state.hasKey("doorsLocked")) {
            dc.setColor(row1Color, Theme.COLOR_BG);
            dc.drawText(textX, row1Y, font, state["doorsLocked"] ? "LOCKED" : "OPEN",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(textX, row1Y, font, "—",
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
        if (fuelPercent != null && fuelPercent < 50) {
            // Derived from the percent via FuelMath — same math the Range & Fuel
            // page uses, so the two surfaces can't disagree. (They used to: this
            // read the raw "fuelLitres" field, which BMW leaves frozen at the last
            // refuel — see the FuelMath header.)
            fuelStr = fuelPercent.toString()
                + "% (+" + FuelMath.litresToFill(fuelPercent).toString() + "L)";
        } else if (fuelPercent != null) {
            fuelStr = fuelPercent.toString() + "%";
        } else {
            fuelStr = "FUEL --";
        }
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
        dc.drawText(textX, row3Y, font, fuelStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var ageStr = null;
        if (state.hasKey("lastUpdated")) {
            ageStr = _ageString(Time.now().value() - state["lastUpdated"]);
        }

        // Warning triangle left of the age when the last few fetches failed (read
        // straight from Storage — QuotaGuard.isFailing would pull that class in here).
        var fails = Application.Storage.getValue(StorageKeys.KEY_FETCH_FAILS);
        if (fails != null && fails >= StorageKeys.FETCH_FAILS_WARN) {
            var iconH = (lineH * 2) / 3;
            var iconW = WarnIcon.width(iconH);
            // Low fuel makes the left cell long ("35% (+40L)"); if the triangle would
            // collide with it, drop " ago" — the triangle already says "look here".
            var fuelW = dc.getTextDimensions(fuelStr, font)[0];
            if (ageStr != null
                    && textX + fuelW + 6 + iconW + 3 + dc.getTextDimensions(ageStr, font)[0] > rightX) {
                ageStr = ageStr.substring(0, ageStr.length() - 4);
            }
            var ageW = (ageStr != null) ? dc.getTextDimensions(ageStr, font)[0] + 3 : 0;
            WarnIcon.draw(dc, rightX - ageW - iconW / 2, row3Y, iconH);
        }

        if (ageStr != null) {
            dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
            dc.drawText(rightX, row3Y, font, ageStr,
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
