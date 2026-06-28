# PayoffModule scaffolding + first convex program (zero-slippage Δᵢ⋆) — GAMS reference

*Spec · 2026-06-28 (rev 3, post second two-step review) · owner: GAMS-development agent (`43wxo1px`, worktree `cfmm-wt/gams`, branch `feat/gams-payoff` off `origin/develop` @ `81fb24d`)*

> **Rev 3 changelog.** Rev 2's two-step review surfaced **two more BLOCKER-class math errors** that empirical reduction caught:
> 1. **B_Plank expected value was wrong by a `sqrt(·)` factor.** Rev 2's bridge gloss `sqrtPX96 = sqrt(P_Lean)·Q96` is true at *fixed Δᵢ* but was mis-applied to the Plank optimum. At Δᵢ⋆_Plank the doubling of Δᵢ cancels the macro's `/2`, so `sqrtPX96_at(λ, i, Δᵢ⋆_Plank) = (L̄/(L̄−Δ^I))·Q96`, NOT its sqrt. Rev 3 fixes the expected value to `PHalfAtStarLeanReal·Q96` and adds an explicit derivation of the bridge identity in §3 D4i.
> 2. **C_Plank NLP tolerance `1e-8` was empirically unsatisfiable.** The Q96-scaled squared-loss objective is so flat near the optimum that CONOPT terminates with relErr ~9e-3 even with `rtmaxv=rtredg=1e-15`. Rev 3 drops the precision claim and asserts only `modelStat = optimal`.
>
> Plus structural fix: (B_Lean) / (B_Plank) helper-lemma cross-checks were tautological (`exp(log(x)) = x` round-trips through GAMS's `log/**`). Rev 3 replaces them with an **independent probe-pair test** (B_indep) — evaluate the kernel at two non-optimum Δᵢ probes, verify the log-ratio matches the analytical `d log P / d Δᵢ = i·log λ` derivative. Adds (F) parabolic-interpolation argmin as a SECOND independent root-finding cross-check. Fixes (E) citation (small-trade V-shape derives from `slippage_residual` sign-change, NOT `pi_trader_half_strictly_increasing_in_Δi` which requires the large-trade regime). GDX `sqrtPAtDiStarQ96` column renamed and made coord-consistent across rows. "Observed" empirical residuals exported. **Rev-3 spec was empirically verified in `/tmp/rev3_test/` end-to-end before commit — every assert passes at the canonical config; `diArgminContinuous = 35.118` matches `diStarPlankReal = 35.122` to ~1e-4.**

## 1. Context

Two upstream merges set the stage:

- **Plank `feat/plank` (merged):** `cfmm-wt/plank/src/exp/CESLongPayoff.plk` — stateless EVM evaluator of the η=½ trader payoff. Plank's docstring: `P_{1/2}(i) ≡ sqrtPX96` (Q64.96).
- **Lean PR #2 (MERGED into develop at `81fb24d`):** brought `lean/exp/eta.lean` (731 lines) plus 8 per-theorem markdown specs. **Lean's `P_half lam Δᵢ i := λ^((i:ℝ)·Δᵢ)`** (eta.lean:38–39) — a *price*, NOT a sqrt-price (no `/2`).

These two `P_{1/2}`-named quantities live in different coordinate systems, related by `sqrtPX96 = sqrt(P_Lean)·Q96` *at fixed Δᵢ*. The implication for OPTIMA (Δᵢ values that zero the respective payoffs) is NOT a simple identity — it requires re-deriving the bridge through the priceImpactKernel_Add0 algebra (see §3 D4i derivation). Empirically and by symbolic verification: **Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean** (the factor-of-2 happens because the macro's `/2` is cancelled by the doubling).

This GAMS PayoffModule is the **programmatic counterpart** that, for each Lean theorem, (a) OBTAINS the convex-program optimum numerically, (b) CONTRASTS it against BOTH the Lean closed form AND the Plank evaluator (via the bridge identity), and (c) EXPORTS the optimum to a per-theorem GDX as a **control-target artefact** for a future EVM controller. The controller acts on Plank's payoff, so the canonical control target is in **Plank coordinates**.

## 2. Goal

Land the PayoffModule scaffolding + one concrete first program (`eta_pi_trader_zero_slippage.gms`) that corroborates Lean's `pi_trader_half_zero_at_deltaI_star` theorem AND Plank's `cesLongPayoff` zero via the empirically-verified bridge `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean`, then exports the discrete Plank-coordinate control target `Δᵢ⋆_Plank_int ∈ {1, …, 200}` for the future EVM controller.

## 3. Decisions (with rationale)

| # | Decision | Why |
|---|----------|-----|
| D1 | **Per-theorem files under `model/payoff/`.** | One Lean theorem per `.gms` file; orchestrator `$include`s the subset. |
| D2 | **Shared `_PayoffScaffolding.gms`.** Include-guarded. | Dual-coord macros, scale constants, provenance scalars. |
| D3 | **First theorem = `pi_trader_half_zero_at_deltaI_star`.** | Closed-form Δᵢ⋆ in both coordinates; exercises the full cross-check suite. |
| D4a–h | Scale conventions: `λ` WAD, `i` int24, `Δᵢ` int ∈ {1..200}, `L̄`/`Δ^I` Q128.128, `η` Q0.128, `sqrtPX96` Q64.96. | Inherits binary-fixed-point lineage from Uniswap V3 TickMath; matches the prior cycle's priceImpactKernel work. |
| **D4i** | **Bridge identity (LOAD-BEARING; derived from the priceImpactKernel_Add0 algebra, NOT a kernel-equality-at-fixed-Δᵢ statement).** Setting Plank's `term = ΔO` (i.e. `sqrtPX96·Δ^I/Q96 = L̄·(sqrtPX96 − sqrtQX96)/Q96`) and substituting the kernel's `sqrtQX96 = L̄·sqrtPX96/(L̄ + Δ^I·sqrtPX96/Q96)` yields, after Q96 cancellation: **`sqrtPX96 = (L̄/(L̄−Δ^I))·Q96`** at the Plank zero. Inverting through `sqrtPX96 = λ^(i·Δᵢ/2)·Q96` gives `Δᵢ⋆_Plank = 2·log(L̄/(L̄−Δ^I))/(i·log λ) = 2·Δᵢ⋆_Lean`. The factor-of-2 is a property of the two payoff zeros at different Δᵢ values (not a same-Δᵢ kernel equality). | Rev-2 reviewer's empirical reproduction confirmed both algebraic derivation and `sympy` cross-check. The bridge IS robust, but it is NOT the trivially-misleading "equivalently" implied by rev 2's gloss; it depends on the specific algebra of `priceImpactKernel_Add0`. If that algebra is ever reformulated, the bridge breaks. |
| D5 | **Workhorse: integer enumeration. NLP relaxation: scaffolding only.** | Enumeration is bit-exact, license-free. NLP's value is structural (Model/Solve idiom for later cycles), not numerical (precision is poor — see D9). |
| D6 | **GDX schema: `optimum(sourceD, targetD)` 4 × 4 = 16 cells.** `sourceD = {lean, plank, solver, enumeration}`; `targetD = {diStarInt, piAtDiStarObserved, P_Lean_at_DiStar, sqrtPX96_at_DiStar}`. Each row evaluates each target AT THAT ROW's `diStarInt` — consistent column semantics across rows. | Rev-2 reviewer caught semantic mismatch (closed-form rows vs solver rows meant different things). Rev 3 makes each cell self-consistently report state-at-this-row's-Δᵢ. |
| D7 | **Two tolerances:** `diffTolerance = 1e-12` (relative, non-zero refs) + `zeroTolerance = 1e-20` (ABSOLUTE, zero refs). | Rev-1 fix: relative-to-zero is mathematically undefined. |
| D8 | **Bounds-binding guard for BOTH coordinates.** | Interior-optimum theorem only. |
| **D9** | **NLP cross-check (C_Plank) drops precision claim; modelStat only.** | Rev-2 reviewer empirically confirmed: CONOPT's `rtredg` is gradient precision, not argmin precision. On a Q96-scaled squared-loss objective the second derivative near the optimum is `~Q96² · log(λ)² · tiny`, so the iterate stops 4–9 orders of magnitude away from the analytic argmin regardless of tolerance tightening (tested with `rtmaxv=rtredg=1e-15`). C_Plank's value is "did the solver-stack wire up without diverging," NOT "did it converge to the closed-form value" — (D_Plank) and (F) are the precision checks. |
| **D10** | **Drop tautological (B_Lean) and (B_Plank); replace with (B_indep) probe-pair test.** | Rev-2 reviewer caught: `P_Lean_at(λ, i, diStarLeanReal)` mechanically equals `exp(log(L̄/(L̄−Δ^I)))` by definition — a GAMS `**`/`log` round-trip, NOT a helper-lemma corroboration. (B_indep) tests the kernel definition via `log(P(b)/P(a)) = (b−a)·i·log λ` (analytical derivative integrated) at two non-optimum probe points — genuinely independent of the closed-form Δᵢ⋆. |
| **D11** | **Add (F) parabolic-interpolation argmin** as second independent root-find. | Three-point parabolic interp around the discrete enumeration argmin estimates the continuous argmin; compares to `diStarPlankReal`. Independent of the closed-form (uses only `piGrid` evaluations). Empirically matches to relErr ~1e-4. |
| D12 | **Macro naming discipline.** `piTrader_Half_Lean`, `piTrader_Half_Plank` etc. | Reserved namespace for cycle 2+ (band_min/band_max reuse Plank macro). |

## 4. Architecture (files affected)

```
model/
├── PayoffModule.gms                              EDIT: stub → thin orchestrator
├── payoff/
│   ├── _PayoffScaffolding.gms                    NEW : dual-coord macros + scale constants + provenance
│   └── eta_pi_trader_zero_slippage.gms           NEW : first theorem's program (both coordinates)
├── payoff_zero_slippage.gdx                      NEW : committed control-target fixture (via Makefile target)
└── test/
    └── PayoffModuleTest.gms                      NEW : rolled-up test (drives all per-program asserts)
docs/superpowers/specs/
└── 2026-06-28-payoff-zero-slippage-design.md     this spec
```

**Makefile** gains target `payoff-fixtures` (see §12). Final counts: **`compile-gams: 10 ok / 0 failed`**, **`test-gams: 3 passed / 0 failed`**. GDX produced by **`make payoff-fixtures`** (NOT by compile-gams or test-gams).

## 5. Shared scaffolding — `model/payoff/_PayoffScaffolding.gms`

**Critical syntactic note:** GAMS `$macro` requires its body AND every invocation's argument-list on a **single physical line**. Below every macro definition and every invocation in §6 is one line.

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
*   Lean:    P_Lean(λ, i, Δᵢ) := λ^(i·Δᵢ)          [eta.lean:38, a PRICE — no /2]
*   Plank:   sqrtPX96(λ, i, Δᵢ) := λ^(i·Δᵢ/2)·Q96  [CESLongPayoff.plk, a SQRT-PRICE]
*
*   Same-Δᵢ bridge:  sqrtPX96(λ,i,Δᵢ) = sqrt(P_Lean(λ,i,Δᵢ)) · Q96
*
*   Payoff-zero bridge (derived from priceImpactKernel_Add0 algebra; see §3 D4i):
*   Δᵢ⋆_Plank = 2 · Δᵢ⋆_Lean
*   At Δᵢ⋆_Plank: sqrtPX96 = (L̄/(L̄−Δ^I)) · Q96  (NOT its sqrt — the doubling cancels macro /2)

* ── Lean-coordinate evaluators ──
$macro P_Lean_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)) )
$macro P_Lean_post(P, LQ128, DIQ128) ( (LQ128)*(P) / ((LQ128) + (DIQ128)*(P)) )
$macro piTrader_Half_Lean(P, LQ128, DIQ128) ( sqr( (P)*(DIQ128)/Q128 - (LQ128)*((P) - P_Lean_post((P),(LQ128),(DIQ128)))/Q128 ) )

