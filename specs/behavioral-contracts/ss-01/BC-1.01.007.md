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
# Behavioral Contract BC-1.01.007: USB Device Open by Bus+Address, else deviceNotFound

## Description
`USBDevice.open(matching:)` iterates the libusb device list and opens the specific device identified by the combination of bus number AND address — not just VID/PID — ensuring the exact physical unit is targeted. If no device in the list matches both fields, the libusb context is exited and `deviceNotFound` is thrown.

## Preconditions
1. `libusb_init` has not been called prior; `open` manages its own context lifetime.
2. `target.busNumber` and `target.address` are populated from a prior discovery scan.
3. The device may or may not still be physically present.

## Postconditions
1. `libusb_init` is called; if it fails (rc != 0), `contextInitFailed(rc)` is thrown and no list is retrieved.
2. The full device list is retrieved; if `count < 0`, `libusb_exit` is called and `deviceNotFound` is thrown.
3. Each device in the list is compared: `libusb_get_bus_number(dev) == target.busNumber && libusb_get_device_address(dev) == target.address`.
4. On a match: `libusb_open` is called; if `rc == 0`, a `USBDevice` is returned with `ctx` and `handle` set.
5. On a match but `libusb_open` fails: `libusb_exit` is called and `openFailed(rc)` is thrown.
6. If the list is exhausted with no match: `libusb_exit` is called and `deviceNotFound` is thrown.
7. `libusb_free_device_list` is called via `defer` after successful match and open.

## Invariants
1. Exactly one libusb context is created per `open` call; it is either owned by the returned `USBDevice` or freed before the throw.
2. Bus+address uniquely identifies the physical port; VID/PID are not re-checked here.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Device was disconnected between discovery and open | List exhausted; `deviceNotFound` thrown |
| EC-002 | Bus matches but address differs (device re-enumerated) | No match; `deviceNotFound` thrown |
| EC-003 | `libusb_init` fails | `contextInitFailed(rc)` thrown immediately |
| EC-004 | `libusb_get_device_list` returns negative count | `libusb_exit`; `deviceNotFound` thrown |
| EC-005 | Match found but `libusb_open` returns non-zero rc | `libusb_exit`; `openFailed(rc)` thrown |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `target` matches device at bus=1, addr=3 | `USBDevice` returned, `info == target` | happy-path |
| `target.address` differs from all devices | `deviceNotFound` thrown | edge case |
| `libusb_init` returns -12 | `contextInitFailed(-12)` thrown | error |

## Error Handling
- `USBTransportError.contextInitFailed(rc)`: libusb init failure.
- `USBTransportError.deviceNotFound`: device not in current enumeration.
- `USBTransportError.openFailed(rc)`: device present but open rejected (permissions, kernel driver).

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/USB/USBDevice.swift:45-73 |
| Ingest BC | BC-020 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/USB/USBDevice.swift |
|------|------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
