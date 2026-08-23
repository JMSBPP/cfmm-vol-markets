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
  `br_published` now means "bytes reached disk" in the sense that `write_bytes_atomically`
  returned. A rename that succeeded and a file that a consumer can read are the same thing on
  POSIX, and 28-03's race harness measures exactly that from the outside -- but the LOOP itself
  never verifies its own publication. If a plan ever wants "the loop confirms what it published",
  it is a read-back, and it belongs with 28-04's before/after tree diff rather than here.
