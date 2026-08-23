---
phase: 28-resident-loop-fixture-publication
plan: 05
subsystem: offchain-loop
tags: [haskell, loop, crash-consistency, sigint, signals, exit-codes, tier-c-capture, census, blocked]

requires:
  - phase: 22-driver-capture
    provides: "`Driver.Capture.write_atomically` — the ONE rename, whose surviving-sibling failure is this plan's third firing input"
  - phase: 27-anvil-read-layer
    provides: "`offchain/rig/capture-chain-read.sh` — the Tier-C gating shape this plan's capture copies, and the both-directions endpoint census a new shell site has to satisfy"
  - plan: 28-01
    provides: "`Loop.Ledger`'s one-call block commit, whose indivisibility is what makes an abandoned block cost nothing"
  - plan: 28-02
    provides: "`Loop.Run`'s one iteration function and `Loop.Config`'s exit table, both of which this plan extends"
  - plan: 28-03
    provides: "`publish_for`'s deliberate `try` around the write — the ruling that makes the publish stage the one stage that does NOT abandon the block"
  - plan: 28-04
    provides: "`the_fixtures_directory_is_recorded_absent_from_both_trees` — the measurement the capture's second refusal quotes"
provides:
  - "`Loop.Run.env_interrupted` — the shutdown as a question the loop asks, read at two points and both between blocks"
  - "`Loop.Run.run_loop`'s wrapper around the iteration, and `Loop.Config.HaltBlockException` / exit 34 — the tenth table entry, DEMANDED by the totality check rather than permitted by it"
  - "`offchain/app/LoopMain.hs`'s SIGINT/SIGTERM handler, which writes one Bool and does nothing else, and a final machine-readable halt line"
  - "`Loop.Config.halt_name` and `Loop.Run.json_token`, exported so the halt line names its condition through the table and escapes through the one escaper"
  - "`offchain/rig/capture-loop.sh` — the live Tier-C run, written, gated, listed in the endpoint census, and UNRUN"
  - "four checks: the seven-stage exception battery, the interrupt at a boundary, the fixture after an interruption, and the capture's absence AS A VERDICT"
  - "LOOP-02's second direction asserted over the LOOP, folded into an existing check so the total did not move"
affects: [28-SUMMARY, LOOP-02, LOOP-05, CHAIN-01]

tech-stack:
  added: ["unix (executable loop stanza; GHC boot library, +0 packages MEASURED)"]
  patterns:
    - "A shutdown is stated as a PLACE the flag is read, not as a promise about a handler — because a handler that acts runs in the middle of whatever the main thread was doing"
    - "A battery's per-stage EXPECTATION is data, so a stage that legitimately behaves differently is recorded rather than forced into a uniform claim the code does not make"
    - "A check whose subject does not exist yet is written INVERTED: it passes on absence and its failure text says what each direction means"
    - "A firing input that makes the suite pathological is re-aimed surgically rather than waited out"

key-files:
  created:
    - offchain/rig/capture-loop.sh
  modified:
    - offchain/lib/Loop/Config.hs
    - offchain/lib/Loop/Run.hs
    - offchain/app/LoopMain.hs
    - offchain/lib/Chain/Endpoint.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md

key-decisions:
  - "`HaltBlockException` is a FIFTH constructor and a TENTH exit code rather than a reuse of `HaltDb` or `HaltRpcExhausted`: an outer wrapper cannot tell which stage threw, and a chain failure recorded under a ledger discriminator is 28-01's conflation arriving from the far end"
  - "The interrupt is `installHandler` and NOT `UserInterrupt`: GHC's default throws asynchronously at a point nobody chose, and replacing the handler is what makes 'read between blocks' true rather than likely"
  - "The battery drives `run_loop`, not `process_block` — four of the seven stages are components the iteration does not wrap, and driving it directly measures the wrong composition"
  - "The PUBLISH stage's disposition is `commits`, recorded as data with 28-03's reason, rather than changed to make a uniform claim pass"
  - "`the_live_loop_capture_is_present_and_names_its_block` reads NO artifact: `aeson_is_absent_from_the_storage_path`'s haddock rules that a missing subject is a FAILURE naming the plan that creates it"
  - "LOOP-02's loop-level arms went into `a_cache_hit_publishes_at_the_events_own_block`, which already stages the collision, rather than into a new check that would re-stage it"

