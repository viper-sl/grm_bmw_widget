// BMW CarData REST API client — LEAN (:background) steady-state poll ONLY.
// Cold-start / maintenance calls (VIN discovery, container create/list/delete,
// basicData, tyre diagnosis) live in the foreground-only CarDataBootstrap class so
// they do NOT load into the small background image (the bg process loads whole
// classes). That separation frees enough background heap for the telematicData
// response to deserialize without `-403 NETWORK_RESPONSE_OUT_OF_MEMORY`.
// MANDATORY: x-version: v1 header on ALL requests to api-cardata.bmwgroup.com.
// All builds use the live API (no mock layer); MockData exists for unit tests only.
// Parse-and-discard: raw JSON is never stored; typed state dict is returned.
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

(:background)
class CarDataClient {

    static const _DATA_HOST = "https://api-cardata.bmwgroup.com";
    // Container names (stamped on create; the cached*ContainerId() helpers compare
    // against these to detect a version bump). Container create/list lives in
    // CarDataBootstrap. The FULL container is the foreground's (all 39 descriptors,
    // incl. About-car detail); the BG container is the lean page-field set the
    // background polls so its response fits the ~28 KB background heap.
    static const _CONTAINER_NAME    = "grm_bmw_widget_v3";
    // v3: the LIVE/event-driven page fields (lock, doors, trunk, hood, windows, range,
    // fuel) — kept small enough to fit the ~28 KB background heap. Slow/static fields
    // (tyres, odometer, service, About-car) are left to the manual/daily full fetch.
    // Bumping the name forces re-creation with the new descriptor set.
    static const _BG_CONTAINER_NAME = "grm_bmw_widget_bg_v3";

    var _callback;
    var _maxTs;      // parse-time accumulator: max epoch seconds across all fields
    var _tsMemoStr;  // last timestamp string seen this parse (1-entry memo)
    var _tsMemoEpoch;// its epoch — most descriptors in one response share a timestamp

    // --- Telematic Data (main poll, every 40 min) ---

