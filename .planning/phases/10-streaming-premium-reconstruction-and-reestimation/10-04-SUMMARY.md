---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 04
subsystem: chunk-geometry
tags: [panoptic, chunk, getTicks, tickmath, liquidity, read-schedule, dedup, hourly, haskell, offline-tests]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 01
    provides: "Panel.Subgraph.Chunk/Leg + legChunkKey (asymmetric getTicks, match rate 1.0) + the frozen chunks-sample.json fixture + chunk-legs.csv census + the positionSize-as-Double trap"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 03
    provides: "Chain.BlockIndex.EpochBlock + epoch-blocks.csv (2832 hourly boundaries) + the measured 7.24 calls/s throughput"
provides:
  - "Panoptic.Chunk: ChunkKey, getTicks/getRangesFromStrike (floor-down/ceil-up, delegating to the single arithmetic source Panel.Subgraph.legChunkKey), crossCheckChunks (subgraph=authority), getSqrtRatioAtTick (exact TickMath X96 Integer), getLiquidityForAmount0/1, legLiquidity (asset-selected, Integer), LegChunk + resolveLegChunks (width==0 dropped, index preserved)"
  - "Panoptic.Chunk read schedule: ReadRow, readScheduleRaw (full tokenId/leg fan-out), buildReadSchedule (deduplicated on the pool-wide (chunkKey, block, isLong, atTick)), storedValueTick = 8388607"
  - "Panel.Subgraph.Leg gains legAsset (the token0/token1 selector); legsQuery now selects asset"