patterns-established:
  - "Two haddock sentences naming a seam were MOVED so a `grep -c` over the module prints 1 — 27-01's rule for the thirtieth time, and the first time it caught PROSE THAT PREDATED THE PLAN"

requirements-completed: [LOOP-02, LOOP-05]

duration: 246min
completed: 2026-08-23
---

# Phase 28 Plan 05: Crash Consistency, the Shutdown, and the Phase Close Summary

**An exception was injected at SEVEN stages of one iteration and every abandoned block left the
watermark exactly where it was, no row for the event, and a block a clean pass re-processed under
the SAME content key — and the interrupt was OBSERVED landing block 2 whole, both of its rows and
its watermark together, with block 3 never entered, reddening at
*"Row counts by block: [(1,1),(2,0),(2,0),(3,0)]"* the moment the flag was read between events
instead of between blocks.**

## Performance

- **Duration:** 246 min
- **Started:** 2026-08-23T09:08:07Z
- **Tasks:** 3/3
- **Files modified:** 9 (1 created, 8 modified)

## Commits

| Task | Commit    | Subject                                                                    |
| ---- | --------- | -------------------------------------------------------------------------- |
| 1    | `63e0c84` | a shutdown read between blocks, and an exception at every stage             |
| 2    | `478845d` | the live capture, written and gated and recorded as blocked                 |
| 3    | `e2b801d` | LOOP-02's second direction, asserted over the loop                          |

## The numbers, as measured

| Quantity                                     | Before  | After   | How                                              |
| -------------------------------------------- | ------- | ------- | ------------------------------------------------ |
| `cabal test` total (`BASE_5` -> `BASE_5 + 4`) | **228** | **232** | run COLD at `572ec0e` before any edit, then again |
| `cabal test` wall clock                       | 534 s   | **551 s** | `date` around the binary, both ends RUN        |
| `cabal build --enable-tests -j all` warnings  | 0       | **0**   | `grep -cE '[Ww]arning'` over the build log       |
| `^Downloading` lines                          | 0       | **0**   | same log; `unix` is a GHC boot library           |
| `purge_file_floor`                            | 82      | **83**  | `find` RUN at both ends, zero slack              |
| `credential_scan_floor`                       | 93      | **94**  | `find` RUN at both ends, zero slack              |
| `endpoint_sites` entries                      | 19      | **20**  | counted in the source, not from the haddock      |
| `exit_table` non-zero entries                 | 9       | **10**  | counted in the source                            |

**`BASE_5 = 228` was measured COLD** at this plan's start against a clean tree at `572ec0e`:
`228/228 checks passed`, `WALL_SECONDS=534`, build exit 0, 0 warnings, 0 `Downloading`.

**BOTH FLOORS RE-MEASURED BY RUNNING `find`, AND BOTH MOVED BY THE SAME ONE** — this plan commits
exactly one file, `offchain/rig/capture-loop.sh`:

```
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l
83
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
94
```

Extension census under `offchain/` at close: **hs 66, sh 13, json 11, sql 4**. `sh` moved by one and
**`json` did NOT** — which is the capture's artifact being ABSENT, stated as a number rather than as
a sentence.

**FOUR CHECKS COST THE SUITE SEVENTEEN SECONDS** — 534 s to 551 s through roughly fifteen sweep
passes, so about one second of direct work. 28-03's multiply-by-fifteen rule was applied before any
of them was written: none races, none sleeps, and the battery's seven stages each run one `--once`
pass over a single block. **335 s of headroom against the 900 s ceiling remain.**

## What was built

### Task 1 — the shutdown, the wrapper, and the battery (`63e0c84`)

**`Loop.Run.env_interrupted :: IO Bool`**, asked at exactly two points and both BETWEEN blocks: at
the top of a pass before a range is planned, and after an iteration returns before the next block is
entered. A block that has begun always finishes; a block that has not begun is never begun.

