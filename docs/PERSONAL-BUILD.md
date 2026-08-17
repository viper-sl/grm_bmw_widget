# Personal Build (your watch, not the IQ store)

This widget can be built **for your own watch** without publishing to the Connect IQ
store. Your BMW credentials live in a **gitignored** override and are baked into a
private `.prg` you sideload.

## What you need

Only your **BMW CarData client ID**. Everything else is automatic:

| Value | How it's obtained |
|---|---|
| **clientId** | You provide it (BMW CarData portal) — in the override file below |
| **refresh/access token** | On-watch device-flow pairing (no manual entry) |
| **VIN** | Auto-discovered via `GET /customers/vehicles/mappings` after pairing |
| **container IDs** | Two auto-created via `POST /customers/containers` on first sync: a **full** one (foreground) + a **lean** one (background poll) |

## How the clientId is baked in

The personal build puts your clientId in **source** (not just a settings default),
so it works even when stale/empty persisted settings would otherwise override the
XML default — which happens on a real watch where old SETTINGS can't easily be cleared.

- `source/Config.mc` → `Config.clientId()` returns the Settings value if present,
  else the baked-in `personalClientId()`.
- `source/PersonalClientId.mc` — committed **stub** (`:stubcid`) returning `""`.
- `source-personal/PersonalClientIdReal.mc` — **gitignored**, your real value (`:realcid`).
- `livetest.jungle` adds `source-personal/` and excludes `:stubcid`.

Regenerate the gitignored real one after changing clientId:
```sh
CID=$(python3 -c 'import json;print(json.load(open("bmw_tokens.json"))["client_id"])')
mkdir -p source-personal
cat > source-personal/PersonalClientIdReal.mc <<MC
(:realcid :background)
function personalClientId() { return "$CID"; }
MC
```

## Setup (one-time)

1. (Optional) The override properties file is also still read first; you can leave
   `resources-livetest/properties/properties.xml`:
   ```xml
   <?xml version="1.0"?>
   <properties>
     <property id="clientId" type="String">YOUR_CLIENT_ID</property>
     <!-- Settings-proof copy: not referenced by settings.xml, so the sim/GCM
          settings store can never override it with an empty value.
          Config.clientId() falls back to it when "clientId" resolves empty. -->
     <property id="clientIdBaked" type="String">YOUR_CLIENT_ID</property>
     <property id="vin" type="String"></property>
     <property id="containerId" type="String"></property>
     <property id="refreshToken" type="String"></property>
     <property id="tankLitres" type="Number">52</property>
     <property id="updateMode" type="Number">0</property>
   </properties>
   ```
   (Or regenerate it from `bmw_tokens.json` — see the `python3` snippet in
   [LIVE-TESTING.md](LIVE-TESTING.md).)

2. These are all **gitignored** and must never be committed:
   `resources-livetest/`, `livetest.jungle`, `bin/personal.prg`, `bin/livetest.prg`,
   `bmw_tokens.json`, `developer_key`.

## Build & run

```sh
./build-personal.sh            # build + load into the running simulator
./build-personal.sh --device   # build bin/personal-device.prg for a real watch
```

The two modes use **different compile targets** — `fenix6pro_sim` for the simulator,
`fenix6pro` for the physical watch — so they produce separate `.prg` files. The
device build is signed with your `developer_key`.

### Sideload onto a real fēnix 6 Pro

1. Connect the watch by USB — it mounts as a USB drive ("GARMIN").
2. Copy `bin/personal-device.prg` into the watch's `GARMIN/APPS/` folder.
3. Safely eject and unplug.
4. On the watch, scroll the widget glance loop to **BMW Status**.

(If the app doesn't appear, confirm the file is directly in `GARMIN/APPS/`, not a
subfolder, and that there's free space.)

### ⚠ Installed but never appears in the widget list (poisoned slot)

**Confirmed root cause + fix (Jun 2026):** repeated *failed* installs of the same
app id (e.g. a build with an unsupported permission) **poison that app id's slot**
in the watch's app registry (`GARMIN/APPS/OUT.BIN`). Once poisoned, the watch
rejects every subsequent install under that id — even a previously-working binary.

The registry shows the poisoned app uniquely: `f5=0`, the raw upload filename (e.g.
`release`) instead of an assigned 8-char hash, and `f8=-1` (0xFFFFFFFF). Working
apps always get a nonzero `f5`, a hash filename, and no `f8`.

**Fix that worked:** change the app id in `manifest.xml` (`iq:application id=...`)
to a fresh UUID — `python3 -c "import uuid;print(uuid.uuid4().hex)"` — and install
under a distinct filename (e.g. `BMWWIDGET.PRG`, not `release.prg`). This lands in a
clean registry slot and installs normally. The poisoned slot can be left alone; the
firmware ignores the dead entry.


If a build with an **unsupported permission** was ever sideloaded (e.g. a build that
requested `PersistedContent`, which the fēnix 6 firmware does not support), the watch
**registers the app but refuses to load it** — leaving a "ghost": a `SETTINGS/<name>.SET`
with no executable, and a registry entry with version 0. This ghost then **blocks**
clean reinstalls.

The widget dump shows it: the app appears in `GARMIN/APPS/OUT.BIN` (the master app
registry) with the right app id and name but `version=00` and no `DATA/<name>.*`.

Recover:
1. Delete the ghost settings file on the watch: `GARMIN/APPS/SETTINGS/<name>.SET`
   (it was named after the .prg you copied, e.g. `release.SET`).
2. **Restart the watch** (power off/on) — the registry is cached in firmware; a restart
   forces a re-scan and drops the dead entry.
3. Copy the current `bin/BMWWIDGET.PRG` into `GARMIN/APPS/` and **safe-eject**.

The widget only ever needs **Communications + Background** permissions (both supported
on fēnix 6). Never add `PersistedContent` or other unsupported permissions.

### ⚠ Stuck on "Press START to connect" after install?

This means the app is reading an **empty clientId** — almost always from **stale
persisted settings** left by a previous install (especially the generic
no-clientId build). The XML clientId default only applies on first install;
a persisted empty value overrides it, and **reinstalling the `.prg` does NOT clear
it**.

Fix: delete the persisted SETTINGS + DATA (the build script does this automatically
when it auto-copies, but to do it by hand):

```sh
rm /Volumes/*/GARMIN/APPS/SETTINGS/GRM_BMW_WIDGET.SET
rm /Volumes/*/GARMIN/APPS/DATA/GRM_BMW_WIDGET.*
```

Then reinstall. Same applies to the **simulator** — wipe its store with
`rm -rf "$TMPDIR/com.garmin.connectiq"` before loading, or it caches the empty value.

## First-run flow (cold start)

1. Open the widget → "Press START to connect".
2. START → device-flow auth shows a user code.
3. Approve it at `customer.bmwgroup.com` in a browser.
4. The widget then automatically: discovers your VIN → creates its data containers
   (full + lean background) → fetches basicData + telematicData → shows your car.

No VIN or container ID typing required.

## Store build vs. personal build

| | Store build (`monkey.jungle`) | Personal build (`livetest.jungle`) |
|---|---|---|
| Resources | `resources` only | `resources` + `resources-livetest` (your clientId) |
| Credentials | user enters in phone settings | baked from the override |
| Use | publishable, generic | your watch only |

The two share **all source** — only the resource override differs.
