---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 11
subsystem: documentation
tags: [cross-walk, fidelity, lean-witness, multiplier-wedge, vegoid, close-out, roadmap, state, anti-overclaim]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 10
    provides: "the terminal estimation result (UNINFORMATIVE x2, kappa>0 x2, witness does not obtain) and the measured wedge figures to carry forward"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 05
    provides: "Panoptic.Premium.multiplierWedge — built in 10-05 for exactly this purpose, reported and never applied"
  - phase: 09-panoptic-upsilon-structural-econometrics
    plan: 07
    provides: "lean-haskell-crosswalk.md — the three-register fidelity table this plan EXTENDS"
provides:
  - "THE CLOSED FIDELITY RECORD: lean-haskell-crosswalk.md now documents the one place the Lean-to-Haskell correspondence is imperfect, with a MEASURED wedge distribution rather than a quoted bound"
  - "NEW MEASURED STATISTICS: wedge p25 1.000000, p75 1.204167, p90 1.291667, mean 1.117256 over 8,910 readings (median/min/max/branch-maxima reproduce 10-10 exactly)"
  - "THE SHAPE-CONTAMINATION DIAGNOSTIC: Pearson 0.143545 / Spearman 0.122141 of wedge against a chunk-level moneyness proxy, non-monotone quintile medians — flagged as a threat to validity, NOT declared negligible"
  - "The terminal witness status recorded in the fidelity record itself (witness does NOT obtain; ATMOTMNullHypothesis OPEN)"
  - "The seller-side sign-convention note — the durable warning against the defect that forced the 10-10 HALT"
  - "ROADMAP + STATE Phase-10 close-out, including the explicit 10-12 SKIP with CTX-REPLAY-OPT recorded UNSATISFIED"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A fidelity record that omits its own imperfections is worse than none: the wedge row is the one row in the cross-walk that says 'these two objects DIFFER', and it is written in the same three-register format as the rows that say they agree."
    - "A quoted bound is recomputed from the data before it is repeated. Every grep-able anchor added here was verified against source in the same session it was written."
    - "When a contamination diagnostic comes back small-but-nonzero, it is reported as small-but-nonzero and flagged — not rounded down to 'negligible' because that would be convenient."
    - "A directional bias argument on a PROXY is labelled as a proxy argument and explicitly denied the status of a correction or a bound."
    - "An optional plan that is skipped has its requirement ID recorded as UNSATISFIED, never silently checked off."

key-files:
  created:
    - ".planning/phases/10-streaming-premium-reconstruction-and-reestimation/10-11-SUMMARY.md"
  modified:
    - "notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md"
    - ".planning/ROADMAP.md"
    - ".planning/STATE.md"

key-decisions:
  - "The wedge distribution was recomputed here rather than only quoted, on the full 8,910-reading basis, in exact rational arithmetic. The five figures 10-10 published (median 1.112500, min 1.000000, max 1.291667, long max 1.291667, short max 1.204167, 3467/8910 at exactly 1) REPRODUCE EXACTLY; p25, p75, p90 and the mean are new and the method is written into the file."
  - "The plan asked for the wedge over panel-epoch.csv; it was computed over premium-accumulators.csv instead, because that is the file that carries removed_liquidity and net_liquidity (panel-epoch.csv does not) and it is the basis both prior analyses used. Computing it on a different basis would have produced figures inconsistent with the frozen outputs — the exact failure mode the plan warned against."
  - "The shape contamination was NOT declared negligible. The plan offered both branches; the data chose the second. 38.9% of readings sit at exactly 1, so the distribution is not near-degenerate, and the moneyness co-variation is small but nonzero (Pearson 0.143545) with a non-monotone quintile profile. It is recorded as a threat to validity."
  - "The contamination's DIRECTION is stated once — it biases kappa-hat towards zero, so the kappa>0 rejection is conservative with respect to it — and immediately fenced: proxy-based, not a correction, not a bound, chunk-level where the panel is position-level."
  - "10-12 is SKIPPED and CTX-REPLAY-OPT is recorded as UNSATISFIED rather than marked done. The purpose is already served wei-exactly by the 10-08 gate plus two CLEAN anti-fabrication reviews; the plan file stays in place, unexecuted."
  - "No Lean file was touched and no lake build or Aristotle task was run. Nothing in Lean changed, so building would prove nothing and running Aristotle would risk the concurrent sessions' in-flight work."

