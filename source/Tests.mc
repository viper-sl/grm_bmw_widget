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
    return true;
}

(:test)
function testParse_stringPassthrough(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertEqualMessage(s["displayUnit"], "km", "displayUnit");
    return true;
}

(:test)
function testParse_kpaToBar(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(_fEq(s["tyrePressureFL"], 2.3), "FL 230kPa->2.3");
    Test.assertMessage(_fEq(s["tyrePressureRL"], 2.2), "RL 220kPa->2.2");
    Test.assertMessage(_fEq(s["tyreTargetFL"], 2.2), "target 220->2.2");
    return true;
}

(:test)
function testParse_nullOmitted(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(!s.hasKey("dataAge"), "dataAge never stored");
    // trunk.isLocked + ignitionOn are null in fixture and not mapped -> absent
    Test.assertMessage(!s.hasKey("ignitionOn"), "null ignition omitted");
    return true;
}

(:test)
function testParse_lastUpdatedIsMax(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData(_fixture());
    Test.assertMessage(s.hasKey("lastUpdated"), "lastUpdated present");
    var expected = CarDataClient._parseIso8601("2026-05-27T17:53:20Z");
    Test.assertEqualMessage(s["lastUpdated"], expected, "max ts, not older 05-24");
    return true;
}

(:test)
function testParse_emptyContainer(logger as Test.Logger) as Lang.Boolean {
    var s = new CarDataClient()._parseTelematicData({});
    Test.assertMessage(s != null, "empty -> dict not null");
    Test.assertMessage(!s.hasKey("rangeKm"), "empty -> no fields");
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
    return true;
}

(:test)
function testIso8601_malformed(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(CarDataClient._parseIso8601("bad"), 0, "short->0");
    Test.assertEqualMessage(CarDataClient._parseIso8601(null), 0, "null->0");
    return true;
}

// ============================================================
//  PageChrome.oneDecimal
// ============================================================

(:test)
function testOneDecimal(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(PageChrome.oneDecimal(2.3), "2.3", "2.3");
    Test.assertEqualMessage(PageChrome.oneDecimal(2.0), "2.0", "2.0");
    Test.assertEqualMessage(PageChrome.oneDecimal(2.25), "2.3", "round up .25->.3");
    Test.assertEqualMessage(PageChrome.oneDecimal(2.96), "3.0", "carry 2.96->3.0");
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
    // null, UNCONFIGURED, NEEDS_REBOOTSTRAP must short-circuit to callback(false).
    var states = [null, "UNCONFIGURED", "NEEDS_REBOOTSTRAP"];
    for (var i = 0; i < states.size(); i++) {
        _resetStorage();
        if (states[i] != null) {
            Application.Storage.setValue(StorageKeys.KEY_TOKEN_STATE, states[i]);
        }
        var cap = new _BoolCapture();
        new TokenManager().ensureValidToken(cap.method(:onResult));
        Test.assertMessage(cap.called, "callback fired");
        Test.assertMessage(cap.value == false, "guard state -> false");
    }
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
    return true;
}

// ============================================================
//  QuotaGuard — rate-limit gate
// ============================================================

(:test)
function testQuota_firstRunAllowed(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Test.assertMessage(QuotaGuard.canFetch(), "null gate -> allowed");
    return true;
}

(:test)
function testQuota_activeGateBlocks(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_NEXT_ALLOWED, Time.now().value() + 1000);
    Test.assertMessage(!QuotaGuard.canFetch(), "future gate -> blocked");
    return true;
}

(:test)
function testQuota_expiredGateAllows(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    Application.Storage.setValue(StorageKeys.KEY_NEXT_ALLOWED, Time.now().value() - 10);
    Test.assertMessage(QuotaGuard.canFetch(), "past gate -> allowed");
    return true;
}

(:test)
function testQuota_updateAdvancesGate(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    QuotaGuard.updateAfterFetch();
    var next = Application.Storage.getValue(StorageKeys.KEY_NEXT_ALLOWED);
    Test.assertMessage(_nearNow(next, 2400), "advances ~40min");
    return true;
}

(:test)
function testQuota_exceededBlocks24h(logger as Test.Logger) as Lang.Boolean {
    _resetStorage();
    QuotaGuard.onQuotaExceeded();
    var next = Application.Storage.getValue(StorageKeys.KEY_NEXT_ALLOWED);
    Test.assertMessage(_nearNow(next, 86400), "429 blocks ~24h");
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

function _fEq(a, b) {
    if (a == null) { return false; }
    var d = a - b;
    if (d < 0) { d = -d; }
    return d < 0.01;
}

function _fixture() {
    return { "telematicData" => {
        "vehicle.cabin.door.lock.status" => { "value" => "SECURED", "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
        "vehicle.drivetrain.lastRemainingRange" => { "value" => "653", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "km" },
        "vehicle.drivetrain.fuelSystem.level" => { "value" => "95", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "%" },
        "vehicle.drivetrain.fuelSystem.remainingFuel" => { "value" => "21", "timestamp" => "2026-05-24T12:15:23Z", "unit" => "l" },
        "vehicle.cabin.door.row1.driver.isOpen" => { "value" => "CLOSED", "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
        "vehicle.cabin.door.row1.passenger.isOpen" => { "value" => "CLOSED", "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
        "vehicle.body.trunk.isOpen" => { "value" => "CLOSED", "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
        "vehicle.body.trunk.isLocked" => { "value" => null, "timestamp" => null, "unit" => null },
        "vehicle.body.hood.isOpen" => { "value" => "CLOSED", "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
        "vehicle.vehicle.travelledDistance" => { "value" => "40926", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "km" },
        "vehicle.status.serviceDistance.next" => { "value" => "22000", "timestamp" => "2026-05-27T17:53:20Z", "unit" => null },
        "vehicle.cabin.infotainment.displayUnit.distance" => { "value" => "km", "timestamp" => "2026-05-24T12:15:23Z", "unit" => null },
        "vehicle.drivetrain.engine.isIgnitionOn" => { "value" => null, "timestamp" => null, "unit" => null },
        "vehicle.chassis.axle.row1.wheel.left.tire.pressure" => { "value" => "230", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
        "vehicle.chassis.axle.row1.wheel.right.tire.pressure" => { "value" => "230", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
        "vehicle.chassis.axle.row2.wheel.left.tire.pressure" => { "value" => "220", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
        "vehicle.chassis.axle.row2.wheel.right.tire.pressure" => { "value" => "230", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
        "vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget" => { "value" => "220", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
        "vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget" => { "value" => "220", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
        "vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget" => { "value" => "220", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" },
        "vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget" => { "value" => "220", "timestamp" => "2026-05-27T17:53:20Z", "unit" => "kPa" }
    }};
}
