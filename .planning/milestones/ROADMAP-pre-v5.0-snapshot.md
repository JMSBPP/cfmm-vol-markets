# Roadmap: CFMM Payoff Replication — Plank ↔ GAMS Connection Layer (v1 Plumbing)

## Overview

This milestone builds the **open-loop plumbing** that carries a parameter set from a (stub) GAMS solver, through a defined encoding contract, into a compiled Plank write/read surface, and back out via a round-trip equality check — all bound to one authoritative kernel. The journey is deliberately ordered plumbing-first: first make the repository public-ready and canonical (Phase 1), then co-locate the GAMS sources and pin the toolchain and kernel both tracks conform to (Phase 2), then write the encoding contract and theory grounding the implementation and bridge both consume (Phase 3), then implement **and compile** the Plank bridge-surface BEFORE wiring it (Phase 4), then stand up the GAMS stub emitter (Phase 5), then wire the runtime bridge with read-back round-trip and selector conformance (Phase 6), and finally run the whole thing end-to-end behind hard guards (Phase 7).

This milestone proves the connection layer *carries parameters correctly* — it does **not** prove payoff replication, run a real optimization model, or assert LDF conformance; those are explicitly v2. This is an early research repo: most `.plk` sources are stubs or have parse/type errors, the Plank↔GAMS bridge is a zero-line gap, and the GAMS solver is intentionally a stub this milestone. The phases below assume nothing about working replication, a real optimization model, or LDF correctness.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Repository Restructure & Sanitize** - Canonical public `wvs-finance` repo, `JMSBPP` fork, and a publish-readiness scrub gating the public flip
- [ ] **Phase 2: Vendoring, Shared Kernel & Toolchain Pin** - GAMS vendored into `model/`, the bridge-path kernel fully specified, the Plank toolchain + submodules pinned with loud FFI guards
- [ ] **Phase 3: Encoding Contract & Theory Grounding** - The per-hop fixed-point encode/decode + ABI/storage-slot contract, plus the parameter→theory reference notes
- [ ] **Phase 4: Plank Bridge-Surface Implementation & Compile** - Implemented and cleanly-compiling Plank write body, struct read, and lens getters for every seeded field
- [ ] **Phase 5: GAMS Plumbing (stub solver)** - GAMS model runs from `model/` and emits the bridge-consumed parameter artifact with a stub objective
- [ ] **Phase 6: Open-Loop Runtime Bridge** - Serialize → encode → write → read-back round-trip equality, plus selector conformance
- [ ] **Phase 7: End-to-End Plumbing Run** - One command runs the full open-loop plumbing path, succeeding only if the FFI guards and round-trip pass

## Phase Details

### Phase 1: Repository Restructure & Sanitize
**Goal**: The project lives in the correct ownership topology — a canonical public `wvs-finance` upstream with a `JMSBPP` fork — and the tree is sanitized so nothing leaks or breaks when it goes public.
**Depends on**: Nothing (first phase). Outward-facing — the public flip and the destructive fork-migration step are confirmed with the user at execution.
**Requirements**: REPO-01, REPO-02, REPO-03, REPO-04, REPO-05
**Success Criteria** (what must be TRUE):
  1. `git grep -InE '/home/[a-z0-9_-]+/'` returns nothing; `refs/`, `node_modules`, and the `Counter` scaffold are absent from tracked files; and `.gitignore` covers `node_modules`/build artifacts (REPO-05).
  2. The public flip and the destructive fork-migration step (retire/rename the existing standalone `JMSBPP` repo) execute only after an explicit user confirmation, following a documented, reversible backup → create-canonical → retire → fork sequence with the destructive step called out (REPO-02, REPO-05).
  3. `git remote -v` shows `upstream` → `wvs-finance/cfmm-replicationPlank` and `origin` → the `JMSBPP` fork, and `wvs-finance/...` is reachable as a public repo that is the canonical upstream (REPO-01, REPO-03).
  4. `README.md` is no longer Foundry boilerplate and describes the Plank/GAMS dual-track plus setup (REPO-04).
  5. The broken CI is fixed or explicitly disabled so a fresh clone does not present a misleading red check at the public flip (REPO-05).
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Local sanitize (remove refs/, Counter, broken CI; scrub home paths; README + MIT LICENSE) and squash to one clean baseline (REPO-04, REPO-05)
- [ ] 01-02-PLAN.md — Gated irreversible migration: push baseline, transfer to wvs-finance, flip public, fork back to JMSBPP, set remotes (REPO-01, REPO-02, REPO-03)

