# cfmm-vol-markets — Haskell↔Plank Differential Conformance

## What This Is

A differential-testing program that makes the Haskell executable spec (`spec/src/Panoptic/NId.hs`)
the *authoritative oracle* for the on-chain Plank implementation
(`src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk`). Foundry fuzz tests call the Haskell
spec and the Plank implementation with the same inputs and assert byte-equality of the results.

The first deliverable is a passing differential fuzz test for `volOrderToTokenId` — the
`VolOrder → PanopticTokenId` map (Layer 1 of the variance-swap replication stack).

## Core Value

**A fuzzed input that produces a different `tokenId` in Haskell than in Plank must fail the build.**
If the executable spec and the on-chain implementation can silently disagree, the spec is decoration.

## Requirements

### Validated

<!-- Inferred from existing code — these already work and are relied upon. -->

- ✓ Haskell `volOrderToTokenId :: VolOrder -> Integer -> (Integer,Integer,Integer,Integer) -> PanopticTokenId` — existing
- ✓ Plank `vol_order_to_panoptic_token_id(vo, pool_id)` Layer-1 map (4-leg, all-long, floor-strike encoder) — existing
- ✓ Plank harness `VolOrderToPanopticTokenIdHarness.plk` exposing `tokenIdFromVolOrder`/`bucketFromVolOrder`/`centerTick` — existing
- ✓ Structural/golden/fuzz test suite `VolOrderToPanopticTokenId.t.sol` against a hand-ported `validate()` oracle — existing
- ✓ `ffi = true` already enabled in `foundry.toml` — existing
- ✓ `develop-gate` as sole required check on `develop` (approve → forge + plank on self-hosted runner) — existing

### Active

<!-- Hypotheses until shipped and validated. -->

- [ ] A `SpecHelper` transport lets Solidity tests obtain the Haskell spec's `tokenId` for arbitrary inputs
- [ ] The Haskell spec is reachable from a Foundry test run inside `develop-gate` (spec submodule checked out + built in CI)
- [ ] Plank `vol_order_to_panoptic_token_id` accepts a caller-supplied 4-tuple of `optionRatio`s (1..127) and pins `asset = 1` on all legs, matching the Haskell
- [ ] Both sides share one `VolOrder` wire format, so a fuzzed VolOrder decodes identically in Haskell and Plank
- [ ] Both sides agree on **rejection**, not just on returned values — the guard sets are reconciled
- [ ] `test__fuzz_differential__volOrder` passes over fuzzed `(VolOrder, poolId, OptionRatio[4])`
- [ ] `.planning/phases/FEATURES/feat-*/` is adopted as the milestone layout for feature work

### Out of Scope

- **`volOrderToMintPlan` / `positionSize` / chunk differential** — the sizing map (Layer 2) is a later
  feature; this milestone isolates the scale-free tokenId.
- **`NId` scaling helpers (`mkNId`, `nSigma`, `scaleByNId`)** — Hop-A optional-space scaling, not part
  of the tokenId map.
- **Panoptic decoder helpers (`panopticStrike`, `panopticWidth`, …) as diff targets** — they are read
  paths used *by* the test, not subjects of it.
- **Building GSD tooling for FEATURES phases** — deferred; adopt the directory convention now, make it
  first-class in GSD later.
- **Layer-2 geometric weights and Layer-3 payoff cap** — pre-existing future work, unchanged by this.

## Context

- **Two implementations, one function.** `spec/` (Haskell, a submodule of canonical
  `d2p-finance/cfmm-vol-markets-spec`) is the executable specification; `src/**.plk` is the on-chain
  implementation. Today they are *not the same function*: the Haskell takes a 4-tuple of
  `optionRatio`s and sets `asset = 1`; the Plank map hardcodes `optionRatio = 1` and leaves `asset`
  unset (it is added afterward by `vol_order_to_mint`). The diff test cannot pass until this is closed.
