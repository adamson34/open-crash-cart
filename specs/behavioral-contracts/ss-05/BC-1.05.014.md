---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/UVC/CH9329.swift, Sources/OCCKit/Adapters/UVC/UVCAdapter.swift"
subsystem: "SS-05"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.05.014: CH9329 Serial Port Discovery and Environment Override

## Description

`discoverCH9329Ports()` scans `/dev` for serial port devices whose names match CH340/CH343 USB-serial chip enumeration patterns. `UVCAdapter.connect()` uses the discovered port list (or an environment variable override) and the `OCC_CH9329_BAUD` environment variable with a default baud rate of 9600.

## Preconditions

1. The system `/dev` directory is readable.
2. Optionally, `OCC_CH9329_PORT` and/or `OCC_CH9329_BAUD` are set in the process environment.

## Postconditions

1. `discoverCH9329Ports()` returns `/dev/` prefixed paths sorted alphabetically, filtered to names matching:
   - `cu.usbserial*`
   - `cu.wchusbserial*`
   - `cu.usbmodem*`
2. If `OCC_CH9329_PORT` is set, that path is used directly (overrides discovery).
3. If `OCC_CH9329_PORT` is not set, `discoverCH9329Ports().first` is used (first alphabetically sorted match).
4. If no port is found via either method, no CH9329 is attached and `hasHID = false`.
5. The baud rate is `Int(env["OCC_CH9329_BAUD"] ?? "") ?? 9600` — default 9600 if variable absent or non-integer.
6. On successful `CH9329(path:baud:)` init, `hasHID = true` and the adapter logs "full KVM via CH9329 on <path>".
7. On failure, the adapter logs "view-only (no CH9329 HID controller found)".

## Invariants

1. Port paths are always `/dev/<name>` format.
2. The sorted order is lexicographic; `cu.usbserial-1` sorts before `cu.usbserial-2`.
3. `OCC_CH9329_PORT` completely bypasses filesystem discovery when set.
4. The default baud rate of 9600 matches the CH9329 factory default.

## Edge Cases

### EC-001: No matching devices in /dev
`discoverCH9329Ports()` returns `[]`. `UVCAdapter` enters view-only mode.

### EC-002: Multiple CH9329 candidates
All matching paths are returned; `UVCAdapter.connect()` tries only the first. Remaining candidates are unused.

### EC-003: OCC_CH9329_PORT set to non-existent path
`CH9329(path:baud:)` returns `nil` (SerialPort init fails), `hasHID = false`.

### EC-004: OCC_CH9329_BAUD set to non-integer
`Int(env["OCC_CH9329_BAUD"] ?? "")` returns `nil`, defaulting to 9600.

### EC-005: /dev unreadable (permission error)
`try? FileManager.default.contentsOfDirectory(atPath: "/dev")` returns `nil` → `[]` returned, view-only mode.

## Canonical Test Vectors

| OCC_CH9329_PORT | /dev contents | Expected port used | hasHID |
|----------------|--------------|-------------------|--------|
| not set | `cu.usbserial-1430` | `/dev/cu.usbserial-1430` | true (if CH9329 init succeeds) |
| not set | (empty) | — | false |
| `/dev/cu.usbserial-custom` | anything | `/dev/cu.usbserial-custom` | true (if CH9329 init succeeds) |
| not set | `cu.wchusbserial1420, cu.usbserial-1430` | `/dev/cu.usbserial-1430` (sorted first) | true |

## Error Handling

`discoverCH9329Ports()` never throws; errors from `contentsOfDirectory` are swallowed via `try?`. CH9329 init failure is handled by the `if let` guard in `UVCAdapter.connect()`.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/CH9329.swift:60-66`, `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:73-82` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-044 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/CH9329.swift:60-66`; `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:73-82` |
| Confidence | MEDIUM — source code, no unit test |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
