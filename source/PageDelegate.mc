// Delegate for data pages — navigation via WatchUi.switchToView() in PageNav.advance().
using Toybox.Application;
using Toybox.WatchUi;

class PageDelegate extends WatchUi.BehaviorDelegate {

    function initialize() { BehaviorDelegate.initialize(); }

    function onNextPage()     { return PageNav.advance(1);  }
    function onPreviousPage() { return PageNav.advance(-1); }

    function onSelect() {
        // UNCONFIGURED as well as NEEDS_REBOOTSTRAP: sign-out sets the former and wipes
        // the cache, leaving the user on an empty page whose START did nothing at all.
        var ts = Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE);
        if (ts != null && (ts.equals("NEEDS_REBOOTSTRAP") || ts.equals("UNCONFIGURED"))) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);
            return true;
        }
        return PageNav.selectCurrent();
    }

    function onMenu() {
        WatchUi.pushView(SettingsMenu.build(), new SettingsMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}
