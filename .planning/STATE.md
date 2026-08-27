---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 6
status: executing
stopped_at: "Completed 01.1-06-PLAN.md — PHASE 1.1 IS COMPLETE AND MERGED. PR #59 merged as e6276f2; push-build.yml, .github/foundry-version, notes/TOOLCHAIN_PINS.md and scripts/check-ci-skip-ledger.sh are live on origin/develop, and develop-gate resolves the pin there. First gate run 33112404579 (pull_request, success) stamped b0a9dd9... with VolOrderToPanopticTokenId 10/10 and the suite at 271/0/1. Criterion 3 proven: two pushes to develop with the workflow present (e6276f2, 62d35b2) produced ZERO push-build runs. CI-05/06/07 ticked; issue #58 closed. THE FINDING: develop-gate has no approval gate and never has — criterion 2 restated per Option B, repo config unchanged. NEXT: Phase 1 resumes at plan 01-03, and its FIRST action should be bringing feat/red-diff-scaffold up to origin/develop so it inherits push builds."
last_updated: "2026-08-27T20:36:00.000Z"
last_activity: "2026-08-27 — Plan 01.1-06 completed Phase 1.1: PR #59 merged as e6276f2 with an admin bypass, both CI workflows now live on develop, the pinned toolchain stamped on the gate path for the first time, and the develop-exclusion proven across two real pushes. Its checkpoint produced the phase's most valuable finding — develop-gate has never had an approval gate (protection_rules: []) — which corrected a belief that had been used to argue design decisions here and in a sibling project."
progress:
  total_phases: 12
  completed_phases: 0
  total_plans: 12
  completed_plans: 8
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-27)

**Core value:** A fuzzed input that produces a different `tokenId` in Haskell than in Plank must fail the build.
**Current focus:** Phase 1.1 — CI Feedback Loop (INSERTED; Phase 1 paused at plan 01-03)

## Current Position

Phase: 1.1 of 12 (CI Feedback Loop — INSERTED) — **COMPLETE AND MERGED**; Phase 1 resumes next
Plan: 6 of 6 in current phase — ALL COMPLETE
Current Plan: 6
Total Plans in Phase: 6
Status: **PHASE 1.1 COMPLETE AND MERGED.** PR #59 merged as `e6276f2` (merge commit, admin bypass). `push-build.yml`, `.github/foundry-version`, `notes/TOOLCHAIN_PINS.md` and `scripts/check-ci-skip-ledger.sh` are live on `origin/develop`, and `develop-gate` there sources the pin twice. Gate run `33112404579` (`pull_request`, success) stamped `b0a9dd9…` with `VolOrderToPanopticTokenId.t.sol` 10/10 and the suite at 271 / 0 / 1 skipped. Criterion 3 proven: two pushes to `develop` with the workflow present (`e6276f2`, `62d35b2`) produced ZERO push-build runs. CI-05/06/07 ticked; issue #58 closed. **Phase 1 remains independently PAUSED at 2 of 6 (issue #57 OPEN) and resumes at plan 01-03 — its first action should be bringing `feat/red-diff-scaffold` up to `origin/develop`, since a branch that has not inherited `push-build.yml` gets no push builds.**
Last activity: 2026-08-27 — Phase 1.1 merged. The pinned toolchain is now stamped on BOTH CI paths, every push to a non-`develop` branch compiles unattended, and pushes to `develop` provably do not. The phase's checkpoint also corrected a long-standing false belief about `develop-gate`'s approval step.

Progress: [███████░░░] 67%  (8 of 12 plans: Phase 1.1 complete at 6/6, Phase 1 paused at 2/6)

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: 5.9 min
- Total execution time: 0.68 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| Phase 1 | 2/6 | 6 min | 3 min |
| Phase 1.1 | 5/6 | 35 min | 7 min |

**Per-plan:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 3min | 3 tasks | 2 files |
| Phase 01 P02 | 3min | 1 tasks | 1 files |
| Phase 01.1 P01 | 2min | 3 tasks | 2 files |
| Phase 01.1 P02 | 2min | 2 tasks | 2 files |
| Phase 01.1 P03 | 6min | 3 tasks | 2 files |
| Phase 01.1 P04 | 18min | 2 tasks | 3 files |
| Phase 01.1 P05 | 7min | 2 tasks | 5 files |

**Recent Trend:**
- Last 5 plans: 2 min, 2 min, 6 min, 18 min, 7 min
- Trend: up, and the shape is explained rather than alarming — 01.1-04 (18 min) waited on two real CI
  runs and a maintainer checkpoint; 01.1-05 (7 min) is back to file work plus static proof. Plans that
  touch CI cost wall-clock the moment they need a run (7 data points).

*Updated after each plan completion*

## Accumulated Context

### Decisions

