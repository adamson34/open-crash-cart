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

# BC-1.03.005: OCR Region Selection Produces Clamped Floor/Ceil Pixel Crop of Raw Frame; Drag Under 3pt or Crop Under 4px Yields Nil

## Description

`VideoView.finishSelection(at:)` converts the user's drag rectangle from view coordinates to raw-frame pixel coordinates using letterbox-aware math, then crops `lastImage`. The pixel rectangle uses `floor` for the top-left origin and `ceil` for width/height to avoid sub-pixel gaps. Drags smaller than 3 points in either dimension, or crops smaller than 4 pixels in either dimension, return nil to the caller.

## Preconditions

- The user has completed a mouse drag while `selecting == true`.
- `lastImage` is non-nil (a frame has been received).
- `selectionStart` is set (mouseDown was received).

## Postconditions

**Drag too small** (`r.width <= 3` or `r.height <= 3` in view points):
- `onRegionSelected?(nil)` is called.
- `endRegionSelection()` is called (overlay hidden, crosshair cursor popped).

**Crop too small after letterbox mapping** (`crop.width < 4` or `crop.height < 4` in pixels):
- `onRegionSelected?(nil)` is called.

**No lastImage**:
- `onRegionSelected?(nil)` is called.

**Valid selection**:
- View rectangle is mapped to frame pixels via letterbox math:
  - `scale = min(bounds.width / frameWidth, bounds.height / frameHeight)`
  - Display origin: `ox = (bounds.width - frameWidth * scale) / 2`, same for Y
  - Each point is normalized into `[0,1]` then multiplied by frameWidth/frameHeight
- `crop.x = floor(min(p1.x, p2.x))`, `crop.y = floor(min(p1.y, p2.y))`
- `crop.width = ceil(abs(p2.x - p1.x))`, `crop.height = ceil(abs(p2.y - p1.y))`
- `lastImage.cropping(to: crop)` is called on the raw (unenhanced) image.
- Resulting `CGImage` is passed to `onRegionSelected?`.
- `endRegionSelection()` is called via `defer`.

## Invariants

- Crop is always performed on `lastImage` (raw frame), never on the enhanced display image.
- `endRegionSelection()` is always called (via `defer`) regardless of outcome.
- Points outside the displayed video area are clamped to `[0,1]` normalized range before pixel conversion.

## Edge Cases

- **EC-001** — User drags exactly 3 points: `r.width > 3` is false; nil returned.
- **EC-002** — Drag is 3.001 view points but maps to fewer than 4 pixels (extreme zoom-out): crop size guard catches it; nil returned.
- **EC-003** — Selection partially outside letterbox bars: out-of-bounds points clamped to video edge; crop is valid if resulting size >= 4px.
- **EC-004** — `lastImage` is nil (no frame yet): first guard in `finishSelection` fires; nil returned.
- **EC-005** — `selectionStart` is nil (mouseDown not received): first guard fires; nil returned.

## Canonical Test Vectors

| Scenario | Drag (view pts) | Frame size | Expected |
|----------|-----------------|------------|----------|
| Normal drag | 100×80 pt over full 1024×768 frame | 1024×768 | CGImage of cropped region |
| Tiny drag | 2×10 pt | 1024×768 | nil |
| Borderline drag (3.001×10) but <4px crop | 3.001×10 pt, 100% zoom-out | 10×10 frame | nil (crop < 4px wide) |
| Drag outside video bars | Starts in left bar | 1024×768 | Clamped to left edge of video |

## Error Handling

All nil cases call `onRegionSelected?(nil)`. No exceptions are thrown. `CGImage.cropping(to:)` returning nil (invalid rect) also produces nil via the `guard`.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoView.swift:164-188` |
| Ingest BC | BC-123 (pass-3-deep-app-layer.md) |
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
| Key lines | `:168` `guard r.width > 3, r.height > 3`; `:173-178` letterbox scale/offset math; `:176-179` `toPixel` closure with clamp; `:182-183` `floor`/`ceil` crop rect; `:184` `guard crop.width >= 4, crop.height >= 4`; `:165` `defer { endRegionSelection() }` |
