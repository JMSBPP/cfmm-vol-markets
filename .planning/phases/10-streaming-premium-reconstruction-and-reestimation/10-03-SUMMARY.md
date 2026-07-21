---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 03
subsystem: chain-access
tags: [block-index, binary-search, interpolation, epoch, hourly, rpc-throughput, csv-cache, haskell, offline-tests]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 02
    provides: "Chain.Rpc.ethGetBlockByNumber / BlockHeader / RpcEnv (single JSON-RPC transport, fail-loud, retry/backoff)"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 01
    provides: "the HOURLY re-scope (2832 in-window hourly boundaries, not 119 daily) and Panel.Build.epochOfSeconds/hourlyEpoch alongside the untouched dailyEpoch"
provides:
  - "Chain.BlockIndex: epoch<->block map via interpolation-assisted, postcondition-asserted monotone search over eth_getBlockByNumber, CSV-cached and resumable (EpochBlock, findBlockAtOrAfter, buildBlockIndex/buildBlockIndexWith, loadBlockIndex/writeBlockIndex/appendBlockIndexRow, blockForEpoch, epochBlockMap; pure stepSearch/bisectFirstAtOrAfter core)"
  - "notes/structural-econometrcics/data/epoch-blocks.csv: the materialised HOURLY epoch->boundary-block map, 2832 rows over blocks 43,782,127..48,877,927, monotone, round-trip floor(ts/3600)==epoch on every row"
  - "notes/structural-econometrcics/data/rpc-throughput-probe.md: the measured answer to RESEARCH Open Question 3 (200/200 OK, 0 429, 7.24 calls/s)"
  - "the block-index CLI subcommand (build + --probe N throughput mode)"
affects: [10-04, 10-05, 10-06, 10-09]

# Tech tracking
tech-stack:
  added:
    - "directory (tests.unit) — getTemporaryDirectory/removeFile for the offline temp-file build+resume spec"
  patterns:
    - "Single search algorithm shared by a pure driver and the live driver via a factored `stepSearch` step function — the pure `bisectFirstAtOrAfter` and IO `findBlockAtOrAfterWith` can never diverge"
    - "Interpolation-assisted bisection over near-uniform block timestamps converges in ~2 calls/epoch (measured 5666 calls for 2832 boundaries), while the asserted postcondition ts(b)>=target>ts(b-1) keeps it correct on irregular block times"
    - "The epoch rule is imported (Panel.Build.epochOfSeconds), never re-derived — boundary instant = epoch*epochSeconds; the 09-05 40587-offset trap stays closed"
    - "Streaming + resumable index build: each row appended the instant it is found; a partial CSV is loaded and its epochs skipped, so a multi-thousand-call run resumes instead of restarting"

key-files:
  created:
    - "econometrics/src/Chain/BlockIndex.hs"
    - "econometrics/test/Chain/BlockIndexSpec.hs"
    - "notes/structural-econometrcics/data/epoch-blocks.csv"
    - "notes/structural-econometrcics/data/rpc-throughput-probe.md"
  modified:
    - "econometrics/app/Main.hs"
    - "econometrics/package.yaml"
    - "econometrics/test/Spec.hs"

key-decisions:
  - "Index built over the 2832 IN-WINDOW HOURLY boundaries (hourly re-scope), not the 119 daily epochs the plan text was drafted against; the hourly set is derived by intersecting the block-window timestamps with the hourly grid and cross-checked against variance.csv's daily range."
  - "buildBlockIndex/findBlockAtOrAfter parameterized by epochSeconds and by the block window so daily and hourly grids share one implementation and the offline spec can drive the full build+resume path against a pure oracle."
  - "Interpolation-assisted (not naive) bisection: uses actual fetched timestamps to guess the midpoint, clamped strictly inside the bracket so it terminates on any monotone oracle; cut the build to 2.0 calls/epoch."

patterns-established:
  - "Any chain-touching module keeps its costly search core pure and monad-agnostic (stepSearch) so the offline spec exercises the exact production algorithm with zero network."

