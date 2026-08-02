---
phase: 22-live-stochastic-drivers
plan: 05
subsystem: offchain-rpc
tags: [haskell, web3, anvil, uniswap-v4, driver, seeded-rng, evidence-artifact, falsification, DRIV-01]

# Dependency graph
requires:
  - phase: 22-live-stochastic-drivers
    plan: 04
    provides: "CheatSwap.Rpc.cheat_and_swap — the composed extsload -> packSlot0For -> compose_slot0 -> anvil_setStorageAt -> absolute clock -> router swap -> E3/E5 sequence, with an E3 carrying the cheated tick OBSERVED"
  - phase: 22-live-stochastic-drivers
    plan: 03
    provides: "the swappable rig (9 contracts, one full-range position, PoolSwapTest), the deterministic clock origin, and a test suite that honours RIG_MANIFEST"
provides:
  - "DRIV-01 CLOSED BY A PATH, not a step: five consecutive cheat -> clock -> swap steps, each producing exactly one E3 carrying the tick AND the timestamp the driver submitted"
  - "StochasticPriceGen.Rpc.run_cheat_swap_path — the driver loop, on a t_0 = head + stride, t_k = t_0 + k*stride schedule that is monotonic by construction"
  - "Driver.Seed — RIG_SEED as a single decimal Word32; drawn seeds are printed and recorded, malformed ones FAIL"
  - "Driver.Capture — DriverRun, a run record that can represent a TRUNCATED run and says so (dr_complete + configuredSize)"
  - "offchain/rig/driver-run-capture.json — a committed, provenance-bearing record of a live five-step run"
  - "Flush-on-failure PROVEN by injection: a mid-fold abort leaves a decodable partial artifact with dr_complete false and the steps that already mined"
  - "Six new chain-independent checks over it (73 -> 79)"
affects: [22-06, subgraph-v6]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The run's randomness is a VALUE the artifact carries, not a side effect of process start"
    - "A count equality over a list is blind to that list being truncated — compare against the CONFIGURED size, not only against the recorded one"
    - "Per-step assertions belong in the DRIVER even when the underlying primitive deliberately tolerates the same case for measurement"
    - "One env override drives BOTH the writer and the checks when the writer IS the capture tool — the opposite of 22-04's split, and for the opposite reason"

key-files:
  created:
    - offchain/lib/Driver/Seed.hs
    - offchain/lib/Driver/Capture.hs
    - offchain/rig/driver-run-capture.json
  modified:
    - offchain/lib/StochasticPriceGen/Rpc.hs
    - offchain/app/Main.hs
    - offchain/app/Sample.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "t0 is derived from the FIRST recorded step's own submitted timestamp rather than passed as a second parameter — a run with no mined step has no origin, and ds_t0 is Maybe so a partial artifact cannot invent one"
  - "The chain head is read ONCE at driver start, not per step: re-reading would make each timestamp depend on how long the previous transaction took"
  - "done_ref is set immediately after run_cheat_swap_path returns, BEFORE run_order_gen — an order-side failure must not mark the price-path evidence partial"
  - "DRIVER_CAPTURE redirects the WRITER as well as the checks, deliberately unlike 22-04's RIG_CHEAT_SWAP_PROOF: here the driver IS the capture tool, and the plan's own M1 requires `cabal run` to be aimable at a temp path"
  - "run_order_gen stays inside the same runWeb3' as the plan specifies; the finally wrapper covers it too, which is why done_ref exists"
  - "The steps IORef is appended BEFORE the per-step assertions run, so a step that mined and then failed its assertion is in the artifact"

patterns-established:
  - "When a plan's predicted discriminator is measured green, the CHECK is the defect — fix it in the task and quote both the before and the after (fifth application in this workstream)"
  - "A self-consistency assertion and a value pin catch DIFFERENT mutants; measure both, do not assume the pin is redundant"

requirements-completed: [DRIV-01]
requirements-contributed: [DRIV-01]

# Metrics
duration: 22min
completed: 2026-08-02
---

