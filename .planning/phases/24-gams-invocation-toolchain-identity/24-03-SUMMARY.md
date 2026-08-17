---
phase: 24-gams-invocation-toolchain-identity
plan: 03
subsystem: testing
tags: [haskell, gams, subprocess, io-edge, stubs, tier-b, fresh-directory, exit-codes, source-scan]

# Dependency graph
requires:
  - phase: 24-gams-invocation-toolchain-identity
    plan: 01
    provides: "classify_exit (total, stream-free), parse_gams_version / parse_conopt_version, and the gams_no_fallback_path directory-vs-list guard this module had to join"
  - phase: 24-gams-invocation-toolchain-identity
    plan: 02
    provides: "render_argv (the tokens the echo conjunct compares against), decode_artifact (conjunct 4), whitelist_for (the child's environment), and the aeson_storage_path growth guard this module had to join"
  - phase: 23-postgres-foundation
    provides: "Store.Types.sha256_hex and volume_path_golden_bytes_len, the Check/guarded/expect runner, and the build-a-bait-then-scan positive-control idiom"
provides:
  - "Gams.Run: run_prover, the ONE process spawn in the phase -- exclusive run directory, group-owning timeout(1) -k, drained pipes, whitelisted env, read-back from bytes, and a six-conjunct verdict of which none is log text"
  - "ProverOutcome whose Aborted case is structurally incapable of carrying an artifact, OBSERVED in three GHC arms"
  - "Five Tier-B checks registered in core_checks (126/126 -> 131/131), each spawning real /bin/sh children the check writes itself"
  - "write_stub plus the stub bodies, BUILT never committed, so no GAMS version banner is ever spelled inside offchain/"
  - "Both tree-derived floors re-measured cold, and the discovery that purge_file_floor never moved at 24-02"
affects: [24-04, 24-05, 24-06, 25-content-key-and-keyed-store]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A conjunction, not a gate: exit 0 is the FIRST conjunct and the module's haddock enumerates all six in the order they run"
    - "The freshness reference point is handed DOWN as a predicate, so the one clock lives where it is taken"
    - "A stream-independence arm asserts the two streams actually DIFFER before concluding that identical verdicts mean anything"
    - "A run directory reported as the empty string is asserted against FIRST, because doesDirectoryExist \"\" is False and would pass the removal arm vacuously"
    - "Stubs are BUILT into a temp directory, never committed, for the reason baits are built"

key-files:
  created:
    - offchain/lib/Gams/Run.hs
  modified:
    - cfmm-replicationPlank-rpc-api.cabal
    - offchain/lib/Gams/Exit.hs
    - offchain/test/Main.hs

key-decisions:
  - "Produced carries CapturedStreams too -- the plan's own two tasks contradicted each other, and the addition is what makes the run directory observable on BOTH outcomes without weakening the artifact claim"
  - "backstop_no_exit_code = -1: when the in-process backstop fires there IS no exit status, and -1 is not a byte any process can return, so it cannot be mistaken for an observed code"
  - "AbortReason gains NotAbsolute: the module refuses a relative binary or model path, and a refusal needs a representation"
  - "filepath added to the LIBRARY stanza -- a boot package already in the plan but hidden from that stanza; Downloading = 0"
  - "GAMS-01 and GAMS-02 stay PARTIAL: every Tier-A and Tier-B row shipped, and each still has one Tier-C row that does not exist until 24-06's capture"

patterns-established:
  - "A new module under offchain/lib/Gams/ joins BOTH scanned lists in the commit that creates it -- and 24-03 did it without being reminded, which is the 24-02 rule working"
  - "Both tree-derived floors are re-measured TOGETHER and both numbers compared to what is written down, because 24-02 moved one and not the other and nothing reddened"

requirements-completed: []

# Metrics
duration: 41min
completed: 2026-08-16
---

# Phase 24 Plan 03: The One IO Edge — Summary

