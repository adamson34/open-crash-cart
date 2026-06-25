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

# BC-1.05.007: Command Key Suppression and Right-Command Omission

## Description

The macOS Left Command key (kVK_Command, 0x37) is explicitly absent from the HID keymap and returns `nil`. This prevents macOS system shortcuts (screenshot, Cmd-Tab, Spotlight) from being forwarded to the target machine. The Right Command key (kVK_RightCommand, 0x36) is also unmapped but via comment-only omission rather than an explicit test assertion.

## Preconditions

1. `HIDKeymap.hidUsage(forMacKeyCode:)` is called with key code `0x37` or `0x36`.

## Postconditions

1. `HIDKeymap.hidUsage(forMacKeyCode: 0x37)` returns `nil`. (HIGH confidence — test-pinned.)
2. `HIDKeymap.hidUsage(forMacKeyCode: 0x36)` returns `nil`. (MEDIUM confidence — comment-only at HIDKeymap.swift:50-53, no test assertion.)
3. Neither key code maps to HID usage 0xE3 (Left GUI) or 0xE7 (Right GUI).

## Invariants

1. No macOS Command key variant ever maps to a HID usage in this table.
2. The GUI key can only reach the target via an explicit chord action (e.g. the "Send Windows key" UI button), not through normal keyboard input forwarding.

## Edge Cases

### EC-001: 0x36 confidence gap
The Right Command suppression is comment-only (HIDKeymap.swift:50-53). If a future refactor adds a table entry for 0x36, the Mac's Right-Cmd key would forward a GUI keypress to the target. A regression test for `0x36 → nil` should be added.

### EC-002: VideoView Command-held guard (related)
Even if this keymap gap were plugged, `VideoView.keyDown` suppresses all key events while `event.modifierFlags.contains(.command)` (VideoView.swift:197), providing a second layer of defense. See BC-1.05.012 (Command-Modified Press Suppression).

## Canonical Test Vectors

| Input | Expected | Confidence | Notes |
|-------|----------|-----------|-------|
| `0x37` (Left Command) | `nil` | HIGH | Test-pinned (KeymapTests.swift:10) |
| `0x36` (Right Command) | `nil` | MEDIUM | Comment-only at HIDKeymap.swift:50-53; no test assertion |

## Error Handling

Returns `nil`; no side effects.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Input/HIDKeymap.swift:49-56` (comment block + table omission) |
| Test file:line | `Sources/occ-tests/KeymapTests.swift:10` (0x37 only) |
| Ingest BC | BC-031 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Input/HIDKeymap.swift:49-56` |
| Confidence | HIGH for 0x37; MEDIUM for 0x36 |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test (0x37) + source comment (0x36) |
