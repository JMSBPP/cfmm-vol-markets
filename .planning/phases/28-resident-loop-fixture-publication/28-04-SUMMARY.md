---
phase: 28-resident-loop-fixture-publication
plan: 04
subsystem: offchain-loop
tags: [haskell, loop, publication, tree-diff, precondition, cross-track-contract, trip-wire, exdev, census]

requires:
  - phase: 22-driver-capture
    provides: "`Driver.Capture.write_atomically` — the ONE rename, whose sibling rule this plan MEASURED for the first time and whose stated reason it corrected"
  - phase: 27-anvil-read-layer
    provides: "`walk_files` (the recursive lister the snapshots use) and the both-directions census discipline"
  - plan: 26-02
    provides: "`the_upstream_shocklib_pin_is_a_live_trip_wire` — the shape a check that reads `origin/develop` has to take, ref resolvability asserted FIRST"
  - plan: 28-03
    provides: "`Loop.Publish`, `Loop.Config`'s publication target, `fresh_temp_dir`'s unique suffix, and the 528 s wall clock this plan had to fit inside"
provides:
  - "`Loop.Publish.publish_precondition` / `PublishPrecondition` / `publish_precondition_message` — the startup refusal, its two diagnoses, and the one sentence carrying path, owner, refusal and repair"
  - "`offchain/app/LoopMain.hs` calls it ONCE, before the first poll, exiting 40"
  - "four checks: the before/after tree diff, the loud named refusal, the `origin/develop` trip-wire on `VOLUME_PATH_JSON`, and the outstanding prerequisite AS A VERDICT"
  - "a MEASUREMENT of what a non-sibling temp file costs, and the corrected haddock in `Driver.Capture` that three phases of prose had wrong"
  - "`path_on_upstream` — one upstream reader, two subjects"
affects: [28-05, LOOP-04]

tech-stack:
  added: []
  patterns:
    - "A claim about the filesystem is settled by a BEFORE/AFTER snapshot over a directory seeded with decoys, never by reading the writer"
    - "An outstanding PREREQUISITE is registered as a check whose failure text says what a PASS means and what a FAIL means, because a paragraph cannot notice the day it stops being true"
    - "A cross-track constant is compared byte-for-byte against the CONSUMER's own declaration read live through `git show`, with the extraction asserted to have found exactly one non-empty literal FIRST"
    - "A firing input whose predicted arm does not fire is driven a SECOND way until the arm's real subject is identified, and the haddock is corrected to name the limit"

key-files:
  created: []
  modified:
    - offchain/lib/Loop/Publish.hs
    - offchain/app/LoopMain.hs
    - offchain/test/Main.hs
    - offchain/lib/Driver/Capture.hs

key-decisions:
  - "`publish_precondition` is a SEPARATE type from `PublishRefusal`: one is a fact about a document in a running loop, the other about the process's environment before any block was read"
  - "`FixtureDirNotADirectory` is a second constructor rather than a second message, and the suite asserts the two rendered strings DIFFER — one message reused would name neither repair"
  - "`precondition_advice (FixtureDirMissing _)` is DEFINED as the library's message rather than re-typed: two copies of the sentence naming the owning workstream are two places for that workstream to stop being named"
  - "Arm (e) of the tree diff is kept, with its LIMIT written into its own haddock, rather than removed or strengthened into a race: a before/after diff cannot see where a temp file lived, and saying so is worth more than an arm that claims it can"
  - "`Driver.Capture`'s three-phase-old 'silently degrade to a copy' sentence is FALSE and was replaced by the measurement, not softened"

patterns-established:
  - "A structural property is stated as the IMPORT LIST that makes the wrong branch untypeable, not as a promise of restraint — and the prose is written so the grep asserting it can be zero"

requirements-completed: []

duration: 118min
completed: 2026-08-23
---

# Phase 28 Plan 04: Exactly One File, and a Directory This Loop Will Not Invent Summary

**Publication was OBSERVED adding exactly one file to a directory holding two decoys and nothing
else — added `["volume_path.json"]`, removed `[]`, decoy bytes unchanged, no `*.tmp` surviving,
and the parent gaining only `fixtures/volume_path.json` — across TWO publications of different
bytes; and the plan's own firing input for the "nothing outside" arm came back `228/228`, which is
how the arm's real subject got named instead of assumed.**

## Performance

- **Duration:** 118 min
- **Started:** 2026-08-23T07:44:32Z
- **Tasks:** 2/2
- **Files modified:** 4 (0 created, 4 modified)

