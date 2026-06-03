// Page 1: Vehicle info + stub image.
// Visible ONLY when basicData.seriesDevt == "G42" (BMW 2 Series Gran Coupe).
// makeImageRequest cannot set custom headers so live API image is unavailable;
// bundled vehicle.png stub is shown instead.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class PageVehicle extends WatchUi.View {

    var _vehicleImage;   // bundled stub PNG
    var _bmwIcon;        // fallback if stub fails to load
    var _sync;
    var _refreshing;

    function initialize() {
        View.initialize();
        _refreshing = false;
        try { _vehicleImage = WatchUi.loadResource(Rez.Drawables.VehicleImage); } catch (e) { _vehicleImage = null; }
        try { _bmwIcon      = WatchUi.loadResource(Rez.Drawables.BmwIcon);      } catch (e) { _bmwIcon      = null; }
    }

    // Only show for G42 platform cars (BMW 2 Series Gran Coupe).
    function isVisible() {
        if (VehicleCache.read() == null) { return false; }
        var about = Application.Storage.getValue(StorageKeys.KEY_BASIC_DATA) as Lang.Dictionary or Null;
        if (about == null) { return false; }
        var platform = about.hasKey("seriesDevt") ? about["seriesDevt"] : null;
        return platform instanceof Lang.String && (platform as Lang.String).equals("G42");
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

    function onUpdate(dc) {
        dc.setColor(Theme.COLOR_TEXT, Theme.COLOR_BG);
        dc.clear();

        PageChrome.drawAccent(dc);
        PageChrome.drawHeader(dc, null);

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        // Show stub vehicle image, fall back to BMW roundel
        var bmp = (_vehicleImage != null) ? _vehicleImage : _bmwIcon;
        if (bmp != null) {
            var bw = bmp.getWidth();
            var bh = bmp.getHeight();
            dc.drawBitmap(cx - bw / 2, cy - bh / 2 + 6, bmp);
        } else {
            var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
            if (name == null) { name = "BMW"; }
            dc.setColor(Theme.COLOR_WHITE, Theme.COLOR_BG);
            dc.drawText(cx, cy, Graphics.FONT_LARGE, name.toUpper(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(_refreshing ? Theme.COLOR_WARN : Theme.COLOR_DIM, Theme.COLOR_BG);
        dc.drawText(cx, dc.getHeight() - 70, Graphics.FONT_XTINY,
            _refreshing ? "Refreshing…" : "OK to refresh",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        PageChrome.drawAge(dc, VehicleCache.read());
        PageChrome.drawSelectHint(dc);
    }

}
