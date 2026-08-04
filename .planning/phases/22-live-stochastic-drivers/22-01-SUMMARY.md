---
phase: 22-live-stochastic-drivers
plan: 01
subsystem: infra
tags: [foundry, forge, via-ir, uniswap-v4, plank, sha256-pinning, source-of-truth-import, anvil]

# Dependency graph
requires:
  - phase: 20-deploy-rig-source-of-truth-import
    provides: "import-paths.txt / import-ref.txt / verify-import.sh / IMPORT-PIN.md — the verbatim-import + sha256-pin machinery this plan re-ran against a newer ref"
  - phase: 21-v2-abi-repin
    provides: "the V2 client whose rig-pins.json generatedFrom now follows the new import ref"
provides:
  - "37 source-of-truth paths pinned to origin/develop @ 2039f27 (PR #18), byte-identical and sha256-matched"
  - "foundry-scripts/deploy/InitSwappableRig.s.sol imported verbatim — the only thing that can make a swap enter DynamicFeeHook.beforeSwap"
  - "DeployDynamicFeeHook.s.sol at TICK_SPACING = 20 (F2) — the PoolKey/poolId the rest of Phase 22 must rebuild against"
  - "PROOF that the two vendored v4-core routers (PoolSwapTest, PoolModifyLiquidityTest) compile under --via-ir and emit bytecode artifacts"
  - "FORGE-DELTA.md — a zero-delta forge/plank baseline vs Phase 20's 85/27/112"
  - "22-CROSS-TRACK-FINDINGS.md — the phase's report-never-edit findings file"
affects: [22-02, 22-03, 22-04, 22-05, 22-06, subgraph-v6]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Re-import by `git checkout <ref> -- <path>` per path, never by directory glob (a glob would have pulled notes/VOLATILITY_INSTRUMENTS.md, +753 lines, out of another track)"
    - "IMPORT-PIN.md digest table regenerated wholesale by a shell loop; no digest ever transcribed, and the working-tree and `git show` generations cross-checked for agreement"
    - "A green `forge build` is NOT evidence a file compiled — assert the artifact exists with non-empty bytecode.object AND carries this run's mtime"

key-files:
  created:
    - foundry-scripts/deploy/InitSwappableRig.s.sol
    - .planning/phases/22-live-stochastic-drivers/FORGE-DELTA.md
    - .planning/phases/22-live-stochastic-drivers/22-CROSS-TRACK-FINDINGS.md
  modified:
    - offchain/rig/import-paths.txt
    - offchain/rig/import-ref.txt
    - offchain/rig/check-upstream.sh
    - offchain/rig/rig-pins.json
    - .planning/phases/20-deploy-rig-source-of-truth-import/IMPORT-PIN.md
    - foundry-scripts/deploy/DeployDynamicFeeHook.s.sol
    - src/modules/pos_spec/VolOrderManagerMod.plk

key-decisions:
  - "IMPORT-PIN.md stays THE pin file and keeps verify-import.sh's PIN= constant — a second pin file in the Phase-22 directory would create two sources of truth for one fact"
  - ".planning/issue-17-swappable-rig-SPEC.md (+134 on develop) was NOT imported: the plan's 37-path set is authoritative and every acceptance criterion is stated against the literal 37"
  - "FORGE-DELTA measured with `forge test --via-ir --fuzz-seed 4880` — Phase 20's exact command and seed — not the plan's bare `forge test`, which would not have been comparable"

patterns-established:
  - "Restore a mutated tracked file from the COMMIT, not from an uncommitted working state: commit the task first, then falsify with git checkout"
  - "Verify a 'comment-only' upstream claim by compiling both source revisions and comparing emitted hex, rather than reading the diff"

requirements-completed: []  # DELIBERATELY EMPTY. The plan's frontmatter lists [DRIV-01, DRIV-02]
# because this plan CONTRIBUTES to them, but neither driver has run against a live rig yet — this
# is the import/unblock plan, 1 of 6. Marking them complete here would be a false claim.
# REQUIREMENTS.md keeps both at "Pending", matching Phase 20's precedent (RIG-01 was marked
# complete only at 20-05, the phase's last plan).
requirements-contributed: [DRIV-01, DRIV-02]

# Metrics
duration: 9min
completed: 2026-08-02
---

# Phase 22 Plan 01: Source-of-Truth Re-Import & Router Compile Proof Summary

