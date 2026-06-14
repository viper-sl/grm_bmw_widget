# BMW Widget Backlog

Items B3–B6, B8, F7, F9–F12 were implemented 2026-06-12 via PRD FR-15–26
(`_bmad-output/planning-artifacts/prds/prd-grm_bmw_widget-2026-06-10/`).

## Bugs

### ✅ B1 — Glance: no status label when car is open *(fixed 2026-06-14)*
When the car is in open/unlocked state, the glance view shows no status label at all.

**Finding (2026-06-14 captures):** `vehicle.cabin.door.lock.status` reliably returns
`LOCKED` / `UNLOCKED` / `SECURED` on this vehicle, and the parser maps all three
(`SECURED`/`LOCKED`→`doorsLocked=true`, `UNLOCKED`→`false`). So when genuinely unlocked
`doorsLocked` *is* set and the glance *does* draw "OPEN" — the "no label at all" case is
the **absent-field path** (`doorsLocked` omitted on `INVALID`/`UNKNOWN`/no-signal). Same
data-availability family as B3 and B10.

**Fix:** `BmwWidgetGlanceView` row 1 now draws a muted "—" when `doorsLocked` is absent,
so the row never goes blank (the `LOCKED`/`OPEN` branch is unchanged for the known case).

_Effort: S · Risk: Low._

### ✅ B2 — Glance: fuel label shows litres only after threshold *(done 2026-06-13)*
Currently fuel is displayed as `FUEL 31l`. After the threshold it should show both percentage and litres: `XX% (31l)` instead of only litres.

**Fix:** glance row 3 now shows `XX% (+YYL)` below 50% (YY = litres still needed to
fill), and drops the "FUEL" prefix whenever a percentage is shown.

### ✅ B3 — Car parked as open, no signal → lock status page disappears *(done 2026-06-12, FR-15/16)*
Scenario: car goes to parking in open state, signal is lost, no further updates received.
Result: the lock status page vanishes entirely. Needs investigation — likely the page is dismissed when state becomes stale/unknown.

**Fix:** `VehicleCache.write()` is now merge-on-write — a fetch that omits `doorsLocked` no longer erases it, so `PageLock.isVisible()` stays true once the field has ever been seen.

### ✅ B4 — Lock status page: door status not updated on manual refresh *(done 2026-06-12, FR-19/20)*
When a door is physically open, manual status update still shows doors as locked.
Hood and trunk open states are also not reflected.

**Fix:** rear-door descriptors added (container v2), 3×2 door/hood/trunk grid on PageLock, plus a prominent data-age indicator since CarData has no fixed refresh interval.

### ✅ B5 — Lock status page: shows "locked" while driving *(done 2026-06-12, FR-17)*
**Fix:** `vehicle.drivetrain.engine.isIgnitionOn` parsed into `engineRunning`; PageLock shows an amber RUNNING state that takes precedence over locked/unlocked.

