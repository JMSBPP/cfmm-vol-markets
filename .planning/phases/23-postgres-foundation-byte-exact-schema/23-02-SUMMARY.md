---
phase: 23-postgres-foundation-byte-exact-schema
plan: 02
subsystem: database
tags: [store-laws, key-scheme, byte-fidelity, aeson, haskell, falsification, mutation-testing]

# Dependency graph
requires:
  - "23-01: Store.Types (Artifact, KeyScheme, StoredRun, adversarial_corpus), Store.Class (the Store record), Store.Memory (new_memory_store)"
provides:
  - "Store.Laws — store_laws :: [(String, Store -> IO (Either String ()))] and law_names; SEVEN total laws, no partial function anywhere, no database client, no aeson"
  - "store_laws_run_against_the_memory_store — DB-03's 'still discriminate' half, delivered by REAL execution against a fresh store per law, no socket"
  - "expected_store_laws_is_the_law_set — the law surface as a SET, both directions, one message"
  - "adversarial_corpus_has_a_silently_corrupted_member — behaviour-tag SET + member-NAME SET + uniqueness + size"
  - "aeson_round_trip_mutations_are_re_measured — three mutations pinned as VALUES, re-measured every run"
  - "aeson_is_absent_from_the_storage_path — six-file scan with a proven positive control; RED until 23-03"
affects: [23-03 schema and migrations, 23-04 conformance capture, 23-05 checks, 25 content key]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The store contract as DATA (a named list of laws), so one implementation has two subjects and the SET can be asserted in both directions"
    - "A fresh store per law, so no law's writes can satisfy another law's read"
    - "A guard's scope is a NAMED file list including the file that does not exist yet — a missing file is a FAILURE naming the plan that creates it, never a pass"
    - "The anti-control for a deliberate red: stub the missing subject CLEAN and watch the suite go fully green, which pins the red's cause to the absent file and nothing else"

key-files:
  created:
    - offchain/lib/Store/Laws.hs
  modified:
    - offchain/test/Main.hs
    - offchain/lib/Store/Types.hs
    - cfmm-replicationPlank-rpc-api.cabal
    - .planning/REQUIREMENTS.md

key-decisions:
  - "aeson_storage_path names SIX files, not the plan's four: every module under offchain/lib/Store/ with NO exemptions, including Store/Types.hs, whose haddock was reworded to stop naming the import it does not have"
  - "expected_corpus_members added: the plan's behaviour-tag SET does not discriminate deleting octal-escape, because double-backslash carries the same tag"
  - "Both directions of the law-set mismatch are collected into ONE message rather than short-circuited, because a rename produces one violation of each kind"
  - "The deliberate red costs TWO FAIL lines, not one: sentinel_falsification_harness refuses to certify against a red baseline, which is the harness working"

patterns-established:
  - "Prose is inside the grep's blast radius — THREE more instances in this plan alone, one of them the acceptance criterion itself"
  - "Restore a mutated file from a SAVED COPY, never from `git checkout --`, when that file also carries uncommitted work"

requirements-completed: []
requirements-partial: [DB-03, BYTE-03, KEY-07]
requirements-untouched-despite-plan-frontmatter: [BYTE-05]

# Metrics
duration: 62min
completed: 2026-08-16
---

# Phase 23 Plan 02: The Store Laws Summary

**Seven store laws now EXECUTE for real against `Store.Memory` inside `cabal test` with no server
and no socket — every one of them OBSERVED firing against a named wrong store — and the law SET,
the corpus SET and BYTE-03's two aeson guards are locked around them, with the suite ending
deliberately RED on the not-yet-written `Store/Postgres.hs`.**

## Performance

- **Duration:** 62 min
- **Started:** 2026-08-16T14:05:00Z
- **Completed:** 2026-08-16T15:07:00Z
- **Tasks:** 3
- **Files modified:** 5 (1 created, 4 modified)

## MEASURED VALUES (the output block this plan owes)

### Check counts, against 23-01's cold baseline

