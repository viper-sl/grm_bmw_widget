# BMW CarData — Telematics Descriptor Reference

> Source: BMW CarData Telematics Data Catalogue (Customer), EN  
> Captured: 2026-06-14  
> Vehicle context: ICE BMW 218i — most EV/charging descriptors will be null/absent for this vehicle but are included for completeness.

Descriptor strings cleaned of the catalogue's word-break artifact. 'stream' = Streamable column (MQTT). 'kind'=doc marks non-scalar payloads (lists/images/swagger refs) that are not simple telematicData values. Value enums quoted verbatim where given. 'include'=true marks the widget's full-container subscription set (41 scalars — mirrors CarDataBootstrap._containerDescriptors, the source of truth); false = not subscribed. 'observed' = latest value seen in bmw_data/capture_*.json (null = never returned a value on the test vehicle). See docs/descriptors.md for the curated list and empirical findings (B10/B11/B12/B1). Observed values for PII-flagged (location) descriptors are redacted.
**125 descriptors across 8 categories.**


**Legend** — `stream`: ✓ = available on the MQTT streaming channel. `kind`: `scalar` = simple value (container/telematicData); `doc` = list/image/Swagger payload (not a simple value). `PII` marks location data.

## Basic Vehicle Data (6)

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.sim.status` | SIM activation status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | - | true, false | - |  | scalar |
| `vehicle.vehicleIdentification.basicVehicleData` | Basic vehicle data | - | Swagger ../basicData | - |  | DOC |
| `vehicle.drivetrain.batteryManagement.batterySizeMax` | HV battery size<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-300 kWh, INVALID | kWh | ✓ | scalar |
| `vehicle.extras.optionalEquipment.code` | Optional equipment list | - | 4-digit codes, comma-separated | - |  | DOC |
| `vehicle.drivetrain.electricEngine.hvsMaxEnergyAbsolute` | HV battery max energy content<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | - | 0-300 kWh, INVALID | kWh |  | scalar |
| `vehicle.look.image` | Vehicle image | - | PNG file | - |  | DOC |

## Vehicle Status (65)

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.vehicle.antiTheftAlarmSystem.alarm.activationTime` | AntiTheftAlarm activation time<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | - | - | ✓ | scalar |
| `vehicle.vehicle.antiTheftAlarmSystem.alarm.armStatus` | AntiTheftAlarm arm status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | unarmed, doorsOnly, doorsTiltCabin | - | ✓ | scalar |
| `vehicle.vehicle.antiTheftAlarmSystem.alarm.isOn` | AntiTheftAlarm is on<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | boolean | true, false | - | ✓ | scalar |
| `vehicle.channel.teleservice.status` | Teleservice availability | string | PENDING, IDLE, SUCCESSFUL, ERROR | - | ✓ | scalar |
| `vehicle.electricalSystem.battery.voltage` | 12V battery voltage | float | 5 V to 20 V | V | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.profile.mode` | Charging profile mode | string | XML structure (see catalogue) | - | ✓ | DOC |
| `vehicle.cabin.convertible.roofRetractableStatus` | Convertible roof retractable status (Mini)<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | - | - | ✓ | scalar |
| `vehicle.drivetrain.internalCombustionEngine.engine.ect` | Coolant temperature | int16 | 0-150 C / 32-302 F | Celsius | ✓ | scalar |
| `vehicle.channel.ngtp.timeVehicle` | Date and time in vehicle | string | 00:00-23:59 | - | ✓ | scalar |
| `vehicle.status.serviceTime.inspectionDateLegal` | Date of next inspection<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | dd.mm.yyyy hh:mm UTC | - | ✓ | scalar |
| `vehicle.vehicle.deepSleepModeActive` | Deep sleep mode | boolean | true, false | - | ✓ | scalar |
| `vehicle.cabin.infotainment.displayUnit.distance` | Display unit (distance) | string | km, miles | - | ✓ | scalar |
| `vehicle.status.serviceDistance.yellow` | Distance threshold for service info | uint16 | 2000 km / 1243 mi | - | ✓ | scalar |
| `vehicle.cabin.infotainment.navigation.destinationSet.distance` | Distance to nav destination<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | uint16 | 0-100000 km | - | ✓ | scalar |
| `vehicle.status.serviceDistance.next` | Distance to next service | uint16 | 0-100000 km | - | ✓ | scalar |
| `vehicle.cabin.door.status` | Door status (legacy aggregate) | string | ASN_locked/ASN_unlocked/ASN_selective-Locked/ASN_unknown; allDoorsLocked/trunkLocked: ASN_isTrue/ASN_isFalse/ASN_isUnknown | - | ✓ | scalar |
| `vehicle.electronicControlUnit.diagnosticTroubleCodes.raw` | Fault memory | - | - | - | ✓ | DOC |
| `vehicle.cabin.door.row1.driver.position` | Front driver door position | uint8 | 0%-100% | percent | ✓ | scalar |
| `vehicle.cabin.door.row1.passenger.position` | Front passenger door position | uint8 | 0%-100% | percent | ✓ | scalar |
| `vehicle.cabin.door.row2.driver.position` | Rear driver door position | uint8 | 0%-100% | percent | ✓ | scalar |
| `vehicle.cabin.door.row2.passenger.position` | Rear passenger door position | uint8 | 0%-100% | percent | ✓ | scalar |
| `vehicle.cabin.hvac.statusAirPurification` | HVAC air purification status<br>_Included in the container for a future air-purification feature; subscribed but intentionally NOT parsed/rendered yet (no parser key). Null on this ICE vehicle so far. Reviewed 2026-06-14._ | string | UNFILTERED, PURIFYING_ONGOING, PURIFIED, INVALID | - | ✓ | scalar |
| `vehicle.electricalSystem.battery.stateOfCharge` | Low-voltage battery SoC | - | - | % | ✓ | scalar |
| `vehicle.vehicle.travelledDistance` | Mileage / odometer<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | float | 0-500000 km | km | ✓ | scalar |
| `vehicle.cabin.infotainment.isMobilePhoneConnected` | Mobile phone connection | boolean | ASN_isFalse, ASN_isTrue, ASN_isUnknown | - | ✓ | scalar |
| `vehicle.isMoving` | Motion status | boolean | ASN_isFalse, ASN_isTrue, ASN_isUnknown | - | ✓ | scalar |
| `vehicle.cabin.infotainment.navigation.currentLocation.heading` | Vehicle orientation/heading | double | 0-359 | degrees | ✓ | scalar |
| `vehicle.status.conditionBasedServicesCount` | Number of CBS reports | uint16 | 0-60 | - | ✓ | scalar |
| `vehicle.vehicle.preConditioning.isRemoteEngineStartAllowed` | Engine pre-conditioning permission | boolean | true, false, INVALID | - | ✓ | scalar |
| `vehicle.cabin.hvac.preconditioning.status.comfortState` | Preconditioning comfort state<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | NOT_ACTIVE, COMFORT_HEATING, COMFORT_COOLING, COMFORT_VENTILATION, DEFROST, COMFORT_UNDEFINED | - | ✓ | scalar |
| `vehicle.vehicle.preConditioning.activity` | Pre-conditioning status | string | standby, heating, cooling, ventilation, inactive | - | ✓ | scalar |
| `vehicle.body.trunk.window.isOpen` | Rear window unlocking | boolean | CLOSED, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.vehicle.preConditioning.error` | Preconditioning error reason<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | LowFuel, LowBattery, QuotaExceeded, HeaterFailure, ComponentFailure, OpenOrUnlocked, OK, INVALID | - | ✓ | scalar |
| `vehicle.cabin.infotainment.navigation.remainingRange` | Remaining range (nav/fuel) | uint16 | 0-100000 km | - | ✓ | scalar |
| `vehicle.drivetrain.engine.isActive` | State of ignition (isActive) | boolean | ASN_isFalse, ASN_isTrue, ASN_isUnknown | - | ✓ | scalar |
| `vehicle.body.trunk.isOpen` | Status of boot lid / trunk | boolean | CLOSED, OPEN, INVALID (INTERMEDIATE=half-open) | - | ✓ | scalar |
| `vehicle.cabin.convertible.roofStatus` | Status of convertible roof | string | CLOSEDSECURED, OPENSECURED, EMERGENCYLOCKED, HARDTOPMOUNTED, INTERMEDIATEPOSITION, LOADINGPOSITION | - | ✓ | scalar |
| `vehicle.cabin.door.lock.status` | Status of doors (lock) | - | SECURED, UNLOCKED, SELECTIVE-LOCKED, LOCKED, INVALID, UNKNOWN | - |  | scalar |
| `vehicle.drivetrain.engine.isIgnitionOn` | Status of engine (on/off) | boolean | ASN_isFalse, ASN_isTrue, ASN_isUnknown | - | ✓ | scalar |
| `vehicle.cabin.door.row1.driver.isOpen` | Front left door | boolean | OPEN, CLOSED, INVALID, UNKNOWN | - | ✓ | scalar |
| `vehicle.cabin.window.row1.driver.status` | Front left window | string | CLOSED, INTERMEDIATE, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.cabin.door.row1.passenger.isOpen` | Front right door | boolean | OPEN, CLOSED, INVALID, UNKNOWN | - | ✓ | scalar |
| `vehicle.cabin.window.row1.passenger.status` | Front right window | string | CLOSED, INTERMEDIATE, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.body.hood.isOpen` | Status of hood | boolean | CLOSED, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.body.lights.isRunningOn` | Status of lights | boolean | ASN_isFalse, ASN_isTrue, ASN_isUnknown | - | ✓ | scalar |
| `vehicle.cabin.door.row2.driver.isOpen` | Rear left door | boolean | OPEN, CLOSED, INVALID, UNKNOWN | - | ✓ | scalar |
| `vehicle.cabin.window.row2.driver.status` | Rear left window | string | CLOSED, INTERMEDIATE, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.cabin.door.row2.passenger.isOpen` | Rear right door | boolean | OPEN, CLOSED, INVALID, UNKNOWN | - | ✓ | scalar |
| `vehicle.cabin.window.row2.passenger.status` | Rear right window | string | CLOSED, INTERMEDIATE, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.cabin.sunroof.status` | Status of sunroof<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | CLOSED, INTERMEDIATE, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.cabin.sunroof.overallStatus` | Sunroof overall status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | INVALID, OPEN, OPEN_TILT, INTERMEDIATE_TILT, CLOSED | - | ✓ | scalar |
| `vehicle.cabin.sunroof.relativePosition` | Sunroof relative position<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | int8 | -100% to 100% | percent | ✓ | scalar |
| `vehicle.cabin.sunroof.shade.position` | Sunshade position<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | uint8 | 0%-100% | percent | ✓ | scalar |
| `vehicle.drivetrain.fuelSystem.remainingFuel` | Tank content (litres) | float | 0-100 L / 0-26.5 gal | L | ✓ | scalar |
| `vehicle.drivetrain.fuelSystem.level` | Tank level (%) | uint8 | 0%-100%, INVALID | % | ✓ | scalar |
| `vehicle.cabin.sunroof.tiltStatus` | Sunroof tilt status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | CLOSED, INTERMEDIATE, OPEN, INVALID | - | ✓ | scalar |
| `vehicle.status.serviceTime.hUandAuServiceYellow` | Time threshold main/exhaust inspection<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | uint16 | 0-10 months | months | ✓ | scalar |
| `vehicle.status.serviceTime.yellow` | Time threshold for service info<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | uint16 | 4 weeks | weeks | ✓ | scalar |
| `vehicle.cabin.infotainment.navigation.destinationSet.arrivalTime` | Time to nav destination<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | hh:mm | - | ✓ | scalar |
| `vehicle.vehicle.timeSetting` | Time zone setting<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | wintertime, summertime, utc, manual, INVALID | - | ✓ | scalar |
| `vehicle.body.trunk.door.isOpen` | Trunk door open status | boolean | true, false | - | ✓ | scalar |
| `vehicle.body.trunk.isLocked` | Trunk locked status | boolean | true, false | - | ✓ | scalar |
| `vehicle.cabin.infotainment.navigation.currentLocation.altitude` | Vehicle altitude | double | -100 m to 6000 m | - | ✓ | scalar · PII |
| `vehicle.cabin.infotainment.navigation.currentLocation.latitude` | Vehicle position latitude | double | -90 to +90 | degrees | ✓ | scalar · PII |
| `vehicle.cabin.infotainment.navigation.currentLocation.longitude` | Vehicle position longitude | double | -180 to +180 | degrees | ✓ | scalar · PII |

