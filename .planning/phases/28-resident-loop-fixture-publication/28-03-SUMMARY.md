---
phase: 28-resident-loop-fixture-publication
plan: 03
subsystem: offchain-loop
tags: [haskell, loop, publication, atomic-rename, shape-floor, splice, race, byte-fidelity, census]

requires:
  - phase: 22-driver-capture
    provides: "`Driver.Capture.write_json_atomically` — the temp-sibling-then-rename this plan GENERALIZES rather than copies"
  - phase: 23-postgres-foundation
    provides: "`Store.Types.volume_path_golden_sha256`/`_bytes_len` and the committed 606-byte golden that is this plan's oracle"
  - phase: 24-toolchain-identity
    provides: "BYTE-04's measurement — `dQx[0]` moving by 32 wei through a 53-bit carrier — which is why the splice is textual"
  - phase: 25-content-key-keyed-store
    provides: "`Store.Cache.decide`, `Store.Memory` and the counting-stub `Solver` the cache-hit check drives"
  - phase: 27-anvil-read-layer
    provides: "`Chain.Read.fixture_identity_entries` (CHAIN-05) and `render_address_token`'s deliberate non-masking"
  - plan: 28-02
    provides: "`Loop.Run`'s one iteration function with its `env_publish` seam, `Loop.Config`'s one-resolver idiom, and the LOOP-01 checks whose `loop_env` this plan re-shapes"
provides:
  - "`Driver.Capture.write_bytes_atomically` — and `write_atomically`, the ONE rename in this repository"
  - "`Loop.Publish` — the shape floor, the textual identity splice, and the atomic publish that never creates a directory"
  - "`Loop.Config`'s publication target: `fixture_dir_env_var`, `default_fixture_dir`, `fixture_file_name`, `default_fixture_path`, `fixture_dir_from`, `fixture_dir`"
  - "`Loop.Run.publish_for` — publication for every outcome carrying an artifact, `elided` included, at the EVENT's block; `br_published` now means BYTES REACHED DISK"
  - "five checks: the ten-second race, its torn-read positive control, the shape floor, the byte-verbatim splice and the cache hit"
  - "`FIXTURE_DIR` in `advertised_overrides`, probed through the LOOP-04 refusal itself"
  - "a wall-clock cost model for this suite: the sentinel sweep multiplies any check's cost by about fifteen"
affects: [28-04, 28-05, LOOP-03, LOOP-04]

tech-stack:
  added: ["unix (test-suite stanza only; GHC boot library, +0 packages MEASURED)"]
  patterns:
    - "A positive control is PARAMETERISED into the same harness, so the two arms differ in exactly one expression"
    - "The oracle is the committed bytes: byte-identity is asserted against the golden, never against a re-serialisation of it"
    - "A refusal table is preceded by an arm proving the floor is BELOW the real artifact, or the table passes vacuously"
    - "An instrument that can fail on its own — a shared temp directory, a throwing writer — gets a named arm or a unique name, because an intermittent instrument makes every verdict it reports unreadable"
    - "A wall-clock budget in this repository is multiplied by the sentinel sweep, not by the number of times the check appears"

key-files:
  created:
    - offchain/lib/Loop/Publish.hs
  modified:
    - offchain/lib/Driver/Capture.hs
    - offchain/lib/Loop/Config.hs
    - offchain/lib/Loop/Run.hs
    - offchain/app/LoopMain.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "The shape floor's hard half is the DECODER'S, reached by calling `decode_artifact`, because `post_conditions` already refuses the same `length dQx == nEvents` the consuming forge test asserts and two copies of one contract are free to disagree"
  - "The floor's real subject is a CONSTRUCTED valid-but-tiny artifact, not a truncation: the plan's 150-byte truncation is `ArtifactUnparseable` because the decoder runs first, and that ordering is right"
  - "An aeson `Value` round trip does NOT lose the `dQx[0]` digits — `Scientific` is exact — so the byte-identity arm and the digit-string arm catch DIFFERENT re-renderers and neither is redundant"
  - "The torn writer is `System.Posix.IO`, because GHC's per-inode lock table refuses a write handle while the harness's reader holds the file — the runtime protecting the very invariant the control exists to violate"
  - "An EMPTY `FIXTURE_DIR` resolves to the default, the opposite of `LOOP_POLL_MS`'s ruling, because an empty directory string would publish a real fixture into the repository root with nothing to say so"
  - "`fresh_temp_dir` names each directory uniquely rather than clearing a shared one, after `removeContentsRecursive: Directory not empty` was OBSERVED under the sentinel sweep's repeated passes"

