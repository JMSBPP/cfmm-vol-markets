---
phase: 28-resident-loop-fixture-publication
plan: 01
subsystem: database
tags: [haskell, postgres, migrations, ledger, watermark, cabal, gams, content-key]

requires:
  - phase: 23-postgres-foundation
    provides: "the migration manifest, the named-constraint idiom, `withTransaction`'s client, and the store-conformance capture whose freshness oracle this plan had to re-satisfy"
  - phase: 25-content-key-keyed-store
    provides: "`Store.Cache.decide`, the `Store.Solver` seam, `Store.Memory` and the counting-stub instruments the six new checks reuse verbatim"
  - phase: 26-shock-assembly
    provides: "`Fee.Split.min_admissible_dstar` and `is_admissible`, from which the inadmissible witness is DERIVED rather than spelled"
  - phase: 27-anvil-read-layer
    provides: "the measured-before-written discipline, the endpoint/chain census terms every new file must not name, and the three structural greps"
provides:
  - "`Loop.Solve` — S2 closed by moving resolution to the caller (no lying `AbortReason`), plus the toolchain stash `decide` throws away"
  - "`Loop.Solve.classify` — S3 as data: four outcomes, a reason, the artifact, and `cl_halts` as ONE field"
  - "`Loop.Ledger` — the `Ledger` seam with a one-call/one-transaction block commit, on memory and on postgres"
  - "migration `004_loop_ledger.sql` — `loop_event` unique on `(tx_hash, log_index)` and the single-row `loop_watermark`"
  - "a re-taken `offchain/rig/store-conformance.json` naming four migrations"
  - "six checks: LOOP-02's two directions, S3's discrimination, the vocabulary set, the DDL guarantees, and the indivisible commit"
affects: [28-02, 28-03, LOOP-01, LOOP-05, STORE-07]

tech-stack:
  added: []
  patterns:
    - "Resolution is a STARTUP precondition, not a per-solve failure — the seam takes resolved paths so no `AbortReason` has to lie"
    - "The failure policy is a FIELD (`cl_halts`), not a branch at each call site"
    - "One call, one transaction: the block commit has no arity at which a caller can forget the watermark"
    - "The reference ledger refuses exactly what the server's CHECK refuses — Tier B must predict Tier C"
    - "A reader SCANS for the identity it was asked about rather than looking up the key it assumes the writer used, so a re-keying mutation is observable"

key-files:
  created:
    - offchain/lib/Loop/Solve.hs
    - offchain/lib/Loop/Ledger.hs
    - offchain/migrations/004_loop_ledger.sql
  modified:
    - offchain/lib/Store/Schema.hs
    - offchain/rig/store-conformance.json
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "S2 is closed by MOVING resolution out of the seam, not by widening `AbortReason` — a startup fact recorded under the same discriminator as a solver failure is the exact conflation S3 exists to prevent"
  - "S3 is NARROWER than 27-SUMMARY states: `decide` already returns `Left (Inadmissible ...)` before the solver is reachable, so the abort-line discriminator is needed only by the capture that drives the eight-refusal renderer"
  - "The memory ledger holds ONE `IORef` over both the rows and the watermark — two refs cannot make a half-applied commit unrepresentable"
  - "The memory ledger applies migration 004's row CHECKs and RAISES, tightening the reference rather than loosening the server (23-04's ruling, repeated)"
  - "STORE-07 stays DEFERRED; `loop_event` is a partial STORE-07 BY CONSTRUCTION and the migration header and the traceability row both say so"

patterns-established:
  - "Docker is verified BEFORE the migration is written, because adding one turns the freshness oracle red and an executor who finds that out with no server is one step from weakening the check"
  - "A firing input that refutes its own prediction is recorded in the haddock, not quietly re-aimed"

requirements-completed: []

duration: 55min
completed: 2026-08-22
---

# Phase 28 Plan 01: Loop Seams and the Per-Event Ledger Summary

