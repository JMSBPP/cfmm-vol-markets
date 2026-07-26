# premium-accumulators.csv — data lineage (plan 10-06)

**Built:** 2026-07-21 → 2026-07-22 (resumable pull across multiple sessions)
**Dataset:** `notes/structural-econometrcics/data/premium-accumulators.csv` — 8,910 data rows (+1 CSV header, +6 comment lines), 12 columns: `token_type,tick_lower,tick_upper,block,is_long,at_tick,acc0_x64,acc1_x64,net_liquidity,removed_liquidity,epoch,endpoint`

## Source

- **Contract:** `SemiFungiblePositionManagerV4.getAccountPremium(...)` at `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` (SFPM, via `PanopticPool.SFPM()`), VEGOID = 8 (ν = 1/8 multiplier included in the accumulator).
- **Market:** Base (chainId 8453), PanopticPool `0xb50e8bb68f5855da742f4579274902a20454174a`, Uniswap V4 poolId `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a`.
- **RPC:** `https://mainnet.base.org` (archive-capable, keyless), failover `https://base.drpc.org`. Final slice: `FAILOVER_CALLS: 0`.
- **Schedule:** `Panoptic.Chunk.buildReadSchedule` — 2,832 hourly epoch boundaries (`epoch-blocks.csv`, plan 10-03) interior reads + exact-block mint/burn endpoint rows for the 61 Phase-9 spells, deduplicated pool-wide on `(chunkKey, block, isLong, atTick)` → **DISTINCT_READS = 8,910** (vs the 30k–60k pre-dedup envelope; the 52-distinct-chunk dedup was the lever).
- **Driver:** `Panoptic.ReadDriver` (commit `d2a5086`) — checkpointed (append-per-row), resumable (skips cached rows), fail-loud (retry/backoff then abort; never silently narrows the window). CLI: `read-premia` (commit `15dbff5`).

## Pull history (resume chain)

| Cycle | Rows at start → end | Driver |
|---|---|---|
| 1–2 (executor, 2026-07-21) | 0 → 2,208 | background slices, env-capped |
| 3–4 (executor) | 2,208 → 5,364 | interrupted twice by session limits; cache unaffected |
| 5 (orchestrator, direct CLI) | 5,364* → 6,922 | aborted by RPC rate-limit exhaustion on both endpoints (fail-loud), +1,552 rows |
| 6 (orchestrator, direct CLI, completed 2026-07-25 per fs/git evidence; earlier '2026-07-22' dating was wrong) | 6,922 → **8,910 COMPLETE** | `CALLS_MADE: 1994`, `ELAPSED_S: 7963`, `FAILOVER_CALLS: 0` |

*One false start ran from `econometrics/` cwd and died on relative-path resolution before writing anything (variance.csv not found) — zero rows affected.

## Integrity checks (2026-07-22)

- Row count: **8,910 == schedule** (6 comment lines + 1 header + 8,910 data).
- Exact-duplicate rows: **0** (`sort -u` count == total).
- Duplicate read keys (all columns through `at_tick`): **0**.
- `net_liquidity==0` rows: **54** dataset-wide (flagged, not errors — chunk empty at that block; the driver's `CHUNK_EMPTY_ROWS: 44` stdout stat counts only the final resume slice, not checkpoint-skipped rows). `ACC_FROZEN_ROWS: 0`.
- Block range: 43,781,657 .. 48,157,721 (covers all spell windows).

## Notes for consumers (10-07/10-08/10-09)

- Accumulators are X64 (`2^64` scale), uint128 wraparound semantics — diff via `Panoptic.Premium.accDelta` (`diffMod 128`) only.
- `at_tick` column: the stored-value sentinel `8388607` would mark non-extrapolated reads, but NO row in this dataset uses it — all 8,910 reads pass a real tick (extrapolated), consistent with reconcile.md flagging all spells `Extrapolated`.
- Wall-clock: rate-limit backoff dominated (~0.25–7 calls/s effective depending on endpoint mood); plan future pulls with generous margins.

## Anti-fabrication review (2026-07-26, two independent reviewers)

- **Live provenance (Reviewer A): CLEAN.** 8 rows re-read against Base archive at the same blocks — 32/32 integers exact; 4 golden-fixture readings reproduced byte-identical; reconcile CLI re-run → byte-identical errors CSV and verdict block; 3 subgraph ground-truth burns match.
- **Offline forensics (Reviewer B): CLEAN.** All 61 recon_wei reproduced exactly in independent Python from committed artifacts; distribution stats recompute exactly; gate logic single-commit, unchanged across results; no planted literals.
- **Known limitation (recorded, mitigated):** `truth_wei` is fetched live from the subgraph at reconcile time and materialized only in `reconcile-errors.csv` (the output). Mitigations: A re-queried 3 burns live (exact match); the truth/premium_usd ratio against the phase-9-committed `panel.csv` sits in a tight plausible ETH-price band across 55 tokenIds; 53/61 truths equal wei-exact integer computations over the committed accumulator rows.
- Corrections applied above per the reviews: cycle-6 completion date, dataset-wide empty-chunk count (54, not the slice-local 44), and the unused sentinel wording.
