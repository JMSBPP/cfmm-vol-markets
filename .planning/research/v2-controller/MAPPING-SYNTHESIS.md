# EVM-Controller v2.0 — Mapping Synthesis

> **SCOPE CORRECTION (user, 2026-06-28): this milestone is the STATIC, low-level
> kernel layer — NOT the dynamic/hook layer.** Assume fixed pool liquidity `L̄`, a
> representative agent, η=½. The "controller" here is **closed-form algebraic
> inversion** at the kernel level: choose a structural parameter (`Δi`, and where
> needed η/ξ/ι) so a kernel-level target (cross-section vol `σ_target`,
> zero-slippage, payoff exposure) is hit. There is NO time index, NO feedback
> loop, NO adaptive fee policy `φ(·;t)`, NO V4 `beforeSwap` hook in scope — those
> are KERNEL.md's higher dynamic layer (`inf_Θ C_φ^π = d(π, Υ^φ)`), explicitly
> deferred. The static inversions are mostly ALREADY PROVEN in `lean/exp/eta.lean`;
> the milestone deliverable is the spec that assembles them into a coherent static
> control kernel + its EVM fixed-point realization. The "Anchoring design
> questions" and dynamic-control sections below are superseded by this correction
> and retained only for the higher (later) layer.

## Static low-level control kernel (the in-scope object)

Layering (KERNEL.md): static kernels `P_X(Δi;i)=λ^{iΔi}`, `ℓ(ξ,ι;i)`, CES payoffs,
vol term structure `σ` → (later) adaptive fee policy `φ` → (later) `inf_Θ d(π,Υ^φ)`.
THIS milestone = the first box only.

Proven static inversions = the control law (all in `lean/exp/eta.lean`):
- **`sigma_xs_poly_target_exists`** — closed form `Δi⋆(n,d,σ_target) =
  (d·n(n−1)+√disc)/(n(n−1)(2n−1)/3)`, `disc = c1²−4c2(d²−σ_target)`,
  `c2=n(n−1)(2n−1)/6`, `c1=−d·n(n−1)`; valid for `n≥2`, `σ_target>d²` (strict).
  Uses `sigma_xs_poly` (n free), NOT full `sigma_xs` (where `#=⌊(i₊−i₋)/Δi⌋` is
  floor-coupled) — correct object when the tick grid is held fixed.
- **`pi_trader_half_strictly_increasing_in_Δi`** — `π_{1/2}=(PΔᴵ−Δᴼ)²` strictly
  increasing in `Δi` iff `Δᴵ≥L̄` (large-trade); small-trade is piecewise with a
  zero at `P=L̄/(L̄−Δᴵ)`.
- **`eta_split_kernel_identity`** — `P_η(i)=P_{1/2}(i₋)P_{1/2}(i₊)`,
  `i₋=⌊ηi⌋`, `i₊=i−i₋`: realize generic-η on the ½ price-impact the EVM has.
- **`sigmaVTS_invariant_under_eta_Δi_rescaling` ∧ `eta_Δi_independent_in_sigma_and_L_eta`**
  — `(η,Δi)` collapse to `η·Δi` in σ but separate in `(σ,L_η)`: tick spacing
  cannot replicate all of elasticity; need both knobs for both observables.
- **`eta_pi_trader_zero_slippage`** — zero-slippage `Δi⋆` closed form.

Numeric primitives (primitives.md): WAD=1e18, ε(precision)=1e12, unityTick=1,
maxTick=2²⁴−1, minTick=2²³−1, uintMax=2²⁵⁶−1. Pricing base λ=1.0001. Tick grid
k1..k241 ⇒ `i∈[−120,120]` (tickVal=ord−121). EVM realization needs: fixed-point
`sqrt`, `mulDiv` (have, plankified-univ3), the integer η-split, regime branch,
saturation (never revert). Liquidity-kernel normalization caveat: with ι=1 the
weights are the raw ramp `ξ^i` (Σ≠1) — don't assume normalized.

Open at the static layer: general η≠½ (needs fixed-point pow or linearize around
½); lift `σ_xs` inversion from `_poly` (n free) to a Δi-interval where `#` is
constant; concrete int24 bounds + rounding/quantization spec for each inversion.

---
## (Superseded — higher dynamic layer, retained for later)


Synthesis of the four mapping documents in this directory (`PROJECT-MAP.md`,
`LEAN-MAP.md`, `GAMS-MAP.md`, `EVM-CONTROL-PRIMITIVES-MAP.md`). This is the
research/design-spec milestone for the on-chain (EVM/Plank) adaptive feedback
controller — `CTRL-01` (control law in `src/DynamicCFMM.plk` updating `xi`/`iota`)
and `CTRL-02` (V4 `beforeSwap` hook). Design constraint: **simple, algebraically
sound (matrix-based), fully EVM-computable, discrete-time, on the tick grid, no
heavy external optimizers.**

## The system in one picture

