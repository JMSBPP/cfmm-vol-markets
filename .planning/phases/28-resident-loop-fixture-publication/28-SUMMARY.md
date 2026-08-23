---
phase: 28-resident-loop-fixture-publication
kind: phase-summary
status: complete-chain-free-with-the-live-half-blocked
subsystem: offchain-loop
tags: [loop-01, loop-02, loop-03, loop-04, loop-05, watermark, ledger, atomic-rename, shutdown, spike-seams, chain-01-blocked, store-07-partial]
plans: 5
requirements_shipped: [LOOP-01, LOOP-02, LOOP-03, LOOP-04, LOOP-05]
requirements_blocked_live_half: [LOOP-01, LOOP-02, LOOP-03, LOOP-04, LOOP-05]
requirements_partial: [STORE-07]
completed: 2026-08-23
---

# Phase 28 — The Resident Loop & Fixture Publication: phase summary

All five LOOP requirements are retired **for their chain-free halves**, all three spike seams are
closed in the library, and **the live end-to-end run is BLOCKED BY NAME on two external tracks and
has never happened**. The loop polls from a watermark that is a row in the store, records every
outcome as a chronology, publishes exactly one file by atomic rename, refuses a publication
directory it did not create, and observes a shutdown only at a block boundary.

`cabal test` went **205/205 → 232/232**, exit 0, zero warnings, and it still reaches no chain, no
database and no solver — the three structural greps, each with a positive control, were green at
every one of the five closes.

---

## Requirement disposition

| | Chain-free half | Live half | Where |
|---|---|---|---|
| **LOOP-01** | ✅ Complete | ⛔ **BLOCKED** | 28-02 |
| **LOOP-02** | ✅ Complete | ⛔ **BLOCKED** | 28-01 + 28-05 |
| **LOOP-03** | ✅ Complete | ⛔ **BLOCKED** | 28-03 |
| **LOOP-04** | ✅ Complete | ⛔ **BLOCKED** | 28-04 |
| **LOOP-05** | ✅ Complete | ⛔ **BLOCKED** | 28-05 |
| **STORE-07** | 🟡 **PARTIAL BY CONSTRUCTION — and still DEFERRED** | — | 28-01 |

**Four of the five were carried into this phase marked *Blocked*, and the attribution was INHERITED
rather than measured every time** — LOOP-01 at 28-02, LOOP-03 at 28-03, LOOP-04 at 28-04, LOOP-05 at
28-05. The status came from CHAIN-01's row, not from anyone asking what each requirement is actually
about. LOOP-01 is about the WATERMARK and the RESUME; LOOP-03 about the ATOMIC WRITE and the SHAPE;
LOOP-04 about a TREE DIFF; LOOP-05 about the shutdown and the commit boundary. **None of the four
needs a chain.** Phase 27 made the identical correction for CHAIN-02/03 and wrote in its own summary
that it is "the kind of inheritance that costs a phase". It cost this one four more instances.

---

## The two blocks, by name, with what would discharge them

### CHAIN-01 — the `Shock` emitter. Plank / mev-migrate workstream, **GitHub issue #26**.

`SELECTOR_NEXT 0xd3827b0b` is a FUNCTION SELECTOR on `AlgebraIntegralShocksWriterInterface.plk` and
has never been an event. The event is `Shock(address indexed pool, int24, uint24, uint24)`, topic0
`0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64`, and it is emitted from a forge
**TEST**, not from a deployable contract another process can drive —
`foundry-scripts/mev_tax_model_one/` holds only `DeployAlgebraFactory.s.sol`.

**WHAT WOULD DISCHARGE IT:** one driver emitting a single `Shock` in a MINED transaction on the
resolved endpoint. Nothing more. **Not this workstream's to build**, and it was not built here.

### LOOP-04's directory — `mev_tax_model_one` track, **GitHub issues #24 and #25**.

`test/models/mev_tax_model_one/fixtures/` is absent from this worktree AND from `origin/develop`.
MEASURED at 28-04, in both directions:

```
$ git ls-tree -r --name-only origin/develop | grep -c "^test/models/mev_tax_model_one/fixtures"
0
$ find test -path "*mev_tax_model_one*"
(nothing)
```

The loop REFUSES to create it and so does the capture. `the_fixtures_directory_is_recorded_absent_from_both_trees`
is the standing record and it goes RED the day the directory lands — at which point LOOP-04 must be
re-stated against the real tree and that check RETIRED rather than weakened.

