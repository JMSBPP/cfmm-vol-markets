---
phase: 22-live-stochastic-drivers
plan: 03
subsystem: infra
tags: [anvil, foundry, uniswap-v4, rig-lifecycle, determinism, haskell, falsification]

# Dependency graph
requires:
  - phase: 22-live-stochastic-drivers
    plan: 01
    provides: "foundry-scripts/deploy/InitSwappableRig.s.sol imported verbatim at 2039f27, with its routers PROVEN to compile under --via-ir"
  - phase: 20-deploy-rig-source-of-truth-import
    provides: "deploy-rig.sh / verify-rig.sh / Rig.Manifest / the SC-5 byte-identical-manifest property this plan re-measured"
provides:
  - "A SWAPPABLE rig from one command: 6 deploy scripts, 9 contracts, one full-range position, and a probe swap PROVEN to have written a hook timepoint (1700000003 -> 1700000010)"
  - "A deterministic chain clock origin: anvil --silent --timestamp 1700000000, so the chain and the RealizedVolatilityMod seed share one origin"
  - "rig-manifest.json carrying PoolSwapTest + PoolModifyLiquidityTest, both cross-checked broadcast-vs-console, both MANDATORY in Rig.Manifest"
  - "verify-rig.sh Probe 6: both routers' manager() must equal the manifest PoolManager -- a fault a bytecode probe provably cannot see"
  - "SC-5 RE-MEASURED under the new clock: normalised sha256 e0f01eb5fc3545f7d1a7066a95a42c62c271aa333bf955fd6359d286abfeec44"
  - "A test suite that actually honours RIG_MANIFEST -- previously it silently ignored it"
affects: [22-04, 22-05, 22-06, subgraph-v6]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "anvil --timestamp anchors the ORIGIN only; the clock still advances with wall time, so a driver must read the chain head"
    - "A rig-level acceptance check OWNS the script's internal require: parse the console line and assert it in the lifecycle script, the way `seeded : true` already was"
    - "To isolate a binding probe, CONSTRUCT the exact fault on chain (a second, real, live router bound to the wrong manager) rather than mutating a manifest entry into a different contract type"

key-files:
  created:
    - .planning/phases/22-live-stochastic-drivers/deferred-items.md
  modified:
    - offchain/rig/deploy-rig.sh
    - offchain/rig/verify-rig.sh
    - offchain/rig/README.md
    - offchain/lib/Rig/Manifest.hs
    - offchain/lib/VolOrder/Decode.hs
    - offchain/test/Main.hs

key-decisions:
  - "Only the two router ADDRESSES enter the manifest; tick range, liquidity and probe deltas stay on the console. Every mandatory manifest field is a field Rig.Manifest refuses to load without, and a field no consumer reads would weaken that meaning."
  - "The two stale tickSpacing comments were REWRITTEN to record the resolution (PR #18 / 2039f27 / F2), not deleted -- but phrased so the literal stale claim string does not survive a grep."
  - "The RIG_MANIFEST defect was FIXED in this plan rather than logged, because the plan's own falsification could not run without it. The RIG_PINS analogue was logged as D22-1: pins_file is consumed in PURE message code and rig-pins.json is committed, so git checkout is already its falsifier."

patterns-established:
  - "Commit the task BEFORE falsifying, so `git checkout` is a genuine restore (22-01's lesson, applied)"
  - "When a plan's predicted discriminator does not redden, the CHECK is the defect -- fix it in the task and quote both the before and after"

requirements-completed: []  # DELIBERATELY EMPTY. The plan's frontmatter lists [DRIV-01, DRIV-02]
# because this plan CONTRIBUTES to them. Neither driver has RUN against the live rig yet -- this
# plan builds the rig they will run against (3 of 6). Phase 20's precedent: RIG-01 was marked
# complete only at 20-05, the phase's last plan.
requirements-contributed: [DRIV-01, DRIV-02]

# Metrics
duration: 13min
completed: 2026-08-02
---

# Phase 22 Plan 03: Swappable Rig Lifecycle Summary

