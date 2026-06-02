// Central registry of ALL Application.Storage key strings.
// RULE: Never use inline string literals for Storage keys elsewhere in the codebase.
// NOTE: KEY_VEHICLE_IMAGE intentionally absent — 173 KB exceeds Storage cap (~16-32 KB total)
//       and Background.exit() cap (8 KB). PageVehicle deferred to v2.
(:background)
class StorageKeys {
    static const KEY_VEHICLE_STATE    = "vehicleState";      // Dictionary: parsed Vehicle State
    static const KEY_TOKEN_STATE      = "tokenState";        // String: UNCONFIGURED/NORMAL/NEEDS_REFRESH/NEEDS_REBOOTSTRAP
    static const KEY_ACCESS_TOKEN     = "accessToken";       // String: opaque bearer token (1h)
    static const KEY_ACCESS_EXPIRY    = "accessTokenExpiry"; // Number: epoch seconds (obtainedAt + expiresIn)
    static const KEY_REFRESH_TOKEN    = "refreshToken";      // String: rotates on every use
    static const KEY_NEXT_ALLOWED     = "nextAllowedCall";   // Number: epoch seconds (Quota Guard gate)
    static const KEY_BACKOFF_UNTIL    = "backoffUntil";      // Number: epoch seconds (0 = no backoff active)
    static const KEY_VEHICLE_NAME     = "vehicleName";       // String: e.g. "BMW 218i" (from basicData)
    static const KEY_DRIVE_TYPE       = "driveType";         // String: CONV / BEV / PHEV (from basicData)
    static const KEY_BASIC_DATA       = "basicData";         // Dictionary: full basicData snapshot (About car)
    static const KEY_VIN              = "vin";               // String: auto-discovered VIN (from /mappings)
    static const KEY_CONTAINER_ID     = "containerId";       // String: auto-created container id
}