```
23-01 COLD BASELINE (re-measured cold at the start of this plan, NOT inherited)
  cabal test                          ->  91/91 checks passed, SC-3 and SC-4 OK
  cabal build --enable-tests -j all   ->  exit 0, 0 offchain warning lines

AFTER TASK 1 (Store.Laws; registers no check)
  91/91 checks passed                 ->  UNCHANGED, as the task requires

AFTER TASK 2 (three checks registered)
  94/94 checks passed                 ->  BASELINE + EXACTLY 3
  0 FAIL lines

AFTER TASK 3 (two more checks registered)
  94/96 checks passed                 ->  BASELINE + EXACTLY 5, 2 red
  2 FAIL lines  (see "The transient red" below)

AFTER TASK 3, WITH A CLEAN STUB Store/Postgres.hs ON DISK (anti-control C2)
  96/96 checks passed                 ->  everything green, BOTH failures gone
```

Every number above came from running the built test binary directly
(`dist-newstyle/.../cfmm-replicationPlank-rpc-api-test`). `cabal test` buffers the runner's stdout
and does not reliably surface the `N/M checks passed` line on a cached re-run, which is exactly the
"read the log, not the wrapper" problem this repo has been bitten by; the binary was used for every
recorded count.

`cabal build --enable-tests -j all` exited 0 with **0** lines matching
`^offchain/[^ ]*:[0-9]+:[0-9]+: warning:` after every task. The bare `cabal build -j all` is VACUOUS
and was never run.

```
find offchain -name '*.sql' | wc -l   ->  0     (sc3_literal_purge untouched by this plan)
grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs  ->  0
```

### aeson's mutations, RE-MEASURED at this build plan

GHC 9.10.3, `aeson 2.2.5.0` (read out of the resolved `dist-newstyle/cache/plan.json`, not assumed).
Driven through `cabal repl` against the real library:

```
{"d":0.00318353}     =>  {"d":3.18353e-3}
{"v":2.8e19}         =>  {"v":28000000000000000000}
{"b":"a","a":"b"}    =>  {"a":"b","b":"a"}
{"z":1.0}            =>  {"z":1.0}                   -- aeson is the IDENTITY here; NOT pinned
```

The research's two vectors are CONFIRMED, not cited. The third (key reorder) was added because it
is the vector that ties BYTE-03 to BYTE-02 — aeson reorders object keys for the same reason `jsonb`
does. The fourth is recorded as an honest negative: it is a JSON document aeson does **not** mutate,
so it would be useless as a vector, and pinning it would have made the check pass on a tautology.

## Guards observed firing

A guard never seen rejecting is treated as absent. Nine arms across three tasks, all verbatim, all
sources restored.

### The seven store laws — a full falsification table, with the CONTROL first

Driven through `cabal repl` against the real `Store.Laws`, with deliberately-wrong stores built by
record update on `new_memory_store` (the instrument `Store.Class`'s record-of-functions shape exists
for). `FIRED` is a `Left`; blank is `Right ()`.

| Law | control | A `byteain` blob write | B phantom `get_blob` | C key drops `key_scheme` | D key drops `model` | E last-writer-wins | F `put` is a no-op |
|---|---|---|---|---|---|---|---|
| `law_blob_round_trips_byte_identically` | ok | **FIRED** | | | | | |
| `law_blob_lookup_of_an_absent_name_is_nothing` | ok | | **FIRED** | | | | |
| `law_key_scheme_orphans_rather_than_matching` | ok | | | **FIRED** | | | |
| `law_same_key_under_a_new_scheme_inserts` | ok | | | **FIRED** | | | **FIRED** |
| `law_put_then_lookup_returns_the_same_artifact` | ok | | | | | | **FIRED** |
| `law_distinct_models_do_not_collide` | ok | | | | **FIRED** | | **FIRED** |
| `law_first_writer_wins_on_the_identity_triple` | ok | | | | | **FIRED** | **FIRED** |

The control column is what makes the rest evidence: all seven are `Right ()` against the correct
`Store.Memory` before a single mutant is applied.

Two messages worth quoting, because they are what an operator reads:

```
MUTANT-A/bare-ByteString-write-path: law_blob_round_trips_byte_identically:
  member octal-escape went in at 6 bytes and came back at 3 bytes

MUTANT-C/key-drops-key_scheme: law_key_scheme_orphans_rather_than_matching:
  a row was written under key_scheme KeyScheme 1 and a lookup under KeyScheme 2 for the same
  (model, key) returned 7 bytes, sha256 015abd7f... A superseded scheme must orphan, never
  almost-match.
```