**One command now takes a machine with no anvil to a pool that can actually be swapped — six
deploy scripts, nine contracts, a genesis clock shared with the vol seed, and a probe swap whose
`1700000003 -> 1700000010` is the rig's own proof that `DynamicFeeHook.beforeSwap` writes
timepoints — and the plan's own falsification procedure exposed a test suite that had been
silently ignoring `RIG_MANIFEST`, which is fixed here rather than noted.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-08-02T16:25:41Z
- **Tasks:** 3 (plus one in-task auto-fix commit)
- **Files modified:** 7 (6 modified, 1 created)

## Task Commits

1. **Task 1: deterministic clock origin + the InitSwappableRig step** — `9280260` (feat)
2. **Task 2: nine mandatory contracts, router binding probe, F2-resolved comments** — `0141ce7` (feat)
3. **Auto-fix: the test suite ignored `RIG_MANIFEST`** — `585a2c2` (fix)
4. **Task 3: SC-5 re-measured; README's three stale spots fixed** — `5a0f9e7` (docs)

## The measured facts this plan produced

### The probe swap (Task 1 / the whole point of the plan)

```
  swapRouter            : 0x9A676e781A523b5d0C0e43731313A708CB607508
  modifyLiquidityRouter : 0x0B306BF915C4d645ff596e518fAf3F9669b97016
  tickLower             : -887260
  tickUpper             : 887260
  liquidity             : 1000000000000000000000
  probe delta0          : -1000000
  probe delta1          : 999899
  timepoint ts before   : 1700000003
  timepoint ts after    : 1700000011
...
  probe swap wrote a timepoint: 1700000003 -> 1700000011
```

Across five from-scratch runs in this session the pair was `1700000003 -> 1700000010` four times
and `-> 1700000011` once. The BEFORE value is stable (the hook is seeded at deploy time and the
deploy sequence is deterministic); the AFTER value carries one second of wall-clock jitter,
because `--timestamp` fixes the origin and not the rate. Both are strictly increasing, which is
the only thing asserted.

### The genesis clock

```
$ cast block --rpc-url local 0 --field timestamp
1700000000
```

Equal to `INIT_TS`, the same literal that seeds `RealizedVolatilityMod`. At the end of this plan
the chain head was `1700000027` at block 13 — i.e. 27 seconds of drift from origin across a
deploy plus a `cabal run`. **This is the number 22-05's driver must respect: read the head, never
assume `INIT_TS`.**

### The manifest

```
$ jq -r '.contracts | keys | length' offchain/rig/rig-manifest.json
9
$ jq -r '.contracts.PoolSwapTest, .contracts.PoolModifyLiquidityTest' …
0x9a676e781a523b5d0c0e43731313a708cb607508
0x0b306bf915c4d645ff596e518faf3f9669b97016      # 9 addresses, 9 distinct
$ jq -r '.pool.tickSpacing' …
20                                              # THE proof the ts=10 rig was rebuilt, not patched
$ jq -r '.generatedFrom' …  == cat offchain/rig/import-ref.txt
2039f2783598866a337115df4a265a75e8842e82
$ cast code <PoolSwapTest> --rpc-url local | wc -c
10073
```

### SC-5, RE-MEASURED (not inherited)

Two from-scratch `deploy-rig.sh` runs after both the `--timestamp` change and the sixth script:

```
$ diff -u rig-run1.json rig-run2.json        # (jq -S 'del(.generatedAt)')
                                             # EMPTY, exit 0
$ sha256sum rig-run1.json rig-run2.json
e0f01eb5fc3545f7d1a7066a95a42c62c271aa333bf955fd6359d286abfeec44  rig-run1.json
e0f01eb5fc3545f7d1a7066a95a42c62c271aa333bf955fd6359d286abfeec44  rig-run2.json

generatedAt run1: 2026-08-02T16:35:12Z
generatedAt run2: 2026-08-02T16:35:21Z      # DIFFER -> run 2 really regenerated
```

**No field moved.** Both router addresses and `pool.poolId` are stable across from-scratch runs —
the routers are plain `new` under `startBroadcast` from a deterministic nonce sequence, so they
inherit the same determinism the other seven addresses already had.

### The router `manager()` accessor

`manager`, READ out of `lib/panoptic-v2-core/lib/v4-core/src/test/PoolTestBase.sol:16`
(`IPoolManager public immutable manager;`), which both `PoolSwapTest` and
`PoolModifyLiquidityTest` extend. Not guessed, and no bytecode-only fallback was used.

