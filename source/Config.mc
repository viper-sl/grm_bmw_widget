// Central config resolver. clientId comes from Settings (Properties) for store
// builds, but the PERSONAL build also bakes it into source (personalClientId) so it
// works even when the persisted Property is empty/stale — important on a real watch
// where stale SETTINGS can override the XML default and can't easily be cleared.
//
// personalClientId() has two definitions selected by build annotation:
//   - source/PersonalClientId.mc        (:stubClientId)  committed stub, returns ""
//   - resources-livetest/.../PersonalClientId.mc          gitignored real value
// The personal jungle excludes :stubClientId and adds the gitignored source dir.
using Toybox.Application;

(:background)
class Config {

    // Effective clientId: the Settings value if present, else the baked-in personal
    // fallback (empty for store builds — users enter it in phone settings).
    static function clientId() {
        var p = Application.Properties.getValue("clientId");
        if (p != null && !p.equals("")) { return p; }
        return personalClientId();
    }

}