patterns-established:
  - "A firing input whose predicted arm does not fire is DRIVEN a second way until the arm's real subject is identified, and the haddock is corrected to name it"
  - "A wall-clock estimate written by a planner is re-measured before it is repeated"

requirements-completed: [LOOP-03]

duration: 155min
completed: 2026-08-23
---

# Phase 28 Plan 03: Publication — the Atomic Write, the Splice, and the Floor Summary

**A reader racing the publisher for ten seconds completed 204,555 reads across 142,623
publications and found ZERO of them unparseable — and the same reader, against the same two
documents, with only the rename removed, found 1,240,687 torn reads out of 1,333,592 (93.0%), so
the zero is evidence about the rename rather than about the harness.**

## Performance

- **Duration:** 155 min
- **Started:** 2026-08-23T05:02:00Z
- **Completed:** 2026-08-23T07:37:19Z
- **Tasks:** 2/2
- **Files modified:** 6 (1 created, 5 modified)

## Commits

| Task | Commit    | Subject                                                                     |
| ---- | --------- | --------------------------------------------------------------------------- |
| 1    | `ed9f483` | one rename in the tree, and a publish that refuses on five named shapes      |
| 2    | `dc96987` | the ten-second race, and the torn read OBSERVED at nine reads in ten         |

## The numbers, as measured

| Quantity                                     | Before  | After   | How                                              |
| -------------------------------------------- | ------- | ------- | ------------------------------------------------ |
| `cabal test` total (`BASE_3` -> `BASE_3 + 5`) | **219** | **224** | run at Task 1's commit and at Task 2's           |
| `cabal test` wall clock                       | 186 s   | **528 s** | `date` around the binary, both ends RUN        |
| `cabal build --enable-tests -j all` warnings  | 0       | **0**   | `grep -cE '[Ww]arning'` over the build log       |
| `^Downloading` lines                          | 0       | **0**   | same log; `unix` is a boot library               |
| `purge_file_floor`                            | 81      | **82**  | `find` RUN at both ends, zero slack              |
| `credential_scan_floor`                       | 92      | **93**  | `find` RUN at both ends, zero slack              |
| `endpoint_sites` entries                      | 19      | **19**  | counted in the source; this plan adds no site    |

Extension census under `offchain/` at the final measurement: **hs 66, sh 12, json 11, sql 4**.
Both floors moved by the SAME one, `offchain/lib/Loop/Publish.hs`, because this plan commits no
artifact and no script — so neither the `.json` nor the `.sh` census moved. Both `find` commands
were RUN at both ends; neither number was derived from the other.

`BASE_3 = 219` was measured COLD at this plan's start against the interrupted executor's dirty
tree, and CONFIRMED at Task 1's commit: `219/219 checks passed` in 186 s.

### The race, MEASURED on both arms

The counters live only in a failure message, so they were obtained by INVERTING each verdict and
reading what the check printed. Baselines restored and `sha256sum -c`'d afterwards.

| Arm                                     | Publications | Completed reads | Unparseable    |
| --------------------------------------- | -----------: | --------------: | -------------: |
| `publish_fixture` (temp sibling + rename) |  **142,623** |     **204,555** |          **0** |
| no temp file, no rename                   |    **6,079** |   **1,333,592** | **1,240,687**  |

Both counters clear the floor of 100 by three orders of magnitude, and that floor arm is ordered
FIRST in both checks: a race that barely ran is a green "no torn read" about nothing.

The torn arm publishes twenty times less and is read six times more, which is the shape of the
window itself — each publication holds the file half-written for 200 µs, and the reader spends
almost all of its time inside that window rather than outside it.

## What was built

### Task 1 — the generalized writer and `Loop.Publish` (`ed9f483`)

`Driver.Capture.write_atomically` is now the only expression in this repository that renames a
file into place, and both public writers are that expression with a different way of filling the
temp file. **MEASURED:** `grep -rn "renameFile" offchain/lib offchain/app` prints four lines, of
which one is an import and two are haddock sentences — exactly ONE call site.

`Loop.Publish.publish_bytes` decides in an order that is the design, and each step is there
because the one before it would otherwise report the wrong subject: decode, then the byte floor,
then the pool token on TWO arms, then the splice. The splice is textual — the identity prefix and
then every byte of the artifact after its own opening brace — because the stored bytes are the
oracle and BYTE-04 measured what a second renderer costs.

`Loop.Config` gained the publication target in the one-resolver shape, and `Loop.Run.publish_for`
is the one place the cache ruling is spelled: it does not branch on the outcome at all, it
branches on whether there are bytes.

