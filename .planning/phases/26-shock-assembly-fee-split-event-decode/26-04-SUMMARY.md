---
phase: 26-shock-assembly-fee-split-event-decode
plan: 04
subsystem: fee-splitter
tags: [tier-c, real-prover, gams-differential, abort-line-taxonomy, ungated-renderer, seventh-swept-artifact, sentinel-floors, phase-close, fee-02]

# Dependency graph
requires:
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 01
    provides: "Fee.Split's ellipse_test / is_admissible / min_admissible_dstar -- the arithmetic the whole differential is a claim about, and the bisection check 23 re-runs in-suite"
  - phase: 26-shock-assembly-fee-split-event-decode
    plan: 03
    provides: "the NINTH refusal in render_argv, which is precisely why render_argv_ungated had to exist: the capture cannot build a command line for the four rows the differential exists to measure; and the carry-forward that editing Gams/Argv.hs means RE-TAKING gams-conformance.json"
  - phase: 24-gams-invocation-toolchain-identity
    provides: "Gams.Invoke's raw_gams (which returns the run's LOG, the only place the abort line exists) and invoke_shock; the capture-script idiom, the freshness-oracle idiom, and the swept-artifact / field-floor / sentinel-pair-floor machinery"
provides:
  - "Gams.Argv.render_argv_ungated: the eight pre-existing refusals, with exactly one permitted consumer, asserted in both directions"
  - "Gams.Config.FEE_SPLIT_CONFORMANCE and its resolver, registered in advertised_overrides and config_env_vars"
  - "offchain/app/FeeSplitConformance.hs + offchain/rig/capture-fee-split.sh: sixteen real GAMS invocations, five value gates, 846 ms"
  - "offchain/rig/fee-split-conformance.json: 12 grid rows, 4 controls, 125 leaves, DISAGREE=0 against GAMS 54.1 / CONOPT 4.39"
  - "four Tier-C checks in core_checks (190 -> 194), each OBSERVED rejecting its named input"
  - "the SEVENTH swept artifact, with all seven field floors and sentinel_pair_floor re-measured in one run"
  - "RC-B1 CLOSED: (1000,3000)'s boundary re-swept and it is 300361, agreeing with Fee.Split exactly"
  - "RC-B2 CLOSED by a DIFFERENT derivation than the finding proposed, with the finding's own falsifying input run"
affects: [27, 28]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A verdict recorded about an external process is derived from the most SPECIFIC observable that process emits -- here the model's own source line -- and never from the exit code when the exit code is many-to-one"
    - "An escape hatch out of a structural refusal is exported with its consumer set asserted in BOTH directions, and the scanning check may not spell the identifier it scans for"
    - "A check whose arms dominate one another is reported as such and the dominated arm is OBSERVED under a two-part mutation that lifts its dominator"
    - "A mutation baseline is RE-TAKEN after every intentional edit: restoring from a baseline that predates one silently reverts it"
    - "A count arm and a name arm are separate: `length xs == 4 && null ys` prints an empty body when the count is what failed"

key-files:
  created:
    - offchain/app/FeeSplitConformance.hs
    - offchain/rig/capture-fee-split.sh
    - offchain/rig/fee-split-conformance.json
  modified:
    - offchain/lib/Gams/Argv.hs
    - offchain/lib/Gams/Config.hs
    - offchain/rig/gams-conformance.json
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/test/Main.hs
    - .planning/REQUIREMENTS.md
    - .planning/PROJECT.md

key-decisions:
  - "gams_admits is (abort_line /= 109) and NEVER (exit == 0 && artifact_present). RC-B2's proposed derivation is MEASURED false: eight of twelve rows are CONOPT-infeasible at this fixture and would be reported as disagreements"
  - "The one-pip attribution arm asserts the boundary+1 row is NOT refused at line 109, not that it exits 0. The plan's version is measured false for all four pairs"
  - "The controls go through the UNMODIFIED production path (invoke_shock) while the grid rows go through raw_gams: a control that Produced through the real composition is a stronger control than one driven by the same raw call as its subject"
  - "The control targets are the sweep's MEASURED solvable ones -- 490000 for three pairs, 497000 for (700,800) -- not the plan's parabola vertices, three of which abort"
  - "upper_root_ceiling is RECOMPUTED in-suite rather than recorded in the artifact: it is a Haskell fact, and recomputing it is the same discipline the boundary already follows"
  - "config_env_vars carries (identifier, value) as the shipped list has since 24-04; the plan's literal ('FEE_SPLIT_CONFORMANCE', ...) would have landed in the census's `undeclared` arm"
  - "gams_version / conopt_version are asserted as DOTTED NUMERALS, not as non-empty: the harness absorbed six mutations against a non-emptiness test"
  - "gams_exit and gams_abort_line are TIED to each other and the line must be in the model's known abort taxonomy -- the arm that catches RC-B2's own falsifying input on the eight rows the refusal arm does not cover"

patterns-established:
  - "The scanning check builds its subject identifier at runtime so the file holding the check is inside its own blast radius without matching itself"
  - "A firing observation that reddens MORE checks than the plan predicted is recorded as a correction to the prediction, not smoothed over"

requirements-completed: [FEE-02]

# Metrics
duration: ~5h
completed: 2026-08-17
---

# Phase 26 Plan 04: The Differential Against the Real Prover — Summary

**`Fee.Split.is_admissible` and `volume_path.gms`'s own `ellTest` gate now agree on twelve points
that bracket four exact boundaries by one pip on each side, measured against GAMS 54.1 / CONOPT 4.39
in 846 milliseconds — and the thing that makes the measurement mean anything is not the exit code.
Exit 3 is what all twelve rows return. What separates the four the prover REFUSES from the eight it
merely cannot solve is the model's own source line: 109 is the half-ellipse, 171 and 173 are CONOPT
failing to reach an admissible point. RC-B1's open boundary is closed — `(1000, 3000)` refuses at
300360 and does not at 300361, which is `min_admissible_dstar 1000 3000` exactly — and RC-B2's
falsifying input was RUN and reddens on all twelve rows.**

## Performance

