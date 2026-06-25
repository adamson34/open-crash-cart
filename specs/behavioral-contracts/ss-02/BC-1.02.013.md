---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: opencrashcart-pass-3-deep-app-layer.md
subsystem: SS-02
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.02.013: Display Pipeline Raw vs Enhanced (layer.contents Path)

## Description

`VideoView.updateDisplayedImage()` is the single point where the CALayer content is set. When `enhancement.isActive` is false, the raw `CGImage` is set directly. When `enhancement.isActive` is true, `enhance()` applies CIColorControls (brightness/contrast/saturation) and optionally CISharpenLuminance before setting the result. Snapshot and OCR always use the raw `lastImage`, never the enhanced output. The enhancement pipeline is owned by SS-03; this BC covers only the display/contents switching path.

## Preconditions

- `lastImage` is non-nil (at least one frame has been received).
- `enhancement` reflects the current user settings.

## Postconditions

- If `enhancement.isActive == false`: `layer?.contents = lastImage` (the raw CGImage).
- If `enhancement.isActive == true`: `layer?.contents = enhance(lastImage)` (a new CGImage produced by CoreImage filters).
- `snapshotPNG()` always reads `lastImage` directly — enhancement does not affect snapshots.
- OCR always reads `lastImage` via the caller — enhancement does not affect OCR input.

## Invariants

- `lastImage` is never replaced by `enhance()` output; it always holds the raw decoded frame.
- `setEnhancement()` calls `updateDisplayedImage()` immediately, re-rendering the current frame with the new settings.
- `enhancement.isActive` is `true` iff any of: `brightness != 0`, `contrast != 1`, `sharpness != 0`, `grayscale == true` (VideoView.swift:11).

## Edge Cases

| EC-ID  | Scenario                                  | Expected Outcome                                   |
|--------|-------------------------------------------|----------------------------------------------------|
| EC-062 | No frame received yet (lastImage = nil)   | updateDisplayedImage is a no-op                    |
| EC-063 | enhancement.isActive = false              | layer.contents = raw CGImage                       |
| EC-064 | enhancement.isActive = true               | layer.contents = enhanced CGImage                  |
| EC-065 | setEnhancement called with all-default values | isActive = false → raw path used                |
| EC-066 | snapshotPNG called with enhancement active| Returns PNG of raw frame (no enhancement)          |

## Canonical Test Vectors

| enhancement.isActive | lastImage present | layer.contents                | snapshotPNG result    | Category  |
|----------------------|-------------------|-------------------------------|-----------------------|-----------|
| false                | yes               | raw CGImage                   | raw PNG               | happy-path (BC-125 reference) |
| true                 | yes               | enhanced CGImage (SS-03)      | raw PNG               | happy-path |
| false                | no                | unchanged                     | nil                   | edge      |

## Error Handling

If `ciContext.createCGImage` fails (very rare), `enhance()` returns the original `cgImage` (VideoView.swift:115). The display degrades gracefully to the unenhanced image.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/occ/VideoView.swift:96-99 (updateDisplayedImage), :45-47 (enhancement.isActive), :119-123 (snapshotPNG) |
| Ingest BC                       | BC-125 reference (opencrashcart-pass-3-deep-app-layer.md:33) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — display pipeline switching; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/occ/VideoView.swift:96-99, 45-47, 119-123 |
| Confidence       | MEDIUM (no app-layer tests; confirmed from source) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
