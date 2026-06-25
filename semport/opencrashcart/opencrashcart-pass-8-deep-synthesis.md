# Pass 8: Final Synthesis — OpenCrashCart

Definitive synthesis of the brownfield ingest. All passes converged; coverage audit and extraction validation passed (PASS/TRUST, 98% accuracy, 52/52 metrics zero-delta).

## What OpenCrashCart is
A ~4,764-LOC, arm64-native macOS KVM client that drives headless machines over USB crash-cart adapters. A device-agnostic core (`OCCKit`) exposes one seam — the `CrashCartAdapter` protocol — behind which two backends plug in: **StarTech** (libusb + custom "VSP" wire protocol + reverse-engineered 16×16-tile RGB565→BGRA codec + FPGA bitstream upload + virtual media + DDC + analog tuning) and **UVC** (AVFoundation capture + CH9329 serial-HID). An AppKit app (`occ`) and three CLIs consume a single `AsyncStream<AdapterEvent>` channel.

## Complete feature set
KVM (video/keyboard/mouse), virtual media (ISO/IMG as USB drive), OCR copy-from-screen (Vision), paste/type text, on-screen keyboard (sticky modifiers), analog video tuning + DDC presets, client-side image enhancement (Core Image, display-only), relative-mouse mode, session recording (H.264), snapshots, user-editable hardware profiles ("bring your own firmware"), poll-based hotplug, multi-adapter (StarTech + UVC).

## Bounded-context map
1. **Adapter abstraction** (`Adapter/`) — protocol seam + value types (Types.swift) + discovery/factory/registry/profiles.
2. **StarTech backend** (`Adapters/StarTech/`) — VSP protocol, tile codec, 3-thread transport, firmware, virtual media, MISC tuning, DDC.
3. **UVC backend** (`Adapters/UVC/`) — AVFoundation capture + CH9329/SerialPort HID.
4. **Transport** (`USB/`) — libusb wrapper + enumeration.
5. **Input mapping** (`Input/`) — HID keymap + typing.
6. **App/session** (`occ/`) — AppController (session aggregate root, fuses UI+orchestration), VideoView, panels, Recorder, OCR, Theme, StatusBar.

## Complexity ranking (by LOC + conceptual load)
1. StarTech tile codec + 3-thread transport (StarTechAdapter 435 + TileDecoder 203) — highest; concurrency + binary protocol + reverse-engineered codec.
2. AppController (666) — session state machine + full command surface, fused UI/orchestration.
3. VideoView (332) — input translation, letterbox math, OCR selection, relative-mouse capture.
4. SettingsWindow (297) — profile-edit + firmware-import.
5. UVC/CH9329 (180+66+39) — capture + serial-HID + mouse coalescing.

## Critical design decisions (intentional, keep)
- **One seam, two concurrency models** — StarTech (4 raw threads + priority queue) and UVC (GCD + mouse coalescing) unified by AsyncStream→@MainActor; sync fire-and-forget input avoids actor hops.
- **Protocol + default-no-op extension** — backends implement only what their hardware supports.
- **Bring-your-own-firmware** — no vendor blobs bundled; runtime search chain. Clean-room provenance on every RE'd surface.
- **Dependency-free test harness** — pure-logic coverage runs under bare CLT in CI.
- **Display-only image enhancement** — raw frames preserved for snapshot/OCR.

## Anti-patterns / smells (surfaced by ingest)
- Dual device-matching source of truth (AdapterRegistry + ProfileStore + StarTechAdapter.model — 3 hardcodes).
- `AppController` god-object fuses UI + session orchestration (666 LOC, no separate session type).
- Layer leak: `USBDevice.close()` references `VSProtocol.interfaceNumber`.
- Dormant `needsKeyframe` (desync recovery never fires).
- Silent error swallowing (firmware copy `try?`, profile write `try?`, OCR perform `try?`).
- Unbounded AsyncStream buffer; indefinite rescan with no cap/backoff.

## Convergence report
| Pass | Rounds | Trajectory | Outcome |
|---|---|---|---|
| 0 Inventory | 1 broad | — | covered (B.5/B.6 confirmed) |
| 1 Architecture | 1 broad | — | covered |
| 2 Domain | broad + deep r1 + r2 + r3 | SUBSTANTIVE → SUBSTANTIVE → NITPICK | CONVERGED |
| 3 Behavioral | broad + deep r1 + r2 + r3 | SUBSTANTIVE → SUBSTANTIVE → NITPICK | CONVERGED |
| 4 NFR | 1 broad | — | covered |
| 5 Conventions | 1 broad | — | covered |
- B.5 coverage audit: SUBSTANTIVE — found the app-UI layer blind spot, filled by deep rounds + BC-AUDIT-001..033.
- B.6 extraction validation: PASS/TRUST — 25/26 BCs confirmed (1 confidence-grade fix), 0 hallucinated, 52/52 metrics zero-delta.

## Coverage metrics
- 45/45 Sources files covered. ~140 behavioral contracts (BC-001..086 protocol/OCCKit, BC-100..143 app, BC-200..211 panels, BC-AUDIT-001..033). ~40 entities/value types. 41 NFRs + config table. ~24 conventions.
- Confidence: HIGH where test-pinned (protocol packing, tile codec, keymap/typing, gunzip, profiles); MEDIUM for code-grounded-untested (all app layer, USB transport, virtual media, STATUS parse, firmware).

---

## Lessons for OpenCrashCart (priority-ordered backlog)

