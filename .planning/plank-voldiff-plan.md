# Plan: Differential testing of the Plank realized-volatility oracle

Status: v3. Two review rounds done (Reality Checker + Solidity Smart Contract Engineer, in
parallel each round). Every BLOCKER from both rounds is resolved IN CODE, not deferred.
Milestone: todo.md item 5, "Differential testing with Plank".
Commits: e2609ba (port), d4da7f7 (dispatch + arithmetic), d3c0695 (baseline), 9b18bf2 (ring
wrap + falsifiable tests).

## The governing rule

`getTwapTick(dt)` and `getTickCumulative(dt)` MUST be **bit-exact across Algebra, UniV3 and
Plank, for every `dt`. Tolerance ZERO.**

v1 of this plan claimed Algebra averages over a fixed WINDOW and that Plank-vs-UniV3 could
therefore only agree "in restricted regimes". **That was false**, and it was a pre-authorized
excuse for real divergence. Algebra's `getTwapTick` reads `getSingleTimepoint` twice and applies
the *identical* negative-remainder decrement as UniV3. WINDOW never touches `tickCumulative`; it
reaches only `averageTick` and `volatilityCumulative`.

Corollary, already applied to the reference suite: `assertApproxEqAbs(..., 1)` is **banned**.
±1 on an int24 is exactly the width of the floor-toward-−∞ correction it is supposed to test.

## Hard-won lessons that must not be re-learned

**1. `make compile-plank` passing is not evidence.** `plank build` does not type-check code
unreachable from `run{}`. While RealizedVolatilityMod's `run{}` was `@evm_stop();`, every
function in it was dead code and the gate was green on an EMPTY module. Only *calling* it proves
anything. (`VegaAccountMod` and `VarianceMarketPlant` are still in this state — their gate
greenness means nothing either.)

**2. A test that cannot fail is worse than no test, because it gets counted.** The first smoke
suite was mutation-tested by a reviewer: deleting `@evm_signextend`, corrupting the volatility
kernel, and deleting `u32_sub`'s mask ALL left it 6/6 green. It asserted things that could not
distinguish a correct oracle from a broken one. **Every test added from here states which
mutation it kills, and the mutation battery is re-run before any "green" is reported.**

**3. Constant-tick paths are non-discriminating.** On a constant path `avg_tick == tick`, so
`k = 0` and `b = 0` in the volatility kernel and `calculate_avg_tick` short-circuits. Every
constant-tick test passes against an oracle that ignores storage entirely.

## Current state — verified, not asserted

`make test-vol-prereqs` -> **18 green** (7 reference + 11 Plank smoke).
`make compile-plank` -> 13 ok. `forge build --via-ir --optimize` -> rc 0.

Mutation battery (re-run at 9b18bf2): **6/6 mutants killed** —
drop SIGNEXTEND on tick/avg_tick; drop SIGNEXTEND on tick_cumulative; volatility kernel
coefficient 6->7; delete `u32_sub`'s 32-bit mask; unmask the ring index; stop accumulating
`tick_cumulative`. Baseline and restored source both green.

Bugs found and fixed while getting here (all pre-existing, none introduced by the port):
- **Ring wrap wrote OUTSIDE the ring.** `StorageIndex.next` did not mask to 16 bits;
  `load_timepoint` did. At index 65535 the write landed at `keccak(base)+65536` while the state
  word masked `ss_index` back to 0 — so reads resolved index 0 to the GENESIS timepoint. The
  oracle silently rewound to init state on wrap, losing every sample, with no revert.
  *This plan's earlier Phase 4 proposed covering wrap by unit-asserting `oldest_index_of` and the
  `windowStartIndex` bump. Both are correct. It would have tested the two things that work.*
- Checked `-`/`+` in the volatility kernel -> **reverted on any downward tick move**.
- Timestamp deltas mod 2^256 not mod 2^32 -> **inverted `oracle_lte`** for any timestamp below
  WINDOW, silently returning the spot tick as the average.
- `require(@evm_not(bool))` -> bitwise NOT, both branches truthy, **double-init guard never fired**.
- `tick_cumulative` packed in 24 bits (Algebra: int56); no sign-extension on unpack.
- `dt == 0` -> EVM SDIV by zero returns 0 SILENTLY where both refs revert.
- The reference suite was RED in `setUp` (uncatchable `vm.createSelectFork`), the UniV3 ref was
  misconfigured (claimed a 65535-slot ring while writing a handful; discarded the cardinality
  `Oracle.write` returns), and its one discriminating test was reading the WRONG CONTRACT.

