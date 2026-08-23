---
phase: 24-gams-invocation-toolchain-identity
plan: 05
subsystem: testing
tags: [haskell, gams, conopt, capture-artifact, tier-c, freshness-oracle, sentinel-sweep, growth-guard, restore-on-failure]

# Dependency graph
requires:
  - phase: 24-gams-invocation-toolchain-identity
    plan: 04
    provides: "GAMS_CONFORMANCE in advertised_overrides, GAMS_BIN/GAMS_MODEL as named gaps, the_suite_never_names_the_real_solver with its proven positive control, and gams_conformance_command -- the advice string that named a script that did not exist until this plan"
  - phase: 24-gams-invocation-toolchain-identity
    plan: 03
    provides: "Gams.Run.run_prover (the ONE spawn), ProverOutcome, artifact_name/log_name, and the carry-forward that gams_verdict_path would need a growth guard the day a third verdict module landed"
  - phase: 24-gams-invocation-toolchain-identity
    plan: 02
    provides: "render_argv / render_decimal / parse_shock_field (the argv oracle the leading-zero and volTgtWad checks use), whitelist_for, and aeson_storage_path's directory-vs-list guard"
  - phase: 24-gams-invocation-toolchain-identity
    plan: 01
    provides: "parse_gams_version and parse_conopt_version -- the SHIPPED parsers that produce every version and every parser verdict the capture records"
  - phase: 23-postgres-foundation
    provides: "capture-store-conformance.sh's refuse-to-emit-a-partial-artifact discipline, the store-conformance Tier-C check shapes, the sentinel sweep, and the PGSTORE_DSN named-gap ruling this plan applies to model_sources"
provides:
  - "Gams.Invoke: the real-prover composition, importable by exactly ONE file -- resolve_gams_bin (absolute, via findExecutable), resolve_gams_model (must EXIST), binary_identity (bare sha256 + size), environment_for/invoke_shock, and raw_gams for the four invocations the production path cannot construct"
  - "offchain/app/GamsConformance.hs and offchain/rig/capture-gams-conformance.sh: the only real-solver caller and the only script that drives it, gating on VALUES and restoring the previous artifact from a saved copy on any non-zero exit"
  - "offchain/rig/gams-conformance.json: 76 leaves of committed real-toolchain evidence, 75 of them read by a check"
  - "Ten Tier-C checks (138/138 -> 149/149 with the growth guard), every one FAILING rather than skipping when the artifact is absent"
  - "gams_verdict_scope_is_decided_module_by_module: the growth guard 24-03's carry-forward said gams_verdict_path would need, with five reasoned exemptions"
  - "GAMS_CONFORMANCE as the SIXTH swept artifact; four tree-derived floors re-measured, all six artifact_field_floors entries measured in ONE run"
affects: [24-06, 25-content-key-and-keyed-store]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A capture records the value it HANDED the child, taken from the function that built it, never a second derivation of what it believes that value to be"
    - "The anchor a set of runs is compared against must come from a file committed before the capture existed -- three runs agreeing with a fourth run is not reproducibility"
    - "A recorded parser verdict is RECOMPUTED by the suite over a narrower input than the capture used, so agreement is a claim about where the banner is rather than a function compared with itself"
    - "A pinned SET is only worth having when an outside oracle independently classifies its members (each hostile variable must carry a key Gams.Env's own forbidden_key_prefixes excludes)"
    - "Restore-on-failure is proven by comparing DIGESTS, never by reading an exit code"
    - "A count-preserving RENAME is the control that shows a count would have missed what a set caught; the deletion alone does not show it"
    - "Every artifact_field_floors entry is re-measured by raising ALL of them by one, so the harness has to name what each artifact enumerated"

key-files:
  created:
    - offchain/lib/Gams/Invoke.hs
    - offchain/app/GamsConformance.hs
    - offchain/rig/capture-gams-conformance.sh
    - offchain/rig/gams-conformance.json
  modified:
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/rig/README.md
    - offchain/test/Main.hs

key-decisions:
  - "TEN Tier-C checks, not the nine the plan's prose says -- its own action text lists ten bullets"
  - "The capture executable writes NO probe model: the script writes all four into its own scratch directory and hands the directory over as argv[1], so no fourth, unadvertised environment variable is needed to pass the path"
  - "golden.sha256 is the digest of the COMMITTED volume-path-golden.json, not of any run, and the suite anchors it to Store.Types.volume_path_golden_sha256 -- a third place"
  - "gams_version is cross-checked against conopt_link_version: two invocations, two parses, one number, in place of a machine-specific pin"
  - "parse_shock_field ADMITS 28e18 and REFUSES 2.8e19; the planned 'both spellings denote one value' assertion is FALSE and was replaced by the measured relationship"
  - "Gams/Invoke.hs joined aeson_storage_path and gams_no_fallback_path in the commit that created it, against the plan's task-1 file list, because 24-03 made that a rule and cabal test would otherwise have been RED at that commit"
  - "GAMS-03 is left PENDING for 24-06 although every row of its test map has now shipped"

