# Returned bundle — M11–M18 → Lean declarations

All declarations live in `RequestProject/MevTaxControl.lean`, namespace
`MevTaxControl`. The file builds with **zero `sorry`**; every declaration below
is axiom-clean (`propext`, `Classical.choice`, `Quot.sound` only).

| Block | Item | Lean declaration | Outcome |
|---|---|---|---|
| M11 | Definition 32 (event-time plant) | `EventPlant` (+ `state`, `uEx`, `uEn`, `ThetaSigma`, `piSigma`, `piSigmaHat`, `output`, `phiTotal`, `signedResidual`, `errorSigma`, `piSigma_itm`, `piSigma_otm`, `StandingAssumptions`) | transcribed |
| M12 | Theorem 29 (the monoid path is direct) | `Theorem29_monoid_path_is_direct` | proved |
| M12 | Corollary (five-factor product ≠ total derivative) | `Corollary29_five_factor_product_not_total_derivative` | **refuted with witness** |
| M12 | "also to be settled": conditioned partial vs. total derivative | `M12_conditioned_partial_and_total_derivative_incompatible` | settled: they cannot both hold |
| M13 | Theorem 30 (submersion; section sum ill-posed) | `Theorem30_composed_fee_submersion_section_sum_ill_posed` (+ `phiTotalMap`, `phiTotalFDeriv`, `hasFDerivAt_phiTotalMap`) | proved, with two-section witness |
| M14 | Proposition 12 (the boxed law solves a different equation) | `Proposition12_boxed_law_solves_a_different_equation` (+ `BoxedTauStarLaw`, `chainDerivative`) | **refuted with witness** |
| M14 | Proposition 13 (implicit, not closed) | `Proposition13_implicit_not_closed` (+ `BoxedTauStarLawImplicit`) | proved |
| M15 | Proposition 14 (root, not argmin) | `Proposition14_signed_residual_root`, `Proposition14_error_not_differentiable_at_minimiser` | proved |
| M16 | Theorem 31 (admissibility and projection, branched at the strike) | `Theorem31_admissibility_and_projection` | proved |
| M17 | Theorem 32 (hazard monotonicity in the tax) | `Theorem32_hazard_strictAntiOn_tau` (+ `mevMultiTaxed`, `probOr_multiFee_joint`, `mevMultiTaxed_eq_mevMulti`) | proved (new) |
| M17 | the `τ → λ` substitution is not sign-preserving | `tau_to_nu_strictAntiOn_under_H2` | proved under (H2) + explicit clearing hypothesis |
| M18 | (H1), (H2) | `H1_dLbar_dpiPhi_pos`, `H2_dnu_dlamMEV_pos` | **hypotheses, never proved** |
| M18 | ladder factorization / axis error | `ladder_sum_eq_dQvStar`, `M18_axis_error_refuted` | proved; `τ*_MEV = 1` refuted |

## What each refutation exhibits

* **Corollary of Theorem 29.** The universally quantified five-factor identity
  is false. Witness: all outer maps the identity, `φ_M = 0`, `ν ≡ 0`,
  `τ_MEV = 0`. There the total derivative through the composed fee is `1`
  while the five-factor product is `0`, because `ν` does not respond and the
  monoid puts `τ_MEV` directly in the fee. With two forward paths the total
  derivative is the **sum** over paths.

* **M12, second question.** If `ν` reaches `τ_MEV` only through `λ_MEV`, then
  conditioning on `λ_MEV` sets `∂ν/∂τ_MEV = 0` and the boxed product vanishes,
  while the unrestricted total derivative is `c (1-φ_M)(1-φ_X) ≠ 0` for any
  outer derivative `c ≠ 0`. The conditioned partial and the unrestricted total
  derivative therefore cannot both satisfy the boxed identity.

* **Theorem 30, section witness.** The coordinate sections `φ ↦ (φ,0,0)` and
  `φ ↦ (0,φ,0)` are both sections of `φ_total` and agree at `φ = 0`, yet at
  `ΔQ_M = 1`, `p_{(η,Δi)} = 0`, `ΔQ_X = 0` they induce sums `1` and `0`.

* **Proposition 12.** The boxed law is equivalent (for `ΔQ_v^⋆ ≠ 0`,
  `τ_MEV ≠ 1`, `φ_M, φ_X ≠ 1`) to `∂π̂^σ/∂τ_MEV = ΔQ_v^⋆`. Since the boxed law
  never mentions `σ_K²`, one and the same `τ_MEV` satisfies it at two different
  strikes whose contractual payoffs `π^σ` differ, and at which
  `π^σ ≠ π̂^σ`. The factor `(σ²(i(t)) - σ_K²)^+` is absent.

* **M18 axis error.** `∂L_σ(i_K)/∂π^φ = 0` on the volatility axis (the ladder
  is `L_σ` times a pure geometric weight) coexists with `∂L(i_K)/∂π^φ > 0` on
  the price axis under (H1); the price-axis sum is then strictly positive and
  `τ*_MEV = 1` fails.

## Guards honoured

1. `MevOptimization.ptrade` is the Möbius kernel with a negative-fee pole. Every
   fee-limit step keeps the composed fee in `[0,1)`: in Theorem 32 this is the
   conjunction `0 ≤ φ̄`, `0 ≤ α`, `0 ≤ u`, `multiFee < 1`, `τ_MEV ∈ [0,1]`.
2. The three kinks are branched, never differentiated through: `(·)^+` at the
   strike (`piSigma_itm` / `piSigma_otm`, and the two branches of Theorem 31),
   `|·|` in `e^σ` (Proposition 14 exhibits the non-differentiability rather than
   differentiating), and no statement differentiates a `min(·)` funded cap.
3. Sign and ordering claims use the tree's native idiom — `StrictMono`,
   `StrictAntiOn`, `IsMinOn`, `Monotone` — and a derivative layer is introduced
   only where the source's own claim *is* a derivative identity (M12, M13, M14),
   in which case the needed derivative facts are proved explicitly
   (`hasDerivAt_phiTotal_tau`, `hasFDerivAt_phiTotalMap`).
4. Neither T24 nor the Capponi–CES interior embedding is re-attempted, and
   `mevTotal_eq_arb_of_sandwich_zero` is cited nowhere.
5. No symbol is minted: `L_σ` (volatility axis) is kept distinct from `L̄`
   (price axis) throughout, and the source's composite is written out as
   `π^φ - π^LVR` with no shorthand.

## Scope notes (not settled here, and what would settle them)

* **The sign of `∂ν/∂τ_MEV` unconditionally.** `tau_to_nu_strictAntiOn_under_H2`
  needs the identification of `λ_MEV` with the taxed arbitrage hazard, carried
  as the explicit hypothesis `hclearing`. Without it the sandwich channel
  `λ_sandwich` is unmodelled and its own tax response is unpinned; a modelled
  `λ_sandwich(τ_MEV)` with a declared sign would settle the general case.
* **Existence of a boxed fixed point in the non-closed case.** Proposition 13
  gives witnesses with zero and with infinitely many solutions; a contraction or
  a strict-monotonicity hypothesis on `τ_MEV ↦ 1 - K (∂φ/∂ν)(τ_MEV)` would
  restore existence and uniqueness.
* **Strict monotonicity of `π̂^σ` in `τ_MEV`.** Propositions 14 and Theorem 31
  carry it as `hmono`. Deriving it from Theorem 32 additionally requires the
  price-axis liquidity response (H1) and a monotone `π^l`, neither of which is
  proved here — (H1) is an estimand by ruling.