patterns-established:
  - "A phase closes by writing down where it is WRONG, not only what it achieved — and the closing plan's deliverable is the correction of a number the phase itself had been quoting."

requirements-completed: [CTX-XWALK]
requirements-unsatisfied: [CTX-REPLAY-OPT]

# Metrics
duration: ~35m
completed: 2026-07-27
---

# Phase 10 Plan 11: Multiplier-Wedge Cross-Walk and Phase Close-Out Summary

**The Lean/Haskell fidelity record now documents the one place the correspondence is imperfect — Panoptic's utilization multiplier — as a MEASURED distribution over all 8,910 accumulator readings (median 1.112500, p90 1.291667, 38.9% exactly 1, max implied R/N 2.333333) that corrects rather than repeats the 1.125 bound the phase had been quoting; the wedge's shape contamination is reported as small-but-nonzero and flagged as a threat to validity rather than rounded down to negligible; and Phase 10 closes with its success criterion NOT met, its witness NOT obtaining, and its one optional plan skipped with the requirement recorded unsatisfied.**

## Performance

- **Duration:** ~35m
- **Tasks:** 2, both autonomous, no checkpoints
- **Files:** 4 (1 created, 3 modified)
- **Suite:** **215 examples, 0 failures** (unchanged — this plan changed no code)
- **Lean:** `git status --porcelain lean/` **empty** across both commits

## Task Commits

1. **Extend the cross-walk with the measured Panoptic-multiplier wedge** — `8cba914` (docs)
2. **ROADMAP + STATE Phase-10 close-out** — `0258034` (docs)

## THE MEASURED WEDGE

Computed by `Panoptic.Premium.multiplierWedge` over **all 8,910** rows of
`notes/structural-econometrcics/data/premium-accumulators.csv`, in exact rational arithmetic,
using each row's own `removed_liquidity`, `net_liquidity` and `is_long`.

```
N (readings)                          8910
min                                   1.000000
p25                                   1.000000
MEDIAN                                1.112500
mean                                  1.117256
p75                                   1.204167
P90                                   1.291667
max                                   1.291667
share with R = 0 (wedge exactly 1)    3467 / 8910 = 0.389113
long  (n = 2839)  median / max        1.222222 / 1.291667
short (n = 6071)  median / max        1.000000 / 1.204167
implied max R/N on long readings      2.333333
1 + nu, the figure quoted as a bound  1.125            <- FALSE on this market
```

**Reproduction check.** Six of these figures were already published in
`2026-07-20-upsilon-estimates-v2.md` §7 and `2026-07-27-upsilon-estimates-v3.md` §8 — median,
min, max, long max, short max, and the 3467/8910 zero-share. All six reproduce **exactly** from
an independent recomputation on the raw CSV. p25, p75, p90 and the mean are new to this plan
and the computation method is written into the cross-walk beside them.

**The 1.125 correction.** `1 + nu*R/N <= 1 + nu` requires `R <= N`. On this market `R/N`
reaches 2.333333, so the long branch exceeds 1.125; the short branch does too once
`R` passes roughly `1.62*N`. The cross-walk now states the measured figures and marks 1.125 as
the figure the phase context *quoted*, not as a ceiling.

**Edge case, handled and stated:** 54 readings carry `net_liquidity = 0` (`ChunkEmpty`). All 54
also carry `R = 0`, so `multiplierWedge`'s `removedLiq == 0` branch returns `1` before any
division — no division by zero arises, and the published 8,910 basis is intact.

## The level-vs-shape consequence, stated in both directions

The plan required this to be stated without overclaiming either way. It resolved as follows.

- **LEVEL — unambiguous.** `upsilon0-hat` is the vega of **Panoptic's** premium, not of the bare
  fee-revenue identity `Panoptic.streamingPremium` models. Any comparison against a Lean
  `streamingPremium` quantity must carry a factor centred at 1.1125 with measured range
  [1.000000, 1.291667]. This is a reinterpretation of what the parameter denotes — **never an
  adjustment to apply**, because the multiplier is already inside the contract's X64 accumulator
  and re-applying it would double-count.

