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
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.014: FPGA File Selection — Profile vs Generation, notFound Error

## Description
`loadFPGABitstream` has two variants. The profile variant uses the profile's `firmwareFiles` list (defaulting to `["ulcvm.fgz", "usbip.fgz"]` if empty) and prepends the profile's `firmwareDir` as an extra search path. The generation variant uses file name priority based on generation: gen-2 tries `["ulcvm.fgz", "usbip.fgz"]`; gen-1 tries `["usbip.fgz", "ulcvm.fgz"]`. If no file is found across all search directories, `FirmwareError.notFound(searched:)` is thrown with the full list of searched absolute paths.

## Preconditions
1. For profile variant: `HardwareProfile` with `firmwareFiles` and optional `firmwareDir` is provided.
2. For generation variant: `generation` is 1 or 2.
3. `searchDirectories` is available.

## Postconditions
1. Profile variant: `files = profile.firmwareFiles.isEmpty ? ["ulcvm.fgz", "usbip.fgz"] : profile.firmwareFiles`.
2. Profile variant: `extra = profile.firmwareDir.map { [$0] } ?? []`.
3. Generation variant: `names = generation >= 2 ? ["ulcvm.fgz", "usbip.fgz"] : ["usbip.fgz", "ulcvm.fgz"]`.
4. Both variants: iterate `names` (or `files`) × `searchDirectories`; return `gunzip(data)` of the first found file.
5. If no file found: throw `FirmwareError.notFound(searched: all_paths)` where `all_paths` is the cross-product of directories × filenames.

## Invariants
1. File name order determines precedence: gen-2 prefers ulcvm over usbip; gen-1 prefers usbip over ulcvm.
2. The notFound error message lists every specific path searched (dir/filename combos), not just directories.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Profile with empty `firmwareFiles` | Defaults to `["ulcvm.fgz", "usbip.fgz"]` |
| EC-002 | Profile with custom `["custom.fgz"]` | Only `custom.fgz` is searched |
| EC-003 | `generation == 1` | `usbip.fgz` tried before `ulcvm.fgz` |
| EC-004 | `generation >= 2` | `ulcvm.fgz` tried before `usbip.fgz` |
| EC-005 | No file found in any directory | `FirmwareError.notFound(searched: […])` with full path list |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `generation=2`, `ulcvm.fgz` present in appSupportDir | Returns decompressed bitstream | happy-path |
| `generation=1`, only `usbip.fgz` present | Returns decompressed `usbip.fgz` | happy-path (gen-1) |
| No .fgz files anywhere | `FirmwareError.notFound(searched: ["/path/ulcvm.fgz", …])` | error |

## Error Handling
- `FirmwareError.notFound(searched:)`: includes all searched absolute paths for user guidance.
- `GzipError` from `gunzip`: propagates directly (file corrupt or not a valid gzip stream).

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift:60-97 |
| Ingest BC | BC-053 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechFirmware.swift |
|------|--------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / documentation |
