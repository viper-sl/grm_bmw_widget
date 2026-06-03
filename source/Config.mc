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

    static function clientId() {
        return Application.Properties.getValue("clientId");
    }

}
