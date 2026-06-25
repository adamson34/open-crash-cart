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

# BC-1.02.015: Relative Mouse Mode Rounded Clamped Int16 Deltas

## Description

When `relativeMode == true`, `VideoView.sendMouse()` sends movement as signed integer deltas rather than absolute coordinates. The raw `CGFloat` deltas from the NSEvent (`deltaX`, `deltaY`) are rounded to the nearest integer and clamped to the `Int16` range `[-32768, 32767]` via `Int16(clamping:)`. This matches the `MouseEvent.isAbsolute = false` path in VSPack, which encodes x and y as signed 16-bit values.

## Preconditions

- `relativeMode == true`.
- `selecting == false`.
- An `NSEvent` with valid `deltaX` and `deltaY` fields is being processed.

## Postconditions

- `dx = Int16(clamping: Int(event.deltaX.rounded()))`.
- `dy = Int16(clamping: Int(event.deltaY.rounded()))`.
- `sendMouse(buttons: buttons, x: dx, y: dy, wheel: wheel, absolute: false)` is called.
- Absolute coordinates are NOT computed in relative mode (the letterbox mapping is skipped entirely).

## Invariants

- `.rounded()` uses banker's rounding (Swift default: `.toNearestOrAwayFromZero` for `CGFloat.rounded()`).
- Deltas represent per-event movement, not accumulated position.
- `Int16(clamping:)` prevents overflow for very large single-event deltas.

## Edge Cases

| EC-ID  | Scenario                          | Expected Outcome                        |
|--------|-----------------------------------|-----------------------------------------|
| EC-073 | deltaX=0.4, deltaY=0.6            | dx=0, dy=1                             |
| EC-074 | deltaX=100000.0                   | dx=32767 (Int16 max, clamped)           |
| EC-075 | deltaX=-100000.0                  | dx=-32768 (Int16 min, clamped)          |
| EC-076 | deltaX=0.0, deltaY=0.0 (no movement) | dx=0, dy=0 — still forwarded         |
| EC-077 | Cursor is hidden in relative mode | sendMouse still called (CGAssociate handles cursor) |

## Canonical Test Vectors

| deltaX   | deltaY   | Expected dx | Expected dy | absolute | Category  |
|----------|----------|-------------|-------------|----------|-----------|
| 5.3      | -2.7     | 5           | -3          | false    | happy-path (BC-120 reference) |
| 0.4      | 0.6      | 0           | 1           | false    | edge (rounding) |
| 100000.0 | 0.0      | 32767       | 0           | false    | edge (Int16 clamp) |
| 0.0      | 0.0      | 0           | 0           | false    | edge (zero delta) |

## Error Handling

Not applicable — `Int16(clamping:)` prevents all overflow. No error path exists.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/occ/VideoView.swift:289-293 |
| Ingest BC                       | BC-120 (opencrashcart-pass-3-deep-app-layer.md:28) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — relative mouse encoding; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/occ/VideoView.swift:289-293 |
| Confidence       | MEDIUM (code-only; no app-layer tests) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
