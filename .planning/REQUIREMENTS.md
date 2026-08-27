# Requirements: Haskell↔Plank Differential Conformance

**Defined:** 2026-08-27
**Core Value:** A fuzzed input that produces a different `tokenId` in Haskell than in Plank must fail the build.

## v1 Requirements

Requirements for this milestone. Each maps to a roadmap phase.

### Differential Test Scaffold — the first clean push

- [ ] **RED-01**: `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` exists and compiles under `--via-ir`, alongside the existing structural suite and harness
- [ ] **RED-02**: The file carries the inherited `.diff.t.sol` doctrine header, oriented as **neither side sacrosanct** — a divergence is a finding about either implementation, adjudicated case by case, and neither the spec nor the Plank map may be bent merely to restore green
- [ ] **RED-03**: The test observes the established differential discipline — corpora **constructed** with `bound` rather than filtered with `vm.assume`, every fuzz backed by a non-fuzz anchor case, and non-vacuity asserted rather than assumed
- [ ] **RED-04**: `SpecHelper` exposes `readTokenId(…)` as a stub that reverts when called, **plus a wiring probe** the test queries first
- [ ] **RED-05**: The fuzz body is written against the real assertion (`assertEq(specTokenId, implTokenId)`) and guarded by `vm.skip` on the wiring probe, so the branch pushes clean through `develop-gate` with **no skip-ledger edit**
- [ ] **RED-06**: The organization — file layout, naming, and the Solidity↔spec transport boundary — is documented so later phases extend it rather than redesign it

### VolOrder(T) Refactor — blocking prerequisite

- [ ] **VORD-01**: `VolOrder` is a comptime type constructor `VolOrder(T)` carrying an `extra: T` payload, following the in-repo `Shock(R)` pattern
- [ ] **VORD-02**: The minimal instantiation produces a **bit-identical** `tokenId` to today's `vol_order_to_panoptic_token_id` for every input the current suite covers
- [ ] **VORD-03**: Existing callers — `vol_order_to_mint`, `position_size_for_target_vega`, `vol_order_leg_split`, `VolOrderToPanopticTokenIdHarness.plk` — compile and pass unchanged against the minimal instantiation
- [ ] **VORD-04**: A rich instantiation carries the data the Haskell map takes: a 4-tuple of `optionRatio`s (each 1..127) and the `asset` bit
- [ ] **VORD-05**: The rich instantiation emits the Haskell-equivalent `tokenId` — per-leg `optionRatio` from the tuple, `asset = 1` on all four legs
- [ ] **VORD-06**: `VolOrder(T)` has a defined serialization that carries *which* `T` was instantiated, decodable by a consumer from the bytes alone

### Spec Oracle (Haskell side)

- [ ] **SPEC-01**: The Haskell decodes the `VolOrder(T)` wire format into its own `VolOrder` + extra payload, so Plank-originated inputs drive the spec unmodified
- [ ] **SPEC-02**: The spec exposes `volOrderToTokenId` through an external entrypoint callable from outside the Haskell process
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

- [ ] **CI-01**: `develop-gate` checks out the `spec/` submodule
- [ ] **CI-02**: `develop-gate` builds the Haskell oracle on the self-hosted runner (GHC/cabal availability confirmed or provisioned)
- [ ] **CI-03**: The differential test executes and is **enforced** in `develop-gate` — it cannot silently skip
- [ ] **CI-04**: The interim `vm.skip` wiring guard from RED-05 is **removed** once the oracle is reachable, so the end state has no silent-skip path

### Planning Layout

- [ ] **PROC-01**: `.planning/phases/FEATURES/feat-*/` is adopted as the directory layout for this milestone's feature phases

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

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| RED-01 … PROC-01 | TBD | Pending |

**Coverage:**
- v1 requirements: 29 total
- Mapped to phases: 0
- Unmapped: 29 ⚠️

---
*Requirements defined: 2026-08-27*
