---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ-probe/main.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.01.041: occ-probe CLI — USB Device Enumeration and Adapter Identification

## Description

`occ-probe` is a command-line diagnostic tool that enumerates all USB devices
on the current bus via `enumerateUSBDevices()`, cross-references each device
against `AdapterRegistry.known`, and prints a structured report to stdout.
For each recognized crash-cart adapter it prints VID/PID, bus number, device
address, product string, serial number, and a human-readable link-speed
classification that warns on Full-Speed connections. The tool exits 0 in all
cases except a libusb enumeration failure (exit 1 to stderr).

## Preconditions

- PRE-01: The host machine has libusb available and initializable
  (`libusb_init` returns 0).
- PRE-02: `AdapterRegistry.known` contains at least the StarTech NOTECONS02
  model (VID `0x152A`, PIDs `[0x8460, 0x8463]`).
- PRE-03: No command-line arguments are required; the tool takes none.

## Postconditions

- POST-01: The tool always prints the header line
  `"occ-probe — scanning USB for crash-cart adapters"` followed by a
  56-character `"─"` separator to stdout before any device output.
- POST-02 (no adapters found): If `carts` is empty, stdout contains:
  - `"No known crash-cart adapter found (<N> USB devices seen)."`
  - A blank line, then `"Supported models:"`.
  - For each model in `AdapterRegistry.known`: `"  • <name>"` then
    `"      VID <hex(vid)>  PID <pid1>/<pid2>"`.
  - A blank line, then `"Tip: plug in the adapter and run \`swift run occ-probe\` again."`.
  - Exit code 0.
- POST-03 (adapters found): For each recognized adapter, stdout contains a
  block with:
  - `"  ✓ <model.name>"`
  - `"      VID/PID : <hex(vid)>:<hex(pid)>"`
  - `"      bus/addr: <busNumber>/<address>"`
  - `"      product : <product ?? "—">"`
  - `"      serial  : <serial ?? "—">"`
  - `"      usb     : High-Speed+ (480 Mbps+, good)"` if `isHighSpeedOrBetter`,
    otherwise `"      usb     : Full-Speed only — video will be slow"`.
  - `"      backend : <model.id>"`
  - A trailing blank line.
  - Exit code 0.
- POST-04 (enumeration failure): Writes
  `"USB enumeration failed: <error>\n"` to stderr and exits with code 1.
- POST-05: VID and PID values are formatted as `0xXXXX` (four uppercase hex
  digits with `0x` prefix) using `String(format: "0x%04X", v)`.

## Invariants

- INV-01: The header and separator are always printed before any device output
  or "no adapters" message, even when zero USB devices are visible.
- INV-02: `isHighSpeedOrBetter` is derived from `libusb_get_device_speed(dev) >= 3`
  (USBEnumeration.swift:38); speeds 0–2 (UNKNOWN, LOW, FULL) produce the slow
  warning; speeds 3+ (HIGH, SUPER, SUPER_PLUS) produce the "good" label.
- INV-03: String descriptors (product, serial) are best-effort; failure to open
  a device for descriptor reads is non-fatal. A missing descriptor prints `"—"`.
- INV-04: The tool makes no writes to any USB device; it is strictly read-only
  (enumerates and optionally opens handles for descriptor reads only).

## Edge Cases

- EC-001: **libusb_init fails** — `enumerateUSBDevices()` throws
  `USBError.initFailed(rc)`. The error is written to stderr and the tool exits 1.
- EC-002: **libusb_get_device_list fails** — throws `USBError.enumerationFailed(rc)`.
  Same stderr + exit-1 path.
- EC-003: **No USB devices at all** — `devices` is empty, `carts` is empty;
  POST-02 applies with `N = 0`.
- EC-004: **Multiple recognized adapters** — all matched adapters are printed;
  the header `"Found <count> crash-cart adapter(s):"` uses the plural count.
- EC-005: **Device held by another driver** — `libusb_open` for descriptor reads
  fails; `manufacturer`, `product`, `serial` remain `nil`; they print as `"—"`.
