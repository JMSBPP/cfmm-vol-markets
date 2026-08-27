---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 2
status: executing
stopped_at: "Completed 01.1-02-PLAN.md — Foundry pin recorded in-repo (.github/foundry-version + notes/TOOLCHAIN_PINS.md), commit dddb26b on feat/ci-feedback-loop, unpushed"
last_updated: "2026-08-27T19:12:36.596Z"
last_activity: "2026-08-27 — Plan 01.1-02 executed: Foundry pin recorded in-repo (.github/foundry-version v1.5.1/b0a9dd9 + notes/TOOLCHAIN_PINS.md), commit dddb26b on feat/ci-feedback-loop, unpushed, no CI run triggered"
progress:
  total_phases: 12
  completed_phases: 0
  total_plans: 12
  completed_plans: 4
  percent: 33
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-27)

**Core value:** A fuzzed input that produces a different `tokenId` in Haskell than in Plank must fail the build.
**Current focus:** Phase 1.1 — CI Feedback Loop (INSERTED; Phase 1 paused at plan 01-03)

## Current Position

Phase: 1.1 of 12 (CI Feedback Loop — INSERTED; runs before Phase 1 wave 3)
Plan: 2 of 6 in current phase
Current Plan: 2
Total Plans in Phase: 6
Status: Executing — Phase 1.1 plan 01.1-02 complete, 01.1-03 next. Phase 1 is PAUSED at 2 of 6 (01-03 resumes after 1.1 merges).
Last activity: 2026-08-27 — Plan 01.1-02 executed: Foundry pin recorded in-repo (.github/foundry-version v1.5.1/b0a9dd9 + notes/TOOLCHAIN_PINS.md), commit dddb26b on feat/ci-feedback-loop, unpushed, no CI run triggered

Progress: [███░░░░░░░] 33%  (4 of 12 plans across the two open phases: 1 and 1.1)

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 2.5 min
- Total execution time: 0.2 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| Phase 1 | 2/6 | 6 min | 3 min |
| Phase 1.1 | 2/6 | 4 min | 2 min |

**Per-plan:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 3min | 3 tasks | 2 files |
| Phase 01 P02 | 3min | 1 tasks | 1 files |
| Phase 01.1 P01 | 2min | 3 tasks | 2 files |
| Phase 01.1 P02 | 2min | 2 tasks | 2 files |