**A child that exits 0 and writes nothing is REFUSED, the real 606 golden bytes planted at the caller's working directory are UNREACHABLE, two stubs with the same exit code and opposite log text give the identical verdict, and `Aborted` has no artifact to give — five Tier-B checks spawning real children, five firing observations, and a GHC error in three arms.**

## Performance

- **Duration:** 41 min
- **Started:** 2026-08-17T00:06Z
- **Completed:** 2026-08-17T00:41Z (final metadata commit after)
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- `run_prover` is the ONE process spawn in the phase. It runs through `/usr/bin/timeout -k` (the wrapper owns the process GROUP, and CONOPT is a grandchild at `Solvelink=2`, so a kill written against the direct child could not fail), in an **exclusive** directory created with `createDirectory` and bracketed with `removeDirectoryRecursive`.
- The verdict is a **conjunction of six**, and not one of them is log text: exit code classifies as `Solved`; the artifact exists in a directory that could not have pre-existed; its mtime is at or after a marker written just before the spawn; it decodes; both echoed fields equal the argv token **sent**; and the run's own log carries a job banner naming the invoked model. **Detection that finds nothing ABORTS the run.**
- `exit_zero_without_artifact_is_refused` drives a stub whose entire body is `exit 0`. MEASURED with the REAL binary, `action=c` is exactly this shape — exit 0, log and listing written, `volume_path.json` **absent**.
- `a_pre_existing_artifact_is_unreachable` plants the **real 606 committed golden bytes** and a valid job banner at the process's own working directory, using a shock equal to the golden's own inputs so the plant would satisfy every remaining conjunct if it were reachable. It refuses to clobber, removes both in a `finally`, and asks `git status --porcelain` afterwards whether either name appears.
- The **stream-independence arm** has its own positive control: the two chatty stubs' stdouts are asserted to DIFFER before their verdicts agreeing is allowed to mean anything.
- `each_invocation_gets_a_fresh_directory_and_it_is_removed` asserts the reported directory is **non-empty first**, because `doesDirectoryExist ""` is `False` and the removal arm would otherwise pass because its subject was absent — the milestone's own defect class, inside the check written to catch a neighbouring one.
- Suite **126/126 → 131/131**, FAIL 0, zero `-Wall` warnings, still DB-free AND GAMS-free, **+0 packages**.

## Task Commits

1. **Task 1: `Gams.Run`, the one IO edge** — `847bc9c` (feat)
2. **Task 2: five Tier-B checks and both floors** — `f557e16` (test)

## The compile-level observation, in three arms

The plan asks for the GHC error, not the argument. All three were run against the built library with `cabal exec -- ghc -fno-code -Wall -package cfmm-replicationPlank-rpc-api`, and the scratch modules were deleted afterwards.

**Arm A — the accessor cannot be total.** `outcome_artifact (Produced artifact _ _) = artifact`, alone:

```
AbortedProbe.hs:9:1: warning: [GHC-62161] [-Wincomplete-patterns]
    Pattern match(es) are non-exhaustive
    In an equation for ‘outcome_artifact’:
        Patterns of type ‘ProverOutcome’ not matched: Aborted _ _ _
```

Recorded as a warning and it is a **hard gate failure by this repository's own rule** — `-Wall` clean is the build gate, and every task in this phase verifies `grep -ciE 'warning'` is 0.

**Arm B — there is nothing of that type inside `Aborted`.** Writing the second equation:

```
AbortedProbe.hs:9:44: error: [GHC-83865]
    • Couldn't match expected type ‘ProverArtifact’
                  with actual type ‘Gams.Run.AbortReason’
    • In the expression: reason
      In an equation for ‘outcome_artifact’:
          outcome_artifact (Aborted reason _ _) = reason
```

**Arm C — no such accessor is exported either:**

```
ExportProbe.hs:2:18: error: [GHC-61689]
    Module ‘Gams.Run’ does not export ‘outcome_artifact’.
```

