// Shared page chrome — consistent visual hierarchy across all detail pages.
// Matches UX mock key-screens-v2: red top accent, BMW 218i header, label/value/unit
// stack, optional red progress bar, bottom data-age. Primary values are WHITE;
// red is for accents/bars only; green/amber only for status text.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;

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

    // Data-age line at the bottom (mock: .page-age). Stale → amber prefix.
    // "lastUpdated" is the CAR's last report time (max telematic timestamp), not the
    // fetch time — a parked car reports infrequently, so only flag >24h as stale.
    static const STALE_SECONDS = 259200; // 3 days — parked cars routinely report 1-2d old
    static function drawAge(dc, state) {
        if (state == null || !state.hasKey("lastUpdated")) { return; }
        var ageSec = Time.now().value() - state["lastUpdated"];
        var str = _ageString(ageSec);
        var color = Theme.COLOR_DIM;   // mock .page-age = --text3
        if (ageSec > STALE_SECONDS) {
            str = "! " + str;
            color = Theme.COLOR_WARN;
        }
        dc.setColor(color, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - 44, Graphics.FONT_XTINY, str,
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

    // Downward chevron at screen bottom — indicates OK/START is interactive.
    // Only call from pages whose onSelect() returns true.
    static function drawSelectHint(dc) {
        var cx  = dc.getWidth() / 2;
        var tip = dc.getHeight() - 12;   // chevron tip y
        var top = tip - 8;               // chevron arms y
        dc.setPenWidth(2);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 8, top, cx, tip);
        dc.drawLine(cx, tip, cx + 8, top);
    }

    // Format a float to 1 decimal place (Monkey C lacks printf on all types).
    static function oneDecimal(f) {
        var whole = f.toNumber();
        var frac = ((f - whole) * 10 + 0.5).toNumber();
        if (frac >= 10) { whole += 1; frac = 0; }
        return whole.toString() + "." + frac.toString();
    }

}
