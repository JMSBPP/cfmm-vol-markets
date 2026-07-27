---
phase: 10-streaming-premium-reconstruction-and-reestimation
verified: 2026-07-27T18:03:09Z
status: passed
score: 8/8 must-haves verified
---

# Phase 10: streaming premium reconstruction and reestimation Verification Report

**Phase Goal:** Fix Phase 9's measurement failure by reconstructing per-position per-epoch
Panoptic premium (route amended to SFPM `getAccountPremium` archive reads), validate behind a
hard ≤1% wei stratified gate, restore the position-epoch panel, re-run the unchanged Phase-9
estimator; success criterion = an informative υ₀ estimate (CI half-width ≤ ~6.2e-5) REGARDLESS
of κ̂'s sign — with the pre-committed conditional: if uninformative after a passing gate,
"report that this market cannot identify υ and STOP" is the contracted terminal outcome.

**Verified:** 2026-07-27T18:03:09Z
**Status:** passed
**Re-verification:** No — initial verification

**Framing note (per verification brief):** the phase's *power* goal was NOT met — both
estimation runs returned `STOPPING_RULE: UNINFORMATIVE`. That is the pre-registered null branch
of the phase's own contract, not a process failure. This report verifies the *process* contract:
did the phase deliver every artifact, gate, checkpoint and honest-disclosure obligation it
promised, including the null-outcome branch, and does the codebase actually contain what the
SUMMARYs claim.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Census + hourly re-scope trail (10-01): daily STOP honored, hourly GO measured, decision trail committed | ✓ VERIFIED | `panel-size-audit.md` line 219 `RECOMMENDATION: STOP`, line 264 `## DAILY-DESIGN VERDICT: STOP (honored)`; `panel-size-audit-hourly.md` line 90 `RECOMMENDATION: GO`, line 119 `## FINAL DECISION: PROCEED (hourly design)`. Commits `efbac82,d6c2a3c,63270d4,a02df396,7dcf998` all in history. |
| 2 | Chain layer + premium read: suite green, frozen fixtures offline, premium-accumulators.csv 8,910 rows w/ lineage + CLEAN×2 review | ✓ VERIFIED | `stack test` run live: **215 examples, 0 failures**. `test/fixtures/premium-acc-golden.json` exists; `RpcSpec.hs`/`PremiumSpec.hs`/`SfpmSpec.hs` read it with "No network access" comments. `premium-accumulators.csv`: 8917 lines − 6 `#` banner − 1 header = **8910 data rows**, exact match. `premium-accumulators-lineage.md` lines 41-42: "Reviewer A: CLEAN" / "Reviewer B: CLEAN", corroborated by commit `9ad94b2` "anti-fabrication review CLEAN x2". |
| 3 | The hard gate: reconcile.md GATE:PASS (median 0.0 both strata, 53/61 wei-exact), gateTolerance 0.01 unedited across history | ✓ VERIFIED | `reconcile.md` verdict block: `MEDIAN_REL_ERROR_SHORT: 0.000000`, `MEDIAN_REL_ERROR_LONG: 0.000000`, `GATE_TOLERANCE: 0.01`, `GATE: PASS`. `git log -p -- econometrics/src/Panel/Reconcile.hs` shows exactly ONE commit (`a2ad4b6`, plan 10-07) ever touched the file — `gateTolerance = 0.01` was set at creation and never modified since. |
| 4 | Panel: panel-epoch.csv 6,760 rows, zero unmatched epochs, burn-truth.csv frozen (61 rows), CLEAN×2 review | ✓ VERIFIED | `panel-epoch.csv`: 6802 lines − 41 banner − 1 header = **6760 rows**, exact match; SUMMARY claims `UNMATCHED_EPOCHS: 0`. `burn-truth.csv`: 95 lines − 33 banner − 1 header = **61 rows**, exact match. Same 10-08 CLEAN×2 review covers the accumulators this panel decomposes from (10-09 self-check independently recomputed `TELESCOPE_MISMATCHES: 0` / `TRUTH_MISMATCHES: 0` against it). |
| 5 | Estimation: estimator unchanged; run-1 frozen w/ CORRECTIONS header; HALT artifacts exist (DISPOSITION-MEMO+PIVOT-LOCK w/ sha256 pin); run-2 under the lock; STOPPING_RULE mechanical/result-blind; κ>0 rejection recorded both constructions; witness explicitly NOT obtained; conjecture OPEN | ✓ VERIFIED | `git log --oneline -- econometrics/src/Model/ econometrics/src/Tests/ econometrics/src/Alternatives.hs` shows no commits after Phase-9 tip `bb15a96`; `git log 92a0516..HEAD -- <those paths>` empty. `2026-07-20-upsilon-estimates-v2.md` line 1 `# CORRECTIONS`, line 4 "FROZEN at the realized result." `10-10-DISPOSITION-MEMO.md` and `10-10-PIVOT-LOCK.md` both exist; lock records `PIVOT_LOCK_SHA256: 56044349…` verified at run time per SUMMARY. Both analysis files: `STOPPING_RULE: UNINFORMATIVE`, `TEST_KAPPA_POS_P` 9.534719e-3 (v2) and 7.308348e-3 (v3) — both < 0.05, both files state "the Lean witness does not obtain" / "DOES NOT OBTAIN" and "conjecture remains OPEN". |
| 6 | Cross-walk: measured wedge (median 1.1125, max 1.2917, 1.125-bound corrected), witness status, sign-convention note, verified anchors | ✓ VERIFIED | `lean-haskell-crosswalk.md`: median `1.112500`, p90/max `1.291667`, explicit "the wedge BINDS, and it is not near-degenerate at 1"; witness table states `DOES NOT OBTAIN`, `ATMOTMNullHypothesis` `CONJECTURE OPEN`; sign-convention note present (10-11-SUMMARY quotes it verbatim, matches the file). |
| 7 | No lean/ edits by any Phase-10 commit; no home-absolute paths in phase-created tracked files; no key leakage | ✓ VERIFIED | Checked all 19 Phase-10 task commits (`efbac82` … `a2ad4b6`) with `git show --stat` grepped for `lean/` — zero matches. The 5 `lean/`-touching commits in this window (`5e08578`,`6914fba`,`d23ebfb`,`4d4e317`,`a4f7e09`) are separate `vol_markets` work interleaved chronologically, not among any plan's documented Task Commits. Grepped 16 phase-created data/analysis/checkpoint files for `/home/|$HOME|~/` and for key-like patterns — zero matches in either sweep. |
| 8 | The 10-12 skip is explicit in ROADMAP + STATE with rationale | ✓ VERIFIED | `ROADMAP.md` line 217: "11/12 plans executed — the 12th (10-12) is **SKIPPED**… `CTX-REPLAY-OPT`, which is recorded UNSATISFIED"; line 231 gives the full reason (10-08 gate + CLEAN×2 reviews already serve the purpose). `STATE.md` lines 5,6,8,29,46,50 all independently state "10-12 SKIPPED" / "CTX-REPLAY-OPT unsatisfied" with matching rationale. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `notes/structural-econometrcics/data/panel-size-audit.md` + `-hourly.md` | Two-round STOP→GO census trail | ✓ VERIFIED | Both exist, both grep to the claimed verdicts. |
| `notes/structural-econometrcics/data/premium-accumulators.csv` | 8,910 SFPM accumulator rows | ✓ VERIFIED | Row count exact; lineage banner present. |
| `notes/structural-econometrcics/data/premium-accumulators-lineage.md` | CLEAN×2 review record | ✓ VERIFIED | Both reviewer verdicts present. |
| `notes/structural-econometrcics/data/reconcile.md` / `reconcile-errors.csv` | 61-spell hard gate report | ✓ VERIFIED | Verdict block matches SUMMARY verbatim; 61 data rows + header = 62 lines. |
| `notes/structural-econometrcics/data/panel-epoch.csv` | 6,760-row position-epoch panel | ✓ VERIFIED | Row count exact. |
| `notes/structural-econometrcics/data/burn-truth.csv` | 61-row frozen ground truth | ✓ VERIFIED | Row count exact. |
| `notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates-v2.md` | Run 1, FROZEN | ✓ VERIFIED | `# CORRECTIONS` / `FROZEN` header present. |
| `notes/structural-econometrcics/analysis/2026-07-27-upsilon-estimates-v3.md` | Run 2, terminal | ✓ VERIFIED | `STOPPING_RULE: UNINFORMATIVE`, κ finding present. |
| `10-10-DISPOSITION-MEMO.md` / `10-10-PIVOT-LOCK.md` | HALT + lock artifacts | ✓ VERIFIED | Both exist in phase dir, sha256 pin recorded in lock. |
| `notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md` | Extended fidelity record | ✓ VERIFIED | Wedge stats + witness table present. |
| `econometrics/src/Panel/Reconcile.hs` | `gateTolerance = 0.01`, byte-stable | ✓ VERIFIED | Single-commit file, untouched since creation. |
| `econometrics/src/Model/`, `src/Tests/`, `Alternatives.hs` | Byte-unchanged from Phase 9 | ✓ VERIFIED | No commits since Phase-9 tip `bb15a96`. |
| `.planning/ROADMAP.md`, `.planning/STATE.md` | 10-12 skip + CTX-REPLAY-OPT unsatisfied recorded | ✓ VERIFIED | Explicit text confirmed in both. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `premium-accumulators.csv` | `reconcile.md` verdict | `econometrics reconcile` CLI | WIRED | Lineage row cites the exact commit/argv/file; gate reads the committed CSV directly. |
| `reconcile-errors.csv` (10-08) | `panel-epoch.csv` (10-09) | `decomposePremium` telescoping | WIRED | 10-09 self-check: per-tokenId Σ `premium_wei` == Σ `recon_wei` for all 55 tokenIds, `TELESCOPE_MISMATCHES: 0`. |
| `burn-truth.csv` (10-09) | `reconcile-errors.csv` `truth_wei` | frozen-input join | WIRED | 10-09 self-check: `TRUTH_MISMATCHES: 0` across 55 tokenIds. |
| `panel-epoch.csv` (10-09) | estimation panels v2/v3 (10-10) | Phase-9 estimator, CLI `estimate --epoch-panel` | WIRED | Both panels carry 6,760 rows; row-by-row diff confirmed only the authorised sign flip changed (1,735 rows). |
| `Panel.Reconcile.gateTolerance` | gate verdict | direct reference, no override path | WIRED | Constant defined once, referenced by `reportOf`; `git diff` empty across all touching commits. |
| `10-10` estimation result | `10-11` cross-walk | wedge figures + witness status carried forward | WIRED | All six overlapping figures (median/min/max/long-max/short-max/zero-share) reproduce exactly in 10-11's independent recomputation. |

