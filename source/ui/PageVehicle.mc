// Page 1: Vehicle image hero page.
// Fetches the live per-VIN image from the BMW CarData API via makeImageRequest.
// Bearer token passed as a query parameter (API cannot use custom headers).
// If the fetch fails, displays the vehicle name as text — no bundled image stub.
using Toybox.Application;
using Toybox.Communications;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class PageVehicle extends WatchUi.View {

    static const _DATA_HOST = "https://api-cardata.bmwgroup.com";

    var _apiBitmap;     // fetched from BMW (BitmapReference)
    var _requested;     // image request fired this session
    var _sync;          // manual-refresh coordinator
    var _refreshing;    // true while a manual fetch is in flight

    function initialize() {
        View.initialize();
        _apiBitmap  = null;
        _requested  = false;
        _refreshing = false;
    }

    // Visible whenever we have any vehicle data (acts as the hero/landing page).
    function isVisible() {
        return VehicleCache.read() != null;
    }

    // OK/START on the image page triggers a manual data refresh (manual update mode).
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

    function _requestApiImage() {
        if (_requested) { return; }
        _requested = true;

        var vin   = Application.Properties.getValue("vin");
        var token = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
        if (vin == null || token == null) { return; }

        var url = _DATA_HOST + "/customers/vehicles/" + vin + "/image";
        Communications.makeImageRequest(
            url,
            { "access_token" => token },
            {
                :maxWidth  => 218,
                :maxHeight => 131,
                :dithering => Communications.IMAGE_DITHERING_NONE
            },
            method(:onApiImage)
        );
    }

    function onApiImage(responseCode as Lang.Number, data as WatchUi.BitmapResource or Graphics.BitmapReference or Null) as Void {
        if (responseCode == 200 && data != null) {
            _apiBitmap = data;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        PageChrome.drawAccent(dc);
        PageChrome.drawHeader(dc, null);

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        _requestApiImage();

        if (_apiBitmap != null) {
            var bw = _apiBitmap.getWidth();
            var bh = _apiBitmap.getHeight();
            dc.drawBitmap(cx - bw / 2, cy - bh / 2 + 6, _apiBitmap);
        } else {
            var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
            if (name == null) { name = "BMW"; }
            dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
            dc.drawText(cx, cy, Graphics.FONT_LARGE, name.toUpper(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(_refreshing ? Theme.COLOR_WARN : Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(cx, dc.getHeight() - 70, Graphics.FONT_XTINY,
            _refreshing ? "Refreshing…" : "OK to refresh",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        PageChrome.drawAge(dc, VehicleCache.read());
    }

}
