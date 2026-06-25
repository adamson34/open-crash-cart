---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.017
title: "setDDCPreset — Fire-and-Forget with getVersions Side Effect, Not Persisted"
origin: brownfield
subsystem: SS-04
capability: CAP-005
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift
ingest_bc: DF-202
domain_facts: [DF-202, DF-203]
---

# BC-1.04.017: setDDCPreset — Fire-and-Forget with getVersions Side Effect, Not Persisted

## Description

`StarTechAdapter.setDDCPreset(_:)` enqueues two wire commands: `[VSProtocol.Command.setDDC.rawValue, UInt8(preset.rawValue)]` at control priority, then `VSPack.command(.getVersions)` also at control priority. The DDC command advertises a DDC/EDID resolution preset to the connected target machine. The `getVersions` follow-up is a device re-query side effect. Neither the selected preset nor any "current preset" state is persisted to `UserDefaults`, `ProfileStore`, or any other storage — DDC state is entirely transient per device session (DF-202).

## Preconditions

- `StarTechAdapter` is connected (device is open, command queue is running).
- `preset` is a valid `DDCPreset` case.
- `running.get() == true` (adapter not in shutdown).

## Postconditions

- Two commands are enqueued to the command queue in order:
  1. `[setDDC.rawValue, UInt8(preset.rawValue)]`
  2. `getVersions` command
- No state is updated in `lastStatus`, `ProfileStore`, `UserDefaults`, or any persistent store.
- The `getVersions` response (when it arrives) will be handled by `handleResponse` which ignores `.versions` for core KVM purposes (see StarTechAdapter:340 — falls through to the ignore case).

## Invariants

- DDC preset is never persisted; there is no "current DDC preset" property on the adapter.
- The `getVersions` follow-up always follows the `setDDC` command in the queue; their relative order is guaranteed by sequential enqueue calls.
- The method does not await or block on device acknowledgement (fire-and-forget).

## Edge Cases

- EC-001 Adapter in shutdown (`running.get() == false`) → queue is closed; commands are dropped silently.
- EC-002 User calls `setDDCPreset` twice rapidly → both pairs of commands are enqueued; device receives them in order.
- EC-003 `getVersions` response received → ignored for core KVM; no state side-effect beyond clearing the internal device version cache (if any).
- EC-004 App restart → no DDC preset is restored (no persistence); device reverts to its power-on default.

## Canonical Test Vectors

| Input | Commands enqueued | Persisted? |
|---|---|---|
| `.res1920x1080` | `[setDDC, 0x03]`, then `getVersions` | No |
| `.res1280x1024` | `[setDDC, 0x00]`, then `getVersions` | No |
| `.res1024x768` | `[setDDC, 0x01]`, then `getVersions` | No |

## Error Handling

No error handling at this layer. If the device does not acknowledge the DDC command, no retry or error is surfaced. The fire-and-forget model relies on the device's own error handling.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:121-125` |
| Ingest domain fact | DF-202, DF-203 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (DDC commands are stateless) |
| Capability Anchor Justification | CAP-005 ("Video display control and DDC preset management") |

## Related BCs

- BC-1.04.016 — uses: `DDCPreset.rawValue` as wire payload

## Architecture Anchors

- `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:121-125` — `setDDCPreset(_:)`

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/OCCKit/Adapters/StarTech/StarTechAdapter.swift:121-125` |
| Confidence | HIGH (direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
