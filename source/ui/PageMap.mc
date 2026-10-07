// Page: Car location on the device's own onboard cartography (FR-27..FR-31, FR-36).
// The only page that extends WatchUi.MapView rather than WatchUi.View — MapView is
// itself a View subclass, so PageNav.switchToView() takes it unchanged.
//
// Cache-only by design (FR-39/FR-40): this page NEVER initiates a network request.
// Location rides the full container (manual START refresh, or the once-daily auto
// full fetch), not the lean background poll — so the age row is the user's only
// signal that the pin may predate where the car actually is.
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

(:mapPage)
class PageMap extends WatchUi.MapView {

    // Half-diagonal of a 300 m x 300 m box: 150 * sqrt(2). Projecting NW and SE
    // corners this far from the car gives an exact metric viewport with no
    // latitude-dependent degree math (FR-28).
    static const HALF_DIAG_M = 212;

    function initialize() {
        MapView.initialize();
        setMapMode(WatchUi.MAP_MODE_PREVIEW);
        // BOTH areas must be set before the first paint — MapView throws
        // "<X> visible area top left is not set" otherwise, and onShow() is NOT
        // guaranteed to run before the first onUpdate on the switchToView path.
        _applyScreenArea();
        _frameOnCar();
    }

    // MUST run before the first render: MapView throws
    // "Screen visible area top left is not set" if it paints without one.
    // Uses DeviceSettings rather than a Dc because there is no Dc at construction
    // time — mirrors PageChrome.s() scaling so the band matches the real chrome.
    function _applyScreenArea() {
        var ds = System.getDeviceSettings();
        var w  = ds.screenWidth;
        var h  = ds.screenHeight;
        var sh = (h < 260) ? 260 : h;            // same floor as PageChrome.s()
        var top    = (44 * sh + 130) / 260;      // below the header
        var bottom = h - ((34 * sh + 130) / 260); // above the age row
        setScreenVisibleArea(0, top, w, bottom);
    }

    // FR-36 — hide entirely when the vehicle has never reported a position.
    function isVisible() {
        var state = VehicleCache.read();
        return state != null && state.hasKey("lat") && state.hasKey("lon");
    }

    // FR-32 — OK toggles preview <-> zoom in BOTH directions. Routed here by
    // PageNav.selectCurrent(), the same path every other page's OK press takes.
    function onSelect() {
        setMapMode(isBrowsing() ? WatchUi.MAP_MODE_PREVIEW : WatchUi.MAP_MODE_BROWSE);
        WatchUi.requestUpdate();
        return true;
    }

    function isBrowsing() {
        return getMapMode() == WatchUi.MAP_MODE_BROWSE;
    }

    function onShow() {
        _frameOnCar();
    }

    // FR-28/FR-29 — marker at the cached fix, viewport framed ~300 m around it.
    // Always leaves a map visible area set, even with no fix: the page is hidden
    // in that state (FR-36), but a visible area is a hard precondition of paint.
    function _frameOnCar() {
        var car = _cachedCarLocation();
        if (car == null) {
            _frameAround(_locationOf(0.0, 0.0));
            return;
        }
        var marker = new WatchUi.MapMarker(car);
        marker.setIcon(WatchUi.MAP_MARKER_ICON_PIN, 0, 0);
        setMapMarker(marker);
        _frameAround(car);
    }

    // Angles are radians from north: -PI/4 = NW, 3*PI/4 = SE.
    function _frameAround(loc) {
        setMapVisibleArea(
            loc.getProjectedLocation(-Math.PI / 4, HALF_DIAG_M),
            loc.getProjectedLocation(3 * Math.PI / 4, HALF_DIAG_M)
        );
    }

    function _locationOf(lat, lon) {
        return new Position.Location({
            :latitude  => lat,
            :longitude => lon,
            :format    => :degrees
        });
    }

    function _cachedCarLocation() {
        var state = VehicleCache.read();
        if (state == null) { return null; }
        var lat = state.hasKey("lat") ? state["lat"] : null;
        var lon = state.hasKey("lon") ? state["lon"] : null;
        if (lat == null || lon == null) { return null; }
        return _locationOf(lat, lon);
    }

    // FR-30 — native map first, this widget's chrome on top. No dc.clear(): the
    // parent onUpdate paints the whole frame and clearing would erase the map.
    function onUpdate(dc) {
        MapView.onUpdate(dc);

        // In zoom mode the device's native browse interface owns the screen.
        if (isBrowsing()) { return; }

        PageChrome.drawAccent(dc);
        _drawHeader(dc);
        _drawAge(dc);                 // FR-31
        PageChrome.drawNavDots(dc);
        PageChrome.drawSelectHint(dc);
    }

    // The shared PageChrome text helpers draw with an OPAQUE Theme.COLOR_BG
    // background — invisible on the other (dark) pages, but a black box over
    // cartography. The map page therefore draws its own text: transparent
    // background, dark halo for contrast against whatever the map renders.
    function _drawHeader(dc) {
        var name = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_NAME);
        if (name == null) { name = "BMW"; }
        _haloText(dc, dc.getWidth() / 2, PageChrome.s(dc, 30),
                  Graphics.FONT_XTINY, name.toUpper(), Theme.COLOR_WHITE);
    }

    function _drawAge(dc) {
        var state = VehicleCache.read();
        if (state == null || !state.hasKey("lastUpdated")) { return; }
        var ageSec = Time.now().value() - state["lastUpdated"];
        // Same 30-minute staleness threshold as PageChrome.drawAgeProminent;
        // white rather than DIM because DIM is unreadable over a light map.
        var color = (ageSec > 1800) ? Theme.COLOR_WARN : Theme.COLOR_WHITE;
        var text = PageChrome._ageString(ageSec);
        var y = dc.getHeight() - PageChrome.s(dc, 22);
        _haloText(dc, dc.getWidth() / 2, y, Graphics.FONT_XTINY, text, color);
        PageChrome.drawFailMark(dc, text, y);
    }

    // Text with a 1px dark outline in all 8 directions, then the fill on top.
    // Standard cartographic label treatment — stays legible over light terrain,
    // dark water and everything between.
    function _haloText(dc, x, y, font, text, color) {
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var o = PageChrome.s(dc, 1);
        if (o < 1) { o = 1; }
        dc.setColor(Theme.COLOR_BG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x - o, y,     font, text, j);
        dc.drawText(x + o, y,     font, text, j);
        dc.drawText(x,     y - o, font, text, j);
        dc.drawText(x,     y + o, font, text, j);
        dc.drawText(x - o, y - o, font, text, j);
        dc.drawText(x + o, y - o, font, text, j);
        dc.drawText(x - o, y + o, font, text, j);
        dc.drawText(x + o, y + o, font, text, j);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, j);
    }

}
