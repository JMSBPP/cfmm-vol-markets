# Execution Plan — todo.md CODE_REVIEW backlog (27-07-26) + remaining features

Status: REVIEWED (Reality Checker + Software Architect, both NEEDS WORK) → RESOLVED. Executable.

## RESOLUTION (post-review)
Both reviewers verified against the files; coverage + wave intent confirmed sound. Corrections:
- **Atomicity (B1):** the relocation unit is **module + EVERY importer + PlankTestBase/PLANK_DEP/deployPlank
  strings, in ONE commit** — not per-file. Full-suite-green gates *between* atomic units.
- **Real relocation graph (B1, OPEN 1 was wrong):** NO file imports `types::PricePair`/`types::PriceBucket`;
  `plankified-univ3` is NOT a consumer. Price types (`PricePair`/`PriceBucket`/`PriceOrderedPair`) all import
  `types::PriceCoordinate` and move together; the only cross-break is `types::PriceCoordinate::*` in
  `LiquidityAmounts.plk:3` (which stays `lib::`). **Dominant blast radius = `lib::TickUtils`: 8 importers across
  types/pos_spec tracks** (VolOrder, PanopticTokenId, LDFParams, PriceBucket, SpreadTickAssimetry, VolRangeWidth
  + harnesses) — a `lib→types` layer move; scope all 8 in one commit OR **defer TickUtils** to a standalone step (M3).
- **Relocation gate (B2):** `forge test` is NOT sufficient — Plank doesn't type-check code unreachable from `run{}`
  (dead code like `LDFLib` is imported by nobody). Gate each relocation with `make compile-plank` **and** a
  reachability check that every moved symbol's importers compile through a deployed entrypoint.
- **Green baseline (M2):** the suite is NOT fully green today — `PanopticVegaLens.t.sol` (F1, harness not yet
  written) reverts in setUp, and the exposure suites (VegaAccountMod / VegaIssuance) are known-failing. Pin the
  baseline = all tests EXCEPT `test/exposure/*` and `test/exposure/PanopticVegaLens.t.sol`; each step keeps THAT green.
