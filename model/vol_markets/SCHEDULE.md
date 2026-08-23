# `SCHEDULE.md` — liquidity, payoff, and the EVM-implementable `ΔQ_M` schedule

Machine-checked backbone: `RequestProject/Flow.lean` (§2–§4), building on
`pos_spec.md` and `tbd.md`. Builds with **no `sorry`**.

## 1. `getLiquidityForAmounts` — `(ΔQ_M, ΔQ_v, p(i), p(i_l), p(i_u)) → (L, i_l, i_u)`

With `s_a = p(i_l)`, `s_b = p(i_u)` the range sqrt-prices (`s_a < s_b`, guaranteed
by `PosSpec.tickPrice_lt`) and `s_p` the current sqrt-price:

* `liquidity0 amt0 s_a s_b = amt0 · (s_a·s_b) / (s_b − s_a)` (`Flow.liquidity0`)
* `liquidity1 amt1 s_a s_b = amt1 / (s_b − s_a)` (`Flow.liquidity1`)
* `getLiquidity s_p s_a s_b amt0 amt1` (`Flow.getLiquidity`) selects the branch:
  * `s_p ≤ s_a`  → `liquidity0 amt0 s_a s_b` (all token0),
  * `s_a < s_p < s_b` → `min(liquidity0 amt0 s_p s_b, liquidity1 amt1 s_a s_p)`,
  * `s_p ≥ s_b`  → `liquidity1 amt1 s_a s_b` (all token1).

Here `amt0 ↔ ΔQ_v`, `amt1 ↔ ΔQ_M`. Facts:

* `liquidity1_nonneg`, `liquidity0_nonneg` : `L ≥ 0` for nonnegative amounts and a
  proper range (`s_a < s_b`, `s_a > 0`);
* `liquidity1_mono` : `L` is monotone in the token1 amount `ΔQ_M`;
* `liquidity1_eq_div` : in the token1 branch, `L = ΔQ_M / (p(i_u) − p(i_l))`.

This is the nominal structure `L` that will bear the terminal payoff.

## 2. Payoff

* Terminal: `π(σ̄) = L·(p(i_u) − p(i_l))` (`Flow.terminalPayoff`);
  `terminalPayoff_nonneg` gives `π ≥ 0` for `L ≥ 0` and `p(i_l) ≤ p(i_u)`.
* Trajectory: `π(σ̄; σ(t), t) = L·(p(i(σ̄)) − p(σ(t)))` (`Flow.trajPayoff`).

## 3. Reducing the objective to a linear program in `ΔQ_M`

Fix `p_risk` (exogenous, constant in `t`). Use the token1 liquidity from §1:
`L = ΔQ_M / w` with `w := p(i_u) − p(i_l) > 0`. Writing the control `x := ΔQ_M`
and `k := p(i(σ̄)) − p(σ(t))`,

  `π(x) = (k / w)·x`   (`Flow.trajPayoff_control`).

This is **linear in the control** `x`, over the admissible interval `x ∈ [0, X]`
with `X = Q_M^Σ` (from `tbd.md`, `deltaShares_admissible_iff`).

## 4. Optimal (bang-bang) schedule

`min_{x∈[0,X]} (k/w)·x` is attained at an endpoint:

* `k < 0`  (i.e. `p(σ(t)) > p(i(σ̄))`, realized vol price above target): minimize
  by **`x = X = Q_M^Σ`** — `Flow.schedule_min_high`.
* `k ≥ 0`  (realized vol price at/below target): minimize by **`x = 0`**, value `0`
  — `Flow.schedule_min_low`.

The complete statement, including the optimal value, is
`Flow.schedule_isLeast`:

  `IsLeast ((fun x => (k/w)·x) '' [0, X]) (min 0 ((k/w)·X))`.

### EVM-implementable schedule for `ΔQ_M(t)`

At each time `t`, read `σ(t)`, form `p(σ(t))` via `TickMath`, compare with the
fixed target price `p(i(σ̄))`, and set

```
w = p(i_u) - p(i_l)                 // > 0 by construction (PosSpec.tickPrice_lt)
X = Q_M_total                       // admissible ceiling (deltaShares_admissible_iff)
if p_sigma_t > p_target:            // k < 0  → schedule_min_high
    dQM(t) = X                      // deposit the full admissible amount
else:                               // k ≥ 0  → schedule_min_low
    dQM(t) = 0                      // deposit nothing
dQv(t) = mulDiv(dQM(t), 2^96, p_risk)   // tbd.md, round down
L(t)   = mulDiv(dQM(t), 2^96, w)        // Flow.liquidity1_eq_div, token1 branch
```

* The rule is a **threshold/bang-bang** controller: a single price comparison
  `p(σ(t)) ⋛ p(i(σ̄))` selects the endpoint. No optimizer, no iteration — cheapest
  possible on-chain form, and provably optimal (`schedule_isLeast`).
* All arithmetic is division-free except the two `mulDiv`s for `ΔQ_v` and `L`,
  both rounded down (conservative for the deposits backing shares).
* Admissibility is enforced by the ceiling `X = Q_M^Σ` (money-side test, a plain
  comparison), consistent with the state bounds proved in
  `Main.admissible_state_bounds`.
* Representations follow `pos_spec.md` (prices Q64.96 / X96) and `tbd.md`
  (`ΔQ_M`, `ΔQ_v` in RAY, `p_risk` Q64.96, `L` `uint128`).

## Data-flow summary

```
(σ̄, #_σ̄, s_v) --pos_spec--> (p(i), p(i_l), p(i_u))
(ΔQ_M, p_risk) --tbd------> (ΔQ_M, ΔQ_v)
(ΔQ_M, ΔQ_v, p(i), p(i_l), p(i_u)) --getLiquidityForAmounts--> (L, i_l, i_u)
π(σ̄; σ(t), t) = L·(p(i(σ̄)) − p(σ(t)))
min over ΔQ_M(t)  ==>  bang-bang schedule above (schedule_isLeast)
```
