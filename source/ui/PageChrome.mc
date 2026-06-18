using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.WatchUi;

class PageChrome {

    static function drawAccent(dc) {
        dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
        dc.fillRectangle(0, 0, dc.getWidth(), 3);
    }

    static function drawHeader(dc, suffix) {
        var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
        if (name == null) { name = "BMW"; }
        if (suffix != null) { name = name + suffix; }
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, 30, Graphics.FONT_XTINY, name.toUpper(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    static function drawLabel(dc, label, y) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    static function drawValue(dc, value, font, y, color) {
        dc.setColor(color, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, font, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    static function drawUnit(dc, unit, y) {
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY, unit,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    static function drawBar(dc, pct, y, fillColor) {
        var barW = 160;
        var barH = 8;
        var barX = (dc.getWidth() - barW) / 2;
        if (pct < 0) { pct = 0; }
        if (pct > 1) { pct = 1; }
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.fillRectangle(barX, y, barW, barH);
        dc.setColor(fillColor, Theme.COLOR_BG);
        dc.fillRectangle(barX, y, (barW * pct).toNumber(), barH);
    }

    static function drawAge(dc, state) {
        if (state == null || !state.hasKey("lastUpdated")) { return; }
        var ageSec = Time.now().value() - state["lastUpdated"];
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() - 22, Graphics.FONT_XTINY,
            _ageString(ageSec),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Data Age with staleness emphasis (FR-20) — same position/font as drawAge(),
    // but turns COLOR_WARN once the cached data is more than 30 minutes old, so a
    // "locked, all closed" reading isn't mistaken for current while the car idles.
    static function drawAgeProminent(dc, state) {
        if (state == null || !state.hasKey("lastUpdated")) { return; }
        var ageSec = Time.now().value() - state["lastUpdated"];
        var color = (ageSec > 1800) ? Theme.COLOR_WARN : Theme.COLOR_DIM;
        dc.setColor(color, Theme.COLOR_BG);
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

    static function blitBuffer(dc, x, y, buf) {
        if (buf == null) { return; }
        if (buf has :get) {
            var b = buf.get();
            if (b != null) { dc.drawBitmap(x, y, b); }
        } else {
            dc.drawBitmap(x, y, buf);
        }
    }

    static function drawRefreshHint(dc, isRefreshing) {
        // Hide while cooling down (but keep visible during active in-flight refresh).
        if (!isRefreshing) {
            var lastSync = Application.Storage.getValue(ForegroundSync.KEY_LAST_FG);
            if (lastSync != null && (Time.now().value() - lastSync) < ForegroundSync.COOLDOWN_SECONDS) {
                return;
            }
        }
        var hy = dc.getHeight() / 4;
        var icon = null;
        try { icon = WatchUi.loadResource(Rez.Drawables.RefreshIcon); } catch (e) {}
        if (icon != null) {
            var iw = icon.getWidth();
            var ih = icon.getHeight();
            var ix = dc.getWidth() - iw - 19;
            var iy = hy - ih / 2;
            if (isRefreshing) {
                dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
                dc.fillCircle(ix + iw / 2, iy + ih / 2, iw / 2 + 2);
            }
            dc.drawBitmap(ix, iy, icon);
        } else {
            var tip = dc.getWidth() - 22;
            var arm = tip - 10;
            dc.setPenWidth(2);
            dc.setColor(isRefreshing ? Theme.COLOR_WARN : Theme.COLOR_MUTED,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawLine(arm, hy - 7, tip, hy);
            dc.drawLine(tip, hy, arm, hy + 7);
        }
    }

    // Small banner shown after a refresh that hit BMW's daily API rate limit.
    // Drawn over the page's cached data so the user keeps seeing last-known values.
    static function drawRateLimitNote(dc) {
        var cx = dc.getWidth() / 2;
        var y  = (dc.getHeight() * 3) / 4 + 20;
        dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "Daily limit — try tomorrow",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    static function drawSelectHint(dc) {
        var hy  = dc.getHeight() / 4;
        var tip = dc.getWidth() - 22;
        var arm = tip - 10;
        dc.setPenWidth(2);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(arm, hy - 7, tip, hy);
        dc.drawLine(tip, hy, arm, hy + 7);
    }

    static function drawNavDots(dc) {
        var total = PageNav.visibleCount();
        var rank  = PageNav.activeRank();
        if (total <= 1) { return; }
        dc.setPenWidth(1);
        var spacing = 10;
        var startY  = (dc.getHeight() - (total - 1) * spacing) / 2;
        for (var i = 0; i < total; i++) {
            var y = startY + i * spacing;
            if (i == rank) {
                dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
                dc.fillCircle(8, y, 3);
            } else {
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawCircle(8, y, 3);
            }
        }
    }

    static function oneDecimal(f) {
        var whole = f.toNumber();
        var frac = ((f - whole) * 10 + 0.5).toNumber();
        if (frac >= 10) { whole += 1; frac = 0; }
        return whole.toString() + "." + frac.toString();
    }

}
