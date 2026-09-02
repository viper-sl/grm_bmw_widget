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
function testDelete_alreadyDeletingIsOk(logger as Test.Logger) as Lang.Boolean {
    Test.assertMessage(CarDataClient.isAlreadyDeleting({"exveErrorId" => "CU-122"}),
        "CU-122 -> already deleting (treat as success)");
    Test.assertMessage(!CarDataClient.isAlreadyDeleting({"exveErrorId" => "CU-124"}),
        "CU-124 -> not already deleting");
    Test.assertMessage(!CarDataClient.isAlreadyDeleting(null), "no body -> not already deleting");
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
    Test.assertMessage(_fEq(s["lat"], 48.137), "lat Float");
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

// ============================================================
//  FuelMath — the glance and the Range & Fuel page must quote identical litres.
//  Regression: the glance read the raw (stale) "fuelLitres" and showed
//  "41% (+8L)" while the page derived "31L to fill" for the same 41 % / 52 L car.
// ============================================================

(:test)
function testFuelMath_derivesLitresFromPercent(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Properties.setValue("tankLitres", 52);
    Test.assertEqualMessage(FuelMath.tankLitres(), 52, "tank from property");
    // 41 % of 52 L = 21.32 → truncated to 21 in tank, 31 to fill (NOT the 8 the
    // stale 44 L field produced).
    Test.assertEqualMessage(FuelMath.litresInTank(41), 21, "41% of 52L in tank");
    Test.assertEqualMessage(FuelMath.litresToFill(41), 31, "41% of 52L -> 31L to fill");
    // The two halves always account for the whole tank.
    Test.assertEqualMessage(FuelMath.litresInTank(41) + FuelMath.litresToFill(41), 52,
        "in + toFill == tank");
    // Boundaries: empty, full, and an over-100 % reading right after a brim fill.
    Test.assertEqualMessage(FuelMath.litresToFill(0), 52, "empty -> full tank to fill");
    Test.assertEqualMessage(FuelMath.litresToFill(100), 0, "full -> nothing to fill");
    Test.assertEqualMessage(FuelMath.litresToFill(105), 0, "over-full clamps at 0");
    Test.assertMessage(FuelMath.litresInTank(null) == null, "unknown percent -> null");
    Test.assertMessage(FuelMath.litresToFill(null) == null, "unknown percent -> null");
    // A different tank size flows through both.
    Application.Properties.setValue("tankLitres", 60);
    Test.assertEqualMessage(FuelMath.litresInTank(50), 30, "50% of 60L");
    Test.assertEqualMessage(FuelMath.litresToFill(50), 30, "50% of 60L to fill");
    // _resetStorage() clears Storage but NOT Properties — restore the default so
    // the tank size doesn't leak into later tests.
    Application.Properties.setValue("tankLitres", FuelMath.DEFAULT_TANK_LITRES);
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

// A single invalid_grant is NOT proof the grant is dead: a refresh whose response was
// lost in transit (BMW rotated, the watch never saw the new token) produces exactly one,
// and NEEDS_REBOOTSTRAP is a one-way door. Strike one must behave like any transient
// failure; only the second latches.
(:test)
function testToken_invalidGrantNeedsCorroboration(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);

    tm.onTokenRefreshResponse(400, { "error" => "invalid_grant" });
    Test.assertMessage(cap.value == false, "invalid_grant -> false");
    Test.assertMessage(tm.getTokenState() == null, "first strike does NOT latch");
    Test.assertEqualMessage(
        Application.Storage.getValue(StorageKeys.KEY_GRANT_STRIKES), 1, "strike recorded");
    var until = Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL);
    Test.assertMessage(_nearNow(until, 2400), "first strike backs off like a transient error");

    // Every strike up to the threshold behaves the same way. Driven off the constant
    // so raising it can't leave this test asserting the old rule.
    for (var i = 2; i < TokenManager.GRANT_STRIKES_UNATTENDED; i++) {
        tm.onTokenRefreshResponse(400, { "error" => "invalid_grant" });
        Test.assertMessage(tm.getTokenState() == null, "strike below threshold does NOT latch");
        Test.assertEqualMessage(
            Application.Storage.getValue(StorageKeys.KEY_GRANT_STRIKES), i, "strike counted");
    }

    tm.onTokenRefreshResponse(400, { "error" => "invalid_grant" });
    Test.assertEqualMessage(tm.getTokenState(), "NEEDS_REBOOTSTRAP", "threshold strike latches");
    _resetStorage();
    return true;
}

