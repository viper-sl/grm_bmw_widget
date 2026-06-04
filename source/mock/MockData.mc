// Fixture dictionaries for (:debug) builds only — never compiled into (:release).
// Values match empirical live data from BMW 218i (VIN REDACTED-VIN, 2026-05-29 session).
// Container REDACTED-CONTAINER (v2, 21 descriptors). Mirror live API shape exactly.
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
