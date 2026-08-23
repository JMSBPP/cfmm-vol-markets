---
phase: 24-gams-invocation-toolchain-identity
plan: 02
subsystem: testing
tags: [haskell, gams, argv, renderer, artifact-decoder, byte-exactness, source-scan, scope-growth]

# Dependency graph
requires:
  - phase: 24-gams-invocation-toolchain-identity
    plan: 01
    provides: "Gams.Config's named-once idiom, the Check/pure_check/expect runner, and the directory-vs-list assertion pattern this plan applies to the aeson scan"
  - phase: 23-postgres-foundation
    provides: "Store.Json's total pure recogniser (the precedent for a hand-rolled decoder), Store.Types.volume_path_golden_sha256 / _bytes_len / sha256_hex, and the aeson_storage_path scan this plan extends"
provides:
  - "Gams.Argv: Shock as seven strict Integers with no optional field, render_decimal, render_argv (seven tokens, eight refusals), and parse_shock_field as the EDGE normalizer that makes the leading zero unable to reach the execve"
  - "Gams.Env: the invocation whitelist as data, LC_ALL pinned to C, five forbidden prefixes, and validate_env asserting the key SET in both directions"
  - "Gams.Artifact: a hand-rolled [Integer] decoder behind Store.Json, both echoed fields and both fractional fields kept as verbatim TEXT, pa_bytes as the oracle"
  - "Nine Tier-A checks registered in core_checks (117/117 -> 126/126)"
  - "aeson_storage_path extended to the whole GAMS layer AND asserted against offchain/lib/{Store,Gams}/ in both directions, so the scan's scope cannot silently fail to grow"
affects: [24-03, 24-04, 24-05, 24-06, 25-content-key-and-keyed-store]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The edge NORMALIZES rather than refuses: a leading zero is rebuilt from its digits and re-spelled, so two spellings of one value cannot key two rows"
    - "A truncation is asserted as an EQUALITY on Integers with a stated sign convention, never as a tolerance"
    - "A provenance digest is asserted BEFORE the decode it authorises"
    - "Two source scans over the same directory share ONE file set, so one growth guard covers both"

key-files:
  created:
    - offchain/lib/Gams/Argv.hs
    - offchain/lib/Gams/Env.hs
    - offchain/lib/Gams/Artifact.hs
  modified:
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/test/Main.hs

key-decisions:
  - "parse_shock_field NORMALIZES the leading zero instead of refusing it -- refusing moves the problem to the caller; normalizing settles it, and settles KEY-04 with it"
  - "The exponent is BOUNDED at 10^96: an unbounded one turns a 4-character token into an arbitrary allocation supplied by whoever supplies the shock"
  - "BYTE-04's 32 wei is asserted as image MINUS exact = +32, the research table's sign convention, stated in the failure message because the check was first written the other way round and the first run caught it"
  - "artifact_float_path is aeson_storage_path, not a two-file list -- one set, one growth guard, thirteen more files covered at zero cost"
  - "BYTE-04 is marked COMPLETE; GAMS-02 and GAMS-06 are held at PARTIAL because their remaining conjuncts are Tier-B subprocess checks that do not exist yet"

patterns-established:
  - "A new module under offchain/lib/{Store,Gams}/ is added to aeson_storage_path in the commit that creates it, and a check now makes that unforgettable rather than merely written down"
  - "Every guard that scans source is pointed at a set some OTHER check asserts against the directory"

requirements-completed: [BYTE-04]

# Metrics
duration: 33min
completed: 2026-08-16
---

# Phase 24 Plan 02: The Renderer, the Whitelist, and the Decoder — Summary

**A leading zero that MEASURED a different sha256 can no longer reach the `execve`, `dQx[0]`'s 32-wei loss is an equality on `Integer`s tied to the committed file by a digest checked before the decode, and the aeson scan's scope now grows by construction rather than by anyone remembering to grow it — nine Tier-A checks, five of them OBSERVED failing against their named inputs.**

## Performance

- **Duration:** 33 min
- **Started:** 2026-08-16T23:35:49Z
- **Completed:** 2026-08-17T00:09Z
- **Tasks:** 3 (plus one in-plan fix commit)
- **Files modified:** 5 (3 created, 2 modified)

