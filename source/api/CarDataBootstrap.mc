// Foreground-only BMW CarData calls: cold-start + maintenance (VIN discovery,
// container list/create/delete, basicData, tyre diagnosis).
//
// Deliberately NOT (:background). The background process loads whole classes, so
// keeping this (large) code — including the 39-string descriptor array — out of the
// (:background) image is what frees enough background heap for the telematicData
// response to deserialize without `-403 NETWORK_RESPONSE_OUT_OF_MEMORY`. The lean
// steady-state poll lives in CarDataClient (:background); bootstrap is the
// foreground's job (ForegroundSync), which runs the full chain after pairing.
//
// Shared statics (_DATA_HOST, _buildHeaders, _storeContainer, _CONTAINER_NAME) stay
// in CarDataClient and are referenced here — fine, the foreground loads both classes.
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

class CarDataBootstrap {

    var _callback;
    var _matchName;    // container name to match in onContainersResponse
    var _isBgTarget;   // true → store result as the lean bg container, false → full
    var _capFailure;   // last createContainer failed with a cap-like error (not rate/auth/descriptor)

    // True when the most recent createContainer was rejected with the container cap error
    // (HTTP 403 + CU-124, "Maximum number of containers reached"). Onboarding uses this to
    // offer a "delete all containers and retry" cleanup.
    function createCapFailure() { return _capFailure == true; }

    // --- Basic Data (bootstrap — vehicle name + About-car snapshot) ---