* ── Plank-coordinate evaluators ──
$macro sqrtPX96_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)/2) * Q96 )
$macro priceImpactQ128_Add0(sqrtP, LQ128, dxQ128) ( priceImpactKernel_Add0((sqrtP), (LQ128)/Q128, (dxQ128)/Q128) )
$macro traderTerm_Half_Plank(sqrtP, DIQ128)            ( (sqrtP)*(DIQ128)/Q128/Q96 )
$macro traderDeltaO_Half_Plank(sqrtP, sqrtQ, LQ128)    ( (LQ128)*((sqrtP) - (sqrtQ))/Q128/Q96 )
$macro piTrader_Half_Plank(sqrtP, LQ128, DIQ128) ( sqr( traderTerm_Half_Plank((sqrtP),(DIQ128)) - traderDeltaO_Half_Plank((sqrtP), priceImpactQ128_Add0((sqrtP),(LQ128),(DIQ128)), (LQ128)) ) )

* ── Shared provenance + tolerance scalars ──
Scalar etaQ128 ;     etaQ128 = power(2, 127);            * = η = 1/2 in Q0.128
Scalar gamsVersion / 54.1 /;
Scalar modelVersion / 3 /;                                * cycle 1, spec rev 3
Scalar lambdaWad ;   lambdaWad = lambda;                  * = 1.0001·1e18 WAD
Scalar diffTolerance / 1e-12 /;                            * RELATIVE tol for non-zero references
Scalar zeroTolerance / 1e-20 /;                            * ABSOLUTE tol for zero references
Scalar tieBreaking   / 1 /;                                * 1=smallest, 2=largest, 3=midpoint
```

**Numerical-precision note:** `LbarQ128 = 2^128 ≈ 3.4e38` exceeds IEEE-double exact-integer range (`2^53 ≈ 9e15`). Boundary cancellation `LbarQ128/Q128 = 1.0` is exact under double arithmetic; ratios like `LbarQ128/(LbarQ128−DICfgQ128)` remain numerically clean. Empirically the IEEE round-off floor on the helper-lemma cross-check is ~1e-15, comfortably below `1e-12` relative tol.

## 6. First program — `model/payoff/eta_pi_trader_zero_slippage.gms`

```gams
$title Zero-slippage Δᵢ⋆ — Lean `pi_trader_half_zero_at_deltaI_star` + Plank cesLongPayoff zero
$include _PayoffScaffolding.gms

