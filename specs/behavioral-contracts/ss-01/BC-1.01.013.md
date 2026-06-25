---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift"
subsystem: "SS-01"
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.013: Firmware Search-Directory Order

## Description
`StarTechFirmware.searchDirectories(extra:)` builds the ordered list of directories to search for firmware files. The order is: (1) any `extra` dirs passed by the profile, (2) `OCC_FIRMWARE_DIR` environment variable, (3) the ProfileStore configured firmware directory, (4) the app-support firmware directory, (5) the vendor app bundle resources, (6) `~/data`, (7) `~/Library/Application Support/USB Crash Cart Adapter/data`. Directories are searched in this fixed priority order; the first file match wins.

## Preconditions
1. Called from `loadFPGABitstream(profile:)` or `loadFPGABitstream(generation:)`.
2. `ProcessInfo.processInfo.environment` is readable.
3. `ProfileStore.shared` is initialized.

## Postconditions
1. `extra` directories come first if non-empty.
2. `OCC_FIRMWARE_DIR` env var is appended next if set.
3. `ProfileStore.shared.firmwareDirectory` is appended if non-nil and non-empty.
4. `ProfileStore.shared.applicationSupportFirmwareDir` is always appended.
5. The three vendor/home paths are always appended last in fixed order:
   - `/Applications/USB Crash Cart Adapter.app/Contents/Resources/data`
   - `<home>/data`
   - `<home>/Library/Application Support/USB Crash Cart Adapter/data`

## Invariants
1. At least three directories (app-support + two vendor paths) are always in the list.
2. The same list is used for both the search and the `notFound` error message.
3. `OCC_FIRMWARE_DIR` always precedes ProfileStore dirs when both are set.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `OCC_FIRMWARE_DIR` not set | Skipped; list continues with ProfileStore |
| EC-002 | `ProfileStore.shared.firmwareDirectory` is nil | Skipped |
| EC-003 | `extra` is empty | First item becomes `OCC_FIRMWARE_DIR` or ProfileStore dir |
| EC-004 | `extra` contains multiple paths | All prepended before env var |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `extra=[]`, no env var, no profile dir | `[appSupportDir, vendorBundle, home/data, home/AppSupport/…]` | happy-path |
| `OCC_FIRMWARE_DIR="/custom"` set | `/custom` at index 0 (no extra), before profileStore entries | edge case |
| `extra=["/profile/fw"]` | `/profile/fw` first, then env/profile/etc. | edge case |

## Error Handling
No errors thrown from `searchDirectories`. If no file is found across all directories, `FirmwareError.notFound(searched:)` is thrown by `loadFPGABitstream`, with the searched paths list built from `searchDirectories`.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift:32-48 |
| Ingest BC | BC-052 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift |
|------|--------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | documentation / assertion |
