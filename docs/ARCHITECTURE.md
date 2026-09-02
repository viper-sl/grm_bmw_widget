# BMW Widget — Architecture & Logic

A Garmin Connect IQ **widget** (Monkey C) that shows BMW CarData vehicle status — range,
fuel, lock/doors/windows, tyres, odometer, plus an "About car" detail menu — on the watch
face glance and a small page carousel.

> **The one design driver:** the watch runs the app in **two separate processes with very
> different memory budgets**. Everything below — the two-container model, the foreground/
> background class split, the cache projection — exists to live within the **~28 KB
> background heap**.

| Process | Heap | What runs there |
|---|---|---|
| **Foreground app** | ~1 MB on fēnix 6 Pro · **64 KB on base fēnix 6** | UI, pairing, the full data sync, cache writes |
| **Glance** | ~28 KB (own partition) | the glance view only — reads a lean projection |
| **Background service** | **~28 KB** | the periodic poll: token → fetch → parse → exit |

A response that parses fine in the 1 MB foreground returns
**`-403 NETWORK_RESPONSE_OUT_OF_MEMORY`** in the background — the original "background never
updates" bug. The fix: the background polls a **lean container** whose response fits.

---

## 1. Process & component map

`(:background)`-tagged classes load into the background process; everything else is
foreground-only. The background loads **whole classes**, so heavy foreground-only code
(VIN discovery, container create/delete, the 41-descriptor array) lives in a separate
class to keep it out of the background image.

```mermaid
graph TB
    APP["BmwWidgetApp (:background)<br/>AppBase entry points"]

    subgraph FG["FOREGROUND process (~1 MB)"]
        direction TB
        VIEW["BmwWidgetView + Delegate<br/>setup / loading / carousel host"]
        PAGES["Pages: RangeFuel · Lock · Odometer · Tyres · Map<br/>PageNav · PageDelegate · MapPageDelegate · PageChrome"]
        MENUS["SettingsMenu · AboutMenu · AuthView"]
        FSYNC["ForegroundSync<br/>full cold-start + refresh chain"]
        BOOT["CarDataBootstrap<br/>VIN · containers · basicData · tyre · delete"]
        AUTH["DeviceAuthManager<br/>OAuth device flow + PKCE"]
        CDEL["ContainerDeleter"]
    end

    subgraph BG["BACKGROUND service (~28 KB)"]
        direction TB
        SVC["BmwWidgetServiceDelegate<br/>onTemporalEvent then poll"]
        CDC["CarDataClient (:background)<br/>lean telematic fetch + parse"]
        TOK["TokenManager (:background)<br/>OAuth refresh FSM"]
        QG["QuotaGuard (:background)<br/>rate gate + 24h block"]
    end

    GLANCE["BmwWidgetGlanceView (:glance)<br/>reads KEY_GLANCE_STATE directly<br/>(~28 KB partition)"]

    subgraph STORE["Application.Storage (~128 KB)"]
        VC["VehicleCache (:background)<br/>write/merge + glance projection"]
        KEYS["StorageKeys (:background)<br/>tokens · vin · container ids · state"]
    end

    APP -->|"getInitialView"| VIEW
    APP -->|"getGlanceView"| GLANCE
    APP -->|"getServiceDelegate"| SVC
    APP -->|"onBackgroundData"| VC

    VIEW --> PAGES --> FSYNC
    MENUS --> AUTH
    MENUS --> CDEL
    AUTH --> FSYNC
    FSYNC --> BOOT
    FSYNC --> CDC
    FSYNC --> TOK
    CDEL --> BOOT
    BOOT -.->|"shares statics"| CDC

    SVC --> CDC
    SVC --> TOK
    SVC --> QG
    CDC --> VC
    FSYNC --> VC
    GLANCE -.->|"reads"| STORE
    VC --> KEYS

    classDef bg fill:#13315c,stroke:#4a90d9,color:#fff;
    classDef fg fill:#1b4332,stroke:#52b788,color:#fff;
    classDef gl fill:#5a189a,stroke:#c77dff,color:#fff;
    class SVC,CDC,TOK,QG,VC,KEYS,APP bg;
    class VIEW,PAGES,MENUS,FSYNC,BOOT,AUTH,CDEL fg;
    class GLANCE gl;
```

