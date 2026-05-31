// Page: Lock overview — matches UX mock page 3.
// Header · "SECURED/UNLOCKED" status (green/amber) · 2x2 grid of door/trunk/hood.
// Each cell: position name (muted) over status (white, or red if OPEN).
using Toybox.Graphics;
using Toybox.WatchUi;

class PageLock extends WatchUi.View {

    function initialize() { View.initialize(); }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("doorsLocked");
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var state = VehicleCache.read();
        if (state == null) { return; }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        PageChrome.drawAccent(dc);

        // Lock status header (the hero)
        var locked = state["doorsLocked"];
        dc.setColor(locked ? Theme.COLOR_OK : Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, 52, Graphics.FONT_SMALL, locked ? "SECURED" : "UNLOCKED",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2x2 grid: columns centered around cx, two rows below center
        var colL = cx - 42;
        var colR = cx + 42;
        var row1 = cy + 4;
        var row2 = cy + 40;

        _cell(dc, colL, row1, "FRONT L", state, "doorFLOpen");
        _cell(dc, colR, row1, "FRONT R", state, "doorFROpen");
        _cell(dc, colL, row2, "TRUNK",   state, "trunkOpen");
        _cell(dc, colR, row2, "HOOD",    state, "hoodOpen");

        PageChrome.drawAge(dc, state);
    }

    // One grid cell: position label over open/closed status.
    function _cell(dc, x, y, name, state, key) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(x, y - 9, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var isOpen = state.hasKey(key) ? state[key] : false;
        dc.setColor(isOpen ? Theme.COLOR_ERROR : Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.drawText(x, y + 6, Graphics.FONT_XTINY, isOpen ? "OPEN" : "CLOSED",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
