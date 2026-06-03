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
using Toybox.Lang;
using Toybox.WatchUi;

class SettingsMenu {

    // Build the Menu2 with current values reflected in sub-labels.
    static function build() {
        var menu = new WatchUi.Menu2({ :title => "Settings" });

        menu.addItem(new WatchUi.MenuItem(
            "Update Mode", modeLabel(), :updateMode, null));

        var tankProp = Application.Properties.getValue("tankLitres");
        var tank = (tankProp != null) ? tankProp : 52;
        menu.addItem(new WatchUi.MenuItem(
            "Tank Size", tank.toString() + " L", :tankSize, null));

        menu.addItem(new WatchUi.MenuItem("Re-pair", "Re-authenticate", :repair, null));
        menu.addItem(new WatchUi.MenuItem("Sign out", "Clear tokens", :signout, null));
        menu.addItem(new WatchUi.MenuItem("About car", null, :about, null));
        return menu;
    }

    // 0 = Manual, 1 = Auto hourly, 2 = Auto adaptive.
    static function mode() {
        var m = Application.Properties.getValue("updateMode");
        return (m == null) ? 0 : m;
    }

    static function modeLabel() {
        var m = mode();
        if (m == 1) { return "Auto · hourly"; }
        if (m == 2) { return "Auto · adaptive"; }
        return "Manual · button";
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
            // Cycle Manual -> Auto hourly -> Auto adaptive -> Manual; re-apply immediately.
            var next = (SettingsMenu.mode() + 1) % 3;
            Application.Properties.setValue("updateMode", next);
            var app = Application.getApp();
            app._applyUpdateMode();
            item.setSubLabel(SettingsMenu.modeLabel());
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

// Read-only "About car" key/value list — full basicData snapshot (all ~19 fields).
// Curated, human-friendly fields first; the rest follow in catalogue order.
class AboutMenu {
    // NOTE: static const arrays are typed as Object at the Monkey C runtime,
    // so .size() / [i] on them causes Symbol Not Found. All data is defined
    // as local variables inside build() where the types are properly inferred.

    static function build() {
        var menu = new WatchUi.Menu2({ :title => "About car" });
        var about = Application.Storage.getValue(StorageKeys.KEY_BASIC_DATA) as Lang.Dictionary or Null;
        if (about == null) {
            menu.addItem(new WatchUi.MenuItem("No data yet", "Refresh to load", null, null));
            return menu;
        }

        // Curated display order: parallel local arrays (typed Array<String>).
        var cKeys = [
            "modelName", "series", "bodyType", "colourDescription", "engine",
            "driveTrain", "propulsionType", "numberOfDoors", "steering",
            "constructionDate", "countryCode", "hasNavi", "hasSunRoof",
            "headUnit", "modelKey", "seriesDevt", "simStatus", "colourCodeRaw"
        ];
        var cLabels = [
            "Model", "Series", "Body", "Colour", "Engine",
            "Drive", "Propulsion", "Doors", "Steering",
            "Built", "Country", "Navi", "Sunroof",
            "Head unit", "Model key", "Platform", "SIM", "Colour code"
        ];

        // Show curated fields only — covers all known BMW basicData keys.
        // Avoiding about.keys() iteration: the return type is Object at runtime,
        // causing Symbol Not Found on .size() and array subscript.
        var n = cKeys.size();
        for (var i = 0; i < n; i++) {
            var k = cKeys[i];
            if (about.hasKey(k)) {
                var v = about[k];
                if (k.equals("constructionDate") && v != null) {
                    var t = v.indexOf("T");
                    if (t > 0) { v = v.substring(0, t); }
                }
                _add(menu, cLabels[i], v);
            }
        }
        return menu;
    }

    static function _add(menu, label, value) {
        var v = (value == null || value.toString().equals("")) ? "—" : value.toString();
        menu.addItem(new WatchUi.MenuItem(label, v, null, null));
    }
}

class AboutMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {} // read-only
}