# Phase 22 Plan 05: The DRIV-01 Driver, Closed by a Path — Summary

**Five consecutive steps, five E3 logs, and every one of them carries the tick AND the timestamp the
driver submitted. DRIV-01 was a PATH requirement and 22-04 had only proven a STEP; this is the run
that closes it. Along the way the plan's own G1 detector was measured GREEN under the mutant it
exists to catch, and fixed.**

---

## THE RUN — `offchain/rig/driver-run-capture.json`, verbatim

`RIG_SEED=123456789`, `t0 = 1700001670`, `stride = 12`.

| k | submitted tick | submitted ts | **e3.tick** | **e3.timestamp** | status | e3_count | e5_count | fee |
|---|---|---|---|---|---|---|---|---|
| 0 | 237   | 1700001670 | **237**   | **1700001670** | 1 | 1 | 1 | 3000 |
| 1 | -556  | 1700001682 | **-556**  | **1700001682** | 1 | 1 | 1 | 3000 |
| 2 | -1000 | 1700001694 | **-1000** | **1700001694** | 1 | 1 | 1 | 3000 |
| 3 | -1344 | 1700001706 | **-1344** | **1700001706** | 1 | 1 | 1 | 3000 |
| 4 | -1191 | 1700001718 | **-1191** | **1700001718** | 1 | 1 | 1 | 3000 |

```
sum(e3_count) = 5     sum(e5_count) = 5     length(steps) = 5     configuredSize = 5
timestamps strictly increasing = true       dr_complete = true
[.steps[] | select(.e3.tick != .tick)] | length = 0
[.steps[] | select(.status != 1)]       | length = 0
generatedFrom = 2039f2783598866a337115df4a265a75e8842e82  == cat offchain/rig/import-ref.txt
```

Every timestamp is exactly `t0 + k*12`. `count(E5) - count(E3) = 0` over the whole run: **no step
was eaten by the G1 guard**, and that is an on-chain measurement rather than an inference — E5 fires
on every swap including one whose write the guard swallowed, so the difference between the two
counts is a direct count of lost timepoints, and both numbers arrive free in the same receipts.

---

## LEAD: A SIXTH PREDICTED DISCRIMINATOR MEASURED AND REFUTED — the plan's own G1 detector

`<standing_corrections>` warned that predicted mutant discriminators had been refuted five times.
This is the sixth.

The plan's M1, verbatim:

> delete the `evm_set_next_block_timestamp` call from `cheat_and_swap`, re-run `cabal run`
> against a temp capture path, and check `driv01_no_same_second_noop` against THAT artifact.
> PREDICTED: E3 < steps -> RED.

Applied exactly as written:

```
$ RIG_SEED=123456789 DRIVER_CAPTURE=<temp> cabal run cfmm-replicationPlank-rpc-api
cfmm-replicationPlank-rpc-api: user error (run_cheat_swap_path: step 0 SUBMITTED timestamp
  1700001899 but the hook RECORDED timestamp 1700001888 ...)
EXIT=1

$ jq -r '.dr_complete, (.steps|length), ([.steps[]|.e3_count]|add), ([.steps[]|.e5_count]|add)'
false   1   1   1

$ DRIVER_CAPTURE=<temp> cabal test
77/79 checks passed
2 FAILED: driv01_e3_per_step_matches_submitted, driv01_run_capture_is_present_and_fresh
```

**`driv01_no_same_second_noop` stayed GREEN.**

**Measured cause.** The mutant does not reach G1 at all — it reddens the DRIVER's own timestamp
assertion at step 0, because a block that did not receive an explicit timestamp does not carry
`t0 + k*stride`. That truncates the run to one healthy step, and over one healthy step
`count(E5) == count(E3) == length(steps) == 1` is **perfectly true**. The counts say only that
nothing was eaten out of the steps that EXIST. The claim being made is that nothing was eaten out of
the RUN.

