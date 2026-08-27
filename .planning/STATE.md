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

- **UNVERIFIED AND LOAD-BEARING: does `vm.rpc` forward arbitrary non-`eth_*` methods to a non-Ethereum endpoint, and how does it surface results to Solidity?** The entire JSON-RPC decision rests on this. It was asserted confidently earlier in planning from recollection, NOT from Foundry source or docs. `evm_spec_rpc` has a researcher verifying it against source. If it only proxies `eth_*` to a real node, the transport decision collapses and both roadmaps change.
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
