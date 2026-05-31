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

    // "BMW 218i" header near top, tiny muted (mock: .page-hdr top:42px).
    static function drawHeader(dc, suffix) {
        var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
        if (name == null) { name = "BMW"; }
        if (suffix != null) { name = name + suffix; }
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, 58, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Small uppercase label above the value (mock: .plbl).
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
    static function drawAge(dc, state) {
        if (state == null || !state.hasKey("lastUpdated")) { return; }
        var ageSec = Time.now().value() - state["lastUpdated"];
        var str = _ageString(ageSec);
        var color = Theme.COLOR_MUTED;
        if (ageSec > 3600) {
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

    // Format a float to 1 decimal place (Monkey C lacks printf on all types).
    static function oneDecimal(f) {
        var whole = f.toNumber();
        var frac = ((f - whole) * 10 + 0.5).toNumber();
        if (frac >= 10) { whole += 1; frac = 0; }
        return whole.toString() + "." + frac.toString();
    }

}
