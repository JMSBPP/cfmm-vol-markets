import vol_markets.EtaCurvature

open Set Filter
open scoped Topology

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Trading-curve substitution parameter

This file formalizes blocks S0–S3 of `ETATILDE_ADDENDUM.md`.  The document's
`η̃` is named `etaTilde`.  Its logistic is the existing
`FeeSchedule.logistic`; the tick base is the existing `PosSpec.lam`, and the
only curvature index used here is `EtaCurvature.curvIndex`.
-/

namespace EtaTilde

/-- The trading-curve substitution parameter (asset value share). -/
noncomputable def etaTilde (η Δi : ℝ) : ℝ :=
  FeeSchedule.logistic (η * Δi * Real.log PosSpec.lam / 2)

/-- The unbounded price-grid exponent recovered from an asset share. -/
noncomputable def etaOfTilde (t Δi : ℝ) : ℝ :=
  2 * Real.log (t / (1 - t)) / (Δi * Real.log PosSpec.lam)

/-- Curvature expressed in terms of the trading-curve share. -/
noncomputable def curvOfTilde (t Δi : ℝ) : ℝ :=
  1 - ((1 - t) / t) ^ Δi

/-- The trading-curve share recovered from curvature. -/
noncomputable def tildeOfCurv (c Δi : ℝ) : ℝ :=
  1 / (1 + (1 - c) ^ (1 / Δi))

/-- **A1.** The share odds equal the per-tick price multiplier. -/
theorem etaTilde_ratio (η Δi : ℝ) :
    etaTilde η Δi / (1 - etaTilde η Δi) =
      PosSpec.lam ^ (η * Δi / 2) := by
  unfold etaTilde
  set z := η * Δi * Real.log PosSpec.lam / 2 with hz
  simp only [FeeSchedule.logistic]
  have hexp_pos : 0 < Real.exp (-z) := Real.exp_pos _
  have hdenom_pos : 0 < 1 + Real.exp (-z) := by linarith
  have h1_sub : 1 - 1 / (1 + Real.exp (-z)) = Real.exp (-z) / (1 + Real.exp (-z)) := by
    field_simp; ring
  rw [h1_sub]
  field_simp
  ring_nf
  rw [← Real.exp_log (PosSpec.lam_pos)]
  rw [← Real.exp_mul]
  rw [← Real.exp_add]
  simp [hz]
  ring_nf
  rw [Real.exp_zero]

/-- **A2.** The share odds are the observable adjacent-tick square-root-price
step of the existing price grid. -/
theorem etaTilde_eq_priceEta_step (η Δi i : ℝ) :
    etaTilde η Δi / (1 - etaTilde η Δi) =
      VolInstrument.priceEta η Δi (i + 1) /
        VolInstrument.priceEta η Δi i := by
  rw [etaTilde_ratio]
  unfold VolInstrument.priceEta
  rw [← Real.rpow_sub (by exact PosSpec.lam_pos)]
  congr 1
  ring

/-- **B1.** Every finite exponent and spacing induces a genuine share. -/
theorem etaTilde_mem_Ioo (η Δi : ℝ) :
    etaTilde η Δi ∈ Ioo (0 : ℝ) 1 := by
  exact FeeSchedule.logistic_mem_Ioo _

/-- **B2.** For positive spacing, the share is strictly increasing in the
price-grid exponent. -/
theorem etaTilde_strictMono {Δi : ℝ} (hΔi : 0 < Δi) :
    StrictMono (fun η => etaTilde η Δi) := by
  unfold etaTilde
  apply StrictMono.comp FeeSchedule.logistic_strictMono
  have hlam : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hcoeff : 0 < Δi * Real.log PosSpec.lam / 2 := by positivity
  have : (fun η => η * Δi * Real.log PosSpec.lam / 2) = (fun η => η * (Δi * Real.log PosSpec.lam / 2)) := by
    ext η; ring
  rw [this]
  exact strictMono_id.mul_const hcoeff

