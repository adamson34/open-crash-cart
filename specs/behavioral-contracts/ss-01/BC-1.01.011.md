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
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.011: gunzip Round-Trip with windowBits 47

## Description
`gunzip(_:)` decompresses a gzip or zlib stream using the system zlib library, passing `windowBits = 47` (32 + 15) to `inflateInit2_` so that the wrapper format (gzip vs zlib) is auto-detected. The function is a pure transform: given valid compressed input it returns the fully decompressed bytes; given the output of `gzip(data)`, it returns the original `data`. The output is assembled from 64 KB chunks and returned as a flat `[UInt8]`.

## Preconditions
1. `input` is a non-empty `[UInt8]` containing a valid gzip or zlib-compressed byte stream.
2. The system zlib library is available (always true on macOS/Linux).

## Postconditions
1. `inflateInit2_(&strm, 47, zlibVersion(), …)` is called with `windowBits = 47`.
2. The full decompressed output is accumulated across one or more 65536-byte chunks.
3. Decompression completes when inflate returns `Z_STREAM_END`.
4. `inflateEnd(&strm)` is called via `defer` regardless of success or failure.
5. The returned `[UInt8]` contains exactly the decompressed bytes in order.
6. `gunzip(gzip(data)) == data` for any valid data (round-trip identity).

## Invariants
1. `windowBits = 47` is always used; this constant must not be changed without updating this BC.
2. The initial capacity hint is `input.count * 4` (may grow as needed).
3. The 65536-byte chunk size is fixed.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Input is a valid gzip stream | Returns decompressed bytes, no error |
| EC-002 | Input is a valid zlib stream | Also decompressed correctly (auto-detect) |
| EC-003 | `inflateInit2_` fails (returns != Z_OK) | `GzipError.initFailed(rc)` thrown |
| EC-004 | `inflate` fails mid-stream | `GzipError.inflateFailed(result)` thrown |
| EC-005 | Output larger than `input.count * 4` initial capacity | Array grows dynamically; all bytes captured |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Gzip-compressed `[0x48, 0x65, 0x6C, 0x6C, 0x6F]` ("Hello") | `[0x48, 0x65, 0x6C, 0x6C, 0x6F]` | happy-path (round-trip) |
| Truncated/corrupt gzip data | `GzipError.inflateFailed(…)` | error |
| `inflateInit2_` returns non-Z_OK | `GzipError.initFailed(rc)` | error |

## Error Handling
- `GzipError.initFailed(rc)`: zlib initialization refused; rc is the zlib error code.
- `GzipError.inflateFailed(rc)`: decompression error mid-stream; rc is the zlib error code.
- Caller (`StarTechFirmware.loadFPGABitstream`) propagates these errors; `boot()` catches them and emits a skip message.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Util/Gunzip.swift:17-49 |
| Ingest BC | BC-050 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Util/Gunzip.swift |
|------|----------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | assertion / documentation |