patterns-established:
  - "A new module under offchain/lib/Gams/ now joins THREE decided lists, and the third one gained its guard in the same commit"
  - "A capture is re-run at the end of the plan and diffed field-by-field against the committed one, so 'reproducible' names the fields that move"

requirements-completed: [GAMS-01, GAMS-02, GAMS-04, GAMS-06]

# Metrics
duration: ~1h50m
completed: 2026-08-17
---

# Phase 24 Plan 05: The Real Toolchain, Committed — Summary

**The real GAMS 54.1.0 / CONOPT 4.39.0 was driven once, out of band, and every MEASURED value in
24-RESEARCH came back exactly save one line index. Ten checks now rest on the recorded result, 75 of
the artifact's 76 leaves are read by one of them, the restore-on-failure path is proven BY DIGEST,
and `cabal test` still cannot name the solver.**

## Performance

| | Before this plan | After |
|---|---|---|
| checks | 138/138 | **149/149** |
| FAIL | 0 | **0** |
| `-Wall` warnings | 0 | **0** |
| `cabal test` wall (binary pre-built) | **150.3 s** | **156.0 s** |
| swept artifacts | 5 | **6** |
| `sentinel_pair_floor` | 3250 | **3698** |

Budget **900 s**. **+5.7 s** for eleven checks and a sixth swept artifact, and the reason it is that
cheap is `sweep_one`'s `readable` filter: the ten Tier-C checks read only this artifact and spawn
nothing, so each is paid once per pair of ITS 448 rather than 3698 times. `expensive_checks` is
UNCHANGED and that is a decision, not an omission — there is nothing here for `cheap_first` to defer.

`pgrep -a 'sleep 3' | wc -l` is **0** after the suite. No process was leaked and no scratch directory
was stranded: the capture script `rm -rf`s its own scratch tree on every exit path.

## Task Commits

| Task | Name | Commit |
|---|---|---|
| 1 | The module that names the real prover, and the two files allowed to import it | `15c539c` |
| 2 | The real toolchain's behaviour is committed evidence, and ten checks rest on it | `2e1a390` |
| 3 | The sixth swept artifact, six floors re-measured in one run, every leaf accounted for | `ac607bd` |

## What the real toolchain did

Everything below is `offchain/rig/gams-conformance.json`, produced by
`bash offchain/rig/capture-gams-conformance.sh` against
`/usr/gams/gams54.1_linux_x64_64_sfx/gams` and the `volume_path.gms` in the sibling `cfmm-wt/gams`
worktree.

| observation | 24-RESEARCH said | this capture measured |
|---|---|---|
| clean solve digest / length | `e7b14f38…07d0d884` / 606 | **identical** |
| `action=c` | exit 0, artifact ABSENT | **exit 0, `artifact_present` false** |
| no arguments | exit 0, stdout 1239, stderr 0 | **identical**, line 1 `--- Job ? Start …` |
| `--version` | exit 6, stdout 275, stderr 0 | **identical**, line 1 `--- Job --version Start …` |
| exit codes | 0 / 2 / 3 / 3 / 6 / 0 / 0 | **identical** |
| CONOPT true | `4.39.0` | **`4.39.0`** |
| CONOPT decoys | `54.1.0` link, `libconopt464.so` | **identical** |
| true banner line index | probe 38, real run 47 | probe **38**, real run **48** |
| leading zero `079228…` | exit 0, gates green, `d64a7b32…14b9e650` | **identical** |
| `28e18` vs `2.8e19` | byte-identical, both golden | **identical** |
| hostile env (4 variables) | golden | **golden** |
| minimal env (`LC_ALL`, `PATH`) | golden | **golden** |
| `gams` binary | 1,822,256 bytes, `79cd3a57…` | **identical** |

**ONE DIFFERENCE, and it is recorded rather than reconciled.** The true CONOPT banner sits at line
**48** of the production run's own `volume_path.log`, not 47. The probe's 38 matches exactly. The
claim the check makes — the two positions DIFFER, so a positional parse would answer correctly for
one and wrongly for the other — is untouched; the research number is off by one and this summary is
the correction. Nothing was adjusted to make it agree.

