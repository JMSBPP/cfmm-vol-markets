---
phase: 23-postgres-foundation-byte-exact-schema
plan: 03
subsystem: database
tags: [schema, migrations, bytea, jsonb, advisory-lock, postgresql-simple, postgresql-migration, purge]

# Dependency graph
requires:
  - "23-01: Store.Types (Artifact, KeyScheme, StoredRun, derived_doc_from_text, derived_doc_sha256), Store.Class (the Store record), Store.Config (migrations_dir)"
  - "23-02: Store.Laws (the seven laws the Postgres store must satisfy), aeson_is_absent_from_the_storage_path (RED on this plan's own file until it landed)"
provides:
  - "offchain/migrations/001_model_run.sql — model_run with the KEY-07 identity constraint over all three of (model, key_scheme, key), the derived jsonb doc column and the path-ops GIN index"
  - "offchain/migrations/002_byte_corpus.sql — the byte-fidelity fixture, a separate table because the corpus is neither valid UTF-8 nor valid JSON"
  - "Store.Schema — expected_migrations (ordered, gapless), identity_constraint_name, identity_constraint_columns; PURE"
  - "Store.Postgres — the sole database-client importer: Binary-only writes, doc derived from the same parameter as raw in one statement, pg_advisory_lock(872304), a runner that calls exitFailure, server_version, live_identity_constraint_columns"
  - "migration_list_is_ordered_and_gapless — the migration surface as a SET in BOTH directions, over the directory's WHOLE contents"
  - "unique_constraint_names_all_three_columns — the Haskell constant AND the DDL text of the file Postgres is handed"
  - "sc3_literal_purge extended to .sql, PROVEN scanned rather than merely declared"
affects: [23-04 conformance capture, 23-05 checks, 25 content key]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The conflict target and the catalogue lookup both derive from ONE exported constant, so a schema rename cannot leave the insert conflicting on a constraint that no longer exists"
    - "A directory whose WHOLE contents are asserted against a manifest, because the migration library applies every entry it finds with no extension filter"
    - "An anti-control that separates DECLARED from SCANNED: with the extension in the known list but not the scanned list, a seeded literal in that file type is invisible to the purge"

key-files:
  created:
    - offchain/migrations/001_model_run.sql
    - offchain/migrations/002_byte_corpus.sql
    - offchain/lib/Store/Schema.hs
    - offchain/lib/Store/Postgres.hs
  modified:
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "execute/execute_ THROW on a statement that returns columns, so the plan's and the research's prescribed `execute_ con \"select pg_advisory_lock(872304)\"` compiles and then throws at the first acquisition; both lock statements go through query"
  - "On checksum drift through runMigrations the payload is the SCRIPT NAME, not the string 'Checksum mismatch' — that wording belongs to the separate MigrationValidation path"
  - "The migration-set check asserts the directory's whole contents, not only its .sql, because postgresql-migration applies every entry with no extension filter — this also keeps the `\".sql\"` literal count at exactly 2"
  - "The lock key is one exported constant passed as a parameter, and the conflict target derives from identity_constraint_name — both deviate from the plan's acceptance greps and both remove a drift surface"
  - "model_run.doc is NOT NULL jsonb, so the keyed path requires valid JSON — and law_first_writer_wins_on_the_identity_triple's second put is not JSON. Recorded, not papered over; 23-04 must rule"

requirements-completed: []
requirements-partial: [DB-01, KEY-07, BYTE-01, BYTE-02, BYTE-03]

# Metrics
duration: 44min
completed: 2026-08-16
---

# Phase 23 Plan 03: The Schema, the Migrations and Store.Postgres Summary

**The suite is GREEN — 98/98, FAIL count 0 — because `Store/Postgres.hs` now exists and is
correct: the only database-client importer in the tree, every `bytea` parameter `Binary`-wrapped,
`doc` derived from the same parameter as `raw` in one statement, an advisory lock the library does
not provide and an `exitFailure` the library does not perform; and `.sql` joined
`sc3_literal_purge`'s scanned set with the scan PROVEN to read it and an anti-control proving that
declaring it would not have been enough.**

## Performance

