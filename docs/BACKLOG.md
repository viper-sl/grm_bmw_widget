# BMW Widget Backlog

Items B3–B6, B8, F7, F9–F12 were implemented 2026-06-12 via PRD FR-15–26
(`_bmad-output/planning-artifacts/prds/prd-grm_bmw_widget-2026-06-10/`).

## Bugs

### B1 — Glance: no status label when car is open
When the car is in open/unlocked state, the glance view shows no status label at all.
Expected: show an appropriate label (e.g. "Open") or handle the open state explicitly.

### B2 — Glance: fuel label shows litres only after threshold
Currently fuel is displayed as `FUEL 31l`. After the threshold it should show both percentage and litres: `XX% (31l)` instead of only litres.

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

### ✅ B6 — Lock status page: no red W indicator for open windows *(done 2026-06-12, FR-18)*
**Fix:** four window descriptors added (container v2); red **W** badge renders next to the status label when any window is OPEN/INTERMEDIATE.

### ✅ B8 — Tyre wear status missing (regression) *(verified 2026-06-12, FR-21)*
**Outcome:** verify-then-fix — parsing and PageTyres rendering confirmed correct; no code gap. Container v2 migration re-establishes the descriptor set.

---

## Features

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
