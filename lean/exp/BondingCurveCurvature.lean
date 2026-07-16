/-
  exp/BondingCurveCurvature.lean

  Formal companion to the closing DYNAMICS note, second installment.  The note
  introduces the *bonding-curve curvature*

      κ  ≡  ∂²Δ^O / ∂p²

  of the output rule `Δ^O` viewed as a function of the (sqrt-)price `p` at fixed
  pool liquidity `L̄` and input size `Δ^I`, claims the closed form

      κ  =  − 2·Δ^I·L̄³ / (L̄ + Δ^I·p)³                            (note's eqn)

  and then deduces a chain of monotonicities:

      ∂|κ|/∂Δᵢ < 0,    ∂Δ^O/∂Δᵢ > 0,

  a quadratic cost `C_κ` with `∂²C_κ/∂(Δ^O)² = |κ|`, and the interior first-order
  condition for the trade size,

      ∂π⁺/∂Δᵢ ≡ Δᵢ·(2·Σ + Δᵢ·∂Σ/∂Δᵢ) = 0      ⇒   2·Σ + Δᵢ·∂Σ/∂Δᵢ = 0,

  once the variance capacity `Σ` is allowed to depend on `Δᵢ` through the
  inventory-weight feedback.

  RESULTS / VERIFICATION (all machine-checked below, no `sorry`).

  • `DeltaO_eq_model` : the model's `CFMM.Eta.Delta_O_half` equals the closed
    price-form `Δ^O(p) = L̄·Δ^I·p² / (L̄ + Δ^I·p)` (with `p = P_half …`).

  • `DeltaO_hasDerivAt` : ∂Δ^O/∂p = L̄·Δ^I·p·(2L̄ + Δ^I·p)/(L̄ + Δ^I·p)².

  • `kappa_eq_secondDeriv` : the curvature is exactly the second price-derivative,
    and its closed form is

        κ(p) = + 2·Δ^I·L̄³ / (L̄ + Δ^I·p)³.

    ⚠ SIGN CORRECTION.  The note writes this with a leading minus sign.  The
    correct curvature is POSITIVE (`kappa_pos`): the constant-product output rule
    is CONVEX in the price, so `∂²Δ^O/∂p² > 0`.  The *magnitude* `|κ|` in the
    note is, however, exactly right, and every downstream conclusion uses only
    `|κ|`, so the rest of the chain stands.

  • `abs_kappa_eq`, `kappa_strictAntiOn_p`, `abs_kappa_strictAnti_in_Δi` :
    `|κ| = κ`, `κ` is strictly decreasing in the price, hence — composing with
    the spacing→price map `P_half` (increasing in `Δᵢ` for `i>0`, `λ>1`) —
    `∂|κ|/∂Δᵢ < 0`.

  • `DeltaO_strictMonoOn_p`, `DeltaO_strictMono_in_Δi` : `Δ^O` is strictly
    increasing in the price and therefore strictly increasing in `Δᵢ`,
    confirming `∂Δ^O/∂Δᵢ > 0`.

  • `costQuad_hasDerivAt`, `costQuad_secondDeriv` : the quadratic cost
    `C_κ(x) = (|κ|/2)·x²` has `∂²C_κ/∂x² = |κ|`, the stated curvature-matching
    of the cost.

  • `piPlusFB_hasDerivAt`, `foc_interior` : with the feedback variance capacity
    `Σ : ℝ → ℝ` (now Δᵢ-dependent) and `π⁺(Δᵢ) = Δᵢ²·Σ(Δᵢ)`,

        ∂π⁺/∂Δᵢ = 2·Δᵢ·Σ(Δᵢ) + Δᵢ²·Σ′(Δᵢ),

    and an interior maximizer `Δᵢ⋆ ≠ 0` satisfies the note's stationarity
    condition `2·Σ(Δᵢ⋆) + Δᵢ⋆·Σ′(Δᵢ⋆) = 0`.

  Imports `exp.eta` only for the model primitives `P_half`, `Delta_O_half`,
  `P_half_post`, `P_half_pos`, `P_half_strictMono`.  No new economic primitive
  and no axiom beyond the standard `propext`/`Classical.choice`/`Quot.sound`.
-/
import Mathlib
import exp.eta

open Real
open scoped BigOperators

namespace CFMM.Curvature

open CFMM.Eta

/-! ## The output rule `Δ^O` as a function of the price `p` -/

/-- Output amount `Δ^O` as an explicit function of the (sqrt-)price `p`, with
    fixed pool liquidity `L` and input size `D = Δ^I`:
        `Δ^O(p) = L·D·p² / (L + D·p)`. -/
noncomputable def DeltaO (L D p : ℝ) : ℝ := L * D * p ^ 2 / (L + D * p)

/-- First price-derivative `∂Δ^O/∂p = L·D·p·(2L + D·p)/(L + D·p)²`. -/
noncomputable def DeltaO_deriv (L D p : ℝ) : ℝ :=
  L * D * p * (2 * L + D * p) / (L + D * p) ^ 2

/-- Bonding-curve curvature `κ = ∂²Δ^O/∂p² = 2·D·L³/(L + D·p)³`.

    NOTE the sign: the curvature is POSITIVE (the output rule is convex in the
    price); the note's leading minus sign is a typo, see `kappa_pos`. -/
noncomputable def kappa (L D p : ℝ) : ℝ := 2 * D * L ^ 3 / (L + D * p) ^ 3

/-
The model's `Delta_O_half` in closed price form: `Δ^O = DeltaO L̄ Δ^I P(i)`.
-/
theorem DeltaO_eq_model (lam Δi : ℝ) (i : Int) (L_bar Delta_I : ℝ)
    (hD : L_bar + Delta_I * P_half lam Δi i ≠ 0) :
    Delta_O_half lam Δi i L_bar Delta_I = DeltaO L_bar Delta_I (P_half lam Δi i) := by
  unfold Delta_O_half DeltaO P_half_post;
  grind

/-
`∂Δ^O/∂p = L·D·p·(2L + D·p)/(L + D·p)²`.
-/
theorem DeltaO_hasDerivAt (L D p : ℝ) (hp : L + D * p ≠ 0) :
    HasDerivAt (DeltaO L D) (DeltaO_deriv L D p) p := by
  convert HasDerivAt.div ( HasDerivAt.const_mul ( L * D ) ( hasDerivAt_pow 2 p ) ) ( HasDerivAt.add ( hasDerivAt_const _ _ ) ( HasDerivAt.const_mul D ( hasDerivAt_id _ ) ) ) _ using 1 <;> norm_num [ hp ];
  unfold DeltaO_deriv; ring;

/-
The curvature is exactly the second price-derivative `∂²Δ^O/∂p²`, with the
    closed form `κ(p) = 2·D·L³/(L + D·p)³`.
-/
theorem kappa_eq_secondDeriv (L D p : ℝ) (hp : L + D * p ≠ 0) :
    HasDerivAt (DeltaO_deriv L D) (kappa L D p) p := by
  convert HasDerivAt.div ( show HasDerivAt ( fun x : ℝ => L * D * x * ( 2 * L + D * x ) ) ( L * D * ( 2 * L + D * p ) + L * D * p * D ) p by
                            convert HasDerivAt.mul ( HasDerivAt.mul ( hasDerivAt_const _ _ ) ( hasDerivAt_id p ) ) ( HasDerivAt.add ( hasDerivAt_const _ _ ) ( HasDerivAt.mul ( hasDerivAt_const _ _ ) ( hasDerivAt_id p ) ) ) using 1 ; ring;
                            norm_num ; ring ) ( show HasDerivAt ( fun x : ℝ => ( L + D * x ) ^ 2 ) ( 2 * D * ( L + D * p ) ) p by
                                                                                                                                                        convert HasDerivAt.comp p ( hasDerivAt_pow 2 _ ) ( HasDerivAt.const_add _ ( HasDerivAt.const_mul _ ( hasDerivAt_id p ) ) ) using 1 ; ring! ) ( pow_ne_zero 2 hp ) using 1;
  grind +locals

/-
⚠ SIGN CORRECTION: the curvature is strictly POSITIVE for `L, D, p > 0`
    (the output rule is convex in the price), contradicting the note's leading
    minus sign.  The magnitude formula `|κ| = 2·D·L³/(L+D·p)³` is correct.
-/
theorem kappa_pos (L D p : ℝ) (hL : 0 < L) (hD : 0 < D) (hp : 0 < p) :
    0 < kappa L D p := by
  exact div_pos ( by positivity ) ( by exact pow_pos ( by positivity ) _ )

/-
`|κ| = κ` (the curvature is nonnegative).
-/
theorem abs_kappa_eq (L D p : ℝ) (hL : 0 < L) (hD : 0 < D) (hp : 0 < p) :
    |kappa L D p| = kappa L D p := by
  exact abs_of_pos ( kappa_pos L D p hL hD hp )

/-! ## `∂|κ|/∂Δᵢ < 0` : the curvature magnitude shrinks with the spacing -/

/-
`|κ|` is strictly decreasing in the price: larger `p` ⇒ smaller curvature.
-/
theorem kappa_strictAntiOn_p (L D : ℝ) (hL : 0 < L) (hD : 0 < D) :
    StrictAntiOn (kappa L D) (Set.Ioi (0 : ℝ)) := by
  intro p hp q hq hpq;
  unfold kappa;
  gcongr;
  · exact pow_pos ( add_pos hL ( mul_pos hD hp ) ) _;
  · nlinarith [ hp.out ]

/-
`∂|κ|/∂Δᵢ < 0`.  Composing `kappa_strictAntiOn_p` with the spacing→price map
    `P_half` (strictly increasing in `Δᵢ` for `i > 0`, `λ > 1`): a larger spacing
    yields a strictly smaller curvature magnitude.
-/
theorem abs_kappa_strictAnti_in_Δi (lam : ℝ) (i : Int) (L_bar Delta_I : ℝ)
    (hL : 0 < L_bar) (hD : 0 < Delta_I) (hlam : 1 < lam) (hi : 0 < i)
    (Δi Δi' : ℝ) (hΔ : Δi < Δi') :
    kappa L_bar Delta_I (P_half lam Δi' i) < kappa L_bar Delta_I (P_half lam Δi i) := by
  apply_rules [ kappa_strictAntiOn_p ];
  · exact P_half_pos lam Δi ( by positivity ) i;
  · exact P_half_pos _ _ ( by positivity ) _;
  · apply_rules [ P_half_strictMono ]

/-! ## `∂Δ^O/∂Δᵢ > 0` : output grows with the spacing -/

/-
`Δ^O` is strictly increasing in the price on `p > 0`.
-/
theorem DeltaO_strictMonoOn_p (L D : ℝ) (hL : 0 < L) (hD : 0 < D) :
    StrictMonoOn (DeltaO L D) (Set.Ioi (0 : ℝ)) := by
  intro p hp q hq hpq;
  unfold DeltaO;
  field_simp;
  rw [ div_lt_div_iff₀ ] <;> nlinarith [ mul_pos hD hp.out, mul_pos hD hq.out, mul_lt_mul_of_pos_left hpq hD, mul_lt_mul_of_pos_left hpq hL, mul_lt_mul_of_pos_left hpq ( mul_pos hD hL ), mul_lt_mul_of_pos_left hpq ( mul_pos hD hp.out ), mul_lt_mul_of_pos_left hpq ( mul_pos hD hq.out ) ]

/-
`∂Δ^O/∂Δᵢ > 0`.  Since `Δ^O` is increasing in the price and `P_half` is
    increasing in the spacing, the output strictly increases with `Δᵢ`.
-/
theorem DeltaO_strictMono_in_Δi (lam : ℝ) (i : Int) (L_bar Delta_I : ℝ)
    (hL : 0 < L_bar) (hD : 0 < Delta_I) (hlam : 1 < lam) (hi : 0 < i)
    (Δi Δi' : ℝ) (hΔ : Δi < Δi') :
    DeltaO L_bar Delta_I (P_half lam Δi i) < DeltaO L_bar Delta_I (P_half lam Δi' i) := by
  apply_rules [ DeltaO_strictMonoOn_p ];
  · exact P_half_pos _ _ ( by positivity ) _;
  · exact P_half_pos _ _ ( by positivity ) _;
  · apply P_half_strictMono;
    · bv_omega;
    · linarith;
    · linarith

/-! ## The curvature-matched quadratic cost `C_κ` -/

/-- Quadratic cost `C_κ(x) = (k/2)·x²` whose curvature in the output is the
    constant `k` (to be instantiated at `k = |κ|`). -/
noncomputable def costQuad (k x : ℝ) : ℝ := k / 2 * x ^ 2

/-
`∂C_κ/∂x = k·x`.
-/
theorem costQuad_hasDerivAt (k x : ℝ) :
    HasDerivAt (costQuad k) (k * x) x := by
  convert HasDerivAt.const_mul ( k / 2 ) ( hasDerivAt_pow 2 x ) using 1 ; ring

/-
`∂²C_κ/∂x² = k`.  With `k = |κ|` this is the note's curvature-matching
    `∂²C_κ/∂(Δ^O)² = |κ|`.
-/
theorem costQuad_secondDeriv (k x : ℝ) :
    HasDerivAt (fun y => k * y) k x := by
  convert ( hasDerivAt_mul_const k ) using 1;
  ac_rfl

/-! ## Interior first-order condition with the feedback variance capacity `Σ` -/

/-- The feedback long-vol payoff `π⁺(Δᵢ) = Δᵢ²·Σ(Δᵢ)`, where the variance
    capacity `Σ` is now allowed to depend on `Δᵢ` through the inventory-weight
    feedback `η̃(Δᵢ, η; π⁺)`. -/
noncomputable def piPlusFB (Sigma : ℝ → ℝ) (Δi : ℝ) : ℝ := Δi ^ 2 * Sigma Δi

/-
`∂π⁺/∂Δᵢ = 2·Δᵢ·Σ(Δᵢ) + Δᵢ²·Σ′(Δᵢ)` — the note's
    `∂π⁺/∂Δᵢ = 2·Δᵢ·Σ + Δᵢ²·∂Σ/∂Δᵢ`.
-/
theorem piPlusFB_hasDerivAt (Sigma : ℝ → ℝ) (Sigma' Δi : ℝ)
    (hS : HasDerivAt Sigma Sigma' Δi) :
    HasDerivAt (piPlusFB Sigma) (2 * Δi * Sigma Δi + Δi ^ 2 * Sigma') Δi := by
  convert HasDerivAt.mul ( hasDerivAt_pow 2 Δi ) hS using 1 ; ring

/-
Interior first-order condition for the trade-size optimum.  If `Δᵢ⋆ ≠ 0` is
    an interior maximizer of `π⁺`, the note's stationarity condition holds:

        2·Σ(Δᵢ⋆) + Δᵢ⋆·Σ′(Δᵢ⋆) = 0.
-/
theorem foc_interior (Sigma : ℝ → ℝ) (Sigma' Δistar : ℝ) (hΔi : Δistar ≠ 0)
    (hS : HasDerivAt Sigma Sigma' Δistar)
    (hmax : IsLocalMax (piPlusFB Sigma) Δistar) :
    2 * Sigma Δistar + Δistar * Sigma' = 0 := by
  exact mul_left_cancel₀ hΔi <| by linarith [ hmax.deriv_eq_zero, ( piPlusFB_hasDerivAt Sigma Sigma' Δistar hS ) |> HasDerivAt.deriv ] ;

end CFMM.Curvature