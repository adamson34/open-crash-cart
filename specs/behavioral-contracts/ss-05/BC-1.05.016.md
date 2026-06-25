---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/UVC/UVCAdapter.swift"
subsystem: "SS-05"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.05.016: UVC Input State Modifier Byte and 6KRO Key Tracking

## Description

`UVCAdapter.applyKey(_:)` maintains a modifier byte (`modifierByte`) and a pressed-keys list (`downKeys`) as mutable state on `inputQueue`. Modifier key usages (0xE0–0xE7) set or clear bits in `modifierByte`. Non-modifier key presses append to `downKeys` (capped at 6); key releases remove from the list. The `allReleased` flag clears both structures unconditionally.

## Preconditions

1. `hasHID == true` (gate in `send(key:)`).
2. `HIDKeyEvent` is provided with `usage`, `isDown`, `allReleased` fields.
3. `applyKey` is called on `inputQueue` (serialised access; no concurrent writes).

## Postconditions

1. **Modifier key down** (`usage` in 0xE0..0xE7, `isDown=true`): bit `1 << (usage - 0xE0)` set in `modifierByte`.
2. **Modifier key up** (`usage` in 0xE0..0xE7, `isDown=false`): same bit cleared in `modifierByte`.
3. **Regular key down** (`isDown=true`, `usage` not in modifier range): if not already in `downKeys` and `downKeys.count < 6`, append `usage`; otherwise no-op (6KRO limit).
4. **Regular key up** (`isDown=false`): remove `usage` from `downKeys` (no-op if not present).
5. **allReleased** (`allReleased=true`): `modifierByte = 0` and `downKeys.removeAll()`, regardless of `isDown`.
6. After every call, `ch9329?.keyboard(modifier: modifierByte, keys: downKeys)` is called to send the current state.

## Invariants

1. `downKeys.count` is always 0–6 (enforced by the `< 6` guard before append).
2. `modifierByte` encodes exactly the 8 modifier positions (bits 0–7 = usages 0xE0–0xE7).
3. All state access is serialised on `inputQueue`; no locking is required.
4. `allReleased` is idempotent: applying it twice from the same state yields the same result.

## Edge Cases

### EC-001: 6-key rollover limit
A 7th simultaneous key press is silently ignored; `downKeys` stays at 6 entries.

### EC-002: allReleased clears modifier byte
Even if `isDown=true` in the same event, `allReleased=true` resets both `modifierByte` and `downKeys`. This is used by chord completion events.

### EC-003: Key up for key not in downKeys
`removeAll { $0 == usage }` is a no-op when `usage` is absent. Safe.

### EC-004: Modifier key with allReleased
A modifier-key-up event with `allReleased=true` first clears the modifier bit, then clears all state. Net result: fully released.

### EC-005: Simultaneous modifier + regular key release
Each event arrives separately on `inputQueue`; order is FIFO from the caller.

## Canonical Test Vectors

| Event | Pre-state | Post-state modifierByte | Post-state downKeys |
|-------|-----------|------------------------|-------------------|
| `usage=0xE1, isDown=true` | mod=0x00, keys=[] | 0x02 (bit 1 = LShift) | [] |
| `usage=0xE1, isDown=false` | mod=0x02, keys=[] | 0x00 | [] |
| `usage=0x04, isDown=true` | mod=0x00, keys=[] | 0x00 | [0x04] |
| `usage=0x04, isDown=false` | mod=0x00, keys=[0x04] | 0x00 | [] |
| `usage=0x04, isDown=false, allReleased=true` | mod=0x02, keys=[0x04,0x05] | 0x00 | [] |
| 6 keys in downKeys, 7th key down | mod=0x00, keys=[0x04..0x09] | 0x00 | [0x04..0x09] (unchanged) |

## Error Handling

No failure mode; all operations on the state are safe Swift value mutations.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:128-139` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-035 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:128-139` |
| Confidence | MEDIUM — source code, no unit test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
