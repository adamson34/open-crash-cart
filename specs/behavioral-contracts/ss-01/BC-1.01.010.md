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
# Behavioral Contract BC-1.01.010: Disconnected Guard Before Transfer and Idempotent close()

## Description
Both `bulkRead` and `bulkWrite` guard against a nil handle before issuing any libusb call, throwing `.disconnected` immediately if the device is no longer open. `close()` is idempotent: it releases the interface and closes the handle on the first call, then sets `handle = nil` and `ctx = nil`; subsequent calls are no-ops.

## Preconditions
1. `USBDevice` instance exists (may be in open or closed state).
2. Caller may invoke `close()` any number of times.
3. Caller may call `bulkRead`/`bulkWrite` at any point.

## Postconditions
1. `bulkRead`/`bulkWrite` with `handle == nil` → `USBTransportError.disconnected` thrown before any libusb call.
2. First `close()` call: `libusb_release_interface`, `libusb_close(handle)`, `handle = nil`, `libusb_exit(ctx)`, `ctx = nil`.
3. Second (and subsequent) `close()` calls: both `if let` guards fail; no libusb calls are made.
4. After `close()`, all subsequent transfers throw `.disconnected` due to nil handle.

## Invariants
1. `handle` and `ctx` become nil atomically from the caller's perspective (no partial state visible).
2. No crash occurs from double-close.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `close()` called once | Interface released, handle and ctx freed, both set to nil |
| EC-002 | `close()` called twice | Second call is a complete no-op |
| EC-003 | `bulkRead` after `close()` | `.disconnected` thrown via guard |
| EC-004 | `bulkWrite` after `close()` | `.disconnected` thrown via guard |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `close()` on open device | No error; handle=nil, ctx=nil | happy-path |
| `close()` called again | No-op; no crash | edge case |
| `bulkRead` after close | `.disconnected` thrown | error |

## Error Handling
- No errors thrown from `close()`.
- `bulkRead`/`bulkWrite` with closed handle throw `.disconnected`.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/USB/USBDevice.swift:84, 95-96, 108-118 |
| Ingest BC | BC-023 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/USB/USBDevice.swift |
|------|------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause |
