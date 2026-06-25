---
document_type: behavioral-contract
level: L3
bc_id: BC-1.04.019
title: "Theme.padding — Dual-Clamp State Machine: Env/UserDefaults/Adjust/Reset with Persist and onChange"
origin: brownfield
subsystem: SS-04
capability: CAP-006
introduced: v1.0.0
lifecycle_status: active
extracted_from:
  - Sources/occ/Theme.swift
ingest_bc: BC-206
domain_facts: [DF-204, BC-206]
---

# BC-1.04.019: Theme.padding — Dual-Clamp State Machine: Env/UserDefaults/Adjust/Reset with Persist and onChange

## Description

`Theme.padding` is the only persisted UI layout state in OpenCrashCart (DF-204), stored under UserDefaults key `"OpenCrashCartPadding"`. Its initial value follows a three-way priority: (1) `OCC_PADDING` environment variable — accepted as-is with no clamping; (2) a previously-saved UserDefaults value — clamped to `[0, 40]`; (3) hardcoded default of 14. The `didSet` observer persists every write to UserDefaults and fires `onChange?()` for relayout. `adjust(by:)` clamps the result to `[0, 96]`. `reset()` restores the value to 14.

## Preconditions

- `Theme.shared` is the singleton, accessed from the main actor (`@MainActor`).
- `OCC_PADDING` may or may not be set in the process environment.
- UserDefaults key `"OpenCrashCartPadding"` may or may not exist.
- `onChange` callback may be nil (no relayout needed yet) or set.

## Postconditions

**Initialisation priority:**
1. If `OCC_PADDING` env var is set and parseable as `Double`: `padding = CGFloat(env)` — NO clamping.
2. Else if UserDefaults has a saved value: `padding = CGFloat(min(max(saved, 0), 40))` — clamped to `[0, 40]`.
3. Else: `padding = 14` — hardcoded default.

**`padding` didSet:**
- `UserDefaults.standard.set(Double(padding), forKey: "OpenCrashCartPadding")` — persists immediately.
- `onChange?()` — triggers relayout if callback is set.

**`adjust(by delta:)`:**
- `padding = max(0, min(96, padding + delta))` — result clamped to `[0, 96]`.
- Setter fires: persists to UserDefaults + calls `onChange`.

**`reset()`:**
- `padding = 14` — setter fires: persists 14 to UserDefaults + calls `onChange`.

## Invariants

- `OCC_PADDING` bypasses clamping entirely — intended for developer/testing use.
- UserDefaults-loaded values are clamped to `[0, 40]` (conservative sane range) at load time only.
- Runtime `adjust(by:)` uses the broader `[0, 96]` clamp range.
- Every write to `padding` (including from `adjust` and `reset`) triggers both persist and `onChange`.
- `padding` is always a `CGFloat`; UserDefaults stores it as `Double` (lossless conversion on 64-bit).

## Edge Cases

- EC-001 `OCC_PADDING="-5"` → `padding = -5.0` (no clamping applied).
- EC-002 `OCC_PADDING="200"` → `padding = 200.0` (no clamping).
- EC-003 Saved UserDefaults value is `50` → clamped to `40` on load.
- EC-004 Saved UserDefaults value is `-1` → clamped to `0` on load.
- EC-005 `adjust(by: 100)` when `padding = 14` → `14 + 100 = 114` → clamped to `96`.
- EC-006 `adjust(by: -100)` when `padding = 14` → `14 - 100 = -86` → clamped to `0`.
- EC-007 `reset()` → `padding = 14`; UserDefaults updated; `onChange` called.
- EC-008 `onChange` not set at time of write → `onChange?()` is a no-op (optional chaining).
- EC-009 `OCC_PADDING` set but not parseable as Double → `env` is nil → falls through to UserDefaults path.

## Canonical Test Vectors

| Scenario | Input | Result `padding` | UserDefaults written? | onChange fired? |
|---|---|---|---|---|
| Env var set | `OCC_PADDING="-5"` | `-5.0` | No (init, no didSet) | No (init) |
| Saved value 50 | UserDefaults["OpenCrashCartPadding"]=50 | `40.0` (clamped) | No (load only) | No (init) |
| No saved value | — | `14.0` | No (init) | No (init) |
| adjust(by: 10) | padding=14, delta=10 | `24.0` | Yes | Yes |
| adjust(by: 100) | padding=14, delta=100 | `96.0` (clamped) | Yes | Yes |
| reset() | — | `14.0` | Yes | Yes |

## Error Handling

No errors. `ProcessInfo.processInfo.environment["OCC_PADDING"].flatMap { Double($0) }` returns `nil` for non-numeric values, falling through to UserDefaults path.

## Traceability

| Field | Value |
|---|---|
| Source file:line | `Sources/occ/Theme.swift:12-17` (padding property + didSet) |
| Source file:line | `Sources/occ/Theme.swift:38-55` (init + adjust + reset) |
| Ingest BC | BC-206 (pass-2-3-deep-panels-r2.md) |
| Ingest domain fact | DF-204 (pass-2-3-deep-panels-r2.md) |
| L2 Invariants | DI-TBD (UI layout state consistency) |
| Capability Anchor Justification | CAP-006 ("UI theme and layout customisation") |

## Related BCs

- None in SS-04; `onChange` connects to AppController layout logic in SS-01.

## Architecture Anchors

- `Sources/occ/Theme.swift:6` — `@MainActor final class Theme`
- `Sources/occ/Theme.swift:38-49` — `private init()` with tri-path initialisation

## Source Evidence

| Field | Value |
|---|---|
| Path | `Sources/occ/Theme.swift:12-55` |
| Confidence | HIGH (direct code read, unambiguous conditionals) |
| Extraction Date | 2026-06-25 |
| Evidence Type | source code |
