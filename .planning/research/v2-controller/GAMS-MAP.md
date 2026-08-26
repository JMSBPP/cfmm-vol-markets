# GAMS Model Map — for the on-chain adaptive feedback controller

READ-ONLY research artifact. Maps the off-chain GAMS algebraic/optimization model
in this CFMM repo and extracts what a *simple, EVM-computable* feedback controller
must reproduce, approximate, or replace. Scope is the GAMS layer plus the
GAMS↔EVM differential-test bridge.

Sources surveyed:
- Vendored GAMS: `/home/jmsbpp/cfmms-playground/cfmm-replicationPlank/model/`
- GAMS WIP worktree (branch `feat/gams-payoff`): `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/`
- Differential-testing worktree (branch `feat/gamsdiff`): `/home/jmsbpp/cfmms-playground/cfmm-wt/gamsdiff/`

> Note on "two model snapshots": the vendored `model/` (the merged baseline) is
> thinner than the `cfmm-wt/gams` worktree (active payoff work). Where they differ
> I cite both. The WIP worktree is the most advanced GAMS state and is where the
> only real `Model`/`Solve` lives.

---

## 1. The `.gms` files and what each does

### Vendored baseline (`model/*.gms`)

| File | Role | Real model or stub? |
|---|---|---|
| `model/primitives.gms` | Shared fixed-point constants (`unity=1e18` WAD, `uintMax=2^256-1`, `precision=1e12`, tick bounds `maxTick=2^24-1`, `minTick=2^23-1`). Include-guarded; include-only. | Constants only |
| `model/PricingKernel.gms` | The pricing kernel `priceKernel(s,t) = (λ/unity)^(tickVal·spacing/2)·2^96`, i.e. the EVM `getSqrtRatioAtTick` Q64.96 sqrt price. Defines sets `tick=k1..k241`, `tickSpacingDomain=s1..s60`, `lambda=1.0001·1e18`. | **Real** (algebraic, no solve) |
| `model/LiquidityKernel.gms` | Per-tick liquidity weight `ℓ(ξ,ι;i)=ξ^i / ((1−ξ^ι)/(1−ξ))` (normalized geometric kernel). Declares `xi`/`iota` structural params with admissible domains. | **Real** (algebraic), but see §2 caveat |
| `model/TradingRegion.gms` | Intended home of the CES trading function `L=X^η·Y^{1−η}` (`poolLiquidityCone`), elasticity `eta_x_y`, inventory/liquidity positive variables with bounds. **Vendored copy is gutted to `$include primitives.gms` only.** | **STUB** in vendored; real in build listing |
| `model/PayoffModule.gms` | Vendored copy is an empty stub (`$include primitives.gms`). | **STUB** (vendored) |
| `model/dynamic/InitState.gms` | Initial inventory `init(X)=100·1e18, init(Y)=10000·1e18`. Orphan fragment (references `inventory` set it pulls via PricingKernel). | Data fragment |

The vendored `TradingRegion.gms` body (the real version) is preserved in the build
listing `model/build/TradingRegion.lst` and reads (the load-bearing equation):

```
poolLiquidityCone..
    poolL("liquidityL") =e=
        inv("assetX") ** (eta_x_y / unity)
      * inv("cashY") ** (1 - eta_x_y / unity);
```

This is the **only `Equation` in the baseline**, and there is **no `Model`/`Solve`**
statement anywhere in the vendored tree — `model/BUILD.md` confirms the vendored
content is "syntax-checkable only."

### WIP worktree additions (`cfmm-wt/gams/model/...`)

