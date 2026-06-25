# Pass 0: Inventory — OpenCrashCart

Native macOS (Apple Silicon) USB crash-cart KVM client. Swift Package Manager project
(`swift-tools-version: 6.0`, `platforms: .macOS(.v13)`). Core library `OCCKit`, AppKit app
`occ`, three CLI targets (`occ-probe`, `occ-connect`, `occ-tests`), two C system-library
shims (`Clibusb`, `Czlib`). All metrics measured with `find … -exec wc -l {} +`.

## Tech Stack
- Swift 6.0 (strict concurrency; `Sendable`/`@unchecked Sendable` throughout), SPM (no Xcode project), macOS 13+ (UVC path needs 14+).
- Tests: hand-rolled dependency-free `Harness` run as `occ-tests` (XCTest/swift-testing avoided for CLT/CI).
- CI: GitHub Actions on macos-15 (build + `occ-tests`). Packaging: `scripts/make-app.sh` (bundles libusb, ad-hoc signs).

### External / system dependencies
| Dependency | Kind | Used for |
|---|---|---|
| libusb-1.0 | C via Clibusb | StarTech USB I/O: enumerate, open/claim iface 0, bulk EP 0x82/0x83/0x04. Header hardcoded `/opt/homebrew/...`. |
| zlib | C via Czlib | `gunzip()` inflates the gzip FPGA bitstream. |
| AppKit | Apple | Entire `occ` UI. |
| AVFoundation | Apple | UVC capture (`UVCAdapter`/`UVCDiscovery`) + recording (`Recorder` AVAssetWriter→H.264). |
| Vision | Apple | `OCR.swift` text recognition (correction off). |
| CoreImage/CoreVideo/QuartzCore/CoreGraphics | Apple | Image enhancement, pixel buffers, timestamps. |
| UniformTypeIdentifiers | Apple | File types for media mount + profile import. |
| POSIX termios | libc | `SerialPort` → CH9329 HID for UVC dongles. |

> Vendor FPGA firmware is NOT bundled — `StarTechFirmware` locates the user's vendor install at runtime.

## File Tree (Sources/)
```
OCCKit/
  Adapter/        CrashCartAdapter.swift Types.swift AdapterRegistry.swift
                  AdapterFactory.swift HardwareProfile.swift ProfileStore.swift
  Adapters/StarTech/  StarTechAdapter.swift VSProtocol.swift StarTechTileDecoder.swift
                      StarTechVideoDecoder.swift StarTechFirmware.swift StarTechSupport.swift VirtualMedia.swift
  Adapters/UVC/       UVCAdapter.swift UVCDiscovery.swift CH9329.swift SerialPort.swift
  Input/   HIDKeymap.swift HIDTyping.swift
  USB/     USBEnumeration.swift USBDevice.swift
  Util/    Gunzip.swift
occ/  main.swift AppController.swift VideoView.swift SettingsWindow.swift ToolbarStrip.swift
      KeyboardPanel.swift VideoAdjustPanel.swift ImageEnhancePanel.swift StatusBar.swift
      PlaceholderView.swift Recorder.swift OCR.swift Theme.swift
occ-probe/main.swift  occ-connect/main.swift
occ-tests/ main.swift TestHarness.swift ProtocolTests.swift TileDecoderTests.swift
           GunzipTests.swift KeymapTests.swift TypingTests.swift ProfileTests.swift
Clibusb/module.modulemap  Czlib/module.modulemap Czlib/shim.h
```
docs/PROTOCOL.md (121), docs/CODEC.md (73), packaging/{Info.plist,makeicon.swift}, scripts/make-app.sh, .github/workflows/ci.yml.

## Target dependency graph
`Clibusb`,`Czlib` ← `OCCKit` ← {`occ`,`occ-probe`,`occ-connect`,`occ-tests`}. No third-party SPM deps; only system libs + Apple frameworks. All products inherit `-L/opt/homebrew/lib`.

### Internal layering (from imports)
- `Adapter/` abstractions (Foundation only) define `CrashCartAdapter`.
- `Adapters/StarTech/` → USB/, Util/Gunzip, Input/, Adapter/.
- `Adapters/UVC/` → AVFoundation + SerialPort/CH9329; conforms to CrashCartAdapter.
- `AdapterFactory.makeAdapter` wires only `"dmtz-vsp"` → StarTech; UVC is reached elsewhere (app menu), NOT via the factory.

## Metrics (measured)
| Area | Files | LOC |
|---|---:|---:|
| OCCKit/Adapter | 6 | 438 |
| OCCKit/Adapters/StarTech | 7 | 1029 |
| OCCKit/Adapters/UVC | 4 | 311 |
| OCCKit/Input | 2 | 99 |
| OCCKit/USB | 2 | 208 |
| OCCKit/Util | 1 | 49 |
| **OCCKit total** | **22** | **2134** |
| occ (app) | 13 | 2285 |
| occ-probe | 1 | 47 |
| occ-connect | 1 | 77 |
| occ-tests | 8 | 221 |
| **Sources total** | **45** | **4764** |

Largest: AppController.swift (666), StarTechAdapter.swift (435), VideoView.swift (332),
SettingsWindow.swift (297), StarTechTileDecoder.swift (203), ToolbarStrip.swift (198),
UVCAdapter.swift (180), KeyboardPanel.swift (173).

## File-prioritization tiers
- T0 entry: Package.swift, occ/main, occ-probe/main, occ-connect/main, occ-tests/main.
- T1 core: CrashCartAdapter, Types, VSProtocol, StarTechTileDecoder, StarTechVideoDecoder.
- T2 adapters/transport: StarTechAdapter, StarTechFirmware, StarTechSupport, VirtualMedia, UVCAdapter, CH9329, SerialPort, UVCDiscovery, USBDevice, USBEnumeration.
- T3 wiring/profiles/input: AdapterFactory, AdapterRegistry, HardwareProfile, ProfileStore, HIDKeymap, HIDTyping.
- T4 UI: AppController, VideoView, SettingsWindow, ToolbarStrip, KeyboardPanel, VideoAdjustPanel, ImageEnhancePanel, StatusBar, PlaceholderView, Recorder, OCR, Theme.
- T6 tests; T7 utils/packaging.

## Flagged for later passes
- `AsyncStream<AdapterEvent>` device→UI channel; heavy `@unchecked Sendable` + manual locks (3-thread transport, CommandQueue); `@MainActor` UI.
- Protocol-with-default-impl (`CrashCartAdapter` extension: typeText/CtrlAltDel/no-op tuning).
- C interop via OpaquePointer/withCString/struct-packed byte arrays (libusb/zlib/termios/VSP).
- **Gaps:** `Adapter/` vs `Adapters/` easy to conflate; UVC backend not reachable via `makeAdapter` (reached via app menu — verify Pass 1/3); `StarTechVideoDecoder` "placeholder" comment is stale (real decoder is `StarTechTileDecoder`).

## State Checkpoint
```yaml
pass: 0
status: complete
files_scanned: 47
swift_loc_sources_only: 4764
next_pass: 1
```