## Usage-Based Vehicle Data (5)

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.vehicle.averageWeeklyDistanceShortTerm` | Average distance/week<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | float | 1-3000 km | - | ✓ | scalar |
| `vehicle.vehicle.averageWeeklyDistanceLongTerm` | Average distance/week (long-life)<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | float | 1-3000 km | - | ✓ | scalar |
| `vehicle.drivetrain.lastRemainingRange` | Last sent remaining range (elec+fuel)<br>_PHEV: e-range+CE range; ICE: CE range; BEV: likely 0. Use only for combustion cars; EVs read kombiRemainingElectricRange._ | float | 0-6500 | km | ✓ | scalar |
| `vehicle.vehicle.speedRange.lowerBound` | Speed range lower | int16 | -100 to 500 km/h | km/h | ✓ | scalar |
| `vehicle.vehicle.speedRange.upperBound` | Speed range upper | int16 | -100 to 500 km/h | km/h | ✓ | scalar |

## Vehicle Events (2)

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.channel.teleservice.lastAutomaticServiceCallTime` | Automatic Teleservice Call<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | dd.mm.yyyy hh:mm UTC | - | ✓ | scalar |
| `vehicle.channel.teleservice.lastTeleserviceReportTime` | Teleservice report | string | dd.mm.yyyy hh:mm:ss UTC | - | ✓ | scalar |

