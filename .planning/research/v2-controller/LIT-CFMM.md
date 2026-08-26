# LIT-CFMM — Annotated Bibliography: CFMM/AMM Economics & Control

Literature survey for the on-chain (EVM/Plank) adaptive feedback controller that tunes a
CFMM's curve and fee parameters (ξ ↔ price-elasticity / LDF α / curvature; ι ↔ tick-spacing)
so the AMM replicates a target contingent payoff out of fee revenue. Anchored on **Q3** of
`MAPPING-SYNTHESIS.md`: replicating / function-maximizing AMMs, dynamic fees, LVR, and
concentrated-liquidity reallocation as a control problem.

Design constraint to keep in view while reading: **simple, algebraically sound (matrix-based),
fully EVM-computable, discrete-time, on the tick grid, no on-chain solvers, hooks must saturate
not revert.** Papers are graded **[FOUNDATIONAL must-read]**, **[CORE]**, or **[PERIPHERAL]**
for our specific design question.

Primary source: arXiv MCP. The single most central paper (Angeris–Evans–Chitra, *Replicating
Market Makers*) was read in full; the curvature paper and Baggiani et al. dynamic-fees paper
were read at the level of abstract + key results sections; the rest from detailed abstracts.

---

## Top 3 must-reads (read these first)

