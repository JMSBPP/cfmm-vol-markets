---
phase: 26-shock-assembly-fee-split-event-decode
plan: 01
subsystem: fee-splitter
tags: [integer-arithmetic, uniswap-v4, gams-transcription, ellipse-test, bisection, rounding-rule, scan-scope-growth, tier-a]

# Dependency graph
requires:
  - phase: 25-content-key-and-keyed-store
    provides: "Store.Key's pips_denominator (KEY-05) -- the constant this module states a SECOND time, because Store.Key was written first and cannot import Fee.Split; the suite now asserts the two are equal"
  - phase: 24-gams-invocation-toolchain-identity
    provides: "Gams.Argv's Either-refusal shape and in_range's name-the-field-name-the-bound message discipline, which SplitRefusal follows; the aeson/float scan pair and their both-directions directory guard, whose scope this plan grew"
provides:
  - "offchain/lib/Fee/Split.hs: pips_denominator, fee_in_domain, compose_scaled, residual_scaled, nearest_partner, exact_pairs_for, ellipse_test, is_admissible, min_admissible_dstar, FeeSplit, SplitRefusal (5 constructors), refusal_message, refusal_boundary, splitter_version -- all Integer, all total, one import"
  - "seven Tier-A checks in core_checks (162 -> 169), each OBSERVED rejecting its named input"
  - "fee_in_domain + FeeOutOfDomain: blocker B1's guard, landed as a value this phase can assert rather than as a step in a function a later plan writes"
  - "a min_admissible_dstar bisection that tries BOTH floor(vertex) and floor(vertex)+1, with the reviewer's counterexample (99,101) pinned in the corpus"
  - "the scan scope grown to offchain/lib/Fee in the SAME commit as the module, and both tree-derived floors re-measured cold (62->63, 71->72)"
affects: [26-02, 26-03, 26-04, 27]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A constant stated in two modules that cannot import each other gets an EQUALITY CHECK, not a comment: the duplication becomes a checked agreement"
    - "A totality guard lands as a PREDICATE (fee_in_domain) in the plan that owns the type, so the phase that owns the type can assert it instead of deferring the whole finding"
    - "A bisection's right end is tried at both floor(vertex) and floor(vertex)+1, because either alone returns Nothing on a real input"
    - "A second evaluation is built from a DIFFERENT algebraic form (the complement of what the pair keeps), not a re-spelling of the same expansion"
    - "A deterministic sweep asserts it is NOT one-sided; a sample carrying one verdict makes the agreement arm vacuous in the other direction"
    - "A scan pattern is narrowed to what it MEANS (word-anchored) rather than the scanned set being narrowed to the files that do not trip it"

key-files:
  created:
    - offchain/lib/Fee/Split.hs
  modified:
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/test/Main.hs

key-decisions:
  - "fee_in_domain is a new export beyond the plan's 'export exactly' list, because blocker B1's fix has to be assertable in the plan that owns SplitRefusal -- split_for does not exist until 26-03"
  - "The min_admissible_dstar bisection tries TWO candidate right ends, not the plan's one: floor(vertex) alone is wrong at (99,101) and floor(vertex)+1 alone is wrong whenever the root interval sits entirely at or below the vertex"
  - "The 'rho >= 2+sqrt(3) is FALSE' sentence lives in check 5's haddock in Main.hs, not in Fee/Split.hs, which the plan's own FLOATS gate forbids (RC-B3)"
  - "The float scan pattern is WORD-ANCHORED on sqrt and Rational: the plan's unanchored pattern matches sqrtPriceX96 on 13 lines of the existing scanned set and could never have exited 1"
  - "fs_seed and fs_splitter_version are haddocked as a named CARRY-FORWARD citing ROADMAP's own line, NOT as a debt phase 25 settled -- 25 ran first and imports nothing from here"
  - "SC-1's 'derived pips reach the key' half is stated in the module haddock as an open GAP with no implementing task in this phase"
  - "The scan-scope growth moved from task 2 into task 1's commit: the coverage check is bidirectional, so listing the file and listing its directory must land with the file"

patterns-established:
  - "The order of arms inside one check is load-bearing and is documented as such: value, bound, size, extrema -- a floor rounder is invisible to the first three and only the fourth sees it"
  - "A mutation ledger records which arm fired, not merely that the check went red"

requirements-completed: [FEE-01, FEE-02]

# Metrics
duration: ~4h
completed: 2026-08-17
---