affects: [10-05, 10-06, 10-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single arithmetic source of truth across an import boundary: Panoptic.Chunk.getTicks/getRangesFromStrike delegate to Panel.Subgraph.legChunkKey (the leaf module) and re-export it, so the tested public geometry can never diverge from the census-validated implementation — a literal upward move would form an import cycle"
    - "Exact on-chain arithmetic in Integer only: TickMath.getSqrtRatioAtTick reproduced bit-for-bit (2^96 at tick 0, monotone) and LiquidityAmounts done with floor division, never Double (RESEARCH: no Double upstream of the panel)"
    - "Pool-wide dedup: reads keyed on (chunkKey, block, isLong, atTick) collapse co-chunk positions to one call; the un-deduplicated fan-out is kept (readScheduleRaw) for later per-position attribution via legLiquidity"

key-files:
  created:
    - "econometrics/src/Panoptic/Chunk.hs"
    - "econometrics/test/Panoptic/ChunkSpec.hs"
  modified:
    - "econometrics/src/Panel/Subgraph.hs"
    - "econometrics/package.yaml"
    - "econometrics/test/Spec.hs"

key-decisions:
  - "getTicks/getRangesFromStrike DELEGATE to Panel.Subgraph.legChunkKey rather than re-implement the floor/ceil arithmetic — the plan's 'move canonical impl into Panoptic.Chunk' is impossible without an import cycle (Panoptic.Chunk depends on Panel.Subgraph for Leg/Chunk), so the base arithmetic stays in the leaf module and Panoptic.Chunk re-exports it. Same single-source guarantee, no duplication, no divergence risk."
  - "Leg gained legAsset (token side selector) rather than guessing the token side from tokenType; parsed optionally with a tokenType default so the frozen asset-less legs fixture still decodes."
  - "legLiquidity is asserted strictly positive only for SUBSTANTIAL positionSizes; a positionSize==1 leg selected on token0 over a 100-tick chunk floors to L==0 — this is Panoptic's exact getLiquidityChunk floor division, tested as a non-negative degenerate case, not forced positive."

requirements-completed: [CTX-PANEL2]

# Metrics
duration: ~9m
completed: 2026-07-21
---

# Phase 10 Plan 04: Chunk Geometry + Read Schedule Summary

**`Panoptic.Chunk` turns every subgraph `Leg` into its exact `(tokenType, tickLower, tickUpper)` chunk identity and `Integer` liquidity multiplier, reproducing all 126 frozen `Chunk` records' tick ranges with zero mismatches, and emits a deduplicated, endpoint-aware `getAccountPremium` read schedule keyed on the pool-wide chunk — all proven offline (suite 102 → 117, +15 examples).**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-07-21T16:49:37Z
- **Tasks:** 2 (both TDD/offline)
- **Files:** 5 (2 created, 3 modified)

## Accomplishments

- **Fixed the geometry before any accumulator is read.** `getTicks` mirrors `PanopticMath.getTicks` with the floor-down / ceil-up asymmetry preserved for odd `width·tickSpacing`, and `crossCheckChunks` validates it against the subgraph's OWN `Chunk` records — the authority — on the frozen `chunks-sample.json`: **126/126 records match, mismatch list empty** (an empty fixture fails the test, never vacuously passes). The formula is the cross-check, not the authority, exactly as RESEARCH requires.
- **Kept the tick arithmetic single-sourced across a module boundary.** `getTicks` / `getRangesFromStrike` delegate to `Panel.Subgraph.legChunkKey` (the census-validated implementation, match rate 1.0 at 10-01) and re-export it, so the tested public geometry cannot drift from the validated one. A literal move would have formed an import cycle; delegation gives the same guarantee with no duplicated arithmetic.
- **Computed liquidity in `Integer` end-to-end.** `getSqrtRatioAtTick` is the exact Uniswap `TickMath` X96 bit-decomposition table (`2^96` at tick 0, strictly monotone across the probe tick list) — no `Double` 53-bit approximation of a `2^96` value. `getLiquidityForAmount0/1` use floor division on `Integer` as `FullMath.mulDiv`, and `legLiquidity` selects the token side from the new `Leg.asset` field, never guessing. **No `Double` appears in any signature in the module.**
- **Dropped `width == 0` legs at one explicit, greppable point.** `resolveLegChunks` filters `legWidth == 0` (matching `PanopticPool._getPremia` L2250) while retaining the original leg index for multi-leg reconciliation (RESEARCH Pitfall 7).
- **Emitted the deduplicated, endpoint-aware read schedule.** `buildReadSchedule` produces interior epoch-boundary reads for every epoch whose boundary block lies in a spell's `[meBlock, beBlock]` (with `atTick` from the per-epoch tick index for smooth extrapolation), PLUS exact-block mint/burn endpoint rows (`rrEndpoint = Just "mint"|"burn"`) so the gate reads accumulators at the spell endpoints, not the nearest epoch boundary. Reads are deduplicated on the pool-wide `(chunkKey, block, isLong, atTick)` — proven by a synthetic three-spell case where two chunk-sharing spells collapse from 10 raw rows to 5.

## Panoptic.Chunk Public API

```
-- Chunk identity
ChunkKey(..)               -- ckTokenType, ckTickLower, ckTickUpper (Ord)
legChunkKey                -- re-export of the canonical tuple geometry

-- Tick range
getRangesFromStrike :: Int -> Int -> (Int, Int)          -- (rangeDown, rangeUp)
getTicks            :: Int -> Int -> Int -> (Int, Int)   -- (tickLower, tickUpper)
crossCheckChunks    :: [Chunk] -> Int -> ([Chunk],[Chunk])  -- (matching, mismatching)

-- Liquidity (Integer only)
getSqrtRatioAtTick  :: Int -> Integer                    -- X96
getLiquidityForAmount0, getLiquidityForAmount1 :: Int -> Int -> Integer -> Integer
legLiquidity        :: Leg -> Integer -> Int -> Integer  -- positionSize, tickSpacing

-- Leg -> chunk resolution
LegChunk(..)               -- lcLegIndex, lcChunkKey, lcIsLong, lcLiquidity, lcStrike, lcWidth
resolveLegChunks    :: Int -> Integer -> [Leg] -> [LegChunk]

-- Read schedule
ReadRow(..)                -- rrTokenId, rrLegIndex, rrChunkKey, rrIsLong, rrEpoch, rrBlock, rrAtTick, rrEndpoint
storedValueTick     :: Int                               -- 8388607 = type(int24).max
readScheduleRaw     :: Map Epoch EpochBlock -> Map Epoch Int -> [(Text,MintEvent,BurnEvent,[LegChunk])] -> [ReadRow]
buildReadSchedule   :: (same signature)                  -- deduplicated
```

## getTicks Match Rate & Read-Count Projection

| metric | value |
|---|---|
| `GETTICKS_MATCH_RATE` (frozen `chunks-sample.json`) | **1.000000** (126/126, mismatch list empty) |
| `getSqrtRatioAtTick 0` | `2^96` exactly |
| `DISTINCT_READS` / `SCHEDULE_ROWS` (this plan) | not materialised — 10-04 is offline machinery + spec |

**DISTINCT_READS is computed by the CLI in 10-06, against real spells joined to `epoch-blocks.csv`; it MUST be budgeted against 10-03's HOURLY envelope (~30k–60k calls, ~70–140 min at the measured 7.24 calls/s), NOT the RESEARCH 8k–15k daily figure.** The pool-wide dedup on `(chunkKey, block, isLong, atTick)` is the primary lever bringing the raw per-position fan-out down: on this market the census found only **52 distinct chunks** over 55 tokenIds, so per epoch the distinct-chunk read count is bounded by the live chunks in that hour, not by the position count. 10-06 prints `DISTINCT_READS`/`SCHEDULE_ROWS` and applies its go/no-go against the measured hourly rate.

## Deviations from Plan

### Auto-fixed / adapted (Rule 3 — blocking structural constraint)

**1. [Rule 3 - Blocking] `legChunkKey` stays in `Panel.Subgraph`; `Panoptic.Chunk` delegates + re-exports**
- **Found during:** Task 1.
- **Issue:** The plan says "move the canonical implementation of `legChunkKey` into `Panoptic.Chunk`, leave `Panel.Subgraph.legChunkKey` a thin re-export." A literal move is impossible: `Panoptic.Chunk` imports `Panel.Subgraph` for the `Leg`/`Chunk` record types, so `Panel.Subgraph` cannot import `Panoptic.Chunk` back — that is a compile-blocking import cycle.
- **Fix:** Inverted the delegation. The canonical floor/ceil arithmetic remains in the leaf module `Panel.Subgraph.legChunkKey` (already validated match-rate 1.0 at 10-01); `Panoptic.Chunk.getTicks`/`getRangesFromStrike` delegate to it and `Panoptic.Chunk` re-exports `legChunkKey`. Same single-source-of-truth guarantee, no duplicated arithmetic, `app/Main.hs`'s existing `legChunkKey` call keeps working unchanged.
- **Files:** `econometrics/src/Panoptic/Chunk.hs`, `econometrics/src/Panel/Subgraph.hs` (doc note).
- **Commit:** `0b0d397`.

**2. [Rule 2 - Missing field] `Leg` gained `legAsset`**
- **Found during:** Task 1 (`legLiquidity` must select the token side by `asset`, which the `Leg` type did not carry).
- **Fix:** Added `legAsset :: !Int`, selected it in `legsQuery`, and parsed `asset` optionally in the `FromJSON` instance with a `tokenType` default so the pre-existing asset-less `subgraph-sample.json` legs fixture still decodes (its consumers ignore `asset`). No token side is guessed for live data.
- **Files:** `econometrics/src/Panel/Subgraph.hs`.
- **Commit:** `0b0d397`.

**3. [Test-truthfulness] `legLiquidity` strict-positivity scoped to substantial positionSizes**
- **Found during:** Task 1 (a first spec asserting strict positivity for EVERY non-zero positionSize row failed).
- **Issue:** A `positionSize == 1`, `optionRatio == 1` leg selected on token0 over a 100-tick chunk yields `L == 0` under floor division — this is Panoptic's exact `getLiquidityChunk` behaviour, not a bug. The plan's blanket "strictly positive for every non-zero positionSize row" over-claims for degenerate sizes.
- **Fix:** Strict positivity is asserted for substantial positionSizes (both token sides); the `positionSize == 1` case is tested as a non-negative floor-to-zero, matching on-chain arithmetic.
- **Files:** `econometrics/test/Panoptic/ChunkSpec.hs`.
- **Commit:** `0b0d397`.

**4. [Rule 3 - Blocking] `buildReadSchedule` derives spell epochs from the block index, not a hardcoded 3600**
- **Found during:** Task 2.
- **Issue:** The plan phrases interior rows as "epochs in `[epoch_mint .. epoch_burn]`", but `MintEvent`/`BurnEvent` carry blocks and timestamps, not epochs, and re-deriving `epoch = floor(ts/3600)` inside the schedule would reintroduce the exact epoch-rule duplication 10-03 designed out.
- **Fix:** Interior epochs are those whose boundary block (from `Chain.BlockIndex`) lies within the spell's `[meBlock, beBlock]` — the block index is the single authority for which epochs a spell spans; no epoch rule is re-derived. `epochOfBlock` tags endpoint rows with the epoch their exact block falls in.
- **Files:** `econometrics/src/Panoptic/Chunk.hs`.
- **Commit:** `628d674`.

## Authentication Gates

None. Both tasks are fully offline against the frozen `chunks-sample.json` fixture and synthetic block indices; no network, no keys.

## Issues Encountered

- One initial spec failure (the `positionSize == 1` floor-to-zero above), which surfaced correct on-chain floor-division behaviour rather than a code defect — resolved by making the test faithful (Deviation 3). No code defect.

## Next Phase Readiness

- **10-05 (fan-out / attribution):** consume `readScheduleRaw` for the full `(tokenId, leg)` mapping and `legLiquidity` to attribute pool-wide accumulator reads back to positions.
- **10-06 (execution):** drive `buildReadSchedule` over real spells joined to `epoch-blocks.csv`, print `DISTINCT_READS`/`SCHEDULE_ROWS`, and budget against the HOURLY ~30k–60k / ~70–140 min envelope (10-03), re-probing archive availability (dated ~2026-08-19).
- **10-08 (gate):** the exact-block mint/burn endpoint rows are already tagged (`rrEndpoint`) so the reconciliation reads accumulators at the spell endpoints, not the nearest epoch boundary.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-21*

## Self-Check: PASSED

- All 6 claimed files exist on disk (2 created, 3 modified, + this SUMMARY).
- Both task commits (0b0d397, 628d674) exist in history.
- Suite 102 → 117/0 (+15 offline ChunkSpec examples); getTicks match rate 1.0 on 126/126 frozen Chunk records; no `Double` in any Panoptic.Chunk signature; no network/URL in source or spec.
