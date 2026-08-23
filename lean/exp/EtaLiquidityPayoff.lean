/-
  exp/EtaLiquidityPayoff.lean — pricing the *liquidity*-side (short-vol)
  payoff π⁻, in the same structural style as the trader-side π⁺.

  Background (from `exp.EtaReplication`).  The long-vol trader payoff was
  defined "subject to an input and a price times the output" as a
  divergence
        π⁺ = d(p · Δᴵ, Δᴼ),     d = dSlip = (· − ·)²,
  where `p = p_eta`, the input is the trade `Δᴵ`, the priced input is
  `p·Δᴵ`, and the output is `Δᴼ = Delta_O_eta`.  The spec note then sets
        π⁻(Δᵢ;·) ≡ #·(−σ_{Δᵢ})  =  −(#·σ)  =  −π⁺,
  i.e. the liquidity / short-vol payoff is the sign-flip of the long-vol
  payoff, and asks: *the same way we priced π⁺ (an input and a price times
  the output), price the liquidity ΔL — reusing as much existing notation
  as possible.  What are some options?*

  This file answers with three concrete options, each reusing the existing
  objects (`dSlip`, `p_eta`, `p_eta_post`, `Delta_O_eta`, `pi_plus_eta`,
  `pi_eta_trader`) and introducing essentially **no new objects**, and
  proves how each relates to π⁺ and to the others.

  The structural fact that makes the liquidity input `ΔL` enter cleanly is
  the scaling geometry of the swap rules:

    • `p_eta_post_scale_invariant` — jointly scaling `(L, Δᴵ) ↦ (t·L, t·Δᴵ)`
      leaves the post-trade price unchanged (`t ≠ 0`).  This is precisely
      the *price-invariant region* of the note,
      `p(i, Δᴵ, L̄) = p(i, Δᴵ, L̄ + ΔL̄)`, in which liquidity is added.
    • `Delta_O_eta_scale_homog` — under that scaling the output is
      homogeneous of degree 1: `Δᴼ(t·L, t·Δᴵ) = t·Δᴼ(L, Δᴵ)`.
    • `pi_plus_eta_scale_homog` — hence π⁺ is homogeneous of degree 2:
      `π⁺(t·L, t·Δᴵ) = t²·π⁺(L, Δᴵ)`.

  OPTIONS for the priced liquidity payoff π⁻.

    Option A — sign duality (`pi_minus_eta`).  New objects: none.
      `π⁻ := −π⁺ = −d(p·Δᴵ, Δᴼ)`.  This is the literal `π⁻ ≡ #·(−σ)`.
      Liquidity does not appear explicitly; the LP is the trader's
      counterparty.

    Option B — liquidity-share scaling (`pi_minus_eta_liq`).  New objects:
      none beyond reusing `Delta_O_eta`/`dSlip` at the rescaled liquidity.
      Treating the supplied liquidity `ΔL` as the LP's *input*, the
      LP-attributed output is the degree-1 marginal `Δᴼ` in the
      price-invariant region, and the priced input is `p·(ΔL/L·Δᴵ)`.  Then
      `π⁻_liq = −d(p·(ΔL/L·Δᴵ), Δᴼ_liq) = −(ΔL/L)²·π⁺`
      (`pi_minus_eta_liq_eq`), so the LP payoff is the trader payoff scaled
      by the squared liquidity share `(ΔL/L)²` and sign-flipped.  At full
      share `ΔL = L` it collapses to Option A
      (`pi_minus_eta_liq_full_share`).

    Option C — η-CES Bregman duality (`pi_minus_eta_ces`).  New objects:
      none.  `π⁻_CES := −π_η^{trader}`, the sign-flip of the η-CES Bregman
      long-vol payoff.  Reduces to Option A at `η = 1/2`
      (`pi_minus_eta_ces_half`).
-/
import Mathlib
import exp.eta
import exp.EtaReplication
import exp.CESLongVolPayoff

open Real
open scoped BigOperators

namespace CFMM.Eta

/-! ## Scaling geometry of the swap rules (the price-invariant region) -/

/-- `dSlip` scales quadratically: `dSlip (t·a) (t·b) = t²·dSlip a b`. -/
lemma dSlip_smul (t a b : ℝ) : dSlip (t * a) (t * b) = t ^ 2 * dSlip a b := by
  unfold dSlip; ring

