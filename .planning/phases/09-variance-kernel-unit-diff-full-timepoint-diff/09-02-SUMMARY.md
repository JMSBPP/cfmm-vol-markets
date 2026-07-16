---
phase: 09-variance-kernel-unit-diff-full-timepoint-diff
plan: 02
subsystem: testing
tags: [forge, fuzz, differential-testing, plank, algebra, volatility-oracle, mutation-testing, ffi, refactor]

# Dependency graph
requires:
  - phase: 08-reference-integrity-kernel-mock
    provides: "test/refs/algebra-volatility-oracle.sha256 + make check-algebra-ref-pin (the pinned Algebra baseline this diff is measured against)"
  - phase: 09-variance-kernel-unit-diff-full-timepoint-diff
    plan: 01
    provides: "VDIFF-02: the kernel proven bit-exact at tolerance 0 over 1024 runs -- which is what makes a divergence HERE attributable to the write path rather than the formula. Also the cache/fuzz replay lesson and the re-confirmed FFI/compile-plank correction."
provides:
  - "VDIFF-04 discharged: the Algebra-vs-Plank-ONLY full-timepoint variance diff -- volatilityCumulative, averageTick, windowStartIndex at tolerance 0 after EVERY write; green (fixed anchor + 256-run constructed fuzz)"
  - "test/market_state_measurements/TimepointDecoder.sol -- THE single test-side unpacker for Plank's packed timepoint word (was 2 copies, would have been 3)"
  - "make test-vol-timepoint-diff, folded into test-vol-prereqs (pin still FIRST)"
  - "Observed-RED falsifiability proof for SC-4's remaining two mutants (timepoint packing corruption; volatilityCumulative accumulation stopped), both restored byte-identical and green"
  - "Empirical confirmation that asserting INSIDE the driver (after every write) localises the accumulation mutant to the earliest write at which it can diverge"
affects: [10-corpus-construction, 11-edges-and-mutation-battery]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The differential assertion lives INSIDE the two-way driver, so 'after EVERY write' cannot be forgotten at a call site -- and the failure localises to the first diverging write"
    - "A shared decoder library owns the packed-layout offsets, so a layout change desynchronises ONE file, and the differential makes that loud"
    - "Hand-derived anchor values are VERIFIED with a temporary exact assertion before being written into a docblock as fact, then relaxed to the required form"
    - "Docblock kill-claims committed as PENDING and filled in only from observation -- never written ahead of the run"
    - "Mutant kills re-run against a CLEARED cache/fuzz; a non-fuzz unit anchor is kept alongside because it is cache-independent by construction"

key-files:
  created:
    - test/market_state_measurements/TimepointDecoder.sol
    - test/market_state_measurements/RealizedVolatilityTimepoint.diff.t.sol
  modified:
    - test/market_state_measurements/RealizedVolatilitySmoke.t.sol
    - Makefile

key-decisions:
  - "09-02: VDIFF-04 DISCHARGED at tolerance 0 with ZERO divergences -- fixed anchor + 256-run constructed fuzz, asserting after init and after EVERY write. Nothing was hedged: no tolerance added, no field dropped, no assertion relaxed."
  - "09-02: the fixed anchor's hand-derived first-write value (avgTick1 = -400, vol = 2,376,388) was VERIFIED EMPIRICALLY with a temporary exact assertion before being stated as fact in the docblock, then relaxed to the plan-mandated assertGt(volA, 0). A derivation written into a comment unverified is just a plausible-looking claim."
  - "09-02: Mutant B's failure numbers (9612287 != 7235899) are the state after the SECOND write -- 9612287 = Algebra's cumulative (2376388 + 7235899), 7235899 = that write's delta ALONE. The test aborts at the EARLIEST write at which the accumulation mutant can diverge. This is direct evidence that asserting inside the driver is load-bearing, not stylistic."
  - "09-02: an initial inference that the second write accrued ZERO volatility was WRONG and was checked before it reached the summary (delta w2 = 7235899, not 0). The real explanation -- abort at the first diverging write -- is stronger. Per-write accrual on the anchor is 2376388 / 7235899 / 12625: all non-zero, so the anchor is non-vacuous at every write."
  - "09-02: the WHAT THIS KILLS docblock was committed PENDING in e6e4718 and filled in only after Task 3 ran. Committing 'OBSERVED RED' before observing it would be exactly the failure mode this phase exists to prevent."
  - "09-02: both mutants are caught by the NON-fuzz unit anchor as well as the fuzz. That is a strictly stronger position than 09-01's, because a unit assertion is cache-independent -- it cannot be a replay even in principle."

