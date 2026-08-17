# Test Suite

Unit tests for the BMW status widget. All tests live in
[source/Tests.mc](../source/Tests.mc) and use the Connect IQ `Toybox.Test`
framework (`(:test)` annotation — test functions compile only into test builds,
never into release).

**42 tests, 0 failures** (verified 2026-08-17). They cover every major module *except the
live network data calls* (`makeWebRequest`). Network handlers are exercised by
invoking their response callbacks directly with mock dictionaries, so the full
parse / FSM / rotation / backoff logic runs without any HTTP traffic.

Beyond parsing / token-FSM / quota / cache / glance-projection, the suite also
covers the BMW error-code classifiers used across the app:
`testRateLimit_detectsCu429` (rate limit = HTTP 403 + CU-429),
`testCapError_detectsCu124` (container cap), and
`testDelete_alreadyDeletingIsOk` (async-delete CU-122 = success).

## Running

```sh
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"

# build a test binary (-t compiles the (:test) code)
java -jar "$SDK/bin/monkeybrains.jar" \
  -o bin/test.prg -f monkey.jungle -y developer_key -d fenix6pro_sim -w -t

# run it in the simulator (simulator must be open first)
"$SDK/bin/monkeydo" bin/test.prg fenix6pro -t
```

**Run the suite on BOTH capability tiers.** The jungle's tier split
(`base.excludeAnnotations = bgPoll`) means a fenix6pro (legacy) build never
compiles the `(:bgPoll)` code — hourly/adaptive scheduling and
`_adaptiveShouldFetch` — so a legacy-only run cannot catch full-tier
regressions (even syntax errors there). Repeat on a full-tier device:

```sh
java -jar "$SDK/bin/monkeybrains.jar" \
  -o bin/test8.prg -f monkey.jungle -y developer_key -d fenix8pro47mm_sim -w -t
"$SDK/bin/monkeydo" bin/test8.prg fenix8pro47mm -t
```

Expected tail:

```
Ran 42 tests
PASSED (passed=42, failed=0, errors=0)
```

## What is and isn't covered

| Layer | Covered? | How |
|---|---|---|
| Telematic JSON → Vehicle State parser | ✅ | direct `_parseTelematicData(fixture)` |
| ISO-8601 → epoch | ✅ | direct `_parseIso8601` |
| OAuth token FSM (auth) | ✅ | `ensureValidToken` + direct `onTokenRefreshResponse` |
| Quota / rate-limit gate | ✅ | seed Storage, assert `canFetch` / advances |
| Vehicle State persistence | ✅ | `VehicleCache` write→read round-trip |
| UI formatters | ✅ | `PageChrome.oneDecimal`, `_ageString` |
| Fuel litres math (glance ≡ page) | ✅ | `FuelMath` derived from `fuelPercent` × tank (B12) |
| **Live HTTP fetches** | ⛔ by design | network excluded; only the response handlers are tested |
| View `onUpdate` rendering | ⛔ | requires a graphics context; not unit-testable |

---

## CarDataClient — telematic parser (12)

Source: [source/api/CarDataClient.mc](../source/api/CarDataClient.mc).
Most run against `_fixture()` — the 26-descriptor BMW 218i payload in
[source/mock/MockData.mc](../source/mock/MockData.mc) (`(:debug :background)`, so it never
reaches a release build); the rest build minimal inline payloads.

| Test | Asserts |
|---|---|
| `testParse_numericCasts` | String values cast to `Number`: `rangeKm` 653, `fuelPercent` 95, `fuelLitres` 21, `odometerKm` 40926, `serviceDistanceKm` 22000. |
| `testParse_booleanCasts` | Open/closed + lock strings cast to `Boolean`: `doorsLocked` true (`SECURED`), all doors/trunk/hood false (`CLOSED`). |
| `testParse_stringPassthrough` | `displayUnit` passes through as the string `"km"`. |
| `testParse_kpaToBar` | kPa → bar conversion (÷100.0): 230→2.3, 220→2.2, target 220→2.2. |
| `testParse_nullOmitted` | Null-valued descriptors are omitted, never stored as null (`ignitionOn` absent); `dataAge` is never persisted. |
| `testParse_lastUpdatedIsMax` | `lastUpdated` = **max** epoch across all fields — the newer `2026-05-27T17:53:20Z`, not the older `05-24` entries. *(This is the test that caught the `String.compareTo` crash — see below.)* |
| `testParse_emptyContainer` | Empty `{}` → non-null dict with no fields (no crash, no partial state). |
| `testParse_lockEnums` | Lock enum mapping: `UNLOCKED`→false, `LOCKED`→true, `INVALID`→omitted entirely. |
| `testParse_rearDoorsAndWindowsClosed` | Row2 doors and all four windows parse to `false` from `CLOSED` (FR-19 rear-door support). |
| `testParse_windowStatusVariants` | Only `OPEN` counts as open: `INTERMEDIATE` (frameless reseat, B11), `CLOSED` and `INVALID` → false; an absent descriptor is omitted, not false (OQ-4). |
| `testParse_rangeSelection` | F16 powertrain-aware range: ICE → `lastRemainingRange`; `totalRemainingRange` wins when present; BEV → `kombiRemainingElectricRange` + `socPercent`. |
| `testParse_aboutCarTelematics` | About-car detail casts: battery volts Float, coolant/`totalRangeKm`/`cbsCount` Number, teleservice + preconditioning String, lat/lon Float. |