### What both blocks stop: `offchain/rig/capture-loop.sh`, and it is UNRUN

The live Tier-C run is written, listed in `Chain.Endpoint.endpoint_sites` as a `ShellConsumer`, gated
exactly as Phase 27 gated its two captures — resolve through `offchain/rig/endpoint.sh`, refuse
loudly and BY NUMBER, never skip — and **it has never been executed**. Its artifact,
`offchain/rig/loop-conformance.json`, is deliberately ABSENT, and the suite asserts that absence:
`the_live_loop_capture_is_present_and_names_its_block` passes while the artifact does not exist and
FAILS on the day it appears, with failure text saying what each direction means. That inversion is
the only form in which "this evidence does not exist yet" can itself be evidence.

**The gate was exercised at the phase close, with no rig stood up and nothing written:**

```
CAPTURE FAIL: nothing answered eth_blockNumber at http://127.0.0.1:8545.
              This is NOT a skip. ... Stand the rig up first: bash offchain/rig/deploy-rig.sh
EXIT=1
```

---

## STORE-07 is PARTIAL BY CONSTRUCTION, and it is NOT closed

Migration `004_loop_ledger.sql` creates `loop_event`, carrying three of STORE-07's four fields
(`key`, `tx_hash`+`log_index`, `block`) plus `observed_at`, unique on `(tx_hash, log_index)`, with
every outcome recorded — `elided`, `stored`, `not_persisted`, `inadmissible`.

**What is ABSENT is the append-only ENFORCEMENT.** There is no trigger, and nothing in this
repository forbids an `update` or a `delete` on a `loop_event` row. Nothing issues one either —
`insert_event_sql` ends `on conflict … do nothing`, and the memory reference implementation applies
the same rule — but "nobody does it" is a fact about today's callers and "the server refuses it" is a
fact about the schema, and STORE-07 asks for the second. The gap is stated in migration `004`'s own
header. **A row saying STORE-07 is closed because a table exists would be the
assertion-without-an-implementing-task shape this milestone keeps finding.** The trigger hardening
stays deferred with STORE-02..05.

---

## The three spike seams, and what each turned out to be

From `.planning/SPIKE-end-to-end.md`, restated by 27-SUMMARY as binding on this phase.

### S1 — a `KeyIdentity` could only be obtained from a COMPLETED RUN. **Closed in the library (28-02).**

`Gams.Detect.detect_toolchain` writes a five-line hermetic NLP — verbatim from
`capture-gams-conformance.sh:157-163` — into a fresh exclusive directory, runs the binary on it, and
hands the output to a pure parser. The directory is removed on every exit path.

**"Version-only" means no production model and no production SOLVE, not no process, and both halves
are MEASURED and already committed rather than argued:** `gams --version` is parsed as an input
FILENAME, exits 6, and its banner is refused `Left (WrongJob "--version")` by the very parser this
module reuses; CONOPT states its own version only in the output of a run that reaches the solver.
`gams-conformance.json` records both. `ti_model_sources` carries the PRODUCTION model's digest and
never the probe's — a probe that leaked into the identity would key every stored row to a throwaway
file.

The identity is probed once and pinned for the process lifetime. **The drift ruling, as implemented:**
`Loop.Run.adopt_identity` is 28-CONTEXT's user ruling as a PURE function — a completed run reporting a
different toolchain returns the NEW identity plus a note naming both, and the loop continues. It does
not halt. What makes that safe is the ledger rather than the function: every row carries the versions
that KEYED it, so the switch is reconstructible from rows that were already being written. Two
returns are the same value with different reasons and they are kept apart in the note — a reported
identity that cannot become a `KeyIdentity` is NOT adopted, and saying so out loud is what stops an
unusable toolchain from looking like an unchanged one.

### S2 — `invoke_shock` did not fit the `Solver` seam. **Closed by MOVING resolution out (28-01).**

The tempting repair — an `AbortReason` constructor meaning "the binary or the model could not be
resolved" — was deliberately NOT added. An `AbortReason` is written into a ledger row and read by a
post-mortem, and "the model file was not where the process expected it" recorded under the same
discriminator as "CONOPT could not reach an admissible point" is exactly the conflation S3 exists to
prevent, arriving from the other end. `Loop.Solve.solver_for` takes already-resolved paths;
resolution is a STARTUP precondition of the caller, reported as `Loop.Config.Precondition`. The
structural property is the DIRECTORY: every importer of the resolving module is under
`offchain/app/`, and `grep -rc` over `offchain/lib/Loop/` reports 0 for every file there.