## The artifact, and why every leaf is accounted for

**76 leaves** by the harness's own enumeration (`jq 'paths(scalars)'` says 75; the harness's number is
the larger one and it is the one budgeted with, exactly as 23-05's note says). The plan asked for
50–70 and this is six over — a deviation of record, taken deliberately: the nine `observations` cost
18 leaves on their own and the alternative was to make the verdict list a count, which 23-05 MEASURED
passing a deletion.

**The harness's first run over it reported exactly ONE absorbed field.** 23-05's first run over the
store artifact reported four and promoted three of them to assertions; this one had nothing left to
promote, because the fields that would otherwise have been pardoned were asserted while the checks
were being written:

| field that could have been pardoned | what was asserted instead |
|---|---|
| `conopt_true_line_index_probe` / `_real` | both `> 0` AND unequal — `0 /= 48` is satisfied by an index never measured |
| `gams_version_method`, `conopt_method` | must CONTAIN the name of the parser that produced their value; "non-empty" is satisfied by a zero address |
| `hostile_env_run.vars` | the SET is pinned AND every member's key must match a prefix in `Gams.Env.forbidden_key_prefixes` |
| `minimal_run.vars` | a PROPER subset of `whitelist_keys`, length 2, `HOME` absent — "minimal" is the claim |
| `no_args.line1`, `version_flag.line1` | RECOMPUTED with `parse_gams_version` and required to be a `WrongJob` rejection |
| `voltgt_rendering.a` / `.b` | run through `parse_shock_field` in both directions (see the deviation below) |
| `leading_zero_run.token` | computed from `render_decimal` over the Tier-B shock — an outside oracle |
| `gams_size`, `gams_sha256`, `gams_path`, `gams_build` | shape: positive, 64 bare hex, absolute, 8 lowercase hex |

The one pardon is `generatedAt`, and it reuses `reason_generated_at` — the same field 21-02 already
MEASURED as not being a regeneration witness in this repository.

### The absorbed-pair decision, in full

| pair | decision | why |
|---|---|---|
| `gams-conformance.json.generatedAt` × all six sentinels | **PARDONED** | 21-02's measurement: the capture completes well inside the one-second stamp resolution, so two back-to-back runs share a timestamp and a stale file passes a timestamp comparison silently. There is no comparand. |

Nothing else was reported. Every other (field, sentinel) pair of the 448 exercised was CAUGHT.

## Three things that refuse to be tautologies

24-04 MEASURED the cost of the alternative: with `gams_conformance_env_var` in the override list,
`uncovered` compared the constant to itself, `probe_override` set the environment by that same
constant, and renaming the config left the suite **138/138 green with the library renamed
underneath it**. Every assertion below was written against that.

1. **The anchor is a third place.** `golden.sha256` is the digest the capture took of the COMMITTED
   `volume-path-golden.json` — a file that existed before this capture did — and the suite compares
   it against `Store.Types.volume_path_golden_sha256`, a Haskell constant. Had `golden` been the
   whitelisted run's own digest, `whitelist_run.sha256 == golden.sha256` would have been a value
   compared with itself, and the minimal and hostile runs would have been three runs of one toolchain
   agreeing with a fourth run of the same toolchain.
2. **The parser verdicts are recomputed over a NARROWER input.** The capture parsed the whole stdout;
   the suite re-runs the same shipped parser over the recorded FIRST LINE and requires (a) a
   `WrongJob` rejection specifically — `EmptyInput` and `NoJobBanner` are the answers a sentinel
   produces — and (b) exact agreement with the recorded string. Agreement is therefore a claim about
   where the banner is, not a function compared with itself.
3. **The GAMS version has a second, independent reading.** `gams_version` comes from the clean
   solve's job banner; `conopt_link_version` comes from the GAMS-side CONOPT link line in a
   DIFFERENT invocation (the 8-line NLP probe). Two invocations, two parses, one number — which is
   what stands in for the machine-specific pin this suite must not carry. Firing observation 3 shows
   both checks reddening on one mutation, which is the cross-check working.

## The fourteen firing observations

Every mutation applied ALONE; every source restored **from a saved copy** verified by digest, never
by `git checkout`; the committed artifact's sha256 is **`a46e0f5b62856d75b91245bea769d1eefc37118a66fc5de18aafa3099047b1d2`** before and after all of them.

### Task 1 — the growth guard 24-03 said this list would need

**1. An unlisted module in the layer.** `offchain/lib/Gams/Publish.hs` created, listed nowhere:

