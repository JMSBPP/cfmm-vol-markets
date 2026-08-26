# Requirements: CFMM Payoff Replication — Plank ↔ GAMS Connection Layer

**Defined:** 2026-06-27
**Milestone scope:** Open-loop **plumbing**, end-to-end, with a **stub GAMS solver**. This milestone proves the connection layer carries parameters correctly (GAMS output → encode → Plank write → read-back round-trip), on one authoritative kernel. It does **not** yet prove correct payoff *replication* (real optimization model, replication-error metric, and LDF correctness are v2).
**Core Value:** A parameter set flows end-to-end — (stub) GAMS output → encoded to Plank fixed-point → written via `initVolTermStructure` → read back and round-trip-verified — with both tracks bound to one authoritative kernel.

## v1 Requirements

Each maps to exactly one roadmap phase.

### Repository

- [ ] **REPO-01**: `wvs-finance/cfmm-replicationPlank` exists as a **public** repo and is the canonical upstream
- [ ] **REPO-02**: `JMSBPP/cfmm-replicationPlank` is a fork of the `wvs-finance` canonical, achieved via a **documented, reversible migration sequence** (backup → create canonical → retire/rename the existing standalone `JMSBPP` repo → fork); the destructive step is called out and confirmed before execution
- [ ] **REPO-03**: local git remotes reflect the topology (`upstream` = wvs-finance, `origin` = JMSBPP fork)
- [x] **REPO-04**: a project `README.md` (replacing the Foundry boilerplate) describes the Plank/GAMS dual-track and setup
- [x] **REPO-05**: **publish-readiness sanitization** before the public flip — remove `refs/` `node_modules` and the `Counter` scaffold, fix-or-disable the broken CI, **scrub all local absolute paths** (no `$HOME/...` local home-absolute path in tracked files), and ensure `.gitignore` covers `node_modules`/build artifacts

### Toolchain & Reproducibility

- [ ] **TOOL-01**: the `plank` compiler version is pinned (e.g., `.plank-version`) and the canonical codegen backend (`sona`) is declared; the FFI build asserts `plank --version` matches the pin
- [ ] **TOOL-02**: the Plank deployer / `plankified-univ3` submodules are pinned to specific commits, and the FFI deploy guards the silent-zero failure mode (assert returned bytecode length > 0 and deployed address ≠ 0; fail loudly)

### Shared Kernel

- [ ] **KERN-01**: every type on the **bridge path — explicitly enumerated** (`VolatilityTermStructure` and its fields; the `NumberFormat`/`BoundedValue` they use) — carries number format, bounds, and unit semantics, with **no placeholder bounds** (the `baseTick` bound is resolved to a concrete int24 range)
- [ ] **KERN-02**: `VolatilityTermStructure` is fully specified **and** a concrete conformance mechanism binds the Plank type and the GAMS symbols to the single kernel definition (a generated shared constants file both sides include, or a checked field-by-field cross-reference) — not prose alone
- [ ] **KERN-03**: the kernel states the canonical fixed-point conventions (WAD `1e18`, Q64.96) and unit rules, using **one canonical name** for the Q64.96 format consistently (reconcile `Q64x96`/`Q64.96`/`Q96_ONE`)

### Encoding Contract & Parameter Map

- [ ] **MAP-01**: a GAMS↔Plank mapping table covers at least `xi`↔`priceElasticity`/LDF `alpha`, `iota`↔`statePartitionDelta`/`tickSpacing`, and `baseTick`, each with mapping direction
- [ ] **MAP-02**: a **per-hop** fixed-point encode/decode chain is specified for each parameter — every quantizing hop (e.g., GAMS `xi` → Q64.96 `priceElasticity` → state-scale `alpha`) with its scale base and rounding mode; the `priceElasticity` upper bound is **corrected so the type covers the full valid `alpha` range** (resolves `Q96_ONE` < `MAX_ALPHA`)
- [ ] **MAP-03**: signed `baseTick` encoding is specified — int24 two's-complement sign-extended to `u256`, rounded to a `tickSpacing` multiple, within the resolved int24 bounds
- [ ] **MAP-04**: a `tickSpacing` divisibility invariant is enforced — encoding validates or re-derives `tickLower`/`tickUpper` as valid multiples of the resolved `tickSpacing` (e.g., canonical ±120 vs spacing)
- [ ] **MAP-05**: the `initVolTermStructure` ABI + storage-layout contract is specified — canonical function signature string, ABI argument layout, and on-storage bit-packing of `VolatilityTermStructure`; selector `0xd9c112ef` is verified to equal `keccak(signature)[:4]`
- [ ] **MAP-06**: storage slots are **reconciled** — the write slot (`SLOT_VOLATILITY_TERM_STRUCTURE`) and the simulator's read slots are unified and declared (no undefined `SLOT_TICK_*`); any parameter is traceable from its GAMS symbol to a declared Plank slot

