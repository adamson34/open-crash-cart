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

# BC-1.02.006: Partial Record Reassembly Across USB Transfers (Incomplete Returns Nil)

## Description

USB bulk transfers do not guarantee record alignment. A tile record (4 bytes for solid, 516 bytes for raw) may be split across two consecutive calls to `ingest()`. The decoder stashes the tail of a partial record in `leftover` and returns `nil` from the first call. On the next call, it prepends the leftover bytes and processes the complete record before continuing with the remainder of the new transfer.

## Preconditions

- A record begins within the current transfer `data` but its total size exceeds the remaining bytes (`count - pos < recordSize`).
- The header word pair is present (the `while count - pos >= 4` loop guard has passed) so `isSolid` and `recordSize` are known.
- `leftoverNeeded == 0` at the start of the call (no prior partial record pending).

## Postconditions

**First call (partial transfer):**
- `leftover = Array(data[pos..<count])` — the available tail bytes are stashed.
- `leftoverNeeded = recordSize` (4 for solid, 516 for raw).
- `ingest()` returns `nil` (no frame emitted).

**Second call (completion):**
- At the top of `ingest()`, the `leftoverNeeded > 0` branch is entered.
- `take = min(leftoverNeeded - leftover.count, data.count)` bytes are appended to `leftover`.
- If `leftover.count == leftoverNeeded`: the complete record is processed via `processRecord`, `leftover` is cleared, `leftoverNeeded = 0`.
- If still incomplete (very short second transfer): `nil` is returned again (waiting continues).
- After completing the leftover record, remaining bytes in `data` are processed normally via `processBuffer`.
- If a tile was written, a frame is returned.

## Invariants

- `leftover` always contains a contiguous prefix of one record (never multi-record or interleaved).
- `leftoverNeeded` is always either 0 or the full record size (4 or 516).
- The reassembly path handles only the current leftover record; it does not call `processBuffer` recursively for the leftover bytes.
- `reset()` clears `leftover` and `leftoverNeeded`.

## Edge Cases

| EC-ID  | Scenario                                           | Expected Outcome                                |
|--------|----------------------------------------------------|-------------------------------------------------|
| EC-026 | First transfer: first 200 bytes of 516-byte raw record | leftover=[200B], leftoverNeeded=516, nil returned |
| EC-027 | Second transfer: remaining 316 bytes               | Record completed, tile decoded, frame returned  |
| EC-028 | Second transfer also too short (e.g. 100 more bytes) | Still waiting (leftover=300B), nil returned   |
| EC-029 | Solid record split: first 2 bytes arrive           | leftover=[2B], leftoverNeeded=4, nil            |
| EC-030 | Second transfer completes solid + more records    | Solid tile decoded, then remaining records processed |

## Canonical Test Vectors

| Scenario                           | Call 1 input             | Call 1 output | Call 2 input         | Call 2 output              | Category     |
|------------------------------------|--------------------------|---------------|----------------------|----------------------------|--------------|
| Raw 516-byte record split at 200   | full[0..<200] (200B)     | nil           | full[200..<516] (316B)| VideoFrame with G=0xFC     | happy-path (test-pinned: TileDecoderTests.swift:50-58) |

## Error Handling

No error is raised for partial records; the caller simply receives `nil` and must call `ingest()` again with the next USB transfer. If the device is disconnected mid-transfer, `reset()` is called on reconnect, discarding the stale `leftover`.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:56-71 (leftover completion), :100-106 (stash) |
| Ingest BC                       | BC-015 (opencrashcart-pass-3-behavioral-contracts.md:20) |
| Test file:line                  | Sources/occ-tests/TileDecoderTests.swift:50-58 |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — transfer reassembly; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:56-71, 100-106 |
| Confidence       | HIGH (test-pinned: TileDecoderTests.swift:50-58 splits a 516-byte record at byte 200) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code + test suite |
