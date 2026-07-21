---
phase: 08-reference-integrity-kernel-mock
plan: 01
subsystem: test-infrastructure
tags: [vdiff, pin, reference-integrity, falsification, make]
requires: []
provides:
  - "make check-algebra-ref-pin — red-on-divergence guard over the Algebra reference closure"
  - "test/refs/algebra-volatility-oracle.sha256 — the pinned 4-file closure manifest"
  - "a stable differential baseline for Phases 9-11"
affects:
  - "Makefile:test-vol-prereqs (now gated on the pin, first)"
tech-stack:
  added: []
  patterns:
    - "checksum-the-linked-path (node_modules), not a vendored copy — pinned bytes == compiled bytes by construction"
    - "accumulate check failures rather than short-circuit, so each guard is independently observable"
    - "falsify every guard before trusting it (observed RED, not asserted RED)"
key-files:
  created:
    - test/refs/algebra-volatility-oracle.sha256
    - script/check-algebra-ref-pin.sh
  modified:
    - Makefile
    - .planning/phases/08-reference-integrity-kernel-mock/deferred-items.md
decisions:
  - "Pin mechanism = sha256 manifest over node_modules, NOT vendoring under lib/ (avoids pin theatre)"
  - "Checks accumulate instead of short-circuiting, so the drift guard is observable independently of the content hash"
  - "Added Mutant D (package identity) beyond the plan's A-C: plan success criterion 2 demanded an observed RED for the version/integrity guard, and no planned mutant covered it"
metrics:
  duration: ~12 min
  tasks: 3
  files: 4
  completed: 2026-07-16
---

# Phase 8 Plan 01: Algebra Reference Pin Summary

Pinned the whole 4-file Algebra `VolatilityOracle` import closure with a sha256 manifest over the
`node_modules` copy that foundry actually compiles, wired it as the first prerequisite of
`make test-vol-prereqs`, and **proved it falsifiable with four observed RED mutants**.

## What was built

| Artifact | Purpose |
| --- | --- |
| `test/refs/algebra-volatility-oracle.sha256` | 4-line manifest pinning the exact closure the harness links |
| `script/check-algebra-ref-pin.sh` | 3 independent guards: content pin, closure-drift, package identity |
| `Makefile:check-algebra-ref-pin` | Runs the guard; FIRST prerequisite of `test-vol-prereqs` |

**Why `node_modules` and not a vendored `lib/` copy:** `remappings.txt` has no cryptoalgebra
entry; resolution comes solely from `foundry.toml:18`. Vendoring under `lib/` would have left the
suite compiling against `node_modules` while the pin guarded bytes nothing links — pin theatre,
the exact failure mode 08-CONTEXT warned about. Checksumming the linked path makes pinned bytes
== compiled bytes by construction.

**Closure verified, not assumed.** Re-derived every `^import` line before pinning: all 4 files'
imports are `./`-relative and resolve inside the manifest. The closure is self-contained,
confirming the plan's stated facts (package-lock v2.2.0 + integrity also confirmed verbatim).

## The falsification run — OBSERVED exits