**Why CarDataClient was split from CarDataBootstrap:** the background poll only needs the
telematic fetch + parser. VIN discovery, container create/list/delete, basicData, tyre, and
the 41-string descriptor array are foreground-only. Putting them in `CarDataBootstrap`
(not `(:background)`) keeps that bytecode out of the 28 KB background image. Shared statics
(`_DATA_HOST`, `_buildHeaders`, `_CONTAINER_NAME`, `_storeContainer`, `cachedContainerId`)
stay on `CarDataClient`.

---

## 2. The two-container model

A **container** is a server-side subscription to a set of descriptors; `telematicData`
returns exactly that container's fields in one GET. The app keeps **two**:

```mermaid
graph LR
    subgraph BMW["BMW account (max 10 containers)"]
        FULL["grm_bmw_widget_v3<br/>41 descriptors<br/>all pages + About-car detail"]
        LEAN["grm_bmw_widget_bg_v3<br/>14 LIVE descriptors<br/>lock · doors · windows · range · fuel"]
    end

    FG2["FOREGROUND<br/>manual START / once-a-day"] -->|"GET full"| FULL
    BGP["BACKGROUND poll<br/>every cycle"] -->|"GET lean"| LEAN

    FULL --> CACHE["VehicleCache (merge)"]
    LEAN --> CACHE
    CACHE --> GLANCEv["Glance"]
    CACHE --> PAGESv["Pages"]
```

- The **lean (bg) container** holds only **live / event-driven** fields, small enough that
  its ~5 KB response fits the background heap. Its name is **version-stamped** (`_bg_v3`);
  bumping it forces re-creation with a new descriptor set.
- The **full container** carries everything (incl. the 12 "About car" telematics).
- `VehicleCache.write` **merges**, so the slow/static fields (tyres, odometer, service,
  About-car) from the last full fetch persist while the background keeps the live fields
  fresh.

| Field group | In bg (lean) container? | Refreshed by |
|---|---|---|
| Lock, doors, trunk, hood | ✅ | background poll |
| Windows | ✅ | background poll |
| Range (`totalRemainingRange` → `rangeKm`), fuel %, fuel L | ✅ | background poll |
| Tyres (pressure/target), odometer, service distance, displayUnit | ❌ | full fetch (manual / daily) |
| About-car detail (battery V, coolant, location, SOC, CBS, teleservice…) | ❌ | full fetch (manual / daily) |

> ⚠️ **Known gap (deferred D1):** the lean container has `totalRemainingRange` but not
> `lastRemainingRange` / `kombiRemainingElectricRange`. On an **ICE** car `total == last`,
> so it's fine; a **BEV/PHEV** whose only live source is the electric range won't get
> `rangeKm` from the background poll.

---

## 3. Entry points & poll cadence

`BmwWidgetApp` (the only class needed in both processes) wires the four CIQ entry points and
registers the background temporal event based on `updateMode`.

```mermaid
flowchart TD
    START["onStart then _applyUpdateMode()"] --> MODE{"updateMode?"}
    MODE -->|"0 manual / default"| M0["register next 10:00 Moment<br/>one-shot, re-armed each fire"]
    MODE -->|"1 hourly"| M1["register Duration 3600s"]
    MODE -->|"2 adaptive"| M2["register Duration 1800s<br/>(gated in the service delegate)"]

    M0 --> FIRE["OS fires onTemporalEvent"]
    M1 --> FIRE
    M2 --> FIRE
    FIRE --> SVC["BmwWidgetServiceDelegate"]
```

- **0 manual (default):** one daily ~10:00 fetch (keeps the OAuth token pair alive); the
  Moment is one-shot, so `onTemporalEvent` re-registers tomorrow's 10:00.
- **1 hourly:** fires every 3600 s.
- **2 adaptive:** fires every 1800 s but `_adaptiveShouldFetch()` only lets it fetch at
  chosen hours (00, 06–08, every 30 min 09–22, 23 top-up).
- Regardless of mode, **`QuotaGuard` enforces a 40-min minimum** between actual fetches.

---

## 4. Background poll (the fixed path)