# Phase 26 Plan 01: `Fee.Split` — the Exact Level Constraint and the Prover's Own Ellipse — Summary

**The fee splitter's arithmetic core lands as 465 lines of total `Integer` code with exactly one
import, and its two claims are asserted rather than argued: the level constraint recomposes the
fixture to `6497000000` scaled units against a provenance that never touches the function under
test, and admissibility is `volume_path.gms`'s own `ellTest` transcribed term for term and checked
against an independently constructed fraction on 2013 triples. Three defects were found in the plan
itself — a bisection that returns `Nothing` on an admissible input, a mandated haddock sentence its
own gate forbids, and a scan pattern that could never have passed — and all three were fixed with
the measurement that found them.**

## Performance

| | Wave start (BASE) | After this plan |
|---|---|---|
| `cabal test` | **162/162** | **169/169** |
| FAIL | 0 | **0** |
| exit code | 0 | **0** |
| `-Wall` warnings | 0 | **0** |
| `cabal test` wall | **191 s** | **181 s** |
| `purge_file_floor` | 62 | **63** |
| `credential_scan_floor` | 71 | **72** |
| modules under `offchain/lib/Fee` | 0 | **1** |

**BASE was measured COLD at `2026-08-17T16:07:46Z`, before this plan edited a single file:**
`cabal test` → `162 PASS`, `0 FAIL`, exit `0`, wall `191 s`. That is +11 on the 151 this phase was
drafted against, which is phase 25 landing first exactly as `26-VALIDATION.md` said it would; every
gate in this plan was `BASE + N` against 162 and no absolute total was inherited. The 149.5 s wall
in `26-VALIDATION.md` is likewise superseded — 191 s is the comparand, and the finished suite runs
at **181 s against a 900 s ceiling**, so the seven new checks and their 2000-triple sweep cost
nothing measurable above run-to-run variance.

## Task Commits

| Task | Name | Commit |
|---|---|---|
| 1 | `Fee.Split` — the whole type surface and the exact arithmetic (+ scan scope, + both floors) | `cfce3d1` |
| 2 | FEE-01 — four checks over the level constraint | `1c4f79e` |
| 3 | FEE-02 Tier A — the prover's ellipse, the second evaluation, the float scan | `59328ab` |

## Gate readings, as PRINTED

| Gate | Command | Reading |
|---|---|---|
| build | `cabal build --enable-tests -j all` | exit `0`, `WARN=0`, `DL=0` |
| hex literals | `grep -cE '0x[0-9a-fA-F]{40}\b\|...' offchain/lib/Fee/Split.hs` | `HEXLIT=0` |
| floats | `grep -cE 'Double\|Float\|realToFrac\|fromRational\|Data\.Ratio\|Rational\|sqrt\|System\.\|unsafePerformIO' offchain/lib/Fee/Split.hs` | `FLOATS=0` |
| imports | `grep -c '^import' offchain/lib/Fee/Split.hs` | `1`, and it is `import Data.Word (Word32)` |
| surface | `grep -cE 'ellipse_test\|min_admissible_dstar\|...' offchain/lib/Fee/Split.hs` | `67` (floor is 8) |
| rational import | `grep -cE '^import +(qualified +)?Data\.Ratio' offchain/test/Main.hs` | `RATIO=0` |
| DB-free | `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` | `DBFREE=0` |
| GAMS-free | `grep -cE 'Gams\.Invoke\|CFMM_REQUIRE_GAMS\|/usr/gams' offchain/test/Main.hs` | `GAMSFREE=0` |
| NUL bytes | `wc -c` vs `tr -d '\000' \| wc -c` | `26779` both ways |
| territory | `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` | **empty** |

### The two floors, re-measured COLD as a pair

Both commands were RUN at task 1's commit, with `offchain/lib/Fee/Split.hs` on disk. Neither number
was derived from the other and neither was obtained by adding one to what was beside it.

```
find offchain -type f \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) | wc -l
63
find offchain -type f \( -name '*.hs' -o -name '*.sql' -o -name '*.sh' -o -name '*.json' \) | wc -l
72
```

Census under `offchain/` at that measurement: `hs 51, sh 9, json 9, sql 3`. Both floors are set to
those printed values, **zero slack**, and both were re-read unchanged at the final verification run.
The pre-phase-25 figures the plan carried (59/68, and the 60/69 it was first drafted with) were
hypotheses by the time it ran.

