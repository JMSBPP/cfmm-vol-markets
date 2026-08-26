# CONTROLLERS — candidate static controllers for the on-chain CFMM

> READ-ONLY synthesis (2026-06-28). Catalogs controllers **already implied by the
> repo's proven Lean inversions, its GAMS payoff program, and its binomial
> period model** — it does NOT design new theory. Every entry cites the exact
> GAMS program / Lean theorem it comes from.

## Framing (the non-negotiables)

- **Static, not temporal.** Each controller is a *target → actuator* map evaluated
  once; there is no time index, no feedback loop, no adaptive fee `φ(·;t)`. (The
  dynamic layer is explicitly deferred — `MAPPING-SYNTHESIS.md` scope correction.)
- **The state space is the tick lattice.** Integer ticks `i ∈ [−120, 120]` (241
  nodes, `tickVal = ord − 121`), spacing `Δi ∈ {1..60}` (fixtures use `Δi = 1`).
  The lattice is **CRR-style binomial**: from node `i` an *up* move multiplies the
  ½-pricing kernel by `λ^{Δi}` (down by `λ^{−Δi}`), since
  `P_½(i) = λ^{i·Δi}` (`eta.lean:38`, `P_half`). The up/down ±1 increment is drawn
  by `BinomialProxy.plk` (`P(±1)=½`); the per-node trade *amount* by
  `SwapAmtGen.plk`.
- **Actuators** the controllers may set: `Δi` (tick spacing — the primary knob),
  `η` (elasticity, **pinned ½** this milestone), `ξ`/`ι` (liquidity-kernel
  decay/support), `baseTick`. Proven inversions move `Δi`; `η` enters only via the
  split-kernel generalization path.
- **η = ½** throughout (the only weight with an on-chain counterpart;
  `BALANCED_ETA = 0.5`, `etaQ128 = 2^127`). `eta_split_kernel_identity` is the
  documented path to general η.
- **EVM fixed-point reality.** Plank's only numeric type is `u256`; signed values
  are two's-complement. Primitives available: `mulDiv` (512-bit), `getSqrtRatioAtTick`
  / `getTickAtSqrtRatio` (the on-chain `λ^x` / `log_λ`), `sqrt_price_math`,
  `@evm_sdiv`/`@evm_sar`. **Missing (must hand-write):** signed fixed-point mul/div,
  saturating clamp, WAD `exp`/`ln`/general `pow`. **Hard rule:** a hook that reverts
  DoSes the swap — every controller must **saturate, never revert**.

---

## C1 — Zero-Slippage Spacing Controller

- **Intent.** Pick the tick spacing at which the trade is fair (zero squared
  slippage / at-the-money on the variance leg).
- **Control target.** Trader payoff `π_½ = (P_½(i)·Δᴵ − Δᴼ)² → 0` (equivalently the
  price ratio reaches `L̄/(L̄−Δᴵ)`).
- **Actuator.** `Δi` (tick spacing).
- **Closed form.**
  `Δi⋆ = log(L̄/(L̄−Δᴵ)) / (log λ · i)`, with `P_½(Δi⋆) = L̄/(L̄−Δᴵ)` (the
  **log-free rational target**). — Lean `pi_trader_half_zero_at_deltaI_star`
  + helper `P_half_at_deltaI_star` (`eta.lean:501,518`); GAMS
  `eta_pi_trader_zero_slippage.gms` (checks A_Lean/A_Plank/B_Plank). Plank-coordinate
  bridge: `Δi⋆_Plank = 2·Δi⋆_Lean`.
- **Regime / feasibility.** Small-trade `0 < Δᴵ < L̄`; `λ>1, i>0, L̄>0`. Must land
  in the admissible band `Δi ∈ [1,200]` (GAMS aborts otherwise).
- **EVM cost & primitives.** `log` is NOT EVM-native ⇒ **target the rational price
  ratio** `L̄/(L̄−Δᴵ)` (one `mulDiv`) and invert price→tick with the existing
  `getTickAtSqrtRatio` (binary search), OR ship `Δi⋆` precomputed off-chain. No
  η-split needed (η=½).
