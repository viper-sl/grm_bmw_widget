# BMW CarData descriptors — final widget set

Working curation of the BMW CarData telematics catalogue for the GRM BMW widget.
This is the **source of truth for which descriptors the widget subscribes to**;
[reference/cardata-descriptors.json](reference/cardata-descriptors.json) mirrors it
(`include` flag) and the build script reads that JSON to create the container.

## How to read each row

```
[-]<descriptor path>   | <human name> [✓confirmed]   | <observed value | NULL>
```

| Marker | Meaning |
|---|---|
| `-` prefix | **Excluded** — not subscribed by the widget (EV/charging-only, redundant, or low value on this ICE vehicle). Toggle the `-` to include/exclude. |
| `✓confirmed` | Descriptor returned a non-null value in a real `telematicData` response (live container, 2026-05-27). |
| 3rd column | Latest **observed value** across all `bmw_data/capture_*.json` runs, or `NULL` if it has never returned a value on this vehicle. |

## Summary (40 included / 78 excluded)

- **40 included** descriptors — 32 have returned a live value, **8 are included but never observed in the 7 captures** (the discovery container omitted some; e.g. `travelledDistance` is `✓confirmed` from container v2 but wasn't in the probe set). Deliberate keeps: rear doors+windows, `trunk.isLocked`, `deepSleepModeActive`, odometer; `hvac.statusAirPurification` is subscribed for a **future air-purification feature** — intentionally not parsed/rendered yet.
- **78 excluded** — overwhelmingly EV/PHEV charging, sunroof/convertible, and detail fields not surfaced by the widget.
- Observed values sourced from the 7 captures (`secured-baseline`, `engine-on`, `moving`; 2026-06-13/14) against test container (62-descriptor discovery container).

> **Note on the live container:** the discovery container carries 62
> descriptors (everything that was *plausibly* capturable). This file's **40-descriptor
> included set is the final widget target** — rebuild the container from it
> (`build_test_container.py`, which now reads `include`) when ready to slim the live set.
> The on-watch widget container (`CarDataClient._containerDescriptors`, **v3**) carries
> **41** descriptors: the ICE render/About set (`isIgnitionOn` dropped as a dead prop;
> `hvac.statusAirPurification` subscribed for a future feature, not yet parsed) **plus 2
> EV/PHEV fields for F16** (`kombiRemainingElectricRange`, electric SoC) that are null on
> this ICE car but let the same build support BEV/PHEV vehicles.

## Key empirical findings (from these captures)

- **Ignition / motion never populate** (`engine.isIgnitionOn`, `engine.isActive`, `isMoving` = NULL even engine-on **and** while moving) → BMW does not report these for this vehicle/account. [B10 won't-fix], and the residual of [B5] (shows LOCKED while driving).
- **`window.*.status` `INTERMEDIATE`** persists with the door fully closed (frameless-window reseat state), so only `OPEN` counts as open. [B11 fixed]
- **`fuelSystem.remainingFuel`** is frozen (44 l, stale timestamp) while `fuelSystem.level` tracks live (99→82 %) → compute litres-to-fill from `level` only. [B12]
- **`door.lock.status`** observed enum = `LOCKED` / `UNLOCKED` / `SECURED` (all handled by the parser) → the glance "no status label" case ([B1]) is the **null/INVALID / no-signal** path, not a missing enum value.

---

-vehicle.sim.status                                                     | SIM activation status | NULL
-vehicle.drivetrain.batteryManagement.batterySizeMax                    | HV battery size | NULL
-vehicle.drivetrain.electricEngine.hvsMaxEnergyAbsolute                 | HV battery max energy content | NULL
-vehicle.vehicle.antiTheftAlarmSystem.alarm.activationTime              | AntiTheftAlarm activation time | NULL
-vehicle.vehicle.antiTheftAlarmSystem.alarm.armStatus                   | AntiTheftAlarm arm status | NULL
-vehicle.vehicle.antiTheftAlarmSystem.alarm.isOn                        | AntiTheftAlarm is on | NULL
vehicle.channel.teleservice.status                                     | Teleservice availability | Initial status
vehicle.electricalSystem.battery.voltage                               | 12V battery voltage | 13.56 V
-vehicle.cabin.convertible.roofRetractableStatus                        | Convertible roof retractable status (Mini) | NULL
vehicle.drivetrain.internalCombustionEngine.engine.ect                 | Coolant temperature | 93 °C
-vehicle.channel.ngtp.timeVehicle                                        | Date and time in vehicle | NULL
-vehicle.status.serviceTime.inspectionDateLegal                         | Date of next inspection | NULL
vehicle.vehicle.deepSleepModeActive                                    | Deep sleep mode | NULL
vehicle.cabin.infotainment.displayUnit.distance                        | Display unit (distance) ✓confirmed | km
vehicle.status.serviceDistance.yellow                                  | Distance threshold for service info | 2000
-vehicle.cabin.infotainment.navigation.destinationSet.distance          | Distance to nav destination | NULL
vehicle.status.serviceDistance.next                                    | Distance to next service ✓confirmed | 21000
-vehicle.cabin.door.status                                              | Door status (legacy aggregate) | NULL
-vehicle.cabin.door.row1.driver.position                                | Front driver door position | NULL
-vehicle.cabin.door.row1.passenger.position                             | Front passenger door position | NULL
-vehicle.cabin.door.row2.driver.position                                | Rear driver door position | NULL
-vehicle.cabin.door.row2.passenger.position                             | Rear passenger door position | NULL
vehicle.cabin.hvac.statusAirPurification                               | HVAC air purification status | NULL
-vehicle.electricalSystem.battery.stateOfCharge                         | Low-voltage battery SoC | NULL
vehicle.vehicle.travelledDistance                                      | Mileage / odometer ✓confirmed | NULL
-vehicle.cabin.infotainment.isMobilePhoneConnected                      | Mobile phone connection | NULL
-vehicle.isMoving                                                       | Motion status | NULL
vehicle.cabin.infotainment.navigation.currentLocation.heading          | Vehicle orientation/heading | 358 degrees
vehicle.status.conditionBasedServicesCount                             | Number of CBS reports | 6
-vehicle.vehicle.preConditioning.isRemoteEngineStartAllowed             | Engine pre-conditioning permission | false
-vehicle.cabin.hvac.preconditioning.status.comfortState                 | Preconditioning comfort state | NULL
vehicle.vehicle.preConditioning.activity                               | Pre-conditioning status | INACTIVE
-vehicle.body.trunk.window.isOpen                                       | Rear window unlocking | NULL
-vehicle.vehicle.preConditioning.error                                  | Preconditioning error reason | NULL
-vehicle.cabin.infotainment.navigation.remainingRange                   | Remaining range (nav/fuel) | NULL
-vehicle.drivetrain.engine.isActive                                     | State of ignition (isActive) | NULL
vehicle.body.trunk.isOpen                                              | Status of boot lid / trunk ✓confirmed | CLOSED
-vehicle.cabin.convertible.roofStatus                                   | Status of convertible roof | NULL
vehicle.cabin.door.lock.status                                         | Status of doors (lock) ✓confirmed | LOCKED
-vehicle.drivetrain.engine.isIgnitionOn                                 | Status of engine (on/off) ✓confirmed | NULL
vehicle.cabin.door.row1.driver.isOpen                                  | Front left door ✓confirmed | CLOSED
vehicle.cabin.window.row1.driver.status                                | Front left window | CLOSED
vehicle.cabin.door.row1.passenger.isOpen                               | Front right door ✓confirmed | CLOSED
vehicle.cabin.window.row1.passenger.status                             | Front right window | CLOSED
vehicle.body.hood.isOpen                                               | Status of hood ✓confirmed | CLOSED
-vehicle.body.lights.isRunningOn                                        | Status of lights | NULL
vehicle.cabin.door.row2.driver.isOpen                                  | Rear left door | NULL
vehicle.cabin.window.row2.driver.status                                | Rear left window | NULL
vehicle.cabin.door.row2.passenger.isOpen                               | Rear right door | NULL
vehicle.cabin.window.row2.passenger.status                             | Rear right window | NULL
-vehicle.cabin.sunroof.status                                           | Status of sunroof | NULL
-vehicle.cabin.sunroof.overallStatus                                    | Sunroof overall status | NULL
-vehicle.cabin.sunroof.relativePosition                                 | Sunroof relative position | NULL
-vehicle.cabin.sunroof.shade.position                                   | Sunshade position | NULL
vehicle.drivetrain.fuelSystem.remainingFuel                            | Tank content (litres) ✓confirmed | 44 l
vehicle.drivetrain.fuelSystem.level                                    | Tank level (%) ✓confirmed | 82 %
-vehicle.cabin.sunroof.tiltStatus                                       | Sunroof tilt status | NULL
-vehicle.status.serviceTime.hUandAuServiceYellow                        | Time threshold main/exhaust inspection | NULL
-vehicle.status.serviceTime.yellow                                      | Time threshold for service info | NULL
-vehicle.cabin.infotainment.navigation.destinationSet.arrivalTime       | Time to nav destination | NULL
-vehicle.vehicle.timeSetting                                            | Time zone setting | NULL
vehicle.body.trunk.door.isOpen                                         | Trunk door open status | false
vehicle.body.trunk.isLocked                                            | Trunk locked status ✓confirmed | NULL
vehicle.cabin.infotainment.navigation.currentLocation.altitude         | Vehicle altitude | 211
vehicle.cabin.infotainment.navigation.currentLocation.latitude         | Vehicle position latitude | REDACTED degrees
vehicle.cabin.infotainment.navigation.currentLocation.longitude        | Vehicle position longitude | REDACTED degrees
-vehicle.vehicle.averageWeeklyDistanceShortTerm                         | Average distance/week | NULL
-vehicle.vehicle.averageWeeklyDistanceLongTerm                          | Average distance/week (long-life) | NULL
vehicle.drivetrain.lastRemainingRange                                  | Last sent remaining range (elec+fuel) ✓confirmed | 499 km
-vehicle.vehicle.speedRange.lowerBound                                  | Speed range lower | NULL
-vehicle.vehicle.speedRange.upperBound                                  | Speed range upper | NULL
-vehicle.channel.teleservice.lastAutomaticServiceCallTime               | Automatic Teleservice Call | NULL
-vehicle.channel.teleservice.lastTeleserviceReportTime                  | Teleservice report | NULL
-vehicle.electricalSystem.battery48V.stateOfHealth.displayed            | 48V battery SoH | NULL
-vehicle.drivetrain.electricEngine.charging.acAmpere                    | AC charging current | NULL
-vehicle.drivetrain.electricEngine.charging.acVoltage                   | AC charging voltage | NULL
-vehicle.drivetrain.electricEngine.charging.timeToFullyCharged          | Remaining charging time | NULL
-vehicle.drivetrain.electricEngine.charging.connectorStatus             | Charging connector status | NULL
-vehicle.drivetrain.electricEngine.charging.method                      | Charging method/plug type | NULL
-vehicle.drivetrain.electricEngine.charging.chargingMode                | Charging mode | NULL
-vehicle.drivetrain.electricEngine.charging.connectionType              | Charging process (inductive/conductive) | NULL
-vehicle.drivetrain.electricEngine.charging.phaseNumber                 | Charging phases | NULL
-vehicle.drivetrain.electricEngine.charging.status                      | Charging status | NULL
-vehicle.powertrain.electric.battery.stateOfCharge.displayed            | Charging status displayed (SoC) | NULL
-vehicle.drivetrain.batteryManagement.header                            | HV battery charging status | NULL
-vehicle.drivetrain.avgElectricRangeConsumption                         | Average electric consumption | NULL
-vehicle.vehicle.avgSpeed                                               | Average speed | NULL
-vehicle.drivetrain.batteryManagement.maxEnergy                         | HV battery energy content | NULL
-vehicle.drivetrain.electricEngine.remainingElectricRange               | Estimate of electric range during charging | NULL
-vehicle.drivetrain.electricEngine.charging.timeRemaining               | Estimate remaining charging time | NULL
vehicle.drivetrain.totalRemainingRange                                 | Estimate of total range (elec+CE) | 499 km
-vehicle.drivetrain.electricEngine.charging.hvStatus                    | HV charging system status | NULL
-vehicle.powertrain.electric.range.target                               | Remaining electric range (target SoC) | NULL
-vehicle.drivetrain.electricEngine.kombiRemainingElectricRange          | Remaining electric range | NULL
-vehicle.powertrain.electric.battery.stateOfCharge.target               | Target SoC | NULL
-vehicle.body.chargingPort.status                                       | Status of charging plug | NULL
-vehicle.body.chargingPort.combinedStatus                               | Charging port connection status | NULL
-vehicle.powertrain.electric.battery.charging.power                     | Charging power | NULL
-vehicle.powertrain.electric.battery.stateOfHealth.displayed            | HV battery SoH (SOCE) | NULL
-vehicle.drivetrain.electricEngine.charging.windowSelection             | Charging window selection | NULL
-vehicle.powertrain.tractionBattery.charging.port.anyPosition.flap.isOpen | Charging port flap open | NULL
-vehicle.powertrain.tractionBattery.charging.port.anyPosition.isPlugged | Charging port plugged | NULL
-vehicle.cabin.infotainment.hmi.distanceUnit                            | Infotainment distance unit | NULL
-vehicle.cabin.infotainment.navigation.currentLocation.fixStatus        | Navigation fix status | NULL
-vehicle.cabin.infotainment.navigation.currentLocation.numberOfSatellites | Navigation satellite count | NULL
-vehicle.powertrain.electric.range.displayControl                       | Electric range display control | NULL
vehicle.chassis.axle.row1.wheel.left.tire.pressure                     | Tyre pressure FL ✓confirmed | 230 kPa
vehicle.chassis.axle.row1.wheel.right.tire.pressure                    | Tyre pressure FR ✓confirmed | 230 kPa
vehicle.chassis.axle.row2.wheel.left.tire.pressure                     | Tyre pressure RL ✓confirmed | 230 kPa
vehicle.chassis.axle.row2.wheel.right.tire.pressure                    | Tyre pressure RR ✓confirmed | 230 kPa
vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget               | Tyre target FL ✓confirmed | 230 kPa
vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget              | Tyre target FR ✓confirmed | 230 kPa
vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget               | Tyre target RL ✓confirmed | 230 kPa
vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget              | Tyre target RR ✓confirmed | 230 kPa
-vehicle.chassis.axle.row1.wheel.left.tire.temperature                  | Tyre temp FL | NULL
-vehicle.chassis.axle.row1.wheel.right.tire.temperature                 | Tyre temp FR | NULL
-vehicle.chassis.axle.row2.wheel.left.tire.temperature                  | Tyre temp RL | NULL
-vehicle.chassis.axle.row2.wheel.right.tire.temperature                 | Tyre temp RR | NULL
