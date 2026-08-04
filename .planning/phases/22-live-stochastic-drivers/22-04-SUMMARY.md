---
phase: 22-live-stochastic-drivers
plan: 04
subsystem: offchain-rpc
tags: [haskell, web3, anvil, uniswap-v4, slot0, cheat-swap, falsification, evidence-artifact]

# Dependency graph
requires:
  - phase: 22-live-stochastic-drivers
    plan: 02
    provides: "CheatSwap.Types (pool_state_slot, compose_slot0 at bit 184, check_cheat_tick), CheatSwap.Encoding (388-byte swap calldata), RealizedVol.Decode (E3/E5 with sign extension)"
  - phase: 22-live-stochastic-drivers
    plan: 03
    provides: "the swappable rig (9 contracts, one full-range position, PoolSwapTest), the deterministic clock origin, and a test suite that honours RIG_MANIFEST"
provides:
  - "CheatSwap.Rpc — cheat_and_swap: the composed extsload -> packSlot0For -> compose_slot0 -> anvil_setStorageAt -> absolute clock set -> router swap -> E3/E5 extraction, behind FOUR client-side guards each OBSERVED rejecting"
  - "THE PHASE BLOCKER DISCHARGED BY MEASUREMENT: an E3 carrying the cheated tick 5000 has been observed on chain"
  - "The blocker's SILENCE demonstrated: the identical sequence aimed at PriceSetterPoolManager returns status 1, one E3, one E5, and the wrong tick"
  - "G1 as a pinned measured fact: a forced same-second repeat is status 1 with an E5 and NO E3"
  - "The near-floor tick MEASURED (research's unmeasured prediction confirmed): no revert, E3 carries -887259"
  - "offchain/rig/cheat-swap-proof.json — a committed, provenance-bearing artifact with six live measurements"
  - "Five chain-independent checks over it, each falsified by its own mutant"
affects: [22-05, 22-06, subgraph-v6]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Measurement-only constructors live in the TYPE (CheatSwapClock), not behind a boolean flag"
    - "Every artifact field that can exceed 2^53 is a DECIMAL STRING — jq numbers are doubles and a rounded 256-bit word still looks like a word"
    - "Evidence-artifact paths are resolved through an env override so checks can be falsified without damaging the evidence they guard"
    - "An honest-limit note belongs IN the check, not in a summary nobody re-reads"

key-files:
  created:
    - offchain/lib/CheatSwap/Rpc.hs
    - offchain/app/CheatSwapProof.hs
    - offchain/rig/capture-cheat-swap-proof.sh
    - offchain/rig/cheat-swap-proof.json
  modified:
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal
    - .planning/phases/22-live-stochastic-drivers/22-CROSS-TRACK-FINDINGS.md
    - .planning/phases/22-live-stochastic-drivers/deferred-items.md

key-decisions:
  - "cst_cheat_manager split from cst_pool_manager solely so the blocker can be DEMONSTRATED; every production caller passes the same address twice and the haddock says so"
  - "cheat_and_swap does NOT fail on e3_count == 0 — Task 3 needs that case observable; only a reverted receipt is refused"
  - "ForceTimestamp added because omitting the clock call RACES G1 rather than reproducing it (measured both ways)"
  - "clock_untouched_repeat_step3's E3 count is deliberately NOT pinned — it depends on wall time and was observed at both values"
  - "proof_file resolved through RIG_CHEAT_SWAP_PROOF, and the override proven non-vacuous before any mutant was trusted"
  - "generatedFrom recorded unconditionally; blockNumber deliberately absent (heights 9/11/10 across three deploys)"

patterns-established:
  - "When a plan's measurement MECHANISM cannot produce the case it exists to measure, the mechanism is the defect — fix it in the task (22-03's RIG_MANIFEST lesson, applied to a second surface)"
  - "Prove an override is honoured before trusting any falsification that uses it"
  - "A weak-but-true assertion is kept AND labelled weak in-file, with the assertion that actually discriminates added beside it"

requirements-completed: []
requirements-contributed: [DRIV-01]

# Metrics
duration: 31min
completed: 2026-08-02
---

# Phase 22 Plan 04: The Cheat-Swap Composition, Discharged by Measurement — Summary

**An E3 carrying the cheated tick `5000` has been OBSERVED on a live chain, and the identical
sequence aimed at the wrong `PoolManager` has been observed returning a perfectly healthy receipt
carrying `4999` — so the phase's highest-severity finding is now discharged by evidence rather than
by argument. Along the way the plan's own G1 measurement mechanism was refuted, and fixed.**

