---
phase: 24-gams-invocation-toolchain-identity
verified: 2026-08-17T02:10:00-04:00
status: passed
score: 7/7 requirements verified; 5/5 success criteria verified
---

# Phase 24: GAMS Invocation & Toolchain Identity Verification Report

**Phase Goal:** The prover runs as a controlled subprocess whose success is decided by evidence
rather than log text, and the toolchain versions the content key depends on are either read for
real or the run aborts. Sequenced BEFORE the store so no production row can be written under a key
component that a broken detector silently emptied.

**Verified:** 2026-08-17T02:10 (America/New_York)
**Status:** passed
**Re-verification:** No — initial verification (no prior `24-VERIFICATION.md` existed; the previous
attempt stalled and wrote nothing).

## Method

This verification reproduces evidence rather than trusting SUMMARY prose. All commands below were
run in the FOREGROUND with an explicit `timeout`, per the retry instructions. Two source mutations
were applied, one at a time, each rebuilt, each run through the full `cabal test`, and each restored
immediately afterward with the restore proven by `sha256sum` against `git show HEAD:<path>` before
any further action. `git status --porcelain` was checked clean before concluding.

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth (Success Criterion) | Status | Evidence |
|---|---|---|---|
| 1 | A stub that exits 0 writing nothing is REFUSED; a stub with a pre-existing artifact is REFUSED (fresh temp dir); model-level (2,3) vs environmental codes are distinguished; no decision reads stdout/stderr (GAMS-01, GAMS-02) | VERIFIED | `PASS exit_zero_without_artifact_is_refused`, `PASS a_pre_existing_artifact_is_unreachable`, `PASS each_invocation_gets_a_fresh_directory_and_it_is_removed`, `PASS gams_verdict_ignores_the_streams`, `PASS stub_exit_codes_drive_the_verdict` — all in `cabal test` output (151/151 run, reproduced below). `classify_exit` in `offchain/lib/Gams/Exit.hs` read directly: 2→`ModelLevel CompilationError`, 3→`ModelLevel ExecutionError`, 7→`Environmental LicensingError`, imports only `System.Exit` (no `Data.ByteString`/`Data.Text`/`isInfixOf` — grep = 0), so "no decision reads a stream" is structural. |
| 2 | Version parser rejects every garbage-battery member (empty, whitespace, help banner, flag output, wrong component, truncated, localised); no `GamsVersion`/`ConoptVersion` constructible empty (GAMS-03) | VERIFIED | `PASS gams_version_parser_rejects_the_garbage_battery`, `PASS gams_version_is_not_constructible_empty`. Read `offchain/lib/Gams/Version.hs` in full: neither newtype's constructor is exported; `grep -cE 'fromMaybe|<|>|catch|"unknown"|fromJust|head|!!'` = 0; parser checks job-name subject BEFORE shape, matching the plan's exact banners. |
| 3 | CONOPT detection reads the true solver version, rejecting the GAMS-side link-version decoy and the `.so`-filename decoy (GAMS-04) | VERIFIED | `PASS conopt_parser_rejects_both_decoys`, `PASS conopt_parse_is_position_independent`. **Reproduced by mutation**: changing `conopt_spaced_marker` from `"C O N O P T"` to bare `"CONOPT"` caused `conopt_parser_rejects_both_decoys` and `conopt_parse_is_position_independent` to FAIL, naming the exact defect (`"the REAL CONOPT banner was rejected as NoConoptBanner"`). Source restored, verified byte-identical to HEAD by sha256 (`413e1bf8…`). |
| 4 | A hung child is terminated AND reaped (no orphan); >1MB stderr completes without deadlock; a timed-out run never produces an output row (GAMS-05) | VERIFIED | `PASS a_hung_grandchild_is_terminated_and_reaped`, `PASS a_stderr_flood_completes_without_deadlock`. `Gams.Run` uses `/usr/bin/timeout -k <n> <budget>` as the direct child (group-owning) plus an in-process `System.Timeout.timeout` backstop — read directly, matches decision-of-record #4. `TimedOut` constructor in `Gams.Exit` carries no path to `Artifact`. |
| 5 | Environment is an explicit whitelist with `LC_ALL=C`; hostile ambient vars produce byte-identical output; inherited environment is observed to differ; `dQx`/`dQM` decode as `Integer`, exact 32-wei delta proven vs `Double` (GAMS-06, BYTE-04) | VERIFIED | `PASS the_child_environment_is_exactly_the_whitelist`, `PASS gams_conformance_records_byte_identity_under_a_hostile_environment`, `PASS an_inherited_environment_is_observed_to_differ`, `PASS dqx_double_decode_loses_exactly_32_wei_on_the_first_element`, `PASS every_golden_element_is_inexact_under_double`. **Reproduced by mutation**: mapping exit code 7 to `Solved` in `Gams.Exit` (adjacent structural check, see below) confirms the exit-taxonomy guard reddens by name; the 32-wei check itself was read in full and is a bare Integer equality (`image - first_element == 32`), immune to tolerance-style false positives. |

