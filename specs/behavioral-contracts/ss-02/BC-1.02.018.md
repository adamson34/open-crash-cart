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
introduced: v1.1.0
---

# BC-1.02.018: Decoder Requests Keyframe on Desync (v1.1.0 — Corrects Dormant Defect)

## Description

**This contract formalizes a v1.1.0 behavior change. It describes the CORRECTED behavior, not the current v1.0.0 code.**

In v1.0.0, `StarTechTileDecoder` has a `needsKeyframe: Bool` property wired into `StarTechAdapter.videoLoop` — after each `decoder.ingest()` call, the loop checks `decoder.needsKeyframe` and if true enqueues `VSPack.command(.doIFrame)` to the control queue (StarTechAdapter.swift:299-301). However, in v1.0.0 the decoder never sets `needsKeyframe = true` (it is only cleared, at StarTechTileDecoder.swift:51 and :45). This means video desync — caused by record-reassembly failure or wildly out-of-range tile coordinates — permanently corrupts the displayed frame with no recovery path. This is a documented dormant defect (ingest BC-019).

**v1.1.0 corrected behavior:** `StarTechTileDecoder` sets `needsKeyframe = true` in two new conditions:

1. **Reassembly failure:** During the leftover-completion path (StarTechTileDecoder.swift:56-71), if the reassembled `leftover` would exceed `leftoverNeeded` bytes (a sign of stream corruption rather than a clean split), the decoder abandons the partial record, clears `leftover`, resets `leftoverNeeded = 0`, and sets `needsKeyframe = true`.

2. **Wild out-of-range coordinates:** In `processRecord`, when `tileX >= tilesWide || tileY >= tilesHigh` AND the coordinate values exceed the 7-bit field's plausible range (e.g., both X and Y are at the maximum 127 — indicating random/garbage data rather than a legitimate high tile index near the boundary), `needsKeyframe` is set to `true`. A single mildly-out-of-range tile does NOT trigger keyframe recovery; only clearly corrupt coordinates (heuristic: both axes simultaneously at or above a configurable threshold, default 110) do.

**videoLoop reaction:** When `decoder.needsKeyframe == true` after an `ingest()` call, `videoLoop` enqueues a `.doIFrame` command (ASCII 'i') at control priority. The device responds with a full keyframe, restoring a coherent display.

**Self-healing property:** After the I-frame arrives and the decoder successfully processes full tile records, the next ingest call clears `needsKeyframe = false` (line 51) and normal incremental operation resumes.

## Preconditions

- The decoder is running (not in `reset()` state).
- `decoder.ingest(chunk)` has just been called.
- One of:
  - The leftover reassembly buffer received more bytes than `leftoverNeeded` (stream framing error).
  - `processRecord` encountered tile coordinates where both X and Y simultaneously exceed the "wildly OOR" threshold (default: ≥ 110, i.e., > 14 tiles beyond the 96-column edge).

## Postconditions

- `needsKeyframe = true` is set before `ingest()` returns.
- `ingest()` may return `nil` (if no tile was written) or a partial frame.
- `StarTechAdapter.videoLoop` detects `decoder.needsKeyframe == true` at StarTechAdapter.swift:299.
- `queue.enqueue(VSPack.command(.doIFrame), priority: .control)` is called.
- The device receives 'i' and responds with a full keyframe within the next video cycle.
- On the next call to `ingest()`, `needsKeyframe` is reset to `false` (line 51) regardless of content.

## Invariants

- `needsKeyframe` is ephemeral: set in one `ingest()` call, consumed and cleared at the start of the next.
- The I-frame command is enqueued at `.control` priority — it does not preempt in-flight keyboard/mouse input but is not starved by input events.
- A single mildly-out-of-range tile (tileX = 121, tileY = 5) does NOT set `needsKeyframe`; only the "wildly OOR" condition does.
- `reset()` clears `needsKeyframe = false` (StarTechTileDecoder.swift:45); reconnect does not trigger spurious I-frames.

## Edge Cases

| EC-ID  | Scenario                                        | Expected Outcome                                              |
|--------|-------------------------------------------------|---------------------------------------------------------------|
| EC-088 | Normal transfer, all tiles in range             | needsKeyframe stays false; no I-frame enqueued                |
| EC-089 | Leftover byte count exceeds leftoverNeeded       | needsKeyframe = true; I-frame enqueued                       |
| EC-090 | Single out-of-range tile (tileX=121, tileY=5)   | needsKeyframe stays false (mild OOR, not "wild")             |
| EC-091 | Both axes wildly OOR (tileX=127, tileY=127)     | needsKeyframe = true; I-frame enqueued                       |
| EC-092 | I-frame enqueued, device sends keyframe          | Next ingest clears needsKeyframe; display recovers            |
| EC-093 | reset() called                                  | needsKeyframe = false; no I-frame on reconnect               |
| EC-094 | Multiple consecutive desync frames              | I-frame enqueued on each until ingest succeeds cleanly       |

## Canonical Test Vectors

| Scenario                                           | needsKeyframe after ingest | I-frame enqueued | Category     |
|----------------------------------------------------|---------------------------|------------------|--------------|
| Clean transfer with valid tiles                    | false                     | no               | happy-path   |
| Leftover overflow (corrupt stream)                 | true                      | yes              | error (v1.1.0 new) |
| tileX=127, tileY=127 (wildly OOR)                  | true                      | yes              | error (v1.1.0 new) |
| tileX=121, tileY=5 (mildly OOR, not wild)          | false                     | no               | edge         |
| After I-frame received and clean ingest            | false                     | no               | happy-path (recovery) |

## Error Handling

If `requestKeyframe()` fails to enqueue (e.g., `queue` is closed due to disconnect), the video loop will exit naturally on the next USB read error. No additional error handling is required for the keyframe path.

## Current State (v1.0.0 — Dormant Defect)

In v1.0.0 code at StarTechTileDecoder.swift:51, `needsKeyframe` is unconditionally set to `false` at the start of every `ingest()` call, and there is NO code that ever sets it to `true` during normal operation. The `videoLoop` check at StarTechAdapter.swift:299-301 is therefore dead code. This means any stream corruption results in a permanently incorrect or frozen display with no self-healing.

Source: `opencrashcart-pass-3-behavioral-contracts.md:24` — "BC-019 needsKeyframe never set true → documented desync/I-frame loop dormant."

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line (dormant defect) | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:51 (clears only); StarTechAdapter.swift:299-301 (dead check) |
| Source file:line (v1.1.0 target) | StarTechTileDecoder.swift: new code in leftover path (~line 69) and processRecord (~line 124) |
| Ingest BC                       | BC-019 (opencrashcart-pass-3-behavioral-contracts.md:24) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — desync recovery / keyframe self-heal; capability file not yet produced |
| Related BCs                     | BC-1.02.006 (reassembly), BC-1.02.008 (OOR skip), BC-1.02.007 (emission gate) |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift:45, 51; StarTechAdapter.swift:299-301 |
| Confidence       | LOW (documented divergence in ingest pass; needsKeyframe wired but never fired — confirmed from direct source read) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis + ingest document divergence note |
