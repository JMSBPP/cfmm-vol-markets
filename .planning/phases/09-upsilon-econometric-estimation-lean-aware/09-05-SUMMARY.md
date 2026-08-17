---
phase: 09-upsilon-econometric-estimation-lean-aware
plan: 05
subsystem: econometrics
tags: [haskell, variance, eiv-instrument, uniswap-v4, base, eth_getLogs, json-rpc, realized-variance]

# Dependency graph
requires:
  - phase: 09-01
    provides: econometrics/ Haskell scaffold (stack lts-24.50, Econ.Types, CLI skeleton, hspec harness)
  - phase: 09-02
    provides: DATA-SOURCES.md §4 resolved data contract (Base V4 ETH/USDC market, RPC eth_getLogs variance route, V4 Swap topic0 + poolId)
  - phase: 09-04
    provides: Panel.Build.dailyEpoch (the shared daily-epoch boundary) reused as the single source of truth
provides:
  - "Panel.Variance: chunked eth_getLogs ingestion of Base V4 Swap logs + int24/uint160 ABI decode"
  - "realizedVariance σ̂²_t (within-day realized variance) and instrumentVariance σ̃²_t (disjoint even-swap EIV instrument)"
  - "live 'variance' CLI stage (RPC fetch → tick cache → variance.csv)"
  - "notes/structural-econometrcics/data/variance.csv (epoch,sigma2,sigma2_instrument) over a live bounded Base V4 sample"
affects: [09-09 live estimation (consumes variance.csv, joins to panel.csv by epoch), 09-08 EIV-IV estimator]

# Tech tracking
tech-stack:
  added: [time, http-conduit/Network.HTTP.Simple JSON-RPC client, aeson eth_getLogs decode]
  patterns:
    - "Chunked eth_getLogs over block ranges with inline blockTimestamp extraction (no per-block eth_getBlockByNumber)"
    - "Full-word two's-complement decode of ABI int24 (tick) / uint160 (sqrtPriceX96) from Swap log data words"
    - "Fixture-driven deterministic golden tests for numeric core; live RPC only at the CLI edge"

key-files:
  created:
    - econometrics/src/Panel/Variance.hs
    - econometrics/test/Panel/VarianceSpec.hs
    - econometrics/test/fixtures/swap-ticks-sample.csv
    - notes/structural-econometrcics/data/variance.csv
    - notes/structural-econometrcics/data/swap-ticks-base-v4-sample.csv
  modified:
    - econometrics/app/Main.hs
    - econometrics/package.yaml
    - econometrics/test/Spec.hs

key-decisions:
  - "USER-DIRECTED OVERRIDE: build σ̂²_t from Uniswap V4 Swap logs on Base via chunked eth_getLogs (BigQuery dropped — project suspended); the plan's BigQuery SQL kept only as historicalBigQuerySql provenance"
  - "Instrument σ̃²_t = realized variance on the DISJOINT even-swap intraday sub-window (0-based even positions), the two-noisy-measures EIV remedy"
  - "Reuse Panel.Build.dailyEpoch (whole-UTC-days-since-Unix-epoch) as the single epoch-index source of truth so variance.csv and panel.csv join on identical labels"

patterns-established:
  - "V4 Swap-log data word map: [amount0, amount1, sqrtPriceX96, liquidity, tick, fee] — cross-verified by word5 = 0x1f4 = 500 (pool fee tier)"
  - "eth_getLogs filter = PoolManager singleton address + V4 Swap topic0 + poolId in topics[1]"

requirements-completed: [CTX-VAR]

# Metrics
duration: 28min
completed: 2026-07-20
---

# Phase 9 Plan 05: Variance Regressor σ̂²_t and EIV Instrument σ̃²_t Summary

**Within-day realized variance and its disjoint even-swap EIV instrument, built in Haskell from live Uniswap V4 PoolManager Swap logs on Base via chunked eth_getLogs (BigQuery path retired), golden-tested to 1e-9 and aligned to the panel's daily epoch.**

## Performance

- **Duration:** ~28 min
- **Started:** 2026-07-20T02:00:00Z
- **Completed:** 2026-07-20T02:27:47Z
- **Tasks:** 2 (Task 2 executed as TDD RED → GREEN)
- **Files modified:** 8 (3 created source/fixture, 2 created data artifacts, 3 modified)

## Accomplishments

