// Single source of truth for Vehicle State persistence.
// RULE: All foreground rendering reads exclusively from VehicleCache.read().
// RULE: Only BmwWidgetApp.onBackgroundData() writes here (receives Background.exit payload).
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
//   "trunkOpen"         : Boolean                       vehicle.body.trunk.isOpen
//   "hoodOpen"          : Boolean                       vehicle.body.hood.isOpen
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
//   "lastUpdated"       : Number  (epoch seconds)       max(timestamp) across all non-null fields
//
// NOT in schema — computed at render time only:
//   dataAge = Time.now().value() - state["lastUpdated"]
//
// Absent fields: omitted entirely from Dictionary (never stored as null).
// Tyre pressures: already converted from kPa to bar by CarDataClient before write.
using Toybox.Application;

(:background)
class VehicleCache {

    // Returns the latest Vehicle State Dictionary, or null if not yet populated.
    static function read() {
        return Application.Storage.getValue(StorageKeys.KEY_VEHICLE_STATE);
    }

    // Writes the complete Vehicle State Dictionary to persistent Storage.
    // The caller (BmwWidgetApp.onBackgroundData) is responsible for type correctness.
    static function write(vehicleState) {
        Application.Storage.setValue(StorageKeys.KEY_VEHICLE_STATE, vehicleState);
    }

}
