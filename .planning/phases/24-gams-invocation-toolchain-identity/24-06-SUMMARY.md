---
phase: 24-gams-invocation-toolchain-identity
plan: 06
subsystem: storage
tags: [postgres, migration, check-constraint, sqlstate-23514, capture-artifact, tier-c, freshness-oracle, growth-guard, restore-on-failure, phase-close]

# Dependency graph
requires:
  - phase: 24-gams-invocation-toolchain-identity
    plan: 05
    provides: "the six-artifact sentinel sweep and its four tree-derived floors at 58/67/3698/6-entries, the gams-conformance capture, and the ruling that GAMS-03's last conjunct is the schema-level guard"
  - phase: 24-gams-invocation-toolchain-identity
    plan: 01
    provides: "Gams.Version's abstract newtype -- the PRIMARY defence this migration is defence-in-depth behind"
  - phase: 23-postgres-foundation
    provides: "Store.Schema's hand-written migration manifest, the computed freshness oracle that recomputes every migration's md5 from the repo's own .sql files, capture-store-conformance.sh's refuse-to-emit-a-partial-artifact discipline, and the SET-not-count finding"
provides:
  - "offchain/migrations/003_version_columns_nonempty.sql: a named CHECK making an empty gams_ver or conopt_ver unstorable -- the layer that outlives every Haskell refactor"
  - "Store.Schema: a three-entry expected_migrations, versions_nonempty_constraint_name and versions_nonempty_columns as data"
  - "empty_version_rejected: SQLSTATE 23514 OBSERVED against postgres 18.4 on BOTH version columns independently, through store_put -- the store's own Binary-wrapped write path -- with a positive control that lands the identical row when the versions are non-empty"
  - "version_columns_are_unstorable_empty_in_the_ddl and store_conformance_records_the_empty_version_rejection (149/149 -> 151/151)"
  - "expected_store_observation_blocks: the store artifact's top-level surface as a SET in both directions -- the fifth list in this phase found without a growth guard and the fifth to get one"
  - "a readiness poll that is actually a readiness gate (-h 127.0.0.1), after THREE consecutive captures died on the entrypoint's temporary bootstrap server"
affects: [25-content-key-and-keyed-store]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NOT NULL is not non-empty: a text column's emptiness guard is a CHECK, and the CHECK is named so the server's own message can say WHICH constraint refused"
    - "A per-column observation records emptied AND other_nonempty, so 'both columns are covered' is not one observation written down twice"
    - "A refusal exhibit carries a POSITIVE CONTROL that LANDS -- 'it raised' is satisfied by a dead connection, a malformed key and a missing table"
    - "rows_after is the SERVER'S OWN count: 'an exception was raised' and 'nothing was written' are different claims"
    - "A field the writer hardcodes cannot be asserted -- delete it rather than compare a constant to itself; the sentinel harness is what finds it"
    - "pg_isready over a container's unix socket is satisfied by the entrypoint's bootstrap server; the TCP probe is the discriminator"
    - "read -r a b c <<< \"$(jq ...)\" collapses on a field with a legitimate empty value -- one jq call per field"

key-files:
  created:
    - offchain/migrations/003_version_columns_nonempty.sql
  modified:
    - offchain/lib/Store/Schema.hs
    - offchain/app/StoreConformance.hs
    - offchain/rig/capture-store-conformance.sh
    - offchain/rig/store-conformance.json
    - offchain/test/Main.hs

key-decisions:
  - "The per-column `attempted` field was DELETED rather than asserted -- it was the literal True and the sentinel harness reported it ABSORBED; the honest per-column form is the ENTRY, compared to Store.Schema's column list in both directions"
  - "SQLSTATE is pinned to 23514 as a VALUE, not asserted 'non-empty' -- every server error carries a non-empty SQLSTATE"
  - "The lock probe migration was renumbered 003 -> 004: the library sorts by FILENAME and 003_lock_probe would have sorted BEFORE the real 003"
  - "expected_store_observation_blocks is written out rather than derived from the artifact, on Store.Schema's own reasoning about globbed manifests"
  - "The plan brief's floors (55/63) were 24-04's; both were re-measured cold before anything was edited and read 58/67"

patterns-established:
  - "A capture's own artifact surface gets a both-directions SET, not only its verdict map"
  - "A defect found in a capture's shell gate is fixed in the same commit as the observation that revealed it, and the collapsing-read hazard is written into the comment"

requirements-completed: [GAMS-03]

# Metrics
duration: ~2h
completed: 2026-08-17
---

# Phase 24 Plan 06: `NOT NULL` Is Not Non-Empty — Summary

**A `"" == ""` that has been live since phase 23 is closed one layer BELOW the Haskell guard, and
the closing was WATCHED: SQLSTATE `23514` against a real Postgres 18.4, on `gams_ver` and
`conopt_ver` independently, through the store's own `Binary`-wrapped write path, with a positive
control that lands the identical row when the versions are non-empty. The copy-paste-shaped
half-constraint was MEASURED letting an empty `conopt_ver` through.**

## Performance

| | Before this plan | After |
|---|---|---|
| checks | 149/149 | **151/151** |
| FAIL | 0 | **0** |
| `-Wall` warnings | 0 | **0** |
| `cabal test` wall (binary pre-built) | **149.8 s** | **150.0 s** |
| migrations | 2 | **3** |
| swept artifacts | 6 | 6 (one re-captured) |
| `sentinel_pair_floor` | 3698 | **3828** |

