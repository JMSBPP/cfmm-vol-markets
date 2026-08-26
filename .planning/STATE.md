---
gsd_state_version: 1.0
milestone: v6.0
milestone_name: Model Output Store + VolumePath Bridge (rpc_api workstream)
status: in-progress
stopped_at: "Completed 28-05-PLAN.md AND THE PHASE. 228/228 -> 232/232 (BASE_5 + 4), exit 0, zero warnings, zero Downloading, 534 s -> 551 s against the 900 s ceiling -- four checks cost SEVENTEEN seconds, because 28-03's multiply-by-fifteen rule was applied before they were written and none of them races. LOOP-05 CLOSED and LOOP-02 CLOSED OVER THE LOOP; PHASE 28 COMPLETE, chain-free, with the LIVE half of all five requirements BLOCKED by name. AN EXCEPTION WAS INJECTED AT SEVEN STAGES of one iteration and every abandoned block left the watermark exactly where it was, no row for the event, and a block a clean pass RE-PROCESSED UNDER THE SAME CONTENT KEY -- the battery drives run_loop and NOT process_block, because four of the seven stages are components the iteration does not wrap and driving it directly measures the wrong composition (OBSERVED at 229/231 in the first version). TWO of the seven stages have a DIFFERENT disposition and both are earlier plans' deliberate rulings, recorded as DATA rather than forced into a uniform claim: the PUBLISH stage does not abandon the block (28-03 wrapped the write in try on purpose -- a full disk is not a reason to stop processing the chain), and the store legitimately HOLDS an entry for the three stages that throw after the solve, because decide writes it and that write is content-keyed. THE SHUTDOWN IS A QUESTION THE LOOP ASKS: Env gained env_interrupted and run_loop reads it at exactly two points, both BETWEEN blocks; LoopMain owns the IORef and installs a SIGINT/SIGTERM handler that writes it and does NOTHING else, because GHC's default throws UserInterrupt at the main thread asynchronously at a point nobody chose and that point includes the middle of the ledger's one commit. The iteration is now WRAPPED and HaltBlockException / exit 34 is the TENTH table entry -- DEMANDED by the totality check rather than permitted by it, since before this an escaping exception killed the process with no exit code from any table at all. offchain/rig/capture-loop.sh is WRITTEN, GATED exactly as Phase 27 gated its two, listed in endpoint_sites (19 -> 20) in the same commit, and UNRUN: its gate was EXERCISED with no rig stood up (\"CAPTURE FAIL: nothing answered eth_blockNumber\", exit 1, nothing written) and its artifact is deliberately ABSENT, which the suite asserts as a VERDICT whose failure text says what each direction means. FOUR DRIVES, THREE LANDED: hoisting the commit above the event loop -> 228/231 caught by TWO checks (the plan's own prescribed input for that check would have been INERT, and the reason names what the arm really guards); reading the flag between EVENTS -> 229/231 at \"Row counts by block: [(1,1),(2,0),(2,0),(3,0)]\"; a surviving temp sibling -> 228/231 caught by this check AND 28-04's tree diff. THE FOURTH WAS ABANDONED AT 52 MINUTES OF CPU: rename -> copy reddens the ten-second race, which puts a ten-second check into the sweep's reader sets, so a whole CLASS of firing input cannot be driven on this suite -- 28-03's 2328 s finding, sharper. grep -c ledger_commit_block over Loop/Run.hs prints 1 after TWO haddock sentences moved, one of them 28-02's and PREDATING this plan -- 27-01's rule for the thirtieth time and the first time it caught prose the executing plan did not write. Floors 82/93 -> 83/94, both re-measured by RUNNING find, both moved by the SAME one .sh; census hs 66, sh 13, json 11, sql 4 -- the .json census did NOT move, which is the artifact being absent stated as a number. Phase totals: 205/205 -> 232/232, +27 across five plans. Next: /gsd:verify-phase 28, then capture-loop.sh when #26 lands an emitter and the #24 track lands the fixtures directory."
last_updated: "2026-08-23"
last_activity: "2026-08-23 -- 28-05 executed AND PHASE 28 CLOSED BY HAND. 228/228 -> 232/232, 0 warnings, 0 Downloading, 551 s. LOOP-05 and LOOP-02 closed; all five LOOP requirements complete CHAIN-FREE with the live half BLOCKED on issue #26 (no deployable Shock emitter) and issues #24/#25 (the publication directory is on neither tree). An exception at SEVEN stages leaves the watermark unadvanced and the block re-processable under the same content key; the shutdown lands block 2 whole and never enters block 3. offchain/rig/capture-loop.sh written, gated, census-listed and UNRUN, with its absence registered as a verdict. Floors 82/93 -> 83/94. 28-05-SUMMARY.md and 28-SUMMARY.md written; REQUIREMENTS.md, ROADMAP.md and this file edited BY HAND -- no gsd-tools state subcommand and no phase complete was run."
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 26
  completed_plans: 26
---

<!--
FRONTMATTER WARNING, RECORDED AT 24-03 AND STILL BINDING.
`gsd-tools state record-session`, `state add-decision` and `state update-progress` all REWRITE this
frontmatter from a global view of the repository's .planning trees, and they get it wrong for this
one: the milestone reverts to v2.0, `status:` is overwritten with whatever prose the "Status:" line
of the body happens to start with, and the four progress counters are replaced by machine-wide
totals (25 phases / 43 plans). 24-03 ran all three and had to restore every field by hand.
EDIT THIS BLOCK BY HAND. `roadmap update-plan-progress <N>` is the one that is safe.
-->


# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-27)

**Core value (v4.0):** `VolOrderManagerMod.plk` is a vol-order REGISTRY — `create_order(uint88,uint24,uint16)` (strike/width/skew, selector `0x6501fe94`) validating against the machine-checked `vol_order_is_complete` predicates, assigning a sequential id, storing a packed `VolOrder` word — plus a BEST-EFFORT batch entrypoint running N create_order calls in one tx (invalid tuples skipped, batch never reverts). Built for the rpc_api Haskell `StochasticOrderGen` consumer (PR #9 awaits this surface). Every claim is a CALLED test or an OBSERVED mutation kill; compiling is NOT evidence; the gate is the batch dispatch being CALLED green through FFI-deployed bytecode (**CORRECTED at 19-05** — `PLANK_SKIP` is the rescue queue for entrypoints that do NOT compile, so this module never belonged there; the queue is empty and there was no exit to perform).
**Current focus (v6.0):** the **model output store** — a Postgres/JSONB keyed store whose key is
the shock that produced the output, so an identical shock skips the solve and a re-solve that
disagrees is caught; and the issue #25 bridge carrying a live Anvil `next` event through the
GAMS VolumePath prover to the fixture the forge test reads. Binding reference:
`model/mev_tax_model_one/VOLUME_PATH.md` — consume, do not re-derive.

**Prior focus (v4.0, record):** **MILESTONE v4.0 COMPLETE (2026-07-21).** All five phases (16, 17, 18a, 18b, 19) and all 15 requirements shipped. `VolOrderManagerMod.plk` is a proven vol-order registry: `create_order` and `create_orders` both CALLED green through FFI-deployed bytecode, a 10-application mutation battery with ZERO survivors, an independent-mock sequence differential at tol 0, and a consumer golden fixture from an encoder outside this repo. Next action: tag v4.0 and hand off to peer `mv15a18k`, OR resume v2.0 (`/gsd:plan-phase 10`).

**Track note:** Sixth milestone — **v6.0 is the rpc_api workstream's** (offchain Haskell, branch `feat/rpc-api`), phases 23–28, from issue #25. The **subgraph (issue #14) was renumbered v6.0 → v7.0 on 2026-08-16** and is queued behind this one, on dependency grounds: it needs somewhere to put what it indexes, and v6.0 builds exactly that. v5.0 (VolOrder V2 re-pin + stochastic drivers, phases 20–22) SHIPPED 2026-08-03. v3.0 (VegaAccountMod vault, Phases 12–15) SHIPPED 2026-07-19 (tag `v3.0`). v1.0 (GAMS plumbing, Phases 1–7) PAUSED. v2.0 (vol-oracle differential, Phases 8–11) PAUSED after Phase 9 — VDIFF-05..08 (Phases 10–11) remain pending, NOT part of v4.0. Resuming v2.0 = `/gsd:plan-phase 10`. These phase ranges are separate tracks — never renumbered.

## Current Position

Phase: **28 — Resident Loop & Fixture Publication** — **COMPLETE (5/5 plans), 2026-08-23.**
Phase summary: `.planning/phases/28-resident-loop-fixture-publication/28-SUMMARY.md`.
Plan: **28-05 COMPLETE** (commits `63e0c84`, `478845d`, `e2b801d` + this close). Summary:
`.planning/phases/28-resident-loop-fixture-publication/28-05-SUMMARY.md`.
228/228 → **232/232** (`BASE_5 + 4`), exit 0, zero warnings, 0 `Downloading`, measured wall clock
**534 s → 551 s** against the 900 s ceiling; floors **82/93 → 83/94**, both re-measured by RUNNING
`find` and both moved by the SAME one `.sh` (census `hs 66, sh 13, json 11, sql 4` — the `.json`
census did NOT move, which is the capture's artifact being absent, stated as a number).
**Phase totals: 205/205 → 232/232, +27 across five plans.**
Next: **`/gsd:verify-phase 28`**, then the live `capture-loop.sh` run when issue #26 lands an
emitter and the `#24` track lands the fixtures directory.

**MILESTONE v6.0 IS 6/6 PHASES AND ITS `status:` IS DELIBERATELY STILL `in-progress`** — phase 28
is closed, not verified, and the milestone is not this plan's to declare finished.

**28-05 DISPOSITION — LOOP-05 IS CLOSED, LOOP-02 IS CLOSED OVER THE LOOP, AND THE PHASE IS COMPLETE
CHAIN-FREE WITH THE LIVE HALF OF ALL FIVE REQUIREMENTS BLOCKED BY NAME.**

**AN EXCEPTION WAS INJECTED AT SEVEN STAGES OF ONE ITERATION** — `source_logs`, `ledger_seen`,
`source_reads`, `solver_run`, `env_read_identity`, the publish write (a DIRECTORY placed at the
sibling temp path) and `ledger_commit_block` — and every abandoned block left the watermark exactly
where it was, no row for the event, and a block a clean pass RE-PROCESSED under the SAME content
key. The battery's PREMISE arm is ordered first: a clean pass over the same block must leave one
row, one store entry and a watermark, or every "nothing was written" arm is satisfied by a pipeline
that writes nothing ever.

**IT DRIVES `run_loop` AND NOT `process_block`, AND THE FIRST VERSION MEASURED THE WRONG
COMPOSITION** — OBSERVED at 229/231. Four of the seven stages are components the iteration does NOT
wrap, so their exceptions escape it into a caller that is always there in production. A battery
reporting those four as "escaping" would be a true fact about a function nobody calls alone.

**TWO OF THE SEVEN STAGES HAVE A DIFFERENT DISPOSITION AND BOTH ARE EARLIER PLANS' DELIBERATE
RULINGS, RECORDED AS DATA RATHER THAN FORCED INTO A UNIFORM CLAIM.** The PUBLISH stage does not
abandon the block — 28-03 wrapped the write in `try` on purpose, because a full disk or a directory
that vanished mid-run is not a reason to stop processing the chain. The store legitimately HOLDS an
entry for the three stages that throw after the solve, because `decide` writes it and that write is
CONTENT-KEYED, so the re-processed block recomputes the same key and elides. Asserting "every stage
leaves the store untouched" would have been false, and asserting "every stage abandons the block"
would have required reverting a shipped ruling to make a check pass — which is a check measuring
itself. What IS uniform is the arm that matters, and it is the requirement.

**THE SHUTDOWN IS A QUESTION THE LOOP ASKS, AND THE PROPERTY IS STATED AS A PLACE.**
`Loop.Run.env_interrupted` is read at exactly two points and both are BETWEEN blocks: at the top of
a pass before a range is planned, and after an iteration returns before the next block is entered.
`LoopMain` owns the `IORef Bool` and installs `installHandler sigINT`/`sigTERM` with a handler that
writes it and does NOTHING else — no logging, no exit, no IO. **GHC's DEFAULT `SIGINT` has exactly
the shape being avoided:** it throws `UserInterrupt` at the main thread asynchronously, at a point
nobody chose, and that point includes the middle of the ledger's one commit. `installHandler`
replaces it, so no exception is delivered at all. A clean drain returns `Right ()` and exits 0.
OBSERVED: the flag set from inside `source_logs` while it serves block 2 (which carries TWO events)
lands block 2 whole — both rows and its watermark, together — and block 3 is never entered.

**THE ITERATION IS WRAPPED, AND `HaltBlockException` / EXIT 34 IS THE TENTH TABLE ENTRY DEMANDED BY
THE TOTALITY CHECK RATHER THAN PERMITTED BY IT.** Before this, an exception escaping a stage killed
the process with a bare Haskell exception and **no exit code from any table at all** — the condition
did not exist until the wrapper did, which is a different thing from a code that was forgotten. It
is deliberately NOT mapped onto `HaltDb` or `HaltRpcExhausted`: an outer wrapper cannot tell which
stage threw, and a chain failure under a ledger discriminator is 28-01's conflation from the far end.

**`offchain/rig/capture-loop.sh` IS WRITTEN, GATED, CENSUS-LISTED AND UNRUN**, and its gate was
EXERCISED with no rig stood up: *"CAPTURE FAIL: nothing answered eth_blockNumber at …  This is NOT
a skip."*, exit 1, nothing written, `git status` unchanged. Its artifact is deliberately ABSENT and
`the_live_loop_capture_is_present_and_names_its_block` asserts that absence — passing while the live
run is OWED and BLOCKED, failing the day it appears, with failure text saying what to do then. No
check reads a non-existent artifact: `aeson_is_absent_from_the_storage_path`'s own haddock rules
that a missing subject is a FAILURE naming the plan that creates it, never a pass. Listed as a
`ShellConsumer` in `endpoint_sites` (**19 → 20**) in the SAME commit that created the file.

**FOUR DRIVES, THREE LANDED, EVERY BASELINE RESTORED `sha256sum -c` CLEAN.** Hoisting the commit
above the EVENT LOOP → **228/231**, caught by TWO checks with different diagnoses; the plan's own
prescribed input for that check (*move the commit ahead of the publish stage*) would have been
INERT, because the commit is already after publication and a publish exception is already swallowed
— and saying why names what the arm really guards. Reading the flag between EVENTS → **229/231**,
*"Row counts by block: [(1,1),(2,0),(2,0),(3,0)]"*. A surviving temp sibling → **228/231**, caught by
this plan's check AND 28-04's tree diff.

**THE FOURTH WAS ABANDONED AT 52 MINUTES OF CPU, AND THAT IS A FINDING ABOUT THE HARNESS.** Driving
the rename→copy mutation reddens 28-03's ten-second race check, which puts a ten-second check into
`sentinel_falsification_harness`'s reader sets. 28-03 measured that shape at 2328 s against a normal
528; this one never finished. **A whole CLASS of firing input — anything that reddens an expensive
check — cannot be driven on this suite in reasonable time.** The repair is to re-aim the mutation
surgically at the arm under test, which is what was done (keep the rename, re-fill the temp file
after it), and the arm reddened in a normal 553 s.

**`grep -c "ledger_commit_block"` OVER `Loop/Run.hs` PRINTS 1 AFTER TWO HADDOCK SENTENCES MOVED, AND
ONE OF THEM WAS NOT THIS PLAN'S.** It printed 3; the other prose was 28-02's, in the module header,
present since the file was created. 27-01's rule for the **thirtieth** time on this branch and the
first time it has caught prose the executing plan did not write. The replacement is stronger than a
quieter version of the same claim: the header now STATES the property the grep holds.

**LOOP-02 WAS CLOSED OVER THE LOOP, WITHOUT MOVING THE TOTAL.** 28-01 asserted both directions
against the reference implementations through a pipeline the SUITE composed and recorded that the
requirement is stated over `Loop.Run`. The replay direction reached the loop through the stage
battery's re-run arm; the distinct-events direction was folded into
`a_cache_hit_publishes_at_the_events_own_block`, which already stages exactly that collision — two
positions at DIFFERENT heights whose `split_for` answers agree, FOUND by search and CONFIRMED
through the full `split_for` — as `[1, 1]` ledger rows and `1` store entry, through a counting
store. Both instruments, because neither is sufficient: the entry count catches a ledger keyed on
the content key, the row counts catch a store keyed on the event position.

**STORE-07 IS PARTIAL BY CONSTRUCTION AND STAYS DEFERRED.** Migration `004` carries three of its
four fields plus `observed_at`, unique on the event position, every outcome recorded. What is ABSENT
is the append-only ENFORCEMENT: no trigger, nothing forbidding an `update` or a `delete`. Nothing
issues one either — but "nobody does it" is a fact about callers and "the server refuses it" is a
fact about the schema, and STORE-07 asks for the second.

**FOUR OF THE FIVE LOOP REQUIREMENTS WERE CARRIED IN MARKED *Blocked* AND THE ATTRIBUTION WAS
INHERITED RATHER THAN MEASURED EVERY TIME** — LOOP-01 at 28-02, LOOP-03 at 28-03, LOOP-04 at 28-04,
LOOP-05 at 28-05. Phase 27 made the identical correction for CHAIN-02/03 and wrote that it is "the
kind of inheritance that costs a phase". It cost this one four more instances.

**`gsd-tools state …` AND `phase complete` WERE NOT RUN.** Every document in this close was edited
BY HAND and this frontmatter was verified intact afterwards — `milestone: v6.0`, `status:`, and four
counters that are a COUNT of the plan files per v6.0 phase (5+6+3+4+3+5 = 26), not an addition.
`roadmap update-plan-progress 28` would write `6/5` because it counts the phase-level summary as a
plan; the table says `5/5` by hand.

**28-04 DISPOSITION — LOOP-04's CHAIN-FREE HALF IS CLOSED, AND ITS HEADLINE IS A TREE DIFF RATHER
THAN A READING OF THE WRITER.** Publication was OBSERVED adding **exactly one file** to a directory
holding two decoys: `added = ["volume_path.json"]`, `removed = []`, the decoys' **BYTES** unchanged
(read back, not merely their names), **no `*.tmp` surviving**, and the PARENT gaining only
`fixtures/volume_path.json` — across **TWO** publications of different bytes, because a temp sibling
that survives the first write is invisible until the second one collides with it. The
"before-set is non-empty" arm is ordered FIRST: an empty before-set makes every set difference
trivially right, and a publisher that WIPED the directory would pass all of them.

**THE REFUSAL NAMES ITS OWNER, AND IT DOES SO BEFORE THE FIRST BLOCK.**
`Loop.Publish.publish_precondition` carries the RESOLVED path, the workstream that owns the
directory (`mev_tax_model_one`, GitHub issues **#24 AND #25**), the sentence that this process will
not create it, and the repair — all in ONE message, because an operator meets this once, on stderr,
next to an exit code. `LoopMain` calls it at STARTUP, exiting **40**, and that is deliberate: a loop
that discovers this on its first EVENT has already advanced a watermark past blocks it could not
publish for. `publish_fixture` keeps its own guard and the suite drives both — a directory removed
mid-run is not a directory that was never there. **Nothing in the module can make a directory and
the property is STRUCTURAL rather than careful:** the `System.Directory` import list carries
`doesDirectoryExist` and `doesFileExist` and no maker, so the branch does not typecheck.

**THE DEFAULT PATH IS NOW PINNED TO THE CONSUMER'S OWN DECLARATION, READ LIVE.**
`git show origin/develop:test/models/mev_tax_model_one/AlgebraIntegralMevTaxModelOneShocks.t.sol`
gives `string constant VOLUME_PATH_JSON = "test/models/mev_tax_model_one/fixtures/volume_path.json"`,
and `Loop.Config.default_fixture_path` is byte-equal to it. 28-03 could only compare the default
against `default_fixture_dir </> fixture_file_name` — a join, which is this side agreeing with itself
and is true for every possible value of both halves. The check is in
`the_upstream_shocklib_pin_is_a_live_trip_wire`'s shape: the ref's resolvability asserted FIRST with
`git fetch origin develop` in the failure and never a skip, the reader shown saying YES and NO, and
the extraction asserted to have found **exactly ONE non-empty literal** before the comparison —
because an extractor that matched nothing agrees with any default this side happens to hold.

**28-CONTEXT'S OUTSTANDING PREREQUISITE IS NOW A VERDICT RATHER THAN A PARAGRAPH.**
`test/models/mev_tax_model_one/fixtures` is absent from THIS worktree and from
`git ls-tree -r --name-only origin/develop`, and
`the_fixtures_directory_is_recorded_absent_from_both_trees` says so in both directions. Its failure
text states what a PASS means (LOOP-04's live half is blocked on the `#24` track landing the
directory, issue #25, and the loop's behaviour there is proven only through `FIXTURE_DIR`) and what
a FAIL means (the directory ARRIVED — re-state LOOP-04 against the real tree at the phase close, and
then **RETIRE** this check rather than weaken it). A paragraph cannot notice the day it stops being
true.

**THE PLAN'S FIRST FIRING INPUT WAS REFUTED, AND DRIVING IT A SECOND WAY CORRECTED A HADDOCK THAT
HAD BEEN WRONG SINCE PHASE 22.** Moving `Driver.Capture.write_atomically`'s temp file to
`getTemporaryDirectory` was predicted to redden arm (e). **DRIVEN: `228/228`, NOT CAUGHT** — the file
is created and RENAMED AWAY, so **a before/after tree diff cannot see where a temp file lived**;
arm (e)'s real subject is a file that SURVIVES outside the directory. Re-driven with the destination
on this repository's `ext4` (device 66306) against `/tmp`'s `tmpfs` (device 50), it reddens through
the FIRST arm: `renameFile:renamePath:rename '/tmp/volume_path.json.tmp' to '…': unsupported
operation (Invalid cross-device link)`. **So `Driver.Capture`'s three-phase-old "silently degrade to
a copy" sentence is FALSE** — POSIX `rename(2)` does not copy, it raises `EXDEV`. The sibling rule is
right and the reason given for it was wrong: the hazard is a write that either works by luck of the
mount table or dies at the last step with the destination still holding the previous document, which
for a resident loop is a HALT and not a tear. Both haddocks now carry the measurement and both
drives; arm (e) is KEPT with its limit written into its own haddock rather than removed or turned
into a 350-second race.

**TWO PLAN ERRORS, BOTH MEASURED.** (1) Task 1's `grep -cE "createDirectory" = 0` is unsatisfiable by
the same task's own prescribed haddock, which the plan requires to say the module creates nothing. It
printed **2**, both prose. **THE PROSE MOVED** — 27-01's rule for the twenty-ninth time on this branch
and the second time in phase 28 — and the replacement is stronger, naming the import list as the
mechanism instead of promising restraint. (2) Task 2's `find test -path "*fixtures*"` "returns
nothing" was FALSE when it was written: `test/pos_spec/fixtures` and `test/gamsDiff/fixtures` predate
this workstream. The real subject is `find test -path "*mev_tax_model_one*"`, and the stronger form —
`doesDirectoryExist default_fixture_dir` — is what the check asserts.

**FIVE DRIVES, EVERY ONE OBSERVED, EVERY BASELINE RESTORED `sha256sum -c` CLEAN.** M1 (`228/228`,
refuted) and M1b (`226/228`, EXDEV) above; M2 (the precondition creates the directory and still
refuses) reddened **the arm that matters and only that arm** — *"after publish_precondition refused
…/fixtures, something IS there: a directory"* — which is the after-state arm earning its place, since
the verdict, the message, the four required contents and the exit code were all still correct under a
function that had already done the forbidden thing. M3 (one character out of `default_fixture_dir`)
was caught by **TWO checks with different diagnoses**, naming both strings. M4
(`mkdir -p test/models/mev_tax_model_one/fixtures`) reddened the worktree arm and rehearsed the day
the prerequisite closes.

**`git status --porcelain test/` IS EMPTY** and `find test -path "*mev_tax_model_one*"` returns
nothing. **FOUR CHECKS COST THE SUITE ONE TO TWO SECONDS** — 28-03's multiply-by-fifteen rule was
applied *before* they were written, and **366 s of headroom against the 900 s ceiling remain for
28-05**, which is roughly 24 seconds of its own work.

**28-03 DISPOSITION — LOOP-03 IS CLOSED, AND THE HEADLINE IS FALSIFIABLE BECAUSE THE CONTROL WAS
OBSERVED (the record).**

`Loop.Publish`, `Driver.Capture.write_bytes_atomically`, `Loop.Config`'s publication
target, `Loop.Run.publish_for` and five checks. **This plan was RESUMED**: the previous executor
was killed mid-Task-1 with six files dirty, `offchain/lib/Loop/Publish.hs` untracked, and the tree
not building (`loop_chain_id` and `fresh_temp_dir` referenced and defined nowhere). Nothing was
discarded; the task split is by concern, and Task 1's commit was verified GREEN at 219/219 by
RUNNING the suite at that state before Task 2 was committed.

**THE RACE, MEASURED ON BOTH ARMS BY INVERTING EACH VERDICT SO THE COUNTERS WERE PRINTED.**
`publish_fixture` (temp sibling + rename): **142,623 publications, 204,555 completed reads, 0
unparseable.** No temp file, no rename, same reader, same two documents, same deadline: **6,079
publications, 1,333,592 completed reads, 1,240,687 unparseable — 93.0%.** Nine reads in ten are
torn the moment the rename is removed. `publication_race` takes the WRITER as a parameter, so the
two arms differ in exactly one expression; both checks order the "did the race actually run" arm
(floor 100 on both counters) FIRST, because a green "no torn read" over a race that did not happen
is a check about nothing.

**THERE IS EXACTLY ONE `renameFile` CALL SITE IN THE TREE.** `write_bytes_atomically` was added as
a GENERALIZATION and both public writers are now `write_atomically`; `grep -rn "renameFile"
offchain/lib offchain/app` prints four lines, of which one is an import and two are haddock
sentences. `Loop.Publish` names no rename (`grep -c` = 0), no `Data.Aeson`, no `Double` and no
`createDirectory`, and there is no aeson anywhere under `offchain/lib/Loop/`.

**THREE OF THE PLAN'S PREDICTIONS WERE REFUTED AND THE HADDOCK WAS CORRECTED, NEVER THE CHECK.**
(1) The 150-byte truncation is `ArtifactUnparseable`, not `BelowShapeFloor` — the plan prescribes
both the decode-first ordering and the floor refusal, and a prefix of the golden stops being JSON
long before it gets small. The floor's real subject is a CONSTRUCTED artifact that decodes and is
still under 200 bytes, whose decode is asserted FIRST. (2) **An aeson `Value` round trip does NOT
lose the `dQx[0]` digits.** Driven: it reddens the BYTE arm (539 against 605) and never reaches the
digit arm; with the byte arm neutered the check came back GREEN, because `Scientific` is
arbitrary-precision and its encoder prints an integral value verbatim. Re-driven through `Double`,
the digit arm reddens exactly as written — so the two arms catch DIFFERENT re-renderers and the
carrier BYTE-04 measured is `Double`, never "a JSON value type" in general. (3) **THE WALL-CLOCK
BUDGET WAS WRONG BY A FACTOR OF SEVENTEEN.** The plan said `173 s → ~195 s` on the arithmetic that
two ten-second harnesses run once each. `sentinel_falsification_harness` re-runs `core_checks`
about fifteen times — once per swept artifact through `all_objections`, once for its own baseline,
and once per negative control through `first_objection`, which cannot short-circuit because their
whole point is that nothing objects. **MEASURED at both ends: 186 s without the races, 528 s with.**
The number is now in `race_window_seconds`'s haddock and in `deferred-items.md`.

**THE TORN CONTROL CANNOT BE WRITTEN IN `System.IO`, AND THE REASON IS THE RUNTIME DEFENDING THE
INVARIANT.** `withBinaryFile ... WriteMode` raises **`resource busy (file is locked)`** — OBSERVED —
because GHC keeps a per-inode lock table and the harness's reader holds the file open. Catching and
retrying would have been wrong twice: the reader's own `readFile` would fail with the same lock
error inside the window, and the harness would count a LOCK failure as a torn read. `System.Posix.IO`
issues the `open()` itself; `unix` is a GHC boot library `process` already depends on, `+0 packages`
MEASURED. The same fact is why the atomic writer is unaffected — a SIBLING is a different inode and
`rename()` opens nothing.

**THE INSTRUMENT HAD TWO FAILURE MODES OF ITS OWN AND BOTH WERE OBSERVED BEFORE THEY WERE FIXED.**
`fresh_temp_dir` cleared a shared per-label directory and raised `removeContentsRecursive:
Directory not empty`, and on another run left the publisher writing into a directory that had just
been removed. **The cost of not fixing it was measured:** the flaky check entered the sweep's reader
sets and the suite ran **2328 s** instead of 528, and the harness's own NEGATIVE CONTROL went red
(*"the sweep reported it CAUGHT by a_reader_racing_the_publisher_sees_no_torn_fixture"*) — the
harness correctly refusing to believe a flaky check. Each directory now carries a
`getMonotonicTimeNSec` suffix. A publication that threw also escaped to `guarded` as an anonymous
IO error; `race_write_fails` is now an ordered arm and the cache-hit check reads through
`read_if_present`.

**FIVE FIRING INPUTS, EVERY ONE OBSERVED, EVERY BASELINE RESTORED `sha256sum -c` CLEAN.** M1
(publisher → torn writer) reddened check 1 at *"1223305 bad read(s) out of 1326222 completed, across
5953 publications"* **and left the control GREEN**, which is the pair working. M2 (fold the
zero-pool arm) named the zero arm. M3 (re-render through `Double`) reddened the digit arm **and
three independent structural guards** — the aeson scan, the artifact-path `Double` scan and the fee-path
scan. M4 (skip publication on `OutcomeElided`) reddened at *"THE CACHE HIT DID NOT PUBLISH"*. M5
(`fixture_min_bytes = 700`, above the 606-byte golden) reddened **six**, including
`every_advertised_override_is_honoured` — with the floor above every artifact the publisher refuses
on the FLOOR before it reaches the directory check, so the `FIXTURE_DIR` probe's failure stops
naming the resolved path, which is that probe's third assertion earning its place.

**`git status --porcelain test/` IS EMPTY AFTER EVERY RUN.** Every publication check runs against a
temporary directory; `Loop.Config.default_fixture_dir` — the `mev_tax_model_one` track's — was never
created, and `Loop.Publish` cannot create it.

**28-02 DISPOSITION — LOOP-01 IS CLOSED AND S1 IS CLOSED IN THE LIBRARY.** `Gams.Detect`,
`Loop.Config`, `Loop.Poll`, `Loop.Chain`, `Loop.Run`, `offchain/app/LoopMain.hs`, the
`executable loop` stanza and eight checks. All three spike seams — S1, S2, S3 — are now closed.

**LOOP-01 IS PROVEN THE ONLY WAY IT CAN BE, AND ITS "BLOCKED" ATTRIBUTION WAS INHERITED RATHER
THAN MEASURED** — the third time on this branch after CHAIN-02/03. The watermark is a ROW IN THE
STORE and `run_loop` re-reads it from the ledger on every pass, so nothing in-process can report
a restart-safe watermark while holding an in-process one.
`a_restart_resumes_at_the_watermark_and_skips_nothing` drains a head of 5, then — WITH NO LOOP
RUNNING — adds events at blocks 6 and 7 and raises the head to 8, then builds a **second `Env`
over the same store and ledger**, which is what a restart is here. It asserts the down-time
events EXIST in the source FIRST (an empty second window satisfies "nothing was skipped" for a
loop that skipped everything), then that the down-time rows landed, the watermark reads 8, and
the EARLY events did **not** gain a second row — which is the arm that tells resuming apart from
starting over, because a loop that re-scans from the beginning also lands the down-time rows.
**FIRING INPUT OBSERVED:** `next_range` starting from the head when a watermark is present →
216/219, *"THE EVENTS THAT OCCURRED WHILE THE LOOP WAS DOWN WERE SKIPPED. Row counts [0,0] for
the events at blocks [6,7]"*. Ranges are CLOSED `[b, b]`, asserted on the CALLS the iteration
made rather than on the function that computes them, and a quiet block still advances the
watermark. The LIVE poll is still unexercised — CHAIN-01, issue #26 — and that is recorded in
LOOP-01's traceability row rather than left to be discovered.

**S1: "VERSION-ONLY" MEANS NO PRODUCTION MODEL AND NO PRODUCTION SOLVE, NOT NO PROCESS.** Both
halves are MEASURED and already committed: `gams --version` is parsed as a FILENAME, exits 6, and
its banner is refused `Left (WrongJob "--version")` by the very parser `Gams.Detect` reuses
(`gams-conformance.json` `version_flag/parser_verdict`); and CONOPT states its own version only
in the output of a run that reaches the solver (`conopt_method`). So the probe SOLVES a five-line
hermetic NLP in a directory it makes and removes, and the production model is DIGESTED and never
run. `ti_model_sources` carries the PRODUCTION digest and never the probe's — a probe that leaked
into the identity would key every stored row to a throwaway file. Both negative controls are the
toolchain's own committed banner lines, the positive control is the same line with ONLY the job
field replaced (asserted to differ in that field ALONE, index 2 and no other), and
`git diff offchain/test/Main.hs | grep -cE "54\.1\.0|4\.39\.0|37378ce0"` prints **0**.

**THE EXIT TABLE IS COMPLETE ON DAY ONE, AND `Loop/Config.hs` STATES NONE OF THE COLLIDING
NUMERALS.** Nine non-zero entries including 28-03/04/05's conditions, because a table that grows
one code per plan is a table nothing can assert is TOTAL. The disjointness is asserted in the
suite against `Gams.Exit.gams_code_domain` itself rather than against a transcription of it, so
it follows a change to the prover's table. Task 2's acceptance criterion
(`grep -cE "\b(11|124|137|145)\b"` = 0) is unsatisfiable by the same task's own prescribed
prose; the PROSE MOVED, 27-01's rule for the twenty-eighth time.

**TWO CENSUS FINDINGS, BOTH OBSERVED RED FIRST.** (1) `sc3_literal_purge` named
`offchain/lib/Loop/Run.hs:268` for the `0xffffffff` mask in `split_seed` — an eight-hex literal
reads as a selector, and `Word32`'s own `fromInteger` IS the modular reduction, so the literal
was never necessary. (2) `every_endpoint_site_resolves_rather_than_hardcodes` named
`offchain/lib/Loop/Chain.hs`: a `HaskellConsumer` must obtain the authority from the resolver on
a **code line**, and `web3_chain_source` takes it as an argument. The repair is
`resolved_chain_source`, which resolves once and returns the endpoint ALONGSIDE the source, so
nothing resolves twice and the caller reports the authority it actually used.
`offchain/app/LoopMain.hs` is **not** an endpoint site — it matches no census term — so the
manifest went to **nineteen**, and its haddock had said "Fifteen entries" while holding eighteen.

**`LOOP_POLL_MS` NEEDED A THIRD OVERRIDE SHAPE.** `probe_override` asserts a bogus PATH comes
back verbatim, which is meaningless for a resolver that returns a number; `unprobed_overrides` is
the gap list for a variable whose CONSUMER is unreachable from `cabal test`, and this one's is a
pure library function called by two checks. Pardoning it would be an ignore list covering
something fully measurable. `value_overrides` transposes the three assertions instead — a
distinctive value honoured, the default when absent, and a bogus value REFUSED with a message
that NAMES it — and is folded into `every_advertised_override_is_honoured` so the total stays at
`BASE_2 + 8`.

**FIVE FIRING INPUTS IN TASK 3 PLUS ONE IN TASK 1, EVERY ONE OBSERVED, EVERY BASELINE RESTORED
`sha256sum -c` CLEAN. TWO WERE CAUGHT BY A SECOND, INDEPENDENT GUARD:** M3 (advance the watermark
only on event blocks) reddened the quiet-stretch check at *"reads Just 9, expected Just 12"* AND
the restart check at *"after the first pass over a head of 5 the watermark reads Just 4"*; M6 (an
unreadable poll value falling back to the default) reddened its own check AND
`every_advertised_override_is_honoured`, from the sweep side — which is the value-override probe
earning its place rather than restating the dedicated one.

**28-01 DISPOSITION — SPIKE SEAMS S2 AND S3 ARE CLOSED IN THE LIBRARY.** `Loop.Solve`,
`Loop.Ledger`, migration `004_loop_ledger.sql`, a re-taken `store-conformance.json` and six
checks. **LOOP-02 is NOT closed by 28-01** — its two directions are asserted against the
reference implementations through a pipeline the suite composes, and the requirement is stated
over the loop, which 28-02 wrote; the loop-level assertion is still owed. Phase 27's record
continues below, unchanged.

**S2 IS ANSWERED BY MOVING RESOLUTION OUT, NOT BY WIDENING `AbortReason`.** The constructor
meaning "the binary or the model could not be resolved" was deliberately NOT added and
`Loop.Solve` deliberately does not import the resolving module (`grep -c` = 0). An
`AbortReason` is written into a ledger row and read by a post-mortem; "the model file was not
where the process expected it" recorded under the same discriminator as "CONOPT could not reach
an admissible point" is exactly the conflation S3 exists to prevent, arriving from the other
end. Resolution is a STARTUP precondition of the caller.

**S3 IS NARROWER THAN 27-SUMMARY STATES, AND IT WAS MEASURED.** The spike recorded that a caller
of `decide` cannot tell an inadmissible shock from an unsolvable one, because `NotPersisted`
drops the streams and the abort line (109 = ellipse refusal vs 171/173 = CONOPT) lives only in a
deleted run directory. True of the ABORT PATH, and not the whole picture: `render_argv`'s NINTH
refusal is applied before any argv exists, `content_key` inherits it, and `decide` returns
`Left (Inadmissible …)` **before the solver is reachable** — so the two failures 28-CONTEXT gives
OPPOSITE policies to are already two different constructors of `Either ArgvError Decision`. The
solver handed to `decide` in the check **throws if it is called**, and it was not called; the
witness is DERIVED (one pip below `min_admissible_dstar` for the fixture's own pair) with both
sides of the boundary asserted first. The abort-line discriminator is still needed by exactly one
consumer: the capture that drives the eight-refusal renderer on purpose.

**M1 REFUTED THE PLAN'S OWN PREDICTION, AND THAT IS THE FINDING.** The plan said removing the
`ledger_seen` guard would redden the invocation arm **at 2**. It does not. The counter stays at 1
and the row count stays at 1, because the CONTENT KEY still hits on the replay and the ledger's
first-writer rule still holds; only the do-nothing arm fires (209/211,
`decided Just OutcomeElided`). So `ledger_seen` does **not** save a solve — the key already does.
It saves the store lookup and the write attempt, and what it protects is the pipeline doing
NOTHING on a replay. The haddock now records the measurement instead of the prediction. **27-03's
M4 shape arriving again:** the arm the plan aimed at stayed green and a different one caught the
defect, with a different diagnosis.

**TWO MUTATIONS WERE CAUGHT BY A SECOND, INDEPENDENT GUARD.** M2 (key the ledger on the content
key) reddened the row-count arm at *"1 row(s) for the first event and 0 for the second"* AND the
positive control of the commit check, which sees the same collapse from the commit side. M5
(delete the unique clause from `004`) reddened the DDL check AND
`store_conformance_is_present_and_fresh`, because editing a migration moves its digest — one says
the guarantee is gone, the other says the recorded evidence no longer describes the schema it was
measured against.

**DOCKER BEFORE THE MIGRATION, AND THE CAPTURE RE-TAKEN.** `docker info` exit 0, Server Version
29.5.2, verified BEFORE `004` was written — because adding it turns the freshness oracle red and
an executor who finds that out with no server is one step from weakening the check. The capture
was re-taken (`server_version 18.4`, `postgres:18-alpine`, `sc_complete true`, 8/8 laws,
`generatedAt 2026-08-22T23:02:43Z`, `004_loop_ledger.sql` at md5 `ab6f60d9…d703b5`, which
`md5sum` recomputes). And the staleness instrument was OBSERVED firing first: with the pre-004
capture restored, **203/205**, *"the repo has a migration the capture never saw"*, then restored
under `sha256sum -c`.

**THE WATERMARK'S TWO GUARDS ARE BOTH LOAD-BEARING.** `primary key (only_row)` is what the
upsert's conflict target names; `check (only_row)` is what forbids a SECOND row carrying `false`,
which the primary key alone would happily admit and which would give the table two rows, one of
them a watermark nothing reads. `ledger_commit_block` takes the block AND its rows, so LOOP-05 is
a property of the SIGNATURE rather than a rule about call order.

**THE REFERENCE LEDGER REFUSES WHAT THE SERVER REFUSES.** 23-04's ruling repeated: the memory
implementation applies migration 004's row CHECKs and RAISES, before it mutates anything, over
ONE `IORef` carrying both the rows and the watermark — two refs cannot make a half-applied commit
unrepresentable, because one of them is already updated when the other fails.

**TWO PLAN ERRORS, BOTH MEASURED.** (1) Task 2's acceptance asks `grep -c` to print 1 for each of
the four outcome tokens; `'inadmissible'` prints **2** and both occurrences are in the DDL the
plan itself prescribes, because `loop_event_keyed_unless_inadmissible` names it a second time.
The stronger form was checked instead. (2) Task 2's verify command reads `m['name']` out of
`store-conformance.json`; the capture writes `filename`, and the suite reads `filename` too.

**`new_postgres_ledger` HAS NO IN-SUITE SUBJECT**, and that is recorded rather than left to be
discovered: `cabal test` is server-free by construction (DB-03), the in-suite subject is the
memory implementation, and the structural arm asserts only that the file names
`withTransaction`. A Tier-C capture driving it belongs with 28-02's.

**Phase 28 context gathered (2026-08-22):**
`.planning/phases/28-resident-loop-fixture-publication/28-CONTEXT.md`. Phase 27 verified
`passed` (10/10, `27-VERIFICATION.md`, commit `b376399`). **S1 DECIDED:** a `detect_toolchain`
version-only probe in the library, pinned for the process lifetime; **user ruling on drift: adopt
the new identity and continue** (logged, ledger-reconstructible), not halt. LOOP-02's
"run-log rows" are satisfied by a **minimal per-event ledger** (unique `(tx_hash, log_index)`,
every outcome recorded) while STORE-07's append-only enforcement stays deferred; watermark is a
dedicated single-row table advanced in the same transaction. Failure policy: skip inadmissible,
halt on unsolvable (watermark not advanced), retry-then-halt on RPC. Modes: resident + `--once`,
1 s `eth_blockNumber` poll, one JSON line per block, fixed exit-code table. **TWO PREREQUISITES
before `/gsd:plan-phase 28`:** (1) the `#24` track must land
`test/models/mev_tax_model_one/fixtures/` on develop — requested on issue #25; (2) CHAIN-01 stays
BLOCKED on #26, so LOOP-01..05 are to be proven chain-free with a Tier-C capture gated as in 27.
NOTE: `gsd-tools phase complete 27` was run at phase close and REVERTED — it rewrote this file's
frontmatter to `milestone: v2.0` (fourth subcommand observed doing so).

**PHASE 27 DISPOSITION.** CHAIN-02, CHAIN-03 (27-02), CHAIN-05 (27-03), CHAIN-06, CHAIN-07 (27-01)
shipped; CHAIN-04 was already done at 26-02; **CHAIN-01 is BLOCKED**. Suite **194 → 205** across the
phase. CHAIN-02 and CHAIN-03 were carried in marked *Blocked* and **were never blocked** — that was
inherited from CHAIN-01's row rather than measured, and a pinned read needs only a POOL.

**CHAIN-01 — BLOCKED, BY NAME, WITH ITS DEPENDENCY.** Plank / mev-migrate workstream, issue #26,
`SELECTOR_NEXT 0xd3827b0b`. There is no deploy script for the Shock writer —
`foundry-scripts/mev_tax_model_one/` holds only `DeployAlgebraFactory.s.sol` — and the event is
emitted from a forge **test**, not from a deployable contract another process can drive. **Not this
workstream's to build.** WHAT WOULD DISCHARGE IT: one driver that emits a single `Shock` in a MINED
transaction on the resolved endpoint. Everything on this side is ready: `Chain.Shock` decodes it
(CHAIN-04, 12 checks, 21-member corpus), `Chain.Read` pins the reads to its block, `Chain.Endpoint`
resolves the endpoint it would be pointed at, and CHAIN-05's fixture already carries the identity
slot the decoded pool goes into.

**TWO REQUIREMENT TEXTS CORRECTED AT CLOSE, neither by changing a status.** CHAIN-01 said *"the
`next` event"* and `next(address,uint160,int24,uint24,uint24)` is a FUNCTION SELECTOR
(`0xd3827b0b`), never an event — the event is `Shock(address indexed pool, int24, uint24, uint24)`,
topic0 `0x21b0e4f8…55987d64`. CHAIN-06 said *"Nine sites, one rule"* and the count was wrong three
ways: TEN by its own pattern, ELEVEN counting `verify-rig.sh` (invisible to any pattern built from
those two tokens, because it reached the chain through foundry's alias), and the rule was
implemented **ZERO** times. The durable form is `endpoint_sites`, checked in both directions, **18**
entries.

**THE FIXTURE SAYS WHICH POOL, AND THE STRING IS A MEASUREMENT.** `pool` (string address),
`blockNumber` (**STRING**) and `chainId` (number) — issue #29's returned contract, plank `f713089`.
`token0`/`token1` deliberately ABSENT: the consuming test reads them from the pool, so the pool
stays the single source of truth. OBSERVED, not asserted: `9007199254740993` through a JSON number
decoded into the 53-bit carrier comes back `9007199254740992`, short by **exactly 1**, equal to
BYTE-04's own `double_image` of that integer. **AND THE FINDING BESIDE IT:** the suite's own JSON
value type carries that number EXACTLY, so the hazard is invisible from inside this suite — the loss
belongs to the CONSUMER'S carrier, not to the JSON text, which is precisely why publishing a string
is the remedy. Asserting only the exact path would have been reassuring and wrong.

**NONE OF THE SUBJECT IS SPELLED IN THE CHECK.** The pool is `se_pool` of a corpus member decoded by
`decode_shock`; the height and chain id are `block_b` and `chainId` out of the COMMITTED capture,
which is what "the identity it was SOLVED FOR" means. Only the three CONTRACT KEY NAMES are written
by hand, and deliberately: they are external, so a key set derived from the producer would be the
producer agreeing with itself. **The pool is SYNTHETIC and labelled so** — CHAIN-01's emitter is
blocked, the rig is a v4 pool with a 32-byte `poolId` and no Algebra pool ADDRESS, and recording the
manager's address under the key `pool` would have been a recorded measurement that is FALSE.

**M4 WAS NOT PREDICTED, AND IT IS THE FINDING.** The plan's third firing input exists to show the
ordering guard is load-bearing. M3 showed it fires. M4 asked the harder question — with that arm
REMOVED and the witness still below the ceiling, does the rest go green? **It does not:** the check
still reddens, through a DIFFERENT arm ("came back UNCHANGED"). So there are two independent guards
against a vacuous subject and they give **different diagnoses** — the ordering arm says the WITNESS
was chosen wrong, the inequality arm says the CARRIER stopped losing it, and only the first is true.
26-03's existence-versus-order finding, arriving from a direction nobody aimed at.

**M2 IS WHY THE SHAPE ARM AND THE ZERO ARM ARE SEPARATE.** The zero address is shape-VALID — `0x`
plus forty lowercase hex digits, every guard satisfied — so folded into one arm the zero arm would
be unreachable. Measured: M2 fired the zero arm ALONE while the shape arm stayed green.

**S1 BINDS PHASE 28 AND MUST BE DECIDED BEFORE IT PLANS ITS LOOP.** From
`.planning/SPIKE-end-to-end.md`: a `KeyIdentity` can only be obtained from a COMPLETED RUN
(`key_identity` needs a `ToolchainIdentity` whose only producer is `run_prover`'s `Produced` arm,
yet `decide` needs the identity BEFORE the first solve, and there is no `detect_toolchain`), so the
loop bootstraps with a throwaway solve or the library grows a detection function. **S2:**
`invoke_shock` does not fit the `Solver` seam and `AbortReason` has no constructor for a resolution
failure, so the composition function phase 28 will reach for first is the wrong one. **S3:**
`Decision` drops `CapturedStreams`, so a caller cannot tell an inadmissible shock (abort line 109)
from an unsolvable one (171/173) — which touches CHAIN-03's spirit directly.

### 27-02, still standing (the record)

**THE PIN IS A TYPE, NOT A CONVENTION.** `BlockRef` is a `newtype` with one constructor, so the
moving-head tag is not something the read layer avoids — it is something the type cannot express,
and re-opening the question means changing `newtype` to `data`, a diff nobody writes by accident.
Every read takes it as a required positional argument. `latest_appears_nowhere_in_the_read_layer`
then closes the corridor the type leaves open (a string handed to the transport, a second import),
with a positive control that greps a SEEDED COPY of the read layer beside a CLEAN copy of it.

**CHAIN-03 IS A PURE TOTAL FUNCTION**, drivable at arguments a local anvil will not produce on
demand: twelve refusals across five diagnoses (negative height, absent answer, four unparseable
shapes, an ALL-ZERO WORD, a decoded zero) and four acceptances, because a rule that refuses
everything passes a refusal table. `lpFee` is NOT zero-refused, and that is a measurement: a
dynamic-fee pool stores it as zero at initialise, so a blanket rule would refuse the rig's own
genesis state on every call.

**THE DECOY HAD TO BE BUILT BY THE FUNCTION UNDER TEST.** The naming arm's control was hand-spelled
first, and the mutation that drops the delimiters from `refusal_naming_of` MEASURED **201/201,
exit 0, NOT CAUGHT** — the hand-spelled decoy kept *its* quotes while the producer lost them, so the
two strings stopped being able to collide and the arm that exists to observe the collision passed by
construction. Routed through the producer, the same mutation fires at 199/201.

**anvil_setStorageAt DOES NOT CREATE A BLOCK.** The first capture recorded
`pinned_equals_block_b = false` and looked exactly like CHAIN-02's defect. Driven with `cast`
independently: the cheat writes into the state OF THE CURRENT HEAD, so pinning at the head pins to
the block the cheat is about to occupy. The pin was never broken — the same run reads block 0 and
gets the bare `0x` marker, which it could only do if the block parameter were reaching the node.
Fixed with one `evm_mine` BEFORE the write; `write_landed_above_b` is now a recorded and asserted
field so the construction can never again be mistaken for the defect. **This binds anything else
that constructs a historical divergence on this rig.**

**A CLAIM THIS PLAN HAD ALREADY COMMITTED WAS WRONG.** `measured_pre_pool_block` moves **5 → 7**.
Walking every height of a from-scratch rig: blocks 0–5 the PoolManager has NO CODE and the call
returns the bare `0x` marker; blocks 6–7 it has code and the pool is uninitialised, returning an
ALL-ZERO WORD; block 8 the pool is live at tick 0; block 13 tick −1 after the probe swap. Those are
two different diagnoses and the earlier draft merged them.

**cabal test STILL OPENS NO SOCKET**, now asserted by a **third** structural grep beside the DB-free
and GAMS-free ones. Its tokens are not equally load-bearing and that was measured: `web3-ethereum`
IS a test dependency so the JSON-RPC method module can be imported today and only the scan stops it
(the firing input compiled and was caught); `web3-provider` is NOT, so that import does not build at
all and its firing input had to be a comment.

### 27-01, still standing (the record, and it caught this plan twice)

**ONE RESOLVER, IN TWO LANGUAGES, WITH THE TWO STATEMENTS ASSERTED BYTE-EQUAL.**
`Chain.Endpoint` states `ETH_RPC_URL` and the default authority once for the Haskell tree;
`offchain/rig/endpoint.sh` states the default once for the three bash sites and splits it into
`RPC_URL` / `RPC_HOST` / `RPC_PORT`. `bash` cannot import a Haskell module, so the value exists
twice by necessity and `the_producer_and_the_consumers_bind_one_endpoint` compares them — the move
`Fee.Split` and `Store.Key` already make for the pip denominator.

**WHAT CHAIN-06 DESCRIBES IS NOT WHAT WAS THERE.** It reads as though nine sites each implement the
rule and might drift. MEASURED: the rule was implemented **ZERO** times — the only occurrence of the
variable under `offchain/` was a COMMENT in `deploy-rig.sh` saying the deploy scripts scrub it.

**THREE PLAN ERRORS, EACH FOUND BY MEASUREMENT.** (1) `offchain/rig/verify-rig.sh` is an **ELEVENTH
site** that CHAIN-06's list of nine does not contain: fourteen `cast` calls against a live rig,
reached through foundry's `--rpc-url local` alias, so it named neither token and no pattern built
from them could see it. (2) The plan's census pattern would have reported the fix as a regression —
it found 10 before the rewiring and **8 after**, because five of the six Haskell consumers stop
naming either token the moment they name the resolver. (3) `"cast call"` matched
`CheatSwap/Encoding.hs`'s `cast calldata`: the 26-03 longer-wrong-value shape, and
`offchain/rig/README.md`'s hand-run grep still carries it.

**A CHECK OF MINE WAS VACUOUS AND ITS OWN MUTATION PROVED IT.**
`an_empty_eth_rpc_url_does_not_resolve_to_the_empty_string`, written against the environment,
MEASURED GREEN against a deliberately unguarded resolver. `System.Environment.setEnv k ""` routes an
empty value to `unsetEnv`, so it was driving the UNSET path twice — the passes-because-the-subject-is-
absent defect, inside the guard against it. Repaired by factoring the rule into the pure
`endpoint_from`, with the empty export's reachability OBSERVED in a child shell.

**FEE-02 IS PROVEN AGAINST THE REAL PROVER, AND THE DISCRIMINATOR IS NOT THE EXIT CODE.**
`Fee.Split.is_admissible` and `volume_path.gms`'s own `ellTest` gate agree on twelve points that
bracket four exact boundaries — 82804 / 109769 / 300361 / 495953 — by one pip on each side.
**All twelve rows exit 3.** What separates the four the prover REFUSES from the eight it merely
cannot solve is the model's own SOURCE LINE: **109 is the half-ellipse refusal; 171 and 173 are
CONOPT failing to reach an ADMISSIBLE point**, which is `admissible-but-unsolved` and never a
disagreement. `gams_admits = (abort_line /= 109)`, pinned in the capture, in the shell gate and in
three in-suite arms. Gates: `DISAGREE=0`, `VERDICTS=2`, `BADCTL=0`, `complete=true`, and four rows
refused at line 109. GAMS 54.1.0 / CONOPT 4.39.0, model `79940449…ca53ad`, sixteen invocations in
**846 ms** (a solve is 35 ms; the sweep doc's "~2 s per run" was its own script's overhead).

**RC-B1 CLOSED.** The 160-run sweep left `(1000, 3000)` open because its grid stepped
300000 → 400000. Re-swept at ten points here: last ELLIPSE **300360**, first non-ellipse
**300361**, and `min_admissible_dstar 1000 3000 == Just 300361`. **All four pairs now agree with
the prover at the boundary exactly.** The controls are the sweep's MEASURED solvable targets —
490000 (ROADMAP SC-2's own 0.49) for three pairs and 497000 for `(700, 800)` — not the plan's
parabola vertices, three of which abort.

**RC-B2 CLOSED, by a DIFFERENT derivation than the finding proposed.** Its
`(gams_exit == 0 && gams_artifact_present)` is measured FALSE here — `gams_artifact_present` is
false on all twelve rows and eight of them are admissible. Its own falsifying input (every
`gams_exit` set to 0, `gams_admits` untouched) was RUN and reddens naming **all twelve rows**, on an
arm that ties the exit to the line and requires the line to be in the model's known abort taxonomy.

Suite **190/190 → 194/194**, exit 0, zero warnings, wall **173 s** against a 900 s ceiling. Phase
arithmetic `162 + 32 = 194` (the plan says 31; the extra one is 26-02's own recorded twelfth check).
Seventh swept artifact; all seven field floors named by the harness in ONE run
(20 / 110 / 151 / 130 / 156 / 76 / **125**) and **none of the six moved** — including
`store-conformance.json`, which `26-VALIDATION.md` predicted phase 25 would grow by ~22 and which
did not grow at all. `sentinel_pair_floor` **3828 → 4574**, the four identity skips NAMED. Floors
re-measured COLD as a pair: `purge_file_floor` **67**, `credential_scan_floor` **77**. Four guards,
**thirteen firings observed**, every one restored from a sha256-verified copy. Both structural greps
**0**. Territory clean.

**FEE-01's text is corrected in BOTH documents.** `REQUIREMENTS.md` and `PROJECT.md` claimed the
composition is exact; it is not. Exactness needs `10⁶ ∣ φ_X·φ_M`, true for **4.935 %** of
`f ∈ [1, 20000]` (987 of 20000, recomputed today) and for **none** of 100 / 500 / 3000 / 10000 pips.
`split_for 0 3000 490000` gives `(752, 2250)` composing to **3000.308** pips. Both now say
round-and-report, with the measured numbers. `ROADMAP.md` was not edited.

**CARRY-FORWARD (replacing "phase 26 owes phase 25 nothing else").** `fs_seed` and
`fs_splitter_version` exist and are asserted by check 18, and all twelve `FeeSplit` fields are read
by a check — but `splitter_version` has **no consumer**: phase 25 ran first and imports nothing from
`Fee.Split`. Wiring it into the content key is non-destructive via `key_scheme` — RC-M5's anchor
**ROADMAP:1288-1289**, whose sentence has since drifted to **ROADMAP:1304-1305** — and belongs to
whoever next touches `Store.Key`. SC-1's store half is likewise still open.

**AN INADMISSIBLE SHOCK HAS NO ARGV AT ALL, AND THE PROCESS WAS OBSERVED NOT STARTING.**
`volume_path.gms:100-108`'s own `ellTest` is `render_argv`'s **ninth** refusal, in exact `Integer`
arithmetic, evaluated AFTER `distinct_fees`. `Gams.Run.run_prover` hands the `Left` to
`refused_before_spawn`, so there is no argv for `spawn_into` to receive — and a `/bin/sh` stub whose
whole body touches a marker was driven through the real edge to say so from the filesystem rather
than from the case expression: POSITIVE CONTROL first at `txlVolumeRate = 82804` (marker present,
`cs_run_dir` non-empty), then the subject at `82803` — marker ABSENT,
`Aborted (ArgvRejected (Inadmissible 500 6000 82803 …)) 0`, and **`cs_run_dir == ""`**, which says
more than "no marker". Suite **181/181 → 190/190**, exit 0, zero warnings, wall **158 s** against a
900 s ceiling. Floors re-measured COLD as a pair: `purge_file_floor` **64**, `credential_scan_floor`
**73** — UNCHANGED, this plan creates no file. Nine guards, **ten firings observed**, every one
restored from a sha256-verified copy. Both structural greps **0**. Territory clean.

**BLOCKER B1 IS CLOSED.** `split_for` tests `fee_in_domain f` BEFORE `admissible_band`, because that
enumeration reaches `x = 1000000` for every `f > 1000000` and `nearest_partner` divides by zero
there — an exception no `Either` can carry. Asserted as a value:
`split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)`, and 8388608 is v4's
`DYNAMIC_FEE_FLAG` in `PoolKey.fee`, not a fee of 8388608 pips. **The finding's ordering clause
cannot bite:** step 0 tests the POOL fee and says nothing about the legs, which `split_for` DERIVES;
an in-domain `(3000, 3000)` shock is still `FieldOutOfRange "phiXpips"` citing §1.2. **26-01's
boundary disagreement is CARRIED, not resolved:** v4's `isValid` admits `f = 1000000` and the
splitter does not, and the domain was NOT widened to match.

**THE ORDERING GUARANTEE IS NOW BEHAVIOURAL, AND ITS LINE-NUMBER HALF EXPIRES AT 26-04.**
`distinct_fees` is at `Gams/Argv.hs:206` and `admissible_pair` at `:207` today. Deleting
`distinct_fees` was OBSERVED leaving the refusal INTACT as
`Inadmissible 6000 6000 490000 18944769600000000000000000000 Nothing` — the count unchanged, §1.2's
diagnosis gone — while `equal_fees_are_refused_in_haskell_with_the_1_2_diagnosis` reddened naming
the constructor. **That constructor arm is what 26-04's `render_argv_ungated` split must leave
standing**; the composition must be `render_argv_ungated >>= then admissible_pair`, never the
inverse.

**RC-M6 IS CONFIRMED AT 2, AND BOTH DOCUMENTS ARE CORRECTED.**
`admissible_band 3000 1000 == [(1,2999),(2,2998)]`, size **2** — measured independently and again by
the check's own failure text. The **4** in `26-03-PLAN.md:178` and `26-VALIDATION.md:232` is the
count of BOTH orientations; `admissible_band` keeps only `m > x`. The EMPTY input is
`delta* = 200`, the SINGLETON is `delta* = 500` (`[(1,2999)]`, `fs_band_size == 1`), and both are
now asserted BY VALUE.

**`gams-conformance.json` HAD TO BE RE-TAKEN, AND NO PLAN OF THIS PHASE SAYS SO.**
`gams_freshness_subjects` is `["offchain/lib/Gams/Argv.hs", "offchain/lib/Gams/Artifact.hs"]` and the
oracle recomputes both digests from disk, so touching the renderer reddens it. It was re-driven
against the REAL GAMS 54.1 (`CFMM_REQUIRE_GAMS=1`, `GAMS_BIN=/usr/gams/gams54.1_…/gams`,
`GAMS_MODEL=…/cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms`), exit 0, **9/9 verdicts pass**.
The whole diff is `argv_module_sha256` and two banner timestamps: **with the ninth refusal installed
the golden artifact still reproduces at `e7b14f38..07d0d884`.** **26-04 must re-take it too** — its
`render_argv_ungated` split necessarily edits that file.

**FOUR PLAN DEFECTS, EACH WITH THE MEASUREMENT THAT FOUND IT.** (1) `ResidualTooLarge`'s arguments
are specified as `(x, m, f, r)` and 26-01 shipped `(f, x, m, r)` — four `Integer`s, nothing would
have type-checked differently and the message would have named the fee as a leg. (2) The plan's
step 1 and step 2 are the SAME test, because `pick_from_band` is `Nothing` exactly when the band is
empty; merged, so no branch needs a message for a state that cannot exist. (3) Check 16's stated
firing input — "move the ninth refusal after the token list" — is a NO-OP in an `Either` do-block;
the only mutation that produces an argv is one that takes the gate off the rendering path. (4) The
`BADDEPS` collision RC-B3 warns about does NOT bite this gate: it scans `Fee/Split.hs` only, which
has no `sqrtPriceX96`, and the unanchored pattern prints 0 there too. It DOES bite
`no_floating_value_is_on_the_fee_path`, which 26-01 already anchored.

**RC-m11 IS CLOSED.** All twelve `FeeSplit` fields are now read by a check; `fs_ellipse_e` and
`fs_boundary_pips` are asserted against `Fee.Split` recomputed at the split's own pair and target.
A sixth `SplitRefusal` constructor, `NoBoundaryForAnAdmissiblePair`, carries RC-M4's impossible
`Nothing` as a named refusal rather than a `fromMaybe` default.

**CHAIN-04 IS COMPLETE. `Chain.Shock` DECODES AN EVENT WHOSE EVERY PRODUCTION LOG IS TWO-THIRDS
ZERO.** 259 lines, six imports, +0 packages, no IO, no hexadecimal literal, `Either` with ten named
refusals: arity, topic0, EMITTER, address shape, zero pool, exact-96 length, the zero shock, and
three per-word ranges. Suite **169/169 → 181/181**, exit 0, zero warnings, wall **176 s** against a
900 s ceiling. Floors re-measured COLD as a pair with the module on disk: `purge_file_floor`
**63 → 64**, `credential_scan_floor` **72 → 73**, zero slack, census `hs 52, sh 9, json 9, sql 3`.
Twelve guards, **seventeen firings observed**, every one restored from a sha256-verified copy. Both
structural greps **0**. Territory clean; `develop` never merged and `ShockLib.plk`, `Shock.plk` and
`ShockRoundTrip.t.sol` were read with `git show origin/develop:…` and cited, never edited.

**RC-M3'S JUSTIFICATION FOR THE `ZeroShock` RENAME IS FALSE, AND THE CONSEQUENCE INVERTS IT.** The
finding says *"`render_argv`'s ninth refusal already kills `txlVolumeRate = 0` for free"*. MEASURED
at `Gams/Argv.hs:137`: the bound is `in_range "txlVolumeRate" value 0 999999` — **lower bound 0** —
and `render_argv` has **eight** refusals, not nine. A zero rate renders cleanly and reaches the
prover, which cannot answer it (`E(x, m, 0) = D⁴xm > 0`, asserted against the shipped
`ellipse_test`). So the `ZeroShock` **consumer rule is load-bearing**: Phase 27 must SKIP the
period, and it is the only thing between a quiet period and a solve that must abort. The first
draft of check 4 asserted the finding and went red, which is how this was caught.

**AN EVENT TOPIC IS UNAUTHENTICATED, AND THE DECODER NOW SAYS SO WITH A GUARD (RC-M4).**
`decode_shock` takes `expected_emitter` alongside `expected_topic0` and refuses `WrongEmitter`.
`synthetic_log` hardcodes one address for every log it builds, so no phase-26 check could observe
emitter discrimination even in principle until a `shock_log_from` helper and a `wrong-emitter`
corpus member existed. **STILL OPEN and Phase 27's to discharge:** `ShockEvent` carries no block,
log index or transaction, so a batch decode must keep the `Change` beside the event or two blocks
mix silently. The obligation is haddocked in the module's MUST-NOT-BE-TRUSTED-ON paragraph.

**THE DATA LAYOUT NOW HAS AN INDEPENDENT ORACLE (M2 / RC-M7).** The corpus and the decoder shared
one belief about word order and padding, so a shared misreading passed every check and the headline
claim was a tautology. `cast abi-encode "f(int24,uint24,uint24)" -- -200 490000 7` is pinned as 192
bare hex characters and compared to the `negative-tick-and-decay` member's `changeData`; transposing
two words in the corpus reddens it, which nothing did before. It is a SIBLING constant, **not** a
`ground_truth` row — `sc4_ground_truth_encoder` hashes every row's signature and would redden on a
192-char payload.

**RC-m7 IS CLOSED BY MEASUREMENT AND THE TRIP-WIRE WAS RE-SCOPED.** PR #30 merged the model into
`origin/develop` (`291d8a6`), so check 10's old subject — the emitter's absence from this worktree —
was permanently satisfied-by-absence. It now reads `origin/develop` through `git`, with a control
shown saying YES and NO, and asserts the emitter's hand-written `SHOCK_EVENT_TOPIC0` **equals**
`keccak(shock_signature)`, plus the word order and the 96-byte payload the decoder assumes. Its
failure text keeps the advice: **re-verify the CONSTANT, not merely re-home the pin.** This adds
`git` as a suite dependency alongside `grep` and `/bin/sh`; if `origin/develop` is unresolvable the
check fails loudly with `git fetch origin develop`.

**`"Shock"` IS DELIBERATELY NOT IN `expected_topic_pins`**, with the reason in the file:
`generate-pins.sh` iterates LOCAL interface files and the emitter is not one, so the generator could
never produce that pin. **New prose-in-a-grep instance (24):** the plan's own acceptance command
`sed -n '/expected_topic_pins/,/^$/p' | grep -c Shock` prints **2**, not 0, because `sed` restarts
its range at the comment that explains the exclusion. Anchored to `^expected_topic_pins ::` it
prints 0.

**`Fee.Split` IS THE SPLITTER'S ARITHMETIC, AND IT IS TOTAL.** 465 lines, one import
(`Data.Word`), no floating value, no rational type, no IO, no hexadecimal literal. `compose_scaled`
is the level constraint exactly; `ellipse_test` is `volume_path.gms:100-108` transcribed term for
term times `D^6`; `min_admissible_dstar` bisects. Suite **162/162 → 169/169**, exit 0, zero
warnings, wall **181 s** against a 900 s ceiling. Floors re-measured COLD as a pair with the module
on disk: `purge_file_floor` **62 → 63**, `credential_scan_floor` **71 → 72**, zero slack, census
`hs 51, sh 9, json 9, sql 3`. Both structural greps **0**. Territory clean.

**BASE WAS 162, NOT 151.** Every gate in phase 26 is `BASE + N` against a BASE measured cold at
`2026-08-17T16:07:46Z`, before any edit. The 151 the phase was drafted against, and the 149.5 s wall
beside it, both predate phase 25 and are dead. The comparand wall is **191 s**.

**THREE DEFECTS WERE FOUND IN THE PLAN ITSELF, each fixed with the measurement that found it.**
(1) `RC-M4`: the specified bisection returns `Nothing` at `x = 99, m = 101` though `499975` is
admissible — and the reviewer's own one-line fix is wrong in the mirrored case, so the shipped code
tries BOTH candidate right ends and haddocks why that is complete. (2) `RC-B3`: the plan mandated a
haddock sentence containing `sqrt` in a file its own gate scans for `sqrt`; the sentence moved to the
check's haddock. (3) **NEW**: the plan's float-scan pattern matches `sqrtPriceX96` on **13 lines** of
the already-scanned set, so the check could never have exited 1 — the pattern is word-anchored, the
scanned set is not narrowed.

**BLOCKER B1 IS HALF-CLOSED, AND THE OTHER HALF IS NAMED.** `nearest_partner` divides by `D - x` and
a band over `[1 .. f-1]` reaches `x = 1000000` for every `f > 1000000` — which v4's
`DYNAMIC_FEE_FLAG` (8388608) is. `fee_in_domain` and `FeeOutOfDomain` landed here with three
asserted arms. **26-03 owes** `split_for`'s step-0 guard and the
`split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)` arm, with "delete the guard, observe
the exception" as its firing input.

**FEE-01 AND FEE-02 ARE NOT MARKED COMPLETE, DELIBERATELY.** FEE-01's text says "the splitter
produces (φ_X, φ_M)" and `split_for` does not exist until 26-03; its word "exactly" is FALSE under
the round-and-report ruling and 26-04 owns the correction. FEE-02's "checked before the solver is
invoked" is 26-03's ninth refusal and its Tier-C grid agreement is 26-04's. What shipped is FEE-01's
arithmetic and FEE-02's Tier-A half. Marking either complete now would be the assertion-without-an-
implementing-task shape this milestone keeps finding.

**SEVEN OF `FeeSplit`'S TWELVE FIELDS ARE ASSERTED BY NO CHECK IN ANY PLAN OF THIS PHASE**
(`fs_pool_fee_pips`, `fs_dstar_pips`, `fs_realized_scaled`, `fs_is_exact`, `fs_ellipse_e`,
`fs_boundary_pips`, `fs_band_size`) — reviewer minor `RC-m11`. The record is an interface for
26-03's constructor. If 26-03 does not assert them they are unread fields, and the phase close must
report them by name.

**THE CHAIN FLOORS WHAT THE SPLITTER DOES NOT.** `ProtocolFeeLibrary.calculateSwapFee` computes
`x + m - div(mul(x,m), 1000000)` under truncating EVM `div`, so the realized on-chain fee is high by
`frac(xm/D)` — up to a whole pip, always the same direction — independent of the splitter's own
signed half-pip residual. Phase 27's `compose(read pair) == pool fee` reconciliation will disagree by
exactly that term and must not read it as a splitter bug. **Also OPEN**: v4's `MAX_PROTOCOL_FEE` is
1000 pips and the pinned `f = 6497` seed-0 result `(1036, 5467)` exceeds it on BOTH legs, so which
two on-chain fields the legs are realized in is undecided.

### Phase 25 — closed, and the record below still binds

**THE SHOCK IS NOW THE KEY.** `Store.Key` frames its preimage so no two distinct inputs collide and
no per-run path can reach it (KEY-01..06, six checks); `Store.Cache.decide` looks that key up
BEFORE the solver is reachable and elides on a hit (STORE-01, two checks); an aborted run leaves
nothing behind (STORE-08, one check with a `Produced` positive control ordered first); and emptying
the store is a scoped operation the solve path does not name (STORE-06, two checks).

Suite **151/151 → 157/157 → 160/160 → 162/162**, exit 0, zero `-Wall` warnings, 0 `FAIL` lines.
Both structural greps **0** over `offchain/test/Main.hs` (DB-free and GAMS-free), each captured as
its OWN exit status, never from a pipeline and never gated on `grep -c`. Floors `purge_file_floor`
**62** and `credential_scan_floor` **71**, both re-measured cold at close against `find` printing
exactly 62 and 71 — **zero slack, and they did not move at 25-03, which is the expected reading**
because that plan adds no file under `offchain/`. Census `hs 50, sh 9, json 9, md 3, txt 2, sql 3`.
Territory clean.

**FIVE REQUIREMENTS ARE DEFERRED AND THEY ARE NAMED: STORE-02, STORE-03, STORE-04, STORE-05,
STORE-07.** Not dropped. Each has a written reason in `REQUIREMENTS.md`'s Store deferral block
(`REQUIREMENTS.md:70-88`) with traceability rows at `:208-214`. A requirement that vanishes without
a record is indistinguishable from one that was forgotten, so they are listed here, in
`25-SUMMARY.md`, in `REQUIREMENTS.md` and in `ROADMAP.md`'s phase entry.

**THREE DATABASE-REVIEW FINDINGS STILL BIND ANY FUTURE STORE WRITE.** `DB-B2`: a bare `ByteString`
on a `bytea` parameter type-checks, runs and CORRUPTS silently (6 bytes in, 3 out, measured on PG
18.4) — the `Binary` newtype is mandatory and **nothing structurally enforces it**, no compile
error, no helper, no source scan. `DB-M4`: the derived `doc` column's placeholders are all
`Binary ByteString`, so **transposing positions 3 and 4 compiles, runs, and derives `doc` from the
KEY**; a generated column would close it and is unavailable (`convert_from` is STABLE). `DB-M5`:
`jsonb` refuses the JSON escape for the NUL code point, so a legal RFC-8259 artifact containing it
**cannot be stored at all** while `doc` is `not null` — the derived projection vetoing the
authoritative bytes, undecided by this phase. The trigger-hardening findings `DB-B1`, `DB-M1` and
`DB-M2` attach to `run_log` and `quarantine`, which belong to deferred requirements, and do NOT
bind — unreached, not resolved.

**STORE-06 IS A TYPE PLUS A SCAN, IN THAT ORDER.** `store_reset :: ResetScope -> IO ()` makes the
unscoped call unwritable — there is no `store_reset store` that type-checks. What the type cannot do
is stop a module CALLING the scoped form: the field is in scope wherever `Store (..)` is imported,
and a typeclass would have the identical property. So the second half is a scan over
`Store/Cache.hs`. The plan's name `reset_is_unreachable_from_a_solve_or_a_publish` was rejected on
measurement — there is no publish path in this tree and the field is not unreachable — and it is
`no_solve_path_names_the_reset_entry_point`.

**THE ABSENCE SCAN READS THE FILE RATHER THAN SHELLING `grep -c`.** `grep -c` prints `0` for a file
that does not exist, so an absence claim built on it passes for the one reason that should fail it
loudest. The check asserts the file EXISTS and names `decide`, `store_put` and `store_lookup` —
fields of the same record, through the same import — before it asserts the reset token is absent.

**`25-02` HAS NO PLAN SUMMARY, AND THAT IS RECORDED RATHER THAN BACK-FILLED.** Its three task
commits landed (`1b733c4`, `6eba818`, `1164b4d`) and no closeout followed; this file's Current
Position still read "25-01 COMPLETE" until now, and its progress counters were never advanced for
25-02. Precedent: 24-05's summary was written and left untracked until 24-06 carried it. 25-02's
content is in `25-SUMMARY.md` and in its own unusually full commit messages; a summary reconstructed
after the fact from commit messages is a weaker artifact than the commit messages.

**`Store.Postgres.store_reset` IS NOT EXERCISED BY ANYTHING.** `cabal test` is server-free by
construction (DB-03) and no capture script drives a reset. Its statement takes no parameters, so it
carries neither the DB-B2 `Binary` hazard nor a DB-M4 placeholder — but "it compiles" is the whole
of the evidence for it, and the module haddock says so at the point of definition.

**NO END-TO-END STORE-01.** Nothing builds a production `Solver` from `Gams.Run.run_prover`;
elision is proven at the seam with a counting test solver. That was reviewer finding M3 and it is
the first thing phase 26 owes.

**GUARD #21 IS STILL OPEN**, and now closes as a phase-level carry-forward rather than a plan one.
Phase 24 named the artifact-side echoed-field cross-check as the mutation Phase 25 owed;
`the_preimage_excludes_every_per_run_token` discharges KEY-02's scope half, and the echoed-field
mutation was in the cut scope.

Next action: **execute 26-03** (`split_for`, `admissible_band`, the argv assembly). It carries three
inherited debts by name: blocker B1's `split_for` step-0 guard and its
`split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)` arm; RC-M6's corrected empty-band size
(**2**, not 4 — `admissible_band 3000 1000 == [(1,2999),(2,2998)]`); and RC-m11's seven unasserted
`FeeSplit` fields. **`offchain/lib/Gams/Argv.hs` is now inside a grep's blast radius**: check 10's
second arm requires the decay identifier to appear NOWHERE in that file, prose included, and 26-03
and 26-04 both edit it — that arm has been OBSERVED firing on a haddock line. The production
`Solver` adapter that closes STORE-01 end to end is still owed and 26-02 did not touch it.

Last activity: 2026-08-17 — 26-02 executed (commits `b22b637`, `e69a2e8`, `d536d08`), 181/181.

## Phase 25 Plan 01 Position (record)

Plan: **25-01 COMPLETE** (commits `c0e2e9c`, `26378ad`). `Store.Key` shipped at `f00b40b` with no
check on it; it has six now, and KEY-01..06 are all discharged.

Suite **151/151 → 157/157**, exit 0, zero `-Wall` warnings, 157 s wall. Both structural greps still
**0** over `offchain/test/Main.hs` (DB-free and GAMS-free), each captured as its OWN exit status.
File floors did not move — no module was added, and that was the expected reading.

**THE FRAMING CHECK'S FIRST ARM IS THE CHECK.** `[("a","bcd"),("e","f")]` and
`[("ab","cd"),("e","f")]` are asserted byte-identical CONCATENATED BARE before anything is said
about `frames`. A pair built from fixed-length digests differs bare too and would have passed with
the framer deleted — the collision has to be exhibited or the separation is green about nothing.
The third arm carries it to `key_preimage`, so the claim lands on the real preimage.

**KEY-01'S PLAN STEP WAS WRONG AND THE CODE SAID SO.** The plan asked for `key_identity` to return
`Left` on an absolute model-source path. It does not: `relativise` takes `takeFileName` FIRST, so
`/var/lib/…/volume_path.gms` becomes `volume_path.gms` — not absolute, no separator — and the
identity is `Right` with the directory discarded. `AbsoluteModelSourcePath` fires only for a path
whose file name is EMPTY. The check asserts both halves (relativisation + the directory absent from
the preimage bytes; refusal naming the ORIGINAL path for the unrelativisable case) and was renamed
`no_key_identity_carries_an_absolute_model_source_path`, because a check named "refuses" while the
behaviour is "relativises" is the misleading artifact this repository keeps paying for.

**THE PER-RUN SCOPE CHECK WAS OBSERVED REDDENING, ONCE, THROWAWAY.** Seeding a legitimately-present
token (`lo=2`) into `key_per_run_tokens` took
`the_preimage_excludes_every_per_run_token` to FAIL at 155/157. Absence claims are cheap to write
and free to pass; this one has a live subject. It is the check that stops the store being useless —
`Gams.Run`'s wrapper vector carries an EXCLUSIVE PER-RUN temp dir, so a preimage containing it
reconstructs the argv perfectly and hits the cache exactly never.

**ABSENCE IS ASSERTED ON THE FRAMED FORM, NOT AS A BARE SUBSTRING.** The wrapper's budget and kill
delay are bare integers; a substring claim about them is a claim about which digits happen to occur
inside a sha256. `frames [token]` makes it a claim about a component. The forbidden tokens and the
installation path are assembled from string fragments, so the GAMS-free grep over `Main.hs` stays 0
— instance 19 of that hazard, anticipated rather than discovered.

**FOUR NAMES IN THE PLAN'S API LIST ARE NOT EXPORTED** — `build`, `relativise`, `source_frames`,
`parse_frames`. They are top-level bindings in `Store.Key` and absent from its export list. Nothing
was lost (the checks use `frames` and `key_preimage` instead), but 25-02 must not assume them.

**GUARD #21 IS STILL OPEN.** 24's phase-level finding named the echoed-field cross-check as the
mutation Phase 25 owes. `the_preimage_excludes_every_per_run_token` asserts KEY-02's scope half —
one renderer, no per-run tokens — but the artifact-side echoed-field mutation is not this plan's
subject and remains owed.

Next action (as recorded then): `/gsd:execute-phase 25` continues at **25-02** (`Store.Solver` /
`Store.Cache`: elide on hit, and no cache entry for an aborted run).

Last activity: 2026-08-17 — 25-01 executed (commits `c0e2e9c`, `26378ad`).

## Phase 25 Plan 02 Position (reconstructed at close — NO SUMMARY WAS WRITTEN)

Plan: **25-02 COMPLETE** (commits `1b733c4`, `6eba818`, `1164b4d`). No `25-02-SUMMARY.md` exists and
none was back-filled; see the note in the Current Position above. What it shipped:

- `Store.Solver` — the solver seam, a record of functions over `Gams.Run`'s own `ProverOutcome`. The
  outcome sum is **RE-EXPORTED, not redefined**: a second sum of the same name would have the cache
  speaking a type the real prover never returns.
- `Store.Cache.decide` — lookup FIRST, elide on a hit, persist only a completed run. It takes a
  `KeyIdentity` and a `Shock` and nothing that varies per invocation, so no budget, kill delay,
  binary path or per-run working directory can reach the key. `grep -c 'RunRequest'` over the file
  is 0.
- Three checks: `an_identical_shock_elides_the_solve`, `a_miss_invokes_the_solver_exactly_once`,
  `an_aborted_run_produces_no_cache_entry`. Suite **157/157 → 159/159 → 160/160**.
- **Two throwaway reddening observations, from its commit messages:** `decide` solving before the
  lookup and discarding the answer gave `FAIL … the solver was invoked 1 times on a shock whose key
  was already stored` (156/159) **with the VALUE arm still green** — exactly the "ran and was
  ignored" solver a counter-free check would pass; and `decide` returning the solver's bytes on a
  hit gave `FAIL … expected Elided with the STORED bytes` (156/159), naming the B′ document it
  returned. The pair is non-redundant, and that was measured rather than argued.
- Both floors re-measured by running both `find` commands, twice, once per module-adding commit:
  purge 60 → 61 → 62, credential 69 → 70 → 71, each against exactly that many files, zero slack.

## Phase 24 Closing Position (record)

Phase: **24 — GAMS Invocation & Toolchain Identity** — **COMPLETE (6/6 plans, 7/7 requirements)**
Plan: **24-06 COMPLETE.** `NOT NULL` is not non-empty, and the database was WATCHED saying so.

**A `"" == ""` LIVE SINCE PHASE 23 IS CLOSED ONE LAYER BELOW THE HASKELL GUARD.**
`001_model_run.sql` declares `gams_ver` and `conopt_ver` `text not null`, and **`text not null` does
not forbid `''`** — so the schema underneath `Gams.Version`'s unconstructible-empty newtype would
still have accepted the empty string from any other writer. Migration
`003_version_columns_nonempty.sql` adds a NAMED `check (length(gams_ver) > 0 and length(conopt_ver)
> 0)`, and the refusal was **OBSERVED against a real Postgres 18.4**, not argued from the DDL:
SQLSTATE **`23514`**, on **`gams_ver` and `conopt_ver` independently** (each with the other column
left non-empty), through **`store_put` — the store's own `Binary`-wrapped write path**, with the
server's own message naming the constraint and `rows_after` **0** from the server's own count. Suite
**149/149 → 151/151**, FAIL 0, zero `-Wall` warnings, still DB-free AND GAMS-free, wall 150.0 s
against 900 s.

**THE POSITIVE CONTROL IS WHAT MAKES THE REFUSAL MEAN ANYTHING.** The identical row with both
versions non-empty **LANDS** (`control_accepted true`, `control_rows_after 1`). "It raised" is
satisfied by a dead connection, a malformed key, a `doc` that is not JSON and a table that does not
exist — this repository's whole defect class. The control is evaluated BEFORE the rejections in both
the script gate and the in-suite check.

**THE COPY-PASTE CONSTRAINT WAS MEASURED, NOT ARGUED.** With `003` cut down to
`check (length(gams_ver) > 0)` and nothing else changed, the capture recorded **`rejected: false`** —
the server **STORED** an empty `conopt_ver`. The two-conjunct constraint is not tidiness, and the
same run is the restore-on-failure proof: the capture DID write a new artifact, the gate fired, and
the committed evidence came back **byte-identical by DIGEST** (`4111b1f3…520f18e8`), which is the
instrument phase 23's first docker probe taught us to use instead of an exit code.

**A FIELD THE HARNESS CAUGHT WAS DELETED, NOT ASSERTED.** The first version of the observation
carried a per-column `attempted` and it was the literal `True`; the sentinel sweep reported all six
of its mutations ABSORBED. Asserting it would have compared a constant to itself — 24-04 MEASURED
that shape leaving a suite **138/138 green with the library renamed underneath it**. The honest
per-column form is the ENTRY, and the array's column set is compared to
`Store.Schema.versions_nonempty_columns` in BOTH directions.

**THE STORE ARTIFACT'S TOP-LEVEL SURFACE IS NOW A SET IN BOTH DIRECTIONS** —
`expected_store_observation_blocks`. **Fifth list found in this phase without a growth guard and the
fifth to get one.** OBSERVED with the COUNT-PRESERVING RENAME control:
`empty_version_rejected` → `empty_version_refused` leaves **14 keys before and 14 after**, so a
count passes, and the set reddens in both directions at once.

**THE READINESS POLL WAS NOT A READINESS GATE, AND IT COST THREE CAPTURES.**
`pg_isready` over the container's UNIX SOCKET is satisfied by the entrypoint's TEMPORARY bootstrap
server — and it reports `FATAL: database "..." does not exist` as *accepting connections*. The poll
passed, the bootstrap server shut down, and the client's first query hit the close. `-h 127.0.0.1`
is the discriminator, because the bootstrap server has no TCP listener. Pre-existing since 23-04; it
failed in the SAFE direction every time, which is exactly why it survived. A companion bug in the
same block: `read -r a b c <<< "$(jq …)"` collapses when `sqlstate` is legitimately empty — one `jq`
call per field now.

**BOTH TREE-DERIVED FLOORS RE-MEASURED COLD, BEFORE AND AFTER, and the brief was wrong.** The plan
brief said `purge_file_floor` 55 / `credential_scan_floor` 63; those are **24-04's** numbers.
Measured cold on disk before anything was edited: **58 / 67**, zero slack. After the migration:
**59 / 68**, zero slack, census `hs 47, sh 9, json 9, md 3, txt 2, sql 3`. `sentinel_pair_floor`
**3698 → 3828** and `artifact_field_floors`'s `store-conformance.json` **134 → 156**, both raised
until the harness NAMED what it reached; the five other artifacts came back at exactly their old
numbers.

**PROSE INSIDE A GREP'S BLAST RADIUS — INSTANCE 18.** This plan's own haddock said "every future
writer that is not `Store.Postgres`", inside the file whose scan asserts no such token is in it. The
verification grep returned 1. Eighteen times now; the answer has never changed.

**PHASE-LEVEL FINDING: FOUR of 24-RESEARCH's 41 guards have a standing assertion and NO mutation.**
Named, not omitted (23-05's guard #13 precedent): **#11** `conopt_parse_is_position_independent`
(never falsified — 24-01 records it staying GREEN under a sibling's mutation, which is not an
observation of it); **#21** the echoed-field cross-check (24-03 exercised it and it PASSED; the
freshness conjunct did the catching); **#23** the 2 MB stderr drain (its firing input is a deadlock
and no mutation removed the drain); and **#28/#30** (the empty hostile-variable set and the
fewer-than-16-of-16 arm, both asserted every run, neither mutated). Guard #21 is the one Phase 25
must close — KEY-02's own success criterion asks for exactly that mutation.

**ALL SEVEN PHASE-24 REQUIREMENTS ARE COMPLETE**, and `24-RESEARCH`'s five-part gate on starting
Phase 25 is discharged in full.

Next action: `/gsd:plan-phase 25`.

Last activity: 2026-08-17 — 24-06 executed (commits `158ca84`, `79f8ad8`).

## Phase 24 Plan 05 Position (record)

Plan: **24-05 COMPLETE** (commits `15c539c`, `2e1a390`, `ac607bd`, closeout `1df084a`). The real
GAMS 54.1.0 / CONOPT 4.39.0 driven once out of band into `offchain/rig/gams-conformance.json`; ten
Tier-C checks resting on it; 75 of the artifact's 76 leaves read by one of them; the sixth swept
artifact; four floors re-measured; fourteen firing observations; `cabal test` still structurally
unable to name the solver. Suite **138/138 → 149/149**. GAMS-01/02/04/06 marked COMPLETE.
**Its summary was written but never committed** — `24-05-SUMMARY.md` was untracked until 24-06's
metadata commit carried it, unmodified. A phase record that exists only on one machine's disk is not
a record.

Its three carry-forwards that outlive the phase: `gams-conformance.json` is NOT byte-stable across
re-captures (`generatedAt` and two banner `line1`s carry a wall clock, MEASURED);
`Gams.Invoke.raw_gams`'s timeout has never been observed firing (the production path through
`run_prover` HAS been, at 24-04); and `conopt_true_line_index_real` is **48**, not the 47
`24-RESEARCH` records.

## Phase 24 Plan 04 Position (record)

Plan: **24-04 COMPLETE.** The hung GRANDCHILD, two real environment vectors, a version that cannot
be missing, and the structural guarantee that `cabal test` cannot reach the real prover. Suite
**131/131 → 138/138**, FAIL 0, zero `-Wall` warnings, still DB-free AND GAMS-free, **+0 packages**.

**THIS PLAN WAS INTERRUPTED AND CONTINUED.** Tasks 1 and 2 were committed (`8f5d2ef`, `a8a3a21`)
and the executor then died mid-Task-3 on a connection loss, not a code failure. A second executor
re-measured every inherited claim cold before touching anything — build, suite, both greps,
`git status`, both commits — and only then executed Task 3 (`76184d0`) and closed the plan out.

**THE TIMEOUT IS NOW FALSIFIED, AND ON THE RIGHT SUBJECT.** 24-03 left guards 23/24/25 built and
never observed firing, and this phase's own rule treats an unobserved guard as ABSENT. The stub
backgrounds `sleep 300 &` and `wait`s, so the process under test is a GRANDCHILD — **MEASURED,
written against a direct child the check CANNOT FAIL**, because `System.Timeout.timeout` reaps a
direct child with no orphan and the assertion would be green with or without the group-owning
`/usr/bin/timeout -k`. Liveness is read from `/proc/<pid>`. The negative control was OBSERVED: with
`Gams.Run` spawning the binary directly, `/proc/3896506/stat` reported `3896506 (sleep) Z 1 …` —
the grandchild reparented to PID 1 and still present. `pgrep -a 'sleep 3'` is 0 after the suite.

**THE WHITELIST IS PROVEN IN FORCE BY TWO REAL VECTORS, NOT BY BYTES.** The inherited child carries
**64 keys** against the whitelist's 3, and `shell_injected_env_keys = ["PWD","SHLVL","_"]` was
MEASURED on this host rather than copied from the plan. A byte comparison could not do this work:
four hostile ambient variables changed nothing and there is no comma-decimal locale on this machine.
**And the check as planned COULD NOT FAIL** — its expected side was `whitelist_for scratch`, the
same expression as its subject, so deleting `LC_ALL` moved both sides together. OBSERVED, then
fixed against `whitelist_keys`. **Seventh representation of this project's standing defect, found
inside the check written to catch the sixth.**

**`cabal test` IS NOW STRUCTURALLY INCAPABLE OF NAMING THE REAL SOLVER, AND SAYS SO IN-SUITE.**
`the_suite_never_names_the_real_solver` is the DB-free scan's twin: three tokens BUILT by
concatenation, scanned over `offchain/test/Main.hs`, with a **PROVEN positive control** — a seeded
bait carrying all three in the shapes they would really appear in must be NAMED, a clean file
carrying the IO edge and `/bin/sh` must not be, and the control is ordered FIRST. It is no longer a
verification-time command an executor has to remember.

**23-05's `PGSTORE_DSN` RULING TRANSFERS UNWEAKENED.** `GAMS_CONFORMANCE` is registered and probed;
`GAMS_BIN` and `GAMS_MODEL` are NAMED GAPS with written reasons, because their consumer is the
module the grep above makes unreachable, and both ways of manufacturing a subject are rejected —
importing it breaks the GAMS-free property on its way to enforcing it, and a validator written only
to be probed is a registered-but-vacuous probe. `probe_override` was not weakened.

**A PLAN ACCEPTANCE CRITERION WAS MEASURED BACKWARDS AND REJECTED.** Criterion 5 asked for the
variable to be referenced through `gams_conformance_env_var` rather than spelled, *"which is what
makes a rename in the config module redden the sweep"*. It is the reverse, and the plan contradicts
itself (its action says "same shape as `STORE_CONFORMANCE` exactly", which is a literal). MEASURED:
with the constant in the list, renaming it in `Gams.Config` leaves the whole suite at **138/138,
exit 0**; with the literal, the identical rename reddens **two independent checks**. The literal is
kept and the counter-measurement is written into the check's haddock so it is not re-proposed.

**THE LIST ITSELF GOT A GROWTH GUARD.** `config_env_vars` now pairs each value with the NAME of the
constant holding it, and a census grepped out of `offchain/lib/{Store,Gams}/Config.hs` is compared
BOTH WAYS. Dropping a variable from the list was OBSERVED leaving the pre-existing coverage arm
GREEN — it is a per-variable arm — and the census is what reddened. A sixth variable in either
config module can no longer be added silently.

**GAMS-05 IS COMPLETE.** Every row of roadmap SC-4 shipped and every one is OBSERVED, and "never an
output row" was discharged at the TYPE level at 24-03 under planning correction 1. **GAMS-03 and
GAMS-06 stay PARTIAL**, each owing exactly one capture-artifact row that does not exist until 24-05:
the resolved absolute binary path plus executable sha256 (GAMS-03), and a hostile ambient variable
producing byte-identical output (GAMS-06).

**BOTH FLOORS RE-MEASURED COLD, TOGETHER, AND NEITHER MOVED:** `purge_file_floor` **55** against
exactly 55 files, `credential_scan_floor` **63** against exactly 63 — zero slack on both. This plan
adds no file; the re-measurement was done because the rule is that a floor is re-measured whenever a
plan is already editing this block, and 24-02 is why.

**PROSE INSIDE A GREP'S BLAST RADIUS — INSTANCE 16.** Task 3 wrote a check, a pattern, a bait, a
positive control and three override reasons that all have to DESCRIBE the three forbidden tokens
without naming them, inside the file being scanned. Every one describes rather than lists; pattern
and bait are both built by concatenation. Sixteen times now, and the answer has never changed.

**THE WALL.** 78.3 s at 24-03's end → **140.9 s**, all with the binary pre-built. Tasks 1-2 cost
+61.7 s (six checks that each spawn several real children, one waiting out a 2 s budget, one pushing
2,000,000 bytes through a pipe); Task 3's structural check costs **+0.9 s**. Budget 900 s.

Next action: `/gsd:execute-phase 24` (plan 24-05).

Last activity: 2026-08-16 — 24-04 executed (commits `8f5d2ef`, `a8a3a21`, `76184d0`).

## Phase 24 Plan 03 Position (record)

Plan: **24-03 COMPLETE.** The ONE IO edge. `Gams.Run.run_prover` is the only function in this
phase that spawns a process, and the verdict it returns is a **conjunction of six** of which not
one is log text: the exit code classifies as `Solved`; the artifact exists in a directory that
could not have pre-existed; its mtime is at or after a marker written just before the spawn; it
decodes; both echoed fields equal the argv token **sent**; and the run's own log carries a job
banner naming the invoked model.

Status: **EXIT 0 MEANS "GAMS RAN", AND THE SUITE NOW DRIVES THAT RATHER THAN ARGUING IT.** Five
Tier-B checks spawn real `/bin/sh` children the checks write themselves. A stub whose whole body
is `exit 0` is REFUSED — MEASURED with the real binary, `action=c` is exactly that shape. The
**real 606 committed golden bytes** planted at the process's own working directory, with a valid
job banner beside them and a shock equal to the golden's own inputs, are UNREACHABLE. Two stubs
with the same exit code and opposite log text (`Normal completion` against `** Locally
Infeasible`) give the IDENTICAL verdict, and that arm has its own positive control asserting the
two stdouts actually DIFFER. Suite **126/126 → 131/131**, FAIL 0, zero `-Wall` warnings, still
DB-free AND GAMS-free, **+0 packages**.

**`Aborted` HAS NO ARTIFACT, AND THE COMPILER SAID SO THREE WAYS.** Correction 1 is stated at the
type level rather than deferred to Phase 25's run-log table, and the GHC output is quoted verbatim:
`Patterns of type 'ProverOutcome' not matched: Aborted _ _ _` (the accessor cannot be total),
`Couldn't match expected type 'ProverArtifact' with actual type 'AbortReason'` (there is nothing of
that type inside `Aborted`), and `Module 'Gams.Run' does not export 'outcome_artifact'`. A
consequence measured rather than predicted: **the mutation the plan named for firing observation 1
is not expressible** — `Produced` demands an artifact and a run that wrote nothing has none.

**THE FRESHNESS CONJUNCT WAS THE BELT, NOT THE BRACES.** Firing observation 2 pointed the artifact
read at the process CWD instead of the run directory, and the plant was caught by `StaleArtifact`
— found, decoded, echoed fields matching, and losing on its modification time. Pitfall 8's
belt-and-braces observed doing the catching.

**`purge_file_floor` HAD NEVER MOVED.** 24-02's summary states it went 51 → 54 in `2a558e3`;
`git show` on that commit and every commit since reports **51**, against **55** files on disk —
**four of slack**, in the guard whose entire job is to detect a scan that collapsed. Its twin
`credential_scan_floor` DID move, so one half of a pair that is always re-measured together landed
and nothing reddened. Both are now re-measured cold: **51 → 55** and **62 → 63**, zero slack on
both, with the discrepancy recorded in the floor's own haddock and the rule restated as a pair.

**PROSE INSIDE A GREP'S BLAST RADIUS, THREE MORE TIMES IN ONE PLAN — instances 13, 14 and 15.**
`Gams/Exit.hs`'s explanation of why a layer must not read the model-status word contained it;
`Gams/Run.hs`'s haddock spelled all three identifiers its own acceptance criteria grep for at zero;
and the comment beside the new `Gams.Run` import asserted the three GAMS-free tokens stay out of
`Main.hs` **while listing all three**, so the verification grep returned 2. Every time the prose
moved and no pattern was relaxed.

**THE TIMEOUT IS BUILT BUT NOT YET FALSIFIED.** `/usr/bin/timeout -k` (which owns the process
GROUP, because CONOPT is a grandchild at `Solvelink=2`) and the in-process backstop are both in
`Gams.Run`, and neither has been OBSERVED firing. Guards 23/24/25 are GAMS-05's and belong to
24-04; until they run, this phase's own rule treats the timeout as absent.

**THE WALL.** 73.1 s before, **78.3 s** after, both with the binary pre-built. +5.2 s for five
checks that each spawn several real children, and the reason it is that cheap is `sweep_one`'s
`readable` filter: these five read no swept artifact, so they run once per full `core_checks` pass
rather than once per sentinel pair. Budget 900 s.

**GAMS-01 and GAMS-02 stay PARTIAL.** Every Tier-A and Tier-B row of both shipped and every one is
OBSERVED; each still has exactly one **Tier-C** row that reads a capture artifact which does not
exist until 24-06.

Next action: `/gsd:execute-phase 24` (plan 24-04).

Last activity: 2026-08-16 — 24-03 executed (commits `847bc9c`, `f557e16`).

## Phase 24 Plan 02 Position (record)

Plan: **24-02 COMPLETE.** The renderer that decides the artifact's bytes, the environment
whitelist, and the decoder that never builds a 53-bit floating value. **BYTE-04 is MARKED
COMPLETE** — the first requirement closed in this phase, because all six of its Tier-A rows
shipped here and every conjunct has a check that reads it. GAMS-02 and GAMS-06 stay PARTIAL:
their remaining halves are Tier-B subprocess checks that do not exist yet.

Status: **THE LEADING ZERO CANNOT REACH THE `execve`.** `parse_shock_field` NORMALIZES at the
edge, so `079228162514264337593543950336` and `79228162514264337593543950336` become one
`Integer` and one token — which also settles Phase 25's KEY-04 (`28e18` and
`28000000000000000000` are the same value) upstream of any row. `Shock` carries seven strict
`Integer`s with no optional and no defaultable field, and eight shape-valid shocks are refused BY
FIELD NAME. Suite **117/117 → 126/126**, FAIL 0, zero `-Wall` warnings, still DB-free AND
GAMS-free, +0 packages.

**BYTE-04 IS TWO EQUALITIES ON `Integer`s, TIED TO THE FILE BY A DIGEST CHECKED FIRST.**
`dQx[0]`'s 53-bit image is pinned at `-2613128317657530368` and the move is asserted as
`image - exact = +32` — the research table's sign convention, now STATED, because the check was
first written the other way round and its own first run caught it (an `abs` would have hidden it).
16 of 16 elements are shown inexact, `|delta|` in `[4, 328]`. The provenance digest runs BEFORE
the decode, so an edited artifact fires on identity rather than producing a
different-but-plausible vector.

**THE REASSIGNED HOLE IS CLOSED, NOT DEFERRED.** `aeson_storage_path` had no directory
cross-check and wave 1 proposed 24-04. `Gams/Artifact.hs` went onto the list in the commit that
created it, all five sibling GAMS modules with it, and research guard 34 landed in the same
commit — a both-directions assertion over `offchain/lib/{Store,Gams}/` with an EMPTY, reasoned
exemption list. Then the same defect was found INSIDE the fix: the new float scan was a
hardcoded two-file list with no growth guard of its own. `artifact_float_path` is now
`aeson_storage_path` — one set, one growth guard, thirteen more files covered at zero cost, and
`budget :: Double` seeded into `Gams/Env.hs` was OBSERVED reddening it by file and line, which
before that fix would have been silent.

**FIVE FIRING OBSERVATIONS.** A leading-zero renderer named the `=0` token; an edge that REFUSED
the leading zero instead of normalizing it fired the M7 arm the plan named (the planned mutation
fired the positive arm first, so both were run and both recorded, as at 24-01); a decoder that
took `1.5` as `1` put a wrong wei amount into `dQx`; ONE byte of
`offchain/rig/volume-path-golden.json` — length unchanged at 606 — fired on the DIGEST before
the decode; and an unlisted `Gams/Publish.hs` was named by BOTH directory-vs-list guards. Every
source restored **from a saved copy** verified sha256-identical, never by `git checkout`.

**THE PROSE TRAP FIRED A TWELFTH TIME — AND THIS TIME IT WAS IN THE PLAN.** 24-02's task 1 action
asked for a haddock explaining why `show` on a `Double` is locale-dependent, while its own
acceptance criterion greps that file for `Double` expecting 0. The reasoning was kept and the
words changed; the pattern was not relaxed.

**BOTH TREE-DERIVED FLOORS RE-MEASURED COLD, in the same commit as the modules that moved them:**
`purge_file_floor` 51 → **54** and `credential_scan_floor` 59 → **62**, each from
`find … | wc -l` run at execution time. **Zero slack for the second plan running** — 51 against
exactly 51 files, 59 against exactly 59.

> **CORRECTED AT 24-03 — the `purge_file_floor` half of that sentence is FALSE.** `git show` on
> `2a558e3` and on every commit after it reports `purge_file_floor = 51`. The number was measured
> and written into the summary; the edit never reached `Main.hs`. Only `credential_scan_floor`
> moved. The floor therefore sat four below its subject with nothing red, which is the defect class
> this milestone's standing rule names, inside the guard that exists to detect it. Left in place
> rather than rewritten, because what was believed is part of the record; the correction is 24-03's
> deviation 3 and both floors are now 55 / 63 against exactly 55 / 63 files.

**THE WALL.** 68 s before, **76 s** after, with the test binary already built both times (24-01's
87.8 s included compilation and is not comparable). Nine checks cost ~8 s, two of which spawn
`grep` inside the sentinel harness's ~3250-pair multiplier. Budget 900 s.

Next action: `/gsd:execute-phase 24` (plan 24-03).

Last activity: 2026-08-16 — 24-02 executed (commits `2a62cce`, `46ba4fc`, `2a558e3`, `8fc2bd6`).

## Phase 23 Closing Position (record)

Phase: **23 — Postgres Foundation & the Byte-Exact Schema** — **COMPLETE (5/5 plans)**
Plan: **23-05 COMPLETE.** All **nine** phase requirements marked complete for the first time
(DB-01..04, BYTE-01/02/03/05, KEY-07) — four plans deliberately held them at PARTIAL because
evidence unread by any check is the artifact-asserted-by-nothing shape (issue #19). **That
condition is now discharged.** Next: `/gsd:plan-phase 24`.

Status: **THE EVIDENCE IS LOAD-BEARING.** Thirteen new checks turn
`offchain/rig/store-conformance.json` from a committed file nothing read into the artifact eleven
assertions rest on. **Suite 111/111, FAIL count 0, still DB-free** — the three-token grep over
`offchain/test/Main.hs` is still **0**. `cabal test` WALL went **78 s → 97 s** with the fifth swept
artifact; the budget was 900 s and the artifact was NOT narrowed.

**SIXTEEN FALSIFICATIONS OBSERVED**, each against its named input, and the committed artifact's
sha256 (`1e5f076a…d332153`) is byte-identical before and after all of them. The four the plan named:
ABSENT (all eleven artifact-reading checks fail, naming the capture command — none skips), STALE (a
real `.sql` edited: `recorded=9e89722c… recomputed=ff649f32…`), TRUNCATED (`sc_complete false`), and
a MISSING LAW VERDICT — **reported as a SET mismatch while `sc_law_count` still read 8**, which is
the demonstration that a count-based instrument would have passed that input.

**THE BARE PATH TURNED OUT TO BE PREDICTABLE.** The sentinel harness reported four fields of the
new artifact absorbed; three were ASSERTED rather than pardoned. `bare_out_len` and
`bare_out_sha256` are now compared against `bare_path_prediction` — a MODEL of the two mechanisms
(libpq's C-string escaper truncating at the first NUL, then `byteain`'s legacy escape decode)
computed from `cm_bytes` in `Store.Types`, never from the artifact. It reproduces **all five
returning corpus members exactly, in length AND digest**. BYTE-05's negative control is now an
outside oracle rather than a bound. Only `generatedAt` is pardoned.

**`PGSTORE_DSN` IS A NAMED GAP, NOT A PROBE.** Its consumer is libpq, reachable only through the
client module and the capture executable, and neither is reachable from `cabal test` BY
CONSTRUCTION — that is DB-03. Manufacturing a consumer (a `validate_dsn` written only to be probed)
would be a registered-but-vacuous probe, the exact defect the sweep exists to catch. It lives in a
new **asserted** `unprobed_overrides` list with a written reason, and the two halves that ARE
measurable (verbatim resolution, differs-from-default) are asserted. `probe_override` was not
weakened. `STORE_CONFORMANCE` IS registered and was observed firing on three arms.

Next action (at the time): `/gsd:plan-phase 24` — DONE; phase 24 is planned (6 plans) and 24-01
is executed.

Last activity: 2026-08-16 — 23-05 executed (commits `96736a4`, `90f6c4f`).

### The six phases

| Phase | Name | Reqs | Blocked? |
|---|---|---|---|
| 23 | Postgres Foundation & the Byte-Exact Schema | 9 | **COMPLETE 5/5, all 9 reqs** |
| 24 | GAMS Invocation & Toolchain Identity | 7 | No |
| 25 | The Content Key & Keyed Store | 14 | No |
| 26 | Shock Assembly — Fee Split & Event Decode | 5 | No |
| 27 | Anvil Read Layer | 3 | **Yes** — plank must emit `next` (issue #26) |
| 28 | Resident Loop & Fixture Publication | 5 | **Yes** — inherits 27 |

Execution order 23 → 24 → 25 → 26 → 27 → 28, with **26 parallelizable against 23–25** (zero
dependencies beyond `base`). **23 → 24 → 25 is a genuine chain.**

### Three changes from the six phases approved in brainstorm

The approved shape was (1) Postgres foundation, (2) keyed store, (3) GAMS invocation, (4) Anvil
read layer, (5) fee splitter, (6) resident loop. Same six bodies of work; three things moved:

1. **GAMS invocation moved 3rd → 2nd, ahead of the store.** The key contains the GAMS and CONOPT
   versions (KEY-01), so GAMS-03/GAMS-04 are a *prerequisite* of STORE-01. An emptily-succeeding
   detector (`"" == ""` — this repo's defect #1, verbatim) poisons every row written before it is
   fixed, and those rows are indistinguishable afterwards.
2. **Byte-exactness + `key_scheme` moved into the earliest schema phase (23).** BYTE-01/02/05 and
   KEY-07 are schema decisions every later phase consumes; an artifact stored only in `jsonb` is
   unrecoverable as bytes, and a key-formula change without `key_scheme` is a full-table rebuild.
   Phase 23 is **not plumbing**.
3. **Fee splitter and Anvil swapped (5th ↔ 4th), and CHAIN-04 pulled out of the Anvil phase into
   the splitter phase.** The Anvil phase is BLOCKED; the splitter is not. CHAIN-04 is explicitly
   not blocked — decoding runs against synthetic logs. This makes 23–26 a contiguous chain-free
   block.

**Unchanged and load-bearing:** the byte-reproduction proof — the milestone's headline falsifiable
claim — lands at the end of **Phase 25, with no chain and no upstream**. If the plank block
persists, 23–26 still deliver a complete, verified subsystem.

### Requirement count correction

`REQUIREMENTS.md` said *"39 v6.0 requirements defined"* in both its header and its footer. The
actual checkbox count is **43** (BYTE 5, KEY 7, STORE 8, DB 4, GAMS 6, FEE 4, CHAIN 4, LOOP 5).
Corrected in place; nothing was added or dropped to make the arithmetic work.

### Standing rule for every v6.0 success criterion

This project's review history is dominated by **one** defect class: *an assertion that passes
when its subject is absent* — found six times, each after the previous sweep was declared
complete (`"" == ""`, numeric zero, a count-preserving rename defeating a count floor, an empty
ref file, a CI `grep -q` over an empty log, `0x00…00` passing every hex-shape guard), plus a
seventh (a recorded field derived from the same expression as its own comparison target). v6.0
hands it five new representations: a content hash, a version string, a subprocess exit code, a
determinism check, and a DB test that skipped. **Every criterion is stated as something that can
FAIL** — "X is rejected", "Y aborts when absent", "the mutant Z is OBSERVED caught". "Tests pass"
is not a criterion; a suite that skips also passes.

### Blocked-work coordination

Phases 27–28 wait on the plank worktree emitting the `next` event (`SELECTOR_NEXT 0xd3827b0b` =
`next(address,uint160,int24,uint24,uint24)`); it is a stub today, owned by issue #26. Phase 28
additionally needs the `test/models/mev_tax_model_one/fixtures/` path agreed with the owning
track **before** planning — it does not exist in this worktree today.

**v5.0 closed:** merged to develop as `19a06f3` (PR #9, 209 commits) on 2026-08-03 with
`--admin`, bypassing the `gate` check. CI has NEVER validated it; the `haskell` gate job's
first real execution will be on develop — and v6.0 adds Postgres as a *second* external
prerequisite to a job that has not yet survived its first. Local evidence at merge:
`cabal test` 91/91, zero `-Wall` warnings, `forge test` 252/0 (== develop's baseline),
`verify-rig.sh`/`verify-import.sh` exit 0. Follow-ups filed: #19 (rig payload asserted by
nothing), #20 (MixedReadback block unfalsifiable offline).

## v4.0 Closing Position (record, plank workstream)

Phase: 19 — Differential, Mutation Battery & Consumer Fixture (MVER-01..04) — **COMPLETE**
Milestone: **v4.0 COMPLETE** — all five phases (16, 17, 18a, 18b, 19) and all 15 requirements (VORD-01..05, MCAL-01..06, MVER-01..04) done.
Plan: 19-01 COMPLETE (MVER-01), 19-02 COMPLETE (MVER-03), 19-03 COMPLETE (MVER-02 part A), 19-04 COMPLETE (MVER-02 part B — **MVER-02 fully satisfied**), 19-05 COMPLETE (MVER-04).
Status: 19-05 done — MVER-04 satisfied. `test-vol-order-acceptance` (plus `test-vol-order-diff`, `test-vol-order-fixture`) exists and exits 0; the fold-in is an OBSERVATION (all three Phase 19 contract names seen in plain `make test`), not a prerequisite — `make test` is already a whole-tree `forge test`, and a prerequisite would double-run pos_spec and inflate the tally. **Counts re-MEASURED cold at execution time and every red ATTRIBUTED:** `make test` **102 passed / 18 failed / 120 total (44 suites)**, `make compile-plank` **11 ok / 2 failed** — 14 exposure `setUp()` reverts (the uncommitted `VegaIssuanceLib.plk` draft, `unresolved identifier 'VolOrder'`), 4 vol-type track under `test/types/pos_spec/`, **0 under `test/pos_spec/`**, 0 TickVolatility (did not surface). The stale `MEASURED AT 17-01` block (96 pass / 4 fail, 13 ok — both wrong) was REPLACED, not amended. The real gate is VERIFIED not inferred: `batchSelectorIsNowDispatched`, `mixedBatchFootprintAndContiguity`, `mixedBatchReturnIsByteExact` all CALLED green through `deployPlank`/FFI bytecode. `PLANK_SKIP` byte-identically empty; no exit ceremony invented. `src/` byte-untouched.
Status: 19-04 done — the consolidated MVER-02 battery is complete. **10 mutant applications across parts A and B, 10 observed REDs, SURVIVOR COUNT ZERO**, every mutated source restored sha256 byte-identical (`be196dcb…cc9b8787`, `5fe71f30…73fe8f35`). Guard 3's kill was taken from the REVERT assertion, never a state check, and its state-invisibility was RE-MEASURED (`VolOrderManagerBatchStateTest` green 2/0 under the mutant). M8's N=0 blindness re-measured GREEN; the element-base-shift (N=0-BLIND) vs head-drop (N=0-VISIBLE) mapping settled by measuring BOTH variants rather than inheriting 18b's. M9 killed by the raw-word canonicality assertion, with the `abi.decode` `EvmError: Revert` cascade recorded separately as the Haskell-consumer contract. **Four mutants have a SINGLE point of failure** (M2 outside pos_spec entirely; M4's 65536 test; M5/M6/M7's `VolOrderManagerBatchGuardTest`) — wave 1 structurally cannot cover the malformed-input or large-id surfaces.
Status: 19-01 done — the interleaved sequence differential is green and the module AGREES with an independent Solidity mock at tol 0 across mixed `(create_order | create_orders)` sequences. No disagreement observed. `src/` byte-untouched (both sha256 pins match the 18b baseline).
Status: 19-02 done — MVER-03 satisfied. The consumer golden fixture is committed with bytes produced by `cast abi-encode` (alloy), an encoder OUTSIDE this repo; the module's returndata matches it byte-for-byte across 5 cases including N=0, INDEPENDENTLY CONFIRMING 18b's 64+64N layout from a third encoder. All four interface selectors recomputed with `cast sig` and matching, plus a completeness gate that reddens on an unpinned fifth. **The cross-language gap is NOT closed:** alloy proves STANDARD-ABI conformance only; peer `mv15a18k`'s Haskell decoder remains unexercised and is marked per-case in the fixture.
Last activity: 2026-07-21 — 19-05 executed: three dedicated make targets (acceptance target exits 0); the stale `MEASURED AT 17-01` block replaced with cold-measured counts, every red attributed to a named cause; the CALLED-green batch dispatch verified by three named tests; `PLANK_SKIP` confirmed empty and the roadmap's stale exit wording corrected. `src/` byte-untouched.

Progress (v4.0): [██████████] 100% — 5/5 phases (16, 17, 18a, 18b, 19), 9 plans complete. **MILESTONE COMPLETE.**

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 23 P01 | 41min | 3 tasks | 5 files |
| Phase 23 P02 | 62min | 3 tasks | 5 files |
| Phase 23 P03 | 44min | 2 tasks | 6 files |
| Phase 23 P04 | 33min | 3 tasks | 12 files |
| Phase 23 P05 | 71min | 2 tasks | 2 files |
| Phase 24 P01 | 22min | 3 tasks | 5 files |
| Phase 24 P02 | 33min | 3 tasks | 5 files |
| Phase 24 P04 | 107min (interrupted; 20:45→22:32 across two sessions) | 3 tasks | 1 file |
| Phase 25 P01 | 41min | 3 tasks | 1 file |
| Phase 19 P01 | 6 | 3 tasks | 3 files |
| Phase 19 P02 | 33 | 3 tasks | 3 files |
| Phase 19 P03 | 24 | 3 tasks | 1 files |
| Phase 19 P04 | 21 | 2 tasks | 1 files |
| Phase 19 P05 | 5 | 3 tasks | 2 files |
| Phase 20 P01 | 4 | 3 tasks | 3 files |
| Phase 20 P02 | 13 | 3 tasks | 40 files |
| Phase 20 P03 | 12 | 3 tasks | 4 files |
| Phase 20 P04 | 14 | 2 tasks | 4 files |
| Phase 20 P05 | 22 | 3 tasks | 11 files |
| Phase 21 P02 | 6 | 2 tasks | 3 files |
| Phase 21 P01 | 11 | 3 tasks | 6 files |
| Phase 21 P03 | 15 | 3 tasks | 4 files |
| Phase 21 P04 | 15 | 2 tasks | 5 files |
| Phase 21 P05 | 19min | 3 tasks | 6 files |
| Phase 22 P01 | 9 | 2 tasks | 10 files |
| Phase 22 P02 | 47 | 3 tasks | 5 files |
| Phase 22 P04 | 31min | 3 tasks | 8 files |
| Phase 22 P05 | 22min | 3 tasks | 8 files |
| Phase 22 P06 | 41 | 3 tasks | 9 files |
| Phase 24 P03 | 41 | 2 tasks | 4 files |
| Phase 24 P05 | 110min | 3 tasks | 7 files |
| Phase 24 P06 | 120min | 2 tasks | 6 files |
| Phase 26 P02 | ~5h | 3 tasks | 3 files |
| Phase 26 P03 | 180min | 3 tasks | 5 files |
| Phase 27 P01 | ~2h | 4 tasks | 16 files |
| Phase 28 P03 | 155min (resumed; the previous executor was killed mid-Task-1) | 2 tasks | 6 files |

## Accumulated Context

### Roadmap Evolution

- Phase 8 added (2026-07-18): panoptic vol-claim lean4 formalization — formalize `spec/protocol/panoptic.md` (vol-option payoff, replication-cost pricing, υ identification) in the `lean/` Lake project. Lean4-track phase, independent of Phases 2–7.
- Phase 11 added (2026-07-30): MEV hazard-rate metric and infimum program (λ_MEV) — λ_MEV analogous to flairHazard over the shared Θ_φ, identify Θ_{λ_MEV}, solve inf λ_MEV (opposite level-block monotonicity to the solved sup λ_FLAIR), joint sup/inf program; Angstrom = implementation reference; refs acquired in ../plank/refs/{flair,mev}/. Dir: phases/11-mev-hazard-inf-program/.

### Decisions

**v6.0 (Phase 28) decisions:**

- [Phase 28]: [28-03 MEASURED, and it binds every future check in this suite] **A CHECK THAT COSTS
  T SECONDS COSTS `cabal test` ABOUT 15T.** `sentinel_falsification_harness` re-runs `core_checks`
  once per swept artifact through `all_objections` (seven), once more for its own baseline, and once
  per negative control through `first_objection` — and the negative controls cannot short-circuit,
  because their whole point is that nothing objects. Measured at both ends: **186 s without 28-03's
  two ten-second race harnesses, 528 s with them**, so twenty seconds of racing costs the suite 342.
  `expensive_checks` is an ORDERING list and drops nothing, so it does not help. 28-03-PLAN.md
  budgeted `173 s → ~195 s` on the assumption that a check runs once. **Multiply by fifteen, not by
  two.** The 900 s ceiling now has 372 s of headroom for 28-04 and 28-05 together.

- [Phase 28]: [28-03 MEASURED] **`Data.Aeson.Value` is NOT the carrier that loses wei — `Double`
  is.** A publisher that round-trips the golden through `encode <$> decodeStrict` produces
  DIFFERENT BYTES (539 against 605: whitespace and key order) and the SAME digits, because a number
  is carried as `Scientific`, which is arbitrary-precision, and its encoder prints an integral value
  verbatim. Driven both ways: with the byte-identity arm neutered the check came back GREEN under
  the aeson re-render, and reddened at *"the decimal digit string of dQx[0] -- -2613128317657530400
  -- does not occur in the published bytes"* only once every number was pushed through
  `realToFrac … :: Double`. **Consequence:** "we round-tripped it through aeson" is not by itself the
  BYTE-04 defect, and a check aimed at BYTE-04 must name `Double`. The byte-identity arm is what
  catches an exact rebuild, and the two arms are not redundant.

- [Phase 28]: [28-03 MEASURED] **GHC's runtime keeps a per-inode file lock, and it makes a
  non-atomic writer unwritable in `System.IO`.** `withBinaryFile path WriteMode` raises `resource
  busy (file is locked)` while any handle in the same process holds that file open for reading. A
  torn-write positive control therefore has to go through `System.Posix.IO`; catching and retrying
  would make the READER fail with the same lock error inside the window, and the harness would count
  a lock failure as a torn read. The same fact is why a temp-sibling-then-rename writer is
  unaffected: a sibling is a different inode and `rename()` opens nothing. **Binds any future
  in-process concurrency check on a file.**

- [Phase 28]: [28-03 OBSERVED, twice, in two different ways] **A temp directory shared by name is an
  instrument with a failure mode of its own, and under the sentinel sweep it WILL fire.** A
  per-label directory cleared with `removeDirectoryRecursive` raised `removeContentsRecursive:
  unsatisfied constraints (Directory not empty)` and, on another run, left a publisher writing into
  a directory that had just been removed. The cost was measured: the flaky check entered the sweep's
  reader sets, the suite ran **2328 s instead of 528**, and the harness's own NEGATIVE CONTROL went
  red naming it. Name each scratch directory uniquely (`getMonotonicTimeNSec`), and give any
  operation that can throw inside a harness its own ORDERED ARM — an anonymous `unexpected IO error`
  at `guarded` is the least useful form of a real finding.

- [Phase 28]: [28-03] **An EMPTY `FIXTURE_DIR` resolves to the default, and that is the OPPOSITE of
  `LOOP_POLL_MS`'s ruling.** The failures differ: an unreadable cadence has no interpretation at all,
  while an empty directory string resolves to the process's working directory and would publish a
  real fixture into the repository root with nothing to say so. Falling back puts the miss where
  LOOP-04's missing-directory precondition can see it. Both are driven through the PURE rule, never
  through `setEnv`, because `setEnv k ""` routes to `unsetEnv` (27-01).

**v6.0 (Phase 27) decisions:**

- [Phase 27]: [27-02 MEASURED, and it is the plan's headline] **`anvil_setStorageAt` does not create
  a block — it writes into the state OF THE CURRENT HEAD.** The first capture pinned at the head,
  read back the value the cheat had just written, and recorded `pinned_equals_block_b = false`,
  which is indistinguishable from CHAIN-02's defect. Driven with `cast` independently of the
  program: `head = 19; setStorageAt; evm_mine x3` leaves `--block 19` showing the WRITE and
  `--block 18` showing the old word. The pin was never broken — the same program reads block 0 and
  gets the bare `0x` marker, which it could only do if the block parameter were reaching the node.
  The construction now mines ONE block before the write, and `write_landed_above_b` is a recorded
  and asserted field so the two causes can never be confused again. **Binds anything else that
  constructs a historical divergence on this rig.**

- [Phase 27]: [27-02 FINDING] **A decoy a check compares against must be BUILT BY THE FUNCTION UNDER
  TEST.** The naming arm was written with the delimiters spelled out inside the check; the mutation
  that drops them from the producer MEASURED **201/201, exit 0, NOT CAUGHT**, because the
  hand-spelled decoy kept its own quotes and the two strings could no longer collide. The arm was
  asserting about its own literal. Routed through `refusal_naming_of` the same mutation fires at
  199/201. Same shape as 27-01's `setEnv k ""` finding one level in: an assertion passing because its
  subject is absent, inside the guard written against exactly that.

- [Phase 27]: [27-02 CORRECTED, a committed measurement that was false] **`measured_pre_pool_block`
  5 → 7.** Blocks 0–5 of a from-scratch rig have NO PoolManager code, so the call returns the bare
  `0x` marker; blocks 6–7 have code and no pool, returning an ALL-ZERO WORD; block 8 is the first
  readable. Those are two DIFFERENT diagnoses and the earlier draft merged them — the exact pair
  `decode_word_token` exists to keep apart. Heights shift between deploys (21-02: 9, 11, 10), so
  what is durable is the ORDER of the three regimes, not the numbers.

- [Phase 27]: [27-02 DECIDED] **A capture that constructs a divergence must record BOTH "the chain
  moved" and "the two reads came apart", because neither implies the other.** `unpinned_differs`
  false means the divergence was never constructed and the artifact is void;
  `pinned_and_unpinned_disagree` false means both reads followed the head, which is the defect
  itself. A capture where the chain moved and both reads followed it satisfies the first and fails
  the second.

- [Phase 27]: [27-02 DECIDED] **The capture is an EXECUTABLE, not only a shell script.**
  `Chain.Read`'s wiring half (`read_pool_field`, `read_raw_word_token`, `block_param`) is
  unreachable from `cabal test` by construction, and an unexercised surface is this package's
  advertised-and-dead shape — measured three times at 22-03, 22-04 and 22-07. Its cabal stanza is
  `+0 packages` in the build plan but NOT `+0 dependency lines`: the first build failed `GHC-87110`
  naming two packages the library already depends on, and the comment states the narrower true claim
  rather than copying the sibling stanza's.

- [Phase 27]: [27-02 FINDING] **A structural grep's tokens are not interchangeable, and which one is
  load-bearing is measurable.** `the_suite_never_reaches_a_chain` names three. `web3-ethereum` IS a
  test-suite dependency, so the JSON-RPC method module can be imported today and only this scan
  stops it — that firing input COMPILED and was caught. `web3-provider` is NOT, so that import does
  not build at all and its firing input had to be a comment, which works only because the scan
  covers the whole file deliberately. One guards a state reachable in a line of Haskell, the other
  one reachable in a line of `.cabal`.

- [Phase 27]: [27-02 DECIDED] **A positive control built from a COPY OF THE SUBJECT beats a
  three-line bait.** `latest_appears_nowhere_in_the_read_layer` greps a seeded copy of the read layer
  beside a clean copy of it. OBSERVED: when the token is seeded into the real file, the control's
  third arm fires FIRST and says so more precisely than the main scan — "the real file already
  carries the token and the main arm below is about to report the same thing less clearly."

- [Phase 27]: [27-02 STATED GAP] **`chain-read-conformance.json` has an override
  (`CHAIN_READ_CONFORMANCE`, probed) and is NOT in the sentinel sweep.** The sweep COULD reach it, so
  it is recorded in `unswept_artifacts` with its own reason and that list's haddock now states the
  reason per entry rather than one blanket claim that would be false for this member. Folding it in
  means an `absorbed_by_design` entry, with a count and a reason, for every (leaf, sentinel) pair no
  check objects to.

- [Phase 27]: [27-01 MEASURED] **CHAIN-06's "nine sites" is wrong three ways, and each was measured
  rather than reasoned about.** It is TEN by its own pattern (`offchain/spec/types.md` is the tenth,
  a pasted RPC transcript). It is ELEVEN counting `offchain/rig/verify-rig.sh` — fourteen `cast`
  calls against a live rig, reached through foundry's `--rpc-url local` ALIAS, so it named neither
  the variable nor the authority and **no pattern built from those two tokens could ever have found
  it**. And the rule was implemented ZERO times, not nine: the only occurrence of `ETH_RPC_URL`
  under `offchain/` was a COMMENT in `deploy-rig.sh`. **Correct the requirement text at phase close.**
- [Phase 27]: [27-01 DECIDED] **A census term set is anchored to what the census MEANS, not to the
  tokens that happened to find the current members.** MEASURED both ways: the plan's pattern ("names
  the variable or the authority") found 10 sites BEFORE the rewiring and only 8 AFTER, because five
  of the six Haskell consumers stop naming either token the moment they name `resolve_endpoint`. A
  census on that pattern would have reported five correctly-fixed files as missing.
  `endpoint_census_terms` therefore closes over the resolver, the shell resolver's path, and the two
  shapes of REACHING a chain — and that last pair is what found `verify-rig.sh`.
- [Phase 27]: [27-01 FINDING] **`"cast call"` is a prefix of `"cast calldata"`.** It was a census
  term because `offchain/rig/README.md`'s hand-run chain-independence grep names it; on its first run
  it matched `CheatSwap/Encoding.hs`, whose haddock says the calldata is built by shelling to `cast
  calldata` — purely local, no endpoint. The 26-03 shape (`"828040"` contains `"82804"`) in mirror.
  Dropped: an endpoint flag is the anchored form. **README's grep still carries the bug** and has
  simply never met a file that says `cast calldata`.
- [Phase 27]: [27-01 FINDING, base] **`System.Environment.setEnv k ""` routes an empty value to
  `unsetEnv`.** OBSERVED: `setEnv "PROBE_VAR" "" >> lookupEnv` returns `Nothing`. So a check that
  sets a variable empty and asserts a default comes back drives the UNSET path twice — and the first
  draft of `an_empty_eth_rpc_url_does_not_resolve_to_the_empty_string` MEASURED GREEN against a
  deliberately unguarded resolver. A shell reaches the state easily (`export VAR=` leaves it present
  and empty). **A rule that must be tested at a value the process cannot install in its own
  environment is factored into a PURE function of that value**, with the value's reachability
  observed in a child process rather than assumed.
- [Phase 27]: [27-01 DECIDED] **A duplication a check compares is a checked agreement.** `bash`
  cannot import a Haskell module, so the default authority is stated once per language and the two
  statements are asserted byte-equal — the move `Fee.Split` and `Store.Key` already make for the pip
  denominator. The alternative (inlining the parameter expansion in three shells) would have been
  four statements, three of them unchecked.
- [Phase 27]: [27-01 DECIDED] **Existence and ORDER are separate assertions over the same subject.**
  OBSERVED that neither alone suffices: moving the chainId assertion below the first `--broadcast`
  fires only the order arm; deleting it fires only the existence arm. That is 26-03's finding, where
  an ordering gate written only as line numbers was structurally voided by 26-04's refactor while
  staying green.
- [Phase 27]: [27-01 DECIDED] **Prose inside the census's blast radius is DECLARED, never argued
  away.** `offchain/spec/types.md` and `offchain/rig/README.md` are `Transcript` sites and
  `offchain/test/Main.hs` is a `Census` site whose rule is the inverse of every other kind's — it
  must NAME the resolver and name none of `chain_reaching_terms`, which makes README's hand-run
  chain-independence grep executable. Instance 26 of prose caught by a pattern on this branch was
  hit during this plan; the prose moved, as it did the other 25 times.

Older decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting v4.0:

**v6.0 (Phase 24) decisions:**

- [Phase 24]: [24-06 DECIDED, from MEASURED M14] **the schema refuses the empty version, and the
  refusal is a NAMED check.** `text not null` does not forbid `''`, so `Gams.Version`'s abstract
  newtype — the primary defence — protects only the writers that go through Haskell. Migration
  `003_version_columns_nonempty.sql` adds `check (length(gams_ver) > 0 and length(conopt_ver) > 0)`
  under the name `model_run_versions_nonempty`, and the name is load-bearing rather than stylistic:
  SQLSTATE `23514` says only that SOME check refused, and `model_run` is free to grow other checks.
  The recorded evidence asserts the server's own message CONTAINS that name. OBSERVED against
  Postgres 18.4 on both columns independently, with a positive control that lands.
- [Phase 24]: [24-06 DECIDED] **a refusal exhibit that does not also record an ACCEPTANCE is not
  evidence.** "The insert raised" is satisfied by a dead connection, a malformed key, a `doc` that
  is not JSON and a missing table. `empty_version_rejected` therefore carries `control_accepted` and
  `control_rows_after` — the identical row with non-empty versions, which must land exactly one row
  — and both the shell gate and the in-suite check evaluate the control BEFORE the rejections.
  `rows_after` per attempt is the SERVER'S own count, because "an exception was raised" and "nothing
  was written" are different claims.
- [Phase 24]: [24-06 DECIDED, MEASURED by the sentinel harness] **a field the writer hardcodes is
  DELETED, never asserted.** The first version of the observation carried a per-column `attempted`
  that was the literal `True`; the harness reported all six of its mutations ABSORBED. Asserting it
  would have compared a constant to itself, which is 24-04's measured defect (a suite green with the
  library renamed underneath it). The honest per-column form is the ENTRY, compared to
  `Store.Schema.versions_nonempty_columns` in both directions, so a missing attempt is a set
  mismatch rather than a shorter list.
- [Phase 24]: [24-06 DECIDED] **`pg_isready` over a container's unix socket is not a readiness
  gate.** The postgres entrypoint runs a temporary bootstrap server on that socket during `initdb`,
  and `pg_isready` reports a server answering `FATAL: database "..." does not exist` as accepting
  connections. THREE consecutive captures died on the subsequent shutdown. The gate is now
  `pg_isready -h 127.0.0.1`, because the bootstrap server has no TCP listener — a discriminator,
  not a longer sleep. Pre-existing since 23-04 and invisible because it failed in the safe
  direction.
- [Phase 24]: [24-01 DECIDED, from MEASURED M2] **the GAMS version's discriminator is the banner's
  JOB NAME, not the shape of the version token.** The three real banners — the production run
  (`volume_path.gms`), the no-argument help banner (`?`, **exit 0**, version present three times,
  no model run) and the flag (`--version`, exit 6) — differ in exactly one field, and every one of
  them carries a perfectly well-formed `54.1.0`. So the rule is one equality: the job name must
  equal the basename of the `.gms` actually invoked. It rejects both wrong-subject banners without
  a denylist and keeps rejecting the ones nobody has met. A shape-first rule would accept the help
  banner. OBSERVED: with the equality removed, that banner parses to
  `Right (GamsVersion ("54.1.0","37378ce0"))`.
- [Phase 24]: [24-01 DECIDED, from MEASURED M3] **CONOPT is recognised by the SPACED-LETTER form
  and by scanning every line.** Both decoys carry the token `CONOPT`; only the true line carries
  `C O N O P T`. Position is refused as evidence because the true line was measured at buffer index
  38 in the hermetic probe and 47 in the production run. OBSERVED twice: relaxing the marker to the
  bare token makes the parser reject the TRUE line (its letters are spaced, so it has no bare
  `CONOPT` token at all — an unplanned finding worth keeping), and making the marker
  spacing-insensitive makes it accept the GAMS-side link version as `ConoptVersion "54.1.0"`.
- [Phase 24]: [24-01 DECIDED] **`Unclassified` is a FAILURE and 0 is the only `Solved`, and
  `gams_code_domain` names the mod-256 IMAGES.** GAMS reports 400/401/402/909 and an exit status is
  a byte, so a collision argument for the timeout codes made against the unfolded numbers would be
  about codes no caller ever observes; the domain holds 141/144/145/146. The domain is asserted in
  BOTH directions — non-membership of 124/137 alone is satisfied by a domain that shrank to nothing.
- [Phase 24]: [24-01 FINDING, the prose trap caught by a guard rather than by a review] **a haddock
  comment in `Gams/Exit.hs` reddened the very scan the same commit installed.** The word spelled
  c-a-t-c-h appeared in a sentence explaining why the fall-through is not success, and the
  no-fallback pattern matched it, naming the file and the line. The prose moved; the pattern was not
  relaxed. This is the eleventh instance of prose-inside-a-grep on this branch and the first where
  the guard did the catching — which is the argument for widening a scan's scope rather than the
  argument against it.
- [Phase 24]: [24-01 DECIDED, extending the plan] **the no-fallback scan's file set is asserted
  against the DIRECTORY, in both directions, with reasoned exemptions.** `Gams/Config.hs` is EXEMPT
  WITH A WRITTEN REASON (`fromMaybe <default> <$> lookupEnv` IS the `Store.Config` resolver idiom
  and no version value exists on that path), not omitted. 23-03 measured what a hardcoded list does
  alone: `Store/Schema.hs` sat unlisted for two commits with nothing red. NOTE the boundary —
  `aeson_storage_path` still has no such cross-check; `Gams/Artifact.hs` must be added there and
  plan 24-04 owns it.
- [Phase 24]: [24-01 MEASURED, correcting two inherited numbers] **the cold `cabal test` baseline
  was 111/111 at wall 71.8 s**, not the 97 s recorded in this file and in `24-RESEARCH.md` nor the
  66 s in the execution prompt. Six PURE checks took it to 117/117 at 87.8 s: +16 s, because the
  sentinel harness re-runs `core_checks` once per (leaf × sentinel) pair and pays every added check
  roughly 3250 times. Tier-B stub checks spawn subprocesses INSIDE that multiplier.

**v6.0 (Phase 23) decisions:**

- [Phase 23]: [23-05 DECIDED, the plan's own explicit fork] **`PGSTORE_DSN` is a NAMED GAP in an asserted `unprobed_overrides` list, NOT a registered `OverrideProbe`.** `probe_override`'s third assertion is that pointing the variable at an unresolvable value makes the CONSUMER fail NAMING that value. `PGSTORE_DSN`'s consumer is libpq, reached only through the client module and the capture executable, and **neither is reachable from `cabal test` by construction** — that is DB-03, and the three-token grep that must return 0 is its structural form. Both ways of manufacturing a subject were rejected: importing the client breaks DB-03 on the way to enforcing DB-02, and a `validate_dsn` written only to be probed is worse *because it looks right* — its rejection would prove that a function written to reject rejects. That is a registered-but-vacuous probe, the exact defect the sweep exists to catch, installed to close the sweep's own list. `probe_override` was NOT weakened. The two halves that ARE measurable (verbatim resolution, differs-from-default) are asserted, plus disjointness of the two lists and a both-directions check that every variable `Store.Config` names appears in exactly one of them.
- [Phase 23]: [23-05 MEASURED, upgrades BYTE-05 from a bound to an ORACLE] **the bare write path's damage is PREDICTABLE from its two mechanisms.** libpq's C-string escaper truncates at the first NUL (23-04) and `byteain` then decodes the legacy escapes — `\\` to one backslash, `\NNN` to one octal byte (23-01). `bare_path_prediction` composes them over `cm_bytes` from `Store.Types`, and the expected side never touches the artifact. It reproduces **all five returning corpus members exactly, in length AND digest** (`nul` 1→0, `crlf` 4→4, `trailing-newline` 2→2, `octal-escape` 6→3 `aAb`, `double-backslash` 4→3 `a\b`). The sentinel harness had reported `bare_out_len` and `bare_out_sha256` as absorbed and the plan permitted pardoning them; modelling the mechanism was the better answer and is the difference between recording that bytes were lost and predicting exactly which.
- [Phase 23]: [23-05 MEASURED, corrects 23-04's carried-forward budget input] **the sentinel harness enumerates 134 leaves of `store-conformance.json`, not 121.** 23-04's 121 is `jq 'paths(scalars)'`, which OMITS JSON nulls; `scalar_json_paths` treats a null as a leaf and mutates it. `sentinel_pair_floor` RE-MEASURED 2457 → **3250** by raising the constant until the harness reported what it reached, never by arithmetic; 134 × 6 = 804 possible, 793 exercised, the 11 difference being identity skips, so `3250 − 2457 = 793` confirms the four older artifacts still contribute exactly 2457. All five `artifact_field_floors` re-measured in that run and the four older ones came back UNCHANGED (20 / 110 / 151 / 130), which is what says none of them shrank while the new one was added.
- [Phase 23]: [23-05 FINDING, a guard registered and green for three plans had never been seen to reject] **research guard #7 (`aeson_round_trip_mutations_are_re_measured`'s "the round trip became the identity" arm) had no firing observation anywhere in the phase** until it was compiled into the nineteen-guard ledger. OBSERVED by pinning a vector whose round trip genuinely is the identity — the research table's own named input. Carry forward: a guard can sit registered, green and cited for three plans without anyone having watched it reject, and only building the ledger surfaces it.
- [Phase 23]: [23-05 FINDING, the phase's ONE unobserved guard] **research guard #13 (`PGSTORE_DSN` override) has no observation and cannot get one offline.** It is named as a phase-level finding rather than omitted. The only evidence the variable is honoured end to end is 23-04's capture, which exports it and gets a `server_version` back — real evidence, and not a `cabal test` observation. If a later phase introduces a DSN consumer reachable offline, that is the moment to move the entry into `advertised_overrides` — and the moment to be suspicious of any consumer introduced *in order to* move it.
- [Phase 23]: [23-05 MEASURED, the assertion a COUNT cannot make] deleting one key from `law_verdicts` reddens `store_conformance_verdicts_are_all_pass` as a SET mismatch **while `sc_law_count` still reads 8**. That is the demonstration, not the argument, that a skipped law is structurally unrepresentable rather than merely detectable.
- [Phase 23]: [23-05 DECIDED] the checksum-drift MESSAGE **is** asserted — for the FILENAME it names, from `expected_migrations`, and never for the words "checksum mismatch", which do not appear on that path. The arm reproduces 23-04's real defect (a server `NOTICE` recorded in its place), so it is a guard with a demonstrated catch rather than a decoration.
- [Phase 23]: [23-05, the FIFTH and SIXTH instances of prose inside a grep's blast radius] a FAILURE MESSAGE naming the postgres store module took the DB-free grep from 0 to 1. The credential pattern and its bait are therefore BUILT from fragments rather than written contiguously, for the same reason `purge_control_literal` and `aeson_bait_source` are. **Rule, now with six instances: any token a check greps for must not appear contiguously in a file that check reads — including in prose and including in failure text.**

- [Phase 23]: [23-04 USER RULING, implemented AND validated by measurement] the keyed path **REQUIRES a json value** — `model_run.doc` is `not null jsonb` derived from the same parameter as `raw`, and the server computes the row before it resolves the conflict clause, so `on conflict do nothing` does not save a non-json artifact. `Store.Memory` is TIGHTENED to match (rather than the server loosened) because **TIER B MUST PREDICT TIER C**: a law suite that passes against the reference store and fails against Postgres defeats the three-tier design, which is the only reason `cabal test` may run with no database. `law_first_writer_wins`'s second payload became `{"a":2,"note":"SECOND-SOLVE-DISAGREED"}` — still different bytes, so its discriminating power is unchanged — and the old non-json bytes became the probe of the new eighth law. **MEASURED: all 8 laws pass against `Store.Postgres` unchanged.** BYTE-01's arbitrary-bytes requirement is served by `byte_corpus`, which deliberately has no `jsonb` column.
- [Phase 23]: [23-04 DECIDED] `Store.Json` — a total, pure RFC 8259 recogniser behind a UTF-8 gate — is the predicate the server-free tier rejects with. Hand-written because every module under `offchain/lib/Store/` is in `aeson_storage_path`, and because a RECOGNISER builds no value and therefore cannot re-render a number or reorder a key. Its agreement with `jsonb` is **MEASURED per input** in the capture's `json_agreement` block, never claimed in prose. Added to `aeson_storage_path` in the commit that created it, per the rule 23-03 wrote down and then broke.
- [Phase 23]: [23-04 MEASURED, FALSIFIES the plan's own guard table AND the research] **`corpus[nul]` is `SilentlyCorrupted`, not `ServerRejects`.** Driven through `postgresql-simple`'s bare-`ByteString` path it goes in at **1 byte and comes back at 0**, with NO error — because `ToField ByteString` is `Escape`, which hands the value to libpq's C-string escaper, and **a C string ends at its first NUL**, so the parameter reaching Postgres is empty and there is nothing left for the encoding check to reject. The research measured a different path (a text literal not going through parameter escaping). The tag is corrected, and this **STRENGTHENS BYTE-05**: a total truncation is a worse silent corruption than `octal-escape`'s 6→3 and had been filed under the loud behaviour that proves the least. Any citation of "the secondary `Binary` observation" must name `high-byte` and `invalid-utf8`, which do raise. Also: `crlf` and `trailing-newline` round-trip CORRECTLY through the broken path and must never be cited as evidence for the wart.
- [Phase 23]: [23-04 MEASURED, refutes this executor's own prediction] the predicted `Store.Json` / `jsonb` **numeric-overflow divergence DOES NOT EXIST** — `1e1000` and `1e100000` were both ACCEPTED by the server. The one real divergence is a `\u0000` escape inside a string (RFC-valid, refused by `jsonb`, because Postgres text cannot carry a NUL). Both refuted probes are KEPT under their own names: a probe deleted for agreeing is a probe that can never disagree later.
- [Phase 23]: [23-04 MEASURED, confirms 23-03's source-read EMPIRICALLY] on checksum drift through `runMigrations` the stderr line is `migration FAILED: 001_model_run.sql (dir: …)` — the **SCRIPT NAME**, exactly as 23-03 read out of `Migration.hs:181`, and not the words "checksum mismatch". `checksum_drift_stderr` is recorded for a human reader and **23-05 must not assert on its text**; the exit code (`1`, from the runner's own `exitFailure`) is the observation.
- [Phase 23]: [23-04 MEASURED, strengthens the plan] an exclusion observation needs its RELEASE observation. `second_migrator_try_lock false` / `applied 0` against an already-migrated database is satisfied by a migrator that could never apply anything, by a closed connection, and by a directory with nothing new in it. The probe directory therefore carries a THIRD migration and the lock is measured again after release: `after_release_try_lock true`, `after_release_applied 1`. Only that pair says the lock EXCLUDED work that would otherwise have happened.
- [Phase 23]: [23-04 FINDING, a guard PROBE can itself be vacuous] the docker-absent refusal probe did NOT fire on its first attempt: a `chmod 000` `docker` shim placed first on `PATH` is SKIPPED by bash's PATH search, the real binary was found, the capture ran to completion and the artifact CHANGED. It was caught only because the artifact digest was compared before and after rather than the exit code being read alone. The valid probe builds a 2750-entry symlink farm of `/usr/bin` with `docker` omitted and verifies `command -v docker` is empty BEFORE invoking the script. Guard then fired: exit 1, message naming `docker`, artifact byte-identical.
- [Phase 23]: [23-04 MEASURED, validates a design choice by accident] the capture's **non-default host port `55433` is not taste** — `docker ps` during this plan showed another project's `postgres:18-alpine` bound to `0.0.0.0:5432` on this very machine. On the default port the capture would have connected to a foreign database, migrated it, and reported success.
- [Phase 23]: [23-04 DECIDED, corrects a self-contradiction in the plan] the artifact FILE is written exactly ONCE, atomically, at the end; only the completeness FLAG starts `False`. The plan's "write `sc_complete` `False` FIRST" taken literally means the tool replaces the committed evidence with an empty skeleton before it has produced any — the precise failure the capture scripts' restore-on-failure shape exists to prevent, and forbidden by this plan's own standards.
- [Phase 23]: [23-04 MEASURED, 23-05's budget input] `store-conformance.json` has **121 LEAVES**, 70 of them the corpus block (7 members × 10 fields, the plan's own prescribed shape). At ~6 full `core_checks` re-runs per leaf the sentinel harness must be budgeted explicitly; consider ONE iterating check over the corpus array rather than per-field checks. The number is reported rather than trimmed — trimming a recorded field to make a harness cheaper is how fields stop being asserted.
- [Phase 23]: [23-03 MEASURED, the count every later v6.0 plan compares against] the suite is **98/98, FAIL count 0** — 23-02's 96 total plus EXACTLY the 2 checks 23-03 registered, with BOTH deliberate reds closed by the single file `offchain/lib/Store/Postgres.hs`. 23-02's anti-control C2 predicted this to the check. Counts taken from the BUILT TEST BINARY, not from `cabal test`.
- [Phase 23]: [23-03 MEASURED, a BUG in the research's AND the plan's own prescribed code] `execute` / `execute_` **THROW** on a statement that returns columns — `finishExecute` raises `QueryError "execute resulted in 1-column result"` on `PQ.TuplesOk` (`Internal.hs:408-428`). So `execute_ con "select pg_advisory_lock(872304)"`, the form BOTH the research's §Code Examples and 23-03's task 2 prescribe, compiles cleanly and throws at the FIRST acquisition. Both lock statements go through `query` and consume the row: `[Only ()]` for the void-returning blocking lock (`FromField ()` exists and requires exactly `voidOid`), `[Only Bool]` for try and unlock. **Never use `execute_` for a `select` run for its side effect.**
- [Phase 23]: [23-03 MEASURED, source-read, binds 23-05] on checksum drift through `runMigrations` the payload is `MigrationError name` — the **SCRIPT NAME** (`Migration.hs:181`) — NOT the string `"Checksum mismatch"`. That wording belongs to the separate `MigrationValidation` path (`:239`), which the runner does not take. A check asserting on the drift payload TEXT would be asserting on a filename. The observation that counts is `echo $?` == 1 either way.
- [Phase 23]: [23-03 MEASURED, source-read] `postgresql-migration` applies **EVERY entry** in the migration directory — `scriptsInDirectory dir = sort <$> listDirectory dir` (`Migration.hs:155-158`), no extension filter anywhere on the path. A README or an editor backup dropped into `offchain/migrations/` is read and handed to `execute_` as SQL. `migration_list_is_ordered_and_gapless` therefore asserts the directory's WHOLE contents against the manifest, in both directions, and both arms were OBSERVED firing (a rename names both violations in one message; a `[1,3]` version list fires the gapless arm alone).
- [Phase 23]: [23-03 FINDING, a stale measurement inherited as fact by four documents] the research, the plan, 23-01's summary and 23-02's summary all state `purge_file_floor` is **36 against exactly 36 scanned files, zero slack**. At execution time the scan was **41** — waves 1 and 2 added five `.hs` files — so the stated consequence ("the first `.sql` reddens the floor immediately") was already FALSE; only the extension census would have fired. Re-measured to **45** (36 hs + 7 sh + 2 sql) and the block now records the RULE for when to re-measure, not just the number. It was measured three times and wrong twice, once because it was taken before the commit's own new module existed.
- [Phase 23]: [23-03 OBSERVED, the anti-control that matters] **declaring an extension is NOT scanning it.** With `.sql` in `purge_known_extensions` but NOT in `purge_scanned_extensions`, a seeded `0x`-prefixed 64-hex literal in a tracked `.sql` file is INVISIBLE to the purge — the floor fires first (42 < 44), and lowering the floor as well makes `sc3_literal_purge` **PASS with the literal on disk**. Two edits, each looking reasonable alone. This is why `.sql` went into BOTH lists, and it is what pins the guard-#19 FAIL to the SCAN rather than to the declaration.
- [Phase 23]: [23-03 CARRIED FORWARD, a real incompatibility 23-04 must RULE on] `model_run.doc` is `NOT NULL jsonb` derived from `raw`, so every artifact on the keyed path must be valid JSON — and `law_first_writer_wins_on_the_identity_triple` (`Store/Laws.hs:298`) writes the non-JSON bytes `SECOND-SOLVE-DISAGREED` as its second put. Against `Store.Postgres` that statement raises `invalid input syntax for type json` **before the `on conflict` clause is reached** (Postgres computes the row before resolving the conflict); against `Store.Memory` the same law passes. NOT papered over by editing wave 2's fixture. 23-04 chooses: the disagreeing payload becomes a disagreeing JSON *document* (it is the SOLE kill site for the last-writer-wins mutant, so it must still differ in its bytes), or the keyed surface stops requiring JSON. Recording the `SqlError` as the law's verdict would record a schema decision as a store defect.
- [Phase 23]: [23-03 FINDING, the pattern's TENTH instance and now also its INVERSE] prose in the grep's blast radius struck again on the first attempt in a brand-new file: `Store/Postgres.hs`'s haddock SAYING the `…Simple.Binary` module does not exist was counted by the acceptance grep asserting that import is absent. And the INVERSE appeared for the first time: `Store/Schema.hs` was created in 23-03 task 1 and spent two commits **absent from `aeson_storage_path`** — a storage module BYTE-03's scan did not read. The usual defect is a guard's scope SHRINKING; this is the scope failing to GROW, it is quieter, **nothing reddens**, and it was caught only by the plan's own self-check. A glob would have caught it and would have lost the property the named list exists for.
- [Phase 23]: [23-02 MEASURED, the count every later v6.0 plan compares against] the suite is **94/96** — the 23-01 cold baseline of 91 plus EXACTLY 5 new checks, with 2 RED BY DESIGN. With a clean stub `offchain/lib/Store/Postgres.hs` on disk it is **96/96**, which is what 23-03 lands on. Counts were taken from the BUILT TEST BINARY, not from `cabal test`: `cabal test` buffers the runner's stdout and printed `91/91 checks passed` on one invocation and nothing on the next, so a step that reads `cabal test | tail -3` can silently record no count at all.
- [Phase 23]: [23-02 OBSERVED, all seven laws, with the correct store as the CONTROL column] every law in `Store.Laws` was seen returning `Left` against a named wrong store: a `byteain` blob write (`member octal-escape went in at 6 bytes and came back at 3 bytes` — the MEASURED PG 18.4 corruption reproduced), a phantom `get_blob`, a key dropping `key_scheme`, a key dropping `model`, last-writer-wins, and a no-op `put`. **HONEST NEGATIVES:** the `key_scheme`-dropping mutant moves EXACTLY TWO laws and leaves the other five untouched (23-01's finding, reproduced through the law set itself); `law_key_scheme_orphans_rather_than_matching` does NOT fire against a store that stores NOTHING, so it is evidence only alongside the round-trip and the two-scheme insert; and last-writer-wins has a SINGLE kill site, which Phase 25's determinism claim rests on.
- [Phase 23]: [23-02 FINDING, corrects the plan] the corpus BEHAVIOUR-TAG set does **not** discriminate deleting `octal-escape` — `double-backslash` carries the same `SilentlyCorrupted` tag, so all three classes survive and the only surviving instrument was `length == 7`, a count defeated by substitution. `expected_corpus_members` (the member NAME set, both directions, ordered ahead of the count) is what actually caught the deletion.
- [Phase 23]: [23-02 DECIDED, strengthens the plan] `aeson_storage_path` names **SIX** files — every module under `offchain/lib/Store/`, with NO exemptions — not the plan's four. `Store/Types.hs` was to be exempted, and measurement showed its haddock was the ONLY thing under `offchain/lib/Store/` matching the pattern at all, on two lines SAYING the import is absent. Exempting a storage module because its comments trip the guard is the scope-shrinking defect; the prose was reworded instead.
- [Phase 23]: [23-02 MEASURED, unsatisfiable gate] the plan's "the suite fails on exactly ONE check" **cannot hold**. `sentinel_falsification_harness` carries an explicit `expect (null baseline)` that refuses to certify against a failing suite, so ANY deliberate red costs TWO FAIL lines. The harness was NOT weakened and no baseline-exemption list was added. Related: a red baseline also EMPTIES the harness — the run drops from ~75s to ~8s because the reader set collapses to the single always-failing check. Do not read a fast harness run as a fast suite.
- [Phase 23]: [23-02 FINDING, the pattern is now nine-times-over and deserves a pre-commit check] **prose is inside the grep's blast radius**, three more times in one plan — `Store/Laws.hs` naming the aeson module path that its own scan looks for; `Store/Types.hs` likewise; and worst, `store_laws_run_against_the_memory_store`'s haddock spelling `Store.Postgres` and the require-a-database variable while explaining that they are absent, which is EXACTLY the acceptance grep. A first fix reintroduced the token inside the sentence warning about it, caught only by re-running the grep.
- [Phase 23]: [23-02 PROCEDURE, standing rule] restore a mutated file from a SAVED COPY, never from `git checkout -- <file>`, whenever that file also carries uncommitted work. `git checkout --` on `offchain/test/Main.hs` after a pattern mutation restored it to HEAD and deleted ~170 lines of uncommitted implementation; it was caught only because the before/after digest comparison did not match.

- [Phase 23]: [23-01 MEASURED, the cold baseline every later v6.0 plan compares against] `cabal test` = **91/91 checks passed**; `cabal build --enable-tests -j all` exit 0 with **0** `offchain/` warning lines; `find offchain/{lib,app,test} -name '*.hs' | wc -l` = **28** before, **32** after; `find offchain -name '*.sql' | wc -l` = **0**, so `sc3_literal_purge`'s extension census and its zero-slack `purge_file_floor` of 36 are still untouched. STATE.md's 91/91 and the CI header's 78/85 were NOT inherited — both were re-measured cold. **`cabal build -j all` WITHOUT `--enable-tests` is VACUOUS** (it exits 0 against a non-compiling test suite) and was never used as evidence.
- [Phase 23]: [23-01 MEASURED, confirms the research rather than contradicting it] `plan.json` set-diff puts the install plan at **152 → 158 units (+6)**. `postgresql-simple` **0.7.0.1** is +4 (`Only-0.1`, `postgresql-libpq-0.11.0.0`, `postgresql-libpq-configure-0.11`, itself); `postgresql-migration` **0.2.1.8** is +2 (itself, `cryptohash-md5-0.11.101.0`); **`crypton` 1.0.6 is +0 — it is in BOTH sets**, because `web3-crypto` already pins `crypton <1.1`. Zero `Downloading` lines. `cryptonite` units in the resolved plan: **0**.
- [Phase 23]: [23-01 OBSERVED, BYTE-02 is a compile error and it was seen firing] `probe :: DerivedDoc -> DerivedDoc -> Bool ; probe = (==)` fails with `[GHC-39999] No instance for 'Eq DerivedDoc'`, and an `escape_hatch :: DerivedDoc -> Artifact` written in a DIFFERENT module fails with `[GHC-01928] Illegal term-level use of the type constructor`. **The plan's stated recipe could not fail** — it asked for `deriving Eq` AND the probe together, which compiles. Measured as a PAIR instead: probe alone → exit 1, probe WITH the instance → exit 0. Without that anti-control, a compile error does not tell you WHICH missing thing caused it.
- [Phase 23]: [23-01 OBSERVED, binds 23-02's law set] `Store.Memory` keyed on the FULL `(model, key_scheme, key)` triple orphans correctly: a lookup under superseded scheme 2 returns `Nothing`, and the same `(model,key)` under scheme 2 INSERTS without disturbing scheme 1. The negative control — keying on `(model, key)` alone — **compiles**, returns the scheme-1 row for a scheme-2 lookup, and SILENTLY DROPS the second insert. **HONEST NEGATIVE: only the superseded-scheme lookup and the two-scheme insert discriminate. Round-trip, first-writer-wins, blob-verbatim and label arms are all UNCHANGED under the mutant** — a law suite without a cross-scheme lookup would pass against a store that has no `key_scheme` at all.
- [Phase 23]: [23-01 DECIDED, deviation from the research sketch] `DerivedDoc` wraps `Text` (the `doc::text` rendering), NOT `Data.Aeson.Value`. Identical type-level guarantee, and it keeps `Data.Aeson` off the storage path that BYTE-03's own grep polices from 23-02. The `doc` column is still `jsonb`; only the Haskell-side view changes.
- [Phase 23]: [23-01 FINDING, the eighth self-contradicting-criterion instance in this repo] Three of the plan's acceptance greps counted matches in HADDOCK, not code — `cryptonite` (the plan prescribed a comment containing the token it then forbade), `octal-escape`, `DerivedDoc(..)`, and the credential grep (2 hits, both on the word "password" in comments SAYING there is no password). The last is substantive: DB-02's planned `no_credential_is_present_in_a_tracked_file` check greps exactly those tokens with a positive control, so a comment asserting its own cleanliness would have reddened it. **Prose is inside the grep's blast radius.** Also unsatisfiable as written: `grep -c 'lookupEnv' Store/Config.hs == 2`, since the import line alone makes the floor 3.
- [Phase 23]: [23-01 FINDING, gsd-tools is not safe on this STATE.md] `gsd-tools state advance-plan` errors (`Cannot parse Current Plan or Total Plans in Phase`) and `state update-progress` rewrote the frontmatter to `milestone: v2.0`, 25 phases / 37 plans by scanning EVERY phase directory on disk — folding the v1.0–v5.0 tracks, which this file says are separate and never renumbered, into v6.0. Reverted; the v6.0 progress block is maintained BY HAND.
- [Phase 26]: [26-02 CONFIRMED, the 23-01 finding RECURS] `gsd-tools state advance-plan` errored identically (`Cannot parse Current Plan or Total Plans in Phase`) and `state update-progress` again rewrote the frontmatter to `milestone: v2.0`, `milestone_name: milestone`, a `status` line made of a stray sentence fragment, and 25 phases / 50 plans / 47 complete by scanning every phase directory on disk. Reverted by hand at 26-02's closeout and the v6.0 counters set by hand (15 -> 16 of 18). `state record-metric` and `roadmap update-plan-progress` are SAFE and were used. `requirements mark-complete` is SAFE and was used. **Do not run `state update-progress` or `state advance-plan` against this file.**
- [Phase 26]: [26-03 FINDING, the "safe" list is WRONG and this is the SEVENTH occurrence] `gsd-tools state record-metric` ALSO rewrites this frontmatter to `milestone: v2.0`, `milestone_name: milestone`, a `status` line made of a stray prose fragment, 25 phases / 50 plans / 48 complete, and it reverts `stopped_at` and `last_activity` to older values. 26-02's own note lists it as SAFE and the 26-03 execution brief repeated that. **BISECTED at 26-03 on a scratch copy, one command at a time, checking line 3 after each:** `state record-metric` -> `milestone: v2.0`; `roadmap update-plan-progress 26` -> `milestone: v6.0`; `requirements mark-complete FEE-01` -> `milestone: v6.0`. So the culprit is `record-metric` alone, and the other two are genuinely safe. The metrics row it appends is CORRECT and worth having -- it also writes the duration without the `min` suffix every other row carries -- so the rule is: run it, then restore the frontmatter by hand and fix the units. **Do not run `state update-progress`, `state advance-plan` or `state record-metric` against this file without restoring the frontmatter afterwards.**

- [18b-01 MEASURED, supersedes 18a's number]: N=128 batch gas is now **execGas 3,231,765 + intrinsic 21,000 + EIP-2028 calldata 23,000 = 3,275,765 TOTAL**, a **+28,313 (+0.87%)** move from 18a's 3,247,452. The encoder adds 2 mstores per element plus memory expansion for the 8256-byte buffer; calldata gas is unchanged (the INPUT did not change). Still 3.05x under MCAL-01's 10,000,000 ceiling and well inside the plan's 3,400,000 stop-and-investigate band.
- [18b-01 MEASURED, the honest negatives — record these rather than the kill count alone]: (a) the **element-base-shift mutant (`base = 32 + 64*i`) is BLIND at N=0** — `test__unit__emptyReturnIsExactlySixtyFourBytes` stayed GREEN under it, because with no elements there is nothing to misplace and the total is 64 bytes either way. Killable only at N >= 1. (b) The **stride mutant (`64 + 32*i`) is blind at N <= 1** — OBSERVED directly: `test__unit__oneAndTwoElementReturnsAreByteExact` reddened at its **N=2** assertion while its N=1 assertion passed, since i=0 makes `64 + stride*i` independent of the stride. (c) The **dropped-outer-offset-word mutant IS killable at N=0** (32 bytes vs 64) — it and the base-shift mutant are COMPLEMENTARY, which is why both are run. A corpus that is N=0-only, or N<=1-only, would silently miss real encoder bugs.
- [18b-01 MEASURED, binds any future all-invalid corpus]: the `(false, id)` leak mutant is **NOT killable by an all-invalid batch on a fresh registry** — `test__unit__allInvalidBatchReturnsAllFalseZero` stayed GREEN under it, because `id` never leaves 0 there, so `(false, id)` IS `(false, 0)`. The SEEDED mixed corpus is the SOLE kill site. An all-invalid corpus alone would have recorded a fake pass.
- [18b-01 DECIDED, equivalence-checked and NOT counted as a kill]: the pure allocation-REORDERING mutant is **unconstructible**, and for a stronger reason than the bump-allocator argument the plan anticipated: moving the buffer allocation inside the loop makes the trailing `@evm_return(out, ...)` fail to compile with `error: unresolved identifier 'out'` (OBSERVED). Any reordering that keeps the return reachable requires `out` in the outer scope before the loop, so the before-the-loop ordering is enforced by SCOPING, not merely by convention. The under-allocated-buffer mutant carries the allocation-hazard evidence instead. **Kill count is 6, not 7.**
- [18b-01 CORROBORATED, HARD REQUIREMENT for the Haskell peer]: solc's `abi.decode` **REJECTS a non-canonical success word outright** — under the `success = 2` mutant the entire 18a suite reddens with `EvmError: Revert`, not with wrong values. A lenient Haskell decoder would accept a truthy 2. The two consumers would then disagree about the same bytes, which is exactly why the canonical-bool guarantee is a CONSUMER-SIDE CONTRACT and not a test detail.
- [18a-01 MEASURED, gas number SUPERSEDED at 18b-01 — see above]: N=128 batch gas is **execGas 3,203,452 + intrinsic 21,000 + EIP-2028 calldata 23,000 = 3,247,452 TOTAL**, against MCAL-01's 10,000,000 ceiling (3.08x headroom). This is 1.10x the research's UNVERIFIED ~2.94M estimate — same order of magnitude, so the loop does no unintended work. Pinned by `test__unit__maxBatchGasUnderBudget`, whose success/count/slot assertions all precede the threshold check so a passing `assertLe` cannot certify an early revert.
- [18a-01 DISCHARGED, was ACTION REQUIRED]: the M5 counter-hoist mutant is now a **REAL KILL**, exactly as 17-01 predicted. Observed RED: `id contiguity: third valid order at C+2: 0 != 2381976974094761317277030730967468670979` — slot C+2 holds ZERO because the skipped middle tuple consumed the id and pushed valid_B to C+3. The `orderCount` assertion also reddens (8 != 7) but is NOT discriminating; a count-only corpus would not have pinned where the order landed.
- [18a-01 FINDING, binds every future mutation gate]: **forge reports only the FIRST failing assertion per test**, so assertion ORDER is mutation-evidence design. The plan's original ordering had `orderCount` mask the contiguity red under M5, which would have been recorded as a count-only kill. Place the DISCRIMINATING assertion first. Fixed at `eac83f7`.
- [18a-01 EMPIRICAL, supersedes SC-6's original wording]: deleting the validation branch **cannot** produce a batch revert — `pack_vol_order` is pure shl/&/| and `@evm_sstore` cannot revert here, so an unvalidated tuple is STORED WRONG and COUNTED. Observed: `assertTrue(ok, "MCAL-04: no batch-revert observed")` stayed GREEN under M-VAL while three value assertions reddened. This also CORROBORATES the MCAL-04 structural enumeration: M-VAL drove arbitrary unvalidated tuples through the entire post-validation path and produced no revert, so no step's totality was contradicted. SC-6 was corrected at `56c4721` before execution; the correction is now backed by measurement.
- [18a-01 DECIDED, HARD REQUIREMENT for the Haskell peer]: guard 1 requires the **CANONICAL array offset `0x40` at byte 36**. The ABI spec permits a non-minimal offset, so a bespoke encoder that legally pads the head is REJECTED with an empty revert. Deliberate — it closes the PHANTOM-ORDER hole: the module reads elements at a fixed `100 + 32*i`, which is sound ONLY because the offset is pinned.
- [18a-01 DECIDED]: `width` is read UNMASKED. It is the TOP input field, so any bit >= 128 inflates it past `0xffffff` and validation rejects it — dirty-high-bit rejection with zero new arithmetic. Masking to `& 0xFFFFFF` would map two distinct calldata words onto one stored order, a malleability seam for the Phase 19 differential.
- [18a-01 DECIDED]: MAX_BATCH (128) is checked FIRST, before the three calldata guards, because Plank's `*` and `+` are CHECKED — an adversarial `count` near 2^256 would panic 0x11 inside `32 * count` before the size comparison ran, muddying MCAL-02's mutation evidence with panic data instead of an empty revert.
- [18b-01 baselines]: `make compile-plank` 13 ok / 0 failed / 0 skipped (UNCHANGED — the return type adds no entrypoint); `make test` **120 pass / 4 pre-existing fails** (was 112 / 4; +8 = the new `VolOrderManagerReturnEncodingTest`). The 4 reds are the vol-type track's `src/types/pos_spec/` harness failures, unchanged and not ours.
- [18a-01 baselines, count SUPERSEDED at 18b-01]: `make compile-plank` 13 ok / 0 failed / 0 skipped (UNCHANGED — the batch adds no new entrypoint); `make test` **112 pass / 4 pre-existing fails** (was 99 / 4).
- [17-01 MEASURED, binds 18a/19]: `v3::storage::array_slot` uses Plank's CHECKED `+`, so `keccak(base) + id` PANICS (0x11) rather than wrapping. Addressable ids cap at `2^256-1 - keccak(SLOT_ORDERS_BASE)` (~6.5e74). VORD-05's "no revert for a nonexistent id" therefore holds for every REACHABLE id (counter-assigned, +1/tx), which is the property it exists to establish. NOT worked around: `array_slot` is another track's file and masking the id module-side is exactly the ring-mask corruption M1 forbids. Boundary pinned as a VALUE instead.
- [17-01 DECIDED, ACTION REQUIRED IN 18a]: the "counter store hoisted above validation" mutant (M5) is an EQUIVALENCE-CHECKED NON-KILL in the strict path — `validate_order_strict` reverts, and a revert rolls back the prior SSTORE, so the hoist is unobservable. It becomes NON-equivalent in 18a, where the batch SKIPS instead of reverting: a hoisted store would advance the id on a skipped tuple. **18a MUST re-run this mutant and expect a RED.**
- [17-01 DECIDED]: both entrypoint selectors pinned in `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — `create_order(uint88,uint24,uint16)`=0x6501fe94 (dispatched) and `create_orders(uint256,uint256[])`=0x81357911 (DECLARED, falls through to `revert_empty()` until 18a). This is what breaks the 17<->18a circular dependency. `test__unit__batchSelectorNotYetDispatched` locks the current fall-through and must be updated when 18a dispatches it.
- [17-01 EVIDENCE]: the id-65536 test is the SOLE kill site for the ring-mask mutant — every other test stayed GREEN under it, because `& 0xFFFF` is a no-op at ids 1 and 2. Small-id tests alone were provably insufficient; this is measured, not argued.
- [17-01 baselines]: `make compile-plank` 13 ok / 0 failed / 0 skipped (was 12); `make test` 99 pass / 4 pre-existing fails (was 87 / 4), MODAL — see the nondeterminism blocker below. `PLANK_SKIP` stays EMPTY (MVER-04 corrected at af488a0: a module that compiles never enters the rescue queue).
- [16-01 DECIDED, binds 17/18a]: `validate_order` is a bool-returning CORE with `validate_order_strict` as a thin reverting wrapper. Phase 17 calls the wrapper, Phase 18a calls the core — MCAL-04's "same validation both paths" is true by construction, not by assertion. Do not collapse them.
- [16-01 DECIDED]: `TICK_SPACING = 20` pinned inside `build_vol_order` (one place). `vol_range_width_is_complete` ANDs `tickSpacing > 0`, so a zeroed field makes the composed validator IDENTICALLY FALSE — under which an all-reject validator passes a naive fuzz trivially. Mutant M5 proves this is observable. All order construction in 17/18a MUST go through `build_vol_order`.
- [16-01 MEASURED]: stored word is the FULL 152-bit `(width << 128) | (20 << 104) | (strike << 16) | skew`. NOTE this SUPERSEDES the earlier v4.0 roadmap-time assumption of a 128-bit `skew|strike|width` subset with tickSpacing deferred, and supersedes the "REDUCED width check (no tickSpacing operand)" note below — the full `vol_range_width_is_complete` is reused verbatim, tickSpacing included.
- [16-01 MEASURED]: accept sets, verified against the real predicates — skew [1, 65534] (1 and 65534 ACCEPTED, do NOT revert), width [1, 0xffffff], strike [1, 2^88-1]. The requirement's earlier "both endpoints revert" wording was wrong.
- [16-01 baselines]: `make compile-plank` 12 ok / 0 failed / 0 skipped (was 11); `make test` 87 pass / 4 pre-existing pos_spec fails (was 74 / 4).
- [16-01 pattern]: when a roadmap-named mutation site lives in another track's file, apply the identical semantic flip at OUR call site by inlining the flipped predicate, and record the substitution rationale in-file. Used for M3 (skew comparison, home is SpreadTickAssimetry.plk:12).
- [v4.0 roadmap]: 4 phases from the research SUMMARY skeleton; VORD-04 mapped to Phase 17 ALONE (Phase 16 delivers the pack/unpack layout its store consumes, but the requirement is mapped once).
- [v4.0 constraint]: runtime `while` only — `inline while` (comptime unroll) is parsed but compiler-rejected in v0.1.1; the batch loop is a plain bounded `while i < count`, not unrolled, not recursive.
- [v4.0 constraint]: best-effort containment is a pure-validation pre-check (branch-only, no self-call), NOT a self-`@evm_call` boundary — `create_order` has no revert-prone dependency call.
- [v4.0 constraint]: `array_slot(base,id) = keccak256(base)+id` reused verbatim from `v3::storage`, WITHOUT the RealizedVolatility ring's 16-bit wraparound mask (load-bearing for a ring, corruption-causing for a monotonic-id registry). Zero arithmetic in the module.
- [v4.0 constraint]: two peer-dependent placeholders (`MAX_BATCH` value; typed `(bool,uint256)[]` return shape) — NAMED placeholders with test structure written against them; never guessed, never blockers. Peer = rpc_api track `mv15a18k` (PR #9).
- [v4.0 constraint — **SUPERSEDED at 16-01, do not use**]: ~~stored word is the 128-bit create_order-native subset (`skew|strike|width` at offsets 0/16/104, bits 128–151 zeroed, `tickSpacing` deferred with pricing); width validated by the REDUCED check `width in (0,0xffffff]` (no `tickSpacing` operand).~~ Phase 16 measured the real layout: the FULL 152-bit word with `tickSpacing = 20` live in bits 104..127, and the FULL `vol_range_width_is_complete` (tickSpacing conjuncts included) reused verbatim. See the 16-01 MEASURED entries above.
- [carried, v3.0]: `make compile-plank` passing is NOT evidence — Plank does not type-check code unreachable from `run{}`. Proof = CALLING the module through FFI-deployed bytecode.
- [carried, v3.0]: `deployPlank` recompiles the `.plk` fresh on every test run via FFI — a mutation battery does NOT need `make compile-plank` between mutants; the mutant reaches the deployed bytecode as long as tests use `deployPlank` (re-check if any test ever deploys from a prebuilt artifact).
- [carried, v3.0]: observed-RED discipline — mutant applied → cache/fuzz cleared → verbatim RED recorded → restored sha256-identical → green; equivalence-masked mutants documented, never counted. Keep a NON-FUZZ unit anchor alongside each fuzz (cache-independent by construction). Reference mock must NEVER echo Plank's own output (vacuous differential).
- [carried, v3.0]: one shared decoder, not a fourth copy — `test/.../TimepointDecoder.sol` precedent; v4.0 promotes a single `VolOrderDecoder` and reuses it.
- [Phase 19]: [19-01 MEASURED] The module and the independent mock AGREE at tol 0 across interleaved (create_order | create_orders) sequences — orderCount, every stored word, and return bytes — over a seeded 8-step anchor ending at id 12 and a 256-run cold-cache fuzz. Step 3 (strict path resuming on a BATCH-advanced counter) is the property 18a/18b structurally could not test; VolOrderManagerMod satisfies it. No disagreement observed.
- [Phase 19]: [19-01 FINDING, binds every seeded differential] vm.store seeding moves the COUNTER, not the orders: ids in [1, seedBase] are legitimately EMPTY on both sides. The plan's after-every-write helper asserted 'pw != 0' and 'tickSpacing == 20' over all of [1, pc] and would have failed on every seeded test. Agreement is asserted over the full range; live-order SHAPE only for id > seedBase, with assertEq(pw, 0) below it (which also catches phantom-order seeding bugs).
- [Phase 19]: [19-01 BLOCKING, affects any test-side NatSpec] solc parses a leading at-sign + word in NatSpec as a doc tag: the field-at-bit layout shorthand triggers 'Error (6546): Documentation tag @128 not valid for contracts' and the file will not compile. Use prose in NatSpec; the shorthand survives in string literals, which is where failure messages need it.
- [Phase 19]: [19-02 CONFIRMED, the milestone's strongest encoder evidence] cast abi-encode (alloy) INDEPENDENTLY confirms 18b's pinned return layout from a THIRD encoder outside this repo: offset 0x20 at byte 0, length in ELEMENTS, static tuples at stride 0x40, total exactly 64+64N, and the N=0 case at exactly 64 bytes. Two independent encoders (solc at 18b, alloy here) now agree with the hand-rolled Plank encoder.
- [Phase 19]: [19-02 SCOPE, must NOT be blurred in the exit record] alloy proves the return bytes are STANDARD-ABI CONFORMANT. It does NOT exercise the Haskell consumer's decoder. The cross-language gap with peer mv15a18k remains OPEN and is kept visible in four places: the fixture's _scope_limit and _peer_status fields, 5 NOT-PEER-VERIFIED placeholders, and the dedicated test__unit__peerHaskellBytesAreStillAnOpenGap.
- [Phase 19]: [19-02 MEASURED, honest negative] test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes is NOT an anti-inaction gate — it stayed GREEN under a 5-to-4 fixture case-count drop because it reads expected[0] only. The count gate lives solely in the differential and the peer-gap tests. A refactor keeping only the N=0 test would silently lose falsifiability.
- [Phase 19]: [19-02 FINDING, binds remaining Phase 19 plans] the acceptance criterion 'git diff --stat src/ produces NO output' is UNSATISFIABLE at execution time — the pre-existing uncommitted src/lib/exposure/VegaIssuanceLib.plk draft (which CONTEXT itself defers) always shows. Fifth instance of the self-contradicting-criterion pattern. Scope the criterion to src/**/pos_spec instead; the real property (pos_spec byte-untouched, module sha256 be196dcb...cc9b8787) was verified directly.
- [Phase 19]: M8's N=0 blindness belongs to the ELEMENT-BASE SHIFT, not the head-drop — established by measuring BOTH variants
- [Phase 19]: M9 is also N=0-blind and all-invalid-blind; its kill needs an N>=1 corpus containing a VALID tuple
- [Phase 19]: The three calldata guards have a SINGLE point of failure in VolOrderManagerBatchGuardTest; wave 1 structurally cannot cover them
- [Phase 19]: [19-05 MEASURED, replaces the stale 17-01 record] `make test` = 102 passed / 18 failed / 120 total (44 suites); `make compile-plank` = 11 ok / 2 failed. Every red ATTRIBUTED: 14 exposure setUp() reverts (the uncommitted src/lib/exposure/VegaIssuanceLib.plk draft, `unresolved identifier 'VolOrder'`, propagating through deployPlank/FFI), 4 vol-type track under test/types/pos_spec/, **0 under test/pos_spec/**, 0 TickVolatility. The 13->11 entrypoint drop and 4->18 fail rise vs 18b are the exposure draft landing in between, NOT a Phase 19 regression: Phase 19 moved the pass count 95->102 and added zero failures.
- [Phase 19]: [19-05 FINDING, will fire on every future run] the acceptance criterion `grep 'FAIL' <output> | grep -c 'pos_spec'` == 0 is a FALSE POSITIVE — it matches the `--dep pos_spec=src/types/pos_spec` flag echoed inside `[FAIL: vm.ffi: ffi command [...]]` lines from the EXPOSURE suites, not any failing test. It measured 28 while the real count of reds under test/pos_spec/ was ZERO. Scope such gates to `test/pos_spec/`, and note that test/types/pos_spec/ is the vol-type TYPE track — a different owner.
- [Phase 19]: [19-05 VERIFIED, the real MVER-04 gate] the BATCH dispatch is CALLED green through FFI-deployed bytecode, not inferred from compile-green: batchSelectorIsNowDispatched (selector 0x81357911 reaches a dispatch branch rather than revert_empty), mixedBatchFootprintAndContiguity (the branch does real work — state effects at raw vm.load addresses from a seeded counter), mixedBatchReturnIsByteExact (the return half). All reach the module via deployPlank -> plank build over FFI AT TEST TIME.
- [Phase 19]: [19-05 CORRECTED, fourth stale-criterion fix in this milestone] roadmap SC-4, the Phase 19 Goal line and the one-line entry all asserted a `PLANK_SKIP` exit that does not exist. PLANK_SKIP is the rescue queue for entrypoints that do NOT compile; a module dispatching a subset of its declared selectors compiles fine, so VolOrderManagerMod never met the entry condition. Queue verified byte-identically empty. Like the previous three, resolved by fixing the DOCUMENT, never the code.
- [Phase 20]: [20-01 MEASURED] Upstream gate OPEN — PR #15 (feat/plank->develop) MERGED; origin/develop pinned at 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d in offchain/rig/import-ref.txt. This SUPERSEDES research §1's CLOSED measurement (origin/develop = 1c41935, PR #15 OPEN at 14:20 UTC). The gate is a re-runnable command whose sharpest discriminator is a grep for the V2 selector 0x98d950ec, not path existence — a path check cannot tell a merged V2 interface from the stale v1 file.
- [Phase 20]: [20-01 MEASURED, binds 20-02's delta] Cold PRE-IMPORT baselines on feat/rpc-api: forge test --via-ir --fuzz-seed 4880 = 139 passed / 5 failed / 144 total (47 suites); make compile-plank = 14 ok / 0 failed / 0 skipped. 19-05's 102/18/120 + 11ok/2fail were NOT carried forward — the gap is the exposure draft: src/lib/exposure/VegaIssuanceLib.plk is now TRACKED and COMPILES here, so the 14 VegaAccount*/VegaIssuance* setUp() reverts and 2 compile failures are gone. 4 of the 5 reds are the known vol-type track failures; the 5th (VolOrderManagerFuzzTest test__fuzz__logCreateOrder) is NEW to this branch record and is pre-import, so 20-02 must not mistake it for import damage. 0 reds under test/pos_spec/.
- [Phase 20]: [20-01 VERIFIED] forge build exits 0 on the PRE-import tree after npm ci --ignore-scripts (172 pkgs) + the develop-gate.yml submodule sequence with the submodule.lib/panoptic-helper.update=none recursion guard (guard OBSERVED firing: 'Skipping submodule'). Any post-import build failure is therefore unambiguously attributable to the import. No tracked file moved: git status --porcelain on src/ test/ Makefile foundry.toml remappings.txt is EMPTY.
- [Phase Phase 20]: [20-02 VERIFIED] The import LANDED byte-identical: 36 paths checked out from origin/develop @ 9f5ccba, git diff against the ref EMPTY, none re-typed. src/lib/TickUtils.plk removed as superseded (R054 -> src/types/pricing/TickUtils.plk; its only 3 importers were all in the list and switch to types::pricing::TickUtils on the ref). The V2 discriminators are LIVE not merely present: SELECTOR_CREATE_ORDER = 0x98d950ec is the sole live const and 0x6501fe94 survives only as a RETIRED-NEVER-LIVE comment.
- [Phase Phase 20]: [20-02 PROVEN] The Plank closure is COMPLETE, established by compilation before anvil was ever started: all four deploy module roots build with the exact plankOpts() flag set (7 deps, verified against the IMPORTED PlankDeployBase.s.sol, not just research) and emit pure hex bytecode. VolOrderManagerMod's bytecode contains 6398d950ec -- the V2 selector is in the compiled DISPATCH TABLE, strictly stronger than a constant in a source file. ZERO closure gaps: no path was added, the 36-path list is unchanged from task 1. A 20-03 anvil failure therefore cannot be a closure gap.
- [Phase Phase 20]: [20-02 MEASURED, binds the Solidity-testing session] Post-import delta, ATTRIBUTED not repaired: forge test --via-ir --fuzz-seed 4880 = 139/5/144 -> 85 passed / 27 failed / 112 total; make compile-plank = 14ok/0 -> 13 ok / 3 failed / 16 entrypoints. forge build STILL exit 0, confirming solc never sees .plk, so all 27 reds are runtime/FFI and forge script (20-03) is unaffected. The total FELL 32 because six suites now fail in setUp(), which forge reports as ONE failure while the rest never run. Four named causes: C1 V2 arity create_order(uint88,uint24,uint16,uint96)/0x98d950ec with the v1 3-arg RETIRED (20 tests); C2 two harnesses importing the removed lib::TickUtils; C3 per-test --dep sets lacking types=src/types; C4 harness call sites at v1 arity. By transition: 1 carried pre-existing, 2 transformed, 24 genuinely new.
- [Phase Phase 20]: [20-02 FINDING] C3 is a DEPENDENCY-ROOT problem, not a content problem, and the proof is a divergence: VolRangeWidthHelper.plk compiles OK under make compile-plank (full dep set) while the SAME file fails under forge test's FFI (narrower per-test set). Re-running the failing command with --dep types=src/types added emits bytecode and exits 0 (MEASURED, no file edited). So C2/C3 are mechanical fixes for the Solidity-testing session, not a migration. Separately, test__unit__everyInterfaceSignatureStringIsPinned is a WORKING pin, not a bug -- it reddened because it DETECTED the source-of-truth change, exactly its job.
- [Phase Phase 20]: [20-02 PATTERN, falsify-before-trust] The SC-1 verifier was driven to FAIL on purpose before being reported green: a flipped pin digest and a deleted pin row each exit 1 with a named message, and both restorations were verified byte-identical. Faults were injected into IMPORT-PIN.md (this workstream's own file), never a plank-owned one. This answers the repo's four recorded instances of criteria that passed vacuously. Also carried forward for 20-04: IMarketStateSocket.plk was imported for set-completeness and IS the broken stub (seven const NAME = lines with no values, no terminators) -- the pin parser must skip valueless consts DELIBERATELY, with the skip asserted in a test.
- [Phase 20]: [20-03 RESOLVED, closes research §12.1 and REFUTES its prediction] Foundry records DeployDynamicFeeHook's raw .call to the CREATE2 proxy as a TOP-LEVEL transactionType CREATE2 attributed to the hook (contractAddress = the mined hook, contractName null), NOT as a CALL to 0x4e59b448 with the hook in additionalContracts[] -- additionalContracts is [] on all six transactions, in both runs. The plan's PRIMARY extractor branch never fires; the FALLBACK is the real path. contractName is null for the same reason it is null on plankDeployFFI modules (Plank initcode solc never saw), so the Plank hook is keyed on transactionType while PriceSetterHook (new X{salt:...}) carries a contractName and is keyed by name. The hook address also appears a second time as a CALL (initializeHook), so keying on CREATE2 is correct by construction, not by ordering luck.
- [Phase 20]: [20-03 MEASURED, SC-5] Two from-scratch deploy-rig.sh runs produce a byte-identical manifest: jq -S 'del(.generatedAt)' diff EMPTY, both normalised files sha256 197acd740685fb0860ec1f8227d95afc541985fe6d081b3fade6712f5888f354, with generatedAt DIFFERING (18:46:13Z vs 18:49:15Z) so run 2 provably regenerated the file. Two determinism results that were NOT guaranteed: (a) BOTH CREATE2-mined addresses reproduce, which for the Plank DynamicFeeHook means plank build emitted byte-identical initcode -- stronger than 20-02's 'compiles and emits hex'; (b) the seeded packed timepoint is identical across runs (1766847064...619776), confirming it derives from the fixed INIT_TS literal and not the wall clock. A date +%s INIT_TS would still have PASSED SC-5 (the seed is not a manifest field) while silently making the rig's STATE irreproducible.
- [Phase 20]: [20-03 VERIFIED, SC-2 falsified] verify-rig.sh exits 0 with '7 contracts live, RealizedVolatilityMod seeded' and contains ZERO address literals (every target read from the manifest via jq -r). All six injected faults exit 1 with named messages, run against COPIES via a RIG_MANIFEST override with the real manifest's sha256 confirmed unchanged after. TWO faults are load-bearing beyond box-ticking: pointing RealizedVolatilityMod at the LIVE 17151-byte PoolManager passes probe 1 and is caught ONLY by probe 3 (so probe 3 does not ride on the bytecode check), and swapping contracts.PoolManager for PriceSetterPoolManager proves probe 5 discriminates between two REAL contracts, not merely live-vs-empty. A live-vs-empty-only falsification would have left both unproven.
- [Phase 20]: [20-03 FINDING, one research-table label is stale] Research §3.2 lists DeployDynamicFeeMod printing 'owner (TOFU)  : <address>'. The IMPORTED file prints 'owner (TOFU)  : the deployer, captured in-broadcast' -- a sentence, not an address -- so there is no console address to cross-check and none is attempted. TOFU ownership is instead PROVEN on chain by verify-rig.sh probe 4 (owner() == manifest accounts.deployer), which is strictly stronger than matching a printed string. Every other console label matched the imported source exactly. Separately: poolId is the ONLY console-primary field with no independent source (it is not an address in the broadcast record); currency0/currency1 were upgraded to a SET cross-check against the two MinimalToken CREATEs.
- [Phase 20]: [20-04 MEASURED] Every pin is GENERATED, never typed: 30 selectors + 5 topic0s computed by cast sig/cast keccak from signature strings parsed out of the imported .plk files, each then ASSERTED equal to that file's own declared const. All 35 agreed -- zero disagreements, so no interface constant is wrong and the parser truncated nothing. generate-pins.sh contains ZERO hex literals; rig-pins.json names the signature and the source path for every pin. The truncation hazard was MEASURED not argued: a naive single-line parse of the wrapped TimepointWritten signature yields 0xc0055983... , a valid-looking WRONG 32-byte hash. Only the in-file cross-check separates it from the correct 0x44d3c76a... value.
- [Phase 20]: [20-04 FINDING, corrects research 5.3] The // signature:: convention is NOT used by all six interface files. DynamicFeeInterface.plk uses a THIRD shape -- bare // name(args) comments with no marker -- for all five of its selectors. A marker-only parser would have emitted 25 selectors instead of 30 and EXITED 0, silently hand-picking a subset. Fixed by anchoring the parser on the const DECLARATIONS and walking backward through the contiguous comment block (marker form takes precedence, bare form is the fallback); a const with a hex value and no derivable signature is a loud abort, so a fourth shape appearing later fails rather than shrinking the output.
- [Phase 20]: [20-04 PROVEN] Normaliser idempotency is established by CROSS-FILE AGREEMENT, not by assertion. TimepointWritten, WindowChanged, FeeConfigurationChanged and getAverageVolatility are each declared in two files in two DIFFERENT comment shapes -- decorated (indexed + parameter names, one of them wrapped across two lines) and already-canonical single-line. Both paths through the parser produced identical signature strings and identical computed values, and the generator ABORTS if any duplicate disagrees.
- [Phase 20]: [20-04 DECIDED, resolves a self-contradicting criterion -- the SIXTH in this repo] The plan required that deleting contracts.VolOrderManagerMod make the decode FAIL, while its own schema locks contracts as an OPEN map so a new deployment needs no Haskell change. A smaller map is still a valid map, so aeson structurally cannot fail. Resolved by KEEPING the map open (20-03's contract preserved, extra contracts accepted) and adding a required_contracts completeness check in load_rig_from that runs after decoding and names both the missing and the present contracts. The failure is raised by the completeness check, NOT by aeson -- do not blur this.
- [Phase 20]: [20-04 VERIFIED, closes a 20-05 question early] 20-03's rig-manifest.json already existed at 20-04 execution time and Rig.Manifest decoded the REAL file, not merely the fixture. It matches the wave-3 schema B contract with ZERO deviation -- every key, every nesting level, all hex lowercase, chainId/tickSpacing/initTs/initTick as JSON numbers. There is nothing for 20-05 task 1 to reconcile on the manifest shape. Also: the v1 E1 topic0 did NOT have to be omitted -- it is present VERBATIM and complete in the imported notes/DATA_CONTRACT.md:16, so it is parsed from there rather than expanded from memory, while the truncated .plk form is rejected by an explicit ellipsis guard.
- [Phase 20]: [20-05 MEASURED, the purge fixed a LIVE bug] Sample.hs's price_setter_hook literal 0x78f77B58... has ZERO bytecode on the deployed rig (cast code returns 0x) while the manifest's PriceSetterHook 0x683ee59f... has 2183 bytes. The driver's entire price-write path was aimed at an address with no contract at it. The other two literals were still correct by nonce accident (VolOrderManagerMod landed at the same address), which is the point: a literal is right only by accident and cannot announce when it stops being right. Six literals were purged, not the research inventory's four -- check-upstream.sh carried 0x98d950ec and 0x6501fe94 and is IN the decided *.hs/*.sh scope; both are now read from rig-pins.json with jq.
- [Phase 20]: [20-05 FINDING, the SEVENTH self-contradicting criterion] The plan's own prescribed Decode.hs comment ('The RETIRED v1 value 0xa8892769 lives in rig-pins.json') contains an 8-hex literal that its OWN purge criterion matches -- written verbatim, task 1 could never pass. Resolved by pointing the comment at the retired block without the hex. Separately, two acceptance criteria measure TEXT where they mean STRUCTURE (grep -c on 'account|order_manager|price_setter_hook' in Sample.hs and on 'Rig.Manifest' in the decode chain counted explanatory COMMENTS, not code); both were satisfied by rewording, at the cost of moving the removed-binding routing table into the summary.
- [Phase 20]: [20-05 DECIDED, a working tool would have broken silently] generate-pins.sh parsed retired.topic_order_created_stale out of offchain/lib/VolOrder/Decode.hs -- the very constant this plan deletes -- so the generator would have aborted with 'matched 0 values'. Re-pointed at src/modules/VolOrderManagerMod.plk, the superseded duplicate module carrying 'const TOPIC_ORDER_CREATED = 0xa8892769' verbatim: the file the Decode.hs constant was ORIGINALLY transcribed from and the origin of the rot (research 2.2). Better provenance, still never typed, another track's file READ only. Re-run produces rig-pins.json byte-identical. CAVEAT for Phase 21: the generator now depends on that superseded file existing; plank deleting it is a loud failure needing a new recorded home, not a silent drop.
- [Phase 20]: [20-05 VERIFIED, SC-4 is falsifiable and was OBSERVED red] cabal test = 44/44 (35 per-pin + 9 named). Every pin is recomputed from the signature PARSED OUT OF the .plk file its own source field names, by a SECOND independent parser anchored differently from generate-pins.sh's (comment-block forward scan vs const-declaration backward walk). A one-character pin corruption (0x98d950ec -> 0x98d950ed) reddens exactly sc4_pin_selector_create_order and sc4_cast_agreement at 42/44 exit 1, with the recomputed value CORRECT and the pin wrong, both Haskell keccak256 and cast saying so independently; git checkout restores 44/44. The suite also caught a defect in ITSELF first: cast's trailing newline made two identical-looking hex strings compare unequal.
- [Phase 20]: [20-05 FINDING, the clean-machine trap the plan's template would have shipped] The README's submodule step needs 'git -c submodule.lib/panoptic-helper.update=none'. The plain recursive command exits 0 in this checkout ONLY because the skip is recorded in lib/panoptic-v2-core/.git/config, a machine-local artifact; upstream's committed .gitmodules points lib/panoptic-helper at an unreachable repo and this repo has no overriding stanza. A clean machine following the plain form fails at step 2. Separately documented: cabal run completes and reports a receipt but the order REVERTS -- Encoding.hs still builds the retired 3-arg create_order against a V2 module dispatching 0x98d950ec (20-02's cause C1, pre-existing, Phase 21's re-pin), recorded in the README so a reader does not read it as a rig failure.
- [Phase 21]: [21-02 MEASURED, stronger than planned] All THREE golden-comparable cases match the v4.0 alloy fixture BYTE-FOR-BYTE, not just N0_empty. The plan expected N1_success/N2_success_then_fail to differ in the order-id words because the golden was taken against a fresh registry. They do not, and structurally cannot from this script: create_orders RETURNS its array, so the capture is four eth_calls, and an eth_call does not mutate state -- every case executes against orderCount = 0, exactly the golden's condition. The differs_only_in_order_ids comparator was built and ships (it becomes load-bearing against a rig that has taken real transactions) but is recorded false on all three. COROLLARY for 21-05: the captured order ids are HYPOTHETICAL, ids the calls WOULD have assigned; an assertion hardcoding id == 1 is really asserting the rig is fresh.
- [Phase 21]: [21-02 FINDING, binds 21-05] generatedAt is NOT a regeneration witness for capture-batch-return.sh. The Phase-20 idempotence recipe (two runs, generatedAt must DIFFER) was designed around deploy-rig.sh, which takes tens of seconds. The capture takes 294 ms against a 1-second timestamp resolution, so two back-to-back runs SHARE a generatedAt -- MEASURED, both 18:30:37Z -- and the check would have passed on a stale artifact. Regeneration was re-proven by deleting the artifact before each run and gating the second on the wall-clock second rolling over (bounded until-loop, no fixed sleep): runs A/B at 18:31:02Z and 18:31:03Z, normalised diff EMPTY, same sha256 786c9506...824c0cd7 as the first pair. Five runs, one normalised sha256. Use blockNumber/manager as the discriminating provenance fields; generatedAt is a label. Caveat written into offchain/rig/README.md.
- [Phase 21]: [21-02 CONFIRMED, hazard F1 -- REPORTED to the plank track, never edited] src/modules/pos_spec/VolOrderManagerMod.plk lines 177-188 carry a V1 comment block ('width@104..127 | bits >=128 MUST BE ZERO', 'width IS DELIBERATELY UNMASKED. It is the TOP field') that its OWN file contradicts at lines 221-235, where the executing V2 code masks width to 0xFFFFFF at 104 and reads targetVega UNMASKED from bit 128. The stale block is dangerous because it is plausible and co-located: a word built from it carries targetVega = 0, the tuple is rejected, and the batch SKIPS rather than reverting, so a capture would degenerate into a legitimate-looking all-(false,0) artifact proving nothing. The warning is recorded in offchain/rig/capture-batch-return.sh immediately above input_word(), naming the line range and the failure mode.
- [Phase 21]: [21-02 SCOPE, binds 21-03] The capture emitted NO E1 VolOrderCreated v2 log and could not: these are eth_calls, which produce no logs. The v2 E1 log remains UNOBSERVED and 21-03's decode shape is still derived from emitter source alone. Closing that gap needs a real eth_sendTransaction against create_orders -- cheap now that the rig is standing and the V2 input word (skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223) is proven live -- but it is 21-03's work.
- [Phase 21]: [21-02 DECIDED, RPIN-05 deliberately left PENDING] RPIN-05 is claimed by BOTH 21-02 and 21-05, and its text is 'decode_create_orders_result is verified byte-unchanged against the V2 module's (bool,uint256)[] return'. 21-02 delivered the LIVE half -- the observed bytes with provenance -- but produced no Haskell decoder verification at all, and was explicitly scoped OUT of adding assertions to offchain/test/Main.hs (21-05 owns the suite side). Checking the box now would record a decoder verification that does not exist. Left unchecked in REQUIREMENTS.md; 21-05 closes it once decode_create_orders_result is asserted against offchain/rig/batch-return-capture.json.
- [Phase 21]: [21-01 MEASURED, invalidates a gate used in three tasks] `cabal build -j all` does NOT build the test suite -- it exited 0 with 0 warnings against a test suite carrying `Not in scope: record field 'target_vega'`. cabal only builds test components when tests are enabled. Every build/warning gate in this workstream must be `cabal build --enable-tests -j all`; the plain form certifies lib+exe only and would report a non-compiling suite as green.
- [Phase 21]: [21-01 MEASURED, honest negative that limits what RPIN-03 may claim] Under the `shiftR 152`->`shiftR 144` storage mutant, `rpin03_input_word_is_not_storage_word` stayed GREEN. Its final assertion is an INEQUALITY (`unpack_vol_order_storage input /= base`), and a WRONG offset satisfies an inequality as well as the right one. That check discriminates CONFLATION of the two layouts, never CORRECTNESS of either -- only `rpin03_storage_round_trip` establishes the 152 offset. Do not cite the former as evidence for the latter.
- [Phase 21]: [21-01 MEASURED, discrimination is specific] Under the `shiftL 128`->`shiftL 120` input-word mutant, `rpin01_encoder_argument_order` and `rpin02_field_rejections` correctly stayed GREEN: the calldata path goes through `cast calldata` and never touches `pack_vol_order_input` (genuinely independent encoders), and rejection checks assert BOUNDS not POSITIONS -- a misplaced field is still in range. Neither family covers the other; both are load-bearing.
- [Phase 21]: [21-01 FINDING, the EIGHTH self-contradicting criterion in this repo] The plan prescribed a comment stating the V1 3-arg path is deleted, while its own verification step 6 requires `grep -rn 'uint88,uint24,uint16)' offchain/` to produce NO output -- the natural comment matches that grep. Resolved by rewording the comment to omit the signature string (and to say why), never by relaxing the criterion. Same class as 20-05's prescribed Decode.hs comment.
- [Phase 21]: [21-01 FINDING, F1 CONFIRMED against the source] `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` still reads 'bits >=128 MUST BE ZERO' and 'width IS DELIBERATELY UNMASKED. It is the TOP field', both FALSE of that same file's V2 code at 229-235 (width is masked and interior; targetVega is the unmasked top field at 128). Plank track's file -- REPORTED, never edited. An implementer trusting it ships a V1 packer that passes every offchain test and is SILENTLY SKIPPED on the batch path as an ordinary `(false,0)`. The Haskell-side comment in Encoding.hs now names the block as untrustworthy.
- [Phase 21]: [21-01 FINDING, F2] The module pins TICK_SPACING = 20 into storage bits 104..127 while the rig's own deployed pool has tickSpacing = 10 (rig-manifest.json .pool.tickSpacing). REPORTED in Decode.hs and offchain/test/Main.hs; the test expectation is written against the MODULE CONSTANT so a change to it reddens rather than passing silently. Not resolved -- resolving it means editing another track's module.
- [Phase 21]: [21-01 DECIDED] `cabal run` was deliberately NOT executed: it writes live orders to the shared anvil rig that 21-02 was capturing batch-return data from in the same wave. The V2 fix is proven statically (encoder selector == module's dispatched selector, three ways); live confirmation belongs to a plan that owns the rig state.
- [Phase 21]: [21-03 MEASURED] rpin06's inequality assertions do NOT catch a decoder that destroys targetVega -- with the baseline round-trip assertion neutralised the check PASSES under the target_vega=0 mutant. The baseline is the sole discriminator; an inequality never establishes correctness of the thing it is unequal about.
- [Phase 21]: [21-03 FINDING] sc4_no_retired_value_is_live is defeated by ZERO-PADDING: it compares pin values as strings, so the left-padded 32-byte form of a retired 8-hex value stays GREEN while that value is live. Pre-existing (Phase 20's check); logged to deferred-items.md, fix = compare numerically.
- [Phase 21]: [21-03 OBSERVED] FIRST E1 VolOrderCreated v2 log ever seen on chain: 2 topics, 128 bytes/4 data words, topic0 == pin, orderId in topic 1 only, data = (12345,600,77,1e18). Captured non-destructively via evm_snapshot/evm_revert; rig restored to block 9, orderCount 0, SC-2 green.
- [Phase 21]: 21-04: the plan's predicted mutant discriminator was REFUTED by measurement -- a linear-uniform draw spans 9 distinct bit-lengths (62..70) over 256 fixed-seed draws and clears the >= 8 spread assertion; bottom-decade mass (77 vs 4 of 256) is the real shape discriminator and was added
- [Phase 21]: 21-04: draw_target_vega's zero-lower-bound rejection is INCIDENTAL (0 * Infinity = NaN in the log transform), not an explicit parameter guard -- a second VegaDraw constructor must supply its own validation
- [Phase 21]: [21-05] RPIN-05 closed: live captured bytes asserted byte-for-byte against the alloy golden inside a suite PROVEN chain-independent with anvil stopped (65/65, pgrep anvil empty)
- [Phase 21]: [21-05 REFUTED] The plan's instruction to record follow-up #5 as ADDRESSED is FALSE — verify_mined_order is unchanged and still discards tickSpacing and bits >= 248 before comparing. Recorded PARTIALLY ADDRESSED.
- [Phase 21]: [21-05 REFUTED] blockNumber is NOT a provenance discriminator — three from-scratch deploys of the same rig gave heights 9, 11, 10. Freshness asserts chainId + manager only.
- [Phase 21]: [21-05 MEASURED] decode_create_orders_result never reads the outer offset word (follow-up #2 demonstrated); and the freshness check cannot see a module change behind an unchanged CREATE address (F4).
- [Phase 21]: [21-05 CLOSED] sc4_no_retired_value_is_live now compares NUMERICALLY — under 21-03's identical injection the suite reports 4 failures where 21-03 recorded 3.
- [Phase 22]: 22-01: IMPORT-PIN.md stays THE pin file (verify-import.sh's PIN= constant unchanged) — a Phase-22 pin file would create two sources of truth for one fact
- [Phase 22]: 22-01: .planning/issue-17-swappable-rig-SPEC.md (+134 on develop) deliberately NOT imported — the 37-path set is authoritative and every acceptance criterion is stated against the literal 37 (finding F22-3)
- [Phase 22]: 22-01: forge/plank delta measured with Phase 20's exact command AND seed (forge test --via-ir --fuzz-seed 4880), not the plan's bare 'forge test', so 85/27/112 is a real comparison
- [Phase 22]: 22-01: DRIV-01/DRIV-02 NOT marked complete despite being in the plan's requirements frontmatter — this is the import/unblock plan (1 of 6) and neither driver has run against a live rig; REQUIREMENTS.md stays Pending, matching Phase 20's RIG-01-at-20-05 precedent
- [Phase 22]: 22-02: EVERY signed field needs at least one NEGATIVE pin of its own — MEASURED, the third refuted discriminator in this workstream
- [Phase 22]: 22-02: compose_slot0 masks at bit 184 so protocolFee/lpFee survive BY CONSTRUCTION (G5b); masking at 160 breaks tick/sqrtPrice coherence (G5a)
- [Phase 22]: 22-02: PoolSwapTest.swap calldata is 388 bytes (4+32*12), not the planned 324 — the empty bytes member still costs an offset AND a length word
- [Phase 22]: 22-02: POOLS_SLOT = 6 is CONSUMED from the pinned DynamicFeeHook.plk constant, never re-derived from v4-core, so the hook and the client cannot disagree
- [Phase 22]: 22-02: RealizedVol.Decode is a DECODER only — the module name is not evidence the no-writeTimepoint-client decision was violated
- [Phase 22]: 22-04: the cheat-swap composition is DISCHARGED BY MEASUREMENT — an E3 carrying the cheated tick 5000 was observed on chain; the identical sequence aimed at PriceSetterPoolManager returns status 1, one E3, one E5 and tick 4999
- [Phase 22]: 22-04: G1 cannot be reached by OMITTING the clock advance — that races wall time (observed both ways); CheatSwap.Rpc gained ForceTimestamp to construct the collision, and anvil was measured accepting an EQUAL next-block timestamp while rejecting only strictly-lower
- [Phase 22]: 22-04: the near-floor tick -887259 does NOT revert and E3 carries it, so 22-05 needs no per-step direction/limit selection
- [Phase 22]: 22-05: DRIV-01 CLOSED by a PATH — five consecutive cheat->clock->swap steps, each producing exactly one E3 carrying the tick AND the timestamp submitted (t0=1700001670, stride=12, seed 123456789)
- [Phase 22]: 22-05: the plan's own G1 detector was MEASURED GREEN under its mutant and FIXED — a count equality over recorded steps is blind to the run being truncated; compare against configuredSize
- [Phase 22]: 22-05: DRIVER_CAPTURE redirects the WRITER as well as the checks, deliberately unlike 22-04's RIG_CHEAT_SWAP_PROOF — here the driver IS the capture tool
- [Phase 22]: or_complete is DRIV-02's OWN completion flag: dr_complete means the DRIV-01 path finished and is set before the order side runs, so borrowing it would report a price-path success as an order-side success
- [Phase 22]: The three submitted mixed-batch tuples are pinned BY VALUE, never by relations: a batch cut 3->2 is self-consistent in every relation a check could form (M4, measured)
- [Phase 22]: preview_create_orders exposed rather than widening create_orders' return type: a mined transaction carries NO returndata, so the 64-byte empty return is observable only through the preview eth_call
- [Phase 24]: 24-03: Produced carries CapturedStreams too -- the plan's two tasks contradicted each other on cs_run_dir observability, and the addition strengthens rather than weakens (Aborted still has no artifact)
- [Phase 24]: 24-03: backstop_no_exit_code = -1 -- when the in-process backstop fires there IS no exit status, and -1 is not a byte any process can return, so it cannot be mistaken for an observed code
- [Phase 24]: 24-03: GAMS-01 and GAMS-02 held at PARTIAL -- every Tier-A and Tier-B row shipped and is OBSERVED, but each has one Tier-C row that reads a capture artifact not existing until 24-06

### Pending Todos

None yet.

### Blockers/Concerns

**[Phase 10 — THE DURABLE RECORD THAT THE PRE-COMMITMENT WAS HONOURED]**

- **This market cannot identify υ.** The pre-committed, result-blind stopping rule (half-width <= 6.2e-5) was applied and FAILED, then failed AGAIN after the one construction defect with an unambiguously signed effect on it was found, escalated to the user, locked, and fixed. Realised half-widths 1.479533e-1 (run 1) and 1.979569e-1 (run 2). **NO respecification was attempted** — no filters, trims, outlier drops, re-fetches, SE-method swaps, test-geometry changes, transforms, control additions or subsample hunting — and is scheduled. The bar was never moved, not even after its unit incoherence (Phase 9 USD/day vs this panel's ETH/hour) surfaced mid-run; that incoherence is recorded in both analysis outputs and repaired in neither.
- **The binding constraint is the 55-cluster ceiling**, with 84.1% of the 6,760 rows sitting in ten positions. No LHS transformation and no additional hours on existing positions can touch it; only more INDEPENDENT positions would. Any future work on this question that does not add clusters is not addressing the constraint.
- **Open, and flagged rather than resolved:** the Panoptic multiplier wedge co-varies weakly with moneyness (Pearson 0.143545 on a chunk-level proxy), so `κ̂` carries a contamination that was measured and directionally signed but NOT corrected. `Upsilon.ATMOTMNullHypothesis` remains an OPEN conjecture; the formal witness does not obtain.
- **CTX-REPLAY-OPT is unsatisfied by choice** (10-12 skipped as optional and non-blocking; rationale in Decisions and in ROADMAP). It is not a blocker for anything downstream, and it is not claimed as done.

[From codebase concerns audit — affect future phases]

- **Repo ownership inverted + destructive migration** (Phase 1): `JMSBPP` is standalone origin; `wvs-finance` repo does not yet exist. The public flip and the destructive fork-migration step (REPO-02) are outward-facing and MUST be confirmed with the user at execution (Concern 11, PROJECT constraints).
- **Publish-readiness leaks** (Phase 1): tracked `refs/` Next.js app + `node_modules`, `Counter` scaffold, broken CI, and absolute `$HOME/...` (local home-absolute) paths must be scrubbed before the public flip (REPO-05; Concerns 7, 9, 10).
- **Plank toolchain unpinned + silent-zero FFI** (Phase 2): `plank v0.1.1` via curl-bash with no lockfile; deployer/`plankified-univ3` on floating HEAD. Pin and add loud FFI guards before relying on builds (TOOL-01/02; Concern 3).
- **Plank sources are stubs/parse-errors** (Phase 4): `VolatilityTermStructure.plk`, `IMarketDynamicsLens.plk`, `Numerics.plk` have empty selectors/untyped fields/`u265` typo. Phase 4 must implement AND compile the bridge surface (PLNK-04; Concern 2).
- **Bridge is a zero-line gap** (Phase 6): GAMS↔Plank integration does not exist; the exchange format + per-hop encoding (Phase 3) gate the wiring (Concern 4).
- **GAMS solver is a deliberate stub** (Phase 5): GAMS-02 emits the artifact with a stub objective only; the real model is v2 (`PAY-01`).
- 12-04 INHERITS: amend the approved ## ETA section for ESC-1 (E7's scalarization-impossibility sentence is FALSE on [kappa_S, kappa_I]), ESC-2 (E0's probInv justification is misattributed) and ESC-3 (E0 omits theta<1). DEFERRED by user ruling until the 12-02 bundle lands.

## Session Continuity

Last session: 2026-08-17T05:13:03.000Z
Stopped at: PHASE 24 COMPLETE (6/6 plans, 7/7 requirements) -- next /gsd:plan-phase 25
Resume file: None

---

## Merged from origin/develop on 2026-08-23 (other tracks' conflicting segments, kept verbatim)

Resolution rule: `.planning/` is shared by several tracks with disjoint phase ranges. The rpc_api v6.0 state is kept as the live frontmatter/position; every develop-side segment that conflicted is preserved below unedited so no other track's record is lost.

### develop segment 1 of 5

milestone: v1.0
milestone_name: milestone
status: "**PHASE 11 WAVE 2 IS IN FLIGHT — THE QUEUE IS BUSY.** Bundle B was submitted as the single Aristotle task (project `19f777ab`, task `f8840dab`) carrying T20–T30: the degeneracy, the constrained/Jensen program, and the Angstrom bridge. Nothing is proven yet; integration is 11-05's job and is BLOCKED until the task is terminal. **The two-reviewer gate paid for itself twice this plan.** It caught a BLOCKER that the PLAN ITSELF had introduced — `mevTotal` defined as `probOr` of two unbounded hazards, which approved block M7 explicitly forbids and which would have compiled green, passed the axiom sweep and passed 11-05's fidelity diff while being wrong for every nonzero sandwich. Both reviewers, running blind to each other, found it independently; the already-proven `probOr_hazard` was the decisive evidence. Separately, and before either reviewer ran, the plan's T25 was found to be a vacuous triviality at the schedule level — the document's own OPEN note — and was restated at the path level. **Watch T24 on return: an OPEN T24 alongside a delivered T25 is an acceptable, recordable outcome and must not be written up as success.** What follows is the prior wave's status, retained verbatim."
stopped_at: Completed 12-04-PLAN.md — PHASE 12 CLOSED, queue FREE
last_updated: "2026-08-02T13:54:23.811Z"
last_activity: "2026-08-02 — PHASE 12 COMPLETE (4/4 plans). `lean/vol_markets/EtaCurvature.lean` landed in TWO Aristotle runs (`4878ca32` OUT_OF_BUDGET at 36/51 with 15 sorries, NOT integrated; repair `c3a617f3` closed them): 1269 lines, 51 declarations, 0 sorries, 51/51 axiom-clean, `lake build` green (8067 jobs), origin `b02caf7` + mirror `lean4-spec main d25fd75`. THE HEADLINE: `etaStar = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)`, the first CONSTRUCTED interior optimum in this program, obtained by INVERTING a bijection at a KINK — no first-order condition anywhere — with the coupling `∂η⋆/∂φ < 0`. 12-04 closed the record: LEAN_TRACEABILITY §0 notation rows + binding remap paragraph, §7.2's nine-item OPEN ledger, §6(b) amended, the addendum's missing `> LEAN` annotation mirrored, the sha-pin invalidation DISCLOSED (`4f5362c1…` → live `54d10b59…`), and plank's line-227 η question answered with the controller law and NO invented proxy. Six CTX-* SATISFIED, CTX-DEGEN SATISFIED AS NARROWED. NOT ESTABLISHED: the equilibrium transfer (the largest OPEN item — every theorem is about `lpExcess ∘ curvIndex`, none about our AMM), the factor-share half of the η-identity (PARTIALLY discharged), and Phase 11's Θ_φ-restricted σ-varying case. Commits e4447ff, f623bd3, dedc66f. Queue FREE."
progress:
  total_phases: 12
  completed_phases: 4
  total_plans: 40
  completed_plans: 37
  percent: 93

### develop segment 2 of 5

**Core value:** A parameter set flows end-to-end — (stub) GAMS output → encoded to Plank fixed-point → written via `initVolTermStructure` → read back and round-trip-verified — with both tracks bound to one authoritative kernel.
**Current focus:** Phase 1 — Repository Restructure & Sanitize

## Current Position

Phase: 12 of 12 (Optimal η for the FLAIR/MEV trade-off — the interior curvature controller) — Lean4 + Math track — **COMPLETE 2026-08-02**
Plan: **12-04 COMPLETE — 4 of 4 plans. PHASE 12 IS CLOSED. THE ARISTOTLE QUEUE IS FREE.** Six of the seven CTX-* requirements SATISFIED and **CTX-DEGEN SATISFIED AS NARROWED** (user ruling 2026-07-31 — no literal de-degeneration of the `Θ_φ` program). Nothing further is scheduled in Phase 12.
Plan (12-04): **PHASE 12 CLOSE-OUT (CTX-TRACE).** **THE HEADLINE: `EtaCurvature.etaStar` = `ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)` — the FIRST INTERIOR OPTIMUM this program has constructed, where everything in `Θ_φ` was a corner (`joint_corner_degeneracy`) or a saturation limit (`β_j → −∞`, never attained).** It is obtained by **INVERTING the bijection** `curvIndex η Δi = 1 − λ^(−Δi²η/2)` at the kink `κ_φ⋆ = κ_φ,I = 1 − √((1+φ)/(1+ϱ_I))` — existence AND location in one step — and `curvIndex_etaStar` is a machine-checked EQUALITY carrying the closed form in its own statement. **THERE IS NO FIRST-ORDER CONDITION ANYWHERE**: `lpExcess_isMaxOn` is built from the two one-sided strict monotonicities `lpExcess_strictMonoOn` / `_strictAntiOn`, and `κ_φ⋆` is a KINK where the derivative jumps. **THE HEADLINE IS QUALIFIED, DELIBERATELY, AND THE QUALIFICATION IS NOT COSMETIC: `lean/exp/DynamicsOptimization.lean` ALREADY CARRIES AN INTERIOR-η CLAIM** (`foc_eta`, `optimal_controls`) — in a DIFFERENT model, on a different objective (`π⁺ = Δi²S(η)`, where η enters only through the inventory-weight curve), and it **HYPOTHESIZES** the maximizer and characterizes it by an FOC. What is new here is **CONSTRUCTION — existence and closed form — versus that module's hypothesized maximizer and first-order characterization**, and `LEAN_TRACEABILITY` §7.2 says exactly that so nobody downstream reads the two as duplicates or as one superseding the other. **THE DE-DEGENERATION AND THE COUPLING.** `eta_no_common_argmax` keeps its CONJUNCTION — both `arbLossRatio` and `surplusRatio` strictly fall in η, so no common argmax exists in the curvature model — and `etaStar_coupled_to_fee_corner` carries `∂η⋆/∂φ = −1/((1+φ)Δi²ln λ) < 0`: **RAISING THE FEE LOWERS THE OPTIMAL CURVATURE**, so the Phase-11 fee corner and the curvature choice are COUPLED, not separable. Fee and curvature are SUBSTITUTE FRICTIONS on the investor's marginal cost; following the coupling to its limit switches the controller OFF (`φ → ϱ_I⁻` ⟹ `η⋆ → 0⁺`, the zero-curvature constant-price grid). **THE η-IDENTITY IS PARTIALLY DISCHARGED, NOT CLOSED.** The user's 2026-07-31 decision that `priceEta`'s η and `eta.md`'s η are the same parameter has two halves: the EXPONENT identity `priceEta η Δi i = p_eta(lam,Δi,η/2,i) = P_half(lam,Δi·η/2,i)` is **PROVEN** (`priceEta_eq_p_eta_half`, `priceEta_eq_P_half`; the factor 2 is the sqrt-price normalization), while the FACTOR-SHARE identification with `CFMM.Eta.L_eta` is **OPEN** — optional T28'b came back absent, as pre-authorized, and was NOT satisfied by restating T28'a. The reason the second half is a modelling claim rather than a rewriting is `exp/eta.lean`'s own `P_half` docstring: **η does not enter the tick→price map**. It is worse than merely open: a factor share must lie in `(0,1)`, and `η⋆ ∈ (0,1)` needs `Δi ≳ 21` at `λ=1.0001, ϱ_I=0.05, φ=0.003`, while `Δi = 1` and `Δi = 10` are both in standard use (`η⋆ ≈ 458` and `≈ 4.6`) — so on much of the tick-spacing range the factor-share reading is not open but **UNAVAILABLE**. **NOT ESTABLISHED — nine standing OPEN items, the equilibrium transfer first, now carried as a ledger in `LEAN_TRACEABILITY` §7.2:** (1) **THE EQUILIBRIUM TRANSFER** — every theorem is about `lpExcess ∘ curvIndex`, and that `lpExcess` describes THIS project's tick-grid AMM is an ASSUMPTION, not a derivation; deriving it means re-solving the anchor's (A.31)/(A.39) on a discrete grid with per-tick liquidity, and **nothing in the module is a theorem about our AMM**; (2) welfare — Proposition 6's welfare half is not transcribed and does not follow from E3+E4, and the anchor's ranking assumes arbitrage rent is deadweight, which `### MEV` contradicts under rent recycling; (3) `arbLossRatio` and `mevMulti` are **NOT IDENTIFIED** — different models, different units — by construction, not by omission; (4) gas (Assumption 3 absorbed); (5) the `Θ_φ`-restricted σ-varying MEV comparison, INHERITED from Phase 11 and untouched here; (6) the factor-share identification; (7) the Phase-11 degeneracy is NOT resolved — `ϱ_I` is a CANDIDATE for §6(b)'s demand layer, not a closure of it; (8) `η⋆` is σ-INDEXED once the fee is `multiFee(σ)` while the grid η is a design constant chosen once, and **a beforeSwap/afterSwap hook cannot vary η**; (9) the `c₁ ≤ 0` freeze boundary, where the LP payoff is flat and `η⋆` is not an argmax at all. **ADDED HYPOTHESES (2, both with conclusions intact, zero narrowed statements):** `lpExcess_strictAntiOn` gained `φ < ϱ_S ≤ ϱ_I` — E0's own standing ordering made explicit, needed so the shock branch point does not sit above the investor switch; and `etaStar_pos_iff` gained `−1 < ϱ_I` because **Mathlib's `Real.log` is `log|x|`**, so the unguarded criterion is FALSE (witness `ϱ_I = −3, φ = 0`) — precisely the log-sign trap the 12-02 Model QA review predicted, and the second time a Mathlib total-function convention has falsified a statement as drafted in this project (after `ptrade`'s negative-fee pole). **WHAT THIS PLAN ACTUALLY WROTE, and what it deliberately did NOT rewrite.** `LEAN_TRACEABILITY` §0 gained rows for `premInv`/`premShock` — **declared PREMIA, NOT PROBABILITIES** in the row text, because under the probability misreading (which `12-CONTEXT.md` contains) `κ_φ⋆ = 1 − √((1+φ)/(1+ϱ_I))` is uninterpretable and the demand-side link to §6(b) is lost — plus the four absorbed `ϖ_*` constants (with `ϖ_H` honestly recorded as having **no Lean binder of its own**), `kphiS`/`kphiI`/`kphiStar`, `cOne…cThree` and `etaStar`; a binding paragraph recording the Capponi remaps, the absorptions and their reasons (`θ` collides with option theta, `κ` with the Phase-11 scalarization weight), the `f ≡ φ` identification, **the η protection and the gate INVERSION of Phase-11's Rule 1**, the ν avoidance, the deliberate `λ` overload (tick base `PosSpec.lam` vs subscripted hazards), and the `arbLossRatio`/`mevMulti` NON-IDENTIFICATION. **§6(b) was AMENDED, not deleted** — `ϱ_I` is a PARTIAL carrier for the demand-elasticity gap, with the equilibrium transfer and MMR §7.3 eq. (27) named as what remains OPEN. **DEVIATION: the plan's `§7.2` was NOT written as a second claim table.** `§13` had already landed with the module at `b02caf7`, following the convention §8 onward established, so §7.2 is instead the §7-level entry point plus the nine-item E8 OPEN ledger, with bidirectional cross-references — duplicating §13's statuses would have created two sources of truth for the same verdicts, which is the failure mode the traceability file exists to prevent. Every backticked identifier in §7.2 was grep-verified to be a real declaration by a check **scoped to that section** (11-06's defect fixed, not repeated), and four prose tokens were un-backticked when the check caught them. **A REAL DRIFT WAS FOUND AND CLOSED:** the plank copy carried the `> LEAN` back-annotation (plank `08039da`) while this tree's addendum carried **none** — mirrored byte-identical. **THE SHA-PIN INVALIDATION IS NOW DISCLOSED RATHER THAN LEFT TO BE DISCOVERED:** `APPROVED-ETA-SHA256 4f5362c1…` (and the identical `BUNDLED-ETA-SHA256`) no longer match the live section, which hashes `54d10b59…`; two intentional edits moved the bytes (the ESC-1/2/3 corrections, which **landed EARLY at `62220db` at the user's direct instruction rather than being deferred to this plan as 12-02 had ruled**, and the back-annotation), and it is safe only because both gates were already consumed and both passed and `PROMPT-SHA256` is untouched by document edits. `../plank/todo.md` **line 227** (a LINE number, not an item number) now carries the closing controller-law answer: the law, its four strict comparative statics with the fee coupling called out, the carriers, and the three caveats — `ϱ_I` **UNOBSERVABLE with NO on-chain proxy invented, deliberately**, because that is the υ econometric null-result failure mode that cost this project two phases; the "substitution elasticity" phrasing **tightened rather than propagated** (for a weighted-geometric CFMM the elasticity of substitution is 1 and η is the FACTOR SHARE); and the equilibrium transfer labelled an ASSUMPTION. **`12-RESEARCH.md` was left UNEDITED** — a dated research artifact; its three carried-forward defects are corrected in the ROADMAP correction block, in E7's own ESC-1 line and in §13, which is where a later plan would actually read them. **PLANK INTEGRITY:** `../plank/` written but **NOT committed** (HEAD `08039da` before and after); the M0→end-of-M8 bytes hashed `5fb90745…` before AND after, unchanged — and that value is **not** the Phase-11 pin `9fcf01d3…`, because plank's own prose-compression pass moved those bytes independently, before this phase. **NO `.lean` FILE TOUCHED** (`git status --porcelain lean/` empty throughout) and `lake build` green (8067 jobs). The `claude-peers` MCP is **not exposed to executor sub-agents**, exactly as at 12-01, so the owner handoff again went through `todo.md` — **the coordinator should re-send the live notification to `ul2inqpl`.** Commits e4447ff, f623bd3, dedc66f.
Plan (12-03): **THE LANDING — AND IT TOOK TWO ARISTOTLE RUNS, WHICH THE PLAN DID NOT ANTICIPATE** (CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN). Project `4878ca32` / task `e1c846ae` returned **`OUT_OF_BUDGET`**, not `COMPLETE`: 51 declarations at 723 lines with **15 carrying `sorry`**. **It was NOT integrated** — `lean/vol_markets/` requires sorry-free axiom-clean modules and the standing rule bars hand-proving the gap locally — and the refusal is the correct outcome, not a failure. All 18 bundled inputs came back byte-identical, so it was resource exhaustion, not a payload or logic failure. `12-CONTINGENCY.md` **WAS INVOKED**, option 1 (second bundle) over option 2 (close with 15 honest OPEN rows), at the user's `submit eta -b`: project `c3a617f3`, task `4ec89173`, the original 18 inputs plus the partial as working base, prompt scoped to the 15 gaps with a transport hint (prove `curvIndex_etaStar` first, then the η-transport by composition rather than re-deriving) and a **budget PRIORITY ORDER** so a second truncation would degrade gracefully instead of losing the headline. **No second two-reviewer gate was run on the repair prompt, and that is a recorded decision rather than a default:** the 15 statements were Aristotle's OWN, already type-correct, in a file that already built, so the transcription-defect class the gate exists to catch cannot recur when no statement is being authored. **RESULT: `COMPLETE` — `lean/vol_markets/EtaCurvature.lean`, 1269 lines, 51 declarations, 0 sorries, 51/51 axiom-clean** (`propext`, `Classical.choice`, `Quot.sound`), root APPENDED to the lakefile, `lake build` green (8067 jobs), origin `b02caf7` + mirror `lean4-spec main d25fd75`. **Declaration list identical to the submitted partial — no renames, no drops, no additions**, which is the check a count would have missed. Integrated via the NON-UNIFORM map-driven import rewrite (`RequestProject.EtaReplication` → `exp.EtaReplication`, the rest → `vol_markets.*`); a blanket sed would have produced the non-existent `vol_markets.eta`. **Fidelity: 13/15 verbatim, 2 AMENDED, ZERO NARROWED.** Optional **T28'b ABSENT** as pre-authorized ⟹ E8(6) OPEN. **This plan was executed manually by the orchestrator rather than by a plan executor, so `12-03-SUMMARY.md` was written RETROACTIVELY at 12-04** from git and on-disk ground truth, and it says so; three fidelity claims (18-module byte-identity, declaration-list identity, the 51/51 axiom sweep) are inherited from the execution-time record rather than re-run, and the summary marks them as such rather than asserting them. Commits 2f5310c, 93a7122, 4ee4234, b02caf7; retroactive summary e4447ff.
Plan (12-02): THE ARISTOTLE BUNDLE (CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN, CTX-REVIEW). An **EIGHTEEN**-module bundle — 15 `vol_markets` (the plan said seventeen; `JitLiquidity` landed mid-plan and the binding rule is doc + ALL proved modules) plus the three `CFMM.Eta` modules the η-bridge consumes — carrying the user-approved `## ETA` section and a **1232-line, 35-item T1'–T31' specification**: Capponi's Lemma 3, Propositions 5 and 6, the closed form **`η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)`** obtained by INVERTING the bijection `κ_φ(η,Δi) = 1 − λ^(−Δi²η/2)` at the KINK `κ_φ* = κ_φ,I`, the normalization bridge split into its provable and modelling halves, and the Phase-11 contrast. **The import closure was PROVEN, not assumed** (14 distinct imports, all resolving — the check that catches the `CESLongVolPayoff` class 12-RESEARCH F7.3 missed), and all 18 copies are byte-identical to the landed modules. `12-02-MODULE-MAP.txt` exists because **12-03's return rewrite is NOT a single sed**: `RequestProject.eta` → `exp.eta` but `RequestProject.VolInstrument` → `vol_markets.VolInstrument`, and a blanket substitution yields the non-existent `vol_markets.eta`. **THE TWO-REVIEWER GATE PAID FOR ITSELF TWICE, AND ONE OF THE TWO DEFECTS WAS IN THE APPROVED DOCUMENT.** Reality Checker + Model QA Specialist, independent OS processes, parallel and blind, both NEEDS WORK: **2 BLOCKER, 1 MAJOR, 11 MINOR, 0 unresolved.** (i) `lpExcessEta` applied EIGHT arguments to the SEVEN-parameter `lpExcess` and reintroduced `cOne` as a free parameter — the headline chain T27'→T28'→T30', where the wrong unsupervised fix **silently falsifies the T10' branch agreement the entire peak rests on**. (ii) **Block E7's scalarization-impossibility sentence is FALSE** and had been mandated verbatim into a permanent Lean docstring: it holds on the two OUTER branches but fails on `[κ_φ,S, κ_φ,I]`, because the two ratios switch branches at DIFFERENT points, so the weighted derivative is a difference of a decreasing `1/κ_φ²` and an increasing `1/(1−κ_φ)²` term. **RECOMPUTED INDEPENDENTLY rather than taken on trust** — at `φ=0, ϖ_A=1, ϱ_S=0.5, ϱ_I=3, w₁=2, w₂=1` the derivative runs `+0.637` at `0.19` to `−1.403` at `0.45`, crossing at **`κ_φ ≈ 0.2412`, a stationary interior maximum strictly inside the middle region and at NO branch point** (the reviewer's own `≈0.29` was slightly off; the finding was not). (iii) MAJOR: **T8' was FALSE as displayed**, guarding `premShock` against `Real.sqrt`'s junk value but missing the symmetric `premInv` guard — at `fee=0, premShock=0, premInv=-2` the reverse direction fails — and it was not on the anti-narrowing list, so a quiet weakening of the iff would have been undetectable. All fixed pre-submission. The reviewers CLEARED: no FOC anywhere, the T24' inversion algebra re-derived against `VolInstrument.lean:30`, the closure re-derived independently, **all thirty Mathlib citations real and line-exact with zero phantom hints**, every quoted signature byte-exact, `cOne` verified term-by-term to BE the anchor's `τ₁`, and no doc-vs-PDF disagreement. **USER RULING, BINDING ON 12-04: submit now, amend the document LATER.** ESC-1 (E7's false sentence), ESC-2 (E0's misattributed `ϖ_I > 0` justification — the strict increase survives at `ϖ_I = 0`; the PEAK fails, via `c₁ < 0`) and ESC-3 (E0 omits `θ < 1`) are recorded-and-neutralized in the prompt and the **amendment is DEFERRED to a 12-04-style pass**, deliberately not now, because amending `## ETA` mid-flight breaks `APPROVED-ETA-SHA256` and leaves 12-03 diffing the return against bytes that no longer exist. Neither defect falsifies a requested theorem — on the middle branch `lpExcess`'s two terms both push UP, so the peak is untouched. Doc fidelity held at assembly AND at submit: `APPROVED == BUNDLED == LIVE` ETA section `4f5362c1…`, E-block diff empty, **while the live whole-file hash moved TWICE** (`64bdbead…` after a notation update, `1df289c5…` as the GREEKS blocks landed) — which is exactly why the gate is the END-marker-delimited section. The bundled copy was deliberately NOT re-copied at submit time: it is the gated frozen artifact and the live file was under concurrent edit. Pins: `PROMPT-SHA256 6f28c64f…` (post-fix, the exact bytes sent), `BUNDLED-ETA-SHA256 4f5362c1…`, `BUNDLED-DOC-SHA256 64bdbead…`. Queue proven clear first — 20/20 projects IDLE, zero `eta-curvature` projects, so unambiguously a NEW project. Deviations: 18-not-17 modules; **T17'b ADDED as a new REQUIRED item** (E5's zero-sum identity — approved, provable, and the clean content T18' can safely omit); `cOne` resolved as a DEFINITION against the plan's own "free parameter" wording, since the `κ_φ,I` branch agreement holds only for E4's closed form. Four mechanical-criterion defects recorded, the sharpest being that **the plan's own Mathlib verification grep anchors `^(theorem|lemma)` against a file where every gluing lemma is `protected theorem`** — run as written it returns NOTHING and reproduces the 11-02 phantom-hint signature exactly, which would have dropped the central gluing route. NOT ESTABLISHED: **nothing is proven** — the task is IN_PROGRESS, no `.lean` file was created or modified, and every T-item is a REQUEST; the three OPTIONAL items (T18', T18'b, T28'b) may return absent, which is a recordable outcome and not a failure; the equilibrium transfer and object-level identification remain ASSUMPTIONS (E8(1)); and the Phase-11 degeneracy is untouched, section (D) being a contrast per the narrowed CTX-DEGEN ruling. Commits 9dbc53d, 0e10fe7, a69a978.
Plan (12-01): THE CURVATURE DOC SPEC (CTX-CURVDOC, CTX-REVIEW). Blocks E0–E8 transcribe Capponi–Jia arXiv:2103.08842v4 §5.1 — **Lemma 3**, **Proposition 5**, **Proposition 6**, read from the PDF, not from the research summary — as one-dimensional algebra over a curvature index, with all equilibrium content frozen into four constants `ϖ_A, ϖ_I, ϖ_H, ϖ_D`. The headline is **`η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)`**, obtained by INVERTING the bijection `κ_φ(η,Δi) = 1 − λ^(−Δi²η/2)` at `κ_φ^★ = 1 − √((1+φ)/(1+ϱ_I))` — a **KINK**, a branch point where the derivative jumps, and **no first-order condition appears anywhere** (both reviewers cleared this; one called it the document's best block). **USER AMENDMENT, BINDING: the curvature index is `κ_φ`, not `χ`** — and applying it exposed that the draft used `\varphi` for the FEE, contradicting M0's own binding of `\varphi` to the quote function, so the fee was retyped `\phi` throughout. That collision survived BOTH reviewers and was invisible to the pre-amendment gate. **USER RULING, BINDING ON 12-02: CTX-DEGEN IS NARROWED — there is no literal de-degeneration theorem.** `mevMulti` contains no η, so the Phase-11 `Θ_φ` degeneracy is untouched; what ships is an interior optimum in a separate Capponi-anchored model plus the η-bridge transport, with `ϱ_I` a CANDIDATE for the demand-elasticity layer `LEAN_TRACEABILITY` §6(b) names, not a closure of it. **THE TWO-REVIEWER GATE PAID FOR ITSELF THREE TIMES.** Reality Checker + Model QA Specialist, spawned as independent OS processes in parallel and blind to each other, both returned NEEDS WORK: **3 BLOCKER, 9 MAJOR, 9 MINOR, 0 blocking rows unresolved.** Every BLOCKER was real and **two were defects the PLAN and 12-RESEARCH had specified**: (i) E7's interior-optimum mechanism was a scalarization story that **CONTRADICTED E4** — `D` does not combine `arbLoss` and `surplus`, investor surplus is not a term of `D` at all, and the peak comes from the LP revenue term's corner→interior regime switch; the reviewer further showed the "two antitone objectives ⇒ interior peak" reading is UNSOUND (branch-constant derivative sign), the same defect Phase 11 refuted, reintroduced as the positive story; (ii) the de-degeneration was **vacuous under the document's own E8(3)**, contrasting two arbitrage objects the document declares unidentified; (iii) E6's "SUPERSEDED" claim over `exp/DynamicsOptimization` required precisely the factor-share identification E8(6) declares OPEN. MAJORs included `ϖ_A > 0` never being assumed (three strictness claims false as written), E1 asserting the `κ_φ ↔ k` identification as definitional (**found INDEPENDENTLY by both reviewers**), `φ̄` being `multiFee`'s FLOOR rather than the fee so `η*` is σ-indexed, "unbounded η helps interiority" being backwards (the map covers `(0,1) ⊊ [0,1]`), and welfare not following from E3+E4. **Where a reviewer contradicted `12-RESEARCH.md`, the PDF and the Lean tree decided — three times, and the reviewers won each time.** The gate itself caught a packaging defect at insertion: the anchor citation lived ABOVE `**E0.` and so did NOT travel into the landed payload; the insertion was REVERTED, an ANCHOR line added inside E0, and the payload re-checked to pass the gate STANDALONE — gating the source file is not gating what lands. `eta-notation-gate.sh` INVERTS Phase 11's Rule 1 (η REQUIRED, not forbidden) and is proven to FAIL on the Phase-11 addendum with the Rule-1 message; the amendment added Rule 4b (kappa admissible only `\varphi`-subscripted; bare `κ` still forbidden) and Rule 4c (`χ` forbidden outright), **both NEGATIVE-TESTED rather than assumed**. Approved bytes pinned by an END-marker-delimited hash **`APPROVED-ETA-SHA256 4f5362c1…`** (`541819fe…` SUPERSEDED by the amendment) plus `APPROVED-ADDENDUM-SHA256 d1bade08…`. M-block integrity PROVEN across both insertions: the M0 → end-of-M8 scope hashed `9fcf01d3…` before AND after each. The plank-owned document and `todo.md` were WRITTEN BUT NOT COMMITTED (owner `ul2inqpl`; plank HEAD `f379f48` identical before and after); the peer handoff went through `todo.md` because the `claude-peers` MCP tool is not exposed to executor sub-agents — **the coordinator should re-send the live notification.** NOT ESTABLISHED: **nothing is proven** — E0–E8 are a specification, no `.lean` file was touched, and both the object-level identification and the equilibrium transfer are ASSUMPTIONS (E8(1)); welfare is OPEN (E8(2)); nine OPEN items in all. Carry-forwards: `12-RESEARCH.md` still carries F8's wrong mechanism, F8's de-degeneration framing and F3's "beyond his range" — correct at 12-04; and another workstream's uncommitted M0–M8 compression pass has ALREADY staled the Phase-11 M-block pins in the plank worktree, independently of this phase. Commits 3256f5b, f28f304, 85fb70b, b4da87f.
Plan (11-06): **PHASE 11 COMPLETE — 6 of 6 plans executed, all eight CTX-* requirements SATISFIED.** The phase delivered what it set out to define and then delivered two REFUTATIONS where it expected positive results, and the traceability record says so in the sanctioned status words rather than softening either. `λ_ARB` is defined, identified and its infimum program SOLVED (`MevOptimization.lean`, 25 declarations); the joint program and the Angstrom bridge are proved (`MevJointProgram.lean`, 27 declarations); both modules are axiom-clean and mirrored to `cfmm-lean4-spec`. **Nothing further is scheduled in Phase 11.** The designated successor thread is the interior-`η` curvature layer (Capponi–Jia, refs in `../plank/refs/mev/`), which is the direct consequence of M6a: over `Θ_φ` alone there is no trade-off to control, so the degeneracy-breaker must come from outside the fee parameter set.
Plan (11-06): THE CLOSE-OUT (CTX-TRACE). The deliverable is an auditable record a future consumer can trust without re-deriving it, and its only real risk was softening. `model/vol_markets/LEAN_TRACEABILITY.md` gained: §0 notation rows for `φ`/`φ̄`, `Δt`, `P_trade`, `a_t`, `λ_ARB`, `λ_MEV` and `τ`, plus a paragraph binding the three resolved MMR collisions (fee `γ` → `φ` with `γ_j` still the sigmoid steepness; block rate `λ` → `Δt ≜ λ⁻¹` because `λ` here is a hazard; composite `η` DELIBERATELY NEVER NAMED, the root-block-rate factor written `√(2/Δt)`) and the binding rule that **`λ_ARB` and `λ_MEV` are never interchangeable — `λ_ARB` is a SUMMAND of `λ_MEV`**, so `a_t` is distinguished from `flairHazard`'s `w_t` and `τ` is marked a protocol parameter OUTSIDE `Θ_φ`; and a new **§7.1 carrying 14 claim rows**. **EVERY BACKTICKED IDENTIFIER IN THE NEW ROWS WAS VERIFIED TO BE A REAL DECLARATION**, not merely present as text: 25 names checked against `^theorem|^noncomputable def` in `MevOptimization.lean` and 27 against `MevJointProgram.lean`, all resolving — a row naming a non-existent lemma is worse than no row, and the check was written to catch exactly that. **THE STATUS WORDS COME FROM THE FIDELITY RECORDS.** `M6a → PROVEN`, with the row text stating the RESULT rather than the aspiration: one admissible point simultaneously maximizes `flairMulti` and minimizes `mevMulti`, in the levels AND the shape coordinate, robust to every scalarization `κ ≥ 0`, so **there is no trade-off over `Θ_φ` and the shape block `(β, γ)` is NOT essential — the phase brief's expectation is refuted, machine-checked**. `M6b general σ-varying schedule claim → REFUTED`, carrying `mev_ge_flat_under_flair_budget_false` and the witness (`T=2`, `Δt=2`, `B=2`, `σ=(1,10)`, unit `w`/`D`, fees `(2,0)`, flat fee `1`) together with the exact-rational recomputation `31/22 ≈ 1.4091` flat against `4/3 ≈ 1.3333` tilted — the flat path is STRICTLY WORSE. **The `Θ_φ`-restricted isotone case is a SEPARATE `OPEN` row**, not folded into the refutation: the witness schedule decreases in σ while every `Θ_φ`-reachable schedule is isotone (`VolInstrument.multiFee_monotone`), and the executor float numerics that point the same way are labelled NOT machine-checked and are merged into no claim. `M5 → CORRECTED → PROVEN` naming both disclosed corrections (T15's added `0 ≤ φ̄max + umax·αmax0`, T17's admissibility constraint — the same `ptrade` negative-fee pole in both places) and `mevMulti_min_gt_corner`'s fixed `u = uMax`. `M3(ii) → OPEN`, marked deliberately optional and non-blocking: T19 was omitted so the exact Corollary-2 CPMM kernel and its `σ²Δt < 8` guard have no carrier anywhere in the repository. `M4 → PROVEN` with the **no affine** finding recorded as a correction of the naive FLAIR-mirror expectation — `ptrade` is not affine, level and shape do not separate, and M5's bound is a path SUM. **THE ROW MOST AT RISK OF BEING OVERSOLD IS THE ONE MOST TIGHTLY BOUNDED:** `arb_add_fee_eq_lvr` carries the words **bridge identity** and **tautology** on its own line, states the ring identity `x·p + x·(1−p) = x` explicitly, and says in terms that it is **NOT a formalization of MMR Theorem 3 / Theorem 4**, which are fast-block small-fee asymptotic approximations formalized nowhere in this phase — so nobody downstream can cite it as "MMR Theorem 3 formalized". §6's stale clause **"MEV section (empty in the doc)"** is gone, and was REPLACED rather than deleted: five gaps are now named precisely — (a) the continuum path-integral form of `λ_ARB` (the discrete functional is the deliverable, as for `λ_FLAIR`), (b) the demand-elasticity/optimal-fee equilibrium layer belonging to `FeeSchedule`, whose exact missing term is the anchor's §7.3 eq. (27), (c) the Theorem 3/4 asymptotics themselves, (d) the exact Corollary-2 kernel, (e) the `Θ_φ`-restricted σ-varying comparison; `𝓖_φ` beyond the `probOr` monoid core keeps its own OPEN line. `VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` gained per-block `> LEAN` annotations on M1–M7 following the `VOLATILITY_INSTRUMENTS_LEAN_ADDENDUM.md` precedent, and **block M6b is AMENDED `OPEN` → `REFUTED`** with the `Θ_φ`-restricted remainder kept OPEN in the same amendment; M8's closing caveat was updated to match so the document does not contradict itself. The plank-owned `../plank/notes/VOLATILITY_INSTRUMENTS.md` received the identical M6b amendment and the landed T20–T30 annotation replacing its `"bundle B in flight"` placeholder — **edited but NOT committed** (owner `ul2inqpl`; plank HEAD `df7088f` identical before and after, only a pre-existing working-tree modification touched). The back-annotation **intentionally invalidates the `APPROVED-ADDENDUM-SHA256` pin in `11-01-REVIEW.md`**, and that is recorded in the addendum header rather than left to be discovered: both doc-fidelity gates (11-02's and 11-04's, which compare the BUNDLED copy to the approved bytes) have already been consumed and both passed, so no downstream check reads the addendum hash. ROADMAP's Phase-11 goal clause was CORRECTED in place without deleting the original intent, its planning-correction note upgraded from "research shows" to "machine-checked", and the six-plan list closed with per-plan outcomes. NO `.lean` FILE TOUCHED (`git status --porcelain lean/` empty) and `lake build` green at close. NOT ESTABLISHED: nothing new was proved here — this plan moved no mathematics, only the record of it; and the `Θ_φ`-restricted varying-σ case remains genuinely OPEN, with a second refutation carrying an explicit `multiFee` witness as the named follow-up. Deviations were mechanical-criterion defects, recorded not papered over: the plan's identifier-existence loop scans the WHOLE file and therefore catches §8's pre-existing `joint_candidates_disagree` (an `EndogenousMaturity.lean` identifier from an independent run, verified present there — §8 was left alone as instructed), and its `! grep -rE '/home/'` criterion false-fails on ROADMAP's pre-existing Phase-1 REPO-05 rows that QUOTE the home-path scrub command; the plan also assumed a `Requirements: TBD` placeholder and a `0 plans` line that a prior pass had already filled. Same self-contradiction class as 11-02's `ptradeCPMM`, 11-03's axiom-name grep, 11-04's phantom `lean` and 11-05's docstring regex.
Plan (11-05, headline): **BUNDLE B IS LANDED AND THE QUEUE IS FREE.** `lean/vol_markets/MevJointProgram.lean` is integrated, registered, green and mirrored to both remotes. **THE T24 VERDICT IS REFUTED (COUNTEREXAMPLE)** — `mev_ge_flat_under_flair_budget_false`, Aristotle's outcome 3, machine-checked and axiom-clean; the general varying-σ flat-fee claim is FALSE, not open. **11-06 INHERITS A REQUIRED DOC AMENDMENT: approved block M6b must change `OPEN` → `FALSE` for the varying-σ schedule comparison, with a `REFUTED` traceability row**, plus an explicit OPEN row for the `Θ_φ`-restricted case which this refutation does NOT settle. Full evidence in `11-05-FIDELITY.md`.
Plan (11-05): LANDING ARISTOTLE BUNDLE B (CTX-JOINT, CTX-ANGSTROM). Task `f8840dab` reached `COMPLETE` and returned `MevJointProgram.lean` — **481 lines, 22 theorems + 5 defs = 27 declarations, sorry-free, and 27/27 `#print axioms` = [propext, Classical.choice, Quot.sound]** (the sweep file was GENERATED from a grep of the module, so it cannot silently omit a declaration; every name resolved and the run exited 0). Integrated with the inverse import rewrite `RequestProject.` → `vol_markets.` as the ONLY edit, registered as a lakefile root (APPENDED after `EndogenousMaturity`/`MevOptimization`, removing nothing — the build log's `Built vol_markets.MevJointProgram (27s)` is the evidence the module was actually elaborated and not skipped by an unregistered root, which would have made the green build vacuous), `lake build vol_markets` 8039 jobs and `lake build` 8063 jobs both exit 0. **BYTE-IDENTITY HELD: all ELEVEN submitted dependency modules returned with empty diffs**, checked BEFORE integrating anything, including the already-proven `MevOptimization.lean` and `FlairOptimization.lean`, and the bundled document too. **THE T20–T30 DIFF IS THE DELIVERABLE, AND IT IS PERFECT: every specified statement — T20, T21, T22, T23, the four path carriers, T24's refutation, T25, T26, T27, T28, T29 and T30's four declarations — is BYTE-IDENTICAL to the sha-verified prompt** (whose hash re-verified at integration time equals the `11-04-RUN-RECORD.md` pin, so the diff is against the bytes actually sent). **Zero narrowing, zero renaming, and — unlike bundle A, whose T15 was FALSE as specified — ZERO corrective hypotheses**; the only additions are the two the prompt PRE-AUTHORIZED on T25's strict companion (`0 < w t` on the whole range, plus a non-constancy witness), Aristotle having said which route it took. **THE FINDING: T24 IS FALSE.** The volatility-varying Jensen statement, this phase's declared main mathematical risk, came back as **outcome 3 — the machine-checked negation theorem `mev_ge_flat_under_flair_budget_false`**, whitespace-normalized character-for-character the block the prompt mandated, and axiom-clean because it closes by `norm_num` on numerals rather than the compiled-evaluation tactic the prompt forbade. Witness: `T=2`, `Δt=2`, `σ=(1,10)`, unit weights and denominators, evaluated fees `(2,0)`, budget `B=2`, flat fee `1`. **Recomputed INDEPENDENTLY outside Lean in exact rational arithmetic rather than taking the prover's word: flat path `1/2 + 10/11 = 31/22 ≈ 1.4091` against tilted path `1/3 + 1 = 4/3 ≈ 1.3333` — the flat fee is STRICTLY WORSE, so the claim is violated.** The failing hypothesis is named in the module's own docstring: volatility VARIES, so the summands are DIFFERENT convex functions at different `t` and ordinary Jensen never applies — exactly the non-sign-definite covariance term the prompt anticipated. **THE REACH IS BOUNDED EXPLICITLY RATHER THAN OVERSOLD**, which is the plan's real deliverable: the witness schedule `if x = 1 then 2 else 0` DECREASES in σ, whereas every `Θ_φ`-reachable schedule is ISOTONE (`VolInstrument.multiFee_monotone` proves `Monotone (multiFee …)` under `0 < γ j`, `0 ≤ α j`, `0 ≤ u`). So the theorem settles the GENERAL schedule-level claim — which approved block M6b had labelled OPEN and **which must now be corrected to FALSE, with a REFUTED traceability row** — but the **`Θ_φ`-RESTRICTED varying-σ case is recorded as still OPEN**. Executor numerics indicate the violation persists there too (a genuine `multiFee(σ) = 2 + 2·logistic(8·(σ−1.5))` at `σ=(0.5,2.5)` gives flat `1.194805` vs schedule `1.169203`), and they are labelled **NOT machine-checked** and are deliberately NOT merged into the verified claim; a second refutation carrying an explicit `multiFee` witness is the named follow-up. ANTI-RELABELLING VERIFIED: T25 exists under its own `const_sigma` name at the PATH level (via the new `flairPath`/`mevPath` carriers and their two `rfl` bridges) with a strict companion consuming `ptrade_strictConvexOn` — the STRICT form, not the non-strict fallback — and is NOWHERE described as satisfying T24 or as covering CTX-JOINT's general case. WHAT IS NOW PROVED: the unconstrained joint program is DEGENERATE (T20–T22 — one admissible point simultaneously maximizes `flairMulti` and minimizes `mevMulti`, in the levels AND the shape coordinate, robustly to every scalarization `κ ≥ 0`, so **there is no trade-off over `Θ_φ` and the shape block `(β, γ)` is NOT essential**, the phase's own expectation machine-checked as refuted); the budget pins the mean fee (T23); the constant-σ path-level flat-fee optimality with its strict half (T25); and the whole Angstrom bridge (T26–T30 — the rebate with nonnegativity DISCHARGED on `mevMulti_nonneg` rather than assumed, `mevNet_argmin_invariant` showing that for every `τ < 1` the rebate changes the program's VALUE and not its SOLUTION so `τ` is formally outside `Θ_φ`, `taxFraction k = k/(k+1)` with `k` FREE and no numeral in any statement, `mev_mono_dt` ISOTONE in `Δt`, and **`mevTotal := lamARB + lamSand` PLAIN ADDITION** with the `probOr` correspondence in its own lemma — the 11-04 reviewer BLOCKER, correctly built). Three binders returned UNUSED (`hW` on `flair_budget_mean` and `flairPath_budget_mean`, `hτ1` on `mevNet_le_mev`), so those theorems are STRONGER than specified — recorded, not edited, since touching a returned proof voids its verification. NOT ESTABLISHED: the general varying-σ flat-fee claim (FALSE); the `Θ_φ`-restricted varying-σ case (OPEN); and the aligned-measure `a = w` used by T24/T25 is imposed by direct substitution rather than as an explicit hypothesis, which is what the prompt specified but is flagged for readers. Deviations were all mechanical-criterion defects, RECORDED rather than papered over: the plan's tax-constant regex requires a comment marker at line start and so FALSE-FAILS on Lean block-docstring continuation lines (verified instead with a comment-aware scanner tracking `/- … -/` nesting — PASS, both `49`/`0.98` hits inside the docstring, no numeral in any statement); `aristotle download --destination` writes an ARCHIVE FILE and extracts one directory deeper than the plan assumes (symlinked so the plan's literal criterion runs as written); and `tail -60` missed the appended run summary (closing provenance line added). Same self-contradiction class as 11-02's `ptradeCPMM`, 11-03's axiom-name grep and 11-04's phantom `lean`. Pushed to origin (`94e7fa9`) and to `cfmm-lean4-spec` main (subtree `81b2729`, verified a fast-forward before pushing). Memory `aristotle-mev-bundle-b-inflight` flipped to RESOLVED: **the queue is FREE**. Commits 9e2a587, 94e7fa9.
Plan (11-04): ARISTOTLE BUNDLE B — THE JOINT PROGRAM + THE ANGSTROM BRIDGE (CTX-JOINT, CTX-ANGSTROM, CTX-REVIEW). An 850-line T20–T30 specification over an 11-module bundle (bundle A's ten plus the newly PROVEN `MevOptimization.lean`, which is now itself an off-limits artifact) was submitted as **the single in-flight task: project `19f777ab-e4ca-47ca-86a1-bf64af79fa90`, task `f8840dab-5723-4a09-9632-1391561180c5`**, target `RequestProject/MevJointProgram.lean`. Sections: **(A) the DEGENERACY T20–T22** (M6a — one point simultaneously maximizes FLAIR and minimizes MEV, in the levels AND the shape coordinate, robustly to every scalarization κ ≥ 0: the phase's REFUTATION result); **(B) the CONSTRAINED program T23–T25** (M6b — the budget pins the mean fee, then the σ-varying Jensen statement); **(C) the ANGSTROM bridge T26–T30** (M7 — rebate, argmin-invariance, parametric tax, cadence, sandwich reduction). **THE GATE EARNED ITS KEEP AND THE PLAN WAS WRONG.** Two reviewers (Reality Checker + Model QA Specialist, the same specialist pick as 11-01/11-02 so the three gates are comparable) were spawned as **independent OS processes in parallel, blind to each other**, because the `Task` sub-agent tool was unavailable — which made their convergence evidence rather than an echo. Both returned NEEDS WORK and **both independently found the SAME BLOCKER**: **11-04-PLAN.md's own action text specified `mevTotal := VolInstrument.probOr lamARB lamSand`, and approved block M7 explicitly forbids exactly that** — "⊕ is hazard-side addition, plain addition of rates … ⊗_φ acts on probabilities in [0,1] and is NOT applied to the unbounded hazards directly". Verified independently against M7 AND against the **already-proven `VolInstrument.probOr_hazard`, whose statement IS the proof** that the hazard-side image of `probOr` is `λ_M + λ_X` — the project already owned the lemma refuting the draft. **The defect was INVISIBLE to every downstream check**: at `λ_sandwich = 0` both reductions hold under either definition, so the module compiles, the axiom sweep is clean and 11-05's fidelity diff passes, while shipping an object that is wrong for every nonzero sandwich (`probOr 2 2 = 0` reports two active channels as zero total MEV). Corrected to `lamARB + lamSand` with the correspondence preserved as a new named lemma `mevTotal_probOr_hazard`. Doc-over-plan, exactly as 11-02 adjudicated its `·Δt` BLOCKER. **EXECUTOR-FOUND BEFORE EITHER REVIEWER RAN: the plan's T25 was a TRIVIALITY** — at the schedule level with σ_t ≡ σ0 every `Θ_φ` schedule already yields a constant fee path, so both sides collapse to an EQUALITY and the strict half's non-constancy hypothesis is UNSATISFIABLE; it would have returned "proved" and been banked as the delivered fallback while carrying no content. That is the document's OWN M6b OPEN note. Fixed by introducing path-level carriers `flairPath`/`mevPath` with two definitional bridges and stating T25 at the PATH level (the doc's own quantification), keeping T24 at the schedule level where varying σ makes it non-vacuous. Two MAJORs also resolved: a **letter-compliant loophole** in T24's outcome 2 (a prover could add a hypothesis forcing the fee path constant — one of the prompt's own examples — and deliver the trivial collapse under T24's name without breaching the anti-relabelling clause), and the omission of **M8's SCOPE OF THE AGGREGATE caveat** in the one module that names an object "the total", where multi-block censoring and cross-batch sandwiching attack T29/T30 directly. Reviewer 1 additionally re-derived the covariance sketch by hand (correct), diffed every quoted signature byte-for-byte, and **closed 11-RESEARCH Open Question Q5** by verifying the four Mathlib Jensen lemmas with line numbers (`ConvexOn.map_sum_le` :67, `map_centerMass_le` :52, `StrictConvexOn.map_sum_lt` :103 with its `0 < w i` whole-index requirement). DOC FIDELITY RE-PROVEN AT SUBMIT TIME AGAINST ALL THREE COPIES while the coordinator's prose pass was concurrently live: `BUNDLED-DOC-SHA256` still equals the 11-02 pin and the 11-01 APPROVED hash (671000a5…), M-block diffs EMPTY for approved-vs-bundled AND approved-vs-LIVE; **the whole-file live hash MISMATCHES and that is EXPECTED** (646→745 lines, every change outside `### MEV`) — the M-block diff is the gate, the whole-file hash is not. Notation gate PASS on the addendum and the bundled `### MEV` section; the informational FAIL on the prompt is RECORDED not suppressed (both hits are the `η` PROHIBITION — mention, not use). ESCALATED NOT FIXED: M7(i)'s display reads as "LP incidence = full tax fraction" while the doc's own prose records a creator/protocol/LP split — surfaced to the user, the plank-owned document NOT edited, and the prompt-side mitigation (T28's upper-bound docstring) already prevents any theorem carrying the conflation. NOT ESTABLISHED: **nothing is proven** — T20–T30 are a specification, status `IN_PROGRESS` at close, and the plan's `<done>` is only PARTLY met (submitted with full provenance ✓; "reported COMPLETE with the T24 outcome stated" ✗). **T24 (the σ-varying Jensen statement) is the phase's main mathematical risk and may not come back**: the summands are different convex functions, plain Jensen does not apply, and the covariance bound is not sign-definite. **A returned T25 with T24 OPEN is an ACCEPTABLE outcome that MUST be recorded as OPEN and never relabelled a success.** NO LEAN FILE TOUCHED (`git status --porcelain lean/` empty across both commits); no key in any tracked file. In-flight task recorded in memory `aristotle-mev-bundle-b-inflight`. Commits 99cf6c5, 2831daf.
Plan (11-03): LANDING ARISTOTLE BUNDLE A (CTX-PTRADE, CTX-MEVHAZ, CTX-INF). Task `d1c57297` reached `COMPLETE` and returned `MevOptimization.lean` — **1046 lines, 3 defs + 22 public theorems + 3 private helpers, sorry-free, and 25/25 `#print axioms` = [propext, Classical.choice, Quot.sound]** (the sweep file was GENERATED from a grep of the module, so it cannot silently omit a theorem). Integrated with the inverse import rewrite `RequestProject.` → `vol_markets.` as the ONLY edit — hand-editing a returned proof voids its verification — registered as a lakefile root (the build log's `Built vol_markets.MevOptimization (57s)` is the evidence the module was actually elaborated and not skipped by an unregistered root, which would have made the green build vacuous), `lake build vol_markets` 8038 jobs and `lake build` 8062 jobs both exit 0. **BYTE-IDENTITY HELD: all ten submitted dependency modules returned with empty diffs**, checked BEFORE integrating anything and corroborated from the repo side (`git status --porcelain lean/` showing exactly the two intended entries; empty `git diff --stat` over FlairOptimization and VolInstrument) and by Aristotle's own summary. **THE T1–T19 DIFF IS THE DELIVERABLE**: every T-number has an explicit disposition in `11-03-FIDELITY.md`; **no T1–T18 item is MISSING and NO returned conclusion is NARROWED**. All four narrowings the run record told this plan to watch for held: **T6 came back `StrictConvexOn`** (proved from the definition via the `X/Y + Y/X > 2` route, with `ptrade_convexOn` as the named weakening — both names exist), **T13's bound is a `Finset` SUM** and not the product form that would be false since `ptrade` is not affine, **T8 kept its `·Δt`** (11-02's first BLOCKER survived the round trip) with the finiteness guard correctly NOT attached, and **T17 carries the admissibility constraint and PROVES `ContinuousOn`** via `IsCompact.exists_isMinOn` rather than assuming it — the degenerate repair the prompt forbade appears nowhere in the file. **THE FINDING: T15 AS SPECIFIED WAS FALSE.** Aristotle added `hfee : 0 ≤ φbarMax + uMax·αmax0` to `mevMulti_saturation_limit` and says why in its own run summary — without it the limiting fee lands on **`ptrade`'s negative-fee pole**, the SAME pole both 11-02 reviewers used to demolish the pre-review T17. The reviewers found it in one place; it was live in two, and the prover closed the second. Recorded as STRENGTHENED-HYPOTHESES with its reason, alongside three smaller additions (`0 ≤ u` on T11, a redundant `0 ≤ αmax j` on T14, the upper-box constraint on `mevMulti_min_gt_corner`). WHAT IS NOW PROVED: `ptrade φ σ Δt = σ/(σ + φ·√(2/Δt))` with all seven of M1's properties (strict antitone in the fee, strict convexity — neither downgraded); `mevHazard`/`mevMulti` over the SAME `multiFee` parameter space and the SAME `D t` denominator as `FlairOptimization.flairHazard`, so the hazards are commensurable BY CONSTRUCTION; the antitone identification with every FLAIR direction reversed (strict in φ̄, weak in α and u, ISOTONE in β); and the solved infimum program — path-sum corner bound, bang-bang level corner, `β0 → −∞` saturation limit, strict gap at every finite β0, compact-box minimizer, `Theta_lambdaMEV_identification`, and `mevMulti_min_gt_corner` for M5(iii)'s strict half. **`Θ_{λ_ARB} = {φ̄, α, u}` at its UPPER corner; the shape block cannot attain the infimum** — the exact reversal of the solved FLAIR supremum, now machine-checked. NOT ESTABLISHED: **T19 was omitted**, so block M3(ii)'s exact CPMM kernel `ARBoverV_exact` has NO formal carrier anywhere in the repo and the `σ²·Δt < 8` finiteness guard lives nowhere — optional and non-blocking, but reported rather than dropped; **CTX-INF is satisfied by a CORRECTED T15**, meaning the prompt was wrong in one more place than its two-reviewer gate caught; the three private helpers were not individually axiom-printed (private names are mangled) and their cleanliness is a transitive INFERENCE from the 25 clean public prints, labelled as one; `mevMulti_min_gt_corner` fixes `u = uMax` rather than quantifying, and the argument that this is the sharp case is an EXECUTOR argument, not machine-checked; and this is `λ_ARB`, a SUMMAND of `λ_MEV`, equal to the aggregate only under M7's uniform-clearing reduction that is not formalized here. Deviations: `aristotle download --destination` writes an ARCHIVE FILE not a directory (renamed + extracted per the existing scratch convention); the lakefile anchor had moved under an independent parallel run (`b03494d`, EndogenousMaturity) so the new root was APPENDED after it, removing nothing; and the fidelity record's own acceptance criterion greps it for the forbidden axiom names, so the clean sweep is stated by description rather than by writing them — the same self-contradiction class 11-02 hit at `ptradeCPMM`, resolved the same way. Pushed to origin (`42c8e60`) and to `cfmm-lean4-spec` main (subtree `19afcdd`, verified a fast-forward before pushing). Memory `aristotle-mev-bundle-a-inflight` flipped to RESOLVED: **the queue is FREE**. Commits 5dd94e9, 42c8e60.
Plan (11-02): ARISTOTLE BUNDLE A — ptrade, λ_ARB, THE INFIMUM PROGRAM (CTX-PTRADE, CTX-MEVHAZ, CTX-INF, CTX-REVIEW). A reviewer-gated T1–T19 numbered specification over a 10-module bundle (the FLAIR run's 9 plus `FlairOptimization.lean` as the mirror template it must reverse and NOT modify) was submitted as **the single in-flight Aristotle task: project `cb371ee5-f27c-48d2-a396-725751fd7c36`, task `d1c57297-39b2-47ad-8048-492a407c6498`**, target `RequestProject/MevOptimization.lean`. THE DOC FIDELITY GATE IS THE POINT: the bundled document is a copy of a LIVE, UNCOMMITTED, PLANK-OWNED file, so it was proved faithful TWICE and independently — `BUNDLED-DOC-SHA256` == `APPROVED-DOC-SHA256` 671000a5… (live plank file agreeing at submit time), AND an M-block byte diff against the approved addendum that is empty (181 lines each) — re-run after every prompt edit and again immediately before submit, because the plank file could have moved while the reviewers ran. **The prover received bytes identical to what the user approved.** THE TWO-REVIEWER GATE (Reality Checker + Model QA Specialist, again run IN PARALLEL as independent read-only processes; the same specialist pick and reason as 11-01, deliberately, so the two gates are comparable) was run on THE PROMPT — the artifact the prover consumes — not on the plan (PIT-7). Both returned NEEDS WORK: **2 BLOCKERs + 3 MAJORs + 6 MINORs, every blocking row resolved before the submission was spent.** THE TWO BLOCKERS WERE REAL AND EACH WOULD HAVE BURNED THE ONE-SHOT RUN: (1) **T8 had dropped the doc's `·Δt` factor** from the M3(i) weight — silently RE-INTRODUCING the exact rate-vs-amount defect 11-01's own gate caught as its BLOCKER 4; the Δt-less form came from the pre-gate research file AND from this plan's own task text, and was corrected against the approved doc under the binding doc-over-plan rule; without it the summand scales √Δt instead of MMR's Δt^{3/2}, understating the batch-cadence lever — the phase's second non-degenerate lever — by a full factor of Δt. (2) **T17 was PROVABLY FALSE as written**: both reviewers independently built the same counterexample — `ptrade` has a pole at negative fees, so on an arbitrary compact Θ the objective is discontinuous and unbounded below and NO minimizer exists (T=1, σ=1, Δt=2, Θ=[−2,0]×{0}³ ⟹ 1/(1+φ̄) → −∞). FLAIR needed no constraint only because `flairMulti` is AFFINE hence continuous on ℝ⁴ — **a SECOND place the mirror breaks, beyond the single one RESEARCH F4 tabulates**; T17 now carries an admissibility constraint and explicitly FORBIDS the degenerate "just add ContinuousOn" repair, which would be true while gutting the theorem. The three MAJORs: M5(iii)'s "strictly exceeds the displayed bound" half had NO carrier (a clause 11-01's reviewer specifically fought for) ⟹ new corollary `mevMulti_min_gt_corner`; M1's "increasing in σ" was the one of seven documented P_trade properties left uncarried ⟹ `ptrade_monotoneOn_sigma`; and the λ_ARB object carried the AGGREGATE's name, risking the `mevHazard + sandwich` double-count M0 forbids ⟹ mandatory docstring caveat rather than a rename (renaming would break the plan's own acceptance criteria and 11-03's integration keys). EXECUTOR-FOUND, INDEPENDENT OF THE REVIEWERS: **three Mathlib hints the plan supplied DO NOT EXIST at the pinned v4.28.0** — `strictConvexOn_inv`, `StrictConvexOn.comp_affineMap`, `StrictConvexOn.smul` all grep to zero hits (only the NON-strict `ConvexOn.comp_affineMap` exists; Mathlib has no strict affine-precomposition lemma at all) — replaced with verified routes (`strictConvexOn_of_deriv2_pos'` Deriv.lean:308, `strictConvexOn_zpow` :99, `StrictConvexOn.convexOn` Function.lean:360) and the non-existences STATED so the prover does not hunt for them; left in, they would likely have pushed it to downgrade T6 to `ConvexOn`, the exact silent narrowing the plan forbids. The Reality Checker independently re-verified every Mathlib citation INCLUDING the three non-existence claims. QUEUE PROVEN EMPTY before submit (`--status RUNNING` → "No projects found"; all five most recent IDLE; newest 78bac8dd/FLAIR COMPLETE) so exactly ONE task is in flight. Also found: `aristotle show` STREAMS and blocks (hung a 2-min call) — poll with `aristotle tasks`. Bundles are NOT committable (`scratch/` gitignored, and NO prior Aristotle bundle was ever tracked), so their identity is the sha256 pins in the committed run record — the mechanism the plan already built. NOT ESTABLISHED: **nothing is proven yet** — T1–T19 are a specification, status `IN_PROGRESS` at close (~22 min, 18 polls), and the plan's `<done>` is only PARTLY met (submitted with full provenance ✓; "reported COMPLETE with the user cleared to integrate" ✗). The T1–T19 fidelity checklist in the run record is 11-03's diff target; T6 (strict convexity), T16 and T17 are the likeliest to return narrowed. Accepted-not-eliminated: the CLI's missing-`.lake` warning (the FLAIR bundle also had none and returned 15 axiom-clean theorems) — first suspect if the run fails to build server-side. NO LEAN FILE TOUCHED (`git status --porcelain lean/` empty across both commits); no key in any tracked file. In-flight task recorded in memory `aristotle-mev-bundle-a-inflight`. Commits b8b29be, e5cb8dd.
Plan (11-01): THE λ_MEV DOC SPECIFICATION (CTX-MEVDOC, CTX-REVIEW). `VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` = ten insert-ready LaTeX blocks (M0–M8) transcribing — never re-deriving — Milionis–Moallemi–Roughgarden arXiv:2305.14604v2 under three mechanically-enforced notation substitutions (MMR fee γ→φ, MMR block rate λ→Δt, MMR composite η NEVER named since η is the reserved pricing kernel). THE TWO SUBSTANTIVE RESULTS ARE STATED AS DELIBERATELY SEPARATE CLAIMS, which is the whole point: **M6a the DEGENERACY** — unconstrained over Θ_φ the same corner point and the same saturating direction β→−∞ simultaneously maximize λ_FLAIR and minimize λ_ARB, robustly to any linear scalarization, so **the phase brief's expectation that the shape block (β, γ_j) becomes essential is REFUTED and says so in those words**; and **M6b the CONSTRAINED result** — over arbitrary fee PATHS at fixed FLAIR income the flat path minimizes λ_ARB and any path non-constant on the positive-weight steps is strictly worse, with the σ-varying SCHEDULE comparison labelled OPEN. `mev-notation-gate.sh` enforces PIT-1/2/3 mechanically; its only escape hatch is the `<!-- notation-map -->` marker and rule 7 bounds that marker to the header/M0, so the specific weakening of "just mark the offending line" is itself caught. THE GATE DID REAL WORK: it caught three genuine violations during authoring and resolution and the ADDENDUM was fixed each time — **the gate was never weakened** (still 6 markers, all before the M1 header). TWO REVIEWERS RAN IN PARALLEL as independent read-only processes (Reality Checker, mandatory; Model QA Specialist, picked as the closest catalog specialist to quant-finance/microstructure — pick and reason recorded), both returned NEEDS WORK, and **4 BLOCKERs + 12 MAJORs + 10 MINORs were all resolved before approval was requested**. The four BLOCKERs were not cosmetic: (1) the draft used `\varphi` for the fee but the parent doc binds `\varphi` to the QUOTE FUNCTION (line 305) and uses `\phi` for the fee — a same-concept/different-glyph clash the gate structurally could not see, and one that would have shipped a wrong Lean module; (2) `argsup = arginf` was ill-posed since both arg-sets are empty over the unbounded shape block by the project's own PROVEN `flairMulti_strict_below_saturation` — restated as three well-posed claims; (3) M6b's headline was VACUOUS because `multiFee` depends on σ alone, so at constant σ every admissible schedule already yields a flat path — the doc was claiming in bold the conclusion of its own OPEN problem; (4) `a_t` was dimensionally wrong — MMR's LVR is a RATE per unit time, so the per-block weight needs ·Δt, without which the sum mixed rates with amounts, commensurability with λ_FLAIR was false, and the Δt cadence lever was understated by a full factor of Δt. Five source-dependent findings were RE-VERIFIED by the executor directly against the paper before acting (LVR-as-rate :882–884; per-block Δt^{3/2} :1344–1346; eq. (27)'s dropped "delta-hedged" :1482; the `\varphi` binding at parent :305; Assumption 2 :548–556) — all five confirmed. SOURCE CONFLICT ADJUDICATED: BLOCKER 3 contradicts 11-RESEARCH F6, which asserted the schedule-level claim outright; the reviewer won, the paper is silent, and the disposition records which source won. USER APPROVED at the blocking checkpoint (verbatim reply recorded); blocks landed in `../plank/notes/VOLATILITY_INSTRUMENTS.md` under `### MEV` — the two pre-existing bullets KEPT verbatim, 181 lines appended, 464→646, **0 deletions**. THE APPROVED BYTES ARE PINNED (`APPROVED-DOC-SHA256` 671000a5…, `APPROVED-ADDENDUM-SHA256` e9ff2b4c…) so a downstream bundle copy can be PROVED faithful — 11-02/11-04 grep the first, and any further edit to the `### MEV` section hard-fails rather than silently drifting. Gate against the plank doc: the whole-file run FAILS rule 1 on the doc's OWN legitimate pricing-kernel η (lines 262/263/294/295/388) — exactly the case the plan anticipated — so an extracted `### MEV` section was gated instead: PASS; **both runs recorded, the failing one not suppressed**. NO LEAN FILE TOUCHED (`git status --porcelain lean/` empty across all three commits) and no Aristotle task run. Plank worktree HEAD 8f43641 identical before and after; nothing committed there (owner `ul2inqpl`). NOT ESTABLISHED: nothing here is proven — these are doc-level claims awaiting Aristotle, and M6a/M6b are the statements most likely to acquire extra hypotheses when formalized. OPEN THREAD: the `claude-peers` tool was not exposed to the executor, so the peer notification to `ul2inqpl` rides on the `../plank/todo.md` handoff entry (precedent 489bb43) and a coordinator relay. NEXT PHASE DESIGNATED BY USER at the checkpoint: interior η (Capponi–Jia curvature, refs in `../plank/refs/mev/`) is the degeneracy-breaker — the direct consequence of M6a, since over Θ_φ alone there is no trade-off to control. Commits 265b937, f6e89bc, 4d66f1f.

Superseded position (Phase 10) — Phase: 10 of 10 (Streaming Premium Reconstruction & Re-estimation) — Lean4 + Haskell econometrics track
Plan: **10-11 COMPLETE — PHASE 10 IS CLOSED.** 11 of 12 plans executed; 10-12 (CTX-REPLAY-OPT, optional and non-blocking by construction) is SKIPPED and recorded as such, NOT as satisfied. THE PHASE'S VERDICT CHAIN, end to end: Wave-0 census **GO** (on the hourly re-scope; the daily grid returned STOP on its own pre-committed rule and that STOP was honoured) -> reconciliation gate **PASS** (61/61 spells, short-stratum median relative error 0.000000 in Integer ETH wei, 53/61 exact to the wei, worst 5.447268e-4 against a tolerance of 0.01 that was never modified) -> stopping rule **UNINFORMATIVE under BOTH LHS constructions** (half-widths 1.479533e-1 and 1.979569e-1 against the never-moved 6.2e-5 bar). **THE PHASE'S SUCCESS CRITERION IS NOT MET AND THAT IS THE REPORTED RESULT: this market cannot identify upsilon.** No respecification, no subsample hunting, no estimator fishing was performed and none is scheduled.
Plan (10-11): THE CROSS-WALK + CLOSE-OUT (CTX-XWALK). `lean-haskell-crosswalk.md` now carries the Panoptic-vs-Lean multiplier wedge as a THREE-REGISTER row (Lean `Panoptic.streamingPremium` = the bare fee-revenue identity with NO multiplier / Haskell `Panoptic.Premium.premiumWei` on `SFPM.getAccountPremium` deltas, which ALREADY includes it / spec 4.3) and — the substantive deliverable — as a **MEASURED distribution rather than a quoted bound**, recomputed here in exact rational arithmetic over ALL 8,910 rows of premium-accumulators.csv: N 8910, min 1.000000, p25 1.000000, **median 1.112500**, mean 1.117256, p75 1.204167, **p90 1.291667**, max 1.291667; **38.9% of readings (3467/8910) sit at exactly 1** (R = 0); long readings (n 2839) median 1.222222 max 1.291667, short (n 6071) median 1.000000 max 1.204167; implied max R/N 2.333333. The median/min/max and both branch maxima REPRODUCE the 10-10 figures exactly; p25/p75/p90/mean are new and the method is recorded in the file. **The 1.125 "bound" is CORRECTED IN THE FIDELITY RECORD, not repeated**: `1 + nu` caps the long branch only when `R <= N`, and here it does not. LEVEL vs SHAPE, stated without overclaiming in either direction: the wedge makes `upsilon0` unambiguously the vega of PANOPTIC'S premium (a reinterpretation of what the parameter denotes, never an adjustment to apply — the multiplier is already inside the contract's X64 accumulator); it contaminates `kappa` only insofar as R/N co-varies with moneyness, and **that contamination is NOT demonstrably negligible and is flagged as a threat to validity** — on a chunk-level moneyness proxy (|chunk centre - at_tick|) Pearson corr(wedge,d) = 0.143545, Spearman 0.122141, and the per-quintile median wedge is NON-MONOTONE (1.125000, 1.000000, 1.000000, 1.112500, 1.187500). Its DIRECTION is recorded once and not over-read: a wedge rising in d inflates far-OTM premia relative to ATM, flattening the observed decay, so it biases kappa-hat TOWARDS zero and the kappa>0 rejection is conservative with respect to it — a proxy-based directional argument, explicitly NOT a bias correction and NOT a bound (the proxy is chunk-level; the panel's moneyness is position-level). WITNESS STATUS recorded as terminal: `exp_family_witnesses_ATMOTM` PROVED, sorry-free, axiom-clean; `hk` STATISTICALLY SUPPORTED (kappa-hat 3.041754e-2, p 7.308348e-3); `hu` SIGN ONLY (upsilon0-hat 0.106332, 95% CI [-9.162517e-2, 0.304289] contains zero, p 0.146215); `hd` satisfied; **the witness DOES NOT OBTAIN** and `ATMOTMNullHypothesis` stays OPEN. A SIGN-CONVENTION note was added for future consumers: panel-epoch.csv's `premium_wei` is the protocol's own sign (canonical — it sums to the gate-validated recon_wei), while the regression LHS requires `Panel.Build.premiumUsd`'s seller-side normalization applied via `--seller-side-normalize`; v2 is the un-normalized arm and v3 the normalized one, neither wrong, and mixing them silently is the exact defect that forced the 10-10 HALT. Six new grep-able fidelity anchors, each verified against source before being written (multiplierWedge's nu = 1 % 8 and R=0-first branch; vegoidConst == 8 in calldata slot 7; premiumWei's `2 ^ (64 :: Int)` X64 scale with long negation; decomposePremium — not telescope — as what `premiumObsChain` actually builds the panel from; premiumUsd's sign). NO LEAN FILE TOUCHED and no Aristotle task run — `git status --porcelain lean/` empty across both commits. No econometrics source changed; suite stays 215/0.
Plan (10-10): RE-ESTIMATION + THE PRE-COMMITTED STOPPING RULE (CTX-EST2). **THE TERMINAL ESTIMATION RUN OF PHASE 10, executed twice under a user-adjudicated HALT.** The Phase-9 estimator was consumed BYTE-UNCHANGED — `git diff` over `src/Model/`, `src/Tests/` and `Alternatives.hs` is EMPTY across every commit of this plan and the modules were last touched by bb15a96 in Phase 9; ALL wiring lives in `app/Main.hs`, which is exactly what keeps "only the LHS changed" a one-line audit rather than a claim. RUN 1 (as-is protocol sign, 6,760 rows / 55 clusters): upsilon0-hat 3.597340e-2, clustered CR0 SE 7.548636e-2, **CI half-width 1.479533e-1 vs the pre-committed 6.2e-5 bar => STOPPING_RULE UNINFORMATIVE**. The verdict is result-blind BY CONSTRUCTION: `stoppingRuleVerdict :: Double -> String` takes the half-width and nothing else, so it cannot consult kappa's sign or any p-value even by accident. SIDE FINDING, REAL AND REPORTED WITHOUT OVER-READING: kappa-hat 3.090495e-2 (SE 1.318375e-2, p 9.534719e-3) — **H0 of a FLAT vega profile REJECTS for the first time in this project**; position-FE, which Phase 9 could not identify at all, is now IDENTIFIED (6,757 obs / 52 clusters, kappa_FE 3.162e-2) and CONCURS, so strike-composition selection does not appear to be doing the identifying work; symmetry also rejects (p 2.4e-7). THE HALT: a construction defect surfaced AFTER the verdict was computed — 10-09's `assembleEpochPanel` kept the protocol's sign while Phase 9's `Panel.Build.premiumUsd` normalizes long spells to the seller side ("the same vega would enter the regression with two opposite signs and cancel"), leaving 2,280/6,760 rows (33.7%, 8/55 tokenIds) opposite-signed with an unambiguously attenuating effect on the adjudicated quantity. The executor did NOT fix it in place, froze the verdict, and DECLINED to propose the re-run from inside the run; USER adjudicated `escalate-anomaly` under the anti-fishing-replication discipline; the coordinator committed a disposition memo and a pivot lock (cda0a15). RUN 2 (terminal, under lock `phase10-plan10-10-run2` whose sha256 56044349...43e9998 is VERIFIED AT RUN TIME — the CLI ABORTS on mismatch, because the lock's own terms void it if edited post-commit): THE SINGLE CHANGE was long-tokenId premium x (-1), and it was VERIFIED rather than asserted — an independent Python comparison of the two exports gives **0 rows differing in any regressor, 1,735 pi values flipped** (= 2,280 long rows - 545 long zeros), 5,025 identical, 0 otherwise. Result: upsilon0-hat 1.063317e-1, SE 1.009984e-1, **half-width 1.979569e-1 => STOPPING_RULE UNINFORMATIVE AGAIN**. **THE CONCLUSION: this market cannot identify upsilon.** The sign defect was real and is fixed; fixing it did NOT change the verdict, so the uninformative interval cannot be attributed to it — a stronger claim than run 1 alone could support. Pre-registered branch A obtained via the FIRST disjunct ONLY: |upsilon0| moved AWAY from zero x2.956 (consistent with the pre-named de-cancellation mechanism) but the SE **WIDENED** x1.338, which is expected when LHS magnitudes grow and is explicitly NOT evidence for the mechanism; D1 improved 4.113 -> 1.862 while **D2 is "no" in BOTH arms** — the CI contains zero either way. kappa>0 PERSISTS (p 9.534719e-3 -> 7.308348e-3), exactly as the lock anticipated. THE FORMAL WITNESS DOES NOT OBTAIN: hk is statistically supported, hu is satisfied in SIGN ONLY (p 0.146, CI contains zero); the witness bar was TIGHTENED mid-plan to require support on BOTH hypotheses (the theorem takes hu AND hk), which is strictly harder to assert — the 09-09 over-read lesson applied. `exp_family_witnesses_ATMOTM` stays PROVED and axiom-clean and the conjecture stays OPEN; no Lean file was touched and no Aristotle task was run. THE BAR WAS NEVER MOVED: mid-run it emerged that 6.2e-5 carries Phase 9's USD/day units while the realised half-width carries this panel's ETH/hour units — RECORDED in both outputs, repaired in NEITHER, and frozen explicitly by the lock. TWO FURTHER CORRECTIONS: the quoted 1.125 multiplier-wedge bound is FALSE on this market (measured median 1.1125, long max 1.2917, short max 1.2042 — `1+nu` bounds it only when R <= N, and here R/N reaches 2.33), and `guardFrozen` now refuses in CODE to overwrite an analysis carrying a CORRECTIONS/FROZEN header. NOT ESTABLISHED: the binding constraint is the 55-cluster ceiling with 84.1% of rows in ten positions, which NO LHS transformation can touch. Every headline figure recomputed independently in Python. Suite 215/0 throughout. Commits eec8890, ebc92fb, cda0a15, 2bed390.
Plan (10-09): THE POSITION-EPOCH PANEL, RESTORED (CTX-PANEL2). `panel-epoch.csv` = **6,760 rows, one per (tokenId, HOURLY epoch)** over 55 tokenIds and 1,887 epochs — the spec §1 unit Phase 9 could not construct, on the grid 10-01's re-scope selected. **UNMATCHED_EPOCHS 0** (every panel epoch present in the variance series), **TELESCOPE_MISMATCHES 0** and **PANEL_SUM_MISMATCHES 0** — each of the 55 tokenIds' rows sum to its gate-validated `recon_wei` EXACTLY in Integer wei, so 10-08's GATE: PASS TRANSFERS to the panel rather than being asserted of it. MULTI_EPOCH_TOKENIDS 52/55 (within-position epochs median 10, max 1176) — the within-position regressor variation Phase 9 had exactly ZERO of. LEG_READ_HOLES 0. GAIN_FACTOR 110.8x over the 61-spell baseline. THREE CORRECTIONS THE PLAN TEXT DID NOT ANTICIPATE, each forced by the hourly re-scope or by arithmetic: (1) `telescope` CANNOT hit the plan's demanded TELESCOPE_MISMATCHES 0 — per-interval flooring undershoots the endpoint total by up to N-1 wei for any leg liquidity that is not a multiple of 2^64, and the real ones (e.g. 761,939,137,362) are not; `Panoptic.Premium.decomposePremium` takes increments as differences of the CUMULATIVE premium, exact for ANY L. (2) 10-05 tagged each delta with the ENDING reading's epoch; block-index epoch e is the START of hour e, so that would have regressed hour e's premium on hour e+1's variance — the 09-05 40587-offset trap one grid finer. `premiumObsChain` tags the accrual interval's STARTING epoch; `buildPremiumObs` left byte-identical. (3) The plan says 'Panel.Variance is untouched' and joins `variance.csv`, but that file is DAILY (keys ~20536) while the accumulators are HOURLY (keys ~492876) — the join would have matched nothing. Width-parameterized estimators (`*At`) + a NEW `variance-hourly.csv` (2,833 epochs, rebuilt from the cached 632,315 ticks with NO refetch); daily `variance.csv` byte-unchanged. `Panel.Epoch` created as a LEAF to break a real cycle (Panel.Build -> Panoptic.Chunk -> Chain.BlockIndex -> Panel.Build, existing only to borrow the grid); `dailyEpoch` byte-identical where 09-04 put it. `epoch-panel` is a SEPARATE subcommand, NOT a `build-panel` flag: `build-panel` rewrites `panel.csv`, THE frozen gate population the telescoping check is defined against, and the subgraph has advanced since the gate. ONE QUIET HOUR (epoch 495112) saw zero swaps between neighbours carrying 700+; a bounded re-fetch of blocks 47,805,127..47,814,126 reproduced the tick cache BYTE-IDENTICALLY (git diff empty), so it was still on chain, not missed — carried as sigma^2 = 0 (a measured zero), pool tick carried forward (a state variable), n_swaps = 0 so its 3 rows stay isolable. Honest limitation: the confirming re-fetch used the SAME public endpoint, so it shows reproducibility, not provider-independence. PROVENANCE HARDENING (user-adopted from 10-08's carry-forward): `burn-truth.csv` freezes the 61-spell OptionBurn ground truth as a committed INPUT — unit determined by the gate's OWN classifier (RawWei), BigInt->Double->Integer round-trip verified EXACT (max 1.76e13, three orders below 2^53), TRUTH_MISMATCHES 0 against reconcile-errors.csv. This closes the one limitation 10-08's anti-fabrication review recorded and could not close. ROW COUNT RECONCILED TERM BY TERM against the 10-01 projection: 6764 +3 (hour 495112, excluded by the census as non-estimable, now measured) -1 (hour 492875, the tick cache's partial leading hour with no boundary block in the 10-03 index) = 6766 SPELL_EPOCH_ROWS, -6 (tokenId,epoch) collisions among duplicate-tokenId spell pairs = 6760. NOT ESTABLISHED: the row count is NOT the precision — clusters stay at 55 and TOP10_TOKENID_ROW_SHARE is 0.841, so the clustered CI will not contract like 1/sqrt(6760). FLAGGED_ROWS 6760 is every row because all 8,910 reads passed a real atTick (universal `Extrapolated`); the informative flag is `ChunkEmpty` on 50 rows, and `AccFrozen` on none. Self-check recomputed every headline figure from the committed artifacts in exact integer Python. Suite 176->215/0. Commits 7aaff51, a2c1f04, 4645257, 56034ad, 4afad77.
Plan (10-08): THE HARD GATE (CTX-GATE). Ran `reconcile` over all 61 spells, both strata, no selection flags, in Integer ETH wei. **GATE: PASS** — MEDIAN_REL_ERROR_SHORT 0.000000 (the verdict stratum), MEDIAN_REL_ERROR_LONG 0.000000, P90_SHORT 1.220169e-9, MAX_REL_ERROR_SHORT 5.447268e-4, SIGNED_BIAS_SHORT 3/5, LEGCOUNT_MISMATCHES 0, ZERO_TRUTH_EXCLUDED 0, LABEL_DISAGREEMENTS 0, CENSUS_MISMATCHES 0, GATE_TOLERANCE 0.01. **53 of 61 spells reproduce OptionBurn.premium0 EXACTLY, to the wei.** `gateTolerance` was NOT modified — `git diff` on Panel/Reconcile.hs is empty across 63a3fa2~1..HEAD; every CLI gap was fixed in app/Main.hs precisely to keep that a one-line audit. LONG STRATUM: 8/8 EXACT (SIGNED_BIAS_LONG 0/0) — the expected `_getAvailablePremium` settlement-cap wedge DID NOT BIND on any spell in this sample; reported, not assumed, and still excluded from the pass/fail arithmetic. THE 8 IMPERFECT SPELLS DIAGNOSED, both 10-07 suspects REFUTED before publication: multi-leg summation refuted (4 of 7 two-leg spells exact; third-worst is single-leg — leg count is exposure, not mechanism), mid-spell s_options rewrite refuted (all 8 have exactly ONE mint, ONE burn, identical positionSize at both ends — no intermediate touch existed). TRUE MECHANISM: an END-OF-BLOCK vs AT-TRANSACTION eth_call read wedge — eth_call resolves state at end-of-block while _getPremia evaluated the accumulator at its tx position inside that block. Four evidence lines: every residual is sub-block (7 of 8 below one block's average accrual; the 72x case is 0.29 blocks once the 250x post-burn liquidity collapse is applied, since the accumulator is per-unit-liquidity); signs obey the live-chunk rule without exception (the ONE spell with a chunk alive+in-range at its burn block is the ONE positive wedge of any size); 8/61 = 13.1% matches the 0.124 swaps/block arrival rate (~12% predicted); scaling-signature clean and sign split two-sided, and no multiplier bug can produce 53 exact reconstructions. IRREDUCIBLE at eth_call granularity (burnBlock-1 relocates the same error with opposite sign); removing it needs transaction-level replay — a different data route, not a fix. Bounded at 5.447268e-4 = 18x inside tolerance, median unmoved. ARTIFACTS: reconcile.md (lineage incl. git commit + exact argv + SFPM + VEGOID + block range, verbatim stdout verdict block, both stratum tables, all 61 per-spell rows, worst-5 + authored wedge attribution) and reconcile-errors.csv (61 rows, rel_error NA never 0 on zero truth). ANTI-FABRICATION REVIEW GATE (user-mandated, before close-out): Reviewer A live provenance CLEAN (8 rows re-read vs Base archive, 32/32 integers exact; CLI re-run byte-identical; 3 subgraph truths match); Reviewer B offline forensics CLEAN (all 61 recon_wei reproduced exactly in independent Python; stats recompute exactly; no planted literals). Recorded limitation: truth_wei materialises only in reconcile-errors.csv, mitigations documented in the read lineage. Suite 176/0. Commits 63a3fa2, 9ad94b2.
Plan (10-07): RECONCILIATION MACHINERY + PRE-CHECK (CTX-GATE). `Panel.Reconcile` rebuilds each spell's premium from the EXACT mint-block and burn-block accumulator readings (the rrEndpoint rows 10-06 wrote — never the nearest epoch boundary, a named RESEARCH wedge), gross accumulator for short legs / owed for long, `premiumWei accBurn accMint (lcLiquidity lc) (lcIsLong lc)` summed over legs. EVERYTHING is Integer ETH wei; the first Double in the path is srRelError; an acceptance grep forbids any price-unit string in the module. gateTolerance = 0.01 is ONE named top-level constant referenced by the CLI, the report and the spec, and it was NOT touched during the run (git diff on Reconcile.hs across the task-2 commit is empty). `reportOf` is the SINGLE verdict rule so the spec and the CLI cannot disagree about what passing means: PASS = short-stratum median <= gateTolerance AND zero leg-count mismatches. STRATIFICATION IS STRUCTURAL — stratify returns two independent ErrorDists and the long stratum is reported in full but EXCLUDED from the pass/fail arithmetic (_getAvailablePremium L588-599 caps SETTLED long premium while the accumulator reports ACCRUED, so a long wedge is protocol behaviour, not a defect); the two are never pooled. Leg-count mismatch (srLegCount vs srLegCountTruth) FAILS the gate — a like-for-unlike comparison that happens to be close is worse than one that is loudly wrong (Pitfall 7). errorDist reports median/p25/p75/p90/max + over/under-reconstruction sign counts (the multiplier-vs-rounding diagnostic) + zero-truth exclusions, NaN on empty (never a 0 that reads as a perfect gate). GROUND-TRUTH UNIT MEASURED NOT ASSUMED: OptionBurn.premium0 is ALREADY raw 18-decimal units (median magnitude ~1e11-1e12), so truthWei = round(premium0) with NO 1e18 factor — corroborated by Panel.Build.premiumUsd dividing by 1e18. `reconcile` CLI (NOT a suite case: 10-VALIDATION keeps hspec offline) with --only-short/--max-legs/--limit selection, panel.csv as THE gate population + is_long authority (LABEL_DISAGREEMENTS 0) and chunk-legs.csv as a chunk-range cross-check (CENSUS_MISMATCHES 0); exits NON-ZERO on GATE: FAIL. PRE-CHECK RESULT (5 short single-leg spells): MEDIAN_REL_ERROR_SHORT 0.0 — three spells reconcile EXACTLY to the wei — max 2.18e-9, SIGNED_BIAS_SHORT 0/2 (both under by -286 and -239 wei on ~1e11 wei premia: the integer-div flooring wedge RESEARCH sized at <1 wei/leg/touch, one-signed as rounding must be, NOT a multiplier bug), scaling-signature check clean (no |recon|/|truth| within 1% of 2^64/2^128/1e12/1e18), LEGCOUNT_MISMATCHES 0, GATE PASS. The telescoping decomposition is CONFIRMED before the 61-spell gate is spent. Suite 156->176/0 (+20 offline ReconcileSpec). Commits a2ad4b6, c7c1bfc.
Plan (10-06): BULK ACCUMULATOR READ (CTX-PREM). premium-accumulators.csv materialised at 8,910/8,910 scheduled reads across a 6-cycle resume chain surviving two session limits and one dual-RPC rate-limit exhaustion, zero data loss; 0 duplicate keys, ACC_FROZEN_ROWS 0, CHUNK_EMPTY_ROWS 44 (pre-mint, flagged not errored), blocks 43,781,657..48,157,721 covering every spell window; 130 exact-block mint/burn endpoint rows are what 10-07's gate reads. Commits d2a5086, 15dbff5, efc0a62.
Plan (10-05): SFPM PREMIUM READ (CTX-PREM, CTX-GATE). `Panoptic.Sfpm` = the getAccountPremium call: poolKeyBytes (160B abi.encode(PoolKey)) proven byte-for-byte by keccak256(poolKeyBytes)==known poolId 96d4b53a..288c0a; getAccountPremiumCalldata derives the selector from the signature (never hardcoded), lays out 8 head slots with the DYNAMIC bytes poolKey head carrying the 0x100 offset (data in the tail), total 452B; atTick=Nothing encodes the 8388607 stored-value sentinel; decodeAccountPremium is LENGTH-DEFENSIVE (>=64B two right-aligned uint128 words / >=32B single LeftRight-packed word), currency0 in the RIGHT slot, fail-loud (< 32B => Left, never a decoded zero); getAccountLiquidity/decodeAccountLiquidity implemented (NOT deferred) to disambiguate netLiquidity==0 (RESEARCH Pitfall 5). `Panoptic.Premium` = accumulator diffs -> per-leg/epoch premium wei: accDelta=diffMod 128 (unchecked uint128 wraparound, never signed sub), premiumWei applies the X64 (2^64) scale — NOT X128/X96 — with long-leg negation (_getPremia L2296-2298); telescope asserts the EXACT integer decomposition (Sigma per-epoch == endpoint, exact when L is a multiple of 2^64) — the identity the gate rests on; PremiumFlag ChunkEmpty (netLiq==0) / AccFrozen (isFrozenAcc, within 1% of 2^128-1 cap) / Extrapolated (real atTick) carried through so a zero delta is never ambiguous; multiplierWedge = nu=1/8 Rational (1 at R=0, <=1.125 long) for the 10-11 cross-walk, reported not applied; buildPremiumObs fans pool-wide chunk deltas to per-leg/epoch obs via lcLiquidity (poTokenId attached by the 10-06 driver). Offline against premium-acc-golden.json + synthetic chains; suite 117->147/0 (+12 Sfpm, +18 Premium). Commits 6360ffd, 56e0f49.
Plan (10-04): CHUNK GEOMETRY + READ SCHEDULE (CTX-PANEL2). `Panoptic.Chunk` turns a subgraph `Leg` into its exact `(tokenType, tickLower, tickUpper)` chunk identity and `Integer` liquidity multiplier. getTicks/getRangesFromStrike mirror PanopticMath.getTicks (floor-down/ceil-up asymmetric for odd width*tickSpacing) and DELEGATE to the single arithmetic source `Panel.Subgraph.legChunkKey` (a literal move up forms an import cycle — Panoptic.Chunk depends on Panel.Subgraph for Leg/Chunk), re-exporting it. crossCheckChunks validates getTicks against the subgraph's OWN Chunk records (the authority) on frozen chunks-sample.json: 126/126 match, mismatch list empty. getSqrtRatioAtTick = exact Uniswap TickMath X96 bit-decomposition in Integer (2^96 at tick 0, strictly monotone) — NO Double 53-bit approximation. getLiquidityForAmount0/1 floor-division Integer (FullMath.mulDiv); legLiquidity selects the token side via the NEW Leg.legAsset field (parsed optionally, tokenType default for asset-less fixtures) — never guessed; NO Double in any signature. resolveLegChunks drops width==0 legs at one explicit greppable point (PanopticPool._getPremia L2250), preserving original leg index. READ SCHEDULE: buildReadSchedule emits interior epoch-boundary reads for every epoch whose boundary block lies in a spell's [meBlock,beBlock] (atTick from per-epoch tick index) + exact-block mint/burn endpoint rows (rrEndpoint=Just mint|burn) so the gate reads at the spell endpoints; deduplicated on the pool-wide (chunkKey,block,isLong,atTick); readScheduleRaw keeps the full tokenId/leg fan-out for 10-05; storedValueTick=8388607 (type(int24).max). DISTINCT_READS materialised at 10-06 against the HOURLY ~30k-60k / ~70-140 min envelope (52 distinct chunks bound per-epoch reads), NOT the 15k daily figure. Suite 102->117/0 (+15 offline ChunkSpec). Commits 0b0d397, 628d674.
Plan (10-03): EPOCH<->BLOCK INDEX + RPC PROBE (CTX-PANEL2, CTX-FEE). `Chain.BlockIndex` maps each HOURLY epoch boundary to the FIRST Base block with ts >= epoch*3600, by interpolation-assisted, postcondition-asserted (ts(b)>=target>ts(b-1)) monotone search over Chain.Rpc.ethGetBlockByNumber — NO 2s-block assumption (offline spec drives the real algorithm against an irregular 1s/4s-gap oracle). Imports Panel.Build.epochOfSeconds as the SINGLE epoch rule (boundary instant = epoch*epochSeconds), never re-derived; a factored pure `stepSearch` core is shared by pure `bisectFirstAtOrAfter` and live `findBlockAtOrAfterWith` so they cannot diverge. Streaming + RESUMABLE: appendBlockIndexRow per row, skips epochs already in CSV. HOURLY RE-SCOPE (from 10-01): built over the 2832 IN-WINDOW hourly boundaries (492876..495707), NOT the 119 daily epochs the plan text assumed — derived by intersecting the block-window timestamps with the hourly grid, cross-checked against variance.csv's daily range (20536..20654). block-index CLI subcommand (build + --probe N). LIVE BUILD: epoch-blocks.csv = 2832 monotone rows, blocks 43,782,127..48,877,927, round-trip floor(ts/3600)==epoch on every row, 5,666 eth_getBlockByNumber calls (2.0/epoch). RPC PROBE (RESEARCH Open Q3 ANSWERED): 200/200 OK, 0 err, 0 429, 7.24 calls/s -> rpc-throughput-probe.md; 10-06 must budget the HOURLY bulk read (~70-140 min for ~30k-60k calls), NOT the RESEARCH 15k daily figure. Added `directory` (test dep). Suite 89->102/0 (+13 BlockIndex). Commits a8aebeb, b73faff.
Plan (10-02): CHAIN-ACCESS SUBSTRATE (CTX-FEE). Built `Chain.Abi` (the SINGLE ABI/word-arithmetic module) and `Chain.Rpc` (the SINGLE JSON-RPC transport), both fully tested OFFLINE. Chain.Abi: decodeWordAt (RAW returndata, two's-complement sign extension), encodeWord/encodeUint256/encodeInt24/encodeAddress/encodeBytesDynamic, decodeUint128Pair (right slot = currency0 ETH), diffMod (unchecked mod 2^n, always non-negative), feeGrowthInside (Pool.sol L488-511 three-branch identity, asymmetric >= / < boundary), keccak256Hex/selector via crypton Keccak_256 (NOT SHA3-256 — proven by the known Transfer/empty/Swap topic vectors). Chain.Rpc: RpcEnv/defaultBaseEnv(mainnet.base.org)/drpcFailoverEnv(base.drpc.org), generic rpcPost with the retry/backoff loop LIFTED VERBATIM from Panel.Variance, ethCall/ethGetBlockByNumber/ethBlockNumber, BlockTag/blockTagHex, decodeCallResult — all FAIL LOUD (empty 0x returndata / missing result / JSON-RPC error -> Left, never a decoded zero). Panel.Variance refactored to import both (wordAt + its forked httpLBS/retry code DELETED; getLogsChunk + currentHeadBlock now call the lifted transport) with its public API unchanged (Panel.VarianceSpec green). Frozen test/fixtures/premium-acc-golden.json (blocks 44.5M/47M/latest gross+owed) reproduces the three RESEARCH probe invariants — monotone in block height, owed>gross, atTick>stored — with ZERO network. Rule-1 fix: plan literal blockTagHex 44500000==0x2a76d80 was arithmetically wrong (correct 0x2a70420). Added crypton+memory (lib) and aeson (test) deps. Suite 62->89/0 (+27: 19 Abi, 4 Rpc, 4 premium-golden). Commits 8849e9b, 3feec71.
Plan (10-01): WAVE-0 PANEL-SIZE BLOCKER — resolved. Converted the phase's load-bearing width==0 assumption into a MEASUREMENT: `PanopticPool._getPremia` (L2250) skips every width==0 leg, but the census found 68/68 spell-legs carry width/=0 across all 61 spells / 55 tokenIds — the trap does NOT bind on the accrual population. Added Panel.Subgraph.Chunk (Integer liquidity fields, never Double — BigInt hits 10^20+) + fetchChunks + legChunkKey (asymmetric floor-down/ceil-up getTicks), which reproduce the protocol's own Chunk ranges EXACTLY (GETTICKS_MATCH_RATE = 1.0 on all 68). sample-size CLI census with a PARAMETERIZED epoch width (EPOCH_HOURS) alongside the untouched Panel.Build.dailyEpoch. TWO-ROUND VERDICT: the daily grid returned a pre-committed STOP (within-position median 1 epoch/position vs floor 5) and it was HONORED — daily design closed. USER then re-scoped to HOURLY epochs BEFORE any estimation (thresholds untouched); hourly re-measurement returns GO on both conditions: JOINABLE_ROWS=6764, WITHIN_POSITION_EPOCHS_MEDIAN=10, sigma^2 estimable 2832/2832 hrs, GAIN_FACTOR ~111x, cluster count unchanged at 55. USER DECISION: PROCEED to Wave 2 on the hourly design, accepting two recorded residual risks — (a) 55-cluster ceiling bounds clustered precision regardless of rows; (b) hourly sigma^2 noisier (~177 vs ~5209 incr/window), worsening EIV attenuation and thinning the even-swap instrument (~88 incr) — both adjudicated empirically by the UNCHANGED <=1% reconciliation gate and <=6.2e-5 stopping rule in 10-10. DOWNSTREAM CONSEQUENCE: the panel and variance layers are now HOURLY (an hourly epoch fn exists alongside dailyEpoch, which is untouched) — 10-03 epoch<->block, 10-05/10-06 read schedule (~2832 epochs), and 10-09 panel join all consume hourly epochs; 10-04 MUST re-estimate bulk-read call volume vs the RESEARCH 8k-15k daily-sized figure. Commits efbac82, d6c2a3c, 63270d4, a02df36, 7dcf998.
Plan (09-09): CTX-ALT + THE LIVE RUN. Alternatives.hs = the four LOCKED spec §6.2 alternatives (semiparametric degree-0 B-spline vega profile on moneyness quantile knots; seed tick-linearization centered at ī; tokenId-FE within estimator with κ concentrated over a grid; collateral channel) — each reports estIdentified=False WITH A REASON rather than a meaningless number. SCHEMA CORRECTION (Rule 1+3, forced): 09-04's Panel.Subgraph/Panel.Build queried a schema that does not exist — TokenId has no `snapshots`, `premiumSettleds` is EMPTY, premiaSettled*Total is IDENTICALLY ZERO market-wide, and Leg.strike is already an int24 TICK (the round(log K/log 1.0001) map produced NaN on negative strikes). Unit of observation therefore forced to the ACCRUAL SPELL (mint→burn, π = USD/day, σ̂² averaged over the spell window); spreading premium across days REJECTED as manufacturing a mechanical null. LIVE DATA: 632,315 V4 Swap logs (blocks 43,781,657..48,879,461, 510 chunked calls) → 119 daily epochs; 1447 mints + 1432 burns + 768 tokenIds → 61 accrual spells / 55 tokenIds / 4 accounts (34 above the money, 27 below). NLS BUG FIXED: κ enters as exp(−κ·d) with d in TICKS (median 153), so the fixed start κ=0.2 gives exp(−0.2·153)≈5e−14 — numerically dead, Jacobian vanishes, and the first live run reported a SPURIOUS κ=0.384; Model.NLS now multi-starts from data-scaled values and keeps the lowest SSE (regression test at live tick scale added). RESULT = NULL: υ̂₀=2.27e−9 (clustered SE 1.26e−4) is numerically ZERO ⇒ κ STRUCTURALLY UNIDENTIFIED (SE 18.8) and the κ>0 test is VACUOUS (not fails-to-reject); best fit is a constant β̂₀=2.36e−4 USD/day (SE 8.8e−5). Formal witness of exp_family_witnesses_ATMOTM does NOT obtain — the Lean theorem stays proved/axiom-clean and the conjecture stays OPEN; this cross-section carries no information about it. Alternatives: semiparametric NOT INTERPRETABLE (non-monotone, SE-dominated), seed-linear γ=+5.5e−4 (OPPOSITE sign to κ>0), position-FE NOT IDENTIFIED (11 obs / 5 multi-spell tokenIds, boundary minimizer ⇒ selection threat UNRESOLVED), collateral estimated but on DEPOSITED collateral not required Q_M. Self-describing analysis output + estimation-panel.csv (61 rows) exported for 09-10. Suite 59/0; lake build vol_markets exit 0 (commits e32e179, dab55c7, b8b49aa, c9f16c1, bb15a96).
Plan (09-08): Model.SandwichSE.clusterSandwich = hand-rolled tokenId-clustered CR0 sandwich (bread·meat·bread, bread=(JᵀJ)⁻¹, meat=Σ_g s_g s_gᵀ) — reproduces the frozen 09-01 golden V/SE to 1e-9 and collapses to HC0 under singleton clusters; pure CR0 (no finite-sample correction) with clusterCR1Factor exposed. Tests.Specification = the three committed §5 tests: testUpsilonPos/testKappaPos one-sided Normal on the clustered covariance (κ>0 = THE null test H₀:κ=0), testSymmetry χ²₁ Wald on the 2×2 κ⁺/κ⁻ sub-block; excluded restrictions absent; p-values from statistics. estimate CLI wires clustered SEs + all three tests (split-model Wald fit inline in Main). Full suite 40/0 (commits 416e9b2, 4f7085e).
Plan (09-07): estimator core (CTX-EST) — Model.Upsilon mirrors Lean upsilon/PosSpec.lam byte-for-byte (model = b0+u0·exp(−k·d)·s2, moneyness |iK−it|, tickBase 1.0001, modelSplit κ⁺/κ⁻); Model.NLS.fitGSL = hmatrix-gsl Numeric.GSL.Fitting Levenberg-Marquardt PRIMARY (analytic Jacobian + covariance handle for 09-08 SEs), fitAD = ad Gauss-Newton/LM cross-check (both recover planted params 1e-2, agree 1e-3); Model.EIV.ivFit = two-step two-noisy-measures IV (κ̂ from NLS, then (ZᵀX)⁻¹Zᵀy instrumenting σ̂² with σ̃², reduces attenuation); estimate CLI joins panel.csv⋈variance.csv; lean-haskell-crosswalk.md is the witness fidelity table. Full suite 31/0 (commits af84dc1, 2de090a).
Plan (09-06): exp_family_witnesses_ATMOTM proved by single serial Aristotle task (new project f9865d3a, task 84b02173, server commit 7ccd814) AS STATED (Option-B slope-centered envelope, not weakened); integrated sorry-free into lean/vol_markets/Upsilon.lean. lake build vol_markets exit 0 (8032 jobs), zero sorries; #print axioms = [propext, Classical.choice, Quot.sound] on the bridging lemma and all re-checked Phase-8/upsilon theorems. κ̂>0 now formally witnesses ATMOTMNullHypothesis (commit c087ec8).
Plan (09-05): variance regressor σ̂²_t + EIV instrument σ̃²_t built (CTX-VAR) — Panel.Variance ingests Base V4 Swap logs via chunked eth_getLogs RPC (USER-DIRECTED OVERRIDE; BigQuery dropped, project suspended), decodes int24 tick/uint160 sqrtPriceX96 from log data; realizedVariance = within-day RV of tick log-price increments, instrument = disjoint even-swap sub-window (two-noisy-measures IV); reuses Panel.Build.dailyEpoch (unix-day index) so variance.csv joins panel.csv. Live proof: 2136 real swaps, blocks 48768127..48775327, 2 epochs (20651/20652) → notes/.../variance.csv + swap-ticks cache. Full suite 18/0.
Status: **PHASE 11 WAVE 2 IS IN FLIGHT — THE QUEUE IS BUSY.** Bundle B was submitted as the single Aristotle task (project `19f777ab`, task `f8840dab`) carrying T20–T30: the degeneracy, the constrained/Jensen program, and the Angstrom bridge. Nothing is proven yet; integration is 11-05's job and is BLOCKED until the task is terminal. **The two-reviewer gate paid for itself twice this plan.** It caught a BLOCKER that the PLAN ITSELF had introduced — `mevTotal` defined as `probOr` of two unbounded hazards, which approved block M7 explicitly forbids and which would have compiled green, passed the axiom sweep and passed 11-05's fidelity diff while being wrong for every nonzero sandwich. Both reviewers, running blind to each other, found it independently; the already-proven `probOr_hazard` was the decisive evidence. Separately, and before either reviewer ran, the plan's T25 was found to be a vacuous triviality at the schedule level — the document's own OPEN note — and was restated at the path level. **Watch T24 on return: an OPEN T24 alongside a delivered T25 is an acceptable, recordable outcome and must not be written up as success.** What follows is the prior wave's status, retained verbatim.

Superseded status (Wave 1) — **PHASE 11 WAVE 1 LANDED.** Aristotle task `d1c57297` reached COMPLETE and 11-03 integrated it: `lean/vol_markets/MevOptimization.lean` — 1046 lines, 25 declarations, sorry-free, 25/25 axiom-clean, registered in the lakefile roots, `lake build` green on all three libs, and mirrored to origin and `cfmm-lean4-spec` main. All ten submitted dependency modules came back BYTE-IDENTICAL. Every one of T1–T18 is present and NONE is narrowed — T6 came back strictly convex, T13's bound is a path SUM, T8 kept its `·Δt`, and T17 proves `ContinuousOn` instead of assuming it. The finding: Aristotle had to ADD `0 ≤ φbarMax + uMax·αmax0` to T15 because the saturation limit as specified was FALSE at `ptrade`'s negative-fee pole — the SAME pole the 11-02 reviewers used to demolish T17, live in a second place the gate did not reach. Optional T19 was omitted, so block M3(ii)'s exact CPMM kernel has no formal carrier. THE SERIAL QUEUE IS NOW FREE: 11-04 (bundle B) is unblocked. What follows is the prior wave's status, retained verbatim.

Superseded status (Wave 10) — Phase 10 Wave 10 COMPLETE: **the estimation question is answered and CLOSED.** The pre-committed, result-blind stopping rule was applied to the gate-validated position-epoch panel and FAILED — then failed AGAIN after the one construction defect with an unambiguously signed effect on it was found, escalated to the user, locked, and fixed. **This market cannot identify upsilon**, and because the verdict survives both LHS constructions that conclusion is about the MARKET rather than about the measurement — which is the thing Phase 9's ambiguous null could not distinguish. The estimator was byte-unchanged throughout (empty diff over src/Model, src/Tests, Alternatives.hs), the 6.2e-5 bar was never moved despite its discovered unit incoherence, and run 1's analysis is frozen and unedited beside run 2's. Genuinely new and reported without over-reading: **kappa > 0 rejects H0 of a flat vega profile under BOTH constructions** (p 9.5e-3, 7.3e-3) with the now-identified position-FE diagnostic concurring — a statement about the profile's SHAPE, not a substitute for the rule, which is about upsilon0's LEVEL. The formal Lean witness does NOT obtain (hu satisfied in sign only); the theorem stays proved and axiom-clean and the conjecture stays OPEN. NO further estimation iteration will run: run 2 is terminal by the pivot lock and the user's commitment. Next: 10-11 (cross-walk + lineage close-out) — carry the MEASURED wedge figures (median 1.1125, long max 1.2917, implied max R/N 2.33), NOT the false 1.125 bound.
Superseded status (Wave 7) — 10-06 materialised the 8,910-row accumulator dataset and 10-07 built the gate machinery (`Panel.Reconcile` + the `reconcile` CLI) and ran the prescribed 5-spell PRE-CHECK: median relative error 0.0 in ETH wei, three of five spells exact to the wei, worst 2.18e-9, one-signed flooring residual only, scaling-signature check clean, GATE PASS. The telescoping decomposition is confirmed — the reconstructed panel really is a decomposition of `OptionBurn.premium0`, not an independent estimate. Ground-truth unit MEASURED (premium0 is already raw 18-decimal units; no 1e18 factor). Next: 10-08 runs the FULL 61-spell hard gate as a CHECKPOINT — same CLI, no selection flags, `gateTolerance` stays 0.01; read the two strata separately (the short stratum is the verdict; the 8 long spells carry the expected `_getAvailablePremium` settlement-cap wedge and are reported, not pooled). Any short-stratum spell materially above the ~1e-9 flooring floor is a multi-leg summation or a mid-spell `s_options` rewrite — the two wedges the single-leg pre-check could not exercise. Residual risks (55-cluster ceiling; noisier hourly sigma^2 / thinner even-swap instrument) adjudicated at the 10-10 stopping rule.
Last activity: 2026-07-30 — 11-03 COMPLETE. Aristotle bundle A LANDED: `lean/vol_markets/MevOptimization.lean` (1046 lines, 3 defs + 22 public theorems + 3 private helpers), sorry-free, 25/25 `#print axioms` = [propext, Classical.choice, Quot.sound], root registered, `lake build` 8062 jobs exit 0. 10/10 bundled modules byte-identical. T1–T18 all present, none narrowed; T19 OMITTED (optional). Aristotle-added hypotheses recorded, incl. the NECESSARY T15 fee-nonnegativity guard. Pushed to origin (42c8e60) and cfmm-lean4-spec main (19afcdd). Commits 5dd94e9, 42c8e60. Queue FREE for 11-04.

Progress: [█████████░] 86%

### develop segment 3 of 5

| Phase 01 P01 | 11 | 3 tasks | 14 files |
| Phase 08 P01 | 12 | 2 tasks | 8 files |
| Phase 08 P02 | 4 | 2 tasks | 2 files |
| Phase 09 P03 | 2 | 2 tasks | 1 files |
| Phase 09 P01 | 9 | 2 tasks | 8 files |
| Phase 09 P02 | 6 | 3 tasks | 1 files |
| Phase 09 P04 | 6 | 2 tasks | 8 files |
| Phase 09 P05 | 28 | 2 tasks | 8 files |
| Phase 09 P06 | 30 | 2 tasks | 1 files |
| Phase 09 P07 | 9 | 2 tasks | 9 files |
| Phase 09 P08 | 8 | 2 tasks | 7 files |
| Phase 09 P09 | 195 | 2 tasks | 16 files |
| Phase 10 P01 | 1440 | 4 tasks | 8 files |
| Phase 10 P02 | 60 | 2 tasks | 8 files |
| Phase 10 P03 | 28 | 2 tasks | 7 files |
| Phase 10 P04 | 9 | 2 tasks | 5 files |
| Phase 10 P05 | 9 | 2 tasks | 6 files |
| Phase 10 P07 | 95 | 2 tasks | 7 files |
| Phase 10 P08 | 60 | 2 tasks | 5 files |
| Phase 10 P09 | ~3h | 5 tasks | 14 files |
| Phase 10 P10 | 240 | 4 tasks | 5 files |
| Phase 10 P11 | 35 | 2 tasks | 4 files |
| Phase 11 P01 | 120 | 3 tasks | 6 files |
| Phase 11 P02 | 45 | 3 tasks | 5 files |
| Phase 11 P03 | 35 | 2 tasks | 6 files |
| Phase 11 P04 | 75 | 3 tasks | 5 files |
| Phase 11 P05 | ~35 min | 2 tasks | 6 files |
| Phase 11 P06 | 34 min | 2 tasks | 5 files |
| Phase 12 P01 | 4h | 3 tasks | 6 files |
| Phase 12 P02 | ~3h | 3 tasks | 4 files |
| Phase 12 P04 | 11 min | 3 tasks | 6 files |

### develop segment 4 of 5

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Plumbing-first scope: prove the connection layer carries parameters correctly with a stub GAMS solver; real optimization model + replication proof + LDF conformance are v2.
- Phase order fixed: Plank bridge-surface is implemented AND compiled (Phase 4) BEFORE the bridge wiring (Phase 6) — resolves the prior phase-order inversion BLOCKER.
- Phases 1 and 2 are serialized (no parallelism) to avoid the repo-identity race during the public flip / fork migration.
- Theory grounding links to cfmm-theory `KERNEL.md` by URL/citekey (no submodule); refs under `spec/protocol/refs/`.
- [Phase 11]: 11-01: the three MMR notation collisions resolved as γ→φ, λ→Δt, η never named — enforced by an executable grep gate (`mev-notation-gate.sh`) with a bounded header/M0 whitelist marker, not by convention; the gate caught three genuine violations during authoring and was never weakened
- [Phase 11]: 11-01: λ_ARB (the arbitrage channel; ASCII `lambda_ARB`) and λ_MEV (the total, λ_ARB ⊕ λ_sandwich; ASCII `lambda_MEV`) are DISTINCT symbols and are never interchangeable; the infimum program is on λ_ARB, and the two coincide only under M7's uniform-batch-clearing reduction. λ_ARB ABSORBS the "arb toxicity" hazard-index entry — carrying both would double-count
- [Phase 11]: 11-01: the doc states the DEGENERACY (M6a) and the CONSTRAINED result (M6b) as two separate, well-posed claims rather than one arg-set equality — the phase brief's "the shape block (β, γ) becomes essential" expectation is refuted unconstrained, and the doc says so in those words
- [Phase 11]: 11-02/11-04: two SERIAL Aristotle bundles (mirror content first, novel content second) rather than one — so a weakened or corrected return from bundle A could revise bundle B's premises before they were spent. It paid: bundle A's T15 came back FALSE-as-specified, and that pole informed bundle B's drafting
- [Phase 11]: 11-05: the volatility-varying Jensen statement (T24) verdict is **REFUTED** — `mev_ge_flat_under_flair_budget_false`, Aristotle's outcome 3, machine-checked and axiom-clean; witness recomputed independently in exact rationals (flat 31/22 ≈ 1.4091 vs tilted 4/3 ≈ 1.3333). The Θ_φ-restricted isotone case stays OPEN and is claimed neither way; the supporting float numerics are labelled NOT machine-checked
- [Phase 11]: `arb_add_fee_eq_lvr` is a **bridge identity** — the ring tautology x·p + x·(1−p) = x — and NOT a formalization of MMR Theorem 3/4; those asymptotics are quoted in block M2 and remain unformalized, and the traceability row says so on its own line so nobody downstream can cite it otherwise
- [Phase 11]: the Angstrom tax stays PARAMETRIC in τ = k/(k+1) with k free; the l2-angstrom repo snapshot and the live docs disagree on the constants, so no numeric enters a theorem — the dated k = 49 / τ = 0.98 instance lives only in prose
- [Phase 11]: 11-06: doc-over-plan again at close — where the plan's mechanical criteria contradicted the artifacts (an identifier loop reaching into §8's pre-existing `joint_candidates_disagree`, a `/home/` scan hitting ROADMAP's own quoted scrub command, an assumed `Requirements: TBD` that a prior pass had filled), the criteria were recorded as defective and the semantic requirement verified properly, rather than editing the artifacts to satisfy the regex
- [Phase 01]: 01-01: MIT LICENSE (wvs-finance); orphan-branch squash to one sanitized baseline; GAMS paths relativized to in-repo model/; recovery bundle + backup/pre-squash captured before rewrite
- [Phase 08]: 08-01: negated θ kernel exponent (Gaussian must decay), Demeterfi cited by URL/citekey not vendored PDF, six cfmm-discrete notes vendored under spec/protocol/refs/
- [Phase 08]: 08-02: renamed lattice value binder π→pl (π is reserved Mathlib notation for Real.pi); θ_ATM=kσ/√(8πτ) stated as τ→0⁺ asymptotic with hΘ pinning, sole Aristotle obligation is centralBinom_isEquivalent (sharp central-binomial asymptotic)
- [Phase ?]: User-directed: no hand-proving. Upsilon.lean statements + conjecture drafted locally; one Aristotle submission (project 6bda0e2c-cc54-4663-9a4f-ffeada3bda6f, task 2c102a3e) covers all 4 sorry'd goals; integrate from returned archive.
- [Phase ?]: First submission sat QUEUED with zero events; user chose cancel+resubmit. Same bundle, same 4 goals. Single in-flight task preserved.
- [Phase ?]: Full estimator (hmatrix-gsl LM after user installed GSL 2.8, hand-rolled clustered sandwich SEs, tests, EIV-IV) in Haskell; GAMS replicates only the 3-variable NLS point estimates as a non-blocking differential check, coordinated to the GAMS session (PID 175812) via claude-peers per the ownership map.
- [Phase 09]: 09-03: corrected ATMOTMNullHypothesis conjunct 3 to slope-centered envelope exp(-c·max(i-iK, -(i-iK)-1)) (forward-difference is symmetric about iK-½, so exp(-c|i-iK|) was param-independently false on the left branch); sorry'd exp_family_witnesses_ATMOTM (exp family, c=κ·Δi) pinned for the single Aristotle task 09-06; Option A fallback recorded
- [Phase 09]: 09-01: pinned econometrics/ to lts-24.50 (GHC 9.10.3 = system GHC, no download) + hmatrix-gsl-0.19.0.1 extra-dep (Numeric.GSL.Fitting = primary NLS LM); stack build/test green, system GSL 2.8 linked
- [Phase 09]: 09-01: froze CR0 sandwich-SE golden fixture (orthogonal-J 2-cluster/3-obs toy: V=[[2.25,.75,0],[.75,.25,0],[0,0,2.25]], SE=[1.5,.5,1.5]) with hand arithmetic in-file for 09-08 to implement against
- [Phase 09]: 09-02: data-source gate resolved — accept Base V4 ETH/USDC (chainId 8453, panopticPool 0xb50e...174a, poolId 0x96d4...288c0a) via keyless Goldsky base/dev subgraph; GRAPH_API_KEY not needed (public); variance from direct RPC eth_getLogs on Base V4 Swap logs (V4 topic0 + poolId topic1) — BigQuery dropped (project thetaswap-research suspended, 403 CONSUMER_SUSPENDED); 09-05 consumes RPC logs not BigQuery SQL, 09-04 unaffected except market ids
- [Phase 09]: 09-04: panel π_it = per-epoch DELTA of cumulative premiaSettledInUsdTotal (tag to ENDING epoch, N snapshots→N−1 rows); i_K=round(log strike/log 1.0001) mirrors PosSpec.lam; dailyEpoch=floor(unixSec/86400) 00:00 UTC bucket shared with 09-05 variance window; σ̂² emitted as NaN placeholder for 09-05 join
- [Phase 09]: 09-05: variance built from Base V4 Swap logs via chunked eth_getLogs RPC (BigQuery dropped, project suspended); instrument σ̃²_t = disjoint even-swap sub-window (two-noisy-measures IV); reuse Panel.Build.dailyEpoch (unix-day index) as single source of truth so variance.csv joins panel.csv
- [Phase 09]: 09-06: bridging lemma exp_family_witnesses_ATMOTM proved by single serial Aristotle task (new project f9865d3a, task 84b02173, server commit 7ccd814) AS STATED (Option-B slope-centered envelope); integrated sorry-free + axiom-clean; κ̂>0 now formally witnesses ATMOTMNullHypothesis
- [Phase 09]: 09-07: estimator core (CTX-EST) — hmatrix-gsl fitModel Levenberg-Marquardt is PRIMARY NLS (analytic Jacobian + covariance handle for 09-08 SEs); ad Gauss-Newton/LM retained as synthetic cross-check; both recover planted (β₀,υ₀,κ) within 1e-2
- [Phase 09]: 09-07: EIV ivFit = two-step two-noisy-measures IV — κ̂ from NLS (identified off moneyness), then just-identified IV (ZᵀX)⁻¹Zᵀy instruments σ̂² with σ̃²; reduces υ̂₀ attenuation. Model.Upsilon mirrors Lean upsilon/PosSpec.lam byte-for-byte, backed by lean-haskell-crosswalk.md
- [Phase 09]: 09-08: clusterSandwich = pure CR0 (bread·meat·bread, no finite-sample correction) to match the frozen 09-01 golden to 1e-9; Stata CR1 factor (G/(G−1))·((N−1)/(N−k)) exposed as clusterCR1Factor but not baked in
- [Phase 09]: 09-08: the three committed §5 tests use the CLUSTERED covariance (not naive OLS SEs) — υ₀>0/κ>0 one-sided Normal upper tail (κ>0 is THE null test), κ⁺=κ⁻ χ²₁ Wald on the 2×2 split sub-block; deliberately-excluded J-test/β₀=0 absent; split-model Wald fit inlined in Main (Model.NLS out of files_modified)
- [Phase 09]: 09-09: unit of observation forced to the ACCRUAL SPELL (mint→burn) — the live subgraph has NO per-epoch premium series (TokenId.snapshots absent, premiumSettleds empty, premiaSettled*Total identically zero); spreading spell premium across days rejected as manufacturing a mechanical null. Flagged for the 09-11 audit.
- [Phase 09]: 09-09: Model.NLS multi-starts from data-scaled values — a fixed kappa=0.2 start is numerically dead when moneyness is in ticks (exp(-0.2*153)~5e-14), and produced a spurious kappa=0.384 on the first live run
- [Phase 09]: 09-09: LIVE RESULT is a NULL — upsilon0-hat=2.3e-9 (SE 1.3e-4) is numerically zero, so kappa is STRUCTURALLY UNIDENTIFIED (SE 18.8) and the kappa>0 test is VACUOUS, not fails-to-reject. The exp_family_witnesses_ATMOTM witness does NOT obtain; the Lean conjecture remains open and untouched.
- [Phase ?]: Live Base run produced a structural null (no settled-premia data market-wide; unit of observation forced from position-epoch to accrual spell). User halted rather than spend the audit-econ gate on a spec-departed null.
- [Phase 10]: 10-01: daily-grid Wave-0 census returned STOP (within-position median 1 epoch/position vs floor 5) and it was HONORED; the daily design is closed on its own pre-committed rule.
- [Phase 10]: 10-01: user re-scoped to HOURLY epochs BEFORE any estimation (thresholds untouched); hourly census returns GO (6764 joinable rows, median 10 epochs/position, sigma^2 estimable 2832/2832 hrs). Decision: PROCEED to Wave 2 on the hourly design — panel and variance layers are now HOURLY; an hourly epoch fn exists alongside the untouched Panel.Build.dailyEpoch.
- [Phase 10]: 10-01: two residual risks accepted at PROCEED — (a) 55-cluster ceiling bounds clustered precision regardless of rows; (b) hourly sigma^2 noisier (~177 vs ~5209 incr/window) worsening EIV attenuation and thinning the even-swap instrument (~88 incr). Adjudicated empirically by the UNCHANGED <=1% reconciliation gate and <=6.2e-5 stopping rule in 10-10; getTicks proven exact (match rate 1.0) and width!=0 holds 68/68.
- [Phase 10]: 10-02: Chain.Abi + Chain.Rpc are the single ABI-codec and JSON-RPC transport in the repo (Panel.Variance.wordAt + forked retry loop DELETED, re-sourced by import); sign extension, diffMod wraparound (128/256), the three-branch feeGrowthInside identity, and crypton Keccak-256 (NOT SHA3) are each a named offline spec; frozen premium-acc-golden.json reproduces the RESEARCH probe invariants (monotone, owed>gross, atTick>stored) with zero network. Plan literal blockTagHex 44500000==0x2a76d80 was wrong (correct 0x2a70420, Rule 1). Suite 62->89/0.
- [Phase 10]: 10-03: Chain.BlockIndex maps HOURLY epoch boundaries to Base blocks by interpolation-assisted, postcondition-asserted monotone search over eth_getBlockByNumber (no 2s-block assumption); imports Panel.Build.epochOfSeconds as the single epoch rule, CSV-cached + resumable. Materialised epoch-blocks.csv = 2832 in-window hourly rows (blocks 43,782,127..48,877,927), built in 5,666 calls (2.0/epoch).
- [Phase 10]: 10-03: RESEARCH Open Question 3 ANSWERED — 200-call probe on keyless mainnet.base.org = 7.24 calls/s, 0 errors, 0 429s (corroborated by the 5,666-call build, 0/0). 10-06 must budget the HOURLY bulk read (~2832 boundaries x chunk-legs => ~70-140 min), NOT the RESEARCH 15k daily figure.
- [Phase 10]: 10-04 start: executing read-schedule/chunk-geometry plan
- [Phase 10]: 10-04: Panoptic.Chunk built — getTicks (floor/ceil asymmetric, match rate 1.0 on 126/126 frozen Chunk records via crossCheckChunks, subgraph=authority), getSqrtRatioAtTick (exact TickMath X96 Integer, 2^96 at tick 0, monotone), getLiquidityForAmount0/1 + legLiquidity (asset-selected, Integer floor division), resolveLegChunks (drops width==0 legs, preserves index). Leg gained legAsset (token side selector, defaults to tokenType for asset-less fixtures).
- [Phase 10]: 10-04: canonical tick arithmetic stays in Panel.Subgraph.legChunkKey (leaf module); Panoptic.Chunk.getTicks/getRangesFromStrike DELEGATE + re-export it — a literal move forms an import cycle. buildReadSchedule emits interior epoch-boundary reads (epoch boundary block in spell's [meBlock,beBlock]) + exact-block mint/burn endpoint rows, deduplicated on pool-wide (chunkKey,block,isLong,atTick); storedValueTick=8388607. DISTINCT_READS materialised at 10-06 against the HOURLY ~30k-60k envelope, NOT 15k daily. Suite 102->117. Commits 0b0d397, 628d674.
- [Phase 10]: 10-05: Panoptic.Sfpm proves the getAccountPremium poolKey encoding byte-for-byte via keccak256(poolKeyBytes)==known poolId; selector DERIVED from the signature; dynamic bytes poolKey head carries the 0x100 offset; calldata is 452B; decodeAccountPremium is length-defensive (64B two-word ABI / 32B LeftRight-packed) with currency0 in the right slot and fail-loud on short returndata; getAccountLiquidity implemented to disambiguate netLiquidity==0 (Pitfall 5).
- [Phase 10]: 10-05: Panoptic.Premium premiumWei applies the X64 (2^64) scale with long-leg negation (_getPremia L2296-2298); accDelta=diffMod 128 (unchecked uint128 wraparound, never signed sub); telescope asserts EXACT integer decomposition (Sigma per-epoch==endpoint, exact when L is a multiple of 2^64); PremiumFlag ChunkEmpty/AccFrozen/Extrapolated carried through so a zero delta is never ambiguous; multiplierWedge is a nu=1/8 Rational for the 10-11 cross-walk (reported, not applied). Suite 117->147/0. Commits 6360ffd, 56e0f49.
- [Phase 10]: 10-07: the gate VERDICT is scored on the SHORT stratum plus zero leg-count mismatches; the long stratum is reported in full but EXCLUDED from pass/fail (_getAvailablePremium caps SETTLED long premium while the accumulator reports ACCRUED, so a long wedge is protocol behaviour). Never pooled — RESEARCH's instruction is exact on both halves.
- [Phase 10]: 10-07: GROUND-TRUTH UNIT MEASURED, NOT ASSUMED — OptionBurn.premium0 is ALREADY raw 18-decimal units (median magnitude ~1e11-1e12), so truthWei = round(premium0) with NO 1e18 factor; corroborated by Panel.Build.premiumUsd dividing bePremium0 by 1e18. The determination and the converting expression are written into the report.
- [Phase 10]: 10-07: gateTolerance = 0.01 lives as ONE named top-level constant in Panel.Reconcile, referenced by the CLI, the report and the spec; reportOf is the SINGLE verdict rule shared by the gate and its test. The task-2 commit leaves Reconcile.hs byte-identical (0 diff lines matching gateTolerance.*=) — the diagnosis renderer was deliberately placed in app/Main.hs to preserve that auditability.
- [Phase 10]: 10-07: a leg-count mismatch FAILS the gate rather than merely being reported — a like-for-unlike comparison that happens to be close is worse than one that is loudly wrong (RESEARCH Pitfall 7).
- [Phase 10]: 10-07 PRE-CHECK RESULT: 5 short single-leg spells, median relative error 0.0 (3 exact to the wei), max 2.18e-9, signed bias 0/2 (one-signed -286/-239 wei flooring residual on ~1e11 wei premia), scaling-signature check clean, GATE PASS. The telescoping decomposition is confirmed sound; proceed to the full 61-spell gate in 10-08 with gateTolerance unchanged.
- [Phase ?]: Full 61-spell reconciliation: median 0.0 both strata, 53/61 exact to wei, all 8 long spells exact, worst 5.45e-4 (18x inside 0.01), residuals diagnosed as irreducible sub-block eth_call read wedge (both pre-registered suspects refuted). User adjudicated: proceed to 10-09/10-10. Execution HALTED by user before the 10-08 closing continuation ran.
- [Phase 10]: 10-08 THE GATE VERDICT: GATE: PASS on all 61 spells — MEDIAN_REL_ERROR_SHORT 0.0 (the scored stratum), MEDIAN_REL_ERROR_LONG 0.0, 53/61 exact to the wei, worst 5.447268e-4 (18x inside tolerance), LEGCOUNT_MISMATCHES 0. gateTolerance = 0.01 was NOT modified: git diff on Panel/Reconcile.hs is empty across 63a3fa2~1..HEAD, and every CLI gap was fixed in app/Main.hs precisely to keep that a one-line audit.
- [Phase 10]: 10-08 USER ADJUDICATION: PROCEED. The decision was recorded before a halt and executed only after the user-mandated anti-fabrication review gate returned CLEAN from two independent reviewers (A: 8 rows re-read vs Base archive, 32/32 integers exact, CLI re-run byte-identical, 3 subgraph truths match; B: all 61 recon_wei reproduced exactly in independent Python, stats recompute exactly, no planted literals). Recorded limitation: truth_wei materialises only in reconcile-errors.csv, mitigations documented in the read lineage. Corrections committed as 9ad94b2.
- [Phase 10]: 10-08 RESIDUAL DIAGNOSED, both pre-registered suspects REFUTED: multi-leg summation (4 of 7 two-leg spells exact, third-worst is single-leg) and mid-spell s_options rewrite (all 8 imperfect spells have exactly one mint, one burn, identical positionSize). True mechanism is an END-OF-BLOCK vs AT-TRANSACTION eth_call read wedge — sub-block on all 8 (the 72x case is 0.29 blocks after the 250x post-burn liquidity collapse), signs obey the live-chunk rule exactly, 8/61=13.1% matches the 0.124 swaps/block rate. IRREDUCIBLE at eth_call granularity; removing it needs transaction-level replay, a different data route.
- [Phase 10]: 10-08: the LONG stratum needed no allowance — 8/8 exact, SIGNED_BIAS_LONG 0/0. The _getAvailablePremium settlement cap the phase expected to open a downward long wedge DID NOT BIND on any spell in this sample. Reported rather than assumed, and still excluded from the pass/fail arithmetic as 10-07 specified.
- [Phase 10]: 10-09: telescope REPLACED by decomposePremium for the panel — per-interval flooring cannot hit TELESCOPE_MISMATCHES 0 for real leg liquidities; cumulative-difference increments are exact for any L
- [Phase 10]: 10-09: the accumulator delta's epoch tag CORRECTED to the accrual interval's STARTING epoch (block-index epoch e is the START of hour e); buildPremiumObs left byte-identical
- [Phase 10]: 10-09: epoch-panel is a separate subcommand, not a build-panel flag — build-panel rewrites panel.csv, THE frozen gate population the telescoping check is defined against
- [Phase 10]: 10-09: Panel.Epoch created as a leaf to break the Panel.Build/Panoptic.Chunk/Chain.BlockIndex cycle; forking the epoch index was the alternative and is the 09-05 trap
- [Phase 10]: 10-09: the single zero-swap hour (495112) is carried as a MEASURED row (sigma^2 = 0, pool tick carried forward, n_swaps = 0), justified by a re-fetch reproducing the tick cache byte-identically
- [Phase 10]: 10-10 RUN 1: the Phase-9 estimator ran BYTE-UNCHANGED on the 6,760-row position-epoch panel (git diff over src/Model, src/Tests, Alternatives.hs EMPTY; last touched bb15a96 in Phase 9). STOPPING_RULE UNINFORMATIVE — upsilon0-hat 3.597340e-2, clustered SE 7.548636e-2, CI half-width 1.479533e-1 vs the pre-committed 6.2e-5 bar. Verdict computed by stoppingRuleVerdict, which takes the half-width as its ONLY argument and so cannot consult kappa's sign or any p-value.
- [Phase 10]: 10-10 RUN 1 SIDE FINDING: kappa-hat = 3.090495e-2, clustered SE 1.318375e-2, p = 9.534719e-3 — H0 of a FLAT vega profile REJECTS for the first time in this project, and position-FE (now identified: 6,757 obs / 52 clusters, kappa_FE 3.162e-2) concurs, so strike-composition selection does not appear to be doing the identifying work. Symmetry also rejects (p = 2.4e-7). NOT a substitute for the stopping rule: kappa is about the profile's SHAPE, the rule is about upsilon0's LEVEL.
- [Phase 10]: 10-10 HALT: a construction defect was found AFTER run 1's verdict — 10-09's assembleEpochPanel kept the protocol's sign while Phase 9's Panel.Build.premiumUsd normalizes long spells to the seller side ('the same vega would enter with two opposite signs and cancel'). 2,280/6,760 rows (33.7%, 8/55 tokenIds) entered opposite-signed. The executor did NOT fix it in place and declined to propose the re-run from inside the run; the verdict was frozen and escalated. USER adjudicated escalate-anomaly under the anti-fishing-replication discipline.
- [Phase 10]: 10-10 RUN 2 (terminal, under pivot lock phase10-plan10-10-run2, sha256 56044349...43e9998 VERIFIED at run time — the CLI aborts on mismatch because the lock's own terms void it if edited): THE SINGLE CHANGE was long-tokenId premium x (-1). Verified independently in Python: 0 rows differ in any regressor, 1,735 pi values flipped, 5,025 identical. STOPPING_RULE UNINFORMATIVE AGAIN — upsilon0-hat 1.063317e-1, SE 1.009984e-1, half-width 1.979569e-1.
- [Phase 10]: 10-10 THE CONCLUSION: this market cannot identify upsilon. The bar failed under BOTH LHS constructions, so the uninformative interval cannot be attributed to the sign defect. Pre-registered branch A obtained via the FIRST disjunct ONLY (|upsilon0| moved away from zero x2.956; the SE WIDENED x1.338, which is NOT evidence for the mechanism). D1 improved 4.113 -> 1.862 but D2 is 'no' in both arms — the CI contains zero either way. The binding constraint is the 55-cluster ceiling with 84.1% of rows in ten positions, which no LHS transformation can touch.
- [Phase 10]: 10-10 kappa>0 PERSISTS under both constructions (p 9.534719e-3 -> 7.308348e-3), exactly as the lock anticipated (sign normalization acts on upsilon0's level). The FORMAL WITNESS does NOT obtain: hk is statistically supported but hu is satisfied in SIGN ONLY (p = 0.146, CI contains zero). The witness bar was TIGHTENED mid-plan to require support on BOTH hypotheses — the theorem takes hu AND hk — which is strictly harder to assert. exp_family_witnesses_ATMOTM stays proved and axiom-clean; the conjecture stays OPEN. No Lean file touched, no Aristotle task run.
- [Phase 10]: 10-10 THE BAR WAS NEVER MOVED. Mid-run it emerged that 6.2e-5 carries Phase 9's USD/day units while the realised half-width carries this panel's ETH/hour units. That incoherence is RECORDED in both analysis outputs and repaired in NEITHER; the pivot lock froze it explicitly. Also corrected: the 1.125 multiplier-wedge 'bound' is false on this market — measured median 1.1125, long max 1.2917, short max 1.2042, since 1+nu bounds it only when R <= N and here R/N reaches 2.33. Carry the MEASURED figures into 10-11, not 1.125.
- [Phase 10]: 10-CONTEXT ROUTE AMENDMENT (recorded here as the durable entry): the full V4 replay was WITHDRAWN as the primary route. The cached swap stream `swap-ticks-base-v4-full.csv` is a two-column `timestamp_unix,tick` file with no fee amount, no liquidity and no block number, and exact replay from events alone is impossible because `feeGrowthGlobal` updates per swap STEP with a step-varying liquidity divisor the Swap event does not expose. Replaced by archive `eth_call` reads of `SemiFungiblePositionManagerV4.getAccountPremium` — evaluating the identity INSIDE the contract that defines it. Replay survives only as the optional, non-blocking CTX-REPLAY-OPT cross-check.
- [Phase 10]: 10-01 WAVE-0 BLOCKER, threshold stated BEFORE the measurement: `PanopticPool._getPremia` L2250 skips every `width == 0` leg, so the phase's load-bearing x100 sample-gain premise was converted into a measurement taken before any pipeline work. GO threshold: 300 achievable panel rows AND within-position median >= 5 epochs. Measured: width != 0 on 68/68 spell-legs (the trap does not bind), daily grid FAILED the epoch condition (median 1) => STOP, honoured; hourly re-scope (chosen by the user before any estimation, thresholds untouched) returned GO at 6764 joinable rows and median 10.
- [Phase 10]: 10-08 GATE DEFINITION (the durable statement of what passing meant): median relative error <= 1% on `OptionBurn.premium0`, computed in Integer ETH WEI, STRATIFIED short vs long with only the short stratum scored (long premium is capped by `_getAvailablePremium`, so a long wedge is protocol behaviour, not a defect), plus zero leg-count mismatches as a hard failure. The tolerance was held as ONE named constant `Panel.Reconcile.gateTolerance = 0.01` and NEVER relaxed — `git diff` on Reconcile.hs is empty across the gate commits, which is what makes that a one-line audit rather than a claim.
- [Phase 10]: 10-10 STOPPING RULE (pre-committed and result-INDEPENDENT): success = upsilon0 clustered-CI half-width <= 6.2e-5, regardless of kappa-hat's sign or significance. Enforced by construction, not by discipline: `stoppingRuleVerdict :: Double -> String` takes the realised half-width and NOTHING else, so it cannot consult a direction or a p-value even by accident.
- [Phase 10]: 10-11: the multiplier wedge is recorded in the cross-walk as a MEASURED distribution (N 8910, median 1.112500, p25 1.000000, p75 1.204167, p90 1.291667, max 1.291667, mean 1.117256, 3467/8910 exactly 1, max R/N 2.333333), and the 1.125 figure is corrected rather than repeated. The wedge's SHAPE contamination is NOT claimed negligible: on a chunk-level moneyness proxy Pearson 0.143545 / Spearman 0.122141 with non-monotone quintile medians, flagged as a threat to validity; its direction biases kappa-hat toward zero, so the kappa>0 rejection is conservative with respect to it — stated as a proxy argument, not a correction.
- [Phase 10]: 10-11: 10-12 (CTX-REPLAY-OPT) is SKIPPED, and CTX-REPLAY-OPT is recorded as NOT satisfied rather than quietly marked done. Reason: the cross-check's purpose — independent evidence that the reconstructed premium is the protocol's — is already served by the 10-08 gate reconciling all 61 spells against on-chain `OptionBurn.premium0` wei-exactly (53/61 exact) and by two independent anti-fabrication reviews returning CLEAN (live archive re-read 32/32 integers exact; full offline Python recomputation, no planted literals). The plan was optional and non-blocking by construction and nothing downstream depends on it. The plan file stays in place, unexecuted; the user may request the run later.
- [Phase 11]: 11-01: the fee is \phi, NEVER \varphi — the parent doc already binds \varphi to the quote function (line 305); caught by the Reality Checker as a BLOCKER. Standing rule adopted: the document's own notation is always preserved, a conflicting EXTERNAL symbol gets a NEW symbol, and every remap is recorded in the marker-whitelisted notation-map paragraph.
- [Phase 11]: 11-01: lambda_ARB (arb channel) and lambda_MEV (aggregate, defined exactly once in M7) are DISTINCT symbols; lambda_ARB ABSORBS the doc's 'arb toxicity' index entry so the aggregate cannot double-count. Blocks M3-M6b are stated on lambda_ARB alone.
- [Phase 11]: 11-01: M6b is stated over arbitrary fee PATHS, not over Theta_phi SCHEDULES — at constant sigma every admissible schedule already yields a flat path, so the schedule-level claim was vacuous. The sigma-varying schedule comparison is labelled OPEN. This overrides 11-RESEARCH F6; the reviewer won and the paper is silent.
- [Phase 11]: 11-01: a_t carries an explicit Delta t — MMR's LVR is a RATE per unit time, so the per-block weight is (sigma^2/8)V*Delta t and the summand scales Delta t^{3/2} per MMR section 7.1. Without it lambda_FLAIR commensurability was false and the cadence lever understated by a factor of Delta t.
- [Phase 11]: 11-01: the Angstrom rebate is an LP-INCIDENCE object, not an intensity reduction — tau redistributes extracted value to LPs and leaves extraction intensity invariant; tau stays parametric and k=49 appears only as a dated snapshot instance.
- [Phase 11]: 11-01: approved bytes pinned by APPROVED-DOC-SHA256 / APPROVED-ADDENDUM-SHA256 because the plank doc is live, uncommitted and foreign-owned; 11-02/11-04 grep the doc hash so an unannounced edit to the ### MEV section hard-fails instead of drifting.
- [Phase 11]: 11-02: the approved DOC outranks the plan's task text as the specification — the plan's T8 draft had dropped the doc's ·Δt factor and was corrected against the doc, catching a re-introduction of 11-01's own BLOCKER 4
- [Phase 11]: 11-02: T17 (compact minimizer) is FALSE for arbitrary compact Θ — ptrade has a pole at negative fees; the prompt now carries an admissibility constraint and explicitly forbids a bare ContinuousOn hypothesis as the repair
- [Phase 11]: 11-02: three Mathlib hints supplied by the plan do not exist at v4.28.0 (strictConvexOn_inv, StrictConvexOn.comp_affineMap, StrictConvexOn.smul); replaced with verified routes and the non-existences stated so the prover does not hunt for them
- [Phase 11]: 11-02: Aristotle submission bundles are NOT committed (scratch/ is gitignored and no prior bundle was tracked); their identity is pinned by sha256 in the committed run record
- [Phase 11]: 11-03: T15's saturation limit as specified was FALSE — Aristotle added 0 <= phibarMax + uMax*alphamax0 because the limiting fee otherwise lands on ptrade's negative-fee pole (the same pole that made the pre-review T17 false); the requirement is satisfied by a CORRECTED statement, disclosed
- [Phase 11]: 11-03: the returned proof is immutable — the only edit made was the mechanical RequestProject. -> vol_markets. import rewrite, because hand-editing a returned proof voids the verification it carries
- [Phase 11]: 11-03: T19 (ARBoverV_exact, block M3(ii)'s exact CPMM kernel and the sole carrier of the sigma^2*dt < 8 guard) was OMITTED as permitted; reported as a real gap in the repo rather than absorbed, since nothing in the leading-order program depends on it
- [Phase 11]: mevTotal is PLAIN ADDITION (lamARB + lamSand), not probOr — the plan's own draft contradicted approved block M7; both reviewers found it independently and probOr_hazard was the decisive evidence
- [Phase 11]: T25 restated at the PATH level via new flairPath/mevPath carriers — the plan's schedule-level draft was a vacuous triviality, exactly the document's own M6b OPEN note
- [Phase 11]: T24's outcome-2 escape hatch EXCLUDES any added hypothesis forcing the fee path constant, closing a letter-compliant loophole that would have banked T25 as the hard result
- [Phase 11]: T24 (varying-sigma flat-fee optimality) is REFUTED by machine-checked counterexample mev_ge_flat_under_flair_budget_false, not OPEN and not satisfied by T25 — doc block M6b must change OPEN to FALSE
- [Phase 11]: The refutation's REACH is bounded explicitly: it settles the GENERAL schedule-level claim; the Theta_phi-restricted varying-sigma case stays OPEN because the witness schedule is sigma-decreasing while multiFee is isotone
- [Phase 11]: Executor numerics indicating the violation persists for isotone multiFee schedules are recorded as NOT machine-checked and are never merged into the verified claim
- [Phase 12]: Curvature index is kappa_varphi, not chi (USER amendment 2026-07-31); fee retyped \phi — \varphi is the quote-function symbol per M0
- [Phase 12]: CTX-DEGEN NARROWED (USER): no literal de-degeneration theorem — binding on what 12-02 may ask Aristotle to prove
- [Phase 12]: ETA block placement: the user-authored ## FLAIR & MEV stub body replaced, the user's title kept
- [Phase 12]: The eta bridge ships as TWO claims: exponent identity (provable) and factor-share identification (OPEN)
- [Phase 12]: 12-02: bundle is EIGHTEEN modules, not the plan's seventeen — JitLiquidity landed mid-plan and the binding rule is doc + ALL proved modules
- [Phase 12]: 12-02: cOne ships as a DEFINITION, not a free parameter — the kphiI branch agreement holds only for E4's closed form, and freeing it would silently falsify the peak
- [Phase 12]: 12-02 (USER): submit now, amend the document LATER (12-04) — never desync a pinned doc from the copy an in-flight task proves against
- [Phase 12]: 12-02: T17'b ADDED as a new REQUIRED item — E5's zero-sum identity, the clean approved content that survives if the OPTIONAL welfare item T18' is omitted
- [Phase 12]: 12-02: the bundled doc copy is NOT re-copied at submit time — it is the gated frozen artifact and the live plank file was under concurrent edit

### develop segment 5 of 5

Last session: 2026-08-02T13:54:23.806Z
Stopped at: Completed 12-04-PLAN.md — PHASE 12 CLOSED, queue FREE
Next: **Phase 11 is closed and nothing further is scheduled in it.** The user-designated successor thread is the interior-`η` curvature layer (Capponi–Jia; PDFs in `../plank/refs/mev/`) — the direct consequence of M6a, since over `Θ_φ` alone there is no trade-off to control and the degeneracy-breaker must come from outside the fee parameter set. Two named formalization follow-ups remain OPTIONAL and non-blocking: (1) a second refutation carrying an explicit `multiFee` witness, which would close the `Θ_φ`-restricted σ-varying case; (2) T19's exact Corollary-2 CPMM kernel, the only carrier of the `σ²Δt < 8` guard. Neither is scheduled.
Also: nothing is scheduled in Phase 10. If the user wants 10-12 later, the plan file is in place and unexecuted. Any future work on υ identification must add INDEPENDENT positions — the 55-cluster ceiling, not the LHS, is the binding constraint.

