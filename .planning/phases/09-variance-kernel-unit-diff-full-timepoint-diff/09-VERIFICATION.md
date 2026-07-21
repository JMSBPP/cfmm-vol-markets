---
phase: 09-variance-kernel-unit-diff-full-timepoint-diff
verified: 2026-07-16T18:30:00Z
status: passed
score: 9/9 must-haves verified
---

# Phase 9: Variance Kernel Unit-Diff & Full-Timepoint Diff Verification Report

**Phase Goal:** The variance kernel is proven bit-exact against Algebra in isolation, and the full stored timepoint is proven bit-exact after every write — with both proofs demonstrated falsifiable, not merely green.
**Verified:** 2026-07-16T18:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Method

Every claim below was re-derived from the codebase and from commands **I ran myself** in this
session, not copied from either SUMMARY. Both mutants in 09-01 and both mutants in 09-02 were
independently re-applied (from unmodified source, by me, with `cache/fuzz` cleared immediately
before each run), observed RED with my own eyes, restored, and re-confirmed green. The tree was
left clean and verified so (`git diff --stat` empty on every touched file) before this report was
written.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A fuzz drives ONE `(dt, tick0, tick1, avgTick0, avgTick1)` tuple through both Algebra's `_volatilityOnRange` and Plank's `calculate_realized_volatility`, asserting FULL uint256 equality at tolerance 0 | ✓ VERIFIED | `make test-vol-kernel-fuzz` run by me: `[PASS] test__fuzz__kernelAlgebraEqualsPlankFiveDim(uint32,int32,int32,int32,int32) (runs: 1024, μ: 14784, ~: 14747)`. `grep -c "uint88"` on the test file = 0 (assertion is on the full word); `assertEq(got, exp` present. |
| 2 | `dt` bounded to `[1, 2^32)` by construction, excluding the known `dt=0` divergence | ✓ VERIFIED | `DT_MIN=1; DT_MAX=4294967295` constants read directly from the file; `bound(uint256(dtRaw), DT_MIN, DT_MAX)` present; docblock states the Panic-0x12-vs-silent-SDIV-0 rationale. |
| 3 | Ticks int24-bounded; non-degeneracy secures BOTH `k != 0` AND `b != 0` (not just `tick0 != tick1`) | ✓ VERIFIED | Read the test body: `avgTick0` repaired against `tick0` (secures `b`), `tick1` repaired against the `k` expression directly (secures `k`), both `assertTrue(k != 0, ...)` and `assertTrue(b != 0, ...)` present and executed every run — this is a stronger construction than "tick0 != tick1 alone," which the plan explicitly called out as an insufficient gap. |
| 4 | Mutant swapping the harness call-site argument order to Algebra's order makes the fuzz FAIL | ✓ VERIFIED (re-derived, not trusted) | I applied the edit myself to `RealizedVolatilityKernelHarness.plk:49`, cleared `cache/fuzz`, ran `make test-vol-kernel-fuzz` → **exit 2**, `[FAIL: ... 115792089237316195423570985008687907853269984665640563584076248285097938211044 != 312714267225060268775 ...]`. Restored via `git checkout --`, `git diff --stat` empty, re-ran → **exit 0**, `runs: 1025`, PASS. (Counterexample differs from the SUMMARY's own recorded one — expected, since fuzz seeds are not fixed across runs — but the failure mode and near-2^256 divergence class match exactly.) |
| 5 | Mutant changing the kernel middle-term coefficient `6 -> 7` makes the fuzz FAIL | ✓ VERIFIED (re-derived, not trusted) | I applied the edit myself to `RealizedVolatilityLib.plk:32`, cleared `cache/fuzz`, ran `make test-vol-kernel-fuzz` → **exit 2**, `[FAIL: ... 35887063659607857 != 37354578926687453; ... args=[90837452, -96, 179192735, -2594, -4]]` — a counterexample independent of the Mutant-A one. Restored, `git diff --stat` empty, re-ran → **exit 0**, `runs: 1025`, PASS. |
| 6 | `make check-algebra-ref-pin` still exits 0 — the baseline did not move | ✓ VERIFIED | Ran it directly, standalone and after the full mutant battery: `OK: Algebra reference pin intact (4 files, v2.2.0)`, exit 0 both times. |
| 7 | ONE shared decoder unpacks Plank's packed timepoint word — offsets exist in exactly one place in `test/` | ✓ VERIFIED | `test/market_state_measurements/TimepointDecoder.sol` offsets (`OFF_VOL=32, OFF_TICK=120, OFF_AVG_TICK=144, OFF_TICK_CUM=168, OFF_WSI=224, OFF_INIT=240`) checked byte-for-byte against `src/types/market_state_measurements/Timepoint.plk:30-35` (`OFF_REALIZED_VOL=32, OFF_TICK=120, OFF_AVG_TICK=144, OFF_TICK_CUMULATIVE=168, OFF_WINDOW_START_INDEX=224, OFF_INITIALIZED=240`) — exact match, including the SIGN-EXTENDED int24/int56 cast pattern (`int24(uint24(...))`, `int56(uint56(...))`). `grep -cE "^\s*uint256 constant OFF_" RealizedVolatilitySmoke.t.sol` = 0; `grep -cE "struct TP \{"` = 0; smoke file delegates via `TimepointDecoder.decode`. |
| 8 | An Algebra-vs-Plank-ONLY driver applies the same `(timestamp, tick)` sequence to both; UniV3 is NOT driven | ✓ VERIFIED | `grep -c "MarketStatisticsUniV3Ref\|uni\."` on `RealizedVolatilityTimepoint.diff.t.sol` = 0. `setUp` reads directly: only `MarketStatisticsAlgebraRef` and `IPlankOracle` are constructed. |
| 9 | After EVERY write (and init), Algebra and Plank agree exactly on `volatilityCumulative`, `averageTick`, `windowStartIndex`; `oldestIndex` is NOT asserted | ✓ VERIFIED | `_assertVarianceFieldsMatch()` is called inside BOTH `_initBoth` (line 147) and `_writeBoth` (line 153) — confirmed by direct grep with line numbers. `grep -c "oldestIndex"` on the diff test = 0 (not even named). Ran `make test-vol-timepoint-diff` myself: `[PASS] test__unit__fixedSequenceVarianceFieldsMatch()`, `[PASS] test__fuzz__randomPathVarianceFieldsMatch (runs: 256)`. |
| 10 | Corpus is non-vacuous: fixed prefix guarantees `volatilityCumulative > 0`; consecutive ticks never repeat; timestamps strictly increasing/distinct | ✓ VERIFIED | `assertGt(volA, 0, ...)` present in the fixed-anchor test; the fuzz's non-vacuity prefix (`lastTick -= 500` or `+= 500` before the loop) and per-iteration repair (`if (next == lastTick) next = ...`) read directly from source; `_deltaAt` bounds to `[1, 3600]`, never 0. |
| 11 | Mutant corrupting the timepoint packing (`OFF_AVG_TICK 144 -> 145`) makes the diff FAIL | ✓ VERIFIED (re-derived, not trusted) | I applied the edit myself to `Timepoint.plk:32`, cleared `cache/fuzz`, ran `make test-vol-timepoint-diff` → **exit 2**. Unit anchor: `[FAIL: averageTick: algebra vs plank, tolerance 0: 100 != 200] test__unit__fixedSequenceVarianceFieldsMatch()` — **exact match** to the SUMMARY's claimed number. Fuzz also failed on the same assertion with an independent counterexample. Restored, `git diff --stat` empty, re-ran → **exit 0**, both tests PASS. |
| 12 | Mutant stopping `volatilityCumulative` accumulation makes the diff FAIL | ✓ VERIFIED (re-derived, not trusted) | I applied the edit myself to `Timepoint.plk:115` (`vol: @evm_add(...) & MASK_U88` → `vol: realized_vol_delta.vol & MASK_U88`), cleared `cache/fuzz`, ran `make test-vol-timepoint-diff` → **exit 2**. Unit anchor: `[FAIL: volatilityCumulative: algebra vs plank, tolerance 0: 9612287 != 7235899] test__unit__fixedSequenceVarianceFieldsMatch()` — **exact match** to the SUMMARY's claimed number, confirming the accumulation-mutant diagnosis is real, not a post-hoc rationalization. Restored, `git diff --stat` empty, re-ran → **exit 0**, both tests PASS. |
| 13 | `make check-algebra-ref-pin` still exits 0 after the 09-02 mutant battery — baseline did not move | ✓ VERIFIED | Ran it directly after restoring `Timepoint.plk`: `OK: Algebra reference pin intact (4 files, v2.2.0)`, exit 0. |

