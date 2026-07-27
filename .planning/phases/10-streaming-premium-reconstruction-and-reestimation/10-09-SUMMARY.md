---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 09
subsystem: panel-construction
tags: [panel, position-epoch, hourly, variance, eiv-instrument, telescoping, provenance, haskell, cli]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 01
    provides: "the HOURLY re-scope (EPOCH_HOURS = 1), the 6,764-row projection, 55 clusters, chunk-legs.csv"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 06
    provides: "premium-accumulators.csv — 8,910 SFPM X64 accumulator readings incl. exact mint/burn endpoint rows"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 08
    provides: "GATE: PASS at short-stratum median 0.0 + reconcile-errors.csv (61 per-spell recon_wei / truth_wei)"
provides:
  - "notes/structural-econometrcics/data/panel-epoch.csv — THE estimation-ready position-hour panel: 6,760 rows, 55 tokenIds, 1,887 hourly epochs, 39-line lineage banner, sigma2 + instrument joined in"
  - "notes/structural-econometrcics/data/variance-hourly.csv — sigma2_t, the disjoint even-swap EIV instrument, i_t and n_swaps at 2,833 hourly epochs, rebuilt from the cached 632,315-tick series with NO refetch"
  - "notes/structural-econometrcics/data/burn-truth.csv — the 61-spell OptionBurn ground truth frozen as a committed INPUT (closes 10-08's recorded truth_wei limitation)"
  - "Panel.Build.assembleEpochPanel / EpochObs / writeEpochPanelCsv — the spec section-1 unit with an explicitly-returned unmatched-epoch list"
  - "Panoptic.Premium.decomposePremium — the EXACT per-interval decomposition (sums to the endpoint premium for ANY leg liquidity)"
  - "Panoptic.Premium.premiumObsChain / buildSpellPremiumObs — accrual-interval epoch tagging + the pool-wide window restriction"
  - "Panel.Variance.*At (byEpochAt / realizedVarianceAt / instrumentVarianceAt / meanPoolTickAt / swapCountsAt / writeVarianceCsvAt / fillQuietEpochs)"
  - "Panel.Epoch — the leaf module that owns the epoch grid, breaking a real import cycle"
  - "econometrics CLI: epoch-panel, burn-truth, variance --epoch-hours/--patch"
  - "THE RESULT: UNMATCHED_EPOCHS 0, TELESCOPE_MISMATCHES 0, PANEL_SUM_MISMATCHES 0, MULTI_EPOCH_TOKENIDS 52/55, GAIN_FACTOR 110.8x"
