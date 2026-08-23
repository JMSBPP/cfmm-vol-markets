---
phase: 23-postgres-foundation-byte-exact-schema
plan: 04
subsystem: database
tags: [capture, conformance, docker, postgres, bytea, jsonb, advisory-lock, migrations, json-recogniser]

# Dependency graph
requires:
  - "23-01: Store.Types (adversarial_corpus, volume_path_golden_sha256, sha256_hex), Store.Config (pgstore_dsn, store_conformance_path, migrations_dir)"
  - "23-02: Store.Laws (the law set as data), Store.Memory (the reference store)"
  - "23-03: Store.Postgres (the client, the lock, the runner, the live-catalogue read), Store.Schema, the two migrations"
provides:
  - "Store.Json — a total, pure RFC 8259 recogniser with a UTF-8 gate; the predicate that lets the SERVER-FREE tier reject what the server rejects"
  - "law_a_non_json_artifact_is_rejected_on_the_keyed_path — the schema rule as an executable law, with a liveness control ordered first"
  - "offchain/app/StoreConformance.hs — the capture executable; every DB-only observation DRIVEN, none asserted"
  - "offchain/rig/capture-store-conformance.sh — docker-provisioned Postgres on a non-default port, per-run database, CFMM_REQUIRE_DB, restore-on-failure"
  - "offchain/rig/volume-path-golden.json — the real 606-byte GAMS artifact, with provenance in the rig README and its digest pinned elsewhere"
  - "offchain/rig/store-conformance.json — the committed evidence, 121 leaves, sc_complete true, 8/8 law verdicts against server_version 18.4"
affects: [23-05 checks and the sentinel harness, 25 content key, 24 toolchain identity]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TIER B PREDICTS TIER C: the reference store is TIGHTENED to the server's constraint rather than the server loosened, and the prediction is then MEASURED per input in an agreement block instead of argued in a haddock"
    - "A capture that re-executes ITSELF as a subprocess to observe a real exit code, because the library's failure is a VALUE and a value cannot demonstrate 'exits non-zero'"
    - "An exclusion observation paired with its release observation: the lock excludes a migration that DOES land once the lock is freed, so 'applied 0' cannot be satisfied by a migrator that could never apply anything"
    - "Per-observation databases created and dropped by the tool, with the conninfo override VERIFIED against current_database() rather than trusted"

key-files:
  created:
    - offchain/lib/Store/Json.hs
    - offchain/app/StoreConformance.hs
    - offchain/rig/capture-store-conformance.sh
    - offchain/rig/volume-path-golden.json
    - offchain/rig/store-conformance.json
  modified:
    - offchain/lib/Store/Memory.hs
    - offchain/lib/Store/Laws.hs
    - offchain/lib/Store/Postgres.hs
    - offchain/lib/Store/Types.hs
    - offchain/test/Main.hs
    - offchain/rig/README.md
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "USER RULING IMPLEMENTED: the keyed path REQUIRES a json value; Store.Memory is tightened to match and the law fixture becomes a json value that still disagrees. Validated by measurement — all 8 laws pass against Store.Postgres unchanged"
  - "corpus[nul] is SilentlyCorrupted, not ServerRejects — MEASURED 1 byte in, 0 bytes out, no error, because libpq's escaper takes a C string and a C string ends at its first NUL. The plan's own guard-table row is FALSIFIED"
  - "The predicted Store.Json/jsonb numeric-overflow divergence does NOT exist — 1e1000 and 1e100000 both accepted. Only the NUL-escape divergence reproduces"
  - "The artifact FILE is written exactly once at the end; only the completeness FLAG starts false. Writing an incomplete artifact first would destroy committed evidence before the tool had produced any"
  - "The non-default host port is validated by measurement, not taste: another project's Postgres is bound to 0.0.0.0:5432 on this machine right now"

requirements-completed: []
requirements-partial: [DB-01, DB-04, BYTE-01, BYTE-02, BYTE-05, KEY-07]

# Metrics
duration: 33min
completed: 2026-08-16
---

# Phase 23 Plan 04: The Conformance Capture Summary

**A real Postgres 18.4 was stood up in Docker, every database-only observation was DRIVEN against
it, and all nine came out at their expected values on the first run — including the user ruling's
new law, which passed against `Store.Postgres` unchanged and so PROVED the tightening it required:
tier B predicted tier C. Three measurements came out contrary to what the research, the plan or
this executor predicted, and all three are recorded as findings rather than adjusted.**

## Performance

