/-
  exp/InventoryObserverDynamics.lean

  Formal companion to the closing DYNAMICS note, third installment.  The note
  closes the loop on the latent inventory weights `η̃` by giving an OBSERVER for
  them and then solving the trade-size / curvature program

      (Δᵢ⋆, η⋆) ≡ arg max [ π⁺(Δᵢ, η ; α) − C(Δᵢ) ].

  This file makes the four moving pieces precise and machine-checks the
  computations and comparative statics.

  1. INVENTORY-IMPLIED OBSERVER.  Since `η̃_j` is latent, the note approximates it
     by an inventory-implied observer

         η̃_j  ∝  g(j) / Σ_{m≠j} g(m),   g(j) = O / (O + p_{(Δᵢ,η)}(j)·I).

     We define `obsRaw`/`obsImplied` and prove the observer is positive and
     strictly DECREASING in the branch price `p(j)` (`obsRaw_strictAnti`): the
     observer downweights branches whose implied price is high (their `O`-side
     inventory is relatively scarce).

  2. CURVATURE-MATCHED COST.  The note pins the cost by `∂²C_κ/∂(Δ^O)² = |κ|`.
     The minimal such cost `C_κ(x) = (|κ|/2)x²` is `CFMM.Curvature.costQuad |κ|`
     (second installment).  The note ALSO writes an explicit composite cost
         C_κ(Δᵢ; j, η⋆) = 2κ(Δᵢ)(Δ^O(Δᵢ))² + χ(η_j(Δᵢ) − η_j⋆)²,
     for which `∂²/∂(Δ^O)² = 4κ` (`costComposite_secondDeriv_DO`).  ⚠ To match the
     curvature target `|κ|` the leading coefficient must be `|κ|/2`, not `2κ`;
     we record the literal computation and the correction.

  3. GIBBS (BOLTZMANN) OBSERVER and `∂η̃_i/∂Δᵢ < 0`.  Setting
         η̃_i ∝ exp(−β·C_κ(Δᵢ; i)),
     we define the softmax `gibbs`, prove it is a probability vector
     (`gibbs_pos`, `gibbs_sum_eq_one`) and compute its exact derivative
     (`gibbs_hasDerivAt`):
         ∂η̃_i/∂Δᵢ = −β·η̃_i·( C_i′ − Σ_k η̃_k C_k′ ).
     Hence `∂η̃_i/∂Δᵢ < 0` exactly when branch `i`'s marginal cost exceeds the
     observer-average marginal cost (`gibbs_deriv_neg`); in particular `β>0` and a
     rising own-cost (`C_i′ > ⟨C′⟩`) give the note's `∂η̃_i/∂Δᵢ < 0`.

  4. VARIANCE CAPACITY and the INTERIOR PROGRAM.  With the feedback weights the
     variance capacity is `Σ(Δᵢ) = Σ_j η̃_j(Δᵢ) α_j²` (`SigmaGibbs`), with
     derivative `Σ′(Δᵢ) = Σ_j (∂η̃_j/∂Δᵢ) α_j²` (`SigmaGibbs_hasDerivAt`).  The
     net objective `J(Δᵢ) = π⁺(Δᵢ) − C(Δᵢ) = Δᵢ²·Σ(Δᵢ) − C(Δᵢ)` has
         ∂J/∂Δᵢ = 2Δᵢ·Σ + Δᵢ²·Σ′ − C′      (`netObjective_hasDerivAt`),
     so an INTERIOR optimum `Δᵢ⋆≠0` satisfies the note's stationarity
         ∂π⁺/∂Δᵢ = 2Δᵢ⋆·Σ + Δᵢ⋆²·Σ′ = C′(Δᵢ⋆)   (`foc_net_interior`).

  5. ∂π⁺/∂η.  In the separable payoff `π⁺(Δᵢ,η)=Δᵢ²·Σ_j η̃_j(η) α_j²` the
     η-partial is `∂π⁺/∂η = Δᵢ²·Σ_j η̃_j′(η) α_j²` (`piPlus_partial_eta`,
     reusing `CFMM.DynamicsOpt`), and an interior η-optimum solves
     `Σ_j η̃_j′(η⋆) α_j² = 0` (`piPlus_foc_eta`).

  Imports `exp.eta`, `exp.BondingCurveCurvature` (`piPlusFB`, `kappa`, `DeltaO`),
  and `exp.DynamicsOptimization` (`piPlus` and its η-partial).  No new axiom.
-/
import Mathlib
import exp.eta
import exp.BondingCurveCurvature
import exp.DynamicsOptimization

open Real
open scoped BigOperators

namespace CFMM.InventoryObserver

variable {N : ℕ}

