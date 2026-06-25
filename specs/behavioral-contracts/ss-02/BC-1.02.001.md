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

# BC-1.02.001: Tile Record Header Bit-Field Extraction (tileX / tileY / solid)

## Description

The StarTech tile codec encodes tile position and type in two 16-bit little-endian words at the start of every tile record. This contract defines how `StarTechTileDecoder.processRecord` extracts the tileX coordinate, tileY coordinate, and solid-fill flag from the second word (word1). These three values gate every downstream decode path — an incorrect extraction corrupts every tile rendered.

## Preconditions

- A byte slice of at least 4 bytes is available at `offset` within `data`.
- Bytes at `offset` and `offset+1` form word0 (LE); bytes at `offset+2` and `offset+3` form word1 (LE).
- The caller has verified the slice is complete before calling `processRecord`.

## Postconditions

- `tileX` = `Int(word1 & 0x7F)` — bits [6:0] of word1 (0–127).
- `tileY` = `Int((word1 >> 7) & 0x7F)` — bits [13:7] of word1 (0–127).
- `isSolid` = `(word1 & 0x4000) != 0` — bit 14 of word1.
- Bit 15 of word1 (the "first" flag used in test helpers) is not read by the decoder; it has no effect on `tileX`, `tileY`, or `isSolid`.
- word0 is passed unmodified to downstream fill/decode functions as the color/data word.

## Invariants

- Extraction is purely bitwise with no side effects.
- The same record byte sequence always produces the same `(tileX, tileY, isSolid)` triple.
- The 7-bit fields allow a maximum representable value of 127 per axis; values ≥ 120 (tileX) or ≥ 100 (tileY) are out-of-range but still extracted correctly — bounds checking happens in `processRecord`, not extraction.

## Edge Cases

| EC-ID  | Scenario                          | Expected Outcome                    |
|--------|-----------------------------------|-------------------------------------|
| EC-001 | word1 = 0x0000                    | tileX=0, tileY=0, isSolid=false     |
| EC-002 | word1 = 0x7F00 (tileX=0, tileY=126, solid=0) | tileX=0, tileY=126        |
| EC-003 | word1 = 0x407F (tileX=127, tileY=0, solid=0) | tileX=127, tileY=0        |
| EC-004 | word1 = 0x4000 (solid flag only)  | tileX=0, tileY=0, isSolid=true      |
| EC-005 | word1 = 0xFFFF (all bits set)     | tileX=127, tileY=127, isSolid=true  |
| EC-006 | word1 = 0x8000 (first-flag only)  | tileX=0, tileY=0, isSolid=false (bit 15 ignored) |

## Canonical Test Vectors

| Input (word1 hex) | tileX | tileY | isSolid | Category |
|-------------------|-------|-------|---------|----------|
| 0x4000            | 0     | 0     | true    | happy-path (solid at origin) |
| 0x0082 (x=2,y=1 → bits: 0b0000_0000_1000_0010) | 2 | 1 | false | happy-path (raw tile off-origin) |
| 0xFFFF            | 127   | 127   | true    | edge (all bits set) |
| 0x8000            | 0     | 0     | false   | edge (first-flag, no solid) |

Note: word1 for tileX=2, tileY=1 = `(2 & 0x7F) | ((1 & 0x7F) << 7)` = `0x0002 | 0x0080` = `0x0082`.

## Error Handling

This function is purely computational; it cannot fail. Out-of-range coordinate values are extracted correctly and rejected by the bounds guard (`guard tileX < tilesWide, tileY < tilesHigh`) in the same `processRecord` function.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:118-120 |
| Ingest BC                       | BC-010 (opencrashcart-pass-3-behavioral-contracts.md:15) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none — pure computational extraction) |
| Capability Anchor Justification | CAP-TBD — tile codec header extraction; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:115-125 |
| Confidence       | HIGH (test-pinned: TileDecoderTests.swift verifies downstream behavior derived from these extractions) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code + test suite |
