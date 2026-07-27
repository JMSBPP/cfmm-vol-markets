import Mathlib
import vol_markets.Panoptic
import vol_markets.Upsilon
import vol_markets.GeomProfile
import vol_markets.FeeSchedule

open scoped BigOperators

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Volatility instruments

This file formalizes the well-posed mathematical claims in
`VOLATILITY_INSTRUMENTS.md`.  It reuses the project's payoff, Greek, geometric
liquidity, price-grid, flow, fee, and risk declarations rather than replacing
those interfaces.  The path integral and econometric prose are intentionally
outside scope.  Mathlib's `max` and `min` already carry their usual join/meet
semilattice laws; the sequential fee operation is developed explicitly below.
-/

namespace VolInstrument

/-! ## Pricing geometry (`Θ_p = {η, Δi}`) -/

/-- Pricing-kernel geometry.  The identifier `η` is used only as this exponent
parameter, while `Δi` denotes tick spacing. -/
noncomputable def priceEta (η Δi i : ℝ) : ℝ :=
  PosSpec.lam ^ ((i / 2) * Δi * η)

lemma priceEta_pos (η Δi i : ℝ) : 0 < priceEta η Δi i := by
  unfold priceEta
  exact Real.rpow_pos_of_pos PosSpec.lam_pos _

lemma priceEta_strictMono (η Δi : ℝ) (h : 0 < η * Δi) :
    StrictMono (priceEta η Δi) := by
  intro i k hik
  unfold priceEta
  apply Real.rpow_lt_rpow_of_exponent_lt PosSpec.one_lt_lam
  nlinarith

lemma priceEta_one (Δi i : ℝ) : priceEta 1 Δi i = PosSpec.tickPrice Δi i := by
  unfold priceEta PosSpec.tickPrice
  congr 1
  ring

/-! ## Per-tick amounts and finite cumulative amounts -/

noncomputable def deltaQM (η Δi i L : ℝ) : ℝ :=
  L * ((priceEta η Δi (i + Δi) - priceEta η Δi i) /
    (priceEta η Δi i * priceEta η Δi (i + Δi)))

noncomputable def deltaQX (η Δi i L : ℝ) : ℝ :=
  L * (priceEta η Δi (i + Δi) - priceEta η Δi i)

lemma deltaQM_token0 (η Δi i L : ℝ) :
    deltaQM η Δi i L =
      L * (1 / priceEta η Δi i - 1 / priceEta η Δi (i + Δi)) := by
  unfold deltaQM
  have h₁ := ne_of_gt (priceEta_pos η Δi i)
  have h₂ := ne_of_gt (priceEta_pos η Δi (i + Δi))
  field_simp

/-- Nonnegativity along the forward grid additionally requires positive tick
spacing.  This condition is mathematically necessary: `η * Δi > 0` alone also
allows both parameters to be negative, in which case `i + Δi < i`. -/
lemma deltaQX_nonneg (η Δi i L : ℝ) (hL : 0 ≤ L) (hstep : 0 < η * Δi)
    (hΔi : 0 ≤ Δi) : 0 ≤ deltaQX η Δi i L := by
  unfold deltaQX
  exact mul_nonneg hL (sub_nonneg.mpr
    ((priceEta_strictMono η Δi hstep).monotone (by linarith)))

lemma deltaQM_nonneg (η Δi i L : ℝ) (hL : 0 ≤ L) (hstep : 0 < η * Δi)
    (hΔi : 0 ≤ Δi) : 0 ≤ deltaQM η Δi i L := by
  rw [deltaQM_token0]
  apply mul_nonneg hL
  have hprice : priceEta η Δi i ≤ priceEta η Δi (i + Δi) :=
    (priceEta_strictMono η Δi hstep).monotone (by linarith)
  exact sub_nonneg.mpr (one_div_le_one_div_of_le (priceEta_pos η Δi i) hprice)

/-- Cumulative token-M amount along the first `n` grid intervals. -/
noncomputable def cumulativeQM (η Δi iMin : ℝ) (L : ℕ → ℝ) (n : ℕ) : ℝ :=
  ∑ j ∈ Finset.range n, deltaQM η Δi (iMin + (j : ℝ) * Δi) (L j)

/-- Cumulative token-X amount along the first `n` grid intervals. -/
noncomputable def cumulativeQX (η Δi iMin : ℝ) (L : ℕ → ℝ) (n : ℕ) : ℝ :=
  ∑ j ∈ Finset.range n, deltaQX η Δi (iMin + (j : ℝ) * Δi) (L j)

lemma cumulativeQM_succ (η Δi iMin : ℝ) (L : ℕ → ℝ) (n : ℕ) :
    cumulativeQM η Δi iMin L (n + 1) = cumulativeQM η Δi iMin L n +
      deltaQM η Δi (iMin + (n : ℝ) * Δi) (L n) := by
  simp [cumulativeQM, Finset.sum_range_succ]

