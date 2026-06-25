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

# BC-1.05.018: VideoView Command-Modified Press Suppression and KeyUp Forwarding

## Description

`VideoView.keyDown` suppresses all key presses made while the macOS Command modifier is held, preventing macOS system shortcuts from leaking to the target. However, `VideoView.keyUp` always forwards key releases regardless of modifier state, to prevent stuck keys on the target when the user releases a key after releasing Command.

## Preconditions

1. `VideoView` is the first responder and not in OCR selection mode.
2. A key event arrives from the macOS event system.

## Postconditions

**keyDown:**
1. If `event.modifierFlags.contains(.command)` → event is swallowed; nothing is sent to `input`.
2. If `event.isARepeat` → event is swallowed (auto-repeat is suppressed).
3. If `HIDKeymap.hidUsage(forMacKeyCode: event.keyCode)` returns `nil` → event is swallowed.
4. Otherwise: `usage` is added to `keysDown`; `input?.sendKey(usage: usage, isDown: true, allReleased: keysDown.isEmpty)` is called (note: `allReleased` is always `false` here because `usage` was just inserted).

**keyUp:**
1. If `HIDKeymap.hidUsage(forMacKeyCode: event.keyCode)` returns `nil` → event is swallowed.
2. Otherwise: `usage` is removed from `keysDown`; `input?.sendKey(usage: usage, isDown: false, allReleased: keysDown.isEmpty)` is called.
3. The Command modifier state is NOT checked for keyUp events.

## Invariants

1. Key releases are always forwarded if the key has a HID usage, regardless of which modifiers are currently held.
2. Auto-repeat (`event.isARepeat == true`) is suppressed for keyDown; no auto-repeat events reach the target.
3. `keysDown` accurately reflects the set of HID usages the target believes are pressed.

## Edge Cases

### EC-001: Command+C pressed then Command released then C released
- Cmd+C keyDown: swallowed (Command held).
- Cmd released (flagsChanged, not a keyDown): forwarded if Cmd had been tracked via keysDown.
- C keyUp: forwarded unconditionally → target receives a C-up. The C was never pressed on the target, so this is a harmless spurious release.

### EC-002: Unknown key code on keyDown
`hidUsage` returns `nil` → no insertion into `keysDown`, nothing sent.

### EC-003: Unknown key code on keyUp
`hidUsage` returns `nil` → `removeAll` is never called for an absent usage; no side effects.

### EC-004: OCR selection mode
`selecting == true` → `keyDown` returns early (Esc is intercepted first; other keys are swallowed). `keyUp` does NOT check `selecting` in the source (VideoView.swift:203-208) — a keyUp during selection is forwarded. This may leave a key stuck if the user holds a key while entering selection mode.

## Canonical Test Vectors

| Event | Modifier flags | Expected action |
|-------|---------------|----------------|
| keyDown, 'a' (0x00), no modifiers | none | `sendKey(usage: 0x04, isDown: true, ...)` |
| keyDown, 'a' (0x00), Command held | `.command` | swallowed — nothing sent |
| keyDown, isARepeat=true | any | swallowed |
| keyUp, 'a' (0x00), Command held | `.command` | `sendKey(usage: 0x04, isDown: false, ...)` — forwarded |
| keyDown, unknown keyCode (0xFFFF) | none | swallowed (nil mapping) |

## Error Handling

No failure mode; all event swallowing is silent.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoView.swift:195-208` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-127 (opencrashcart-pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/VideoView.swift:195-208` |
| Confidence | MEDIUM — source code, no app-layer test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
