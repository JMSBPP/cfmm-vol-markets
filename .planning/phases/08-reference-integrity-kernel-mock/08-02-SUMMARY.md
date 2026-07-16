---
phase: 08-reference-integrity-kernel-mock
plan: 02
subsystem: test-infrastructure
tags: [vdiff, kernel, mock, differential, plank-harness, falsification]
requires:
  - "08-01: the pinned Algebra reference closure (the bytes this mock compiles against)"
provides:
  - "AlgebraVolatilityKernelMock — external handle on Algebra's internal pure _volatilityOnRange"
  - "RealizedVolatilityKernelHarness.plk — ABI handle on Plank's calculate_realized_volatility (selector 0xc6342af0)"
  - "make test-vol-kernel-probe — the proven-wired kernel pair Phase 9 fuzzes"
affects:
  - "Makefile:test-vol-prereqs (kernel probe appended after test-vol-diff)"
tech-stack:
  added: []
  patterns:
    - "harness takes the REFERENCE's argument order; the re-order lives at ONE commented call site"
    - "differential assertion + independent anchor: agreement alone cannot catch a mock that echoes the SUT"
    - "mutate the SOURCE and recompile — a mutant that never reaches bytecode proves nothing"
key-files:
  created:
    - test/mocks/AlgebraVolatilityKernelMock.sol
    - test/market_state_measurements/RealizedVolatilityKernelHarness.plk
    - test/market_state_measurements/RealizedVolatilityKernel.probe.t.sol
  modified:
    - Makefile
decisions:
  - "The harness takes calldata in ALGEBRA's order so ONE tuple drives both sides; the Algebra->Plank re-order is isolated to a single call site, making the footgun mutable-in-one-place and therefore falsifiable"
  - "Anchor 819430 asserted alongside the differential assertion — the differential alone would pass for a mock that echoed Plank"
  - "Kept the doc line the plan's own grep-count criterion contradicted, rather than deleting accurate documentation to satisfy a literal count"
metrics:
  duration: ~10 min
  tasks: 3
  files: 4
  completed: 2026-07-16
---

# Phase 8 Plan 02: Kernel Mock & Differential Probe Summary

Made Algebra's `internal pure` variance kernel and Plank's `calculate_realized_volatility` both
externally callable, and proved in one shot that the pair is **wired and agrees exactly** — with
the argument-order mutant **OBSERVED RED**, not asserted red.

## What was built

| Artifact | Purpose |
| --- | --- |
| `test/mocks/AlgebraVolatilityKernelMock.sol` | Thin external wrapper over `VolatilityOracle._volatilityOnRange`, `pragma =0.8.20` |
| `test/market_state_measurements/RealizedVolatilityKernelHarness.plk` | Plank entrypoint at selector `0xc6342af0`; owns the Algebra→Plank re-order |
| `test/market_state_measurements/RealizedVolatilityKernel.probe.t.sol` | The differential probe: mock == Plank, tolerance 0, + anchor |
| `Makefile:test-vol-kernel-probe` | Runs the probe; appended to `test-vol-prereqs` after `test-vol-diff` |

**Selector — `cast sig`-verified, not guessed:**

```
cast sig "volatilityOnRange(int256,int256,int256,int256,int256)"  ->  0xc6342af0
```
Declared literal matches byte-for-byte (diffed programmatically, not by eye).

## The falsification run — OBSERVED, not reasoned

The plan's central demand. The harness call site was mutated to Algebra's order
(`calculate_realized_volatility(dt, tick0, tick1, avg_tick0, avg_tick1)`), **recompiled through
`make compile-plank`** (a source edit alone would never have reached the deployed bytecode — the
mutant would have been theatre), and the probe re-run.

