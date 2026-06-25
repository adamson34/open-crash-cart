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
# Behavioral Contract BC-1.01.021: tryConnect Idempotent Guard

## Description
`AppController.tryConnect()` is a single-flight guard: it returns immediately without starting a new connection attempt if either `adapter != nil` (a session is already established) or `connecting == true` (a handshake is in flight). This prevents duplicate adapter instances from being created when the 2-second rescan timer fires while a connection is already active or in progress.

## Preconditions
1. `tryConnect()` is called from the main actor (either synchronously at launch or from the timer callback).
2. `adapter` and `connecting` may be in any combination of states.

## Postconditions
1. If `adapter != nil`: returns immediately; no discovery, no new adapter, no state change.
2. If `connecting == true`: returns immediately; same conditions.
3. If `adapter == nil && connecting == false`: proceeds with discovery.

## Invariants
1. At most one connection attempt is in flight at any time.
2. The guard is purely state-based; no I/O is performed before it.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Timer fires while connected | `adapter != nil` → immediate return |
| EC-002 | Timer fires during handshake | `connecting == true` → immediate return |
| EC-003 | Both `adapter != nil` and `connecting == true` | First condition matches; immediate return |
| EC-004 | `adapter == nil, connecting == false`, no device found | Discovery finds nothing; `showPlaceholder(.noAdapter)` |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `adapter=nil, connecting=false`, device found | New adapter created, `connecting=true` | happy-path |
| `adapter` set | Returns immediately; no discovery | edge case |
| `connecting=true` | Returns immediately; no discovery | edge case |

## Error Handling
No errors thrown from `tryConnect`; all async errors are handled in the `Task` closure it creates.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:173-174 |
| Ingest BC | BC-100 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
