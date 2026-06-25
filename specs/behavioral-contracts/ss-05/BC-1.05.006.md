---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Input/HIDKeymap.swift"
subsystem: "SS-05"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.05.006: HID Keymap macOS-to-USB-HID Usage Translation

## Description

`HIDKeymap.hidUsage(forMacKeyCode:)` translates a macOS Carbon virtual key code (`kVK_*`) to a USB HID keyboard usage ID (HID Usage Tables, Keyboard/Keypad page 0x07). The mapping is a static lookup table covering ANSI letters, number row, whitespace, punctuation, function keys, navigation cluster, keypad, and modifier keys. Keys absent from the table return `nil`.

## Preconditions

1. A macOS `kVK_*` virtual key code is provided as `UInt16`.

## Postconditions

1. If `keyCode` is present in the internal table, returns `Optional(UInt8)` with the corresponding HID usage.
2. If `keyCode` is absent, returns `nil`.
3. Specific pinned mappings (test-verified):
   - `0x00` (kVK_ANSI_A) → `0x04` (HID `a`)
   - `0x24` (kVK_Return) → `0x28` (HID Enter)
   - `0x7E` (kVK_UpArrow) → `0x52` (HID Up Arrow)
   - `0x38` (kVK_Shift) → `0xE1` (HID Left Shift)
4. `0x37` (kVK_Command / Left Command) → `nil` (intentionally unmapped; see BC-1.05.007).
5. Unknown key codes → `nil`.

## Invariants

1. The table is a compile-time constant; it cannot be modified at runtime.
2. All returned usage IDs are in the HID Keyboard/Keypad page 0x07 range (0x04–0xE7); no usage IDs from other pages are present.
3. Modifier key codes (kVK_Control, kVK_Shift, kVK_Option, kVK_RightControl, kVK_RightShift, kVK_RightOption) map to modifier HID usages 0xE0–0xE7.

## Edge Cases

### EC-001: Command key (0x37)
Returns `nil`. The Command key is intentionally not mapped to prevent leaking macOS system shortcuts (screenshot, Cmd-Tab, Spotlight) to the target machine.

### EC-002: Unknown / synthetic key code (0xFFFF)
Returns `nil`. No panic or assertion occurs.

### EC-003: Right GUI (kVK_RightCommand = 0x36)
Returns `nil`. Comment-only in source at HIDKeymap.swift:50 — MEDIUM confidence that this is intentionally omitted with the same rationale as 0x37. There is no HID usage 0xE7 (Right GUI) entry in the table.

### EC-004: Keypad keys
Keypad numeric keys (kVK_Keypad0–kVK_Keypad9, kVK_KeypadDecimal, arithmetic operators) map to HID usages 0x59–0x63.

## Canonical Test Vectors

| macOS keyCode | Expected HID usage | Notes |
|--------------|-------------------|-------|
| `0x00` | `0x04` | kVK_ANSI_A → HID 'a' — test-pinned (KeymapTests.swift:6) |
| `0x24` | `0x28` | kVK_Return → HID Enter — test-pinned (KeymapTests.swift:7) |
| `0x7E` | `0x52` | kVK_UpArrow → HID Up — test-pinned (KeymapTests.swift:8) |
| `0x38` | `0xE1` | kVK_Shift → HID Left Shift — test-pinned (KeymapTests.swift:9) |
| `0x37` | `nil` | Left Command — intentionally unmapped (KeymapTests.swift:10) |
| `0xFFFF` | `nil` | Unknown key code (KeymapTests.swift:11) |

## Error Handling

Returns `nil` for unmapped keys; no exceptions thrown. The caller is responsible for handling `nil` (e.g. dropping the event).

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Input/HIDKeymap.swift:13-56` |
| Test file:line | `Sources/occ-tests/KeymapTests.swift:6-11` |
| Ingest BC | BC-030 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Input/HIDKeymap.swift:13-56` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