### S3 — `Decision` dropped the discriminator. **NARROWER THAN 27-SUMMARY STATED, and it was MEASURED (28-01).**

The spike recorded that a caller of `decide` cannot tell an inadmissible shock (abort line 109) from
an unsolvable one (171/173), because `NotPersisted` drops the streams and the line number lives only
in a run directory `Gams.Run` deletes. **That is true of the ABORT PATH and it is not the whole
picture.** An inadmissible shock never reaches the prover in production: `render_argv`'s ninth
refusal is applied before any argument vector exists, `content_key` inherits it, and `decide` returns
`Left (Inadmissible …)` **before the solver is reachable**. So the two failures 28-CONTEXT gives
OPPOSITE policies to already arrive on two DIFFERENT constructors of `Either ArgvError Decision`, and
`Loop.Solve.classify` tells them apart with no log, no `CapturedStreams` and no wider `Decision`.

Measured rather than read off the code: the solver handed to `decide` in
`an_inadmissible_shock_is_told_apart_from_an_unsolvable_one` **throws if it is called**, and it was
not called. The witness is DERIVED — one pip below `min_admissible_dstar` for the fixture's own fee
pair — with both sides of the boundary asserted first.

**The abort-line discriminator is still real and still needed, by exactly one consumer:** the capture
that drives the eight-refusal renderer on purpose. `Loop.Solve` is not a second one.

---

## What each plan shipped

### 28-01 — the seams and the per-event ledger (`c2f465a`, `873204c`, `8c27802`) · **205 → 211**

`Loop.Solve` (S2 and S3), `Loop.Ledger` with a one-call/one-transaction block commit on memory and on
postgres, migration `004_loop_ledger.sql`, a re-taken `store-conformance.json` naming four
migrations, and six checks.

`loop_event` is keyed on the POSITION in the chain — `unique (tx_hash, log_index)` — because the
content key is a function of the SHOCK and a shock does not know which log it arrived on. Two events
with identical values are one key and must still be two rows. `loop_watermark` is one row by two
independent guards and **both are load-bearing**: `primary key (only_row)` is what the upsert's
conflict target names, and `check (only_row)` forbids a SECOND row carrying `false`, which the
primary key alone would happily admit. `ledger_commit_block` takes the block AND its rows, so LOOP-05
is a property of the SIGNATURE rather than a rule about call order.

**Docker was verified BEFORE the migration was written** (`docker info` exit 0, Server 29.5.2),
because adding `004` turns the freshness oracle red — and the oracle was OBSERVED firing at 203/205
with the pre-004 capture restored, then restored under `sha256sum -c`.

### 28-02 — startup identity, the poll, the persisted watermark (`153460d`, `631cf31`, `3ab9d7e`) · **211 → 219**

`Gams.Detect` (S1), `Loop.Config`, `Loop.Poll`, `Loop.Chain`, `Loop.Run`, `offchain/app/LoopMain.hs`,
the `executable loop` stanza, and eight checks.

**LOOP-01 is proven the only way it can be.** The watermark is a ROW IN THE STORE and `run_loop`
re-reads it from the ledger on every pass, so nothing in-process can report a restart-safe watermark
while holding an in-process one. The check drains a head of 5, then — WITH NO LOOP RUNNING — adds
events at blocks 6 and 7 and raises the head to 8, then builds a SECOND `Env` over the SAME store and
ledger, which is what a restart is here. The down-time events are asserted to EXIST in the source
FIRST, and the EARLY events are counted AGAIN at the end — a restart that re-scanned from the
beginning also lands the down-time rows, and only the second count tells the two apart.

Ranges are CLOSED `[b, b]`, asserted on the CALLS the iteration made (`[(0,0),(1,1),(2,2),(3,3),(4,4)]`)
rather than on the function that computes them. A quiet block still advances the watermark.

### 28-03 — publication, the atomic write and the shape floor (`ed9f483`, `dc96987`) · **219 → 224**

`Driver.Capture.write_bytes_atomically` and `write_atomically` — **the ONE rename in this
repository** — `Loop.Publish`, `Loop.Config`'s publication target, `Loop.Run.publish_for`, and five
checks.

**The race, measured on BOTH arms by the same reader against the same two documents,** with the
harness parameterised by the WRITER so the arms differ in exactly one expression:

| Arm | Publications | Completed reads | Unparseable |
|---|---:|---:|---:|
| `publish_fixture` (temp sibling + rename) | 142,623 | 204,555 | **0** |
| no temp file, no rename | 6,079 | 1,333,592 | **1,240,687 (93.0%)** |

Both checks order the "did the race actually run" arm FIRST. Every read is classified by
`Store.Json.is_json_value` PLUS a `decode_artifact`, because a tear between two documents of
different lengths can leave valid JSON that is not a valid artifact.

**A cache HIT still publishes**, stamped with the EVENT's block, with the artifact bytes
byte-identical to the first publication's. The splice is TEXTUAL and byte-identity is asserted
against the committed golden, never against a re-serialisation of it.

### 28-04 — exactly one file, and a directory this loop will not invent (`31d4d37`, `e73693e`, `e45b3b6`) · **224 → 228**

`Loop.Publish.publish_precondition` and its message, `LoopMain`'s startup refusal at exit 40, and four
checks.

Publication was OBSERVED adding **exactly one file** to a directory holding two decoys, with a third
in the PARENT: `added = ["volume_path.json"]`, `removed = []`, the decoys' **BYTES** unchanged (read
back, not merely their names), no `*.tmp` surviving, and the parent gaining only
`fixtures/volume_path.json` — across TWO publications of different bytes (264 and 296), because a
temp sibling that survives the first write is invisible until the second collides with it. The
"before-set is non-empty" arm is ordered FIRST.

`default_fixture_path` is pinned BYTE-EQUAL to the consumer's own `VOLUME_PATH_JSON`, read live out
of `origin/develop` through `git show`, with the extraction asserted to have found exactly ONE
non-empty literal FIRST. 28-03 could only compare the default against `default_fixture_dir </>
fixture_file_name` — a join, which is this side agreeing with itself.

### 28-05 — crash consistency, the shutdown, the gated capture, the close (`63e0c84`, `478845d`, `e2b801d`) · **228 → 232**

`Loop.Run.env_interrupted` read at two points and both between blocks; `LoopMain`'s SIGINT/SIGTERM
handler that writes one `Bool` and does nothing else; the wrapper around the iteration and
`HaltBlockException` / exit 34; `offchain/rig/capture-loop.sh`; and four checks.

An exception was injected at SEVEN stages and every abandoned block left the watermark exactly where
it was, no row for the event, and a block a clean pass re-processed under the SAME content key. The
shutdown was OBSERVED landing block 2 whole — both rows and its watermark together — with block 3
never entered. Detail, including the two stages whose disposition differs BY DESIGN, in
`28-05-SUMMARY.md`.

---

## Measured totals at phase close

| | Value | How |
|---|---|---|
| `cabal build --enable-tests -j all` | exit **0**, **0** warnings, **0** `Downloading` | run at close, exit code captured SEPARATELY |
| `cabal test` | exit **0**, **232/232**, **0** FAIL lines | run at close |
| Suite at phase start | 205/205 | 27-03's close |
| Delta across the phase | **+27** (6 + 8 + 5 + 4 + 4) | |
| Wall, full suite | **551 s** against a 900 s ceiling | `date` around the binary |
| `purge_file_floor` | **83**, zero slack | `find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f \| wc -l` → **83** |
| `credential_scan_floor` | **94**, zero slack | same `find` plus `-o -name '*.json'` → **94** |
| Census under `offchain/` | hs **66**, sh **13**, json **11**, sql **4** | RUN at close |
| `endpoint_sites` | **20** entries | counted on disk at close |
| `exit_table` | **10** non-zero entries | counted on disk at close |
| Migrations | **4** (`004_loop_ledger.sql`) | manifest and capture agree |
| Structural greps at 0 | **three** — DB-free, GAMS-free, chain-free, each with a positive control | in-suite |
| Territory | **empty** | `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` |

### The suite's wall clock, plan by plan

| Plan | Checks | Wall | Note |
|---|---:|---:|---|
| start | 205 | ~195 s | 27's close |
| 28-01 | 211 | — | |
| 28-02 | 219 | — | |
| 28-03 | 224 | **528 s** | the two ten-second races cost 342 s |
| 28-04 | 228 | 534 s | four checks cost 1–2 s |
| 28-05 | 232 | **551 s** | four checks cost 17 s |

