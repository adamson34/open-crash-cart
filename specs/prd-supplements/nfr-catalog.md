---
document_type: prd-supplement-nfr-catalog
level: L3
status: draft
traces_to: prd.md
source: semport/opencrashcart/opencrashcart-pass-4-nfr-catalog.md
---

# Non-Functional Requirements — OpenCrashCart

Derived from the brownfield ingest (validated PASS/TRUST). Each NFR cites where it is encoded.

## Performance / real-time
- NFR-PERF-01 Late UVC frames dropped (`alwaysDiscardsLateVideoFrames=true`) — liveness > backlog.
- NFR-PERF-02 Fixed BGRA end-to-end — no per-frame format negotiation.
- NFR-PERF-03 Per-frame copy + CGImage accepted cost (only Recorder pools buffers).
- NFR-PERF-04 Bounded tile geometry 1920×1600/16/120×100; pre-alloc ~12.3MB fb; emit only on tile write.
- NFR-PERF-05 Mouse coalescing (latest-wins) for the 9600-baud CH9329 link.
- NFR-PERF-06 Two-priority CommandQueue (input before control) keeps typing responsive during FPGA upload.
- NFR-PERF-07 Bulk timeouts: write 1000ms / read 2000ms / media 4000ms; 64KiB chunk cap.
- NFR-PERF-08 AsyncStream = single UI backpressure boundary (default **unbounded** buffer — gap).
- NFR-PERF-09 Bounded 1MiB thread stacks; 3 I/O threads/StarTech, 2 GCD queues/UVC.
- NFR-PERF-10 Paced typing 7ms between strokes.

## Reliability / safety
- NFR-REL-01 `releaseAllKeys` on every focus loss — no stuck key on a live target.
- NFR-REL-02 key-up always forwarded; NFR-REL-03 ⌘-held presses not forwarded.
- NFR-REL-04 `flagsChanged` modifier-only guard (no stray 'A').
- NFR-REL-05 heartbeat echo keeps the StarTech link alive.
- NFR-REL-06 2s rescan auto-reconnect (poll-based hotplug) — **v1.1.0:** suppressed after explicit Disconnect (BC-1.01.034).
- NFR-REL-07 device-gone error mapping (timeout→continue, disconnected→fatal).
- NFR-REL-08 clean teardown; media loops check `running` between chunks.
- NFR-REL-09 recording drops size-mismatch frames (no corrupt .mov).
- NFR-REL-10 mount-by-exact-unit (bus+address).
- **v1.1.0 NFR-REL-11** decoder self-heals via keyframe request on desync (BC-1.02.018).

## Security / clean-room
- NFR-SEC-01 No vendor firmware bundled; runtime search chain.
- NFR-SEC-02 Clean-room provenance documented in source; MIT.
- NFR-SEC-03 Ad-hoc signed, not notarized (open question for v1.1.0); README quarantine note.
- NFR-SEC-04 Camera-only permission (`NSCameraUsageDescription`).
- NFR-SEC-05 No telemetry / no network code anywhere in Sources.

## Observability
- NFR-OBS-01 `AdapterEvent.message/.status` channel. NFR-OBS-02 on-change-only status emission.
- NFR-OBS-03 fps + bandwidth readout (sanity-gated). NFR-OBS-04 CLI diagnostics. NFR-OBS-05 link-speed warning.

## Configurability
- NFR-CFG-01 5 `OCC_*` env vars. NFR-CFG-02 UserDefaults padding (clamped). NFR-CFG-03 profiles.json (BYO firmware).
- NFR-CFG-04 firmware search precedence (profile→env→store→app-support→vendor). NFR-CFG-05 hardcoded /opt/homebrew (build-time).
- NFR-CFG-06 device-side DDC/MISC tuning + client-side display-only enhancement.

## Portability / build
- NFR-PORT-01 macOS 13+ (UVC needs 14). NFR-PORT-02 Apple Silicon arm64.
- NFR-PORT-03 Homebrew libusb bundled into .app. NFR-PORT-04 self-contained signed bundle. NFR-PORT-05 dependency-free test suite (no XCTest).

## Known NFR gaps (hardening backlog)
- Unbounded AsyncStream buffer (PERF-08); no reconnect cap/backoff (REL-06); no retry/backoff on
  transient bulk-write; hardcoded `/opt/homebrew` (no `/usr/local` fallback); CH9329 serial write-only
  (no link-health). These are P2 items in the synthesis — not all in v1.1.0 scope.
