// Single source of truth for Vehicle State persistence.
// RULE: All foreground rendering reads exclusively from VehicleCache.read().
// RULE: Writers are BmwWidgetApp.onBackgroundData() and ForegroundSync (merge via
//       write()); the debug seed uses replace(); sign-out uses clear().
// RULE: Always reference StorageKeys.KEY_* — never inline the key string.
//
// Vehicle State Dictionary schema (all fields optional — absent = unavailable):
//
//   "rangeKm"           : Number  (integer km)          vehicle.drivetrain.lastRemainingRange
//   "fuelPercent"       : Number  (integer 0-100)       vehicle.drivetrain.fuelSystem.level
//   "fuelLitres"        : Number  (integer L)           vehicle.drivetrain.fuelSystem.remainingFuel
//   "doorsLocked"       : Boolean                       vehicle.cabin.door.lock.status (SECURED/LOCKED=true)
//   "doorFLOpen"        : Boolean                       vehicle.cabin.door.row1.driver.isOpen
//   "doorFROpen"        : Boolean                       vehicle.cabin.door.row1.passenger.isOpen
//   "doorRLOpen"        : Boolean                       vehicle.cabin.door.row2.left.isOpen
//   "doorRROpen"        : Boolean                       vehicle.cabin.door.row2.right.isOpen
//   "trunkOpen"         : Boolean                       vehicle.body.trunk.isOpen
//   "hoodOpen"          : Boolean                       vehicle.body.hood.isOpen
//   "engineRunning"     : Boolean                       vehicle.drivetrain.engine.isIgnitionOn
//   "windowFLOpen"      : Boolean (true=OPEN/INTERMEDIATE) vehicle.cabin.window.row1.driver.status
//   "windowFROpen"      : Boolean (true=OPEN/INTERMEDIATE) vehicle.cabin.window.row1.passenger.status
//   "windowRLOpen"      : Boolean (true=OPEN/INTERMEDIATE) vehicle.cabin.window.row2.driver.status
//   "windowRROpen"      : Boolean (true=OPEN/INTERMEDIATE) vehicle.cabin.window.row2.passenger.status
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
    static function read() as Lang.Dictionary or Null {
        return Application.Storage.getValue(StorageKeys.KEY_VEHICLE_STATE) as Lang.Dictionary or Null;
    }

    // Merges newState into the previously cached Vehicle State Dictionary so a poll
    // that omits a field (e.g. doors are skipped while the car is moving) doesn't
    // erase a previously-known value (B3). lastUpdated becomes the max of both.
    // The caller is responsible for type correctness of newState's values.
    static function write(newState as Lang.Dictionary) as Void {
        var existing = Application.Storage.getValue(StorageKeys.KEY_VEHICLE_STATE) as Lang.Dictionary or Null;
        if (existing == null) {
            Application.Storage.setValue(StorageKeys.KEY_VEHICLE_STATE, newState);
            return;
        }
        var merged = existing;
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
        Application.Storage.setValue(StorageKeys.KEY_VEHICLE_STATE, merged);
    }

    // Replaces the cached Vehicle State wholesale — NO merge. For flows where
    // stale fields must not survive: debug seeding, switching vehicles.
    static function replace(newState as Lang.Dictionary) as Void {
        Application.Storage.setValue(StorageKeys.KEY_VEHICLE_STATE, newState);
    }

    // Drops the cached Vehicle State entirely (sign-out: the next pairing may
    // be a different vehicle, and write()'s merge would resurrect this one's data).
    static function clear() as Void {
        Application.Storage.deleteValue(StorageKeys.KEY_VEHICLE_STATE);
    }

}
