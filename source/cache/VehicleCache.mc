// Single source of truth for Vehicle State persistence.
// RULE: All foreground rendering reads exclusively from VehicleCache.read().
// RULE: Writers are BmwWidgetApp.onBackgroundData() and ForegroundSync (merge via
//       write()); the debug seed uses replace(); sign-out uses clear().
// RULE: Always reference StorageKeys.KEY_* — never inline the key string.
//
// Vehicle State Dictionary schema (all fields optional — absent = unavailable):
//
//   "rangeKm"           : Number  (integer km)          best-available range (F16): totalRemainingRange / kombiRemainingElectricRange / lastRemainingRange
//   "fuelPercent"       : Number  (integer 0-100)       vehicle.drivetrain.fuelSystem.level
//   "fuelLitres"        : Number  (integer L)           vehicle.drivetrain.fuelSystem.remainingFuel
//                         NOT RENDERED — BMW only republishes this around a refuel, so it
//                         goes stale while fuelPercent stays fresh (captures show it frozen
//                         for >22 h), and write()'s merge then preserves the stale value
//                         forever. All displayed litres come from FuelMath (percent × tank).
//   "doorsLocked"       : Boolean                       vehicle.cabin.door.lock.status (SECURED/LOCKED=true)
//   "doorFLOpen"        : Boolean                       vehicle.cabin.door.row1.driver.isOpen
//   "doorFROpen"        : Boolean                       vehicle.cabin.door.row1.passenger.isOpen
//   "doorRLOpen"        : Boolean                       vehicle.cabin.door.row2.left.isOpen
//   "doorRROpen"        : Boolean                       vehicle.cabin.door.row2.right.isOpen
//   "trunkOpen"         : Boolean                       vehicle.body.trunk.isOpen
//   "hoodOpen"          : Boolean                       vehicle.body.hood.isOpen
//   "windowFLOpen"      : Boolean (true=OPEN)           vehicle.cabin.window.row1.driver.status
//   "windowFROpen"      : Boolean (true=OPEN)           vehicle.cabin.window.row1.passenger.status
//   "windowRLOpen"      : Boolean (true=OPEN)           vehicle.cabin.window.row2.driver.status
//   "windowRROpen"      : Boolean (true=OPEN)           vehicle.cabin.window.row2.passenger.status
//   "odometerKm"        : Number  (integer km)          vehicle.vehicle.travelledDistance
//   "serviceDistanceKm" : Number  (integer km)          vehicle.status.serviceDistance.next
//   "displayUnit"       : String  ("km" or "miles")     vehicle.cabin.infotainment.displayUnit.distance
//   "tyrePressureFL"    : Float   (bar = kPa / 100.0)   vehicle.chassis.axle.row1.wheel.left.tire.pressure
//   "tyrePressureFR"    : Float   (bar)                 vehicle.chassis.axle.row1.wheel.right.tire.pressure
//   "tyrePressureRL"    : Float   (bar)                 vehicle.chassis.axle.row2.wheel.left.tire.pressure
//   "tyrePressureRR"    : Float   (bar)                 vehicle.chassis.axle.row2.wheel.right.tire.pressure
//   "tyreTargetFL"      : Float   (bar)                 vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget
//   "tyreTargetFR"      : Float   (bar)                 vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget
//   "tyreTargetRL"      : Float   (bar)                 vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget
//   "tyreTargetRR"      : Float   (bar)                 vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget
//   "tyreWearKmFL"      : Number  (integer km)          smartMaintenanceTyreDiagnosis frontLeft.tyreWear.dueMileage
//   "tyreWearKmFR"      : Number  (integer km)          smartMaintenanceTyreDiagnosis frontRight.tyreWear.dueMileage
//   "tyreWearKmRL"      : Number  (integer km)          smartMaintenanceTyreDiagnosis rearLeft.tyreWear.dueMileage
//   "tyreWearKmRR"      : Number  (integer km)          smartMaintenanceTyreDiagnosis rearRight.tyreWear.dueMileage
//   --- About-car telematics (v3; grouped read-only menu, not on any page) ---
//   "batteryVoltage"    : Float   (V)                   vehicle.electricalSystem.battery.voltage
//   "coolantC"          : Number  (°C)                  vehicle.drivetrain.internalCombustionEngine.engine.ect
//   "totalRangeKm"      : Number  (integer km)          vehicle.drivetrain.totalRemainingRange
//   "cbsCount"          : Number  (count)               vehicle.status.conditionBasedServicesCount
//   "serviceYellowKm"   : Number  (integer km)          vehicle.status.serviceDistance.yellow
//   "deepSleep"         : Boolean                       vehicle.vehicle.deepSleepModeActive
//   "preconditioning"   : String                        vehicle.vehicle.preConditioning.activity
//   "teleservice"       : String                        vehicle.channel.teleservice.status
//   "lat"               : Float   (degrees, PII)        vehicle.cabin.infotainment.navigation.currentLocation.latitude
//   "lon"               : Float   (degrees, PII)        vehicle.cabin.infotainment.navigation.currentLocation.longitude
//   "altitudeM"         : Number  (m)                   vehicle.cabin.infotainment.navigation.currentLocation.altitude
//   "headingDeg"        : Number  (degrees)             vehicle.cabin.infotainment.navigation.currentLocation.heading
//   --- F16 multi-powertrain (BEV/PHEV; null on ICE) ---
//   "electricRangeKm"   : Number  (integer km)          vehicle.drivetrain.electricEngine.kombiRemainingElectricRange
//   "socPercent"        : Number  (integer 0-100)       vehicle.powertrain.electric.battery.stateOfCharge.displayed
//   "lastUpdated"       : Number  (epoch seconds)       max(timestamp) across all non-null fields
//
// NOT in schema — computed at render time only:
//   dataAge = Time.now().value() - state["lastUpdated"]
//
// Absent fields: omitted entirely from Dictionary (never stored as null).
// Tyre pressures: already converted from kPa to bar by CarDataClient before write.
using Toybox.Application;
using Toybox.Lang;