// A refresh driven by a START press latches sooner: the user is watching and can act
// on the prompt. Same shared counter, lower bar.
(:test)
function testToken_manualStrikeThresholdIsLower(logger as Test.Logger) as Lang.Boolean {
    Test.assertMessage(
        TokenManager.GRANT_STRIKES_MANUAL < TokenManager.GRANT_STRIKES_UNATTENDED,
        "manual threshold must be the lower of the two");

    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    tm.setManual(true);

    for (var i = 1; i < TokenManager.GRANT_STRIKES_MANUAL; i++) {
        tm.onTokenRefreshResponse(400, { "error" => "invalid_grant" });
        Test.assertMessage(tm.getTokenState() == null, "below the manual threshold: no latch");
    }
    tm.onTokenRefreshResponse(400, { "error" => "invalid_grant" });
    Test.assertEqualMessage(tm.getTokenState(), "NEEDS_REBOOTSTRAP", "manual threshold latches");

    // The same strike count left by an unattended run must NOT have latched.
    _resetStorage();
    var bg = new TokenManager();
    bg._callback = cap.method(:onResult);
    for (var j = 0; j < TokenManager.GRANT_STRIKES_MANUAL; j++) {
        bg.onTokenRefreshResponse(400, { "error" => "invalid_grant" });
    }
    Test.assertMessage(bg.getTokenState() == null,
        "unattended run survives the manual threshold");
    _resetStorage();
    return true;
}

// A successful refresh retires the strike ledger — otherwise an old strike would latch
// on the next isolated 400. It must NOT clear the error backoff: that gates the DATA
// API, and a refresh against customer.bmwgroup.com is no evidence that host is healthy.
// Clearing it here let one widget open reset a backoff earned by a data-API outage.
(:test)
function testToken_successClearsStrikesNotBackoff(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    Application.Storage.setValue(StorageKeys.KEY_GRANT_STRIKES, 1);
    Application.Storage.setValue(StorageKeys.KEY_BACKOFF_UNTIL, Time.now().value() + 14400);

    tm.onTokenRefreshResponse(200, { "access_token" => "A", "refresh_token" => "R" });
    Test.assertMessage(
        Application.Storage.getValue(StorageKeys.KEY_GRANT_STRIKES) == null, "strikes cleared");
    Test.assertMessage(
        _nearNow(Application.Storage.getValue(StorageKeys.KEY_BACKOFF_UNTIL), 14400),
        "data-API backoff survives a token refresh");
    _resetStorage();
    return true;
}

// A 200 that omits refresh_token must leave the stored one alone. Writing null over it
// strands the widget in UNCONFIGURED on the very next call (DeviceAuthManager already
// guards this; TokenManager did not).
(:test)
function testToken_missingRefreshTokenKeepsStored(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    Application.Storage.setValue(StorageKeys.KEY_REFRESH_TOKEN, "REF-OLD");

    tm.onTokenRefreshResponse(200, { "access_token" => "ACC-NEW", "expires_in" => 3600 });
    Test.assertMessage(cap.value == true, "still a success");
    Test.assertEqualMessage(
        Application.Storage.getValue(StorageKeys.KEY_REFRESH_TOKEN), "REF-OLD",
        "existing refresh token preserved");
    Test.assertEqualMessage(tm.getAccessToken(), "ACC-NEW", "access token still rotated");
    _resetStorage();
    return true;
}

