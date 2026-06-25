---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-3-deep-app-layer.md"
subsystem: "SS-02"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.02.014: Absolute Mouse Letterbox-Aware Pixel Mapping Clamped to [0, dim-1]

## Description

In absolute mouse mode, `VideoView.sendMouse()` maps the macOS view-local point to a pixel coordinate in the remote frame, accounting for the aspect-fit letterbox (black bars). The computation first finds the displayed video rectangle (centered, aspect-fit), normalises the pointer position to a [0,1] range within that rectangle, multiplies by `(frameSize - 1)` to get a pixel coordinate, then clamps and rounds. Coordinates outside the letterbox bars are clamped to the nearest valid pixel — the cursor never reports a negative or out-of-bounds position.

## Preconditions

- `relativeMode == false`.
- `selecting == false` (mouse suppressed otherwise, see BC-1.02.016).
- `frameSize` has been set by a prior `display()` call (or defaults to 1024×768).
- `bounds` reflects the current view size.

## Postconditions

- `fw = max(frameSize.width, 1)`, `fh = max(frameSize.height, 1)`.
- `scale = min(bounds.width / fw, bounds.height / fh)` — aspect-fit scale.
- `dispW = fw * scale`, `dispH = fh * scale`.
- `originX = (bounds.width - dispW) / 2`, `originY = (bounds.height - dispH) / 2`.
- `nx = max(0, min(1, (p.x - originX) / dispW))` — normalised x in [0,1].
- `ny = max(0, min(1, (p.y - originY) / dispH))` — normalised y in [0,1].
- `x = Int16(clamping: Int((nx * (fw - 1)).rounded()))` — pixel x in [0, fw-1].
- `y = Int16(clamping: Int((ny * (fh - 1)).rounded()))` — pixel y in [0, fh-1].
- `sendMouse(buttons:x:y:wheel:absolute:true)` is called on the `input` delegate.

## Invariants

- `x` is always in `[0, frameSize.width - 1]`.
- `y` is always in `[0, frameSize.height - 1]`.
- Pixels in the black bar regions (outside the video rectangle) map to the nearest edge pixel.
- The view is flipped (top-left origin), so y=0 corresponds to the top of the video.

## Edge Cases

| EC-ID  | Scenario                               | Expected Outcome                                     |
|--------|----------------------------------------|------------------------------------------------------|
| EC-067 | Pointer in top-left letterbox bar      | x=0, y=0                                             |
| EC-068 | Pointer at exact bottom-right corner   | x=fw-1, y=fh-1                                      |
| EC-069 | Pointer outside view bounds (< 0)      | Clamped to 0                                         |
| EC-070 | frameSize.width=0 (before first frame) | fw=max(0,1)=1 — no division by zero                  |
| EC-071 | View is wider than frame (bars on left/right) | x clamps correctly at left/right bar edges    |
| EC-072 | Scroll wheel event                     | wheel = ±1 or 0; x/y computed from event location    |

## Canonical Test Vectors

| View size  | frameSize  | Pointer (view coords) | Expected x | Expected y | Category  |
|------------|------------|-----------------------|------------|------------|-----------|
| 800×600    | 1024×768   | center (400, 300)     | 512        | 384        | happy-path (BC-119 reference) |
| 800×600    | 1024×768   | (0, 0)                | 0          | 0          | edge (top-left) |
| 800×600    | 1024×768   | (800, 600)            | 1023       | 767        | edge (bottom-right) |
| 800×600    | 1024×768   | (-10, -10)            | 0          | 0          | edge (out of view) |

## Error Handling

Division by zero is prevented by `fw = max(frameSize.width, 1)` and `fh = max(frameSize.height, 1)`. `Int16(clamping:)` prevents integer overflow.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/occ/VideoView.swift:296-309 |
| Ingest BC                       | BC-119 (opencrashcart-pass-3-deep-app-layer.md:27) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — absolute mouse mapping; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/occ/VideoView.swift:296-309 |
| Confidence       | MEDIUM (code-only; no app-layer tests for mouse mapping) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
