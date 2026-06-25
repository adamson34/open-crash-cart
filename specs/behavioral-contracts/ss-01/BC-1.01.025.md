---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ/AppController.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.025: 2-Second Rescan as Sole Auto-Reconnect Driver

## Description
The sole mechanism for automatic reconnection is a repeating `Timer` with a 2.0-second interval that calls `tryConnect()`. On app launch, `tryConnect()` is also called once synchronously before the timer starts. No other code path triggers an automatic connection attempt. If the device disappears and reappears, the next timer fire will discover it.

## Preconditions
1. `applicationDidFinishLaunching` has been called.
2. `rescanTimer` has been created with `repeats: true, timeInterval: 2.0`.

## Postconditions
1. At app launch: `tryConnect()` is called once synchronously at :126.
2. `rescanTimer` fires every 2.0 seconds and calls `tryConnect()`.
3. No other mechanism calls `tryConnect()` automatically (except `menuReconnect` which is user-initiated and calls it explicitly).

## Invariants
1. The rescan interval is exactly 2.0 seconds.
2. `rescanTimer` is the only timer that drives auto-reconnection.
3. `tryConnect()` is idempotent; multiple fires while connected are safe (BC-1.01.021).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Device appears between two timer ticks | Detected at the next 2s tick |
| EC-002 | Timer fires while in `.live` state | `tryConnect()` guard returns immediately (adapter != nil) |
| EC-003 | `OCC_SECONDS` expires before device found | App terminates (BC-1.01.026) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Device plugged in at t=1.5s after launch | Detected at ~t=2.0s timer tick | happy-path |
| Device already present at launch | `tryConnect()` sync call at t=0 connects immediately | happy-path |

## Error Handling
No errors; timer fires are best-effort. If `tryConnect()` fails, it self-resets and the next tick retries.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:126-129 |
| Ingest BC | BC-104 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | documentation / assertion |