**37 paths re-pinned to `origin/develop @ 2039f27` by verbatim checkout with a mechanically regenerated sha256 table, and the phase's lowest-confidence assumption — that the two never-before-built v4-core routers compile under `--via-ir` — converted into a measured fact with bytecode artifacts.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-08-02T16:00:48Z
- **Completed:** 2026-08-02T16:10:00Z
- **Tasks:** 2
- **Files modified:** 10 (7 modified, 3 created)

## Accomplishments

- **The measured delta matched the plan EXACTLY** — 2 changed, 1 added, 36 → 37 paths, all three sha256 digests identical to the plan's `<interfaces>` block. No expiry this time.
- **`InitSwappableRig.s.sol` (199 lines) is in the tree**, imported verbatim. It is the only artifact that can make a swap enter `DynamicFeeHook.beforeSwap`; every remaining plan in Phase 22 was unexecutable without it.
- **The routers compile and are PRESENT as artifacts.** `forge build --via-ir` exits 0 and `PoolSwapTest` / `PoolModifyLiquidityTest` carry 10374 / 9370 hex chars of `bytecode.object`, produced by this run.
- **`verify-import.sh` green at 37 and TWICE falsified**, with both restores sha256-identical.
- **Zero forge/plank delta** vs Phase 20 — 85/27/112 across 47 suites and 13 ok / 3 failed, digit-for-digit — with a mechanism for why, not a shrug.
- **The F1 "comment-only" claim was MEASURED, not assumed**: both source revisions compiled to byte-identical hex.

## Task Commits

1. **Task 1: Re-measure the delta, import by checkout, re-pin 37 paths** — `a0b5d94` (chore)
2. **Task 2: Prove the vendored routers compile under --via-ir and record the delta** — `7b2cbf5` (docs)

## Files Created/Modified

- `offchain/rig/import-paths.txt` — 36 → 37 lines; `InitSwappableRig.s.sol` inserted directly after `DeployDynamicFeeHook.s.sol`, grouping preserved
- `offchain/rig/import-ref.txt` — `9f5ccba…` → `2039f278…`, written by `printf` from `git rev-parse`
- `offchain/rig/check-upstream.sh` — one line added to `REQUIRED_PATHS`; nothing else touched, selector reads stay `jq`-sourced
- `offchain/rig/rig-pins.json` — regenerated; **exactly one line changed** (`generatedFrom`)
- `.planning/phases/20-deploy-rig-source-of-truth-import/IMPORT-PIN.md` — header re-pinned + a `Re-pinned:` provenance line; all 37 digest rows regenerated by loop
- `foundry-scripts/deploy/DeployDynamicFeeHook.s.sol` — imported (F2: `TICK_SPACING` 10 → 20)
- `foundry-scripts/deploy/InitSwappableRig.s.sol` — imported, NEW, 199 lines
- `src/modules/pos_spec/VolOrderManagerMod.plk` — imported (F1: comment block only)
- `.planning/phases/22-live-stochastic-drivers/FORGE-DELTA.md` — the zero-delta baseline with attribution
- `.planning/phases/22-live-stochastic-drivers/22-CROSS-TRACK-FINDINGS.md` — 4 findings, none fixed

## The re-measured delta (and whether it matched the plan)

**It matched.** Run at execution start, against a fresh `git fetch`:

```
origin/develop = 2039f2783598866a337115df4a265a75e8842e82
recorded ref   = 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d
SC-1 OK: 36 imported paths content-identical to 9f5ccba… and sha256-matched   <- clean start

=== delta INSIDE pinned set ===
 foundry-scripts/deploy/DeployDynamicFeeHook.s.sol |  5 ++++-
 src/modules/pos_spec/VolOrderManagerMod.plk       | 26 ++++++++++++-----------
 2 files changed, 18 insertions(+), 13 deletions(-)

=== delta over foundry-scripts/ src/ notes/ ===
 foundry-scripts/deploy/DeployDynamicFeeHook.s.sol |   5 +-
 foundry-scripts/deploy/InitSwappableRig.s.sol     | 199 ++++++
 notes/VOLATILITY_INSTRUMENTS.md                   | 753 ++++++++++++++++++++--
 src/modules/pos_spec/VolOrderManagerMod.plk       |  26 +-
```

All three sha256 recomputed from `git show 2039f27:<path>` matched the plan's stated values
character-for-character (`f282e094…`, `d9d4e228…`, `fba060b9…`), as did the ref subject
(`Merge pull request #18 from JMSBPP/feat/plank`).

**Two precision notes** (neither changes any action taken):

