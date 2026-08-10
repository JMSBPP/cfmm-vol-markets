# Return for `TAX6_ADDENDUM.md` (M36–M40, Theorems 48–52)

Two new modules, both `#print axioms`-clean (`propext`, `Classical.choice`, `Quot.sound`
only) and free of `sorry`:

* `RequestProject/MevTransactional.lean` — namespace `MevTaxTransactional` — the
  primitives and **M36 (Theorem 48)**.
* `RequestProject/MevTransactionalOptimum.lean` — same namespace — **M37–M40
  (Theorems 49–52)**.

Nothing already proved in `MevTaxControl.lean`, `MevTaxProgram.lean`,
`MevLVRCancellation.lean`, `MevChannelClosure.lean`, `MevReturnsReduction.lean` or
`MevShockInput.lean` is redone; those results are used by declaration name
(`MevTaxReturns.Theorem40d_loop_correction_removes_epsilon` is the only one *applied*;
the rest are cited in docstrings).

The four new assumptions are carried exactly as typed objects, never proved and never
estimated:

* **(A-ind)** enters as `IndepFun S Vabs μ` in
  `Theorem48a_block_events_partition` — **the only place independence is used**.
* **(A-tail)** enters as `hazTail al phi = Real.exp (-(al*phi))`; `A_tail_survival`
  grounds it against Mathlib's `expMeasure` (it *is* `ℙ(|V| > φ)` for an exponential
  tail). No estimate of `α` is used or claimed anywhere.
* **(A-size)** enters as the constant `δ` inside `f_LP·δ` (`ntFee`): the *rate* `h(φ)`
  responds to the fee, the size does not.
* **(A-route)** enters as `Kf = fun _ => δ·φ_base` (leg fees only, `dK = 0`) versus the
  counterfactual full routing `Kf = fun f => δ·f` (`dK = δ`). Both readings are carried
  side by side throughout; nothing is assumed about which one the FOC prefers.

Standing bans respected: `π^{transactional}` (`piTransOpp`, `piTransBlock`,
`piTransCond`) is a **trader-side** object, distinct from `π^φ` and `π^varphi`; no
isoelastic demand appears; the elasticity `ε(φ) = φh'/h = -αφ` is **derived**
(`Theorem48_derived_elasticity`), never a primitive.

---

## The model in one line

```
ℙ_arb(φ)   = σ/(σ + cφ),      c = √(2/Δt)          -- pArb, = MevOptimization.ptrade
ℙ_trans(φ) = (1 - ℙ_arb(φ))·h(φ),   h(φ) = ℙ(|V| > φ) = e^{-αφ}
m(φ)       = (1 - ℙ_arb(φ))·h(φ)·f_LP(φ)·δ  -  Lvr·ℙ_arb(φ),  Lvr = σ²Δt/8
```

`m` is the LP PnL drift — **not** the squared-derivative objective that
`MevTaxReturns.Theorem44_objective_reading_does_not_discriminate` already showed cannot
distinguish a minimum from a maximum. The workhorse is the **reduced FOC**

```
m'(φ) = c/(σ+cφ)² · Φ(φ),
Φ(φ)  = K'·h·φ(σ+cφ) + K·(hσ + h'·φ(σ+cφ)) + Lvr·σ          -- focRed
```

(`hasDerivAt_mObj`), and under (A-tail) `Φ = focTail`.

---

## M36 — Theorem 48

| claim | declaration | verdict |
|---|---|---|
| (a) partition, numerically | `Theorem48a_partition` | holds (identity) |
| (a) partition, as events, `1-ℙ_ARB` factorization under (A-ind) | `Theorem48a_block_events_partition` | holds |
| (b) the `NT_FEE` term MMR eq. (27) leaves unspecified | `Theorem48b_block_income_decomposition` | holds |
| derived elasticity `ε(φ) = -αφ` | `Theorem48_derived_elasticity` | holds |
| (c) the comparison, **both ways** | `Theorem48c_complement_marginal_gap` | exact gap |
| (c) which reading is accounting-consistent | `Theorem48c_unconditional_reading_is_not_a_partition` | complement reading |
| (c) what the second channel does to the root | `Theorem48c_complement_adds_a_positive_channel`, `Theorem48c_root_shifts_up` | pushes the root **up** |
| (d) `π^{transactional}` well defined | `Theorem48d_expected_surplus` | `E[(|V|-b)⁺] = e^{-αb}/α` |
| (d) decreasing in `φ` | `Theorem48d_piTransOpp_strictAnti` | holds for `piTransOpp` |
| (d) **as stated** (complement-weighted per block) | `Theorem48d_block_form_is_not_decreasing` | **REFUTED, witness** |
| (d) conditional-on-participation form | `Theorem48d_conditional_form_is_strictly_increasing` | **strictly increasing** |