/-- **B3a.** Recovering the exponent after applying the logistic is the
identity.  Positive spacing is needed to divide by `Δi`. -/
theorem etaOfTilde_etaTilde {Δi : ℝ} (η : ℝ) (hΔi : 0 < Δi) :
    etaOfTilde (etaTilde η Δi) Δi = η := by
  unfold etaOfTilde etaTilde
  set x := η * Δi * Real.log PosSpec.lam / 2 with hx_def
  -- Key: logistic(x) = 1 / (1 + exp(-x)) and odds = exp(x)
  have hlam_pos : 0 < PosSpec.lam := PosSpec.lam_pos
  have hlam_ne_one : PosSpec.lam ≠ 1 := ne_of_gt PosSpec.one_lt_lam
  have hlog_lam_pos : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hlog_lam_ne_zero : Real.log PosSpec.lam ≠ 0 := ne_of_gt hlog_lam_pos
  -- Key lemma: logistic x / (1 - logistic x) = exp x
  unfold FeeSchedule.logistic
  have hexp_neg_x_pos : 0 < Real.exp (-x) := Real.exp_pos _
  have h1_add_exp_pos : 0 < 1 + Real.exp (-x) := by linarith
  have h1_add_exp_ne_zero : 1 + Real.exp (-x) ≠ 0 := ne_of_gt h1_add_exp_pos
  -- Simplify: (1/(1+exp(-x))) / (1 - 1/(1+exp(-x))) = exp(x)
  have hOdds : (1 / (1 + Real.exp (-x))) / (1 - 1 / (1 + Real.exp (-x))) = Real.exp x := by
    have h_sub : 1 - 1 / (1 + Real.exp (-x)) = Real.exp (-x) / (1 + Real.exp (-x)) := by
      field_simp
      ring
    rw [h_sub]
    field_simp
    rw [Real.exp_neg x]
    field_simp
  rw [hOdds]
  rw [Real.log_exp]
  rw [hx_def]
  field_simp

/-- **B3b.** Applying the logistic after recovering an exponent is the
identity on genuine shares.  Membership in `(0,1)` guards both the logarithm
and odds denominator; positive spacing guards division by `Δi`. -/
theorem etaTilde_etaOfTilde {t Δi : ℝ} (ht : t ∈ Ioo (0 : ℝ) 1)
    (hΔi : 0 < Δi) : etaTilde (etaOfTilde t Δi) Δi = t := by
  have h := etaOfTilde_etaTilde (etaOfTilde t Δi) hΔi
  have h1 : etaTilde (etaOfTilde t Δi) Δi ∈ Ioo (0 : ℝ) 1 := etaTilde_mem_Ioo _ _
  have h2 : t ∈ Ioo (0 : ℝ) 1 := ht
  -- etaOfTilde is strictly monotonic on (0,1), so injective
  have hinj : StrictMonoOn (fun t => etaOfTilde t Δi) (Ioo (0 : ℝ) 1) := by
    intro t₁ ht₁ t₂ ht₂ hlt
    unfold etaOfTilde
    have hlam_pos : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
    have hdenom_pos : 0 < Δi * Real.log PosSpec.lam := by positivity
    have hdiv_pos : 0 < 2 / (Δi * Real.log PosSpec.lam) := by positivity
    -- Need to show: 2 * log(t₁/(1-t₁)) / denom < 2 * log(t₂/(1-t₂)) / denom
    suffices hlog : Real.log (t₁ / (1 - t₁)) < Real.log (t₂ / (1 - t₂)) by
      calc 2 * Real.log (t₁ / (1 - t₁)) / (Δi * Real.log PosSpec.lam)
          = (2 / (Δi * Real.log PosSpec.lam)) * Real.log (t₁ / (1 - t₁)) := by ring
        _ < (2 / (Δi * Real.log PosSpec.lam)) * Real.log (t₂ / (1 - t₂)) := by nlinarith
        _ = 2 * Real.log (t₂ / (1 - t₂)) / (Δi * Real.log PosSpec.lam) := by ring
    apply Real.log_lt_log
    · exact div_pos ht₁.1 (by linarith [ht₁.2])
    · have h1 : 0 < 1 - t₁ := by linarith [ht₁.2]
      have h2 : 0 < 1 - t₂ := by linarith [ht₂.2]
      have hcross : t₁ * (1 - t₂) < t₂ * (1 - t₁) := by nlinarith [ht₁.1, ht₁.2, ht₂.1, ht₂.2, hlt]
      have : t₁ / (1 - t₁) < t₂ / (1 - t₂) := by
        rw [div_lt_div_iff₀ h1 h2]
        exact hcross
      exact this
  exact hinj.injOn h1 h2 h