1. The plan's `<interfaces>` block attributes `+18 -13` to `VolOrderManagerMod.plk` and `+5 -1` to
   `DeployDynamicFeeHook.s.sol`. Those are the `--stat` *aggregate* (18 insertions / 13 deletions
   across BOTH files) and the *total changed lines* respectively. `--numstat` gives the true
   per-file split: `4 1 DeployDynamicFeeHook.s.sol` and `14 12 VolOrderManagerMod.plk`.
2. The full-tree delta carries two paths the plan's three-directory scope never saw:
   `.planning/issue-17-swappable-rig-SPEC.md` (+134, NEW — the plank track's spec for the very
   script imported here) and `todo.md` (+97). Neither imported; recorded as finding **F22-3**.

## Both falsifications, verbatim

Run against the **committed** Task-1 state so `git checkout` is a genuine restore.

**A — flip the last hex char of the new `InitSwappableRig` digest row (`…75e1` → `…75e0`):**

```
SC-1 FAIL sha256 foundry-scripts/deploy/InitSwappableRig.s.sol: pinned=fba060b988086e3c81d150fefd9e43e1bcbf0ec1b5041917fd8cff8efcbb75e0 actual=fba060b988086e3c81d150fefd9e43e1bcbf0ec1b5041917fd8cff8efcbb75e1
EXIT=1
restored sha256-identical: YES
SC-1 OK: 37 imported paths content-identical to 2039f2783598866a337115df4a265a75e8842e82 and sha256-matched to IMPORT-PIN.md
EXIT=0
```

**B — delete the new `InitSwappableRig` pin row entirely (37 rows → 36):**

```
SC-1 FAIL: no pin row in .planning/phases/20-deploy-rig-source-of-truth-import/IMPORT-PIN.md for foundry-scripts/deploy/InitSwappableRig.s.sol
EXIT=1
restored sha256-identical: YES
SC-1 OK: 37 imported paths content-identical to 2039f2783598866a337115df4a265a75e8842e82 and sha256-matched to IMPORT-PIN.md
EXIT=0
```

**C (beyond plan) — the upstream gate cannot go green on a develop lacking the script.** The
must-have says so; the plan gave no procedure. Executed as a direct existence test against the
superseded ref, which is a real develop that lacks the file:

```
ABSENT on 9f5ccba: foundry-scripts/deploy/InitSwappableRig.s.sol  -> gate would set missing=1 -> exit 2
```

and the real gate against today's develop:

```
OPEN: origin/develop = 2039f2783598866a337115df4a265a75e8842e82 carries the V2 rig artifacts (0x98d950ec present).
recorded -> offchain/rig/import-ref.txt
EXIT=0
```

## The `forge script` env failure, verbatim

With every required variable explicitly unset (`env -u POOL_MANAGER -u HOOK -u TOKEN0 -u TOKEN1`):

```
[3240698] → new InitSwappableRig@0x9f7cF1d1F558E57ef88a59ac3D47214eF25B6A06
  └─ ← [Return] 16075 bytes of code

[2929] InitSwappableRig::run()
  ├─ [0] VM::envAddress("POOL_MANAGER") [staticcall]
  │   └─ ← [Revert] vm.envAddress: environment variable "POOL_MANAGER" not found
  └─ ← [Revert] vm.envAddress: environment variable "POOL_MANAGER" not found

Error: script failed: vm.envAddress: environment variable "POOL_MANAGER" not found
```

The contract deployed into the simulation with 16075 bytes of runtime code and `run()` was
ENTERED — so this is compile + target resolution succeeding, then dying exactly where the plan
predicted. Not a compile error, not "no matching contract".

## The forge / plank numbers, with attribution

Measured with Phase 20's exact command and seed (`forge test --via-ir --fuzz-seed 4880`) so the
comparison is real:

| metric | Phase 20 post-import | now | delta |
|---|---|---|---|
| forge passed / failed / total | 85 / 27 / 112 | **85 / 27 / 112** | **0 / 0 / 0** |
| forge suites | 47 | **47** | 0 |
| `compile-plank` ok / failed | 13 / 3 | **13 / 3** | 0 / 0 |
| `forge build --via-ir` | exit 0 | exit 0 | unchanged |

**Every moved number is attributed — and none moved, for a reason:**

- **F2** is a `constant` in a *deploy script*. `forge test` never executes
  `foundry-scripts/deploy/*.s.sol`, so `TICK_SPACING = 20` reaches no test. It reaches the CHAIN
  only on broadcast — which is exactly why the standing rig is stale and 22-03 must redeploy, and
  why that staleness is invisible in these numbers.
