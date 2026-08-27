# Phase 1 gate evidence

- **Run:** https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33123496782
- **Run id:** `33123496782`
- **Branch:** `feat/red-diff-scaffold`
- **PR:** https://github.com/JMSBPP/cfmm-vol-markets/pull/60
- **Commit:** `8f01abf67fec3b917b849e974a7ddbc221860d35`
- **Job conclusions:** approve=**success** forge=**success** plank=**success** gate=**success**
- **Workflow:** `develop-gate`, event `pull_request`, base `develop`
- **Harvested:** 2026-08-27T22:46:42Z

Job ids, for anyone re-pulling the logs: approve `98695945576`, forge `98695963521`,
plank `98695963588`, gate `98696684268`.

**On the `approve` job — no human approval occurred, and none was required.** It started
`22:41:30Z` and completed `22:41:32Z`, unattended, two seconds after the run was created.
`gh api /repos/JMSBPP/cfmm-vol-markets/actions/runs/33123496782/pending_deployments` returned
`[]`. This confirms, on this run, the measurement recorded in STATE.md: the `develop-gate`
environment has `protection_rules: []` and has never been configured, so the `environment:` key
in the workflow produces a deployment record and no gate. What actually protects `develop` is the
required status-check context `gate`. Nothing in this plan changed that, and nothing in this plan
attempted a self-approval.

## Toolchain

Quoted from the forge job's `Stamp the resolved forge version` step:

```
/home/jmsbpp/.foundry-pins/v1.5.1/bin/forge
/home/jmsbpp/.foundry/bin/forge
/home/jmsbpp/.foundry/bin/forge
forge Version: 1.5.1-v1.5.1
Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2
Build Timestamp: 2025-12-19T14:07:55.455914129Z (1766153275)
Build Profile: maxperf
```

The Phase 1.1 (CI-05) pin landed on `develop` before this run, so this gate run executed against a
pinned toolchain and the version lines are present. `Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`
is the exact binary every transport measurement in `notes/DIFFERENTIAL_LAYOUT.md` is scoped to, so
this gate result is attributable to a toolchain rather than to "whatever the runner had". The
`which -a forge` lines show the pinned binary resolving AHEAD of the box's pre-existing
`$HOME/.foundry/bin/forge` (listed twice on `PATH`) — the collision the per-pin directory exists
to win.

## Transport mechanism findings

**Established by this run:**

- The low-level `address(probe).call(...)` boundary in `_probeWiring` returned, and its return
  data decoded into a full `SpecOracle.Health` struct rather than a bool or a string. The probe
  ran once in `setUp` for all four tests in the contract; had the decode reverted, all four would
  have errored in `setUp` instead of producing the two SKIPs and two PASSes below.
- `vm.expectRevert` across that same external boundary caught the stub's `SpecOracleNotWired`
  revert:

  ```
  [PASS] test_specHelper_stubRevertsAndProbeReportsNotWired() (gas: 16680)
  [PASS] test_implSide_answersOnAnchor() (gas: 17954)
  ```

**NOT established by this run — stated plainly so it is not mistaken for answered:**

Whether `try`/`catch` works against a **cheatcode-originated** revert is **NOT established by this
run**. Phase 1 makes no cheatcode call at all: the probe's revert originates in ordinary Solidity
(`SpecOracle.volOrderToTokenId` reverting `SpecOracleNotWired`), not in `vm.rpc`. `try`/`catch`
performs an `extcodesize` check against the cheatcode address, which is why it is the
lowest-confidence item in the transport analysis, and it is recorded as OPEN in
`notes/DIFFERENTIAL_LAYOUT.md`. The low-level-call success above sidesteps that question; it does
not answer it. They are different questions. It must be answered before Phase 7 relies on it —
Phase 5's RPC-03 skeleton is the first run that can.

Also **not established by this run:** whether an end-to-end round trip against a non-Ethereum
JSON-RPC server works. No RPC call is made anywhere in this phase.

## Criterion 1 — compiles under --via-ir alongside the structural suite and harness

The command, quoted from the forge job's step header:

```
forge test --via-ir --offline --fuzz-seed 4880 --skip "*VolRangeWidth*" "*SpreadTickAssimetryHelper*" "*PanopticVegaLens.t.sol*"
```

It compiled clean (`Compiler run successful with warnings`, 0 errors), and the diff test contract
appears in the run:

```
Ran 4 tests for test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol:VolOrderToPanopticTokenIdDiffTest
```

Whole-suite total, unchanged from the pre-PR push build `33117651701`:

```
Ran 75 test suites in 6.00s (27.98s CPU time): 273 tests passed, 0 failed, 3 skipped (276 total tests)
```

## Criterion 2 — skipped via the wiring probe, no skip-ledger edit

The two differential tests SKIP, and the skip reason is the probe's, quoted verbatim:

```
[SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test__fuzz_differential__volOrder(uint256,uint256,uint256,uint256,uint256,uint256,uint256) (runs: 0, μ: 0, ~: 0)
[SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test_differential__volOrder__anchor() (gas: 0)
```

The two evidence tests PASS in the same contract — the file is not inert, and "everything
skipped" cannot hide it:

```
[PASS] test_implSide_answersOnAnchor() (gas: 17954)
[PASS] test_specHelper_stubRevertsAndProbeReportsNotWired() (gas: 16680)
Suite result: ok. 2 passed; 0 failed; 2 skipped; finished in 88.74ms (986.29µs CPU time)
```

Skip-ledger check: `git diff develop..HEAD -- .github/workflows/develop-gate.yml` → **0 bytes**.
`git diff develop..HEAD -- .github/` → **0 bytes**. The ledger on this branch is byte-identical to
`develop`, and it is what it was before this phase:

```yaml
          forge test --via-ir --offline --fuzz-seed 4880
          --skip "*VolRangeWidth*" "*SpreadTickAssimetryHelper*"
          "*PanopticVegaLens.t.sol*"
```

Three patterns, not four. `*PriceSetterHook*` was retired from the ledger by Phase 1.1 (commit
`12e1fb9` on `develop`, at the maintainer's explicit instruction) after the uncompilable test that
motivated it was deleted. Plan 01-05's context block still describes a four-pattern ledger; that
description is stale, and the correct reading is that this phase added **zero** patterns to a
ledger that was independently shrinking.

## Criterion 3 — regression floor held

```
Ran 10 tests for test/protocol_integrations/VolOrderToPanopticTokenId.t.sol:VolOrderToPanopticTokenIdTest
[PASS] testFuzz_legFromBucket_reconstructs(int256,uint256,int256) (runs: 256, μ: 12980, ~: 12902)
[PASS] testFuzz_map_validAndTiles(uint256,uint256) (runs: 256, μ: 41618, ~: 41679)
[PASS] test_legFromBucket_negativeOdd() (gas: 7667)
[PASS] test_legFromBucket_positiveEven() (gas: 7897)
[PASS] test_legFromBucket_positiveOdd() (gas: 7941)
[PASS] test_map_goldenStructure() (gas: 23781)
[PASS] test_map_guard_passesAtExactly2ts() (gas: 17598)
[PASS] test_map_guard_revertsOnNarrowSide() (gas: 13783)
[PASS] test_map_guard_revertsOnWidthOverflow() (gas: 14378)
[PASS] test_map_validatesAsPanoptic() (gas: 21973)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 212.18ms (203.15ms CPU time)
```

`git diff develop..HEAD -- test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` →
**0 bytes**. The floor held at 10/10 without the file being touched.

Across the whole run: `grep -c 'Suite result: FAILED'` → **0**.

## Criterion 4 — doctrine, discipline, and written organization

Delivered by plans 01-03 and 01-04; verified at source, not from this run. See
`01-03-SUMMARY.md` and `01-04-SUMMARY.md`. What this run adds is only that the doctrine header and
`notes/DIFFERENTIAL_LAYOUT.md` are on the branch the gate compiled.

## Criterion 5 — FEATURES layout on develop

Delivered by plan 01-01. See `01-01-SUMMARY.md`. `.planning/phases/FEATURES/README.md` and the
mode-120000 `feat-red-diff-scaffold` symlink are tracked on `develop` at commit `04dea0a`.

## Anomalies

Five, none of them a failure, all recorded because a green run is not a reason to omit them.

1. **The suite total is 273/0/3/276, not the `252 passed, 0 failed` in `develop-gate.yml`'s
   comment.** That comment is stamped "VERIFIED LOCALLY against PR #15" and predates both the
   ledger shrinking (`*PriceSetterHook*` retired, which returned three previously-excluded files to
   the compile set) and subsequent test growth. The number to compare against is the pre-PR push
   build `33117651701` on `470c916`, which reported **273 passed, 0 failed, 3 skipped (276)** —
   byte-identical to this run. The workflow comment is stale; it is not evidence of drift.

2. **The run reports 3 skipped, not 2.** Two are this phase's differential tests. The third is
   pre-existing and unrelated:
   `[SKIP: loop-conformance.json absent at offchain/rig/loop-conformance.json - run the live sequence] test__priceInvarianceUnderVolumePath()`.
   It was skipped identically on `470c916` before this PR existed.

3. **The skip ledger has three patterns; plan 01-05's context block says four.** Detailed under
   Criterion 2. The plan text is stale, `.github/` is untouched, and the criterion's substance —
   this phase adds nothing to the ledger — holds.

4. **The PR contains 13 files, not 4.** The four SOURCE files are exactly as specified
   (`git diff develop..HEAD --name-only`, excluding `.planning/` and `docs/`). The other nine are
   GSD planning artifacts and one `docs/superpowers/plans/` note, which ride the feature branch
   because phases now run INLINE in the main tree rather than in a per-phase worktree. None of them
   is compiled or executed by the gate. Plan 01-05's acceptance criterion asserting a four-entry
   `gh pr view --json files` predates that workflow change and is not met as literally written.

5. **`Compiler run successful with warnings`.** 236 warning-matching lines across the compile,
   all pre-existing and none originating in the four files this PR adds; `forge test` exits 0 and
   the gate does not treat warnings as errors. Not introduced here, not fixed here.

**No expected line was absent.** Every quotation above was taken from
`gh run view 33123496782 --repo JMSBPP/cfmm-vol-markets --log --job 98695963521`; none was
reconstructed or paraphrased.
