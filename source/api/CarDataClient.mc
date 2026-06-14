// BMW CarData REST API client.
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
            data = null;
            _callback.invoke(responseCode, null);
        }
    }

    // --- Basic Data (bootstrap only — called once from ServiceDelegate Phase 1) ---

    function fetchBasicData(vin, accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            _DATA_HOST + "/customers/vehicles/" + vin + "/basicData",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => _buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onBasicDataResponse)
        );
    }

    function onBasicDataResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        if (responseCode == 200 && data != null) {
            var brand = (data.hasKey("brand") && data["brand"] != null) ? data["brand"] : "BMW";
            var model = (data.hasKey("modelName") && data["modelName"] != null) ? data["modelName"] : "";
            Application.Storage.setValue(StorageKeys.KEY_VEHICLE_NAME, brand + " " + model);
            var drive = (data.hasKey("driveTrain") && data["driveTrain"] != null) ? data["driveTrain"] : "CONV";
            Application.Storage.setValue(StorageKeys.KEY_DRIVE_TYPE, drive);
            // Full basicData snapshot for the on-watch "About car" key/value list.
            // Stored as one dict (string values) so AboutMenu can render it generically.
            var about = {};
            var keys = data.keys();
            for (var i = 0; i < keys.size(); i++) {
                var k = keys[i];
                var v = data[k];
                if (v != null) { about[k] = v.toString(); }
            }
            Application.Storage.setValue(StorageKeys.KEY_BASIC_DATA, about);
        }
        data = null;
        _callback.invoke(responseCode, null);
    }

    // --- Tyre Diagnosis (best-effort, separate endpoint, no container needed) ---

    function fetchTyreDiagnosis(vin, accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            _DATA_HOST + "/customers/vehicles/" + vin + "/smartMaintenanceTyreDiagnosis",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => _buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onTyreDiagnosisResponse)
        );
    }

    function onTyreDiagnosisResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        var result = {};
        if (responseCode == 200 && data != null) {
            var car     = data.hasKey("passengerCar")   ? data["passengerCar"]   : null;
            var mounted = (car != null && car.hasKey("mountedTyres")) ? car["mountedTyres"] : null;
            if (mounted != null) {
                _parseTyreKm(mounted, "frontLeft",  result, "tyreWearKmFL");
                _parseTyreKm(mounted, "frontRight", result, "tyreWearKmFR");
                _parseTyreKm(mounted, "rearLeft",   result, "tyreWearKmRL");
                _parseTyreKm(mounted, "rearRight",  result, "tyreWearKmRR");
            }
        }
        data = null;
        _callback.invoke(responseCode, result);
    }

    function _parseTyreKm(mounted, position, result, key) {
        var pos  = mounted.hasKey(position) ? mounted[position] : null;
        if (pos == null) { return; }
        var wear = pos.hasKey("tyreWear") ? pos["tyreWear"] : null;
        if (wear == null) { return; }
        var km   = wear.hasKey("dueMileage") ? wear["dueMileage"] : null;
        if (km != null && km > 0) { result[key] = km.toNumber(); }
    }

    // --- VIN discovery (GET /customers/vehicles/mappings) ---
    // Auto-learns the user's VIN after auth so it need not be entered manually.

    // typecheck off: makeWebRequest's callback type names PersistedContent.Iterator,
    // whose permission is unsupported on fenix 6 (adding it makes the watch refuse to
    // run the widget). We don't name that type anywhere; suppress the check here.
    (:typecheck(false))
    function fetchMappings(accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            _DATA_HOST + "/customers/vehicles/mappings",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => _buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onMappingsResponse)
        );
    }

    // Picks the PRIMARY VIN (or the first) and stores it. Returns vin via callback.
    // The /mappings body is a JSON array; makeWebRequest may surface it as a Lang.Array,
    // wrapped as {"data":[...]}, or (top-level array) an iterator. We type the param as
    // Lang.Object to AVOID naming PersistedContent.Iterator (that permission is not
    // supported on fenix 6 and made the watch silently refuse to run the widget).
    (:typecheck(false))
    function onMappingsResponse(responseCode, data) {
        var vin = null;
        if (responseCode == 200 && data != null) {
            var list = data;
            if (data instanceof Lang.Dictionary) {
                list = data.hasKey("data") ? data["data"] : null;
            }
            if (list instanceof Lang.Array) {
                vin = _vinFromArray(list);
            } else if (list != null) {
                // Iterator-like: pull entries via next() without naming the type.
                vin = _vinFromIterator(list);
            }
        }
        if (vin != null) { Application.Storage.setValue(StorageKeys.KEY_VIN, vin); }
        data = null;
        _callback.invoke(responseCode, vin);
    }

    function _pickVin(e, firstSoFar) {
        // returns [first, primaryOrNull] for one entry
        if (e instanceof Lang.Dictionary && e["vin"] != null) {
            var mt = e["mappingType"];
            var isPrimary = (mt != null && mt.equals("PRIMARY"));
            return [ (firstSoFar == null) ? e["vin"] : firstSoFar, isPrimary ? e["vin"] : null ];
        }
        return [ firstSoFar, null ];
    }

    function _vinFromArray(arr) {
        var first = null;
        for (var i = 0; i < arr.size(); i++) {
            var r = _pickVin(arr[i], first);
            first = r[0];
            if (r[1] != null) { return r[1]; }
        }
        return first;
    }

    // Duck-typed iterator walk (PersistedContent.Iterator has next()).
    function _vinFromIterator(it) {
        var first = null;
        try {
            var e = it.next();
            while (e != null) {
                var r = _pickVin(e, first);
                first = r[0];
                if (r[1] != null) { return r[1]; }
                e = it.next();
            }
        } catch (ex) {
            // not iterable — give up gracefully
        }
        return first;
    }

    // --- Container creation (POST /customers/containers) ---
    // Body shape (verified): { name, purpose, technicalDescriptors:[...] }.
    // technicalDescriptors is a FLAT array of dotted strings (not objects).

    static const _CONTAINER_NAME = "grm_bmw_widget_v3";

    // List existing containers; reuse ours (match by name) if present.
    // GET /customers/containers -> {"data":{"containers":[ {id|containerId, name, ...} ]}}.

    function fetchContainers(accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            _DATA_HOST + "/customers/containers",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => _buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onContainersResponse)
        );
    }

    // Returns an existing container id (name match ONLY) or null via callback.
    // Containers under other names — including this widget's own older versions —
    // must NOT be reused: the A3 migration relies on a no-match here so the
    // caller falls through to createContainer with the current descriptor set.
    function onContainersResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        var cid = null;
        if (responseCode == 200 && data != null) {
            var d = data.hasKey("data") ? data["data"] : data;
            var list = (d instanceof Lang.Dictionary && d.hasKey("containers")) ? d["containers"] : null;
            if (list instanceof Lang.Array) {
                for (var i = 0; i < list.size(); i++) {
                    var c = list[i];
                    if (c instanceof Lang.Dictionary) {
                        var id = c.hasKey("containerId") ? c["containerId"]
                               : (c.hasKey("id") ? c["id"] : null);
                        var nm = c["name"];
                        if (id != null && nm != null && nm.equals(_CONTAINER_NAME)) {
                            cid = id;
                            break;
                        }
                    }
                }
            }
        }
        if (cid != null) { _storeContainer(cid); }
        data = null;
        _callback.invoke(responseCode, cid);
    }

    function createContainer(accessToken, callback) {
        _callback = callback;
        // JSON POST: Content-Type must be set via the REQUEST_CONTENT_TYPE_JSON enum in
        // :headers (a raw "Content-Type" string yields -200 INVALID_HTTP_HEADER_FIELDS).
        // CIQ then JSON-encodes the Dictionary body.
        Communications.makeWebRequest(
            _DATA_HOST + "/customers/containers",
            {
                "name"                 => _CONTAINER_NAME,
                "purpose"              => "Garmin fenix widget status",
                "technicalDescriptors" => _containerDescriptors()
            },
            { :method       => Communications.HTTP_REQUEST_METHOD_POST,
              :headers      => {
                  "Authorization"               => "Bearer " + accessToken,
                  "x-version"                   => "v1",
                  "Accept"                      => "application/json",
                  "Content-Type"                => Communications.REQUEST_CONTENT_TYPE_JSON
              },
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onCreateContainerResponse)
        );
    }

    function onCreateContainerResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        var cid = null;
        if ((responseCode == 200 || responseCode == 201) && data != null) {
            cid = data.hasKey("containerId") ? data["containerId"]
                : (data.hasKey("id") ? data["id"] : null);
            if (cid != null) { _storeContainer(cid); }
        }
        data = null;
        _callback.invoke(responseCode, cid);
    }

    // --- Container delete (F14, DELETE /customers/containers/{id}, verified 200) ---

    function deleteContainer(containerId, accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            _DATA_HOST + "/customers/containers/" + containerId,
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_DELETE,
              :headers      => _buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onDeleteContainerResponse)
        );
    }

    function onDeleteContainerResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        data = null;
        _callback.invoke(responseCode, null);
    }

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

    // The 39 descriptors the widget reads (ICE 218i, container v3).
    // v3 vs v2: dropped engine.isIgnitionOn (never populates on this vehicle — B10),
    // added the 12 telematics fields surfaced in the grouped "About car" menu plus
    // hvac.statusAirPurification (subscribed for a future feature, not yet parsed).
    static function _containerDescriptors() {
        return [
            "vehicle.cabin.door.lock.status",
            "vehicle.cabin.door.row1.driver.isOpen",
            "vehicle.cabin.door.row1.passenger.isOpen",
            "vehicle.cabin.door.row2.driver.isOpen",
            "vehicle.cabin.door.row2.passenger.isOpen",
            "vehicle.body.trunk.isOpen",
            "vehicle.body.trunk.isLocked",
            "vehicle.body.hood.isOpen",
            "vehicle.drivetrain.lastRemainingRange",
            "vehicle.drivetrain.fuelSystem.level",
            "vehicle.drivetrain.fuelSystem.remainingFuel",
            "vehicle.vehicle.travelledDistance",
            "vehicle.status.serviceDistance.next",
            "vehicle.cabin.infotainment.displayUnit.distance",
            "vehicle.cabin.window.row1.driver.status",
            "vehicle.cabin.window.row1.passenger.status",
            "vehicle.cabin.window.row2.driver.status",
            "vehicle.cabin.window.row2.passenger.status",
            "vehicle.chassis.axle.row1.wheel.left.tire.pressure",
            "vehicle.chassis.axle.row1.wheel.right.tire.pressure",
            "vehicle.chassis.axle.row2.wheel.left.tire.pressure",
            "vehicle.chassis.axle.row2.wheel.right.tire.pressure",
            "vehicle.chassis.axle.row1.wheel.left.tire.pressureTarget",
            "vehicle.chassis.axle.row1.wheel.right.tire.pressureTarget",
            "vehicle.chassis.axle.row2.wheel.left.tire.pressureTarget",
            "vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget",
            // About-car telematics (v3)
            "vehicle.electricalSystem.battery.voltage",
            "vehicle.drivetrain.internalCombustionEngine.engine.ect",
            "vehicle.drivetrain.totalRemainingRange",
            "vehicle.status.conditionBasedServicesCount",
            "vehicle.status.serviceDistance.yellow",
            "vehicle.vehicle.deepSleepModeActive",
            "vehicle.vehicle.preConditioning.activity",
            "vehicle.channel.teleservice.status",
            "vehicle.cabin.infotainment.navigation.currentLocation.latitude",
            "vehicle.cabin.infotainment.navigation.currentLocation.longitude",
            "vehicle.cabin.infotainment.navigation.currentLocation.altitude",
            "vehicle.cabin.infotainment.navigation.currentLocation.heading",
            // F16 multi-powertrain: electric range + HV state-of-charge (null on this ICE
            // car, populated on BEV/PHEV — the parser runtime-selects the live field).
            "vehicle.drivetrain.electricEngine.kombiRemainingElectricRange",
            "vehicle.powertrain.electric.battery.stateOfCharge.displayed",
            // Subscribed for a future air-purification feature; intentionally not parsed yet.
            "vehicle.cabin.hvac.statusAirPurification"
        ];
    }

    // --- Shared helpers ---

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
