# Requirements: Haskell↔Plank Differential Conformance

**Defined:** 2026-08-27
**Core Value:** A fuzzed input that produces a different `tokenId` in Haskell than in Plank must fail the build.

## v1 Requirements

Requirements for this milestone. Each maps to a roadmap phase.

### Differential Test Scaffold — the first clean push

- [x] **RED-01**: `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` exists and compiles under `--via-ir`, alongside the existing structural suite and harness
- [x] **RED-02**: The file carries the inherited `.diff.t.sol` doctrine header, oriented as **neither side sacrosanct** — a divergence is a finding about either implementation, adjudicated case by case, and neither the spec nor the Plank map may be bent merely to restore green
- [x] **RED-03**: The test observes the established differential discipline — corpora **constructed** with `bound` rather than filtered with `vm.assume`, every fuzz backed by a non-fuzz anchor case, and non-vacuity asserted rather than assumed
- [x] **RED-04**: The spec seam exists as a stub shaped to the interface `evm-spec-bridge` will generate — `library SpecOracle` with `volOrderToTokenId(bytes,uint64)` **reverting** (`SpecOracleNotWired`, fail-safe: a struct-returning stub would let a caller silently "agree" on a fabricated `tokenId == 0`) and `health()` returning the full tagged envelope as the **single wiring predicate** the test queries first, observed across a real external call boundary
- [x] **RED-05**: The fuzz body is written against the real assertion (`assertEq(specTokenId, implTokenId)`) and guarded by `vm.skip` on the wiring probe, so the branch pushes clean through `develop-gate` with **no skip-ledger edit**
- [x] **RED-06**: The organization — file layout, naming, and the Solidity↔spec transport boundary — is documented so later phases extend it rather than redesign it

### VolOrder(T) Refactor — blocking prerequisite

- [x] **VORD-01**: `VolOrder` is a comptime type constructor `VolOrder(T)` carrying an `extra: T` payload, following the in-repo `Shock(R)` pattern
- [x] **VORD-02**: The minimal instantiation produces a **bit-identical** `tokenId` to today's `vol_order_to_panoptic_token_id` for every input the current suite covers
- [x] **VORD-03**: Existing callers — `vol_order_to_mint`, `position_size_for_target_vega`, `vol_order_leg_split`, `VolOrderToPanopticTokenIdHarness.plk` — compile and pass unchanged against the minimal instantiation
- [ ] **VORD-04**: The `Extra(T)` descriptor, when flagged `FLAG_PANOPTIC`, points at the data the Haskell map takes — four `optionRatio`s (each 1..127) — and the builder sets the `asset` bit. (Restated 2026-08-28 from "a rich instantiation carries…": there is no second instantiation; see 02-REGRESSION-ASSESSMENT.md §4a. `pool_id` stays an explicit parameter, §4a decision 7.)
- [ ] **VORD-05**: With a `FLAG_PANOPTIC` descriptor the builder emits the Haskell-equivalent `tokenId` — per-leg `optionRatio` from the four values the descriptor points at, `asset = 1` on all four legs. (Restated 2026-08-28; mechanism only, outcome unchanged.)
- [ ] **VORD-06**: `VolOrder(T)` has a defined serialization that carries *which* `T` was instantiated, decodable by a consumer from the bytes alone
- [x] **VORD-07**: The `Extra(T)` `FLAG_PANOPTIC` payload is 40 bits — leg `k` at `[8k..8k+7]` with `optionRatio` 7b @`8k` and `tokenType` 1b @`8k+7`, plus `vegoid` 8b @32 — and `extra_decode` accepts 40 while REJECTING 28. Every redundant field is CHECKED against a value the builder derives independently (the caller declares, the contract proves): `tokenType` against the i\* split, `vegoid` against `pool_id[40..47]` with a SEPARATE `!= 0` check since equality alone passes when both sides are zero, and `vo.rangeWidth.tickSpacing` against `key.tick_spacing`.
- [ ] **VORD-08**: The `asset` bit has exactly ONE writer in the codebase, and the removal of `vol_order_to_mint`'s four `panoptic_add_asset` calls is ATOMIC with the addition of the Layer-1 write — one commit, not two. `panoptic_add_asset` is additive, so between the two changes a second write carries into `optionRatio`'s least significant bit, which the Layer-1 golden vectors cannot observe. The atomicity IS the requirement; it is the first thing lost at a phase handoff, which is why it is in the text rather than left to the plan.