- **Type.** Pure set-point map; static.
- **Status.** **PROVEN** (Lean + GAMS 4-way corroborated). EVM-ready via the ratio form.

## C2 — Cross-Section Variance-Target Controller (σ_xs)

- **Intent.** Pick the spacing that makes the cross-section vol equal a target.
- **Control target.** `σ_xs,poly(n,d,Δi) = σ_target`.
- **Actuator.** `Δi`.
- **Closed form.**
  `Δi⋆(n,d,σ_target) = (d·n(n−1) + √disc) / (n(n−1)(2n−1)/3)`,
  `disc = c₁² − 4c₂(d²−σ_target)`, `c₂ = n(n−1)(2n−1)/6`, `c₁ = −d·n(n−1)`,
  `d := i₋ − i_μ`. — Lean `sigma_xs_poly_target_exists` (`eta.lean:560`); GAMS
  σ identity in `eta_sigma_xs_realized_connection.md`.
- **Regime / feasibility.** `n ≥ 2` (positive leading coeff) and **strict**
  `σ_target > d²` (Aristotle-narrowed; non-strict lets the root collapse to 0).
  Uses `sigma_xs_poly` with `#` = `n` FREE — valid only on a Δi-interval where the
  tick count `#` is constant (lift to full `sigma_xs` is a GAP, see G3).
- **EVM cost & primitives.** One fixed-point `sqrt` (`disc`) + a few `mulDiv`; the
  `n`-dependent coefficients are integer constants computable on-chain or shipped.
- **Type.** Pure set-point map (quadratic inversion); static.
- **Status.** **PROVEN** for `_poly`; EVM-ready (needs a fixed-point `sqrt`, which
  `tick_math` MSB machinery supports). Full-`σ_xs` lift is open.

## C3 — Trader-Payoff Band-Min Controller (large trade)

- **Intent.** Minimize trader payoff within an admissible spacing band.
- **Control target.** minimize `π_½` over `[Δi_min, Δi_max]`.
- **Actuator.** `Δi = Δi_min` (left endpoint).
- **Closed form / rule.** `π_½(Δi_min) ≤ π_½(Δi)` ∀ admissible `Δi`. — Lean
  `pi_trader_half_band_min_at_left` (`eta.lean:477`), inline corollary of
  `pi_trader_half_strictly_increasing_in_Δi`.
- **Regime / feasibility.** Large-trade `L̄ ≤ Δᴵ`; `λ>1, i>0, L̄>0, 0<Δi_min`.
- **EVM cost & primitives.** Trivial — pick/clamp to the band floor. No payoff eval.
- **Type.** Pure set-point (endpoint selection); static.
- **Status.** **PROVEN**, cheapest possible. EVM-ready.

## C4 — Trader-Payoff Band-Max Controller (variance-swap maximizer)

- **Intent.** Maximize the trader's long-variance payoff within the band.
- **Control target.** maximize `π_½` over `[Δi_min, Δi_max]`.
- **Actuator.** `Δi`.
- **Closed form / rule.**
  - Large-trade `L̄ ≤ Δᴵ`: `Δi = Δi_max` (right endpoint). — `pi_trader_half_band_max_large_trade`.
  - Small-trade with golden bound `Δᴵ² + Δᴵ·L̄ ≤ L̄²` (i.e. `Δᴵ/L̄ ≤ (√5−1)/2 ≈ 0.618`):
    `Δi = argmax(π(Δi_min), π(Δi_max))` (endpoint). — `pi_trader_half_band_max_small_trade`
    (`eta.lean:609,701`) + `residual_antitone`.
- **Regime / feasibility.** **Fails as endpoint rule** in the sliver
  `(√5−1)/2·L̄ < Δᴵ < L̄`: an interior hump on the left branch can beat both
  endpoints (machine-checked counterexample `L̄=1, Δᴵ=0.9`). There the max-π policy
  needs an interior search or a band that excludes the hump (GAP, see G4).