```mermaid
flowchart TD
    EV["onTemporalEvent"] --> REREG{"mode 0?"}
    REREG -->|"yes"| RR["re-register tomorrow 10:00"]
    REREG -->|"no"| ADAPT{"mode 2 and not<br/>an adaptive hour?"}
    RR --> ADAPT
    ADAPT -->|"skip"| X0["Background.exit(null)"]
    ADAPT -->|"ok"| SETUP{"VIN and bg<br/>container cached?"}
    SETUP -->|"no"| X1["exit — open the app to bootstrap"]
    SETUP -->|"yes"| POLL["_runPollCycle"]

    POLL --> BO{"backoff gate active?"}
    BO -->|"yes"| X2["exit"]
    BO -->|"no"| TOK["TokenManager.ensureValidToken"]
    TOK --> OK{"token ok?"}
    OK -->|"no"| X3["exit"]
    OK -->|"yes"| Q{"QuotaGuard.canFetch?<br/>(>= 40 min since last)"}
    Q -->|"no"| X4["exit"]
    Q -->|"yes"| FETCH["CarDataClient.fetchTelematicData<br/>(LEAN bg container)"]
    FETCH --> RESP{"responseCode"}
    RESP -->|"200"| W["stamp lastUpdated=now<br/>QuotaGuard.updateAfterFetch<br/>Background.exit(state)"]
    RESP -->|"429 or 403+CU-429"| RL["QuotaGuard.onQuotaExceeded<br/>(block until 4 AM) then exit"]
    RESP -->|"other / -403"| ERR["updateAfterFetch + backoff<br/>then exit"]

    W --> OBD["onBackgroundData(state)<br/>then VehicleCache.write then requestUpdate"]
```

`Background.exit(state)` ends the service and hands `state` to the **foreground**
`onBackgroundData`, which merges it into the cache and refreshes the glance projection.

---

## 5. Foreground sync — full vs. live, manual vs. daily

`ForegroundSync.run(onDone, isManual)` is the cold-start + refresh chain. It always ensures
**both** containers exist, but only does the heavy **full** fetch when warranted:

```mermaid
flowchart TD
    RUN["run(onDone, isManual)"] --> FULLQ["_fullFetch = isManual OR dailyDue<br/>(dailyDue = lastFull null or older than 24h)"]
    FULLQ --> CD{"_fullFetch and within<br/>60s cooldown?"}
    CD -->|"yes"| F0["_finish(false)"]
    CD -->|"no"| TOK["ensureValidToken"]
    TOK --> VIN["resolve VIN (else GET /mappings)"]
    VIN --> FC["resolve/create FULL container"]
    FC --> BC["resolve/create LEAN bg container"]
    BC --> GATE{"_fullFetch?"}
    GATE -->|"no"| DONE1["_finish(true)<br/>containers ensured; bg keeps live fields fresh"]
    GATE -->|"yes"| BD["fetchBasicData"]
    BD --> TY["fetchTyreDiagnosis (best-effort)"]
    TY --> TEL["fetchTelematicData (FULL container)"]
    TEL --> TR{"200?"}
    TR -->|"yes"| WRITE["merge tyre wear<br/>stamp lastUpdated=now<br/>VehicleCache.write<br/>KEY_LAST_FG + KEY_LAST_FULL = now<br/>re-arm updateMode then _finish(true)"]
    TR -->|"no"| F1["_finish(false)"]
```

| Trigger | `isManual` | Result |
|---|---|---|
| Pairing complete (AuthView) | `true` | full fetch (first data) |
| START on Range/Lock page | `true` | full fetch (subject to 60 s cooldown) |
| App open (auto, BmwWidgetView) | `false` | full only if >24 h since last; else ensure-containers + rely on bg |

**Rate-limit short-circuit (`_stop429`)** is checked at every chain step: a `429`
(incl. normalized `403+CU-429`) sets `_rateLimited`, calls `QuotaGuard.onQuotaExceeded()`,
stamps the 60 s cooldown, and `_finish(false)`. The owning view reads `isRateLimited()` to
show "Daily limit reached" instead of bouncing to auth. **`_stop401`** sits beside it:
a `401` invalidates the cached access-token expiry and re-runs the chain once with a
freshly refreshed token (`_retried401` caps it at one retry).

---

## 6. Token lifecycle (TokenManager FSM)

Token **refresh** hits `customer.bmwgroup.com` and is **quota-exempt** (separate host from
the data API). The FSM state lives in `KEY_TOKEN_STATE`.

