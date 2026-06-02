// Committed STUB for the baked-in personal clientId.
// Store builds compile this (returns "" → users enter clientId in phone settings).
// The PERSONAL build EXCLUDES the :stubcid annotation (via livetest.jungle) and
// instead compiles the gitignored real value from resources-livetest source.
(:stubcid :background)
function personalClientId() {
    return "";
}