patterns-established:
  - "Verify-then-claim: derivations and inferences are executed (temporary probe) before being written down, and a wrong inference is discarded rather than smoothed into the narrative"
  - "Self-defeating acceptance criteria are resolved in favour of BOTH requirements (paraphrase in-file, verbatim in the SUMMARY), not by dropping one"

requirements-completed: [VDIFF-04]

# Metrics
duration: 13min
completed: 2026-07-16
---

# Phase 9 Plan 02: Full-Timepoint Variance Diff Summary

**VDIFF-04 discharged: an Algebra-vs-Plank-ONLY driver asserts exact (tolerance 0) agreement on the STORED `volatilityCumulative`, `averageTick` and `windowStartIndex` after init and after EVERY write — green across a fixed anchor and a 256-run constructed fuzz, with SC-4's remaining two mutants OBSERVED red; and the timepoint unpacker now exists in exactly ONE place.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-07-16T17:33:39Z
- **Completed:** 2026-07-16T17:47:06Z
- **Tasks:** 3
- **Files modified:** 4 (2 created, 2 modified)

## The Mutant Table — the deliverable

**No `make compile-plank` was run between the mutants, and none is needed.** `deployPlank` → `plankDeployFFI` → `plankBuildFFI` shells out to `plank build` over FFI **at test time**; `build/plank/*.hex` is read by **nothing** in the test path. Both REDs below came from a `.plk` edit alone, on the very next `forge test` — the **fourth** independent confirmation that 08-02's contrary claim ("its kills are fiction" without a recompile) is **FALSE**. STATE.md carries that correction; this plan does not resurrect it.

**Both kills were run against a CLEARED `cache/fuzz`** (`rm -rf cache/fuzz` before each). Per 09-01, a `runs: 0` "kill" can be Foundry **replaying** a previous mutant's cached counterexample instead of fuzzing.

| # | Exact edit | Observed exit | Verbatim `[FAIL: ...]` line | Which assertion | Restored exit |
|---|-----------|---------------|------------------------------|-----------------|---------------|
| **A** | `src/types/market_state_measurements/Timepoint.plk:32` — `const OFF_AVG_TICK = 144;` → `const OFF_AVG_TICK = 145;` | **2** (RED, 0 passed / 2 failed) | *unit:* `[FAIL: averageTick: algebra vs plank, tolerance 0: 100 != 200] test__unit__fixedSequenceVarianceFieldsMatch() (gas: 144856)`<br><br>*fuzz:* `[FAIL: averageTick: algebra vs plank, tolerance 0: -387745 != -775490; counterexample: calldata=0xe187d208...00de args=[3, 222]] test__fuzz__randomPathVarianceFieldsMatch(uint256,uint8) (runs: 0, μ: 0, ~: 0)` | **`averageTick: algebra vs plank, tolerance 0`** — both tests | **0** (2 passed, `runs: 256`) |
| **B** | `src/types/market_state_measurements/Timepoint.plk:115` — `vol: @evm_add(current.realizedVolatility.vol, realized_vol_delta.vol) & MASK_U88` → `vol: realized_vol_delta.vol & MASK_U88` | **2** (RED, 0 passed / 2 failed) | *unit:* `[FAIL: volatilityCumulative: algebra vs plank, tolerance 0: 9612287 != 7235899] test__unit__fixedSequenceVarianceFieldsMatch() (gas: 285057)`<br><br>*fuzz:* `[FAIL: volatilityCumulative: algebra vs plank, tolerance 0: 1075855730087298 != 1075855727710910; counterexample: calldata=0xe187d208d84d...00d5 args=[97835655732304296718056894905525987774850650894266610447958184176342268018555 [9.783e76], 213]] test__fuzz__randomPathVarianceFieldsMatch(uint256,uint8) (runs: 0, μ: 0, ~: 0)` | **`volatilityCumulative: algebra vs plank, tolerance 0`** — both tests | **0** (2 passed, `runs: 256`) |

