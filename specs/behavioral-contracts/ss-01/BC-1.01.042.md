---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: Sources/occ-connect/main.swift
subsystem: SS-01
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.01.042: occ-connect CLI — StarTech Adapter Connect and Live Event Stream

## Description

`occ-connect` is a command-line driver that discovers a StarTech crash-cart
adapter via `discoverCrashCartDevices()`, connects to the first result using
`StarTechAdapter.connect()`, and prints every `AdapterEvent` to stdout in an
unbuffered stream (`setbuf(stdout, nil)`). It auto-stops after a configurable
timeout (default 20 seconds, overridden by the `OCC_SECONDS` environment
variable) and handles SIGINT for clean manual termination. Only StarTech
adapters are supported; UVC devices are not handled by this CLI.

## Preconditions

- PRE-01: libusb is initializable on the host.
- PRE-02: `StarTechAdapter` is the only adapter type instantiated; UVC paths
  are not taken by this tool.
- PRE-03: stdout is line-buffered or fully buffered by default; `setbuf(stdout, nil)`
  is called at process start to make it unbuffered.
- PRE-04: `OCC_SECONDS`, if set, must be parseable as a `Double`.

## Postconditions

- POST-01: `setbuf(stdout, nil)` is called before any other output, ensuring
  stdout is unbuffered for the lifetime of the process.
- POST-02 (adapter found): A connection banner is printed:
  `"Connecting to <model.name> at bus <busNumber>/<address>…"`.
- POST-03 (adapter found): Each `AdapterEvent` from the stream is printed:
  - `.status(s)`: `"● status: <describe(state)>  kbd=<ok|—> leds=<rawValue> fps=<fps> <bytesPerSecond> B/s"` (bytesPerSecond formatted `"%.0f"`)
  - `.frame(f)`: `"▣ frame <width>×<height>"`
  - `.message(m)`: `"· <m>"`
  - `.mediaChanged(name)`: `"💿 media: <name ?? "ejected">"`
  - `.disconnected(reason)`: `"✕ disconnected: <reason>"`, then the Task returns
- POST-04 (adapter not found): Prints `"No crash-cart adapter found. Plug one in and try again."` to stdout and exits 1.
- POST-05 (USB enumeration failure): Writes `"USB enumeration failed: <error>\n"` to stderr and exits 1.
- POST-06 (connect failure): Writes `"connect failed: <error>\n"` to stderr and exits 1.
- POST-07 (auto-stop): A `Timer` fires after `stopAfter` seconds (default 20.0,
  or `Double(OCC_SECONDS)` if set and parseable). When it fires, stdout receives
  `"\n(auto-stop after <Int(stopAfter)>s)"` and the process exits 0.
- POST-08 (SIGINT): A SIGINT handler prints `"\nStopping…"` and exits 0.
- POST-09: `RunLoop.main.run()` keeps the process alive until an exit path
  is reached; the async `Task` is retained via `_ = task`.

## Invariants

- INV-01: stdout is always made unbuffered (`setbuf(stdout, nil)`) on line 4
  before any output; this ensures events stream live even when stdout is
  redirected to a file or pipe.
- INV-02: The default auto-stop timeout is exactly 20 seconds as the fallback
  when `OCC_SECONDS` is absent or non-parseable.
- INV-03: Only `StarTechAdapter` is instantiated — the tool does not discover
  or connect to UVC devices.
- INV-04: `discoverCrashCartDevices()` (USBEnumeration.swift:64-68) internally
  calls `enumerateUSBDevices()` and filters via `AdapterRegistry.match`; the
  returned list is StarTech-only because `AdapterRegistry.known` currently
  contains only the StarTech model.
- INV-05: `bytesPerSecond` in the status line is formatted with `"%.0f"` (zero
  decimal places, rounds to nearest integer).

## Edge Cases

- EC-001: **No adapter found** — `carts.first` is `nil`; POST-04 applies.
- EC-002: **Multiple adapters** — only the first result (`carts.first`) is used.
- EC-003: **connect() throws** — caught inside the `Task`; POST-06 applies
  (`exit(1)` from inside the task).
- EC-004: **OCC_SECONDS set but not parseable** — `Double($0)` returns `nil`;
  the fallback of `20.0` is used silently.
- EC-005: **OCC_SECONDS = 0** — timer fires immediately (next run-loop tick);
  auto-stop message printed and process exits 0 before printing any events.
- EC-006: **SIGINT before connection** — handler prints `"\nStopping…"` and
  exits 0; no cleanup of partial USB state is performed.