```
FAIL gams_verdict_scope_is_decided_module_by_module: the modules on disk under offchain/lib/Gams are not the set the verdict scan decided about.
      on disk but neither scanned nor exempt: offchain/lib/Gams/Publish.hs
      A new module in this layer is added to gams_verdict_path -- or to gams_verdict_exempt WITH A WRITTEN REASON -- in the commit that creates it. 24-03 left this list unguarded deliberately and wrote down the condition that would end the exemption; Gams/Invoke.hs is that condition.
135/139 checks passed
```

**2. A thin exemption reason.** `Argv.hs`'s reason replaced with `"EXEMPT. Not needed."`:

```
FAIL gams_verdict_scope_is_decided_module_by_module: these gams_verdict_exempt entries carry no real reason: offchain/lib/Gams/Argv.hs. An exemption without a defended reason is how a scan's scope shrinks to the empty set one plausible file at a time.
137/139 checks passed
```

**3. The GAMS-free scan, on this plan's own haddock — INSTANCE 17.** Not a deliberate mutation; the
suite went red on the first full run of Task 1:

```
FAIL the_suite_never_names_the_real_solver: this test suite NAMES the real solver:
      offchain/test/Main.hs:7244:-- @Gams.Invoke@ and the capture tooling, and @rig\/gams-conformance.json@ lands with the capture
      offchain/test/Main.hs:9622:-- 'Gams.Exit' holds the taxonomy, 'Gams.Run' holds the conjunction, and 24-05's 'Gams.Invoke'
      offchain/test/Main.hs:9629:-- either grow or gain a guard\"/. 'Gams.Invoke' is that third module, so it does both --
```

The three PATH literals `"offchain/lib/Gams/Invoke.hs"` in the scanned lists did **not** match — the
pattern is anchored on the DOTTED module form. Only the prose did. Seventeenth time on this branch;
the prose moved and the pattern did not.

### Task 2 — the capture's restore path, PROVEN BY DIGEST

Phase 23's first docker probe passed its exit-code check while the artifact changed underneath it, so
an exit code is not the instrument. One byte of `volume-path-golden.json` (`490000` → `490001`,
length unchanged at 606), which fires a self-check that runs AFTER `write_json_atomically`:

```
wrote offchain/rig/gams-conformance.json
  GOLDEN    2387ec9c22a6c4ef61bfcc7fd59b591e2a686e4c92c63abeb872b713abb7d4f5  (606 bytes)
  VERDICTS  6/9 pass
CAPTURE FAIL: 3 of 9 observations did not pass against the real toolchain:
              clean_solve_reproduces_the_committed_golden_bytes
              the_minimal_whitelist_reproduces_the_golden_bytes
              a_hostile_environment_leaves_the_bytes_identical
              Report it as a FINDING about the toolchain; do not adjust the numbers.
  RESTORED offchain/rig/gams-conformance.json to its previous contents (sha256 a46e0f5b62856d75b91245bea769d1eefc37118a66fc5de18aafa3099047b1d2).
           The capture failed, so the evidence it would have replaced is kept.
capture exit=1
artifact AFTER  = a46e0f5b62856d75b91245bea769d1eefc37118a66fc5de18aafa3099047b1d2
RESTORE PROVEN BY DIGEST: IDENTICAL
```

The capture DID write a new artifact — the `wrote` line carries the mutated golden's digest — and the
original came back byte-identical. `volume-path-golden.json` restored to `e7b14f38…07d0d884`.

### Task 2 — the ten checks, five mutations plus a control

**4. The artifact moved aside.** All ten FAIL, each naming the capture command, **none skips**:

```
FAIL gams_conformance_is_present_and_fresh: no offchain/rig/gams-conformance.json -- re-take it with: bash offchain/rig/capture-gams-conformance.sh
FAIL gams_conformance_records_the_measured_exit_codes: no offchain/rig/gams-conformance.json -- re-take it with: bash offchain/rig/capture-gams-conformance.sh
FAIL gams_conformance_records_action_c_exit_zero_with_no_artifact: ... (same)
FAIL gams_conformance_records_the_wrong_subject_banners: ... (same)
FAIL gams_conformance_records_the_resolved_binary_and_its_digest: ... (same)
FAIL gams_conformance_records_conopt_and_the_method_that_found_it: ... (same)
FAIL gams_conformance_records_byte_identity_under_a_hostile_environment: ... (same)
FAIL gams_conformance_records_the_minimal_whitelist_reproducing_the_golden_bytes: ... (same)
FAIL gams_conformance_records_the_leading_zero_changing_the_bytes: ... (same)
FAIL gams_conformance_verdicts_are_all_pass: ... (same)
138/149 checks passed
```

