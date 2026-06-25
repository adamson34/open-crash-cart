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

# BC-1.02.008: Out-of-Range Tile Coordinates Skipped and Record Consumed

## Description

The device may emit tile records with coordinates outside the valid 120×100 tile grid (0..119 for X, 0..99 for Y). The decoder detects this condition, skips the record without writing any pixels, and advances the stream position by the correct record size so parsing continues correctly. No frame emission occurs for an out-of-range tile alone.

## Preconditions

- A complete tile record (4 bytes solid, 516 bytes raw) is present at `offset`.
- `tileX >= tilesWide (120)` or `tileY >= tilesHigh (100)` — at least one coordinate is out of range.

## Postconditions

- No pixels are written to the framebuffer.
- `sawTileSinceEmit` is NOT set by this record.
- The function returns `isSolid ? 4 : 4 + 512` — the record is consumed (bytes are skipped in the stream), not re-parsed.
- Parsing continues at the next record after the skipped bytes.
- `needsKeyframe` is NOT set by this path in v1.0.0 (dormant — see BC-1.02.017 for the v1.1.0 fix).

## Invariants

- `tilesWide = 120 = 1920 / 16` (StarTechTileDecoder.swift:14).
- `tilesHigh = 100 = 1600 / 16` (StarTechTileDecoder.swift:15).
- The 7-bit fields (max 127) allow values 120–127 for X and 100–127 for Y to be "out of range but parseable" — these are all skipped.
- The skip is a clean forward advance; the record bytes are not written to `leftover`.

## Edge Cases

| EC-ID  | Scenario                            | Expected Outcome                          |
|--------|-------------------------------------|-------------------------------------------|
| EC-036 | tileX=120 (first invalid X)         | Record consumed, no pixel write           |
| EC-037 | tileY=100 (first invalid Y)         | Record consumed, no pixel write           |
| EC-038 | tileX=127, tileY=127 (max 7-bit)    | Record consumed, no pixel write           |
| EC-039 | Out-of-range tile followed by valid tile | Valid tile decoded, frame emitted    |
| EC-040 | All records in transfer are OOR     | nil returned (no tile written)            |

## Canonical Test Vectors

| tileX | tileY | Record type | Pixel at (0,0) after call | Frame returned? | Category |
|-------|-------|-------------|---------------------------|-----------------|----------|
| 120   | 0     | solid red   | unchanged (0x00)          | false           | error/OOR (MEDIUM: code-only, no test) |
| 0     | 100   | solid red   | unchanged                 | false           | error/OOR |
| 120   | 0     | solid + then tile(0,0) solid green | (0,0) = green | true | edge (OOR skip + valid) |

## Error Handling

The out-of-range condition is handled silently — no error is emitted to the event stream. In v1.0.0 the condition does not trigger keyframe recovery. The v1.1.0 change (BC-1.02.017) addresses this gap by setting `needsKeyframe = true`.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:122-125 |
| Ingest BC                       | BC-017 (opencrashcart-pass-3-behavioral-contracts.md:22) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — bounds guard; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:122-125 |
| Confidence       | MEDIUM (code-only; no test exercises an out-of-range tile directly) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
