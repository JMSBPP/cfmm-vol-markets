---
phase: 28-resident-loop-fixture-publication
plan: 02
subsystem: offchain-loop
tags: [haskell, loop, watermark, restart, gams, detect, exit-codes, census, cabal]

requires:
  - phase: 24-toolchain-identity
    provides: "`Gams.Version`'s two parsers and the committed `gams-conformance.json`, whose REAL wrong-subject banner lines are this plan's negative controls"
  - phase: 25-content-key-keyed-store
    provides: "`Store.Cache.decide`, `Store.Key.key_identity`, `Store.Memory` and the counting-stub `Solver` every LOOP-01 check reuses verbatim"
  - phase: 26-shock-assembly
    provides: "`Chain.Shock.decode_shock`, `Fee.Split.split_for` and the synthetic `Shock` log corpus the mined logs are built from"
  - phase: 27-anvil-read-layer
    provides: "`Chain.Read`'s `BlockRef`-required reads, `Chain.Endpoint`'s site census in both directions, and the `setEnv k \"\"` -> `unsetEnv` measurement"
  - plan: 28-01
    provides: "`Loop.Solve`'s seam plus its toolchain stash, `Loop.Ledger`'s one-call block commit, and migration 004"
provides:
  - "`Gams.Detect` — S1 closed in the library: an identity before the first solve, with no production model and no production solve"
  - "`Loop.Config` — `LOOP_POLL_MS`, `loop_first_block`, and the COMPLETE exit-code table with its two decoders"
  - "`Loop.Poll` — the pure chain edge: `next_range`, `event_identity`, `log_block`, `shock_filter_fields`, and `ChainSource` as a record of five actions"
  - "`Loop.Chain` — the ONLY module in the loop layer that names the transport, listed as an endpoint site"
  - "`Loop.Run` — ONE iteration function; the mode decides only re-entry"
  - "`offchain/app/LoopMain.hs` and the `executable loop` stanza"
  - "eight checks: S1's two, and LOOP-01's six"
  - "`value_overrides` — a THIRD override shape, for a variable whose value is not a path"
affects: [28-03, 28-04, 28-05, LOOP-01, LOOP-03, LOOP-04]

tech-stack:
  added: []
  patterns:
    - "The transport is a RECORD OF ACTIONS, so what the chain did while the loop was DOWN is something a check decides rather than something it arranges"
    - "A restart is a FRESH `Env` over the same store and ledger — nothing in-process carries over, because the watermark is read back out of the ledger"
    - "The exit table is complete on day one; a table that grows one code per plan is a table nothing can assert is total"
    - "The closedness of `[b, b]` is asserted on the CALLS the iteration made, not on the function that computes them"
    - "An override whose value is not a path gets a third probe shape rather than a pardon in the gap list"

key-files:
  created:
    - offchain/lib/Gams/Detect.hs
    - offchain/lib/Loop/Config.hs
    - offchain/lib/Loop/Poll.hs
    - offchain/lib/Loop/Chain.hs
    - offchain/lib/Loop/Run.hs
    - offchain/app/LoopMain.hs
  modified:
    - offchain/lib/Chain/Endpoint.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "\"Version-only\" means no production model and no production SOLVE, not no process: the version flag is parsed as a FILENAME and CONOPT states its version only in a run that reaches the solver, both MEASURED and both committed in `gams-conformance.json`"
  - "`ti_model_sources` carries the PRODUCTION model's digest and never the probe's — a probe that leaked into the identity would key every row to a throwaway file"
  - "Loop.Config states NONE of the colliding numerals; the disjointness is asserted against `Gams.Exit.gams_code_domain` rather than against a transcription of it"
  - "`Loop.Chain` gained `resolved_chain_source` because the endpoint census requires a Haskell consumer to name the resolver on a CODE line, and it returns the endpoint ALONGSIDE the source so nothing resolves twice"
  - "`LOOP_POLL_MS` needed a THIRD override shape: `probe_override` asserts a bogus PATH comes back verbatim, which is meaningless for a resolver that returns a number, and `unprobed_overrides` is the gap list for a variable whose consumer is unreachable — which this one's is not"

patterns-established:
  - "A firing input that is caught by a SECOND independent guard is recorded as such: two of the five were"
  - "An acceptance criterion that the plan's own prescribed prose makes unsatisfiable is measured, recorded, and replaced by the stronger statement"

requirements-completed: [LOOP-01]

duration: 80min
completed: 2026-08-23
---

# Phase 28 Plan 02: Startup Identity, the Poll, and the Persisted Watermark Summary