- **RPC ingestion of Base V4 Swap logs** replacing the dead BigQuery path: chunked `eth_getLogs` filtered by the V4 Swap topic0 + poolId (`topics[1]`), decoding the tick (`int24`, word 4) and `sqrtPriceX96` (`uint160`, word 2) straight from the log `data` via full-word two's-complement. Confirmed the Base PoolManager singleton `0x498581ff…2652b2b` and that the public Base RPC returns `blockTimestamp` inline (no extra block round-trips).
- **σ̂²_t and σ̃²_t** computed as within-day realized variance of V4 tick-implied log-price increments, with the instrument taken over a disjoint even-swap sub-window (two-noisy-measures IV, spec §4.3), bucketed by the panel's `dailyEpoch`.
- **Live end-to-end proof:** the `variance` CLI stage fetched **2,136 real swaps** over blocks 48,768,127–48,775,327 (~4 h straddling a UTC midnight), cached them, and wrote `variance.csv` with **2 epochs** (20651 = 2026-07-17, 20652 = 2026-07-18).
- **Deterministic golden suite:** 8/8 `VarianceSpec` cases green (RV/instrument to 1e-9, boundary bucketing, live-data ABI decode); full shared suite 18/0.

## Task Commits

1. **Task 1: Base V4 Swap-log RPC ingestion + int24 tick decode** - `e8eae01` (feat)
2. **Task 2: σ̂²_t + disjoint-window instrument σ̃²_t** (TDD):
   - RED (failing spec + math stubs) - `7511230` (test)
   - GREEN (real bodies + CLI wiring + live variance.csv) - `304bec3` (feat)

**Plan metadata:** _this commit_ (docs: complete plan)

## Files Created/Modified

- `econometrics/src/Panel/Variance.hs` - RPC ingestion, ABI decode, realized/instrument variance, CSV writer; `historicalBigQuerySql` kept as provenance only
- `econometrics/test/Panel/VarianceSpec.hs` - CTX-VAR golden spec (RV, instrument, boundary, ABI decode)
- `econometrics/test/fixtures/swap-ticks-sample.csv` - frozen 2-UTC-day tick fixture for deterministic tests
- `econometrics/app/Main.hs` - live `variance` CLI stage (RPC fetch or cached ticks → variance.csv)
- `econometrics/package.yaml` - added `time` (lib), `containers`/`time` (tests), `containers` (exe); registered `Panel.VarianceSpec`
- `econometrics/test/Spec.hs` - registered `Panel.VarianceSpec.spec` (shared entry point)
- `notes/structural-econometrcics/data/variance.csv` - per-epoch σ̂²_t and σ̃²_t (live Base V4 sample)
- `notes/structural-econometrcics/data/swap-ticks-base-v4-sample.csv` - cached raw tick series (re-runs never refetch)

## Decisions Made

- **Transport = RPC, not BigQuery** (user-directed): σ̂²_t and the EIV window derive from V4 `eth_getLogs`; the variance math itself is transport-agnostic and unchanged from the plan.
- **Instrument window = even-swap sub-window** (documented in the CSV banner and code): a disjoint sub-sample of the same day's swaps, giving an independent noisy measure of the same daily σ² to instrument σ̂²_t.
- **Single-source epoch boundary:** imported/re-exported `Panel.Build.dailyEpoch` rather than defining a second one, so the two CSVs share the exact integer epoch index.

## Deviations from Plan

### Auto-fixed / user-directed adaptations

**1. [User-directed override] BigQuery SQL → chunked eth_getLogs RPC transport**
- **Found during:** Task 1 (ingestion)
- **Issue:** The plan's live source was BigQuery (`crypto_ethereum.logs`, v3 Swap topic0 by pool address). Per the 09-02 checkpoint resolution (DATA-SOURCES.md §4), BigQuery is unusable (GCP project suspended, 403 CONSUMER_SUSPENDED) and the confirmed market is Uniswap V4 on Base (PoolManager singleton keyed by poolId).
- **Fix:** Implemented chunked `eth_getLogs` JSON-RPC in Haskell (Network.HTTP.Simple + aeson) filtered by V4 Swap topic0 + poolId; decode tick/sqrtPriceX96 from the V4 log `data`. Retained the plan's SQL as `historicalBigQuerySql` (provenance only, NOT wired). Transport-agnostic acceptance criteria (module, decode, variance math, no-secrets, no-home-paths, CSV header) kept as-is; the transport-specific `eth_getLogs`/topic0/poolId path replaces the BigQuery/MCP path.
- **Files modified:** econometrics/src/Panel/Variance.hs, econometrics/app/Main.hs
- **Verification:** live pull of 2,136 swaps → variance.csv (2 epochs); 8/8 spec green.
- **Committed in:** e8eae01, 304bec3

