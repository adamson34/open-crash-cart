---
document_type: adversarial-review
level: L3
status: complete
traces_to: prd.md
reviewers: 3x vsdd-factory:adversary (fresh-context, perspective-diverse)
date: 2026-06-25
verdict: REVISED (all blocking + high + medium addressed 2026-06-25)
---

# Adversarial Review — OpenCrashCart PRD (v1.1.0)

Three fresh-context adversaries reviewed: (A1) the 11 v1.1.0 change contracts vs source,
(A2) cross-document consistency & coverage, (A3) a 23-BC baseline-accuracy sample vs source.

## Headline
- **Baseline (existing-behavior) contracts are trustworthy** — A3 confirmed 22/23 sampled BCs
  exactly match source, including all test-pinned wire/codec contracts. Safe to build on.
- **The v1.1.0 CHANGE contracts — the ones that drive code edits — have real design flaws**
  that would cause wrong implementations. These are the catches that justify reviewing before coding.

## BLOCKING (must fix before implementation)

| # | BC / Area | Finding | Fix |
|---|-----------|---------|-----|
| B1 | **BC-1.06.004–009 (all 6 test-backfills)** | **Visibility wall.** `occ-tests` plain-`import OCCKit` (Package.swift:37-41) — NOT `@testable`. Only `public` symbols are visible. `CommandQueue`, `VirtualMedia`, `StarTechFirmware.searchDirectories`, `parseStatus`, `USBDevice.check` are `internal`/`private` → the specified tests **won't compile**. | Per BC, add explicit precondition: promote the symbol to `public` (or add a public test shim / extract a pure core). Each backfill BC entails a named public-API delta. |
| B2 | **BC-1.02.018** (keyframe self-heal) | **Trigger is a phantom.** Primary trigger "leftover > leftoverNeeded" is unreachable — `take = min(leftoverNeeded - leftover.count, …)` makes it impossible (TileDecoder.swift:58-60). OOR heuristic "both axes ≥110" is geometrically incoherent (tilesHigh=100, so tileY≥100 is *always* garbage; AND-condition misses single-axis corruption). | Re-derive a reachable desync signal (e.g. K consecutive ingests with zero in-range tiles, or OOR-skip count > fraction of records). Trigger on `tileY ≥ tilesHigh`, not "both ≥110". |
| B3 | **BC-1.02.018** (keyframe self-heal) | **I-frame spam / unbounded queue.** `needsKeyframe` checked every ingest + reset each call → sustained desync enqueues a `.doIFrame` per video read into the unbounded `controlQ`. | Add invariant: ≤1 outstanding `.doIFrame` between clean frames (latch cleared only on a clean decode). |
| B4 | **BC-1.04.020** (single source of truth) | **Self-contradiction.** Postconditions derive `StarTechAdapter.model` via `builtIns.first!` (force-unwrap in a `static let`) while EC-003 promises "empty builtIns → no crash." `first!` traps at type-init. | Use non-crashing derivation (`builtIns.first.map{…}` + zero fallback) and drop `first!`. |
| B5 | **BC-1.06.004** | **Wrong error type** — maps to `USBError` (doesn't exist); real domain is `USBTransportError` (USBDevice.swift:4-23). Mapping lives in `private check`. | Correct type; specify extracting `check`'s switch into `public static func mapRC(_:) -> USBTransportError?`. |
| B6 | **BC-1.06.007** | **Wrong bps formula + wrong state enum** — BC says `rawRate * multiplier` & `.noSignal`; real is `words*16*1000/ticks` (guard ticks=0) and `.noVideo(reason)`/`.live`/`.connecting`. | Rewrite to the real formula + state set; expose `parseStatus`. |
| B7 | **BC-1.06.008** | **Misattributed behavior** — mouse coalescing is in `UVCAdapter` (private, CH9329-gated, async), NOT `StarTechAdapter`. Untestable as written. | Re-anchor to UVC; extract a pure, public, synchronous `MouseCoalescer` and test that. |
| B8 | **BC-1.05.012** | **Wrong canonical test vector** — row (1919,1079,1920,1080) claims ax=4094/ay=4090; correct integer math = **4093/4092**. A test pinned to this would fail correct code. (Only un-test-pinned numeric BC in the sample had the error.) | Fix vector to 4093/4092. **Sweep all other MEDIUM/no-test-pin BCs with hand-computed numeric vectors.** |
| B9 | **STATUS parse duplicated** | BC-1.01.005 (SS-01) **and** BC-1.02.010 (SS-02) both contract `parseStatus` with divergent detail. | Merge into one canonical BC (SS-02 per PRD §2 ownership); retarget BC-1.06.007. |
| B10 | **Firmware search-order contradiction** | BC-1.01.013 says **7-tier**, BC-1.04.004 says **2-tier** (omits OCC_FIRMWARE_DIR + vendor paths), NFR-CFG-04 says **5-tier**. Security-relevant BYO-firmware path. | Make BC-1.01.013 authoritative; have BC-1.04.004 + NFR-CFG-04 reference it verbatim. Resolves synthesis P3.3. |
| B11 | **Auto-Tune / autophase: zero coverage** | `autoTuneVideo` seam + "Auto-Tune" menu + "autophase done" status are referenced but **no BC** covers them. | Add a BC (SS-02 or SS-04) or explicitly scope out in PRD §3. |

## HIGH (fix in the same revision pass)

| # | BC / Area | Finding | Fix |
|---|-----------|---------|-----|
| H1 | BC-1.01.034 (Disconnect stays) | Flag fixes the rescan path but doesn't cancel an in-flight `eventTask` (`menuDisconnect` sets `eventTask=nil` without `.cancel()`, unlike `menuConnectUVC`); stale `.disconnected` from a torn-down adapter can interleave. | Add postcondition: cancel `eventTask`; ignore stale `.disconnected` (adapter identity/generation). |
| H2 | BC-1.06.005 | `VirtualMedia` is `internal` + filesystem-bound; BC asserts property `isReadOnly` (real name `readOnly`); "in-memory fixture / dependency-free" is false (needs temp file). | Make public; fix property name; acknowledge temp-file I/O. |
| H3 | BC-1.06.006 | Firmware order/tail count wrong (3 vendor paths, not 1); `ProfileStore.shared` is an un-mockable singleton → nondeterministic test. | Correct list; make `searchDirectories` public + parameterize store inputs. |
| H4 | capabilities.md anchors | BC-1.03.013/.015 cite `capabilities.md §CAP-X` — **no such file exists** (dangling anchor). | Strip the anchor text until the arch phase defines capabilities. |
| H5 | PRD §7 false claim | Says "BCs carry CAP-TBD" — but SS-03 uses CAP-OCR/ENHANCE/…, SS-04 uses CAP-004/005/006 (two schemes). | Correct PRD §7; normalize all BCs to CAP-TBD until arch. |
| H6 | CLI + link-speed coverage | occ-probe, occ-connect, and the Full-Speed link-speed warning (NFR-OBS-05) have no BC. | Add BCs or state transitive coverage. |

## MEDIUM / LOW (track, not blocking)
- M1 BC-1.03.012: forbid the "empty-string → No text found" path masking a real OCR failure (mandate explicit error).
- M2 BC-1.04.020: source-of-truth fields are the *string* `vendorId`/`productIds`, not the read-only computed `vid`/`pids`.
- M3 BC-1.06.010: distinguish backfill **characterization** tests (pin current behavior; red-green N/A) from change-BC **regression** guards (red-green required).
- M4 Frontmatter schema drift: SS-04 BCs use `bc_id`/`title`/`domain_facts`; others use `version`/`status`/`phase`/`traces_to`. Normalize.
- M5 Two capability-ID schemes (semantic vs numeric). Standardize.
- M6 BC-1.03.002 same-line vector: clarify all observations are newline-joined regardless of line grouping.
- L1 OCR/Vision failure not in error-taxonomy domains table (surfaced as plain `.message`).
- L2 Synthesis P3 items (StatusBar OOB, sharpness/flatness vocab) uncontracted — note as accepted divergences.

## Verified COMPLETE (no action)
Baseline extraction trustworthy (22/23). DDC, virtual media, image-enhancement display-only split,
mouse-vs-key ownership split, stuck-key safety, BC-INDEX integrity (124, no gaps, v1.1.0 markers correct).

## Disposition
Verdict **NEEDS-REVISION**. The baseline is sound; the **v1.1.0 change set + supplements need a revision pass**
before architecture/implementation. Recommended order: B1–B11 (blocking) → H1–H6 → sweep numeric vectors (B8) →
re-review the revised change BCs.

---

## Revision Applied (2026-06-25)

All BLOCKING, HIGH, MEDIUM, and LOW items were addressed in separate commits on `factory-artifacts`:

| Item | Resolution |
|------|------------|
| B1 (test visibility wall) | Each SS-06 backfill BC now names its required public-API delta (extract pure core / promote clean unit) |
| B2/B3/B4 (keyframe) | BC-1.02.018 rewritten: reachable triggers (tileY≥tilesHigh, sustained no-decode) + bounded `keyframeRequested` latch |
| B5 | BC-1.06.004 USBError→USBTransportError + extract public `mapLibusbResult` |
| B6 | BC-1.06.007 correct bps formula + state enum, extract pure compute/derive |
| B7 | BC-1.06.008 re-anchored to UVCAdapter + extract public `MouseCoalescer` |
| B8 | BC-1.05.012 vector fixed (4093/4092); sweep found + fixed 3 more (BC-1.02.014/001/005) |
| B9 | STATUS parse merged → BC-1.02.010 canonical; BC-1.01.005 deprecated |
| B10 | Firmware order reconciled to canonical BC-1.01.013 (7-tier); BC-1.04.004 + NFR-CFG-04 reference it |
| B11 | BC-1.02.019 auto-tune/autophase added |
| H1 | BC-1.01.034 + eventTask.cancel() + stale-event isolation |
| H2/H3 | BC-1.06.005 (VirtualMedia public/readOnly/temp-file), BC-1.06.006 (7-tier + injectable pure fn) |
| H4 | All dangling `capabilities.md` anchors stripped |
| H5/M5 | All capability IDs normalized to CAP-TBD (single scheme); PRD §7 now accurate |
| H6/F-03/F-04 | BC-1.01.041/042 (CLIs) + BC-1.01.043 (link-speed) added |
| M1 | BC-1.03.012 mandates explicit OCR error channel (no empty-string masking) |
| M2 | BC-1.04.020 source-of-truth = string fields; `.vid`/`.pids` computed |
| M3 | BC-1.06.010 splits regression-guard vs characterization tests |
| M4 | All 128 BC frontmatter normalized to one schema |
| M6 | BC-1.03.002 newline-join invariant clarified |
| L1 | Vision OCR failure added to error-taxonomy |
| L2 | P3 known divergences documented as accepted (PRD §4) |

Baseline (existing-behavior) contracts were already verified trustworthy (22/23 sampled). A targeted
re-review of the revised v1.1.0 change contracts is recommended before architecture.