**5. `action_c.artifact_present := true`** (scratch copy through `GAMS_CONFORMANCE`):

```
FAIL gams_conformance_records_action_c_exit_zero_with_no_artifact: the capture records action=c at exit 0 with artifact_present True, and the MEASURED pair is 0 / False.
147/149 checks passed
```

**6. `conopt_link_version := conopt_version`** — TWO checks fired, the second unplanned and welcome:

```
FAIL gams_conformance_records_the_resolved_binary_and_its_digest: the capture records gams_version "54.1.0" from the clean solve's job banner and conopt_link_version "4.39.0" from the NLP probe's GAMS-side link line.
FAIL gams_conformance_records_conopt_and_the_method_that_found_it: the true CONOPT version "4.39.0" EQUALS a decoy (link "4.39.0", shared object "libconopt464.so").
146/149 checks passed
```

**7. One observation DELETED** (9 → 8):

```
FAIL gams_conformance_verdicts_are_all_pass: an observation the set names has NO entry in the capture: conopt_true_version_differs_from_both_decoys
147/149 checks passed
```

**8. THE COUNT-PRESERVING CONTROL**, because observation 7 alone does not answer the plan's question
"would a count over the same document still have passed". The same entry RENAMED instead of deleted:
**length still 9, zero non-pass verdicts — a count passes and a verdict sweep passes** — and the SET
reddens in both directions:

```
FAIL gams_conformance_verdicts_are_all_pass: an observation the set names has NO entry in the capture: conopt_true_version_differs_from_both_decoys
      the capture reports an observation the set does not name: conopt_true_version_differs_from_one_decoy
147/149 checks passed
```

**Answer of record: yes, a count would have passed.** 23-05 measured it for a deleted law; this is the
same finding on a renamed observation, and it is why the assertion is a set in both directions.

**9. ONE SPACE appended to `offchain/lib/Gams/Argv.hs`, no re-capture:**

```
FAIL gams_conformance_is_present_and_fresh: the committed GAMS conformance capture is STALE. These modules have been edited since it was taken:
      offchain/lib/Gams/Argv.hs: recorded=e7475dd7095136798c22ee3fd04a784d0e845d368e9344413584aa6d406e0409 recomputed=a8c9c2b0f21d21d6d41364989fbb3c7010a319771ebbb6cb1eeb92cbafb3c331
      The first renders the argv token that DECIDES the artifact's bytes and the second decodes them back; every byte claim in that artifact was measured against the OLD code and nothing here can tell you whether it still holds.
147/149 checks passed
```

`Argv.hs` restored sha256-identical to `e7475dd7…6e0409` from a saved copy.

**10. The check the plan wrote could not be satisfied.** See deviation 1 — `parse_shock_field` refuses
`2.8e19`, so the planned assertion went RED on its first run:

```
FAIL gams_conformance_records_the_leading_zero_changing_the_bytes: the two recorded volTgtWad spellings are "28e18" and "2.8e19", and they must be DIFFERENT strings that Gams.Argv's edge normaliser maps to the same value (28000000000000000000).
147/149 checks passed
```

### Task 3 — the sweep

**11. The pair floor, raised until the harness reported what it reached:**

```
FAIL sentinel_falsification_harness: the sweep exercised 3698 (field, sentinel) pairs, below the floor of 999999. ...
```

**12. All six field floors, measured in ONE run** by raising every entry by exactly 1:

```
FAIL sentinel_falsification_harness: the sweep enumerated fewer fields than the floor in:
      rig-manifest.json: 20, floor 21
      rig-pins.json: 110, floor 111
      driver-run-capture.json: 151, floor 152
      cheat-swap-proof.json: 130, floor 131
      store-conformance.json: 134, floor 135
      gams-conformance.json: 76, floor 77
```

**13. The absorbed pairs, reported by name:**

```
FAIL sentinel_falsification_harness: these (field, sentinel) pairs were ABSORBED SILENTLY -- the value was replaced on ONE side only and nothing in the suite objected. Each one is a field nothing here asserts:
      gams-conformance.json.generatedAt  :=  empty-string  x1
      gams-conformance.json.generatedAt  :=  git-null-object-id  x1
      gams-conformance.json.generatedAt  :=  json-null  x1
      gams-conformance.json.generatedAt  :=  numeric-zero  x1
      gams-conformance.json.generatedAt  :=  zero-address  x1
      gams-conformance.json.generatedAt  :=  zero-word  x1
```

