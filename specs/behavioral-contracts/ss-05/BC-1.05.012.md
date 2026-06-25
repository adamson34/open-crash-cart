---
document_type: behavioral-contract
level: L3
id: BC-1.05.012
title: CH9329 Absolute Mouse Coordinate Scaling 0..4095
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/OCCKit/Adapters/UVC/CH9329.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.012: CH9329 Absolute Mouse Coordinate Scaling 0..4095

## Description

`CH9329.mouseAbsolute` scales pixel coordinates from the capture frame's dimensions to the CH9329 absolute mouse range of 0–4095. The scaling formula is `value * 4096 / dimension`, clamped to `[0, 4095]`. The x and y values are sent as two little-endian bytes each in the CMD 0x04 data payload.

## Preconditions

1. `width` and `height` are the current video frame dimensions (positive integers).
2. `x` and `y` are pixel coordinates within the frame (may exceed bounds; clamping is applied).
3. `buttons`, `wheel` are valid button bitmask and scroll delta.

## Postconditions

1. `ax = clamp(x * 4096 / width, 0, 4095)` when `width > 0`; `ax = 0` when `width == 0`.
2. `ay = clamp(y * 4096 / height, 0, 4095)` when `height > 0`; `ay = 0` when `height == 0`.
3. The data payload is `[0x02, buttons, ax_low, ax_high, ay_low, ay_high, wheel_signed]` (report ID 0x02, coordinates little-endian).
4. The frame is sent via CMD 0x04.

## Invariants

1. The scaling formula uses integer arithmetic (`x * 4096 / width`); sub-pixel precision is truncated.
2. Zero dimension guard: width or height == 0 produces coordinate 0, preventing division by zero.
3. Coordinates are always clamped to [0, 4095] regardless of input.

## Edge Cases

### EC-001: Zero dimension (before first frame)
`width=0` or `height=0` → `ax=0, ay=0`. No panic.

### EC-002: Coordinate at exact frame boundary
`x == width - 1` → `ax = (width-1) * 4096 / width` ≈ 4095 (slightly less than 4096). Top-right pixel maps to near-max.

### EC-003: Coordinate exactly at width (pixel just outside frame)
`x == width` → `ax = 4096`, clamped to 4095.

### EC-004: Wheel negative value
`wheel = -1` → `UInt8(bitPattern: -1) = 0xFF`. Signed encoding via bitPattern cast.

### EC-005: Typical 1920x1080 frame, center pixel
`x=960, y=540, width=1920, height=1080` → `ax=960*4096/1920=2048`, `ay=540*4096/1080=2048`.

## Canonical Test Vectors

| x | y | width | height | Expected ax | Expected ay |
|---|---|-------|--------|------------|------------|
| 0 | 0 | 1920 | 1080 | 0 | 0 |
| 960 | 540 | 1920 | 1080 | 2048 | 2048 |
| 1919 | 1079 | 1920 | 1080 | 4094 | 4090 |
| 0 | 0 | 0 | 0 | 0 | 0 | zero-dimension guard |

## Error Handling

Division by zero is guarded by the `width > 0 ? ... : 0` conditional. No exception is raised.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/CH9329.swift:29-37` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-042 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/CH9329.swift:29-37` |
| Confidence | MEDIUM — source code, no direct unit test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
