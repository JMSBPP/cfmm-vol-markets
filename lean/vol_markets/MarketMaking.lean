import vol_markets.EllIntrinsic

/-!
# MarketMaking — the vol-market trading function, bid/ask fee prices, and the ramp band

Three exercises from the project's TODO (2026-08-11), stated on the proved `EllIntrinsic`
scaffolding (imported, not copied).

## Notation map (deliberately disagrees with the governing document — do not rename)

`ε` here = the document's share `χ_{X/M}`; `ρ` here = the document's substitution
`ε_{X/M}`; `x`/`y` = the document's reserve legs `Q_X^L`, `Q_M^L`. `phiCES` is the
in-tree family. The document's fee is `φ ∈ (0,1)`; here it is `f` (φ is taken by the
family glyph in this file's comments).

## Instructions

Prove the `sorry`'d statements. Priority **S1 > S2 > A1 > A2 > A3 > R1 > R2**.

If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. In particular
**A1's sign is under genuine suspicion** — see its docstring; if the sign comes out
negative on `f ∈ (0,1)`, do NOT silently swap the bid/ask labels: prove the identity as
stated and ADD a lemma named `bidask_labels_inverted` recording the sign fact.

Do not modify any definition here or in `EllIntrinsic`.
-/

namespace MarketMaking

open Real Set EllIntrinsic

/-! ## Part S — the vol-market trading function φ^σ -/

/-- The vol-market trading function (document TODO item 1):
`φ^σ(x, y) = y − (L − x/2)²` with `L` the vol-asset liquidity. -/
noncomputable def phiSigma (L x y : ℝ) : ℝ := y - (L - x / 2) ^ 2

/-- Its marginal price: quotient of partials `∂_x φ^σ / ∂_y φ^σ`. -/
noncomputable def pSigma (L x : ℝ) : ℝ := L - x / 2

/-- **S1 — the closed kit of φ^σ.** (i) the marginal price is `L − x/2` (quotient of
partials); (ii) along the level curve `y(x) = c + (L−x/2)²` the tangent slope is `−p`
(the document's Theorem 33 consistency); (iii) the price impact is CONSTANT,
`dp/dx = −1/2`, so `Γ_φ = dx/dp = −2` — φ^σ is the constant-gamma curve; (iv) its
intrinsic liquidity (the `−2p^{3/2}/(dp/dx)` form of `EllIntrinsic`) is `4·p^{3/2}`. -/
theorem phiSigma_kit (L x c : ℝ) :
    HasDerivAt (fun t => phiSigma L t (c + (L - t / 2) ^ 2)) 0 x ∧
    HasDerivAt (fun t => c + (L - t / 2) ^ 2) (-(pSigma L x)) x ∧
    HasDerivAt (fun t => pSigma L t) (-(1 / 2)) x ∧
    (0 < pSigma L x →
      -2 * (pSigma L x) ^ ((3 : ℝ) / 2) / (-(1 / 2)) = 4 * (pSigma L x) ^ ((3 : ℝ) / 2)) := by
  have hlin : HasDerivAt (fun t : ℝ => L - t / 2) (-(1 / 2)) x := by
    simpa using ((hasDerivAt_id x).div_const 2).const_sub L
  have hsq : HasDerivAt (fun t : ℝ => (L - t / 2) ^ 2)
      (2 * (L - x / 2) ^ (2 - 1) * (-(1 / 2))) x := hlin.pow 2
  refine ⟨?_, ?_, ?_, ?_⟩
  · have hconst : (fun t : ℝ => phiSigma L t (c + (L - t / 2) ^ 2)) = fun _ : ℝ => c := by
      funext t; unfold phiSigma; ring
    rw [hconst]
    exact hasDerivAt_const x c
  · have := hsq.const_add c
    convert this using 1
    unfold pSigma
    ring
  · simpa [pSigma] using hlin
  · intro _
    ring

/-- **S2 — the boxed question `φ^ν → φ_{(χ,ε)}`: NO.** φ^σ is not a positive multiple of
any guarded CES member — the CES family is positively 1-homogeneous
(`phiCES_homogeneous`) and φ^σ is not (the square term). Expected shape: scale the state
by `t = 2` and compare. If some DEGENERATE identification survives (e.g. at a single
point or in a limit), record it under `phiSigma_CES_boundary` rather than weakening. -/
theorem phiCES_smul (ρ ε x y t : ℝ) (hρ : ρ ≠ 0) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hy : 0 < y) (ht : 0 < t) :
    phiCES ρ ε (t * x) (t * y) = t * phiCES ρ ε x y := by
  have hS : (0 : ℝ) ≤ ε * x ^ ρ + (1 - ε) * y ^ ρ := by
    have h1 : (0 : ℝ) < x ^ ρ := Real.rpow_pos_of_pos hx ρ
    have h2 : (0 : ℝ) < y ^ ρ := Real.rpow_pos_of_pos hy ρ
    nlinarith [hε.1, hε.2]
  have htr : (0 : ℝ) < t ^ ρ := Real.rpow_pos_of_pos ht ρ
  unfold phiCES
  rw [Real.mul_rpow ht.le hx.le, Real.mul_rpow ht.le hy.le,
    show ε * (t ^ ρ * x ^ ρ) + (1 - ε) * (t ^ ρ * y ^ ρ)
      = t ^ ρ * (ε * x ^ ρ + (1 - ε) * y ^ ρ) by ring,
    Real.mul_rpow htr.le hS, ← Real.rpow_mul ht.le,
    mul_one_div_cancel hρ, Real.rpow_one]

