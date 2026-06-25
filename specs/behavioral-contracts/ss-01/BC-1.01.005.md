---
document_type: behavioral-contract
level: L3
version: "1.0"
status: deprecated
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift"
subsystem: "SS-01"
lifecycle_status: deprecated
introduced: v1.0.0
deprecated: v1.1.0-spec-revision
deprecated_by: adversarial-review B9/F-02 (duplicate STATUS-parse contract)
replacement: BC-1.02.010
---
# Behavioral Contract BC-1.01.005: STATUS Packet Parse, State Derivation, and On-Change Emit (DEPRECATED — superseded by BC-1.02.010)

## Description

**DEPRECATED.** STATUS-packet parsing (`parseStatus`, StarTechAdapter.swift:347-401) is canonically
contracted in **[BC-1.02.010](../ss-02/BC-1.02.010.md)** under SS-02, which owns "STATUS → state"
per PRD §2. This SS-01 contract was a duplicate of the same code path (adversary B9/F-02). Its unique
detail — the CC1 `miscLen = 9` / CC2 `miscLen = 15` mapping — has been folded into BC-1.02.010.

Do not implement against this file. All preconditions, postconditions, edge cases, and test vectors
for STATUS parse, state derivation (`.live`/`.noVideo`/`.connecting`), the `words*16*1000/ticks` bps
formula, signed misc decoding, and on-change emit (`differs` ignores `bytesPerSecond`) live in
BC-1.02.010.

## Traceability

| Field | Value |
|-------|-------|
| Replacement | BC-1.02.010 (canonical) |
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:347-401 |
| Ingest BC | BC-084 |
| Deprecated by | adversarial-review B9/F-02 |
