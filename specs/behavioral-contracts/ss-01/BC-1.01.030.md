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
# Behavioral Contract BC-1.01.030: Device Adjustments Cached Not Pushed to Live Sliders

## Description
When a `.status` event contains non-empty `adjustments`, `AppController` stores them in `latestAdjustments` but does NOT push them to the `VideoAdjustPanel` sliders if the panel is open. Adjustments are only applied to the slider panel when it is opened via `toggleVideoAdjust()`. This prevents knob-jump while a drag or the device's auto-fine-tune is in progress.

## Preconditions
1. A `.status(status)` event is received with `!status.adjustments.isEmpty`.
2. `VideoAdjustPanel` may or may not be open.

## Postconditions
1. `latestAdjustments = status.adjustments` is updated.
2. The `adjustPanel` sliders are NOT updated in response to this event.
3. When `toggleVideoAdjust()` opens the panel: `panel.apply(latestAdjustments)` is called.

## Invariants
1. `latestAdjustments` always reflects the most recent non-empty device adjustments.
2. The panel never receives a mid-drag update; it only syncs on open.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `status.adjustments` is empty | `latestAdjustments` not updated |
| EC-002 | Panel is open when status arrives | No update pushed to sliders |
| EC-003 | Panel opened after disconnect | `latestAdjustments` holds last known values; applied on open |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Status with `adjustments[.phase] = 10` | `latestAdjustments[.phase] = 10`; panel sliders unchanged | happy-path |
| Open adjust panel after that | Sliders show phase=10 | happy-path (apply on open) |

## Error Handling
No errors. Cache update is a simple assignment.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:248-255, 543 |
| Ingest BC | BC-109 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | documentation / assertion |
