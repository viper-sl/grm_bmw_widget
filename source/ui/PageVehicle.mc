// Page 1: Vehicle info card.
// makeImageRequest cannot set custom HTTP headers, and BMW CarData requires
// Authorization: Bearer + x-version: v1 on all endpoints, so image fetch
// always returns 404. Replaced with a vehicle info card using basicData
// (already fetched via makeWebRequest with proper headers).
using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class PageVehicle extends WatchUi.View {

    var _bmwIcon;        // BMW roundel from resources
    var _sync;
    var _refreshing;

    function initialize() {
        View.initialize();
        _refreshing = false;
        try { _bmwIcon = WatchUi.loadResource(Rez.Drawables.BmwIcon); } catch (e) { _bmwIcon = null; }
    }

    // Visible whenever we have any vehicle data.
    function isVisible() {
        return VehicleCache.read() != null;
    }

    // OK/START → manual data refresh.
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

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        PageChrome.drawAccent(dc);

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        // BMW roundel — centered in upper half
        if (_bmwIcon != null) {
            var iw = _bmwIcon.getWidth();
            var ih = _bmwIcon.getHeight();
            dc.drawBitmap(cx - iw / 2, cy - ih / 2 - 20, _bmwIcon);
        }

        // Vehicle name (e.g. "BMW 218I")
        var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
        if (name == null) { name = "BMW"; }
        dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
        dc.drawText(cx, cy + 26, Graphics.FONT_SMALL, name.toUpper(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Colour + body from basicData
        var about = Application.Storage.getValue(StorageKeys.KEY_BASIC_DATA);
        if (about instanceof Lang.Dictionary) {
            var colour = about.hasKey("colourDescription") ? about["colourDescription"] : null;
            var body   = about.hasKey("bodyType")          ? about["bodyType"]          : null;
            var line2Parts = [];
            if (colour != null) { line2Parts.add(colour); }
            if (body   != null) { line2Parts.add(body); }
            if (line2Parts.size() > 0) {
                var line2 = "";
                for (var i = 0; i < line2Parts.size(); i++) {
                    if (i > 0) { line2 = line2 + " · "; }
                    line2 = line2 + line2Parts[i].toUpper();
                }
                dc.setColor(Theme.COLOR_MUTED, Theme.COLOR_BG);
                dc.drawText(cx, cy + 46, Graphics.FONT_XTINY, line2,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // Refresh hint + age
        dc.setColor(_refreshing ? Theme.COLOR_WARN : Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(cx, dc.getHeight() - 70, Graphics.FONT_XTINY,
            _refreshing ? "Refreshing…" : "OK to refresh",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        PageChrome.drawAge(dc, VehicleCache.read());
        PageChrome.drawSelectHint(dc);
    }

}
