# Product Brief: OpenCrashCart

**Author:** Luke Adamson
**Date:** 2026-06-25
**Status:** draft

## Problem Statement

Server and homelab operators rely on **USB crash-cart adapters** to get a headless machine's
screen, keyboard, and mouse when the network is down and SSH/IPMI isn't an option. The
incumbent software for the StarTech NOTECONS02 ("USB Crash Cart Adapter.app") is an
**Intel-only, abandoned Python 2.7/wxPython app**. As macOS ends Intel/Rosetta support, that
app stops working — and Mac users lose console access to their machines entirely. There is no
maintained, native replacement.

Separately, the same class of cheap **USB-video (UVC) capture dongles** (HDMI/VGA→USB, often
paired with a CH9329 serial-HID controller) is widely owned but poorly served on macOS by a
clean, free viewer/recorder.

**Stakes:** without a native tool, Mac-based admins are locked out of physical-console recovery
on Apple Silicon, and a broad set of capture-dongle owners have no polished Mac client.

## Target Users

**Primary (served equally):**
- **Sysadmins / homelab operators** — recovering headless servers, NAS, Proxmox/ESXi boxes via
  a StarTech crash-cart adapter when remote access is unavailable. High technical sophistication;
  value reliability and zero-fuss console access (video + keyboard + mouse + virtual media).
- **Broader UVC-capture users** — owners of inexpensive HDMI→USB dongles (with optional CH9329
  HID) who want a clean Mac viewer with recording, snapshots, OCR, and image enhancement. KVM
  input is a power feature layered on a good capture core. Mixed technical sophistication.

**Secondary:**
- IT field techs needing an ad-hoc, install-light tool.
- Developers/tinkerers extending support to other adapters via user-editable hardware profiles.

## Value Proposition

OpenCrashCart is the **open, clean-room, native Apple-Silicon** replacement for abandoned,
Intel-only crash-cart software — and a polished general USB-capture client in the same app.

Differentiators:
- **Native arm64 Swift + AppKit** — runs where the vendor app no longer can; no Python, no Rosetta.
- **Multi-adapter behind one seam** — StarTech crash-carts (custom VSP protocol + reverse-engineered
  tile video codec) *and* generic UVC dongles (AVFoundation + CH9329), selected by user-editable
  hardware profiles ("bring your own firmware").
- **Clean-room and open** — no vendor code or firmware bundled; MIT-licensed; the protocol/codec
  were independently reverse-engineered and documented.
- **More than a viewer** — virtual media (boot/recover an ISO), OCR copy-from-screen, paste/type,
  on-screen keyboard, recording, snapshots, video tuning/DDC, client-side image enhancement.

**The one thing it must do well:** reliably deliver live screen + keyboard + mouse to a headless
target over the supported adapters, on Apple Silicon, without fuss.

## Success Criteria

This brief defines a **stability / hardening release (v1.1.0 stable)**, not a pivot.

Measurable outcomes:
- The **P1 correctness fixes** from the brownfield ingest are resolved and verified (see Scope):
  Disconnect no longer auto-reconnects within 2s; video desync can request a keyframe; OCR
  failures don't hang the status line; the device registry has a single source of truth.
- **Test backfill**: the currently-untested MEDIUM-confidence contracts (USB error mapping,
  virtual-media block math, firmware search order, STATUS parse, mouse coalescing, command-queue
  priority) gain harness tests; `swift run occ-tests` stays green in CI.
- **UVC + CH9329 path validated** on real hardware (promoted from "experimental" to supported).
- **README has screenshots** and the v1.1.0 stable release is cut.
- No regression in the validated StarTech path (live 1024×768@75Hz proven on real hardware).

MVP = the above. Full vision (deferred): see Out of Scope.

## Scope

### In Scope (v1.1.0 stable)
- Fix P1 bugs surfaced by the ingest:
  - P1.1 Disconnect silently auto-undone by the 2s rescan timer.
  - P1.2 Dormant `needsKeyframe` — wire I-frame request on decoder desync.
  - P1.3 OCR `perform` error swallowed → stuck "Reading text…" status.
  - P1.4 Dual/triple device-matching source of truth → unify.
- P1.5 Test backfill for the untested MEDIUM contracts.
- Validate the UVC + CH9329 backend on real hardware; treat capture as a first-class path
  alongside crash-cart KVM (serve both audiences equally).
- Screenshots + README polish; cut v1.1.0 stable.
- Selected low-risk P2/P3 cleanups (e.g. stale `PlaceholderVideoDecoder` comment, layer leak in
  `USBDevice.close`) as capacity allows.

### Out of Scope (deferred to later milestones)
- **Cross-platform / Windows** build (likely a C#/Avalonia rebuild using the protocol docs as spec).
- **Virtual-camera output** (the main lever to broaden to streamers/conferencing).
- **KVM-over-IP** / network remote access.
- New large features generally; this is a hardening release.
- Notarization / Mac App Store distribution (see Open Questions).

## Constraints

- **Clean-room:** no vendor source code or firmware is bundled or redistributed; firmware is
  supplied by the user at runtime (BYO-firmware). Protocol/codec are independently documented.
- **License/team:** MIT, public GitHub repo, solo maintainer.
- **No Python:** native stack only (Swift + AppKit today); the Python runtime is never reintroduced.
- **Platform:** macOS 13+, Apple Silicon (arm64). UVC capture requires macOS 14+ (`.external`).
- **Build:** SwiftPM under Command Line Tools (no Xcode → no XCTest; custom test harness);
  Homebrew `libusb` bundled into the `.app`.
- **Git/process:** commits must not include a Claude co-author trailer.

## Prior Art & References

- **Reference implementation = the existing OpenCrashCart codebase itself** — fully analyzed via
  the brownfield ingest (`.factory/semport/opencrashcart/`, ~140 behavioral contracts, validated
  PASS/TRUST). This brief's backlog is drawn directly from that ingest's P0–P3 lessons.
- **StarTech NOTECONS02 vendor app** ("USB Crash Cart Adapter.app", Python 2.7/wxPython, Intel-only)
  — the abandoned incumbent; used as a **clean-room behavioral reference only** (decompiled,
  never copied). Protocol in `docs/PROTOCOL.md`, codec in `docs/CODEC.md`.
- **Cheap UVC + CH9329 dongles** — the second supported hardware class (HDMI/VGA→USB + serial-HID).
- **PiKVM** — comparator for the deferred KVM-over-IP direction.

## Open Questions

- **Notarization stance:** prior decision was "don't worry about it" (ad-hoc signing + quarantine
  note), and this was *not* locked as a hard constraint. Confirm whether v1.1.0 stays ad-hoc or
  pursues notarization for lower install friction.
- **Positioning / name tension:** serving sysadmins *and* broader capture users equally creates a
  branding tension ("CrashCart" reads sysadmin-only). Resolve whether the README/positioning should
  foreground the capture-app framing now, or defer until a virtual-camera milestone.
- **Roadmap ordering after v1.1.0:** which deferred bet comes first — virtual-camera output
  (audience reach, low effort) vs cross-platform/Windows (largest reach, largest effort)?
- **UVC validation hardware:** confirm a CH9329 dongle is available to validate the input path
  before promoting it from experimental.
