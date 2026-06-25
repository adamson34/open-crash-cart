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

# BC-1.02.005: FFFF/FFFF Padding Record Advances to Next 512-Byte Boundary

## Description

The StarTech video stream pads tile records to 512-byte USB bulk-transfer boundaries. A padding record is identified by both word0 and word1 being `0xFFFF`. When encountered, the decoder skips forward to the next 512-byte boundary relative to the current position within the transfer buffer, not from the start of the stream. A tile record immediately following the padding is decoded normally.

## Preconditions

- `word0 == 0xFFFF && word1 == 0xFFFF` at the current stream position `pos`.
- At least 4 bytes remain at `pos` (the loop guard `count - pos >= 4` is satisfied).

## Postconditions

- `skip = min(512 - (pos & 511), count - pos)` — advance by the number of bytes to reach the next 512-byte boundary within the current transfer.
- `pos` advances by `skip`; bytes in the padding region are not decoded.
- No tile is written; `sawTileSinceEmit` is not set by this record.
- Processing continues at the new `pos` value; the next tile record (if present) is decoded.
- If the buffer ends before the boundary (`count - pos < 512 - (pos & 511)`), the remaining bytes are consumed and the loop terminates normally (no leftover is stashed for padding bytes).

## Invariants

- The boundary is always computed relative to `pos` within the current `data` array (not a global stream offset).
- Padding records are never stashed in `leftover`; they are consumed in-place.
- A tile record after a padding block begins at a 512-byte-aligned offset within the transfer.

## Edge Cases

| EC-ID  | Scenario                                     | Expected Outcome                                     |
|--------|----------------------------------------------|------------------------------------------------------|
| EC-021 | Padding at pos=0 (4 bytes FFFF/FFFF + 508 zeros + tile) | skip=508, tile decoded after skip           |
| EC-022 | Padding at pos=508 (boundary at pos=512)     | skip=4, advances exactly 4 bytes                    |
| EC-023 | Padding at pos=512 (already boundary)        | `512 - (512 & 511) = 512`, but `min(512, count-pos)` — advances to next boundary |
| EC-024 | Buffer ends inside padding region            | Remaining bytes consumed, loop exits, nil returned  |
| EC-025 | Two sequential padding blocks at boundary    | Each consumed independently; two skip advances      |

## Canonical Test Vectors

| Input (bytes)                                          | Expected result                      | Category    |
|--------------------------------------------------------|--------------------------------------|-------------|
| [FF,FF,FF,FF] + 508 zeros + solid red header (4B)      | Red tile decoded after padding        | happy-path (test-pinned: TileDecoderTests.swift:41-48) |
| [FF,FF,FF,FF] at pos=508                               | skip=4, next record at pos=512       | edge        |
| [FF,FF,FF,FF] only (4 bytes total)                     | skip=4, loop exits, nil returned     | error       |

## Error Handling

Padding records are consumed without error. A buffer that ends in the padding region simply terminates the loop; no error is raised and `nil` is returned (no tile was written).

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:91-96 |
| Ingest BC                       | BC-014 (opencrashcart-pass-3-behavioral-contracts.md:19) |
| Test file:line                  | Sources/occ-tests/TileDecoderTests.swift:41-48 |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — stream padding alignment; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:91-96 |
| Confidence       | HIGH (test-pinned: TileDecoderTests.swift:41-48 verifies tile decodes after padding block) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code + test suite |
