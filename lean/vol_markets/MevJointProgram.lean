import Mathlib
import vol_markets.MevOptimization
import vol_markets.FlairOptimization

open scoped BigOperators Topology

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Joint sup-FLAIR / inf-MEV program

Unless `mevTotal` appears, the MEV-side quantities below are `λ_ARB`, not the total `λ_MEV`.
They are identified exactly by T30 when uniform batch clearing nulls the intra-batch sandwich
channel.  The objectives use the leading-order, fast-block, small-fee factorization
`ARB ≈ LVR · P_trade`, not an exact finite-`Δt` identity.  Neither functional contains demand
response to fees, so its corner solutions are properties of these volume-inelastic objectives,
not market equilibria; the missing term is the anchor's section 7.3 equation (27),
`E[delta-hedged LP P&L] = E[NT_FEE] - E[ARB]`.  Moreover `P_trade` is a steady-state quantity
used quasi-statically along varying-volatility paths, legitimate only if parameters move slowly
relative to mixing of the mispricing process.

T20--T22 refute an unconstrained trade-off in `Θ_φ`: the shape block `(β, γ)` is not essential.
It becomes relevant only under the fee-budget constraint studied at path level in T23--T25.
The alignment there is strong: identifying arbitrage weight `a` with traded-flow weight `w`
forces noise-trader flow to be proportional block-by-block to leading-order LVR.  Without it the
measures differ and the constrained conclusion can reverse.

Finally, `λ_MEV` covers only the two modelled channels, arbitrage and intra-batch sandwiching; it
is not all MEV.  Excluded are backruns of noise-trader flow; multi-block MEV (where censorship
lengthens effective `Δt` and attacks the cadence lever directly); JIT liquidity; and fixed gas
costs, which act as an additive fee and move `P_trade`.
-/

namespace MevJointProgram

/-- T20 / M6a(i): the same top level corner maximizes FLAIR and minimizes the arbitrage channel. -/
theorem joint_corner_degeneracy
    (n : ℕ) (γ β α αmax : ℕ → ℝ) (φbar φbarMax u uMax Δt : ℝ)
    (σpath w a D : ℕ → ℝ) (T : ℕ)
    (hφ0 : 0 ≤ φbar) (hφ : φbar ≤ φbarMax) (hu0 : 0 ≤ u) (hu : u ≤ uMax)
    (hα0 : ∀ j < n, 0 ≤ α j) (hαmax0 : ∀ j < n, 0 ≤ αmax j)
    (hα : ∀ j < n, α j ≤ αmax j)
    (hσ : ∀ t < T, 0 < σpath t) (hΔ : 0 < Δt)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) (ha : ∀ t < T, 0 ≤ a t) :
    FlairOptimization.flairMulti n γ β α φbar u σpath w D T ≤
      FlairOptimization.flairMulti n γ β αmax φbarMax uMax σpath w D T ∧
    MevOptimization.mevMulti n γ β αmax φbarMax uMax σpath a D Δt T ≤
      MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T := by
  constructor
  · exact FlairOptimization.flairMulti_corner_attained_levels n γ β α αmax φbar φbarMax u uMax
      σpath w D T hφ hu0 hu hα0 hαmax0 hα hD hw
  · exact MevOptimization.mevMulti_corner_attained_levels n γ β α αmax φbar φbarMax u uMax
      σpath a D Δt T hφ hφ0 hu0 hu hα0 hαmax0 hα ha hD hσ hΔ

