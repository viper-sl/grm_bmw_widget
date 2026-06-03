#!/usr/bin/env bash
# Build YOUR personal BMW widget (not for the IQ store).
#
# Personal config lives in the gitignored resources-livetest/properties/properties.xml
# (only clientId is required — VIN auto-discovers via /mappings, container auto-creates
# on first run). Pairing is done on-watch via the device flow.
#
# Usage:
#   ./build-personal.sh            # build + load into the running simulator
#   ./build-personal.sh --device   # build a sideload-ready .prg for a real fenix 6 Pro
#
# Output: bin/personal.prg          (simulator)
#         bin/personal-device.prg   (real watch — copy to GARMIN/APPS/)
set -euo pipefail

SDK="${CIQ_SDK:-$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b}"
KEY="${DEVELOPER_KEY:-developer_key}"
JUNGLE="livetest.jungle"
DEVICE="fenix6pro"

if [ ! -f "resources-livetest/properties/properties.xml" ]; then
  echo "Missing resources-livetest/properties/properties.xml (your clientId)." >&2
  echo "Create it from bmw_tokens.json — see docs/PERSONAL-BUILD.md." >&2
  exit 1
fi
if [ ! -f "$KEY" ]; then
  echo "Missing developer key '$KEY'. Generate one in the SDK (or set DEVELOPER_KEY)." >&2
  exit 1
fi

if [ "${1:-}" == "--device" ]; then
  # Output named BMWWIDGET.PRG (not "release.prg") to avoid colliding with a stale
  # ghost registry entry the watch may have keyed by the old filename.
  OUT="bin/BMWWIDGET.PRG"
  echo "Building DEVICE release build → $OUT  (target: $DEVICE)"
  # Matches the known-good manual command: -d fenix6pro (real target, NOT _sim) -r.
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "$DEVICE" -r
  echo "✓ Built $OUT"

  # Auto-detect a mounted Garmin device (a volume containing GARMIN/APPS) and copy.
  DEST=""
  for v in /Volumes/*; do
    if [ -d "$v/GARMIN/APPS" ]; then DEST="$v/GARMIN/APPS"; break; fi
  done

  if [ -n "$DEST" ]; then
    # Wipe stale persisted SETTINGS + DATA first. A previous install (esp. the generic
    # no-clientId build) persists an EMPTY clientId that overrides the baked-in default,
    # leaving the app stuck on "Press START to connect". Reinstalling the .prg alone does
    # NOT clear this — the persisted SETTINGS/DATA must go.
    rm -f "$DEST/SETTINGS/GRM_BMW_WIDGET.SET" 2>/dev/null && echo "  cleared stale SETTINGS"
    rm -f "$DEST/DATA/GRM_BMW_WIDGET."* 2>/dev/null && echo "  cleared stale DATA"
    cp -f "$OUT" "$DEST/GRM_BMW_WIDGET.PRG"
    sync
    echo "✓ Copied to $DEST/GRM_BMW_WIDGET.PRG"
    echo "  Safely eject the watch, then open 'BMW Status' in the widget loop."
  else
    echo "⚠ No Garmin device mounted (looked for /Volumes/*/GARMIN/APPS)."
    echo "  1. Connect the fenix 6 Pro by USB; on the watch confirm 'Mass Storage'."
    echo "  2. Re-run, or copy manually:"
    echo "       cp $OUT /Volumes/<GARMIN>/GARMIN/APPS/GRM_BMW_WIDGET.PRG"
  fi
  exit 0
fi

OUT="bin/personal.prg"
echo "Building SIM release build → $OUT  (target: ${DEVICE}_sim)"
java -jar "$SDK/bin/monkeybrains.jar" \
  -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "${DEVICE}_sim" -w -r

echo "Loading into simulator…"
"$SDK/bin/monkeydo" "$OUT" "$DEVICE"