**FIXED, not noted** (`3e40fcb`): `length(steps)` is now compared against `configuredSize`, with the
measurement written into the failure message so nobody removes it as a redundant assertion. Against
the same M1 artifact:

```
FAIL driv01_no_same_second_noop: the run recorded 1 steps but was configured for 5.
  MEASURED (22-05, M1): with the clock call deleted this check's count equality stayed TRUE over a
  one-step truncated run, because count(E5) == count(E3) == 1 says only that nothing was eaten out
  of the steps that EXIST. ...
76/79 checks passed
3 FAILED: driv01_e3_per_step_matches_submitted, driv01_no_same_second_noop,
          driv01_run_capture_is_present_and_fresh
```

**And the count half was independently confirmed to still discriminate on its own** — M3 below sets
one of FIVE steps to `e3_count = 0`, 22-04 measurement C's exact receipt shape, and the count
assertion reddens with the size assertion satisfied.

---

## THE MUTANTS — six applied, six results, all on COPIES

The committed artifact was never modified by any of them. Before trusting any, the override itself
was proven non-vacuous (22-03's and 22-04's twice-measured lesson):

```
$ DRIVER_CAPTURE=<nonexistent> cabal test
75/79 checks passed
4 FAILED: driv01_e3_per_step_matches_submitted, driv01_legacy_write_price_still_ran,
          driv01_no_same_second_noop, driv01_run_capture_is_present_and_fresh
```

| # | mutant | reddened | observed |
|---|---|---|---|
| **T1a** | `gen_from_seed _ = createSystemRandom` | `driv01_seed_is_reproducible` | `two generators built from seed 123456789 produced DIFFERENT paths` — 74/75. Caught by the SELF-CONSISTENCY half. |
| **T1b** | `gen_from_seed _ = initialize (V.singleton 0)` | `driv01_seed_is_reproducible` | `the first three ticks from seed 123456789 are [345,888,1540], not the pinned [455,233,-14]` — 74/75. Self-consistency PASSES; **only the value pin catches this one.** |
| **M1** | delete the clock call from `cheat_and_swap` | *(none, before the fix)* | **GREEN — see the LEAD.** After the fix: reddens at 76/79. |
| **M2** | one step's `e3.tick` +1, in a copy | `driv01_e3_per_step_matches_submitted` | `step 2 SUBMITTED tick -1000 but the hook RECORDED tick -999` — 78/79 |
| **M3** | one of five steps `e3_count` 1 → 0 | `driv01_e3_per_step_matches_submitted`, `driv01_no_same_second_noop` | `count(E5) - count(E3) = 1 is how many steps the G1 same-second guard ATE` — 77/79 |
| **M4** | `legacy_write_price.poolManager` → the `DynamicFeeHook` manager | `driv01_legacy_write_price_still_ran` | `the legacy write_price landed on 0x5fc8d326… but PriceSetterPoolManager is 0xb7f8bc63…` — 78/79 |

**T1a and T1b together are the point.** The plan predicted the value pin would catch the
argument-ignoring mutant. It does not get the chance — the self-consistency assertion fires first,
because `createSystemRandom` is also non-deterministic. T1b is the mutant that isolates the pin: a
generator that ignores its argument but is still deterministic is exactly as self-consistent as the
correct one, and only the three pinned values see it. 21-04's lesson, reproduced on a second
surface rather than inherited.

---

## FLUSH ON FAILURE — PROVEN BY INJECTION, not asserted

A `fail` injected into `one_step` after step 2's transaction had mined:

```
$ RIG_SEED=123456789 DRIVER_CAPTURE=<temp> cabal run cfmm-replicationPlank-rpc-api
RIG_SEED=123456789
  seed 123456789 supplied via RIG_SEED
cfmm-replicationPlank-rpc-api: user error (INJECTED FAILURE at step 2,
  tx 0xfd4467481851f6be9aa98f747113d22c020d0c7db56c38a8685c61f409ba5321)
EXIT=1

$ jq -r '.dr_complete, .configuredSize, (.steps|length), (.steps[]|"k=\(.k) tick=\(.tick) ts=\(.expected_ts) e3.tick=\(.e3.tick) status=\(.status)")'
false
5
2
k=0 tick=237  ts=1700001592 e3.tick=237  status=1
k=1 tick=-556 ts=1700001604 e3.tick=-556 status=1
```