/-- T21 / M6a(ii): lowering sigmoid centers improves both objectives.  Thus one common sequence
`β → -∞` drives FLAIR to its supremum and ARB to its infimum; the separate existing saturation
results show that neither endpoint is attained at finite `β`. -/
theorem joint_beta_degeneracy
    (n : ℕ) (γ β β' α : ℕ → ℝ) (φbar u Δt : ℝ)
    (σpath w a D : ℕ → ℝ) (T : ℕ)
    (hβ : ∀ j < n, β j ≤ β' j) (hγ : ∀ j < n, 0 < γ j)
    (hφ0 : 0 ≤ φbar) (hu0 : 0 ≤ u) (hα0 : ∀ j < n, 0 ≤ α j)
    (hσ : ∀ t < T, 0 < σpath t) (hΔ : 0 < Δt)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) (ha : ∀ t < T, 0 ≤ a t) :
    FlairOptimization.flairMulti n γ β' α φbar u σpath w D T ≤
      FlairOptimization.flairMulti n γ β α φbar u σpath w D T ∧
    MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T ≤
      MevOptimization.mevMulti n γ β' α φbar u σpath a D Δt T := by
  exact ⟨FlairOptimization.flairMulti_anti_beta n γ β β' α φbar u σpath w D T
      hβ hγ hu0 hα0 hD hw,
    MevOptimization.mevMulti_mono_beta n γ β β' α φbar u σpath a D Δt T
      hβ hγ hu0 hα0 hφ0 ha hD hσ hΔ⟩

/-- T22 / M6a(iii): no unconstrained trade-off in `Θ_φ`, robust under every nonnegative linear
weighting.  This is specifically a degeneracy of two volume-INELASTIC objectives: fee income is
fee times exogenous flow while ARB is antitone in fee.  With demand response FLAIR need not remain
monotone and the degeneracy dissolves; this is not a market-equilibrium claim. -/
theorem joint_scalarization_degeneracy
    (n : ℕ) (γ β α αmax : ℕ → ℝ) (φbar φbarMax u uMax Δt κ : ℝ)
    (σpath w a D : ℕ → ℝ) (T : ℕ) (hκ : 0 ≤ κ)
    (hφ0 : 0 ≤ φbar) (hφ : φbar ≤ φbarMax) (hu0 : 0 ≤ u) (hu : u ≤ uMax)
    (hα0 : ∀ j < n, 0 ≤ α j) (hαmax0 : ∀ j < n, 0 ≤ αmax j)
    (hα : ∀ j < n, α j ≤ αmax j)
    (hσ : ∀ t < T, 0 < σpath t) (hΔ : 0 < Δt)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) (ha : ∀ t < T, 0 ≤ a t) :
    FlairOptimization.flairMulti n γ β α φbar u σpath w D T
        - κ * MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T ≤
      FlairOptimization.flairMulti n γ β αmax φbarMax uMax σpath w D T
        - κ * MevOptimization.mevMulti n γ β αmax φbarMax uMax σpath a D Δt T := by
  obtain ⟨hf, hm⟩ := joint_corner_degeneracy n γ β α αmax φbar φbarMax u uMax Δt
    σpath w a D T hφ0 hφ hu0 hu hα0 hαmax0 hα hσ hΔ hD hw ha
  nlinarith

/-- Arbitrary fee-path FLAIR carrier.  Path level is M6b's quantification; schedule level is only
the subfamily reachable inside `Θ_φ`. -/
noncomputable def flairPath (φpath w D : ℕ → ℝ) (T : ℕ) : ℝ :=
  ∑ t ∈ Finset.range T, φpath t * w t / D t

/-- Arbitrary fee-path arbitrage carrier under the aligned traded-flow measure. -/
noncomputable def mevPath (φpath σpath w D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) : ℝ :=
  ∑ t ∈ Finset.range T, MevOptimization.ptrade (φpath t) (σpath t) Δt * w t / D t

