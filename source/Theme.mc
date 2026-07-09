// Central registry of ALL color constants — M Performance theme.
// Palette matches the UX mock key-screens-v2.html :root exactly.
// RULE: Never use inline hex color values in any ui/ file. Always reference Theme.COLOR_*.
//
// TIER-SPLIT DESIGN (see monkey.jungle): API 6.0+ devices get the AMOLED
// refresh ((:designNew) — true-black background, OLED-bright green); legacy
// fēnix 6-era devices keep the original palette pixel-for-pixel
// ((:designClassic)). Exactly one variant of each paired constant survives
// per device build.
class Theme {
    (:designNew)     static const COLOR_BG = 0x000000; // true black — AMOLED pixels off, blends with bezel
    (:designClassic) static const COLOR_BG = 0x111111; // --bg    near-black background

    static const COLOR_ACCENT = 0xE02020; // --red   M Performance red (bars, accents)
    static const COLOR_WHITE  = 0xFFFFFF; // pure white — hero primary values
    static const COLOR_TEXT   = 0xF5F5F5; // --text1 secondary value text
    static const COLOR_MUTED  = 0xAAAAAA; // --text2 secondary / labels / unit
    static const COLOR_DIM    = 0x555555; // --text3 tertiary: headers, age, dots

    static const COLOR_WARN   = 0xE07020; // amber: low fuel / tyre low / unlocked

    (:designNew)     static const COLOR_OK = 0x00C853; // OLED-bright green: all-clear (dots, bars)
    (:designClassic) static const COLOR_OK = 0x4CAF50; // green: all-clear / good (dots, bars)

    static const COLOR_OK_HI  = 0x69F0AE; // bright green: hero status text (SECURED)
    static const COLOR_ERROR  = 0xE02020; // red: critical / open (= ACCENT)

    // Progress-bar track — only referenced by the (:designNew) PageChrome.drawBar.
    (:designNew)     static const COLOR_TRACK = 0x2E2E2E; // whisper-dark: the FILL carries the signal
}