requirements-completed: [CTX-PANEL2, CTX-FEE]

# Metrics
duration: ~28m
completed: 2026-07-21
---

# Phase 10 Plan 03: Epoch↔Block Index + RPC Throughput Probe Summary

**`Chain.BlockIndex` maps every HOURLY epoch boundary to its first Base block by interpolation-assisted, postcondition-asserted monotone search over `eth_getBlockByNumber` (no 2-second-block assumption), CSV-cached and resumable; the live build materialised all 2832 in-window hourly boundaries (blocks 43,782,127..48,877,927) in 5,666 calls, and the 200-call throughput probe answered RESEARCH Open Question 3 at a clean 7.24 calls/s, 0 errors, 0 429s.**

## Performance

- **Duration:** ~28 min (incl. a ~13-min live 2832-boundary build streamed in the background)
- **Started:** 2026-07-21T12:11:27Z
- **Completed:** 2026-07-21T12:39:19Z
- **Tasks:** 2 (Task 1 TDD/offline; Task 2 CLI + live build + probe)
- **Files modified:** 7 (4 created, 3 modified)

## Accomplishments

- **Built the index every downstream accumulator read is keyed on.** `Chain.BlockIndex` finds, for each epoch, the FIRST block whose timestamp is `>= epoch * epochSeconds`, converging by interpolation-assisted bisection over the actual block timestamps and asserting `ts(b) >= target && ts(b-1) < target` against freshly fetched headers before accepting any row. RESEARCH's forbidden "assume 2s blocks" shortcut is impossible: the offline spec drives the real algorithm against a deliberately irregular 1s/4s-gap oracle.
- **Honoured the single epoch rule.** The boundary instant is `epoch * epochSeconds` and the round-trip check imports `Panel.Build.epochOfSeconds`; the module never writes its own `floor(ts / width)`. Every one of the 2832 materialised rows satisfies `floor(block_timestamp / 3600) == epoch`.
- **Made the build resumable.** Rows are appended to `epoch-blocks.csv` the instant they are found; a re-run loads the CSV and probes only the missing epochs. Proven offline (temp file, call-counted oracle) and relied on for the live run.
- **Answered RESEARCH Open Question 3 with a measured number.** The 200-call probe sustained 7.24 calls/s with 0 errors and 0 429s across the estimation window; report written to `notes/.../rpc-throughput-probe.md` for 10-06's go/no-go.
- **Materialised the map.** `epoch-blocks.csv`: 2832 monotone hourly rows, blocks 43,782,127..48,877,927, built in 5,666 `eth_getBlockByNumber` calls (2.0 calls/epoch).

## Task Commits

1. **Task 1: `Chain.BlockIndex` — bisected, CSV-cached epoch/block map (TDD, offline)** — `a8aebeb` (feat)
2. **Task 2: block-index CLI, live hourly index build, RPC throughput probe** — `b73faff` (feat)

_TDD note: as in 10-02, the Haskell RED/GREEN collapses to one commit per task — a spec importing a not-yet-existing module fails at COMPILE time, which would leave the suite non-building at a committed RED, so module + spec land together, verified green against the `-m "BlockIndex"` filter before commit._

## Files Created/Modified

- `econometrics/src/Chain/BlockIndex.hs` — the index: `EpochBlock`, pure `stepSearch`/`bisectFirstAtOrAfter`, live `findBlockAtOrAfter(With)`, `buildBlockIndex(With)` (streaming/resumable), `loadBlockIndex`/`writeBlockIndex`/`appendBlockIndexRow`, `blockForEpoch`/`epochBlockMap`, `estimationWindowBlocks`.
- `econometrics/test/Chain/BlockIndexSpec.hs` — 13 offline examples: irregular-oracle exactness, postcondition, live-shaped search, round-trip persistence, full build, resumption, fail-stop.
- `econometrics/app/Main.hs` — `block-index` subcommand: availability re-probe + failover, hourly-set derivation + variance.csv cross-check, streaming build with call counting, and the `--probe N` throughput mode + report writer.
- `econometrics/package.yaml` — registered `Chain.BlockIndexSpec`; added `directory` to `tests.unit`.
- `econometrics/test/Spec.hs` — wired `Chain.BlockIndexSpec.spec`.
- `notes/structural-econometrcics/data/epoch-blocks.csv` — the materialised 2832-row hourly map.
- `notes/structural-econometrcics/data/rpc-throughput-probe.md` — the measured throughput report.

