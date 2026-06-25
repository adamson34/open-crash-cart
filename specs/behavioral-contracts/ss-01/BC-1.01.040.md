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
# Behavioral Contract BC-1.01.040: Relative Mouse Toggle Tri-Sync — State, Menu, View, Status

## Description
`menuToggleRelativeMouse()` toggles the `relativeMouse` boolean and synchronizes three dependent components in a single action: `videoView.relativeMode` is updated, `relativeMouseItem.state` (menu checkmark) is toggled, and a status bar message describes the new state. All three updates are always performed together.

## Preconditions
1. User clicks "Relative Mouse Mode" in the View menu.
2. `relativeMouse`, `videoView`, `relativeMouseItem`, and `statusBar` are all initialized.

## Postconditions
1. `relativeMouse.toggle()` — flips the boolean.
2. `videoView.relativeMode = relativeMouse` — view enters/exits relative capture mode.
3. `relativeMouseItem.state = relativeMouse ? .on : .off` — menu checkmark updated.
4. Status bar message: relative=true → "Relative mouse mode ON — cursor captured…"; relative=false → "Relative mouse mode off."

## Invariants
1. `relativeMouse`, `videoView.relativeMode`, and `relativeMouseItem.state` are always in sync after this action.
2. The status message always reflects the post-toggle state.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Toggle from off→on | All three synced to "on"; cursor captured |
| EC-002 | Toggle from on→off | All three synced to "off"; cursor released |
| EC-003 | Called multiple times | Each toggle flips state consistently |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `relativeMouse=false` → toggle | `relativeMouse=true`, view relativeMode=true, checkmark=on, "ON" message | happy-path |
| `relativeMouse=true` → toggle | `relativeMouse=false`, view relativeMode=false, checkmark=off, "off" message | happy-path |

## Error Handling
No errors. All state updates are synchronous on the main actor.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:454-461 |
| Ingest BC | BC-118 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | assertion |