// BMW rotates on every refresh, so two overlapping refreshes race and the loser gets a
// 400 invalid_grant. A caller arriving mid-refresh must fail transiently instead —
// no second POST, and above all no change to the token state.
(:test)
function testToken_concurrentRefreshIsBlocked(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    // Start from NORMAL, the state a healthy widget is actually in when a sibling
    // refresh collides with it. Asserting from "NEEDS_REFRESH" proved nothing: that is
    // the value the refresh path writes anyway, so the assertion held whether or not
    // the gate worked.
    Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");
    Application.Storage.setValue(StorageKeys.KEY_REFRESH_TOKEN, "REF");
    // Inside the skew window, so ensureValidToken routes to _refreshToken.
    Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY,
        Time.now().value() + TokenManager.EXPIRY_SKEW_SECONDS - 30);
    Application.Storage.setValue(StorageKeys.KEY_REFRESH_INFLIGHT, Time.now().value());

    var cap = new _BoolCapture();
    new TokenManager().ensureValidToken(cap.method(:onResult));
    Test.assertMessage(cap.called, "callback fired");
    Test.assertMessage(cap.value == false, "in-flight refresh -> transient false");
    Test.assertEqualMessage(
        Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE), "NORMAL",
        "token state genuinely untouched (not demoted, not an auth failure)");
    _resetStorage();
    return true;
}

// A stamp dated in the future (the clock moved backwards) must still count as live —
// failing open there reopens the double-refresh race the stamp exists to close.
(:test)
function testToken_futureInflightStillBlocks(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");
    Application.Storage.setValue(StorageKeys.KEY_REFRESH_TOKEN, "REF");
    Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY, Time.now().value() - 1);
    Application.Storage.setValue(StorageKeys.KEY_REFRESH_INFLIGHT, Time.now().value() + 30);

    var cap = new _BoolCapture();
    new TokenManager().ensureValidToken(cap.method(:onResult));
    Test.assertMessage(cap.value == false, "future stamp -> still blocked");
    Test.assertEqualMessage(
        Application.Storage.getValue(StorageKeys.KEY_TOKEN_STATE), "NORMAL",
        "state untouched");

    // ...but an impossible stamp is discarded rather than blocking forever.
    _resetStorage();
    var prev = _blankCreds();
    try {
        var tm = new TokenManager();
        var cap2 = new _BoolCapture();
        tm._callback = cap2.method(:onResult);
        Application.Storage.setValue(StorageKeys.KEY_REFRESH_INFLIGHT,
            Time.now().value() + TokenManager.INFLIGHT_TTL_SECONDS + 600);
        tm._refreshToken();
        Test.assertEqualMessage(tm.getTokenState(), "UNCONFIGURED",
            "impossible stamp discarded, gate passed");
    } finally {
        _restoreCreds(prev);
        _resetStorage();
    }
    return true;
}

// A refresh that never went out must not advance the token state. Before the fix,
// ensureValidToken wrote NEEDS_REFRESH up front, so a gated or credential-less attempt
// demoted a healthy NORMAL watch to a state only a successful refresh clears.
(:test)
function testToken_abortedAttemptLeavesStateAlone(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var prev = _blankCreds();
    try {
        Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NEEDS_REBOOTSTRAP");
        Application.Storage.setValue(StorageKeys.KEY_GRANT_STRIKES, 2);
        var tm = new TokenManager();
        var cap = new _BoolCapture();
        // Forced retry with no creds: aborts at the creds check, before dispatch.
        tm.retryAfterRebootstrap(cap.method(:onResult));
        Test.assertEqualMessage(
            Application.Storage.getValue(StorageKeys.KEY_GRANT_STRIKES), 2,
            "strike ledger survives an attempt that never sent anything");
    } finally {
        _restoreCreds(prev);
        _resetStorage();
    }
    return true;
}

