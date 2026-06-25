---
document_type: behavioral-contract
level: L3
version: "1.1"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.005: Harness Test Exists Verifying Virtual-Media Block Math Including Zero-Pad and RO Guard (Ingest BC-060..062)

## Description
A test section covering virtual-media geometry and I/O must exist in the `occ-tests` harness and pass. The test verifies three related behaviors: (1) geometry derivation (`blockCount = UInt32(fileSize / blockSize)`, ISO → 2048 bytes/block read-only, IMG → 512 bytes/block read-write); (2) reads that extend beyond the file return zero-padded data for the out-of-range portion; (3) write calls on a read-only (ISO) or closed media image are no-ops and return without error. These behaviors existed in v1.0.0 code (`VirtualMedia.swift`) but had no harness coverage. The test must use real temporary files in `NSTemporaryDirectory()` — `VirtualMedia` is filesystem-bound via `FileHandle` and cannot be exercised with pure in-memory data. This is deterministic temp-file I/O (known size, content, lifecycle), not an integration test.

## Preconditions
1. A test function (e.g., `runVirtualMediaTests(_:)`) is registered in `main.swift` and calls a section such as `t.section("Virtual media")`.
2. **Public-API delta required:** `VirtualMedia` in `Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift` is currently `internal` (`final class VirtualMedia`, line 6). It must be promoted to `public` so the `occ-tests` target (plain `import OCCKit`, no `@testable`) can construct and exercise it. The initializer signature `init?(path: String, cdrom: Bool)` must also be `public`.
3. Small ISO and IMG fixture files are created via `NSTemporaryDirectory()` within the test (e.g., 2048-byte ISO body written as `Data`, 1024-byte IMG body).
4. The read-only property is `readOnly: Bool` (NOT `isReadOnly`) — this is the correct field name per `VirtualMedia.swift:9`.

## Postconditions
1. Assertions verify ISO geometry: `blockSize == 2048`, `blockCount == UInt32(fileSize / 2048)`, `readOnly == true`.
2. Assertions verify IMG geometry: `blockSize == 512`, `blockCount == UInt32(fileSize / 512)`, `readOnly == false`.
3. A read beyond end-of-file returns a buffer padded with `0x00` bytes for the overrun portion (per `read(startBlock:length:)` contract in `VirtualMedia.swift:33-43`).
4. A read on a closed image returns an all-zero buffer of the requested size.
5. A write call on an ISO image is a no-op; the underlying temp file is not modified (checked by re-reading the file).
6. A write call on a closed image is a no-op; no error is thrown.
7. Close is idempotent: calling `close()` twice does not crash or error.
8. All assertions pass; `swift run occ-tests` exits 0.

## Invariants
1. `blockCount` is `UInt32(size / UInt64(blockSize))` — integer division (no rounding, consistent with `VirtualMedia.swift:29`).
2. Zero-padding is applied at the read layer, not in the stored file.
3. The `readOnly` guard is evaluated before any write I/O is attempted (per `VirtualMedia.swift:47`).
4. Tests use real temp files (deterministic, known content); no mock FileHandle or in-memory substitute is used.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Read exactly at end of file | Returns data up to last byte; no zero-pad needed |
| EC-002 | Read starting at EOF (startBlock * blockSize == fileSize) | Returns all-zero buffer of requested length |
| EC-003 | Read spanning EOF | Returns valid prefix + zero-padded suffix |
| EC-004 | Write to ISO (`readOnly == true`) | No-op; returns without error; file unchanged |
| EC-005 | Write to closed IMG | No-op; returns without error |
| EC-006 | `close()` called twice | Second call is no-op; no error |
| EC-007 | File size is not a multiple of blockSize | `blockCount = UInt32(fileSize / UInt64(blockSize))` (integer division; tail bytes inaccessible) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| ISO temp file, 2048-byte body, `cdrom: true` | `blockSize=2048`, `blockCount=1`, `readOnly=true` | happy-path (geometry) |
| IMG temp file, 1024-byte body, `cdrom: false` | `blockSize=512`, `blockCount=2`, `readOnly=false` | happy-path (geometry) |
| Read block 0 from 2048-byte ISO | Returns exact 2048 bytes matching file content | happy-path (read) |
| Read block 1 from 2048-byte ISO (past EOF) | Returns 2048 zero bytes | edge (zero-pad) |
| Write block 0 to ISO | No-op; no error thrown; file content unchanged | edge (RO guard) |
| Close ISO; read block 0 | Returns 2048 zero bytes | edge (closed zero-pad) |
| Close ISO; write block 0 | No-op; no error thrown | edge (closed RO guard) |

## Error Handling
No errors are thrown from zero-pad reads or no-op writes — these are silent success paths. A test that checks for an unexpected error thrown here should fail (the contract is error-free for these cases). Temp files must be cleaned up (e.g., `defer { try? FileManager.default.removeItem(atPath: ...) }`) to avoid leaving artifacts.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift:6` (class declaration, internal); `:9` (`readOnly` property name); `:16-30` (init geometry); `:33-43` (zero-pad read); `:45-49` (RO write guard) |
| Ingest BC | BC-060 ("geometry ISO 2048 RO / IMG 512 RW; blockCount=size/blockSize"), BC-061 ("read zero-pads short/closed"), BC-062 ("write no-op if RO/closed; close idempotent") — opencrashcart-pass-3-behavioral-contracts.md |
| Public-API delta | Promote `VirtualMedia` and its `init?(path:cdrom:)` from `internal` to `public` |
| Stories | TBD |
| Capability Anchor Justification | `capability: CAP-TBD` — virtual media I/O and geometry per Pass-3 BC-060..062; capability ID to be assigned after capabilities.md is updated |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift` |
| Confidence | HIGH (contracts derived from code constants and control flow per Pass-3) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Code control-flow analysis (Pass-3 BCs BC-060, BC-061, BC-062) |

## Related BCs
- BC-1.06.001 — harness infrastructure (depends on)
- BC-1.06.010 — coverage policy (depends on)

## Architecture Anchors
- `Sources/OCCKit/Adapters/StarTech/VirtualMedia.swift` — virtual-media implementation

## Story Anchor
TBD

## VP Anchors
TBD