Correction 1 is therefore not a convention: an aborted run producing an output row is **unrepresentable**, and the compiler said so three different ways.

## The five firing observations

Every mutation was applied, the suite run, the verbatim FAIL captured, and the source restored **from a saved copy** (never `git checkout`), verified sha256-identical against `Run.hs` `4e0b2f60…31aa66`, `Exit.hs` `212a34a5…2220ad`, `Main.hs` `29849ecf…0a7ade` and `volume-path-golden.json` `e7b14f38…07d0d884`.

### 1. the artifact-presence conjunct removed — and the TYPE refused the mutation the plan named

The plan asks for "make `run_prover` return `Produced` on exit 0 without checking artifact presence". **That mutation cannot be written.** `Produced` demands a `ProverArtifact` and there is none to hand it — the same shape Arm B above quotes. The closest expressible mutation was applied instead: the presence and freshness conjuncts deleted, and the bytes read through `read_if_present` (empty when absent).

```
FAIL exit_zero_without_artifact_is_refused: a child that exits 0 and writes NOTHING was not refused: Aborted ArtifactRejected (NotJson "the input ended where a json value was expected") at exit 0 (run dir "/tmp/cfmm-gams-run-13")
FAIL a_pre_existing_artifact_is_unreachable: a valid-looking volume_path.json planted at the caller's working directory WAS REACHABLE: Aborted ArtifactRejected (NotJson "the input ended where a json value was expected") at exit 0 (run dir "/tmp/cfmm-gams-run-15")
```

Two checks reddened, and the result is stronger than the plan predicted: without the presence conjunct the layer still refuses, but it refuses **for the wrong reason** — it reports a malformed document where the truth is that no document exists. Recorded rather than smoothed over, because "the type stopped the literal mutation" is the finding.

### 2. the artifact read from the process CWD instead of the run directory

Mutation: `run_dir </> artifact_name` became `artifact_name`, and the log read likewise.

```
FAIL stub_exit_codes_drive_the_verdict: the stub that exits 0 having written a valid artifact and a log with a matching job banner did not produce one: Aborted NoArtifact at exit 0 (run dir "/tmp/cfmm-gams-run-1")
FAIL a_pre_existing_artifact_is_unreachable: a valid-looking volume_path.json planted at the caller's working directory WAS REACHABLE: Aborted StaleArtifact at exit 0 (run dir "/tmp/cfmm-gams-run-15")
```

**The second line is the one worth reading twice.** With the run directory removed from the path, the belt-and-braces **freshness** conjunct is what caught the plant — the artifact was found, decoded, and its echoed fields matched, and it lost on its modification time. That is Pitfall 8's "belt and braces" being the belt, observed rather than assumed. The first line is the same mutation from the other side: a stub that DID write into the run directory now looks like a stub that wrote nothing.

### 3. the bracket's teardown removed

Mutation: `bracket (allocate tmp) removeDirectoryRecursive body` became `bracket (allocate tmp) (\_ -> pure ()) body`.

```
FAIL each_invocation_gets_a_fresh_directory_and_it_is_removed: a run directory SURVIVED the invocation: /tmp/cfmm-gams-run-17, /tmp/cfmm-gams-run-19, /tmp/cfmm-gams-run-21. The bracket removes it on every path -- success, abort and exception alike. The third of these is the ABORT path (a stub exiting 2), which is the one a success-only teardown would leave behind, and a leftover run directory is precisely what the freshness conjunct exists to make unreadable.
```

All three directories named, including the one from the **abort** path.

### 4. a verdict seeded into `Gams/Run.hs`

Mutation: `log_says_it_failed buffer = Data.List.isInfixOf "infeasible" buffer`, plus its import.

