---
phase: 23
slug: postgres-foundation-byte-exact-schema
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-16
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `23-RESEARCH.md` `## Validation Architecture` — the authoritative req→test map lives
> there (22 rows) along with the guard→firing-input table (19 guards).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | **None, by design.** Hand-rolled `exitcode-stdio-1.0` runner: `data Check = Check { check_name, check_run :: IO (Either String ()) }` (`offchain/test/Main.hs:379`). Every check runs; the process exits non-zero if any failed |
| **Config file** | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` |
| **Registration point** | `core_checks :: IO [Check]` — **a check not in this list does not exist** |
| **Quick run command** | `cabal build --enable-tests -j all` |
| **Full suite command** | `cabal test` |
| **Baseline (re-measured cold, 2026-08-16)** | **91/91 checks passed** |
| **Hard gates** | zero `-Wall` warnings under `offchain/`; **`cabal build -j all` WITHOUT `--enable-tests` is VACUOUS** and never counts as evidence |
| **Chain/DB dependency** | **NONE — and this MUST be preserved.** No row in the req→test map needs a database inside `cabal test`. The structural guarantee is asserted: `Store.Postgres\|connectPostgreSQL\|CFMM_REQUIRE_DB` must grep to **0** in `Main.hs` |
| **New test file** | **None.** The suite is one file and one runner; a check outside `core_checks` is invisible to the sentinel harness |

### The three tiers

- **A — pure.** No IO. Corpus set assertions, aeson re-measurement, purge greps, override audit.
- **B — executable contract.** `Store.Laws` run for real against `Store.Memory`, in-suite.
  **This is where DB-03's "still discriminate" is actually delivered** — real executions, not
  assertions over a file.
- **C — committed evidence.** Checks asserting over `store-conformance.json`, captured against a
  real Dockerised Postgres out of band. Tier C is the only tier that ever needed a server, and it
  needed it at *capture* time, never at `cabal test` time.

---

## Sampling Rate

- **Per task:** `cabal build --enable-tests -j all` (zero warnings) — then `cabal test`.
- **Per wave:** the above, plus the wave's own named observation demonstrated firing.
- **Phase gate:** `cabal test` green with the FAIL count at **0**; the `-Wall` gate clean; and
  every guard added by the phase **observed rejecting** its named input at least once.

---

## Per-Task Verification Map

| Task | Plan | Wave | Requirements | Tier | Automated command | Status |
|---|---|---|---|---|---|---|
| 23-01-01 | 01 | 1 | — (scaffolding) | build | `cabal build --enable-tests -j all` | ⬜ pending |
| 23-01-02 | 01 | 1 | BYTE-02, BYTE-05 | A | `cabal build --enable-tests -j all` | ⬜ pending |
| 23-01-03 | 01 | 1 | DB-02 | A | `cabal build --enable-tests -j all` | ⬜ pending |
| 23-02-01 | 02 | 2 | DB-03 | B | `cabal test` | ⬜ pending |
| 23-02-02 | 02 | 2 | DB-03, BYTE-05, KEY-07 | A + B | `cabal test` | ⬜ pending |
| 23-02-03 | 02 | 2 | BYTE-03 | A | `cabal test` | ⬜ pending |
| 23-03-01 | 03 | 3 | DB-01, KEY-07 | A | `cabal test` | ⬜ pending |
| 23-03-02 | 03 | 3 | BYTE-01, BYTE-02, BYTE-03 | build | `cabal build --enable-tests -j all` | ⬜ pending |
| 23-04-01 | 04 | 4 | DB-01, DB-04, BYTE-01, KEY-07 | C (capture) | `cabal build --enable-tests -j all` | ⬜ pending |
| 23-04-02 | 04 | 4 | DB-04, BYTE-02, BYTE-05 | C (capture) | capture script, then `cabal test` | ⬜ pending |
| 23-05-01 | 05 | 5 | DB-01, DB-03, BYTE-01, BYTE-02, BYTE-05, KEY-07 | C | `cabal test` | ⬜ pending |
| 23-05-02 | 05 | 5 | DB-02, DB-04 | A | `cabal test` | ⬜ pending |

**Every task's quick gate is `cabal build --enable-tests -j all` with zero warnings.** No task
may cite the bare `cabal build -j all`.

---

## Requirement Coverage

All nine IDs are covered; the authoritative per-check detail is `23-RESEARCH.md`'s 22-row map.

| Req | Covered by | Tier | Needs DB in `cabal test`? |
|---|---|---|---|
| **BYTE-01** | `store_corpus_round_trips_byte_identically`, `store_conformance_digests_match_the_pinned_source_digest` | B + C | **No** |
| **BYTE-02** | `jsonb_round_trip_of_the_real_shape_is_exhibited_failing`; plus a **compile error** (`DerivedDoc` has no `Eq`, no converter to `Artifact`) | C + compile | **No** |
| **BYTE-03** | `aeson_round_trip_mutations_are_re_measured`, `aeson_is_absent_from_the_storage_path` | A | **No** |
| **BYTE-05** | `bare_bytestring_is_observed_corrupting_the_artifact`, `adversarial_corpus_has_a_silently_corrupted_member` | A + C | **No** |
| **DB-01** | `migration_list_is_ordered_and_gapless`, `..._records_a_nonzero_exit_on_checksum_drift`, `..._records_the_second_migrator_applying_nothing`, `..._records_two_runs_from_an_empty_database` | A + C | **No** |
| **DB-02** | `every_advertised_override_is_honoured` extended with `PGSTORE_DSN`/`STORE_CONFORMANCE`; `no_credential_is_present_in_a_tracked_file` | A | **No** |
| **DB-03** | `store_laws_run_against_the_memory_store`, `expected_store_laws_is_the_law_set` | B + A | **No** |
| **DB-04** | the capture script provisions Dockerised Postgres; asserted through the artifact | C | **No** |
| **KEY-07** | orphaning under a superseded `key_scheme`, observed in the capture | B + C | **No** |

---

## Standing Findings the Execution Must Carry

- **A guard never OBSERVED rejecting is treated as ABSENT.** For each of the 19 guards the
  research names the input that makes it fire; that firing must be demonstrated, not assumed.
- **ROADMAP SC-1's corpus was inadequate** — `0x00` and invalid UTF-8 raise a **loud** error;
  CRLF and a trailing newline round-trip correctly and prove nothing. Only
  backslash-plus-octal (`a\101b`: 6 bytes via `Binary`, **3 bytes** as a text literal, no error)
  corrupts silently. Assert on **length/digest**, NEVER on "an exception was thrown" — a
  `SqlError` is shaped exactly like a dead connection.
- **Anti-collapse:** a check must redden if *every* corpus member records `SqlError`, which
  would mean the corpus lost its discriminating member.
- **`postgresql-migration` 0.2.1.8 has NO advisory lock** — the concurrency observation is the
  caller's `pg_try_advisory_lock(872304)`, measured `f` while held / `t` after release. No
  sleep-racing.
- **`postgresql-migration` exits 0 on checksum drift.** The guard is the caller's `exitFailure`
  and the OBSERVATION is `echo $?` == 1 after appending one comment line to `001_*.sql`.
- **The `.sql`/purge collision is one task, not a surprise** — `purge_file_floor` is 36 against
  exactly 36 scanned files, **zero slack**. `purge_scanned_extensions`, `purge_known_extensions`
  and a **re-measured** floor move in the same commit. And declaring the extension is not the
  same as scanning it: prove `.sql` is scanned by seeding a `0x`-prefixed literal and observing
  `sc3_literal_purge` redden.
- **`purge_pattern` requires a `0x` prefix**, so any pinned digest must be written as **bare**
  hex.
- **23-02 ends deliberately RED** on `aeson_is_absent_from_the_storage_path`, whose subject
  (`Store/Postgres.hs`) 23-03 creates. Scoping the check to only-existing files would make it
  pass *because its subject does not exist* — the defect class. 23-03's gate is FAIL count 0.
- **Tree-derived floors are re-MEASURED at execution time**, never inherited:
  `purge_file_floor`, `sentinel_pair_floor`, `artifact_field_floors`.
- **`PGSTORE_DSN` resolves a DSN string, not a FilePath**, so `OverrideProbe`'s shape does not
  fit. **Do NOT weaken `probe_override`.** If the "consumer fails naming the resolved value"
  assertion cannot honestly be satisfied, register it in an asserted `unprobed_overrides` list
  with a written reason — a registered-but-vacuous probe is the exact defect the sweep exists to
  catch.

---

## Wave 0 Requirements

**None.** The suite is one file and one runner; every registration point is a task in the plans,
not scaffolding. Test infrastructure already exists and is reused, not replaced.

---

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Instructions |
|---|---|---|---|
| Docker Postgres provisioning | DB-04 | Requires a container runtime; deliberately out of `cabal test` to keep the suite DB-free | `bash offchain/rig/capture-store-conformance.sh` — provisions `postgres:18-alpine`, runs the capture, tears down |

---

## Validation Sign-Off

- [ ] `cabal build --enable-tests -j all` — zero warnings
- [ ] `cabal test` — FAIL count 0, total ≥ 91 baseline
- [ ] Every guard added by this phase observed rejecting its named input
- [ ] `Store.Postgres|connectPostgreSQL|CFMM_REQUIRE_DB` greps to 0 in `Main.hs`
- [ ] Tree-derived floors re-measured, not inherited
- [ ] Territory clean: `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` empty
