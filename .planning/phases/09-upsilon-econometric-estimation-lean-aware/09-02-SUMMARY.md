---
phase: 09-upsilon-econometric-estimation-lean-aware
plan: 02
subsystem: data
tags: [panoptic, subgraph, goldsky, base, uniswap-v4, eth_getLogs, bigquery, variance, data-sources]

# Dependency graph
requires:
  - phase: 09-upsilon-econometric-estimation-lean-aware
    provides: 09-01 econometrics/ Stack scaffold + Econ.Types Obs/Panel/Theta records the panel/variance builders populate
provides:
  - Confirmed non-Sepolia Panoptic subgraph endpoint (keyless Goldsky panoptic-subgraph-base/dev/gn)
  - Confirmed panel market — Base V4 ETH/USDC (chainId 8453, panopticPool 0xb50e...174a, underlying V4 poolId 0x96d4...288c0a)
  - Uniswap V4 PoolManager Swap topic0 (0x40e9cecb...112f) + poolId indexed-topic filter for the variance builder
  - Recorded variance data route: direct RPC eth_getLogs on Base V4 Swap logs (BigQuery dropped)
  - Self-describing DATA-SOURCES.md with a resolved §4 DECISION section superseding the discovery §3
affects: [09-04, 09-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [self-describing data-sources note with discovery record retained + authoritative resolved-decision section appended, live _meta probe recorded verified-at-resolution]

key-files:
  created: []
  modified:
    - notes/structural-econometrcics/data/DATA-SOURCES.md

key-decisions:
  - "MARKET: accept Base V4 ETH/USDC (chainId 8453, panopticPool 0xb50e8bb68f5855da742f4579274902a20454174a, poolId 0x96d4...288c0a) — the only reachable non-Sepolia Panoptic subgraph; Ethereum-mainnet Goldsky subgraphs are all 404"
  - "GRAPH_API_KEY NOT required — the Goldsky Base endpoint is public"
  - "VARIANCE ROUTE: direct RPC eth_getLogs on Base V4 PoolManager Swap logs (V4 topic0 + poolId in topics[1]); BigQuery dropped — project thetaswap-research suspended, 403 CONSUMER_SUSPENDED on every query (verified parent session 2026-07-19)"

patterns-established:
  - "Resolved-checkpoint pattern: append an authoritative §4 DECISION section that supersedes the earlier discovery/open-decision section, keeping the discovery trail intact for audit"

requirements-completed: [CTX-PANEL, CTX-VAR]

# Metrics
duration: 6min
completed: 2026-07-19
---

# Phase 9 Plan 02: Data-Source Discovery Gate — Base V4 Market + RPC Variance Route Summary

**Confirmed the live data path for the υ-identification panel: keyless Goldsky Base Panoptic subgraph (Base V4 ETH/USDC, chainId 8453) for positions/premia/strikes, and direct RPC `eth_getLogs` on Base V4 PoolManager Swap logs for the variance source — BigQuery dropped after CONSUMER_SUSPENDED.**

## Performance

- **Duration:** 6 min (checkpoint-continuation only; Tasks 1-2 landed earlier in de6aaba)
- **Started:** 2026-07-19T18:30:00Z (continuation spawn)
- **Completed:** 2026-07-19T18:36:00Z
- **Tasks:** 1 of 1 remaining (Task 3 checkpoint resolution); Tasks 1-2 pre-completed
- **Files modified:** 1

## Accomplishments

- Resolved the blocking human-verify checkpoint (Task 3) with the user decision "accept base", closing the data-access gate for the whole Phase-9 pipeline.
- Recorded the confirmed panel market in `DATA-SOURCES.md` §4: Base V4 ETH/USDC — chainId 8453, panopticPool `0xb50e8bb68f5855da742f4579274902a20454174a` (fee 0.05%), underlying Uniswap V4 poolId `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a`, keyless Goldsky endpoint `panoptic-subgraph-base/dev/gn`.
- Verified the confirmed endpoint live at resolution time: a `_meta` GraphQL probe returned block 48,861,639 (2026-07-20T01:57:05Z) with `hasIndexingErrors: false`.
- Recorded the variance route change: direct RPC `eth_getLogs` on Base V4 Swap logs (V4 topic0 + poolId in `topics[1]`), replacing the assumed BigQuery `crypto_ethereum` v3 SQL path.
- Documented the downstream implications: 09-05's variance builder consumes RPC-pulled Base V4 Swap logs (the reference SQL is now historical/alternative only); 09-04's panel is unaffected except for the market identifiers.

## Task Commits

1. **Task 1: Discover/probe non-Sepolia Panoptic subgraph endpoint** — `de6aaba` (feat, pre-completed)
2. **Task 2: BigQuery reachability + Uniswap Swap topic0** — `de6aaba` (feat, pre-completed)
3. **Task 3: Checkpoint resolution — record confirmed market + variance route** — `7fbdf82` (docs)

**Plan metadata:** _this SUMMARY + STATE + ROADMAP_ (docs: complete plan)

## Files Created/Modified

- `notes/structural-econometrcics/data/DATA-SOURCES.md` — appended §4 "DECISION (resolved checkpoint)" recording the confirmed Base V4 market identifiers, the keyless endpoint, GRAPH_API_KEY-not-required, the RPC variance route, and the BigQuery drop; updated the header Status from awaiting-decision to RESOLVED.

## Decisions Made

- **Accept Base V4 ETH/USDC as the panel market** (user "accept base"). It is the only reachable non-Sepolia Panoptic subgraph — every Ethereum-mainnet Goldsky subgraph (prod and dev tags) is 404, and Panoptic V2 currently deploys only to Base + Sepolia.
- **GRAPH_API_KEY not required** — the Goldsky Base endpoint is public; nothing added to `.env`.
- **Variance from direct RPC `eth_getLogs`, not BigQuery** — the GCP project `thetaswap-research` is suspended (403 CONSUMER_SUSPENDED on every query, verified from the parent session), and the user did not authorize fixing/switching the BigQuery project. σ̂²_t and the EIV second window build from Base V4 PoolManager Swap logs via chunked `eth_getLogs` (public RPC by default; a paid RPC key can go into `.env` later if rate limits demand).

## Deviations from Plan

The plan assumed a mainnet/L2 ETH/USDC market on a clean Uniswap-v3 + `bigquery-public-data.crypto_ethereum` path. Discovery (Tasks 1-2) and the user decision diverged from that assumption. These are user-directed resolutions of the plan's own checkpoint, not autonomous deviation-rule fixes:

**1. [User-directed] Base V4 market instead of a mainnet v3 market**
- **Found during:** Task 1 (discovery)
- **Issue:** No live Ethereum-mainnet Panoptic subgraph exists (all Goldsky mainnet endpoints 404); only Base (V4) is reachable.
- **Resolution:** User accepted the Base V4 ETH/USDC market as the panel market.
- **Files modified:** `notes/structural-econometrcics/data/DATA-SOURCES.md`
- **Committed in:** `7fbdf82`

**2. [User-directed] BigQuery → direct RPC `eth_getLogs` for the variance source**
- **Found during:** Task 2 / checkpoint resolution
- **Issue:** BigQuery is unusable — GCP project `thetaswap-research` suspended (403 CONSUMER_SUSPENDED, verified parent session). The chosen market is also Uniswap V4 on Base, which `crypto_ethereum` (mainnet v3) does not cover anyway.
- **Resolution:** Variance built from Base V4 PoolManager Swap logs via chunked `eth_getLogs` against a Base RPC; the reference SQL retained as historical/alternative only.
- **Files modified:** `notes/structural-econometrcics/data/DATA-SOURCES.md`
- **Committed in:** `7fbdf82`

---

**Total deviations:** 2 user-directed (checkpoint resolutions, not auto-fixes).
**Impact on plan:** The pipeline's data path is now concrete and reachable. 09-05 must consume RPC V4 Swap logs rather than BigQuery SQL; 09-04 is unaffected except market identifiers. No scope creep.

## Issues Encountered

- The executor session that produced Tasks 1-2 lacked the `mcp__bigquery__` MCP tools, so the BigQuery dry-run could not be run there — it was surfaced to the checkpoint. The parent session then established that BigQuery is entirely unusable (project suspended), which is what drove the RPC route. Resolved via the user decision.

## User Setup Required

None — the confirmed Base subgraph endpoint is public (no `GRAPH_API_KEY`). A paid Base RPC key is only needed later if public-RPC rate limits become a problem for the variance builder (09-05); if so it goes into the worktree `.env`, gitignored.

## Next Phase Readiness

- **Wave 2 unblocked.** Both data sides are confirmed and recorded self-describingly.
- **09-04 (panel):** ready — reads positions/premia/strikes from the keyless Base subgraph (panopticPool `0xb50e...174a`, poolId `0x96d4...288c0a`).
- **09-05 (variance):** ready — must be wired to RPC `eth_getLogs` on Base V4 Swap logs (V4 topic0 `0x40e9cecb...112f`, poolId in `topics[1]`), NOT BigQuery SQL. This is the one override 09-05 must honor.
- **Concern:** the Base ETH/USDC market has a thin cross-section (only ~7 distinct panopticPoolAccounts observed), which may limit tokenId clustering — flagged for the panel/estimation plans.

## Self-Check: PASSED

- FOUND: `notes/structural-econometrcics/data/DATA-SOURCES.md`
- FOUND: `.planning/phases/09-upsilon-econometric-estimation-lean-aware/09-02-SUMMARY.md`
- FOUND commit: `7fbdf82` (Task 3 resolution)
- FOUND commit: `de6aaba` (Tasks 1-2)

---
*Phase: 09-upsilon-econometric-estimation-lean-aware*
*Completed: 2026-07-19*
