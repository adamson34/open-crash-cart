---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/VSProtocol.swift"
subsystem: "SS-05"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.05.003: VSP Mouse Button Bitmask Encoding

## Description

The `MouseButtons` option set encodes pressed mouse buttons as a bitmask in the VSP wire packet. Right and middle pressed together produce the raw value `0x06`. The bitmask encoding follows the USB HID boot protocol convention adapted for the VSP protocol.

## Preconditions

1. A `MouseButtons` option set is provided with zero or more members from `{.left, .right, .middle}`.

## Postconditions

1. `MouseButtons([.right, .middle]).rawValue == 0x06`.
2. The raw value is placed directly in byte position `result[2]` of the `mouseEvent` packet.
3. Left button alone produces `rawValue == 0x01`.
4. Right button alone produces `rawValue == 0x02` (inferred from bitmask semantics and test `right|middle=6`).
5. Middle button alone produces `rawValue == 0x04` (inferred).
6. No buttons produces `rawValue == 0x00`.

## Invariants

1. The button bitmask is a plain `UInt8`; no masking or transformation is applied beyond the option set's `rawValue`.

## Edge Cases

### EC-001: All three buttons simultaneously
`[.left, .right, .middle]` → `rawValue == 0x07`. Legal combination for test harnesses.

### EC-002: Empty set
`[]` → `rawValue == 0x00` (no buttons pressed; used for mouse-move events).

### EC-003: Right + middle (test-pinned)
`[.right, .middle]` → `rawValue == 0x06` — the explicit test vector confirms bit positions.

## Canonical Test Vectors

| Input | Expected rawValue | Notes |
|-------|------------------|-------|
| `[.right, .middle]` | `0x06` | Test-pinned: right=0x02, middle=0x04 (ProtocolTests.swift:13-15) |
| `[.left]` | `0x01` | Left button only |
| `[]` | `0x00` | No buttons, move-only event |

## Error Handling

The `MouseButtons` option set type prevents invalid bitmask values at compile time.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:89-91` |
| Test file:line | `Sources/occ-tests/ProtocolTests.swift:13-15` |
| Ingest BC | BC-003 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:89-91` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
