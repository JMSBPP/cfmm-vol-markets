# Phase 22 — Cross-Track Findings

**Opened:** 2026-08-02 (plan 22-01)
**Discipline:** REPORT, never edit. Every file named below belongs to another workstream
(`notes/`, `src/`, `foundry-scripts/`, `test/` — see `CLAUDE.md`). Nothing here was fixed.

Findings are addressed to the **plank development session** (`claude-peers` agent `ul2inqpl`)
unless stated otherwise.

---

## F22-1 — `DATA_CONTRACT.md` says "same-block"; the guard is per distinct TIMESTAMP

**Severity:** MAJOR for anyone writing a driver against this contract. The wording is imprecise;
the behaviour is not wrong.
**Owner:** plank track (`notes/`, `src/lib/`).
**Status:** REPORTED.

`notes/DATA_CONTRACT.md:25` states:

> - A same-block second write emits NOTHING (no state transition, no event).

The guard it describes is `src/lib/market_state_measurements/RealizedVolatilityStateLib.plk:114`:

```plank
let now = block_timestamp & MASK_U32;
// at most one timepoint per block: B1 -- plain false, NOT an @evm_return halt; also
// bypasses the E3 emit (no state transition, no event).
if vol_state.lastTimepointTimestamp == now { return false; }
```

This is an **equality test on a uint32 TIMESTAMP**. There is no block number anywhere in the file
(`grep -n 'blocknumber\|@evm_number\|block_number'` → no matches). The in-file comment at :112
carries the same imprecision as the doc ("at most one timepoint per block").

The two formulations coincide on a chain with ≥1s block times and **DIVERGE on anvil**, which
mines several blocks per wall second. On anvil, two swaps in two *different* blocks inside the same
second silently no-op the second write: no E3, while E5 and the fee override are still served
normally. A driver that counts swaps and expects one E3 each will over-count with no error signal.

