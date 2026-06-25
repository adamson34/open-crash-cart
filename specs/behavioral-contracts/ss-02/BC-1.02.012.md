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

# BC-1.02.012: makeCGImage BGRA noneSkipFirst | byteOrder32Little, nearest Magnification

## Description

`VideoView.makeCGImage(_:)` converts a decoded `VideoFrame` (BGRA byte layout) into a `CGImage` suitable for display on a CALayer. The bitmap info must be `CGImageAlphaInfo.noneSkipFirst | CGBitmapInfo.byteOrder32Little` so CoreGraphics interprets the in-memory `[B, G, R, A]` byte order correctly without a channel swap. The layer `magnificationFilter` is `.nearest` (set at init time) to preserve crisp pixel edges when the video is scaled up. An incorrect bitmap info produces color-swapped video; an incorrect filter produces blurry video.

## Preconditions

- `frame.pixels` is a `[UInt8]` array of exactly `frame.width * frame.height * 4` bytes in BGRA row-major order.
- `frame.width > 0` and `frame.height > 0`.

## Postconditions

- `CGImage` is created with:
  - `bitsPerComponent: 8`
  - `bitsPerPixel: 32`
  - `bytesPerRow: frame.width * 4`
  - `space: CGColorSpaceCreateDeviceRGB()`
  - `bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)`
  - `shouldInterpolate: false`
  - `intent: .defaultIntent`
- The CALayer `magnificationFilter` is `.nearest` (set in `init`, not in `makeCGImage`).
- `display()` sets `layer?.contents` to the CGImage (or the enhanced variant if `enhancement.isActive`).
- Returns `nil` if `CGDataProvider` construction fails (very rare; only on memory allocation failure).

## Invariants

- `byteOrder32Little` + `noneSkipFirst` together define the BGRA interpretation: CoreGraphics reads byte 0 as Blue, byte 1 as Green, byte 2 as Red, byte 3 as Alpha (skipped).
- The alpha channel is ignored for display (noneSkipFirst); it is always 0xFF in the decoder output.
- `lastImage` always stores the raw (pre-enhancement) CGImage; enhancement is applied at display time only.

## Edge Cases

| EC-ID  | Scenario                              | Expected Outcome                                   |
|--------|---------------------------------------|----------------------------------------------------|
| EC-057 | frame.pixels = single BGRA pixel (0xF8, 0x00, 0x00, 0xFF) | CGImage at (0,0) appears red on screen |
| EC-058 | CGDataProvider allocation fails       | makeCGImage returns nil; display() is a no-op      |
| EC-059 | Very large frame (1920×1600)          | CGImage created successfully (7,372,800-byte buffer) |
| EC-060 | enhancement.isActive = false          | layer.contents = raw CGImage                       |
| EC-061 | enhancement.isActive = true           | layer.contents = enhanced CGImage (SS-03 scope)    |

## Canonical Test Vectors

| Input BGRA bytes (single pixel) | Displayed color | bitmapInfo correct? | Category  |
|---------------------------------|-----------------|---------------------|-----------|
| [0x00, 0x00, 0xF8, 0xFF]        | Red             | yes                 | happy-path (BC-AUDIT-014) |
| [0xF8, 0x00, 0x00, 0xFF]        | Blue            | yes                 | happy-path |
| [0x00, 0xFC, 0x00, 0xFF]        | Green           | yes                 | happy-path |

## Error Handling

If `makeCGImage` returns `nil`, `display()` exits early without updating `lastImage` or `layer.contents`. The previously displayed frame remains visible.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/occ/VideoView.swift:125-135 (makeCGImage), :64-73 (init, magnificationFilter) |
| Ingest BC                       | BC-AUDIT-014 (opencrashcart-pass-3-deep-app-layer.md — VideoView section) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — CGImage construction + display pipeline; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/occ/VideoView.swift:64-73, 125-135 |
| Confidence       | MEDIUM (no app-layer tests; confirmed from source code) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