```mermaid
stateDiagram-v2
    [*] --> first_run: tokenState == null
    first_run --> NORMAL: refresh 200 (rotate)
    first_run --> UNCONFIGURED: no client id / refresh token

    NORMAL --> NORMAL: access token valid (outside skew)
    NORMAL --> NEEDS_REFRESH: expired or inside skew window
    NEEDS_REFRESH --> NORMAL: refresh 200 (rotate)
    NEEDS_REFRESH --> NEEDS_REFRESH: transient 5xx / -104 (backoff)
    NEEDS_REFRESH --> NEEDS_REFRESH: 400 invalid_grant, strike < 5 (backoff)
    NEEDS_REFRESH --> NEEDS_REBOOTSTRAP: 400 invalid_grant, strike 5

    UNCONFIGURED --> [*]: callback(false)
    NEEDS_REBOOTSTRAP --> NORMAL: silent retry succeeds (AuthView)
    NEEDS_REBOOTSTRAP --> pairing: silent retry fails
    pairing --> NORMAL: device-flow success
```

Pairing (`DeviceAuthManager`, foreground only) is OAuth 2.0 **Device Authorization Grant +
PKCE**: POST `/device/code` → show user code → poll `/token` until approved → store tokens
→ `NORMAL`. On success the AuthView runs a manual `ForegroundSync`. Token rotation always
writes the **refresh token before the access token** (so an interrupted rotation is
recoverable), and a `200` that omits `refresh_token` leaves the stored one untouched.

### Why the FSM is defensive about `invalid_grant`

BMW rotates the refresh token on **every** refresh, which makes a poor connection
dangerous: if the POST reaches BMW but the response is lost on the phone bridge, BMW has
burned the old token and the watch never received the new one. The next attempt then gets
a perfectly genuine `400 invalid_grant` — indistinguishable from a truly dead grant. Two
overlapping refreshes produce the same thing: the loser presents an already-rotated token.

`NEEDS_REBOOTSTRAP` is a **one-way door** — `ensureValidToken()` short-circuits on it
before any network call — so latching it on a single `invalid_grant` turns a BLE dropout
into a permanent "Re-auth needed". Three guards keep that from happening:

| Guard | Key | Effect |
|---|---|---|
| **Corroboration** (`GRANT_STRIKES_TO_LATCH = 5`) | `KEY_GRANT_STRIKES` | strikes 1–4 behave like any transient failure (backoff, state untouched); only the 5th latches. Any successful refresh clears the count. A high threshold only delays the prompt — cached data stays on screen under a "No connection" note, and Settings → *Re-pair* is always available. Spread over the doubling backoff (40 m, 80 m, 160 m, 4 h, 4 h) an unattended watch latches in ~12 h; tapping START burns the strikes immediately. |
| **Serialization** (`INFLIGHT_TTL_SECONDS = 90`) | `KEY_REFRESH_INFLIGHT` | one refresh at a time across views *and* processes (they share Storage). A caller arriving mid-refresh fails transiently. The TTL self-heals a stamp left by a killed process. |
| **Silent retry** | — | opening the re-link prompt spends one quota-exempt refresh via `TokenManager.retryAfterRebootstrap()` before showing the device flow; success clears the latch outright. Settings → *Re-pair* opts out (`AuthView.setAllowRecover(false)`) because the user asked for pairing by name. |

`EXPIRY_SKEW_SECONDS = 300` refreshes early: a token still valid when the request leaves
the watch can expire in flight, and the data path reads the resulting `401` as a transient
error. A `401` on a data call therefore also calls `TokenManager.invalidateAccessToken()`
(drops `KEY_ACCESS_EXPIRY`) — the foreground re-runs the chain once with a fresh token,
the background poll picks it up on the next tick.

### Failure classification (why a dropout no longer asks for a re-auth)

`ForegroundSync` exposes three failure kinds, and the views branch on all three —
`isRateLimited()`, `authFailed()`, otherwise transient. **Only `authFailed()`
(`UNCONFIGURED` / `NEEDS_REBOOTSTRAP`) may open the device flow.** A `-104`, a timeout, a
`5xx` or a failed container list keeps the cached data on screen under a "No connection"
note. `run()` also pre-flights `System.getDeviceSettings().phoneConnected`, so an
unreachable phone never enters the chain at all.

