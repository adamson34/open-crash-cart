---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: opencrashcart-pass-3-deep-app-layer.md
subsystem: SS-03
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.009: Recorder Lazy Session Start on First Accepted Frame with Real-Time PTS at Timescale 600

## Description

`Recorder` defers `AVAssetWriter.startWriting()` and `startSession(atSourceTime:)` until the first frame that passes the size check. Presentation timestamps are computed as `CACurrentMediaTime() - startTime` with `preferredTimescale: 600`, giving sub-millisecond precision. This lazy approach means `init` does not start writing, allowing a recording object to exist without output until a valid frame arrives.

## Preconditions

- `Recorder` has been successfully initialized.
- `append(_:)` is called with a frame that passes the dimension guard (per BC-1.03.008).

## Postconditions

**First accepted frame** (`started == false`):
- `startTime = CACurrentMediaTime()` is recorded.
- `writer.startWriting()` is called.
- `writer.startSession(atSourceTime: .zero)` is called.
- `started = true`.
- The frame is then appended with PTS `CMTime(seconds: 0, preferredTimescale: 600)` (since `now - startTime ≈ 0`).

**Subsequent accepted frames** (`started == true`):
- `startTime` is unchanged.
- No new session is started.
- PTS = `CMTime(seconds: max(0, CACurrentMediaTime() - startTime), preferredTimescale: 600)`.

## Invariants

- `writer.startWriting()` is called exactly once per `Recorder` instance.
- `startTime` is set exactly once (on the first accepted frame).
- PTS is always non-negative (enforced by `max(0, ...)`).
- Timescale is always 600.

## Edge Cases

- **EC-001** — Very long recording: PTS values grow as `Double` seconds; at timescale 600, the value is precise to 1/600 second (~1.67 ms). No overflow concern for typical crash-cart sessions.
- **EC-002** — Clock wraps or goes backward: `max(0, now - startTime)` clamps PTS to 0; frame is appended with PTS 0 rather than a negative time.
- **EC-003** — `input.isReadyForMoreMediaData` is false or `pixelBufferPool` is nil: frame is dropped without incrementing `frameCount` (secondary guard at `:47`). `started` remains `true`.

## Canonical Test Vectors

| Scenario | started before call | Expected |
|----------|--------------------|------------------------------------------------------------|
| First frame | false | startWriting + startSession called; started=true; PTS≈0s @600 |
| Second frame at +1s | true | startWriting NOT called; PTS≈CMTime(seconds:1, timescale:600) |
| Frame when input not ready | true | dropped; frameCount unchanged |

## Error Handling

No throws. The `guard input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool` guard silently drops frames when the writer backpressures.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/Recorder.swift:40-64` |
| Ingest BC | BC-136 (pass-3-deep-app-layer.md) |
| Stories | (filled by story-writer) |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-TBD ("Record the decoded video stream to an H.264 .mov file") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/Recorder.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:40` `let now = CACurrentMediaTime()`; `:41-46` `if !started { startTime = now; writer.startWriting(); writer.startSession(atSourceTime: .zero); started = true }`; `:62` `CMTime(seconds: max(0, now - startTime), preferredTimescale: 600)` |
