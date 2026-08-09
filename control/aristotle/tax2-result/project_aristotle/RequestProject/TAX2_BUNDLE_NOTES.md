# Bundle 2 (M19–M24) — returned results

Everything below is formalized in `RequestProject/MevTaxProgram.lean`
(namespace `MevTaxProgram`), axiom-clean (`propext`, `Classical.choice`,
`Quot.sound` only) and with zero `sorry`. Bundle 1 (`MevTaxControl.lean`) is
cited, never redone.

## The plant used throughout

`τ_MEV` reaches the realizable payoff along

```
τ_MEV ──────────────────────────────► φ_total ─► π^φ ─► L̄ ─► π̂^σ      (P-direct)
   └──► ν ──► φ_X (DOC Def. 18 gate) ─┘                                (P-gate)
```

with `φ_total = φ_M ⊗_φ φ_X(ν(τ_MEV)) ⊗_φ τ_MEV` (Rule 12) and
`A = (∂π̂^σ/∂L̄)(∂L̄/∂π^φ)(∂π^φ/∂φ)` the outer chain factor
(`MevTaxProgram.phiTot`, `MevTaxProgram.piHat`).

## M19 — the corrected program

`Definition33_CorrectedTaxProgram`: minimize the exposure
`𝓔(τ) = (∂π̂^σ/∂τ_MEV)²` over `τ_MEV ∈ [0,1]` **subject to** `π^σ = π̂^σ`;
FOC `∂π̂^σ/∂τ_MEV = 0`. `M19_FOC_is_not_feasibility` proves: FOC ⟺ `𝓔 = 0`;
FOC without feasibility; feasibility without FOC; and the superseded
`∂π̂^σ/∂τ_MEV = ΔQ_v^⋆` is neither.

## M20 — the total derivative is a SUM

`Theorem33_path_decomposition`:

```
∂π̂^σ/∂τ_MEV = A(1-φ_M)(1-φ_X)  +  A(1-φ_M)(1-τ_MEV)(∂φ/∂ν)(∂ν/∂τ_MEV)
                (P-direct)                     (P-gate)
```

`Theorem33_five_factor_product_is_one_summand`: the source's five-factor product
**is** the (P-gate) summand (reading `∂φ/∂ν` as `∂φ_total/∂ν`), is off by the
monoid Jacobian `(1-φ_M)(1-τ_MEV)` under the Definition-18 reading, and equals
the total derivative **iff** (P-direct) `= 0`.

## M21 — the two paths oppose

`Theorem34_opposed_signs`: (P-direct) `> 0`, (P-gate) `< 0`.
`Theorem34_omitting_direct_can_reverse_sign`: witnesses where the gate-only
answer is negative while the true total derivative is positive — omitting
(P-direct) can flip the sign, not just the magnitude.
`Theorem34_signs_from_H1_H2` reads both signs off (H1), (H2) and the cited
`tau_to_nu_strictAntiOn_under_H2`. The boxed `∂φ/∂ν` of `ENTRY_POINT` is
transcribed as `dphidnuBoxed`, proved to be the ν-derivative of Definition 18's
fee level (`hasDerivAt_feeLevel_nu`) and strictly positive under
`α_R, γ_R > 0`, `α_j ≥ 0` not all zero (`dphidnuBoxed_pos`).

## M22 — existence, and the controller's domain

* `Theorem35_interior_root`: IVT sufficiency; necessary **and** sufficient under
  strict monotonicity; uniqueness.
* `Theorem35_root_iff_gate_dominates_at_zero`: `D(1) > 0` **always** (the gate
  path carries `(1-τ_MEV)`, which dies at `τ_MEV = 1`), so existence reduces to
  the gate-dominance condition at zero tax:
  `|(∂φ/∂ν)(∂ν/∂τ_MEV)| > 1 - φ_X`.
* `Theorem36_no_interior_root_off_the_band`: on exact saturation (`α_R = 0`,
  `γ_R = 0`, or all `α_j = 0`) and, quantitatively, whenever the utilization
  stays off the **responsive band**

  ```
  ν ∈ (β_R - W/γ_R, β_R + W/γ_R),      α_R γ_R (∑_j α_j) N e^{-W} < m
  ```

  (`m ≤ 1-φ_X`, `|∂ν/∂τ_MEV| ≤ N`), the total derivative is strictly positive
  throughout `[0,1]` and **no interior root exists**. This band is the
  controller's domain (`responsiveBand`, `responsiveBand_eq_Ioo`).

