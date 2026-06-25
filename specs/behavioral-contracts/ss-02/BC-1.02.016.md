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

# BC-1.02.016: Mouse Buttons from pressedMouseButtons Global State, Wheel ±1/0

## Description

Mouse button state is read from `NSEvent.pressedMouseButtons` (a global bitmask of currently-pressed buttons) at the time each mouse event is processed, rather than tracking cumulative state in the view. This approach guarantees buttons are accurate at event time. The scroll wheel maps `scrollingDeltaY > 0` to `+1`, `< 0` to `-1`, and exactly `0` to `0`.

## Preconditions

- A mouse event (move, down, up, drag, scroll) is being processed in `sendMouse()`.
- `selecting == false`.

## Postconditions

- `raw = NSEvent.pressedMouseButtons` — global bitmask at event time.
- Bit 0 (`raw & 0b001 != 0`) → `.left` inserted into `buttons`.
- Bit 1 (`raw & 0b010 != 0`) → `.right` inserted into `buttons`.
- Bit 2 (`raw & 0b100 != 0`) → `.middle` inserted into `buttons`.
- `wheel: Int16 = scrollingDeltaY > 0 ? 1 : (scrollingDeltaY < 0 ? -1 : 0)` (for scroll events).
- Non-scroll events pass `wheel: 0` (default parameter).

## Invariants

- `MouseButtons` is an `OptionSet` (UInt8); left=1, right=2, middle=4 (matching BC-003 in the protocol).
- Higher button bits (3+) in `pressedMouseButtons` are ignored.
- The wheel value is bounded to {-1, 0, +1} — multi-click scroll magnitude is not preserved.

## Edge Cases

| EC-ID  | Scenario                               | Expected Outcome                         |
|--------|----------------------------------------|------------------------------------------|
| EC-078 | No buttons pressed (raw=0)             | buttons = []                             |
| EC-079 | Left+right pressed (raw=0b011)         | buttons = [.left, .right]               |
| EC-080 | scrollingDeltaY = 3.5 (scroll up)      | wheel = 1                               |
| EC-081 | scrollingDeltaY = -0.001 (tiny scroll) | wheel = -1                              |
| EC-082 | scrollingDeltaY = 0.0                  | wheel = 0                               |
| EC-083 | Bit 3 set in pressedMouseButtons       | Ignored (not mapped to any MouseButton) |

## Canonical Test Vectors

| raw bitmask | scrollingDeltaY | Expected buttons        | Expected wheel | Category  |
|-------------|-----------------|-------------------------|----------------|-----------|
| 0b001       | 0               | [.left]                 | 0              | happy-path (BC-121 reference) |
| 0b011       | 0               | [.left, .right]         | 0              | happy-path |
| 0b000       | 5.0             | []                      | 1              | happy-path (scroll up) |
| 0b000       | -2.0            | []                      | -1             | happy-path (scroll down) |
| 0b111       | 0               | [.left, .right, .middle]| 0              | edge (all buttons) |

## Error Handling

Not applicable. `pressedMouseButtons` is a system call that always succeeds. The `Int16` wheel value cannot overflow given the {-1,0,+1} constraint.

## Traceability

| Field                           | Value |
|---------------------------------|-------|
| Source file:line                | Sources/occ/VideoView.swift:276-279 (scroll), :283-287 (buttons) |
| Ingest BC                       | BC-121 (opencrashcart-pass-3-deep-app-layer.md:29) |
| Stories                         | by story-writer |
| L2 Invariants                   | (none) |
| Capability Anchor Justification | CAP-TBD — mouse button + wheel encoding; capability file not yet produced |

## Source Evidence

| Field            | Value |
|------------------|-------|
| Path             | Sources/occ/VideoView.swift:276-287 |
| Confidence       | MEDIUM (code-only; no app-layer tests) |
| Extraction Date  | 2026-06-25 |
| Evidence Type    | Source code analysis |
