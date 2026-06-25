---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-01"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.020: FT Virtual Media Wire Commands — 'c', 'A', 'B', 'G'

## Description
Virtual media is controlled over the VSP protocol with four wire command codes: mount ('c' / `ftConnect`) sends device type and block count; device-initiated read ('A' / `ftRead`) streams data back; device-initiated write ('B' / `ftWrite`) receives data from the device; stop/eject ('G' / `ftStartStop`) is sent by the target when it removes the media. These map to host-side handlers `mountMedia`, `handleFtRead`, `handleFtWrite`, and the ftStartStop eject check.

## Preconditions
1. A `VirtualMedia` instance has been created (for mount, read, write).
2. For `ftRead`/`ftWrite`: `args` contains at least 8 bytes encoding `LE32(startBlock) + LE32(length)`.
3. For `ftStartStop`: `args[0]` encodes a bitmask.

## Postconditions
1. `ftConnect` ('c'): sends `[ftConnect, mediaType, LE32(blockCount)]` where `mediaType = cdrom ? 2 : 1`.
2. `ftRead` ('A'): reads `length` bytes from `media` starting at `startBlock`; bulk-writes to `VSProtocol.Endpoint.dataOut` in up to 65536-byte chunks.
3. `ftWrite` ('B'): bulk-reads `length` bytes from `VSProtocol.Endpoint.dataIn` in up to 65536-byte chunks; calls `media.write(startBlock:, data:)`.
4. `ftStartStop` ('G'): if `args[0] & 3 == 2`, calls `ejectMedia()` (target removed media).
5. `ftStartStop` with any other value: no-op.

## Invariants
1. `ftRead` and `ftWrite` both check `running.get()` per chunk iteration; they exit mid-transfer if the adapter is disconnecting.
2. `ftRead`/`ftWrite` both guard `args.count >= 8` and `device != nil`.
3. The media lock (`mediaLock`) is acquired to get the media reference before I/O.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `ftRead` with no media mounted | `guard let m` fails; handler returns without I/O |
| EC-002 | `ftWrite` with read-only media | `media.write` is a no-op; data received from device is discarded |
| EC-003 | `ftStartStop` with `bits & 3 == 1` (mounted) | No eject |
| EC-004 | `args.count < 8` for ftRead/ftWrite | Guard fails; handler returns immediately |
| EC-005 | `running` becomes false mid-chunk | Loop exits; incomplete transfer |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| Mount ISO: `cdrom=true, blockCount=2048` | Enqueues `[0xc_cmd, 2, LE32(2048)]` | happy-path (mount) |
| `ftStartStop` with `args[0]=2` | `ejectMedia()` called | edge case (eject) |
| `ftRead` with no media | No I/O; returns immediately | edge case |

## Error Handling
- `ftRead`/`ftWrite` swallow `bulkWrite`/`bulkRead` errors with `catch { break }` — partial transfer results in incomplete data on the device side, but no crash.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:129-194, 333-339 |
| Ingest BC | BC-063 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | medium |
| Extraction Date | 2026-06-25 |
| Evidence Type | documentation / guard clause |
