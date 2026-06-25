---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/OCCKit/Adapter/HardwareProfile.swift, Sources/occ-tests/ProfileTests.swift"
subsystem: "SS-04"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---

# BC-1.04.002: HardwareProfile.matches() — Fail-Closed VID+PID Conjunction

## Description

`HardwareProfile.matches(vendorID:productID:)` returns `true` if and only if the incoming USB VID equals the profile's parsed `vid` AND the incoming PID is contained in the profile's parsed `pids` array. Both conditions must hold simultaneously; partial matches are rejected. An unparseable profile entry (vid=0 or pids empty) results in no match (fail-closed semantics).

## Preconditions

- `vendorID` and `productID` are `UInt16` values from a discovered USB device.
- The profile's `vendorId` and `productIds` strings have been parsed via `HardwareProfile.parse(_:)` (see BC-1.04.001).
- `pids` may be empty if `productIds` is empty.

## Postconditions

- Returns `true` iff `vid == vendorID && pids.contains(productID)`.
- Returns `false` when `vid != vendorID`, even if `productID` matches.
- Returns `false` when `pids.isEmpty` (no product IDs registered).
- Returns `false` when `vid == 0` (parse failure default), preventing spurious matches against VID 0.

## Invariants

- The function is pure and side-effect-free.
- Conjunction is strict: one mismatch is sufficient to return `false`.
- `pids.contains` uses value equality on `UInt16` — order-independent.

## Edge Cases

- EC-001 Matching VID, non-matching PID → `false`.
- EC-002 Non-matching VID, matching PID → `false`.
- EC-003 Both matching → `true`.
- EC-004 `pids` empty → always `false` regardless of VID.
- EC-005 `vid == 0` (parse failure) → `false` unless device VID happens to be 0x0000 (degenerate hardware; effectively impossible with USB spec).
- EC-006 Profile has multiple PIDs; one matches → `true` (StarTech gen-1 0x8460 and gen-2 0x8463 both listed).

## Canonical Test Vectors

| vendorID | productID | Profile pids | Expected | Notes |
|---|---|---|---|---|
| `0x152A` | `0x8463` | `[0x8460, 0x8463]` | `true` | StarTech gen-2 — ProfileTests:17 |
| `0x152A` | `0x8460` | `[0x8460, 0x8463]` | `true` | StarTech gen-1 — ProfileTests:18 |
| `0x152A` | `0x9999` | `[0x8460, 0x8463]` | `false` | Unknown PID — ProfileTests:19 |
| `0x0001` | `0x8460` | `[0x8460, 0x8463]` | `false` | Wrong VID |
| `0x152A` | `0x8460` | `[]` | `false` | Empty pids list |

## Error Handling

No error cases; the function always returns a `Bool`. Fail-closed: uncertain or missing configuration produces `false`, so an unparseable profile does not accidentally claim ownership of a connected device.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/HardwareProfile.swift:32-34` |
| Test file:line | `Sources/occ-tests/ProfileTests.swift:16-19` |
| Ingest BC | BC-071 (pass-3-behavioral-contracts.md) |
| L2 Invariants | DI-TBD (fail-closed device matching) |
| Capability Anchor Justification | CAP-TBD ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.001 — depends on: `vid`/`pids` produced by hex/decimal parser
- BC-1.04.005 — composes with: `ProfileStore.match()` calls this on each stored profile

## Architecture Anchors

- `Sources/OCCKit/Adapter/HardwareProfile.swift` — `matches(vendorID:productID:)`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/HardwareProfile.swift:32-34` |
| Confidence | HIGH (test-pinned via ProfileTests.swift) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source + test |