- **[Phase 01.1, plan 06 checkpoint] Criterion 2 is RESTATED, not repaired — Option B, maintainer verbatim.** Shown that `develop-gate`'s environment has no protection rules, the maintainer chose: *"Restate the criterion, merge as-is"* and *"Yes, merge with bypass"*. So criterion 2 is amended to rest on what is actually enforced — `develop`'s required status-check context `gate` plus `required_approving_review_count: 1` — and the `environment:` key is recorded as **documentary**. **The repo configuration is deliberately NOT changed**; no required reviewer was added to the `develop-gate` environment. Consequence to carry forward: **the `gate` job must never be given a `name:`**, because `contexts: ["gate"]` is the branch's only enforced check and a rename would silently un-protect `develop`. Plan 05's insistence on this is confirmed load-bearing rather than stylistic.
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

- [Phase 01.1]: push-build.yml is a SEPARATE unattended workflow (no environment:, no secrets., no API_KEY reaching the job) — verified structurally against the PARSED YAML, not by grep: every occurrence of those tokens is a YAML comment explaining the omission, and GitHub does not evaluate ${{ }} in comments
- [Phase 01.1]: MEASURED on run 33107877073: the cfmm-build runner DOES have egress to raw.githubusercontent.com, flock IS present, and foundryup --install "${FOUNDRY_VERSION#v}" resolves v1.5.1/b0a9dd9 — the pinned install into $HOME/.foundry-pins/$FOUNDRY_VERSION and the commit assertion both went green, closing three of plan 03's four residual unknowns from observation rather than assumption
- [Phase 01.1]: The push build COPIES develop-gate's --skip ledger and seed rather than sharing it (the gate's ledger line may not move), and scripts/check-ci-skip-ledger.sh makes the copy's parity ENFORCED not reviewed — comment lines are stripped first so a comment cannot satisfy it, and a vacuous zero-pattern extraction is red

