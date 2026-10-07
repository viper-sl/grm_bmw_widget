(:background)
class StorageKeys {
    static const KEY_VEHICLE_STATE    = "vehicleState";
    static const KEY_GLANCE_STATE     = "glanceState";   // lean glance-only projection of KEY_VEHICLE_STATE
    static const KEY_TOKEN_STATE      = "tokenState";
    static const KEY_ACCESS_TOKEN     = "accessToken";
    static const KEY_ACCESS_EXPIRY    = "accessTokenExpiry";
    static const KEY_REFRESH_TOKEN    = "refreshToken";
    // The clientId the stored tokens were issued to. BMW rejects a refresh_token
    // presented by a client that did not issue it, so a changed clientId kills the
    // whole grant — this stamp is how that is detected (TokenManager.syncClient).
    static const KEY_TOKEN_CLIENT_ID  = "tokenClientId";
    // Two-phase rotation. BMW hands out a new refresh token on every refresh, but a
    // new token is only PROVEN once it has actually fetched data — so the outgoing one
    // is kept here until then, and restored if the new one is rejected first.
    static const KEY_REFRESH_TOKEN_PREV = "refreshTokenPrev";
    static const KEY_GRANT_UNCONFIRMED  = "grantUnconfirmed";
    static const KEY_NEXT_ALLOWED     = "nextAllowedCall";
    static const KEY_BACKOFF_UNTIL    = "backoffUntil";
    // Epoch of the refresh POST currently in flight — serializes token refreshes
    // across the foreground views and the background process (they share Storage).
    static const KEY_REFRESH_INFLIGHT = "refreshInFlight";
    // Consecutive invalid_grant responses with no successful refresh in between.
    // Corroboration before NEEDS_REBOOTSTRAP is latched (TokenManager).
    static const KEY_GRANT_STRIKES    = "grantStrikes";
    static const KEY_VEHICLE_NAME     = "vehicleName";
    static const KEY_DRIVE_TYPE       = "driveType";
    static const KEY_BASIC_DATA       = "basicData";
    static const KEY_VIN              = "vin";
    static const KEY_CONTAINER_ID     = "containerId";
    static const KEY_CONTAINER_NAME   = "containerName";
    // Second, lean container polled by the background service (fewer descriptors →
    // a response small enough to deserialize in the ~28 KB background heap). The full
    // container above stays the foreground's, so the About-car detail survives.
    static const KEY_BG_CONTAINER_ID   = "bgContainerId";
    static const KEY_BG_CONTAINER_NAME = "bgContainerName";
}