Mutant A is the MEASURED PG 18.4 corruption reimplemented (`byteain` re-reads `\101` as one octal
byte), so the law reports the research's exact `6 -> 3` rather than a digest mismatch.

**HONEST NEGATIVES from the same table, and they bind later plans:**

1. **MUTANT C moves EXACTLY TWO laws.** The other five are completely unchanged by dropping
   `key_scheme` from the identity. This reproduces 23-01's G4 finding *through the law set itself*
   rather than through a repl transcript, and it is why those two laws may never be dropped.
2. **`law_key_scheme_orphans_rather_than_matching` does NOT fire under MUTANT F.** A store that
   stores NOTHING satisfies orphaning trivially. That law is evidence only alongside
   `law_put_then_lookup_returns_the_same_artifact` and `law_same_key_under_a_new_scheme_inserts`.
3. **MUTANT E (last-writer-wins) is caught by ONE law only.** `law_first_writer_wins_on_the_identity_triple`
   is the sole kill site, and Phase 25's determinism claim rests on it.

### GUARD #17 — the law SET. FIRED.

Input: rename `law_distinct_models_do_not_collide` to `law_distinct_models_do_not_collide_v2` in
`Store/Laws.hs` ONLY. Verbatim, and it names BOTH directions in one message:

```
FAIL expected_store_laws_is_the_law_set: Store.Laws defines a law this SET does not name: law_distinct_models_do_not_collide_v2
      this SET names a law Store.Laws does not define: law_distinct_models_do_not_collide
      The law surface is a SET on both sides: a law the set does not name is a law whose verdict
      nothing accounts for, and a name the library does not define is a set that has stopped
      describing anything. A duplicate name would let one law pad the surface for two.
```

**Honest negative from the same run:** `store_laws_run_against_the_memory_store` still **PASSED**
under the rename. A renamed law still executes and still holds, so the EXECUTION is not an
instrument for the surface — the SET is. That is why the length comparison inside the execution
check is documented as secondary and never as the primary.

### GUARD #3 — the corpus. FIRED.

Input: delete the `octal-escape` member from `adversarial_corpus` in `Store/Types.hs`. Verbatim:

```
FAIL adversarial_corpus_has_a_silently_corrupted_member: the corpus MEMBER SET has moved.
  Gone: octal-escape | new and unaccounted for: . The size assertion below is a count, and a
  count is satisfied by swapping the discriminating member for a harmless one -- which is exactly
  the substitution that would make plan 23-05's negative control vacuous while every number in
  this check still added up.
```

**This CORRECTS the plan.** The plan prescribed the behaviour-tag SET as the instrument for this
guard. MEASURED: it does not discriminate. `double-backslash` is also tagged `SilentlyCorrupted`, so
with `octal-escape` deleted all three behaviour classes are still present and both the tag-set
assertion and the `any SilentlyCorrupted` assertion stay GREEN. Only a count (7 vs 6) was left, and a
count is defeated by swapping the discriminating member for a harmless one — finding #3 in this
repo, verbatim. `expected_corpus_members` (the member set, both directions, ordered ahead of the
count) is what actually caught the deletion.

### BYTE-03 — three observations, so no part of the check is trusted unexercised

**C1 — the SCAN branch.** A stub `offchain/lib/Store/Postgres.hs` containing `import Data.Aeson (toJSON)`:

```
FAIL aeson_is_absent_from_the_storage_path: an aeson Value is on the STORAGE PATH. The bytes in
  the raw column are the oracle and aeson re-renders numbers and reorders keys -- MEASURED, and
  asserted as values in aeson_mutation_vectors:
      offchain/lib/Store/Postgres.hs:3:import Data.Aeson (toJSON)
```

**C2 — the ANTI-CONTROL.** The same stub, CLEAN (no aeson): `PASS aeson_is_absent_from_the_storage_path`
and the whole suite goes **96/96**. This is what pins the transient red's cause to the *missing file*
and nothing else — 23-01's own lesson that a failure on its own does not tell you which missing thing
caused it. It also measures exactly what 23-03 will land on.

**C3 — the POSITIVE CONTROL.** `aeson_pattern` mutated to `"zzz-a-pattern-that-cannot-match-anything"`:

```
FAIL aeson_is_absent_from_the_storage_path: BYTE-03's POSITIVE CONTROL did not fire: grep exited
  ExitFailure 1 over a file that imports the aeson module and calls toJSON. The pattern has
  stopped matching anything, which means the exit-1 the real scan reports is absence of MATCHES
  only by assumption.
```

So the seeded `bait.hs` **is** matched and **is** named by the identical argument vector, and an
exit-1 from the real scan is evidence rather than assumption. The control also asserts that a
seeded `clean.hs` is NOT named, so exit-0 is evidence about the PATTERN rather than about grep's
willingness to match something.

All three stubs and mutations were removed; `git status --porcelain offchain/lib/Store/` was clean
afterwards.

### Restoration digests

`sha256sum` before the mutations and after restoration — compared by **diffing digest files**, not
by asserting:

```
BEFORE                                                             AFTER (IDENTICAL)
31ff0584078c0aab7538014413688282815587ccb6eef2a67bbfbcf30ffa68db   offchain/lib/Store/Laws.hs
6c789dc4b5bcadd214bc1153978287072650ffc7e365992666e3bbc02150d58f   offchain/lib/Store/Types.hs
```

`diff` of the two digest files was EMPTY. (`Store/Types.hs` was subsequently CHANGED on purpose in
task 3 — the haddock reword — and that change is committed, not a restoration failure. The digest
above is its state across the task-2 mutation window.)

## THE TRANSIENT RED — deliberate, named, and closed by 23-03

`cabal test` ends on **TWO** FAIL lines, not one:

```
FAIL aeson_is_absent_from_the_storage_path: the storage path names files that are not on disk:
  offchain/lib/Store/Postgres.hs. offchain/lib/Store/Postgres.hs is created by PLAN 23-03 and this
  check is DELIBERATELY RED until it lands. Scoping the list to the files that exist would make
  this check pass because its subject is absent, which is the defect class this milestone's
  standing rule names. If a file was RENAMED, rename it here in the same commit.

FAIL sentinel_falsification_harness: the suite was ALREADY failing before a single mutation was
  applied (aeson_is_absent_from_the_storage_path). Every "caught" verdict below would be that
  pre-existing failure and not the mutation, so the sweep proves nothing until the baseline is
  green.
```

The second is **not a defect and not scope creep** — it is the harness working exactly as designed,
refusing to certify a sweep whose every "caught" verdict would be a pre-existing failure. It appeared
identically during both of task 2's mutation runs (92/94, two FAILs each time), which is how it was
predicted rather than discovered.

**23-03 closes BOTH with one file.** MEASURED, not argued: with a clean stub `Store/Postgres.hs` on
disk the suite is 96/96 and both names are green (anti-control C2 above).

A related measurement worth carrying: with a red baseline the sentinel sweep also becomes
structurally degenerate — the whole run drops from ~75s to ~8s, because the reader set collapses to
the single always-failing check and every pair is "caught" by it immediately. A red baseline does
not merely uncertify the harness; it empties it.

## Requirement status — NOT marked complete, and why

`requirements mark-complete` was deliberately NOT run, for the second plan running. The plan's
frontmatter claims `[DB-03, BYTE-03, BYTE-05, KEY-07]`; measured against what shipped, **none is
complete**.

| Req | Verdict | Evidence, and what is still owed |
|---|---|---|
| **DB-03** | **Partial — and its "passes" half is RED right now** | "Still discriminate" is DELIVERED: seven laws really execute against a fresh `Store.Memory` per law and every one was observed firing. "No database present" holds STRUCTURALLY (the three-token grep is 0, no socket, no branch). But `cabal test` does **not** currently pass, by this plan's own design, so the requirement as written is unmet until 23-03. |
| **BYTE-03** | **Partial** | `aeson_round_trip_mutations_are_re_measured` is GREEN with three re-measured vectors pinned as values. `aeson_is_absent_from_the_storage_path` exists, has a proven positive control and an observed scan branch — and is RED on its own subject. Green at 23-03. |
| **BYTE-05** | **NOT satisfied** | The requirement is a round-trip *through the database*. **23-02 provisioned, contacted and required no database at all.** What landed is a second precondition: the corpus SET is now locked by name and by behaviour class, and the blob round-trip is an executing law. Lands at 23-04. |
| **KEY-07** | **Partial** | The orphaning property is an EXECUTING law rather than a comment, and both KEY-07 laws were observed firing against a `(model, key)`-keyed store. The requirement's actual subject — `key_scheme` inside a Postgres UNIQUE constraint — is schema (23-03) and a live-catalogue assertion (23-04). |