### Theory Grounding

- [ ] **REF-01**: each mapped parameter has a reference markdown under `spec/protocol/refs/` linking it to its grounding note in `cfmm-theory` — primary target `KERNEL.md`, extensible (`cfmm-control/ELASTICITY_CONTROL.md`, `cfmm-options/PAYOFF.md`, …) — cited by URL/citekey with **no code dependency** on the cfmm-theory tree
- [ ] **REF-02**: in the `spec/protocol/refs/` markdown, each key control parameter is annotated with the behavioral theorem/assumption/market regime it encodes (supporting level — not a formal review)

### Plank Bridge-Surface Implementation

- [ ] **PLNK-01**: `src/types/VolatilityTermStructure.plk` is implemented with a working `read` that decodes the stored struct per the MAP-05 layout
- [ ] **PLNK-02**: `IMarketDynamics.initVolTermStructure` has an implemented body that decodes calldata and stores into the reconciled slot per MAP-05/MAP-06 (not just a selector constant)
- [ ] **PLNK-03**: `IMarketDynamicsLens` getters are implemented — including **`getPriceElasticity`**, `getStatePartitionDelta`, and `getBaseTick` — providing a read-back view for **every** seeded field
- [ ] **PLNK-04**: all Plank sources on the bridge/pipeline path **compile cleanly** via the pinned FFI build — the parse/type stubs (`SELECTOR_… =;`, untyped fields, `uint256` vs `u256`, `u265` typo) blocking the path are fixed

### GAMS Plumbing (stub solver)

- [x] **GAMS-01**: GAMS sources are vendored into `model/` inside the repo and the pipeline references that location (not `../experiments/gams`) — ✓ **DONE** (already vendored: `model/*.gms`, `model/dynamic/InitState.gms`, `model/spec/*`, `model/BUILD.md` tracked). Residual `../experiments/gams` text references in `model/BUILD.md` + `docs/superpowers/` get cleaned in the Phase 1 path scrub.
- [ ] **GAMS-02**: the GAMS model **runs from `model/` and emits the parameter-output artifact** the bridge consumes, using a **stub/placeholder objective** (a trivial or fixed map is acceptable this milestone); the real optimization model is deferred to v2

### Open-Loop Runtime Bridge

- [ ] **BRDG-01**: GAMS output is serialized to a defined exchange format (e.g., JSON or ABI-encoded calldata) that the Plank side consumes
- [ ] **BRDG-02**: a bridge step encodes the parameters per the MAP-02 contract and writes them to Plank via `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`)
- [ ] **BRDG-03**: the Plank `ReferenceMarket`/LDF reads the seeded parameters back through the lens views and a **round-trip equality** holds: `decode(readback) ≈ original` within the stated quantization tolerance
- [ ] **BRDG-04**: a selector-conformance test asserts each Plank selector constant on the path equals `keccak(documented signature)[:4]`

### End-to-End Plumbing

- [ ] **PIPE-01**: a single command runs the full open-loop **plumbing** path end-to-end — payoff spec → (stub) GAMS solve → encode → Plank write → read-back — exiting success **only if** the FFI guards (TOOL-02) and the round-trip (BRDG-03) pass
- [ ] **PIPE-02**: an **open-loop guard** — the swap-replay/simulate step performs **no in-loop parameter updates** (keeping the closed-loop controller out of this milestone)

---

## Milestone v2.0 Requirements — Realized-Volatility Oracle Differential Testing

Scoped requirements for the v2.0 oracle track (todo.md items 8–9). Separate from the v1 plumbing
requirements above. Reference of record: Algebra `VolatilityOracle`. Phase numbering continues at 8.

### Reference Integrity

