---
phase: 24-gams-invocation-toolchain-identity
plan: 04
subsystem: testing
tags: [haskell, gams, subprocess, timeout, process-group, grandchild, environment-whitelist, structural-grep, override-sweep, tier-b]

# Dependency graph
requires:
  - phase: 24-gams-invocation-toolchain-identity
    plan: 03
    provides: "Gams.Run.run_prover (the ONE spawn), RunRequest with rr_budget_s / rr_kill_after_s / rr_env, ProverOutcome whose Aborted carries no artifact, write_stub, and the five Tier-B checks these six extend"
  - phase: 24-gams-invocation-toolchain-identity
    plan: 02
    provides: "whitelist_for / whitelist_keys (the expected side of the environment vector), the 606 committed golden artifact bytes the stubs plant"
  - phase: 24-gams-invocation-toolchain-identity
    plan: 01
    provides: "Gams.Config's three env-var name constants and three resolvers, and parse_gams_version's job-name anchor (the banner the missing-banner stubs omit)"
  - phase: 23-postgres-foundation
    provides: "OverrideProbe / probe_override / UnprobedOverride and the PGSTORE_DSN ruling this plan applies unchanged; the build-a-bait-then-scan positive-control idiom"
provides:
  - "Six Tier-B/structural checks registered in core_checks (131/131 -> 138/138): the hung GRANDCHILD, the 2 MB stderr flood, the timed-out run with a valid artifact, the two environment vectors, the missing-banner abort, and the GAMS-free structural grep"
  - "the_suite_never_names_the_real_solver: a three-token grep over offchain/test/Main.hs with a PROVEN positive control -- the DB-free scan's twin, now an in-suite check rather than a command an executor has to remember"
  - "GAMS_CONFORMANCE registered in advertised_overrides; GAMS_BIN and GAMS_MODEL named in unprobed_overrides with written reasons, following 23-05's ruling UNWEAKENED"
  - "config_env_vars: five variables across two config modules, each paired with the identifier that holds it, with a both-directions census growth guard over the config modules themselves"
  - "shell_injected_env_keys = [PWD, SHLVL, _], MEASURED on this host rather than copied from the plan"
affects: [24-05, 24-06, 25-content-key-and-keyed-store]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The process under test is a GRANDCHILD: a test written against a direct child cannot fail, because System.Timeout.timeout already reaps one"
    - "Liveness is read from /proc/<pid>, which answers 'terminated AND reaped' rather than 'stopped'"
    - "A check that testifies about process reaping kills every survivor on its way to FAILING about it"
    - "A whitelist is proven in force by comparing two REAL environment vectors, not by comparing bytes -- this host has no comma-decimal locale to differ with"
    - "The expected side of an assertion may never be the same expression as its subject (whitelist_for vs whitelist_keys)"
    - "A structural absence grep is an in-suite check with a seeded-bait positive control ordered FIRST, never a verification-time command"
    - "A transcribed list gets a both-directions census against the source of truth, so a sixth member cannot be added silently"

key-files:
  created: []
  modified:
    - offchain/test/Main.hs

key-decisions:
  - "The override list keeps the LITERAL variable name, against the plan's acceptance criterion 5 -- MEASURED: with the constant in the list a config rename leaves the whole suite green (138/138)"
  - "config_env_vars pairs each value with the NAME of its constant, so a census grepped out of the two config modules can be compared both ways -- the list itself now has a growth guard"
  - "GAMS_BIN and GAMS_MODEL are NAMED GAPS, not weakened probes: 23-05's PGSTORE_DSN ruling transfers because the obstruction is identical"
  - "GAMS-05 is marked COMPLETE; GAMS-03 and GAMS-06 stay PARTIAL, each owing exactly one capture-artifact row that does not exist until 24-05"
  - "store_overrides_are_probed_or_named_as_gaps keeps its 23-05 name although its scope is now five variables across two modules, because the acceptance criteria and the phase record name it"

patterns-established:
  - "A negative control is a ONE-TIME OBSERVATION recorded verbatim in the commit, not a permanent check -- the check would otherwise leak a process by design"
  - "Both tree-derived floors are re-measured cold whenever a plan is already editing this file, even when the plan adds no file"

requirements-completed: [GAMS-05]

# Metrics
duration: 2 sessions (interrupted; tasks 1-2 in the first, task 3 and closeout in the second)
completed: 2026-08-16
---