**LOOP-01 is proven the only way it can be — two events were injected at blocks 6 and 7 while no
loop was running, a fresh `Env` was built over the same store and ledger, and the restart picked
them up — with the restart-from-`latest` mutation OBSERVED reddening at *"Row counts [0,0] for the
events at blocks [6,7]"*; and S1 is closed in the library by a version-only probe whose two negative
controls are the toolchain's own committed wrong-subject banners.**

## Performance

- **Duration:** 80 min
- **Started:** 2026-08-22T23:52:00Z
- **Completed:** 2026-08-23T01:12:39Z
- **Tasks:** 3/3
- **Files modified:** 9 (6 created, 3 modified)

## Commits

| Task | Commit    | Subject                                                                    |
| ---- | --------- | -------------------------------------------------------------------------- |
| 1    | `153460d` | an identity before the first solve, and the probe that pays for it          |
| 2    | `631cf31` | one iteration function, closed ranges, and an exit table complete on day one |
| 3    | `3ab9d7e` | LOOP-01, proven with events that occurred while the loop was down            |

## The numbers, as measured

| Quantity                                    | Before  | After   | How                                            |
| ------------------------------------------- | ------- | ------- | ---------------------------------------------- |
| `cabal test` total (`BASE_2` -> `BASE_2 + 8`) | **211** | **219** | run COLD before the first edit, and at the end |
| `cabal build --enable-tests -j all` warnings | 0       | **0**   | `grep -cE '[Ww]arning'` over the build log     |
| `^Downloading` lines                        | 0       | **0**   | `grep -c '^Downloading'` over the same log     |
| `purge_file_floor`                          | 75      | **81**  | `find` RUN at both ends, zero slack            |
| `credential_scan_floor`                     | 86      | **92**  | `find` RUN at both ends, zero slack            |
| `endpoint_sites` entries                    | 18      | **19**  | counted in the source, not from the haddock    |

Extension census under `offchain/` at the final measurement: **hs 65, sh 12, json 11, sql 4**.
Both floors moved by the SAME six, all of them `.hs`, because this plan commits no artifact and no
script — so neither the `.json` nor the `.sh` census moved. Both `find` commands were RUN at both
ends; neither number was derived from the other.

The six files: `Gams/Detect.hs`, `Loop/Config.hs`, `Loop/Poll.hs`, `Loop/Chain.hs`, `Loop/Run.hs`,
`app/LoopMain.hs`.

## What was built

### Task 1 — `Gams.Detect`, S1 closed in the library (`153460d`)

`detect_toolchain` writes `probe_model_source` — the five-line hermetic NLP, verbatim from
`offchain/rig/capture-gams-conformance.sh:157-163` — into a FRESH exclusive directory, runs the
binary on it at `lo=3`, and hands the captured output to the pure `toolchain_from_probe`. The
directory is removed on every exit path (`bracket`), `grep -c "createDirectoryIfMissing"` prints 0,
and no GAMS action token appears anywhere in the module.

**"Version-only" means no production model and no production SOLVE, not no process, and both halves
of that are MEASURED and committed rather than argued.** `gams --version` is parsed as an input
FILENAME; the process exits 6 and its banner is refused `Left (WrongJob "--version")` by the very
parser this module reuses — `gams-conformance.json` records both the line and the verdict. CONOPT
states its own version only in the output of a run that reaches the solver; the same artifact's
`conopt_method` says how. Both sentences are in the haddock.

**`ti_model_sources` is the PRODUCTION model's digest and never the probe's.** The key is over the
model that will be solved. A probe that leaked into the identity would key every stored row to a
throwaway file, so every row would agree with every other row about a model none of them ran. The
driven check asserts the source list names the temp model and that `probe_model_name` is not an
infix of any recorded name.

Two checks. `detect_toolchain_refuses_every_wrong_subject_banner` is pure and reads BOTH negative
controls out of the committed capture, compares this module's refusal against the capture's own
recorded `parser_verdict` strings, and asserts FIRST that the positive control differs from the two
real banners **in the job field alone** — index 2 of the whitespace-delimited tail, and no other.
`detect_toolchain_is_driven_end_to_end_against_a_stub` writes a `/bin/sh` script, runs it, and
checks the four facts that make the identity USABLE, ending at `Store.Key.key_identity` accepting
it. `git diff offchain/test/Main.hs | grep -cE "54\.1\.0|4\.39\.0|37378ce0"` prints **0**: every
expected value comes out of the artifact.

### Task 2 — `Loop.Config`, `Loop.Poll`, `Loop.Chain`, `Loop.Run` (`631cf31`)

