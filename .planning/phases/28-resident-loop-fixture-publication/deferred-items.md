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
