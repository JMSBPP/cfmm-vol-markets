---
phase: 01-red-differential-scaffold
plan: 05
subsystem: ci
tags: [github-actions, develop-gate, pull-request, differential-testing, evidence, foundry]

# Dependency graph
requires:
  - phase: 01-03
    provides: "VolOrderToPanopticTokenId.diff.t.sol — the four test functions whose SKIP/PASS pattern this run observes"
  - phase: 01-04
    provides: "notes/DIFFERENTIAL_LAYOUT.md + the make target — the last two source files in the four-file diff this PR opens"
  - phase: 01.1
    provides: ".github/foundry-version + the stamp step — without them this run's forge version would be UNDETERMINED and the result unattributable to a toolchain"
provides:
  - "PR JMSBPP/cfmm-vol-markets#60 — feat/red-diff-scaffold into develop, referencing tracking issue #57"
  - "develop-gate run 33123496782 on 8f01abf — the first gate run this branch has ever had; approve/forge/plank/gate all success"
  - "01-05-GATE-EVIDENCE.md — Phase 1 criteria 1, 2 and 3 established from quoted gate-log lines, with the runner's forge commit stamped and five anomalies recorded"
affects: [01-06, phase-05-rpc-design, phase-07-spec-transport, phase-11-ci-enforcement]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Gate evidence quotes log lines verbatim from `gh run view --log --job`, never paraphrase"
    - "Every gate-result claim is stamped with the runner's resolved forge commit"

key-files:
  created:
    - .planning/phases/01-red-differential-scaffold/01-05-GATE-EVIDENCE.md
  modified:
    - .planning/STATE.md
    - .planning/ROADMAP.md

key-decisions:
  - "The PR body states the SOURCE diff is four files AND names the nine planning artifacts riding the branch, rather than claiming a four-file PR — the inline-tree workflow makes the literal four-file claim false and a reviewer would catch it immediately"
  - "No approval was sought or performed on the develop-gate environment: pending_deployments was [] and the approve job completed unattended in 2s, confirming the STATE.md measurement on a live run rather than assuming it"
  - "The evidence file and this summary are committed on feat/red-diff-scaffold, not pushed straight to develop — phases run INLINE now, and 01-06 merges the branch"

patterns-established:
  - "A gate run's `approve` job duration is itself evidence about whether an approval gate exists: 2s unattended is a measurement, not an assumption"
  - "Anomalies are recorded even when the run is green — a stale workflow comment and a shrunken skip ledger are findings, not noise"

requirements-completed: []

# Metrics
duration: 11min
completed: 2026-08-27
---

# Phase 1 Plan 05: PR, Gate Run and Evidence Harvest Summary

**PR #60 is open into `develop` and `develop-gate` run `33123496782` came back green on all four
jobs — the two differential tests SKIP on the wiring probe's own reason string, both evidence tests
PASS so the file is provably not inert, the regression floor holds 10/10, and `.github/` is
byte-identical to `develop` — making Phase 1 criteria 1, 2 and 3 true in the only environment
authorized to prove them.**

## Performance

- **Duration:** 11 min (of which ~3.5 min was the gate run itself)
- **Tasks:** 3 of 3 complete (task 3 was the blocking checkpoint; resolved 2026-08-27 — see below)
- **Files modified:** 1 created, 2 modified (all `.planning/`); zero source files

## Task Commits

