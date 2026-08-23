# Phase 23: Postgres Foundation & the Byte-Exact Schema — Research

**Researched:** 2026-08-16
**Domain:** Postgres schema + migrations + byte-fidelity contract, in Haskell (GHC 9.10.3), under a
hand-rolled `Check` test runner that must stay database-free
**Confidence:** HIGH (stack and schema inherited from settled research; every new claim below was
executed against PostgreSQL 18.4 in Docker or read out of the dependency source on this machine)

> **This document does not re-derive the domain.** `.planning/research/{SUMMARY,STACK,ARCHITECTURE,PITFALLS}.md`
> settled the library choice, the `bytea`-vs-`jsonb` measurements, the `Binary` wart, the
> `postgresql-migration` exit-0 wart, the aeson round-trip mutations and the three test tiers.
> Those are cited, not repeated. What is new here is in **New Measurements** and
> **Validation Architecture**, and the new measurements change how three of the phase's success
> criteria must be written.

---

## Summary

Phase 23 owns the milestone's headline guarantee, and the entire guarantee reduces to one
sentence: *the column that is compared is the column that was written, and every guard protecting
that is seen firing.* The schema half is already decided and measured — `bytea` authoritative,
`jsonb` derived, `key_scheme` inside the unique constraint, `postgresql-simple` 0.7.0.1 at +4
packages. There is no architectural research left to do there.

The research left to do is **validation**, and three findings below change the plan materially.
First, the `Binary`-newtype guard has an **asymmetric** failure surface that the roadmap's stated
adversarial corpus cannot exercise: measured on PG 18.4, `0x00` and invalid UTF-8 sent through the
bare-`ByteString` path raise `ERROR: invalid byte sequence for encoding "UTF8"` (a loud exception,
indistinguishable in shape from a dead connection), while CRLF and a trailing newline **round-trip
correctly** and prove nothing at all. The only corpus member that produces the failure the
requirement is actually about — a wrong value returned with no complaint — is a **backslash
followed by octal digits**: six bytes in, three bytes out, no error. That byte is not in the
roadmap's corpus and must be added. Second, `postgresql-migration` 0.2.1.8 contains **no advisory
lock of any kind** (source-read: `checkScript` is a bare `SELECT` inside the run's transaction),
so the roadmap's "concurrently by two migrators with only one applying" is not delivered by the
library and must be built with `pg_advisory_lock`. Third, adding a single `.sql` file under
`offchain/` **immediately reddens `sc3_literal_purge`**, whose extension census is exactly the five
types present today and whose file floor is at its exact current value with zero slack.

On DB-03 — the criterion the objective flags as load-bearing in both halves — the roadmap's
`CFMM_REQUIRE_DB=1` answer **fails open**, and the three-tier architecture has already dissolved
the question it answers. Under three tiers nothing in `cabal test` touches a database, so there is
nothing in `cabal test` for the variable to gate; any check that consults it is by construction a
DB-dependent check and has broken the tier decision. The variable's honest job is in the capture
tool. The discriminating power `cabal test` needs comes instead from a **computed** freshness
oracle (the migration `(filename, md5)` list and the law verdict set, both recomputable from the
repo with no server) plus the existing sentinel harness. That design is specified in full below.

**Primary recommendation:** build the schema exactly as `.planning/research/ARCHITECTURE.md`
Anti-Pattern 1 specifies, put every migration `.sql` outside `offchain/` or pay the three
`sc3_literal_purge` edits deliberately, wrap the migration runner in `pg_advisory_lock`, add
`a\101b` to the adversarial corpus, and validate through the artifact-plus-set idiom the suite
already runs rather than through a `CFMM_REQUIRE_DB` branch.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **DB-01** | Migrations applied by an explicit command whose failure — including a checksum mismatch — exits non-zero | STACK.md measured the exit-0 wart end to end (`MigrationError "Checksum mismatch"` + exit 0). **New:** source-read confirms no advisory lock exists in 0.2.1.8, so the concurrency half needs `pg_advisory_lock` — measured working below |
| **DB-02** | Connection config from the environment, no hardcoded credentials, consistent with the existing override convention | STACK.md measured `connectPostgreSQL ""` falling back to `PG*` env with `DATABASE_URL` unset; the repo's convention is `Rig.Manifest`'s `fromMaybe default <$> lookupEnv` + `advertised_overrides` registration (`offchain/test/Main.hs:3561`) |
| **DB-03** | `cabal test` passes with no database present **and** the store checks still discriminate | ARCHITECTURE.md's three tiers; PITFALLS.md #16. **New:** the `CFMM_REQUIRE_DB` design is evaluated and replaced below (§Validation Architecture / DB-03) |
| **DB-04** | A Postgres instance provisionable for local and CI runs via Docker | STACK.md measured `postgres:18-alpine` ready in 3 s; re-confirmed today (server_version 18.4, `standard_conforming_strings=on`, `bytea_output=hex`) |
| **BYTE-01** | Output stored as `bytea` and returned byte-identical, verified against a recorded sha256 | ARCHITECTURE.md Anti-Pattern 1's two-column schema; PITFALLS.md #3. **New:** the real 606-byte artifact exists and is byte-reproducible — see New Measurements #3 |
| **BYTE-02** | A `jsonb` projection exists for querying, **derived** from the bytes; no check compares `jsonb` to `jsonb` for byte identity | SUMMARY.md's measured `jsonb` reorder (`4075758e…` vs `dd8a3e26…`). Enforcement recommendation: make it a **type error**, not a check (§Don't Hand-Roll) |
| **BYTE-03** | The bytes never pass through `Data.Aeson.Value` on the storage path | SUMMARY.md's four measured aeson mutations; ARCHITECTURE.md's `write_bytes_atomically` split of `Driver.Capture` |
| **BYTE-05** | A stored artifact round-trips byte-identically — a test that fails if any layer normalizes, including bare `ByteString` instead of `Binary` | PITFALLS.md #3. **New and load-bearing:** the corpus the roadmap names cannot demonstrate silent corruption; see New Measurements #1 |
| **KEY-07** | Rows carry `key_scheme` inside the unique constraint so a key-formula change orphans rather than corrupts | PITFALLS.md #4 and #15; the column is one `SMALLINT` and the constraint is `(model, key_scheme, key)` |

---

## User Constraints

No `CONTEXT.md` exists for this phase (`.planning/phases/23-postgres-foundation-byte-exact-schema/`
is empty). There are therefore no locked user decisions, no explicitly-delegated discretion areas
and no deferred ideas to honour beyond what `ROADMAP.md` and `REQUIREMENTS.md` already state.

The binding constraints in force are the roadmap's, and they are treated here as locked:

- `bytea` authoritative, `jsonb` derived — non-negotiable.
- `postgresql-simple` 0.7.0.1; not `hasql`, not `persistent`.
- Postgres is **never** a dependency of `cabal test`.
- "It type-checks" is never acceptance; "the suite is green" is never acceptance.
- `.planning/config.json` sets `workflow.nyquist_validation: true`, so the Validation Architecture
  section below is mandatory and authoritative.

---

## New Measurements

Everything in this section was executed on this machine today, against `postgres:18-alpine`
(`server_version` **18.4**, `standard_conforming_strings=on`, `bytea_output=hex`) or read out of
the dependency tarballs in `~/.cabal/packages/`. The container was removed afterwards.

