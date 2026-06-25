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
# Behavioral Contract BC-1.01.037: Paste Gated on Non-Empty Clipboard

## Description
`pasteText()` reads the general pasteboard string and types it only if the string is non-empty. An empty clipboard shows a status message "Clipboard has no text to paste." and does not call `adapter.typeText`. A non-empty clipboard calls `adapter.typeText(text)` and emits a pluralized count message.

## Preconditions
1. `pasteText()` is called (via menu or toolbar).
2. `NSPasteboard.general` may or may not contain a string.

## Postconditions
1. If no string or empty string: `statusBar.setMessage("Clipboard has no text to paste.")`.
2. If non-empty string: `adapter?.typeText(text)` called; `statusBar.setMessage("Pasting N character(s) to target…")` with correct pluralization.
3. Pluralization: `N == 1` → "character"; `N != 1` → "characters".

## Invariants
1. Empty clipboard never reaches `adapter.typeText`.
2. `adapter` nil is handled by optional chaining (`adapter?.typeText`).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Clipboard empty | Status message; no type |
| EC-002 | Clipboard has `" "` (space only) | Non-empty → types space; "Pasting 1 character…" |
| EC-003 | `adapter == nil` with non-empty clipboard | Optional chain no-ops typeText; message still shown |
| EC-004 | Single character | "Pasting 1 character to target…" (singular) |
| EC-005 | Multiple characters | "Pasting N characters to target…" (plural) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Clipboard: "Hello" | `typeText("Hello")` called; "Pasting 5 characters to target…" | happy-path |
| Clipboard: "" | No typeText; "Clipboard has no text to paste." | edge case |
| Clipboard: "A" | `typeText("A")` called; "Pasting 1 character to target…" | edge case (singular) |

## Error Handling
No errors. Clipboard read returns nil-safe result.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:416-423 |
| Ingest BC | BC-115 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