## M23 — second order

* Under the exposure reading `𝓔 = (∂π̂^σ/∂τ_MEV)²`, any FOC root is a **global**
  minimiser of `𝓔`; SOC `𝓔'' = 2(D')² > 0` iff the crossing is transversal
  (`Proposition15_second_order_exposure`).
* Under the *level* reading (stationary point of `π̂^σ`), the SOC is **not
  settled** by the M20/M21 data: two plants with identical first-order data at
  `τ* = 1/2` and opposite curvature
  (`Proposition15_level_reading_second_order_undetermined`).
* The hypothesis that settles it — single crossing from below of the total
  derivative — is stated and used in
  `Proposition15_single_crossing_gives_minimum`. It is never discharged.

## M24 — verdicts and the corrected law

| factor of the source's box | verdict |
|---|---|
| leading `1 -` | **SURVIVES** (the corrected law is again `τ* = 1 - …`) |
| `1/ΔQ_v^⋆` | **SPURIOUS** (artefact of the RHS `ΔQ_v^⋆`; the FOC is scale-invariant) |
| `[∑_{i_K} π^l ∂L(i_K)/∂π^φ]` | **SPURIOUS** in the law (a positive common factor; it stays in the derivative) |
| `[ΔQ_M/(1-φ_X) + p ΔQ_X/(1-φ_M)]` | **ILL-POSED** (no section-independent value — `Theorem30`) |
| `∂φ/∂ν` | **SURVIVES** (same form and sign, relocated to the denominator) |
| `∂ν/∂τ_MEV` | **SIGN CORRECTED** (`< 0`, not `> 0`) |
| `(1-φ_M)(1-φ_X)` — the direct monoid path | **MISSING** |
| `(1-φ_M)(1-τ_MEV)` — the monoid Jacobian | **MISSING** |
| self-reference of `τ*` on the right | **MISSING** |

(`auditTable`, justified by `Proposition16_audit_justification`.)

**Corrected law** (`Proposition16_corrected_law`), for `A(1-φ_M) ≠ 0` and a
responsive gate:

```
∂π̂^σ/∂τ_MEV = 0  ⟺  τ*_MEV = 1 + (1-φ_X)/((∂φ/∂ν)(∂ν/∂τ_MEV))
                            = 1 - (1-φ_X)/|(∂φ/∂ν)(∂ν/∂τ_MEV)|
```

It is **implicit**, not closed: `φ_X`, `∂φ/∂ν`, `∂ν/∂τ_MEV` are evaluated at
`ν(τ*_MEV)`. Closed exactly when they do not depend on `τ_MEV`
(`Proposition16_closed_form_and_branch_structure`); existence/uniqueness from
M22.

**Domain.** `τ*_MEV < 1` always; `τ*_MEV > 0` **iff** `1-φ_X < |(∂φ/∂ν)(∂ν/∂τ_MEV)|`
(otherwise the optimum is the boundary `τ_MEV = 0`); the utilization must lie in
the responsive band of M22. The `(·)^+` strike kink is branched, not
differentiated: it lives in the constraint (OTM ⇒ `π̂^σ(τ) = 0`;
ITM ⇒ `π̂^σ(τ) = ΔQ_v^⋆(σ² - σ_K²)`), and the FOC root is branch-independent.

## Named as unsettled

1. Sign of `∂²π̂^σ/∂τ_MEV²` at the root under the level reading — settled only by
   single crossing from below (M23).
2. Strict negativity `∂ν/∂τ_MEV < 0` at a point: the cited theorem gives strict
   antitonicity, hence only `≤ 0`
   (`dnudtau_nonpos_of_strictAntiOn`,
   `dnudtau_strict_negativity_is_an_extra_hypothesis`); `< 0` is carried as a
   typed hypothesis.
3. (H1), (H2) are behavioural LP-supply estimands: typed hypotheses, never
   discharged.