*(Brownfield self-ingest: "reference" and "target" are the same codebase, so each lesson is an actionable improvement the ingest surfaced.)*

### P0 — Correctness gaps to fix before next release
None blocking — the app ships and works. The highest-impact real bugs are in P1 (no "won't load / broken contract" class defects found).

### P1 — High-ROI improvements (proven gap, small edit, measurable)
- **P1.1 Disconnect is silently auto-undone within 2s** — (a) `menuDisconnect` resets state but leaves the rescan timer running (AppController.swift:397-407), (b) the 2s `rescanTimer` re-`tryConnect`s (BC-104/112), (c) gap: user clicks Disconnect and it reconnects itself, (d) add a `userDisconnected` flag that pauses rescan until an explicit Reconnect/Connect. Files: `Sources/occ/AppController.swift`.
- **P1.2 Video desync cannot self-heal** — (a) `videoLoop` checks `decoder.needsKeyframe` and would enqueue `doIFrame` (StarTechAdapter.swift:299-301), (b) `StarTechTileDecoder` never sets `needsKeyframe=true` (BC-019), (c) gap: on a corrupt/partial frame stream there is no I-frame request, so artifacts persist, (d) set `needsKeyframe` when record reassembly fails or tile coords are wildly out of range. Files: `Sources/OCCKit/Adapters/StarTech/StarTechTileDecoder.swift`.
- **P1.3 OCR failure leaves a stuck "Reading text…" status** — (a) `recognizeText` swallows `perform` errors with `try?` and never calls completion (OCR.swift:7-24, BC-140), (b) the status stays "Reading text…" forever, (c) gap: no error path, (d) pass a failure through the completion and clear status. Files: `Sources/occ/OCR.swift`, `Sources/occ/AppController.swift`.
- **P1.4 Unify the dual device registry** — (a) PIDs are hardcoded in `AdapterRegistry.known`, `ProfileStore.builtIns`, and `StarTechAdapter.model` (3 places), (b) a PID change needs 3 synced edits, (c) gap: drift risk, (d) make `AdapterRegistry`/`StarTechAdapter.model` derive from the built-in profile (single source). Files: `Sources/OCCKit/Adapter/{AdapterRegistry,ProfileStore}.swift`, `StarTechAdapter.swift`.
- **P1.5 Backfill tests for the MEDIUM untested contracts** — (a) tests cover only pure logic, (b) USB error mapping, virtual-media block math, firmware search order, STATUS parse, mouse coalescing, command-queue priority are untested (BC-020..023, 060..063, 084, 036, 037), (d) add harness tests (these are pure-ish and injectable). Files: `Sources/occ-tests/`.

### P2 — Worth considering (judgment calls / trade-offs)
- **P2.1 Non-awaited disconnect on terminate** (BC-106) — `applicationWillTerminate` fires `Task { await disconnect() }` without awaiting; device cleanup is best-effort. Consider a bounded synchronous wait. `AppController.swift:139-143`.
- **P2.2 Silent `try?` on firmware import** (BC-134) — a failed copy is hidden but the dir is still repointed (partial-failure). Surface copy errors. `Sources/occ/SettingsWindow.swift:184-203`.
- **P2.3 No VID/PID format validation in Settings UI** (BC-130) — invalid hex is stored raw and silently parses to 0 (fail-closed but confusing). Validate on save. `SettingsWindow.swift`.
- **P2.4 Layer leak** — `USBDevice.close()` references `VSProtocol.interfaceNumber`; pass the interface number in instead. `Sources/OCCKit/USB/USBDevice.swift`.
- **P2.5 Unbounded AsyncStream buffer + no reconnect cap/backoff** (PERF-08, REL-06) — consider `.bufferingNewest` and capped/backoff rescan.
- **P2.6 Cross-platform/`/opt/homebrew`** — hardcoded prefix blocks Intel-Homebrew/`/usr/local`; relevant to any reach-broadening (the user's "less niche" thread). `Package.swift`.
- **P2.7 CH9329 serial is write-only** — no read/ack means no serial-link health signal (unlike StarTech heartbeat). `Sources/OCCKit/Adapters/UVC/SerialPort.swift`.

### P3 — Known divergences to document (intentional; just note them)
- **P3.1 Stale comment**: `PlaceholderVideoDecoder` says "no pixel decoding yet / Phase 3 will return decoded frames" — the real decoder is `StarTechTileDecoder`. Fix the comment. `StarTechVideoDecoder.swift:7-9,20,41`.
- **P3.2 Boot omits doc's `e`(ftDisconnect)** step (BC-082) — reconcile code (v,s,g,FPGA) with `docs/PROTOCOL.md`.
- **P3.3 Firmware header comment** lists 3 tiers vs the 5-tier implementation (round-3) — align comment to code.
- **P3.4 `VideoAdjustment.sharpness` ↔ MISC index 4 documented "flatness"** — vocabulary drift; pick one term.
- **P3.5 UVC reachable only via the app menu, never `makeAdapter`/CLIs** — deliberate asymmetry; document it so it isn't mistaken for an oversight.
- **P3.6 `VSProtocol.Misc` vs `StarTechAdapter.miscIndex`** — two parallel MISC encodings; note which is authoritative.
- **P3.7 StatusBar `KeyboardEmulation.name` array** (BC-210) — latent OOB if a 4th enum case is ever added; add a default or make it exhaustive.

## Downstream
These artifacts feed `/create-brief`, `/create-domain-spec`, `/create-prd`. Phase D (vision disposition) is deferred until a vision doc exists.