**28-03's multiply-by-fifteen rule is the phase's most reusable number.** The plan predicted
`173 s → ~195 s` on the arithmetic that two ten-second harnesses run once each. They do not:
`sentinel_falsification_harness` re-runs `core_checks` about fifteen times — once per swept artifact
through `all_objections`, once for its own baseline, and once per negative control through
`first_objection`, which cannot short-circuit because their whole point is that nothing objects.
**MEASURED at both ends: 186 s without the races, 528 s with them.** 28-04 and 28-05 applied the rule
BEFORE writing anything and between them cost 23 seconds.

### The exit-code table, as it stands

| Code | Name | Family |
|---:|---|---|
| 0 | clean drain, or the requested pass completed | — |
| 30 | `halt_unsolvable` | halt |
| 31 | `halt_rpc_exhausted` | halt |
| 32 | `halt_db` | halt |
| 33 | `halt_solver_exception` | halt |
| 34 | `halt_block_exception` *(28-05)* | halt |
| 40 | `precondition_fixture_dir` | precondition |
| 41 | `precondition_toolchain` | precondition |
| 42 | `precondition_endpoint` | precondition |
| 43 | `precondition_prover_paths` | precondition |
| 44 | `precondition_ledger` | precondition |
| 64 | usage — deliberately OUTSIDE the table | — |

Thirty-something is the halting family (the loop ran and stopped); forty-something is the
precondition family (the loop never started), so an operator can read the first digit and know
whether anything was processed. The whole domain is asserted DISJOINT from
`Gams.Exit.gams_code_domain` (`[0..11] ++ [109..115] ++ [141,144,145,146]`) and from the timeout
wrapper's `[124, 137]` — against those lists themselves, never against a transcription. `Loop.Config`
states none of the colliding numerals: `grep -cE "\b(11|124|137|145)\b"` over it prints **0**.

---

## Every firing input this phase drove

Twenty-eight drives across five plans. Every mutated source was restored from a copy and
**`sha256sum -c` reported `OK` on every baseline after every one**, including the one that was
abandoned.

| Plan | # | Mutation | Suite | Verbatim / result |
|---|---|---|---:|---|
| 28-01 | M1 | remove the `ledger_seen` guard from `loop_step` | 209/211 | *"the SAME event replayed was processed again and decided Just OutcomeElided"* — **and it REFUTED the plan's own prediction** |
| 28-01 | M2 | key the memory ledger on the content key | 208/211 | *"the ledger holds 1 row(s) for the first event and 0 for the second, expected 1 and 1"* — caught by a SECOND guard too |
| 28-01 | M3 | flip `cl_halts` on the inadmissible arm | 209/211 | *"classify HALTS the loop on an inadmissible shock"* |
| 28-01 | M4 | add a fifth `Outcome`, leave the SQL alone | 209/211 | *"the type has these and the DDL does not: skipped"* |
| 28-01 | M5 | delete the unique clause from migration `004` | 208/211 | *"migration 004 does not constrain the event position to be unique"* — caught by a SECOND guard too |
| 28-01 | M6 | advance the watermark before the rows are validated | 209/211 | *"the watermark reads Just 11 after a block that was REFUSED, expected Nothing"* |
| 28-02 | M1 | the stub echoes the recorded `--version` banner | 211/213 | *"detect_toolchain refused a stub that printed a well-formed probe output and exited 0"* |
| 28-02 | M2 | `next_range` starts from the head when a watermark is present | 216/219 | *"THE EVENTS THAT OCCURRED WHILE THE LOOP WAS DOWN WERE SKIPPED. Row counts [0,0] for the events at blocks [6,7]"* |
| 28-02 | M3 | advance the watermark only on event-bearing blocks | 216/219 | *"the watermark reads Just 9, expected Just 12"* — caught by a SECOND guard too |
| 28-02 | M4 | ask the source for the whole window in one call | 217/219 | *"the run asked the source for [(0,1),(1,2),(2,3),(3,4),(4,5)]"* |
| 28-02 | M5 | the missing-index refusal names the tx-hash field | 217/219 | *"a log with no changeLogIndex was refused, but the refusal does not name that field"* |
| 28-02 | M6 | an unreadable poll value falls back to the default | 216/219 | *"LOOP_POLL_MS was set to \"soon\" and the loop resolved a cadence of 1000 milliseconds anyway"* — caught by a SECOND guard too |
| 28-03 | M1 | point the race's publisher at the torn writer | 219/224 | *"A CONSUMER RACING THE PUBLISHER READ A TORN FIXTURE. 1223305 bad read(s) out of 1326222 completed"* — **and left the control GREEN** |
| 28-03 | M2 | fold the zero-pool arm into the shape arm | 223/224 | *"a ZERO pool was answered with Left (PoolIsNotAnAddressToken …)"* |
| 28-03 | M3 | re-render the artifact through a `Double` carrier | 220/224 | *"the decimal digit string of dQx[0] -- -2613128317657530400 -- does not occur in the published bytes"* — reddened **three** structural guards as well |
| 28-03 | M4 | skip publication on `OutcomeElided` | 223/224 | *"THE CACHE HIT DID NOT PUBLISH."* |
| 28-03 | M5 | `fixture_min_bytes = 700`, above the 606-byte golden | 218/224 | *"A floor at or above every real artifact refuses everything"* — reddened **six** |
| 28-04 | M1 | temp file → `getTemporaryDirectory`, destination on `tmpfs` | **228/228** | **NOT CAUGHT — the plan's prediction REFUTED** |
| 28-04 | M1b | the same, destination on the repository's `ext4` | 226/228 | *"unsupported operation (Invalid cross-device link)"* |
| 28-04 | M2 | `publish_precondition` creates the directory and still refuses | 226/228 | *"after publish_precondition refused …/fixtures, something IS there: a directory."* |
| 28-04 | M3 | one character out of `default_fixture_dir` | 225/228 | both strings named; caught by **TWO** checks with different diagnoses |
| 28-04 | M4 | `mkdir -p` the real fixtures directory | 226/228 | *"THIS WORKTREE now carries test/models/mev_tax_model_one/fixtures as a directory."* |
| 28-05 | M1 | hoist the commit ahead of the event loop | 228/231 | *"STAGE seen: THE WATERMARK READS Just 0 … must be UNCHANGED at Nothing"* — caught by **TWO** checks |
| 28-05 | M2 | read the interrupt flag between EVENTS | 229/231 | *"Row counts by block: [(1,1),(2,0),(2,0),(3,0)]"* |
| 28-05 | M3a | rename → copy, temp survives | — | **ABANDONED at 52 minutes of CPU** — see below |
| 28-05 | M3b | keep the rename, re-fill the temp file after it | 228/231 | *"a temp sibling SURVIVED the interrupted publication"* — caught by **TWO** checks |