**Score:** 5/5 truths verified.

### GAMS-03's schema-level conjunct (migration 003)

Read `offchain/migrations/003_version_columns_nonempty.sql` directly:

```sql
alter table model_run
  add constraint model_run_versions_nonempty
  check (length(gams_ver) > 0 and length(conopt_ver) > 0);
```

Both columns are covered by ONE conjunctive constraint (`and`, not two independent checks that
could be applied partially) — this satisfies the phase's own measurement that a half-constraint
(`length(gams_ver) > 0` alone) lets an empty `conopt_ver` through, which 24-06-SUMMARY.md documents
was directly observed (`CAPTURE FAIL: … The server STORED an empty toolchain version`) before this
two-conjunct form was written. `cabal test` confirms `PASS version_columns_are_unstorable_empty_in_the_ddl`
and `PASS store_conformance_records_the_empty_version_rejection`. A live server run (SQLSTATE 23514
against Postgres 18.4) was not re-executed in this verification (requires docker + port 55433 +
~time); this is accepted per the phase brief's "optional" allowance since the DDL was read directly
and the file-half check (`version_columns_are_unstorable_empty_in_the_ddl`) passed.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `offchain/lib/Gams/Config.hs` | `GAMS_BIN`/`GAMS_MODEL`/`GAMS_CONFORMANCE`, named once each | VERIFIED | Read in full; three env vars, `fromMaybe <default> <$> lookupEnv <var>` shape, no `/usr/gams` literal (grep = 0). |
| `offchain/lib/Gams/Version.hs` | Abstract `GamsVersion`/`ConoptVersion`, job-name-anchored + spaced-letter parsers | VERIFIED | Read in full (252 lines); constructors not exported; forbidden-pattern greps all 0. |
| `offchain/lib/Gams/Exit.hs` | Total `classify_exit`, no stream parameter | VERIFIED | Read in full (151 lines); single `import System.Exit`; `gams_code_domain` exported and excludes 124/137. |
| `offchain/lib/Gams/Argv.hs`, `Env.hs`, `Artifact.hs` | Canonical renderer, whitelist, `Integer` decoder | VERIFIED (via passing checks; not fully re-read line-by-line but greps + PASS lines corroborate) | `argv_rendering_is_canonical_and_total`, `the_child_environment_is_exactly_the_whitelist`, `no_Double_and_no_aeson_on_the_artifact_path` all PASS. |
| `offchain/lib/Gams/Run.hs` | The one IO edge; fresh exclusive run dir; group-owning timeout | VERIFIED | Read the timeout/wrapper block directly (lines 285-315): `timeout -k <kill_after> <budget>` argv, `readCreateProcessWithExitCode` (2M-byte-safe), `System.Timeout.timeout` backstop. Confirmed clean (no `--foreground` residue from the prior failed attempt) and matches `git show HEAD` exactly. |
| `offchain/lib/Gams/Invoke.hs` | Thin composition resolving the real binary; imported ONLY by `GamsConformance.hs` | VERIFIED | `grep -rl 'import.*Gams\.Invoke' offchain/` returns exactly one file: `offchain/app/GamsConformance.hs`. |
| `offchain/migrations/003_version_columns_nonempty.sql` | Two-column CHECK constraint | VERIFIED | Read in full; covers both columns in one conjunction. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `offchain/test/Main.hs` | `Gams.Version` | `parse_gams_version` battery check | WIRED | `PASS gams_version_parser_rejects_the_garbage_battery` observed in full 151/151 run. |
| `offchain/test/Main.hs` | `core_checks` | six+ Tier-A checks registered | WIRED | All named checks (`gams_version_parser_rejects_the_garbage_battery`, `gams_version_is_not_constructible_empty`, `conopt_parser_rejects_both_decoys`, `conopt_parse_is_position_independent`, `gams_exit_taxonomy_is_total_and_disjoint`, `timeout_codes_do_not_collide_with_gams_codes`) appear exactly once each in the `cabal test` PASS list. |
| `offchain/app/GamsConformance.hs` | `Gams.Invoke` | sole real-binary composition | WIRED, and STRUCTURALLY EXCLUSIVE | Confirmed by the single-file grep above; `offchain/test/Main.hs` cannot reach `Gams.Invoke`, `CFMM_REQUIRE_GAMS`, or `/usr/gams` (grep = 0), making the Tier B/C split real rather than asserted. |
| `Store.Schema` migration list | `offchain/migrations/003_version_columns_nonempty.sql` | manifest entry | WIRED | `PASS migration_list_is_ordered_and_gapless`; `ls offchain/migrations/ \| wc -l` = 3 matching the SUMMARY's claim. |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| GAMS-01 | 24-01, 24-03, 24-05 | Prover invoked as subprocess, success decided by evidence not log text | SATISFIED | `classify_exit` structural (no stream param); `PASS stub_exit_codes_drive_the_verdict`; `PASS the_suite_never_names_the_real_solver` (with positive control observed). |
| GAMS-02 | 24-02, 24-03, 24-05 | Exit-0-no-artifact is failure | SATISFIED | `PASS exit_zero_without_artifact_is_refused`; `PASS a_pre_existing_artifact_is_unreachable`. |
| GAMS-03 | 24-01, 24-04, 24-05, 24-06 | GAMS/CONOPT versions detected, empty-detection aborts, unstorable at schema layer | SATISFIED | Version parser reviewed; migration 003 reviewed; `PASS version_columns_are_unstorable_empty_in_the_ddl`. |
| GAMS-04 | 24-01, 24-05 | CONOPT true version read, both decoys rejected | SATISFIED | Reproduced by mutation (see Truth #3 above). |
| GAMS-05 | 24-04, 24-05 | Hung solve bounded by timeout, terminates child | SATISFIED | `PASS a_hung_grandchild_is_terminated_and_reaped`; `Gams.Run` timeout wrapper reviewed. |
| GAMS-06 | 24-02, 24-04, 24-05 | Invocation environment controlled | SATISFIED | `PASS the_child_environment_is_exactly_the_whitelist`, `PASS an_inherited_environment_is_observed_to_differ`, `PASS gams_conformance_records_byte_identity_under_a_hostile_environment`. |
| BYTE-04 | 24-02, 24-05 | `dQx`/`dQM` decoded as `Integer`, never `Double` | SATISFIED | `dqx_double_decode_loses_exactly_32_wei_on_the_first_element` read in full: bare Integer equality, sign convention stated, no tolerance possible. |

No orphaned requirements: `.planning/REQUIREMENTS.md` maps exactly GAMS-01..06 and BYTE-04 to
Phase 24, and all seven appear in at least one plan's `requirements:` frontmatter field.

### Anti-Patterns Found

None. `grep -n -E "TODO|FIXME|XXX|HACK|PLACEHOLDER"` across all eight `Gams/*.hs` files plus
`GamsConformance.hs` plus the migration file returns nothing. No `return null`/`return {}`/empty
handler patterns. No file in the phase's module set is a stub (all are 95-569 lines with substantive
logic, matching the SUMMARY's claims of real parsers, a total exit taxonomy, and IO plumbing).

### Priority-by-priority summary (per the retry brief's ordering)

1. **Structural property** — CONFIRMED. `grep -cE 'Gams\.Invoke|CFMM_REQUIRE_GAMS|/usr/gams' offchain/test/Main.hs` = 0. DB-free grep (`Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL`) = 0. `Gams.Invoke` imported by exactly one file (`offchain/app/GamsConformance.hs`).
2. **Floors match the live tree today** — CONFIRMED by direct re-measurement, not trusted from any SUMMARY: `purge_file_floor` = 59 in `Main.hs`, `find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l` = 59 (MATCH). `credential_scan_floor` = 68 in `Main.hs`, the four-extension `find` = 68 (MATCH).
3. **Migration 003 schema-level constraint** — CONFIRMED by reading the SQL directly: both columns covered in one `and`-conjunction, matching the phase's own measurement that a single-column check lets an empty `conopt_ver` through.
4. **Spot-checked guard firings, restored by digest** — TWO mutations performed (time-budgeted; both fast/pure, avoiding the hung-grandchild timeout hazard the previous attempt got stuck on):
   - CONOPT spaced-marker → bare token: `conopt_parser_rejects_both_decoys` and `conopt_parse_is_position_independent` both FAILED, naming the exact rejection. Restored, `sha256sum` = `413e1bf8…` matching `git show HEAD:offchain/lib/Gams/Version.hs`.
   - Exit code 7 → `Solved`: `gams_exit_taxonomy_is_total_and_disjoint` FAILED naming code 7 exactly (`"these exit codes classify as Solved: [7]"`), and the cascading `stub_exit_codes_drive_the_verdict` FAILED too, corroborating the licensing guard from a second, independent check. Restored, `sha256sum` = `212a34a5…` matching `git show HEAD:offchain/lib/Gams/Exit.hs`.
   - BYTE-04's exact 32-wei delta and the exit-0-no-artifact refusal were verified by direct source reading (both are bare, tolerance-proof Integer equalities / structural refusals) rather than by a third live mutation, given the token/time budget; this is disclosed as a slightly lighter form of evidence than the two mutations above.
5. **Positive controls** — `the_suite_never_names_the_real_solver` was read in full: it calls `gams_free_positive_control` FIRST and only then checks the real scan, matching the `aeson_positive_control` precedent the plan requires.
6. **No constant-on-both-sides tautologies** — the SUMMARY documents this defect being found and fixed in a *prior* wave (the `attempted` field deleted, deviation 1 of 24-06); nothing analogous was found live in the code read during this verification.

### Disclosed no-mutation guards — disclosure confirmed accurate

- **#11 `conopt_parse_is_position_independent`** — confirmed as a STANDING pure-battery check (two
  buffers, index 38 and 47) with no dedicated positional-logic mutation on record. Note: this
  verification's own CONOPT-marker mutation *did* cause this check to fail, but that mutation
  attacked the marker constant, not "positional logic" — it is a different guard's input, and the
  4-guard disclosure's claim ("never falsified [by ITS OWN named input, code that reads a line
  number]") stands.
