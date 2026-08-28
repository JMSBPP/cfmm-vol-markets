# Roadmap: Haskell↔Plank Differential Conformance

## Overview

The milestone lands in one direction: make the Haskell executable spec the authoritative oracle
for the Plank `volOrderToTokenId` map, and make disagreement fail the build. It starts by pushing a
compiling, skip-guarded differential test file (nothing to diff against yet), then generalizes
`VolOrder` into the comptime constructor `VolOrder(T)` so a Haskell-equivalent instantiation exists
at all, gives that type a decodable wire format, **designs the RPC/transport architecture itself**,
teaches the Haskell to read that format and answer from outside its process, wires a Solidity
transport to ask it, reconciles the guard sets so the two sides agree on *rejection* as well as on
values, turns the fuzz green, and finally flips `develop-gate` so the test can never silently skip
again.

**The transport is a design problem, not a lookup.** Which transport is appropriate — and why — is
learned through interactive back-and-forth, including how responsibility is delegated between the
Haskell spec service and the Foundry test process. Phase 5 exists for exactly that and owns the
decision; it is not a formality to be short-circuited.

## Conventions (binding for every phase)

- **Phase directory layout:** `.planning/phases/FEATURES/feat-<slug>/` containing
  `<NN>-<NN>-PLAN.md` / `<NN>-<NN>-SUMMARY.md`. Phases are FEATURES. (Requirement PROC-01.)
- **Phases start INLINE:** work happens in the current tree. Do NOT create a per-phase git
  worktree — that rule was retired after Phase 1.1, where a worktree turned out to be the only
  place a needed file existed. A tracking issue on `develop` still applies.
- **CI is the validation gate — and the only build environment:** there is no internal/local
  compilation step. Dependencies and submodules are deliberately left *uninitialized* locally; the CI
  is what syncs, updates and manages them, and the compiler's answer is always read from whether
  `develop-gate` passed. This holds for pushes **and** for PRs. Every success criterion below is
  worded to be verifiable from a gate run. Never report a phase as verified from a local run.
- **Fork → PR:** `d2p-finance/*` is canonical, `JMSBPP/*` is the fork. Changes reach canonical only
  via PR. Phase 6 touches the `spec/` submodule and therefore carries a two-repo cost.
- **Regression floor:** `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` stays green in
  every gate run from Phase 1 onward. The one sanctioned exception is Phase 2's regression
  assessment, which may decide — explicitly, with the user, and *before* the refactor is written —
  that a test tightly coupled to the old `VolOrder` shape is eliminated or rewritten. Coverage lost
  that way is replaced, never merely dropped, and no test is removed or `--skip`-ed to turn a red
  gate green.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: RED Differential Scaffold** - The first clean push: a compiling, skip-guarded `.diff.t.sol` with its doctrine and transport boundary
- [x] **Phase 1.1: CI Feedback Loop** (INSERTED) - push-triggered build so every commit compiles, plus an explicit pinned forge version stamped into every run
- [x] **Phase 2: VolOrder(T) Minimal Instantiation** - `VolOrder` becomes a comptime constructor with today's output bit-identical
- [x] **Phase 2.5: Venue-Tagged Market Key & Payload Widening** (INSERTED) - the key names its venue in the type and proves its poolId against the SFPM; the `FLAG_PANOPTIC` payload widens to 40 bits
- [ ] **Phase 3: VolOrder(T) Rich Instantiation** - The Haskell-shaped payload: 4-tuple of `optionRatio`s plus the `asset` bit
- [ ] **Phase 4: VolOrder(T) Wire Format** - A serialization that carries *which* `T` it is, decodable from the bytes alone
- [ ] **Phase 5: RPC Design & Protocol Skeleton** - The transport decision and the spec-service/test-process responsibility split, proven by a payload-free skeleton
- [ ] **Phase 6: Haskell Spec Oracle** - The spec decodes the wire format and answers `volOrderToTokenId` out-of-process, built test-first
- [ ] **Phase 7: Solidity↔Spec Transport** - `SpecHelper` reaches the oracle and distinguishes rejection from transport failure
- [ ] **Phase 8: Plank Guard Additions** - The three guards Plank lacks: ratio range, per-leg span, tick bound
- [ ] **Phase 9: Guard Parity Assertion** - Revert-vs-return agreement is asserted, and shared guards stay aligned
- [ ] **Phase 10: Passing Differential Test** - `test__fuzz_differential__volOrder` goes green over the fuzzed corpus
- [ ] **Phase 11: develop-gate Enforcement** - Spec in CI, oracle built on the runner, `vm.skip` removed

## Phase Details

### Phase 1: RED Differential Scaffold
**Directory**: `.planning/phases/FEATURES/feat-red-diff-scaffold/`
**Branch**: `feat/red-diff-scaffold`
**Goal**: The differential test exists as a real, compiling, pushed artifact — written against the
assertion it will eventually make, and guarded so it costs the gate nothing until an oracle exists.
**Depends on**: Nothing (first phase)
**Requirements**: RED-01, RED-02, RED-03, RED-04, RED-05, RED-06, PROC-01
**Success Criteria** (what must be TRUE):
  1. `develop-gate` is green on `feat/red-diff-scaffold`, with the forge job compiling
     `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` under `--via-ir` alongside the
     existing structural suite and harness.
  2. The same gate run reports the differential test as **skipped via the wiring probe** — the
     `SpecHelper.readTokenId` stub reverts, the probe reports "not wired", `vm.skip` fires, and the
     branch diff contains **no skip-ledger edit**.
  3. The same gate run still reports `VolOrderToPanopticTokenId.t.sol` green (regression floor held).
  4. The merged tree contains the doctrine header (neither side sacrosanct; divergence is a finding
     about either implementation, adjudicated case by case), the differential discipline (corpora
     **constructed** with `bound`, never filtered with `vm.assume`; every fuzz backed by a non-fuzz
     anchor; non-vacuity asserted), and a written description of the file layout, naming, and
     Solidity↔spec transport boundary that Phases 6–11 extend rather than redesign.
     → **VERIFIED ON THE MERGED TREE** (plan 06, merge `b090b2e`), read with `git show origin/develop:`
     rather than from the branch. All five strings present in
     `VolOrderToPanopticTokenId.diff.t.sol`: `NEITHER SIDE SACROSANCT`, `adjudicated case by case`,
     `never filtered with vm.assume`, `every fuzz names a non-fuzz anchor`,
     `non-vacuity is ASSERTED via a live counter`. **Zero executable `vm.assume` calls**
     (`grep -c 'vm.assume('` → `0`; the four textual hits are the doctrine comment that bans it).
     `notes/DIFFERENTIAL_LAYOUT.md` carries 10 `## ` sections incl. the transport boundary;
     `SpecHelper.sol` carries `SpecOracleNotWired` 3×.
  5. `.planning/phases/FEATURES/feat-red-diff-scaffold/` exists on `develop`, establishing the
     FEATURES layout for the milestone.
     → **VERIFIED ON `origin/develop`** (plan 06). `git ls-tree origin/develop` shows the entry at
     mode **`120000`** → `../01-red-differential-scaffold`, resolving to **6** `01-0*-PLAN.md` files,
     beside `README.md` and the sibling `feat-ci-feedback-loop` symlink.
**Plans**: 6 plans in 6 waves (strictly sequential — each wave's output is the next wave's input)

Plans:
- [x] 01-01-PLAN.md — worktree, tracking issue, and the FEATURES layout committed to `develop` (PROC-01)
- [x] 01-02-PLAN.md — `SpecHelper.sol`: the reverting `volOrderToTokenId` stub, `health()` as the wiring predicate, the external boundary (RED-04)
- [x] 01-03-PLAN.md — `VolOrderToPanopticTokenId.diff.t.sol`: doctrine, discipline, `setUp`-cached wiring probe, three-outcome separation before `assertEq(specTokenId, implTokenId)` (RED-01/02/03/05)
- [x] 01-04-PLAN.md — `notes/DIFFERENTIAL_LAYOUT.md` (10 sections: generated-interface boundary + measured transport constraints, each with its evidence) + the make target (RED-06)
- [x] 01-05-PLAN.md — PR into `develop`, gate run, evidence harvested incl. runner `forge --version` (RED-01/05; has a checkpoint)
- [x] 01-06-PLAN.md — merge to `develop`, verify criteria 4 and 5 against the merged tree, close out

