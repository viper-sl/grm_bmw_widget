# BMW CarData API — verified findings

Empirically verified by hitting the live BMW CarData API with an EU account and an
**ICE BMW 218i (G42, B48C, `driveTrain: CONV`)**. Where this conflicts with the
public/community docs, **the live behaviour wins**. (All VINs / container IDs below are
redacted — they're account-specific.)

## Authentication — OAuth 2.0 Device Flow (public client, PKCE)

- Device code: `POST https://customer.bmwgroup.com/gcdm/oauth/device/code`
- Token:       `POST https://customer.bmwgroup.com/gcdm/oauth/token`
- **Scope (required):** `authenticate_user openid cardata:streaming:read cardata:api:read`
- **PKCE required:** `code_challenge` (S256) + `code_verifier`; `response_type=device_code`.
- Token response: `access_token` (opaque, **~1 h**), `refresh_token` (**~2-week sliding**),
  `id_token` (JWT — MQTT streaming only, **not** the REST bearer), `gcid`, `expires_in`.
- Refresh works via `grant_type=refresh_token`. **Refresh is quota-exempt** (different
  host) — it does not count against the data-API rate limit.

The bearer for data calls is the **`access_token`**, never the `id_token`.

## Data API — `https://api-cardata.bmwgroup.com`

> **Mandatory header on every data call: `x-version: v1`.** Without it → `TP-403`.
> This was the single biggest blocker; it is not obvious from the docs.

Paths use **`/customers/`** (plural). Singular `/customer/` → `CU-403`.

| Endpoint | Method | Result | Use |
|---|---|---|---|
| `/customers/vehicles/mappings` | GET | 200 | VIN discovery (`mappingType: PRIMARY`) |
| `/customers/vehicles/{vin}/basicData` | GET | 200 | Static metadata (model, body, colour…) |
| `/customers/containers` | GET | 200 | List the account's containers |
| `/customers/containers` | POST | 200 | **Create** a container (see body below) |
| `/customers/containers/{id}` | DELETE | 200/204 | Delete a container |
| `/customers/vehicles/{vin}/telematicData?containerId=…` | GET | 200 | Live values for the container's descriptors |
| `/customers/vehicles/{vin}/smartMaintenanceTyreDiagnosis` | GET | 200 | Rich per-tyre data (no container needed) |
| `/customers/vehicles/{vin}/image` | GET | 200 | Vehicle JPEG (needs `Accept: image/*`) |

### Containers

A **container** is a named subscription to a set of descriptors; `telematicData` returns
exactly the descriptors in the referenced container.

```json
POST /customers/containers
{ "name": "my_widget_v1", "purpose": "free text", "technicalDescriptors": ["vehicle.x.y", …] }
```

- The field is **`technicalDescriptors`** — a **flat array of dotted strings**. (Not
  `descriptors`, not objects with `technicalDescriptor` keys — those return `CU-401`.)
- **Max 10 containers per account.** No per-descriptor cap observed (40+ works).
- Descriptor IDs are the catalogue's **"Technical descriptor"** column
  (`vehicle.domain.sub.field`), *not* the `bmwcardata_*` stream-name column.
- Changing the descriptor set means a **new container** — this app stamps the container
  with a version name and re-creates on change (see the architecture's container-versioning).

### `telematicData` response shape

```json
{ "telematicData": {
    "<technical.descriptor>": { "timestamp": "ISO8601|null", "unit": "str|null", "value": "str|null" }
} }
```

## Parsing learnings (these shaped the client)

1. **Every `value` is a STRING** — even numbers (`"95"`, `"653"`) and booleans/enums
   (`"SECURED"`, `"CLOSED"`, `"km"`). The parser casts per field.
2. **Per-field timestamps**, not one snapshot — fields in the same response can differ by
   days. "Data age" must be derived from the **newest** timestamp across shown fields.
3. **A descriptor in the container does NOT guarantee a value** — many come back
   `{value:null, timestamp:null}`. Treat null as *absent* and hide it.
4. **Payloads are tiny** (~1.5 KB for 12 descriptors; a few KB for 40) — comfortably
   under the background-process limits.

## Quota

- **~50 REST data calls / 24 h** on `api-cardata.bmwgroup.com`; exceeding → `CU-429`.
- Token **refresh** (on `customer.bmwgroup.com`) is **exempt**.
- `GET`/`POST`/`DELETE` on containers each cost a data call — discovery tooling should be
  idempotent (reuse, don't recreate).

## Observed error codes

| Code | Meaning | Cause seen |
|---|---|---|
| `TP-403` | Forbidden | missing `x-version: v1` header |
| `CU-400` | Bad request | `telematicData` without `containerId` |
| `CU-401` | Parameter invalid | wrong container body shape |
| `CU-403` | Forbidden | singular `/customer/` path |
| `CU-105` | No permission for containerId | container deleted / wrong VIN → re-bootstrap |
| `CU-124` | Max containers reached | account at the 10-container cap on `POST /containers` (HTTP 403); delete one to create. Verified live 2026-06-19. |
| `CU-429` | Rate limit | > ~50 calls/day (HTTP **403**, not 429) |
| `CU-127` | No LBCS data | ICE has no location-based charging (expected) |

## Bonus data (beyond the widget's core needs)

- **Tyre diagnostics** (`smartMaintenanceTyreDiagnosis`): per-tyre brand, dimension,
  season, mounting date, and a wear/`dueMileage` estimate. Separate REST endpoint, no
  container.
- **Vehicle image**: a real JPEG (~170 KB).
