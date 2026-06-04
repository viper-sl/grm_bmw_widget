#!/usr/bin/env bash
# Build YOUR personal BMW widget (not for the IQ store).
#
# Personal config lives in the gitignored resources-livetest/properties/properties.xml
# (only clientId is required — VIN auto-discovers via /mappings, container auto-creates
# on first run). Pairing is done on-watch via the device flow.
#
# Usage:
#   ./build-personal.sh            # build + load into the running simulator (fenix 6 Pro)
#   ./build-personal.sh --device   # build a sideload-ready .prg for a real fenix 6 Pro
#   ./build-personal.sh --fr255-sim  # build + load into simulator as Forerunner 255
#   ./build-personal.sh --fr255    # build a sideload-ready .prg for a real Forerunner 255
#   ./build-personal.sh --iq       # build a signed .iq package (all installed devices)
#
# Output:
#   bin/personal.prg               (simulator)
#   bin/BMWWIDGET.PRG              (real watch — copy to GARMIN/APPS/)
#   bin/BMWWIDGET.iq               (signed IQ package — sideload via Connect IQ phone app)
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

mkdir -p bin

# Normalise single-dash aliases.
ARG="${1:-}"
case "$ARG" in
  -iq)        ARG="--iq"        ;;
  -device)    ARG="--device"    ;;
  -fr255)     ARG="--fr255"     ;;
  -fr255-sim) ARG="--fr255-sim" ;;
esac

# ── --fr255-sim: simulator build for Forerunner 255 ─────────────────────────
if [ "$ARG" == "--fr255-sim" ]; then
  OUT="bin/personal-fr255.prg"
  echo "Building SIM release build → $OUT  (target: fr255_sim)"
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "fr255_sim" -r 2>&1 \
    | grep -v "^WARNING:" || true
  if [ ! -f "$OUT" ]; then
    echo "✗ Build failed — fr255 SDK profile may not be installed." >&2
    echo "  Install it: SDK Manager → Devices → Forerunner 255, then re-run." >&2
    exit 1
  fi
  SIM_APP="$SDK/bin/ConnectIQ.app"
  if ! pgrep -qx "simulator" 2>/dev/null; then
    echo "Starting Connect IQ simulator…"
    open -a "$SIM_APP"
    for i in $(seq 1 15); do
      sleep 1
      if "$SDK/bin/monkeydo" "$OUT" "fr255" 2>/dev/null; then
        echo "✓ Loaded into simulator"
        exit 0
      fi
    done
    echo "⚠ Simulator did not become ready in time. Try:"
    echo "    $SDK/bin/monkeydo $OUT fr255"
    exit 1
  fi
  echo "Loading into simulator…"
  "$SDK/bin/monkeydo" "$OUT" "fr255"
  echo "✓ Loaded into simulator"
  exit 0
fi

# ── --fr255: real Forerunner 255 sideload .prg ───────────────────────────────
if [ "$ARG" == "--fr255" ]; then
  OUT="bin/BMWWIDGET-FR255.PRG"
  echo "Building DEVICE release build → $OUT  (target: fr255)"
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "fr255" -r 2>&1 \
    | grep -v "^WARNING:" || true
  if [ ! -f "$OUT" ]; then
    echo "✗ Build failed — fr255 SDK profile may not be installed." >&2
    echo "  Install it: SDK Manager → Devices → Forerunner 255, then re-run." >&2
    exit 1
  fi
  echo "✓ Built $OUT"

  DEST=""
  for v in /Volumes/*; do
    if [ -d "$v/GARMIN/APPS" ]; then DEST="$v/GARMIN/APPS"; break; fi
  done

  if [ -n "$DEST" ]; then
    rm -f "$DEST/SETTINGS/GRM_BMW_WIDGET.SET" 2>/dev/null && echo "  cleared stale SETTINGS"
    rm -f "$DEST/DATA/GRM_BMW_WIDGET."* 2>/dev/null && echo "  cleared stale DATA"
    cp -f "$OUT" "$DEST/GRM_BMW_WIDGET.PRG"
    sync
    echo "✓ Copied to $DEST/GRM_BMW_WIDGET.PRG"
  else
    echo "⚠ No Garmin device mounted."
    echo "  Copy manually: cp $OUT /Volumes/<GARMIN>/GARMIN/APPS/GRM_BMW_WIDGET.PRG"
  fi
  exit 0
fi

# ── --device: real watch sideload .prg ──────────────────────────────────────
if [ "$ARG" == "--device" ]; then
  OUT="bin/BMWWIDGET.PRG"
  echo "Building DEVICE release build → $OUT  (target: $DEVICE)"
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "$DEVICE" -r 2>&1 \
    | grep -v "^WARNING:"
  echo "✓ Built $OUT"

  DEST=""
  for v in /Volumes/*; do
    if [ -d "$v/GARMIN/APPS" ]; then DEST="$v/GARMIN/APPS"; break; fi
  done

  if [ -n "$DEST" ]; then
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

# ── --iq: signed distribution package (separate app ID, no personal resources) ──
if [ "$ARG" == "--iq" ]; then
  OUT="bin/BMWWIDGET.iq"
  echo "Building IQ distribution package → $OUT"
  echo "  App ID : 0a54403f6fef458a96fca6f8a147f299  (manifest-iq.xml)"
  echo "  Local  : 7f673698b206464a8e918654edcfeb6c  (manifest.xml / livetest)"
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$OUT" -f "iq.jungle" -y "$KEY" -e -r 2>&1 \
    | grep -v "^WARNING:"
  echo "✓ Built $OUT  — can coexist on watch with the personal sideload build"
  echo "  Sideload via the Connect IQ phone app → My Device Apps → Sideload Widget."
  exit 0
fi

# ── default: simulator build + load ─────────────────────────────────────────
OUT="bin/personal.prg"
echo "Building SIM release build → $OUT  (target: ${DEVICE}_sim)"
java -jar "$SDK/bin/monkeybrains.jar" \
  -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "${DEVICE}_sim" -r 2>&1 \
  | grep -v "^WARNING:"

# Launch simulator if not already running, then wait for it to accept connections.
SIM_APP="$SDK/bin/ConnectIQ.app"
if ! pgrep -qx "simulator" 2>/dev/null; then
  echo "Starting Connect IQ simulator…"
  open -a "$SIM_APP"
  # Poll until monkeydo can connect (max 15 s)
  for i in $(seq 1 15); do
    sleep 1
    if "$SDK/bin/monkeydo" "$OUT" "$DEVICE" 2>/dev/null; then
      echo "✓ Loaded into simulator"
      exit 0
    fi
  done
  echo "⚠ Simulator did not become ready in time. Try:"
  echo "    $SDK/bin/monkeydo $OUT $DEVICE"
  exit 1
fi

echo "Loading into simulator…"
"$SDK/bin/monkeydo" "$OUT" "$DEVICE"
echo "✓ Loaded into simulator"