| | Wave start (BASE) | After this plan |
|---|---|---|
| `cabal test` | **190/190** | **194/194** |
| FAIL | 0 | **0** |
| exit code | 0 | **0** |
| `-Wall` warnings | 0 | **0** |
| `cabal test` wall | **153 s** | **173 s** |
| `purge_file_floor` | 65 | **67** |
| `credential_scan_floor` | 74 | **77** |
| `sentinel_pair_floor` | 3828 | **4574** |
| swept artifacts | 6 | **7** |
| `render_argv` refusals | 9 | **9** (unchanged — the split preserves them) |

**BASE was measured COLD at `2026-08-17T20:20:31Z`, before this plan edited a single file:**
`cabal build --enable-tests -j all` exit `0`, `WARN=0`, `DL=0`; then `cabal test` → `190 PASS`,
`0 FAIL`, exit `0`, wall `153 s`. That equals exactly what `26-03-SUMMARY.md` recorded on exit
(190), so **there is no BASE finding to report by name**. Every gate in this plan was `BASE + N`
against 190 and no absolute total was inherited.

**Wall:** 173 s against the 400 s narrow-trigger and the 900 s stop. The seventh artifact costs
**+20 s**, which is the 746 new sentinel pairs each re-running a `core_checks` that is now 194
long. RC-M8 warned this would be the surprising number; it was not, and the reason is that the
artifact is 125 leaves rather than phase 23's 134.

## Task Commits

| Task | Name | Commit |
|---|---|---|
| 1 | the ungated renderer, its one consumer, and the capture that needs it | `89fb495` |
| 2 | the real prover's own verdict, on twelve points that bracket four boundaries | `3799a84` |
| 3 | four Tier-C checks over the prover's own refusal, and four floors re-measured | `d8b1d37` |

## Gate readings, as PRINTED

| Gate | Command | Reading |
|---|---|---|
| build | `cabal build --enable-tests -j all` | exit `0`, `WARN=0`, `DL=0` |
| shell syntax | `bash -n offchain/rig/capture-fee-split.sh` | `SH_SYNTAX_OK` |
| hex literals | `grep -rcE '0x…{40}\b\|0x…{64}\b\|0x…{8}\b'` over the new `.hs` and `.sh` | `HEXLIT=0` |
| decay absent from the renderer | `grep -cE '[Dd]ecay' offchain/lib/Gams/Argv.hs` | `DECAY_IN_ARGV=0` |
| GAMS-free suite | `grep -cE 'Gams\.Invoke\|CFMM_REQUIRE_GAMS\|/usr/gams' offchain/test/Main.hs` | `GAMSFREE=0` |
| DB-free suite | `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` | `DBFREE=0` |
| ungated renderer, definition | `grep -c 'render_argv_ungated' offchain/lib/Gams/Argv.hs` | `5` (floor 2) |
| ungated renderer, consumer | `grep -c 'render_argv_ungated' offchain/app/FeeSplitConformance.hs` | `3` (floor 1) |
| ungated renderer, THIRD file | `grep -rn … \| grep -v Argv.hs \| grep -v FeeSplitConformance.hs` | **empty** |
| `CFMM_REQUIRE_GAMS` in the script | `grep -c 'CFMM_REQUIRE_GAMS' offchain/rig/capture-fee-split.sh` | `7` (floor 1) |
| the override literal | `grep -c '"FEE_SPLIT_CONFORMANCE"' offchain/test/Main.hs` | `4` (floor 2) |
| artifact digests bare | `grep -cE '"0x' offchain/rig/fee-split-conformance.json` | `HEXPREFIX=0` |
| NUL bytes | `wc -c` vs `tr -d '\000' \| wc -c` | equal on all six files written |
| territory | `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` | **empty** |

`grep -c 'model/' offchain/rig/capture-fee-split.sh` reports **4**, and every one was read: lines
68, 73-74 and 111 are all comment or `>&2` message text saying the script never writes there. The
only path under `model/` the script touches is the one `GAMS_MODEL` names, and it is opened
read-only by the prover.

### The two tree floors, re-measured COLD as a pair

Both commands were RUN at task 3, with the two new files on disk. Neither number was derived from
the other and neither was obtained by adding to the number beside it.

```
find offchain -type f \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) | wc -l
67
find offchain -type f \( -name '*.hs' -o -name '*.sql' -o -name '*.sh' -o -name '*.json' \) | wc -l
77
```

Census under `offchain/` at that measurement: `hs 54, sh 10, json 10, sql 3`. Wave-start readings,
taken COLD before this plan touched anything, were **65 / 74**, and the census then was
`hs 53, sh 9, json 9, sql 3`. The deltas are `+2` and `+3`, exactly as the plan predicted — this
plan adds one app `.hs`, one rig `.sh` and one `.json`, and only the credential scan sees the third.
Both floors are set to the printed values, **zero slack**.

### The seven field floors and the pair floor, re-measured in ONE run

The method reports a number rather than confirming one: every existing floor raised by exactly 1,
the new one set to 99999, and `sentinel_pair_floor` set to 999999, so the harness had to name what
it had reached. It named the pair count first (arms short-circuit), so the run was repeated with
the pair floor set to the named value; the field-floor arm then named all seven at once.

```
FAIL sentinel_falsification_harness: the sweep exercised 4574 (field, sentinel) pairs, below the
floor of 999999.

FAIL sentinel_falsification_harness: the sweep enumerated fewer fields than the floor in:
      rig-manifest.json: 20, floor 21
      rig-pins.json: 110, floor 111
      driver-run-capture.json: 151, floor 152
      cheat-swap-proof.json: 130, floor 131
      store-conformance.json: 156, floor 157
      gams-conformance.json: 76, floor 77
      fee-split-conformance.json: 125, floor 99999
```

**NOT ONE OF THE SIX MOVED.** The arithmetic checks the pair count: `4574 − 3828 = 746` against
`125 × 6 = 750` possible, so exactly **FOUR** pairs were skipped as identities, and they are NAMED
rather than counted — the numeric zero against `controls[].control_exit`, which is legitimately 0
for all four controls. That zero is what a control IS.

## The firing ledger — four guards, thirteen observations, every one OBSERVED

Every mutation was applied, built, run, and restored from a **saved copy verified by `sha256sum` on
both sides**, never `git checkout`. Restores verified:
`Gams/Argv.hs` → `099d9a88…e702385f`, `Fee/Split.hs` → `b3510f82…7ec127ab`,
`offchain/app/Main.hs` → `50909186…1eed5f89`, `offchain/test/Main.hs` → `9b420e9e…baa6525e`.
Artifact mutations went to scratch copies reached through `FEE_SPLIT_CONFORMANCE`; the committed
artifact was never written.