## Commits

| Task | Commit    | Subject                                                                |
| ---- | --------- | ---------------------------------------------------------------------- |
| 1    | `31d4d37` | a directory this loop will not invent, refused before the first block   |
| 2    | `e73693e` | one file proven by a tree diff, and a block reported as a verdict       |
| 2    | `e45b3b6` | the sibling rule, measured — and three phases of prose corrected        |

## The numbers, as measured

| Quantity                                     | Before  | After   | How                                             |
| -------------------------------------------- | ------- | ------- | ----------------------------------------------- |
| `cabal test` total (`BASE_4` -> `BASE_4 + 4`) | **224** | **228** | run COLD at `7257778` before any edit, then again |
| `cabal test` wall clock                       | 532 s   | 534 s   | `date` around the binary, both ends RUN         |
| `cabal build --enable-tests -j all` warnings  | 0       | **0**   | `grep -cE '[Ww]arning'` over the build log      |
| `^Downloading` lines                          | 0       | **0**   | same log                                        |
| `purge_file_floor`                            | 82      | **82**  | `find` RUN at both ends                         |
| `credential_scan_floor`                       | 93      | **93**  | `find` RUN at both ends                         |

**`BASE_4 = 224` was measured COLD** at this plan's start against a clean tree at `7257778`:
`224/224 checks passed`, `WALL_SECONDS=532`.

**BOTH FLOORS RE-MEASURED BY RUNNING `find`, AND BOTH ARE UNCHANGED**, which is what this plan
predicted because it creates no file:

```
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l
82
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
93
```

Extension census under `offchain/` at that measurement: **hs 66, sh 12, json 11, sql 4** —
identical to 28-03's. Both commands were RUN; neither number was carried forward.

**FOUR CHECKS COST THE SUITE ONE TO TWO SECONDS.** 532 s to 533 s at Task 2's commit and 534 s at the correction commit, through roughly fifteen sweep passes.
28-03's multiply-by-fifteen rule was applied before these checks were written — no race, no
`threadDelay`, no long harness — and the budget it protects is intact: **366 s of headroom against
the 900 s ceiling remain for 28-05.**

## What was built

### Task 1 — the precondition, its text, and the exit that carries it (`31d4d37`)

`Loop.Publish.publish_precondition :: FilePath -> IO (Either PublishPrecondition ())` asks
`doesDirectoryExist` and `doesFileExist` and answers with one of two named constructors. It makes
nothing on any path, and **the property is structural rather than careful**: the `System.Directory`
import list carries the two QUESTIONS and no maker of any kind, so the branch that could do it does
not typecheck.

