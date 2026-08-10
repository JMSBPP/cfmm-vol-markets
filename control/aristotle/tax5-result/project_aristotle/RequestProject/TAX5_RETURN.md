# Return for `TAX5_ADDENDUM.md` (M33–M35)

One new module, `#print axioms`-clean (`propext`, `Classical.choice`, `Quot.sound` only)
and free of `sorry`:

* `RequestProject/MevShockInput.lean` — namespace `MevTaxShock` — **M33–M35**
  (Theorems 45–47).

`MevTaxControl.H1_dLbar_dpiPhi_pos`, `MevTaxControl.H2_dnu_dlamMEV_pos` and
`MevTaxChannels.ScaleHomogeneous` are used **by name as typed hypotheses only**; none is
discharged. Nothing already proved in `MevTaxControl.lean`, `MevTaxProgram.lean`,
`MevLVRCancellation.lean`, `MevChannelClosure.lean` or `MevReturnsReduction.lean` is
redone; those results are cited by declaration name and file.

**Ban 4 (the `dphidnu` slot).** Every claim below that touches the gate uses the **bare**
`∂φ_X/∂ν` slot of `MevTaxProgram.totalDeriv` / `MevTaxProgram.pathGate`, the one fixed by
`MevTaxProgram.hasDerivAt_phiTot`; the monoid Jacobian `(1-φ_M)(1-τ_MEV)` is written out
separately wherever it appears (`Theorem47_shared_driver_leaves_no_root`,
`Theorem47_loop_law_is_vacuous`, `Theorem47_single_channel_root_is_not_a_root`).
`SRC` Convention 9's **composed** reading is not used anywhere in this bundle.

---

## The model (`MevShockInput.lean`, §"the price-impact response model")

`DOC` Definition 14 declares the price-impact elasticity `ε_{p/X}` an observable. Write
`a = |ε_{p/X}| > 0`. Reserves along the trading curve, parameterized by the marginal price
`p_φ`:

```
Q_X(p) = R p^{-1/a},   Q_M(p) = R p^{1/a}
```

* `reserveX_constant_elasticity` — the model realizes the declared observable exactly:
  `Δ log p = -a · Δ log Q_X`.
* `liquidityUnit` — the pool capital in liquidity units, `φ_{(1/2,0)}(i_K; 0, L)`, is the
  scale `R = L̄`, the same at every price.
* At Rule 5 (`ruleFive_exponent`) `a = 2`, `κ_φ = 1/2`: the model **is** the balanced
  Cobb–Douglas curve. Away from `a = 2` it is the leading-order constant price-impact
  reading of Definition 14, not a CES level set — stated, not hidden.

A relative shock `s = Δp/p` sends the external price to `p(1+s)`; the arbitrageur stops at
the near edge of the fee band, i.e. at `p·u` with

```
u = bandRatio s φ = (1+s)(1-φ),      engaged  ⟺  u > 1  ⟺  s > φ/(1-φ)
```

(`engaged_iff`) — the same "shock against band" comparison `DOC` Definition 21 already
makes with `σ` against `φ√(2/Δt)`.

---

## M33 — Theorem 45. **HOLDS, and `g` is explicit**

| claim | verdict | declaration |
|---|---|---|
| `ΔQ = L̄ · g(Δp/p, φ, κ_φ)` and hence `ν = g(Δp/p, φ, κ_φ)` | **HOLDS** | `Theorem45_shock_driven_utilization` |
| `g` written out in the stated arguments | **explicit** | same, conjunct 3 |
| consistency with `MevTaxChannels.Theorem39_arb_side_does_not_close` | **CONFIRMS it** | `Theorem45_consistency_with_Theorem39` |
| a benign factorization of the same shape | **red flag: it *is* the missing elasticity** | `Theorem45_benign_factorization_is_a_demand_elasticity` |

**`g`, explicitly.** With `u = (1+s)(1-φ)` and `m = (1-κ_φ)/(4κ_φ) = 1/(2|ε_{p/X}|)`
(`expOfCurv_curvOfImpact`),

```
g(s, φ, κ_φ)  =  | u^m − u^{−m} | ,        ν = g,        ΔQ = L̄ · g
```

At Rule 5 (`κ_φ = 1/2`) this is `|u^{1/4} − u^{−1/4}|`. The core algebraic identity is
`legs_product`: the **signed** product of the two legs is exactly `−(L̄(u^m − u^{−m}))²`,
whence Rule 5's geometric mean on the unsigned legs is `L̄·g` (`varphi_unsigned_legs`).
`g` is even in `log u` (`gOfRatio_inv`), so up- and down-shocks of equal log size give the
same utilization; only the engaged branch `u > 1` is used for derivatives.