---

## 7. Data flow: fetch → parse → cache → render

```mermaid
flowchart LR
    RESP["telematicData JSON<br/>{descriptor: {value, timestamp, unit}}"]
    RESP --> PARSE["CarDataClient._parseTelematicData<br/>strings to typed · kPa to bar<br/>null omit · range selection<br/>lastUpdated = max field ts"]
    PARSE --> STATE["Vehicle State dict<br/>(~40 optional keys)"]
    STATE --> STAMP["lastUpdated = now<br/>(fetch time, temporary)"]
    STAMP --> WRITE["VehicleCache.write(state)"]
    WRITE --> MERGE["merge into KEY_VEHICLE_STATE<br/>omitted fields kept; lastUpdated = max"]
    MERGE --> PROJ["_writeGlanceSummary then<br/>KEY_GLANCE_STATE = doorsLocked,<br/>rangeKm, fuelPercent, lastUpdated"]
    MERGE --> PAGESr["Pages read VehicleCache.read()<br/>(full state, 1 MB heap)"]
    PROJ --> GLANCEr["Glance reads KEY_GLANCE_STATE<br/>directly (NOT via VehicleCache)"]
```

**Why the glance reads `KEY_GLANCE_STATE` directly:** referencing `VehicleCache` from the
`(:glance)` view would pull its write/merge bytecode into the glance image, and
deserializing the full ~40-key state in the ~28 KB glance partition OOMs (the 2026-06-15
crash). The lean 4-field projection is written by **every** cache writer. `fuelLitres` is
deliberately *not* projected — the glance derives its "+NNL to fill" from `fuelPercent` via
`FuelMath`, because BMW leaves `remainingFuel` frozen at the last refuel (B12).

> **"last upd" = fetch time (temporary):** both fetch paths overwrite `lastUpdated` with the
> wall clock at fetch completion, so the age resets to ~now on every successful poll rather
> than tracking the vehicle's report time. Marked temporary "till we stabilize"; the
> parser's max-timestamp machinery is dormant, not removed.

---

## 8. Rate limit, quota & backoff

Three independent gates, all keyed in Storage:

```mermaid
flowchart TD
    subgraph detect["Detection: CarDataClient.isRateLimit(rc, data)"]
        D1["rc == 429"] --> HIT["treat as 429"]
        D2["rc == 403 AND body<br/>exveErrorId == CU-429"] --> HIT
    end

    HIT --> QE["QuotaGuard.onQuotaExceeded()<br/>KEY_NEXT_ALLOWED = 4 AM next day"]

    subgraph gates["Gates (independent Storage keys)"]
        G1["QuotaGuard.canFetch()<br/>KEY_NEXT_ALLOWED: +40 min per fetch,<br/>set to 4 AM on CU-429"]
        G2["Error backoff<br/>KEY_BACKOFF_UNTIL: doubles to 4 h cap<br/>on transient / -403 errors,<br/>cleared on any success"]
        G3["FG cooldown<br/>KEY_LAST_FG: 60 s between full refreshes"]
    end
```

- **CU-429 is the key insight:** BMW returns its **daily limit as HTTP `403` with body
  `exveErrorId == "CU-429"`**, *not* HTTP 429. `isRateLimit` normalizes both → callers arm
  the 24 h block and show a clear message (no false "auth needed").
- `KEY_NEXT_ALLOWED` (quota gate) and `KEY_BACKOFF_UNTIL` (error backoff) are **separate**:
  the gate advances on every call; backoff is set on errors and cleared on success. "Cleared
  on success" is `QuotaGuard.clearBackoff()`, called from the token refresh, the background
  poll and the foreground sync — without it the backoff only ever doubles, and one bad patch
  of connectivity keeps the poll blocked for up to 4 h after the link is back.

---

## 9. UI / navigation