```
FAIL gams_verdict_ignores_the_streams: a verdict in the GAMS layer reads SOLVER OUTPUT:
      offchain/lib/Gams/Run.hs:412:log_says_it_failed buffer = Data.List.isInfixOf "infeasible" buffer
      VOLUME_PATH.md section 4: the exit code is non-zero on every abort -- gate on it, never on log text. MEASURED: stderr is 0 BYTES in every GAMS mode, so a stream reader compares the empty string against the empty string every single run, on the good path and the bad one alike.
```

The file **and the line** are named, with the positive control having fired first.

### 5. `classify_exit`'s 7 arm returns `ModelLevel ExecutionError`

```
FAIL gams_exit_taxonomy_is_total_and_disjoint: exit code 7 classifies as ModelLevel ExecutionError, expected Environmental LicensingError. reading non-zero as "the model says infeasible" records an expired licence as an infeasibility verdict -- an administrative failure rewritten as a scientific claim
FAIL stub_exit_codes_drive_the_verdict: the stub that exit 7 should have given Aborted (ExitVerdict (Environmental LicensingError)) at exit 7, and gave Aborted ExitVerdict (ModelLevel ExecutionError) at exit 7 (run dir "/tmp/cfmm-gams-run-7"). Exit 7 is LICENSING: a layer that reads any non-zero code as a statement about the model records an expired licence as a scientific claim.
```

24-01's **pure** check and 24-03's **spawned** check both name code 7. That is the two tiers agreeing about the same fact through different instruments — the pure one reading a function, the spawned one reading a real child's exit status through `timeout(1)`.

## The floors, re-measured cold — and one of them had never moved

```
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l
55
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
63
```

| Floor | Written down | On disk before | Slack | Now |
|---|---|---|---|---|
| `purge_file_floor` | 51 | 55 scanned files | **FOUR** | **55** |
| `credential_scan_floor` | 62 | 62 scanned files | zero | **63** |

**24-02's summary states `purge_file_floor` moved 51 → 54 in commit `2a558e3`. It did not.** `git show` on `2a558e3`, `8fc2bd6`, `4c18a9c` and every commit since all report `purge_file_floor = 51`; only `credential_scan_floor` moved (59 → 62). One half of a pair that is always re-measured together landed and the other did not, the summary of record asserted both had, and **nothing reddened** — because a floor with slack passes for a reason unrelated to its subject. Four `.hs` files could have been deleted from `offchain/` with that guard still green.

Recorded in the floor's own haddock rather than quietly corrected, and the rule beside it is now explicit: run **both** commands, compare **both** numbers to what is written down, never add.

Census under `offchain/`: `hs 45, sh 8, json 8, md 3, txt 2, sql 2`. Only `.hs` moved, by one. The `.json` count is unchanged: every stub this plan spawns is **built** into a temp directory, never committed.

## Suite counts and wall, MEASURED cold

| | Checks | Wall |
|---|---|---|
| Baseline before this plan | 126/126 | **73.1 s** |
| After | **131/131** | **78.3 s** |

Both with the test binary already built. Budget **900 s**.

**+5.2 s for five checks that each spawn several real children** — and the reason it is that cheap is the sentinel harness's `readable` filter. `sweep_one` runs only checks that objected when the swept artifact was garbled; these five read no artifact, so they are excluded from the per-pair runs and are paid once per full `core_checks` pass — the main pass plus one `reader_set` derivation per swept artifact, about six passes rather than the ~3250-pair multiplier that made 24-01's six pure checks cost 16 s. The research's ≤ 2 s hung-child budget is untouched: nothing here waits out a timeout, and the longest child is a `cat` heredoc.

## Files Created/Modified