- **EVM cost & primitives.** Two payoff evals via `CESLongPayoff.plk`
  (`getNextSqrtPriceFromAmount0RoundingUp` + `getAmount1DeltaUnsigned` + `mulDiv`)
  + compare/select. Saturating compare, no division by controller value.
- **Type.** Set-point (endpoint compare); static.
- **Status.** **PROVEN** for large-trade and sub-golden small-trade; **GAP** in the
  0.382-wide upper small-trade sliver.

## C5 — Small-Signal Gain (linearized) Controller

- **Intent.** Local control gain for `π` near zero trade size (linearized loop seed).
- **Control target.** local sensitivity `π_½/Δᴵ²` as `Δᴵ → 0⁺`.
- **Actuator.** `Δi` (through `P`).
- **Closed form.** `lim_{Δᴵ→0⁺} π_½/Δᴵ² = P²(P−1)²`, `P = λ^{i·Δi}`. — Lean
  `pi_trader_half_small_trade_quadratic` (`eta.lean:428`; holds for any `λ>0`).
- **Regime / feasibility.** Small-signal (perturbative `Δᴵ`). `P` from the lattice
  node; gain is exact in the limit, an approximation at finite `Δᴵ`.
- **EVM cost & primitives.** `P = getSqrtRatioAtTick(i·Δi)` then two squarings /
  `mulDiv` — very cheap. Watch `*%` overflow above ~2^192 (see `CESLongPayoff.plk:42`).
- **Type.** Linearization / local-gain map; static.
- **Status.** **PROVEN**. EVM-ready.

## C6 — 3-Point Parabolic Argmin Update (lattice search)

- **Intent.** Find the payoff-extremizing spacing without a solver.
- **Control target.** `argmin_Δi π_½` (reproduces the GAMS CONOPT NLP argmin and the
  integer enumeration argmin).
- **Actuator.** `Δi`.
- **Lattice recursion.** `Δ⋆ ≈ Δ₀ + ½(π₋ − π₊) / (π₋ − 2π₀ + π₊)`, evaluated on
  three adjacent lattice nodes `{Δ₀−1, Δ₀, Δ₀+1}`. — GAMS
  `eta_pi_trader_zero_slippage.gms` check (F) (validated to 1e-3 against the Lean
  closed form C1); cross-checked by enumeration check (D).
- **Regime / feasibility.** Needs an interior triplet (GAMS guard (G): not at band
  boundary) and a locally convex (V-shaped) arm — guaranteed small-trade by C1.
- **EVM cost & primitives.** 3 payoff evals (`CESLongPayoff`) + one signed `mulDiv`
  division. Guard `denom = (π₋ − 2π₀ + π₊) ≠ 0` before dividing (else revert).
- **Type.** Recursion over the lattice (1-D search); static (one step here, since
  C1 gives the closed form — this is the solver-free fallback).
- **Status.** **PROVEN-equivalent** to the NLP argmin (GAMS-validated). EVM-portable.

## C7 — η-Split Kernel Realization Controller

- **Intent.** Realize a *generic-η* price on an EVM that only has the ½ sqrt-price
  algebra — the generalization path off the η=½ pin.
- **Control target.** `P_η(i)` (a target price under elasticity `η`).
- **Actuator.** the tick split `(i₋, i₊)`, `i₋ = ⌊η·i⌋`, `i₊ = i − i₋`
  (a `baseTick`-style decomposition of the node).
- **Closed form.** `P_η(i) = P_½(i₋)·P_½(i₊) = P_½(i)`. — Lean
  `eta_split_kernel_identity` (`eta.lean:67`); `model/exp/eta.md`. Validity holds
  for any `η ∈ (0,1)` **provided `i₋, i₊` stay in Int24**.