- **Duration:** 44 min
- **Started:** 2026-08-16T15:14:00Z
- **Completed:** 2026-08-16T15:58:00Z
- **Tasks:** 2 (plus two follow-up commits: the end-of-plan floor re-measurement and the
  self-check's finding)
- **Files modified:** 6 (4 created, 2 modified)

## MEASURED VALUES (the output block this plan owes)

### Check counts, and the arithmetic against 23-02

Every number from the BUILT TEST BINARY, per 23-02's finding that `cabal test` buffers the runner's
stdout and does not reliably surface the count.

```
COLD BASELINE, re-measured at the start of this plan (NOT inherited)
  94/96 checks passed,  2 FAILED: aeson_is_absent_from_the_storage_path,
                                  sentinel_falsification_harness

AFTER TASK 1 (two checks registered; the .sql files land)
  96/98 checks passed   ->  BASELINE + EXACTLY 2, the same two reds
  2 FAIL lines

AFTER TASK 2 (Store/Postgres.hs lands; no check registered)
  98/98 checks passed   ->  0 FAIL lines. BOTH transient reds CLOSED.
  cabal test            ->  exit 0, "1 of 1 test suites passed"
```

98 = 23-02's total of 96 + exactly the 2 checks task 1 added. This matches 23-02's anti-control C2
prediction to the check (it measured 96/96 with a clean stub on disk; this plan adds 2 and lands
98/98).

`cabal build --enable-tests -j all` exited 0 with **0** lines matching
`^offchain/[^ ]*:[0-9]+:[0-9]+: warning:` after every task and after every probe. **The bare
`cabal build -j all` is VACUOUS and was never run.**

### The purge collision — the floor was RE-MEASURED, and the inherited number was already stale

```
                                                    BEFORE      AFTER
find offchain -name '*.sql' | wc -l                    0           2
find offchain \( -name '*.hs' -o -name '*.sh' \)      41          --      (scanned set, old scope)
find offchain \( ... -o -name '*.sql' \)              41          45      (scanned set, new scope)
purge_file_floor                                      36          45
```

**The research's and the plan's "36 against exactly 36 scanned files, ZERO SLACK" was STALE at
execution time.** Waves 1 and 2 added five `.hs` files, so the scan was already at **41** and the
recorded zero slack had silently become five. Nothing was wrong with the check — the floor is a
`>=` floor and 41 ≥ 36 — but the *claim* that any `.sql` addition would immediately redden the
floor was no longer true. Only the extension census would have fired. This is precisely why the
plan says re-measure and do not copy, and it is the reason the number is now written with the rule
that governs it rather than as a bare integer.

The floor was measured **three times** and was wrong twice:

1. **44** — taken from the census run *before* task 1's own new library module was written. One
   low. A `>=` floor accepts that in silence.
2. **44 (correct at that commit)** — 35 Haskell + 7 shell + 2 SQL.
3. **45** — task 2 added `Store/Postgres.hs`, so 36 + 7 + 2. Committed separately (`3995d4e`) with
   the rule recorded: re-measure when the purge's SCOPE changes or when a plan is already editing
   the block, not on every added `.hs`.

Extension census under `offchain/` before the change: `hs 34, json 6, md 3, sh 7, txt 2`.

### Digests of the files that were mutated and restored

Compared by **diffing digest files**, never by asserting. Every `diff` was EMPTY.

```
offchain/migrations/001_model_run.sql   12adb51f8250af9502346d34fca28f237147c4e9e44f59a324c858fb7c5160e5
offchain/migrations/002_byte_corpus.sql 998c01dc73e302cabab8636ce676c8bffc38216c3c33a738ad1f1a6e106e5ea1
offchain/lib/Store/Schema.hs            8df4200daf5b1dd141a4f2f2ffb714508ea061627265842467ed71ad78159597
offchain/lib/Store/Postgres.hs          14d07790e358e686de42758014e068c4c1efcfb3a8c4b2f22d21bdb25b58cc82
offchain/test/Main.hs                   restored identical across the two-edit anti-control window
```

`git checkout --` was NOT used anywhere. Every restore came from a saved copy in the scratch
directory, per 23-02's standing rule — and `offchain/test/Main.hs` carried the whole uncommitted
task-1 implementation while it was mutated, which is exactly the situation that cost ~170 lines
last wave.

### Every `bytea` parameter in `Store/Postgres.hs`, and its wrapper

The inspection the plan asks for. **Six parameters reach a `bytea`; all six are wrapped.**

| Site | Statement | Parameter | Column / function | Wrapper |
|---|---|---|---|---|
| `put_run` | `insert_sql` #3 | `sr_key sr` | `model_run.key` | **`Binary`** |
| `put_run` | `insert_sql` #4 | `bytes` | `model_run.raw` — THE ORACLE | **`Binary`** |
| `put_run` | `insert_sql` #5 | `bytes` (the SAME value again) | `convert_from(?, 'UTF8')::jsonb` → `model_run.doc` | **`Binary`** |
| `put_blob` | `blob_insert_sql` #2 | `artifact_bytes art` | `byte_corpus.raw` | **`Binary`** |
| `lookup_run` | `lookup_sql` #3 | `key` | `where key = ?` against `bytea` | **`Binary`** |
| `doc_digest` | `doc_sql` #3 | `key` | `where key = ?` against `bytea` | **`Binary`** |

Non-`bytea` parameters — `model`, `key_scheme`, `gams_ver`, `conopt_ver`, `name`, the constraint
name — are correctly unwrapped.

**A strengthening over the plan's wording.** The plan asks for "every `bytea` **write** parameter".
The last two rows are in `WHERE` clauses of *reads*, and they are exposed to the identical wart:
the value is still being SENT, so a bare `ByteString` there sends a quoted TEXT literal and the
comparison silently MISSES for any key `byteain` would re-read. A key of `0x0badc0de` is unaffected;
a key containing a backslash is not. The wart is about the direction of travel, not about the verb
in the statement's name.

Reads are deliberately UNWRAPPED: `FromField ByteString` special-cases the `bytea` OID
(`FromField.hs:392-394`) and hands off to the `Binary` reader, so the read side is lossless.
Recorded in the module haddock: a negative control that swapped the newtype on the READ side would
pass and prove nothing.

## Guards observed firing

A guard never seen rejecting is treated as absent. **Five arms, all verbatim, all restored.**

### GUARD #19 — `.sql` is SCANNED, not merely declared. FIRED.

Input: a `0x`-prefixed 64-hex literal appended to `002_byte_corpus.sql`, the string BUILT in the
shell so no tracked file and no transcript carries it as a literal.

```
FAIL sc3_literal_purge: address/selector/topic0 literals survive in the executable surface:
      offchain/migrations/002_byte_corpus.sql:15:-- probe: 0xaaaa…aaaa   (64 'a')
```

### THE ANTI-CONTROL — declaring is NOT scanning, and it is measured in two steps

With the probe literal still on disk, `.sql` was moved OUT of `purge_scanned_extensions` while
staying in `purge_known_extensions` — the "just declare it as data" option the check's own failure
text offers:

```
step 1 (extension declared, not scanned):
FAIL sc3_literal_purge: the purge scanned 42 files, below the floor of 44. …

step 2 (and the floor lowered to 42 to match):
PASS sc3_literal_purge
```

**Step 2 is the finding.** With `.sql` declared as data and the floor adjusted, the check goes
GREEN with a `0x`-prefixed 64-hex literal sitting in a tracked, EXECUTED file under `offchain/`.
Step 1 is the honest half of the same measurement: the floor is a real instrument against this
degradation and catches the first of the two edits it takes. But two edits are all it takes, and
each one on its own looks reasonable. This is why the extension went into BOTH lists.

It also pins the earlier observation: the FAIL in guard #19 came from the SCAN, not from the
declaration — remove the scan and the identical file stops being named.

### GUARD — the migration SET, both directions, from ONE rename. FIRED.

Input: `002_byte_corpus.sql` renamed to `002_byte_corpus_v2.sql` on disk only.

```
FAIL migration_list_is_ordered_and_gapless: the manifest names a migration that is not on disk: 002_byte_corpus.sql
      the migration directory holds a file the manifest does not name: 002_byte_corpus_v2.sql
      The migration surface is a SET on both sides. A name the directory does not carry is a run
      that silently applies less than the manifest claims; a file the manifest does not name is
      executed anyway, because the library applies EVERY entry in that directory with no extension
      filter. One direction alone is satisfied by a rename.
```

Both violations in ONE message, per 23-02's finding that a rename produces one of each kind and
`_ <- expect` short-circuits.

### GUARD — the ordered-and-gapless arm, separately. FIRED.

The set arm and the version arm are different instruments and the version arm would otherwise never
have been seen rejecting. Input: `expected_migrations` version `2` changed to `3` in `Store/Schema.hs`,
filenames untouched, so ONLY this arm can fire.

```
FAIL migration_list_is_ordered_and_gapless: the migration versions are [1,3] and must be [1,2].
  They are the ORDER the library applies these files in, expressed independently of the filenames
  it sorts by, so a gap means a migration was dropped and a run that skipped it still reported
  success.
```

### GUARD — KEY-07's file half. FIRED.

Input: `key_scheme` dropped from the DDL in `001_model_run.sql`, the Haskell constant left alone —
the exact drift the two subjects exist to catch.

```
FAIL unique_constraint_names_all_three_columns: offchain/migrations/001_model_run.sql does not
  contain "unique (model, key_scheme, key)". The Haskell constant above is not the thing Postgres
  is handed; this is. Dropping a column from the DDL while leaving the constant alone is exactly
  the drift the two subjects exist to catch.
```

### GUARD — BYTE-03's scan, over `Store/Schema.hs`. FIRED, after the entry was ADDED.

`Store/Schema.hs` landed in task 1 and spent two commits as a storage module the scan did not read
— see deviation 10. Once listed, the entry was proven LIVE rather than decorative:

```
FAIL aeson_is_absent_from_the_storage_path: an aeson Value is on the STORAGE PATH. …
      offchain/lib/Store/Schema.hs:47:import Data.Aeson (toJSON)
```

### GUARD — BYTE-03's scan, over the REAL file this time. FIRED.

23-02 observed this branch against a *stub*. The check's subject is now the real module, and a
guard that has only ever been observed against a placeholder has been observed against a
placeholder. Input: an aeson import appended to `Store/Postgres.hs`.

```
FAIL aeson_is_absent_from_the_storage_path: an aeson Value is on the STORAGE PATH. The bytes in
  the raw column are the oracle and aeson re-renders numbers and reorders keys -- MEASURED, and
  asserted as values in aeson_mutation_vectors:
      offchain/lib/Store/Postgres.hs:362:import Data.Aeson (toJSON)
```

**HONEST NEGATIVES from this plan's guard work:**

1. **The `>= 2` arm and the duplicate-name arm of `migration_list_is_ordered_and_gapless` were NOT
   observed firing.** Both are ordered after the set arm, and every input that shortens or
   duplicates the manifest trips the set arm first, which short-circuits. They are floors behind a
   stronger instrument, not independent evidence, and should not be cited as such.
2. **Nothing in this plan observed the `Binary` wart, the advisory lock, the `exitFailure` or the
   derived `doc` actually behaving.** All four are source-read and structural here. They need a
   server, and that is 23-04's capture — the tier decision holds, and this plan provisioned,
   contacted and required no database.

## FOUR MEASURED CORRECTIONS to the research and the plan

All source-read on this machine at 23-03, against the tarballs in `~/.cabal/packages/`.

**1. `execute` / `execute_` THROW on a statement that returns columns.** `finishExecute` raises
`QueryError "execute resulted in 1-column result"` on `PQ.TuplesOk` (`Internal.hs:408-428`). The
form BOTH the research (`§Code Examples`) and this plan (task 2, item (b)) prescribe —
`execute_ con "select pg_advisory_lock(872304)"` — compiles cleanly and then throws at the FIRST
acquisition. Nothing complains at compile time; the whole class of wart this module exists to close.
Both lock statements now go through `query` and consume the row: `[Only ()]` for the void-returning
blocking lock (there IS a `FromField ()`, and it requires exactly `voidOid`), `[Only Bool]` for try
and unlock.

**2. On checksum drift through `runMigrations` the payload is the SCRIPT NAME, not
`"Checksum mismatch"`.** `executeMigration`'s `ScriptModified` branch returns
`MigrationError name` (`Migration.hs:181`). The string `"Checksum mismatch: <name>"` comes from the
separate `MigrationValidation` path (`:239`), which `run_migrations_or_exit` does not take.
**23-05 must not assert on that payload text** — it would be asserting on a filename.

**3. `postgresql-migration` applies EVERY entry in the migration directory.**
`scriptsInDirectory dir = sort <$> listDirectory dir` (`Migration.hs:155-158`), with no extension
filter anywhere on the path. A README or an editor backup dropped into `offchain/migrations/` is
read and handed to `execute_` as SQL. This is why the manifest check asserts the directory's WHOLE
contents rather than only its `.sql` files — strictly stronger, and it also keeps the `".sql"`
literal count at exactly 2 without contorting anything.

**4. `ToField ByteString` is at `ToField.hs:223-225`, not `:78`.** Line 78 is the comment about
`EscapeByteA`. The behaviour the plan describes is correct; the citation was one line-number off and
is corrected in the module haddock.

Also re-run rather than cited: `grep -ric advisory` across `postgresql-migration/src/` returns
**0** in all three modules. The absent lock is confirmed at this version, on this machine.

## A REAL INCOMPATIBILITY, CARRIED FORWARD TO 23-04 — not a note

`model_run.doc` is `NOT NULL jsonb` derived from `raw`, so **every artifact written through the
keyed path must be valid JSON.**

`law_first_writer_wins_on_the_identity_triple` (`Store/Laws.hs:298`) writes the bytes
`SECOND-SOLVE-DISAGREED` as its second put. Against `Store.Memory` that law passes. Against
`Store.Postgres` the statement raises `invalid input syntax for type json` **before the
`on conflict` clause is ever reached** — Postgres computes the row before it resolves the conflict,
so `do nothing` does not save it.

This was NOT papered over and NOT quietly fixed by editing wave 2's law fixture. It is recorded at
the insert in `Store/Postgres.hs` and here, because it is a SCHEMA decision that wants a deliberate
ruling, and hiding it would mean 23-04 meets an `SqlError` it cannot distinguish from a store
defect. **23-04 must choose one:**

- (a) that law's disagreeing payload becomes a disagreeing JSON *document* — the failure message
  already carries the word "disagreed"; the bytes do not need to. `law_first_writer_wins` is the
  SOLE kill site for the last-writer-wins mutant (23-02's honest negative #3), so whatever replaces
  it must still differ from `{"a":1}` in its bytes; or
- (b) the keyed surface stops requiring JSON, which is a change to BYTE-02's shape and needs saying
  out loud.

Recording the resulting `SqlError` as the law's verdict is not an option: it would record a schema
decision as a store defect, in the artifact that 23-05 reads as evidence.

## Requirement status — NOT marked complete, and why

`requirements mark-complete` was deliberately NOT run, for the third plan running. The plan's
frontmatter claims `[DB-01, KEY-07, BYTE-01, BYTE-02, BYTE-03]`. Measured against what shipped,
**four are partial and one is nearly closed.**

| Req | Verdict | Evidence, and what is still owed |
|---|---|---|
| **DB-01** | **Partial** | The runner exists, holds `pg_advisory_lock(872304)` and calls `exitFailure` on `MigrationError`; the manifest is ordered, gapless and locked as a SET in both directions with two arms OBSERVED firing. But every DB-01 clause that matters — exit code 1 on drift, the second migrator applying 0, two runs from an empty database — is an observation against a SERVER and none was made here. Lands at 23-04. |
| **KEY-07** | **Partial** | The constraint names all three columns in the DDL **and** in Haskell, and the file half was OBSERVED reddening when `key_scheme` was dropped. `live_identity_constraint_columns` exists and reads the catalogue with `with ordinality`, but has never been RUN. The live half is 23-04's capture and 23-05's assertion. |
| **BYTE-01** | **Partial** | The `bytea` columns exist and every parameter reaching one is `Binary`-wrapped, inspected site by site above. Byte-exactness itself is unobserved without a server: the corpus round-trip through Postgres is 23-04. |
| **BYTE-02** | **Partial** | `doc` is now a real derived projection, written from the SAME parameter as `raw` in ONE statement — structural, with no second source and no Haskell on the path. The other half, the exhibit of a `jsonb` round-trip FAILING a sha256 comparison on the real 606-byte shape, needs a server. 23-04. |
| **BYTE-03** | **Effectively closed here, formally at 23-05** | `aeson_is_absent_from_the_storage_path` is GREEN over seven files that all exist, with a proven positive control, and its scan branch was OBSERVED firing against the REAL `Store/Postgres.hs` rather than against a stub. Zero aeson tokens in the module. Left partial only because the requirement is signed off with the rest of the phase. |

`.planning/REQUIREMENTS.md` traceability rows carry these verdicts.

## Task Commits

1. **Task 1: the migrations, the manifest, and the three purge constants** — `5535582` (feat)
2. **Task 2: `Store.Postgres`** — `2aa1e96` (feat)
3. **End-of-plan floor re-measurement, 44 → 45** — `3995d4e` (test)
4. **`aeson_storage_path` gains `Store/Schema.hs`** — `c4741b3` (test)

## Files Created/Modified

- `offchain/migrations/001_model_run.sql` — **created.** `model_run`, the
  `model_run_identity unique (model, key_scheme, key)` constraint, the path-ops GIN index. The
  `create` carries no existence guard, deliberately — that is what makes the concurrency lock
  observable at 23-04.
- `offchain/migrations/002_byte_corpus.sql` — **created.** A separate table with no `jsonb` column,
  because the corpus is neither valid UTF-8 nor valid JSON.
- `offchain/lib/Store/Schema.hs` — **created.** `expected_migrations`, `identity_constraint_name`,
  `identity_constraint_columns`. Pure; no IO, no client, no directory read.
- `offchain/lib/Store/Postgres.hs` — **created.** 361 lines. The six `Store` fields, the lock, the
  runner, `server_version`, `live_identity_constraint_columns`. The only file in
  `offchain/{lib,app,test}` matching `Database\.PostgreSQL`.
- `offchain/test/Main.hs` — three purge constants moved, `migration_list_is_ordered_and_gapless` and
  `unique_constraint_names_all_three_columns` added and registered in `core_checks`,
  `identity_constraint_ddl` constant, imports of `Store.Config` and `Store.Schema`.
- `cfmm-replicationPlank-rpc-api.cabal` — `Store.Schema` and `Store.Postgres` in `exposed-modules`,
  each in the commit that creates its file.

## Decisions Made

- **The migration-set check asserts the directory's WHOLE contents, not its `.sql` files.** Driven
  by measurement (correction #3) rather than by taste. It is strictly stronger and, as a side
  effect, keeps `grep -c '".sql"' offchain/test/Main.hs` at exactly 2 without any contortion.
- **The insert's conflict target derives from `identity_constraint_name`.** A hardcoded
  `on conflict on constraint model_run_identity` can disagree with the constant every other check
  reads, and nothing would catch it until a live database at 23-04. Deriving it makes the
  disagreement unrepresentable. The constant is compile-time and never user input, so building it
  into the `Query` is not an injection surface.
- **The lock key is ONE exported constant passed as a parameter.** The plan wrote the literal twice
  in SQL *and* defined a constant, which leaves the constant dead (a `-Wall` failure unless
  exported) and two places to keep in step. 23-04 records `advisory_lock_key`; it now reads the same
  binding the lock is taken with.
- **`with_connection` takes the DSN as an argument**, matching 23-04's stated interface rather than
  this plan's export list. `Store.Config` keeps the environment override, so `Store.Postgres` reads
  no environment at all.
- **`unique_constraint_names_all_three_columns` is a `Check`, not a `pure_check`.** It reads a file;
  `pure_check` takes an `Either String ()` and cannot do IO. It also asserts the constraint NAME
  appears in the DDL, which is what ties the file to the constant the insert conflicts on.
- **The migration under test is resolved through `lookup 1 expected_migrations`**, not named a
  second time, so a renumbering the manifest accepts cannot leave this check reading a file that no
  longer exists while reporting nothing. `lookup` also keeps the code total — no `head`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in prescribed code] `execute_` on a `select` throws**
- **Found during:** Task 2, while checking `finishExecute`'s behaviour before writing the lock
- **Issue:** The research's `§Code Examples` and the plan's task 2 both prescribe
  `execute_ con "select pg_advisory_lock(872304)"`. `finishExecute` throws `QueryError` on
  `PQ.TuplesOk` (`Internal.hs:408-428`). It compiles and throws at the first acquisition.
- **Fix:** Both lock statements go through `query` and consume the row.
- **Verification:** Source-read; `FromField ()` exists at `FromField.hs:271` and requires `voidOid`,
  so `[Only ()]` is the type-checked form for the void-returning blocking lock.
- **Committed in:** `2aa1e96`

**2. [Rule 1 - Stale measurement inherited as fact] `purge_file_floor` 36 / "zero slack"**
- **Found during:** Task 1, the mandatory re-measure
- **Issue:** The research, the plan, 23-01's summary and 23-02's summary all state the floor is 36
  against exactly 36 scanned files with zero slack. At execution time the scan was **41** — waves 1
  and 2 added five `.hs` files. The stated consequence ("the first `.sql` reddens the floor
  immediately") was no longer true; only the extension census would have fired.
- **Fix:** Floor re-measured, and re-measured again at plan end after task 2 added a sixth `.hs`.
  Final 45. The haddock now records the RULE that governs the number, not just the number.
- **Verification:** 45 == the `find` output at plan end, run and compared.
- **Committed in:** `5535582`, `3995d4e`

**3. [Rule 2 - Missing critical] Guard #19 alone does not separate DECLARED from SCANNED**
- **Found during:** Task 1
- **Issue:** The plan's guard #19 shows the purge reddening on a seeded `.sql` literal. That shows
  the literal was found; it does not show what would have happened had `.sql` gone into the known
  list only — which is the cheaper, plausible-looking option the check's own failure text offers.
- **Fix:** A two-step anti-control. With `.sql` declared but not scanned the floor fires (42 < 44);
  lower the floor as well and the check PASSES with the literal on disk.
- **Verification:** Both steps verbatim above.
- **Committed in:** `5535582`

**4. [Rule 2 - Missing critical] The ordered/gapless arm had no independent input**
- **Found during:** Task 1
- **Issue:** Every input the plan names for `migration_list_is_ordered_and_gapless` (a rename) fires
  the SET arm, which short-circuits before the version arm runs. The version arm would have shipped
  never having been observed rejecting anything.
- **Fix:** A separate probe that changes only a version number, leaving the filenames correct.
- **Verification:** `the migration versions are [1,3] and must be [1,2]`, verbatim above.
- **Committed in:** `5535582`

**5. [Rule 2 - Missing critical] Prose inside the grep's blast radius — the TENTH instance**
- **Found during:** Task 2, running the acceptance greps
- **Issue:** `grep -c 'Database.PostgreSQL.Simple.Binary' offchain/lib/Store/Postgres.hs` returned
  **1** against a required 0. The hit was the module haddock *saying that module does not exist*.
  The comment warning about the dead import path was counted by the grep asserting the dead import
  path is absent — the same shape as 23-02's `CFMM_REQUIRE_DB` incident, in a fresh file, on the
  first attempt.
- **Fix:** Reworded to describe the path rather than spell it, with an in-file note saying why. The
  same treatment applied pre-emptively to the haddock quoting the prescribed `execute_` call.
- **Verification:** the grep returns **0**; `pg_advisory_lock(` returns exactly 1, the real call.
- **Committed in:** `2aa1e96`

**6. [Rule 1 - Self-contradicting criteria] Three acceptance greps count their own prose**
- **Found during:** Task 1, writing the DDL
- **Issue:** The plan's prescribed 001 text contains the words `jsonb_path_ops` and
  `if not exists` in its COMMENTS while its own criteria require
  `grep -c 'jsonb_path_ops' == 1` and `grep -c 'if not exists' == 0`. As written, the file it
  dictates fails the criteria it sets. Same shape for `unique (model, key_scheme, key)`.
- **Fix:** The comments describe those constructs instead of spelling them, each with a one-line
  note recording why. All three greps return their required values.
- **Committed in:** `5535582`

**7. [Rule 1 - Unsatisfiable criterion] `unique_constraint_names_all_three_columns` as a `pure_check`**
- **Found during:** Task 1
- **Issue:** The plan calls it a `pure_check` and in the same breath requires it to read
  `001_model_run.sql`. `pure_check :: String -> Either String () -> Check` cannot do IO.
- **Fix:** A `Check` with `guarded`, which is also what makes an unexpected IO error that check
  failing rather than the suite dying.
- **Committed in:** `5535582`

**8. [Rule 4-adjacent - recorded, NOT fixed] The jsonb column and a law fixture are incompatible**
- **Found during:** Task 2, reading `Store/Laws.hs` to check the Postgres store satisfies all seven
- **Issue:** See the dedicated section above. `law_first_writer_wins_on_the_identity_triple` writes
  non-JSON bytes; `model_run.doc` is `NOT NULL jsonb`.
- **Action:** Documented at the insert and handed to 23-04 with both remedies spelled out. NOT
  fixed, because editing wave 2's law fixture would hide a schema decision behind a one-literal
  change, and because the choice belongs to the plan that first runs the laws against a server.
- **Committed in:** `2aa1e96`

**9. [Deviation from acceptance greps, property verified directly] Two constants, not two literals**
- **Issue:** The plan requires `grep -c 'model_run_identity' >= 2` and
  `grep -c 'pg_advisory_lock(872304)' == 1`. Both count LITERALS that duplicate a constant.
- **Fix:** `identity_constraint_name` is used 5 times (insert conflict target + catalogue parameter
  + haddock); `migration_lock_key` is defined once, exported, and passed to both lock statements —
  `872304` appears exactly once in the file.
- **Verification:** the properties the greps stand for, checked directly:
  `grep -c 'pg_advisory_lock(' == 1`, `grep -c 'pg_try_advisory_lock(' == 1`,
  `grep -c '872304' == 1`, `grep -c 'identity_constraint_name' == 5`.
- **Committed in:** `2aa1e96`

**10. [Rule 2 - Missing critical, SELF-INFLICTED] `aeson_storage_path` did not grow with the tree**
- **Found during:** the self-check, after the SUMMARY was written
- **Issue:** `Store/Schema.hs` was created in task 1 and NOT added to `aeson_storage_path`. It spent
  two commits as a storage module BYTE-03's scan did not read. 23-02 established the rule — every
  module under `offchain/lib/Store/`, no exemptions, added in the commit that creates it — and this
  plan broke it two commits later, while its own carry-forward section was restating it.
- **Why nothing caught it:** the usual form of this defect is a guard's scope SHRINKING, and the
  named list is the defence against that. This is the other direction, and it is quieter: a named
  list makes an omission visible but not impossible, and nothing reddens when the list simply stops
  keeping up. A glob would have caught this one and would have lost the property the named list
  exists for.
- **Fix:** entry added; 7 modules on disk, 7 named; the haddock now carries this instance so the
  trade is legible.
- **Verification:** OBSERVED firing on a seeded import naming `Store/Schema.hs:47`, then restored
  sha256-identical. Verbatim above.
- **Committed in:** `c4741b3`

---

**Total deviations:** 10 (1 bug in prescribed code that would have thrown at runtime, 1 stale
inherited measurement, 4 missing-critical strengthenings — one of them self-inflicted and found only
by the self-check, 2 self-contradicting or unsatisfiable criteria, 1 finding recorded rather than
fixed, 1 acceptance-grep deviation with the property verified directly)
**Impact on plan:** No scope creep; nothing weakened. Deviation 1 is the important one — the plan's
lock code was unrunnable and would have failed at 23-04 with a `QueryError` that looks nothing like
a lock problem. Deviations 3 and 4 add observations the plan did not ask for and that the phase's
"a guard never observed rejecting is absent" rule requires. Deviation 5 makes the
prose-in-blast-radius pattern **ten instances** across three plans and it should now be a
pre-commit check rather than a discovery, as 23-02 already recommended.

## Issues Encountered

Beyond the deviations: none. Every build exited 0 with zero `offchain/` warnings on the first
attempt, including after each of the five guard probes.

One self-inflicted near-miss worth recording: `Store/Postgres.hs` was first written with an absurd
six-function chain of `Query`-building helpers, generated in place of the one-line
`fromString identity_constraint_name` that `IsString Query` already provides. It never reached a
build, let alone a commit, but it is the kind of thing that ships when a file is written once and
read never.

## Out of scope, logged not fixed

`deferred-items.md` in this directory is unchanged and still applies: `225a/` (GAMS scratch,
pre-dating this phase) and the untracked `CHANGELOG.md` / `Setup.hs` / `stack.yaml*`, the first of
which is named by the `.cabal`'s `extra-doc-files` so an `sdist` from a clean checkout would fail.
Neither is this workstream's territory.

## User Setup Required

None. **No database was provisioned, contacted, or required by this plan** — the three-tier decision
holds for the third plan running, now with the client module on disk. `cabal test` still opens no
socket: `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` is 0,
and exactly one file in `offchain/{lib,app,test}` matches `Database\.PostgreSQL`.

## Next Phase Readiness

Ready for **23-04** (the conformance capture). Carry forward:

- **RULE ON THE `jsonb` / `law_first_writer_wins` INCOMPATIBILITY BEFORE WRITING THE CAPTURE.** See
  the dedicated section. It will otherwise present as an `SqlError` from a law that passes against
  `Store.Memory`.
- **Do not assert on the drift payload TEXT.** Through `runMigrations` it is the SCRIPT NAME, not
  `"Checksum mismatch"`. The observation that counts is `echo $?` == 1 either way.
- **Do not use `execute_` for any statement that returns columns** — it throws. This bit the plan's
  own lock code and will bit anything that runs a `select` for its side effect.
- **`offchain/migrations/` must contain migrations and nothing else.** The library applies every
  entry with no extension filter, and `migration_list_is_ordered_and_gapless` now asserts the whole
  directory. A scratch file written there by the capture would redden the suite — mutate only the
  scratch COPY, which 23-04 already plans to do.
- **`migration_lock_key` is exported.** Record `advisory_lock_key` from that binding, not from a
  transcription of `872304`.
- **The capture is the FIRST execution of every DB-facing line in `Store.Postgres`.** Nothing in it
  has been run: not the lock, not the runner, not the insert, not the catalogue query. Treat a first
  failure there as a defect in this module before treating it as a defect in the capture.
- **`purge_file_floor` is 45** and the block now records the rule for when to re-measure it. The
  extension census is the instrument that catches a NEW file type; the floor catches SHRINKAGE.
- **BYTE-03's scan reads `Store/Postgres.hs` from its first commit** and was observed firing against
  the real file. Any new module under `offchain/lib/Store/` must be added to `aeson_storage_path` in
  the same commit — the list is named, not globbed, on purpose, and THIS PLAN FORGOT IT ONCE
  (deviation 10). Nothing reddens when the list stops keeping up with the directory; the only
  instrument is remembering. 23-04 adds no module under that directory, but 25 will.
- **Territory clean:** `git status --porcelain src test foundry-scripts Makefile foundry.toml
  .github` is EMPTY.

---
*Phase: 23-postgres-foundation-byte-exact-schema*
*Completed: 2026-08-16*

## Self-Check: PASSED

Re-verified against disk and git rather than asserted. **The self-check earned its keep this time:
it is what found deviation 10**, a storage module the BYTE-03 scan was not reading.

- All four created files exist AND are tracked (`git ls-files --error-unmatch`):
  `001_model_run.sql`, `002_byte_corpus.sql`, `Store/Schema.hs`, `Store/Postgres.hs`.
- All four commits resolve: `5535582`, `2aa1e96`, `3995d4e`, `c4741b3`.
- Every digest quoted above re-computed and matching:
  `12adb51f…5160e5` (001), `998c01dc…6e5ea1` (002), `8df4200d…159597` (Schema),
  `14d07790…58cc82` (Postgres).
- `Store/Postgres.hs` is **361 lines**, as claimed.
- `grep -rlE 'Database\.PostgreSQL' offchain/{lib,app,test}` lists **exactly one file**, and it is
  `offchain/lib/Store/Postgres.hs`.
- `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` = **0**.
- The aeson pattern over **all seven** modules under `offchain/lib/Store/` = **0** each, and all
  seven are named in `aeson_storage_path` (7 on disk == 7 listed).
- `Store/Laws.hs:298` really is
  `store_put st (run_of probe_model scheme_one probe_key "SECOND-SOLVE-DISAGREED")` — the
  incompatibility carried forward to 23-04 is quoted from the line it lives on, not from memory.
- `purge_file_floor` = **45** == the `find` output at plan end.
- Final suite: **98/98, FAIL count 0**, `cabal test` exit 0, 0 `offchain/` warning lines.
- `git status --porcelain offchain/` is EMPTY — every probe and mutation was removed.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is EMPTY.
