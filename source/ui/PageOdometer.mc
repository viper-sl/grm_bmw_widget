// Page: Odometer & Service — matches UX mock page 4.
// Header · label "ODOMETER" · big white km · then service distance + colored bar.
// Service bar: green >5000, amber 1000-5000, red <1000 (km to next service).
using Toybox.Graphics;
using Toybox.WatchUi;

class PageOdometer extends WatchUi.View {

    function initialize() { View.initialize(); }

    function onSelect() { return false; } // no OK action on this page

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
        // Unit folded into the label to free vertical space (avoids number/label collision).
        PageChrome.drawLabel(dc, "ODOMETER (KM)", cy - 58);
        PageChrome.drawValue(dc, state["odometerKm"].toString(),
            Graphics.FONT_NUMBER_MEDIUM, cy - 8, Theme.COLOR_TEXT);

        // Service distance (secondary, with colored bar). FONT_TINY supports comma.
        if (state.hasKey("serviceDistanceKm")) {
            var svcKm = state["serviceDistanceKm"];
            var svcColor = _serviceColor(svcKm);

            var pct = svcKm.toFloat() / 5000.0;
            PageChrome.drawBar(dc, pct, cy + 44, svcColor);

            dc.setColor(Theme.COLOR_DIM, Theme.COLOR_BG);
            dc.drawText(cx, cy + 58, Graphics.FONT_XTINY,
                "SERVICE IN " + _short(svcKm),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        PageChrome.drawAge(dc, state);
    }

    function _serviceColor(svcKm) {
        if (svcKm > 5000) { return Theme.COLOR_OK; }
        if (svcKm > 1000) { return Theme.COLOR_WARN; }
        return Theme.COLOR_ERROR;
    }

    // Compact distance: >=1000 -> "22K km" / "1.5K km"; else "850 km".
    function _short(n) {
        if (n < 1000) { return n.toString() + " km"; }
        var k = n / 1000;
        var rem = (n % 1000) / 100;   // first decimal of the thousands
        if (rem == 0) { return k.toString() + "K km"; }
        return k.toString() + "." + rem.toString() + "K km";
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