## The firing ledger — seven guards, eight observations, every one OBSERVED

Every mutation was applied to the working tree, built, run, and then restored from a **saved copy
verified by `sha256sum` on both sides** — never `git checkout`. `Fee/Split.hs` restored to
`d0fd6a16bcb7e1e6ca9907f0f157384aaa81b10725011d6e5d3e95fc83340e30` all eight times;
`offchain/test/Main.hs` to `3c653dfe8ee0d675d56e537e1139acbad0f5961334edebb97dae107444094a17`.

| # | Guard | Firing input | What went red, VERBATIM |
|---|---|---|---|
| 1 | `compose_is_the_exact_level_constraint` | `- x*m` deleted from `compose_scaled` | `compose_scaled 500 6000 is 6500000000, and D*(x+m) - x*m is 6497000000.` |
| 2 | `the_fixture_pair_recomposes_to_6497_pips` | same | `the fixture pair (500, 6000) pips composes to 6500000000 scaled units, not 6497000000.` |
| 3 | `exact_split_existence_is_measured_in_both_directions` | `exact_pairs_for` returning `[]` | `f = 6497 pips has 0 exact integer-pip pairs, and it has exactly 2. If this is 0 the search stopped early and the negative arms below would pass for the wrong reason.` |
| 4a | `rounding_residual…` **BOUND arm** | `nearest_partner` returning `q + 2` | `at f = 100 pips, 45 band members miss by a WHOLE PIP or more, the first being [(1,101,1999899)]` |
| 4b | `rounding_residual…` **EXTREMA arm** | `nearest_partner` returning `q` (floor) | `the largest absolute residual over the band at f = 3000 pips is 998994, and it was MEASURED at 499671.` |
| 5 | `admissibility_is_the_provers_own_ellipse_test` | `pn` replaced by the arithmetic-mean reading | `ellipse_test 500 6000 490000 is 2447831250000000000000000000000, and the prover's own ellTest times D^6 at that point is -295056739100000000000000000000.` |
| 6a | `the_integer_form…` **VALUE arm** | same (the mean reading) | `the two evaluations disagree in VALUE at (500, 6000, 82803): the fraction reduces to 4991723980281000000000000 at the D^6 scale and the module's integer form is 1530610871017312500000000000000.` |
| 6b | `the_integer_form…` **ONE-SIDED SWEEP arm** | the sign of `- d2*(x+m)*pn*d` flipped | `of the 2000 swept triples 0 are admissible, so the agreement below is being asserted over a sample with only one verdict in it. MEASURED at 189 admissible and 1811 refused.` |
| 7a | `no_floating_value_is_on_the_fee_path` **scan arm** | `budget :: Double` seeded into `Fee/Split.hs` | `a floating value or a rational type is on the FEE PATH.` — and `no_Double_and_no_aeson_on_the_artifact_path` went red with it |
| 7b | `no_floating_value_is_on_the_fee_path` **membership arm** | `offchain/lib/Fee/Split.hs` removed from `aeson_storage_path` | `offchain/lib/Fee/Split.hs is NOT in the scanned set…` — and `the_artifact_path_scan_covers_every_module_on_it` red beside it |

**No guard added by this plan lacks an observed firing.** Two arms are reported separately from
their check because the ORDER of arms inside a check is what makes them different guards.

### CORRECTION B, OBSERVED rather than argued

The plan says a `floor` rounder does not trip the one-pip bound and that only the extrema can see
it. Run:

| rounder | band sizes | bound arm | extrema at `f = 3000` |
|---|---|---|---|
| nearest (shipped) | 44 / 224 / 1344 / 2900 / 4447 | green | max 499671, min 8 |
| `floor` | **44 / 224 / 1344 / 2900 / 4447 — IDENTICAL** | **green** | **max 998994, min 458** |
| `q + 2` | 45 / 225 / 1345 / 2901 / 4448 | **red, every member** | — |

A `floor` rounder leaves the band's SIZE untouched and its worst residual (`999799` at `f = 10000`)
strictly below one whole pip. The size arm and the bound arm are both blind to it. Only the extrema
arm fires. That is why the residual carries four arms and not one.

## Deviations from Plan

### 1. `[BLOCKER B1 — findings]` `fee_in_domain` and `FeeOutOfDomain`, landed as an assertable value