**Recent Trend:**
- Last 5 plans: 3 min, 3 min, 2 min, 2 min
- Trend: flat (4 data points)

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
- [Phase 01]: SpecOracle seam shaped to the interface evm-spec-bridge GENERATES (library SpecOracle, volOrderToTokenId(bytes,uint64), health()); isWired() collapsed into health() — one wiring mechanism
- [Phase 01]: Status lives as a field ON Health (not (Status,Health)) so the skip predicate is health().status == Status.TransportFailure — the SAME predicate Phase 7 keeps. Provisional pending generation
- [Phase 01]: Phase 1 stub REVERTS (SpecOracleNotWired) rather than returning a zero struct — fail-safe, not fail-open. Phase 7's real impl RETURNS the tagged struct and must not revert (GUARD-05)
- [Phase 01.1]: Phase 1.1 opened on develop tip 90dacaa: tracking issue JMSBPP/cfmm-vol-markets#58, worktree /home/jmsbpp/cfmms-playground/cfmm-wt/ci-feedback-loop on feat/ci-feedback-loop (pushed to origin, zero divergence)
- [Phase 01.1]: Decimal/INSERTED phases use the identical FEATURES convention — the numbered tool-facing dir carries the decimal (01.1-ci-feedback-loop) and the FEATURES entry is the same mode-120000 symlink; now written into FEATURES/README.md
- [Phase 01.1]: feat/ci-feedback-loop pushed with no new content BEFORE push-build.yml exists — GitHub picks push-event workflows from the pushed ref, so plan 03's push is by construction the first observable trigger, not by assumption
- [Phase 01.1]: Foundry pinned in-repo at .github/foundry-version: v1.5.1 / commit b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2 / installer a27902ef04dcb43061fabf343365cb5afc95fc48 — a shell-sourceable KEY=value file both workflows will source, so the push build and the PR gate cannot pin different versions
- [Phase 01.1]: The pin asserts on the COMMIT SHA, not the tag, and its rationale lives in notes/TOOLCHAIN_PINS.md (binding spec per CLAUDE.md) — a bump is a two-file diff whose review must re-measure the four transport findings; v1.8.0 refused despite vm.rpcJson because it encodes returns differently
- [Phase 01.1]: CI installs the pin into $HOME/.foundry-pins/$FOUNDRY_VERSION and prepends it to PATH, deliberately NOT $HOME/.foundry — on the persistent cfmm-build runner that shared dir IS the box's default forge, so installing there would have CI rewrite the machine for every other job

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
- **MEASURED (forge 1.5.1-stable `b0a9dd9`, solc 0.8.34) — the founding failure mode was REPRODUCED.** A server that accepts the connection and never answers costs **45.00 s per call and the test PASSED**, because the call site ignored `success`. At `fuzz.runs = 256` that is **3.2 hours of green CI meaning nothing**. Refines the earlier note: connection-refused fails fast, but *accepted-and-never-answered* pays the full hardcoded 45 s, and `vm.rpc` has no timeout knob. A half-dead server is far worse than a dead one. **BINDING RULE: every oracle call site captures `(bool ok, bytes ret)` and asserts on `ok` before touching `ret`**, enforced by a grep-verifiable criterion, not by discipline.
- **MEASURED — `bytes memory b = vm.rpc(...)` is UNSAFE.** Static-coerced results give a bare un-messaged `EvmError: Revert`; **object results silently return garbage with `b.length == 96`**. Version-dependent: master encodes returns differently from 1.5.1. Never `abi.decode` a raw `vm.rpc` return.
- **MEASURED — the JSON→ABI coercion is VALUE-DEPENDENT, which is the fuzzing hazard.** The same record decodes to different ABI types by number *magnitude*: `tokenId "0"` → `tuple(string,string,string)`; `tokenId "18446744073709551616"` → `tuple(string,string,uint256)`. A fuzz campaign hits both; a decoder correct for one is wrong for the other, intermittently, by input magnitude — and would present as a Plank divergence. Together with alphabetical key reordering and `null` → 32 zero bytes, this makes the **one even-length `0x`-hex string with a tag byte the single highest-value constraint in the design**.
- **MEASURED — selector-matching cannot distinguish failure modes.** JSON-RPC error object, HTTP 500, connection-refused, timeout, and calling an absent cheatcode ALL revert with `CheatcodeError(string)` = `0xeeaa9e6f`, differing only in unstable English text. The three-way distinction exists ONLY because rejection rides the HTTP-200 `result` channel with a tag.
- **MEASURED — a bare-string `health()` proves the wrong thing.** `"ok"` is a `string`, one of the few cleanly-decoding shapes, so a green health check says nothing about whether domain payloads survive. `health()` must return the **same tagged hex envelope** a domain method returns. Expected future fixtures: `spec_fixtureRejection`, `spec_fixtureTransportFault`.
- **OPEN RISK — Foundry is UNPINNED in this repo and in CI.** Verified: no version key in `foundry.toml`, no `foundry-toolchain` action or `foundryup` step in `develop-gate`, no `.foundryrc`/`.tool-versions`. The self-hosted runner uses whatever `forge` is on the box, and being *persistent* it drifts silently on any `foundryup`. Local is `1.5.1-stable` `b0a9dd9` — the exact commit all transport findings were measured at; v1.8.0 (published 2026-08-27) encodes returns differently. Unpinned Foundry makes wire behaviour non-deterministic across runs. Candidate for `/gsd:insert-phase`; NOT in RED-01..06, so not absorbed into Phase 1 unilaterally.
- **STANDING RULE — Foundry docs track `master`, not the shipped binary.** A researcher recommended `vm.rpcJson` at HIGH confidence, correctly read from real documentation, for a cheatcode absent from every binary anyone runs. Documentation is a claim about `master`; only `cheatcodes.json` at a *release tag* is a claim about what ships. Never cite Foundry docs as evidence about the installed toolchain.
- **RECURRING DESIGN PULL to resist: "the adapter/transport validates."** An independent researcher concluded the bridge should own guard evaluation. That is a coherent transport design and wrong only because of a property specific to this project — the spec must be the SOLE oracle, or the differential test degenerates into comparing Plank against a re-implementation (exactly the hand-ported `validate()` problem this milestone exists to kill). Nothing about the transport makes that obvious, so the pull will recur and will look reasonable each time. Guard evaluation is the spec's, without exception.
- **Coercion-conformance fixture → assigned to Phase 5 (RPC-03), NOT the pin phase.** Idea from `evm_spec_rpc`: a test asserting the specific `vm.rpc` behaviours depended on (a `0x`-hex result round-trips byte-exactly; the value-dependent coercion still behaves as measured), so a forge bump on the runner goes red with a named cause instead of silently reclassifying outcomes mid-fuzz. It is the third drift layer — pin prevents, version-stamp reveals, fixture *fails*. It is NOT cheap here: `vm.rpc` makes a real HTTP request, so the fixture needs a responder, which does not exist until Phase 5's skeleton server plus CI-01/CI-02. **Assertion lines to include:** a `0x`-hex result round-trips byte-exactly; the value-dependent coercion still behaves as measured; and `expectRevert` on `environment variable ... not found` proving `${...}` alias resolution is still lazy rather than load-time.
- **RESOLVED BY MEASUREMENT — `[rpc_endpoints]` `${...}` resolves at alias USE, not at config load.** The feared gate-wide collapse does not occur. Measured by `evm_spec_rpc` on `forge 1.5.1-stable` `b0a9dd9` (byte-identical to local and to the inserted pin), with `EVM_SPEC_BRIDGE_URL` unset: `forge build` succeeds (exit 0); `forge config` succeeds and stores the value **uninterpolated** as the literal `"${EVM_SPEC_BRIDGE_URL}"` — the decisive evidence, since a literal surviving into loaded config means no load-time interpolation; unrelated tests pass; only a test that *uses* the alias fails, with `vm.rpc: environment variable EVM_SPEC_BRIDGE_URL not found`; and the failure is scoped, not contagious across suites. With the var SET and nothing listening, the error carries the env value's URL, proving interpolation does happen at use. **Consequence:** the alias is safe to add, and safe to add BEFORE anything can answer on it — the key costs nothing until a test uses it. The self-describing "variable not found" failure is actually *better* than the literal-URL fallback, which would give a connection error to a hardcoded port. The literal-URL form drops from load-bearing back to merely available. Caveat: 1.5.1-stable only — exactly what the inserted pin exists to hold still.
- **TOOLING — `update-plan-progress` lying is STRUCTURAL, not intermittent; never trust its return.** Root cause confirmed by `custom_gsd` reading the source: the command ends in an **unconditional** `output({updated: true})` — an inner `withRows !== roadmapContent` comparison exists but the final return path never consults it. Paired with an edit helper whose own doc comment says a no-op "simply returns its input unchanged", a missed regex yields unchanged content and `updated: true` regardless. Same defect class affects `update-progress`. **Every executor must verify with `git diff` and set rows/checkboxes by hand.** Confirmed still present in the `open-gsd/gsd-core` lineage too, so it will not be fixed by an upgrade. By contrast `record-metric` and `add-decision` (bugs 3/4) ARE fixed in gsd-core — those workarounds are specific to this `get-shit-done-cc` v1.25.1 install.
- **Cross-boundary misattribution to watch for:** Haskell bottoms in the unmodified spec escape as HTTP 500 — i.e. as *transport failure* — so a spec bug can present as the bridge being broken. Bridge-side fix is `try (evaluate (force x))` rather than `throwError`. Signature: transport failures clustering on particular inputs rather than randomly.
- **Never route spec rejections through `vm.assume`.** `max_test_rejects` is 65536 and shared — rejections would burn a global budget and be hidden rather than observed.
- **GHC/cabal on the self-hosted runner is unverified.** Now a Phase 5 prerequisite, not Phase 11 — a service transport means the runner must build AND RUN a long-lived process. Present on the dev machine (GHC 9.10.3 / cabal 3.16.1.0); unverified on the runner. The persistent self-hosted runner also risks leaked processes answering later runs on a stale spec commit — mitigated by the `specCommit` assertion plus an ephemeral port rather than a fixed one.
- **CI ordering tension (accepted).** CI-01/CI-02 put the spec on the runner but sit in Phase 11, while Phases 6–10 need spec reachability to be gate-observable. The RED-05 wiring probe absorbs this; if it proves insufficient, pull CI-01/CI-02 forward via `/gsd:insert-phase` rather than reordering silently.
- **Two-repo cost in Phase 6.** Spec changes land via `JMSBPP` fork → PR into `d2p-finance/cfmm-vol-markets-spec` plus a submodule pin bump here.

