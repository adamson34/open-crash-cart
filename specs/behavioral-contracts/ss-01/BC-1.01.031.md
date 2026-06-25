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
# Behavioral Contract BC-1.01.031: UVC Menu Connect Tears Down Prior Adapter First

## Description
`menuConnectUVC` tears down the currently connected adapter (if any) before starting a UVC session: it fires a non-awaited `Task { await current.disconnect() }`, cancels the current `eventTask`, nils `adapter`, sets `connecting=true`, resets `didAutoSize`, and shows the `.connecting` placeholder. Only then is the `UVCAdapter` created and `connect()` awaited.

## Preconditions
1. User selected a UVC device from the submenu.
2. `adapter` may be a StarTech adapter or another UVC adapter.

## Postconditions
1. If `adapter != nil`: a disconnect Task is fired (not awaited).
2. `eventTask?.cancel()` is called.
3. `adapter = nil`, `connecting = true`, `didAutoSize = false`.
4. `showPlaceholder(.connecting)` is called.
5. A new `UVCAdapter` is created and its `connect()` is awaited in a new Task.
6. On UVC connect success: `connecting = false`; event loop entered.
7. On UVC connect failure: full reset (connecting=false, adapter=nil, `.noAdapter`).

## Invariants
1. `didAutoSize` is reset so the new UVC session gets its own auto-size.
2. The prior adapter's disconnect is non-blocking (fire-and-forget).
3. No two sessions are active simultaneously (adapter=nil before new assignment).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | No prior adapter when UVC selected | Disconnect Task no-op; rest proceeds |
| EC-002 | UVC device removed before connect completes | `connect()` throws; full reset |
| EC-003 | StarTech adapter active when UVC selected | StarTech disconnect fired; UVC session started |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Active StarTech, user selects UVC | StarTech disconnect fired; UVC session started | happy-path |
| No prior adapter, UVC selected | UVC session started directly | edge case |

## Error Handling
UVC connect errors: `connecting=false, adapter=nil`, status bar message, `.noAdapter`.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:218-239 |
| Ingest BC | BC-110 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
