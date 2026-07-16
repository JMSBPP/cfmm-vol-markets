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
  5. Each mapped parameter has a reference markdown under `spec/refs/` citing its `cfmm-theory` grounding note (primary `KERNEL.md`) by URL/citekey with no code dependency on the theory tree, annotated with the behavioral theorem/assumption/regime it encodes (REF-01, REF-02).
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
- [ ] **Phase 9: Variance Kernel Unit-Diff & Full-Timepoint Diff** - Fuzz `calculate_realized_volatility` vs Algebra's `_volatilityOnRange` for exact `uint88` equality, and after every write assert Algebra-vs-Plank agree field-by-field on the full stored timepoint — each mutation-verified falsifiable
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
| 8. Reference Integrity & Kernel Mock | 0/3 | Planned | - |
| 9. Variance Kernel Unit-Diff & Full-Timepoint Diff | 0/TBD | Not started | - |
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
