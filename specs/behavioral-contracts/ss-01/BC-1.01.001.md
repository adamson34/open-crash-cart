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
# Behavioral Contract BC-1.01.001: StarTech Generation Derivation from PID

## Description
When a StarTech adapter is initialized, its hardware generation (1 or 2) is derived solely from the USB product ID of the discovered device. PID 0x8463 maps to generation 2 (NOTECONS02 current); any other StarTech PID (including 0x8460) maps to generation 1. This generation value governs FPGA firmware file preference order at boot.

## Preconditions
1. A `DiscoveredDevice` with `vendorID == 0x152A` has been passed to `StarTechAdapter.init`.
2. The `productID` field of the device is available and read.

## Postconditions
1. `self.generation == 2` if and only if `device.productID == 0x8463`.
2. `self.generation == 1` for all other product IDs accepted by `StarTechAdapter.canDrive`.
3. The generation value is immutable after initialization.

## Invariants
1. Generation is a pure function of `productID`; no I/O occurs during derivation.
2. The `canDrive` predicate (vendorID match + productIDs set membership) is evaluated before `init` is called; `init` trusts the caller has already validated compatibility.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | PID is 0x8463 | generation = 2 |
| EC-002 | PID is 0x8460 | generation = 1 |
| EC-003 | Any other PID accepted by canDrive | generation = 1 (default) |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| `DiscoveredDevice(productID: 0x8463)` | `adapter.generation == 2` | happy-path (gen-2) |
| `DiscoveredDevice(productID: 0x8460)` | `adapter.generation == 1` | happy-path (gen-1) |
| `DiscoveredDevice(productID: 0x8461)` | `adapter.generation == 1` | edge case (unknown PID → gen-1) |

## Error Handling
No errors are raised during generation derivation. Invalid PIDs are impossible at this point because `canDrive` gates entry; any future additional PID defaults to generation 1.

## Traceability
| Field | Value |
|-------|-------|
| Source | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:43-44 |
| Ingest BC | BC-080 |
| Stories | (filled by story-writer) |

## Source Evidence
| Path | Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift |
|------|-------------------------------------------------------|
| Confidence | high |
| Extraction Date | 2026-06-25 |
| Evidence Type | type constraint / assertion |