* ── Canonical single config (Q128.128 amounts) ──
Scalar iCfg        / 60 /;
Scalar LbarQ128 ;  LbarQ128  = Q128;                       * L̄ = 1 in Q128.128
Scalar DICfgQ128 ; DICfgQ128 = Q128 / 10;                  * Δ^I = 0.1 in Q128.128

* ── Lean-coordinate closed forms (verbatim from eta.lean:491–512) ──
Scalar diStarLeanReal ;
diStarLeanReal       = log(LbarQ128 / (LbarQ128 - DICfgQ128)) / (log(lambdaWad/unity) * iCfg);
Scalar PHalfAtStarLeanReal ;
PHalfAtStarLeanReal  = LbarQ128 / (LbarQ128 - DICfgQ128);

* ── Plank-coordinate closed forms (via bridge — see §3 D4i derivation) ──
Scalar diStarPlankReal ;  diStarPlankReal = 2 * diStarLeanReal;
* At Δᵢ⋆_Plank, the macro's /2 cancels the doubling of Δᵢ, so sqrtPX96 evaluates
* to (L̄/(L̄−Δ^I))·Q96 — NOT its sqrt. (Rev-2 bug fixed here.)
Scalar sqrtPAtStarPlankExpectedQ96 ;
sqrtPAtStarPlankExpectedQ96 = PHalfAtStarLeanReal * Q96;

