// Shared page chrome — consistent visual hierarchy across all detail pages.
// Matches UX mock key-screens-v2: red top accent, BMW 218i header, label/value/unit
// stack, optional red progress bar, bottom data-age. Primary values are WHITE;
// red is for accents/bars only; green/amber only for status text.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.WatchUi;

class PageChrome {

    // Red accent line across the top (mock: .screen::before, 3px red).
    static function drawAccent(dc) {
        dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
        dc.fillRectangle(0, 0, dc.getWidth(), 3);
    }

    // "BMW 218I" header near top, tiny muted uppercase (mock: .page-hdr top:42px).
    // Sits well above the page label to avoid overlap with RANGE/ODOMETER/etc.
    static function drawHeader(dc, suffix) {
        var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
        if (name == null) { name = "BMW"; }
        if (suffix != null) { name = name + suffix; }
        name = name.toUpper();
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);   // mock .page-hdr = --text3
        dc.drawText(dc.getWidth() / 2, 30, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Small uppercase label above the value (mock: .plbl = --text2).
    static function drawLabel(dc, label, y) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Big primary value, white (mock: .pval). font picks size.
    static function drawValue(dc, value, font, y, color) {
        dc.setColor(color, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, font, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Small unit/caption below the value (mock: .punit).
    static function drawUnit(dc, unit, y) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY, unit,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Centered red progress bar (mock: .pbar). pct 0..1. color overrides fill.
    static function drawBar(dc, pct, y, fillColor) {
        var w = dc.getWidth();
        var barW = 160;
        var barH = 5;
        var barX = (w - barW) / 2;
        if (pct < 0) { pct = 0; }
        if (pct > 1) { pct = 1; }
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.fillRectangle(barX, y, barW, barH);
        dc.setColor(fillColor, Theme.COLOR_BG);
        dc.fillRectangle(barX, y, (barW * pct).toNumber(), barH);
    }

    // Data-age line near the bottom. Always shown in DIM — a parked car's
    // 1-3d old data is normal, not an error condition requiring orange.
    static function drawAge(dc, state) {
        if (state == null || !state.hasKey("lastUpdated")) { return; }
        var ageSec = Time.now().value() - state["lastUpdated"];
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - 22, Graphics.FONT_XTINY,
            _ageString(ageSec),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    static function _ageString(sec) {
        if (sec < 60)    { return sec.toString() + "s ago"; }
        if (sec < 3600)  { return (sec / 60).toString() + "m ago"; }
        if (sec < 86400) { return (sec / 3600).toString() + "h ago"; }
        return (sec / 86400).toString() + "d ago";
    }

    // Blit a BufferedBitmap or BufferedBitmapReference at (x, y).
    // Handles SDK 3.x (bitmap directly) and SDK 4.0+ (reference with .get()).
    static function blitBuffer(dc, x, y, buf) {
        if (buf == null) { return; }
        if (buf has :get) {
            var b = buf.get();
            if (b != null) { dc.drawBitmap(x, y, b); }
        } else {
            dc.drawBitmap(x, y, buf);
        }
    }

    // Refresh icon at the 3 o'clock (START button) position on the right edge.
    // isRefreshing=true tints the icon area amber while a sync is in flight.
    // Only call from pages whose onSelect() triggers a data refresh.
    static function drawRefreshHint(dc, isRefreshing) {
        // 2 o'clock position: y = h/4 ≈ 65px on a 260px screen.
        // At y=65 the circular screen right edge ≈ x=243 (vs 260 at centre).
        // Use inset=19 so a 20px icon's right edge lands at ~241, inside the circle.
        var hy = dc.getHeight() / 4;
        var icon = null;
        try { icon = WatchUi.loadResource(Rez.Drawables.RefreshIcon); } catch (e) {}
        if (icon != null) {
            var iw = icon.getWidth();
            var ih = icon.getHeight();
            var ix = dc.getWidth() - iw - 19;  // right edge at ~241 px (inside circle at y=65)
            var iy = hy - ih / 2;
            if (isRefreshing) {
                dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
                dc.fillRectangle(ix - 1, iy - 1, iw + 2, ih + 2);
            }
            dc.drawBitmap(ix, iy, icon);
        } else {
            // Fallback chevron — same 2-o'clock position
            var tip = dc.getWidth() - 22;
            var arm = tip - 10;
            dc.setPenWidth(2);
            dc.setColor(isRefreshing ? Theme.COLOR_WARN : Theme.COLOR_MUTED,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawLine(arm, hy - 7, tip, hy);
            dc.drawLine(tip, hy, arm, hy + 7);
        }
    }

    // Chevron for toggle pages (Tyres) — same 2 o'clock position as drawRefreshHint.
    static function drawSelectHint(dc) {
        var hy  = dc.getHeight() / 4;   // 2 o'clock ≈ 65 px on 260 px screen
        var tip = dc.getWidth() - 22;
        var arm = tip - 10;
        dc.setPenWidth(2);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(arm, hy - 7, tip, hy);
        dc.drawLine(tip, hy, arm, hy + 7);
    }

    // Navigation dots on left edge — reads rank/count from PageNav so dots are
    // always evenly spaced across visible pages only (no phantom gap for hidden pages).
    static function drawNavDots(dc) {
        var info  = PageNav.visibleInfo();
        var total = info[0];
        var rank  = info[1];
        if (total <= 1) { return; }
        var dotR    = 3;
        var spacing = 10;
        var startY  = (dc.getHeight() - (total - 1) * spacing) / 2;
        for (var i = 0; i < total; i++) {
            var y = startY + i * spacing;
            if (i == rank) {
                dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
                dc.fillCircle(8, y, dotR);
            } else {
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawCircle(8, y, dotR);
            }
        }
    }

    // Format a float to 1 decimal place (Monkey C lacks printf on all types).
    static function oneDecimal(f) {
        var whole = f.toNumber();
        var frac = ((f - whole) * 10 + 0.5).toNumber();
        if (frac >= 10) { whole += 1; frac = 0; }
        return whole.toString() + "." + frac.toString();
    }

}