- **Duration:** 33 min
- **Started:** 2026-08-16T16:17:05Z
- **Completed:** 2026-08-16T16:50:22Z
- **Tasks:** 3 (the user ruling ahead of the plan's two)
- **Files:** 12 (5 created, 7 modified)
- **One full capture, cold, no container running:** **4–8 s** (four timed runs: 7 s, 8 s, 8 s, 4 s;
  the container itself is ready in ~2 s)

## THE USER RULING — IMPLEMENTED, AND THEN VALIDATED BY MEASUREMENT

23-03 measured that `model_run.doc` is `not null jsonb` while
`law_first_writer_wins_on_the_identity_triple` wrote non-json bytes, and correctly refused to
decide it. The ruling: **the keyed path requires json, `Store.Memory` is tightened to match, the
fixture becomes a json value that still disagrees, and the rule becomes an executable law.** All
four parts landed in commit `883a991`, before any capture work.

**The point of the ruling was that tier B must PREDICT tier C.** That is now a measurement rather
than an argument:

```
law_verdicts against Store.Postgres, server_version 18.4:   8 / 8 pass
  law_a_non_json_artifact_is_rejected_on_the_keyed_path     pass
  law_blob_lookup_of_an_absent_name_is_nothing              pass
  law_blob_round_trips_byte_identically                     pass
  law_distinct_models_do_not_collide                        pass
  law_first_writer_wins_on_the_identity_triple              pass
  law_key_scheme_orphans_rather_than_matching               pass
  law_put_then_lookup_returns_the_same_artifact             pass
  law_same_key_under_a_new_scheme_inserts                   pass
```

The identical eight pass against `Store.Memory` inside `cabal test` with no socket open. Before the
ruling, `law_first_writer_wins` would have raised `invalid input syntax for type json` here while
passing there.

### `Store.Json`, and why it is hand-written

`Store.Memory` needs a json predicate with no server. Every module under `offchain/lib/Store/` is
in `aeson_storage_path`, so a json library was not available — and would not have been more
faithful anyway, since aeson's grammar differs from `jsonb`'s in the other direction. `Store.Json`
is a total, pure RFC 8259 **recogniser** (it builds no value, so it cannot re-render a number or
reorder a key) behind a UTF-8 gate that mirrors the server's own `convert_from(?, 'UTF8')` step.

It was added to `aeson_storage_path` **in the commit that creates it**, per the rule 23-03 wrote
down and then broke.

### The law's four arms, and the order

`law_a_non_json_artifact_is_rejected_on_the_keyed_path` asserts, in this order:

1. **a LIVENESS control** — a json row written and read back. Without it every remaining assertion
   is satisfied by a store that stores nothing, by a store whose every call raises, and by a
   database that is switched off. *"The put failed and the row is absent"* is the exact shape of an
   unreachable server;
2. the non-json put **RAISED** — separating the server's behaviour from a store that accepts and
   silently drops, which is also the no-op-put mutant;
3. the row is **ABSENT** — the VALUE-level half;
4. the liveness row is still readable **AFTER** the refusal — a rejection must not poison the
   connection.

The probe bytes are `SECOND-SOLVE-DISAGREED` — the exact bytes 23-03 discovered the incompatibility
with. They were not discarded; they became the probe of the law that codifies the rule they
revealed.

## MEASURED VALUES

### The nine-row guard table, with the ACTUAL recorded value

| guard | field | expected | **RECORDED** |
|---|---|---|---|
| `Binary` on write (value-level kill) | `corpus[octal-escape]` | `in_len 6`, `bare_out_len 3`, `bare_outcome "returned"` | **6 → 3, `"returned"`, no error** ✓ |
| `Binary` on write (secondary) | `corpus[nul].bare_outcome` | `"SqlError"` | **`"returned"`, `bare_out_len 0`** ✗ **FALSIFIED — see finding 1** |
| `Binary` on write (secondary, actual) | `corpus[high-byte]`, `corpus[invalid-utf8]` | a loud error | **`"SqlError"` both** ✓ |
| `bytea` authoritative | `jsonb_exhibit.doc_text_sha256` | differs from `raw_out_sha256` | **`b50a14b4…a87a16e4` ≠ `e7b14f38…07d0d884`** ✓ |
| BYTE-01 round-trip | `jsonb_exhibit.raw_out_sha256` | equals `raw_in_sha256` and the Haskell pin | **all three equal `e7b14f38…07d0d884`** ✓ |
| checksum drift | `migration_checks.checksum_drift_exit` | `1` | **`1`** (and `..._without_guard` `0`, `library_result "MigrationError"`) ✓ |
| concurrency | `second_migrator_try_lock` / `_applied` | `false` / `0` | **`false` / `0`** ✓ |
| concurrency — **the positive control** | `after_release_try_lock` / `_applied` | `true` / `1` | **`true` / `1`** ✓ |
| empty-db double run | `empty_db_run2_applied` | `0` | **`0`** (with `empty_db_run1 true`) ✓ |
| `key_scheme` orphaning | `law_verdicts.law_key_scheme_orphans_rather_than_matching` | `"pass"` | **`"pass"`** ✓ |
| live constraint | `unique_constraint.columns` | `["model","key_scheme","key"]` | **`["model","key_scheme","key"]`** ✓ |

`corpus[crlf].bare_out_sha256` **equals** its input digest, and `trailing-newline` likewise — the
research's measured `RoundTripsAnyway` behaviour reproducing correctly, exactly as the plan
predicted. Those two members prove nothing about the wart and are recorded so that nobody cites
them as if they did.

### The corpus, both paths, every member

```
name              behaviour          in  binary_out  bare_outcome  bare_out  binary_eq  bare_eq
nul               SilentlyCorrupted   1       1        returned        0        true      false
high-byte         ServerRejects       1       1        SqlError       -1        true      false
invalid-utf8      ServerRejects       2       2        SqlError       -1        true      false
crlf              RoundTripsAnyway    4       4        returned        4        true      TRUE
trailing-newline  RoundTripsAnyway    2       2        returned        2        true      TRUE
octal-escape      SilentlyCorrupted   6       6        returned        3        true      false
double-backslash  SilentlyCorrupted   4       4        returned        3        true      false
```

**Every one of the seven round-trips byte-identically through the `Binary` path** (`binary_eq`
`true`, all seven). Five of the seven do not through the bare path, three of them SILENTLY.

### The golden bytes

```
wc -c        606                                                              == volume_path_golden_bytes_len
sha256       e7b14f384ab4c027be5450218a52040110d45dbaddbbfb0bb7bd5ab707d0d884 == volume_path_golden_sha256
tail -c 4    5d 0a 7d 0a   ( "]\n}\n" — trailing newline PRESENT )
source       cfmm-gams model/mev_tax_model_one/volume_path.json  (GAMS 54.1 / CONOPT 4.39.0)
```

All three agree with the pins in `offchain/lib/Store/Types.hs`. The pin was NOT touched. Provenance
is recorded in `offchain/rig/README.md` **without the digest**, deliberately: a digest beside the
thing it digests is a tautology, and the pin lives in Haskell source so a silent replacement of
these bytes reddens rather than agreeing with itself.

### Tier-B-predicts-tier-C, per input

The `json_agreement` block — my addition, because the ruling's claim deserved measuring rather than
asserting.

```
probe                       Store.Json   jsonb    agree
law-fixture-object             true       true      ✓
the-disagreeing-document       true       true      ✓
the-non-json-probe            false      false      ✓
volume-path-golden             true       true      ✓
trailing-content              false      false      ✓
invalid-utf8                  false      false      ✓
nul-escape-in-a-string         true      FALSE      ✗   the ONE real divergence
exponent-1e1000                true       true      ✓   predicted to diverge; DID NOT
exponent-1e100000              true       true      ✓   predicted to diverge; DID NOT
```

### The artifact

```
offchain/rig/store-conformance.json     sha256 1e5f076af2b5c2839ca590f637959af49b57c5559942dab3014e9a293d332153
LEAF COUNT (jq -r 'paths(scalars)|join(".")' | wc -l)   121
sc_complete true, sc_law_count 8, law_verdicts length 8, server_version 18.4, image postgres:18-alpine
migrations   001_model_run.sql  md5 ea1a2d1f4c96bead00ba22540956c793
             002_byte_corpus.sql md5 9e89722c2ca66bd632f4f5f343934e2f
```

**121 leaves is plan 23-05's budget input** and it is on the high side. The corpus block is 70 of
them (7 members × 10 fields), which is the plan's own prescribed shape. If ~6 full `core_checks`
re-runs per leaf is the real sentinel cost, 23-05 should budget for that explicitly and consider
covering the corpus with one iterating check rather than per-field ones. The number is reported
here rather than trimmed, because trimming a recorded field to make a harness cheaper is how fields
stop being asserted.

### Build and suite

```
cabal build --enable-tests -j all   exit 0, 0 lines matching ^offchain/[^ ]*:[0-9]+:[0-9]+: warning:
                                    (after EVERY task and EVERY probe. The bare `cabal build -j all`
                                    is VACUOUS and was never run.)
test binary                          98/98 checks passed, FAIL count 0
cabal test                           exit 0, "1 of 1 test suites passed"
grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs   ->  0
```

The count is **unchanged at 98**: this plan registers no new check (23-05 does). The new law is
DATA in `expected_store_laws`, not a check, and it runs inside the existing
`store_laws_run_against_the_memory_store`.

### `purge_file_floor` — RE-MEASURED, never carried forward

```
                                                     23-03 END    23-04 END
find offchain -name '*.hs'                              36           38
find offchain -name '*.sh'                               7            8
find offchain -name '*.sql'                              2            2
SCANNED TOTAL == purge_file_floor                       45           48
```

The three new scanned files are `Store/Json.hs`, `app/StoreConformance.hs` and
`rig/capture-store-conformance.sh`. Extension census under `offchain/` at this measurement:
`hs 38, sh 8, json 8, md 3, txt 2, sql 2` — `.json` grew by two (the golden artifact and the
capture), both DATA, already declared, deliberately not scanned.

## Guards OBSERVED firing

A guard never seen rejecting is treated as absent. **Six arms, every mutated file restored from a
SAVED COPY and verified by diffing digest files — `git checkout --` was not used anywhere.**

### THE NEW LAW, arm 2 — a store that ACCEPTS non-json. FIRED.

`Store.Memory`'s json gate replaced by an unconditional `Right ()`:

```
FAIL store_laws_run_against_the_memory_store: the store contract does not hold against Store.Memory,
      which is the REFERENCE implementation every other store is measured against:
      Store.Memory: law_a_non_json_artifact_is_rejected_on_the_keyed_path: a 22-byte artifact that
      is not a json value was ACCEPTED on the keyed path. …
```

### THE NEW LAW, arm 3 — a store that VALIDATES AFTER WRITING. FIRED.

The gate moved to after the map insert — a realistic defect, and the one arm 2 alone cannot see:

```
      Store.Memory: law_a_non_json_artifact_is_rejected_on_the_keyed_path: the non-json put was
      refused and the row is PRESENT anyway: 22 bytes, sha256 ee713a99…a955a523
```

### THE NEW LAW, arm 1 — a store that stores NOTHING. FIRED, and FIRST.

`put_run`'s insert replaced by a no-op. Five laws reddened; the point is **which** message this law
produced:

```
      Store.Memory: law_a_non_json_artifact_is_rejected_on_the_keyed_path: the LIVENESS control,
      a json row written and read back before any rejection returned no row, …
```

It named the LIVENESS control, not the rejection. A store that is switched off does not "pass" the
rejection law by refusing everything — which is the whole reason the control is ordered first.

### THE CAPTURE'S REFUSAL — docker absent. FIRED, artifact byte-unchanged.

```
before  sha256 e6b5c374b08cf9c1a0c862932ae189521004e6b5003e887f7dbd2b71536ea6d0
run     EXIT=1
        CAPTURE FAIL: docker is not on PATH, so no database can be provisioned.
                      CFMM_REQUIRE_DB=1: this script emits NO artifact rather than a partial
                      one. The committed offchain/rig/store-conformance.json is left exactly as it was.
after   sha256 e6b5c374b08cf9c1a0c862932ae189521004e6b5003e887f7dbd2b71536ea6d0   IDENTICAL
```

**The first attempt at this probe was INVALID and said so.** A non-executable `docker` shim placed
first on `PATH` did **not** fire the guard — bash's `PATH` search skips non-executable files and
found the real binary, so the capture ran to completion and the artifact CHANGED. Recorded because
it is the more interesting half: a probe that fails to make the subject absent reports the guard
passing. The valid probe builds a 2750-entry symlink farm of `/usr/bin` with `docker` omitted, and
`command -v docker` returns nothing before the script is invoked.

### THE CAPTURE'S RESTORE-ON-FAILURE — a self-check failing AFTER the write. FIRED.

Self-check 2's expected `raw_len` changed to `999` on a saved copy of the script, so the failure
lands *after* the tool has already replaced the tracked artifact:

```
EXIT=1
CAPTURE FAIL: the exhibit ran over 606 bytes, expected the real artifact's 606.
  RESTORED offchain/rig/store-conformance.json to its previous contents (sha256 e6b5c374…536ea6d0).
           The capture failed, so the evidence it would have replaced is kept.
```

Artifact restored byte-identical; no `.prev` or `.tmp` residue; container removed on the failure
path too. Script restored from the saved copy, sha256 `70bec7e3…aff05d0d`, verified equal.

**HONEST NEGATIVES from this plan's guard work:**

1. **No arm of the capture's nine self-checks other than the two above was observed firing.** They
   are written in the falsify-the-cardinality-first shape that `capture-cheat-swap-proof.sh`
   established, but only the `raw_len` arm was driven. The remaining seven are unexercised
   instruments and should not be cited as evidence that they can reject.
2. **The `absent` value of `bare_outcome` was never produced.** All seven members came back either
   `returned` or `SqlError`, so that third branch has never executed.
3. **`checksum_drift_exit_without_guard` is a written constant, not a measurement.** It is `0`
   because the process demonstrably survived the in-process run — the run afterwards continued and
   wrote the artifact — but no exit code was sampled from a guardless process, because there is no
   guardless process to sample. `checksum_drift_library_result` (`"MigrationError"`) is the measured
   half of that pair.

## THREE FINDINGS — recorded, not adjusted

### 1. `corpus[nul]` is NOT `ServerRejects`, and the plan's own guard table is FALSIFIED

The plan's table says `corpus[nul].bare_outcome` should be `"SqlError"` with the UTF-8 message. The
research's table says `0x00` through the bare path raises
`ERROR: invalid byte sequence for encoding "UTF8": 0x00`. **MEASURED through the real client:**

```
nul   in_len 1   bare_outcome "returned"   bare_out_len 0   no error
```

One byte in, **zero** bytes out, statement succeeded. The mechanism is one layer below the server:
`ToField ByteString` is `Escape`, which hands the value to libpq's C-string escaper, and **a C
string ends at its first NUL** — so the parameter reaching Postgres is the empty string and there
is nothing left for the encoding check to reject. The research measured a *different path* (a text
literal in a client that does not go through parameter escaping); both readings are true of their
own path, and only this one is true of the path the corpus is a corpus FOR.

`Store.Types.adversarial_corpus`'s tag is corrected to `SilentlyCorrupted`, with the mechanism
recorded beside it. **This STRENGTHENS BYTE-05.** A total truncation at the first NUL is a worse
silent corruption than the backslash-octal member's 6→3, and it had been filed under the LOUD
behaviour — the one shaped exactly like a dead connection, which proves the least.

The behaviour SET assertion is unaffected: `high-byte` and `invalid-utf8` still carry
`ServerRejects`, and they are the members that actually deliver the loud half. Any future citation
of "the secondary `Binary` observation" must name those two, not `nul`.

### 2. The predicted `Store.Json` / `jsonb` numeric-overflow divergence DOES NOT EXIST

`Store.Json`'s haddock, as first written, claimed two known divergences. One reproduces (a
`\u0000` escape inside a string: accepted by RFC 8259, refused by `jsonb`, because Postgres text
cannot carry a NUL). The other was **refuted at two magnitudes** — `1e1000` and `1e100000` were
both **accepted** by `jsonb`.