---

## LEAD: A FIFTH PREDICTED MECHANISM REFUTED — and this one was the plan's own instrument

`<standing_corrections>` warned that predicted discriminators had been refuted four times. This is
the fifth, and like 22-03's it was not a check that missed a mutant — it was a **measurement
mechanism that could not produce the phenomenon it existed to measure**.

Plan 22-04's Task 3 specifies measuring the G1 same-second no-op with a second step

> whose `evm_setNextBlockTimestamp` call is SKIPPED entirely

Implemented exactly as written (`LeaveClockAlone`) and run:

```
same_second_repeat_step1  tick=5100  ts=1700000111  headAfter=1700000111  status=1  e3=1  e5=1
same_second_repeat_step2  tick=5200  ts=1700000111  headAfter=1700000112  status=1  e3=1  e5=1
```

`headAfter = 1700000112`. **The block landed one second later and a healthy E3 fired.** No
collision. The hazard was not reproduced, and a check pinned on that step would have been asserting
nothing.

**Measured cause**, directly against the node:

```
$ cast rpc evm_setNextBlockTimestamp 1700000124      -> null       # EQUAL: ACCEPTED
$ cast rpc evm_setNextBlockTimestamp 1700000123      -> Error: -32602
                                     Timestamp error: 1700000123 is lower than previous block's timestamp
```

After an explicit absolute set, anvil resumes wall-clock-derived timestamps for unset blocks. So
whether a "forgotten" advance collides depends on whether a wall second elapsed between two
transactions — **it was later observed at `T` three times in a row**, i.e. the same code path
produced `e3_count = 1` once and `e3_count = 0` three times. Intermittent by construction.

**FIXED, not noted.** `CheatSwap.Rpc` gained `ForceTimestamp`, which sets the absolute timestamp
with the clock guards deliberately bypassed. The collision is now **constructed**:

```
same_second_repeat_step1  tick=5100  ts=1700000256  headAfter=1700000256  status=1  e3=1  e5=1
same_second_repeat_step2  tick=5200  ts=1700000256  headAfter=1700000256  status=1  e3=0  e5=1
```

`LeaveClockAlone` was **kept**, still executed, and still recorded
(`clock_untouched_repeat_step3`) so the refutation stays on chain — but
`driv01_same_second_is_a_silent_noop` explicitly does **not** pin its E3 count, and says why
in-file. Recorded as **F22-7**.

---

## THE GATE — measurement A, verbatim

```json
{
  "name": "cheat_to_5000_then_swap",
  "tick": 5000,
  "ts": 1700000232,
  "head_ts_after": 1700000232,
  "status": 1,
  "e3_count": 1,
  "e5_count": 1,
  "e3": {
    "timestamp": 1700000232,
    "tick": 5000,
    "volatilityCumulative": "24035071635471",
    "averageTick": -135491,
    "tickCumulative": "-31027584"
  },
  "e5": { "sigma": "105416980857", "fee": 15000 },
  "state_slot": "0x9b0e565d23708a2c71ed19e38b727f891d27a8e35186bcdfb17c1f0160cb7492",
  "word_before":  "23223198172617642141431069233413930382162922907087213372",
  "word_written":  "7307508186654514591018525893284256416917456691626270",
  "word_before_high184": "0",
  "word_written_high184": "0",
  "swap_calldata_bytes": 388,
  "tx_hash": "0xb1b5251048c4a254a3711797aef8a3f0aac3695e54cd54823a260e8ae96b890e"
}
```

**`e3.tick == 5000`.** The pool initialised at tick 0 and a 1e6-wei exact-input swap against
`L = 1e21` cannot move the price anywhere near tick 5000, so this value has exactly one possible
origin: a slot0 write that `DynamicFeeHook.beforeSwap` actually read. The composition fix works
end to end.

On the very first capture (before the artifact was regenerated with six measurements), the field
decode was even cleaner, because the pool was still where `InitSwappableRig`'s probe left it:

| | tick in `word_before` | tick in `word_written` | tick E3 recorded |
|---|---|---|---|
| A (right manager) | **-1** | **5000** | **5000** |
| B (wrong manager) | **4999** | **7000** | **4999** |

---