/-- Path/schedule bridge: path level is the document's quantification and schedules are the
sub-family reachable inside `Θ_φ`. -/
theorem flairPath_schedule (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (T : ℕ) :
    flairPath (fun t => φfun (σpath t)) w D T =
      FlairOptimization.flairHazard φfun σpath w D T := rfl

/-- Path/schedule bridge: path level is the document's quantification and schedules are the
sub-family reachable inside `Θ_φ`. -/
theorem mevPath_schedule (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) :
    mevPath (fun t => φfun (σpath t)) σpath w D Δt T =
      MevOptimization.mevHazard φfun σpath w D Δt T := rfl

/-- T23: FLAIR is linear in the evaluated fee path. -/
theorem flair_budget_pins_mean_fee (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (T : ℕ) :
    FlairOptimization.flairHazard φfun σpath w D T =
      ∑ t ∈ Finset.range T, φfun (σpath t) * (w t / D t) := by
  simp [FlairOptimization.flairHazard, div_eq_mul_inv, mul_assoc]

/-- T23 mean form: a FLAIR budget fixes the weighted mean fee and nothing else, leaving fee-path
shape free for the convex ARB side. -/
theorem flair_budget_mean
    (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (B : ℝ) (T : ℕ)
    (hW : 0 < FlairOptimization.pathWeight w D T)
    (hbudget : FlairOptimization.flairHazard φfun σpath w D T = B) :
    ∑ t ∈ Finset.range T,
        φfun (σpath t) * ((w t / D t) / FlairOptimization.pathWeight w D T) =
      B / FlairOptimization.pathWeight w D T := by
  rw [← hbudget, flair_budget_pins_mean_fee]
  simp only [div_eq_mul_inv, mul_assoc, Finset.sum_mul]

/-- Path-level linear identity used by the constrained program. -/
theorem flairPath_sum (φpath w D : ℕ → ℝ) (T : ℕ) :
    flairPath φpath w D T = ∑ t ∈ Finset.range T, φpath t * (w t / D t) := by
  simp [flairPath, div_eq_mul_inv, mul_assoc]

/-- Path-level mean form of T23. -/
theorem flairPath_budget_mean
    (φpath w D : ℕ → ℝ) (B : ℝ) (T : ℕ)
    (hW : 0 < FlairOptimization.pathWeight w D T)
    (hbudget : flairPath φpath w D T = B) :
    ∑ t ∈ Finset.range T,
        φpath t * ((w t / D t) / FlairOptimization.pathWeight w D T) =
      B / FlairOptimization.pathWeight w D T := by
  rw [← hbudget, flairPath_sum]
  rw [Finset.sum_div]
  exact Finset.sum_congr rfl fun _ _ => (mul_div_assoc _ _ _).symm

/-- T24 refutation.  At the explicit witness volatility varies (`1` versus `10`), so the
constant-volatility hypothesis behind ordinary Jensen fails.  The fee is tilted toward the step
where trade probability is steeper, reversing the proposed inequality. -/
theorem mev_ge_flat_under_flair_budget_false :
    ¬ (∀ (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (Δt B : ℝ) (T : ℕ),
      0 < Δt → (∀ t < T, 0 < σpath t) → (∀ t < T, 0 ≤ w t) → (∀ t < T, 0 < D t) →
      0 < FlairOptimization.pathWeight w D T →
      (∀ t < T, 0 ≤ φfun (σpath t)) →
      FlairOptimization.flairHazard φfun σpath w D T = B →
      ∑ t ∈ Finset.range T,
          MevOptimization.ptrade (B / FlairOptimization.pathWeight w D T) (σpath t) Δt
            * (w t / D t) ≤
        MevOptimization.mevHazard φfun σpath w D Δt T) := by
  intro h
  let σpath : ℕ → ℝ := fun t => if t = 0 then 1 else 10
  let w : ℕ → ℝ := fun _ => 1
  let D : ℕ → ℝ := fun _ => 1
  let φfun : ℝ → ℝ := fun x => if x = 1 then 2 else 0
  have hh := h φfun σpath w D 2 2 2
  have hσ : ∀ t < 2, 0 < σpath t := by intro t ht; interval_cases t <;> norm_num [σpath]
  have hφ : ∀ t < 2, 0 ≤ φfun (σpath t) := by intro t ht; interval_cases t <;> norm_num [φfun, σpath]
  have hb : FlairOptimization.flairHazard φfun σpath w D 2 = 2 := by norm_num [FlairOptimization.flairHazard, φfun, σpath, w, D]
  have hc := hh (by norm_num) hσ (by intros; norm_num [w]) (by intros; norm_num [D]) (by norm_num [FlairOptimization.pathWeight, w, D]) hφ hb
  norm_num [Finset.sum_range_succ, MevOptimization.mevHazard, MevOptimization.ptrade, FlairOptimization.pathWeight, σpath, w, D, φfun] at hc


/-- T25: under the fee-budget constraint and aligned measure, a flat fee minimizes ARB when
volatility is constant.  This is about fee PATHS: inside `Θ_φ` at constant `σ`, every schedule
already yields a constant path, so strictness has no bite there; the varying-`σ` schedule claim is
refuted by T24's explicit witness. -/
theorem mev_ge_flat_under_flair_budget_const_sigma
    (φpath σpath w D : ℕ → ℝ) (Δt B σ0 : ℝ) (T : ℕ)
    (hΔ : 0 < Δt) (hσ0 : 0 < σ0) (hσ : ∀ t < T, σpath t = σ0)
    (hw : ∀ t < T, 0 ≤ w t) (hD : ∀ t < T, 0 < D t)
    (hW : 0 < FlairOptimization.pathWeight w D T)
    (hφ : ∀ t < T, 0 ≤ φpath t)
    (hbudget : flairPath φpath w D T = B) :
    FlairOptimization.pathWeight w D T *
        MevOptimization.ptrade (B / FlairOptimization.pathWeight w D T) σ0 Δt ≤
      mevPath φpath σpath w D Δt T := by
  -- Key: pathWeight = ∑ w t / D t
  let W := FlairOptimization.pathWeight w D T
  have hW_pos : 0 < W := hW
  -- Define normalized weights
  let ω : ℕ → ℝ := fun t => (w t / D t) / W
  -- ω sums to 1 on the range
  have hW_def : W = ∑ t ∈ Finset.range T, w t / D t := rfl
  have hω_sum : ∑ t ∈ Finset.range T, ω t = 1 := by
    simp only [ω]
    rw [← Finset.sum_div]
    rw [hW_def]
    exact div_self hW_pos.ne'
  -- ω is nonneg
  have hω_nonneg : ∀ t ∈ Finset.range T, 0 ≤ ω t := by
    intro t ht
    apply div_nonneg
    · exact div_nonneg (hw t (Finset.mem_range.mp ht)) (le_of_lt (hD t (Finset.mem_range.mp ht)))
    · exact le_of_lt hW_pos
  -- The fee path is nonneg on range
  have hφ_nonneg : ∀ t ∈ Finset.range T, 0 ≤ φpath t := by
    intro t ht
    exact hφ t (Finset.mem_range.mp ht)
  -- ptrade is convex on [0, ∞) for σ0 > 0 and Δt > 0
  have hconvex : ConvexOn ℝ (Set.Ici 0) (fun φ => MevOptimization.ptrade φ σ0 Δt) :=
    MevOptimization.ptrade_convexOn σ0 Δt hσ0 hΔ
  -- The average fee equals B / W
  have hφ_avg : ∑ t ∈ Finset.range T, ω t * φpath t = B / W := by
    simp only [ω]
    have h1 : ∑ t ∈ Finset.range T, w t / D t / W * φpath t =
              (∑ t ∈ Finset.range T, w t / D t * φpath t) / W := by
      rw [Finset.sum_div]
      exact Finset.sum_congr rfl fun t _ => by ring
    rw [h1]
    rw [← hbudget]
    congr 1
    exact Finset.sum_congr rfl fun t _ => by ring
  -- Apply Jensen's inequality
  have hjensen : MevOptimization.ptrade (∑ t ∈ Finset.range T, ω t * φpath t) σ0 Δt ≤
      ∑ t ∈ Finset.range T, ω t * MevOptimization.ptrade (φpath t) σ0 Δt := by
    apply hconvex.map_sum_le
    · exact hω_nonneg
    · exact hω_sum
    · exact hφ_nonneg
  -- Rewrite hjensen using hφ_avg
  rw [hφ_avg] at hjensen
  -- mevPath under constant volatility
  have hmevPath_eq : mevPath φpath σpath w D Δt T =
      ∑ t ∈ Finset.range T, MevOptimization.ptrade (φpath t) σ0 Δt * w t / D t := by
    simp [mevPath]
    exact Finset.sum_congr rfl fun t ht => by rw [hσ t (Finset.mem_range.mp ht)]
  rw [hmevPath_eq]
  -- Multiply hjensen by W
  have step1 : W * MevOptimization.ptrade (B / W) σ0 Δt ≤
      W * ∑ t ∈ Finset.range T, ω t * MevOptimization.ptrade (φpath t) σ0 Δt := by
    gcongr
  have step2 : W * ∑ t ∈ Finset.range T, ω t * MevOptimization.ptrade (φpath t) σ0 Δt =
      ∑ t ∈ Finset.range T, MevOptimization.ptrade (φpath t) σ0 Δt * w t / D t := by
    rw [Finset.mul_sum]
    apply Finset.sum_congr rfl
    intro t _
    simp only [ω]
    field_simp
  linarith

/-- Strict T25 companion.  We assume every in-range weight is strictly positive (rather than
restricting the index set) and exhibit two in-range fees that differ.  Under the fee-budget
constraint every nonconstant path then has strictly larger ARB than the flat path. -/
theorem mev_gt_flat_under_flair_budget_const_sigma
    (φpath σpath w D : ℕ → ℝ) (Δt B σ0 : ℝ) (T : ℕ)
    (hΔ : 0 < Δt) (hσ0 : 0 < σ0) (hσ : ∀ t < T, σpath t = σ0)
    (hw : ∀ t < T, 0 < w t) (hD : ∀ t < T, 0 < D t)
    (hW : 0 < FlairOptimization.pathWeight w D T)
    (hφ : ∀ t < T, 0 ≤ φpath t)
    (hbudget : flairPath φpath w D T = B)
    (hnconst : ∃ t₁ < T, ∃ t₂ < T, φpath t₁ ≠ φpath t₂) :
    FlairOptimization.pathWeight w D T *
        MevOptimization.ptrade (B / FlairOptimization.pathWeight w D T) σ0 Δt <
      mevPath φpath σpath w D Δt T := by
  -- Key: pathWeight = ∑ w t / D t
  let W := FlairOptimization.pathWeight w D T
  have hW_pos : 0 < W := hW
  -- Define normalized weights
  let ω : ℕ → ℝ := fun t => (w t / D t) / W
  -- ω sums to 1 on the range
  have hW_def : W = ∑ t ∈ Finset.range T, w t / D t := rfl
  have hω_sum : ∑ t ∈ Finset.range T, ω t = 1 := by
    simp only [ω]
    rw [← Finset.sum_div]
    rw [hW_def]
    exact div_self hW_pos.ne'
  -- ω is positive
  have hω_pos : ∀ t ∈ Finset.range T, 0 < ω t := by
    intro t ht
    apply div_pos
    · exact div_pos (hw t (Finset.mem_range.mp ht)) (hD t (Finset.mem_range.mp ht))
    · exact hW_pos
  -- The fee path is nonneg on range
  have hφ_nonneg : ∀ t ∈ Finset.range T, 0 ≤ φpath t := by
    intro t ht
    exact hφ t (Finset.mem_range.mp ht)
  -- ptrade is strictly convex on [0, ∞) for σ0 > 0 and Δt > 0
  have hstrict : StrictConvexOn ℝ (Set.Ici 0) (fun φ => MevOptimization.ptrade φ σ0 Δt) :=
    MevOptimization.ptrade_strictConvexOn σ0 Δt hσ0 hΔ
  -- The average fee equals B / W
  have hφ_avg : ∑ t ∈ Finset.range T, ω t * φpath t = B / W := by
    simp only [ω]
    have h1 : ∑ t ∈ Finset.range T, w t / D t / W * φpath t =
              (∑ t ∈ Finset.range T, w t / D t * φpath t) / W := by
      rw [Finset.sum_div]
      exact Finset.sum_congr rfl fun t _ => by ring
    rw [h1]
    rw [← hbudget]
    congr 1
    exact Finset.sum_congr rfl fun t _ => by ring
  -- mevPath under constant volatility
  have hmevPath_eq : mevPath φpath σpath w D Δt T =
      ∑ t ∈ Finset.range T, MevOptimization.ptrade (φpath t) σ0 Δt * w t / D t := by
    simp [mevPath]
    exact Finset.sum_congr rfl fun t ht => by rw [hσ t (Finset.mem_range.mp ht)]
  -- Get indices where fees differ
  obtain ⟨t₁, ht₁, t₂, ht₂, hne⟩ := hnconst
  -- Apply strict Jensen's inequality
  have hjensen : MevOptimization.ptrade (∑ t ∈ Finset.range T, ω t * φpath t) σ0 Δt <
      ∑ t ∈ Finset.range T, ω t * MevOptimization.ptrade (φpath t) σ0 Δt := by
    apply hstrict.map_sum_lt
    · exact fun t _ => hω_pos t ‹_›
    · exact hω_sum
    · exact hφ_nonneg
    · exact ⟨t₁, Finset.mem_range.mpr ht₁, t₂, Finset.mem_range.mpr ht₂, hne⟩
  -- Rewrite hjensen using hφ_avg
  rw [hφ_avg] at hjensen
  rw [hmevPath_eq]
  -- Multiply hjensen by W
  have step1 : W * MevOptimization.ptrade (B / W) σ0 Δt <
      W * ∑ t ∈ Finset.range T, ω t * MevOptimization.ptrade (φpath t) σ0 Δt := by
    gcongr
  have step2 : W * ∑ t ∈ Finset.range T, ω t * MevOptimization.ptrade (φpath t) σ0 Δt =
      ∑ t ∈ Finset.range T, MevOptimization.ptrade (φpath t) σ0 Δt * w t / D t := by
    rw [Finset.mul_sum]
    apply Finset.sum_congr rfl
    intro t _
    simp only [ω]
    field_simp
  linarith

/-- M7(i): LP-net ARBITRAGE hazard under rebate fraction `τ`, an LP-incidence object, not reduced
extraction.  It equals M7's `(1-τ)·λ_MEV` only through T30 when sandwich hazard is zero.  Extraction
invariance assumes searcher participation is inelastic in `τ`; as margins vanish participation may
lapse, distinct from monopoly/collusion lowering the realized rebate. -/
noncomputable def mevNet (τ : ℝ) (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) : ℝ :=
  (1 - τ) * MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T

/-- A rebate fraction in `[0,1]` lowers LP-net incidence, using model assumptions that imply ARB
nonnegativity rather than assuming that conclusion. -/
theorem mevNet_le_mev (τ : ℝ) (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) (hτ0 : 0 ≤ τ) (hτ1 : τ ≤ 1)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔ : 0 < Δt)
    (hφ : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u) :
    mevNet τ n γ β α φbar u σpath a D Δt T ≤
      MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T := by
  rw [mevNet]
  have hmev_nonneg := MevOptimization.mevMulti_nonneg n γ β α φbar u σpath a D Δt T
    ha hD hσ hΔ hφ hα hu
  nlinarith

/-- LP-net incidence is antitone in the rebate fraction. -/
theorem mevNet_anti_tau (τ τ' : ℝ) (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) (hτ : τ ≤ τ')
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔ : 0 < Δt)
    (hφ : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u) :
    mevNet τ' n γ β α φbar u σpath a D Δt T ≤
      mevNet τ n γ β α φbar u σpath a D Δt T := by
  unfold mevNet
  apply mul_le_mul_of_nonneg_right _ (MevOptimization.mevMulti_nonneg n γ β α φbar u σpath a D Δt T ha hD hσ hΔ hφ hα hu)
  linarith

/-- A full rebate leaves zero LP-borne arbitrage incidence. -/
theorem mevNet_eq_zero_of_tau_one (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) :
    mevNet 1 n γ β α φbar u σpath a D Δt T = 0 := by simp [mevNet]

/-- T27: for `τ < 1`, rebate changes the value but not the solution, formalizing that it lies
outside `Θ_φ`.  Strictness is necessary: at `τ = 1` the left objective is identically zero, so every
point is a minimizer while the right objective need not be minimized there; the equivalence is
false in general. -/
theorem mevNet_argmin_invariant (τ : ℝ) (hτ : τ < 1)
    (u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (Θ : Set (ℝ × ℝ × ℝ × ℝ)) (θ : ℝ × ℝ × ℝ × ℝ) :
    IsMinOn (fun θ : ℝ × ℝ × ℝ × ℝ =>
        mevNet τ 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1)
          θ.1 u σpath a D Δt T) Θ θ ↔
    IsMinOn (fun θ : ℝ × ℝ × ℝ × ℝ =>
        MevOptimization.mevMulti 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1)
          θ.1 u σpath a D Δt T) Θ θ := by
  have hpos : 0 < 1 - τ := by linarith
  constructor
  · intro hhyp θ' hθ'
    have := hhyp hθ'
    simp only [Set.mem_setOf_eq] at this
    unfold mevNet at this
    rwa [mul_le_mul_iff_right₀ hpos] at this
  · intro hhyp θ' hθ'
    unfold mevNet
    exact mul_le_mul_of_nonneg_left (hhyp hθ') (le_of_lt hpos)

/-- Parametric auction-tax ceiling `k/(k+1)`.  The dated 2026-07-30 l2-angstrom snapshot gives
`k = 49`, `τ = 0.98`, but live documentation differs on surrounding constants, so claims remain
parametric.  This map assumes bids use priority fees, full-value competition, and honest ordering;
monopoly/collusion can lower realized `τ`, and `priority_fee × gas` is a model assumption.  When
proceeds split among creator, protocol, and LP, LP incidence is `LPshare * k/(k+1)`, making this an
upper bound attained only by a pure-LP rebate; `mevNet`'s `τ` denotes actual LP incidence. -/
noncomputable def taxFraction (k : ℝ) : ℝ := k / (k + 1)

/-- Nonnegative tax parameters produce fractions in `[0,1)`. -/
theorem taxFraction_mem_Ico (k : ℝ) (hk : 0 ≤ k) : taxFraction k ∈ Set.Ico (0 : ℝ) 1 := by
  unfold taxFraction
  constructor
  · exact div_nonneg hk (by linarith)
  · exact (div_lt_one (by linarith)).mpr (by linarith)

/-- The parametric tax ceiling is monotone on nonnegative parameters. -/
theorem taxFraction_mono : MonotoneOn taxFraction (Set.Ici 0) := by
  intro x hx y hy hxy
  simp only [taxFraction, Set.mem_Ici] at *
  rw [div_le_div_iff₀ (by linarith : 0 < x + 1) (by linarith : 0 < y + 1)]
  linarith

/-- T29: ARB is isotone in mean interblock time at fixed per-block weights and horizon: more drift
accumulates between blocks.  This is the partial `ptrade` effect.  In M3(i), `a t` itself contains
`Δt`, and per-calendar-time `T ∝ 1/Δt`; both occurrences must be reconciled.  The diffusion scaling
is empirically supported only around one second and above; sub-second claims require an omitted
jump-diffusion extension.  `Δt` does not occur in `FlairOptimization.flairMulti`'s signature, which
is the formal content of 'the cadence lever does not enter FLAIR'; this is a fact about the type,
not a theorem. -/
theorem mev_mono_dt (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (T : ℕ) (Δt Δt' : ℝ)
    (hΔ : 0 < Δt) (hΔle : Δt ≤ Δt')
    (hφ0 : 0 ≤ φbar) (hu0 : 0 ≤ u) (hα0 : ∀ j < n, 0 ≤ α j)
    (hσ : ∀ t < T, 0 < σpath t)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t) :
    MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T ≤
      MevOptimization.mevMulti n γ β α φbar u σpath a D Δt' T := by
  unfold MevOptimization.mevMulti MevOptimization.mevHazard
  apply Finset.sum_le_sum
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  have hfee_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := by
    unfold VolInstrument.multiFee
    apply add_nonneg hφ0
    apply mul_nonneg _ hu0
    apply Finset.sum_nonneg
    intro j hj
    exact mul_nonneg (hα0 j (Finset.mem_range.mp hj))
      (le_of_lt (FeeSchedule.logistic_mem_Ioo _).1)
  have hΔ' : 0 < Δt' := lt_of_lt_of_le hΔ hΔle
  have hpm := MevOptimization.ptrade_monotoneOn_dt
    (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t)
      hfee_nonneg (hσ t ht')
  exact div_le_div_of_nonneg_right
    (mul_le_mul_of_nonneg_right (hpm hΔ hΔ' hΔle) (ha t ht'))
    (le_of_lt (hD t ht'))

/-- M7 total of the two modelled hazard channels: plain addition of rates.  This is `λ_MEV`;
`MevOptimization.mevMulti` is only `λ_ARB`.  No sandwich profit shape is modelled. -/
noncomputable def mevTotal (lamARB lamSand : ℝ) : ℝ := lamARB + lamSand

/-- Uniform batch clearing supplies zero intra-batch sandwich hazard, hence total equals ARB.  This
nulls internal ordering only, not cross-batch sandwich variants outside this model. -/
theorem mevTotal_eq_arb_of_sandwich_zero (lamARB : ℝ) : mevTotal lamARB 0 = lamARB := by
  simp [mevTotal]

/-- Under uniform clearing, zero intra-batch sandwich hazard is exactly why every T20--T25 statement
about `mevMulti` is also about total `λ_MEV`; cross-batch variants remain outside the aggregate. -/
theorem mevTotal_mevMulti_eq_of_sandwich_zero
    (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) :
    mevTotal (MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T) 0 =
      MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T := by
  simp [mevTotal]

/-- Probability-side `probOr` maps to plain hazard addition.  This is why `mevTotal` is `+`, not
`probOr`; the latter acts on probabilities in `[0,1]`, never directly on unbounded rates. -/
theorem mevTotal_probOr_hazard (lamARB lamSand : ℝ) :
    VolInstrument.probOr (1 - Real.exp (-lamARB)) (1 - Real.exp (-lamSand)) =
      1 - Real.exp (-(mevTotal lamARB lamSand)) := by
  simpa [mevTotal] using VolInstrument.probOr_hazard lamARB lamSand

end MevJointProgram