`26-REVIEW-FINDINGS.md` B1: `nearest_partner f x` divides by `pips_denominator - x`, the band runs
`x` over `[1 .. f-1]`, so **every `f > 1000000` reaches `x = 1000000`** and raises an exception that
no `SplitRefusal` constructor could carry. Verified here against the vendored v4:
`LPFeeLibrary.sol:15` `DYNAMIC_FEE_FLAG = 0x800000` (8388608), `:25` `MAX_LP_FEE = 1000000`,
`PoolKey.sol:16` *"must be exactly equal to 0x800000"*. Reproduced independently:
`nearest_partner 8388608 1000000` → division by zero.

The finding's fix is `split_for`'s step 0, and **`split_for` does not exist until 26-03**. So this
plan landed the two halves it owns and made the guard assertable NOW rather than deferring the whole
finding:

- `FeeOutOfDomain Integer` added to `SplitRefusal` with its `refusal_message` arm, which names 8388608
  as v4's sentinel and says explicitly it is **not** an 8388608-pip fee;
- `fee_in_domain :: Integer -> Bool` exported — one export beyond the plan's "export exactly" list —
  so `split_for`'s step 0 is `unless (fee_in_domain f) $ Left (FeeOutOfDomain f)` and the predicate
  is checkable a plan early;
- three arms in check 4 (the check that ENUMERATES, hence the check that would divide by zero)
  asserting `8388608`, `1000000` and `0` are all out of domain.

**Also measured, and haddocked:** v4's own `isValid` admits `f = MAX_LP_FEE = 1000000`; the splitter
does not, because at a 100% pool fee the only partner of any `x` is `m = 1000000`. The two bounds
look identical and differ by one.

**Carried to 26-03:** the check arm the finding specifies —
`split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)` — with the firing input "delete the
guard, observe the exception rather than a `Left`".

### 2. `[RC-M4]` The specified bisection is WRONG, and the fix is TWO candidates, not one

`26-01-PLAN.md:294-297` specifies `hi = min vertex (D-1)` with `vertex = floor(-B/2A)`. Reproduced
here exactly: at `x = 99, m = 101` the real vertex is `499974.996…`, so
`ellipse_test 99 101 499974 = 27201107960480676 > 0` and the specified rule returns `Nothing` —
while `ellipse_test 99 101 499975 = -12498937537499375 <= 0`, confirmed the true answer by
exhaustive scan over `[0, 999999]`.

**The finding's own fix is also incomplete.** `hi = min (vertex + 1) (D - 1)` is wrong in the
mirrored case: if the root interval lies entirely at or below the real vertex, `floor(v)+1` is not
admissible while `floor(v)` is, and the same `Nothing` is returned. The shipped implementation tries
**both** candidates and takes the first admissible one, which is complete: an admissible integer `k`
is either at or below `floor(v)` — forcing `floor(v)` itself into the root interval — or at or above
`floor(v)+1`, forcing that one in. So "neither candidate admissible" is a fact rather than a failure
to look, and it is haddocked as that argument.

`(99, 101) -> Just 499975` is in check 5's pinned corpus, as the finding requires, with the reason
in the failure message. The degenerate `A = 0` case returns `Nothing` for a stated reason (it forces
`E = D^4 x m > 0` everywhere) rather than by clamping.

### 3. `[RC-B3]` The plan mandated haddock text its own gate forbids

`26-01-PLAN.md:283` requires the `ellipse_test` haddock to state the `rho >= 2+sqrt(3)` corollary is
FALSE; `:350` gates `Fee/Split.hs` on a pattern whose alternation includes `sqrt`, with `:356`
requiring `FLOATS=0`. The mandated string contains the forbidden one. The corollary sentence is in
**check 5's haddock in `offchain/test/Main.hs`**, outside the scanned set — instance 22 of the
class, resolved the way the twenty-one before it were. `Fee/Split.hs`'s own haddock says the
sentence lives there and why, so the pointer is not lost.

### 4. `[NEW — found here]` The plan's float-scan pattern could never have exited 1

Check 7 as specified scans `artifact_float_path` with
`Double|Float|realToFrac|fromRational|Data\.Ratio|Rational|sqrt` and requires exit 1. **RUN before
shipping:** that pattern matches `sqrtPriceX96` on **13 lines** across `offchain/lib/Gams/Argv.hs`
(8), `Gams/Artifact.hs` (4) and `Gams/Run.hs` (1) — all three already in the scanned set — so the
scan exits 0 and the check fails permanently.

