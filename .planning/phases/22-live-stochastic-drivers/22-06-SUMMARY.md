---
phase: 22-live-stochastic-drivers
plan: 06
subsystem: offchain-rpc
tags: [haskell, web3, anvil, uniswap-v4, vol-order, batch, abi-return, seeded-replay, falsification, DRIV-02, phase-gate]

# Dependency graph
requires:
  - phase: 22-live-stochastic-drivers
    plan: 05
    provides: "the DRIV-01 driver loop, Driver.Capture's extensible run record, Driver.Seed's RIG_SEED resolution, and the DRIVER_CAPTURE override proven non-vacuous"
  - phase: 22-live-stochastic-drivers
    plan: 04
    provides: "the proven cheat-swap mechanism the same run still exercises"
  - phase: 21-v2-abi-repin
    plan: 04
    provides: "the V2-complete order client — 4-arg create_order, batch with preview/status/block-pinned readback, LogUniform vega"
provides:
  - "DRIV-02 CLOSED: the single order, a MIXED batch and a zero-arrival tick all exercised live and recorded beside the DRIV-01 steps in ONE artifact"
  - "VolOrder.Rpc.preview_create_orders — the only channel that can show the 64-byte empty return, because a mined transaction carries no returndata"
  - "Driver.Capture's orders block, with its OWN completion flag (or_complete), deliberately not dr_complete"
  - "Sample.sample_mixed_batch — valid / skew=65535 / valid, the live-measured width-valid domain-invalid discriminator"
  - "StochasticOrderGen.Rpc.chunk exported, so generator_chunks_at_zero is MEASURED from the real function"
  - "Four chain-independent checks over the orders block (79 -> 83), five measured discriminators"
  - "SC-5 replay measured BOTH ways: same-seed identical, different-seed different"
  - "The README's ONE documented command sequence, run top to bottom at exit 0, with the driver step and a Replaying-a-run section"
affects: [subgraph-v6]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A second requirement gets its OWN completion flag; borrowing the first's would report a price-path success as an order-side success"
    - "Pin the SUBMITTED VALUES, not the relations between recorded values — a truncated batch is perfectly self-consistent"
    - "Expose the preview rather than widen the function: five call sites depend on create_orders' type and none wants the bytes"
    - "Record the id a readback actually queried, separately from the id the event announced"
    - "Where a documented claim about a program's behaviour can be measured from the program itself, measure it (generator_chunks_at_zero)"

key-files:
  created:
    - .planning/phases/22-live-stochastic-drivers/22-VERIFICATION.md
  modified:
    - offchain/lib/VolOrder/Rpc.hs
    - offchain/lib/Driver/Capture.hs
    - offchain/lib/StochasticOrderGen/Rpc.hs
    - offchain/app/Main.hs
    - offchain/app/Sample.hs
    - offchain/test/Main.hs
    - offchain/rig/driver-run-capture.json
    - offchain/rig/README.md
    - .planning/phases/22-live-stochastic-drivers/22-CROSS-TRACK-FINDINGS.md

key-decisions:
  - "or_complete is DRIV-02's own flag: dr_complete means the DRIV-01 path finished and 22-05 sets it BEFORE the order side runs, so a second requirement reading it would read a price-path success as an order-side success"
  - "The mixed batch and the empty batch run AFTER run_order_gen, because gen is consumed sequentially and anything inserted earlier would shift the generator's draws"
  - "read_order_count and read_order_packed exported beside preview_create_orders — the artifact must RECORD orderCount and the packed word, and no exported path to them existed"
  - "so_readback_id recorded separately from e1.orderId, so a readback aimed at another id cannot content-match some other order and look perfect"
  - "The three submitted tuples are pinned BY VALUE, not by length — a batch cut from three to two is self-consistent in every relation the check could otherwise use"
  - "status fields are Maybe Integer and serialise as null on a pre-Byzantium receipt: a defaulted 1 would be a status never observed and a defaulted 0 would report a revert that never happened"