    function fetchTelematicData(vin, containerId, accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            _DATA_HOST + "/customers/vehicles/" + vin + "/telematicData?containerId=" + containerId,
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => _buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onTelematicDataResponse)
        );
    }

    function onTelematicDataResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        if (responseCode == 200 && data != null) {
            var state = _parseTelematicData(data);
            data = null;
            _callback.invoke(responseCode, state);
        } else {
            var rc = isRateLimit(responseCode, data) ? 429 : responseCode;
            data = null;
            _callback.invoke(rc, null);
        }
    }

    // --- Container id cache (shared with CarDataBootstrap, which writes via _storeContainer) ---

    // Cache the container id stamped with the name it was created/matched under,
    // so cachedContainerId() can detect a version bump later.
    static function _storeContainer(cid) {
        Application.Storage.setValue(StorageKeys.KEY_CONTAINER_ID, cid);
        Application.Storage.setValue(StorageKeys.KEY_CONTAINER_NAME, _CONTAINER_NAME);
    }

    // Returns the cached container id, or null after invalidating it if it was
    // stored under a different container name (older widget version). Without
    // this, a stale v1 id short-circuits discovery and the v2 container — with
    // its expanded descriptor set — would never be created for existing installs.
    static function cachedContainerId() {
        var cid = Application.Storage.getValue(StorageKeys.KEY_CONTAINER_ID);
        if (cid == null) { return null; }
        var name = Application.Storage.getValue(StorageKeys.KEY_CONTAINER_NAME);
        if (name == null || !name.equals(_CONTAINER_NAME)) {
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_NAME);
            return null;
        }
        return cid;
    }

    // Background (lean) container — same stamp-and-invalidate scheme as the full one.
    static function _storeBgContainer(cid) {
        Application.Storage.setValue(StorageKeys.KEY_BG_CONTAINER_ID, cid);
        Application.Storage.setValue(StorageKeys.KEY_BG_CONTAINER_NAME, _BG_CONTAINER_NAME);
    }

    static function cachedBgContainerId() {
        var cid = Application.Storage.getValue(StorageKeys.KEY_BG_CONTAINER_ID);
        if (cid == null) { return null; }
        var name = Application.Storage.getValue(StorageKeys.KEY_BG_CONTAINER_NAME);
        if (name == null || !name.equals(_BG_CONTAINER_NAME)) {
            Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_ID);
            Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_NAME);
            return null;
        }
        return cid;
    }

    // --- Shared helpers ---

    // BMW signals its daily rate limit as HTTP 403 with body exveErrorId == "CU-429"
    // (NOT HTTP 429). Normalize both to 429 so callers have one "rate limited" signal.
    static function isRateLimit(rc, data) {
        if (rc == 429) { return true; }
        if (rc != 403) { return false; }
        if (data instanceof Lang.Dictionary && data.hasKey("exveErrorId")) {
            var id = data["exveErrorId"];
            // A readable body names the cause. CU-124 (container cap) is a 403 too and
            // is NOT a rate limit — isContainerCapError handles it.
            return (id != null && id.equals("CU-429"));
        }
        // No readable body — and a bodyless 403 must NOT be read as the daily limit.
        // The likelier cause on a container-scoped call is a container this client
        // cannot use (one created under a previous clientId; re-pairing does not touch
        // the cached ids, which is why re-pairing alone left the widget on 403 while
        // signing out fixed it). Calling that a quota block would arm a 24-hour gate
        // over a problem one re-discovery fixes. ForegroundSync._stop403 escalates
        // instead: re-discover once, and only treat a SECOND 403 as the limit.
        return false;
    }

    // Drop the cached container ids so the next sync re-lists (and re-creates if
    // needed). Containers belong to the client that created them, so a new grant may
    // not be able to use them at all.
    static function invalidateContainers() {
        Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_ID);
        Application.Storage.deleteValue(StorageKeys.KEY_CONTAINER_NAME);
        Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_ID);
        Application.Storage.deleteValue(StorageKeys.KEY_BG_CONTAINER_NAME);
    }

    // Container-create rejected because the BMW account is at its container cap:
    // HTTP 403 with body exveErrorId == "CU-124" ("Maximum number of containers
    // reached") — confirmed live 2026-06-19. Distinct from CU-429 (rate limit, also
    // HTTP 403, normalized by isRateLimit first) and from a bad descriptor (CU-401).
    // Onboarding offers "delete all containers and retry" only for this.
    static function isContainerCapError(rc, data) {
        if (rc == 403 && data instanceof Lang.Dictionary && data.hasKey("exveErrorId")) {
            var id = data["exveErrorId"];
            return (id != null && id.equals("CU-124"));
        }
        return false;
    }

    // DELETE issued for a container already pending deletion: error body exveErrorId
    // == "CU-122" ("Container already set for deletion"). Deletion is async, so a re-list
    // can still return it; deleting again gives CU-122. It's effectively gone, so callers
    // treat this as a successful delete. Confirmed live 2026-06-19.
    static function isAlreadyDeleting(data) {
        if (data instanceof Lang.Dictionary && data.hasKey("exveErrorId")) {
            var id = data["exveErrorId"];
            return (id != null && id.equals("CU-122"));
        }
        return false;
    }

    static function _buildHeaders(accessToken) {
        return {
            "Authorization" => "Bearer " + accessToken,
            "x-version"     => "v1",
            "Accept"        => "application/json"
        };
    }

    // Parse telematicData response → typed Vehicle State Dictionary.
    // Rules: strings cast to typed values; null → omit; kPa→bar; lastUpdated=max(epoch).
    function _parseTelematicData(raw) {
        _maxTs = 0;          // epoch seconds accumulator
        _tsMemoStr = null;   // reset the per-parse timestamp memo
        var state = {};
        var td = raw["telematicData"];
        if (td == null) { raw = null; return state; }

        // Lock status — only enum field that needs bespoke mapping.
        var e = td["vehicle.cabin.door.lock.status"];
        if (e != null) {
            var v = e["value"];
            if (v != null) {
                if (v.equals("SECURED") || v.equals("LOCKED")) {
                    state["doorsLocked"] = true;
                } else if (v.equals("UNLOCKED") || v.equals("SELECTIVE-LOCKED")) {
                    state["doorsLocked"] = false;
                } // INVALID/UNKNOWN → omit doorsLocked
                _updateMaxTs(e["timestamp"]);
            }
        }

        // Plain numeric / string fields (shared helpers — no per-field boilerplate).
        _parseNumVal(td, "vehicle.drivetrain.lastRemainingRange",            state, "rangeKm");
        _parseNumVal(td, "vehicle.drivetrain.fuelSystem.level",              state, "fuelPercent");
        _parseNumVal(td, "vehicle.drivetrain.fuelSystem.remainingFuel",      state, "fuelLitres");
        _parseNumVal(td, "vehicle.vehicle.travelledDistance",               state, "odometerKm");
        _parseNumVal(td, "vehicle.status.serviceDistance.next",              state, "serviceDistanceKm");
        _parseStrVal(td, "vehicle.cabin.infotainment.displayUnit.distance",  state, "displayUnit");

        // Doors / trunk / hood: OPEN -> true, anything else -> false; absent -> omit.
        _parseOpenState(td, "vehicle.cabin.door.row1.driver.isOpen",    state, "doorFLOpen");
        _parseOpenState(td, "vehicle.cabin.door.row1.passenger.isOpen", state, "doorFROpen");
        _parseOpenState(td, "vehicle.cabin.door.row2.driver.isOpen",    state, "doorRLOpen");
        _parseOpenState(td, "vehicle.cabin.door.row2.passenger.isOpen", state, "doorRROpen");
        _parseOpenState(td, "vehicle.body.trunk.isOpen",                state, "trunkOpen");
        _parseOpenState(td, "vehicle.body.hood.isOpen",                 state, "hoodOpen");

        // Ignition (engine.isIgnitionOn) intentionally NOT parsed: it never populates
        // on this vehicle/account, even engine-on and while moving (B10, dropped in v3).

        // About-car telematics (grouped read-only menu — not on any page).
        _parseFloatVal(td, "vehicle.electricalSystem.battery.voltage",                      state, "batteryVoltage");
        _parseNumVal(td,   "vehicle.drivetrain.internalCombustionEngine.engine.ect",        state, "coolantC");
        _parseNumVal(td,   "vehicle.drivetrain.totalRemainingRange",                        state, "totalRangeKm");
        _parseNumVal(td,   "vehicle.status.conditionBasedServicesCount",                    state, "cbsCount");
        _parseNumVal(td,   "vehicle.status.serviceDistance.yellow",                         state, "serviceYellowKm");
        _parseBoolVal(td,  "vehicle.vehicle.deepSleepModeActive",                           state, "deepSleep");
        _parseStrVal(td,   "vehicle.vehicle.preConditioning.activity",                      state, "preconditioning");
        _parseStrVal(td,   "vehicle.channel.teleservice.status",                            state, "teleservice");
        _parseFloatVal(td, "vehicle.cabin.infotainment.navigation.currentLocation.latitude",  state, "lat");
        _parseFloatVal(td, "vehicle.cabin.infotainment.navigation.currentLocation.longitude", state, "lon");
        _parseNumVal(td,   "vehicle.cabin.infotainment.navigation.currentLocation.altitude",   state, "altitudeM");
        _parseNumVal(td,   "vehicle.cabin.infotainment.navigation.currentLocation.heading",    state, "headingDeg");

        // F16 multi-powertrain: electric range + HV state-of-charge (BEV/PHEV; null on ICE).
        _parseNumVal(td, "vehicle.drivetrain.electricEngine.kombiRemainingElectricRange", state, "electricRangeKm");
        _parseNumVal(td, "vehicle.powertrain.electric.battery.stateOfCharge.displayed",   state, "socPercent");

        // Window status: only OPEN -> true (open); INTERMEDIATE/CLOSED/INVALID -> false.
        // (INTERMEDIATE is the frameless-window reseat state and occurs with the door
        // fully closed — confirmed via live capture 2026-06-14, B11.)
        _parseWindowStatus(td, "vehicle.cabin.window.row1.driver.status",    state, "windowFLOpen");
        _parseWindowStatus(td, "vehicle.cabin.window.row1.passenger.status", state, "windowFROpen");
        _parseWindowStatus(td, "vehicle.cabin.window.row2.driver.status",    state, "windowRLOpen");
        _parseWindowStatus(td, "vehicle.cabin.window.row2.passenger.status", state, "windowRROpen");

        // Tyre pressures (kPa → bar = kPa / 100.0)
        _parseTyrePressure(td, "vehicle.chassis.axle.row1.wheel.left.tire.pressure",        state, "tyrePressureFL");
        _parseTyrePressure(td, "vehicle.chassis.axle.row1.wheel.right.tire.pressure",       state, "tyrePressureFR");
        _parseTyrePressure(td, "vehicle.chassis.axle.row2.wheel.left.tire.pressure",        state, "tyrePressureRL");
        _parseTyrePressure(td, "vehicle.chassis.axle.row2.wheel.right.tire.pressure",       state, "tyrePressureRR");
        _parseTyrePressure(td, "vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget",  state, "tyreTargetFL");
        _parseTyrePressure(td, "vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget", state, "tyreTargetFR");
        _parseTyrePressure(td, "vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget",  state, "tyreTargetRL");
        _parseTyrePressure(td, "vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget", state, "tyreTargetRR");

        // F16: pick the powertrain-appropriate range for `rangeKm` (the field pages render).
        // Powertrain is unknown at compile time, so select the populated field at runtime:
        // totalRemainingRange (PHEV total / ICE) → kombiRemainingElectricRange (BEV) →
        // lastRemainingRange (ICE, already in rangeKm). On this ICE car total == last.
        if (state.hasKey("totalRangeKm")) {
            state["rangeKm"] = state["totalRangeKm"];
        } else if (!state.hasKey("rangeKm") && state.hasKey("electricRangeKm")) {
            state["rangeKm"] = state["electricRangeKm"];
        }

        // lastUpdated = max epoch across all non-null fields (accumulated in _updateMaxTs)
        if (_maxTs > 0) {
            state["lastUpdated"] = _maxTs;
        }

        raw = null;
        return state;
    }

    // All parse helpers share the same shape: one td lookup, one value read, early-out
    // on absent/null (field omitted entirely), then write + bump the timestamp once.

    // Door/trunk/hood isOpen: OPEN -> true, anything else -> false.
    function _parseOpenState(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e == null) { return; }
        var v = e["value"];
        if (v == null) { return; }
        state[key] = v.equals("OPEN");
        _updateMaxTs(e["timestamp"]);
    }

    // Window status: only OPEN -> true; INTERMEDIATE/CLOSED/INVALID -> false (B11).
    function _parseWindowStatus(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e == null) { return; }
        var v = e["value"];
        if (v == null) { return; }
        state[key] = v.equals("OPEN");
        _updateMaxTs(e["timestamp"]);
    }

    // kPa tyre entry -> Float bar (kPa / 100.0).
    function _parseTyrePressure(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e == null) { return; }
        var v = e["value"];
        if (v == null) { return; }
        state[key] = v.toNumber() / 100.0;
        _updateMaxTs(e["timestamp"]);
    }

    function _parseNumVal(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e == null) { return; }
        var v = e["value"];
        if (v == null) { return; }
        state[key] = v.toNumber();
        _updateMaxTs(e["timestamp"]);
    }

    function _parseFloatVal(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e == null) { return; }
        var v = e["value"];
        if (v == null) { return; }
        state[key] = v.toFloat();
        _updateMaxTs(e["timestamp"]);
    }

    function _parseStrVal(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e == null) { return; }
        var v = e["value"];
        if (v == null) { return; }
        state[key] = v;
        _updateMaxTs(e["timestamp"]);
    }

    // Boolean-ish: real Booleans or "true"/"false" strings; anything else -> omit.
    function _parseBoolVal(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e == null) { return; }
        var v = e["value"];
        if (v == null) { return; }
        if (v instanceof Lang.Boolean)              { state[key] = v; }
        else if (v.equals("true") || v.equals("True"))   { state[key] = true; }
        else if (v.equals("false") || v.equals("False")) { state[key] = false; }
        else { return; }   // unrecognized -> don't touch maxTs
        _updateMaxTs(e["timestamp"]);
    }

    // Update _maxTs (epoch seconds) if this timestamp is newer.
    // A single telematicData response groups most fields under one snapshot timestamp,
    // so a 1-entry memo skips re-parsing the same string ~30×/parse (each parse builds
    // 6 substrings + a Gregorian dict + a Moment — pure transient garbage otherwise).
    function _updateMaxTs(ts) {
        if (ts == null) { return; }
        var epoch;
        if (ts.equals(_tsMemoStr)) {
            epoch = _tsMemoEpoch;
        } else {
            epoch = _parseIso8601(ts);
            _tsMemoStr = ts;
            _tsMemoEpoch = epoch;
        }
        if (epoch > _maxTs) { _maxTs = epoch; }
    }

    // Convert ISO8601 UTC string "2026-05-27T17:53:20Z" → epoch seconds.
    static function _parseIso8601(ts) {
        if (ts == null || ts.length() < 19) { return 0; }
        var moment = Time.Gregorian.moment({
            :year   => ts.substring(0, 4).toNumber(),
            :month  => ts.substring(5, 7).toNumber(),
            :day    => ts.substring(8, 10).toNumber(),
            :hour   => ts.substring(11, 13).toNumber(),
            :minute => ts.substring(14, 16).toNumber(),
            :second => ts.substring(17, 19).toNumber()
        });
        return moment.value();
    }

}