theorem phiSigma_not_CES (L : ℝ) (hL : 0 < L) :
    ¬ ∃ (A ρ ε : ℝ), 0 < A ∧ ρ ≠ 0 ∧ ε ∈ Ioo (0 : ℝ) 1 ∧
      ∀ x y : ℝ, 0 < x → 0 < y → phiSigma L x y = A * phiCES ρ ε x y := by
  rintro ⟨A, ρ, ε, hA, hρ, hε, h⟩
  have h1 : phiSigma L (2 * L) 1 = A * phiCES ρ ε (2 * L) 1 :=
    h (2 * L) 1 (by linarith) one_pos
  have h2 : phiSigma L (2 * (2 * L)) (2 * 1) = A * phiCES ρ ε (2 * (2 * L)) (2 * 1) :=
    h _ _ (by linarith) (by norm_num)
  rw [phiCES_smul ρ ε (2 * L) 1 2 hρ hε (by linarith) one_pos (by norm_num)] at h2
  have hv1 : phiSigma L (2 * L) 1 = 1 := by unfold phiSigma; ring
  have hv2 : phiSigma L (2 * (2 * L)) (2 * 1) = 2 - L ^ 2 := by unfold phiSigma; ring
  rw [hv1] at h1
  rw [hv2] at h2
  nlinarith [h1, h2, hL]

/-! ## Part A — bid/ask fee prices and the fee algebra -/

/-- Bid price as the TODO defines it: `P/f`. -/
noncomputable def Pbid (f P : ℝ) : ℝ := P / f

/-- Ask price as the TODO defines it: `f·P`. -/
noncomputable def Pask (f P : ℝ) : ℝ := f * P

/-- The document's fee monoid operation `⊗_φ`. -/
noncomputable def otimes (a b : ℝ) : ℝ := 1 - (1 - a) * (1 - b)

