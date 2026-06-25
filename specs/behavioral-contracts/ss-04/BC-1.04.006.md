---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.006
title: "ProfileStore.remove() — Built-In Profiles Are Non-Deletable"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/ProfileStore.swift
ingest_bc: BC-201
domain_facts: [BC-201]
---

# BC-1.04.006: ProfileStore.remove() — Built-In Profiles Are Non-Deletable

## Description

`ProfileStore.remove(id:)` deletes profiles by ID but silently skips any profile with `builtIn == true`. The filter predicate `{ $0.id == id && !$0.builtIn }` ensures that calling `remove` on the ID of a built-in profile leaves the store unchanged. This is the programmatic enforcement of the UI-level restriction (see BC-1.04.012 for the UI side).

## Preconditions

- `ProfileStore.shared` has been initialised.
- `id` is a non-nil, non-empty string.
- The profile with `id` may or may not exist in `_profiles`.
- The profile may have `builtIn == true` or `builtIn == false`.

## Postconditions

- If a profile matching `id` exists and `builtIn == false`: it is removed from `_profiles`; `writeToDisk()` is called.
- If a profile matching `id` exists and `builtIn == true`: `_profiles` is unchanged; `writeToDisk()` is still called (the write writes the unchanged array, which is a no-op in effect but still occurs).
- If no profile with `id` exists: `_profiles` is unchanged; `writeToDisk()` is called.
- `NSLock` is acquired/released around the `removeAll` mutation.

## Invariants

- Built-in profiles are never removed from `_profiles` by this method.
- `builtIn == true` is the sole gate; the profile ID is not specifically hardcoded in the remove logic.
- Disk write always occurs after every `remove` call regardless of whether anything was actually removed.

## Edge Cases

- EC-001 Remove a custom profile (builtIn=false) → removed and written to disk.
- EC-002 Remove the StarTech built-in by its ID → silently ignored; store unchanged.
- EC-003 Remove an ID that does not exist → no-op in memory, still writes disk (idempotent).
- EC-004 Multiple profiles with same builtIn=false and different IDs; remove one → only that one removed.
- EC-005 All custom profiles removed; only built-ins remain → disk written with built-ins only.

## Canonical Test Vectors

| Input ID | builtIn | Pre-state count | Post-state count | Disk write? |
|---|---|---|---|---|
| `"startech-notecons02"` | `true` | 1 | 1 | Yes (no-op write) |
| `"custom-abc12345"` | `false` | 2 | 1 | Yes |
| `"nonexistent-id"` | N/A | 1 | 1 | Yes (no-op write) |

## Error Handling

No error is surfaced. Attempting to remove a built-in silently succeeds from the caller's perspective (no error, no crash), but the profile remains. The UI enforces this contract at the row-button level (built-in rows have no Delete button — BC-1.04.012).

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:77-82` |
| Ingest BC | BC-201 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (built-in profiles cannot be deleted) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.005 — related: built-ins seeded here are the same profiles protected here
- BC-1.04.012 — UI enforcement: Delete button suppressed for builtIn profiles in SettingsWindow

## Architecture Anchors

- `Sources/OCCKit/Adapter/ProfileStore.swift:77-82` — `remove(id:)`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/ProfileStore.swift:77-82` |
| Confidence | HIGH (unambiguous filter predicate) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
