# Deferred items — phase 28

Discovered during execution, OUT OF SCOPE for the plan that found them. Not fixed.

## 28-02

- **Four untracked files at the repository root predate this phase** and were present in the
  worktree before 28-02 executed: `CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock`.
  `CHANGELOG.md` is named by the cabal file's `extra-doc-files` stanza, so a source distribution
  built from a clean checkout would fail on it. None of the four is touched by 28-02 and none is
  a consequence of its changes, so they are recorded here rather than committed or ignored by an
  executor who did not create them. Owner: whoever ran `cabal init`/`stack init` on this branch.

- **`Loop.Config.HaltRpcExhausted` reports one attempt, always.** 28-CONTEXT rules bounded retry
  with backoff before an RPC halt, and 28-02 wires no retry: `Loop.Run.process_block` halts on the
  first refused pinned read and reports `HaltRpcExhausted block 1`. The code exists, the condition
  exists, the RETRY does not. It belongs with the plan that owns the live path.

- **`Loop.Config.EndpointUnresolvable` is the chain-surface precondition, not only the endpoint's.**
  `Chain.Endpoint.resolve_endpoint` cannot fail -- it returns the default -- so the constructor's
  live producers in `offchain/app/LoopMain.hs` are the rig-manifest lookups (the pool manager, the
  shock emitter, the pool id). The name is the plan's and was kept; the haddock says what it covers.

## 28-03

- **`sentinel_falsification_harness` multiplies every check's cost by about fifteen, and nothing
  says so at the point where a check is written.** MEASURED at 28-03: the suite runs in 186 s
  without this plan's two ten-second race harnesses and 528 s with them, so twenty seconds of
  racing costs the suite 342. The cause is structural rather than a defect -- `reader_set` runs
  `core_checks >>= all_objections` once per swept artifact (seven), the harness runs it once more
  for its own baseline, and the six negative controls run `core_checks >>= first_objection`, which
  cannot short-circuit because their whole point is that nothing objects. `expensive_checks` exists
  and is ORDERING only ("nothing is ever dropped from a list because it appears here"), so it does
  not help. The number is recorded in `race_window_seconds`'s haddock; whether the sweep should be
  able to EXCLUDE a check that reads no artifact -- soundly, in the direction `reader_set`'s own
  haddock already argues -- is a change to the harness and belongs to whoever owns it. 28-03 did
  not need it: 528 s is inside the 900 s ceiling.

- **`Loop.Publish.publish_fixture` reports success from the WRITE, and nothing re-reads the file.**
  *(Still open at the phase close. 28-04 did not take it and neither did 28-05.)*
  `br_published` now means "bytes reached disk" in the sense that `write_bytes_atomically`
  returned. A rename that succeeded and a file that a consumer can read are the same thing on
  POSIX, and 28-03's race harness measures exactly that from the outside -- but the LOOP itself
  never verifies its own publication. If a plan ever wants "the loop confirms what it published",
  it is a read-back, and it belongs with 28-04's before/after tree diff rather than here.

## 28-05

- **A REAL `SIGINT` WAS NEVER DELIVERED TO THIS LOOP.** What `cabal test` drives is
  `Loop.Run.env_interrupted`, the FLAG — which is the half the loop owns, and the only half a
  chain-free suite can reach. The other half is `offchain/app/LoopMain.hs`'s
  `installHandler sigINT (Catch …)` / `installHandler sigTERM (Catch …)`, and that executable stops
  at the chain-surface precondition because the rig manifest names no emitter (CHAIN-01, issue #26).
  So "the handler writes the flag and does nothing else" is a property of six lines that compile and
  have never run. It belongs with the plan that runs `capture-loop.sh`, which should send the signal
  and observe the loop draining at a boundary rather than mid-block. Owner: whoever discharges #26.

- **`Loop.Config.HaltRpcExhausted` STILL reports one attempt, always** — 28-02 recorded it and
  neither 28-03, 28-04 nor 28-05 wired the bounded retry 28-CONTEXT rules. 28-05 did NOT make this
  worse and did not fix it: the new outer wrapper catches an exception from the log fetch or the
  pinned read as `HaltBlockException` rather than retrying it either. The condition, the constructor
  and the exit code all exist; the RETRY does not. It belongs with the plan that owns the live path,
  because a retry policy chosen without ever having watched a real node time out is a guess.

- **THE COPY-INSTEAD-OF-RENAME MUTATION MAKES THIS SUITE PATHOLOGICAL, AND THAT IS A PROPERTY OF THE
  HARNESS RATHER THAN OF THE MUTATION.** Driving 28-05's third firing input as
  `renameFile tmp path` → `BS.readFile tmp >>= BS.writeFile path` reddens the ten-second race check,
  which puts it into `sentinel_falsification_harness`'s reader sets — 28-03's measured
  multiply-by-fifteen, applied to a check that costs ten seconds. **OBSERVED: the run passed 52
  minutes of CPU without finishing and was abandoned.** 28-03 measured the same shape at 2328 s
  against a normal 528 and filed the underlying question (whether the sweep should be able to
  EXCLUDE a check that reads no artifact) as a change to the harness. This is a second, sharper
  instance: it means a whole CLASS of firing input — anything that reddens an expensive check —
  cannot be driven on this suite in reasonable time, and a future executor who meets it should
  re-aim the mutation surgically rather than wait. 28-05 re-aimed it (keep the rename, re-fill the
  temp file afterwards) and the arm reddened in 553 s. Owner: whoever owns the harness.

- **`offchain/rig/capture-loop.sh`'s ONE `cast send` LINE IS UNCONFIRMED AND SAYS SO.** The emitter
  does not exist in any tree this workstream builds from, so its entry point's NAME and ARGUMENT
  LIST cannot be read off anything — only the EVENT is pinned, by a topic0 recomputed from
  `Chain.Shock.shock_signature`. Whoever lands the emitter must correct that line against the
  interface they ship. It is flagged in the script's own comment rather than left to be discovered,
  because a plausible-looking call that was never executed is exactly the kind of thing that gets
  believed.

- **The four untracked root files are STILL untracked** — `CHANGELOG.md`, `Setup.hs`, `stack.yaml`,
  `stack.yaml.lock`. Flagged by 27's phase summary, re-flagged by 28-02, and untouched by every plan
  in this phase. `CHANGELOG.md` is named by the cabal file's `extra-doc-files` stanza, so a source
  distribution built from a clean checkout would still fail on it. Owner: whoever ran
  `cabal init`/`stack init` on this branch.
