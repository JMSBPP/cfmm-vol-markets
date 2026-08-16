# Requirements: Milestone v6.0 — Model Output Store + VolumePath Bridge

**Defined:** 2026-08-16
**Core Value:** A target contingent payoff can flow end-to-end — payoff → GAMS solves optimal
parameters → parameters encoded → Plank CFMM simulates — with the two tracks agreeing on one
authoritative type/parameter kernel.
**Source:** GitHub issue #25. Authoritative contract: `model/mev_tax_model_one/VOLUME_PATH.md`.
**Research:** `.planning/research/SUMMARY.md` (2026-08-16).

---

## v6.0 Requirements

### Byte Integrity (BYTE)

The milestone's headline guarantee is that a re-solve reproduces bytes. Everything here
exists because three separate layers were measured silently altering them.

- [x] **BYTE-01**: The prover's output is stored as `bytea` and returned byte-identical to
      what GAMS emitted — verified against a recorded sha256, not against a parsed document.
- [x] **BYTE-02**: A `jsonb` projection exists for querying and is **derived** from the
      bytes; no check ever compares `jsonb` to `jsonb` to establish byte identity.
- [x] **BYTE-03**: The prover's bytes never pass through `Data.Aeson.Value` on the storage
      or publication path (measured: `decode→encode` mutates 4 fields at GHC 9.10.3).
- [ ] **BYTE-04**: `dQx`/`dQM` are decoded as `Integer`, never `Double` (measured: `Double`
      loses 32 wei on the first element, which would execute the wrong swap amounts).
- [x] **BYTE-05**: A stored artifact round-trips byte-identically through the database — a
      test that fails if any layer normalizes, including `ByteString` sent as text rather
      than via the `Binary` newtype.

### Key Identity (KEY)