1. **Replicating Market Makers** — Angeris, Evans, Chitra (arXiv:2103.14769, 2021).
   *Why:* This IS our problem statement. It proves the exact duality the controller exploits —
   the space of {concave, nonnegative, nondecreasing, 1-homogeneous} payoff functions `V(c)` is
   equivalent to the space of convex CFMMs, and gives a constructive map (Fenchel conjugate,
   eq. 5: `ψ_V(R) = sup_c (V(c) − cᵀR)`) from a *desired payoff* to the *trading function* that
   statically replicates it — **with no oracle and no time-varying curve**. It is the
   payoff→curve "set-point ⇒ actuator" formula our `ξ`/curve law is approximating on-chain. It
   also flags the central economic catch (see Appendix A): a no-fee CFMM replicating a payoff is
   a *supermartingale* — it gives up theta/positive gamma to arbitrage — and **conjectures fees
   restore self-financing replication.** That conjecture is precisely our thesis ("replicate a
   target payoff *out of fee revenue*"). Section 3 works covered-call and perpetual-American-put
   examples; §3.1 recovers the Balancer `x^w y^{1-w}` kernel from a power payoff — our CES η=½
   kernel is the `w=½` instance.

2. **When does the tail wag the dog? Curvature and market making** — Angeris, Evans, Chitra
   (arXiv:2012.08040, 2020).
   *Why:* This is the actuator theory for **ξ**. It defines price sensitivity / liquidity as the
   **curvature** of the trading function and proves the design rule our controller schedules on:
   *low-curvature* curves are right for assets whose value is ~fixed (stable, deep, low
   slippage), *high-curvature* curves are better for LPs when traders have an informational edge
   (toxic flow). Since ξ tunes the geometric LDF and hence local curvature, this paper supplies
   the *sign and monotonicity* of the ξ actuator and the volatility/adverse-selection trigger
   that should move it — the economic complement to the Lean-proven Δi monotonicity in
   `MAPPING-SYNTHESIS.md`.

3. **Optimal Dynamic Fees in Automated Market Makers** — Baggiani, Herdegen, Sánchez-Betancourt
   (arXiv:2506.02869, 2025).
   *Why:* This gives a directly EVM-portable **fee control law**. Solving the stochastic-control
   problem for dynamic fees in a CFMM, it finds **approximate closed-form** solutions and — the
   load-bearing result for us — that a fee that is **linear in inventory and that tracks changes
   in the external price is a good approximation of the optimal fee structure.** Linear-in-state
   + price-tracking is exactly the `u = −K x` constant-gain affine law the EVM-feasibility
   verdict says we can afford (~9 `mulDiv` for n=3). It also identifies **two regimes** (raise
   fees to deter arbitrageurs vs. lower fees to attract noise traders) — i.e. our gain-scheduled
   / piecewise control structure, motivated economically rather than only by the small/large
   trade sign-flip.

---

## Theme A — Payoff replication & function-maximizing AMMs (the set-point ⇄ curve map)

### [FOUNDATIONAL] Replicating Market Makers — 2103.14769 (2021)
See Top-3 #1. The payoff→trading-function construction, the consistency conditions on `V`
(concave / nonneg / nondecreasing / 1-homogeneous), and the fee-restores-replication conjecture.
**Maps to:** our payoff-replication formula and the *reason* fee revenue is the financing source;
also bounds *what payoffs are reachable* (only concave/short-gamma without shorting or oracles —
a hard constraint on the target the controller may be asked to track).

### [CORE] Replicating Monotonic Payoffs Without Oracles — Angeris, Evans, Chitra; 2111.13740 (2021)
Shows *any monotonic payoff* (cash-or-nothing calls, capped calls, …) can be replicated using
only LP shares in a CFMM, with an explicit trading-function recipe, and derives the arbitrageur's
earnings in closed form. Notably re-derives the constant-product (50/50) curve from first
principles as the "hold 50% in each asset" payoff. **Maps to:** widens the menu of target payoffs
beyond the smooth-concave case to monotone/option-like ones, and the closed-form arbitrage-earnings
formula is a candidate fee-revenue accounting term for the controller's payoff-financing ledger.

### [CORE] The Geometry of Constant Function Market Makers — Angeris, Chitra, Diamandis, Evans,
Kulkarni; 2308.08066 (2023)
A general "axioms" framework: every CFMM has a *unique canonical* trading function that is
nondecreasing, concave, 1-homogeneous — without assuming differentiability or homogeneity — and
proves (via conic duality) the equivalence of portfolio-value function and trading function.
**Maps to:** licenses us to treat our (possibly non-smooth, tick-discretized) curve through its
canonical concave representative, and underwrites the `V ⇄ ψ` duality the controller's set-point
logic assumes even when the on-chain curve is piecewise.

### [FOUNDATIONAL-ref] Improved Price Oracles: Constant Function Market Makers — Angeris, Chitra;
2003.10001 (2020)
The origin of the **portfolio value function** `V(c) = inf_{ψ(R)≥k} cᵀR` (the optimal-arbitrage
/ LP-payoff object) and of the arbitrage-as-zero-sum-game model. **Maps to:** defines our *plant
output* in economic terms — the LP payoff the controller is steering — and the arbitrage response
that moves reserves to the price set-point (the actuation channel: the controller sets curve/fee,
arbitrage moves reserves). Read for definitions, not for control.

### [CORE] Modeling LVR via Continuous-Installment Options — Singh et al.; 2508.02971 (2025)
Models a CFMM LP position as a portfolio of perpetual American continuous-installment options;
proves LVR equals the theta (funding-fee decay) of the embedded at-the-money CI option, and — key
for us — derives a **liquidity profile / price boundaries that suffer approximately constant,
price-independent LVR** over a long forward window, calibrated from the IV term structure.
**Maps to:** a concrete *set-point recipe* for the liquidity-density shape (an ξ/ι target) that
makes the cost the controller must finance roughly constant and predictable — a much friendlier
reference signal than instantaneous LVR. Ties the "replicate a payoff" goal to an explicit
options decomposition.

---

## Theme B — Curvature, weighted-geometric kernels & bonding-curve / LDF design (the ξ/η actuator)

### [FOUNDATIONAL] When does the tail wag the dog? Curvature and market making — 2012.08040 (2020)
See Top-3 #2. Curvature = price sensitivity = liquidity; low- vs high-curvature design rule keyed
to fixed-value vs informed-trader regimes. **Maps to:** the ξ actuator's direction and the
adverse-selection trigger for gain scheduling.

### [CORE] From Swap Axioms to Weighted Geometric Means — Assmann, Degenbaev; 2604.16898 (2026)
Derives the weighted geometric mean `∏ xᵢ^{wᵢ}` (Balancer; constant-product as the symmetric
case) as the *unique* invariant forced by three axioms (validity invariance, Pareto efficiency,
unit invariance); Lean-4 machine-checked. **Maps to:** our CES kernel `L = X^η Y^{1−η}` is exactly
this object, and η is the weight `w`. The paper says *which* curve families are admissible if we
keep standard AMM axioms — constraining how far the ξ/η actuator can deform the curve before it
stops being a sound CFMM. Directly relevant to the `TODO(eta-CES)` general-η question.

### [PERIPHERAL] The Homogeneous Properties of Automated Market Makers — Jensen et al.; 2105.02782
(2021)
Universal liquidity-provisioning derivation; CFMM ≡ token-swap MM under uniform reserves; shows
impermanent loss is a function of both volatility and market depth. **Maps to:** background on how
non-linear price effect → slippage (trader side) and IL (LP side); useful for sanity-checking the
plant's slippage/IL terms, low novelty for the control law itself.

---

## Theme C — Dynamic / adaptive fees & the LVR plant (the fee actuator + the cost being financed)

### [FOUNDATIONAL] Automated Market Making and Loss-Versus-Rebalancing — Milionis, Moallemi,
Roughgarden, Zhang; 2208.06046 (2022)
The "Black-Scholes formula for AMMs." Identifies LVR as the core adverse-selection cost to LPs
(stale prices picked off by arbitrageurs), derives closed-form LVR for all CFMMs, and shows how
protocols can be redesigned to reduce it. **Maps to:** this is the **disturbance / cost model** the
controller fights — the leakage that fee revenue must out-earn for payoff replication to be
self-financing. Its closed-form `LVR ∝ ½ σ² · (pool's price-sensitivity)` is the quantitative
link between volatility (disturbance), curvature (ξ actuator), and the revenue target.

### [FOUNDATIONAL] Optimal Dynamic Fees in AMMs — Baggiani, Herdegen, Sánchez-Betancourt;
2506.02869 (2025)
See Top-3 #3. Linear-in-inventory + price-tracking fee ≈ optimal; two-regime structure.
**Maps to:** the concrete affine `u = −Kx` fee law and its gain-scheduling justification.

### [CORE] Optimal Dynamic Fees for AMMs: A Stochastic Control Approach to LVR — Ghasemlu;
2606.21769 (2026)
Because the fee enters only the *drift* (not the diffusion) of relative wealth, the LP problem
reduces to an ergodic control problem whose solution is a **pointwise volatility feedback**: the
growth-optimal fee is independent of wealth and risk aversion, **collapses to a constant when
volatility is constant**, and is **strictly increasing in instantaneous variance** (pro-cyclical).
Gas costs handled by an **impulse-control dead-band**. **Maps to:** strong evidence our control law
can be a *static gain on a volatility estimate* (fee = f(σ̂)), not a solver — exactly the
"precomputed gains / closed-form set-points" target of Q4; and the dead-band is the EVM
anti-chattering / gas-aware update gate. Confirms the constant-gain reduction is principled, not a
shortcut.

### [CORE] Optimal Fees for Liquidity Provision in AMMs — Campbell, Bergault, Milionis, Nutz;
2508.08152 (2025)
Reduced-form AMM-parallel-to-CEX model with order routing and arbitrage; large-scale simulation +
real data. Finds the optimal fee is competitive with and **remarkably stable** under normal
conditions but should spike in high volatility → recommends a **threshold-type dynamic fee
schedule.** **Maps to:** a discrete, EVM-cheap actuator form — a thresholded (bang/deadband) fee
rather than a continuously-varying one; pairs naturally with regime switching and saturation.

### [CORE] Optimal Fees for Geometric Mean Market Makers — Evans, Angeris, Chitra; 2104.00446 (2021)
Framework for the value to LPs of a G3M with fees under a general diffusion, and selection of
*optimal static* fees; shows mean-variance LPs prefer a G3M as fees → 0. **Maps to:** the
fee↔curvature↔LP-value coupling specialized to our exact kernel family (G3M = our CES curve);
gives the static-fee baseline the dynamic controller must beat and the analytic LP-value objective.

### [PERIPHERAL] Fees in AMMs: A Quantitative Study — Alexander, Fritz; 2406.12417 (2024)
Models arbitrage dynamics for a concrete pool and finds **asymmetric / directional dynamic fees**
(fees that mimic price directionality) mitigate losses to toxic flow. **Maps to:** suggests the
fee actuator should be *signed by trade direction* — consistent with the directional binomial swap
proxy already stubbed on the Plank side; an actuator refinement, not a core requirement.

### [PERIPHERAL] Generalizing Impermanent Loss on DEXs with CFMMs — Tangri et al.; 2301.06831 (2023)
General IL framework across any CFMM with optional concentrated liquidity, including the
fees-exceed-IL profitability condition. **Maps to:** an accounting identity for the
"fee-revenue ≥ replication-cost" break-even the controller targets; useful for the diff-test
ledger, low control content.

---

## Theme D — Concentrated-liquidity reallocation as a control problem (the ι / range actuator)

### [CORE] Strategic Liquidity Provision in Uniswap v3 — Fan, Marmolejo-Cossío, Moroz, Neuder, Rao,
Parkes; 2106.12033 (2021)
Formalizes the **dynamic liquidity provision** problem: narrow ranges concentrate liquidity (more
fees when in-range) but risk falling out of range; reallocation costs gas. Optimizes over a general
strategy class. **Maps to:** the canonical statement of *range/tick-spacing reallocation as
sequential control under a gas (actuation) cost* — i.e. our ι actuator with an action penalty, and
the cost that motivates a dead-band update rule.

### [CORE] Adaptive Liquidity Provision in Uniswap V3 with Deep RL — Zhang, Chen, Yang; 2309.10129
(2023)
DRL policy that adaptively adjusts price ranges to maximize fees net of gas + hedging, explicitly
optimizing against **LVR**, with a rebalancing hedge. **Maps to:** confirms range adaptation +
fee-vs-LVR is the right objective, but its policy is a neural net — *the anti-pattern* for us
(not EVM-computable). Use as a performance ceiling / reference behavior to distill a constant-gain
or thresholded surrogate against, not as an on-chain design.

### [PERIPHERAL] Dynamic Liquidity Provision in CLMMs (τ-reset strategies) — Urusov et al.;
2505.15338 (2025)
Backtests **τ-reset** strategies (re-center the range when price drifts τ away), ML-tuned, beating
uniform allocation by 13–23% in fees. **Maps to:** τ-reset is a clean, EVM-implementable
**gain-scheduled bang-bang reallocation** law (a hysteresis band on price) — a concrete, cheap
candidate for the ι actuator's update trigger; complements Ghasemlu's dead-band.

### [PERIPHERAL] Uniswap Liquidity Provision: An Online Learning Approach — Bar-On, Mansour;
2302.00610 (2023)
Regret-minimization for range selection with **non-stochastic** rewards, with a reward lower bound
in terms of trading volume. **Maps to:** a worst-case-robust alternative to stochastic-control
fee/range laws; relevant if we cannot commit to a swap-flow reference model (the unspecified
stochastic layer in `GAMS-MAP.md` §3) — online-learning gives guarantees without one, though its
per-step update is heavier than a fixed gain.

---

## How this maps to our open design questions

Cross-referenced to the OPEN items and anchoring questions in `MAPPING-SYNTHESIS.md`.

- **OPEN-1 / Q1 (discrete-time control structure on AMM params).** The literature converges on the
  exact structure the EVM-feasibility verdict already favors: **affine, linear-in-state feedback**.
  Baggiani et al. (linear-in-inventory + price-tracking ≈ optimal fee) and Ghasemlu (fee = static
  gain on a volatility estimate; constant when σ constant) jointly justify `u = −Kx` with
  off-chain-precomputed `K` as principled, not a crude approximation. Campbell et al. and the
  τ-reset / dead-band results push toward **thresholded / hysteresis** actuation, which is even
  cheaper and dovetails with "saturate, never revert."

- **OPEN-2 / Q2 (stability on a piecewise-monotone plant; regime switching).** Two independent
  economic sources reproduce our Lean-proven small/large-trade sign-flip as a **two-regime fee
  policy** (Baggiani: deter-arbitrageur vs. attract-noise-trader; Campbell: normal vs. high-vol
  threshold). This means the gain-scheduling is *economically* motivated, not just an artifact of
  the trade-size geometry — strengthening the case for a switched/piecewise-affine controller and
  giving natural Lyapunov candidates (LP growth rate in Ghasemlu's ergodic formulation; LP value
  in Evans et al.).

- **OPEN-3 / Q3 (stochastic swap-flow reference — currently a GAMS gap).** No CFMM paper hands us a
  drop-in Poisson-count/lognormal-amount reference, but two routes exist: (a) Milionis et al. LVR
  gives a *continuous* diffusion-driven disturbance model (`LVR ∝ ½σ²·sensitivity`) that the
  controller can track via a volatility estimate, sidestepping a discrete flow model; (b) Bar-On &
  Mansour's online-learning route gives guarantees with **no** stochastic flow model at all —
  directly relevant since the GAMS side has no such spec.

- **OPEN-4 / Q3 (general η≠½ CES / curve actuator).** Assmann–Degenbaev pins down `X^η Y^{1−η}` as
  the axiomatically forced curve family and η as the weight — so the ξ/η actuator is deforming a
  *known admissible* manifold. The curvature paper gives the direction (informed-flow → higher
  curvature). Replicating Market Makers §3.1 shows the η=½ kernel is the `w=½` power-payoff
  instance, so the general-η extension is "replicate `c^w`" — a closed-form target, even if the
  on-chain `pow` remains the implementation blocker noted in `GAMS-MAP.md` item 8.

- **OPEN-5 / Q5 (fixed-point implementation: anti-windup, saturation, gas).** Ghasemlu's
  **impulse-control dead-band** and the τ-reset hysteresis are the literature's gas-aware
  anti-chattering mechanisms — they ARE our anti-windup/update-gate, and map cleanly onto a
  Solidity "only actuate outside the band, else hold" rule that never reverts.

- **The financing thesis itself (replicate a payoff *out of fee revenue*).** This is exactly the
  open conjecture in Replicating Market Makers Appendix A: a no-fee replicating CFMM is a
  supermartingale (loses theta to arbitrage); fees are conjectured to restore self-financing
  replication. Evans et al. (G3M optimal fees), Milionis et al. (fees hedge LVR), and Singh et al.
  (LVR = option theta; constant-LVR liquidity profile) collectively turn that conjecture into a
  *budget*: choose ξ/ι/fee so that **fee revenue ≥ LVR/theta cost of the target payoff.** That
  inequality is the controller's true set-point.

### One-line takeaways table

| Paper | Grade | Single most useful thing for our controller |
|---|---|---|
| Replicating Market Makers (2103.14769) | FOUND. | payoff→curve map (Fenchel); fees-restore-replication conjecture |
| Curvature / tail-wag-dog (2012.08040) | FOUND. | ξ↔curvature actuator direction + adverse-selection trigger |
| Optimal Dynamic Fees / Baggiani (2506.02869) | FOUND. | linear-in-state + price-tracking ≈ optimal fee (= `u=−Kx`) |
| AMM & LVR / Milionis (2208.06046) | FOUND. | the disturbance/cost model fees must out-earn (`∝½σ²·sens.`) |
| Improved Price Oracles (2003.10001) | FOUND-ref | definition of plant output `V(c)`; arbitrage as actuation channel |
| Stochastic-control LVR / Ghasemlu (2606.21769) | CORE | fee = static gain on σ̂; impulse dead-band for gas/anti-windup |
| Replicating Monotonic Payoffs (2111.13740) | CORE | extends reachable targets to option-like monotone payoffs |
| Geometry of CFMMs (2308.08066) | CORE | canonical concave curve underwrites `V⇄ψ` for piecewise curves |
| CI-options LVR / Singh (2508.02971) | CORE | liquidity profile with ~constant LVR = friendly set-point |
| Swap Axioms → WGM (2604.16898) | CORE | `X^ηY^{1−η}` is the admissible curve manifold; η = weight |
| Optimal Fees LP / Campbell (2508.08152) | CORE | threshold-type dynamic fee schedule (cheap actuation) |
| Optimal Fees G3M (2104.00446) | CORE | static-fee baseline + LP-value objective for our kernel |
| Strategic LP v3 (2106.12033) | CORE | ι/range reallocation as sequential control under gas cost |
| Adaptive LP DRL (2309.10129) | CORE | performance ceiling to distill into a constant-gain surrogate |
| τ-reset CLMM (2505.15338) | PERIPH. | hysteresis-band reallocation = EVM-cheap ι update trigger |
| Online-learning LP (2302.00610) | PERIPH. | range control with NO stochastic flow model (regret bound) |
| Directional fees (2406.12417) | PERIPH. | sign the fee by trade direction (matches binomial proxy) |
| Generalizing IL (2301.06831) | PERIPH. | fee≥IL break-even identity for the diff-test ledger |
| Homogeneous AMM props (2105.02782) | PERIPH. | IL = f(volatility, depth) sanity check on plant |
