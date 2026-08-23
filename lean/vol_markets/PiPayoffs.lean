import Mathlib

/-!
# PiPayoffs — the adjusted π family: carriers, and CONSISTENCY with the current objects

## Intent

The governing document just minted (user TODO, 2026-08-11): the forward payoff `π^f`,
the log payoff `π^log`, the HODL drift (reserves FROZEN at inception), the rebalancing
drift `π^R` (current reserves), `π^IL ≡ π^HODL − π^φ`, and the boxed LVR law
`∂_t π^LVR = ∂_t π^R − ∂_t π^φ`. This bundle supplies their carriers AND checks the new
definitions for INCONSISTENCIES against the already-proved layer — the envelope
(`∂π^φ/∂P = Q_X^L`) and the gamma closed form. Every target is a CONSISTENCY statement:
if any is false as written, that IS the sought inconsistency — refute it as stated
(named `..._false` counterexample) and prove the corrected form under a NEW name,
documenting exactly what changed. A refutation is a successful outcome.

## Setup

The portfolio value along the price is abstracted as `V : ℝ → ℝ` with the PROVED
envelope supplied as a hypothesis: `V' = x` (the X-reserve as a function of price,
decreasing) and `x' = Γ` (the gamma). Price paths are `p : ℝ → ℝ` in time. `ps` is the
inception price `p⋆`. This keeps every statement a pure-calculus fact instantiable by
the in-tree `piVal`/`gamma_eq_ell` layer.

## Instructions

Prove the `sorry`'d statements. Priority **P1 > P2 > P5 > P6 > P3 > P4**.
Do not modify any definition (`piF`, `piLog`, `piHODL`).
-/

namespace PiPayoffs

open Real Set Asymptotics

/-- Document Definition 34: the forward payoff, unit notional struck at `ps`. -/
noncomputable def piF (ps P : ℝ) : ℝ := P - ps

/-- Document Definition 35: the log payoff struck at `ps`. -/
noncomputable def piLog (ps P : ℝ) : ℝ := Real.log (P / ps)

/-- Document Definition 30's HODL value: the tangent line at inception —
holdings `(x0, y0)` frozen, valued at the current price. -/
noncomputable def piHODL (x0 y0 P : ℝ) : ℝ := x0 * P + y0

/-- **P1 — the log payoff's gamma (closes the document's Proposition 6 premise).**
`∂²π^log/∂P² = -1/P²`, and consequently the intrinsic-liquidity form
`-2·P^{3/2}·(π^log)'' = 2·P^{-1/2}` — the `K^{-1/2}` law the replication premise needs.
Also `∂²π^f/∂P² = 0` (the forward has no gamma). -/
theorem piLog_gamma (ps P : ℝ) (hps : 0 < ps) (hP : 0 < P) :
    deriv (fun q => deriv (piLog ps) q) P = -(1 / P ^ 2) ∧
    -2 * P ^ ((3 : ℝ) / 2) * deriv (fun q => deriv (piLog ps) q) P
      = 2 * P ^ (-(1 : ℝ) / 2) ∧
    deriv (fun q => deriv (piF ps) q) P = 0 := by
  have hd : ∀ q : ℝ, 0 < q → HasDerivAt (piLog ps) (1 / q) q := by
    intro q hq
    have h1 : HasDerivAt (fun r : ℝ => r / ps) (1 / ps) q := by
      simpa using (hasDerivAt_id q).div_const ps
    have h2 := (Real.hasDerivAt_log (by positivity : q / ps ≠ 0)).comp q h1
    convert h2 using 1
    field_simp
  have hev : (fun q => deriv (piLog ps) q) =ᶠ[nhds P] (fun q : ℝ => 1 / q) := by
    filter_upwards [Ioi_mem_nhds hP] with q hq using (hd q hq).deriv
  have h2nd : deriv (fun q => deriv (piLog ps) q) P = -(1 / P ^ 2) := by
    rw [hev.deriv_eq]
    have hinv : HasDerivAt (fun q : ℝ => 1 / q) (-(1 / P ^ 2)) P := by
      simpa [one_div] using hasDerivAt_inv (ne_of_gt hP)
    exact hinv.deriv
  refine ⟨h2nd, ?_, ?_⟩
  · rw [h2nd, show (-(1 : ℝ) / 2) = 3 / 2 - 2 by ring, Real.rpow_sub hP,
      show (P : ℝ) ^ (2 : ℝ) = P ^ (2 : ℕ) by rw [← Real.rpow_natCast P 2]; norm_num]
    field_simp
  · have h : ∀ q : ℝ, deriv (piF ps) q = 1 := by
      intro q
      rw [show piF ps = fun r : ℝ => id r - ps from rfl]
      simp
    simp [h]

