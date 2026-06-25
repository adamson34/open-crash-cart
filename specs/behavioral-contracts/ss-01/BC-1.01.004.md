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
# Behavioral Contract BC-1.01.004: Response Dispatch and Heartbeat Echo

## Description
The response loop reads 64-byte packets from the device's stream-in endpoint and dispatches each based on the first byte (command). Heartbeat packets ('H', `VSProtocol.Response.heartbeat`) are echoed back: the exact received payload is prepended with the heartbeat command byte and re-enqueued at `.control` priority. All other recognized responses invoke specific handlers; unrecognized command bytes are silently dropped.

## Preconditions
1. The response thread is running with a valid `USBDevice` handle.
2. `running.get()` returns true.
3. The device has been claimed and the boot sequence has started.

## Postconditions
1. Each packet's first byte is matched against `VSProtocol.Response` raw values.
2. For `.heartbeat`: a new message `[VSProtocol.Response.heartbeat.rawValue] + args` is enqueued at `.control` priority.
3. For `.status`: `parseStatus(args)` is called.
4. For `.fpgaGood`: `.message("FPGA loaded.")` is emitted and a fresh `getStatus` is enqueued.
5. For `.fpgaBad`: `.message("FPGA load failed: …")` with null-terminated ASCII reason is emitted.
6. For `.ftRead` / `.ftWrite`: virtual media read/write handlers are invoked synchronously on the response thread.
7. For `.ftStartStop` with `args[0] & 3 == 2`: `ejectMedia()` is called (target ejected the media).
8. Unrecognized command bytes (no `VSProtocol.Response` case) are dropped silently.

## Invariants
1. Heartbeat echo preserves the received args bytes verbatim.
2. Response handling never throws; all errors in sub-handlers are swallowed.
3. The response loop continues after a `.timeout` error from `bulkRead`; only `.disconnected` terminates it.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Packet with zero length (empty) | `packet.first` is nil; `continue` skips dispatch |
| EC-002 | Unrecognized command byte | `VSProtocol.Response(rawValue:)` returns nil; dropped |
| EC-003 | `.ftStartStop` with bits not equal 2 | No eject; ignored |
| EC-004 | `.heartbeat` received while queue closing | `enqueue` no-ops because queue is closed; no crash |
| EC-005 | `bulkRead` throws `.timeout` | Loop continues normally |
| EC-006 | `bulkRead` throws `.disconnected` | `died("Device disconnected")` called |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Packet `[0x48, 0x01, 0x02]` (heartbeat 'H' + 2 args) | Enqueued: `[0x48, 0x01, 0x02]` at `.control` | happy-path (echo) |
| Packet `[status_cmd, …29 bytes…]` | `parseStatus` called with 28-byte args | happy-path (status) |
| Packet `[0xFF]` (unknown cmd) | Silently dropped; loop continues | edge case |
| `bulkRead` raises `.timeout` | Loop iteration skipped; no event emitted | error |

## Error Handling
- `.timeout` on `bulkRead`: `continue` — loop resumes.
- `.disconnected` on `bulkRead`: `died("Device disconnected")` — yields `.disconnected` event, sets `running=false`.
- Other errors on `bulkRead`: `continue` — loop resumes (transient).

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:271-344 |
| Ingest BC | BC-083 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / type constraint |
