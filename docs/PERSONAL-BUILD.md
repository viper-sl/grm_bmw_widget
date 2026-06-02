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
| **containerId** | Auto-created via `POST /customers/containers` on first run |

## Setup (one-time)

1. Put your client ID in the gitignored override
   `resources-livetest/properties/properties.xml`:
   ```xml
   <?xml version="1.0"?>
   <properties>
     <property id="clientId" type="String">YOUR_CLIENT_ID</property>
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

## First-run flow (cold start)

1. Open the widget → "Press START to connect".
2. START → device-flow auth shows a user code.
3. Approve it at `customer.bmwgroup.com` in a browser.
4. The widget then automatically: discovers your VIN → creates the data container →
   fetches basicData + telematicData → shows your car.

No VIN or container ID typing required.

## Store build vs. personal build

| | Store build (`monkey.jungle`) | Personal build (`livetest.jungle`) |
|---|---|---|
| Resources | `resources` only | `resources` + `resources-livetest` (your clientId) |
| Credentials | user enters in phone settings | baked from the override |
| Use | publishable, generic | your watch only |

The two share **all source** — only the resource override differs.