## Electric Vehicle Data (29)

_EV category has ~100 charging/preconditioning descriptors; the most useful state/range/SoC ones are listed. Full set is in the online catalogue. For an ICE 218i these are absent._

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.electricalSystem.battery48V.stateOfHealth.displayed` | 48V battery SoH<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | uint16 | 0%-250% | percent | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.acAmpere` | AC charging current<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | uint8 | 0-25 A | A | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.acVoltage` | AC charging voltage<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-300 V | V | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.timeToFullyCharged` | Remaining charging time<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | uint16 | 0-65500 min, INVALID | min | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.connectorStatus` | Charging connector status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | CONNECTED, DISCONNECTED, ERROR | - | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.method` | Charging method/plug type<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | AC_TYPE1PLUG, AC_TYPE2PLUG, NOCHARGING | - | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.chargingMode` | Charging mode<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | NORMAL_PROGNOSE_BASED, STEP_BASED, PLC_MODE | - | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.connectionType` | Charging process (inductive/conductive)<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | CONDUCTIVE, INDUCTIVE, SIGNAL_INVALID | - | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.phaseNumber` | Charging phases<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | NO_CHARGING, 1-PHASES, 2-PHASES, 3-PHASES, INVALID | - | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.status` | Charging status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | NOCHARGING, INITIALIZATION, CHARGINGACTIVE, CHARGINGPAUSED, CHARGINGENDED, CHARGINGERROR | - | ✓ | scalar |
| `vehicle.powertrain.electric.battery.stateOfCharge.displayed` | Charging status displayed (SoC)<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-100 % | percent | ✓ | scalar |
| `vehicle.drivetrain.batteryManagement.header` | HV battery charging status<br>_Leaf name 'header' looks like a mis-parsed table section-header row, not a real descriptor key — caused CU-402 on container create. Needs verification against a live catalogue._ | float | 0%-100% | percent | ✓ | DOC |
| `vehicle.drivetrain.avgElectricRangeConsumption` | Average electric consumption<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-100 kWh/100km | - | ✓ | scalar |
| `vehicle.vehicle.avgSpeed` | Average speed | uint16 | 0-300 km/h, INVALID | km/h | ✓ | scalar |
| `vehicle.drivetrain.batteryManagement.maxEnergy` | HV battery energy content<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-300 kWh, INVALID | kWh | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.remainingElectricRange` | Estimate of electric range during charging<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-1000 km | km | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.timeRemaining` | Estimate remaining charging time<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | uint16 | 0-200 min | min | ✓ | scalar |
| `vehicle.drivetrain.totalRemainingRange` | Estimate of total range (elec+CE)<br>_PHEV total range (electric + combustion)._ | float | 0-2000 km | km | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.charging.hvStatus` | HV charging system status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | INVALID, CHARGING, ERROR, NOT_CHARGING, WAITING_FOR_CHARGING, FINISHED_FULLY_CHARGED, FINISHED_NOT_FULL | - | ✓ | scalar |
| `vehicle.powertrain.electric.range.target` | Remaining electric range (target SoC)<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-4000 km/mi, INVALID | km | ✓ | scalar |
| `vehicle.drivetrain.electricEngine.kombiRemainingElectricRange` | Remaining electric range<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | float | 0-4000 km, INVALID | - | ✓ | scalar |
| `vehicle.powertrain.electric.battery.stateOfCharge.target` | Target SoC<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | uint8 | 0-100 (10% steps), INVALID | % | ✓ | scalar |
| `vehicle.body.chargingPort.status` | Status of charging plug<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | CONNECTED, DISCONNECTED, INVALID, -NA- | - | ✓ | scalar |
| `vehicle.body.chargingPort.combinedStatus` | Charging port connection status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | DISCONNECTED, CONNECTED, INVALID | - |  | scalar |
| `vehicle.powertrain.electric.battery.charging.power` | Charging power<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | int32 | - | W | ✓ | scalar |
| `vehicle.powertrain.electric.battery.stateOfHealth.displayed` | HV battery SoH (SOCE)<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | - | - | - |  | scalar |
| `vehicle.drivetrain.electricEngine.charging.windowSelection` | Charging window selection<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | CHOSEN, NOTCHOSEN, -NA- | - | ✓ | scalar |
| `vehicle.powertrain.tractionBattery.charging.port.anyPosition.flap.isOpen` | Charging port flap open<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | boolean | true, false | - | ✓ | scalar |
| `vehicle.powertrain.tractionBattery.charging.port.anyPosition.isPlugged` | Charging port plugged<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | boolean | true, false | - | ✓ | scalar |

## Metadata (4)

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.cabin.infotainment.hmi.distanceUnit` | Infotainment distance unit<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | MILES, KILOMETERS | - | ✓ | scalar |
| `vehicle.cabin.infotainment.navigation.currentLocation.fixStatus` | Navigation fix status<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | string | NO_FIX, GPS_FIX_2D, GPS_FIX_3D | - | ✓ | scalar |
| `vehicle.cabin.infotainment.navigation.currentLocation.numberOfSatellites` | Navigation satellite count<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14)._ | uint8 | - | - | ✓ | scalar |
| `vehicle.powertrain.electric.range.displayControl` | Electric range display control<br>_Excluded from test container — not needed for widget (reviewed 2026-06-14, EV/charging or low-value field on this ICE vehicle)._ | string | - | - | ✓ | scalar |