## Accomplishments

- `parse_shock_field` **normalizes at the edge**, so `079228162514264337593543950336` and `79228162514264337593543950336` become one `Integer` and one token. The M7 arm asserts the produced token carries no `=0` and quotes both MEASURED digests (`d64a7b32…14b9e650` against the golden `e7b14f38…07d0d884`).
- `parse_shock_field "28e18" == parse_shock_field "28000000000000000000"` — **Phase 25's KEY-04 settled upstream of any row**, in the phase that owns the rendering.
- `Shock` carries **seven strict `Integer`s, no optional and no defaultable field**, and eight shape-valid shocks are refused **by field name** — including the §1.2 equal-fee case, refused in this process rather than recovered from a code-3 abort that cannot be distinguished from an unhandled execution error.
- `decode_artifact` produces `[Integer]`, keeps **both echoed fields and both fractional fields as verbatim text**, and contains no 53-bit type and no JSON library. `pa_bytes` keeps the oracle.
- BYTE-04 asserted as **two equalities on `Integer`s** plus **16 of 16** elements inexact with `|delta|` in `[4, 328]`, all tied to `offchain/rig/volume-path-golden.json` by a digest asserted **before** any decode.
- `aeson_storage_path` **extended to the whole GAMS layer in the same commit**, and `the_artifact_path_scan_covers_every_module_on_it` now asserts it against `offchain/lib/{Store,Gams}/` **in both directions** with an empty, reasoned exemption list.
- Suite **117/117 → 126/126**, FAIL 0, zero `-Wall` warnings, still DB-free and GAMS-free, `+0` packages.

## Task Commits

1. **Task 1: `Gams.Argv`** — `2a62cce` (feat)
2. **Task 2: `Gams.Env` and `Gams.Artifact`** — `46ba4fc` (feat)
3. **Task 3: nine Tier-A checks, both floors re-measured** — `2a558e3` (test)
4. **In-plan fix: the float scan's scope must grow too** — `8fc2bd6` (fix)

## The live hole the orchestrator reassigned — CLOSED HERE, not deferred

Wave 1 handed forward that `aeson_storage_path` had no directory cross-check and proposed 24-04 for the fix. **It was not deferred.** `Gams/Artifact.hs` went onto the scanned list in the commit that created it, five sibling modules went with it, and research guard 34 landed in the same commit as a both-directions assertion over `offchain/lib/{Store,Gams}/`.

Two consequences worth recording:

1. **Scoping the scan to "the modules that obviously need it" is the same judgement call that left `Store/Schema.hs` out for two commits.** All six GAMS modules are listed, not the one that decodes.
2. **`aeson_scan_exemptions` is EMPTY, and that is a fact rather than a placeholder.** Every module under both directories is scanned today.

## The five firing observations

Each mutation was applied, the suite run, the verbatim FAIL captured, and the source restored **from a saved copy** (never `git checkout`), verified against pinned digests: `Argv.hs` `e7475dd7…6e0409`, `Artifact.hs` `ac943852…5632e4`, `Env.hs` `2e78bfc3…7ed7fe`, `volume-path-golden.json` `e7b14f38…07d0d884`. `git status --porcelain offchain/` carried no mutation residue afterwards.

### 1a. `render_decimal` emits a leading zero

Mutation: `render_decimal = show` became `render_decimal n = '0' : show n`.

```
FAIL argv_rendering_is_canonical_and_total: argv token 0 is "--sqrtPriceX96=079228162514264337593543950336", expected "--sqrtPriceX96=79228162514264337593543950336". The order and the spelling are both fixed: GAMS accepts these parameters in any order, so a renderer that reordered them would still solve while producing a different command line for the same shock.
```

The plan predicted the **M7 arm** would name it. The **element-by-element arm fired first**, because it compares the same field — so the token containing `=0` is named, but by the positive arm rather than by the arm written for it. Recorded rather than smoothed over, and it is why 1b exists.

### 1b. the edge REFUSES the leading zero instead of normalizing it — the M7 arm's own input

