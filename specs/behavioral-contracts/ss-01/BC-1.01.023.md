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
# Behavioral Contract BC-1.01.023: connecting Flag Spans Entire Async Handshake

## Description
`connecting` is set to `true` before `adapter.connect()` is awaited and cleared to `false` immediately after `connect()` returns — whether by success or by thrown error. This flag spans the entire async handshake, preventing the 2-second rescan timer from launching a second connection attempt while the first is still awaiting the USB open + thread start.

## Preconditions
1. `tryConnect()` passed its guard and found a device.
2. `connecting` is currently `false`.

## Postconditions
1. `connecting = true` is set synchronously before `Task { … }` begins awaiting `adapter.connect()`.
2. On success: `connecting = false` is set after `connect()` returns and before entering the event loop.
3. On error: `connecting = false` is set in the `catch` block before any cleanup.

## Invariants
1. There is no code path through the Task closure that exits with `connecting == true` and no adapter active (except the moment inside `connect()` itself).
2. The guard at `tryConnect()` entry relies on this invariant.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `connect()` throws immediately | `connecting = false` in catch; `adapter = nil`; placeholder shown |
| EC-002 | Timer fires during `connect()` await | `connecting == true`; timer call is a no-op |
| EC-003 | `connect()` succeeds | `connecting = false` set; event loop entered |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Successful connect | `connecting`: false→true (during connect)→false (after) | happy-path |
| `connect()` throws | `connecting=false`, `adapter=nil`, `.noAdapter` shown | error |

## Error Handling
`catch` block: `connecting = false`, `adapter = nil`, `statusBar.setMessage(error)`, `showPlaceholder(.noAdapter)`.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:180-194 |
| Ingest BC | BC-102 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