* ── Bounds-binding guard (BOTH coordinates) ──
abort$(diStarLeanReal  < diMinInt or diStarLeanReal  > diMaxInt)
    "Out of zero-slippage regime: Δᵢ⋆_Lean outside [1, 200]", diStarLeanReal;
abort$(diStarPlankReal < diMinInt or diStarPlankReal > diMaxInt)
    "Out of zero-slippage regime: Δᵢ⋆_Plank outside [1, 200]", diStarPlankReal;

* ── (X) Cross-coordinate consistency (sanity: bridge identity) ──
abort$(abs(diStarPlankReal - 2*diStarLeanReal)/diStarLeanReal > diffTolerance)
    "FAIL: bridge identity Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean violated", diStarLeanReal, diStarPlankReal;

* ── (A_Lean) Lean payoff at Δᵢ⋆_Lean → 0 — corroborates Lean theorem ──
Scalar PLeanAtStar ;      PLeanAtStar      = P_Lean_at(lambdaWad, iCfg, diStarLeanReal);
Scalar piAtStarLeanReal ; piAtStarLeanReal = piTrader_Half_Lean(PLeanAtStar, LbarQ128, DICfgQ128);
abort$(abs(piAtStarLeanReal) > zeroTolerance)
    "FAIL: Lean π at Δᵢ⋆_Lean must be ≈ 0 absolute", piAtStarLeanReal;

* ── (A_Plank) Plank payoff at Δᵢ⋆_Plank → 0 — corroborates Plank evaluator ──
Scalar sqrtPAtStarPlankQ96 ;  sqrtPAtStarPlankQ96 = sqrtPX96_at(lambdaWad, iCfg, diStarPlankReal);
Scalar piAtStarPlankReal ;    piAtStarPlankReal   = piTrader_Half_Plank(sqrtPAtStarPlankQ96, LbarQ128, DICfgQ128);
abort$(abs(piAtStarPlankReal) > zeroTolerance)
    "FAIL: Plank π at Δᵢ⋆_Plank must be ≈ 0 absolute", piAtStarPlankReal;

