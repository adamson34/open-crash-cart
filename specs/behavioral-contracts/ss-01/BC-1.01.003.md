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
lifecycle_status: active
introduced: v1.0.0
---
# Behavioral Contract BC-1.01.003: StarTech Boot Handshake Sequence — v, s, g then FPGA

## Description
The boot thread sends three control commands in order — `getVersions` ('v'), `getStatus` ('s'), `startVStream` ('g') — and then attempts to load and upload the FPGA bitstream. All four commands are enqueued as `.control` priority onto the command queue; the FPGA upload follows only if the bitstream loads without error. A failed bitstream load emits a skip message and does not abort the session.

## Preconditions
1. `boot()` is called from the dedicated "OpenCrashCart-Boot" thread after the writer/response/video threads are already running.
2. The command queue is open and the writer thread is draining it.
3. `self.profile` and `self.generation` are set (from `init`).

## Postconditions
1. `VSPack.command(.getVersions)` is enqueued first.
2. `VSPack.command(.getStatus)` is enqueued second.
3. `VSPack.command(.startVStream)` is enqueued third.
4. If `profile` is non-nil, `StarTechFirmware.loadFPGABitstream(profile:)` is called; otherwise `loadFPGABitstream(generation:)` is called.
5. On successful bitstream load, a `.message` event with KB count is emitted, then `uploadFPGA` is called.
6. On failed bitstream load (any `Error`), `.message("FPGA load skipped: \(error)")` is emitted and `uploadFPGA` is NOT called.

## Invariants
1. The three control commands are always enqueued regardless of FPGA load outcome.
2. `getVersions` always precedes `getStatus` which always precedes `startVStream` in the queue.
3. FPGA upload is attempted at most once per `boot()` call.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | Profile is nil | Falls back to `loadFPGABitstream(generation:)` |
| EC-002 | Profile is set | Uses `loadFPGABitstream(profile:)` |
| EC-003 | Bitstream file not found | Skip message emitted; v/s/g still sent |
| EC-004 | `running` flag becomes false mid-boot | `uploadFPGA` checks `running.get()` per block; upload exits early |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `profile=nil, generation=2`, bitstream found | Queue: [v, s, g, …FPGA blocks…]; message "Uploading FPGA bitstream (N KB)…" emitted | happy-path |
| `profile=nil`, bitstream not found | Queue: [v, s, g]; message "FPGA load skipped: …" emitted | edge case |
| `profile` set with custom firmwareFiles | Queue: [v, s, g, …FPGA blocks…]; profile path used | happy-path (profile) |

## Error Handling
- `FirmwareError.notFound` is caught by the `do/catch` in `boot()` and produces a `.message` event.
- All other `Error` types from firmware loading are also caught and produce a `.message` event.
- Neither case throws out of `boot()`; the session continues.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:215-229 |
| Ingest BC | BC-082 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | guard clause / assertion |
