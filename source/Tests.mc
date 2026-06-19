// Unit tests — run: monkeydo bin/test.prg fenix6pro -t
// (:test) functions compile only into test builds.
// Covers pure logic: parser, ISO8601, QuotaGuard, backoff, PageChrome formatters.
using Toybox.Test;
using Toybox.Lang;
using Toybox.Application;
using Toybox.Time;

// ============================================================
//  CarDataClient._parseTelematicData — type conversion
// ============================================================

(:test)
function testParse_numericCasts(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertEqualMessage(s["rangeKm"], 653, "rangeKm");
    Test.assertEqualMessage(s["fuelPercent"], 95, "fuelPercent");
    Test.assertEqualMessage(s["fuelLitres"], 21, "fuelLitres");
    Test.assertEqualMessage(s["odometerKm"], 40926, "odometerKm");
    Test.assertEqualMessage(s["serviceDistanceKm"], 22000, "serviceDistanceKm");
    _resetStorage();
    return true;
}

// ============================================================
//  CarDataClient.isRateLimit — BMW daily limit = HTTP 403 + CU-429 body
// ============================================================

(:test)
function testRateLimit_detectsCu429(logger as Test.Logger) as Lang.Boolean {
    Test.assertMessage(CarDataClient.isRateLimit(429, null), "HTTP 429 -> rate limited");
    Test.assertMessage(CarDataClient.isRateLimit(403, {"exveErrorId" => "CU-429"}),
        "403 + CU-429 body -> rate limited");
    Test.assertMessage(!CarDataClient.isRateLimit(403, {"exveErrorId" => "CU-105"}),
        "403 + other CU code -> not rate limited");
    Test.assertMessage(!CarDataClient.isRateLimit(403, null), "403 no body -> not rate limited");
    Test.assertMessage(!CarDataClient.isRateLimit(200, null), "200 -> not rate limited");
    return true;
}

(:test)
function testCapError_detectsCu124(logger as Test.Logger) as Lang.Boolean {
    Test.assertMessage(CarDataClient.isContainerCapError(403, {"exveErrorId" => "CU-124"}),
        "403 + CU-124 -> container cap");
    Test.assertMessage(!CarDataClient.isContainerCapError(403, {"exveErrorId" => "CU-429"}),
        "403 + CU-429 (rate limit) -> not cap");
    Test.assertMessage(!CarDataClient.isContainerCapError(403, {"exveErrorId" => "CU-401"}),
        "403 + CU-401 (bad descriptor) -> not cap");
    Test.assertMessage(!CarDataClient.isContainerCapError(429, null), "429 -> not cap");
    Test.assertMessage(!CarDataClient.isContainerCapError(403, null), "403 no body -> not cap");
    return true;
}

(:test)
function testParse_booleanCasts(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(s["doorsLocked"] == true, "SECURED->true");
    Test.assertMessage(s["doorFLOpen"] == false, "CLOSED->false");
    Test.assertMessage(s["doorFROpen"] == false, "FR CLOSED->false");
    Test.assertMessage(s["trunkOpen"] == false, "trunk CLOSED->false");
    Test.assertMessage(s["hoodOpen"] == false, "hood CLOSED->false");
    _resetStorage();
    return true;
}

(:test)
function testParse_stringPassthrough(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertEqualMessage(s["displayUnit"], "km", "displayUnit");
    _resetStorage();
    return true;
}

(:test)
function testParse_kpaToBar(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(_fEq(s["tyrePressureFL"], 2.3), "FL 230kPa->2.3");
    Test.assertMessage(_fEq(s["tyrePressureRL"], 2.2), "RL 220kPa->2.2");
    Test.assertMessage(_fEq(s["tyreTargetFL"], 2.2), "target 220->2.2");
    _resetStorage();
    return true;
}

(:test)
function testParse_nullOmitted(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(!s.hasKey("dataAge"), "dataAge never stored");
    // trunk.isLocked is null in fixture and not mapped -> absent
    Test.assertMessage(!s.hasKey("trunkLocked"), "null trunk.isLocked omitted");
    _resetStorage();
    return true;
}

