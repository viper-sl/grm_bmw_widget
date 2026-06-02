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
  OUT="bin/personal-device.prg"
  echo "Building DEVICE release build → $OUT  (target: $DEVICE)"
  # NOTE: real-device target is "$DEVICE" (NOT the _sim variant).
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "$DEVICE" -w -r
  echo
  echo "✓ Built $OUT"
  echo "Sideload onto the watch:"
  echo "  1. Connect the fenix 6 Pro by USB (it mounts as a drive)."
  echo "  2. Copy $OUT into the watch's GARMIN/APPS/ folder."
  echo "  3. Eject, then find 'BMW Status' in the widget glance loop."
  exit 0
fi

OUT="bin/personal.prg"
echo "Building SIM release build → $OUT  (target: ${DEVICE}_sim)"
java -jar "$SDK/bin/monkeybrains.jar" \
  -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "${DEVICE}_sim" -w -r

echo "Loading into simulator…"
"$SDK/bin/monkeydo" "$OUT" "$DEVICE"
