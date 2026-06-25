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
# Behavioral Contract BC-1.01.015: FPGA Upload — 'f' Command, 507-Byte Framing, Length-0 Terminator

## Description
`uploadFPGA` streams the FPGA bitstream to the device as a sequence of framed blocks. Each block is the single-byte command `VSProtocol.Command.fpgaData.rawValue` ('f'), followed by a big-endian 16-bit sequence number, a big-endian 16-bit chunk length, and exactly 507 bytes of payload (zero-padded if the final chunk is smaller). After all data blocks are sent, a final block with chunk length 0 (and 507 zero-pad bytes) signals end-of-stream.

## Preconditions
1. `data` is the fully decompressed FPGA bitstream (`[UInt8]`).
2. The command queue is open and the writer thread is running.
3. `running.get()` is true at the start of upload.
4. `VSProtocol.fpgaBlockSize == 507`.

## Postconditions
1. Each block is `[fpgaData_cmd] + be16(seq) + be16(chunk.count) + 507-byte-payload`.
2. `seq` starts at 0 and increments by 1 per data block (wrapping with `&+= 1`).
3. The payload for non-final blocks is the raw data slice; shorter final data slice is zero-padded to 507 bytes.
4. The terminating block has `be16(chunk.count) == be16(0)` and 507 zero bytes as payload.
5. Each block is enqueued at `.control` priority.
6. If `running.get()` becomes false mid-upload, the loop exits without sending remaining blocks or the terminator.

## Invariants
1. Block payload is always exactly 507 bytes (enforced by zero-padding).
2. The length field encodes the actual data bytes in the chunk, not the padded payload size.
3. The terminator is sent only on normal loop completion (chunk is empty), not on early exit.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `data` is empty | One block enqueued immediately: seq=0, len=0, 507 zero bytes (terminator) |
| EC-002 | `data.count` is a multiple of 507 | Last data block full; followed by separate len=0 terminator block |
| EC-003 | `running` becomes false mid-upload | Upload exits without terminator; device will time out on its side |
| EC-004 | `data.count % 507 != 0` | Last block padded with zeros to 507 bytes |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| 507-byte data | 2 blocks: block(seq=0, len=507, data) + block(seq=1, len=0, zeros) | happy-path |
| 1014-byte data (2×507) | 3 blocks: data,data,terminator with seq 0,1,2 | happy-path |
| 100-byte data | 2 blocks: block(seq=0, len=100, data+407 zeros) + terminator | edge case (partial) |

## Error Handling
- No errors thrown from `uploadFPGA`; queue write failures are invisible (enqueue is best-effort).
- Response to `fpgaGood` / `fpgaBad` from the device validates success; handled in `handleResponse`.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:231-253 |
| Ingest BC | BC-054 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | documentation / assertion |