Non-zero exit, the step index and the tx hash in the message, and a **decodable partial artifact
carrying the two steps that already mined**. The committed artifact's sha256 was
`13f5bd30500ce98a2f839745634b6d0b621312b35da4d7240cc3909d595e143a` before the injection and
identical after — it was never touched, because the run was aimed through `DRIVER_CAPTURE`.

**Note the ticks: `237, -556` are the SAME values the clean run produced.** The injected run was a
byte-exact replay of the clean run's tick path from the same seed, which is the reproducibility
claim demonstrated rather than argued.

---

## HONEST LIMIT — the plan's "sha256 returns to the clean-run value" is not achievable

The plan's acceptance asks to "confirm the file's sha256 returns to the clean-run value" after
restoring the injection. It cannot: `generatedAt` moves with wall time and `t0` moves with the chain
head (`t_0 = head + stride`, and `anvil --timestamp` fixes the ORIGIN, not the RATE — 22-03's
measured constraint). A re-run is byte-identical in the fields that carry meaning — the tick series,
the E3 series, the counts, the statuses — and different in exactly the two fields the artifact
records BECAUSE they are chain- and wall-dependent. The stronger statement was measured instead: the
committed artifact was never written by any mutant run at all.

---

## CHAIN INDEPENDENCE — RE-MEASURED, not inherited

```
$ bash offchain/rig/deploy-rig.sh --stop   -> rig stopped: nothing is listening on 8545
$ pgrep -a anvil                           -> (empty, exit 1)
$ cast block-number --rpc-url …:8545       -> Error: error sending request for url
$ cabal test                               -> 79/79 checks passed ; SC-3 and SC-4 OK ; exit 0
```

The rig was then stood back up from scratch, and the committed run **still passes freshness against
the from-scratch redeploy** — 79/79. `chainId`, `generatedFrom`, `poolManager`, `dynamicFeeHook` and
`tickSpacing` all held across a full teardown and redeploy, a third independent confirmation of
22-03's SC-5 determinism claim.

---

## THE GATES

| gate | measured |
|---|---|
| `cabal build --enable-tests -j all` | exit 0, **zero** `-Wall` warnings |
| `cabal test` | **79/79** (73 → 79), exit 0 |
| `cabal test` with anvil STOPPED | **79/79**, exit 0 |
| `cabal run cfmm-replicationPlank-rpc-api` | exit 0, prints `RIG_SEED=123456789`, writes the artifact |
| `RIG_SEED=notanumber cabal run` | exit 1, message names `RIG_SEED` (quoted below) |
| `sc3_literal_purge` | PASS (the purge grep produces no output) |
| `grep -c 'createSystemRandom' offchain/app/Main.hs` | **0** |
| `grep -c '^-.*run_price_gen'` on the file's whole-plan diff | **0** |
| total deleted lines in `StochasticPriceGen/Rpc.hs` | **0** — the diff is pure addition |
| `grep -c 'finally' offchain/app/Main.hs` | 3 |
| `grep -c 'modifyIORef' offchain/lib/StochasticPriceGen/Rpc.hs` | 2 |
| `grep -c 'write_price' offchain/app/Main.hs` | 5 |
| `grep -c '^+.*vector'` on the cabal diff | **1**; `Downloading` count **0**; resolved id **vector-0.13.2.0** |
| territory | `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt notes/` EMPTY |

The malformed-seed rejection, verbatim:

```
cfmm-replicationPlank-rpc-api: user error (Driver.Seed: RIG_SEED is set but is not a seed.
  value    : "notanumber"
  expected : a single decimal Word32 in [0, 4294967295]
  This does NOT fall back to a drawn seed. A malformed seed that silently became a random
  one would produce a run the operator believes is a replay and is not -- and the artifact
  would record the drawn value, so nothing downstream could tell.
  Unset RIG_SEED to draw one (it will be printed), or supply a decimal value.)
EXIT=1
```

