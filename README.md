# OpenCrashCart

[![CI](https://github.com/adamson34/open-crash-cart/actions/workflows/ci.yml/badge.svg)](https://github.com/adamson34/open-crash-cart/actions/workflows/ci.yml)

A native macOS (Apple Silicon) client for USB crash-cart adapters — an open, clean-room
replacement for vendor crash-cart software that only ships as Intel binaries.

OpenCrashCart ("OCC") gives you a headless server's screen, keyboard, and mouse over a USB
crash-cart adapter, plus virtual media (mount an ISO/IMG as a USB drive), paste-text, an
on-screen keyboard, manual video tuning, DDC/EDID presets, relative-mouse mode, snapshots,
and session recording.

## Design

- **Pure Swift + AppKit**, arm64-native. USB via libusb (bundled in the app).
- **Multi-adapter** by design: every device is a backend behind the `CrashCartAdapter`
  protocol, selected by a user-editable **hardware profile**. StarTech NOTECONS02 (Digital
  Multitools "VSP" protocol) is the first built-in profile.
- **Bring your own firmware.** These adapters are FPGA devices that need a vendor bitstream
  uploaded each session. OpenCrashCart ships **none** of it — you point it at the firmware
  file you already own (Settings → Import Firmware). The app contains no vendor code or
  firmware, and is clean-room throughout.

## Build

Requires the Swift toolchain and Homebrew `libusb`.

```sh
brew install libusb
swift build                 # builds OCCKit + the CLIs
./scripts/make-app.sh       # builds dist/OpenCrashCart.app (self-contained, code-signed)
```

CLIs for diagnostics: `swift run occ-probe` (detect adapters),
`swift run occ-connect` (headless boot/handshake).

## Testing

```sh
swift run occ-tests
```

A dependency-free test suite (the CLT toolchain ships no XCTest/swift-testing) covering the
video codec, VSP protocol packing, HID keymap/typing, hardware profiles, and gzip inflate.
It runs in CI (GitHub Actions) on every push and pull request to `main`/`dev`.

## Firmware

OpenCrashCart loads the adapter's FPGA bitstream from, in order: a profile's `firmwareDir`,
`OCC_FIRMWARE_DIR`, the folder set in Settings, OpenCrashCart's own
`~/Library/Application Support/OpenCrashCart/firmware`, then a vendor install as a fallback.
Use **Settings → Import Firmware…** to copy your firmware into OpenCrashCart's own folder;
after that the vendor app is no longer needed.

## Status

Working end-to-end on real hardware: live video, keyboard, mouse, virtual media, paste-text,
video tuning, DDC, relative mouse, and recording.