The (c) comparison, derived both ways:

```
m'_comp(φ) - m'_uncond(φ) = K·(A(φ)h(φ) - ℙ_arb(φ)h'(φ)) - K'·h(φ)ℙ_arb(φ),
A(φ) = σc/(σ+cφ)² = ∂(1-ℙ_arb)/∂φ > 0
```

Under (A-route) (`K' = 0`) and any nonincreasing `h`, this is **strictly positive**: the
complement channel adds marginal value at every `φ > 0`, so the accounting-consistent
root lies strictly to the right of the unconditional one. That answers the addendum's
parenthetical — `(1 - ℙ_ARB)` is increasing in `φ`, and the second channel asks for a
**higher** fee.

The unconditional reading is not admissible accounting: `ℙ_arb + h > 1` at
`σ = c = φ = 1`, `α = 1/2`, so "arb block" and "benign execution" cannot both be block
events without double-counting the arb block's flow.

**(d) is refuted as stated.** The complement-weighted block payoff
`(1-ℙ_arb(φ))·δe^{-αφ}/α` is larger at `φ = 1/2` than at `φ = 1/10` (σ = c = α = δ = 1):
the complement factor increases in `φ` and vanishes at `φ = 0`, dominating the
exponential decay near the left endpoint. The *conditional* form is worse — by
memorylessness the conditional mean residual is `1/α` regardless of the band, so the form
is `(1-ℙ_arb)δ/α`, **strictly increasing**. The object that is both well defined and
strictly decreasing in `φ` is the per-opportunity payoff `piTransOpp = δe^{-αφ}/α`.

---

## M37 — Theorem 49

**The relaxed hypothesis, named:** the premise of
`MevTaxShock.Theorem47_no_exogenous_hazard_input` — *the composed fee is a sufficient
statistic for the tax's effect* — formalized as `FeeSufficient`.

* `Theorem49_full_routing_keeps_fee_sufficiency` — under full routing the premise **holds
  verbatim**, and with it Theorem 47's verdict.
* `Theorem49_no_routing_breaks_fee_sufficiency` — under **(A-route)** it **fails**:
  `(φ_base, τ) = (1/2, 0)` and `(0, 1/2)` give the same composed fee `φ = 1/2` and
  different LP income. This premise, and nothing else, is what M37 relaxes.
* `Theorem49_exogenous_input_admits_a_root` / `Theorem49_root_law_from_loop_theorem` —
  in the loop algebra of `MevTaxChannels.Theorem38_two_routes_close_a_loop`, the input is
  `i ≠ 0`, the FOC `P = 0` is solvable, and the law
  `τ* = 1 + (1-φ_X)/((∂φ_X/∂ν)·i)` comes from
  `MevTaxReturns.Theorem40d_loop_correction_removes_epsilon` — nothing re-derived.
* `Theorem49_extended_model_has_an_interior_root` — with the witness
  (`Δt = 2`, `σ = 1/3`, `α = 10`, `φ_base = 1/100`, `δ = 100`) there is an interior
  `τ* ∈ (0,1)` at which the **total** `τ`-derivative of the LP objective vanishes, with a
  nondegenerate fee path. `Theorem47_shared_driver_leaves_no_root`'s conclusion therefore
  **fails** in the extended model.

---

## M38 — Theorem 50

**(a) The profitability condition `sup m > 0` is REFUTED as an iff, in both
directions**, and replaced by exact threshold laws:

* `Theorem50a_sign_law_noroute` — at an interior stationary point,
  `m(φ*) < 0 ⟺ -h'(φ*)φ* > h(φ*)`, i.e. under (A-tail) `⟺ αφ* > 1`.