- **Regime / feasibility.** `IsInt24 i₋`, `IsInt24 i₊` (explicit hyps). Note: this
  closes the *price kernel* under η, NOT the impact/CES payoff for general η (that
  remains a GAP, G2).
- **EVM cost & primitives.** Two `getSqrtRatioAtTick` + one `mulDiv` (with the
  `⌊η·i⌋` floor via `@evm_sdiv`). Cheap.
- **Type.** Pure set-point / composition map; static.
- **Status.** **PROVEN** (the kernel identity). It is the *enabler* for general-η,
  but the η-impact/payoff surrogate it would feed does not yet exist.

## C8 — (η, Δi) Dual-Knob Identifiability Constraint

- **Intent.** Not a tracker — a feasibility/observability guard telling the
  designer when one knob suffices and when two are required.
- **Control target.** the joint observable `(σ, L_η)`.
- **Actuator(s).** `η` AND `Δi` (they are NOT interchangeable in the joint target).
- **Closed form.** `σ(η,Δi) = σ(cη, Δi/c)` ∀c>0 (σ sees only the product `η·Δi`),
  but `L_η ≠ L_{cη}` for `X≠Y, c≠1`. — Lean
  `sigmaVTS_invariant_under_eta_Δi_rescaling ∧ eta_Δi_independent_in_sigma_and_L_eta`
  (`eta.lean:120,138`).
- **Regime / feasibility.** Tick spacing alone CANNOT replicate all of elasticity;
  to hit both `σ` and `L_η` you must move both knobs. Critical for any future state
  estimation.
- **EVM cost & primitives.** N/A (design constraint; no on-chain compute).
- **Type.** Identifiability constraint (meta-controller); static.
- **Status.** **PROVEN**. Bounds what C1–C7 can achieve with `Δi` alone.

## C9 — Realized-Variance Lattice Aggregator

- **Intent.** Compute realized variance across the occupied lattice nodes (the
  observable that σ-target control C2 drives).
- **Control target.** `σ_realized = (1/#) Σ_{k<#} (i₋ + kΔi − i_μ)²` and its exact
  link to `σ_xs`.
- **Actuator.** read-only over `Δi`, `#`.
- **Closed form (collapses the lattice rollback).**
  `σ_xs = #·σ_realized − (#−1)d² − 2dΔi·#(#−1)` with `Σ_{k<n}(d+kΔi)² =
  nd² + dΔi·n(n−1) + Δi²·n(n−1)(2n−1)/6`. — Lean
  `sigma_xs_eq_sharp_mul_sigma_realized` + `sum_sq_arith` (`eta.lean:286,241`).
- **Regime / feasibility.** Only `# ≥ 1` needed (ordering hyps decorative). Naive
  `σ_xs = #·σ_realized` is FALSE unless `i₋ = i_μ`.
- **EVM cost & primitives.** Closed form ⇒ no per-node loop; a handful of `mulDiv`
  on integer tick counts.
- **Type.** Lattice recursion **collapsed to closed form** (no binomial rollback
  needed); static.
- **Status.** **PROVEN**. EVM-ready.

## C10 — Binomial Swap-Flow Reference Generator (the plant input)

- **Intent.** Produce the exogenous up/down move + trade amount that drives the
  lattice — the *reference process*, not a feedback controller.
- **Control target.** simulated order flow `ΔY(t) = Σ Iₙ·Δyₙ` (direction `I∈{±1}`,
  amount `Δy`).
- **Actuator.** none (exogenous driver).
- **Form.** direction `gen_rand(seed) = parity(prevrandao) ∈ {0,1}` —
  `BinomialProxy.plk` (the `P(±1)=½` increment). Amount (deterministic proxy)
  `Δy(t) = 19e18 + 2·KERNEL^(timeIndex⁴·decay)`, bounded `[19e18,21e18]` —
  `SwapAmtGen.plk` (sel `0xbc4af3dc`). Intended stochastic spec (Poisson `Nₜ`,
  LogNormal `Δyₙ`, σ=1.2) is in `plank/NOTES.md` only.