**S2 and S3 are closed in the library — the seam takes already-resolved paths so no `AbortReason` has to lie about a startup failure, and `decide`'s `Left (Inadmissible …)` turns out to already discriminate the two failures 28-CONTEXT gives opposite policies to — and LOOP-02's chronology lands as `loop_event` unique on `(tx_hash, log_index)` with a watermark that cannot be advanced separately from the rows it covers.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-08-22T22:46:44Z
- **Completed:** 2026-08-22T23:42:02Z
- **Tasks:** 3/3
- **Files modified:** 7 (3 created, 4 modified)

## Commits

| Task | Commit    | Subject                                                                                   |
| ---- | --------- | ----------------------------------------------------------------------------------------- |
| 1    | `c2f465a` | the seam takes resolved paths, and the refusal already tells the two failures apart         |
| 2    | `873204c` | a block's rows and its watermark have no arity that can separate them                       |
| 3    | `8c27802` | six checks for LOOP-02, and the firing input that refuted its own prediction                |

## The numbers, as measured

| Quantity                                     | Before | After  | How                                                     |
| -------------------------------------------- | ------ | ------ | ------------------------------------------------------- |
| `cabal test` total                            | 205    | **211** | run cold before the first edit, and again at the end     |
| `cabal build --enable-tests -j all` warnings  | 0      | **0**   | `grep -cE "Warning\|warning"` over the build log         |
| `^Downloading` lines                          | 0      | **0**   | `grep -c "^Downloading"` over the same log               |
| `purge_file_floor`                            | 72     | **75**  | `find` RUN at both ends, zero slack                      |
| `credential_scan_floor`                       | 83     | **86**  | `find` RUN at both ends, zero slack                      |
| migrations in `expected_migrations`           | 3      | **4**   | `004_loop_ledger.sql`                                    |
| migrations in the committed capture           | 3      | **4**   | capture RE-TAKEN, never hand-edited                      |

Extension census under `offchain/` at the final measurement: **hs 59, sh 12, json 11, sql 4**.
Both floors moved by the SAME three — two `.hs` and one `.sql` — and the `.json` census did **not**
move, because this plan RE-TOOK `store-conformance.json` rather than creating an artifact. Both
`find` commands were run at both ends; neither number was derived from the other.

## What was built

### Task 1 — `Loop.Solve` (`c2f465a`)

`solver_for :: ProverPaths -> IO (Solver, IO (Maybe ToolchainIdentity))` builds the seam from
five already-resolved fields. The module names neither the resolving module (`grep -c` = 0) nor the
eight-refusal renderer (`grep -c` = 0), and adds no package.

**S2's answer is a decision, not a workaround.** The tempting repair is an `AbortReason`
constructor meaning "the binary or the model could not be resolved". It is deliberately NOT added:
an `AbortReason` is written into a ledger row and read by a post-mortem, and "the model file was
not where the process expected it" recorded under the same discriminator as "CONOPT could not reach
an admissible point" is exactly the conflation S3 exists to prevent, arriving from the other end.
Resolution is a startup precondition; a caller that cannot resolve fails before the loop starts.

**The stash exists because `decide` throws the toolchain away.** `decide` matches
`Produced artifact _toolchain _streams`. 28-02's drift ruling (adopt the new identity and continue)
has no other route to that value, and widening `Decision` would change a type five existing checks
assert against by equality. Written on the `Produced` arm only.

`classify :: Either ArgvError Decision -> Classified` returns `Outcome`, a reason, the artifact,
and `cl_halts` — a FIELD, so "which failures halt" is one expression a check can read.

### Task 2 — migration `004`, `Loop.Ledger`, and the re-taken capture (`873204c`)

**Docker was verified BEFORE the migration was written:** `docker info` exit 0, Server Version
29.5.2. That order is the gate, because adding `004` turns
`store_conformance_is_present_and_fresh` red until the capture is re-taken.