`publish_precondition_message` carries all four things in ONE sentence, because an operator meets
this once, on stderr, next to an exit code: the RESOLVED path, the owning workstream
(`mev_tax_model_one`, GitHub issues **#24 and #25**), the refusal to create it, and the repair.

Verbatim, as the check reads it:

> the publication directory "/tmp/cfmm-loop-loop04-missing-dir-24029922173512/fixtures" DOES NOT
> EXIST, and this process will not create it. That directory belongs to the mev_tax_model_one
> workstream -- GitHub issues #24 and #25 -- and a loop that created it would publish a fixture into
> a path of its own invention, report success, and leave the consuming forge test skipping forever.
> Land the directory on develop from the #24 track, or point FIXTURE_DIR at a directory that already
> exists.

The haddock records the two reasons the text is this specific, and they compose into silence:
a loop that created the directory turns a typo into a fixture published where nothing reads it, and
the consuming forge test SKIPS while the file is absent — so a wrong path is GREEN on both sides of
the workstream boundary and leaves no evidence anywhere.

`offchain/app/LoopMain.hs` calls it ONCE, at startup, before the first poll, and exits by
`exit_code_for_precondition (FixtureDirMissing _)` = **40**. At startup and not at the first
publication, deliberately: a loop that discovers this on its first EVENT has already advanced a
watermark past blocks it could not publish for. `publish_fixture` keeps its own guard as well, and
the suite drives both — a directory removed while the loop runs is not a directory that was never
there.

### Task 2 — the four checks (`e73693e`)

1. **`publication_adds_exactly_one_file_and_nothing_else`** — the tree diff. Two decoys inside the
   publication directory, a third in its PARENT, then snapshot, publish, snapshot. Five arms in
   order, and the first is the one that makes the rest mean anything.
2. **`a_missing_fixture_directory_is_a_loud_named_failure`** — the refusal, its four required
   contents, exit 40, and the filesystem UNCHANGED afterwards.
3. **`the_default_fixture_path_is_the_consumers_own_constant`** — the live trip-wire on
   `origin/develop`.
4. **`the_fixtures_directory_is_recorded_absent_from_both_trees`** — the prerequisite as a verdict.

### The snapshots, as sets

Taken from the check's own construction; the failure messages print exactly these on a red run.

| Snapshot                       | Contents                                                                    |
| ------------------------------ | --------------------------------------------------------------------------- |
| `before` (publication dir)     | `["decoy-one.txt", "decoy-two.json"]`                                       |
| `after` first publication      | `["decoy-one.txt", "decoy-two.json", "volume_path.json"]`                   |
| `added`                        | `["volume_path.json"]`                                                      |
| `removed`                      | `[]`                                                                        |
| decoy bytes                    | UNCHANGED (read back and compared, not just the names)                      |
| `*.tmp` surviving              | `[]`                                                                        |
| `before` (PARENT)              | `["fixtures/decoy-one.txt", "fixtures/decoy-two.json", "parent-decoy.txt"]` |
| `added` (PARENT)               | `["fixtures/volume_path.json"]`                                             |
| `removed` (PARENT)             | `[]`                                                                        |
| after a SECOND publication     | `added` still `["volume_path.json"]`, `*.tmp` still `[]`, bytes DIFFERENT   |

The second publication is not a repetition: a temp sibling that survives the FIRST write is
invisible under arms (b) and (c) and becomes a COLLISION on the second, and it is the only way to
observe that the second document actually replaced the first rather than being refused into a green
nothing. The two artifacts differ in length by construction (264 and 296 bytes), so
`one_bytes /= two_bytes` is a real assertion.

### The constant, read live out of `origin/develop`

```
$ git show origin/develop:test/models/mev_tax_model_one/AlgebraIntegralMevTaxModelOneShocks.t.sol
string constant VOLUME_PATH_JSON = "test/models/mev_tax_model_one/fixtures/volume_path.json";
```

`grep -c` for that literal prints **1** — exactly one declaration, which the check asserts before
comparing. `Loop.Config.default_fixture_path` is byte-equal to it. 28-03 could only compare the
default against `default_fixture_dir </> fixture_file_name`, which is this side agreeing with
itself and is true for every possible value of both halves.

The extractor requires three things of a line — it names the constant, it says `constant`, and it
is an assignment with a string literal — so `string memory json = vm.readFile(VOLUME_PATH_JSON);`
(also an assignment naming the constant) is not a candidate and the extraction does not have to
guess. The result is asserted to be exactly ONE element and asserted NON-EMPTY before the
comparison, because an extractor that matched nothing agrees with any default this side happens to
hold — this milestone's standing defect arriving at the one comparison the whole bridge rests on.

### The prerequisite, as a verdict

`test/models/mev_tax_model_one/fixtures` is absent from BOTH trees, and that is now a check rather
than a paragraph:

```
$ git ls-tree -r --name-only origin/develop | grep -c "^test/models/mev_tax_model_one/fixtures"
0
$ find test -path "*mev_tax_model_one*"
(nothing)
```

The failure text says what a PASS means (LOOP-04's live half is blocked on the `#24` track landing
the directory, issue #25, and the loop's behaviour there is proven only through `FIXTURE_DIR`) and
what a FAIL means (the directory ARRIVED, nothing is broken, re-state LOOP-04 against the real tree
at the phase close and then RETIRE this check rather than weaken it). The listing's own control —
`consumer_test_path` must be IN it — is asserted first, because a listing that finds nothing
reports every directory as absent.

## The firing inputs, every one OBSERVED

| #   | Mutation                                                          | Result                                                                                                          |
| --- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| M1  | temp file → `getTemporaryDirectory` (destination under `/tmp`)     | **`228/228`, NOT CAUGHT — the plan's prediction REFUTED**                                                        |
| M1b | the same, destination on the repository's `ext4`                   | `226/228`, `unsupported operation (Invalid cross-device link)`                                                    |
| M2  | `publish_precondition` creates the directory and still refuses      | `226/228`, *"after publish_precondition refused …/fixtures, something IS there: a directory."*                    |
| M3  | one character out of `default_fixture_dir` (`fixtures` → `fixture`) | `225/228`, both strings named, and a SECOND check caught it independently                                        |
| M4  | `mkdir -p test/models/mev_tax_model_one/fixtures` in this worktree  | `226/228`, *"THIS WORKTREE now carries test/models/mev_tax_model_one/fixtures as a directory."*                   |

Every mutated source was restored from a copy and **`sha256sum -c` reported `OK` on all four
baselines after every one of the five drives.** M4's directory was removed and
`find test -path "*models*"` returns nothing again.

M3's failure names BOTH strings, verbatim:

```
FAIL the_default_fixture_path_is_the_consumers_own_constant: THE CONSUMER AND THIS SIDE NAME DIFFERENT FILES.
      VOLUME_PATH_JSON on origin/develop is "test/models/mev_tax_model_one/fixtures/volume_path.json"
      Loop.Config.default_fixture_path is "test/models/mev_tax_model_one/fixture/volume_path.json"
```

## Findings

### THE PLAN'S FIRST FIRING INPUT WAS REFUTED, AND DRIVING IT A SECOND WAY CORRECTED A HADDOCK THAT HAD BEEN WRONG SINCE PHASE 22

28-04-PLAN.md predicted that moving `Driver.Capture.write_atomically`'s temp file out of the
destination's directory would redden **arm (e)** — "nothing was created OUTSIDE that directory".
**DRIVEN: `228/228`, zero failures. Nothing reddened at all.**

The reason is a limit of the instrument rather than a defect in it, and it is now in the check's own
haddock: the temp file is created and then RENAMED AWAY, so a before/after snapshot taken once the
call has returned sees nothing. **A BEFORE/AFTER TREE DIFF CANNOT SEE WHERE A TEMP FILE LIVED.**
Arm (e)'s real subject is a file that SURVIVES outside the publication directory — litter, or a
destination written in the wrong place entirely — and the whole point of a temp file is that it does
not survive. Only a concurrent observer can see the window, and that is 28-03's race harness, which
costs the suite about 350 seconds and is deliberately not re-run here.

**Driven a second way** — the same mutation with the destination moved onto the repository's own
filesystem — it reddens, through the FIRST arm rather than arm (e):

```
FAIL publication_adds_exactly_one_file_and_nothing_else: unexpected IO error:
renameFile:renamePath:rename '/tmp/volume_path.json.tmp' to
'.../dist-newstyle/loop04-xdev/fixtures/volume_path.json': unsupported operation (Invalid cross-device link)
```

`/tmp` on this machine is `tmpfs` (device 50) and this repository is `ext4` (device 66306) —
`stat -c '%d %n' /tmp .`, run.

**AND THAT IS THE FINDING WITH THE LONGEST REACH.** Every version of `Driver.Capture`'s comment from
Phase 22 through 28-03 said a rename that crossed a filesystem "would silently degrade to a copy",
and `Loop.Publish`'s module header repeated it. **That sentence is false for this code path and had
never been driven.** POSIX `rename(2)` does not copy; it fails with `EXDEV`, and `renameFile`
raises. The sibling rule is RIGHT and the reason given for it was wrong: the hazard is not a silent
copy, it is a write that either works by luck of the mount table or dies at the last step with the
destination still holding the previous document. For a resident loop that is a halt, not a tear.
Both haddocks now carry the measurement and both drives.

### THE TASK-1 ACCEPTANCE CRITERION WAS UNSATISFIABLE BY THE SAME TASK'S OWN PRESCRIBED PROSE

`grep -cE "createDirectory" offchain/lib/Loop/Publish.hs` is required to print `0`. It printed
**2**, and both matches were haddock lines — one of them the sentence the plan itself asks for
("creates nothing on any path — no `createDirectory`, no `createDirectoryIfMissing`"), the other the
criterion quoting itself. **THE PROSE MOVED**, which is 27-01's rule for the twenty-ninth time on
this branch and the second time in phase 28 after 28-02's colliding exit numerals.

The replacement is strictly stronger rather than merely quieter: instead of promising restraint, the
haddock names the MECHANISM — the `System.Directory` import list carries `doesDirectoryExist` and
`doesFileExist` and no maker, so the branch that could create a directory does not typecheck. The
grep now has a real subject: any future *code* line reaching for a maker makes it non-zero.

### THE PLAN'S "`find test -path '*fixtures*'` RETURNS NOTHING" IS FALSE, AND WAS FALSE WHEN IT WAS WRITTEN

Task 2's acceptance criterion asks that `find test -path "*fixtures*"` still return nothing after
the run. RUN, on a clean tree, before this plan edited anything:

```
$ find test -path "*fixtures*"
test/pos_spec/fixtures
test/gamsDiff/fixtures
test/pos_spec/fixtures/vol_order_return_golden.json
test/gamsDiff/fixtures/price_impact_kernel.json
test/gamsDiff/fixtures/pricing_kernel.json
```

Three unrelated fixture directories predate this workstream. The criterion's real subject is the
`mev_tax_model_one` one, and the command that has it is
`find test -path "*mev_tax_model_one*"`, which returns nothing. The stronger form was checked
instead, in the check itself: `doesDirectoryExist default_fixture_dir` and
`doesFileExist default_fixture_path`, which name the resolver's own default rather than a glob.

### M3 WAS CAUGHT TWICE, BY TWO CHECKS WITH DIFFERENT DIAGNOSES

Changing one character of `default_fixture_dir` reddened
`the_default_fixture_path_is_the_consumers_own_constant` ("the consumer and this side name different
files", with both strings) AND
`the_fixtures_directory_is_recorded_absent_from_both_trees` ("the resolver's default moved and the
two are no longer about the same directory"). That is deliberate: check 4 writes the directory
string out by hand and compares it to the constant, which is 24-04's MEASURED ruling that referring
to the config constant alone leaves the suite green under a rename while the literal reddens. The
two checks now pin the same string from opposite ends — one to `origin/develop`, one to the
resolver — and cannot drift apart without one going red.

### M2 FIRED THE ARM THAT MATTERS AND ONLY THAT ARM

The mutation reports the refusal and creates the directory anyway — the exact failure LOOP-04
exists to prevent, and the one every other arm of that check is satisfied by. Only the after-state
arm fired. That is the arm earning its place: the verdict, the message, the four required contents
and the exit code were all still correct under a function that had already done the forbidden thing.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 3 — Blocking] Task 1's `createDirectory` criterion could not be met with the prescribed
haddock**
- **Found during:** Task 1
- **Issue:** `grep -cE "createDirectory"` printed 2, both prose, one of them the plan's own
  prescribed sentence.
- **Fix:** the prose moved; the property is now stated as the import list rather than as a promise.
- **Commit:** `31d4d37`

### Departures from the plan's sketch, toward the property the plan asked for

**2. `publish_precondition_message` is a THIRD export the plan does not name.** The plan lists
`publish_precondition` and `PublishPrecondition` and then requires the check to assert "the rendered
message contains the resolved path, the string `mev_tax_model_one`, and an issue reference". A
`Show` instance renders a constructor and a path, not a sentence, and `LoopMain`'s
`precondition_advice` is in an executable no check can import. So the renderer is exported, and
`precondition_advice (FixtureDirMissing _)` is DEFINED as it rather than re-typed.

**3. Arm (e) is KEPT with its limit documented rather than replaced.** The plan's firing input for
it was refuted. Removing the arm would lose a real guard (a writer that leaves litter outside the
directory), and strengthening it into a concurrent observer would cost the suite ~350 s for a
property 28-03 already measures. The arm stays and its haddock says what it cannot see.

**4. `plk_on_upstream` was renamed `path_on_upstream`.** 28-04 asks the same question of a `.t.sol`
file, and a helper named for `.plk` answering about a forge test is a name that has stopped being
true. One reader, two subjects; a second copy would be a second place for the ref to drift.

**5. A fifth drive (M1b) was run.** The plan names four firing inputs. The first was refuted, and
28-03's established pattern is that such an input is driven a second way until the arm's real
subject is identified. That second drive is what produced this plan's largest finding.

## Authentication gates

None.

## What this leaves for 28-05

- **LOOP-04's LIVE half.** Everything above is proven against temporary directories, because the
  real one is on neither tree. `the_fixtures_directory_is_recorded_absent_from_both_trees` is the
  standing record of that, and it will go red on the day the `#24` track lands the directory — at
  which point LOOP-04 must be re-stated against the real tree and that check retired.
- **The wall clock.** 534 s against 900 s. **366 s of headroom**, and any check costing T seconds
  costs the suite about 15T — so 28-05 has roughly 24 seconds of its own work to spend.
- **The loop still does not read back what it published.** 28-03 deferred this and 28-04 did not
  take it: `br_published` still means "the write returned". The tree diff observes the file from
  outside; the LOOP does not.

## Self-Check: PASSED

- `offchain/lib/Loop/Publish.hs` — FOUND
- `offchain/app/LoopMain.hs` — FOUND
- `offchain/test/Main.hs` — FOUND
- `offchain/lib/Driver/Capture.hs` — FOUND
- commit `31d4d37` — FOUND
- commit `e73693e` — FOUND
- commit `e45b3b6` — FOUND
