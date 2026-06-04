// BMW CarData REST API client.
// MANDATORY: x-version: v1 header on ALL requests to api-cardata.bmwgroup.com.
// (:debug)/(:release) annotations control mock vs live network calls.
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

    (:release)
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

    (:debug)
    function fetchTelematicData(vin, containerId, accessToken, callback) {
        _callback = callback;
        onTelematicDataResponse(200, MockData.telematicFixture());
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

    (:release)
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

    (:debug)
    function fetchBasicData(vin, accessToken, callback) {
        _callback = callback;
        onBasicDataResponse(200, MockData.basicDataFixture());
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

    (:release)
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

    (:debug)
    function fetchTyreDiagnosis(vin, accessToken, callback) {
        _callback = callback;
        onTyreDiagnosisResponse(200, MockData.tyreDiagnosisFixture());
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
    (:release :typecheck(false))
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

    (:debug)
    function fetchMappings(accessToken, callback) {
        _callback = callback;
        onMappingsResponse(200, { "data" => [ { "vin" => "WBADEBUGVIN000001", "mappingType" => "PRIMARY" } ] });
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

    static const _CONTAINER_NAME = "grm_bmw_widget";

    // List existing containers; reuse ours (match by name) if present.
    // GET /customers/containers -> {"data":{"containers":[ {id|containerId, name, ...} ]}}.

    (:release)
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

    (:debug)
    function fetchContainers(accessToken, callback) {
        _callback = callback;
        onContainersResponse(200, { "data" => { "containers" => [] } });
    }

    // Returns an existing container id (ours by name, else first) or null via callback.
    function onContainersResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        var cid = null;
        if (responseCode == 200 && data != null) {
            var d = data.hasKey("data") ? data["data"] : data;
            var list = (d instanceof Lang.Dictionary && d.hasKey("containers")) ? d["containers"] : null;
            if (list instanceof Lang.Array) {
                var firstId = null;
                for (var i = 0; i < list.size(); i++) {
                    var c = list[i];
                    if (c instanceof Lang.Dictionary) {
                        var id = c.hasKey("containerId") ? c["containerId"]
                               : (c.hasKey("id") ? c["id"] : null);
                        if (id != null) {
                            if (firstId == null) { firstId = id; }
                            var nm = c["name"];
                            if (nm != null && nm.equals(_CONTAINER_NAME)) {
                                cid = id;              // prefer our own container
                                break;
                            }
                        }
                    }
                }
                if (cid == null) { cid = firstId; }    // else reuse any existing container
            }
        }
        if (cid != null) { Application.Storage.setValue(StorageKeys.KEY_CONTAINER_ID, cid); }
        data = null;
        _callback.invoke(responseCode, cid);
    }

    (:release)
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

    (:debug)
    function createContainer(accessToken, callback) {
        _callback = callback;
        onCreateContainerResponse(200, { "containerId" => "DEBUGCONTAINER01" });
    }

    function onCreateContainerResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        var cid = null;
        if ((responseCode == 200 || responseCode == 201) && data != null) {
            cid = data.hasKey("containerId") ? data["containerId"]
                : (data.hasKey("id") ? data["id"] : null);
            if (cid != null) { Application.Storage.setValue(StorageKeys.KEY_CONTAINER_ID, cid); }
        }
        data = null;
        _callback.invoke(responseCode, cid);
    }

    // The 21 descriptors the widget reads (ICE 218i, container v2).
    static function _containerDescriptors() {
        return [
            "vehicle.cabin.door.lock.status",
            "vehicle.cabin.door.row1.driver.isOpen",
            "vehicle.cabin.door.row1.passenger.isOpen",
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

        // Door FL
        e = td["vehicle.cabin.door.row1.driver.isOpen"];
        if (e != null && e["value"] != null) {
            state["doorFLOpen"] = e["value"].equals("OPEN");
            _updateMaxTs(e["timestamp"]);
        }

        // Door FR
        e = td["vehicle.cabin.door.row1.passenger.isOpen"];
        if (e != null && e["value"] != null) {
            state["doorFROpen"] = e["value"].equals("OPEN");
            _updateMaxTs(e["timestamp"]);
        }

        // Trunk
        e = td["vehicle.body.trunk.isOpen"];
        if (e != null && e["value"] != null) {
            state["trunkOpen"] = e["value"].equals("OPEN");
            _updateMaxTs(e["timestamp"]);
        }

        // Hood
        e = td["vehicle.body.hood.isOpen"];
        if (e != null && e["value"] != null) {
            state["hoodOpen"] = e["value"].equals("OPEN");
            _updateMaxTs(e["timestamp"]);
        }

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