### Phase 2: Vendoring, Shared Kernel & Toolchain Pin
**Goal**: Both tracks are co-located and reproducible — GAMS sources live inside the repo, the bridge-path type kernel is fully and unambiguously specified, and the Plank toolchain plus submodules are pinned with FFI guards that fail loudly.
**Depends on**: Phase 1 (serialized — no Phase 1∥Phase 2 parallelism, to avoid the repo-identity race the review flagged).
**Requirements**: GAMS-01, KERN-01, KERN-02, KERN-03, TOOL-01, TOOL-02
**Success Criteria** (what must be TRUE):
  1. ✓ **DONE (pre-completed)** — GAMS sources are tracked under `model/` and the pipeline references that path; residual `../experiments/gams` text references cleaned in the Phase 1 scrub (GAMS-01). Phase 2 carries only KERN-01..03 + TOOL-01..02 as remaining work.
  2. The FFI build asserts `plank --version` matches a pinned `.plank-version` (with the `sona` codegen backend declared) and fails loudly on mismatch; the deployer/`plankified-univ3` submodules are pinned to specific commits; and the deploy path asserts returned bytecode length > 0 and deployed address ≠ 0 (TOOL-01, TOOL-02).
  3. Every type on the enumerated bridge path — `VolatilityTermStructure` and its fields, plus the `NumberFormat`/`BoundedValue` they use — carries number format, bounds, and unit semantics with no placeholder bounds (the `baseTick` bound resolved to a concrete int24 range) (KERN-01).
  4. A concrete conformance mechanism (a generated shared constants file both sides include, or a checked field-by-field cross-reference) binds the Plank type and the GAMS symbols to one kernel definition — not prose alone (KERN-02).
  5. The kernel states the canonical fixed-point conventions (WAD `1e18`, Q64.96) using one canonical name for the Q64.96 format consistently (`Q64x96`/`Q64.96`/`Q96_ONE` reconciled) (KERN-03).
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Encoding Contract & Theory Grounding
**Goal**: The single source of truth for how every parameter crosses the boundary exists — a per-hop fixed-point encode/decode chain plus the ABI/storage-layout contract — and each mapped parameter is grounded to its theory note. This spec is consumed by both the Plank implementation (Phase 4) and the bridge (Phase 6).
**Depends on**: Phase 2 (kernel + fixed-point conventions).
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, MAP-06, REF-01, REF-02
**Success Criteria** (what must be TRUE):
  1. A GAMS↔Plank mapping table covers at least `xi`↔`priceElasticity`/LDF `alpha`, `iota`↔`statePartitionDelta`/`tickSpacing`, and `baseTick`, each with an explicit mapping direction (MAP-01).
  2. Each parameter has a documented per-hop encode/decode chain with scale base and rounding mode for every quantizing hop, and the `priceElasticity` upper bound is corrected so the type covers the full valid `alpha` range (resolving `Q96_ONE` < `MAX_ALPHA`) (MAP-02).
  3. Signed `baseTick` encoding is specified (int24 two's-complement sign-extended to `u256`, rounded to a `tickSpacing` multiple, within resolved int24 bounds) and a `tickSpacing` divisibility invariant for `tickLower`/`tickUpper` is enforced (MAP-03, MAP-04).
  4. The `initVolTermStructure` ABI + storage-layout contract is specified (signature string, ABI arg layout, on-storage bit-packing) with selector `0xd9c112ef` verified to equal `keccak(signature)[:4]`, and the write slot and simulator read slots are reconciled into declared slots with no undefined `SLOT_TICK_*` (MAP-05, MAP-06).
  5. Each mapped parameter has a reference markdown under `spec/protocol/refs/` citing its `cfmm-theory` grounding note (primary `KERNEL.md`) by URL/citekey with no code dependency on the theory tree, annotated with the behavioral theorem/assumption/regime it encodes (REF-01, REF-02).
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Plank Bridge-Surface Implementation & Compile
**Goal**: The actual Plank write body, struct read, and lens getters are implemented per the Phase 3 contract AND compile cleanly via the pinned FFI build — delivered BEFORE the bridge wiring so the wiring has a real surface to call. This fixes the prior phase-order inversion BLOCKER.
**Depends on**: Phase 3 (the layout/encoding/slot contract).
**Requirements**: PLNK-01, PLNK-02, PLNK-03, PLNK-04
**Success Criteria** (what must be TRUE):
  1. `src/types/VolatilityTermStructure.plk` has a working `read` that decodes the stored struct per the MAP-05 layout (PLNK-01).
  2. `IMarketDynamics.initVolTermStructure` has an implemented body that decodes calldata and stores into the reconciled MAP-05/MAP-06 slot — not just a selector constant (PLNK-02).
  3. `IMarketDynamicsLens` getters `getPriceElasticity`, `getStatePartitionDelta`, and `getBaseTick` are implemented, providing a read-back view for every seeded field (PLNK-03).
  4. All Plank sources on the bridge/pipeline path compile cleanly via the pinned FFI build — the parse/type stubs (`SELECTOR_… =;`, untyped fields, `uint256` vs `u256`, the `u265` typo) blocking the path are fixed (PLNK-04).
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

### Phase 5: GAMS Plumbing (stub solver)
**Goal**: The GAMS side produces the artifact the bridge consumes, running from the vendored location with a stub objective — enough to feed the pipe, no real optimization.
**Depends on**: Phase 2 (vendored sources), Phase 3 (knows the output shape/encoding to emit).
**Requirements**: GAMS-02
**Success Criteria** (what must be TRUE):
  1. The GAMS model runs from `model/` and exits successfully using a stub/placeholder objective (a trivial or fixed map is acceptable this milestone) (GAMS-02).
  2. The run emits the parameter-output artifact in the shape/encoding the Phase 3 contract defines for the bridge to consume (GAMS-02).
  3. The stub objective is clearly marked as such; no real optimization model is present, and the real model remains a v2 (`PAY-01`) deferral (GAMS-02).
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

### Phase 6: Open-Loop Runtime Bridge
**Goal**: The connection layer is wired — GAMS output is serialized, encoded per contract, written to the compiled Plank surface, and read back with a round-trip equality and selector-conformance check. This is the open-loop bridge: no in-loop parameter updates.
**Depends on**: Phase 3 (encoding contract), Phase 4 (compiled Plank write/read surface), Phase 5 (GAMS output to serialize).
**Requirements**: BRDG-01, BRDG-02, BRDG-03, BRDG-04
**Success Criteria** (what must be TRUE):
  1. GAMS output is serialized to a defined exchange format (e.g., JSON or ABI-encoded calldata) that the Plank side consumes (BRDG-01).
  2. A bridge step encodes the parameters per the MAP-02 contract and writes them via `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`) (BRDG-02).
  3. The seeded parameters are read back through the lens views and a round-trip equality holds — `decode(readback) ≈ original` within the stated quantization tolerance — for every seeded field (BRDG-03).
  4. A selector-conformance test asserts each Plank selector constant on the path equals `keccak(documented signature)[:4]` (BRDG-04).
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

### Phase 7: End-to-End Plumbing Run
**Goal**: A single command runs the full open-loop plumbing path end-to-end and is honest about success — it passes only if the guards and round-trip pass, and the simulate step does no closed-loop updates.
**Depends on**: Phase 6.
**Requirements**: PIPE-01, PIPE-02
**Success Criteria** (what must be TRUE):
  1. One command runs payoff spec → (stub) GAMS solve → encode → Plank write → read-back, end-to-end (PIPE-01).
  2. That command exits success only if the TOOL-02 FFI guards (bytecode length > 0, address ≠ 0) and the BRDG-03 round-trip pass, and exits non-zero (fails loudly) otherwise (PIPE-01).
  3. An open-loop guard asserts the swap-replay/simulate step performs no in-loop parameter updates, keeping the closed-loop controller out of this milestone (PIPE-02).
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

## Progress

**Execution Order:**
Phases execute strictly in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7. No Phase 1∥Phase 2 parallelism (repo-identity race).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Repository Restructure & Sanitize | 0/TBD | Not started | - |
| 2. Vendoring, Shared Kernel & Toolchain Pin | 0/TBD | Not started | - |
| 3. Encoding Contract & Theory Grounding | 0/TBD | Not started | - |
| 4. Plank Bridge-Surface Implementation & Compile | 0/TBD | Not started | - |
| 5. GAMS Plumbing (stub solver) | 0/TBD | Not started | - |
| 6. Open-Loop Runtime Bridge | 0/TBD | Not started | - |
| 7. End-to-End Plumbing Run | 0/TBD | Not started | - |

## Coverage

All 30 v1 requirements in REQUIREMENTS.md are mapped to exactly one phase:

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | REPO-01, REPO-02, REPO-03, REPO-04, REPO-05 | 5 |
| 2 | GAMS-01, KERN-01, KERN-02, KERN-03, TOOL-01, TOOL-02 | 6 |
| 3 | MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, MAP-06, REF-01, REF-02 | 8 |
| Complete    | 2026-07-16 | 4 |
| 5 | GAMS-02 | 1 |
| 6 | BRDG-01, BRDG-02, BRDG-03, BRDG-04 | 4 |
| 7 | PIPE-01, PIPE-02 | 2 |

**Total mapped: 30/30** — no orphans, no duplicates.

## Scope Boundary

This is **open-loop plumbing only**. Explicitly out of this milestone (v2):
- Correct payoff **replication** proof, replication-error metric + tolerance (`PROOF-*`)
- Real GAMS optimization model — Phase 5 is a **stub objective** (`PAY-01`)
- LDF conformance / `SwapAmtGen` overflow fix (`LDF-*`)
- Closed-loop adaptive controller + V4 `beforeSwap` hook (`CTRL-*`) — Phase 7's PIPE-02 guard actively keeps in-loop updates out
- Production / mainnet deployment, multiple-payoff library (`PLIB-01`), formal literature review (`RIG-01`), secure on-chain randomness (`RIG-02`)

## Deferred Review Findings (do NOT block roadmap; resolve during phase planning)

The two-step review confirmed all original BLOCKERs/MAJORs resolved. The following finer findings were surfaced on the revised roadmap and are **deferred to phase planning** (by user direction — not blocking initialization):

