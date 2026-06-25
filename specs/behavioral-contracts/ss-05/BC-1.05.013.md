---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/UVC/CH9329.swift"
subsystem: "SS-05"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.05.013: CH9329 Relative Mouse Signed Byte Encoding

## Description

`CH9329.mouseRelative` sends a relative mouse movement report via CMD 0x05. The dx, dy, and wheel values are signed `Int8` values that have been clamped from the caller's `Int` inputs. They are transmitted as their unsigned `UInt8` bit-pattern representation (two's-complement encoding).

## Preconditions

1. `dx`, `dy`, `wheel` are `Int8` values (already clamped by the caller; see BC-1.05.016).
2. `buttons` is a `UInt8` button bitmask.

## Postconditions

1. The data payload is `[0x01, buttons, dx_bits, dy_bits, wheel_bits]` (5 bytes, report ID 0x01).
2. `dx_bits = UInt8(bitPattern: dx)` — signed two's-complement, e.g. `dx=-1 → 0xFF`.
3. `dy_bits = UInt8(bitPattern: dy)`.
4. `wheel_bits = UInt8(bitPattern: wheel)`.
5. The frame is sent via CMD 0x05.

## Invariants

1. The report ID is always `0x01` in the first data byte.
2. Values are clamped to `[-128, 127]` before this function is called; no saturation occurs here.
3. No scaling is applied; raw delta values are sent directly.

## Edge Cases

### EC-001: Maximum positive delta
`dx=127` → `dx_bits = 0x7F`.

### EC-002: Maximum negative delta
`dx=-128` → `dx_bits = 0x80`.

### EC-003: Neutral (no movement)
`dx=0, dy=0, wheel=0` → data `[0x01, buttons, 0x00, 0x00, 0x00]`.

### EC-004: Wheel scroll down
`wheel=-1` → `wheel_bits = 0xFF` (most devices interpret 0xFF as scroll down).

## Canonical Test Vectors

| dx | dy | wheel | buttons | Expected data bytes |
|----|-----|-------|---------|-------------------|
| 0 | 0 | 0 | 0x00 | `[0x01, 0x00, 0x00, 0x00, 0x00]` |
| 10 | -5 | 0 | 0x01 | `[0x01, 0x01, 0x0A, 0xFB, 0x00]` |
| -128 | 127 | -1 | 0x00 | `[0x01, 0x00, 0x80, 0x7F, 0xFF]` |

## Error Handling

No failure mode. Callers must pass pre-clamped `Int8` values; passing `Int` without clamping is a caller error handled at the call site (UVCAdapter.drainMouse uses `Int8(clamping:)`).

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/CH9329.swift:41-46` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-043 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/CH9329.swift:41-46` |
| Confidence | MEDIUM — source code, no direct unit test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