| File | Role |
|---|---|
| `PricingKernel.gms` | Same as vendored **plus** two `$macro`s: `tunablePricingKernel(s,t,e)` (η-generalized pricing kernel, e=1/2 recovers the EVM kernel) and `priceImpactKernel_Add0(sqrtP,L,dx)` = `L·sqrtP / (L + dx·sqrtP/2^96)` (the post-trade sqrt price, mirrors V3 `getNextSqrtPriceFromAmount0RoundingUp` add=true). |
| `payoff/_PayoffScaffolding.gms` | Macro library + constants for the payoff program: `Q96=2^96`, `Q128=2^128`, Δᵢ bounds `[1,200]`, η in Q0.128, tolerances. Defines Lean- and Plank-coordinate evaluators (see §2). |
| `payoff/eta_pi_trader_zero_slippage.gms` | **The one real optimization program.** Finds the zero-slippage trade size Δᵢ⋆ that minimizes trader payoff π; includes an NLP solve + discrete enumeration + closed-form cross-checks. Exports `payoff_zero_slippage.gdx`. |
| `PayoffModule.gms` | Orchestrator that `$include`s the per-theorem payoff files. |
| `PriceImpactKernelFixture.gms` | GDX generator: tabulates `priceImpact(s,tick,dx)` over the grid → `price_impact_kernel.gdx` for the diff harness. |
| `_PriceImpactKernelInputs.gms` | Shared inputs: `Lbar=1e18`, `dxVal` = {small 1e15, medium 1e17, large 1e18}. |
| `test/PricingKernelTest.gms`, `test/PriceImpactKernelTest.gms`, `test/PayoffModuleTest.gms` | GAMS-side assertion tests (`abort$` on property violations). |

---

## 2. The optimization / decision problem

### What kind of problem is it?

Almost the entire GAMS layer is **algebraic tabulation, not optimization**. The
pricing kernel, liquidity kernel, and price-impact kernel are closed-form
`Parameter` assignments evaluated over index sets — no decision variables, no
solver. The CES trading function is the only *declared* `Equation`, but in the
baseline it is never wrapped in a `Model`/`Solve`.

There is exactly **one genuine optimization program**, in the WIP worktree:
`model/payoff/eta_pi_trader_zero_slippage.gms`.

