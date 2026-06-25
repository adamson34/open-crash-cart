---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.015
title: "SettingsWindow — Firmware Import: Copy into App Support and Repoint Store Directory"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/occ/SettingsWindow.swift
ingest_bc: BC-134
domain_facts: [BC-134]
---

# BC-1.04.015: SettingsWindow — Firmware Import: Copy into App Support and Repoint Store Directory

## Description

The "Import Firmware…" action lets the user copy one or more `.fgz` firmware files into OpenCrashCart's own App Support firmware directory, eliminating the need for the vendor application. After the user selects files in an NSOpenPanel, each file is copied to `<applicationSupportFirmwareDir>/<filename>`, and then `ProfileStore.firmwareDirectory` is set to that destination directory. All file operations use `try?` — partial failure (e.g. one of several files fails to copy) is silently absorbed.

## Preconditions

- The user has clicked "Import Firmware…" in the Settings window.
- The NSOpenPanel is configured for file selection, allowing multiple selection, with `.fgz` and `.data` content types.
- The user selects one or more files and clicks "Import" (`.OK` response).
- `ProfileStore.shared.applicationSupportFirmwareDir` yields a valid path string.

## Postconditions

- The destination directory is created: `try? FileManager.default.createDirectory(atPath: dest, withIntermediateDirectories: true)`.
- For each selected `url` in `panel.urls`:
  - `target` = `dest + "/" + url.lastPathComponent`.
  - Any existing file at `target` is removed: `try? FileManager.default.removeItem(atPath: target)`.
  - File is copied: `try? FileManager.default.copyItem(atPath: url.path, toPath: target)`.
- `ProfileStore.shared.firmwareDirectory` is set to `dest` (the App Support firmware dir).
- `refresh()` and `onChange()` are called after all copies complete.

## Invariants

- Destination is always `applicationSupportFirmwareDir` — not a user-chosen arbitrary path.
- Pre-existing files with the same name are deleted before copying (overwrite semantics).
- `ProfileStore.firmwareDirectory` is always updated to the App Support dir, even if some or all copies fail (known reliability gap: directory is set even on partial failure).
- The operation always concludes with a `refresh()` + `onChange()` call.

## Edge Cases

- EC-001 Single file selected, copy succeeds → firmwareDirectory set; UI refreshed.
- EC-002 Multiple files selected, all succeed → all copied; firmwareDirectory set.
- EC-003 Single file selected, copy fails (`try?` swallows) → firmwareDirectory still set to App Support dir (empty or partial).
- EC-004 Destination directory creation fails (`try?` swallows) → subsequent copies will also fail; firmwareDirectory still set.
- EC-005 User cancels NSOpenPanel → handler returns at `guard resp == .OK`; nothing happens.
- EC-006 File with same name already exists → removed first, then fresh copy (overwrite).

## Canonical Test Vectors

| Scenario | Expected post-state |
|---|---|
| Import `ulcvm.fgz` succeeds | File at `<AppSupport>/OpenCrashCart/firmware/ulcvm.fgz`; `firmwareDirectory` = that dir |
| Import fails (disk full) | `firmwareDirectory` still set; file may not be present |
| Cancel panel | No change |

## Error Handling

All `FileManager` operations and `ProfileStore.firmwareDirectory` assignment use `try?` or are non-throwing. Partial failure is invisible to the user. This is a known risk flagged in Pass 3 (BC-134: "silent try? — partial-failure risk").

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/occ/SettingsWindow.swift:184-203` |
| Ingest BC | BC-134 (pass-3-deep-app-layer.md) |
| L2 Invariants | DI-TBD (firmware import reliability) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") per capabilities.md §CAP-004 |

## Related BCs

- BC-1.04.008 — calls: `firmwareDirectory` setter triggers immediate persist
- BC-1.04.004 — feeds: imported directory becomes the store-wide Tier 2 firmware path

## Architecture Anchors

- `Sources/occ/SettingsWindow.swift:184-203` — `importFirmware()` action

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/occ/SettingsWindow.swift:184-203` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
