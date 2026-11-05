#!/usr/bin/env bash
# Build YOUR personal BMW widget (not for the IQ store).
#
# Personal config lives in the gitignored resources-livetest/properties/properties.xml
# (only clientId is required — VIN auto-discovers via /mappings, container auto-creates
# on first run). Pairing is done on-watch via the device flow.
#
# Usage:
#   ./build-personal.sh            # build + load into the running simulator (fenix 8 Pro 47mm)
#   ./build-personal.sh --device   # build a sideload-ready .prg for a real fenix 8 Pro
#   ./build-personal.sh --fr255-sim  # build + load into simulator as Forerunner 255
#   ./build-personal.sh --fr255    # build a sideload-ready .prg for a real Forerunner 255
#   ./build-personal.sh --iq       # signed .iq, BETA app ID (private beta testing)
#   ./build-personal.sh --iqprod   # signed .iq, PROD app ID (upload to the store, public)
#
# Override the default target via CIQ_DEVICE (e.g. CIQ_DEVICE=fenix6pro ./build-personal.sh).
# Explicit device flags (--fr255, --fr255-sim) always win over CIQ_DEVICE.
#
# Output:
#   bin/personal.prg               (simulator)
#   bin/BMWWIDGET.PRG              (real watch — copy to GARMIN/APPS/)
#   bin/BMWWIDGET.iq               (beta IQ package — sideload via Connect IQ phone app)
#   bin/BMWWIDGET-prod.iq          (prod IQ package — upload to the Connect IQ store)
set -euo pipefail

SDK="${CIQ_SDK:-$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2}"
KEY="${DEVELOPER_KEY:-developer_key}"
JUNGLE="livetest.jungle"
DEVICE="${CIQ_DEVICE:-fenix8pro47mm}"

# Connect IQ app IDs. An ID identifies the app in the store and on the watch, and a
# published ID can never change — the prod one is permanent once uploaded.
# manifest-iq.xml is the template for both; the ID is swapped in at build time.
IQ_BETA_ID="0a54403f6fef458a96fca6f8a147f299"
IQ_PROD_ID="cdbc0197661143ecbc4478161b71d125"

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
  -iqprod)    ARG="--iqprod"    ;;
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
  rm -f "$OUT"
  echo "Building DEVICE release build → $OUT  (target: $DEVICE)"
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "$DEVICE" -r 2>&1 \
    | grep -v "^WARNING:" || true
  if [ ! -f "$OUT" ]; then
    echo "✗ Build failed — the $DEVICE SDK profile may not be installed." >&2
    echo "  Install it: SDK Manager → Devices → $DEVICE, then re-run." >&2
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
    echo "  Safely eject the watch, then open 'BMW Status' in the widget loop."
  else
    echo "⚠ No Garmin device mounted (looked for /Volumes/*/GARMIN/APPS)."
    echo "  1. Connect the watch ($DEVICE) by USB; on the watch confirm 'Mass Storage'."
    echo "  2. Re-run, or copy manually:"
    echo "       cp $OUT /Volumes/<GARMIN>/GARMIN/APPS/GRM_BMW_WIDGET.PRG"
  fi
  exit 0
fi

# ── --iq / --iqprod: signed distribution packages (no personal resources) ───
# Both build from iq.jungle + manifest-iq.xml; only the application id differs.
# The id is injected into a generated copy of the manifest, and a generated copy of
# iq.jungle points project.manifest at it (a second jungle can't override that
# property, and the copy must sit in the project root so source/resources still
# resolve). Both are removed on exit; iq.jungle / manifest-iq.xml stay the single
# templates. The built .iq is then opened to prove it carries the intended id.
build_iq() {
  local label="$1" app_id="$2" out="$3"
  local manifest="manifest-iq-$label.generated.xml" jungle="iq-$label.generated.jungle"
  trap "rm -f '$manifest' '$jungle'" EXIT   # expand now: the locals are gone by EXIT

  echo "Building IQ $label package → $out"
  echo "  App ID : $app_id"
  echo "  Local  : 7f673698b206464a8e918654edcfeb6c  (manifest.xml / livetest)"

  APP_ID="$app_id" perl -0pe \
    's/(<iq:application\b[^>]*?\bid=")[0-9a-f]{32}(")/$1$ENV{APP_ID}$2/' \
    manifest-iq.xml > "$manifest"
  if ! grep -q "id=\"$app_id\"" "$manifest"; then
    echo "✗ Could not set the app id in $manifest — is manifest-iq.xml's <iq:application id=…> intact?" >&2
    exit 1
  fi
  sed "s|^project.manifest *=.*|project.manifest = $manifest|" iq.jungle > "$jungle"
  if ! grep -q "^project.manifest = $manifest\$" "$jungle"; then
    echo "✗ Could not point $jungle at $manifest — is iq.jungle's project.manifest line intact?" >&2
    exit 1
  fi

  rm -f "$out"
  java -jar "$SDK/bin/monkeybrains.jar" \
    -o "$out" -f "$jungle" -y "$KEY" -e -r 2>&1 \
    | grep -v "^WARNING:" || true
  if [ ! -f "$out" ]; then
    echo "✗ Build failed — see the errors above." >&2
    exit 1
  fi

  # Never ship a package under the wrong id: read it back out of the archive.
  # (Captured first: `grep -q` closing the pipe early would SIGPIPE tar under pipefail.)
  local packaged
  packaged="$(tar -xOf "$out" manifest.xml)"
  if ! grep -q "id=\"$app_id\"" <<<"$packaged"; then
    echo "✗ $out does not contain app id $app_id — refusing to hand it over." >&2
    rm -f "$out"
    exit 1
  fi
  echo "✓ Built $out  (app id verified inside the package)"
}

if [ "$ARG" == "--iq" ]; then
  build_iq beta "$IQ_BETA_ID" "bin/BMWWIDGET.iq"
  echo "  Can coexist on the watch with the personal sideload build."
  echo "  Sideload via the Connect IQ phone app → My Device Apps → Sideload Widget."
  exit 0
fi

if [ "$ARG" == "--iqprod" ]; then
  build_iq prod "$IQ_PROD_ID" "bin/BMWWIDGET-prod.iq"
  echo "  Upload this file to the Connect IQ store dashboard (public listing)."
  exit 0
fi

# ── default: simulator build + load ─────────────────────────────────────────
OUT="bin/personal.prg"
rm -f "$OUT"
echo "Building SIM release build → $OUT  (target: ${DEVICE}_sim)"
java -jar "$SDK/bin/monkeybrains.jar" \
  -o "$OUT" -f "$JUNGLE" -y "$KEY" -d "${DEVICE}_sim" -r 2>&1 \
  | grep -v "^WARNING:" || true
if [ ! -f "$OUT" ]; then
  echo "✗ Build failed — the $DEVICE SDK profile may not be installed (or CIQ_DEVICE typo)." >&2
  echo "  Install it: SDK Manager → Devices → $DEVICE, then re-run." >&2
  exit 1
fi

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
