// Page: Tyres compact — matches UX mock page 5.
// Header "BMW 218i · Tyres" · 2x2 grid: position (muted) / value / OK|LOW status.
// Warning (amber "LOW") if actual < target - 0.2 bar. OK toggles actual ↔ target.
using Toybox.Graphics;
using Toybox.WatchUi;

class PageTyres extends WatchUi.View {

    var _mode;  // 0=actual pressure  1=target pressure  2=wear km remaining

    function initialize() {
        View.initialize();
        _mode = 0;
    }

    function onSelect() {
        _mode = (_mode + 1) % 3;
        WatchUi.requestUpdate();
        return true;
    }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("tyrePressureFL");
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

        var label = (_mode == 1) ? "TARGET (BAR)" : (_mode == 2) ? "WEAR (KM)" : "TYRES (BAR)";
        PageChrome.drawLabel(dc, label, cy - PageChrome.s(dc, 56));

        var colL = cx - PageChrome.s(dc, 44);
        var colR = cx + PageChrome.s(dc, 44);
        var row1 = cy - PageChrome.s(dc, 16);
        var row2 = cy + PageChrome.s(dc, 36);

        _cell(dc, colL, row1, "FRONT L", state, "tyrePressureFL", "tyreTargetFL", "tyreWearKmFL");
        _cell(dc, colR, row1, "FRONT R", state, "tyrePressureFR", "tyreTargetFR", "tyreWearKmFR");
        _cell(dc, colL, row2, "REAR L",  state, "tyrePressureRL", "tyreTargetRL", "tyreWearKmRL");
        _cell(dc, colR, row2, "REAR R",  state, "tyrePressureRR", "tyreTargetRR", "tyreWearKmRR");

        PageChrome.drawAge(dc, state);
        PageChrome.drawNavDots(dc);
        PageChrome.drawSelectHint(dc);
    }

    function _cell(dc, x, y, name, state, pKey, tKey, wKey) {
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
        dc.drawText(x, y - PageChrome.s(dc, 12), Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_mode == 2) {
            var km = state.hasKey(wKey) ? state[wKey] : null;
            if (km == null) {
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawText(x, y + PageChrome.s(dc, 12), Graphics.FONT_TINY, "--",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                dc.setColor(km < 5000 ? Theme.COLOR_WARN : Theme.COLOR_OK, Theme.COLOR_BG);
                dc.drawText(x, y + PageChrome.s(dc, 12), Graphics.FONT_TINY, km.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            return;
        }

        var actual = state.hasKey(pKey) ? state[pKey] : null;
        var target = state.hasKey(tKey) ? state[tKey] : null;
        var value  = (_mode == 1) ? target : actual;

        if (value == null) {
            dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(x, y + PageChrome.s(dc, 12), Graphics.FONT_TINY, "--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var color;
        if (_mode == 1) {
            color = Theme.COLOR_MUTED;
        } else {
            var low = (target != null && actual < (target - 0.2));
            color = low ? Theme.COLOR_WARN : Theme.COLOR_OK;
        }
        dc.setColor(color, Theme.COLOR_BG);
        dc.drawText(x, y + PageChrome.s(dc, 12), Graphics.FONT_TINY, PageChrome.oneDecimal(value),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