| # | Guard / arm | Firing input | What went red, VERBATIM |
|---|---|---|---|
| — | check 14 (26-03), the ORDERING gate re-asserted BEHAVIOURALLY | `render_argv = admissible_pair >> render_argv_ungated` | `the equal-fee shock was refused by the ELLIPSE (Inadmissible, boundary Nothing), not by distinct_fees. MEASURED: min_admissible_dstar 3000 3000 == Nothing … The refusal COUNT is identical either way and VOLUME_PATH.md section 1.2's specific diagnosis is what was lost.` |
| 21a | `fee_split_conformance_is_present_and_fresh` **SET arm** | one grid row deleted from a scratch copy | `the capture's (phiXpips, phiMpips, txlVolumeRate) key set is not the pinned sixteen.` / `MISSING grid point: (500, 6000) @ 82803` |
| 21b | same, **FRESHNESS arm** | one byte of trailing whitespace appended to `Fee/Split.hs`, no re-capture | `the committed fee-split differential is STALE. offchain/lib/Fee/Split.hs has been edited since it was taken:` / `recorded=b3510f82…7ec127ab` / `recomputed=f583e4c9…c0776257` |
| 21c | same, **VERSION-SHAPE arm** | the sentinel harness, unprompted | six pairs ABSORBED SILENTLY against a non-emptiness test — see "what the mutations also taught" |
| 21d | same, **OVERRIDE arm** (item 25) | `FEE_SPLIT_CONFORMANCE=/nonexistent-override-probe/FEE_SPLIT_CONFORMANCE.json` | `no /nonexistent-override-probe/FEE_SPLIT_CONFORMANCE.json -- re-take it with: bash offchain/rig/capture-fee-split.sh` |
| 22a | `haskell_and_gams_agree_on_every_grid_point` **DIFFERENTIAL arm** | `gams_admits` flipped on `(100,900) @ 109768` | `(100, 900) @ 109768: Fee.Split.is_admissible recomputes False, the capture recorded haskell_admits False and gams_admits True (exit 3, model line 109)` |
| 22b | same, **`haskell_E` arm** | the recorded `E` at `(500,6000) @ 82803` moved by ONE | `(500, 6000) @ 82803: recorded 4991723980281000000000001, recomputed 4991723980281000000000000` |
| 22c | same, **DERIVATION arm** | `(500,6000) @ 82805` abort line set to 109, `gams_admits` untouched | `these rows record a gams_admits that is not (gams_abort_line /= 109):` / `(500, 6000) @ 82805: gams_admits True with abort line 109` |
| 22d | same, **EXIT/LINE TIE arm** — **RC-B2's own falsifying input** | every `gams_exit` set to 0, `gams_admits` untouched | `these rows record an exit code and an abort line that cannot both be true …` and **all twelve rows named**, e.g. `(500, 6000) @ 82803: exit 0, model line 109` |
| 22e | same, **FOUR-REFUSALS arm** | the `82803` row deleted | `the four boundary-minus-one rows are the ONLY place the real prover is ever observed REFUSING anything …` / `no row at all for (500, 6000) @ 82803` |
| 22f | same, **ONE-PIP ATTRIBUTION arm** (two-part; dominator lifted) | arm 22c lifted, then `(500,6000) @ 82805` abort line set to 109 | `these rows sit ONE PIP ABOVE their pair's boundary and the prover still refused them at the ellipse: (500, 6000) @ 82805.` |
| 22g | same, **TWO-SIDED arm** (two-part; dominator lifted) | arm 22e lifted, then every inadmissible row deleted | `the grid carries only one verdict (every point ADMITTED), so the agreement asserted above is vacuous in the other direction …` |
| 22h | same, **CONTROLS arm** | `(700,800)`'s `control_exit` set to 3 | `these controls did not produce an artifact through the unmodified production path:` / `(700, 800) @ 497000: exit 3, artifact True` |
| 23a | `the_grid_brackets_each_boundary_by_one_pip` **BISECTION arm** | the pinned boundary for `(500,6000)` moved ONE PIP, 82804 → 82805 | `a pinned boundary is not the one Fee.Split re-bisects here:` / `(500, 6000): the grid is pinned at boundary 82805 and min_admissible_dstar bisects Just 82804` |
| 23b | same, **BRACKETING arm** | the `82805` (`boundary + 1`) row deleted | `the grid does not bracket every boundary by one pip on each side:` / `(500, 6000) has no row at delta* = 82805 (boundary + 1)` |
| 24 | `the_ungated_renderer_has_exactly_one_consumer` | a real `render_argv_ungated` binding added to `offchain/app/Main.hs` | `the consumer set of the UNGATED renderer is not the two files it must be.` / `SECOND CONSUMER:    offchain/app/Main.hs` |

**No guard added by this plan lacks an observed firing.** Arms are reported separately from their
check because the ORDER of arms inside a check is what makes them different guards.

### What the mutations also taught, recorded rather than smoothed over

- **The inverted renderer composition reddens FOUR checks, not one.** The plan predicts check 14
  reddens "while the total refusal COUNT is unchanged and **every other check stays green**". The
  count clause is right — it is nine refusals either way. The "every other check" clause is
  **FALSE, measured**: `argv_rendering_is_canonical_and_total` and `out_of_range_words_are_rejected`
  also redden, both because the ellipse now refuses an out-of-range `txlVolumeRate` before
  `in_range` can name the field —
  `the refusal "txlVolumeRate-100%" failed as Inadmissible 500 6000 1000000 … expected a
  FieldOutOfRange naming "txlVolumeRate"`. The freshness oracle reddens too, by digest, as 26-02 and
  26-03 both recorded. The plan's CONCLUSION survives intact and is the important half: the
  inversion is invisible to COUNTS, which is why the durable gate is a constructor.
- **The sentinel harness found two real holes this plan had not seen, and both were ASSERTED rather
  than pardoned.** Its first run over the new artifact reported fourteen absorbed pairs:
  `gams_version` and `conopt_version` each absorbed the zero address, the zero word and the null
  object id (all three are non-empty strings, and the arm tested only non-emptiness); and
  `grid[].gams_exit` and `grid[].gams_abort_line` each absorbed the numeric zero on the **eight
  admissible rows**. The second of those is **RC-B2's own stated falsifying input landing on
  exactly the rows the refusal arm does not cover**, and it was absorbed until the exit/line tie arm
  was written. Only `generatedAt` is pardoned, for the same measured reason its six siblings are.
