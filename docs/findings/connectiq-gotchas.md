# Connect IQ / Monkey C — constraints & traps

Platform limits and battle-tested gotchas hit while building this widget for **fēnix 6
Pro (System 5)**. These shaped the architecture as much as the BMW API did.

## Hard platform limits

| Limit | Value | Impact |
|---|---|---|
| Background process memory | **~32 KB** (fēnix 6 / 6X Pro) | The tightest budget in the app: the CarData fetch + JSON parse + cache write all run here. The prime constraint for any perf work. |
| Widget (foreground) memory | ~64 KB | Page views, settings menus, glance. |
| `Application.Storage` | **~128 KB total, ~8 KB per key** | The Vehicle State dict and any buffer must fit. A multi-entry buffer in one key overflows the per-key cap. |
| Filesystem | **no arbitrary file-write API** for 3rd-party apps | Persistence is `Application.Storage` (key/value) or FIT files (numeric only). A literal on-watch JSON log isn't possible. |

**Consequences baked into the design:** parse-and-discard (null the raw response right
after parsing; never retain the full JSON), keep the cache lean, and treat the 32 KB
background ceiling — not CPU — as the scaling limit.

## Dual-scope (`:background`) rule — the #1 startup crasher

The `(:background)` process loads **only** `(:background)`-tagged classes. Anything the
service delegate or `onBackgroundData` transitively touches must be tagged, or you get:

```
Error: Illegal Access (Out of Bounds)   ← native VM fault, NOT catchable by try/catch
  Class not available to 'Background'
```

- The crash may point at a **foreground** line — because the *background copy* of the
  same app class can't load a dependency. The line number misleads; the **missing class**
  is the culprit.
- Fix: add `(:background)` to that class (additive — foreground still sees it). Debug-only
  classes: `(:debug :background)`.
- Audit: `grep -L "(:background)" source/<service+api+cache+guard+StorageKeys>`.

## Monkey C language traps

| Symptom | Cause | Fix |
|---|---|---|
| `String has no method 'compareTo'` (and many Java methods) | Monkey C strings are minimal | Convert to comparable primitives (e.g. ISO timestamp → epoch `Number`). |
| `Symbol Not Found` on a `static const` array | Static const arrays can be typed `Object` at runtime | Use named, typed locals; avoid `Object`-typed array subscripts. |
| `v.indexOf` / `.keys()` crash on a dict value | Dict values come back typed **`Object`**, not `String`/`Array` | Re-read into a typed local first; in callbacks, params are always `Object`. |
| `substring` type crash | type inference loses the `String` type across calls | Pin the type (named `String` local) before calling `substring`. |
| try/catch doesn't stop a crash | `Illegal Access (Out of Bounds)` is a native fault | Fix the root cause — it's not catchable. |

> The compiler also emits noisy *"Cannot determine if container access is using container
> type"* **warnings** on untyped `Dictionary` access (`dict[key]`). They're benign and
> pervasive in this codebase's parse/render paths.

## Connectivity / error surface

- `responseCode == -104` is **`Communications.BLE_CONNECTION_UNAVAILABLE`** — no phone
  link. Pre-flight `System.getDeviceSettings().phoneConnected` and map negative
  `responseCode`s to a friendly message; never show the raw number to the user.
- Three distinct error layers to keep separate: **transport** (negative `responseCode`),
  **HTTP** (`401` refresh, `429` quota), and **CarData app codes** (`CU-xxx`).

## Simulator & sideload gotchas

- **Stale persisted Storage** survives a sim restart — the sim reloads app Storage from
  disk. Old behaviour after a code change often means stale storage, not your change.
  Hard-wipe: `rm -rf "$TMPDIR/com.garmin.connectiq"`.
- **Orphaned `monkeydo`/shell** holds the sim's TCP ports (1234/1235) → app hangs on load.
  `pkill -f "monkeydo "; pkill -f MonkeyDoDeux`.
- **Empty `clientId` from stale settings** — a persisted empty value overrides the XML
  default and reinstalling the `.prg` does **not** clear it; delete the on-watch/sim
  `SETTINGS`/`DATA` for the app id.
- **"Poisoned app slot"** (real watch): repeated *failed* installs of the same app id
  (e.g. a build requesting an unsupported permission like `PersistedContent`, which
  fēnix 6 doesn't support) poison that id's registry slot — the watch then rejects every
  later install under it. Fix: assign a **fresh app id** (`uuid4().hex`) in `manifest.xml`
  and install under a distinct filename. This widget needs only **Communications +
  Background** permissions.

## Working principle

**Instrument first, guess never.** Drop a `System.println` at the decision point, rebuild,
watch the log — two log lines beat an hour of theories. Remove all prints before
committing (`grep -rn "System.println" source/`).