### Phase 1.1: CI Feedback Loop (INSERTED)
**Directory**: `.planning/phases/FEATURES/feat-ci-feedback-loop/`
**Branch**: `feat/ci-feedback-loop`
**Goal**: Close the hole in the CI-is-the-only-build-environment doctrine — make every push compile
immediately and unattended, and make every result attributable to a known toolchain.
**Depends on**: Phase 1 waves 1–2 (the `SpecOracle` seam exists and is pushed).
**Runs BEFORE Phase 1 wave 3**, so waves 3–6 get compile feedback on every push rather than
discovering breakage at the wave-5 PR.
**Why this was inserted**: two gaps found during Phase 1 execution.

*(a) The doctrine had no feedback path.* `develop-gate` is `on: pull_request` only — deliberately, per
its own comment ("PR-only; merges go through PRs, no double-approval from a push trigger"). Combined
with dependencies being intentionally uninitialized locally, that means code can be written, committed
and pushed with **zero compile feedback** until someone opens a PR. `SpecHelper.sol` is on the remote
right now and nothing has ever compiled it. "CI is the only build environment" only holds if CI
actually builds on the event that produces code.

*(b) Foundry is pinned nowhere* — no version key in `foundry.toml`, no `foundry-toolchain` action or
`foundryup` step, no `.foundryrc`/`.tool-versions`. The self-hosted runner is *persistent*, so its
`forge` drifts silently on any `foundryup`. **Four** recorded findings rest on `1.5.1-stable`
`b0a9dd9` specifically: the `json_value_to_token` coercion behaviour, the `vm.rpc` return encoding,
`${...}` alias resolution being lazy, and `try`/`catch` catching a cheatcode revert. v1.8.0 (published
2026-08-27) encodes returns differently.
**Requirements**: CI-05, CI-06, CI-07
**Success Criteria** (what must be TRUE):
  1. A push to a non-`develop` branch triggers a build with **no manual approval**, which initializes
     submodules, builds the Plank toolchain, runs `npm ci`, and runs `forge build` + `forge test`.
     Demonstrated by an actual run on `feat/ci-feedback-loop`.
     → **DEMONSTRATED** by run [`33109459584`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33109459584)
     (`push`, `fb546e8`, **success**): `pending_deployments: []`, job started +3 s, all five
     obligations green including `forge build` AND `forge test`. Awaiting the plan-04 checkpoint.
  2. That workflow is **separate** from `develop-gate`, which keeps its `environment` approval and its
     role as the PR/merge authority — no double-approval, and no push path that can approve a merge.
     → **ESTABLISHED STATICALLY** (plan 05, `7591034`). After the gate gained the pin+stamp, the edit
     is `84` insertions / **`0`** deletions against `origin/develop` and the diff contains no `-`
     line at all. `develop-gate.yml`'s `on:` still parses to exactly
     `{'pull_request': {'branches': ['develop']}}`; `environment:` occurs exactly once (line 14, in
     `approve`); the `gate` job still has no `name:` (branch-protection context string intact) and
     still declares `needs: [approve, forge, plank]`; neither `forge` nor `plank` gained an `if:`,
     which is what would reopen the skipped-jobs-green incident. `push-build.yml` remains
     environment-free and secret-free.
     → **RUN-TIME HALF: FALSIFIED AS WRITTEN, and NOT by this phase.** The first gate run of this phase,
     [`33112404579`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33112404579) (`pull_request`,
     `7591034`, **success**), required **ZERO** approvals: `pending_deployments` was `[]` at every poll and
     the `approve` job ran unattended (`20:15:07Z` created → `20:15:11Z` started → `20:15:15Z` done).
     Cause, read from the API: the `develop-gate` **environment** has `protection_rules: []`,
     `deployment_branch_policy: null`, `can_admins_bypass: true`, and `created_at == updated_at ==
     2026-06-28T21:28:40Z` — it has never been configured. The `environment:` key therefore produces a
     deployment record and **no approval gate**. This is PRE-EXISTING: gate runs from 2026-08-26, before
     this phase existed, show the same unattended `approve` (`33012911523` +4 s, `33008976085` +3 s), and
     plan 05's `+84 / −0` proves the phase did not remove it. **Total approvals for the whole change: 0,
     not the expected 1.** What the gate's authority actually rests on is `develop`'s required status-check
     context `gate` (`contexts: ["gate"]`, app 15368) plus `required_approving_review_count: 1` with
     `enforce_admins: false`. The required check is real; the environment approval is decorative.
     **Criterion 2 cannot be ticked as written** — it needs either a configured reviewer on the
     `develop-gate` environment, or restatement in terms of the required `gate` status check, which IS
     enforced. Maintainer decision; this executor did not attempt any self-approval or config change.
     → **RESOLVED AT PLAN 06'S CHECKPOINT — Option B, criterion RESTATED.** Maintainer, verbatim:
     *"Restate the criterion, merge as-is"* and *"Yes, merge with bypass"*. **Criterion 2 now reads:**
     the push build is a workflow separate from `develop-gate`, and `develop-gate` remains the PR/merge
     authority by virtue of `develop`'s required status-check context `gate` plus
     `required_approving_review_count: 1` — the two protections that are actually enforced. The
     `environment: develop-gate` key on the `approve` job is **documentary**: it records the intent of a
     gate that the environment has never been configured to provide. **The repo configuration was NOT
     changed** and no required reviewer was added. **Load-bearing consequence: the `gate` job must never
     be given a `name:`**, since `contexts: ["gate"]` is the branch's only enforced check and a rename
     would silently un-protect `develop` — plan 05's insistence on this is confirmed necessary, not
     stylistic. On this restatement the criterion is MET: `push-build.yml` is a separate file with no
     `environment:`, no secrets and no ability to satisfy the `gate` context, and the gate's `+84 / −0`
     edit left the `gate` job's `name`-lessness and `needs: [approve, forge, plank]` untouched.
  3. Pushes to `develop` do **not** trigger the push build (merges are the PR gate's job).
     → **PROVEN** (plan 06). Two real pushes to `develop` with `push-build.yml` present at the ref:
     the merge `e6276f2` (`2026-08-27T20:28:51Z`) and the evidence commit `62d35b2`
     (`20:33:15Z`). `gh run list --workflow push-build.yml --branch develop` was `[]` after both
     (`20:29:36Z`, `20:34:44Z`), and `gh run list --branch develop` shows the branch's only run ever
     is a Dependency Graph run from 2026-07-10. The four PRE-merge `[]` readings are recorded in the
     evidence file as explicitly **NOT** proof, since `push-build.yml` was absent from `develop` at
     the time and a workflow that does not exist at a ref cannot run there.
  4. Both workflows resolve an explicit, declared Foundry version rather than the ambient one, and
     each run's log shows the resolved `forge --version` including version and commit SHA.
     → **HALF MET.** *File half:* both workflows now `.`-source `.github/foundry-version` twice
     (install + stamp) with **byte-identical** step bodies — the extracted regions `diff` empty
     (plan 05, `7591034`). *Run half:* proven on the push path only (runs `33107877073` /
     `33109459584`, both `forge 1.5.1-v1.5.1` / `b0a9dd9…`, with `which -a forge` showing the pinned
     binary ahead of the box's own). **No `develop-gate` run exists yet**, so CI-05 and CI-06 stay
     `Pending` until plan 06's PR produces one.
     → **NOW MET ON BOTH PATHS.** Gate run
     [`33112404579`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33112404579) stamped
     `forge Version: 1.5.1-v1.5.1` / `Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2` /
     `Build Timestamp: 2025-12-19T14:07:55.455914129Z`, with `which -a forge` listing
     `/home/jmsbpp/.foundry-pins/v1.5.1/bin/forge` ahead of the box's own — byte-identical to both push
     builds. The install step was a **0-second** pin-keyed cache hit emitting no output (`##[endgroup]` is
     its last line), confirming the cache is keyed by pin and not by workflow, exactly as plan 05
     predicted; the *stamp* step's `grep -qF "$FOUNDRY_COMMIT"` is what re-asserted the pin, and it
     passed. CI-05/CI-06 are now evidence-backed on the gate path; they close with plan 06.
  5. The pinned version is recorded in the repo — not only in workflow YAML — with the reason, citing
     that the transport findings hold at `1.5.1-stable` `b0a9dd9`. Changing the pin is a visible,
     reviewable diff; it cannot happen by someone running `foundryup` on the runner.
  6. The existing suite is unaffected: a run still reports `VolOrderToPanopticTokenId.t.sol` green and
     the `--skip` ledger line is untouched.
     → **Regression half MET, ledger half DEPARTED FROM — deliberately.** Run `33109459584`:
     `VolOrderToPanopticTokenId.t.sol` is `10 passed; 0 failed; 0 skipped`, and the suite is
     `271 tests passed, 0 failed, 1 skipped (272 total)` against the last recorded local baseline of
     252 passed. The ledger line was **not** untouched: a maintainer-authorised cleanup (`fb546e8`,
     outside any plan) deleted the uncompilable `PriceSetterHook.t.sol` + its orphaned `TickCheat.sol`
     and retired that ledger entry, 4 patterns → 3, in **both** workflows with the parity guard green.
     Because `--skip` matches on filename, that entry had also been masking `src/…/PriceSetterHook.sol`
     and `foundry-scripts/PriceSetterHook.s.sol` — both now compile clean. Criterion 6's intent (no
     regression, no widening of the ledger) holds; its letter does not.
     → **CONFIRMED ON THE GATE PATH** (plan 06). Gate run `33112404579`:
     `Suite result: ok. 10 passed; 0 failed; 0 skipped` for `VolOrderToPanopticTokenId.t.sol`, and
     `271 tests passed, 0 failed, 1 skipped` across 74 suites. `bash scripts/check-ci-skip-ledger.sh`
     on the merged `develop` tree exits 0 with `skip-ledger parity OK: 3 patterns, seed 4880`.
**Open questions for planning**:
  - ~~Pinning Foundry on a *persistent self-hosted* runner is not the hosted-container problem —
    `foundry-rs/foundry-toolchain@v1` vs an explicit `foundryup --version`, tool-cache behaviour, and
    collision with the system `forge` already installed there. Do not assume the hosted recipe transfers.~~
    → **CLOSED BY OBSERVATION** (plan 04, `01.1-CI-EVIDENCE.md`). Runs `33107877073` and `33109459584`
    both printed `which -a forge` as `/home/jmsbpp/.foundry-pins/v1.5.1/bin/forge` **ahead of**
    `/home/jmsbpp/.foundry/bin/forge` — the box **did** already have its own forge (listed twice on
    `PATH`), the pinned binary won via the `$GITHUB_PATH` prepend, and `$HOME/.foundry` was never
    written to. The hosted recipe would have collided on the very first push; the collision was real,
    not hypothetical, and foundryup said so itself
    (`There are multiple binaries with the name 'forge' present in your 'PATH'`). All four
    install-mechanism unknowns also answered: runner egress works, `flock` is present, `--install` is
    the right flag, `v1.5.1` resolves to `b0a9dd9…`. Cold install 19 s; warm 0 s via the stamp file,
    with the pin still re-asserted every run by the *stamp* step.
  - Unattended builds on a self-hosted runner execute pushed code without a human in the loop. That is
    the accepted tradeoff for immediacy (approval stays on the PR path), but the workflow should avoid
    exposing secrets it does not need — note `develop-gate`'s forge job passes `API_KEY`.
    → **RESOLVED — the tradeoff was re-affirmed at plan 04's checkpoint and ACCEPTED UNMODIFIED.**
    `pending_deployments` is `[]` on both runs and each started 3 s after its push, so "no human in
    the loop" is measured rather than claimed; shown that, the maintainer asked for no change to
    `push-build.yml` and approved ("…Ther approve", verbatim in `01.1-04-SUMMARY.md`). The workflow
    ships with no `environment:`, no secrets and no approval, as measured. **Still open, because the
    response was silent on it:** whether `timeout-minutes: 30` (and the gate's tighter `25`) has
    headroom on a genuinely COLD runner — submodules, the plankc `cargo build --release` and the
    forge compile cache were warm in both runs; only the pin install was measured cold, at 19 s.
  - ~~Whether the push build should reuse `develop-gate`'s skip ledger or run the full suite.~~
    → Resolved during planning (reuse + parity guard); the ledger is now **3 patterns / seed 4880**
    in both workflows after the `*PriceSetterHook*` entry was retired between the two runs.
**Resolved during planning** (rationale in the plans, not repeated here):
  - **Not** `foundry-rs/foundry-toolchain@v1`. Read from its source: it installs into
    `$HOME/.foundry` (`src/index.ts`: `FOUNDRY_DIR = path.join(os.homedir(), ".foundry")`), which on
    a *persistent* runner is the box's shared foundry dir — so the action would have an unattended
    workflow rewrite the machine's default `forge` on every push, reintroducing the exact drift the
    pin exists to stop. It also runs on `node24`, unverified on this runner. Both workflows instead
    drive the same pinned `foundryup` installer into a pin-keyed `$HOME/.foundry-pins/$VERSION` and
    prepend it to the job's `PATH`: job-scoped, collision-free, installed once per pin, and it beats
    the system `forge` because `$GITHUB_PATH` prepends. `which -a forge` is logged so the collision
    is observable rather than assumed. The residual unknowns (runner egress, `flock`, the pre-existing
    system `forge`) are answered from the real run in plan 04, not asserted.
  - **The push build reuses the ledger and the seed.** Its job is to predict the gate; a different
    surface would go red on pre-existing known-broken families and train everyone to ignore it. The
    duplicated ledger is guarded by `scripts/check-ci-skip-ledger.sh`, which fails the push build if
    the two copies diverge (extracting the copy into one shared place is unavailable — the gate's
    ledger line may not move).
  - **No secrets on the push workflow.** `develop-gate`'s forge job passes `API_KEY`; the unattended
    workflow does not receive it. It runs `--offline` with no mainnet-fork test, and `${...}` in
    `[rpc_endpoints]` is measured to resolve at alias *use*, not at config load.
**Plans**: 6 plans in 6 waves (strictly sequential — each wave's output is the next wave's input)

Plans:
- [x] 01.1-01-PLAN.md — worktree, tracking issue, FEATURES layout for the inserted phase (CI-07)
- [x] 01.1-02-PLAN.md — `.github/foundry-version` + `notes/TOOLCHAIN_PINS.md`: the pin recorded in-repo with its reason (CI-05)
- [x] 01.1-03-PLAN.md — `.github/workflows/push-build.yml` + `scripts/check-ci-skip-ledger.sh`, pushed (the workflow's own first trigger) (CI-06/07)
- [x] 01.1-04-PLAN.md — harvest the actual run into `01.1-CI-EVIDENCE.md`; answers the self-hosted pinning question from observation (CI-06/07; has a checkpoint)
      — task 1 `79602e2` (`01.1-CI-EVIDENCE.md`, harvesting BOTH runs `33107877073` red and
      `33109459584` green); **task 2's blocking human-verify checkpoint APPROVED** by the maintainer
      ("…Ther approve"), recorded verbatim in `01.1-04-SUMMARY.md`. Timeout-headroom question left
      unanswered by the response and NOT treated as answered.
- [x] 01.1-05-PLAN.md — the same pin + stamp in `develop-gate`'s forge job, proven purely additive (CI-05/06)
      — `7591034`, **+84 / −0** against `origin/develop`; install+stamp bodies byte-identical to
      `push-build.yml`'s; trigger, `environment` approval, `gate` contract, ledger and seed all
      proven unmoved. NOT pushed — plan 06 owns the PR and the first gate run.
- [x] 01.1-06-PLAN.md — PR, gate run, merge, and the develop-exclusion proof; close out (CI-05/06/07; has a checkpoint)
      — **COMPLETE.** PR [#59](https://github.com/JMSBPP/cfmm-vol-markets/pull/59) merged as `e6276f2`
      (merge commit, admin bypass). Both workflows fired on the same SHA from different events:
      push-build `33112355047` (`push`, success, `pending_deployments: []`, +3 s) and the first
      develop-gate run of this phase, `33112404579` (`pull_request`, **success**, all four jobs green,
      pin stamped `b0a9dd9…`, `VolOrderToPanopticTokenId.t.sol` 10/10, suite 271 / 0 / 1 skipped).
      Criterion 3 proven across two pushes to `develop`. Issue #58 closed. CI-05/06/07 ticked.
      **Its checkpoint produced the phase's most valuable finding** — `develop-gate` has no approval
      gate and never has — resolved by restating criterion 2, not by changing repo configuration.

### Phase 2: VolOrder(T) Minimal Instantiation
**Directory**: `.planning/phases/FEATURES/feat-volorder-t-minimal/`
**Branch**: `feat/volorder-t-minimal`
**Goal**: `VolOrder` is a comptime type constructor carrying `extra: T`, and instantiating it with the
empty payload reproduces today's behavior exactly — a refactor whose blast radius is *measured and
decided up front* rather than discovered while writing it.
**Depends on**: Phase 1
**Requirements**: VORD-01, VORD-02, VORD-03
**Regression assessment comes first.** Before the refactor is written, enumerate every test and
dependency coupled to the concrete `VolOrder` shape and classify each one: *survives untouched*,
*needs a mechanical call-site update*, or *is tightly coupled to the old format and should be
eliminated*. The elimination candidates are a brainstorm-and-decide step with the user, not a
judgement call made mid-refactor — and the decisions are recorded with their rationale before any
code moves. This assessment is what makes the "no edits" criterion below meaningful rather than
aspirational: it establishes *which* files were expected to be untouched in the first place.
**Success Criteria** (what must be TRUE):
  1. A recorded regression assessment enumerates every test and dependency coupled to the old
     `VolOrder` shape, classifies each into the three buckets above, and carries a user-agreed
     decision plus rationale for every elimination candidate.
     → **VERIFIED ON origin/develop** (plan 05, merge `790c413`): `git show origin/develop:…/02-REGRESSION-ASSESSMENT.md | grep -c '^**Status:** FINAL'` → 1, `grep -c '(02-05 fills)'` → 0, `grep -c 'NONE FOUND (02-04)'` → 1.
  2. `develop-gate` is green on `feat/volorder-t-minimal`: the plank job compiles `VolOrder(T)`
     following the in-repo `Shock(R)` pattern, and the forge job runs the full existing suite.
     → **VERIFIED ON origin/develop** (plan 05, merge `790c413`): gate run 33184231798 green on `790c413^2` = 56b3c4d (source diff to develop 0 bytes); `const VolOrder = fn (comptime T: type) type` → 1, `fn (comptime T: type, vo: VolOrder(T), pool_id: u256)` → 1, `const Extra = fn (comptime T: type) type` → 1; 76 suites / 287 passed / 0 failed / 3 skipped; compile-plank 39 ok.
  3. Every test classified *survives untouched* — including the golden vectors and fuzz cases in
     `VolOrderToPanopticTokenId.t.sol` — passes in that gate run with **no edits to those files**,
     making the minimal instantiation's `tokenId` bit-identical to today's
     `vol_order_to_panoptic_token_id`.
     → **VERIFIED ON origin/develop** (plan 05, merge `790c413`): `git diff b090b2e origin/develop -- test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` → **0 bytes**; that suite `Suite result: ok. 10 passed; 0 failed; 0 skipped` in run 33184231798.
  4. Every eliminated or rewritten test is traceable to a decision from criterion 1. Nothing is
     deleted, weakened or `--skip`-ed merely to make the gate green; a coupled test that would have
     caught a real regression is replaced, not dropped.
     → **VERIFIED ON origin/develop** (plan 05, merge `790c413`): elimination bucket NONE PREDICTED / NONE FOUND; `--diff-filter=D` over `test/` since b090b2e → 0 files; `--skip` ledger on develop still 3 patterns (never widened).
  5. The plank job compiles `vol_order_to_mint`, `position_size_for_target_vega`,
     `vol_order_leg_split` and `VolOrderToPanopticTokenIdHarness.plk` against the minimal
     instantiation, and the differential test still compiles and still skips in the same run
     (Phase 1 state preserved).
     → **VERIFIED ON origin/develop** (plan 05, merge `790c413`): `compile-plank: 39 ok, 0 failed` incl. `OK test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` and `OK test/protocol_integrations/VolOrderMintSizingHarness.plk`; differential still 2× `[SKIP: spec oracle not wired…]` + 2× PASS with a 0-byte diff since b090b2e.
**Plans**: 5 plans in 5 waves (strictly sequential — the toolchain bump must be green on the
unchanged suite before instrumentation, instrumentation before the assessment, the assessment's
checkpoint before the refactor, the refactor's gate run before the merge). **Every plan carries the
EXECUTION GATE: superpowers INLINE executor in the maintainer's session only; `autonomous: false`.**

Plans:
- [x] 02-01-PLAN.md — tracking issue + `feat/volorder-t-minimal` + draft PR; `lib/plank-monorepo` `30f3bdc` → `00c0a1a` (`main`; `feat/arrays` is 404) with the ~15 std moves and NOTHING else; gate GREEN on the unchanged suite = the VORD-02 attribution safeguard (VORD-02)
- [x] 02-02-PLAN.md — `make abi-edge-stamp` + additive push-build step stamping the harness's sha256 + PUSH4 selector set (pre-refactor reference); the ONE-TIME `--skip` probe for `*VolRangeWidth*` / `*SpreadTickAssimetryHelper*`, measured and reverted; a new scoped issue (VORD-02/03)
- [x] 02-03-PLAN.md — `02-REGRESSION-ASSESSMENT.md`: every coupled `.plk`/`.sol` classified with the evidence bar, elimination bucket predicted empty (HARD STOP otherwise), the design recorded (local `none` tag, explicit `comptime T`, `extra: bytes(T)`, `vol_order_base`); blocking maintainer checkpoint (VORD-01/02/03; has a checkpoint)
- [x] 02-04-PLAN.md — (reopened and re-executed 2026-08-28 to `02-REGRESSION-ASSESSMENT.md` §4a; the plan's own edit list was VOID after chunk review) — the refactor: `VolOrder(T)` in 4 files only, `comptime T` on the tokenId path only, harness surface frozen; gate green with 02-01's counts, floor 10/10 untouched, differential still skips, stamp selector set identical (VORD-01/02/03)
- [x] 02-05-PLAN.md — assessment FINAL from the gate evidence, `--skip` decision applied or deferred, PR ready, protection re-measured, merge, criteria verified on `origin/develop`, branch retired with `-d`, STATE/ROADMAP/REQUIREMENTS hand-edited (VORD-01/02/03)

### Phase 2.5: Venue-Tagged Market Key & Payload Widening (INSERTED)
**Directory**: `.planning/phases/FEATURES/feat-volmarketkey/` → `.planning/phases/02.5-volmarketkey/`
**Branch**: `feat/volmarketkey` (cut from `ccdd7bc`) · **Tracking issue**: #68
**Worktree**: `../vol-markets-volmarketkey` — a maintainer-set exception for THIS phase only; the
inline rule remains the default for every other phase (see `AGENTS.md`).
**Goal**: `VolMarketKey(V)` resolves a venue-tagged market key to its venue's pool identity — an
SFPM-verified Panoptic `poolId` for V4 and V3, a registry-verified pool address for Algebra — and the
`FLAG_PANOPTIC` payload carries per-leg `tokenType` plus `vegoid`, each PROVED against an
independently derived value rather than trusted. `MarketId.plk` is retired into it.
**Depends on**: Phase 2
**Runs BEFORE Phase 3**, which is paused: Phase 3 has no directory, no CONTEXT.md and no plans, so
this phase unpicks nothing. Phase 3's criteria and VORD-04/05 are restated against the payload width
THIS phase merges.
**Requirements**: KEY-01, KEY-02, KEY-03, KEY-04, KEY-05, KEY-06, VORD-07
**Spec**: `docs/superpowers/specs/2026-08-28-volmarketkey-and-extra-payload-widening-design.md`
**Why this was inserted**: Phase 3's criteria were written against a 28-bit `FLAG_PANOPTIC` payload
carrying four `optionRatio`s and nothing else. Reading Panoptic's own sources produced findings that
make that payload insufficient and one of its premises false.

*(a) The Panoptic `poolId` is STATEFUL.* Both SFPMs loop
`while (s_poolIdToKey[poolId].tickSpacing != 0) poolId = incrementPoolPattern(poolId)` on collision
and enforce the stored value at mint. A key that derives a `poolId` purely emits tokenIds that revert
at mint whenever a collision occurred, so the identifier must be derived as a CANDIDATE and verified
against the SFPM — a capability Phase 3 has nowhere to put. This also supplies the mechanical
justification `§4a` decision 7 previously lacked: a value depending on SFPM storage cannot be derived
inside a pure builder, so `pool_id` must stay an explicit parameter.

*(b) The payload is short of the map's operands.* `vegoid` (1..255) and per-leg `tokenType` both
belong to the tokenId the Haskell emits; at 28 bits there is room for neither. Widening after Phase 3
has producers would break a merged wire format; widening while it has none is free. 28 was itself the
76 → 28 correction (PR #65 / `b2868cc`, merged one day earlier), so this reopens a recent decision —
deliberately, with maintainer approval, not by drift.
**Success Criteria** (what must be TRUE):
  1. `develop-gate` green: the plank job compiles ALL THREE instantiations —
     `VolMarketKey(V4)`, `(V3)`, `(Algebra)`. Plank only type-checks an INSTANTIATED comptime branch,
     so each must be instantiated, not merely declared (the Phase 2 vacuous-negative-test lesson).
  2. Passing a `VolMarketKey(Algebra)` to the Panoptic arm is a COMPILE error, not a runtime revert —
     demonstrated via `vm.tryFfi`, not asserted in prose — and the negative test MATCHES THE ERROR
     TEXT, not merely a non-zero exit code. A fixture containing a typo also fails to compile, so an
     exit-code-only assertion goes green while proving nothing about the property under test: the
     same vacuity as an unreachable fixture, arriving through a different door. Copy
     `test__unit__nonRegionTagDoesNotCompile` (asserts `_contains(r.stderr, "Extra: T must be a
     region")`), NOT `test__unit__extraFieldsNeedUnwrap` two lines below it, which checks only the
     exit code. **This carries a design obligation:** the Panoptic arm must reject a non-Panoptic
     venue through an explicit guard with its own distinctive message, mirroring `Extra.plk`'s, since
     a bare structural type mismatch yields a generic diagnostic a typo could also produce — cheaper
     to build in than to retrofit. Algebra terminates at a verified pool address because no
     `PanopticFactoryAlgebra` exists; the dead-end is a type-level fact.
  3. `extra_decode` REQUIRES 40 and REJECTS 28, with all three sites moving together
     (`EXTRA_PANOPTIC_BITS`, the `require` in `extra_decode`, and `PANOPTIC_BITS` plus its wrong-len
     revert test), RED-first. Leg `k` at `[8k..8k+7]`: `optionRatio` 7b @`8k`, `tokenType` 1b
     @`8k+7`; `vegoid` 8b @32.
  4. Every guard THIS PHASE OWNS reverts with its own case in the gate: `vegoid == 0`; `ratio_k == 0`;
     a length that is not 40; a reserved flag bit; and `vegoid_payload != pool_id[40..47]` INCLUDING
     the both-zero pair that satisfies the equality and must still revert. That last one is the
     phase's most valuable guard test and it stays here because BOTH its operands are 2.5's —
     `pool_id` is `VolMarketKey`'s SFPM-verified output and the payload is `Extra(T)`'s format, and
     `Extra.plk` imports only `std`, so no `VolOrder` is involved. The two guards that DO need a
     `VolOrder` — `tt_k` against the geometric split, and `vo.rangeWidth.tickSpacing` against
     `key.tick_spacing` — belong to Phase 3 under the seam below.
  5. The `poolId` candidate is verified against the SFPM: an agreeing pair passes, and a
     collision-incremented mismatch reverts with OUR error at build time rather than Panoptic's at
     mint. The two venue patterns are asserted SEPARATELY, not assumed identical —
     V4 = `uint40` of the low bits of the v4 PoolId, V3 = `uint40(uint160(pool) >> 120)`.
  6. `panoptic_asset_bit == 1 -% asset_index` is asserted for BOTH values of `asset_index`, as a
     standalone function of the key (KEY-06). This is a pure key property — no builder, no
     `VolOrder` — which is why F1's inversion, the single NOT whose failure mode is a valid position
     on the WRONG SIDE of the pair, is verified HERE and is where criterion 9's independent check
     belongs. The single-writer property and its atomic commit are VORD-08, delivered by Phase 3,
     because the Layer-1 write it must be atomic with lives in that phase's function.
  7. `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` is still 10/10 green with NO EDITS
     to that file. (`test__unit__phase2MapStillHardcodesRatioOneAndNoAsset` is PHASE 3's to retire —
     it can only be retired once, and a second claim on it invites whichever phase runs later to
     treat the criterion as already satisfied and drop it, which is the exact failure it guards.)
  8. `MarketId.plk` is deleted and its three real consumers migrated — `MarketId.t.sol`,
     `MarketIdHarness.plk`, and the `MarketStateSocket.t.sol:22` comment — with the V4 pattern shown
     to subsume `market_id_from_pool_key`'s keccak rather than duplicating it.
  9. The two findings carrying the most risk are INDEPENDENTLY VERIFIED inside this phase, by
     something other than the two sessions that produced them: (i) F1's `panoptic_asset_bit ==
     1 -% asset_index`, a single NOT whose failure mode is a valid position on the WRONG SIDE of the
     pair, and (ii) the §9.1 zero band, derived jointly and therefore not independently held by
     either author. Both currently rest on exactly two readers.
**Scope seam with Phase 3 — DATA vs BUILDER** (agreed by both sessions 2026-08-28). The deciding
property is whether a thing needs a `VolOrder`, not whether it "needs the builder" — that is the test
that actually sorts the cases. **2.5 delivers** `VolMarketKey(V)` (SFPM-verified `poolId`,
`asset_index`, the derived asset bit) and the 40-bit `Extra(T)` payload FORMAT with every guard whose
operands are the key and the payload alone. `Extra.plk` imports only `std`, so none of that touches
`VolOrder`. **Phase 3 owns every edit to `vol_order_to_panoptic_token_id`**: the dereference, the
per-leg writes, the asset write and its atomic single-writer commit (VORD-08), the two cross-checks
that need a `VolOrder` (`tt_k` vs the geometric split; `vo.rangeWidth.tickSpacing` vs
`key.tick_spacing`, from spec §6.2), and the Phase-2 pin. Each phase is then testable without the
other's code, and neither edits a function the other owns. A second consequence, deliberate: F1's
asset inversion is verified in 2.5 and the §9.1 underflow in 3.5, so criterion 9's two highest-risk
findings land in different phases and neither is checked by the phase that would most want it to pass.

**Two-step review: WAIVED.** The standing rule (Reality Checker + one specialist, in parallel, before
any pre-commit spec is treated as ready) was offered twice with two named candidates — Solidity Smart
Contract Engineer for the mechanics, Blockchain Security Auditor for the silent-wrong-answer modes —
and DECLINED by the maintainer. Recorded here rather than left as an absence, because the consequence
travels: the spec's findings carry only its author's verification and this session's, with no
independent adversarial pass. Criterion 9 is the in-phase substitute, which is cheaper but is not the
same thing.
**Open questions for planning**:
  - **Stale LOCAL checkouts, not a CI gap** (corrected 2026-08-28; an earlier draft of this entry
    claimed the evidence base was unreproducible in CI, which is FALSE). `develop-gate.yml:123-126`
    syncs, inits `lib/panoptic-v2-core` one level, blocks `panoptic-helper` — it contains
    `panoptic-v2-core` and would recurse infinitely — then recursive-inits `lib/`; both the forge and
    plank jobs then run `make plank-toolchain`, which rebuilds the compiler from the pinned submodule
    because the runner's persistent `~/.plank/bin/plank` does not track the pin. So `contracts/` IS
    present in the gate, findings F1–F5 ARE re-checkable there, and 2.5 will compile. What is broken
    is this working tree — a stale 6-file partial checkout for panoptic, an empty worktree for
    plank-monorepo — which is developer ergonomics, not validation. The open question is whether
    cleaning them belongs to this phase, so a developer can re-verify without a scratchpad clone.
    **Standing hazard, not two one-off errors:** neither the spec author's session nor this one can
    build locally, so every structural claim either makes is inference until the gate or a source
    read confirms it. It has already produced two wrong conclusions — a "Panoptic is v4-only" finding
    reasoned from a test-only checkout, and this entry's own retracted CI claim reasoned from a
    broken worktree. That is the argument for attaching the cleanup here rather than deferring it.
  - Decision 6 (registry lookup over CREATE2) has consequences past Phase 3 and is flagged in the
    spec for EXPLICIT maintainer review, not merely carried as ruled.
  - The residual Haskell divergence: the oracle sets `asset = 1` unconditionally and cannot express
    `asset_index == 1`. Key-driven asset shrinks the Phase 7 gap without closing it; whose phase
    reconciles the remainder is unassigned.
  - **`asset == 0` sizing is deferred to Phase 3.5 and carries a known BLOCKER.** `getLiquidityForAmount0`'s
    inner `mulDiv96(hi, lo)` floors to ZERO for every leg below tick ≈ −665455 (a 221,817-tick band,
    25% of the negative range), so Panoptic itself would deploy those legs as empty liquidity. All
    four legs inside it makes `S0 == 0` and divides by zero; some legs inside makes `S0` silently too
    small and `positionSize` too LARGE with no revert. The companion overflow is BOUNDED and cannot
    occur: `term_k ≈ √/(ε·n) ≤ 2^174.3`, ~80 bits of headroom below `u256`.
**Plans**: TBD — the spec is unblocked (review waived, see above) and awaits the maintainer's own
read. Planning starts from `docs/superpowers/specs/2026-08-28-volmarketkey-and-extra-payload-widening-design.md`.

### Phase 3: VolOrder(T) Rich Instantiation
**Directory**: `.planning/phases/FEATURES/feat-volorder-t-rich/`
**Branch**: `feat/volorder-t-rich`
**Goal**: The tokenId builder reads its operands through the `Extra(T)` descriptor and emits the
tokenId the Haskell would emit — closing the "not the same function" gap without breaking the
no-payload path.
**Depends on**: Phase 2
**Requirements**: VORD-04, VORD-05, VORD-08
> **Criteria restated 2026-08-28 to the Phase 2 design of record**
> (`.planning/phases/02-volorder-t-minimal-instantiation/02-REGRESSION-ASSESSMENT.md` §4a). They were
> written when "rich instantiation" meant a SECOND `VolOrder(T)` variant. There is no second variant:
> there is one `VolOrder(T)` per region carrying an `Option(Extra(T))` descriptor, and the operands
> arrive through the `FLAG_PANOPTIC` dereference. **The outcomes below are unchanged** — ratios
> 1..127, `asset = 1` on four legs, the minimal path untouched; only the mechanism is corrected.
> **Scope seam with Phase 2.5 — this phase owns the BUILDER** (agreed 2026-08-28; see Phase 2.5's
> seam paragraph). Every edit to `vol_order_to_panoptic_token_id` is Phase 3's: the dereference, the
> per-leg writes, the asset write and its ATOMIC single-writer commit (**VORD-08**, moved here from
> 2.5 because the commit that satisfies it must be atomic with the Layer-1 write), the two
> cross-checks that need a `VolOrder` — `tt_k` against the geometric i\* split, and
> `vo.rangeWidth.tickSpacing` against `key.tick_spacing` (spec §6.2, a self-review finding that
> exists only because the spec was written out and which nothing in this entry would otherwise
> reproduce) — and `test__unit__phase2MapStillHardcodesRatioOneAndNoAsset`, EXCLUSIVELY. 2.5 delivers
> the key and the payload format; this phase consumes them. The criteria below still describe the
> 28-bit payload and are restated once 2.5 merges.
**Success Criteria** (what must be TRUE):
  > *Restated 2026-08-28 against the MERGED payload, read from merge commit `081bb7e`:
  > `EXTRA_PANOPTIC_BITS = 40`, `PAYLOAD_LEG_STRIDE = 8`, `PAYLOAD_OFF_VEGOID = 32`. The prior
  > criteria described a 28-bit, ratios-only payload and no key. Decisions in `03-CONTEXT.md`.*
  1. `develop-gate` green: the plank job compiles the `FLAG_PANOPTIC` branch of
     `vol_order_to_panoptic_token_id`, which DEREFERENCES `Extra(T)`'s offset to read the 40-bit
     payload word from region `T` — the first code in this project that follows a pointer into a
     region. `pool_id` remains an explicit parameter (§4a decision 7, now also justified by the
     poolId being stateful), and the `asset` bit arrives as a COMPUTED `u256` so the builder stays
     generic over one tag and F1's inversion stays tested in 2.5.
  2. The forge job runs a DIFFERENTIAL against Panoptic's own `TokenId` library — the oracle is
     `@types/TokenId.sol`, already imported and compiling in this suite
     (`DynamicFeeHookE2E.t.sol:17`, `:179`). Expected values are built with
     `TokenId.wrap(0).addPoolId(…).addLeg(…)` and asserted equal to the Plank builder over a
     `bound`-constructed corpus, plus ONE literal anchor tokenId. **Field decoders are supporting
     assertions, not the driver** — a decoder written as `(tid >> (64 + 48*leg + 1)) & 0x7f` is the
     implementation's own arithmetic, so a wrong offset makes test and code wrong together.
  3. The same gate run still reports the no-payload path's golden vectors green:
     `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` 10/10 with **no edits to that file**.
  4. Supplying a `FLAG_PANOPTIC` descriptor changes only the `optionRatio`, `tokenType` and `asset`
     fields — strike, width, pool-id and tickSpacing bits are identical to the no-payload path for
     the same geometry, asserted in the gate.
  5. Every cross-check this phase owns reverts with its own case: `tt_k` disagreeing with the
     geometric i\* split; `vo.rangeWidth.tickSpacing` disagreeing with `key.tick_spacing` (spec §6.2,
     a self-review finding that exists only because the spec was written out); and a descriptor
     offset running PAST `calldatasize()`, which the EVM reads as zeros and 2.5's
     `extra_payload_validate` rejects on the first `ratio_k == 0` — demonstrated by a test that
     deliberately points past the end, not reasoned about.
  6. **VORD-08:** the `asset` bit is written in exactly ONE place. `vol_order_to_mint`'s four
     `panoptic_add_asset` calls are removed in the SAME COMMIT that adds the Layer-1 write, with a
     dedicated test pinning that no double-add occurs. `panoptic_add_asset` is additive, so a
     surviving second write carries into `optionRatio`'s LSB — and the golden vectors cannot catch
     it, because they exercise Layer 1 only.
  7. `test__unit__phase2MapStillHardcodesRatioOneAndNoAsset` is RENAMED to say what it actually
     pins, and its assertions are kept. **Corrected 2026-08-28 during planning:** an earlier draft of
     this criterion claimed the pin "goes RED the moment criterion 2 is met". IT DOES NOT. It calls
     `tokenIdWithNoneExtra` — the NO-PAYLOAD path — and asserts `optionRatio == 1` and `asset == 0`,
     both of which criteria 3 and 4 REQUIRE to stay true. The pin still passes after this phase.
     What becomes false is its NAME: `phase2MapStillHardcodes…` implies "not yet", when after Phase 3
     that is the permanent, intended behaviour of the no-payload path. So it is repurposed, under a
     name saying the no-payload path is UNCHANGED by Phase 3 — criteria 3 and 4's property expressed
     as an executing assertion rather than left to the golden vectors alone. Nothing is deleted.
  8. A successor GAP PIN records what is still NOT Haskell-equivalent after this phase, so Phase 8
     must retire it deliberately in turn: no `|tick| <= uniswapMaxTick` guard, no per-leg span guard
     (both GUARD-01/02/03), and `asset_index == 1` being inexpressible in the oracle, which sets
     `asset = 1` unconditionally. An unrecorded known gap at a phase boundary is this project's
     recurring failure mode.

**Plans**: 3 plans in 3 waves (strictly sequential — each wave's output is the next wave's input)

Plans:
- [ ] 03-01-PLAN.md — RED: the `tokenIdWithPanopticExtra` harness entrypoint and the differential
      test file driving Panoptic's `TokenId` library. First push is RED on purpose (VORD-04/05)
- [ ] 03-02-PLAN.md — GREEN: the `FLAG_PANOPTIC` branch, the asset write and `vol_order_to_mint`'s
      four adds removed IN THE SAME COMMIT (VORD-08), the three no-behaviour-change call sites, the
      pin renamed with assertions intact, and the Phase-8 gap pin (VORD-04/05/08)
- [ ] 03-03-PLAN.md — close out: PR, `develop-gate` (not push-build), live protection re-measurement,
      merge, per-criterion verification against `origin/develop`, branch retired with `-d`

### Phase 4: VolOrder(T) Wire Format
**Directory**: `.planning/phases/FEATURES/feat-volorder-t-wire-format/`
**Branch**: `feat/volorder-t-wire-format`
**Goal**: `VolOrder(T)` serializes to bytes from which a consumer can recover *which* `T` it received
and every field — the hop the Haskell will read on the other side.
**Depends on**: Phase 3
**Owns open decision**: wire format — Shock-style tagged (leading flags byte, present-components-only
payload, length derived from flags and rejected on mismatch) **vs** per-variant layout with the
variant travelling out-of-band. Resolve during phase planning, not before.
**Requirements**: VORD-06
**Success Criteria** (what must be TRUE):
  1. `develop-gate` green with an encode→bytes→decode round-trip test covering **both**
     instantiations, recovering the variant and every field from the bytes alone.
  2. The gate runs a bound-constructed fuzz over the round trip with a non-fuzz anchor and asserted
     non-vacuity, per the Phase 1 discipline.
  3. Malformed input reverts: a byte string whose declared shape and length disagree is rejected, not
     silently decoded — asserted in the gate.
  4. The chosen format is recorded as a resolved decision in `PROJECT.md` (the OPEN row is closed).
**Plans**: TBD

### Phase 5: RPC Design & Protocol Skeleton
**Directory**: `.planning/phases/FEATURES/feat-rpc-design/`
**Branch**: `feat/rpc-design`
**Goal**: State the contract `evm-spec-bridge` must satisfy for this milestone to continue, settle the
division of labour between the Haskell spec service and the Foundry test process, and prove the shape
works with a minimal protocol skeleton carrying no domain payload.
**Depends on**: Phase 4
**MODIFIED — the transport decision was taken outside this phase.** At `evm-spec-bridge`
initialization the user resolved the transport as **JSON-RPC**, knowingly overriding this phase's
ownership of it (`evm_spec_rpc` flagged the conflict before acting; the user confirmed directly).
This phase is therefore no longer the phase that *builds* the transport — it is the **reference
contract for what `evm-spec-bridge` delivers**. RPC-01 records the decision and its rationale rather
than making it. RPC-02 remains genuinely open and owned here.
**Cross-repo**: `evm-spec-bridge` (canonical `d2p-finance/evm-spec-bridge`, `JMSBPP` fork, PR-only)
enters this repo as a **submodule**. It is a Haskell library plus a JSON-RPC server exe, depends on
`cfmm-vol-markets-spec`, and generates the Solidity interface from the same schema as its Haskell
protocol types so the two sides cannot drift silently.
**Requirements**: RPC-01, RPC-02, RPC-03
**Success Criteria** (what must be TRUE):
  1. `PROJECT.md` records the transport as **resolved: JSON-RPC**, with the rationale *and* the fact
     that it was decided at bridge initialization rather than in this phase — the override is visible
     in the record, not smoothed over.
  2. A written responsibility delegation states, for each of wire encoding/decoding, input validation,
     guard evaluation, and error classification, which participant owns it. No responsibility is
     unassigned or shared by default. Binding constraint: **the Foundry test process owns none of
     them** — any semantics it holds is a re-implementation of the spec, which is the failure this
     milestone exists to eliminate. Guard evaluation is the spec's, without exception.
  3. `develop-gate` is green with a minimal protocol skeleton — a health/echo method carrying **no**
     `volOrderToTokenId` payload — exercised end-to-end against the bridge's server, proving the shape
     works before any domain logic depends on it.
  4. The skeleton demonstrates the failure path as well as the success path: an unreachable or
     non-responding service is reported as *transport failure*, distinguishably, in the same run.
  5. The health/echo response carries the **spec commit SHA the bridge was built against**, and a test
     asserts it equals this repo's `spec/` pin — see the skew hazard in Sequencing Notes. A mismatch
     must fail loudly rather than produce a meaningless green.
**Plans**: TBD

### Phase 6: Haskell Spec Oracle
**Directory**: `.planning/phases/FEATURES/feat-spec-oracle-entrypoint/`
**Branch**: `feat/spec-oracle-entrypoint`
**Goal**: The Haskell spec accepts Plank-originated bytes and answers `volOrderToTokenId` from outside
its process, so the spec is drivable without re-constructing inputs on the Haskell side.
**Depends on**: Phase 5
**Method**: the architecture and specification drive the implementation test-first (TDD) — tests for
the entrypoint's contract are written before the entrypoint, on both sides of the fork → PR.
**Two-repo cost**: changes to `spec/` land in `d2p-finance/cfmm-vol-markets-spec` via a `JMSBPP` fork
→ PR; this repo only bumps the submodule pin. Budget the phase for both repos.
**Owns open decision**: oracle packaging — new cabal exe **vs** a mode on the existing Chart/cairo
`cfmm-scratchpad-exe` (heavy to build in CI). Resolve during phase planning.
**Requirements**: SPEC-01, SPEC-02, SPEC-03
**Success Criteria** (what must be TRUE):
  1. A `JMSBPP` → `d2p-finance/cfmm-vol-markets-spec` pull request is merged, and its own PR checks
     are green including a test that decodes checked-in **Plank-produced** wire vectors into the
     spec's `VolOrder` + extra payload without modifying the spec's own model.
  2. The upstream PR checks also show the external entrypoint invoked out-of-process on those vectors
     returning the spec's `tokenId`, and returning a *rejection* (not a crash) for guard-violating
     vectors.
  3. `develop-gate` is green on the branch that bumps the `spec/` submodule pin to the merged commit;
     the differential path remains skip-guarded on the runner (spec is still not checked out there).
  4. The oracle packaging choice is recorded as a resolved decision in `PROJECT.md`.
**Plans**: TBD

### Phase 7: Solidity↔Spec Transport
**Directory**: `.planning/phases/FEATURES/feat-spec-transport/`
**Branch**: `feat/spec-transport`
**Goal**: `SpecHelper` stops being a stub — a Foundry test can obtain the spec's answer for an
arbitrary `(VolOrder(T), poolId)`, and can tell "the spec said no" apart from "the transport broke".
**Depends on**: Phase 6
**Inherits**: the JSON-RPC transport, the responsibility delegation fixed in Phase 5, and the protocol
skeleton proven there. This phase implements against those, it does not revisit them.
**Generated interface, not hand-written.** `SpecHelper` implements the Solidity interface **generated
by `evm-spec-bridge`** from the same schema as its Haskell protocol types. Phase 1's `SpecHelper.sol`
is a deliberately minimal stub whose boundary is documented as provisional precisely so this phase
adopts the generated interface rather than redesigning the seam (RED-06).
**Requirements**: XPORT-01, XPORT-02
**Success Criteria** (what must be TRUE):
  1. `develop-gate` green on `feat/spec-transport`: `SpecHelper.readTokenId(…)` is implemented against
     the bridge's **generated** Solidity interface and the Phase 4 wire format, and the wiring probe
     still governs execution on the runner. No hand-written restatement of the protocol types exists
     in `test/` — drift is prevented by construction, not by review.
  2. The transport returns three distinguishable outcomes — spec success with a `tokenId`, spec
     rejection with the rejecting guard identifiable, and transport failure — and a test asserts they
     are never conflated.
  3. The wiring probe reports "oracle unreachable" as *transport failure*, not as spec rejection, so a
     broken oracle can never masquerade as agreement.
  4. The implementation matches Phase 5's responsibility delegation — the test process does not
     take on validation or guard evaluation the spec service was assigned, or vice versa.
**Plans**: TBD

### Phase 8: Plank Guard Additions
**Directory**: `.planning/phases/FEATURES/feat-plank-guards/`
**Branch**: `feat/plank-guards`
**Goal**: Plank rejects the inputs the Haskell rejects — the three checks the on-chain map currently
does not perform at all.
**Depends on**: Phase 7
**Requirements**: GUARD-01, GUARD-02, GUARD-03
**Success Criteria** (what must be TRUE):
  1. `develop-gate` green: the forge job shows `optionRatio` outside `1..127` reverting on the Plank
     side with the same acceptance boundary the spec uses (127 accepted, 128 and 0 rejected).
  2. The gate shows per-leg `span < Δ` reverting, and `|tick| > uniswapMaxTick` reverting, each with
     a non-fuzz anchor at the boundary plus a bound-constructed fuzz corpus and asserted non-vacuity.
  3. The same gate run still reports `VolOrderToPanopticTokenId.t.sol` green — no input the existing
     suite covers newly reverts.
  4. Each new guard reverts with a distinct, named error so the differential test can report *which*
     guard fired.
**Plans**: TBD

### Phase 9: Guard Parity Assertion
**Directory**: `.planning/phases/FEATURES/feat-guard-parity/`
**Branch**: `feat/guard-parity`
**Goal**: Rejection agreement becomes an assertion rather than an assumption — the two sides are
compared on *whether* they revert, not only on what they return.
**Depends on**: Phase 8
**Requirements**: GUARD-04, GUARD-05
**Success Criteria** (what must be TRUE):
  1. `develop-gate` green with a parity test showing the already-shared guards — each side of `i*`
     ≥ 2Δ, leg width < 4096 — behaving identically to their pre-refactor behavior on the existing
     corpus.
  2. The differential harness asserts revert-vs-return agreement for every input: one side reverting
     while the other returns is a **failure**, reported with the input and which side rejected.
  3. The parity assertion is proven non-vacuous by a deliberately divergent fixture that makes it fail
     before it is corrected, with the red run and the green run both recorded on the branch.
  4. The regression floor and the Phase 1 skip discipline are both intact in the same gate run.
**Plans**: TBD

### Phase 10: Passing Differential Test
**Directory**: `.planning/phases/FEATURES/feat-diff-test-green/`
**Branch**: `feat/diff-test-green`
**Goal**: The fuzz that has been written-but-skipped since Phase 1 actually runs against the oracle
and agrees.
**Depends on**: Phase 9
**Sequencing note**: this phase's terminal proof is Phase 11's CI-03. Until `develop-gate` checks out
and builds the spec, the gate can only confirm the test compiles and skips on the runner; agreement is
not a validated claim until Phase 11 executes it in CI.
**Requirements**: DIFF-01, DIFF-02
**Success Criteria** (what must be TRUE):
  1. `test__fuzz_differential__volOrder` asserts `assertEq(specTokenId, implTokenId)` over a
     bound-constructed corpus of `(VolOrder, poolId, OptionRatio[4])`, with a non-fuzz anchor case and
     asserted non-vacuity, and passes wherever the oracle is reachable.
  2. The corpus exercises the divergence-prone geometry named in `PROJECT.md`: leg splits, negative
     ticks, and each guard boundary — asserted by coverage counters, not assumed.
  3. `develop-gate` is green on the branch and still reports `VolOrderToPanopticTokenId.t.sol` green
     (DIFF-02 regression floor).
  4. A divergence fails the test with a message naming the offending input, both `tokenId`s, and the
     differing field.
**Plans**: TBD

### Phase 11: develop-gate Enforcement
**Directory**: `.planning/phases/FEATURES/feat-ci-enforcement/`
**Branch**: `feat/ci-enforcement`
**Goal**: The gate itself proves the core value — a fuzzed input on which Haskell and Plank disagree
fails the build, with no silent-skip path left.
**Depends on**: Phase 10
**Requirements**: CI-01, CI-02, CI-03, CI-04
**Success Criteria** (what must be TRUE):
  1. A `develop-gate` run shows the `spec/` submodule checked out on the self-hosted runner (the
     `submodules: false` / `lib`-only init is replaced) and the Haskell oracle build step succeeding
     with GHC/cabal confirmed or provisioned on the runner.
  2. The same run reports `test__fuzz_differential__volOrder` as **passed, not skipped**, with its
     non-vacuity counter proving cases were actually compared.
  3. The `vm.skip` wiring guard from RED-05 is absent from the diff test on `develop`, and a
     deliberately unreachable oracle makes `develop-gate` **red** rather than green-with-a-skip —
     demonstrated once on the branch.
  4. A deliberately divergent input makes `develop-gate` fail, closing the milestone's core value:
     a fuzzed input producing a different `tokenId` in Haskell than in Plank fails the build.
**Plans**: TBD

## Sequencing Notes

- The order RED → VORD → RPC → SPEC/XPORT → GUARD → DIFF → CI is a deliberate project constraint, not a
  derived convenience. Phase 1 ships first specifically so the differential file exists and pushes
  clean before there is anything to diff against; Phases 2–4 are the blocking prerequisite refactor;
  and Phase 5 settles how the two sides talk before Phase 6 gives them something to say.
- **The CI tension is no longer merely "accepted" — the JSON-RPC decision escalated it.** The original
  framing was that CI-01/CI-02 (spec on the runner) make Phases 6–10 gate-observable while sitting in
  Phase 11, absorbed by the RED-05 wiring probe. That framing **no longer holds**: RPC-03 requires the
  protocol skeleton be "exercised end-to-end over the chosen transport", and a *service* transport
  means the self-hosted runner must build **and run** a long-lived Haskell process for **Phase 5
  itself** to be gate-observable. CI-01/CI-02 are therefore a prerequisite for Phase 5, not Phase 11.
  Expect to pull them forward via `/gsd:insert-phase`; do not treat the skip-guard as covering this.
  Compounding unknowns: GHC/cabal on the self-hosted `cfmm-build` runner is still unverified (present
  on the dev machine at GHC 9.10.3 / cabal 3.16.1.0), the gate currently checks out no `spec/` at all,
  and a persistent self-hosted runner adds service-ready/test-start races, port collisions and leaked
  processes surviving between runs.
- **Spec-version skew is a correctness hazard, not a build hazard.** `evm-spec-bridge` depends on
  `cfmm-vol-markets-spec`, and this repo pins `spec/` directly — two paths to the oracle. Nothing
  fails if they diverge, which is exactly what makes it dangerous: the differential test would compare
  Plank against a *different spec version than the roadmap believes is the oracle*, and stay green.
  A false green here is worse than a red, because the milestone's whole premise is that disagreement
  fails the build. Mitigation is mandatory, not optional — the bridge reports the spec commit SHA it
  was built against in the health/echo response (Phase 5 criterion 5) and a test asserts it equals the
  `spec/` pin. Preferred topology if the bridge can support it: pin only the bridge and let it be the
  single authority on the spec version, eliminating the second path entirely.
- Two decisions stay open by design and are owned by phase planning: wire format (Phase 4) and oracle
  packaging (Phase 6). Do not pre-resolve them. Transport is **resolved (JSON-RPC)**, decided outside
  Phase 5 at bridge initialization. RPC-02 — the responsibility split — remains open and owned by
  Phase 5.

## Progress

**Execution Order:** 1 (waves 1-2) → **1.1** → 1 (waves 3-6) → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. RED Differential Scaffold | 6/6 | Complete | 2026-08-27 |
| 1.1 CI Feedback Loop (INSERTED) | 6/6 | Complete | - |
| 2. VolOrder(T) Minimal Instantiation | 5/5 | Complete | 2026-08-28 |
| 3. VolOrder(T) Rich Instantiation | 0/TBD | Not started | - |
| 4. VolOrder(T) Wire Format | 0/TBD | Not started | - |
| 5. RPC Design & Protocol Skeleton | 0/TBD | Not started | - |
| 6. Haskell Spec Oracle | 0/TBD | Not started | - |
| 7. Solidity↔Spec Transport | 0/TBD | Not started | - |
| 8. Plank Guard Additions | 0/TBD | Not started | - |
| 9. Guard Parity Assertion | 0/TBD | Not started | - |
| 10. Passing Differential Test | 0/TBD | Not started | - |
| 11. develop-gate Enforcement | 0/TBD | Not started | - |

## Requirement Coverage

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | RED-01, RED-02, RED-03, RED-04, RED-05, RED-06, PROC-01 | 7 |
| 1.1 | CI-05, CI-06, CI-07 | 3 |
| 2 | VORD-01, VORD-02, VORD-03 | 3 |
| 3 | VORD-04, VORD-05 | 2 |
| 4 | VORD-06 | 1 |
| 5 | RPC-01, RPC-02, RPC-03 | 3 |
| 6 | SPEC-01, SPEC-02, SPEC-03 | 3 |
| 7 | XPORT-01, XPORT-02 | 2 |
| 8 | GUARD-01, GUARD-02, GUARD-03 | 3 |
| 9 | GUARD-04, GUARD-05 | 2 |
| 10 | DIFF-01, DIFF-02 | 2 |
| 11 | CI-01, CI-02, CI-03, CI-04 | 4 |
| **Total** | | **35 / 35** |

No orphaned requirements. No requirement mapped to more than one phase.

---
*Roadmap created: 2026-08-27*
