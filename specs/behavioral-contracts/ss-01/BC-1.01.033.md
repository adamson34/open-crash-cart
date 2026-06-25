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
# Behavioral Contract BC-1.01.033: Reconnect Triggers Immediate Rediscovery; Disconnect Leaves Rescan Running (Current Defect)

## Description
`menuReconnect` immediately tears down the current session and calls `tryConnect()` synchronously, forcing an immediate rediscovery without waiting for the next 2-second timer tick. `menuDisconnect` tears down the session and shows `.noAdapter` but does NOT stop the rescan timer — the 2-second timer continues firing `tryConnect()` which will reconnect within 2 seconds if the device is still present. This means "Disconnect" does not keep the device disconnected in the current implementation; it is auto-undone by the timer. This is a known defect (see BC-1.01.034 for the v1.1.0 correction).

## Preconditions
1. `menuReconnect()` or `menuDisconnect()` is called by the user.
2. `adapter` may be set or nil.

## Postconditions (menuReconnect)
1. If `adapter` set: `Task { await adapter.disconnect() }` fired.
2. `adapter = nil`, `eventTask = nil`, `connecting = false`, `didAutoSize = false`.
3. `showPlaceholder(.noAdapter)`.
4. `tryConnect()` called synchronously — may start a new session immediately.

## Postconditions (menuDisconnect, current behavior)
1. Same teardown as Reconnect (steps 1-3 above).
2. `tryConnect()` is NOT called explicitly — but the running `rescanTimer` will call it within 2 seconds.
3. If the device is still present, auto-reconnect occurs within ≤2 seconds.

## Invariants (current)
1. Reconnect always forces an immediate retry via `tryConnect()`.
2. Disconnect does not stop the rescan timer; auto-reconnect is unavoidable without a userDisconnected flag (see BC-1.01.034).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Reconnect while not connected | `adapter=nil` already; `tryConnect()` proceeds immediately |
| EC-002 | Disconnect while not connected | Teardown is idempotent; `adapter=nil` already |
| EC-003 | Disconnect, wait 2s | Device reconnects automatically (defect) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| User clicks Reconnect | Immediate teardown + immediate tryConnect() | happy-path |
| User clicks Disconnect, device still present | Disconnect, then auto-reconnect within 2s (defect) | edge case (defect) |

## Error Handling
No errors thrown from either menu action.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:397-407 |
| Ingest BC | BC-112 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | inferred |
