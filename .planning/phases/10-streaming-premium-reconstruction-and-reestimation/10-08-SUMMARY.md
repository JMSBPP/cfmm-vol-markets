---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 08
subsystem: validation-gate
tags: [reconciliation, gate, premium, wei, stratification, checkpoint, anti-fabrication, haskell, cli]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 06
    provides: "premium-accumulators.csv (8,910 rows incl. the 130 exact-block mint/burn endpoint rows the gate reads)"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 07
    provides: "Panel.Reconcile (gateTolerance=0.01, reportOf, stratify, errorDist) + the reconcile CLI + the 5-spell pre-check (median 0.0)"
provides:
  - "notes/structural-econometrcics/data/reconcile.md — THE 61-spell gate report: lineage, verbatim verdict block, both stratum distributions, all 61 per-spell rows, worst-5 diagnosis, authored wedge attribution"
  - "notes/structural-econometrcics/data/reconcile-errors.csv — 61 machine-readable per-spell rows (token_id,is_long,leg_count,leg_count_truth,recon_wei,truth_wei,rel_error,signed_error_wei,flags)"
  - "reconcile CLI --errors-csv option; verbatim-stdout verdict block in the report; mechanical worst-5 diagnosis table"
  - "THE VERDICT: GATE: PASS at MEDIAN_REL_ERROR_SHORT = 0.0, LEGCOUNT_MISMATCHES = 0, gateTolerance = 0.01 UNMODIFIED"
  - "The residual-wedge diagnosis: an end-of-block vs at-transaction eth_call read wedge, irreducible at block granularity, bounded at 5.447268e-4"
affects: [10-09, 10-10, 10-11]

# Tech tracking
tech-stack:
  added: ["process (executable dep, for the git-commit lineage lookup)"]
  patterns:
    - "The verdict labels are built ONCE as a single list and used for BOTH stdout and the published artifact, so a captured transcript and the committed report cannot disagree about the verdict."
    - "The report carries the lineage it cannot reconstruct for itself — git commit, the exact argv, SFPM target, VEGOID, accumulator row count and block range — so a gate result is attributable to a commit and a command rather than to a session."
    - "rel_error is NA (never 0) when the ground truth is zero, so a zero-truth exclusion can never be read downstream as a perfect reconstruction."
    - "A pre-registered suspect is TESTED and REFUTED with evidence before publication, not carried forward as a caveat. Both of 10-07's named suspects were falsified against subgraph history and the leg-count cross-tab."
    - "A residual is sized against a physical scale (per-block accrual, per-unit-liquidity), not against the tolerance — which is what turned an 'outlier at 72x' into 'sub-block, like the other seven'."

key-files:
  created:
    - "notes/structural-econometrcics/data/reconcile.md"
    - "notes/structural-econometrcics/data/reconcile-errors.csv"
  modified:
    - "econometrics/app/Main.hs"
    - "econometrics/package.yaml"
    - "notes/structural-econometrcics/data/premium-accumulators-lineage.md"

key-decisions:
  - "GATE: PASS on all 61 spells with gateTolerance = 0.01 BYTE-IDENTICAL throughout — git diff on Panel/Reconcile.hs is empty across every commit of this plan. The verdict was scored on the SHORT stratum (median 0.0) plus zero leg-count mismatches, exactly as 10-07's reportOf defines it."
  - "USER ADJUDICATION: proceed. Recorded before a halt, executed only after the user-mandated anti-fabrication review gate returned CLEAN from two independent reviewers."
  - "BOTH pre-registered suspects REFUTED before publication. Multi-leg summation: 4 of 7 two-leg spells are exact to the wei and the third-worst spell is single-leg, so leg count is exposure, not mechanism. Mid-spell s_options rewrite: all 8 imperfect spells have exactly one mint, one burn, and identical positionSize at both ends — no intermediate touch existed to rewrite the baseline."
  - "The residual mechanism is an END-OF-BLOCK vs AT-TRANSACTION read wedge: eth_call resolves state at end-of-block while _getPremia evaluated the accumulator at its transaction's position inside that block. It is IRREDUCIBLE at eth_call granularity — reading at burnBlock-1 relocates the same error with the opposite sign — and removing it would need transaction-level state (debug_traceTransaction / state-override replay), a different data route rather than a correction to this one."
  - "The long stratum needed no allowance: 8 of 8 long spells are EXACT. The _getAvailablePremium settlement cap the phase expected to open a downward long wedge did not bind on any spell in this sample. Reported, not assumed — the long stratum stays excluded from the pass/fail arithmetic exactly as 10-07 specified."
  - "The CLI's report-plumbing gaps were fixed in app/Main.hs and NEVER in Reconcile.hs, preserving the 'was the tolerance module touched?' check as a trivial one-line audit."