| State | Call site | `make test-vol-kernel-probe` | Observed |
| --- | --- | --- | --- |
| **Mutant** | `(dt, tick0, tick1, avg_tick0, avg_tick1)` | **exit 2 (RED)** | `[FAIL: kernel: plank vs algebra, tolerance 0: 1157920892...122585162 != 819430]` |
| **Restored** | `(avg_tick0, avg_tick1, tick0, tick1, dt)` | **exit 0 (GREEN)** | `[PASS] test__unit__kernelProbeAlgebraEqualsPlankNonDegenerate (gas: 12023)` |

Restoration verified by `git diff --stat` against the committed harness: **empty** — byte-identical,
not merely "looks right".

**Two things this observation proves beyond the plan's ask:**

1. **The failure landed on the differential assertion**, not the anchor — the mutant broke
   *agreement*, which is exactly the property the probe exists to defend.
2. **The probe genuinely CALLS Plank.** Plank's returned value *changed* when Plank's source
   changed (to `115792089...585162`, a two's-complement negative — the mis-ordered kernel yields
   a negative numerator that `@evm_sdiv` returns as a huge u256). A deployed-but-dead harness
   would have returned the same value under both. This is the "proven CALLED, not merely deployed"
   requirement discharged by observation.

**The mock is likewise proven called, by construction:** `assertEq(exp, 819430)` reads the mock's
return directly. A dead or reverting mock cannot satisfy it.

## Why the anchor is load-bearing

`assertEq(got, exp)` alone is **insufficient**, and this is the subtle part worth stating: a mock
that merely *echoed* Plank's answer would satisfy it perfectly. The anchor `819430` pins Algebra's
side to a value **neither implementation can influence** — derived from Algebra's documented
formula, and computed independently **three times**: by the planner, re-derived by the
plan-checker in Python, and re-derived once more here before any code was written:

```
k = -350 (!= 0)   b = 1500 (!= 0)   num = 4,424,925,000   den = 5400
vol = 4,424,925,000 / 5400 = 819,430   (SDIV truncates toward zero)
```

Non-degeneracy needs **both** `k != 0` (tick0 != tick1) **and** `b != 0` (tick0 != avgTick0).
08-CONTEXT phrases it as `tick0 != tick1`, which only secures `k`. Had `b` been 0 too, both sides
would return 0 and `assertEq(0, 0)` would pass against a kernel that returns 0 unconditionally.
The chosen input satisfies both; the in-file docblock and an `assertTrue(exp != 0)` guard record
why, so a future edit cannot quietly flatten it.

## Deviations from Plan

### 1. [Not fixed — criterion bug, code left as the plan specified] Task 1's `grep -c` count is unsatisfiable

