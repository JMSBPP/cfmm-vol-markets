---
phase: 28-resident-loop-fixture-publication
verified: 2026-08-23T08:15:00Z
status: passed
score: 5/5 requirements verified for their chain-free halves (LOOP-01..05); 2 external blocks confirmed named and gated, not silently missing
---

# Phase 28: Resident Loop & Fixture Publication Verification Report

**Phase Goal:** A loop that survives its own crash, never double-counts an event, never conflates
"already solved this shock" with "already saw this event", and publishes exactly one file the
forge test can never observe half-written.

**Verified:** 2026-08-23T08:15:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | The loop discovers new `next` events by polling from a persisted watermark, and a restart resumes without skipping (LOOP-01) | ✓ VERIFIED | `loop_watermark` is a table (migration 004, `only_row` PK + CHECK), `run_loop` re-reads it from the ledger every pass (`offchain/lib/Loop/Run.hs`). Check `a_restart_resumes_at_the_watermark_and_skips_nothing` PASS in the live `cabal test` run. |
| 2 | Replaying the same event produces one row/no second solve; two distinct events with an identical shock produce one cache entry and two rows (LOOP-02) | ✓ VERIFIED | `the_same_event_twice_produces_one_row_and_no_second_solve` and `two_distinct_events_with_one_shock_make_one_entry_and_two_rows` PASS. `loop_event` unique on `(tx_hash, log_index)` (migration 004, confirmed by direct read). LOOP-02's loop-level arms folded into `a_cache_hit_publishes_at_the_events_own_block`, confirmed PASS. |
| 3 | A reader racing the publisher for 10s sees zero torn/unparseable fixtures; a non-atomic writer is shown to tear in the same harness (LOOP-03) | ✓ VERIFIED | `a_reader_racing_the_publisher_sees_no_torn_fixture` and `a_non_atomic_writer_is_observed_tearing_the_same_reader` PASS. Single `renameFile` call site confirmed at `offchain/lib/Driver/Capture.hs:422`. |
| 4 | Publication writes exactly one file into the other workstream's tree and nothing else; a missing directory is a loud, named failure (LOOP-04) | ✓ VERIFIED | `publication_adds_exactly_one_file_and_nothing_else`, `a_missing_fixture_directory_is_a_loud_named_failure`, `the_default_fixture_path_is_the_consumers_own_constant` PASS. `test/models/mev_tax_model_one/fixtures/` confirmed absent from worktree and `origin/develop` (both directly reproduced). |
| 5 | SIGINT and an exception injected at each iteration stage leave the store/fixture consistent, observed only at a block boundary (LOOP-05) | ✓ VERIFIED | `an_exception_at_each_stage_leaves_the_watermark_unadvanced` (7 stages, data-driven per-stage dispositions confirmed in source), `an_interrupt_is_observed_only_at_a_block_boundary`, `the_published_fixture_survives_an_interrupted_iteration` PASS. `env_interrupted` read at exactly two points between blocks (`Loop/Run.hs:566,614`), confirmed by direct read. |