The haddock is corrected and the refutation is written into it. The probes stay, under their own
names, because **a probe deleted for agreeing is a probe that can never disagree later.** This is
the discipline the plan asks for applied to my own prediction rather than to the plan's.

### 3. `checksum_drift_stderr` recorded server chatter, and fixing it confirmed a 23-03 source-read

The first capture recorded
`NOTICE:  relation "schema_migrations" already exists, skipping` — the *first* non-empty stderr
line, which says nothing about the drift. Corrected to the last non-`NOTICE:` line, which is the
runner's own message:

```
migration FAILED: 001_model_run.sql (dir: /tmp/cfmm-store-conformance-drift)
```

**That is 23-03's source-read confirmed EMPIRICALLY:** on drift through `runMigrations` the payload
is the **SCRIPT NAME**, not the string "Checksum mismatch". 23-05 must not assert on that text — it
would be asserting on a filename. The exit code is the observation.

### And one validated-by-accident decision

`docker ps` during this plan showed **another project's Postgres bound to `0.0.0.0:5432` on this
machine right now** (`mamertomics-monorepo-postgres-1`, same `postgres:18-alpine` image). Had the
capture used the default host port it would have connected to a foreign database, migrated it, and
reported success. The non-default `55433` is validated by measurement, not preferred by taste.

