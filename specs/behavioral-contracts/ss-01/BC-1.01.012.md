---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Util/Gunzip.swift"
subsystem: "SS-01"
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.012: gunzip Error Mapping — initFailed and inflateFailed

## Description
`gunzip` maps zlib errors to two typed enum cases: `GzipError.initFailed(rc)` when `inflateInit2_` returns a non-Z_OK code, and `GzipError.inflateFailed(rc)` when the inflate loop terminates with anything other than `Z_STREAM_END`. Both cases carry the raw zlib error integer for diagnostic purposes.

## Preconditions
1. `gunzip` is called with any `[UInt8]` input.
2. The zlib return value from `inflateInit2_` or the final `inflate` call is available.

## Postconditions
1. If `inflateInit2_` returns `rc != Z_OK (0)`: `GzipError.initFailed(rc)` is thrown; `inflateEnd` is still called via `defer`.
2. If the inflate loop exits with `result != Z_STREAM_END`: `GzipError.inflateFailed(result)` is thrown; `inflateEnd` is called via `defer`.
3. `Z_STREAM_END` is the only successful terminal state; all others produce `inflateFailed`.

## Invariants
1. `inflateEnd` is always called exactly once due to `defer`, regardless of success or failure.
2. Error codes from zlib are preserved verbatim (not translated to strings at throw site).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `inflateInit2_` returns `Z_MEM_ERROR` (-4) | `initFailed(-4)` thrown |
| EC-002 | `inflate` returns `Z_DATA_ERROR` (-3) | `inflateFailed(-3)` thrown |
| EC-003 | `inflate` returns `Z_OK` then loop exits (shouldn't happen) | `inflateFailed(Z_OK)` thrown (defensive) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Valid gzip bytes | Return success, no throw | happy-path |
| Corrupt bytes (not gzip/zlib) | `GzipError.inflateFailed(-3)` (`Z_DATA_ERROR`) | error |

## Error Handling
- Both error types have `CustomStringConvertible` descriptions for user-facing messages.
- `boot()` catches all errors from `loadFPGABitstream` (which calls `gunzip`) and emits them as `.message` events.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Util/Gunzip.swift:4-12, 21, 47 |
| Ingest BC | BC-051 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Util/Gunzip.swift |
|------|----------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | type constraint / assertion |