Budget **900 s**. **+0.2 s**, which is inside the run-to-run noise — the twenty-two new leaves cost
nothing measurable because `sweep_one`'s `readable` filter runs each store-conformance check once per
pair of ITS artifact rather than 3828 times.

`pgrep -a 'sleep 3' | wc -l` is **0** and `docker ps -a | grep cfmm` is **0** after everything below.
The capture provisions and removes its own container on every exit path, including the four failing
ones.

## Task Commits

| Task | Name | Commit |
|---|---|---|
| 1 | The empty version string is unstorable at the schema layer | `158ca84` |
| 2 | SQLSTATE 23514, OBSERVED, on both version columns independently | `79f8ad8` |

## What the server actually did

`offchain/rig/store-conformance.json`, `empty_version_rejected`, produced by
`bash offchain/rig/capture-store-conformance.sh` against `postgres:18-alpine` (server **18.4**) on
`127.0.0.1:55433` — deliberately not 5432, because another project's Postgres is bound to
`0.0.0.0:5432` on this machine and the default port would let a foreign database silently satisfy
the connection.

| attempt | emptied | other column | outcome | SQLSTATE | rows after |
|---|---|---|---|---|---|
| `gams_ver = ''` | yes | non-empty | **refused** | **`23514`** | **0** |
| `conopt_ver = ''` | yes | non-empty | **refused** | **`23514`** | **0** |
| both non-empty (**control**) | — | — | **accepted** | — | **1** |

The server's own message, both times, verbatim:

```
new row for relation "model_run" violates check constraint "model_run_versions_nonempty"
```

**Every one of those five columns is load-bearing and none of them is decoration.**

- `emptied` and `other_nonempty` are what make these TWO observations rather than one written down
  twice. An attempt that emptied nothing is refused for some other reason entirely; an attempt that
  emptied both columns says nothing about whether the constraint mentions the second one.
- The **control** is evaluated BEFORE the rejections, in the script and in the check. "It raised" is
  satisfied by a dead connection, a malformed key, a `doc` that is not JSON, and a table that does
  not exist. Only an identical row LANDING makes the two refusals attributable to the one thing that
  differs between them and it.
- `rows_after` is the **server's own count**. "An exception was raised" and "nothing was written"
  are different claims and this repository has been burned by the first standing in for the second.
- The **constraint name** in the message is what turns `23514` from "some check refused" into "this
  one did". `model_run` is free to grow other checks later.

## The half constraint, MEASURED

The plan asks for both columns to be tested independently because *"a constraint that only covers
one column is exactly the shape a copy-paste produces"*. That is not an argument here; it was run.
With migration `003` cut down to `check (length(gams_ver) > 0)` and nothing else changed, the
capture recorded **`rejected: false`** and its gate fired:

```
wrote offchain/rig/store-conformance.json  (server_version 18.4, 8 law verdicts, image postgres:18-alpine)
CAPTURE FAIL: the empty-version block records rejected=false.
              The server STORED an empty toolchain version. KEY-01 folds both version
              strings into the content key, so every toolchain then hashes to the same key
              component and the poisoned rows are indistinguishable afterwards. Report it
              as a FINDING about migration 003; do not adjust the numbers.
capture exit=1
```

The empty `conopt_ver` **landed**. The two-conjunct constraint is not tidiness.

## The store artifact, before and after

```
sha256 BEFORE (committed at 24-05)  1e5f076af2b5c2839ca590f637959af49b57c5559942dab3014e9a293d332153
sha256 AFTER  (committed here)      4111b1f3191660705f06bf9403b54d55e866187ec2d3810cb37825ba520f18e8
```

Top-level keys **13 → 14**; harness-enumerated leaves **134 → 156**; recorded migrations **2 → 3**.
Two consecutive successful captures were diffed field by field and are **identical apart from
`generatedAt`** — unlike `gams-conformance.json`, this artifact carries no other wall clock, which is
a measurement and is recorded here so a future plan does not have to re-derive it.

## The seven firing observations

Every mutation applied ALONE. Every source restored **from a saved copy verified by digest**, never
by `git checkout`. The committed artifact's sha256 is `4111b1f3…520f18e8` before and after all of
them, and `git status --porcelain offchain/rig/store-conformance.json` reflects only the intended
re-capture.

### 1. 23-05's COMPUTED FRESHNESS ORACLE, against a real migration rather than a mutation

Task 1's own `cabal test`, with `003` on disk and no re-capture yet. This is the reason the plan
sequenced the migration and the capture as two tasks, and it is the observation that says the oracle
recomputes rather than trusts a stamp:

```
PASS migration_list_is_ordered_and_gapless
PASS version_columns_are_unstorable_empty_in_the_ddl
FAIL store_conformance_is_present_and_fresh: the repo has a migration the capture never saw: 003_version_columns_nonempty.sql
FAIL sentinel_falsification_harness: the suite was ALREADY failing before a single mutation was applied (store_conformance_is_present_and_fresh). Every "caught" verdict below would be that pre-existing failure and not the mutation, so the sweep proves nothing until the baseline is green.
148/150 checks passed
```

### 2. `empty_version_rejected.rejected := false` (scratch copy through `STORE_CONFORMANCE`)

```
FAIL store_conformance_records_the_empty_version_rejection: the server STORED an empty toolchain version in:  (the block's own conjunction reports rejected False).
149/151 checks passed
```