patterns-established:
  - "A gate verdict is adjudicated by the user and gated on an independent anti-fabrication review before any downstream plan consumes it — the executor reports, it does not self-certify."
  - "Diagnosis of an in-tolerance residual is performed and published anyway. A PASS with an unexplained 500,000x-the-floor outlier is a PASS whose meaning is unknown."

requirements-completed: [CTX-GATE]

# Metrics
duration: ~60min executor + review gate
completed: 2026-07-26
---

# Phase 10 Plan 08: The Full 61-Spell Hard Gate Summary

**The reconstruction was scored against the protocol's own `OptionBurn.premium0` on all 61 spells in Integer ETH wei and it PASSED at a short-stratum median relative error of exactly 0.0 — 53 of 61 spells reproduce the ground truth bit-for-bit to the wei, all 8 long spells are exact, and the worst spell in the sample misses by 5.447268e-4, eighteen times inside a `gateTolerance = 0.01` that is byte-identical to the constant 10-07 committed; both of 10-07's pre-registered suspects for the eight imperfect spells were falsified before publication and the residual was identified instead as an end-of-block vs at-transaction `eth_call` wedge that is sub-block on every one of the eight and irreducible at block granularity.**

## Performance

- **Duration:** ~60 min executor (Task 1 landed 08:43), plus a halt and the user-mandated review gate (closed 13:37)
- **Tasks:** 2 (Task 1 auto, Task 2 blocking decision checkpoint — adjudicated by the user)
- **Files:** 5 (2 created, 3 modified)
- **Suite:** **176 examples, 0 failures** — unchanged, as required

## Task Commits

1. **Task 1: full 61-spell stratified gate + published distribution** — `63a3fa2` (feat)
2. **Review-gate corrections to the read lineage** — `9ad94b2` (docs)

## Gate Verdict

Verbatim from `notes/structural-econometrcics/data/reconcile.md`:

```
SPELLS_RECONCILED: 61
GROUND_TRUTH_UNIT: RawWei
MEDIAN_REL_ERROR_ALL: 0.000000
N_SHORT: 53
MEDIAN_REL_ERROR_SHORT: 0.000000
P90_REL_ERROR_SHORT: 1.220169e-9
MAX_REL_ERROR_SHORT: 5.447268e-4
SIGNED_BIAS_SHORT: 3/5
N_LONG: 8
MEDIAN_REL_ERROR_LONG: 0.000000
MAX_REL_ERROR_LONG: 0.000000
SIGNED_BIAS_LONG: 0/0
LEGCOUNT_MISMATCHES: 0
ZERO_TRUTH_EXCLUDED: 0
LABEL_DISAGREEMENTS: 0
CENSUS_MISMATCHES: 0
GATE_TOLERANCE: 0.01
GATE: PASS
```

**`MEDIAN_REL_ERROR_SHORT`: 0.000000 — `MEDIAN_REL_ERROR_LONG`: 0.000000 — `GATE: PASS`**

### USER DECISION: **proceed**

Recorded in STATE before a halt, and executed only after the user's required
anti-fabrication review gate returned **CLEAN from two independent reviewers**.
`GATE: PASS` is present in `reconcile.md`, so `proceed` is a valid combination
and no escalation was required.

### Stratified distributions

| stratum | n | median | p25 | p75 | p90 | max | recon>truth | recon<truth | zero-truth excl. |
|---|---|---|---|---|---|---|---|---|---|
| **short** (THE verdict) | 53 | 0.0 | 0.0 | 0.0 | 1.220169e-9 | **5.447268e-4** | 3 | 5 | 0 |
| **long** (reported, not scored) | 8 | 0.0 | 0.0 | 0.0 | 0.0 | **0.0** | 0 | 0 | 0 |
| all (diagnostic only) | 61 | 0.0 | 0.0 | 0.0 | 1.299713e-10 | 5.447268e-4 | 3 | 5 | 0 |

