// Page: Odometer & Service — matches UX mock page 4.
// Header · label "ODOMETER" · big white km · then service distance + colored bar.
// Service bar: green >5000, amber 1000-5000, red <1000 (km to next service).
using Toybox.Graphics;
using Toybox.WatchUi;

class PageOdometer extends WatchUi.View {

    function initialize() { View.initialize(); }

    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("odometerKm");
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        var state = VehicleCache.read();
        if (state == null) { return; }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        PageChrome.drawAccent(dc);
        PageChrome.drawHeader(dc, null);

        // Odometer (primary). Number font has digits only — no comma (renders as tofu).
        PageChrome.drawLabel(dc, "ODOMETER", cy - 58);
        PageChrome.drawValue(dc, state["odometerKm"].toString(),
            Graphics.FONT_NUMBER_MEDIUM, cy - 22, Theme.COLOR_TEXT);
        PageChrome.drawUnit(dc, "km", cy + 12);

        // Service distance (secondary, with colored bar). FONT_TINY supports comma.
        if (state.hasKey("serviceDistanceKm")) {
            var svcKm = state["serviceDistanceKm"];
            var svcColor = _serviceColor(svcKm);

            var pct = svcKm.toFloat() / 5000.0;
            PageChrome.drawBar(dc, pct, cy + 36, svcColor);

            dc.setColor(svcColor, Theme.COLOR_BG);
            dc.drawText(cx, cy + 54, Graphics.FONT_TINY,
                _grouped(svcKm) + " km to service",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        PageChrome.drawAge(dc, state);
    }

    function _serviceColor(svcKm) {
        if (svcKm > 5000) { return Theme.COLOR_OK; }
        if (svcKm > 1000) { return Theme.COLOR_WARN; }
        return Theme.COLOR_ERROR;
    }

    // Insert thousands separators: 40926 -> "40,926"
    function _grouped(n) {
        var s = n.toString();
        var out = "";
        var count = 0;
        for (var i = s.length() - 1; i >= 0; i--) {
            out = s.substring(i, i + 1) + out;
            count++;
            if (count % 3 == 0 && i > 0) { out = "," + out; }
        }
        return out;
    }

}