The `in:` list is empty because only the top-level conjunction was flipped and the per-column
verdicts were left alone — the message reports both, so a reader can tell a doctored conjunction
from a real acceptance.

### 3. The block DELETED — a SET mismatch, not a shorter list

```
FAIL store_conformance_verdicts_are_all_pass: an observation block the set names has NO entry in the capture: empty_version_rejected
FAIL store_conformance_records_the_empty_version_rejection: missing JSON key "empty_version_rejected"; present keys: corpus, generatedAt, image_tag, ...
148/151 checks passed
```

### 3b. THE COUNT-PRESERVING CONTROL, because observation 3 alone does not answer "would a count have passed"

`empty_version_rejected` **renamed** to `empty_version_refused`. **Fourteen keys before, fourteen
after — a count passes.** The set reddens in BOTH directions in one message:

```
FAIL store_conformance_verdicts_are_all_pass: an observation block the set names has NO entry in the capture: empty_version_rejected
      the capture carries a block the set does not name: empty_version_refused
      The artifact's own top-level surface is a SET on both sides. A block that vanished would otherwise redden only whichever check happened to read it -- and a block nothing reads yet would be invisible entirely, which is the artifact-asserted-by-nothing shape these checks exist to close.
148/151 checks passed
```

**Answer of record: yes, a count would have passed.** 23-05 measured it for a deleted law verdict and
24-05 for a renamed observation; this is the same finding one level out, on the artifact's own
top-level surface.

### 4. `(3, "003_version_columns_nonempty.sql")` dropped from `expected_migrations`

Three checks fired, from three different directions, on one mutation:

```
FAIL migration_list_is_ordered_and_gapless: the migration directory holds a file the manifest does not name: 003_version_columns_nonempty.sql
FAIL version_columns_are_unstorable_empty_in_the_ddl: the migration manifest has no version 3, so the migration that makes an empty toolchain version unstorable cannot be identified and this check has no subject to read.
FAIL store_conformance_is_present_and_fresh: the capture records a migration the repo does not have: 003_version_columns_nonempty.sql
147/151 checks passed
```

`Store/Schema.hs` restored from a saved copy, sha256 `3a91105c77418763c582ef26bc5c90962fca09cdd8e69a5f92a64209ef00d835` before and after.

### 5. SQLSTATE `23514` → `23505` — the arm that says "non-empty" is not the assertion

`23505` is a unique violation. It is non-empty, it is a real integrity-constraint SQLSTATE, and it is
exactly what a mis-built exhibit produces:

```
FAIL store_conformance_records_the_empty_version_rejection: the empty-version refusal did not report SQLSTATE "23514" (check_violation): gams_ver reported "23505" | the block's conjunction reports "23505".
      An empty conjunction means the two attempts DISAGREED. Any other code means a different gate refused the insert -- 23505 is a unique violation, 22P02 a malformed input, 42P01 a missing table -- and this exhibit would then be about the wrong constraint while still looking like a guard firing.
150/151 checks passed
```

### 6. The POSITIVE CONTROL never landed

```
FAIL store_conformance_records_the_empty_version_rejection: the empty-version POSITIVE CONTROL recorded accepted False and 0 row(s) after, and it must be True and 1.
      Without it every rejection below is satisfied by a dead connection, a malformed key, a doc that is not JSON and a table that does not exist.
150/151 checks passed
```

### 7. RESTORE-ON-FAILURE, PROVEN BY DIGEST

Phase 23's first docker probe passed its exit-code check while the artifact changed underneath it,
so an exit code is not the instrument. The half-constraint run above is the vehicle: the capture
**did** write a new artifact — the `wrote` line is in the transcript — and then the gate fired.

```
artifact BEFORE = 4111b1f3191660705f06bf9403b54d55e866187ec2d3810cb37825ba520f18e8
capture exit=1
  RESTORED offchain/rig/store-conformance.json to its previous contents (sha256 4111b1f3191660705f06bf9403b54d55e866187ec2d3810cb37825ba520f18e8).
           The capture failed, so the evidence it would have replaced is kept.
artifact AFTER  = 4111b1f3191660705f06bf9403b54d55e866187ec2d3810cb37825ba520f18e8
RESTORE PROVEN BY DIGEST: IDENTICAL
```

`offchain/migrations/003_version_columns_nonempty.sql` restored from a saved copy, sha256
`ee174269e679336e8bc1c10ef40ec790f541ecc12d852a41386cee2756cf9230` before and after, and
`git status --porcelain offchain/migrations/` empty afterwards.

### 8. The sentinel harness, three ways

**The pair floor**, raised until the harness reported what it reached:

```
FAIL sentinel_falsification_harness: the sweep exercised 3828 (field, sentinel) pairs, below the floor of 999999.
```

**All six field floors, measured in ONE run** by raising every entry, so the harness had to name each:

```
FAIL sentinel_falsification_harness: the sweep enumerated fewer fields than the floor in:
      rig-manifest.json: 20, floor 999999
      rig-pins.json: 110, floor 999999
      driver-run-capture.json: 151, floor 999999
      cheat-swap-proof.json: 130, floor 999999
      store-conformance.json: 156, floor 999999
      gams-conformance.json: 76, floor 999999
```

**An absorbed field, reported by name — and ACTED ON rather than pardoned** (see deviation 1):

