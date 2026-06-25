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
capability: CAP-RECORD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.008: Recorder Drops Size-Mismatch Frames to Prevent File Corruption

## Description

`Recorder.append(_:)` silently drops any frame whose pixel dimensions differ from the width and height locked at `Recorder.init` time. This prevents AVAssetWriter from receiving frames of mixed dimensions, which would corrupt the output .mov file.

## Preconditions

- A `Recorder` instance has been successfully initialized with a specific `width` and `height`.
- `append(_:)` is called with a `VideoFrame`.

## Postconditions

**Frame dimensions match** (`frame.width == width && frame.height == height`):
- Frame is processed and appended to the recording.
- `frameCount` is incremented.

**Frame dimensions mismatch** (`frame.width != width || frame.height != height`):
- Frame is immediately dropped; `return` with no further processing.
- `frameCount` is NOT incremented.
- `AVAssetWriter` receives no call for this frame.
- No error is raised; the mismatch is silent.

## Invariants

- All frames written to the `AVAssetWriter` have identical dimensions equal to those specified at `init` time.
- `frameCount` counts only successfully appended frames.
- Width and height are immutable after initialization.

## Edge Cases

- **EC-001** — Video source changes resolution mid-recording (e.g., device reconnect): all new-resolution frames are dropped; recording continues with original-resolution frames only.
- **EC-002** — All frames after the first have a different resolution: only the first frame is recorded (if it matched); `finish()` yields `frameCount == 1`.
- **EC-003** — Frame has zero width or height: mismatches the stored positive dimension; dropped silently.

## Canonical Test Vectors

| Scenario | frame.width | frame.height | recorder width | recorder height | Appended? | frameCount after |
|----------|-------------|--------------|----------------|-----------------|-----------|-----------------|
| Match | 1024 | 768 | 1024 | 768 | Yes | +1 |
| Width mismatch | 800 | 768 | 1024 | 768 | No | unchanged |
| Height mismatch | 1024 | 600 | 1024 | 768 | No | unchanged |
| Both mismatch | 800 | 600 | 1024 | 768 | No | unchanged |

## Error Handling

Mismatches are silently dropped. No error is surfaced to the UI. This is by design to avoid corrupting the output file.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/Recorder.swift:38-39` |
| Ingest BC | BC-135 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-RECORD ("Record the decoded video stream to an H.264 .mov file") per capabilities.md §CAP-RECORD |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/Recorder.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:38` `func append(_ frame: VideoFrame) {`; `:39` `guard frame.width == width, frame.height == height else { return }` |
