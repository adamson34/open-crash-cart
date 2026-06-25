---
document_type: behavioral-contract
level: L3
id: BC-1.05.020
title: VideoView releaseAllKeys on Focus Loss and resignFirstResponder
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/occ/VideoView.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.020: VideoView releaseAllKeys on Focus Loss and resignFirstResponder

## Description

When `VideoView` loses keyboard focus, it releases every key that the target machine believes is held down, preventing stuck keys that could lock out a live machine. `releaseAllKeys()` iterates over a snapshot of `keysDown`, sends a key-up event for each with `allReleased=true`, then clears `keysDown`. `resignFirstResponder()` calls `releaseAllKeys()` before restoring the cursor from relative mode.

## Preconditions

1. `VideoView` currently has first-responder status.
2. One or more keys may be in `keysDown` (held state).

## Postconditions

**releaseAllKeys():**
1. If `keysDown.isEmpty`, returns immediately (no events sent).
2. For each `usage` in a snapshot of `keysDown`: calls `input?.sendKey(usage: usage, isDown: false, allReleased: true)`.
3. `keysDown` is cleared (`removeAll()`).
4. The `allReleased: true` flag in each call signals the adapter to flush all state (see BC-1.05.016).

**resignFirstResponder():**
1. Calls `releaseAllKeys()`.
2. If `cursorHidden` (relative mode was active): calls `CGAssociateMouseAndMouseCursorPosition(1)` and `NSCursor.unhide()`, sets `cursorHidden = false`.
3. Calls `super.resignFirstResponder()` and returns its result.

## Invariants

1. Every key in `keysDown` at focus-loss time receives exactly one key-up event with `allReleased=true`.
2. `keysDown` is empty after `releaseAllKeys()` completes.
3. The cursor is always restored on focus loss, even if no keys were held.
4. `releaseAllKeys()` is idempotent: a second call with empty `keysDown` is a no-op.

## Edge Cases

### EC-001: No keys held at focus loss
`keysDown.isEmpty` → early return; no `sendKey` calls.

### EC-002: Multiple keys held (chord)
Each held key receives its own key-up event; all have `allReleased=true`.

### EC-003: Focus loss during OCR selection
`selecting` may be `true`; `releaseAllKeys` does not check `selecting`. Keys held before selection began are released correctly.

### EC-004: Relative mode cursor restoration
`cursorHidden=true` → cursor is unconditionally un-hidden and CGAssociation restored. This is correct even if no keys were held.

### EC-005: Input delegate is nil
`input?.sendKey(...)` is a nil-safe call; events are silently dropped if the delegate is absent.

## Canonical Test Vectors

| keysDown before | Expected sendKey calls | keysDown after |
|----------------|----------------------|----------------|
| `{}` | 0 | `{}` |
| `{0x04}` | `sendKey(usage: 0x04, isDown: false, allReleased: true)` | `{}` |
| `{0x04, 0xE1}` | `sendKey(0x04, false, allReleased: true)`, `sendKey(0xE1, false, allReleased: true)` (order undefined) | `{}` |

## Error Handling

No failure mode; all operations are infallible Swift set mutations and nil-safe delegate calls.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoView.swift:223-241` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-126 (opencrashcart-pass-3-deep-app-layer.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/VideoView.swift:223-241` |
| Confidence | MEDIUM — source code, no app-layer test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