- `offchain/lib/Gams/Run.hs` — `RunRequest`, `ProverOutcome`, `AbortReason`, `ToolchainIdentity`, `CapturedStreams`, `run_prover`, `with_fresh_run_dir`. Contains no floating type, no JSON library, no fallback, and none of the six stream tokens. Its haddock enumerates all six conjuncts in the order they run and states that `cs_stdout`/`cs_stderr` are diagnostic beside the fields themselves.
- `offchain/lib/Gams/Exit.hs` — one sentence reworded. See deviation 2.
- `offchain/test/Main.hs` — `write_stub`, the stub bodies, `tier_b_shock`, `with_tier_b_scratch`, `tier_b_request`, five checks and their registration, `gams_stream_pattern`/`gams_verdict_path`/`gams_stream_positive_control`, `Gams/Run.hs` added to both scanned lists, and both floors.
- `cfmm-replicationPlank-rpc-api.cabal` — `Gams.Run` exposed; `filepath` added to the library stanza. **+0 packages**, confirmed by `grep -c Downloading` = 0 rather than estimated.

## Decisions Made

1. **`Produced` carries `CapturedStreams` too.** See deviation 1 — the plan's two tasks contradicted each other and this is the resolution that strengthens rather than weakens.
2. **`backstop_no_exit_code = -1`.** When the in-process backstop fires there is no exit status at all. `0` would say "GAMS ran"; `124` or `137` would manufacture a measurement out of a mechanism that did not report one. `-1` is not a byte any process can exit with, so it cannot be mistaken for an observed code, and the load-bearing part is the `AbortReason`.
3. **`AbortReason` gains `NotAbsolute`.** A relative binary path is a `PATH`-shadow surface and the module refuses it — and a refusal that has no constructor has to be spelled as some other refusal, which would be a lie in the failure message.
4. **The exclusivity retry is not a fallback.** `with_fresh_run_dir` recovers from exactly one condition (the name is taken) by asking for a **different** name, never by reusing the taken one and never by continuing without a directory; every other `IOError` is re-thrown unchanged. `Gams/Run.hs` is on the scanned no-fallback set rather than exempt from it.
5. **GAMS-01 and GAMS-02 stay PARTIAL.** See "Requirements".

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] The plan's two tasks contradicted each other about `cs_run_dir`**

- **Found during:** Task 1, while writing the type
- **Issue:** Task 1 specifies `Produced !ProverArtifact !ToolchainIdentity`. Task 2 requires `CapturedStreams` to carry `cs_run_dir` and then asserts that "two successive `run_prover` calls report two DIFFERENT `cs_run_dir` values" **and separately** that "the same holds on the ABORT path" — so the first pair must be `Produced` runs, whose run directory the task-1 type makes unobservable.
- **Fix:** `Produced !ProverArtifact !ToolchainIdentity !CapturedStreams`. This is an ADDITION and weakens nothing: `Aborted` still has no artifact field, and all three GHC arms above were run against this shape.
- **Verification:** `each_invocation_gets_a_fresh_directory_and_it_is_removed` asserts about two `Produced` runs and one `Aborted` run, and firing observation 3 shows all three named.
- **Committed in:** `847bc9c`

**2. [Rule 1 — Bug] Prose inside a grep's blast radius — three files, three instances, one plan**

This is the **thirteenth, fourteenth and fifteenth** occurrences on this branch. In each case the reasoning was kept and the words changed; **no pattern was relaxed.**

- **13th — `Gams/Exit.hs:50`.** Its haddock explained that a layer reading non-zero as *"the model says {the forbidden word}"* records an expired licence as a verdict. `gams_verdict_ignores_the_streams` scans that file for exactly that word. Reworded to "the model says the constraints admit no point"; the phrase "an infeasibility verdict" survives, because the pattern is the model-status adjective and not its noun. Found **before** the check first ran, by reading the pattern against the file.
- **14th — `Gams/Run.hs`, three separate tokens.** Task 1's own acceptance criteria grep this file for `Prelude.readFile` = 0, `outcome_artifact` = 0 and `createDirectoryIfMissing` = 0 — and the haddock explaining why each of those three is **not** used spelled all three. Every one was reworded to describe the thing rather than name it, with the reason recorded in the file.
- **15th — `offchain/test/Main.hs`, and this one is the sharpest.** The comment beside the new `Gams.Run` import asserted that the three GAMS-free tokens stay out of this file, and **listed all three**. The verification grep returned **2** (the sentence appeared twice). The comment describing itself as evidence of absence was the only thing making the claim false. Both occurrences reworded to describe the tokens; the grep is now **0**.
- **Verification:** `grep -cE 'Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams' offchain/test/Main.hs` = **0**, and every task-1 criterion re-run at **0**.
- **Committed in:** `847bc9c`, `f557e16`

