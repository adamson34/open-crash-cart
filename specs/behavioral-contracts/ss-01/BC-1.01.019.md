---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.019: Write No-Op on RO/Closed and Idempotent close()

## Description
`VirtualMedia.write(startBlock:data:)` is a no-op if `closed == true` or `readOnly == true`; no file I/O is attempted in either case. `close()` is idempotent: the first call sets `closed = true` and closes the file handle; subsequent calls find `closed` already true and do nothing. All operations hold the `NSLock`.

## Preconditions
1. `VirtualMedia` is initialized (possibly read-only).
2. `write` or `close` may be called from any thread.

## Postconditions
1. `write` with `closed == true`: returns immediately without write.
2. `write` with `readOnly == true` (ISO): returns immediately without write.
3. `write` with `closed == false && readOnly == false`: seeks and writes data to file.
4. First `close()`: sets `closed = true`, calls `handle.close()`.
5. Subsequent `close()`: `closed` is already true; nothing happens.

## Invariants
1. Read-only media can never be written, regardless of calling context.
2. `close()` is safe to call from concurrent threads (lock-protected).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Write to ISO (readOnly=true) | No-op; no file I/O |
| EC-002 | Write after close | No-op; no file I/O |
| EC-003 | `close()` called twice | Second call is a no-op |
| EC-004 | Concurrent `write` and `close` | Lock ensures one completes before the other |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Write to open IMG at block 0 | Data written to file at byte offset 0 | happy-path |
| Write to ISO (readOnly=true) | No-op; file unchanged | edge case |
| `close()` twice | No crash; handle closed once | edge case |

## Error Handling
- `write` swallows seek/write errors via `try?`; no errors thrown or surfaced.
- `close` swallows `handle.close()` errors via `try?`.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift:45-55 |
| Ingest BC | BC-062 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift |
|------|-----------------------------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
