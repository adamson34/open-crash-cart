---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-2-3-deep-panels-r2.md"
subsystem: "SS-03"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.014: ImageEnhancePanel Emits Normalized ÷100 ImageEnhancement Values and Reset Emits Default

## Description

`ImageEnhancePanel` uses slider ranges that are intentionally scaled by 100 for user-friendly integer display (e.g., brightness -50..50 maps to -0.5..0.5). On every slider change and on the grayscale checkbox toggle, `current()` is called to build an `ImageEnhancement` struct by dividing each slider value by 100.0, and emits via `onChange`. The reset button sets sliders to their defaults and emits `ImageEnhancement()` (all fields at zero/default).

## Preconditions

- `ImageEnhancePanel` is initialized with an `onChange` closure.
- The panel is visible and interactive.

## Postconditions

**Slider or checkbox changed**:
- `onChange(current())` is called.
- `current()` computes:
  - `brightness = brightness.doubleValue / 100.0` (range: -0.5..0.5)
  - `contrast = contrast.doubleValue / 100.0` (range: 0.5..2.0)
  - `sharpness = sharpness.doubleValue / 100.0` (range: 0.0..1.0)
  - `grayscale = grayscale.state == .on`
- The emitted `ImageEnhancement` is passed to `VideoView.setEnhancement(_:)`.

**Reset tapped**:
- `brightness.doubleValue = 0` (slider reset)
- `contrast.doubleValue = 100` (slider reset to 100, emits 1.0 after ÷100)
- `sharpness.doubleValue = 0`
- `grayscale.state = .off`
- `onChange(ImageEnhancement())` is called — emits the default struct (all fields at zero/1.0 contrast).

## Invariants

- Slider ranges: brightness [-50, 50], contrast [50, 200], sharpness [0, 100].
- Emitted values: brightness [-0.5, 0.5], contrast [0.5, 2.0], sharpness [0.0, 1.0].
- Default `ImageEnhancement()` has: brightness=0, contrast=1, sharpness=0, grayscale=false.
- `onChange` is called on every slider move (continuous = true) and checkbox state change.
- Reset always emits `ImageEnhancement()`, not `current()`.

## Edge Cases

- **EC-001** — Slider at maximum: brightness=50 → emits 0.5; contrast=200 → emits 2.0; sharpness=100 → emits 1.0.
- **EC-002** — Slider at minimum: brightness=-50 → emits -0.5; contrast=50 → emits 0.5.
- **EC-003** — Panel closed without reset: last emitted enhancement remains active on the VideoView until panel is re-opened and reset, or a new enhancement is emitted.
- **EC-004** — `onChange` closure captures `[weak self]` from AppController: if AppController is deallocated, closure is a no-op.

## Canonical Test Vectors

| Action | Slider values | Emitted brightness | Emitted contrast | Emitted sharpness |
|--------|--------------|-------------------|-----------------|------------------|
| Brightness drag to 25 | 25, 100, 0 | 0.25 | 1.0 | 0.0 |
| Contrast drag to 150 | 0, 150, 0 | 0.0 | 1.5 | 0.0 |
| Reset | 0, 100, 0 | 0.0 | 1.0 | 0.0 |
| All max | 50, 200, 100 | 0.5 | 2.0 | 1.0 |

## Error Handling

No errors possible in slider manipulation. `onChange` closure failures are the caller's concern.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/ImageEnhancePanel.swift:8-11, 77-93` |
| Ingest BC | BC-207 (pass-2-3-deep-panels-r2.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-TBD ("Apply client-side display-only image enhancements to the video stream") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/ImageEnhancePanel.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:8-11` slider init with raw ranges; `:78-83` `current()` divides by 100.0; `:85` `@objc private func changed() { onChange(current()) }`; `:87-93` `resetTapped` sets raw slider values and calls `onChange(ImageEnhancement())` |