Restoration was verified by `git checkout --` then `git diff --stat` printing **nothing** for `Timepoint.plk` (byte-identical to HEAD, not "looks right"). `git diff --stat -- node_modules` also printed nothing — the reference was never touched.

### Three observations worth carrying forward

1. **Mutant A's unit failure is `100 != 200` — the stored field reads back exactly DOUBLED.** Packing one bit high and decoding at the true offset is a left-shift by one. Plank's own `pack_timepoint`/`unpack_timepoint` both read the constant, so they stay *self-consistent* under this mutant — the module is internally coherent and wrong. `getTwapTick` cannot see it. Only reading the STORED WORD at the real offset and diffing it against Algebra can. That is the entire justification for VDIFF-04 existing on top of the Phase 0-1 quotient diff.

2. **Mutant B's `9612287 != 7235899` are the state after the SECOND write, not the third.** `9612287` is Algebra's running cumulative (`2376388 + 7235899`); `7235899` is that write's delta **alone**. The fixed anchor performs three writes, but the assertion lives *inside* `_writeBoth`, so the test **aborts at the earliest write at which this mutant is capable of diverging at all** (it is provably invisible on write 1, where cumulative == delta). A driver asserting once at the end would still have gone red — but against the *third* write's state, saying nothing about where the accumulator first broke. **The "assert after EVERY write" requirement is load-bearing, and this is the evidence.**

3. **`runs: 0` appeared on both fuzz kills — and here it is NOT the 09-01 replay pathology.** The cache was cleared immediately before each; `runs: 0` means the fuzz died on its *first generated input*, which is expected for mutants this total (every input diverges). The distinguishing evidence: Mutant B's counterexample is **independent** of Mutant A's (seed `9.783e76`/`213` vs `3`/`222`), and — decisively — **both mutants also redden the NON-fuzz unit anchor**, which is cache-independent by construction and cannot be a replay even in principle. This is a strictly stronger position than 09-01's, which rested on the fuzz alone.

## Task Commits

1. **Task 1: Extract the timepoint unpacker to shared test infra** — `9c67793` (refactor)
2. **Task 2: The Algebra-vs-Plank-only full-timepoint variance diff** — `e6e4718` (test)
3. **Task 3: Falsifiability — both mutants observed RED, restored, green** — `eb98d48` (test)

## Files Created/Modified

- `test/market_state_measurements/TimepointDecoder.sol` — **created.** `library TimepointDecoder` + `struct PlankTimepoint`: THE single test-side unpacker. Offsets (`32/120/144/168/224/240`) verified by reading `src/types/market_state_measurements/Timepoint.plk:30-35` directly, **not** trusted from any doc. In-file docblock records *why* it is a library (it existed twice; VDIFF-04 needed a third) and that the offsets are **mirrored, not shared** — Plank's packing order is not Solidity's, so a layout change must move this file too, and VDIFF-04 is what makes that loud rather than silent.
- `test/market_state_measurements/RealizedVolatilityTimepoint.diff.t.sol` — **created** (247 lines, ≥100 required). `RealizedVolatilityTimepointDiffTest`: the two-way driver, the three-field tolerance-0 assertion, the fixed anchor, and the 256-run constructed fuzz — plus the in-file docblock recording why Algebra-vs-Plank only, why the oldest-index is excluded, why `delta >= 1` is load-bearing, why tolerance 0 is guaranteed *and regime-conditional*, what is deliberately Phase 10, and **WHAT THIS KILLS** (filled from observation).
- `test/market_state_measurements/RealizedVolatilitySmoke.t.sol` — **modified.** Minimal: import the decoder, delete the six `OFF_*` constants and `struct TP`, `_timepoint` delegates to `TimepointDecoder.decode`, `TP memory` → `PlankTimepoint memory`. Field names unchanged, so **no assertion moved**.
- `Makefile` — **modified.** Added `test-vol-timepoint-diff`; appended it to the END of `test-vol-prereqs` and to `.PHONY`. Existing prerequisites NOT reordered — `check-algebra-ref-pin` stays FIRST.
- `test/market_state_measurements/RealizedVolatility.diff.t.sol` — **deliberately UNTOUCHED** (`git diff --stat` empty). Phase 0-1's merged, verified driver; refactoring it is churn on a passing differential and out of scope for VDIFF-04.

