---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.014
title: "SettingsWindow — Live USB Presence Dot, Graceful Enumeration Failure"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/occ/SettingsWindow.swift
ingest_bc: BC-133
domain_facts: [BC-133]
---

# BC-1.04.014: SettingsWindow — Live USB Presence Dot, Graceful Enumeration Failure

## Description

Each profile row in the Settings window shows a 10×10 colored dot indicating whether the corresponding USB device is currently connected. On every `refresh()` call, `enumerateUSBDevices()` is called with `try?`. If enumeration succeeds, a profile is considered detected if any discovered device matches via `profile.matches(vendorID:productID:)`; the dot is rendered green. If no match, the dot is dark gray. If enumeration throws (returns `nil` via `try?`), `present` is an empty array and all dots render gray — the UI degrades gracefully without crashing.

## Preconditions

- `refresh()` is called (on the main thread, from Settings window lifecycle).
- `enumerateUSBDevices()` may succeed (returning `[DiscoveredDevice]`) or throw (resulting in `nil` from `try?`).
- `ProfileStore.shared.profiles` returns the current profile list.

## Postconditions

- `present` = `(try? enumerateUSBDevices()) ?? []`.
- For each profile: `detected = present.contains { profile.matches(vendorID: $0.vendorID, productID: $0.productID) }`.
- Dot color: `detected ? Theme.shared.accentGreen : NSColor(white: 0.3, alpha: 1)`.
- Dot dimensions: 10×10 pt, `cornerRadius = 5` (circular).
- If enumeration fails: all dots are gray; no error UI, no crash.

## Invariants

- Dot color has exactly two states: green (detected) or gray (not detected / enumeration failure).
- Enumeration failure is silently absorbed; it is not distinguishable from "no device present" in the UI.
- The dot is computed fresh on every `refresh()` call; it is not cached between refreshes.
- `profile.matches` uses the same logic as the main adapter matching path (BC-1.04.002).

## Edge Cases

- EC-001 Enumeration succeeds, device present → green dot.
- EC-002 Enumeration succeeds, device not present → gray dot.
- EC-003 Enumeration throws (permission denied, IOKit error) → `present = []` → all dots gray.
- EC-004 Multiple profiles, one matches a connected device → that row green; others gray.
- EC-005 Same physical device matches multiple profiles (overlapping PID ranges) → both rows show green.

## Canonical Test Vectors

| `enumerateUSBDevices` result | Profile matches | Dot color |
|---|---|---|
| `[{0x152A, 0x8463}]` | StarTech profile matches | green |
| `[{0x152A, 0x8463}]` | Custom profile does not match | gray |
| throws → `nil` | N/A | gray (all profiles) |
| `[]` | N/A | gray |

## Error Handling

`try?` absorbs enumeration errors. No alert, no log, no distinct visual state for error vs. not-connected.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/occ/SettingsWindow.swift:110-125` |
| Ingest BC | BC-133 (pass-3-deep-app-layer.md) |
| L2 Invariants | DI-TBD (UI graceful degradation on hardware error) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.002 — used: `profile.matches()` drives the detected flag

## Architecture Anchors

- `Sources/occ/SettingsWindow.swift:110-115` — `refresh()` enumeration call
- `Sources/occ/SettingsWindow.swift:118-126` — `makeProfileRow` dot construction

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/occ/SettingsWindow.swift:110-125` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