# Phase 24 Plan 04: The Hung Grandchild, Two Environment Vectors, and a Suite That Cannot Name the Solver — Summary

Three hazards that survive a naive test, and the structural guarantee that `cabal test` cannot reach
the real prover. Six checks, seven mutations observed firing, one plan acceptance criterion measured
BACKWARDS and rejected with the counter-measurement recorded in the source.

## This plan was INTERRUPTED and CONTINUED

Tasks 1 and 2 were executed and committed by a first executor, which then died mid-Task-3 on a
connection loss — not a code failure. A second executor verified the inherited state cold (build,
suite, both greps, `git status`, the two commits) before touching anything, executed Task 3, and
closed the plan out. Everything below about Tasks 1 and 2 is read out of their commits `8f5d2ef`
and `a8a3a21`; where a fact could not be re-taken it says so and says why.

## Performance

| | Before this plan | After tasks 1-2 | After task 3 |
|---|---|---|---|
| checks | 131/131 | 137/137 | **138/138** |
| FAIL | 0 | 0 | **0** |
| `-Wall` warnings | 0 | 0 | **0** |
| `cabal test` wall (binary pre-built) | 78.3 s | 140.0 s | **140.9 s** |

Budget 900 s. The +61.7 s that tasks 1-2 cost is the honest price of six checks that each spawn
several real `/bin/sh` children, one of which deliberately waits out a 2 s timeout budget and one of
which pushes 2,000,000 bytes through a pipe. Task 3's structural check adds **+0.9 s**: it spawns
two `grep`s and writes two small files, and like its five predecessors it reads no swept artifact,
so `sweep_one`'s `readable` filter runs it once per full `core_checks` pass rather than once per
sentinel pair.

`pgrep -a 'sleep 3' | wc -l` is **0** after the suite. The suite leaks no process.

## Task Commits

| Task | Name | Commit |
|---|---|---|
| 1 | The timeout owns the process group — proven on a GRANDCHILD | `8f5d2ef` |
| 2 | The environment vector, and a version that cannot be missing | `a8a3a21` |
| 3 | The suite cannot name the real solver; three overrides registered or named as gaps | `76184d0` |

## Task 1 — the grandchild (from commit `8f5d2ef`)

Three checks, 279 lines, all in `offchain/test/Main.hs`.

`a_hung_grandchild_is_terminated_and_reaped` is the one this phase was most at risk of writing
wrongly. The stub backgrounds `sleep 300 &` and `wait`s, so the process under test is one level
BELOW the one the wrapper was handed. **MEASURED: written against a direct child this check CANNOT
FAIL** — `System.Timeout.timeout` reaps a direct child with no orphan, so the assertion would be
green with or without the group-owning `/usr/bin/timeout -k`. Liveness is read from `/proc/<pid>`,
which answers "terminated AND reaped" rather than "stopped". `grep -c 'sleep 300 &'` is **2** and
`grep -c '/proc/'` is **3**.

`a_stderr_flood_completes_without_deadlock` asserts 2,000,000 bytes as an **equality**, so a
truncating drain reddens as loudly as a deadlocking one, and carries its own `System.Timeout` budget
so a deadlock fails the check BY NAME instead of hanging the suite.

`a_timed_out_run_yields_Aborted_and_no_artifact` uses a stub that writes a VALID artifact and a
VALID log FIRST and then hangs. A layer checking artifact presence before the exit code would call
that a success while the process still runs.

Every survivor is killed on the way to FAILING about it: a check that testifies about process
reaping and leaks a process has reproduced its own subject.

### The negative control, verbatim — and one honest correction about its instrument

Recorded in `8f5d2ef` as the FIRING OBSERVATION for `Gams.Run` spawning the binary directly with
only the Haskell backstop, which is precisely the direct-child-only kill the plan asked to observe:

```
FAIL a_hung_grandchild_is_terminated_and_reaped: the backgrounded grandchild
3896506 SURVIVED the timeout. /proc/3896506/stat said:
  3896506 (sleep) Z 1 3895722 3895722 34836 ...
FAIL a_timed_out_run_yields_Aborted_and_no_artifact: ... gave
Aborted ExitVerdict (TimedOut Killed) at exit -1
```

Two facts are legible in that line and they are the two the plan asked for: field 3 is the process
state and field 4 is the PPID, so the surviving process was **reparented to PID 1** and was still
present in procfs when the check read it.