/-- **Price-invariant region.**  Jointly scaling liquidity and trade,
    `(L, Δᴵ) ↦ (t·L, t·Δᴵ)` with `t ≠ 0`, leaves the post-trade price
    unchanged.  This is the region `p(i, Δᴵ, L̄) = p(i, Δᴵ, L̄ + ΔL̄)` of
    the spec note, in which the liquidity provider operates. -/
theorem p_eta_post_scale_invariant
    (lam Δi eta : ℝ) (i : Int) (L Delta_I t : ℝ) (ht : t ≠ 0) :
    p_eta_post lam Δi eta i (t * L) (t * Delta_I)
      = p_eta_post lam Δi eta i L Delta_I := by
  unfold p_eta_post
  rw [show t * L * p_eta lam Δi eta i = t * (L * p_eta lam Δi eta i) from by ring,
      show t * L + p_eta lam Δi eta i * (t * Delta_I)
            = t * (L + p_eta lam Δi eta i * Delta_I) from by ring,
      mul_div_mul_left _ _ ht]

/-- **Degree-1 homogeneity of the output.**  Under the joint scaling
    `(L, Δᴵ) ↦ (t·L, t·Δᴵ)` the output is homogeneous of degree 1:
    `Δᴼ(t·L, t·Δᴵ) = t·Δᴼ(L, Δᴵ)`.  (Holds for all `t`, including `t = 0`.) -/
theorem Delta_O_eta_scale_homog
    (lam Δi eta : ℝ) (i : Int) (L Delta_I t : ℝ) :
    Delta_O_eta lam Δi eta i (t * L) (t * Delta_I)
      = t * Delta_O_eta lam Δi eta i L Delta_I := by
  rcases eq_or_ne t 0 with h | h
  · simp [Delta_O_eta, p_eta_post, h]
  · unfold Delta_O_eta
    rw [p_eta_post_scale_invariant lam Δi eta i L Delta_I t h]; ring

/-- **Degree-2 homogeneity of the trader payoff.**  Since the priced input
    `p·Δᴵ` and the output `Δᴼ` both scale by `t`, the squared-slippage
    payoff scales by `t²`: `π⁺(t·L, t·Δᴵ) = t²·π⁺(L, Δᴵ)`. -/
theorem pi_plus_eta_scale_homog
    (lam Δi eta : ℝ) (i : Int) (L Delta_I t : ℝ) :
    pi_plus_eta lam Δi eta i (t * L) (t * Delta_I)
      = t ^ 2 * pi_plus_eta lam Δi eta i L Delta_I := by
  unfold pi_plus_eta
  rw [Delta_O_eta_scale_homog,
      show p_eta lam Δi eta i * (t * Delta_I)
            = t * (p_eta lam Δi eta i * Delta_I) from by ring,
      dSlip_smul]

/-! ## Option A — sign duality (no new objects) -/

/-- **Option A: liquidity payoff as the sign-flip of the trader payoff.**
    `π⁻ := −π⁺`.  This is the literal `π⁻ ≡ #·(−σ)` of the spec note: the
    LP is the trader's counterparty, so its payoff is minus the trader's
    squared slippage. -/
noncomputable def pi_minus_eta (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) : ℝ :=
  - pi_plus_eta lam Δi eta i L Delta_I

/-- Option A is exactly `−d(p·Δᴵ, Δᴼ)` — the trader's "price times input vs
    output" divergence, negated. -/
theorem pi_minus_eta_eq_neg_dSlip
    (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) :
    pi_minus_eta lam Δi eta i L Delta_I
      = - dSlip (p_eta lam Δi eta i * Delta_I)
              (Delta_O_eta lam Δi eta i L Delta_I) :=
  rfl

/-- Option A is the negated η=1/2 squared-slippage payoff at the rescaled
    spacing `Δᵢ·η` (using `pi_plus_eta_eq_pi_trader_half`): `π⁻ = −π_{1/2}`. -/
theorem pi_minus_eta_eq_neg_pi_trader_half
    (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) :
    pi_minus_eta lam Δi eta i L Delta_I
      = - pi_trader_half lam (Δi * eta) i L Delta_I := by
  unfold pi_minus_eta
  rw [pi_plus_eta_eq_pi_trader_half]

