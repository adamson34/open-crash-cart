---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: "Sources/occ-tests/"
subsystem: "SS-06"
lifecycle_status: active
introduced: v1.1.0
---
# BC-1.06.010: Every v1.1.0 Change BC Ships with a Harness Test Verifying the Corrected Behavior

## Description
This is the coverage policy contract for the v1.1.0 hardening release. Every behavioral contract classified as a v1.1.0 P1 fix (in SS-01 through SS-04) must have a corresponding harness test that exercises the corrected behavior before the release is merged to `main`. "Ships with" means the test exists in the same commit or PR that delivers the fix; no fix is considered done until its test passes in CI. This contract is meta: it governs the process by which the other v1.1.0 test-backfill BCs (BC-1.06.004 through BC-1.06.009) are considered satisfied.

## Preconditions
1. A v1.1.0 release branch exists targeting `main`.
2. The set of v1.1.0 change BCs is enumerated (from SS-01..04 BC files with `introduced: v1.1.0`).
3. CI is configured per BC-1.06.002 (gates `main` on `swift run occ-tests`).

## Postconditions
1. For each v1.1.0 change BC (BC-X.YY.ZZZ with `introduced: v1.1.0` in SS-01..04):
   a. A named test section in `occ-tests` exists that references the BC by its behavior description.
   b. The test exercises the corrected behavior (not the pre-fix behavior).
   c. `swift run occ-tests` exits 0 with that test present.
2. No v1.1.0 fix PR is merged to `main` or `dev` while the corresponding test is absent or failing.
3. The specific test-backfill BCs BC-1.06.004 through BC-1.06.009 are all satisfied (their tests exist and pass) before the v1.1.0 release tag is applied.

## Invariants
1. "Corrected behavior" means the test must fail on the pre-fix code and pass on the post-fix code (red-green TDD discipline).
2. A test that always passes regardless of the fix does not satisfy this contract (it must be a genuine regression guard).
3. This policy applies to all SS-01..04 v1.1.0 changes, not just those named in BC-1.06.004..009; those six are the minimum enumerated set.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | A v1.1.0 fix is trivially correct by construction (e.g., a constant rename) | A test must still exist; even trivial fixes need regression guards |
| EC-002 | A test is written but does not fail on pre-fix code | The test is insufficient; it must be strengthened to be a genuine regression guard |
| EC-003 | A v1.1.0 change BC in SS-01..04 has no test written before PR merge | PR must be blocked; policy violation |
| EC-004 | The fix and test land in separate commits on the same PR | Acceptable, provided the CI gate passes with both commits included |

## Canonical Test Vectors
| Scenario | Verification | Category |
|----------|-------------|----------|
| v1.1.0 PR with BC-1.06.004 test present and passing | CI green; PR mergeable | happy-path |
| v1.1.0 PR with BC-1.06.005 test absent | CI fails (missing test = no coverage of the corrected behavior, but more practically: the uncovered code path was the bug, so the test must be present) | policy-violation |
| All six test-backfill BCs satisfied + CI green | v1.1.0 release tag may be applied | happy-path (release gate) |
| Test written but passes on unpatched code | Policy violation — test is not a genuine regression guard | error |

## Error Handling
Violations of this policy are process errors, not runtime errors. A missing test is detected at PR review time by checking that each v1.1.0 change BC has a corresponding `t.section(...)` / `t.expect(...)` block in `occ-tests`. CI does not automatically enforce policy completeness beyond running tests that exist — human review of BC-to-test mapping is required at merge time.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ-tests/main.swift:1-14` (test registration), `.github/workflows/ci.yml` (enforcement) |
| Ingest BC | Gaps section: "test-backfill targets: USB mapping, virtual media math, firmware search, FPGA upload framing, STATUS parse, mouse coalescing, command-queue priority — all code-grounded but UNTESTED" — opencrashcart-pass-3-behavioral-contracts.md:78 |
| Stories | TBD |
| Capability Anchor Justification | v1.1.0 test-backfill coverage policy per Pass-3 Gaps section (policy-level contract, no single source BC) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `Sources/occ-tests/main.swift`, `.github/workflows/ci.yml`, `opencrashcart-pass-3-behavioral-contracts.md` (Gaps section) |
| Confidence | HIGH (explicit policy requirement derived from enumerated gaps) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Process policy (derived from code analysis gaps + CI configuration) |

## Related BCs
- BC-1.06.001 — harness infrastructure this policy relies on (depends on)
- BC-1.06.002 — CI gate that enforces this policy (depends on)
- BC-1.06.004 — USB rc mapping test (composes with)
- BC-1.06.005 — virtual-media test (composes with)
- BC-1.06.006 — firmware search test (composes with)
- BC-1.06.007 — STATUS parse test (composes with)
- BC-1.06.008 — mouse coalescing test (composes with)
- BC-1.06.009 — command-queue priority test (composes with)

## Architecture Anchors
- `Sources/occ-tests/main.swift` — test registration point
- `.github/workflows/ci.yml` — CI enforcement

## Story Anchor
TBD

## VP Anchors
TBD
