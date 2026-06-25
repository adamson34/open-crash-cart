---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ-tests/TestHarness.swift"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.0.0
---
# BC-1.06.001: Dependency-Free Harness Executes as `occ-tests` and Exits Non-Zero on Any Failure

## Description
The project's test harness is a hand-rolled, dependency-free executable target (`occ-tests`) that requires no XCTest or swift-testing runtime. When invoked via `swift run occ-tests`, it runs all registered test functions, prints pass/fail lines to stdout, and calls `exit(1)` if any single `expect` or `expectEqual` assertion failed. If every assertion passed it calls `exit(0)`. This behaviour is the foundation of the CI quality gate.

## Preconditions
1. The Swift 6 Command Line Tools toolchain is installed (no full Xcode required).
2. `swift run occ-tests` is executed from the repository root.
3. `OCCKit` builds without error (it is a dependency of `occ-tests`).

## Postconditions
1. The process exits with code `0` if and only if `Harness.failed == 0` at the point `finish()` is called.
2. The process exits with code `1` if `Harness.failed >= 1`.
3. Every failed assertion prints a line prefixed with `  ✗` to stdout before exit.
4. Every passed assertion prints a line prefixed with `  ✓` to stdout.
5. The final summary line reads either `ALL PASSED ✓  (<N> checks)` or `<F> FAILED ✗  (<P>/<N> passed)`.

## Invariants
1. `Harness` has zero dependencies on Foundation (beyond `import Foundation` for `exit()`), XCTest, or swift-testing.
2. `Harness.finish()` is `Never` returning — it always calls `exit()`.
3. A failure in one test section does not abort subsequent sections; all sections always run.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | All assertions pass | exit(0); summary prints "ALL PASSED ✓" |
| EC-002 | Exactly one assertion fails | exit(1); summary prints "1 FAILED ✗" |
| EC-003 | Multiple sections, failure in first section | Subsequent sections still execute; total failure count accumulated |
| EC-004 | `expectEqual` mismatch | Prints `[got <actual>, want <expected>]` suffix; increments `failed` |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| All harness assertions pass (current suite state) | Process exits 0; stdout ends with `ALL PASSED ✓` | happy-path |
| One `expectEqual` call where actual ≠ expected injected | Process exits 1; failed line printed with got/want detail | error |
| `swift run occ-tests` in a clean checkout with `swift build` passing | Combined exit 0 | happy-path (CI simulation) |

## Error Handling
`Harness` has no internal error handling — every assertion result is deterministic. The only failure mode is a compilation error in `occ-tests` (which becomes a `swift build` failure, a separate gate; see BC-1.06.002).

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ-tests/TestHarness.swift:1-41`, `Sources/occ-tests/main.swift:1-14` |
| Ingest BC | (harness infrastructure — no single pass-3 BC; foundational to all BC-001..BC-143) |
| Stories | TBD |
| Capability Anchor Justification | Quality gate infrastructure per Pass-0 inventory §Tech Stack (hand-rolled dependency-free harness) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/occ-tests/TestHarness.swift` |
| Confidence | HIGH (test-pinned, direct code read) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code (complete file) |

## Related BCs
- BC-1.06.002 — CI gate that invokes this harness (depends on)
- BC-1.06.003 through BC-1.06.010 — test-backfill contracts verified by this harness (depends on)

## Architecture Anchors
- `Sources/occ-tests/TestHarness.swift` — Harness implementation
- `Sources/occ-tests/main.swift` — test runner entry point

## Story Anchor
TBD

## VP Anchors
TBD
