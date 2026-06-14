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

        menu.addItem(new WatchUi.MenuItem(
            "Next Service", nextMaintenanceLabel(), :nextMaintenance, null));

        // F13: enable/disable the Range & Fuel L/100km estimate.
        menu.addItem(new WatchUi.MenuItem(
            "Est. Consumption", consumptionLabel(), :consumption, null));

        // Auth + container actions live under a "Manage" submenu.
        menu.addItem(new WatchUi.MenuItem("Manage", "Auth · container", :manage, null));
        menu.addItem(new WatchUi.MenuItem("About car", null, :about, null));
        return menu;
    }

    // F13: consumption-estimate row toggle (default on).
    static function showConsumption() {
        var v = Application.Properties.getValue("showConsumption");
        return (v == null) ? true : v;
    }

    static function consumptionLabel() {
        return showConsumption() ? "On" : "Off";
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

    // FR-23: 0 = use BMW's serviceDistanceKm; >0 = user override (km).
    static function nextMaintenanceKm() {
        var v = Application.Properties.getValue("nextMaintenanceKm");
        return (v == null) ? 0 : v;
    }

    static function nextMaintenanceLabel() {
        var km = nextMaintenanceKm();
        if (km == 0) { return "Auto (BMW)"; }
        return km.toString() + " km";
    }

}

// Routes top-level Settings selections.
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

        } else if (id == :nextMaintenance) {
            // FR-23: cycle in 1000 km steps, 0 ("Auto (BMW)") .. 50000, then wrap to 0.
            var n = SettingsMenu.nextMaintenanceKm() + 1000;
            if (n > 50000) { n = 0; }
            Application.Properties.setValue("nextMaintenanceKm", n);
            item.setSubLabel(SettingsMenu.nextMaintenanceLabel());
            WatchUi.requestUpdate();

        } else if (id == :consumption) {
            // F13: toggle the L/100km estimate on the Range & Fuel page.
            var on = !SettingsMenu.showConsumption();
            Application.Properties.setValue("showConsumption", on);
            item.setSubLabel(SettingsMenu.consumptionLabel());
            WatchUi.requestUpdate();

        } else if (id == :manage) {
            WatchUi.pushView(ManageMenu.build(), new ManageMenuDelegate(), WatchUi.SLIDE_LEFT);

        } else if (id == :about) {
            WatchUi.pushView(AboutMenu.build(), new AboutMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function _tank() {
        var t = Application.Properties.getValue("tankLitres");
        return (t == null) ? 52 : t;
    }

}

// "Manage" submenu — auth + container actions grouped off the top-level Settings list.
class ManageMenu {
    static function build() {
        var menu = new WatchUi.Menu2({ :title => "Manage" });
        menu.addItem(new WatchUi.MenuItem("Re-pair", "Re-authenticate", :repair, null));
        menu.addItem(new WatchUi.MenuItem("Sign out", "Clear tokens", :signout, null));
        menu.addItem(new WatchUi.MenuItem(
            "Delete container", "Re-create on next sync", :deleteContainer, null));
        return menu;
    }
}

class ManageMenuDelegate extends WatchUi.Menu2InputDelegate {

    var _deleter;    // keeps the async ContainerDeleter alive during the request
    var _busyItem;   // the "Delete container" item to update on completion

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();

        if (id == :repair) {
            var auth = new DeviceAuthManager();
            WatchUi.pushView(new AuthView(auth), new AuthDelegate(auth), WatchUi.SLIDE_LEFT);

        } else if (id == :signout) {
            Application.Storage.deleteValue(StorageKeys.KEY_ACCESS_TOKEN);
            Application.Storage.deleteValue(StorageKeys.KEY_REFRESH_TOKEN);
            Application.Storage.deleteValue(StorageKeys.KEY_ACCESS_EXPIRY);
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "UNCONFIGURED");
            // The next pairing may be a different account/vehicle — drop all
            // vehicle-derived state, or write()'s merge would resurrect this
            // car's fields (doorsLocked, windows, ...) onto the next one.
            VehicleCache.clear();
            Application.Storage.deleteValue(StorageKeys.KEY_VEHICLE_NAME);
            Application.Storage.deleteValue(StorageKeys.KEY_BASIC_DATA);
            Application.Storage.deleteValue(StorageKeys.KEY_VIN);
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_NAME);
            item.setSubLabel("Signed out");
            WatchUi.requestUpdate();

        } else if (id == :deleteContainer) {
            // F14: delete the BMW-side container; next sync re-creates it.
            _busyItem = item;
            item.setSubLabel("Deleting…");
            WatchUi.requestUpdate();
            _deleter = new ContainerDeleter();
            _deleter.run(method(:onContainerDeleted));
        }
    }

    // F14: ContainerDeleter completion — reflect result on the menu item.
    function onContainerDeleted(success) {
        if (_busyItem != null) {
            _busyItem.setSubLabel(success ? "Deleted" : "Failed — retry");
        }
        _deleter = null;
        WatchUi.requestUpdate();
    }

}

// "About car" is split into data groups: a top-level group list, each opening a
// read-only key/value sub-menu. Static "Vehicle" info comes from KEY_BASIC_DATA;
// the live telematics groups (v3 container) read from VehicleCache.
class AboutMenu {
    static function build() {
        var menu = new WatchUi.Menu2({ :title => "About car" });
        menu.addItem(new WatchUi.MenuItem("Vehicle",          "Model, body, colour…", :grpVehicle,  null));
        menu.addItem(new WatchUi.MenuItem("Battery & engine", "12V, coolant",         :grpBattery,  null));
        menu.addItem(new WatchUi.MenuItem("Service",          "Maintenance",          :grpService,  null));
        menu.addItem(new WatchUi.MenuItem("Status",           "Range, teleservice…",  :grpStatus,   null));
        menu.addItem(new WatchUi.MenuItem("Location",         "GPS",                  :grpLocation, null));
        return menu;
    }