- EC-006: **Full-Speed adapter connected** — `isHighSpeedOrBetter` is `false`
  (speed < 3); the "usb" line reads `"Full-Speed only — video will be slow"`.
- EC-007: **Unknown VID/PID** — device is enumerated by libusb but does not
  appear in `AdapterRegistry.known`; it is excluded from the `carts` array and
  does not appear in the printed output.

## Canonical Test Vectors

### TV-01 — Happy path: one recognized High-Speed adapter

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| USB bus state  | One device: VID=0x152A, PID=0x8460, bus=1, addr=3, product="StarTech NOTECONS02 USB Crash Cart Adapter", serial="SN001", speed=HIGH (3) |
| Expected stdout (partial) | Header, separator, `"Found 1 crash-cart adapter(s):"`, adapter block with all fields, `"      usb     : High-Speed+ (480 Mbps+, good)"` |
| Exit code      | 0                                                                  |

### TV-02 — No recognized adapters

| Field          | Value                                                |
|----------------|------------------------------------------------------|
| USB bus state  | 3 devices, none matching known VID/PID               |
| Expected stdout | Header, separator, `"No known crash-cart adapter found (3 USB devices seen)."`, supported-models block |
| Exit code      | 0                                                    |

### TV-03 — Full-Speed adapter triggers slow warning

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| USB bus state  | One device: VID=0x152A, PID=0x8460, speed=FULL (2)                |
| Expected stdout | Adapter block contains `"      usb     : Full-Speed only — video will be slow"` |
| Exit code      | 0                                                                  |

### TV-04 — libusb enumeration failure

| Field          | Value                                                |
|----------------|------------------------------------------------------|
| Condition      | `enumerateUSBDevices()` throws `USBError.enumerationFailed(-3)` |
| Expected stderr | `"USB enumeration failed: libusb_get_device_list failed (-3)\n"` |
| Expected stdout | (none)                                              |
| Exit code      | 1                                                    |

### TV-05 — Missing string descriptors

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| USB bus state  | One recognized device; `libusb_open` fails; `product=nil, serial=nil` |
| Expected stdout | Adapter block contains `"      product : —"` and `"      serial  : —"` |
| Exit code      | 0                                                                  |

## Error Handling

- `USBError.initFailed` and `USBError.enumerationFailed` are caught at the
  top level; message is written to `FileHandle.standardError` and `exit(1)` is
  called.
- All other errors (descriptor read failures) are non-fatal and result in `nil`
  string fields, displayed as `"—"`.

## Traceability

| Field                          | Value                                                                   |
|--------------------------------|-------------------------------------------------------------------------|
| Source file:line               | Sources/occ-probe/main.swift:1-47 (full file)                          |
| USB enumeration                | USBEnumeration.swift:18-61 (`enumerateUSBDevices`)                     |
| Speed check                    | USBEnumeration.swift:38 (`libusb_get_device_speed(dev) >= 3`)          |
| Registry lookup                | AdapterRegistry.swift:29-32 (`match(vendorID:productID:)`)             |
| Ingest BC                      | N/A (new BC, no prior contract)                                         |
| Capability Anchor Justification | CAP-TBD — capability catalog not yet produced                          |
| Stories                        | (filled by story-writer)                                                |

## Source Evidence

| Field           | Value                                                                 |
|-----------------|-----------------------------------------------------------------------|
| Path            | Sources/occ-probe/main.swift                                          |
| Confidence      | HIGH — complete file read, all output literals extracted verbatim     |
| Extraction Date | 2026-06-25                                                            |
| Evidence Type   | Direct source read                                                    |

```swift
// occ-probe/main.swift:41-44 (link-speed string)
let speed = d.isHighSpeedOrBetter
    ? "High-Speed+ (480 Mbps+, good)"
    : "Full-Speed only — video will be slow"
print("      usb     : \(speed)")

// USBEnumeration.swift:38 (speed threshold)
let highSpeedOrBetter = libusb_get_device_speed(dev) >= 3
```
