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
capability: CAP-SNAPSHOT
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.007: snapshotPNG Returns PNG Data from Raw lastImage

## Description

`VideoView.snapshotPNG()` encodes the raw `lastImage` CGImage as PNG. The raw (unenhanced) frame is used regardless of any active image enhancement settings, ensuring the snapshot faithfully represents the actual captured frame pixels.

## Preconditions

- `snapshotPNG()` is called on the `VideoView`.

## Postconditions

**`lastImage` is non-nil**:
- An `NSBitmapImageRep` is created from `lastImage`.
- PNG data is returned via `representation(using: .png, properties: [:])`.
- Return value is non-nil `Data` (assuming `NSBitmapImageRep` encoding succeeds).

**`lastImage` is nil** (no frame received yet):
- Returns `nil`.
- No encoding attempt is made.

## Invariants

- The snapshot always uses the raw frame (`lastImage`), not the enhanced display image.
- Enhancement state (brightness, contrast, sharpness, grayscale) does not affect snapshot output.
- The encoding format is always PNG.

## Edge Cases

- **EC-001** — No frame has been received yet: `lastImage` is nil; returns nil. Caller (`snapshot()` in AppController at `:627`) shows status "No frame to snapshot yet."
- **EC-002** — Enhancement is active at time of snapshot: enhancement is ignored; raw frame is used.
- **EC-003** — `NSBitmapImageRep.representation` returns nil (very rare memory/encoding failure): `snapshotPNG` returns nil; caller shows error status.

## Canonical Test Vectors

| Scenario | lastImage | Enhancement active | Expected return |
|----------|-----------|--------------------|----------------|
| Frame present, no enhancement | CGImage 1024×768 | No | PNG Data (non-nil) |
| Frame present, enhancement active | CGImage 1024×768 | Yes (brightness +0.5) | PNG Data of raw frame (non-nil) |
| No frame yet | nil | No | nil |

## Error Handling

`NSBitmapImageRep.representation` returns an optional; nil is propagated to caller. No exceptions.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoView.swift:119-123` |
| Ingest BC | BC-125 partial, BC-pass-2-deep `:23` "snapshotPNG wraps lastImage→PNG" |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-SNAPSHOT ("Capture a PNG snapshot of the current raw video frame") |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/VideoView.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:119` `func snapshotPNG() -> Data?`; `:120` `guard let image = lastImage else { return nil }`; `:121` `let rep = NSBitmapImageRep(cgImage: image)`; `:122` `return rep.representation(using: .png, properties: [:])` |