**Score:** 5/5 truths verified (chain-free halves, as the phase itself scopes them — see Gaps Summary for why this is the correct scope)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `offchain/migrations/004_loop_ledger.sql` | `loop_event` unique on `(tx_hash, log_index)`, single-row `loop_watermark` | ✓ VERIFIED | Read directly; `constraint loop_event_identity unique (tx_hash, log_index)` present verbatim; `loop_watermark` has PK + CHECK on `only_row`. |
| `offchain/lib/Loop/Ledger.hs` | `Ledger` seam, one-call/one-transaction block commit, memory+postgres | ✓ VERIFIED | Exists, exports match plan frontmatter, `withTransaction` referenced (grep confirmed indirectly via successful build/test). |
| `offchain/lib/Loop/Solve.hs` | S2/S3 closed: `solver_for`, `classify` | ✓ VERIFIED | Exists; imported in `LoopMain.hs`; `grep -c` over `offchain/lib/Loop/` for the resolving module names = 0 (structural boundary confirmed). |
| `offchain/lib/Gams/Detect.hs` | `detect_toolchain` — S1 closed | ✓ VERIFIED | Exists, checks pass (`detect_toolchain_refuses_every_wrong_subject_banner`, `detect_toolchain_is_driven_end_to_end_against_a_stub`). |
| `offchain/lib/Loop/Run.hs` | One iteration function; `env_interrupted`; `HaltBlockException` wrapper | ✓ VERIFIED | Directly read: `try (process_block ...)` wrapping into `HaltBlockException` (line ~602), `env_interrupted` read at two points (566, 614), `publish_for` wrapped in `try` (505). |
| `offchain/lib/Loop/Config.hs` | Exit-code table (10 non-zero entries), `LOOP_POLL_MS` | ✓ VERIFIED | Directly read: exactly 10 entries (30-34, 40-44), matches SUMMARY table exactly. Disjointness grep `grep -cE "\b(11\|124\|137\|145)\b"` = 0, confirmed. |
| `offchain/lib/Loop/Publish.hs` | Shape floor, identity splice, atomic publish, `publish_precondition` | ✓ VERIFIED | Exists; checks pass; publication directory precondition confirmed exiting 40 in exit table. |
| `offchain/app/LoopMain.hs` | The executable; resolves, detects, wires, loops, exits by table | ✓ VERIFIED | Exists; imports resolving module (`resolve_gams_bin`/`resolve_gams_model`, confirmed at lines 55, 136-137) — the one permitted importer, per S2's structural rule. |
| `offchain/rig/capture-loop.sh` | The live Tier-C run, gated, unrun | ✓ VERIFIED | Exists, executable. Run directly with no rig up: exits 1, prints `CAPTURE FAIL: nothing answered eth_blockNumber ...`, writes nothing (`offchain/rig/loop-conformance.json` absent afterward, `git status --porcelain` unchanged). |
| `.planning/phases/28-resident-loop-fixture-publication/28-SUMMARY.md` | Phase record | ✓ VERIFIED | Exists, cross-checked against ROADMAP.md/REQUIREMENTS.md/STATE.md — all four documents agree with each other and with the codebase. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `Loop.Solve` | `Store.Cache.decide` | `classify` consumes `Either ArgvError Decision` | ✓ WIRED | `try (decide (env_store env) ...)` at `Loop/Run.hs:413`; suite green. |
| `Loop.Ledger` | `loop_event`/`loop_watermark` | `withTransaction` around both | ✓ WIRED | `a_block_commit_is_one_transaction_on_both_ledgers` PASS. |
| `Loop.Run` | `Loop.Ledger.ledger_commit_block` | one call per block | ✓ WIRED | `try (ledger_commit_block (env_ledger env) block (reverse rows))` at `Loop/Run.hs:322`. |
| `app/LoopMain.hs` | `Gams.Invoke.resolve_gams_bin`/`resolve_gams_model` | startup resolution, outside S2 | ✓ WIRED | Confirmed import + call sites at `LoopMain.hs:55,136-137`; `grep -rc` over `offchain/lib/Loop/` for these names = 0. |
| `Loop.Publish` | `Driver.Capture.write_bytes_atomically`/`write_atomically` | temp sibling + rename, one directory | ✓ WIRED | `write_atomically` is the sole `renameFile` call site in the repo (`Driver/Capture.hs:422`), confirmed by direct grep. |
| `Loop.Run` | `Loop.Publish.publish_fixture` | called for every outcome carrying an artifact, elided included | ✓ WIRED | `publish_for` at `Loop/Run.hs:495-505`, wrapped in `try`; `a_cache_hit_publishes_at_the_events_own_block` PASS. |
| `Loop.Config` | `.../AlgebraIntegralMevTaxModelOneShocks.t.sol` on `origin/develop` | `default_fixture_path` vs `VOLUME_PATH_JSON` | ✓ WIRED | `the_default_fixture_path_is_the_consumers_own_constant` PASS; live `git show origin/develop:...` trip-wire confirmed present in test source (per 28-04-SUMMARY, re-verified indirectly via passing suite). |
| `Loop.Run` | the block boundary | interrupt flag read between blocks only | ✓ WIRED | `env_interrupted` calls at `Loop/Run.hs:566` (top of pass) and `614` (after iteration, before next block) — both outside `process_block`'s call. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| LOOP-01 | 28-02 | Loop discovers events by polling from a persisted watermark; restart resumes without skipping | ✓ SATISFIED (chain-free half) | Watermark is a store row (migration 004); restart proof PASS; live poll blocked by name on CHAIN-01/#26 (recorded in REQUIREMENTS.md, ROADMAP.md, and the LoopMain precondition chain). |
| LOOP-02 | 28-01, 28-05 | Seeing the same event twice does not duplicate work or corrupt the store | ✓ SATISFIED | Both directions asserted against reference implementations (28-01) and over the loop itself (28-05); all relevant checks PASS. |
| LOOP-03 | 28-03 | Newest run published by atomic rename; consumer never observes a partial file | ✓ SATISFIED | Race harness measured 0/204,555 torn on the atomic writer vs 1,240,687/1,333,592 (93%) torn on the non-atomic control; both checks PASS live. |
| LOOP-04 | 28-04 | Publication writes exactly one file and nothing else; missing directory is a loud named failure | ✓ SATISFIED (against temp dirs; real tree absent, recorded as such) | Tree-diff and precondition checks PASS; `test/models/mev_tax_model_one/fixtures/` confirmed absent from both worktree and `origin/develop` directly. |
| LOOP-05 | 28-05 | Crash/interrupt mid-cycle leaves store and fixture consistent | ✓ SATISFIED | Seven-stage exception battery and boundary-only shutdown checks PASS; per-stage dispositions (`sb_commits`, `sb_solved`) confirmed as data in source, matching the two by-design deviations. |
| STORE-07 | 28-01 | (Not phase-28 native; referenced) append-only run log | 🟡 PARTIAL BY CONSTRUCTION, correctly recorded as deferred | Migration 004 header states the gap explicitly; REQUIREMENTS.md traceability row confirms "PARTIAL BY CONSTRUCTION at 28-01, and it is NOT closed by it." No orphan — recorded exactly where the task said it would be. |
| CHAIN-01 | Phase 27 (carried) | The `Shock` emitter | ⛔ BLOCKED, by name | Confirmed named in REQUIREMENTS.md (multiple locations), ROADMAP.md, 28-SUMMARY.md, `capture-loop.sh`'s own refusal text, and `Chain/Endpoint.hs`'s `endpoint_sites` entry for `capture-loop.sh`. Gate reproduced live: exit 1, correct message, nothing written. |

