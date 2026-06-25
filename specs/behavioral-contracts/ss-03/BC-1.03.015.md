---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: opencrashcart-pass-2-3-deep-panels-r2.md
subsystem: SS-03
capability: CAP-ADJUST
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.03.015: VideoAdjustPanel Tick-Quantized Integer-Only Sliders with Deduplication and apply() Syncs Without Emit

## Description

`VideoAdjustPanel` provides five per-adjustment sliders with discrete integer-only values enforced by `allowsTickMarkValuesOnly = true`. The `sliderChanged` handler deduplicates by comparing against `lastSent`; the `onChange` callback fires only on genuine value changes. The `apply(_:)` method synchronizes slider positions from external values without emitting `onChange` — used when the panel opens to show current device state without re-sending adjustments.

## Preconditions

- `VideoAdjustPanel` is initialized with `onChange`, `onSave`, and `onReset` closures.
- Slider configurations are set at build time.

## Postconditions

**Slider moved**:
- `sliderChanged(_:)` reads `sender.integerValue` (tick-quantized integer).
- `valueLabels[spec.adjustment]?.stringValue` is updated to the integer string.
- If `lastSent[spec.adjustment] == v`: `onChange` is NOT called (deduplicated).
- If `lastSent[spec.adjustment] != v`: `lastSent[spec.adjustment] = v`, then `onChange(spec.adjustment, v)` is called.

**`apply(_:)` called** (e.g., on panel open):
- `sliders[adj]?.integerValue = v` for each entry.
- `valueLabels[adj]?.stringValue = "\(v)"` for each entry.
- `lastSent[adj] = v` for each entry.
- `onChange` is NOT called.

**Save tapped**: `onSave()` called.

**Reset tapped**: `onReset()` called.

## Invariants

Slider ranges:
- sharpness: 0–15 (16 ticks)
- phase: 0–31 (32 ticks)
- horizontal: -30–30 (61 ticks)
- vertical: -30–30 (61 ticks)
- noise: 0–15 (16 ticks)

- All slider values are integer-only (`allowsTickMarkValuesOnly = true`).
- `numberOfTickMarks = Int(spec.max - spec.min) + 1` for each slider.
- `onChange` fires only when the value genuinely changes from `lastSent`.
- `apply` never triggers `onChange`.

## Edge Cases

- **EC-001** — User drags and releases slider to the same tick: `lastSent` matches; `onChange` not called. No duplicate device command sent.
- **EC-002** — `apply` called with a value outside slider range: `NSSlider.integerValue` clamps to min/max; `lastSent` stores the clamped value.
- **EC-003** — Panel opened before any `apply`: all sliders initialize at `value: 0`; `lastSent` is empty; first user drag sends the value regardless of whether it is 0.
- **EC-004** — `apply` called while user is mid-drag: slider jumps to applied value; `lastSent` updated; user must re-drag to send a new value.

## Canonical Test Vectors

| Scenario | Action | lastSent before | Expected onChange call? |
|----------|--------|----------------|------------------------|
| New value | Drag sharpness to 5 | {} | Yes, (sharpness, 5) |
| Same value | Drag sharpness to 5 again | {sharpness: 5} | No |
| apply | apply({sharpness: 8}) | any | No onChange; slider=8, lastSent=8 |
| Save tapped | — | — | onSave() called |

## Error Handling

No error conditions. `allowsTickMarkValuesOnly` enforces valid integer values at the slider level.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ/VideoAdjustPanel.swift:13-19, 64-71, 109-115` |
| Ingest BC | BC-208 (pass-2-3-deep-panels-r2.md) |
| Stories | TBD |
| L2 Invariants | N/A (UI-layer contract) |
| Capability Anchor Justification | CAP-ADJUST ("Tune analog video parameters (sharpness, phase, horizontal, vertical, noise) via per-adjustment sliders") per capabilities.md §CAP-ADJUST |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/occ/VideoAdjustPanel.swift` |
| Confidence | HIGH |
| Extraction Date | 2026-06-25 |
| Evidence Type | Direct source read |
| Key lines | `:13-19` Spec array with ranges; `:67-68` `numberOfTickMarks`, `allowsTickMarkValuesOnly = true`; `:109-115` `apply()` sets slider + label + lastSent, no onChange; `:117-124` `sliderChanged` deduplication `guard lastSent[spec.adjustment] != v else { return }` |
