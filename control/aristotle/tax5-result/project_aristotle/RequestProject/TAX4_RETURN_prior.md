# Return for `TAX4_ADDENDUM.md` (M28–M32)

One new module, `#print axioms`-clean (`propext`, `Classical.choice`, `Quot.sound` only)
and free of `sorry`:

* `RequestProject/MevReturnsReduction.lean` — namespace `MevTaxReturns` — **M28–M32**.

`MevTaxControl.H1_dLbar_dpiPhi_pos`, `MevTaxControl.H2_dnu_dlamMEV_pos` and
`MevTaxChannels.ScaleHomogeneous` are used **by name as typed hypotheses only** and are
never discharged. Nothing already proved in `MevTaxControl.lean`, `MevTaxProgram.lean`,
`MevLVRCancellation.lean` or `MevChannelClosure.lean` is redone; those results are cited
by declaration name and file.

---

## The one thing to read first: Corollary 40, the mandatory consistency check

**M28's algebra is correct, and `Corollary 40` HOLDS — but only under one of the two
readings of `MevTaxProgram.Proposition16_corrected_law`'s `dphidnu` slot, and the
docstring of that theorem names the other one.**

`SRC` **Convention 9** says the gate derivative is composed:
`∂φ/∂ν = (1-φ_M)(1-τ_MEV)·∂φ_X/∂ν`. The Lean variable called `dphidnu` in
`MevTaxProgram.totalDeriv` / `MevTaxProgram.focCore` is **not** that object: it is the
**bare** `∂φ_X/∂ν` of `DOC` Definition 18. That is fixed by the construction of the
derivative itself — `MevTaxProgram.hasDerivAt_phiTot` instantiates the slot from
`hphiX : HasDerivAt phiX dphidnu (nu tauMEV)`, and the monoid Jacobian
`(1-φ_M)(1-τ_MEV)` is carried separately by `MevTaxProgram.pathGate`. The prose of
`Proposition16_corrected_law` (and of `SRC` Proposition 13) nevertheless writes that slot
as `∂φ/∂ν`, which Convention 9 defines to be the composed object.

| substitution into the slot | result | declaration |
|---|---|---|
| **bare** `∂φ_X/∂ν` (what the Lean derivative actually is) | `1 + (1-φ_X)/(dphidnu·dnudtau)` **equals** M28's box, and the FOC equivalence is `Proposition16_corrected_law` conjunct 1 verbatim | `Corollary40_consistency_with_Proposition16` |
| **composed** `(1-φ_M)(1-τ_MEV)·∂φ_X/∂ν` (Convention 9 read literally) | agrees with the box **iff `(1-φ_M)(1-τ_MEV) = 1`**; witness of disagreement at `φ_M = 0, τ = 1/2` | `Corollary40_composed_agrees_iff_monoid_jacobian_is_one`, `Corollary40_composed_substitution_disagrees` |

So the disagreement, where it exists, is a **naming defect in the corrected law's
statement**, not an error in M28's substitution and not an error in the optimization: one
factor of `(1-φ_M)(1-τ_MEV)` is at stake, exactly the monoid Jacobian that the M24 audit
recorded as MISSING from the source box. Neither claim is reinterpreted here: both
readings are formalized and both verdicts are machine-checked.

---

## M28 — Theorem 40 and its corollaries

| claim | verdict | declaration |
|---|---|---|
| the bracket factorises as `A(1-φ_M)(1-φ_X)[1 + (1-φ_M)(1-τ)(∂φ_X/∂ν)νε/φ]` | **HOLDS** | `Theorem40_bracket_factorisation` |
| `τ* = 1 + φ/((1-φ_M)(∂φ_X/∂ν)νε)` (the box) | **HOLDS** for `φ_M, φ_X ≠ 1`, `φ ≠ 0`, `(1-φ_M)(∂φ_X/∂ν)νε ≠ 0` | `Theorem40_returns_reduction` |
| Corollary 40 (agreement with `Proposition16_corrected_law` conjunct 1) | **HOLDS** (bare reading) / **fails** (composed reading) | see the table above |
| Corollary 40b: with `(1-τ)` extracted the law is explicit | **HOLDS only for data frozen in the tax** | `Corollary40b_unique_explicit_root` |
| Corollary 40b: "the implicitness is an artifact of the composite denominator" | **REFUTED** | `Corollary40b_endogenous_fee_closed_form` |
| Corollary 40b: "`(1-φ_X)` cancels" | **REFUTED** once `φ` is the monoid fee | `Corollary40b_phiX_does_not_cancel` |
| falsification target (a): the premise `∂ν/∂φ = νε/φ` | **dies on one-sided flow**, and then the FOC has **no root at all** | `Corollary40c_one_sided_flow_leaves_no_root` |
| falsification target (c): does the reduction survive the loop? | **NO — the elasticity cancels out of the law entirely** | `Theorem40d_loop_correction_removes_epsilon` |