The property is stated as a PLACE rather than as a promise, and the reason is in the haddock: the
alternative is a handler that acts. `LoopMain` owns the `IORef Bool` and installs
`installHandler sigINT (Catch …)` and the same for `sigTERM`; the handler writes the ref and
returns — no logging, no exit, no IO of any kind. **GHC's DEFAULT `SIGINT` behaviour has the shape
the design is avoiding:** it throws `UserInterrupt` at the main thread asynchronously, at a point
nobody chose, and "a point nobody chose" includes the middle of the ledger's one commit.
`installHandler` REPLACES it, so no exception is delivered at all. `SIGTERM` is caught by the same
handler because a resident process is stopped by a supervisor far more often than by a keyboard.

A clean drain returns `Right ()` and `LoopMain` exits 0, printing on stderr which of the two clean
endings it was.

**The iteration is wrapped.** `process_block` catches the two failures it can NAME — the solver seam
and the ledger commit. Everything else it does can still throw. Those are caught in `run_loop` as
`Loop.Config.HaltBlockException`, carrying the block and what was thrown, and the block is abandoned
without a commit.

### Task 2 — the live capture, gated and unrun (`478845d`)

`offchain/rig/capture-loop.sh`, in `capture-chain-read.sh`'s shape: source the shared resolver, hold
no literal authority, validate-first-replace-second around the artifact, and five self-checks that
read NUMBERS out of what was written — the loop's exit code, the watermark strictly advancing, at
least one ledger row, a fixture with bytes that `jq -e` parses, and no outcome token outside the
vocabulary.

**THE GATE WAS EXERCISED, WITH NO RIG STOOD UP AND NOTHING WRITTEN.** Verbatim:

```
$ bash offchain/rig/capture-loop.sh
CAPTURE FAIL: nothing answered eth_blockNumber at http://127.0.0.1:8545.
              This is NOT a skip. LOOP-01..05's live evidence is an observation against a real
              chain, and a capture that quietly did nothing would leave the committed artifact
              stale -- or absent -- while reporting success.
              Stand the rig up first: bash offchain/rig/deploy-rig.sh
EXIT=1
```

`offchain/rig/loop-conformance.json` was still absent afterwards and `git status --porcelain` still
showed only the four pre-existing untracked root files. **No anvil was started and none was stopped,
because none was needed to observe the refusal.**

### Task 3 — LOOP-02 over the loop, and the four documents (`e2b801d` + the close)

See the traceability rows in `.planning/REQUIREMENTS.md` and the phase record in `28-SUMMARY.md`.

## The seven stages, and their dispositions

| # | Stage      | Broken by                            | Halts? | Store entry? |
| - | ---------- | ------------------------------------ | ------ | ------------ |
| 1 | `logs`     | `source_logs` raises                 | yes    | 0            |
| 2 | `seen`     | `ledger_seen` raises                 | yes    | 0            |
| 3 | `reads`    | `source_reads` raises                | yes    | 0            |
| 4 | `solve`    | `solver_run` raises                  | yes    | 0            |
| 5 | `identity` | `env_read_identity` raises           | yes    | 1            |
| 6 | `publish`  | a DIRECTORY at the sibling temp path | **no** | 1            |
| 7 | `commit`   | `ledger_commit_block` raises         | yes    | 1            |

**BOTH COLUMNS THAT VARY ARE DELIBERATE DESIGN DECISIONS MADE IN EARLIER PLANS, AND RECORDING THEM
AS DATA IS THIS PLAN'S FINDING RATHER THAN A WEAKENING OF ITS CHECK.**

Stage 6 does not abandon the block because 28-03 wrapped the write in `try` on purpose —
`publish_for`'s own haddock says a full disk or a directory that vanished mid-run is not a reason to
stop processing the chain, the ledger is the record that matters, and it has already been decided.
Asserting "every stage leaves the watermark unadvanced" would have required reverting that ruling in
order to make a check pass, which is a check measuring itself.

