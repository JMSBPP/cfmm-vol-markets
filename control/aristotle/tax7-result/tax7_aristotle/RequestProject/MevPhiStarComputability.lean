import Mathlib
import RequestProject.MevTransactionalOptimum

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M43 — computability of `φ*` (Theorem 55)

`MevTaxTransactional.Theorem50_*` puts `φ*` at an interior root of the reduced
first-order condition `Φ = focTail` (under (A-tail), (A-route)); the top-up law
`MevTaxTransactional.Theorem50c_top_up_law` consumes it.  An EVM hook cannot
take an `argmax`: it can run a closed form, or an iteration with a proved error
bound.  This module carries **M43 / Theorem 55**:

* **(a)** the FOC is `e^{-αφ}·(quadratic in φ) = const`.  In the degenerate
  linear case `c = 0` this **is** a Lambert-`W` equation and the reduction is
  proved exactly (`Theorem55a_lambert_reduction_at_c_zero`).  For the model's
  own `c = √(2/Δt) > 0` the polynomial factor is genuinely quadratic and no
  elementary or Lambert-`W` form is exhibited; the *impossibility* is stated
  **OPEN** (see the note before `Theorem55a_foc_is_exponential_times_quadratic`)
  rather than asserted — a Liouville/differential-Galois argument is not
  available here.
* **(b)** — the deliverable — the explicit damped-Newton (gradient) map
  `T x = x + Φ(x)/M`, with invariance, a unique root, and a **geometric** error
  bound `|T^[n] x₀ - φ*| ≤ (1 - m/M)^n·(b-a)` on the region cut out by
  `MevTaxTransactional.Theorem52`'s guard `q > 0`
  (`Theorem55b_geometric_convergence`, `Theorem55b_focTail_iteration`,
  `Theorem55b_explicit_ratio`).
* **(c)** the iteration and its limit are **monotone in `σ`**
  (`Theorem55c_iterate_mono_in_sigma`, `Theorem55c_root_mono_in_sigma`,
  `Theorem55c_focTail_mono_sigma`), consistently with `Theorem50d`'s
  pro-cyclicality: warm-starting from the previous block moves the right way.
* **(d)** computable corner predicates deciding `Theorem50(e)`'s taxonomy before
  iterating (`Theorem55d_shutdown_predicate`, `Theorem55d_corner_at_zero_predicate`,
  `Theorem55d_interior_predicate`).

No numeral of any implementation enters a statement (ban 7); `α_transactional`
and `δ_transactional` are free typed parameters throughout ((A-input)).
-/

namespace MevTaxCompute

open MevTaxTransactional

/-! ## Theorem 55(a) — closed form? -/

/-- **Theorem 55(a) [M43] — the shape of the FOC.**  Under (A-tail)/(A-route)
the stationarity condition is an exponential against a **quadratic**:

`Φ(φ) = 0  ⟺  e^{-αφ}·(αcφ² + ασφ - σ) = Lvr·σ/K`.

`OPEN.`  For `c = √(2/Δt) > 0` the left factor is a genuine quadratic, so the
equation is not of the Lambert form `p₁(x)e^{x} = const`; no closed form in
elementary functions or `W` is exhibited.  We do **not** claim impossibility:
a proof would need a Liouville/differential-Galois argument for the class
`{elementary} ∪ {W}`, machinery that is not available in this development.  The
deliverable is therefore (b). -/
theorem Theorem55a_foc_is_exponential_times_quadratic (K al phi sig c Lvr : ℝ)
    (hK : K ≠ 0) :
    focTail K al phi sig c Lvr = 0
      ↔ hazTail al phi * (al * c * phi ^ 2 + al * sig * phi - sig) = Lvr * sig / K := by
  rw [focTail_eq]
  rw [eq_div_iff hK]
  constructor
  · intro h; nlinarith [h]
  · intro h; nlinarith [h]

/-- **Theorem 55(a) [M43] — the Lambert-`W` reduction in the degenerate linear
case.**  When the price-impact rate vanishes (`c = 0`, the `Δt → ∞` boundary of
`cRate`), the quadratic degenerates to a linear factor and the FOC **is** a
Lambert equation: with `v = 1 - αφ`,

`Φ(φ) = 0  ⟺  v·e^{v} = -e·Lvr/K`,   i.e.  `φ* = (1 - W(-e·Lvr/K))/α`.