Every exit code below was **actually run and actually observed**, not inferred.
(Exit 2 is `make`'s code when the recipe fails; the script itself exits 1.)

| Mutant | Perturbation | Observed exit | Restored exit |
| --- | --- | --- | --- |
| **A** | Appended a comment to the **transitive-only** `interfaces/IVolatilityOraclePluginImplementation.sol` | **2 (RED)** | **0 (GREEN)** |
| **B** | `tickCumulative` → `tickC umulative` in `libraries/VolatilityOracle.sol` (the real corruption that already happened) | **2 (RED)** | **0 (GREEN)** |
| **C** | Added `import "./VolatilityOracleInteractions.sol";` to `libraries/VolatilityOracle.sol` | **2 (RED)** | **0 (GREEN)** |
| **D** | `"version": "2.2.0"` → `"2.3.0"` in the plugin's own `package-lock.json` block | **2 (RED)** | **0 (GREEN)** |

**Mutant A is the load-bearing one:** it perturbs a file that is *transitively* imported and never
named in the test's import list. A `VolatilityOracle.sol`-only pin — the obvious implementation —
would have stayed green. It went red.

**Mutant C resolved the plan's hedge.** The plan allowed "(drift guard OR sha)", expecting the
content hash to shadow the drift guard (any import-adding edit also changes the bytes). Because
the checker accumulates rather than short-circuits, **both fired**, and the drift guard emitted
its own verdict with the correctly-normalized path:

```
ERROR: Algebra reference closure GREW: libraries/VolatilityOracle.sol imports unpinned libraries/VolatilityOracleInteractions.sol. Add it to the manifest.
```

So the drift guard is independently observed live, not merely present. The hedge resolves to AND.

**Mutant D was added beyond the plan.** Plan success criterion 2 requires an observed RED for
"the package version/integrity changes", but planned mutants A–C only covered the file contents
and the closure. An unfalsified guard is not a guard, so the version/integrity check was
perturbed too. It went red with the correct, specific message.

Plan `<verify>` command output: `PASS: red on divergence, green on restore` (exit 0).

Final state: `make check-algebra-ref-pin` exits **0**; `git status --porcelain` lists **nothing**
under `node_modules/`; a direct `sha256sum -c` confirms all 4 files byte-identical to the pin.

## Deviations from Plan

### 1. [Rule 2 — missing critical functionality] Scoped the package-identity grep to the plugin's own lockfile block

- **Found during:** Task 1.
- **Issue:** the plan permitted "a plain grep for both literals". A bare
  `grep '"version": "2.2.0"'` over the whole lockfile matches *any* of the hundreds of packages
  at 2.2.0 — it could essentially never fail, which is not a check.
- **Fix:** extract the plugin's own `package-lock.json` block (`grep -A6`) and assert
  version+integrity **within that block**. The integrity literal is still grepped verbatim as the
  plan required (and is unique anyway).
- **Files:** `script/check-algebra-ref-pin.sh`
- **Commit:** 1c0c7ee

### 2. [Rule 2] Checks accumulate rather than short-circuit

- **Found during:** Task 1.
- **Issue:** exiting on the first failed check would let the content hash permanently shadow the
  closure-drift guard — check #2 could never be observed firing, making it untrustworthy by the
  same standard this plan exists to enforce.
- **Fix:** all three checks run; failures accumulate into `rc`; the script exits non-zero if any
  failed. Directly enabled Mutant C's independent observation above.
- **Files:** `script/check-algebra-ref-pin.sh`
- **Commit:** 1c0c7ee

### 3. [Rule 2] Added Mutant D (package identity) beyond the plan's A–C

- **Found during:** Task 3. Covered above.
- **Commit:** proof-only (no source change).

## Findings reported, NOT smoothed over

**`package-lock.json` is UNTRACKED in this repo.** Discovered when Mutant D's restore step
(`git checkout -- package-lock.json`, as any reflexive restore would do) failed:

```
error: pathspec 'package-lock.json' did not match any file(s) known to git
```

Two things worth flagging honestly:

1. **A near-miss on false cleanliness.** The follow-up `git diff --quiet -- package-lock.json`
   printed `CLEAN` — but only because `git diff` ignores untracked files. Had I trusted that
   signal, I would have left the lockfile mutated and reported a clean tree. The restore was only
   confirmed by the checker itself going back to exit 0 from a real `/tmp` backup. This is a live
   example of why exit codes beat status greps.
2. **The checker's own remediation is not executable on a fresh clone.** `script/check-algebra-ref-pin.sh`
   tells the user to "Run 'npm ci' to restore" — but `npm ci` requires a lockfile, and the lockfile
   isn't committed. On a clean checkout there is no `node_modules` and no baseline to restore to.

**This does not undermine the deliverable:** checks #1 (sha over the actually-compiled bytes) and
#2 (drift) are load-bearing and are unaffected by lockfile tracking; #3 is a secondary bump signal.
All five of the plan's `must_haves.truths` hold. But the CI/reproducibility track must resolve this
**before Phase 9 relies on `make test-vol-prereqs` in CI**. Logged in `deferred-items.md`.

Also deferred: the drift guard covers `./`-relative imports only (package-style imports would be
caught by the content hash, not the drift guard). Deliberate scoping — the closure is verified
self-contained today.

## Verification

| Criterion | Result |
| --- | --- |
| Manifest pins all 4 closure files (not 1) | PASS — `wc -l` = 4, all 4 paths present |
| `script/check-algebra-ref-pin.sh` executable, exits 0 intact | PASS — prints `OK: Algebra reference pin intact (4 files, v2.2.0)` |
| Non-zero on any of the 4 diverging | PASS — observed (A, B) |
| Non-zero on closure growth | PASS — observed (C), drift guard fired independently |
| Non-zero on version/integrity change | PASS — observed (D) |
| `make -n test-vol-prereqs` runs the pin FIRST | PASS — first recipe line is `bash script/check-algebra-ref-pin.sh` |
| Reference left byte-identical to the pin | PASS — direct `sha256sum -c` all OK |
| No `node_modules/` residue | PASS — `git status --porcelain` clean |

**Note on acceptance:** per plan and 08-CONTEXT, "it compiles" appears nowhere in this plan's
acceptance. No `forge build` / `make compile-plank` was used as evidence — every criterion above
is an observed exit code.

## VDIFF-01 deliberately NOT marked complete

`08-01-PLAN.md` frontmatter declares `requirements: [VDIFF-01]`, but **VDIFF-01 was not checked
off**, by design. The requirement text covers the pin *and* the mock:

> "... The mock and vendored reference compile under `solc =0.8.20` (Algebra's pinned pragma)."

`08-02-PLAN.md` also declares `requirements: [VDIFF-01]` and its summary has not landed. This plan
delivers only the pin half. Marking VDIFF-01 complete here would assert a half-finished
requirement as done — the exact species of unearned green this phase exists to eliminate.

**Action:** 08-02 (the mock) should run `requirements mark-complete VDIFF-01` when it lands, since
it is the last plan claiming it. The pin half is fully satisfied and evidenced above.

## Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `1c0c7ee` | manifest + checker |
| 2 | `969236e` | make wiring, pin first in `test-vol-prereqs` |
| 3 | `c828a54` | deferred findings from the falsification run |

## Self-Check: PASSED