patterns-established:
  - "When a plan's mutant reddens a DIFFERENT assertion than predicted, report the observed one AND construct the mutant that isolates the named one (fourth application in this workstream)"
  - "A mutant that corrupts the artifact's ENCODING is not a measurement — jq's tonumber turned a decimal string into 1e+18 and the check reddened on the parse, proving nothing"

requirements-completed: [DRIV-02]
requirements-contributed: [DRIV-01, DRIV-02]

# Metrics
duration: 41min
completed: 2026-08-02
---

# Phase 22 Plan 06: DRIV-02, Closed by Exercise — Summary

**The order client was already V2-complete. What it had never done was meet the three shapes the
generator cannot produce: a single order whose E1 and storage readback are both recorded, a batch
carrying a tuple the contract rejects, and a tick where nothing arrives at all. All three are now
live, committed, and pinned by value — and the third one is only observable through a channel this
plan had to add, because a mined transaction carries no returndata.**

**Phase 22 is COMPLETE. All five roadmap success criteria are satisfied from committed artifacts
with no chain running.**

---

## THE RUN — `offchain/rig/driver-run-capture.json`, verbatim

`RIG_SEED=123456789`, `t0 = 1700000048`, `stride = 12`. Steps unchanged from 22-05's shape
(`237, -556, -1000, -1344, -1191`, one E3 each, `count(E5) - count(E3) = 0`). The new block:

### SC-2 — the single order

```
status 1   e1_count 1   readback_id 1   readback_block 13   (a HEIGHT, not "latest")

              strike   width   skew   targetVega
submitted     1000     60      500    1000000000000000000
e1            1000     60      500    1000000000000000000
readback      1000     60      500    1000000000000000000
```

### SC-3 — the MIXED batch

```
submitted  (4100, 40,  210,   2e18)   preview (true,  6)   -> readback id 6  (4100, 40,  210, 2e18)
           (4200, 80,  65535, 3e18)   preview (false, 0)   -> SKIPPED, tx NOT reverted
           (4300, 120, 230,   4e18)   preview (true,  7)   -> readback id 7  (4300, 120, 230, 4e18)

orderCount 5 -> 7   delta 2   successes 2   readbacks 2   status 1
```