// A stale in-flight stamp (process killed mid-refresh) must not block refreshes forever.
(:test)
function testToken_staleInflightExpires(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var prev = _blankCreds();
    try {
        var tm = new TokenManager();
        var cap = new _BoolCapture();
        tm._callback = cap.method(:onResult);
        Application.Storage.setValue(StorageKeys.KEY_REFRESH_INFLIGHT,
            Time.now().value() - TokenManager.INFLIGHT_TTL_SECONDS - 1);
        // With the creds blanked, reaching UNCONFIGURED is the proof the call got PAST
        // the in-flight gate instead of returning at it.
        tm._refreshToken();
        Test.assertEqualMessage(tm.getTokenState(), "UNCONFIGURED", "stale stamp ignored");
    } finally {
        _restoreCreds(prev);
        _resetStorage();
    }
    return true;
}

// The response handler releases the in-flight lock on every outcome — but only the lock
// it took. A response that outlived the TTL must leave the stamp a later refresh now
// owns, or a third caller could dispatch into that live rotation.
(:test)
function testToken_responseReleasesOnlyItsOwnInflight(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var stamp = Time.now().value();
    var tm = new TokenManager();
    var cap = new _BoolCapture();
    tm._callback = cap.method(:onResult);
    tm._inFlightStamp = stamp;                     // as if _refreshToken had dispatched
    Application.Storage.setValue(StorageKeys.KEY_REFRESH_INFLIGHT, stamp);
    tm.onTokenRefreshResponse(500, null);
    Test.assertMessage(
        Application.Storage.getValue(StorageKeys.KEY_REFRESH_INFLIGHT) == null,
        "own lock released on failure too");

    // Overtaken: our response lands after a later refresh re-stamped. Leave it alone.
    _resetStorage();
    var later = Time.now().value() + 120;
    var slow = new TokenManager();
    slow._callback = cap.method(:onResult);
    slow._inFlightStamp = stamp;
    Application.Storage.setValue(StorageKeys.KEY_REFRESH_INFLIGHT, later);
    slow.onTokenRefreshResponse(500, null);
    Test.assertEqualMessage(
        Application.Storage.getValue(StorageKeys.KEY_REFRESH_INFLIGHT), later,
        "a stale response must not release someone else's lock");
    _resetStorage();
    return true;
}

// An access token that expires while the request is in the air comes back as a 401 the
// data path treats as transient. Refresh a skew window early instead.
(:test)
function testToken_refreshesBeforeExpiry(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var prev = _blankCreds();
    try {
        Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");
        // Not expired, but inside the skew window — with the creds blanked, _refreshToken
        // bails to UNCONFIGURED, the observable proof that a refresh was attempted.
        Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY,
            Time.now().value() + TokenManager.EXPIRY_SKEW_SECONDS - 30);
        var cap = new _BoolCapture();
        var tm = new TokenManager();
        tm.ensureValidToken(cap.method(:onResult));
        Test.assertMessage(cap.value == false, "near-expiry token is not served as valid");
        Test.assertEqualMessage(tm.getTokenState(), "UNCONFIGURED", "a refresh was attempted");

        // Comfortably outside the skew window -> served as-is, no refresh.
        _resetStorage();
        Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NORMAL");
        Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY,
            Time.now().value() + TokenManager.EXPIRY_SKEW_SECONDS + 600);
        cap = new _BoolCapture();
        new TokenManager().ensureValidToken(cap.method(:onResult));
        Test.assertMessage(cap.value == true, "token outside the skew window is still valid");
    } finally {
        _restoreCreds(prev);
        _resetStorage();
    }
    return true;
}

