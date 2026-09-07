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
    var _rateLimited;
    var _failed;        // last refresh failed for a non-credential reason
    var _failText;      // why, in words (ForegroundSync.failText)

    function initialize() {
        View.initialize();
        _refreshing  = false;
        _rateLimited = false;
        _failed      = false;
        _failText    = null;
    }

    function onSelect() {
        if (_refreshing) { return true; }
        var lastSync = Application.Storage.getValue(ForegroundSync.KEY_LAST_FG);
        if (lastSync != null && (Time.now().value() - lastSync) < ForegroundSync.COOLDOWN_SECONDS) {
            return true;
        }
        _refreshing  = true;
        _rateLimited = false;   // clear any prior limit/offline note on a fresh attempt
        _failed      = false;
        _failText    = null;
        WatchUi.requestUpdate();
        _sync = new ForegroundSync();
        _sync.run(method(:onRefreshDone), true);  // START = manual full refresh
        return true;
    }

    function onRefreshDone(success) {
        _refreshing = false;
        if (!success && _sync != null && _sync.isRateLimited()) {
            // Daily API limit — show a note on the page; do NOT bounce to auth.
            _rateLimited = true;
        } else if (!success && _sync != null
                && (_sync.authFailed()
                    || _sync.failReason() == ForegroundSync.FAIL_STALE_AUTH)) {
            // Credentials are unusable, or BMW rejected the refresh with a 400 on a
            // retry the user asked for. Offering pairing is cheap and reversible; the
            // strike ladder still governs the one-way NEEDS_REBOOTSTRAP latch.
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);
        } else if (!success) {
            // Non-credential failure (no phone, cooldown, container cap, timeout, 5xx):
            // keep the cached data on screen and say WHICH. Opening the device flow here
            // was the "asks to re-auth after a while" bug — a BLE dropout is not an
            // expired grant — and one generic string for all of them was undiagnosable.
            _failed   = true;
            _failText = _sync.failText();
        }
        WatchUi.requestUpdate();
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
        PageChrome.drawLabel(dc, "RANGE (KM)", cy - PageChrome.s(dc, 58));
        PageChrome.drawValue(dc, (rangeKm != null) ? rangeKm.toString() : "--",
            Graphics.FONT_NUMBER_MEDIUM, cy - PageChrome.s(dc, 8), Theme.COLOR_WHITE);

        // ── Bar ───────────────────────────────────────────────────────────
        // cy-8 = range value center (~122). FONT_NUMBER_MEDIUM height ≈ 60px → bottom ≈ 152.
        // Bar starts at cy+30=160, 8px below value bottom → no overlap.
        var pct = (rangeKm != null) ? (rangeKm.toFloat() / 700.0) : 0.0;
        PageChrome.drawBar(dc, pct, cy + PageChrome.s(dc, 26), barColor);

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
        dc.drawText(cx, cy + PageChrome.s(dc, 50), Graphics.FONT_TINY, fuelStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Liters line (ICE only) — 20px below fuel% center ───────────────
        // Litres come from FuelMath (percent × tank setting), never from the
        // Vehicle State's "fuelLitres" — BMW freezes that field at the last refuel.
        var inTank = FuelMath.litresInTank(fuelPercent);
        if (fuelPercent != null) {
            var litStr = "   " + inTank.toString() + "L in  | "
                + FuelMath.litresToFill(fuelPercent).toString() + "L to fill";
            dc.setColor(lowFuel ? Theme.COLOR_WARN : Theme.COLOR_MUTED, Theme.COLOR_BG);
            dc.drawText(cx, cy + PageChrome.s(dc, 70), Graphics.FONT_XTINY, litStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── Fuel consumption estimate (FR-22) — instantaneous L/100km, not trip-based ──
        // F13: hidden when the showConsumption setting is off (default on).
        // Uses the derived litres for the same reason as the line above: fed the raw
        // "fuelLitres" it reported the litres-at-last-refuel over the current range,
        // which inflated the estimate more and more as the tank drained.
        var consumption = consumptionPer100Km(inTank, rangeKm);
        if (consumption != null && showConsumption()) {
            dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
            dc.drawText(cx, cy + PageChrome.s(dc, 86), Graphics.FONT_XTINY,
                "~" + PageChrome.oneDecimal(consumption) + " L/100KM (EST)",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        PageChrome.drawAge(dc, state);
        PageChrome.drawNavDots(dc);
        PageChrome.drawRefreshHint(dc, _refreshing);
        if (_rateLimited) { PageChrome.drawRateLimitNote(dc); }
        else if (_failed) { PageChrome.drawOfflineNote(dc, _failText); }
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
