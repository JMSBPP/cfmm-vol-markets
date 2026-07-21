---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 01
subsystem: data
tags: [subgraph, panoptic, chunk, getTicks, panel-size, wave-0-blocker, hourly-epochs, haskell]

# Dependency graph
requires:
  - phase: 09-upsilon-econometric-estimation
    provides: "Panel.Subgraph (Endpoint/PoolAddr/Leg/Mint/Burn + fetchers), Panel.Build.dailyEpoch + assembleSpells, the 61-spell / 55-tokenId baseline, variance.csv epoch series"
provides:
  - "Panel.Subgraph.Chunk entity (Integer liquidity fields) + fetchChunks + legChunkKey (asymmetric getTicks map), proven exact against live Chunk records"
  - "The sample-size census CLI with a parameterized epoch width (EPOCH_HOURS)"
  - "A MEASURED width!=0 population: 68/68 legs carry width!=0 across all 61 spells / 55 tokenIds"
  - "A two-round STOP/GO census: daily grid STOP (median 1 epoch/pos) honored, then hourly re-scope GO (6764 joinable rows, median 10)"
  - "A frozen chunk fixture + per-leg chunk-legs.csv for downstream offline specs"
  - "The Wave-0 decision: PROCEED on the HOURLY-re-scoped design — later plans consume HOURLY epochs"
