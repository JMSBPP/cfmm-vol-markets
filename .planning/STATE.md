---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 1
status: executing
stopped_at: "Completed 01-01-PLAN.md — FEATURES layout on develop (04dea0a), issue #57, worktree feat/red-diff-scaffold"
last_updated: "2026-08-27T16:48:45.222Z"
last_activity: "2026-08-27 — Plan 01-01 executed: FEATURES layout on develop (04dea0a), tracking issue #57, worktree feat/red-diff-scaffold"
progress:
  total_phases: 11
  completed_phases: 0
  total_plans: 6
  completed_plans: 1
  percent: 17
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-27)

**Core value:** A fuzzed input that produces a different `tokenId` in Haskell than in Plank must fail the build.
**Current focus:** Phase 1 — RED Differential Scaffold

## Current Position

Phase: 1 of 11 (RED Differential Scaffold)
Plan: 1 of 6 in current phase
Current Plan: 1
Total Plans in Phase: 6
Status: Executing — plan 01-01 complete, 01-02 next
Last activity: 2026-08-27 — Plan 01-01 executed: FEATURES layout on develop (04dea0a), tracking issue #57, worktree feat/red-diff-scaffold

Progress: [██░░░░░░░░] 17%

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 3 min
- Total execution time: 0.05 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| Phase 1 | 1/6 | 3 min | 3 min |

**Per-plan:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 3min | 3 tasks | 2 files |

**Recent Trend:**
- Last 5 plans: 3 min
- Trend: — (single data point)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions table. Affecting current work:

- Haskell spec is the oracle; the hand-ported Solidity `validate()` stays as an independent structural check, not the oracle.
- `VolOrder` becomes `VolOrder(T)` with an `extra: T` payload, following the in-repo `Shock(R)` pattern — no in-place signature break.
- The `VolOrder(T)` refactor is a blocking prerequisite; the diff test consumes the generic type.
- Plank is the fuzz source; inputs are transported to Haskell, never constructed independently on each side.
- Enforce the diff test inside `develop-gate` — a self-skipping test is silently unenforced.
- `.planning/phases/FEATURES/feat-*/` adopted as the milestone layout; GSD tooling for it deferred to v2.
- Phase 5 is a dedicated interactive RPC/transport design phase: it owns the transport decision and fixes the responsibility split between the Haskell spec service and the Foundry test process, proven by a payload-free protocol skeleton.
- Phase 6 (spec oracle) is built test-first (TDD) from its architecture and specification.
- No local compilation: dependencies/submodules are deliberately left uninitialized locally; CI manages them and the compiler's answer is read from `develop-gate`, for pushes and PRs alike.
- [Phase 01]: FEATURES phase dirs are git-tracked symlinks (mode 120000) into the numbered GSD path — gsd-tools' phase scan does not follow symlinks, so the numbered path stays tool-facing
- [Phase 01]: Phase 1 opened on develop tip 04dea0a: tracking issue JMSBPP/cfmm-vol-markets#57, worktree /home/jmsbpp/cfmms-playground/cfmm-wt/red-diff-scaffold on feat/red-diff-scaffold (pushed to origin)

**Open by design — owned by phase planning, do not pre-resolve:**

- `VolOrder(T)` wire format: Shock-style tagged vs per-variant layout → **Phase 4**
- ~~Spec transport~~ → **RESOLVED: JSON-RPC**, decided at `evm-spec-bridge` initialization outside Phase 5 (user override, confirmed directly). Phase 5 now *records* it and remains the reference contract for the bridge.
- **STILL OPEN — RPC-02 responsibility split** → **Phase 5**. A strong prior has been sent to `evm_spec_rpc` and accepted by them: guard evaluation is the spec's without exception; protocol well-formedness is the bridge's while domain validation IS guard evaluation; codec generated from one schema; error classification the bridge's, carrying the rejecting guard. Not yet ratified by the user.
- Oracle packaging: new cabal exe vs a mode on `cfmm-scratchpad-exe` → **Phase 6**

### Pending Todos

None yet.

### Blockers/Concerns