## CarDataClient — ISO-8601 (2)

| Test | Asserts |
|---|---|
| `testIso8601_basic` | Valid timestamp → positive epoch; later string → greater value; two strings 1h apart differ by exactly 3600s. |
| `testIso8601_malformed` | `"bad"` (too short) → 0; `null` → 0. Never throws. |

## TokenManager — OAuth FSM / auth (7)

Source: [source/api/TokenManager.mc](../source/api/TokenManager.mc).
The `_callback` is a public field, so response handlers are tested by assigning
a capture callback and invoking them directly — no HTTP. `_resetStorage()` wipes
runtime Storage before each test.

| Test | Asserts |
|---|---|
| `testToken_guardStatesNoNetwork` | `ensureValidToken` short-circuits to `callback(false)` with **no network** for state `null`, `UNCONFIGURED`, and `NEEDS_REBOOTSTRAP`. |
| `testToken_validTokenSkipsRefresh` | `NORMAL` state with an unexpired access token → `callback(true)` immediately, no refresh. |
| `testToken_refreshSuccessAtomicRotation` | 200 response → **refresh token written before access token** (atomic rotation rule), state `NORMAL`, access token retrievable, expiry ≈ now + `expires_in`. |
| `testToken_refreshDefaultExpiryWhenMissing` | 200 response with no `expires_in` → expiry defaults to now + 3600s. |
| `testToken_invalidGrantRebootstrap` | 400 `invalid_grant` → permanent failure: state `NEEDS_REBOOTSTRAP`, `callback(false)`. |
| `testToken_transientFailureSetsBackoff` | 5xx / null data → `callback(false)` and a backoff is armed (≈ now + 2400s base). |
| `testToken_backoffDoublesAndCaps` | `_incrementBackoff` doubles the remaining wait (3600→7200) and caps at 14400s (4h). |

## QuotaGuard — rate-limit gate (5)

Source: [source/guard/QuotaGuard.mc](../source/guard/QuotaGuard.mc).

| Test | Asserts |
|---|---|
| `testQuota_firstRunAllowed` | No gate stored (first run) → `canFetch()` true. |
| `testQuota_activeGateBlocks` | Gate in the future → `canFetch()` false (background skips the cycle). |
| `testQuota_expiredGateAllows` | Gate in the past → `canFetch()` true. |
| `testQuota_updateAdvancesGate` | `updateAfterFetch()` advances the gate ≈ now + 2400s (40-min poll interval). |
| `testQuota_exceededBlocksUntil4Am` | `onQuotaExceeded()` (CU-429) blocks until the **next 4 AM local** — the offset from local midnight is 4 h or 28 h, and the block always lifts within 24 h. (The older "≈ now + 86400s" assertion only held if the test ran at exactly 4 AM.) |

## VehicleCache & containers — persistence (3)

Source: [source/cache/VehicleCache.mc](../source/cache/VehicleCache.mc),
[source/api/CarDataClient.mc](../source/api/CarDataClient.mc).

| Test | Asserts |
|---|---|
| `testCache_roundTrip` | Empty cache → `null`; after `write()` the dict round-trips with `Number` and `Boolean` values intact. |
| `testCache_mergePreservesDoorsLocked` | Merge-on-write (FR-15/16, B3): a later write that omits `doorsLocked` doesn't erase it, so the Lock page stays visible. |
| `testContainer_staleNameInvalidatesCachedId` | A cached container id whose stored **name** no longer matches the current `_CONTAINER_NAME` is dropped and re-resolved (the version-bump path, §11). |

## Glance projection (3)

Source: [source/cache/VehicleCache.mc](../source/cache/VehicleCache.mc) `_writeGlanceSummary`.

| Test | Asserts |
|---|---|
| `testGlance_summaryProjection` | `KEY_GLANCE_STATE` holds exactly `doorsLocked`/`rangeKm`/`fuelPercent`/`lastUpdated` — heavy fields (`lat`, tyres) stay out, which is what keeps the glance inside its ~28 KB partition. |
| `testGlance_clearDropsProjection` | `clear()` (sign-out) removes the projection as well as the full state. |
| `testGlance_backfillFromFullState` | `ensureGlanceSummary()` seeds the projection from an existing full state — the upgrade path for installs predating `KEY_GLANCE_STATE`. |

