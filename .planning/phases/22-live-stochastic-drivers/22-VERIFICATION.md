# Phase 22 — Verification Record

**Closed:** 2026-08-02 (plan 22-06)
**Requirements:** DRIV-01 (closed at 22-05), DRIV-02 (closed at 22-06)

Every row below names the ARTIFACT FIELD that satisfies the criterion, so the claim can be
re-checked with `jq` rather than re-read. All artifacts are committed and all checks over them are
chain-independent (measured with `pgrep anvil` EMPTY).

The two evidence artifacts:

- `offchain/rig/cheat-swap-proof.json` — six live measurements of the cheat-swap MECHANISM (22-04)
- `offchain/rig/driver-run-capture.json` — one live driver RUN: five steps plus the three order
  shapes (22-05, 22-06)

---

## SC-1 — one E3 per step, carrying the submitted tick (DRIV-01)

**MECHANISM SUPERSEDED at plan time** (22-CONTEXT locked decision): there is no offchain
`writeTimepoint` client. `DynamicFeeHook.beforeSwap` self-writes the timepoint on the pre-swap tick
it reads via `extsload`, so the driver's job is to make the hook FIRE and then OBSERVE E3. The
required OUTCOME is unchanged and is what is recorded.

| clause | satisfied by | observed |
|---|---|---|
| a stochastic price path produces one E3 per step | `.steps[].e3_count` | `1, 1, 1, 1, 1` |
| `receiptStatus == 1` on every step | `.steps[].status` | `1, 1, 1, 1, 1` |
| exactly ONE E3 per receipt | `.steps[].e3_count` summed vs `configuredSize` | `5` vs `5` |
| decoded `(timestamp, tick)` equals what the driver submitted | `.steps[].e3.tick` vs `.steps[].tick`; `.steps[].e3.timestamp` vs `.steps[].expected_ts` | `237/-556/-1000/-1344/-1191` on both sides; every ts exactly `t0 + k*12` |
| the E3 came from the HOOK, not the module | log filter on `changeAddress == DynamicFeeHook` in `CheatSwap.Rpc` | `RealizedVolatilityMod` emits the same topic0 with the poolId sentinel; the filter is mandatory |
| the legacy `write_price` flow still runs, unchanged, beside it | `.legacy_write_price.poolManager` | `PriceSetterPoolManager` — the OTHER manager, which is why this flow could never satisfy DRIV-01 alone |

**Asserted by:** `driv01_e3_per_step_matches_submitted`, `driv01_no_same_second_noop`,
`driv01_legacy_write_price_still_ran`, `driv01_run_capture_is_present_and_fresh`.

**The G1 detector and its refutation.** `count(E5) - count(E3) = 0` over the run is a direct
on-chain count of steps the same-second guard ate, because E5 fires on every swap including one
whose write the guard swallowed. 22-05 measured that this equality is BLIND TO TRUNCATION and fixed
it: `length(steps)` is now also compared against `configuredSize`.

---

## SC-2 — single order: status 1, E1 v2, receipt-block-pinned readback (DRIV-02)

| clause | satisfied by | observed |
|---|---|---|
| a `create_order` receipt with status 1 | `.orders.single.status` | `1` |
| one E1 v2 log under the pinned topic0 | `.orders.single.e1_count` | `1` |
| four decoded data words equal the submitted tuple | `.orders.single.e1` vs `.orders.single.submitted` | `(1000, 60, 500, 1000000000000000000)` on both sides |
| **including `targetVega`** | `.orders.single.e1.targetVega` | `"1000000000000000000"` — a decimal STRING, because 10^18 is over a hundred times 2^53 |
| a receipt-block-pinned `getOrderPacked` readback | `.orders.single.readback_block` | `13` — a height, and asserted NOT to be the string `latest` |
| the readback unpacks to the submitted order | `.orders.single.readback` | equal to `.submitted`, all four fields |
| the readback describes THIS mint | `.orders.single.readback_id` vs `.orders.single.e1.orderId` | `1` vs `1` |

**Asserted by:** `driv02_single_order_live`.

