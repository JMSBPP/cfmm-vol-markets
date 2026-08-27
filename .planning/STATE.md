---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 5
status: executing
stopped_at: "Completed 01-05-PLAN.md tasks 1-2; AT THE BLOCKING CHECKPOINT (task 3). PR #60 (feat/red-diff-scaffold -> develop) is OPEN and develop-gate run `33123496782` on `8f01abf` is GREEN on all four jobs: approve/forge/plank/gate all success, `gate` check `pass` on the PR. The two differential tests SKIP on the probe's own reason string, both evidence tests PASS, the regression floor holds 10/10, suite 273/0/3/276 byte-identical to push-build `33117651701`, runner stamped forge 1.5.1 / `b0a9dd9`. `git diff develop..HEAD -- .github/` is 0 bytes. THE FINDING: `pending_deployments` returned `[]` and `approve` completed unattended in 2s -- the corrected claim about the develop-gate environment is now confirmed on a LIVE run, not just from the API. Evidence at `01-05-GATE-EVIDENCE.md` (`c4dcd67`). AWAITING the maintainer's resume signal; 01-06 must not merge until then."
last_updated: "2026-08-27T22:50:00.000Z"
last_activity: "2026-08-27 -- Phase 1 met the only build environment that can prove its first three criteria. PR #60 opened, develop-gate run 33123496782 green, evidence harvested verbatim from the forge job log. Two plan facts were stale and were corrected rather than quoted: the skip ledger is three patterns not four, and the PR is 13 files not 4 (planning artifacts ride the branch under the inline-tree workflow) -- the SOURCE diff is exactly the four named files."
progress:
  total_phases: 12
  completed_phases: 0
  total_plans: 12
  completed_plans: 10
  percent: 83
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-27)

**Core value:** A fuzzed input that produces a different `tokenId` in Haskell than in Plank must fail the build.
**Current focus:** Phase 1 — RED Differential Scaffold, plan 5 of 6 complete, **halted at the 01-05 checkpoint** (Phase 1.1 merged)

## Current Position