- [x] **VDIFF-01**: The Algebra reference the diff test compiles against is protected from silent replacement — NOT just `libraries/VolatilityOracle.sol` but the full baseline the harness links: `VolatilityOraclePluginImplementation.sol` (the delegatecall target driving Algebra in VDIFF-04), `libraries/VolatilityOracleStorage.sol`, and their transitive imports — pinned as a whole (vendored under `lib/`, or a package-tarball / per-file checksum gate). A build/CI check FAILS LOUDLY when the `node_modules` copy diverges from the pin (verified by deliberately editing a reference file and observing red). The mock and vendored reference compile under `solc =0.8.20` (Algebra's pinned pragma).

### Variance Kernel Diff

- [x] **VDIFF-02**: Plank's `calculate_realized_volatility` is differentially tested against Algebra's `_volatilityOnRange` directly, over a fuzzed `(dt, tick0, tick1, avgTick0, avgTick1)` domain with `dt` bounded to `[1, 2^32)` (Solidity `/` reverts on `dt=0` even under `unchecked`, while EVM SDIV returns 0 — an excluded, known divergence), ticks bounded to int24, asserting exact **full uint256** equality (stronger than the production uint88 truncation, on a free axis), via a mock (distinct name — the package already ships a `MockVolatilityOracle`) that exposes the `internal pure` `_volatilityOnRange`
- [x] **VDIFF-03**: The incorrect assertion diffing Plank's RAW `get_average_volatility` accumulator against Algebra's window-normalized `getAverageVolatility` is removed, and the in-file docs state these are DIFFERENT quantities (Algebra's is Bessel-corrected + WINDOW-normalized). Any scalar volatility comparison instead uses the stored `volatilityCumulative` field (VDIFF-04). Porting Algebra's window-normalized `getAverageVolatility` to Plank (its own interpolation + Bessel branches) is a production task explicitly DEFERRED to a follow-on — not in this milestone.
  - **AS-BUILT CORRECTION (08-03, 2026-07-16):** the "incorrect assertion" this requirement names **never existed** — re-verified by grep before editing (no `assertEq` anywhere had Plank's raw accumulator on one side and Algebra's window-normalized getter on the other). The actual risk was a *loaded gun*: an unused `getAverageVolatility(int24,uint32)` **declaration** in `RealizedVolatilitySmoke.t.sol`'s `IRealizedVolatility` — declared, never called, one `assertEq` from the mistake. **What shipped:** that declaration removed + the trap documented in-file; smoke suite unchanged 11/11; no port (verified: no Bessel in any `.plk`). The requirement's *intent* ("removed, and the docs state they are different quantities") is met; its *premise* was wrong. See `08-03-SUMMARY.md`.

### Full-Timepoint Diff

- [x] **VDIFF-04**: After every write in a shared **Algebra-vs-Plank-only** driver sequence (the volatility surface has no UniV3 counterpart, so the UniV3 ref is NOT driven here), Algebra and Plank agree exactly on the stored timepoint fields `volatilityCumulative`, `averageTick`, and `windowStartIndex`, asserted field-by-field via the `getTimepoint` / `getTimepointPacked` getters (needs test-side unpack of the vol/avgTick/windowStartIndex offsets, added here). `oldestIndex` is EXCLUDED from this differential — it is vacuously `0` on both sides below 2^16 writes, so a corpus of ≤480 writes cannot exercise it; ring-wrap `oldestIndex` behavior is covered Plank-side by the VDIFF-07 unit test. Exactness (tolerance 0) is guaranteed within the int24×uint32 regime (max |tickCumulative| ≈ 3.8e15 < int56 max 3.6e16); it is NOT claimed in Algebra's deliberate int56-overflow regime, which Plank's full-width in-flight accumulator does not replicate.
- [ ] **VDIFF-05**: The differential corpus is CONSTRUCTED (not `vm.assume`-filtered) with total span `> 2×WINDOW` so `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` selection execute INSIDE the write sequence (the existing Phase-0/1 assertions never touch `volatilityCumulative`/`averageTick`/`windowStartIndex` at all). The corpus forces ≥1 strict tick rise and ≥1 strict fall by construction (so `avg_tick ≠ tick`, kernel `k`/`b` nonzero — non-vacuous) and keeps strictly-increasing distinct timestamps (`delta ≥ 1`, on which the heuristic-free `window_start_index` equivalence depends). Coverage of those paths is evidenced by a **targeted mutant KILL** in them — `forge coverage` cannot instrument FFI-deployed Plank bytecode under via-IR, so coverage/trace is NOT an option.
- [ ] **VDIFF-06**: A SEPARATE sub-WINDOW corpus (`init_timestamp < WINDOW`) exercises the `u32_sub` regime — the only regime in which that fix is reachable — kept distinct from VDIFF-05 (whose span forces `currentTime > WINDOW`)

### Edges & Falsifiability

- [ ] **VDIFF-07**: Edge cases hold across Algebra and Plank — a lookback older than the oldest retained timepoint reverts on both; a same-block double write is idempotent (no second timepoint, no revert); a uint32 timestamp wraparound is handled; and ring-buffer wrap is covered by a direct unit assertion (`vm.store` the index, not 65536 writes)
- [ ] **VDIFF-08**: Every new test is proven falsifiable by a mutation battery (deliberate bugs in the variance kernel, the packing, and the accumulator are all KILLED) before it is trusted, and the suite is wired into a `make` target folded into `test-vol-prereqs`

## Milestone v3.0 Requirements — VegaAccountMod Vault ✅ SHIPPED 2026-07-19

All 13 requirements (RISK-01/02, VLIB-01..04, VMOD-01..05, VVER-01/02) complete and verified.
Archived in full: `.planning/milestones/v3.0-REQUIREMENTS.md` · `.planning/MILESTONES.md` · tag `v3.0`.

## Milestone v4.0 Requirements — VolOrderManagerMod + Best-Effort Multicall

Peer-requested (rpc_api track `mv15a18k`, StochasticOrderGen consumer). **This section is post-review**: a two-step parallel review (Reality Checker + Solidity Smart Contract Engineer) found 2 BLOCKERs and 6 MAJORs in the pre-review draft — the packed-layout offsets were transcribed backwards from `VolOrder.plk:35-40`, the batch guard formula assumed a flat calldata layout incompatible with any standard ABI encoder, and a "reduced width check" would have made the composed validator identically false. All are resolved below; the decisions of record are stated inline so no downstream phase re-derives them.

**Decisions of record (do not re-litigate):**
- **Stored word = the FULL 152-bit `pack_vol_order` output, reused VERBATIM** (`width@128 | tickSpacing@104 | strike@16 | skew@0` — verified against `VolOrder.plk:35-40`). The module pins `TICK_SPACING = 20` as a constant (the corpus convention at `VolOrder.t.sol:102`; satisfies the real `<= 0xc8` bound). This keeps `vol_range_width_is_complete` usable AS-IS, requires no new packer or decoder, and avoids a forward-compat trap (a stored `tickSpacing = 0` would fail any future full validation).
- **Batch ABI = `create_orders(uint256 count, uint256[] packedOrders)`, selector `0x81357911`** (`cast sig`-verified), one packed 128-bit word per order. **INPUT WORD BIT LAYOUT (pinned 2026-07-20 — the pre-review draft named the fields but NOT their offsets, and inferring offsets from field-name order is exactly what produced this milestone's packing BLOCKER):** `skew @ bits 0..15 | strike @ bits 16..103 | width @ bits 104..127`. Chosen so bits 0..103 are IDENTICAL to the stored word — skew and strike occupy the same offsets in both, so Phase 16's already-tested masks/shifts apply unchanged; only `width` moves (104 in the input, 128 in storage) because the module inserts `TICK_SPACING = 20` at bits 104..127 on the way to `pack_vol_order`. Bits ≥128 of an input word MUST be zero (dirty-high-bit rejection). Standard ABI, not a flat hand-rolled layout: a flat layout cannot be expressed as a Solidity signature at all, which would make the shared `interfaces/` file and every cast-sig test unsatisfiable for the batch.
- **Return = `(bool success, uint256 orderId)[]` in standard ABI: head `0x40`, stride `0x40`, total `64 + 64N`** (outer offset word + length word + N inlined static pairs). Writing head `0x20` — emitting the length word but forgetting the outer offset — is the single likeliest bug on this surface.
- **`MAX_BATCH` default 128** (~3.0M gas, comfortably includable), **hard admissibility ceiling 512** (~12M). A peer-supplied value above the ceiling is CAPPED and reported back, never silently adopted.

### Registry Core

- [x] **VORD-01**: `create_order(uint88,uint24,uint16)` — selector `0x6501fe94` cast-sig-pinned in an `interfaces/` file shared with the Haskell consumer — validates via the pure lib and REVERTS on any invalid tuple (strict single-call path; the batch is the lenient one). The strict and batch paths call the SAME `validate_order` function, so their accept/reject agreement holds by construction, not by coincidence
- [x] **VORD-02**: A pure `validate_order` lib reuses `spread_tick_assimetry_is_complete` and `vol_range_width_is_complete` VERBATIM (the latter is satisfiable because `TICK_SPACING = 20` is pinned) and AUTHORS one new bound: `strike > 0 & strike <= 2^88-1`. The new bound is load-bearing, not hygiene — `tick_volatility_is_complete` is only `vol > 0` (no upper bound), so an oversized strike would pass validation and then be SILENTLY MASKED to 88 bits by `pack_vol_order`, storing a different value than the caller supplied. Skew semantics stated unambiguously: **valid range is [1, 65534]; 0 and 65535 REVERT; 1 and 65534 are ACCEPTED** — all four boundaries asserted (`PosSpec.lean:52,56` `skewTick_one`/`skewTick_zero` justify why the u16 endpoints are degenerate)
- [x] **VORD-03**: Sequential `uint256` order ids from 1 (0 = null sentinel); `orderCount` advances ONLY on success, so `orderCount` ≡ latest id ≡ live order count (no gaps from failures). The sentinel is SOUND, not lucky: a valid order always has `strike > 0` and `skew > 0`, so a validly packed word is never 0 — therefore `packed == 0 ⟺ nonexistent`
- [x] **VORD-04**: Orders stored at `array_slot(SLOT_ORDERS_BASE, id)` (= `keccak(base) + id`, reused verbatim from `v3::storage`) — MONOTONIC, the ring's 16-bit wraparound mask explicitly NOT imported (it lives in the separate `StorageIndex.plk`, not in `array_slot`). Slot `keccak(base)+0` is never written (ids start at 1) and stays permanently zero, which is what makes `getOrderPacked(0)` return 0 for free. Intra-contract collision safety is asserted at COMPILE-TIME values, not argued probabilistically: `|S − keccak(SLOT_ORDERS_BASE)| > 2^64` for every scalar slot `S` in the module
- [x] **VORD-05**: Readers expose every stored field — `orderCount()`, `getOrderPacked(uint256)` (returns 0 for nonexistent ids, no revert) — module-not-a-black-box. **"Zero arithmetic in the module" means: no DOMAIN arithmetic.** The only permitted operations are the id increment, the loop counter, and the `array_slot` call; all bounds live in the lib, all packing in the type

### Best-Effort Batch

- [x] **MCAL-01**: Batch is `create_orders(uint256 count, uint256[] packedOrders)` (`0x81357911`) with `MAX_BATCH = 128`; `count > MAX_BATCH` reverts BEFORE any work. The gas criterion is a real threshold, not a gesture: measured `N = MAX_BATCH` cost **≤ 10,000,000 gas** (not "under the block limit" — a transaction consuming a whole block is not reliably includable)
- [x] **MCAL-02**: THREE independent calldata guards, each separately mutable and separately killed: (1) `@evm_calldataload(36) == 0x40` — the array offset is canonical, so a client or attacker cannot point the loop at a different calldata region and fabricate phantom orders from zero-padded space; (2) `@evm_calldataload(68) == count` — the array's own length agrees with the count argument (they are independent numbers in the ABI); (3) `@evm_calldatasize() >= 100 + 32*count`. A malformed batch REVERTS the whole transaction — structural failure, never a silent per-call skip
- [x] **MCAL-03**: Per-tuple best-effort via pure-validation pre-check: an invalid tuple is SKIPPED with zero state footprint; valid tuples persist. The footprint assertion is concrete: for `k ∈ [orderCount_before+1, orderCount_before+N]`, raw `vm.load(keccak(base)+k)` is nonzero exactly for the ids assigned to successful positions and zero for every `k > orderCount_after`
- [x] **MCAL-04**: Best-effort containment is established PRIMARILY by a structural enumeration of the post-validation store path — a written argument naming each step and its revert status: `orderCount + 1` (checked add, u256, unreachable); `pack_vol_order` (**no revert** — pure masking, no `require`, no smart constructor: this is the fact that makes pre-validation containment viable at all); `array_slot`'s `keccak + index` (checked add, documented-unreachable at ~2^-192); `@evm_sstore` (cannot revert outside staticcall). Fuzz over a CONSTRUCTED corpus is CORROBORATION, not proof — the criterion is "no batch-revert OBSERVED over N runs", never "proven for all 2^256 values". The completeness differential (batch flags a tuple failed ⟺ standalone `create_order` reverts on it) is a regression guard on top of the by-construction shared-`validate_order` property
- [x] **MCAL-05**: The batch returns hand-rolled ABI `(bool success, uint256 orderId)[]`, positionally aligned to input, with head `0x40`, stride `0x40`, total `64 + 64N`; `success` words are canonically 0 or 1 (a non-canonical bool is rejected by Solidity's `abi.decode` but may pass a Haskell decoder — silent disagreement); a failed tuple returns `(false, 0)`. The results buffer is `@malloc_uninit`'d BEFORE the loop, because `array_slot` itself mallocs 32 bytes every iteration (`storage.plk:232`) and interleaving those with the results buffer under a bump allocator is a live corruption path
- [x] **MCAL-06**: Batch ≡ N-fold composition of the SAME internal create_order: a batch-of-1 produces identical state and id to a standalone `create_order` call. `N = 0` returns a well-formed EMPTY result (exactly 64 bytes: offset `0x20`, length `0`) and never reverts — the governing principle is **structurally impossible → revert; semantically empty → well-formed empty result**. A zero-arrival tick is an in-distribution Poisson sample, not a client bug
  - **[18a-01 PARTIAL — read before closing this in 18b]** Phase 18a discharged the STATE half: batch-of-1 is byte-identical in stored word AND id to a standalone `create_order` (asserted against a second independent instance, with the VALUE pinned so two zeros cannot satisfy it), and `N = 0` succeeds without reverting and leaves every observable slot byte-identical — verified from BOTH a zero and a SEEDED counter, which is what proves the module's unconditional trailing `orderCount` write-back is value-PRESERVING rather than zeroing. The **"exactly 64 bytes: offset `0x20`, length `0`"** clause is NOT discharged and CANNOT be by 18a, which deliberately returns ONE WORD (the success count) so state effects are provable without trusting an untested encoder. **Phase 18b owns that clause.**
  - **[18b-01 DISCHARGED]** The carried return-bytes clause is now BYTE-VERIFIED. `create_orders` emits the hand-rolled `(bool,uint256)[]` and `N = 0` returns EXACTLY 64 bytes — outer offset `0x20`, length `0` ELEMENTS — proven by `test__unit__emptyReturnIsExactlySixtyFourBytes` as `keccak256(returndata) == keccak256(abi.encode(new BatchResult[](0)))` against solc's STANDARD encoder, with `returndatasize` pinned at 64, `abi.decode` shown to succeed and yield a zero-length array, and the bytes shown identical from BOTH a fresh and a SEEDED (C=5) counter. Falsifiability is OBSERVED, not asserted: the dropped-outer-offset-word mutant (M2) reddens this exact test at its keccak assertion (32 bytes vs 64). MCAL-06 is now fully Complete.

### Verification & Exit

- [x] **MVER-01**: An independent Solidity reference mock encodes its results with **`abi.encode` (the standard encoder)** while Plank hand-rolls, and the differential asserts **raw byte equality** (`keccak256(plankReturndata) == keccak256(abi.encode(mockResults))`), including the `N=0` case. Decoded-value comparison is NOT sufficient — it compares semantics while leaving the hand-rolled encoder unconstrained; byte equality makes solc an independent oracle for the one surface with no in-repo precedent. An after-every-write driver additionally asserts `orderCount` and the stored packed word via raw `vm.load` + a single test-side `VolOrderDecoder`
- [x] **MVER-02**: Observed-RED mutation battery, each killable mutant applied → cache cleared → verbatim RED recorded → restored sha256-identical → green: deleted validation branch; missing strike upper bound (silent truncation); count-advance-on-failure; ring-mask reintroduction; EACH of the three calldata guards deleted independently; return-head `0x40`→`0x20`; non-canonical success word. Equivalence-masked mutants documented, never counted
- [x] **MVER-03**: A consumer golden fixture FILE exists containing byte strings produced by an encoder OUTSIDE this repo. If peer bytes are unavailable, a self-encoded stand-in is committed and explicitly marked `NOT-PEER-VERIFIED`, and that gap is listed in the milestone exit record — the criterion is falsifiable either way and cannot be satisfied by doing nothing. Plus a cast-sig test for every selector string in the interface file
- [x] **MVER-04**: `VolOrderManagerMod` is CALLED green on its BATCH dispatch through FFI-deployed bytecode before the milestone closes; the suite is wired into a dedicated `make` target and folded into `make test`. **Corrected 2026-07-20:** the pre-review draft said the module "enters `PLANK_SKIP` when created (Phase 17)" — that rests on a false premise. `PLANK_SKIP` is the Makefile's *rescue queue* for entrypoints that do NOT yet compile; a module dispatching a subset of its declared selectors compiles fine, so it never belongs there. `PLANK_SKIP` stays EMPTY (as Phase 15 left it) and `make compile-plank` simply counts one more entrypoint. Compile-green was never the gate here anyway — the gate is the CALLED batch dispatch, which is unchanged.

## v2 Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Real Optimization & Replication Proof

- **PAY-01**: `PayoffModule.gms` represents an **arbitrary parameterized contingent payoff** with a real objective/constraints/solver, plus a solver-status/feasibility check on the emitted artifact
- **PROOF-01**: the pipeline replicates a concrete contingent-payoff instance end-to-end
- **PROOF-02**: a **replication-error metric** — defined norm, units, sampling grid, on-/off-chain computation locus, and an acceptance tolerance — decomposing encoding-quantization error from CFMM-vs-target structural error

### Simulation Correctness

- **LDF-01**: a Geometric-distribution LDF passes the bunni-v2 LDF conformance suite (normalization, monotonicity, inverse functions) — NOTE: `src/ldf/GeometricDistribution.plk` and its empty test scaffold were DELETED 2026-07-16 (`ead50b8`) as unmaintained; recover from git history when this requirement is picked up
- **LDF-02**: `SwapAmtGen` arithmetic is overflow-bounded over the tested `timeIndex` range; fuzz runs raised to ≥ 1000

### Adaptive Control

- **CTRL-01**: closed-loop adaptive feedback controller in `src/DynamicCFMM.plk` that updates `xi`/`iota` as the simulated market evolves
- **CTRL-02**: V4 `beforeSwap` hook integration driving the controller on-chain

### Breadth & Rigor

- **PLIB-01**: a library of contingent payoffs replicable through the pipeline
- **RIG-01**: formal literature review deliverable on CFMM payoff replication
- **RIG-02**: cryptographically-secure on-chain randomness (VRF / commit-reveal) replacing the simulation proxy

## Out of Scope

Explicitly excluded this milestone.

| Feature | Reason |
|---------|--------|
| **v3.0 vault:** withdraw/redeem, per-account share ledger | The Lean corpus formalizes only the forward map — redemption now would be an UNVERIFIED surface; per-account bookkeeping is a dependency of redemption. Revisit note: a pool-derived redemption rate re-opens the first-depositor/donation analysis ruled N/A for v1 |
| **v3.0 vault:** ERC-20 transferability / ERC-4626 conformance | `exposure.md`: VegaExposure is internal accounting, not a traded token; 4626 mandates pool-ratio pricing — the wrong semantics for an exogenous `p_risk` |
| **v3.0 vault:** distance pipeline D2, risk-price composition P0/P2, stateful `setHaircut`, oracle wiring to `RealizedVolatilityMod`, `p_vol(σ̄)` from pos_spec | H1-only v1 per user decision; a stored `h` with no oracle is inert; pos_spec's type layer still has 5 red harness tests (vol-type-system track) |
| Correct payoff **replication** proof (metric + tolerance) | Plumbing-first milestone; replication correctness is v2 (`PROOF-*`) |
| Real GAMS optimization model | Stub solver this milestone; real model is v2 (`PAY-01`) |
| LDF conformance / `SwapAmtGen` overflow fix | Deferred to v2 (`LDF-*`); not on the plumbing critical path |
| Closed-loop adaptive controller + V4 hook | This milestone is the open-loop bridge it depends on (`CTRL-*`) |
| Production / mainnet hook deployment | Simulation-first; deployment is later |
| Multiple-payoff library | One path; design stays payoff-agnostic (`PLIB-01`) |

## Traceability

Every v1 requirement maps to exactly one phase. See `.planning/ROADMAP.md` for phase detail.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REPO-01 | Phase 1 | Pending |
| REPO-02 | Phase 1 | Pending |
| REPO-03 | Phase 1 | Pending |
| REPO-04 | Phase 1 | Complete |
| REPO-05 | Phase 1 | Complete |
| GAMS-01 | Phase 2 | ✓ Complete (pre-done — vendored to model/) |
| KERN-01 | Phase 2 | Pending |
| KERN-02 | Phase 2 | Pending |
| KERN-03 | Phase 2 | Pending |
| TOOL-01 | Phase 2 | Pending |
| TOOL-02 | Phase 2 | Pending |
| MAP-01 | Phase 3 | Pending |
| MAP-02 | Phase 3 | Pending |
| MAP-03 | Phase 3 | Pending |
| MAP-04 | Phase 3 | Pending |
| MAP-05 | Phase 3 | Pending |
| MAP-06 | Phase 3 | Pending |
| REF-01 | Phase 3 | Pending |
| REF-02 | Phase 3 | Pending |
| PLNK-01 | Phase 4 | Pending |
| PLNK-02 | Phase 4 | Pending |
| PLNK-03 | Phase 4 | Pending |
| PLNK-04 | Phase 4 | Pending |
| GAMS-02 | Phase 5 | Pending |
| BRDG-01 | Phase 6 | Pending |
| BRDG-02 | Phase 6 | Pending |
| BRDG-03 | Phase 6 | Pending |
| BRDG-04 | Phase 6 | Pending |
| PIPE-01 | Phase 7 | Pending |
| PIPE-02 | Phase 7 | Pending |
| VDIFF-01 | Phase 8 | Complete |
| VDIFF-03 | Phase 8 | Complete |
| VDIFF-02 | Phase 9 | Complete |
| VDIFF-04 | Phase 9 | Complete |
| VDIFF-05 | Phase 10 | Pending |
| VDIFF-06 | Phase 10 | Pending |
| VDIFF-07 | Phase 11 | Pending |
| VDIFF-08 | Phase 11 | Pending |
| RISK-01 | Phase 12 | Complete |
| RISK-02 | Phase 12 | Complete |
| VLIB-01 | Phase 13 | Complete |
| VLIB-02 | Phase 13 | Complete |
| VLIB-03 | Phase 13 | Complete |
| VLIB-04 | Phase 13 | Complete |
| VMOD-01 | Phase 14 | Complete |
| VMOD-02 | Phase 14 | Complete |
| VMOD-03 | Phase 14 | Complete |
| VMOD-04 | Phase 14 | Complete |
| VMOD-05 | Phase 14 | Complete |
| VVER-01 | Phase 15 | Complete |
| VVER-02 | Phase 15 | Complete |
| VORD-02 | Phase 16 | Complete |
| VORD-01 | Phase 17 | Complete |
| VORD-03 | Phase 17 | Complete |
| VORD-04 | Phase 17 | Complete |
| VORD-05 | Phase 17 | Complete |
| MCAL-01 | Phase 18a | Complete |
| MCAL-02 | Phase 18a | Complete |
| MCAL-03 | Phase 18a | Complete |
| MCAL-04 | Phase 18a | Complete |
| MCAL-05 | Phase 18b | Complete |
| MCAL-06 | Phase 18a (+ 18b) | Complete |
| MVER-01 | Phase 19 | Complete |
| MVER-02 | Phase 19 | Complete |
| MVER-03 | Phase 19 | Complete |
| MVER-04 | Phase 19 | Complete |

**Coverage:**
- v1 requirements: 30 total — mapped to Phases 1–7: 30 ✓
- v2.0 requirements (VDIFF-01..08): 8 total — mapped to Phases 8–11: 8 ✓
- v3.0 requirements (RISK-01/02, VLIB-01..04, VMOD-01..05, VVER-01/02): 13 total — mapped to Phases 12–15: 13 ✓
- v4.0 requirements (VORD-01..05, MCAL-01..06, MVER-01..04): 15 total — mapped to Phases 16–19: 15 ✓
- Total mapped: 66/66 — Unmapped: 0

---
*Requirements defined: 2026-06-27*
*Last updated: 2026-06-27 — traceability populated against plumbing-first 7-phase roadmap (30/30 mapped)*
*Last updated: 2026-07-15 — appended milestone v2.0 (VDIFF-01..08) traceability, Phases 8–11 (8/8 mapped)*
*Last updated: 2026-07-16 — appended milestone v3.0 (RISK/VLIB/VMOD/VVER, 13 reqs) traceability, Phases 12–15 (13/13 mapped); total 51/51*
*Last updated: 2026-07-19 — appended milestone v4.0 (VORD/MCAL/MVER, 15 reqs) traceability, Phases 16–19 (15/15 mapped); total 66/66*
*Last updated: 2026-07-20 — v4.0 POST-REVIEW: 2 BLOCKERs + 6 MAJORs resolved (packing layout corrected against VolOrder.plk:35-40, standard-ABI batch 0x81357911 with 3 guards, new strike u88 bound authored, MCAL-04 demoted from proof to evidence); Phase 18 SPLIT into 18a (input+state) / 18b (return encoding) — now 5 phases, still 15/15 mapped*
