---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapter/ProfileStore.swift"
subsystem: "SS-04"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.04.007: ProfileStore.upsert() — ID-Keyed Replace-or-Append Write-Through

## Description

`ProfileStore.upsert(_:)` performs an id-keyed replace-or-append operation: if a profile with the same `id` already exists in `_profiles`, it is replaced in-place at the same index; if no profile with that `id` exists, the new profile is appended. In either case the full store is written to disk immediately after the in-memory update. No format validation is performed on the incoming profile fields.

## Preconditions

- `ProfileStore.shared` has been initialised.
- `profile` is a fully-constructed `HardwareProfile` with a non-empty `id`.
- `NSLock` is not already held by the calling thread.

## Postconditions

- **Replace path:** If `_profiles.firstIndex(where: { $0.id == profile.id })` returns a non-nil index `i`, then `_profiles[i]` is replaced with `profile`.
- **Append path:** If no matching index exists, `profile` is appended to `_profiles`.
- `writeToDisk()` is called exactly once after the mutation, persisting the updated store.
- `NSLock` is acquired before and released after the mutation (and before `writeToDisk`).

## Invariants

- The operation is write-through: in-memory state and on-disk state are updated atomically within the same `upsert` call.
- Order of existing profiles is preserved; a replacement does not change position.
- No validation of `vendorId`, `productIds`, or other fields is performed here — invalid strings are stored as-is.
- An upsert of a built-in profile (same id, `builtIn: true`) replaces it in-place, including the `builtIn` flag value from the incoming profile — the flag is not protected here.

## Edge Cases

- EC-001 Upsert a new custom profile → appended; disk written.
- EC-002 Upsert an edit to an existing custom profile (same id) → replaced in-place at same index.
- EC-003 Upsert with the StarTech built-in ID but `builtIn: false` → replaces built-in entry with `builtIn: false` version (note: this is a semantic risk; `remove` protects builtIn profiles but `upsert` does not).
- EC-004 Upsert with empty `productIds` → stored as-is; no validation.
- EC-005 Upsert with malformed `vendorId` (e.g. `"garbage"`) → stored as-is; `vid` will compute as 0.
- EC-006 Two rapid upserts — each acquires NSLock independently; second waits for first to release.

## Canonical Test Vectors

| Scenario | Pre-state | upsert arg | Post-state |
|---|---|---|---|
| Append new | `[builtIn]` | `{id:"custom-abc", ...}` | `[builtIn, custom-abc]` |
| Replace existing | `[builtIn, custom-abc]` | `{id:"custom-abc", name:"Renamed"}` | `[builtIn, {id:"custom-abc",name:"Renamed"}]` |
| Replace built-in | `[builtIn]` | `{id:"startech-notecons02", builtIn:false}` | `[{id:"startech-notecons02",builtIn:false}]` |

## Error Handling

`writeToDisk()` uses `try?` — disk write failures are silently swallowed (known reliability gap, BC-1.04.009). No error is propagated to the caller.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:69-75` |
| Ingest BC | BC-202 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (profile store consistency) |
| Capability Anchor Justification | CAP-TBD ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.009 — composes with: writeToDisk silent-fail contract
- BC-1.04.010 — UI caller: SettingsWindow presentEditor calls upsert after collecting fields

## Architecture Anchors

- `Sources/OCCKit/Adapter/ProfileStore.swift:69-75` — `upsert(_:)`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/ProfileStore.swift:69-75` |
| Confidence | HIGH (unambiguous control flow) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
