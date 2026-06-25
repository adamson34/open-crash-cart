---
document_type: behavioral-contract
level: L3
version: "1.1"
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
This is the coverage policy contract for the v1.1.0 hardening release. It governs two distinct test classes that must both be satisfied before the release tag is applied: **(a) change-BC regression guards** — tests for the SS-01..04 v1.1.0 behavioral fixes (e.g., BC-1.01.034, BC-1.02.018, BC-1.03.012, BC-1.04.020) which exercise corrected behavior and must demonstrate red-green discipline; and **(b) backfill characterization tests** — tests for BC-1.06.004 through BC-1.06.009, which pin existing behavior for the first time. Red-green discipline (Invariant #1) applies exclusively to class (a). Backfill tests in class (b) pass on current code by design — they add regression coverage for behavior that was always correct but untested, so "fail on pre-fix code" is not applicable to them.

## Preconditions
1. A v1.1.0 release branch exists targeting `main`.
2. The set of v1.1.0 change BCs (class a) is enumerated from SS-01..04 BC files with `introduced: v1.1.0`.
3. CI is configured per BC-1.06.002 (gates `main` on `swift run occ-tests`).

## Postconditions
1. **Class (a) — change-BC regression guards:** For each v1.1.0 change BC in SS-01..04 (e.g., BC-1.01.034, BC-1.02.018, BC-1.03.012, BC-1.04.020):
   a. A named test section in `occ-tests` exists that references the BC by its behavior description.
   b. The test exercises the corrected behavior (not the pre-fix behavior).
   c. The test fails on pre-fix code and passes on post-fix code (red-green gate per Invariant #1).
   d. `swift run occ-tests` exits 0 with the fix applied.
2. **Class (b) — backfill characterization tests:** For each of BC-1.06.004 through BC-1.06.009:
   a. A named test section in `occ-tests` exists that exercises the pinned behavior.
   b. The test passes on current (post-v1.0.0, pre-v1.1.0) code by design — it characterizes existing behavior.
   c. The test serves as a regression guard going forward: any future change that breaks the pinned behavior must fail this test.
   d. Red-green discipline (fail on pre-fix) is NOT required for class (b) tests.
3. No v1.1.0 fix PR is merged to `main` or `dev` while the corresponding class (a) test is absent or failing.
4. All class (b) tests exist and pass before the v1.1.0 release tag is applied.

## Invariants
1. **Red-green discipline applies only to class (a) tests.** "Corrected behavior" means the class (a) test must fail on the pre-fix code and pass on the post-fix code. A class (a) test that always passes regardless of the fix is insufficient.
2. Class (b) backfill tests are expected to pass on current code — they pin existing behavior, not corrected behavior. A class (b) test that fails on current code is a bug in the test, not a signal of a fix needed.
3. CI does not automatically enforce policy completeness beyond running tests that exist — human review of BC-to-test mapping is required at merge time to verify all class (a) BCs have genuine regression guards.
4. This policy applies to all SS-01..04 v1.1.0 changes; BC-1.06.004..009 name the minimum enumerated class (b) set.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | A class (a) test is written but passes on pre-fix code | Insufficient for class (a); must be strengthened. Does not apply to class (b). |
| EC-002 | A class (b) backfill test fails on current code | Bug in the test (expected current behavior is wrong); fix the test, not the production code |
| EC-003 | A v1.1.0 class (a) change BC has no test written before PR merge | PR must be blocked; policy violation |
| EC-004 | The fix and test land in separate commits on the same PR | Acceptable, provided CI passes with both commits included |
| EC-005 | A v1.0.0-era trivially correct constant rename has a v1.1.0 change BC | A class (a) regression guard must still exist, even for trivial fixes |
| EC-006 | A class (b) backfill test is written but does not exercise the pinned behavior (always passes vacuously) | Insufficient; the test must make meaningful assertions that would catch regressions |

## Canonical Test Vectors
| Scenario | Class | Red-green required? | Verification | Category |
|----------|-------|---------------------|-------------|----------|
| v1.1.0 PR with BC-1.01.034 regression guard: fails on pre-fix, passes on post-fix | (a) | Yes | CI green post-fix | happy-path |
| v1.1.0 PR with BC-1.06.004 backfill test: passes on current code | (b) | No | CI green on current code | happy-path |
| v1.1.0 PR missing a class (a) regression guard | (a) | N/A | CI may be green (test doesn't exist), but human review blocks merge | policy-violation |
| Class (b) backfill test written but vacuously passing (no meaningful assertions) | (b) | N/A | Human review blocks; test strengthened at PR time | policy-violation |
| All class (a) guards + all class (b) backfills present and passing in CI | both | class (a) only | v1.1.0 release tag may be applied | happy-path (release gate) |

## Error Handling
Violations of this policy are process errors, not runtime errors. Class (a) violations (missing regression guard) are detected at PR review time by checking that each v1.1.0 change BC has a corresponding test that fails on unpatched code. Class (b) violations (missing or vacuous backfill test) are detected at PR review time by inspecting test coverage for BC-1.06.004..009. CI enforces test passage but cannot automatically enforce that class (a) tests are genuine regression guards — that judgment requires human review at merge time.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `Sources/occ-tests/main.swift:1-14` (test registration), `.github/workflows/ci.yml` (enforcement) |
| Ingest BC | Gaps section: "test-backfill targets: USB mapping, virtual media math, firmware search, FPGA upload framing, STATUS parse, mouse coalescing, command-queue priority — all code-grounded but UNTESTED" — opencrashcart-pass-3-behavioral-contracts.md:78 |
| Stories | TBD |
| Capability Anchor Justification | `capability: CAP-TBD` — v1.1.0 test-backfill coverage policy per Pass-3 Gaps section (policy-level contract); capability ID assigned in the architecture phase |

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
- BC-1.06.004 — USB rc mapping test, class (b) (composes with)
- BC-1.06.005 — virtual-media test, class (b) (composes with)
- BC-1.06.006 — firmware search test, class (b) (composes with)
- BC-1.06.007 — STATUS parse test, class (b) (composes with)
- BC-1.06.008 — mouse coalescing test, class (b) (composes with)
- BC-1.06.009 — command-queue priority test, class (b) (composes with)

## Architecture Anchors
- `Sources/occ-tests/main.swift` — test registration point
- `.github/workflows/ci.yml` — CI enforcement

## Story Anchor
TBD

## VP Anchors
TBD