**The mandatory consistency proof.** `Theorem45_consistency_with_Theorem39` proves three
things about the same object `shockArbFlow S s φ Δt a = S · g`:

1. it is `MevTaxChannels.ScaleHomogeneous` — the hypothesis of bundle 3's refutation,
   satisfied *because* `L̄` is an explicit factor;
2. it does **not** `MevTaxChannels.ClosesInObservables` — the fee response is nonzero on
   the engaged branch (`hasDerivAt_gOfRatio_phi`, `dgOfRatio_phi_neg`), so
   `MevTaxChannels.Theorem39_arb_side_does_not_close` applies and forbids closure;
3. the **ratio** `ΔQ/L̄` closes: one function of `(s, φ, Δt, ε_{p/X})` for every pool scale.

There is no conflict, and the factorization is not a repair of the refutation: (2) is a
statement about a *quantity* and (3) about a *scale-free ratio*, which is exactly the
dimensional obstruction bundle 3 identified. The missing primitive `L̄` is now written
down rather than absent — that is the whole of the gain. Compare
`MevTaxReturns.Corollary41_ratio_derivative_closes`, which had already located the
controller's need on the ratio side.

**`ε` for the arb half.** `∂ν/∂φ` is a closed form (`hasDerivAt_gOfRatio_phi`) and
strictly negative on the engaged branch (`dgOfRatio_phi_neg`): a larger fee widens the band
and shortens the arbitrageur's trip. With the participation factor included the fee
elasticity is closed and negative (`Theorem47_epsilon_closes`). So **`ε` ceases to be an
empirical primitive for the arb half** — subject to the reading question that M35 settles
below.

**Falsification targets, answered.**

* *A mispricing distribution?* Not needed for `g` itself: the realized shock suffices,
  because the stopping condition is the band edge. A distribution is needed only to convert
  per-event `g` into a per-block expectation — which is precisely the participation factor
  `ℙ_{Δ_ARB}` of Definition 21, already in the model (M35).
* *An arb-capital constraint or competition parameter?* None enters: the response is the
  quantity that clears the band, and it is fixed by the curve.
* *Does the benign component factorize?* **It must not, and a claim that it does supplies
  the banned primitive.** `Theorem45_benign_factorization_is_a_demand_elasticity`: any
  differentiable nonvanishing `B` with `ΔQ^{ben} = L̄·B(Δp/p, φ)` has a log-derivative in
  the shock, and that number *is* the demand elasticity `DOC` `[M8]` records as MISSING
  (`MMR` §7.3 eq. (27)). Noise traders have no profit function and no stopping condition,
  so the shock ruling supplies no `B`. **No demand elasticity is supplied here.**

---

## M34 — Theorem 46. **HOLDS for the domain; the SIGN reading is a further ruling**

| claim | verdict | declaration |
|---|---|---|
| a shock-induced trade is a swap: both legs nonzero, opposite signs | **HOLDS** | `Theorem46_shock_flow_is_two_legged` |
| the one-sided configuration is unreachable | **HOLDS** — the legs vanish *together* | `Theorem46_one_sided_is_unreachable` |
| `ν` is well defined on shock-induced flow | **only under the UNSIGNED reading** | `Theorem46_sign_reading` |
| `Theorem 38(a)` recovers on the reachable domain | **HOLDS** | `Theorem46_recovers_Theorem38a` |

**The signs, precisely.** For any engaged shock (`u ≠ 1`, `u > 0`) the legs are nonzero and
`ΔQ_X · ΔQ_M < 0` — one leg in, one leg out. The only reachable degenerate configuration
is `u = 1`, the shock inside the band, where **both** legs are zero: there is no shock and
no pool at which one leg moves and the other does not. So the witness of
`MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity` — one leg zero, the
other not — is **not reachable from a shock driver**; it is a one-sided *deposit*, not a
swap, and not in the plant's input.

**Which reading makes `ν` well defined — and that this is a ruling, not a consequence.**
`DOC` Rule 5's operative member is the geometric mean, which needs a **nonnegative**
product. Shock-induced legs have a strictly **negative** signed product. Hence
(`Theorem46_sign_reading`):

* on the **signed** legs the geometric mean has no real value; in Lean `Real.sqrt` of the
  negative product is `0`, so `ν = 0` at *every* shock — which reproduces exactly the
  degeneracy 38(a) was refuted by, and with it
  `MevTaxReturns.Corollary40c_one_sided_flow_leaves_no_root`;
* on the **unsigned** legs the product is strictly positive and `ν = g > 0`.

