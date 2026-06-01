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
            // "About car" details (shown in the on-watch settings menu).
            Application.Storage.setValue(StorageKeys.KEY_COLOUR,
                (data.hasKey("colourDescription") && data["colourDescription"] != null) ? data["colourDescription"] : "");
            Application.Storage.setValue(StorageKeys.KEY_BODY_TYPE,
                (data.hasKey("bodyType") && data["bodyType"] != null) ? data["bodyType"] : "");
            Application.Storage.setValue(StorageKeys.KEY_ENGINE,
                (data.hasKey("engine") && data["engine"] != null) ? data["engine"] : "");
        }
        data = null;
        _callback.invoke(responseCode, null);
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