- **F1** is comment-only, **PROVEN by compiling both revisions**: source at `9f5ccba` and source at
  `2039f27` each pushed through the identical `make compile-plank` invocation emit
  `78ca20408a9f7959ac90a5b053fafa1884fc27a0333c96a44c46a05aa19bc88c` — byte-identical. The
  temporary swap was restored byte-identical (`git status --porcelain` on the path: empty).
- **`InitSwappableRig.s.sol`** adds compilation surface and zero tests.

The 27 reds are Phase 20's inventory (causes C1–C4 + P) carried forward unchanged. `test/` belongs
to the Solidity-testing session; nothing was fixed.

## Decisions Made

- **`IMPORT-PIN.md` edited in place; `verify-import.sh`'s `PIN=` constant untouched.** A Phase-22
  pin file would have meant two sources of truth for one fact. A `Re-pinned:` line names Phase 22
  and the superseded ref so the file's history is legible from the file.
- **`.planning/issue-17-swappable-rig-SPEC.md` deliberately NOT imported** despite being
  plank-authored, on-topic, and in a directory (`.planning/`) that the pin set already imports from
  (`rpc-api-volorder-v2-HANDOFF.md`). Every acceptance criterion in 22-01 is stated against the
  literal count **37**; silently adding a 38th path would have made the plan unfalsifiable. Logged
  as F22-3 with the explicit instruction that a later plan should ADD it to `import-paths.txt` and
  re-pin if it wants it.
- **Phase 20's `forge test` command and seed reused verbatim** rather than the plan's bare
  `forge test`. A different seed produces different fuzz outcomes and the whole point of the file
  is a comparison against `85 / 27 / 112`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `git checkout --` on an UNCOMMITTED `IMPORT-PIN.md` destroyed the re-pin**

- **Found during:** Task 1 (first falsification attempt)
- **Issue:** The plan's falsification procedure says "`git checkout` restores exit 0". Run while
  `IMPORT-PIN.md` was still uncommitted, `git checkout --` restored it to **HEAD** — i.e. the OLD
  36-row, `9f5ccba`-header version — silently undoing the entire re-pin. Verified after the fact:
  `grep -c` on digest rows returned **36** and the header read `Merge pull request #15`. (A
  malformed `sed` delimiter meant the mutation itself never applied, so this was caught on a
  no-op run rather than in the middle of a real falsification.)
- **Fix:** Rebuilt the pin file from the same mechanical generation, then **committed Task 1 before
  running either falsification**, which makes `git checkout` a genuine restore-to-the-pinned-state
  and matches the acceptance criterion literally. Both restores subsequently verified
  sha256-identical to the pre-mutation file.
- **Files modified:** `.planning/phases/20-deploy-rig-source-of-truth-import/IMPORT-PIN.md`
- **Verification:** `verify-import.sh` green at 37 before commit; both falsifications exit 1 and
  both restores exit 0 after commit
- **Committed in:** `a0b5d94` (Task 1 commit — the rebuilt file is what was committed)

**2. [Rule 2 - Missing verification] The plan gave no procedure for its own must-have "check-upstream.sh cannot go green on a develop that lacks InitSwappableRig.s.sol"**

- **Found during:** Task 1
- **Issue:** Task 1 step 5 adds the path to `REQUIRED_PATHS`, and the acceptance criteria check
  only `grep -c … = 1`. A grep proves the string is present, never that the gate would actually
  redden. The must-have asserts a *behaviour*.
- **Fix:** Ran the gate's own existence test (`git cat-file -e "$REF:$path"`) against the
  superseded ref `9f5ccba` — a real develop state that lacks the file — confirming it reports
  `ABSENT` and would set `missing=1` → `exit 2`; then ran the real gate against today's develop
  (exit 0). Output quoted above as falsification C.
- **Files modified:** none (measurement only)
- **Verification:** the two runs quoted above
- **Committed in:** `7b2cbf5` (recorded in the summary; no file change)

**3. [Rule 2 - Missing verification] The F1 "compiled hex byte-identical" claim was asserted by research, never measured in this tree**

- **Found during:** Task 2 (writing FORGE-DELTA.md)
- **Issue:** The zero forge/plank delta is only meaningful if F1 really is comment-only. That was a
  research claim. `<standing_corrections>` says to measure predictions rather than inherit them —
  twice-refuted precedent in this workstream.
- **Fix:** Compiled the pre-import source (`git show 9f5ccba:…`) and the post-import source through
  the identical `make compile-plank` invocation and compared the emitted hex. Byte-identical. The
  file was restored byte-identical immediately (`git status --porcelain` on the path: empty), so
  plank-track territory is untouched.