Mutation: a guard added to `from_digits` rejecting a leading zero.

```
FAIL argv_rendering_is_canonical_and_total: parse_shock_field REFUSED "079228162514264337593543950336" as NotADecimalInteger "079228162514264337593543950336" "the token carries a leading zero". It must NORMALIZE it: a leading zero is a legal spelling of a legal value arriving from outside, and refusing it moves the problem to the caller instead of settling it.
```

This is the arm the plan named, exercised by an input that leaves the seven fixture tokens correct. Both mutations are recorded; neither was discarded.

### 2. `decode_artifact` accepts `1.5` as `1`

Mutation: `integer_token token` became `integer_token (takeWhile (/= '.') token)`.

```
FAIL the_artifact_decoder_refuses_a_non_integer_token: the token "1.5" (fractional) was ACCEPTED into dQx as [1,7]. Those arrays are swap amounts in wei; a token this decoder had to interpret is an amount the model never chose.
```

### 3. ONE byte of the committed artifact

Mutation: byte 268 of `offchain/rig/volume-path-golden.json`, `…530400` → `…530401`. **Length unchanged at 606**, so the length assertion could not be the one that fired.

```
FAIL the_golden_vector_comes_from_the_committed_artifact: the golden artifact's sha256 is 342db389e5e6543f4ffdcf214760027d2cebe080bd867a8c4ec01ed685523fee and Store.Types pins e7b14f384ab4c027be5450218a52040110d45dbaddbbfb0bb7bd5ab707d0d884. This is asserted BEFORE the decode on purpose: an edited artifact would otherwise decode into a different-but-plausible vector and the truncation table below would be measuring a file nobody produced.
```

It fired **on the digest, before the decode**, which is the ordering the check exists for. The file was restored and verified at `e7b14f38…07d0d884`.

### 4. an unlisted module under `offchain/lib/Gams/`

Mutation: an empty `offchain/lib/Gams/Publish.hs`.

```
FAIL the_artifact_path_scan_covers_every_module_on_it: the modules on disk under offchain/lib/Gams and offchain/lib/Store are not the set this scan decided about.
      on disk but neither scanned nor exempt: offchain/lib/Gams/Publish.hs
      A new module under offchain/lib/{Store,Gams}/ is added to aeson_storage_path -- or to aeson_scan_exemptions WITH A WRITTEN REASON -- in the commit that creates it. A missing file is a FAILURE naming the plan that creates it, never a pass. 23-03 MEASURED the other half: Store/Schema.hs spent two commits unlisted and nothing reddened, because a named list makes an omission visible without making it impossible.
```

24-01's `gams_version_is_not_constructible_empty` fired on the same input, which is correct — two scans, two scopes, one new module. The Phase-23 finding is now pre-empted on **both** lists.

### 5. UNPLANNED — a 53-bit value in a module the two-file float scan did NOT read

Mutation: `budget :: Double` seeded into `Gams/Env.hs`, **after** the scope fix in `8fc2bd6`.

```
FAIL no_Double_and_no_aeson_on_the_artifact_path: a 53-bit floating value is on the ARTIFACT PATH. MEASURED from the committed golden artifact: dQx[0] loses exactly 32 wei through that type and ALL SIXTEEN elements of dQx ++ dQM are inexact, |delta| in [4, 328]. These are swap amounts in wei.
      offchain/lib/Gams/Env.hs:62:budget :: Double
```

The file **and the line** are named. Before `8fc2bd6` this input would have been **silent** — that is what the widened scope bought, demonstrated rather than argued.

## The floors, re-measured cold

Run at execution time, with the three new modules on disk, in the same commit that added them:

```
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l
54
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
62
```

| Floor | Was | Now | Slack before |
|---|---|---|---|
| `purge_file_floor` | 51 | **54** | **zero** — 51 against exactly 51 scanned files |
| `credential_scan_floor` | 59 | **62** | zero — 59 against exactly 59 |

Census under `offchain/`: `hs 44, sh 8, json 8, md 3, txt 2, sql 2`. Only `.hs` moved, by three. **Zero slack for the second plan running** — these three modules would have reddened both scans in the commits that created them had the floors not moved with them. Neither was incremented by arithmetic.

