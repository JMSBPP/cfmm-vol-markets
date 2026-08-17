# Social-choice functions for optimizing the protocol parameters `δᵢ` and `η`

*Answer to the design question: "What are some social choice functions we can decide
for optimizing `δᵢ`, `η` that come natural and have economic meaning?"*

This note is grounded in the objects already formalized in this repository
(`exp/eta.lean`, `exp/CESLongVolPayoff.lean`, `exp/EtaReplication.lean`,
`exp/EtaLiquidityPayoff.lean`). A machine-checked companion that **defines** each of
the welfare functionals below and **proves** their basic structural / economic
properties is in `exp/SocialChoiceParameters.lean`.

---

## 1. What "social choice over `(δᵢ, η)`" means here

The protocol designer chooses two scalar parameters:

* **`δᵢ` (= `Δi`)** — the tick spacing / price-grid granularity. In Uniswap-v3 /
  Plank terms it is selected from a small *discrete* admissible menu
  (e.g. `1, 10, 60, 200` ticks), so choosing `δᵢ` is literally a **social choice
  over a finite menu of alternatives**.
* **`η`** — the CES curvature / Bregman exponent of the pricing kernel
  (`p_eta = λ^{i·Δᵢ·η}`, with the `η = ½` quadratic member being ordinary
  squared-slippage). It is a *continuous* dial that trades off concentration of
  liquidity against tail robustness.

A **social-choice / social-welfare function** is a map

```
W : (parameters δᵢ, η)  ↦  ℝ
```

obtained by **aggregating the utilities of the participating agents** at those
parameters, and the design rule is `argmax_{δᵢ, η} W`. The agents in this model and
their already-formalized payoffs are:

| agent | payoff in the repo | economic reading |
|---|---|---|
| **long-vol trader** | `pi_trader_half` / `pi_plus_eta = d(p·Δᴵ, Δᴼ)` | squared slippage they earn (variance buyer) |
| **LP / short-vol** | `pi_minus_eta = −pi_plus_eta`, `pi_minus_eta_liq` | counterparty payoff, scaled by liquidity share `ΔL/L` |
| **protocol / pool** | the cross-section dispersion `sigma_xs`, `sigma_realized` | realized-variance / fee base captured per tick band |
| **arbitrageur / price tracker** | residual of `Delta_O_eta` vs. the external price | keeps `p_post` aligned |

The functionals below differ only in **how** these per-agent payoffs are aggregated;
each corresponds to a standard axiomatic position in welfare economics.

---

## 2. The candidate social-choice functions

Write the agent-utility profile at a candidate parameter pair as
`u = (u₁,…,u_m)` (e.g. `u = (trader, LP)` or `(trader, LP, protocol)`),
each `uⱼ = uⱼ(δᵢ, η)`.

### (A) Utilitarian — total gains from trade `W = Σⱼ uⱼ`
Maximize the **sum** of surpluses. Picks `(δᵢ, η)` that maximize aggregate
efficiency (total gains from trade), ignoring distribution. Axiomatically it is the
**unique** anonymous, Pareto, *additive/separable* aggregator (Harsanyi). Natural
default when the protocol only cares about TVL-weighted throughput.
*Property proved:* monotone in every coordinate ⇒ **Pareto-respecting**.

### (B) Weighted utilitarian / Bergson–Samuelson — `W = Σⱼ wⱼ·uⱼ`, `wⱼ ≥ 0`
Same as (A) but with weights. The economically *native* choice on-chain because the
weights `wⱼ` can be **liquidity shares `ΔL/L`** (already the scaling factor in
`pi_minus_eta_liq_eq`, where `π⁻_liq = −(ΔL/L)²·π⁺`) or **governance-token stakes** —
i.e. token-weighted voting *is* a weighted-utilitarian social choice. At equal
weights it collapses to (A).