lemma cumulativeQX_succ (η Δi iMin : ℝ) (L : ℕ → ℝ) (n : ℕ) :
    cumulativeQX η Δi iMin L (n + 1) = cumulativeQX η Δi iMin L n +
      deltaQX η Δi (iMin + (n : ℝ) * Δi) (L n) := by
  simp [cumulativeQX, Finset.sum_range_succ]

lemma cumulativeQM_monotone (η Δi iMin : ℝ) (L : ℕ → ℝ)
    (hL : ∀ j, 0 ≤ L j) (hstep : 0 < η * Δi) (hΔi : 0 ≤ Δi) :
    Monotone (cumulativeQM η Δi iMin L) := by
  apply monotone_nat_of_le_succ
  intro n
  rw [cumulativeQM_succ]
  exact le_add_of_nonneg_right (deltaQM_nonneg _ _ _ _ (hL n) hstep hΔi)

lemma cumulativeQX_monotone (η Δi iMin : ℝ) (L : ℕ → ℝ)
    (hL : ∀ j, 0 ≤ L j) (hstep : 0 < η * Δi) (hΔi : 0 ≤ Δi) :
    Monotone (cumulativeQX η Δi iMin L) := by
  apply monotone_nat_of_le_succ
  intro n
  rw [cumulativeQX_succ]
  exact le_add_of_nonneg_right (deltaQX_nonneg _ _ _ _ (hL n) hstep hΔi)

lemma grid_succ (iMin Δi : ℝ) (j : ℕ) :
    iMin + (j : ℝ) * Δi + Δi = iMin + ((j + 1 : ℕ) : ℝ) * Δi := by
  push_cast
  ring

lemma cumulativeQX_const (η Δi iMin c : ℝ) (n : ℕ) :
    cumulativeQX η Δi iMin (fun _ => c) n =
      c * (priceEta η Δi (iMin + (n : ℝ) * Δi) - priceEta η Δi iMin) := by
  induction n with
  | zero => simp [cumulativeQX]
  | succ n ih =>
      rw [cumulativeQX_succ, ih]
      unfold deltaQX
      rw [grid_succ]
      ring

lemma cumulativeQM_const (η Δi iMin c : ℝ) (n : ℕ) :
    cumulativeQM η Δi iMin (fun _ => c) n =
      c * (1 / priceEta η Δi iMin -
        1 / priceEta η Δi (iMin + (n : ℝ) * Δi)) := by
  induction n with
  | zero => simp [cumulativeQM]
  | succ n ih =>
      rw [cumulativeQM_succ, ih, deltaQM_token0, grid_succ]
      ring

/-- If a cumulative target is attained by step `N`, the well-ordering of `ℕ`
provides a least attaining step (the rigorous discrete inverse cumulative). -/
lemma exists_least_reaching (Q : ℕ → ℝ) (Qbar : ℝ) (N : ℕ)
    (hN : Qbar ≤ Q N) :
    ∃ n, n ≤ N ∧ Qbar ≤ Q n ∧ ∀ m, Qbar ≤ Q m → n ≤ m := by
  let P : ℕ → Prop := fun n => Qbar ≤ Q n
  have hex : ∃ n, P n := ⟨N, hN⟩
  refine ⟨Nat.find hex, Nat.find_min' hex hN, Nat.find_spec hex, ?_⟩
  intro m hm
  exact Nat.find_min' hex hm

/-! ## Flow region -/

/-- The document's flow region.  The abstract exogenous flow is represented by
its two leg increments; `Real.sqrt` makes the definition total. -/
noncomputable def flowRegion (a b : ℝ) : ℝ := Real.sqrt a * Real.sqrt b

/-- Flow region at one tick, exposing the document's endogenous per-tick legs
plus the two exogenous flow differences. -/
noncomputable def tickFlowRegion
    (η Δi i L dQM dQX : ℝ) : ℝ :=
  flowRegion (deltaQM η Δi i L + dQM) (deltaQX η Δi i L + dQX)

lemma flowRegion_sq (a b : ℝ) (ha : 0 ≤ a) (hb : 0 ≤ b) :
    flowRegion a b ^ 2 = a * b := by
  unfold flowRegion
  rw [mul_pow, Real.sq_sqrt ha, Real.sq_sqrt hb]

lemma tickFlowRegion_sq (η Δi i L dQM dQX : ℝ)
    (hM : 0 ≤ deltaQM η Δi i L + dQM)
    (hX : 0 ≤ deltaQX η Δi i L + dQX) :
    tickFlowRegion η Δi i L dQM dQX ^ 2 =
      (deltaQM η Δi i L + dQM) * (deltaQX η Δi i L + dQX) := by
  exact flowRegion_sq _ _ hM hX