**14. The OTHER direction of `absorbed_by_design`**, which is what stops the pardon list from only
ever growing. A bogus entry for a field that IS asserted:

```
FAIL sentinel_falsification_harness: absorbed_by_design lists (field, sentinel) pairs that are now CAUGHT:
      gams-conformance.json.gams_size  :=  empty-string  x1
      gams-conformance.json.gams_size  :=  numeric-zero  x1
      An ignore list that only ever grows is how a count floor gets defeated by a rename. Delete these entries.
```

`Main.hs` restored from a saved copy, sha256 `bafa130d…47336ed6` before and after.

## The four floors, all measured in this plan's runs

```
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l
58                                                    # at Task 1's commit AND at Task 3's
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
66                                                    # at Task 1's commit
67                                                    # at Task 2's commit, with the artifact on disk
```

| floor | was | now | how |
|---|---|---|---|
| `purge_file_floor` | 55 | **58** | `find … \| wc -l`, zero slack against exactly 58 |
| `credential_scan_floor` | 63 | **66 → 67** | measured TWICE; the `.json` half moved alone at Task 2 |
| `sentinel_pair_floor` | 3250 | **3698** | raised until the harness named 3698 |
| `artifact_field_floors` | 5 entries | **6**, `("gams-conformance.json", 76)` | all six raised by 1 so the harness named each |

**The five older `artifact_field_floors` entries came back at EXACTLY the numbers written at 23-05.**
None has drifted. That is a measurement and it is the answer to the plan's question.

**The arithmetic check on `sentinel_pair_floor`:** `3698 − 3250 = 448`. 76 leaves × 6 sentinels = 456
possible, so **8** were skipped as identities — all eight the numeric zero against a recorded zero,
and they are named in the haddock rather than counted: `exit_codes.clean`, `exit_codes.no_args`,
`exit_codes.action_c`, `action_c.exit`, `no_args.exit`, `no_args.stderr_len`,
`version_flag.stderr_len`, `leading_zero_run.exit`. Three of those zeroes ARE the phase's finding
(exit 0 means GAMS ran; stderr is empty in every mode). The five older artifacts therefore still
contribute exactly 3250, which is what says none of them silently shrank.

**Census under `offchain/` at Task 3:** `hs 47, sh 9, json 9, md 3, txt 2, sql 2`.

## Deviations from Plan

### 1. [Rule 1 — the plan's assertion is FALSE] `parse_shock_field` refuses `2.8e19`

- **Found during:** Task 2, on the check's first run.
- **Issue:** the plan asks the volTgtWad arm to assert that both recorded spellings denote one value.
  MEASURED: `parse_shock_field "28e18" == Right 28000000000000000000`, and
  `parse_shock_field "2.8e19"` is a `Left (NotADecimalInteger …)` — 24-02 refuses a fractional
  mantissa on FORM, because admitting it would require deciding when a floating spelling is exact and
  that decision does not belong at an edge. GAMS accepts both and produces identical bytes.
- **Fix:** assert the REAL relationship, with the shipped function used in BOTH directions: the two
  strings differ; the first is ADMITTED and denotes the golden's `volTgtWad`; the second carries a
  decimal point and is REFUSED. **This repository's edge is stricter than the solver**, and that
  asymmetry is now a recorded finding rather than an inconvenience.
- **Files modified:** `offchain/test/Main.hs`. **Commit:** `2e1a390`.

### 2. [Rule 3 — Blocking] `Gams/Invoke.hs` had to join two scanned lists in Task 1

- **Found during:** Task 1, first `cabal test`.
- **Issue:** the plan's task-1 file list does not include `offchain/test/Main.hs`, but
  `aeson_storage_path` and `gams_no_fallback_path` are both asserted against
  `offchain/lib/{Store,Gams}/` in BOTH directions, so a new module there reddens two checks the
  moment it exists. 24-03 established the rule in those words: *a new module under
  `offchain/lib/Gams/` joins BOTH scanned lists in the commit that creates it.*
- **Fix:** both lists extended in Task 1's commit, plus the third (see deviation 3). `cabal test` is
  green at every commit of this plan.
- **Commit:** `15c539c`.

### 3. [Rule 2 — Missing critical] `gams_verdict_path` had no growth guard

- **Found during:** Task 1.
- **Issue:** 24-03's carry-forward left this list unguarded deliberately and named the condition that
  would end the exemption: *"the day a third such module lands, that list must either grow or gain a
  guard"*. This plan lands that module. **Third list in this phase found without a growth guard, and
  the third to get one** (after `artifact_float_path` at 24-02 and `config_env_vars` at 24-04).
