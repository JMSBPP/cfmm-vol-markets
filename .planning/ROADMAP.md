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
- **Worktree + issue per phase:** every phase starts with a git worktree named after its `feat/…`
  branch and a tracking issue on `develop`. No phase begins without both.
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
- **Review:** every plan passes the two-step review (Reality Checker + one matched specialist, in
  parallel) before execution.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: RED Differential Scaffold** - The first clean push: a compiling, skip-guarded `.diff.t.sol` with its doctrine and transport boundary
- [ ] **Phase 2: VolOrder(T) Minimal Instantiation** - `VolOrder` becomes a comptime constructor with today's output bit-identical
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
  5. `.planning/phases/FEATURES/feat-red-diff-scaffold/` exists on `develop`, establishing the
     FEATURES layout for the milestone.
**Plans**: 6 plans in 6 waves (strictly sequential — each wave's output is the next wave's input)

Plans:
- [x] 01-01-PLAN.md — worktree, tracking issue, and the FEATURES layout committed to `develop` (PROC-01)
- [ ] 01-02-PLAN.md — `SpecHelper.sol`: the reverting `readTokenId` stub, the `isWired` probe, the external probe boundary (RED-04)
- [ ] 01-03-PLAN.md — `VolOrderToPanopticTokenId.diff.t.sol`: doctrine, discipline, probe-skipped `assertEq(specTokenId, implTokenId)` (RED-01/02/03/05)
- [ ] 01-04-PLAN.md — `notes/DIFFERENTIAL_LAYOUT.md` + the `test-vol-order-tokenid-diff` make target (RED-06)
- [ ] 01-05-PLAN.md — PR into `develop`, `develop-gate` run, gate evidence harvested and confirmed (RED-01/05; has a checkpoint)
- [ ] 01-06-PLAN.md — merge to `develop`, verify criteria 4 and 5 against the merged tree, close out

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
  2. `develop-gate` is green on `feat/volorder-t-minimal`: the plank job compiles `VolOrder(T)`
     following the in-repo `Shock(R)` pattern, and the forge job runs the full existing suite.
  3. Every test classified *survives untouched* — including the golden vectors and fuzz cases in
     `VolOrderToPanopticTokenId.t.sol` — passes in that gate run with **no edits to those files**,
     making the minimal instantiation's `tokenId` bit-identical to today's
     `vol_order_to_panoptic_token_id`.
  4. Every eliminated or rewritten test is traceable to a decision from criterion 1. Nothing is
     deleted, weakened or `--skip`-ed merely to make the gate green; a coupled test that would have
     caught a real regression is replaced, not dropped.
  5. The plank job compiles `vol_order_to_mint`, `position_size_for_target_vega`,
     `vol_order_leg_split` and `VolOrderToPanopticTokenIdHarness.plk` against the minimal
     instantiation, and the differential test still compiles and still skips in the same run
     (Phase 1 state preserved).
**Plans**: TBD

### Phase 3: VolOrder(T) Rich Instantiation
**Directory**: `.planning/phases/FEATURES/feat-volorder-t-rich/`
**Branch**: `feat/volorder-t-rich`
**Goal**: A second instantiation carries what the Haskell map actually takes, and emits the tokenId
the Haskell would emit — closing the "not the same function" gap without breaking the first.
**Depends on**: Phase 2
**Requirements**: VORD-04, VORD-05
**Success Criteria** (what must be TRUE):
  1. `develop-gate` green: the plank job compiles **both** instantiations in the same run, the rich
     one carrying a 4-tuple of `optionRatio`s (each 1..127) and the `asset` bit.
  2. The forge job runs non-fuzz anchor cases showing the rich instantiation writes per-leg
     `optionRatio` from the tuple and `asset = 1` on all four legs, checked against the existing
     Panoptic `validate()` structural oracle (the Haskell oracle is not yet reachable).
  3. The same gate run still reports the minimal-instantiation golden vectors green.
  4. Choosing the rich instantiation changes only the `optionRatio`/`asset` fields — the strike,
     width, tokenType and pool-id bits are identical to the minimal instantiation for the same
     geometry, asserted in the gate.
**Plans**: TBD

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

**Execution Order:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. RED Differential Scaffold | 1/6 | In Progress | - |
| 2. VolOrder(T) Minimal Instantiation | 0/TBD | Not started | - |
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
| **Total** | | **32 / 32** |

No orphaned requirements. No requirement mapped to more than one phase.

---
*Roadmap created: 2026-08-27*