## Reminders

- Every phase = one git worktree named after its `feat/…` branch + a tracking issue on `develop`.
- CI (`develop-gate`) is the sole validation gate. Never report work as verified from a local build or local `forge test`.
- Regression floor: `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` stays green in every gate run.

## Session Continuity

Last session: 2026-08-27T19:12:29.534Z
Stopped at: Completed 01.1-02-PLAN.md — Foundry pin recorded in-repo (.github/foundry-version + notes/TOOLCHAIN_PINS.md), commit dddb26b on feat/ci-feedback-loop, unpushed
Resume file: None

Next: execute `.planning/phases/FEATURES/feat-ci-feedback-loop/01.1-03-PLAN.md` (`.github/workflows/push-build.yml` + `scripts/check-ci-skip-ledger.sh`, sourcing `.github/foundry-version`; this plan's push is the FIRST that carries the workflow and therefore the first that can trigger it — CI-06/CI-07) in the `feat/ci-feedback-loop` worktree at /home/jmsbpp/cfmms-playground/cfmm-wt/ci-feedback-loop. `feat/ci-feedback-loop` currently has 1 unpushed commit (dddb26b).
Phase 1 resumes at `01-03-PLAN.md` in the `feat/red-diff-scaffold` worktree once Phase 1.1 merges.