// The re-link prompt's escape hatch: retryAfterRebootstrap ignores the one-way guard
// and clears the strike count, so a spurious latch is recoverable without re-pairing.
(:test)
function testToken_retryAfterRebootstrapBypassesGuard(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    var prev = _blankCreds();
    try {
        Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, "NEEDS_REBOOTSTRAP");
        Application.Storage.setValue(StorageKeys.KEY_GRANT_STRIKES, 2);
        var tm = new TokenManager();
        var cap = new _BoolCapture();
        // Blanked creds -> the forced refresh reaches _refreshToken and bails to UNCONFIGURED;
        // ensureValidToken would have short-circuited on NEEDS_REBOOTSTRAP without touching it.
        tm.retryAfterRebootstrap(cap.method(:onResult));
        Test.assertEqualMessage(tm.getTokenState(), "UNCONFIGURED", "guard bypassed");
        // The strike reset is deferred to dispatch (see testToken_abortedAttemptLeavesStateAlone),
        // so a credential-less attempt leaves the ledger where it was.
        Test.assertEqualMessage(
            Application.Storage.getValue(StorageKeys.KEY_GRANT_STRIKES), 2, "ledger untouched");
    } finally {
        _restoreCreds(prev);
        _resetStorage();
    }
    return true;
}

// A 401 on a data call must invalidate the cached expiry — nothing else would force a
// refresh, since ensureValidToken trusts KEY_ACCESS_EXPIRY.
(:test)
function testToken_invalidateAccessTokenDropsExpiry(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_ACCESS_EXPIRY, Time.now().value() + 3600);
    TokenManager.invalidateAccessToken();
    Test.assertMessage(
        Application.Storage.getValue(StorageKeys.KEY_ACCESS_EXPIRY) == null, "expiry dropped");
    _resetStorage();
    return true;
}

// ForegroundSync must tell a credential failure from a link failure: only the former
// may send the user to pairing. This is the classification the pages branch on.
(:test)
function testSync_classifiesFailure(logger as Test.Logger) as Lang.Boolean {
    var authStates = ["UNCONFIGURED", "NEEDS_REBOOTSTRAP"];
    for (var i = 0; i < authStates.size(); i++) {
        _resetStorage();
        Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, authStates[i]);
        var fs = new ForegroundSync();
        fs._finish(false);
        Test.assertMessage(fs.authFailed(), authStates[i] + " -> auth failure");
    }
    // NORMAL / NEEDS_REFRESH / null all mean the credentials are fine and the link isn't.
    var linkStates = ["NORMAL", "NEEDS_REFRESH"];
    for (var j = 0; j < linkStates.size(); j++) {
        _resetStorage();
        Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, linkStates[j]);
        var fs2 = new ForegroundSync();
        fs2._finish(false);
        Test.assertMessage(!fs2.authFailed(), linkStates[j] + " -> transient, not auth");
    }
    _resetStorage();
    var fs3 = new ForegroundSync();
    fs3._finish(false);
    Test.assertMessage(!fs3.authFailed(), "null state (first-run refresh) -> transient");
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
    Test.assertEqualMessage(g["lastUpdated"], 1000, "lastUpdated projected");
    Test.assertMessage(!g.hasKey("lat"), "heavy lat excluded");
    Test.assertMessage(!g.hasKey("tyrePressureFL"), "tyre field excluded");
    // fuelLitres is BMW's stale last-refuel value; the glance derives litres from
    // fuelPercent via FuelMath instead, so it must not be projected.
    Test.assertMessage(!g.hasKey("fuelLitres"), "stale fuelLitres excluded");
    Test.assertEqualMessage(g.size(), 4, "only the 4 glance fields");
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

// Blanks the credential Settings so a TokenManager refresh bails out at its creds
// check instead of dispatching a real web request from a unit test (the sim's
// settings store supplies non-empty defaults for both). Returns the previous values.
function _blankCreds() {
    var prev = [Application.Properties.getValue("clientId"),
                Application.Properties.getValue("refreshToken")];
    Application.Properties.setValue("clientId", "");
    Application.Properties.setValue("refreshToken", "");
    return prev;
}