## RPC Throughput

Measured answer to RESEARCH Open Question 3 (does `mainnet.base.org` sustain the bulk archive read?), from a 200-call `eth_getBlockByNumber` burst at evenly spaced blocks across the estimation window:

| metric | value |
|---|---|
| endpoint | `https://mainnet.base.org` (primary; `base.drpc.org` failover unused — primary answered) |
| PROBE_CALLS | 200 |
| PROBE_OK_COUNT | 200 |
| PROBE_ERROR_COUNT | 0 |
| PROBE_429_COUNT | 0 |
| PROBE_ELAPSED_S | 27.630 |
| PROBE_CALLS_PER_S | **7.239** |
| PROJECTED_BULK_MINUTES (RESEARCH 15k, daily-sized) | 34.54 |

**Corroborating figure:** the actual index build issued **5,666** `eth_getBlockByNumber` calls for 2832 boundaries and completed in ~13 min wall — an in-situ effective rate of ~7.3 calls/s, matching the probe.

**Hourly-adjusted projection for 10-06 (READ THIS, do not use the 15k figure blind):** the bulk premium read is `getAccountPremium` per chunk-leg per HOURLY epoch, and the hourly grid has 2832 boundaries (not 119). The RESEARCH 8k–15k figure was sized against the DAILY grid. At the measured 7.24 calls/s:
- 15,000 calls → ~34.5 min;
- a plausible hourly volume of ~30k–60k calls (≈ 2832 epochs × ~10–20 chunk-leg reads) → **~70–140 min** of sustained sequential archive calls on the free endpoint.
- 0 errors / 0 429s over the 200-call burst and 0 over the 5,666-call build says the endpoint tolerates sustained sequential load, but 10-06 should still budget failover/chunking for a multi-hour run and re-probe (the archive-availability assumption is dated ~2026-08-19).

## Decisions Made

- **Index over 2832 hourly boundaries, not 119 daily.** Recorded user-directed re-scope from 10-01; see Deviations.
- **Parameterized the search by `epochSeconds` and by the block window.** Keeps daily and hourly on one implementation and lets the offline spec drive the full build/resume path with no network.
- **Interpolation midpoint (clamped) rather than plain halving.** Exploits Base's near-uniform block time to reach ~2 calls/epoch while staying correct on irregular gaps via the asserted postcondition.

## Deviations from Plan

### Recorded re-scope (user-directed, from 10-01)