* `Theorem50a_sign_law_route` — under full routing the same law with threshold `2`:
  routing the revenue to LPs buys exactly one unit of the threshold.
* `Theorem50a_profitability_is_not_sufficient` — witness `α = 1/2`, `f_LPδ = 10`,
  `σ = c = 1`: `sup m > 0`, yet `m` is **strictly increasing on all of `[0,1)`** — no
  interior maximiser exists (the supremum is approached only at the excluded endpoint).
  This is `arXiv:2606.21769` Prop. 4.1's boundary degeneracy reappearing for small but
  nonzero `α`.
* `Theorem50a_profitability_is_not_necessary` — witness `α = 10`, `f_LPδ = 5`,
  `σ = c = 1`: an interior stationary point exists (`Φ > 0` at `1/10`, `Φ < 0` at `1/5`)
  while `m < 0` at **every** admissible fee. The interior optimum is a loss minimiser.

**(b) The carrier analogue of `φ* > 1/α`:**

* `Theorem50b_carrier_analogue_noroute(_tail)` — under (A-route),
  `αφ*(σ + cφ*) > σ`, equivalently **`αφ* > ℙ_ARB(φ*)`**. The literature's `φ* > 1/α` is
  *weakened*: the arb-deterrence channel pays for part of the fee.
* `Theorem50b_carrier_analogue_route(_tail)` — under counterfactual full routing the
  bound is the literature's own, **`φ* > 1/α`**, exactly.

**(c) The top-up law** — `Theorem50c_top_up_law`:
`τ* = (φ* - φ_base)/(1 - φ_base)`, with `τ* ∈ (0,1) ⟺ φ_base < φ* < 1`, on the monoid
carrier `1-φ = (1-φ_base)(1-τ)` of `MevTaxControl.Theorem29_monoid_path_is_direct`.

**(d) Pro-cyclicality** — `Theorem50d_focRedDsig_pos`: at *any* interior stationary
point, either routing regime, any differentiable `h > 0`,

```
σ(σ+cφ)·∂Φ/∂σ = K h σ cφ + Lvr σ (2σ + 3cφ) > 0,
```

the `K'` terms cancelling identically (`hasDerivAt_focRed_sig` proves this *is* the
`σ`-derivative, with `Lvr = σ²Δt/8` carrying its own `σ`-dependence). With `Φ_φ < 0` at a
maximum, `Theorem50d_procyclicality` gives `dφ*/dσ > 0` and `dτ*/dσ > 0`.

**(e) The corner taxonomy** — `Theorem50e_corner_at_zero` (τ* = 0 when the base fee
already covers `φ*`), `Theorem50e_shutdown_is_loss_minimization` (when `m < 0` at every
admissible fee, the program on `[0,1)` minimizes losses; it is not an optimization of
anything else, and it is stated that way).

**Uniqueness under (A-tail)** is delivered in M40 as
`Theorem52_at_most_two_stationary_points`.

---

## M39 — Theorem 51, the incidence question

Both FOCs are derived and compared **by derivation**; no sign was assumed.

`Theorem51_routing_wedge` is the exact identity:

```
Φ_route(φ) - Φ_noroute(φ) = δ·[ hφ(σ+cφ) + (φ-φ_base)(hσ + h'φ(σ+cφ)) ].
```

Everything M39 asks is read off it:

1. **Does the interior root survive no-routing?** **Yes** —
   `Theorem51a_interior_root_survives_no_routing`. The witness's interior root is a root
   of the *no-routing* objective: it is generated by the benign-attrition channel
   (`h' < 0`) against arb-deterrence, and neither of those depends on where the revenue
   goes. The root does not disappear when the fee-setter does not keep the revenue.
2. **Sign of `τ*_noroute - τ*_route`.** **No unconditional sign exists.** Under (A-tail),
   `Theorem51b_shift_sign_under_threshold`: if `α(φ - φ_base) < 1` the wedge is strictly
   positive, so the routing regime wants **more** tax there,
   `τ*_noroute < τ*_route`. `Theorem51b_no_unconditional_sign` exhibits the reversal:
   at `φ = 9/10` with `α = 10`, `σ = 1/3`, `c = 1`, `φ_base = 1/100`, `δ = 1`, the
   **no-routing** marginal value strictly exceeds the full-routing one. The wedge changes
   sign once `α(φ-φ_base) > 1` — because under full routing the LP-accrued fee is itself
   `δφ`, and the benign attrition it suffers scales with `φ`.
