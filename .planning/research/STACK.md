# Stack Research

**Domain:** Postgres/JSONB content-addressed model-output store + external-solver subprocess layer, in Haskell (GHC 9.10.3)
**Researched:** 2026-08-16
**Confidence:** HIGH

> **Method note — these are measurements, not recollections.**
> Every version below was read from a Hackage index refreshed **today** (`cabal update` →
> `index-state: 2026-08-16T11:47:09Z`). Every GHC-9.10.3 compatibility claim was established by
> **actually compiling the package** with the project's own `ghc-9.10.3` / `cabal-install 3.16.1.0`,
> not by reading version bounds. Every dependency-footprint number was computed by diffing
> `plan.json` package sets against this project's real 152-package baseline. Every JSONB/migration
> behaviour was executed against a live **PostgreSQL 18.4** instance. The project's `.cabal` was
> mutated during probing and **restored** (`git diff` clean).

---

## Headline: the premise of the question is wrong, and that changes the decision

The brief anticipated that "several of these lag on new GHC." **They do not.** I built all of them:

| Candidate | Builds on GHC 9.10.3? | Evidence |
|-----------|----------------------|----------|
| `postgresql-simple` | **YES** | already compiled in the local `ghc-9.10.3` store |
| `hasql` + `hasql-pool` + `hasql-transaction` | **YES** | built from scratch, exit 0 |
| `hasql-th` | **YES** | built from scratch, exit 0 |
| `persistent` + `persistent-postgresql` | **YES** | built from scratch, exit 0 |
| `esqueleto` | **YES** | built from scratch, exit 0 |
| `beam-core` + `beam-postgres` | **YES** | built from scratch, exit 0 (slow: drags in `happy`, `haskell-src-exts`) |
| `opaleye` | **YES** | already compiled in the local `ghc-9.10.3` store |

**There is no GHC-9.10.3 exclusion to make this decision for us.** So the decision must be made on
*footprint, ergonomics, and fit* — which is where the candidates separate sharply.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **PostgreSQL** | **18.4** | JSONB store | Already the target. `jsonb_path_ops` GIN gives smaller/faster `@>` indexes than default `jsonb_ops`. Server is **not installed on this machine** — see CI section. |
| **`postgresql-simple`** | **0.7.0.1** | DB client | **+4 packages.** Raw SQL, no DSL, no TH, no monad transformer stack. You write the `@>` / `->>` / GIN DDL literally as SQL. This is the only candidate whose model of the world ("a query is a string, a row is a tuple") matches a codebase that hand-rolls its own `Check` list rather than adopt tasty. |
| **`postgresql-migration`** | **0.2.1.8** | Migrations | **+2 over the client.** Plain `.sql` files in a directory + a runner — the hand-rolled shape — but with **MD5 checksum drift detection** you would otherwise have to write yourself. Verified: it catches a tampered file. |
| **`typed-process`** | **0.2.13.0** | GAMS subprocess | **+2 packages.** `readProcess` returns `(ExitCode, stdout, stderr)` — the exact triple `VOLUME_PATH.md` §4 needs — and is `bracket`-protected so `System.Timeout.timeout` reliably kills the child. |
| **`crypton`** | **1.0.6** | Content-address hash | **+0 packages — already in the resolved plan.** Provides `Crypto.Hash (SHA256, hashWith)`. |

**Total footprint of the entire recommendation: +9 packages** on a 152-package baseline
(`Only`, `cryptohash-md5`, `postgresql-libpq`, `postgresql-libpq-configure`, `postgresql-migration`,
`postgresql-simple`, `resource-pool`, `typed-process`, `unliftio-core`). Measured, not estimated.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `resource-pool` | 0.5.1.0 | Connection pool | **Only if you need concurrency.** `postgresql-simple` has no built-in pool. The resident re-solve loop is single-threaded — one `Connection` is correct and simpler. Add this *when* a second concurrent consumer appears, not before. |
| `aeson` | **2.2.5.0** (pinned) | JSON | Already a direct dep. **Note the pin** (see Version Compatibility). |
| `bytestring`, `text`, `directory`, `filepath` | in plan | raw bytes / paths | Already direct deps. The canonical-serialization and raw-payload columns use `ByteString`. |
| `postgresql-libpq` | 0.11.0.0 | FFI to libpq | Transitive via `postgresql-simple`. `libpq 18.4` **is** installed system-wide (`pg_config --version` → 18.4), so this compiles with no extra setup. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Docker | Postgres for tests/CI | `docker` 29.5.2 present. `postgres:18-alpine` went from `docker run` to `pg_isready` in **3 seconds** (measured). |
| `psql` | Manual inspection | `/usr/bin/psql` present (client only). |
| `cabal build --enable-tests -j all` | The real gate | Unchanged. Per project law, **without** `--enable-tests` it is vacuous. |