Stages 5–7 leave a store entry because `decide` writes it before they are reached, and that write is
CONTENT-KEYED: the re-processed block recomputes the same key, finds it, and elides. A store entry
surviving an abandoned block is not a half-written anything. What shows it is harmless is the RE-RUN
arm, not an assertion that it is absent — and that arm is uniform across all seven: a clean pass over
the same block on the same store and ledger reproduces the row's `(event, block, key)`, and the
watermark ends at the block. `lr_outcome` is deliberately excluded from that comparison, because for
stages 5–7 the re-run legitimately reports `elided` where a fresh pass reported `stored`.

## The firing inputs, every one OBSERVED

| #    | Mutation                                                                | Result                                                                 |
| ---- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| M1   | hoist the commit ahead of the event loop in `process_block`              | **228/231**, caught by TWO checks with different diagnoses              |
| M2   | read the interrupt flag between EVENTS instead of between blocks          | **229/231**                                                            |
| M3a  | `renameFile` → read-then-write (copy, temp survives, rename gone)         | **ABANDONED — 52 minutes of CPU without finishing**                     |
| M3b  | keep the rename, re-fill the temp file after it                           | **228/231**, caught by this plan's check AND 28-04's tree diff          |

Every mutated source was restored from a copy and **`sha256sum -c` reported `OK` on both baselines
after every drive**, including the abandoned one.

M1, verbatim, from the run:

```
FAIL an_exception_at_each_stage_leaves_the_watermark_unadvanced: STAGE seen: THE WATERMARK READS
      Just 0 and this stage abandons the block, so it must be UNCHANGED at Nothing. A watermark
      advanced over an abandoned block is the one failure that is silent AND permanent: the restart
      skips the block and nothing ever says so.
FAIL the_published_fixture_survives_an_interrupted_iteration: the watermark reads Just 29, expected
      Just 5 -- the LAST COMPLETED block. The interrupted iteration published and was then
      abandoned, so it must not have advanced anything.
```

M2, verbatim:

```
FAIL an_interrupt_is_observed_only_at_a_block_boundary: THE BLOCK THAT WAS IN FLIGHT DID NOT
      COMPLETE. Row counts by block: [(1,1),(2,0),(2,0),(3,0)]. Blocks 1 and 2 were entered before
      the shutdown was seen, and block 2 carries TWO events -- a loop that read the flag between
      EVENTS would abandon it part-way and leave one or both of those rows missing. The current
      block's transaction completes or rolls back; it is never half.
```

M3b, verbatim, and note the second check:

```
FAIL publication_adds_exactly_one_file_and_nothing_else: the FIRST publication added
      ["volume_path.json","volume_path.json.tmp"] to the publication directory, and LOOP-04 says it
      adds exactly ["volume_path.json"].
FAIL the_published_fixture_survives_an_interrupted_iteration: a temp sibling SURVIVED the
      interrupted publication: ["volume_path.json","volume_path.json.tmp"].
```

## Findings

### THE PLAN'S OWN PRESCRIBED FIRING INPUT FOR CHECK 1 WOULD HAVE BEEN INERT, AND THE REASON NAMES WHAT THE ARM ACTUALLY GUARDS

28-05-PLAN.md prescribes: *"move `ledger_commit_block` ahead of the publish stage — the publish-stage
arm must observe an advanced watermark."* Under the shipped code the commit is ALREADY after the
publish stage and a publish exception is ALREADY swallowed, so the block commits either way: the
mutation moves the commit past a step that never halted, and the publish-stage arm's expected
watermark is `Just block` before and after. It distinguishes nothing.

What the arm really guards is the commit being the LAST statement of the whole iteration rather than
merely the last statement after publication. So the mutation driven was the stronger one — hoist the
commit ABOVE the event loop, so the block's watermark is written before a single event is decided —
and it reddens six of the seven stages at once, each naming itself. The first one printed is the
message above.

### `HaltBlockException` IS A TENTH EXIT CODE, AND THE TOTALITY CHECK IS WHAT DEMANDED IT

28-02 shipped `exit_table` complete on day one with the argument that a table growing one code per
plan is a table nothing can assert is total. That argument is about a code for a condition that was
ALREADY REACHABLE and unnamed. This is not that: before this plan an exception escaping a stage
killed the process with a bare Haskell exception and **no exit code from any table at all**. The
condition did not exist until the iteration was wrapped.