### Venue-Tagged Market Key — inserted prerequisite

- [x] **KEY-01**: `VolMarketKey(V)` is a comptime type constructor over a VENUE tag (`V4`, `V3`, `Algebra`), so passing a key of one venue where another is expected is a COMPILE error, not a runtime revert. All three venues are instantiated — Plank never type-checks an un-instantiated comptime branch.
- [x] **KEY-02**: The Panoptic arm (V4 and V3) DERIVES the 40-bit pool pattern venue-specifically — V4 from the low 40 bits of the v4 PoolId, V3 from `uint40(uint160(pool) >> 120)` — and VERIFIES it against the SFPM's stored value, reverting on mismatch. The Panoptic `poolId` is STATEFUL (the SFPM increments the pattern on collision), so a pure derivation yields a candidate, not an answer.
- [x] **KEY-03**: The v3 and Algebra pool addresses are obtained by REGISTRY LOOKUP (`factory.getPool` / `factory.poolByPair`) and verified, never CREATE2-derived; no `POOL_INIT_CODE_HASH` is pinned anywhere in the repo.
- [x] **KEY-04**: The Algebra arm terminates at a verified pool ADDRESS and goes no further — there is no `PanopticFactoryAlgebra` — and passing `VolMarketKey(Algebra)` to the tokenId builder is a COMPILE error, making the dead-end a type-level fact rather than a runtime surprise.
- [x] **KEY-05**: `src/types/protocol_integrations/MarketId.plk` is retired and subsumed by `VolMarketKey(V4)`, whose pattern derives from the same keccak of the 5-field PoolKey that `market_id_from_pool_key` already computes. Its three real consumers are migrated.
- [x] **KEY-06**: `VolMarketKey(V)` DERIVES the Panoptic `asset` bit from the key's own `asset_index` — `panoptic_asset_bit == 1 -% asset_index` — as a standalone function of the key, tested for BOTH values of `asset_index`. The inversion is a NOT, not a copy: Panoptic's `asset` bit names the CASH/collateral token that `positionSize` is denominated in (what this protocol calls the NUMERAIRE), so a failure here yields a valid position on the WRONG SIDE of the pair.

### RPC / Transport Architecture

- [ ] **RPC-01**: The transport decision is **recorded** with its rationale — resolved as JSON-RPC at `evm-spec-bridge` initialization, outside this phase, overriding Phase 5's ownership. The record must show the override rather than smooth it over. (Reworded from "decided and recorded": the deciding was taken elsewhere.)
- [ ] **RPC-02**: Responsibility delegation between the two participants — the Haskell spec service and the Foundry test process — is specified: which side owns wire encoding/decoding, input validation, guard evaluation, and error classification
- [ ] **RPC-03**: A minimal protocol skeleton (`health()`) runs and is exercised end-to-end against the bridge's server, proving the transport shape works **independent of** `volOrderToTokenId`, and carrying the spec commit SHA the running binary was **built from** — asserted against this repo's spec authority, failing loudly on mismatch and never skipping past it

### Spec Oracle (Haskell side)

- [ ] **SPEC-01**: The Haskell decodes the `VolOrder(T)` wire format into its own `VolOrder` + extra payload, so Plank-originated inputs drive the spec unmodified
- [ ] **SPEC-02**: The spec exposes `volOrderToTokenId` through an external entrypoint callable from outside the Haskell process, built test-first (TDD) against its architecture and specification
- [ ] **SPEC-03**: Spec-side changes land in `d2p-finance/cfmm-vol-markets-spec` via `JMSBPP` fork → PR, and the `spec/` submodule pin is bumped here

### Transport

