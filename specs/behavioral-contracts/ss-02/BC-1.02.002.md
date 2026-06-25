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

# BC-1.02.002: Solid-Fill Tile RGB565 to BGRA Conversion (4-Byte Record)

## Description

When bit 14 of word1 is set (`isSolid = true`), the decoder interprets the 16-bit word0 as an RGB565 color and flood-fills all 256 pixels of the 16x16 tile in the framebuffer with the equivalent BGRA value. The entire record is 4 bytes (header only; no pixel body). This conversion formula is the core color fidelity primitive for the codec.

## Preconditions

- `isSolid` is `true` (bit 14 of word1 set).
- `word0` contains a valid RGB565 color in the range `[0x0000, 0xFFFF]`.
- `tileX` and `tileY` are within bounds (`< tilesWide` and `< tilesHigh`).
- The framebuffer has been initialized and is at least `maxWidth * maxHeight * 4` bytes.

## Postconditions

- For the input RGB565 value `px`:
  - `B = (px << 3) & 0xFF`
  - `G = (px >> 3) & 0xFC`
  - `R = (px >> 8) & 0xF8`
  - `A = 0xFF`
- All 256 pixels of the target tile (rows 0..15, columns 0..15) are set to `(B, G, R, A)` in memory.
- `sawTileSinceEmit` is set to `true`.
- The record is consumed as exactly 4 bytes.
- Pixels outside the tile boundary are not modified.

## Invariants

- The BGRA layout matches `CGImageAlphaInfo.noneSkipFirst | CGBitmapInfo.byteOrder32Little` — byte order `[B, G, R, A]` at each 4-byte pixel.
- Alpha is always `0xFF` (fully opaque) for solid tiles.
- The conversion is lossy: 5-bit red and blue components have 3 zero LSBs; 6-bit green has 2 zero LSBs.
- Red `0xF800` (pure red in RGB565) must produce exactly `R=0xF8, G=0x00, B=0x00, A=0xFF`.

## Edge Cases

| EC-ID  | Scenario                        | Expected Outcome                            |
|--------|---------------------------------|---------------------------------------------|
| EC-007 | RGB565 = 0xF800 (pure red)      | B=0x00, G=0x00, R=0xF8, A=0xFF             |
| EC-008 | RGB565 = 0x07E0 (pure green)    | B=0x00, G=0xFC, R=0x00, A=0xFF             |
| EC-009 | RGB565 = 0x001F (pure blue)     | B=0xF8, G=0x00, R=0x00, A=0xFF             |
| EC-010 | RGB565 = 0x0000 (black)         | B=0x00, G=0x00, R=0x00, A=0xFF             |
| EC-011 | RGB565 = 0xFFFF (white)         | B=0xF8, G=0xFC, R=0xF8, A=0xFF            |
| EC-012 | Tile at (0,0), activeSize=16x16 | All 256 pixels of tile set; frame emitted   |

## Canonical Test Vectors

| Input RGB565 | Expected B | Expected G | Expected R | Expected A | Category  |
|--------------|------------|------------|------------|------------|-----------|
| 0xF800       | 0x00       | 0x00       | 0xF8       | 0xFF       | happy-path (test-pinned: TileDecoderTests.swift:22-24) |
| 0x07E0       | 0x00       | 0xFC       | 0x00       | 0xFF       | happy-path (green, used in raw tile test) |
| 0x001F       | 0xF8       | 0x00       | 0x00       | 0xFF       | happy-path (blue, used in addressing test) |
| 0x0000       | 0x00       | 0x00       | 0x00       | 0xFF       | edge (black) |
| 0xFFFF       | 0xF8       | 0xFC       | 0xF8       | 0xFF       | edge (white/max) |

## Error Handling

This operation cannot fail. An out-of-range `tileX`/`tileY` is rejected before `fillTile` is called (see BC-1.02.008). Arithmetic overflow is prevented by the `& 0xFF` and `& 0xFC` masks.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:160-175 (fillTile) |
| Ingest BC                       | BC-011 (opencrashcart-pass-3-behavioral-contracts.md:16) |
| Test file:line                  | Sources/occ-tests/TileDecoderTests.swift:20-25 |
| Stories                         | by story-writer |
| L2 Invariants                   | (none — conversion formula) |
| Capability Anchor Justification | CAP-TBD — solid-fill decode; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:160-175 |
| Confidence       | HIGH (test-pinned: TileDecoderTests.swift:20-25 verifies red 0xF800 → BGRA (0,0,F8,FF)) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code + test suite |