(:test)
function testParse_lastUpdatedIsMax(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(s.hasKey("lastUpdated"), "lastUpdated present");
    var expected = CarDataClient._parseIso8601("2026-05-27T17:53:20Z");
    Test.assertEqualMessage(s["lastUpdated"], expected, "max ts, not older 05-24");
    _resetStorage();
    return true;
}

(:test)
function testParse_emptyContainer(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData({});
    Test.assertMessage(s != null, "empty -> dict not null");
    Test.assertMessage(!s.hasKey("rangeKm"), "empty -> no fields");
    _resetStorage();
    return true;
}

(:test)
function testParse_lockEnums(logger as Test.Logger) as Lang.Boolean {
    var c = new CarDataClient();
    var unlocked = c._parseTelematicData(_lockFixture("UNLOCKED"));
    Test.assertMessage(unlocked["doorsLocked"] == false, "UNLOCKED->false");
    var locked = c._parseTelematicData(_lockFixture("LOCKED"));
    Test.assertMessage(locked["doorsLocked"] == true, "LOCKED->true");
    var invalid = c._parseTelematicData(_lockFixture("INVALID"));
    Test.assertMessage(!invalid.hasKey("doorsLocked"), "INVALID omitted");
    _resetStorage();
    return true;
}

// ============================================================
//  FR-19/FR-18 — rear doors + windows (B4/B6)
// ============================================================

(:test)
function testParse_rearDoorsAndWindowsClosed(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(s["doorRLOpen"] == false, "rear-left door CLOSED->false");
    Test.assertMessage(s["doorRROpen"] == false, "rear-right door CLOSED->false");
    Test.assertMessage(s["windowFLOpen"] == false, "FL window CLOSED->false");
    Test.assertMessage(s["windowFROpen"] == false, "FR window CLOSED->false");
    Test.assertMessage(s["windowRLOpen"] == false, "RL window CLOSED->false");
    Test.assertMessage(s["windowRROpen"] == false, "RR window CLOSED->false");
    _resetStorage();
    return true;
}

(:test)
function testParse_windowStatusVariants(logger as Test.Logger) as Lang.Boolean {
    var c = new CarDataClient();
    var open = c._parseTelematicData(_windowFixture("OPEN"));
    Test.assertMessage(open["windowFLOpen"] == true, "OPEN->true");
    var intermediate = c._parseTelematicData(_windowFixture("INTERMEDIATE"));
    Test.assertMessage(intermediate["windowFLOpen"] == false, "INTERMEDIATE->false (frameless reseat state, B11)");
    var closed = c._parseTelematicData(_windowFixture("CLOSED"));
    Test.assertMessage(closed["windowFLOpen"] == false, "CLOSED->false");
    var invalid = c._parseTelematicData(_windowFixture("INVALID"));
    Test.assertMessage(invalid["windowFLOpen"] == false, "INVALID->false");
    // OQ-4: descriptor absent entirely from this vehicle's catalog -> field omitted.
    var absent = c._parseTelematicData({ "telematicData" => {} });
    Test.assertMessage(!absent.hasKey("windowFLOpen"), "absent descriptor omitted");
    _resetStorage();
    return true;
}

// ============================================================
//  F16 — multi-powertrain range selection
// ============================================================