So the obstruction to a closed form is exactly the quadratic term `αcφ²`, i.e.
the price-impact channel — nothing else. -/
theorem Theorem55a_lambert_reduction_at_c_zero (K al phi sig Lvr : ℝ)
    (hK : K ≠ 0) (hsig : sig ≠ 0) :
    focTail K al phi sig 0 Lvr = 0
      ↔ (1 - al * phi) * Real.exp (1 - al * phi) = -(Real.exp 1 * Lvr / K) := by
  have he : Real.exp 1 ≠ 0 := Real.exp_ne_zero 1
  have hexp : Real.exp (1 - al * phi) = Real.exp 1 * Real.exp (-(al * phi)) := by
    rw [← Real.exp_add]; ring_nf
  have hC : ((1 - al * phi) * Real.exp (1 - al * phi) = -(Real.exp 1 * Lvr / K))
      ↔ ((1 - al * phi) * Real.exp (-(al * phi)) = -(Lvr / K)) := by
    rw [hexp]
    have e1 : (1 - al * phi) * (Real.exp 1 * Real.exp (-(al * phi)))
        = Real.exp 1 * ((1 - al * phi) * Real.exp (-(al * phi))) := by ring
    have e2 : -(Real.exp 1 * Lvr / K) = Real.exp 1 * (-(Lvr / K)) := by ring
    rw [e1, e2, mul_right_inj' he]
  rw [hC, focTail_eq, hazTail]
  constructor
  · intro h
    have hfac : sig * (K * Real.exp (-(al * phi)) * (1 - al * phi) + Lvr) = 0 := by
      linear_combination h
    have h1 : K * Real.exp (-(al * phi)) * (1 - al * phi) + Lvr = 0 := by
      rcases mul_eq_zero.mp hfac with h2 | h2
      · exact absurd h2 hsig
      · exact h2
    field_simp
    linear_combination h1
  · intro h
    have h1 : K * Real.exp (-(al * phi)) * (1 - al * phi) + Lvr = 0 := by
      field_simp at h
      linear_combination h
    linear_combination sig * h1

/-! ## Theorem 55(b) — the iteration.  THE ARTIFACT THE HOOK RUNS.

The map is the damped Newton / gradient step on the FOC,

`T(x) = x + Φ(x)/M`,

with `M` any upper bound for `-Φ'` on the bracket `[a,b]`.  It needs one
evaluation of `Φ` per step and no division by a state-dependent quantity — the
`M` is fixed by the parameters, so a fixed-point implementation can precompute
`1/M`. -/

/-- The iteration map `T(x) = x + Φ(x)/M`. -/
noncomputable def iterMap (Phi : ℝ → ℝ) (M : ℝ) : ℝ → ℝ := fun x => x + Phi x / M

lemma hasDerivAt_iterMap (Phi : ℝ → ℝ) (dPhix M x : ℝ) (hd : HasDerivAt Phi dPhix x) :
    HasDerivAt (iterMap Phi M) (1 + dPhix / M) x := by
  have h := (hasDerivAt_id x).add (hd.div_const M)
  simpa [iterMap] using h

variable (Phi dPhi : ℝ → ℝ)

/-- `T` is nondecreasing on the bracket: this is what makes the iteration safe
to warm-start and gives the invariance of `[a,b]`. -/
lemma iterMap_monotoneOn (a b M : ℝ) (hM : 0 < M)
    (hderiv : ∀ x, HasDerivAt Phi (dPhi x) x)
    (hhi : ∀ x ∈ Set.Icc a b, -M ≤ dPhi x) :
    MonotoneOn (iterMap Phi M) (Set.Icc a b) := by
  refine monotoneOn_of_deriv_nonneg (convex_Icc a b) (fun x _ =>
      ((hasDerivAt_iterMap Phi (dPhi x) M x (hderiv x)).continuousAt).continuousWithinAt)
    (fun x _ => ((hasDerivAt_iterMap Phi (dPhi x) M x
      (hderiv x)).differentiableAt).differentiableWithinAt) ?_
  intro x hx
  rw [interior_Icc] at hx
  rw [(hasDerivAt_iterMap Phi (dPhi x) M x (hderiv x)).deriv]
  have h := hhi x ⟨le_of_lt hx.1, le_of_lt hx.2⟩
  have heq : 1 + dPhi x / M = (M + dPhi x) / M := by field_simp
  rw [heq]
  exact div_nonneg (by linarith) hM.le

/-- The contraction estimate: for `x ≤ y` in the bracket,
`T(y) - T(x) ≤ (1 - m/M)(y - x)`. -/
lemma iterMap_contraction (a b m M : ℝ) (hM : 0 < M)
    (hderiv : ∀ x, HasDerivAt Phi (dPhi x) x)
    (hlo : ∀ x ∈ Set.Icc a b, dPhi x ≤ -m) :
    ∀ x ∈ Set.Icc a b, ∀ y ∈ Set.Icc a b, x ≤ y →
      iterMap Phi M y - iterMap Phi M x ≤ (1 - m / M) * (y - x) := by
  have hmono : MonotoneOn (fun x => (1 - m / M) * x - iterMap Phi M x) (Set.Icc a b) := by
    refine monotoneOn_of_deriv_nonneg (convex_Icc a b) ?_ ?_ ?_
    · intro x _
      exact (((continuous_const.mul continuous_id).continuousAt).sub
        ((hasDerivAt_iterMap Phi (dPhi x) M x (hderiv x)).continuousAt)).continuousWithinAt
    · intro x _
      exact ((((hasDerivAt_id x).const_mul (1 - m / M)).sub
        (hasDerivAt_iterMap Phi (dPhi x) M x (hderiv x))).differentiableAt).differentiableWithinAt
    · intro x hx
      rw [interior_Icc] at hx
      have hd : HasDerivAt (fun x => (1 - m / M) * x - iterMap Phi M x)
          ((1 - m / M) * 1 - (1 + dPhi x / M)) x :=
        ((hasDerivAt_id x).const_mul (1 - m / M)).sub
          (hasDerivAt_iterMap Phi (dPhi x) M x (hderiv x))
      rw [hd.deriv]
      have h := hlo x ⟨le_of_lt hx.1, le_of_lt hx.2⟩
      have heq : (1 - m / M) * 1 - (1 + dPhi x / M) = (-(m + dPhi x)) / M := by
        field_simp; ring
      rw [heq]
      exact div_nonneg (by linarith) hM.le
  intro x hx y hy hxy
  have := hmono hx hy hxy
  simp only at this
  linarith

/-- Invariance of the bracket: `T` maps `[a,b]` into `[a,b]` when `Φ(a) ≥ 0` and
`Φ(b) ≤ 0` — the same two sign tests that bracket the root. -/
lemma iterMap_mapsTo (a b M : ℝ) (hab : a ≤ b) (hM : 0 < M)
    (hderiv : ∀ x, HasDerivAt Phi (dPhi x) x)
    (hhi : ∀ x ∈ Set.Icc a b, -M ≤ dPhi x)
    (ha : 0 ≤ Phi a) (hb : Phi b ≤ 0) :
    ∀ x ∈ Set.Icc a b, iterMap Phi M x ∈ Set.Icc a b := by
  have hmono := iterMap_monotoneOn Phi dPhi a b M hM hderiv hhi
  intro x hx
  have hTa : a ≤ iterMap Phi M a := by
    have : 0 ≤ Phi a / M := div_nonneg ha hM.le
    simp only [iterMap]; linarith
  have hTb : iterMap Phi M b ≤ b := by
    have : Phi b / M ≤ 0 := div_nonpos_of_nonpos_of_nonneg hb hM.le
    simp only [iterMap]; linarith
  exact ⟨le_trans hTa (hmono ⟨le_refl a, hab⟩ hx hx.1),
    le_trans (hmono hx ⟨hab, le_refl b⟩ hx.2) hTb⟩

/-- Existence and uniqueness of the root on the bracket. -/
lemma root_exists_unique (a b m : ℝ) (hab : a ≤ b) (hm : 0 < m)
    (hderiv : ∀ x, HasDerivAt Phi (dPhi x) x)
    (hlo : ∀ x ∈ Set.Icc a b, dPhi x ≤ -m)
    (ha : 0 ≤ Phi a) (hb : Phi b ≤ 0) :
    ∃! p : ℝ, p ∈ Set.Icc a b ∧ Phi p = 0 := by
  have hcont : ContinuousOn Phi (Set.Icc a b) :=
    fun x _ => ((hderiv x).continuousAt).continuousWithinAt
  have hmem : (0:ℝ) ∈ Set.Icc (Phi b) (Phi a) := ⟨hb, ha⟩
  obtain ⟨p, hp, hp0⟩ := intermediate_value_Icc' hab hcont hmem
  have hanti : StrictAntiOn Phi (Set.Icc a b) := by
    refine strictAntiOn_of_deriv_neg (convex_Icc a b) hcont ?_
    intro x hx
    rw [interior_Icc] at hx
    rw [(hderiv x).deriv]
    have := hlo x ⟨le_of_lt hx.1, le_of_lt hx.2⟩
    linarith
  refine ⟨p, ⟨hp, hp0⟩, ?_⟩
  rintro q ⟨hq, hq0⟩
  rcases lt_trichotomy q p with h | h | h
  · exact absurd (hanti hq hp h) (by rw [hp0, hq0]; exact lt_irrefl 0)
  · exact h
  · exact absurd (hanti hp hq h) (by rw [hp0, hq0]; exact lt_irrefl 0)

/-- **Theorem 55(b) [M43] — THE ITERATION, with a machine-checked geometric
error bound.**  Let `Φ` be differentiable with `-M ≤ Φ' ≤ -m < 0` on a bracket
`[a,b]` and `Φ(a) ≥ 0 ≥ Φ(b)` (the two sign tests of (d)).  Then:

1. `Φ` has a **unique** root `φ*` in `[a,b]`;
2. the map `T(x) = x + Φ(x)/M` keeps `[a,b]` invariant and fixes `φ*`;
3. after `n` steps from any `x₀ ∈ [a,b]`,

   `|T^[n](x₀) - φ*| ≤ (1 - m/M)^n·|x₀ - φ*| ≤ (1 - m/M)^n·(b - a)`,

   a **geometric** rate with the explicit ratio `k = 1 - m/M ∈ [0,1)`.

This is the artifact the hook runs: one evaluation of `Φ` per step, a
precomputable `1/M`, and a step count fixed in advance by the target accuracy
and the ratio. -/
theorem Theorem55b_geometric_convergence (a b m M : ℝ) (hab : a ≤ b)
    (hm : 0 < m) (hM : 0 < M)
    (hderiv : ∀ x, HasDerivAt Phi (dPhi x) x)
    (hlo : ∀ x ∈ Set.Icc a b, dPhi x ≤ -m)
    (hhi : ∀ x ∈ Set.Icc a b, -M ≤ dPhi x)
    (ha : 0 ≤ Phi a) (hb : Phi b ≤ 0) :
    (∃! p : ℝ, p ∈ Set.Icc a b ∧ Phi p = 0)
      ∧ m ≤ M
      ∧ (0 ≤ 1 - m / M ∧ 1 - m / M < 1)
      ∧ ∀ p ∈ Set.Icc a b, Phi p = 0 → iterMap Phi M p = p ∧
          ∀ x0 ∈ Set.Icc a b, ∀ n : ℕ,
            (iterMap Phi M)^[n] x0 ∈ Set.Icc a b ∧
            |(iterMap Phi M)^[n] x0 - p| ≤ (1 - m / M) ^ n * |x0 - p| ∧
            |(iterMap Phi M)^[n] x0 - p| ≤ (1 - m / M) ^ n * (b - a) := by
  have hmM : m ≤ M := by
    have h1 := hlo b ⟨hab, le_refl b⟩
    have h2 := hhi b ⟨hab, le_refl b⟩
    linarith
  have hk0 : 0 ≤ 1 - m / M := by
    have : m / M ≤ 1 := (div_le_one hM).mpr hmM
    linarith
  have hk1 : 1 - m / M < 1 := by
    have : 0 < m / M := div_pos hm hM
    linarith
  have hmono := iterMap_monotoneOn Phi dPhi a b M hM hderiv hhi
  have hmaps := iterMap_mapsTo Phi dPhi a b M hab hM hderiv hhi ha hb
  have hcontr := iterMap_contraction Phi dPhi a b m M hM hderiv hlo
  refine ⟨root_exists_unique Phi dPhi a b m hab hm hderiv hlo ha hb, hmM, ⟨hk0, hk1⟩, ?_⟩
  intro p hp hp0
  have hfix : iterMap Phi M p = p := by simp [iterMap, hp0]
  refine ⟨hfix, ?_⟩
  intro x0 hx0 n
  induction n with
  | zero =>
    refine ⟨by simpa using hx0, by simp, ?_⟩
    simp only [Function.iterate_zero_apply, pow_zero, one_mul]
    rcases abs_cases (x0 - p) with ⟨h1, -⟩ | ⟨h1, -⟩ <;> rw [h1] <;>
      linarith [hp.1, hp.2, hx0.1, hx0.2]
  | succ n ih =>
    obtain ⟨hmem, hbound, -⟩ := ih
    have hstep : (iterMap Phi M)^[n + 1] x0 = iterMap Phi M ((iterMap Phi M)^[n] x0) := by
      rw [Function.iterate_succ_apply']
    have hmem' : (iterMap Phi M)^[n + 1] x0 ∈ Set.Icc a b := by
      rw [hstep]; exact hmaps _ hmem
    have hcontr' : |iterMap Phi M ((iterMap Phi M)^[n] x0) - p|
        ≤ (1 - m / M) * |(iterMap Phi M)^[n] x0 - p| := by
      set x := (iterMap Phi M)^[n] x0 with hx
      rcases le_total x p with hxp | hxp
      · have h1 : iterMap Phi M p - iterMap Phi M x ≤ (1 - m / M) * (p - x) :=
          hcontr x hmem p hp hxp
        have h2 : iterMap Phi M x ≤ iterMap Phi M p := hmono hmem hp hxp
        rw [hfix] at h1 h2
        rw [abs_of_nonpos (by linarith), abs_of_nonpos (by linarith)]
        linarith
      · have h1 : iterMap Phi M x - iterMap Phi M p ≤ (1 - m / M) * (x - p) :=
          hcontr p hp x hmem hxp
        have h2 : iterMap Phi M p ≤ iterMap Phi M x := hmono hp hmem hxp
        rw [hfix] at h1 h2
        rw [abs_of_nonneg (by linarith), abs_of_nonneg (by linarith)]
        linarith
    have hb1 : |(iterMap Phi M)^[n + 1] x0 - p| ≤ (1 - m / M) ^ (n + 1) * |x0 - p| := by
      rw [hstep]
      calc |iterMap Phi M ((iterMap Phi M)^[n] x0) - p|
          ≤ (1 - m / M) * |(iterMap Phi M)^[n] x0 - p| := hcontr'
        _ ≤ (1 - m / M) * ((1 - m / M) ^ n * |x0 - p|) := by
            exact mul_le_mul_of_nonneg_left hbound hk0
        _ = (1 - m / M) ^ (n + 1) * |x0 - p| := by ring
    refine ⟨hmem', hb1, ?_⟩
    have hx0p : |x0 - p| ≤ b - a := by
      rcases abs_cases (x0 - p) with ⟨h1, h2⟩ | ⟨h1, h2⟩ <;> rw [h1] <;>
        linarith [hp.1, hp.2, hx0.1, hx0.2]
    calc |(iterMap Phi M)^[n + 1] x0 - p| ≤ (1 - m / M) ^ (n + 1) * |x0 - p| := hb1
      _ ≤ (1 - m / M) ^ (n + 1) * (b - a) := by
          exact mul_le_mul_of_nonneg_left hx0p (by positivity)

/-! ### The instantiation at the model's own FOC -/

/-- On `[a,b]` the second-order quadratic of `Theorem52` is bounded below by its
endpoint values (it is concave for `α, c > 0`). -/
lemma qPoly_ge_min_endpoints (al sig c a b x : ℝ) (hal : 0 ≤ al) (hc : 0 ≤ c)
    (hx : x ∈ Set.Icc a b) (qlo : ℝ) (hqa : qlo ≤ qPoly al sig c a)
    (hqb : qlo ≤ qPoly al sig c b) : qlo ≤ qPoly al sig c x := by
  obtain ⟨hxa, hxb⟩ := hx
  rcases lt_trichotomy a b with hab | heq | hba
  · have hkey : (b - a) * (qPoly al sig c x - qlo)
        ≥ (b - x) * (qPoly al sig c a - qlo) + (x - a) * (qPoly al sig c b - qlo) := by
      rw [qPoly, qPoly, qPoly]
      nlinarith [mul_nonneg (mul_nonneg hal hc) (mul_nonneg (sub_nonneg.mpr hxa)
        (sub_nonneg.mpr hxb)), sq_nonneg (x - a), sq_nonneg (b - x)]
    have h1 : 0 ≤ (b - x) * (qPoly al sig c a - qlo) :=
      mul_nonneg (by linarith) (by linarith)
    have h2 : 0 ≤ (x - a) * (qPoly al sig c b - qlo) :=
      mul_nonneg (by linarith) (by linarith)
    nlinarith
  · have hxa' : x = a := le_antisymm (by rw [heq]; exact hxb) hxa
    rw [hxa']; exact hqa
  · exact absurd hba (not_lt.mpr (le_trans hxa hxb))

/-- On `[a,b] ⊆ [0,∞)` the same quadratic is bounded above by `2σ + 2cb`. -/
lemma qPoly_le (al sig c b x : ℝ) (hal : 0 ≤ al) (hsig : 0 ≤ sig) (hc : 0 ≤ c)
    (hx0 : 0 ≤ x) (hxb : x ≤ b) : qPoly al sig c x ≤ 2 * sig + 2 * c * b := by
  rw [qPoly]
  nlinarith [mul_nonneg (mul_nonneg hal hsig) hx0, mul_nonneg (mul_nonneg hal hc) (sq_nonneg x),
    mul_nonneg hc (sub_nonneg.mpr hxb)]

/-- The explicit lower bound `m` for `-Φ'` on the bracket. -/
noncomputable def mLo (K al b qlo : ℝ) : ℝ := K * al * Real.exp (-(al * b)) * qlo

/-- The explicit upper bound `M` for `-Φ'` on the bracket. -/
noncomputable def mHi (K al a sig c b : ℝ) : ℝ :=
  K * al * Real.exp (-(al * a)) * (2 * sig + 2 * c * b)

/-- **Theorem 55(b) [M43] — the iteration at the model's own FOC.**  On a
bracket `[a,b] ⊆ [0,1)` contained in `Theorem52`'s guard region (`q ≥ qlo > 0`
at the endpoints, hence throughout by concavity) and bracketing the root
(`Φ(a) ≥ 0 ≥ Φ(b)`), the hypotheses of `Theorem55b_geometric_convergence` hold
with the **explicit** constants

`m = K α e^{-αb} q_lo`,  `M = K α e^{-αa}(2σ + 2cb)`,

`K = f_LP·δ_transactional`, `α = α_transactional` — both exogenous on-chain
inputs ((A-input)).  Hence a unique `φ*` in the bracket and the geometric bound
with ratio `1 - m/M`. -/
theorem Theorem55b_focTail_iteration (K al a b sig c Lvr qlo : ℝ)
    (hab : a ≤ b) (ha0 : 0 ≤ a) (hK : 0 < K) (hal : 0 < al) (hsig : 0 < sig) (hc : 0 < c)
    (hqlo : 0 < qlo) (hqa : qlo ≤ qPoly al sig c a) (hqb : qlo ≤ qPoly al sig c b)
    (hPa : 0 ≤ focTail K al a sig c Lvr) (hPb : focTail K al b sig c Lvr ≤ 0) :
    (∃! p : ℝ, p ∈ Set.Icc a b ∧ focTail K al p sig c Lvr = 0)
      ∧ ∀ p ∈ Set.Icc a b, focTail K al p sig c Lvr = 0 →
          ∀ x0 ∈ Set.Icc a b, ∀ n : ℕ,
            |(iterMap (fun f => focTail K al f sig c Lvr) (mHi K al a sig c b))^[n] x0 - p|
              ≤ (1 - mLo K al b qlo / mHi K al a sig c b) ^ n * (b - a) := by
  set Phi : ℝ → ℝ := fun f => focTail K al f sig c Lvr with hPhi
  set dPhi : ℝ → ℝ := fun f => -(K * al * hazTail al f * qPoly al sig c f) with hdPhi
  have hderiv : ∀ x, HasDerivAt Phi (dPhi x) x := fun x => hasDerivAt_focTail K al x sig c Lvr
  have hmpos : 0 < mLo K al b qlo := by
    rw [mLo]; positivity
  have hMpos : 0 < mHi K al a sig c b := by
    rw [mHi]
    have h1 : 0 < 2 * sig + 2 * c * b := by nlinarith [ha0, hab]
    positivity
  have hlo : ∀ x ∈ Set.Icc a b, dPhi x ≤ -mLo K al b qlo := by
    intro x hx
    have hq : qlo ≤ qPoly al sig c x :=
      qPoly_ge_min_endpoints al sig c a b x hal.le hc.le hx qlo hqa hqb
    have hh : Real.exp (-(al * b)) ≤ hazTail al x := by
      rw [hazTail]
      exact Real.exp_le_exp.mpr (by nlinarith [hx.2])
    have hpos : 0 < K * al := by positivity
    rw [hdPhi, mLo]
    simp only
    have : K * al * Real.exp (-(al * b)) * qlo ≤ K * al * hazTail al x * qPoly al sig c x := by
      have h1 : K * al * Real.exp (-(al * b)) * qlo ≤ K * al * hazTail al x * qlo := by
        have := mul_le_mul_of_nonneg_left hh hpos.le
        nlinarith [hqlo]
      have h2 : K * al * hazTail al x * qlo ≤ K * al * hazTail al x * qPoly al sig c x := by
        have hnn : 0 ≤ K * al * hazTail al x := by
          have := hazTail_pos al x; positivity
        exact mul_le_mul_of_nonneg_left hq hnn
      linarith
    linarith
  have hhi : ∀ x ∈ Set.Icc a b, -mHi K al a sig c b ≤ dPhi x := by
    intro x hx
    have hx0 : 0 ≤ x := le_trans ha0 hx.1
    have hq : qPoly al sig c x ≤ 2 * sig + 2 * c * b :=
      qPoly_le al sig c b x hal.le hsig.le hc.le hx0 hx.2
    have hh : hazTail al x ≤ Real.exp (-(al * a)) := by
      rw [hazTail]
      exact Real.exp_le_exp.mpr (by nlinarith [hx.1])
    have hpos : 0 < K * al := by positivity
    rw [hdPhi, mHi]
    simp only
    have hqlow : qlo ≤ qPoly al sig c x :=
      qPoly_ge_min_endpoints al sig c a b x hal.le hc.le hx qlo hqa hqb
    have hqnn : 0 ≤ qPoly al sig c x := le_trans hqlo.le hqlow
    have h1 : K * al * hazTail al x * qPoly al sig c x
        ≤ K * al * Real.exp (-(al * a)) * qPoly al sig c x := by
      have := mul_le_mul_of_nonneg_left hh hpos.le
      nlinarith
    have h2 : K * al * Real.exp (-(al * a)) * qPoly al sig c x
        ≤ K * al * Real.exp (-(al * a)) * (2 * sig + 2 * c * b) := by
      have hnn : 0 ≤ K * al * Real.exp (-(al * a)) := by positivity
      exact mul_le_mul_of_nonneg_left hq hnn
    linarith
  obtain ⟨huniq, -, -, hiter⟩ :=
    Theorem55b_geometric_convergence Phi dPhi a b (mLo K al b qlo) (mHi K al a sig c b)
      hab hmpos hMpos hderiv hlo hhi hPa hPb
  refine ⟨huniq, ?_⟩
  intro p hp hp0 x0 hx0 n
  exact ((hiter p hp hp0).2 x0 hx0 n).2.2

/-- **Theorem 55(b) [M43] — the contraction ratio in the problem's parameters.**
The ratio is

`k = 1 - m/M = 1 - e^{-α(b-a)}·q_lo/(2σ + 2cb)`,

decreasing in the bracket width and in the price-impact rate `c`, and
increasing in `α_transactional`: exactly the quantities the hook already
carries. -/
theorem Theorem55b_explicit_ratio (K al a b sig c qlo : ℝ)
    (hK : 0 < K) (hal : 0 < al) :
    1 - mLo K al b qlo / mHi K al a sig c b
      = 1 - Real.exp (-(al * (b - a))) * qlo / (2 * sig + 2 * c * b) := by
  rw [mLo, mHi]
  have hK' : K * al ≠ 0 := by positivity
  have he : Real.exp (-(al * a)) ≠ 0 := Real.exp_ne_zero _
  have hsplit : Real.exp (-(al * b)) = Real.exp (-(al * (b - a))) * Real.exp (-(al * a)) := by
    rw [← Real.exp_add]; ring_nf
  rw [hsplit]
  field_simp

/-- **Theorem 55(b) [M43] — the hypotheses are satisfiable: an explicit witness
bracket, with a numeric contraction ratio.**  At `Δt = 2` (`c = 1`), `σ = 1/3`
(`Lvr = 1/36`), `α_transactional = 1` and `f_LP·δ_transactional = e^{1/2}/9` —
the same witness whose interior optimum is
`MevTaxEquating.Theorem53b_witness_is_an_interior_optimum`, at `φ* = 1/2` — the
bracket `[1/4, 3/4]` satisfies every hypothesis of
`Theorem55b_focTail_iteration` with `q_lo = 1`, and the contraction ratio is at
most `10/13`.  So after `n` steps the error is at most `(10/13)^n·(1/2)`: the
statement is not vacuous, and the step count is a numeral the hook can fix in
advance. -/
theorem Theorem55b_iteration_witness :
    (0:ℝ) ≤ focTail (Real.exp (1/2) / 9) 1 (1/4) (1/3) 1 (1/36)
      ∧ focTail (Real.exp (1/2) / 9) 1 (3/4) (1/3) 1 (1/36) ≤ 0
      ∧ (1:ℝ) ≤ qPoly 1 (1/3) 1 (1/4) ∧ (1:ℝ) ≤ qPoly 1 (1/3) 1 (3/4)
      ∧ (∃! p : ℝ, p ∈ Set.Icc (1/4:ℝ) (3/4)
          ∧ focTail (Real.exp (1/2) / 9) 1 p (1/3) 1 (1/36) = 0)
      ∧ ∀ p ∈ Set.Icc (1/4:ℝ) (3/4), focTail (Real.exp (1/2) / 9) 1 p (1/3) 1 (1/36) = 0 →
          ∀ x0 ∈ Set.Icc (1/4:ℝ) (3/4), ∀ n : ℕ,
            |(iterMap (fun f => focTail (Real.exp (1/2) / 9) 1 f (1/3) 1 (1/36))
                (mHi (Real.exp (1/2) / 9) 1 (1/4) (1/3) 1 (3/4)))^[n] x0 - p|
              ≤ (10/13:ℝ) ^ n * (1/2) := by
  have hK : (0:ℝ) < Real.exp (1/2) / 9 := by positivity
  have hh1 : 0 < hazTail 1 (1/4 : ℝ) := hazTail_pos _ _
  have hPa : (0:ℝ) ≤ focTail (Real.exp (1/2) / 9) 1 (1/4) (1/3) 1 (1/36) := by
    rw [focTail_eq]
    nlinarith [mul_pos hK hh1]
  have hprod : Real.exp (1/2) * hazTail 1 (3/4 : ℝ) = Real.exp (-(1/4 : ℝ)) := by
    rw [hazTail, ← Real.exp_add]; norm_num
  have hlow : (3/4 : ℝ) ≤ Real.exp (-(1/4 : ℝ)) := by
    have h := Real.add_one_le_exp (-(1/4 : ℝ)); linarith
  have hPb : focTail (Real.exp (1/2) / 9) 1 (3/4) (1/3) 1 (1/36) ≤ 0 := by
    rw [focTail_eq]
    nlinarith [hprod, hlow]
  have hqa : (1:ℝ) ≤ qPoly 1 (1/3) 1 (1/4) := by rw [qPoly]; norm_num
  have hqb : (1:ℝ) ≤ qPoly 1 (1/3) 1 (3/4) := by rw [qPoly]; norm_num
  obtain ⟨huniq, hiter⟩ :=
    Theorem55b_focTail_iteration (Real.exp (1/2) / 9) 1 (1/4) (3/4) (1/3) 1 (1/36) 1
      (by norm_num) (by norm_num) hK (by norm_num) (by norm_num) (by norm_num)
      (by norm_num) hqa hqb hPa hPb
  refine ⟨hPa, hPb, hqa, hqb, huniq, ?_⟩
  intro p hp hp0 x0 hx0 n
  have hratio := Theorem55b_explicit_ratio (Real.exp (1/2) / 9) 1 (1/4) (3/4) (1/3) 1 1
    hK (by norm_num)
  have harg : (-(1 * ((3:ℝ)/4 - 1/4))) = -(1/2 : ℝ) := by norm_num
  have hehalf : (1/2 : ℝ) ≤ Real.exp (-(1/2 : ℝ)) := by
    have h := Real.add_one_le_exp (-(1/2 : ℝ)); linarith
  have hele : Real.exp (-(1/2 : ℝ)) ≤ 1 := Real.exp_le_one_iff.mpr (by norm_num)
  have hsimp : Real.exp (-(1/2 : ℝ)) * 1 / (2 * (1/3 : ℝ) + 2 * 1 * (3/4))
      = 6/13 * Real.exp (-(1/2 : ℝ)) := by
    rw [show (2 * (1/3 : ℝ) + 2 * 1 * (3/4)) = 13/6 by norm_num]; ring
  have hk0 : 0 ≤ 1 - mLo (Real.exp (1/2) / 9) 1 (3/4) 1 /
      mHi (Real.exp (1/2) / 9) 1 (1/4) (1/3) 1 (3/4) := by
    rw [hratio, harg, hsimp]; linarith [hele]
  have hkle : 1 - mLo (Real.exp (1/2) / 9) 1 (3/4) 1 /
      mHi (Real.exp (1/2) / 9) 1 (1/4) (1/3) 1 (3/4) ≤ 10/13 := by
    rw [hratio, harg, hsimp]; linarith [hehalf]
  calc |(iterMap (fun f => focTail (Real.exp (1/2) / 9) 1 f (1/3) 1 (1/36))
          (mHi (Real.exp (1/2) / 9) 1 (1/4) (1/3) 1 (3/4)))^[n] x0 - p|
      ≤ (1 - mLo (Real.exp (1/2) / 9) 1 (3/4) 1 /
          mHi (Real.exp (1/2) / 9) 1 (1/4) (1/3) 1 (3/4)) ^ n * (3/4 - 1/4) :=
        hiter p hp hp0 x0 hx0 n
    _ ≤ (10/13:ℝ) ^ n * (1/2) := by
        have hpow := pow_le_pow_left₀ hk0 hkle n
        nlinarith [hpow, pow_nonneg hk0 n]

/-! ## Theorem 55(c) — the iteration respects pro-cyclicality -/

/-- **Theorem 55(c) [M43], the pointwise input.**  With `Lvr = σ²Δt/8` carrying
its own `σ`-dependence, the reduced FOC is **nondecreasing in `σ`** at every fee
with `αφ ≤ 1`; this is the pointwise form of `Theorem50d_focRedDsig_pos`'s
`∂Φ/∂σ = Kh(1-αφ) + 3Lvr > 0` (which holds at stationary points for all `φ`). -/
theorem Theorem55c_focTail_mono_sigma (K al phi sig1 sig2 Δt c : ℝ)
    (hK : 0 ≤ K) (hΔt : 0 ≤ Δt) (hs12 : sig1 ≤ sig2) (hal : al * phi ≤ 1) :
    focTail K al phi sig1 c (lvrCoef sig1 Δt) ≤ focTail K al phi sig2 c (lvrCoef sig2 Δt) := by
  rw [focTail_eq, focTail_eq, lvrCoef, lvrCoef]
  have hh : 0 < hazTail al phi := hazTail_pos al phi
  have h1 : K * hazTail al phi * (sig1 - al * (phi * (sig1 + phi * c)))
      ≤ K * hazTail al phi * (sig2 - al * (phi * (sig2 + phi * c))) := by
    have hfac : sig1 - al * (phi * (sig1 + phi * c)) ≤ sig2 - al * (phi * (sig2 + phi * c)) := by
      nlinarith
    have : 0 ≤ K * hazTail al phi := by positivity
    exact mul_le_mul_of_nonneg_left hfac this
  have hcube : sig1 ^ 3 ≤ sig2 ^ 3 := by
    nlinarith [sq_nonneg sig1, sq_nonneg sig2, sq_nonneg (sig1 + sig2), sq_nonneg (sig2 - sig1)]
  have h2 : sig1 ^ 2 * Δt / 8 * sig1 ≤ sig2 ^ 2 * Δt / 8 * sig2 := by
    have hmul := mul_le_mul_of_nonneg_left hcube (by positivity : (0:ℝ) ≤ Δt / 8)
    nlinarith [hmul]
  linarith

/-- **Theorem 55(c) [M43] — the iterates are monotone in the objective.**  If
`Φ₁ ≤ Φ₂` pointwise on the bracket (the `σ`-comparison of
`Theorem55c_focTail_mono_sigma`), then from the same warm start the iterates of
the higher-`σ` map dominate at every step: a volatility rise moves the
controller's iterate in the direction of the new root, never against it. -/
theorem Theorem55c_iterate_mono_in_sigma (Phi1 Phi2 : ℝ → ℝ) (a b M : ℝ) (hM : 0 < M)
    (hmaps1 : ∀ x ∈ Set.Icc a b, iterMap Phi1 M x ∈ Set.Icc a b)
    (hmaps2 : ∀ x ∈ Set.Icc a b, iterMap Phi2 M x ∈ Set.Icc a b)
    (hmono2 : MonotoneOn (iterMap Phi2 M) (Set.Icc a b))
    (hle : ∀ x ∈ Set.Icc a b, Phi1 x ≤ Phi2 x) :
    ∀ x0 ∈ Set.Icc a b, ∀ n : ℕ,
      (iterMap Phi1 M)^[n] x0 ∈ Set.Icc a b ∧
      (iterMap Phi2 M)^[n] x0 ∈ Set.Icc a b ∧
      (iterMap Phi1 M)^[n] x0 ≤ (iterMap Phi2 M)^[n] x0 := by
  intro x0 hx0 n
  induction n with
  | zero => exact ⟨by simpa using hx0, by simpa using hx0, by simp⟩
  | succ n ih =>
    obtain ⟨hmem1, hmem2, hle_n⟩ := ih
    have hmem1' : (iterMap Phi1 M)^[n + 1] x0 ∈ Set.Icc a b := by
      rw [Function.iterate_succ_apply']; exact hmaps1 _ hmem1
    have hmem2' : (iterMap Phi2 M)^[n + 1] x0 ∈ Set.Icc a b := by
      rw [Function.iterate_succ_apply']; exact hmaps2 _ hmem2
    refine ⟨hmem1', hmem2', ?_⟩
    rw [Function.iterate_succ_apply', Function.iterate_succ_apply']
    have hdiv : Phi1 ((iterMap Phi1 M)^[n] x0) / M ≤ Phi2 ((iterMap Phi1 M)^[n] x0) / M := by
      rw [div_eq_mul_inv, div_eq_mul_inv]
      exact mul_le_mul_of_nonneg_right (hle _ hmem1) (by positivity)
    have hstep : iterMap Phi1 M ((iterMap Phi1 M)^[n] x0)
        ≤ iterMap Phi2 M ((iterMap Phi1 M)^[n] x0) := by
      simp only [iterMap]; linarith
    exact le_trans hstep (hmono2 hmem1 hmem2 hle_n)

/-- **Theorem 55(c) [M43] — the root itself is monotone.**  If `Φ₁ ≤ Φ₂` on the
bracket and `Φ₂` is strictly decreasing there, the roots are ordered
`φ*₁ ≤ φ*₂`: the computed optimum rises with volatility, consistently with
`MevTaxTransactional.Theorem50d_procyclicality`, and hence so does the top-up
tax `τ* = (φ*-φ_base)/(1-φ_base)`
(`MevTaxTransactional.Theorem50c_top_up_law`). -/
theorem Theorem55c_root_mono_in_sigma (Phi1 Phi2 : ℝ → ℝ) (a b p1 p2 : ℝ)
    (hanti2 : StrictAntiOn Phi2 (Set.Icc a b))
    (hle : ∀ x ∈ Set.Icc a b, Phi1 x ≤ Phi2 x)
    (hp1 : p1 ∈ Set.Icc a b) (hp2 : p2 ∈ Set.Icc a b)
    (h1 : Phi1 p1 = 0) (h2 : Phi2 p2 = 0) : p1 ≤ p2 := by
  by_contra hcon
  push_neg at hcon
  have hlt : Phi2 p1 < Phi2 p2 := hanti2 hp2 hp1 hcon
  have := hle p1 hp1
  rw [h1, h2] at *
  linarith

/-! ## Theorem 55(d) — computable corner predicates -/

/-- **Theorem 55(d) [M43] — the SHUTDOWN predicate.**  `K·c ≤ Lvr·σ` (with
`K = f_LP·δ_transactional`, `Lvr = σ²Δt/8`) is a computable sufficient condition
for the objective to be negative at **every** admissible fee: the regime is
`Theorem50e_shutdown_is_loss_minimization`'s loss minimization, and the hook
must not iterate. -/
theorem Theorem55d_shutdown_predicate (K al sig c Lvr : ℝ)
    (hK : 0 < K) (hc : 0 < c) (hsig : 0 < sig) (hal : 0 ≤ al)
    (hpred : K * c ≤ Lvr * sig) :
    ∀ phi ∈ Set.Ico (0:ℝ) 1, mObj (fun _ => K) (hazTail al) phi sig c Lvr < 0 := by
  intro phi hphi
  obtain ⟨h0, h1⟩ := hphi
  have hden : 0 < sig + phi * c := by nlinarith
  rw [mObj_eq _ _ phi sig c Lvr hden.ne', div_neg_iff]
  right
  refine ⟨?_, hden⟩
  have hh1 : hazTail al phi ≤ 1 := by
    rw [hazTail]
    exact Real.exp_le_one_iff.mpr (by nlinarith)
  have hh0 : 0 < hazTail al phi := hazTail_pos al phi
  have hstep1 : K * hazTail al phi * (phi * c) ≤ K * (phi * c) := by
    nlinarith [mul_nonneg (mul_nonneg hK.le h0) hc.le]
  have hstep2 : K * (phi * c) < K * c := by nlinarith [mul_pos hK hc]
  linarith

/-- **Theorem 55(d) [M43] — the `τ* = 0` corner predicate.**  If the marginal
value is nonpositive at the base fee and the second-order guard `q > 0` holds
above it (so `Φ` is strictly decreasing there), then `Φ ≤ 0` on the whole
admissible range above the base fee: the base fee already covers `φ*`, the
optimum is the corner `τ* = 0` (`Theorem50e_corner_at_zero`), and the hook
branches without iterating. -/
theorem Theorem55d_corner_at_zero_predicate (K al phibase sig c Lvr : ℝ)
    (hK : 0 < K) (hal : 0 < al) (hb1 : phibase < 1)
    (hq : ∀ x ∈ Set.Icc phibase 1, 0 < qPoly al sig c x)
    (hpred : focTail K al phibase sig c Lvr ≤ 0) :
    ∀ phi ∈ Set.Icc phibase 1, focTail K al phi sig c Lvr ≤ 0 := by
  have hderiv : ∀ x, HasDerivAt (fun f => focTail K al f sig c Lvr)
      (-(K * al * hazTail al x * qPoly al sig c x)) x :=
    fun x => hasDerivAt_focTail K al x sig c Lvr
  have hcont : ContinuousOn (fun f => focTail K al f sig c Lvr) (Set.Icc phibase 1) :=
    fun x _ => ((hderiv x).continuousAt).continuousWithinAt
  have hanti : StrictAntiOn (fun f => focTail K al f sig c Lvr) (Set.Icc phibase 1) := by
    refine strictAntiOn_of_deriv_neg (convex_Icc phibase 1) hcont ?_
    intro x hx
    rw [interior_Icc] at hx
    rw [(hderiv x).deriv]
    have hqx : 0 < qPoly al sig c x := hq x ⟨le_of_lt hx.1, le_of_lt hx.2⟩
    have hh : 0 < hazTail al x := hazTail_pos al x
    have : 0 < K * al * hazTail al x * qPoly al sig c x := by positivity
    linarith
  intro phi hphi
  rcases eq_or_lt_of_le hphi.1 with heq | hlt
  · rw [← heq]; exact hpred
  · have := hanti ⟨le_refl phibase, by linarith⟩ hphi hlt
    simp only at this
    linarith

/-- **Theorem 55(d) [M43] — the INTERIOR predicate.**  Two sign tests decide the
interior branch and *simultaneously* produce the bracket the iteration of (b)
runs on: if the marginal value is positive at the base fee and negative at some
admissible `b`, there is a root `φ*` strictly between them, the top-up tax is
interior (`Theorem50c_top_up_law`), and `[φ_base, b]` is the bracket. -/
theorem Theorem55d_interior_predicate (K al phibase b sig c Lvr : ℝ)
    (hlt : phibase < b) (hb1 : b < 1)
    (hpos : 0 < focTail K al phibase sig c Lvr)
    (hneg : focTail K al b sig c Lvr < 0) :
    ∃ phistar ∈ Set.Ioo phibase b, focTail K al phistar sig c Lvr = 0
      ∧ 0 < (phistar - phibase) / (1 - phibase)
      ∧ (phistar - phibase) / (1 - phibase) < 1
      ∧ phiOfTau phibase ((phistar - phibase) / (1 - phibase)) = phistar := by
  have hcont : ContinuousOn (fun f => focTail K al f sig c Lvr) (Set.Icc phibase b) :=
    fun x _ => (((hasDerivAt_focTail K al x sig c Lvr).continuousAt)).continuousWithinAt
  have hmem : (0:ℝ) ∈ Set.Icc (focTail K al b sig c Lvr) (focTail K al phibase sig c Lvr) :=
    ⟨hneg.le, hpos.le⟩
  obtain ⟨p, hp, hp0⟩ := intermediate_value_Icc' hlt.le hcont hmem
  have hpb : p ≠ phibase := by
    intro h; rw [h] at hp0; simp only at hp0; linarith
  have hpb2 : p ≠ b := by
    intro h; rw [h] at hp0; simp only at hp0; linarith
  have hpI : p ∈ Set.Ioo phibase b :=
    ⟨lt_of_le_of_ne hp.1 (Ne.symm hpb), lt_of_le_of_ne hp.2 hpb2⟩
  have hbase1 : phibase < 1 := lt_trans hlt hb1
  obtain ⟨hfix, hpos', hlt'⟩ := Theorem50c_top_up_law phibase p hbase1
  exact ⟨p, hpI, hp0, hpos'.mpr hpI.1, hlt'.mpr (lt_trans hpI.2 hb1), hfix⟩

end MevTaxCompute
