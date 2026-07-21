# Phase 9: Variance Kernel Unit-Diff & Full-Timepoint Diff — Context

**Gathered:** 2026-07-16
**Status:** Ready for planning
**Source:** The v2.0 roadmap's two-step parallel review (Reality Checker + Solidity Smart Contract Engineer, 4 MAJORs resolved at `b7ea835`), plus facts established and *verified* during Phase 8 execution.

<domain>
## Phase Boundary

This is **the phase the whole v2.0 milestone exists for**: proving the Plank variance surface bit-exact
against Algebra. Two deliverables:

1. **VDIFF-02 — the 5-D kernel fuzz.** Drive `(dt, tick0, tick1, avgTick0, avgTick1)` through BOTH
   Algebra's `_volatilityOnRange` (via the Phase-8 mock) and Plank's `calculate_realized_volatility`
   (via the Phase-8 harness), asserting **exact equality, tolerance 0**, across the domain.
   Phase 8's probe was a SINGLE POINT — a wiring proof, explicitly *not* evidence of bit-exactness.
   This generalises it.

2. **VDIFF-04 — the full-timepoint diff.** Drive an **Algebra-vs-Plank-only** sequence and, after
   EVERY write, assert exact equality on the stored `volatilityCumulative`, `averageTick`, and
   `windowStartIndex`.