- **A count arm placed beside a name arm prints an empty body.** The first draft of arm 22e asserted
  `length [...] == 4 && null not_refused`; under a deleted refusal row the count was what failed and
  the list of offenders was empty, so the message named **nothing**. Split into an `absent` list and
  a `not_refused` list, it names the missing key.
- **Two of check 22's arms are DOMINATED and are reported as such.** In any self-consistent artifact
  the one-pip attribution arm is unreachable behind the derivation arm, and the two-sided arm is
  unreachable behind the four-refusals arm. Both were OBSERVED under two-part mutations that lift
  the dominator, following 26-02's precedent for its own dominated arms. They are not dead code:
  they are what remains if the arm above them is ever weakened, and the pair of two-part mutations
  is the evidence.
- **A mutation baseline taken at time T silently reverts any intentional edit made after T.** The
  arm-22e message fix was made, built and observed — and then undone by a `cp` from a baseline
  copied before it, with nothing red, because the pre-fix code still passes on a good artifact. It
  was caught by a later `python` assertion failing to find the new text. **The rule this plan adds:
  re-take the baseline after every intentional edit, not once per task.** The prompt's rule ("restore
  only from a baseline you took THIS task") is necessary and is not sufficient.

## The measurements this plan made against the real prover

### RC-B1's open boundary is CLOSED

`26-PROVER-SWEEP.md` closed three of four boundaries and left `(1000, 3000)` open because its grid
stepped 300000 → 400000 around a pinned 300361. Re-swept here at ten points:

```
1000 3000 300300 exit=3 line=109      1000 3000 300361 exit=3 line=173
1000 3000 300320 exit=3 line=109      1000 3000 300362 exit=3 line=173
1000 3000 300340 exit=3 line=109      1000 3000 300370 exit=3 line=173
1000 3000 300355 exit=3 line=109      1000 3000 300400 exit=3 line=173
1000 3000 300359 exit=3 line=109
1000 3000 300360 exit=3 line=109
```

Last ELLIPSE **300360**, first non-ellipse **300361**, and `min_admissible_dstar 1000 3000` is
`Just 300361`. **All four pairs now agree with the prover at the boundary, exactly.**

| pair | last ELLIPSE (line 109) | first non-ellipse | `min_admissible_dstar` | agree? |
|---|---|---|---|---|
| (500, 6000) | 82803 | 82804 | **82804** | **YES** |
| (100, 900) | 109768 | 109769 | **109769** | **YES** |
| (1000, 3000) | 300360 | 300361 | **300361** | **YES** |
| (700, 800) | 495952 | 495953 | **495953** | **YES** |

Note the sweep document's `(100, 900)` row reads "first non-ellipse 109770" and `(700, 800)`'s reads
"495954" — its grid skipped the boundary itself. Driven here, `109769` and `495953` are both
non-ellipse, which tightens both brackets to one pip and makes all four exact.

### The four `jq` gates, quoted verbatim

```
jq -r '.grid | map(select(.haskell_admits != .gams_admits)) | length'   ->  0
jq -r '.grid | map(.haskell_admits) | unique | length'                  ->  2
jq -r '.controls | map(select(.control_exit != 0)) | length'            ->  0
jq -r '.complete'                                                       ->  true
```

and the fifth this plan added, which is the one the differential exists for:

```
jq -r '.grid | map(select(.gams_abort_line == 109)) | length'           ->  4
```

`ROWS=12`, `CTLROWS=4`, `HEXPREFIX=0`. **GAMS 54.1.0, CONOPT 4.39.0**, model
`79940449af9e166b00490e2a5e2a8dde7add29dfad04b304fcc07ffe85ca53ad`, splitter
`b3510f82f57f23019c3f5e6bb2d209e9f979dfb01e82ec5a9011838c7ec127ab`.

### The capture wall, and a number worth correcting

**846 ms** for the whole capture — sixteen real GAMS invocations plus `cabal run` — timed twice.
`26-PROVER-SWEEP.md` records "~2 s per invocation"; that is the sweep script's own overhead.
Measured directly here: a full solve is **35 ms** and an ellipse abort is **16 ms**.

### Byte stability

**The artifact is NOT byte-stable across two consecutive captures, and the only difference is
`generatedAt`.** Measured: two runs 39 s apart digest `839d30d4…` and `67c892aa…`, and
`diff <(jq -S 'del(.generatedAt)' a) <(jq -S 'del(.generatedAt)' b)` is **empty**. That is 24-05's
fact for `gams-conformance.json`, stated here rather than discovered later. Everything else in the
document — sixteen exit codes, sixteen abort lines, twelve exact `E` values, three digests — is a
measurement and reproduces.

### The re-taken GAMS conformance capture

MANDATORY and it had no plan step. `gams_freshness_subjects` digests `offchain/lib/Gams/Argv.hs`,
this plan's split edits it, and the first green build of task 1 produced
`FAIL gams_conformance_is_present_and_fresh: the committed GAMS conformance capture is STALE.`
Re-driven against the real toolchain (exit 0, **9/9 verdicts pass**). Diffed against its
predecessor with `generatedAt` projected out, **exactly three fields moved**:

| field | before | after |
|---|---|---|
| `argv_module_sha256` | `37e4dc3b…3bee61` | `099d9a88…2385f` |
| `no_args.line1` | `… Start 08/17/26 15:17:20 …` | `… Start 08/17/26 16:35:55 …` |
| `version_flag.line1` | `… Start 08/17/26 15:17:20 …` | `… Start 08/17/26 16:35:55 …` |

**So the renderer split did not change the argv the prover receives**: the golden bytes still
reproduce at `e7b14f38..07d0d884` under all three environments, `action=c` still exits 0 writing
nothing, and the leading-zero token still moves the bytes to `d64a7b32..14b9e650`. That is a
measurement worth more than the fix it was made for.

## Deviations from Plan

### 1. `[RC-B1 / RC-B2 — the plan's grid and its verdict derivation are both replaced by MEASURED ones]`