Phase: 1 of 12 (RED Differential Scaffold) — RESUMED after Phase 1.1 merged
Plan: 5 of 6 in current phase
Current Plan: 5
Total Plans in Phase: 6
Status: **PHASE 1 plan 01-05 TASKS 1-2 COMPLETE — HALTED AT THE BLOCKING CHECKPOINT (task 3).** PR [#60](https://github.com/JMSBPP/cfmm-vol-markets/pull/60) is OPEN, `feat/red-diff-scaffold` → `develop` on the JMSBPP fork, referencing tracking issue #57. **`develop-gate` run [`33123496782`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33123496782) on `8f01abf` is GREEN**: approve/forge/plank/gate all `success`, and the sole required check `gate` is `pass` on the PR. From the forge job log: the two differential tests report `[SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05)...]`, both evidence tests report `[PASS]` (so the file is provably not inert), `VolOrderToPanopticTokenIdTest` holds `Suite result: ok. 10 passed; 0 failed; 0 skipped`, and the whole suite is `273 passed, 0 failed, 3 skipped (276)` — byte-identical to push-build `33117651701`. Runner stamped `forge Version: 1.5.1-v1.5.1` / `Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`. `git diff develop..HEAD -- .github/` is **0 bytes**; so is the regression-floor file's diff. **Phase 1 criteria 1, 2 and 3 are established with citable evidence** at `.planning/phases/01-red-differential-scaffold/01-05-GATE-EVIDENCE.md` (`c4dcd67`). NOTHING IS MERGED. Next: the maintainer's resume signal, then plan 01-06 (merge, verify criteria 4-5 on the merged tree, close #57).
Last activity: 2026-08-27 — The scaffold met the gate. The run also CONFIRMED, on live data, the correction made to this plan before execution: `pending_deployments` returned `[]` and the `approve` job ran `22:41:30Z → 22:41:32Z` unattended. No approval was requested, none was given, and none is reported.

Progress: [████████░░] 83%  (10 of 12 plans: Phase 1.1 complete at 6/6, Phase 1 at 5/6)

## Performance Metrics

**Velocity:**
- Total plans completed: 9
- Average duration: 8.3 min
- Total execution time: 1.25 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| Phase 1 | 4/6 | 40 min | 10.0 min |
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
| Phase 01 P04 | 23min | 2 tasks | 2 files |
| Phase 01 P05 | 11min | 2 tasks | 3 files |

**Recent Trend:**
- Last 5 plans: 6 min, 18 min, 7 min, 23 min, 11 min
- Trend: up, and the shape is still explained rather than alarming — 01.1-04 (18 min) waited on two
  real CI runs and a maintainer checkpoint; 01-04 (23 min) wrote a 325-line binding document from
  fifteen recorded measurements and then waited on one CI run. Plans that touch CI cost wall-clock the
  moment they need a run; plans that write binding prose cost reading time (8 data points).

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
- [Phase 01]: RED-06 is satisfied by notes/DIFFERENTIAL_LAYOUT.md, not a .planning/ doc — SpecHelper.sol and the diff test already cite that path, and notes/ is this repo's binding-spec directory (DATA_CONTRACT.md, UNITS_AND_SCALES.md, TOOLCHAIN_PINS.md)
- [Phase 01]: Every transport constraint in DIFFERENTIAL_LAYOUT.md carries the MEASUREMENT that produced it — a rule with its evidence attached survives, a bare rule gets 'simplified' away, and each of these simplified away reintroduces a false green
- [Phase 01]: eth_rpc_timeout is NAMED in DIFFERENTIAL_LAYOUT.md as a knob that does NOT reach vm.rpc, overriding an acceptance criterion that forbade the token. Naming the key a future engineer would reach for is the whole value; the criterion's intent (record no USABLE knob) is met
- [Phase 01]: The 'Foundry is UNPINNED' open risk is recorded as CLOSED-by-Phase-1.1, not copied forward. A binding document must not carry a stale risk about the property its other claims depend on
- [Phase 01]: Phase 1 stub REVERTS (SpecOracleNotWired) rather than returning a zero struct — fail-safe, not fail-open. Phase 7's real impl RETURNS the tagged struct and must not revert (GUARD-05)
- [Phase 01]: CONFIRMED ON A LIVE GATE RUN (`33123496782`, PR #60) — the `develop-gate` environment gates NOTHING. `pending_deployments` returned `[]` and the `approve` job ran `22:41:30Z → 22:41:32Z` unattended. The plan's assertion that `approve` "forces exactly one approval BEFORE untrusted code runs" was corrected in place BEFORE execution from the Phase 1.1 API measurement, and this run turns that correction from an API reading into an observation on the actual event type (`pull_request`) the claim was made about. The standing rule holds: a workflow `environment:` key is a REQUEST for a gate, not proof of one.
- [Phase 01]: Phase 1 criteria 1-3 are PROVEN on `develop-gate` run `33123496782` (`8f01abf`), not on push-build. The differential compiles under `--via-ir`, its two differential tests SKIP on the probe's own reason string while both evidence tests PASS (so an inert file cannot hide behind "everything skipped"), the regression floor holds 10/10, and `git diff develop..HEAD -- .github/` is 0 bytes — no skip-ledger entry was bought. Evidence quoted verbatim in `01-05-GATE-EVIDENCE.md`.
- [Phase 01]: The gate `--skip` ledger is THREE patterns, not the four every Phase 1 plan document quotes. `*PriceSetterHook*` was retired by Phase 1.1 (`12e1fb9`). Plan text describing CI is stale the moment CI changes; quote the workflow file, never the plan. Quoting the plan here would have put a fabricated line in an evidence file.
- [Phase 01]: The PR body states the SOURCE diff is four files AND names the nine planning artifacts riding the branch, rather than repeating the plan's "4 files" claim. Under the inline-tree workflow `gh pr view --json files` returns 13; a reviewer opening the Files-changed tab would have caught the literal claim as false in ten seconds. State the shape that is true, not the shape the plan predicted.
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
- **CLOSED 2026-08-27 (Phase 1.1 / CI-05) — the "Foundry is UNPINNED" risk no longer holds; do not carry it forward.** It was true as written (no version key in `foundry.toml`, no `foundryup` step in `develop-gate`, no `.foundryrc`/`.tool-versions`) and every clause is now false: `.github/foundry-version` pins the release, the commit and the foundryup INSTALLER commit; both workflows install into `$HOME/.foundry-pins/$FOUNDRY_VERSION`, prepend it to `PATH`, and FAIL the run unless `forge --version` contains `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`; and `notes/TOOLCHAIN_PINS.md` records why. Observed on push-build run `33117651701`: `forge Version: 1.5.1-v1.5.1` / `Commit SHA: b0a9dd9...`. The `/gsd:insert-phase` candidacy this entry proposed IS the insertion that happened. **The residual that replaces it:** a pin BUMP silently invalidates every transport measurement recorded here and in `notes/DIFFERENTIAL_LAYOUT.md`; `notes/TOOLCHAIN_PINS.md` §6 makes re-measurement part of the bump, and the Phase 5 (RPC-03) coercion-conformance fixture is the layer that turns a missed re-measurement into a named red. Kept rather than deleted because plan 01-04's own PLAN.md mandated the stale version as live content — the next planner writing from this file must see that it was retired.
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

- **Phases start INLINE, in the current tree — no per-phase worktree** (retired after Phase 1.1). A tracking issue on `develop` still applies.
- CI (`develop-gate`) is the sole validation gate. Never report work as verified from a local build or local `forge test`.
- Regression floor: `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` stays green in every gate run.
- **NEVER give the `gate` job a `name:`.** `develop`'s branch protection requires the status-check context `gate`, which binds to the job id. A rename silently un-protects the default branch.
- **`environment:` in a workflow is not an approval gate.** Verify with the environment's `protection_rules` and a run's `pending_deployments` before claiming one exists.

## Session Continuity

Last session: 2026-08-27T22:50:00Z
Stopped at: **01-05 task 3 — the BLOCKING CHECKPOINT.** Tasks 1 and 2 are complete and committed
(`c4dcd67`). PR #60 is OPEN and green; NOTHING IS MERGED.
Resume file: .planning/phases/01-red-differential-scaffold/01-05-PLAN.md (task 3)

Next: **Awaiting the maintainer's resume signal on the 01-05 checkpoint.** On approval, plan
01-06 merges PR #60 into `develop`, verifies criteria 4 and 5 against the merged tree, and closes
tracking issue #57.

State it inherits:

- **PR [#60](https://github.com/JMSBPP/cfmm-vol-markets/pull/60)** — `feat/red-diff-scaffold` →
  `develop` on the JMSBPP fork, OPEN, referencing #57 via `Closes #57`.
- **`develop-gate` run [`33123496782`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33123496782)**
  on `8f01abf` — approve/forge/plank/gate all `success`; the required `gate` check is `pass`.
  Evidence quoted verbatim in `01-05-GATE-EVIDENCE.md`.
- The branch has advanced past `8f01abf` with planning-only commits (`c4dcd67` and this plan's
  metadata commit). **Those retrigger `develop-gate`, and 01-06 must confirm the run on the
  FINAL head SHA is green before merging** — the required check binds to the head commit, and no
  source file changed, so a re-run is expected to be green for the same reasons.
- **Do NOT commit any `lib/*` submodule.** Seven are checked out at NON-pinned commits in the
  working tree from an earlier local `forge test` attempt. Also not ours: `.planning/config.json`,
  `offchain`, `spec`, `src/modules/premium/DynamicFeeMod.plk`, `TODO.md`,
  `docs/superpowers/specs/2026-08-26-*.md`. Name every file on every `git add`.
- **RED-01…RED-06 and PROC-01 are already ticked** in `REQUIREMENTS.md` and in the ROADMAP plan
  list. 01-06 must NOT re-tick them. The `deferred-items.md` entry that asked for it was cleared
  by `3d56870`.
- The merge will need the branch-protection bypass (`required_approving_review_count: 1`,
  `enforce_admins: false`) — the same path Phase 1.1 took, with the maintainer's prior consent
  recorded in the Decisions section. Ask; do not assume it carries over.
- `gh` needs `-R JMSBPP/cfmm-vol-markets` (two remotes). Never open or push anything against
  `d2p-finance`.
