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

# BC-1.05.011: CH9329 Keyboard Report Pad-to-6 Keys

## Description

`CH9329.keyboard(modifier:keys:)` sends a full 8-byte HID keyboard report to the CH9329 chip. The `keys` array is truncated to at most 6 elements and zero-padded to exactly 6 bytes before prepending the modifier byte and a reserved zero byte. This matches the USB HID boot protocol keyboard report format.

## Preconditions

1. `modifier` is a `UInt8` bit-field where bit N corresponds to modifier usage `0xE0 + N`.
2. `keys` is a `[UInt8]` array of HID usage IDs for currently-pressed non-modifier keys.

## Postconditions

1. The data payload sent is exactly 8 bytes: `[modifier, 0x00, key1, key2, key3, key4, key5, key6]`.
2. If `keys.count < 6`, the remaining positions are filled with `0x00`.
3. If `keys.count > 6`, only the first 6 elements are used (`keys.prefix(6)`).
4. The reserved byte at position 1 is always `0x00`.
5. The resulting CH9329 frame uses `cmd=0x02`.

## Invariants

1. The report always contains exactly 6 key slots; no variable-length report is sent.
2. Zero-padding is applied after truncation, so the total is always 6.
3. The modifier byte encodes the full 8-modifier set in one byte; it is not repeated in the key slots.

## Edge Cases

### EC-001: No keys pressed
`keys=[]` → data `[modifier, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]`. An all-zeros report releases all keys on the target.

### EC-002: Exactly 6 keys
`keys` of length 6 → data contains all 6 keys with no padding.

### EC-003: 7 keys (overflow — 6KRO limit)
`keys` of length 7 → only the first 6 are sent. The 7th key is silently dropped. The UVC input state tracker (BC-1.05.015) enforces `downKeys.count < 6` before appending, so this truncation is a safety net only.

### EC-004: Modifier-only event
`keys=[], modifier=0x01` (Left Ctrl held) → all key slots zero, modifier byte set. Correct for modifier-only hold.

## Canonical Test Vectors

| modifier | keys | Expected data (8 bytes) | Notes |
|----------|------|------------------------|-------|
| `0x00` | `[]` | `[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]` | All-release report |
| `0x00` | `[0x04]` | `[0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00]` | Single key 'a' |
| `0x05` | `[0x4C, 0x00, 0x00, 0x00, 0x00, 0x00]` | `[0x05, 0x00, 0x4C, 0x00, 0x00, 0x00, 0x00, 0x00]` | Ctrl+Alt+Del modifier+key |

## Error Handling

No failure mode; truncation and padding are always applied silently.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/CH9329.swift:22-26` |
| Test file:line | `Sources/occ-tests/ProtocolTests.swift:25-30` (via ch9329Frame) |
| Ingest BC | BC-041 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/CH9329.swift:22-26` |
| Confidence | MEDIUM — source code, no direct unit test for padding behaviour |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