## Requirement status — NOT marked complete, and why

`requirements mark-complete` was deliberately NOT run, for the fourth plan running. The evidence
for five of the six now EXISTS, but the ASSERTIONS over it are plan 23-05's, and a requirement
whose evidence is committed but unread by any check is exactly the artifact-asserted-by-nothing
shape this repository already filed as issue #19.

| Req | Verdict | Evidence, and what is still owed |
|---|---|---|
| **DB-01** | **Evidence complete, assertion owed** | Checksum drift exits **1**; the empty-database second run applies **0**; the second migrator gets **`f`** and applies **0**, and after release gets **`t`** and applies **1**. All four are values in the committed artifact. Nothing in `cabal test` reads them yet. |
| **DB-04** | **Partial** | `image_tag` (`postgres:18-alpine`, the pin that was asked for) and `server_version` (`18.4`, what replied) are both recorded, which is the two-sided form. No check compares them. |
| **BYTE-01** | **Evidence complete, assertion owed** | All seven corpus members round-trip byte-identically through the `Binary` path, and the real 606-byte artifact round-trips to the digest pinned in Haskell source. |
| **BYTE-02** | **Evidence complete, assertion owed** | `doc_text_sha256` `b50a14b4…` ≠ `raw_out_sha256` `e7b14f38…` on the real shape. The exhibit has a live subject. |
| **BYTE-05** | **Evidence complete, and STRONGER than planned** | Three members corrupt SILENTLY on the bare path (`nul` 1→0, `octal-escape` 6→3, `double-backslash` 4→3) and two raise. The plan expected two silent and three loud. |
| **KEY-07** | **Evidence complete, assertion owed** | The LIVE catalogue reports `["model","key_scheme","key"]`, and both KEY-07 laws pass against real SQL. 23-03 asserted the file half; this is the half that proves the file was applied. |