**Corollary 40b, precisely.** Extracting `(1-τ_MEV)` from the composed denominator does
remove one occurrence of the tax. It does not make the law closed, because the numerator
`φ` of the box is the composed fee
`MevTaxControl.phiTotal φ_M φ_X τ_MEV = 1-(1-φ_M)(1-φ_X)(1-τ_MEV)`, which is a function of
the tax. Substituting it, the FOC does have a genuine closed form,

`τ*_MEV = 1 - 1/((1-φ_M)[(1-φ_X) - (∂φ_X/∂ν)νε])`,

in which `(1-φ_X)` is present and load-bearing: two configurations differing only in `φ_X`
have different roots. The self-reference is therefore **reduced by one factor, not shown
to be an artifact**; and even the reduced form still evaluates `ν`, `ε` and `∂φ_X/∂ν` at
`ν(τ*)`, so `Proposition 13`'s "all factors at `ν(τ*)`" rubric stands.

**Theorem 40d, the strongest negative result in this bundle.** Run route (i) and route
(ii) simultaneously in the loop-consistent form already proved as
`MevTaxChannels.Theorem38_two_routes_close_a_loop` — `P = ∂φ/∂τ|total`,
`N = ∂ν/∂τ|total`, `q = ∂ν/∂φ = νε/φ`, `i` = route (i) — and the FOC `P = 0` is
equivalent to

`(1-φ_X) + (1-τ_MEV)(∂φ_X/∂ν)·i = 0`,

with `q`, hence `ε`, **absent**. Consequences: (1) with the (H2) channel switched off
(`i = 0`) there is **no root at all**; (2) with `(∂φ_X/∂ν)·i ≠ 0` the control law is
`τ* = 1 + (1-φ_X)/((∂φ_X/∂ν)·i)`, governed by the (H2) gain alone. M28's "the surviving
unknown is `ε` alone" is therefore true only for the **single-channel** model in which the
loop correction is not applied. Which model is operative is not settled here.

---

## M29 — Theorem 41 and Corollary 41

| claim | verdict | declaration |
|---|---|---|
| `K` carries every dimension and rescaling it does not move the root | **HOLDS** | `Theorem41_scale_freeness` (1,2) |
| the fee elasticity of flow is scale-free | **HOLDS** | `Theorem41_scale_freeness` (3) |
| `∂ν/∂φ` is invariant under `ΔQ → cΔQ`, `L̄ → cL̄` | **HOLDS** | `Theorem41_scale_freeness` (4) |
| the controller needs the ratio derivative, not `∂ΔQ^{ARB}/∂φ` | **HOLDS** | `Corollary41_ratio_derivative_closes` |

For a product-shape flow `ΔQ = S·h(φ)` on a pool of scale `S·λ`, the ratio derivative is
`h'(φ)/λ` — independent of `S` — while `∂ΔQ/∂φ = S·h'(φ)` is not. So M27's missing
primitive (`MevTaxChannels.Theorem39_arb_side_does_not_close`) is missing from a question
the control law does not ask; `π^{varphi}` is needed only to report a magnitude.

---

## M30 — Theorem 42, comparative statics