/-- **A1 — the relative spread identity, WITH ITS SIGN EXAMINED.**
`(P^ask − P^bid)/P = (f−1)(f+1)/f`. NOTE: on the document's fee domain `f ∈ (0,1)` this
quantity is NEGATIVE — i.e. `Pask < Pbid` under these label assignments. Prove the
identity as stated; if the sign fact holds, add `bidask_labels_inverted : f ∈ Ioo 0 1 →
Pask f P < Pbid f P` (for `0 < P`) rather than swapping any label. -/
theorem spread_identity (f P : ℝ) (hf : f ≠ 0) (hP : P ≠ 0) :
    (Pask f P - Pbid f P) / P = (f - 1) * (f + 1) / f := by
  unfold Pask Pbid
  field_simp
  ring

/-- **A1, sign fact.** The identity of `spread_identity` is NEGATIVE on the document's fee
domain `f ∈ (0,1)` (for a positive reference price): with the labels as the TODO assigns
them, `P^ask = f·P` is BELOW `P^bid = P/f`. The labels are therefore inverted relative to
the usual bid ≤ ask convention; recorded here rather than fixed by renaming. -/
theorem bidask_labels_inverted (f P : ℝ) (hf : f ∈ Ioo (0 : ℝ) 1) (hP : 0 < P) :
    Pask f P < Pbid f P := by
  obtain ⟨hf0, hf1⟩ := hf
  unfold Pask Pbid
  have h1 : f * P < P := by nlinarith
  have h2 : P < P / f := by
    rw [lt_div_iff₀ hf0]; nlinarith
  linarith

/-- **A2 — `⊗_φ` IS multiplication, on retention factors.** The complement map
`a ↦ 1−a` carries `⊗_φ` to plain multiplication: `1 − (a ⊗ b) = (1−a)(1−b)`. This is the
machine content behind "which algebra is more intuitive": the current monoid is EXACTLY
the multiplicative algebra of retained fractions. -/
theorem otimes_is_retention_mul (a b : ℝ) :
    1 - otimes a b = (1 - a) * (1 - b) := by
  unfold otimes
  ring

/-- **A3 — ask-composition is multiplicative in the fee factor, NOT `⊗_φ`-compatible.**
Composing two ask maps multiplies the factors: `Pask a (Pask b P) = Pask (a*b) P`; and
the analogous law with `⊗_φ` in place of `*` is FALSE (witness expected at
`a = b = 1/2`, `P = 1`: `3/4 ≠ 1/4`). Prove the first; refute the second as stated. -/
theorem ask_comp_mul (a b P : ℝ) :
    Pask a (Pask b P) = Pask (a * b) P := by
  unfold Pask
  ring

/- REFUTED AS STATED (see `ask_comp_otimes_false` below): composing two ask maps
multiplies the fee factors, and `⊗_φ` is NOT multiplication on the factors themselves
(it is multiplication on the RETENTIONS, `1 - ·`; see `otimes_is_retention_mul`). The
witness `a = b = 1/2`, `P = 1` gives `1/4` on the left and `3/4` on the right. The
statement is kept, commented out, as user-provided content.

theorem ask_comp_otimes (a b P : ℝ) :
    Pask a (Pask b P) = Pask (otimes a b) P := by
  sorry
-/

/-- **A3, refutation.** `ask_comp_otimes` is false: at `a = b = 1/2`, `P = 1` the left
side is `1/4` while the right side is `Pask (3/4) 1 = 3/4`. -/
theorem ask_comp_otimes_false :
    ¬ ∀ a b P : ℝ, Pask a (Pask b P) = Pask (otimes a b) P := by
  intro h
  have := h (1 / 2) (1 / 2) 1
  unfold Pask otimes at this
  norm_num at this

/-- **A3, corrected form.** `⊗_φ` composes ask maps once the arguments are read as FEES
and the maps as acting through the retained fraction: the ask map built from the retention
of `a ⊗ b` is the composite of the retention ask maps of `a` and of `b`. Precisely, with
`r c := 1 - c` the retention, `Pask (r (a ⊗ b)) P = Pask (r a) (Pask (r b) P)`. Only the
placement of the complement map has changed relative to `ask_comp_otimes`; the operation
and both definitions are untouched. -/
theorem ask_comp_otimes_corrected (a b P : ℝ) :
    Pask (1 - otimes a b) P = Pask (1 - a) (Pask (1 - b) P) := by
  unfold Pask otimes
  ring