## Tyre Data (13)

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.chassis.axle.row1.wheel.left.tire.pressure` | Tyre pressure FL | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row1.wheel.right.tire.pressure` | Tyre pressure FR | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row2.wheel.left.tire.pressure` | Tyre pressure RL | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row2.wheel.right.tire.pressure` | Tyre pressure RR | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget` | Tyre target FL | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget` | Tyre target FR | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget` | Tyre target RL | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget` | Tyre target RR | uint16 | 0-1000 kPa, -NA- | kPa | ✓ | scalar |
| `vehicle.chassis.axle.row1.wheel.left.tire.temperature` | Tyre temp FL | float | 0-50 C | Celsius | ✓ | scalar |
| `vehicle.chassis.axle.row1.wheel.right.tire.temperature` | Tyre temp FR | float | 0-50 C | Celsius | ✓ | scalar |
| `vehicle.chassis.axle.row2.wheel.left.tire.temperature` | Tyre temp RL | float | 0-50 C | Celsius | ✓ | scalar |
| `vehicle.chassis.axle.row2.wheel.right.tire.temperature` | Tyre temp RR | float | 0-50 C | Celsius | ✓ | scalar |
| `vehicle.chassis.axle.wheel.tire.diagnosis` | Smart Maintenance tyre diagnostics<br>_Separate REST endpoint, no container needed._ | - | Swagger ../smartMaintenanceTyreDiagnosis | - |  | DOC |

## ConnectedDrive Contract (1)

| Descriptor | Name | Type | Values | Unit | Stream | Kind |
|---|---|---|---|---|:--:|:--:|
| `vehicle.vehicleIdentification.connectedDriveContractList` | Active ConnectedDrive contracts | - | yyyy-mm-dd hh:mm:ss UTC | - |  | DOC |