(:test)
function testParse_rangeSelection(logger as Test.Logger) as Lang.Boolean {
    var c = new CarDataClient();
    // ICE: only lastRemainingRange -> rangeKm = it.
    var ice = c._parseTelematicData({ "telematicData" => {
        "vehicle.drivetrain.lastRemainingRange" => { "value" => "653", "timestamp" => "2026-05-27T10:00:00Z", "unit" => "km" }
    }});
    Test.assertEqualMessage(ice["rangeKm"], 653, "ICE rangeKm = lastRemainingRange");

    // PHEV/ICE: totalRemainingRange present -> wins.
    var phev = c._parseTelematicData({ "telematicData" => {
        "vehicle.drivetrain.lastRemainingRange"  => { "value" => "100", "timestamp" => "2026-05-27T10:00:00Z", "unit" => "km" },
        "vehicle.drivetrain.totalRemainingRange" => { "value" => "420", "timestamp" => "2026-05-27T10:00:00Z", "unit" => "km" }
    }});
    Test.assertEqualMessage(phev["rangeKm"], 420, "total wins over last");

    // BEV: only electric range -> rangeKm = electric.
    var bev = c._parseTelematicData({ "telematicData" => {
        "vehicle.drivetrain.electricEngine.kombiRemainingElectricRange" => { "value" => "310", "timestamp" => "2026-05-27T10:00:00Z", "unit" => "km" },
        "vehicle.powertrain.electric.battery.stateOfCharge.displayed"   => { "value" => "72",  "timestamp" => "2026-05-27T10:00:00Z", "unit" => "%" }
    }});
    Test.assertEqualMessage(bev["rangeKm"], 310, "BEV rangeKm = electric");
    Test.assertEqualMessage(bev["socPercent"], 72, "BEV socPercent");
    _resetStorage();
    return true;
}

// ============================================================
//  About-car telematics (v3) — typed scalar parsing
// ============================================================

(:test)
function testParse_aboutCarTelematics(logger as Test.Logger) as Lang.Boolean {
    var c = new CarDataClient();
    var s = c._parseTelematicData(_aboutFixture());
    Test.assertMessage(_fEq(s["batteryVoltage"], 13.56), "battery voltage Float");
    Test.assertEqualMessage(s["coolantC"], 93, "coolant °C Number");
    Test.assertEqualMessage(s["totalRangeKm"], 499, "totalRangeKm Number");
    Test.assertEqualMessage(s["cbsCount"], 6, "cbsCount Number");
    Test.assertEqualMessage(s["teleservice"], "Initial status", "teleservice String");
    Test.assertEqualMessage(s["preconditioning"], "INACTIVE", "preconditioning String");
    Test.assertMessage(_fEq(s["lat"], 43.368), "lat Float");
    Test.assertEqualMessage(s["headingDeg"], 350, "headingDeg Number");
    // absent descriptors -> omitted entirely
    var absent = c._parseTelematicData({ "telematicData" => {} });
    Test.assertMessage(!absent.hasKey("batteryVoltage"), "absent battery omitted");
    _resetStorage();
    return true;
}

// ============================================================
//  CarDataClient._parseIso8601
// ============================================================

(:test)
function testIso8601_basic(logger as Test.Logger) as Lang.Boolean {
    var e = CarDataClient._parseIso8601("2026-05-27T17:53:20Z");
    Test.assertMessage(e > 0, "valid -> positive");
    var later = CarDataClient._parseIso8601("2026-05-27T17:53:21Z");
    Test.assertMessage(later > e, "later -> greater");
    var hour = CarDataClient._parseIso8601("2026-05-27T18:53:20Z");
    Test.assertEqualMessage(hour - e, 3600, "1h apart = 3600s");
    _resetStorage();
    return true;
}

(:test)
function testIso8601_malformed(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(CarDataClient._parseIso8601("bad"), 0, "short->0");
    Test.assertEqualMessage(CarDataClient._parseIso8601(null), 0, "null->0");
    _resetStorage();
    return true;
}

// ============================================================
//  PageChrome.oneDecimal
// ============================================================

// ============================================================
//  FR-22 — fuel consumption estimate (F9)
// ============================================================

(:test)
function testFuelConsumptionPer100Km(logger as Test.Logger) as Lang.Boolean {
    Test.assertMessage(_fEq(PageRangeFuel.consumptionPer100Km(21, 653), 3.215), "21L / 653km ~= 3.2 L/100km");
    Test.assertMessage(PageRangeFuel.consumptionPer100Km(null, 653) == null, "missing fuel -> null");
    Test.assertMessage(PageRangeFuel.consumptionPer100Km(21, null) == null, "missing range -> null");
    Test.assertMessage(PageRangeFuel.consumptionPer100Km(21, 0) == null, "zero range -> null");
    _resetStorage();
    return true;
}