```
FAIL sentinel_falsification_harness: these (field, sentinel) pairs were ABSORBED SILENTLY -- the value was replaced on ONE side only and nothing in the suite objected. Each one is a field nothing here asserts:
      store-conformance.json.empty_version_rejected.columns[].attempted  :=  empty-string  x2
      store-conformance.json.empty_version_rejected.columns[].attempted  :=  git-null-object-id  x2
      store-conformance.json.empty_version_rejected.columns[].attempted  :=  json-null  x2
      store-conformance.json.empty_version_rejected.columns[].attempted  :=  numeric-zero  x2
      store-conformance.json.empty_version_rejected.columns[].attempted  :=  zero-address  x2
      store-conformance.json.empty_version_rejected.columns[].attempted  :=  zero-word  x2
```

**The pardon list did not grow.** Every other leaf of the new block was CAUGHT, and `absorbed_by_design` is unchanged.

## The floors, all measured in this plan's runs

Both tree-derived floors were run COLD before anything was edited, and again after the one file this
plan adds. Neither was derived from the other and neither was incremented:

```
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l
58                    # before, against exactly 58 -- 24-05's number CONFIRMED on disk
59                    # after 003_version_columns_nonempty.sql
$ find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
67                    # before, against exactly 67
68                    # after
```

| floor | was | now | how |
|---|---|---|---|
| `purge_file_floor` | 58 | **59** | `find … \| wc -l`, zero slack against exactly 59 |
| `credential_scan_floor` | 67 | **68** | the second `find`, run separately, zero slack against exactly 68 |
| `sentinel_pair_floor` | 3698 | **3828** | raised until the harness named 3828 |
| `artifact_field_floors` | 6 entries | **6**, `store-conformance.json` 134 → **156** | all six raised until the harness named each |

**Census under `offchain/`:** `hs 47, sh 9, json 9, md 3, txt 2, sql 3`. A `.sql` is a scanned type
for BOTH scans, so this is the one file kind that moves both floors by the same amount in the same
commit — and both commands were still run separately, because deriving one from the other is what
24-02 did and 24-03 is how that was found out.

**The arithmetic check on `sentinel_pair_floor`:** `3828 − 3698 = 130` against `22 × 6 = 132`
possible, so exactly **two** pairs were skipped as identities. Both are the numeric zero against a
recorded zero and they are named rather than counted: `columns[].rows_after` for each of the two
version columns. Those two zeroes are the finding — they are the server's own count saying the
refused row did not land.

**The five other artifacts came back at exactly the numbers written at 24-05**, including
`gams-conformance.json`, taken one plan ago. None of them shrank while this one grew.

**A floor the plan brief got wrong, recorded rather than quietly corrected:** the brief handed to
this executor said `purge_file_floor` was *"55 against exactly 55 files — zero slack (and
`credential_scan_floor` 63 against 63)"*. Those are **24-04's** numbers; 24-05 moved both and the
on-disk values were **58** and **67**. Nothing was inherited: both were re-measured cold before the
migration was written, which is the only reason the discrepancy is visible at all.

## Deviations from Plan

### 1. [Rule 1 — the field could not be asserted] The per-column `attempted` was DELETED, not asserted

- **Found during:** Task 2, by the sentinel harness on its first run over the re-captured artifact.
- **Issue:** the plan asks for `"attempted": true` in the observation, and the first version of the
  block carried one per column as well as at the top level. The per-column one was the **literal
  `True`**, written by the renderer. The harness reported all six of its sentinel mutations
  ABSORBED, which is correct: nothing could assert it except by comparing a constant to itself, and
  that is the defect 24-04 MEASURED (a suite stayed **138/138 green with the library renamed
  underneath it** because a check compared a constant to itself).
- **Fix:** the field is gone. The honest per-column form is the **entry**: an attempt that did not
  run has no member in the array, and the check compares that array's column set against
  `Store.Schema.versions_nonempty_columns` in BOTH directions — a set mismatch, never a shorter
  list. The plan's `attempted` requirement is carried by the top-level field, which is DERIVED from
  the attempts and is asserted.
- **Cost, measured:** the artifact went 158 leaves → 156, `sentinel_pair_floor` 3840 → 3828. Both
  numbers were re-measured after the change rather than adjusted by arithmetic; the 158/3840 pair is
  recorded in the haddocks so the deletion is legible.
- **Files modified:** `offchain/app/StoreConformance.hs`. **Commit:** `79f8ad8`.

### 2. [Rule 1 — Bug] The readiness poll was not a readiness gate

- **Found during:** Task 2, after **three consecutive captures** died on
  `server closed the connection unexpectedly / This probably means the server terminated abnormally`.
- **Issue:** `docker exec "$CONTAINER" pg_isready -U postgres -d "$DB_NAME"` connects over the
  container's **unix socket**, and the postgres entrypoint runs a **temporary bootstrap server** on
  that socket while `initdb` is still working. Worse, `pg_isready` reports a server that answers
  `FATAL: database "..." does not exist` as ACCEPTING CONNECTIONS. So the poll passed, the entrypoint
  then shut the bootstrap server down to start the real one, and the capture's first query hit the
  close. The container log says it plainly:

  ```
  FATAL:  database "cfmm_store_..._empty" does not exist
  LOG:  received fast shutdown request
  ```

  This is pre-existing, since 23-04. It was invisible because it fails in the SAFE direction — the
  restore-on-failure trap put the previous artifact back every time and proved it by digest — but a
  flaky gate whose failure mode is "re-run it" is how a real regression gets re-run until it passes.