---

## Task Commits

1. **TDD RED — the two failing checks** — `d913e20` (test)
2. **Task 1 — `Driver.Seed` + `Driver.Capture`** — `8e83286` (feat)
3. **Task 2 — `run_cheat_swap_path` + `Main.hs` wiring with flush-on-failure** — `2c84b0c` (feat)
4. **Task 3 — the four SC-1 checks over the committed run** — `5ed181e` (feat)
5. **Auto-fix — the G1 detector was blind to truncation** — `3e40fcb` (fix)

## Decisions Made

- **`t0` is derived, not passed.** The plan's signature gives `run_cheat_swap_path` one `IORef
  [CheatSwapStep]`, so `Main` reads the origin off the FIRST recorded step's own submitted
  timestamp, which is `head + stride` by construction. `ds_t0` is `Maybe`: a run that died before
  anything mined has no origin, and inventing one would make a partial artifact lie.
- **The chain head is read ONCE.** Re-reading it per step would make each timestamp depend on how
  long the previous transaction took — wall-clock noise in a schedule whose whole value is being
  arithmetic. `cheat_and_swap`'s guard (b) still re-reads the head every step, so a schedule that
  fell behind the chain is still caught.
- **`done_ref` is set immediately after `run_cheat_swap_path` returns**, before `run_order_gen`. The
  DRIV-01 path is complete at that point, and an order-side failure must not mark the price-path
  evidence partial.
- **`DRIVER_CAPTURE` redirects the WRITER as well as the checks** — the deliberate opposite of
  22-04's `RIG_CHEAT_SWAP_PROOF`, whose haddock says the override redirects the checks only. The
  reason inverts too: there, the capture was a separate tool and a redirectable capture could
  silently fail to update the artifact everything reads. Here the driver IS the capture tool, and
  the plan's own M1 requires `cabal run` to be aimable at a temp path — which is exactly what made
  the mutant runs non-destructive.
- **The steps `IORef` is appended BEFORE the per-step assertions.** A step that mined and then
  failed its own assertion is the step a reader most needs to see; appending after would lose it.
- **The per-step assertions are duplicated in the driver** rather than moved into `cheat_and_swap`.
  That function deliberately tolerates `e3_count == 0` because 22-04's G1 measurement needs the case
  observable; a driver has the opposite obligation. Both are correct for their own caller.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's G1 detector was blind to truncation**

- **Found during:** Task 3, applying M1.
- **Issue:** `driv01_no_same_second_noop` stayed GREEN under the mutant it exists to catch. The
  mutant truncates the run to one step, and `count(E5) == count(E3) == length(steps)` is true over
  any truncation.
- **Fix:** `length(steps)` compared against `configuredSize`, with the measurement in the message.
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** reddens against the same M1 artifact at 76/79; M3 confirms the count half still
  discriminates on its own at 77/79; clean run still 79/79.
- **Committed in:** `3e40fcb`

**2. [Rule 2 - Missing verification] The plan's Task-1 mutant does not isolate the value pin**

- **Found during:** Task 1 acceptance.
- **Issue:** `gen_from_seed _ = createSystemRandom` reddens the SELF-CONSISTENCY assertion, not the
  pinned values, because it is also non-deterministic. The plan's stated purpose for the pin — that
  a self-consistency assertion cannot see a law change — is therefore untested by it.
- **Fix:** a second mutant was constructed, `gen_from_seed _ = initialize (V.singleton 0)`:
  deterministic, seed-blind, and caught ONLY by the pin (`[345,888,1540]` vs `[455,233,-14]`). Both
  are reported. Measurement only; no file change.
- **Files modified:** none

**3. [Rule 3 - Blocking] The executable component was missing five build-depends**

- **Found during:** Task 2, first build.
- **Issue:** `Main.hs`'s capture wiring needs `bytestring`, `memory-hexstring`, `text`,
  `web3-ethereum` and `process`, none of which the executable stanza listed.
- **Fix:** added, with a comment recording that all five are already library dependencies so no new
  package enters the build plan. Confirmed: zero `Downloading` lines.
- **Files modified:** `cfmm-replicationPlank-rpc-api.cabal`
- **Committed in:** `2c84b0c`

**4. [Rule 1 - Bug] `ProcessType (..)` in the test suite shadowed a local binding**

- **Found during:** Task 1 build.
- **Issue:** the unused `CEV` constructor brings a `delta` field selector into scope, which shadows
  a local `delta` in the storage-perturbation check — a `-Wall` warning, i.e. a gate failure.
- **Fix:** imported by constructor (`ProcessType (GBM, mu, sigma)`) with the reason in a comment.
- **Files modified:** `offchain/test/Main.hs`
- **Committed in:** `8e83286`

---

**Total deviations:** 4 auto-fixed (2 bugs, 1 missing verification, 1 blocking). **No Rule 4
escalation.** One is a correction to the evidence layer; the rest are build and warning hygiene.

## Instructions NOT Followed, and Why

- **`grep -c 'createSystemRandom' offchain/app/Main.hs` = 0 and "record in haddock what this
  replaces" are mutually exclusive.** The first draft's module haddock said "Until 22-05 this was
  `createSystemRandom`", which took the count to 1. Resolved in favour of the grep — the haddock now
  DESCRIBES the constructor ("mwc-random's system-entropy constructor") and states in-line why the
  name is not written out, so a reader gets the history and the check keeps its ability to notice
  the call coming back. Same class as 22-04's `evm_increaseTime` resolution and 22-03's README
  greps.
- **`git diff cfmm-replicationPlank-rpc-api.cabal | grep -c '^+.*vector'` = 1 initially measured
  2**, because the explanatory comment also contained the word. The comment was rephrased so the
  literal appears only on the dependency line. Same class again.
- **Two extra checks beyond the plan's named four.** `driv01_capture_round_trips` implements the
  plan's own Task-1 behaviour ("write_capture writes valid JSON that round-trips") AND proves
  `DRIVER_CAPTURE` non-vacuous before any mutant is aimed through it. `driv01_seed_is_reproducible`
  additionally covers the three `resolve_seed` behaviours the plan lists. 73 → **79**, not 78.
- **Four mutants at Task 3, not two.** M3 (`e3_count` 1 → 0 on one of five steps) and M4
  (`legacy_write_price.poolManager` moved) were added because M1's refutation made it necessary to
  demonstrate that the count half and the legacy-flow check discriminate independently of the new
  size assertion.
- **`run_order_gen` stays inside the same `runWeb3'`**, as the plan's composition specifies. Its
  failure would truncate nothing, because `done_ref` is already `True` by then — that is what the
  flag is for.

