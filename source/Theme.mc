// Central registry of ALL color constants — M Performance theme.
// Palette matches the UX mock key-screens-v2.html :root exactly.
// RULE: Never use inline hex color values in any ui/ file. Always reference Theme.COLOR_*.
class Theme {
    static const COLOR_BG     = 0x111111; // --bg    near-black background
    static const COLOR_ACCENT = 0xE02020; // --red   M Performance red (bars, accents)
    static const COLOR_TEXT   = 0xF5F5F5; // --text1 primary value text
    static const COLOR_MUTED  = 0xAAAAAA; // --text2 secondary / labels / unit
    static const COLOR_DIM    = 0x555555; // --text3 tertiary: headers, age, dots
    static const COLOR_WARN   = 0xE07020; // amber: low fuel / tyre low / unlocked
    static const COLOR_OK     = 0x4CAF50; // green: all-clear / good
    static const COLOR_ERROR  = 0xE02020; // red: critical / open (= ACCENT)
}