## Task Commits

1. **The user ruling — the keyed path requires json, `Store.Memory` tightened, `Store.Json`, the
   new law** — `883a991` (feat)
2. **The capture executable** — `845d4a2` (feat)
3. **The capture script, the golden bytes, the committed artifact, and the three findings** —
   `e7687e5` (feat)

(Commit `593c672`, `docs(roadmap)`, is interleaved in the log and belongs to another track on this
branch. It is not this plan's.)

## Files Created/Modified

- `offchain/lib/Store/Json.hs` — **created.** A total, pure RFC 8259 recogniser behind a UTF-8
  gate. No IO, no library, builds no value. Added to `aeson_storage_path` in the same commit.
- `offchain/app/StoreConformance.hs` — **created.** The capture. Two modes; the `--migrate-only`
  mode exists so the process can re-execute itself and produce a real exit code.
- `offchain/rig/capture-store-conformance.sh` — **created.** Provisioning, a bounded readiness
  poll, `CFMM_REQUIRE_DB`, nine value-level self-checks, restore-on-failure, teardown on every exit
  path.
- `offchain/rig/volume-path-golden.json` — **created.** 606 bytes, verified against the Haskell
  pins at all three of length, digest and trailing bytes.
- `offchain/rig/store-conformance.json` — **created.** The committed evidence.
- `offchain/lib/Store/Memory.hs` — the json gate, ordered BEFORE the map insert, with the totality
  exception documented as a ruling rather than a defect.
- `offchain/lib/Store/Laws.hs` — the eighth law, the json disagreeing document, and `attempt`.
- `offchain/lib/Store/Postgres.hs` — the carried-forward incompatibility paragraph replaced by the
  ruling as implemented.
- `offchain/lib/Store/Types.hs` — `corpus[nul]` retagged with the measured mechanism.
- `offchain/test/Main.hs` — the new law name, `Store/Json.hs` in `aeson_storage_path`,
  `purge_file_floor` 45 → 48.
- `offchain/rig/README.md` — golden provenance (deliberately without the digest) and the capture's
  usage.
- `cfmm-replicationPlank-rpc-api.cabal` — `Store.Json` exposed; the `store-conformance` executable.

## Decisions Made

- **The artifact FILE is written exactly ONCE, at the end; only the completeness FLAG starts
  false.** The plan's "write `sc_complete` `False` FIRST" taken literally means the tool destroys
  the committed artifact before it has produced any evidence — the precise failure the capture
  scripts' restore-on-failure shape exists to prevent, and forbidden by this plan's own standards.
  The flag still starts `False` and flips only after every block returned.
- **Per-observation databases, created and dropped by the tool.** The empty-database double run
  needs a database with no history and the concurrency probe needs one it may add a third migration
  to; sharing the primary would make the first vacuous and leave the second's probe table where
  later observations read. The `dbname=` conninfo override is **verified against
  `current_database()`** rather than trusted — if libpq's last-keyword-wins rule ever changed,
  every observation would silently have been about the primary.
- **The concurrency probe carries its own third migration.** Without it, `applied 0` against an
  already-migrated database is satisfied by a migrator that could never apply anything. The
  after-release pair (`try true`, `applied 1`) is the positive control and it is not optional.
- **The bare-path insert lives in the capture, not in the library.** Shipping the wart in
  `Store.Postgres` so a test could observe it would be worse than the wart. It is confined to one
  function and used for nothing else.
- **`json_agreement` is an addition the plan did not ask for.** The ruling asserts that a
  hand-written recogniser predicts the server; that is falsifiable and is now falsified-or-not per
  input, in the artifact. It immediately paid: it refuted one of my own two predicted divergences.
- **`store-conformance.json` is committed with `jq -S` sorting**, matching
  `capture-cheat-swap-proof.sh`, so two runs differ only where the MEASUREMENT differs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Falsified plan claim] `corpus[nul].bare_outcome` is `"returned"`, not `"SqlError"`**
