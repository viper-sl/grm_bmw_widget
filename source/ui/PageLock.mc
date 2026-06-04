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

        var locked = state.hasKey("doorsLocked") ? state["doorsLocked"] : true;

        // Status label at top
        dc.setColor(locked ? Theme.COLOR_OK_HI : Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, 52, Graphics.FONT_SMALL, locked ? "SECURED" : "UNLOCKED",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Icon + cross shifted down to sit between SECURED label and age text
        var mid = cy + 16;
        var icon = locked ? _iconClosed : _iconOpen;
        if (icon != null) {
            dc.drawBitmap(cx - 24, mid - 24, icon);
        }

        // Cross layout: HOOD above · DOOR L/R on sides · TRUNK below
        _cell(dc, cx,      mid - 46, "HOOD",   state, "hoodOpen");
        _cell(dc, cx - 60, mid,      "DOOR L", state, "doorFLOpen");
        _cell(dc, cx + 60, mid,      "DOOR R", state, "doorFROpen");
        _cell(dc, cx,      mid + 46, "TRUNK",  state, "trunkOpen");

        PageChrome.drawAge(dc, state);
        PageChrome.drawNavDots(dc);
    }

    function _cell(dc, x, y, name, state, key) {
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
        dc.drawText(x, y - 12, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var isOpen = state.hasKey(key) ? state[key] : false;
        if (isOpen) {
            dc.setColor(Theme.COLOR_ERROR, Theme.COLOR_BG);
            dc.drawCircle(x, y + 10, 7);
            dc.fillCircle(x, y + 10, 3);
        } else {
            dc.setColor(Theme.COLOR_OK, Theme.COLOR_BG);
            dc.fillCircle(x, y + 10, 7);
        }
    }

}