**2. [Rule 2 - Correctness] Epoch-index reconciliation with the panel**
- **Found during:** Task 2 GREEN (after 09-04 landed its real `dailyEpoch` in parallel)
- **Issue:** I initially defined `dailyEpoch` via Modified-Julian-Day, but 09-04's `Panel.Build.dailyEpoch` uses whole-UTC-days-since-Unix-epoch (`floor(posix/86400)`). Both share the UTC-midnight boundary, but the integer labels differ by a constant 40587 — which would silently break the variance.csv ↔ panel.csv join in 09-09.
- **Fix:** Dropped the local definition and import/re-export `Panel.Build.dailyEpoch` as the single source of truth; updated the golden tests and regenerated variance.csv (epochs now 20651/20652, panel convention). No refetch (recomputed from cache).
- **Files modified:** econometrics/src/Panel/Variance.hs, econometrics/test/Panel/VarianceSpec.hs, notes/structural-econometrcics/data/variance.csv
- **Verification:** full suite 18/0; variance.csv epochs match the panel's dailyEpoch.
- **Committed in:** 304bec3

**3. [Adaptation] decodeTick word index for V4 (not the plan's "trailing int24")**
- **Found during:** Task 1
- **Issue:** The plan described the tick as the *trailing* int24 of the Swap `data` (the v3 layout). In the V4 `Swap` event the trailing word is `fee` (uint24); the tick is word 4 of 6.
- **Fix:** `decodeTick` reads word 4 and sign-extends via full-word two's-complement. Cross-verified against a live log whose word 5 decoded to `0x1f4` = 500 (the pool's 0.05% fee tier) and whose tick = -201156.
- **Files modified:** econometrics/src/Panel/Variance.hs
- **Verification:** ABI-decode spec cases green against the live-data blob.
- **Committed in:** e8eae01, 7511230

---

**Total deviations:** 1 user-directed transport override + 2 auto-fixed (1 correctness, 1 ABI adaptation).
**Impact on plan:** All are required for the confirmed Base V4 / RPC reality and for a correct downstream join. No scope creep — variance math is exactly the plan's.

## Issues Encountered

- **Shared test suite / shared files under parallel execution:** 09-04 (panel) runs in the same `econometrics/` package and shares `test/Spec.hs`, `app/Main.hs`, and `package.yaml`. During execution the shared `stack test` was momentarily RED from 09-04's in-progress TDD stub `Panel.BuildSpec`; I validated my work in isolation via `--match "Panel.Variance (CTX-VAR)"`. 09-04 landed its GREEN mid-execution, so the full suite is now 18/0. Shared-file edits (Spec.hs registration, Main.hs `variance` wiring, package.yaml deps) were kept surgical to avoid clobbering the sibling's work.
- **Public RPC UA filtering:** the Base public RPC 403s python-urllib's default user agent (Cloudflare); the Haskell http-conduit client and `curl` are unaffected. Not a code issue.

## Scope / Boundary Notes

- Haskell only, all work inside `econometrics/` (variance/RPC modules) + the two data CSVs under `notes/`. Did not touch `lean/`, `scratch/`, or 09-04's panel/subgraph modules.
- **Sample vs full history:** only a bounded ~4 h window (2,136 swaps, 2 epochs) was pulled here to prove the pipeline + caching. The full ~4-month pull runs in 09-09's live estimation (the `variance` CLI takes `--from/--to/--rpc/--chunk`).
- No secrets printed or committed; default RPC = public `https://mainnet.base.org` (documented). A paid RPC key, if needed later, goes in the worktree `.env` only.

## Next Phase Readiness

- `variance.csv` (σ̂²_t, σ̃²_t) is ready for 09-08 (EIV-IV estimator) and 09-09 (live estimation), joining to `panel.csv` on the shared `dailyEpoch` index.
- For 09-09: widen the `variance` CLI block window to the market's full history (first OptionMint block 43,781,657 → tip); consider a chunk size and/or paid RPC to keep the ~4-month pull within rate limits.

---
*Phase: 09-upsilon-econometric-estimation-lean-aware*
*Completed: 2026-07-20*

## Self-Check: PASSED

All created files present; all 3 task commits (e8eae01, 7511230, 304bec3) exist in history.