```mermaid
flowchart TD
    G["Glance: lock · range · fuel bar · age<br/>(Press to set up if no data)"] -->|"START"| V["BmwWidgetView (initial)"]
    V -->|"NORMAL + data"| CAR["Page carousel"]
    V -->|"NEEDS_REBOOTSTRAP"| RELINK["Re-auth prompt then AuthView<br/>(silent token retry first)"]
    V -->|"sync failed on the link"| OFF["No connection - START retries"]
    V -->|"no data"| SETUP["Press START to connect then AuthView"]

    CAR -->|"up/down"| CAR
    CAR -->|"START on Range/Lock"| REFRESH["manual full ForegroundSync"]
    CAR -->|"START on Map"| ZOOM["Map browse mode<br/>MapPageDelegate: up/down zoom, BACK collapses"]
    CAR -->|"MENU"| SET["SettingsMenu"]
    SET --> MANAGE["Manage: re-auth · delete containers · sign out"]
    SET --> ABOUT["About car (basicData + detail telematics)"]

    AUTHV["AuthView (device flow)"] -->|"SUCCESS"| SYNC["full ForegroundSync"]
    AUTHV -->|"rate limited"| RLMSG["Daily API limit reached (BACK to exit)"]
    SYNC -->|"done"| CAR
```

Pages: **RangeFuel** (range + fuel/SOC bar + consumption est.), **Lock** (lock state + all
doors/windows/trunk/hood), **Odometer** (odometer + service distance), **Tyres** (per-tyre
pressure/target + wear km, START cycles the three views), and **Map** (FR-27..FR-40 — the
car's last known position on the device's onboard cartography; the only page extending
`WatchUi.MapView`, and the only one with its own delegate, `MapPageDelegate`, so BACK
collapses browse mode instead of exiting and up/down zoom instead of paging). A page is
visible only when its key fields are present (`isVisible()`), so the carousel grows as
data arrives — the map needs both `lat` and `lon`.

The map occupies a **build-variant fifth slot**: `PageNav._pageCount()` is a `(:mapPage)` /
`(:noMapPage)` function pair, so the carousel is 5 pages on map-capable devices and 4
elsewhere (see §12).

---

## 10. Storage keys

| Key | Written by | Read by |
|---|---|---|
| `KEY_TOKEN_STATE` | TokenManager, DeviceAuthManager, sign-out | TokenManager, views |
| `KEY_ACCESS_TOKEN` / `KEY_ACCESS_EXPIRY` / `KEY_REFRESH_TOKEN` | TokenManager (refresh **before** access) | TokenManager |
| `KEY_VIN` | CarDataBootstrap (mappings) | both sync paths |
| `KEY_CONTAINER_ID` / `_NAME` | `_storeContainer` | `cachedContainerId` (FULL) |
| `KEY_BG_CONTAINER_ID` / `_NAME` | `_storeBgContainer` | `cachedBgContainerId` (LEAN) |
| `KEY_VEHICLE_STATE` | VehicleCache.write (merge) | pages |
| `KEY_GLANCE_STATE` | `_writeGlanceSummary` (every write) | glance (direct) |
| `KEY_VEHICLE_NAME` / `KEY_BASIC_DATA` / `KEY_DRIVE_TYPE` | basicData | About menu, header |
| `KEY_NEXT_ALLOWED` | QuotaGuard | QuotaGuard.canFetch |
| `KEY_BACKOFF_UNTIL` | TokenManager / ServiceDelegate (set on error, cleared on every success) | poll backoff gate |
| `KEY_REFRESH_INFLIGHT` | TokenManager (stamp on dispatch, cleared on response) | refresh serialization, 90 s TTL |
| `KEY_GRANT_STRIKES` | TokenManager (on `invalid_grant`; cleared on success / sign-out) | `NEEDS_REBOOTSTRAP` corroboration |
| `lastForegroundSync` (`KEY_LAST_FG`) | full success, rate-limit | 60 s cooldown |
| `lastFullFetch` (`KEY_LAST_FULL`) | full success | daily full-fetch gate |

---

## 11. Container resolution & versioning

`cachedContainerId()` / `cachedBgContainerId()` return the stored id **only if** the stored
name matches the current `_CONTAINER_NAME` / `_BG_CONTAINER_NAME`; otherwise they delete the
stale id and return null, forcing re-creation. Bumping a name (e.g. `_bg_v2` → `_bg_v3`) is
how a descriptor-set change is rolled out.

```mermaid
flowchart TD
    R["resolve container"] --> C{"cached id?"}
    C -->|"no"| FETCHC["GET /containers"]
    C -->|"yes, name matches"| USE["use it"]
    C -->|"yes, name mismatch"| INVAL["delete stale id then null"]
    INVAL --> FETCHC
    FETCHC --> M{"name match on server?"}
    M -->|"yes"| STORE["store + use"]
    M -->|"no"| CREATE["POST /containers (create)"]
    CREATE --> STORE
```