### (C) Nash social welfare — `W = Πⱼ uⱼ` (equivalently `Σⱼ log uⱼ`)
The **Nash bargaining solution** between trader and LP. Scale-invariant (immune to
re-denominating one agent's payoff), symmetric, Pareto, and IIA — Nash's theorem
makes it the *unique* such bargaining solution. Economically it is the canonical
**fair fee-/surplus-split** rule: it refuses corner solutions that wipe out either
side, so it naturally bounds `η` away from the extremes that starve LPs or traders.
*Property proved:* `log` turns the product into the additive log form.

### (D) Egalitarian / Rawlsian max-min — `W = minⱼ uⱼ`
Maximize the **worst-off** agent. Here that typically means protecting the LP against
adverse selection / worst-case tick, i.e. choosing `δᵢ` and `η` for **robustness**
rather than peak efficiency. Always satisfies `min ≤ mean`, so it is the
inequality-averse extreme.
*Property proved:* `minⱼ uⱼ ≤ (1/m)·Σⱼ uⱼ` (Rawls ≤ utilitarian-mean).

### (E) Atkinson / isoelastic family — `W_ρ = Σⱼ uⱼ^{1−ρ}/(1−ρ)`
A **one-parameter inequality-aversion dial** `ρ ≥ 0` that *interpolates the three
above*: `ρ → 0` is utilitarian (A), `ρ → 1` is Nash (C), `ρ → ∞` is Rawlsian (D).
This is especially natural in *this* repo because **it is the same CES / Bregman
form already used for the pricing kernel** (`pi_eta_trader`, exponent
`1/(1−η)`): the welfare aggregator over agents and the price aggregator over reserves
share one functional family, so a single curvature parameter can govern both. Lets
governance pick one interpretable knob for "how egalitarian."

### (F) Mean–variance (efficiency minus risk) — `W = E[surplus] − γ·σ`
Use the model's own dispersion object: `σ = sigma_xs` (cross-section variance of the
visited ticks) or `sigma_realized`. Then `W = expected fees − γ·sigma_xs` directly
trades **expected throughput against realized-variance exposure**, with `γ` the risk
aversion. Choosing `δᵢ` to shrink `sigma_xs` is exactly slippage-variance control;
`γ = 0` recovers the risk-neutral utilitarian objective.
*Property proved:* `W ≤ E[surplus]` whenever `γ, σ ≥ 0` (risk strictly costs welfare).

### (G) Ramsey / optimal-fee (revenue subject to participation)
`max protocol revenue s.t. LP-IR and trader-IR (uⱼ ≥ 0)`. The
mechanism-design reading: pick `(δᵢ, η)` to maximize captured spread **subject to
both sides choosing to participate**. Natural when the protocol is a revenue-seeking
intermediary rather than a neutral welfare maximizer.

### (H) Median-voter / Condorcet over the discrete tick menu
Because `δᵢ` lives on a finite admissible grid and each agent has an **ideal
granularity** (small traders want fine ticks for low slippage; LPs want coarse ticks
to dampen rebalancing), preferences over `δᵢ` are **single-peaked**. The
median-voter theorem then makes the **median ideal tick** the Condorcet winner — a
*strategy-proof* social choice that needs no cardinal utilities at all. This is the
most "social-choice-theory-proper" option for `δᵢ`.

