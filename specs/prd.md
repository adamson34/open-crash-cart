---
document_type: prd
level: L3
version: "1.0"
status: draft
phase: 1a
inputs: [product-brief.md, semport/opencrashcart/opencrashcart-pass-8-deep-synthesis.md]
traces_to: product-brief.md
supplements: [interface-definitions.md, error-taxonomy.md, nfr-catalog.md, module-criticality.md]
origin: brownfield
---

# Product Requirements Document: OpenCrashCart

> **Index document.** Each behavioral contract lives in its own file under
> `behavioral-contracts/ss-NN/`. Section 2 links to `behavioral-contracts/BC-INDEX.md`
> (128 contracts: 127 active + 1 deprecated). Supplements (interface, NFR, error taxonomy, criticality) live under
> `prd-supplements/`.

## 1. Product Overview

### 1.1 Problem Statement
The incumbent StarTech crash-cart software is Intel-only Python 2.7/wxPython and breaks as macOS
ends Intel/Rosetta support — leaving Mac admins with no native console-recovery path, and the
broad class of UVC capture-dongle owners with no polished macOS client. This PRD specifies a
**v1.1.0 hardening release** of OpenCrashCart: formalize the existing behavior as L3 contracts
and fix the correctness defects surfaced by the brownfield ingest.

### 1.2 Solution Vision
A native arm64 Swift/AppKit app with a device-agnostic `CrashCartAdapter` seam and two backends
(StarTech VSP + UVC/CH9329), serving sysadmins and broader capture users equally. v1.1.0 makes
both backends first-class, fixes four P1 defects, and backfills tests.

### 1.3 Key Differentiators
| ID | Differentiator | Why it matters |
|----|----------------|----------------|
| KD-001 | Native arm64, no Python/Rosetta | Runs where the vendor app no longer can |
| KD-002 | Multi-adapter behind one seam (BYO firmware) | StarTech crash-carts + generic UVC dongles |
| KD-003 | Clean-room + MIT, no vendor blobs | Legally clean, open, extensible via profiles |
| KD-004 | More than a viewer (virtual media, OCR, record, enhance) | Console recovery + capture-app value |

### 1.4 Target Users
| Persona | Description | Volume | Pain |
|---------|-------------|--------|------|
| Sysadmin / homelab | Console recovery on headless servers via crash-cart | Core | High |
| UVC capture user | Clean Mac viewer/recorder for HDMI→USB dongles | Broad | Medium |
| Adapter tinkerer | Adds hardware via user-editable profiles | Niche | Low |

## 2. Subsystems

| SS | Name | Description | Criticality |
|----|------|-------------|-------------|
| 01 | Session & Connection Lifecycle | connect/boot/heartbeat/disconnect/reconnect/rescan, USB transport, firmware upload, virtual media, command queue, AppController session + menu actions | HIGH |
| 02 | Video Pipeline & Decoder Resilience | tile codec, STATUS→state, frame render, mouse-geometry mapping, keyframe self-heal | HIGH |
| 03 | Screen OCR & Capture | OCR select→recognize→clipboard, snapshot, recording, image enhancement, adjust panels | MEDIUM |
| 04 | Device Identity & Hardware Profiles | profile parse/match/persist, settings editor, firmware import, DDC/MISC tuning, single-source matching | HIGH |
| 05 | Input & UVC/CH9329 Backend | HID keymap/typing, VSP + CH9329 packing, key-safety, UVC capture, mouse coalescing | HIGH |
| 06 | Quality Gates & Test Coverage | harness/CI gates + v1.1.0 test backfill + coverage policy | MEDIUM |

## 3. Requirements by Subsystem
All 128 behavioral contracts (127 active + BC-1.01.005 deprecated, merged into BC-1.02.010) are
indexed in **`behavioral-contracts/BC-INDEX.md`** (one file per contract under `ss-NN/`). The set was
revised per `adversarial-review.md` (added coverage BCs BC-1.02.019 auto-tune, BC-1.01.041/042 CLIs,
BC-1.01.043 link-speed). The **11 v1.1.0 change contracts** (the P1 fixes + test backfill) carry
`introduced: v1.1.0`:
- **BC-1.01.034** — Disconnect stays disconnected (P1.1; `userDisconnected` flag suppresses rescan).
- **BC-1.02.018** — Decoder requests keyframe on desync (P1.2; corrects dormant `needsKeyframe`).
- **BC-1.03.012** — OCR failure surfaces and clears status (P1.3; no more stuck "Reading text…").
- **BC-1.04.020** — Single source of truth for device matching (P1.4; derive Registry/model from the built-in profile).
- **BC-1.06.004–010** — Test backfill (USB mapping, virtual-media math, firmware search, STATUS parse, mouse coalescing, queue priority) + coverage policy (P1.5).

Everything else (113 contracts) formalizes existing v1.0.0 behavior as the L3 baseline.

## 4. Cross-Cutting Concerns
- **Clean-room boundary** — no vendor code/firmware bundled; firmware is user-supplied at runtime (NFR-SEC-01/02).
- **Concurrency model** — one `AsyncStream<AdapterEvent>` seam to the `@MainActor` UI; StarTech 4-thread transport + UVC GCD queues; synchronous fire-and-forget input (NFR-PERF-06/09).
- **Stuck-key safety** — `releaseAllKeys` on every focus loss; ⌘ not forwarded (BC-1.05.018..020).
- **Graceful degradation** — UVC view-only without CH9329; firmware-skip on load failure.
- **Observability** — `AdapterEvent.message/.status`, fps/bandwidth, CLI logs (NFR-OBS-*).

## 5. Non-Functional Requirements
See `prd-supplements/nfr-catalog.md` (Performance, Reliability, Security/clean-room, Observability,
Configurability, Portability + known gaps). Interface surface in
`prd-supplements/interface-definitions.md`; error taxonomy in `prd-supplements/error-taxonomy.md`;
module criticality in `prd-supplements/module-criticality.md`.

## 6. Assumptions
- The reverse-engineered VSP protocol + tile codec are stable for the supported StarTech generations
  (PID 0x8460 gen-1, 0x8463 gen-2) — validated on real hardware.
- A CH9329-based UVC dongle is available to validate the input path before promoting it to supported
  (open question in the brief).
- Homebrew `libusb` at `/opt/homebrew` is present at build time; bundled into the `.app` for users.

## 7. Open Questions
- Notarization stance for v1.1.0 (ad-hoc vs notarized) — not locked in the brief.
- KVM-vs-capture-app positioning given the "serve both equally" decision (naming tension).
- Post-v1.1.0 roadmap order: virtual-camera output vs cross-platform/Windows.
- Capability (CAP-NNN) assignment for each BC is deferred to the architecture phase (BCs currently
  carry `capability: CAP-TBD`).