Both must be **mutation-verified falsifiable in this phase** (the VDIFF-08 gate is embedded in
Phase 9's SC-4 — it is not deferred to Phase 11).

**NOT this phase:** the `span > 2×WINDOW` corpus and the sub-WINDOW `u32_sub` corpus are **Phase 10**.
Phase 9's driver need only be *non-vacuous*; do not pull Phase 10's corpus work forward.
</domain>

<decisions>
## Implementation Decisions (LOCKED — established by review or verified in Phase 8; do not re-litigate)

### Tolerance is 0, and that is CORRECT — do not hedge it
Bit-exactness is **guaranteed, not aspirational**, within int24 ticks × uint32 `dt`. Both reviewers
proved it independently:
- Operator trees match exactly: `k**2 * SS` ≡ `(k*%k)*%SS`; `6*b*k*seq` is left-assoc on both sides;
  `6*dt*b**2` ≡ `(6*%dt)*%(b*%b)` (Solidity `**` binds tighter than `*`).
- **No intermediate overflow:** |b| ≤ 2^56, numerator peaks ~2^149 ≪ 2^256 — neither side wraps, so
  they cannot wrap *differently*.
- `@evm_sdiv` **is** the SDIV opcode Solidity's `int256 /` compiles to under `unchecked`. Identical
  truncation-toward-zero.
- uint88 accumulation: Algebra truncates-then-adds; Plank adds-then-masks. `(a+x) mod 2^88 ≡
  (a + (x mod 2^88)) mod 2^88` — **identical**.

### The three input traps (each makes a green test worthless)
- **`dt = 0` is a KNOWN, EXCLUDED divergence.** Solidity `/` reverts even under `unchecked`
  (Panic 0x12); EVM `SDIV(N,0)` returns **0 silently**. Bound `dt ∈ [1, 2^32)`. Left unbounded, the
  fuzzer draws 0 and the mock reverts — failing the run for the *wrong reason*.
- **Non-degeneracy needs BOTH `k != 0` AND `b != 0`.** `tick0 != tick1` secures only `k`; `b != 0`
  additionally requires `tick0 != avgTick0`. If both are 0 the kernel returns 0 and `assertEq(0,0)`
  passes against a kernel that **always returns 0**.
- **`tick == 0` and constant-tick paths are vacuous.** On a constant path `avg_tick == tick`, so
  `k = 0` AND `b = 0`, the kernel returns 0, and `calculate_avg_tick` short-circuits — such a test
  passes against an oracle that ignores storage entirely.

### Assert the FULL uint256, not just uint88 — this is LOAD-BEARING, not a free extra
Production truncates to uint88, but assert the whole returned word.

**Upgraded from evidence (09-01):** this was originally framed as "strictly stronger on a free axis".
It is stronger than that. The argument-order mutant failed with
`115792089237316195423570985008687907853269984665640564039457584003616512485613 != 787251601984`
— a near-full-width word, because swapping feeds `dt` where a tick is expected and the wrapping
operators propagate into the high bits. **The divergence lives exactly in the bits a `uint88`
comparison would discard.** A uint88-only assertion could have let that mutant survive.

### VDIFF-04's field list is exactly: volatilityCumulative, averageTick, windowStartIndex
- **`oldestIndex` is EXCLUDED — it is VACUOUS.** It only becomes non-zero after the ring is
  overwritten, i.e. after **65,536 writes**. Any Phase 9/10 corpus (≤480 writes) leaves it `0` on both
  sides, so the assertion passes *no matter what the wrap logic does*. Ring-wrap `oldestIndex` is
  covered Plank-side in Phase 11 (`vm.store` the index — Algebra's library ring cannot be cheaply
  forced to a near-wrap state, so it is not a differential).
- `tickCumulative` / `blockTimestamp` / `initialized` are ALREADY diffed three-way by the merged
  Phase 0–1 test — Phase 9 adds the **variance** fields.

### Do NOT drive the UniV3 ref
The volatility surface is **Algebra-vs-Plank ONLY** — UniV3's `Oracle` has no volatility accumulator.
Driving it costs ~11.5M gas/run (its `Oracle.grow(512)` prepay) for data never compared, and imposes a
bogus 512 write-cap. **Phase 9 needs its own Algebra+Plank-only driver** — the merged
`RealizedVolatility.diff.t.sol` `_writeAll` drives all three, so do not reuse it as-is for vol.

### `windowStartIndex` equivalence is TESTED here, not assumed
Plank deliberately omits Algebra's `withHeuristic` binary-search first guess, claiming
result-invariance. That holds **only** given strictly-increasing DISTINCT timestamps (`delta >= 1`).
Preserve that invariant in the driver, and note in-file that this equivalence is what the assertion
is proving.

### Tolerance-0 is REGIME-CONDITIONAL
Guaranteed within int24 × uint32 (max |tickCumulative| ≈ 3.8e15 < int56 max 3.6e16). **Not** claimed
in Algebra's deliberate int56-overflow regime — Plank's full-width in-flight accumulator does not
replicate the `int56` wrap there (`RealizedVolatilityLib.plk` vs `VolatilityOracle.sol:357`). The type
bounds keep the corpus out of that regime; say so rather than implying universal exactness.

### Claude's Discretion
- Test file layout/names; whether to extract the shared timepoint unpacker (see Specifics) or inline.
- Fuzz run counts and bounds within the constraints above.
- How the Algebra+Plank-only driver is structured (new helper vs. a parameterised variant).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 8 delivered these — BUILD ON THEM, do not re-create
- `test/mocks/AlgebraVolatilityKernelMock.sol` — exposes Algebra's `internal pure` `_volatilityOnRange`
  externally. solc `=0.8.20`. Name deliberately distinct from the package's shipped
  `MockVolatilityOracle`.
- `test/market_state_measurements/RealizedVolatilityKernelHarness.plk` — Plank ABI harness over
  `calculate_realized_volatility`. **Selector `0xc6342af0` = `volatilityOnRange(int256,int256,int256,int256,int256)`**
  (all int256 — confirmed `cast sig`, and the Solidity interfaces in
  `RealizedVolatilityKernel.probe.t.sol:11` / `.diff.t.sol:20` declare exactly that).
  Calldata read at offsets 4/36/68/100/132 as `dt, tick0, tick1, avg_tick0, avg_tick1` — i.e. it takes
  **ALGEBRA's argument order**, so ONE tuple drives both sides and the Algebra→Plank re-order is
  isolated to a SINGLE commented call site (line 49) — that is what makes the parameter-order footgun
  mutable in one place, hence falsifiable.

  > **[CORRECTED 2026-07-16 — this file previously asserted the signature was
  > `volatilityOnRange(uint32,int24,int24,int24,int24)`. That is FALSE:** that form hashes to
  > `0x5fb3d926`, a DIFFERENT selector. Caught by the 09-01 executor running `cast sig` instead of
  > trusting this doc. The selector *constant* was always right, so nothing broke — but anyone
  > re-deriving the selector from the false signature would have produced `0x5fb3d926` and the
  > dispatch would have silently missed.
  >
  > **How the error happened, because the pattern matters:** the harness's OWN header comment
  > (lines 23-24) states the correct signature and says "Verified with: cast sig". The grep used to
  > "verify" it (`SELECTOR|const .* = fn|calldataload`) filtered those comment lines out; the
  > signature was then *inferred* from the parameter names and written here as verified fact.
  > **A grep that excludes the answer is not verification.** Read the file.
- `test/market_state_measurements/RealizedVolatilityKernel.probe.t.sol` + `make test-vol-kernel-probe`
  — the single-point wiring proof (anchor 819430). Phase 9 generalises this to a fuzz.
- `test/refs/algebra-volatility-oracle.sha256` + `script/check-algebra-ref-pin.sh` — the pin. Runs
  FIRST in `make test-vol-prereqs`; `make check-algebra-ref-pin` exits 0. **If your work makes it red,
  the baseline MOVED — stop; do not re-pin to go green.**

### The implementations under test
- `src/lib/market_state_measurements/RealizedVolatilityLib.plk` — `calculate_realized_volatility`
  (the kernel), `calculate_avg_tick`.
- `src/types/market_state_measurements/Timepoint.plk` — packing + `create_timepoint` (calls the kernel
  on EVERY write).
- `src/modules/market_state_measurements/RealizedVolatilityMod.plk` — `getTimepointPacked`,
  `lastIndex`, `oldestIndex`, `readWindow`.
- `node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries/VolatilityOracle.sol` —
  `_volatilityOnRange` (~287-312), `_getAverageTick` (~341-372), `_createNewTimepoint` (~255-273).

### Test infrastructure
- `test/PlankTestBase.sol` — `deployPlank()` + the 6 `Dependency[]` module roots.
- `test/MarketStatisticsTest.t.sol` — the Algebra ref; `getTimepoint(uint16)` returns all 7 fields
  (~206-229); `lastIndex()`, `oldestIndex()`.
- `test/market_state_measurements/RealizedVolatility.diff.t.sol` — the merged Phase 0–1 driver
  (three-way; do NOT reuse `_writeAll` for vol).
- `.planning/ROADMAP.md` — Phase 9 success criteria (authoritative, review-hardened).
</canonical_refs>

<specifics>
## Specific Ideas / Hard Constraints

- **"It compiles" is NEVER acceptance.** `plank build` does not type-check code unreachable from
  `run{}`; this repo shipped a `13 ok / 0 failed` gate that was green on an EMPTY module.
  `forge build` / `make compile-plank` may appear ONLY as labelled preconditions.
- **The mutation battery does NOT need `make compile-plank` between mutants.** 08-02's SUMMARY claims
  otherwise; **that claim is FALSE and STATE.md carries the correction.** `deployPlank` →
  `PlankDeployer.plankDeployFFI` → `plankBuildFFI` shells out to `plank build <root> --backend sona`
  over FFI **at test time**; `build/plank/*.hex` is written by `make compile-plank` and read by
  **nothing** in the test path. Proven empirically: kernel coefficient `6→7` with NO compile-plank →
  probe RED (`729013 != 819430`); restored → GREEN. **Kept lesson:** a mutant must reach the DEPLOYED
  bytecode — FFI guarantees it here; if a test ever deploys from a prebuilt artifact, re-check.

- **CLEAR `cache/fuzz` WHEN PROVING A KILL — a "kill" can be a cached REPLAY.** (Found in 09-01,
  load-bearing for Phases 10-11, which rest entirely on mutant kills.) Mutant B's first RED came back
  with **`runs: 0`** — Foundry had replayed the *previous* mutant's cached counterexample rather than
  fuzzing. The mutant appeared killed while the fuzz had not executed at all. Clearing `cache/fuzz`
  and re-running produced a genuine RED on a NEW, independent counterexample.
  **`runs: 0` on a "kill" means replay, not proof.** This is the same family as the vacuous compile
  gate: a green/red signal produced without the work behind it actually running.
  (Note: `cache/fuzz/failures` also holds pre-existing cached counterexamples for `OrderTest`,
  `SpreadTickAssimetryTest`, `VolRangeWidthTest` — the known-red pos_spec suites, unrelated.)
- **The stored-field unpacker already exists — reuse, don't write a third copy.**
  `test/market_state_measurements/RealizedVolatilitySmoke.t.sol` has a full `_timepoint()` with all
  offsets: `OFF_VOL=32`, `OFF_TICK=120`, `OFF_AVG_TICK=144`, `OFF_TICK_CUM=168`, `OFF_WSI=224`,
  `OFF_INIT=240`. The Phase 0–1 diff test unpacks only 3 of 7 fields. Phase 9 needs
  vol@32, avgTick@144 (**SIGN-EXTENDED int24**), windowStartIndex@224. Consider extracting the
  unpacker to shared test infra.
- Every forge invocation: `--via-ir --optimize` (defaulted in `foundry.toml`).
- Keep deliverables few and verifiable: the 5-D kernel fuzz and the full-timepoint diff, **each with
  its own observed-RED falsifiability proof**.
</specifics>

<deferred>
## Deferred Ideas

- **Phase 10:** the CONSTRUCTED `span > 2×WINDOW` corpus (which is what actually executes
  `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` selection inside
  `write_timepoint`), and the SEPARATE sub-WINDOW corpus (the only regime reaching `u32_sub`).
  Phase 9's driver must be non-vacuous but need NOT span 2×WINDOW.
- **Phase 11:** edges (dt-too-old revert, same-block idempotency, uint32 wrap, ring wrap via
  `vm.store`), the full mutation battery, and the `make` wire-up.
- **Out of milestone:** porting Algebra's window-normalized `getAverageVolatility` to Plank (its own
  `_getVolatilityCumulativeAt` binary search, windowed interpolation, Bessel's correction). VDIFF-03
  removed the surface that invited diffing it; do not re-add `getAverageVolatility` to
  `IRealizedVolatility`.
- **Out of milestone:** a UniV3 `OracleLib`-based volatility reference (items 6–7).
</deferred>

---

*Phase: 09-variance-kernel-unit-diff-full-timepoint-diff*
*Context gathered: 2026-07-16 — from the v2.0 roadmap review (b7ea835) + facts verified during Phase 8*
