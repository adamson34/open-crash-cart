---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift
subsystem: SS-01
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.01.043: Link-Speed Warning on Non-High-Speed USB Connection

## Description

When `StarTechAdapter.connect()` opens the USB device and claims the interface,
it immediately checks whether the connection is High-Speed or better. If
`dev.isHighSpeedOrBetter` is `false` (i.e. `libusb_get_device_speed` returned a
value less than 3 — UNKNOWN, LOW, or FULL speed), it emits
`AdapterEvent.message("Warning: not a High-Speed USB link — video will be slow.")`
onto the `AsyncStream<AdapterEvent>` before starting any worker threads. This
satisfies the observability requirement that users receive an actionable warning
when video throughput will be degraded.

## Preconditions

- PRE-01: `connect()` has been called on a `StarTechAdapter` instance.
- PRE-02: `USBDevice.open(matching:)` and `claimInterface` have succeeded
  (no exception thrown before the speed check).
- PRE-03: The `AsyncStream` continuation has been created and the `continuation`
  property is non-nil at the point of the check.

## Postconditions

- POST-01 (speed < 3 / Full-Speed or slower): `emit(.message("Warning: not a High-Speed USB link — video will be slow."))` is called, yielding that event to consumers before any worker threads start.
- POST-02 (speed >= 3 / High-Speed or better): No link-speed warning is emitted;
  execution proceeds to `startThread` calls without any message for the speed check.
- POST-03: The speed check does not throw and does not prevent the adapter from
  proceeding to start its worker threads and boot sequence regardless of result.
- POST-04: In `occ-probe`, the same `isHighSpeedOrBetter` field (derived from
  the same libusb threshold) drives the output string `"Full-Speed only — video will be slow"` for the probe CLI (occ-probe/main.swift:41-44). The threshold and
  warning intent are consistent between the two surfaces.

## Invariants

- INV-01: `isHighSpeedOrBetter` is set at USB enumeration time from
  `libusb_get_device_speed(dev) >= 3` (USBEnumeration.swift:38). Speed codes:
  UNKNOWN=0, LOW=1, FULL=2, HIGH=3, SUPER=4, SUPER_PLUS=5. Only codes 3–5
  suppress the warning.
- INV-02: The warning string is a compile-time literal:
  `"Warning: not a High-Speed USB link — video will be slow."` — exact
  spelling including the em-dash and trailing period must be preserved.
- INV-03: The speed check occurs synchronously in `connect()` (lines 60-62),
  after the `AsyncStream` continuation is set up (line 54-57) and the "Connected"
  message is emitted (line 59), but before any worker threads are started
  (line 64 onwards).
- INV-04: The check is a read-only property access; it has no side effects on
  the USB device state.

## Edge Cases

- EC-001: **High-Speed adapter** (speed=3) — `isHighSpeedOrBetter` is `true`;
  no warning emitted; consumer sees only the "Connected…" message followed by
  events from the boot sequence.
- EC-002: **Full-Speed adapter** (speed=2) — `isHighSpeedOrBetter` is `false`;
  warning is emitted as the second event on the stream after the "Connected…"
  message.
- EC-003: **Unknown speed** (speed=0) — `isHighSpeedOrBetter` is `false`;
  warning is emitted. This can happen on VMs or with some hub configurations.
- EC-004: **Low-Speed adapter** (speed=1) — `isHighSpeedOrBetter` is `false`;
  warning is emitted. Practically impossible for a crash-cart adapter but the
  code path is identical.
- EC-005: **SuperSpeed / USB 3** (speed=4 or 5) — `isHighSpeedOrBetter` is
  `true`; no warning.
- EC-006: **Warning appears in occ-connect stdout** — when `occ-connect` runs
  against a Full-Speed adapter, the stream consumer prints the message as
  `"· Warning: not a High-Speed USB link — video will be slow."`.
- EC-007: **Warning appears in AppController status bar** — in the GUI app,
  the `handle(.message(...))` branch calls `statusBar.setMessage(message)`;
  the warning is surfaced in the status bar.

## Canonical Test Vectors

### TV-01 — Happy path: High-Speed adapter, no warning

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| Precondition   | `dev.isHighSpeedOrBetter == true` (libusb speed=3)                 |
| Action         | `adapter.connect()`                                                |
| Expected events (ordered) | 1. `AdapterEvent.message("Connected to StarTech NOTECONS02 USB Crash Cart Adapter — initializing…")` |
| Not expected   | Any `AdapterEvent.message` containing "High-Speed"                 |

### TV-02 — Full-Speed adapter emits warning

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| Precondition   | `dev.isHighSpeedOrBetter == false` (libusb speed=2)                |
| Action         | `adapter.connect()`                                                |
| Expected events (ordered) | 1. `AdapterEvent.message("Connected to StarTech NOTECONS02 USB Crash Cart Adapter — initializing…")`<br>2. `AdapterEvent.message("Warning: not a High-Speed USB link — video will be slow.")` |

### TV-03 — Unknown speed emits warning

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| Precondition   | `dev.isHighSpeedOrBetter == false` (libusb speed=0)                |
| Action         | `adapter.connect()`                                                |
| Expected events | Same as TV-02: connected message then warning message              |

### TV-04 — Warning precedes worker thread startup

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| Precondition   | `dev.isHighSpeedOrBetter == false`                                 |
| Action         | `adapter.connect()` — observe event ordering                        |
| Expected       | Warning message is yielded before any `.status` or `.frame` events, since `emit` is called on line 61, before `startThread` calls begin on line 64 |

### TV-05 — SuperSpeed adapter, no warning

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| Precondition   | `dev.isHighSpeedOrBetter == true` (libusb speed=5, SuperSpeed+)    |
| Action         | `adapter.connect()`                                                |
| Not expected   | Any message containing "video will be slow"                        |

## Error Handling

- The speed check itself cannot fail (it is a boolean property read).
- If `USBDevice.open` throws before the speed check is reached, `connect()` rethrows and no messages are emitted at all (the continuation has not been set up yet when the throw occurs — see line 50 vs line 54).

## Traceability

| Field                          | Value                                                                   |
|--------------------------------|-------------------------------------------------------------------------|
| Source file:line               | StarTechAdapter.swift:59-62 (speed check and conditional emit)         |
| Speed property origin          | USBEnumeration.swift:38 (`libusb_get_device_speed(dev) >= 3`)          |
| occ-probe parallel surface     | occ-probe/main.swift:41-44                                              |
| NFR reference                  | NFR-OBS-05 (link-speed observability requirement)                       |
| Ingest BC                      | N/A (new BC, no prior contract)                                         |
| Capability Anchor Justification | CAP-TBD — capability catalog not yet produced                          |
| Stories                        | (filled by story-writer)                                                |

## Source Evidence

| Field           | Value                                                                 |
|-----------------|-----------------------------------------------------------------------|
| Path            | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift                |
| Confidence      | HIGH — single conditional block, exact string literals extracted       |
| Extraction Date | 2026-06-25                                                            |
| Evidence Type   | Direct source read                                                    |

```swift
// StarTechAdapter.swift:59-62
emit(.message("Connected to \(Self.model.name) — initializing…"))
if !dev.isHighSpeedOrBetter {
    emit(.message("Warning: not a High-Speed USB link — video will be slow."))
}
```

```swift
// USBEnumeration.swift:37-38
// libusb_speed: UNKNOWN=0, LOW=1, FULL=2, HIGH=3, SUPER=4, SUPER_PLUS=5.
let highSpeedOrBetter = libusb_get_device_speed(dev) >= 3
```
