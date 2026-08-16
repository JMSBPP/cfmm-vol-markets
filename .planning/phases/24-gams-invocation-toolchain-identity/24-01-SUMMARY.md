---
phase: 24-gams-invocation-toolchain-identity
plan: 01
subsystem: testing
tags: [haskell, gams, conopt, exit-codes, parser, source-scan, abstract-newtype]

# Dependency graph
requires:
  - phase: 23-postgres-foundation
    provides: "the abstract-newtype idiom (Store.Types.DerivedDoc), the named-once environment idiom (Store.Config), the Check/pure_check/expect runner and core_checks, and the two tree-derived floors this plan had to move"
provides:
  - "Gams.Version: GamsVersion/ConoptVersion as abstract newtypes whose constructors are withheld, with a job-name-anchored GAMS parser and a spaced-letter-anchored CONOPT parser"
  - "Gams.Exit: classify_exit :: ExitCode -> Verdict, total, carrying no stream, with gams_code_domain exported as an independent subject for the timeout-collision argument"
  - "Gams.Config: GAMS_BIN / GAMS_MODEL / GAMS_CONFORMANCE named exactly once each"
  - "Six Tier-A checks registered in core_checks (111/111 -> 117/117)"
  - "A both-directions directory-vs-list assertion over offchain/lib/Gams/, so the no-fallback scan's scope cannot silently fail to grow"