## Suite counts and wall, MEASURED cold

| | Checks | Wall |
|---|---|---|
| Baseline before this plan | 117/117 | **68 s** |
| After | **126/126** | **76 s** |

The 68 s is with the test binary already built; 24-01 recorded 87.8 s including compilation, so the two numbers are not comparable and the **68 → 76 s delta is the honest one**: nine added checks cost ~8 s, of which two are subprocess scans that each spawn `grep` inside the sentinel harness's ~3250-pair multiplier. Budget is 900 s.

## Files Created/Modified

- `offchain/lib/Gams/Argv.hs` — `Shock` (seven strict `Integer`s), `render_decimal`, `render_argv`, `parse_shock_field`, `ArgvError`. Records M7 with both digests and M8's asymmetry, so a later reader does not conclude the renderer is unnecessary for the five re-rendered fields. Contains no floating type, no `Maybe`, and no `read`.
- `offchain/lib/Gams/Env.hs` — the whitelist as data, `validate_env`, `forbidden_key_prefixes`. Records what M9 measured **and what it did not**: no ambient variable and no config file on this machine changes the artifact bytes, and no comma-decimal locale is installed, so GAMS-06's "inheriting differs" half is discharged in 24-04 against the child's environment vector.
- `offchain/lib/Gams/Artifact.hs` — `ProverArtifact`, `decode_artifact`, `ArtifactError`. Imports `Store.Json` and nothing else that parses JSON.
- `cfmm-replicationPlank-rpc-api.cabal` — three `exposed-modules` entries, **+0 packages**, confirmed by `grep -c Downloading` = 0 rather than estimated.
- `offchain/test/Main.hs` — nine checks and their registration, the extended `aeson_storage_path`, `aeson_scan_exemptions`, the growth guard, and both floors.

## Decisions Made

1. **The edge normalizes; it does not refuse.** A leading zero is a legal spelling of a legal value arriving from outside. Refusing it hands the problem back to the caller, where the next caller will spell it differently; normalizing settles the rendering here, which is where the `execve` is, and settles KEY-04 with it.
2. **The exponent is bounded at `10^96`.** `parse_shock_field` accepts `<digits>e<digits>`; an unbounded exponent turns a four-character token into an arbitrarily large allocation chosen by whoever supplies the shock. `96` is above every field's admitted range and the refusal names the bound.
3. **The sign convention for the truncation is stated, not assumed.** `delta = image - exact`, matching the research table row by row.
4. **`artifact_float_path` is `aeson_storage_path`.** See deviation 3.
5. **BYTE-04 is marked complete; GAMS-02 and GAMS-06 are not.** See "Requirements".

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The plan's own action and acceptance criterion contradicted each other on `Argv.hs`'s prose**

- **Found during:** Task 1, before the first build
- **Issue:** The plan's action says to add a haddock note that `show` on a `Double` would be locale-dependent — and its acceptance criterion is `grep -cE 'Double|Float|…' offchain/lib/Gams/Argv.hs` = `0`. The haddock the action asks for **reddens the criterion the same task states**. This is the twelfth instance of prose inside a grep's blast radius on this branch, and the first found in a plan rather than in a commit.
- **Fix:** The reasoning was kept and the words changed — "a FLOATING type would put the C library's numeric locale on the key path". The pattern was **not** relaxed.
- **Verification:** `grep -cE 'Double|Float|realToFrac|fromRational|printf' offchain/lib/Gams/Argv.hs` = **0**, and `Artifact.hs` = **0** under the same treatment.
- **Committed in:** `2a62cce`, `46ba4fc`

**2. [Rule 1 — Bug] BYTE-04's 32 wei was asserted with the wrong sign, and the check caught it**