/-- **B4.** A symmetric pool is exactly a flat price grid. -/
theorem etaTilde_half_iff {η Δi : ℝ} (hΔi : 0 < Δi) :
    etaTilde η Δi = (1 / 2 : ℝ) ↔ η = 0 := by
  constructor
  · intro h
    -- If etaTilde η Δi = 1/2, then using etaTilde_ratio, lam^(η * Δi / 2) = 1
    have horris : etaTilde η Δi / (1 - etaTilde η Δi) = PosSpec.lam ^ (η * Δi / 2) := etaTilde_ratio η Δi
    rw [h] at horris
    simp at horris
    -- Now horris : 1 = lam^(η * Δi / 2)
    have hlam_gt1 : 1 < PosSpec.lam := PosSpec.one_lt_lam
    have hlam_pos : 0 < PosSpec.lam := PosSpec.lam_pos
    have hsimpl : (2⁻¹ : ℝ) / (1 - 2⁻¹) = 1 := by norm_num
    rw [hsimpl] at horris
    set hx := η * Δi / 2 with hx_def
    by_cases hpos : hx > 0
    · have hgt : PosSpec.lam ^ hx > 1 := Real.one_lt_rpow hlam_gt1 hpos
      linarith
    · by_cases hneg : hx < 0
      · have hlt : PosSpec.lam ^ hx < 1 := Real.rpow_lt_one_of_one_lt_of_neg hlam_gt1 hneg
        linarith
      · push_neg at hpos hneg
        have hzero : η * Δi / 2 = 0 := by linarith
        rw [div_eq_zero_iff] at hzero
        rcases hzero with h | h
        · exact mul_eq_zero.mp h |> Or.resolve_right <| hΔi.ne'
        · linarith
  · intro h
    rw [h]
    unfold etaTilde
    simp [FeeSchedule.logistic]
    norm_num

/-- **B5a.** The share tends to one as the exponent tends to `+∞`. -/
theorem etaTilde_tendsto_atTop {Δi : ℝ} (hΔi : 0 < Δi) :
    Tendsto (fun η => etaTilde η Δi) atTop (𝓝 (1 : ℝ)) := by
  unfold etaTilde
  have hlam_pos : 0 < PosSpec.lam := PosSpec.lam_pos
  have hlam_gt1 : 1 < PosSpec.lam := PosSpec.one_lt_lam
  have hlog_lam_pos : 0 < Real.log PosSpec.lam := Real.log_pos hlam_gt1
  have hinner : Filter.Tendsto (fun η => η * Δi * Real.log PosSpec.lam / 2) atTop Filter.atTop := by
    have h1 : Filter.Tendsto (fun η => η * Δi) atTop Filter.atTop :=
      Filter.Tendsto.atTop_mul_const hΔi Filter.tendsto_id
    have h2 : Filter.Tendsto (fun η => η * Δi * Real.log PosSpec.lam) atTop Filter.atTop :=
      Filter.Tendsto.atTop_mul_const hlog_lam_pos h1
    have h3 : Filter.Tendsto (fun η => η * Δi * Real.log PosSpec.lam / 2) atTop Filter.atTop := by
      convert Filter.Tendsto.atTop_div_const (by norm_num : (0 : ℝ) < 2) h2 using 1
    exact h3
  exact FeeSchedule.logistic_tendsto_atTop.comp hinner

/-- **B5b.** The share tends to zero as the exponent tends to `-∞`. -/
theorem etaTilde_tendsto_atBot {Δi : ℝ} (hΔi : 0 < Δi) :
    Tendsto (fun η => etaTilde η Δi) atBot (𝓝 (0 : ℝ)) := by
  unfold etaTilde
  have hlam_pos : 0 < PosSpec.lam := PosSpec.lam_pos
  have hlam_gt1 : 1 < PosSpec.lam := PosSpec.one_lt_lam
  have hlog_lam_pos : 0 < Real.log PosSpec.lam := Real.log_pos hlam_gt1
  have hinner : Filter.Tendsto (fun η => η * Δi * Real.log PosSpec.lam / 2) atBot Filter.atBot := by
    have h1 : Filter.Tendsto (fun η => η * Δi) atBot Filter.atBot :=
      Filter.Tendsto.atBot_mul_const hΔi Filter.tendsto_id
    have h2 : Filter.Tendsto (fun η => η * Δi * Real.log PosSpec.lam) atBot Filter.atBot :=
      Filter.Tendsto.atBot_mul_const hlog_lam_pos h1
    have h3 : Filter.Tendsto (fun η => η * Δi * Real.log PosSpec.lam / 2) atBot Filter.atBot := by
      convert Filter.Tendsto.atBot_div_const (by norm_num : (0 : ℝ) < 2) h2 using 1
    exact h3
  exact FeeSchedule.logistic_tendsto_atBot.comp hinner