### 1. The `Binary` wart is ASYMMETRIC, and the roadmap's corpus cannot exercise its dangerous half

The write side is broken and the read side is not. Source-read of
`postgresql-simple-0.7.0.1`:

- `ToField ByteString` → `Escape` (a quoted **text** literal) — `ToField.hs:78`
- `ToField (Binary ByteString)` → `EscapeByteA` — `ToField.hs:201-206`
- `FromField ByteString` **special-cases `bytea`**: `if typeOid f == TI.byteaOid then unBinary <$> fromField f dat else …` — `FromField.hs:391-394`

So **reading** a `bytea` column into a bare `ByteString` is correct and lossless. The wart is
write-only. A negative control that swaps the newtype on the *read* side will pass and prove
nothing.

On the write side, the corpus members behave in three different ways. MEASURED:

| corpus member | bare-`ByteString` (text) path | what it demonstrates |
|---|---|---|
| `0x00` | `ERROR: invalid byte sequence for encoding "UTF8": 0x00` | a **loud exception** — same shape as a dead connection |
| `0xFF` / invalid UTF-8 | `ERROR: invalid byte sequence for encoding "UTF8": 0xff` | a **loud exception** |
| CRLF, trailing newline | `610d0a620a`, 5 bytes — **round-trips correctly** | **nothing.** Absorbed silently |
| **`a\101b`** = `61 5c 31 30 31 62` | **`614162`, 3 bytes — no error, no warning** | **silent corruption of the value** |

The transcript:

```
1|615c31303162|6|167235f74aa91cbaf0203d4d186f8a14   -- hex literal  (what Binary/EscapeByteA sends)
2|614162      |3|9593f2df5265159c8d524f5603b222de   -- text literal (what bare ByteString sends)
```

`byteain` still accepts the legacy escape format, so a lone backslash followed by three octal
digits is re-read as one byte. Six bytes in, three bytes out, and the statement succeeded.

**Consequence for the plan.** `ROADMAP.md` SC-1 names the corpus as "`0x00`, `0xFF`, invalid
UTF-8, a CRLF and a trailing newline". Two of those five are absorbed and three fire as
exceptions; **none produces a wrong value**. The criterion says "the same corpus sent as a bare
`ByteString` … is OBSERVED to fail that round-trip", and as written that observation would be
satisfied entirely by a `SqlError`. Add `a\101b` (and, cheaply, `\\`, `\000`, `\x` as a literal
two-byte prefix) and assert the **length and digest** of the readback, not merely that something
failed. A check that only asserts "it threw" cannot distinguish the guard firing from the database
being down — which is this repo's defect class wearing a sixth costume.

### 2. `postgresql-migration` 0.2.1.8 has NO advisory lock — the concurrency criterion is not free

Source-read of `Database/PostgreSQL/Simple/Migration.hs`:

- `runMigrations' isFirst con opts commands = if isFirst then doRunTransaction opts con go else go` (`:119`)
- `doRunTransaction` with the default `TransactionPerRun` is exactly `withTransaction con act` (`:381`)
- `checkScript con opts name fileChecksum = query con q (Only name) >>= …` (`:253-262`) — a plain
  `SELECT`. No `FOR UPDATE`, no `LOCK TABLE`.
- `initializeSchema` is `create table if not exists <optTableName>` (`:190-199`)
- Grep for `advisory` / `pg_advisory` across the module: **zero hits**

Under Postgres's default READ COMMITTED, two concurrent migrators both observe
`ScriptNotExecuted`, both `execute_` the DDL, and both insert into `schema_migrations`. If a
migration says `CREATE TABLE model_run (…)` without `IF NOT EXISTS`, the loser crashes with
`relation "model_run" already exists` after the winner commits; with `IF NOT EXISTS` it can still
hit the known concurrent-`CREATE TABLE` race on `pg_type_typname_nsp_index`.

The primitive works and is deterministic. MEASURED, two sessions:

```
session A: select pg_advisory_lock(872304); select pg_sleep(6);
session B (while held):    select pg_try_advisory_lock(872304)  ->  f
session B (after release): select pg_try_advisory_lock(872304)  ->  t
```

**Consequence for the plan.** `ROADMAP.md` SC-3's "concurrently by two migrators with only one
applying" must be implemented as `pg_advisory_lock(<constant>)` around the whole runner, and the
OBSERVATION that makes it non-vacuous is the `f` — a second migrator that reports *applied 0* while
the first holds the lock. `pg_try_advisory_lock` gives a deterministic test with no sleep-racing;
production should use the blocking `pg_advisory_lock`. This confirms PITFALLS.md #15's
recommendation and upgrades it from advice to a requirement.

### 3. The real `volume_path.json` bytes exist, are reproducible, and belong in the artifact

MEASURED at two independent paths:

```
/tmp/vp/volume_path.json                                            606 bytes
/home/jmsbpp/cfmms-playground/cfmm-gams/model/mev_tax_model_one/volume_path.json   606 bytes
both sha256 e7b14f384ab4c027be5450218a52040110d45dbaddbbfb0bb7bd5ab707d0d884
both end   5d 0a 7d 0a   ( "]\n}\n" — trailing newline PRESENT )
```