**53 of 61 spells reproduce `OptionBurn.premium0` EXACTLY, to the wei.** The full
per-spell table (61 rows) is published in `reconcile.md` regardless of the
verdict, and `reconcile-errors.csv` carries the same 61 rows machine-readably.

## The diagnosis: both pre-registered suspects refuted

Three short spells sit materially above the ~1e-9 flooring floor 10-07
established (5.45e-4, 3.25e-5, 1.11e-7). 10-07 named the two wedges its
single-leg pre-check population could not exercise. **Both were tested before
this report was published, and both are refuted.**

**Suspect 1 — multi-leg summation: REFUTED.**

| legs | spells | above the 1e-9 floor |
|---|---|---|
| 1 | 54 | 3 |
| 2 | 7 | 3 |

A broken summation would miss on *every* multi-leg spell. Four of the seven
two-leg spells are exact to the wei, and the third-worst spell is **single-leg**.
Leg count raises exposure (two chunks, two endpoint readings), it is not the
mechanism.

**Suspect 2 — mid-spell `s_options` rewrite: REFUTED.** All 8 imperfect spells
were queried against the subgraph for their complete `optionMints`/`optionBurns`
history. Each has **exactly one mint and exactly one burn**, with **identical
`positionSize`** at both ends. No intermediate mint, partial burn or roll existed
to rewrite `s_options` — precisely the configuration the reconstruction assumes.

**What it actually is — an END-OF-BLOCK vs AT-TRANSACTION read wedge.** `eth_call`
resolves state at the end of a block; `_getPremia` evaluated the same accumulator
at its transaction's position *inside* that block. Four independent lines of
evidence:

1. **Every residual is a sub-block quantity.** Seven of eight are strictly below
   one block's average accrual for their own spell (0.11, 0.07, 0.004, 0.003,
   0.002, 0.000, 0.000). The eighth measures 72 average blocks — but that burn
   drops the chunk from `netLiquidity` 3.798e11 to 1.519e9, a **250x collapse**,
   and the accumulator is *per unit liquidity*: 72.17 / 250 = **0.29 of one
   block's fees**.
2. **The signs obey the live-chunk rule without exception.** A swap after the
   mint tx inflates `acc(mint)` (negative); a swap after the burn tx inflates
   `acc(burn)` (positive) *only if the chunk still holds net liquidity*. Exactly
   one spell has a chunk alive and in range at its burn block — `tokenType=1`,
   `[-201120,-198720]`, `netLiquidity = 1.519e9`, tick −200340 — and it is
   exactly the one positive wedge of any size.
3. **The base rate matches.** 0.124 swaps/block on this pool (632,315 V4 swaps
   over 5,097,804 blocks) x 2 endpoints x half a block ~ **12%** of spells
   expected to carry a wedge. Observed: **8/61 = 13.1%**.
4. **It is not a multiplier or scale bug.** The scaling-signature check is clean
   (no `|recon|/|truth|` within 1% of 2^64, 2^128, 1e12, 1e18 or reciprocals),
   the sign split is two-sided (3 over / 5 under), and no multiplier error can
   produce 53 exact-to-the-wei reconstructions.

**It is irreducible at this granularity.** `eth_call` cannot address a point
inside a block; reading at `burnBlock - 1` relocates the same error to the front
of the block with the opposite sign. Eliminating it requires transaction-level
state (`debug_traceTransaction` or a state-override replay) — a different data
route, not a correction to this one. Bounded at 5.447268e-4, it is **18x inside
the tolerance** and does not move the median off 0.0.

**The long stratum needed no allowance.** All 8 long spells are exact
(`SIGNED_BIAS_LONG: 0/0`). The `_getAvailablePremium` settlement cap
(PanopticPool L588-599) that the phase expected to open a downward long wedge
**did not bind on any spell in this sample**. Reported rather than assumed; the
long stratum stays out of the pass/fail arithmetic exactly as 10-07 specified.

**One honest caveat.** Two of the smallest residuals (+67 and +1 wei, at 1.3e-10
and 1.4e-12 relative) are **positive**, whereas 10-07 characterised the flooring
residue as strictly one-signed downward. That was a two-observation
generalisation the 61-spell sample does not support. Immaterial in magnitude,
recorded rather than smoothed over.