---

## Installation

This is a `cabal` project, not npm. Add to `build-depends` in
`cfmm-replicationPlank-rpc-api.cabal` (library stanza):

```cabal
                      postgresql-simple,      -- 0.7.0.1  DB client
                      postgresql-migration,   -- 0.2.1.8  checksummed .sql runner
                      typed-process,          -- 0.2.13.0 GAMS subprocess, exit-code gated
                      crypton                 -- 1.0.6    SHA256; ALREADY in the plan (+0 pkgs)
```

Do **not** add `resource-pool` yet (see above). Verify with:

```bash
cabal build --enable-tests -j all     # the only gate that counts
```

System prerequisite already satisfied on this machine: `libpq` 18.4 (`/usr/lib/libpq.so`).

---

## The Postgres client decision — ranked, with reasons

### 1. `postgresql-simple` 0.7.0.1 — **RECOMMENDED**

**Footprint: +4** (`Only`, `postgresql-libpq`, `postgresql-libpq-configure`, `postgresql-simple`).
**Template Haskell: none required.** **GHC 9.10.3: builds (already in store).**

JSONB support verified live against PG 18.4:

- `FromField JSON.Value` accepts **both** `jsonOid` and `jsonbOid` (source: `FromField.hs:588`).
- `fromFieldJSONByteString` returns the **raw `ByteString`** — needed for the byte-exact check.
- `@>`, `->>`, GIN `jsonb_path_ops` all worked in a real query.

It wins because it is the only option that does not interpose a model between you and SQL. The
store's whole job is operator-heavy JSONB and a byte-exact reproducibility assertion; every other
candidate makes you either escape out of its abstraction or adopt one you don't need.

**The one genuine wart — and it is subtler than the docs say.** `postgresql-simple` uses `?` as its
parameter placeholder, which collides with the JSONB existence operators `?`, `?|`, `?&`. Its own
source comments this (`Simple.hs:285`): *"escapes double '??'s to make literal '?'s possible in
PostgreSQL queries using the JSON operators."* **But I found empirically that the rule depends on
which function you call:**

| Function | Substitution runs? | Write the existence operator as |
|----------|-------------------|--------------------------------|
| `query` / `execute` (takes params) | yes | `??` |
| `query_` / `execute_` (no params) | **no — SQL passed verbatim** | `?` |

Using `??` in `query_` fails at runtime with `SqlError … "operator does not exist: jsonb ?? unknown"`.
Both forms confirmed working in their correct contexts. **`@>` and `->>` contain no `?` and are
entirely unaffected** — and `@>` is the operator this store actually leans on, so the wart is
marginal in practice.

### 2. `hasql` 2.0.1.0 (+ `hasql-pool` 1.5.0.1, `hasql-transaction` 1.2.3.0) — strong runner-up

**Footprint: +18** (or **+22** with `hasql-th`). **GHC 9.10.3: builds (verified from scratch).**

Genuinely excellent on the merits: first-class `jsonb`, **`jsonbBytes`**, and `jsonbLazyBytes`
codecs (`Hasql/Codecs/Encoders/Value.hs:212-226`); `$1` placeholders so the `?` collision **does not
exist**; pooling is a first-party package rather than an afterthought; typically faster (binary
protocol).

