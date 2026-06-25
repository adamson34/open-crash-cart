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
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.028: .disconnected Event Re-Arms Rescan and Resets didAutoSize

## Description
When `handle(_:)` processes an `.disconnected` event from the adapter stream, it clears `adapter` and `eventTask`, resets `didAutoSize` to false, and shows the `.noAdapter` placeholder. The already-running 2-second rescan timer then drives reconnection on the next tick. `didAutoSize` is reset so the window will resize again to fit the new session's resolution when it reconnects.

## Preconditions
1. An `.disconnected(reason:)` event is received from the adapter's event stream.
2. The event arrives on the main actor via the `handle` function.

## Postconditions
1. `statusBar.setMessage("Disconnected: \(reason) — rescanning…")` is called.
2. `window.title = "OpenCrashCart"` (title cleared).
3. `adapter = nil`.
4. `eventTask = nil`.
5. `didAutoSize = false`.
6. `showPlaceholder(.noAdapter)` is called.
7. The rescan timer continues running; no explicit re-arm action needed.

## Invariants
1. `didAutoSize` is always false after a disconnect event.
2. `adapter` and `eventTask` are always nil after a disconnect event.
3. The rescan timer is never stopped or restarted by this handler.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Device reconnects within the same 2s interval | Next timer tick calls `tryConnect`; may reconnect quickly |
| EC-002 | Multiple `.disconnected` events (if stream bug) | Each applies the same reset idempotently |
| EC-003 | `adapter == nil` when event arrives (race) | nil assignment is a no-op |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `.disconnected(reason: "Device disconnected")` | Status "Disconnected: Device disconnected — rescanning…", `.noAdapter` shown | happy-path |

## Error Handling
No errors thrown from the disconnect handler.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:268-274 |
| Ingest BC | BC-107 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | assertion |
