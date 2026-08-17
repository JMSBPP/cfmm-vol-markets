---
phase: 09-upsilon-econometric-estimation-lean-aware
plan: 01
subsystem: infra
tags: [haskell, stack, hmatrix, hmatrix-gsl, hspec, econometrics, gsl]

# Dependency graph
requires:
  - phase: 08-panoptic-vol-claim-lean4-formalization
    provides: approved υ-identification econometric spec + Lean Upsilon module
provides:
  - Buildable econometrics/ Haskell Stack project pinned to lts-24.50
  - hmatrix + hmatrix-gsl (system GSL 2.8) numeric stack linked and green
  - Econ.Types shared Obs/Panel/Theta records for the whole pipeline
  - optparse CLI skeleton (fetch|build-panel|variance|estimate|test)
  - hspec test harness (econometrics:test:unit) running green
  - Frozen hand-computed CR0 sandwich-SE golden fixture for plan 09-08
affects: [09-04, 09-05, 09-07, 09-08, 09-09, 09-10]

# Tech tracking
tech-stack:
  added: [Stack lts-24.50, GHC 9.10.3, hmatrix-0.20.2, hmatrix-gsl-0.19.0.1, ad-4.5.6, statistics-0.16.5.0, cassava-0.5.4.1, aeson-2.2.5.0, req-3.13.4, hspec-2.11.17]
  patterns: [hpack package.yaml manifest, extra-deps pin with reproducibility lockfile, hand-computed golden fixture with documented arithmetic]

key-files:
  created:
    - econometrics/stack.yaml
    - econometrics/stack.yaml.lock
    - econometrics/package.yaml
    - econometrics/src/Econ/Types.hs
    - econometrics/app/Main.hs
    - econometrics/test/Spec.hs
    - econometrics/test/Golden/SandwichFixture.hs
    - econometrics/.gitignore
  modified: []

key-decisions:
  - "Pinned lts-24.50 (GHC 9.10.3) because it matches the system GHC exactly — Stack reuses it with no extra GHC download"
  - "hmatrix-gsl-0.19.0.1 added as extra-dep (not in lts-24.50); requires hmatrix>=0.18, compatible with the snapshot's hmatrix-0.20.2, and exposes Numeric.GSL.Fitting (the primary NLS LM optimizer)"
  - "Committed stack.yaml.lock so the extra-dep hash is pinned for reproducibility"
  - "Used a manual hspec main in Spec.hs (rather than the hspec-discover auto-driver) so the fixture-consistency describe block lives directly in Spec.hs as the plan specifies, with a single test file"

patterns-established:
  - "Golden fixtures freeze hand-computed truth with the full arithmetic in module comments so an auditor can retrace every matrix step"
  - "No home-absolute paths in any tracked econometrics/ source (Phase-1 rule); .stack-work and generated .cabal are gitignored"

requirements-completed: [CTX-EST]

# Metrics
duration: 9min
completed: 2026-07-19
---

# Phase 9 Plan 01: econometrics/ Stack Scaffold + Sandwich-SE Golden Fixture Summary

**Buildable `econometrics/` Haskell Stack project pinned to lts-24.50 with hmatrix + hmatrix-gsl (system GSL 2.8) linked, an `Econ.Types` core, an optparse CLI skeleton, and a green hspec suite carrying a hand-computed CR0 cluster-robust sandwich-SE golden fixture.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-07-19T18:15:36Z
- **Completed:** 2026-07-19T18:25:00Z (approx)
- **Tasks:** 2
- **Files modified:** 8 created

## Accomplishments
- `stack build` green: the full numeric/IO stack (hmatrix, hmatrix-gsl, ad, statistics, cassava, aeson, req, http-conduit, optparse-applicative) compiles and links against system GSL 2.8 and BLAS/LAPACK. Verified `Numeric.GSL.Fitting` imports cleanly and `libHShmatrix-gsl-0.19.0.1*.so` is installed in the snapshot.
- `Econ.Types` exports the shared `Obs`/`Panel`/`Theta` records every later plan consumes.
- `app/Main.hs` optparse CLI skeleton with `fetch|build-panel|variance|estimate|test` subcommand stubs; no absolute paths.
- `stack test` green (4 examples, 0 failures): the hspec harness runs and asserts the sandwich fixture is internally consistent.
- Froze the CR0 sandwich-SE golden fixture (2-cluster, 3-obs toy panel) with `expectedV = [[2.25,0.75,0],[0.75,0.25,0],[0,0,2.25]]` and `expectedSE = [1.5,0.5,1.5]`, full arithmetic documented in `SandwichFixture.hs` — ready for plan 09-08 to implement `Model.SandwichSE` against.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold econometrics/ Stack project with pinned LTS + numeric deps** - `a45b051` (feat)
2. **Task 2: hspec test suite + hand-computed sandwich-SE golden fixture** - `3c95135` (test)