- **SHAPE — NOT declared negligible.** The plan's first branch ("if near-degenerate at 1, say the
  contamination is negligible and give the number") does **not** apply: only 38.9% of readings
  sit at 1 and the median is 1.1125. Using each reading's chunk centre `(tick_lower +
  tick_upper)/2` against its `at_tick` as a chunk-level moneyness proxy `d`:

  ```
  Pearson  corr(wedge, d) = 0.143545
  Spearman corr(wedge, d) = 0.122141
  median wedge by d-quintile (cuts 266 / 554 / 909 / 1089 ticks):
      1.125000, 1.000000, 1.000000, 1.112500, 1.187500   <- NON-MONOTONE
  ```

  Small, positive, nonzero. **Flagged as a threat to validity.**

- **Direction, stated once and fenced.** A wedge rising in `d` inflates far-OTM premia relative
  to ATM, flattening the observed decay, which biases `kappa-hat` **towards zero**. So the
  Phase-10 rejection of H0: kappa = 0 (p = 7.308348e-3) is, under this proxy, *conservative*
  with respect to this contamination rather than manufactured by it. The cross-walk immediately
  states what this is not: a proxy-based directional argument, **not** a bias correction and
  **not** a bound — the proxy is chunk-level while the panel's moneyness is position-level
  `|i_K - i_t|`, and no attempt was made to convert it into an adjustment.

## The witness status, recorded terminally

| item | status |
|---|---|
| `Upsilon.exp_family_witnesses_ATMOTM` | **PROVED**, sorry-free, axiom-clean (`[propext, Classical.choice, Quot.sound]`). Untouched by Phase 10. |
| `hk : 0 < kappa` | **STATISTICALLY SUPPORTED** — 3.041754e-2, SE 1.245733e-2, p = 7.308348e-3; rejects under BOTH LHS constructions |
| `hu : 0 < upsilon0` | **SIGN ONLY, NOT supported** — 0.106332, SE 0.100998, 95% CI [-9.162517e-2, 0.304289] contains zero, p = 0.146215 |
| `hd : 0 < Delta_i` | SATISFIED (10, the pool tickSpacing) |
| **The witness** | **DOES NOT OBTAIN.** The theorem takes `hu` AND `hk`. |
| `Upsilon.ATMOTMNullHypothesis` | **CONJECTURE OPEN** |

## The sign-convention note

Recorded so no future consumer repeats the defect that forced the 10-10 HALT:
`panel-epoch.csv`'s `premium_wei` is the **protocol's own sign** and is canonical (summing it
over a tokenId reproduces that spell's gate-validated `recon_wei` exactly), while the
**regression LHS** requires `Panel.Build.premiumUsd`'s seller-side normalization applied via
`--seller-side-normalize`. `estimation-panel-v2.csv` is the un-normalized arm,
`estimation-panel-v3.csv` the normalized one. Neither is wrong; mixing them silently is the
defect.

## New grep-able fidelity anchors (each verified against source before writing)

- `Panoptic.Premium.multiplierWedge` — `nu = 1 % 8`, `removedLiq == 0 => 1` branch first
- `Panoptic.Sfpm.vegoidConst == 8`, written into `getAccountPremiumCalldata` slot 7
- `Panoptic.Premium.premiumWei` divides by `2 ^ (64 :: Int)` (X64, not 2^128, not 2^96) and negates long legs
- `Panoptic.Premium.decomposePremium` — not `telescope` — is what `premiumObsChain` builds the panel from
- `Panel.Build.premiumUsd` carries `sign = if isLong then -1 else 1`

Verified live: `Panel/Build.hs:167` has the sign; `Sfpm.hs:72` has `vegoidConst = 8` and
`Sfpm.hs:140` the slot-7 encoding; `Premium.hs:129` has the `2 ^ (64 :: Int)` division;
`Premium.hs:304-305` show `premiumObsChain` calling `decomposePremium`.

## THE PHASE'S VERDICT CHAIN (as written to ROADMAP)

```
Wave-0 census      GO   (hourly re-scope; the daily grid returned STOP and it was HONOURED)
Reconciliation gate PASS (61/61 spells, short-stratum median rel. error 0.000000 in ETH wei,
                          53/61 exact to the wei, worst 5.447268e-4, tolerance 0.01 never moved)
Stopping rule      UNINFORMATIVE, under BOTH LHS constructions
                          (half-widths 1.479533e-1 and 1.979569e-1 vs the never-moved 6.2e-5 bar)