## Anti-fabrication review (user-mandated, ran before this close-out)

The `proceed` decision was held at a halt until two independent reviewers had
attempted to falsify the result. **Both returned CLEAN.**

- **Reviewer A — live provenance: CLEAN.** 8 CSV rows re-read against the Base
  archive at the same blocks: **32/32 integers exact**. Four golden-fixture
  readings reproduced byte-identical. The `reconcile` CLI re-run produced a
  **byte-identical** errors CSV and verdict block. Three subgraph ground-truth
  burns match.
- **Reviewer B — offline forensics: CLEAN.** **All 61 `recon_wei` reproduced
  exactly** in independent Python from the committed artifacts. Distribution
  statistics recompute exactly. The gate logic is single-commit and unchanged
  across the results. No planted literals.
- **Known recorded limitation:** `truth_wei` is fetched live from the subgraph at
  reconcile time and materialises only in `reconcile-errors.csv` (the output).
  Mitigations, documented in the lineage's review section: Reviewer A re-queried
  three burns live (exact match); the `truth_wei`/`premium_usd` ratio against the
  Phase-9-committed `panel.csv` sits in a tight plausible ETH-price band across
  55 tokenIds; and 53/61 truths equal wei-exact integer computations over the
  committed accumulator rows.
- **Corrections applied** from the reviews, committed as `9ad94b2`: the cycle-6
  completion date, the dataset-wide empty-chunk count (**54**, not the
  slice-local `CHUNK_EMPTY_ROWS: 44` the driver's stdout reports), and the
  unused-sentinel wording (no row in the dataset uses the `8388607` stored-value
  sentinel — all 8,910 reads pass a real tick, consistent with every spell being
  flagged `Extrapolated`).

## Accomplishments

- **Ran the hard gate on the full population** — 61 spells, both strata, no
  selection flags, in Integer ETH wei end to end, with `LABEL_DISAGREEMENTS: 0`
  and `CENSUS_MISMATCHES: 0` confirming the gate's own inputs still agree with
  `panel.csv` and `chunk-legs.csv`.
- **Published the whole distribution, not the median** — both stratum tables with
  p25/p75/p90/max and sign counts, all 61 per-spell rows, and the machine-readable
  companion CSV, exactly as the CONTEXT decision requires of a gate whose verdict
  is meant to be auditable rather than announced.
- **Diagnosed an in-tolerance residual anyway.** A PASS carrying an unexplained
  outlier 500,000x above the known floor is a PASS whose meaning is unknown. Both
  named suspects were falsified with evidence and the true mechanism identified,
  quantified against a physical scale, and shown irreducible.
- **Kept the tolerance auditable by construction.** Every report-plumbing gap was
  fixed in `app/Main.hs`; `Panel/Reconcile.hs` is byte-identical across both
  commits, so "was the goalpost moved?" stays a one-line `git diff`.

## Deviations from Plan

### Auto-fixed / added

**1. [Rule 2 - Missing critical functionality] The CLI could not produce the plan's deliverables**
- **Found during:** Task 1, pre-flight against the plan's acceptance greps.
- **Issue:** Three gaps. (a) There was no `--errors-csv` at all, yet the plan
  requires `reconcile-errors.csv` with a fixed header. (b) The report rendered
  `` `GATE_TOLERANCE`: 1.0e-2 `` (backticked, and Haskell's `show` notation) and
  `**GATE: PASS**` — neither matches the plan's pre-committed
  `grep -q 'GATE_TOLERANCE: 0.01'` and `grep -qE '^GATE: (PASS|FAIL)$'`. A gate
  whose verdict line silently fails the grep that reads it is the exact failure
  mode those lines exist to prevent. (c) No worst-5 diagnosis table.
- **Fix:** In `app/Main.hs` only — added `--errors-csv`; built the verdict labels
  as ONE list shared by stdout and a verbatim report block spliced in after the
  lineage; added the mechanical worst-5 table and the exact-reconstruction count;
  enriched the lineage with git commit, exact argv, SFPM target, VEGOID,
  accumulator rows and block range, and the epoch definition. Added `process` to
  the executable deps for the commit lookup.
- **Why not in `Reconcile.hs`:** deliberately, to preserve 10-07's auditability
  property — the tolerance module stays byte-identical across the plan.
- **Files:** `econometrics/app/Main.hs`, `econometrics/package.yaml`. **Commit:** `63a3fa2`.

**2. [Documentation truthfulness] Read-lineage corrections from the review gate**
- **Found during:** the anti-fabrication review.
- **Issue:** Three inaccuracies in `premium-accumulators-lineage.md`: a wrong
  cycle-6 completion date, an empty-chunk count that reported the driver's
  slice-local stdout stat (44) as if it were dataset-wide (54), and wording
  implying the `8388607` sentinel was in use when no row uses it.
- **Fix:** All three corrected, with the review findings and the recorded
  `truth_wei` limitation appended to the lineage.
- **Files:** `notes/structural-econometrcics/data/premium-accumulators-lineage.md`. **Commit:** `9ad94b2`.

### Not done (correctly)

- **`gateTolerance` was not modified, at any point, in any direction.**
  `git diff -- econometrics/src/Panel/Reconcile.hs` is empty across `63a3fa2` and
  `9ad94b2`. It was never close to being needed — the short-stratum median is 0.0 —
  but the property was checked rather than assumed.
- **The verdict was not self-adjudicated.** Task 2 is a blocking decision
  checkpoint; the executor stopped, reported, and waited. The user selected
  `proceed`, and only after an independent review gate.
- **The sub-block wedge was not "fixed".** Chasing it means a different data
  route (transaction-level replay), not a correction — and it is 18x inside the
  tolerance. Recorded as a known, quantified limitation instead.

## Authentication Gates

None. The gate used the keyless public Goldsky Base subgraph (no `GRAPH_API_KEY`
set or needed) and read accumulators from the committed CSV. No credential
appears in either output artifact, and both were checked for home-absolute paths.

## Issues Encountered

- The subgraph advanced between the pre-check and the gate (1602 -> 1603 mints,
  1586 -> 1588 burns). The paired accrual-spell count is unchanged at 61 and
  `panel.csv` remains THE fixed gate population, so the comparison is unaffected —
  noted because a moving upstream is exactly the kind of drift that should be
  visible rather than absorbed.
- Two consecutive gate runs produced byte-identical verdict blocks and error CSVs,
  which is the reproducibility property the 10-11 audit will rely on.

## Next Phase Readiness

- **10-09 (panel construction):** unblocked by the user's `proceed`. The LHS is
  validated against on-chain ground truth at 1% in wei — the measurement failure
  that made Phase 9 uninformative is demonstrably fixed. Build the hourly panel on
  the reconstruction, and carry `PremiumFlag`s plus the per-spell
  `signed_error_wei` from `reconcile-errors.csv` forward so the estimation can
  stratify on the 8 wedge-affected spells if it wants to.
- **10-10 (the stopping rule):** a passing gate validates **measurement, not
  identification**. The pre-committed CI half-width bar (<= 6.2e-5) remains the
  independent success criterion and may still not be met — the 55-cluster ceiling
  and the noisier hourly sigma^2 accepted at 10-01 are unchanged by this result.
- **10-11 (audit):** `reconcile.md` and `reconcile-errors.csv` are the lineage
  artifacts; the wedge attribution, the review-gate findings and the recorded
  `truth_wei` limitation are all written into them and into this SUMMARY.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-26*

## Self-Check: PASSED

- All 6 claimed files exist on disk (2 created, 3 modified, + this SUMMARY).
- Both commits (`63a3fa2`, `9ad94b2`) exist in history.
- `econometrics/src/Panel/Reconcile.hs` is BYTE-IDENTICAL across `63a3fa2~1..HEAD`
  (`git diff --quiet` clean) and `gateTolerance = 0.01` is present unmodified —
  the plan's central acceptance property.
- Every verdict figure quoted above (`GATE: PASS`, `MAX_REL_ERROR_SHORT:
  5.447268e-4`, `SIGNED_BIAS_SHORT: 3/5`, `SIGNED_BIAS_LONG: 0/0`,
  `LEGCOUNT_MISMATCHES: 0`, `GATE_TOLERANCE: 0.01`) was grepped back out of
  `reconcile.md` verbatim rather than transcribed from memory.
- `reconcile-errors.csv` carries exactly 61 data rows under the required header;
  `reconcile.md` carries exactly one line-anchored `GATE:` line and all 61
  per-spell rows; neither file contains a home-absolute path or a credential.
- Suite 176 examples / 0 failures.