(:test)
function testOneDecimal(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(PageChrome.oneDecimal(2.3), "2.3", "2.3");
    Test.assertEqualMessage(PageChrome.oneDecimal(2.0), "2.0", "2.0");
    Test.assertEqualMessage(PageChrome.oneDecimal(2.25), "2.3", "round up .25->.3");
    Test.assertEqualMessage(PageChrome.oneDecimal(2.96), "3.0", "carry 2.96->3.0");
    _resetStorage();
    return true;
}

// ============================================================
//  PageChrome._ageString
// ============================================================

(:test)
function testAgeString(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(PageChrome._ageString(30), "30s ago", "secs");
    Test.assertEqualMessage(PageChrome._ageString(120), "2m ago", "mins");
    Test.assertEqualMessage(PageChrome._ageString(7200), "2h ago", "hours");
    Test.assertEqualMessage(PageChrome._ageString(172800), "2d ago", "days");
    _resetStorage();
    return true;
}

// ============================================================
//  TokenManager — OAuth FSM (auth logic, no network)
//  Response handlers are invoked directly with mock dicts so the
//  full rotation / backoff / state-transition logic is exercised
//  without any HTTP call.
// ============================================================

(:test)
function testToken_guardStatesNoNetwork(logger as Test.Logger) as Lang.Boolean {
    // UNCONFIGURED and NEEDS_REBOOTSTRAP are permanent-failure states: short-circuit
    // to callback(false) with no network. (null state is NOT here — on first run it
    // legitimately attempts a refresh; see _runBootstrap first-run path.)
    var states = ["UNCONFIGURED", "NEEDS_REBOOTSTRAP"];
    for (var i = 0; i < states.size(); i++) {
        _resetStorage();
        Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, states[i]);
        var cap = new _BoolCapture();
        new TokenManager().ensureValidToken(cap.method(:onResult));
        Test.assertMessage(cap.called, "callback fired");
        Test.assertMessage(cap.value == false, "permanent-failure state -> false");
    }
    _resetStorage();
    return true;
}

(:test)
function testToken_validTokenSkipsRefresh(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");
    Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY, Time.now().value() + 3600);
    var cap = new _BoolCapture();
    new TokenManager().ensureValidToken(cap.method(:onResult));
    Test.assertMessage(cap.value == true, "valid unexpired token -> true (no network)");
    _resetStorage();
    return true;
}

(:test)
function testToken_refreshSuccessAtomicRotation(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    tm.onTokenRefreshResponse(200, {
        "access_token"  => "ACC-NEW",
        "refresh_token" => "REF-NEW",
        "expires_in"    => 3600
    });
    Test.assertMessage(cap.value == true, "success -> true");
    Test.assertEqualMessage(tm.getAccessToken(), "ACC-NEW", "access token stored");
    Test.assertEqualMessage(
        Application.Storage.getValue(StorageKeys.KEY_REFRESH_TOKEN), "REF-NEW",
        "refresh token rotated");
    Test.assertEqualMessage(tm.getTokenState(), "NORMAL", "state NORMAL");
    var expiry = Application.Storage.getValue(StorageKeys.KEY_ACCESS_EXPIRY);
    Test.assertMessage(_nearNow(expiry, 3600), "expiry ~= now + expires_in");
    _resetStorage();
    return true;
}

(:test)
function testToken_refreshDefaultExpiryWhenMissing(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    tm.onTokenRefreshResponse(200, { "access_token" => "A", "refresh_token" => "R" });
    var expiry = Application.Storage.getValue(StorageKeys.KEY_ACCESS_EXPIRY);
    Test.assertMessage(_nearNow(expiry, 3600), "missing expires_in -> 3600 default");
    _resetStorage();
    return true;
}

