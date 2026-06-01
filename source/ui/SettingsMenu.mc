// On-watch settings menu (MENU button on the widget). fēnix has no built-in
// per-app settings UI on the device, so we provide one via Menu2.
//
// Items:
//   - Update Mode   : toggle Manual <-> Auto (every 30 min), re-applies the poll
//   - Tank Size     : number picker (litres), used for low-fuel "litres to fill"
//   - Re-pair       : launch the device-flow auth view (re-authenticate)
//   - Sign out      : clear stored tokens (forces setup on next use)
//   - About car     : read-only key/value list from basicData
using Toybox.Application;
using Toybox.WatchUi;

class SettingsMenu {

    // Build the Menu2 with current values reflected in sub-labels.
    static function build() {
        var menu = new WatchUi.Menu2({ :title => "Settings" });

        var auto = _isAuto();
        menu.addItem(new WatchUi.MenuItem(
            "Update Mode", auto ? "Auto · 30 min" : "Manual · button", :updateMode, null));

        var tank = Application.Properties.getValue("tankLitres");
        if (tank == null) { tank = 52; }
        menu.addItem(new WatchUi.MenuItem(
            "Tank Size", tank.toString() + " L", :tankSize, null));

        menu.addItem(new WatchUi.MenuItem("Re-pair", "Re-authenticate", :repair, null));
        menu.addItem(new WatchUi.MenuItem("Sign out", "Clear tokens", :signout, null));
        menu.addItem(new WatchUi.MenuItem("About car", null, :about, null));
        return menu;
    }

    static function _isAuto() {
        var m = Application.Properties.getValue("updateMode");
        return (m != null && m == 1);
    }

}

// Routes menu selections.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :updateMode) {
            // Toggle and persist; re-apply the background poll immediately.
            var auto = SettingsMenu._isAuto();
            Application.Properties.setValue("updateMode", auto ? 0 : 1);
            var app = Application.getApp();
            app._applyUpdateMode();
            item.setSubLabel(auto ? "Manual · button" : "Auto · 30 min");
            WatchUi.requestUpdate();

        } else if (id == :tankSize) {
            // No plain-number NumberPicker mode exists; cycle in 4 L steps (40..80, wrap).
            var t = _tank() + 4;
            if (t > 80) { t = 40; }
            Application.Properties.setValue("tankLitres", t);
            item.setSubLabel(t.toString() + " L");
            WatchUi.requestUpdate();

        } else if (id == :repair) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);

        } else if (id == :signout) {
            Application.Storage.deleteValue(StorageKeys.KEY_ACCESS_TOKEN);
            Application.Storage.deleteValue(StorageKeys.KEY_REFRESH_TOKEN);
            Application.Storage.deleteValue(StorageKeys.KEY_ACCESS_EXPIRY);
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "UNCONFIGURED");
            item.setSubLabel("Signed out");
            WatchUi.requestUpdate();

        } else if (id == :about) {
            WatchUi.pushView(AboutMenu.build(), new AboutMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function _tank() {
        var t = Application.Properties.getValue("tankLitres");
        return (t == null) ? 52 : t;
    }

}

// Read-only "About car" key/value list from basicData.
class AboutMenu {
    static function build() {
        var menu = new WatchUi.Menu2({ :title => "About car" });
        _add(menu, "Model",  StorageKeys.KEY_VEHICLE_NAME);
        _add(menu, "Colour", StorageKeys.KEY_COLOUR);
        _add(menu, "Body",   StorageKeys.KEY_BODY_TYPE);
        _add(menu, "Engine", StorageKeys.KEY_ENGINE);
        _add(menu, "Drive",  StorageKeys.KEY_DRIVE_TYPE);
        return menu;
    }
    static function _add(menu, label, key) {
        var v = Application.Storage.getValue(key);
        if (v == null || v.equals("")) { v = "—"; }
        menu.addItem(new WatchUi.MenuItem(label, v, null, null));
    }
}

class AboutMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {} // read-only
}