- **Found during:** Task 2, reading the first capture's corpus block
- **Issue:** The plan's guard table and the research's transcript both say `0x00` raises on the bare
  path. It does not: 1 byte in, 0 bytes out, no error, because libpq's escaper takes a C string.
- **Fix:** Behaviour tag corrected to `SilentlyCorrupted` with the mechanism recorded. The loud half
  is re-attributed to `high-byte` and `invalid-utf8`, which do raise.
- **Verification:** `bare_outcome "returned"`, `bare_out_len 0` in the committed artifact; suite
  still 98/98 (the behaviour SET is unchanged, all three tags still present).
- **Commit:** `e7687e5`

**2. [Rule 1 - My own prediction refuted] the numeric-overflow divergence does not exist**
- **Found during:** Task 2
- **Issue:** `Store.Json`'s haddock claimed `jsonb` refuses an exponent that overflows `numeric`.
  Driven at `1e1000` and `1e100000`, the server accepted both.
- **Fix:** Haddock corrected to record the refutation; both probes kept under their own names.
- **Commit:** `e7687e5`

**3. [Rule 1 - Wrong field recorded] `checksum_drift_stderr` captured a server `NOTICE`**
- **Found during:** Task 2
- **Issue:** "First non-empty stderr line" is a `NOTICE:` about `schema_migrations`, not the
  runner's message.
