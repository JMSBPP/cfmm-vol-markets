---
phase: 08-reference-integrity-kernel-mock
verified: 2026-07-16T13:13:44Z
status: passed
score: 8/8 must-haves verified (all independently re-derived, none inherited from SUMMARYs)
gaps: []
human_verification: []
notes:
  - "STATE.md / deferred-items.md carry a stale blocker: 'package-lock.json is UNTRACKED' — this
     was fixed by commit ffcc3b6 (tracked package.json + package-lock.json), which landed BEFORE
     STATE.md's own last edit (63d7c53), yet STATE.md still lists it as an unresolved 'NEW' blocker
     requiring resolution before Phase 9. Does not affect any artifact's correctness (independently
     re-verified: `make check-algebra-ref-pin` passes check #3 today, reading the now-tracked
     lockfile) — flagged as a documentation staleness item, not a phase gap."
---

# Phase 8: Reference Integrity & Kernel Mock Verification Report

**Phase Goal:** The differential baseline can no longer move under the suite, the internal
variance kernel is callable in isolation, and the wrong scalar-vol diff surface is removed — so
every later diff compares like-for-like against a stable reference.
**Verified:** 2026-07-16T13:13:44Z
**Status:** passed
**Re-verification:** No — initial verification

## Zero-Trust Method Note

