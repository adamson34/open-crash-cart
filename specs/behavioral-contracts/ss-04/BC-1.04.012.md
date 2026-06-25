---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ/SettingsWindow.swift"
subsystem: "SS-04"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.04.012: SettingsWindow — New vs. Edit Profile Provenance (ID, Backend, builtIn)

## Description

When constructing a `HardwareProfile` in the editor sheet, three fields are set according to whether the editor was opened for a new profile or an existing one. For new profiles: `id` is generated as `"custom-" + UUID().uuidString.prefix(8).lowercased()`, `backend` defaults to `"dmtz-vsp"`, and `builtIn` is `false`. For edits: `id`, `backend`, and `builtIn` are carried over from the existing profile unchanged. This preserves the identity and provenance of existing profiles through an edit cycle.

## Preconditions

- `presentEditor(for:)` is called with either `nil` (new) or an existing `HardwareProfile` (edit).
- For edit flow: `existing` is a valid profile with non-nil `id`, `backend`, and `builtIn`.

## Postconditions

**New profile (`existing == nil`):**
- `id` = `"custom-" + UUID().uuidString.prefix(8).lowercased()` (8 hex characters, always lowercase, always unique).
- `backend` = `"dmtz-vsp"`.
- `builtIn` = `false`.

**Edit flow (`existing != nil`):**
- `id` = `existing!.id` (unchanged — preserves upsert key).
- `backend` = `existing!.backend` (preserved — not editable in UI).
- `builtIn` = `existing!.builtIn` (preserved — edit does not strip built-in status).

## Invariants

- New profiles always get `builtIn: false`; the UI cannot create built-in profiles.
- New profile IDs always have the `"custom-"` prefix followed by exactly 8 lowercase hex characters.
- `backend` is not exposed as an editable field in the editor UI — it is always inherited or defaulted.
- Editing a built-in profile preserves `builtIn: true` — the edit does not demote it to custom.

## Edge Cases

- EC-001 Two rapid "Add Adapter" clicks produce two profiles with different IDs (UUID collision probability negligible).
- EC-002 Editing the StarTech built-in: `builtIn` stays `true`; ID stays `"startech-notecons02"`.
- EC-003 `UUID().uuidString.prefix(8)` always yields 8 characters (UUID format is fixed); `.lowercased()` ensures lowercase hex digits.

## Canonical Test Vectors

| Flow | existing | Result id prefix | Result backend | Result builtIn |
|---|---|---|---|---|
| New | `nil` | `"custom-"` | `"dmtz-vsp"` | `false` |
| Edit custom | `{id:"custom-abc12345", backend:"dmtz-vsp", builtIn:false}` | `"custom-abc12345"` | `"dmtz-vsp"` | `false` |
| Edit built-in | `{id:"startech-notecons02", backend:"dmtz-vsp", builtIn:true}` | `"startech-notecons02"` | `"dmtz-vsp"` | `true` |

## Error Handling

No errors. UUID generation never fails in Swift on macOS.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/occ/SettingsWindow.swift:233-241` |
| Ingest BC | BC-131 (pass-3-deep-app-layer.md) |
| L2 Invariants | DI-TBD (profile identity immutability through edit) |
| Capability Anchor Justification | CAP-TBD ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.013 — composes with: built-in non-deletable in UI complements this provenance contract
- BC-1.04.007 — calls: upsert uses `id` as the key for replace-or-append

## Architecture Anchors

- `Sources/occ/SettingsWindow.swift:233-241` — `HardwareProfile` constructor in sheet handler

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/occ/SettingsWindow.swift:233-241` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