(:test)
function testToken_invalidGrantRebootstrap(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    tm.onTokenRefreshResponse(400, { "error" => "invalid_grant" });
    Test.assertMessage(cap.value == false, "invalid_grant -> false");
    Test.assertEqualMessage(tm.getTokenState(), "NEEDS_REBOOTSTRAP", "permanent failure state");
    _resetStorage();
    return true;
}

(:test)
function testToken_transientFailureSetsBackoff(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    tm.onTokenRefreshResponse(500, null);
    Test.assertMessage(cap.value == false, "5xx -> false");
    var until = Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL);
    Test.assertMessage(_nearNow(until, 2400), "first backoff ~= now + 2400");
    _resetStorage();
    return true;
}

(:test)
function testToken_backoffDoublesAndCaps(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var now = Time.now().value();

    // Active backoff with 3600s remaining → doubles to 7200.
    Application.Storage.setValue(StorageKeys.KEY_BACKOFF_UNTIL, now + 3600);
    tm._incrementBackoff();
    var until = Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL);
    Test.assertMessage(_nearNow(until, 7200), "3600 remaining -> doubles to 7200");

    // Remaining 10000 → 20000, capped to 14400 (4h).
    Application.Storage.setValue(StorageKeys.KEY_BACKOFF_UNTIL, Time.now().value() + 10000);
    tm._incrementBackoff();
    until = Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL);
    Test.assertMessage(_nearNow(until, 14400), "doubling capped at 14400");
    _resetStorage();
    return true;
}

// ============================================================
//  QuotaGuard — rate-limit gate
// ============================================================

(:test)
function testQuota_firstRunAllowed(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Test.assertMessage(QuotaGuard.canFetch(), "null gate -> allowed");
    _resetStorage();
    return true;
}

(:test)
function testQuota_activeGateBlocks(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_NEXT_ALLOWED, Time.now().value() + 1000);
    Test.assertMessage(!QuotaGuard.canFetch(), "future gate -> blocked");
    _resetStorage();
    return true;
}

(:test)
function testQuota_expiredGateAllows(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_NEXT_ALLOWED, Time.now().value() - 10);
    Test.assertMessage(QuotaGuard.canFetch(), "past gate -> allowed");
    _resetStorage();
    return true;
}

(:test)
function testQuota_updateAdvancesGate(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    QuotaGuard.updateAfterFetch();
    var next = Application.Storage.getValue(StorageKeys.KEY_NEXT_ALLOWED);
    Test.assertMessage(_nearNow(next, 2400), "advances ~40min");
    _resetStorage();
    return true;
}

(:test)
function testQuota_exceededBlocksUntil4Am(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    QuotaGuard.onQuotaExceeded();
    var next = Application.Storage.getValue(StorageKeys.KEY_NEXT_ALLOWED);
    var now = Time.now().value();
    Test.assertMessage(next > now, "429 blocks future fetches");
    Test.assertMessage(next - now <= 86400, "block lifts within 24h");
    // Unblock time is the NEXT 4 AM local — today's or tomorrow's, so its
    // offset from local midnight is 4h or 28h. (The old assertion of
    // "~now + 86400" only held when the test ran at exactly 4 AM.)
    var offset = next - Time.today().value();
    Test.assertMessage(offset == 4 * 3600 || offset == 86400 + 4 * 3600,
        "unblocks at next 4 AM local");
    _resetStorage();
    return true;
}

// ============================================================
//  VehicleCache — persistence round-trip
// ============================================================

(:test)
function testCache_roundTrip(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Test.assertMessage(VehicleCache.read() == null, "empty cache -> null");
    VehicleCache.write({ "rangeKm" => 653, "doorsLocked" => true });
    var s = VehicleCache.read();
    Test.assertMessage(s != null, "after write -> not null");
    Test.assertEqualMessage(s["rangeKm"], 653, "value preserved");
    Test.assertMessage(s["doorsLocked"] == true, "bool preserved");
    _resetStorage();
    return true;
}