Every claim below was re-derived by a command I ran myself in this session, not read out of a
SUMMARY. Where a SUMMARY's claim could not be independently reproduced, that is stated explicitly.
Mutants were applied by me, from scratch, independent of the plans' exact scripted sequences (I
picked my own transitive-only-file mutant and my own closure-growth mutant, and ran the argument-
order mutant on the harness myself rather than trusting the recorded table).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence (command I ran myself) |
| --- | --- | --- | --- |
| 1 | `make check-algebra-ref-pin` exits 0 on the current tree | ✓ VERIFIED | Ran it directly: `OK: Algebra reference pin intact (4 files, v2.2.0)`, exit 0 |
| 2 | The pin actually goes RED when the reference moves, including on a transitive-only file (not just `VolatilityOracle.sol`) | ✓ VERIFIED | I appended a comment to `interfaces/IVolatilityOraclePluginImplementation.sol` (my own mutant, not the plan's literal `printf` string) → `make check-algebra-ref-pin` exited **2**, error `interfaces/IVolatilityOraclePluginImplementation.sol: FAILED`. Restored → exit **0**. `git status --porcelain \| grep node_modules` returned nothing (clean). |
| 3 | The pin covers the FULL 4-file closure the harness links, not a subset | ✓ VERIFIED | I independently derived the closure by grepping `^import` in `test/MarketStatisticsTest.t.sol` (3 entry imports) and in all 4 candidate files. Result: `VolatilityOraclePluginImplementation.sol` imports the other 3; `libraries/VolatilityOracle.sol` imports nothing; `libraries/VolatilityOracleStorage.sol` imports `./VolatilityOracle.sol`; the interface file imports nothing. Closure is exactly these 4, self-contained. Manifest (`test/refs/algebra-volatility-oracle.sha256`) lists exactly these 4 paths — I read the file directly. |
| 4 | Closure cannot silently grow — a new import added to a pinned file is caught | ✓ VERIFIED | I added `import "./VolatilityOracleInteractions.sol";` to `libraries/VolatilityOracle.sol` myself → exit **2**, both the content-hash check AND the drift guard fired independently (`ERROR: Algebra reference closure GREW: libraries/VolatilityOracle.sol imports unpinned libraries/VolatilityOracleInteractions.sol.`). Restored → exit 0, `git status --porcelain` clean. |
| 5 | The pin check runs FIRST in `make test-vol-prereqs`, before any diff | ✓ VERIFIED | `make -n test-vol-prereqs \| head -3` — first recipe line is `bash script/check-algebra-ref-pin.sh`. `grep -n "^test-vol-prereqs:" Makefile` confirms `check-algebra-ref-pin` is the first prerequisite token. |
| 6 | Algebra's `_volatilityOnRange` (`internal pure`) is callable in isolation via a distinctly-named mock, and agrees with Plank's `calculate_realized_volatility` at tolerance 0 on a non-degenerate input | ✓ VERIFIED | Read `test/mocks/AlgebraVolatilityKernelMock.sol` (name `AlgebraVolatilityKernelMock`, distinct from the package's shipped `test/MockVolatilityOracle.sol` — confirmed by grep, which does NOT expose `_volatilityOnRange`). Ran `make test-vol-kernel-probe` myself: `[PASS] test__unit__kernelProbeAlgebraEqualsPlankNonDegenerate (gas: 12023)`. Independently recomputed the anchor via a standalone Python script from Algebra's own formula (k=-350, b=1500, num=4,424,925,000, den=5400, truncated quotient = **819430**) — matches the test's asserted anchor exactly. k≠0 and b≠0 both hold (non-degenerate on both axes, not just `tick0≠tick1`). |
| 7 | The probe fails under an argument-order mutant (proves it's genuinely wired, not two independently-correct constants) | ✓ VERIFIED | I mutated `RealizedVolatilityKernelHarness.plk`'s call site myself, from `calculate_realized_volatility(avg_tick0, avg_tick1, tick0, tick1, dt)` to Algebra's order `(dt, tick0, tick1, avg_tick0, avg_tick1)`, WITHOUT running `make compile-plank` first (to independently test the STATE.md-corrected claim that `deployPlank` recompiles via FFI at test time, not from stale `build/plank/*.hex`). Result: `forge test --match-contract RealizedVolatilityKernelProbeTest` → exit **1**, `[FAIL: kernel: plank vs algebra, tolerance 0: 115792...585162 != 819430]`. This independently corroborates the STATE.md-corrected claim (Plank's return value changed with no intervening compile-plank — a dead/stale harness could not have produced a different, wrapped value). Restored → exit 0, `[PASS]`, `git diff --stat` on the harness file after restore showed no residual diff. |
| 8 | No test-side surface diffs Plank's raw `get_average_volatility` against Algebra's window-normalized `getAverageVolatility`, and the smoke suite is unaffected | ✓ VERIFIED | `grep -rn "assertEq.*getAverageVolatility\|getAverageVolatility.*assertEq" --include=*.sol test/` → no matches (exit 1). `grep -rn "function getAverageVolatility" test/` → only `MarketStatisticsTest.t.sol:175` (`getAverageVolatilityLast`, the KEEP target, unrelated). Read `RealizedVolatilitySmoke.t.sol` directly: the `IRealizedVolatility` interface no longer declares `getAverageVolatility`; a 20-line doc block is in its place explaining the raw-vs-window-normalized distinction, the differing selectors, and pointing at the stored `volatilityCumulative` field. Ran `make test-realized-vol-smoke` myself: `11 passed; 0 failed; 0 skipped` (matches the SUMMARY's before/after claim of 11→11, independently reproduced, not inherited). `grep -rn "bessel\|Bessel" --include=*.plk src/` → no matches: no port exists. |

**Score:** 8/8 truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/refs/algebra-volatility-oracle.sha256` | 4-line manifest of the closure | ✓ VERIFIED | Read directly: exactly 4 lines, the 4 closure paths, matches `sha256sum` of the current `node_modules` copy |
| `script/check-algebra-ref-pin.sh` | 3-check red-on-divergence guard | ✓ VERIFIED | Read in full; all 3 checks (content pin, closure-drift, package identity) present and independently exercised above (checks 1 and 2 both fired on my closure-growth mutant) |
| `Makefile` (`check-algebra-ref-pin` target + wiring) | first prerequisite of `test-vol-prereqs` | ✓ VERIFIED | `grep -n "^test-vol-prereqs:"` and `make -n` output both confirm |
| `test/mocks/AlgebraVolatilityKernelMock.sol` | external wrapper over `_volatilityOnRange`, `solc =0.8.20` | ✓ VERIFIED | Read in full; `pragma solidity =0.8.20;`, thin passthrough, name distinct from package's `MockVolatilityOracle` |
| `test/market_state_measurements/RealizedVolatilityKernelHarness.plk` | ABI-reachable Plank kernel entrypoint | ✓ VERIFIED | Read in full; `init {` present, selector `0xc6342af0` independently confirmed via `cast sig "volatilityOnRange(int256,int256,int256,int256,int256)"` run myself, byte-identical to the declared constant |
| `test/market_state_measurements/RealizedVolatilityKernel.probe.t.sol` | differential probe, tolerance 0 + anchor | ✓ VERIFIED | Read in full; `assertEq(got, exp, ...)`, `assertEq(exp, EXPECTED_VOL)` with `EXPECTED_VOL = 819430` (independently recomputed), `assertTrue(exp != 0)` non-degeneracy guard |
| `test/market_state_measurements/RealizedVolatilitySmoke.t.sol` | VDIFF-03 diff-surface removed + documented | ✓ VERIFIED | Read in full; declaration gone, 20-line doc block in its place |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Makefile:test-vol-prereqs` | `script/check-algebra-ref-pin.sh` | make prerequisite, FIRST | ✓ WIRED | `make -n test-vol-prereqs` shows it as the first recipe line |
| `script/check-algebra-ref-pin.sh` | `test/refs/algebra-volatility-oracle.sha256` | `sha256sum -c` | ✓ WIRED | Read script directly: `cd "$REF" && sha256sum -c "$MANIFEST"`; confirmed live by my own mutant runs |
| `test/mocks/AlgebraVolatilityKernelMock.sol` | `@cryptoalgebra/volatility-oracle-plugin/libraries/VolatilityOracle.sol` | library internal call | ✓ WIRED | `VolatilityOracle._volatilityOnRange(dt, tick0, tick1, avgTick0, avgTick1)` present verbatim; probe result (12023 gas, non-reverting, value-correct) proves the call actually executes |
| `RealizedVolatilityKernel.probe.t.sol` | `RealizedVolatilityKernelHarness.plk` | `deployPlank` FFI | ✓ WIRED | Proved by my own argument-order mutant: Plank's *returned value changed* when the `.plk` source changed, with no intervening `make compile-plank` — a dead/undeployed harness could not exhibit this |
| `RealizedVolatilitySmoke.t.sol` interface | `IRealizedVolatility` (no `getAverageVolatility`) | absence of declaration | ✓ WIRED (absence confirmed) | Read the interface block directly; the declaration is gone, replaced by documentation |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| VDIFF-01 | 08-01 (pin half) + 08-02 (mock half) | Pin the Algebra reference closure + mock compiles under `solc =0.8.20` | ✓ SATISFIED | Both halves independently re-verified above (truths 1-7). REQUIREMENTS.md marks `[x]`; no orphaning — 08-01 deliberately left it unchecked and 08-02 is the plan that closed it, per both SUMMARYs and confirmed by reading the requirement's checkbox state directly |
| VDIFF-03 | 08-03 | Remove the raw-vs-normalized diff surface + document | ✓ SATISFIED | Truth 8 above. REQUIREMENTS.md carries an honest AS-BUILT CORRECTION noting the named "incorrect assertion" never existed — I independently re-ran the same survey grep (`getAverageVolatility\|get_average_volatility` across `test/` and `src/`) and got the identical result set the SUMMARY reported, so the correction is not a checkbox ticked against fiction — it is accurate |

No orphaned requirements: the phase's declared IDs (VDIFF-01, VDIFF-03) exactly match what the two PLAN frontmatters claim (08-01: `[VDIFF-01]`, 08-02: `[VDIFF-01]`, 08-03: `[VDIFF-03]`), and both are marked `[x]` in REQUIREMENTS.md with `Phase 8 | Complete` in the traceability table.

### Anti-Patterns Found

Grepped all 7 phase-touched files for `TODO|FIXME|XXX|HACK|PLACEHOLDER` (case-insensitive) — no matches in any file. No stub returns, no empty handlers, no console.log-only implementations found in the mock, harness, probe, or checker script.

### STATE.md Coherence (cross-cutting check)

08-01 and 08-03 ran concurrently in wave 1 and both edited STATE.md. I read the final STATE.md
directly: it correctly reflects all 3 plans complete, records distinct decision entries for 08-01,
08-02, and 08-03 without contradiction, and carries the corrected (not the original false)
"stale bytecode" diagnosis from 08-02 with an explicit `[CORRECTED after execution...]` marker. No
double-counting or dropped entries found — this looks coherent, not merely assumed coherent.

One genuine staleness item found (not a phase gap, flagged above in frontmatter `notes`):
STATE.md's "Blockers/Concerns" section still lists "`package-lock.json` is UNTRACKED" as an
unresolved **NEW** blocker requiring resolution before Phase 9 relies on `make test-vol-prereqs` in
CI — but commit `ffcc3b6` (`build: track package.json + package-lock.json`) landed at 08:59:29,
*before* STATE.md's own last commit (`63d7c53` at 09:06:46), which should have picked up the fix.
Independently confirmed the underlying pin still works correctly today regardless (check #3 reads
the now-tracked lockfile without issue) — this is a documentation lag, not a functional gap.

### Human Verification Required

None. Every truth above was mechanically re-derived (exit codes, grep results, independently
recomputed arithmetic, and my own from-scratch mutants) rather than relying on visual, timing, or
subjective judgment.

### Gaps Summary

No gaps found. All 8 derived truths for VDIFF-01 (pin + mock) and VDIFF-03 were independently
re-verified against the live codebase, not read out of SUMMARYs:

- The pin (`make check-algebra-ref-pin`) exits 0 today, and I personally drove it RED with two
  mutants I designed myself (a transitive-only-file edit, and a closure-growing import) and
  restored it to GREEN both times, leaving no `node_modules` residue.
- The mock (`AlgebraVolatilityKernelMock`) is distinctly named, compiles under `=0.8.20`, and its
  differential probe passes with an anchor (819430) I recomputed independently from Algebra's
  documented formula — not copied from the SUMMARY's arithmetic. I personally applied the
  argument-order mutant to the harness and watched the probe go red without running
  `make compile-plank` first, independently corroborating the STATE.md-corrected claim about
  `deployPlank`'s FFI recompile-at-test-time behavior.
- VDIFF-03's diff-enabling declaration is gone from `IRealizedVolatility`, documented in-file, and
  the smoke suite is unchanged at 11/11 — I ran it myself rather than trusting the recorded count.
  No Bessel/window-normalization port exists anywhere in `.plk` sources.
- `make test-vol-prereqs` runs green end-to-end today (pin → 7 market-statistics → 11 smoke → 2
  diff → 1 kernel probe), with the pin gating first.

The only finding worth carrying forward is the STATE.md staleness noted above — recommend a
one-line STATE.md update before Phase 9, not a re-open of Phase 8.

---

*Verified: 2026-07-16T13:13:44Z*
*Verifier: Claude (gsd-verifier)*