**Correction of record:** the plan's acceptance criterion asked for
`ps -o pid,ppid,stat,cmd -p <pid>` and what was captured is `/proc/<pid>/stat`. Same two facts,
different instrument. It was NOT re-taken during the continuation — pid 3896506 is long gone and
re-taking it would mean re-mutating `Gams.Run` to manufacture a screenshot of something already
observed. The state letter is `Z` rather than `S`, so what this demonstrates precisely is *still
present at PPID 1*, which is what the check reads and therefore what the check needs; it is not a
claim that the `sleep` was still burning a core at that instant.

## Task 2 — two environment vectors (from commit `a8a3a21`)

`the_child_environment_is_exactly_the_whitelist` has the child print its own environment to a file
outside the run directory. `shell_injected_env_keys` was **MEASURED on this host**, not copied from
the plan: `["PWD", "SHLVL", "_"]` — the shell's own exports to its children, not the caller's. A key
outside `whitelist_keys` and outside that set FAILS naming itself.

`an_inherited_environment_is_observed_to_differ` runs the SAME function against the SAME stub with
`rr_env = Nothing`. This is what proves the whitelist is in force; a byte comparison cannot, because
four hostile ambient variables changed nothing and this host offers only `C`, `C.utf8`,
`en_US.utf8` and `POSIX` — no comma-decimal locale to differ with. The inherited child carried
**64 keys** against the whitelist's 3.

`version_detection_failure_aborts_the_invocation` drives two stubs that both exit 0 with a VALID
606-byte artifact: one whose log has no job banner, one that puts the banner on STDERR. Both must
abort. Accepting either is a run COMPLETED with an empty version component, which `not null` does
not forbid.

### The deviation Task 2 found inside its own check

**[Rule 2 — missing critical] The check as planned COULD NOT FAIL.** Its expected side was
`whitelist_for scratch` — the same expression as its subject — so deleting `LC_ALL` from that
function moved both sides together and the check stayed GREEN. OBSERVED, then fixed: the key set is
now compared against `whitelist_keys` (the OTHER constant) and the locale pin is spelled in the test
file. That is the **seventh representation** of this project's standing defect, found inside the
check written to catch the sixth.

## Task 3 — the structural guarantee and the override sweep

`the_suite_never_names_the_real_solver` is the DB-free scan's twin, and it is now an in-suite check
rather than a command an executor has to remember to run at verification time. Three tokens, BUILT
by concatenation so this file stays inside its own scan:

- the module that resolves the LIVE binary and model out of `Gams.Config`, imported by exactly one
  place — the conformance executable plan 24-05 writes — and by nothing this test binary links;
- the capture script's require-a-real-solver gate, on 23-RESEARCH's ruling about its store-side
  twin: gating a suite on "if the tool is installed" fails OPEN;
- the absolute installation prefix of the real binary on this machine.

`Gams.Run` — the testable IO edge, handed its binary path explicitly — is deliberately NOT a token.
Every Tier-B check above drives it against `/bin/sh` stubs the check wrote itself, and that is the
whole design rather than a loophole in it.

**The positive control is PROVEN, not asserted.** A bait file carries all three tokens in the shapes
they would really appear in (an import, an environment gate compared as a string, an absolute path
constant) and must be NAMED by the scan; a clean file carrying the IO edge and `/bin/sh` must NOT
be. The control is ordered FIRST. Absence does not read as success until the pattern has been shown
matching, and firing observation 1 below shows it doing so against a real edit to the real file.

`GAMS_CONFORMANCE` joins `advertised_overrides` in exactly `STORE_CONFORMANCE`'s shape.
`GAMS_BIN` and `GAMS_MODEL` join `unprobed_overrides` with written reasons over the 200-character
floor. `probe_override` was **not weakened**: their consumer is the module the grep above makes
unreachable, so assertion (3) has no subject, and both ways of manufacturing one are rejected —
importing it breaks the GAMS-free property on its way to enforcing it, and a validator written only
to be probed is a registered-but-vacuous probe, the exact defect the sweep exists to catch,
installed to close the sweep's own list. `GAMS_MODEL`'s reason records that `volume_path.gms` does
not exist in this worktree (it lives in the sibling GAMS worktree), so that override is REQUIRED
here rather than optional.

## The seven firing observations

