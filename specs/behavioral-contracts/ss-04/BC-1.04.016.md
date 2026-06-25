---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapter/Types.swift"
subsystem: "SS-04"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.04.016: DDCPreset — 4-Case Enum with rawValue 0..3

## Description

`DDCPreset` is a Swift `enum` with `Int` rawValue conforming to `CaseIterable` and `Sendable`. It has exactly 4 cases mapping to standard display resolutions, with rawValues 0 through 3. The rawValue is used directly as the payload byte in the `setDDC` wire command. There is no persistent state for DDC presets — they are fire-and-forget device commands (DF-202).

## Preconditions

- `DDCPreset` is used at the call site of `StarTechAdapter.setDDCPreset(_:)`.
- The caller selects one of the four enumerated cases.

## Postconditions

- `DDCPreset.res1280x1024.rawValue == 0`
- `DDCPreset.res1024x768.rawValue == 1`
- `DDCPreset.res1920x1200.rawValue == 2`
- `DDCPreset.res1920x1080.rawValue == 3`
- `DDCPreset.allCases.count == 4`
- Each case has a human-readable `label` string (e.g. `"1280 × 1024"`).

## Invariants

- rawValues are contiguous 0..3; no gaps or duplicates.
- `CaseIterable` synthesis is consistent with the explicit rawValues.
- The enum does not carry persisted state; its rawValue is purely a wire-protocol index.

## Edge Cases

- EC-001 `DDCPreset(rawValue: 4)` returns `nil` (no fifth case).
- EC-002 `DDCPreset(rawValue: -1)` returns `nil`.
- EC-003 `DDCPreset.allCases` enumeration always returns all 4 cases in rawValue order.

## Canonical Test Vectors

| Case | rawValue | label |
|---|---|---|
| `.res1280x1024` | `0` | `"1280 × 1024"` |
| `.res1024x768` | `1` | `"1024 × 768"` |
| `.res1920x1200` | `2` | `"1920 × 1200"` |
| `.res1920x1080` | `3` | `"1920 × 1080"` |

## Error Handling

No errors. Enum construction from rawValue uses optional (`DDCPreset?`); out-of-range rawValue returns `nil`.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/Types.swift:122-132` |
| Ingest domain fact | DF-202 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (DDC preset wire values are stable protocol constants) |
| Capability Anchor Justification | CAP-TBD ("Video display control and DDC preset management") |

## Related BCs

- BC-1.04.017 — uses: rawValue of this enum as wire command payload

## Architecture Anchors

- `Sources/OCCKit/Adapter/Types.swift:122-132`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/Types.swift:122-132` |
| Confidence | HIGH (direct code read, enum declaration) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
