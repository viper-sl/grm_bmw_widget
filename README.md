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
- **Tyres** — per-wheel pressure vs. target, and tyre-wear estimate.
- **About car** — a grouped, read-only dump of static vehicle info plus live telematics
  (12 V battery, coolant, location, teleservice, …).
- **On-watch settings** — update mode, tank size, service override, consumption toggle,
  and a **Manage** submenu (re-pair / sign out / delete all containers).

## Supported devices

fēnix 6 / 7 / 8 / E families, MARQ, and Forerunner 255 / 745 / 945 / 955 / 965 / 970
(see [`manifest.xml`](manifest.xml)). Developed and tested against **fēnix 6 Pro**.

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
- The **foreground app** (~1 MB) does the **full** fetch — all pages plus the "About car"
  detail — on a manual refresh (START) or once a day on open, from the **full container**.
  `VehicleCache.write` merges, so background live updates and the last full fetch coexist.
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

You need a **BMW CarData client ID** (free, from the BMW CarData portal). Everything
else is automatic:

| Value | Source |
|---|---|
| **clientId** | you provide it (portal) — in app settings, or baked into a personal build |
| refresh / access token | on-watch device-flow pairing |
| VIN | auto-discovered via `/customers/vehicles/mappings` |
| container IDs | two auto-created via `POST /customers/containers`: a **full** one (foreground) + a **lean** one (background poll) |

First run: open the widget → **START to connect** → approve the shown code at
`customer.bmwgroup.com` → the widget discovers your VIN, creates its data containers, and
fetches your car. No VIN/container typing. (BMW caps an account at **10 containers**; if
that's hit, onboarding offers to delete all and retry — see **Manage → Delete containers**.)

## Build

Prereqs: the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and a
developer key (`developer_key`).

**Store / generic build** (credentials entered in the Garmin Connect Mobile app):

```sh
monkeyc -f monkey.jungle -d fenix6pro -o bin/BmwStatus.prg -y developer_key
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
resources-src/     icon source art
docs/              build/test docs + BMW CarData descriptor reference
docs/findings/     verified API behaviour, descriptor semantics, CIQ gotchas
manifest.xml       app id, supported devices, permissions (Communications + Background)
```

## Privacy

The widget reads your vehicle's data only to display it on your watch; nothing is sent
anywhere except BMW's own API. Captured telematics and any personal config
(VIN, tokens, client ID, simulator settings) are **gitignored** and never committed.

## License

See [`LICENSE`](LICENSE).