## THE COUNTER-MEASUREMENT — measurement B's actual `e3.tick` is `4999`

```
cheat_wrong_pool_then_swap  cheated=7000  ts=1700000244  status=1  e3=1  e5=1  e3.tick=4999
```

Identical in every respect to A except that `cst_cheat_manager` is `PriceSetterPoolManager`. The
receipt is **status 1, one E3, one E5** — indistinguishable from a healthy step — and the tick is
the state A's swap left behind.

The sharpest part is what the word decode adds: **B's `word_written` carries tick 7000**. The
composition was *correct*; only the **destination** was wrong. Without that, "the tick came back
wrong" would have been consistent with broken slot0 arithmetic, which is a different bug with a
different fix. `driv01_wrong_pool_is_silent` asserts both.

`4999` is pinned as an **exact equality, measured not derived** (three consecutive captures), with
an in-file comment saying so — so a future change that accidentally makes the wrong-pool write
*work* reddens here instead of passing quietly.

---

## MEASUREMENT C — G1's two `(e3_count, e5_count)` pairs

| step | mechanism | ts | headAfter | status | e3_count | e5_count |
|---|---|---|---|---|---|---|
| `same_second_repeat_step1` | `AdvanceTo` | 1700000256 | 1700000256 | 1 | **1** | 1 |
| `same_second_repeat_step2` | `ForceTimestamp` (step 1's ts) | 1700000256 | 1700000256 | 1 | **0** | 1 |
| `clock_untouched_repeat_step3` | `LeaveClockAlone` | 1700000256 | 1700000256 | 1 | 0 *(not pinned)* | 1 |

`0 1 1` on step 2, exactly as `RealizedVolatilityStateLib.plk:114`'s equality test predicts. **The
fee was still served and the receipt still looks fine** — which is precisely what makes the missing
timepoint silent. `count(E5) - count(E3)` is therefore a direct on-chain count of steps the guard
ate, and both numbers arrive in the same receipt.

Note the two swaps were in **different blocks** sharing one `uint32` timestamp. That makes
`notes/DATA_CONTRACT.md`'s "same-block" wording an under-description, now refuted by execution and
not merely by source reading — recorded as **F22-5** (plank-owned file, NOT edited).

---

## MEASUREMENT D — the near-floor tick: research's prediction CONFIRMED

```
extreme_tick_near_floor  cheated=-887259  ts=1700000268  status=1  e3=1  e5=1  e3.tick=-887259
                         revert_reason: none
```

`CheatSwap/Encoding.hs`'s haddock labelled this a PREDICTION and named this plan as its measurer.
**No revert**, and E3 carries the cheated tick — `beforeSwap` runs before any swap math, so even a
swap that degenerates at the bottom of the range still writes its timepoint. The fixed
`zeroForOne = true` / `sqrtPriceLimitX96 = 4295128740` pair is therefore safe across the whole G4
domain, and **22-05 does NOT need direction and limit chosen per step**. `driv01_extreme_tick_is_survivable`
pins this, and its failure message spells out that a future revert here is a design consequence to
carry into the driver, not a check to relax.

---

## THE GUARDS — OBSERVED rejecting, with the block height as proof nothing was sent

`<standing_corrections>` required live falsification rather than a `grep -c 'fail ('`. Run against
the live rig, block height **13 before and 13 after** every attempt, head ts unchanged at
`1700000027`:

**Case 1 — `ts == chain head` (equal, not advancing):**
> `user error (cheat_and_swap: requested block timestamp 1700000027 does not advance past the chain head 1700000027 (tick 5000). A non-advancing timestamp is a SILENT NO-OP in the oracle, not an error: RealizedVolatilityStateLib compares lastTimepointTimestamp to now for EQUALITY, so the swap would still succeed at status 1, still emit E5 and still serve a fee, and simply write no timepoint. Nothing was sent.)`

**Case 2 — `ts == chain head - 60` (backwards):**
> `user error (cheat_and_swap: requested block timestamp 1699999967 does not advance past the chain head 1700000027 (tick 5000). ... Nothing was sent.)`

**Case 3 — constructed, because cases 1 and 2 do NOT isolate guard (c):**

Both of the plan's cases redden guard **(b)**; a backwards `ts` is below the head *before* it is
below the previous step, so guard (c) never fires. This is 22-03's Probe-6 lesson recurring — the
literal falsification does not isolate the thing it names. A third case was constructed with
`ts > head` but `ts <= previous_ts`:

> `user error (cheat_and_swap: requested block timestamp 1700000077 does not advance past the previous step's 1700000127 (tick 5000). The oracle assumes a non-decreasing uint32 clock and does NOT check it; a backwards step corrupts the window math with no revert, no event and no symptom, so this guard is the only signal that exists. Nothing was sent.)`

**Case 4 — guard (a), G4, at `tick = 887260` (one outside the inclusive bound):**
> `user error (cheat_and_swap: cheat tick 887260 is outside the G4 domain [-887259, 887259]. ... Cheat moves never cross ticks, so this desync is silent. Nothing was sent. The rig holds exactly ONE full-range position and minting a second range would break the same invariant from the other side.)`

`cast block-number` reported **13** before and **13** after all four. No transaction was sent —
proven by the height, not by inspection.

Related node finding (**F22-6**): the `-32602` rejection is a real second net for *backwards*
clocks but **not for non-advancing ones**, since anvil accepts an equal timestamp. It does not
replace guard (b).

---

## THE MUTANTS — five applied, five reddened, each exactly one check

All ran against **copies**; the committed artifact was never modified. Before trusting any of them,
the override itself was proven non-vacuous:

```
$ RIG_CHEAT_SWAP_PROOF=<nonexistent> cabal test
68/73 checks passed
5 FAILED: driv01_cheat_swap_proof_is_present_and_fresh, driv01_cheated_tick_reaches_e3,
          driv01_extreme_tick_is_survivable, driv01_same_second_is_a_silent_noop,
          driv01_wrong_pool_is_silent
```

| mutant | check reddened | observed output |
|---|---|---|
| A `e3.tick` 5000 → 5001 | `driv01_cheated_tick_reaches_e3` | `THE GATE FAILED: the hook recorded tick 5001, expected the cheated 5000.` — 72/73 |
| A `word_written` recomposed at 160 | `driv01_cheated_tick_reaches_e3` | `the WRITTEN slot0 word carries tick -887259, expected 5000.` — 72/73 |
| B `e3.tick` 4999 → 7000 | `driv01_wrong_pool_is_silent` | `cheating PriceSetterPoolManager DID move the hook's recorded tick to 7000. The two-PoolManager blocker as described is WRONG...` — 72/73 |
| step 2 `e3_count` 0 → 1 | `driv01_same_second_is_a_silent_noop` | `the same-second repeat emitted 1 E3 logs, expected 0.` — 72/73 |
| D `status` 1 → 0 | `driv01_extreme_tick_is_survivable` | `the floor-tick swap came back at status 0. A revert here is a legitimate measurement, but it is a DESIGN CONSEQUENCE...` — 72/73 |

Clean re-run against the committed artifact: **73/73**.

---

## HONEST LIMIT — the bits-≥184 assertion holds WITHOUT DISCRIMINATING on this rig

`word_before_high184` and `word_written_high184` are **both `0`** in every measurement, because
`protocolFee` is unset and a dynamic-fee pool stores `lpFee = 0` at initialize. So
`word_written >> 184 == word_before >> 184` is **true for a reason that has nothing to do with
where the mask is** — the same blindness class 22-02 avoided by construction when its two test
words carried different tick bits (`5555` vs `1234`), and the same class that made 22-02's mutant 1
survive.

Rather than leave that in a summary, it is written **into the check**, and the assertion that
actually discriminates was added beside it: the **tick field of the written word must be 5000**.
Composing at 160 instead of 184 keeps the *target's* tick, and the mutant table above shows it
reddening with `-887259`. The weak assertion is kept because it becomes load-bearing the moment a
protocol fee is configured — it is just labelled as weak today.

---

## Task Commits

1. **Task 1 — `CheatSwap.Rpc`, the guarded per-step sequence** — `b5c7bdc` (feat)
2. **Task 2 — THE MEASUREMENT** — `175a6f8` (feat)
3. **Task 3 — G1 + floor tick + five offline checks** — `f4865d1` (feat)

## Files Created/Modified

- `offchain/lib/CheatSwap/Rpc.hs` (374 lines) — `cheat_and_swap`, `CheatSwapTarget`,
  `CheatSwapStep`, `CheatSwapClock`, `chain_head_timestamp`, and the two node cheats.
- `offchain/app/CheatSwapProof.hs` (384 lines) — the capture tool, run in three independently
  caught groups so a failure in one measurement cannot erase the others.
- `offchain/rig/capture-cheat-swap-proof.sh` (180 lines) — wrapper with **eight** self-checks; two
  of them (`e3.tick != 5000`, and the wrong-pool write *working*) HALT the run because a wrong
  value committed and believed is worse than no capture.
- `offchain/rig/cheat-swap-proof.json` — six measurements, committed, provenance-bearing.
- `offchain/test/Main.hs` — five new checks (68 → **73**), plus `proof_file :: IO FilePath`.
- `cfmm-replicationPlank-rpc-api.cabal` — `CheatSwap.Rpc` exposed; new `cheat-swap-proof` executable.

## Reproducibility

Three consecutive captures, normalised with
`del(.generatedAt) | .measurements |= map(del(.ts, .head_ts_after, .tx_hash, .word_before, .word_before_high184, .word_written_high184) | del(.e3.timestamp, .e3.averageTick, .e3.volatilityCumulative, .e3.tickCumulative) | del(.e5.sigma))`:

```
3e685ea2e498e68ff98590cd203eab921e75c3859b43b277f113f70e2d583a4e   run 1
3e685ea2e498e68ff98590cd203eab921e75c3859b43b277f113f70e2d583a4e   run 2
3e685ea2e498e68ff98590cd203eab921e75c3859b43b277f113f70e2d583a4e   run 3
```

`diff -u` empty across all three pairs. The reproducible core is everything that matters:
`e3.tick`, `e3_count`, `e5_count`, `status`, `fee`, the cheated ticks, `word_written` and the
388-byte calldata length. What is normalised away is genuinely chain-state dependent — **`word_before`
in particular**, because each capture starts from the state the previous one left (measurement A's
pre-state was `-1` on the first capture and `-887259` on the last, the floor measurement's
leftover). `driv01_cheated_tick_reaches_e3` guards that directly: it asserts
`slot0_tick_of word_before /= 5000`, so if the pool were ever already at the cheated tick, the
measurement would redden rather than silently stop discriminating.

The earlier two-measurement artifact reproduced at
`9f14ecab0ea94ef5bd92973c1a4e1b93326b4c16be4ec61cd6892662951f5ffa` across two runs.

## Chain independence — RE-MEASURED, not inherited

```
$ bash offchain/rig/deploy-rig.sh --stop      -> rig stopped: nothing is listening on 8545
$ pgrep -a anvil                              -> (empty, exit 1)
$ cast block-number --rpc-url http://127.0.0.1:8545
                                              -> Error: error sending request for url
$ cabal test                                  -> 73/73 checks passed ; SC-3 and SC-4 OK ; exit 0
$ grep -cE 'cast call|HttpProvider|8545' offchain/test/Main.hs
                                              -> 0
```

The rig was then stood back up, and the **committed proof still passes freshness against a
from-scratch redeploy** — `driv01_cheat_swap_proof_is_present_and_fresh` PASS, 73/73. That is a
live confirmation of 22-03's SC-5 determinism claim from a new direction: the artifact pins
`poolManager`, `tickSpacing`, `chainId` and `generatedFrom`, and none of them moved.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's G1 mechanism could not produce a same-second collision**

- **Found during:** Task 3, first capture with `LeaveClockAlone`.
- **Issue:** `headAfter = ts + 1`, `e3_count = 1` — a healthy timepoint. Re-runs of the same path
  gave `e3_count = 0` three times. The mechanism races wall time; a check pinned on it would be
  intermittently red and vacuous when green.
- **Fix:** measured the node's actual contract (equal timestamps ACCEPTED, only strictly-lower
  rejected), added `ForceTimestamp` to construct the collision deterministically, kept
  `LeaveClockAlone` as a recorded measurement, and left its E3 count deliberately unpinned with the
  reason in-file.
