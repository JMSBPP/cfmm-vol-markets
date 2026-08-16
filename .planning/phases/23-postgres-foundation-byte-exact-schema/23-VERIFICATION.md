---
phase: 23-postgres-foundation-byte-exact-schema
verified: 2026-08-16T18:03:24Z
status: passed
score: 9/9 must-haves verified
---

# Phase 23: Postgres Foundation & the Byte-Exact Schema Verification Report

**Phase Goal:** A migrated Postgres schema whose artifact column returns exactly the bytes it was
given, and a test suite that goes RED — never green, never skipped — when the database or its
committed evidence is absent.

**Verified:** 2026-08-16T18:03:24Z
**Status:** passed
**Re-verification:** No — initial verification

## Method

This is a re-derivation, not a trust exercise. Every claim below was reproduced independently by
running the actual build, running the actual test binary, reading the actual source, reading the
actual committed artifact, and — for the guard-firing claims — reproducing the mutation myself,
observing the failure, and restoring the file from a saved copy with a sha256 diff, exactly the
discipline the phase's own SUMMARYs claim to have followed. Nothing here was accepted on the
strength of a SUMMARY's prose.

## Measured state, independently reproduced

| Claim | Reproduced | Result |
|---|---|---|
| `cabal build --enable-tests -j all` → 0 warnings | yes | `grep -cE '^offchain/[^ ]*:[0-9]+:[0-9]+: warning:'` = **0** |
| `cabal test` → 111/111, FAIL 0 | yes, via the built binary directly (per the repo's own finding that `cabal test`'s wrapper buffers stdout) | **111/111 checks passed**, `grep -c '^FAIL '` = **0** |
| `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` empty | yes | empty |
| Bare `cabal build -j all` never used as evidence | confirmed — every verification here used `--enable-tests` | n/a |

## Goal Achievement