**Why it still loses here:** it costs **4.5× the dependencies** for a store whose query surface is a
handful of statements, and it imposes an explicit encoder/decoder ceremony (`Statement`, `Session`,
`Encoders.param`, `Decoders.column`) on every query. That is precisely the "framework indirection"
this codebase has repeatedly declined. `hasql-th`'s compile-time SQL checking is the strongest
argument *for* it — but it is Template Haskell, adds `postgresql-syntax` + `headed-megaparsec` +
`selective`, and TH is absent from this project today.

**Choose `hasql` instead if** the store later becomes throughput-critical, or if you want
compile-time-validated SQL badly enough to accept TH. Both are defensible; neither is true yet.

### 3. `opaleye` 0.10.8.0 — no

**Footprint: +7.** **GHC 9.10.3: builds.** Small footprint, but it is a *typed relational-algebra
DSL* built on top of `postgresql-simple`. JSONB operators are second-class: you reach for
`Opaleye.Internal` or raw-SQL escape hatches to express `@>`. You pay for a query-composition
abstraction this store has no use for, and you still end up writing raw SQL for the interesting parts.

### 4. `beam-core` 0.11.1.0 + `beam-postgres` 0.6.3.0 — no

**Footprint: +29.** **GHC 9.10.3: builds** — but slowly, dragging in `happy`, `happy-lib`, and
`haskell-src-exts`. Heavy type-level machinery (`constraints-extras`, `dependent-sum`,
`vector-sized`, `finite-typelits`) producing famously difficult type errors. Wrong tool for four tables.

### 5. `persistent` 2.18.1.0 + `persistent-postgresql` 2.14.3.0 (+ `esqueleto` 3.6.0.2) — **no, and it is the worst fit**

**Footprint: +43 / +44.** **GHC 9.10.3: builds.** Disqualifying on three counts:

1. **Template Haskell is not optional** — the entity DSL (`mkPersist`/`share`) *is* the API.
2. It drags in an entire application substrate the project has no use for: `monad-logger`,
   `conduit`, `resourcet`, `unliftio`, `fast-logger`, `blaze-html`, `http-api-data`, `vault`.
3. Its schema model is row-oriented; a `<model>/<key>` JSONB blob store is exactly the shape
   `persistent` handles worst, and `esqueleto` exists precisely because `persistent` can't express
   real SQL.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `postgresql-simple` | `hasql` (+pool, +transaction) | Throughput becomes critical, or many concurrent sessions; or you want `hasql-th` compile-time SQL validation and accept TH. Note `$1` placeholders remove the `?`/`??` wart entirely. |
| `postgresql-migration` | Hand-rolled `.sql` runner | If +2 packages is truly unacceptable. You then owe yourself the checksum table — the drift detection is the whole value. |
| `postgresql-migration` | `dbmigrations` 2.1.0 | Solves on 9.10.3, but is a CLI-first tool with a dependency-store abstraction and richer dependency-ordering. Overkill; `postgresql-migration` reads a plain directory. |
| `typed-process` | `process` 1.6.26.1 (already in plan) | If +2 packages is unacceptable. `readProcessWithExitCode` gives the same `(ExitCode, String, String)` triple — but `String`, not `ByteString`, and you must handle child cleanup on timeout yourself. |
| `crypton` SHA256 | `web3-crypto` `keccak256` | If you want the key to match an on-chain hash. `Crypto.Ethereum.Utils.keccak256` is confirmed present and is itself a thin wrapper over crypton's `hashWith Keccak_256`. Both are already in the closure; SHA256 is the better default for a *database* key (no EVM semantics implied). |
| One `Connection` | `resource-pool` 0.5.1.0 | When a second concurrent DB consumer exists. Not at Phase 23. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`cryptonite`** | **Deprecated on Hackage** (last upload 2022-03-13). Hackage explicitly redirects to crypton. Would also be a genuinely *new* package. | `crypton` — **already in the resolved plan, +0 packages** |
| **`persistent` / `esqueleto`** | +43/+44 packages, mandatory TH, drags in `monad-logger`/`conduit`/`unliftio`/`blaze-html`; worst-fit data model | `postgresql-simple` |
| **`beam`** | +29 packages incl. `happy` + `haskell-src-exts`; severe type errors | `postgresql-simple` |
| **`opaleye`** | DSL you don't need; JSONB operators second-class | `postgresql-simple` |
| **`hasql-th`** | Introduces Template Haskell to a project with none, +22 packages | plain `hasql` if you go that route, else `postgresql-simple` |
| **Storing the solver payload *only* as `jsonb`** | **`jsonb` destroys bytes** — see the trap below. Silently breaks the milestone's core check. | `jsonb` for querying **plus** `bytea` for the canonical bytes |
| **Gating GAMS on stdout/stderr text** | `VOLUME_PATH.md` §4 forbids it; log text is not a contract | `ExitCode` from `readProcess` |
| **Trusting `runMigration`'s exit status** | It returns a `MigrationResult` **value**; a failed migration still exits **0** (measured) | Pattern-match `MigrationError` → `exitFailure` |