`.planning/REQUIREMENTS.md`'s traceability rows carry these verdicts verbatim rather than a tick.

## Task Commits

1. **Task 1: `Store.Laws` — the store contract as seven executable properties** — `cdeb4e0` (feat)
2. **Task 2: run the laws against Memory; lock the law SET and the corpus SET** — `ea1be79` (test)
3. **Task 3: BYTE-03 — re-measure aeson's mutations, scan the storage path** — `18493b0` (test)

## Files Created/Modified

- `offchain/lib/Store/Laws.hs` — **created.** `store_laws`, `law_names`, seven laws, `require` /
  `describe` / `same_artifact` message plumbing. Zero partial functions, zero `error`/`fail`/`head`/
  `fromJust`/`(!!)`, zero database client, zero aeson.
- `offchain/test/Main.hs` — `expected_store_laws`, `expected_corpus_members`,
  `aeson_mutation_vectors`, `aeson_storage_path`, `aeson_pattern`, `aeson_scan`,
  `aeson_bait_source`, `aeson_positive_control`, and five `Check`s registered in `core_checks` after
  `every_advertised_override_is_honoured`.
- `offchain/lib/Store/Types.hs` — haddock reworded so the file can be SCANNED rather than exempted.
- `cfmm-replicationPlank-rpc-api.cabal` — `Store.Laws` in `exposed-modules`, in the commit that
  creates the file.
- `.planning/REQUIREMENTS.md` — four traceability rows rewritten with measured verdicts.

## Decisions Made

- **`aeson_storage_path` names SIX files, not the plan's four.** Every module under
  `offchain/lib/Store/` with no exemptions. The plan proposed excluding `Store/Types.hs`; measurement
  showed its haddock was the *only* thing under `offchain/lib/Store/` matching the pattern at all
  (two hits, both prose naming an import the file does not have). Rewording the prose and scanning
  the file is strictly stronger than exempting it, and "this file is fine, skip it" is how a guard's
  scope shrinks to the empty set.
- **`expected_corpus_members` added.** See guard #3 above: the prescribed instrument did not
  discriminate the prescribed input.
- **Both directions of a law-set mismatch are collected into ONE message.** A rename produces one
  violation of each kind, and `_ <- expect ...` short-circuits, so the operator would have been shown
  half the finding and asked to guess the rest.
- **A fresh `new_memory_store` per law**, so a passing set can never be an artifact of ordering.
- **The count assertion inside `store_laws_run_against_the_memory_store` is documented as
  SECONDARY**, with the SET as primary — the roadmap's count floor survives only in that reduced role,
  as the research specified.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] The corpus behaviour-tag SET does not discriminate its own named input**
- **Found during:** Task 2, guard #3
- **Issue:** The plan's guard is "delete `octal-escape` → the behaviour-tag SET reddens". It does not.
  `double-backslash` carries the same `SilentlyCorrupted` tag, so all three classes survive the
  deletion and the only surviving instrument was `length == 7` — a count, defeated by substitution.
- **Fix:** `expected_corpus_members`, the member-NAME set asserted in both directions and ordered
  ahead of the count.
- **Verification:** The deletion now reddens naming `octal-escape` specifically. Verbatim above.
- **Committed in:** `ea1be79`

**2. [Rule 2 - Missing critical] `Store/Types.hs` exempted from BYTE-03's scan on the strength of prose**
- **Found during:** Task 3
- **Issue:** The plan excludes `Store/Types.hs` from `aeson_storage_path`. Measured, the file is the
  only one under `offchain/lib/Store/` that matches the pattern at all — and it matches on two
  haddock lines that *say the import is absent*. Exempting a storage module because its comments trip
  the guard is the scope-shrinking defect wearing a new costume.
- **Fix:** Prose reworded; `Store/Types.hs` and `Store/Config.hs` both added, so the list is now every
  storage module with zero exemptions.
- **Verification:** `grep -cE 'Data\.Aeson|\btoJSON\b|\bencode\b|\bfromJSON\b|\beitherDecode\b'` is 0
  for all five existing files; the six-file scan runs and its branch was observed catching a seeded
  import (C1).
- **Committed in:** `18493b0`