### Task 2 — the five checks (`dc96987`)

Every one runs against a temporary directory. **`git status --porcelain test/` is EMPTY after
every run**, and `Loop.Config.default_fixture_dir` — the real directory, owned by the
`mev_tax_model_one` track — was never created.

The two race checks share `publication_race`, which takes the WRITER as a parameter. That is what
makes the second one a control: the documents, the deadline, the reader and the classification are
identical, and the arms differ in one expression.

## The firing inputs, every one OBSERVED

| #  | Mutation                                                   | Verbatim, from the run                                                                                                   |
| -- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| M1 | point check 1's publisher at `torn_race_writer`             | `A CONSUMER RACING THE PUBLISHER READ A TORN FIXTURE. 1223305 bad read(s) out of 1326222 completed, across 5953 publications` |
| M2 | fold the zero-pool arm into the shape arm                   | `a ZERO pool was answered with Left (PoolIsNotAnAddressToken "0x0000…0000"), expected PoolIsTheZeroAddress`                 |
| M3 | re-render the artifact through a `Double`-carrying value    | `the decimal digit string of dQx[0] -- -2613128317657530400 -- does not occur in the published bytes`                       |
| M4 | skip publication on `OutcomeElided`                         | `THE CACHE HIT DID NOT PUBLISH. The second block reports br_published = False.`                                            |
| M5 | `fixture_min_bytes = 700`, above the 606-byte golden        | `fixture_min_bytes is 700 and the committed golden is 606 bytes. A floor at or above every real artifact refuses everything` |

Every mutated source was restored from a copy and `sha256sum -c` reported `OK` on all baselines
after every one of the five.

**M1 reddened check 1 and left the control GREEN**, which is the pair working as designed.
**M3 reddened three independent structural guards as well** —
`aeson_is_absent_from_the_storage_path`, `no_Double_and_no_aeson_on_the_artifact_path` and
`no_floating_value_is_on_the_fee_path`. **M5 reddened six**, including
`every_advertised_override_is_honoured`: with the floor above every artifact the publisher refuses
on the FLOOR before it reaches the directory check, so the `FIXTURE_DIR` probe's failure stops
naming the resolved path — the override sweep seeing the same defect from the other side, and a
vindication of that probe's third assertion.

## Findings

### THREE OF THE PLAN'S PREDICTIONS WERE REFUTED AND THE HADDOCK CORRECTED, NOT THE CHECK

**1. The 150-byte truncation is `ArtifactUnparseable`, not `BelowShapeFloor`.** The plan
prescribes both the ordering (decode first, "the order is the design") and the refusal
(`BelowShapeFloor` for the truncation), and the two cannot both hold: a prefix of the golden stops
being JSON long before it gets small. The truncation is asserted as `ArtifactUnparseable`, and the
floor's real subject is `publication_undersized_artifact` — a document CONSTRUCTED to be a valid
artifact (one event, one element per leg, one-character price strings) and still under 200 bytes,
whose decode is asserted FIRST so that arm cannot pass for the truncation's reason. That is the
failure the module's own haddock says the floor exists for.

**2. An aeson round trip does NOT lose the `dQx[0]` digits, and this took two mutations to
establish.** The plan says re-rendering "through the suite's JSON value type" must redden the
digit-string arm. Driven: `encode <$> decodeStrict` over `Data.Aeson.Value` reddens the BYTE arm
(*"the published tail is 539 bytes and the golden's own tail after its opening brace is 605"*) and
never reaches the digit arm; with the byte arm neutered so the later arms could run, **the check
came back GREEN**. `Value` carries a number as `Scientific`, which is arbitrary-precision, and its
encoder prints an integral value verbatim — the 539 against 605 is whitespace and key order, not
digits. Re-driven with every number pushed through `Double` and back, the digit arm reddens exactly
as written. So the two arms catch different re-renderers: the byte arm catches ANY rebuild
including an exact one, and the digit-string arm names the carrier BYTE-04 measured — which is
`Double`, never "a JSON value type" in general.

**3. THE WALL-CLOCK BUDGET WAS WRONG BY A FACTOR OF SEVENTEEN, AND THIS IS THE FINDING WITH THE
LONGEST REACH.** The plan says the suite "runs ~173 s against a 900 s ceiling; the two ten-second
harnesses take it to roughly 195 s", on the arithmetic that two ten-second races run once each.
They do not. `sentinel_falsification_harness` re-runs `core_checks` through `all_objections` once
for its own baseline and once per swept artifact (seven), and through `first_objection` for each of
six negative controls — which cannot short-circuit, because their whole point is that nothing
objects. MEASURED at both ends: **186 s without the races, 528 s with them.** Twenty seconds of
racing costs the suite 342. The margin against 900 s is real but it is a third of what the plan
assumed, and the number is now in `race_window_seconds`'s haddock so the next check that wants a
wall-clock budget multiplies by fifteen rather than by two.