### The clean-machine sequence, run top to bottom

| step | exit |
|---|---|
| `npm ci --ignore-scripts` | 0 |
| `git -c submodule.lib/panoptic-helper.update=none submodule update --init --recursive` | 0 |
| `forge build` | 0 |
| `offchain/rig/check-upstream.sh` | 0 |
| `offchain/rig/verify-import.sh` | 0 (`SC-1 OK: 37 imported paths … 2039f278…`) |
| `offchain/rig/deploy-rig.sh` | 0 (`probe swap wrote a timepoint: 1700000003 -> 1700000010`) |
| `offchain/rig/verify-rig.sh` | 0 (`SC-2 OK: 9 contracts live`) |
| `cabal build --enable-tests -j all` | 0, zero warnings |
| `cabal test` | 0, `68/68 checks passed` |
| `cabal run cfmm-replicationPlank-rpc-api` | 0 |

## THE HEADLINE: a fourth predicted discriminator refuted — and this one broke the plan's own procedure

`<standing_corrections>` warned that predicted mutant discriminators have been refuted three times
in this workstream. This is the fourth, and the worst kind: it was not a check that failed to
catch a mutant, it was a **falsification mechanism that could not be applied at all**.

The plan's Task-2 falsification is, verbatim:

> copy the manifest, delete `.contracts.PoolSwapTest` from the copy, and run
> `RIG_MANIFEST=<copy> cabal test` — `sc3_load_succeeds` must FAIL naming the missing contract.

Applied exactly as written:

```
=== FALSIFICATION 1a: RIG_MANIFEST=<copy without PoolSwapTest> cabal test ===
68/68 checks passed
EXIT=0
```

**GREEN.** `offchain/test/Main.hs` resolved the manifest through a hardcoded constant

```haskell
manifest_file :: FilePath
manifest_file = "offchain/rig/rig-manifest.json"
```

so every check read the REAL nine-contract manifest and the environment variable was discarded.
Meanwhile `verify-rig.sh` DOES honour `RIG_MANIFEST` (it is documented in its own header as the
falsifiability hook), and every `Rig.Manifest` error message ends with *"Override the path with
the RIG_MANIFEST environment variable."* Two halves of one rig verification disagreeing about
what an override means — and the Haskell half could not be pointed at any manifest, for any
falsification, ever.

**FIXED, not noted** (`585a2c2`): `manifest_file :: IO FilePath`, resolved through
`Rig.Manifest.rig_manifest_path`, with the three consumers (`sc3_load_succeeds`,
`sc3_corrupted_manifest_fails`, `rpin05_capture_is_present_and_fresh`) binding it locally. The
haddock on the new definition records the measurement so nobody reverts it as a stylistic change.

The same falsification, re-run against the fixed suite:

```
=== FALSIFICATION 1a (re-run after the fix) ===
FAIL sc3_load_succeeds: load_rig_from failed on the real files: user error (Rig.Manifest: the rig
address manifest decoded but is INCOMPLETE.
  resolved path     : …/manifest-no-swaprouter.json
  missing contracts : PoolSwapTest
  present contracts : DynamicFeeHook, DynamicFeeMod, PoolManager, PoolModifyLiquidityTest,
                      PriceSetterHook, PriceSetterPoolManager, RealizedVolatilityMod,
                      VolOrderManagerMod
  A rig missing one of its contracts is a broken rig, not a rig with a zero address.
…
66/68 checks passed
2 FAILED: rpin05_capture_is_present_and_fresh, sc3_load_succeeds
EXIT=1
```

Two checks redden, both naming `PoolSwapTest`. `rpin05` reddening as well is honest collateral —
it loads the same manifest through the same loader.

## Every other falsification, verbatim

### Task 1 — the probe assertion (`-gt` → `-lt`)

Run against the **committed** Task-1 state, so `git checkout` is a genuine restore.

```
=== re-running with the mutated assertion ===
FATAL: probe swap did not advance the hook's timepoint clock (1700000003 -> 1700000011).
       The rig is NOT proven swappable: beforeSwap either did not run or hit the
       G1 same-second no-op. E3 is the ground truth of what landed, never the swap count.
EXIT=1
```

