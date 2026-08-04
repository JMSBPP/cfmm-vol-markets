---
phase: 20-deploy-rig-source-of-truth-import
plan: 01
subsystem: rig-preflight
tags: [upstream-gate, provenance, baseline, foundry, preflight]
requires: []
provides:
  - "offchain/rig/check-upstream.sh — executable BLOCKING upstream gate (exit 0 open / exit 2 blocked)"
  - "offchain/rig/import-ref.txt — the pinned 40-char origin/develop sha every Phase 20 import resolves against"
  - "FORGE-BASELINE.md — cold pre-import forge test + make compile-plank counts with named failing tests"
  - "a working build environment (node_modules + submodules) in which forge build exits 0"
affects:
  - "20-02 (import): consumes offchain/rig/import-ref.txt as the source ref and FORGE-BASELINE.md as the delta baseline"
tech-stack:
  added: []
  patterns:
    - "gate-as-a-command, not a note: the upstream check is re-runnable and re-measures live remote state"
    - "content discriminator over path existence: grep the V2 selector 0x98d950ec, not just the filename"
    - "measure cold, never inherit: prior-phase counts are a sanity reference, re-taken not copied"
key-files:
  created:
    - offchain/rig/check-upstream.sh
    - offchain/rig/import-ref.txt
    - .planning/phases/20-deploy-rig-source-of-truth-import/FORGE-BASELINE.md
  modified: []
decisions:
  - "The gate's sharpest discriminator is the 0x98d950ec selector grep, not path existence — a path check cannot distinguish a merged V2 interface from the stale v1 file"
  - "19-05's 102/18/120 + 11ok/2fail were NOT carried forward; both baselines re-measured cold and the gap explained by the exposure draft now compiling"
  - "Task 2 commits nothing by design — the preflight changes only gitignored/submodule state, so no tracked file moves"
metrics:
  duration_min: 4
  completed: 2026-07-31
---

# Phase 20 Plan 01: Upstream Gate & Cold Pre-Import Baseline Summary

The Phase 20 upstream gate is OPEN — the plank to develop merge landed, `origin/develop` is pinned
at `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d`, `forge build` exits 0 on a pre-import tree, and both
cold baselines (139/5/144 forge tests, 14 ok plank entrypoints) are recorded with every red named.

## Objective

Open (or provably close) the upstream gate, make the tree buildable, and take the cold pre-import
measurements the rest of Phase 20 is judged against.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write and RUN the blocking upstream gate | `826d19e` | `offchain/rig/check-upstream.sh`, `offchain/rig/import-ref.txt` |
| 2 | npm/submodule preflight — forge build exit 0 before any import | (no commit by design) | no tracked file modified |
| 3 | Take the cold PRE-IMPORT forge test and plank compile baselines | `5836985` | `FORGE-BASELINE.md` |

## Task 1 — Gate result: OPEN

The gate was RUN, not merely written. Verbatim output:

    OPEN: origin/develop = 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d carries the V2 rig artifacts (0x98d950ec present).
    recorded -> offchain/rig/import-ref.txt
    gate_exit=0

**The pinned import ref: `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d`** (40 chars, on disk at
`offchain/rig/import-ref.txt`, not carried in prose).

This SUPERSEDES research section 1, which measured the gate CLOSED at 2026-07-31 14:20 UTC with
`origin/develop = 1c41935` and PR #15 OPEN. PR #15 merged in between; the research measurement
expired exactly as the plan anticipated, which is why the gate re-takes it live.

The gate checks all ten required paths on `origin/develop` (five `foundry-scripts/deploy/` files,
`notes/DATA_CONTRACT.md`, `notes/UNITS_AND_SCALES.md`, the handoff, and the two interface `.plk`
files), then applies the V1-vs-V2 content discriminator: `git show` of
`src/interfaces/pos_spec/VolOrderManagerInterface.plk` piped to `grep -q '0x98d950ec'`. All ten
paths present, selector present. `git cat-file -e "$(cat offchain/rig/import-ref.txt):notes/DATA_CONTRACT.md"`
exits 0, confirming the recorded ref actually resolves the artifacts.