## Verification (observed, not asserted)

| Check | Result |
|---|---|
| `make test-realized-vol-smoke` **BEFORE** the decoder extraction | exit **0** — **`11 passed; 0 failed`** |
| `make test-realized-vol-smoke` **AFTER** the decoder extraction | exit **0** — **`11 passed; 0 failed`** (unchanged), incl. `[PASS] test__unit__storedNegativeTickSignExtends` and `[PASS] test__unit__negativeAvgTickVolatilityIsExact` — the two tests a botched sign/offset extraction would redden |
| `make test-vol-timepoint-diff` | exit **0** — `[PASS] test__unit__fixedSequenceVarianceFieldsMatch`, `[PASS] test__fuzz__randomPathVarianceFieldsMatch (runs: 256)` |
| `make test-vol-prereqs` | exit **0** end-to-end; `OK: Algebra reference pin intact (4 files, v2.2.0)` printed **before** any forge invocation. MarketStatistics 7/7, Smoke 11/11, Diff 2/2, Probe 1/1, Kernel fuzz 1/1, Timepoint diff 2/2 |
| `make check-algebra-ref-pin` | exit **0** — all 4 files OK. **The baseline did not move; nothing was re-pinned.** |
| `grep -c "MarketStatisticsUniV3Ref\|uni\."` | **0** — the UniV3 ref is NOT driven |
| `grep -c "oldestIndex"` | **0** — the vacuous field is not asserted (and not even named) |
| `grep -c "vm.assume"` | **0** — corpus CONSTRUCTED, not filtered |
| `grep -c "172800\|2 \* WINDOW\|2\*WINDOW"` | **0** — Phase 10 NOT pulled forward |
| three field assertions | **1** each (`volatilityCumulative` / `averageTick` / `windowStartIndex` `: algebra vs plank`) |
| `_assertVarianceFieldsMatch();` | present in **BOTH** `_initBoth` (line 124) and `_writeBoth` (line 130) |
| `delta` bound + `assertGt(volA, 0` | **1** each — `delta >= 1` always; non-vacuity asserted, not assumed |
| `git diff --stat` on `RealizedVolatility.diff.t.sol` | **empty** — Phase 0-1's driver untouched |
| `git diff --stat` on `Timepoint.plk` + `node_modules` | **empty** — no mutant residue |

**No acceptance criterion in this plan was "it compiles".** `forge build` appeared only as an implicit precondition of running the tests.

## Decisions Made

