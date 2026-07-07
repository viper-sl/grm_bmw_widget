#!/usr/bin/env python3
"""
BMW CarData — container-cap probe
─────────────────────────────────
Creates throwaway containers until BMW rejects the create, capturing the EXACT
rejection (HTTP status + body, incl. exveErrorId) so the watch app can match the
real "container limit reached" error. Then DELETES every container THIS script
created — even on error / Ctrl-C.

Each container is created with a single KNOWN-GOOD descriptor
(`vehicle.cabin.door.lock.status`), so any failure is the per-account cap (or
auth / rate-limit) — never an "invalid descriptor" (CU-401) error.

Auth + endpoints are reused from bmw_cardata_probe.py (saved bmw_tokens.json,
auto-refresh, device-flow fallback).

QUOTA: uses 1 (list) + N (creates incl. the rejected one) + M (deletes of what it
created) data calls — counts against the ~50/day limit. The account is likely
already near the cap from prior versions, so N is usually small.

Usage:
    pip install requests
    python3 bmw_container_cap_probe.py [--client-id ID] [--max N]
"""

import argparse
import json
import os
import sys
import time

try:
    import requests
except ImportError:
    sys.exit("Missing dependency: pip install requests")

# Reuse auth, endpoints, and token persistence from the existing probe.
from bmw_cardata_probe import ensure_token, DATA_HOST  # noqa: E402

X_VERSION = "v1"
# One descriptor known to be valid (used by the app) → isolates the CAP error from
# any "invalid descriptor" (CU-401) rejection.
SAFE_DESCRIPTORS = ["vehicle.cabin.door.lock.status"]


def _headers(tokens):
    return {
        "Authorization": f"Bearer {tokens['access_token']}",
        "Accept":        "application/json",
        "Content-Type":  "application/json",
        "x-version":     X_VERSION,
    }


def list_containers(tokens):
    r = requests.get(f"{DATA_HOST}/customers/containers",
                     headers=_headers(tokens), timeout=20)
    try:
        body = r.json()
    except Exception:
        body = {}
    d = body.get("data", body) if isinstance(body, dict) else {}
    out = []
    containers = d.get("containers", []) if isinstance(d, dict) else []
    for c in containers:
        if isinstance(c, dict):
            cid = c.get("containerId") or c.get("id")
            if cid:
                out.append((cid, c.get("name")))
    return r.status_code, out


def create_container(tokens, name):
    body = {
        "name":                 name,
        "purpose":              "cap probe (throwaway)",
        "technicalDescriptors": SAFE_DESCRIPTORS,
    }
    r = requests.post(f"{DATA_HOST}/customers/containers",
                      headers=_headers(tokens), json=body, timeout=20)
    try:
        data = r.json()
    except Exception:
        data = {"_raw": r.text[:1000]}
    return r.status_code, data


def delete_container(tokens, cid):
    r = requests.delete(f"{DATA_HOST}/customers/containers/{cid}",
                        headers=_headers(tokens), timeout=20)
    return r.status_code


def main():
    ap = argparse.ArgumentParser(description="BMW CarData container-cap probe")
    ap.add_argument("--client-id", default=os.getenv("BMW_CLIENT_ID"),
                    help="CarData client_id (or BMW_CLIENT_ID env var)")
    ap.add_argument("--max", type=int, default=15,
                    help="max create attempts before giving up (safety bound)")
    args = ap.parse_args()

    print("=" * 64)
    print("  BMW CarData — container-cap probe")
    print("=" * 64)

    tokens = ensure_token(args.client_id or "")

    code, existing = list_containers(tokens)
    print(f"\nExisting containers: {len(existing)}  (HTTP {code})")
    for cid, name in existing:
        print(f"  - {name}  [{cid}]")

    created = []      # ids THIS script created (to delete afterwards)
    cap_error = None  # the rejection that stopped us

    try:
        for i in range(args.max):
            name = f"captest_{int(time.time())}_{i}"
            print(f"\n[create #{i + 1}] {name} …")
            status, data = create_container(tokens, name)
            print(f"  HTTP {status}")
            snippet = json.dumps(data, ensure_ascii=False)
            print("  " + (snippet[:600] + (" …" if len(snippet) > 600 else "")))

            if status in (200, 201):
                cid = (data.get("containerId") or data.get("id")) if isinstance(data, dict) else None
                created.append(cid)
                print(f"  ✓ created  [{cid}]")
            else:
                cap_error = {"http": status, "body": data}
                print("\n  ⚑ CREATE REJECTED — captured response:")
                print(json.dumps(cap_error, indent=2, ensure_ascii=False))
                break
        else:
            print(f"\n  Reached --max={args.max} with no rejection "
                  f"(account was not at the cap).")
    finally:
        # ALWAYS clean up what THIS script created (errors / Ctrl-C included).
        if created:
            print(f"\nCleaning up {len(created)} container(s) created by this script …")
            for cid in created:
                if not cid:
                    continue
                st = delete_container(tokens, cid)
                print(f"  DELETE {cid} → HTTP {st}")
        else:
            print("\nNothing to clean up (this script created no containers).")

    print("\n" + "=" * 64)
    if cap_error:
        body = cap_error["body"]
        eid = body.get("exveErrorId") if isinstance(body, dict) else None
        msg = body.get("exveErrorMsg") if isinstance(body, dict) else None
        print(f"  CAP ERROR:  HTTP {cap_error['http']}   exveErrorId={eid}")
        if msg:
            print(f"              {msg}")
        print("  → Confirm/adjust the cap heuristic in")
        print("    source/api/CarDataBootstrap.mc onCreateContainerResponse")
        print("    (currently: 4xx, not 401/429, not CU-401).")
    else:
        print("  No cap error captured this run.")
    calls = 1 + len(created) + (1 if cap_error else 0) + len(created)
    print(f"  Quota used this run: ~{calls} data calls "
          f"(1 list + {len(created) + (1 if cap_error else 0)} create + {len(created)} delete).")
    print("=" * 64)


if __name__ == "__main__":
    main()