lemma flowRegion_mono_left {a a' b : ℝ} (haa : a ≤ a') :
    flowRegion a b ≤ flowRegion a' b := by
  unfold flowRegion
  exact mul_le_mul_of_nonneg_right (Real.sqrt_le_sqrt haa) (Real.sqrt_nonneg _)

lemma flowRegion_mono_right {a b b' : ℝ} (hbb : b ≤ b') :
    flowRegion a b ≤ flowRegion a b' := by
  unfold flowRegion
  exact mul_le_mul_of_nonneg_left (Real.sqrt_le_sqrt hbb) (Real.sqrt_nonneg _)

/-! ## Multi-sigmoid fees (`Θ_φ = {γ, φbar, β, α}`) -/

/-- Utilization multiplier.  The ratio argument `x` remains abstract because the
document does not specify behavior when its flow-region denominator vanishes. -/
noncomputable def utilization (αR γR βR x : ℝ) : ℝ :=
  αR * FeeSchedule.logistic (γR * (x - βR))

/-- Finite multi-sigmoid schedule, indexed by `Finset.range n`. -/
noncomputable def multiFee (n : ℕ) (γ β α : ℕ → ℝ) (φbar u σ : ℝ) : ℝ :=
  φbar + (∑ j ∈ Finset.range n,
    α j * FeeSchedule.logistic (γ j * (σ - β j))) * u

lemma utilization_mem (αR γR βR x : ℝ) (hαR : 0 ≤ αR) :
    utilization αR γR βR x ∈ Set.Icc 0 αR := by
  obtain ⟨h0, h1⟩ := FeeSchedule.logistic_mem_Ioo (γR * (x - βR))
  unfold utilization
  constructor <;> nlinarith

lemma multiFee_bounds (n : ℕ) (γ β α : ℕ → ℝ) (φbar u σ : ℝ)
    (hα : ∀ j ∈ Finset.range n, 0 ≤ α j) (hu : 0 ≤ u) :
    φbar ≤ multiFee n γ β α φbar u σ ∧
      multiFee n γ β α φbar u σ ≤ φbar + (∑ j ∈ Finset.range n, α j) * u := by
  have hterm : ∀ j ∈ Finset.range n,
      0 ≤ α j * FeeSchedule.logistic (γ j * (σ - β j)) ∧
      α j * FeeSchedule.logistic (γ j * (σ - β j)) ≤ α j := by
    intro j hj
    obtain ⟨h0, h1⟩ := FeeSchedule.logistic_mem_Ioo (γ j * (σ - β j))
    constructor <;> nlinarith [hα j hj]
  have hlo : 0 ≤ ∑ j ∈ Finset.range n,
      α j * FeeSchedule.logistic (γ j * (σ - β j)) :=
    Finset.sum_nonneg (fun j hj => (hterm j hj).1)
  have hhi : (∑ j ∈ Finset.range n,
      α j * FeeSchedule.logistic (γ j * (σ - β j))) ≤
      ∑ j ∈ Finset.range n, α j :=
    Finset.sum_le_sum (fun j hj => (hterm j hj).2)
  unfold multiFee
  constructor <;> nlinarith [mul_le_mul_of_nonneg_right hhi hu]

lemma multiFee_monotone (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (hγ : ∀ j ∈ Finset.range n, 0 < γ j)
    (hα : ∀ j ∈ Finset.range n, 0 ≤ α j) (hu : 0 ≤ u) :
    Monotone (multiFee n γ β α φbar u) := by
  intro σ τ hστ
  unfold multiFee
  apply add_le_add_right
  apply mul_le_mul_of_nonneg_right _ hu
  apply Finset.sum_le_sum
  intro j hj
  apply mul_le_mul_of_nonneg_left _ (hα j hj)
  apply FeeSchedule.logistic_strictMono.monotone
  nlinarith [hγ j hj]

lemma multiFee_single_bridge (γ0 φbar β0 α0 σ : ℝ) (_hγ : 0 < γ0) :
    multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => α0) φbar 1 σ =
      FeeSchedule.feeRaw φbar (φbar + α0) β0 γ0⁻¹ σ := by
  unfold multiFee FeeSchedule.feeRaw
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add,
    mul_one, add_sub_cancel_left]
  congr 2
  unfold FeeSchedule.logistic
  congr 2
  field_simp

/-! ## Sequential fee composition -/

/-- Probabilistic OR, the sequential charging operation. -/
def probOr (a b : ℝ) : ℝ := a + b - a * b

lemma probOr_eq (a b : ℝ) : probOr a b = 1 - (1 - a) * (1 - b) := by
  unfold probOr; ring

lemma probOr_comm (a b : ℝ) : probOr a b = probOr b a := by
  unfold probOr; ring