**Honest limit, carried from Phase 21 follow-up #5 (PARTIALLY ADDRESSED):**
`unpack_vol_order_storage` discards `tickSpacing` at bits 104..127 and anything at >= 248 BEFORE the
comparison. Agreement on the four fields says nothing about those bits.

---

## SC-3 — batch: preview pattern, orderCount delta, every id read back (DRIV-02)

| clause | satisfied by | observed |
|---|---|---|
| a live batch returns entries positionally matching the preview's success PATTERN | `.orders.mixed.preview` | `[[true,6],[false,0],[true,7]]` |
| **a MIXED batch — at least one contract-rejected tuple** | `.orders.mixed.submitted[1].skew` | `65535` — WIDTH-valid (`in_range 16` is `>0 && <2^16`) and DOMAIN-invalid (`spread_tick_assimetry_is_complete` admits `[1, 65534]`) |
| best-effort skip observed live, not assumed | the rejected position's preview entry | `(false, 0)` — and the transaction did NOT revert |
| `orderCount` moves by exactly the success count | `.orders.mixed.orderCount_before/_after` | `5 -> 7`, delta `2`; successes `2` |
| every mined id's receipt-block-pinned readback content-matches | `.orders.mixed.readbacks` | ids `[6, 7]`, fields `(4100,40,210,2e18)` and `(4300,120,230,4e18)` — the two SUCCESSFUL submitted tuples, in order |
| **including `targetVega`** | `.orders.mixed.readbacks[].targetVega` | `"2000000000000000000"`, `"4000000000000000000"` |
| any mismatch reported with the tx hash, never silently | `create_orders`' failure paths | `.orders.mixed.txHash` recorded either way |

**Asserted by:** `driv02_mixed_batch_live`.

**Truncation is closed by VALUE PINS, not by relations.** A batch silently cut from three tuples to
two would be perfectly self-consistent — one success, one rejection, `orderCount` moved by one, one
readback. Measured: mutant M4 constructed exactly that shape and the value pin reddened.

**NOT claimed:** that `skew = 65535` is the only input a client can pass that the contract rejects.
`capture-batch-return.sh` says so; the exclusivity was never verified. Recorded as **F22-8**.

---

## SC-4 — a zero-arrival Poisson tick completes cleanly (DRIV-02)

| clause | satisfied by | observed |
|---|---|---|
| the 64-byte empty return | `.orders.n0.preview_byte_length` | `64` — EXACTLY; not 0, not 32 |
| decodes to an empty result list | `.orders.n0.decoded_length`, and `decode_create_orders_result` re-run in the check | `0`, and `Right []` |
| not a decode failure and not a crash | `.orders.n0.status` | `1` |
| nothing minted | `.orders.n0.orderCount_before/_after` | `7 -> 7` |
| the words are canonical | `.orders.n0.preview_hex`, sliced by the test itself | word 0 = `32` (the array offset), word 1 = `0` (the length); 130 chars total |
| the GENERATOR's reading | `.orders.n0.generator_chunks_at_zero` | `0` |

**Asserted by:** `driv02_zero_arrival_is_64_bytes`.

**TWO THINGS THAT MUST BE SAID PLAINLY.**

1. **A transaction receipt carries NO returndata.** An `eth_getTransactionReceipt` answer has logs,
   a status, a block and gas figures, and no return value anywhere. The 64-byte fact is observable
   through the preview `eth_call` — `VolOrder.Rpc.preview_create_orders`, added by this plan for
   exactly this reason — and through nothing else on the transaction path. The check says so in its
   haddock; a future check claiming to read the length off the mined tx would be wrong about where
   the bytes live.
2. **`run_order_gen` sends NOTHING at N = 0.** `chunk _ [] = []`, so a zero-arrival tick produces
   zero chunks, zero `eth_call`s and zero transactions. SC-4 therefore needs a DIRECT
   `create_orders _ _ []` call; the generator path can never exercise it. Both readings are
   recorded side by side, and `generator_chunks_at_zero` is measured from the real function so the
   claim cannot rot into a stale comment.

---

## SC-5 — one documented command, reproducible from a RECORDED seed (DRIV-01, DRIV-02)