> **Orphan cleanup:** each version bump orphans the old container server-side (two per
> version now), creeping toward BMW's per-account cap over many versions/re-pairs.
> **Manage → "Delete containers"** lists and deletes **every** container on the account
> (incl. old-version orphans), then clears the local ids so the next sync re-creates the
> current pair — so the cap can be reclaimed on demand. Automatic pruning at bootstrap is
> still not done.

---

## 12. Build tiers (the annotation split)

One source tree, several device capabilities. Each jungle
([`monkey.jungle`](../monkey.jungle), [`iq.jungle`](../iq.jungle),
and the gitignored personal `livetest.jungle`) resolves them with `excludeAnnotations` on three
**orthogonal** axes, each a pair where exactly one side survives a given device build:

| Axis | Annotations | Split |
|---|---|---|
| **Scheduling** | `(:bgPoll)` / `(:manualOnly)` | API 6.0+ devices get hourly + adaptive update modes; API < 6.0 gets manual + the daily 10:00 fetch only, and the Update Mode setting is hidden (a different `resources-modes-*` settings XML). |
| **Design** | `(:designNew)` / `(:designClassic)` | The AMOLED refresh (anti-aliasing, pill bars) on the API 6.0+ tier; the original look byte-identical on legacy. |
| **Map page** | `(:mapPage)` / `(:noMapPage)` | `WatchUi.MapView` needs onboard cartography — 32 of the 36 declared products have it; base fēnix 6, fēnix 6S, FR255 and FR745 do not. |

Seven products are on the full tier: fēnix 8 (43/47 mm), fēnix 8 Pro, fēnix 8 Solar
(47/51 mm), fēnix E, FR970. Everything else falls through to `base`.

Two traps worth knowing:

- **Jungle values REPLACE, they don't merge.** A device line must restate its *whole*
  exclusion list, which is why each per-device line repeats the base annotations.
- **A jungle qualifier for a device whose SDK profile isn't installed locally breaks
  every build**, not just that device's — which is why `fenix6s` and `fr745` still have no
  map-tier line (see the TODO in the jungles). `PageNav` therefore also guards
  instantiation with `WatchUi has :MapView` at runtime: compiling map code for a
  map-incapable device *succeeds*, so the annotation is not a safety net on its own.

---

## 13. Key invariants (do not break)

- **No `makeWebRequest` in the foreground `AppBase`** — network I/O is in the background
  service and the foreground sync/auth classes.
- **Anything reachable from the background must be `(:background)`** — the bg process loads
  only tagged classes; a missing tag → `Illegal Access (Out of Bounds)` at load.
- **The glance must not reference `VehicleCache`** — it reads `KEY_GLANCE_STATE` directly.
- **Keep the bg container small** — it must fit the ~28 KB heap (a `-403` means it's too
  big; trim `_bgContainerDescriptors`).
- **Token rotation writes the refresh token before the access token** (atomic-rotation rule),
  and never writes a null over it — a `200` without `refresh_token` leaves the stored one.
- **`NEEDS_REBOOTSTRAP` is latched only on corroborated evidence** — it is a one-way door;
  a single `invalid_grant` may be a lost rotation, not a dead grant.
- **Only `ForegroundSync.authFailed()` may send the user to pairing** — a link-level failure
  gets a note, never the device flow.
- **Every success clears the error backoff** (`QuotaGuard.clearBackoff()`) — the gate is
  only ever doubled otherwise.
- **Always use `StorageKeys.KEY_*`** — never inline a storage key string.
- **Every tier annotation needs both halves** (`:mapPage`/`:noMapPage`, `:bgPoll`/`:manualOnly`,
  `:designNew`/`:designClassic`) — a symbol excluded on one tier with no counterpart on the
  other fails that tier's build, not the one you were editing.

---

*See also: [findings/connectiq-gotchas.md](findings/connectiq-gotchas.md) (platform limits),
[findings/bmw-cardata-api.md](findings/bmw-cardata-api.md) (API behaviour),
[TESTING.md](TESTING.md) (build/run the suite on both tiers).*
