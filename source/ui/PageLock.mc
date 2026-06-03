// Page: Lock overview — matches UX mock page 3.
// Header · "SECURED/UNLOCKED" status (green/amber).
// Between status and door grid: icon legend (closed_w left, open_w right).
// Door grid 2x2: position label + colored dot per cell.
using Toybox.Graphics;
using Toybox.WatchUi;

class PageLock extends WatchUi.View {

    var _iconClosed;   // closed_w.png — shown in legend area between SECURED and grid
    var _iconOpen;     // open_w.png   — shown in legend area between SECURED and grid

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
        dc.setColor(locked ? Theme.COLOR_OK : Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, 52, Graphics.FONT_SMALL, locked ? "SECURED" : "UNLOCKED",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Icon legend: closed_w on left column, open_w on right column.
        // Positioned between SECURED text (y≈52) and door grid (row1=cy+4≈134).
        // 24×24 icons centered at (colL, 93) and (colR, 93).
        var colL   = cx - 42;
        var colR   = cx + 42;
        var iconY  = 93;    // (52 + 134) / 2 rounded
        var iconHW = 12;    // half of 24px icon = 12

        if (_iconClosed != null) {
            dc.drawBitmap(colL - iconHW, iconY - iconHW, _iconClosed);
        }
        if (_iconOpen != null) {
            dc.drawBitmap(colR - iconHW, iconY - iconHW, _iconOpen);
        }

        // Door grid 2x2 with colored dots (green=closed, red ring=open)
        var row1 = cy + 4;
        var row2 = cy + 40;

        _cell(dc, colL, row1, "FRONT L", state, "doorFLOpen");
        _cell(dc, colR, row1, "FRONT R", state, "doorFROpen");
        _cell(dc, colL, row2, "TRUNK",   state, "trunkOpen");
        _cell(dc, colR, row2, "HOOD",    state, "hoodOpen");

        PageChrome.drawAge(dc, state);
    }

    // One grid cell: position label + colored status dot (kept as requested).
    function _cell(dc, x, y, name, state, key) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
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