`process_block` is the whole pipeline for one block and ends in ONE `ledger_commit_block`. A
`cl_halts` outcome returns BEFORE the commit, so the watermark is not advanced past that block. A
block with no logs commits an empty row list and advances anyway. The logs are ordered by
`(blockNumber, logIndex)` before anything is decided, because the ledger's chronology is the
chain's and not the transport's.

`run_loop` re-reads the watermark from the LEDGER on every pass rather than carrying it in a local.
That is the difference LOOP-01 is about: a loop that trusted its own memory of the watermark would
report a restart-safe watermark while holding an in-process one.

`adopt_identity` is 28-CONTEXT's user ruling as a pure function. Two returns are the same value
with different reasons and they are kept apart in the NOTE: a reported identity that cannot become
a `KeyIdentity` is not adopted, and saying so out loud is what stops an unusable toolchain from
looking like an unchanged one.

`exit_table` names all nine conditions now, including 28-03/04/05's.

### Task 3 — `app/LoopMain.hs` and the six LOOP-01 checks (`3ab9d7e`)

`LoopMain` resolves the chain surface, the prover paths, the identity, the publication directory
and the connection, in that order, each failure exiting by `exit_code_for_precondition`. It imports
the resolving module and nothing under `offchain/lib/Loop/` does — `grep -rc` reports 0 for all six
files there — which is what keeps S2 closed and keeps every importer of that module under
`offchain/app/`.

`cabal run -v0 loop -- --once --help` prints usage and exits 0.

## The firing inputs, every one OBSERVED

| #  | Mutation                                                              | Suite   | Verbatim, from the run                                                                             |
| -- | --------------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------- |
| M1 | the driven stub echoes the recorded `--version` banner                 | 211/213 | `detect_toolchain refused a stub that printed a well-formed probe output and exited 0: ProbeVersionUnreadable (WrongJob "--version")` |
| M2 | `next_range` starts from the head when a watermark is present          | 216/219 | `THE EVENTS THAT OCCURRED WHILE THE LOOP WAS DOWN WERE SKIPPED. Row counts [0,0] for the events at blocks [6,7]` |
| M3 | advance the watermark only when the block produced rows                | 216/219 | `the watermark reads Just 9, expected Just 12`                                                      |
| M4 | ask the source for the whole window in one call                        | 217/219 | `the run asked the source for [(0,1),(1,2),(2,3),(3,4),(4,5)] and the required calls are [(0,0),(1,1),(2,2),(3,3),(4,4)]` |
| M5 | the missing-index refusal names the transaction-hash field             | 217/219 | `a log with no changeLogIndex was refused, but the refusal does not name that field`                 |
| M6 | an unreadable poll value falls back to the default                     | 216/219 | `LOOP_POLL_MS was set to "soon" and the loop resolved a cadence of 1000 milliseconds anyway`         |

Every mutated source was restored from a copy and `sha256sum -c` reported `OK` on all baselines
after every one of the six.

## Findings

### TWO MUTATIONS WERE CAUGHT BY A SECOND, INDEPENDENT GUARD

- **M3** reddened `the_watermark_advances_through_event_free_blocks` at *"reads Just 9, expected
  Just 12"* **and** `a_restart_resumes_at_the_watermark_and_skips_nothing` at *"after the first
  pass over a head of 5 the watermark reads Just 4, expected Just 5"*. The two see the same defect
  from opposite ends — one from a quiet stretch never being crossed, the other from a drained head
  not being drained.
- **M6** reddened `an_unparseable_poll_interval_is_refused_rather_than_defaulted` **and**
  `every_advertised_override_is_honoured`, which is the standing override sweep seeing it from the
  sweep side. That is the value-override probe earning its place: it is not a restatement of the
  dedicated check, it is the same property asserted by the guard that runs over EVERY advertised
  override.

This is 28-01's shape repeating (M2 and M5 there), and it is the reason the plan's instruments are
not redundant with each other.

### `LOOP_POLL_MS` NEEDED A THIRD OVERRIDE SHAPE, AND FILING IT AS A GAP WOULD HAVE BEEN THE WRONG ANSWER

The plan says to add `("loop_poll_ms_env_var", loop_poll_ms_env_var)` to `config_env_vars` and
"probe the override". The census's `uncovered` arm then requires the variable to be in
`advertised_overrides` or in `unprobed_overrides`, and NEITHER fits:

- `probe_override` points the variable at a path that cannot exist and asserts the resolver returns
  it **verbatim**. That assertion is meaningless for a resolver that returns a number.
