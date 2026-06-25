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

# BC-1.05.005: VSP USB Bulk Endpoint Address Map

## Description

`VSProtocol.Endpoint` defines the USB bulk endpoint addresses for the StarTech interface 0. Three endpoints are referenced in tests: `videoIn` (0x82) for the inbound video frame stream, `streamOut` (0x04) for outbound host-to-device commands, and `dataIn` (0x85) for virtual-disk data reads.

## Preconditions

1. The StarTech USB device is claimed on interface 0 (`VSProtocol.interfaceNumber == 0`).

## Postconditions

1. `VSProtocol.Endpoint.videoIn == 0x82`.
2. `VSProtocol.Endpoint.streamOut == 0x04`.
3. `VSProtocol.Endpoint.dataIn == 0x85`.
4. `VSProtocol.Endpoint.streamIn == 0x83` (inbound command responses; not test-pinned but present in source).
5. `VSProtocol.Endpoint.dataOut == 0x05` (virtual-disk writes; not test-pinned but present in source).

## Invariants

1. Endpoint constants are compile-time `public static let` values; they cannot vary at runtime.
2. Addresses with high-bit set (0x8x) are bulk IN endpoints; addresses without (0x0x) are bulk OUT endpoints, consistent with USB spec direction encoding.

## Edge Cases

### EC-001: streamIn vs streamOut naming
`streamIn` (0x83) and `streamOut` (0x04) are distinct endpoints with opposite directions; confusion causes silent packet loss. Callers must use the named constant, not a literal.

### EC-002: dataIn vs dataOut
`dataIn` (0x85) is used for reading virtual-disk blocks back; `dataOut` (0x05) is for writes. Swapping them stalls the bulk transfer.

## Canonical Test Vectors

| Constant | Expected Value | Notes |
|----------|---------------|-------|
| `VSProtocol.Endpoint.videoIn` | `0x82` | Test-pinned (ProtocolTests.swift:20) |
| `VSProtocol.Endpoint.streamOut` | `0x04` | Test-pinned (ProtocolTests.swift:21) |
| `VSProtocol.Endpoint.dataIn` | `0x85` | Test-pinned (ProtocolTests.swift:22) |

## Error Handling

Constants; no runtime error possible. If a device enumerates with different endpoint addresses the USB transfer will fail with `deviceNotFound` or `transferFailed` at the transport layer (see BC for USB transport error mapping).

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:10-16` |
| Test file:line | `Sources/occ-tests/ProtocolTests.swift:20-22` |
| Ingest BC | BC-005 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:10-16` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