### THE TORN CONTROL CANNOT BE WRITTEN IN `System.IO`, AND THE REASON IS THE RUNTIME DEFENDING THE INVARIANT

The plan prescribes "open the destination for writing (truncating), write the first half,
`threadDelay`, write the rest, close". `System.IO.withBinaryFile path WriteMode` raises
**`resource busy (file is locked)`** — OBSERVED, at
`/tmp/cfmm-loop-loop03-torn-control/volume_path.json` — because GHC's runtime keeps a per-inode
lock table and the harness's reader holds the same file open. Catching and retrying would have been
the wrong repair twice over: the reader's own `readFile` would then fail with the same lock error
inside the window, and the harness would count a LOCK failure as a torn read — a control firing for
a reason that has nothing to do with the rename. `System.Posix.IO` issues the `open()` itself and
is outside that table. `unix` is a GHC boot library that `process` already depends on: `+0
packages`, MEASURED, no `Downloading` line.

The same fact explains why the atomic writer is unaffected: it fills a SIBLING — a different inode
— and `rename()` opens nothing at all.

### THE INSTRUMENT HAD TWO FAILURE MODES OF ITS OWN, AND BOTH WERE OBSERVED BEFORE THEY WERE FIXED

1. **`fresh_temp_dir` cleared a shared directory** and raised
   `removeContentsRecursive: unsatisfied constraints (Directory not empty)` and, on another run,
   left the publisher writing into a directory that had just been removed
   (`volume_path.json.tmp: does not exist`). Under the sentinel sweep the same check runs many
   times over, and a `/tmp` path is shared with every other process on the machine. Each directory
   now carries a `getMonotonicTimeNSec` suffix and cannot collide. **The cost of not fixing it was
   measured:** with the race check failing intermittently it entered the sweep's reader sets, and
   the suite ran for **2328 s** instead of 528 — and the harness's own NEGATIVE CONTROL went red
   (*"the sweep reported it CAUGHT by a_reader_racing_the_publisher_sees_no_torn_fixture"*), which
   is the harness correctly refusing to believe a flaky check.
2. **A publication that threw escaped to `guarded`** as an anonymous `unexpected IO error` naming a
   temp file. `race_write_fails` is now its own arm, and the cache-hit check reads through
   `read_if_present` so "nothing was published" is a sentence rather than an exception — measured
   under M5, which produced exactly that opaque failure.

### `split_for` REBUILDS A 2900-MEMBER BAND ON EVERY CALL

The cache-hit check needs two events at DIFFERENT heights carrying an IDENTICAL shock, and
`Loop.Run.split_seed` derives the splitter's seed from the event's position — so the two blocks
must be FOUND, not written. Searching 600 positions through `split_for` costs 600 rebuilds of
`admissible_band` (6496 iterations of big-`Integer` admissibility each) and is minutes of wall
clock. The search goes through `pick_from_band` over a band computed ONCE — the same selector
`split_for` uses — and the two positions it returns are then CONFIRMED through the full `split_for`
by the check itself, so the cheap search decides nothing on its own.

### `NotAJsonObject` IS UNREACHABLE FROM `publish_bytes`, AND THAT IS ASSERTED RATHER THAN CLAIMED

`decode_artifact` refuses a non-object top level before the splice is called. The branch is
therefore driven DIRECTLY against `splice_identity`, and the same payload is asserted to come back
`ArtifactUnparseable` through `publish_bytes` — so the unreachability is a measurement in the check
rather than a sentence in a comment that stops being true on the day the guard in front of it moves.

### THE KEY NAMES COME OUT OF THE GOLDEN'S OWN BYTES

`the_published_fixture_carries_the_artifact_bytes_verbatim` spells no artifact field VALUE and no
artifact key NAME. `json_key_tokens` extracts the top-level names from the golden's bytes (with a
floor asserting it found at least ten, so a broken extractor cannot make the arm vacuous), and only
`pool`, `blockNumber` and `chainId` are written by hand — because those three are the CONTRACT
issue #29 handed across the workstream boundary. A further arm asserts those three are ABSENT from
the golden, so an arm that found them in the artifact could not pass without the splice happening.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 3 — Blocking] The torn control could not be written with `System.IO`**
- **Found during:** Task 2
- **Issue:** `withBinaryFile ... WriteMode` raises `resource busy (file is locked)` against GHC's
  per-inode lock table while the harness's reader holds the file open.
