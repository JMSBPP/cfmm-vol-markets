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

- **PARTLY CONFIRMED, LOW CONFIDENCE, NOVEL, NO PRIOR ART — the JSON-RPC transport round trip.** Verified against Foundry `master` source by `evm_spec_rpc`: `vm.rpcJson(urlOrAlias, method, params) returns (string)` DOES accept an arbitrary method string, so the structural claim holds. What remains unverified is the end-to-end round trip against a NON-Ethereum server: (a) whether alloy's `ProviderBuilder::<AnyNetwork>::new(url).build()` makes eager chain-detection calls (e.g. `eth_chainId`) the bridge must answer, (b) whether alloy's deserializer tolerates an arbitrary object in `result`, (c) whether the transport-failure revert is reliably catchable via `try`/`catch` — the entire three-way distinction rests on (c). **No prior art found for pointing this cheatcode at a non-Ethereum service.** Provenance: the original "forwards arbitrary methods" claim was asserted in this project's planning from recollection, not source; it is now partly vindicated but must not be treated as settled. `evm_spec_rpc` is running a throwaway transport spike (hardcoded `{"jsonrpc":"2.0","id":1,"result":"pong"}` responder hit from a real `forge test`) and will send evidence, not a verdict.
- **CORRECTION: the cheatcode is `vm.rpcJson`, not `vm.rpc`.** `vm.rpc` coerces the JSON result through `json_value_to_token` and ABI-encodes it — built for Ethereum's hex-string results, fragile for structured values. Use the three-arg `vm.rpcJson` overload (the two-arg form targets the current fork).
- **HARD ARCHITECTURAL CONSTRAINT: spec rejection must travel in the JSON-RPC `result` field as a tagged value; `error` is reserved for transport/protocol faults.** Alloy turns any JSON-RPC `error` into a cheatcode revert, indistinguishable from connection-refused — the exact conflation XPORT-02 and Phase 9 exist to prevent. Consequence: transport failure arrives as a REVERT, so the generated library must external-self-call and `try`/`catch` to produce `Status.TransportFailure`. Signatures are unaffected; the wrapping is Phase 7's.
- **CI LANDMINE: Foundry retries a refused connection 8× with exponential backoff** (`max_retry` 8, `initial_backoff` 800 ms, `REQUEST_TIMEOUT` 45 s). A per-test wiring probe against an absent oracle costs tens of seconds to minutes and makes the gate *appear to hang* rather than fail. Binding mitigation, baked into Phase 1 so later phases inherit it: **probe once in `setUp()`, cache the outcome, and skip on the cached value** — never call `health()` per test case. Tuning knob is `eth_rpc_timeout` in `foundry.toml`; whether `max_retry` is exposed as a `foundry.toml` key is UNCONFIRMED. Localhost is exempt from the CUPS rate limiter (`guess_local_url` sets `is_local`).
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
