// Page: Range & Fuel — main data page.
// Layout: RANGE label · big km · bar (moved up) · FUEL XX% · XX L in / XX L fill
// Low fuel (<50%): bar + fuel text turn amber.
// OK/START → manual data refresh (same as vehicle page).
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class PageRangeFuel extends WatchUi.View {

    var _sync;
    var _refreshing;

    function initialize() {
        View.initialize();
        _refreshing = false;
    }

    function onSelect() {
        if (_refreshing) { return true; }
        _refreshing = true;
        WatchUi.requestUpdate();
        _sync = new ForegroundSync();
        _sync.run(method(:onRefreshDone));
        return true;
    }

    function onRefreshDone(success) {
        _refreshing = false;
        WatchUi.requestUpdate();
        if (!success) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);
        }
    }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("rangeKm") && state.hasKey("fuelPercent");
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

        var rangeKm     = state.hasKey("rangeKm")    ? state["rangeKm"]    : null;
        var fuelPercent = state.hasKey("fuelPercent") ? state["fuelPercent"] : null;

        var lowFuel  = (fuelPercent != null && fuelPercent < 50);
        var barColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_ACCENT;

        // ── Range value (big) ──────────────────────────────────────────────
        PageChrome.drawLabel(dc, "RANGE (KM)", cy - 58);
        PageChrome.drawValue(dc, (rangeKm != null) ? rangeKm.toString() : "--",
            Graphics.FONT_NUMBER_MEDIUM, cy - 8, Theme.COLOR_WHITE);

        // ── Bar ───────────────────────────────────────────────────────────
        // cy-8 = range value center (~122). FONT_NUMBER_MEDIUM height ≈ 60px → bottom ≈ 152.
        // Bar starts at cy+30=160, 8px below value bottom → no overlap.
        var pct = (rangeKm != null) ? (rangeKm.toFloat() / 700.0) : 0.0;
        PageChrome.drawBar(dc, pct, cy + 30, barColor);

        // ── Fuel percent — 14px below bar bottom (bar bottom = cy+35=165) ─
        var fuelStr   = (fuelPercent != null) ? ("FUEL  " + fuelPercent.toString() + "%") : "FUEL  --";
        var fuelColor = (fuelPercent == null) ? Theme.COLOR_MUTED
                      : lowFuel ? Theme.COLOR_WARN : Theme.COLOR_TEXT;
        dc.setColor(fuelColor, Theme.COLOR_BG);
        dc.drawText(cx, cy + 50, Graphics.FONT_TINY, fuelStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Liters line — 20px below fuel% center ─────────────────────────
        if (fuelPercent != null) {
            var tankProp = Application.Properties.getValue("tankLitres");
            var tank     = (tankProp != null) ? tankProp : 52;
            var inTank   = (tank * fuelPercent) / 100;
            var fill     = tank - inTank;
            if (fill < 0) { fill = 0; }
            var litStr   = inTank.toNumber().toString() + "L in   | " + fill.toNumber().toString() + "L to fill";
            dc.setColor(lowFuel ? Theme.COLOR_WARN : Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(cx, cy + 70, Graphics.FONT_XTINY, litStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        PageChrome.drawAge(dc, state);
        PageChrome.drawNavDots(dc);
        PageChrome.drawRefreshHint(dc, _refreshing);
    }

}
