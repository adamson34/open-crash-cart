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

# BC-1.03.010: Recorder init Fails Closed When AVAssetWriter or canAdd Fail

## Description

`Recorder.init?` is failable. If `AVAssetWriter` cannot be created (invalid URL, unsupported file type, file system error) or if `writer.canAdd(input)` returns `false`, the initializer returns `nil`. The caller (`toggleRecording` in AppController) checks for nil and shows an error status message rather than proceeding with a broken recorder.

## Preconditions

- `Recorder(url:width:height:)` is called with a file URL, width, and height.

## Postconditions

**AVAssetWriter creation fails** (`try? AVAssetWriter(...)` returns `nil`):
- Initializer returns `nil`.
- No `writer`, `input`, or `adaptor` state is set.

**`writer.canAdd(input)` returns `false`**:
- Initializer returns `nil`.
- `writer` and `input` are in a partially constructed state but the instance is discarded.

**Both succeed**:
- `writer.add(input)` is called.
- A fully initialized `Recorder` instance is returned.
- `started == false`, `frameCount == 0`.

## Invariants

- A non-nil `Recorder` always has a valid `writer` with the `input` added.
- A non-nil `Recorder` never starts writing until the first `append` call.
- `input.expectsMediaDataInRealTime = true` is always set.
- Pixel buffer format is always `kCVPixelFormatType_32BGRA`.
- Codec is always `AVVideoCodecType.h264`, container `.mov`.

## Edge Cases

- **EC-001** — URL points to a read-only location: `AVAssetWriter` creation fails; returns `nil`; AppController shows "Could not start recording."
- **EC-002** — Width or height is 0: `AVAssetWriter` may accept it but `canAdd` or downstream `pixelBufferPool` creation will fail; the lazy-start guard in `append` at `:47` protects against a nil pool.
- **EC-003** — Width or height is negative: same as EC-002.

## Canonical Test Vectors

| Scenario | Expected |
|----------|----------|
| Valid URL, 1024×768 | Non-nil Recorder |
| Invalid/nil URL | nil Recorder; caller shows error |
| canAdd returns false (stubbed) | nil Recorder |

## Error Handling

`try?` is used for `AVAssetWriter` creation; nil propagated as failable init return. Caller at `AppController.swift:508-510` checks `guard let rec = Recorder(...)` and shows "Could not start recording." on nil.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/Recorder.swift:18-36` |
| Ingest BC | BC-137 (pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-TBD ("Record the decoded video stream to an H.264 .mov file") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/Recorder.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:18` `init?(url: URL, width: Int, height: Int) {`; `:21` `guard let w = try? AVAssetWriter(...) else { return nil }`; `:34` `guard writer.canAdd(input) else { return nil }`; `:35` `writer.add(input)` |