The plan's `<pinned_grid>` drives four **parabola-vertex** controls (291401 / 304884 / 400180 /
497971) and its task 2 expects `boundary + 1` rows to exit 0 and all controls to exit 0. **Three of
the four vertex controls abort and every `boundary + 1` row aborts**, which is RC-B1's measurement
and it reproduces. What shipped instead:

- **Controls at the sweep's measured solvable targets**: 490000 for `(500,6000)`, `(100,900)` and
  `(1000,3000)`; 497000 for `(700,800)`. All four exit 0 and produce an artifact **through the
  unmodified production path**. `δ* = 490000` is ROADMAP SC-2's own 0.49, put back in — see the
  SC-2 note below.
- **`gams_admits = (abort_line /= 109)`**, pinned in the capture, in the shell gate, in the artifact
  (`ellipse_abort_line`) and asserted in-suite. RC-B2's proposed
  `(gams_exit == 0 && gams_artifact_present)` is measured FALSE here: `gams_artifact_present` is
  false on all twelve rows and eight of them are admissible, so that derivation reports eight
  disagreements. It was replaced, and RC-B2's REAL requirement — tie the recorded verdict to a real
  observable, and assert something about the `boundary − 1` rows — is met by three arms rather than
  one.
- **The one-pip attribution arm asserts `boundary + 1` is not refused at line 109**, not that it
  exits 0. This is strictly stronger than the plan's version *and* it is true: it names the gate
  instead of inferring it from a code that means six things.

### 2. `[NEW — found here]` `config_env_vars`'s shape: the plan's pair contradicts its own next clause

`26-04-PLAN.md:268` asks for the pair `("FEE_SPLIT_CONFORMANCE", fee_split_conformance_env_var)` and
the very next clause says "the identifier side being the NAME of the constant, so the census
matches". The shipped list has been `(identifier, value)` since 24-04, and
`store_overrides_are_probed_or_named_as_gaps` compares the identifier side against a `grep` census
of `^[a-z_]+_env_var :: String$` in the two config modules. Following the plan's literal would have
put `"FEE_SPLIT_CONFORMANCE"` into the `undeclared` arm, because no config module declares an
identifier by that name. Shipped: `("fee_split_conformance_env_var", fee_split_conformance_env_var)`,
with the reason in a comment beside it.

### 3. `[NEW — found here]` The check's own haddock made its scan return three files

`the_ungated_renderer_has_exactly_one_consumer` scans all of `offchain/` with no exclusion —
deliberately, because the suite calling that function WOULD be a second consumer and a scanner
excluded from its own scan cannot see the most likely violation. The first draft carried the
identifier in one haddock line (a FIRING INPUT sentence) and the scan reported
`SECOND CONSUMER: offchain/test/Main.hs`. Resolved the way this repository resolves this class: the
token is BUILT at runtime (`"render_argv" ++ "_ungated"`) and the prose says "the ungated renderer".
`grep -cF 'render_argv_ungated' offchain/test/Main.hs` is now **0**. **This is instance 25 of prose
inside a grep's blast radius on this branch**; 24 was 26-02's `sed` range and 23 was 26-01's
`\bsqrt\b`. RC-B3's word-anchoring rule was applied to every pattern this plan wrote and the
`\bsqrt\b` collision does not touch any of them.

### 4. `[PLAN ARITHMETIC]` The phase total is `BASE_26_01 + 32`, not `+ 31`

`26-04-PLAN.md`'s success criterion 7 and its verification block both say `BASE_26_01 + 31`.
Measured: 26-01 BASE was **162**; 26-01 added 7 (→169), 26-02 added **12** (→181), 26-03 added 9
(→190), 26-04 adds 4 (→**194**). `7 + 12 + 9 + 4 = 32`. The one extra is 26-02's own recorded
deviation 9 — `the_corpus_payload_agrees_with_an_independent_abi_coder`, the twelfth check, which
exists because Solidity M2 / RC-M7 arrived after that plan was written. **`194 = 162 + 32`,
confirmed by running the suite, and the plan's 31 is stale by exactly that documented deviation.**

### 5. `[PLAN BUDGET]` The 120-leaf target is internally inconsistent, and the artifact meets it anyway

`<pinned_grid>` computes "12 rows x 8 leaves + 4 controls x 3 leaves + about 8 top-level" = 116, but
its own JSON example gives controls **five** fields, which is 124 — already over its own target.
Shipped: 12 × 8 + 4 × 5 + 9 top-level = **125** as the harness counts it, and **117** as
`jq '[paths(scalars)] | length'` counts it. The acceptance criterion is written against `LEAVES`,
which is the `jq` command, so it is met at 117. The gap of 8 is not noise and is worth writing down:
**`paths(scalars)` is a `select` over the value at each path, so a path whose value IS `false` is
discarded by the very mechanism meant to enumerate it** — the eight are four `haskell_admits` and
four `gams_admits` on the refusal rows. The harness's 125 is the number budgeted with, exactly as
the existing note says for nulls. The real gate is the wall, and it is 173 s.

### 6. `[PLAN DESIGN — improved]` `upper_root_ceiling` is recomputed, not recorded

The plan puts `upper_root_ceiling` in the artifact and has check 23 assert the recorded values are
499999. The ceiling is a **Haskell** fact, not a GAMS measurement, so recording it and then
asserting it would be two fields agreeing; recomputing it is the same discipline the boundary
already follows. Shipped in-suite and stronger, at O(1) rather than a scan:

- `is_admissible x m 500000` is **False for all four pairs** — the prover's own gate reproducing
  `VOLUME_PATH.md` §1.1's independently derived `δ ≤ 1/2` ceiling as its upper root, which the
  arithmetic-mean misreading puts at 1;
- 499999 is admitted by three pairs, and `(700, 800)` tops out at **499991** with 499992 refused.
  The per-pair statement is what the plan's single 499999 could not express.

### 7. `[NEW — found here]` The grid rows and the controls take different paths through the library

The plan says the executable "drives `Gams.Invoke` once" per row. Shipped: grid rows through
`raw_gams` (the only call that returns the run's LOG, without which there is no abort line and no
discriminator) and controls through `invoke_shock WhitelistEnv` — the **unmodified production
composition**, all nine refusals, `run_prover`'s six verdict conjuncts. That makes the control a
stronger control than the plan's design: a pair that `Produced` through the real path is a pair the
toolchain can answer at all. It also supplies the `ToolchainIdentity` the artifact's versions and
model digest come from, so those come from the shipped parsers rather than a second reading.

