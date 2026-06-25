---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-3-deep-app-layer.md"
subsystem: "SS-03"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.011: Recorder finish Short-Circuits with frameCount=0 When Never Started; Record Start Requires isLive and Non-Zero frameSize.width

## Description

This contract covers two related behaviors: (1) `Recorder.finish()` short-circuits immediately with `completion(0)` when no frames have ever been appended (`started == false`), avoiding an unnecessary AVAssetWriter finalization call. (2) `toggleRecording()` in AppController guards that the session is live and the frame size has a positive width before creating a `Recorder` or showing the save panel.

## Preconditions (finish short-circuit)

- `Recorder.finish(_:)` is called on a recorder where `started == false` (no frames were ever accepted).

## Postconditions (finish short-circuit)

- `completion(0)` is called immediately.
- `input.markAsFinished()` is NOT called.
- `writer.finishWriting` is NOT called.
- The output file is not written.

## Preconditions (record start guard)

- `toggleRecording()` is called in `AppController` while `recorder == nil` (not currently recording).

## Postconditions (record start guard)

**`isLive == false` or `videoView.frameSize.width == 0`**:
- `statusBar.setMessage("Connect to a live target before recording.")` is called.
- `NSSavePanel` is NOT shown.
- `Recorder` is NOT created.

**`isLive == true` AND `videoView.frameSize.width > 0`**:
- `NSSavePanel` is presented to choose output file.
- On user confirmation, `Recorder(url:width:height:)` is called with current frame dimensions.
- On `Recorder` init failure, "Could not start recording." is shown (see BC-1.03.010).
- On success, `recorder` is set and `statusBar.setRecording(true)` is called.

## Invariants

- `finish` callback receives 0 when the recorder was never started.
- `finish` callback receives the actual `frameCount` when the recorder was started.
- Recording dimensions are locked to `videoView.frameSize` at the moment recording starts; subsequent resize events produce dropped frames (per BC-1.03.008), not a new recording session.

## Edge Cases

- **EC-001** — `finish` called on a started recorder: normal path; `input.markAsFinished()` + `writer.finishWriting { completion(n) }` execute; `n == frameCount`.
- **EC-002** — `toggleRecording()` called with `isLive == true` but `frameSize.width == 0`: guard rejects with error message. (This state can occur if `isLive` was set but no frame has been received yet.)
- **EC-003** — User cancels the save panel: `guard resp == .OK` fails; recorder is NOT created; no status change.

## Canonical Test Vectors

| Scenario | started | Expected completion arg |
|----------|---------|------------------------|
| finish never-started | false | 0 (immediate) |
| finish after 10 frames | true | 10 |

| Scenario | isLive | frameSize.width | Expected |
|----------|--------|-----------------|----------|
| Not live | false | 1024 | Error status, no panel |
| Live, zero width | true | 0 | Error status, no panel |
| Live, positive width | true | 1024 | Save panel shown |

## Error Handling

`finish` on an unstarted recorder: no error; `completion(0)` is a clean short-circuit. Record start guard: UI error message only; no exceptions.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/Recorder.swift:67-72`; `Sources/occ/AppController.swift:493-515` |
| Ingest BC | BC-138, BC-139 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-TBD ("Record the decoded video stream to an H.264 .mov file") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/Recorder.swift`, `Sources/occ/AppController.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `Recorder.swift:67-68` `func finish(...) { guard started else { completion(0); return }`; `AppController.swift:498` `guard isLive, videoView.frameSize.width > 0 else { statusBar.setMessage("Connect to a live target before recording."); return }` |
