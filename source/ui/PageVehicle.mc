// Page 1: Vehicle image — DEFERRED to v2.
// PageVehicle.isVisible() returns false so the page is skipped in navigation.
// 173 KB JPEG exceeds Application.Storage cap (~16-32 KB) and Background.exit() cap (8 KB).
using Toybox.WatchUi;

class PageVehicle extends WatchUi.View {

    function initialize() { View.initialize(); }

    // Always hidden in MVP — PageVehicle deferred to v2
    function isVisible() { return false; }

    function onUpdate(dc) {}

}