affects: [24-02, 24-03, 24-04, 25-content-key-and-keyed-store]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The version parse is anchored on the SUBJECT (the banner's job name) before the SHAPE"
    - "The verdict function's TYPE carries no stream, so 'no decision reads log text' is structural"
    - "A scan's file set is asserted against the directory in both directions, with reasoned exemptions"

key-files:
  created:
    - offchain/lib/Gams/Config.hs
    - offchain/lib/Gams/Version.hs
    - offchain/lib/Gams/Exit.hs
  modified:
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/test/Main.hs

key-decisions:
  - "The GAMS version's discriminator is the banner's JOB NAME equalling the invoked .gms basename -- one equality that rejects both real wrong-subject banners without a denylist"
  - "parse_conopt_version matches the spaced-letter form and scans every line; positional logic is refused because the true line MEASURED at index 38 in the probe and 47 in the production run"
  - "Unclassified is a FAILURE and 0 is the only Solved; an unrecognised code may not default to success"
  - "gams_code_domain holds the mod-256 IMAGES (141/144/145/146), because those are the bytes a caller observes"
  - "Gams.Config is EXEMPT from the no-fallback scan WITH A WRITTEN REASON, not omitted from it"
  - "No requirement is marked complete by this plan: it ships the PURE half, and the IO conjuncts of GAMS-01/03 and GAMS-04's Tier-C evidence are not in it"

patterns-established:
  - "Firing observations restore FROM A SAVED COPY verified sha256-identical, never by git checkout"
  - "Both tree-derived floors are re-measured cold in the same commit as the files that move them"

requirements-completed: []

# Metrics
duration: 22min
completed: 2026-08-16
---

# Phase 24 Plan 01: Toolchain Identity, Pure Half — Summary

**A GAMS version that rejects the real exit-0 help banner by job name, a CONOPT version that rejects both real decoys by the spaced-letter form, and an exit taxonomy in which no non-zero code can mean `Solved` — six Tier-A checks, four of them OBSERVED failing against their named inputs.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-16T23:06:01Z
- **Completed:** 2026-08-16T23:27:43Z
- **Tasks:** 3
- **Files modified:** 5 (3 created, 2 modified)

## Accomplishments

- `parse_gams_version` rejects **the real 1239-byte no-argument help banner** — exit 0, version present three times, no model run — as `Left (WrongJob "?")`, and the real `gams --version` output (exit 6) as `Left (WrongJob "--version")`. Neither is on a denylist; one equality does both.
- `parse_conopt_version` accepts `    C O N O P T   version 4.39.0` and rejects **both real decoys** — the GAMS-side link line and `libconopt464.so` — including a buffer carrying both and no true line, which is what a run that never reached CONOPT looks like. The answer is identical at buffer index 38 and 47.
- `classify_exit` is a total function of `ExitCode` alone; **no code in 1..255 classifies as `Solved`**; 7 is licensing; 3 is recorded as ambiguous-by-measurement; 124/137 collide with nothing.
- Both tree-derived floors **re-measured cold** in the same commit as the modules that moved them.
- Suite **111/111 → 117/117**, FAIL 0, zero `-Wall` warnings, still DB-free and GAMS-free.

## Task Commits

1. **Task 1: Gams.Config and Gams.Version** — `250bb78` (feat)
2. **Task 2: Gams.Exit** — `891d5e2` (feat)
3. **Task 3: Six Tier-A checks and the floors they move** — `048233e` (test)

## The four firing observations

Each mutation was applied, the suite run, the verbatim FAIL captured, and the source restored **from a saved copy** (never `git checkout`), verified against pinned digests: `Version.hs` `413e1bf859e9e179b164135811a274a7fde2aee95cfc5bfeb1954c7dd603c512`, `Exit.hs` `943c1d6665240f07613fd2c839e074d12ead51c2ccb81dfa817545fbefe08f68`. `git status --porcelain offchain/lib/Gams/` carried no mutation residue afterwards.

### 1. `parse_gams_version` ignores the job name

Mutation: `| job /= model_basename -> …` became `| False -> …`.

```
FAIL gams_version_parser_rejects_the_garbage_battery: the garbage battery member "help-banner-exit-0" was not rejected as expected.
      first line: "--- Job ? Start 08/16/26 16:01:42 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux"
      expected:   Left WrongJob "?"
      actual:     Right (GamsVersion ("54.1.0","37378ce0"))
```

The exit-0 help banner **accepted, as a fully-formed version**. This is the defect class in its most seductive form and it is now an observation rather than an argument.

### 2a. `parse_conopt_version` matches the bare token `CONOPT` — UNPLANNED, and kept

```
FAIL conopt_parser_rejects_both_decoys: the POSITIVE arm failed: the REAL CONOPT banner was rejected as NoConoptBanner.
      line: "    C O N O P T   version 4.39.0"
```

The mutation the plan named turned out to fire on the **positive** arm: the true banner contains no bare `CONOPT` token at all, because its letters are spaced. Recorded because it says something the planned mutation does not — the spaced form is load-bearing in *both* directions.

### 2b. spacing-insensitive marker + any version-shaped triple

```
FAIL conopt_parser_rejects_both_decoys: the CONOPT decoy "link-version-decoy" was not rejected: got Right (ConoptVersion "54.1.0").
      Both decoys carry the token CONOPT and only the true line carries the spaced-letter form. Accepting one records the GAMS link version, or a soname, as the solver that produced the bytes -- and a different CONOPT can select a different member of the underdetermined path family while passing every gate.
```

GAMS's own number recorded as CONOPT's. `conopt_parse_is_position_independent` stayed **green** under this mutation, which is what says the two checks discriminate different things rather than duplicating one another.

### 3. `classify_exit` maps 7 to `Solved`

```
FAIL gams_exit_taxonomy_is_total_and_disjoint: these exit codes classify as Solved: [7]. Solved means only that GAMS RAN -- MEASURED, `action=c` exits 0 writing no artifact and `gams` with no arguments exits 0 running no model. A NON-ZERO code reaching Solved is the catch-all falling through to success, which is this repository's recurring defect with a number attached.
```

An expired licence recorded as a successful solve.

### 4. a real fallback lands in `Gams/Version.hs`

Mutation: `reported_version = Data.Maybe.fromMaybe "unknown"`, plus its import.

```
FAIL gams_version_is_not_constructible_empty: a FALLBACK is present in the GAMS layer. A default, an alternative, an exception handler or a placeholder string on this path is a version that reports a plausible value when its subject was absent. Phase 25 folds both version strings into the content key, and NOT NULL does not forbid the empty string, so the poisoned rows are indistinguishable afterwards.
      offchain/lib/Gams/Version.hs:93:reported_version = Data.Maybe.fromMaybe "unknown"
```

The file **and the line** are named, not merely counted.

## The floors, re-measured cold

Run at execution time, with the three new modules on disk, in the same commit that added them:

```
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l
51
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
59
```

| Floor | Was | Now | Slack before |
|---|---|---|---|
| `purge_file_floor` | 48 | **51** | **zero** — 48 against exactly 48 scanned files |
| `credential_scan_floor` | 56 | **59** | zero — 56 against exactly 56 |

Census under `offchain/`: `hs 41, sh 8, json 8, md 3, txt 2, sql 2`. Only `.hs` moved, by three. Neither floor was incremented by arithmetic; the two happen to agree with `+3` here, and the day they stop agreeing is the day the difference is the whole point.

## Suite counts, MEASURED cold — and both inherited numbers were stale

| | Checks | Wall |
|---|---|---|
| Baseline before this plan | 111/111 | **71.8 s** |
| After | **117/117** | **87.8 s** |

`STATE.md` and `24-RESEARCH.md` both carried **97 s**; the execution prompt carried **66 s**. The real cold baseline was 71.8 s. The +16 s is the sentinel harness, which re-runs `core_checks` once per (leaf × sentinel) pair — six added checks are paid roughly 3250 times. Budget is 900 s.

## Files Created/Modified

- `offchain/lib/Gams/Config.hs` — the three environment variables, each named exactly once, in `Store.Config`'s shape. Records as a fact of record that `volume_path.gms` does not exist in this worktree, so a run here requires the `GAMS_MODEL` override. No absolute path, no machine-specific digest.
- `offchain/lib/Gams/Version.hs` — both newtypes abstract; job-name-anchored and spaced-letter-anchored parsers; no fallback of any kind on the path.
- `offchain/lib/Gams/Exit.hs` — `classify_exit`, the four verdict types, and `gams_code_domain`. Imports `System.Exit` and nothing else.
- `cfmm-replicationPlank-rpc-api.cabal` — three `exposed-modules` entries, **+0 packages**, confirmed by `grep -c Downloading` = 0 rather than estimated.
- `offchain/test/Main.hs` — six checks, their registration in `core_checks`, both floors, and the directory-vs-list membership assertion.

## Decisions Made

1. **The job name is the discriminator.** Derived from M2: the three real banners differ in exactly one field. A shape-first rule would accept the help banner, whose version field is perfectly well formed.
2. **`parse_conopt_version` returns `Left EmptyInput` for an empty or whitespace-only buffer** rather than `NoConoptBanner`. The plan did not specify this arm; the more informative error was chosen and no check depends on the other answer.
3. **`Unclassified` is a failure, and `gams_code_domain` names the mod-256 images.** A collision argument made against 400/401/402/909 would be about codes no caller ever observes.
4. **`gams_code_domain` is asserted in BOTH directions.** Non-membership of 124/137 alone is satisfied by a domain that shrank to nothing, so the codes that must be *present* — including the folded images and the 109..115 range — are asserted too, and every member must classify to a non-timeout verdict.
5. **No requirement is marked complete.** See "Requirements" below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `Gams.Exit`'s cabal line moved from task 1 to task 2**
- **Found during:** Task 1
- **Issue:** The plan's task 1 adds all three `exposed-modules` lines, but `Gams/Exit.hs` is created in task 2. `cabal build` fails on an exposed module that does not exist, and task 1's own acceptance requires a green build.
- **Fix:** `Gams.Config` and `Gams.Version` landed in task 1's commit; `Gams.Exit` landed in task 2's commit alongside its module.
- **Verification:** `grep -cE '^ +, Gams\.(Config|Version|Exit)$'` = **3** at end state, and every intermediate commit builds.
- **Committed in:** `250bb78`, `891d5e2`

**2. [Rule 1 — Bug] Prose inside the new scan's blast radius reddened `Gams/Exit.hs`**
- **Found during:** Task 3, on the first green run
- **Issue:** `Gams/Exit.hs:29` used the phrase "the c-a-t-c-h-all" (spelled out) in a haddock comment. `gams_version_is_not_constructible_empty` matched it and FAILED, naming the file and the line. The guard was right: a grep reads a module's comments as readily as its code.
- **Fix:** The **prose moved**; the pattern was **not** relaxed. The sentence now says "the final equation", with a note recording what happened, spelled so it cannot re-fire.
- **Verification:** 117/117, FAIL 0; and mutation 4 then demonstrated the same pattern still fires on real code.
- **Committed in:** `048233e`
- **Note:** this is the eleventh instance of prose-inside-a-grep on this branch and the first where the guard itself did the catching rather than a plan's self-check.

**3. [Rule 2 — Missing critical] The no-fallback scan's scope is asserted against the directory**
- **Found during:** Task 3
- **Issue:** The plan specified a scan over `Gams/Version.hs` with no cross-check against what exists on disk. That is exactly the shape `aeson_storage_path` has, and 23-03 measured its consequence: `Store/Schema.hs` sat unlisted for two commits with nothing red.
- **Fix:** `gams_no_fallback_path` (scanned) and `gams_fallback_exempt` (exempt, each with a written reason) must together **equal** the set of `.hs` files under `offchain/lib/Gams/`, asserted in both directions. `Gams/Config.hs` is the one exemption, because `fromMaybe <default> <$> lookupEnv` *is* the `Store.Config` resolver idiom and no version value exists on that path. `Gams/Exit.hs` was added to the scanned set rather than left out of it.
- **Verification:** green; and the reword in deviation 2 was forced by this widened scope, which is the scope demonstrating that it reads what it claims to.
- **Committed in:** `048233e`

**4. [Rule 1 — Bug] A `-Wall` type-default warning in the new CONOPT check**
- **Found during:** Task 3
- **Issue:** `OverloadedStrings` is on in `Main.hs`, so the un-annotated local `reject` defaulted its literal argument and produced three `-Wtype-defaults` warnings — a hard-gate failure.
- **Fix:** A local `reject :: String -> String -> Either String ()` signature, with a comment saying why it is not decoration.
- **Verification:** `grep -ciE 'warning'` = 0.
- **Committed in:** `048233e`

**5. [Deviation of record — measurement over plan] Mutation 2 was run twice**
- The mutation the plan names (bare token `CONOPT`) fires on the **positive** arm, not on the decoy arm, because the true banner has no bare `CONOPT` token. A second mutation (spacing-insensitive marker plus any version-shaped triple) produces the FAIL the plan predicted. Both are recorded above; neither was discarded.

---

**Total deviations:** 5 (1 blocking, 2 bugs, 1 missing-critical, 1 measurement-over-plan)
**Impact on plan:** No scope creep. Deviation 3 is the only added surface, ~25 lines, and it is the fix the phase research explicitly asks for (guard #34) applied to this plan's own new directory.

## Requirements

**Nothing was marked complete, deliberately**, following Phase 23's practice of holding a requirement at PARTIAL until every conjunct has a check that reads it.

| Req | State after this plan | What is missing |
|---|---|---|
| **GAMS-01** | PARTIAL | The decision function is total, stream-free and observed; but "the prover is INVOKED as a subprocess" is `Gams.Run`/`Gams.Invoke`, not in this plan. |
| **GAMS-03** | PARTIAL | Detection cannot succeed emptily and the garbage battery is observed rejecting; but "fails loudly" as *aborts the invocation* needs the Tier-B stub check, and "fed into the key" is Phase 25. |
| **GAMS-04** | PARTIAL | Both decoys are observed rejected and the parse is position-independent; the Tier-C row (the version read out of a real run, in the committed capture) does not exist yet. |

## Issues Encountered

- A **concurrent commit by another session** (`d1543eb`, `.planning/REQUIREMENTS.md` + `ROADMAP.md`) landed between task 2 and task 3 in this worktree. It touches no file this plan owns. All `.planning` edits here were made against freshly-read content rather than a cached copy.
- Four pre-existing untracked files at the repository root (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock`) were present before this plan began and were left untouched — they are outside this phase's territory.

## Carry-forwards

1. **`aeson_storage_path` was deliberately NOT extended.** These three modules are not on the artifact path. `Gams/Artifact.hs` is the one that must be added there, and the directory-vs-list check that would make that unforgettable is scoped to the *aeson* scan and belongs to plan 24-04 — the assertion added here covers only the GAMS layer's own no-fallback scan.
2. **The suite wall is now super-linear in check count** because of the sentinel harness. Six pure checks cost 16 s. Tier-B stub checks in later plans each spawn a subprocess *inside* that multiplier; measure before and after.
3. **`Gams.Config`'s exemption is load-bearing and narrow.** If a later plan puts a version value on `Config.hs`'s path, the exemption's written reason stops being true and the module must move into the scanned set.
4. `gams_version_text`/`gams_build_text` are the only doors out of `GamsVersion`; Phase 25 takes version **strings**, so nothing there needs the constructor.

## User Setup Required

None.

## Next Phase Readiness

- The pure half of toolchain identity is in place and falsified. Plans 24-02+ can build `Gams.Run`/`Gams.Invoke` on top of `classify_exit` and the two parsers without re-opening any of it.
- The empty version value is **unconstructible before any row exists**, which is the gate the research states for starting Phase 25.

## Self-Check: PASSED

All three created modules and this summary exist on disk; all three task commits resolve
(`250bb78`, `891d5e2`, `048233e`). `git status --porcelain src test foundry-scripts Makefile
foundry.toml .github` is EMPTY. Suite re-run after every restoration: 117/117, FAIL 0, zero
`-Wall` warnings.

---
*Phase: 24-gams-invocation-toolchain-identity*
*Completed: 2026-08-16*
