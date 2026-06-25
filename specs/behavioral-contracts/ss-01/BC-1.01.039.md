---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ/AppController.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.039: On-Screen Chord Key Ordering — Down, Key, Up, Reversed Mods

## Description
`sendChord(modifiers:usage:)` sends a complete keyboard chord: modifiers are pressed down in forward order, then the key is pressed down, then the key is released, then modifiers are released in reverse order. `allReleased=true` is set only on the last event (final modifier release). If `modifiers` is empty, `allReleased=true` is set on the key-up event.

## Preconditions
1. `sendChord` is called from `KeyboardPanel` callback with a list of modifier usage codes and a key usage code.
2. `adapter` is non-nil (caller guards).

## Postconditions
1. For each `m` in `modifiers` (forward order): `send(key: HIDKeyEvent(usage: m, isDown: true, allReleased: false))`.
2. `send(key: HIDKeyEvent(usage: usage, isDown: true, allReleased: false))`.
3. `send(key: HIDKeyEvent(usage: usage, isDown: false, allReleased: modifiers.isEmpty))`.
4. Let `mods = Array(modifiers.reversed())`:
   - For each `(i, m)` in `mods.enumerated()`:
     - `send(key: HIDKeyEvent(usage: m, isDown: false, allReleased: i == mods.count - 1))`.

## Invariants
1. Exactly `2 * modifiers.count + 2` key events are sent per chord.
2. `allReleased` is `true` on exactly one event: the last modifier up (or key-up if no modifiers).
3. Modifier up order is the exact reverse of modifier down order.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `modifiers = []`, usage = 0x04 ('a') | 2 events: key-down(allReleased=false), key-up(allReleased=true) |
| EC-002 | `modifiers = [0xE0]`, usage = 0x04 | 4 events: LCtrl-down, a-down, a-up, LCtrl-up(allReleased=true) |
| EC-003 | `modifiers = [0xE0, 0xE2]` (Ctrl+Alt), usage = 0x4C (Del) | 6 events: LCtrl-down, LAlt-down, Del-down, Del-up, LAlt-up, LCtrl-up(allReleased=true) |
| EC-004 | `adapter == nil` | Guard `guard let a = adapter` exits without sending |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `modifiers=[0xE0], usage=0x04` | LCtrl-dn, a-dn, a-up, LCtrl-up(allReleased) | happy-path |
| `modifiers=[], usage=0x29` (Esc) | Esc-dn, Esc-up(allReleased) | edge case (no modifiers) |
| `adapter=nil` | No events sent | edge case |

## Error Handling
`guard let a = adapter else { return }` at entry; no exceptions.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:579-590 |
| Ingest BC | BC-117 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | assertion |
