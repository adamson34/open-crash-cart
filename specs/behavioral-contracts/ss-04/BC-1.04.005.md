---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.005
title: "ProfileStore Seed and Self-Heal — Missing/Corrupt vs. Empty-Array Distinction"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/ProfileStore.swift
ingest_bc: BC-200
domain_facts: [BC-200]
---

# BC-1.04.005: ProfileStore Seed and Self-Heal — Missing/Corrupt vs. Empty-Array Distinction

## Description

`ProfileStore` initialises itself from `~/Library/Application Support/OpenCrashCart/profiles.json`. The initialiser distinguishes two failure modes: (1) the file is missing or undecodable (corrupt JSON) — in this case the store seeds from built-ins AND writes them to disk (`writeToDisk()`); (2) the file decodes successfully but the profiles array is empty — in this case the store loads built-ins in memory only, without rewriting the file.

## Preconditions

- The App Support directory `~/Library/Application Support/OpenCrashCart/` may or may not exist.
- `profiles.json` may be absent, corrupt, or a valid JSON file with zero or more profiles.
- `ProfileStore.builtIns` is a non-empty constant array containing at least the StarTech NOTECONS02 profile.

## Postconditions

**Case A — file missing or corrupt (decode throws):**
- `_profiles` is set to `ProfileStore.builtIns`.
- `_firmwareDirectory` is set to `nil`.
- `writeToDisk()` is called: the built-in profiles are written to `profiles.json`.

**Case B — file decodes, profiles array is empty (`cfg.profiles.isEmpty == true`):**
- `_profiles` is set to `ProfileStore.builtIns` in memory.
- `_firmwareDirectory` is set to `cfg.firmwareDirectory` (may be non-nil from the decoded config).
- `writeToDisk()` is NOT called (empty array preserved on disk).

**Case C — file decodes, profiles array is non-empty:**
- `_profiles` is set to `cfg.profiles` as decoded.
- `_firmwareDirectory` is set to `cfg.firmwareDirectory`.
- No disk write occurs.

## Invariants

- After init, `_profiles` is never empty: it always contains at least `ProfileStore.builtIns`.
- A disk write only occurs on Case A (self-heal), not on Case B or C.
- The App Support directory is created (`withIntermediateDirectories: true`) before any file access.

## Edge Cases

- EC-001 File exists, valid JSON, non-empty profiles → Case C (no disk write).
- EC-002 File exists, valid JSON, `profiles: []` → Case B (built-ins in memory, no rewrite).
- EC-003 File missing entirely → Case A (seed + write).
- EC-004 File exists but not valid JSON → Case A (seed + write).
- EC-005 File exists, valid JSON, `firmwareDirectory` is set, but `profiles: []` → Case B: firmwareDirectory is preserved from decoded config.
- EC-006 First launch (no App Support dir) → directory created, then Case A applies.

## Canonical Test Vectors

| Scenario | File state | Post-init `_profiles` | Disk write? |
|---|---|---|---|
| Fresh install | Missing | `builtIns` | Yes |
| Corrupt JSON | Undecodable | `builtIns` | Yes |
| Empty profiles array | `{"profiles":[]}` | `builtIns` | No |
| Custom profiles | `{"profiles":[{...}]}` | Decoded profiles | No |

## Error Handling

`try? Data(contentsOf:)` and `try? JSONDecoder().decode(...)` suppress errors silently. If either fails, Case A applies. There is no error logging on decode failure — this is a known reliability gap flagged in Pass 3.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:37-45` |
| Ingest BC | BC-200 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (store must always have at least one profile) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.006 — composes with: remove() cannot delete built-ins seeded here
- BC-1.04.009 — composes with: writeToDisk() called on Case A

## Architecture Anchors

- `Sources/OCCKit/Adapter/ProfileStore.swift:31-46` — `private init()`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/ProfileStore.swift:37-45` |
| Confidence | HIGH (direct code read, unambiguous conditional) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
