---
document_type: behavioral-contract
level: L3
id: BC-1.05.008
title: HID Modifier Usage Range Detection
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/OCCKit/Input/HIDKeymap.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.008: HID Modifier Usage Range Detection

## Description

`HIDKeymap.isModifier(_:)` identifies whether a HID usage ID belongs to the USB HID modifier key range 0xE0–0xE7 (Left Control through Right GUI). This check guards modifier-key events in `VideoView.flagsChanged` to prevent spurious key injection from macOS focus-steal events.

## Preconditions

1. A `UInt8` HID usage ID is provided.

## Postconditions

1. Returns `true` if and only if `usage` is in the closed range `0xE0...0xE7`.
2. `isModifier(0xE0)` == `true` (Left Control).
3. `isModifier(0xE1)` == `true` (Left Shift) — test-pinned.
4. `isModifier(0xE7)` == `true` (Right GUI) — test-pinned.
5. `isModifier(0x04)` == `false` (HID 'a') — test-pinned.
6. `isModifier(0xDF)` == `false` (one below range).
7. `isModifier(0xE8)` == `false` (one above range).

## Invariants

1. The range is exactly 8 values (0xE0–0xE7), corresponding to the 8 modifier keys in the USB HID boot protocol modifier byte.
2. The check is a closed-range containment test; boundary values 0xE0 and 0xE7 are both included.

## Edge Cases

### EC-001: Boundary values
`0xDF` returns `false`; `0xE8` returns `false`. Both are one outside the range.

### EC-002: Full modifier range
All 8 values 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7 return `true`.

### EC-003: flagsChanged guard usage
When `VideoView.flagsChanged` fires with `keyCode=0` (maps to HID usage `0x04` for 'a'), `isModifier(0x04)` returns `false`, so the event is dropped and no stray 'A' keystroke is forwarded.

## Canonical Test Vectors

| Input usage | Expected | Notes |
|-------------|----------|-------|
| `0xE1` | `true` | Left Shift — test-pinned (KeymapTests.swift:13) |
| `0xE7` | `true` | Right GUI — test-pinned (KeymapTests.swift:14) |
| `0x04` | `false` | HID 'a' — test-pinned (KeymapTests.swift:15) |
| `0xE0` | `true` | Left Control — boundary |
| `0xE8` | `false` | One above range — boundary |

## Error Handling

Pure boolean predicate; no failure mode.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Input/HIDKeymap.swift:18-20` |
| Test file:line | `Sources/occ-tests/KeymapTests.swift:13-15` |
| Ingest BC | BC-032 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Input/HIDKeymap.swift:18-20` |
| Confidence | HIGH — test-pinned |
| Extraction Date | 2026-06-25 |
| Evidence Type | Test + source code |