### Requirements Coverage

| Requirement (CTX tag) | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| CTX-SIZE | 10-01 | width!=0 panel-size blocker | ✓ SATISFIED | `requirements: [CTX-SIZE]` in 10-01-PLAN frontmatter; census delivered GO/STOP trail. |
| CTX-FEE | 10-02, 10-03 | Chain layer: ABI, RPC, feeGrowthInside, block index | ✓ SATISFIED | Declared in both plans' frontmatter; `stack test` 215/0 green including `Chain/RpcSpec.hs`. |
| CTX-PREM | 10-05, 10-06 | SFPM getAccountPremium read + premium identity | ✓ SATISFIED | Declared in both plans; premium-accumulators.csv delivered and CLEAN×2 reviewed. |
| CTX-GATE | 10-05, 10-07, 10-08 | Hard reconciliation gate ≤1% wei, stratified | ✓ SATISFIED | `reconcile.md` GATE: PASS verified live. |
| CTX-PANEL2 | 10-03, 10-04, 10-09 | Restored position-epoch panel | ✓ SATISFIED | `panel-epoch.csv` verified, zero unmatched epochs claimed and self-checked in 10-09. |
| CTX-EST2 | 10-10 | Re-estimation under pre-committed, result-blind stopping rule | ✓ SATISFIED | Both runs executed, verdict mechanical (`stoppingRuleVerdict :: Double -> String`), estimator byte-unchanged verified. |
| CTX-XWALK | 10-11 | Lean/Haskell cross-walk multiplier wedge | ✓ SATISFIED | `lean-haskell-crosswalk.md` extended, verified. |
| CTX-REPLAY-OPT | 10-12 | Optional, non-blocking replay cross-check | ✓ UNSATISFIED (correct terminal state — explicit skip, not silent) | ROADMAP/STATE both record the skip with rationale; `10-12-PLAN.md` remains unexecuted in the phase dir. |

