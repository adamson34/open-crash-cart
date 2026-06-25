---
document_type: behavioral-contract
level: L3
version: "1.0"
status: draft
phase: 1a
traces_to: product-brief.md
origin: brownfield
extracted_from: ".github/workflows/ci.yml"
subsystem: "SS-06"
capability: CAP-TBD
lifecycle_status: active
introduced: v1.0.0
---
# BC-1.06.002: CI Gate Runs `swift build` Then `swift run occ-tests` on Push/PR to main and dev

## Description
A GitHub Actions workflow triggers on every push and pull-request event targeting the `main` or `dev` branches. The workflow must complete two sequential steps: `swift build` (which verifies the entire package compiles without errors) followed by `swift run occ-tests` (which exercises the behavioural contracts). Both steps must exit 0 for the CI check to pass. A failing check blocks merge.

## Preconditions
1. The repository has a `.github/workflows/ci.yml` defining the `CI` workflow.
2. The workflow is triggered by a `push` or `pull_request` event to `main` or `dev`.
3. `brew install libusb` has completed successfully on the runner (macOS-15).
4. The Xcode version selected is `latest-stable` (Swift 6).

## Postconditions
1. The `Build` step runs `swift build` and the job fails immediately if it returns non-zero.
2. The `Run test suite` step runs `swift run occ-tests` and the job fails if it returns non-zero.
3. On success, both steps report green and the overall workflow check passes.
4. The CI check result is visible on the PR/commit status before merge is possible.

## Invariants
1. `swift run occ-tests` is never skipped when `swift build` passes; the two steps are unconditionally sequential.
2. The workflow runs on `macos-15` runners (Apple Silicon compatible).
3. `libusb` is installed before either build step; failure to install libusb causes the build step to fail.

## Edge Cases
| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | `swift build` fails (compilation error) | CI fails at Build step; `occ-tests` step never runs |
| EC-002 | `swift build` passes but `swift run occ-tests` exits 1 | CI fails at Run test suite step |
| EC-003 | Push to a branch other than main/dev | Workflow does not trigger |
| EC-004 | `brew install libusb` fails | Build step fails; CI fails |

## Canonical Test Vectors
| Input | Expected Output | Category |
|-------|----------------|----------|
| PR to `main` with all tests passing | Workflow status = success, both steps green | happy-path |
| PR to `dev` with a compilation error introduced | Workflow status = failure at Build step | error |
| PR to `main` with a failing test assertion | Workflow status = failure at Run test suite step | error |
| Push directly to `main` (no PR) | Same two-step gate triggers | happy-path variant |

## Error Handling
CI failures surface as a failed GitHub check on the commit/PR. The workflow has no retry logic — failures require a new commit to re-trigger. Xcode selection uses `maxim-lobanov/setup-xcode@v1` action; if this action fails the job fails before build.

## Traceability
| Field | Value |
|-------|-------|
| Source file:line | `.github/workflows/ci.yml:1-32` (complete file) |
| Ingest BC | (CI infrastructure — foundational gate for all BCs) |
| Stories | TBD |
| Capability Anchor Justification | Continuous integration gate per Pass-0 inventory §Tech Stack (CI: GitHub Actions on macos-15, build + occ-tests) |

## Source Evidence
| Field | Value |
|-------|-------|
| Path | `.github/workflows/ci.yml` |
| Confidence | HIGH (direct code read, complete file) |
| Extraction Date | 2026-06-25 |
| Evidence Type | Source code (CI workflow) |

## Related BCs
- BC-1.06.001 — test harness that this CI gate invokes (depends on)
- BC-1.06.003 — app bundle self-containment gate (peer quality gate)

## Architecture Anchors
- `.github/workflows/ci.yml` — workflow definition

## Story Anchor
TBD

## VP Anchors
TBD