So the input ruling **decides the flow domain but not the sign reading**. It removes the
one-sided domain from `PR-REGION` (`DOC:423`); it does not by itself make `ν` well defined.
Adopting the unsigned (absolute-value) legs is a **second author ruling**, and it is the
one under which everything downstream holds. Under it, the premise of
`MevTaxChannels.Theorem38a_flow_scaling_strictly_increases_nu` is met and 38(a) recovers
with `∂ν/∂ΔQ > 0` (`Theorem46_recovers_Theorem38a`), so `Corollary40c`'s hypothesis is not
met on shock-induced flow.

**Standing `OPEN` narrowed, not closed:** `PR-REGION`'s *domain* half is decided by the
input ruling; its *signedness* half is decided by a further ruling, stated here and named
`UNSIGNED-LEGS`.

---

## M35 — Theorem 47. **The two channels are ONE channel, and BOTH control laws are artifacts**

| claim | verdict | declaration |
|---|---|---|
| routes (i) and (ii) are driven by the same primitive | **HOLDS — they are two summands of one product rule over one edge** | `Theorem47_shared_driver_is_one_edge` |
| route (i) carries a `τ_MEV`-edge that bypasses `φ` | **NO** — the project's own taxed hazard depends on `τ_MEV` only through the per-event composed fee | `Theorem47_no_exogenous_hazard_input` |
| the loop-corrected control law | **VACUOUS — no root at any tax** | `Theorem47_shared_driver_leaves_no_root`, `Theorem47_loop_law_is_vacuous` |
| the single-channel (M28) control law | **the FOC of an inconsistent system** | `Theorem47_single_channel_root_is_not_a_root` |
| a residual independent path through benign flow | **NO — benign flow enters the loop gain `q`, not an input `i`** | `Theorem47_benign_residual_is_not_an_exogenous_path` |
| what the shared driver *does* buy | **`ε` closes and is negative** | `Theorem47_epsilon_closes` |

**The shared object.** Under the shock input the expected utilization of the arb half is

```
ν  =  ℙ_{Δ_ARB}(φ, σ, Δt) · g(Δp/p, φ, κ_φ)
```

— participation (`DOC` Definition 21, `MevOptimization.ptrade`) times per-event
utilization (Theorem 45). Both factors are functions of the **same** primitive, the shock,
and of the fee. The chain rule then gives

```
∂ν/∂τ_MEV  =  [ (∂ℙ/∂φ)·g  +  ℙ·(∂g/∂φ) ] · ∂φ/∂τ_MEV
```

(`Theorem47_shared_driver_is_one_edge`): the hazard term and the flow term are the two
summands of **one product rule**, multiplied by the **same** `∂φ/∂τ_MEV`. They are not two
independent inputs, and `MevTaxChannels.Theorem38_two_routes_close_a_loop`'s "route (i) ⊥
route (ii)" is a reformulation, not a fork.

**Route (i) has no bypass.** This is not only a modelling reading: the project's own taxed
hazard `MevTaxControl.mevMultiTaxed` — the object behind
`MevTaxControl.Theorem32_hazard_strictAntiOn_tau` — is a function of the per-event composed
fee alone, so two taxes producing the same fee at every event produce the same hazard
(`Theorem47_no_exogenous_hazard_input`). The exogenous input `i` of
`MevTaxReturns.Theorem40d_loop_correction_removes_epsilon` is therefore `0`.

**Consequence 1: the loop law is vacuous.** With `i = 0` the loop system reads
`N = q·P` and

```
P · (1 − q(1-φ_M)(1-τ_MEV)(∂φ_X/∂ν))  =  (1-φ_M)(1-φ_X)  ≠  0
```