- **Fix:** `pg_isready -h 127.0.0.1`. The bootstrap server has `listen_addresses` empty and listens
  on the socket ONLY, so a TCP probe cannot be satisfied by it. That is the discriminator, and it is
  why the fix is a flag rather than a longer sleep: a readiness gate a not-yet-ready server can
  satisfy is a gate that reports what it is asked. Verified: the capture reached its value gates on
  the next attempt and on every attempt since.
- **Files modified:** `offchain/rig/capture-store-conformance.sh`. **Commit:** `79f8ad8`.

### 3. [Rule 1 — Bug] `read -r a b c <<< "$(jq …)"` collapses on a legitimately empty field

- **Found during:** Task 2, while proving the restore path — the gate fired but printed
  `accepted=1 rows_after=` for a run whose real defect was the half constraint.
- **Issue:** `sqlstate` is the empty string exactly when the two column attempts DISAGREE, which is
  the case the gate exists to catch. In a space-joined line an empty field vanishes under word
  splitting and every variable after it takes its neighbour's value. The gate still refused the
  artifact, but on the wrong arm with a misleading message. A positional read over a field with a
  legitimate empty value is the `"" == ""` defect relocated into the instrument.
- **Fix:** one `jq -r` call per field, and the per-column loop iterates by INDEX. The measurement is
  written into the comment so the shorter idiom is not re-proposed for this block.
- **Scope boundary observed:** the three pre-existing `read -r … <<< "$(jq …)"` sites in this script
  were NOT changed. Their fields (`in_len`, `bare_out_len`, digests, migration counters) have no
  legitimate empty value on the paths those gates read, so the hazard has no subject there. It is
  recorded as a carry-forward rather than fixed opportunistically.
- **Files modified:** `offchain/rig/capture-store-conformance.sh`. **Commit:** `79f8ad8`.

### 4. [Rule 3 — Blocking] The lock probe migration was renumbered `003` → `004`

- **Found during:** Task 2, reading `StoreConformance.hs` before touching it.
- **Issue:** `lock_probe_filename` was `003_lock_probe.sql`, written into a SCRATCH copy of the
  migration directory. `postgresql-migration` sorts by **filename**, so with the real `003` present
  the probe would have sorted BEFORE `003_version_columns_nonempty.sql` — a probe interleaved into
  the middle of the real sequence. It still worked; leaving it would have meant the next reader has
  to re-derive the sort order to know that it did.
- **Fix:** `004_lock_probe.sql`, with the reason in the haddock. The lock observation is unchanged:
  `excluded try=false applied=0, after release try=true applied=1`.
- **Files modified:** `offchain/app/StoreConformance.hs`. **Commit:** `79f8ad8`.

### 5. [Rule 2 — Missing critical] The artifact's top-level surface had no growth guard

