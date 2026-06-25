---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-02"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.02.019: Auto-Tune Video (Autophase + IFrame)

## Description

`autoTuneVideo()` triggers the StarTech adapter's analog phase self-calibration
routine by sending two VSP commands in sequence at control priority: an
`autophase` command (`0x70` / `'p'`) immediately followed by a `doIFrame`
command (`0x69` / `'i'`). The device responds asynchronously with an
`autophaseDone` response (`0x50` / `'P'`), which the response loop translates
into an `AdapterEvent.message("Autophase complete.")`. The GUI surface for this
behavior is the "Auto-Tune Video" item in the Video menu, whose action calls
`retuneVideo()` which delegates to `adapter?.autoTuneVideo()`.

## Preconditions

- PRE-01: A `StarTechAdapter` instance exists and `connect()` has been called
  successfully — the command queue (`CommandQueue`) is open and the writer
  thread is running.
- PRE-02: The `running` atomic flag is `true`.
- PRE-03: The adapter's `continuation` (AsyncStream) is non-nil and consuming
  events downstream.

## Postconditions

- POST-01: Exactly two entries are placed into the command queue in FIFO order:
  1. `[0x70]` — `VSProtocol.Command.autophase.rawValue` (`'p'`)
  2. `[0x69]` — `VSProtocol.Command.doIFrame.rawValue` (`'i'`)
  Both are enqueued at `.control` priority.
- POST-02: Both bytes are serialised over bulk endpoint `0x04`
  (`VSProtocol.Endpoint.streamOut`) by the writer thread in the order enqueued.
- POST-03: When the device later sends a response packet whose first byte is
  `0x50` (`VSProtocol.Response.autophaseDone`), `handleResponse` calls
  `emit(.message("Autophase complete."))`, yielding that event on the
  `AsyncStream<AdapterEvent>`.
- POST-04: No `AdapterEvent.status` change is emitted as a direct result of
  `autoTuneVideo()`; a status update may follow if the device sends a
  subsequent `'S'` packet, but that is outside this contract's scope.
- POST-05: The menu item "Auto-Tune Video" (selector `menuAutoTune`) calls
  `retuneVideo()` on `AppController`, which calls `adapter?.autoTuneVideo()`.
  Invoking the menu item while `adapter` is `nil` is a no-op (optional chaining).

## Invariants

- INV-01: The autophase command (`'p'`) is always enqueued before the IFrame
  command (`'i'`); reversing the order would request a new frame before
  calibration, defeating the intent.
- INV-02: Both commands use `.control` priority, ensuring they are drained
  ahead of any pending `.input`-priority HID events.
- INV-03: `autoTuneVideo()` is idempotent with respect to queue state — calling
  it multiple times appends additional pairs without invalidating prior ones.
- INV-04: The `autophaseDone` response handler emits exactly the string literal
  `"Autophase complete."` (note trailing period) with no dynamic substitution.

## Edge Cases

- EC-001: **Adapter not connected** — if `adapter` is `nil` in `AppController`,
  optional chaining (`adapter?.autoTuneVideo()`) silently does nothing; no crash
  or error is raised.
- EC-002: **Queue closed mid-flight** — if `disconnect()` closes the queue
  between the two `enqueue` calls, the second enqueue is dropped. The first byte
  may or may not have been written to the device; the device will not send `'P'`
  in response and no "Autophase complete." message is emitted.
- EC-003: **USB write error** — if the writer thread encounters a
  `USBTransportError.disconnected` while sending `'p'` or `'i'`, it calls
  `died(...)`, which terminates the stream. No "Autophase complete." message is
  emitted.
- EC-004: **Rapid repeated invocation** — calling `autoTuneVideo()` twice in
  rapid succession appends two `'p'+'i'` pairs to the queue. The device will
  execute both in sequence; the response loop emits "Autophase complete." twice.
- EC-005: **No `autophaseDone` response** — the device may not send `'P'` (e.g.
  device firmware hang). The contract makes no guarantee about a timeout;
  "Autophase complete." is never emitted in this case.

## Canonical Test Vectors

### TV-01 — Happy path: two commands enqueued in correct order

| Field          | Value                                      |
|----------------|--------------------------------------------|
| Precondition   | Adapter connected, queue open              |
| Action         | Call `adapter.autoTuneVideo()`             |
| Expected queue | `[0x70]` at index 0, `[0x69]` at index 1, both priority `.control` |
| Expected bytes on wire | `0x70` then `0x69` via endpoint `0x04` |

### TV-02 — Happy path: `autophaseDone` response yields message event

| Field          | Value                                                        |
|----------------|--------------------------------------------------------------|
| Precondition   | Response loop running; inject response packet `[0x50]`       |
| Action         | `handleResponse(command: 0x50, args: [])`                   |
| Expected event | `AdapterEvent.message("Autophase complete.")`                |

### TV-03 — Edge: `adapter` nil in AppController

| Field          | Value                                      |
|----------------|--------------------------------------------|
| Precondition   | `AppController.adapter == nil`             |
| Action         | Invoke `menuAutoTune` menu item            |
| Expected       | No crash; no queue mutation; no event emitted |

### TV-04 — Edge: queue closed before second enqueue

| Field          | Value                                                         |
|----------------|---------------------------------------------------------------|
| Precondition   | Queue is closed (simulated) after first enqueue               |
| Action         | Call `adapter.autoTuneVideo()`                                |
| Expected       | `[0x70]` enqueued (or attempted); `[0x69]` silently dropped; no event |

## Error Handling

- No explicit error is thrown by `autoTuneVideo()` itself; it is a synchronous
  fire-and-forget method.
- USB transport errors are handled by the writer thread, not by this method.
- The absence of a `'P'` response is not surfaced as an error to the caller.

## Traceability

| Field                          | Value                                                                   |
|--------------------------------|-------------------------------------------------------------------------|
| Source file:line               | StarTechAdapter.swift:86-89 (`autoTuneVideo`), :331-332 (`autophaseDone` case) |
| VSP command bytes              | `autophase = 0x70 ('p')` — VSProtocol.swift:27; `doIFrame = 0x69 ('i')` — VSProtocol.swift:33 |
| VSP response byte              | `autophaseDone = 0x50 ('P')` — VSProtocol.swift:53 |
| UI entry point                 | AppController.swift:442 (`menuAutoTune`), :591 (`retuneVideo`) |
| Ingest BC                      | N/A (new BC, no prior contract)                                         |
| Capability Anchor Justification | CAP-TBD — capability catalog not yet produced                          |
| Stories                        | (filled by story-writer)                                                |

## Source Evidence

| Field           | Value                                                                 |
|-----------------|-----------------------------------------------------------------------|
| Path            | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift                |
| Confidence      | HIGH — implementation is direct, single-method, two lines             |
| Extraction Date | 2026-06-25                                                            |
| Evidence Type   | Direct source read                                                    |

```swift
// StarTechAdapter.swift:86-89
public func autoTuneVideo() {
    queue.enqueue(VSPack.command(.autophase), priority: .control)
    queue.enqueue(VSPack.command(.doIFrame), priority: .control)
}

// StarTechAdapter.swift:331-332
case .autophaseDone:
    emit(.message("Autophase complete."))
```

```swift
// VSProtocol.swift:27,33,53
case autophase      = 0x70 // 'p'
case doIFrame       = 0x69 // 'i'
case autophaseDone  = 0x50 // 'P'
```

```swift
// AppController.swift:442,591
@objc private func menuAutoTune()    { retuneVideo() }
func retuneVideo()            { adapter?.autoTuneVideo() }
```
