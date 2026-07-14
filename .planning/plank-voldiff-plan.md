# Plan: Differential testing of the Plank realized-volatility oracle

Status: DRAFT — pending two-step review (Reality Checker + specialist). Do not execute yet.
Milestone: todo.md item 5, "Differential testing with Plank".
Depends on: commit e2609ba (RealizedVolatilityMod compiles, in the gate).

## Goal

`src/modules/market_state_measurements/RealizedVolatilityMod.plk` is a port of Algebra's
`VolatilityOracle`. Prove it produces the same results as the existing Solidity references
in `test/MarketStatisticsTest.t.sol` (`MarketStatisticsAlgebraRef`, `MarketStatisticsUniV3Ref`).

## What the existing test actually is (read it before trusting the name)

`test/MarketStatisticsTest.t.sol` is NOT a differential test today. It asserts the Algebra ref
and the UniV3 ref **separately**, each against a closed-form expectation:

- `test__fuzz__algebraOneObsTickAvgEqObs` / `..uniV3OneObsTickAvgEqObs` — 1 obs -> avg == tick
- `test__fuzz__algebraEqTickNObsReturnsTickAsAvg` / `..uniV3..` — constant tick -> avg == tick
- `test__fuzz__algebraNMinusOneEqTicksAndOutlierTickSuccess` / `..uniV3..` — N-1 equal + 1
  outlier -> closed-form mean, assertApproxEqAbs(..., 1)

The two refs are never compared to each other. todo.md item 3 says "(partial)" — that is why.
Note also `test__fuzz__uniV3EqTickNObsReturnsTickAsAvg` writes to the **UniV3** ref but then
reads `marketStatisticsAlgebraRef.getTwapTick(...)` (line 197) — a copy-paste bug that makes
that test not test UniV3 at all. Same shape at line 180-201. This must be fixed or the
"reference" we diff against is not what we think it is.

Reference API surface (what a Plank harness must match):
- `initializeTWAP(uint32 blockTimestamp, int24 tick)`
- `writeTimepoint(uint32 timestamp, int24 tick)`
- `getTwapTick(uint32 dt, int24 tick, uint32 currentTimestamp) -> int24`
- `getAverageVolatilityLast(int24 tick, uint32 blockTimestamp) -> uint88`  (Algebra only)

## Honest scope: what CAN and CANNOT be asserted equal

- **Plank vs Algebra: should be bit-exact.** The Plank module is a port of Algebra's algorithm.
  Any divergence is a port bug. This is the real payoff of the diff test.
- **Plank/Algebra vs UniV3: equal only where the algorithms coincide.** UniV3's `Oracle` has no
  WINDOW; Algebra averages over a fixed WINDOW (1 day). They agree on constant-tick paths and on
  arbitrary-dt TWAP built from the tick accumulator, and diverge once WINDOW truncation bites.
  A test asserting blanket Plank == UniV3 equality WILL fail for correct code. Scope each
  assertion to the regime where the semantics actually coincide, and say so in the test name.

## Blockers (must land before any assertion can pass)

These are pre-existing defects, not regressions from the port. Evidence for each is in todo.md.

**B1 — no ABI dispatch.** `RealizedVolatilityMod`'s `run{}` block is `@evm_stop();`. The module
is uncallable from Solidity. Selectors exist in `RealizedVolatilityInterface.plk` but nothing
dispatches on them.

**B2 — `tick_cumulative` packed into 24 bits; Algebra uses `int56`.**
`tick_cumulative = sum(tick * dt)`. One day at tick 887272 is ~7.7e10 (~37 bits). 24 bits holds
+/-8.4e6. It overflows almost immediately, so every accumulator-derived value is wrong.

**B3 — `unpack_timepoint` does not sign-extend.** `tick`, `avg_tick`, `tick_cumulative` are
signed; unpack masks with `& 0xFFFFFF`, so a negative tick returns a large positive number and
`@evm_sdiv` then divides garbage. Ticks are routinely negative — the existing fuzz tests draw
`int24 tick` unbounded, so this is hit immediately.

**B4 — the fix for B2 does not fit in one word.** Algebra's Timepoint is 241 bits. Our extra
`min_tick` (24 bits) makes a correct 56-bit `tick_cumulative` cost 265 bits > 256.
Current layout (233 bits): timestamp 32 | realizedVolatility 88 | tick 24 | avg_tick 24 |
min_tick 24 | tick_cumulative 24 | window_start_index 16 | initialized 1.
**DESIGN DECISION REQUIRED — options:**
  (a) Drop `min_tick` (Algebra has no such field). -> 241 bits, exact parity. Cheapest.
  (b) Shrink `realizedVolatility` 88 -> 64 bits. -> 241 bits. Changes the overflow horizon
      (Algebra sizes 88 bits for ~34800 years).
  (c) Spill to a second storage word. Exact + keeps min_tick; doubles SSTORE cost per write.
