---
document_type: behavioral-contract
level: L3
id: BC-1.05.001
title: VSP keyEvent Wire Framing
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/OCCKit/Adapters/StarTech/VSProtocol.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.001: VSP keyEvent Wire Framing

## Description

`VSPack.keyEvent` serialises a `HIDKeyEvent` into the StarTech VSP wire format for the `k` (0x6B) command. The resulting 5-byte packet encodes the command byte, HID usage, modifier mask, down flag, and allReleased flag in that order, matching the original `vsproto.py` `>4B` struct packing.

## Preconditions

1. A valid `HIDKeyEvent` is provided with fields: `usage: UInt8`, `modifiers: UInt8`, `isDown: Bool`, `allReleased: Bool`.
2. The caller has already resolved a HID usage via `HIDKeymap.hidUsage(forMacKeyCode:)` and confirmed it is non-nil.

## Postconditions

1. The returned `[UInt8]` has exactly 5 bytes.
2. `result[0] == 0x6B` (ASCII `k`, `VSProtocol.Command.keyEvent.rawValue`).
3. `result[1] == event.usage`.
4. `result[2] == event.modifiers`.
5. `result[3] == 1` if `event.isDown`, else `0`.
6. `result[4] == 1` if `event.allReleased`, else `0`.

## Invariants

1. The byte order is fixed big-endian struct packing; no platform endianness affects the output.
2. The modifier byte in the VSP packet is an independent field from the HID modifier usage byte; the caller sets both appropriately.

## Edge Cases

### EC-001: allReleased with isDown=true
A synthetic allReleased=true event combined with isDown=true is a legal packet (used by chord sequences). `result[3]=1, result[4]=1`.

### EC-002: Zero modifier and zero usage
A null key event (`usage=0, modifiers=0, isDown=false, allReleased=false`) produces `[0x6B, 0x00, 0x00, 0x00, 0x00]`. The device must handle this gracefully.

### EC-003: High usage values (modifier range 0xE0–0xE7)
Modifier key events forwarded as regular key events; the modifier byte in field `result[2]` remains 0 because the adapter tracks modifier state separately.

## Canonical Test Vectors

| Input | Expected Output | Notes |
|-------|----------------|-------|
| `usage=0x04, modifiers=0x00, isDown=true, allReleased=false` | `[0x6B, 0x04, 0x00, 0x01, 0x00]` | 'a' key down — test-pinned (ProtocolTests.swift:6-7) |
| `usage=0x04, modifiers=0x00, isDown=false, allReleased=true` | `[0x6B, 0x04, 0x00, 0x00, 0x01]` | 'a' key up, last key released |
| `usage=0xE1, modifiers=0x00, isDown=true, allReleased=false` | `[0x6B, 0xE1, 0x00, 0x01, 0x00]` | Left Shift modifier key down |

## Error Handling

This is a pure serialisation function with no failure mode; it always returns a 5-byte array. Invalid inputs (e.g. wrong struct layout) result in a malformed but well-typed packet — detection is the responsibility of the device firmware.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:82-85` |
| Test file:line | `Sources/occ-tests/ProtocolTests.swift:6-7` |
| Ingest BC | BC-001 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05; flag for product-owner assignment |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:82-85` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