- **Fix:** `last_message_line` drops server chatter and takes the last remaining line. It now reads
  `migration FAILED: 001_model_run.sql`, empirically confirming 23-03's source-read that the drift
  payload is the SCRIPT NAME.
- **Commit:** `e7687e5`

**4. [Rule 2 - Missing critical] the exclusion observation had no positive control**
- **Found during:** Task 1, writing `concurrency`
- **Issue:** The plan asks for `second_migrator_try_lock false` and `second_migrator_applied 0`
  against an already-migrated database, where a second migrator applies 0 whether the lock works or
  not. As specified, the observation is satisfied by a migrator that could never apply anything.
- **Fix:** The probe directory carries a third migration, and the lock is measured again after
  release: `after_release_try_lock true`, `after_release_applied 1`. Both are new fields, both
  asserted by the script's gate.
- **Commit:** `845d4a2`

**5. [Rule 2 - Missing critical] the plan's write order destroys the committed artifact**
- **Found during:** Task 1
- **Issue:** "`sc_complete` is written `False` FIRST and flipped to `True`" requires two writes to
  the tracked path, the first of which replaces good evidence with an empty skeleton — contradicting
  this plan's own standard that the artifact "must NOT be destroyed by a failed capture".
- **Fix:** One atomic write at the end; the FLAG starts false. Documented in the module header.
- **Commit:** `845d4a2`

**6. [Rule 2 - Missing critical, and my own probe was the subject] the docker-absent probe did not fire**
- **Found during:** Task 2, the refusal observation
- **Issue:** A `chmod 000` `docker` shim first on `PATH` does not make `docker` absent — bash's
  `PATH` search skips non-executable files and finds the real one. The capture ran to completion and
  the artifact CHANGED, i.e. the probe reported the guard passing while never having made the
  subject absent.
- **Fix:** A 2750-entry symlink farm of `/usr/bin` with `docker` omitted; `command -v docker`
  verified empty BEFORE invoking the script. The guard then fired.
- **Verification:** exit 1, message names `docker`, artifact digest identical before and after.
- **Recorded in:** this summary; no source change was needed.

### Deviations from acceptance criteria, properties verified directly

**7. `grep -c 'renameFile' offchain/app/StoreConformance.hs` returns 0**
- `Driver.Capture.write_json_atomically` is REUSED — it *is* the `renameFile`-atomic idiom
  (`Driver/Capture.hs:356-360`). Duplicating it to satisfy a grep would add a second implementation
  of the one thing that must not have two. `grep -c 'write_json_atomically'` returns **3**.

