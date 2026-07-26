---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 06
status: complete
completed: 2026-07-22
requirements-completed: [CTX-PREM]
one_liner: "Checkpointed bulk SFPM getAccountPremium read complete: 8910/8910 rows across a 6-cycle resume chain surviving two session limits and one RPC exhaustion, zero data loss, integrity-checked"
key-files:
  created:
    - notes/structural-econometrcics/data/premium-accumulators.csv
    - notes/structural-econometrcics/data/premium-accumulators-lineage.md
    - econometrics/src/Panoptic/ReadDriver.hs
  modified:
    - econometrics/app/Main.hs
commits:
  - d2a5086: "feat(10-06): Panoptic.ReadDriver — checkpointed, resumable, fail-loud bulk read"
  - 15dbff5: "feat(10-06): read-premia CLI — schedule assembly, archive re-probe, dry-run sizing"
  - efc0a62: "feat(10-06): complete bulk SFPM accumulator read — 8910/8910 rows, integrity-checked"
---

# 10-06 Summary — Bulk Accumulator Read

## What shipped
- **`Panoptic.ReadDriver`** — append-per-row checkpointing, resume-by-skipping-cached-rows, retry/backoff with primary→failover, fail-loud abort on exhaustion (never silently narrows the window). Suite 147 → 156/0 at code commit.
- **`read-premia` CLI** — schedule assembly (subgraph mints/burns/legs → 61 spells → deduplicated read schedule), archive re-probe before the pull, `--dry-run` sizing.
- **The dataset**: `premium-accumulators.csv` — **8,910/8,910 scheduled reads** (2,832 hourly boundaries × active chunks + spell-endpoint exact blocks, deduplicated pool-wide to 52 distinct chunks). Full lineage in `premium-accumulators-lineage.md`.

## Budget vs actual
- DISTINCT_READS materialized at **8,910** — far under the 30k–60k envelope (the pool-wide chunk dedup was the lever, exactly as 10-04 predicted).
- Wall time dominated by public-RPC rate limiting, not call count: effective throughput ranged ~0.25–7 calls/s across cycles (final slice: 1,994 calls in 7,963s). `FAILOVER_CALLS: 0` on the completing slice.

## Integrity (verified 2026-07-22, orchestrator)
- 8,910 data rows == schedule; **0 exact-duplicate rows; 0 duplicate read keys**.
- `ACC_FROZEN_ROWS: 0`; `CHUNK_EMPTY_ROWS: 44` (pre-mint blocks, flagged not errored).
- Block range 43,781,657..48,157,721 covers all spell windows.

## Execution story (the checkpointing earned its keep)
Six resume cycles: two executor-session background slices (0→2,208), two cut by session limits (→5,364), one orchestrator-driven CLI slice cut by dual-RPC rate-limit exhaustion after +1,552 rows (fail-loud, as designed), and a final completing slice (→8,910). **Zero redundant calls, zero data loss** across every interruption. One false start ran from the wrong cwd and died on relative-path resolution before writing anything.

## Deviations
- **Completion driven by the orchestrator**, not the executor agent: the executor hit its weekly session limit mid-chain; since the remaining work was pure CLI + bookkeeping, the orchestrator ran the final slices directly and finalized the plan (user-directed "continue feeding the data"). No plan content changed.
- Everything else per plan; the strict-advancement rule was never violated (every slice advanced).
