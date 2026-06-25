---
document_type: behavioral-contract
level: L3
id: BC-1.05.004
title: VSP Bare Command Packing
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/OCCKit/Adapters/StarTech/VSProtocol.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.004: VSP Bare Command Packing

## Description

`VSPack.command` serialises a `VSProtocol.Command` value into a single-byte payload — the command's raw ASCII byte with no additional data. This is used for stateless commands such as `getStatus` (0x73 / `s`) and `startVStream` (0x67 / `g`).

## Preconditions

1. A valid `VSProtocol.Command` enum value is provided.

## Postconditions

1. The returned `[UInt8]` has exactly 1 byte.
2. `result[0] == command.rawValue`.

## Invariants

1. No framing, length, or checksum is added; the single byte is the complete packet for bare commands.
2. Every member of `VSProtocol.Command` has a unique `rawValue` in the ASCII printable range.

## Edge Cases

### EC-001: getStatus
`VSPack.command(.getStatus)` → `[0x73]`. Test-pinned.

### EC-002: startVStream
`VSPack.command(.startVStream)` → `[0x67]`. Test-pinned.

### EC-003: All other commands
Any `VSProtocol.Command` member returns a 1-element array with that member's raw byte. No validation or transformation occurs.

## Canonical Test Vectors

| Input | Expected Output | Notes |
|-------|----------------|-------|
| `.getStatus` | `[0x73]` | ASCII 's' — test-pinned (ProtocolTests.swift:17) |
| `.startVStream` | `[0x67]` | ASCII 'g' — test-pinned (ProtocolTests.swift:18) |

## Error Handling

No failure mode; all `Command` members have statically-known raw values.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:96` |
| Test file:line | `Sources/occ-tests/ProtocolTests.swift:17-18` |
| Ingest BC | BC-004 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/VSProtocol.swift:96` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