**Decision variable:** `di` — the trade input size Δᵢ (a positive integer "tick
count" of input), bounded `di.lo=1, di.up=200`.

**Objective (minimize):**
```
Positive Variable di ;   di.lo = diMinInt; di.up = diMaxInt;     # [1,200]
Variable piVal ;
Equation payoffEq ;
payoffEq.. piVal =e= piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, di), LbarQ128, DICfgQ128);
Model ZeroSlip / payoffEq /;
option nlp = conopt;
Solve ZeroSlip using nlp minimizing piVal;
```

So it is a **single-variable continuous NLP** (CONOPT), with the integer answer
recovered separately by a **discrete enumeration over Δᵢ∈{1..200}** and confirmed
against a Lean-proved closed form. Static (no time loop); the "dynamic" label in
the repo is aspirational (see §3).

**The objective is the CES "long" trader payoff (η=1/2):**
```
π_{1/2}^{trader} = (P_{1/2}(i)·Δ^I − Δ^O)²          # squared shortfall
```
encoded by the scaffolding macros (`payoff/_PayoffScaffolding.gms`):
```
$macro sqrtPX96_at(lamWad,iTick,Di)      ( ((lamWad)/unity) ** ((iTick)*(Di)/2) * Q96 )
$macro priceImpactKernel_Add0(sqrtP,L,dx)( (L)*(sqrtP) / ( (L) + (dx)*(sqrtP)/2^96 ) )   # post-trade sqrtQ
$macro piTrader_Half_Plank(sqrtP,L,DI)   ( sqr( traderTerm − traderDeltaO ) )
```
where `traderTerm = sqrtP·Δ^I/Q128/Q96` and `traderDeltaO = L·(sqrtP−sqrtQ)/Q128/Q96`.

**Closed-form target (what the solve is validating):** the zero-slippage size
```
Δᵢ⋆_Lean  = log( L̄ / (L̄ − Δ^I) ) / ( log(λ) · i )
Δᵢ⋆_Plank = 2 · Δᵢ⋆_Lean
P_{1/2}(Δᵢ⋆) = L̄ / (L̄ − Δ^I)
```
(verbatim from `eta.lean:491-512`, cross-checked four independent ways: Lean
closed form, CONOPT NLP argmin, integer enumeration argmin, and 3-point parabolic
interpolation). The payoff is V-shaped (convex) in Δᵢ with the minimum at Δᵢ⋆.

**Stub vs real:**
- Pricing kernel, price-impact kernel, CES trading function, zero-slippage payoff
  program = **real**.
- `TradingRegion.gms` (vendored) and `PayoffModule.gms` (vendored) = **stubs**;
  the real `poolLiquidityCone` and payoff logic live in the WIP worktree / build
  listings.
- The **general η≠1/2 case is NOT implemented in GAMS**. Everything is pinned to
  η=1/2 because that is "the ONLY weight with an on-chain counterpart"
  (`tools/gamsdiff/gamsdiff/core.py`, `BALANCED_ETA=0.5`). The η-CES post-trade
  form is flagged `TODO(eta-CES)` in `PricingKernel.gms` and blocked on an EVM
  function to diff against.

### Liquidity-kernel caveat (a real bug-flag for the controller)

`model/spec/liquidityKernel.md` documents that the shipped config sets ι=1, so the
normalizing denominator `(1−ξ^ι)/(1−ξ)` collapses to 1 and the code computes the
**raw geometric ramp `ℓ(i)=ξ^i`, not a unit-sum normalized weight**, over the full
241-tick grid. The unit-sum normalization is **unrealized in the current
configuration**. A controller must not assume Σℓ=1 from the current GAMS output.

---

## 3. Discrete-time structure, swap-flow / stochastic model, tick grid, state

### Tick grid (real, in GAMS)
- `tick = k1*k241` → `tickVal = ord(tick) − 121`, i.e. integer ticks **i ∈ [−120, 120]** (241 points).
- `tickSpacingDomain = s1*s60`, `tickSpacingVal = ord(s)`, i.e. spacing Δᵢ ∈ {1..60}; the diff/fixtures use **s1 (spacing 1)** only.
- Tick bounds (`primitives.gms`): `maxTick = 2^24−1 = 16777215`, `minTick = 2^23−1` (mid tick) — the int24 EVM tick domain, though the grid only samples [−120,120].
- `baseTick`: there is no explicit base-tick offset; the −121 shift centers the grid at tick 0 (sqrtP ≈ 2^96).

### State variables (real, but static)
- Inventory `inv(assetX), inv(cashY)` (positive vars, bounds `[1e18, uintMax]`) in `TradingRegion`; initial values `init(X)=100e18, init(Y)=10000e18` in `dynamic/InitState.gms`.
- Pool liquidity `poolL("liquidityL")` = `X^η·Y^{1−η}` (CES), bounds `[1e18, uintMax]`. In the payoff program `L̄` is fixed = 1 (Q128.128).
- Structural params: ξ (`xiNorm`, decay base), ι (`iotaVal`, support length), η (`eta_x_y/unity`, elasticity), λ (`1.0001`, pricing base).

### Discrete-time / stochastic swap-flow model — **NOT in GAMS**
There is **no time index, no swap-count process, no direction draw, and no
stochastic amount model in the GAMS sources.** `model/exp/eta.md` references a
trader payoff `π ∝ σ` (proportional to volatility) and a `dynamic/` directory
exists, but the only "dynamic" file is the static `InitState.gms`. **UNKNOWN /
not authored:** any GAMS discrete-time controller dynamics.

The stochastic swap-flow primitives that *do* exist live on the **Plank (on-chain)
side**, not in GAMS (`cfmm-wt/gams/src/lib/`, `src/ldf/`):
- `src/lib/SwapAmtGen.plk` — `swapAmount(timeIndex)` = `LOWER_BOUND + 2·KERNEL^(timeIndex^4·decay)`, a **time-decay-driven swap-amount generator** bounded in [19e18, 21e18] with a stored `timeDecay` state slot (init −10000e18). Comment: "simplest time index is `block.number`."
- `src/lib/BinomialProxy.plk` — `gen_rand(seed)` returns 0/1 from `@evm_difficulty()` parity: a **direction / Bernoulli draw proxy** (a binomial increment).
- `src/ldf/GeometricDistribution.plk` — selector skeleton only (a liquidity-density-function placeholder; all branches empty → reverts).

These are the embryonic on-chain analogs of a discrete-time swap process (count
via `timeIndex`/`block.number`, direction via the binomial proxy, amount via
`swapAmount`). **They are stubs**, not validated against any GAMS reference.

---

## 4. GAMS↔EVM reconciliation (the gamsdiff bridge)

Architecture: GAMS evaluates a kernel over the grid → `execute_unload` to GDX →
Python (`tools/gamsdiff/`) reads the GDX (`gams.transfer`), rounds float64→int,
serializes a JSON fixture → Foundry `.diff.t.sol` deploys a Plank harness wrapping
the **real Uniswap V3 math** and asserts `assertApproxEqRel` row-by-row.

### Kernels validated
| Kernel | GAMS source | EVM reference (Plank harness) | Fixture | Rows |
|---|---|---|---|---|
| Pricing kernel (tick→sqrtPriceX96) | `priceKernel` / `tunablePricingKernel(e=½)` | `v3::math::tick_math::getSqrtRatioAtTick` (`PriceKernelHarness.plk`, sel `0x986cfba3`) | `pricing_kernel.json` | 241 |
| Price-impact kernel (post-trade sqrtP) | `priceImpactKernel_Add0` | `v3::math::sqrt_price_math::getNextSqrtPriceFromAmount0RoundingUp(add=true)` (`PriceImpactKernelHarness.plk`, sel `0x157f652f`) | `price_impact_kernel.json` | 723 (241 ticks × 3 dx) |

The CES long payoff itself (`CESLongPayoff.plk`, sel `0x1dbad771`) composes
`getNextSqrtPriceFromAmount0RoundingUp` + `getAmount1DeltaUnsigned` + `mulDiv`;
its building blocks are diffed but the full payoff has no committed GAMS↔EVM
fixture yet (the GAMS payoff program validates against **Lean**, not against the
EVM payoff contract). **Liquidity kernel: no EVM diff** (off-chain only).

### Fixed-point conventions
- **Q64.96** — sqrt prices (`priceKernel`, price-impact output). `2^96 = 79228162514264337593543950336`.
- **WAD = 1e18** (`unity`) — liquidity, amounts, λ scaling.
- **Q128.128** — L̄ and Δ^I amounts in the payoff program; **Q0.128** for η (η=½ = `2^127`).
- **eta (η)** — elasticity weight; **pinned to 0.5** for all EVM diffs. `shell.py` *hard-asserts* `etaWeight == 0.5` when loading the impact GDX. η=½ is the balanced 50/50 pool where the tunable kernel reduces exactly to the V3 kernel; η≠½ is off-chain-only.

### Tolerances
- Solidity diffs: `assertApproxEqRel(actual, expected, EPS)` with **EPS = 1e3 = 1e-15 relative**. Producer ran an exact-integer EVM replica over all 723 impact rows: `max_rel_error = 2.02e-16, rows_over_EPS = 0, ~5× headroom` (`PRICE_IMPACT_HANDOFF.md`).
- GAMS-side assertion tests: **1e-12 relative** (`zeroTolerance = 1e-20` absolute for zero refs). The diff layer deliberately tightened to 1e-15.
- Quantization caveat (`core.py::to_sqrt_price_x96`): above 2^52 the float64 is integer-valued at ~2^44 granularity, so the GAMS reference is quantized to ~2^44 — **not exact-integer ground truth**.

### Harness selectors (for the controller's reference math)
- `getSqrtRatioAtTick(int24)` → `0x986cfba3`
- `getNextSqrtPriceFromAmount0RoundingUp(uint160,uint128,uint256,bool)` → `0x157f652f`
- `cesLongPayoff(uint160,uint128,uint256)` → `0x1dbad771`
- `swapAmount(uint256)` → `0xbc4af3dc`; `setDecay` → `0x03ec5467`; `timeDecay` → `0xcaaedea1`
- Deploy idiom: `plankDeployFFI(...)`, backend `"sona"`, dep `v3=lib/plankified-univ3/plank/lib`.

---

## 5. What the on-chain controller must reproduce vs. what is EVM-infeasible

### Already EVM-native (reuse the V3 math directly — proven equal to GAMS)
These GAMS kernels are *defined* to mirror Uniswap V3 functions and are diff-verified
to ~2e-16. The controller does **not** approximate them — it calls the same library:
1. **Pricing kernel** `P_{1/2}(i) = λ^{i·Δᵢ/2}·2^96` ≡ `getSqrtRatioAtTick`.
2. **Price-impact / post-trade price** `P_{1/2}(Δ^I) = L̄·sqrtP/(L̄ + Δ^I·sqrtP/2^96)` ≡ `getNextSqrtPriceFromAmount0RoundingUp(add=true)`.
3. **Output amount** Δ^O ≡ `getAmount1DeltaUnsigned`.
4. **CES long payoff** `π=(P·Δ^I−Δ^O)²` ≡ `cesLongPayoff.plk` (composition of the above).

### Must be reproduced as a closed form / lookup (feasible)
5. **Zero-slippage trade size** `Δᵢ⋆ = log(L̄/(L̄−Δ^I)) / (log(λ)·i)` (Lean-proved).
   On-chain this is the controller's *set-point*. `log` is not EVM-native, but:
   - the relation `P_{1/2}(Δᵢ⋆) = L̄/(L̄−Δ^I)` is a **rational closed form** (no log),
     so the controller can target the *price ratio* directly instead of the log size; OR
   - precompute Δᵢ⋆ off-chain and ship it, OR use the existing V3 `getTickAtSqrtRatio`
     (binary search) to invert price→tick.
6. **Tick grid / spacing arithmetic** (`tickVal = ord−121`, spacing scaling) — trivial integer math.

### EVM-INFEASIBLE as-is — needs a linearized/closed-form surrogate
7. **The CONOPT NLP solve** (`Solve ZeroSlip using nlp minimizing piVal`). No
   nonlinear solver runs on the EVM. **Surrogate:** the controller must NOT solve;
   it uses the closed-form Δᵢ⋆ (item 5) or a cheap **1-D search/Newton step / bisection**
   on the V-shaped (convex) payoff. The repo already proves enumeration and parabolic
   interpolation reproduce the NLP argmin — the parabolic 3-point update
   `Δ* ≈ Δ₀ + ½(π₋−π₊)/(π₋−2π₀+π₊)` is a **directly EVM-portable controller update**.
8. **Real-power `**` with fractional/large exponents** (`λ^{i·Δᵢ/2}`, `X^η`, `**`):
   GAMS uses IEEE `**`; the EVM has no float pow. For the pricing kernel this is
   already handled (the V3 `getSqrtRatioAtTick` bit-trick *is* the surrogate). For a
   **general η≠½ CES** (`L=X^η·Y^{1−η}`, tunable-kernel `λ^{i·Δᵢ·e}`) there is **no EVM
   surrogate yet** — flagged `TODO(eta-CES)`. A controller wanting η≠½ needs a
   fixed-point pow (e.g. `exp/ln` via `PRBMath`/`solady`) or a linearization around η=½.
9. **`log`-based diagnostics / kernel-shape probes** (the log-ratio checks in the
   payoff program) — off-chain validation only; the controller should rely on
   ratio/difference forms, not logs.
10. **Liquidity-kernel normalization** `ℓ(i)=ξ^i/((1−ξ^ι)/(1−ξ))`: the geometric
    partial sum is a closed form (EVM-cheap if ξ,ι are fixed-point), but note the
    **current GAMS config does not normalize** (ι=1; see §2 caveat). A controller
    must compute the geometric-sum denominator itself if it wants Σℓ=1.
11. **Float64 ↔ fixed-point reconciliation**: GAMS works in IEEE doubles (~2^44
    quantization above 2^52); the EVM is exact integer. The controller's state must
    be the integer/fixed-point representation; treat GAMS values as references good
    to ~1e-12…1e-15 relative, never as exact integers.

### Stochastic / dynamic layer — UNSPECIFIED on the GAMS side
12. The swap-flow process (counts, directions, amounts over time) that a *feedback*
    controller reacts to has **no GAMS reference model**. The only artifacts are the
    Plank stubs (`SwapAmtGen.plk` time-decay amount, `BinomialProxy.plk` direction
    draw, `GeometricDistribution.plk` empty LDF). If the controller's feedback loop
    is meant to track a GAMS-defined stochastic process, **that process does not yet
    exist in GAMS** — this is a gap to flag, not something to replicate.

---

## Open questions / unknowns to confirm
- Is the controller meant to track the **η=½ pinned** regime, or does it need the
  un-implemented η≠½ CES? (Determines whether item 8 is in scope.)
- What is the controller's actuator — does it set Δᵢ (trade size), tick spacing,
  the fee, or liquidity L̄? GAMS only optimizes Δᵢ today.
- Is there an intended GAMS discrete-time / stochastic spec (the `dynamic/` dir and
  `π∝σ` note hint at one) or is the dynamics defined entirely on the Plank side?