- **Fix:** `System.Posix.IO.ByteString`, with `unix` added to the test-suite stanza (`+0
  packages`, measured). The reason is in the writer's haddock and in the cabal comment.
- **Commit:** `dc96987`

**2. [Rule 1 — Bug] `fresh_temp_dir` raced with itself under the sentinel sweep**
- **Found during:** Task 2
- **Issue:** a shared per-label directory cleared with `removeDirectoryRecursive`; observed failing
  twice, in two different ways, and observed corrupting the harness's negative control.
- **Fix:** a `getMonotonicTimeNSec` suffix per call.
- **Commit:** `dc96987`

**3. [Rule 2 — Missing critical functionality] A throwing publication had no named arm**
- **Found during:** Task 2
- **Issue:** the race aborted at `guarded` with an anonymous IO error; the cache-hit check did the
  same when nothing was published.
- **Fix:** `race_write_fails` as an ordered arm, and `read_if_present` in place of a bare
  `readFile`.
- **Commit:** `dc96987`

### Departures from the plan's sketch, toward the property the plan asked for

**4. `PublicationDirectoryAbsent` is a SIXTH refusal constructor.** The plan names five. The
directory check has to report something, and folding it into one of the five would have made the
`FIXTURE_DIR` probe's "the failure names the resolved path" assertion depend on a constructor about
a different subject.

**5. The `BelowShapeFloor` arm is driven by a constructed artifact, not by the truncation.** See
finding 1.

**6. The `NotAJsonObject` arm is driven against `splice_identity`, not `publish_bytes`.** See the
unreachability finding.

**7. The `FIXTURE_DIR` empty-value and default-path rules are folded into
`every_advertised_override_is_honoured`** rather than registered as a check, which is 28-02's shape
for `value_overrides`: the sweep is the guard that runs over EVERY advertised override, and a
second check restating one variable's rule is a second place for it to be edited. The total stays
at `BASE_3 + 5`.

**8. This plan was RESUMED, and the task split is by concern rather than by chronology.** The
previous executor was killed mid-Task-1 with six files dirty and `Loop/Publish.hs` untracked. The
tree did not build: `loop_chain_id` and `fresh_temp_dir` were referenced by `offchain/test/Main.hs`
and defined nowhere. Task 1's commit was reconstructed as the state in which the library, the app,
the cabal library stanza and the test file's Task-1-forced edits are present and the suite is
GREEN at 219/219 — verified by RUNNING it at that state, not by inspection — and Task 2's commit
adds the five checks. No commit in this plan leaves the tree unbuildable.

## Authentication gates

None.

## What this leaves for 28-04

- **The before/after tree diff.** Nothing here asserts that publication writes exactly one file
  plus its temp sibling and nothing else; `git status --porcelain test/` being empty is a weaker
  statement about a directory this suite never publishes into.
- **`default_fixture_path` against `origin/develop`.** It is asserted here only against
  `default_fixture_dir </> fixture_file_name` — a join, not the consumer's own `VOLUME_PATH_JSON`.
  28-04 owns reading that string live.
- **The missing-directory PRECONDITION and its text.** `Loop.Publish` refuses and names the path;
  the startup stop that names the owning workstream and exits by
  `exit_code_for_precondition` is `LoopMain`'s, and its text is 28-04's to assert.
- **The wall clock.** 528 s against a 900 s ceiling. 28-04 and 28-05 have 372 s of headroom
  between them, and any check that costs T seconds costs the suite about 15T.

## Self-Check: PASSED

- `offchain/lib/Loop/Publish.hs` — FOUND
- `offchain/lib/Driver/Capture.hs` — FOUND
- `offchain/lib/Loop/Config.hs` — FOUND
- `offchain/lib/Loop/Run.hs` — FOUND
- `offchain/app/LoopMain.hs` — FOUND
- `offchain/test/Main.hs` — FOUND
- `cfmm-replicationPlank-rpc-api.cabal` — FOUND
- commit `ed9f483` — FOUND
- commit `dc96987` — FOUND

`cabal test` at the final state: **224/224 checks passed**, `WALL_SECONDS=528`, and the three
structural greps report PASS (`the_suite_never_names_the_real_solver`,
`the_suite_never_reaches_a_chain`, `the_endpoint_site_census_grows_with_the_tree`).
`git status --porcelain test/` is empty.