Recommendation: (a), PENDING USER CONFIRMATION that `min_tick` is not needed.
Evidence: `min_tick` is self-referential dead weight today — it is maintained
(Timepoint.plk:97 reads `current.min_tick` only to recompute the running minimum) and packed,
but NO downstream consumer ever reads it: it feeds neither avg_tick, nor the volatility
accumulator, nor any getter. It costs exactly the 24 bits that make B2 unfixable in one word.
If it is intended for a future vol-term-structure/skew feature, choose (c) instead — do not
silently drop a field the design wants.

**B5 — timestamp source mismatch.** The Plank module reads `@evm_timestamp()` internally; the
refs take an explicit `blockTimestamp` arg. `vm.warp` does drive `@evm_timestamp()`, so a
warp-driven harness is viable, but the refs must then be fed `uint32(vm.getBlockTimestamp())`
so all three see the same clock. Preferred: parameterize the Plank harness to take an explicit
timestamp, so the uint32 wraparound path in `oracle_lte` is testable without warping to 2^32.

**B6 — `interfaces` dep missing from test setUps.** Every `.t.sol` hand-rolls its
`Dependency[]`; none lists `interfaces`, which `RealizedVolatilityMod` imports. Deploy will fail
with "unknown module". Fix centrally (this is already the standing "AI TODO" about setUp
duplication).

## Steps

**S0 — central test fixture.** One shared base contract exposing the full six-root
`Dependency[]` (v3, std, pos_spec, lib, types, interfaces) + `plankDeployFFI` helpers. Kills B6
and the standing setUp-duplication TODO. Every existing .t.sol migrates to it.

**S1 — fix the Timepoint layout (B2/B3/B4).** Apply the B4 decision; re-pack with `int56`
`tick_cumulative`; add sign-extension to `unpack_timepoint` for all signed fields. Unit-test
pack/unpack round-trip as a property: `unpack(pack(t)) == t` over fuzzed values **including
negative ticks and large accumulators**. This must pass before anything else is trusted.

**S2 — wire the ABI dispatch (B1).** Add the selector dispatch to `RealizedVolatilityMod`'s
`run{}`, or (preferred, matching the repo's established pattern) add
`test/lib/market_state_measurements/RealizedVolatilityHelper.plk` — an entrypoint whose `run{}`
dispatches on selectors and calls into the module. Expose exactly the reference API:
`initializeTWAP`, `writeTimepoint`, `getTwapTick(dt,...)`, `getAverageVolatility`.
`getTwapTick(dt)` is NOT `calculate_avg_tick` (which is WINDOW-based). It must be built from
`tick_cumulative_at`: `twap(dt) = sdiv(cum(now) - cum(now - dt), dt)`, matching UniV3
`observeSingle`. Mirror the UniV3 negative-remainder rounding (`if delta<0 && delta%dt!=0 -> --`)
or the diff will be off by one on negative ticks.

**S3 — fix the existing Algebra-vs-UniV3 test.** Repair the copy-paste bug at line 197 (UniV3
test reads the Algebra ref), then close todo item 3 by adding real ref-vs-ref assertions, not
two parallel closed-form checks. This gives a trustworthy baseline to diff Plank against.

**S4 — the Plank diff test** (`test/.../RealizedVolatility.diff.t.sol`), layered:
  - L1 unit, degenerate: 1 observation -> `twap == tick`. All three agree by construction.
  - L2 fuzz, constant tick (incl. negative): all three -> `tick`. Kills B3 regressions.
  - L3 fuzz, N-1 equal + outlier: closed-form mean, mirrors the existing refs' assertion.
  - L4 **true differential, random tick path**: drive Algebra, UniV3 and Plank through the SAME
    (timestamp, tick) sequence; assert `plank == algebra` EXACTLY on `tickCumulative` and
    `avg_tick`; assert `plank == univ3` only on arbitrary-dt TWAP within the no-WINDOW-truncation
    regime. Shrink-friendly: bound N to ~100 writes as the existing tests do.
  - L5 edge: uint32 timestamp wraparound (exercises `oracle_lte`), ring-buffer wrap
    (requires > 2^16 writes — likely infeasible in fuzz; assert `oldest_index_of` directly
    instead), and `dt` older than the oldest retained timepoint (must revert on all three).

**S5 — wire into the Makefile** as a named target alongside `test-utils` /
`test-pricing-kernel-diff`, with `--via-ir` (mandatory: the whole repo requires it).

## Risks / open questions

- The `withHeuristic` omission in `_binarySearch` is asserted to be result-neutral. L4 is what
  actually proves that. If L4 diverges only on window-boundary targets, suspect this first.
- `@evm_sdiv` vs Solidity `/` on negatives: both truncate toward zero, but the UniV3 ref applies
  an explicit negative-remainder decrement. If S2 does not mirror it, expect systematic off-by-one
  on negative ticks — an easy false alarm to misread as a port bug.
- `realizedVolatility` (volatilityCumulative) diffing is NOT in scope here; it depends on
  `calculate_realized_volatility`, which should be diffed against Algebra's `_volatilityOnRange`
  as its own step (todo items 6-9). Do not conflate.
- Ring-buffer wrap (2^16 timepoints) is not reachable in a fuzz test. Coverage there is by
  direct unit assertion on `oldest_index_of`, not end-to-end.
