---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.008
title: "ProfileStore.firmwareDirectory — Immediate-Persist Setter and NSLock-Guarded Accessors"
origin: brownfield
subsystem: SS-04
capability: CAP-TBD
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/ProfileStore.swift
ingest_bc: BC-203
domain_facts: [BC-203]
---

# BC-1.04.008: ProfileStore.firmwareDirectory — Immediate-Persist Setter and NSLock-Guarded Accessors

## Description

`ProfileStore.firmwareDirectory` is a computed property with explicit getter and setter, both protected by `NSLock`. The setter immediately calls `writeToDisk()` after updating the private `_firmwareDirectory` backing variable. All read and write access to `_profiles` and `_firmwareDirectory` — across every public accessor — goes through the same `NSLock`, making `ProfileStore` safe for concurrent access from the connect/boot thread and the UI thread.

## Preconditions

- `ProfileStore.shared` has been initialised (singleton).
- The calling thread does not already hold `ProfileStore`'s `NSLock` (would deadlock; NSLock is not reentrant).
- `newValue` may be `nil` (clear the directory) or a non-empty path string.

## Postconditions

**Getter (`firmwareDirectory`):**
- Acquires `lock`, reads `_firmwareDirectory`, releases lock, returns value.
- Thread-safe: concurrent reads are serialised through the lock.

**Setter (`firmwareDirectory = newValue`):**
- Acquires `lock`, sets `_firmwareDirectory = newValue`, releases lock.
- Calls `writeToDisk()` (outside the lock; `writeToDisk` acquires the lock internally for its own read).
- The new value is visible to all subsequent getter calls after the setter returns.

**All other accessors (`profiles`, `match`, `upsert`, `remove`):**
- Each acquires the same `NSLock` before accessing `_profiles` or `_firmwareDirectory`.
- NSLock ensures mutual exclusion; `@unchecked Sendable` annotation documents that thread safety is manually managed.

## Invariants

- Every access to `_profiles` or `_firmwareDirectory` is enclosed in a lock/unlock pair.
- `defer { lock.unlock() }` is used in read-only accessors for exception-safety.
- `writeToDisk()` is called outside the critical section (reads state under its own lock internally).
- Setting `firmwareDirectory` to `nil` clears the store-wide override; per-profile `firmwareDir` fields are unaffected.

## Edge Cases

- EC-001 Two threads simultaneously set `firmwareDirectory` → one wins; disk written twice; both writes succeed sequentially.
- EC-002 Set `firmwareDirectory = nil` → `_firmwareDirectory` becomes `nil`; disk written; `firmware` key in JSON set to `null`.
- EC-003 UI thread reads `firmwareDirectory` while boot thread reads `profiles` → serialised via lock; no data race.
- EC-004 Lock held during `writeToDisk` internal read (writeToDisk acquires lock itself) → safe because the outer lock is already released before `writeToDisk` is called in the setter.

## Canonical Test Vectors

| Operation | Pre-state | Post-state | Disk write? |
|---|---|---|---|
| `store.firmwareDirectory = "/my/fw"` | `_firmwareDirectory: nil` | `_firmwareDirectory: "/my/fw"` | Yes |
| `store.firmwareDirectory = nil` | `_firmwareDirectory: "/my/fw"` | `_firmwareDirectory: nil` | Yes |
| `store.firmwareDirectory` (get) | `_firmwareDirectory: "/my/fw"` | unchanged | No |

## Error Handling

`writeToDisk()` silently swallows write failures via `try?` (see BC-1.04.009). No error is returned by the setter.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:50-57` (firmwareDirectory property) |
| Source file:line | `Sources/OCCKit/Adapter/ProfileStore.swift:84-91` (writeToDisk + NSLock) |
| Ingest BC | BC-203 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (thread-safe profile access) |
| Capability Anchor Justification | CAP-TBD ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.009 — composes with: writeToDisk silent-fail contract
- BC-1.04.004 — related: this property is Tier 2 in two-tier firmware location

## Architecture Anchors

- `Sources/OCCKit/Adapter/ProfileStore.swift:8` — `private let lock = NSLock()`
- `Sources/OCCKit/Adapter/ProfileStore.swift:50-57` — `firmwareDirectory` getter/setter

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/ProfileStore.swift:50-57` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
