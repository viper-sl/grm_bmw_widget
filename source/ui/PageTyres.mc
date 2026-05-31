// Page: Tyres compact — matches UX mock page 5.
// Header "BMW 218i · Tyres" · 2x2 grid: position (muted) / bar value (white) / OK|LOW status.
// Warning (amber "LOW") if actual < target - 0.2 bar.
using Toybox.Graphics;
using Toybox.WatchUi;

class PageTyres extends WatchUi.View {

    function initialize() { View.initialize(); }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("tyrePressureFL");
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var state = VehicleCache.read();
        if (state == null) { return; }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        PageChrome.drawAccent(dc);
        PageChrome.drawHeader(dc, " · Tyres (bar)");

        // 2 lines per cell → wider row gap, no overlap
        var colL = cx - 44;
        var colR = cx + 44;
        var row1 = cy - 24;
        var row2 = cy + 28;

        _cell(dc, colL, row1, "FRONT L", state, "tyrePressureFL", "tyreTargetFL");
        _cell(dc, colR, row1, "FRONT R", state, "tyrePressureFR", "tyreTargetFR");
        _cell(dc, colL, row2, "REAR L",  state, "tyrePressureRL", "tyreTargetRL");
        _cell(dc, colR, row2, "REAR R",  state, "tyrePressureRR", "tyreTargetRR");

        PageChrome.drawAge(dc, state);
    }

    // One tyre cell: position label (muted) over value (colored green=OK / amber=LOW).
    // Status conveyed by value color — no separate status line (saves vertical space).
    function _cell(dc, x, y, name, state, pKey, tKey) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(x, y - 10, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var actual = state.hasKey(pKey) ? state[pKey] : null;
        var target = state.hasKey(tKey) ? state[tKey] : null;

        if (actual == null) {
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(x, y + 8, Graphics.FONT_TINY, "--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var low = (target != null && actual < (target - 0.2));
        dc.setColor(low ? Theme.COLOR_WARN : Theme.COLOR_OK, Theme.COLOR_BG);
        dc.drawText(x, y + 8, Graphics.FONT_TINY, PageChrome.oneDecimal(actual),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
