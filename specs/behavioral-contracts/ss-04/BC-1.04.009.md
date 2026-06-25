---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.009
title: "ProfileStore.writeToDisk() — Pretty+SortedKeys JSON, Silent Write Failure"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/ProfileStore.swift
ingest_bc: BC-204
domain_facts: [BC-204]
---

# BC-1.04.009: ProfileStore.writeToDisk() — Pretty+SortedKeys JSON, Silent Write Failure

## Description

`ProfileStore.writeToDisk()` serialises the current in-memory state to `profiles.json` using `JSONEncoder` configured with `[.prettyPrinted, .sortedKeys]`. The output is human-readable and diff-friendly (consistent key order aids version-control diffing). Both the encode step and the file-write step use `try?`, meaning any failure — disk full, permission denied, encoding error — is silently swallowed with no logging or caller notification. This is a known reliability gap.

## Preconditions

- `ProfileStore` has been initialised (singleton).
- `fileURL` points to `~/Library/Application Support/OpenCrashCart/profiles.json`.
- The method may be called from any thread; it acquires `NSLock` internally to read current state.

## Postconditions

- A `Config` struct containing `_firmwareDirectory` and `_profiles` is constructed under lock.
- `JSONEncoder` with `outputFormatting = [.prettyPrinted, .sortedKeys]` encodes the config.
- If encoding succeeds, the resulting `Data` is written to `fileURL` via `try? data.write(to: fileURL)`.
- If encoding or writing fails, the failure is discarded — in-memory state is unchanged.
- JSON keys in the output are sorted alphabetically for determinism.

## Invariants

- Output format is always `prettyPrinted` + `sortedKeys` — never compact or with non-deterministic key order.
- The lock is held only for the state snapshot (`Config` construction); `encode` and `write` happen outside the lock.
- In-memory state is never modified by this method regardless of success or failure.
- The on-disk file is overwritten atomically by `Data.write(to:)` (POSIX atomic write via `.atomic` option is NOT explicitly set — this is a known atomicity gap).

## Edge Cases

- EC-001 Encode fails (hypothetical; all `HardwareProfile` fields are simple codable types) → write skipped; no log.
- EC-002 Disk full → `data.write(to:)` throws; silently swallowed.
- EC-003 File permissions prevent write → silently swallowed.
- EC-004 Called during initial seed (Case A of BC-1.04.005) → built-ins written with `builtIn: true` preserved.
- EC-005 `profiles.json` written with pretty format → a minimal config with one built-in produces multi-line, sorted-key JSON that can be diffed in git.

## Canonical Test Vectors

| Scenario | Expected JSON characteristic |
|---|---|
| StarTech built-in | Keys sorted: `backend`, `builtIn`, `firmwareDir`, `firmwareFiles`, `id`, `name`, `productIds`, `vendorId` |
| `firmwareDirectory: nil` | Top-level `firmwareDirectory` key is `null` |
| `firmwareDirectory: "/fw"` | `"firmwareDirectory": "/fw"` |
| Multiple profiles | Profile array entries are in insertion order (sortedKeys applies to object keys, not array order) |

## Error Handling

All errors are suppressed via `try?`. There is no error notification mechanism, no retry, and no fallback path. This is a known reliability gap identified in Pass 3 (BC-204 notes "reliability gap"). Future versions should log or surface write failures.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:84-91` |
| Ingest BC | BC-204 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (profile persistence) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.005 — caller: seeding calls writeToDisk on Case A
- BC-1.04.006 — caller: remove() always calls writeToDisk
- BC-1.04.007 — caller: upsert() always calls writeToDisk
- BC-1.04.008 — caller: firmwareDirectory setter calls writeToDisk

## Architecture Anchors

- `Sources/OCCKit/Adapter/ProfileStore.swift:84-91` — `private func writeToDisk()`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/ProfileStore.swift:84-91` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