- [ ] **XPORT-01**: A Solidity `SpecHelper` obtains the Haskell spec's `tokenId` for an arbitrary `(VolOrder(T), poolId)` input during a Foundry test run
- [ ] **XPORT-02**: The transport distinguishes spec-side **rejection** from spec-side success, so guard behavior is observable to the test and not conflated with a transport failure

### Guard Parity

- [ ] **GUARD-01**: `optionRatio ∈ 1..127` is enforced identically on both sides
- [ ] **GUARD-02**: per-leg `span ≥ Δ` is enforced identically on both sides
- [ ] **GUARD-03**: `|tick| ≤ uniswapMaxTick` is enforced identically on both sides
- [ ] **GUARD-04**: the already-shared guards — each side of `i*` ≥ 2Δ, leg width < 4096 — remain aligned after the refactor
- [ ] **GUARD-05**: for every fuzzed input, the two sides agree on **revert-vs-return**; a divergence in rejection fails the test just as a divergence in value does

### Differential Test

- [ ] **DIFF-01**: `test__fuzz_differential__volOrder` asserts equality of the spec and implementation `tokenId` over fuzzed `(VolOrder, poolId, OptionRatio[4])` and passes
- [ ] **DIFF-02**: The pre-existing `VolOrderToPanopticTokenId.t.sol` suite remains green throughout

### CI Enforcement

- [ ] **CI-01**: `develop-gate` checks out the `spec/` submodule — extending the gate's existing, deliberate submodule management (`git submodule sync --recursive` + selective init), since dependencies are intentionally left uninitialized locally
- [ ] **CI-02**: `develop-gate` builds the Haskell oracle on the self-hosted runner (GHC/cabal availability confirmed or provisioned)
- [ ] **CI-03**: The differential test executes and is **enforced** in `develop-gate` — it cannot silently skip
- [ ] **CI-04**: The interim `vm.skip` wiring guard from RED-05 is **removed** once the oracle is reachable, so the end state has no silent-skip path

### Toolchain Determinism

- [x] **CI-05**: `develop-gate` resolves an **explicit, pinned Foundry version** rather than whatever `forge` happens to be installed on the persistent self-hosted runner, so gate results are attributable and reproducible
- [x] **CI-06**: Every gate run emits the resolved `forge --version` (version, commit SHA, build timestamp) as run evidence, making toolchain drift visible the first time it occurs
- [x] **CI-07**: A push to any branch other than `develop` **immediately** triggers a build that initializes submodules, installs dependencies, builds the Plank toolchain, and runs `forge build` + `forge test` — **without manual approval** — so code committed at any execution step gets compile feedback without waiting for a PR

### Planning Layout

- [x] **PROC-01**: `.planning/phases/FEATURES/feat-*/` is adopted as the directory layout for this milestone's feature phases

## v2 Requirements

Deferred. Tracked but not in this roadmap.

### Differential Coverage

- **V2-01**: `volOrderToMintPlan` differential — the `(tokenId, chunk)` pair
- **V2-02**: `positionSizeForTargetVega` differential — the Layer-2 sizing scalar
- **V2-03**: `NId` scaling helpers (`mkNId`, `nSigma`, `scaleByNId`) differential
- **V2-04**: Generalize the transport into a reusable oracle covering the whole spec surface

### Tooling

- **V2-05**: Make FEATURES phases with milestone sub-features a first-class GSD structure (commands/tooling in `~/.claude/get-shit-done`)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Layer-2 geometric weights (ξ⋆, `geometric_leg_weights`) | Pre-existing future work; unchanged by this milestone |
| Layer-3 payoff cap `(σ²_R − σ²_K)⁺` | Pre-existing future work; unchanged by this milestone |
| Panoptic decoder helpers as diff *subjects* | They are read paths used *by* the test, not functions under test |
| Replacing the hand-ported `validate()` oracle | It stays as an independent structural check; the Haskell is added alongside, not swapped in |
| Local build/test as the validation path | CI (`develop-gate`) is the gate by project constraint |

## Traceability

Populated during roadmap creation (2026-08-27). Phase directories live at
`.planning/phases/FEATURES/feat-<slug>/` — see ROADMAP.md for slugs and branch names.