`loop_event` is keyed on the POSITION in the chain — `unique (tx_hash, log_index)` — because the
content key is a function of the SHOCK and a shock does not know which log it arrived on. Two
events with identical values are one key and must still be two rows: a chronology that
de-duplicates is a set. `loop_watermark` is one row by two independent guards, and both are
load-bearing: `primary key (only_row)` is what the upsert's conflict target names, and
`check (only_row)` is what forbids a SECOND row carrying `false`, which the primary key alone would
happily admit.

`ledger_commit_block` takes the block AND its rows, in one call and one transaction. There is
deliberately no `insert_row` and no `advance_watermark` on the record: LOOP-05 becomes a property
of the signature rather than a rule about call order.

**The capture was re-taken, not hand-edited.** `bash offchain/rig/capture-store-conformance.sh`
exit 0, `server_version 18.4`, image `postgres:18-alpine`, `sc_complete true`, 8/8 laws,
`generatedAt 2026-08-22T23:02:43Z`. It records `004_loop_ledger.sql` at md5
`ab6f60d921c98dea109cc7e0e6d703b5`, which `md5sum` on the file recomputes exactly, and
`git diff --stat` shows the artifact changed in that commit.

**AND THE STALENESS INSTRUMENT WAS OBSERVED FIRING.** With the pre-004 capture restored from
`HEAD` and nothing else touched, `cabal test` returned **203/205**:

```
FAIL store_conformance_is_present_and_fresh: the repo has a migration the capture never saw: 004_loop_ledger.sql
FAIL sentinel_falsification_harness: the suite was ALREADY failing before a single mutation was applied
```

The baseline was restored and `sha256sum -c` reported `OK`. So the green is the re-take, not a
weakened check.

### Task 3 — the six checks (`8c27802`)

All six run against `Store.Memory` + `new_memory_ledger` + a counting stub `Solver`. No chain, no
database, no solver: the three structural greps still read **0** over `offchain/test/Main.hs` and
their positive controls are inside the green run.

`offchain/lib/Loop` joined `artifact_path_directories` and both modules joined
`aeson_storage_path`, in both directions.

## The firing inputs, every one OBSERVED

| #  | Mutation                                                            | Suite   | Verbatim, from the run                                                                |
| -- | ------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------- |
| M1 | remove the `ledger_seen` guard from `loop_step`                      | 209/211 | `the SAME event replayed was processed again and decided Just OutcomeElided`           |
| M2 | key the memory ledger on the content key                             | 208/211 | `the ledger holds 1 row(s) for the first event and 0 for the second, expected 1 and 1` |
| M3 | flip `cl_halts` on `classify`'s inadmissible arm                     | 209/211 | `classify HALTS the loop on an inadmissible shock`                                     |
| M4 | add a fifth `Outcome` constructor, leave the SQL alone               | 209/211 | `the type has these and the DDL does not: skipped`                                     |
| M5 | delete the unique clause from migration `004`                        | 208/211 | `migration 004 does not constrain the event position to be unique`                     |
| M6 | advance the watermark before the rows are validated                  | 209/211 | `the watermark reads Just 11 after a block that was REFUSED, expected Nothing`         |

Every mutated source was restored from a copy and `sha256sum -c` reported `OK` on all four
baselines after every one of the six.

## Findings

### M1 REFUTED THE PLAN'S OWN PREDICTION, and it is the finding

The plan said removing the `ledger_seen` guard would redden the invocation arm **at 2**.
**MEASURED: it does not.** The counter stays at 1 and the row count stays at 1, because the CONTENT
KEY still hits on the replay and the ledger's first-writer rule still holds. The suite came back
209/211 through the `isNothing second_pass` arm alone.