Fixed the way this repository fixes this class: **the pattern is narrowed to what it means**, not the
scanned set to the files that do not trip it. Two alternations are word-anchored — `\bsqrt\b` and
`\bRational\b` — which leaves `sqrtPriceX96` and `sqrt_text` alone and still matches the operation
and the type. Measured after anchoring: exit 1 over the whole scanned set, and the seeded bait still
matches with its name printed. The reasoning is in `fee_float_pattern`'s haddock, with the 13-line
measurement.

### 5. `[RC-M5 / RC-m9]` The phase-25 claim replaced with a named carry-forward, and the citation corrected

The plan (`:309-311`) requires haddocking `fs_seed`/`fs_splitter_version` as *"exactly what Phase
25's run log and `key_scheme` consume"*, citing **ROADMAP:1202**. Both are wrong and both were
verified here:

- Phase 25 executed FIRST and is closed. Nothing in it imports `Fee.Split`; `grep -rl 'Fee\.Split'`
  over the tracked `.hs` and `.cabal` files finds exactly the three this plan touched — the module,
  the `.cabal` and the suite. The two fields have **no consumer today**.
- **ROADMAP:1202 is a LOOP-03 requirement bullet** (the reader loop, the torn read, the atomic
  rename); the issue-#29 cross-track handoff heading the finding names sits four lines later at
  `:1206`. Either way it is not about `fs_seed` or `splitter_version`, and citing it would put a
  false reference into a haddock. The finding's own description of line 1202 is off by those four
  lines; the conclusion — do not cite it — stands.
- The finding's replacement anchor, ROADMAP:1288-1289, has ALSO drifted: at lines 1288-1289 the file
  now carries phase-24's CONOPT unknowns. **The sentence the finding means is at ROADMAP:1304-1305**:
  *"The `splitter_version` is a Phase 26 product; `key_scheme` (Phase 23) is what makes adding it
  later non-destructive."* The haddock quotes that text and records the measured line numbers as
  "of the file as it stands today", so the next drift costs a reader nothing.

### 6. `[RC-M5, SC-1]` The store half of SC-1 is stated as a GAP

No plan of phase 26 touches `Store.Key`, `Store.RunLog` or the key scheme. The module haddock says
so in those words: the phase asserts the **argv** half; that the derived pips REACH the key has no
implementing task here and is open work. It is not asserted anywhere and is not claimed anywhere.

### 7. `[M5 — Solidity]` The chain's floor, and the band's silence about representability

Two haddock sentences on `compose_scaled`, both verified against the vendored source rather than the
finding's prose:

- `ProtocolFeeLibrary.calculateSwapFee` computes `x + m - div(mul(x,m), PIPS_DENOMINATOR)` in
  assembly, and EVM `div` truncates. The realized on-chain fee is therefore **high by
  `frac(x*m/D)` — up to a whole pip, always in the same direction** — which is a second, independent
  discrepancy from this module's own signed half-pip residual. `26-RESEARCH.md`'s Phase 27
  reconciliation (`compose(read pair) == pool fee`) will disagree by exactly that term and would
  otherwise read as a splitter bug.
- **Recorded OPEN, which the finding accepts as a close:** the band never asks whether a leg is
  on-chain representable. v4's `MAX_PROTOCOL_FEE` is **1000** pips (`ProtocolFeeLibrary.sol:8`,
  masked to 12 bits per direction), and the pinned seed-0 result at `f = 6497` is `(1036, 5467)` —
  **both legs exceed it**, so neither orientation is expressible as a v4 `(protocolFee, lpFee)` pair.
  Which two on-chain fields the legs are realized in is not decided by any plan of this phase. The
  band is unbounded on purpose and that is now written down.

### 8. `[Executor rule]` The scan-scope growth moved from task 2 into task 1's commit

The plan puts the module in task 1 and the scan-list growth in task 2.
`the_artifact_path_scan_covers_every_module_on_it` is **bidirectional**: listing
`offchain/lib/Fee/Split.hs` without listing `offchain/lib/Fee` makes it a *phantom*, and creating the
module without listing either leaves it *unlisted*. Both edits and both floor re-measurements landed
in `cfce3d1`, the commit that creates the file. Task 1's file list therefore includes
`offchain/test/Main.hs`, which the plan does not list.

### 9. `[Consequence — found here]` `pips_denominator` is stated twice and now CHECKED