**3. [Rule 1 - Self-contradicting criterion] `grep -c '^FAIL ' == 1` is unsatisfiable**
- **Found during:** Task 3
- **Issue:** The plan's gate is "the suite fails on exactly ONE named check". `sentinel_falsification_harness`
  contains an explicit `expect (null baseline)` assertion that refuses to certify against a failing
  suite, so any deliberate red costs TWO FAIL lines.
- **Fix:** Measured rather than worked around. The harness is NOT weakened, no baseline-exemption list
  was added, and the second failure is documented as the harness working. Predicted from the source
  before task 3 was written, then confirmed identically during task 2's two mutation runs.
- **Verification:** Verbatim above; anti-control C2 shows both go green together.
- **Committed in:** `18493b0`

**4. [Rule 2 - Missing critical] Prose inside the grep's blast radius, THREE more times**
- **Found during:** Tasks 1 and 3
- **Issue:** (a) `Store/Laws.hs`'s haddock said it imports nothing from `Data.Aeson` — spelling the
  module path that Task 3's own scan looks for, in a file that scan reads. (b) `Store/Types.hs`, as
  above. (c) Worst: `store_laws_run_against_the_memory_store`'s haddock spelled `Store.Postgres` and
  `CFMM_REQUIRE_DB` while explaining that they are absent, which is precisely the acceptance criterion
  `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' == 0`. The comment asserting absence
  was counted by the grep asserting absence.
- **Fix:** All three reworded to describe the tokens rather than quote them, each with an in-file note
  saying why. A first attempt at (c) reintroduced `CFMM_REQUIRE_DB` inside the very sentence warning
  about it — caught by re-running the grep, which is the point of re-running it.
- **Verification:** The three-token grep on `Main.hs` returns **0**; the aeson-pattern grep on
  `Store/Laws.hs` returns **0**.
- **Committed in:** `cdeb4e0`, `18493b0`

**5. [Rule 3 - Procedure fault, self-inflicted] `git checkout --` discarded uncommitted work**
- **Found during:** Task 3, restoring after mutation C3
- **Issue:** C3 mutated `aeson_pattern` in `offchain/test/Main.hs`, a file that also carried the
  entire uncommitted Task 3 implementation. `git checkout -- offchain/test/Main.hs` restored it to
  HEAD, i.e. to the Task 2 commit, deleting ~170 lines of unrelated new work. Detected immediately by
  the digest comparison, which did NOT match — the restore check caught its own restore.
- **Fix:** Task 3's edits re-applied from the plan text and re-verified by full build + full run. A
  `.bak` copy was taken before any subsequent mutation.
- **Standing lesson recorded:** restore a mutated file from a SAVED COPY, never from `git checkout --`,
  whenever that file also carries uncommitted work. Task 2's mutations were safe only because
  `Store/Laws.hs` and `Store/Types.hs` happened to be clean at that moment.
- **Committed in:** `18493b0`

**6. [Rule 1 - Inconsistent task attribute] Task 1's `tdd="true"` has no possible RED**
- **Found during:** Task 1
- **Issue:** The task is marked TDD, but its own acceptance criterion states "this task registers no
  check" and requires the suite count to stay UNCHANGED. There is no test to write red first; the
  tests for the laws land in Task 2.
- **Fix:** The acceptance criterion was followed, and the falsification obligation was discharged
  where it actually belongs — the seven-law × six-mutant table above, run BEFORE the commit, with the
  correct store as the control column. That is a stronger instrument than a RED-then-GREEN cycle over
  a check that does not exist yet.
- **Verification:** 91/91 unchanged after Task 1, as the criterion demands.
- **Committed in:** `cdeb4e0`

**7. [Rule 3 - Measurement tooling] `cabal test` does not reliably print the check count**
- **Found during:** Task 1
- **Issue:** `cabal test` buffers the runner's stdout and printed `91/91 checks passed` on one
  invocation and nothing on the next, so a plan step that reads `cabal test | tail -3` can silently
  record no count at all.
- **Fix:** Every recorded count in this summary comes from executing the built test binary directly,
  which also makes `grep -c '^PASS <name>$'` and `grep -c '^FAIL '` reliable.
- **Verification:** All counts above.

---