### (I) Pareto frontier + Kalai–Smorodinsky (vector, not scalar)
Instead of collapsing to one number, trace the **Pareto-efficient `(δᵢ, η)`
frontier** of trader-vs-LP welfare and select the **Kalai–Smorodinsky** point
(equal proportional gains relative to each side's ideal). Useful when governance
wants the trade-off curve made explicit before committing to weights.

---

## 3. Which axioms pin down which choice (quick guide)

| desired axiom | forces / favors |
|---|---|
| additivity / separability + Pareto | **(A)/(B) utilitarian** (Harsanyi) |
| scale-invariance + symmetry + IIA | **(C) Nash** |
| maximal inequality aversion | **(D) Rawlsian** |
| one tunable inequality-aversion knob | **(E) Atkinson — reuses the model's `η`-CES form** |
| explicit risk pricing | **(F) mean–variance on `sigma_xs`** |
| revenue + participation constraints | **(G) Ramsey** |
| ordinal prefs, strategy-proofness, discrete `δᵢ` | **(H) median-voter / Condorcet** |

---

## 4. Recommendation

* For the **continuous `η`** dial, the **Atkinson / `η`-CES welfare (E)** is the most
  natural and elegant here: it reuses the Bregman family already proved out in
  `CESLongVolPayoff.lean`, gives one interpretable curvature knob, and contains
  utilitarian, Nash and Rawlsian as special cases.
* For the **discrete `δᵢ`** menu, the **median-voter / Condorcet rule (H)** is the
  cleanest *social-choice-theoretic* answer (single-peaked ⇒ Condorcet winner exists
  and is strategy-proof), with **weighted-utilitarian (B)** as the cardinal,
  token-weighted-voting counterpart.
* If a single scalar objective is wanted across both parameters, **mean–variance (F)**
  is the most directly implementable, because its risk term `sigma_xs` is already a
  first-class object in `eta.lean`.

See `exp/SocialChoiceParameters.lean` for the formal definitions and the proved
structural properties referenced above (Pareto monotonicity of utilitarian,
weighted = utilitarian at equal weights, Rawls ≤ mean, Nash log-form, mean–variance
risk penalty, and existence of a utilitarian-optimal tick over a finite menu).

---

## 5. Contrarian / inverse objectives: the zero-sum case `π⁻ = −π⁺`

*Refinement: which of these social-choice functions make sense when we optimize for
the **contrarian / inverse** objectives carried by `π⁺` (long-vol trader) and `π⁻`
(LP / short-vol)?*

The repo already proves the two payoffs are **exact opposites**:
`pi_minus_eta = −pi_plus_eta`
(`EtaLiquidityPayoff.pi_minus_eta_eq_neg_pi_trader_half`). So the trader and the LP
play a **zero-sum game**: every unit of slippage the trader extracts is a unit the
LP loses. Writing the profile as `(t, −t)` with `t := π⁺`, this single fact
reshapes the menu of sensible welfare functionals. All of the following are
**proved** in `exp/SocialChoiceParameters.lean` (section *"Contrarian / inverse
objectives"*).

### What breaks

* **Utilitarian collapses (A).** `W_util (t, −t) = 0` (`W_util_zero_sum`): there are
  no aggregate gains from trade to maximize, so the efficiency planner is
  *indifferent* to `(δᵢ, η)`. It cannot be the objective for opposed sides.
* **Weighted utilitarian only picks a winner (B).** `W_wutil [α, 1−α] (t, −t) =
  (2α−1)·t` (`W_wutil_zero_sum`): the only thing the weight does is choose *whom to
  favour* (sign of `2α−1`); the impartial `α = 1/2` again gives `0`. So a partisan
  planner sets `α ≠ 1/2` and then drives `t` to its extreme — a **maximin /
  exploitation** objective, not a compromise.

### What survives, and what it selects

For opposed objectives the *impartial* and *fairness* functionals all become
**conflict-minimizing**, and they agree on the optimum:

* **Conflict magnitude / variance (the natural impartial objective).** Define
  `C(π⁺) = (π⁺)² = π⁺·(−π⁻)` (`conflict`). It is `≥ 0` and `= 0` iff `π⁺ = 0`
  (`conflict_nonneg`, `conflict_eq_zero_iff`). Minimizing it is exactly minimizing
  the realized squared slippage `sigma_xs` — the only scalar that is symmetric in
  the two sides yet not identically zero. **This is the most economically natural
  contrarian objective**: pick `(δᵢ, η)` to damp the zero-sum transfer.
* **Nash bargaining (C).** `W_nash t (−t) = −t² ≤ 0`, maximized (`= 0`) **iff**
  `t = 0` (`W_nash_zero_sum`, `W_nash_zero_sum_le`, `W_nash_zero_sum_eq_zero_iff`).
  Nash bargaining over opposed payoffs therefore selects the **zero-conflict
  point**.
* **Egalitarian / Rawlsian (D).** `W_egal t (−t) = −|t| ≤ 0` (`W_egal_zero_sum`,
  `W_egal_zero_sum_le`): maximizing the worst-off side again drives `π⁺ → 0`.
* **Minimax / von Neumann value.** The LP-protecting planner solves
  `max_{δ} min(−t(δ)) = min_{δ} t(δ)` — the value of the zero-sum game — which is
  well-posed over any finite tick menu (`exists_minimax_tick`).

### The punchline (with an exact tie to this repo)

For contrarian/inverse objectives the **utilitarian sum is useless**, weighted
utilitarian is just **side-picking / exploitation (maximin)**, and *every*
impartial-or-fair functional — conflict-magnitude, Nash, Rawlsian, minimax —
coincides on the **zero-conflict point `π⁺ = 0`**. In this model that point is not
abstract: it is exactly the **zero-slippage tick spacing `Δᵢ⋆`** proved out in
`eta.pi_trader_half_zero_at_deltaI_star`. So:

* **If the protocol is a neutral referee** between long- and short-vol, the natural
  social choice is **minimize `sigma_xs` (⇔ maximize Nash / Rawls)**, landing on
  `δᵢ = Δᵢ⋆` and a balanced two-sided market.
* **If the protocol deliberately favours one vol-side** (e.g. wants to subsidize
  long-vol liquidity provision), it uses **weighted utilitarian with `α ≠ 1/2`**,
  i.e. a partisan/maximin objective, and accepts a nonzero `π⁺` of the chosen sign.
* **A robust designer** uses the **minimax value** to bound the worst-case transfer
  the disadvantaged side can suffer across the admissible `(δᵢ, η)` menu.

A second, non-zero-sum reading of "contrarian objectives" is to treat long-vol and
short-vol as two *products* and aim for a balanced **two-sided market**: maximize
`min(turnover₊, turnover₋)` (an egalitarian over participation, not over P&L). That
keeps both vol-sides liquid rather than nulling their P&L, and is the right framing
if the goal is market *depth* on both sides instead of fairness of the transfer.
