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

# BC-1.02.004: Absolute Framebuffer Addressing into 1920-Wide Buffer

## Description

The tile decoder writes pixels into a fixed 1920×1600 BGRA framebuffer regardless of the active display resolution. Tile coordinates are absolute: tile(tileX, tileY) maps to framebuffer pixels at `x ∈ [tileX*16, tileX*16+15]` and `y ∈ [tileY*16, tileY*16+15]`. Stride is always 1920*4 = 7680 bytes per row. This contract ensures tile (2,1) places pixels starting at x=32, y=16 in the framebuffer.

## Preconditions

- The 1920×1600 framebuffer has been allocated (initialized in `init()`).
- `tileX` and `tileY` are within bounds (< 120 and < 100 respectively).
- The record is complete (4 bytes for solid, 516 bytes for raw).

## Postconditions

- `baseX = tileX * 16`, `baseY = tileY * 16`.
- Pixel (col, row) within the tile is written to framebuffer offset `((baseY + row) * 1920 + (baseX + col)) * 4`.
- For tile (2, 1): pixels appear at framebuffer x ∈ [32, 47], y ∈ [16, 31].
- Pixels at (0, 0) (outside tile (2,1)) are not modified by a write to tile (2,1).
- The active-size crop applied at frame emission (see BC-1.02.009) is independent of framebuffer addressing.

## Invariants

- `maxWidth` is a compile-time constant of 1920 (StarTechTileDecoder.swift:11).
- `stride` = `1920 * 4 = 7680` bytes per row (StarTechTileDecoder.swift:16).
- Tile addressing is always absolute; there is no "relative to active window" coordinate system at write time.

## Edge Cases

| EC-ID  | Scenario                         | Expected Outcome                                |
|--------|----------------------------------|-------------------------------------------------|
| EC-017 | tile(0,0) solid blue (0x001F)    | Pixel (0,0) in fb = (B=0xF8, G=0, R=0, A=0xFF) |
| EC-018 | tile(2,1) solid blue (0x001F)    | Pixel (32,16) in fb = (B=0xF8, G=0, R=0, A=0xFF); pixel (0,0) unchanged |
| EC-019 | tile(119,99) — max valid coords  | Written at x=[1904,1919], y=[1584,1599]         |
| EC-020 | tile(120,0) — tileX out of range | Skip record (BC-1.02.008 handles this)          |

## Canonical Test Vectors

| tileX | tileY | color RGB565 | Check pixel (fb x,y) | Expected B | Category |
|-------|-------|--------------|----------------------|------------|----------|
| 2     | 1     | 0x001F (blue)| (40, 20)             | 0xF8       | happy-path (test-pinned: TileDecoderTests.swift:34-39) |
| 2     | 1     | 0x001F       | (0, 0)               | 0x00       | edge (outside-tile pixel unchanged) |
| 0     | 0     | 0xF800 (red) | (0, 0)               | 0x00 (R=0xF8) | happy-path |

Note: TileDecoderTests.swift:37 uses `bgra(f, 40, 20).0` which checks the CROPPED frame (activeSize=64x64). Pixel (40,20) in the cropped frame maps to framebuffer (40,20). The b channel (`[0]`) = 0xF8 for blue.

## Error Handling

Out-of-range tile coordinates are rejected before this addressing code is reached. See BC-1.02.008.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:141-146 (decodeRawTile), :164-165 (fillTile) |
| Ingest BC                       | BC-013 (opencrashcart-pass-3-behavioral-contracts.md:18) |
| Test file:line                  | Sources/occ-tests/TileDecoderTests.swift:34-39 |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — framebuffer addressing; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:11,16,141-146,164-165 |
| Confidence       | HIGH (test-pinned: TileDecoderTests.swift:34-39 verifies tile(2,1) at x∈[32,47] y∈[16,31]) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code + test suite |
