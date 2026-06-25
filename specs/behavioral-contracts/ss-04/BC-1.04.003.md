---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.003
title: "HardwareProfile JSON Round-Trip Fidelity and Equatable Conformance"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/HardwareProfile.swift
  - Sources/occ-tests/ProfileTests.swift
ingest_bc: BC-072
---

# BC-1.04.003: HardwareProfile JSON Round-Trip Fidelity and Equatable Conformance

## Description

`HardwareProfile` conforms to `Codable` and `Equatable`. A profile encoded to JSON and decoded back must be equal to the original under `==`. The on-disk `profiles.json` format depends on this guarantee: `ProfileStore` serialises and deserialises profiles via `JSONEncoder`/`JSONDecoder` using the synthesised `Codable` implementation. String fields (including `vendorId` and `productIds`) are stored as their raw string values, not as parsed integers.

## Preconditions

- A `HardwareProfile` value is fully constructed (all fields populated).
- A `JSONEncoder` and matching `JSONDecoder` with default settings are used.
- No custom `encode(to:)` / `init(from:)` implementations exist; synthesis is relied upon.

## Postconditions

- `JSONEncoder().encode(profile)` produces valid UTF-8 JSON without throwing.
- `JSONDecoder().decode(HardwareProfile.self, from: data)` decodes without throwing.
- The decoded value compares equal to the original: `decoded == original`.
- All stored string fields (`vendorId`, `productIds`, `firmwareFiles`, `firmwareDir`) are preserved byte-for-byte.
- Boolean `builtIn` and String `id`, `name`, `backend` round-trip correctly.

## Invariants

- `Equatable` uses value semantics: all stored properties are compared.
- Round-trip does not normalise string representations (e.g. `"0x152A"` stays `"0x152A"`, not `"5418"`).
- `firmwareDir` round-trips as `null` in JSON when `nil`, and as a string when present.

## Edge Cases

- EC-001 `firmwareDir == nil` → JSON key absent or `null`; decoded back to `nil`.
- EC-002 `productIds == []` → JSON empty array; decoded back to `[]`.
- EC-003 `firmwareFiles == []` → JSON empty array; decoded back to `[]`.
- EC-004 `builtIn == true` → JSON `true`; decoded back to `true`.
- EC-005 `vendorId` with mixed case (`"0xAbCd"`) round-trips unchanged — comparison is done on raw string, not parsed integer.
- EC-006 Unicode in `name` field (e.g. Japanese OEM name) round-trips correctly via UTF-8.

## Canonical Test Vectors

| Scenario | Input | Expected after round-trip |
|---|---|---|
| StarTech built-in | `ProfileStore.builtIns.first!` | `decoded == original` |
| Nil firmwareDir | Profile with `firmwareDir: nil` | `firmwareDir` decodes as `nil` |
| Empty productIds | Profile with `productIds: []` | `pids == []` |
| Hex vendorId preserved | `vendorId: "0x152A"` | Decoded `vendorId == "0x152A"` (string unchanged) |

Test vector pinned at `ProfileTests.swift:22-24`.

## Error Handling

`JSONEncoder().encode` is called with `try!` in the test harness — encoding a well-formed `HardwareProfile` must not throw. If decoding fails (corrupt JSON), `ProfileStore` treats it as missing and seeds from built-ins (see BC-1.04.006).

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/HardwareProfile.swift:6` (struct declaration with conformances) |
| Test file:line | `Sources/occ-tests/ProfileTests.swift:22-24` |
| Ingest BC | BC-072 (pass-3-behavioral-contracts.md) |
| L2 Invariants | DI-TBD (on-disk format stability) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") per capabilities.md §CAP-004 |

## Related BCs

- BC-1.04.001 — related: raw strings preserved (not parsed values)
- BC-1.04.006 — feeds: `ProfileStore` depends on decode success for load path
- BC-1.04.009 — feeds: `ProfileStore.writeToDisk` encodes profiles array

## Architecture Anchors

- `Sources/OCCKit/Adapter/HardwareProfile.swift` — `Codable, Equatable` conformances
- `Sources/OCCKit/Adapter/ProfileStore.swift` — `JSONDecoder().decode(Config.self, from: data)`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/HardwareProfile.swift:6` |
| Confidence | HIGH (test-pinned via ProfileTests.swift:22-24) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source + test |