## Getter surface — exists now, no mirrors required

| | Algebra ref | UniV3 ref | Plank |
|---|---|---|---|
| `getTwapTick(dt,tick,now)` | y | y | y |
| `getTickCumulative(dt,tick,now)` | y | y | y |
| `getTimepoint(index)` | full struct | (ts, cum, init) | `getTimepointPacked` |
| `lastIndex()` / `oldestIndex()` | y | y | y |
| window | `WINDOW` constant | n/a | `readWindow()` |

The earlier plan proposed a Solidity mirror of Plank's storage to read its state. That needed
**three** mirrors — the Timepoint codec, `array_slot = keccak256(abi.encode(base)) + i`, and the
packed `RealizedVolatilityState` word — i.e. an unverified oracle checking an unverified
implementation. Adding four selectors to the dispatch deleted two of the three. The remaining one
(the Timepoint word codec, in `RealizedVolatilitySmoke.t.sol`) is exercised by the
mutation-killed tests, so it is not load-bearing on trust.

## Known, legitimate semantic differences — assert around these

1. **Ring size.** UniV3 indexes mod `cardinality` (512); Algebra and Plank mod 65536. **The
   differential corpus MUST stay under 512 writes** and assert it, so a future bump that wraps
   UniV3 fails loudly instead of being blamed on the port.
2. **WINDOW is a constant in Algebra, STORAGE in Plank.** Defaults match (86400). Phase 0
   asserts `readWindow() == 86400`; if init is ever skipped it reads 0 and everything diverges.
3. **UniV3 has no volatility accumulator.** `volatilityCumulative` / `averageTick` are
   Algebra-vs-Plank only.
4. **Plank's `getAverageVolatility` is NOT Algebra's.** It returns the last timepoint's *raw*
   accumulator; `AlgebraRef.getAverageVolatilityLast` is window-normalised. **Different
   quantities — do not diff them.** Diff `volatilityCumulative` via the `getTimepoint` getters.
5. **Revert data differs**: Plank `revert_empty()` (empty), Algebra `targetIsTooOld()` (4-byte),
   UniV3 `'OLD'` (Error(string)). Use bare `vm.expectRevert()`.

## The test — `test/market_state_measurements/RealizedVolatility.diff.t.sol`

**Phase 0 — one driver, three targets.** `_drive(uint32[] timestamps, int24[] ticks)` applies the
SAME sequence to all three. If they are driven by separate code paths, a harness bug produces a
silent divergence that gets blamed on the port. Assert `plank.readWindow() == 86400`.

**Phase 1 — three-way, exact.** After every write, for a fuzzed `dt in [1, elapsed]`:
`assertEq` across all three, tolerance 0, on
  - `getTickCumulative(dt, tick, now)` — the primitive; isolates ring search + interpolation
  - `getTwapTick(dt, tick, now)` — the quotient, incl. the floor correction
  - the stored `(blockTimestamp, tickCumulative, initialized)` at `lastIndex` — the only three
    fields UniV3's Observation shares
Assert all three, not just the TWAP: `getTwapTick` is a QUOTIENT, so a truncated accumulator and
a wrong oldest-index cancel and a TWAP-only assertion passes.

**Phase 2 — two-way, exact, Algebra vs Plank on the full timepoint.** Same driver; after every
write assert `volatilityCumulative`, `tick`, `averageTick`, `windowStartIndex`, `oldestIndex`.
This is the only phase that exercises WINDOW, `_getAverageTick`, the binary search, and the
`windowStartIndex == indexUpdated` bump. `calculate_realized_volatility` runs on EVERY write, so
it is on this critical path and **cannot be deferred to todo items 6-9** as v1 assumed.

**Phase 3 — a corpus that discriminates. CONSTRUCT it; do not `vm.assume` it.**
`vm.assume` on a conjunction (>=1 rise AND >=1 fall AND span > 2*WINDOW) is a far-tail event and
will exhaust `max_test_rejects` (65536). Generate instead:

    uint256 n     = bound(_n, 96, 480);                              // < 512: no UniV3 wrap
    uint32  delta = uint32(bound(_d, (2 * WINDOW) / n + 1, 3600));   // span > 2*WINDOW by construction
    // ticks: bound each to [-887272, 887272]; force >=1 strict rise and >=1 strict fall by
    // construction (e.g. seed indices 0 and 1), never by rejection.

