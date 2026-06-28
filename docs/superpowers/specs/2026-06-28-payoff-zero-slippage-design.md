# PayoffModule scaffolding + first convex program (zero-slippage Δᵢ⋆) — GAMS reference

*Spec · 2026-06-28 (rev 2, post two-step review) · owner: GAMS-development agent (`43wxo1px`, worktree `cfmm-wt/gams`, branch `feat/gams-payoff` off `origin/develop` @ `81fb24d`)*

> **Rev 2 changelog.** Reality Checker + Model QA Specialist returned with **5 BLOCKERs** and **9 MAJORs** against rev 1, including a load-bearing mathematical error (the prior cycle's `2^96` lesson in a new dimension): **Lean's `P_half lam Δᵢ i := λ^(i·Δᵢ)` is the un-squared kernel, while Plank's `sqrtPX96` is the sqrt-price with `/2` in the exponent**. Both PRs are already merged, both go by `π_{1/2}^trader` in prose, and they are **different functions in different coordinate systems**. Rev 1 conflated them; empirically the rev-1 `pi_trader_half` macro yielded `π ≈ 2.4e-5` (vs ≈ 0) at the canonical config, and the integer-enumeration argmin landed at `35 ≈ 2·17.56` rather than the promised `18`. Rev 2 makes the coordinate split EXPLICIT and exposes both coordinate-specific payoff macros; the GDX exports both `Δᵢ⋆`s with provenance noting which is the EVM control target. Additional fixes: GAMS-syntax bugs (multi-line `$macro` invocation, `round()` inside abort value-list), absolute zero-reference tolerance, GDX workflow specified (separate fixture-generation target), Lean-theorem provenance scalars, NLP tolerance loosened to CONOPT default precision, `_Half_Lean`/`_Half_Plank` naming discipline applied preemptively, monotonicity property added (catches misformulations that still happen to zero at the right point).

## 1. Context

Two upstream merges set the stage:

- **Plank `feat/plank` (merged):** added `cfmm-wt/plank/src/exp/CESLongPayoff.plk`, a stateless EVM evaluator of the η=½ trader payoff using Uniswap V3's `getNextSqrtPriceFromAmount0RoundingUp` (== this repo's `priceImpactKernel_Add0`) and `getAmount1DeltaUnsigned`. Plank's `P_{1/2}(i) ≡ sqrtPX96` (Q64.96 sqrt-price) explicitly per its docstring.
- **Lean PR #2 (MERGED into develop at `81fb24d`):** the math peer's PR `feat/lean4-spec` shipped eight markdown specs in `lean/exp/` (one per proven theorem) plus the Lean source `lean/exp/eta.lean` (731 lines, Aristotle-proven `eta_split_kernel_identity` + ~10 further theorems). **Lean's `P_half lam Δᵢ i := λ^((i:ℝ)·Δᵢ)`** is defined in `eta.lean:38–39` — a *price*, NOT a sqrt-price (no `/2`).

These two definitions disagree by a squaring: `sqrtPX96_real = sqrt(P_half_Lean)`, equivalently `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean`. The GAMS PayoffModule must bridge these two coordinate systems explicitly — this is a load-bearing design discovery from the rev-1 two-step review.

This GAMS PayoffModule is the **programmatic counterpart** that, for each Lean theorem, (a) OBTAINS the induced convex-program optimum (numerically), (b) CONTRASTS it against BOTH the Lean closed form (theorem corroboration) AND the Plank evaluator (EVM corroboration), and (c) EXPORTS the optimum to a per-theorem GDX as a **control-target artefact** for a future EVM controller. The EVM controller (separate spec, future cycle) acts on Plank's payoff, so the canonical control target is in **Plank coordinates**.

The current `model/PayoffModule.gms` is a stub. This spec replaces it with an orchestrator + scaffolding + the first theorem's program; subsequent brainstorm cycles add one per-theorem file each.

## 2. Goal

Land the PayoffModule scaffolding (file layout, dual-coordinate macros, integer-scale conventions, GDX-as-control-target schema with provenance) and one concrete first program — `eta_pi_trader_zero_slippage.gms` — that corroborates Lean's `pi_trader_half_zero_at_deltaI_star` theorem (in Lean coordinates) AND the Plank `cesLongPayoff` evaluator's zero (in Plank coordinates, via the bridge `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean`), then exports the discrete Plank-coordinate control target `Δᵢ⋆_Plank_int ∈ {1, …, 200}` for the future EVM controller.

## 3. Decisions (with rationale)