so `P ≠ 0` at **every** tax, whatever the sign or magnitude of `q` — including the resonant
case where the loop gain reaches `1`, where the linear system has no solution at all, which
is again not a root (`Theorem47_shared_driver_leaves_no_root`, conjunct 2; the same verdict
obtained by *invoking* `Theorem40d`'s second clause is `Theorem47_loop_law_is_vacuous`).
Under the M26 signs (`q ≤ 0`, `0 < ∂φ_X/∂ν`) more holds: `∂π̂^σ/∂τ_MEV > 0` on the whole
admissible interval `[0,1]`. There is then **no interior stationary point at all**, and the
constrained optimum is a boundary point of `[0,1]`; *which* boundary depends on the
objective reading (`DOC` Definition 36's squared derivative and the payoff reading of
`MevTaxReturns.Theorem44_root_is_a_minimum_of_piHat` do not point the same way) and is not
decided here.

**Consequence 2: the single-channel law is not the survivor either.** M28's
`MevTaxReturns.reducedLaw` computes the flow response with the **partial** fee derivative
`(1-φ_M)(1-φ_X)` while using the gate response `∂φ_X/∂ν` in the FOC itself. Those are the
same gate; omitting it in one place and using it in the other is inconsistent. A witness
(`Theorem47_single_channel_root_is_not_a_root`, `φ_M = 0`, `φ_X = 1/2`, `∂φ_X/∂ν = 1`,
`q = -1`, `A = 1`): the single-channel FOC vanishes at `τ_MEV = 0`, while the shared-driver
system has `P = 1/4 ≠ 0` there.

**Verdict on the fork: BOTH readings are artifacts of treating a shared driver as two
inputs.** One is empty (no root), the other is the FOC of a system that is not the plant.
The honest statement of the tax program under a shock input is that
`∂π̂^σ/∂τ_MEV` does not vanish on `[0,1]` and the optimum is a corner.

**The falsification target: benign flow.** Benign flow is *not* shock-driven and has no
profit function, so the tax reaches it **only through the fee it pays**. Its response
`B'(φ)` is therefore an addend of the loop gain `q`, not an exogenous input `i`
(`Theorem47_benign_residual_is_not_an_exogenous_path`). Answering the question as posed:
**the loop correction does not apply to that residual alone** — the residual never produces
a separate path, it only shifts `q`, and `q` enters solely the denominator `1 − loop`. Its
"gain" is exactly `1/(1 − q(1-φ_M)(1-τ_MEV)(∂φ_X/∂ν))` with `q = q_arb + B'`, a rescaling of
a nonvanishing `P` and never a root. `B'` is left free of either sign: **no demand
elasticity is supplied.**

**What the shared driver buys.** `ε = (φ/ν)·∂ν/∂φ` is a closed form in
`(Δp/p, φ, σ, Δt, κ_φ)` with no pool-level datum and is **strictly negative** for `φ > 0`
(`Theorem47_epsilon_closes`): both factors of `ν` fall in the fee. So, *if* one nevertheless
operates the single-channel reading, `MevTaxReturns.Theorem43_threshold_elasticity`'s
threshold becomes a computed number and `MevTaxReturns.Theorem44_O2_closes` runs with a
computed `ε < 0` rather than an empirical one. That is a conditional gain, and the
condition is the reading refuted in the previous paragraph.

### O2, load-bearing since Phase 5 — where it now stands

`MevTaxReturns.Theorem44_O2_closes` was conditional on (1) `∂ν/∂φ = νε/φ`, (2) the loop not
being applied, (3) `K > 0`, (4) at least one leg charging. This bundle settles (1) and (2)
in opposite directions:

* (1) is **granted** on shock-induced flow under the `UNSIGNED-LEGS` ruling: `ν ∝ ΔQ`
  holds, `∂ν/∂ΔQ > 0` (`Theorem46_recovers_Theorem38a`), and `ε` is now computed and
  negative (`Theorem47_epsilon_closes`);
* (2) is **not available**: the loop is not an optional refinement under a shared driver,
  it is the plant, and with `i = 0` there is no root to classify.

So **O2 does not close in the direction the summary hoped**. Its resolution under the shock
input is: *there is no interior stationary point to be a minimum or a maximum of*
(`Theorem47_shared_driver_leaves_no_root`). `MevTaxReturns.Theorem44_root_is_a_minimum_of_piHat`
and `Theorem44_O2_closes` remain correct statements about the single-channel model; that
model is the one refuted here. Recorded as **O2-RESOLVED-EMPTY**, not as O2 closed.

---

## Standing `OPEN` items after this bundle

* **`UNSIGNED-LEGS`** (new) — the sign reading of Rule 5's geometric mean on shock-induced
  flow. `Theorem46_sign_reading` shows only the unsigned reading makes `ν` well defined;
  choosing it is an author ruling, not a consequence of the input ruling.
* **The corner optimum** — with `∂π̂^σ/∂τ_MEV > 0` throughout `[0,1]`
  (`Theorem47_shared_driver_leaves_no_root`, conjunct 4), the design question becomes which
  boundary of `[0,1]` the program selects, and whether `DOC` Definition 36 is the right
  objective when no root exists. Not addressed.
* **The curvature model away from Rule 5** — `reserveX`/`reserveM` realize a constant
  price-impact elasticity exactly; for `a ≠ 2` they are not a CES level set of `DOC`
  Definition 13. At Rule 5 (`a = 2`) the two coincide, which is the case in force.
* **`∂τ*/∂γ_R`**, and **the `dphidnu` slot's name** in
  `MevTaxProgram.Proposition16_corrected_law` / `SRC` Proposition 13 — carried over from
  bundle 4, untouched here.