`skew = 65535` is WIDTH-valid (`pack_vol_order_input`'s `in_range 16` is `> 0 && < 2^16`) and
DOMAIN-invalid (`spread_tick_assimetry_is_complete` admits `[1, 65534]`), so it survives the client
and is skipped by the module. Its preview entry is `(false, 0)` — the id slot is zero, which is
what "best-effort skip" looks like on the wire.

### SC-4 — the zero-arrival tick

```
preview_hex   0x0000…0020 0000…0000     (130 chars: 0x + 128)
              word 0 = 32  (the array offset)
              word 1 = 0   (the length)
preview_byte_length      64      EXACTLY -- not 0, not 32
decoded_length           0
status                   1
orderCount               7 -> 7
generator_chunks_at_zero 0
```

---

## LEAD: THE 64-BYTE FACT IS UNOBSERVABLE ON THE TRANSACTION PATH

v4.0's exit record named the empty-batch return "the single clause in the return contract most
likely to break `StochasticOrderGen`". Two things make it hard to observe, and both had to be
handled rather than asserted around.

**First: a mined transaction carries no returndata.** An `eth_getTransactionReceipt` answer has
logs, a status, a block and gas figures, and no return value anywhere — the EVM's return buffer is
not part of the receipt and no node reconstructs it. `create_orders` does perform the preview
`eth_call` internally, and then discards the raw bytes, keeping only the decoded pairs. So the byte
length was reachable from nowhere.

`VolOrder.Rpc.preview_create_orders` was added for exactly this, and its haddock says why it exists
rather than what it does. The check's haddock says it too, in as many words, so that a future check
claiming to read the length off the mined transaction is contradicted in the file it would live in:

> A TRANSACTION RECEIPT CARRIES NO RETURNDATA. … the "exactly 64 bytes" fact is observable through
> the preview `eth_call` and through NOTHING ELSE on the transaction path.

**Second: the generator never gets there.** `chunk _ [] = []`, so a zero-arrival Poisson tick
produces zero chunks, zero `eth_call`s and zero transactions. `run_order_gen` sends nothing at all.
The evidence therefore needs a DIRECT `create_orders _ _ []` call, and both readings are now
recorded side by side — with `generator_chunks_at_zero` taken from the real exported `chunk` so the
claim cannot decay into a stale comment.

---

## THE MUTANTS — six applied, six results, all on COPIES

The committed artifact's sha256 was identical before and after every one of them; each ran through
`DRIVER_CAPTURE`, whose non-vacuity was proven FIRST (22-03's and 22-04's twice-measured lesson):

```
$ DRIVER_CAPTURE=<nonexistent> cabal test
75/83 checks passed
8 FAILED: driv01_e3_per_step_matches_submitted, driv01_legacy_write_price_still_ran,
          driv01_no_same_second_noop, driv01_run_capture_is_present_and_fresh,
          driv02_mixed_batch_live, driv02_run_capture_orders_are_fresh,
          driv02_single_order_live, driv02_zero_arrival_is_64_bytes
```

| # | mutant | reddened | observed |
|---|---|---|---|
| **M1** | `.orders.n0.preview_byte_length` 64 → 32 | `driv02_zero_arrival_is_64_bytes` | `the empty batch previewed 32 bytes, expected EXACTLY 64` — 82/83. **As predicted.** |
| **M2** | one `.orders.mixed.preview` bool false → true, `orderCount_after` left alone | `driv02_mixed_batch_live` | `every position in the batch previewed TRUE, so the batch was NOT mixed` — 82/83. **Reddened a DIFFERENT assertion than the plan predicted** — see below. |
| **M2b** | `.orders.mixed.orderCount_after` +1, preview untouched | `driv02_mixed_batch_live` | `orderCount moved 12 -> 15 (delta 3) but the preview predicted 2 successful orders` — 82/83. This is the mutant that isolates the count equality. |
| **M3** | `.orders.single.e1.targetVega` +1 | `driv02_single_order_live` | `the E1 carries (1000,60,500,1000000000000000001) but the driver submitted (…000)` — 82/83. **As predicted, on the second attempt** — see below. |
| **M4** | the batch TRUNCATED 3 → 2, kept fully self-consistent | `driv02_mixed_batch_live` | the VALUE PIN reddened — 82/83. See below. |
| **M5** | `.orders.complete` true → false | `driv02_run_capture_orders_are_fresh` | `orders.complete is false: the order side ABORTED partway…` — 82/83 |

### M2 — the predicted discriminator was right about the CHECK and wrong about the ASSERTION

The plan predicts M2 reddens "on the count equality". It does not. Flipping the one `false` to
`true` makes the pattern all-true, and the "at least one position previewed FALSE" assertion fires
first — the batch is no longer mixed at all, which is a strictly earlier failure than the count
being wrong. The check discriminates; the named assertion is simply not the one that gets there.

Rather than reorder the assertions to match the prediction (which would have made the weaker
statement fire first for no reason), **M2b was constructed** to isolate the count equality: move
`orderCount_after` alone and leave the preview untouched. It reddens exactly the intended assertion.
This is the same move 22-04 made when the plan's two clock cases both reddened guard (b) and a third
had to be constructed for guard (c) — the fourth application of the pattern in this workstream.

### M3 — the first attempt was a broken mutant, not a measurement

Applied as `jq '.orders.single.e1.targetVega = ((… |tonumber+1)|tostring)'`, it reddened with:

```
FAIL driv02_single_order_live: expected a decimal integer string, got "1e+18"
```

`jq`'s `tonumber` on `"1000000000000000000"` produces a double, and `tostring` renders it as
`1e+18`. The check reddened on the PARSE, not on the value — which proves nothing about whether the
`targetVega` comparison discriminates. **This is the 2^53 rule biting the mutation tooling rather
than the artifact**, and it is worth recording: a mutant that corrupts the encoding is not a
measurement. Re-applied as a literal string assignment, the real assertion fires with both tuples
quoted.

### M4 — the 22-05 truncation lesson, applied forward and confirmed

22-05's carry-forward #4 says any check of the form "sums agree over the steps that exist" must also
compare against a configured count. The order-side analogue is sharper, because there is no
`configuredSize` for a batch. M4 constructed the shape:

```
submitted=2   preview=[true,false]   orderCount delta=1   readbacks=1
```

Every relation a check could form over that artifact is TRUE. One success, one rejection, the count
moved by one, one readback, the pattern genuinely mixed. A relations-only check goes green over a
batch that was configured for three tuples and sent two.

What catches it is that `driv02_mixed_batch_live` pins the three submitted tuples BY VALUE against
`sample_mixed_batch`, exactly as the plan instructed ("PIN VALUES, never relations"), and the
message says why the pin is not a redundant length check.

---

## SC-5 — THE REPLAY, MEASURED BOTH WAYS

Two runs from `RIG_SEED=123456789` against two FRESH rigs:

```
$ diff -u /tmp/ra.json /tmp/rb.json
(empty)

$ sha256sum /tmp/ra.json /tmp/rb.json
03c8515e582fd7d38731aa420b2dcbb17287099c0c79afe00893c50d745c27b9  /tmp/ra.json
03c8515e582fd7d38731aa420b2dcbb17287099c0c79afe00893c50d745c27b9  /tmp/rb.json

$ jq -r '.seed.t0' replay-a.json replay-b.json
1700000027
1700000026
```

The projection is byte-identical while `t0` DIFFERS — and the difference is the point, not a defect:
it is what proves run B actually re-ran on a fresh chain rather than the comparison reading one file
twice.

**FALSIFIED**, on a third fresh rig at `RIG_SEED=123456790`:

```
   "e3": [                 "e3": [
-    237,                  +  289,
-    -556,                 +  -222,
-    -1000,                +  -331,
-    -1344,                +  -919,
-    -1191                 +  -169
   "ids": [                "ids": [
-    6,                    +  5,
-    7                     +  6
```

sha256 `03c8515e…` vs `f5bd76b8…`. Both `ticks`/`e3` and `ids` move — `ids` because the mixed
batch's starting `orderCount` is set by `run_order_gen`'s Poisson draw, which is seeded.

### F22-9 — the plan's own projection carries a field that cannot discriminate

`vegas: [.orders.mixed.submitted[].targetVega]` reads `sample_mixed_batch`, which is fixed DATA and
not a draw. It is identical under every seed by construction, and the falsification run left it
byte-identical while three other components moved. The projection still falsifies because those
three do depend on the seed — but a future plan that trimmed it to `vegas` alone would have a replay
check that proves nothing. Recorded, and named in the README so the trap is not re-entered.

The generator's DRAWN vegas are printed and never captured, so they cannot join the projection.
Deferred rather than done.

---

## THE PHASE GATE — every step re-measured, nothing inherited

Every command in the README's clean-machine sequence, run top to bottom in order:

| # | step | exit |
|---|---|---|
| 1 | `npm ci --ignore-scripts` | **0** |
| 2 | `git -c submodule.lib/panoptic-helper.update=none submodule update --init --recursive` | **0** |
| 3 | `forge build` | **0** |
| 4 | `offchain/rig/check-upstream.sh` | **0** |
| 5 | `offchain/rig/verify-import.sh` | **0** — `SC-1 OK: 37 imported paths` |
| 6 | `offchain/rig/deploy-rig.sh` | **0** |
| 7 | `offchain/rig/verify-rig.sh` | **0** — `SC-2 OK: 9 contracts live` |
| 8a | `cabal build --enable-tests -j all` | **0**, zero `-Wall` warnings |
| 8b | `cabal test` | **0** — 83/83 |
| 9 | `RIG_SEED=123456789 cabal run cfmm-replicationPlank-rpc-api` | **0** |

The committed artifact is the one step 9 produced, against the rig step 6 stood up.

**Chain independence, re-measured:**

```
$ bash offchain/rig/deploy-rig.sh --stop   -> rig stopped: nothing is listening on 8545
$ pgrep -a anvil                           -> (empty, exit 1)
$ cast block-number --rpc-url …:8545       -> Error: error sending request for url
$ cabal build --enable-tests -j all        -> 0 warnings
$ cabal test                               -> 83/83 checks passed ; SC-3 and SC-4 OK ; exit 0
```

The rig was then stood back up — a FOURTH from-scratch deploy this plan — and the committed run
**still passes freshness at 83/83**. That is now the fourth independent confirmation of 22-03's SC-5
determinism claim.

| gate | measured |
|---|---|
| `cabal test` | **83/83** (79 → 83), exit 0 |
| `-Wall` warnings | **0** at every build |
| literal purge over `offchain/**/*.{hs,sh}` | **empty** |
| `grep -cE 'cast call\|HttpProvider\|8545' offchain/test/Main.hs` | **0** |
| `grep -c 'preview_create_orders' offchain/lib/VolOrder/Rpc.hs` | **3** (≥ 2) |
| deleted lines in `VolOrder/Rpc.hs`'s whole-plan diff | **0** — the diff is pure addition |
| `grep -c 'decode_create_orders_result' offchain/test/Main.hs` | 7 → **10** |
| `grep -c 'preview_hex' offchain/test/Main.hs` | **8** (≥ 2) |
| `grep -c 'no returndata' offchain/test/Main.hs` | **1** (≥ 1) |
| `grep -c 'RIG_SEED' offchain/rig/README.md` | **7** (≥ 2) |
| `grep -c 'driver-run-capture.json' / 'cheat-swap-proof.json'` in README | **4** / **1** |
| territory (`src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt notes/`) | **EMPTY** |

---

## Task Commits

1. **Task 1 — the three order shapes, exercised live and recorded** — `e142afa` (feat)
2. **Task 2 — SC-2/SC-3/SC-4 pinned by value, five measured discriminators** — `c724dd0` (feat)
3. **Task 3 — README, the seed replay, the phase gate, the findings** — `ce5ac42` (docs)

## Decisions Made

- **`or_complete` is DRIV-02's own completion flag.** 22-05's carry-forward #1 said `done_ref` means
  "the DRIV-01 path completed" and a second requirement must not silently borrow it. It does not:
  `dr_complete` is set BEFORE the order side runs, deliberately, so an order-side failure cannot
  mark the price-path evidence partial. A DRIV-02 check reading it would read a price-path success
  as an order-side success. Two requirements, two flags, and the reason is in `Driver.Capture`'s
  module header where the next reader will hit it.
- **The mixed batch and the empty batch run AFTER `run_order_gen`.** 22-05's carry-forward #2: `gen`
  is consumed sequentially by `run_price_gen`, `run_cheat_swap_path` and `run_order_gen`, so
  anything inserted before the generator shifts the draws it makes. Neither new call draws from
  `gen` at all — `sample_mixed_batch` is data and an empty batch has nothing to draw for — so the
  order stream is exactly where 22-05 left it. Confirmed by the replay: the tick path is byte-equal
  to 22-05's.
- **`read_order_count` and `read_order_packed` are exported beside `preview_create_orders`.** The
  plan says "ADD one exported helper; change nothing else". The artifact must RECORD `orderCount`
  and the packed storage word, and no exported path to either existed — the alternative was
  duplicating `eth_call_manager`'s `Call` record in `Main`. All three are pure additions to the
  export list; the whole-plan diff on the file has zero deleted lines.
- **`so_readback_id` is recorded separately from `e1.orderId`.** A readback aimed at a different id
  can still content-match — it would simply be describing some OTHER order — so without this the
  readback is not evidence about THIS mint.
- **`status` fields are `Maybe Integer`, serialised as `null` when absent.** A defaulted `1` would
  be a status this run never observed and a defaulted `0` would report a revert that never happened.
- **`strike` and `targetVega` are DECIMAL STRINGS** under 22-04's 2^53 rule; `width` (u24) and
  `skew` (u16) cannot reach 2^53 by their own field widths and stay numbers so the acceptance `jq`
  can do arithmetic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The orders block cannot be built from `VolOrder.Rpc`'s exports**

- **Found during:** Task 1, wiring `capture_mixed`.
- **Issue:** the plan's own field list requires `orderCount_before`/`_after` and per-id readbacks,
  and `create_orders` performs both reads internally and returns neither. `eth_call_manager` is
  private.
- **Fix:** `read_order_count` and `read_order_packed` exported with a haddock stating why. Pure
  additions; the file's diff has zero deleted lines, which the plan's own acceptance requires.
- **Files modified:** `offchain/lib/VolOrder/Rpc.hs`
- **Committed in:** `e142afa`

**2. [Rule 2 - Missing critical] `SingleOrder` could not support the plan's own readback assertion**

- **Found during:** Task 2, writing `driv02_single_order_live`.
- **Issue:** the plan requires asserting that `e1.orderId` "equals the id used for the readback",
  and the record as designed did not carry the id the readback used — so the assertion was
  unwritable, and a readback aimed at any other id would have content-matched some other order and
  looked perfect.
- **Fix:** `so_readback_id` added and asserted equal to `e1.orderId`.
- **Files modified:** `offchain/lib/Driver/Capture.hs`, `offchain/app/Main.hs`,
  `offchain/test/Main.hs`
- **Committed in:** `c724dd0`

**3. [Rule 2 - Missing verification] The plan's M2 does not isolate the assertion it names**

- **Found during:** Task 2 mutation.
- **Issue:** flipping a preview bool false → true reddens the "batch is not mixed" assertion, not
  the count equality the plan predicts. The check discriminates; the prediction is about the wrong
  assertion.
- **Fix:** M2b constructed (`orderCount_after` alone) to isolate the count equality. Both reported.
  Measurement only; no file change.
- **Files modified:** none

**4. [Rule 1 - Bug] The plan's M3 as expressed corrupts the artifact's encoding**

- **Found during:** Task 2 mutation.
- **Issue:** `jq`'s `tonumber` on a 10^18 decimal string yields a double and `tostring` renders
  `1e+18`. The check reddened on the parse rather than on the value, proving nothing.
- **Fix:** re-applied as a literal string assignment. The real assertion then fires. Recorded as a
  pattern: a mutant that corrupts the encoding is not a measurement.
- **Files modified:** none

**5. [Rule 2 - Missing critical] The README's "what the last step proves" section was FALSE**

- **Found during:** Task 3.
- **Issue:** it said `cabal run` "is a demo, not the DRIV-01/DRIV-02 run", that its price writes go
  only to `PriceSetterPoolManager`, and that `deploy-rig.sh`'s probe swap is "the only thing on the
  rig" that makes the hook write a timepoint. All three sentences were made false by 22-05 and
  22-06, and the section is the one a reader consults to know what the command proves.
- **Fix:** rewritten to state what the command now runs, with the superseded claim quoted so the
  change is visible rather than silent.
- **Files modified:** `offchain/rig/README.md`
- **Committed in:** `ce5ac42`

**6. [Rule 1 - Bug] `-Wx-partial` on `head`/`!!` in the new SC-4 slicing**

- **Found during:** Task 2 build. A `-Wall` warning is a gate failure.
- **Fix:** replaced with a two-element pattern match, which also makes the "exactly 2 words"
  assertion structural instead of a separate length check.
- **Files modified:** `offchain/test/Main.hs`
- **Committed in:** `c724dd0`

---

**Total deviations:** 6 auto-fixed (2 bugs, 2 missing critical, 2 missing verification). **No Rule 4
escalation.** Four are corrections to the evidence layer, one to documentation, one to warning
hygiene.

## Instructions NOT Followed, and Why

- **`create_orders`'s internal enforcement was not re-implemented, and its `verify_mined_order`
  readbacks are duplicated in the capture.** `create_orders` already reads every id back; the
  capture reads them again to RECORD them, because the function keeps none of what it checks. The
  duplication is deliberate and is the only way the artifact can carry the values.
- **`capture-batch-return.sh`'s "the ONLY input" comment was not repeated**, per the plan's own
  instruction, and was recorded as **F22-8** instead. The plan also asked to confirm `strike = 0`,
  `width = 0` and `targetVega = 0` against `pack_vol_order_input`'s guards before relying on them:
  done, and all three are WIDTH-invalid as well as domain-invalid (every guard is
  `value > 0 && value < 2^bits`), so none can reach the contract. That is why the discriminator has
  to be a live-measured one rather than an obvious zero.
- **Six mutants at Task 2, not three.** M2b isolates what M2 does not, M4 applies 22-05's truncation
  lesson forward to a surface that has no `configuredSize`, and M5 covers the new completion flag.
- **The round-trip fixture was extended rather than left alone.** Adding `dr_orders` to `DriverRun`
  made `truncated_run` a `-Wmissing-fields` warning. Filling it with `no_orders` would have silenced
  the warning and covered nothing, so the fixture carries a PARTIAL orders block (single recorded,
  mixed and n0 absent) and `driv01_capture_round_trips` now asserts that `orders.complete` is false
  and `orders.n0` is `null` — the orders block is truncatable and says so.

## Issues Encountered

- **The rig's liveness claim was TRUE at start** — pid 1107697 at block 12, exactly as 22-05
  recorded. Verified before being relied on regardless (F22-4). Four further from-scratch deploys
  followed, all clean.
- **The first live run needed no debugging.** `preview [True,False,True]`, `orderCount 5 -> 7`,
  `64 bytes`, `0 chunks` — all on the first attempt, which is what a V2-complete client from Phase
  21 is supposed to look like.
- **One check failed on first run for a real reason:** `driv02_single_order_live` reddened with
  `missing JSON key "readback_id"` because the artifact predated the field. Re-taken, not worked
  around.
- **`cabal build --enable-tests -j all` used throughout**; zero `-Wall` warnings at every gate.
- **Territory clean.** `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml
  remappings.txt notes/` EMPTY throughout. `lib/forge-std`, `offchain/spec/types.md` and the five
  untracked root files were dirty at session start and were never staged.

## Things NOT Done (deliberately)

- **No additional liquidity minted (G4).** The rig still holds exactly the one full-range position.
- **`run_order_gen`, `attach_vega` and `draw_target_vega` are BYTE-UNCHANGED.** The only edit to
  `StochasticOrderGen/Rpc.hs` is the export list plus a haddock on `chunk`; zero deleted lines.
- **`create_orders` is byte-unchanged.** `preview_create_orders` sits beside it.
- **The generator's drawn vegas were not added to the artifact.** They would give the replay
  projection a fourth genuinely seed-dependent component (F22-9), but three already discriminate.
- **`notes/DATA_CONTRACT.md` NOT edited** despite F22-1/F22-5. Plank-owned; wording proposed only.

## Rig state at exit

```
anvil pid   1152682      (anvil --silent --timestamp 1700000000)
block       13
head ts     1700000014
genesis ts  1700000000
manifest    9 contracts, pool.tickSpacing 20
poolId      0x00c35757198030cc0408784a49b5de3ee9c0fad958b0564592e118604b49ab8a
```

Redeployed FROM SCRATCH after the chain-independence measurement, so it is clean. The committed
artifact was taken against the PREVIOUS from-scratch rig and still passes freshness against this
one — which is the fourth confirmation of that determinism, and the reason the artifact pins
`generatedFrom`, `tickSpacing` and addresses rather than `blockNumber`.

Stop with `bash offchain/rig/deploy-rig.sh --stop`. **Do not mint additional ranges (G4).**

---

## PHASE 22 IS COMPLETE — what is PROVEN, ASSUMED, and OPEN

Full mapping of the five roadmap success criteria to observed artifact fields:
`.planning/phases/22-live-stochastic-drivers/22-VERIFICATION.md`.

**PROVEN by observed values on a live chain:**

- **SC-1** — five consecutive steps, one E3 each, `e3.tick` and `e3.timestamp` equal to what the
  driver submitted, `count(E5) - count(E3) = 0`, legacy `write_price` still running on the other
  manager. (22-05, re-taken here.)
- **SC-2** — status 1, one E1, four fields including `targetVega`, readback pinned to the receipt's
  block at height 13 and content-equal.
- **SC-3** — a genuinely mixed batch: `(false, 0)` for the domain-invalid tuple, transaction not
  reverted, `orderCount` moved by exactly 2, both minted ids read back and content-matched.
- **SC-4** — exactly 64 bytes, decoding to `[]` through the shipped decoder AND through the suite's
  own slicing, `orderCount` unmoved, zero generator chunks.
- **SC-5** — one documented sequence at exit 0 on every step; same-seed replay byte-identical with
  differing `t0`; different-seed replay different.

**ASSUMED, and named as such:**

- that `skew = 65535` is the *only* client-passable contract rejection — USED, never claimed
  (F22-8).
- that the 4-field readback comparison suffices; it discards `tickSpacing` at 104..127 and bits
  >= 248 (Phase 21 follow-up #5, PARTIALLY ADDRESSED).
- that the bits->=184 slot0 preservation assertion discriminates — on this rig both high words are
  `0`, so it holds without discriminating (22-04's recorded limit).

**OPEN:**

- **F22-1 / F22-5** — `notes/DATA_CONTRACT.md:25`'s "same-block" wording, refuted by execution.
  Plank-owned, REPORTED, not edited. The only cross-track item this phase leaves behind.
- **F4 (Phase 21)** — freshness cannot see a MODULE change (`manager` is a bytecode-independent
  `CREATE` address). Code-hash pinning proposed, not applied.
- **D22-1** — `RIG_PINS` is advertised as an override the suite does not honour.
- **D22-2** — `batch-return-capture.json` still carries no `generatedFrom`.
- **F22-9** — the drawn vegas are not captured, so they cannot join the replay projection.

**Next milestone (v6.0, issue #14):** the subgraph indexes this phase's event stream. It has what it
needs — a reproducible run from a recorded seed producing E1, E3 and E5 under pinned topic0s, with
the artifact naming the imported ref it was taken against.

---
*Phase: 22-live-stochastic-drivers*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 11 claimed files exist on disk. All 3 claimed commits (`e142afa`, `c724dd0`, `ce5ac42`) resolve
in `git log --all`. Every numeric claim was re-measured at self-check time:

| claim | measured |
|---|---|
| `cabal test` | **83/83, exit 0** |
| `cabal build --enable-tests -j all` warnings | **0** |
| `grep -c 'preview_create_orders' offchain/lib/VolOrder/Rpc.hs` | **3** |
| deleted lines in `VolOrder/Rpc.hs` over the whole-plan diff | **0** |
| deleted lines in `StochasticOrderGen/Rpc.hs` over the whole-plan diff | **0** |
| `grep -c 'decode_create_orders_result' offchain/test/Main.hs` | **10** (was 7) |
| `grep -c 'preview_hex' offchain/test/Main.hs` | **8** |
| `grep -c 'no returndata' offchain/test/Main.hs` | **1** |
| `grep -cE 'cast call\|HttpProvider\|8545' offchain/test/Main.hs` | **0** |
| `grep -c 'RIG_SEED' offchain/rig/README.md` | **7** |
| `grep -c 'driver-run-capture.json' / 'cheat-swap-proof.json'` in README | **4** / **1** |
| `.orders.n0.preview_byte_length` / `decoded_length` / `generator_chunks_at_zero` | **64 / 0 / 0** |
| `.orders.mixed` preview / delta / readbacks | **[true,false,true] / 2 / 2** |
| `.orders.single.e1_count` / `readback_block` / `readback_id` | **1 / 13 / 1** |
| `dr_complete` / `orders.complete` / steps vs configuredSize | **true / true / 5 vs 5** |
| rig alive | **pid 1152682, block 13, head ts 1700000014** |

`git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt notes/`
EMPTY.