/-! ## 1. The inventory-implied observer -/

/-- Raw inventory-implied weight of a branch at implied price `p`:
    `g(p) = O / (O + p·I)`.  Larger `O`-side inventory (or smaller price) raises
    the weight. -/
noncomputable def obsRaw (O I p : ℝ) : ℝ := O / (O + p * I)

/-- The normalized inventory-implied observer with the note's leave-one-out
    denominator:
    `η̃_j ∝ g(j) / Σ_{m≠j} g(m)`. -/
noncomputable def obsImplied [Fintype (Fin N)] (O I : ℝ) (p : Fin N → ℝ) (j : Fin N) : ℝ :=
  obsRaw O I (p j) / (∑ m ∈ Finset.univ.erase j, obsRaw O I (p m))

/-
The raw observer weight is strictly positive for positive inventories and a
    nonnegative price.
-/
theorem obsRaw_pos (O I p : ℝ) (hO : 0 < O) (hI : 0 ≤ I) (hp : 0 ≤ p) :
    0 < obsRaw O I p := by
  exact div_pos hO ( by positivity )

/-
**The observer downweights high-price branches.**  `g(p)` is strictly
    decreasing in the branch price `p` (at fixed positive inventories).
-/
theorem obsRaw_strictAnti (O I : ℝ) (hO : 0 < O) (hI : 0 < I) :
    StrictAntiOn (obsRaw O I) (Set.Ici (0 : ℝ)) := by
  intro p hp q hq hpq;
  unfold obsRaw; rw [ div_lt_div_iff₀ ] <;> nlinarith [ hp.out, hq.out, mul_lt_mul_of_pos_left hpq hI ] ;

/-! ## 2. The curvature-matched / composite cost -/

/-- The explicit composite cost the note writes:
    `C_κ(Δᵢ; j, η⋆) = 2κ·(Δ^O)² + χ·(η_j − η_j⋆)²`. -/
noncomputable def costComposite (kap DO chi etaj etajstar : ℝ) : ℝ :=
  2 * kap * DO ^ 2 + chi * (etaj - etajstar) ^ 2

/-
First derivative of the composite cost in the produced output `Δ^O`
    (holding `κ, χ, η_j, η_j⋆` fixed): `∂C_κ/∂(Δ^O) = 4κ·Δ^O`.
-/
theorem costComposite_hasDerivAt_DO (kap DO chi etaj etajstar : ℝ) :
    HasDerivAt (fun y => costComposite kap y chi etaj etajstar) (4 * kap * DO) DO := by
  convert HasDerivAt.add ( HasDerivAt.const_mul ( 2 * kap ) ( hasDerivAt_pow 2 DO ) ) ( hasDerivAt_const _ _ ) using 1 ; ring!;

/-
**Second derivative of the literal composite cost in `Δ^O` is `4κ`.**
    ⚠ The note's curvature target is `∂²C_κ/∂(Δ^O)² = |κ|`; the literal leading
    coefficient `2κ` therefore over-shoots by a factor of 4.  To curvature-match,
    the coefficient must be `|κ|/2` (i.e. use `CFMM.Curvature.costQuad |κ|`).
-/
theorem costComposite_secondDeriv_DO (kap chi etaj etajstar DO : ℝ) :
    HasDerivAt (fun y => 4 * kap * y) (4 * kap) DO := by
  simpa using HasDerivAt.const_mul ( 4 * kap ) ( hasDerivAt_id DO )

/-! ## 3. The Gibbs (Boltzmann) observer and `∂η̃_i/∂Δᵢ` -/

/-- The Gibbs/Boltzmann observer `η̃_i ∝ exp(−β·C_i)`:
    `η̃_i = exp(−β·C_i) / Σ_k exp(−β·C_k)`. -/
noncomputable def gibbs (beta : ℝ) (C : Fin N → ℝ) (i : Fin N) : ℝ :=
  Real.exp (-beta * C i) / ∑ k, Real.exp (-beta * C k)

/-- The pointwise derivative value of a Gibbs component when the energies move
    along a curve with derivatives `d`:
    `∂η̃_i = −β·η̃_i·( d_i − Σ_k η̃_k d_k )`. -/
noncomputable def gibbsDeriv (beta : ℝ) (Cx d : Fin N → ℝ) (i : Fin N) : ℝ :=
  -beta * gibbs beta Cx i * (d i - ∑ k, gibbs beta Cx k * d k)

/-
The Gibbs partition denominator is strictly positive.
-/
theorem gibbs_denom_pos [Nonempty (Fin N)] (beta : ℝ) (C : Fin N → ℝ) :
    0 < ∑ k, Real.exp (-beta * C k) := by
  exact Finset.sum_pos ( fun _ _ => Real.exp_pos _ ) Finset.univ_nonempty