=> THE PHASE'S SUCCESS CRITERION IS NOT MET, AND THAT IS THE REPORTED RESULT.
   This market cannot identify upsilon. The binding constraint is the 55-cluster ceiling.
```

## The CTX requirement IDs as they stand in ROADMAP

`CTX-SIZE`, `CTX-FEE`, `CTX-PREM`, `CTX-GATE`, `CTX-PANEL2`, `CTX-EST2`, `CTX-XWALK` —
**satisfied**. `CTX-REPLAY-OPT` — **UNSATISFIED, by choice**.

Verified: every one of the eight IDs appears in at least one `requirements:` frontmatter across
`10-01`..`10-12-PLAN.md`, and no plan carries an ID absent from the ROADMAP list.
`grep -c '10-[01][0-9]-PLAN.md' .planning/ROADMAP.md` returns **12**.

## The 10-12 SKIP, recorded explicitly

10-12 (CTX-REPLAY-OPT, narrow-window V4 replay cross-check) is **SKIPPED**. Reason written into
both ROADMAP and STATE: the cross-check's purpose is independent evidence that the reconstructed
premium really is the protocol's, and that purpose is already served — the 10-08 gate reconciles
all 61 spells against on-chain `OptionBurn.premium0` in exact Integer ETH wei with 53/61 exact
to the wei, and two independent anti-fabrication reviewers returned CLEAN (live archive re-read,
32/32 integers exact; full offline Python recomputation, no planted literals). The plan was
optional and non-blocking by construction and nothing downstream depends on it.

**CTX-REPLAY-OPT is recorded as unsatisfied, not quietly checked off.** The plan file stays in
place, unexecuted; the user may request the run later.

## Deviations from Plan

### 1. [Rule 3 — Blocking] The wedge was computed over `premium-accumulators.csv`, not `panel-epoch.csv`

- **Found during:** Task 1, setting up the measurement.
- **Issue:** The plan directs `multiplierWedge` over "the rows of `panel-epoch.csv`". That file
  carries no `removed_liquidity` or `net_liquidity` column — the wedge is not computable from it.
  The function's three inputs live in `premium-accumulators.csv`, which is also the basis both
  frozen analyses used (8,910 readings).
- **Fix:** Computed on the accumulator file. This is also what the plan's own guard demanded —
  "quote the figures already computed rather than recomputing them inconsistently"; using a
  different basis would have produced numbers that disagree with the frozen outputs.
- **Verification:** the six overlapping figures reproduce exactly.
- **Commit:** `8cba914`.

### 2. [Rule 2 — Missing critical functionality] The shape-contamination claim was measured, not asserted

- **Found during:** Task 1, writing the level-vs-shape section.
- **Issue:** The plan permits saying the contamination is negligible *if* the distribution is
  near-degenerate at 1. It is not (median 1.1125, only 38.9% at exactly 1). Writing
  "negligible" would have been unsupported, and writing nothing would have left the plan's
  central question — does `R/N` co-vary with moneyness? — unanswered in the fidelity record.
- **Fix:** Computed the co-variation directly on the same 8,910 readings using a chunk-level
  moneyness proxy, reported Pearson/Spearman and the quintile profile, flagged it as a threat to
  validity, and fenced the directional argument as proxy-based.
- **Direction:** strictly harder to assert. The plan's easier branch was available and the data
  did not support it.
- **Commit:** `8cba914`.

### 3. [Adaptation] ROADMAP was already largely closed out

- Phase 10's `**Requirements**` line, the amended-route Goal paragraph and the 12-plan list were
  already written by earlier plans in the phase. Task 2's remaining work was the phase-outcome
  line, the 10-11 checkbox, the plan count, and the 10-12 skip. No placeholder (`TBD`,
  `0 plans`, `- [ ] TBD`) remained to replace.

### Not done (correctly)

- **No Lean file touched.** `git status --porcelain lean/` empty at plan start and after both
  commits. No `lake build` (nothing changed) and no Aristotle task, per the plan's instruction
  and the concurrent-session boundary in `CLAUDE.md`.
- **No econometrics source changed.** `Panoptic/Premium.hs`'s docstring still describes 1.125 as
  the long bound; correcting it is a code change outside this plan's `files_modified`, and it is
  carried as a deferred item rather than fixed opportunistically.
- **`requirements mark-complete` not run.** `.planning/REQUIREMENTS.md` is the v1 Plank/GAMS
  milestone document and contains no `CTX-*` IDs; the CTX tags are phase-local to ROADMAP and the
  plan frontmatter. Running the tool would have matched nothing.

## Authentication Gates

None. This plan made zero network calls; every input was a committed local artifact.

## Deferred Issues

Appended to the phase's existing `deferred-items.md`, not fixed here (out of this plan's scope):

- **New in 10-11:** `econometrics/src/Panoptic/Premium.hs` — the `multiplierWedge` docstring
  still describes `<= 1.125` as the long-side bound, which the measurements refute. A code
  change, not a docs change; the correction currently lives in the two analysis outputs and now
  the cross-walk. Fixing it changes no behaviour and no test.
- **Already logged under 10-07, still present and again untouched:** `model/exp/eta.md`
  (modified), `model/exp/eta_pi_trader_delta_control.md` (untracked), and a stray zero-content
  file named `bpp@hotmail.es>` in the repo root (an accidental shell-redirect artifact).
  `model/` belongs to the GAMS-development session per `CLAUDE.md`.

## Next Phase Readiness

- **Phase 10 is closed.** Nothing is scheduled. The estimation question is answered — this
  market cannot identify `upsilon` — and the fidelity record is complete including its
  imperfections.
- **If 10-12 is ever wanted**, the plan file is in place and unexecuted, and `CTX-REPLAY-OPT` is
  already recorded as the one unsatisfied requirement.
- **Carry-forward for any future work on `upsilon` identification:** the binding constraint is
  the **55-cluster ceiling** (84.1% of rows in ten positions). More hours on existing positions
  cannot help; more INDEPENDENT positions would be required. Any respecification that does not
  add clusters is not addressing the constraint.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-27*

## Self-Check: PASSED

- **All 5 claimed files exist on disk** (1 created, 3 modified, 1 appended).
- **Both claimed commits exist in history** — `8cba914`, `0258034`.
- **The wedge figures were RECOMPUTED, not copied.** An independent pass over the raw
  `premium-accumulators.csv` in exact rational arithmetic reproduces all six previously
  published figures exactly — median `1.112500`, min `1.000000`, max `1.291667`, long max
  `1.291667`, short max `1.204167`, and `3467 / 8910` readings at exactly 1 — and yields the
  four new ones (p25 `1.000000`, p75 `1.204167`, p90 `1.291667`, mean `1.117256`). The
  8,910-row basis was re-counted from the file.
- **The `net_liquidity = 0` edge case was checked, not assumed:** 54 such rows, of which
  **0 have `R > 0`**, so no division by zero occurs and the R=0 branch legitimately returns 1.
  This also explains the exact reconciliation with the published counts (long 2839 vs 2834
  non-empty, short 6071 vs 6022; 5 + 49 = 54).
- **Every grep-able anchor was verified against source before being written:**
  `Panel/Build.hs:167` (`sign = if isLong then -1 else 1`), `Sfpm.hs:72` (`vegoidConst = 8`),
  `Sfpm.hs:140` (slot-7 encoding), `Premium.hs:129` (`2 ^ (64 :: Int)`), `Premium.hs:205`
  (`nu = 1 % 8`), `Premium.hs:304-305` (`premiumObsChain` calling `decomposePremium`, so the
  "not `telescope`" claim is about the actual call site).
- **`git status --porcelain lean/` is EMPTY** — checked at plan start and after both commits.
  No Lean file touched, no `lake build`, no Aristotle task.
- **All 8 CTX IDs in the ROADMAP list appear in at least one plan's `requirements:`
  frontmatter**, and no plan carries an ID absent from the list.
  `grep -c '10-[01][0-9]-PLAN.md' .planning/ROADMAP.md` = **12**.
- **No NEW home-absolute path introduced:** `git diff | grep '^+' | grep -E '/home/|\$HOME|~/'`
  is empty across all three modified files. (Three pre-existing matches in ROADMAP/STATE are the
  REPO-05 *rule text* describing the prohibition, not paths.)
- **Suite: 215 examples, 0 failures** — re-run after the edits; this plan changed no code.
</content>
</invoke>
