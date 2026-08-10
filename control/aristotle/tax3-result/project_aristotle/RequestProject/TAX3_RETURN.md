# Return for `TAX3_ADDENDUM.md` (M25–M27)

Two new modules, both `#print axioms`-clean (`propext`, `Classical.choice`,
`Quot.sound` only) and free of `sorry`:

* `RequestProject/MevLVRCancellation.lean` — namespace `MevTaxLVR` — **M25**;
* `RequestProject/MevChannelClosure.lean` — namespace `MevTaxChannels` — **M26**, **M27**.

`H1_dLbar_dpiPhi_pos` and `H2_dnu_dlamMEV_pos` (`MevTaxControl.lean`) are used **by
name as typed hypotheses only** and are never discharged. One further typed
hypothesis is introduced and named as such: `MevTaxChannels.ScaleHomogeneous`
(M27), whose ground is the 1-homogeneity of `DOC` Definition 13's CES family.

---

## M25 — Theorem 37 + Corollary 37

| claim | verdict | declaration |
|---|---|---|
| the factorization `∂π̂^σ/∂τ = K·[…]` | **HOLDS** under the composed-fee reading of `∂φ/∂ν` | `MevTaxLVR.Theorem37_LVR_cancellation` |
| the same display read with `DOC` Definition 18's bare `∂φ_X/∂ν` | **REFUTED**, witness given | `MevTaxLVR.Theorem37_literal_bracket_refuted` |
| `K > 0` under (H1), `π^l > 0`, `π^LVR > 0`, `ℙ_{Δ_ARB}` strictly decreasing in `φ` | **HOLDS** | `MevTaxLVR.Theorem37_K_pos`, `MevTaxLVR.priceAxisSum_pos_of_H1` |
| is `ℙ_{Δ_ARB}` strictly decreasing in `φ` on the whole admissible domain? | **NO — only where `σ > 0`** | `MevTaxLVR.dptrade_dphi_neg`, `MevTaxLVR.ptrade_sigma_zero_const` |
| Corollary 37: the zero set is unchanged, `Proposition 13`'s root invariant | **HOLDS for `K ≠ 0`** | `MevTaxLVR.Corollary37_root_invariance` |
| Corollary 37 at `K = 0` (the `σ = 0` slice) | **FAILS**, witness given | `MevTaxLVR.Corollary37_root_invariance_fails_at_K_zero` |

**Reading.** The LVR/net-profit channel enters `∂π̂^σ/∂τ_MEV` only through the
scalar `K`; the bracket is *identically* the two-path sum already proved as
`MevTaxProgram.totalDeriv` (`MevTaxProgram.Theorem33_path_decomposition`), with
(P-direct) the monoid path of `MevTaxControl.Theorem29_monoid_path_is_direct`.
On `σ > 0` the proposal to restore an interior optimum by carrying `π^LVR` is
**futile by construction**. The only place it changes anything is the degenerate
`σ = 0` slice, where `K = 0` kills the objective's tax-response altogether — not
an interior optimum but the loss of the FOC.

The guarded domain lines of `Proposition 13` (`τ* < 1`; the `τ* > 0` iff; the
`|·|` form) are restated in `Corollary37_root_invariance` **only** under
`0 < ∂φ/∂ν`, `∂ν/∂τ_MEV < 0`, `φ_X < 1`, by direct appeal to
`MevTaxProgram.Proposition16_corrected_law`.

---

## M26 — Theorem 38 (a)–(d)

| claim | verdict | declaration |
|---|---|---|
| (a) `∂ν/∂ΔQ > 0` as a universal statement | **REFUTED** — one-sided flow gives `0` | `MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity` |
| (a) on a scaling ray with both legs strictly positive | **HOLDS** | `MevTaxChannels.Theorem38a_flow_scaling_strictly_increases_nu` |
| (a) which property does it need, and does the CES family supply it? | 1-homogeneity **plus** strict positivity at the flow direction; supplied in the open orthant for every `ε_{X/M}`, on the boundary only for `ε_{X/M} > 0` — and Rule 5's operative member is `ε_{X/M} = 0` | `MevTaxChannels.Theorem38a_boundary_behaviour_is_epsilon_dependent` |
| (b) route (ii) gives `∂ν/∂τ_MEV < 0` | **HOLDS** | `MevTaxChannels.Theorem38b_route_two_sign` |
| (c) the routes agree in sign | **HOLDS** | `MevTaxChannels.Theorem38c_routes_agree_in_sign` |
| (c) what route (i) delivers from the cited results alone | only `≤ 0` | `MevTaxChannels.Theorem38c_route_one_from_H2`, `MevTaxChannels.Theorem38c_hazard_route_only_nonpos` |
| (d) route (ii)'s sign does not require (H2) | **HOLDS**, and the replacement is **logically independent** of (H2), not weaker | `MevTaxChannels.Theorem38d_replacement_is_independent_of_H2` |
| decomposition or independent path? is the total the sum? | **independent paths; the total is NOT the plain sum** | `MevTaxChannels.Theorem38_two_routes_close_a_loop` |