/-- **P2 — smooth-path LVR is ZERO (consistency of the boxed law with the envelope).**
With the envelope `V' = x` and a differentiable price path, the value's drift is exactly
the rebalancing drift: `d/dt V(p(t)) = x(p(t))·p'(t)`. Hence on `C¹` paths
`∂_t π^LVR = ∂_t π^R − ∂_t π^φ = 0` — LVR is generated ONLY by quadratic variation,
which is the document's Proposition 15 claim. -/
theorem smooth_path_lvr_zero (V x p : ℝ → ℝ) (t : ℝ)
    (hV : ∀ q, HasDerivAt V (x q) q) (hp : DifferentiableAt ℝ p t) :
    deriv (V ∘ p) t = x (p t) * deriv p t :=
  ((hV (p t)).comp t hp.hasDerivAt).deriv

/-- **P3 — the discrete second-order step (the lattice formulation of `d⟨P⟩`).**
With `V' = x` and `x' = Γ` at `P0`, the one-step expansion carries the gamma on the
SQUARED step: `V(P0+h) − V(P0) − x(P0)·h − ½·Γ(P0)·h² = o(h²)`. This grounds the
document's FLAG: on the lattice `d⟨P_φ⟩` is `(ΔP_φ)²` per step, entering through `½Γ`. -/
theorem discrete_second_order_step (V x Γ : ℝ → ℝ) (P0 : ℝ)
    (hV : ∀ q, HasDerivAt V (x q) q) (hx : HasDerivAt x (Γ P0) P0) :
    (fun h => V (P0 + h) - V P0 - x P0 * h - (1 / 2) * Γ P0 * h ^ 2)
      =o[nhds 0] (fun h => h ^ 2) := by
  set g : ℝ → ℝ := fun h => V (P0 + h) - V P0 - x P0 * h - (1 / 2) * Γ P0 * h ^ 2 with hg
  set g' : ℝ → ℝ := fun h => x (P0 + h) - x P0 - Γ P0 * h with hg'
  have hgd : ∀ h : ℝ, HasDerivAt g (g' h) h := by
    intro h
    have h1 : HasDerivAt (fun s : ℝ => V (P0 + s)) (x (P0 + h)) h := by
      simpa using (hV (P0 + h)).comp h ((hasDerivAt_id h).const_add P0)
    have h2 : HasDerivAt (fun s : ℝ => V (P0 + s) - V P0 - x P0 * s - (1 / 2) * Γ P0 * s ^ 2)
        (x (P0 + h) - x P0 - (1 / 2) * Γ P0 * (2 * h)) h := by
      have h3 := ((h1.sub_const (V P0)).sub ((hasDerivAt_id h).const_mul (x P0))).sub
        ((hasDerivAt_pow 2 h).const_mul ((1 : ℝ) / 2 * Γ P0))
      simpa using h3
    have h4 : x (P0 + h) - x P0 - (1 / 2) * Γ P0 * (2 * h) = g' h := by simp [hg']; ring
    rw [hg]
    exact h4 ▸ h2
  have hlo : g' =o[nhds (0 : ℝ)] (fun h : ℝ => (h - 0) ^ 1) := by
    have h2 : (fun h : ℝ => x (P0 + h) - x P0 - (P0 + h - P0) • Γ P0) =o[nhds (0 : ℝ)]
        (fun h : ℝ => P0 + h - P0) :=
      hx.isLittleO.comp_tendsto (by
        simpa using (Filter.tendsto_id.const_add P0 :
          Filter.Tendsto (fun h : ℝ => P0 + h) (nhds 0) (nhds (P0 + 0))))
    simpa [hg', smul_eq_mul, mul_comm] using h2
  have key := (convex_univ (𝕜 := ℝ) (E := ℝ)).isLittleO_pow_succ_real (x₀ := (0 : ℝ)) (n := 1)
    (f := g) (f' := g') (mem_univ 0) (fun y _ => (hgd y).hasDerivWithinAt)
    (by simpa [nhdsWithin_univ] using hlo)
  simp only [nhdsWithin_univ] at key
  have hg0 : g 0 = 0 := by simp [hg]
  simpa [hg0] using key

/-- **P4 — HODL-drift consistency.** Definition 30's tangent-line HODL and the new
Definition 42 drift form agree: `d/dt [x0·p(t) + y0] = x0·p'(t)` — the frozen reserve
times the price drift, which is Definition 42 at `x0 = Q_X^L(P(t_0))`. -/
theorem hodl_drift_consistent (x0 y0 : ℝ) (p : ℝ → ℝ) (t : ℝ)
    (hp : DifferentiableAt ℝ p t) :
    deriv (fun s => piHODL x0 y0 (p s)) t = x0 * deriv p t :=
  ((hp.hasDerivAt.const_mul x0).add_const y0).deriv

/-- **P5 — IL vanishes at inception.** If the HODL holdings are the on-curve holdings at
the inception price (`piHODL x0 y0 ps = V ps`), then `π^IL(t_0) = 0` — the two
portfolios coincide where the tangent touches. -/
theorem il_zero_at_inception (V : ℝ → ℝ) (x0 y0 ps : ℝ)
    (htangent : piHODL x0 y0 ps = V ps) :
    piHODL x0 y0 ps - V ps = 0 :=
  sub_eq_zero_of_eq htangent

/-- **P6 — IL is nonnegative (the tangent dominates a concave value).** With the
envelope `V' = x`, `x` antitone (the reserve DECREASES in price — the document's
Theorem 33 sign), and the HODL line tangent at `ps` (`x0 = x ps`,
`piHODL x0 y0 ps = V ps`), the HODL value dominates everywhere:
`V P ≤ piHODL x0 y0 P` for all `P > 0` — i.e. `π^IL ≥ 0`. If antitonicity of `x` on
`(0,∞)` is not enough as stated, refute and correct with the exact needed hypothesis.

CHECK OUTCOME: no correction needed. `AntitoneOn x (Ioi 0)` is exactly enough: the
mean value theorem on the interval between `ps` and `P` (both in `(0,∞)`, which is
convex, and `V` is differentiable hence continuous there) produces an intermediate
point `c` with `x c = (V P − V ps)/(P − ps)`, and antitonicity compares `x c` with
`x ps` with the sign of `P − ps`, in both directions. No concavity/`C¹` assumption on
`x` beyond antitonicity is used. -/
theorem il_nonneg (V x : ℝ → ℝ) (x0 y0 ps P : ℝ)
    (hV : ∀ q, 0 < q → HasDerivAt V (x q) q)
    (hanti : AntitoneOn x (Ioi (0 : ℝ)))
    (hx0 : x0 = x ps) (htangent : piHODL x0 y0 ps = V ps)
    (hps : 0 < ps) (hP : 0 < P) :
    V P ≤ piHODL x0 y0 P := by
  subst hx0
  have hval : V ps = x ps * ps + y0 := by rw [← htangent]; rfl
  have key : V P - V ps ≤ x ps * (P - ps) := by
    rcases lt_trichotomy P ps with h | h | h
    · have hcont : ContinuousOn V (Icc P ps) := fun q hq =>
        (hV q (lt_of_lt_of_le hP hq.1)).continuousAt.continuousWithinAt
      obtain ⟨c, hc, hceq⟩ := exists_hasDerivAt_eq_slope V x h hcont
        (fun q hq => hV q (lt_trans hP hq.1))
      have hxc : x ps ≤ x c := hanti (mem_Ioi.2 (lt_trans hP hc.1)) (mem_Ioi.2 hps) hc.2.le
      rw [eq_div_iff (by linarith)] at hceq
      nlinarith [hceq]
    · simp [h]
    · have hcont : ContinuousOn V (Icc ps P) := fun q hq =>
        (hV q (lt_of_lt_of_le hps hq.1)).continuousAt.continuousWithinAt
      obtain ⟨c, hc, hceq⟩ := exists_hasDerivAt_eq_slope V x h hcont
        (fun q hq => hV q (lt_trans hps hq.1))
      have hxc : x c ≤ x ps := hanti (mem_Ioi.2 hps) (mem_Ioi.2 (lt_trans hps hc.1)) hc.1.le
      rw [eq_div_iff (by linarith)] at hceq
      nlinarith [hceq]
  show V P ≤ x ps * P + y0
  linarith [key]

end PiPayoffs
