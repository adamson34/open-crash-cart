---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-3-deep-app-layer.md"
subsystem: "SS-03"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.013: Image Enhancement Is Display-Only; Snapshot and OCR Always Use the Raw Frame

## Description

`VideoView` maintains a separate `lastImage` CGImage that always holds the unprocessed raw frame. Enhancements (brightness, contrast, sharpness, grayscale) are applied only to the layer display via `CIFilter` pipeline and are never applied to `lastImage`. Both `snapshotPNG()` and OCR region selection read from `lastImage` directly. The `isActive` computed property on `ImageEnhancement` gates the CI pipeline to avoid unnecessary work when all values are at their defaults.

## Preconditions

- `VideoView` has received at least one frame.
- `enhancement` may or may not be set to non-default values.
- `isActive` check: `brightness != 0 || contrast != 1 || sharpness != 0 || grayscale == true`.

## Postconditions

**On `display(_:)` call**:
- `lastImage` is updated to the new raw CGImage from the frame.
- `layer?.contents` is set to `enhance(raw)` if `isActive == true`, else to `raw` directly.
- Enhancement is never stored back into `lastImage`.

**On `setEnhancement(_:)` call**:
- `enhancement` is updated.
- `updateDisplayedImage()` re-renders the current `lastImage` through the new enhancement pipeline (or raw if inactive).
- `lastImage` is unchanged.

**On `snapshotPNG()` call**:
- Uses `lastImage` (raw, unenhanced). See BC-1.03.007.

**On OCR region selection finish**:
- `lastImage` is used for crop. See BC-1.03.005.

## Invariants

- `lastImage` always contains raw decoded BGRA frame data.
- Enhancement never mutates `lastImage`.
- Display and data-extraction (snapshot/OCR) use independent code paths with different source images when enhancement is active.

## Edge Cases

- **EC-001** — Enhancement active, user takes snapshot: snapshot is the raw (pre-enhancement) frame pixels. Caller sees the unfiltered image.
- **EC-002** — Enhancement active, user runs OCR: OCR operates on raw pixels. If enhancement made text more readable visually, OCR does not benefit from it (known limitation).
- **EC-003** — `isActive == false` (all defaults): `layer?.contents = raw` — no CI pipeline overhead.
- **EC-004** — `ciContext.createCGImage` fails (returns nil): the `?? cgImage` fallback returns the unfiltered raw CGImage to the layer. Display degrades gracefully to raw.

## Canonical Test Vectors

| Scenario | enhancement.isActive | snapshotPNG source | OCR crop source | Layer display |
|----------|---------------------|-------------------|----------------|--------------|
| No enhancement | false | raw lastImage | raw lastImage | raw lastImage |
| Brightness +0.5 | true | raw lastImage | raw lastImage | CI-filtered |
| Grayscale on | true | raw lastImage | raw lastImage | CI-filtered (desaturated) |

## Error Handling

`CIFilter` pipeline failures fall back to unfiltered image via `?? cgImage` / `?? ci`. `snapshotPNG` and OCR crop cannot fail due to enhancement state.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoView.swift:45-47, 96-123` |
| Ingest BC | BC-125 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-TBD ("Apply client-side display-only image enhancements to the video stream") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/VideoView.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:43` `private var lastImage: CGImage?`; `:46-47` comment "Raw frames are kept for snapshot/OCR; enhancement only affects what's shown"; `:97-99` `layer?.contents = enhancement.isActive ? enhance(raw) : raw`; `:119-123` snapshotPNG uses `lastImage`; `:166` finishSelection uses `lastImage` |
