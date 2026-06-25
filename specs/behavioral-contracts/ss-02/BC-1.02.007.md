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

# BC-1.02.007: Frame Emitted Only When at Least One Tile Written (sawTileSinceEmit Gate)

## Description

`ingest()` returns a non-nil `VideoFrame` only when at least one tile (solid or raw) was successfully written to the framebuffer during that call. The `sawTileSinceEmit` flag is reset to `false` at the top of each `ingest()` call and set to `true` each time `fillTile` or `decodeRawTile` writes pixels. A transfer containing only padding records, or a transfer that is entirely a continuation of a partial record that still isn't complete, produces no frame.

## Preconditions

- `ingest()` has been called with a non-empty byte slice.
- The decoder is not in a reset state.

## Postconditions

- `sawTileSinceEmit` is reset to `false` at the start of each `ingest()` call (StarTechTileDecoder.swift:52).
- `sawTileSinceEmit` is set to `true` whenever `fillTile` (line 129) or `decodeRawTile` (line 133) is called.
- The return value of `ingest()` is `snapshotActiveRegion()` if `sawTileSinceEmit == true`, else `nil` (line 77).
- `snapshotActiveRegion()` copies the `activeWidth × activeHeight` sub-rectangle from the framebuffer into a new `VideoFrame`.

## Invariants

- A call to `ingest()` that processes only padding or only an incomplete partial record always returns `nil`.
- A call that processes at least one in-bounds solid or raw tile always returns a non-nil frame.
- The frame dimensions equal `(activeWidth, activeHeight)` as set by `setActiveSize`.
- The frame pixel buffer is always newly allocated — it is not a view into the framebuffer.

## Edge Cases

| EC-ID  | Scenario                                              | Expected Outcome        |
|--------|-------------------------------------------------------|-------------------------|
| EC-031 | Transfer contains only padding (FFFF/FFFF + zeros)    | nil returned            |
| EC-032 | Transfer is incomplete leftover only (still waiting)  | nil returned            |
| EC-033 | Transfer contains one solid tile                      | non-nil frame returned  |
| EC-034 | Transfer contains two tiles                           | one frame returned (second tile's data included) |
| EC-035 | Transfer contains solid tile + out-of-range tile       | non-nil frame (solid tile was written) |

## Canonical Test Vectors

| Scenario                           | Input                                     | Expected output       | Category    |
|------------------------------------|-------------------------------------------|-----------------------|-------------|
| One solid tile in transfer         | tileHeader(x:0,y:0,solid:true,word0:0xF800) | VideoFrame != nil   | happy-path  |
| Padding only (512 bytes)           | [FF,FF,FF,FF] + 508 zeros                 | nil                   | edge        |
| Partial raw record first half      | raw record [0..<200]                      | nil                   | error path  |

## Error Handling

Not applicable — this is a pure emission gate. The flag cannot be corrupted externally because `ingest()` resets it at the start and `lock` is held throughout.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:51-52 (reset), :77 (gate), :129,133 (set) |
| Ingest BC                       | BC-016 (opencrashcart-pass-3-behavioral-contracts.md:21) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — frame emission gate; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:51-52, 77, 129, 133 |
| Confidence       | HIGH (directly read from source; logic is unambiguous; test suite exercises both nil and non-nil paths) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