---

## The pattern this phase kept meeting

**A prediction written by a planner, refuted by the measurement, and the HADDOCK corrected rather
than the check.** Seven instances, in four of the five plans:

| Plan | The prediction | What was measured |
|---|---|---|
| 28-01 | dropping `ledger_seen` costs a second solve | It does not. The content key still elides it. The guard saves the store LOOKUP and the write attempt, not the solve. |
| 28-03 | the 150-byte truncation is `BelowShapeFloor` | It is `ArtifactUnparseable` — a prefix of the golden stops being JSON long before it gets small. The floor's real subject is a CONSTRUCTED valid-but-tiny artifact. |
| 28-03 | an aeson `Value` round trip loses the `dQx[0]` digits | It does not — `Scientific` is exact. It reddens the BYTE arm instead. The carrier BYTE-04 measured is `Double`, never "a JSON value type". |
| 28-03 | two ten-second races cost the suite ~22 s | They cost **342 s**. The sweep re-runs `core_checks` about fifteen times. |
| 28-04 | a non-sibling temp file reddens the "nothing outside" arm | **228/228, NOT CAUGHT.** A before/after tree diff cannot see where a temp file lived. Re-driven across a device boundary it reddens through the FIRST arm — and corrected a `Driver.Capture` haddock that had been wrong since Phase 22. |
| 28-05 | moving the commit ahead of the publish stage reddens the publish arm | It distinguishes nothing: the commit is already after publication and a publish exception is already swallowed. The stronger mutation — hoist the commit above the EVENT LOOP — reddens six stages at once. |
| 28-05 | writing the destination directly reddens the parse arm | 28-04 already measured that an after-the-fact observer cannot see this. The arm's real subject is a SURVIVING sibling. |

**And its twin: an acceptance criterion the plan's own prescribed prose makes unsatisfiable.** Four
instances — 28-02's two colliding exit numerals and its anchored `detect_toolchain` grep, 28-04's
`createDirectory` count, 28-05's `ledger_commit_block` count. The answer was the same every time, and
it is 27-01's: **THE PROSE MOVES, the pattern does not.** 28-05's is the thirtieth instance on this
branch and the first in which the offending prose PREDATED the plan being executed.

