---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/USB/USBDevice.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.009: bulkRead Returns Transferred-Byte Prefix with Default Timeouts

## Description
`USBDevice.bulkRead` allocates a buffer of `maxLength` bytes, performs a blocking libusb bulk transfer, and returns only the prefix of the buffer actually filled — `Array(buffer[0..<Int(transferred)])`. The default read timeout is 2000 ms and the default write timeout is 1000 ms. Callers may override these via the `timeoutMs` parameter.

## Preconditions
1. `handle` is non-nil (device is open and claimed).
2. `maxLength > 0`.
3. `timeoutMs` is provided or defaults to 2000 (read) / 1000 (write).

## Postconditions
1. A buffer of exactly `maxLength` bytes is allocated and passed to `libusb_bulk_transfer`.
2. The return value is `Array(buffer[0..<Int(transferred)])` — length equals the actual transfer count, which may be less than `maxLength`.
3. If `transferred == 0`, an empty array is returned (not nil).
4. If `handle` is nil, `USBTransportError.disconnected` is thrown before any I/O.

## Invariants
1. The returned array length is always in `[0, maxLength]`.
2. Bytes beyond `transferred` are not included in the return value (no garbage bytes).
3. The write default timeout (1000 ms) differs from the read default (2000 ms).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `transferred == 0` | Returns empty `[]` array |
| EC-002 | `transferred == maxLength` | Full buffer returned |
| EC-003 | `transferred < maxLength` (partial) | Prefix slice returned |
| EC-004 | `handle == nil` | `.disconnected` thrown immediately |
| EC-005 | Transfer times out | `check(-7)` → `.timeout` thrown |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Transfer completes, `transferred=64`, `maxLength=128` | 64-byte array (prefix only) | happy-path |
| Transfer completes, `transferred=0` | `[]` empty array | edge case |
| `handle == nil` | `.disconnected` thrown | error |

## Error Handling
- `handle == nil`: `.disconnected` thrown via guard.
- libusb rc non-zero: mapped via `check(_:)` per BC-1.01.008.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/USB/USBDevice.swift:83-104 |
| Ingest BC | BC-022 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/USB/USBDevice.swift |
|------|------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | type constraint / assertion |
