---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.002: StarTech connect() Ordering — Open, Claim, Threads, Boot

## Description
`StarTechAdapter.connect()` follows a strict ordering: open the USB device, claim the interface, set the stored device reference, then start the three I/O threads (writer, response, video) before launching the boot thread. The event stream continuation is created before any thread touches it. `connect()` returns to the caller promptly — the boot handshake runs asynchronously on the boot thread.

## Preconditions
1. `StarTechAdapter` has been initialized with a valid `DiscoveredDevice`.
2. No prior `connect()` call is in progress (caller enforces single-session via `AppController.tryConnect` guard).
3. The USB device is physically present on the bus.

## Postconditions
1. `USBDevice.open(matching:)` is called first; any failure throws before the interface is claimed.
2. `dev.claimInterface(VSProtocol.interfaceNumber)` is called immediately after a successful open.
3. `self.device` is set to `dev` before any thread is started.
4. The `AsyncStream` continuation is established before threads are started.
5. Threads are started in order: writer ("OpenCrashCart-Writer"), response ("OpenCrashCart-Response"), video ("OpenCrashCart-Video"), then boot ("OpenCrashCart-Boot").
6. `connect()` returns the `AsyncStream` before the boot thread completes.
7. If `isHighSpeedOrBetter` is false, a warning message event is emitted on the stream.

## Invariants
1. No I/O thread starts before `self.device` is set.
2. The stream continuation is never nil when the first thread calls `emit()`.
3. Boot runs on its own thread; `connect()` does not block on it.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `USBDevice.open` throws | Propagates throw; no interface claimed, no threads started |
| EC-002 | `claimInterface` throws | Propagates throw; `self.device` never set, no threads started |
| EC-003 | Device is full-speed (not high-speed) | Warning message emitted after stream creation, threads still start |
| EC-004 | Boot thread fails to load FPGA | `.message("FPGA load skipped: …")` emitted; session continues without FPGA |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Valid high-speed device present | Stream returned, 4 threads running, boot message emitted | happy-path |
| Valid full-speed device | Stream returned + warning message event, threads running | edge case |
| `USBDevice.open` throws `.deviceNotFound` | `connect()` throws `.deviceNotFound` | error |

## Error Handling
- `USBTransportError.deviceNotFound` or `USBTransportError.openFailed` from `open` propagates directly.
- `USBTransportError.claimFailed` from `claimInterface` propagates directly.
- Both cases leave the adapter in an unconnected state; caller (`AppController.tryConnect`) handles reset.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:49-72 |
| Ingest BC | BC-081 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