- **Plant** = the per-swap price-impact transition (Uniswap V3 math:
  `getNextSqrtPriceFromAmount0RoundingUp`, `getAmount1DeltaUnsigned`,
  `getSqrtRatioAtTick`). GAMS↔EVM diff-verified to ~2e-16 (gamsdiff fixtures,
  EPS=1e-15). **Reuse, do not re-model.**
- **Actuators** = `xi` ↔ `priceElasticity`/LDF `alpha`; `iota` ↔
  `statePartitionDelta`/`tickSpacing`/`baseTick`. Fixed-point: WAD 1e18, Q64.96.
- **Proven control structure (Lean `eta.lean`):** tick spacing `Δi` is a clean
  one-parameter actuator in the **large-trade regime `Δᴵ ≥ L̄`** (strictly
  monotone trader payoff), but **non-monotone with a sign-flip in the small-trade
  regime** (at `P = L̄/(L̄−Δᴵ)`). ⇒ control law must be **piecewise / gain-scheduled
  by trade regime.**
- **Set-points / surrogates (proven, EVM-portable):** zero-slippage
  `Δᵢ⋆ = log(L̄/(L̄−Δᴵ))/(log λ · i)`, log-free target `P_{1/2}(Δᵢ⋆)=L̄/(L̄−Δᴵ)`,
  variance-target `Δi`, small-signal quadratic gain `π/ΔI² → P²(P−1)²`, and a
  **3-point parabolic update** `Δ* ≈ Δ₀ + ½(π₋−π₊)/(π₋−2π₀+π₊)`.

## EVM-feasibility verdict (from EVM-CONTROL-PRIMITIVES-MAP)

- **Feasible on-chain in `beforeSwap`:** a small (`n ≤ 3–4`) **constant-gain**
  linear update `x_{k+1} = A x_k + B u_k` (and output `u = -K x`) with `A,B,K`
  **precomputed off-chain** (GAMS/Lean). ~9 `mulDiv` for n=3 — gas-cheap.
- **NOT advisable on-chain:** matrix inverse/solve, eigendecomposition, any
  iterative solver, real-power `pow`/`log` (only Q96 tick↔price closed forms exist).
- **Primitives present:** `plankified-univ3` `mulDiv` (512-bit), Q96 sqrt-price
  math, tick math, safe casts. **Missing (hand-write):** signed-fixed mul/div,
  vector/matrix ops, saturation/clamp, WAD `exp/ln`.
- **Hard rule:** a reverting hook DoSes the swap ⇒ controller must **saturate,
  never revert**; one consistent WAD scale, divide-by-WAD per multiply.

## What's proven vs. what we must add

PROVEN (reuse): plant transition, monotonicity/direction of `Δi`, closed-form
set-points, small-signal gain, convex-payoff parabolic update, identifiability
collapse (η·Δi in σ).

OPEN (this milestone's design work):
1. Discrete-time closed-loop **dynamics model** (state, update, regime switching).
2. **Stability / convergence** guarantee (Lyapunov / contraction / piecewise-affine).
3. **Stochastic swap-flow reference** (Poisson counts, ±1 direction, lognormal
   amounts) — currently Plank stubs only, no GAMS ground truth.
4. **General η≠½ CES** surrogate (fixed-point pow or linearization around η=½).
5. **Fixed-point implementation** spec: scales, signedness, anti-windup, saturation,
   overflow bounds.

## Prerequisites / coordination (from PROJECT-MAP + onboarding)

- Closed loop needs the **v1 open-loop write/read surface compiling first**:
  `initVolTermStructure` body + lens getters (stubs), `ReferenceMarket.init`
  (TODO), selector `0xd9c112ef` (likely wrong), `DynamicCFMM.plk` (non-compiling).
- **No V4 `beforeSwap` hook exists** yet (NOTES.md sketch: Solidity `IHook` →
  deployed Plank `plkWrapper`); top-level `v4-core/` remapping is dangling.
- `src/` is 100% Plank, owned by `ul2inqpl` — coordinate controller file layout;
  never edit `foundry.toml`/`remappings.txt`.
- Ships via PR `feat/evm-controller → develop`; full gate must be green.

## Anchoring design questions for the literature step

- Q1. Control structures for a per-swap, gas-bounded, fixed-point feedback loop on
  AMM params (constant-gain state feedback, gain scheduling, PI, deadbeat, MPC-free).
- Q2. Stability/convergence for discrete-time feedback on a piecewise-monotone plant
  (Lyapunov, contraction, piecewise-affine / switched systems).
- Q3. CFMM-specific: dynamic fees, replicating / function-maximizing AMMs, payoff
  replication from fee revenue, concentrated-liquidity reallocation control.
- Q4. Stochastic market-making control under Poisson order flow (Avellaneda–Stoikov
  lineage) — what reduces to precomputed gains / closed-form set-points.
- Q5. Fixed-point / integer controller implementation — quantization, anti-windup,
  saturation, numerical stability.