- **Fix:** `gams_verdict_scope_is_decided_module_by_module` compares `gams_verdict_path` plus
  `gams_verdict_exempt` against the directory in both directions, and rejects an exemption whose
  reason is under 120 characters. Five exemptions, each defended. `Argv.hs`'s and `Version.hs`'s are
  specific to THIS pattern rather than generic: `Argv.hs` carries the model-status adjective as
  VOLUME_PATH.md §1.2's own word for a fact known from the INPUT, and scanning `Version.hs` would
  forbid the substring search that is how a banner is legitimately read. Widening the scan would have
  been the wrong move; the pattern does not mean the same thing in every file.
- **OBSERVED:** firing observations 1 and 2. **Commit:** `15c539c`.

### 4. [Deviation of record] TEN checks, not nine

The plan says "nine Tier-C checks" three times and its own action text lists **ten** bullets. Ten
shipped. `grep -c '^PASS gams_conformance_'` is 10, which satisfies the ≥9 criterion.

### 5. [Deviation of record] 76 leaves, not 50–70

The plan asks for 50–70 and records the enumerated count. 76, deliberately: the `observations` block
is 18 leaves on its own and the alternative to a named list is a count, which 23-05 MEASURED passing
a deletion and firing observation 8 measured again here. The cost is 448 pairs and, measured, +5.7 s
of wall against a 900 s budget.

### 6. [Deviation of record] The capture script writes the probe models; the executable does not

The plan's task-1 action puts the 8-line CONOPT probe in the script, which is where it is. The four
crafted models (compile error, named abort, unhandled execution error) went there too, and the
executable takes the scratch directory as `argv[1]` — the `store-conformance --migrate-only <dir>`
precedent. The alternative was a fourth environment variable to pass the path, and an environment
variable the override sweep does not know about is the advertised-and-dead defect in reverse. The
executable REFUSES to run when any of the four is missing, naming the file and the script.

### 7. [Deviation of record] `grep -rl 'Gams.Invoke'` names three files, not two

Task 1's acceptance criterion expects two. With an UNESCAPED dot, `grep` matches the path literals
`offchain/lib/Gams/Invoke.hs` in Main.hs's three scanned lists as well. With the escaped dot — the
form `gams_free_pattern` itself uses — it is exactly two:

```
$ grep -rlE 'Gams\.Invoke' offchain/ --include=*.hs
offchain/app/GamsConformance.hs
offchain/lib/Gams/Invoke.hs
```

### 8. [Deviation of record] The line index the research recorded is off by one

Probe 38 matches. The production run's own log puts the true banner at **48**, not 47. Recorded, not
reconciled; the check asserts the two DIFFER and both are positive.

---

**Total deviations:** 8 (1 measurement-over-plan on an assertion that could not hold, 1 blocking,
1 missing-critical, 5 of record)

## The capture re-run, diffed field by field

The plan's verification asks for a re-run from scratch. It was done after Task 3 and every recorded
value is identical **except three**:

```
$ diff <(jq -S 'del(.generatedAt)' committed.json) <(jq -S 'del(.generatedAt)' fresh.json)
63c63  no_args.line1        08/16/26 23:12:16  ->  08/16/26 23:59:45
108c108 version_flag.line1  08/16/26 23:12:17  ->  08/16/26 23:59:45
```

`generatedAt` and the two banner `line1` fields carry a WALL CLOCK, so this artifact is deliberately
NOT byte-stable across re-captures and a future plan must not assert that it is. The two `line1`
fields are asserted by RECOMPUTATION rather than by value, which is exactly why that is harmless. The
committed artifact was restored byte-identically afterwards and `git status --porcelain` is clean.

## Requirements

| Req | State after this plan | Why |
|---|---|---|
| **GAMS-01** | **COMPLETE** | Its fourth and last row, `gams_conformance_records_the_measured_exit_codes`, shipped here and was OBSERVED. The other three shipped at 24-01 and 24-03 and every one is observed. |
| **GAMS-02** | **COMPLETE** | Its fifth row, `gams_conformance_records_action_c_exit_zero_with_no_artifact`, shipped here — the real binary producing exit 0 with no artifact, rather than a stub shaped like it. |
| **GAMS-03** | **PENDING, deliberately** | Every row of its test map has now shipped, including `gams_conformance_records_the_resolved_binary_and_its_digest`. It is left for 24-06 because that plan's frontmatter claims it and adds the layer 24-RESEARCH's "why 24 precedes 25" gate recommends: `NOT NULL` does not forbid `''` (M14), and migration `003`'s CHECK is the defence that outlives every Haskell refactor. Marking it here and again there would be noise. |
| **GAMS-04** | **COMPLETE** | `gams_conformance_records_conopt_and_the_method_that_found_it` shipped, and firing observation 6 shows it reddening when the exhibit loses its decoy. |
| **GAMS-05** | COMPLETE (24-04) | untouched. |
| **GAMS-06** | **COMPLETE** | Both of its remaining rows shipped: byte-identity under four hostile ambient variables, and the minimal whitelist reproducing the golden bytes. Correction 2's honest form — the child's own environment vector — closed at 24-04. |
| **BYTE-04** | COMPLETE (24-02) | untouched. |

