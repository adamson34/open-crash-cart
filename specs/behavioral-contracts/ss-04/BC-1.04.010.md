---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.010
title: "SettingsWindow — Empty Name Aborts Profile Save"
origin: brownfield
subsystem: SS-04
capability: CAP-TBD
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/occ/SettingsWindow.swift
ingest_bc: BC-129
domain_facts: [BC-129]
---

# BC-1.04.010: SettingsWindow — Empty Name Aborts Profile Save

## Description

When the user clicks "Save" in the profile editor alert sheet, `SettingsWindowController` trims whitespace from the Name field and guards against an empty result. If the trimmed name is empty, the save handler returns immediately without creating or updating any profile — no `upsert` is called, no disk write occurs, and the settings window state is unchanged.

## Preconditions

- The profile editor NSAlert is presented (either for new or edit flow).
- The user has clicked the "Save" button (`.alertFirstButtonReturn`).
- `fields.name.stringValue` may be empty, whitespace-only, or contain a valid name.

## Postconditions

- If `name.trimmingCharacters(in: .whitespaces).isEmpty` is `true`: the handler returns immediately; `ProfileStore.shared.upsert` is NOT called; the profiles list is NOT refreshed; `onChange` is NOT called.
- If the trimmed name is non-empty: the profile is constructed and `upsert` is called (see BC-1.04.011 for full construction logic).

## Invariants

- The guard is applied after trimming; a name consisting solely of spaces is treated as empty.
- The check applies identically to both the "Add" (new profile) and "Edit" (existing profile) flows.
- Cancelling the alert (non-`.alertFirstButtonReturn` response) already exits the handler before this guard; the guard only activates on Save.

## Edge Cases

- EC-001 Name field is `""` (empty) → save aborted.
- EC-002 Name field is `"   "` (spaces only) → trimmed to `""` → save aborted.
- EC-003 Name field is `"  My Adapter  "` → trimmed to `"My Adapter"` → save proceeds.
- EC-004 Edit flow: existing profile has a valid name; user clears it and clicks Save → aborted; profile unchanged.
- EC-005 Tab character as sole content → trimmed to `""` → save aborted (`.whitespaces` includes tab on macOS).

## Canonical Test Vectors

| Name field value | Trimmed result | Save proceeds? |
|---|---|---|
| `""` | `""` | No |
| `"  "` | `""` | No |
| `"StarTech"` | `"StarTech"` | Yes |
| `"  StarTech  "` | `"StarTech"` | Yes |

## Error Handling

No error or alert is presented to the user on empty-name abort. The dialog sheet remains open implicitly (the sheet is dismissed after the handler returns regardless), so the user sees no explicit feedback — a known UX gap noted in the ingest. The abort is silent.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/occ/SettingsWindow.swift:228-229` |
| Ingest BC | BC-129 (pass-3-deep-app-layer.md) |
| L2 Invariants | DI-TBD (profile name must not be empty) |
| Capability Anchor Justification | CAP-TBD ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.011 — the succeeding path when name is non-empty (CSV parsing + profile construction)

## Architecture Anchors

- `Sources/occ/SettingsWindow.swift:226-244` — `presentEditor` sheet handler

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/occ/SettingsWindow.swift:228-229` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
