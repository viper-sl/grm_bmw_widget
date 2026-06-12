// UNIT-TEST fixtures only — referenced exclusively from Tests.mc ((:debug) keeps
// this out of (:release) builds; the app itself has no mock layer and always
// talks to the live API).
// Values match empirical live data from BMW 218i (VIN REDACTED-VIN, 2026-05-29 session).
// Container grm_bmw_widget_v2 (27 descriptors). Mirror live API shape exactly.
(:debug :background)
class MockData {

    static function telematicFixture() {
        return {
            "telematicData" => {
                "vehicle.cabin.door.lock.status"
                    => { "value" => "SECURED", "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.drivetrain.lastRemainingRange"
                    => { "value" => "653",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "km" },
                "vehicle.drivetrain.fuelSystem.level"
                    => { "value" => "95",      "timestamp" => "2026-05-27T17:53:20Z", "unit" => "%" },
                "vehicle.drivetrain.fuelSystem.remainingFuel"
                    => { "value" => "21",      "timestamp" => "2026-05-24T12:15:23Z", "unit" => "l" },
                "vehicle.cabin.door.row1.driver.isOpen"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.cabin.door.row1.passenger.isOpen"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.cabin.door.row2.driver.isOpen"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.cabin.door.row2.passenger.isOpen"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.body.trunk.isOpen"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.body.trunk.isLocked"
                    => { "value" => null,      "timestamp" => null,                   "unit" => null },
                "vehicle.body.hood.isOpen"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.vehicle.travelledDistance"
                    => { "value" => "40926",   "timestamp" => "2026-05-27T17:53:20Z", "unit" => "km" },
                "vehicle.status.serviceDistance.next"
                    => { "value" => "22000",   "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.cabin.infotainment.displayUnit.distance"
                    => { "value" => "km",      "timestamp" => "2026-05-24T12:15:23Z", "unit" => null },
                "vehicle.drivetrain.engine.isIgnitionOn"
                    => { "value" => null,      "timestamp" => null,                   "unit" => null },
                "vehicle.cabin.window.row1.driver.status"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.cabin.window.row1.passenger.status"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.cabin.window.row2.driver.status"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.cabin.window.row2.passenger.status"
                    => { "value" => "CLOSED",  "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
                "vehicle.chassis.axle.row1.wheel.left.tire.pressure"
                    => { "value" => "230",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
                "vehicle.chassis.axle.row1.wheel.right.tire.pressure"
                    => { "value" => "230",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
                "vehicle.chassis.axle.row2.wheel.left.tire.pressure"
                    => { "value" => "220",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
                "vehicle.chassis.axle.row2.wheel.right.tire.pressure"
                    => { "value" => "230",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
                "vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget"
                    => { "value" => "220",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
                "vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget"
                    => { "value" => "220",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
                "vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget"
                    => { "value" => "220",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
                "vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget"
                    => { "value" => "220",     "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" }
            }
        };
    }

    static function tyreDiagnosisFixture() {
        return {
            "passengerCar" => {
                "mountedTyres" => {
                    "frontLeft"  => { "tyreWear" => { "dueMileage" => 11500, "status" => "OK", "unit" => "KILOMETER" } },
                    "frontRight" => { "tyreWear" => { "dueMileage" => 11500, "status" => "OK", "unit" => "KILOMETER" } },
                    "rearLeft"   => { "tyreWear" => { "dueMileage" => 10500, "status" => "OK", "unit" => "KILOMETER" } },
                    "rearRight"  => { "tyreWear" => { "dueMileage" => 10500, "status" => "OK", "unit" => "KILOMETER" } }
                }
            }
        };
    }

    static function basicDataFixture() {
        return {
            "brand"      => "BMW",
            "modelName"  => "218i",
            "driveTrain" => "CONV",
            "series"     => "2",
            "countryCode" => "ES"
        };
    }

}