(:background)
class VehicleCache {

    // Returns the latest Vehicle State Dictionary, or null if not yet populated.
    // Foreground pages only. The glance reads the lean KEY_GLANCE_STATE projection
    // straight from Storage (see BmwWidgetGlanceView) — it must not reference this class
    // or the write/merge bytecode below would bloat the glance's ~28 KB code image, and
    // deserializing the full ~40-key dict there OOMs on fenix 6 Pro.
    static function read() as Lang.Dictionary or Null {
        return Application.Storage.getValue(StorageKeys.KEY_VEHICLE_STATE) as Lang.Dictionary or Null;
    }

    // Merges newState into the previously cached Vehicle State Dictionary so a poll
    // that omits a field (e.g. doors are skipped while the car is moving) doesn't
    // erase a previously-known value (B3). lastUpdated becomes the max of both.
    // The caller is responsible for type correctness of newState's values.
    static function write(newState as Lang.Dictionary) as Void {
        var existing = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_STATE) as Lang.Dictionary or Null;
        var merged;
        if (existing == null) {
            merged = newState;
        } else {
            merged = existing;
            var keys = newState.keys();
            for (var i = 0; i < keys.size(); i++) {
                var key = keys[i] as Lang.String;
                if (!key.equals("lastUpdated")) {
                    merged[key] = newState[key];
                }
            }
            if (newState.hasKey("lastUpdated")) {
                var prevTs = merged.hasKey("lastUpdated") ? (merged["lastUpdated"] as Lang.Number) : 0;
                var newTs  = newState["lastUpdated"] as Lang.Number;
                merged["lastUpdated"] = (newTs > prevTs) ? newTs : prevTs;
            }
        }
        Application.Storage.setValue(StorageKeys.KEY_VEHICLE_STATE, merged);
        _writeGlanceSummary(merged);
    }

    // Replaces the cached Vehicle State wholesale — NO merge. For flows where
    // stale fields must not survive: debug seeding, switching vehicles.
    static function replace(newState as Lang.Dictionary) as Void {
        Application.Storage.setValue(StorageKeys.KEY_VEHICLE_STATE, newState);
        _writeGlanceSummary(newState);
    }

    // Drops the cached Vehicle State entirely (sign-out: the next pairing may
    // be a different vehicle, and write()'s merge would resurrect this one's data).
    static function clear() as Void {
        Application.Storage.deleteValue(StorageKeys.KEY_VEHICLE_STATE);
        Application.Storage.deleteValue(StorageKeys.KEY_GLANCE_STATE);
    }

    // Project the glance-visible subset of `state` into KEY_GLANCE_STATE so the
    // glance never deserializes the full Vehicle State. Absent fields are omitted
    // (schema convention); an all-absent projection clears the key so the glance
    // falls back to its "Press to set up" state rather than rendering blanks.
    // The key list MUST stay in sync with the fields BmwWidgetGlanceView reads.
    // (Local array, not a static const — static const arrays type as Object at
    // runtime and break .size()/subscript; see findings/connectiq-gotchas.md.)
    static function _writeGlanceSummary(state as Lang.Dictionary) as Void {
        // "fuelLitres" is deliberately absent: the glance derives its "+NNL to fill"
        // from fuelPercent via FuelMath (the raw field is stale — see the schema note).
        var keys = ["doorsLocked", "rangeKm", "fuelPercent", "lastUpdated"];
        var summary = {};
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i];
            if (state.hasKey(k)) { summary[k] = state[k]; }
        }
        if (summary.size() == 0) {
            Application.Storage.deleteValue(StorageKeys.KEY_GLANCE_STATE);
        } else {
            Application.Storage.setValue(StorageKeys.KEY_GLANCE_STATE, summary);
        }
    }

    // Foreground-only backfill for the upgrade transition: an install that predates
    // KEY_GLANCE_STATE has a full Vehicle State but no projection until the next
    // poll/sync. The widget view (64 KB heap) can safely read the full state once
    // to seed it, so the glance isn't blank in the meantime. NEVER call this from
    // glance or background scope — reading the full dict there is the OOM we fixed.
    static function ensureGlanceSummary() as Void {
        if (Application.Storage.getValue(StorageKeys.KEY_GLANCE_STATE) != null) { return; }
        var full = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_STATE) as Lang.Dictionary or Null;
        if (full != null) { _writeGlanceSummary(full); }
    }

}