The HALT PROTOCOL was NOT triggered. No `20-BLOCKED.md` was written, and none should exist.

## Task 2 — Preflight: forge build exits 0

Research section 7.1 MEASURED `forge build` failing on this branch (`node_modules/` absent, four
tracked test files remap into it). Reproduced and fixed with the exact `develop-gate.yml` sequence:

| Step | Result |
|---|---|
| `npm ci --ignore-scripts` | exit 0, 172 packages added |
| `git submodule update --init lib/panoptic-v2-core` | exit 0 |
| `git -C lib/panoptic-v2-core config submodule.lib/panoptic-helper.update none` | exit 0 |
| `git submodule update --init --recursive` | exit 0, `Skipping submodule 'lib/panoptic-v2-core/lib/panoptic-helper'` |
| `forge build` | **exit 0** (lint notes only, no errors) |

The recursion guard fired visibly — the `Skipping submodule` line is the guard working, not a
warning. `test -d node_modules/@cryptoalgebra` and
`test -f lib/panoptic-v2-core/lib/v4-core/src/PoolManager.sol` both pass.

No tracked file was modified. `git status --porcelain foundry.toml remappings.txt` is empty, so no
other track's territory moved. This is why Task 2 has no commit — its deliverable is an
environment and a recorded exit code, exactly as the plan specified.

## Task 3 — Cold baselines

Both taken cold at 2026-07-31T18:22:10Z, HEAD `826d19ee0b87eeb27bd8efc247bb99040c9e67b3`.

### forge test --via-ir --fuzz-seed 4880

    Ran 47 test suites in 11.16s (51.35s CPU time): 139 tests passed, 5 failed, 0 skipped (144 total tests)

- total: 144, passed: 139, failed: 5, suites: 47

Failing tests, verbatim:

    test/modules/VolOrderManager.fuzz.t.sol:VolOrderManagerFuzzTest test__fuzz__logCreateOrder(uint88,uint24,uint16)
    test/types/pos_spec/SpreadTickAssimetryHelper.t.sol:SpreadTickAssimetryTest test__fuzz__spreadTickAssimetrySplitTick__Valid(uint16,uint24,uint24,int24)
    test/types/pos_spec/SpreadTickAssimetryHelper.t.sol:SpreadTickAssimetryTest test__fuzz__tickFromSplittedTickBucket__Valid(uint16,uint24,uint24,int24,uint24,int24)
    test/types/pos_spec/VolRangeWidth.t.sol:VolRangeWidthTest test__fuzz__volWidthRangeBuildVolRangeWidth_valid(uint24,int24,int24)
    test/types/pos_spec/VolRangeWidth.t.sol:VolRangeWidthTest test__fuzz__volWidthRangeSub_valid(uint24,uint24,uint24)

### make compile-plank

    compile-plank: 14 ok, 0 failed, 0 skipped

- ok: 14, failed: 0, skipped: 0. Zero FAIL lines and zero SKIP lines in the log.

### The measurement trap was avoided

STATE.md [19-05 FINDING] warns that `grep FAIL | grep -c pos_spec` counts the `--dep pos_spec=...`
flag echoed inside `[FAIL: vm.ffi: ...]` lines. Counts here were taken from forge's own summary
line and the identifiers from its `Failing tests:` block — never derived by grepping paths out of
failure text.

## Key Findings

**The 19-05 reference numbers do not transfer, and the gap is explained rather than waved at.**
STATE.md recorded 102/18/120 (44 suites) and 11 ok / 2 failed. Measured here: 139/5/144 (47 suites)
and 14 ok / 0 failed. The dominant cause is the exposure draft: at 19-05
`src/lib/exposure/VegaIssuanceLib.plk` was an uncommitted draft that failed to compile
(`unresolved identifier 'VolOrder'`), propagating through `deployPlank`/FFI to kill 14 suites in
`setUp()` and 2 compile-plank entrypoints. On `feat/rpc-api` that file is TRACKED and compiles —
the `VegaAccount*` and `VegaIssuance*` suites now pass. That accounts for the 2 recovered
entrypoints and most of the 18-to-5 drop. Had the plan copied 19-05's numbers forward, 20-02's
delta would have been computed against a baseline off by 24 tests and 3 entrypoints.

