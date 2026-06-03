// Page 1: Vehicle image hero page.
// Fetches the live per-VIN image from the BMW CarData API via makeImageRequest.
// Bearer token passed as a query parameter (API cannot use custom headers).
// Fallback: BMW roundel icon when no API image is available.
using Toybox.Application;
using Toybox.Communications;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class PageVehicle extends WatchUi.View {

    static const _DATA_HOST = "https://api-cardata.bmwgroup.com";

    var _apiBitmap;       // fetched from BMW (BitmapReference)
    var _bmwIcon;         // bundled BMW roundel — shown while loading or on failure
    var _requested;       // image request fired this session
    var _lastRespCode;    // last HTTP response code from image fetch (debug)
    var _sync;
    var _refreshing;

    function initialize() {
        View.initialize();
        _apiBitmap   = null;
        _bmwIcon     = null;
        _requested   = false;
        _lastRespCode = 0;
        _refreshing  = false;
        try { _bmwIcon = WatchUi.loadResource(Rez.Drawables.BmwIcon); } catch (e) {}
    }

    function isVisible() {
        return VehicleCache.read() != null;
    }

    function onSelect() {
        if (_refreshing) { return true; }
        _refreshing = true;
        _requested  = false;   // allow image re-fetch after each data refresh
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

        var vin   = Application.Storage.getValue(StorageKeys.KEY_VIN);
        if (vin == null) { vin = Application.Properties.getValue("vin"); }
        var token = Application.Storage.getValue(StorageKeys.KEY_ACCESS_TOKEN);
        if (vin == null || token == null) { return; }

        // makeImageRequest cannot set HTTP headers; token passed as query param.
        // BMW CarData /image endpoint — some API versions accept ?access_token.
        var url = _DATA_HOST + "/customers/vehicles/" + vin + "/image";
        Communications.makeImageRequest(
            url,
            { "access_token" => token },
            {
                :maxWidth  => 200,
                :maxHeight => 120,
                :dithering => Communications.IMAGE_DITHERING_NONE
            },
            method(:onApiImage)
        );
    }

    function onApiImage(responseCode as Lang.Number, data as WatchUi.BitmapResource or Graphics.BitmapReference or Null) as Void {
        _lastRespCode = responseCode;
        if (responseCode == 200 && data != null) {
            _apiBitmap = data;
        } else {
            // Non-200: API likely requires Authorization header — show BMW icon fallback.
            // User can press OK to retry after data refresh.
            _apiBitmap = null;
        }
        WatchUi.requestUpdate();
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
        } else if (_bmwIcon != null) {
            // Show BMW roundel while loading or when API image is unavailable.
            var iw = _bmwIcon.getWidth();
            var ih = _bmwIcon.getHeight();
            dc.drawBitmap(cx - iw / 2, cy - ih / 2 + 6, _bmwIcon);
        } else {
            var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
            if (name == null) { name = "BMW"; }
            dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
            dc.drawText(cx, cy, Graphics.FONT_LARGE, name.toUpper(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var hint = _refreshing ? "Refreshing…"
                 : (!_requested || _apiBitmap != null) ? "OK to refresh"
                 : "OK to refresh  [" + _lastRespCode.toString() + "]";
        dc.setColor(_refreshing ? Theme.COLOR_WARN : Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(cx, dc.getHeight() - 70, Graphics.FONT_XTINY, hint,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        PageChrome.drawAge(dc, VehicleCache.read());
    }

}