Restored and re-run:

```
  probe swap wrote a timepoint: 1700000003 -> 1700000010
RIG UP  chainId=31337  ref=2039f278…
EXIT=0
```

`git status --porcelain offchain/rig/deploy-rig.sh` empty after the restore.

### Task 2 — `verify-rig.sh` against a manifest missing a router

```
SC-2 FAIL: …/manifest-no-swaprouter.json has no contracts.PoolSwapTest -- the InitSwappableRig
           step did not run, so the pool has NO liquidity and no unlock-callback router. Re-run:
           bash offchain/rig/deploy-rig.sh
VERIFY EXIT=1
```

The first attempt at this produced `SC-2 FAIL: PoolSwapTest at null did not answer manager()` — a
`jq` miss rendering as the string `null` and being handed to `cast call`. Fixed in the same
commit: Probe 6 now names the missing-key fault instead of the address fault.

### Task 2 — Probe 6, the fault a bytecode probe cannot see

The plan asked for one falsification here; three were run, because the first two do not isolate
the probe and saying so is the point.

**2a (the plan's literal instruction) — the `PoolSwapTest` entry points at the other live PoolManager:**

```
PASS bytecode PoolSwapTest: 0xb7f8bc63…f84f5e has 17151 bytes of code      <- Probe 1 PASSES
SC-2 FAIL: PoolSwapTest at 0xb7f8bc63…f84f5e did not answer manager()
VERIFY EXIT=1
```

**2b (sharper, and an HONEST NEGATIVE) — swap `.contracts.PoolManager` for the other manager:**

```
SC-2 FAIL: DynamicFeeHook poolManager()=0x5fc8d326…f875707 but the manifest PoolManager is
           0xb7f8bc63…f84f5e
VERIFY EXIT=1
```

This reddens at **Probe 5**, not Probe 6 — it cannot isolate the new probe, because the hook's own
binding check fires first. Recorded rather than presented as a success.

**2c — the ISOLATION.** A second, real `PoolSwapTest` was deployed on the standing rig, bound to
the `PriceSetterPoolManager`, and the manifest copy pointed at it. This constructs the exact fault
the probe exists for: a router that is live, has bytecode (5035 bytes — byte-for-byte the same
size as the genuine one), and answers `manager()` correctly, with the wrong answer.

```
PASS bytecode PoolSwapTest: 0xa85233c6…b32338f has 5035 bytes of code
PASS orderCount …            PASS seeded …            PASS owner …
PASS poolManager DynamicFeeHook: … == manifest contracts.PoolManager
PASS poolId DynamicFeeHook:      … == manifest pool.poolId
SC-2 FAIL: PoolSwapTest manager()=0xb7f8bc63…f84f5e but the manifest PoolManager is 0x5fc8d326…f875707
           A router bound to the OTHER PoolManager is live and useless.
VERIFY EXIT=1
```

**Every one of Probes 1–5 passes. Only Probe 6 fires.** That rogue router was wiped by the next
from-scratch `deploy-rig.sh`, and the rig standing at exit is clean.

## Decisions Made

- **Only the two router addresses go into the manifest.** Tick range, liquidity and probe deltas
  stay on the console and in `/tmp/rig-logs/06-swappable.log`. They are proof the script produced,
  not values any driver reads, and every mandatory manifest field is a field `Rig.Manifest`
  refuses to load without — adding a field no consumer reads would dilute that. Recorded as a
  comment above the `jq -n` emitter.
- **The extraction of `HOOK`/`PM`/`CURRENCY0`/`CURRENCY1` was MOVED, not duplicated**, to just
  after the 4th script, together with `console_field`. `POOL_ID`, `TICK_SPACING` and every Step-8
  cross-check stayed put; `B_HOOK` is now defined once, in Step 5a, and Step 7's existence loop
  still covers it.
- **`FS=(… --ffi …)` untouched.** The sixth script's flags are written out inline precisely so the
  difference is visible at the call site rather than hidden behind a shared array.
- **The two stale `tickSpacing` comments were rewritten, not deleted** — the record of a resolved
  discrepancy outlives the discrepancy. They now name PR #18 / `2039f27` / F2, and `Decode.hs`
  adds the consequence the original never stated: the `PoolKey` hash and therefore the `poolId`
  moved with `TICK_SPACING`, so any manifest recorded before that ref is stale **by
  construction**, not merely mislabelled. Both were phrased so a grep for the literal stale claim
  finds nothing.
- **`RIG_PINS` deferred, not fixed** (D22-1). `pins_file` is consumed inside PURE message-building
  code at three sites, so lifting it is a wider refactor than the fault measured; and
  `rig-pins.json` is COMMITTED, so `git checkout` is already a working falsifier for it (that is
  how Phases 20 and 21 actually falsified the pin checks). The gap is a documentation/mechanism
  mismatch, not a blind check.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The test suite ignored `RIG_MANIFEST`, so the plan's own falsification was a no-op**

- **Found during:** Task 2 (falsification 1a)
- **Issue:** `manifest_file` was a hardcoded `FilePath` constant. `RIG_MANIFEST=<broken copy>
  cabal test` returned `68/68 checks passed`, exit 0 — the suite silently read the real manifest.
  `verify-rig.sh` and every `Rig.Manifest` error message both advertise the override.
- **Fix:** `manifest_file :: IO FilePath = rig_manifest_path`; the three consumers bind it locally
  as `mf`; `rig_manifest_path` added to the `Rig.Manifest` import list. The haddock records the
  measurement.
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** the same falsification now exits 1 at `66/68` with `2 FAILED:
  rpin05_capture_is_present_and_fresh, sc3_load_succeeds`, both naming `PoolSwapTest`. Clean
  `cabal test` still `68/68`, zero `-Wall` warnings.
- **Committed in:** `585a2c2`

**2. [Rule 2 - Missing error handling] Probe 6 handed `jq`'s string `null` to `cast call`**

- **Found during:** Task 2 (falsification 1b)
- **Issue:** A manifest without the router key produced `SC-2 FAIL: PoolSwapTest at null did not
  answer manager()` — a message about an address for a fault that is about a manifest. Exit code
  was correct; the diagnosis was not.
- **Fix:** an explicit missing/empty-key guard naming the real cause (the `InitSwappableRig` step
  did not run) and the command that fixes it.
- **Files modified:** `offchain/rig/verify-rig.sh`
- **Committed in:** `585a2c2`

**3. [Rule 2 - Missing verification] The plan's Probe-6 falsification does not isolate Probe 6**

- **Found during:** Task 2 (falsification 2)
- **Issue:** Pointing a router entry at the `PriceSetterPoolManager` fails Probe 6 for the wrong
  reason (a `PoolManager` has no `manager()`), and swapping `.contracts.PoolManager` reddens
  Probe 5 first. Neither demonstrates the fault the probe was written for.
- **Fix:** deployed a second, genuine `PoolSwapTest` bound to the other manager and pointed a
  manifest copy at it. Probes 1–5 all PASS, only Probe 6 fires. Measurement only; the rogue router
  was wiped by the next from-scratch deploy.
- **Files modified:** none
- **Committed in:** recorded here; no file change

**4. [Rule 2 - Missing verification] Three README acceptance greps collided with the plan's own "do not delete the record" instruction**

- **Found during:** Tasks 2 and 3
- **Issue:** The plan requires `grep -c 'tickSpacing = 10'` = 0, `grep -c 'status reverted'` = 0,
  `grep -c 'cabal build -j all'` = 0 and `grep -c 'seven contracts'` = 0, while also requiring the
  historical record be KEPT. A history paragraph that quotes the stale claim verbatim satisfies
  the second and violates the first.
- **Fix:** every history paragraph rephrased so the meaning survives and the literal stale string
  does not ("a deployed pool whose tick spacing was 10", "this section used to say the order
  reverted", "dropping it leaves the test component unconfigured", "the remaining seven
  deployments"). All four greps are now 0 with the record intact. This is the correct reading: the
  greps exist so a future reader searching for the stale claim finds nothing.
- **Files modified:** `offchain/lib/VolOrder/Decode.hs`, `offchain/test/Main.hs`,
  `offchain/rig/README.md`
- **Committed in:** `0141ce7`, `5a0f9e7`

**5. [Rule 1 - Stale value] The README would have inherited 21-05's `2 succeeded / 0 failed`**

- **Found during:** Task 3 (running the clean-machine sequence)
- **Issue:** The plan instructs writing 21-05's measured batch result into the README. Re-measured
  today against this rig it is **`7 succeeded, 0 failed (of 7)`**, not 2/0.
- **Fix:** the README records today's measurement and attributes it to 22-03. Also added, from the
  same run: the demo's price writes go to the `PriceSetterPoolManager`, NOT the `DynamicFeeHook`
  pool — so `cabal run` still does not exercise the cheat-swap path, and `deploy-rig.sh`'s probe
  swap remains the only thing on the rig that makes the hook write.
- **Files modified:** `offchain/rig/README.md`
- **Committed in:** `5a0f9e7`

---

**Total deviations:** 5 (1 bug, 1 missing error handling, 2 missing verifications, 1 stale value)
**Impact on plan:** No scope creep. Deviation 1 was load-bearing — without it the plan's central
Task-2 acceptance criterion was unverifiable.

## Issues Encountered

- **`pgrep -a anvil` was EMPTY at execution start**, as 22-01 predicted (F22-4). The rig was stood
  up from scratch; nothing was `--stop`ped, and nothing assumed a standing chain. This is the
  fourth stale-liveness datapoint in this workstream and the first time a plan was written to
  survive it.
- **`cabal test` remains chain-independent.** `grep -cE 'cast call|HttpProvider|8545'
  offchain/test/Main.hs` = **0** after all edits. The `RIG_MANIFEST` fix touches path resolution
  only; no check opens a socket.
- **Territory clean.** `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml
  remappings.txt notes/` EMPTY throughout. Pre-existing dirt (`lib/forge-std`,
  `offchain/spec/types.md`, and five untracked root files) was present at session start and was
  never staged.
- **`gsd-tools state *` clobbers this repo's STATE.md frontmatter.** Third occurrence. Restored by
  hand after the last tool call.

## Rig state at exit — LEFT RUNNING for 22-04

```
anvil pid   1016807      (anvil --silent --timestamp 1700000000)
block       13
head ts     1700000027
genesis ts  1700000000
manifest    9 contracts, pool.tickSpacing 20
poolId      0x00c35757198030cc0408784a49b5de3ee9c0fad958b0564592e118604b49ab8a
PoolSwapTest             0x9a676e781a523b5d0c0e43731313a708cb607508
PoolModifyLiquidityTest  0x0b306bf915c4d645ff596e518faf3f9669b97016
```

Stop with `bash offchain/rig/deploy-rig.sh --stop`. **Do not mint additional ranges (G4).**

## Next Phase Readiness

**Unblocked for 22-04 and 22-05:**

- The pool is swappable and the write path is PROVEN, not assumed.
- `Rig.Manifest` will hand the driver `PoolSwapTest` — and refuse to load a manifest without it.
- The chain clock has a known origin (`1700000000`) and a known drift behaviour.

**Carried forward as hard constraints:**

- **Read the chain head.** `--timestamp` fixes the origin, not the rate; the head was `1700000027`
  at 13 blocks. `InitSwappableRig` itself consumes one timestamp (`+5 s` warp plus the probe), so
  22-05's first driver step must be strictly later than the probe's `tsAfter`.
- **The write guard is per distinct `uint32` TIMESTAMP, not per block.** Anvil mines several
  blocks per second; a same-second second swap no-ops silently at `status 1`. `TimepointWritten`
  is ground truth, never the swap count.
- **One position only.** The rig holds exactly the full-range `[-887260, +887260]` position at
  L = 1e21. The cheat domain is ticks STRICTLY inside that range.
- **D22-1** (`.planning/phases/22-live-stochastic-drivers/deferred-items.md`): `RIG_PINS` is
  advertised as an override the suite does not honour. Logged, not fixed.

---
*Phase: 22-live-stochastic-drivers*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 8 claimed files exist on disk; all four commits (`9280260`, `0141ce7`, `585a2c2`, `5a0f9e7`)
are reachable in `git log`; anvil pid 1016807 is alive and running with `--timestamp 1700000000`.