// A3 migration: a container id cached under an older container name (or with no
// name stamp at all — pre-v2 installs) must be invalidated, so the bootstrap
// chain re-runs discovery/creation with the v2 descriptor set.
(:test)
function testContainer_staleNameInvalidatesCachedId(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Test.assertMessage(CarDataClient.cachedContainerId() == null, "empty -> null");
    // Pre-upgrade install: id cached without a name stamp.
    Application.Storage.setValue(StorageKeys.KEY_CONTAINER_ID, "OLD-V1-ID");
    Test.assertMessage(CarDataClient.cachedContainerId() == null, "unstamped id invalidated");
    Test.assertMessage(Application.Storage.getValue(StorageKeys.KEY_CONTAINER_ID) == null,
        "stale id deleted from Storage");
    // Current install: id stamped with the current container name round-trips.
    CarDataClient._storeContainer("NEW-V2-ID");
    Test.assertEqualMessage(CarDataClient.cachedContainerId(), "NEW-V2-ID", "stamped id returned");
    _resetStorage();
    return true;
}

// FR-15/B3: a fetch where the lock descriptor came back INVALID (so doorsLocked is
// absent from the new state) must not erase the previously-cached doorsLocked —
// merge-on-write preserves it, keeping PageLock visible (FR-16).
(:test)
function testCache_mergePreservesDoorsLocked(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    VehicleCache.write({ "doorsLocked" => true, "rangeKm" => 653, "lastUpdated" => 1000 });
    VehicleCache.write({ "rangeKm" => 660, "lastUpdated" => 2000 });
    var s = VehicleCache.read();
    Test.assertMessage(s["doorsLocked"] == true, "doorsLocked preserved across merge");
    Test.assertEqualMessage(s["rangeKm"], 660, "rangeKm updated");
    Test.assertEqualMessage(s["lastUpdated"], 2000, "lastUpdated advances to newer");
    _resetStorage();
    return true;
}

// OOM fix (2026-06-15): the glance must read a lean projection, never the full
// Vehicle State (deserializing ~40 keys OOMs the glance memory partition on
// fenix 6 Pro). write() projects the glance-visible subset into KEY_GLANCE_STATE.
(:test)
function testGlance_summaryProjection(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    VehicleCache.write({
        "doorsLocked" => true, "rangeKm" => 653, "fuelPercent" => 80, "fuelLitres" => 40,
        "lastUpdated" => 1000,
        // heavy About/tyre fields that must NOT leak into the glance projection:
        "lat" => 48.1, "lon" => 11.5, "tyrePressureFL" => 2.4, "odometerKm" => 40926,
        "teleservice" => "IDLE"
    });
    var g = Application.Storage.getValue(StorageKeys.KEY_GLANCE_STATE) as Lang.Dictionary or Null;
    Test.assertMessage(g != null, "glance projection written");
    Test.assertEqualMessage(g["rangeKm"], 653, "rangeKm projected");
    Test.assertMessage(g["doorsLocked"] == true, "doorsLocked projected");
    Test.assertEqualMessage(g["fuelPercent"], 80, "fuelPercent projected");
    Test.assertEqualMessage(g["fuelLitres"], 40, "fuelLitres projected");
    Test.assertEqualMessage(g["lastUpdated"], 1000, "lastUpdated projected");
    Test.assertMessage(!g.hasKey("lat"), "heavy lat excluded");
    Test.assertMessage(!g.hasKey("tyrePressureFL"), "tyre field excluded");
    Test.assertEqualMessage(g.size(), 5, "only the 5 glance fields");
    _resetStorage();
    return true;
}

// clear() (sign-out) must drop the glance projection too, else a stale glance
// survives into the next pairing.
(:test)
function testGlance_clearDropsProjection(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    VehicleCache.write({ "rangeKm" => 100, "lastUpdated" => 1 });
    Test.assertMessage(Application.Storage.getValue(StorageKeys.KEY_GLANCE_STATE) != null, "projection present after write");
    VehicleCache.clear();
    Test.assertMessage(Application.Storage.getValue(StorageKeys.KEY_GLANCE_STATE) == null, "projection cleared on sign-out");
    _resetStorage();
    return true;
}

