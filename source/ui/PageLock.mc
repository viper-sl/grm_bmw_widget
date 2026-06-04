// Page: Lock overview — matches UX mock page 3.
// Header · "SECURED/UNLOCKED" status · ONE state icon (48×48) centered below it ·
// 2x2 door grid with colored dots.
using Toybox.Graphics;
using Toybox.WatchUi;

class PageLock extends WatchUi.View {

    var _iconClosed;   // closed_w.png (48×48) — shown when secured
    var _iconOpen;     // open_w.png   (48×48) — shown when unsecured

    function initialize() {
        View.initialize();
        try { _iconClosed = WatchUi.loadResource(Rez.Drawables.ClosedIcon); } catch (e) { _iconClosed = null; }
        try { _iconOpen   = WatchUi.loadResource(Rez.Drawables.OpenIcon);   } catch (e) { _iconOpen   = null; }
    }

    function onSelect() { return false; }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("doorsLocked");
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

        // Lock status hero text (y=52)
        var locked = state.hasKey("doorsLocked") ? state["doorsLocked"] : true;
        dc.setColor(locked ? Theme.COLOR_OK_HI : Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, 52, Graphics.FONT_SMALL, locked ? "SECURED" : "UNLOCKED",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ONE state icon (48×48) centered between status text (y≈52) and grid (row1=cy+4≈134).
        // Center icon at y=93: (52+134)/2. drawBitmap top-left so offset by half icon size (24).
        var icon = locked ? _iconClosed : _iconOpen;
        if (icon != null) {
            dc.drawBitmap(cx - 24, 93 - 24, icon);
        }

        // Door grid 2x2 with colored dots
        var colL = cx - 42;
        var colR = cx + 42;
        var row1 = cy + 4;
        var row2 = cy + 40;

        _cell(dc, colL, row1, "DOOR L", state, "doorFLOpen");
        _cell(dc, colR, row1, "DOOR R", state, "doorFROpen");
        _cell(dc, colL, row2, "TRUNK",   state, "trunkOpen");
        _cell(dc, colR, row2, "HOOD",    state, "hoodOpen");

        PageChrome.drawAge(dc, state);
        PageChrome.drawNavDots(dc);
    }

    function _cell(dc, x, y, name, state, key) {
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
        dc.drawText(x, y - 9, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var isOpen = state.hasKey(key) ? state[key] : false;
        if (isOpen) {
            dc.setColor(Theme.COLOR_ERROR, Theme.COLOR_BG);
            dc.drawCircle(x, y + 6, 5);
            dc.fillCircle(x, y + 6, 2);
        } else {
            dc.setColor(Theme.COLOR_OK, Theme.COLOR_BG);
            dc.fillCircle(x, y + 6, 5);
        }
    }

}
