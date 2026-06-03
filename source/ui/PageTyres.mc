// Page: Tyres compact — matches UX mock page 5.
// Header "BMW 218i · Tyres" · 2x2 grid: position (muted) / value / OK|LOW status.
// Warning (amber "LOW") if actual < target - 0.2 bar. OK toggles actual ↔ target.
using Toybox.Graphics;
using Toybox.WatchUi;

class PageTyres extends WatchUi.View {

    var _showTarget;

    function initialize() {
        View.initialize();
        _showTarget = false;
    }

    function onSelect() {
        _showTarget = !_showTarget;
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