* ── (B_Plank fixed) sqrtPX96 at Δᵢ⋆_Plank equals (L̄/(L̄−Δ^I))·Q96 (NO sqrt) ──
abort$(abs(sqrtPAtStarPlankQ96 - sqrtPAtStarPlankExpectedQ96)/sqrtPAtStarPlankExpectedQ96 > diffTolerance)
    "FAIL: Plank sqrtPX96(Δᵢ⋆_Plank) must equal (L̄/(L̄−Δ^I))·Q96", sqrtPAtStarPlankQ96, sqrtPAtStarPlankExpectedQ96;

* ── (B_indep) INDEPENDENT kernel-definition test via probe pair ──
* Replaces rev-2's tautological (B_Lean)/(B_Plank). Tests log(P(b)/P(a)) =
* (b-a)·i·log(λ_real) — the integrated form of d log P / d Δᵢ. Independent
* of the closed-form Δᵢ⋆ because it uses non-optimum probe points.
Scalar diProbeA / 5 /;
Scalar diProbeB / 20 /;
Scalar PProbeA ; PProbeA = P_Lean_at(lambdaWad, iCfg, diProbeA);
Scalar PProbeB ; PProbeB = P_Lean_at(lambdaWad, iCfg, diProbeB);
Scalar logRatioExpected ; logRatioExpected = (diProbeB - diProbeA) * iCfg * log(lambdaWad/unity);
abort$(abs(log(PProbeB/PProbeA) - logRatioExpected)/abs(logRatioExpected) > diffTolerance)
    "FAIL: P_Lean kernel-definition check (log-ratio) — independent of Δᵢ⋆",
    PProbeA, PProbeB, logRatioExpected;
Scalar sqrtPProbeA ; sqrtPProbeA = sqrtPX96_at(lambdaWad, iCfg, diProbeA);
Scalar sqrtPProbeB ; sqrtPProbeB = sqrtPX96_at(lambdaWad, iCfg, diProbeB);
Scalar logRatioSqrtExpected ; logRatioSqrtExpected = (diProbeB - diProbeA) * iCfg * log(lambdaWad/unity) / 2;
abort$(abs(log(sqrtPProbeB/sqrtPProbeA) - logRatioSqrtExpected)/abs(logRatioSqrtExpected) > diffTolerance)
    "FAIL: sqrtPX96 kernel-definition check (log-ratio)", sqrtPProbeA, sqrtPProbeB, logRatioSqrtExpected;

* ── (C_Plank) NLP — modelStat only, NO precision claim ──
* Rev-3 D9: the Q96-scaled squared-loss objective is so flat near the optimum
* that CONOPT terminates ~1e-2 away from the analytic argmin regardless of
* tolerance tightening. (D_Plank) and (F) are the precision checks; this is
* the "did the solver-stack wire up" check only.
Positive Variable di ;
di.lo = diMinInt; di.up = diMaxInt; di.l = diStarPlankReal / 2;
Variable piVal ;
Equation payoffEq ;
payoffEq.. piVal =e= piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, di), LbarQ128, DICfgQ128);
Model ZeroSlip / payoffEq /;
option nlp = conopt;
Solve ZeroSlip using nlp minimizing piVal;
abort$(ZeroSlip.modelStat <> %modelStat.locallyOptimal% and ZeroSlip.modelStat <> %modelStat.optimal%)
    "FAIL: ZeroSlip NLP did not reach optimum", ZeroSlip.modelStat, ZeroSlip.solveStat;

* ── (D_Plank) Integer enumeration over Δᵢ ∈ {1..200} — derives operational control target ──
Set       diGrid /1*200/ ;
Parameter diVal(diGrid) ;  diVal(diGrid) = ord(diGrid);
Parameter piGrid(diGrid) ;
piGrid(diGrid) = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diVal(diGrid)), LbarQ128, DICfgQ128);
Scalar piMinInt ;  piMinInt = smin(diGrid, piGrid(diGrid));
* Tie-breaking convention: tieBreaking=1 ⇒ smallest argmin under ties.
Scalar diStarInt ;  diStarInt = smin(diGrid$(piGrid(diGrid) = piMinInt), diVal(diGrid));
Scalar diStarPlankIntExpected ;  diStarPlankIntExpected = round(diStarPlankReal);
abort$(abs(diStarInt - diStarPlankIntExpected) > 0)
    "FAIL: discrete enumeration argmin must equal round(Δᵢ⋆_Plank)",
    diStarInt, diStarPlankIntExpected;

