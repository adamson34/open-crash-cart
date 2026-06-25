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
# Behavioral Contract BC-1.01.038: Type-Text Empty-Field Allowed vs Paste Non-Empty Asymmetry

## Description
`menuTypeText()` shows a modal dialog with a text field. When the user confirms, `adapter?.typeText(field.stringValue)` is called unconditionally — even if the field is empty. This is an asymmetry with `pasteText()` which guards against empty input. An empty Type Text dialog results in `typeText("")` being sent to the adapter.

## Preconditions
1. User activates "Type Text…" menu item.
2. The dialog appears and the user clicks "Type" (first button).

## Postconditions
1. On confirm (`.alertFirstButtonReturn`): `adapter?.typeText(field.stringValue)` called with whatever is in the field (including empty string).
2. On cancel: no call to `adapter.typeText`.
3. `adapter == nil` is safe: optional chaining.

## Invariants
1. Empty field → `typeText("")` is called (not guarded).
2. Cancel → no typeText call.
3. Asymmetry with Paste: Paste guards empty; Type Text does not.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Empty text field, user clicks "Type" | `typeText("")` called |
| EC-002 | User clicks "Cancel" | No call |
| EC-003 | `adapter == nil` | Optional chain; no crash |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Field "hello", click Type | `typeText("hello")` called | happy-path |
| Empty field, click Type | `typeText("")` called (asymmetry with paste) | edge case |
| Click Cancel | No adapter call | edge case |

## Error Handling
No errors. Modal dialog handles its own lifecycle.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:425-437 |
| Ingest BC | BC-116 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | inferred |
