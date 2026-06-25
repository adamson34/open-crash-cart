---
document_type: behavioral-contract
level: L3
id: BC-1.05.002
title: VSP mouseEvent Absolute Big-Endian Framing
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/OCCKit/Adapters/StarTech/VSProtocol.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.002: VSP mouseEvent Absolute Big-Endian Framing

## Description

`VSPack.mouseEvent` serialises a `MouseEvent` into the StarTech VSP wire format for the `m` (0x6D) command. The 9-byte packet encodes the command byte, absolute-mode flag, button bitmask, and three signed 16-bit values (x, y, wheel) in big-endian byte order, matching the original `vsproto.py` `>BB3h` struct packing.

## Preconditions

1. A valid `MouseEvent` is provided with fields: `buttons: MouseButtons`, `x: Int16`, `y: Int16`, `wheel: Int16`, `isAbsolute: Bool`.

## Postconditions

1. The returned `[UInt8]` has exactly 9 bytes.
2. `result[0] == 0x6D` (ASCII `m`, `VSProtocol.Command.mouseEvent.rawValue`).
3. `result[1] == 1` if `event.isAbsolute`, else `0`.
4. `result[2] == event.buttons.rawValue`.
5. `result[3..4]` = big-endian encoding of `event.x` as Int16.
6. `result[5..6]` = big-endian encoding of `event.y` as Int16.
7. `result[7..8]` = big-endian encoding of `event.wheel` as Int16.
8. Negative values are two's-complement encoded: `x = -5` encodes as `[0xFF, 0xFB]`.

## Invariants

1. All three coordinate fields are encoded as signed big-endian Int16 regardless of absolute/relative mode.
2. The absolute/relative mode flag is always present in byte position 1.

## Edge Cases

### EC-001: Negative x coordinate
`x = -5` encodes as bytes `[0xFF, 0xFB]` in positions `result[3..4]` (two's-complement big-endian). Test-pinned.

### EC-002: Absolute mode with positive coordinates
`x=10, y=0, isAbsolute=true` → `result[1]=0x01, result[3..4]=[0x00, 0x0A]`.

### EC-003: Zero wheel, relative mode
`wheel=0, isAbsolute=false` → `result[1]=0x00, result[7..8]=[0x00, 0x00]`.

### EC-004: Maximum positive Int16 (x=32767)
Encodes as `[0x7F, 0xFF]` — no overflow.

## Canonical Test Vectors

| Input | Expected Output | Notes |
|-------|----------------|-------|
| `buttons=[.left], x=10, y=-5, wheel=1, isAbsolute=true` | `[0x6D, 0x01, 0x01, 0x00, 0x0A, 0xFF, 0xFB, 0x00, 0x01]` | Test-pinned (ProtocolTests.swift:9-11): left button, abs, x=10, y=-5 |
| `buttons=[.right,.middle], x=0, y=0, wheel=0, isAbsolute=false` | `[0x6D, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]` | Relative mode, buttons bitmask=6 (ProtocolTests.swift:13-15) |

## Error Handling

Pure serialisation; no failure mode. Out-of-range `Int16` values are handled by Swift's type system at the call site.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:88-92` |
| Test file:line | `Sources/occ-tests/ProtocolTests.swift:9-11` |
| Ingest BC | BC-002 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:88-92` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
