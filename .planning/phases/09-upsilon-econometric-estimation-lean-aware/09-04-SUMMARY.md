---
phase: 09-upsilon-econometric-estimation-lean-aware
plan: 04
subsystem: data
tags: [haskell, subgraph, graphql, panoptic, cassava, aeson, panel, base-v4]

# Dependency graph
requires:
  - phase: 09-01
    provides: econometrics/ Stack scaffold (lts-24.50, hmatrix-gsl linked, Econ.Types.Obs, hspec suite)
  - phase: 09-02
    provides: confirmed data source — Base V4 ETH/USDC market (chainId 8453, panopticPool 0xb50e...174a, poolId 0x96d4...288c0a), keyless Goldsky base/dev subgraph
provides:
  - Panel.Subgraph — paginated GraphQL client (fetchPositions) + typed RawPosition/Leg/Snapshot decode + frozen fixture
  - Panel.Build — dailyEpoch (00:00 UTC), deltaPremia (cumulative→per-epoch flow), strikeToTick (λ=1.0001), assemble→Obs, writePanelCsv
  - build-panel CLI stage (fetch → assemble → writePanelCsv)
  - notes/structural-econometrcics/data/panel.csv — tokenId×daily panel (π_it, i_K, i_t; σ̂² placeholder)
affects: [09-05, 09-07, 09-09, 09-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GraphQL POST via http-conduit; endpoint from CLI/config, GRAPH_API_KEY from env (never hardcoded)"
    - "BigInt/BigDecimal string-or-number JSON coercion (numDouble/numInt/numInteger/numBool)"
    - "cumulative→delta epoch assembly (diff consecutive snapshots, tag by ENDING epoch)"
    - "daily epoch defined ONCE (floor(unixSeconds/86400)) shared with 09-05 variance window"

key-files:
  created:
    - econometrics/src/Panel/Subgraph.hs
    - econometrics/src/Panel/Build.hs
    - econometrics/test/Panel/BuildSpec.hs
    - econometrics/test/fixtures/subgraph-sample.json
    - notes/structural-econometrcics/data/panel.csv
  modified:
    - econometrics/app/Main.hs
    - econometrics/test/Spec.hs
    - econometrics/package.yaml

key-decisions:
  - "π_it = per-epoch DELTA of cumulative premiaSettledInUsdTotal, tagged to the ENDING snapshot's epoch (N snapshots → N−1 rows)"
  - "i_K = round(log strike / log 1.0001) mirrors PosSpec.lam; strike parsed as a price ratio (converted to tick), not a raw tick"
  - "daily epoch = floor(unixSeconds/86400) (00:00 UTC bucket), single definition reused by 09-05's variance window"
  - "σ̂² columns emitted as NaN placeholder (fails loudly if used pre-join) — 09-05 fills them"
  - "BuildSpec integrated into the existing unit suite via Panel.BuildSpec.spec (single test binary), avoiding a second Main"

patterns-established:
  - "Frozen normalized subgraph fixture drives offline panel tests; live block-height snapshotting finalized at 09-09"
  - "Numeric coercion accepts JSON string or number for subgraph BigInt/BigDecimal scalars"

requirements-completed: [CTX-PANEL]

# Metrics
duration: 6min
completed: 2026-07-19
---

# Phase 9 Plan 04: Position-Epoch Panel (CTX-PANEL) Summary

**Panoptic Base-V4 subgraph client + cumulative→delta panel assembler producing a tokenId×daily panel (π_it flows, λ=1.0001 strike ticks i_K, pool ticks i_t) with a σ̂² placeholder for the 09-05 join.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-07-19T22:06Z (local -04:00)
- **Completed:** 2026-07-19T22:11Z (local -04:00)
- **Tasks:** 2 (Task 2 is TDD: RED → GREEN)
- **Files modified:** 8 (5 created, 3 modified)

## Accomplishments
- `Panel.Subgraph`: paginated (`first`/`skip`) GraphQL POST client; endpoint from config, optional `GRAPH_API_KEY` from env via `lookupEnv` (confirmed Base endpoint is keyless); typed `RawPosition`/`Leg`/`Snapshot` decode with string-or-number scalar coercion; frozen `subgraph-sample.json` (2 tokenIds, cumulative-premia snapshots for pool `0xb50e...174a`).
- `Panel.Build`: `dailyEpoch` (00:00 UTC bucket, shared with 09-05), `deltaPremia` (cumulative→per-epoch flow), `strikeToTick` (λ=1.0001, mirrors `PosSpec.lam`), `assemble`→`Econ.Types.Obs`, `writePanelCsv` (cassava, self-describing header).
- `build-panel` CLI stage wired fetch → assemble → writePanelCsv.
- `notes/structural-econometrcics/data/panel.csv` generated from the fixture: 3 rows, per-epoch deltas 30/45/40, ticks 488/−305, NaN σ̂² placeholder.
- Fixture-driven `BuildSpec` (6 cases) green in the unit suite; full `stack test` = 10/10.

## Task Commits

1. **Task 1: Subgraph GraphQL client + frozen fixture** - `51dbb4b` (feat)
2. **Task 2 (RED): failing fixture test for panel assembly** - `92c5de4` (test)
3. **Task 2 (GREEN): panel assembly + build-panel CLI + panel.csv** - `ff9902f` (feat)

_TDD Task 2: RED (stubbed Panel.Build, 6 failing) → GREEN (real impl, 10/10 pass). No refactor commit needed — code was clean._

## Files Created/Modified
- `econometrics/src/Panel/Subgraph.hs` - GraphQL client, `fetchPositions`, `parsePositions`, typed decode
- `econometrics/src/Panel/Build.hs` - epoch bucketing, cumulative→delta, strike tick, assemble, CSV writer
- `econometrics/test/Panel/BuildSpec.hs` - fixture-driven behaviours (deltas, tick, N−1 rows)
- `econometrics/test/fixtures/subgraph-sample.json` - frozen normalized subgraph response
- `notes/structural-econometrcics/data/panel.csv` - the assembled panel (σ̂² joined in 09-05)
- `econometrics/app/Main.hs` - `build-panel` subcommand
- `econometrics/test/Spec.hs` - runs `Panel.BuildSpec.spec`
- `econometrics/package.yaml` - registered `Panel.BuildSpec` + `bytestring` test dep

## Decisions Made
- Used the confirmed Base V4 market identifiers (chainId 8453, panopticPool `0xb50e...174a`) throughout — the plan's abstract "confirmed pool" resolved to these per DATA-SOURCES.md §4 (see Deviations).
- Strike stored as a price ratio in the fixture and converted via `strikeToTick`; keeps the Haskell i_K byte-for-byte on the Lean λ=1.0001 grid.
- σ̂² placeholder is `NaN` (not `0`) so any premature use surfaces rather than silently biasing the estimate.
- `BuildSpec` folded into the existing `unit` suite (not a second suite) to avoid an hpack module-discovery clash with the shared `test/` source-dir.

## Deviations from Plan

### User-directed adaptations (from DATA-SOURCES.md §4 resolution)

**1. Market identifiers: mainnet/v3 assumption → Base V4**
- **Found during:** Task 1 (Subgraph client)
- **Issue:** The plan/RESEARCH assumed a mainnet or generic ETH/USDC market with a v3 pool address; the 09-02 checkpoint resolved the reachable market to Base V4 (chainId 8453, panopticPool `0xb50e...174a`, poolId `0x96d4...288c0a`, keyless Goldsky base/dev subgraph).
- **Fix:** Documented the confirmed identifiers in `Panel.Subgraph`'s module header and used the panopticPool address in the fixture; the client filters by the supplied pool id (either the panopticPool or the underlying poolId, passed in via CLI — not hardcoded to a chain).
- **Files:** econometrics/src/Panel/Subgraph.hs, econometrics/test/fixtures/subgraph-sample.json
- **Committed in:** `51dbb4b`

### Auto-fixed Issues

**2. [Rule 3 - Blocking] Test-suite wiring for the new spec**
- **Found during:** Task 2 (RED)
- **Issue:** The frozen fixture test needed to run under `stack test`, but the `unit` suite shares `source-dirs: test` with `Spec.hs` (a `module Main`); a second suite would collide on hpack module discovery.
- **Fix:** Registered `Panel.BuildSpec` as an other-module of the `unit` suite (+ `bytestring` test dep) and invoked `Panel.BuildSpec.spec` from `Spec.hs`.
- **Files:** econometrics/package.yaml, econometrics/test/Spec.hs
- **Verification:** `stack test` = 10 examples, 0 failures.
- **Committed in:** `92c5de4`

---

**Total deviations:** 1 user-directed adaptation + 1 auto-fixed (Rule 3 blocking).
**Impact on plan:** No scope creep. The Base V4 adaptation is exactly the 09-02 checkpoint resolution the plan anticipated; the test wiring was mechanically required.

## Issues Encountered
- The shared `econometrics/package.yaml` was modified on disk mid-execution by the parallel 09-05 session (added `time` to library deps — which `Panel.Build` also needs). Re-read before editing; my additive test-suite edits applied cleanly with no clobber. Left 09-05's `Panel/Variance.hs` and `swap-ticks-sample.csv` untracked (their files, not staged).

## User Setup Required
None - the confirmed Base subgraph endpoint is public/keyless; no `GRAPH_API_KEY` required (the env hook exists only for a future gateway-hosted subgraph).

## Next Phase Readiness
- **09-05 (variance):** consumes the same `dailyEpoch` boundary and joins σ̂²_t + the EIV instrument into the `sigma2_placeholder` column of `panel.csv` (via RPC `eth_getLogs` on Base V4 Swap logs, NOT BigQuery).
- **09-07/09-09 (estimation):** read the completed `panel.csv`; the live block-height snapshotting for `fetchPositions` is finalized at 09-09.
- **Concern:** thin cross-section (~7 accounts / 1000+ OptionMints over ~4 months) — panel is built from what exists, no synthetic padding.

---
*Phase: 09-upsilon-econometric-estimation-lean-aware*
*Completed: 2026-07-19*

## Self-Check: PASSED

All created files present; all task commits (51dbb4b, 92c5de4, ff9902f) exist in history.