- **Selector `0xd9c112ef` is likely wrong** (Phase 3 / MAP-05, Phase 6 / BRDG-02): no plausible `initVolTermStructure` signature reproduces it. At Phase 3, treat the kernel-derived **signature string as authoritative**, recompute the selector, and correct the constant; reference all path selectors symbolically. Extend the signature pinning to the lens getters (BRDG-04).
- **Single quantization boundary** (Phase 3 / MAP-02, Phase 5 / GAMS-02, Phase 6 / BRDG-01): decide one place that does fixed-point encoding — recommended: **GAMS emits raw decimals, the bridge owns all encoding** — and define the off-chain exchange format in Phase 3 so Phase 5 emits against it.
- **Round-trip should be exact** (Phase 6 / BRDG-03): with the replication metric descoped to v2, require **exact equality on the stored integer** for `{priceElasticity, statePartitionDelta, baseTick}` via the lens (hop-1 only); drop the `≈`/tolerance language and the `/LDF` read-back (LDF is a v2 stub).
- **REPO-05 verification** (Phase 1): scan tracked file **contents** (`git grep -InE '/home/[a-z0-9_-]+/'`), not filenames; relativize/URL-ify the local home-absolute paths in `.planning/` docs; vendor GAMS (GAMS-01) before the public flip so no `../experiments/gams` path remains.
- **PIPE-02** (Phase 7): the v1 e2e path has no simulate-update step — phrase the open-loop guard as a **structural** assertion (no controller/update code on the path), not a runtime guard on a non-existent step.
- **Minor:** pin the concrete scale base for `alpha`/`priceElasticity` (MAP-02); add Phase 4 `Depends on: Phase 2`; define the PIPE-01 "payoff spec" as a fixed v1 input fixture; for KERN-02 prefer the checked field-by-field cross-reference (GAMS `$include` and Plank `import` can't share one file).

---

# Milestone v2.0 — Realized-Volatility Oracle Differential Testing

## Overview

This is a **separate, parallel track** from the v1.0 GAMS-plumbing milestone above (Phases 1–7, which remain intact and are not renumbered). It finishes the **variance half** of the Plank realized-volatility oracle's differential proof against **Algebra's `VolatilityOracle` — the reference of record**. The tick-average surface (`getTwapTick` / `getTickCumulative`, three-way exact vs Algebra + UniV3) is DONE and merged (Phase 0–1 of `.planning/plank-voldiff-plan.md`). What remains is proving `volatilityCumulative` and `averageTick` bit-exact.

Phase numbering **continues at Phase 8**. These four phases derive solely from the v2.0 requirements **VDIFF-01..08** in `REQUIREMENTS.md` and formalize Phases 2/3/3b/4 of the two-review-passed `plank-voldiff-plan.md`.

**Hard constraints honored throughout (from PROJECT.md + plank-voldiff-plan.md):**
- **`make compile-plank` passing is NOT evidence** — Plank does not type-check code unreachable from `run{}`. A test only proves something by CALLING the module. Every success criterion below is a passing/failing test or a killed mutation, never "compiles."
- **Every new test MUST be mutation-verified falsifiable before it is trusted** (VDIFF-08). A prior reviewer found 3 of 6 smoke tests survived deliberate bugs. This falsifiability gate is embedded in the success criteria of every test-producing phase (9, 10, 11), not deferred to a single phase.
- **The differential reference is a mutable, untracked `node_modules` file** — pinning it (VDIFF-01) comes FIRST (Phase 8) so every later phase builds on a stable baseline.
- **The corpus is CONSTRUCTED, not `vm.assume`-filtered** (VDIFF-05/06); `span > 2×WINDOW` is required to execute `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` INSIDE `write_timepoint`, and a separate sub-WINDOW corpus is the only regime that reaches `u32_sub`.
- **The volatility diff is Algebra-vs-Plank ONLY** — UniV3 has no volatility accumulator, so its ref is NOT driven in the vol corpora (avoids ~11.5M gas/run of unused work). This is where v2.0 differs from the merged tick-average diff (which was three-way).
- **Tolerance-0 is regime-conditional and guaranteed within it.** Both reviewers confirmed bit-exactness over int24 ticks × uint32 spans (kernel numerator peaks ~2^149 ≪ 2^256; `@evm_sdiv` == Solidity `/`; max |tickCumulative| ≈ 3.8e15 < int56 max 3.6e16). It is NOT claimed in Algebra's deliberate int56-overflow regime (Plank's full-width in-flight accumulator doesn't replicate the `int56` wrap there) — the type bounds keep the corpus out of that regime, and `dt=0` is excluded from the kernel fuzz (Solidity reverts, SDIV returns 0).
- **Build on existing infrastructure, do not re-create it:** `PlankTestBase.sol`, the Algebra + UniV3 refs (`getTimepoint`/`lastIndex`/`oldestIndex`/`getTickCumulative`), Plank's `getTimepointPacked`/`lastIndex`/`oldestIndex`/`readWindow`, the Phase 0–1 driver `test/market_state_measurements/RealizedVolatility.diff.t.sol`, and the `make test-vol-prereqs` target.

## Phases

- [x] **Phase 8: Reference Integrity & Kernel Mock** - Pin the WHOLE Algebra baseline closure (plugin impl + storage lib + transitive) against silent `npm ci` swaps, stand up a distinctly-named mock exposing `_volatilityOnRange` (probe-diffed vs Plank), and remove the one wrong raw-vs-normalized scalar-vol assertion (window-normalized `getAverageVolatility` port deferred) (completed 2026-07-16)
- [x] **Phase 9: Variance Kernel Unit-Diff & Full-Timepoint Diff** - Fuzz `calculate_realized_volatility` vs Algebra's `_volatilityOnRange` for exact **full-uint256** equality (NOT uint88 — 09-01 showed the arg-order divergence lives in the high bits a uint88 compare discards), and after every write assert Algebra-vs-Plank agree field-by-field on the stored timepoint — each mutation-verified falsifiable (completed 2026-07-16)
- [ ] **Phase 10: Discriminating Corpora (span>2×WINDOW + sub-WINDOW)** - Construct the `span > 2×WINDOW` corpus that actually exercises the binary search / interpolation / `window_start_index`, plus a distinct sub-WINDOW corpus for the `u32_sub` regime — both non-vacuous and mutation-verified
- [ ] **Phase 11: Edges, Mutation Battery & Make Wire-Up** - Edge cases (dt-too-old revert, same-block idempotency, uint32 wrap, ring wrap via `vm.store`), the full mutation battery proving every new test falsifiable, and the suite folded into `test-vol-prereqs`

## Phase Details

### Phase 8: Reference Integrity & Kernel Mock
**Goal**: The differential baseline can no longer move under the suite, the internal variance kernel is callable in isolation, and the one wrong scalar-vol assertion is removed — so every later diff compares like-for-like against a stable reference. (Retitled from "…& Scalar-Vol Reconciliation": both reviewers flagged that porting Algebra's window-normalized `getAverageVolatility` is production work + redundant with VDIFF-04, so VDIFF-03 is descoped to a deletion+doc, and the port is deferred.)
**Depends on**: Phase 0–1 (merged tick-average diff + `RealizedVolatility.diff.t.sol` driver). First v2.0 phase.
**Requirements**: VDIFF-01, VDIFF-03
**Success Criteria** (what must be TRUE):
  1. The pin covers the WHOLE baseline the harness links — `VolatilityOraclePluginImplementation.sol` (the delegatecall target driving Algebra in VDIFF-04), `libraries/VolatilityOracle.sol`, `libraries/VolatilityOracleStorage.sol`, and their transitive imports — vendored under `lib/` or checksum/tarball-pinned. A build/CI check FAILS LOUDLY when the `node_modules` copy diverges — verified by deliberately editing a reference file and observing red. (VDIFF-01)
  2. A mock with a DISTINCT name (the package already ships a `MockVolatilityOracle` — do not shadow it) wraps Algebra's `internal pure` `_volatilityOnRange` (storage-free, value args — trivially exposable) as an external function, compiling under `solc =0.8.20`. A probe DIFFERENTIALLY asserts the mock's output against Plank's `calculate_realized_volatility` on a non-degenerate input (`tick0 ≠ tick1`, `b ≠ 0`) — proving it is CALLED and correct in one shot, not merely returns nonzero. (VDIFF-01 scaffolding)
  3. The incorrect assertion diffing Plank's raw `get_average_volatility` accumulator against Algebra's window-normalized `getAverageVolatility` is REMOVED, and the test file documents they are different quantities (Algebra's is Bessel-corrected + WINDOW-normalized). Any scalar vol check instead uses the stored `volatilityCumulative` field (VDIFF-04). Porting Algebra's `getAverageVolatility` to Plank is DEFERRED to a follow-on. (VDIFF-03)
**Plans**: 3 plans (2 waves)

Plans:
- [ ] 08-01-PLAN.md — Pin the 4-file Algebra reference closure via a sha256 manifest + closure-drift guard; wire into `make test-vol-prereqs`; PROVE red on divergence with 3 observed mutants (VDIFF-01) [wave 1]
- [ ] 08-02-PLAN.md — `AlgebraVolatilityKernelMock` exposing `_volatilityOnRange` + a Plank harness for `calculate_realized_volatility` + a non-degenerate differential probe (tolerance 0, k!=0, b!=0) (VDIFF-01 scaffolding) [wave 2, depends 08-01]
- [ ] 08-03-PLAN.md — Remove the raw-vs-window-normalized scalar-vol diff surface and document why the quantities differ; no `getAverageVolatility` port (VDIFF-03) [wave 1]

**Planning note (VDIFF-03):** the "incorrect assertion" this phase was chartered to delete does
not exist in the tree — the planner grepped every `.sol`/`.plk` under `test/` and `src/` and found
no site diffing Plank's raw `get_average_volatility` against Algebra's window-normalized
`getAverageVolatility`. What DOES exist is the surface that invites it: an unused
`getAverageVolatility` declaration in `RealizedVolatilitySmoke.t.sol`'s `IRealizedVolatility`
(declared, never called), one `assertEq` from the mistake. 08-03 removes that surface and documents
the trap — the faithful reading of VDIFF-03's intent against the actual code.

### Phase 9: Variance Kernel Unit-Diff & Full-Timepoint Diff
**Goal**: The variance kernel is proven bit-exact against Algebra in isolation, and the full stored timepoint is proven bit-exact after every write in the shared-driver sequence — with both proofs demonstrated falsifiable, not merely green.
**Depends on**: Phase 8 (pinned reference, `MockVolatilityOracle`, reconciled scalar getter).
**Requirements**: VDIFF-02, VDIFF-04
**Success Criteria** (what must be TRUE):
  1. A fuzz test drives `(dt, tick0, tick1, avgTick0, avgTick1)` through both the mock's `_volatilityOnRange` and Plank's `calculate_realized_volatility` and asserts exact equality (`assertEq`, tolerance 0), with `dt` bounded to `[1, 2^32)` (excluding the known `dt=0` divergence: Solidity `/` reverts even under `unchecked`, EVM SDIV returns 0) and ticks bounded to int24. Assert the full **uint256** return, not just uint88 — strictly stronger on a free axis. Tolerance-0 is GUARANTEED here (numerator peaks ~2^149 ≪ 2^256; SDIV == Solidity `/`; uint88 mask-after-add ≡ truncate-before-add), not merely hoped. (VDIFF-02)
  2. The kernel test guards the known parameter-order footgun (`(avg0,avg1,t0,t1,dt)` vs Algebra's `(dt,t0,t1,avg0,avg1)`): a mutant that swaps the call-site argument order is KILLED by the test (VDIFF-02, VDIFF-08 gate).
  3. Using an **Algebra-vs-Plank-only** driver against the same sequence (the UniV3 ref is NOT driven — it has no volatility surface), after EVERY write Algebra and Plank agree exactly (field-by-field `assertEq`, tolerance 0) on `volatilityCumulative`, `averageTick`, and `windowStartIndex` — read via `getTimepoint` (Algebra) and `getTimepointPacked` (Plank, needs test-side unpack of the vol@32 / avgTick@144-signed / windowStartIndex@224 offsets), NOT a Solidity storage mirror. `oldestIndex` is EXCLUDED: it is vacuously `0` on both sides below 2^16 writes, so this corpus cannot exercise it (covered Plank-side in Phase 11). (VDIFF-04)
  4. The falsifiability gate holds for this phase: mutating the volatility-kernel coefficient (`6→7`), corrupting the timepoint packing, and stopping `volatilityCumulative` accumulation each make at least one Phase 9 assertion FAIL; baseline and restored source are green (VDIFF-08 embedded).
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

### Phase 10: Discriminating Corpora (span>2×WINDOW + sub-WINDOW)
**Goal**: The windowed paths the existing assertions never touch — `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` selection INSIDE `write_timepoint` — plus the `u32_sub` regime, are executed by constructed, non-vacuous corpora feeding the Phase 9 Algebra-vs-Plank full-timepoint diff. (Note: the Phase-0/1 test already drives `binary_search_timepoints` and `tick_cumulative_at` interpolation via interior `dt`; what it never touches is the `volatilityCumulative`/`averageTick`/`windowStartIndex` fields — do not claim the binary search itself is new coverage.)
**Depends on**: Phase 9 (the full-timepoint diff driver the corpora feed).
**Requirements**: VDIFF-05, VDIFF-06
**Success Criteria** (what must be TRUE):
  1. The corpus is CONSTRUCTED via `bound(...)` (per-write delta forcing total span > 2×WINDOW) with NO `vm.assume` conjunction, driving **Algebra + Plank only** (no UniV3 — the vol surface has no UniV3 counterpart, and driving its ~11.5M-gas ring is pure cost). The test body asserts `span > 2*WINDOW`. No `uniV3.lastIndex()+1 < 512` guard and no 512 write-cap — those were UniV3 artifacts. (VDIFF-05)
  2. The corpus forces ≥1 strict tick rise and ≥1 strict fall BY CONSTRUCTION (seeded indices, never rejection), so `avg_tick != tick` and the kernel's `k`/`b` are non-zero — the assertions are non-vacuous — and keeps strictly-increasing distinct timestamps (`delta ≥ 1`, on which the heuristic-free `window_start_index` equivalence depends). (VDIFF-05)
  3. Coverage of `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` selection is evidenced SOLELY by a targeted mutant in those paths being KILLED by this corpus — `forge coverage` cannot instrument FFI-deployed Plank bytecode under via-IR, so a coverage/trace check is NOT an option. The chosen mutant must be one the ≤~49-min Phase-0/1 corpus does NOT already kill (else false confidence). (VDIFF-05, VDIFF-08 gate)
  4. A SEPARATE sub-WINDOW corpus (`init_timestamp in [0, WINDOW)`, few writes, kept distinct from the span>2×WINDOW corpus) exercises the `u32_sub` regime, and a mutant deleting `u32_sub`'s 32-bit mask is KILLED by it. (VDIFF-06, VDIFF-08 gate)
**Cost note**: the span>2×WINDOW corpus (Algebra+Plank only) is the heavy one; keep it OFF the default gate if 256-run wall-clock is prohibitive — expose it as its own `make` target and fold a bounded-run variant into `test-vol-prereqs`.
**Plans**: TBD

Plans:
- [ ] 10-01: TBD

### Phase 11: Edges, Mutation Battery & Make Wire-Up
**Goal**: The edge behaviors agree across implementations, the whole new suite is proven falsifiable by an explicit mutation battery before any green is trusted, and it runs as part of `test-vol-prereqs`.
**Depends on**: Phase 9 and Phase 10 (the battery covers every new test; wire-up folds them all in).
**Requirements**: VDIFF-07, VDIFF-08
**Success Criteria** (what must be TRUE):
  1. Edge tests pass across Algebra and Plank: a lookback older than the oldest retained timepoint reverts on BOTH (bare `vm.expectRevert()`, since revert data differs); a same-block double write is idempotent (no second timepoint, no revert); a uint32 timestamp wraparound is handled by a SEPARATE hand-built test near `type(uint32).max` (the [1e6,3e6] corpus cannot reach it); and ring-buffer wrap is asserted by a **Plank-only** unit test that `vm.store`s the index to 65535 and writes once (NOT 65536 writes; NOT a differential — Algebra's library ring cannot be cheaply forced to a near-wrap state) (VDIFF-07).
  2. An explicit mutation battery is defined and EVERY mutant is KILLED before any green is reported: deliberate bugs in the variance kernel, the packing, and the accumulator (plus the `u32_sub` mask and the `@evm_signextend` corrections) each fail at least one test; baseline and restored source are green (VDIFF-08).
  3. The full v2.0 diff suite is wired into a `make` target folded into `test-vol-prereqs`, and `make test-vol-prereqs` runs it green under `--via-ir --optimize` (VDIFF-08).
  4. No test trusted by the suite is constant-tick-only or `tick == 0`-vacuous, and each new test names in-file the mutation it kills (falsifiability discipline; VDIFF-08).
**Plans**: TBD

Plans:
- [ ] 11-01: TBD

## Progress (Milestone v2.0)

**Execution Order:** Phases execute strictly in numeric order: 8 → 9 → 10 → 11. Reference integrity and the kernel/full-timepoint diff are prerequisites for the corpus work, which is a prerequisite for the edge + mutation-battery wire-up.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 8. Reference Integrity & Kernel Mock | 3/3 | Complete | 2026-07-16 |
| 9. Variance Kernel Unit-Diff & Full-Timepoint Diff | 2/2 | Complete | 2026-07-16 |
| 10. Discriminating Corpora (span>2×WINDOW + sub-WINDOW) | 0/TBD | Not started | - |
| 11. Edges, Mutation Battery & Make Wire-Up | 0/TBD | Not started | - |

## Coverage (Milestone v2.0)

All 8 VDIFF requirements map to exactly one phase:

| Phase | Requirements | Count |
|-------|--------------|-------|
| 8 | VDIFF-01, VDIFF-03 | 2 |
| 9 | VDIFF-02, VDIFF-04 | 2 |
| 10 | VDIFF-05, VDIFF-06 | 2 |
| 11 | VDIFF-07, VDIFF-08 | 2 |

**Total mapped: 8/8** — no orphans, no duplicates.

## Scope Boundary (Milestone v2.0)

Reference of record is Algebra's `VolatilityOracle`. Explicitly deferred (plan items 6–7): a Uniswap-V3 `OracleLib`-based volatility reference — UniV3's `Oracle` has no native volatility accumulator, so it would re-derive Algebra's own `_volatilityOnRange` on the same tick data and diff against itself (low value). `volatilityCumulative` / `averageTick` diffs are Algebra-vs-Plank only.

---

# Milestone v3.0 — VegaAccountMod Vault (H1 Issuance, Exogenous Risk Price)

✅ **SHIPPED 2026-07-19** — Phases 12–15, 7/7 plans, 13/13 requirements (RISK-01/02, VLIB-01..04, VMOD-01..05, VVER-01/02), every phase verified with an independent mutant re-kill. `VegaAccountMod.plk` is a live, proven deposit-only vault; `PLANK_SKIP` is empty; `make compile` 11 ok/0/0; `make test` 74 pass / 4 pre-existing pos_spec fails.

Full phase details: `.planning/milestones/v3.0-ROADMAP.md` · Summary: `.planning/MILESTONES.md` · Tag: `v3.0`

Deferred to future milestones: withdraw/redeem + per-account ledger, distance pipeline D2, P0/P2 risk-price composition, stateful setHaircut, oracle wiring to RealizedVolatilityMod (with setter auth), `p_vol(σ̄)` from pos_spec.

---

# Milestone v4.0 — VolOrderManagerMod + Best-Effort Multicall

## Overview

Peer-requested by the rpc_api Haskell track (`mv15a18k`): their `StochasticOrderGen` (Poisson order-arrival generator) needs an on-chain vol-order REGISTRY plus a BEST-EFFORT batch entrypoint. This milestone builds `VolOrderManagerMod.plk` — `create_order` (validate → pack → sequential id → derived-slot store, NO pricing) and `create_orders` (N of the same in one tx, invalid tuples skipped rather than reverting the batch).

Phase numbering continues at 16 (v3.0 ended at 15). v1.0 Phases 1–7 and v2.0 Phases 10–11 are other tracks, paused, untouched, never renumbered.

**THIS SECTION IS POST-REVIEW.** A two-step parallel review (Reality Checker + Solidity Smart Contract Engineer) found **2 BLOCKERs and 6 MAJORs** in the pre-review draft. All are resolved; the decisions are recorded in REQUIREMENTS.md and restated here. What the review caught, because it explains why several criteria below look unusually specific:

1. **The packed layout was transcribed backwards.** The draft claimed `skew|strike|width @ 0/16/104, bits 128-151 zeroed`. `VolOrder.plk:35-40` is actually `width@128 | tickSpacing@104 | strike@16 | skew@0` — so "store the low 128 bits" would have kept tickSpacing and **silently dropped `width`**, the field every caller supplies and the validator checks. Resolved: store the FULL 152-bit word via the existing `pack_vol_order` verbatim, with `TICK_SPACING = 20` pinned as a module constant.
2. **The batch guard formula assumed a flat calldata layout** incompatible with any standard ABI encoder (a `uint256[]` param has an offset word the guard never validated — leaving the phantom-order hole the guard existed to close). Resolved: standard ABI `create_orders(uint256,uint256[])` = `0x81357911`, three independent guards.
3. **A "reduced width check" would have made the composed validator identically false** (`vol_range_width_is_complete` ANDs `tickSpacing > 0`, so a zeroed tickSpacing rejects 100% of traffic — under which the flagship totality fuzz passes trivially with all-fail results and looks green). Resolved by (1): with tickSpacing pinned to 20, the predicate is reused as-is.
4. **`tick_volatility_is_complete` is only `vol > 0`** — no upper bound — so an oversized strike passes validation and is then silently masked to 88 bits by `pack_vol_order`. A NEW `strike <= 2^88-1` bound must be authored; Phase 16 is therefore NOT "no new mechanism."
5. **The named precedent does not contain what was claimed of it.** `merkle_airdrop.plk` demonstrates the runtime `while` and the computed-offset `@evm_calldataload` (input side) — its three returns are 32/32/0 bytes. There is **no dynamic-array return precedent anywhere in this repo**, and `@evm_calldatasize` has **zero usages** in `src/`. The novel half of the batch has no precedent at all, which is why Phase 18 is split.

**Hard constraints (project-wide, enforced in every phase below):**
- **"It compiles" is NEVER acceptance.** `plank build` does not type-check code unreachable from `run{}`. Every criterion is a CALLED test outcome, a command exit, or an OBSERVED RED.
- Runtime `while` only — `inline while` (comptime unroll) is parsed but REJECTED by the lowerer (`lowerer/mod.rs:728`); do not design around it.
- Best-effort = pure-validation skip, NOT self-call containment. Strict and batch paths call the SAME `validate_order`.
- `array_slot` reused verbatim; the ring's index mask (in `StorageIndex.plk`) explicitly NOT imported.
- Corpora CONSTRUCTED, never `vm.assume`-filtered. ONE test file per surface. Non-fuzz anchor beside every fuzz. A `runs: 0` kill is a replay, not proof.
- Every forge invocation: `--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` (untracked stray from PR #11's track; the skip is a no-op once they remove it).
- The mutation-falsifiability gate is embedded in EVERY test-producing phase (16, 17, 18a, 18b, 19) — not deferred to the last one.

## Phases

- [x] **Phase 16: Type Packing & Validation Foundation** - Pure `validate_order` lib (reused predicates + the NEW strike upper bound) over the verbatim 152-bit `pack_vol_order`, proven falsifiable through a 4-selector FFI harness (VORD-02) (completed 2026-07-20)

  > Correction, recorded at execution: the original "proven falsifiable with no FFI deploy" was FALSE — Plank does not type-check code unreachable from `run{}`, so a pure lib with no harness is unprovable. The harness was a required deliverable, not optional scaffolding (16-CONTEXT.md).
- [x] **Phase 17: Interface & Single-Call Module** - `create_order` CALLED-green: validate via lib, pack via type with `TICK_SPACING` pinned, sequential id, unmasked derived-slot store, readers, cast-sig-pinned selectors for BOTH entrypoints (VORD-01, VORD-03, VORD-04, VORD-05) (completed 2026-07-20)
- [x] **Phase 18a: Batch Input & State Effects** - Standard-ABI decode behind three guards, bounded `while`, validation-skip, MAX_BATCH, totality by structural enumeration + corroborating fuzz, zero-footprint proof — returns ONE word, so state effects are proven without trusting any encoder (MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06) (completed 2026-07-20)
- [x] **Phase 18b: Typed Return Encoding** - The hand-rolled `(bool,uint256)[]` head/tail encoder (head `0x40`, stride `0x40`, total `64+64N`), N=0 edge, byte-level differential against `abi.encode` (MCAL-05) (completed 2026-07-21)
- [x] **Phase 19: Differential, Mutation Battery & Consumer Fixture** - Full reference-mock differential, observed-RED battery, consumer golden fixture, CALLED-green batch dispatch through FFI-deployed bytecode (MVER-01..04) (completed 2026-07-21)

## Phase Details

### Phase 16: Type Packing & Validation Foundation
**Goal**: The pure validation surface exists and is proven falsifiable in isolation — reusing the two sound predicates verbatim, authoring the one bound that is genuinely missing, over the existing 152-bit packer used AS-IS. **Correction to the pre-review draft:** this phase DOES require an FFI-deployed harness. The research claimed pure libs are "independently fuzz-testable with no FFI deploy" — that is false for Plank: there is no path from Foundry to a `.plk` pure function except `deployPlank` through a `run{}` entrypoint, and `plank build` does not type-check anything unreachable from `run{}`. Phase 13's harness header states this explicitly. A `VolOrderValidationHarness.plk` is therefore a deliverable of this phase.
**Depends on**: Nothing new (first v4.0 phase).
**Requirements**: VORD-02
**Success Criteria** (what must be TRUE):
  1. A constructed fuzz over `validate_order` CALLS the accept/reject boundary and at least one tuple is ACCEPTED (a validator that rejects everything must FAIL this phase — that is exactly the failure mode the pre-review draft would have shipped). Skew boundaries asserted at all four points: 0 REVERTS, 1 ACCEPTED, 65534 ACCEPTED, 65535 REVERTS (VORD-02).
  2. The NEW `strike <= 2^88-1` bound rejects an oversized strike that the existing `tick_volatility_is_complete` (`vol > 0`, no upper bound) would accept — asserted as a value that would otherwise be SILENTLY MASKED by `pack_vol_order` to a different stored value (VORD-02).
  3. `pack_vol_order` / `unpack_vol_order` round-trip at tolerance 0 over the constructed corpus with `TICK_SPACING = 20` in the tickSpacing field, confirming the byte-exact layout `width@128 | tickSpacing@104 | strike@16 | skew@0` — the type file is used VERBATIM, not modified (it is owned by the vol-type track, which has 4 red harness tests of its own) (VORD-02).
  4. **Mutation gate:** deleting the new strike bound, and flipping either skew boundary comparison (`>` ↔ `>=`), EACH produce an OBSERVED RED (cache cleared or killed by the non-fuzz anchor); restored byte-identical → green (VORD-02).

**Note:** This phase AUTHORS a new predicate. The pre-review draft classified it "standard pattern, no new mechanism" — that was wrong and is corrected here.

**Plans**: 1 plan (1 wave)

Plans:
- [ ] 16-01-PLAN.md — Pure `VolOrderValidationLib` (two predicates reused verbatim + the authored `strike <= 2^88-1` bound, `TICK_SPACING = 20` pinned, bool core + reverting wrapper), its FFI `VolOrderValidationHarness.plk`, the CALLED-green boundary/strike/round-trip suite, and a six-mutant observed-RED gate (VORD-02) [wave 1]

### Phase 17: Interface & Single-Call Module
**Goal**: `create_order` is a live, CALLED-green registry entrypoint — the base case the batch will compose N times — with both selectors pinned so the peer contract cannot drift silently.
**Depends on**: Phase 16 (the validation lib it calls).
**Requirements**: VORD-01, VORD-03, VORD-04, VORD-05
**Success Criteria** (what must be TRUE):
  1. `create_order(uint88,uint24,uint16)` is CALLED through FFI-deployed bytecode: `orderCount` advances 0→1, and raw `vm.load(array_slot(SLOT_ORDERS_BASE, 1))` decodes to the exact submitted tuple with `TICK_SPACING = 20` in its field — proving the store path end-to-end without trusting any getter (VORD-01, VORD-04).
  2. An invalid tuple REVERTS and leaves `orderCount` and every order slot untouched (asserted on STATE, never on return data); a second valid order gets id 2, demonstrating monotonic ids with no ring mask (VORD-01, VORD-03).
  3. Readers `orderCount()` and `getOrderPacked(uint256)` are each verified by CALLING the selector; `getOrderPacked` on a nonexistent id returns 0 without reverting, and the sentinel is justified in-code: a valid order always has `strike > 0` and `skew > 0`, so a validly packed word is never 0 (VORD-05, VORD-03).
  4. Both selectors are recomputed with `cast sig` from the exact signature strings in `interfaces/exposure/` — `create_order(uint88,uint24,uint16)` = `0x6501fe94` AND `create_orders(uint256,uint256[])` = `0x81357911` (the batch signature is a decision of record in the Overview, so this phase can pin it without waiting on Phase 18a); a compile-time test asserts `|S − keccak(SLOT_ORDERS_BASE)| > 2^64` for every scalar slot `S` (VORD-04).
  5. **Mutation gate:** reintroducing the ring's index mask into the slot derivation, moving the `orderCount` increment before validation, and aliasing a scalar slot onto the orders base EACH produce an OBSERVED RED; restored → green (VORD-03, VORD-04).

**Plans**: 1 plan (1 wave)

Plans:
- [x] 17-01-PLAN.md — `VolOrderManagerInterface` (both entrypoint selectors + both readers, cast-sig-pinned), `VolOrderManagerMod` (validate-then-id-then-unmasked-derived-slot store, zero domain arithmetic), the CALLED-green module suite incl. the id-65536 ring-mask discriminator, and a four-mutant observed-RED gate (VORD-01, VORD-03, VORD-04, VORD-05) [wave 1] — COMPLETE 2026-07-20 (17-01-SUMMARY.md)

### Phase 18a: Batch Input & State Effects
**Goal**: The batch decodes standard-ABI calldata behind three independent guards, loops with a bounded runtime `while`, skips invalid tuples with zero state footprint, and is bounded by `MAX_BATCH` — with all state effects proven via raw `vm.load` while returning only ONE word, so nothing here is observed through an untested encoder.
**Depends on**: Phase 17 (the internal create_order it composes N times).
**Requirements**: MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06
**Success Criteria** (what must be TRUE):
  1. `create_orders(uint256,uint256[])` (`0x81357911`) is CALLED with a mixed valid/invalid batch: valid tuples are stored at sequential ids and `orderCount` advances by exactly the success count; invalid tuples leave NO footprint — for `k ∈ [orderCount_before+1, orderCount_before+N]`, raw `vm.load(keccak(base)+k)` is nonzero exactly for successful positions' ids and zero for every `k > orderCount_after` (MCAL-03, MCAL-01).
  2. All THREE calldata guards fire independently, each asserted with its own corpus: offset ≠ `0x40` REVERTS (the phantom-order hole — a non-canonical offset would point the loop at zero-padded space and fabricate orders); array length ≠ `count` REVERTS; `calldatasize < 100 + 32*count` REVERTS. A malformed batch reverts the whole tx — never a silent skip (MCAL-02).
  3. `count > MAX_BATCH (128)` REVERTS before any `sstore` (asserted on state); `N = MAX_BATCH` is gas-measured at **≤ 10,000,000 gas** — a real threshold, not "under the block limit." If the peer supplies a value above the 512 ceiling it is CAPPED and reported back, never silently adopted (MCAL-01).
  4. Containment is established by a WRITTEN structural enumeration of the post-validation store path in the phase artifact — each step named with its revert status (`orderCount+1` checked/unreachable; `pack_vol_order` **no revert**; `array_slot`'s checked add documented-unreachable at ~2^-192; `sstore` cannot revert) — PLUS a corroborating constructed fuzz recording "no batch-revert OBSERVED over N runs." The criterion is evidence, never "proven for all 2^256 values." The strict and batch paths demonstrably call the SAME `validate_order` (MCAL-04).
  5. Batch-of-1 produces state and id identical to a standalone `create_order`; `N = 0` completes without reverting and without touching state (MCAL-06).
  6. **Mutation gate:** deleting EACH of the three guards independently, deleting the validation branch (**corrected 2026-07-20:** the pre-review draft demanded this redden "as a BATCH REVERT, not a wrong value" — that is mechanically UNSATISFIABLE and is contradicted by MCAL-04's own structural enumeration, which this same phase produces. Verified at source: `pack_vol_order` is pure `@evm_shl`/`&`/`|` with no `require` and no trapping arithmetic, and `@evm_sstore` cannot revert on this path, so an unvalidated tuple is STORED WRONG and never reverts. The pitfalls framing assumed the store path contains revert-prone steps; the enumeration disproves that. The honest kill is a STATE red on the mixed-batch contiguity/count assertions — strictly stronger, since it pins *where* the wrong word landed. Manufacturing a revert to satisfy the old wording is forbidden; if a revert IS observed, that is an MCAL-04 finding — a step in the enumeration is not total — and must be investigated), and advancing `orderCount` on failure EACH produce an OBSERVED RED; restored → green (MCAL-02, MCAL-04).

**Plans**: 1 plan

Plans:
- [x] 18a-01-PLAN.md — create_orders dispatch branch (4 guards, bounded while, validate-then-skip, one-word return) + batch test surface + measured N=128 gas + 7-mutant gate (completed 2026-07-20 — 13 CALLED-green tests, 7/7 observed mutation REDs, N=128 total gas MEASURED at 3,247,452)

### Phase 18b: Typed Return Encoding
**Goal**: The hand-rolled `(bool,uint256)[]` return encoder — the one surface in this milestone with ZERO precedent anywhere in the repo — is byte-exact against the standard encoder.
**Depends on**: Phase 18a (the batch whose results it encodes).
**Requirements**: MCAL-05
**Success Criteria** (what must be TRUE):
  1. The batch returns `(bool,uint256)[]` with head `0x40`, stride `0x40`, total exactly `64 + 64N` bytes — verified by asserting `returndatasize` per N and by `keccak256(plankReturndata) == keccak256(abi.encode(expectedResults))`, where the expected side uses Solidity's STANDARD `abi.encode` while Plank hand-rolls. Byte equality, not decoded-value equality: a decoded comparison leaves the encoder unconstrained (MCAL-05).
  2. `N = 0` returns exactly 64 bytes (offset `0x20`, length `0`) and `abi.decode` on the consumer side succeeds — the failure here is invisible on-chain and lands in the Haskell client, which is what makes it the trickiest edge. Governing principle asserted in-doc: structurally impossible → revert; semantically empty → well-formed empty result (a zero-arrival tick is an in-distribution Poisson sample, not a client bug) (MCAL-05).
  3. Results are positionally aligned to input; `success` words are canonically 0 or 1 (a non-canonical bool passes a lenient Haskell decoder while `abi.decode` rejects it — silent disagreement); a failed tuple returns `(false, 0)` (MCAL-05).
  4. The results buffer is allocated BEFORE the loop, and a test with `N = MAX_BATCH` confirms no corruption — `array_slot` mallocs 32 bytes every iteration (`storage.plk:232`), so interleaving allocations under a bump allocator is a live corruption path (MCAL-05).
  5. **Mutation gate:** head `0x40`→`0x20` (the likeliest real bug — emitting the length word but forgetting the outer offset), stride off-by-one-word, and emitting a non-canonical success word EACH produce an OBSERVED RED against the byte-equality assertion; restored → green (MCAL-05).

**Plans**: 1 plan

Plans:
- [x] 18b-01-PLAN.md — hand-rolled `(bool,uint256)[]` return encoder: the Plank encoder (buffer before the loop, head 0x40 / stride 0x40 / total 64+64N), the byte-level differential against solc's standard `abi.encode` incl. the N=0 64-byte edge and the N=128 allocation probe, and a six-mutant observed-RED gate (completed 2026-07-21 — 8 CALLED-green tests, 6/6 observed mutation REDs, N=128 gas re-measured at 3,275,765, M7 equivalence-checked and excluded)

### Phase 19: Differential, Mutation Battery & Consumer Fixture
**Goal**: The milestone acceptance bar — a full independent-mock differential over sequences, the complete observed-RED battery, a consumer fixture that cannot be satisfied by doing nothing, and a CALLED-green batch dispatch through FFI-deployed bytecode.
**Depends on**: Phases 17, 18a, 18b.
**Requirements**: MVER-01, MVER-02, MVER-03, MVER-04
**Success Criteria** (what must be TRUE):
  1. An after-every-write driver runs identical `(create_order | create_orders)` sequences into the FFI-deployed module and an INDEPENDENT Solidity mock (standard `abi.encode`, never mirroring Plank's manual encoding), asserting `orderCount`, each stored packed word via raw `vm.load` + a single test-side `VolOrderDecoder`, and raw return-byte equality — at tolerance 0, after every write (MVER-01).
  2. The complete observed-RED battery runs with verbatim FAIL lines recorded and sources restored sha256-identical: deleted validation branch, missing strike upper bound, count-advance-on-failure, ring-mask reintroduction, each of the three calldata guards, return-head `0x40`→`0x20`, non-canonical success word. Equivalence-masked mutants documented and explicitly NOT counted as kills (MVER-02).
  3. A consumer golden fixture FILE exists containing byte strings produced by an encoder OUTSIDE this repo. If peer bytes are unavailable, a self-encoded stand-in is committed marked `NOT-PEER-VERIFIED` and the gap is listed in the milestone exit record — falsifiable either way, never satisfiable by inaction. Plus a cast-sig test for every selector string in the interface file (MVER-03).
  4. `VolOrderManagerMod`'s BATCH dispatch is CALLED green through FFI-deployed bytecode -- the real gate, and the one MVER-04's 2026-07-20 correction left standing. **CORRECTED at 19-05:** the pre-correction wording said the module "leaves `PLANK_SKIP`"; there is no exit to perform, because `PLANK_SKIP` is the Makefile's rescue queue for entrypoints that do NOT compile (Makefile:186-198) and a module dispatching a subset of its declared selectors compiles fine. The queue has been empty since Phase 15 and stays empty. `make compile-plank` reports 0 failed FOR THE POS_SPEC SURFACES this milestone owns; the suite has its own `make` target (`test-vol-order-acceptance`) and is folded into `make test`, whose comment block is updated to the newly MEASURED counts (MVER-04).

**Plans**: TBD

Plans:
- [x] 19-01: Interleaved sequence differential vs independent mock (MVER-01) — anchor ends at id 12, fuzz `runs: 256` cold-cache, module and mock agree at tol 0, `src/` sha256-identical
- [x] 19-02: Consumer golden fixture + selector completeness (MVER-03) — 5 `cast abi-encode` (alloy) cases re-derived and diffed against the committed file, all 4 `cast sig` outputs matched the pinned constants, 3 falsifiability modes OBSERVED (not the 1 mandated); alloy independently confirms 18b's layout incl. the N=0 64-byte edge. Cross-language peer gap remains OPEN and marked `NOT-PEER-VERIFIED`
- [x] 19-03: Mutation battery part A (MVER-02) — 5 observed REDs (M1a, M1b, M2, M3, M4), **0 survivors**, 0 unconstructible, each restored sha256-identical. Finding F1: M2 dies ONLY in the Phase-16 harness — no pos_spec test delivers an oversized strike, and on the batch path M2 is genuinely EQUIVALENT (strike masked to 88 bits before validation), so the strike bound at the `create_order` entrypoint is UNPROVEN. Reported, not fixed (this phase builds nothing)
- [x] 19-04: Mutation battery part B (MVER-02) — 5 observed REDs (M5/M6/M7 the three calldata guards deleted INDEPENDENTLY, M8 return element-base shift, M9 non-canonical success word), each restored sha256-identical. **Consolidated MVER-02: 10 applications, 10 REDs, 0 SURVIVORS, 0 unconstructible.** Guard 3's kill taken from the REVERT assertion with its state-invisibility RE-MEASURED. Finding: four mutants (M2, M4, M5/M6/M7) have a SINGLE point of failure — wave 1 structurally cannot cover the malformed-input or large-id surfaces
- [x] 19-05: Dedicated `make` target + re-measured counts (MVER-04) — `test-vol-order-acceptance` (plus `test-vol-order-diff`, `test-vol-order-fixture`) passes; fold-in PROVEN by observing all three Phase 19 contract names in plain `make test`; comment block re-MEASURED cold at **102 passed / 18 failed / 120 total (44 suites)** and **compile-plank 11 ok / 2 failed**, every red attributed (14 exposure draft, 4 vol-type track, **0 in `test/pos_spec/`**); the CALLED-green batch dispatch VERIFIED by three named passing tests through FFI-deployed bytecode; `PLANK_SKIP` verified byte-identically empty and the stale SC-4 "exit" wording corrected

## Progress (Milestone v4.0)

**Execution Order:** Strictly sequential: 16 → 17 → 18a → 18b → 19. Pure functions before FFI; single-call before batch; batch STATE before batch ENCODING (so a totality failure and an encoder off-by-one are never confounded); acceptance last.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 16. Type Packing & Validation Foundation | 1/1 | Complete    | 2026-07-20 |
| 17. Interface & Single-Call Module | 1/1 | Complete    | 2026-07-20 |
| 18a. Batch Input & State Effects | 1/1 | Complete    | 2026-07-20 |
| 18b. Typed Return Encoding | 1/1 | Complete    | 2026-07-21 |
| 19. Differential, Mutation Battery & Consumer Fixture | 5/5 | Complete    | 2026-07-21 |

## Coverage (Milestone v4.0)

| Phase | Requirements | Count |
|-------|--------------|-------|
| 16 | VORD-02 | 1 |
| 17 | VORD-01, VORD-03, VORD-04, VORD-05 | 4 |
| 18a | MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06 | 5 |
| 18b | MCAL-05 | 1 |
| 19 | MVER-01, MVER-02, MVER-03, MVER-04 | 4 |

**Total mapped: 15/15** — no orphans, no duplicates.

## Research Flags (Milestone v4.0)

- **Phase 18a — focused research pass at plan time.** `merkle_airdrop.plk` is the precedent for the runtime `while` and the computed-offset `@evm_calldataload` (input side), and should be read line-by-line for those. Be explicit about what it does NOT provide: it has no `calldatasize` guard and no offset sanity check — followed literally it transplants an unguarded decoder into the one requirement (MCAL-02) that exists to prevent that. `@evm_calldatasize` has zero usages in `src/`.
- **Phase 18b — focused research pass at plan time.** There is NO dynamic-array return anywhere in this repo (all 11 `@evm_return` sites in `src/` are 32/64/96/0 bytes; the merkle file's are 32/32/0). Worth evaluating whether `std::abi`'s comptime machinery (`is_abi_dynamic`, `abi_head_size`, `unsafe_abi_encode_to`) is a partial reuse path rather than encoding fully by hand.
- **Phases 16, 17 — standard patterns**, skip research: near-verbatim mirrors of the v3.0 `VegaAccountMod` dispatch/slot/reader pattern and the existing pos_spec predicates. (Phase 16 does author one new predicate, but the mechanism is not new.)
- **Phase 19 — coordination checkpoint, not a research gap.** Proceed on the placeholder + stand-in fixture if the peer has not answered.

## Scope Boundary (Milestone v4.0)

Registry only — validate, pack, id, store, read, batch. Explicitly OUT: on-chain pricing (`tick_bucket_from_vol_order` and the pos_spec pricing pipeline, which has 4 red harness tests on the vol-type track); a generic `aggregate(address,bytes)` call router (a security surface with no consumer — the input is always tuples, never arbitrary calldata, which is what keeps reentrancy and delegatecall risk structurally absent); per-owner order books and any auth model (orders are anonymous in v1, like `setRiskPrice` in v3.0); events (no log-subscribing consumer); order cancellation/mutation (append-only registry).

**Forward-compat note recorded at design time:** the stored word carries `TICK_SPACING = 20` rather than a caller-supplied value. When pricing lands and orders need real tick spacings, that field becomes caller-supplied and this constant is removed — the layout does not change, only its source. This is why the full 152-bit word is stored rather than a 128-bit subset: a stored `tickSpacing = 0` would fail any future full `vol_range_width_is_complete` validation.

**Adjacent bug found during review, NOT ours to fix:** `wrap_spread_tick_assimetry` (`SpreadTickAssimetry.plk:9`) is `rawSpread << 0xffff` — a shift by 65535 that zeroes everything. It is off the `create_order` path and must stay off it; flagged to the vol-type-system track.