- **Harness move loses zero coverage (M1, my rationale was inverted):** `compile-plank` greps `src` AND `test`
  (Makefile:300); ~5 harnesses already live under `test/` and `deployPlank("test/…")` resolves. CR-O1 is a safe
  pure move (do it LAST in Wave 2 so type moves don't re-touch harness imports — m4).
- **CR-I3 (LDFLib) → own spec + two-step review** (M4; it "needs design first", cannot go direct-TDD). Joins
  CR-T2 (PortafolioDelta) and CR-I4 (PriceSetterHook) as reference-less designs gated by spec+review.
- **Renames first (m1):** disjoint from relocations except `LiquidityAmounts.plk`; keep for clean single-concern diffs.
- **Numerics (m2):** author `types::Numerics` additions as a zero-import leaf (constants only → no cycle). Keep the
  path `src/types/Numerics.plk` per todo:144 (it already exists with WAD/Q64_96).
- **Spelling:** `PortafolioDelta` (match `Portafolio`), not `PortalioDelta` (m3).
- **CR-R3 footprint = 2 files** (`LiquidityAmounts.plk` + `GeometricDistributionHarness.plk`); no `.t.sol` uses the
  fn names directly (m1-RC). CR-I2 is closer to greenfield than "partially realized" (the setter lib is an empty stub).

Proceed order after resolution: Wave 0 (Numerics) → Wave 1 (renames) are low-risk, start now. Wave 2 uses the
atomic-commit + compile-plank gate above; TickUtils move scoped or deferred.

---
### Original draft (superseded by RESOLUTION)
Approach: full coverage (numbered items + inline // todo / // note), dependency-ordered waves, test suite
(currently ~21 LDF + all prior tests green) as the safety net on every mechanical step; reference-less impls
get their own spec + two-step review before coding.

## A. Coverage inventory (CODE_REVIEW, todo.md:102-185)

### Process
- **CR-P1** (L104): integrate manual human review with version control code review (process, not code).
- **CR-P2** (L40): write a develop-branch issue documenting the `ExchangeRateDifussion` → haskell_rpc_api delegation.

### Structural refactors (mechanical; blast radius = import paths + deploy paths)
- **CR-O1** (L110): relocate ALL 11 `*Harness.plk` from `src/` → `test/<namespace>/`. Touches every test's
  `deployPlank("src/…Harness.plk")` path + the Makefile `PLANK_DEP` gate (compile-plank auto-discovers `.plk`
  with `init{` under `src/`; moving harnesses OUT of `src/` removes them from that gate — intended).
- **CR-O2** (L152): math libraries → `lib/math` (not a domain namespace). Candidates: `lib/ldf/FixedPointMath.plk`
  (pure math → `lib/math/`); GeometricDistribution is LDF-domain, likely stays under an LDF namespace.
- **CR-O3** (L163): `lib/TickUtils.plk` is actually a TYPE → relocate to `types/pricing`. ALSO move
  `PriceBucket` / `PriceCoordinate` / `PricePair` (+ PriceOrderedPair) into `types/pricing`.

### Numerics extraction
- **CR-N1** (L144, L158, L169): single `Q96` const in `types/Numerics.plk`; consumers (GeometricDistribution,
  EtaSplitKernel, LiquidityAmounts) import it instead of redefining.
- **CR-N2** (L169): `U128_MAX` → `Numerics.plk` (LiquidityAmounts consumer).

### Renames (notation-binding to VOLATILITY_INSTRUMENTS)
- **CR-R1** (L145): `alpha` → `xi` in GeometricDistribution.
- **CR-R2** (L146): `length` → `iota` in GeometricDistribution.
- **CR-R3** (L148): `geometric_cumulative_amount0/1` → `geometric_cumulative_collateral_on_liquidity` (Q_M^L)
  / `geometric_cumulative_underlying_on_liquidity` (Q_X^L). Update all callers (LiquidityAmounts, tests).

### Type work
- **CR-T1** (L115): MarketId multi-protocol (Algebra/UniV3) generalization — the former `fn(comptime T)` wrapper.
- **CR-T2** (L121): Portafolio accounting logic on the type lib + a `PortalioDelta` type mimicking v4-core
  `BalanceDelta.sol` (packed signed token0/token1 delta). [reference-less design → own spec + review]

### Real implementations (TDD)
- **CR-I1** (L128): `CallbackRealizedVolatilityLib` — store the timepoint on the buffer (currently only decodes tick).
- **CR-I2** (L134): `PanopticTokenIdSetterLib` — a `(VolOrder) -> (PanopticTokenId)` lib (the INTENDED shape;
  supersedes replicating the whole TokenId). Note: partially realized by `panoptic_token_id_from_tick_bucket`;
  this reframes it as a VolOrder-driven setter lib.
- **CR-I3** (L138): `LDFLib` — implementation + interpretation (needs design first).
- **CR-I4** (L176): `PriceSetterHook.plk` — the real impl (PriceSetterHook.sol logic) + PriceUpdate log; DEST_CHAIN
  & origin chain via constructor→init block; a comptime-typed address guarded to match AlgebraFactory OR
  PoolManager interface. [reference-less-ish → own spec + review]

## B. Remaining features (pre-CODE_REVIEW)
- **F1**: PanopticVegaLens (#14) — in progress; `vol_option_payoff` RED test drafted (grounded in Panoptic.lean).
- **F2**: builderCode ↔ Algebra dynamic-fee map (#17) — research-first.
- **F3**: §16 research (Option/Accumulator/comptime/general discrete integral).

## C. Proposed ordering (waves)
Rationale: extract shared consts first (unblocks renames without churn); do content renames before path moves
(cleaner git + one blast radius at a time); big relocations next (mechanical, test-green-gated); then type work;
then TDD impls; then features. Each step keeps the full suite green.

- **Wave 0 — Numerics**: CR-N1 (Q96), CR-N2 (U128_MAX). Low risk, unblocks references.
- **Wave 1 — Renames**: CR-R1 (alpha→xi), CR-R2 (length→iota), CR-R3 (fn names → Q_M/Q_X). Notation-binding.
- **Wave 2 — Relocations**: CR-O1 (harnesses src→test) → CR-O3 (TickUtils + price types → types/pricing) →
  CR-O2 (math → lib/math). Each: move file + rewrite import paths + fix deployPlank paths + Makefile/PlankTestBase.
  HIGH blast radius on import roots — see OPEN 1.
- **Wave 3 — Type work**: CR-T2 (Portafolio accounting + PortalioDelta; own spec+review), CR-T1 (MarketId multi-proto).
- **Wave 4 — Impls (TDD)**: CR-I1 (callback timepoint), CR-I2 (VolOrder→PanopticTokenId), CR-I3 (LDFLib),
  CR-I4 (PriceSetterHook; own spec+review).
- **Wave 5 — Features**: F1 (resume PanopticVegaLens), F2 (builderCode↔Algebra), F3 (research).
- **Process (any time)**: CR-P1, CR-P2.

## D. OPEN issues for review
1. **Import-root breakage on relocation (CR-O3).** `types` dep root = `src/types`, so `PriceBucket` moving to
   `src/types/pricing/` changes its module path `types::PriceBucket` → `types::pricing::PriceBucket`. But
   `LiquidityAmounts.plk` and `lib/plankified-univ3` import `types::PricePair` / `types::PriceBucket` (the
   dangling-consumer contract from Phase 22). Moving them BREAKS those consumers unless we either (a) add a
   `pricing` sub-path and update every consumer, or (b) keep the top-level modules. Which?
2. **Harness relocation (CR-O1) vs the gate.** Harnesses currently live in `src/` so `make compile-plank`
   auto-discovers them. Moving to `test/` removes them from the src-gate; is that intended (they're test rigs), and
   does `deployPlank` still resolve `test/…Harness.plk` paths + the `helpers`/dep roots?
3. **Rename scope (CR-R3).** `geometric_cumulative_amount0/1` are consumed by LiquidityAmounts + 3 test files +
   the Portafolio forward/inverse. Rename is a pure find/replace but must stay diff-green; confirm the exact new
   names (collateral_on_liquidity for Q_M, underlying_on_liquidity for Q_X?).
4. **Which items are pure-mechanical vs need their own spec+review?** Proposed: CR-T2 (PortalioDelta) and CR-I4
   (PriceSetterHook) are reference-less designs → own spec+review. CR-I1/I2/I3 are grounded impls → direct TDD.
   F2 is research-first. Confirm.
5. **Sequencing risk**: should relocations (Wave 2) come BEFORE renames (Wave 1) to avoid moving+renaming the same
   files twice, or does content-first / path-second minimize churn? 