- **VERIFIED FROM SOURCE — `vm.rpc` forwards arbitrary methods to any endpoint.** `crates/cheatcodes/src/evm/fork.rs::rpc_result` builds `ProviderBuilder::<AnyNetwork>::new(url).build()` then `provider.raw_request(method, params)`: **no allowlist, no `eth_*` check, no namespace filter, no node handshake.** `rpc_endpoint` accepts any string starting with `http`/`ws`. `rpc_1Call` is `apply`, not `apply_stateful`, so the 3-arg form needs **no fork, no anvil and no `[rpc_endpoints]` entry** — `vm.rpc("http://127.0.0.1:8547", "spec_health", "[]")` works in plain `forge test`. Two independent researchers reached this from the same source. The original claim (asserted here from recollection) is vindicated, but the end-to-end round trip against a non-Ethereum server still has **no known prior art** — `evm_spec_rpc` is running a throwaway spike to close that.
- **`vm.rpcJson` IS NOT AVAILABLE — use `vm.rpc`.** Merged 2026-06-05 (PR #15076); absent in v1.6.0/v1.7.0, present only in v1.8.0, published 2026-08-27. Local toolchain is `forge 1.5.1-stable`. Pinning a same-day release to obtain it would be reckless.
- **The one-hex-blob result is LOAD-BEARING, not a convenience.** `vm.rpc` runs the JSON `result` through `json_value_to_token`, where objects become tuples **in alphabetical key order**, numbers round-trip through **`f64`**, and `null` becomes **32 zero bytes**. The only byte-exact branch is `"0x<even-nibble hex>"`. So `"0x" <> hex(abi_encode(...))` is the ONLY lossless option — a later phase must not "simplify" it into returning a JSON object.
- **HARD ARCHITECTURAL CONSTRAINT: spec rejection travels in the JSON-RPC `result` field as a tagged value; `error` is reserved for transport/protocol faults.** Evidence chain: `fork.rs:599-604` maps any provider error to `Err`; `inspector.rs:1443-1453` turns a cheatcode `Err` into `InstructionResult::Revert`; `error.rs:137-142` encodes it as `Vm::CheatcodeError { message: string }` — **untyped free text**. Connection-refused, HTTP non-200, malformed body, the 45 s timeout and a JSON-RPC `error` object all collapse into that one string. This is the conflation XPORT-02 and Phase 9 exist to prevent.
- **Transport failure arrives as a REVERT, so the boundary must catch it.** Prefer low-level `address(vm).call(...)` over `try`/`catch`: whether `try`/`catch` works against a cheatcode is the lowest-confidence item found (it does an `extcodesize` check against the cheatcode address). OPEN.
- **Retry/timeout reality (earlier alarm was overstated).** `max_retry` 8 / `initial_backoff` 800 ms / `REQUEST_TIMEOUT` 45 s are **hardcoded and unconfigurable** for `vm.rpc` — `rpc_result` builds via `ProviderBuilder::new`, not `from_config`, so `eth_rpc_timeout` and per-endpoint `retries` do NOT reach it. But retries fire only on **HTTP 429/503**; connection-refused **fails fast**, so an unwired oracle is cheap and a per-test probe would not hang the gate. Probe-once-and-cache is retained as hygiene plus insurance against the one real residual: a **hung** server costs a hardcoded 45 s per call, unshortenable from the Solidity side (the bridge bounds handler execution time to prevent it).
- **Address the oracle as `http://127.0.0.1:PORT`, never `localhost`.** Alloy's `guess_local_url` recognises only `localhost`/`127.0.0.1`/`::1`; a miss means `HTTP_PROXY` is honoured — a bizarre failure mode on a proxied self-hosted runner. Localhost is exempt from the CUPS rate limiter.
- **Never route spec rejections through `vm.assume`.** `max_test_rejects` is 65536 and shared — rejections would burn a global budget and be hidden rather than observed.
- **GHC/cabal on the self-hosted runner is unverified.** Now a Phase 5 prerequisite, not Phase 11 — a service transport means the runner must build AND RUN a long-lived process. Present on the dev machine (GHC 9.10.3 / cabal 3.16.1.0); unverified on the runner. The persistent self-hosted runner also risks leaked processes answering later runs on a stale spec commit — mitigated by the `specCommit` assertion plus an ephemeral port rather than a fixed one.
- **CI ordering tension (accepted).** CI-01/CI-02 put the spec on the runner but sit in Phase 11, while Phases 6–10 need spec reachability to be gate-observable. The RED-05 wiring probe absorbs this; if it proves insufficient, pull CI-01/CI-02 forward via `/gsd:insert-phase` rather than reordering silently.
- **Two-repo cost in Phase 6.** Spec changes land via `JMSBPP` fork → PR into `d2p-finance/cfmm-vol-markets-spec` plus a submodule pin bump here.

## Reminders

- Every phase = one git worktree named after its `feat/…` branch + a tracking issue on `develop`.
- CI (`develop-gate`) is the sole validation gate. Never report work as verified from a local build or local `forge test`.
- Regression floor: `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` stays green in every gate run.
- Every plan passes the two-step review (Reality Checker + one matched specialist, in parallel) before execution.

## Session Continuity

Last session: 2026-08-27T16:47:41.001Z
Stopped at: Completed 01-01-PLAN.md — FEATURES layout on develop (04dea0a), issue #57, worktree feat/red-diff-scaffold
Resume file: None

Next: execute `.planning/phases/FEATURES/feat-red-diff-scaffold/01-02-PLAN.md` (SpecHelper.sol stub + isWired probe) in the `feat/red-diff-scaffold` worktree