**1. [Directed re-scope — HOURLY grid] The index maps 2832 hourly boundaries, not 119 daily epochs**
- **Found during:** Task 1/Task 2 (the plan's `<constants>` and Task-2 acceptance say "119 daily epochs" / "row count == distinct epochs in variance.csv (119)").
- **Why:** 10-01's FINAL DECISION re-scoped the whole phase to HOURLY epochs before any estimation; the panel/variance layers and every downstream read are now hourly (`~2832` boundaries). The plan text predates the acceptance wording being updated for the re-scope.
- **What was done:** the epoch grid is HOURLY (`epochSeconds = 3600`, boundary instant `epoch * 3600`), the round-trip check uses `Panel.Build.epochOfSeconds 3600`, and the in-window hourly set (492876..495707 = 2832) is derived by intersecting the block-window timestamps with the hourly grid — matching 10-01's `COVERED_EPOCHS_HOURLY = 2832` exactly. variance.csv's daily epoch range (20536..20654) is read and CROSS-CHECKED against the window (both map to daily 20536..20654), so it still is "the source of the epoch set" as the plan intends, just expanded to the resolution the phase now runs on.
- **Effect on acceptance:** "row count == 119" is superseded by "row count == in-window hourly boundaries == 2832"; every other Task-2 acceptance check (header, monotonicity, `--help`, no-home-paths, `## RPC Throughput`) passes as written.

**2. [Rule 3 - Blocking] `buildBlockIndex` needed an `epochSeconds` argument and an injectable block window**
- **Found during:** Task 1.
- **Issue:** the plan's stated signature `RpcEnv -> FilePath -> [Epoch] -> IO (...)` hardcodes neither the epoch width (needed for the hourly boundary instant + round-trip rule) nor a search window; and the offline spec cannot drive the real build against the 43M-block estimation window with a small pure oracle.
- **Fix:** `buildBlockIndex :: RpcEnv -> Int -> FilePath -> [Epoch] -> IO (...)` and an injected-transport/window engine `buildBlockIndexWith fetch window provenance epochSeconds csvPath epochs`. `buildBlockIndex` passes `estimationWindowBlocks`; the spec passes a tiny window + pure oracle.
- **Files:** `econometrics/src/Chain/BlockIndex.hs`.
- **Committed in:** `a8aebeb`.

**3. [Rule 3 - Blocking] `tests.unit` lacked `directory`**
- **Found during:** Task 1 (the resumption spec builds into a real temp file).
- **Fix:** added `directory` to `tests.unit.dependencies`.
- **Files:** `econometrics/package.yaml`.
- **Committed in:** `a8aebeb`.

---

**Total deviations:** 1 directed re-scope (documented) + 2 blocking auto-fixes.
**Impact on plan:** the re-scope is the phase's recorded design; the auto-fixes were necessary to build/test the module. No scope creep — the CLI, CSV schema, provenance banner, availability re-probe, and throughput probe are all exactly as specified.

## Authentication Gates

None. The build and probe use the keyless public Base endpoint; no key was introduced and none is present in any committed file. (Archive availability at the window's earliest block was re-confirmed live via the primary endpoint before the build — the failover was not needed.)

## Issues Encountered

- **Two initial spec failures, both test-side, both fixed before the Task-1 commit:** (a) the first oracle was `O(block-number)` and `buildBlockIndexWith` hardcoded the 43M-block window, so the tiny-block spec produced astronomical timestamps and a 43-million-iteration loop — fixed by making the window injectable and giving the oracle a closed form; (b) a fast-stretch expectation was arithmetically wrong (in a 1s-gap segment `ts(b)-1 == ts(b-1)`, so the first-at-or-after is `b-1`, which the code returned correctly). Neither was a code defect.

## Next Phase Readiness

- **10-04 (read schedule):** consume `epoch-blocks.csv` for the per-hourly-epoch block at which to read `getAccountPremium`. **Use the hourly-adjusted bulk projection in `## RPC Throughput`, not the 15k daily figure** — re-derive call volume against 2832 boundaries × chunk-legs before locking the schedule (this is 10-01's carried-forward action item, now backed by a measured 7.24 calls/s).
- **10-06 (execution):** the throughput report + the in-situ 5,666-call build (0 errors/0 429s) say the free endpoint sustains sequential archive load; still budget failover/chunking for a ~70–140 min run and re-probe archive availability (dated ~2026-08-19).
- **`Chain.BlockIndex.blockForEpoch`** is the lookup every reader should use; the map is monotone and postcondition-checked, so a wrong-block corruption of downstream premia is designed out.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-21*

## Self-Check: PASSED

- All 8 claimed files exist on disk (4 created, 3 modified, + this SUMMARY).
- Both task commits (a8aebeb, b73faff) exist in history.
- No home-absolute paths or keys in the created source/data files.
- Suite 89 → 102/0 (+13 BlockIndex offline examples); epoch-blocks.csv is 2832 monotone rows, round-trip `floor(ts/3600)==epoch` on every row.
