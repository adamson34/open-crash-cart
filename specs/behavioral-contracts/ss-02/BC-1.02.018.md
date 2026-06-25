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
introduced: v1.1.0
---

# BC-1.02.018: Decoder Requests Keyframe on Desync (v1.1.0 — Corrects Dormant Defect)

## Description

**This contract formalizes a v1.1.0 behavior change. It describes the CORRECTED behavior, not the current v1.0.0 code.**

In v1.0.0, `StarTechTileDecoder` exposes `needsKeyframe: Bool`, and `StarTechAdapter.videoLoop` checks it after each `decoder.ingest()` and enqueues `VSPack.command(.doIFrame)` at control priority when true (StarTechAdapter.swift:299-301). But the decoder **never sets `needsKeyframe = true`** — line 51 only ever clears it. The recovery path is dead code, so stream corruption permanently degrades the display with no self-heal (ingest BC-019). **This defect wiring is confirmed HIGH from source.**

**v1.1.0 corrected behavior.** The decoder detects desync with two *reachable* signals (the v1.0.0 contract's "leftover > leftoverNeeded" trigger was rejected in adversarial review B2 — `take = min(leftoverNeeded - leftover.count, data.count)` at TileDecoder.swift:58-60 makes that condition unreachable). Replacement signals:

1. **Garbage-coordinate burst (per-ingest):** `processRecord` already skips records whose coordinates are out of range — and because the valid tile grid is `tilesWide = 120 × tilesHigh = 100` while the 7-bit fields allow 0..127, **`tileY >= tilesHigh` (≥100) or `tileX >= tilesWide` (≥120) is always invalid**. The decoder counts these skipped-as-invalid records within a single `ingest()` call; if the count reaches `oorThreshold` (default 8), it sets `needsKeyframe = true`. (This replaces the rejected "both axes ≥110" heuristic from B4, which AND-gated two axes and missed single-axis garbage.)

2. **Sustained no-decode (cross-ingest):** a `staleIngestCount` increments on each non-empty `ingest()` that writes **zero in-range tiles**; when it reaches `staleThreshold` (default 8), the decoder sets `needsKeyframe = true` and resets the counter. A successful in-range tile write resets `staleIngestCount = 0`.

**Bounded I-frame request (corrects B3 spam risk).** `StarTechAdapter` holds a `keyframeRequested: Bool` latch. When `decoder.needsKeyframe == true` after an ingest, `videoLoop` enqueues `.doIFrame` **only if `!keyframeRequested`**, then sets `keyframeRequested = true`. The latch is cleared **only when a clean frame is decoded** (an `ingest()` that writes ≥1 in-range tile with zero invalid-coordinate skips). This guarantees **at most one outstanding `.doIFrame` between clean frames** — no per-ingest enqueue, no unbounded `controlQ` growth under sustained desync.

**Self-healing property.** After the device returns a keyframe and the decoder writes clean in-range tiles, `staleIngestCount` and the invalid-skip counter reset, `keyframeRequested` clears, and normal incremental operation resumes.

## Preconditions

1. The decoder is running (not in `reset()` state); `decoder.ingest(chunk)` was just called with a non-empty chunk.
2. A desync condition holds: either (a) ≥ `oorThreshold` (default 8) records in this `ingest()` were skipped for out-of-range coordinates (`tileX >= tilesWide || tileY >= tilesHigh`), or (b) `staleIngestCount` reached `staleThreshold` (default 8) consecutive non-empty ingests with zero in-range tiles written.

## Postconditions

1. `decoder.needsKeyframe == true` after the triggering `ingest()` returns.
2. `videoLoop` enqueues `VSPack.command(.doIFrame)` at `.control` priority **iff** `keyframeRequested == false`; it then sets `keyframeRequested = true`.
3. While `keyframeRequested == true`, no further `.doIFrame` is enqueued, regardless of how many subsequent ingests report `needsKeyframe`.
4. On the next `ingest()` that writes ≥1 in-range tile with zero invalid-coordinate skips, the decoder resets `staleIngestCount = 0` and the invalid-skip state, and `StarTechAdapter` clears `keyframeRequested = false`.

## Invariants

1. **At most one outstanding `.doIFrame` between clean frames** (the `keyframeRequested` latch) — bounded `controlQ` contribution from this path.
2. The desync triggers are *reachable*: `tileY >= tilesHigh` is a real, frequently-occurring corruption signature (not the unreachable leftover-overflow nor the incoherent both-axes-≥110 rule).
3. `.doIFrame` is enqueued at `.control` priority: it never preempts in-flight keyboard/mouse input, and is not starved by input (drained after `inputQ`).
4. `reset()` clears `needsKeyframe`, `keyframeRequested`, `staleIngestCount`, and the invalid-skip counter — reconnect never emits a spurious I-frame.
5. A single mildly-out-of-range record (one skipped tile) does NOT trigger keyframe recovery — only crossing `oorThreshold`/`staleThreshold` does.

## Edge Cases

| EC-ID  | Scenario | Expected Outcome |
|--------|----------|------------------|
| EC-088 | Normal transfer, all tiles in range | needsKeyframe false; staleIngestCount=0; no I-frame |
| EC-089 | 8+ records in one ingest skipped for tileY≥100 (garbage) | needsKeyframe=true; I-frame enqueued (latch was false) |
| EC-090 | 1 record skipped (tileX=121) in an otherwise-clean ingest | needsKeyframe false (below oorThreshold) |
| EC-091 | 8 consecutive non-empty ingests write zero in-range tiles | needsKeyframe=true on the 8th; staleIngestCount resets; I-frame enqueued |
| EC-092 | needsKeyframe true on ingest N, and again on N+1 (still desynced) | I-frame enqueued once (N); NOT re-enqueued on N+1 (keyframeRequested latched) |
| EC-093 | Device returns keyframe → ingest writes clean in-range tiles | counters + keyframeRequested reset; display recovers; subsequent desync can request again |
| EC-094 | `reset()` / reconnect mid-desync | all desync state cleared; no spurious I-frame |
| EC-095 | `queue` closed (disconnect) when enqueue attempted | enqueue is a no-op; videoLoop exits on next USB read error (no extra handling) |

## Canonical Test Vectors

| Scenario | needsKeyframe after ingest | I-frame enqueued this call | Category |
|----------|---------------------------|----------------------------|----------|
| Clean transfer, in-range tiles | false | no | happy-path |
| 8 records skipped tileY=100..127 in one ingest | true | yes (latch false→true) | error (v1.1.0 new) |
| 8th consecutive zero-in-range-tile ingest | true | yes | error (v1.1.0 new) |
| Still desynced on the following ingest (latch already set) | true | **no** (latch held) | edge (spam guard) |
| 1 out-of-range record only (below threshold) | false | no | edge |
| Keyframe arrives, clean ingest follows | false | no (latch cleared) | happy-path (recovery) |

## Error Handling

If `.doIFrame` cannot be enqueued because `queue` is closed (disconnect), the enqueue is a silent no-op and `videoLoop` exits on the next USB read error — consistent with existing transport teardown. No additional error handling is required.

## Current State (v1.0.0 — Dormant Defect)

`needsKeyframe` is cleared at the start of every `ingest()` (StarTechTileDecoder.swift:51) and never set true anywhere, so the `videoLoop` check (StarTechAdapter.swift:299-301) is dead code. Any stream corruption yields a permanently degraded display with no recovery. Source: `opencrashcart-pass-3-behavioral-contracts.md:24` (BC-019).

## Traceability

| Field | Value |
|-------|-------|
| Source file:line (dormant defect) | StarTechTileDecoder.swift:51 (clears only); StarTechAdapter.swift:299-301 (dead check) |
| Source file:line (v1.1.0 target) | StarTechTileDecoder.swift: new invalid-skip counter in `processRecord` (~:118-125) + `staleIngestCount` in `ingest` (~:49-78); StarTechAdapter.swift: new `keyframeRequested` latch around :299-301 |
| Ingest BC | BC-019 |
| Adversary findings addressed | B2 (unreachable trigger), B3 (I-frame spam), B4 (incoherent OOR heuristic) |
| Stories | (filled by story-writer) |
| Capability Anchor Justification | CAP-TBD — desync recovery / keyframe self-heal |
| Related BCs | BC-1.02.006 (reassembly), BC-1.02.008 (OOR skip), BC-1.02.007 (emission gate) |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | StarTechTileDecoder.swift:45,51,58-60,118-125; StarTechAdapter.swift:299-301 |
| Confidence | Defect wiring: **HIGH** (verified — `needsKeyframe` wired but never fired). Fix trigger/latch design: **proposed v1.1.0** (must be implemented + tested; reachability of `tileY>=tilesHigh` confirmed from grid geometry 120×100 vs 7-bit field). |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code analysis + ingest divergence note; v1.1.0 design |
