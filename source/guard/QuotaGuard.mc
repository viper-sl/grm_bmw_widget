// Rate-limit gate for BMW CarData data API (~50 calls/day on api-cardata.bmwgroup.com).
// Token refresh calls (customer.bmwgroup.com) are exempt — separate host, separate quota.
// RULE: KEY_NEXT_ALLOWED is always advanced forward — never reset to 0.
// RULE: KEY_NEXT_ALLOWED and KEY_BACKOFF_UNTIL are independent keys with different semantics:
//   KEY_NEXT_ALLOWED  — advances on every call; cleared only by time expiry
//   KEY_BACKOFF_UNTIL — cleared to 0 on success; set on error (managed by Background Service)
using Toybox.Application;
using Toybox.Time;

(:background)
class QuotaGuard {

    // Returns true if a Data Fetch is permitted now.
    // null KEY_NEXT_ALLOWED (first run) → always permitted.
    // Active gate (now < nextAllowed) → returns false; Background Service skips this cycle.
    static function canFetch() {
        var nextAllowed = Application.Storage.getValue(StorageKeys.KEY_NEXT_ALLOWED);
        if (nextAllowed == null) {
            return true;
        }
        return Time.now().value() >= nextAllowed;
    }

    // Call after every Data Fetch attempt (success or non-429 error).
    // Advances the gate by 40 minutes — the normal poll interval.
    static function updateAfterFetch() {
        Application.Storage.setValue(
            StorageKeys.KEY_NEXT_ALLOWED,
            Time.now().value() + 2400
        );
    }

    // Call when CarDataClient receives a CU-429 quota-exceeded response.
    // Blocks until 4 AM local time the next day — quota resets at midnight and
    // 4 AM gives BMW's systems time to fully flush the counter.
    static function onQuotaExceeded() {
        // Time.today() returns local midnight of the current day as epoch seconds.
        var todayAt4AM = Time.today().value() + 4 * 3600;
        var blockUntil = (Time.now().value() < todayAt4AM)
            ? todayAt4AM              // before 4 AM today → unblock at 4 AM today
            : todayAt4AM + 86400;    // after  4 AM today → unblock at 4 AM tomorrow
        Application.Storage.setValue(StorageKeys.KEY_NEXT_ALLOWED, blockUntil);
    }

}