Then `assertLt(uniV3.lastIndex() + 1, CARDINALITY_TARGET)` and assert `span > 2*WINDOW` in the
body, so the window path cannot silently stop being covered. Without `span > WINDOW` the binary
search, the interpolation branch of `tick_cumulative_at`, and `window_start_index` are **never
executed** — the existing corpus spans at most 100x30s = 2970s against an 86400s window, so it
has never run any of them.

**Phase 3b — the sub-WINDOW corpus, SEPARATE.** The `u32_sub` fix is only reachable when
`currentTime < WINDOW`. Phase 3 forces `span > 2*WINDOW`, hence `currentTime > 172800` — so
**Phase 3 can never exercise it**. A distinct corpus with `init_timestamp in [0, WINDOW)` and few
writes is required. (The smoke suite pins this at one point; the diff test must cover the range.)

**Phase 4 — edges.**
  - `dt == 0` -> all three revert.
  - `dt` older than the oldest retained timepoint -> all three revert (bare `expectRevert`).
  - Same-block double write -> state identical on all three; second call must not revert.
  - uint32 timestamp wraparound: drive to `type(uint32).max - k` and across. Reachable because
    timestamps are explicit args, not `@evm_timestamp()`.
  - **Ring wrap: cheap, do it.** `vm.store` the index to 65535 and write once (~125k gas). The
    earlier "65537 writes ~ 2e9 gas, infeasible" reasoning was wrong twice over: the real cost is
    ~7.6e9 (the UniV3 ref alone is ~116k gas/write) and `gas_limit` is 1.07e9, so it is *more*
    infeasible than stated — and entirely unnecessary, because `vm.store` reaches the same state.
    This is now a permanent test (`test__unit__ringWrapWritesInsideTheRing`) and it is what caught
    the live wrap bug.

**Phase 5 — wire up.** `make test-vol-diff`, `--via-ir --optimize` (mandatory: `--via-ir` alone
hits stack-too-deep). Fold into `test-vol-prereqs`. Budget runtime: the UniV3 ref costs ~11.5M
gas/run (Oracle.grow's 511 SSTOREs, paid every run) vs Algebra's ~1.1M; a ~480-write corpus x 256
runs x 3 implementations is slow. Consider a separate profile.

## Where a green test would still NOT prove correctness

State these in the test file:
- Any constant-tick assertion (lesson 3).
- `tick == 0` anywhere — a fuzzer favourite that makes every assertion vacuous.
- `getTwapTick`-only assertions (the quotient cancels compensating errors).
- Any corpus whose span < WINDOW: the whole windowed path is dead code.
- Any suite that has not been re-run against the mutation battery.

## Open risks

- The `withHeuristic` omission in `binary_search_timepoints` is asserted to be result-neutral (it
  is a search-time optimization). **Phase 2 is what proves it.** If Phase 2 diverges only on
  window-boundary targets, suspect this first.
- **The differential reference is a mutable, untracked file.**
  `node_modules/@cryptoalgebra/.../VolatilityOracle.sol` is the oracle for this entire exercise
  and `npm ci` will silently replace it. It has already been accidentally hand-edited once (an
  editor auto-fill split an identifier and broke the build). Vendor it under `lib/` with a
  checksum, or add a CI step diffing `node_modules` against the registry tarball.
- `MarketStatisticsTest.test__unit__algebraGenVolTermStructure` has **zero assertions** (pure
  `console2.log`) and passes unconditionally, yet is counted in the green. Assert or skip it.
- `calculate_realized_volatility`'s parameter order differs from Algebra's `_volatilityOnRange`
  (`(avg0, avg1, t0, t1, dt)` vs `(dt, t0, t1, avg0, avg1)`). The single call site maps correctly
  — both reviewers verified this independently — but it is a live footgun for the second caller.
- `calculate_realized_volatility` divides by zero silently when `dt == 0` (EVM SDIV returns 0;
  Solidity panics even under `unchecked`). Unreachable today via the same-block guard, but it is a
  divergence-masking hazard if `lastTimepointTimestamp` ever desyncs from `last_timepoint.timestamp`.