**8. `grep -c '872304' offchain/app/StoreConformance.hs` returns 0**
- `advisory_lock_key` is recorded from the exported `migration_lock_key` binding, which is 23-03's
  explicit carry-forward instruction ("record `advisory_lock_key` from that binding, not from a
  transcription of `872304`"). The plan's grep asks for the transcription that carry-forward
  forbids. The recorded value in the artifact **is** `872304`.

**9. `grep -c 'live_identity_constraint_columns'` returns 2, not 1**
- An import plus its single call site. The property — the constraint is read from the LIVE
  catalogue rather than from the `.sql` — holds; the count cannot be 1 in a module that imports it.

---

**Total deviations:** 9 (3 falsified claims corrected by measurement — one of them the plan's own
guard table, one of them my own haddock; 3 missing-critical strengthenings, one of which was a
defect in my own probe rather than in the code; 3 acceptance-grep deviations with the properties
verified directly)
**Impact on plan:** No scope creep; nothing weakened. Deviation 4 is the important one — as
specified, the concurrency observation could not have failed. Deviation 1 changes what the phase
believes about its own corpus and makes BYTE-05 stronger, not weaker. Deviation 6 is worth carrying:
**a guard probe can itself be vacuous**, and the only reason it was caught is that the artifact
digest was compared before and after rather than the exit code being read alone.

## Issues Encountered

Beyond the deviations: none. Every build exited 0 with zero `offchain/` warning lines, on the first
attempt, after every task and after every probe. The capture worked end to end on its **first** run
against a real server — which is not nothing, given 23-03's warning that this plan is the first
execution of every database-facing line in `Store.Postgres`. Not one defect was found in that
module.

The only `-Wall` warnings produced anywhere in this plan came from the deliberate guard mutants
(`-Wunused-imports` and `-Woverlapping-patterns` on the permissive-`Store.Memory` probe), which is
itself a small confirmation that the probe was a real code change rather than a no-op.

## Out of scope, logged not fixed

`deferred-items.md` in this directory is unchanged and still applies: `225a/` (GAMS scratch,
pre-dating this phase) and the untracked `CHANGELOG.md` / `Setup.hs` / `stack.yaml*`, the first of
which is named by the `.cabal`'s `extra-doc-files` so an `sdist` from a clean checkout would fail.
Neither is this workstream's territory.

## User Setup Required

**Docker.** `bash offchain/rig/capture-store-conformance.sh` needs `docker` and `jq` on `PATH` and
nothing else — it provisions and removes its own container, on a port a local Postgres cannot
occupy. `cabal test` needs neither and opens no socket.

## Next Phase Readiness

Ready for **23-05** (the checks over this artifact). Carry forward:

- **The artifact has 121 LEAVES**, 70 of them the corpus block. Budget the sentinel harness for that
  explicitly; consider one iterating check over the corpus array rather than per-field checks.
- **Do not assert on `checksum_drift_stderr`.** Its text is `migration FAILED: 001_model_run.sql` —
  a FILENAME — now confirmed empirically as well as by source read. The exit code is the
  observation.
- **`corpus[nul]` is `SilentlyCorrupted` and returns 0 bytes.** Any check written from the plan's or
  the research's tables expecting a `SqlError` there will be wrong. `high-byte` and `invalid-utf8`
  are the `ServerRejects` members.
- **`crlf` and `trailing-newline` round-trip correctly through the BROKEN path** and must never be
  cited as evidence for the wart. A check that asserted "the bare path corrupts" over the whole
  corpus would be false.
- **`checksum_drift_exit_without_guard` is a written constant**, not a sampled exit code. Assert on
  `checksum_drift_library_result` (`"MigrationError"`) if the wart itself is the subject.
- **The freshness oracle recomputes md5** from `offchain/migrations/`'s WHOLE contents. Those
  digests are OURS and must not be compared to the migration library's stored checksums. The test
  suite will need a digest function — `crypton` is already a project dependency.
- **`STORE_CONFORMANCE` is honoured by the WRITER as well as the reader** (`Store.Config`), so the
  override-registration check can drive both ends.
- **`offchain/app/` is now the SECOND file matching `Database\.PostgreSQL`.** 23-03's self-check
  claimed exactly one; that claim is superseded, deliberately, and nothing in `cabal test` asserts
  it. If 23-05 adds such a check, scope it to `offchain/lib/` — the library is where the property
  matters.
- **`purge_file_floor` is 48** and the block records the rule for re-measuring it.
- **Any new module under `offchain/lib/Store/` goes into `aeson_storage_path` in the commit that
  creates it.** `Store.Json` did. Phase 25 will add more.
- **Territory clean:** `git status --porcelain src test foundry-scripts Makefile foundry.toml
  .github` is EMPTY, and so is `git status --porcelain offchain/`.

---
*Phase: 23-postgres-foundation-byte-exact-schema*
*Completed: 2026-08-16*

## Self-Check: PASSED

Re-verified against disk and git rather than asserted.

- All five created files exist **and are tracked** (`git ls-files --error-unmatch`):
  `Store/Json.hs`, `app/StoreConformance.hs`, `rig/capture-store-conformance.sh`,
  `rig/volume-path-golden.json`, `rig/store-conformance.json`.
- All three commits resolve: `883a991`, `845d4a2`, `e7687e5`.
- Every digest quoted above re-computed and matching:
  `1e5f076a…d332153` (the artifact), `e7b14f38…07d0d884` (the golden),
  `70bec7e3…aff05d0d` (the capture script, after the restore probe).
- The golden's three independent facts re-measured: `606` bytes, last four `5d0a7d0a`, and its
  digest appears exactly **once** in `offchain/lib/Store/Types.hs` — the pin, in a different file
  from the bytes.
- Artifact re-read: `sc_complete true`, `sc_law_count 8`, `law_verdicts` length **8**, non-`pass`
  verdicts **0**, `server_version 18.4`, `image_tag postgres:18-alpine`, **121** leaves.
- `purge_file_floor` = **48** == the `find` output at plan end.
- `aeson_storage_path` names **8** files; **8** modules exist under `offchain/lib/Store/`; the two
  lists are element-for-element identical. (`grep -c 'offchain/lib/Store/'` over the file returns 9
  — the ninth is a haddock line naming the directory, not a list entry. The list itself was read.)
- `grep -rlE 'Database\.PostgreSQL' offchain/{lib,app,test}` lists **exactly two** files:
  `Store/Postgres.hs` and `app/StoreConformance.hs` — the second is this plan's, deliberate, and
  recorded above as superseding 23-03's "exactly one".
- `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` = **0**.
- Final suite: **98/98, FAIL count 0**; `cabal test` exit 0; **0** `offchain/` warning lines.
- `git status --porcelain offchain/` is EMPTY — every probe and mutation removed, every mutated
  file restored from a saved copy and verified by diffing digest files.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is EMPTY.
- No container remains: `docker ps -a --filter name=cfmm-store-conformance` is empty. The two
  `postgres:18-alpine` containers still on this machine belong to other projects and predate this
  plan — one of them is the `0.0.0.0:5432` binding that validates the non-default port.