- [ ] **KEY-01**: A shock's key is `H(canonical inputs ‖ GAMS version ‖ CONOPT version ‖
      model source digest ‖ solver options digest)`.
- [ ] **KEY-02**: One renderer produces both the `execve` argv and the hash preimage, so the
      key cannot describe an invocation other than the one that ran.
- [ ] **KEY-03**: Inputs are normalized once at the edge (`28e18` → `28000000000000000000`)
      and never re-rendered between uses.
- [ ] **KEY-04**: The preimage is **framed** — field boundaries are unambiguous, so no two
      distinct input tuples can produce the same preimage.
- [ ] **KEY-05**: The pips denominator is part of the preimage, so a future change to it
      cannot silently reinterpret existing keys.
- [ ] **KEY-06**: A missing or unparseable input is an error before hashing — never a
      default that silently becomes part of a key.
- [x] **KEY-07**: Rows carry a `key_scheme` inside the unique constraint, so a future key
      formula change orphans rows rather than corrupting them.

### Store (STORE)

- [ ] **STORE-01**: An identical shock returns the stored artifact **without invoking the
      solver**.
- [ ] **STORE-02**: Re-solving an existing key and getting different bytes is reported as a
      determinism failure with a non-zero exit.
- [ ] **STORE-03**: On a determinism failure the original is kept and the divergent bytes are
      **quarantined**, not discarded — a mismatch becomes evidence.
- [ ] **STORE-04**: Verification is on demand, not on every cache hit (always-verify defeats
      the elision the store exists for; Nix shipped it and removed it as broken).
- [ ] **STORE-05**: A run can be pinned so retention never removes it.
- [ ] **STORE-06**: Reset is a separate, explicit operation that cannot run as a side effect
      of a solve or publish.
- [ ] **STORE-07**: An append-only run log records `(timestamp, key, event tx, block)` — the
      chronology a content key cannot carry.
- [ ] **STORE-08**: A partial or failed run never becomes a cache entry.

### Database Foundation (DB)

- [x] **DB-01**: Schema and migrations are applied by an explicit command whose failure —
      including a checksum mismatch — exits non-zero (`postgresql-migration` returns the
      error and still exits 0).
- [x] **DB-02**: Connection configuration is resolved from the environment with no hardcoded
      credentials, consistent with the existing override convention.
- [x] **DB-03**: `cabal test` passes with **no database present**, and the tests that cover
      store behaviour still discriminate — they must not skip, pass vacuously, or read
      nothing and report clean.
- [x] **DB-04**: A Postgres instance can be provisioned for local and CI runs via Docker.

### Solver Invocation (GAMS)

- [ ] **GAMS-01**: The prover is invoked as a subprocess whose success is decided by the
      **exit code**, never by log text.
- [ ] **GAMS-02**: A run that exits 0 without producing the artifact is a failure (GAMS exit
      0 means "GAMS ran", not "the model solved").
- [ ] **GAMS-03**: The GAMS and CONOPT versions are detected and fed into the key; detection
      that finds nothing **fails loudly** rather than yielding an empty string.
- [ ] **GAMS-04**: CONOPT version detection reads the true solver version (`C O N O P T
      version 4.39.0`) and not the adjacent GAMS-side link version or the `.so` filename.
- [ ] **GAMS-05**: A hung solve is bounded by a timeout that terminates the child process.
- [ ] **GAMS-06**: The invocation environment is controlled, so ambient variables cannot
      change what the solver computes.

### Fee Split (FEE)

- [ ] **FEE-01**: Given a pool fee `f` and a target `δ*`, the splitter produces (φ_X, φ_M)
      satisfying `(1−φ_X)(1−φ_M) = 1−f` exactly.
- [ ] **FEE-02**: The pair satisfies the admissibility condition `δ* ≥ 2ρ/(1+ρ²)` where
      `ρ = φ_M/φ_X`, checked **before** the solver is invoked.
- [ ] **FEE-03**: An infeasible request is refused with the reason and the boundary value,
      rather than being discovered as a solver exit code.
- [ ] **FEE-04**: The choice of ρ within the admissible band is reproducible from a recorded
      seed.

### Chain Reads (CHAIN)

- [ ] **CHAIN-01**: The `next` event is decoded from a mined transaction's logs into the
      shock it carries.
- [ ] **CHAIN-02**: Pool price, liquidity and fee are read **pinned to a single block**, not
      at `latest`.
- [ ] **CHAIN-03**: A read that returns an absent, zero or unparseable value is an error, not
      a value that flows into a key.
- [ ] **CHAIN-04**: Decoding is exercised against synthetic logs, so it is testable before
      the upstream event exists and without a chain.

### Loop and Publication (LOOP)

- [ ] **LOOP-01**: The loop discovers new `next` events by polling from a persisted watermark
      (`eth_subscribe` is unavailable and the client is request/response).
- [ ] **LOOP-02**: Seeing the same event twice does not duplicate work or corrupt the store.
- [ ] **LOOP-03**: The newest run is published to the fixture path the forge test reads, by
      atomic rename — a consumer can never observe a partial file.
- [ ] **LOOP-04**: Publication writes exactly one file into the other workstream's tree and
      nothing else.
- [ ] **LOOP-05**: A crash or interrupt mid-cycle leaves the store and the published fixture
      consistent.

---

## Deferred (v7.0+)

| Requirement | Why deferred |
|---|---|
| Numeric-aware diff of divergent artifacts | Byte inequality plus both digests suffices until a mismatch actually happens |
| Garbage collection of unpinned entries | Artifacts are low-KB; its reachability predicate depends on pinning and the run log landing first |
| Single-flight concurrent solves | Assumes one loop; revisit if the loop becomes concurrent |
| A second store tenant (another model) | Layout is model-agnostic from the start; building a second tenant before a second model exists is speculative |

## Out of Scope

| Feature | Reason |
|---|---|
| Changing `VOLUME_PATH.md`'s emitted JSON shape | `model/` is the GAMS workstream's territory; the §3 shape is their contract |
| Implementing `SELECTOR_NEXT`'s event emission | Plank workstream (issue #26) |
| Fixing the test's `shock(...)` signature mismatch | Belongs with issue #26, which owns the alignment |
| Asserting the rig's computed payload (`e5.fee`, σ, accumulators) | Filed as issue #19; different concern from this store |
| `ExceptT` error plumbing over `Web3` | `runWeb3'`'s `Left` is unreachable; it would advertise a guarantee the runtime does not provide |

## Traceability

Filled during roadmap creation (2026-08-16).

