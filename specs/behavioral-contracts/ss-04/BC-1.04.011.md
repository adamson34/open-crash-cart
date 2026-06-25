---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.011
title: "SettingsWindow — CSV Field Parsing, Firmware Default, and Profile Construction"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/occ/SettingsWindow.swift
ingest_bc: BC-130
domain_facts: [BC-130]
---

# BC-1.04.011: SettingsWindow — CSV Field Parsing, Firmware Default, and Profile Construction

## Description

After the empty-name guard passes (BC-1.04.010), `SettingsWindowController` parses the Product IDs and Firmware Files fields as comma-separated values: split on `,`, trim whitespace from each token, and filter out empty tokens. If the resulting `firmwareFiles` array is empty (the user left the field blank or entered only commas), it defaults to `["ulcvm.fgz"]`. The Vendor ID is stored as the raw string with no hex-format validation. The firmware folder (`dir`) is stored as `nil` when the trimmed string is empty.

## Preconditions

- The empty-name guard has passed (trimmed name is non-empty).
- `fields.pids`, `fields.files`, `fields.vid`, and `fields.dir` are `NSTextField` instances whose `stringValue` may be any string.

## Postconditions

- `pids` = `fields.pids.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }` — a `[String]`.
- `files` = same pipeline applied to `fields.files.stringValue` — a `[String]`.
- `firmwareFiles` in the constructed profile = `files.isEmpty ? ["ulcvm.fgz"] : files`.
- `vendorId` = `fields.vid.stringValue.trimmingCharacters(in: .whitespaces)` — raw string, NO hex validation.
- `firmwareDir` = `dir.isEmpty ? nil : dir` where `dir = fields.dir.stringValue.trimmingCharacters(in: .whitespaces)`.
- The constructed `HardwareProfile` is passed to `ProfileStore.shared.upsert(_:)`.

## Invariants

- CSV parsing is identical for both PID and firmware fields.
- Empty tokens (e.g. from trailing commas like `"0x8460,"`) are filtered out.
- Firmware default `["ulcvm.fgz"]` is applied only when the resulting array is empty, not when the field is non-empty.
- `vendorId` is stored as raw string — `HardwareProfile.parse` handles the actual format at matching time.
- No validation is performed on PID or VID format at this layer (gap noted in BC-130).

## Edge Cases

- EC-001 PIDs field `"0x8460, 0x8463"` → `["0x8460", "0x8463"]`.
- EC-002 PIDs field `"0x8460,"` (trailing comma) → `["0x8460"]` (empty token filtered).
- EC-003 Files field `""` → `[]` → defaulted to `["ulcvm.fgz"]`.
- EC-004 Files field `","` → `[]` after filtering → defaulted to `["ulcvm.fgz"]`.
- EC-005 Files field `"a.fgz, b.fgz"` → `["a.fgz", "b.fgz"]` (no default applied).
- EC-006 Dir field `""` → `firmwareDir: nil`.
- EC-007 Dir field `"  /custom/fw  "` → `firmwareDir: "/custom/fw"` (trimmed).
- EC-008 VID field `"garbage"` → stored as `"garbage"`; `vid` will compute 0 at match time (BC-1.04.001).

## Canonical Test Vectors

| PIDs input | Files input | firmwareFiles | pids array |
|---|---|---|---|
| `"0x8460, 0x8463"` | `"ulcvm.fgz"` | `["ulcvm.fgz"]` | `["0x8460","0x8463"]` |
| `"0x8460,"` | `""` | `["ulcvm.fgz"]` | `["0x8460"]` |
| `""` | `""` | `["ulcvm.fgz"]` | `[]` |
| `"0x8460"` | `"a.fgz, b.fgz"` | `["a.fgz","b.fgz"]` | `["0x8460"]` |

## Error Handling

No errors are raised. Invalid VID/PID strings are silently stored; the profile will simply never match a real device. This is a known gap flagged in BC-130 (no hex validation in SettingsWindow).

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/occ/SettingsWindow.swift:230-241` |
| Ingest BC | BC-130 (pass-3-deep-app-layer.md) |
| L2 Invariants | DI-TBD (profile field integrity) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.010 — precedes: empty-name guard runs before this path
- BC-1.04.007 — calls: upsert is invoked with the constructed profile

## Architecture Anchors

- `Sources/occ/SettingsWindow.swift:230-244` — `presentEditor` sheet handler body

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/occ/SettingsWindow.swift:230-241` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