**What replaces (H2).** `MevTaxChannels.RouteIIPremise` — `∂ν/∂ΔQ > 0` together
with downward-sloping demand `∂ΔQ/∂φ < 0`. Neither premise set implies the
other, so the trade is **not** an unconditional weakening: the controller's
direction is bought at the price of a demand slope on **total** flow, whose
benign component `DOC`'s `[M8]` records as absent (*NO DEMAND ELASTICITY*, the
`OPT_FEES` layer). Route (ii) does, however, avoid `λ_MEV` entirely, hence the
interblock-vs-swap two-clock conflict in `λ_ARB`'s summand.

**The loop.** Running both channels at once closes `φ → ΔQ → ν → φ`. The pair
`(∂φ_total/∂τ, ∂ν/∂τ)` then solves a linear system whose solution is
`naive/(1 − loop)` with `loop = (∂ν/∂ΔQ)(∂ΔQ/∂φ)(1−φ_M)(1−τ)(∂φ_X/∂ν)`. Under
the M26 signs `loop < 0`, so `1 − loop > 1`: **the sign survives, the plain sum
overstates the magnitude.** That is the double count, quantified.

---

## M27 — Theorem 39

**REFUTED.** `∂ΔQ^{ARB}/∂φ` does not close in `(σ, φ, Δt, ε_{p/X})`:
`MevTaxChannels.Theorem39_arb_side_does_not_close` shows that, for any arb-flow
model that is 1-homogeneous in the pool scale, such a closed form forces the fee
response to vanish identically; `MevTaxChannels.Theorem39_missing_primitive_is_the_pool_scale`
gives the same statement for every leading-order product-shape model together
with a witness.

**The missing primitive, named: the POOL SCALE** — the reserve level `L`,
equivalently the portfolio value `π^{varphi}` (`DOC` Definition 25; distinct from
`π^φ`, the `φ`/`varphi` split being binding). `∂ΔQ^{ARB}/∂φ` is a **quantity**;
`σ`, `φ`, `Δt` and the elasticity `ε_{p/X}` (`DOC` Definition 14: an *observable*,
and an elasticity) are all **scale-free**. No function of the four can carry a
level. The obstruction is dimensional, so **neither** of `[M8]`'s LEADING ORDER
and QUASI-STATIC caveats is what blocks closure — they are not the binding
constraint here.

**What does close.** The participation probability `ℙ_{Δ_ARB}` and its
fee-derivative, in `(σ, φ, Δt)` alone (`MevTaxChannels.Theorem39_participation_closes`),
and the fee **elasticity** of arb flow, which is scale-free
(`MevTaxChannels.Theorem39_elasticity_closes`). So the arbitrage side of the
controller is derivable in observables **up to one multiplicative pool-level
constant** — a quantity the pool already measures, unlike `Ḡ`. The empirical
burden therefore collapses to *benign flow plus one pool-level observable*, not
to benign flow alone.

---

## OPEN, with reasons

1. **PR-REGION (`DOC:423`) decides M26(a).** The flow domain — signedness of the
   legs and the admissibility set — is undefined. Under an unsigned/positive
   two-leg reading 38(a) holds along scaling rays; under a one-sided reading it
   is false. Nothing in the tree licenses either; the ruling is the author's.
2. **`∂ΔQ/∂φ` itself.** Route (ii)'s premise is not derived here for the benign
   half, and by `DOC`'s `[M8]` the model has no demand elasticity to derive it
   from. This is stated as irreducibly empirical and left there, per the spec.
3. **Second order.** Nothing here upgrades
   `MevTaxProgram.Proposition15_level_reading_second_order_undetermined`: the FOC
   root is still not established to be the minimiser, and Corollary 37 does not
   assume it is — it is a statement about the **zero set** only.
4. **`ScaleHomogeneous` is a typed hypothesis**, exactly like (H1)/(H2). It is
   the formal content of "the no-arb band is scale-free while the traded
   quantity scales with the reserves", and is not proved from the CES definition
   in-tree.

---
*Companion to `TAX3_ADDENDUM.md`; prior results cited by declaration name and
file throughout, per standing ban 5.*