affects: [10-10, 10-11, 10-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A decomposition is proved EXACT by construction rather than checked to a tolerance: increments are differences of the CUMULATIVE premium, so they telescope for any liquidity instead of losing a wei per interval to flooring."
    - "The failure mode is RETURNED, not filtered. assembleEpochPanel hands back the unmatched-epoch list and the CLI exits non-zero on it — a silent join drop is what made the 09-05 40587-offset bug look like a small clean panel."
    - "A row-count shortfall against a prior projection is reconciled term by term (6764 +3 -1 -6 = 6760) rather than waved at."
    - "A validated quantity is frozen as an INPUT, not left to exist only inside the artifact it validates (burn-truth.csv closes 10-08's recorded truth_wei limitation)."
    - "An import cycle is broken by moving the shared definition to a leaf, never by forking it — forking the epoch index is exactly what 09-05 paid for."
    - "A zero-swap hour is distinguished from an unobserved hour by re-fetching the block range and showing the cache reproduces byte-identically; only then is sigma^2 = 0 a measurement."

key-files:
  created:
    - "econometrics/src/Panel/Epoch.hs"
    - "notes/structural-econometrcics/data/panel-epoch.csv"
    - "notes/structural-econometrcics/data/variance-hourly.csv"
    - "notes/structural-econometrcics/data/burn-truth.csv"
  modified:
    - "econometrics/src/Panel/Build.hs"
    - "econometrics/src/Panel/Variance.hs"
    - "econometrics/src/Panoptic/Premium.hs"
    - "econometrics/src/Panoptic/Chunk.hs"
    - "econometrics/src/Chain/BlockIndex.hs"
    - "econometrics/app/Main.hs"
    - "econometrics/test/Panel/BuildSpec.hs"
    - "econometrics/test/Panel/VarianceSpec.hs"
    - "econometrics/test/Panoptic/PremiumSpec.hs"
    - "notes/structural-econometrcics/data/DATA-SOURCES.md"

key-decisions:
  - "The panel is built on the HOURLY grid, not the plan text's daily one. The plan was written against the original design; 10-01's re-scope governs where they conflict, and every artifact, epoch rule and banner in this plan says HOURLY."
  - "telescope was REPLACED by decomposePremium for the panel. Per-interval flooring undershoots the endpoint total by up to N-1 wei whenever the leg liquidity is not a multiple of 2^64 — which the real liquidities are not. Sub-wei is numerically trivial and methodologically fatal: the panel's licence is that it DECOMPOSES the gate-validated total, so it must sum back exactly. It does, for all 55 tokenIds."
  - "The epoch tag was CORRECTED from 10-05's ending-epoch convention to the accrual interval's STARTING epoch. Block-index epoch e is the START of hour e, so the boundary(e)->boundary(e+1) delta is hour e's premium and must meet hour e's sigma^2. buildPremiumObs is left byte-identical; the correction lives in the new premiumObsChain."
  - "epoch-panel is a SEPARATE subcommand, not a flag on build-panel as the plan specified. build-panel rewrites panel.csv — THE frozen 61-spell gate population that 10-08's verdict and this plan's own telescoping cross-check are both defined against — and the subgraph has advanced since the gate (1602->1603 mints). Extending it would have moved the population under the check meant to validate the panel."
  - "Panel.Epoch was created as a leaf module. Panel.Build -> Panoptic.Chunk -> Chain.BlockIndex -> Panel.Build is a real cycle that exists only to borrow the epoch grid; the alternative to moving the grid was forking it, which is the 09-05 trap. dailyEpoch stays byte-identical where 09-04 put it."
  - "The single zero-swap hour (495112) is carried as a MEASURED row, not dropped and not interpolated: sigma^2 = 0 (no swap, no increment, no movement), pool tick carried forward (a state variable), n_swaps = 0 so its 3 panel rows stay isolable. Justified by a re-fetch of that block range reproducing the tick cache BYTE-IDENTICALLY."

patterns-established:
  - "An artifact that a later plan will estimate on carries its own join validation (UNMATCHED_EPOCHS, TELESCOPE_MISMATCHES) frozen in its banner, so the property is a fact about the committed file rather than about a re-run."

requirements-completed: [CTX-PANEL2]

# Metrics
duration: ~3h active across two interrupted sessions
completed: 2026-07-27
---

# Phase 10 Plan 09: The Restored Position-Epoch Panel Summary

**The spec's section-1 unit of observation is back on disk: 6,760 position-hour rows over 55 tokenIds and 1,887 hourly epochs, joined to a freshly-rebuilt hourly variance series with ZERO unmatched epochs, and every tokenId's rows sum back to its gate-validated `recon_wei` EXACTLY in Integer wei — so 10-08's `GATE: PASS` transfers to the panel rather than being asserted of it — with within-position variation restored on 52 of 55 positions (median 10 hours, max 1,176) at a 110.8x row gain over Phase 9's 61 spells.**

## Performance

- **Duration:** ~3h active work, spread across two sessions (one killed by a process exit, one by a session limit; no work was lost — the working tree carried forward and every task committed atomically)
- **Tasks:** 5 executable units, each committed separately
- **Files:** 14 (4 created, 10 modified)
- **Suite:** **176 → 215 examples, 0 failures** (39 new specs)

## Task Commits

1. **Hourly σ̂² / EIV instrument at a parameterized epoch width** — `7aaff51` (feat)
2. **Position-epoch panel assembler with a zero-unmatched variance join** — `a2c1f04` (feat)
3. **Build the live hourly panel** — `4645257` (feat)
4. **Freeze the 61-spell OptionBurn ground truth as a committed INPUT** — `56034ad` (feat)
5. **DATA-SOURCES section 6** — `4afad77` (docs)

## THE NUMBERS

```
PANEL_ROWS: 6760                    UNMATCHED_EPOCHS: 0
PANEL_TOKENIDS: 55                  TELESCOPE_MISMATCHES: 0
PANEL_EPOCHS: 1887                  PANEL_SUM_MISMATCHES: 0
SPELL_EPOCH_ROWS: 6766              LEG_READ_HOLES: 0
MULTI_EPOCH_TOKENIDS: 52            FLAGGED_ROWS: 6760
WITHIN_POSITION_EPOCHS_MEDIAN: 10   QUIET_EPOCH_ROWS: 3
WITHIN_POSITION_EPOCHS_MAX: 1176    PHASE9_BASELINE_ROWS: 61
TOP10_TOKENID_ROW_SHARE: 0.841272   GAIN_FACTOR: 110.819672
```

The CLI exits non-zero on any unmatched epoch or telescoping mismatch. It did not.

### The row count, reconciled term by term

The 10-01 census projected `ACHIEVABLE_PANEL_ROWS = 6764`. The panel has 6,760.
The 4-row difference is **measured, not estimated**:

```
6764   census (per SPELL, over hours with >= 2 swaps)
  +3   hour 495112 — excluded by the census as non-estimable, now carried as a
       measured quiet hour (3 spells span it)
  -1   hour 492875 — the tick cache's partial leading hour, which has no boundary
       block in the 10-03 index: one spell mints at block 43,781,657, before the
       index's first boundary 43,782,127 (verified: 2 accumulator rows tagged
       epoch 492876 by the epochOfBlock fallback carry that mint block)
= 6766 SPELL_EPOCH_ROWS  (the census-comparable count, emitted by the CLI)
  -6   (tokenId, epoch) collisions — 61 spells over 55 tokenIds, and six of the
       duplicate-tokenId spell pairs share an hour
= 6760 PANEL_ROWS
```

## Accomplishments

- **Restored the unit of observation Phase 9 could not construct.** One row per
  `(tokenId, hourly epoch)` with `π_it` in Integer wei, the strike tick, the
  epoch's mean pool tick, `|i_K − i_t|`, σ̂²_t, the EIV instrument and the swap
  count behind it. 52 of 55 positions contribute more than one hour — the
  within-position regressor variation Phase 9 had *exactly zero* of.
- **Made the decomposition exact rather than close.** `telescope` floors each
  interval separately and undershoots the endpoint total by up to `N−1` wei
  whenever the leg liquidity is not a multiple of `2^64`. `decomposePremium`
  takes increments as differences of the *cumulative* premium, which telescopes
  identically for any liquidity. Result: all 55 tokenIds sum back to their
  gate-validated `recon_wei` **to the wei**.
- **Caught and fixed a one-hour misalignment before it reached the estimator.**
  10-05 tagged each accumulator delta with the *ending* reading's epoch. On the
  hourly grid that would have regressed hour `e`'s premium on hour `e+1`'s
  variance — the 09-05 40587-offset trap, one grid finer. `premiumObsChain` tags
  the accrual interval's *starting* epoch; `buildPremiumObs` is left byte-identical.
- **Rebuilt the variance side at hourly resolution with no refetch.** 2,833
  epochs from the cached 632,315-tick series; the daily `variance.csv` is
  byte-unchanged, and a spec pins `realizedVarianceAt 86400 == realizedVariance`
  so it stays reproducible.
- **Closed 10-08's recorded provenance gap.** `burn-truth.csv` freezes the ground
  truth as an *input*, with the unit determined by the gate's own classifier, the
  BigInt→Double→Integer round-trip verified exact (max 1.76e13, three orders below
  2^53), and `TRUTH_MISMATCHES: 0` against `reconcile-errors.csv`.

## What this does NOT establish

- **The row count is not the precision.** Standard errors are tokenId-clustered
  and the cluster count is **unchanged at 55**; 84% of the rows sit in ten
  positions, one of which carries 1,176. Adding hours to existing positions
  multiplies rows without multiplying clusters. A 110x row gain does not prejudge
  10-10's pre-committed CI half-width bar (≤ 6.2e-5), which remains the sole
  arbiter and may still not be met.
- **The gate validated MEASUREMENT, not identification.** This plan carries that
  validation onto the panel; it does not add to it.
- **Multi-leg positions carry one strike.** Premium is summed over legs within the
  hour (which is what the scalar `OptionBurn.premium0` ground truth also is), but
  `strike_tick` and `is_long` come from the position's first resolved leg — the
  same rule `assembleSpells` and the 10-08 gate stratum use. For the 7 two-leg
  spells that single strike approximates the position's moneyness. `leg_count` is
  carried in the artifact rather than dropped so the approximation is visible.
- **`FLAGGED_ROWS: 6760` is every row, and that is expected, not alarming.** All
  8,910 reads passed a real `atTick`, so every observation carries `Extrapolated`.
  The informative flag is `ChunkEmpty`, on **50** rows. No row carries `AccFrozen`.

## Deviations from Plan

### Auto-fixed / adapted

**1. [Rule 3 — Blocking] The plan's `assembleEpochPanel` location closed an import cycle**
- **Found during:** Task 1 (Task 2 here), first compile.
- **Issue:** The plan mandates `assembleEpochPanel` in `Panel.Build` and "do not
  create a new module". But `Panel.Build → Panoptic.Chunk → Chain.BlockIndex →
  Panel.Build` is a real cycle: the latter two import `Panel.Build` solely to
  borrow `Epoch` / `epochOfSeconds`. GHC rejects it.
- **Fix:** Moved the grid to a new **leaf** module `Panel.Epoch`; `Panel.Build`
  imports and re-exports the three names unchanged, so no consumer's import
  changed. The assembler still lives in `Panel.Build` exactly as required, and
  `dailyEpoch` is byte-identical where 09-04 put it (the plan's
  `git diff | grep -c 'dailyEpoch ::'` check returns 0).
- **Why not fork the grid:** that is precisely the 09-05 40587-offset trap.
- **Commit:** `a2c1f04`.

**2. [Rule 1 — Bug] The plan's `TELESCOPE_MISMATCHES: 0` was unreachable via `telescope`**
- **Found during:** Task 2 design.
- **Issue:** The plan asserts the interior epoch reads and the endpoint reads must
  agree "exactly", treating any difference as a bug. With per-interval flooring
  they cannot: `Σ floor(Δ_k·L/2^64) < floor((ΣΔ_k)·L/2^64)` by up to `N−1` wei
  for any `L` that is not a multiple of `2^64`, and the real leg liquidities
  (e.g. 761,939,137,362) are not.
- **Fix:** `Panoptic.Premium.decomposePremium` — increments as differences of the
  cumulative premium, exact for any `L`. Six specs, including one that
  demonstrates `telescope` undershooting on a real liquidity.
- **Commit:** `a2c1f04`.

**3. [Rule 1 — Bug] 10-05's ending-epoch tag is off by one hour on this grid**
- **Found during:** Task 2 design. See "Accomplishments" above.
- **Fix:** `premiumObsChain` tags the accrual interval's starting epoch;
  `buildPremiumObs` untouched and still pinned by its own specs.
- **Commit:** `a2c1f04`.

**4. [Rule 3 — Blocking] `epoch-panel` is a separate subcommand, not a `build-panel` flag**
- **Issue:** The plan extends `build-panel`, which rewrites `panel.csv` — THE
  frozen 61-spell gate population. The subgraph has advanced since the gate
  (10-08 recorded 1602→1603 mints), so running it would move the population under
  the telescoping check that is supposed to validate the panel.
- **Fix:** A separate `epoch-panel` subcommand reading `panel.csv` as input.
  `build-panel` is untouched. Documented at the option type.
- **Commit:** `4645257`.

**5. [Rule 2 — Missing critical functionality] The variance side did not exist at hourly resolution**
- **Issue:** The plan says "`Panel.Variance` is untouched" and joins to
  `variance.csv`. That file is **daily** (119 epochs, keys ≈ 20536) while the
  accumulators are tagged **hourly** (keys ≈ 492876). Joining them would have
  matched nothing — or, worse, silently matched a handful.
- **Fix:** Width-parameterized estimators (`*At`), a separate hourly artifact at a
  new path, and `variance.csv` byte-unchanged. This is the 10-01 re-scope's
  documented downstream consequence, which the plan text (written for the
  original design) predates.
- **Commit:** `7aaff51`.

**6. [Rule 2 — Missing critical functionality] One hour in the window carries no swap**
- **Issue:** Epoch 495112 has zero swaps between neighbours carrying 700+, so it
  had no variance row and would have forced `UNMATCHED_EPOCHS > 0`.
- **Investigation before treatment:** re-fetched blocks 47,805,127–47,814,126 from
  the public Base RPC. The result reproduced the cached tick series
  **byte-identically** (`git diff` on the 632,315-row cache is empty). The hour
  was still on chain; the pull did not miss it.
- **Fix:** `fillQuietEpochs` — σ̂² = 0 (no swap ⇒ no increment ⇒ no movement, a
  *measured* zero), pool tick carried forward (a state variable, not a flow),
  `n_swaps = 0` so the 3 affected panel rows stay isolable downstream. Six specs.
- **Honest limitation:** the confirming re-fetch used the **same** public endpoint
  as the original pull, so it establishes reproducibility rather than
  provider-independence. A second-provider check was attempted and not completed.
- **Commit:** `4645257`.

### Added beyond the plan (user-adopted)

**7. `burn-truth.csv` — the ground truth frozen as an input** (`56034ad`). Adopted
from 10-08's carry-forward. See "Accomplishments".

### Not done (correctly)

- **`Panel.Build.dailyEpoch` was not touched.** The plan's own diff check passes.
- **`Panel/Reconcile.hs` was not touched.** 10-08 established "is the module
  byte-identical?" as a one-line audit of whether the gate tolerance moved. The
  panel's endpoint-preferring lookup mirrors `Panel.Reconcile.lookupAt` in a
  comment rather than by exporting it, so that property survives this plan.
- **`assembleSpells` / `writePanelCsv` / `panel.csv` retained.** The spell path is
  the independent check on the thing that replaced it.
- **`variance.csv` (daily) was not regenerated.** The block index and the 10-08
  gate lineage both reference it.
- **No rows were dropped to make a number look better.** The unmatched list is
  returned and the CLI fails on it; the quiet-hour rows are carried and labelled.

## Authentication Gates

None. Both live pulls (the 61-burn ground-truth freeze and the bounded 9,000-block
tick re-fetch) used keyless public endpoints — the Goldsky Base subgraph and
`https://mainnet.base.org`. No `GRAPH_API_KEY` was set or needed. No credential
appears in any artifact; all four were checked for home-absolute paths.

## Issues Encountered

- **Two session interruptions** (a process exit and a session limit) landed
  mid-plan. Nothing was lost: the working tree survived both and every task was
  already committed atomically or was re-derived from the diff on resume.
- **A `VarianceRow` / `VarRow` field-name collision** in `app/Main.hs` (the
  estimator's local record already used `vrSigma2`). Resolved by naming the
  library record's accessors `var*`.

## Next Phase Readiness

- **10-10 (re-estimation + the stopping rule):** `panel-epoch.csv` is
  estimation-ready — `premium_eth` is the LHS, `moneyness` and `sigma2` are the
  regressors, `sigma2_instrument` is the EIV instrument, `token_id` is the cluster
  and `account` the coarser one. Two things to carry in: (a) the 3 rows with
  `n_swaps = 0` are droppable with one predicate if the estimator prefers; (b) the
  `TOP10_TOKENID_ROW_SHARE` of 0.841 and the 55-cluster ceiling mean the clustered
  CI is not going to contract like `1/sqrt(6760)`. The ≤ 6.2e-5 bar is unchanged
  and unrelaxed.
- **10-11 (audit):** the lineage chain is now closed end to end —
  `burn-truth.csv` (input) → `premium-accumulators.csv` → `reconcile.md` /
  `reconcile-errors.csv` (gate) → `variance-hourly.csv` + `panel-epoch.csv`
  (panel), with each artifact carrying its own banner and every count in this
  SUMMARY emitted by the CLI rather than transcribed.
- **Recommended before 10-10 executes:** the user's standing anti-fabrication
  review gate. The specific claims worth attacking are `TELESCOPE_MISMATCHES: 0`
  (recompute the per-tokenId sums from `panel-epoch.csv` against
  `reconcile-errors.csv` independently), the 6764→6760 reconciliation, and the
  quiet-hour treatment at epoch 495112.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-27*

## Self-Check: PASSED

Every headline figure below was **recomputed from the committed artifacts in
exact integer arithmetic, in Python — a different language from the one that
produced them** — rather than transcribed from the CLI's own stdout.

- All 10 claimed files exist on disk (4 created, 6 of the 10 modified sampled).
- All 5 claimed commits exist in history (`7aaff51`, `a2c1f04`, `4645257`,
  `56034ad`, `4afad77`).
- **`TELESCOPE_MISMATCHES: 0`** — per-tokenId `Σ premium_wei` from
  `panel-epoch.csv` equals `Σ recon_wei` from `reconcile-errors.csv` for **all 55
  tokenIds**, in exact `Integer` wei.
- **`TRUTH_MISMATCHES: 0`** — per-tokenId `Σ premium0_wei` from the frozen
  `burn-truth.csv` equals `Σ truth_wei` from `reconcile-errors.csv` for all 55.
- **`UNMATCHED_EPOCHS: 0`** — every one of the 1,887 panel epochs is present in
  `variance-hourly.csv`.
- Row counts re-derived from the files: panel **6,760** rows / **55** tokenIds /
  **1,887** epochs; `burn-truth.csv` **61** rows; `variance-hourly.csv` **2,833**
  rows. `MULTI_EPOCH_TOKENIDS` **52**, within-position median **10**, max
  **1,176**, top-10 row share **0.841272**, `GAIN_FACTOR` **110.819672**.
- **Join integrity re-checked, not assumed:** every row's `sigma2`,
  `sigma2_instrument` and `n_swaps` equal `variance-hourly.csv`'s values for that
  row's epoch (0 drift over 6,760 rows), and every row's `moneyness` equals
  `|strike_tick − pool_tick|` (0 mismatches).
- Flag census re-derived: **6,710** `Extrapolated`, **50** `ChunkEmpty;Extrapolated`,
  **0** `AccFrozen`. `QUIET_EPOCH_ROWS` **3**.
- **Byte-stability properties held:** `git diff 16462c1..HEAD` is empty for
  `Panel/Reconcile.hs` (10-08's one-line "did the tolerance move?" audit),
  `variance.csv`, `panel.csv`, **and** `swap-ticks-base-v4-full.csv` — the last
  being the evidence that the bounded re-fetch of blocks 47,805,127–47,814,126
  reproduced the cached tick series exactly.
- The plan's own diff guard passes:
  `git diff -- econometrics/src/Panel/Build.hs | grep -c 'dailyEpoch ::'` is **0**.
- No home-absolute path and no credential in any of the four artifacts.
- Suite **215 examples, 0 failures**.
