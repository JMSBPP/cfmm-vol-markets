---
phase: 25-content-key-keyed-store
plan: 03
kind: phase-summary
subsystem: database
tags: [content-key, sha256, netstring-framing, cache-elision, postgres, haskell, store]

requires:
  - phase: 23-postgres-foundation
    provides: "Store.Class / Store.Memory / Store.Postgres / Store.Laws — the store seam, the reference implementation, the server-backed one, and the eight laws that run against both"
  - phase: 24-gams-invocation-and-versions
    provides: "Gams.Run.run_prover and its ProverOutcome, render_argv / parse_shock_field, the parsed GAMS and CONOPT version types, ToolchainIdentity"
provides:
  - "Store.Key — the netstring framer, the tagged preimage, the refusing identity (KEY-01..06, six checks)"
  - "Store.Solver — the solver seam, so elision is observable without spawning GAMS"
  - "Store.Cache.decide — lookup first, elide on a hit, persist only a completed run (STORE-01, STORE-08)"
  - "Store.Types.ResetScope + Store.Class.store_reset — emptying as its own scoped operation (STORE-06)"
  - "eleven registered checks, suite 151/151 -> 162/162"
affects: [26, 27, 28, store-cache, content-key, volume-path-bridge]

tech-stack:
  added: []
  patterns:
    - "absence asserted on the FRAMED form of a token, so a numeric claim is about a component rather than about digits inside a digest"
    - "a solver seam that COUNTS its own invocations, so \"the solve was skipped\" is a measurement rather than a reading of the code"
    - "a scope argument as the guard against accidental invocation: a destructive operation whose first parameter is a sum type cannot be written down unscoped"
    - "an absence scan implemented by READING the file rather than by shelling grep -c, which prints 0 on a file that does not exist"

key-files:
  created:
    - offchain/lib/Store/Key.hs
    - offchain/lib/Store/Solver.hs
    - offchain/lib/Store/Cache.hs
  modified:
    - offchain/lib/Store/Types.hs
    - offchain/lib/Store/Class.hs
    - offchain/lib/Store/Memory.hs
    - offchain/lib/Store/Postgres.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "The phase was SCOPE CUT mid-flight from 9 plans / 28 tasks to 3 plans / 8 tasks (commit 1d30bef). Five of the eight STORE requirements were deferred rather than dropped, and they are named individually in this summary and in REQUIREMENTS.md."
  - "STORE-06's guard is a TYPE plus a SOURCE SCAN, in that order: ResetScope makes the unscoped call unwritable, and a scan over Store.Cache is what says the solve path does not make the scoped one. The record-of-functions seam leaves the field in scope wherever Store (..) is imported, and no arrangement of it would not."
  - "The plan's check name reset_is_unreachable_from_a_solve_or_a_publish was rejected on measurement — there is no publish path in this tree and the field IS reachable. Renamed no_solve_path_names_the_reset_entry_point, after 25-01's precedent."
  - "Store.Postgres.store_reset is a bare `delete from model_run` with NO where clause, because STORE-05 (pinning) is deferred and a predicate that never excludes anything reads like a retention policy."

patterns-established:
  - "A new ResetScope constructor is a -Wall failure in both store implementations, because ModelRunOnly is matched explicitly rather than by wildcard."
  - "Both file floors (purge_file_floor, credential_scan_floor) are re-measured by RUNNING the two find commands in the same sitting and recording what they print — never by arithmetic, and never derived one from the other."

requirements-completed: [KEY-01, KEY-02, KEY-03, KEY-04, KEY-05, KEY-06, STORE-01, STORE-06, STORE-08]

duration: 3h 18m (25-01 start to 25-03 close)
completed: 2026-08-17
---

# Phase 25: The Content Key & Keyed Store — Phase Summary

**The shock is now the key: `Store.Key` frames its preimage so no two distinct inputs collide and no
per-run path can reach it, `Store.Cache.decide` looks that key up BEFORE the solver is reachable and
elides on a hit, an aborted run leaves nothing behind, and emptying the store is a scoped operation
the solve path does not name.**

## What shipped, requirement by requirement

