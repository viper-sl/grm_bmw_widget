# Findings & investigations

Durable, hard-won knowledge distilled from this project's research, the live BMW CarData
capture campaign, and the debugging sessions — kept here so it survives independently of
the internal planning artifacts it was mined from.

| Doc | What's in it |
|---|---|
| [bmw-cardata-api.md](bmw-cardata-api.md) | Verified BMW CarData API behaviour — OAuth device flow, the mandatory `x-version: v1` header, endpoints, the container model, response shape, quota, and the `CU-xxx`/`TP-xxx` error codes. |
| [descriptor-semantics.md](descriptor-semantics.md) | What the telematics descriptors *actually* do on a real car: fields that never populate (ignition/motion), enum quirks (`INTERMEDIATE` windows, lock states), the frozen `remainingFuel`, tyre-pressure logic, and multi-powertrain range selection. |
| [connectiq-gotchas.md](connectiq-gotchas.md) | Connect IQ / Monkey C platform limits (~28 KB background budget, 8 KB/key storage, no file-write API) and the traps that cost real time — the `:background` scope rule, the background-poll `-403` OOM (fixed via a lean container), Monkey C type crashes, BLE error codes, and sim/sideload pitfalls. |

## Related (elsewhere in the repo)

- [../ARCHITECTURE.md](../ARCHITECTURE.md) — the current architecture: process/component map, two-container model, flows, token FSM, rate-limit/quota, storage keys (with diagrams in [../diagrams/](../diagrams/)).
- [../descriptors.md](../descriptors.md) — the curated descriptor subscription set (the widget's source of truth) with observed values.
- [../reference/cardata-catalogue.md](../reference/cardata-catalogue.md) — the full BMW CarData descriptor catalogue.
- [../garmin-connect-iq-api.md](../garmin-connect-iq-api.md) — generic Connect IQ API/module reference.

> Tested vehicle: an ICE BMW 218i (G42). Behaviour can differ by model, powertrain, and
> account/contract tier — treat "never populates / always null" as *observed on this
> vehicle*, not a guarantee.