That sharpens what `ledger_seen` is FOR. It does **not** save a solve — the key already does. What
it saves is the store lookup and the write attempt, and what it protects is the pipeline doing
NOTHING on a replay, which is the only one of the three instruments that can tell the guard is
gone. The `after_both == 1` arm is therefore not falsified by this mutation; it is falsified by a
pipeline that re-solves, which is a different defect. The haddock now says so instead of carrying a
prediction the measurement contradicts.

This is 27-03's M4 shape arriving again: the arm the plan aimed at stayed green and a different one
caught the defect, with a different diagnosis.

### S3 IS NARROWER THAN 27-SUMMARY STATES

The spike recorded that a caller of `decide` cannot tell an inadmissible shock from an unsolvable
one, because `NotPersisted` drops the captured streams and the abort line number (109 vs 171/173)
lives only in a run directory the invocation deletes. That is true of the ABORT PATH and it is not
the whole picture.

**An inadmissible shock never reaches the prover in production.** `render_argv`'s ninth refusal is
applied before any argument vector exists, `content_key` inherits it, and `decide` returns
`Left (Inadmissible …)` before the solver is reachable. So the two failures 28-CONTEXT gives
opposite policies to arrive on two DIFFERENT constructors of `Either ArgvError Decision`, and
`classify` tells them apart with no log, no `CapturedStreams` and no wider `Decision`.

This was MEASURED rather than read off the code: the solver handed to `decide` in
`an_inadmissible_shock_is_told_apart_from_an_unsolvable_one` **throws if it is called**, and it was
not called. The witness is DERIVED — one pip below `min_admissible_dstar` for the fixture's own fee
pair — with both sides of the boundary asserted first, because a pair that admits nothing anywhere
would pass an inadmissibility assertion for the one reason that should fail it.

The abort-line discriminator is still real and still needed, by exactly one consumer: the capture
that drives the eight-refusal renderer on purpose. `Loop.Solve` is not a second one.

### TWO MUTATIONS WERE CAUGHT BY A SECOND, INDEPENDENT GUARD

- **M2** reddened the row-count arm AND the positive control of
  `a_block_commit_is_one_transaction_on_both_ledgers`, which sees the same collapse from the commit
  side.
- **M5** reddened the DDL check AND `store_conformance_is_present_and_fresh`, because editing a
  migration moves its digest. One says the guarantee is gone; the other says the recorded evidence
  no longer describes the schema it was measured against.

### THE PLAN'S TOKEN-COUNT CRITERION IS UNSATISFIABLE BY THE PLAN'S OWN SQL

Task 2's acceptance asks that `grep -c` print **1** for each of the four outcome tokens. It prints
1 for `'elided'`, `'stored'` and `'not_persisted'` and **2** for `'inadmissible'` — and BOTH
occurrences are in the DDL the plan itself prescribes, because
`loop_event_keyed_unless_inadmissible` names the token a second time. What was checked instead is
the stronger statement: `grep -o "'[a-z_]*'"` over the file yields exactly `elided 1, stored 1,
not_persisted 1, inadmissible 2` and no other quoted token. Two PROSE occurrences (of the unique
clause and of `'stored'`) were removed rather than argued about — 27-01's rule that prose inside a
grep's blast radius is moved, never explained away.

### THE PLAN'S VERIFY COMMAND READS THE WRONG KEY

Task 2's `<automated>` block reads `m['name']` out of `store-conformance.json`'s migration entries.
The capture writes `filename`, and `store_conformance_is_present_and_fresh` reads `filename` too.
The command as written raises `KeyError`; it was run against `filename`.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 3 — Blocking] `OverloadedStrings` was missing from `Loop.Ledger`**
- **Found during:** Task 2
- **Issue:** the five SQL statements are `String` without the pragma; the first build failed with
  five `Couldn't match type ‘[Char]’ with ‘Query’` errors.
- **Fix:** added `{-# LANGUAGE OverloadedStrings #-}`, which `Store/Postgres.hs` already carries.
- **Commit:** `873204c`

