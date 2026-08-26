# Controller Exercise EX-01 — Zero-Slippage / Fair-Trade Spacing Controller (C1)

**Intake:** TODO.md · C1. First merged GAMS/Lean optimization result reframed as a
controller-design exercise.
**Provenance:** `develop` `6369fc6` — tick-spacing optimization **program (1)**;
Lean `lean/exp/eta.lean :: pi_trader_half_zero_at_deltaI_star` (PROVEN, Aristotle
project `88d393e7`), framing `lean/exp/eta_pi_trader_zero_slippage.md`.
**Layer:** static, tick-lattice, fixed `L̄`, representative agent, η = ½.

---

## 1. The proven result (what the optimizer gives us)

In the **small-trade regime** `0 < Δᴵ < L̄` (with `i>0`, `λ>1`, `L̄>0`), the trader
variance-swap payoff `π_{1/2}^trader = (P·Δᴵ − Δᴼ)²` is driven to **exactly zero**
by the closed-form tick spacing

```
Δᵢ⋆  =  log( L̄ / (L̄ − Δᴵ) )  /  ( log λ · i )
```

Proven via the helper `P_half_at_deltaI_star`: at `Δᵢ⋆` the pricing kernel hits

```
P*  =  λ^{ i · Δᵢ⋆ }  =  L̄ / (L̄ − Δᴵ)            ← the slippage-residual root
```

at which the residual bracket `L̄ + P·(Δᴵ − L̄)` collapses to 0.

**Reading (critical):** `Δᵢ⋆` is the **fair-trade / zero-payoff / at-the-money**
spacing — trader and LP mutually indifferent on the variance leg. It is
trader-*pessimal*, and it is the **regime divider**: `π` ↓ for `Δᵢ < Δᵢ⋆`, `π` ↑ for
`Δᵢ > Δᵢ⋆`.

## 2. Control reframing

| Control element | This exercise |
|---|---|
| **Plant** | η=½ pricing/price-impact kernel `P=λ^{iΔᵢ}`, `Δᴼ` = `getAmount1DeltaUnsigned` (V3 math, gamsDiff-verified) |
| **Observable state** `x` | `(L̄, Δᴵ, i, λ)` — pool liquidity, trade size, tick, base |
| **Actuator** `u` | tick spacing `Δᵢ` = `statePartitionDelta` (the `iota`-side knob) |
| **Set-point** | `Δᵢ⋆(x)` — closed-form, the plant **inverse** placing `P` at `P* = L̄/(L̄−Δᴵ)` |
| **Reference/target** | see §3 — the objective is a design choice |

This is a **static feedforward set-point** (plant inversion), open-loop on the
lattice — NOT a time-feedback loop. In the spatially-invariant frame it is one
per-position entry of the control operator (the value the controller writes at tick
`i`).

## 3. Objective — as established by the GAMS/Lean work (not a free choice)

The objective is taken from what the optimizer/theorem actually proves, and both
sides agree:

- **GAMS** (`model/payoff/eta_pi_trader_zero_slippage.gms`, `feat/gams-payoff`):
  a CONOPT NLP that **minimizes** the η=½ trader payoff `π=(P·Δᴵ−Δᴼ)²` over `Δᵢ`.
- **Lean** (`pi_trader_half_zero_at_deltaI_star`): that minimizer is exactly
  `Δᵢ⋆`, where `π = 0`; since `π ≥ 0` (a square), `Δᵢ⋆` is the **global minimizer**.

So the established objective of program (1) is: **the zero-slippage minimizer
`Δᵢ⋆`** — the fair-trade / at-the-money landmark, and the divider between the two
control regimes (`π↓` below `Δᵢ⋆`, `π↑` above).

What EX-01 must realize is therefore this proven `Δᵢ⋆`. **How the protocol *uses*
it** (drive toward it vs. push to the band endpoint farthest from it to maximize the
long-variance payoff) is a **separate policy that the theorem itself flags as
not-yet-formalized** (the band-max companion). That usage policy is OUT OF SCOPE for
EX-01 and is its own future intake item — do not bake a usage policy in here.

## 4. EVM realization — CANDIDATE sketch (route is an open design question, see §6)