## Files Created/Modified
- `econometrics/stack.yaml` - lts-24.50 resolver + hmatrix-gsl-0.19.0.1 extra-dep, reproducibility notes
- `econometrics/stack.yaml.lock` - pinned extra-dep hash
- `econometrics/package.yaml` - hpack manifest: library + executable + `unit` test stanza
- `econometrics/src/Econ/Types.hs` - `Econ.Types` module: `Obs`, `Panel`, `Theta`
- `econometrics/app/Main.hs` - optparse CLI skeleton (5 stub subcommands)
- `econometrics/test/Spec.hs` - hspec main asserting fixture consistency
- `econometrics/test/Golden/SandwichFixture.hs` - frozen hand-computed CR0 sandwich fixture
- `econometrics/.gitignore` - ignores `.stack-work/`, generated `*.cabal`

## Decisions Made
- **lts-24.50** chosen because it pairs with GHC 9.10.3 (the already-installed system GHC), avoiding a multi-hundred-MB GHC download, and ships hmatrix 0.20.2 + ad 4.5.6 + all supporting packages.
- **hmatrix-gsl-0.19.0.1 as extra-dep** — it is not in lts-24.50; its `hmatrix>=0.18` bound is satisfied by the snapshot's 0.20.2, and it provides `Numeric.GSL.Fitting`, the Levenberg-Marquardt optimizer that is the phase's primary NLS estimator (per the RESEARCH.md ADDENDUM: GSL 2.8 is installed, hmatrix-gsl is REQUIRED).
- **stack.yaml.lock committed** to pin the extra-dep for reproducibility.
- **Fixture design** — J columns chosen mutually orthogonal so `JᵀJ = diag(2,2,4)` inverts by inspection, keeping the by-hand sandwich arithmetic fully auditable while still exercising cluster aggregation (cluster "A" has 2 obs, "B" has 1).

## Deviations from Plan

### Minor design choices (no auto-fix rules triggered)

**1. Manual hspec main instead of the hspec-discover driver**
- **Found during:** Task 2
- **Issue:** The plan text says both "hspec-discover driver" and "add a placeholder `describe` in `test/Spec.hs`". In idiomatic hspec-discover usage `Spec.hs` is only a `{-# … hspec-discover #-}` pragma and the `describe` blocks must live in separate `*Spec` modules — the two instructions conflict for a single fixture file.
- **Resolution:** Used a self-contained manual hspec `main` in `Spec.hs` (the more concrete of the two instructions), keeping exactly the two test files the plan lists and genuinely running the fixture-consistency assertions. `stack test` green, 4 examples.
- **Files:** econometrics/test/Spec.hs, econometrics/package.yaml
- **Committed in:** 3c95135

---

**Total deviations:** 1 minor design choice. No Rule 1-4 auto-fixes were required.
**Impact on plan:** None — both acceptance-criteria sets pass verbatim; the numeric stack, types, CLI, and golden fixture are all delivered as specified.

## Issues Encountered
- **hmatrix-gsl not in the snapshot:** resolved by pinning it as an extra-dep after confirming (via Hackage) its `hmatrix>=0.18` bound is compatible with lts-24.50's hmatrix-0.20.2. No further conflicts.

## User Setup Required
None - system GSL 2.8, BLAS, and LAPACK are already installed; the build links them with no manual configuration.

## Next Phase Readiness
- Wave-1 build gate is GREEN: every downstream plan (09-04/05/07/08/09) now has a green `stack build` / `stack test` surface to compile and test against.
- Plan 09-08 has its golden truth frozen: `Model.SandwichSE` must reproduce `expectedV`/`expectedSE` to 1e-9 from `toyJacobianRows`/`toyResiduals`/`toyClusters`.
- The `optparse` subcommand stubs (`fetch`, `build-panel`, `variance`, `estimate`) are the integration points for 09-04/05/07.
- No blockers. Sibling plans 09-02 (data discovery) and 09-03 (Lean) run in parallel this wave with no file overlap.

---
*Phase: 09-upsilon-econometric-estimation-lean-aware*
*Completed: 2026-07-19*

## Self-Check: PASSED
- All 8 created files present on disk.
- Both task commits (a45b051, 3c95135) present in git history.
- `stack build` and `stack test` both exit 0; hmatrix-gsl `.so` installed and `Numeric.GSL.Fitting` imports.