### 8. `[Documentation pointer]` The approved FEE-01 wording is in the PLAN, not in the findings

The execution brief says the replacement wording is "verbatim in `26-REVIEW-FINDINGS.md`". It is
not — that file contains no occurrence of "round-and-report", "DIVISOR problem" or "4.93". The
verbatim text is in `26-04-PLAN.md`'s `<phase_close>` block, and that is what was used. One number
was corrected against the measurement: the plan writes **4.93 %** and the measured value is
**4.935 %** (987 of 20000, recomputed today), which is what shipped, with the count beside it.

---

# PHASE 26 RECORD

## The 39-row guard ledger, reconciled against what was OBSERVED across 26-01 .. 26-04

`26-RESEARCH.md`'s ledger, with the plan that owns each guard and whether a firing was OBSERVED.

| # | Guard | Owner | Observed firing? |
|---|---|---|---|
| 1 | level constraint exact | 26-01 | **YES** — `compose_scaled 500 6000 is 6500000000, and D*(x+m) - x*m is 6497000000` |
| 2 | fixture recomposition | 26-01 | **YES** — same mutation, second arm |
| 3 | exact-split existence, positive | 26-01 | **YES** — `f = 6497 pips has 0 exact integer-pip pairs, and it has exactly 2` |
| 4 | exact-split existence, negative | 26-01 | **YES** — same check, and 26-01 added the `FeeOutOfDomain` arms to it |
| 5 | rounding residual bound | 26-01 | **YES**, on TWO arms (`q + 2` → bound; `floor` → extrema) |
| 6 | ellipse predicate, doc-prose reading | 26-01 | **YES** — `ellipse_test 500 6000 490000 is 2447831250000000000000000000000, and the prover's own ellTest times D^6 … is -295056739100000000000000000000` |
| 7 | ellipse predicate, leading-order limit | 26-01 | **NOT OBSERVED, and it has no standing assertion.** The leading-order form is named in prose as a corollary; nothing in the suite asserts it, so there is nothing to fire. Reported by name; it is a research finding, not a guard |
| 8 | integer form ≡ rational form | 26-01 | **YES** — value arm and one-sided-sweep arm both |
| 9 | boundary is the exact root | 26-01 / 26-03 | **YES** — and 26-04 closed it against the REAL prover at all four pairs |
| 10 | `δ* = 0` refused | 26-02 | **YES** — via check 4's arm 2 under the ninth-refusal deletion |
| 11 | equal fees refused | 26-03 | **YES** — check 14, and again here under the inverted composition |
| 12 | no float on the fee path | 26-01 | **YES**, on both the scan arm and the membership arm |
| 13 | scan scope grows | 26-01 / 26-02 | **YES** — `offchain/lib/Fee/Split.hs is NOT in the scanned set…` |
| 14 | no spawn on refusal | 26-03 | **YES** — the marker was OBSERVED present under mutation and absent under the subject |
| 15 | splitter holds no IO | 26-03 | **YES** — `import System.Process (readProcess)` seeded |
| 16 | grid is two-sided | **26-04** | **YES**, under a two-part mutation (dominated by guard 35's SET arm) |
| 17 | grid abort is attributed | **26-04** | **YES** — `(700, 800) @ 497000: exit 3, artifact True` |
| 18 | exact-vs-double margin | 26-01 (research) | **NOT OBSERVED, and it has no standing assertion.** It is the reason the grid is at `φ ≥ 100` pips; the decision is honoured and recorded in `pinned_pairs`' haddock, and nothing asserts it. Reported by name |
| 19 | seed is load-bearing | 26-03 | **YES** — `the eight pinned seeds select 1 DISTINCT pair(s) at f = 3000` |
| 20 | band is non-degenerate | 26-03 | **YES**, and the guard's own named input was CORRECTED: `δ* = 1000` has TWO members, `δ* = 200` is the empty one |
| 21 | topic0 is computed | 26-02 | **YES** — `int24` → `int23`, one character |
| 22 | the call selector is not a topic | 26-02 | **YES** — via the corpus SET and by-name lookups |
| 23 | sign-aware decode | 26-02 | **YES**, on FOUR arms, two of them under two-part mutations |
| 24 | all-zero payload | 26-02 | **YES** — and the constructor was renamed `ZeroShock` |
| 25 | wrong data length | 26-02 | **YES** — the `length-128` member |
| 26 | topic arity | 26-02 | **YES** — the `three-topics` member |
| 27 | pool topic shape | 26-02 | **YES** — `zero-pool`, and `NotAnAddress` by construction |
| 28 | word range | 26-02 | **YES** — the transposition arm |
| 29 | corpus discriminates | 26-02 | **YES**, twice: deletion AND a count-preserving rename |
| 30 | decay never sent | 26-02 | **YES**, on all three arms |
| 31 | upstream trip-wire | 26-02 | **YES**, on four arms, with the mandatory positive control |
| 32 | `expected_topic_pins` untouched | 26-02 | **YES** — `"Shock"` added, two checks reddened |
| 33 | `sc3_literal_purge` | all four | **NOT OBSERVED IN PHASE 26.** It is a pre-existing check with its own positive control from phase 23; no plan here seeded a `0x`-prefixed literal to watch it fire. Reported by name — every new `.hs` and `.sh` was measured at `HEXLIT=0`, which is the absence of a match and not evidence the scan works |
| 34 | capture freshness | **26-04** | **YES** — one byte of whitespace on `Fee/Split.hs`, both digests printed |
| 35 | capture completeness | **26-04** | **YES** — the SET arm named the missing key; the `complete` arm has a standing assertion and **no observed firing**, because a truncated capture cannot be produced without editing the artifact by hand and the SET arm fires first. Reported |
| 36 | sentinel harness | **26-04** | **YES**, and it found two real holes unprompted (the version shape and the exit/line pair) |
| 37 | suite stays GAMS-free | all four | **NOT OBSERVED IN PHASE 26.** Pre-existing, with a proven positive control from 24-04. Measured at `GAMSFREE=0` on every commit. Reported by name |
| 38 | suite stays DB-free | all four | **NOT OBSERVED IN PHASE 26.** Same shape; `DBFREE=0` on every commit. Reported by name |
| 39 | `FEE_SPLIT_CONFORMANCE` override | **26-04** | **YES** — the failure message CONTAINS `/nonexistent-override-probe/FEE_SPLIT_CONFORMANCE.json` |

**Five guards carry a standing assertion or a standing decision with NO firing observed in this
phase, and every one is named above rather than omitted: 7, 18, 33, 35 (the `complete` arm), 37 and
38.** Guards 7 and 18 have no assertion at all and are research findings honoured by a design
decision; 33, 37 and 38 are pre-existing checks with positive controls proven in earlier phases and
measured at zero here; 35's `complete` arm is dominated by its own SET arm. 23-05's guard 13 and
24-06's four-guard precedent are the shape.

## The research corrections this phase CONFIRMED by measurement

1. **The residual headroom is 2x and not 10³, and a `floor` rounder does NOT trip the one-pip
   bound.** 26-01 OBSERVED it: under `floor` the band sizes are IDENTICAL (44 / 224 / 1344 / 2900 /
   4447), the bound arm stays green, and only the extrema arm fires (`max 998994` against the shipped
   `499671`). `residual = (D−x)(m − m_exact)`, so nearest rounding gives `|residual| ≤ (D−x)/2` and
   the 10³ figure is a band minimum.
2. **The empty-band firing input is `δ* = 200`, not the `δ* = 1000` guard 20 names, which measures
   at 2 — not at 4.** 26-03 OBSERVED it and corrected both `26-03-PLAN.md:178` and
   `26-VALIDATION.md:232`. The 4 counts BOTH orientations; `admissible_band` keeps only `m > x`.
   RC-M6 predicted "the message will print 2"; it printed
   `admissible_band 3000 1000 is [(1,2999),(2,2998)] with size 2`.
3. **(this plan) The corrected composed-fee / full-gap derivation reproduces the REAL prover's own
   admissibility verdict at four boundaries, exactly.** The arithmetic-mean misreading, being 2×
   too large, would refuse roughly 82,700 pips that GAMS accepts; that would appear as ELLIPSE rows
   where GAMS reports INFEASIBLE or SOLVED. It does not.

## Final suite state

| | value | how |
|---|---|---|
| `cabal test` | **194/194**, FAIL 0, exit 0 | `grep -c '^PASS'` / `grep -c '^FAIL'` |
| phase arithmetic | **162 + 32 = 194** | 7 + 12 + 9 + 4, each recorded on exit |
| wall | **173 s** | against a 900 s ceiling and a 400 s narrow-trigger |
| `-Wall` warnings | **0** | `grep -ciE '\bwarning\b'` over the build log |
| `GAMSFREE` | **0** | `grep -cE 'Gams\.Invoke\|CFMM_REQUIRE_GAMS\|/usr/gams' offchain/test/Main.hs` |
| `DBFREE` | **0** | `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` |
| `purge_file_floor` | **67** | `find offchain -type f \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) \| wc -l` |
| `credential_scan_floor` | **77** | `find offchain -type f \( -name '*.hs' -o -name '*.sql' -o -name '*.sh' -o -name '*.json' \) \| wc -l` |
| `artifact_field_floors` | **20 / 110 / 151 / 130 / 156 / 76 / 125** | all seven named by the harness in ONE run |
| `sentinel_pair_floor` | **4574** | named by the harness; `746 = 750 − 4`, the four skips named |

## Phase 25 — what it is owed, and what it is not

**Both fields exist and BOTH are asserted.** `fs_seed` and `fs_splitter_version` are read by check 18
(`the_seeded_pick_is_a_pure_function_of_seed_and_band`), whose firing was OBSERVED at 26-03 with a
`split_for` that discarded its seed: *"the split records fs_seed = 0 and was handed 7"*. All twelve
`FeeSplit` fields are read by a check — RC-m11 is closed, not carried.

**"Phase 26 owes Phase 25 nothing else" is NOT the right statement and is replaced by a named
carry-forward.** Phase 25 executed FIRST and is closed; nothing in it imports `Fee.Split`
(`grep -rl 'Fee\.Split'` over the tracked `.hs` and `.cabal` finds only this phase's own files). So
`fs_splitter_version` has **no consumer today**. The anchor is **ROADMAP:1288-1289** as RC-M5 gives
it — and 26-01 MEASURED that the file has drifted and the sentence RC-M5 means now sits at
**ROADMAP:1304-1305**: *"The `splitter_version` is a Phase 26 product; `key_scheme` (Phase 23) is
what makes adding it later non-destructive."* **CARRY-FORWARD: wiring `splitter_version` into the
content key is non-destructive via `key_scheme` and belongs to whoever next touches `Store.Key`.**
Both line numbers are recorded because both have already moved once.

**SC-1's store half is still open**, in the same words 26-01 and 26-03 used: no plan of phase 26
touches `Store.Key`, `Store.RunLog` or `key_scheme`, and the phase asserts the **argv** half only
(26-03 check 15). That the derived pips reach the content KEY has no implementing task here.

## The SC-2 substitution, reported as a finding

ROADMAP SC-2 names the grid point `ρ* = 3.8198 / δ* = 0.49`. **This phase's GAMS differential does
not contain that point, and the reason is a measurement:**

- `3.8198` is a root of `2ρ/(1+ρ²) = 0.49` — the arithmetic-mean / semi-axis reading `26-RESEARCH.md`
  M1 measured as exactly **2× too large**. Its provenance is the misreading, not the prover.
- The correct leading-order root at `δ* = 0.49` is **1.2234668** (or 0.8173495). So at `ρ = 3.8198`
  the pair is comfortably ADMISSIBLE at `δ* = 0.49` and bracketing it brackets nothing.
- **The exact boundary is not a function of `ρ` alone.** The prover's `phiBar = φ_X + φ_M − φ_X·φ_M`
  carries the product term, so no single `ρ*` names a boundary for every fee.

What replaces it is bracketing in the `δ*` direction at four FIXED pairs, at the EXACT integer
boundary each pair actually has (82804 / 109769 / 300361 / 495953), one pip either side, with the
boundary re-bisected in-suite. **SC-2's falsifiable clause — "the Haskell verdict AGREES with the
GAMS prover's verdict on every grid point. A disagreement is a bug in one of them and fails the
phase" — is unchanged and is check 22, and it is green against the real prover.** Only the NAMED
POINT and the PREDICATE clause yielded, exactly as `26-RESEARCH.md`'s "Correction of record 1"
already ruled for the predicate.

**`δ* = 490000` — SC-2's own 0.49 — is back in the differential**, as the control target for three
of the four pairs, because the 160-run sweep measured it as the single most useful grid point there
is. `<planning_corrections>` CORRECTION C removed it for a budget reason; the measurement put it
back. One fact worth recording rather than hiding: at `δ* = 490000` the pair `(700, 800)` is
INADMISSIBLE (its boundary is 495953), so SC-2's named target is not even uniformly admissible
across this grid's own pairs.

## The two upstream document corrections

Made in the phase-close commit, by this task and by nobody earlier, because 26-01's locked decision 1
(round-and-report) makes both texts FALSE as written. Every number was RE-MEASURED here before the
edit: `exact_pairs_for` is `[]` at 100 / 500 / 3000 / 10000 and `[(6000,500),(500,6000)]` at 6497;
`split_for 0 3000 490000` gives `fs_phi_x_pips = 752, fs_phi_m_pips = 2250,
fs_realized_scaled = 3000308000, fs_residual_scaled = 308000` — **3000.308 pips**, `+0.308` of a
pip; and 987 of 20000 fees admit an exact pair, **4.935 %**.

**(a) `.planning/REQUIREMENTS.md`, FEE-01.** BEFORE:

> Given a pool fee `f` and a target `δ*`, the splitter produces (φ_X, φ_M) satisfying
> `(1−φ_X)(1−φ_M) = 1−f` exactly.

AFTER: the round-and-report text from `<phase_close>`, with `4.93 %` corrected to **4.935 %** and
the count `987 of 20000` added.

**(b) `.planning/PROJECT.md`, the "Fee splitter" bullet.** BEFORE:

> `(1−φ_X)(1−φ_M) = 1−f` sets the **level** — and note this makes φ̄, the prover's composed fee,
> equal to `f` exactly.

AFTER: the replacement from `<phase_close>`, again at 4.935 %. `ROADMAP.md` was NOT edited and
`.planning/phases/25-*` was not touched; both are owned elsewhere.

## Phase 27 inherits

- **`Chain.Shock` and the `ShockLib.plk` merge trip-wire.** The trip-wire's subject is
  `origin/develop`, read with `git show`, never through a merge. **When it fires it instructs FOUR
  things**, and the third is the one that matters: (1) move the topic0 pin out of `ground_truth`
  into the generated `offchain/rig/rig-pins.json` surface; (2) add `"Shock"` to
  `expected_topic_pins`; (3) **RE-VERIFY THE CONSTANT** `SHOCK_EVENT_TOPIC0` against
  `keccak(shock_signature)` rather than merely re-homing the pin — those are different facts and
  only the second decides whether a real log ever matches; (4) delete the check, whose subject has
  been overtaken.
- **`ZeroShock` is a SKIP, never a decode alarm** (26-02, and it is load-bearing: nothing downstream
  refuses a zero rate except the ninth refusal, and `render_argv`'s `txlVolumeRate` lower bound is
  still 0).
- **`ShockEvent` carries no block, log index or transaction.** A batch decode must keep the `Change`
  alongside the `ShockEvent` or two blocks mix silently.
- **The abort-line taxonomy.** `Store.Cache.Decision` drops `Gams.Run.CapturedStreams`, so a caller
  of `decide` cannot tell an INADMISSIBLE shock from an UNSOLVABLE one — the line number lives only
  in `volume_path.log` inside a run directory `Gams.Run` deletes. `offchain/app/SpikeEndToEnd.hs`
  records the wrapper that works around it; a phase-28 poller needs that wrapper or a wider
  `Decision`.
- **Which two on-chain fields `(φ_X, φ_M)` are realized in is still undecided** (Solidity M5). The
  pinned `f = 6497` seed-0 result `(1036, 5467)` exceeds v4's `MAX_PROTOCOL_FEE` of 1000 pips on
  both legs. `admissible_band` is unbounded on purpose and says so.

## Structural facts held

- Both structural greps over `offchain/test/Main.hs` are **0** (`DBFREE`, `GAMSFREE`), and the
  Tier-C capture runs OUT OF BAND through a script that writes a committed artifact.
- `core_checks` is the sole registration point; all four names are defined AND registered.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is **empty**.
  `develop` was never merged; nothing under `src/`, `test/`, `foundry-scripts/`, `Makefile`,
  `foundry.toml` or `.github/` was edited.
- The four pre-existing untracked root files (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`,
  `stack.yaml.lock`) were left alone.
- No file written by this plan contains a NUL byte (`wc -c` equals `tr -d '\000' | wc -c`).
- Every mutation baseline taken in this task was deleted at close.

## Open, and named

1. **Guards 7, 18, 33, 35 (`complete` arm), 37 and 38 have no observed firing in this phase.** Named
   in the ledger above with the reason for each. Three are pre-existing checks with positive
   controls proven in earlier phases; two are research decisions with no assertion; one is dominated.
2. **`splitter_version` still has no consumer** — the named carry-forward above, ROADMAP:1304-1305.
3. **SC-1's store half is open**: the derived pips reaching the content KEY has no implementing task
   in phase 26.
4. **The artifact's `gams_artifact_present` is not recorded for grid rows**, because it is `false` on
   all twelve and would be twelve leaves of no information. `control_artifact_present` IS recorded
   and asserted. Stated so nobody reads its absence as an omission.
5. **The capture depends on the sibling `cfmm-wt/gams` worktree** being on disk and on `GAMS_MODEL`
   pointing at it. That is the same dependency `capture-gams-conformance.sh` has and it is why both
   are out of band.
6. **`26-PROVER-SWEEP.md`'s "~2 s per invocation" is the sweep script's overhead, not GAMS's.**
   Measured here: 35 ms for a full solve, 16 ms for an ellipse abort, 846 ms for all sixteen plus
   `cabal run`. Anyone budgeting a larger grid should use these.

## Self-Check: PASSED

Every created file was tested with `[ -f ]` and FOUND; every commit hash was tested with
`git log --oneline --all | grep -q` and FOUND; all four check names are DEFINED once and REGISTERED
once in `core_checks`, counted with anchored greps.
