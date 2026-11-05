// Central config resolver. clientId comes from Settings (Properties): the store
// build reads the user's phone-settings value; the personal build reads the value
// baked into resources-livetest/properties/properties.xml.
//
// NOTE: we deliberately do NOT bake clientId into source via build annotations —
// the source-exclusion machinery (excludeAnnotations + extra sourcePath) produces a
// prg the fenix 6 installer rejects (f8=-1). A plain resource override matches the
// known-good store-build structure.
using Toybox.Application;
using Toybox.Lang;

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
    //
    // Trimmed: a Client ID pasted on a phone routinely drags a trailing space or
    // newline along, and BMW then rejects a value that looks perfectly right on screen.
    static function clientId() {
        var v = trim(Application.Properties.getValue("clientId"));
        if (v != null && !v.equals("")) {
            return v;
        }
        try {
            var baked = trim(Application.Properties.getValue("clientIdBaked"));
            if (baked != null && !baked.equals("")) {
                return baked;
            }
        } catch (e) {
            // property not declared (store build) — fall through
        }
        return v;
    }

    // The VIN Setting, as a VIN or null. Typed on a phone, it arrives lower-cased or
    // with spaces/hyphens/dots: normalize those. Anything that is then not 17
    // characters cannot be a VIN, so it is ignored and the widget auto-discovers instead
    // — the README says to leave the field empty, and a half-typed VIN must not be worse
    // than an empty one. Shared by the foreground sync and the background poll.
    static function settingsVin() {
        var v = trim(Application.Properties.getValue("vin"));
        if (!(v instanceof Lang.String) || v.equals("")) { return null; }
        var a = v.toUpper().toCharArray();
        var out = "";
        for (var i = 0; i < a.size(); i++) {
            var c = a[i];
            if (c != ' ' && c != '-' && c != '.') { out += c.toString(); }
        }
        return (out.length() == 17) ? out : null;
    }

    // Leading/trailing whitespace and control characters removed. Non-strings pass
    // through untouched (a Settings value can come back as a Number).
    static function trim(v) {
        if (!(v instanceof Lang.String)) { return v; }
        var a = v.toCharArray();
        var i = 0;
        var j = a.size();
        while (i < j && a[i].toNumber() <= 32)     { i++; }
        while (j > i && a[j - 1].toNumber() <= 32) { j--; }
        return (i == 0 && j == a.size()) ? v : v.substring(i, j);
    }

}