| Requirement | Phase | Status |
|---|---|---|
| BYTE-01 | Phase 23 | **Evidence complete (23-04), assertion owed** — all SEVEN corpus members round-trip byte-identically through the `Binary` path against a real PG 18.4 (`binary_out_sha256 == in_sha256`, seven for seven), and the real 606-byte artifact round-trips to `e7b14f38…07d0d884`, the digest pinned in Haskell source. Recorded in `offchain/rig/store-conformance.json`. What is still owed is a CHECK that reads it — 23-05. Prior verdict: **Partial (23-03)** — the `bytea` columns exist (`model_run.raw`, `model_run.key`, `byte_corpus.raw`) and EVERY parameter reaching one goes through `Binary`: six sites, inspected individually in the summary, including the two in `WHERE` clauses that the plan's "every bytea WRITE parameter" wording did not cover but that are exposed to the identical wart. Reads are deliberately unwrapped — `FromField ByteString` special-cases the `bytea` OID, so the wart is write-only. Byte-exactness itself is UNOBSERVED: the corpus round-trip through a real server is 23-04. |
| BYTE-02 | Phase 23 | **Evidence complete (23-04), assertion owed** — the exhibit exists and has a LIVE subject: on the real 606-byte shape `doc_text_sha256` is `b50a14b4…a87a16e4` and `raw_out_sha256` is `e7b14f38…07d0d884`, so the `jsonb` round-trip FAILS the sha256 comparison the requirement asks for. The digest comes from `convert_to(doc::text,'UTF8')` — the server's own rendering — never from a json library. 23-05 asserts it, and must redden if the two ever become EQUAL, because equal digests mean the exhibit lost its subject. Prior verdict: **Partial (23-03)** — the "a jsonb projection EXISTS" clause is now SATISFIED and its "derived from the bytes" half is STRUCTURAL: `doc` is written by `convert_from(?, 'UTF8')::jsonb` from the SAME parameter as `raw`, in ONE statement, with the artifact passed twice — there is no second source it could come from and no Haskell code constructs it. Still owed: the exhibit of a `jsonb` round-trip FAILING a sha256 comparison on the real 606-byte shape (23-04). Prior verdict, still standing: **Partial (23-01)** — the "no check compares jsonb to jsonb" clause is DISCHARGED at compile time and OBSERVED firing (`[GHC-39999] No instance for 'Eq DerivedDoc'`, plus `[GHC-01928]` on a converter). The "a jsonb projection EXISTS" clause needs the schema (23-03) and the failing-comparison exhibit (23-04). |
| BYTE-03 | Phase 23 | **Effectively closed at 23-03, formally signed off with the phase** — `aeson_is_absent_from_the_storage_path` is GREEN over SEVEN files that all exist (`Store/Schema.hs` was added to the list at 23-03 after the self-check found it unlisted for two commits), zero aeson tokens in each, and its scan branch was OBSERVED firing against the REAL `Store/Postgres.hs` rather than against a stub. Prior verdict: **Partial (23-02)** — both guards exist and both were OBSERVED. `aeson_round_trip_mutations_are_re_measured` is GREEN and re-measures three mutations at aeson 2.2.5.0 as pinned VALUES (`0.00318353 -> 3.18353e-3`, `2.8e19 -> 28000000000000000000`, and a key reorder), so a subject that vanished would redden. `aeson_is_absent_from_the_storage_path` is DELIBERATELY RED: it names all six `offchain/lib/Store/*.hs` with no exemptions, and `Store/Postgres.hs` does not exist until 23-03. Its positive control was OBSERVED firing (pattern mutated to match nothing) and its scan branch was OBSERVED catching a seeded aeson import. Complete when 23-03 lands the file and the check goes green — MEASURED with a clean stub: 96/96. |
| BYTE-04 | Phase 24 | Pending |
| BYTE-05 | Phase 23 | **Evidence complete (23-04), assertion owed, and STRONGER than planned** — driven through a real server, THREE members corrupt SILENTLY on the bare path (`nul` 1→0, `octal-escape` 6→3, `double-backslash` 4→3) and two raise `SqlError`; the plan expected two silent and three loud. **`nul` was retagged from `ServerRejects` to `SilentlyCorrupted` on measurement**: `ToField ByteString` is `Escape`, libpq's escaper takes a C STRING, and a C string ends at its first NUL, so the parameter reaching Postgres is empty — 1 byte in, 0 out, no error. A total truncation is a worse silent corruption than 6→3 and had been filed under the loud behaviour that proves the least. `crlf` and `trailing-newline` round-trip CORRECTLY through the broken path and must never be cited as evidence. Prior verdict: **Pending — NOT satisfied by 23-01.** The requirement is a round-trip *through the database*; 23-01 provisioned and contacted no database. What 23-01 landed is its PRECONDITION: the 7-member corpus with measured behaviour tags, including the `SilentlyCorrupted` `a\101b` that SC-1's own five members cannot produce. Lands at 23-04. **23-02 added the corpus SET lock** (`adversarial_corpus_has_a_silently_corrupted_member`, GREEN), and MEASURED that the behaviour-tag set the plan prescribed does NOT discriminate deleting `octal-escape` — `double-backslash` carries the same tag, so all three classes survive the deletion. The member-NAME set, asserted in both directions, is what caught it. |
| KEY-01 | Phase 25 | Pending |
| KEY-02 | Phase 25 | Pending |
| KEY-03 | Phase 25 | Pending |
| KEY-04 | Phase 25 | Pending |
| KEY-05 | Phase 25 | Pending |
| KEY-06 | Phase 25 | Pending |
| KEY-07 | Phase 23 | **Evidence complete (23-04), assertion owed** — `live_identity_constraint_columns` has now been RUN, against a real catalogue, and reports exactly `["model","key_scheme","key"]`. That is the half 23-03 could not reach: a DDL file that was never applied and a catalogue that drifted are different failures, and this one says the file WAS applied. Both KEY-07 laws also pass against real SQL. Prior verdict: **Partial (23-03)** — the constraint now names all THREE columns in the DDL (`constraint model_run_identity unique (model, key_scheme, key)`) AND in Haskell (`Store.Schema.identity_constraint_columns`), asserted as two subjects because they drift; the FILE half was OBSERVED reddening when `key_scheme` was dropped from the DDL with the constant left alone. `live_identity_constraint_columns` exists and reads the catalogue with `with ordinality` but has NEVER BEEN RUN — the live half is 23-04's capture and 23-05's assertion. Prior verdict: **Partial (23-02)** — the orphaning property is now an EXECUTING law rather than a comment: `law_key_scheme_orphans_rather_than_matching` and `law_same_key_under_a_new_scheme_inserts` run against `Store.Memory` inside `cabal test` with no socket, and BOTH were OBSERVED firing against a store keyed on `(model, key)` alone. The requirement's own subject — `key_scheme` inside a Postgres UNIQUE CONSTRAINT — is schema, and lands at 23-03; the live-catalogue assertion lands at 23-04. |
| STORE-01 | Phase 25 | Pending |
| STORE-02 | Phase 25 | Pending |
| STORE-03 | Phase 25 | Pending |
| STORE-04 | Phase 25 | Pending |
| STORE-05 | Phase 25 | Pending |
| STORE-06 | Phase 25 | Pending |
| STORE-07 | Phase 25 | Pending |
| STORE-08 | Phase 25 | Pending |
| DB-01 | Phase 23 | **Evidence complete (23-04), assertion owed** — all four server-requiring clauses are now VALUES in the committed artifact: a corrupted checksum makes the runner exit **1** (`checksum_drift_exit`, from a real subprocess; the library's own in-process result is `MigrationError` with the process still alive, recorded as `checksum_drift_exit_without_guard 0`); two runs from a database created moments ago succeed and the second applies **0**; and a second migrator, while the first holds `pg_advisory_lock(872304)`, gets **`f`** and applies **0** — then, after release, gets **`t`** and applies **1** of a directory carrying a third migration, which is the positive control without which "applied 0" is satisfied by a migrator that could never apply anything. NOTE for 23-05: the drift stderr is `migration FAILED: 001_model_run.sql` — a FILENAME — so nothing may assert on that text. Prior verdict: **Partial (23-03)** — `run_migrations_or_exit` exists, holds `pg_advisory_lock(872304)` (which `postgresql-migration` 0.2.1.8 does NOT provide — zero `advisory` hits, re-grepped) and calls `exitFailure` on `MigrationError` (which the library does NOT do — it exits 0). The manifest is ordered, gapless and locked as a SET in both directions over the directory's WHOLE contents, with two arms OBSERVED firing. But every DB-01 clause that matters is an observation against a SERVER — exit code 1 on drift, the second migrator applying 0, two runs from an empty database — and NONE was made: this plan contacted no database. 23-04. |
| DB-02 | Phase 23 | **Partial (23-01)** — `PGSTORE_DSN`/`STORE_CONFORMANCE` resolve via `lookupEnv` in the `Rig.Manifest` idiom with **zero** credential literals (grep-verified, prose included). Not complete until both are registered in `advertised_overrides` and OBSERVED honoured (23-05); this repo has measured three advertised-and-dead overrides. |
| DB-03 | Phase 23 | **Partial (23-02) — and the "passes" half is RED BY DESIGN right now.** The "still discriminate" half is DELIVERED and measured: `store_laws_run_against_the_memory_store` really executes all seven store laws against a fresh `Store.Memory` per law, and every law was OBSERVED firing against a named wrong store. "No database present" is satisfied STRUCTURALLY — `grep -cE 'Store\.Postgres\|CFMM_REQUIRE_DB\|connectPostgreSQL' offchain/test/Main.hs` = 0, so no socket and no branch to misconfigure. But `cabal test` does NOT currently pass (2 red: `aeson_is_absent_from_the_storage_path` and, consequently, `sentinel_falsification_harness`), so the requirement as written is NOT met until 23-03. |
| DB-04 | Phase 23 | **Partial (23-04)** — `offchain/rig/capture-store-conformance.sh` provisions Postgres via Docker for local runs: `postgres:18-alpine` on host port **55433** (deliberately NOT 5432 — another project's Postgres is bound to `0.0.0.0:5432` on this machine, so the default would let a foreign database silently satisfy the connection), a per-run database, a bounded readiness poll, and teardown on every exit path including SIGINT. Cold run **4–8 s**. The artifact records BOTH sides of the pin: `image_tag` (`postgres:18-alpine`, what was asked for) and `server_version` (`18.4`, what replied). Still owed: the CI half of "local and CI" — that is the CI track's coordination item, not this workstream's, and no `.github/` file was touched. No check compares the two recorded fields yet (23-05). |
| GAMS-01 | Phase 24 | Pending |
| GAMS-02 | Phase 24 | Pending |
| GAMS-03 | Phase 24 | Pending |
| GAMS-04 | Phase 24 | Pending |
| GAMS-05 | Phase 24 | Pending |
| GAMS-06 | Phase 24 | Pending |
| FEE-01 | Phase 26 | Pending |
| FEE-02 | Phase 26 | Pending |
| FEE-03 | Phase 26 | Pending |
| FEE-04 | Phase 26 | Pending |
| CHAIN-01 | Phase 27 | Blocked (upstream `next` event, issue #26) |
| CHAIN-02 | Phase 27 | Blocked (upstream `next` event, issue #26) |
| CHAIN-03 | Phase 27 | Blocked (upstream `next` event, issue #26) |
| CHAIN-04 | Phase 26 | Pending |
| LOOP-01 | Phase 28 | Blocked (upstream `next` event, issue #26) |
| LOOP-02 | Phase 28 | Blocked (upstream `next` event, issue #26) |
| LOOP-03 | Phase 28 | Blocked (upstream `next` event, issue #26) |
| LOOP-04 | Phase 28 | Blocked (upstream `next` event, issue #26) |
| LOOP-05 | Phase 28 | Blocked (upstream `next` event, issue #26) |

**Coverage:** 43 v6.0 requirements defined; **43/43 mapped** to exactly one phase each — no
orphans, no duplicates.

**Count correction (2026-08-16):** this file previously stated *"39 v6.0 requirements defined"*
in both the header and here. The actual checkbox count is **43** — BYTE 5, KEY 7, STORE 8, DB 4,
GAMS 6, FEE 4, CHAIN 4, LOOP 5. The figure is corrected rather than reconciled by dropping four
requirements; no requirement was added or removed at roadmap time.

| Phase | Requirements | Count | Blocked? |
|---|---|---|---|
| 23 — Postgres Foundation & the Byte-Exact Schema | DB-01..04, BYTE-01, BYTE-02, BYTE-03, BYTE-05, KEY-07 | 9 | No |
| 24 — GAMS Invocation & Toolchain Identity | GAMS-01..06, BYTE-04 | 7 | No |
| 25 — The Content Key & Keyed Store | KEY-01..06, STORE-01..08 | 14 | No |
| 26 — Shock Assembly (Fee Split & Event Decode) | FEE-01..04, CHAIN-04 | 5 | No |
| 27 — Anvil Read Layer | CHAIN-01, CHAIN-02, CHAIN-03 | 3 | **Yes** — plank worktree must emit `next` (issue #26) |
| 28 — Resident Loop & Fixture Publication | LOOP-01..05 | 5 | **Yes** — inherits Phase 27 |

**Two ordering corrections applied at roadmap time**, both from research, both changing which
phase a requirement lands in relative to the six approved in brainstorm:

1. **GAMS-03/GAMS-04 precede STORE-01.** The key contains the GAMS and CONOPT versions
   (KEY-01), so version detection is a *prerequisite* of the store's first production write, not
   a later phase. The GAMS phase therefore sits at position 2, ahead of the store.
2. **BYTE-01/02/05 and KEY-07 land in the earliest schema phase (23), not with the store.**
   They are schema decisions — `bytea` authoritative, `jsonb` derived, the `Binary` newtype, and
   `key_scheme` inside the unique constraint — that every later phase consumes and each is
   expensive to retrofit.

Additionally, **CHAIN-04 is mapped to Phase 26, not to the (blocked) Anvil phase**: decoding is
exercised against synthetic logs, so it is buildable with no chain and no upstream. Only
CHAIN-01/02/03 are blocked.

---
*Requirements defined: 2026-08-16 · Traceability filled: 2026-08-16*
