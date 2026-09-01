# cfmm-vol-markets — Haskell↔Plank Differential Conformance

## What This Is

A differential-testing program that makes the Haskell executable spec (`spec/src/Panoptic/NId.hs`)
the *authoritative oracle* for the on-chain Plank implementation
(`src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk`). Foundry fuzz tests drive both
implementations with the same inputs and assert byte-equality of the results.

Reaching that requires first generalizing `VolOrder` into a comptime type constructor `VolOrder(T)`,
where `T` is the extra payload that selects which tokenId gets built. The milestone delivers that
refactor and then a passing differential fuzz test for `volOrderToTokenId` — the
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
- ✓ Structural/golden/fuzz suite `VolOrderToPanopticTokenId.t.sol` against a hand-ported `validate()` oracle — existing
- ✓ Comptime type constructors are supported in-repo (`VolOrder(T)` refactor target) — existing
- ✓ `ffi = true` already enabled in `foundry.toml` — existing
- ✓ `develop-gate` as sole required check on `develop` (approve → forge + plank on self-hosted runner) — existing

### Active

<!-- Hypotheses until shipped and validated. -->

**Prerequisite refactor (own worktree, must land first):**

- [ ] `VolOrder` becomes a comptime type constructor `VolOrder(T)` carrying an `extra: T` payload
- [ ] The minimal instantiation reproduces today's tokenId exactly — existing callers
      (`vol_order_to_mint`, `position_size_for_target_vega`, the harness, the green test suite) keep working
- [ ] A richer instantiation carries the data the Haskell takes (4-tuple of `optionRatio`s 1..127, `asset`)
      and produces the Haskell-equivalent tokenId
- [ ] `VolOrder(T)` has a defined serialization that survives the Plank→Haskell hop

**Differential test:**

- [ ] A `SpecHelper` transport lets Solidity tests obtain the Haskell spec's `tokenId` for arbitrary inputs
- [ ] The Haskell spec is reachable from a Foundry test run inside `develop-gate` (spec submodule checked out + built in CI)
- [ ] Both sides agree on **rejection**, not just on returned values — the guard sets are reconciled
- [ ] `test__fuzz_differential__volOrder` passes over fuzzed `(VolOrder, poolId, OptionRatio[4])`
- [ ] `.planning/phases/FEATURES/feat-*/` is adopted as the milestone layout for feature work

### Out of Scope

- **`volOrderToMintPlan` / `positionSize` / chunk differential** — the sizing map (Layer 2) is a later
  feature; this milestone isolates the scale-free tokenId.
- **`NId` scaling helpers (`mkNId`, `nSigma`, `scaleByNId`)** — Hop-A optional-space scaling, not part
  of the tokenId map.
- **Panoptic decoder helpers (`panopticStrike`, `panopticWidth`, …) as diff targets** — read paths used
  *by* the test, not subjects of it.
- **Building GSD tooling for FEATURES phases** — adopt the directory convention now, make it
  first-class in GSD later.
- **Layer-2 geometric weights and Layer-3 payoff cap** — pre-existing future work, unchanged by this.

## Context

- **Two implementations, one function.** `spec/` (Haskell, a submodule of canonical
  `d2p-finance/cfmm-vol-markets-spec`) is the executable specification; `src/**.plk` is the on-chain
  implementation. Today they are *not the same function*: the Haskell takes a 4-tuple of
  `optionRatio`s and sets `asset = 1`; the Plank map hardcodes `optionRatio = 1` and leaves `asset`
  unset (added afterward by `vol_order_to_mint`). `VolOrder(T)` is how that gap closes without
  breaking existing callers.
- **Plank is the fuzz source.** Inputs originate on the Plank/Foundry side and must be transported to
  the Haskell — not constructed independently on each side, which would let the two drift.
- **`Shock(R)` is the template.** The in-repo precedent pairs a comptime type constructor with a
  *self-describing tagged* wire format: a leading `flags` byte, present-components-only payload, and a
  `length` derived from the flags and rejected on mismatch. That tagging mechanism is what lets a
  consumer recover which variant it received from the bytes alone.
- **Guard divergence is the hard part.** Haskell additionally rejects ratios outside 1..127, per-leg
  `span < Δ`, and ticks outside `|tick| ≤ uniswapMaxTick`. Plank checks none of these. Differential
  fuzzing targets exactly these gaps, so the sides must agree on *when they revert*.
- **VolOrder packing today.** Plank packs to a `u256`
  (`skew@0 | volStrike@16 | tickSpacing@104 | width@128 | targetVega@152`, 248 bits); the Haskell has no
  unpacker and builds from structured fields (`mkVolRangeWidth`, `mkVolStrike`, `mkVolSkew`).
- **The existing test's oracle is hand-written.** `VolOrderToPanopticTokenId.t.sol` validates against a
  verbatim Solidity port of Panoptic's `validate()` plus hardcoded golden vectors — a
  *re-implementation*, not the spec. This project replaces it with the real Haskell as oracle.
- **CI does not see `spec/`.** `develop-gate` checks out with `submodules: false` and inits only
  `lib/`, so the spec submodule is absent on the runner. GHC 9.10.3 / cabal 3.16.1.0 exist on the
  developer machine; availability on the self-hosted runner is unverified.
