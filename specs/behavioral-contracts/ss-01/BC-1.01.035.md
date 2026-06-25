---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ/AppController.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.035: Settings onChange Triggers menuReconnect

## Description
`SettingsWindowController` is initialized with an `onChange` closure that calls `menuReconnect()`. Any profile or firmware setting change in the Settings window immediately triggers a full reconnect cycle so the new profile/firmware takes effect without requiring a manual Reconnect. This makes settings changes live-apply without an app restart.

## Preconditions
1. `openSettings()` has been called, creating a `SettingsWindowController` with the `onChange` closure.
2. The user saves a change in the Settings window.

## Postconditions
1. `SettingsWindowController.onChange()` is called by the settings window on save.
2. This calls `menuReconnect()` on `AppController`.
3. `menuReconnect()` tears down the current session and calls `tryConnect()` (per BC-1.01.033).

## Invariants
1. The `onChange` closure is set exactly once at `SettingsWindowController` creation.
2. Settings changes always trigger a full reconnect (no partial reload).

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Settings saved while not connected | `menuReconnect()` called; no active adapter to disconnect |
| EC-002 | Settings saved while connecting | `menuReconnect()` tears down in-flight connection; retries |
| EC-003 | Settings window opened twice | Controller is reused (`settingsController == nil` guard); same onChange |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| User changes profile in Settings and saves | `menuReconnect()` called; session reconnects with new profile | happy-path |
| Settings saved with no device present | `menuReconnect()` → `tryConnect()` → `.noAdapter` | edge case |

## Error Handling
No errors. `menuReconnect()` self-handles all failures.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/occ/AppController.swift:471-472 |
| Ingest BC | BC-113 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/occ/AppController.swift |
|------|--------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | assertion |