## Issues Encountered

- **The rig's liveness claim was TRUE at start** — pid 1061007 at block 13, exactly as 22-04
  recorded. Verified before being relied on regardless (F22-4).
- **The mid-plan `cabal run`s advanced the chain**, so the committed artifact's `t0` (1700001670) is
  much later than the rig's genesis. This is expected and is why `t0` is recorded rather than
  assumed: absolute timestamps do not replay across rigs, only the tick path and the schedule's
  SHAPE do.
- **`cabal build --enable-tests -j all` used throughout**; zero `-Wall` warnings at every gate.
- **Territory clean.** `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml
  remappings.txt notes/` EMPTY throughout. The five untracked root files (`CHANGELOG.md`,
  `Setup.hs`, `stack.yaml`, `stack.yaml.lock`, `todo.md`) were present at session start and were
  never staged.

## Things NOT Done (deliberately)

- **No additional liquidity minted (G4).** The rig still holds exactly the one full-range position.
- **`ForceTimestamp` and `LeaveClockAlone` appear nowhere in the driver loop.** Both bypass the clock
  guards and are labelled MEASUREMENT ONLY in the type; `run_cheat_swap_path` constructs `AdvanceTo`
  and nothing else.
- **`write_price` and `run_price_gen` are BYTE-UNCHANGED.** The whole-plan diff on
  `StochasticPriceGen/Rpc.hs` has **zero** deleted lines, and `PriceSetter/Rpc.hs` was not touched at
  all.