- **Found during:** Task 2, deciding where to register the new observation "in the SET".
- **Issue:** the LAW VERDICTS have been a set in both directions since 23-05, but the artifact's own
  observation BLOCKS were not. Deleting `jsonb_exhibit` or `migration_checks` reddened only whichever
  check happened to read it, and adding a block nothing reads was invisible entirely — the
  artifact-asserted-by-nothing shape (issue #19) one level out. **Fifth list found without a growth
  guard in this phase, and the fifth to get one** (after `artifact_float_path` at 24-02,
  `config_env_vars` at 24-04, `gams_verdict_path` at 24-05, and the store-law set at 23-05).
- **Fix:** `expected_store_observation_blocks`, compared to the artifact's top-level keys in both
  directions inside `store_conformance_verdicts_are_all_pass`. **OBSERVED** by firing observations 3
  and 3b, the second of which is the count-preserving control.
- **Files modified:** `offchain/test/Main.hs`. **Commit:** `79f8ad8`.

### 6. [record] Prose inside a grep's blast radius — INSTANCE 18

`version_columns_are_unstorable_empty_in_the_ddl`'s haddock said *"every future writer that is not
`Store.Postgres`"* — a DB-free token, in the file whose own scan asserts that no such token is in it.
The verification grep returned **1**. The module is now DESCRIBED rather than named, and the note
recording instance 18 is itself written to stay outside the pattern. Eighteen times on this branch;
the answer has never changed.

### 7. [deviation of record] The plan's floor figures were stale

Covered in the floors section above: the brief said 55/63, the disk said 58/67, and the disk won.
The plan's own instruction — *"trust nothing inherited — measure it yourself"* — is what caught it.

### 8. [deviation of record] Two checks shipped, not one

The plan's task 2 names `store_conformance_records_the_empty_version_rejection`. A second,
`version_columns_are_unstorable_empty_in_the_ddl`, shipped in task 1: the FILE half, on the
`unique_constraint_names_all_three_columns` precedent. It is not redundant with the Tier-C check —
a DDL file that was never applied leaves the file half green and the server half with nothing to
report, and the two are the same pair of subjects KEY-07 has had since 23-03. 149 → 151, not 150.

---

**Total deviations:** 8 (3 bugs auto-fixed, 1 blocking, 1 missing-critical, 3 of record)

---

## PHASE-CLOSING GUARD LEDGER

One row per guard in `24-RESEARCH.md`'s 41-row table. **Where a guard's own firing input has never
been applied it is named as a phase-level finding, not omitted** — 23-05's guard #13 precedent.

Two instrument classes appear below and they are not the same strength:

- **DRIVEN** — the guard was handed its exact firing input and was watched producing the rejection,
  in the failure message of a mutation or a negative control quoted in a commit.
- **STANDING** — the check hands the guard its firing input on EVERY suite run and asserts the
  rejection, so a guard that stopped rejecting reddens immediately. For a total pure function over a
  pinned battery this is equivalent evidence; it is distinguished because it is not a mutation.

| # | Guard | Input that fired it | Status | Recorded in |
|---|---|---|---|---|
| 1 | version parser — empty | `""` | STANDING (battery member) | 24-01, `gams_version_parser_rejects_the_garbage_battery` |
| 2 | version parser — whitespace | `"\n"`, `"   \t  \n"` | STANDING | 24-01, same check |
| 3 | version parser — **wrong subject, exit 0** | the real 1239-byte no-argument help banner | **DRIVEN** | 24-01 obs 1: `the garbage battery member "help-banner-exit-0" was not rejected as expected` |
| 4 | version parser — the flag's own output | the real 275-byte `--version` stdout | STANDING | 24-01, same check; recomputed over the recorded line at 24-05 |
| 5 | version parser — wrong component | the `gams audit` GAMSX line | STANDING | 24-01 |
| 6 | version parser — truncated | banner cut before the version field | STANDING | 24-01 |
| 7 | version parser — localised/foreign | synthetic reordered banner, labelled synthetic | STANDING | 24-01 |
| 8 | version parser — **wrong stream** | a stub writing the banner to stderr, stdout empty | **DRIVEN** | 24-04 task 2 + obs 3 (`a placeholder version on a missing banner → Produced …, GAMS 0.0.0`) |
| 9 | CONOPT — link-version decoy | `CONOPT 4    54.1.0 37378ce0 …` | **DRIVEN** | 24-01 obs 2b: `the CONOPT decoy "link-version-decoy" was not rejected: got Right (ConoptVersion "54.1.0")` |
| 10 | CONOPT — `.so` decoy | `libconopt464.so` | STANDING + **DRIVEN at Tier C** | 24-01; 24-05 obs 6 (`the true CONOPT version "4.39.0" EQUALS a decoy`) |
| 11 | CONOPT — position independence | the true line at index 38 and at 47 | **FINDING — never falsified** | see findings below |
| 12 | no empty version constructible | `fromMaybe "unknown"` in `Gams/Version.hs` | **DRIVEN** | 24-01 obs 4 |
| 13 | exit taxonomy — licensing | `ExitFailure 7` | **DRIVEN, twice** | 24-01 obs 3; 24-03 (`exit code 7 classifies as ModelLevel ExecutionError, expected Environmental LicensingError`) |
| 14 | exit taxonomy — curdir gone | `ExitFailure 145` (`401` mod 256) | STANDING (the taxonomy check was falsified on code 7, not on 145) | 24-01, 24-03 |
| 15 | exit taxonomy — ambiguity recorded | `ExitFailure 3` | STANDING | 24-01, `gams_exit_taxonomy_is_total_and_disjoint` |
| 16 | verdict ignores streams | `isInfixOf` on solver output seeded into the GAMS layer | **DRIVEN** | 24-03: `FAIL gams_verdict_ignores_the_streams: a verdict in the GAMS layer reads SOLVER OUTPUT` |
| 17 | **exit 0 with no artifact** | a stub that exits 0 writing nothing; the real binary at `action=c` | **DRIVEN, twice** | 24-03 (`exit_zero_without_artifact_is_refused`); 24-05 obs 5 (`artifact_present True, and the MEASURED pair is 0 / False`) |
| 18 | stale artifact unreachable | the real 606 golden bytes planted at the caller's CWD | **DRIVEN** | 24-03 (`a valid-looking volume_path.json … WAS REACHABLE`; second run caught by `StaleArtifact`) |
| 19 | fresh directory | inspect after success and after an abort | **DRIVEN** | 24-03 (`a run directory SURVIVED the invocation: … the third of these is the ABORT path`) |
| 20 | artifact post-conditions | `nEvents: 8` with `dQx` of length 7 | STANDING | 24-02, `artifact_postconditions_reject_a_short_array` |
| 21 | echoed-field cross-check | change one argv token after rendering | **FINDING — never falsified** | see findings below |
| 22 | canonical argv renderer | `sqrtPriceX96 = 079228…` | **DRIVEN, twice** | 24-02 obs 1 and 2 (the renderer emitting it, and an edge REFUSING instead of normalizing) |
| 23 | stderr flood | a stub writing 2,000,000 bytes to stderr | **FINDING — never falsified** | see findings below |
| 24 | **hung grandchild** | `sleep 300 & … wait`, with a direct-child-only kill | **DRIVEN** (negative control) | 24-04: `/proc/3896506/stat` → `3896506 (sleep) Z 1 …`, reparented to PID 1 |
| 25 | timeout ⇒ no artifact | the hung stub with a valid artifact already written | **DRIVEN** | 24-04: `Aborted ExitVerdict (TimedOut Killed) at exit -1`; `Produced` unreachable by type at 24-03 |
| 26 | environment is the whitelist | `env = Nothing` | **DRIVEN** | 24-04 obs 1 (`MISSING LC_ALL`; the inherited child carried 64 keys) |
| 27 | whitelist content | `LC_ALL` deleted from the whitelist | **DRIVEN** | 24-04 obs 2 — and the check as PLANNED could not fail; fixed, then observed |
| 28 | hostile ambient inertness | an EMPTY hostile-variable set in the artifact | STANDING + DRIVEN by absence (24-05 obs 4); the named input was not applied | 24-05 |
| 29 | **`Double` loses 32 wei** | `dQx[0]` decoded as `Double` | **DRIVEN** | 24-02: `FAIL dqx_double_decode_loses_exactly_32_wei_on_the_first_element` (the sign convention was wrong and its own first run caught it) |
| 30 | every element inexact | fewer than 16 of 16 differing | STANDING; the named input was not applied | 24-02 |
| 31 | golden vector provenance | ONE byte of `volume-path-golden.json`, length unchanged | **DRIVEN, twice** | 24-02 obs 4; 24-05 restore-path proof |
| 32 | non-integer token refused | `1.5` into `dQx` | **DRIVEN** | 24-02 obs 3 (`ACCEPTED into dQx as [1,7]`) |
| 33 | no aeson / no `Double` on the artifact path | `budget :: Double` seeded into `Gams/Env.hs` | **DRIVEN** | 24-02 obs 5 |
| 34 | **scan scope grows** | an unlisted `Gams/Publish.hs` | **DRIVEN, twice** | 24-02 obs 5 (both directory-vs-list guards); 24-05 obs 1 |
| 35 | capture freshness | one space appended to `Gams/Argv.hs`; **and a real new migration** | **DRIVEN, twice** | 24-05 obs 9 (`recorded=e7475dd7… recomputed=a8c9c2b0…`); **24-06 obs 1** |
| 36 | capture completeness / SET-not-count | a deleted observation, and a count-preserving RENAME | **DRIVEN, four times** | 23-05; 24-05 obs 7 and 8; **24-06 obs 3 and 3b** |
| 37 | `GAMS_CONFORMANCE` override | the constant renamed in `Gams.Config` | **DRIVEN** | 24-04 obs 2b (two independent checks) — and 2c is the counter-measurement that rejected the plan's own criterion |
| 38 | `GAMS_BIN` override | — | **DECIDED EXEMPTION**, named gap with a written reason; the reason-quality guard itself is DRIVEN | 24-04 obs 3 (`these unprobed-override entries carry no real reason: GAMS_MODEL`) |
| 39 | suite is GAMS-free | the module named in prose | **DRIVEN, three times** | 24-04 obs 1 (instance 15/16); 24-05 obs 3 (instance 17); **24-06 deviation 6 (instance 18, on the DB-free twin)** |
| 40 | sentinel harness — absorbed pairs | any leaf no check reads | **DRIVEN, three times** | 24-05 obs 13 and 14; **24-06 obs 8**, where the absorbed field was DELETED rather than pardoned |
| 41 | `sc3_literal_purge` | a `0x`-prefixed literal in a scanned type | STANDING with a PROVEN positive control on every run | seeded bait in `purge_positive_control` |

### Phase-level findings: FOUR guards whose own firing input was never applied

Named rather than omitted, and none of them is a code defect — each is a gap in the EVIDENCE.

1. **Guard 11 — `conopt_parse_is_position_independent` has never been observed reddening.** Its
   firing input is *code* (any positional or line-number logic), not data, and no such mutation was
   applied in any wave. 24-01 records it staying **green** under mutation 2b, which shows it
   discriminates a different thing from its sibling — but green under someone else's mutation is not
   an observation of this guard. The subject is real (probe line 38 vs production line **48**, itself
   an off-by-one correction to the research at 24-05).
2. **Guard 21 — the echoed-field conjunct has never been observed REJECTING.** 24-03's second firing
   observation exercised it and it PASSED: *"the artifact was found, decoded, and its echoed fields
   matched, and it lost on its modification time."* The freshness conjunct did the catching. The
   named input — change one argv token after rendering — was never applied.
3. **Guard 23 — the 2 MB stderr drain has never been observed failing.** Its firing input is a
   deadlock, which cannot be produced without removing the drain, and no such mutation was applied.
   The assertion is an EQUALITY on 2,000,000 bytes, so a truncating drain would redden as loudly as a
   deadlocking one — but that is an argument, not an observation.
4. **Guards 28 and 30 — the named inputs were not applied.** Guard 28's *empty hostile-variable set*
   and guard 30's *fewer than 16 of 16 inexact* were both asserted every run and neither was
   mutated. Both were seen reddening only via 24-05's artifact-absent sweep, which fires all ten
   Tier-C checks at once and therefore says nothing specific about either.

**Carried to Phase 25 as owed evidence, not as blockers.** Every one of the four has a live standing
assertion; what is missing is the mutation that proves the assertion can fail.

## Requirements

| Req | State after this plan | Why |
|---|---|---|
| **GAMS-03** | **COMPLETE** | Its last owed conjunct shipped and was OBSERVED: an empty toolchain version is now unstorable, and the refusal was watched against a real Postgres 18.4 with SQLSTATE `23514` on both columns independently, through the store's own `Binary`-wrapped write path, with a positive control. Every other row shipped at 24-01/24-04/24-05. |
| GAMS-01 | COMPLETE (24-05) | untouched |
| GAMS-02 | COMPLETE (24-05) | untouched |
| GAMS-04 | COMPLETE (24-05) | untouched |
| GAMS-05 | COMPLETE (24-04) | untouched |
| GAMS-06 | COMPLETE (24-05) | untouched |
| BYTE-04 | COMPLETE (24-02) | untouched |

**All seven of phase 24's requirements are now complete.**

## Issues Encountered

- Three captures died on the readiness race before it was diagnosed. Each one failed SAFELY: the
  committed artifact was restored and proved identical by digest every time. See deviation 2.
- **`24-05-SUMMARY.md` was never committed.** Commit `1df084a` closed 24-05 out and its message
  says the summary had been written, but the file is untracked in the working tree. It is committed
  here, unmodified, in the metadata commit — a phase whose record exists only on one machine's disk
  is a phase with no record.
- Four untracked files at the repository root — `CHANGELOG.md`, `Setup.hs`, `stack.yaml`,
  `stack.yaml.lock` — predate this plan, are outside its territory, and were left alone. They have
  now been carried by three consecutive plans and are named again here.

## Carry-forwards

1. **The four guards above have standing assertions and no mutation.** Phase 25 touches the key
   path, which is where guard 21 (the echoed-field cross-check) becomes load-bearing — KEY-02's own
   success criterion asks for a mutant that renders argv and preimage independently to be OBSERVED
   caught, and that mutation is exactly guard 21's missing input.
2. **Three `read -r … <<< "$(jq …)"` sites remain in `capture-store-conformance.sh`.** They are safe
   TODAY because the fields they read have no legitimate empty value on those paths. That is a
   property of the current corpus and migration observations, not of the idiom, and it should be
   revisited if either grows a field that can be empty.
3. **`003_version_columns_nonempty.sql` is a CHECK and not a NOT NULL.** `length(col) > 0` is NULL
   for a NULL and a CHECK passes on NULL — deliberately, because 001's `not null` is the constraint
   that answers NULL. If a future migration ever drops one of those `not null` declarations, this
   constraint will NOT cover the gap.
4. **`store-conformance.json` moves only in `generatedAt` across re-captures.** MEASURED here by a
   field-by-field diff of two consecutive successful captures. Unlike `gams-conformance.json`, which
   carries three wall clocks, this one carries exactly the one.
5. **`Store.Schema.versions_nonempty_columns` and the capture's per-column writer are coupled by a
   string comparison.** Adding a third version column to that list without teaching
   `empty_version_block` about it would produce an attempt that empties nothing — which is caught,
   loudly, by the `emptied` assertion, but the coupling is worth knowing about before Phase 25 adds
   `key_scheme` provenance to the same table.

## User Setup Required

`docker` and `jq` must be on PATH to re-run `bash offchain/rig/capture-store-conformance.sh`; both
were present (docker 29.5.2, jq 1.8.1). Host port **55433** must be free — it is deliberately not
5432, because another project's Postgres is bound to `0.0.0.0:5432` on this machine and the default
would let a foreign database silently satisfy the connection. Nothing is required to run
`cabal test`.

## Next Phase Readiness

**Phase 24 is COMPLETE — 6/6 plans, 7/7 requirements.** The gate `24-RESEARCH.md` sets on starting
Phase 25 is discharged in full:

1. `GamsVersion`/`ConoptVersion` have no constructible empty value and the garbage battery has been
   observed rejecting every member, including the exit-0 help banner (24-01).
2. Detection failure aborts the invocation, observed by driving it (24-04).
3. The CONOPT parser has been observed rejecting both decoys (24-01, 24-05).
4. The argv renderer is total and canonical, with the leading-zero case observed changing the bytes
   (24-02, 24-05).
5. **Migration `003`'s CHECK exists and has been observed refusing** — this plan.

Phase 25 inherits a settled rendering, a validated toolchain identity, and a schema that cannot
store the empty version its content key is about to be built from.

## Self-Check: PASSED

- `offchain/migrations/003_version_columns_nonempty.sql` — FOUND, tracked, sha256 `ee174269e679336e8bc1c10ef40ec790f541ecc12d852a41386cee2756cf9230`.
- `offchain/rig/store-conformance.json` — FOUND, tracked, sha256 `4111b1f3191660705f06bf9403b54d55e866187ec2d3810cb37825ba520f18e8`.
- Commits `158ca84` and `79f8ad8` — both FOUND in `git log`.
- `cabal build --enable-tests -j all`: exit 0, **0** warnings. `cabal test`: exit 0.
- Suite **151/151**, `grep -c '^FAIL '` = **0**, including `sentinel_falsification_harness`.
- `cabal test | grep -c '^PASS store_conformance_records_the_empty_version_rejection$'` = **1**.
- `cabal test | grep -c '^PASS migration_list_is_ordered_and_gapless$'` = **1**.
- `cabal test | grep -c '^PASS version_columns_are_unstorable_empty_in_the_ddl$'` = **1**.
- `grep -cE 'Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams' offchain/test/Main.hs` = **0**.
- `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` = **0**.
- `ls offchain/migrations/ | wc -l` = **3**; `jq -r '.migrations | length'` = **3**.
- `jq -r '.empty_version_rejected.attempted, .rejected, .sqlstate'` = `true`, `true`, `23514`.
- `grep -cE 'postgres://|PGPASSWORD|password=[^"$]' offchain/migrations/003_version_columns_nonempty.sql` = **0**.
- `find offchain … | wc -l` = **59** / **68**, matching `purge_file_floor` and `credential_scan_floor` exactly.
- `pgrep -a 'sleep 3' | wc -l` = **0**; `docker ps -a | grep -c cfmm` = **0**.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` = EMPTY.

---
*Phase: 24-gams-invocation-toolchain-identity*
*Completed: 2026-08-17*