---

## The trap that would have silently broken this milestone

**PostgreSQL `jsonb` is a normalizing type. A `jsonb` round-trip is NOT byte-preserving.**

Official PG 18 docs: *"jsonb does not preserve white space, does not preserve the order of object
keys, and does not keep duplicate object keys."* I confirmed this live:

```
raw   bytea = {"z_last":1,"a_first":2,  "dup":1, "dup":3}
jsonb text  = {"dup": 3, "z_last": 1, "a_first": 2}
BYTE-IDENTICAL? False
```

Whitespace stripped, keys **reordered** (note: *not* lexicographic — jsonb orders by key length then
bytewise), duplicate key dropped with last-wins.

`PROJECT.md` makes *"same inputs + same toolchain → same bytes"* a **standing falsifiable check**.
If that check reads back a `jsonb` column, it is **not testing the solver** — it is testing
Postgres's normalizer, and it will report agreement even when GAMS output differs in key order, or
report spurious differences across a PG major upgrade.

**Required schema consequence:**

```sql
CREATE TABLE model_output (
  key      text  PRIMARY KEY,   -- H(canonical inputs ‖ GAMS ver ‖ CONOPT ver)
  model    text  NOT NULL,      -- '<model>' half of <model>/<key>
  payload  jsonb NOT NULL,      -- QUERY surface: @>, ->>, GIN
  raw      bytea NOT NULL       -- AUTHORITY: exact solver bytes; the byte-check reads THIS
);
CREATE INDEX model_output_gin ON model_output USING GIN (payload jsonb_path_ops);
```

The byte-for-byte re-solve check compares `raw`. The `payload` column is a derived, queryable
projection. Hash over `raw` (or over the canonical input serialization), **never** over `payload`.

**GIN opclass choice** (from PG 18 docs): `jsonb_path_ops` supports `@>`, `@?`, `@@` and is
"usually much smaller … search operations typically perform better." Default `jsonb_ops` additionally
supports `?`, `?|`, `?&`. **Use `jsonb_path_ops`** unless key-existence queries become load-bearing —
which also happens to sidestep the `??` wart.

---

## Hashing — what the key should be

**Use `crypton`'s SHA256. It costs zero new packages** (`crypton-1.0.6` is already in the resolved
plan, pulled transitively via `web3-crypto`). Verified working:

```haskell
import Crypto.Hash (SHA256(..), hashWith)
contentKey = show (hashWith SHA256 canonicalBytes)   -- lowercase hex, e.g. 2c31d952…
```

**Canonical serialization is the hard part, not the hash.** For stability across runs and machines:

- Fix field order explicitly (do **not** serialize a `Map`, and do **not** hash an `aeson` `encode`
  of a record — `aeson`'s object key order is not a stable contract).
- Render the seven numeric inputs as **exact decimal integers/rationals**. Never hash a `Double`'s
  textual rendering; binary floating-point formatting is the classic cross-machine drift source.
- Use an unambiguous separator that cannot occur in a field (I used `\x1f` US) so
  `("ab","c")` and `("a","bc")` cannot collide.
- Append the two version strings **inside** the hashed region — that is what makes the
  toolchain part of the identity, per the milestone definition.

`web3-crypto`'s `keccak256` (confirmed at `Crypto/Ethereum/Utils.hs:19`) is equally available and
also +0 packages — prefer it only if the key must line up with an on-chain hash.

**Watch for the `memory` skew.** My first attempt failed to compile with
`No instance for ByteArrayAccess (crypton-1.1.4:Digest SHA256)` because two `memory`/`crypton`
versions were in scope. Pinning `crypton <1.1` (matching what `web3-crypto` already forces) fixed it.
Using `show` on the `Digest` avoids the `ByteArray` bridge entirely — simplest and warning-free.

---

## Subprocess — `typed-process`, and why

**Recommendation: `typed-process` 0.2.13.0 (+2 packages: `typed-process`, `unliftio-core`).**

```haskell
readProcess :: MonadIO m => ProcessConfig s o e -> m (ExitCode, L.ByteString, L.ByteString)
```

That triple is exactly the §4 contract: **gate on `ExitCode`, keep stdout/stderr as captured
artifacts, never parse them for control flow.**

**Timeout safety — verified from source, not assumed.** `readProcess` is implemented as
`withProcess pc' …`, and `withProcess = withProcessTerm`, which is
`bracket (startProcess config) stopProcess`. Because the release action is `stopProcess`
(`= pCleanup`), an async exception — including the one `System.Timeout.timeout` delivers — runs
cleanup and **terminates the child**. So:

```haskell
System.Timeout.timeout micros (readProcess gamsCfg)
```

is safe and will not leak an orphaned GAMS process.

Note the haddock on `withProcessTerm` says it is "usually *not* what you want … see
typed-process#25" — that advice is aimed at people *interacting* with a long-lived child, where you
want to wait rather than kill. For **run-to-completion-or-timeout**, terminate-on-exception is
exactly the desired semantics, and `readProcess` already has it.

**`process` 1.6.26.1 is the honest fallback** — it is already in the plan (+0 packages) and
`readProcessWithExitCode` yields the same triple. It returns `String` rather than `ByteString`
(lossy/slow for large solver output, and encoding-sensitive), and you carry the cleanup burden
yourself. `System.Process` is not a separate option — it is the module `process` exports.
**+2 packages to get `ByteString` output and bracket-guaranteed child termination is worth it.**

---

## Connection/config — no hardcoding, consistent with `RIG_*`

**Verified live:** `connectPostgreSQL ""` connects using **only** libpq's standard environment
variables — with `DATABASE_URL` unset entirely:

```
DATABASE_URL present? False
connected via PG* env to db = probe
```

Recommended precedence, matching the existing `RIG_MANIFEST` / `RIG_PINS` / `DRIVER_CAPTURE` /
`RIG_SEED` idiom:

1. **`RIG_DATABASE_URL`** (project-namespaced override — consistent with the existing `RIG_*` family)
2. **`DATABASE_URL`** (the ecosystem-standard name CI tooling already sets)
3. **`""`** → libpq falls back to `PGHOST` / `PGPORT` / `PGUSER` / `PGPASSWORD` / `PGDATABASE`

All three land in one `ByteString` passed to `connectPostgreSQL`. **Fail loudly** if none resolve —
do not silently default to `localhost`, or a CI misconfiguration becomes a green run against the
developer's machine. Keep passwords out of the repo; `PGPASSWORD`/`.pgpass` are the standard routes.

---

## Migrations — `postgresql-migration`, verified end to end

Plain `.sql` files in a directory, applied by a runner — the hand-rolled shape, with the one part
you'd get wrong done for you. Measured behaviour:

```
init      = MigrationSuccess
apply     = MigrationSuccess
re-apply  = MigrationSuccess          (idempotent)
validate  = MigrationSuccess          (checksum)
--- after appending one comment line to 001_init.sql ---
apply     = MigrationError "001_init.sql"
validate  = MigrationError "Checksum mismatch: 001_init.sql"
```

`MigrationDirectory` reads ordinary SQL files; `MigrationValidation` is an **MD5 drift detector**.
For a milestone whose thesis is reproducibility, a migration set that notices when it has been
edited underneath you is worth 2 packages. Rolling this yourself means reimplementing the
`schema_migrations` table and the checksums.

**Two caveats, both measured:**

- **It does not exit non-zero.** `runMigration` returns `MigrationResult`; my tampered run printed
  `MigrationError` and the process still exited **0**. Pattern-match and call `exitFailure`
  yourself, or a broken migration passes CI.
- The API is `Database.PostgreSQL.Simple.Migration` — it is **`postgresql-simple`-native**. If you
  later switch to `hasql`, this choice does not come with you. That coupling is real and is an
  argument for deciding the client question once, now.

`dbmigrations` 2.1.0 also solves on 9.10.3 but is a heavier CLI-oriented tool with dependency
ordering this schema does not need.

---

## Postgres provisioning for CI (self-hosted runner)

**Measured on this machine:** no Postgres **server** (`postgres`, `initdb` absent from `PATH`);
`psql` client and `libpq` 18.4 present; **Docker 29.5.2 available**. `postgres:18-alpine` reached
`pg_isready` in **3 seconds**.

| Option | Trade-offs | Verdict |
|--------|-----------|---------|
| **GH Actions `services:` container** | Native `services:` block, health-checked, fresh DB per job, auto-torn-down. Requires Docker on the runner (**present**). Note: on a *self-hosted, non-containerized* runner the service port must be mapped to `localhost` (`ports: 5432:5432`) — the automatic container-network hostname trick only applies when the **job itself** runs in a container. | **RECOMMENDED** |
| **`docker compose` step** | Full control (extensions, `postgresql.conf`, init SQL); more YAML; you own readiness-polling and cleanup, and a crashed job can leak containers on a *persistent* self-hosted runner. | Good fallback if you need custom server config |
| **Local system cluster on the runner** | Fastest (no container start), but **not installed**, and it is persistent shared state on a runner that already serialises the gate with a host-wide `flock`. Cross-run contamination would undermine the reproducibility claim this milestone exists to make. | **Avoid** |

Two self-hosted-specific cautions this project has already been bitten by:

- **Port collisions.** The runner is shared and the gate is `flock`-serialised host-wide. Bind a
  **non-default host port** (I used `55433`) or scope the DB per job, so a developer's local
  Postgres cannot silently satisfy a CI connection.
- **The `haskell` gate job has never executed** (`19a06f3` merged with `--admin`). Its first real
  run will now also be the first run of the Postgres service wiring. Expect to debug **both** at
  once; consider landing the service block in a trivial PR before Phase 23's code depends on it.

---

## Version Compatibility

| Package | Constraint | Notes |
|---------|-----------|-------|
| `crypton` | **`>=0.30 && <1.1`** — forced by `web3-crypto` | Plan resolves **1.0.6**, though **1.1.4** is latest. Adding `crypton` directly is fine; **do not request `>=1.1`** or the plan breaks. |
| `aeson` | **`<2.3`** — forced by `web3-crypto` | Plan pins **2.2.5.0**; latest is **2.3.1.0**. Any new dependency demanding `aeson >=2.3` will conflict. *(Verified: `hasql` still solves inside the real project under this cap.)* |
| `base` | `web3-crypto` allows `<4.21` | GHC 9.10.3's `base` 4.20.x fits. **A future GHC 9.12 (`base` 4.21) would break `web3-crypto`** — out of scope now, but it caps the compiler. |
| `postgresql-simple` | `0.7.0.1` | `postgresql-migration` requires `>=0.4 && <0.8` — compatible. |
| `postgresql-libpq` | `0.11.0.0` | Needs system `libpq`; **18.4 present**. |
| `process` | `1.6.26.1` in plan (latest 1.6.30.0) | GHC boot library; leave it alone. |
| PostgreSQL server | **18.x** | Pin the CI image tag (`postgres:18-alpine`). A major-version change can alter `jsonb` numeric rendering — pin it, since `payload::text` stability is assumed nowhere but confusion is cheap to avoid. |

**All candidate integrations were re-verified inside the real project**, not just standalone:
`postgresql-simple`, `postgresql-simple + postgresql-migration`, `hasql` trio, `hasql + hasql-th`,
`typed-process`, and `crypton` each produce a valid plan alongside the existing `hs-web3` closure.

---

## Stack Patterns by Variant

**If the store stays single-writer (the resident re-solve loop) — the Phase 23 case:**
- One `Connection`, no pool. Skip `resource-pool`.
- Because it is one process against one DB, an advisory lock (`pg_advisory_lock`) is a cheaper
  mutual-exclusion story than anything application-side.

**If a second concurrent consumer appears (e.g. the v7.0 subgraph writer):**
- Add `resource-pool` 0.5.1.0 (+1) and wrap `Connection` acquisition.
- Reconsider `hasql` + `hasql-pool` at that point — its pooling story is first-party and better.

**If compile-time-checked SQL becomes a requirement:**
- Switch to `hasql` + `hasql-th` (+22) and accept Template Haskell. Do this as a deliberate
  decision, not incrementally — `postgresql-migration` is `postgresql-simple`-bound and would
  need replacing too.

---

## Confidence

| Claim | Confidence | Basis |
|-------|-----------|-------|
| All candidates build on GHC 9.10.3 | **HIGH** | compiled each one; exit 0 |
| Dependency footprint numbers | **HIGH** | `plan.json` set-diff vs the real 152-pkg baseline |
| Versions | **HIGH** | Hackage index refreshed 2026-08-16T11:47:09Z |
| `jsonb` is not byte-preserving | **HIGH** | official PG 18 docs **+** executed against PG 18.4 |
| `?` vs `??` differs between `query` and `query_` | **HIGH** | executed both; captured the `SqlError` |
| `typed-process` kills the child on timeout | **HIGH** | read `bracket … stopProcess` in the source. *Reasoned from the bracket, not from a timeout test I ran.* |
| Migration checksum drift detection + exit-0 caveat | **HIGH** | executed, including the tampered-file case |
| `crypton` costs +0 packages | **HIGH** | present in the existing resolved plan |
| CI service-container recommendation | **MEDIUM** | Docker + image startup measured here; the **GH Actions `services:` wiring on this specific self-hosted runner is not yet exercised** — it has never run. |

**Gaps / things I did not verify:**
- I did not run `hasql` against the live database — its JSONB codecs were verified by source
  inspection, not execution. The recommendation against it rests on footprint and style fit, both
  measured, not on any functional deficiency.
- I did not measure `postgresql-simple` vs `hasql` throughput. If the resident loop turns out to be
  DB-bound (unlikely — it is GAMS-bound), that assumption should be revisited.
- Concurrency/locking semantics for the resident loop's "cache hit elides the solve" race are a
  **Phase 23 design question**, not a library question, and are unresolved here.

---

## Sources

- **Local toolchain execution** (highest confidence) — `ghc 9.10.3`, `cabal-install 3.16.1.0`;
  build probes, `plan.json` set-diffs, live PG 18.4 runs
- **Hackage index** @ `index-state 2026-08-16T11:47:09Z` — all version numbers
- **Package sources** (`cabal get`) — `postgresql-simple-0.7.0.1` (`Simple.hs:285`,
  `FromField.hs:576-592`), `hasql-2.0.1.0` (`Codecs/Encoders/Value.hs:212-226`),
  `typed-process-0.2.13.0` (`Typed.hs:314,411`), `postgresql-migration-0.2.1.8`,
  `web3-crypto-1.1.0.0` (`Crypto/Ethereum/Utils.hs:19`, `.cabal` bounds)
- https://www.postgresql.org/docs/18/datatype-json.html — json vs jsonb preservation; GIN opclasses
- https://hackage.haskell.org/package/cryptonite — deprecation confirmed (last upload 2022-03-13)
- `.planning/PROJECT.md` — milestone v6.0 goal, `VOLUME_PATH.md` §3/§4 determinism + exit-code rules
- `cfmm-replicationPlank-rpc-api.cabal` — existing dependency set

---
*Stack research for: Postgres/JSONB content-addressed model-output store + solver subprocess layer (Haskell, GHC 9.10.3)*
*Researched: 2026-08-16*
