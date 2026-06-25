---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-04"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.04.018: MISC Video Adjustment — Encode, Clamp [-128..255], Save, and Reset

## Description

Video adjustments (phase, horizontal position, vertical position, noise, sharpness) are sent to the device as MISC wire commands. `setVideoAdjustment(_:value:)` maps a `VideoAdjustment` case to a MISC protocol index, clamps the value to `[-128, 255]`, encodes negative values as two's-complement unsigned bytes, and enqueues the `setMisc` command. `saveVideoAdjustment(_:)` enqueues `saveMisc` (persists to device NVRAM). `resetVideoAdjustment(_:)` enqueues `defaultMisc` (restores device factory default for that adjustment).

## Preconditions

- `StarTechAdapter` is connected.
- `a` is a valid `VideoAdjustment` case (all 5 cases have MISC indices).
- `value` is any `Int` (clamping is applied internally).

## Postconditions

**`setVideoAdjustment(_:value:)`:**
- `miscIndex` mapping: phase→0, horizontal→1, vertical→2, noise→3, sharpness→4.
- `clamped = max(-128, min(255, value))`.
- `byte = UInt8(clamped < 0 ? 256 + clamped : clamped)` — negative values become their unsigned two's-complement equivalent (e.g. -1 → 255, -128 → 128).
- Enqueues `[setMisc.rawValue, idx, byte]` at control priority.

**`saveVideoAdjustment(_:)`:**
- Enqueues `[saveMisc.rawValue, idx]` at control priority.

**`resetVideoAdjustment(_:)`:**
- Enqueues `[defaultMisc.rawValue, idx]` at control priority.

## Invariants

- All 5 `VideoAdjustment` cases have a defined MISC index (0..4); `miscIndex` never returns `nil` for valid cases.
- Clamping is applied before byte encoding; values outside `[-128, 255]` are silently clamped.
- The encode formula `256 + clamped` produces the correct unsigned byte for the range `[-128, -1]`.
- `save` and `reset` commands do not re-encode a value — they reference only the index.

## Edge Cases

- EC-001 `value = 0` → `byte = 0`.
- EC-002 `value = 127` → `byte = 127`.
- EC-003 `value = -1` → `clamped = -1` → `byte = 255`.
- EC-004 `value = -128` → `clamped = -128` → `byte = 128`.
- EC-005 `value = 256` → `clamped = 255` → `byte = 255`.
- EC-006 `value = -129` → `clamped = -128` → `byte = 128` (clamped, not wrapped).
- EC-007 `value = 1000` → `clamped = 255` → `byte = 255`.
- EC-008 `resetVideoAdjustment(.phase)` → enqueues `[defaultMisc.rawValue, 0]` (index 0 only, no value byte).

## Canonical Test Vectors

| VideoAdjustment | value | clamped | byte |
|---|---|---|---|
| `.phase` | `0` | `0` | `0x00` |
| `.horizontal` | `-1` | `-1` | `0xFF` |
| `.vertical` | `-128` | `-128` | `0x80` |
| `.noise` | `255` | `255` | `0xFF` |
| `.sharpness` | `256` | `255` | `0xFF` |
| `.phase` | `-129` | `-128` | `0x80` |

## Error Handling

No errors. If `miscIndex` returns `nil` (only possible for a future unimplemented case), the function returns early without enqueuing. Currently all 5 cases are handled, so this guard is always satisfied.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:93-119` |
| Ingest BC | BC-085 (pass-3-behavioral-contracts.md) |
| L2 Invariants | DI-TBD (video adjustment encode correctness) |
| Capability Anchor Justification | CAP-TBD ("Video display control and DDC preset management") |

## Related BCs

- BC-1.04.017 — sibling: DDC commands also fire-and-forget, same command queue

## Architecture Anchors

- `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:93-119`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:93-119` |
| Confidence | HIGH (direct code read, unambiguous clamp/encode arithmetic) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