- [Phase 01.1]: MEASURED on runs 33107877073 + 33109459584 — the pin-keyed install ANSWERS the ROADMAP's persistent-self-hosted open question. `which -a forge` printed `$HOME/.foundry-pins/v1.5.1/bin/forge` AHEAD of `$HOME/.foundry/bin/forge` (which the box already had, listed TWICE on PATH) in both runs; `$HOME/.foundry` was never written to. `foundry-toolchain@v1` would have collided on the first push — that was reasoned during planning and is now observed, with foundryup itself warning "There are multiple binaries with the name 'forge' present in your 'PATH'". Cold install 19 s, warm 0 s via the stamp file. Open question CLOSED BY OBSERVATION.
- [Phase 01.1]: The pin is re-asserted on EVERY run by the STAMP step, not by the install step. Run 2's install step took 0 s and emitted zero output (stamp-file cache hit), so the `grep -qF "$FOUNDRY_COMMIT"` inside the install branch did NOT run — but the stamp step's own identical assertion did, and passed. Anyone editing the stamp step must know it is now the only per-run pin assertion.
- [Phase 01.1]: FIRST CONFIRMED COMPILE in this project's history is run 33109459584 (`fb546e8`, push, SUCCESS): `Ran 74 test suites in 11.21s: 271 tests passed, 0 failed, 1 skipped (272 total)`, with `VolOrderToPanopticTokenId.t.sol` at 10/10 — the regression floor, held in CI for the first time. Against the last recorded local baseline of 252 passed, with a SMALLER skip ledger (3 patterns, seed 4880).
- [Phase 01.1]: `--skip` MATCHES ON FILENAME, so a ledger entry masks more than the file that motivated it. `--skip "*PriceSetterHook*"` had also been excluding `src/modules/protocol_integrations/PriceSetterHook.sol` and `foundry-scripts/PriceSetterHook.s.sol` from the test build; retiring it exposed both to compilation for the first time and they are CLEAN. General hazard of glob-shaped skip ledgers — check what else a pattern catches before adding one.
- [Phase 01.1]: `forge build` deliberately carries NO `--skip`. Run 1 went red on `Error (5005)` linearization in `PriceSetterHook.t.sol:19` — skip-ledger entry #1, predicted verbatim by `develop-gate.yml:55`. The gate had never run a bare `forge build`, so the break was real, known, documented and STRUCTURALLY INVISIBLE to the only CI that existed. Teaching `forge build` the ledger would restore that blindness; the fix was to delete the uncompilable test instead.
- [Phase 01.1]: CHECKPOINT APPROVED (plan 04, verbatim): "remove the PriceSetterHook skip from develop since is no longer there but do not create a worktree for such fix but make it under the current tree. Ther approve" — the unattended-execution tradeoff is ACCEPTED UNMODIFIED (no environment:, no secrets, no approval on push-build.yml). The one requested change was already `12e1fb9` on develop. The `timeout-minutes` headroom question was NOT answered and is NOT treated as answered: 30 min (and the gate's tighter 25) remains comfortable AS OBSERVED and unproven COLD.
- [Phase 01.1]: develop-gate's forge job now resolves the pin and stamps `forge --version` (7591034), with install+stamp `run:` bodies copied BYTE-FOR-BYTE from push-build.yml — inline comments included — so `diff` of the extracted regions is empty. Divergence between the two workflows is now mechanically detectable rather than a matter of reading both files carefully. The plan's own text re-worded those comments; the plan's own acceptance criterion forbade that. Criterion and stated intent won.
- [Phase 01.1]: The pin+stamp steps go BEFORE the submodule/plankc/npm block in BOTH workflows (gate: line 37 vs line 123). A drifted or unavailable toolchain reddens in seconds instead of after ~20 min of setup. Nothing before that point needs forge.
- [Phase 01.1]: "Purely additive" is proven as a diff SHAPE assertion, not a review: `git diff --numstat origin/develop` deleted-field == 0 (`84  0`) plus `git diff | grep '^-' | grep -v '^---'` empty. A reflowed comment fails it as loudly as a deleted job. Precondition: the baseline diff must be EMPTY before the edit — verified — otherwise `84/0` is not attributable to this plan.
- [Phase 01.1]: The ledger-parity guard is deliberately NOT copied into develop-gate. Drift arrives via an edit, an edit arrives via a push, and every push already runs the guard; a second copy buys nothing and widens the diff on the one workflow that must stay reviewable at a glance.
- [Phase 01.1]: TOOLING — `state add-decision` is worse than plan 03 recorded: it REGENERATES the frontmatter from a scrape of the BODY. Probed directly this session: it corrupted `milestone: v1.0 -> v1.8`, forced `status: executing -> paused`, and REVERTED `stopped_at` to the previous plan's value while stripping its quotes — because the body's "Stopped at:" line had not been updated yet. **Consequence: frontmatter edits made BEFORE body edits are silently reverted by any state verb.** It also filed the decision below the "Open by design" block, as previously recorded. Restored from a pre-call backup and hand-edited instead.

**Open by design — owned by phase planning, do not pre-resolve:**

- `VolOrder(T)` wire format: Shock-style tagged vs per-variant layout → **Phase 4**
- ~~Spec transport~~ → **RESOLVED: JSON-RPC**, decided at `evm-spec-bridge` initialization outside Phase 5 (user override, confirmed directly). Phase 5 now *records* it and remains the reference contract for the bridge.
- **STILL OPEN — RPC-02 responsibility split** → **Phase 5**. A strong prior has been sent to `evm_spec_rpc` and accepted by them: guard evaluation is the spec's without exception; protocol well-formedness is the bridge's while domain validation IS guard evaluation; codec generated from one schema; error classification the bridge's, carrying the rejecting guard. Not yet ratified by the user.
- Oracle packaging: new cabal exe vs a mode on `cfmm-scratchpad-exe` → **Phase 6**

### Pending Todos

None yet.

### Blockers/Concerns

- **STANDING RULE — `environment:` in a workflow is NOT evidence of an approval requirement; only the environment's `protection_rules` are.** This was stated wrongly for the whole of Phase 1.1 and the error propagated: the coordinator repeatedly told the maintainer, and a sibling project, that `develop-gate`'s first job was a human approval step, and argued design decisions from it — including this phase's own criterion 2 and the "no double-approval from a push trigger" rationale in `develop-gate.yml`'s comment. The claim was read off the YAML's *intent* and never checked against the API. What caught it was polling `gh api repos/.../actions/runs/<id>/pending_deployments`, getting `[]` where a pause was predicted, and going to `gh api repos/.../environments/develop-gate` for the cause. **Verification rule: to claim an approval gate exists, read `protection_rules` on the environment (and `pending_deployments` on a real run). A workflow key is a request for a gate, not proof of one.** The same reasoning error would recur for `deployment_branch_policy` and for required status checks read from workflow YAML rather than from `branches/<b>/protection`.
- **MEASURED, BLOCKING PHASE 1.1's CRITERION 2 — `develop-gate`'s `environment: develop-gate` ENFORCES NOTHING.** `gh api repos/JMSBPP/cfmm-vol-markets/environments/develop-gate` returns `"protection_rules": []`, `"deployment_branch_policy": null`, `"can_admins_bypass": true`, with `created_at == updated_at == 2026-06-28T21:28:40Z` — the environment has **never been configured since the day it was created**. Consequence: the `approve` job's `environment:` key produces a deployment record and no approval gate. On gate run `33112404579` the `approve` job started **4 s** after the run was created (`20:15:07Z → 20:15:11Z`), completed in 4 s, and `pending_deployments` was `[]` at every poll. **This is PRE-EXISTING and NOT caused by Phase 1.1:** the same pattern holds on gate runs from 2026-08-26, before this phase existed (`33012911523` approve `20:56:17Z → 20:56:21Z`; `33008976085` approve started `20:09:40Z`, +3 s), and plan 05 proved the workflow edit is `+84 / −0`. **What the gate's authority actually rests on:** `develop` branch protection requires the status check context `gate` (`contexts: ["gate"]`, app 15368) and `required_approving_review_count: 1` — but `enforce_admins: false`, so the repo owner can merge past the review. The required `gate` check is real; the *environment approval* is decorative. Phase 1.1's criterion 2 ("keeps its `environment` approval") is therefore a claim about a protection that does not exist, and cannot be ticked as written. **Decision owed to the maintainer:** either configure required reviewers on the `develop-gate` environment (restoring the property the criterion assumes), or restate criterion 2 in terms of the required `gate` status check, which IS enforced. Recorded rather than worked around — the plan explicitly forbids routing around the approval, and this executor did not attempt any self-approval.
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
- **NEVER give the `gate` job a `name:`.** `develop`'s branch protection requires the status-check context `gate`, which binds to the job id. A rename silently un-protects the default branch.
- **`environment:` in a workflow is not an approval gate.** Verify with the environment's `protection_rules` and a run's `pending_deployments` before claiming one exists.

## Session Continuity

Last session: 2026-08-27T20:12:00Z
Stopped at: Completed 01.1-05-PLAN.md (both tasks). Plan 01.1-04 also closed out — its checkpoint was approved.
Resume file: .planning/phases/01.1-ci-feedback-loop/01.1-06-PLAN.md

Next: **Plan 01.1-06 — the PR, the first `develop-gate` run, the merge, and the develop-exclusion
proof.** This is the wave that closes CI-05, CI-06 and CI-07 together, and it is the ONLY thing left
in Phase 1.1.

State it inherits:

- `feat/ci-feedback-loop` is at **`7591034`**, **4 commits ahead of `origin/develop`** (`dddb26b`,
  `bdeecb3`, `fb546e8`, `7591034`) and **NOT pushed**. Plan 06 pushes and opens the PR
  (`gh` needs `-R JMSBPP/cfmm-vol-markets`).
- `develop-gate.yml` now carries the pin+stamp: **+84 / −0** against `origin/develop`, with the
  PR-only trigger, the single `environment: develop-gate` approval on `approve`, the unnamed `gate`
  job's `needs: [approve, forge, plank]`, the 3-entry `--skip` ledger and `--fuzz-seed 4880` all
  proven unmoved by seven static assertions (recorded verbatim in `01.1-05-SUMMARY.md`).
- **Expect `pending_deployments` to be NON-empty** on the gate run — unlike every push-build run so
  far. That is the `environment: develop-gate` approval doing its job, not a fault.
- **Expect the gate's install step to take 0 s and print nothing** (stamp cache hit at
  `$HOME/.foundry-pins/v1.5.1/.installed-b0a9dd9…`, keyed by pin not by workflow). The pin is
  re-asserted by the **stamp** step, which must be green and must show
  `forge Version: 1.5.1-v1.5.1` / `Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`. A silent
  install step is correct, not a step that failed to run.