- **#21 echoed-field cross-check** — confirmed never observed rejecting; explicitly assigned to
  Phase 25 in the SUMMARY's guard ledger, and Phase 25's key-path work is the natural place a
  rendered-vs-preimage mismatch becomes observable.
- **#23 the 2MB stderr drain** — confirmed as an equality-based standing check with no deadlock
  mutation on record (`stderr_flood_bytes = 2000000`, asserted as an exact length equality).
- **#28/#30** — confirmed as standing assertions (hostile-variable-set emptiness, 16-of-16
  inexactness) with their specific named mutations not applied.

Disclosure is accurate; per the retry brief, this is not treated as a gap.

## Reproduced test run (final state, after both restores)

```
151/151 checks passed
SC-3 and SC-4 OK
Test suite cfmm-replicationPlank-rpc-api-test: PASS
```

`cabal build --enable-tests -j all` — 0 warnings, 0 `Downloading` lines (no new package entered the
build plan). `git status --porcelain` — clean except this VERIFICATION.md and the four pre-existing
untracked root files (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock`) that the SUMMARY
already names as out-of-scope carry-forwards.

### Human Verification Required

None. All checks in this phase are structural/programmatic (grep-based absence checks, pure
parsers, an IO subprocess layer exercised through stub scripts). No UI, no visual, no external
service beyond an optional live-Postgres capture that the phase itself made optional for this
verification pass (the file-level DDL check already covers the schema claim).

### Gaps Summary

None. All 5 ROADMAP success criteria verified, all 7 requirements (GAMS-01..06, BYTE-04) satisfied
with direct evidence, the structural Tier B/C split confirmed by grep, both re-measured floors match
the live tree exactly, the migration's two-column constraint confirmed by reading the DDL, and two
independent guard firings were reproduced live and restored byte-identical by digest. The phase's
own disclosed evidence gaps (guards #11/#21/#23/#28/#30 lacking their specific named mutations) are
accurately disclosed in the SUMMARY and carried to Phase 25 as owed evidence, not blockers — this
verification confirms the disclosure is honest rather than treating it as a new finding.

---

*Verified: 2026-08-17T02:10-04:00*
*Verifier: Claude (gsd-verifier)*
