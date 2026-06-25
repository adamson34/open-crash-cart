---
document_type: prd-supplement-error-taxonomy
level: L3
status: draft
traces_to: prd.md
---

# Error Taxonomy — OpenCrashCart

All errors are typed `enum: Error, CustomStringConvertible`; libusb/zlib variants carry the raw
`Int32` return code. Diagnostics reach the user as `AdapterEvent.message`/`.disconnected` (no central
logger). Principle: **fail-closed on device loss, degrade gracefully on local resource failure.**

## Error domains

| Domain enum | Source | Cases | User-facing? |
|-------------|--------|-------|--------------|
| `USBTransportError` | USBDevice.swift | contextInitFailed, deviceNotFound, openFailed, claimFailed, transferFailed, timeout, disconnected | partial (via .message/.disconnected) |
| `USBError` | USBEnumeration.swift | contextInitFailed, enumerationFailed | internal (best-effort, non-fatal) |
| `GzipError` | Gunzip.swift | initFailed(rc), inflateFailed(rc) | via "FPGA load skipped" message |
| `UVCError` | UVCAdapter.swift | cameraAccessDenied, deviceNotFound, configurationFailed | yes (actionable, e.g. permissions) |
| `FirmwareError` | StarTechFirmware.swift | notFound(searched:[...]) | yes (lists every searched path) |

## Categories, severity, recovery

| Category | Examples | Severity | Recovery strategy |
|----------|----------|----------|-------------------|
| **Transient transport** | `timeout` (-7) on a bulk read/write | low | `continue` the loop; reader re-checks `running` every 2s |
| **Fatal transport** | `disconnected` (-4, NO_DEVICE) | high | `died()` → clean teardown → `.disconnected` event → 2s rescan re-discovers |
| **Acquisition** | open/claim failed (device held by another driver) | medium | non-fatal during enumeration (best-effort string read); fatal during connect → reset session |
| **Firmware** | `notFound`, gunzip failure | medium | degrade: emit "FPGA load skipped: …" and continue boot (not aborting) |
| **Capture/permission** | `cameraAccessDenied` | medium | surface System Settings guidance; UVC view stays blocked until granted |
| **Local resource** | VirtualMedia `init?` nil, SerialPort/CH9329 `init?` nil | low | fail-closed via optional; caller degrades (view-only / no media) |

## User-facing vs internal messages
- **User-facing** (shown in status bar / CLI): connect banners, FPGA upload result, autophase done,
  firmware-not-found (with searched paths), camera-permission guidance, "Disconnected: <reason> —
  rescanning…", link-speed warning, mount/eject text.
- **Internal** (swallowed / logged via message only): transient bulk timeouts, best-effort USB
  descriptor read failures, JSON write failures (`try?`).

## v1.1.0 error-handling changes (P1 fixes)
- **BC-1.03.012** — OCR: the currently-swallowed `VNImageRequestHandler.perform` error (OCR.swift,
  `try?`) MUST propagate to the completion and clear the stuck "Reading text…" status with an error
  message.
- **BC-1.04.009 / P2.2** — `ProfileStore.writeToDisk` and SettingsWindow firmware-import currently
  swallow write/copy errors with `try?`; a future hardening item is to surface partial-copy failures
  (tracked, not in v1.1.0 scope unless capacity allows).

## Known gaps (from ingest NFR catalog)
- No retry/backoff for transient bulk-write failures (writer just `continue`s).
- No reconnect cap/backoff (indefinite 2s rescan).
- CH9329 serial is write-only → no serial-link health/ack signal (unlike the StarTech heartbeat).