## Issues Encountered

- The `voltgt_rendering` arm of check 9 went red on its first run because the plan's assertion was
  false. Fixed by measurement, not by relaxing the check. See deviation 1.
- The GAMS-free scan went red on Task 1's own haddock (instance 17). The prose moved.
- Four pre-existing untracked files at the repository root — `CHANGELOG.md`, `Setup.hs`,
  `stack.yaml`, `stack.yaml.lock` — predate this plan, are outside its territory, and were left
  alone.

## Carry-forwards

1. **`gams-conformance.json` is not byte-stable across re-captures** and three fields say so:
   `generatedAt` and the two banner `line1`s carry a wall clock. Any future plan re-taking this
   capture will produce a diff in exactly those three fields and nowhere else — that has been
   MEASURED, not assumed.
2. **`Gams.Invoke.raw_gams` uses `/usr/bin/timeout` and `readCreateProcessWithExitCode`, and neither
   its budget nor its backstop has been observed firing.** 24-03's carry-forward 3 applies again one
   layer up: a timeout never seen expiring is, by this phase's own rule, absent. The production path
   through `run_prover` HAS been falsified (24-04, the hung grandchild); this second wrapper has not.
3. **`conopt_true_line_index_real` is 48 and 24-RESEARCH says 47.** The research document was not
   edited. If a later plan cites that number, it should cite this summary.
4. **The four probe models live in the capture script and the executable requires them by NAME.**
   Both sides list the same four filenames; the executable fails loudly naming the missing one, but
   nothing compares the two lists. If a fifth exit-code observation is ever added, both sides move.
5. **`gams_conformance_unrecomputable` has exactly one entry and the check asserts that count.** If a
   second unrecomputable field ever appears, that assertion moves with it — deliberately, so a gap
   cannot be added silently.

## User Setup Required

`GAMS_MODEL` must be set to the absolute path of `volume_path.gms` in the sibling `cfmm-wt/gams`
worktree before running `bash offchain/rig/capture-gams-conformance.sh`. The path is machine-specific
and is documented in `offchain/rig/README.md`; it is deliberately absent from every tracked file.
Nothing is required to run `cabal test`.

## Next Phase Readiness

24-06 (wave 6, the last) is unblocked and is the only plan left in phase 24. It adds migration
`003_version_columns_nonempty.sql`, moves `Store.Schema.expected_migrations` to three entries, and
re-captures `store-conformance.json` — whose computed freshness oracle recomputes every migration's
md5 from the repository's own `.sql` files, which is why that plan is last. It also moves
`purge_file_floor` (a `.sql` is a scanned type) and `credential_scan_floor` again, and both must be
re-measured cold, together, in the same sitting.

## Self-Check: PASSED

- `offchain/lib/Gams/Invoke.hs` — FOUND.
- `offchain/app/GamsConformance.hs` — FOUND.
- `offchain/rig/capture-gams-conformance.sh` — FOUND, mode 100755.
- `offchain/rig/gams-conformance.json` — FOUND, tracked, `jq -e '.gc_complete'` prints `true`.
- Commits `15c539c`, `2e1a390`, `ac607bd` — all three FOUND in `git log`.
- `cabal build --enable-tests -j all`: exit 0, **0** warnings. `cabal test`: exit 0.
- Suite **149/149**, `grep -c '^FAIL '` = **0**, including `sentinel_falsification_harness`.
- `grep -cE 'Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams' offchain/test/Main.hs` = **0**.
- `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` = **0**.
- `grep -c 'sentinel_pair_floor = 3250' offchain/test/Main.hs` = **0**.
- `grep -c '("gams-conformance.json", ' offchain/test/Main.hs` = **1**.
- `grep -c 'gams-conformance.json' offchain/test/Main.hs` = **8**.
- `pgrep -a 'sleep 3' | wc -l` = **0**.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` = EMPTY.

---
*Phase: 24-gams-invocation-toolchain-identity*
*Completed: 2026-08-17*