- **Prior planning was deliberately reset.** Commit `663c70b chore: reset GSD planning tree` cleared
  `.planning/` ahead of this fresh cycle. Earlier design work survives in git history — notably
  `.planning/cr-i2-vol-order-to-panoptic-token-id-SPEC.md` at `790d476`, documenting the Layer-1/2/3
  decomposition and the review findings behind the current Plank map.

## Constraints

- **Workflow**: Phases start **inline, in the current tree** — no per-phase git worktree. (Superseded
  the earlier worktree-per-unit rule after Phase 1.1.) A tracking issue on `develop` still applies.
- **Validation**: CI is the gate *and the only build environment*. There is no internal/local
  compilation step — dependencies and submodules are deliberately left uninitialized locally; the CI
  syncs and manages them, and the compiler's answer is read from whether `develop-gate` passed. This
  holds for pushes and for PRs. Never report work as verified from a local build.
- **Fork → PR**: `d2p-finance/*` are canonical; `JMSBPP/*` are the develop forks. Changes reach
  canonical repos only via pull request. This milestone touches the `spec/` submodule, so spec-side
  changes require their own fork → PR plus a submodule pin bump here.
- **Sequencing**: The `VolOrder(T)` refactor is a blocking prerequisite — it must land and pass
  `develop-gate` before the differential-test phase begins.
- **Regression floor**: The refactor must not break the existing green suite; today's tokenId output
  must be bit-identical under the minimal instantiation.
- **Tech stack**: Foundry (`--via-ir`, `ffi = true`, fuzz runs 256) + the Plank toolchain + GHC/cabal.
  No Hardhat.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Haskell spec is the oracle; Solidity ports are not | A hand-ported `validate()` tests our re-reading of Panoptic, not the spec | — Pending |
| `VolOrder` becomes `VolOrder(T)` with an `extra: T` payload | Lets the Haskell-equivalent tokenId be a *different instantiation* rather than a breaking signature change; follows the proven `Shock(R)` pattern | — Pending |
| ~~Change the Plank signature in place~~ | **Superseded** by `VolOrder(T)` — the minimal instantiation preserves today's callers, so no in-place break is needed | ⚠️ Revisited |
| Refactor is a blocking prerequisite, on its own worktree | The diff test consumes the generic type; testing the old static map would be throwaway work | — Pending |
| Fuzz the VolOrder geometry, not just `(poolId, ratios)` | Leg splits, negative ticks and guards are where divergence hides | — Pending |
| Plank is the fuzz source; inputs are transported to Haskell | Independently constructing inputs on each side lets them drift, defeating the test | — Pending |
| Enforce the diff test inside `develop-gate` | A self-skipping test is silently unenforced; CI is the gate | — Pending |
| A dedicated RPC design phase precedes the spec oracle | Transport and the spec-service/test-process responsibility split are a design problem, not a lookup; settling them before there is domain payload to carry avoids rework | — Pending |
| The spec oracle is built test-first (TDD) | Its architecture and specification drive the implementation, across both repos of the fork → PR | — Pending |
| Adopt `.planning/phases/FEATURES/feat-*/`; defer GSD tooling | Get the layout's benefit now without a detour into GSD internals | — Pending |
| Scope milestone to `volOrderToTokenId` only | Prove the differential harness on one map before generalizing | — Pending |
| **OPEN — `VolOrder(T)` wire format: Shock-style tagged vs per-variant layout** | Tagged = one decoder covers every `T`; per-variant = simpler each, but the variant must travel out-of-band. Settle in phase planning | — Pending |
| **RESOLVED — spec transport: JSON-RPC** (was OPEN, owned by Phase 5) | Decided **at `evm-spec-bridge` initialization, outside Phase 5**, by the user — knowingly overriding this project's "open by design, do not pre-resolve" instruction. The `evm_spec_rpc` session flagged the conflict before acting rather than presenting it as settled; the user confirmed the override directly when it was put to them. Rationale for JSON-RPC over `vm.ffi`: a warm service avoids per-case process spawn across a 256-run fuzz, and generalizes to the whole spec surface rather than one query shape. Recorded with the override visible rather than smoothed over, per Phase 5 criterion 1 | ✓ Decided (outside Phase 5) |
| `evm-spec-bridge` enters this repo as a submodule | The transport is a separate deliverable with its own repo, gate and lifecycle. It is a Haskell lib + JSON-RPC server exe, depends on `cfmm-vol-markets-spec`, and **generates the Solidity interface from the same schema as its Haskell protocol types** so the two sides cannot drift silently. Phase 5 becomes the reference contract for what it must deliver; Phase 7's `SpecHelper` targets the generated interface | — Pending |
| **Spec version must have ONE authority** | The bridge depends on `cfmm-vol-markets-spec` and this repo pins `spec/` directly — two paths to the oracle. Divergence breaks nothing and fails nothing, so the differential test would compare Plank against a spec version nobody believes is the oracle and stay green. Mitigation is mandatory: bridge reports its spec commit SHA in the health/echo response, asserted against the `spec/` pin. Preferred if viable: pin only the bridge and drop the direct `spec/` pin | — Pending |
| **OPEN — oracle packaging: new cabal exe vs mode on `cfmm-scratchpad-exe`** | **The recorded cost rationale is VOID and so is its replacement** — cairo arrives via the *library*, which every source-path consumer builds whichever exe is invoked. Measured: apt provisioning 14 s vs a 302 s cold build. Decide on interface and lifecycle grounds; there is no cost difference to appeal to. See STATE.md Blockers | — Pending |

---
*Last updated: 2026-08-27 after initialization*