- **No order-side capture.** The `orders` object is plan 22-06's; `DriverRun` is a record with no
  positional serialisation, so adding it is one field and one line.

## Rig state at exit — LEFT RUNNING for 22-06

```
anvil pid   1107697      (anvil --silent --timestamp 1700000000)
block       12
head ts     1700000014
genesis ts  1700000000
orderCount  0
manifest    9 contracts, pool.tickSpacing 20
poolId      0x00c35757198030cc0408784a49b5de3ee9c0fad958b0564592e118604b49ab8a
```

The rig was REDEPLOYED FROM SCRATCH at the end of this plan (the chain-independence measurement
required stopping it), so it is clean: `orderCount = 0`, nothing swapped, no driver run against it.
Stop with `bash offchain/rig/deploy-rig.sh --stop`. **Do not mint additional ranges (G4).**

## Next Phase Readiness

**DRIV-01 is CLOSED.** It is "the stochastic price path drives … E3 emitted per step with the
submitted tick" — a path, and the path has been run, recorded, committed and asserted by value.
22-04's carry-forward #6 said explicitly that 22-05 is the plan that closes it; this is that plan.

Carry-forwards for **22-06** (DRIV-02):

1. **`DriverRun` is designed to be extended.** Add `dr_orders :: Maybe OrdersRecord`, one line in
   `ToJSON`, and nothing else moves. The record has no positional serialisation.
2. **`run_order_gen` already runs inside the same `runWeb3'` and the same `finally`.** An order
   capture needs its own `IORef` appended the same way `steps_ref` is, and `done_ref`'s meaning must
   then be split or renamed — right now it means "the DRIV-01 path completed", deliberately, and a
   second requirement should not silently borrow it.
3. **The seed is shared.** `gen` is consumed sequentially by `run_price_gen`, then
   `run_cheat_swap_path`, then `run_order_gen`, so the order stream depends on everything drawn
   before it. That is deterministic and replayable, but it means changing the price path's `size`
   changes the ORDERS too. If 22-06 wants independently replayable orders it needs its own generator
   from the same seed, and that is a decision, not an oversight.
4. **A count equality over a recorded list is blind to truncation.** The G1 detector's refutation
   generalises: any 22-06 check of the form "sums agree over the steps that exist" must also compare
   against the configured count.
5. **`e3_count` per step and `count(E5) - count(E3)` over the run are different assertions.** The
   first localises; the second is the run-level detector. M3 reddens both, M1 (pre-fix) reddened
   neither — keep both.

---
*Phase: 22-live-stochastic-drivers*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 9 claimed files exist on disk. All 5 claimed commits (`d913e20`, `8e83286`, `2c84b0c`,
`5ed181e`, `3e40fcb`) resolve in `git log --all`. Every numeric claim was re-measured at self-check
time:

| claim | measured |
|---|---|
| `cabal test` | **79/79, exit 0** |
| `cabal build --enable-tests -j all` warnings | **0** |
| `grep -c 'createSystemRandom' offchain/app/Main.hs` | **0** |
| `grep -c '^-.*run_price_gen'` on the whole-plan diff | **0** |
| deleted lines in `StochasticPriceGen/Rpc.hs` | **0** |
| `sum(e3_count)` / `sum(e5_count)` / `length(steps)` / `configuredSize` | **5 / 5 / 5 / 5** |
| `[.steps[] \| select(.e3.tick != .tick)] \| length` | **0** |
| `.generatedFrom` vs `offchain/rig/import-ref.txt` | **equal** |
| rig alive | **pid 1107697, block 12, head ts 1700000014, orderCount 0** |

`git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt notes/`
EMPTY.