- EC-007: **Stream ends via .disconnected** — the `for await` loop exits; the
  Task completes; because no explicit `exit` is called after the `.disconnected`
  case's `return`, the RunLoop continues running until the auto-stop timer fires
  or SIGINT is received.

## Canonical Test Vectors

### TV-01 — Happy path: adapter found, status and message events received

| Field          | Value                                                                      |
|----------------|----------------------------------------------------------------------------|
| Precondition   | One StarTech adapter at bus=1/addr=3; OCC_SECONDS not set                  |
| Action         | Run `occ-connect`                                                           |
| Expected stdout line 1 | `"Connecting to StarTech NOTECONS02 USB Crash Cart Adapter at bus 1/3…"` |
| Expected: message event | `"· Connected to StarTech NOTECONS02 USB Crash Cart Adapter — initializing…"` |
| Auto-stop      | After 20s: `"\n(auto-stop after 20s)"`, exit 0                             |

### TV-02 — No adapter found

| Field          | Value                                                     |
|----------------|-----------------------------------------------------------|
| Precondition   | No recognized USB devices                                 |
| Expected stdout | `"No crash-cart adapter found. Plug one in and try again."` |
| Exit code      | 1                                                         |

### TV-03 — OCC_SECONDS override

| Field          | Value                                               |
|----------------|-----------------------------------------------------|
| Environment    | `OCC_SECONDS=5`                                     |
| Precondition   | Adapter connected, stream running                   |
| Expected       | Auto-stop fires after 5s: `"\n(auto-stop after 5s)"`, exit 0 |

### TV-04 — USB enumeration failure

| Field          | Value                                                               |
|----------------|---------------------------------------------------------------------|
| Condition      | `discoverCrashCartDevices()` throws `USBError.enumerationFailed(-1)` |
| Expected stderr | `"USB enumeration failed: libusb_get_device_list failed (-1)\n"` |
| Exit code      | 1                                                                   |

### TV-05 — Status event output formatting

| Field          | Value                                                                                     |
|----------------|-------------------------------------------------------------------------------------------|
| Event          | `.status(AdapterStatus(state: .live(1280,1024,60), keyboardOK: true, leds: [], fps: 30, bytesPerSecond: 1234567.8, adjustments: [:]))` |
| Expected stdout | `"● status: live 1280×1024@60Hz  kbd=ok leds=0 fps=30 1234568 B/s"` |

### TV-06 — stdout unbuffered

| Field          | Value                                                                   |
|----------------|-------------------------------------------------------------------------|
| Precondition   | stdout redirected to pipe                                               |
| Action         | Run `occ-connect`; check first bytes arrive before auto-stop            |
| Expected       | Characters appear on the pipe as each `print()` executes, not batched at exit |

## Error Handling

- `enumerateUSBDevices()` / `discoverCrashCartDevices()` errors: stderr + `exit(1)`.
- `adapter.connect()` errors: stderr + `exit(1)` from inside the async Task.
- No explicit cleanup of USB device handles on abnormal exit; libusb cleanup
  is handled by the OS on process exit.

## Traceability

| Field                          | Value                                                                   |
|--------------------------------|-------------------------------------------------------------------------|
| Source file:line               | Sources/occ-connect/main.swift:1-77 (full file)                        |
| setbuf call                    | occ-connect/main.swift:4                                               |
| Auto-stop default              | occ-connect/main.swift:70 (`?? 20`)                                    |
| OCC_SECONDS env var            | occ-connect/main.swift:70                                              |
| SIGINT handler                 | occ-connect/main.swift:64-67                                           |
| discoverCrashCartDevices       | USBEnumeration.swift:64-68                                             |
| Ingest BC                      | N/A (new BC, no prior contract)                                         |
| Capability Anchor Justification | CAP-TBD — capability catalog not yet produced                          |
| Stories                        | (filled by story-writer)                                                |

## Source Evidence

| Field           | Value                                                                 |
|-----------------|-----------------------------------------------------------------------|
| Path            | Sources/occ-connect/main.swift                                        |
| Confidence      | HIGH — complete file read, all control paths covered                  |
| Extraction Date | 2026-06-25                                                            |
| Evidence Type   | Direct source read                                                    |

```swift
// occ-connect/main.swift:4
setbuf(stdout, nil)   // unbuffered so output streams live even when redirected

// occ-connect/main.swift:70-73
let stopAfter = ProcessInfo.processInfo.environment["OCC_SECONDS"].flatMap { Double($0) } ?? 20
Timer.scheduledTimer(withTimeInterval: stopAfter, repeats: false) { _ in
    print("\n(auto-stop after \(Int(stopAfter))s)")
    exit(0)
}
```
