# BMW Status — Garmin Connect IQ widget

A Garmin watch **widget** that shows your BMW's live status — range, fuel, lock state,
doors/windows, tyres, odometer and service info — pulled from the official
[BMW CarData](https://bmw-cardata.bmwgroup.com/) REST API. Written in **Monkey C** for
the Connect IQ platform.

> Personal/hobby project. Not affiliated with or endorsed by BMW or Garmin.

## Features

- **Glance** — lock state, range and fuel at a glance in the widget carousel.
- **Range & Fuel** — remaining range, fuel %, litres-in / litres-to-fill, and an
  optional instantaneous consumption estimate (`~L/100 km`). Powertrain-aware: shows
  battery % + electric range on EV/PHEV vehicles.
- **Lock overview** — SECURED / UNLOCKED, per-door open dots (front + rear), hood and
  trunk, plus a red **W** badge for any open window. Prominent data-age indicator.
- **Odometer** — mileage and distance to next service (with an optional user override).
- **Tyres** — per-wheel pressure vs. target, and tyre-wear estimate (START cycles the
  three views).
- **Car location** — the parked car pinned on the watch's own onboard map; START toggles
  a browsable zoom view. Only on devices that ship cartography — 32 of the 36 supported
  products (not base fēnix 6/6s, FR255, FR745).
- **About car** — a grouped, read-only dump of static vehicle info plus live telematics
  (12 V battery, coolant, location, teleservice, …).
- **On-watch settings** — update mode, tank size, service override, consumption toggle,
  and a **Manage** submenu (re-pair / sign out / delete all containers).

## Supported devices

fēnix 6 / 7 / 8 / E families, MARQ, and Forerunner 255 / 745 / 945 / 955 / 965 / 970
(see [`manifest.xml`](manifest.xml)). Developed and tested against **fēnix 6 Pro**
(legacy tier) and **fēnix 8 Pro** (API 6.0+ tier).

## How it works

Pairing uses **OAuth 2.0 Device Authorization Grant** (on-watch — no credential typing).
The design is shaped by the watch running the app in **two processes with very different
memory budgets** — the background heap is only **~28 KB**:

```
                            full container (41 fields)
ForegroundSync ─ full ──────────────────────────────────►┐
(manual START / once-a-day)   CarDataBootstrap + CarDataClient
                                                          ├─ parse ─► VehicleCache ─► Glance + Pages
Background service ─ live ───────────────────────────────►┘   (merge; read-only render)
(scheduled)                 lean bg container (14 live fields)
```

- The **background service** (~28 KB) refreshes the at-a-glance **live** fields (lock,
  doors, windows, range, fuel) from a **lean container** whose response fits that tiny
  heap, and writes a compact Vehicle State to the cache.
- The **foreground app** does the **full** fetch — all pages plus the "About car" detail
  — on a manual refresh (START) or once a day on open, from the **full container**.
  `VehicleCache.write` merges, so background live updates and the last full fetch coexist.
  Its heap is ~1 MB on fēnix 6 Pro but only **64 KB** on the base fēnix 6, and that
  smaller ceiling is what the foreground code size is really budgeted against.
- The **glance and pages** are read-only over the cache — they never do network I/O.
- All vehicle-specific values (client ID, VIN, container IDs, tokens) live only in
  Connect IQ **Settings/Storage** — the source contains **no** hardcoded credentials.

**Full architecture** — process/component map, flows, token FSM, rate-limit/quota and
storage-key reference, with diagrams: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
(rendered diagrams in [`docs/diagrams/`](docs/diagrams/)).

Descriptor reference: [`docs/reference/cardata-catalogue.md`](docs/reference/cardata-catalogue.md)
· curated widget set: [`docs/descriptors.md`](docs/descriptors.md).

**Findings & investigations** — the hard-won knowledge behind the design (verified BMW
CarData API behaviour, real descriptor semantics, and Connect IQ / Monkey C gotchas) is
in [`docs/findings/`](docs/findings/).

## Setup

You need a **BMW CarData client ID** (free, from the BMW CarData portal) and a My BMW
account in a country where CarData is offered (EU / UK). Everything else is automatic:

| Value | Source |
|---|---|
| **clientId** | you provide it (portal) — in app settings, or baked into a personal build |
| refresh / access token | on-watch device-flow pairing |
| VIN | auto-discovered via `/customers/vehicles/mappings` |
| container IDs | two auto-created via `POST /customers/containers`: a **full** one (foreground) + a **lean** one (background poll) |

### 1. Create a BMW CarData client

One-time, ~10 minutes. Portal labels differ per language; the Spanish ones are given as
an example.

1. Sign in to the **My BMW web portal** for your country and open your vehicle overview
   — e.g. `https://www.bmw.es/es-es/mybmw/vehicle-overview`.
2. Open **BMW CARDATA**.
3. In the technical-access section — *Technical access to BMW CarData* / ES *ACCESO
   TÉCNICO A BMW CARDATA* — **create a client** and copy the **Client ID**.
4. Switch on **both** toggles: *CarData API access* (ES *Solicitar acceso a la API de
   CarData*) and *CarData streaming* (ES *Transmisión de CarData*). The widget's OAuth
   scope is `authenticate_user openid cardata:streaming:read cardata:api:read`, so both
   must be enabled even though only the REST API is used.
5. In the streaming section open the **data selection** (ES *Cambiar selección de
   datos*) and tick the [descriptors below](#2-select-the-data-fields). Selecting
   everything works too — the widget never requests anything outside that set.
6. Save and **wait 5–10 minutes**: a freshly created client is not usable immediately.

### 2. Select the data fields

Exactly the 41 descriptors of the widget's **full container** — verbatim from
[`CarDataBootstrap._containerDescriptors`](source/api/CarDataBootstrap.mc#L353-L401).
The lean background container is a 14-field **subset** of the same list (no extra
selection needed), and the two extra endpoints the widget calls — `basicData` and
`smartMaintenanceTyreDiagnosis` — take no descriptors at all.

```text
# Doors, windows, lock  → glance lock state + Lock page
vehicle.cabin.door.lock.status
vehicle.cabin.door.row1.driver.isOpen
vehicle.cabin.door.row1.passenger.isOpen
vehicle.cabin.door.row2.driver.isOpen
vehicle.cabin.door.row2.passenger.isOpen
vehicle.cabin.window.row1.driver.status
vehicle.cabin.window.row1.passenger.status
vehicle.cabin.window.row2.driver.status
vehicle.cabin.window.row2.passenger.status
vehicle.body.trunk.isOpen
vehicle.body.trunk.isLocked
vehicle.body.hood.isOpen

# Range and fuel  → glance + Range & Fuel page
vehicle.drivetrain.totalRemainingRange
vehicle.drivetrain.lastRemainingRange
vehicle.drivetrain.fuelSystem.level
vehicle.drivetrain.fuelSystem.remainingFuel

# Odometer and service  → Odometer page + About car
vehicle.vehicle.travelledDistance
vehicle.status.serviceDistance.next
vehicle.status.serviceDistance.yellow
vehicle.status.conditionBasedServicesCount
vehicle.cabin.infotainment.displayUnit.distance

# Tyres  → Tyres page (wear km comes from the tyre-diagnosis endpoint)
vehicle.chassis.axle.row1.wheel.left.tire.pressure
vehicle.chassis.axle.row1.wheel.right.tire.pressure
vehicle.chassis.axle.row2.wheel.left.tire.pressure
vehicle.chassis.axle.row2.wheel.right.tire.pressure
vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget
vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget
vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget
vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget

# Car location  → map page + About car → Location
vehicle.cabin.infotainment.navigation.currentLocation.latitude
vehicle.cabin.infotainment.navigation.currentLocation.longitude
vehicle.cabin.infotainment.navigation.currentLocation.altitude
vehicle.cabin.infotainment.navigation.currentLocation.heading

# About car → Battery & engine / Status
vehicle.electricalSystem.battery.voltage
vehicle.drivetrain.internalCombustionEngine.engine.ect
vehicle.vehicle.deepSleepModeActive
vehicle.vehicle.preConditioning.activity
vehicle.channel.teleservice.status

# EV / PHEV only (null on ICE — the parser picks the live field)
vehicle.drivetrain.electricEngine.kombiRemainingElectricRange
vehicle.powertrain.electric.battery.stateOfCharge.displayed

# Subscribed for an upcoming feature, not parsed yet
vehicle.cabin.hvac.statusAirPurification
```

Litres are derived from `fuelSystem.level`, not from `remainingFuel` — the latter goes
stale on a running car (see `docs/findings/`). Per-descriptor rationale and the excluded
catalogue: [`docs/descriptors.md`](docs/descriptors.md).

### 3. Pair the watch

1. **Garmin Connect** → your device → *Connect IQ Apps* → **BMW Status** → *Settings* →
   paste the **Client ID**. Leave VIN and Container ID empty.
2. Open the widget → **START to connect**. A pairing code and a link appear.
3. Approve it at the link the watch shows — BMW returns it alongside the code, falling
   back to `customer.bmwgroup.com/oneid/#/link` — on a phone or computer, signing in
   with your BMW account.
4. The watch discovers your VIN, creates both containers and fetches your car. No
   VIN/container typing. The refresh token is ~2-week sliding, renewed on every use — a
   widget you open regularly stays paired.

### Refresh behaviour

- **START** on the *Range & Fuel* or *Lock* page → immediate full refresh (60 s
  cooldown). On *Tyres* START cycles actual/target/wear, on the map page it toggles
  zoom, on *Odometer* it does nothing.
- **Once a day at ~10:00** — a full fetch even in manual mode, which also keeps the
  OAuth token pair alive (FR-25).
- **Update Mode** (*Auto hourly* / *Auto adaptive*) exists only on the **API 6.0+ tier**
  — fēnix 8, fēnix 8 Pro, fēnix 8 Solar, fēnix E, FR970. Every other device is manual +
  daily, and the setting is hidden ([`iq.jungle`](iq.jungle)).
- BMW allows **~50 data calls / 24 h**. A full fetch spends 3 (basicData + tyre
  diagnosis + telematicData), a background poll spends 1; token refresh is exempt.
- Freshness is bounded by the **car**, not the widget: a parked BMW may report every few
  hours. The pages show a data-age indicator for that reason.

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `BMW Widget` / `Press START to connect` | No client ID in settings yet — step 3.1. |
| Pairing fails right after creating the client | The 5–10 min portal activation hasn't completed; retry. |
| `Re-auth needed` / `Press START to re-pair` | Refresh token expired (unopened > ~2 weeks) → **Manage → Re-pair**. |
| Container error / `CU-124` | BMW caps an account at **10 containers**. Onboarding offers to delete all and retry; otherwise **Manage → Delete containers** (the widget re-creates its own). |
| A page is missing, or values are blank | Your car (or your CarData selection) doesn't report that field — pages hide themselves when their key data is absent. |

## Build

Prereqs: the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and a
developer key (`developer_key`).

**Generic build** — no baked credentials, one device at a time
([`monkey.jungle`](monkey.jungle) → [`manifest.xml`](manifest.xml)):

```sh
monkeyc -f monkey.jungle -d fenix6pro -o bin/BmwStatus.prg -y developer_key
```

**Store package** — signed `.iq` for all supported devices, from
[`iq.jungle`](iq.jungle) → `manifest-iq.xml`, which carries a **different app ID** so
the published widget and a personal sideload coexist on one watch. See
[`docs/IQ-STORE-PUBLISH.md`](docs/IQ-STORE-PUBLISH.md):

```sh
./build-personal.sh --iq       # → bin/BMWWIDGET.iq
```

**Personal build** (your client ID baked in, for your own watch) — see
[`docs/PERSONAL-BUILD.md`](docs/PERSONAL-BUILD.md):

```sh
./build-personal.sh            # build + load into the running simulator
./build-personal.sh --device   # sideload-ready .prg for a real watch
```

## Tests

A Monkey C unit-test suite covers parsing, token/quota state machines, and the cache.
See [`docs/TESTING.md`](docs/TESTING.md):

```sh
monkeyc -f monkey.jungle -d fenix6pro -o bin/test.prg -y developer_key --unit-test
# with the Connect IQ simulator running:
monkeydo bin/test.prg fenix6pro -t
```

## Project layout

```
source/            Monkey C app (api/ cache/ guard/ ui/ mock/)
resources/         strings, settings, drawables, properties
resources-modes-*  per-tier settings XML (full = all update modes, legacy = manual only)
resources-src/     icon source art
docs/              build/test docs + BMW CarData descriptor reference
docs/findings/     verified API behaviour, descriptor semantics, CIQ gotchas
monkey.jungle      generic build  → manifest.xml
iq.jungle          store package  → manifest-iq.xml (different app ID)
livetest.jungle    personal build → manifest.xml + resources-livetest (gitignored)
manifest*.xml      app id, supported devices, permissions (Communications + Background)
```

## Privacy

The widget reads your vehicle's data only to display it on your watch; nothing is sent
anywhere except BMW's own API. Captured telematics and any personal config
(VIN, tokens, client ID, simulator settings) are **gitignored** and never committed.

## License

See [`LICENSE`](LICENSE).