/-- **C1.** Headline bridge from the asset share to the existing curvature
index: the inverse per-tick step is raised to the spacing. -/
theorem curvIndex_eq_of_etaTilde (η Δi : ℝ) :
    EtaCurvature.curvIndex η Δi =
      1 - ((1 - etaTilde η Δi) / etaTilde η Δi) ^ Δi := by
  have h1 : (1 - etaTilde η Δi) / etaTilde η Δi = (etaTilde η Δi / (1 - etaTilde η Δi))⁻¹ := by
    field_simp
  rw [h1, etaTilde_ratio]
  rw [EtaCurvature.curvIndex]
  congr 1
  have h : (PosSpec.lam ^ (η * Δi / 2))⁻¹ = PosSpec.lam ^ (-(η * Δi / 2)) := by
    rw [Real.rpow_neg (le_of_lt PosSpec.lam_pos)]
  rw [h]
  rw [← Real.rpow_mul (le_of_lt PosSpec.lam_pos)]
  congr 1
  ring

/-- **C2.** The share-curvature map composes with `etaTilde` to the existing
curvature index. -/
theorem curvOfTilde_etaTilde (η Δi : ℝ) :
    curvOfTilde (etaTilde η Δi) Δi =
      EtaCurvature.curvIndex η Δi := by
  rw [curvIndex_eq_of_etaTilde]
  rfl

