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
    var _maxTs; // parse-time accumulator: max epoch seconds across all fields

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

    static const _CONTAINER_NAME = "grm_bmw_widget_v2";

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

    // The 27 descriptors the widget reads (ICE 218i, container v2).
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
            "vehicle.drivetrain.engine.isIgnitionOn",
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
            "vehicle.chassis.axle.row2.wheel.right.tire.pressureTarget"
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
        _maxTs = 0; // epoch seconds accumulator
        var state = {};
        var td = raw["telematicData"];
        if (td == null) { raw = null; return state; }

        var e;

        // Lock status
        e = td["vehicle.cabin.door.lock.status"];
        if (e != null && e["value"] != null) {
            var v = e["value"];
            if (v.equals("SECURED") || v.equals("LOCKED")) {
                state["doorsLocked"] = true;
            } else if (v.equals("UNLOCKED") || v.equals("SELECTIVE-LOCKED")) {
                state["doorsLocked"] = false;
            } // INVALID/UNKNOWN → omit doorsLocked
            _updateMaxTs(e["timestamp"]);
        }

        // Range (ICE only — "only for combustion cars")
        e = td["vehicle.drivetrain.lastRemainingRange"];
        if (e != null && e["value"] != null) {
            state["rangeKm"] = e["value"].toNumber();
            _updateMaxTs(e["timestamp"]);
        }

        // Fuel %
        e = td["vehicle.drivetrain.fuelSystem.level"];
        if (e != null && e["value"] != null) {
            state["fuelPercent"] = e["value"].toNumber();
            _updateMaxTs(e["timestamp"]);
        }

        // Fuel litres
        e = td["vehicle.drivetrain.fuelSystem.remainingFuel"];
        if (e != null && e["value"] != null) {
            state["fuelLitres"] = e["value"].toNumber();
            _updateMaxTs(e["timestamp"]);
        }

        // Doors / trunk / hood: OPEN -> true, anything else -> false; absent -> omit.
        _parseOpenState(td, "vehicle.cabin.door.row1.driver.isOpen",    state, "doorFLOpen");
        _parseOpenState(td, "vehicle.cabin.door.row1.passenger.isOpen", state, "doorFROpen");
        _parseOpenState(td, "vehicle.cabin.door.row2.driver.isOpen",    state, "doorRLOpen");
        _parseOpenState(td, "vehicle.cabin.door.row2.passenger.isOpen", state, "doorRROpen");
        _parseOpenState(td, "vehicle.body.trunk.isOpen",                state, "trunkOpen");
        _parseOpenState(td, "vehicle.body.hood.isOpen",                 state, "hoodOpen");

        // Odometer
        e = td["vehicle.vehicle.travelledDistance"];
        if (e != null && e["value"] != null) {
            state["odometerKm"] = e["value"].toNumber();
            _updateMaxTs(e["timestamp"]);
        }

        // Service distance (unit null in response → infer km)
        e = td["vehicle.status.serviceDistance.next"];
        if (e != null && e["value"] != null) {
            state["serviceDistanceKm"] = e["value"].toNumber();
            _updateMaxTs(e["timestamp"]);
        }

        // Display unit (km / miles)
        e = td["vehicle.cabin.infotainment.displayUnit.distance"];
        if (e != null && e["value"] != null) {
            state["displayUnit"] = e["value"];
            _updateMaxTs(e["timestamp"]);
        }

        // Engine running (ignition). Value format unconfirmed (OQ-2) — accept plain
        // booleans/strings or ASN_isTrue/ASN_isFalse enum strings; ASN_isUnknown/other -> omit.
        e = td["vehicle.drivetrain.engine.isIgnitionOn"];
        if (e != null && e["value"] != null) {
            var ign = e["value"];
            if (ign instanceof Lang.Boolean) {
                state["engineRunning"] = ign;
                _updateMaxTs(e["timestamp"]);
            } else if (ign.equals("true") || ign.equals("True") || ign.equals("ASN_isTrue")) {
                state["engineRunning"] = true;
                _updateMaxTs(e["timestamp"]);
            } else if (ign.equals("false") || ign.equals("False") || ign.equals("ASN_isFalse")) {
                state["engineRunning"] = false;
                _updateMaxTs(e["timestamp"]);
            } // ASN_isUnknown / other -> omit
        }

        // Window status: OPEN/INTERMEDIATE -> true (open), CLOSED/INVALID -> false.
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

        // lastUpdated = max epoch across all non-null fields (accumulated in _updateMaxTs)
        if (_maxTs > 0) {
            state["lastUpdated"] = _maxTs;
        }

        raw = null;
        return state;
    }

    // Parse a door/trunk/hood isOpen entry: OPEN -> true, anything else -> false.
    // Absent descriptor (e.g. row2 doors not in this vehicle's catalog, OQ-4) -> omit.
    function _parseOpenState(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e != null && e["value"] != null) {
            state[key] = e["value"].equals("OPEN");
            _updateMaxTs(e["timestamp"]);
        }
    }

    // Parse a window status entry: OPEN/INTERMEDIATE -> true, CLOSED/INVALID -> false.
    // Absent descriptor (e.g. not in this vehicle's catalog, OQ-4) -> omit entirely.
    function _parseWindowStatus(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e != null && e["value"] != null) {
            var v = e["value"];
            state[key] = v.equals("OPEN") || v.equals("INTERMEDIATE");
            _updateMaxTs(e["timestamp"]);
        }
    }

    // Parse a kPa tyre entry; convert to Float bar; update _maxTs.
    function _parseTyrePressure(td, descriptor, state, key) {
        var e = td[descriptor];
        if (e != null && e["value"] != null) {
            state[key] = e["value"].toNumber() / 100.0;
            _updateMaxTs(e["timestamp"]);
        }
    }

    // Update _maxTs (epoch seconds) if this timestamp is newer.
    // Monkey C strings have no compareTo — convert to epoch and compare numbers.
    function _updateMaxTs(ts) {
        if (ts == null) { return; }
        var epoch = _parseIso8601(ts);
        if (epoch > _maxTs) {
            _maxTs = epoch;
        }
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
