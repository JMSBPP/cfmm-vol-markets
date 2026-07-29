# Deferred items — Phase 17

Out-of-scope discoveries made during 17-01 execution. **Not fixed** (they belong to other
tracks and are not caused by this phase's changes).

---

## D1 — FLAKY pre-existing fuzz failure in `test/lib/pos_spec/TickVolatilityLib.t.sol`

**Test:** `TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess(uint256)`

**Symptom:**
```
[FAIL: R(); counterexample: calldata=0xcd924b82000000000000000000000000000000000000000000000000ffffffffffffffff args=[18446744073709551615 [1.844e19]]]
```
The counterexample is always the same value: `2^64 - 1`.

**Owner:** the vol-type / TickVolatility track. **NOT** `src/types/pos_spec/` (which is
byte-untouched), and **NOT** one of the 4 known pos_spec reds.

**PROVEN PRE-EXISTING, not caused by 17-01.** Reproduced with all three 17-01 files
(`src/modules/pos_spec/VolOrderManagerMod.plk`,
`src/interfaces/pos_spec/VolOrderManagerInterface.plk`,
`test/pos_spec/VolOrderManager.t.sol`) stashed out of the tree: `make test` on that baseline
with a cold `cache/fuzz` reported **86 passed, 5 failed**, including this exact counterexample
at `runs: 127` (a genuine fresh discovery, not a cached replay).

**It is FLAKY / seed-dependent, which is why the recorded baseline never showed it.** Measured
over 4 cold-cache (`rm -rf cache/fuzz`) full-suite runs with 17-01 present:

| run | result |
| --- | ------ |
| 1 | 96 passed, 4 failed |
| 2 | 95 passed, 5 failed  <- this item surfaced |
| 3 | 96 passed, 4 failed |
| 4 | 96 passed, 4 failed |

In isolation (`--match-path test/lib/pos_spec/TickVolatilityLib.t.sol`) it passed 3/3 at
`runs: 256`. Foundry seeds each campaign randomly, so whether the fuzzer reaches `2^64-1`
varies run to run.

**Consequence for the recorded baseline.** STATE.md's `87 pass / 4 fail` is the MODAL cold-cache
result and is reproduced exactly by 17-01 (`87 + 9 new = 96 pass / 4 fail`). But it is not
*deterministic*: a cold-cache run can legitimately report `5 failed` through no fault of the
phase under test. Anyone gating on "exactly 4 failures" should re-run before treating a 5th as a
regression, and should check whether the 5th is this counterexample.

**Not fixed here** per the scope boundary: the defect is in another track's file, is unrelated to
anything 17-01 touches, and 17-01 must not absorb or paper over other tracks' reds.

**Recommended:** report `2^64-1` to the TickVolatility owner as a real latent counterexample —
it is deterministic once the fuzzer finds it, so it is a genuine bug, not fuzz noise.