| # | Decision | Why |
|---|----------|-----|
| D1 | **Per-theorem files under `model/payoff/`.** Each Lean theorem maps to one `.gms` file owning its Model/Solve, enumeration, cross-checks, and GDX export. `PayoffModule.gms` is a thin orchestrator. | Mirrors my prior per-kernel pattern. Each cycle's subagent touches one file. |
| D2 | **Shared `_PayoffScaffolding.gms`.** Include-guarded; houses dual-coordinate macros, scale constants, provenance scalars. | DRY without premature abstraction. |
| D3 | **First theorem = `pi_trader_half_zero_at_deltaI_star` (eta.lean:518).** | Small-trade regime, closed-form Δᵢ⋆ that drives π = 0 (in both coordinates). Strongest scaffolding test — exercises Lean-coord, Plank-coord, NLP, enumeration, and monotonicity cross-checks. |
| D4 | **Integer-scale conventions, end-to-end (no real decimals leak into the GDX).** | Inherits the binary-fixed-point lineage Uniswap V3's TickMath uses. EVM consumer reads control targets without decoding floats. |
| D4a | **`λ` in WAD** (`λ_real · 1e18`); inherited from `PricingKernel.gms`. | `1.0001 · 1e18 = 1000100000000000000`. |
| D4b | **`i` (tick index) as raw int24.** | Uniswap convention. Canonical config: `i = 60`. |
| D4c | **`Δᵢ` (tick spacing) as positive integer ∈ {1, …, 200}.** User-specified operational bound. | Lean treats Δᵢ as a real; GAMS solves the continuous relaxation for theorem corroboration AND enumerates `{1..200}` for the discrete control target. Bounds-binding configs are BAND MIN/MAX's job — separate cycles. |
| D4d | **`L̄`, `Δ^I` in Q128.128** (`L_real · 2^128` as uint256). User-specified. | Q128.128 gives 128 fractional bits below 1 (sub-unit precision the η-CES analysis benefits from) and 128 integer bits above. Boundary-converted to raw inside the payoff macros so `priceImpactKernel_Add0` (raw L/raw dx) composes unchanged. |
| D4e | **`η` in Q0.128** (`η · 2^128` as uint128). User-specified. | `η = ½ → 2^127` exactly. Same binary lineage as L Q128.128. Confirmed by the algorithm hint: Uniswap V3 TickMath's lookup constants are Q128.128, so the implicit "1/2" in the sqrt lives at Q128 precision. |
| D4f | **`sqrtPX96` in Q64.96.** Uniswap convention. | Unchanged from PricingKernel/TickMath. |
| D4g | **`π_Plank` in `(raw real)²`.** | Mirrors Plank `CESLongPayoff.plk`. Q128.128 boundary divisions make `term_Plank` and `ΔO_Plank` both real-unit token amounts; squared is (real)². |
| D4h | **`π_Lean` in `(real ratio · real amount)²`.** | Lean's `P_Lean · Δ^I − L̄·(P_Lean − P_Lean_post)` lives in real units after Q128 boundary cancellation. Same scale as π_Plank for L̄ ≈ Δ^I ≈ O(1). |
| **D4i** | **Dual coordinate convention is LOAD-BEARING and EXPLICIT.** | Lean: `P_half_Lean := λ^(i·Δᵢ)` (price, no /2). Plank: `sqrtPX96 := λ^(i·Δᵢ/2)·Q96` (sqrt-price, with /2). Bridge: `sqrtPX96 = sqrt(P_Lean)·Q96`; therefore `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean`. Rev 1 conflated them. Rev 2 ships dual macros (`piTrader_Half_Lean`, `piTrader_Half_Plank`) so future per-theorem files can pick the right side for what they're corroborating. |
| D5 | **Solver workhorse = integer enumeration; NLP relaxation kept and properly wired.** Discrete argmin via `smin` over 200 elements. NLP (CONOPT) runs in Plank coord; its outputs populate the `solver` column of the GDX. | Enumeration is bit-exact and license-free; NLP scaffolds the Model/Solve idiom for cycle 2+. |
| D6 | **GDX schema: 4 sources × 4 targets = 16 cells in `optimum(sourceD, targetD)`** plus full provenance. Sources: `lean, plank, solver, enumeration`. Targets: `diStarInt, piAtDiStarReal, sqrtPAtDiStarQ96, PLeanAtDiStarReal`. | Both coordinates are exported. Auditor + EVM-controller author both have full traceability. |
| D7 | **Two tolerances:** `diffTolerance = 1e-12` (relative, for non-zero references — inherits spec §D9) AND `zeroTolerance = 1e-20` (ABSOLUTE, for zero references like π at Δᵢ⋆). | Rev 1 used relative tolerance against a zero reference, which is mathematically undefined. `zeroTolerance` derived from IEEE round-off floor for the squared-shortfall computation at canonical scales. |
| D8 | **Bounds-binding guard for BOTH coordinates** (`1 ≤ Δᵢ⋆_Lean ≤ 200` AND `1 ≤ Δᵢ⋆_Plank ≤ 200`). | Interior-optimum theorem only. Boundary cases → BAND MIN/MAX cycles. |
| D9 | **NLP cross-check tolerance loosened to `1e-8`** (CONOPT's default precision, not 1e-12). | Rev 1 used `1e-12` for the NLP-vs-closed-form check; CONOPT's default `rtmaxv`/`rtredg` floors achievable accuracy at ~1e-8. A tighter tol would require explicit CONOPT options. Pin 1e-8 as the documented expectation; tighten via option file if a future program needs to. |
| D10 | **Macro naming discipline applied preemptively.** η=½-specific macros suffixed `_Half`; coordinate-specific siblings `_Half_Lean` / `_Half_Plank`. | Mirrors the priceImpactKernel `_Add0` lesson. Renaming cost is one Edit now vs N+1 once siblings ship. |

## 4. Architecture (files affected)

```
model/
├── PayoffModule.gms                              EDIT: stub → thin orchestrator
├── payoff/
│   ├── _PayoffScaffolding.gms                    NEW : dual-coord macros + scale constants + provenance
│   └── eta_pi_trader_zero_slippage.gms           NEW : first theorem's program (both coordinates)
├── payoff_zero_slippage.gdx                      NEW : committed control-target fixture (generated via Makefile target)
└── test/
    └── PayoffModuleTest.gms                      NEW : rolled-up test (drives all per-program asserts)
docs/superpowers/specs/
└── 2026-06-28-payoff-zero-slippage-design.md     NEW : this spec
```

**Makefile** gains one new target `payoff-fixtures` (see §12). Final expected counts after Task 1 lands: **`compile-gams: 10 ok / 0 failed`** (the prior 8 model-root .gms files + `_PayoffScaffolding.gms` + `eta_pi_trader_zero_slippage.gms`; both new files are at `model/payoff/`, which `find` recurses into) and **`test-gams: 3 passed / 0 failed`** (the prior 2 + `PayoffModuleTest.gms`). The committed GDX is produced by **`make payoff-fixtures`** (NOT by compile-gams or test-gams).

The prior 8 model-root .gms files (verified at the spec's pinned commit `81fb24d` via `find model -name '*.gms' -not -path '*/test/*' -not -path '*/build/*' | sort`): `dynamic/InitState.gms`, `LiquidityKernel.gms`, `PayoffModule.gms`, `PriceImpactKernelFixture.gms`, `PricingKernel.gms`, `_PriceImpactKernelInputs.gms`, `primitives.gms`, `TradingRegion.gms`.

## 5. Shared scaffolding — `model/payoff/_PayoffScaffolding.gms`

**Critical syntactic note:** GAMS `$macro` requires its body — including the entire argument-list of any invocation — on a **single physical source line**. Every macro definition below is one line; every macro invocation in §6 must also be one line, however long. The rev-1 spec wrapped invocations across lines and would have failed to compile (GAMS errors 726/727/730).

```gams
$if set PAYOFF_SCAFFOLDING_INCLUDED $exit
$setGlobal PAYOFF_SCAFFOLDING_INCLUDED 1

$include PricingKernel.gms                    * lambda (WAD), unity, priceImpactKernel_Add0 (raw L)

* ── Binary fixed-point scale constants (mirroring Uniswap V3 TickMath lineage) ──
Scalar Q96  ;  Q96  = power(2,  96);          * Q64.96 for sqrt prices
Scalar Q128 ;  Q128 = power(2, 128);          * Q128.128 for L̄/Δ^I ; Q0.128 for η

* ── Operational bounds on Δᵢ ──
Scalar diMinInt / 1   /;
Scalar diMaxInt / 200 /;

* ── COORDINATE TRANSLATION (Lean ↔ Plank ↔ GAMS) — LOAD-BEARING ──
*
*   Lean:    P_half lam Δᵢ i := λ^((i:ℝ)·Δᵢ)         [eta.lean:38, a PRICE — no /2]
*   Plank:   sqrtPX96(λ,i,Δᵢ) := λ^(i·Δᵢ/2)·Q96      [CESLongPayoff.plk, a SQRT-PRICE]
*   Bridge:  sqrtPX96 = sqrt(P_Lean) · Q96
*   Hence:   Δᵢ⋆_Plank = 2 · Δᵢ⋆_Lean   (the sqrt squashes the half)
*
* Both payoff macros are exposed below — choose by which coordinate you're testing:
*   piTrader_Half_Lean  : matches Lean's pi_trader_half     (uses P_Lean, unsquared)
*   piTrader_Half_Plank : matches Plank's cesLongPayoff     (uses sqrtPX96)

* ── Lean-coordinate evaluators ──
* P_Lean(λ, i, Δᵢ) := λ^(i·Δᵢ) — a dimensionless price ratio (no Q-scaling).
$macro P_Lean_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)) )
* P_Lean_post := L̄·P/(L̄ + Δ^I·P); Q128 cancels inside the ratio cleanly.
$macro P_Lean_post(P, LQ128, DIQ128) ( (LQ128)*(P) / ((LQ128) + (DIQ128)*(P)) )
* Lean payoff (eta.lean:195, `pi_trader_half`): π_Lean = ( P·Δ^I − L̄·(P − P_post) )².
$macro piTrader_Half_Lean(P, LQ128, DIQ128) ( sqr( (P)*(DIQ128)/Q128 - (LQ128)*((P) - P_Lean_post((P),(LQ128),(DIQ128)))/Q128 ) )

* ── Plank-coordinate evaluators ──
* sqrtPX96 at continuous (i, Δᵢ) — Q64.96 sqrt-price (with /2 and ·Q96, Plank/Uniswap convention).
$macro sqrtPX96_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)/2) * Q96 )
* Boundary adapter — priceImpactKernel_Add0 takes raw L and raw dx; we hand it Q128.128.
$macro priceImpactQ128_Add0(sqrtP, LQ128, dxQ128) ( priceImpactKernel_Add0((sqrtP), (LQ128)/Q128, (dxQ128)/Q128) )
* Plank payoff (CESLongPayoff.plk:33–43): π_Plank = (sqrtP·Δ^I/Q96 − L̄·(sqrtP − sqrtQ)/Q96)².
$macro traderTerm_Half_Plank(sqrtP, DIQ128)            ( (sqrtP)*(DIQ128)/Q128/Q96 )
$macro traderDeltaO_Half_Plank(sqrtP, sqrtQ, LQ128)    ( (LQ128)*((sqrtP) - (sqrtQ))/Q128/Q96 )
$macro piTrader_Half_Plank(sqrtP, LQ128, DIQ128) ( sqr( traderTerm_Half_Plank((sqrtP),(DIQ128)) - traderDeltaO_Half_Plank((sqrtP), priceImpactQ128_Add0((sqrtP),(LQ128),(DIQ128)), (LQ128)) ) )

* ── Shared provenance + tolerance scalars (every fundamental quantity at integer scale) ──
Scalar etaQ128 ;     etaQ128 = power(2, 127);            * = η = 1/2 in Q0.128 (bit-exact, mirrors Q128's `power(2,128)`)
Scalar gamsVersion / 54.1 /;
Scalar modelVersion / 2 /;                                * cycle 1, spec rev 2
Scalar lambdaWad ;   lambdaWad = lambda;                  * = 1.0001·1e18 WAD
Scalar diffTolerance / 1e-12 /;                            * RELATIVE tol for non-zero references (spec §D9)
Scalar zeroTolerance / 1e-20 /;                            * ABSOLUTE tol for ZERO references (rev-2 D7)
Scalar tieBreaking   / 1 /;                                * 1=smallest, 2=largest, 3=midpoint (enumeration tie convention)
```

**Numerical precision note** (RC's MAJOR): `LbarQ128 = 2^128 ≈ 3.4e38` exceeds IEEE-double exactly-representable integer range (`2^53 ≈ 9e15`). The boundary cancellation `LbarQ128 / Q128 = 1.0` is exact under double arithmetic, and ratios like `LbarQ128 / (LbarQ128 − DICfgQ128)` remain numerically clean (the product magnitude is reduced before the division). The IEEE round-off floor on the helper-lemma cross-check is empirically `~1e-15`, comfortably below the `1e-12` relative tolerance.

## 6. First program — `model/payoff/eta_pi_trader_zero_slippage.gms`

```gams
$title Zero-slippage Δᵢ⋆ — Lean theorem `pi_trader_half_zero_at_deltaI_star` + Plank cesLongPayoff zero
$include _PayoffScaffolding.gms

* ── Canonical single config (Q128.128 amounts) ──
Scalar iCfg        / 60 /;
Scalar LbarQ128 ;  LbarQ128  = Q128;                       * L̄ = 1 (real) in Q128.128
Scalar DICfgQ128 ; DICfgQ128 = Q128 / 10;                  * Δ^I = 0.1 in Q128.128

* ── Lean-coordinate closed forms (verbatim from eta.lean:491–512) ──
* Δᵢ⋆_Lean = log(L̄/(L̄−Δ^I)) / (log λ · i)  ≈ 17.56 at canonical config.
Scalar diStarLeanReal ;
diStarLeanReal       = log(LbarQ128 / (LbarQ128 - DICfgQ128)) / (log(lambdaWad/unity) * iCfg);
* Lean helper: P_Lean(Δᵢ⋆_Lean) = L̄/(L̄−Δ^I) — real ratio (no Q-scaling).
Scalar PHalfAtStarLeanReal ;
PHalfAtStarLeanReal  = LbarQ128 / (LbarQ128 - DICfgQ128);

* ── Plank-coordinate closed forms (via the bridge Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean) ──
Scalar diStarPlankReal ;  diStarPlankReal = 2 * diStarLeanReal;     * ≈ 35.12
* Plank helper: sqrtPX96(Δᵢ⋆_Plank) = sqrt(L̄/(L̄−Δ^I)) · Q96.
Scalar sqrtPAtStarPlankExpectedQ96 ;
sqrtPAtStarPlankExpectedQ96 = sqrt(PHalfAtStarLeanReal) * Q96;

* ── Bounds-binding guard (BOTH coordinates must be interior in [1, 200]) ──
abort$(diStarLeanReal < diMinInt or diStarLeanReal > diMaxInt)
    "Out of zero-slippage regime: Δᵢ⋆_Lean outside [1, 200] — use band_min/band_max", diStarLeanReal;
abort$(diStarPlankReal < diMinInt or diStarPlankReal > diMaxInt)
    "Out of zero-slippage regime: Δᵢ⋆_Plank outside [1, 200] — use band_min/band_max", diStarPlankReal;

* ── (X) Cross-coordinate consistency (sanity: the bridge identity) ──
abort$(abs(diStarPlankReal - 2*diStarLeanReal) / diStarLeanReal > diffTolerance)
    "FAIL: bridge identity Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean violated", diStarLeanReal, diStarPlankReal;

* ── (A_Lean) Lean payoff at Δᵢ⋆_Lean must be ≈ 0 — corroborates Lean theorem ──
Scalar PLeanAtStar ;      PLeanAtStar      = P_Lean_at(lambdaWad, iCfg, diStarLeanReal);
Scalar piAtStarLeanReal ; piAtStarLeanReal = piTrader_Half_Lean(PLeanAtStar, LbarQ128, DICfgQ128);
abort$(abs(piAtStarLeanReal) > zeroTolerance)
    "FAIL: Lean π at Δᵢ⋆_Lean must be ≈ 0 absolute (zero-reference)", piAtStarLeanReal;

* ── (B_Lean) Lean helper at Δᵢ⋆_Lean: P_Lean(Δᵢ⋆_Lean) ≈ L̄/(L̄−Δ^I) ──
abort$(abs(PLeanAtStar - PHalfAtStarLeanReal) / PHalfAtStarLeanReal > diffTolerance)
    "FAIL: Lean P_half(Δᵢ⋆_Lean) must equal L̄/(L̄−Δ^I)", PLeanAtStar, PHalfAtStarLeanReal;

* ── (A_Plank) Plank payoff at Δᵢ⋆_Plank must be ≈ 0 — corroborates Plank evaluator ──
Scalar sqrtPAtStarPlankQ96 ;  sqrtPAtStarPlankQ96 = sqrtPX96_at(lambdaWad, iCfg, diStarPlankReal);
Scalar piAtStarPlankReal ;    piAtStarPlankReal   = piTrader_Half_Plank(sqrtPAtStarPlankQ96, LbarQ128, DICfgQ128);
abort$(abs(piAtStarPlankReal) > zeroTolerance)
    "FAIL: Plank π at Δᵢ⋆_Plank must be ≈ 0 absolute (zero-reference)", piAtStarPlankReal;

* ── (B_Plank) Plank helper at Δᵢ⋆_Plank: sqrtP(Δᵢ⋆_Plank) ≈ sqrt(L̄/(L̄−Δ^I))·Q96 ──
abort$(abs(sqrtPAtStarPlankQ96 - sqrtPAtStarPlankExpectedQ96) / sqrtPAtStarPlankExpectedQ96 > diffTolerance)
    "FAIL: Plank sqrtPX96(Δᵢ⋆_Plank) must equal sqrt(L̄/(L̄−Δ^I))·Q96", sqrtPAtStarPlankQ96, sqrtPAtStarPlankExpectedQ96;

* ── (C_Plank) NLP relaxation in PLANK coord — control target lives here ──
Positive Variable di ;
di.lo = diMinInt;
di.up = diMaxInt;
di.l  = diStarPlankReal / 2;                              * start below optimum, exercise descent
Variable piVal ;
Equation payoffEq ;
* Single-line macro invocation (multi-line would fail GAMS $macro expansion):
payoffEq.. piVal =e= piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, di), LbarQ128, DICfgQ128);

Model ZeroSlip / payoffEq /;
option nlp = conopt;
Solve ZeroSlip using nlp minimizing piVal;
abort$(ZeroSlip.modelStat <> %modelStat.locallyOptimal% and ZeroSlip.modelStat <> %modelStat.optimal%)
    "FAIL: ZeroSlip NLP did not reach optimum", ZeroSlip.modelStat, ZeroSlip.solveStat;
* CONOPT default precision ~1e-8 — loosen from §D7 1e-12 (spec §D9).
abort$(abs(di.l - diStarPlankReal) / diStarPlankReal > 1e-8)
    "FAIL: NLP argmin must match Plank closed-form Δᵢ⋆_Plank to CONOPT default tol", di.l, diStarPlankReal;

* ── (D_Plank) Integer enumeration over Δᵢ ∈ {1..200} — derives the operational control target ──
Set       diGrid /1*200/ ;
Parameter diVal(diGrid) ;  diVal(diGrid) = ord(diGrid);
Parameter piGrid(diGrid) ;
* Single-line macro invocation:
piGrid(diGrid) = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diVal(diGrid)), LbarQ128, DICfgQ128);
Scalar piMinInt ;  piMinInt = smin(diGrid, piGrid(diGrid));
* Tie-breaking convention: tieBreaking=1 ⇒ smallest argmin under ties (see scaffolding).
Scalar diStarInt ;  diStarInt = smin(diGrid$(piGrid(diGrid) = piMinInt), diVal(diGrid));
* Hoist round() to a Scalar — GAMS forbids function calls in abort/display value-lists.
Scalar diStarPlankIntExpected ;  diStarPlankIntExpected = round(diStarPlankReal);
abort$(abs(diStarInt - diStarPlankIntExpected) > 0)
    "FAIL: discrete enumeration argmin must equal round(Δᵢ⋆_Plank)", diStarInt, diStarPlankIntExpected;

* ── (E) Monotonicity property (per Lean `pi_trader_half_strictly_increasing_in_Δi`) ──
* π_Plank monotone-decreasing on [1, ⌊Δᵢ⋆_Plank⌋], monotone-increasing on [⌈Δᵢ⋆_Plank⌉, 200].
Scalar diStarFloor ;  diStarFloor = floor(diStarPlankReal);
Scalar diStarCeil  ;  diStarCeil  = ceil(diStarPlankReal);
Set leftArmBreaks(diGrid) ;
leftArmBreaks(diGrid) $(ord(diGrid) > 1 and ord(diGrid) <= diStarFloor and piGrid(diGrid) >= piGrid(diGrid-1)) = yes;
Scalar leftBreakCount ;   leftBreakCount  = card(leftArmBreaks);
abort$(leftBreakCount > 0)
    "FAIL: π_Plank should be strictly decreasing on [1, ⌊Δᵢ⋆_Plank⌋]", leftBreakCount;
Set rightArmBreaks(diGrid) ;
rightArmBreaks(diGrid) $(ord(diGrid) >= diStarCeil and ord(diGrid) < 200 and piGrid(diGrid) >= piGrid(diGrid+1)) = yes;
Scalar rightBreakCount ;  rightBreakCount = card(rightArmBreaks);
abort$(rightBreakCount > 0)
    "FAIL: π_Plank should be strictly increasing on [⌈Δᵢ⋆_Plank⌉, 200]", rightBreakCount;

* ── Control-target GDX export (with Lean-theorem provenance) ──
Set inputD    / lambdaWad, iTick, LbarQ128, DeltaIQ128, etaQ128, diMinInt, diMaxInt /;
Set targetD   / diStarInt, piAtDiStarReal, sqrtPAtDiStarQ96, PLeanAtDiStarReal /;
Set sourceD   / lean, plank, solver, enumeration /;

Parameter inputs(inputD);
inputs('lambdaWad')   = lambdaWad;
inputs('iTick')       = iCfg;
inputs('LbarQ128')    = LbarQ128;
inputs('DeltaIQ128')  = DICfgQ128;
inputs('etaQ128')     = etaQ128;
inputs('diMinInt')    = diMinInt;
inputs('diMaxInt')    = diMaxInt;

Parameter optimum(sourceD, targetD);
* `lean` column: closed-form predictions in Lean coord (the theorem corroboration baseline).
optimum('lean',        'diStarInt')          = round(diStarLeanReal);
optimum('lean',        'piAtDiStarReal')     = 0;                                       * theorem: π=0 exact
optimum('lean',        'sqrtPAtDiStarQ96')   = sqrt(PHalfAtStarLeanReal) * Q96;         * via bridge
optimum('lean',        'PLeanAtDiStarReal')  = PHalfAtStarLeanReal;
* `plank` column: closed-form predictions in Plank coord (the EVM CONTROL TARGET).
optimum('plank',       'diStarInt')          = diStarPlankIntExpected;                   * = round(Δᵢ⋆_Plank)
optimum('plank',       'piAtDiStarReal')     = 0;
optimum('plank',       'sqrtPAtDiStarQ96')   = sqrtPAtStarPlankExpectedQ96;
optimum('plank',       'PLeanAtDiStarReal')  = PHalfAtStarLeanReal;
* `solver` column: NLP outputs at Plank coord (real values from CONOPT).
optimum('solver',      'diStarInt')          = round(di.l);
optimum('solver',      'piAtDiStarReal')     = piVal.l;
optimum('solver',      'sqrtPAtDiStarQ96')   = sqrtPX96_at(lambdaWad, iCfg, di.l);
optimum('solver',      'PLeanAtDiStarReal')  = P_Lean_at(lambdaWad, iCfg, di.l/2);       * un-sqrt to Lean coord
* `enumeration` column: the canonical operational target the EVM controller reads.
optimum('enumeration', 'diStarInt')          = diStarInt;
optimum('enumeration', 'piAtDiStarReal')     = piMinInt;
optimum('enumeration', 'sqrtPAtDiStarQ96')   = sqrtPX96_at(lambdaWad, iCfg, diStarInt);
optimum('enumeration', 'PLeanAtDiStarReal')  = P_Lean_at(lambdaWad, iCfg, diStarInt/2);

* ── Lean-theorem provenance (SetText singletons for string-valued metadata) ──
Set theoremNameSet      / 'pi_trader_half_zero_at_deltaI_star' /;
Set leanFileSet         / 'lean4-spec/lean/exp/eta.lean' /;
Set leanLineSet         / '518' /;
Set aristotleProjectSet / '88d393e7-ec4e-438f-a5fd-9f34aab1c2e5' /;
Scalar theoremStatus / 1 /;                                * 1=proven, 0=sorry, -1=conjectured

execute_unload 'payoff_zero_slippage.gdx',
    inputs, optimum,
    gamsVersion, modelVersion, lambdaWad, etaQ128,
    diffTolerance, zeroTolerance, tieBreaking,
    theoremStatus, theoremNameSet, leanFileSet, leanLineSet, aristotleProjectSet;

display "PASS: zero-slippage — Lean+Plank coordinates corroborated; control target =", diStarInt;
display "  Lean coord:  ", diStarLeanReal, PLeanAtStar, piAtStarLeanReal;
display "  Plank coord: ", diStarPlankReal, sqrtPAtStarPlankQ96, piAtStarPlankReal;
display "  Enum:        ", diStarInt, piMinInt;
display "  Solver:      ", di.l, piVal.l;
```

## 7. Orchestrator — `model/PayoffModule.gms`

```gams
$title PayoffModule orchestrator — $include the per-theorem subset the driver wants.
* Per-theorem files $include _PayoffScaffolding.gms themselves (include-guarded), so
* the orchestrator just lists them in dependency order — no separate scaffolding include here.
$include payoff/eta_pi_trader_zero_slippage.gms
* Future cycles append (one $include line per cycle):
* $include payoff/eta_pi_trader_band_min.gms
* $include payoff/eta_pi_trader_band_max.gms
* $include payoff/eta_sigma_xs_target_inversion.gms
* $include payoff/eta_split_kernel_identity.gms
```

## 8. Test rollup — `model/test/PayoffModuleTest.gms`

```gams
$title PayoffModule rolled-up assertion test
* action=ce (from `make test-gams`) drives the per-program asserts inside every $include'd payoff file.
* Note: this test invokes a real NLP Solve (CONOPT) — make test-gams now depends on CONOPT being available.
$include PayoffModule.gms
display "PASS: all PayoffModule per-program asserts cleared.";
```

## 9. GDX schema (committed contract for the future EVM-controller author)

| GDX symbol | Indexing | Value | Scale | Semantics |
|---|---|---|---|---|
| `inputs(inputD)` | 7 keys | scalar per key | mixed (named in key) | Canonical config + operational bounds. |
| `optimum(sourceD, targetD)` | 4 × 4 = 16 cells | scalar per cell | mixed (named in key suffix) | `sourceD ∈ {lean, plank, solver, enumeration}` × `targetD ∈ {diStarInt, piAtDiStarReal, sqrtPAtDiStarQ96, PLeanAtDiStarReal}`. **Controller reads `optimum('enumeration','diStarInt')` as the operational control target.** |
| `gamsVersion` / `modelVersion` | scalars | `54.1` / `2` | dimensionless | toolchain + spec rev provenance |
| `lambdaWad` / `etaQ128` | scalars | WAD / Q0.128 | as named | numeric provenance |
| `diffTolerance` / `zeroTolerance` / `tieBreaking` | scalars | `1e-12` / `1e-20` / `1` | dimensionless | the tolerances/conventions cross-checks were asserted at |
| `theoremStatus` | scalar | `1` (proven) | dimensionless | Lean-theorem status |
| `theoremNameSet` / `leanFileSet` / `leanLineSet` / `aristotleProjectSet` | 1-element sets | string text via GDX SetText | dimensionless | Lean-theorem string provenance (auditable from the GDX alone) |

## 10. Success criteria

- `model/PayoffModule.gms` orchestrates 1 per-theorem file (`eta_pi_trader_zero_slippage.gms`), which itself $includes `_PayoffScaffolding.gms` (include-guarded).
- `make compile-gams` → **10 ok / 0 failed**.
- `make test-gams` → **3 passed / 0 failed** (per-program asserts (A_Lean), (B_Lean), (A_Plank), (B_Plank), (C_Plank), (D_Plank), (E), (X) all clear).
- `make payoff-fixtures` (new Makefile target — see §12) runs `gams payoff/eta_pi_trader_zero_slippage.gms action=ce …` from `model/`, producing `model/payoff_zero_slippage.gdx` exactly once.
- `gdxdump model/payoff_zero_slippage.gdx Symbols` lists `inputs`, `optimum`, `gamsVersion`, `modelVersion`, `lambdaWad`, `etaQ128`, `diffTolerance`, `zeroTolerance`, `tieBreaking`, `theoremStatus`, `theoremNameSet`, `leanFileSet`, `leanLineSet`, `aristotleProjectSet` (14 symbols), plus the auto-promoted domain sets `inputD`, `targetD`, `sourceD`, `diGrid`, `leftArmBreaks`, `rightArmBreaks`.
- `optimum('enumeration', 'diStarInt')` for the canonical config equals **`round(2 · log(10/9) / (log(1.0001) · 60))` = `round(35.1175)` = `35`** (the Plank-coordinate control target, NOT Lean's 18).
- `optimum('lean', 'diStarInt') = round(17.5587) = 18` (Lean-coordinate value, exported for cross-coordinate audit).
- `.gitignore` extends the existing `!model/price_impact_kernel.gdx` re-include with `!model/payoff_zero_slippage.gdx`. **`git add -f` is forbidden** — implementer must add the .gitignore patch BEFORE `git add` the GDX.
- Expected GDX size: ≤ 6 KB. `gdxdump model/payoff_zero_slippage.gdx | wc -l` ≈ 80.

## 11. Out of scope (explicit YAGNI)

- **EVM controller.** This spec produces the control-target GDX; the controller is future work.
- **Differential test against `CESLongPayoff.plk`.** Evaluator diff (analogous to my `priceImpactKernel` work), distinct from the convex-program track. Future cycle if wanted.
- **Bounds-binding configs** (`Δᵢ⋆ ∉ [1, 200]`). BAND MIN/MAX theorems' job.
- **Multi-config grids.** Q3-locked: per-theorem GDX is single-config. **MQA review pushback noted:** they argued for 3–4 configs to exercise small-Δ^I, large-Δ^I, and small-i regimes; deferred per the Q3 lock. Revisit when an EVM-controller use case demonstrates the gap.
- **MIP/MINLP solve.** Integer enumeration is sufficient on `{1..200}`. Larger domains re-open this.
- **η-tunable variants.** `_Half` suffix discipline reserves the namespace for `_Tunable_…` if needed; the lean-proven kernel-split identity opens that path but the EVM side hasn't shipped.
- **Lean-side rebroadcast of `P_half := λ^(i·Δᵢ/2)`.** Would eliminate the coordinate split entirely but requires re-discharging all Aristotle proofs (~35 min/theorem cached). Not this spec's call; out-of-track.

## 12. Workflow

- **Branch:** `feat/gams-payoff` off `origin/develop` @ `81fb24d` (already created).
- **Lean PR #2 status:** MERGED to develop at the spec's pinned commit. Lean files are on `develop`; no PR dependency.
- **New Makefile target `payoff-fixtures`** (regenerates the committed per-theorem GDXs):

  ```makefile
  # payoff-fixtures: regenerate committed per-theorem payoff GDX(s).
  # Runs each per-theorem .gms with action=ce from model/ so execute_unload's relative
  # path lands the .gdx at the model root. Separate from gams-fixtures (gamsdiff peer's).
  .PHONY: payoff-fixtures
  payoff-fixtures:
  	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
  	@cd $(GAMS_DIR) && rc=0; \
  	for f in $$(find payoff -name 'eta_*.gms' | sort); do \
  		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
  		printf '>> regenerating fixture from %s\n' "$$f"; \
  		if $(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
  			printf '   OK %s\n' "$$f"; \
  		else \
  			printf '   FAIL %s -> %s/%s\n' "$$f" "$(GAMS_DIR)" "$$out"; rc=1; \
  		fi; \
  	done; \
  	exit $$rc
  ```
  Add `payoff-fixtures` to the existing `.PHONY` line.
- **Per-cycle cadence:** brainstorm → spec (+ two-step review) → plan → SDD execution → review → PR to develop. **One theorem per cycle.**
- **Recommended sequence:** zero-slippage (this cycle) → band-min → band-max → variance-target → kernel-split.
- **Solver availability:** CONOPT ships under the GAMS demo license (verified empirically by RC review). The model is 1-D, fits trivially.

## 13. References

- **Lean PR #2 (MERGED into `develop` at `81fb24d`):** brought `lean/exp/eta.lean` + 8 per-theorem markdown specs in `lean/exp/`.
- **Lean theorem:** `cfmm-wt/lean4-spec/lean/exp/eta.lean:518` (`pi_trader_half_zero_at_deltaI_star`), `:491–498` (`deltaI_star` closed form), `:501–512` (`P_half_at_deltaI_star` helper), `:38–39` (`P_half := λ^(i·Δᵢ)` definition — un-squared, NOT a sqrt-price).
- **Lean per-theorem markdown:** `cfmm-wt/lean4-spec/lean/exp/eta_pi_trader_zero_slippage.md`.
- **Plank evaluator:** `cfmm-wt/plank/src/exp/CESLongPayoff.plk` — the EVM evaluator the future controller will use. Plank's `P_{1/2}(i) ≡ sqrtPX96` (with `/2` and `·Q96`, distinct coordinate from Lean's `P_half`).
- **Uniswap V3 reference:** `lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk` (`getNextSqrtPriceFromAmount0RoundingUp`, `getAmount1DeltaUnsigned`); TickMath's Q128.128 lookup constants.
- **Prior cycle's spec** (Q-scale conventions inherited): `docs/superpowers/specs/2026-06-28-price-impact-kernel-gams-design.md`.
- **GAMS-track scope memory:** `gams-agent-scope.md`.
- **Rev-1 two-step review record:** Reality Checker + Model QA Specialist findings (this conversation). Both reviewers independently identified the Lean-vs-Plank sqrt coordinate mismatch as the load-bearing BLOCKER; both empirically verified by hand-computing the canonical config.