**Consequence already binding on this phase (22-CONTEXT G1):** the driver MUST advance the clock
≥1s between writes it expects recorded, and **E3 is the ground truth of what landed** — never the
swap count. The newly imported `InitSwappableRig.s.sol:81-94` already encodes this understanding
correctly (it warps +5s and calls `evm_increaseTime` before the probe, with the comment "the write
guard is TIMESTAMP equality (one timepoint per distinct uint32 second)"), so the *implementation*
and the *script* agree — only `DATA_CONTRACT.md:25` and the lib comment at :112 lag.

**Suggested wording (plank track's call, not ours):** "A second write **within the same uint32
timestamp** emits NOTHING (no state transition, no event). On chains that mine more than one block
per second this is NOT the same as 'same block'."

---

## F22-2 — F1's `targetVega@128..255` and the client's u96@128..223 are COMPATIBLE (22-CONTEXT question, CLOSED)

**Severity:** INFO — this closes an open question rather than opening one.
**Owner:** none; recorded for this workstream.
**Status:** CONFIRMED, no action.

`22-CONTEXT.md` flagged that F1's rewritten comment block describes
`targetVega@128..255 (UNMASKED TOP FIELD)` while the offchain client packs a u96 at 128..223 with
bits ≥224 zero by construction, and asked the planner to confirm these are compatible rather than a
layout change. They are compatible, and the imported comment says so itself:

> `targetVega` IS DELIBERATELY UNMASKED: any dirty bit >= 224 inflates it past 2^96-1, where
> `target_vega_fits_packed` rejects the tuple (batch: SKIP, strict: revert)

So 128..255 is the **unmasked read region**, not a widened field: the module reads the whole top of
the word and lets `target_vega_fits_packed`
(`src/lib/pos_spec/VolOrderValidationLib.plk:60`, reached from
`vol_order_is_complete` at :87) reject anything above 2^96−1. The field is still u96 at 128..223.
Phase 21's client-side `in_range 96` guard remains exactly right and no re-pin of the packer is
implied.

Corroborating measurement: F1 is comment-only and its compiled bytecode is **byte-identical**
across the rewrite (`78ca2040…19bc88c` both sides) — see `FORGE-DELTA.md`. A layout change could
not have left the hex fixed.

---

## F22-3 — a second plank-authored artifact exists on develop and is NOT in the pin set

**Severity:** MINOR.
**Owner:** this workstream (a pin-set decision), FYI to plank.
**Status:** REPORTED, deliberately NOT imported.

The full-tree delta `9f5ccba..2039f27` contains two paths beyond the phase's import set:

```
134  0  .planning/issue-17-swappable-rig-SPEC.md
 97  0  todo.md
682 71  notes/VOLATILITY_INSTRUMENTS.md
```

`.planning/issue-17-swappable-rig-SPEC.md` is the plank track's written spec for the very script
this plan imported, and `.planning/rpc-api-volorder-v2-HANDOFF.md` shows `.planning/` imports are
not categorically excluded. It was **not** imported because the plan's 37-path set is the
authoritative pin list and every acceptance criterion in 22-01 is stated against the literal count
37; adding a 38th path silently would have made the plan unfalsifiable. If a later plan wants the
spec, it should ADD it to `import-paths.txt` explicitly and re-pin.

`notes/VOLATILITY_INSTRUMENTS.md` (+753) belongs to the **Lean4/math** session and was explicitly
excluded — `git status --porcelain notes/` was empty after the import, confirming no glob pulled it
in. `todo.md` on develop is unrelated to this pin set (this worktree carries its own untracked
`todo.md`).

---

## F22-4 — the "anvil is currently RUNNING" execution-context claim was STALE

**Severity:** MINOR (process, not code) — but it is the **third** stale liveness claim in this
workstream (21-02 recorded the same class of error, and 20-01 expired a research measurement).
**Owner:** this workstream's planning/context discipline.
**Status:** MEASURED and REFUTED.

The execution context stated *"anvil is currently RUNNING with a STALE ts=10 rig"*. At execution
time:

```
pgrep -a anvil                        -> (no output, exit 1)
ps aux | grep '[a]nvil'               -> (no output)
cast block-number --rpc-url http://127.0.0.1:8545
                                      -> Error: error sending request for url (http://127.0.0.1:8545/)
```

There is no anvil process and nothing listening on 8545. This plan needed no chain, so nothing was
blocked — but **22-03 must not assume a standing rig it can `--stop`**; it must stand one up from
scratch. The substantive half of the claim survives and gets STRONGER: whatever rig existed was
built at `TICK_SPACING = 10`, and F2 moved it to 20, so any recorded rig is stale by PoolKey hash
regardless of whether the node is up.

---

## Open items carried INTO this file by earlier phases (unchanged, listed for one-place lookup)

- **F1 / F2 (Phase 21)** — the stale V1 comment block and the `TICK_SPACING` mismatch. **BOTH ARE
  NOW FIXED UPSTREAM** by PR #18 and landed in this import: F1 is the rewritten comment at
  `VolOrderManagerMod.plk:174-193`, F2 is `TICK_SPACING = 20` at
  `DeployDynamicFeeHook.s.sol:35`. Closing them is the plank track's to record; from this side they
  are resolved.
- **F4 (Phase 21)** — the manifest freshness check cannot see a module CHANGE (`manager` is a
  `CREATE` address, bytecode-independent). Code-hash pinning proposed, not applied. Still open;
  this plan did not touch it.

---

## F22-5 — `notes/DATA_CONTRACT.md`'s same-block claim is now REFUTED BY EXECUTION, not just by source reading

**Found during:** 22-04 Task 3. **Plank-owned file. NOT edited.**

F22-1 recorded a *source-level* divergence: `notes/DATA_CONTRACT.md:25` says "A same-block second
write emits NOTHING", while `src/lib/market_state_measurements/RealizedVolatilityStateLib.plk:114`
is `if vol_state.lastTimepointTimestamp == now { return false; }` — an equality test on the
`uint32` timestamp with zero block-number reads in the file.

22-04 executed it. `offchain/rig/cheat-swap-proof.json`, measurement `same_second_repeat_step2`:

```
status = 1     e3_count = 0     e5_count = 1
```

Two swaps sharing one `uint32` timestamp, in DIFFERENT blocks (the second forced via
`evm_setNextBlockTimestamp` at the first's own timestamp). The second emitted **no E3 while still
emitting E5 and serving a fee at status 1**. So the guard is per-TIMESTAMP, and the doc's
"same-block" wording under-describes it: on anvil, which mines several blocks per second, a
*different-block* write is silently dropped too.

The consequence for any consumer of the doc is that `count(E5) - count(E3)` is a direct measure of
dropped writes, and E3 is the ground truth of what landed — never the swap count, never the block
count.

**Suggested wording for the plank track (ours to propose, theirs to apply):** replace "same-block"
with "same-`uint32`-timestamp" and note that block number does not enter the guard.

---

## F22-6 — anvil accepts an EQUAL next-block timestamp and rejects only a strictly lower one

**Found during:** 22-04 Task 3. Node behaviour, no file owner — recorded here because it changes
what a driver can and cannot construct.

```
$ cast rpc evm_setNextBlockTimestamp <head_ts>      -> null      (ACCEPTED)
$ cast rpc evm_setNextBlockTimestamp <head_ts - 1>  -> Error: server returned an error response:
                                                      error code -32602: Timestamp error:
                                                      <n> is lower than previous block's timestamp
```

Two consequences:

1. The node's rejection is a real second net for BACKWARDS clocks but **not** for non-advancing
   ones. It therefore does not replace the client-side `ts > head` guard, which is the only signal
   that exists for the equal case (G2 is unguarded on chain).
2. The G1 collision is CONSTRUCTIBLE and deterministic. It has to be constructed: simply omitting
   the timestamp call does **not** reliably collide — measured landing at `T + 1` once and at `T`
   three times, because it depends on wall time elapsed between two transactions. See F22-7.

---

## F22-7 — omitting the clock advance does NOT reliably reproduce G1; it RACES it

**Found during:** 22-04 Task 3. This refutes the plan's own stated mechanism.

Plan 22-04 specified measuring G1 by a second step "whose `evm_setNextBlockTimestamp` call is
SKIPPED entirely". Applied exactly as written, the second step came back at
`head_ts_after = T + 1` with **`e3_count = 1`** — a healthy timepoint, no collision, the hazard not
reproduced. Three later runs of the same code path came back at `T` with `e3_count = 0`.

The mechanism is wall-clock dependent, so a check pinned on it would be intermittently red and
would say nothing when it passed. `CheatSwap.Rpc` therefore gained `ForceTimestamp`, which sets the
absolute timestamp with the clock guards deliberately bypassed, and the G1 measurement is now
constructed rather than hoped for. `LeaveClockAlone` was KEPT and is still measured
(`clock_untouched_repeat_step3`) so the refutation stays on chain, but its E3 count is explicitly
NOT pinned by `driv01_same_second_is_a_silent_noop`, and the check says why in-file.

**Consequence for 22-05:** a driver that merely *forgets* to advance the clock does not fail
loudly, and does not even fail consistently — it drifts. The client-side guards are the mechanism;
the node is not a backstop.