Four are Task 3's, taken during the continuation; three are Tasks 1-2's, quoted from their commits.
Every mutation was applied ALONE and every source was restored **from a saved copy** verified by
digest, never by `git checkout`.

### Task 1 — `Gams.Run` spawns the binary directly (Haskell backstop only)

Quoted in full in the negative-control section above: both
`a_hung_grandchild_is_terminated_and_reaped` and `a_timed_out_run_yields_Aborted_and_no_artifact`
went RED, the first quoting `/proc/3896506/stat`. Source restored sha256-identical
(`4e0b2f60…31aa66`).

### Task 2 — three mutations

```
1. env = Nothing unconditionally ->
   FAIL the_child_environment_is_exactly_the_whitelist: ... MISSING LC_ALL
   FAIL an_inherited_environment_is_observed_to_differ: the inheriting child's
     environment carries 64 keys and the whitelisted one carries 64
   (the second fired for exactly the reason its haddock names)
2. LC_ALL deleted from Gams.Env.whitelist_for -> BOTH
   the_whitelist_pins_LC_ALL_C_and_admits_no_GAMS_variable AND
   the_child_environment_is_exactly_the_whitelist FAIL (only after the fix)
3. a placeholder version on a missing banner ->
   FAIL version_detection_failure_aborts_the_invocation: ... was not refused:
   Produced (606 artifact bytes, GAMS 0.0.0, ...)
```

Sources restored sha256-identical: `Run.hs 4e0b2f60…31aa66`, `Env.hs 2e78bfc3…7ed7fe`.

### Task 3, observation 1 — the token named in prose

A comment reading `-- FIRING OBSERVATION 1 (24-04, TEMPORARY): the resolving module named in prose
-- Gams.Invoke` was added above the runner section:

```
FAIL the_suite_never_names_the_real_solver: this test suite NAMES the real solver:
      offchain/test/Main.hs:9829:-- FIRING OBSERVATION 1 (24-04, TEMPORARY): the resolving module named in prose -- Gams.Invoke
      One of three tokens is present: the module that resolves the live binary and model, the capture script's require-a-real-solver gate, or the installation's absolute path. ...
FAIL sentinel_falsification_harness: the suite was ALREADY failing before a single mutation was applied (the_suite_never_names_the_real_solver). ...
136/138 checks passed
```

The scan NAMED the line and the column, which is the whole point of the `-nHE` vector.

### Task 3, observation 2a — the variable dropped from the list

`gams_conformance_env_var` removed from `config_env_vars`, the `OverrideProbe` left in place. This
is the observation that justifies the growth guard: **the coverage arm stayed GREEN** — it is a
per-variable arm and a variable that is not in the list is not uncovered, it is unmentioned. The new
census is what reddened:

```
FAIL store_overrides_are_probed_or_named_as_gaps: these environment-variable constants are DECLARED in offchain/lib/Store/Config.hs / offchain/lib/Gams/Config.hs and this file's config_env_vars list names none of them: gams_conformance_env_var.
136/138 checks passed
```

Without the census this mutation is invisible. With it, so is a sixth variable added to either
config module.

### Task 3, observation 2b — the constant renamed in the config module

`gams_conformance_env_var = "GAMS_CONFORMANCE_V2"` in `Gams.Config`, everything else untouched.
**Two independent checks** fired:

```
FAIL every_advertised_override_is_honoured: GAMS_CONFORMANCE is ADVERTISED and DEAD: its resolver returned "offchain/rig/gams-conformance.json" with the variable set to "/nonexistent-override-probe/GAMS_CONFORMANCE.json". Every falsification aimed through this variable is vacuous until it is honoured -- measured three times in this module already (22-03 RIG_MANIFEST, 22-04 RIG_CHEAT_SWAP_PROOF, 22-07 RIG_PINS).
FAIL store_overrides_are_probed_or_named_as_gaps: the config modules advertise these environment variables and this file's override lists name NONE of them: GAMS_CONFORMANCE_V2.
135/138 checks passed
```

### Task 3, observation 2c — the COUNTER-demonstration

The same rename, with the override list referring to `gams_conformance_env_var` instead of spelling
the name — which is exactly what the plan's acceptance criterion 5 asked for:

```
138/138 checks passed
SC-3 and SC-4 OK
exit=0
```

**The whole suite is green with the library renamed underneath it.** See the deviation below.

### Task 3, observation 3 — a thin reason

