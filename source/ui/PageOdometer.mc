// Page: Odometer & Service — matches UX mock page 4.
// Header · label "ODOMETER" · big white km · then service distance + colored bar.
// Service bar: green >5000, amber 1000-5000, red <1000 (km to next service).
using Toybox.Graphics;
using Toybox.WatchUi;

class PageOdometer extends WatchUi.View {

    function initialize() { View.initialize(); }

    function onSelect() { return false; }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("odometerKm");
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

        PageChrome.drawLabel(dc, "ODOMETER (KM)", cy - 58);
        PageChrome.drawValue(dc, state["odometerKm"].toString(),
            Graphics.FONT_NUMBER_MEDIUM, cy - 8, Theme.COLOR_WHITE);

        // FR-23: a user-set "next maintenance" override (km) replaces BMW's
        // serviceDistanceKm for display when set (>0).
        var override = SettingsMenu.nextMaintenanceKm();
        var svcKm = (override > 0) ? override
                  : (state.hasKey("serviceDistanceKm") ? state["serviceDistanceKm"] : null);

        if (svcKm != null) {
            var svcColor = _serviceColor(svcKm);
            var pct = svcKm.toFloat() / 5000.0;
            PageChrome.drawBar(dc, pct, cy + 44, svcColor);
            dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
            dc.drawText(cx, cy + 68, Graphics.FONT_XTINY,
                "SERVICE IN " + _short(svcKm),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        PageChrome.drawAge(dc, state);
        PageChrome.drawNavDots(dc);
    }

    function _serviceColor(svcKm) {
        if (svcKm > 5000) { return Theme.COLOR_OK; }
        if (svcKm > 1000) { return Theme.COLOR_WARN; }
        return Theme.COLOR_ERROR;
    }

    function _short(n) {
        if (n < 1000) { return n.toString() + " km"; }
        var k = n / 1000;
        var rem = (n % 1000) / 100;
        if (rem == 0) { return k.toString() + "K km"; }
        return k.toString() + "." + rem.toString() + "K km";
    }

}