| Requirement | Plan | Evidence |
| --- | --- | --- |
| **KEY-01** no machine-specific path in a key | 25-01 | `no_key_identity_carries_an_absolute_model_source_path` — the absolute path is relativised to its file name AND the directory string is absent from the preimage bytes; the unrelativisable path is `Left (AbsoluteModelSourcePath <original>)` |
| **KEY-02** one renderer, no per-run tokens | 25-01 | `the_preimage_excludes_every_per_run_token` — all 7 shock tokens and both fixed options present (framed), the `-k` flag, kill delay, budget, timeout binary, absolute solver path and `curdir=` absent |
| **KEY-03** the framer separates | 25-01 | `framing_separates_what_concatenation_conflates` — the bare collision is EXHIBITED first, then the framed difference, then the difference in `key_preimage` itself |
| **KEY-04** normalization is single-pass | 25-01 | `edge_normalization_is_single_pass` — `28e18` and `28000000000000000000` give one key; a different value gives a different one |
| **KEY-05** the pips denominator is in the preimage | 25-01 | `the_pips_denominator_is_in_the_preimage` — the library's constant is carried, and `pips_denominator + 1` moves the preimage |
| **KEY-06** a missing input is an error, never a default | 25-01 | `key_identity_refuses_an_absent_conopt_version` — `Nothing` is `Left ConoptVersionAbsent`, never `""` and never a placeholder |
| **STORE-01** an identical shock skips the solve | 25-02 | `an_identical_shock_elides_the_solve` (stored bytes returned AND invocation counter 0, with B ≠ B′ asserted first) and `a_miss_invokes_the_solver_exactly_once` (counter 1, the stored bytes are the solver's, the second call elides, the counter is still 1, the store holds ONE entry) |
| **STORE-06** reset is separate and explicit | 25-03 | `reset_empties_the_store_and_is_scoped` and `no_solve_path_names_the_reset_entry_point` |
| **STORE-08** a failed run never becomes a cache entry | 25-02 | `an_aborted_run_produces_no_cache_entry` — three abort shapes against a fresh store, with a `Produced` POSITIVE CONTROL ordered first |

Nine requirements, eleven checks, three new library modules (`Store.Key`, `Store.Solver`,
`Store.Cache`) and four modified ones.

## DEFERRED — five requirements, named

**These are deferred, not dropped, and they are named here because a requirement that vanishes
without a record is indistinguishable from one that was forgotten.** Each has a written reason in
`.planning/REQUIREMENTS.md` under the `### Store (STORE)` heading — the block titled
**"DEFERRED — revisit after the loop runs end to end"** (`REQUIREMENTS.md:70-88`), with the
traceability rows at `REQUIREMENTS.md:208-214` marking each **Deferred to a later milestone (scope
cut 2026-08-17)**.

| Requirement | What it asks for | Why it is deferred |
| --- | --- | --- |
| **STORE-02** | Re-solving an existing key and getting different bytes is a determinism failure with a non-zero exit | Turns `VOLUME_PATH.md` §3's determinism guarantee into a standing falsifiable check — valuable research, not needed to produce a fixture. It also generates the re-solve driver, the quarantine path and STORE-04. |
| **STORE-03** | On a determinism failure the original is kept and the divergent bytes are quarantined | Serves STORE-02 only; nothing in the bridge consumes a quarantine row. |
| **STORE-04** | Verification on demand rather than on every cache hit | Serves STORE-02 only. The underlying hazard stays recorded: always-verify defeats the elision the store exists for. |
| **STORE-05** | A run can be pinned so retention never removes it | There is no retention sweep in the bridge, so pinning has nothing to survive. **This is why `store_reset` has no `pinned` predicate and no `where not pinned` clause** — see the decision of record below. |
| **STORE-07** | An append-only run log records `(timestamp, key, event tx, block)` | Two of its four fields (`event tx`, `block`) are blocked upstream on Phase 27 regardless, so it could only ever have closed PARTIAL in v6.0. The append-only enforcement it implies is the trigger-hardening work the scope cut removed. |

The scope cut itself is recorded at commit `1d30bef` and in `REQUIREMENTS.md:50-59`. Its rationale
of record: the verification apparatus had grown larger than the code it verified (11,206 test lines
against 9,844 library lines), and the trigger-hardening the phase-25 database review called for
amounts to defending an append-only log against a superuser on a local development Postgres, which
is not this milestone's threat model.

## Reviewer findings — which are moot and which still bind

`25-REVIEW-FINDINGS.md` carries a Database Optimizer review written against the PRE-CUT plan set.
Sorting it against what actually shipped:

### Moot — they attach to deferred requirements only

- **DB-B1** (`text not null` re-opened in `run_log` and `quarantine`) — both tables belong to
  STORE-07 and STORE-03. Neither table exists.
- **DB-M1** (`session_replication_role = replica` walks through both triggers; the catalogue check
  cannot see a DISABLED trigger) — trigger hardening for the append-only run log. STORE-07.
- **DB-M2** ("REVOKE is a no-op" is true, but the conclusion skips the remedy) — same append-only
  enforcement. STORE-07.

These are **not resolved**. They are unreached, and whoever resumes STORE-03 or STORE-07 must read
them before writing the DDL.

### STILL BINDING on any future store write — carry these forward

**DB-B2 — a bare `ByteString` on a `bytea` parameter type-checks, runs, and corrupts silently.**
`ToField ByteString` is `Escape` (a quoted TEXT literal); `ToField (Binary ByteString)` is
`EscapeByteA`. Measured on PG 18.4: `a\101b` = `61 5c 31 30 31 62` (6 bytes) goes in and
`61 41 62` (3 bytes) comes back, no error and no warning, because `byteain` still accepts the legacy
escape format and re-reads `\101` as one octal byte. **The `Binary` newtype is mandatory on every
`bytea` write parameter and NOTHING STRUCTURALLY ENFORCES IT** — no compile error, no helper, no
source scan. `Store.Postgres`'s existing writes are all wrapped; a new one that is not would pass
every assertion in this repository while corrupting the column. The reviewer's fix stands for future
work: a server-computed readback digest (`encode(sha256(<col>),'hex')`) gated against the
Haskell-side one, plus the schema backstop (`sha256()` is IMMUTABLE, `provolatile = 'i'`, verified,
so a `check` constraint on it is legal).

*(Note the direction: the wart is WRITE-ONLY. `FromField ByteString` special-cases the `bytea` OID
and hands off to the `Binary` reader, so reading into a bare `ByteString` is lossless — which is why
`lookup_run` deliberately does exactly that, and why a negative control that swapped the newtype on
the READ side would pass and prove nothing.)*

**DB-M4 — the derived `doc` column's placeholders are all the same type, so transposing two
compiles and silently derives `doc` from the KEY.** `insert_sql` binds positions 3, 4 and 5 as
`Binary ByteString` — key, raw, raw-again-for-the-projection. Transposing 3 and 4 compiles, runs,
and gives a store whose derived projection describes the key rather than the artifact. There is no
type help and no check. A generated column would close it and is unavailable: `convert_from` is
STABLE (`provolatile = 's'`, verified) and `generated always as (…) stored` fails *"generation
expression is not immutable"*. Two placeholders are therefore forced — but naming `raw` **once** is
not, and the reviewer's `from (values (?,?,?,?)) as v(...)` form does that while preserving both the
arbiter and the `xmax` discriminator. **Keep `on conflict ON CONSTRAINT model_run_identity`**: the
threading through `Store.Schema.identity_constraint_name` is deliberate and a bare column list
discards it.

**DB-M5 — `jsonb` refuses the JSON escape for the NUL code point, so a legal artifact containing
it cannot be stored at all while `doc` is `not null`.** That escape is six characters -- a
backslash, a `u`, and four zeros -- and it is DESCRIBED here rather than pasted, because pasting
the decoded byte is what makes `file(1)` report a document as `data`: `25-REVIEW-FINDINGS.md` is
in exactly that state, and the first draft of this paragraph put three NUL bytes into this file.
A document binding a key to a one-character string holding that escape is RFC-8259-valid, aeson
accepts it, `::json` accepts it, and `::jsonb` **refuses** it -- *"unsupported Unicode escape
sequence ... cannot be converted to text."* Because `doc` is `not null` and derived in the same statement, **the derived projection
vetoes the authoritative bytes** — the exact inversion the schema comment is written against. Same
class: a JSON number overflowing `numeric`. This phase does **not** decide it. The honest options
remain (a) accept and document the restriction on admissible artifacts, (b) make `doc` nullable with
a fallback to NULL on conversion failure, (c) use `json` not `jsonb`, costing the `jsonb_path_ops`
GIN index. **Whichever is picked, `Store.Memory`'s json gate must predict it, or Tier B stops
predicting Tier C** — which is the only reason `cabal test` is allowed to run without a server at
all.

The volume_path artifact this bridge actually carries is integer arrays and does not contain the
escape, so the veto is latent rather than live. That is a fact about today's fixture, not a
guarantee about the prover.

## Measured totals

Everything below was run at phase close, each command's own exit code captured.

| Measurement | Value |
| --- | --- |
| `cabal build --enable-tests -j all` | exit **0**, **0** warning/error lines |
| `cabal test` | exit **0**, **162/162**, **0** `FAIL` lines |
| Suite wall clock | **270 s** at the closing gate, **load average 12.0**; the two runs before it were 220 s (load 8.0) and 245 s |
| `purge_file_floor` | **62**, against `find` printing exactly **62** — zero slack |
| `credential_scan_floor` | **71**, against `find` printing exactly **71** — zero slack |
| Extension census under `offchain/` | `hs 50, sh 9, json 9, md 3, txt 2, sql 3` |
| DB-free grep (`Store\.Postgres\|connectPostgreSQL\|CFMM_REQUIRE_DB` over `Main.hs`) | **0** (grep exit 1, captured as its own status) |
| GAMS-free grep (`Gams\.Invoke\|CFMM_REQUIRE_GAMS\|/usr/gams` over `Main.hs`) | **0** (grep exit 1, captured as its own status) |
| Territory (`src test foundry-scripts Makefile foundry.toml .github`) | `git status --porcelain` **empty** |

Suite trajectory across the phase: **151/151 → 157/157** (25-01) **→ 160/160** (25-02) **→ 162/162**
(25-03).

**Both floors did NOT move at 25-03, and that is the expected reading** — this plan adds no file
under `offchain/`. They were re-measured cold anyway, by running the two `find` commands in the same
sitting, because the rule is that a floor is re-measured whenever a plan is already touching the
tree, and 24-02 is why.

**The wall clock deserves its caveat, and it is NOT attributed to the two new checks.** The
pre-25-03 baseline of record is 168 s. Three runs were taken at close: 245 s, 220 s at load average
8.0, and 270 s at load average 12.0. The number tracks the LOAD, not the check count — 220 s at
load 8 and 270 s at load 12 with an identical binary is the host, and this machine carries six other
worktrees.

The structural reason the marginal cost is near zero: both new checks are excluded from the sentinel
sweep by `sweep_one`'s `readable` filter. Neither objects when an artifact's every leaf is replaced
with a marker, so neither appears in a derived reader set, so both run once per full `core_checks`
pass rather than once per sentinel pair. Their bodies are a handful of `IORef` operations and one
5 KB file read.

**This is stated as a reading, not as a measurement.** Nobody re-ran the 160-check baseline under
load 12 to subtract it, so the +100 s is explained rather than accounted for. If the suite is still
near 270 s the next time this host is idle, that reading is wrong and the cost is somewhere in these
two checks.

## Task commits

**25-01 — Cover `Store.Key`** (summary: `25-01-SUMMARY.md`)

1. `c0e2e9c` — `test(25-01)`: frame, normalize once, key the pip denominator
2. `26378ad` — `test(25-01)`: the refusing identity and the preimage's scope
3. `d79fa1f` — `docs(25-01)`: complete Cover Store.Key plan

**25-02 — Cache elision and abort safety** (see the finding below: no plan summary was written)

4. `1b733c4` — `feat(25-02)`: the solver seam, so elision can be observed without a solver
5. `6eba818` — `feat(25-02)`: decide — lookup first, elide on a hit, and the two checks that prove it
6. `1164b4d` — `test(25-02)`: an aborted run leaves no cache entry, proven against a control

**25-03 — Explicit reset, and close the phase**

7. `2f6235d` — `feat(25-03)`: reset as its own operation, scoped, and unnamed by the solve path

Phase metadata commit: see `git log` for the `docs(25-03)` commit carrying this file.

Earlier in the phase, before any plan executed: `f00b40b` created `Store.Key` with no check on it,
and `1d30bef` is the scope cut.

## Decisions of record

**1. STORE-06's guard is a type FIRST and a source scan SECOND.**
`store_reset :: ResetScope -> IO ()` means there is no `store_reset store` that type-checks — a
caller has to name, at the call site and in the source, which part of the store it means to empty.
That is what the type can do. What it cannot do is stop a module from calling the scoped form, since
the field is in scope wherever `Store (..)` is imported; a typeclass would have the identical
property, because the method would be in scope wherever the constraint was. So the second half is a
scan over `offchain/lib/Store/Cache.hs`, asserting the module that decides whether to solve does not
MENTION the reset entry point. It cannot invoke what it does not name.

**2. `ModelRunOnly` names the keyed table and stops there, and the blob surface proves it.**
The byte-fidelity table holds the adversarial corpus — measurements, not cache entries — and BYTE-05
rests on it. A sweep that took it too would destroy evidence while doing exactly what it was told.
`reset_empties_the_store_and_is_scoped` seeds a blob and asserts it survives, which is what stops
`ResetScope` from being a parameter nobody reads.

**3. No `pinned` predicate and no `where not pinned` clause, in either implementation.**
STORE-05 is deferred; there is no `pinned` column. A `where` clause that never excludes anything
reads, to anyone auditing the file later, exactly like a retention policy that is being honoured.
Both implementations say so in their haddock.

**4. `ModelRunOnly` is matched explicitly rather than by wildcard, in both stores.**
A wildcard would make both implementations do the same thing for every scope anyone adds later,
silently. With the constructor named, a second scope is a non-exhaustive-patterns warning — and
`-Wall` is a failure in this tree.

**5. The absence scan reads the file rather than shelling `grep -c`.**
`grep -c` prints `0` for a file that does not exist and exits 2, so an absence claim built on it
passes for the one reason that should fail it loudest — a renamed or deleted subject. The check
reads `Store/Cache.hs`, asserts it EXISTS, asserts it names `decide`, `store_put` and `store_lookup`
(fields of the same record, reached through the same import, so the scan is demonstrably able to see
a record field), and only then asserts the reset token is absent. The needle is case-folded and
bare, so it catches the field, the scope type, and prose — deliberately. A haddock in `Store.Cache`
explaining that it does not empty anything would fail this check, and that is the right outcome.

## Deviations from plan

### 1. [Rule 1 — Plan step contradicted by the tree] The plan's check name asserts two things that are false

- **Found during:** 25-03 Task 1
- **Plan said:** register `reset_is_unreachable_from_a_solve_or_a_publish`.
- **Measured:** `grep -rn "publish\|Publish" offchain/lib offchain/app --include=*.hs` returns
  **nothing**. There is no publish path in this tree — no module, no function. And "unreachable" is
  false of the thing the check actually guards: `Store.Cache` imports `Store.Class (Store (..))`, so
  the reset field is in scope there; what is true is that the file does not name it.
- **Fix:** renamed `no_solve_path_names_the_reset_entry_point`, and the haddock states both
  corrections so the name is not re-proposed. This follows 25-01's precedent exactly — a check named
  "refuses" while the behaviour is "relativises" was the misleading artifact that phase corrected.
- **The requirement is still discharged:** STORE-06 asks that reset cannot run as a side effect of a
  solve. The type refuses the unscoped call; the scan says the solve path makes no call at all.
- **Commit:** `2f6235d`

### 2. [Rule 3 — Plan context self-contradictory] `files_modified` lists a file the plan's own check forbids touching

- **Found during:** 25-03 Task 1
- **Issue:** `25-03-PLAN.md`'s frontmatter lists `offchain/lib/Store/Cache.hs` under
  `files_modified`, while its own Task 1 check 11 requires that file to contain **zero** occurrences
  of the reset symbol. The only edit that plan could have wanted is a comment about reset — which is
  precisely what the check exists to fail.
- **Fix:** `Store/Cache.hs` is **untouched** by this plan. This is the twentieth recorded instance
  of prose landing inside a grep's blast radius on this branch, anticipated rather than discovered,
  and the explanatory note lives in `Store.Class` and in the check's own haddock instead.
- **Commit:** `2f6235d`

### 3. [Rule 2 — Missing critical, added] Two arms the plan did not ask for, both of which stop a vacuous pass

- **Found during:** 25-03 Task 1
- **Issue:** as written, check 10 ("seed two entries, reset, assert empty") passes for a store whose
  two seeds are the SAME triple (first-writer-wins makes that one entry) and for a store whose seeds
  never landed at all (the keyed put RAISES on a non-json artifact). Check 11 as written
  (`grep -c` is 0) passes when the file has been renamed or deleted.
- **Fix:** check 10 asserts the two keys DIFFER and both rows are PRESENT before the reset; check 11
  asserts the file exists and names three identifiers it must name. This is not the per-claim
  positive-control discipline the scope cut removed — it is the minimum that makes an absence claim
  an absence.
- **Commit:** `2f6235d`

### 4. [Recorded, not fixed] `25-02` has no plan summary

- **Found during:** 25-03 Task 2
- **Issue:** `.planning/phases/25-content-key-keyed-store/` contains `25-01-SUMMARY.md` and no
  `25-02-SUMMARY.md`. 25-02's three task commits landed (`1b733c4`, `6eba818`, `1164b4d`) and no
  closeout followed; `STATE.md`'s Current Position still reads "25-01 COMPLETE" and its progress
  counters were never advanced for 25-02. There is precedent — 24-05's summary was written and left
  untracked, and 24-06 carried it.
- **Action:** **not** back-filled as a separate document. 25-02's content is recorded in this phase
  summary (the requirement table, the commit list, and the two throwaway reddening observations
  quoted from its commit messages) and in the commit messages themselves, which are unusually full.
  A summary reconstructed after the fact from commit messages is a weaker artifact than the commit
  messages, and pretending otherwise is the kind of record this repository already distrusts.
- **Carried forward:** the executor of the next phase should not read the absence of
  `25-02-SUMMARY.md` as 25-02 being incomplete. It is complete; its requirements are ticked.

**Total deviations:** 3 auto-fixed (1 plan-step correction, 1 plan-context contradiction, 1 missing
critical), 1 recorded and deliberately not fixed.
**Impact on plan:** no scope creep. Nothing was added beyond the two checks the plan named and the
minimum arms that make them non-vacuous; the plan was not re-inflated.

## Known gaps, stated rather than left to be found

1. **`Store.Postgres.store_reset` is not exercised by anything.** `cabal test` is server-free by
   construction (DB-03) and no capture script drives a reset. Its statement takes no parameters, so
   it carries neither the DB-B2 `Binary` hazard nor a DB-M4 placeholder to transpose — but "it
   compiles" is the whole of the evidence for it, and the module haddock says so at the point of
   definition.
2. **Guard #21 remains open.** Phase 24's phase-level finding named the echoed-field cross-check as
   the mutation Phase 25 owed. `the_preimage_excludes_every_per_run_token` discharges KEY-02's scope
   half; the artifact-side echoed-field mutation was in the cut scope and is still owed.
3. **No end-to-end STORE-01.** Nothing in this repository builds a production `Solver` from
   `Gams.Run.run_prover`; elision is proven at the seam with a counting test solver. That was
   reviewer finding M3, and the bridge phase is where it closes.
4. **DB-M5 is undecided.** See the carry-forward above. Today's artifact does not contain the
   escape, so the veto is latent.

## Next phase readiness

The store is a working cache: a shock keys deterministically, a repeat shock costs no solve, an
aborted run costs no poison, and an operator can empty it without the solve path being able to. That
is the whole of what the `volume_path` bridge needs from phase 25.

The one thing phase 26 must supply that this phase deliberately did not is the production `Solver` —
the adapter from `Gams.Run.run_prover` into the `Store.Solver` seam. Until it exists, STORE-01 is
proven of the seam and not of the loop.

## Self-Check

Every claim above that names a file or a commit was re-verified on disk, not asserted.

| Claim | Result |
| --- | --- |
| `.planning/phases/25-content-key-keyed-store/25-SUMMARY.md` | FOUND |
| `offchain/lib/Store/Types.hs`, `Class.hs`, `Memory.hs`, `Postgres.hs`, `offchain/test/Main.hs` | FOUND (all five) |
| commits `c0e2e9c`, `26378ad`, `d79fa1f` (25-01) | FOUND (`git cat-file -e`) |
| commits `1b733c4`, `6eba818`, `1164b4d` (25-02) | FOUND |
| commit `2f6235d` (25-03 task 1) | FOUND |
| commits `f00b40b` (Store.Key), `1d30bef` (scope cut) | FOUND |
| both new check names in the `cabal test` PASS lines | FOUND (log lines 138, 139) |
| `grep -ci reset offchain/lib/Store/Cache.hs` | **0**, grep exit 1 — captured as its own status |
| NUL bytes in this file, `STATE.md`, `REQUIREMENTS.md`, `ROADMAP.md` | **0** in each. The first draft of the DB-M5 paragraph put THREE into this file by pasting the decoded byte; that is instance twenty of prose landing inside a grep's blast radius on this branch, and it is why the escape is now described rather than written. |
| `.planning/STATE.md` frontmatter | reads `milestone: v6.0` / `milestone_name: Model Output Store + VolumePath Bridge (rpc_api workstream)`, verified BY HAND after editing. Neither `state update-progress` nor `phase complete` was run — the file's own binding warning records that they have rewritten it to `v2.0` five consecutive times, and this executor did not make it six. |

## Self-Check: PASSED

---
*Phase: 25-content-key-keyed-store*
*Completed: 2026-08-17*