* ── (E) V-shape (small-trade regime — slippage_residual sign-change, NOT strict monotonicity) ──
* eta.lean:359–365 notes π first DECREASES then INCREASES in the small-trade regime
* (Δ^I < L̄); the strict-monotonicity theorem at :366 requires Δ^I ≥ L̄ (large-trade).
* Canonical config is small-trade, so we test the V-shape at Δᵢ⋆_Plank.
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

* ── (F) Independent argmin via 3-point parabolic interpolation ──
* Uses only piGrid evaluations (no closed-form substitution); estimates the
* continuous argmin from a parabola through (k-1, k, k+1). Tests that the
* macro algebra produces a function whose continuous minimum matches Lean's.
Scalar piHere, piPrev, piNext, diArgminContinuous;
piHere = piMinInt;
piPrev = sum(diGrid$(diVal(diGrid) = diStarInt - 1), piGrid(diGrid));
piNext = sum(diGrid$(diVal(diGrid) = diStarInt + 1), piGrid(diGrid));
diArgminContinuous = diStarInt + 0.5*(piPrev - piNext) / (piPrev - 2*piHere + piNext);
abort$(abs(diArgminContinuous - diStarPlankReal)/diStarPlankReal > 1e-3)
    "FAIL: parabolic-interp argmin disagrees with Lean closed form",
    diArgminContinuous, diStarPlankReal;

* ── Control-target GDX export (consistent column semantics across rows) ──
* Each row evaluates each target at THAT row's diStarInt — schema is self-consistent.
Set inputD    / lambdaWad, iTick, LbarQ128, DeltaIQ128, etaQ128, diMinInt, diMaxInt /;
Set targetD   / diStarInt, piAtDiStarObserved, P_Lean_at_DiStar, sqrtPX96_at_DiStar /;
Set sourceD   / lean, plank, solver, enumeration /;

Parameter inputs(inputD);
inputs('lambdaWad')   = lambdaWad;
inputs('iTick')       = iCfg;
inputs('LbarQ128')    = LbarQ128;
inputs('DeltaIQ128')  = DICfgQ128;
inputs('etaQ128')     = etaQ128;
inputs('diMinInt')    = diMinInt;
inputs('diMaxInt')    = diMaxInt;

