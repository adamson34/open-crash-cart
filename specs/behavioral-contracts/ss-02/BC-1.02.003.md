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

# BC-1.02.003: Raw Tile 516-Byte Record with RGB565 Green Channel (G=0xFC)

## Description

When `isSolid` is false, the decoder reads a 516-byte record: 4-byte header + 512-byte body containing 256 LE RGB565 pixels (16x16 tile). Each pixel is decoded using the same RGB565→BGRA formula as the solid-fill path. This contract specifically pins the green channel output: an input pixel `0x07E0` (pure green in RGB565) must produce `G=0xFC` in the BGRA output — confirming the `(px >> 3) & 0xFC` extraction is correct.

## Preconditions

- `isSolid` is `false` (bit 14 of word1 clear).
- A body of exactly 512 bytes follows the 4-byte header at `bodyOffset = offset + 4`.
- `tileX` and `tileY` are within bounds.
- The 512-byte body contains 256 LE-encoded `UInt16` RGB565 values read in row-major order.

## Postconditions

- All 256 pixels of the tile are decoded: for pixel at body index `i` (2 bytes LE), `px = body[i] | (body[i+1] << 8)`, then BGRA as per the formula.
- A green pixel `px = 0x07E0` produces `G = (0x07E0 >> 3) & 0xFC = 0xFC` at the corresponding framebuffer location.
- `sawTileSinceEmit` is set to `true`.
- The record is consumed as exactly 516 bytes (4 header + 512 body).

## Invariants

- Pixel layout in the body is little-endian: low byte first, then high byte.
- Row-major order: pixel (col, row) is at body offset `(row * 16 + col) * 2`.
- The 512-byte body is not padded; it is exactly 256 * 2 bytes.

## Edge Cases

| EC-ID  | Scenario                                  | Expected Outcome                            |
|--------|-------------------------------------------|---------------------------------------------|
| EC-013 | All 256 pixels = 0x07E0 (pure green)      | Every pixel in tile: G=0xFC, B=0, R=0, A=0xFF |
| EC-014 | Mixed colors in body                      | Each pixel decoded independently with same formula |
| EC-015 | Body byte at index 0 = 0xE0, index 1 = 0x07 | LE decode: px = 0x07E0, G=0xFC           |
| EC-016 | Record size check: header(4) + body(512) = 516 | `full.count == 516` (TileDecoderTests.swift:54) |

## Canonical Test Vectors

| Input (body pixel hex LE) | Expected G | Expected B | Expected R | Category |
|---------------------------|------------|------------|------------|----------|
| [0xE0, 0x07] (= 0x07E0)   | 0xFC       | 0x00       | 0x00       | happy-path (test-pinned: TileDecoderTests.swift:27-32) |
| [0x00, 0xF8] (= 0xF800)   | 0x00       | 0x00       | 0xF8       | happy-path (red) |
| [0x1F, 0x00] (= 0x001F)   | 0x00       | 0xF8       | 0x00       | happy-path (blue) |
| [0xFF, 0xFF] (= 0xFFFF)   | 0xFC       | 0xF8       | 0xF8       | edge (white/max) |

## Error Handling

No error path exists within `decodeRawTile`; it assumes a valid 512-byte body provided by `processRecord`. Truncated records are caught upstream at the `leftover` reassembly stage (see BC-1.02.006).

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:140-158 (decodeRawTile) |
| Ingest BC                       | BC-012 (opencrashcart-pass-3-behavioral-contracts.md:17) |
| Test file:line                  | Sources/occ-tests/TileDecoderTests.swift:27-32, :54 |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — raw tile decode; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:140-158 |
| Confidence       | HIGH (test-pinned: TileDecoderTests.swift:27-32 verifies G channel, :54 pins 516-byte size) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code + test suite |
