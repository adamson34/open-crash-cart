---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: opencrashcart-pass-3-behavioral-contracts.md
subsystem: SS-02
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.02.009: setActiveSize Clamps to [1, Max] and Crops Output Frame

## Description

`setActiveSize(width:height:)` controls the dimensions of the `VideoFrame` emitted by `snapshotActiveRegion()`. Input dimensions are clamped to the range `[1, maxWidth]` for width and `[1, maxHeight]` for height, preventing zero-size or oversized frames. The framebuffer always maintains the full 1920×1600 allocation; only the emitted crop changes. This method is called by `parseStatus` in `StarTechAdapter` whenever the device reports a new active video mode.

## Preconditions

- The decoder is initialized.
- `width` and `height` are any `Int` values (including 0, negative, or values exceeding the max).

## Postconditions

- `activeWidth = min(max(width, 1), 1920)` — clamped to [1, 1920].
- `activeHeight = min(max(height, 1), 1600)` — clamped to [1, 1600].
- Subsequent calls to `snapshotActiveRegion()` emit a frame of exactly `(activeWidth, activeHeight)` pixels.
- The frame pixel buffer contains the top-left `activeWidth × activeHeight` sub-rectangle of the 1920×1600 framebuffer.
- Pre-existing pixels outside the active crop are preserved in the framebuffer but not emitted.

## Invariants

- Default `activeWidth = 1024`, `activeHeight = 768` (StarTechTileDecoder.swift:20-21).
- `setActiveSize` is protected by `lock` (same lock as `ingest`); no data race.
- `maxWidth = 1920`, `maxHeight = 1600` (StarTechTileDecoder.swift:11-12).

## Edge Cases

| EC-ID  | Scenario                          | Expected Outcome                               |
|--------|-----------------------------------|------------------------------------------------|
| EC-041 | setActiveSize(width:0, height:0)  | Clamped to (1, 1)                              |
| EC-042 | setActiveSize(width:-10, height:5)| Clamped to (1, 5)                              |
| EC-043 | setActiveSize(width:1920, height:1600) | Unchanged (at max)                        |
| EC-044 | setActiveSize(width:1921, height:1601) | Clamped to (1920, 1600)                   |
| EC-045 | setActiveSize(width:1280, height:1024) | Emitted frame is 1280×1024 pixels         |
| EC-046 | Call during active decoding       | NSLock ensures atomicity; no torn read/write   |

## Canonical Test Vectors

| Input (w, h) | activeWidth | activeHeight | Frame dimensions | Category   |
|--------------|-------------|--------------|------------------|------------|
| (16, 16)     | 16          | 16           | 16×16            | happy-path (used throughout TileDecoderTests) |
| (0, 0)       | 1           | 1            | 1×1              | edge (zero clamp) |
| (1921, 1601) | 1920        | 1600         | 1920×1600        | edge (over-max clamp) |
| (1920, 1600) | 1920        | 1600         | 1920×1600        | edge (at-max, no clamp) |

## Error Handling

No error is raised. All out-of-range inputs are silently clamped. The caller (parseStatus) is responsible for providing valid dimensions from the device STATUS message.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:34-38 (setActiveSize), :182-196 (snapshotActiveRegion) |
| Ingest BC                       | BC-018 (opencrashcart-pass-3-behavioral-contracts.md:23) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — active-size crop; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:34-38 |
| Confidence       | MEDIUM (code-only; setActiveSize called in every TileDecoderTest but clamping behaviour not directly tested at limits) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