- Expected gate `forge test`: `271 passed, 0 failed, 1 skipped` across 74 suites, with
  `VolOrderToPanopticTokenId.t.sol` at 10/10. The gate runs `forge test` only — no bare `forge
  build` — so it measures a subset of what the push build measured.
- **CI-05, CI-06 and CI-07 all remain `Pending` in REQUIREMENTS.md.** All three close at plan 06, on
  the gate run's evidence. CI-06's sentence is "every **GATE** run emits the resolved
  `forge --version`" — a workflow file that *would* stamp is not a run that *did*.
- Criterion 3 (pushes to `develop` do NOT trigger the push build) is still unproven and needs the
  merge itself: after the PR merges to `develop`, confirm no `push-build` run appears for that push.

Live loose ends carried forward, neither owned by plan 06:

- Issue #16 was closed at 19:44:12Z with items 2 (seed-dependent width-type fuzz bug, still masked
  behind `*VolRangeWidth*` / `*SpreadTickAssimetryHelper*`) and 3 (gamsdiff runner env) UNADDRESSED
  and untracked in `.planning/`.
- **Cold-runner timeout headroom is UNMEASURED** and the checkpoint response was silent on it.
  Submodules, the plankc `cargo build --release` and the forge compile cache were warm in both
  push-build runs; only the pin install was measured cold (19 s). The gate's `timeout-minutes: 25`
  is tighter than the push build's 30, and plan 06's run will very likely be warm again.

Phase 1 resumes at `01-03-PLAN.md` in the `feat/red-diff-scaffold` worktree once Phase 1.1 merges.
