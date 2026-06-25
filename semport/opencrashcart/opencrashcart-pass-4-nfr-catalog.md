# Pass 4: NFR Catalog — OpenCrashCart

Dominant constraints: (1) soft-real-time video over USB bulk, (2) slow CH9329 9600-baud serial.

## Performance / real-time
- PERF-01 Late UVC frames dropped: alwaysDiscardsLateVideoFrames=true (UVCAdapter.swift:62). Liveness>completeness.
- PERF-02 Fixed BGRA end-to-end (kCVPixelFormatType_32BGRA; tile decoder BGRA; VideoView byteOrder32Little|noneSkipFirst). No per-frame format negotiation.
- PERF-03 Per-frame full-buffer copy + per-frame CGImage (accepted cost; only Recorder uses CVPixelBufferPool).
- PERF-04 Bounded tile geometry: 1920×1600, 16px tiles, 120×100; pre-alloc ~12.3MB fb; solid=4B, raw=516B; emit only if a tile touched.
- PERF-05 Mouse coalescing (latest-wins) for 9600-baud link (UVCAdapter:43-46,141-167; baud OCC_CH9329_BAUD default 9600).
- PERF-06 Two-priority CommandQueue: input drained before control (StarTechSupport:6-37) — typing stays responsive during FPGA upload.
- PERF-07 Bulk timeouts: write 1000ms, read 2000ms, virtual-media 4000ms; chunk cap 64KiB; response read 64B.
- PERF-08 AsyncStream is the single UI backpressure boundary; default UNBOUNDED buffer (gap); status de-dup limits volume.
- PERF-09 Bounded 1MiB thread stacks; 3 I/O threads/StarTech session; 2 GCD queues/UVC.
- PERF-10 Paced typing: 7ms (0.007) between strokes on .userInitiated queue (CrashCartAdapter:100).

## Reliability / safety
- REL-01 releaseAllKeys on every focus loss (window+app resign; resignFirstResponder) — no stuck key.
- REL-02 key-up always forwarded (asymmetric with keyDown).
- REL-03 Command-held presses NOT forwarded (macOS shortcut safety, VideoView:196-197).
- REL-04 flagsChanged guards isModifier (avoids stray 'A' on keyCode-0 focus theft).
- REL-05 heartbeat 'H' echo keeps link alive (control priority).
- REL-06 2s rescan timer = poll-based hotplug auto-reconnect.
- REL-07 device-gone error mapping: timeout→continue, disconnected→died; transient write→continue.
- REL-08 clean teardown/cancellation; media loops check running between 64KiB chunks.
- REL-09 recording drops frames whose size differs from writer dims (no corrupt .mov).
- REL-10 mount-by-exact-unit (bus+address), not first VID/PID.

## Security / clean-room
- SEC-01 No vendor firmware bundled; runtime search chain; bundle script copies only occ + libusb.
- SEC-02 Clean-room provenance documented in source (VSProtocol, StarTechAdapter, TileDecoder, docs); MIT.
- SEC-03 Ad-hoc signing (codesign -s -), no hardened runtime/entitlements/notarization; README quarantine note.
- SEC-04 NSCameraUsageDescription only (UVC); requestAccess(.video); no mic/location/network strings.
- SEC-05 No telemetry/network: zero URLSession/Socket/analytics matches in Sources.

## Observability
- OBS-01 AdapterEvent.message/.status channel → status bar.
- OBS-02 on-change-only status emission (differs); UVC only on size change.
- OBS-03 fps + bytesPerSecond (words*16*1000/ticks); StatusBar "%2d fps %4.1f MB/s" with sanity gate.
- OBS-04 CLI diagnostics: occ-probe lists devices/speed/backend; occ-connect unbuffered live logs, non-zero exit.
- OBS-05 link-speed warning (libusb speed>=3) GUI+CLI.

## Configurability
- CFG-01 Env: OCC_FIRMWARE_DIR, OCC_PADDING, OCC_SECONDS, OCC_CH9329_PORT, OCC_CH9329_BAUD.
- CFG-02 UserDefaults padding ("OpenCrashCartPadding"), clamped [0,40] read / [0,96] live / reset 14.
- CFG-03 profiles.json (BYO firmware); built-in StarTech seed; editable-not-deletable; hex/decimal IDs.
- CFG-04 firmware search precedence (profile→env→store→app-support→vendor); gen from PID 0x8463→2.
- CFG-05 hardcoded /opt/homebrew (build-time).
- CFG-06 device-side video tuning (MISC) + DDC presets; client-side enhancement display-only.

## Portability / build
- PORT-01 min macOS 13; UVC .external needs 14.
- PORT-02 Apple Silicon arm64 (premise: replace Intel-only vendor app).
- PORT-03 Homebrew libusb bundled into .app via otool/@rpath rewrite.
- PORT-04 self-contained double-clickable bundle; id com.opencrashcart.OpenCrashCart, v1.1.0-beta.1.
- PORT-05 dependency-free test suite (no XCTest), runs under bare CLT in CI.

## Config-value table → NFR
9600 baud→PERF-05; 0.007 typing→PERF-10; alwaysDiscardsLateVideoFrames→PERF-01; 1000/2000/4000ms timeouts→PERF-07; 65536 chunk→PERF-04/07; 1920×1600/16/120×100→PERF-04; 1024×768 default; 507 fpgaBlockSize; 1MiB stack→PERF-09; 2.0s rescan→REL-06; speed>=3→OBS-05; padding 14/[0,40]/[0,96]→CFG-02; EP 0x82/0x83/0x04/0x85/0x05→PERF-09; 'H'→REL-05; 0x152A/0x8460,0x8463→CFG-03; ulcvm/usbip.fgz→SEC-01/CFG-04; /opt/homebrew→CFG-05/PORT-03; .macOS(.v13)/13.0→PORT-01; macOS14 .external→PORT-01; codesign -s -→SEC-03; NSCameraUsageDescription→SEC-04.

## Gaps / missing-but-expected NFRs
- No explicit AsyncStream buffering policy (unbounded buffer risk).
- No hardened runtime/notarization/entitlements.
- No retry/backoff for transient bulk-write failures.
- No circuit-breaker / max-reconnect cap (indefinite 2s retry).
- Hardcoded /opt/homebrew (no /usr/local fallback).
- CH9329 serial is write-only (no read/ack → no serial-link health signal, unlike StarTech heartbeat).