**Score:** 13/13 truths verified (consolidated to 9 must-haves in frontmatter per the PLAN's two `must_haves` blocks; every individual claim independently re-derived).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `test/market_state_measurements/RealizedVolatilityKernel.diff.t.sol` | The 5-D variance-kernel differential fuzz (VDIFF-02) | ✓ VERIFIED | `contract RealizedVolatilityKernelDiffTest` present; 165 lines (≥80 required); ran and passed at 1024 runs myself; killed by 2 independently-applied mutants. |
| `test/market_state_measurements/RealizedVolatilityTimepoint.diff.t.sol` | The Algebra-vs-Plank-only full-timepoint variance diff (VDIFF-04) | ✓ VERIFIED | `contract RealizedVolatilityTimepointDiffTest` present; 247 lines (≥100 required); ran and passed myself (fixed anchor + 256-run fuzz); killed by 2 independently-applied mutants. |
| `test/market_state_measurements/TimepointDecoder.sol` | The single shared unpacker for Plank's packed timepoint word | ✓ VERIFIED | `library TimepointDecoder` present; offsets checked byte-for-byte against `Timepoint.plk`'s authoritative layout (see Truth 7). |
| `Makefile` | `test-vol-kernel-fuzz`, `test-vol-timepoint-diff`, folded into `test-vol-prereqs`, pin FIRST | ✓ VERIFIED | Both targets present; `test-vol-prereqs: check-algebra-ref-pin test-market-statistics test-realized-vol-smoke test-vol-diff test-vol-kernel-probe test-vol-kernel-fuzz test-vol-timepoint-diff` — pin is first, both new targets appended at the end, not reordering existing prerequisites. Ran `make test-vol-prereqs` end-to-end myself: exit 0, every suite PASS. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `RealizedVolatilityKernel.diff.t.sol` | `AlgebraVolatilityKernelMock.sol` | `mock.volatilityOnRange(...)` | ✓ WIRED | Call present, both sides compared in `assertEq(got, exp, ...)`. |
| `RealizedVolatilityKernel.diff.t.sol` | `RealizedVolatilityKernelHarness.plk` | `deployPlank(...)` + selector `0xc6342af0` | ✓ WIRED | `setUp` deploys via `deployPlank("test/market_state_measurements/RealizedVolatilityKernelHarness.plk")`; harness selector independently re-derivable as `cast sig "volatilityOnRange(int256,int256,int256,int256,int256)"` (not re-run by me, but the harness's own header states it and the probe/fuzz both call through this ABI and pass). |
| `RealizedVolatilityTimepoint.diff.t.sol` | `TimepointDecoder.sol` | `TimepointDecoder.decode(plk.getTimepointPacked(li))` | ✓ WIRED | Call present in `_assertVarianceFieldsMatch`, result destructured into all three asserted fields. |
| `RealizedVolatilitySmoke.t.sol` | `TimepointDecoder.sol` | extracted unpacker replaces in-file copy | ✓ WIRED | `grep -c "TimepointDecoder"` ≥ 2 (import + call); `struct TP` and `OFF_*` constants removed (both greps = 0); smoke suite re-run by me at 11/11, unchanged. |
| `RealizedVolatilityTimepoint.diff.t.sol` | `MarketStatisticsTest.t.sol` | `alg.getTimepoint(li)` -> 7 fields | ✓ WIRED | Positional destructuring `(,,, uint88 volA,, int24 avgA, uint16 wsiA)` matches Algebra's documented return order; confirmed against zero divergence over 256+1 runs. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| VDIFF-02 | 09-01 | 5-D differential fuzz, kernel, tolerance 0, full uint256 | ✓ SATISFIED | Verified end-to-end myself (Truths 1-6). `.planning/REQUIREMENTS.md` marks `[x]` with description matching what was built; traceability table shows `VDIFF-02 | Phase 9 | Complete`. |
| VDIFF-04 | 09-02 | Algebra-vs-Plank-only full-timepoint variance diff, tolerance 0, after every write | ✓ SATISFIED | Verified end-to-end myself (Truths 7-13). `.planning/REQUIREMENTS.md` marks `[x]`; traceability table shows `VDIFF-04 | Phase 9 | Complete`. |

**Cross-reference against PLAN frontmatter:** 09-01 declares `requirements: [VDIFF-02]`; 09-02 declares `requirements: [VDIFF-04]`. No overlap, no orphan — both requirements mapped to Phase 9 in `.planning/REQUIREMENTS.md`'s traceability table are accounted for by exactly one plan each.

### Tooling Honesty Check (ZERO_TRUST_MANDATE finding #7)

I read the actual files rather than trusting either SUMMARY's narrative:

- **`.planning/REQUIREMENTS.md`** — read directly. VDIFF-02 and VDIFF-04 are both marked `[x]` with accurate descriptions (VDIFF-02's line matches what the diff test actually asserts; VDIFF-04's line correctly states the field list and the `oldestIndex` exclusion). The traceability table (lines 170-177) correctly shows `VDIFF-02 | Phase 9 | Complete` and `VDIFF-04 | Phase 9 | Complete`. **This file was genuinely updated, not left stale.**
- **`.planning/ROADMAP.md`** — read directly. The "Coverage" progress table (line 279) correctly shows `9. Variance Kernel Unit-Diff & Full-Timepoint Diff | 2/2 | Complete | 2026-07-16`. **However**, the earlier "## Phases" overview checklist (line 200) still shows `- [ ] **Phase 9: ...**` — an **un-flipped checkbox**, i.e. this file has two independent progress-tracking mechanisms and only one of them (the Coverage table) was updated for Phase 9. The same inconsistency exists for Phase 8 in the *opposite* direction (its overview bullet is `[x]` but its Coverage-table row still reads `0/3 | Planned | -`, which 09-02's own `deferred-items.md` already disclosed). **This is a genuine, additional documentation inconsistency I found independently** (the un-flipped Phase 9 overview checkbox was not called out in either SUMMARY or the deferred-items log). It does not affect the phase's actual technical deliverables — every test, mutant kill, and pin check above was independently re-run and passed — so it is reported as a MINOR documentation finding, not a gap.
- **`.planning/STATE.md`** — read directly. Frontmatter (`completed_phases: 3`, `total_plans: 7`, `completed_plans: 7`) and prose (`Current Position: Phase 9 ... COMPLETE`, `Progress: Phase 8 COMPLETE (3/3) — Phase 9 COMPLETE (2/2)`) are internally consistent and match the actual git history (5 commits across 08-01/02/03 and 09-01/02, all confirmed to exist via `git log --oneline -1 <hash>` for every commit hash cited in both SUMMARYs). **STATE.md was genuinely reconciled by hand, as both SUMMARYs claim** — I did not find a stale or contradictory statement in it for Phase 9.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `.planning/ROADMAP.md` | 200 | Overview checklist bullet for Phase 9 not flipped to `[x]` despite the Coverage table and STATE.md both correctly showing it complete | ℹ️ Info | Documentation-only; does not affect the phase's functional deliverables (all independently verified above). Flagging so it is not missed by whoever next edits ROADMAP.md. |
| — | — | No TODO/FIXME/placeholder/empty-implementation patterns found in any of the 5 files this phase touched (`RealizedVolatilityKernel.diff.t.sol`, `RealizedVolatilityTimepoint.diff.t.sol`, `TimepointDecoder.sol`, `RealizedVolatilitySmoke.t.sol`, `Makefile`) | — | — | Checked directly with `grep -n -E "TODO|FIXME|XXX|HACK|PLACEHOLDER"` and `grep -n -E "return null|=> \{\}"` style patterns — none found. |

### Human Verification Required

None. Every must-have in this phase reduces to a command exit code or a grep match, all of which
I ran and observed directly. No visual, UX, or external-service-dependent behavior is in scope for
this phase.

### Gaps Summary

No gaps found. All 9 must-haves (frontmatter) / 13 individual observable truths (detailed table)
are VERIFIED by commands I ran myself in this session — not by trusting either SUMMARY. Both
phase-01's two mutants (arg-order swap, kernel coefficient `6→7`) and phase-02's two mutants
(timepoint packing offset corruption, stopped accumulation) were independently re-applied from
clean source with `cache/fuzz` cleared before each, observed RED with the exact failure output
recorded, restored, and re-confirmed green. The `check-algebra-ref-pin` baseline never moved. The
tree is clean: `git diff --stat` is empty on every file this verification touched.

One MINOR, non-blocking documentation inconsistency was found and is reported above (ROADMAP.md's
overview checklist bullet for Phase 9, and separately Phase 8, not flipped despite the Coverage
table being accurate) — this does not affect goal achievement and is not structured as a gap.

---

*Verified: 2026-07-16T18:30:00Z*
*Verifier: Claude (gsd-verifier)*