> The realization below is a candidate, not a committed design. Choosing the actual
> on-chain route (esp. sqrt vs price-domain) is a controller-design question to solve
> in the design phase — deferred, not decided here.

The closed form has a `log` and `log λ` — expensive on-chain. **But the target is a
price ratio**, and Uniswap tick math is exactly `log_{1.0001}`:

```
P*            = L̄ / (L̄ − Δᴵ)                      // cheap ratio (one mulDiv); needs Δᴵ < L̄
sqrtP*X96     = sqrt(P*) in Q64.96                 // needs fixed-point sqrt (gap G5) OR encode P* and use price-domain
tick*         = getTickAtSqrtRatio(sqrtP*X96)      // = round( log_{1.0001}(P*) ) = round( i·Δᵢ⋆ )   ← the log, for free
Δᵢ⋆_ticks     = tick* / i                          // integer divide; round to a valid tickSpacing multiple
```

So `Δᵢ⋆` is obtained from the **existing `getTickAtSqrtRatio`** (TickMath, in
`plankified-univ3`) — no general `log`. This is why the catalog marks C1 EVM-ready.

Design points to pin:
- **Convention factor:** the C2 proof case found `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean` (sqrt-price
  vs price tick convention). Confirm whether the same factor applies here and bake it
  into the tick conversion. **(verify against TickMath base.)**
- **Regime guard:** require `Δᴵ < L̄`; if `Δᴵ ≥ L̄`, this controller is undefined —
  **saturate** to the band policy (program (2)), never revert (a reverting hook DoSes
  the swap).
- **Rounding:** `Δᵢ⋆_ticks` rounded to a multiple of the pool `tickSpacing`, clamped
  to `[MIN_TICK, MAX_TICK]` (±887272). State the rounding mode (down vs nearest).
- **Fixed-point:** WAD for `L̄`, `Δᴵ`; Q64.96 for prices; single consistent scale,
  divide-by-WAD per multiply. If a fixed-point `sqrt` is too heavy, evaluate in the
  price domain via a price-indexed TickMath variant (decision below).

## 5. Validation

`gamsDiff`-style fixture: sweep `(L̄, Δᴵ, i, λ=1.0001)` over the small-trade regime,
emit `Δᵢ⋆` from the Lean/GAMS reference (exact via SymPy `Rational`), evaluate the
EVM/Plank path, assert `|Δᵢ⋆_evm − Δᵢ⋆_ref| ≤ 1 tick` (quantization tolerance).
Re-use the price-impact harness pattern (`PriceImpactKernelHarness.plk`).

## 6. Design questions

**Resolved (from the GAMS/Lean work, §3):**
- *Objective* — realize the **proven zero-slippage minimizer `Δᵢ⋆`**. The usage
  policy (drive-to vs band-endpoint max-payoff) is the not-yet-formalized band-max
  companion → a separate future intake, not part of EX-01.

**Open — to solve in the controller-design phase (NOT now):**
1. **EVM realization route** — fixed-point `sqrt` (`√P* → getTickAtSqrtRatio`; closes
   gap G5; reusable by C2) **vs** a price-domain TickMath path (no sqrt; C1-only).
2. **Convention factor** — confirm/derive the `×2` Lean↔Plank tick factor here.
3. **Rounding mode** — `Δᵢ⋆ → tickSpacing` multiple (down vs nearest), clamp to ±887272.

These are genuine controller-design decisions; EX-01 records them as the design work
to be done, it does not pre-decide them.

## 7. Definition of done (EX-01)

- [ ] The §6 open design questions resolved (EVM route, convention factor, rounding).
- [ ] `Δᵢ⋆` EVM algorithm specified to the signature level (inputs, scales, the
  chosen tick/price route, regime guard, rounding, saturation).
- [ ] gamsDiff fixture spec (sweep grid + tolerance) defined.
- [ ] Hand-off note: where the Plank lives (coordinate `src/` with `ul2inqpl`),
  what G5 primitive (if any) it needs.

> This exercise is the design spec for C1; *implementation* belongs to the future
> implementation milestone (per MILESTONE.md). EX-01 = "design such a controller", done.
