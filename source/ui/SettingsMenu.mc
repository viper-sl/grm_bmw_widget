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
    // Fully inlined — no helper functions.
    // about and menu are LOCAL vars so they keep their declared types.
    // Function parameters always become Object in Monkey C, causing Symbol
    // Not Found for type-specific methods (hasKey, indexOf, addItem, etc).
    // v.substring() returns String or Null — use a separate var + .toString()
    // to re-pin the type to String before passing to MenuItem.

    static function build() {
        var menu  = new WatchUi.Menu2({ :title => "About car" });
        var about = Application.Storage.getValue(StorageKeys.KEY_BASIC_DATA) as Lang.Dictionary or Null;
        if (about == null) {
            menu.addItem(new WatchUi.MenuItem("No data yet", "Refresh to load", null, null));
            return menu;
        }

        if (about.hasKey("modelName"))         { var v = about["modelName"].toString();         menu.addItem(new WatchUi.MenuItem("Model",       v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("series"))            { var v = about["series"].toString();            menu.addItem(new WatchUi.MenuItem("Series",      v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("bodyType"))          { var v = about["bodyType"].toString();          menu.addItem(new WatchUi.MenuItem("Body",        v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("colourDescription")) { var v = about["colourDescription"].toString(); menu.addItem(new WatchUi.MenuItem("Colour",      v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("engine"))            { var v = about["engine"].toString();            menu.addItem(new WatchUi.MenuItem("Engine",      v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("driveTrain"))        { var v = about["driveTrain"].toString();        menu.addItem(new WatchUi.MenuItem("Drive",       v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("propulsionType"))    { var v = about["propulsionType"].toString();    menu.addItem(new WatchUi.MenuItem("Propulsion",  v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("numberOfDoors"))     { var v = about["numberOfDoors"].toString();     menu.addItem(new WatchUi.MenuItem("Doors",       v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("steering"))          { var v = about["steering"].toString();          menu.addItem(new WatchUi.MenuItem("Steering",    v.equals("") ? "—" : v, null, null)); }

        if (about.hasKey("constructionDate")) {
            var raw = about["constructionDate"].toString();
            var t   = raw.indexOf("T");
            // Re-pin to String after substring (returns String or Null in Monkey C).
            var vd  = (t > 0) ? raw.substring(0, t).toString() : raw;
            menu.addItem(new WatchUi.MenuItem("Built", vd.equals("") ? "—" : vd, null, null));
        }

        if (about.hasKey("countryCode"))   { var v = about["countryCode"].toString();   menu.addItem(new WatchUi.MenuItem("Country",    v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("hasNavi"))       { var v = about["hasNavi"].toString();       menu.addItem(new WatchUi.MenuItem("Navi",       v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("hasSunRoof"))    { var v = about["hasSunRoof"].toString();    menu.addItem(new WatchUi.MenuItem("Sunroof",    v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("headUnit"))      { var v = about["headUnit"].toString();      menu.addItem(new WatchUi.MenuItem("Head unit",  v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("modelKey"))      { var v = about["modelKey"].toString();      menu.addItem(new WatchUi.MenuItem("Model key",  v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("seriesDevt"))    { var v = about["seriesDevt"].toString();    menu.addItem(new WatchUi.MenuItem("Platform",   v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("simStatus"))     { var v = about["simStatus"].toString();     menu.addItem(new WatchUi.MenuItem("SIM",        v.equals("") ? "—" : v, null, null)); }
        if (about.hasKey("colourCodeRaw")) { var v = about["colourCodeRaw"].toString(); menu.addItem(new WatchUi.MenuItem("Colour code", v.equals("") ? "—" : v, null, null)); }

        return menu;
    }
}

class AboutMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {} // read-only
}
