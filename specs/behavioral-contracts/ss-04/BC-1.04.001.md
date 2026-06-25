---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.001
title: "HardwareProfile VID/PID String Parsing — Hex or Decimal, Default 0"
origin: brownfield
subsystem: SS-04
capability: CAP-004
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapter/HardwareProfile.swift
  - Sources/occ-tests/ProfileTests.swift
ingest_bc: BC-070
---

# BC-1.04.001: HardwareProfile VID/PID String Parsing — Hex or Decimal, Default 0

## Description

`HardwareProfile` stores `vendorId` and `productIds` as raw strings (e.g. `"0x152A"` or `"5418"`). The computed properties `vid` and `pids` parse those strings through `HardwareProfile.parse(_:)`, which accepts both `0x`-prefixed hexadecimal and plain decimal representations. An unparseable string silently yields `0` rather than throwing.

## Preconditions

- A `HardwareProfile` instance has been constructed with non-nil `vendorId` and `productIds` strings.
- Strings may contain leading/trailing whitespace.
- Strings are either `"0x…"` / `"0X…"` (hex) or digit-only (decimal); any other form is treated as unparseable.

## Postconditions

- `vid` returns `UInt16(s.dropFirst(2), radix: 16) ?? 0` when the trimmed string lowercased has prefix `"0x"`.
- `vid` returns `UInt16(s) ?? 0` for decimal-only strings.
- `pids` maps each element of `productIds` through the same rule, returning a `[UInt16]`.
- Whitespace is stripped before parsing; case of the `0x` prefix is ignored.
- Any string that cannot be converted returns `0` — never throws or crashes.

## Invariants

- Parse is pure and stateless; the same string always produces the same `UInt16`.
- Default value `0` for unparseable strings is stable across app versions.
- Stored string representation is preserved unchanged; parsing does not mutate the struct.

## Edge Cases

- EC-001 `"0x152A"` → `0x152A` (uppercase hex digits, lowercase prefix).
- EC-002 `"0X152A"` → `0x152A` (uppercase X prefix also accepted via `lowercased()`).
- EC-003 `"5418"` → `5418` (decimal, same bit pattern as `0x152A`).
- EC-004 `"  0x8460  "` → `0x8460` (whitespace stripped).
- EC-005 `""` → `0` (empty string is unparseable).
- EC-006 `"xyz"` → `0` (non-numeric garbage).
- EC-007 `"65536"` → `0` (decimal overflow: `UInt16` max is 65535).
- EC-008 `"0xFFFF"` → `0xFFFF` (max valid hex value).

## Canonical Test Vectors

| Input String | Expected `UInt16` | Notes |
|---|---|---|
| `"0x152A"` | `0x152A` | Hex — verified by `ProfileTests:9` |
| `"5418"` | `5418` | Decimal — verified by `ProfileTests:13` |
| `"33888"` | `33888` | Decimal PID — verified by `ProfileTests:14` |
| `"  0x8460  "` | `0x8460` | Whitespace-padded |
| `""` | `0` | Empty → default 0 |
| `"bad"` | `0` | Garbage → default 0 |
| `"65536"` | `0` | Overflow → default 0 |

## Error Handling

No error is raised. Unparseable strings silently return `0`. Callers must not rely on `0` being a valid VID/PID; a `vid` of `0` will never match a real USB device (VID 0x0000 is unassigned), so the profile will simply not match.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapter/HardwareProfile.swift:37-41` |
| Test file:line | `Sources/occ-tests/ProfileTests.swift:7-14` |
| Ingest BC | BC-070 (pass-3-behavioral-contracts.md) |
| Ingest BC-205 | pass-2-3-deep-panels-r2.md |
| L2 Invariants | DI-TBD (profile matching must be deterministic) |
| Capability Anchor Justification | CAP-004 ("Hardware profile management and device matching") |

## Related BCs

- BC-1.04.002 — depends on: parsed `vid`/`pids` feed the `matches()` predicate
- BC-1.04.003 — composes with: JSON round-trip preserves raw strings (not parsed values)

## Architecture Anchors

- `Sources/OCCKit/Adapter/HardwareProfile.swift` — `HardwareProfile.parse(_:)` static func

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapter/HardwareProfile.swift:37-41` |
| Confidence | HIGH (test-pinned via ProfileTests.swift) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source + test |