3. **Is there a discontinuous term at `τ = 0`?** — `Theorem51c_wedge_at_zero_tax`. *Within
   a regime*, no: each objective is differentiable in `τ` at `τ = 0`, so `∂m/∂τ` picks up
   no discontinuous term; the first unit of tax destroys benign surplus smoothly.
   *Between the regimes*, yes: at `τ = 0` the two marginal values differ by
   `δ·h(φ_base)·φ_base(σ+cφ_base) > 0` — strictly positive, so the two regimes do not
   paste smoothly even at zero tax. Routing is a discrete change of the objective, not a
   limit of no-routing.

---

## M40 — Theorem 52, second order

* `Theorem52_second_order` — at an interior stationary point,
  `m''(φ*) = (c/(σ+cφ*)²)·Φ'(φ*)` with `Φ'(φ) = -Kαh(φ)q(φ)` and
  `q(φ) = 2σ + 2cφ - ασφ - αcφ²` (`qPoly`, `hasDerivAt_focTail`).
* `Theorem52_strict_local_max` — `q(φ*) > 0 ⇒ m''(φ*) < 0`: strict local maximum
  (and `q(φ*) < 0 ⇒` strict local minimum).
* **Single crossing FAILS, even under (A-tail)** — `Theorem52_single_crossing_fails`:
  the witness `Φ_w` is `+` at `1/100`, `−` at `1/5`, `+` again at `4/5`, so `m` is not
  concave and not single-crossing and has two distinct interior stationary points. Since
  `e^{-αφ}` is log-concave, uniqueness of the *stationary point* already fails inside the
  log-concave class — the witness answers M40's last question without leaving (A-tail).
* **What (A-tail) contributes** — `Theorem52_at_most_two_stationary_points`: at most two
  zeros of `Φ` on `(0,∞)`. Three would force, by Rolle applied twice, two distinct
  positive roots of the concave quadratic `q`, whose product of roots is `-2σ/(αc) < 0`.
  Hence the sign pattern can only be `+,-,+`: at most one interior **local maximiser**,
  the second stationary point being a local minimum.
* **What survives for a general hazard.** Every pointwise law above —
  `Theorem50a_sign_law_noroute`, `Theorem50a_sign_law_route`,
  `Theorem50b_carrier_analogue_noroute`, `Theorem50b_carrier_analogue_route`,
  `Theorem50d_focRedDsig_pos`, `Theorem52_second_order` — is stated for an arbitrary
  differentiable `h` (only `h(φ) > 0` and `h'(φ)` enter). (A-tail) is load-bearing in
  exactly one place: the **counting** of stationary points.

---

## OPEN, with reasons

1. **Global maximiser versus local maximiser.** `Theorem52_at_most_two_stationary_points`
   bounds the interior *local* maximisers by one; it does not locate the *global*
   maximiser of `m` on `[0,1)`, which may sit at the excluded endpoint
   (`Theorem50a_profitability_is_not_sufficient` is exactly that case). A complete
   taxonomy would need the boundary comparison `m(φ*) vs lim_{φ→1} m(φ)`, which depends on
   the carrier convention for `φ = 1` — a modelling choice the addendum does not fix.
   Stated OPEN rather than resolved by narrowing the carrier.
2. **Log-concave `h` beyond (A-tail).** For a general log-concave `h`, `Φ' = -K(h'σ +
   (h'' φ + 2h')(σ+cφ)·…)` is no longer a hazard times a quadratic, and the Rolle argument
   does not close. Since uniqueness already fails *inside* the (A-tail) class, no weaker
   hypothesis can restore it; what remains open is whether some *additional* condition on
   `h` (beyond log-concavity) bounds the stationary points for general `h`.
3. **`α` is unidentified.** Per the register's finding attached to (A-tail), no causal
   estimate of `α` exists. Every `α`-dependent statement here is a conditional law or an
   explicit witness; none is an estimate, and none should be read as one.
