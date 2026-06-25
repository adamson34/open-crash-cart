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

# BC-1.03.006: Esc Cancels OCR Selection; All Keyboard Events Are Swallowed During Selection Mode

## Description

While the video view is in OCR region-selection mode (`selecting == true`), keyboard input is fully suppressed from reaching the target machine. The Escape key (keyCode 0x35) cancels the selection and calls `onRegionSelected?(nil)`. All other keys are silently dropped (not forwarded, not repeated).

## Preconditions

- `selecting == true` (set by `beginRegionSelection()`).
- The video view is first responder.

## Postconditions

**Escape key (keyCode 0x35) pressed during selection**:
- `endRegionSelection()` is called (overlay hidden, cursor popped, `selecting = false`).
- `onRegionSelected?(nil)` is called.
- No key event is forwarded to the target via `input?.sendKey`.

**Any other key pressed during selection**:
- The event is consumed by the `keyDown` override with a bare `return`.
- No key event is forwarded to the target.
- `keysDown` set is not modified.

**Key pressed when NOT in selection mode**:
- Normal forwarding behavior applies (governed by other BCs outside SS-03 scope).

## Invariants

- Zero key events reach the target machine while `selecting == true`.
- The Escape path always calls both `endRegionSelection()` and `onRegionSelected?(nil)`.
- `keyUp` events are also suppressed during selection (the guard in `keyDown` applies; `keyUp` does not have the same guard, but no `keyDown` occurs first so no release is needed — note: this is implicitly safe since `keysDown` is not modified during selection).

## Edge Cases

- **EC-001** — User holds a key before entering selection mode, then releases during selection: `keyUp` is NOT gated by `selecting`; the release is forwarded. This is safe (releases a key that was already down on the target).
- **EC-002** — User presses and holds Escape (auto-repeat): the first event cancels; subsequent repeat events arrive with `isARepeat == true`. The `selecting` guard is checked first (before repeat guard), so the cancellation fires on first event; subsequent events fall through the `selecting` check as `selecting` is already `false`.
- **EC-003** — Selection mode is active but video view loses first responder: `resignFirstResponder` calls `releaseAllKeys` and restores cursor; `selecting` may remain `true` if `endRegionSelection` is not triggered — this is a potential stuck-state (not addressed in current code).

## Canonical Test Vectors

| Scenario | Key | selecting | Expected |
|----------|-----|-----------|----------|
| Esc during selection | 0x35 | true | endRegionSelection + onRegionSelected?(nil) called |
| Letter key during selection | 0x00 ('A') | true | swallowed; no sendKey call |
| Letter key outside selection | 0x00 ('A') | false | forwarded normally |
| Esc outside selection | 0x35 | false | forwarded normally via HIDKeymap |

## Error Handling

No errors thrown. All paths are explicit guards with early returns.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoView.swift:190-194, 151-158` |
| Ingest BC | BC-124 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-OCR ("Run Vision OCR on a cropped screen region and copy result to clipboard") per capabilities.md §CAP-OCR |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/VideoView.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:190-194` `if selecting { if event.keyCode == 0x35 { endRegionSelection(); onRegionSelected?(nil) }; return }`; `:151-158` `endRegionSelection()` body |
