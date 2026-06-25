---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "opencrashcart-pass-3-deep-app-layer.md"
subsystem: "SS-02"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.02.011: VideoView Default frameSize 1024x768

## Description

`VideoView` initialises its `frameSize` property to `CGSize(width: 1024, height: 768)` before any video frame is received. This default governs all mouse coordinate calculations and the aspect-fit letterbox computation until the first real frame arrives and calls `display()`. An incorrect default would produce offset mouse clicks on the target machine before the first frame is rendered.

## Preconditions

- A `VideoView` instance has been created via `init(frame:)`.
- No call to `display(_:)` has been made yet.

## Postconditions

- `frameSize.width == 1024.0`
- `frameSize.height == 768.0`
- The CALayer `contentsGravity` is `.resizeAspect` and `magnificationFilter` is `.nearest`.
- The layer background is `NSColor.black.cgColor`.

## Invariants

- `frameSize` is updated by each call to `display(_:)` to the incoming `frame.width × frame.height`.
- No other method mutates `frameSize` before `display` is called.
- The 1024×768 default is the most common legacy crash-cart resolution; it ensures mouse events are not accidentally clamped to zero before the first frame.

## Edge Cases

| EC-ID  | Scenario                            | Expected Outcome                           |
|--------|-------------------------------------|--------------------------------------------|
| EC-054 | View created, no frame yet          | frameSize = (1024, 768)                   |
| EC-055 | display() called with 1920×1080     | frameSize updated to (1920, 1080)          |
| EC-056 | display() called twice              | frameSize reflects second frame dimensions |

## Canonical Test Vectors

| Action                    | frameSize.width | frameSize.height | Category  |
|---------------------------|-----------------|------------------|-----------|
| init(frame:) only         | 1024            | 768              | happy-path (BC-AUDIT-013 from deep-app-layer) |
| After display(1280×720)   | 1280            | 720              | happy-path |

## Error Handling

Not applicable — the default is a compile-time constant.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/occ/VideoView.swift:42 |
| Ingest BC                       | BC-AUDIT-013 (opencrashcart-pass-3-deep-app-layer.md — VideoView section) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — video display init; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/occ/VideoView.swift:42 |
| Confidence       | MEDIUM (no app-layer tests; read directly from source) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
