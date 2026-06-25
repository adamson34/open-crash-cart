---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ/VideoView.swift"
subsystem: "SS-05"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.05.019: VideoView flagsChanged isModifier Guard Prevents Stray A Keystroke

## Description

`VideoView.flagsChanged` handles macOS modifier-key transition events. It guards against a known macOS edge case where `flagsChanged` fires with `keyCode=0` when the focus-steal overlay appears (e.g. screenshot). `keyCode=0` maps to the 'a' key (HID 0x04), which is NOT a modifier. The `isModifier(usage)` check ensures this spurious event is silently dropped rather than injecting a stray 'A' keystroke on the target.

## Preconditions

1. `VideoView` is the first responder.
2. A `flagsChanged` event arrives from the macOS event system.

## Postconditions

1. `HIDKeymap.hidUsage(forMacKeyCode: event.keyCode)` is evaluated.
2. `HIDKeymap.isModifier(usage)` is evaluated on the result.
3. If either returns `nil` or `false`, the event is silently dropped; nothing is sent to `input`.
4. If both succeed (usage is a true modifier), the toggle logic runs: if `usage` is in `keysDown` it is a release; otherwise it is a press.
5. `keysDown` is updated and `input?.sendKey(...)` is called.

## Invariants

1. Only the 8 HID modifier usages (0xE0–0xE7) can pass the `isModifier` guard.
2. `keyCode=0` maps to HID usage `0x04` ('a'), which is NOT in the modifier range → always dropped.
3. The toggle approach (first event = press, second = release) is required because `flagsChanged` does not include an `isDown` state; it fires on both transitions.

## Edge Cases

### EC-001: keyCode=0 (stray A during focus-steal)
`hidUsage(forMacKeyCode: 0x00) = 0x04`; `isModifier(0x04) = false` → event dropped. No 'A' keystroke forwarded.

### EC-002: Left Shift pressed (normal modifier)
`hidUsage(forMacKeyCode: 0x38) = 0xE1`; `isModifier(0xE1) = true` → usage not in `keysDown` → isDown=true → insert 0xE1 → `sendKey(usage: 0xE1, isDown: true, ...)`.

### EC-003: Left Shift released
Second `flagsChanged` for same key: `0xE1` is now in `keysDown` → isDown=false → remove 0xE1 → `sendKey(usage: 0xE1, isDown: false, allReleased: keysDown.isEmpty)`.

### EC-004: Unknown key code in flagsChanged
`hidUsage` returns `nil` → dropped (first guard clause).

## Canonical Test Vectors

| keyCode | hidUsage | isModifier | Action |
|---------|----------|-----------|--------|
| `0x00` | `0x04` | false | dropped — stray 'A' suppressed |
| `0x38` | `0xE1` | true | press/release toggled |
| `0x3B` | `0xE0` | true | press/release toggled (Left Ctrl) |
| `0xFFFF` | nil | — | dropped (nil usage) |

## Error Handling

No failure mode; both guard clauses produce silent drops.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoView.swift:210-219` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-128 (opencrashcart-pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/VideoView.swift:210-219` |
| Confidence | MEDIUM — source code, no app-layer test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