- **Guard divergence is the hard part.** Haskell additionally rejects ratios outside 1..127, per-leg
  `span < Δ`, and ticks outside `|tick| ≤ uniswapMaxTick`. Plank checks none of these. Differential
  fuzzing targets exactly these gaps, so the sides must agree on *when they revert*.
- **VolOrder has no shared wire format.** Haskell builds `VolOrder` from structured fields
  (`mkVolRangeWidth`, `mkVolStrike`, `mkVolSkew`); Plank consumes a packed `u256`
  (`width@128 | tickSpacing@104 | vol@16 | spread@0`). Fuzzing the VolOrder requires one shared
  encoding — likely `unpackVolOrder` on the Haskell side.
- **The existing test's oracle is hand-written.** `VolOrderToPanopticTokenId.t.sol` validates against a
  verbatim Solidity port of Panoptic's `validate()` plus hardcoded golden vectors. That is a
  *re-implementation*, not the spec — this project replaces it with the real Haskell as oracle.
- **CI does not see `spec/`.** `develop-gate` checks out with `submodules: false` and inits only
  `lib/`, so the spec submodule is absent on the runner. GHC 9.10.3 / cabal 3.16.1.0 exist on the
  developer machine; availability on the self-hosted runner is unverified.
- **Prior planning was deliberately reset.** Commit `663c70b chore: reset GSD planning tree` cleared
  `.planning/` ahead of this fresh cycle. Earlier design work survives in git history — notably
  `.planning/cr-i2-vol-order-to-panoptic-token-id-SPEC.md` at `790d476`, which documents the Layer-1/2/3
  decomposition and the review findings behind the current Plank map.

## Constraints

- **Workflow**: Every unit of work (feature, refactor, fix) starts with a git worktree named after its
  `feat/…` branch and a tracking issue on `develop` — general rule, not a per-task choice.
- **Validation**: CI is the gate. Work is *not* validated by compiling or running the suite locally;
  the branch is pushed and `develop-gate` decides. Never report work as verified from a local build.
- **Fork → PR**: `d2p-finance/*` are canonical; `JMSBPP/*` are the develop forks. Changes reach
  canonical repos only via pull request. This milestone touches the `spec/` submodule, so spec-side
  changes require their own fork → PR plus a submodule pin bump here.
- **Review**: Every spec/plan must pass the two-step review (Reality Checker + one matched specialist,
  in parallel) before it is executed.
- **Tech stack**: Foundry (`--via-ir`, `ffi = true`, fuzz runs 256) + the Plank toolchain + GHC/cabal.
  No Hardhat.
- **Dependency**: The Plank signature change ripples into `vol_order_to_mint`, `position_size_for_target_vega`,
  and the existing harness/tests, which must stay green.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Haskell spec is the oracle; Solidity ports are not | A hand-ported `validate()` tests our re-reading of Panoptic, not the spec | — Pending |
| Change the Plank signature in place (add ratios, pin `asset`) rather than add a parallel map | One source of truth; two near-identical maps would drift | — Pending |
| Fuzz the VolOrder geometry, not just `(poolId, ratios)` | Leg splits, negative ticks and guards are where divergence hides | — Pending |
| Enforce the diff test inside `develop-gate` | A self-skipping test is silently unenforced; CI is the gate | — Pending |
| Adopt `.planning/phases/FEATURES/feat-*/`; defer GSD tooling | Get the layout's benefit now without a detour into GSD internals | — Pending |
| Scope milestone to `volOrderToTokenId` only | Prove the differential harness on one map before generalizing | — Pending |
| **OPEN — spec transport: `vm.ffi` binary vs Haskell JSON-RPC service** | `vm.rpc(alias, method, params)` forwards arbitrary methods, so a warm spec service avoids per-case process spawn and generalizes to the whole spec surface; ffi is simpler and already enabled. Settle in phase planning | — Pending |
| **OPEN — oracle packaging: new cabal exe vs mode on `cfmm-scratchpad-exe`** | The existing exe is a Chart/cairo plotting binary — heavy to build in CI | — Pending |

---
*Last updated: 2026-08-27 after initialization*
