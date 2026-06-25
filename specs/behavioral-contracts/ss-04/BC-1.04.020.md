---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.020
title: "Single Source of Truth for Device Matching — AdapterRegistry and StarTechAdapter Derive from Built-In HardwareProfile (v1.1.0)"
origin: brownfield
subsystem: SS-04
capability: CAP-TBD
introduced: v1.1.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/AdapterRegistry.swift
  - Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift
  - Sources/OCCKit/Adapter/ProfileStore.swift
ingest_bc: BC-073
---

# BC-1.04.020: Single Source of Truth for Device Matching — AdapterRegistry and StarTechAdapter Derive from Built-In HardwareProfile (v1.1.0)

## Description

**v1.1.0 change.** In v1.0.0, the StarTech VID (`0x152A`) and PIDs (`[0x8460, 0x8463]`) are hardcoded in three independent locations: `AdapterRegistry.known` (AdapterRegistry.swift:19-25), `ProfileStore.builtIns` (ProfileStore.swift:21-28), and `StarTechAdapter.model` (StarTechAdapter.swift:11-16). This constitutes a defect (P1.4) — any change to the adapter's supported PIDs requires three separate, manually-synchronised edits, which creates divergence risk.

In v1.1.0, `AdapterRegistry.known` and `StarTechAdapter.model` are refactored to derive their VID/PID data from the corresponding entry in `ProfileStore.builtIns`, making `ProfileStore.builtIns` the single source of truth.

**Source-of-truth fields (adversary M2):** the *declared* constants live on the built-in profile as the string fields `vendorId: String` and `productIds: [String]` (HardwareProfile.swift:10-11) — these are what an editor changes. `vid: UInt16` and `pids: [UInt16]` are read-only *computed* accessors (HardwareProfile.swift:29-30); `AdapterModel` consumers read those computed values. A device-detection mismatch due to the triple-hardcode is a regression in matching correctness.

## Preconditions

**v1.0.0 (defect state, brownfield baseline):**
- `AdapterRegistry.known[0].vendorID == 0x152A` and `productIDs == [0x8460, 0x8463]` (hardcoded in AdapterRegistry.swift:22-24).
- `StarTechAdapter.model.vendorID == 0x152A` and `productIDs == [0x8460, 0x8463]` (hardcoded in StarTechAdapter.swift:13-15).
- `ProfileStore.builtIns[0].vid == 0x152A` and `pids == [0x8460, 0x8463]` (hardcoded in ProfileStore.swift:25-27).
- All three agree at v1.0.0; divergence can only occur through a future edit to one or two (not all three) locations.

**v1.1.0 (target state):**
- `ProfileStore.builtIns` is the sole place where VID/PID constants are declared.
- `AdapterRegistry.known` constructs its `AdapterModel` entries by reading from `ProfileStore.builtIns`.
- `StarTechAdapter.model` constructs its `AdapterModel` by reading from `ProfileStore.builtIns`.

## Postconditions

**v1.1.0 behavioural invariant (post-refactor):**
- For all `p` in `ProfileStore.builtIns`: there exists exactly one `AdapterModel` in `AdapterRegistry.known` with `model.id == p.id`, `model.vendorID == p.vid`, and `model.productIDs == p.pids`.
- `StarTechAdapter.model` derives from the StarTech entry resolved **by id** (`ProfileStore.builtIns.first { $0.id == "startech-notecons02" }`), NOT a force-unwrapped `.first!`. When that entry is present, `model.vendorID == entry.vid` and `model.productIDs == entry.pids`.
- **No `!` force-unwrap appears in the derivation of the `static let model`** (a force-unwrap there would trap at type-initialization if built-ins were ever empty — contradicting EC-003's "no crash" guarantee).
- Adding a new PID to the StarTech built-in's `productIds` string array automatically propagates to both `AdapterRegistry` and `StarTechAdapter.model` without any other code change.

## Invariants

- There is exactly one place to update supported VID/PID values: `ProfileStore.builtIns`.
- `AdapterRegistry` and `StarTechAdapter` do not contain device identity constants; they reference `ProfileStore.builtIns`.
- The `AdapterModel.id` for the StarTech adapter remains `"startech-notecons02"` — stable across the refactor.

## Edge Cases

- EC-001 v1.0.0 state: all three agree → matching works, but any single-location edit causes divergence.
- EC-002 v1.1.0 state: PID added to `ProfileStore.builtIns[0].productIds` → automatically reflected in `AdapterRegistry.match()` and `StarTechAdapter.canDrive()`.
- EC-003 `ProfileStore.builtIns` is an empty array (pathological) → `AdapterRegistry.known` is empty; no adapters matched.
- EC-004 Custom user profiles in `ProfileStore.shared.profiles` do not affect `AdapterRegistry.known` — registry only reflects built-ins.

## Canonical Test Vectors

| Location | v1.0.0 (defect) | v1.1.0 (target) |
|---|---|---|
| StarTech built-in `vendorId`/`productIds` (string fields) | `"0x152A"` / `["0x8460","0x8463"]` (hardcoded) | declared **source of truth**; `.vid`/`.pids` are computed from these |
| `AdapterRegistry.known[0].vendorID` | `0x152A` (hardcoded) | derived from `ProfileStore.builtIns` |
| `StarTechAdapter.model.vendorID` | `0x152A` (hardcoded) | derived from `ProfileStore.builtIns` |
| Sync required on PID add | 3 edits | 1 edit |

## Error Handling

No runtime errors. The refactor is a compile-time structural change. If `ProfileStore.builtIns` is accidentally emptied, `AdapterRegistry` and `StarTechAdapter.model` both produce empty/zero-value entries and matching fails gracefully (no crash — fail-closed per BC-1.04.002).

## Traceability

| Field | Value |
|---|---|
| Source file:line (defect) | `Sources/OCCKit/Adapter/AdapterRegistry.swift:19-25` |
| Source file:line (defect) | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:11-16` |
| Source file:line (source of truth) | `Sources/OCCKit/Adapter/ProfileStore.swift:20-29` |
| Ingest BC | BC-073 (pass-3-behavioral-contracts.md) |
| L2 Invariants | DI-TBD (single source of truth for device identity) |
| Capability Anchor Justification | CAP-TBD ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.002 — related: `AdapterRegistry.match()` and `StarTechAdapter.canDrive()` both implement the same vid&&pids.contains logic as `HardwareProfile.matches()`
- BC-1.04.005 — depends on: `ProfileStore.builtIns` is the source of truth seeded here

## Architecture Anchors

- `Sources/OCCKit/Adapter/AdapterRegistry.swift:18-32`
- `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:10-19`
- `Sources/OCCKit/Adapter/ProfileStore.swift:20-29`

## Story Anchor

- STORY-TBD (v1.1.0 refactor: eliminate triple PID hardcode, P1.4)

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/AdapterRegistry.swift:19-25`, `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:11-16`, `Sources/OCCKit/Adapter/ProfileStore.swift:20-29` |
| Confidence | HIGH (triple hardcode confirmed by direct read of all three files) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