**2. [Rule 1 — Bug] A redundant `Shock` import warned under `-Wall`**
- **Found during:** Task 1
- **Issue:** the shock reaches `run_prover` through a record field, so the type name is never
  mentioned in a signature; the first build printed one `-Wunused-imports` warning.
- **Fix:** removed the import. Zero warnings is the gate, not "one known warning".
- **Commit:** `c2f465a`

**3. [Rule 2 — Missing critical functionality] The memory ledger's reader could not observe a
re-keying**
- **Found during:** Task 3, writing M2
- **Issue:** `ledger_rows_for` looked the map key up. Under M2 that makes BOTH events unfindable, so
  the check reddens for a reason nobody wrote down instead of by returning one row where two were
  committed.
- **Fix:** `memory_rows_for` now SCANS for rows whose own `lr_event` matches. Equivalent while the
  map is keyed on `lr_event` — and that is the point: a reader that looks up the key it assumes the
  writer used cannot observe the writer keying on something else.
- **Files modified:** `offchain/lib/Loop/Ledger.hs`
- **Commit:** `8c27802` (a task-2 file touched in task 3's commit, with the reason in the message)

**4. [Rule 3 — Blocking] `outcomes` shadowed five long-standing local bindings**
- **Found during:** Task 3
- **Issue:** an unqualified import produced five `-Wname-shadowing` warnings, which is a gate
  failure here.
- **Fix:** reached through `import qualified Loop.Solve as LS`. Same move `Fee.Split` already makes
  in this file and for the same reason.
- **Commit:** `8c27802`

### Departures from the plan's sketch, toward the property the plan asked for

**5. The memory ledger holds ONE `IORef`, not two.** The plan sketched
`IORef (Map …)` plus `IORef (Maybe Integer)` and asked that "a partially-applied commit is not
representable there either". Two refs cannot say that — one of them is already updated when the
other fails. One ref over a record carrying both halves can, and M6 is what observes it.

**6. The memory ledger applies migration 004's row CHECKs and RAISES.** `ledger_row_refusal` states
the DDL's row rule once in Haskell, and the commit applies it to every row BEFORE it mutates
anything. This is 23-04's ruling repeated — TIER B MUST PREDICT TIER C — and it is also what gives
the behavioural arm of check 6 a commit that raises without a hand-injected exception.

**7. `rows_for` RAISES on an unrecognised outcome token** rather than defaulting to one.
`loop_event_outcome_known` makes it unreachable today; a default is what would keep it looking
unreachable on the day the constraint is dropped.

**8. A sixth firing input was added.** The plan names FIVE (`checks 1, 2, 3, 4, 6`) while its
acceptance asks for six. `the_event_identity_and_the_single_row_watermark_are_in_the_ddl` had none;
M5 is it.

**9. Check 5 reads the file instead of shelling out to a scanner.** The plan asks for the file's
existence to be asserted first because the usual instrument exits 1 both for "no match" and for "no
such file". Reading the text designs that conflation out rather than guarding against it, and the
existence arm is still ordered first.

## Authentication gates

None.

## What this leaves for 28-02

- The loop itself: polling, the `--once` mode, the exit-code table, the JSON line per block.
- `detect_toolchain` (S1) — decided in 28-CONTEXT, not implemented here.
- The drift comparison that `solver_for`'s stash exists to feed.
- `new_postgres_ledger` has **no in-suite subject** — `cabal test` is server-free by construction
  and the in-suite subject is the memory implementation. Its structural arm asserts the file names
  `withTransaction`; "it compiles" is the rest of the evidence, and that is recorded here rather
  than left to be discovered. A Tier-C capture driving it belongs with 28-02's.
- LOOP-02 is **not** closed by this plan. Its two directions are asserted against the reference
  implementations through a pipeline the suite composes; the requirement is stated over the loop,
  which 28-02 writes.

## Self-Check: PASSED