⚠️ **Residual (2026-06-14, see [B10](#b10--running-status-never-shown-fr-17-regressiongap)):** a live
`moving` capture shows `door.lock.status = LOCKED` while the car was actually moving,
with `isIgnitionOn`/`isActive`/`isMoving` all still null — so on this vehicle PageLock
will display plain "LOCKED" while driving, same symptom B5 set out to fix. The parse
logic is correct; the underlying descriptors just never populate for this
vehicle/account. Tracked under B10, not reopening B5.

### ✅ B6 — Lock status page: no red W indicator for open windows *(done 2026-06-12, FR-18)*
**Fix:** four window descriptors added (container v2); red **W** badge renders next to the status label when any window is OPEN/INTERMEDIATE.

### ✅ B8 — Tyre wear status missing (regression) *(verified 2026-06-12, FR-21)*
**Outcome:** verify-then-fix — parsing and PageTyres rendering confirmed correct; no code gap. Container v2 migration re-establishes the descriptor set.

### ✅ B9 — No-internet case shows raw "auth failed error 104" *(fixed 2026-06-14)*
When the watch has no internet connectivity, auth calls failed with a raw error code
(e.g. "Device code HTTP -104") instead of a user-friendly message.

**Fix:** `DeviceAuthManager` now pre-flights `System.getDeviceSettings().phoneConnected`
in `start()` (→ "No phone connection" up front), and both response callbacks route
through `_friendlyError(responseCode)`: `BLE_CONNECTION_UNAVAILABLE` (-104) → "No phone
connection", any negative → "No connection — check phone", `401` → "Auth expired —
retry", `429` → "Daily limit reached", other positive → "Server error N". The raw
negative transport code is never shown. (OAuth error strings like `expired_token` are
still passed through as they're already meaningful.)

_Effort: S · Risk: Low._

### ✅ B10 — RUNNING status never shown (FR-17 regression/gap) *(resolved won't-fix + dead code removed 2026-06-14)*
Despite FR-17 (B5) mapping `vehicle.drivetrain.engine.isIgnitionOn` →
`engineRunning` and PageLock rendering an amber RUNNING state, the RUNNING status
is still never displayed.

**Finding (2026-06-14, engine-on capture):** captured `telematicData` with the engine
physically running — `vehicle.drivetrain.engine.isIgnitionOn` and
`vehicle.drivetrain.engine.isActive` are **still null/absent**, same as on the parked
baseline. `vehicle.isMoving` is also null. Other "live" fields in the same capture
(`totalRemainingRange` 686→499, `lastRemainingRange` 499, GPS, door/window/lock status)
all refreshed with a `16:01:31`/`16:01:46` timestamp, while `ect` (coolant temp, 93°C —
plausible for a running engine) and `battery.voltage` stayed pinned to the original
`2026-06-13T17:05:44` snapshot. So this isn't a timing/freshness issue with this one
capture — BMW CarData simply does not report ignition/engine-active state for this
vehicle (or this account/contract tier), regardless of actual engine state.

A follow-up `moving` capture (2026-06-14T16:10:36, ~9 min later, GPS position shifted
~16 m) confirms the same: `isIgnitionOn`/`isActive`/`isMoving` are all still
null/absent while the car was actually moving, and `door.lock.status` reads `LOCKED`
throughout — see [B5](#-b5--lock-status-page-shows-locked-while-driving-done-2026-06-12-fr-17).

**Conclusion:** the FR-17/B5 "amber RUNNING state" can never trigger with the data this
vehicle provides — `engineRunning` will always be `null`/false. Not a parser bug, no
further capture will help.

**Resolution (2026-06-14):** removed the dead code rather than leave an unreachable
branch. `engine.isIgnitionOn` dropped from the container (v3); the `engineRunning` parse
block, the `PageLock` RUNNING branch, the `VehicleCache` schema entry, the MockData
fixture entry, and `testParse_engineRunningVariants` are all gone. `PageLock` now shows
only SECURED/UNLOCKED. If a future vehicle/account does populate ignition, re-add the
descriptor + a parse + branch.

_Effort: S · Risk: Low · **Resolved — won't-fix for this vehicle, dead code removed**._

### ✅ B11 — Red "W" badge shows on door-open even when window is closed (FR-18 bug) *(fixed 2026-06-14)*
The per-door red **W** window-open badge (FR-18) appears when a *door* is opened
even though that door's *window* is not open.

**Fix:** live captures (2026-06-14, ~15:52-15:54) caught the driver door cycling
OPEN→CLOSED while `window.row1.driver.status` went CLOSED→INTERMEDIATE→CLOSED→INTERMEDIATE
— by the last capture the door was fully CLOSED again but the window still read
`INTERMEDIATE`. This is the frameless-window reseat state, not "half open". Confirms
`INTERMEDIATE` is not a reliable "open" signal. `_parseWindowStatus`
(`source/api/CarDataClient.mc`) now treats only `"OPEN"` as open; `Tests.mc` updated to
expect `INTERMEDIATE -> false`.

### B12 — `fuelSystem.remainingFuel` doesn't track `fuelSystem.level` (stale/stuck descriptor)
First capture (2026-06-14T09:39): `level`=99%, `remainingFuel`=44 l, same timestamp —
a ~7 l gap vs the expected ~51 l for a 52 l tank at 99%. Four follow-up captures
(2026-06-14T15:52-15:54, after the car had clearly been driven) show `level` updated
to **83%** with fresh timestamps each time, while `remainingFuel` stayed frozen at
**44 l with the original 2026-06-13T17:05 timestamp** — i.e. `remainingFuel` simply
isn't refreshing on this vehicle, independent of any tank-size question. A 99%→83%
drop (16pp, ~8.3 l on a 52 l tank) produced zero change in `remainingFuel`.

**Plan:** treat `remainingFuel` as unreliable/rarely-updated on this vehicle — don't
mix it with `level` for the "litres to fill" hint. Compute `toFill` purely from
`level`: `toFill = tank - tank*level/100` (drop `fuelLitres` from that calculation
entirely, or only show it as a secondary/last-known value with its own timestamp).
`fuelPercent` (`level`) remains the primary, live-updating field — no change needed
there.

**Deferred (2026-06-14):** keep the current API value-based `remainingFuel` behaviour
for now — need more data to confirm whether `remainingFuel` is permanently frozen on
this vehicle or just refreshes on a much slower cadence (e.g. only after a fill-up or a
longer drive) before switching the "litres to fill" hint to a `level`-only computation.
Revisit once more captures span a refuel event.

_Effort: S · Risk: Low · **Deferred — gathering more data**._

---

## Features

### ✅ F17 — Expanded "About car" menu, split by data groups *(done 2026-06-14)*
The flat read-only About-car list (static `basicData` only) is now a grouped menu, and
the new v3 telematics descriptors are surfaced there.

**Fix:** `AboutMenu` (`source/ui/SettingsMenu.mc`) is now a top-level group list —
**Vehicle** (static `basicData`), **Battery & engine** (12V voltage, coolant), **Service**
(next service, warn threshold, CBS count), **Status** (total range, teleservice,
preconditioning, deep sleep), **Location** (lat/lon/altitude/heading) — each opening a
read-only key/value sub-menu. Container bumped to **v3** with 12 new telematics
descriptors parsed into `VehicleCache` (`batteryVoltage`, `coolantC`, `totalRangeKm`,
`cbsCount`, `serviceYellowKm`, `deepSleep`, `preconditioning`, `teleservice`, `lat`,
`lon`, `altitudeM`, `headingDeg`); `hvac.statusAirPurification` is subscribed for a
future feature but not yet parsed. Absent fields are omitted; empty groups show a
placeholder. Heading shows degrees + 8-point compass (e.g. `350° N`).

### ✅ F7 — Odometer page: next maintenance input *(done 2026-06-12, FR-23)*
**Fix:** `nextMaintenanceKm` property (IQ settings numeric field + on-watch cycling menu item); >0 overrides BMW's `serviceDistanceKm` on the odometer page, 0 = auto.

### ✅ F9 — Fuel consumption calculation *(done 2026-06-12, FR-22)*
**Fix:** instantaneous estimate `fuelLitres / rangeKm × 100`, shown as `~X.X L/100KM (EST)` on the Range & Fuel page.

### ✅ F10 — IQ settings: move Client ID out of the dropdown *(verified 2026-06-12, FR-24)*
**Outcome:** already a standalone `alphaNumeric` field in settings.xml — confirmation only.

### ✅ F11 — Background daily refresh at 10:00 in manual mode *(done 2026-06-12, FR-25)*
**Fix:** Manual mode registers a Moment-based temporal event for the next 10:00 local; the service delegate re-registers tomorrow's occurrence on each firing, and any successful manual refresh re-arms the chain.

### ✅ F12 — Glance icon update *(done 2026-06-12, FR-26)*
**Fix:** `launcher_icon.png` regenerated (40×40) from the revised BMW roundel source (`resources-src/bmw-icon-svg.webp`).

### ✅ F13 — Settings: enable/disable the estimated-consumption row *(done 2026-06-14)*
The `~X.X L/100KM (EST)` row added by F9 should be toggleable from IQ settings.

**Fix:** boolean IQ property `showConsumption` (default true) — toggleable from **both**
the phone IQ app settings (boolean entry in `settings.xml`) **and** the on-watch
"Est. Consumption · On/Off" item in `SettingsMenu` (now the 4th top-level item, clearly
visible after the auth actions moved into the Manage submenu). `PageRangeFuel` gates the
consumption `drawText` on `showConsumption()`.

### ✅ F14 — Settings: "Manage" submenu (Re-pair / Sign out / Delete container) *(done 2026-06-14)*
**Decision (revised 2026-06-14):** Re-pair, Sign out, and Delete container are grouped
under a **"Manage" submenu** (`ManageMenu`/`ManageMenuDelegate` in `ui/SettingsMenu.mc`),
not flat top-level items — this declutters the top-level Settings list.

**Fix:** `CarDataClient.deleteContainer(id)` (`DELETE /customers/containers/{id}`) +
`ContainerDeleter` foreground runner (`ensureValidToken` → delete → drop local
container id/name so the next poll re-bootstraps; cached Vehicle State kept). The
`:deleteContainer` `MenuItem` lives in the Manage submenu with async
"Deleting…/Deleted/Failed" status. Top-level Settings is now: Update Mode · Tank Size ·
Next Service · Est. Consumption · Manage · About car.

### ❌ F15 — Settings: "Save dev logs" action *(won't do 2026-06-14)*
Capture recent API responses to a file on the watch for diagnostics.

**Outcome — not possible / dropped.** Connect IQ has **no arbitrary file-write API** for
3rd-party apps, and there is no off-watch export path that would make a dev-log file
useful (Settings sync is one-way phone→watch; the only on-watch sink is
`Application.Storage`, which can't be pulled off the device by a user). An on-watch-only
ring buffer adds memory pressure (32 KB background budget) and PII-handling burden (VIN/
location) for no real diagnostic payoff. Decision: **drop F15.** If diagnostics are ever
needed, use the simulator + a live capture (`scripts/cardata/capture.py`) instead.

### ✅ F16 — Total range support for all powertrain types *(done 2026-06-14)*
**Fix:** added EV/PHEV descriptors to container v3 (`totalRemainingRange`,
`electricEngine.kombiRemainingElectricRange`, `powertrain.electric.battery.stateOfCharge.displayed`).
Parser runtime-selects `rangeKm` = total → electric → last (ICE: total == last). New cache
keys `electricRangeKm`, `socPercent`. `PageRangeFuel` shows `BATTERY %` instead of `FUEL %`
when fuel is absent but SoC present, and `isVisible()` accepts SoC-only (BEV); SoC +
electric range also surfaced in the About-car groups. Covered by `testParse_rangeSelection`.

---

## Chores

### C1 — Git history cleanup, docs, publish on GitHub
Clean up git history, write up documentation, and publish the project on GitHub.

**Plan:** audit history for secrets (real `clientId` lives only in gitignored
`resources-livetest/` — confirm none leaked); write README (setup, build-personal.sh,
CarData pairing); squash/curate noisy commits; add LICENSE; publish public repo.
⚠️ Scrub any captured `telematicData` (VIN/location) before publishing.

_Effort: M · Risk: Med._

### ✅ C2 — Memory consumption review / performance optimization *(done 2026-06-14)*
Review overall memory usage and look for performance optimization opportunities. Binding
limit = the **~32 KB background budget** (fetch+parse+cache), not CPU.

**Findings & fixes (`CarDataClient._parseTelematicData` hot path):**

1. **Timestamp memo — biggest win.** `_parseIso8601` was called **once per present
   descriptor (~33×/parse)**, each call allocating 6 substrings + a Gregorian dict + a
   Moment — all transient garbage. A single response groups most fields under **one**
   snapshot timestamp, so a 1-entry `(string→epoch)` memo on `_updateMaxTs` collapses
   those ~33 parses to **≈3–4** (the distinct timestamps). ~88 % fewer allocations in the
   heaviest function, lowering peak background allocation pressure.
2. **De-duplicated parse blocks.** Six near-identical inline blocks (range, fuel %, fuel
   litres, odometer, service distance, display unit) folded into the existing
   `_parseNumVal`/`_parseStrVal` helpers → ~24 fewer source lines, less duplicated
   bytecode (code memory).
3. **Tighter helpers (best-C shape).** Every `_parse*` helper now does **one** `td`
   lookup, **one** value read into a local (was reading `e["value"]` twice — guard +
   use), and **early-returns** on absent/null; `_parseBoolVal` bumps the timestamp once
   instead of in three branches.

**Verified clean already:** raw JSON nulled right after parse (`onTelematicDataResponse`
→ `data = null`), no member retains the full response, `VehicleCache` merge is in-place
(no third copy). Tests green incl. `testParse_lastUpdatedIsMax` (memo correctness across
mixed timestamps).

**Considered, deferred:** splitting the ~14 About-only fields (`lat`/`lon`/`teleservice`/…)
into a separate Storage key so the glance/pages deserialize a leaner Vehicle State. Real
saving on the foreground glance read, but it adds a Storage key + dual-merge complexity
(against the "fewest moving parts" goal) for a surface that renders infrequently —
revisit only if glance memory becomes tight.

_Effort: M · Risk: Low._

---

## QA

### Q1 — Test door status reads
Verify door open/closed status is read and displayed correctly across scenarios.

**Plan:** capture `telematicData` across states (all closed / one door open / hood / trunk
/ rear doors) and confirm `_parseOpenState` → PageLock dots match. Pairs naturally with the
B10/B11 live captures.

_Effort: S · Risk: Low._

### Q2 — Edge-case review
Review corner/edge cases: re-auth flow, car removal, wrong/changed VIN, missing or
malformed data, and API response format changes.

**Plan:** map each failure to a handled path — `CU-105` (container gone/wrong VIN) should
trigger the `cachedContainerId()` re-bootstrap; expired token → refresh; missing fields →
hide-if-null (already); response-shape drift → defensive `hasKey`/type guards in `_parse*`.
Verify re-bootstrap fires on a *live* `CU-105`, not just a missing local id.

_Effort: M · Risk: Med._
