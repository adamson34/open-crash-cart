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
# Behavioral Contract BC-1.01.008: libusb Return Code to Error Mapping

## Description
The private `check(_:)` method in `USBDevice` maps libusb integer return codes to typed `USBTransportError` values. Return code 0 is success (no throw). Code -7 (LIBUSB_ERROR_TIMEOUT) maps to `.timeout`. Code -4 (LIBUSB_ERROR_NO_DEVICE) maps to `.disconnected`. All other non-zero codes map to `.transferFailed(rc)`.

## Preconditions
1. `check(_:)` is called after any libusb bulk transfer completes.
2. The rc value is the direct return from `libusb_bulk_transfer`.

## Postconditions
1. `rc == 0` → no throw; caller proceeds normally.
2. `rc == -7` → `USBTransportError.timeout` is thrown.
3. `rc == -4` → `USBTransportError.disconnected` is thrown.
4. Any other `rc != 0` → `USBTransportError.transferFailed(rc)` is thrown.

## Invariants
1. Exactly three code points are handled specially: 0 (success), -7 (timeout), -4 (no-device).
2. The mapping is deterministic and has no side effects.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `rc == 0` | No throw |
| EC-002 | `rc == -7` | `.timeout` thrown |
| EC-003 | `rc == -4` | `.disconnected` thrown |
| EC-004 | `rc == -1` (LIBUSB_ERROR_IO) | `.transferFailed(-1)` thrown |
| EC-005 | `rc == -99` (unknown code) | `.transferFailed(-99)` thrown |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `rc = 0` | No error | happy-path |
| `rc = -7` | `USBTransportError.timeout` | edge case |
| `rc = -4` | `USBTransportError.disconnected` | edge case |
| `rc = -5` | `USBTransportError.transferFailed(-5)` | error |

## Error Handling
All error cases throw; callers in writer/response/video loops handle `.timeout` (continue) and `.disconnected` (die) specially; `.transferFailed` is treated as transient by the writer and response loops.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/USB/USBDevice.swift:120-127 |
| Ingest BC | BC-021 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/USB/USBDevice.swift |
|------|------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | type constraint / assertion |
