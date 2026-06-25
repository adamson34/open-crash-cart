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
# Behavioral Contract BC-1.01.022: No-Device Cleans State and Shows noAdapter

## Description
When `tryConnect()` finds no matching device (discovery returns an empty list or `makeAdapter` returns nil), the placeholder view is set to `.noAdapter` if and only if no connection is already in progress and no adapter is currently set. No error is raised; the next rescan timer fire will retry automatically.

## Preconditions
1. `tryConnect()` passed the `adapter == nil && !connecting` guard.
2. `discoverProfiledDevices()` returns an empty list, or `makeAdapter(for:profile:)` returns nil.

## Postconditions
1. `showPlaceholder(.noAdapter)` is called.
2. `adapter` remains nil.
3. `connecting` remains false.
4. No log or error message is emitted.

## Invariants
1. The no-device path does not change `connecting` or `adapter`.
2. The placeholder is always set to `.noAdapter` (not `.connecting`) in this path.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Discovery list empty | `showPlaceholder(.noAdapter)` called |
| EC-002 | `makeAdapter` returns nil for found device | Same outcome |
| EC-003 | Called repeatedly with no device present | Placeholder is set idempotently each time |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| No device on bus | Placeholder shows `.noAdapter`; `adapter=nil` | happy-path (no device) |
| Device found but profile mismatch | Placeholder shows `.noAdapter` | edge case |

## Error Handling
No errors thrown. Clean state is maintained for the next rescan.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:176-178 |
| Ingest BC | BC-101 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