**3. [Rule 2 — Missing critical] `purge_file_floor` never moved at 24-02**

- **Found during:** Task 2, re-measuring the floors cold
- **Issue:** The written floor was 51 against **55** scanned files. 24-02's summary states it moved 51 → 54; `git show` on that commit and every commit after reports 51. Its twin moved. This one did not. **Four files of slack, and a guard with slack passes for a reason unrelated to its subject** — the milestone's standing defect, in the guard whose whole job is to detect it.
- **Fix:** `purge_file_floor = 55` and `credential_scan_floor = 63`, both from `find … | wc -l` run at execution time, neither by arithmetic. The floor's haddock now records the discrepancy and states the rule as a pair: run both commands, compare both numbers.
- **Verification:** green at 55/63 against exactly 55/63 files — zero slack on both, for the first time since 24-01.
- **Committed in:** `f557e16`

**4. [Rule 3 — Blocking] `filepath` was hidden from the library stanza**

- **Found during:** Task 1, first build
- **Issue:** The plan states `filepath` is "already resolved". It is resolved in the **build plan** (the test-suite stanza depends on it, and `directory` pulls it in), but the library stanza does not name it, so GHC refused: *"It is a member of the hidden package 'filepath-1.5.4.0'"*.
- **Fix:** `filepath` added to the library `build-depends` with the measurement beside it. Hand-rolling `</>`, `takeFileName` and `isAbsolute` was the alternative and is the "don't hand-roll" row this phase's research writes down.
- **Verification:** `grep -c Downloading` = **0** at that commit.
- **Committed in:** `847bc9c`

**5. [Deviation of record — measurement over plan] The mutation the plan named for observation 1 is not expressible**

- The plan's firing input is "make `run_prover` return `Produced` on exit 0 without checking artifact presence". `Produced` demands a `ProverArtifact` value and a run that wrote nothing has none, so **the type refuses the mutation** — which is Correction 1 doing its job before a check gets involved. The closest expressible mutation was applied and both its FAIL lines are quoted above. Recorded, not discarded, following 24-01's mutation-2 and 24-02's mutation-1 precedent.

**6. [Refactor] The freshness reference point is a predicate, not a timestamp**

- `getModificationTime` returns a `UTCTime`, and naming that type in a top-level signature would have required adding `time` to the library stanza for one word. `spawn_into` closes over `t0` and hands `conjuncts` an `is_fresh :: FilePath -> IO Bool` instead. One clock, in the one place it is taken, and no package added.

---

**Total deviations:** 6 (1 bug spanning three files, 1 missing-critical, 2 blocking, 1 measurement-over-plan, 1 refactor)
**Impact on plan:** No scope creep. The only added surface is deviation 1's third field and deviation 3's two integers.

## Requirements

| Req | State after this plan | Why |
|---|---|---|
| **GAMS-01** | PARTIAL | Three of its four rows shipped and every one is OBSERVED: `gams_exit_taxonomy_is_total_and_disjoint` (24-01), `gams_verdict_ignores_the_streams` (firing observation 4, positive control fired), and `stub_exit_codes_drive_the_verdict` (firing observation 5, plus the stream-independence arm with its own control). The fourth, `gams_conformance_records_the_measured_exit_codes`, is **Tier C** and reads a capture artifact that does not exist until 24-06. |
| **GAMS-02** | PARTIAL | Four of five rows shipped: `exit_zero_without_artifact_is_refused`, `a_pre_existing_artifact_is_unreachable`, `each_invocation_gets_a_fresh_directory_and_it_is_removed` (all three OBSERVED here) and `artifact_postconditions_reject_a_short_array` (24-02). The fifth, `gams_conformance_records_action_c_exit_zero_with_no_artifact`, is **Tier C** — 24-06. |