// Upgrade backfill: a pre-upgrade install has a full state but no projection;
// ensureGlanceSummary() (foreground) seeds it so the glance isn't blank.
(:test)
function testGlance_backfillFromFullState(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_VEHICLE_STATE,
        { "rangeKm" => 200, "fuelPercent" => 50, "lastUpdated" => 5 });
    Test.assertMessage(Application.Storage.getValue(StorageKeys.KEY_GLANCE_STATE) == null, "no projection pre-backfill");
    VehicleCache.ensureGlanceSummary();
    var g = Application.Storage.getValue(StorageKeys.KEY_GLANCE_STATE) as Lang.Dictionary or Null;
    Test.assertMessage(g != null, "backfilled");
    Test.assertEqualMessage(g["rangeKm"], 200, "rangeKm backfilled");
    Test.assertEqualMessage(g.size(), 3, "only present glance fields backfilled");
    _resetStorage();
    return true;
}

// ============================================================
//  test helpers (auth/quota/cache)
// ============================================================

// Captures the boolean a TokenManager callback is invoked with.
(:test)
class _BoolCapture {
    var value;
    var called;
    function initialize() { value = null; called = false; }
    function onResult(b) { value = b; called = true; }
}

// Wipe runtime Storage between tests so each starts from a known state.
// NOTE: plain (not (:test)) — annotating a helper makes the runner execute it
// as a test case. (:test) is only for the actual test_* functions.
function _resetStorage() {
    Application.Storage.clearValues();
}

// True if a stored epoch is ~= now + offset (tolerates a few seconds of clock drift).
function _nearNow(stored, offset) {
    if (stored == null) { return false; }
    var expected = Time.now().value() + offset;
    var d = stored - expected;
    if (d < 0) { d = -d; }
    return d <= 5;
}

// ============================================================
//  fixtures
// ============================================================

function _lockFixture(val) {
    return { "telematicData" => {
        "vehicle.cabin.door.lock.status" =>
            { "value" => val, "timestamp" => "2026-05-27T10:00:00Z", "unit" => null }
    }};
}

function _windowFixture(status) {
    return { "telematicData" => {
        "vehicle.cabin.window.row1.driver.status" =>
            { "value" => status, "timestamp" => "2026-05-27T10:00:00Z", "unit" => null }
    }};
}

function _aboutFixture() {
    var ts = "2026-05-27T10:00:00Z";
    return { "telematicData" => {
        "vehicle.electricalSystem.battery.voltage"                          => { "value" => "13.56",          "timestamp" => ts, "unit" => "V" },
        "vehicle.drivetrain.internalCombustionEngine.engine.ect"            => { "value" => "93",             "timestamp" => ts, "unit" => "°C" },
        "vehicle.drivetrain.totalRemainingRange"                            => { "value" => "499",            "timestamp" => ts, "unit" => "km" },
        "vehicle.status.conditionBasedServicesCount"                        => { "value" => "6",              "timestamp" => ts, "unit" => null },
        "vehicle.channel.teleservice.status"                                => { "value" => "Initial status", "timestamp" => ts, "unit" => null },
        "vehicle.vehicle.preConditioning.activity"                          => { "value" => "INACTIVE",       "timestamp" => ts, "unit" => null },
        "vehicle.cabin.infotainment.navigation.currentLocation.latitude"    => { "value" => "43.368",         "timestamp" => ts, "unit" => "degrees" },
        "vehicle.cabin.infotainment.navigation.currentLocation.heading"     => { "value" => "350",            "timestamp" => ts, "unit" => "degrees" }
    }};
}

function _fEq(a, b) {
    if (a == null) { return false; }
    var d = a - b;
    if (d < 0) { d = -d; }
    return d < 0.01;
}

// The canonical 27-descriptor fixture lives in MockData — one copy to maintain.
// (:debug) because MockData is compiled out of (:release); the (:test) callers
// are compiled out there too, so nothing dangles.
(:debug)
function _fixture() {
    return MockData.telematicFixture();
}
