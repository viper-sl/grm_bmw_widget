// Page: Range & Fuel — main data page.
// Layout: RANGE label · big km · bar (moved up) · FUEL XX% · XX L in / XX L fill
// Low fuel (≤20%): bar + fuel text turn amber.
// OK/START → manual data refresh (same as vehicle page).
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
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
        var lastSync = Application.Storage.getValue(ForegroundSync.KEY_LAST_FG);
        if (lastSync != null && (Time.now().value() - lastSync) < ForegroundSync.COOLDOWN_SECONDS) {
            return true;
        }
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
        // F16: visible for ICE (fuelPercent) or EV/PHEV (socPercent) once a range is known.
        var state = VehicleCache.read();
        return state != null && state.hasKey("rangeKm")
            && (state.hasKey("fuelPercent") || state.hasKey("socPercent"));
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

        var lowFuel  = (fuelPercent != null && fuelPercent <= 20);
        var barColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_ACCENT;

        // ── Range value (big) ──────────────────────────────────────────────
        PageChrome.drawLabel(dc, "RANGE (KM)", cy - 58);
        PageChrome.drawValue(dc, (rangeKm != null) ? rangeKm.toString() : "--",
            Graphics.FONT_NUMBER_MEDIUM, cy - 8, Theme.COLOR_WHITE);

        // ── Bar ───────────────────────────────────────────────────────────
        // cy-8 = range value center (~122). FONT_NUMBER_MEDIUM height ≈ 60px → bottom ≈ 152.
        // Bar starts at cy+30=160, 8px below value bottom → no overlap.
        var pct = (rangeKm != null) ? (rangeKm.toFloat() / 700.0) : 0.0;
        PageChrome.drawBar(dc, pct, cy + 26, barColor);

        // ── Fuel / battery percent — 14px below bar bottom ─────────────────
        // F16: ICE shows FUEL %, EV/PHEV (no fuel %) shows BATTERY %.
        var socPercent = state.hasKey("socPercent") ? state["socPercent"] : null;
        var fuelStr;
        var fuelColor;
        if (fuelPercent != null) {
            fuelStr   = "FUEL  " + fuelPercent.toString() + "%";
            fuelColor = lowFuel ? Theme.COLOR_WARN : Theme.COLOR_WHITE;
        } else if (socPercent != null) {
            fuelStr   = "BATTERY  " + socPercent.toString() + "%";
            fuelColor = (socPercent <= 20) ? Theme.COLOR_WARN : Theme.COLOR_WHITE;
        } else {
            fuelStr   = "FUEL  --";
            fuelColor = Theme.COLOR_MUTED;
        }
        dc.setColor(fuelColor, Theme.COLOR_BG);
        dc.drawText(cx, cy + 50, Graphics.FONT_TINY, fuelStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Liters line (ICE only) — 20px below fuel% center ───────────────
        if (fuelPercent != null) {
            var tankProp = Application.Properties.getValue("tankLitres");
            var tank     = (tankProp != null) ? tankProp : 52;
            var inTank   = (tank * fuelPercent) / 100;
            var fill     = tank - inTank;
            if (fill < 0) { fill = 0; }
            var litStr   = "   " + inTank.toNumber().toString() + "L in  | " + fill.toNumber().toString() + "L to fill";
            dc.setColor(lowFuel ? Theme.COLOR_WARN : Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(cx, cy + 70, Graphics.FONT_XTINY, litStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── Fuel consumption estimate (FR-22) — instantaneous L/100km, not trip-based ──
        // F13: hidden when the showConsumption setting is off (default on).
        var fuelLitres = state.hasKey("fuelLitres") ? state["fuelLitres"] : null;
        var consumption = consumptionPer100Km(fuelLitres, rangeKm);
        if (consumption != null && showConsumption()) {
            dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
            dc.drawText(cx, cy + 86, Graphics.FONT_XTINY,
                "~" + PageChrome.oneDecimal(consumption) + " L/100KM (EST)",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        PageChrome.drawAge(dc, state);
        PageChrome.drawNavDots(dc);
        PageChrome.drawRefreshHint(dc, _refreshing);
    }

    // FR-22: instantaneous L/100km from remaining fuel + remaining range.
    // Returns null when not computable (missing data or zero range).
    static function consumptionPer100Km(fuelLitres, rangeKm) {
        if (fuelLitres == null || rangeKm == null || rangeKm <= 0) { return null; }
        return (fuelLitres.toFloat() / rangeKm.toFloat()) * 100.0;
    }

    // F13: consumption-estimate row toggle (IQ property; default on).
    static function showConsumption() {
        var v = Application.Properties.getValue("showConsumption");
        return (v == null) ? true : v;
    }

}