No orphaned requirements: all 8 CTX IDs appear in at least one plan's `requirements:` frontmatter, and no plan carries an ID absent from the ROADMAP's declared list (`grep -c '10-[01][0-9]-PLAN.md' .planning/ROADMAP.md` = 12, matching the phase's 12 plan files).

### Anti-Patterns Found

None blocking. Two pre-existing, explicitly deferred items (not introduced by Phase 10, logged in `deferred-items.md` with correct scope reasoning):

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `econometrics/src/Panoptic/Premium.hs` | ~190-208 | Docstring still claims `multiplierWedge` is bounded by 1.125 (measurements refute this: max R/N = 2.333) | ℹ️ Info | Non-blocking; correction lives in the analysis outputs and cross-walk. Deferred as a code change out of 10-11's markdown-only scope. |
| repo root / `model/exp/*` | — | Stray untracked file `bpp@hotmail.es>` and modified `model/` files (GAMS track's, not this session's) | ℹ️ Info | Explicitly out of this session's scope per `CLAUDE.md`; logged and left untouched, correctly. |

No TODO/FIXME/placeholder patterns, no stub returns, and no console-log-only implementations found in any Phase-10-created Haskell module (`Panel/Reconcile.hs`, `Panel/Epoch.hs`, `Panoptic/Premium.hs`, `Panoptic/Sfpm.hs`, `Chain/BlockIndex.hs`) — all backed by passing specs in the 215-example suite.

### Human Verification Required

None required. Every claim checked in this report was verifiable directly against the committed codebase/artifacts (row counts, git history, live `stack test` run, grep against verdict blocks) rather than needing subjective/visual/runtime judgment.

### Gaps Summary

No gaps. The phase's power/success criterion (informative υ₀ CI) was NOT achieved — both estimation runs (10-10, run 1 and the pivot-locked run 2) returned `STOPPING_RULE: UNINFORMATIVE` — but this is the phase's own pre-registered terminal outcome for that branch, and every artifact, checkpoint and disclosure obligation that branch requires is present and correct:

- The gate that had to PASS before estimation could run, did pass, with the full distribution (not just the median) published and both pre-registered suspects for the 8 imperfect spells tested and refuted with evidence rather than hand-waved.
- The one construction defect discovered mid-run (mixed-sign LHS) was handled exactly per the anti-fishing discipline: frozen, escalated, disposed via a written memo, fixed under a hash-pinned pivot lock as a single pre-registered iteration, both results kept on the record side by side, and no further iterations run.
- The stopping-rule verdict function is structurally result-blind (`Double -> String`, no access to κ̂ or p-values), so "the null obtained" cannot be a process artifact of a benevolent verdict function.
- The genuinely new finding (κ̂ > 0 rejects flat-profile H₀ under both LHS constructions) is reported without being oversold as a substitute for the missed stopping-rule bar, and the Lean witness is explicitly stated to not obtain — the theorem stays proved/axiom-clean, the conjecture stays OPEN.
- The one optional plan (10-12 / CTX-REPLAY-OPT) is explicitly, not silently, recorded as skipped and unsatisfied in both ROADMAP and STATE.
- No scope violations: zero lean/ edits by any Phase-10 commit, zero home-absolute paths or credentials in any phase-created artifact, and the estimator stack is provably byte-unchanged from Phase 9.

Status is **passed**: the phase delivered its full process contract, including the honest-null branch, exactly as designed.

---

*Verified: 2026-07-27T18:03:09Z*
*Verifier: Claude (gsd-verifier)*