- **Regime / feasibility.** Miner-influenceable (prevrandao) ⇒ keep out of any
  control gain; use only as simulated flow.
- **EVM cost & primitives.** `@evm_difficulty`, `@evm_exp`/`@evm_mul`. Compiles.
- **Type.** Stochastic/deterministic reference generator over the binomial lattice;
  static per call.
- **Status.** **STUB** — compiles, but **no GAMS ground truth** validates it. This
  is the stochastic swap-flow gap (G1).

---

## (a) Readiness × EVM-cheapness ranking

| Rank | Controller | Status | EVM cost | Type | Actuator |
|---|---|---|---|---|---|
| 1 | **C3** Band-Min (large trade) | Proven | trivial (clamp) | endpoint set-point | Δi |
| 2 | **C5** Small-Signal Gain | Proven | ~3 mulDiv | linearization | Δi via P |
| 3 | **C9** Realized-Var Aggregator | Proven | few mulDiv (closed form) | collapsed recursion | read-only |
| 4 | **C7** η-Split Realization | Proven | 2 tickRatio + mulDiv | composition set-point | (i₋,i₊) |
| 5 | **C1** Zero-Slippage Spacing | Proven | mulDiv + getTickAtSqrtRatio | set-point (ratio form) | Δi |
| 6 | **C4** Band-Max | Proven* | 2 payoff evals + compare | endpoint set-point | Δi |
| 7 | **C2** σ_xs Variance-Target | Proven (_poly) | 1 sqrt + mulDiv | quadratic inversion | Δi |
| 8 | **C6** Parabolic Argmin | Proven-equiv | 3 payoff evals + signed div | lattice search | Δi |
| 9 | **C8** (η,Δi) Identifiability | Proven | N/A (design guard) | constraint | η & Δi |
| 10 | **C10** Binomial Flow Reference | **Stub** | exp/mul (compiles) | reference generator | none |

\* C4 carries the golden-ratio feasibility caveat (G4).

## (b) Gaps where NO controller exists yet

- **G1 — Stochastic swap-flow reference.** The Poisson/LogNormal order-flow model
  (`plank/NOTES.md`) has **no GAMS ground truth**; only the `BinomialProxy` /
  `SwapAmtGen` Plank stubs (C10) exist, unvalidated. No differential fixture.
- **G2 — General-η price impact & CES payoff.** Only η=½ is instantiated. C7 closes
  the *price kernel* under η, but there is **no EVM surrogate for the η-impact /
  CES payoff** (`TODO(eta-CES)`); needs fixed-point `pow`/`exp`-`ln` or a
  linearization around ½. Blocks a general-η version of C1/C2/C4.
- **G3 — σ_xs full-vs-poly lift.** C2 is proven only for `sigma_xs_poly` (with `#`
  free). Lifting to the full `sigma_xs` (where `# = ⌊(i₊−i₋)/Δi⌋` is floor-coupled
  to Δi) over a constant-`#` Δi-interval is **unproven**.
- **G4 — Band-max interior hump.** C4's endpoint rule is FALSE in the small-trade
  sliver `(√5−1)/2·L̄ < Δᴵ < L̄`; an interior-critical-point search (or a
  hump-excluding band) has **no controller**.
- **G5 — Fixed-point realization spec.** All Lean math is over ℝ. No proven WAD /
  Q64.96 / Q128.128 rounding, overflow, or quantization bounds; no `int24` rounding
  spec per inversion. The signed-fixed-point `mulDiv` and saturating clamp that
  C2/C4/C6 need are **not yet written** in Plank.
- **G6 — Liquidity-kernel (ξ, ι) controller.** No proven inversion sets `ξ`/`ι`;
  and the shipped config (`ι=1`) leaves `ℓ(i)=ξ^i` **un-normalized** (Σℓ≠1), so any
  controller using the liquidity kernel must compute the geometric-sum denominator
  itself. No Lean coverage.
