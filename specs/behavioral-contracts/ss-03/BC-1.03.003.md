---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: opencrashcart-pass-3-deep-app-layer.md
subsystem: SS-03
capability: CAP-OCR
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.003: handleOCR Trims Result and Copies to Clipboard Only on Non-Empty; Cancel and Empty Have Distinct Status Messages

## Description

`AppController.handleOCR(_:)` is the OCR completion handler. It handles three distinct paths: nil image (cancelled by the user), empty trimmed text (no text found), and non-empty text (success with clipboard write). Each path produces a distinct status bar message. The clipboard is never written on cancel or empty result.

## Preconditions

- `handleOCR` is called on the main queue (dispatched via `DispatchQueue.main.async` inside the `recognizeText` completion).
- The `image` argument is either `nil` (user cancelled selection) or a `CGImage` (selection completed; may yield empty or non-empty text).

## Postconditions

**Cancel path** (`image` is `nil`):
- `statusBar.setMessage("OCR cancelled.")` is called.
- No call to `recognizeText` is made.
- Clipboard is not modified.

**Empty text path** (image present, trimmed text is `""`):
- `statusBar.setMessage("No text found in the selection.")` is called.
- Clipboard is not modified.

**Success path** (image present, trimmed text is non-empty):
- Recognized text is trimmed of leading/trailing whitespace and newlines.
- `NSPasteboard.general.clearContents()` is called.
- `NSPasteboard.general.setString(trimmed, forType: .string)` is called.
- `statusBar.setMessage("Copied <n> character<s> from screen to clipboard.")` is called, where `<n>` is `trimmed.count` and pluralization is `"character"` when n=1, `"characters"` otherwise.

## Invariants

- The clipboard is only written when `trimmed` is non-empty.
- The status message always reflects the actual outcome (cancel / not-found / success).
- Character count in the status message always matches the length of the trimmed string written to clipboard.

## Edge Cases

- **EC-001** — Text is all whitespace: trimming yields `""`; treated as empty path; no clipboard write.
- **EC-002** — Text is exactly one character: status reads "Copied 1 character from screen to clipboard." (singular).
- **EC-003** — `self` deallocated before main-queue dispatch runs: the `guard let self` in the closure exits cleanly; no crash, no clipboard write.
- **EC-004** — recognizeText completion never fires (perform error swallowed per BC-1.03.001): handleOCR's inner block never executes; status remains "Reading text…" indefinitely.

## Canonical Test Vectors

| Scenario | Input image | OCR text | Expected status | Clipboard written? |
|----------|-------------|----------|----------------|-------------------|
| Cancel | nil | — | "OCR cancelled." | No |
| No text found | CGImage | "" | "No text found in the selection." | No |
| Single character | CGImage | "X" | "Copied 1 character from screen to clipboard." | Yes, "X" |
| Multi-character | CGImage | "hello world" | "Copied 11 characters from screen to clipboard." | Yes, "hello world" |
| Whitespace only | CGImage | "   \n  " | "No text found in the selection." | No |

## Error Handling

- All paths are handled explicitly. No throws or panics.
- The `recognizeText` error-swallow defect (BC-1.03.001 EC-001) causes the inner block never to execute; the `handleOCR` function itself does not raise an error.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/AppController.swift:648-665` |
| Ingest BC | BC-142 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-OCR ("Run Vision OCR on a cropped screen region and copy result to clipboard") per capabilities.md §CAP-OCR |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/AppController.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:648` `guard let image else { statusBar.setMessage("OCR cancelled."); return }`; `:649` `statusBar.setMessage("Reading text…")`; `:654` `trimmingCharacters(in: .whitespacesAndNewlines)`; `:655` `guard !trimmed.isEmpty`; `:659-662` clipboard write + count message |
