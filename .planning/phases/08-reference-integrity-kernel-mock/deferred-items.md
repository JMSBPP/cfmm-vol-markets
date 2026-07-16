# Phase 8 — Deferred Items

Out-of-scope discoveries logged during execution. NOT fixed (scope boundary: only issues
directly caused by the current task's changes are auto-fixed).

## From 08-03 (VDIFF-03)

### Pre-existing solc warning: unused local variable

- **File:** `test/market_state_measurements/RealizedVolatilitySmoke.t.sol:183`
- **Warning:** `Warning (2072): Unused local variable. TP memory t = _last();`
- **Function:** `test__unit__timestampBelowWindowDoesNotInvertComparator` — NOT touched by 08-03.
- **Why deferred:** Pre-existing. 08-03 only edited the `IRealizedVolatility` interface block
  (lines 10-22 pre-edit). The warning surfaced only because the edit forced a recompile that the
  baseline run skipped ("No files changed, compilation skipped") — it is not a regression.
- **Substance:** `t` is read from `_last()` after two writes, then discarded; the test's real
  assertions use `t2` after a third write. Harmless, but the dead read suggests the first-stage
  state was once asserted and the assertion was dropped. Worth a look in Phase 11 (mutation
  battery), where a dropped assertion is exactly the failure mode under audit.
- **Suggested owner:** Phase 11 (VDIFF-08 falsifiability sweep).

## From 08-01 (VDIFF-01 pin)

### `package-lock.json` is UNTRACKED — `npm ci` cannot restore the baseline on a fresh clone

- **Found during:** 08-01 Task 3, Mutant D. `git checkout -- package-lock.json` failed with
  `error: pathspec 'package-lock.json' did not match any file(s) known to git`.
- **Detail:** the whole npm/hardhat surface is untracked on `feat/plank` (`package.json`,
  `package-lock.json`, `hardhat.config.ts`, `contracts/`, `ignition/`, `tsconfig.json`).
- **Why it matters for the pin:**
  - `script/check-algebra-ref-pin.sh` check #3 (package identity) reads `package-lock.json`.
    Grounding a guard in an untracked file is weaker than it appears.
  - The remediation the checker itself prints — "Run 'npm ci' to restore" — is **not executable
    on a fresh clone**: `npm ci` REQUIRES a lockfile. On a clean checkout there is no baseline
    to restore *to*, and no `node_modules` at all.
  - Checks #1 (sha over the actually-compiled bytes) and #2 (closure drift) are the load-bearing
    guards and are unaffected. The 08-01 deliverable stands on those; #3 is a secondary signal.
- **Why deferred:** tracking the lockfile means deciding the fate of the entire untracked
  hardhat/npm surface — a repo-structural decision (deviation Rule 4), well outside "pin the
  Algebra reference".
- **Suggested owner:** the CI/reproducibility track, BEFORE Phase 9 relies on
  `make test-vol-prereqs` in CI.

### Drift guard covers only `./`-relative imports

- **File:** `script/check-algebra-ref-pin.sh` check #2.
- **Substance:** the guard normalizes `./`-relative imports only. A pinned file that gained a
  *package-style* import (e.g. `@cryptoalgebra/integral-core/...`) would not be flagged by the
  drift guard — though it WOULD be caught by the content hash (check #1), since adding any
  import changes the file's bytes.
- **Why deferred:** scoped deliberately. The closure is verified self-contained today (every
  import in all 4 files is `./`-relative). Revisit only if the reference package is bumped.
- **Suggested owner:** whoever bumps `@cryptoalgebra/volatility-oracle-plugin`.