// MUST be called from a `finally`: an assertion that throws between _blankCreds() and
// here leaves both Settings blanked for every later test AND every later sim session,
// and the next _blankCreds() then captures "" as the value to "restore" — the damage
// becomes permanent.
function _restoreCreds(prev) {
    if (prev[0] != null) { Application.Properties.setValue("clientId", prev[0]); }
    if (prev[1] != null) { Application.Properties.setValue("refreshToken", prev[1]); }
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
        "vehicle.cabin.infotainment.navigation.currentLocation.latitude"    => { "value" => "48.137",         "timestamp" => ts, "unit" => "degrees" },
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

// ============================================================
//  Map page — build-variant page slot and visibility gate
//  (:mapPage) so these compile out on map-incapable devices along
//  with PageMap itself; otherwise the (:test) build would dangle.
// ============================================================

(:test, :mapPage)
function testMapPage_pageCountIncludesMapSlot(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(PageNav._pageCount(), 5,
        "map-capable build must expose 5 carousel slots");
    return true;
}

(:test, :mapPage)
function testMapPage_visibilityRequiresBothCoordinates(logger as Test.Logger) as Lang.Boolean {
    var page = new PageMap();

    VehicleCache.replace({ "lastUpdated" => 1000 });
    Test.assertMessage(!page.isVisible(), "no coords -> hidden");

    VehicleCache.replace({ "lastUpdated" => 1000, "lat" => 48.137 });
    Test.assertMessage(!page.isVisible(), "lat without lon -> hidden");

    VehicleCache.replace({ "lastUpdated" => 1000, "lon" => 11.576 });
    Test.assertMessage(!page.isVisible(), "lon without lat -> hidden");

    VehicleCache.replace({ "lastUpdated" => 1000, "lat" => 48.137, "lon" => 11.576 });
    Test.assertMessage(page.isVisible(), "both coords -> visible");

    _resetStorage();
    return true;
}

// ============================================================
//  DeviceAuthManager — auth error text
//  The watch has room for a short, actionable line; BMW answers a
//  refused scope with the RFC 6749 boilerplate. Guards the mapping
//  and the length cap AuthView's un-clipped word-wrap depends on.
// ============================================================

(:test)
function testAuth_errorTextIsActionableAndFits(logger as Test.Logger) as Lang.Boolean {
    // A portal permission switched off arrives as invalid_request + boilerplate
    // (observed 2026-08-17 with "CarData API access" disabled).
    var rfcBoilerplate = "The request is missing a required parameter, includes an "
        + "unsupported parameter value (other than grant type), repeats a parameter, "
        + "includes multiple credentials, utilizes more than one mechanism for "
        + "authenticating the client, or is otherwise malformed.";
    var msg = DeviceAuthManager._serverError(400, {
        "error" => "invalid_request", "error_description" => rfcBoilerplate });
    Test.assertMessage(msg.find("CarData API") != null, "points at the portal switches");
    Test.assertMessage(msg.length() <= DeviceAuthManager._MSG_MAX, "fits the screen");

    // Unmapped code -> BMW's own words, capped so they can't run off the bezel.
    var unknown = DeviceAuthManager._serverError(400, {
        "error" => "some_new_code", "error_description" => rfcBoilerplate });
    Test.assertMessage(unknown.length() <= DeviceAuthManager._MSG_MAX, "long text capped");

    // Error code with no description at all still says something.
    var bare = DeviceAuthManager._serverError(400, { "error" => "some_new_code" });
    Test.assertEqualMessage(bare, "some_new_code", "falls back to the raw code");

    // No body = transport failure -> the friendly HTTP mapping, not an OAuth hint.
    Test.assertEqualMessage(DeviceAuthManager._serverError(429, null),
        "Daily limit reached", "429 without a body");
    return true;
}