---

## Carried forward

### Blocked, by name, on other tracks

- **`offchain/rig/capture-loop.sh` has never run.** Issue **#26** (the `Shock` emitter) and issues
  **#24/#25** (the publication directory). Both external. The suite records the absence as a verdict
  and its failure text says what to do the day it changes.
- **`test/models/mev_tax_model_one/fixtures/` is on neither tree.** Every publication proof in this
  phase runs against a temporary directory.

### Measured and not fixed — the full list is `deferred-items.md`

- **A real `SIGINT` was never delivered.** The suite drives the FLAG; the handler is in the
  executable, which stops at the chain-surface precondition.
- **`HaltRpcExhausted` reports one attempt, always.** 28-CONTEXT rules bounded retry with backoff;
  four plans have not wired it.
- **The loop never re-reads what it published.** `br_published` means the write returned.
- **The sentinel harness multiplies every check by ~15, and a firing input that reddens an expensive
  check cannot be driven here** — 28-05 observed 52 minutes of CPU without completion and re-aimed
  the mutation surgically.
- **`capture-loop.sh`'s one `cast send` line is UNCONFIRMED**, and labelled so in its own comment:
  the emitter's entry point cannot be read off anything that exists.
- **`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock` are still untracked.** Flagged by
  Phase 27, re-flagged by 28-02, untouched by every plan here. `CHANGELOG.md` is named by the cabal
  file's `extra-doc-files`, so an `sdist` from a clean checkout would fail on it.
- **`chain-read-conformance.json` is not in the sentinel sweep** and has an override (27's carry).
- **`endpoint.sh` is not exercised by `cabal test`** — it is bash, and putting it under the gate is a
  Tier decision nobody has made (27's carry).
- **`new_postgres_ledger` has NO in-suite subject.** `cabal test` is server-free by construction; the
  in-suite subject is the memory implementation and "it compiles" is the rest of the evidence. A
  Tier-C capture driving it is what `capture-loop.sh` would be, if it could run.

### Tooling

- **`roadmap update-plan-progress 28` writes `6/5`**, because it counts the phase-level
  `28-SUMMARY.md` in the phase directory as a plan. Phase 27 recorded `4/3` for the same reason.
  Corrected by hand; it will need correcting again after any re-run.
- **`gsd-tools state …` and `phase complete` were NOT run**, per the standing warning in `STATE.md`'s
  own frontmatter comment. Four subcommands have been observed rewriting it — milestone reverting to
  `v2.0`, counters replaced by machine-wide totals — most recently at the Phase 27 close. Every
  document in this close was edited by hand and the frontmatter verified intact afterwards.

---

## Commits

| Plan | SHA | Subject |
|---|---|---|
| 28-01 | `c2f465a` | the seam takes resolved paths, and the refusal already tells the two failures apart |
| 28-01 | `873204c` | a block's rows and its watermark have no arity that can separate them |
| 28-01 | `8c27802` | six checks for LOOP-02, and the firing input that refuted its own prediction |
| 28-01 | `a90014b` | complete the loop-seams-and-ledger plan |
| 28-02 | `153460d` | an identity before the first solve, and the probe that pays for it |
| 28-02 | `631cf31` | one iteration function, closed ranges, and an exit table complete on day one |
| 28-02 | `3ab9d7e` | LOOP-01, proven with events that occurred while the loop was down |
| 28-02 | `dc85809` | complete the startup-identity-and-watermark plan |
| 28-03 | `ed9f483` | one rename in the tree, and a publish that refuses on five named shapes |
| 28-03 | `dc96987` | the ten-second race, and the torn read OBSERVED at nine reads in ten |
| 28-04 | `31d4d37` | a directory this loop will not invent, refused before the first block |
| 28-04 | `e73693e` | one file proven by a tree diff, and a block reported as a verdict |
| 28-04 | `e45b3b6` | the sibling rule, measured — and three phases of prose corrected |
| 28-04 | `572ec0e` | complete the exactly-one-file plan |
| 28-05 | `63e0c84` | a shutdown read between blocks, and an exception at every stage |
| 28-05 | `478845d` | the live capture, written and gated and recorded as blocked |
| 28-05 | `e2b801d` | LOOP-02's second direction, asserted over the loop |