No orphaned requirements found: every ID declared across the five plan frontmatters (LOOP-01..05) has a corresponding traceability row in REQUIREMENTS.md, and the cross-referenced CHAIN-01/STORE-07 items are consistently named in all four documents (CONTEXT, REQUIREMENTS, ROADMAP, STATE) and in the code itself (capture-loop.sh's refusal text, migration 004's header).

### Anti-Patterns Found

None found that constitute blockers. The phase's own SUMMARY and deferred-items.md are unusually thorough in naming everything left undone (RPC retry, real SIGINT never delivered, `br_published` meaning only "write returned" not "read back," 4 untracked root files predating the phase). All of these are recorded as deliberate, named deferrals rather than hidden gaps, and none contradicts the phase's stated scope (chain-free proofs only).

One item worth flagging as informational: `HaltRpcExhausted` reports exactly one attempt (no retry loop wired yet), per 28-CONTEXT's "bounded retry with backoff" ruling. This is explicitly filed in `deferred-items.md` under 28-02 and repeated under 28-05 as still open — not a silent gap.

### Human Verification Required

None required for this verification pass. All must-haves are either directly observable via `cabal build`/`cabal test`/direct file reads/direct script execution (all performed above) or are explicitly, consistently recorded as blocked-by-name external dependencies (CHAIN-01/#26, the fixtures directory/#24/#25) whose absence is itself asserted as a verdict in the test suite (`the_live_loop_capture_is_present_and_names_its_block`, `the_fixtures_directory_is_recorded_absent_from_both_trees`).

The only outstanding live-path verification — running `offchain/rig/capture-loop.sh` against a real chain with a real `Shock` emitter — is explicitly out of this workstream's control (issue #26) and is correctly not claimed as done anywhere in the phase's documentation.

### Gaps Summary

No gaps found relative to what Phase 28 actually committed to deliver. The phase's own framing is careful and was verified to be accurate rather than aspirational: LOOP-01 through LOOP-05 are complete for their **chain-free halves**, which is what the phase's plans, ROADMAP.md's success criteria, and REQUIREMENTS.md's traceability table all say — none of them claims the live end-to-end path works. That live path is explicitly and consistently named as blocked on two external tracks (issue #26 for the `Shock` emitter, issues #24/#25 for the publication directory), and both blocks were independently reproduced during this verification:

- `bash offchain/rig/capture-loop.sh` with no rig running: exit 1, `CAPTURE FAIL: nothing answered eth_blockNumber at http://127.0.0.1:8545. This is NOT a skip. ...`, no artifact written, tree unchanged.
- `find test -path "*mev_tax_model_one*"` and `git ls-tree -r --name-only origin/develop | grep -c "^test/models/mev_tax_model_one/fixtures"`: both empty/0, confirming the fixtures directory is on neither tree.

All measured numbers reproduced exactly:
- `cabal build --enable-tests -j all`: exit 0, 0 warnings, 0 `Downloading` lines.
- `cabal test`: 232/232 checks passed, exit 0, wall clock ~9m18s (within the claimed ~9 minutes / 551s-class range).
- `purge_file_floor` (hs+sh+sql): 83. `credential_scan_floor` (+json): 94. Extension census: hs 66, sh 13, json 11, sql 4. Migrations: 4.
- `endpoint_sites`: 20 entries (counted directly in `Chain/Endpoint.hs`).
- `exit_table`: 10 non-zero entries, matching the claimed codes 30-34/40-44 exactly.
- Migration 004's `loop_event_identity` constraint: `unique (tx_hash, log_index)`, verbatim.
- The one `renameFile` call site: `Driver/Capture.hs:422`, inside `write_atomically`.
- The seven-stage exception battery (`loop_stage_breaks` in `offchain/test/Main.hs`) matches the SUMMARY's disposition table exactly: `publish` is the only stage with `sb_commits=True`, and `identity`/`publish`/`commit` are the three stages with `sb_solved=True` (decide already wrote the store entry).
- The `Driver.Capture` EXDEV haddock correction (deviation d) is present verbatim, correcting the three-phase-old "silently degrade to a copy" claim.
- All 18 spot-checked commit hashes from the five plan SUMMARYs exist in git history.
- Git tree is clean at `4605ca8` except for the four pre-existing untracked root files (`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock`), which are correctly and repeatedly documented as predating this phase and out of its scope.

The two executor-reported "deviation" items from the task brief were also independently confirmed in source:
(a) `publish_for`'s write is wrapped in `try` (per-stage exception `publish` has `sb_commits=True`), and `decide` writes the store entry before the `identity`/`publish`/`commit` stages (`sb_solved=True` for those three) — both confirmed directly in `offchain/test/Main.hs`'s `loop_stage_breaks` definition and in `Loop/Run.hs`'s `try (decide ...)` placement relative to `publish_for`/`ledger_commit_block`.
(b) `HaltBlockException`/exit 34 confirmed as the tenth entry in `Loop/Config.hs`'s `exit_table`.

STORE-07 is correctly recorded as partial-by-construction (not closed), matching REQUIREMENTS.md's traceability row and migration 004's own header verbatim.

---

*Verified: 2026-08-23T08:15:00Z*
*Verifier: Claude (gsd-verifier)*