* Each row stores: its diStarInt + Plank π at that int (the controller's actual cost)
* + P_Lean & sqrtPX96 at that int (the two prices for audit).
Scalar diLeanRound ;   diLeanRound   = round(diStarLeanReal);
Scalar diPlankRound ;  diPlankRound  = diStarPlankIntExpected;
Scalar diSolverRound ; diSolverRound = round(di.l);

Parameter optimum(sourceD, targetD);
optimum('lean',        'diStarInt')           = diLeanRound;
optimum('lean',        'piAtDiStarObserved')  = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diLeanRound), LbarQ128, DICfgQ128);
optimum('lean',        'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diLeanRound);
optimum('lean',        'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diLeanRound);

optimum('plank',       'diStarInt')           = diPlankRound;
optimum('plank',       'piAtDiStarObserved')  = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diPlankRound), LbarQ128, DICfgQ128);
optimum('plank',       'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diPlankRound);
optimum('plank',       'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diPlankRound);

optimum('solver',      'diStarInt')           = diSolverRound;
optimum('solver',      'piAtDiStarObserved')  = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diSolverRound), LbarQ128, DICfgQ128);
optimum('solver',      'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diSolverRound);
optimum('solver',      'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diSolverRound);

optimum('enumeration', 'diStarInt')           = diStarInt;
optimum('enumeration', 'piAtDiStarObserved')  = piMinInt;
optimum('enumeration', 'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diStarInt);
optimum('enumeration', 'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diStarInt);

* ── Lean-theorem provenance (string-valued via 1-element Sets) ──
Set theoremNameSet      / 'pi_trader_half_zero_at_deltaI_star' /;
Set leanFileSet         / 'lean4-spec/lean/exp/eta.lean' /;
Set leanLineSet         / 'eta.lean:518' /;
Set aristotleProjectSet / '88d393e7-ec4e-438f-a5fd-9f34aab1c2e5' /;
Scalar theoremStatus / 1 /;                                * 1=proven, 0=sorry, -1=conjectured

* ── Continuous-argmin auxiliary scalars (also exported for audit) ──
Scalar diArgminContinuousExport ;  diArgminContinuousExport = diArgminContinuous;
Scalar diSolverContinuousExport ;  diSolverContinuousExport = di.l;

execute_unload 'payoff_zero_slippage.gdx',
    inputs, optimum,
    gamsVersion, modelVersion, lambdaWad, etaQ128,
    diffTolerance, zeroTolerance, tieBreaking,
    theoremStatus, theoremNameSet, leanFileSet, leanLineSet, aristotleProjectSet,
    diArgminContinuousExport, diSolverContinuousExport;

display "PASS: zero-slippage — Lean+Plank coordinates corroborated; control target =", diStarInt;
display "  Lean coord:  ", diStarLeanReal, PLeanAtStar, piAtStarLeanReal;
display "  Plank coord: ", diStarPlankReal, sqrtPAtStarPlankQ96, piAtStarPlankReal;
display "  Enum:        ", diStarInt, piMinInt;
display "  NLP:         ", di.l, piVal.l;
display "  Parabolic:   ", diArgminContinuous;
```

## 7. Orchestrator — `model/PayoffModule.gms`

```gams
$title PayoffModule orchestrator — $include the per-theorem subset the driver wants.
* Per-theorem files $include _PayoffScaffolding.gms themselves (include-guarded).
$include payoff/eta_pi_trader_zero_slippage.gms
* Future cycles append:
* $include payoff/eta_pi_trader_band_min.gms
* $include payoff/eta_pi_trader_band_max.gms
* $include payoff/eta_sigma_xs_target_inversion.gms
* $include payoff/eta_split_kernel_identity.gms
```

## 8. Test rollup — `model/test/PayoffModuleTest.gms`

```gams
$title PayoffModule rolled-up assertion test
* action=ce drives per-program asserts inside every $include'd payoff file.
* This test invokes a real NLP Solve (CONOPT) — make test-gams now depends on CONOPT.
$include PayoffModule.gms
display "PASS: all PayoffModule per-program asserts cleared.";
```

## 9. GDX schema

| GDX symbol | Indexing | Value | Scale | Semantics |
|---|---|---|---|---|
| `inputs(inputD)` | 7 keys | scalar | mixed (named) | Canonical config + operational bounds. |
| `optimum(sourceD, targetD)` | 4 × 4 = 16 cells | scalar | mixed | `sourceD ∈ {lean, plank, solver, enumeration}` × `targetD ∈ {diStarInt, piAtDiStarObserved, P_Lean_at_DiStar, sqrtPX96_at_DiStar}`. **Each row evaluates all 4 targets at THAT row's `diStarInt`** — consistent column semantics. **Controller reads `optimum('enumeration','diStarInt')` as the canonical control target; `optimum('enumeration','piAtDiStarObserved')` is the floor π the controller will incur at integer Δᵢ.** |
| `gamsVersion` / `modelVersion` | scalars | `54.1` / `3` | dimensionless | toolchain + spec rev provenance |
| `lambdaWad` / `etaQ128` | scalars | WAD / Q0.128 | as named | numeric provenance |
| `diffTolerance` / `zeroTolerance` / `tieBreaking` | scalars | `1e-12` / `1e-20` / `1` | dimensionless | tolerances + tie-break convention |
| `theoremStatus` | scalar | `1` (proven) | dimensionless | Lean theorem status |
| `theoremNameSet` / `leanFileSet` / `leanLineSet` / `aristotleProjectSet` | 1-elem sets | string UEL | dimensionless | Lean provenance (auditable from GDX alone) |
| `diArgminContinuousExport` / `diSolverContinuousExport` | scalars | real | dimensionless | the continuous argmin estimates (parabolic + NLP); for audit of how close the integer was to the real optimum |

## 10. Success criteria

- `model/PayoffModule.gms` orchestrates 1 per-theorem file.
- `make compile-gams` → **10 ok / 0 failed**.
- `make test-gams` → **3 passed / 0 failed**. Per-program asserts: (X) bridge, (A_Lean), (A_Plank), (B_Plank), (B_indep)·2, (C_Plank) modelStat, (D_Plank), (E) left + right, (F) parabolic.
- `make payoff-fixtures` produces `model/payoff_zero_slippage.gdx`.
- `gdxdump model/payoff_zero_slippage.gdx Symbols` lists 16 explicit symbols (above) plus auto-promoted domain sets.
- `optimum('enumeration', 'diStarInt')` = **`round(2·log(10/9)/(log(1.0001)·60))` = `round(35.117)` = `35`** (the Plank-coord control target).
- `optimum('lean', 'diStarInt') = round(17.559) = 18` (Lean-coord, exported for audit).
- `diArgminContinuousExport` ≈ `35.118` (parabolic interp), matches `diStarPlankReal ≈ 35.117` to ~1e-4.
- `.gitignore` extends the existing `!model/price_impact_kernel.gdx` re-include with `!model/payoff_zero_slippage.gdx`. **`git add -f` forbidden.**
- Expected GDX size ≤ 8 KB.
- **Rev-3 spec was empirically verified end-to-end in `/tmp/rev3_test/` before commit (all asserts pass, exit 0).**

## 11. Out of scope (explicit YAGNI)

- **EVM controller.** Future spec.
- **Differential test against `CESLongPayoff.plk`** (evaluator diff). Separate cycle.
- **Bounds-binding configs** — BAND MIN/MAX's job.
- **Multi-config grids.** Q3-locked single-config; MQA pushback (M5) noted, deferred.
- **MIP/MINLP.** Larger domains re-open this.
- **η-tunable variants.**
- **Lean-side rebroadcast** of `P_half := λ^(i·Δᵢ/2)` — would eliminate the coordinate split. Not this spec's call.

## 12. Workflow

- **Branch:** `feat/gams-payoff` off `origin/develop` @ `81fb24d` (created).
- **Lean PR #2:** MERGED at the pinned commit.
- **New Makefile target `payoff-fixtures`** (per-theorem GDX regenerator). The `\t` lines below must be literal TABs when transcribed (Markdown's 2-space block-indent is illustrative only):

  ```makefile
  # payoff-fixtures: regenerate committed per-theorem payoff GDX(s).
  .PHONY: payoff-fixtures
  payoff-fixtures:
  	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
  	@cd $(GAMS_DIR) && rc=0; \
  	for f in $$(find payoff -name 'eta_*.gms' | sort); do \
  		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
  		printf '>> regenerating fixture from %s\n' "$$f"; \
  		if $(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 2>&1 | tee -a "$$out.err" >/dev/null; then \
  			printf '   OK %s\n' "$$f"; \
  		else \
  			printf '   FAIL %s -> %s/%s\n' "$$f" "$(GAMS_DIR)" "$$out"; rc=1; \
  		fi; \
  	done; \
  	exit $$rc
  ```
- **Per-cycle cadence:** brainstorm → spec (+ two-step review) → plan → SDD execution → review → PR.
- **Recommended sequence:** zero-slippage → band-min → band-max → variance-target → kernel-split.
- **Solver availability:** CONOPT ships under GAMS demo license (RC-verified).

## 13. References

- **Lean PR #2 (MERGED at `81fb24d`):** brought `lean/exp/eta.lean` + 8 per-theorem markdown specs.
- **Lean theorem:** `eta.lean:518` (`pi_trader_half_zero_at_deltaI_star`), `:491–498` (`deltaI_star`), `:501–512` (`P_half_at_deltaI_star`), `:38–39` (`P_half := λ^(i·Δᵢ)` — un-squared).
- **Lean per-theorem markdown:** `lean/exp/eta_pi_trader_zero_slippage.md`.
- **Plank evaluator:** `cfmm-wt/plank/src/exp/CESLongPayoff.plk`. `P_{1/2}(i) ≡ sqrtPX96` (Plank's docstring).
- **Uniswap V3 reference:** `lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk`; TickMath Q128.128 constants.
- **Prior cycle's spec** (Q-scale conventions inherited): `docs/superpowers/specs/2026-06-28-price-impact-kernel-gams-design.md`.
- **GAMS-track scope memory:** `gams-agent-scope.md`.
- **Rev-2 two-step review record:** Reality Checker + Model QA Specialist found (a) sqrt-vs-no-sqrt confusion in (B_Plank) expected value, (b) NLP tolerance unsatisfiable, (c) (B_Lean)/(B_Plank) tautologies. All three resolved in rev 3 by, respectively, (a) dropping the sqrt in `sqrtPAtStarPlankExpectedQ96`, (b) dropping the precision claim in (C_Plank), (c) replacing with the independent probe-pair test (B_indep) + adding (F) parabolic interp.
- **Rev-3 empirical pre-flight:** `/tmp/rev3_test/` — full spec algebra ran end-to-end before commit; all asserts pass at canonical config.
