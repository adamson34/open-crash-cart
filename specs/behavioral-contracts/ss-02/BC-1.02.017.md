---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-3-behavioral-contracts.md"
subsystem: "SS-02"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.02.017: Mouse Suppressed During OCR Region Selection

## Description

While the user is dragging an OCR selection rectangle (`selecting == true`), all mouse events are suppressed and not forwarded to the remote target. `mouseDown` captures the selection start point, `mouseDragged` updates the overlay rectangle, and `mouseUp` completes the selection — none of these forward a mouse event. The `sendMouse()` guard at line 282 (`if selecting { return }`) ensures no accidental clicks reach the target machine during text selection.

## Preconditions

- `beginRegionSelection()` has been called and `selecting == true`.
- Mouse events are received by the `VideoView`.

## Postconditions

- `sendMouse()` returns immediately without calling `input?.sendMouse(...)` when `selecting == true`.
- `mouseDown` stores `selectionStart = convert(e.locationInWindow, from: nil)` (VideoView.swift:255) and does NOT call `sendMouse`.
- `mouseDragged` updates `overlay.selectionRect` but does NOT call `sendMouse` (VideoView.swift:267-272).
- `mouseUp` calls `finishSelection` which calls `onRegionSelected` and then `endRegionSelection` — not `sendMouse`.
- After `endRegionSelection()` sets `selecting = false`, subsequent mouse events are forwarded normally.

## Invariants

- No mouse event during an OCR selection (from `beginRegionSelection()` to `endRegionSelection()`) reaches the remote target.
- Keyboard events during selection are also suppressed (see BC-1.02.018, from `keyDown` in VideoView).
- The OCR selection suppression is a pure UI concern; it does not affect the decoder or the USB transport.

## Edge Cases

| EC-ID  | Scenario                           | Expected Outcome                                    |
|--------|------------------------------------|----------------------------------------------------|
| EC-084 | Mouse click before beginRegionSelection | Forwarded normally                             |
| EC-085 | Mouse click during selection        | Suppressed (not forwarded)                         |
| EC-086 | Mouse click after endRegionSelection| Forwarded normally                                |
| EC-087 | rightMouseDown during selection    | sendMouse guard not hit for right-click (VideoView.swift:262 — no selecting check) → NOTE: right-click IS forwarded during selection (potential gap) |

## Canonical Test Vectors

| selecting | Event type  | Expected sendMouse called? | Category  |
|-----------|-------------|---------------------------|-----------|
| false     | mouseMoved  | yes                        | happy-path |
| true      | mouseMoved  | no                         | happy-path (BC-122 reference) |
| true      | mouseDown   | no                         | happy-path |
| false     | mouseDown   | yes                        | happy-path |

Note on EC-087: `rightMouseDown` (line 262) calls `sendMouse(e)` without a `selecting` guard — right-click events during OCR selection may reach the target. This is an existing gap, not a v1.1.0 concern.

## Error Handling

Not applicable — suppression is a simple boolean guard.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/occ/VideoView.swift:254-273 (selection mouse handling), :282 (sendMouse guard) |
| Ingest BC                       | BC-122 (opencrashcart-pass-3-deep-app-layer.md:30) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — mouse suppression during OCR; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/occ/VideoView.swift:254-273, 282 |
| Confidence       | MEDIUM (code-only; no app-layer tests) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
