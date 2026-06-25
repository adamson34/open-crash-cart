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
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.036: Ctrl-Alt-Del / Windows 0xE3 / Escape 0x29 Direct Chords

## Description
Three hardcoded special key actions are provided in the Keyboard menu and toolbar: `sendCtrlAltDel()` sends the USB HID Ctrl+Alt+Del chord; `sendKeyPress(usage: 0xE3)` sends the Left GUI (Windows) key; `sendKeyPress(usage: 0x29)` sends the Escape key. All three are no-ops if `adapter == nil`.

## Preconditions
1. The corresponding menu item or toolbar button is activated.
2. `adapter` may or may not be set.

## Postconditions
1. If `adapter == nil`: no key event is sent; no error or message.
2. If `adapter` set:
   - Ctrl-Alt-Del: `adapter.sendCtrlAltDel()` is called (implementation sends the HID chord).
   - Windows key: `adapter.sendKeyPress(usage: 0xE3)` is called.
   - Escape: `adapter.sendKeyPress(usage: 0x29)` is called.

## Invariants
1. Usage code 0xE3 is Left GUI (Windows/Command key) in HID usage tables.
2. Usage code 0x29 is Escape in HID usage tables.
3. No state change in AppController; pure key-event dispatch.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `adapter == nil` | No-op via optional chaining |
| EC-002 | Ctrl-Alt-Del sent during BIOS | Depends on firmware/target; AppController's contract is send-only |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| menuCtrlAltDel with active adapter | `adapter.sendCtrlAltDel()` called | happy-path |
| menuWindowsKey with active adapter | Key event usage=0xE3 sent | happy-path |
| menuEscape with no adapter | No-op | edge case |

## Error Handling
Optional chaining (`adapter?.`) makes all calls safe when adapter is nil.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:438-440 |
| Ingest BC | BC-114 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | type constraint / assertion |