| clause | satisfied by | observed |
|---|---|---|
| one documented command sequence | `offchain/rig/README.md` "Clean-machine sequence" | all 10 steps run top to bottom, **every one exit 0** |
| against a fresh Phase-20 rig | `deploy-rig.sh` — 6 scripts, 9 contracts | 4 from-scratch deploys this plan; the committed run passes freshness against each |
| the seed is RECORDED | `.seed.rng` | `123456789`, printed before anything is sent |
| the run is reproducible from it | two same-seed runs against FRESH rigs | projection `diff -u` EMPTY, sha256 `03c8515e582fd7d38731aa420b2dcbb17287099c0c79afe00893c50d745c27b9` on both |
| the second run really re-ran | `.seed.t0` in the two raw artifacts | `1700000027` vs `1700000026` — DIFFERENT |
| the replay check is not vacuous | a `RIG_SEED+1` run on a fresh rig | ticks `237,-556,-1000,-1344,-1191` → `289,-222,-331,-919,-169`; ids `[6,7]` → `[5,6]` |

**Honest limit:** absolute timestamps do NOT replay. `t_0` is read from the chain head
(`t_0 = head + stride`) and anvil's `--timestamp` fixes the ORIGIN, not the RATE. What replays is
the tick path, the E3 series, the drawn values, the minted ids, and the schedule's SHAPE
(`t_k - t_0 = k*stride`). Stated in the README rather than quietly excluded.

**F22-9:** the plan's own projection includes `.orders.mixed.submitted[].targetVega`, which is fixed
DATA rather than a draw and is identical under every seed. Three of the four components DO
discriminate; that one cannot, and the README names the trap.

---

## Phase gate — re-measured at 22-06, never inherited

| gate | measured |
|---|---|
| every README clean-machine step | 10 steps, **all exit 0** |
| `cabal build --enable-tests -j all` | exit 0, **zero** `-Wall` warnings |
| `cabal test` | **83/83**, exit 0 |
| `cabal test` with anvil STOPPED (`pgrep anvil` empty, `cast` erroring) | **83/83**, exit 0 |
| `offchain/rig/verify-import.sh` | exit 0, **37 paths** |
| `offchain/rig/verify-rig.sh` | exit 0, **9 contracts live**, both routers bound to the right manager |
| literal purge over `offchain/**/*.hs,*.sh` | **empty** |
| `grep -cE 'cast call\|HttpProvider\|8545' offchain/test/Main.hs` | **0** |
| territory (`src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt notes/`) | **EMPTY** |

---

## What is PROVEN, what is ASSUMED, what is OPEN

**PROVEN by observed values on a live chain:**
- the hook self-writes a timepoint carrying a tick that could only have come from a slot0 write it
  read (22-04: E3 `5000` against a pool that cannot reach tick 5000 by trade)
- five consecutive steps each producing exactly one E3 with the submitted tick AND timestamp
- best-effort batch skip: `(false, 0)` for a domain-invalid tuple, transaction not reverted,
  `orderCount` moved by exactly the success count
- the empty batch returns exactly 64 bytes decoding to `[]`
- same-seed replay identical, different-seed replay different

**ASSUMED (relied on, not independently established here):**
- that `skew = 65535` is the *only* client-passable contract rejection (F22-8 — USED, not claimed)
- that the 4-field readback comparison is sufficient; it discards `tickSpacing` and bits >= 248
  (Phase 21 follow-up #5, PARTIALLY ADDRESSED)
- that the bits->=184 slot0 preservation assertion discriminates — on this rig both high words are
  `0`, so it holds without discriminating (22-04's recorded honest limit)

**OPEN:**
- **F22-1 / F22-5** — `notes/DATA_CONTRACT.md:25`'s "same-block" wording, refuted by execution.
  Plank-owned, REPORTED, not edited.
- **F4 (Phase 21)** — the manifest freshness check cannot see a MODULE change, because `manager` is
  a bytecode-independent `CREATE` address. Code-hash pinning proposed, not applied.
- **D22-1** — `RIG_PINS` is advertised as an override the suite does not honour.
- **D22-2** — `batch-return-capture.json` still carries no `generatedFrom`.
- the generator's DRAWN vegas are printed but not captured, so they cannot join the replay
  projection (F22-9).

---
*Phase: 22-live-stochastic-drivers*
*Verification closed: 2026-08-02*