/-! ## Option B — liquidity-share scaling (reuses `Delta_O_eta`, `dSlip`) -/

/-- **Liquidity-attributed output.**  Reusing `Delta_O_eta`, the reserve
    released by supplying liquidity `ΔL` in the price-invariant region is
    the output evaluated at liquidity `ΔL` with the proportionally scaled
    trade `ΔL/L·Δᴵ`.  By degree-1 homogeneity this equals `(ΔL/L)·Δᴼ`. -/
noncomputable def Delta_O_liq
    (lam Δi eta : ℝ) (i : Int) (L Delta_I ΔL : ℝ) : ℝ :=
  Delta_O_eta lam Δi eta i ΔL (ΔL / L * Delta_I)

/-- **Option B: priced liquidity payoff.**  Treating `ΔL` as the LP's
    input, the priced input is `p·(ΔL/L·Δᴵ)` and the output is the
    liquidity-attributed `Δᴼ_liq`; the payoff is their divergence, negated:
    `π⁻_liq := −d(p·(ΔL/L·Δᴵ), Δᴼ_liq)`. -/
noncomputable def pi_minus_eta_liq
    (lam Δi eta : ℝ) (i : Int) (L Delta_I ΔL : ℝ) : ℝ :=
  - dSlip (p_eta lam Δi eta i * (ΔL / L * Delta_I))
          (Delta_O_liq lam Δi eta i L Delta_I ΔL)

/-- **Option B in closed form.**  The priced liquidity payoff is the trader
    payoff scaled by the squared liquidity share `(ΔL/L)²` and sign-flipped:
    `π⁻_liq = −(ΔL/L)²·π⁺`. -/
theorem pi_minus_eta_liq_eq
    (lam Δi eta : ℝ) (i : Int) (L Delta_I ΔL : ℝ) (hL : L ≠ 0) :
    pi_minus_eta_liq lam Δi eta i L Delta_I ΔL
      = - (ΔL / L) ^ 2 * pi_plus_eta lam Δi eta i L Delta_I := by
  unfold pi_minus_eta_liq Delta_O_liq pi_plus_eta
  set t := ΔL / L with ht
  have hΔL : ΔL = t * L := by rw [ht]; field_simp
  rw [hΔL, Delta_O_eta_scale_homog,
      show p_eta lam Δi eta i * (t * Delta_I)
            = t * (p_eta lam Δi eta i * Delta_I) from by ring,
      dSlip_smul]
  ring

/-- **Option B reduces to Option A at full share.**  Supplying the whole
    pool (`ΔL = L`, share 1) makes the priced liquidity payoff coincide
    with the sign-dual payoff. -/
theorem pi_minus_eta_liq_full_share
    (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) (hL : L ≠ 0) :
    pi_minus_eta_liq lam Δi eta i L Delta_I L
      = pi_minus_eta lam Δi eta i L Delta_I := by
  rw [pi_minus_eta_liq_eq lam Δi eta i L Delta_I L hL]
  unfold pi_minus_eta
  rw [div_self hL]; ring

/-! ## Option C — η-CES Bregman duality (no new objects) -/

/-- **Option C: η-CES liquidity payoff.**  The sign-flip of the η-CES
    Bregman long-vol payoff `pi_eta_trader`.  Generalizes Option A to the
    whole η-CES family. -/
noncomputable def pi_minus_eta_ces
    (η lam Δi : ℝ) (i : Int) (L_bar Delta_I : ℝ) : ℝ :=
  - pi_eta_trader η lam Δi i L_bar Delta_I

/-- Option C reduces, at `η = 1/2`, to the negated squared-slippage payoff
    `−π_{1/2}` — the same short-vol object Option A is built from (here at
    spacing `Δᵢ`, since `pi_eta_trader` uses the η-independent kernel
    `P_half`). -/
theorem pi_minus_eta_ces_half
    (lam : ℝ) (hlam : 0 < lam)
    (Δi : ℝ) (i : Int) (L_bar Delta_I : ℝ) :
    pi_minus_eta_ces (1 / 2) lam Δi i L_bar Delta_I
      = - pi_trader_half lam Δi i L_bar Delta_I := by
  unfold pi_minus_eta_ces
  rw [pi_eta_extends_half lam hlam Δi i L_bar Delta_I]

end CFMM.Eta
