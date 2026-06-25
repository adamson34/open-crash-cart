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

# BC-1.05.010: CH9329 Wire Frame Structure and Checksum

## Description

`ch9329Frame(cmd:data:)` constructs a CH9329 protocol frame with the fixed preamble `[0x57, 0xAB, 0x00]`, followed by the command byte, a length byte equal to `data.count`, the data bytes, and a checksum byte. The checksum is the sum of all preceding bytes modulo 256 (all bytes including preamble, cmd, and len).

## Preconditions

1. `cmd` is a valid CH9329 command byte (e.g. 0x02 for keyboard, 0x04 for absolute mouse, 0x05 for relative mouse).
2. `data` is a `[UInt8]` array of any length (0–255 bytes).

## Postconditions

1. The returned array length equals `5 + data.count` (3-byte preamble + cmd + len + data + checksum).
2. `result[0] == 0x57`, `result[1] == 0xAB`, `result[2] == 0x00`.
3. `result[3] == cmd`.
4. `result[4] == UInt8(data.count)`.
5. `result[5...(4+data.count)]` == `data`.
6. `result.last == (0x57 + 0xAB + 0x00 + cmd + data.count + sum(data)) & 0xFF`.
7. Empty keyboard report `cmd=0x02, data=[0,0,0,0,0,0,0,0]` → checksum `0x0C`. Test-pinned.
8. Ctrl+Alt+Del payload `cmd=0x02, data=[0x05, 0, 0x4C, 0, 0, 0, 0, 0]` → checksum `0x5D`. Test-pinned.

## Invariants

1. The preamble bytes `[0x57, 0xAB, 0x00]` are always present at positions 0–2; the address byte is always `0x00`.
2. The checksum covers the entire frame including preamble, cmd, and len — not just the data.
3. The checksum wraps silently at 256 (single-byte modular arithmetic).

## Edge Cases

### EC-001: Empty data
`ch9329Frame(cmd: 0x01, data: [])` → 5 bytes: `[0x57, 0xAB, 0x00, 0x01, 0x00, checksum]`.

### EC-002: Maximum data length (255 bytes)
`len` byte saturates at 255. Callers must not pass data arrays longer than 255 bytes.

### EC-003: Checksum overflow
The sum intentionally wraps; `& 0xFF` is applied at each step (or equivalently to the final sum).

### EC-004: Ctrl+Alt+Del breakdown
Header sum: `0x57+0xAB+0x00+0x02+0x08 = 0x10C`, mask to `0x0C`. Data `0x05+0x00+0x4C = 0x51`. Total: `0x0C+0x51 = 0x5D`. Matches test assertion.

## Canonical Test Vectors

| Input (cmd, data) | Expected last byte (checksum) | Notes |
|-------------------|------------------------------|-------|
| `0x02, [0,0,0,0,0,0,0,0]` | `0x0C` | Empty keyboard report — test-pinned (ProtocolTests.swift:25-27) |
| `0x02, [0x05, 0, 0x4C, 0, 0, 0, 0, 0]` | `0x5D` | Ctrl+Alt+Del — test-pinned (ProtocolTests.swift:29-30) |

## Error Handling

No failure mode. Data length > 255 will silently truncate the `len` byte; callers must not exceed this limit.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/CH9329.swift:51-57` |
| Test file:line | `Sources/occ-tests/ProtocolTests.swift:25-30` |
| Ingest BC | BC-040 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/CH9329.swift:51-57` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