`the_loop_exit_codes_are_total_and_disjoint_from_the_gams_domain` asserts the constructor images and
the table's codes are the SAME SET, in both directions, so adding the constructor without adding
`("halt_block_exception", 34)` reddens it. The check REQUIRED the entry rather than permitting it,
and 34 is outside `Gams.Exit.gams_code_domain` (`[0..11] ++ [109..115] ++ [141,144,145,146]`) and
outside the timeout wrapper's `[124, 137]` by the same arm that has always asserted it.

It is deliberately not mapped onto `HaltDb` or `HaltRpcExhausted`. An outer wrapper genuinely cannot
tell which stage threw, and a chain failure recorded under a ledger discriminator is exactly the
conflation 28-01 refused to add an `AbortReason` constructor for, arriving from the other end.

### THE BATTERY HAD TO DRIVE `run_loop`, AND THE FIRST VERSION MEASURED THE WRONG COMPOSITION

Written against `process_block` directly, the battery went **229/231** with
`an_exception_at_each_stage_leaves_the_watermark_unadvanced` red: four of the seven stages —
`source_logs`, `ledger_seen`, `source_reads`, `env_read_identity` — are components the iteration does
NOT wrap, so their exceptions escape it. They are caught one level up, by a caller that is always
there in production. A battery that reported those four as "escaping" would be reporting a true fact
about a function nobody calls alone.

Driving `run_loop Once` also forced the block to be `Loop.Config.loop_first_block`: a sweep that
crossed quiet blocks first would have advanced the watermark through them legitimately, and the arm
asserting it is UNCHANGED would have been about the wrong number. One block, one event, one thing
that can have moved.

### THE THIRD FIRING INPUT MADE THE SUITE PATHOLOGICAL, AND THAT IS A FACT ABOUT THE HARNESS

Driven as the plan describes — `renameFile tmp path` replaced by a copy that leaves the temp file —
the mutation reddens 28-03's ten-second race check, which puts a ten-second check into
`sentinel_falsification_harness`'s reader sets. 28-03 MEASURED that shape at 2328 s against a normal
528. **This run passed 52 minutes of CPU without finishing and was abandoned.**

The consequence is worth writing down rather than rediscovering: **a whole CLASS of firing input —
anything that reddens an expensive check — cannot be driven on this suite in reasonable time.** The
repair is to re-aim the mutation surgically at the arm under test, which is what was done: keep the
rename (so the race stays green) and re-fill the temp file after it (so a sibling survives). The arm
reddened in a normal 553 s, and it reddened 28-04's tree diff too, which is the pair of guards
working. Recorded in `deferred-items.md` for whoever owns the harness.

### TWO HADDOCK SENTENCES SPELLED THE COMMIT'S NAME, AND ONE OF THEM PREDATED THIS PLAN

Task 1's acceptance asks that `grep -c "ledger_commit_block" offchain/lib/Loop/Run.hs` print `1`.
**It printed 3.** One was the call site; the other two were prose — and only ONE of them was this
plan's. The other is 28-02's, in the module header, and it had been there since the file was
created.

The prose moved, both sentences, and the replacement is stronger than a quieter version of the same
claim: the module header now STATES the property the grep holds — the commit is named exactly once
and it is the last statement of the iteration — so the grep has a subject a reader can see the point
of. 27-01's rule for the thirtieth time on this branch, and the first time it has caught prose that
was not written by the plan being executed.

### THE `unix` DEPENDENCY IS `+0` PACKAGES, MEASURED, AND IT IS IN THE EXECUTABLE AND NOT THE LIBRARY

`System.Posix.Signals` is not a boot-free import, but `unix` is a GHC boot library that `process`
already depends on and that 28-03 already added to the test-suite stanza. Adding it to
`executable loop` produced **0 `Downloading` lines** on the build that introduced it.

It is in the executable deliberately. Nothing under `offchain/lib/Loop/` installs a handler and
nothing there should: `Loop.Run` READS a flag it was handed, and who sets it — and from which
signal — is the executable's business. That is exactly what lets `cabal test` drive the interrupt at
a moment no signal could produce, which is "during block 2's log fetch".

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 3 — Blocking] The stage battery, written against `process_block`, measured the wrong
composition**
- **Found during:** Task 1
- **Issue:** four of the seven stages' exceptions escape the iteration and are caught by `run_loop`;
  the check's first arm required the iteration to catch them, and went red at 229/231.