`Store.Key` (phase 25) already exports `pips_denominator` and `offchain/test/Main.hs` already imports
it unqualified. `Fee.Split` exports the same name, and two unqualified imports of one name is an
ambiguity **error**, not a warning. Rather than dropping the export, the suite imports `Fee.Split`
twice — plainly for the rest of the surface, and qualified as `FS` for the constant — and check 1
asserts `FS.pips_denominator == pips_denominator`. The duplication that could not be removed became
a checked agreement, which is strictly better than either module silently owning it.

### 10. `[Plan prediction not borne out — reported, not hidden]` Two firing messages differ from the plan's

- The plan predicts mutation (a) makes check 5 "print the `82803`/`82804` flip". It does not: check 5
  reddens one arm EARLIER, at the `490000` pin. The flip is named by **check 6**, whose value arm
  reports `(500, 6000, 82803)` as the first disagreeing triple. Both are recorded above.
- The plan predicts the sign-flip mutation makes check 6 "name the first disagreeing triple". It
  reddens on the **one-sided sweep** arm instead, because flipping the sign flips `is_admissible`
  too and the whole 2000-triple sample becomes inadmissible. That arm was added by this plan and is
  the stronger report; the value arm's own firing is observed under mutation (a).

## What the module actually is

`offchain/lib/Fee/Split.hs`, 465 lines, `import Data.Word (Word32)` and nothing else.

| Function | What it is |
|---|---|
| `compose_scaled x m` | `D(x+m) - xm`, exactly `D * (the fee the pair composes to)`. `compose_scaled 500 6000 == 6497000000`, provenance `999500 * 994000 = 993503000000 = D * 993503` |
| `residual_scaled f x m` | the signed miss in `D * pips` units; bounded by `(D-x)/2 < D/2`, so the one-pip alarm has **2x** headroom |
| `nearest_partner f x` | nearest integer to `D(f-x)/(D-x)` by `divMod`, **ties round UP**, partial on `x = D` by design |
| `exact_pairs_for f` | both orientations, via `(D-x)(D-m) = D(D-f)` over the open window `(D-f, D)`. Census `0/0/0/0` for 100/500/3000/10000 and **2** for 6497 |
| `ellipse_test x m d` | `volume_path.gms:100-108` times `D^6`, term for term |
| `min_admissible_dstar x m` | bisection with **both** candidate right ends |
| `fee_in_domain f` | `1 <= f < D`. Blocker B1's guard |

Measured and pinned in prose: **4.935%** of `f` in `[1, 20000]` admit an exact integer-pip pair
(987 of 20000, recomputed here), and none of the four canonical Uniswap tiers does. That measurement
— not a preference — is why the ruling is round-and-report.

## Structural facts held

- Both structural greps over `offchain/test/Main.hs` are **0** (`DBFREE`, `GAMSFREE`).
- `core_checks` is the sole registration point; all seven names are defined AND registered.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is **empty**.
  `develop` was never merged; the v4 libraries were read from the vendored `lib/` tree in place.
- The four pre-existing untracked root files (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`,
  `stack.yaml.lock`) were left alone.
- No file written by this plan contains a NUL byte (`wc -c` equals `tr -d '\000' | wc -c`).

## Open, and named

1. **`split_for`'s step-0 domain check and its `split_for 0 8388608 490000` arm** — 26-03. The
   predicate and the refusal constructor are here; the function that must call it is not.
2. **Which two on-chain fields `(phi_X, phi_M)` are realized in** — undecided. The pinned `f = 6497`
   result `(1036, 5467)` is not expressible as a v4 `(protocolFee, lpFee)` pair (M5).
3. **SC-1's store half** — the derived pips reaching the key has no implementing task in phase 26.
4. **Seven of `FeeSplit`'s twelve fields are asserted by no check in any plan of this phase**
   (RC-m11): `fs_pool_fee_pips`, `fs_dstar_pips`, `fs_realized_scaled`, `fs_is_exact`,
   `fs_ellipse_e`, `fs_boundary_pips`, `fs_band_size`. The record is an interface for 26-03's
   constructor; if 26-03 does not assert them, they are unread fields and should be reported by name
   at the phase close.
5. **The wall moved 191 s → 232 s at task 1 and back to 181 s at task 3.** The 232 s reading was
   taken immediately after adding one file to two scans, and is not reproduced by the final run;
   recorded rather than explained away. RC-M8's warning about `sentinel_pair_floor` stands for 26-04.

## Self-Check: PASSED