- **Files modified:** `offchain/lib/CheatSwap/Rpc.hs`, `offchain/app/CheatSwapProof.hs`,
  `offchain/test/Main.hs`
- **Verification:** step 2 now `0 1 1` across three captures; the `e3_count 0 → 1` mutant reddens.
- **Committed in:** `f4865d1`. Recorded as F22-6/F22-7.

**2. [Rule 2 - Missing critical] `proof_file` was a hardcoded constant — 22-03's exact defect**

- **Found during:** Task 3, setting up the mutant.
- **Issue:** the plan's own falsification says "via `RIG_...`-style path override or a temp copy",
  but with a constant path the only available falsification is damaging the committed evidence. This
  is byte-for-byte the `manifest_file` fault 22-03 measured, on a second surface.
- **Fix:** `proof_file :: IO FilePath` via `RIG_CHEAT_SWAP_PROOF`; five consumers bind it locally.
  The haddock states the scope explicitly (**the override redirects the CHECKS only; the capture
  always writes the committed path**) so the two halves cannot drift apart the way 22-03's did.
- **Verification:** the override was proven honoured BEFORE any mutant was trusted — pointed at a
  nonexistent path, all five `driv01_` proof checks redden at 68/73. The committed artifact was
  never modified by any of the five mutants.
- **Committed in:** `f4865d1`