- **The hand-derived anchor was verified before being written down as fact.** The plan supplies a derivation (`avgTick1 = -400`, `vol = 2,376,388` at the first write) and mandates asserting only `> 0`. Rather than copy the derivation into the docblock on trust, it was **checked empirically** with a temporary exact assertion (`assertEq(avgA, -400)`, `assertEq(volA, 2376388)`) — **both passed** — and the probe was then removed and the assertion relaxed to the mandated `assertGt(volA, 0)`. A derivation written into a comment unverified is just a plausible-looking claim.
- **The `WHAT THIS KILLS` docblock was committed PENDING.** Task 2's commit (`e6e4718`) deliberately says "PENDING OBSERVATION … deliberately does NOT yet claim any kill", and Task 3 (`eb98d48`) filled it in from the observed output. Writing "OBSERVED RED" before observing it would have been the exact failure mode this phase exists to prevent.
- **A wrong inference was caught and discarded rather than shipped.** See Findings 2.
- **The plan's own grep criteria conflicted with quoting the verbatim FAIL lines in-file.** Resolved in favour of *both* requirements (Deviations #1).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's acceptance criteria were self-defeating on the assertion-message greps**
- **Found during:** Task 3
- **Issue:** The plan requires `grep -c "volatilityCumulative: algebra vs plank"` and `grep -c "averageTick: algebra vs plank"` to print **exactly 1**, *and* requires the `WHAT THIS KILLS` docblock to record the observed mutant failures. Quoting the verbatim `[FAIL: ...]` lines in the docblock reproduces the assertion messages, so both greps printed **2** — the file was correct in substance but failed its own gate. (Same family as 09-01's `vm.assume` self-defeat.)
- **Fix:** The docblock now *paraphrases* ("failing the averageTick assertion (algebra vs plank, tolerance 0) with `100 != 200`") and points at this SUMMARY for the verbatim lines, with an in-file note explaining *why* it is phrased that way so a future reader does not "fix" it back and re-break the gate. The **verbatim** lines live here in the SUMMARY, where the plan's `<output>` block mandates them.
- **Files modified:** `test/market_state_measurements/RealizedVolatilityTimepoint.diff.t.sol`
- **Verification:** all three greps → `1`; `make test-vol-timepoint-diff` exit 0.
- **Committed in:** `eb98d48` (Task 3 commit)

**2. [Rule 3 - Blocking] Backticks in a `git commit -m` message executed as shell commands**
- **Found during:** Task 3
- **Issue:** The Task 3 commit message used backticks around `` `+=` ``, `` `=` `` and `` `make compile-plank` ``. Bash ran them as command substitution: `+=: command not found`, and **`make compile-plank` actually executed**, injecting its build log into the commit message. The commit landed mangled.
- **Fix:** Amended with `git commit --amend -F <file>`, no shell interpretation. Message verified by `git log -1 --format=%B`.
- **Impact on the mutant evidence: NONE.** The accidental `compile-plank` ran *after* both mutants were already applied, observed, restored and re-verified green — it is not in the causal path of any RED, and `build/plank/` is untracked and read by nothing in the test path. The claim "no `make compile-plank` between mutants" remains true and is restated honestly here rather than quietly omitted.
- **Files modified:** none (commit message only)
- **Committed in:** `eb98d48` (amended)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking). No Rule 4 (architectural) situations arose. No criterion was weakened.

## Findings — report, do not smooth over

**FINDING 1 (no divergence): the diff found NO divergence between Algebra and Plank.** Fixed anchor + 256 fuzz runs, tolerance 0, asserting three fields after init and after every write — zero counterexamples. Per the standing instruction, a real divergence would have been the most valuable output available; there wasn't one, and **nothing was adjusted to manufacture the green** (no tolerance added, no field dropped, no assertion relaxed). The pass is corroborated, not merely trusted, by the two observed REDs: the same configuration kills both mutants immediately, on both the fuzz *and* the cache-independent unit anchor. Given 09-01 proved the kernel bit-exact, this result means the **write path** (packing, accumulation, windowing) also agrees over this corpus — but note the corpus is deliberately non-vacuous only; the windowed regimes remain **Phase 10**, so this is not a claim about `calculate_avg_tick`'s interpolation branch.