## FuelMath (2)

Source: [source/FuelMath.mc](../source/FuelMath.mc).

| Test | Asserts |
|---|---|
| `testFuelMath_derivesLitresFromPercent` | Litres in tank / to fill derive from `fuelPercent` × tank size (B12), sum to the tank, clamp at 0/full, follow a changed tank property, and pass `null` through. |
| `testFuelConsumptionPer100Km` | The FR-22 instantaneous `~L/100 km` estimate from remaining litres + remaining range. |

## Map page (2)

Source: [source/PageNav.mc](../source/PageNav.mc), [source/ui/PageMap.mc](../source/ui/PageMap.mc).

| Test | Asserts |
|---|---|
| `testMapPage_pageCountIncludesMapSlot` | The carousel has the build-variant fifth slot on a map-capable build (`_pageCount()` = 5). |
| `testMapPage_visibilityRequiresBothCoordinates` | The page hides unless **both** `lat` and `lon` are cached — one alone is not a fix. |

## DeviceAuthManager — auth error text (1)

Source: [source/api/DeviceAuthManager.mc](../source/api/DeviceAuthManager.mc).

| Test | Asserts |
|---|---|
| `testAuth_errorTextIsActionableAndFits` | `invalid_request` (what a disabled portal permission actually returns, alongside RFC 6749 boilerplate) maps to the "check CarData API + streaming" hint; an unmapped code keeps BMW's own words but capped at `_MSG_MAX`; a code with no description falls back to the code; a bodyless 429 gives the friendly transport text. The length cap matters because `AuthView` word-wraps without clipping — an uncapped sentence runs off the bezel. |

## BMW error-code classifiers (3)

Source: [source/api/CarDataClient.mc](../source/api/CarDataClient.mc).

| Test | Asserts |
|---|---|
| `testRateLimit_detectsCu429` | Daily limit = HTTP **403** with `exveErrorId == CU-429` (and plain 429) → `isRateLimit` true. |
| `testCapError_detectsCu124` | Container cap = 403 + `CU-124` → `isCapError` true. |
| `testDelete_alreadyDeletingIsOk` | `CU-122` ("already set for deletion") counts as a successful delete. |

## PageChrome — UI formatters (2)

Source: [source/ui/PageChrome.mc](../source/ui/PageChrome.mc).

| Test | Asserts |
|---|---|
| `testOneDecimal` | 1-decimal formatting incl. rounding and carry: 2.3→"2.3", 2.0→"2.0", 2.25→"2.3", 2.96→"3.0". |
| `testAgeString` | Data-age humanizer: 30→"30s ago", 120→"2m ago", 7200→"2h ago", 172800→"2d ago". |

---

## Test helpers

Defined in [source/Tests.mc](../source/Tests.mc). Helper *functions* are plain
(annotating a helper with `(:test)` makes the test runner try to execute it as a
test case); only `_BoolCapture` carries `(:test)` since a class is never run as a
test. The `(:test)`-only code is still excluded from release builds via the test
build flag.

- **`_fixture()`** — returns `MockData.telematicFixture()`, the 26-descriptor BMW 218i
  telematic payload in [source/mock/MockData.mc](../source/mock/MockData.mc) (mixed
  fresh/stale timestamps, one null-valued descriptor). `MockData` is `(:debug :background)`
  and referenced **only** from the test file — the app itself has no mock layer and always
  talks to the live API.
- **`_lockFixture(val)` / `_windowFixture(val)`** — minimal payloads carrying a single
  lock- or window-status descriptor, for enum-mapping tests.
- **`_aboutFixture()`** — the About-car telematics subset (battery, coolant, location…).
- **`_BoolCapture`** — object whose `onResult(b)` records the boolean a
  `TokenManager` callback was invoked with (`called` / `value`).
- **`_resetStorage()`** — `Application.Storage.clearValues()`; gives each
  Storage-touching test a clean slate.
- **`_nearNow(stored, offset)`** — true if a stored epoch ≈ `now + offset`
  (±5s tolerance, to absorb clock drift between store and assert).
- **`_fEq(a, b)`** — float equality within 0.01 (for kPa→bar comparisons).

## Notes

- **A real bug these tests caught.** `_updateMaxTs` originally called
  `ts.compareTo(_maxTs)` — Monkey C `String` has no `compareTo`, so the parser
  threw *Symbol Not Found* on **every** real fetch carrying a timestamp. The
  simulator missed it (seeded debug data bypasses the parser); `testParse_*`
  exposed it immediately. Fixed by accumulating max **epoch** (numeric compare).
- **Build warnings** ("Cannot determine if container access is using container
  type", one "Statement is not reachable") are type-inference notices on
  dictionary access — cosmetic, not errors.
- **Still untested:** live `makeWebRequest` calls (excluded by request) and View
  `onUpdate` rendering (needs a real graphics context).