1. **Task 1: Push, open the PR, drive the run to completion** — no repo commit. The artifacts are
   a GitHub PR (#60) and a workflow run (`33123496782`), recorded here rather than manufactured
   as an empty commit. The branch push moved `origin/feat/red-diff-scaffold` `3d56870 → 8f01abf`.
2. **Task 2: Harvest the gate log, write the evidence** — `c4dcd67` (docs)
3. **Task 3: Checkpoint** — reached, and **RESOLVED** by the maintainer (see "Checkpoint (task 3) — RESOLVED"). No repo commit: a checkpoint's artifact is the answer, recorded here.

## The run

| | |
|---|---|
| PR | https://github.com/JMSBPP/cfmm-vol-markets/pull/60 |
| Run | https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33123496782 |
| Head SHA | `8f01abf67fec3b917b849e974a7ddbc221860d35` |
| approve | **success** (2 s, `98695945576`) |
| forge | **success** (1 m 47 s, `98695963521`) |
| plank | **success** (15 s, `98695963588`) |
| gate | **success** (3 s, `98696684268`) — the sole required check, `pass` on the PR |

```
Ran 4 tests for test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol:VolOrderToPanopticTokenIdDiffTest
[SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test__fuzz_differential__volOrder(...)
[SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test_differential__volOrder__anchor()
[PASS] test_implSide_answersOnAnchor() (gas: 17954)
[PASS] test_specHelper_stubRevertsAndProbeReportsNotWired() (gas: 16680)
Suite result: ok. 2 passed; 0 failed; 2 skipped

Suite result: ok. 10 passed; 0 failed; 0 skipped   <- VolOrderToPanopticTokenIdTest, the floor
Ran 75 test suites in 6.00s: 273 tests passed, 0 failed, 3 skipped (276 total tests)

forge Version: 1.5.1-v1.5.1
Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2
```

The suite total is **byte-identical to push-build `33117651701`** on `470c916`. Opening the PR
moved nothing.

## The environment-approval claim, checked rather than assumed

The plan as written asserted the `approve` job "forces exactly one approval BEFORE untrusted code
runs". That was corrected in place before execution (commit `8f01abf`) on the strength of a Phase
1.1 measurement, and **this run confirms the correction on live data**:
`pending_deployments` returned `[]`, and `approve` ran `22:41:30Z → 22:41:32Z` — two seconds,
unattended. No approval was requested, none was given, and none is reported. What protects
`develop` is the required status-check context `gate`, which is `pass`.

## Toolchain attribution

The runner stamped `Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2` — the exact binary every
transport measurement in `notes/DIFFERENTIAL_LAYOUT.md` is scoped to. `which -a forge` showed the
pinned `$HOME/.foundry-pins/v1.5.1/bin/forge` resolving ahead of the box's own
`$HOME/.foundry/bin/forge` (listed twice on `PATH`). Without Phase 1.1's pin this section would
have read `UNDETERMINED`, and a green gate would not have been attributable to any toolchain.

## What this run does NOT establish

Recorded because a green run is the easiest place to lose a negative result:

- **`try`/`catch` against a cheatcode-originated revert is still OPEN.** Phase 1 makes no
  cheatcode call; the probe's revert originates in ordinary Solidity. The low-level
  `address(probe).call(...)` boundary succeeding sidesteps that question, it does not answer it.
  Phase 5's RPC-03 skeleton is the first run that can. It must be answered before Phase 7 relies
  on it.
- **The non-Ethereum JSON-RPC round trip is untested here.** No RPC call occurs in this phase.

## Deviations from Plan

### 1. [Criterion defect] "the PR contains exactly four files"

- **Found during:** Task 1 verification.
- **Issue:** Task 1's acceptance criterion required `gh pr view --json files` to return exactly the
  four source paths. It returns **13**. Nine are GSD planning artifacts plus one
  `docs/superpowers/plans/` note, which ride the feature branch because phases now run INLINE in
  the main tree instead of in a per-phase worktree. The criterion predates that workflow change —
  the same defect 01-04 recorded as its deviation 3.
- **Fix:** Verified the criterion's INTENT instead, which is what the phase actually cares about:
  `git diff develop..HEAD --name-only` filtered to source paths returns exactly `Makefile`,
  `notes/DIFFERENTIAL_LAYOUT.md`, `test/protocol_integrations/SpecHelper.sol`,
  `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol`, and
  `git diff develop..HEAD -- .github/` is **0 bytes**. Nothing under `.planning/` or `docs/` is
  compiled or executed by the gate. The PR body says all of this explicitly rather than repeating
  the plan's "4 files" claim, which a reviewer opening the Files-changed tab would have caught as
  a false statement in the first ten seconds.
- **Files:** PR #60 body, `01-05-GATE-EVIDENCE.md` (Anomaly 4)

### 2. [Rule 1 — Stale fact] The plan's four-pattern skip ledger is three patterns

- **Found during:** Task 2, reading `.github/workflows/develop-gate.yml` to quote the ledger.
- **Issue:** The plan's context block quotes the gate command as
  `--skip "*PriceSetterHook*" "*VolRangeWidth*" "*SpreadTickAssimetryHelper*" "*PanopticVegaLens.t.sol*"`.
  The ledger on `develop` has **three** patterns; `*PriceSetterHook*` was retired by Phase 1.1
  (`12e1fb9`, at the maintainer's explicit instruction) after the uncompilable test that motivated
  it was deleted. Quoting the plan's four would have put a fabricated line in an evidence file.
- **Fix:** Quoted the ledger from the workflow file as it actually stands, and recorded the
  discrepancy as Anomaly 3. The criterion's substance is untouched and stronger than stated: this
  phase added **zero** patterns to a ledger that was independently shrinking.
- **Files:** `01-05-GATE-EVIDENCE.md`

### 3. [Process] Evidence committed on the feature branch, not pushed to `develop`

- **Issue:** Task 2 instructed `git commit` then `git push origin develop` from a separate main
  worktree. There is no separate worktree — phases run inline — and pushing planning artifacts
  directly to `develop` would fork the evidence away from the PR that produced it.
- **Fix:** `01-05-GATE-EVIDENCE.md` is committed on `feat/red-diff-scaffold` (`c4dcd67`) and
  reaches `develop` with the merge in 01-06. The acceptance criterion
  `git log origin/develop -1 --name-only` listing the evidence file is therefore not met as
  literally written, and is met after 01-06.

### 4. [Not a deviation, recorded] No requirement ticks in this plan

RED-01…RED-06 were already `[x]` and `Complete` before execution (RED-06 by 01-04; RED-01/02/03/05
by commit `3d56870`, which cleared the item logged in `deferred-items.md`). This plan ticked
nothing and re-ticked nothing. Its `requirements: [RED-01, RED-05]` frontmatter is satisfied by the
**evidence** this plan produced — those two are the claims that could only ever be made from a gate
run, and they now have one.

## Anomalies in the run itself

Five, detailed in `01-05-GATE-EVIDENCE.md`: the stale `252 passed` comment in the workflow (the
right baseline is push-build `33117651701` at 273/0/3/276, which this run matched exactly); the
third skip being the pre-existing `loop-conformance.json` absence, not ours; the three-pattern
ledger; the 13-file PR; and 236 pre-existing compiler-warning lines. None is a failure and none was
omitted for being inconvenient.

## Requirements

None newly ticked. RED-01 and RED-05 — the two the plan names — are now backed by gate evidence
rather than only by push-build evidence, which is what Phase 1's criteria 1 and 2 are actually
stated against.

## Checkpoint (task 3) — RESOLVED

The prompt asked the maintainer to authorize the merge, and read:

> Type 'approved — merge' to authorize plan 01-06 to merge PR #60 into develop and close #57, or
> describe what is wrong.

**The maintainer's answer, verbatim and in full:**

```
approved
```

That is the complete response — one word, no qualification, no "but", nothing described as wrong.
It is recorded here exactly as given rather than normalized to the prompt's suggested phrasing.
The prompt offered two mutually exclusive branches (authorize, or describe what is wrong) and the
answer is unambiguously the first. Plan 01-06 was released on it and merged PR #60 as
`b090b2e8cf026cf7a4ac4dad703ce772e36cf99e`.

**What the approval was known to cost, and what it actually cost.** The checkpoint disclosed that
merging would land an unreviewed PR. Plan 01-06 re-measured branch protection immediately before
merging (`gh api /repos/JMSBPP/cfmm-vol-markets/branches/develop/protection`) and found **no
`required_pull_request_reviews` block at all** — the only requirement is the status-check context
`gate`, with `enforce_admins: false`. `mergeStateStatus` was `CLEAN`. **No `--admin` bypass was
used and none was needed.** The disclosed cost was therefore larger than the real one; the
disclosure is left standing here rather than edited away, because it is what the maintainer was
shown when they answered.

Plan 01-05 is **complete** — 3 of 3 tasks.

## Next

**Plan 01-06** merged PR #60 into `develop`, verified criteria 4 and 5 against the merged tree, and
closed tracking issue #57. See `01-06-SUMMARY.md`. Phase 1 is complete.

## Self-Check: PASSED

- `.planning/phases/01-red-differential-scaffold/01-05-GATE-EVIDENCE.md` — FOUND (197 lines)
- `.planning/phases/01-red-differential-scaffold/01-05-SUMMARY.md` — FOUND
- Commit `c4dcd67` — FOUND
- develop-gate run `33123496782` — conclusion `success`, verified via `gh run view`
- PR JMSBPP/cfmm-vol-markets#60 — `OPEN`, base `develop`, head `feat/red-diff-scaffold`
- `gh pr checks 60` — `gate` = `pass`
- `git diff develop..HEAD -- .github/` — 0 bytes
- `git diff develop..HEAD -- test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` — 0 bytes
- `grep -c '^milestone: v1.0$' .planning/STATE.md` → `1` (no state-writing verb was called; every
  STATE.md / ROADMAP.md edit was made by hand and proven with `git diff`)
- No `lib/*` submodule, `offchain`, `spec`, `.planning/config.json`, `TODO.md`,
  `src/modules/premium/DynamicFeeMod.plk` or `docs/superpowers/specs/2026-08-26-*` staged in any
  commit