Nothing was marked complete, following 24-01's practice and 24-02's: a requirement is held at PARTIAL until **every** conjunct has a check that reads it, and "the real binary was observed doing this" is a conjunct that no stub can discharge.

## Issues Encountered

- Four pre-existing untracked files at the repository root (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock`) were present before this plan began and were left untouched — outside this phase's territory.
- `/tmp/cfmm-gams-run-*` directories left by firing observation 3 (the mutation that removes the teardown) were removed by hand afterwards. That is the mutation working as designed, and it is worth noting that the only thing that ever leaves those directories behind is the defect.

## Carry-forwards

1. **`Gams/Invoke.hs`, when 24-05 creates it, has TWO lists to join** — `aeson_storage_path` (which also drives the float scan) and `gams_no_fallback_path` — and it will additionally be in `gams_verdict_path`'s natural scope. The first two are asserted against the directory; **the third is NOT**. `gams_verdict_path` is a hardcoded two-file list with no growth guard, which is precisely the shape 24-02 found inside its own fix. It is left that way deliberately for now because its members are "the modules where a verdict is decided" rather than "every module in a directory" — but the day a third such module lands, that list must either grow or gain a guard.
2. **`ti_conopt_version` is a `Maybe`, and only one check reads it.** `stub_exit_codes_drive_the_verdict` asserts it is `Just` on the clean path. The `Nothing` arm is unreachable from `Produced` and has no test; 24-06's capture is where a real run that aborted before the solve could exercise it.
3. **The timeout is BUILT but not yet FALSIFIED.** `/usr/bin/timeout -k` and the in-process backstop are both in `Gams.Run`, and neither has been observed firing. Guards 23 (2 MB stderr flood), 24 (hung grandchild) and 25 (timeout ⇒ no artifact) are GAMS-05's and belong to 24-04. **Until those run, the timeout is a guard never observed rejecting**, which this phase's own rule treats as absent.
4. **`rr_env = Nothing` exists and nothing uses it.** It is there so 24-04 can spawn the same function twice and observe the inherited child naming a variable the whitelist excludes — Correction 2's honest form of GAMS-06.
5. **The stub bodies assume `/usr/bin/cat` and `/bin/sh`.** `PATH=/usr/bin` is what the whitelist gives the child; a host without `cat` there would fail these checks for an environmental reason. Recorded rather than defended: the whitelist is the interface and the stubs exercise it.

## User Setup Required

None.

## Next Phase Readiness

- The IO edge exists and is falsified. 24-04 can add the GAMS-05 and GAMS-06 stub checks on top of `run_prover` without reopening any of it — `rr_budget_s`, `rr_kill_after_s` and `rr_env = Nothing` are already the three knobs those checks need.
- 24-05's `Gams.Invoke` can compose `run_prover` with `Gams.Config`'s resolution without re-deciding a single conjunct.
- Phase 25 inherits a `ToolchainIdentity` whose GAMS version is unconstructible-empty and whose model sources are a sorted list, so the content key has both halves before any row exists.

## Self-Check: PASSED

`offchain/lib/Gams/Run.hs` and this summary exist on disk; both task commits resolve (`847bc9c`, `f557e16`). `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is **EMPTY**, and no `volume_path.json` or `volume_path.log` is anywhere in the tree. Suite re-run after every restoration: **131/131, FAIL 0**, zero `-Wall` warnings, `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL'` = **0** and `grep -cE 'Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams'` = **0** over `offchain/test/Main.hs`. All four pinned digests verified byte-identical after the five mutations.

---
*Phase: 24-gams-invocation-toolchain-identity*
*Completed: 2026-08-16*