`reason_model_has_no_offline_consumer` replaced with `"GAP. Not needed offline."`:

```
FAIL store_overrides_are_probed_or_named_as_gaps: these unprobed-override entries carry no real reason: GAMS_MODEL.
136/138 checks passed
```

Restored: `Main.hs 02981e67…0fe356`, `Gams/Config.hs 95890914…e6b2dd`, both verified by digest
against the saved copies, and `git status --porcelain offchain/lib/Gams/` empty afterwards.

## The floors, re-measured cold

Run at execution time, both together, neither derived from the other and neither incremented:

```
find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l          -> 55
find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) ... -> 63
```

`purge_file_floor` = **55** against exactly 55 files. `credential_scan_floor` = **63** against
exactly 63. **Zero slack on both, and neither moved** — this plan adds no file, it adds checks to
one that already existed. Extension census under `offchain/` unchanged: `hs 45, sh 8, json 8, md 3,
txt 2, sql 2`. The re-measurement was done anyway because the rule is that a floor is re-measured
whenever a plan is already editing this block, and 24-02 is why: it recorded a measurement whose
edit never reached the source, and no arithmetic would have caught that. Both haddocks record this
sitting.

## Deviations from Plan

### 1. [Rule 1 — the plan's own acceptance criterion is backwards] The override list keeps the LITERAL name

**Found during:** Task 3.

**Issue:** acceptance criterion 5 requires `grep -c 'GAMS_CONFORMANCE' offchain/test/Main.hs` to be
`0`, justified as *"the variable is referenced through `gams_conformance_env_var`, never re-spelled
(which is what makes a rename in the config module redden the sweep)"*. The justification is false,
and the plan contradicts itself: its own action text says the entry is *"Same shape as
`STORE_CONFORMANCE` exactly"*, and `STORE_CONFORMANCE` is a literal.

**Why it is false, and MEASURED:** with the constant in the list, `uncovered` compares the constant
against itself and is true for every possible value of it, and `probe_override` sets the environment
by that same constant, so both detectors follow a rename together. Firing observation 2c is the
measurement: renaming the constant in `Gams.Config` with the list referring to it leaves the whole
suite at **138/138, exit 0**. With the literal, the identical rename reddens **two independent
checks** (observation 2b).

**Fix:** the literal is kept, and the measurement is written into
`store_overrides_are_probed_or_named_as_gaps`'s haddock under its own heading so the criterion is
not re-proposed. The consequence for the criterion: `grep -c 'GAMS_CONFORMANCE'` is **2**, not 0 —
the entry and the haddock paragraph explaining why. Every other Task 3 acceptance criterion is met.

**Files modified:** `offchain/test/Main.hs`. **Commit:** `76184d0`.

### 2. [Rule 2 — missing critical functionality] The variable list had no growth guard

**Found during:** Task 3, while extending the list from two variables to five.

**Issue:** `store_vars` was a transcription. A sixth variable added to either config module, and to
neither override list, would leave every assertion in the check passing — the advertised-and-dead
defect one level above where the sweep already catches it.

**Fix:** `config_env_vars` now pairs each value with the NAME of the constant that holds it, and a
census grepped out of `offchain/lib/{Store,Gams}/Config.hs` (`^[a-z_]+_env_var :: String$`) is
compared against those identifiers BOTH WAYS. A collapsed census — `grep` exit 1, or an operand
missing from disk — is reported as a failure rather than as an empty set, so it cannot agree with an
emptied list. OBSERVED firing (observation 2a) on the exact mutation the plan named, which the
pre-existing coverage arm did not catch.

**Files modified:** `offchain/test/Main.hs`. **Commit:** `76184d0`.

### 3. [record] The negative control's instrument

Recorded as `/proc/<pid>/stat` rather than `ps -o pid,ppid,stat,cmd`. Same two facts (state, PPID
1); not re-taken during the continuation because the pid is gone and re-taking it would mean
re-mutating `Gams.Run` to photograph something already observed. Detail in the Task 1 section above.

### 4. [record] The check keeps a name its scope has outgrown

`store_overrides_are_probed_or_named_as_gaps` now covers five variables across two config modules
and is no longer the store's alone. The name is kept because the acceptance criteria and the phase
record refer to it; the haddock says so in its first paragraph rather than leaving the mismatch to
be discovered.

## Prose inside a grep's blast radius — instance 16