- **Fix:** the battery drives `run_loop Once`, and the block moved to `loop_first_block` so the
  watermark arm has one thing that can have moved.
- **Commit:** `63e0c84`

**2. [Rule 3 — Blocking] Task 1's `grep -c "ledger_commit_block"` criterion was unsatisfiable**
- **Found during:** Task 1
- **Issue:** printed 3; two matches were haddock, one of them 28-02's and predating this plan.
- **Fix:** the prose moved; the module header now states the property the grep holds.
- **Commit:** `63e0c84`

**3. [Rule 2 — Missing critical functionality] The capture script spelled two hex constants inside
`sc3_literal_purge`'s blast radius**
- **Found during:** Task 2
- **Issue:** `.sh` is in `purge_scanned_extensions`, and the script's block explanation named
  `SELECTOR_NEXT`'s value and the event's topic0 — an 8-hex and a 64-hex literal.
- **Fix:** both removed and referred to by name, with `REQUIREMENTS.md` CHAIN-01 named as where the
  written values live. Caught BEFORE the file was committed rather than by a red run.
- **Commit:** `478845d`

### Departures from the plan's sketch, toward the property the plan asked for

**4. `HaltBlockException` and exit 34 are a FIFTH `Halt` constructor the plan does not name.** The
plan says "the loop halts with the corresponding `Halt`". There was no corresponding one, and the
three that exist each mean something specific. See the finding above.

**5. The battery has SEVEN stages with per-stage DISPOSITIONS, where the plan asks for a uniform
"the watermark is unadvanced, no row, the store gained no entry".** Two of those three are false for
some stages BY DESIGN, and both designs are earlier plans' deliberate rulings. See the table above.

**6. The plan's prescribed firing input for check 1 was replaced by a stronger one.** See the
finding; the prescribed one distinguishes nothing under the shipped code.

**7. The plan's prescribed firing input for check 3 ("write the destination directly instead of
through the rename") was replaced.** 28-04 already MEASURED that an after-the-fact observer cannot
see a temp file that was renamed away, and 28-03 measured that only a concurrent reader sees the
tear. The arm this plan owns is the SURVIVING sibling, and the mutation that reddens it is one that
leaves a sibling behind.

**8. A FOURTH check was registered.** The plan's Task 1 names three and Task 2 names one; the total
is `BASE_5 + 4`, not `+ 3`.

**9. LOOP-02's loop-level arms were added to an existing check.** The plan does not mention LOOP-02.
28-01's summary recorded that the requirement is stated over the LOOP and was asserted against a
composed pipeline, and the phase could not honestly mark it complete without closing that. The arms
went into `a_cache_hit_publishes_at_the_events_own_block`, which already stages the exact collision,
so the total did not move.

## Authentication gates

None.

## What this leaves

- **The live run.** `offchain/rig/capture-loop.sh` has never executed. CHAIN-01 / issue #26 for the
  emitter, issues #24 and #25 for the publication directory. The check that records this goes RED
  the day the artifact appears, and its failure text says what to do then.
- **A real signal.** The handler compiles and has never run; see `deferred-items.md`.
- **The RPC retry**, still. 28-02 filed it, three plans have not taken it.
- **The harness's cost model**, sharpened: a firing input that reddens an expensive check cannot be
  driven here.

## Self-Check: PASSED

- `offchain/rig/capture-loop.sh` — FOUND
- `offchain/lib/Loop/Config.hs` — FOUND
- `offchain/lib/Loop/Run.hs` — FOUND
- `offchain/app/LoopMain.hs` — FOUND
- `offchain/lib/Chain/Endpoint.hs` — FOUND
- `offchain/test/Main.hs` — FOUND
- `cfmm-replicationPlank-rpc-api.cabal` — FOUND
- `offchain/rig/loop-conformance.json` — ABSENT, as asserted
- commit `63e0c84` — FOUND
- commit `478845d` — FOUND
- commit `e2b801d` — FOUND
