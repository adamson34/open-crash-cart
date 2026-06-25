---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.004
title: "HardwareProfile Two-Tier Firmware Location — Profile Override vs. Store Directory"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/HardwareProfile.swift
  - Sources/OCCKit/Adapter/ProfileStore.swift
ingest_bc: DF-200
domain_facts: [DF-200, DF-201]
---

# BC-1.04.004: HardwareProfile Two-Tier Firmware Location — Profile Override vs. Store Directory

## Description

**Scope (adversary B10/F-05):** this BC covers ONLY the profile-vs-store override sub-relationship (DF-200/201) — NOT the full precedence list. The complete 7-tier search chain (incl. `OCC_FIRMWARE_DIR` + the three vendor paths) is canonical in **BC-1.01.013** (../ss-01/BC-1.01.013.md); this BC contributes the profile/store directories as inputs to it. Within that chain, a `HardwareProfile` may carry a per-profile `firmwareDir: String?` override (DF-200). Separately, `ProfileStore` exposes a store-wide `firmwareDirectory: String?` (DF-200). When both are set the per-profile `firmwareDir` takes precedence; neither field is required. The fallback path is the App Support firmware directory (`applicationSupportFirmwareDir`) which is derived at runtime and never persisted (DF-201).

## Preconditions

- `HardwareProfile.firmwareDir` may be `nil` (no per-profile override) or a non-empty path string.
- `ProfileStore.firmwareDirectory` may be `nil` (not set) or a non-empty path string.
- Both fields are independent; changing one does not affect the other.

## Postconditions

- `HardwareProfile.firmwareDir` (when non-nil) is the highest-priority firmware search location for that specific profile.
- `ProfileStore.firmwareDirectory` (when non-nil) is the fallback for profiles that have no `firmwareDir`.
- `ProfileStore.applicationSupportFirmwareDir` is always the last-resort path: `<profiles.json dir>/firmware`.
- `applicationSupportFirmwareDir` is computed from `fileURL` at call time; it is never stored to disk.

## Invariants

- Tier 1 (profile-level `firmwareDir`) always wins over Tier 2 (store-level `firmwareDirectory`).
- `applicationSupportFirmwareDir` path is always `<App Support>/OpenCrashCart/firmware`.
- Setting `ProfileStore.firmwareDirectory` does NOT change any `HardwareProfile.firmwareDir`.
- Both directories are strings (filesystem paths), not `URL` objects — conversion is caller responsibility.

## Edge Cases

- EC-001 Both `firmwareDir` and `ProfileStore.firmwareDirectory` are `nil` → only App Support path is available.
- EC-002 Profile `firmwareDir` is set to a non-existent path → firmware loader receives that path and will fail at load time (not at profile evaluation time).
- EC-003 `ProfileStore.firmwareDirectory` is set to a valid path but the specific profile has `firmwareDir` set → profile path wins, store path ignored for that profile.
- EC-004 Two profiles in the same store, one with `firmwareDir` set and one without → each resolves independently.

## Canonical Test Vectors

| firmwareDir | store firmwareDirectory | Expected priority path |
|---|---|---|
| `"/custom/fw"` | `"/store/fw"` | `"/custom/fw"` (profile wins) |
| `nil` | `"/store/fw"` | `"/store/fw"` (store fallback) |
| `nil` | `nil` | `applicationSupportFirmwareDir` |
| `"/custom/fw"` | `nil` | `"/custom/fw"` (profile wins) |

## Error Handling

No error is raised at the profile-tier level. An invalid path is passed downstream to `StarTechFirmware.loadFPGABitstream(profile:)` which handles file-not-found errors. See BC-1.01.013 for the canonical full search order.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/HardwareProfile.swift:13` (`firmwareDir` field) |
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:54-57` (`firmwareDirectory` accessor) |
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:60-62` (`applicationSupportFirmwareDir`) |
| Ingest domain fact | DF-200, DF-201 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (firmware location precedence) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") per capabilities.md §CAP-004 |

## Related BCs

- BC-1.04.008 — composes with: `ProfileStore.firmwareDirectory` setter (BC-1.04.008 governs persistence)
- BC-1.01.013 — canonical firmware search order; consumes this profile/store result as inputs

## Architecture Anchors

- `Sources/OCCKit/Adapter/HardwareProfile.swift:13`
- `Sources/OCCKit/Adapter/ProfileStore.swift:54-62`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/HardwareProfile.swift:13`, `Sources/OCCKit/Adapter/ProfileStore.swift:54-62` |
| Confidence | HIGH (direct field read, no ambiguity) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