- **Found during:** Task 1.
- **Issue:** the criterion requires `grep -c "MockVolatilityOracle"` to print `1`, but the plan's
  **own verbatim file body** contains the string **twice** (lines 11–12: the name being avoided,
  and the shipped file's path). The criterion contradicts the code it ships.
- **Resolution:** the criterion's *stated intent* — "(the doc note only — never a declaration)" —
  is what was verified, and it holds: `grep -E "^\s*(contract|interface|library)\s+MockVolatilityOracle"`
  returns **nothing**. Both occurrences are comments.
- **Why not "fixed":** hitting the literal `1` would mean deleting an accurate line of
  documentation purely to satisfy a miscounted grep — optimising the metric against its purpose.
  Reported instead.
- **Files:** none changed.

## Findings reported, NOT smoothed over

**A near-miss worth recording.** The first instinct on applying the mutant was to run
`make test-vol-kernel-probe` directly. That would have tested the **stale** bytecode from the
previous `make compile-plank` — the probe deploys from `build/plank/*.hex`, so a `.plk` source edit
is invisible to forge until recompiled. The mutant would very plausibly have "passed", and the
correct conclusion ("the probe is vacuous") would have been drawn from an artefact of the build
system rather than the test. `make compile-plank` was run between mutation and probe, and the
RED above is genuine. **Phase 9's mutation battery must recompile Plank between every mutant** or
its kills are fiction.

**08-03 non-regression triggered a false alarm, resolved by checking rather than assuming.**
`grep -c "getAverageVolatility" RealizedVolatilitySmoke.t.sol` returns **5**, which looks like
08-03's removal was reverted. It was not: all 5 are 08-03's explanatory comments;
`grep -E "function getAverageVolatility"` returns nothing. The declaration is gone and stays gone.

**Warning, not fixed (out of scope):** solc emits
`Warning (2018): Function state mutability can be restricted to view` for the probe's test
function. Left alone — forge test functions are conventionally `public`, and `view` would be
churn in a file whose job is the assertion.

## Verification

| Criterion | Result |
| --- | --- |
| Mock exposes the kernel under `solc =0.8.20`, name distinct from shipped `MockVolatilityOracle` | PASS — `forge build` exit 0, artifact emitted; no declaration collision |
| Harness ABI-reachable at a `cast sig`-verified selector | PASS — `0xc6342af0`, declared literal diffed against `cast sig` output |
| Harness auto-discovered, NOT in `PLANK_SKIP` | PASS — `grep RealizedVolatilityKernelHarness Makefile` returns nothing; `compile-plank` 14 ok / 0 failed |
| Probe asserts mock == Plank at tolerance 0 | PASS — `[PASS] ... (gas: 12023)` |
| Probe pins the independent anchor 819430 | PASS — anchor assertion green |
| Probe is non-degenerate (k != 0 AND b != 0) | PASS — k=-350, b=1500, plus an `assertTrue(exp != 0)` guard |
| Argument-order mutant OBSERVED red, restored green | PASS — exit 2 → exit 0; restore confirmed byte-identical via `git diff` |
| `make test-vol-prereqs` green end-to-end | PASS — exit 0: pin → 7 refs → 11 smoke → 2 diff → 1 probe |
| `make check-algebra-ref-pin` still exits 0 | PASS — `OK: Algebra reference pin intact (4 files, v2.2.0)` |
| 08-01's Makefile targets not clobbered | PASS — `check-algebra-ref-pin` present and still the FIRST prerequisite |

**Note on acceptance:** `forge build` and `make compile-plank` appear here **only** as
preconditions, exactly as the plan labels them. Every acceptance row above is an observed test
outcome or exit code. Consistent with 08-01's standard and 08-CONTEXT's hard rule.

## Scope guard honoured

The 5-D fuzz was **not** written. This plan is scaffolding; VDIFF-02 / Phase 9 owns the fuzz over
`(dt, tick0, tick1, avgTick0, avgTick1)`. The probe is a **single point** — a wiring proof and a
necessary precondition, not evidence of bit-exactness across the domain. The probe's own docblock
says so in-file, so no future reader can mistake it for the fuzz.

## VDIFF-01 — now complete

08-01 delivered the pin half and deliberately left VDIFF-01 unchecked, noting that 08-02 (the mock)
is the last plan claiming it. Both halves now exist and are evidenced:

- **Pin:** `test/refs/algebra-volatility-oracle.sha256` + `make check-algebra-ref-pin` (4 mutants observed RED, 08-01).
- **Mock:** `AlgebraVolatilityKernelMock` + its differential probe, compiling under `solc =0.8.20`
  (Algebra's pinned pragma — the requirement's explicit wording), proven CALLED by the mutant above.

VDIFF-01 marked complete on that basis.

## Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `8f5f0fb` | `AlgebraVolatilityKernelMock` — external handle on the kernel |
| 2 | `c9301b9` | Plank harness, selector `0xc6342af0`, re-order at one call site |
| 3 | `43606d8` | The differential probe + `make test-vol-kernel-probe` wiring |

## Self-Check: PASSED

All 4 claimed files exist on disk; all 3 claimed commits resolve in `git log`;
`make check-algebra-ref-pin` exits **0** (baseline unmoved — this plan did not disturb 08-01's pin);
no mutant residue and no `node_modules/` modifications outstanding.