**Four of the five reds are the exact vol-type track failures named in STATE.md [19-05 MEASURED]**
(`SpreadTickAssimetryTest` x2, `VolRangeWidthTest` x2), owned by another track. The fifth,
`VolOrderManagerFuzzTest test__fuzz__logCreateOrder`, is NOT in the 19-05 record and is a
pre-import red specific to this branch state. Recording it now is what prevents 20-02 from
mistaking it for import damage. Zero reds under `test/pos_spec/`.

**The nondeterministic TickVolatility red did not surface.** STATE.md flags
`TickVolatilityLibTest test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess` as appearing on
roughly 1 cold-cache run in 4 at counterexample `2^64-1`. That suite ran 2 passed / 0 failed here.
The `--fuzz-seed 4880` pin is what makes 20-02's re-run comparable; a bare `forge test` would not be.

## Deviations from Plan

None - plan executed exactly as written. No deviation rules were invoked, no auth gates were hit,
and no architectural decision arose.

The one thing worth stating explicitly is a non-deviation: the plan's Task 1 HALT PROTOCOL was a
live branch, not dead text. Research measured the gate CLOSED; it was re-measured OPEN at execution
time. The plan's structure handled the state change without any edit.

## Territory Compliance (CLAUDE.md)

`git status --porcelain src/ test/ Makefile foundry.toml remappings.txt` produces NO output. Every
other track's territory is byte-untouched. The three files created all sit in this workstream's
own territory (`offchain/rig/` and `.planning/`). The five pre-import reds under `test/` are
REPORTED and ATTRIBUTED, never repaired — `test/` belongs to the Solidity-testing session.

## Verification

| Check | Result |
|---|---|
| `bash offchain/rig/check-upstream.sh` | exit 0 |
| `grep -qE '^[0-9a-f]{40}$' offchain/rig/import-ref.txt` | pass |
| `forge build` | exit 0 |
| `FORGE-BASELINE.md` count lines (`total`/`passed`/`failed`/`suites`/`ok`/`skipped`) | all present |
| `grep -c '<' FORGE-BASELINE.md` (no unfilled placeholders) | 0 |
| `git status --porcelain src/ test/ Makefile foundry.toml remappings.txt` | empty |
| `grep -c '0x98d950ec' check-upstream.sh` / `exit 2` / `issue #13` | 3 / 1 / 2 |

## What 20-02 Inherits

1. **Source ref**: `offchain/rig/import-ref.txt` = `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d`. Read
   it from disk; do not retype the sha.
2. **Delta baseline**: 139 passed / 5 failed / 144 total (47 suites) and 14 ok / 0 failed / 0
   skipped. Re-measure with the IDENTICAL commands including `--fuzz-seed 4880`.
3. **A green build**: any post-import `forge build` failure is now unambiguously the import's.
4. **A re-runnable gate**: `check-upstream.sh` can be re-run at any later point to confirm the ref
   still carries the artifacts.

## Requirement Status — RIG-01 deliberately NOT marked complete

`20-01-PLAN.md` frontmatter carries `requirements: [RIG-01]`, but RIG-01 reads: "The four
`foundry-scripts/deploy/` scripts stand up the full rig on a local anvil ... with each script's
printed addresses + selectors + event topic0s captured for the drivers." This plan stood up
nothing on anvil and captured no addresses — it delivered a gate, a pinned ref and two baselines.

RIG-01 spans plans 20-01 through 20-05 and is satisfiable only at phase end. It is left UNCHECKED
in `REQUIREMENTS.md` (traceability row stays `Pending`). Marking it done here would be exactly the
kind of unearned completion claim this project's exit records have had to correct four times.

## Self-Check: PASSED

All four claimed files exist on disk (`offchain/rig/check-upstream.sh`,
`offchain/rig/import-ref.txt`, `FORGE-BASELINE.md`, `20-01-SUMMARY.md`). Both claimed commits
(`826d19e`, `5836985`) resolve in `git log`. `20-BLOCKED.md` correctly does NOT exist, consistent
with the gate having opened.