/-! ## Part R — the ramp band (the Heaviside-level half of the Dirac reformulation)

The TODO's measure-valued position `d L̃ = L̄[δ(P^ask) − δ(P^bid)]` is the distributional
SECOND derivative of the ramp difference below; only the ramp/step level is formalized
here — the δ-statement stays a comment. -/

/-- The ramp (call payoff): `(t − K)⁺`. -/
noncomputable def ramp (K t : ℝ) : ℝ := max (t - K) 0

/-- **R1 — the ramp-band closed form.** For `a ≤ b` the call spread is the clamped band:
`ramp a t − ramp b t` equals `0` for `t ≤ a`, `t − a` on `[a,b]`, and `b − a` for
`b ≤ t`. -/
theorem ramp_band (a b t : ℝ) (hab : a ≤ b) :
    ramp a t - ramp b t
      = if t ≤ a then 0 else if t ≤ b then t - a else b - a := by
  unfold ramp
  rcases le_or_gt t a with h1 | h1
  · rw [if_pos h1, max_eq_right (by linarith), max_eq_right (by linarith)]
    ring
  · rw [if_neg (not_le.2 h1)]
    rcases le_or_gt t b with h2 | h2
    · rw [if_pos h2, max_eq_left (by linarith), max_eq_right (by linarith)]
      ring
    · rw [if_neg (not_le.2 h2), max_eq_left (by linarith), max_eq_left (by linarith)]
      ring

/-- **R2 — the step pair.** Strictly inside the band the call spread has slope `1`, and
strictly outside it has slope `0` — the first distributional derivative is the
indicator step pair (the Dirac pair is one derivative further and is NOT claimed
here). -/
theorem ramp_band_deriv (a b t : ℝ) (hab : a < b) :
    (a < t → t < b → HasDerivAt (fun s => ramp a s - ramp b s) 1 t) ∧
    (t < a → HasDerivAt (fun s => ramp a s - ramp b s) 0 t) ∧
    (b < t → HasDerivAt (fun s => ramp a s - ramp b s) 0 t) := by
  refine ⟨?_, ?_, ?_⟩
  · intro h1 h2
    have heq : (fun s => ramp a s - ramp b s) =ᶠ[nhds t] (fun s : ℝ => s - a) := by
      filter_upwards [Ioo_mem_nhds h1 h2] with s hs
      unfold ramp
      rw [max_eq_left (by linarith [hs.1]), max_eq_right (by linarith [hs.2])]
      ring
    exact ((hasDerivAt_id t).sub_const a).congr_of_eventuallyEq heq
  · intro h1
    have heq : (fun s => ramp a s - ramp b s) =ᶠ[nhds t] (fun _ : ℝ => (0 : ℝ)) := by
      filter_upwards [Iio_mem_nhds h1] with s hs
      have hsa : s < a := hs
      have hsb : s < b := lt_of_lt_of_le hsa hab.le
      unfold ramp
      rw [max_eq_right (by linarith), max_eq_right (by linarith)]
      ring
    exact (hasDerivAt_const t (0 : ℝ)).congr_of_eventuallyEq heq
  · intro h1
    have heq : (fun s => ramp a s - ramp b s) =ᶠ[nhds t] (fun _ : ℝ => b - a) := by
      filter_upwards [Ioi_mem_nhds h1] with s hs
      have hsb : b < s := hs
      have hsa : a < s := lt_trans hab hsb
      unfold ramp
      rw [max_eq_left (by linarith), max_eq_left (by linarith)]
      ring
    exact (hasDerivAt_const t (b - a)).congr_of_eventuallyEq heq

end MarketMaking
