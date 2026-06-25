# Pass 1: Architecture — OpenCrashCart

Native macOS USB crash-cart KVM client. ~45 Swift files / ~4760 LOC. One SwiftPM package producing OCCKit (library) + occ/occ-probe/occ-connect/occ-tests (executables). Dependency direction is strictly inward: UI/CLIs → OCCKit → {Clibusb, Czlib}.

## 1. Layered architecture
- UI (AppKit) — Sources/occ/: AppController (session bridge + menus, 666 LOC), VideoView (render + input capture, 332), SettingsWindow, ToolbarStrip, KeyboardPanel, VideoAdjustPanel, ImageEnhancePanel, StatusBar, PlaceholderView, Recorder, OCR, Theme, main.
- Session/orchestration — fused into AppController (@MainActor); there is NO separate session type.
- Adapter abstraction (the seam) — OCCKit/Adapter/: CrashCartAdapter (protocol + default ext), Types, AdapterFactory, AdapterRegistry, HardwareProfile, ProfileStore.
- Backends — OCCKit/Adapters/: StarTech (Adapter, Support/CommandQueue, TileDecoder, VideoDecoder seam, Firmware, VirtualMedia, VSProtocol) and UVC (Adapter, Discovery, CH9329, SerialPort).
- Transport — OCCKit/USB/: USBDevice (libusb bulk), USBEnumeration; serial under UVC.
- System shims — Clibusb, Czlib, Util/Gunzip.
- Input mapping — OCCKit/Input/: HIDKeymap, HIDTyping.
- CLIs — occ-probe (enumerate), occ-connect (connect + print stream, StarTech only), occ-tests.

## 2. The CrashCartAdapter seam
CrashCartAdapter (CrashCartAdapter.swift:32) is AnyObject, Sendable. Static identity (model, canDrive); lifecycle (connect() async throws -> AsyncStream<AdapterEvent>, disconnect()); sync fire-and-forget input (send(key:), send(mouse:)); optional capabilities with default no-op (requestKeyframe, autoTuneVideo, mount/eject media, setVideoAdjustment, save/reset, setDDCPreset); conveniences built on primitives (typeText, sendKeyPress, sendCtrlAltDel). UI talks only to `any CrashCartAdapter` + the value types in Types.swift.

Discovery+factory (StarTech path): discoverProfiledDevices() → enumerateUSBDevices() (libusb) → ProfileStore.match(vid,pid) → makeAdapter(for:profile:) switch on profile.backend ("dmtz-vsp"→StarTechAdapter, default→nil).

### Verified gap: UVC reachable only via AppKit menu
makeAdapter has no UVC case (default→nil). UVCAdapter.canDrive returns false. Only construction site: AppController.menuConnectUVC (AppController.swift:226 → UVCAdapter(deviceID:)) from the dynamically-populated "Connect UVC Device" submenu. CLIs cannot reach UVC. Deliberate asymmetry, not a bug.

## 3. Concurrency architecture
- StarTech: 4 raw Threads (Writer EP0x04, Response EP0x83, Video EP0x82, transient Boot), each 1MB stack, against a single EP-thread-safe USBDevice. CommandQueue (NSCondition, inputQ drained before controlQ) keeps typing responsive during FPGA upload. AtomicFlag running gates loops. Virtual-media data EPs 0x85/0x05 driven inline in the response thread.
- UVC: GCD — captureQueue (CMSampleBuffer → BGRA copy), inputQueue (CH9329 HID state + mouse coalescing: latest-position-wins). CH9329 → SerialPort (blocking termios). AVCaptureSession start/stop hopped via nonisolated(unsafe).
- @MainActor bridge: AppController consumes the AsyncStream with `for await event in events { handle(event) }`; input flows back as synchronous calls (no actor hop, by design).

## 4. Data flow
- Video device→screen (StarTech): EP0x82 → videoLoop bulkRead → decoder.ingest (tile reassembly, RGB565→BGRA into 1920×1600 framebuffer) → emit(.frame) → AppController.handle → VideoView.display (CGImage + optional CoreImage enhancement) + recorder.append.
- Video (UVC): capture device → captureOutput → row-copy CVPixelBuffer (already BGRA) → emit(.frame) → same path.
- Input UI→device (common front-end): VideoView keyDown/keyUp/flagsChanged → HIDKeymap (swallows ⌘), tracks keysDown for allReleased; mouse → absolute active-pixel coords with letterbox correction or relative deltas → VideoViewInput → AppController.send → adapter.send.
  - StarTech: VSPack.keyEvent('k')/mouseEvent('m') → input queue → Writer → EP0x04.
  - UVC/CH9329: applyKey (modifier bitmask + ≤6 keys) → ch9329Frame (0x57 0xAB 0x00 cmd len data checksum) → SerialPort. Gated on hasHID; view-only if no CH9329.

## 5. Cross-cutting concerns
- Error handling: USBTransportError/USBError (CustomStringConvertible, carry libusb codes). Loops: timeout→continue, disconnected→died() (clean teardown + .disconnected), other→swallow. Diagnostics travel as .message events (no central logger).
- Firmware: StarTechFirmware loads the user's existing FPGA bitstream at runtime (never bundled). Resolution order: profile firmwareDir → OCC_FIRMWARE_DIR → ProfileStore dir → app-support → vendor fallbacks. .fgz gunzipped via Czlib. Failure degrades to a message, not abort.
- Profiles: HardwareProfile (Codable) + ProfileStore (NSLock singleton) at ~/Library/Application Support/OpenCrashCart/profiles.json; seeded with builtIns; editable via SettingsWindow.
- Lifecycle: tryConnect once + 2s repeating rescan timer (poll-based hotplug). .disconnected nulls adapter so the timer re-discovers. UVC bypasses tryConnect (manual menu). VideoView.releaseAllKeys on focus loss prevents stuck keys. OCC_SECONDS auto-terminates (test harness).

## Substantive findings
1. UVC backend reachable only via the AppKit menu, never makeAdapter/discovery/CLIs (verified).
2. Two concurrency models behind one seam (StarTech 4-thread+priority-queue vs UVC dual-GCD+coalescing), unified by AsyncStream→@MainActor; sync input avoids an actor hop.
3. AppController fuses UI + session orchestration (no separate session type; 666 LOC).
4. Hotplug is poll-based (2s rescan), not IOKit-notification driven.
5. Two parallel device registries (AdapterRegistry.known compiled / ProfileStore JSON) must be hand-synced.
6. Profile-driven no-redistribution firmware loading + default-no-op protocol extension are the two intentional extensibility seams.
7. Decoder seam is a protocol with a real StarTechTileDecoder + a PlaceholderVideoDecoder (transport testable without pixels).

Confidence: HIGH for layering/seam/concurrency/data-flow/UVC-reachability; MEDIUM for tile-decoder pixel internals.
(Two Mermaid diagrams — component + data-flow — in the full agent transcript.)
