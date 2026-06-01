// Input delegate — routes up/down to page navigation, and START to on-device auth
// when the widget needs (re-)authentication (empty cache / NEEDS_REBOOTSTRAP).
using Toybox.Application;
using Toybox.WatchUi;

class BmwWidgetDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START/ENTER:
    //  - on the setup / re-link prompt: launch the device-flow auth view
    //  - otherwise: hand to the active page (image page -> manual refresh,
    //    tyres page -> toggle actual/target). The view returns true if handled.
    function onSelect() {
        if (_view == null) { return false; }
        if (_view.needsAuth()) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);
            return true;
        }
        return _view.onSelect();
    }

    function onNextPage() {
        if (_view != null) { return _view.onNextPage(); }
        return false;
    }

    function onPreviousPage() {
        if (_view != null) { return _view.onPreviousPage(); }
        return false;
    }

}
