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
# Behavioral Contract BC-1.01.024: Connect-Fail Full Reset

## Description
When `adapter.connect()` throws an error, `AppController` performs a full state reset: clears `connecting`, nils `adapter`, updates the status bar with the error message, and shows the `.noAdapter` placeholder. This leaves the session in the same clean state as before any connection attempt, allowing the 2-second rescan timer to retry.

## Preconditions
1. `tryConnect()` started a connection attempt (adapter stored, `connecting=true`).
2. `adapter.connect()` threw an error (USB open failure, claim failure, etc.).

## Postconditions
1. `connecting = false`.
2. `adapter = nil`.
3. `statusBar.setMessage("Connect failed: \(error)")` is called.
4. `showPlaceholder(.noAdapter)` is called.
5. The `eventTask` variable is implicitly abandoned (the Task scope ends).

## Invariants
1. After a connect failure, the state is indistinguishable from startup with no device found.
2. The rescan timer continues running and will retry on the next 2-second tick.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `USBTransportError.deviceNotFound` thrown | Full reset; retry after 2s |
| EC-002 | `USBTransportError.openFailed(rc)` thrown | Full reset; status bar shows rc-specific message |
| EC-003 | Device present but interface claim fails | Full reset; same behavior |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `connect()` throws `.deviceNotFound` | `adapter=nil, connecting=false`, status "Connect failed: device no longer present…" | error |
| `connect()` throws `.openFailed(-3)` | Same reset + message with rc | error |

## Error Handling
All errors from `connect()` are caught here; none propagate to the caller.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:189-194 |
| Ingest BC | BC-103 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