    function fetchBasicData(vin, accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            CarDataClient._DATA_HOST + "/customers/vehicles/" + vin + "/basicData",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => CarDataClient._buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onBasicDataResponse)
        );
    }

    function onBasicDataResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        responseCode = CarDataClient.isRateLimit(responseCode, data) ? 429 : responseCode;
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
            CarDataClient._DATA_HOST + "/customers/vehicles/" + vin + "/smartMaintenanceTyreDiagnosis",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => CarDataClient._buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onTyreDiagnosisResponse)
        );
    }

    function onTyreDiagnosisResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        responseCode = CarDataClient.isRateLimit(responseCode, data) ? 429 : responseCode;
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

    // typecheck off: makeWebRequest's callback type names PersistedContent.Iterator,
    // whose permission is unsupported on fenix 6 (adding it makes the watch refuse to
    // run the widget). We don't name that type anywhere; suppress the check here.
    (:typecheck(false))
    function fetchMappings(accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            CarDataClient._DATA_HOST + "/customers/vehicles/mappings",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => CarDataClient._buildHeaders(accessToken),
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
        responseCode = CarDataClient.isRateLimit(responseCode, data) ? 429 : responseCode;
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

    // --- Containers (list / create / delete) ---

    // List existing containers; reuse the one matching `name` if present.
    // GET /customers/containers -> {"data":{"containers":[ {id|containerId, name, ...} ]}}.
    // isBg selects which Storage slot a match is cached into (lean bg vs full).
    function fetchContainers(accessToken, name, isBg, callback) {
        _callback   = callback;
        _matchName  = name;
        _isBgTarget = isBg;
        Communications.makeWebRequest(
            CarDataClient._DATA_HOST + "/customers/containers",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => CarDataClient._buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onContainersResponse)
        );
    }

    // Returns an existing container id (match on _matchName ONLY) or null via callback.
    // Containers under other names — including this widget's own older versions —
    // must NOT be reused: the A3 migration relies on a no-match here so the
    // caller falls through to createContainer with the current descriptor set.
    function onContainersResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        responseCode = CarDataClient.isRateLimit(responseCode, data) ? 429 : responseCode;
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
                        if (id != null && nm != null && nm.equals(_matchName)) {
                            cid = id;
                            break;
                        }
                    }
                }
            }
        }
        if (cid != null) { _storeResolved(cid); }
        data = null;
        _callback.invoke(responseCode, cid);
    }

    // Lists EVERY container id on the account (for the "delete all" maintenance action —
    // clears orphaned old-version containers, not just the two this build tracks).
    // Returns the rate-limit-normalized responseCode + an Array of ids via the callback.
    function fetchContainerIds(accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            CarDataClient._DATA_HOST + "/customers/containers",
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_GET,
              :headers      => CarDataClient._buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onContainerIdsResponse)
        );
    }

    function onContainerIdsResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        responseCode = CarDataClient.isRateLimit(responseCode, data) ? 429 : responseCode;
        var ids = [];
        if (responseCode == 200 && data != null) {
            var d = data.hasKey("data") ? data["data"] : data;
            var list = (d instanceof Lang.Dictionary && d.hasKey("containers")) ? d["containers"] : null;
            if (list instanceof Lang.Array) {
                for (var i = 0; i < list.size(); i++) {
                    var c = list[i];
                    if (c instanceof Lang.Dictionary) {
                        var id = c.hasKey("containerId") ? c["containerId"]
                               : (c.hasKey("id") ? c["id"] : null);
                        if (id != null) { ids.add(id); }
                    }
                }
            }
        }
        data = null;
        _callback.invoke(responseCode, ids);
    }

    // name + descriptors + isBg parameterize the full vs lean-bg container.
    function createContainer(accessToken, name, descriptors, isBg, callback) {
        _callback   = callback;
        _isBgTarget = isBg;
        // JSON POST: Content-Type must be set via the REQUEST_CONTENT_TYPE_JSON enum in
        // :headers (a raw "Content-Type" string yields -200 INVALID_HTTP_HEADER_FIELDS).
        // CIQ then JSON-encodes the Dictionary body.
        Communications.makeWebRequest(
            CarDataClient._DATA_HOST + "/customers/containers",
            {
                "name"                 => name,
                "purpose"              => "Garmin fenix widget status",
                "technicalDescriptors" => descriptors
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
        responseCode = CarDataClient.isRateLimit(responseCode, data) ? 429 : responseCode;
        var cid = null;
        _capFailure = false;
        if ((responseCode == 200 || responseCode == 201) && data != null) {
            cid = data.hasKey("containerId") ? data["containerId"]
                : (data.hasKey("id") ? data["id"] : null);
            if (cid != null) { _storeResolved(cid); }
        } else if (CarDataClient.isContainerCapError(responseCode, data)) {
            // 403 + CU-124 "Maximum number of containers reached" → onboarding offers
            // "delete all containers and retry".
            _capFailure = true;
        }
        data = null;
        _callback.invoke(responseCode, cid);
    }

    // Cache a resolved/created container id into the slot for the current target.
    function _storeResolved(cid) {
        if (_isBgTarget) { CarDataClient._storeBgContainer(cid); }
        else             { CarDataClient._storeContainer(cid); }
    }

    // --- Container delete (F14, DELETE /customers/containers/{id}, verified 200) ---

    function deleteContainer(containerId, accessToken, callback) {
        _callback = callback;
        Communications.makeWebRequest(
            CarDataClient._DATA_HOST + "/customers/containers/" + containerId,
            null,
            { :method       => Communications.HTTP_REQUEST_METHOD_DELETE,
              :headers      => CarDataClient._buildHeaders(accessToken),
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onDeleteContainerResponse)
        );
    }

    function onDeleteContainerResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) as Void {
        // Rate limit (429 / 403+CU-429) → surface distinctly so the caller can show a
        // "daily limit" message instead of "retry". Else: already gone (404) or already
        // pending deletion (CU-122) → effectively deleted, normalize to success.
        if (CarDataClient.isRateLimit(responseCode, data)) {
            responseCode = 429;
        } else if (responseCode == 404 || CarDataClient.isAlreadyDeleting(data)) {
            responseCode = 204;
        }
        data = null;
        _callback.invoke(responseCode, null);
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

    // LIVE / event-driven page fields the BACKGROUND container subscribes to — lock,
    // doors, trunk, hood, windows, range, fuel. Small enough to fit the ~28 KB background
    // heap (the 27-field "all pages" set OOM'd, rc=-403). Slow/static fields (tyres,
    // odometer, service distance, displayUnit, EV range/SOC, About-car detail) are left to
    // the manual/daily FULL fetch. rangeKm comes from totalRemainingRange via the parser's
    // range-selection. VehicleCache.write merges, so the full-fetch fields persist between.
    static function _bgContainerDescriptors() {
        return [
            "vehicle.cabin.door.lock.status",
            "vehicle.cabin.door.row1.driver.isOpen",
            "vehicle.cabin.door.row1.passenger.isOpen",
            "vehicle.cabin.door.row2.driver.isOpen",
            "vehicle.cabin.door.row2.passenger.isOpen",
            "vehicle.body.trunk.isOpen",
            "vehicle.body.hood.isOpen",
            "vehicle.cabin.window.row1.driver.status",
            "vehicle.cabin.window.row1.passenger.status",
            "vehicle.cabin.window.row2.driver.status",
            "vehicle.cabin.window.row2.passenger.status",
            "vehicle.drivetrain.totalRemainingRange",
            "vehicle.drivetrain.fuelSystem.level",
            "vehicle.drivetrain.fuelSystem.remainingFuel"
        ];
    }

}