The comment above the `Gams.Run` import already carried instance 15 (its first draft listed all
three GAMS-free tokens in the sentence claiming they were absent). Task 3 wrote a whole check, a
pattern, a bait, a positive control and three override reasons that all have to DESCRIBE those three
tokens without naming them, inside the very file being scanned. Every one of them describes rather
than lists, the pattern and the bait are both built by concatenation, and the answer was the same as
it has been the previous fifteen times: **move the prose, never relax the pattern.**

## Requirements

**GAMS-05 is marked COMPLETE.** Every row of roadmap SC-4 has shipped and every one is OBSERVED: a
child that never exits is terminated and reaped with no orphan surviving (read from procfs, with a
negative control showing the same stub surviving a direct-child-only kill); a child writing >1 MB to
stderr completes without deadlock (2,000,000 bytes, asserted as an equality); and "a timed-out run
never produces an output row" was discharged at the TYPE level at 24-03 under planning correction 1,
because the append-only run log is STORE-07 and belongs to Phase 25. No GAMS-05 row is owed to a
capture artifact.

**GAMS-03 stays PARTIAL.** SC-2's version rows all shipped (24-01, and Task 2's missing-banner
abort), but its last sentence — the absolute resolved binary path and the sha256 of the executable
recorded alongside the version — is a capture-artifact row and the capture does not exist until
24-05.

**GAMS-06 stays PARTIAL.** Task 2 discharged SC-5's "a run inheriting the environment is OBSERVED to
differ" in the form planning correction 2 restated it, and BYTE-04 closed at 24-02. The remaining
row — a hostile ambient variable produces byte-identical output — was explicitly adopted unchanged
by correction 2 and *"lands in the capture"*, so it belongs to 24-05.

GAMS-01, GAMS-02 and GAMS-04 are untouched by this plan and stay as 24-03 left them.

## Issues Encountered

The plan was interrupted by a connection loss mid-Task-3. Nothing was lost: Tasks 1 and 2 were
already committed, the working tree was clean, no stub process was orphaned (`pgrep -a 'sleep 3'`
was 0) and no temp directory was stranded. The continuation re-measured every inherited claim before
trusting it, on the standing rule that this phase has already shipped one summary whose number never
reached the source.

Four untracked files at the repository root — `CHANGELOG.md`, `Setup.hs`, `stack.yaml`,
`stack.yaml.lock` — predate this plan, are outside its territory, and were left alone.

## Carry-forwards

1. **`gams_conformance_command` names a script that does not exist yet.** `probe_override` does not
   need it to exist — it points the variable at a path that cannot exist and asserts the reader
   fails naming it — but the advice string tells an operator to run
   `bash offchain/rig/capture-gams-conformance.sh`, and 24-05 owes that file.
2. **The `unprobed_overrides` list is expected to SHRINK at 24-05, not grow.** `GAMS_BIN` and
   `GAMS_MODEL` stay gaps for as long as `cabal test` cannot reach their consumer, which is
   permanent by design; what 24-05 owes is the capture-side evidence their reasons promise — a
   resolved absolute path, an executable digest, and a job banner naming the model that ran.
3. **The census is scoped to the two config modules.** `Driver.Capture` and `Driver.Seed` carry
   their own environment variables and their own guards; if a third config module appears, it must
   join `config_modules` in the commit that creates it, on the same rule that governs
   `aeson_storage_path`.

## User Setup Required

None.

## Next Phase Readiness

24-05 (wave 5, Tier C) is unblocked. It writes the module the grep above forbids this file from
naming, the capture executable and script, the committed `gams-conformance.json`, nine Tier-C checks
and the sixth swept artifact — at which point both floors move again and both must be re-measured
cold, together.

## Self-Check: PASSED

- `offchain/test/Main.hs` — FOUND on disk, modified in all three task commits.
- `.planning/phases/24-gams-invocation-toolchain-identity/24-04-SUMMARY.md` — this file.
- Commits `8f5d2ef`, `a8a3a21`, `76184d0` — all three FOUND in `git log`.
- `cabal build --enable-tests -j all`: exit 0, **0** warnings. `cabal test`: exit 0.
- Suite **138/138**, `grep -c '^FAIL '` = **0**.
- `grep -cE 'Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams' offchain/test/Main.hs` = **0**.
- `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` = **0**.
- `pgrep -a 'sleep 3' | wc -l` = **0**.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` = EMPTY.
