---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.013
title: "SettingsWindow — Built-In Profiles Are Non-Deletable in UI"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/occ/SettingsWindow.swift
ingest_bc: BC-132
domain_facts: [BC-132]
---

# BC-1.04.013: SettingsWindow — Built-In Profiles Are Non-Deletable in UI

## Description

When building a profile row in the Settings window, `SettingsWindowController.makeProfileRow(_:detected:)` only adds a "Delete" button to the row's button stack if `profile.builtIn == false`. Built-in profiles have an "Edit" button only. This is the UI-layer enforcement of the same invariant enforced at the data layer by `ProfileStore.remove()` (BC-1.04.006).

## Preconditions

- `makeProfileRow(_:detected:)` is called for each profile in `ProfileStore.shared.profiles`.
- The `profile.builtIn` field is read from the stored profile.

## Postconditions

- If `profile.builtIn == false`: the row contains both an "Edit" button and a "Delete" button.
- If `profile.builtIn == true`: the row contains only an "Edit" button; no "Delete" button is added.
- The "(built-in)" label suffix is appended to the displayed name for built-in profiles: `profile.name + "  (built-in)"`.

## Invariants

- The "Delete" button is created and wired only when `!profile.builtIn` evaluates to true.
- Built-in profile row rendering is never altered by the number of custom profiles present.
- The Edit button is always present for all profiles (built-in or custom).

## Edge Cases

- EC-001 Store has only the StarTech built-in → single row with Edit only, no Delete.
- EC-002 Store has StarTech built-in + one custom → built-in row: Edit only; custom row: Edit + Delete.
- EC-003 User edits a built-in profile (Edit button present) → edit flow preserves `builtIn: true` per BC-1.04.012; row still shows as built-in after refresh.
- EC-004 `refresh()` is called after any edit/delete → rows are rebuilt from current store state (no stale UI).

## Canonical Test Vectors

| Profile | builtIn | Buttons in row |
|---|---|---|
| StarTech NOTECONS02 | `true` | Edit only |
| Custom `"custom-abc12345"` | `false` | Edit, Delete |

## Error Handling

No error cases. The conditional is a simple `if !profile.builtIn { ... }` block.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/occ/SettingsWindow.swift:139-148` |
| Ingest BC | BC-132 (pass-3-deep-app-layer.md) |
| L2 Invariants | DI-TBD (built-in profile deletion prevention) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") per capabilities.md §CAP-004 |

## Related BCs

- BC-1.04.006 — data layer enforcement of same invariant
- BC-1.04.012 — provenance: built-in flag preserved through edits

## Architecture Anchors

- `Sources/occ/SettingsWindow.swift:139-148` — `makeProfileRow` button-stack conditional

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/occ/SettingsWindow.swift:139-148` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
