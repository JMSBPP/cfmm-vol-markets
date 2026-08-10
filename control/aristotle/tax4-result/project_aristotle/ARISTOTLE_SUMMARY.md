# Summary of changes for run 07b744ce-1237-4791-b3c0-c1827fe36805
## Deliverable

One new module, `RequestProject/MevReturnsReduction.lean` (namespace `MevTaxReturns`, ~995 lines), formalizing blocks **M28–M32** of `RequestProject/TAX4_ADDENDUM.md` — Theorems 40–44 with their corollaries. It **builds cleanly, contains no `sorry`**, and all 30 theorems/lemmas were checked with `#print axioms`: each depends only on `propext`, `Classical.choice`, `Quot.sound`. `MevTaxControl.H1_dLbar_dpiPhi_pos`, `MevTaxControl.H2_dnu_dlamMEV_pos` and `MevTaxChannels.ScaleHomogeneous` are used by name as typed hypotheses only and are never discharged. A companion return document, `RequestProject/TAX4_RETURN.md`, records every verdict with its declaration name.

## Corollary 40 — the mandatory consistency check

M28's algebra is **correct**, and Corollary 40 **HOLDS** — but only under one of the two readings of the derivative slot, and the prose names the other one.

The Lean variable `dphidnu` in `MevTaxProgram.totalDeriv` / `focCore` is the **bare** `∂φ_X/∂ν` — that is fixed by `MevTaxProgram.hasDerivAt_phiTot`, which instantiates the slot from `hphiX : HasDerivAt phiX dphidnu (nu tauMEV)`, with the monoid Jacobian `(1-φ_M)(1-τ)` carried separately by `MevTaxProgram.pathGate`. The prose of `MevTaxProgram.Proposition16_corrected_law` (and of `SRC` Proposition 13) writes that slot as `∂φ/∂ν`, which `SRC` Convention 9 defines to be the **composed** object.

* Bare reading: M28's box **equals** `Proposition16_corrected_law` conjunct 1 verbatim, and the FOC equivalence is obtained by invoking that theorem — `Corollary40_consistency_with_Proposition16`.
* Composed reading: the two agree **iff `(1-φ_M)(1-τ_MEV) = 1`** (`Corollary40_composed_agrees_iff_monoid_jacobian_is_one`), with a machine-checked witness of disagreement at `φ_M = 0, τ = 1/2, φ = ∂φ_X/∂ν = ν = 1, ε = -1` (`Corollary40_composed_substitution_disagrees`).

So where they disagree, the defect is in the **naming of the slot** in the corrected law's statement — exactly one factor of `(1-φ_M)(1-τ)`, the monoid Jacobian the M24 audit recorded as missing — not in M28's substitution and not in the optimization. Neither claim was reinterpreted: both readings are formalized and both verdicts are machine-checked.

## Refutations returned

* **Corollary 40b REFUTED in its stated form.** Extracting `(1-τ)` removes one occurrence of the tax, but the box's numerator `φ` is the monoid fee `MevTaxControl.phiTotal φ_M φ_X τ`, itself a function of τ. The genuine closed form is `τ* = 1 - 1/((1-φ_M)[(1-φ_X) - (∂φ_X/∂ν)νε])` (`Corollary40b_endogenous_fee_closed_form`), in which `(1-φ_X)` does **not** cancel — witness `Corollary40b_phiX_does_not_cancel`. The self-reference is reduced by one factor, not shown to be an artifact.
* **The premise dies on one-sided flow.** Route (ii) is identically zero and the FOC then has **no root at any tax** (`Corollary40c_one_sided_flow_leaves_no_root`). The flow-domain ruling PR-REGION (`DOC:423`) is the author's and stays OPEN.
* **The loop removes ε entirely** (`Theorem40d_loop_correction_removes_epsilon`). Run in the loop-consistent form of `MevTaxChannels.Theorem38_two_routes_close_a_loop`, the FOC `P = 0` is equivalent to `(1-φ_X) + (1-τ)(∂φ_X/∂ν)i = 0`: the elasticity is absent, with `i = 0` there is no root, and otherwise `τ* = 1 + (1-φ_X)/((∂φ_X/∂ν)i)`. M28's "the surviving unknown is ε alone" holds only for the single-channel model. Which model is operative is a live fork, not settled here.
* **`∂τ*/∂γ_R` has no global sign** — bracket positive at the gate centre, negative for a steep gate above it, both witnesses checked (`Theorem42_gate_steepness_bracket_witnesses`).

## Results that hold

* **Theorem 40** (`Theorem40_bracket_factorisation`, `Theorem40_returns_reduction`): the FOC is explicit, `τ* = 1 + φ/((1-φ_M)(∂φ_X/∂ν)νε)`, for a frozen fee level.
* **Theorem 41 / Corollary 41** (M29): the scale factor multiplies the FOC and does not move its root; the ratio derivative `∂ν/∂φ` is scale-free while `∂ΔQ^ARB/∂φ` is not — bundle 3's missing pool-scale primitive is missing from a question the controller never asks.
* **Theorem 42** (M30, signs derived not assumed): `∂τ*/∂ε < 0`, `∂τ*/∂ν > 0`, `∂τ*/∂φ < 0`, `∂τ*/∂φ_M < 0`, `∂τ*/∂(∂φ_X/∂ν) > 0`; `∂τ*/∂α_R > 0`; `∂τ*/∂φ̄ < 0`. Limits: `ε → 0⁻` ⇒ `τ* → -∞`; `ε → -∞` ⇒ `τ* → 1`.
* **Theorem 43** (M31): `τ* > 0 ⟺ |ε| > ε* = φ/((1-φ_M)(∂φ_X/∂ν)ν)`, and `τ* < 1` always; `ε*` does not involve `φ_X`. The endogenous-fee threshold is exactly `ε*` read at the **no-tax** fee, and differs from it at any positive tax — so the design number must be quoted with its operating fee.
* **Theorem 44 / open item O2 CLOSES** on the reduced model: `∂²π̂^σ/∂τ² = -A(1-φ_M)²(1-φ_X)(∂φ_X/∂ν)νε/φ(τ)² > 0` for `ε < 0`, and on `[0,1]` — provided at least one leg charges, `(1-φ_M)(1-φ_X) < 1`, so the composed fee never vanishes — the total derivative is **strictly increasing** (`Theorem44_O2_closes`). Single crossing becomes a theorem rather than the unproved hypothesis of `MevTaxProgram.Proposition15_single_crossing_gives_minimum`, the interior root is unique, and it is a **minimum** of `π̂^σ` (`Theorem44_root_is_a_minimum_of_piHat`). Separately, Definition 36's objective reading `min (∂π̂^σ/∂τ)²` cannot discriminate: every root minimizes it (`Theorem44_objective_reading_does_not_discriminate`).

## Standing OPEN, with reasons

PR-REGION (`DOC:423`); which channel model is operative (the two give different control laws); O2 under the loop (ε does not appear there, so it cannot settle it); the sign of `∂τ*/∂γ_R`; and the naming of the `dphidnu` slot in the corrected law and in `SRC` Proposition 13.