- **Found during:** Task 3, on the first suite run
- **Issue:** The plan says "the difference from `head golden_dqx` is exactly `32`", which is sign-ambiguous. Written as `exact - image` it is `-32`; the research table's convention is `image - exact = +32`.
- **Fix:** The assertion was flipped to `image - first_element == 32` and the convention is now **stated in the failure message**, with a note that the check was first written the other way round. `every_golden_element_is_inexact_under_double`'s deltas were flipped to match, so its reported values line up with M12 row by row without a mental sign flip.
- **Verification:** `FAIL dqx_double_decode_loses_exactly_32_wei_on_the_first_element: dQx[0] loses -32 wei…` was the observed red; green afterwards.
- **Committed in:** `2a558e3`
- **Note:** an `abs` would have hidden this. The magnitude was right and the sign was not.

**3. [Rule 2 — Missing critical] The float scan's own scope could not grow**

- **Found during:** Task 3, while deciding whether BYTE-04 may be marked complete
- **Issue:** `artifact_float_path` was a hardcoded two-file list with no directory cross-check — **the exact defect the growth guard shipping in the same commit exists to close**, reproduced inside it. A future `Gams/Invoke.hs` holding a 53-bit value would have been silent.
- **Fix:** `artifact_float_path = aeson_storage_path`. One set, one growth guard, both scans covered. `byte04_named_modules` keeps `Argv.hs` and `Artifact.hs` asserted PRESENT by name, which a set comparison alone cannot do because a list and a directory can shrink together. MEASURED first: every `.hs` under `offchain/lib/{Store,Gams}/` is already free of the pattern, so the widening cost nothing and bought thirteen files.
- **Verification:** firing observation 5 — `budget :: Double` in `Gams/Env.hs` reddens naming the file and the line, and would have been silent before.
- **Committed in:** `8fc2bd6`

**4. [Rule 1 — Bug] `-Wall` warnings in the new code**

- **Found during:** Tasks 1, 2 and 3
- **Issue:** three separate hard-gate failures: a redundant `Data.List (foldl')` import (`foldl'` is in the Prelude at base 4.20); `-Wx-partial` on `head digits` in `Artifact.hs`'s leading-zero guard; and four `-Wtype-defaults` on an unannotated local `refuses` under `OverloadedStrings` — the identical warning 24-01 hit on its CONOPT check.
- **Fix:** import removed with a note; the leading-zero guard rewritten as a total case split; a local `refuses :: String -> String -> BS.ByteString -> Either String ()` signature with a comment saying why it is not decoration.
- **Verification:** `grep -ciE 'warning'` = 0 on every build log.
- **Committed in:** `2a62cce`, `46ba4fc`, `2a558e3`

**5. [Deviation of record — measurement over plan] `007` is refused ONE LAYER EARLIER than the plan expected**

- The plan expects `"dQx": [007]` → `Left (NotAnInteger "007")`. MEASURED: RFC 8259 admits no leading zero, so `Store.Json.recognise_json_value` refuses the whole document and the answer is `Left (NotJson …)`. The refusal is stronger, not weaker.
- The check asserts the **measured** constructor per input and says why in its haddock; the leading-zero arm in `unsigned_token` is kept as defence, with the reason written down — a guard whose only defence is a component someone else maintains can be removed by a change nobody thought was about it.
- **Committed in:** `46ba4fc`, `2a558e3`

