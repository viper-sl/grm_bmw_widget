# Descriptor semantics — what the data actually does

Empirical behaviour of the BMW CarData telematics descriptors, learned from a 7-run live
capture campaign (parked / engine-on / moving) on an **ICE BMW 218i**. The catalogue
gives the *spec*; only live captures reveal what a given vehicle/account actually emits.

**Rule that kept proving true: observed semantics beat catalogue spec.** The catalogue
resolves which fields *exist* and their nominal enum; the live values decide what's real.

See [bmw-cardata-api.md](bmw-cardata-api.md) for the API itself, the curated subscription
set in [../descriptors.md](../descriptors.md), and the full catalogue in
[../reference/cardata-catalogue.md](../reference/cardata-catalogue.md).

## Fields that NEVER populate on this vehicle/account

These returned `null` in every capture — **even with the engine running and while the car
was moving** — so they are not a timing/freshness artifact; BMW simply doesn't emit them
for this contract tier:

- `vehicle.drivetrain.engine.isIgnitionOn`
- `vehicle.drivetrain.engine.isActive`
- `vehicle.isMoving`, `vehicle.vehicle.avgSpeed`, `vehicle.vehicle.speedRange.*`

**Consequence:** any "engine running / driving" UI is unreachable on this vehicle. The
widget dropped these descriptors and removed the dead RUNNING state rather than ship an
unreachable branch. If another vehicle/account *does* populate ignition, re-add the
descriptor + parse + branch.

Also always `null` here (kept in the container for other body styles): rear doors/windows
(`row2.*`), `vehicle.body.trunk.isLocked`.

## Enum / value quirks that drove parser rules

| Descriptor | Finding | Parser rule |
|---|---|---|
| `vehicle.cabin.door.lock.status` | Observed `LOCKED` / `UNLOCKED` / `SECURED`. Full spec adds `SELECTIVE-LOCKED` / `INVALID` / `UNKNOWN`. | `SECURED`,`LOCKED` → locked; `UNLOCKED`,`SELECTIVE-LOCKED` → unlocked; `INVALID`/`UNKNOWN`/null → **omit** (hide). |
| `vehicle.cabin.window.row1.*.status` | `INTERMEDIATE` **persists with the door fully closed** — it's the frameless-window reseat state, *not* "half open" (contradicts the catalogue gloss). | Only `"OPEN"` counts as open. `INTERMEDIATE`/`CLOSED`/`INVALID` → closed. |
| `vehicle.drivetrain.fuelSystem.remainingFuel` | **Frozen** — stayed at the same litres with a stale timestamp while `…level` (%) tracked live across a 99→82 % drop. | Treat as unreliable; derive "litres to fill" from `…fuelSystem.level` (%), not from `remainingFuel`. |
| `vehicle.drivetrain.lastRemainingRange` vs `…totalRemainingRange` | On ICE both are equal. PHEV total includes electric; BEV uses `…electricEngine.kombiRemainingElectricRange`. | Runtime-select the range to display: total → electric → last (powertrain unknown at compile time). |
| `*.tire.pressure` / `*.tire.pressureTarget` | kPa integers (e.g. `230` = 2.3 bar). Targets uniform 220 kPa on this car; readings often +10 kPa (tyres warm from driving). | kPa→bar = `/100`. Warn only when actual < target − 20 kPa (< ~2.0 bar); a small over-pressure is normal, don't warn. |
| `vehicle.status.serviceDistance.next` | Value present, **`unit: null`** | Infer km (consistent with every distance field in the API). |
| `vehicle.cabin.door.lock.status` vs `…door.*.isOpen` | These are **distinct**: lock state ≠ a physically open door. | Don't conflate "unlocked" with "door open" in the UI. |

## "Hide if unavailable" is load-bearing

Because so many descriptors are sometimes/always null, every field is rendered only when
present (`state.hasKey(...)`), never as `null`/`--` unless the *whole* surface would
otherwise go blank (see B1 — the glance draws a muted `—` when lock state is absent so the
row never disappears).

## Data freshness

CarData updates on the car's own (slow) cadence — captured fields were often **hours to
days** old on a parked car. Polling faster than that cadence gains nothing; a prominent
**data-age** indicator (and stale-but-shown UX) is essential.