- **Files modified:** none persisted
- **Verification:** `sha256sum` on both hex outputs → `78ca2040…19bc88c` twice; `cmp -s` silent
- **Committed in:** `7b2cbf5` (recorded in FORGE-DELTA.md)

---

**Total deviations:** 3 (1 blocking self-inflicted regression, 2 missing verifications added)
**Impact on plan:** No scope creep. Deviation 1 was recovered before anything was committed;
deviations 2 and 3 turn two asserted must-haves into measured ones.

## Issues Encountered

- **The execution context's "anvil is currently RUNNING" claim is FALSE.** `pgrep -a anvil` is
  empty, `ps aux | grep '[a]nvil'` is empty, and `cast block-number` against
  `http://127.0.0.1:8545` errors with a connection failure. Nothing was blocked (this plan needs no
  chain) but **22-03 must stand a rig up from scratch and must not assume one to `--stop`**.
  Recorded as F22-4; it is the third stale liveness/measurement claim in this workstream (cf.
  21-02's identical finding and 20-01's expired research measurement).
- **`cabal build --enable-tests -j all && cabal test` exits 0 at 66/66**, so the `generatedFrom`
  move broke nothing — which is expected, since `grep -rn 'generatedFrom\|import-ref\|IMPORT-PIN'
  offchain --include='*.hs'` shows only `Rig/Manifest.hs` *decoding* the field, with no check
  pinning its value. The 65 → 66 move is plan **22-02's** in-flight work running in parallel, not
  this plan's; this plan touches no Haskell.
- **`gsd-tools state *` CLOBBERS this project's STATE.md frontmatter — every call, silently.**
  Each of `state advance-plan` / `update-progress` / `add-decision` / `record-session` rewrote the
  header to `milestone: v2.0`, `milestone_name: milestone`, `status: completed`, and reset
  `last_activity` to a stale 20-02 string. The wrong values come from the same bad inference the
  init call reports (`"milestone_version": "v2.0", "milestone_name": "milestone"`) — this repo
  carries several parallel milestone tracks with non-contiguous phase ranges, which the tool
  cannot see. `status: completed` on an in-progress v5.0 is the dangerous one. Restored by hand
  AFTER the last tool call (restoring earlier does not stick — it was clobbered twice). **Anyone
  running these tools in this repo must re-check the STATE.md frontmatter afterwards.**
  `state advance-plan` also errors outright (`Cannot parse Current Plan or Total Plans in
  STATE.md`) because this project's Current Position uses prose, so the position below was written
  by hand. `roadmap update-plan-progress 22` worked correctly (`0/6 Planned` → `1/6 In Progress`).
- **Parallel-plan hygiene held.** `offchain/lib/RealizedVol/Decode.hs` and `offchain/test/Main.hs`
  are dirty from 22-02 and were never staged — both commits here contain only this plan's files.
  `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` and
  `… notes/` are both EMPTY after the import.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

**Unblocked for the rest of Phase 22:**

- `InitSwappableRig.s.sol` is present, pinned, and PROVEN to compile and resolve under `--via-ir`.
  Its documented invocation is
  `forge script foundry-scripts/deploy/InitSwappableRig.s.sol --tc InitSwappableRig --rpc-url local --broadcast --via-ir`
  with `POOL_MANAGER`, `HOOK`, `TOKEN0`, `TOKEN1` from `DeployDynamicFeeHook.s.sol`'s printed
  manifest. No `--ffi`.
- The script prints seven new manifest lines (`swapRouter`, `modifyLiquidityRouter`, tick range,
  liquidity, probe deltas, timepoint ts before/after) — `Rig/Manifest.hs` will need the two router
  keys.

**Carried into 22-03 as hard constraints:**

- **Redeploy is mandatory.** F2 moved `TICK_SPACING` 10 → 20, which changes the `PoolKey` hash and
  therefore the poolId. Any previously recorded rig is stale by construction, and no anvil is
  currently running.
- **G1 is a timestamp guard, not a block guard** (F22-1). The driver must advance the clock ≥1s
  between writes it expects recorded, and E3 — never the swap count — is ground truth.
- **G4: mint no second range.** The script mints exactly one full-range position and its own header
  says so; the cheat domain is ticks strictly inside `[−887260, +887260]`.
- `PoolSwapTest.swap` must not be nested in an outer unlock (it requires `deltaBefore == 0`).

---
*Phase: 22-live-stochastic-drivers*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 11 claimed files and both build artifacts exist on disk; both task commits (`a0b5d94`,
`7b2cbf5`) are reachable in `git log`; `verify-import.sh` re-run at self-check time exits 0 at
37 paths.