**Total deviations:** 7 auto-fixed (2 missing-critical strengthenings, 2 self-contradicting or
inconsistent criteria, 1 prose-in-blast-radius sweep, 1 self-inflicted procedure fault, 1 measurement
tooling correction)
**Impact on plan:** No scope creep. Two deviations make guards STRICTLY STRONGER than specified
(the corpus member set, the six-file scan). One records that a stated gate could not hold and measures
what actually happens instead of bending the harness to fit. The prose sweep is now a nine-times-over
pattern in this repo and should be treated as a standing pre-commit check rather than a discovery.

## Issues Encountered

Beyond the deviations: none. Every build after every task exited 0 with zero `offchain/` warnings on
the first attempt.

## Out of scope, logged not fixed

`deferred-items.md` in this directory is unchanged and still applies: `225a/` (GAMS scratch,
pre-dating this phase) and the untracked `CHANGELOG.md` / `Setup.hs` / `stack.yaml*`, the first of
which is named by the `.cabal`'s `extra-doc-files` so an `sdist` from a clean checkout would fail.
Neither is this workstream's territory.

## User Setup Required

None. No external service configuration. **No database was provisioned, contacted, or required by
this plan** — the three-tier decision still holds, now structurally rather than by convention.

## Next Phase Readiness

Ready for **23-03** (schema + migrations). Carry forward:

- **23-03 MUST create `offchain/lib/Store/Postgres.hs`,** and doing so closes BOTH current failures
  at once. Measured with a clean stub: 96/96. If 23-03 lands the module under a different name, the
  entry in `aeson_storage_path` must be renamed in the SAME commit.
- **`Store/Postgres.hs` must not import aeson, and the scan reads it from its first commit.** So must
  `Store/Config.hs`, `Store/Class.hs`, `Store/Laws.hs`, `Store/Memory.hs` and `Store/Types.hs` — six
  files, no exemptions. Watch the COMMENTS as well as the imports.
- **`Store.Schema` and `Store.Postgres` are still deliberately NOT in `exposed-modules`.** A module
  named there with no file on disk fails the build; each stanza ships with its file.
- **The first `.sql` under `offchain/` still costs three `sc3_literal_purge` edits.**
  `purge_known_extensions`, `purge_scanned_extensions` and `purge_file_floor` (still **36**, zero
  slack) move in the same commit. `find offchain -name '*.sql'` is still 0.
- **The law set is the capture's contract.** 23-04's `store-conformance.json` must key its verdicts on
  these seven names exactly; a missing verdict is a set mismatch, which is what makes skip-inflation
  unrepresentable rather than merely detectable.
- **Two laws carry KEY-07 and five do not** — re-measured here through the law set itself. Any future
  trimming of `store_laws` must keep `law_key_scheme_orphans_rather_than_matching` and
  `law_same_key_under_a_new_scheme_inserts`.
- **A red baseline empties the sentinel harness** (~75s → ~8s, reader set collapses to the failing
  check). Do not read a fast harness run as a fast suite.
- **Territory clean:** `git status --porcelain src test foundry-scripts Makefile foundry.toml .github`
  is EMPTY.

---
*Phase: 23-postgres-foundation-byte-exact-schema*
*Completed: 2026-08-16*

## Self-Check: PASSED

Every claim above re-verified against disk and git rather than asserted:

- `offchain/lib/Store/Laws.hs` exists AND is tracked (`git ls-files`), digest
  `31ff0584078c0aab7538014413688282815587ccb6eef2a67bbfbcf30ffa68db` matches the value quoted in the
  restoration block.
- All three task commits resolve: `cdeb4e0`, `ea1be79`, `18493b0`.
- `grep -cE '\berror\b|\bfail\b|fromJust|\bhead\b|!!' offchain/lib/Store/Laws.hs` = **0**.
- The aeson pattern over the five storage-path files that EXIST = **0** each.
  `offchain/lib/Store/Postgres.hs` is confirmed ABSENT — the transient red's subject really is
  missing, which is the claim the red is making.
- `grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs` = **0**.
- `Store.Laws` appears exactly once in the `.cabal`; `find offchain -name '*.sql'` = **0**;
  `purge_file_floor` still **36**.
- `git status --porcelain offchain/` is EMPTY — every stub and mutant from the observation runs was
  removed.
- `git status --porcelain src test foundry-scripts Makefile foundry.toml .github` is EMPTY.