- `unprobed_overrides` is the honestly-named gap for a variable whose CONSUMER is unreachable from
  `cabal test`. This one's consumer is `Loop.Config.poll_ms_from`, a pure function in the library,
  called by two checks. Pardoning it would be an ignore list covering something fully measurable —
  which is the shape that list's own haddock warns about.

So `value_overrides` transposes `probe_override`'s three assertions rather than dropping them: a
distinctive valid value honoured verbatim, the default when absent with the two differing, and a
bogus value REFUSED with a message that NAMES it. The third is the one that matters, and it is not
a validator written only to be probed — 28-CONTEXT rules that an unparseable cadence is a refusal.
It is folded into `every_advertised_override_is_honoured` rather than registered as a new check, so
the total stays at `BASE_2 + 8`.

### TWO CENSUS FINDINGS, BOTH OBSERVED RED BEFORE THEY WERE FIXED

1. **`sc3_literal_purge` named `offchain/lib/Loop/Run.hs:268`** for the `0xffffffff` mask in
   `split_seed`. An eight-hex literal reads as a selector, and the scan is right to say so. The
   mask is now `Word32`'s own `fromInteger`, which IS the modular reduction — the literal was never
   necessary, only habitual. Twenty-eighth instance on this branch of a token inside a grep's blast
   radius, and the answer was the same as the other twenty-seven.
2. **`every_endpoint_site_resolves_rather_than_hardcodes` named `offchain/lib/Loop/Chain.hs`**:
   *"does not name the resolver on any code line"*. A `HaskellConsumer` must OBTAIN the authority
   from `resolve_endpoint`, and `web3_chain_source` takes it as an argument — the plan fixes that
   signature, and it is the right signature, because it keeps the wiring a pure function of the
   authority. The repair is `resolved_chain_source`, which resolves once and returns the endpoint
   **alongside** the source, so the caller reports the authority it actually used. Two resolutions
   in one process are two answers that can differ, and the one that got reported would be the one
   nobody used.

### `offchain/app/LoopMain.hs` IS NOT AN ENDPOINT SITE, AND THAT IS THE MEASUREMENT

It was listed as one in a first draft. It matches none of `endpoint_census_terms` — it reaches the
chain only through `resolved_chain_source` — so listing it would have made the census's `phantom`
arm red for a file that is genuinely not a site. The manifest went to **nineteen**, not twenty.

### `Chain.Endpoint`'s MANIFEST HADDOCK WAS ALREADY WRONG

It said *"Fifteen entries"* while the list held **eighteen**. Corrected to nineteen with
`Loop/Chain.hs` added. Nothing asserted the number, which is why it drifted; the check that matters
compares the list against the TREE, in both directions, and that was green throughout.

### TWO ACCEPTANCE CRITERIA THE PLAN'S OWN TEXT MAKES UNSATISFIABLE

1. Task 2 asks that `grep -cE "\b(11|124|137|145)\b" offchain/lib/Loop/Config.hs` find none of those
   numerals used as an exit code — while the same task's `<action>` prescribes haddock prose
   stating that "`11` is inside it" and that "`124` and `137` are the timeout wrapper's". A literal
   `grep -c` counts prose. Resolved the way 27-01 rules such collisions: the PROSE MOVED. Loop.Config
   states none of the four numerals and refers to the modules that own them, the grep prints
   **0**, and the disjointness is asserted in
   `the_loop_exit_codes_are_total_and_disjoint_from_the_gams_domain` against `gams_code_domain`
   itself rather than against a transcription of it — which is the stronger statement, because it
   follows a change to the prover's table.
2. Task 1 asks that `grep -E "^detect_toolchain$|^detect_toolchain\b"` show "the export and a
   single-line type signature", while the same task's `<action>` prescribes a FOUR-LINE signature
   with a documented argument per line. The two cannot both hold, and the export line is indented
   so an anchored grep cannot see it either. What was checked instead: the export is present
   (`offchain/lib/Gams/Detect.hs:64`), the signature matches the plan's sketch argument for
   argument, and the grep prints the declaration head and its equation.

### `HaltRpcExhausted` HAS A PRODUCER BUT NO RETRY

28-CONTEXT rules bounded retry with backoff before an RPC halt. This plan wires the halt — a pinned
read that refuses returns `HaltRpcExhausted block 1` before the commit — and no retry. The count in
the constructor is therefore honest and small rather than absent, and the gap is in
`deferred-items.md` rather than in a comment nobody reads.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 — Bug] An eight-hex mask literal in `Loop.Run.split_seed`**
- **Found during:** Task 2
- **Issue:** `sc3_literal_purge` named `offchain/lib/Loop/Run.hs:268`; `0xffffffff` is
  selector-shaped and the scan cannot tell a mask from one.