/-- **C3.** The curvature inverse is a round trip on genuine shares at positive
spacing.  The `(0,1)` share domain makes every real-power base positive, and
`0 < Δi` makes the reciprocal exponent valid.  The second conjunct records
that this is the existing `EtaCurvature.curvIndex`, not a second curvature. -/
theorem tildeOfCurv_curvOfTilde {t Δi : ℝ} (ht : t ∈ Ioo (0 : ℝ) 1)
    (hΔi : 0 < Δi) :
    tildeOfCurv (curvOfTilde t Δi) Δi = t ∧
      curvOfTilde t Δi = EtaCurvature.curvIndex (etaOfTilde t Δi) Δi := by
  unfold tildeOfCurv curvOfTilde
  constructor
  · -- First part: 1 / (1 + (1 - (1 - ((1 - t) / t) ^ Δi)) ^ (1 / Δi)) = t
    have h1 : (1 - t) / t > 0 := div_pos (by linarith [ht.2]) ht.1
    have h2 : ((1 - t) / t) ^ Δi > 0 := Real.rpow_pos_of_pos h1 Δi
    have h3 : ((1 - t) / t) ^ Δi ≠ 0 := ne_of_gt h2
    have h4 : (1 - t) / t ≠ 0 := ne_of_gt h1
    rw [sub_sub_cancel]
    rw [← Real.rpow_mul (le_of_lt h1)]
    simp [hΔi.ne']
    rw [one_add_div ht.1.ne']
    field_simp
    ring
  · -- Second part: 1 - ((1 - t) / t) ^ Δi = curvIndex (etaOfTilde t Δi) Δi
    unfold EtaCurvature.curvIndex etaOfTilde
    have h1 : (1 - t) / t > 0 := div_pos (by linarith [ht.2]) ht.1
    have ht_div : t / (1 - t) > 0 := div_pos ht.1 (by linarith [ht.2])
    have hlam_pos : (0 : ℝ) < PosSpec.lam := PosSpec.lam_pos
    have hlam_ne_one : PosSpec.lam ≠ 1 := by norm_num [PosSpec.lam]
    have hlog_lam_ne_zero : Real.log PosSpec.lam ≠ 0 := Real.log_ne_zero_of_pos_of_ne_one hlam_pos hlam_ne_one
    have hΔi_ne_zero : Δi ≠ 0 := hΔi.ne'
    -- Simplify exponent: -(Δi ^ 2 * (2 * Real.log (t / (1 - t)) / (Δi * Real.log lam))) / 2
    -- = -Δi * Real.log (t / (1 - t)) / Real.log lam
    -- = Δi * Real.log ((1 - t) / t) / Real.log lam
    -- = Δi * Real.logb lam ((1 - t) / t)
    have exponent_simp : -(Δi ^ 2 * (2 * Real.log (t / (1 - t)) / (Δi * Real.log PosSpec.lam))) / 2 =
      Δi * Real.logb PosSpec.lam ((1 - t) / t) := by
      rw [Real.logb]
      have h_log_inv : Real.log ((1 - t) / t) = -Real.log (t / (1 - t)) := by
        rw [← Real.log_inv, inv_div]
      field_simp
      rw [h_log_inv]
    rw [exponent_simp]
    rw [Real.rpow_mul (le_of_lt hlam_pos)]
    conv_rhs => rw [← Real.rpow_mul (le_of_lt hlam_pos)]
    rw [mul_comm]
    rw [Real.rpow_mul (le_of_lt hlam_pos)]
    have logb_eq : PosSpec.lam ^ Real.logb PosSpec.lam ((1 - t) / t) = (1 - t) / t :=
      Real.rpow_logb hlam_pos hlam_ne_one h1
    rw [logb_eq]

/-- **C4 (corrected).** At positive spacing, curvature is strictly increasing
(not decreasing) on genuine shares, vanishes exactly at the symmetric share,
and agrees with the existing curvature index after conversion to `η`.  The
requested strict-antitonicity has its direction reversed: increasing the asset
share decreases `(1-t)/t`, hence increases `1 - ((1-t)/t)^Δi`. -/
theorem curvOfTilde_strictMono {Δi : ℝ} (hΔi : 0 < Δi) :
    StrictMonoOn (fun t => curvOfTilde t Δi) (Ioo (0 : ℝ) 1) ∧
      ∀ t ∈ Ioo (0 : ℝ) 1,
        (curvOfTilde t Δi = 0 ↔ t = (1 / 2 : ℝ)) ∧
        curvOfTilde t Δi = EtaCurvature.curvIndex (etaOfTilde t Δi) Δi := by
  constructor
  · -- StrictMonoOn part
    intro t1 ht1 t2 ht2 hlt
    unfold curvOfTilde
    -- Need: 1 - ((1 - t1) / t1) ^ Δi < 1 - ((1 - t2) / t2) ^ Δi
    -- i.e., ((1 - t2) / t2) ^ Δi < ((1 - t1) / t1) ^ Δi
    have h1 : (1 - t1) / t1 > 0 := div_pos (by linarith [ht1.2]) ht1.1
    have h2 : (1 - t2) / t2 > 0 := div_pos (by linarith [ht2.2]) ht2.1
    have hlt' : (1 - t2) / t2 < (1 - t1) / t1 := by
      rw [div_lt_div_iff₀ ht2.1 ht1.1]
      nlinarith [ht1.1, ht1.2, ht2.1, ht2.2, hlt]
    have := Real.rpow_lt_rpow (le_of_lt h2) hlt' hΔi
    linarith
  · -- Universal quantifier part
    intro t ht
    constructor
    · constructor
      · intro h
        unfold curvOfTilde at h
        have h1 : (1 - t) / t > 0 := div_pos (by linarith [ht.2]) ht.1
        have h2 : ((1 - t) / t) ^ Δi = 1 := by linarith
        have h3 : (1 - t) / t = 1 := by
          by_contra hne
          rcases lt_or_gt_of_ne hne with hlt | hgt
          · have : ((1 - t) / t) ^ Δi < 1 := Real.rpow_lt_one h1.le hlt hΔi
            linarith
          · have : ((1 - t) / t) ^ Δi > 1 := Real.one_lt_rpow hgt hΔi
            linarith
        field_simp at h3
        rw [div_eq_iff ht.1.ne'] at h3
        linarith
      · intro h
        subst h
        unfold curvOfTilde
        norm_num
    · have := curvOfTilde_etaTilde (etaOfTilde t Δi) Δi
      rw [etaTilde_etaOfTilde ht hΔi] at this
      exact this

/-- **C4 refutation.** The requested strict-decrease assertion is false, even
at spacing one; the values at shares `1/4 < 3/4` occur in increasing order.
The final conjunct ties the counterexample's curvature to the existing index. -/
theorem not_curvOfTilde_strictAnti :
    ¬ StrictAntiOn (fun t => curvOfTilde t 1) (Ioo (0 : ℝ) 1) ∧
      curvOfTilde (1 / 4 : ℝ) 1 =
        EtaCurvature.curvIndex (etaOfTilde (1 / 4 : ℝ) 1) 1 := by
  constructor
  · -- Counterexample: 1/4 < 3/4 but curvOfTilde (1/4) 1 < curvOfTilde (3/4) 1
    intro h
    have h1 : (1/4 : ℝ) ∈ Ioo (0 : ℝ) 1 := by norm_num
    have h2 : (3/4 : ℝ) ∈ Ioo (0 : ℝ) 1 := by norm_num
    have hab : (1/4 : ℝ) < 3/4 := by norm_num
    have := h h1 h2 hab
    norm_num [curvOfTilde] at this
  · have h := curvOfTilde_etaTilde (etaOfTilde (1/4) 1) 1
    rw [etaTilde_etaOfTilde (by norm_num : (1/4 : ℝ) ∈ Ioo 0 1) one_pos] at h
    exact h

/-- **C5.** On the genuine-share domain and at positive spacing, curvature is
in `(0,1)` exactly on the asset-heavy half.  The explicit `t ∈ (0,1)`
hypothesis is necessary: outside it, `Real.rpow` uses `log |x|`, so the
unguarded equivalence is false.  The second conjunct identifies the quantity
with the existing curvature index. -/
theorem curvOfTilde_mem_Ioo {t Δi : ℝ} (ht : t ∈ Ioo (0 : ℝ) 1)
    (hΔi : 0 < Δi) :
    (curvOfTilde t Δi ∈ Ioo (0 : ℝ) 1 ↔ t ∈ Ioo (1 / 2 : ℝ) 1) ∧
      curvOfTilde t Δi = EtaCurvature.curvIndex (etaOfTilde t Δi) Δi := by
  unfold curvOfTilde
  refine ⟨?_, ?_⟩
  · -- curvOfTilde t Δi = 1 - ((1 - t) / t) ^ Δi ∈ Ioo 0 1 ↔ t ∈ Ioo (1/2) 1
    have ht_pos : t > 0 := ht.1
    have ht_lt_1 : t < 1 := ht.2
    have h1mt_t_pos : (1 - t) / t > 0 := div_pos (by linarith) ht_pos
    have hball : ((1 - t) / t) ^ Δi > 0 := Real.rpow_pos_of_pos h1mt_t_pos Δi
    have hball_ne_zero : ((1 - t) / t) ^ Δi ≠ 0 := ne_of_gt hball
    -- 1 - x ∈ Ioo 0 1 iff x ∈ (0, 1)
    -- This means ((1-t)/t)^Δi ∈ (0, 1) iff t ∈ (1/2, 1)
    constructor
    · intro h
      -- If 1 - ((1-t)/t)^Δi ∈ Ioo 0 1, then ((1-t)/t)^Δi ∈ Ioo 0 1
      have hball_lt_1 : ((1 - t) / t) ^ Δi < 1 := by linarith [h.1]
      have hball_pos : 0 < ((1 - t) / t) ^ Δi := hball
      -- Since Δi > 0, ((1-t)/t)^Δi < 1 iff (1-t)/t < 1
      have h_ratio_lt_1 : (1 - t) / t < 1 := by
        by_contra h_ge
        push_neg at h_ge
        have h_ge_1 : ((1 - t) / t) ^ Δi ≥ 1 := Real.one_le_rpow h_ge (le_of_lt hΔi)
        have := h.1
        linarith
      -- (1 - t) / t < 1 iff 1 - t < t iff t > 1/2
      have ht_gt_half : t > 1 / 2 := by
        have : (1 - t) / t < 1 := h_ratio_lt_1
        have : 1 - t < t := by
          rwa [div_lt_one ht_pos] at this
        linarith
      exact ⟨ht_gt_half, ht_lt_1⟩
    · intro h
      -- If t ∈ Ioo (1/2) 1, show 1 - ((1-t)/t)^Δi ∈ Ioo 0 1
      have ht_gt_half : t > 1 / 2 := h.1
      -- (1 - t) / t < 1 since t > 1/2
      have h_ratio_lt_1 : (1 - t) / t < 1 := by
        rw [div_lt_one ht_pos]
        linarith
      -- 0 < (1 - t) / t since t ∈ (0, 1)
      have h_ratio_pos : 0 < (1 - t) / t := h1mt_t_pos
      have hball_lt_1 : ((1 - t) / t) ^ Δi < 1 := by
        apply Real.rpow_lt_one h_ratio_pos.le h_ratio_lt_1 hΔi
      constructor <;> linarith
  · unfold EtaCurvature.curvIndex etaOfTilde
    have h1 : (1 - t) / t > 0 := div_pos (by linarith [ht.2]) ht.1
    have ht_div : t / (1 - t) > 0 := div_pos ht.1 (by linarith [ht.2])
    have hlam_pos : (0 : ℝ) < PosSpec.lam := PosSpec.lam_pos
    have hlam_ne_one : PosSpec.lam ≠ 1 := by norm_num [PosSpec.lam]
    have hlog_lam_ne_zero : Real.log PosSpec.lam ≠ 0 := Real.log_ne_zero_of_pos_of_ne_one hlam_pos hlam_ne_one
    have hΔi_ne_zero : Δi ≠ 0 := hΔi.ne'
    have exponent_simp : -(Δi ^ 2 * (2 * Real.log (t / (1 - t)) / (Δi * Real.log PosSpec.lam))) / 2 =
      Δi * Real.logb PosSpec.lam ((1 - t) / t) := by
      rw [Real.logb]
      have h_log_inv : Real.log ((1 - t) / t) = -Real.log (t / (1 - t)) := by
        rw [← Real.log_inv, inv_div]
      field_simp
      rw [h_log_inv]
    rw [exponent_simp]
    rw [Real.rpow_mul (le_of_lt hlam_pos)]
    conv_rhs => rw [← Real.rpow_mul (le_of_lt hlam_pos)]
    rw [mul_comm]
    rw [Real.rpow_mul (le_of_lt hlam_pos)]
    have logb_eq : PosSpec.lam ^ Real.logb PosSpec.lam ((1 - t) / t) = (1 - t) / t :=
      Real.rpow_logb hlam_pos hlam_ne_one h1
    rw [logb_eq]

/-- **D1.** Analytic and economic admissibility coincide.  The first condition
`0 < η * Δi` is exactly the step hypothesis required by
`VolInstrument.deltaQM_nonneg`; positive spacing is additionally assumed here
to identify the sign of `η`. -/
theorem admissible_iff {η Δi : ℝ} (hΔi : 0 < Δi) :
    (0 < η * Δi ↔ (1 / 2 : ℝ) < etaTilde η Δi) ∧
    ((1 / 2 : ℝ) < etaTilde η Δi ↔
      EtaCurvature.curvIndex η Δi ∈ Ioo (0 : ℝ) 1) := by
  have hmono := etaTilde_strictMono hΔi
  have h0 : etaTilde 0 Δi = 1 / 2 := by rw [etaTilde_half_iff hΔi |>.mpr rfl]
  have hmem : etaTilde η Δi ∈ Ioo (0 : ℝ) 1 := etaTilde_mem_Ioo _ _
  constructor
  · constructor
    · intro h
      have : 0 < η := by nlinarith
      have : etaTilde η Δi > etaTilde 0 Δi := hmono this
      linarith [h0]
    · intro h
      have hpos : 0 < η := by
        by_contra hf
        push_neg at hf
        cases lt_or_eq_of_le hf with
        | inl hneg =>
          have : etaTilde η Δi < etaTilde 0 Δi := hmono hneg
          linarith [h0]
        | inr heq =>
          subst heq; linarith [h0]
      nlinarith
  · rw [← curvOfTilde_etaTilde]
    have := curvOfTilde_mem_Ioo hmem hΔi
    rw [this.1]
    simp only [Set.mem_Ioo]
    exact ⟨fun h => ⟨h, hmem.2⟩, fun h => h.1⟩

/-- **D2.** Flat exponent, symmetric share, and zero existing curvature are
equivalent at positive spacing. -/
theorem zero_curv_iff {η Δi : ℝ} (hΔi : 0 < Δi) :
    (η = 0 ↔ etaTilde η Δi = (1 / 2 : ℝ)) ∧
      (etaTilde η Δi = (1 / 2 : ℝ) ↔
        EtaCurvature.curvIndex η Δi = 0) := by
  have h1 : (η = 0 ↔ etaTilde η Δi = (1 / 2 : ℝ)) := (etaTilde_half_iff hΔi).symm
  have h2 : etaTilde η Δi = (1 / 2 : ℝ) ↔ EtaCurvature.curvIndex η Δi = 0 := by
    rw [curvIndex_eq_of_etaTilde]
    constructor
    · intro ht
      rw [ht]
      norm_num [Real.one_rpow]
    · intro hc
      -- From hc: ((1 - etaTilde η Δi) / etaTilde η Δi) ^ Δi = 1
      have h_exp_eq_one : ((1 - etaTilde η Δi) / etaTilde η Δi) ^ Δi = 1 := by linarith
      -- For x ^ Δi = 1 with Δi > 0 and x ≥ 0, we must have x = 1
      have h_base_eq_one : (1 - etaTilde η Δi) / etaTilde η Δi = 1 := by
        have h_eta_pos : etaTilde η Δi > 0 := etaTilde_mem_Ioo η Δi |>.1
        have h_eta_lt_one : etaTilde η Δi < 1 := etaTilde_mem_Ioo η Δi |>.2
        have h_base_pos : (1 - etaTilde η Δi) / etaTilde η Δi ≥ 0 := div_nonneg (by linarith) (le_of_lt h_eta_pos)
        have h_base_ne_zero : (1 - etaTilde η Δi) / etaTilde η Δi ≠ 0 := by
          apply div_ne_zero
          · linarith
          · linarith
        have h_base_pos' : (1 - etaTilde η Δi) / etaTilde η Δi > 0 := lt_of_le_of_ne h_base_pos (Ne.symm h_base_ne_zero)
        by_contra h_ne
        by_cases h_gt : (1 - etaTilde η Δi) / etaTilde η Δi > 1
        · have := Real.one_lt_rpow h_gt hΔi
          linarith
        · push_neg at h_gt
          have h_lt : (1 - etaTilde η Δi) / etaTilde η Δi < 1 := lt_of_le_of_ne h_gt h_ne
          have := Real.rpow_lt_one h_base_pos'.le h_lt hΔi
          linarith
      -- From base = 1: (1 - etaTilde) / etaTilde = 1, so 1 - etaTilde = etaTilde, etaTilde = 1/2
      have h_eta_ne_zero : etaTilde η Δi ≠ 0 := ne_of_gt (etaTilde_mem_Ioo η Δi |>.1)
      rw [div_eq_one_iff_eq h_eta_ne_zero] at h_base_eq_one
      linarith
  exact ⟨h1, h2⟩

/-- **E1.** The landed optimum always induces a genuine factor share.  Thus the
factor-share identification is reachable through `etaTilde` even though
`EtaCurvature.etaStar` itself can be arbitrarily large: a Cobb–Douglas share
must lie in `(0,1)`, while the exponent need not.  The second conjunct records
that this induced share recovers the existing `EtaCurvature.curvIndex`. -/
theorem etaStar_tilde_mem_Ioo (premInv fee Δi : ℝ) :
    etaTilde (EtaCurvature.etaStar premInv fee Δi) Δi ∈ Ioo (0 : ℝ) 1 ∧
      curvOfTilde (etaTilde (EtaCurvature.etaStar premInv fee Δi) Δi) Δi =
        EtaCurvature.curvIndex (EtaCurvature.etaStar premInv fee Δi) Δi := by
  exact ⟨etaTilde_mem_Ioo _ _, curvOfTilde_etaTilde _ _⟩

/-- **E2.** The landed curvature is expressed through its induced share.
The hypotheses `0 ≤ fee`, `fee < premInv`, and `0 < Δi` are necessary because
they are precisely the admissibility assumptions of the landed theorem
`EtaCurvature.curvIndex_etaStar`. -/
theorem curvIndex_etaStar_via_tilde {premInv fee Δi : ℝ}
    (hfee : 0 ≤ fee) (hpi : fee < premInv) (hΔi : 0 < Δi) :
    curvOfTilde (etaTilde (EtaCurvature.etaStar premInv fee Δi) Δi) Δi =
      EtaCurvature.kphiStar premInv fee := by
  rw [curvOfTilde_etaTilde]
  exact EtaCurvature.curvIndex_etaStar hfee hpi hΔi

end EtaTilde
