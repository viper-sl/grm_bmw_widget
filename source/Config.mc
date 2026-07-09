// Central config resolver. clientId comes from Settings (Properties): the store
// build reads the user's phone-settings value; the personal build reads the value
// baked into resources-livetest/properties/properties.xml.
//
// NOTE: we deliberately do NOT bake clientId into source via build annotations —
// the source-exclusion machinery (excludeAnnotations + extra sourcePath) produces a
// prg the fenix 6 installer rejects (f8=-1). A plain resource override matches the
// known-good store-build structure.
using Toybox.Application;

(:background)
class Config {

    // Resolution order:
    //   1. "clientId" Property — store build: user-entered via GCM settings;
    //      personal build: baked default from resources-livetest.
    //   2. "clientIdBaked" Property — personal build only (declared ONLY in
    //      resources-livetest/properties, never in settings.xml). The sim and
    //      GCM persist a settings store that can override the "clientId"
    //      default with an empty string ("Empty clientId overrides XML
    //      default" gotcha); clientIdBaked has no settings surface, so
    //      nothing can clobber it. Store builds don't declare it — the
    //      getValue throws and the catch falls through.
    static function clientId() {
        var v = Application.Properties.getValue("clientId");
        if (v != null && !v.equals("")) {
            return v;
        }
        try {
            var baked = Application.Properties.getValue("clientIdBaked");
            if (baked != null && !baked.equals("")) {
                return baked;
            }
        } catch (e) {
            // property not declared (store build) — fall through
        }
        return v;
    }

}