**3. [Rule 2 - Missing verification] The plan's clock falsification does not isolate guard (c)**

- **Found during:** Task 1 acceptance.
- **Issue:** both prescribed cases (`ts == head`, `ts == head - 60`) redden guard **(b)**; a
  backwards timestamp is below the head before it is below the previous step, so guard (c) could
  never fire. Structurally identical to 22-03's Probe-6 finding.
- **Fix:** a third case was constructed (`ts > head` but `ts <= previous_ts`) which reddens guard
  (c) alone, and a fourth for guard (a). All four verbatim messages are recorded above.
- **Files modified:** none — measurement only.

**4. [Rule 2 - Missing verification] The bits-≥184 assertion does not discriminate on this rig**

- **Found during:** Task 3, writing `driv01_cheated_tick_reaches_e3`.
- **Issue:** both high words are `0`, so the plan's prescribed assertion is true regardless of where
  the mask sits — the same blindness that let 22-02's mutant 1 survive.
- **Fix:** kept the assertion (it becomes load-bearing under a configured protocol fee) with the
  limit written INTO the check, and added the discriminating one beside it: the written word's tick
  field must be 5000. Also asserted that the recorded `*_high184` fields agree with the words they
  summarise, so a derived field cannot drift from its source.
- **Verification:** the recompose-at-160 mutant reddens with `carries tick -887259, expected 5000`.
- **Committed in:** `f4865d1`

