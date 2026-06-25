# Pass 6: Synthesis — OpenCrashCart

Cross-references Passes 0–5. Reconciles findings, flags inconsistencies, and reports coverage gaps to drive Phase B deepening.

## Unified understanding (one paragraph)
OpenCrashCart is a ~4,764-LOC, arm64-native macOS KVM client that gives an operator a headless machine's screen/keyboard/mouse over a USB crash-cart adapter. A device-agnostic core library (`OCCKit`) exposes one seam — the `CrashCartAdapter` protocol — behind which two concrete backends plug in: the libusb-driven **StarTech** path (custom "VSP" wire protocol + a reverse-engineered 16×16-tile RGB565→BGRA video codec, FPGA bitstream uploaded each session, virtual media, DDC, MISC video tuning) and a generic **UVC** path (AVFoundation capture + CH9329 serial-HID for keyboard/mouse, view-only if no controller). The AppKit app (`occ`) and three CLIs consume the same `AsyncStream<AdapterEvent>` event channel. The codebase is unusually disciplined for its size: a strict `Adapter/` (abstractions) vs `Adapters/` (concretes) split, a protocol-with-default-no-op extensibility seam, a four-way stratified concurrency model, typed per-subsystem errors, and a signature reverse-engineering-provenance/clean-room comment convention that ties every RE'd surface to a spec doc.

## Cross-pass consistency check
Findings corroborated independently across passes (high confidence):
- **UVC reachable only via the AppKit menu, never `makeAdapter`/CLIs** — flagged in Pass 0, verified in Pass 1 (AdapterFactory has no UVC case; `UVCAdapter.canDrive`=false; sole site `AppController.menuConnectUVC`), reflected in Pass 3 (BC-045).
- **`PlaceholderVideoDecoder` "no pixel decoding yet" comment is stale** — Pass 0 flag → Pass 2/3 confirm `StarTechTileDecoder` is the real default decoder (init default param + all tile tests + docs/CODEC.md:73).
- **`needsKeyframe` dormant** — Pass 2 (never set true) and Pass 3 (BC-019: documented desync/I-frame loop never fires).
- **Two-priority CommandQueue / input-ahead-of-control** — Pass 1 (concurrency), Pass 3 (BC-037), Pass 4 (PERF-06).
- **Mouse coalescing for the slow serial link** — Pass 1, Pass 3 (BC-036), Pass 4 (PERF-05).
- **No bundled firmware / clean-room** — Pass 1 (cross-cutting), Pass 4 (SEC-01/02), Pass 5 (§6.2).

No cross-pass contradictions found. Metric agreement: all passes report 45 Sources files / 4,764 LOC (47/4,868 incl. Package.swift + makeicon.swift), independently recounted in Pass 0 and Pass 5.

## Reconciled inconsistencies in the *code* (not the analysis)
1. **Dual device-matching source of truth** — `AdapterRegistry.known` (compiled, CLI/enumeration path) vs `ProfileStore.builtIns` (user JSON, app path); the same StarTech model + PIDs are hardcoded in three places (Registry, ProfileStore, `StarTechAdapter.model`). A PID change needs three edits. (Pass 1 #5, Pass 5 §9.1)
2. **Layer leak** — `USBDevice.close()` references `VSProtocol.interfaceNumber`, putting a StarTech constant in the generic USB layer. (Pass 5 §9.2)
3. **MISC double-encoding** — `VSProtocol.Misc` constants vs `StarTechAdapter.miscIndex`; `VideoAdjustment.sharpness` ↔ MISC index 4 documented "flatness". (Pass 2, Pass 5 §9.4/§9.6)
4. **Boot-order divergence vs docs** — code sends v,s,g then FPGA; PROTOCOL.md lists an `e`(ftDisconnect) step not sent. (Pass 3 BC-082)
5. **Firmware redundancy** — two `loadFPGABitstream`/`locate` overloads (profile vs generation). (Pass 5 §9.3)

## Gap report (drives Phase B + B.5)
Under-documented subsystems / orphaned-ish modules from the broad sweep:
- **AppController (666 LOC)** — the largest file, only partially traced (menus, session lifecycle, rescan, OCR/record wiring, relative-mouse, UVC submenu). Highest-value Pass-1/Pass-3 deepening target.
- **VideoView (332 LOC)** — input capture, letterbox mouse mapping, OCR region selection, image-enhancement plumbing — only key-state/allReleased deeply covered.
- **SettingsWindow (297 LOC)** — profile editor UI essentially uncovered (forms, firmware import, validation).
- **Recorder / OCR** — touched in Pass 4 (NFR-REL-09, BGRA) but no behavioral contracts.
- **occ-probe / occ-connect** — CLI behaviors lightly covered.
- **USBEnumeration** — speed detection + descriptor reads partially covered.
- **Test-coverage gap (for spec backfill)**: the MEDIUM-confidence contracts (USB transport mapping, virtual-media block math, firmware search order, FPGA upload framing, STATUS parse, mouse coalescing, command-queue priority) are code-grounded but untested.

## Confidence assessment
- HIGH: protocol packing, tile codec, keymap/typing, gunzip, profiles (all test-pinned); architecture/seam/concurrency/data-flow; UVC reachability; clean-room posture.
- MEDIUM: StarTech lifecycle internals, virtual-media wire integration, firmware search, STATUS parse, UVC/CH9329 input state — code-grounded, untested.
- LOW: dormant `needsKeyframe`/I-frame path; STATUS fields read-and-discarded (pixPerClk/savedPos/fpgaPowered).

## Phase B targeting (carryover, verbatim)
- **Pass 2 next scope:** AppController/VideoView/SettingsWindow domain operations (menu actions, session state, profile-edit model, OCR/record/relative-mouse state).
- **Pass 3 next scope:** behavioral contracts for AppController session lifecycle, VideoView input/letterbox/OCR-selection, SettingsWindow validation, Recorder/OCR; promote MEDIUM untested contracts with exact code refs.
- **Pass 1/4/5 next scope:** UI-layer architecture (panel/Theme/delegate topology), NFRs in AppController (rescan/teardown/OCC_SECONDS), UI conventions in the uncovered app files.
