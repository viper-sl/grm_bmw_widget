using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.WatchUi;

class PageChrome {

    // All fixed pixel offsets in the UI were tuned on the 260px fēnix 6 grid.
    // s() scales a grid value to the actual screen height so 416/454px AMOLED
    // devices keep the same proportions (exact no-op at 260px). Use it for
    // y-offsets, gaps and small geometry — never for values already derived
    // from getWidth()/getHeight() fractions.
    // The height is floored at 260: sub-260 devices (240px fēnix 6s/7s, MARQ
    // gen 1, FR745/945) keep the hand-tuned grid values unchanged — shrinking
    // gaps under same-size fonts would reintroduce the overlap this fixes.
    // +130 rounds half-up so small values don't truncate away on 280px.
    static function s(dc, px) {
        var h = dc.getHeight();
        if (h < 260) { h = 260; }
        return (px * h + 130) / 260;
    }

    // TIER-SPLIT DESIGN: (:designNew) = AMOLED refresh on API 6.0+ devices;
    // (:designClassic) = original look, byte-identical on legacy (see monkey.jungle).
    //
    // New design: same top stripe as classic (user preference over a bezel arc),
    // plus frame-wide anti-aliasing — pages call drawAccent first, so every
    // later circle/arc this frame is smoothed.
    (:designNew)
    static function drawAccent(dc) {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(Theme.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, dc.getWidth(), s(dc, 3));
    }

    (:designClassic)
    static function drawAccent(dc) {
        dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
        dc.fillRectangle(0, 0, dc.getWidth(), s(dc, 3));
    }

    static function drawHeader(dc, suffix) {
        var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
        if (name == null) { name = "BMW"; }
        if (suffix != null) { name = name + suffix; }
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, s(dc, 30), Graphics.FONT_XTINY, name.toUpper(),
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

    // New design: pill-shaped bar on a whisper-dark track — the fill carries
    // the signal instead of competing with a bright track.
    (:designNew)
    static function drawBar(dc, pct, y, fillColor) {
        var barW = s(dc, 160);
        var barH = s(dc, 8);
        var barX = (dc.getWidth() - barW) / 2;
        var r    = barH / 2;
        if (pct < 0) { pct = 0; }
        if (pct > 1) { pct = 1; }
        dc.setColor(Theme.COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, y, barW, barH, r);
        var fw = (barW * pct).toNumber();
        if (fw > 0) {
            if (fw < barH) { fw = barH; }  // keep the pill cap intact at tiny %
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, y, fw, barH, r);
        }
    }

    (:designClassic)
    static function drawBar(dc, pct, y, fillColor) {
        var barW = s(dc, 160);
        var barH = s(dc, 8);
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
        var text = _ageString(ageSec);
        var y = dc.getHeight() - s(dc, 22);
        dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawFailMark(dc, text, y);
    }

    // Data Age with staleness emphasis (FR-20) — same position/font as drawAge(),
    // but turns COLOR_WARN once the cached data is more than 30 minutes old, so a
    // "locked, all closed" reading isn't mistaken for current while the car idles.
    static function drawAgeProminent(dc, state) {
        if (state == null || !state.hasKey("lastUpdated")) { return; }
        var ageSec = Time.now().value() - state["lastUpdated"];
        var color = (ageSec > 1800) ? Theme.COLOR_WARN : Theme.COLOR_DIM;
        var text = _ageString(ageSec);
        var y = dc.getHeight() - s(dc, 22);
        dc.setColor(color, Theme.COLOR_BG);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawFailMark(dc, text, y);
    }

    // Warning triangle just left of the centered age `text` at `y`, shown once the
    // last few fetch attempts failed (QuotaGuard.isFailing). The age alone can't tell
    // a car that simply hasn't reported from a link that keeps failing.
    static function drawFailMark(dc, text, y) {
        if (!QuotaGuard.isFailing()) { return; }
        var h = (dc.getFontHeight(Graphics.FONT_XTINY) * 2) / 3;
        var textW = dc.getTextDimensions(text, Graphics.FONT_XTINY)[0];
        var cx = dc.getWidth() / 2 - textW / 2 - s(dc, 4) - WarnIcon.width(h) / 2;
        WarnIcon.draw(dc, cx, y, h);
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
            var ix = dc.getWidth() - iw - s(dc, 19);
            var iy = hy - ih / 2;
            if (isRefreshing) {
                dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
                dc.fillCircle(ix + iw / 2, iy + ih / 2, iw / 2 + 2);
            }
            dc.drawBitmap(ix, iy, icon);
        } else {
            var tip = dc.getWidth() - s(dc, 22);
            var arm = tip - s(dc, 10);
            dc.setPenWidth(s(dc, 2));
            dc.setColor(isRefreshing ? Theme.COLOR_WARN : Theme.COLOR_MUTED,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawLine(arm, hy - s(dc, 7), tip, hy);
            dc.drawLine(tip, hy, arm, hy + s(dc, 7));
        }
    }

    // Small banner shown after a refresh that hit BMW's daily API rate limit.
    // Drawn over the page's cached data so the user keeps seeing last-known values.
    static function drawRateLimitNote(dc) {
        var cx = dc.getWidth() / 2;
        var y  = (dc.getHeight() * 3) / 4 + s(dc, 20);
        dc.setColor(Theme.COLOR_WARN, Theme.COLOR_BG);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "Daily limit — try tomorrow",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Banner for a refresh that failed for a reason the user can act on but that is NOT
    // a credential problem. `text` comes from ForegroundSync.failText(): a dropped phone
    // link, a container-cap rejection and a server error must not all read the same, and
    // none of them may read as "you need to sign in again".
    static function drawOfflineNote(dc, text) {
        var cx = dc.getWidth() / 2;
        var y  = (dc.getHeight() * 3) / 4 + s(dc, 20);
        dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            (text != null) ? text : "Update failed — retry",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // The cache is empty but a page view is still on the stack — after a sign-out, which
    // calls VehicleCache.clear() while the menu sits on top of a data page. Every page
    // used to `dc.clear()` and return here, i.e. paint pure black with no way forward,
    // and START did nothing because the delegate only routed NEEDS_REBOOTSTRAP. Draw an
    // honest empty state instead; START now opens pairing (see PageDelegate.onSelect).
    static function drawEmptyState(dc) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - s(dc, 14), Graphics.FONT_SMALL, "No vehicle data",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + s(dc, 12), Graphics.FONT_TINY, "Press START to set up",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    static function drawSelectHint(dc) {
        var hy  = dc.getHeight() / 4;
        var tip = dc.getWidth() - s(dc, 22);
        var arm = tip - s(dc, 10);
        dc.setPenWidth(s(dc, 2));
        dc.setColor(Theme.COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(arm, hy - s(dc, 7), tip, hy);
        dc.drawLine(tip, hy, arm, hy + s(dc, 7));
    }

    static function drawNavDots(dc) {
        var total = PageNav.visibleCount();
        var rank  = PageNav.activeRank();
        if (total <= 1) { return; }
        dc.setPenWidth(s(dc, 1));
        var spacing = s(dc, 10);
        var startY  = (dc.getHeight() - (total - 1) * spacing) / 2;
        var dotX = s(dc, 8);
        var dotR = s(dc, 3);
        for (var i = 0; i < total; i++) {
            var y = startY + i * spacing;
            if (i == rank) {
                dc.setColor(Theme.COLOR_ACCENT, Theme.COLOR_BG);
                dc.fillCircle(dotX, y, dotR);
            } else {
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawCircle(dotX, y, dotR);
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