**6. [Rule 3 — Blocking, same shape as 24-01's] the `.cabal` lines land with their modules**

- The plan's task 1 adds all three `exposed-modules` lines, but `Env.hs` and `Artifact.hs` are created in task 2 and `cabal build` fails on an exposed module that does not exist. `Gams.Argv` landed in task 1; the other two in task 2. `grep -cE '^ +, Gams\.(Argv|Env|Artifact)$'` = **3** at end state, and every intermediate commit builds.

**7. [Rule 2 — Missing critical] each new module joins `gams_no_fallback_path` in the commit that creates it**

- 24-01's directory-vs-list assertion over `offchain/lib/Gams/` is LIVE, so a module created without being listed reddens the suite. Rather than let intermediate commits sit red, `Argv.hs` was listed in task 1's commit and `Env.hs`/`Artifact.hs` in task 2's. This is the rule working as intended one plan after it was written.

**8. [Refactor] `gams_layer_modules` folded onto the new `modules_under`**

- Two enumerators over the same directory would be two things to keep in agreement. One implementation, two callers.

---

**Total deviations:** 8 (3 bugs, 2 missing-critical, 1 blocking, 1 measurement-over-plan, 1 refactor)
**Impact on plan:** No scope creep. Deviation 3 is the only added surface (~15 lines) and it is the reassigned hole applied to this plan's own new guard.

## Requirements

| Req | State after this plan | Why |
|---|---|---|
| **BYTE-04** | **COMPLETE** | Every conjunct has a check that reads it: the arrays decode to pinned exact `[Integer]`s from a file identified by digest **before** the decode; the 53-bit image is pinned as an equality; 16 of 16 elements are shown inexact; six non-integer spellings are refused; and no 53-bit type or JSON library is on the scanned set — a scan with a proven positive control whose scope is asserted against the directory in both directions. All six of the research table's BYTE-04 rows are Tier A and all six shipped here. |
| **GAMS-02** | PARTIAL | The artifact post-conditions are observed rejecting a short array, a length disagreement, an empty array and a non-JSON body. The requirement's own sentence — *a run that exits 0 without producing the artifact* — needs the Tier-B stub checks (`exit_zero_without_artifact_is_refused`, `a_pre_existing_artifact_is_unreachable`, `each_invocation_gets_a_fresh_directory`), which are 24-03/24-04. |
| **GAMS-06** | PARTIAL | The rendering half is discharged and observed; the whitelist is asserted as data in both directions. *The invocation environment is controlled* needs the child's own environment vector, spawned twice — 24-04, per the research's Correction 2. |

## Issues Encountered

- The plan's task-1 action and its own acceptance criterion contradicted each other (deviation 1). Following the measurement rather than the prose is what the standing rule says, and the grep is the measurement.
- Four pre-existing untracked files at the repository root (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock`) were present before this plan began and were left untouched — outside this phase's territory.

## Carry-forwards

1. **`Gams/Invoke.hs` and any other new GAMS module now have TWO lists to join** — `aeson_storage_path` (which also drives the float scan) and `gams_no_fallback_path`. Both are asserted against the directory, so the suite will name the omission on the day it lands rather than two commits later.
2. **`aeson_scan_exemptions` is empty and should stay that way.** The first entry must carry the reason it is one, and `Gams/Config.hs`'s exemption on the *other* list is the precedent for how narrow that reason has to be.
3. **The wall grew 68 → 76 s for nine checks, two of which spawn `grep`.** Tier-B stub checks in 24-03/04 each spawn a subprocess **inside** the sentinel harness's multiplier and one of them deliberately waits out a timeout; the research's ≤ 2 s hung-child budget is the number to hold to.
4. **`render_argv`'s `phiXpips`/`phiMpips` upper bound is `2^64`, deliberately loose.** `VOLUME_PATH.md` §4 bounds `txlVolumeRate` above and says nothing about the fee pips, so no tighter bound was invented. If §4 later bounds them, this is where it goes.
5. **`pa_delta_realized_text` and `pa_r_phi_realized_text` have no numeric consumer.** If Phase 25 ever needs their value, that is the moment to decide where the conversion lives — and it must not be this module.

## User Setup Required

None.

## Next Phase Readiness

- The renderer is settled, so Phase 25 inherits a rendering rather than choosing one after rows exist — which is gate 4 of the research's "what must be proven before 25 may start".
- The artifact decoder is in place and falsified, and BYTE-04 is closed.
- 24-03 and 24-04 can build `Gams.Invoke` on `render_argv`, `whitelist_for` and `decode_artifact` without re-opening any of them.

## Self-Check: PASSED

All three created modules and this summary exist on disk; all four commits resolve
(`2a62cce`, `46ba4fc`, `2a558e3`, `8fc2bd6`). `git status --porcelain src test foundry-scripts
Makefile foundry.toml .github` is EMPTY. Suite re-run after every restoration: **126/126, FAIL 0**,
zero `-Wall` warnings, `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL'` = 0 and
`grep -cE 'Gams\.Invoke|/usr/gams|"gams"'` = 0 over `offchain/test/Main.hs`. All four pinned
digests verified byte-identical after the five mutations.

---
*Phase: 24-gams-invocation-toolchain-identity*
*Completed: 2026-08-16*