**5. [Rule 2 - Missing critical] A failed measurement would have erased the successful ones**

- **Found during:** Task 3, wiring measurement D.
- **Issue:** `fail` inside `Web3` surfaces as an uncaught `IOException`, so a revert at D would have
  killed the capture and left A, B and C unrecorded — the one outcome the plan calls a failure.
- **Fix:** three independently caught groups, and a `Measured` type whose failure case still emits a
  row (`status 0` + `revert_reason`). A self-check asserts the artifact carries all six rows, so a
  silently shrinking list reddens.
- **Committed in:** `f4865d1`

---

**Total deviations:** 5 auto-fixed (1 bug, 4 missing critical/verification). **No Rule 4 escalation.**
All five are corrections to the EVIDENCE layer. No production behaviour beyond the plan's scope.

## Instructions NOT Followed, and Why

- **`cheat_and_swap` takes a `CheatSwapClock`, not two bare `Integer`s.** The plan's stated
  signature `CheatSwapTarget -> Integer -> Integer -> Web3 CheatSwapStep` cannot express guard (c),
  which the plan's own acceptance criteria require — guard (c) needs the previous step's timestamp
  as well as this one's. Encoding the clock intent in a type also puts the two measurement-only
  bypasses where a reader cannot miss them, instead of behind a boolean.
- **`grep -c 'evm_setNextBlockTimestamp' = 1` and "record in haddock why not `evm_increaseTime`" are
  mutually exclusive.** Any haddock naming the method verbatim takes the count to 2. Resolved in
  favour of the grep: the haddock names `evm_increaseTime` verbatim (allowed — the criterion is
  "outside comments") with the `-85682546` measurement, and refers to the one that IS used as "the
  absolute setter". Counts measured: `evm_setNextBlockTimestamp` = 1; `evm_increaseTime` = 3, all
  three on haddock lines, 0 outside comments.
- **Six measurements, not five.** The plan allows "or the number actually produced, stated
  explicitly". The sixth is `clock_untouched_repeat_step3` — the refuted mechanism, kept on chain so
  nobody re-derives it from the wrong premise. `.measurements | length` = **6**.
- **`hex32_of` was not added to `CheatSwap.Types`.** `CheatSwap.Encoding.hex32` already exists from
  22-02 and does exactly this; a second name for it would be the drift the plan's own "if it is not
  already there" clause guards against.