- **Fix:** the reduction is `fromInteger` at `Word32`, which is defined to be modular. The literal
  and the `Data.Bits` import of `(.&.)` both went.
- **Commit:** `631cf31`

**2. [Rule 3 — Blocking] `Loop.Chain` did not satisfy the endpoint census's consumer rule**
- **Found during:** Task 2
- **Issue:** a `HaskellConsumer` must name the resolver on a CODE line; `web3_chain_source` takes
  the authority as an argument, which is the signature the plan fixes.
- **Fix:** added `resolved_chain_source`, which resolves once and returns `(String, ChainSource)`.
  `LoopMain` uses it, so nothing is dead and nothing resolves twice.
- **Commit:** `631cf31`

**3. [Rule 3 — Blocking] `OverloadedStrings` was missing from `LoopMain`**
- **Found during:** Task 3
- **Issue:** `Rig.Manifest`'s lookups take `Text`; three literals failed to typecheck.
- **Fix:** added the pragma, at the TOP of the file — placing it between the module haddock and
  the `module` keyword detaches the haddock, which was observed and corrected in the same sitting.
- **Commit:** `3ab9d7e`

### Departures from the plan's sketch, toward the property the plan asked for

**4. `Env` has no pool-manager field.** The plan lists one. The manager is closed over by
`source_reads`, which is the only thing that uses it, and a record field whose value is never the
one used is a value that can drift with nothing noticing.

**5. `exit_usage` was added, OUTSIDE the table.** A command line that was never a valid invocation
ended no run, so it is neither a halt nor a precondition — the same reason `exit_ok` is not in the
table. Check 5 asserts it is distinct from every table entry, from `exit_ok`, from
`gams_code_domain` and from the wrapper's two, so it is not an escape hatch.

**6. Check 3 asserts the closed range on the CALLS, not on the function.** The plan asks for
`from == to` "for every block a run produces". `loop_chain` records every range it was asked for
and the check compares the recorded list against `[(b, b) | b <- [loop_first_block .. 4]]` —
contiguity included, so a skipped block is caught as well as a widened one. That is what M4
observes.

**7. Check 6 has five arms, not three.** The plan names unset / `"250"` / `"soon"`. Added: the
child-shell PREMISE that a present-and-empty variable is reachable at all (27-01's repair, without
which the empty arm asserts about a `Maybe` nobody showed the system produces), and a negative
value, because "not a decimal integer" and "not a cadence" are different refusals.

**8. `Loop.Run` re-exports `Halt`.** So a caller needs one import to decide its exit, which is what
`LoopMain` does.

## Authentication gates

None.

## What this leaves for 28-03

- **Publication.** `Loop.Run.env_publish` is called for every outcome carrying an artifact,
  including `elided`, and `LoopMain`'s implementation REPORTS the block, the digest and the length
  and writes nothing. The typed shape (`pool`, `blockNumber` as a string, `chainId`, plus the
  golden's ten fields) and the atomic rename are LOOP-03's.
- **The fixture-directory resolver.** `LoopMain` checks `doesDirectoryExist` against issue #25's
  contract string stated once in that file; 28-03 gives it the `Chain.Endpoint`-shaped resolver
  with its env override and its byte-equal assertion.
- **`br_published` means "an artifact was handed to the publish action"**, not "bytes reached
  disk". The publisher's own success is the publisher's to report, and 28-03 owns it.
- **The RPC retry.** See `deferred-items.md`.
- **A Tier-C capture driving `new_postgres_ledger`.** 28-01 recorded that it has no in-suite
  subject; this plan did not give it one, and `cabal test` remains server-free by construction.
- **CHAIN-01 is still BLOCKED** (issue #26). `LoopMain` stops at the chain-surface precondition
  naming `ShockWriter` and the issue, because the rig manifest names no emitter. Every LOOP-01
  proof in `cabal test` is chain-free and did not wait on it.

## Self-Check: PASSED

Every created and modified file was confirmed on disk with `[ -f ]`; all three task commits were
confirmed with `git log --oneline --all | grep`. `cabal test` was re-run at the end of the check:
**219/219**, and the three structural greps report PASS
(`the_suite_never_names_the_real_solver`, `the_suite_never_reaches_a_chain`,
`the_endpoint_site_census_grows_with_the_tree`).
