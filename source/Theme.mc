// Central registry of ALL color constants — M Performance theme.
// RULE: Never use inline hex color values in any ui/ file. Always reference Theme.COLOR_*.
class Theme {
    static const COLOR_BG     = 0x111111; // Near-black background
    static const COLOR_ACCENT = 0xE02020; // M Performance red
    static const COLOR_TEXT   = 0xFFFFFF; // Primary text
    static const COLOR_MUTED  = 0x888888; // Secondary / stale-data text
    static const COLOR_WARN   = 0xFFAA00; // Amber: service 1000-5000 km / tyre low
    static const COLOR_OK     = 0x44CC44; // Green: service >5000 km / all clear
    static const COLOR_ERROR  = 0xE02020; // Red: service <1000 km / tyre critical (= ACCENT)
}