**Answer to the open question: yes, carry the real bytes.** They are 606 bytes, they are
byte-identical across two runs of GAMS 54.1 / CONOPT 4.39.0, and they are the *only* corpus that
can exercise BYTE-02 at all. The adversarial corpus and the real bytes are **not substitutable**:
the adversarial corpus catches transport corruption (a byte the wire cannot carry), while only the
real §3 shape catches *shape-dependent* normalization — `jsonb`'s key reorder is a function of the
key names and lengths, and aeson's `0.00318353 → 3.18353e-3` is a function of the actual numeric
literals. SC-2 as written ("a `jsonb` round-trip of the real `volume_path.json` shape is exhibited
FAILING a sha256 comparison") literally cannot be satisfied by synthetic bytes.

Two riders:

- The file lives in **another worktree** (`cfmm-gams`). Do not read across worktrees at test time —
  that is the Phase 28 ownership problem arriving early. **Copy** the bytes into
  `offchain/rig/` as this workstream's own committed evidence, with provenance recorded
  (toolchain versions, the two-run reproducibility, the date).
- The pinned sha256 must live in **Haskell source**, not beside the bytes in the artifact. A
  digest recorded next to the thing it digests is the seventh defect — the tautology. This is the
  `rpin05_live_bytes_match_the_external_golden` distinction and it is already established practice
  here.

### 4. A `.sql` file under `offchain/` reddens `sc3_literal_purge` on the first run

MEASURED against the current tree:

```
extensions present under offchain/ : hs json md sh txt
purge_known_extensions             : [".hs",".json",".md",".sh",".txt"]   (Main.hs:842)
purge_scanned_extensions           : [".hs",".sh"]                        (Main.hs:835)
scanned files (.hs + .sh)          : 36
purge_file_floor                   : 36                                   (Main.hs:846)   -- zero slack
```

The check's own failure text is explicit: *"offchain/ holds file types this check has never decided
about … Either add it to `purge_scanned_extensions` (if code runs from it) or to
`purge_known_extensions` with the reason it is data."* SQL **is** executed, so the correct answer
is both lists, and the plan must say so deliberately rather than discover it as a red.

Related and easy to get wrong: `purge_pattern` (`Main.hs:824-830`) requires a `0x` prefix —
`0x[0-9a-fA-F]{64}\b`. A **bare** 64-hex sha256 does not match, which is why `ground_truth`
(`Main.hs:352-359`) already carries bare topic0 literals in this same file. **Pin the artifact
digest bare** (`"e7b14f38…"`). Writing `0xe7b14f38…` reddens the suite.

### 5. Version re-confirmation

Both tarballs resolved in the local cabal store, matching STACK.md exactly:
`postgresql-simple-0.7.0.1`, `postgresql-migration-0.2.1.8`. `Binary` is exported from
`Database.PostgreSQL.Simple.Types` (`:146`), re-exported by `Database.PostgreSQL.Simple` — there is
no `Database.PostgreSQL.Simple.Binary` module, so an import written that way will not compile.

---

## Standard Stack

Inherited verbatim from `.planning/research/STACK.md` (measured by `plan.json` set-diff against the
real 152-package baseline). Phase 23 needs only the first two rows; `typed-process` belongs to
Phase 24 and `crypton` is used here for the corpus digest.

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `postgresql-simple` | **0.7.0.1** | DB client | **+4 packages**, the smallest of six candidates. Raw SQL, no DSL, no TH — the only candidate whose model matches a codebase that hand-rolls its own `Check` list |
| `postgresql-migration` | **0.2.1.8** | Migration runner | **+2 over the client.** Plain `.sql` directory + MD5 drift detection you would otherwise write yourself |
| `crypton` | **1.0.6** | SHA256 over the corpus | **+0 packages** — already resolved transitively via `web3-crypto` |
| PostgreSQL | **18.4** | server | pin the image tag; record the server version in the conformance artifact |

### Not in this phase

`typed-process` (Phase 24), `resource-pool` (not until a second concurrent consumer exists —
the store is single-writer at Phase 23).

### Pins that constrain future work

| Package | Constraint | Source |
|---|---|---|
| `crypton` | `<1.1` — forced by `web3-crypto`; plan resolves 1.0.6 | STACK.md |
| `aeson` | `<2.3` — forced by `web3-crypto`; plan pins 2.2.5.0 | STACK.md |
| `base` | `web3-crypto` allows `<4.21`, so GHC 9.12 would break it | STACK.md |

**Installation** — add to the `library` stanza of `cfmm-replicationPlank-rpc-api.cabal`, following
the existing comment discipline at lines 107–115 (which records *whether a new package enters the
build plan*):

```cabal
                      postgresql-simple,      -- 0.7.0.1  +4 packages (Only, postgresql-libpq,
                                              --          postgresql-libpq-configure, itself)
                      postgresql-migration,   -- 0.2.1.8  +2 (itself, cryptohash-md5)
                      crypton                 -- 1.0.6    +0 -- ALREADY resolved via web3-crypto
```

Verify with the only gate that counts:

```bash
cabal build --enable-tests -j all     # WITHOUT --enable-tests this is VACUOUS
```

---

## Architecture Patterns

### Module layout (from ARCHITECTURE.md; role-named, one IO edge per area)

```
offchain/lib/Store/
├── Types.hs      PURE  StoredRun, Artifact newtype, KeyScheme
├── Schema.hs     PURE  the migration list as ordered (version, name) values + their digests
├── Class.hs      IO    the Store record-of-functions (the seam)
├── Laws.hs       IO    store_laws :: [(String, Store -> IO (Either String ()))]
├── Memory.hs     IO    IORef-backed reference implementation
├── Config.hs     IO    PGSTORE_DSN resolution, Rig.Manifest idiom
└── Postgres.hs   IO    the ONLY module importing postgresql-simple
```

`Store.Class` is a **record of functions, not a typeclass** — the codebase defines zero typeclasses
of its own across 26 library modules, and a record can be partially overridden per-check (a store
whose `store_put` fails on the third call is one line).

### The schema

```sql
create table model_run (
  model       text     not null,
  key_scheme  smallint not null,
  key         bytea    not null,
  raw         bytea    not null,   -- THE ARTIFACT. Byte-exact. The oracle. Never compared to doc.
  doc         jsonb    not null,   -- derived projection. Query surface only. NEVER authoritative.
  gams_ver    text     not null,
  conopt_ver  text     not null,
  pinned      boolean  not null default false,
  created_at  timestamptz not null default now(),
  constraint model_run_identity unique (model, key_scheme, key)   -- KEY-07
);
create index model_run_doc_gin on model_run using gin (doc jsonb_path_ops);
```

`jsonb_path_ops` supports `@>`, `@?`, `@@`, is smaller and faster than default `jsonb_ops`, and —
usefully — sidesteps the `?` / `??` placeholder wart entirely, since `@>` and `->>` contain no `?`.

### Pattern: the guard that is a TYPE ERROR, not a check

BYTE-02 asks for "a check reddens if any identity comparison reads the `jsonb` column". A check can
be deleted or renamed; a type cannot be compared away. Give the two columns **distinct newtypes with
no `Eq` between them**:

```haskell
-- Store/Types.hs
newtype Artifact   = Artifact   ByteString   -- from `raw`.  Eq. Digestible. THE oracle.
newtype DerivedDoc = DerivedDoc Value        -- from `doc`.  NO Eq instance. Cannot be compared.
```

`verify_bytes :: Artifact -> Artifact -> Bool` then cannot be handed a `DerivedDoc`, and
`DerivedDoc` has no `Eq`, so `doc == doc` does not type-check. This is the same instrument Phase 25
uses for `FreshlySolvedBytes`, applied one phase earlier at zero cost. The residual hole — someone
writes a converter — is closed by a source-scan check in the `sc3_literal_purge` idiom (grep with a
positive control) over `offchain/lib/Store/`.

### Pattern: the migration runner that actually exits non-zero

```haskell
-- postgresql-migration returns a VALUE. The process exits 0 regardless. MEASURED (STACK.md).
run :: Connection -> FilePath -> IO ()
run con dir = do
  _ <- execute_ con "select pg_advisory_lock(872304)"     -- NOT provided by the library
  result <- runMigrations con defaultOptions
              [ MigrationInitialization, MigrationDirectory dir ]
  case result of
    MigrationSuccess    -> pure ()
    MigrationError what -> do
      hPutStrLn stderr ("migration FAILED: " ++ what ++ " (dir: " ++ dir ++ ")")
      exitFailure                                          -- the whole point
```

Note `runMigrations`'s default `TransactionPerRun` already wraps the run in `withTransaction`
(source: `Migration.hs:119` → `:381`), so a mid-run failure rolls back. The advisory lock is
session-scoped and is released when the connection closes.

### Anti-patterns (from ARCHITECTURE.md, restated because Phase 23 is where they land)

- **Storing the artifact only as `jsonb`.** Destroys the milestone's headline guarantee. Measured.
- **Skipping a check when the DB is absent.** Forbidden by `sc3_load_succeeds`'s stated rule.
- **Trusting `runMigration`'s process exit status.** It is always 0.
- **A naked `ByteString` parameter against a `bytea` column.** Silent corruption, measured above.
- **Reading the fixture bytes across worktrees at test time.** Copy them in and pin the digest.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Migration ordering + checksum drift | your own `schema_migrations` table | `postgresql-migration` `MigrationDirectory` + `MigrationValidation` | The MD5 drift detector is the whole value; it is measured catching a tampered file (STACK.md) |
| Binary parameter escaping | manual `\x` hex string building | `Database.PostgreSQL.Simple.Types (Binary(..))` | `EscapeByteA` is the only correct write path; hand-rolling it re-opens exactly the corruption measured above |
| SHA256 | `cryptonite` (deprecated 2022-03-13) | `crypton` `Crypto.Hash (SHA256, hashWith)` | +0 packages, already resolved. `show` on the `Digest` avoids the `ByteArrayAccess` skew (STACK.md) |
| Mutual exclusion for migrations | an application-side lock file or a CI `flock` | `pg_advisory_lock(<constant>)` | The DB is the shared resource; the existing host-wide flock is keyed on anvil's port 8545, not on Postgres |
| "Is the committed artifact stale?" | a `generatedAt` timestamp comparison | recompute the migration `(filename, md5)` list and the law set from the repo | 21-02 MEASURED that `generatedAt` is not a regeneration witness (`Main.hs`, `reason_generated_at`) |
| Mutating an artifact to prove a field is asserted | a bespoke one-off harness | register it in `swept_artifacts` (`Main.hs:5019`) | The sentinel harness ships positive and negative controls; a bespoke one would not |
| Proving an env override is live | a comment in the README | an `OverrideProbe` in `advertised_overrides` (`Main.hs:3561`) | Three overrides were measured advertised-and-dead; this sweep is the standing general fix |
| Provisioning Postgres for tests | `tmp-postgres` | `docker run --rm postgres:18-alpine` in the capture script only | `tmp-postgres` shells out to `initdb`/`pg_ctl`, absent on this machine; last release 2019-12-29 |

**Key insight:** every hand-rolled option in this table has already been attempted somewhere in
this repo's history and produced a defect of the same class — an instrument that reports clean
having read nothing.

---

## Common Pitfalls

Phase 23 owns five of the seventeen in `.planning/research/PITFALLS.md`. Summarised with the new
measurements folded in.

### Pitfall 3 (owned): `ToField ByteString` sends text, not `bytea`
**What goes wrong:** the types line up, nothing complains at compile time, and the bytes come back
different. **How to avoid:** `newtype Artifact = Artifact ByteString` in `Store.Types` whose
`ToField`/`FromField` go *only* through `Binary`, so a bare `ByteString` cannot reach a query.
**Warning sign:** a digest column whose stored length is 64 when you meant 32.
**The input that makes the guard fire:** `a\101b` — measured 6 bytes → 3 bytes, no error.

### Pitfall 15 (owned): concurrent migrators on a shared executor
**What goes wrong:** the develop gate's `concurrency` group is keyed on `github.ref` and does not
exclude runs on different refs; the existing host-wide `flock` is keyed on anvil's port. A Postgres
instance is a second shared singleton with the same problem. **How to avoid:** advisory lock
(measured above) + **database-per-run in CI** (a name derived from the run id, created and dropped
in-job) so the shared-singleton problem does not arise at all. **Also:** `actions/checkout`'s
`clean: true` runs `git clean -ffdx`, so "migrate from a completely empty database" is CI's
**normal** case, not an edge case.

### Pitfall 16 (owned): DB tests that skip — the `grep -q`-over-an-empty-log finding
**What goes wrong:** `if PGHOST unset then skip` makes the suite green having verified nothing.
**How to avoid:** the three tiers plus the artifact-and-set design in §Validation Architecture. See
the DB-03 analysis there — the roadmap's `CFMM_REQUIRE_DB` fails open and is relocated.

### Pitfall 1 (owned): `jsonb` cannot return the bytes it was given
Measured three times independently. `bytea` authoritative; the identity comparison never reads
`doc`. Enforced as a type error above.

### Pitfall 4 (partial — the `key_scheme` half): a key-formula change corrupts instead of orphaning
Phase 23 owns only the column and the constraint. **The input that makes the guard fire:** insert a
row under `key_scheme = 1`, look it up under `key_scheme = 2`, observe **zero rows** — never a
silent match, never a "close enough" hit.

### New, phase-local: the corpus that proves nothing
A corpus of CRLF and trailing newlines round-trips correctly through the *broken* path. A negative
control built from it is green and vacuous. Every corpus member must be classified by which of the
three behaviours it produces (exception / absorbed / silent corruption), and at least one member of
the third class is mandatory.

### New, phase-local: `.sql` under `offchain/` is an immediate red
Three constants in `offchain/test/Main.hs` must move together. Budget it as a task, not a surprise.

---

## Code Examples

### Round-tripping the adversarial corpus (BYTE-01 / BYTE-05)

```haskell
-- Source: postgresql-simple-0.7.0.1 Types.hs:146, ToField.hs:201, FromField.hs:412
import Database.PostgreSQL.Simple        (Connection, execute, query)
import Database.PostgreSQL.Simple.Types  (Binary(..), Only(..))

put_artifact :: Connection -> Artifact -> IO ()
put_artifact con (Artifact bs) =
  () <$ execute con "insert into model_run (…, raw, …) values (…, ?, …)" (Only (Binary bs))

get_artifact :: Connection -> Digest -> IO (Maybe Artifact)
get_artifact con k = do
  rows <- query con "select raw from model_run where key = ?" (Only (Binary (digest_bytes k)))
  pure $ case rows of
    (Only (Binary bs) : _) -> Just (Artifact bs)   -- Binary on the way out too, for symmetry;
    _                      -> Nothing              -- a bare ByteString would also be CORRECT here
```

### The adversarial corpus, classified

```haskell
-- Each member is tagged with the behaviour it produces on the BROKEN (bare ByteString) path,
-- because "the guard fired" is only evidence if you know WHICH failure you observed.
data CorpusBehaviour = ServerRejects | RoundTripsAnyway | SilentlyCorrupted deriving (Eq, Show)

adversarial_corpus :: [(String, ByteString, CorpusBehaviour)]
adversarial_corpus =
  [ ("nul",              BS.pack [0x00],                          ServerRejects)
  , ("high-byte",        BS.pack [0xFF],                          ServerRejects)
  , ("invalid-utf8",     BS.pack [0xC3, 0x28],                    ServerRejects)
  , ("crlf",             C8.pack "a\r\nb",                        RoundTripsAnyway)
  , ("trailing-newline", C8.pack "a\n",                           RoundTripsAnyway)
  -- THE DISCRIMINATING MEMBER. MEASURED on PG 18.4: 61 5c 31 30 31 62 (6 bytes) comes back
  -- as 61 41 62 (3 bytes) with NO error, because byteain still accepts the legacy escape
  -- format and re-reads \101 as one octal byte. Every other member either throws (which is
  -- shaped like a dead connection) or survives (which proves nothing). Do not remove it.
  , ("octal-escape",     C8.pack "a\\101b",                       SilentlyCorrupted)
  , ("double-backslash", C8.pack "a\\\\b",                        SilentlyCorrupted)
  ]
```

### The `key_scheme` orphaning proof (KEY-07)

```sql
-- Source: measured shape; the constraint is unique (model, key_scheme, key)
insert into model_run (model, key_scheme, key, raw, doc, …)
     values ('mev_tax_model_one', 1, '\x0badc0de', '\x00', '{}', …);

-- A lookup under the CURRENT scheme must return nothing. Not a near-miss, not a warning.
select count(*) from model_run
 where model = 'mev_tax_model_one' and key_scheme = 2 and key = '\x0badc0de';   -- expect 0

-- And the same key under a new scheme must INSERT, not conflict.
insert into model_run (model, key_scheme, key, raw, doc, …)
     values ('mev_tax_model_one', 2, '\x0badc0de', '\x01', '{}', …);            -- expect 1 row
```

### The advisory lock (DB-01)

```haskell
-- MEASURED: pg_try_advisory_lock returns f while held by another session, t after release.
-- The blocking form is correct in production; the try form is what makes the TEST deterministic.
with_migration_lock :: Connection -> IO a -> IO a
with_migration_lock con =
  bracket_ (() <$ execute_ con "select pg_advisory_lock(872304)")
           (() <$ execute_ con "select pg_advisory_unlock(872304)")
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **None, by design.** A hand-rolled `exitcode-stdio-1.0` runner: `data Check = Check { check_name :: String, check_run :: IO (Either String ()) }` (`offchain/test/Main.hs:379`). Every check runs; the process exits non-zero if any failed |
| Config file | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` (line 167) |
| Registration point | `core_checks :: IO [Check]` (`offchain/test/Main.hs:5684`). A check not in this list does not exist |
| Quick run command | `cabal build --enable-tests -j all` |
| Full suite command | `cabal test` |
| Hard gates | zero `-Wall` warnings under `offchain/` (CI enforces with a positive control **and** a compiled-module floor); `cabal build` **without** `--enable-tests` is VACUOUS and never counts |
| Baseline | 91/91 at v5.0 merge (`STATE.md`); 78/85 in a clean checkout with no rig manifest (CI header). **Re-MEASURE cold at plan time** — do not inherit these |

**No new test file is created.** Phase 23 extends one file. That is the convention and deviating
from it would put checks outside `core_checks`, where the sentinel harness cannot re-run them.

### Requirement → Test Map

Every one of the nine requirements, the check that covers it, where it lives, the input that makes
it fail, and whether it needs a database. **No row needs a database in `cabal test`.**

| Req | Check name | Lives in | Tier | Input that makes it FAIL | Needs DB? |
|---|---|---|---|---|---|
| **BYTE-01** | `store_corpus_round_trips_byte_identically` | `Store.Laws` (run against `Store.Memory` in-suite; against `Store.Postgres` in the capture) | B + C | Any store whose `store_put`/`store_lookup` normalizes. Positive control: the `octal-escape` member returns 3 bytes not 6 | **No** (Tier B); yes for the capture only |
| **BYTE-01** | `store_conformance_digests_match_the_pinned_source_digest` | `offchain/test/Main.hs` | C | The recorded per-corpus-member sha256 in `store-conformance.json` differing from the digest recomputed **in Haskell from the corpus definition**. Pinned bare-hex in source, never read from the artifact beside the bytes | **No** |
| **BYTE-05** | `bare_bytestring_is_observed_corrupting_the_artifact` | `offchain/test/Main.hs` asserting over `store-conformance.json`'s `negative_control` block | C | The artifact recording `SilentlyCorrupted` members as having round-tripped, **or** recording every member as `ServerRejects` (which means the corpus lost its discriminating member) | **No** |
| **BYTE-05** | `adversarial_corpus_has_a_silently_corrupted_member` | `offchain/test/Main.hs` | A (pure) | Deleting `octal-escape`/`double-backslash` from `adversarial_corpus`. A SET assertion over the behaviour tags, not a count | **No** |
| **BYTE-02** | `jsonb_round_trip_of_the_real_shape_is_exhibited_failing` | `offchain/test/Main.hs` asserting over `store-conformance.json`'s `jsonb_exhibit` block | C | The artifact recording the `bytea` sha256 and the `jsonb`-round-trip sha256 as **equal**. The exhibit must show them DIFFERING; equality means the exhibit stopped exercising `jsonb` | **No** |
| **BYTE-02** | *(no check — a type error)* | `Store.Types` | compile | `DerivedDoc` gaining an `Eq` instance, or a `DerivedDoc -> Artifact` converter appearing | **No** |
| **BYTE-03** | `aeson_round_trip_mutations_are_re_measured` | `offchain/test/Main.hs` | A (pure) | aeson ceasing to mutate — i.e. `decode >=> encode` becoming the identity on the pinned inputs. Re-MEASURED here, not cited: `0.00318353 → 3.18353e-3`, `2.8e19 → 28000000000000000000` | **No** |
| **BYTE-03** | `aeson_is_absent_from_the_storage_path` | `offchain/test/Main.hs`, `sc3_literal_purge` idiom (grep + positive control) | A | Introducing `encode`/`toJSON`/`Data.Aeson` into `offchain/lib/Store/Postgres.hs` or the publication path. **Positive control mandatory**: the pattern must be SHOWN matching a seeded bait file, else absence is evidence of nothing | **No** |
| **DB-01** | `migration_list_is_ordered_and_gapless` | `Store.Schema` + a `pure_check` | A | Reordering, duplicating or skipping a version in the pure `[(version, name)]` list | **No** |
| **DB-01** | `store_conformance_records_a_nonzero_exit_on_checksum_drift` | `offchain/test/Main.hs` over the artifact's `migration` block | C | The artifact recording `checksum_drift_exit == 0`. `postgresql-migration` returns `MigrationError` and the process exits 0 — the guard is the caller's `exitFailure` and the OBSERVATION is `echo $?` == 1 after appending one comment line to `001_*.sql` | **No** |
| **DB-01** | `store_conformance_records_the_second_migrator_applying_nothing` | `offchain/test/Main.hs` over the artifact's `concurrency` block | C | The artifact recording `try_advisory_lock == true` for the second migrator, or `applied_by_second /= 0`. MEASURED deterministic: `f` while held, `t` after release | **No** |
| **DB-01** | `store_conformance_records_two_runs_from_an_empty_database` | `offchain/test/Main.hs` over the artifact | C | The artifact recording only one run, or a non-empty starting database. `git clean -ffdx` makes empty the CI norm | **No** |
| **DB-02** | `every_advertised_override_is_honoured` **extended** with `PGSTORE_DSN` and `STORE_CONFORMANCE` | `offchain/test/Main.hs:3561` `advertised_overrides` | A | (1) the resolver ignoring the variable; (2) resolving to the same value set and unset; (3) the consumer loading anyway from a bogus path; (4) the failure text not NAMING the resolved path. Probe path: `/nonexistent-override-probe/PGSTORE_DSN.json` | **No** |
| **DB-02** | `no_credential_is_present_in_a_tracked_file` | `offchain/test/Main.hs`, `sc3_literal_purge` idiom | A | A password, DSN or host literal appearing under `offchain/`. Needs its own positive control | **No** |
| **DB-03** | `store_laws_run_against_the_memory_store` | `Store.Laws` × `Store.Memory` in `core_checks` | B | Any law failing against the reference implementation. These are **real executions**, not assertions over a file — this is where DB-03's "still discriminate" is actually delivered | **No** |
| **DB-03** | `expected_store_laws_is_the_law_set` | `offchain/test/Main.hs`, `expected_selector_pins` idiom (`Main.hs:424`) | A | Renaming, adding or removing a law in `Store.Laws` without editing the SET. Asserted in **both** directions against `Store.Laws`'s own list AND the artifact's verdict keys — a missing verdict is a set mismatch, so a skipped law cannot inflate a count | **No** |
| **DB-03** | `store_conformance_is_present_and_fresh` | `offchain/test/Main.hs`, `rpin05_capture_is_present_and_fresh` idiom | C | The artifact absent (**FAIL, never skip** — naming the capture command); `sc_complete == False`; `sc_law_count /= length expected_store_laws`; or the recorded migration `(filename, md5)` list differing from the md5s **recomputed from the repo's `.sql` files**. Freshness is COMPUTED, never a timestamp | **No** |
| **DB-03** | `store_conformance_verdicts_are_all_pass` | `offchain/test/Main.hs` | C | Any recorded verdict not `pass`; any verdict key not in `expected_store_laws`; any expected law with no verdict | **No** |
| **DB-03** | `sentinel_falsification_harness` **extended** — `store-conformance.json` in `swept_artifacts` + a new `artifact_field_floors` entry | `offchain/test/Main.hs:5019`, `:5465` | A | Any leaf of the artifact that no check asserts comes back as an **absorbed** pair and fails the harness by name. This is the "sentinel store deliberately wired wrong" instrument, with positive and negative controls already built | **No** |
| **DB-04** | `store_conformance_records_the_pinned_image_and_server_version` | `offchain/test/Main.hs` | C | The artifact recording a server version other than the pinned `18.x`, or the image tag drifting from `postgres:18-alpine`. The capture script exits non-zero naming `docker` when it is absent — never emits a partial artifact | **No** |
| **KEY-07** | `key_scheme_orphans_rather_than_matching` | `Store.Laws` (Memory) **and** the artifact (Postgres) | B + C | A lookup under scheme 2 returning a row written under scheme 1; or an insert of the same `(model, key)` under a new scheme raising a unique violation instead of succeeding | **No** (Tier B) |
| **KEY-07** | `unique_constraint_names_all_three_columns` | `Store.Schema` `pure_check` + the artifact's recorded `pg_indexes` row | A + C | The constraint DDL in the `.sql` omitting `key_scheme`. Asserted against the **live catalogue** in the capture, not only against the file the migration was read from | **No** |

### DB-03: the roadmap's design, evaluated and improved

The roadmap's answer is `CFMM_REQUIRE_DB=1` forcing RED when no database is reachable, plus a count
floor on executed store checks to catch skip-inflation. Three problems, and a replacement.

**Problem 1 — the variable fails OPEN.** `CFMM_REQUIRE_DB=1` is set in CI. If the workflow's `env:`
block drifts, or a job is added that forgets it, the suite silently returns to skip-mode and is
green. That is `RIG_MANIFEST` advertised-and-dead, one layer up, and this repo has measured that
exact shape three times. A safety property must not live in another system's configuration — the
CI's own `-Wall` gate comment says precisely this about `git clean -ffdx` ("safety living in another
system's DEFAULT rather than in the check").

**Problem 2 — the question is already dissolved.** Under the three-tier decision, *nothing in
`cabal test` touches a database*. There is therefore nothing for the variable to gate; and any check
that consults it is by construction a DB-dependent check, which means the tier decision has been
broken. The absent subject for `cabal test` is not Postgres — it is `store-conformance.json`, which
is **committed**, so a fresh checkout has it, so "FAIL, never skip" costs nothing and is
unconditional. (Contrast `rig-manifest.json`, which is gitignored; the suite fails loudly on it
anyway, and CI stands the rig up in-job. The conformance artifact is strictly easier.)

**Problem 3 — a count floor is the weakest of the three instruments, and the repo knows it.**
`expected_selector_pins` is a SET, in this file, with the reason written down: *"a floor of thirty
is satisfied by thirty pins of which one has been swapped."* A floor on *executed store checks* is
defeated by the same rename, which is finding #3 verbatim.

**The replacement.** Seven parts; the roadmap's two survive in reduced roles.

1. **Structural, not policy.** No check in `cabal test` opens a socket. DB-03's first half is
   satisfied by construction rather than by a branch, and there is no branch to misconfigure.
2. **Tier B is where "still discriminate" is delivered.** `store_laws` runs for real against
   `Store.Memory` — real execution of the store contract with no server. This is the part the
   `CFMM_REQUIRE_DB` framing under-weights: most of the discrimination never needed a database.
3. **The law surface is a SET, asserted in both directions**, against `Store.Laws`'s own list *and*
   against the artifact's verdict keys. A skipped law is a *missing verdict*, i.e. a set mismatch —
   skip-inflation becomes structurally unrepresentable rather than detectable.
4. **Freshness is COMPUTED, not stamped.** The artifact records the migration `(filename, md5)`
   list, the law set and the PG server version; the suite recomputes the md5s from the repo's own
   `.sql` files and reddens on drift. Editing a migration without re-capturing is a red. This is the
   `sc4_generated_from_is_the_imported_ref` idiom and it answers the *stale artifact* hole that the
   `CFMM_REQUIRE_DB` design leaves entirely open.
5. **`CFMM_REQUIRE_DB=1` is RETAINED but RELOCATED to `offchain/rig/capture-store-conformance.sh`**,
   where it means "refuse to emit an artifact at all if the database is unreachable". Its failure
   mode becomes a *stale* artifact — caught by (4) — instead of a *truncated* one, which nothing
   catches. Kept because CI should still fail loudly when it cannot provision Postgres; moved
   because gating `cabal test` on it is what fails open.
6. **The count floor SURVIVES as a secondary instrument only**: `sc_complete :: Bool` plus
   `sc_law_count :: Int` recorded in the artifact and compared to `length expected_store_laws`, in
   the `dr_complete` / `dr_configured_size` idiom (`Driver/Capture.hs:93-98`), so a truncated capture
   is visible without arithmetic. It is never the primary instrument.
7. **The sentinel harness does the "deliberately-wrong store" work.** Registering
   `store-conformance.json` in `swept_artifacts` mutates every leaf with all six sentinels and fails
   on any leaf nothing asserts — with positive and negative controls already built and already
   proven. A bespoke sentinel check would have neither.

**Net effect on the roadmap's SC-5.** Its clauses survive with one substitution: "`CFMM_REQUIRE_DB=1`
and no database reachable ⇒ the suite is RED" becomes "`CFMM_REQUIRE_DB=1` and no database
reachable ⇒ **the capture** is RED and emits nothing, and the suite is RED on the resulting stale or
absent artifact". The other clauses — the law SET, the count floor on executed store checks, the
`PGSTORE_DSN`/`STORE_CONFORMANCE` override registration with the consumer failing loudly and naming
the path — are adopted unchanged.

### Every guard, and the input that makes it fire

A guard never seen to reject is the empty-log finding. One row per guard; no row says "invalid
input".

| Guard | The exact input that makes it fire | Observation |
|---|---|---|
| `Binary` newtype on write | `a\101b` = `61 5c 31 30 31 62` | readback is `61 41 62`, **length 6 → 3, no error**. MEASURED |
| `Binary` newtype on write (secondary) | `0x00`, `0xFF`, `0xC3 0x28` | `ERROR: invalid byte sequence for encoding "UTF8"`. MEASURED. Recorded as `ServerRejects` so it is never mistaken for the value-level kill |
| corpus discrimination | delete `octal-escape` from `adversarial_corpus` | the behaviour-tag SET assertion reddens |
| `bytea` authoritative | the real 606-byte `volume_path.json` | `jsonb` round-trip reorders keys; the two sha256s differ. Equal digests ⇒ the exhibit stopped exercising `jsonb` ⇒ RED |
| `jsonb` never compared | add `deriving Eq` to `DerivedDoc`, or write a `DerivedDoc -> Artifact` converter | compile error / source-scan red |
| aeson off the storage path | add `encode` to `Store/Postgres.hs` | grep check with a proven positive control |
| aeson still mutates | pin `0.00318353` and `2.8e19` | re-measured each run; a round-trip that became the identity reddens (the guard's own subject vanished) |
| migration checksum drift | append one comment line to `001_*.sql` | `MigrationError "Checksum mismatch"` **and** process exit 1 (the `exitFailure` we add). Exit 0 ⇒ RED |
| migration concurrency | second migrator calls `pg_try_advisory_lock(872304)` while the first holds it | returns `f`; second applies 0 migrations. MEASURED |
| migration from empty | fresh `docker run --rm postgres:18-alpine`, run twice | both `MigrationSuccess`; second applies 0 |
| `key_scheme` orphaning | write under scheme 1, look up under scheme 2 | **0 rows.** And the same `(model, key)` under scheme 2 INSERTS rather than conflicting |
| unique constraint completeness | drop `key_scheme` from the constraint DDL | the recorded `pg_indexes` row no longer names all three columns |
| `PGSTORE_DSN` override | `PGSTORE_DSN=/nonexistent-override-probe/PGSTORE_DSN.json` | consumer fails and the message CONTAINS that path |
| `STORE_CONFORMANCE` override | same probe shape | same |
| conformance freshness | edit any `.sql` under the migration directory without re-capturing | recomputed md5 ≠ recorded md5 |
| conformance completeness | truncate the capture mid-run | `sc_complete == False`, or `sc_law_count` short |
| law SET | rename one law in `Store.Laws` | set mismatch in both directions |
| sentinel harness | any new artifact leaf that no check reads | reported as an **absorbed** pair, by name, with its sentinel |
| `sc3_literal_purge` | a `0x`-prefixed 8/40/64-hex literal in a `.hs`, `.sh` or (newly) `.sql` file under `offchain/` | grep exit 0. Note the digest pin must be written **bare** |

### Sampling Rate

- **Per task commit:** `cabal build --enable-tests -j all` — `--enable-tests` is load-bearing;
  without it the command exits 0 without ever compiling the suite. Measured four times.
- **Per wave merge:** `cabal test` (full `core_checks` + `sentinel_falsification_harness`) with
  **zero `-Wall` warnings** under `offchain/`.
- **Phase gate:** full suite green; `-Wall` clean; `bash offchain/rig/capture-store-conformance.sh`
  re-run from a fresh container producing an artifact whose verdicts are all `pass`; every guard in
  the table above OBSERVED firing at least once with its named input, and the observation recorded.
- **Do not** run the capture inside `cabal test`, and do not run the driver that rewrites a tracked
  artifact it is being checked against — the CI workflow already documents why (it converts a
  staleness failure into a silent pass).

### Wave 0 Gaps

There is no test *file* to create — the suite is one file and one runner. The gaps are registration
points and infrastructure, all of which must exist before the first store assertion is written.

- [ ] `.cabal` library stanza — `postgresql-simple`, `postgresql-migration`, `crypton`, with the
      package-count comment in the existing lines 107–115 discipline (+6 packages, MEASURED)
- [ ] `.cabal` — ~7 new `Store.*` `exposed-modules`; a new `executable store-conformance` stanza
      in the `cheat-swap-proof` family. **Note the CI compiled-module floor**
      (`find offchain/{lib,app,test} -name '*.hs' | wc -l`) rises with every new module and is
      computed from the tree, so no constant needs editing — but a `.hs` in a source dir listed in
      **no component** is never `-Wall`-checked and shows up as a shortfall
- [ ] `offchain/test/Main.hs` — `expected_store_laws :: [String]` in the `expected_selector_pins`
      idiom (`:424`)
- [ ] `offchain/test/Main.hs` — two new `OverrideProbe` entries in `advertised_overrides` (`:3561`)
- [ ] `offchain/test/Main.hs` — `store-conformance.json` in `swept_artifacts` (`:5019`) **and** a new
      `artifact_field_floors` entry (`:5465`), both with the floor MEASURED, not guessed. Budget the
      cost: the harness re-runs `core_checks` once per (leaf × 6 sentinels); a 40-leaf artifact adds
      ~240 pairs to the current 2457
- [ ] `offchain/test/Main.hs` — `purge_known_extensions` **and** `purge_scanned_extensions` gain
      `".sql"` (SQL is executed), and `purge_file_floor` is re-MEASURED upward from 36. **Mandatory
      the moment the first `.sql` lands under `offchain/`** — measured: the extension census is
      exactly the five present types and the floor has zero slack
- [ ] `offchain/test/Main.hs` — ~14 new `Check` values wired into `core_checks` (`:5684`). A check
      not in this list does not exist and the sentinel harness cannot re-run it
- [ ] `offchain/rig/capture-store-conformance.sh` — `deploy-rig.sh` idiom; `docker run --rm
      postgres:18-alpine` on a **non-default host port** (55433 was used for today's probe) so a
      developer's local Postgres cannot silently satisfy a CI connection; per-run database name
- [ ] `offchain/rig/store-conformance.json` — committed evidence. Design it **narrow**: every leaf
      must be either asserted or pardoned in `absorbed_by_design` with a written reason
- [ ] `offchain/rig/volume-path-golden.json` (or similar) — the real 606-byte artifact copied in
      from the `cfmm-gams` worktree, with provenance recorded and its sha256 pinned **bare** in
      Haskell source
- [ ] The migration `.sql` directory — decide its location **before** writing it (see the
      `sc3_literal_purge` gap above)
- [ ] `.github/workflows/develop-gate.yml` — Postgres provisioning in the `haskell` job. **This job
      has never executed**; its first run debuts both the gate and the Postgres wiring. STACK.md's
      standing recommendation: land the service block in a trivial PR *before* Phase 23's code
      depends on it

---

## State of the Art

| Old approach | Current approach | Impact |
|---|---|---|
| `cryptonite` for hashing | `crypton` 1.0.6 | `cryptonite` deprecated on Hackage (last upload 2022-03-13); `crypton` is already resolved, +0 packages |
| `tmp-postgres` for test databases | `docker run --rm postgres:<pinned>` in a capture tool | `tmp-postgres`'s last release is 2019-12-29 and it needs `initdb`/`pg_ctl`, absent here |
| Always-verify determinism | on-demand verification | Nix shipped `--repeat`/`enforce-determinism` and **removed them in 2.13** (2023-01-17) as "broken under many circumstances" |
| `jsonb` as the artifact column | `bytea` authoritative + `jsonb` derived | Measured three times; `jsonb` reorders keys and re-renders numbers through `numeric` |
| Default `jsonb_ops` GIN | `jsonb_path_ops` | Smaller, faster for `@>`; and it sidesteps the `?`/`??` placeholder wart |

**Deprecated / does not exist:**
- `Database.PostgreSQL.Simple.Binary` — **not a module.** `Binary` lives in
  `Database.PostgreSQL.Simple.Types`, re-exported by `Database.PostgreSQL.Simple`
- Bazel's `--experimental_repeated_by` — does not exist; absent from the flag reference,
  `bazel_flags.proto` and the release notes (SUMMARY.md)
- An advisory lock inside `postgresql-migration` — does not exist at 0.2.1.8 (source-read today)

---

## Open Questions

1. **Where do the migration `.sql` files live?**
   - What we know: anywhere under `offchain/` triggers three `sc3_literal_purge` edits, measured.
   - What's unclear: whether the project prefers `offchain/migrations/` (paying the edits, which is
     the *correct* answer since SQL is executed and should be scanned) or a top-level `migrations/`
     (avoiding them, but putting executable content outside the purge's reach — which is exactly the
     "undeclared type is EXEMPT and nothing says so" hole the check warns about).
   - Recommendation: **`offchain/migrations/`**, and add `.sql` to *both* lists. Free-passing an
     executable file type is the worse trade.

2. **Do GH Actions `services:` containers work on the `cfmm-build` executor?**
   - What we know: Docker 29.5.2 works there; the `haskell` job has never executed at all.
   - What's unclear: `services:` on a *non-containerized* self-hosted runner needs explicit port
     mapping, and nobody has run it.
   - Recommendation: the per-run-database strategy was chosen partly because it does not depend on
     the answer. Prefer an explicit `docker run` step over `services:` for exactly that reason, and
     land the wiring in a trivial PR before Phase 23's code depends on it.

3. **How narrow can `store-conformance.json` be?**
   - What we know: every leaf must be asserted or pardoned with a reason, and each leaf costs six
     full suite re-runs in the sentinel harness.
   - Recommendation: verdicts keyed by law name, plus a small fixed provenance block (server
     version, image tag, migration `(filename, md5)` list, `sc_complete`, `sc_law_count`, corpus
     behaviour tags). Resist recording anything a check will not read.

4. **Does the pips denominator belong in `key_scheme`'s scope?** (Phase 25's problem, flagged here.)
   - `key_scheme` is what makes a later key-formula change additive. Phase 23 only needs to ship the
     column and the constraint; nothing here should try to fix the key's *contents*.

5. **What is the correct `sentinel_pair_floor` after the fifth artifact lands?**
   - Must be re-MEASURED at plan time, not incremented by guesswork. Currently 2457 with four
     artifacts.

---

## Sources

### Primary — executed on this machine today (HIGH)
- `postgres:18-alpine` in Docker (`server_version` 18.4, `standard_conforming_strings=on`,
  `bytea_output=hex`): the text-vs-`bytea` corruption transcript; the UTF-8 rejections for `0x00`
  and `0xFF`; the CRLF/trailing-newline pass-through; `pg_advisory_lock` / `pg_try_advisory_lock`
  behaviour across two sessions. Container removed after measurement
- `postgresql-simple-0.7.0.1` source: `Types.hs:146` (`newtype Binary`), `ToField.hs:78,201-206`
  (`Escape` vs `EscapeByteA`), `FromField.hs:391-394,412-419,640` (the read-side `bytea`
  special-case, `okBinary`)
- `postgresql-migration-0.2.1.8` source: `Migration.hs:76-262,281-400` (`runMigrations'`,
  `doRunTransaction`, `checkScript`, `initializeSchema`, `MigrationOptions`) — no advisory lock
- `find` / `sha256sum` over `/tmp/vp/volume_path.json` and the `cfmm-gams` worktree copy: 606 bytes,
  `e7b14f38…`, trailing newline `5d 0a 7d 0a`, byte-identical at two paths
- The tree: `offchain/` extension census (5 types, 36 scanned files) against
  `purge_known_extensions`, `purge_scanned_extensions` and `purge_file_floor = 36`

### Primary — this repository, read directly (HIGH)
- `offchain/test/Main.hs` — `Check`:379, `guarded`:385, `expected_selector_pins`:424,
  `sc3_load_succeeds`:729, `purge_pattern`:824, `purge_*_extensions`:835-846,
  `advertised_overrides`:3561, `every_advertised_override_is_honoured`:3607, `probe_override`:3613,
  `sentinels`:4998, `swept_artifacts`:5019, `outside_repo`:5061, `sweep_one`:5160,
  `absorbed_by_design`:5302, `sentinel_pair_floor`:5459, `artifact_field_floors`:5465,
  `sentinel_falsification_harness`:5477, `main`:5664, `core_checks`:5684
- `offchain/lib/Rig/Manifest.hs:191-197` (the `lookupEnv` override idiom),
  `offchain/lib/Driver/Capture.hs:93-98,319-327` (`dr_complete`/`dr_configured_size`, `capture_path`)
- `.github/workflows/develop-gate.yml:130-282,438-459` — the `haskell` job, the `-Wall` gate's
  positive control and compiled-module floor, the `git clean -ffdx` note, the flock, `cabal test`
- `cfmm-replicationPlank-rpc-api.cabal` — existing dependency set and comment discipline
- `.planning/config.json` — `nyquist_validation: true`

### Secondary — settled prior research, cited not re-derived (HIGH)
- `.planning/research/SUMMARY.md`, `STACK.md`, `ARCHITECTURE.md`, `PITFALLS.md` (2026-08-16)
- `.planning/ROADMAP.md` Phase 23 §, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`

### External (MEDIUM — official docs)
- PostgreSQL 18 `datatype-binary` — `bytea` input formats, hex and legacy escape
- PostgreSQL 18 `datatype-json` — `jsonb` normalization
- PostgreSQL 18 `functions-admin` — advisory lock functions

---

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — inherited from measured research; both tarballs re-confirmed in the
  local store today
- Schema / architecture: **HIGH** — measured three times independently in prior research; the
  two-column decision is not in doubt
- New measurements (the corruption byte, the missing advisory lock, the `.sql` purge collision, the
  606-byte artifact): **HIGH** — each executed or source-read today, transcripts above
- Validation architecture: **HIGH** for the mechanism (every instrument already runs in this repo
  and has proven controls); **MEDIUM** for the floors and counts, which must be re-MEASURED at plan
  time rather than inherited
- CI Postgres provisioning: **MEDIUM** — Docker measured; `services:` on this specific self-hosted
  runner remains unexercised, and the `haskell` job has never run at all

**Research date:** 2026-08-16
**Valid until:** ~2026-09-15 for the stack (stable). The `-Wall` module floor, `purge_file_floor`,
`sentinel_pair_floor` and the suite's pass count are **tree-derived and go stale on any commit** —
re-measure them at plan time, never inherit them from this document.