**FINDING 2 (a wrong inference, caught before it shipped):** Mutant B's unit failure `9612287 != 7235899` has difference `2376388` — *exactly* the independently verified first-write accrual. The tempting inference was "the second write accrues 0 volatility", which would have meant the anchor was weaker than it looks. **That inference was wrong, and was checked instead of written up.** A temporary per-write probe showed accrual `2376388 / 7235899 / 12625` — all non-zero. The true explanation is better: the assertion fires *inside* `_writeBoth`, so the test aborts at the **second** write, and `9612287` (Algebra's cumulative after two writes) is being compared against `7235899` (that write's delta alone). The coincidence is arithmetic, not degeneracy. **Recorded because the near-miss is the point:** a plausible number pattern nearly became a false claim about corpus quality, and only executing the check prevented it.

**FINDING 3 (tooling, silent no-op — matters for Phases 10-11):** `gsd-tools roadmap update-plan-progress 09` reported `"status": "Complete", "complete": true` **but wrote nothing to ROADMAP.md** — it does not match this roadmap's `| 9. <name> | 0/TBD | Not started | - |` row format. This was caught by checking `git diff` instead of trusting the command's success output; the Phase 9 row was then updated by hand to `2/2 | Complete | 2026-07-16`. Likewise `gsd-tools state advance-plan` **errored** (`Cannot parse Current Plan or Total Plans in Phase from STATE.md`) against this STATE.md's prose format, leaving the body still reading "09-01 COMPLETE / Phase 9 IN PROGRESS" while the frontmatter counters had advanced — the prose was reconciled by hand. **A tool reporting success is not evidence the file changed** — same family as every other lesson in this phase. Both logged to `deferred-items.md`.

**FINDING 4 (scope, not acted on):** the ROADMAP v2.0 progress table's **Phase 8** row still reads `0/3 | Planned | -` although Phase 8 is COMPLETE. Pre-existing staleness, unrelated to 09-02; **not fixed** (only the Phase 9 row was in scope). Logged to `deferred-items.md` for whoever verifies Phase 8.

**FINDING 5 (scope, not acted on):** two **pre-existing** diagnostics in `RealizedVolatilitySmoke.t.sol`, verified against HEAD as predating this plan (solc `Warning (2072): Unused local variable` at the first `_last()` read in `test__unit__timestampBelowWindowDoesNotInvertComparator`, and a forge-lint `unused-import` for `console2`). The refactor only renamed the unused local's type; it did not introduce either. **Out of scope, not fixed**, logged to `.planning/phases/09-variance-kernel-unit-diff-full-timepoint-diff/deferred-items.md`. Flagged because the unused `t` is a *dead read of pre-write state* that the test's own comment describes but never asserts — a small latent coverage gap, not a defect.

## Issues Encountered

- **The commit-message backtick execution** (Deviations #2) — the only real blocker; it also caused an unintended `make compile-plank` run, which is disclosed above rather than omitted.
- **The self-defeating grep criteria** (Deviations #1) — resolved by honouring both requirements rather than dropping either.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **VDIFF-04 is discharged.** ROADMAP **SC-3 holds**: the Algebra-vs-Plank-only driver asserts exact tolerance-0 agreement on `volatilityCumulative`, `averageTick` and `windowStartIndex` after every write, read via `getTimepoint`/`getTimepointPacked` (**not** a Solidity storage mirror), with the oldest-index excluded as vacuous and UniV3 not driven.
- **ROADMAP SC-4 is now COMPLETE by observation.** All three named mutants are killed: 09-01's kernel coefficient `6→7`, plus 09-02's timepoint packing corruption and stopped `volatilityCumulative` accumulation. Baseline and restored source green in every case.
- **The unpacker exists in exactly ONE place** — `test/market_state_measurements/TimepointDecoder.sol`. Phase 10/11 must **reuse it**, not copy it. (Phase 0-1's `RealizedVolatility.diff.t.sol` retains its partial 3-field inline unpack by deliberate scope decision; folding it in is available as future cleanup on a passing test.)
- **Phase 10 is unblocked and its scope is intact:** the `span > 2×WINDOW` corpus and the sub-WINDOW `u32_sub` corpus were **not** pulled forward. This driver is non-vacuous but does **not** execute `calculate_avg_tick`'s WINDOW-interpolation branch — Phase 10 still owns that, and should not read this green as covering it.
- **Carry forward for Phase 11's battery:** clear `cache/fuzz` when proving a kill, **and** prefer keeping a non-fuzz unit anchor alongside each fuzz — it is cache-independent by construction, so it cannot be a replay even in principle. That is what made this plan's kills stronger than 09-01's.
- **No blockers.** The Algebra pin exits 0; the baseline did not move.

## Self-Check: PASSED

Every claim above was re-verified against disk and git, not trusted:

- Files exist: `test/market_state_measurements/TimepointDecoder.sol`, `test/market_state_measurements/RealizedVolatilityTimepoint.diff.t.sol` (247 lines, ≥100 required), `Makefile`, this SUMMARY.
- Commits exist: `9c67793`, `e6e4718`, `eb98d48`.
- `contract RealizedVolatilityTimepointDiffTest` present (1 match); `library TimepointDecoder` present (1 match).
- key_links present: `TimepointDecoder.decode` (diff test + smoke test), `alg.getTimepoint`, `test-vol-timepoint-diff:` in Makefile.
- Final gates re-run on the restored tree: `make test-vol-timepoint-diff` exit 0 (2 passed, runs 256), `make test-vol-prereqs` exit 0, `make check-algebra-ref-pin` exit 0, `make test-realized-vol-smoke` 11/11, no mutant residue in `Timepoint.plk` or `node_modules`.

---
*Phase: 09-variance-kernel-unit-diff-full-timepoint-diff*
*Completed: 2026-07-16*