/-
Each Gibbs weight is strictly positive.
-/
theorem gibbs_pos [Nonempty (Fin N)] (beta : ℝ) (C : Fin N → ℝ) (i : Fin N) :
    0 < gibbs beta C i := by
  exact div_pos ( Real.exp_pos _ ) ( gibbs_denom_pos _ _ )

/-
The Gibbs weights sum to one: the observer is a probability vector.
-/
theorem gibbs_sum_eq_one [Nonempty (Fin N)] (beta : ℝ) (C : Fin N → ℝ) :
    ∑ i, gibbs beta C i = 1 := by
  unfold gibbs; rw [ ← Finset.sum_div ] ; exact div_self <| ne_of_gt <| gibbs_denom_pos beta C;

/-
**Exact derivative of a Gibbs component.**  If each energy `C_k` is
    differentiable along `Δᵢ` with derivative `d_k`, then
        ∂η̃_i/∂Δᵢ = −β·η̃_i·( d_i − Σ_k η̃_k d_k ).
-/
theorem gibbs_hasDerivAt [Nonempty (Fin N)] (beta : ℝ) (C : Fin N → ℝ → ℝ)
    (d : Fin N → ℝ) (i : Fin N) (x : ℝ) (hd : ∀ k, HasDerivAt (C k) (d k) x) :
    HasDerivAt (fun y => gibbs beta (fun k => C k y) i)
      (gibbsDeriv beta (fun k => C k x) d i) x := by
  unfold gibbs gibbsDeriv;
  convert HasDerivAt.div ( HasDerivAt.exp ( HasDerivAt.const_mul ( -beta ) ( hd i ) ) ) ( HasDerivAt.sum fun k _ => HasDerivAt.exp ( HasDerivAt.const_mul ( -beta ) ( hd k ) ) ) _ using 1 <;> norm_num [ gibbs ] ; ring;
  any_goals exact Finset.univ;
  · ext; simp +decide [ div_eq_mul_inv ] ;
  · field_simp;
    norm_num [ ← Finset.mul_sum _ _ _, ← Finset.sum_div, mul_assoc, mul_div_cancel₀, ne_of_gt ( Finset.sum_pos ( fun k _ => Real.exp_pos _ ) ( Finset.univ_nonempty ) ) ] ; ring;
    simp +decide [ mul_assoc, mul_comm, mul_left_comm, ne_of_gt ( Finset.sum_pos ( fun k _ => Real.exp_pos _ ) ( Finset.univ_nonempty ) ) ];
  · exact ne_of_gt <| Finset.sum_pos ( fun _ _ => Real.exp_pos _ ) Finset.univ_nonempty

/-
**`∂η̃_i/∂Δᵢ < 0`.**  With `β>0`, branch `i`'s marginal cost above the
    observer-average marginal cost (`d_i > Σ_k η̃_k d_k`) makes its Gibbs weight
    strictly decreasing — the note's `∂η̃_i/∂Δᵢ < 0`.
-/
theorem gibbs_deriv_neg [Nonempty (Fin N)] (beta : ℝ) (Cx d : Fin N → ℝ)
    (i : Fin N) (hbeta : 0 < beta)
    (hi : ∑ k, gibbs beta Cx k * d k < d i) :
    gibbsDeriv beta Cx d i < 0 := by
  exact mul_neg_of_neg_of_pos ( mul_neg_of_neg_of_pos ( neg_neg_of_pos hbeta ) ( gibbs_pos beta Cx i ) ) ( sub_pos_of_lt hi )

/-! ## 4. Variance capacity with feedback and the interior program -/

/-- The feedback variance capacity `Σ(Δᵢ) = Σ_j η̃_j(Δᵢ) α_j²` with Gibbs
    observer weights. -/
noncomputable def SigmaGibbs (beta : ℝ) (C : Fin N → ℝ → ℝ) (α : Fin N → ℝ) (x : ℝ) : ℝ :=
  ∑ j, gibbs beta (fun k => C k x) j * (α j) ^ 2

/-
`Σ(Δᵢ) ≥ 0`.
-/
theorem SigmaGibbs_nonneg [Nonempty (Fin N)] (beta : ℝ) (C : Fin N → ℝ → ℝ)
    (α : Fin N → ℝ) (x : ℝ) : 0 ≤ SigmaGibbs beta C α x := by
  exact Finset.sum_nonneg fun i _ => mul_nonneg ( le_of_lt ( gibbs_pos _ _ _ ) ) ( sq_nonneg _ )