| Requirement | Phase | Status |
|-------------|-------|--------|
| RED-01 | Phase 1 — RED Differential Scaffold | Complete |
| RED-02 | Phase 1 — RED Differential Scaffold | Complete |
| RED-03 | Phase 1 — RED Differential Scaffold | Complete |
| RED-04 | Phase 1 — RED Differential Scaffold | Complete |
| RED-05 | Phase 1 — RED Differential Scaffold | Complete |
| RED-06 | Phase 1 — RED Differential Scaffold | Complete |
| PROC-01 | Phase 1 — RED Differential Scaffold | Complete |
| VORD-01 | Phase 2 — VolOrder(T) Minimal Instantiation | Complete |
| VORD-02 | Phase 2 — VolOrder(T) Minimal Instantiation | Complete |
| VORD-03 | Phase 2 — VolOrder(T) Minimal Instantiation | Complete |
| VORD-04 | Phase 3 — VolOrder(T) Rich Instantiation | Pending |
| VORD-05 | Phase 3 — VolOrder(T) Rich Instantiation | Pending |
| VORD-06 | Phase 4 — VolOrder(T) Wire Format | Pending |
| KEY-01 | Phase 2.5 — Venue-Tagged Market Key & Payload Widening | Complete |
| KEY-02 | Phase 2.5 — Venue-Tagged Market Key & Payload Widening | Complete |
| KEY-03 | Phase 2.5 — Venue-Tagged Market Key & Payload Widening | Complete |
| KEY-04 | Phase 2.5 — Venue-Tagged Market Key & Payload Widening | Complete |
| KEY-05 | Phase 2.5 — Venue-Tagged Market Key & Payload Widening | Complete |
| KEY-06 | Phase 2.5 — Venue-Tagged Market Key & Payload Widening | Complete |
| VORD-07 | Phase 2.5 — Venue-Tagged Market Key & Payload Widening | Complete |
| VORD-08 | Phase 3 — VolOrder(T) Rich Instantiation | Pending |
| RPC-01 | Phase 5 — RPC Design & Protocol Skeleton | Pending |
| RPC-02 | Phase 5 — RPC Design & Protocol Skeleton | Pending |
| RPC-03 | Phase 5 — RPC Design & Protocol Skeleton | Pending |
| SPEC-01 | Phase 6 — Haskell Spec Oracle | Pending |
| SPEC-02 | Phase 6 — Haskell Spec Oracle | Pending |
| SPEC-03 | Phase 6 — Haskell Spec Oracle | Pending |
| XPORT-01 | Phase 7 — Solidity↔Spec Transport | Pending |
| XPORT-02 | Phase 7 — Solidity↔Spec Transport | Pending |
| GUARD-01 | Phase 8 — Plank Guard Additions | Pending |
| GUARD-02 | Phase 8 — Plank Guard Additions | Pending |
| GUARD-03 | Phase 8 — Plank Guard Additions | Pending |
| GUARD-04 | Phase 9 — Guard Parity Assertion | Pending |
| GUARD-05 | Phase 9 — Guard Parity Assertion | Pending |
| DIFF-01 | Phase 10 — Passing Differential Test | Pending |
| DIFF-02 | Phase 10 — Passing Differential Test | Pending |
| CI-05 | Phase 1.1 — CI Feedback Loop | Complete |
| CI-06 | Phase 1.1 — CI Feedback Loop | Complete |
| CI-07 | Phase 1.1 — CI Feedback Loop | Complete |
| CI-01 | Phase 11 — develop-gate Enforcement | Pending |
| CI-02 | Phase 11 — develop-gate Enforcement | Pending |
| CI-03 | Phase 11 — develop-gate Enforcement | Pending |
| CI-04 | Phase 11 — develop-gate Enforcement | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35 ✓
- Unmapped: 0
- Duplicated across phases: 0

Phase distribution: P1=7, P1.1=3, P2=3, P3=2, P4=1, P5=3, P6=3, P7=2, P8=3, P9=2, P10=2, P11=4.

---
*Requirements defined: 2026-08-27 · Traceability populated: 2026-08-27*
