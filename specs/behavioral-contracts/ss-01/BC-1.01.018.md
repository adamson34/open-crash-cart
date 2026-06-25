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
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.018: Block Read Zero-Pads Short and Closed Reads

## Description
`VirtualMedia.read(startBlock:length:)` seeks to the byte offset `startBlock * blockSize`, reads up to `length` bytes, and returns exactly `length` bytes by zero-padding if the actual read is shorter than requested. If the media is closed or `length == 0`, an all-zero `Data` of size `max(0, length)` is returned immediately without file I/O.

## Preconditions
1. `VirtualMedia` is initialized and optionally open.
2. `startBlock` and `length` are provided by the device's FT read request.

## Postconditions
1. If `closed == true` or `length <= 0`: returns `Data(count: max(0, length))` (all zeros).
2. Otherwise: seeks to `UInt64(startBlock) * UInt64(blockSize)`, reads `length` bytes.
3. If `readData(ofLength:)` returns fewer than `length` bytes: the result is padded with `Data(count: length - data.count)` zeros.
4. If seek or read throws: returns `Data(count: length)` (all zeros as fallback).
5. The lock (`lock.lock()`) is held for the entire read operation.

## Invariants
1. The returned `Data` is always exactly `length` bytes (unless `length <= 0` in which case it is 0 bytes).
2. Zero-padding is appended at the end of the data, not interspersed.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `closed == true` | Returns `Data(count: length)` immediately |
| EC-002 | `length == 0` | Returns empty `Data` |
| EC-003 | Partial read (near end of file) | Read data + zero padding to `length` bytes |
| EC-004 | Seek fails | Caught by `do/catch`; returns `Data(count: length)` |
| EC-005 | `startBlock` beyond end of file | `readData(ofLength:)` returns empty; full zero `Data` returned |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Open media, `startBlock=0, length=512` (IMG) | First 512 bytes of file | happy-path |
| `closed=true`, `length=512` | `Data` of 512 zero bytes | edge case |
| Partial last block: file has 300 bytes, `length=512` | 300 real bytes + 212 zero bytes | edge case |

## Error Handling
- No errors thrown from `read`.
- Seek/read exceptions are caught and produce a zero-padded result.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift:33-42 |
| Ingest BC | BC-061 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift |
|------|-----------------------------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