/-
**`Σ′(Δᵢ) = Σ_j (∂η̃_j/∂Δᵢ) α_j²`.**  The variance capacity inherits the
    Gibbs feedback derivative.
-/
theorem SigmaGibbs_hasDerivAt [Nonempty (Fin N)] (beta : ℝ) (C : Fin N → ℝ → ℝ)
    (d : Fin N → ℝ) (α : Fin N → ℝ) (x : ℝ) (hd : ∀ k, HasDerivAt (C k) (d k) x) :
    HasDerivAt (SigmaGibbs beta C α)
      (∑ j, gibbsDeriv beta (fun k => C k x) d j * (α j) ^ 2) x := by
  convert HasDerivAt.fun_sum _;
  exact fun i _ => HasDerivAt.mul_const ( gibbs_hasDerivAt beta C d i x hd ) _

/-- The net objective `J(Δᵢ) = π⁺(Δᵢ) − C(Δᵢ) = Δᵢ²·Σ(Δᵢ) − C(Δᵢ)`. -/
noncomputable def netObjective (Sigma Cost : ℝ → ℝ) (x : ℝ) : ℝ :=
  CFMM.Curvature.piPlusFB Sigma x - Cost x

/-
**`∂J/∂Δᵢ = 2Δᵢ·Σ + Δᵢ²·Σ′ − C′`.**
-/
theorem netObjective_hasDerivAt (Sigma Cost : ℝ → ℝ) (Sigma' Cost' x : ℝ)
    (hS : HasDerivAt Sigma Sigma' x) (hC : HasDerivAt Cost Cost' x) :
    HasDerivAt (netObjective Sigma Cost)
      (2 * x * Sigma x + x ^ 2 * Sigma' - Cost') x := by
  convert HasDerivAt.sub ( CFMM.Curvature.piPlusFB_hasDerivAt Sigma Sigma' x hS ) hC using 1

/-
**Interior first-order condition for the trade size.**  At an interior
    maximizer `Δᵢ⋆ ≠ 0` of `J = π⁺ − C`,
        ∂π⁺/∂Δᵢ = 2Δᵢ⋆·Σ(Δᵢ⋆) + Δᵢ⋆²·Σ′(Δᵢ⋆) = C′(Δᵢ⋆),
    i.e. marginal long-vol payoff equals marginal cost.
-/
theorem foc_net_interior (Sigma Cost : ℝ → ℝ) (Sigma' Cost' Δistar : ℝ)
    (hS : HasDerivAt Sigma Sigma' Δistar) (hC : HasDerivAt Cost Cost' Δistar)
    (hmax : IsLocalMax (netObjective Sigma Cost) Δistar) :
    2 * Δistar * Sigma Δistar + Δistar ^ 2 * Sigma' = Cost' := by
  have := hmax.deriv_eq_zero; rw [ netObjective_hasDerivAt Sigma Cost Sigma' Cost' Δistar hS hC |> HasDerivAt.deriv ] at this; linarith;

/-! ## 5. The η-partial of π⁺ and the interior η-optimum -/

/-- **`∂π⁺/∂η = Δᵢ²·Σ_j η̃_j′(η) α_j²`** (reusing the separable payoff of
    `CFMM.DynamicsOpt`). -/
theorem piPlus_partial_eta (w : ℝ → Fin N → ℝ) (w' : Fin N → ℝ) (α : Fin N → ℝ)
    (Δi η : ℝ) (hd : ∀ j, HasDerivAt (fun y => w y j) (w' j) η) :
    HasDerivAt (fun y => CFMM.DynamicsOpt.piPlus w α Δi y)
      (Δi ^ 2 * ∑ j, w' j * (α j) ^ 2) η :=
  CFMM.DynamicsOpt.piPlus_hasDerivAt_eta w w' α Δi η hd

/-- **Interior η first-order condition.**  At an interior maximizer `η⋆` of
    `η ↦ π⁺(Δᵢ, η)` with non-degenerate spacing `Δᵢ ≠ 0`,
        Σ_j η̃_j′(η⋆) α_j² = 0. -/
theorem piPlus_foc_eta (w : ℝ → Fin N → ℝ) (w' : Fin N → ℝ) (α : Fin N → ℝ)
    (Δi ηstar : ℝ) (hΔi : Δi ≠ 0)
    (hd : ∀ j, HasDerivAt (fun y => w y j) (w' j) ηstar)
    (hmax : IsLocalMax (fun y => CFMM.DynamicsOpt.piPlus w α Δi y) ηstar) :
    ∑ j, w' j * (α j) ^ 2 = 0 :=
  CFMM.DynamicsOpt.foc_eta w w' α Δi ηstar hΔi hd hmax

end CFMM.InventoryObserver