On the sign domain `0 < φ`, `φ_M < 1`, `0 < ∂φ_X/∂ν` (`MevTaxProgram.dphidnuBoxed_pos`),
`0 < ν`, `ε < 0` (from `SRC` Theorem 33(ii)'s `∂ΔQ/∂φ < 0`), with `φ`, `∂φ_X/∂ν`, `ν`, `ε`
read as data — `Theorem42_comparative_statics`:

| partial | value | sign |
|---|---|---|
| `∂τ*/∂ε` | `-(φ/((1-φ_M)(∂φ_X/∂ν)ν))/ε²` | **< 0** — a more elastic flow (`ε` more negative) **raises** `τ*` |
| `∂τ*/∂ν` | `-(φ/((1-φ_M)(∂φ_X/∂ν)ε))/ν²` | **> 0** |
| `∂τ*/∂φ` | `1/((1-φ_M)(∂φ_X/∂ν)νε)` | **< 0** |
| `∂τ*/∂φ_M` | `(φ/((∂φ_X/∂ν)νε))/(1-φ_M)²` | **< 0** |
| `∂τ*/∂(∂φ_X/∂ν)` | `-(φ/((1-φ_M)νε))/(∂φ_X/∂ν)²` | **> 0** |

Gate parameters, with `∂φ_X/∂ν` expanded from `DOC` Definition 18
(`MevTaxProgram.dphidnuBoxed`):

* `α_R` (gate height): `∂(∂φ_X/∂ν)/∂α_R > 0` (`Theorem42_alphaR_raises_the_gate_slope`),
  hence `∂τ*/∂α_R > 0` by the chain with the row above.
* `φ̄` (base fee, `DOC` Definition 18): it enters only through `φ_X`, and
  `∂φ/∂φ̄ = ∂φ/∂φ_X = (1-φ_M)(1-τ_MEV) > 0`
  (`MevTaxControl.Theorem29_monoid_path_is_direct`), so `∂τ*/∂φ̄ < 0` by the `∂τ*/∂φ` row.
* `γ_R` (gate steepness): **NO GLOBAL SIGN.**
  `∂(∂φ_X/∂ν)/∂γ_R = α_R V e^z[(1+e^z) + γ_R(β_R-ν)(1-e^z)]/(1+e^z)³`, `z = γ_R(β_R-ν)`
  (`Theorem42_gate_steepness_sign_is_ambiguous`). The bracket is positive at the gate
  centre `ν = β_R` and negative for a steep gate operated above the centre
  (`γ_R = 10`, `β_R - ν = -1`) — both witnesses machine-checked
  (`Theorem42_gate_steepness_bracket_witnesses`). This is **OPEN as a sign** and is a
  domain statement: the tax responds to gate steepness in opposite directions on the two
  sides of `β_R`.

**The two `ε` limits** (`Theorem42_epsilon_limits`):

* `ε → 0⁻` (inelastic): `τ* → -∞`. The interior root leaves `[0,1]` and, below Theorem
  43's threshold, the constrained optimum is the corner `τ_MEV = 0`.
* `ε → -∞` (perfectly elastic): `τ* → 1⁻`. The admissible set is exhausted from below and
  the confiscatory boundary is approached but never attained.

---

## M31 — Theorem 43, the threshold elasticity

`Theorem43_threshold_elasticity`, on the same sign domain and with
`Proposition 13`'s guard carried (`0 < ∂φ/∂ν`, `∂ν/∂τ < 0`, `φ_X < 1`):

```
τ* > 0   ⟺   1 - φ_X < |(∂φ/∂ν)(∂ν/∂τ)|   ⟺   |ε| > ε* = φ / ((1-φ_M)(∂φ_X/∂ν)ν)
```

and `τ* < 1` always. **`ε*` does not involve `φ_X`**: the admissibility question reduces
to a comparison of the flow elasticity with the fee level per unit of gate response.
Below `ε*` no interior tax is optimal.

In the endogenous-fee reading of `Corollary40b_endogenous_fee_closed_form` the threshold is
`ε*_endo = (1/(1-φ_M) - (1-φ_X))/((∂φ_X/∂ν)ν)` (`Theorem43_endogenous_threshold_differs`),
and this is exactly `ε*` **evaluated at the no-tax fee** `φ(0) = φ_M ⊗_φ φ_X`
(`Theorem43_endogenous_threshold_is_the_no_tax_threshold`); read at any positive tax the
two numbers differ (`Theorem43_thresholds_differ_at_positive_tax`). So M31's design number
is well posed but must always be quoted with the operating fee it is evaluated at.

---

## M32 — Theorem 44, and open item O2

| claim | verdict | declaration |
|---|---|---|
| the objective reading `min (∂π̂^σ/∂τ)²` discriminates max from min | **NO — every root minimizes it** | `Theorem44_objective_reading_does_not_discriminate` (via `MevTaxProgram.Proposition15_second_order_exposure`) |
| frozen fee: `∂²π̂^σ/∂τ² = -A(1-φ_M)(∂φ_X/∂ν)(∂ν/∂τ) > 0` | **HOLDS** | `Theorem44_second_order_frozen_fee` |
| endogenous fee: `∂²π̂^σ/∂τ² = -A(1-φ_M)²(1-φ_X)(∂φ_X/∂ν)νε/φ(τ)² `, sign `= -sign(ε)` | **HOLDS** | `Theorem44_second_order_endogenous_fee` |
| a strictly increasing total derivative with a root makes the root a minimizer of `π̂^σ` on `[0,1]` | **HOLDS** | `Theorem44_root_is_a_minimum_of_piHat` |
| the total derivative is strictly increasing on the whole admissible interval `[0,1]` | **HOLDS** whenever at least one leg charges | `Theorem44_O2_closes` (with `phiTotal_pos_on_unit_interval`) |

**O2 closes on the reduced model.** With `ε` explicit rather than buried in `∂ν/∂τ_MEV`,
the second derivative of `π̂^σ` in the tax is a single signed expression in
`(ε, ν, Θ_φ, φ_M)`; on the M26 domain (`ε < 0`, `K > 0`, `∂φ_X/∂ν > 0`, `ν > 0`,
`φ_M, φ_X < 1`) it is **strictly positive at every tax at which the composed fee does not
vanish**. On the admissible interval `τ_MEV ∈ [0,1]` the composed fee
`MevTaxControl.phiTotal φ_M φ_X τ = 1-(1-φ_M)(1-φ_X)(1-τ)` is nonzero exactly when at
least one leg charges, `(1-φ_M)(1-φ_X) < 1` (`phiTotal_pos_on_unit_interval`); under that
single extra hypothesis the total derivative is **strictly increasing on all of `[0,1]`**
(`Theorem44_O2_closes`) — single crossing is a *theorem* rather than an assumption, the
root is unique, and it is a **minimum of `π̂^σ`**, not a maximum. That is precisely what
`MevTaxProgram.Proposition15_single_crossing_gives_minimum` needed and nothing supplied.
If both legs are free (`φ_M = φ_X = 0`) the fee vanishes at `τ_MEV = 0`, the reduced
derivative `νε/φ` is undefined there, and the closure does not apply.

**What that closure is conditional on — stated, not narrowed.**

1. `∂ν/∂φ = νε/φ`, i.e. `ν ∝ ΔQ` under proportional legs. On a one-sided flow this fails
   (`MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`) and there is no
   root to classify (`Corollary40c_one_sided_flow_leaves_no_root`). The flow-domain ruling
   **PR-REGION** (`DOC:423`) is the author's and remains OPEN.
2. Route (ii) alone, i.e. the loop of `SRC` Theorem 34 **not** applied. With the loop live
   the FOC is a different equation (`Theorem40d_loop_correction_removes_epsilon`) and the
   second-order condition of that system is **OPEN** — the elasticity does not appear in
   it, so `ε` cannot settle it.
3. `K > 0` (`MevTaxLVR.Theorem37_K_pos`), which rests on (H1) — undischarged by
   construction.
4. At least one leg charges, `(1-φ_M)(1-φ_X) < 1`, so that the composed fee is nonzero
   throughout `[0,1]`.

---

## Standing OPEN items after this bundle

* **PR-REGION** (`DOC:423`) — the flow-domain ruling. Everything in M28, M31 and M32
  needs the two-sided branch.
* **Which channel model is operative** — single-channel route (ii), or the loop-corrected
  system of `SRC` Theorem 34. The two give *different control laws*
  (`Theorem40d_loop_correction_removes_epsilon`), so this is now a live fork, not a
  refinement.
* **O2 under the loop** — the second-order condition of the loop-corrected FOC.
* **`∂τ*/∂γ_R`** — no global sign; positive at the gate centre, negative for a steep gate
  operated above it.
* **The `dphidnu` slot's name** in `MevTaxProgram.Proposition16_corrected_law` and in
  `SRC` Proposition 13: the Lean statement's slot is the bare `∂φ_X/∂ν`, the prose calls it
  `∂φ/∂ν`, and Convention 9 makes those different objects.
