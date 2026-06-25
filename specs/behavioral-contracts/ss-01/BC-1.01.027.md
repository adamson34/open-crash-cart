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
# Behavioral Contract BC-1.01.027: applicationWillTerminate Cancels Task and Fire-and-Forget Disconnect

## Description
`applicationWillTerminate` cancels the event-consuming `Task` (`eventTask?.cancel()`) and then fires a non-awaited `Task { await adapter?.disconnect() }`. The disconnect is fire-and-forget: the function returns without waiting for it to complete, which means teardown may not finish if the process exits before the async disconnect runs. This is a known risk.

## Preconditions
1. `applicationWillTerminate` is called by AppKit during the termination sequence.
2. `adapter` may or may not be set.
3. `eventTask` may or may not be set.

## Postconditions
1. `eventTask?.cancel()` is called synchronously.
2. A new detached `Task` is created that calls `adapter?.disconnect()` asynchronously.
3. The function returns without awaiting the disconnect Task.
4. The disconnect Task may or may not complete before the process exits.

## Invariants
1. The event Task is always cancelled before the disconnect Task is spawned.
2. No crash occurs if `adapter` is nil (optional chaining).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `adapter == nil` at termination | Disconnect Task is no-op; no crash |
| EC-002 | `eventTask == nil` | Cancel is no-op |
| EC-003 | Process exits before disconnect completes | USB device left open by kernel; OS reclaims it |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Normal quit with active adapter | Task cancelled; disconnect fired (may complete) | happy-path |
| Quit with no adapter | Both operations are no-ops | edge case |

## Error Handling
No error handling in this path; disconnect failure is silently tolerated.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:139-143 |
| Ingest BC | BC-106 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | documentation / inferred |
