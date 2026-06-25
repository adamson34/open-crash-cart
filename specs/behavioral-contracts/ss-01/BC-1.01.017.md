---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.017: Virtual Media Geometry — ISO 2048 RO / IMG 512 RW

## Description
`VirtualMedia.init` determines block geometry from the `cdrom` parameter: ISO (cdrom=true) uses 2048-byte blocks and is read-only; IMG (cdrom=false) uses 512-byte blocks and is read-write. `blockCount` is computed as `floor(fileSize / blockSize)`. Initialization fails (returns nil) if the file attributes cannot be read or the file size is zero.

## Preconditions
1. `path` points to a readable file.
2. `cdrom` is true for ISO/CD-ROM images, false for disk images.

## Postconditions
1. `blockSize = cdrom ? 2048 : 512`.
2. `readOnly = cdrom`.
3. `blockCount = UInt32(fileSize / UInt64(blockSize))`.
4. ISO files are opened read-only (`FileHandle(forReadingAtPath:)`).
5. IMG files are opened for updating (`FileHandle(forUpdatingAtPath:)`) falling back to read-only if updating fails.
6. Returns nil if `fileSize == 0` or file attributes are inaccessible.

## Invariants
1. `blockSize` is always either 512 or 2048; no other values are possible.
2. `blockCount` uses integer division; trailing bytes that don't fill a full block are excluded.
3. `readOnly` state cannot change after initialization.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | ISO file, 4 MB | `blockSize=2048`, `readOnly=true`, `blockCount=2048` |
| EC-002 | IMG file, 1 MB | `blockSize=512`, `readOnly=false`, `blockCount=2048` |
| EC-003 | File size not a multiple of blockSize | Last partial block excluded from `blockCount` |
| EC-004 | File size is 0 | `init` returns nil |
| EC-005 | File not accessible (no permissions) | `init` returns nil (attributes read fails) |
| EC-006 | IMG file opened read-only (no write perms) | `FileHandle(forUpdatingAtPath:)` returns nil; falls back to read-only handle; `readOnly` is still false (per `cdrom`) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| 720 KB ISO file | `blockSize=2048`, `blockCount=360`, `readOnly=true` | happy-path (ISO) |
| 1 MB IMG file | `blockSize=512`, `blockCount=2048`, `readOnly=false` | happy-path (IMG) |
| 0-byte file | `init` returns nil | edge case |

## Error Handling
- All failures return nil from the failable initializer.
- No errors thrown.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift:16-30 |
| Ingest BC | BC-060 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift |
|------|-----------------------------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | type constraint / assertion |