affects: [10-03, 10-04, 10-05, 10-06, 10-07, 10-08, 10-09, 10-10, 10-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Epoch width is a CLI parameter (EPOCH_HOURS), not a hardcoded 86400 divisor — the census re-runs at any grid without touching Panel.Build.dailyEpoch"
    - "getTicks range arithmetic (floor-down / ceil-up, asymmetric for odd width*tickSpacing) validated against the protocol's own Chunk records via a match-rate cross-check rather than trusted"
    - "Pre-committed necessary-condition floor (rows>=300 AND within-position median>=5) stated BEFORE measurement and NOT adjusted after — the anti-fishing discipline"

key-files:
  created:
    - "notes/structural-econometrcics/data/chunk-legs.csv"
    - "notes/structural-econometrcics/data/panel-size-audit.md"
    - "notes/structural-econometrcics/data/panel-size-audit-hourly.md"
    - "econometrics/test/fixtures/chunks-sample.json"
  modified:
    - "econometrics/src/Panel/Subgraph.hs"
    - "econometrics/app/Main.hs"
    - "econometrics/src/Panel/Build.hs"
    - "econometrics/test/Panel/BuildSpec.hs"

key-decisions:
  - "Daily-grid STOP verdict HONORED (median 1 epoch/position vs floor 5); the daily design is closed on its own pre-committed rule."
  - "User re-scoped to HOURLY epochs BEFORE any estimation, thresholds untouched; hourly re-measurement returns GO on both conditions."
  - "PROCEED to Wave 2 on the hourly design, accepting two recorded residual risks (55-cluster ceiling; noisier hourly sigma^2), adjudicated empirically by the unchanged <=1% reconciliation gate and <=6.2e-5 stopping rule."

patterns-established:
  - "Two-round census: a STOP under one grid is a real, honored outcome; a re-scope is a distinct design with its own measurement, not a goalpost move on the same design."

requirements-completed: [CTX-SIZE]

# Metrics
duration: ~24h wall (multi-session; Task 3 checkpoint awaited user)
completed: 2026-07-21
---

# Phase 10 Plan 01: Wave-0 Panel-Size Blocker Summary

**Two-round width!=0 census on the Base ETH/USDC Panoptic market: the daily-epoch grid returned a pre-committed STOP (median 1 epoch/position), the user re-scoped to HOURLY epochs before any estimation, and the hourly grid returned GO (6,764 joinable rows, median 10 epochs/position) — Phase 10 PROCEEDS on the hourly design.**

## Performance

- **Duration:** ~24h wall clock across sessions (Task 3 was a blocking decision checkpoint awaiting the user; active build/measure work was a few hours)
- **Completed:** 2026-07-21
- **Tasks:** 4 executable units (1, 2, 3a, 3b) + the resolved Task-3 checkpoint
- **Files modified:** 8

## Accomplishments

- **Converted the phase's load-bearing assumption into a measurement.** `PanopticPool._getPremia` skips every `width == 0` leg; RESEARCH had sampled only `width: 0` legs and feared the usable panel was no larger than Phase 9's 61 spells. The census measured the real number: **68 of 68 spell-legs carry `width != 0`** across all 61 spells / 55 tokenIds. The `width==0` trap does NOT bind on this market's accrual population.
- **Built and validated the `Chunk` entity + `getTicks` map.** `Panel.Subgraph.Chunk` (with `Integer` liquidity fields, never `Double` — BigInt reaches 10^20+) and `legChunkKey` (asymmetric floor-down/ceil-up range arithmetic) reproduce the protocol's own `Chunk` range records EXACTLY: `GETTICKS_MATCH_RATE = 1.0` on all 68 legs.
- **Ran the STOP/GO census twice under a parameterized epoch width.** Daily grid: STOP (within-position median = 1 epoch, below the floor of 5). Hourly grid (after the user re-scope): GO — `JOINABLE_ROWS = 6764`, `WITHIN_POSITION_EPOCHS_MEDIAN = 10`, `sigma^2` estimable in 2832/2832 hours, `GAIN_FACTOR ~= 111x`.
- **Recorded the final PROCEED decision** with its full trail and the two residual risks the user explicitly accepted.

## Task Commits

Each task was committed atomically:

1. **Task 1: Chunk/Leg census queries + sample-size CLI** - `efbac82` (feat)
2. **Task 2: run the Wave-0 census (daily) — RECOMMENDATION: STOP** - `d6c2a3c` (feat)
3. **Task 3a: parameterize the census epoch width; add sigma^2 estimability** - `63270d4` (feat)
4. **Task 3b: honor the daily STOP; record the hourly re-scope (GO)** - `a02df36` (docs)
5. **Task 3 (final): record FINAL DECISION — PROCEED (hourly design)** - `7dcf998` (docs)

**Plan metadata:** see the docs commit closing this plan (SUMMARY + STATE + ROADMAP).

## Files Created/Modified

- `econometrics/src/Panel/Subgraph.hs` - Added `Chunk` entity (Integer liquidity), `fetchChunks`, `parseChunks`, `legChunkKey` (asymmetric getTicks).
- `econometrics/app/Main.hs` - Added the `sample-size` subcommand and `runSampleSize` (census, chunk join, epoch-width parameter, audit emission).
- `econometrics/src/Panel/Build.hs` - Epoch-width parameterization support alongside the untouched `dailyEpoch`.
- `econometrics/test/Panel/BuildSpec.hs` - Coverage for the parameterized epoch grid.
- `econometrics/test/fixtures/chunks-sample.json` - Frozen `chunks` response for offline getTicks specs in 10-04.
- `notes/structural-econometrcics/data/chunk-legs.csv` - Per-(tokenId, leg) census: strike, width, tokenType, computed tick range, chunk match flag, position_size, mint/burn epochs.
- `notes/structural-econometrcics/data/panel-size-audit.md` - The daily-grid audit (RECOMMENDATION: STOP).
- `notes/structural-econometrcics/data/panel-size-audit-hourly.md` - The hourly-grid audit (RECOMMENDATION: GO) + the appended `## FINAL DECISION: PROCEED (hourly design)`.

## The Census Numbers (hourly, the design chosen)

| metric | value |
|---|---|
| `TOTAL_LEGS` / `WIDTH_NONZERO_LEGS` | 68 / 68 |
| `WIDTH_NONZERO_TOKENIDS` (= `USABLE_TOKENID_COUNT`, the CLUSTER count) | 55 |
| `DISTINCT_CHUNKS` | 52 |
| `GETTICKS_MATCH_RATE` | 1.000000 |
| `COVERED_EPOCHS_HOURLY` / `ESTIMABLE_SIGMA2_EPOCHS_HOURLY` | 2832 / 2832 |
| `JOINABLE_ROWS_HOURLY` (= `ACHIEVABLE_PANEL_ROWS`) | 6764 |
| `WITHIN_POSITION_EPOCHS_MEDIAN_HOURLY` | 10 |
| `SWAPS_PER_EPOCH_MEDIAN_HOURLY` | 177 |
| `PHASE9_BASELINE_ROWS` / `GAIN_FACTOR` | 61 / ~110.9x |

Pre-committed rule (GO iff rows >= 300 AND within-position median >= 5): both PASS.

## Wave-0 Verdict

**Selected option: `proceed` (PROCEED — continue to Wave 2), on the HOURLY-re-scoped design.**

Full decision trail (recorded verbatim in substance in `panel-size-audit-hourly.md`):

1. **Daily design STOP — HONORED.** The pre-committed rule returned STOP on the daily grid (median 1 epoch/position vs floor 5). Applied as written, not adjusted after the number was seen. Daily design closed.
2. **User re-scoped to HOURLY epochs BEFORE any estimation.** Epoch width changed daily -> hourly (`EPOCH_HOURS = 1`); the GO/STOP thresholds themselves were left untouched.
3. **Hourly re-measurement — GO on both conditions,** scored on the stricter `JOINABLE_ROWS` reading: 6,764 rows; median 10 epochs/position; `sigma^2` estimable in 2832/2832 hours; cluster count unchanged at 55.
4. **User selected `proceed`** to Wave 2 (plans 10-02 .. 10-11), accepting two recorded residual risks:
   - (a) the cluster count is unchanged at 55, which bounds clustered precision regardless of how many rows the hourly grid adds;
   - (b) hourly `sigma^2` is noisier (~177 vs ~5209 increments/window), so EIV attenuation worsens and the even-swap instrument thins (~88 increments).

   Both are adjudicated empirically by the UNCHANGED ≤1% reconciliation gate and the UNCHANGED result-blind stopping rule (clustered CI half-width ≤ 6.2e-5) in plan 10-10. Neither control was relaxed to accommodate the re-scope.

## Reusable Findings (consumed downstream)

1. **`width == 0` selection identity.** On this market the accrual population is 100% `width != 0` (68/68). The `_getPremia` skip does not thin the usable panel — a leg being in an accrual spell already implies it accrued premium and therefore carried nonzero width. Downstream plans need not re-filter on width.
2. **`getTicks` is exact.** `legChunkKey`'s asymmetric range arithmetic reproduces the protocol's `Chunk` ranges on every leg (`GETTICKS_MATCH_RATE = 1.0`). 10-04 can promote this map to `Panoptic.Chunk` as canonical and test it against `chunks-sample.json` with confidence it is correct, not merely plausible.

## DOWNSTREAM CONSEQUENCE — the panel and variance layers are now HOURLY

The chosen design changes the epoch grid for every plan after this one. An **hourly epoch function exists alongside `Panel.Build.dailyEpoch` (which is untouched)**:

- **10-03 (epoch<->block index):** must map HOURLY epoch boundaries to blocks, not daily. ~2832 hourly epochs replace the 119 daily epochs.
- **10-04 (read schedule):** **FLAG — 10-04 must re-estimate its bulk-read call volume against the hourly grid.** Hourly boundaries mean ~2832 epochs, so the bulk-read call count grows accordingly and will very likely EXCEED the RESEARCH 8k-15k figure that was sized against the daily grid. Re-derive the call count before committing the read schedule.
- **10-05 / 10-06 (read schedule / execution):** consume hourly boundaries -> ~2832 epochs; sizing, batching, and rate-limit budgets scale with the hourly count.
- **10-07 / 10-08 (reconciliation):** UNCHANGED — reconciliation remains spell-level, and the ≤1% wei gate is untouched.
- **10-09 (panel join):** joins on HOURLY epochs; the panel is now position-hour, not position-day.
- **10-10 (stopping rule):** UNCHANGED — result-blind clustered CI half-width ≤ 6.2e-5 remains the sole arbiter; it was NOT relaxed for the hourly re-scope.

## Deviations from Plan

The daily-grid census returned STOP under the plan's pre-committed rule (plan text explicitly treats STOP as a legitimate, publishable outcome). Rather than closing the phase, the user exercised the checkpoint to re-scope the epoch width to hourly BEFORE any estimation — a genuine change of experimental design, not a post-hoc threshold adjustment. This was handled through the Task-3 decision checkpoint (its intended mechanism), so it is a checkpoint resolution, not an auto-fix deviation. The GO/STOP thresholds themselves were never moved.

## Issues Encountered

- The daily grid failed condition (b) of the pre-committed floor (within-position variation): with mint->burn spells averaged to one daily epoch each, the median position spanned only 1 usable epoch. Resolved not by relaxing the rule but by the user re-scoping to a finer (hourly) grid, which restores genuine within-position variation in `sigma^2` — the qualitative identification gain spec 4.4 actually intends.

## Next Phase Readiness

- Wave 2 (10-02 .. 10-11) is cleared to execute on the HOURLY design.
- **Action item for 10-04:** re-estimate bulk-read call volume against ~2832 hourly epochs vs the RESEARCH 8k-15k daily-sized figure before locking the read schedule.
- Residual risks (55-cluster precision ceiling; noisier hourly `sigma^2` / thinner even-swap instrument) are carried forward and will be adjudicated empirically at the 10-07/10-08 reconciliation gate and the 10-10 stopping rule.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-21*

## Self-Check: PASSED

- All 7 claimed files exist on disk.
- All 5 claimed commits (efbac82, d6c2a3c, 63270d4, a02df36, 7dcf998) exist.
- No home-absolute paths or keys in the SUMMARY.
