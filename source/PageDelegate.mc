// Delegate for data pages — uses WatchUi.switchToView() with hardware
// SLIDE_UP / SLIDE_DOWN transitions (same as Garmin's own widget carousel).
using Toybox.Application;
using Toybox.WatchUi;

class PageDelegate extends WatchUi.BehaviorDelegate {

    function initialize() { BehaviorDelegate.initialize(); }

    function onNextPage() {
        if (!PageNav.advance(1)) { return false; }
        WatchUi.switchToView(PageNav.current(), new PageDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() {
        if (!PageNav.advance(-1)) { return false; }
        WatchUi.switchToView(PageNav.current(), new PageDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() {
        // Re-link guard: if token has expired, launch re-auth instead.
        var ts = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (ts != null && ts.equals("NEEDS_REBOOTSTRAP")) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);
            return true;
        }
        var p = PageNav.current();
        return (p != null) ? p.onSelect() : false;
    }

    function onMenu() {
        WatchUi.pushView(SettingsMenu.build(), new SettingsMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}