lemma probOr_assoc (a b c : ℝ) : probOr (probOr a b) c = probOr a (probOr b c) := by
  unfold probOr; ring

lemma probOr_zero (a : ℝ) : probOr a 0 = a := by
  unfold probOr; ring

lemma zero_probOr (a : ℝ) : probOr 0 a = a := by
  rw [probOr_comm, probOr_zero]

lemma probOr_mem_Icc {a b : ℝ} (ha : a ∈ Set.Icc (0 : ℝ) 1)
    (hb : b ∈ Set.Icc (0 : ℝ) 1) : probOr a b ∈ Set.Icc (0 : ℝ) 1 := by
  rw [probOr_eq]
  constructor
  · have ha0 : 0 ≤ 1 - a := sub_nonneg.mpr ha.2
    have hb0 : 0 ≤ 1 - b := sub_nonneg.mpr hb.2
    have ha1 : 1 - a ≤ 1 := by linarith [ha.1]
    have hprod : (1 - a) * (1 - b) ≤ 1 * 1 :=
      mul_le_mul ha1 (by linarith [hb.1]) hb0 (by norm_num)
    linarith
  · nlinarith [mul_nonneg (sub_nonneg.mpr ha.2) (sub_nonneg.mpr hb.2)]

lemma probOr_mono {a a' b b' : ℝ} (ha : a ≤ a') (hb : b ≤ b')
    (ha' : a' ≤ 1) (hb' : b' ≤ 1) : probOr a b ≤ probOr a' b' := by
  rw [probOr_eq, probOr_eq]
  have h1 : 0 ≤ 1 - a' := sub_nonneg.mpr ha'
  have h2 : 0 ≤ 1 - b' := sub_nonneg.mpr hb'
  have hm : (1 - a') * (1 - b') ≤ (1 - a) * (1 - b) :=
    mul_le_mul (by linarith) (by linarith) h2 (by linarith)
  linarith

lemma probOr_hazard (lamM lamX : ℝ) :
    probOr (1 - Real.exp (-lamM)) (1 - Real.exp (-lamX)) =
      1 - Real.exp (-(lamM + lamX)) := by
  rw [probOr_eq]
  rw [show (1 - (1 - Real.exp (-lamM))) = Real.exp (-lamM) by ring,
    show (1 - (1 - Real.exp (-lamX))) = Real.exp (-lamX) by ring,
    ← Real.exp_add]
  congr 2
  ring

/-! ## Demeterfi log portfolio and variance sensitivity -/

noncomputable def logPortfolio (p pStar : ℝ) : ℝ :=
  (p - pStar) / pStar - Real.log (p / pStar)

noncomputable def variancePortfolio (p pStar sig2 t : ℝ) : ℝ :=
  logPortfolio p pStar + sig2 * t / 2

lemma logPortfolio_nonneg (p pStar : ℝ) (hp : 0 < p) (hps : 0 < pStar) :
    0 ≤ logPortfolio p pStar := by
  have hx : 0 < p / pStar := div_pos hp hps
  have hlog := Real.log_le_sub_one_of_pos hx
  unfold logPortfolio
  have halg : (p - pStar) / pStar = p / pStar - 1 := by
    field_simp [ne_of_gt hps]
  rw [halg]
  linarith

lemma logPortfolio_atm (pStar : ℝ) (hps : pStar ≠ 0) :
    logPortfolio pStar pStar = 0 := by
  simp [logPortfolio, hps]

lemma variancePortfolio_upsilon (p pStar sig2 t Δs : ℝ) (hΔ : Δs ≠ 0) :
    Upsilon.upsilon (fun s2 => variancePortfolio p pStar s2 t) sig2 Δs = t / 2 := by
  unfold Upsilon.upsilon variancePortfolio
  field_simp
  ring

lemma variancePortfolio_unit_upsilon (p pStar sig2 t Δs : ℝ)
    (ht : t ≠ 0) (hΔ : Δs ≠ 0) :
    Upsilon.upsilon (fun s2 => (2 / t) * variancePortfolio p pStar s2 t)
      sig2 Δs = 1 := by
  unfold Upsilon.upsilon variancePortfolio
  field_simp
  ring

/-! ## Existing-interface bridges -/

lemma realizedVariancePayoff_bridge (sig2R sig2K : ℝ) :
    max 0 (sig2R - sig2K) = Panoptic.volOptionPayoff 1 sig2R sig2K := by
  simp [Panoptic.volOptionPayoff]

/-- The document's strike weights are exactly the existing geometric profile. -/
lemma strikeWeight_bridge (ξ : ℝ) (ι iK : ℕ) :
    ξ ^ iK / ((1 - ξ ^ ι) / (1 - ξ)) = GeomProfile.geomWeight ξ ι iK := by
  unfold GeomProfile.geomWeight
  field_simp

end VolInstrument
