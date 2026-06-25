---
document_type: behavioral-contract
level: L3
id: BC-1.05.015
title: UVC Adapter View-Only Mode Without CH9329
subsystem: SS-05
capability: CAP-TBD
origin: brownfield
extracted_from: Sources/OCCKit/Adapters/UVC/UVCAdapter.swift
introduced: v1.0.0
lifecycle_status: active
phase: 1a
traces_to: domain-spec-L2.md
---

# BC-1.05.015: UVC Adapter View-Only Mode Without CH9329

## Description

`UVCAdapter` operates in two modes: full KVM (CH9329 present) and view-only (CH9329 absent). When no CH9329 serial port is found or initialised, all keyboard and mouse input is silently dropped. Video frames are always delivered as BGRA. The `keyboardOK` field of the status event reflects whether HID control is available.

## Preconditions

1. `UVCAdapter.connect()` has been called and completed.
2. No CH9329 was found or was successfully initialised (`hasHID == false`).

## Postconditions

1. `UVCAdapter.canDrive(_:)` always returns `false` (it is not libusb-driven; static contract).
2. `send(key:)` is a no-op when `hasHID == false`; no frame is sent to any serial port.
3. `send(mouse:)` is a no-op when `hasHID == false`.
4. Video frames are captured by AVFoundation and delivered via the `AsyncStream<AdapterEvent>` as `.frame(VideoFrame(...))` events.
5. `VideoFrame.pixels` are in BGRA format (32-bit, 4 bytes/pixel, `kCVPixelFormatType_32BGRA`).
6. When frame dimensions change, a `.status(AdapterStatus)` event is emitted with `status.keyboardOK = hasHID`.
7. In view-only mode, `status.keyboardOK == false`.

## Invariants

1. `canDrive` is always `false` regardless of CH9329 presence; UVC adapters are not claimed via libusb.
2. `hasHID` is set once at connect time and only reset to `false` on disconnect.
3. BGRA format is unconditionally configured via `output.videoSettings`; it does not depend on CH9329 presence.

## Edge Cases

### EC-001: connect() called without camera permission
`AVCaptureDevice.requestAccess(for:)` returns `false` → throws `UVCError.cameraAccessDenied`. No frames delivered.

### EC-002: Device not found
No `AVCaptureDevice` matches `deviceID` → throws `UVCError.deviceNotFound`.

### EC-003: Session setup failure
`canAddInput` or `canAddOutput` returns `false` → throws `UVCError.sessionSetupFailed`.

### EC-004: CH9329 connected mid-session
`UVCAdapter` does not detect CH9329 hot-plug after `connect()` returns. The user must reconnect via the menu.

### EC-005: disconnect() while capturing
`session.stopRunning()` is called on `captureQueue`; `.disconnected(reason: "Closed")` is yielded to the stream.

## Canonical Test Vectors

| Scenario | hasHID | keyboardOK in status | send(key:) behaviour |
|---------|--------|---------------------|---------------------|
| No CH9329 found | false | false | no-op |
| CH9329 found and init OK | true | true | forwarded to CH9329 |
| send(key:) with hasHID=false | false | — | returns immediately, no serial write |

## Error Handling

Three error cases are typed as `UVCError` and thrown from `connect()`. All are non-recoverable for the current connection attempt; the caller must call `connect()` again after rectifying the condition.

## Traceability

| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:13-14, 61-82, 91-118, 123-126` |
| Test file:line | None — MEDIUM confidence |
| Ingest BC | BC-045 (opencrashcart-pass-3-behavioral-contracts.md) |
| Stories | TBD |
| L2 Invariants | TBD |
| Capability Anchor Justification | CAP-TBD — capability list not yet finalised for SS-05 |

## Source Evidence

| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/UVC/UVCAdapter.swift:13-14, 61-82, 91-118, 123-126` |
| Confidence | MEDIUM — source code, no unit test for view-only mode |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code |
