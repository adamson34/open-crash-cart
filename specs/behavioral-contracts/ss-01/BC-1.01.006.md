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
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.006: StarTech Disconnect and died() Teardown

## Description
There are two teardown paths: `disconnect()` (caller-initiated, async) and `died()` (device-initiated, from any I/O thread). Both paths set `running` to false, close the media, close the command queue, close the USB device, yield a `.disconnected` event on the stream, finish the stream, and nil out the continuation. `died()` additionally guards against double-invocation using `running.get()`.

## Preconditions
1. For `disconnect()`: called by an `async` context (AppController `Task`).
2. For `died()`: called from a writer or response thread when a `.disconnected` USB error is detected.
3. `running` may be true or false at the point of call.

## Postconditions
1. `running.set(false)` is called (both paths).
2. `closeMedia()` is called (both paths), releasing any mounted virtual media.
3. `queue.close()` is called (both paths), unblocking any `take()` waiter.
4. `device?.close()` is called (both paths), releasing the libusb handle and interface.
5. `continuation?.yield(.disconnected(reason:))` is called with an appropriate reason string.
6. `continuation?.finish()` is called.
7. `continuation = nil` prevents future emissions.
8. `died()` returns without action if `running.get()` is already false at entry (double-died guard).

## Invariants
1. After teardown completes, no further `.frame`, `.status`, or `.message` events can be emitted (continuation is nil).
2. `closeMedia()` is called exactly once regardless of which teardown path executes.
3. `died()` is idempotent: calling it twice produces exactly one `.disconnected` event.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `disconnect()` called with no media mounted | `closeMedia()` is a no-op; no crash |
| EC-002 | `disconnect()` called while `running` is already false | `running.set(false)` is idempotent; subsequent close calls are safe |
| EC-003 | `died()` called twice concurrently | Second call returns immediately after `running.get() == false` check |
| EC-004 | Writer thread receives `.disconnected`; response thread also receives `.disconnected` | Only the first `died()` to run sets `running=false`; second is a no-op |
| EC-005 | `continuation` is nil at teardown (stream already finished) | Optional chaining `continuation?.yield(…)` no-ops; no crash |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `disconnect()` called on connected adapter | `.disconnected(reason: "Closed by user")` event, stream finishes | happy-path |
| Write thread gets `.disconnected` USB error | `died("USB write: device disconnected")` → `.disconnected(reason:…)` event | error path |
| Response thread gets `.disconnected` USB error | `died("Device disconnected")` → `.disconnected(reason:…)` event | error path |

## Error Handling
- No errors thrown from either teardown path.
- USB close failures are swallowed by optional-chaining (`device?.close()` — `USBDevice.close()` itself is non-throwing).

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:203-211, 417-424 |
| Ingest BC | BC-086 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