### Observable Truths (the seven items this verification was scoped to)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | `cabal test` is genuinely DB-free | ✓ VERIFIED | `grep -cE 'Store\.Postgres\|connectPostgreSQL\|CFMM_REQUIRE_DB' offchain/test/Main.hs` = **0**. Confirmed no socket: the only two files matching `Database\.PostgreSQL` are `Store/Postgres.hs` and `app/StoreConformance.hs`, neither reachable from `offchain/test/`. |
| 2 | The suite discriminates without a database (DB-03's second half) | ✓ VERIFIED | `Store.Laws.store_laws` executes for real against `Store.Memory` (`store_laws_run_against_the_memory_store`, `offchain/test/Main.hs:5978`, builds a **fresh** `new_memory_store` per law via `against_a_fresh_store`). Registered in `core_checks` (line 7278). Renaming a law in `Store/Laws.hs` and rerunning the suite produced `FAIL expected_store_laws_is_the_law_set` naming both the orphaned expected-law and the undeclared library law — reddened the suite (109/111, 2 FAILED) exactly as the SUMMARY claims. File restored, sha256 verified identical (`e4c9113…d0430c768`). |
| 3 | Guards fire (spot-checked 3 of the 18 claimed) | ✓ VERIFIED | **(a)** Law rename → `FAIL expected_store_laws_is_the_law_set`, verbatim as documented. **(b)** Deleting the `octal-escape` corpus member → `FAIL adversarial_corpus_has_a_silently_corrupted_member` **and** cascaded into `FAIL bare_bytestring_is_observed_corrupting_the_artifact` (108/111), exactly the two-check cascade the 23-05 SUMMARY documents. **(c)** `DerivedDoc` + a bare `probe = (==)`: reproduced the exact `[GHC-39999] No instance for 'Eq DerivedDoc'` compile error; the anti-control (adding `deriving Eq`) made the identical probe compile cleanly. All three mutated files restored from saved copies with sha256 diffs confirmed empty (`Types.hs` = `e9d67552…c686ee6`, `Laws.hs` = `e4c9113…d0430c768`). |
| 4 | Absence checks have positive controls | ✓ VERIFIED | Read `aeson_positive_control` and `credential_positive_control` in full (`offchain/test/Main.hs:7116`, `6938`). Both seed a real bait file AND a clean/innocent file, assert the scan exits 0 and NAMES the bait, and assert the innocent file is NOT named. The credential control specifically asserts the environment-variable *form* (`password=$VAR`) does **not** match while the literal form does — a genuine two-directional control, not a decorative one. |
| 5 | Floors re-measured, match the tree today | ✓ VERIFIED | `purge_file_floor` = 48 in source; `find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f \| wc -l` = **48**. `credential_scan_floor` = 56 in source; `find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f \| wc -l` = **56**. `sentinel_pair_floor` = 3250 — cannot be wrong given the full suite (which exercises `sentinel_falsification_harness`) passed at 111/111; a stale floor there would redden that check. |
| 6 | `unprobed_overrides` is asserted, not a free pass | ✓ VERIFIED | Read `store_overrides_are_probed_or_named_as_gaps` in full (`offchain/test/Main.hs:3804`). It asserts: (a) every env var `Store.Config` names is in exactly one of `advertised_overrides`/`unprobed_overrides` (catches a silent rename); (b) the two lists are disjoint; (c) every unprobed reason string is ≥200 chars (rejects a stub like "not needed"); (d) the resolver for each unprobed var is actually exercised. `PGSTORE_DSN`'s reason honestly names the two rejected alternatives (opening a socket from `cabal test`, or a vacuous validator) rather than hiding the gap. |
| 7 | The byte guarantee holds end to end | ✓ VERIFIED | `001_model_run.sql`: `raw bytea not null`, `doc jsonb not null`, both written in one `insert` statement from the same `bytea` parameter (confirmed by reading `Store/Postgres.hs`'s `convert_from(?, 'UTF8')::jsonb` clause, asserted structurally). `aeson_storage_path` names exactly the 8 files that exist under `offchain/lib/Store/`; `grep -cE 'Data\.Aeson\|\btoJSON\b\|\bencode\b\|\bfromJSON\b\|\beitherDecode\b' offchain/lib/Store/*.hs` = **0** for every one. The corpus has exactly **3** `SilentlyCorrupted` members (`nul`, `octal-escape`, `double-backslash`) — corrected from the plan's original 2, per the documented 23-04 finding that `nul`'s bare-path behavior was mismeasured in the plan/research and re-tagged after driving it against a real server. |

**Score:** 7/7 scoped truths verified, plus the 9/9 requirement IDs cross-referenced below.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `offchain/lib/Store/Types.hs` | Artifact/DerivedDoc contract, corpus | ✓ VERIFIED | Compiles; `DerivedDoc` has no `Eq` (guard fired live); 7-member corpus present |
| `offchain/lib/Store/Laws.hs` | 7 executable laws + 1 (json law from 23-04) = 8 | ✓ VERIFIED | 8 verdicts in `store-conformance.json`, all "pass" |
| `offchain/lib/Store/Postgres.hs` | sole `postgresql-simple` importer, Binary-wrapped writes | ✓ VERIFIED | `grep -rlE 'Database\.PostgreSQL' offchain/lib` = only this file |
| `offchain/migrations/001_model_run.sql`, `002_byte_corpus.sql` | schema with `unique(model,key_scheme,key)` | ✓ VERIFIED | present, DDL confirmed by direct read |
| `offchain/rig/store-conformance.json` | committed DB evidence | ✓ VERIFIED | present, sha256 `1e5f076a…d332153`, `sc_complete: true`, 8/8 law verdicts pass, `jsonb_exhibit` shows differing digests as required |
| `offchain/test/Main.hs` Tier-C checks | assert the artifact | ✓ VERIFIED | registered in `core_checks`, all pass, absence/staleness/truncation guards reproduced live for law-set and corpus-set cases |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `Store/Postgres.hs` insert | `bytea` param | `convert_from(?,'UTF8')::jsonb` from same param as `raw` | ✓ WIRED | confirmed by direct file read; DDL and Postgres module agree |
| `offchain/test/Main.hs` | `Store.Laws.store_laws` | `new_memory_store` per law | ✓ WIRED | confirmed executing (mutation reddened the suite) |
| `offchain/test/Main.hs` | `offchain/rig/store-conformance.json` | `store_conformance_path` | ✓ WIRED | file read through the config resolver; artifact values match check assertions |
| `offchain/test/Main.hs` | `swept_artifacts` | fifth `MutableArtifact` entry | ✓ WIRED | `sentinel_falsification_harness` passed, consistent with correctly-registered fifth artifact |

### Requirements Coverage

| Requirement | Source Plan(s) | Status | Evidence |
|---|---|---|---|
| DB-01 | 23-03, 23-04, 23-05 | ✓ SATISFIED | `checksum_drift_exit`=1, `second_migrator_try_lock`=false/`applied`=0 then true/1 after release, `empty_db_run2_applied`=0 — all in the committed artifact and asserted by `core_checks` (suite green) |
| DB-02 | 23-01, 23-05 | ✓ SATISFIED | `no_credential_is_present_in_a_tracked_file` with verified positive control; `PGSTORE_DSN`/`STORE_CONFORMANCE` resolve via `lookupEnv`, zero credential literals confirmed |
| DB-03 | 23-02, 23-05 | ✓ SATISFIED | `cabal test` DB-free (grep=0) and discriminates (guard-firing reproduced live) |
| DB-04 | 23-04, 23-05 | ✓ SATISFIED | `image_tag`="postgres:18-alpine", `server_version`="18.4" both in artifact, both asserted |
| BYTE-01 | 23-03, 23-04, 23-05 | ✓ SATISFIED | corpus `Binary`-path round-trips byte-identical (7/7 in artifact); golden 606-byte round-trip confirmed |
| BYTE-02 | 23-01, 23-03, 23-05 | ✓ SATISFIED | `DerivedDoc` has no `Eq`/converter (compile-guard reproduced); `doc_text_sha256` differs from `raw_out_sha256` in committed artifact |
| BYTE-03 | 23-02, 23-03 | ✓ SATISFIED | `aeson_is_absent_from_the_storage_path` green over 8 files, 0 matches confirmed by direct grep |
| BYTE-05 | 23-01, 23-02, 23-04, 23-05 | ✓ SATISFIED | 3 `SilentlyCorrupted` corpus members confirmed present in source and matched in committed artifact |
| KEY-07 | 23-01, 23-02, 23-03, 23-04, 23-05 | ✓ SATISFIED | DDL constraint over all 3 columns confirmed by direct read; live catalogue read (`unique_constraint.columns`) in artifact = `["model","key_scheme","key"]` |

All nine requirement IDs from the task are present in the union of the five plans' `requirements:`
frontmatter (cross-checked), and REQUIREMENTS.md carries `[x]` for all nine with traceability rows
whose final verdict is "Complete" and whose cited evidence matches what was independently
reproduced above. No orphaned requirements found — the phase's roadmap row lists exactly
`DB-01..04, BYTE-01, BYTE-02, BYTE-03, BYTE-05, KEY-07` (9), matching the plans' union exactly.

### Anti-Patterns Found

None. No `TODO`/`FIXME`/placeholder markers found in the Store modules; no stub `return null`/
empty-handler patterns; the deliberately-empty default (`default_pgstore_dsn = ""`) is documented
and load-bearing (libpq's own PG* env-var fallback), not a placeholder.

### Human Verification Required

None. Every item in scope was verifiable by build, test-binary execution, source read, and
reproduced mutation.

### Gaps Summary

No gaps. All seven scoped observable truths verified by independent reproduction (not by trusting
SUMMARY prose), all nine requirement IDs cross-referenced against both REQUIREMENTS.md and live
code/artifact state, the measured state block in the task (build clean, 111/111, territory clean)
reproduced exactly, and three of the eighteen claimed guard-firings were independently reproduced
and restored byte-identical, all matching their SUMMARY's claims precisely — including one
verbatim GHC compiler error and one two-check cascade failure.

One phase-level finding, already disclosed honestly by the phase itself and not a gap: research
guard #13 (`PGSTORE_DSN`'s override-consumer-fails-naming-the-value arm) cannot be observed from
`cabal test` by construction (its consumer is libpq, unreachable from the DB-free test suite), and
the phase records this as an open finding rather than manufacturing a vacuous probe to close it.
This is the correct behavior for the defect class this phase exists to guard against, not a defect
in the phase.

---

_Verified: 2026-08-16T18:03:24Z_
_Verifier: Claude (gsd-verifier)_