- **`batch-return-capture.json` was NOT re-captured** to add `generatedFrom` — the plan's own
  decision. Recorded as **D22-2** in `deferred-items.md` rather than closed on paper.

## Issues Encountered

- **The rig's liveness claim was TRUE this time** — `pgrep` found pid 1016807 at block 13, head ts
  1700000027, exactly as 22-03 recorded. First time in this phase; it was verified before being
  relied on regardless (F22-4).
- `cabal repl lib:...` with `--repl-options=-ghci-script=` runs the script **before** the library is
  loaded, so every import fails with "member of the hidden package". Feeding the same script on
  **stdin** works. Noted because the guard falsification depends on it.
- `cabal build --enable-tests -j all` used throughout; zero `-Wall` warnings at every gate.

## Things NOT Done (deliberately)

- **No driver loop.** That is 22-05, and it is now unblocked by an observed value rather than by an
  argument.
- **No additional liquidity minted (G4).** The rig still holds exactly the one full-range position.
- **`notes/DATA_CONTRACT.md` NOT edited** despite F22-5 refuting its "same-block" wording — it is
  the plank track's file. Wording proposed in the findings file, not applied.
- **Territory clean:** `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml
  remappings.txt notes/` EMPTY throughout.

## Rig state at exit — LEFT RUNNING for 22-05

```
anvil pid   1061007      (anvil --silent --timestamp 1700000000)
block       13
head ts     1700000015
genesis ts  1700000000
orderCount  0
manifest    9 contracts, pool.tickSpacing 20
poolId      0x00c35757198030cc0408784a49b5de3ee9c0fad958b0564592e118604b49ab8a
```

Stop with `bash offchain/rig/deploy-rig.sh --stop`. **Do not mint additional ranges (G4).**

## Next Phase Readiness

**22-05 is UNBLOCKED, and its dependency is discharged by evidence.**

Carry-forwards:

1. **The composition works, and the failure mode is understood precisely.** Cheat
   `.contracts.PoolManager`; read the high bits from the same manager. Aiming elsewhere produces a
   correct word in a slot nothing reads, at status 1, with a healthy E3.
2. **The fixed swap parameters are safe across the whole G4 domain** — measured at the floor, no
   revert, E3 fires. 22-05 does **not** need per-step direction/limit selection.
3. **G1 is real and cannot be reached by omission.** A driver that forgets to advance the clock
   *races* the hazard rather than hitting it. `AdvanceTo` and its two guards are the mechanism; the
   node is not a backstop for the equal case. Use `count(E5) - count(E3)` as the run-level detector.
4. **Read the chain head every step.** `--timestamp` fixes the origin, not the rate.
5. **`ForceTimestamp` and `LeaveClockAlone` must never appear in a driver loop.** Both bypass the
   clock guards; both are labelled MEASUREMENT ONLY in the type.
6. **DRIV-01 deliberately NOT marked complete.** This plan's frontmatter carries `requirements:
   [DRIV-01]`, but so do 22-01, 22-02, 22-03 and 22-05. DRIV-01 is "the stochastic price path drives
   ... E3 emitted per step with the submitted tick" — a *path*, not a step. This plan proved the
   mechanism for one step. **22-05 is the plan that closes it**, matching Phase 20's precedent where
   RIG-01 was marked only at the phase's last plan.

---
*Phase: 22-live-stochastic-drivers*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 9 claimed files exist on disk. All 3 claimed commits (`b5c7bdc`, `175a6f8`, `f4865d1`) resolve
in `git log --all`. Every numeric claim in this summary was re-measured at self-check time:

| claim | measured |
|---|---|
| `grep -c 'evm_setNextBlockTimestamp' CheatSwap/Rpc.hs` = 1 | **1** |
| `grep -c 'evm_increaseTime'` = 3, all on comment lines | **3 total, 0 outside comments** |
| `.measurements \| length` = 6 | **6** |
| `grep -cE 'cast call\|HttpProvider\|8545' offchain/test/Main.hs` = 0 | **0** |
| capture-script self-checks = 8 | **8** |
| `cabal build --enable-tests -j all` warnings | **0** |
| `cabal test` | **73/73, exit 0** |
| rig alive | **pid 1061007, block 13, head ts 1700000015, orderCount 0** |

`git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt notes/`
EMPTY.
