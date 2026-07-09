# Publishing to the Connect IQ Store

How to package and publish **BMW Status** to the [Connect IQ Store](https://apps.garmin.com/).
This doc is **only** about the store path — generic/distributable build, the `.iq`
package, and the developer-dashboard submission.

> For building onto **your own watch** (clientId baked in, sideload), see
> [PERSONAL-BUILD.md](PERSONAL-BUILD.md). That is a different app ID and a different
> jungle, and is never published.

## Store build vs. personal build

| | **Store build** (`iq.jungle`) | Personal build (`livetest.jungle`) |
|---|---|---|
| Manifest | `manifest-iq.xml` | `manifest.xml` |
| App ID | `0a54403f6fef458a96fca6f8a147f299` | `7f673698b206464a8e918654edcfeb6c` |
| Resources | `resources` + per-tier `resources-modes-*` | `resources` + `resources-livetest` + per-tier `resources-modes-*` |
| Credentials | **user enters in Garmin Connect Mobile** | clientId baked from override |
| Output | `bin/BMWWIDGET.iq` (signed package) | `bin/*.prg` (sideload) |
| Goal | publishable, generic | your watch only |

The two app IDs are deliberately different so the published widget and your personal
sideload can **coexist on the same watch** without colliding.

The store build ships **no hardcoded credentials**. Each user supplies their own BMW
CarData **clientId** through the widget's settings in the Garmin Connect Mobile app;
VIN auto-discovers and the data containers (full + lean background) auto-create on first
run (see the README).

## What gets published

| Field | Value | Source |
|---|---|---|
| App name | `BMW Status` | `@Strings.AppName` |
| Type | `widget` | `manifest-iq.xml` |
| Entry | `BmwWidgetApp` | `manifest-iq.xml` |
| Min SDK | `3.4.0` | `manifest-iq.xml` |
| Launcher icon | `@Drawables.LauncherIcon` (`resources/drawables/launcher_icon.png`) | `manifest-iq.xml` |
| Permissions | `Communications`, `Background` | `manifest-iq.xml` |
| Languages | `eng` | `manifest-iq.xml` |

## Device coverage (the gotcha)

`manifest-iq.xml` lists each supported `<iq:product>`, but the IQ package builder
**requires every listed device to have its SDK profile installed locally** (Connect IQ
SDK Manager → Devices). A device without an installed profile fails the build.

To keep `--iq` building out of the box, `manifest-iq.xml` currently has **only the
locally-installed devices uncommented** (`fenix6pro`, `fr255`); the full fēnix 6/7/8/E,
MARQ, and Forerunner list is present but commented out.

To widen store coverage:

1. Connect IQ SDK Manager → **Devices** → install the profiles you want.
2. Un-comment the matching `<iq:product>` lines in `manifest-iq.xml`.
3. **If the device is API 6.0+** (fēnix 8 family, fēnix E, FR970, and future
   full-tier devices): add its `excludeAnnotations = manualOnly` and
   `resourcePath = resources;resources-modes-full` stanzas to `iq.jungle`
   (copy an existing fenix8 pair). Devices without a stanza fall to the
   legacy tier — manual + daily refresh only, no Update Mode setting.
4. Rebuild the `.iq` (below) — it now contains those devices.

> Keep `manifest.xml` (personal/local) and `manifest-iq.xml` (store) device lists in
> sync intentionally; they don't have to match, but divergence is easy to forget.

## Build the `.iq` package

The `.iq` is the **single file you upload** to the store. It's a release build, signed
with your `developer_key`, covering every installed/uncommented device.

```sh
./build-personal.sh --iq          # → bin/BMWWIDGET.iq
```

Under the hood (so you can run it manually):

```sh
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"
java -jar "$SDK/bin/monkeybrains.jar" \
  -o bin/BMWWIDGET.iq \
  -f iq.jungle \
  -y developer_key \
  -e -r
```

- `-e` exports a packaged `.iq` (multi-device) rather than a single-device `.prg`.
- `-r` is a **release** build (no debug symbols).
- `-f iq.jungle` selects `manifest-iq.xml` + `resources` + the per-tier
  `resources-modes-legacy`/`-full` settings (no personal override).

Prereqs: the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and a
`developer_key` (the same key must sign every update — see Versioning).

### Test the package before submitting

You can sideload the `.iq` to a real watch via the **Connect IQ phone app → My Device
Apps → Sideload Widget** to verify it runs (and that it coexists with any personal
build) before you ever upload it to the store.

## Pre-submit checklist

- [ ] **Release build** (`-r`). Don't ship a debug build.
- [ ] **No `(:debug)` symbol leaks.** Plain (non-annotated) helpers in `source/Tests.mc`
      compile into release builds; if one references a `(:debug)`-only symbol (e.g.
      `MockData`) the release build breaks. Annotate such helpers `(:debug)`. Confirm a
      clean `-r` build before packaging.
- [ ] **No hardcoded credentials.** The store build must never include
      `resources-livetest` (`resources` + `resources-modes-*` are expected — they
      hold the per-tier settings). Confirm `iq.jungle` is the jungle in use.
- [ ] **Permissions are exactly** `Communications` + `Background`. Don't add
      unsupported permissions (e.g. `PersistedContent` is unsupported on fēnix 6).
- [ ] **Every listed device** in `manifest-iq.xml` has its SDK profile installed (else
      the build fails or silently drops it).
- [ ] Unit tests pass (see [TESTING.md](TESTING.md)).

## Submit to the store

The store side is done in Garmin's web dashboard, not in this repo:

1. Sign in to the **[Connect IQ developer dashboard](https://apps.garmin.com/developer/dashboard)**
   with the Garmin account tied to your `developer_key`.
2. **Upload App** → choose `bin/BMWWIDGET.iq`.
3. Fill the store listing (have these ready):
   - **App name / category** — `BMW Status`, category *Widget*.
   - **Short + long description** — what it does, that a BMW CarData clientId is
     required, and the on-watch pairing flow.
   - **Screenshots** — from the simulator or watch (glance + each page).
   - **Store icon** — separate from the in-app launcher icon; Garmin specifies the
     dimensions in the upload form.
   - **Support contact / privacy** — note that data goes only to BMW's own API and
     nothing is collected (see README → Privacy).
   - **"Not affiliated with BMW or Garmin"** disclaimer (already in the README).
4. Submit for review. Garmin reviews before the listing goes live.

## Versioning / updates

- The **same `developer_key`** must sign every update — losing it means you can't
  publish updates under this app ID. Back it up (it's gitignored).
- The **app ID in `manifest-iq.xml` must stay constant** (`0a54403f6fef458a96fca6f8a147f299`)
  so users get it as an update rather than a new app. Don't regenerate it.
- Bump the app's version in the dashboard for each release; rebuild the `.iq` and
  re-upload.

## Gotchas

- **`-e` is required** for a store package. A plain `-d <device>` build produces a
  single-device `.prg` you cannot upload as a multi-device store app.
- **Empty/stale settings** are a user-side first-run trap, not a packaging one, but
  worth knowing: a user who previously sideloaded a no-clientId build can have stale
  persisted settings. On the store app each user just enters their clientId in Garmin
  Connect Mobile.
- **Don't publish `manifest.xml`'s app ID.** That's the personal/local ID; publishing
  it would collide with sideload installs.