    // Build the sub-menu for a group id.
    static function group(id) {
        if (id == :grpVehicle)  { return _vehicleMenu(); }
        if (id == :grpBattery)  { return _batteryMenu(); }
        if (id == :grpService)  { return _serviceMenu(); }
        if (id == :grpStatus)   { return _statusMenu(); }
        if (id == :grpLocation) { return _locationMenu(); }
        return _kv("About car", []);
    }

    // Read-only key/value Menu2 from rows = [ [label, valueOrNull], … ];
    // null values are skipped (field unavailable); empty group shows a placeholder.
    static function _kv(title, rows) {
        var menu = new WatchUi.Menu2({ :title => title });
        var any = false;
        for (var i = 0; i < rows.size(); i++) {
            var val = rows[i][1];
            if (val != null) {
                menu.addItem(new WatchUi.MenuItem(rows[i][0], val, null, null));
                any = true;
            }
        }
        if (!any) {
            menu.addItem(new WatchUi.MenuItem("No data yet", "Refresh to load", null, null));
        }
        return menu;
    }

    static function _vehicleMenu() {
        var a = Application.Storage.getValue(StorageKeys.KEY_BASIC_DATA) as Lang.Dictionary or Null;
        return _kv("Vehicle", [
            ["Model",       _str(a, "modelName")],
            ["Series",      _str(a, "series")],
            ["Body",        _str(a, "bodyType")],
            ["Colour",      _str(a, "colourDescription")],
            ["Engine",      _str(a, "engine")],
            ["Drive",       _str(a, "driveTrain")],
            ["Propulsion",  _str(a, "propulsionType")],
            ["Doors",       _str(a, "numberOfDoors")],
            ["Steering",    _str(a, "steering")],
            ["Built",       _date(a, "constructionDate")],
            ["Country",     _str(a, "countryCode")],
            ["Navi",        _str(a, "hasNavi")],
            ["Sunroof",     _str(a, "hasSunRoof")],
            ["Head unit",   _str(a, "headUnit")],
            ["Model key",   _str(a, "modelKey")],
            ["Platform",    _str(a, "seriesDevt")],
            ["SIM",         _str(a, "simStatus")],
            ["Colour code", _str(a, "colourCodeRaw")]
        ]);
    }

    static function _batteryMenu() {
        var s = VehicleCache.read();
        return _kv("Battery & engine", [
            ["12V batt",  _floatU(s, "batteryVoltage", "%.2f", " V")],
            ["Coolant",   _numU(s, "coolantC", " °C")],
            ["HV charge", _numU(s, "socPercent", " %")]
        ]);
    }

    static function _serviceMenu() {
        var s = VehicleCache.read();
        return _kv("Service", [
            ["Next service", _numU(s, "serviceDistanceKm", " km")],
            ["Warn at",      _numU(s, "serviceYellowKm", " km")],
            ["CBS reports",  _numU(s, "cbsCount", "")]
        ]);
    }

    static function _statusMenu() {
        var s = VehicleCache.read();
        return _kv("Status", [
            ["Total range", _numU(s, "totalRangeKm", " km")],
            ["Elec range",  _numU(s, "electricRangeKm", " km")],
            ["Teleservice", _str(s, "teleservice")],
            ["Precondition", _str(s, "preconditioning")],
            ["Deep sleep",  _bool(s, "deepSleep")]
        ]);
    }

    static function _locationMenu() {
        var s = VehicleCache.read();
        return _kv("Location", [
            ["Latitude",  _floatU(s, "lat", "%.5f", "°")],
            ["Longitude", _floatU(s, "lon", "%.5f", "°")],
            ["Altitude",  _numU(s, "altitudeM", " m")],
            ["Heading",   _heading(s, "headingDeg")]
        ]);
    }

    // Heading as degrees + 8-point compass direction, e.g. "350° N".
    static function _heading(d, key) {
        if (d == null || !d.hasKey(key)) { return null; }
        var deg = d[key];
        var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        var idx = (((deg + 22.5) / 45).toNumber()) % 8;
        if (idx < 0) { idx += 8; }
        return deg.toString() + "° " + dirs[idx];
    }

    // --- value formatters: return a display String, or null when absent ---

    static function _str(d, key) {
        if (d == null || !d.hasKey(key)) { return null; }
        var v = d[key].toString();
        return v.equals("") ? "—" : v;
    }

    static function _date(d, key) {
        if (d == null || !d.hasKey(key)) { return null; }
        var v = d[key].toString();
        if (v.length() >= 10) { v = v.substring(0, 10); }
        return v.equals("") ? "—" : v;
    }

    static function _numU(d, key, unit) {
        if (d == null || !d.hasKey(key)) { return null; }
        return d[key].toString() + unit;
    }

    static function _floatU(d, key, fmt, unit) {
        if (d == null || !d.hasKey(key)) { return null; }
        return d[key].format(fmt) + unit;
    }

    static function _bool(d, key) {
        if (d == null || !d.hasKey(key)) { return null; }
        return d[key] ? "Yes" : "No";
    }
}

class AboutMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var id = item.getId();
        // Group rows carry a :grp* id and open a sub-menu; leaf key/value rows
        // have a null id and are read-only.
        if (id != null) {
            WatchUi.pushView(AboutMenu.group(id), new AboutMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}
