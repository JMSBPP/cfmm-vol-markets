/-
  exp/EtaPartitionChange.lean — formal counterpart to the closing block of
  the η̄-pricing spec note: re-expressing a price computed under a *custom*
  admissible state-partition delta `Δᵢ` (and elasticity `η`) in terms of
  the *canonical* partition `(1/2, Δ̄ᵢ)`.

  The note ends with the requirement: denoting pricing under a custom
  admissible state partition `Δᵢ ≠ Δ̄ᵢ` by `p_{(η,Δᵢ)}(i)`, find the values
  `(i⋆, i°)` such that

      p_{(η,Δᵢ)}(i)  =  p_{(1/2,Δ̄ᵢ)}(i⋆) · p_{(1/2,Δ̄ᵢ)}(i°).

  Here the pricing kernel under partition `(η, Δᵢ)` is (cf. `p_eta` in
  `exp.EtaReplication`)

      p_{(η,Δᵢ)}(x)  =  λ^{x · Δᵢ · η}.

  Since the exponent is multiplicative in the base `λ`, the product on the
  right-hand side has exponent `(i⋆ + i°) · Δ̄ᵢ / 2`, so the decomposition
  holds **iff**

      (i⋆ + i°) · Δ̄ᵢ  =  2 · i · Δᵢ · η.                              (★)

  This file makes the answer precise and proves it:

    • `p_eta_partition_change` — the *exact* real-tick witnesses
      `i⋆ = i° = i·Δᵢ·η / Δ̄ᵢ` (the symmetric split) satisfy the identity
      whenever `λ > 0` and `Δ̄ᵢ ≠ 0`; this is the general solution of (★).

    • `exists_partition_change` — existence form of the same statement.

    • `p_eta_partition_change_int` — the integer-tick version: any integer
      ticks `(i⋆, i°)` solving the commensurability relation (★) give the
      decomposition exactly (no `Δ̄ᵢ ≠ 0` needed). Exact *integer* ticks
      exist precisely when `2·i·Δᵢ·η` is an integer multiple of `Δ̄ᵢ`; the
      asymmetric choice `(i⋆, i°) = (n, 0)` with `n·Δ̄ᵢ = 2·i·Δᵢ·η` is the
      simplest such witness (`p_{(1/2,Δ̄ᵢ)}(0) = 1`).

  This generalizes `eta_split_kernel_identity` (which is the special case
  `η = 1/2`, `Δᵢ = Δ̄ᵢ`, where (★) reduces to `i⋆ + i° = i`).
-/
import Mathlib
import exp.eta
import exp.EtaReplication

open Real
open scoped BigOperators

namespace CFMM.Eta

/-- **Real-tick pricing kernel** under partition `(η, Δᵢ)`:
    `p_{(η,Δᵢ)}(x) = λ^{x · Δᵢ · η}`, with the tick `x` ranging over `ℝ`.
    Agrees with `p_eta` on integer ticks (`p_eta_real_intCast`). -/
noncomputable def p_eta_real (lam Δi eta x : ℝ) : ℝ :=
  lam ^ (x * Δi * eta)

/-- On integer ticks the real-tick kernel coincides with `p_eta`. -/
@[simp] lemma p_eta_real_intCast (lam Δi eta : ℝ) (i : Int) :
    p_eta_real lam Δi eta (i : ℝ) = p_eta lam Δi eta i := rfl

/-- **Change of state partition (real ticks).**

    A price computed under the custom partition `(η, Δᵢ)` at tick `i`
    factors as a product of two *canonical* `(1/2, Δ̄ᵢ)` prices at the
    symmetric real ticks `i⋆ = i° = i·Δᵢ·η / Δ̄ᵢ`:

        p_{(η,Δᵢ)}(i)
          = p_{(1/2,Δ̄ᵢ)}(i·Δᵢ·η/Δ̄ᵢ) · p_{(1/2,Δ̄ᵢ)}(i·Δᵢ·η/Δ̄ᵢ).

    These witnesses solve the commensurability relation (★) of the file
    header. -/
theorem p_eta_partition_change
    (lam : ℝ) (hlam : 0 < lam)
    (Δi Δbar eta : ℝ) (hΔbar : Δbar ≠ 0) (i : Int) :
    p_eta lam Δi eta i
      = p_eta_real lam Δbar (1 / 2) ((i : ℝ) * Δi * eta / Δbar)
        * p_eta_real lam Δbar (1 / 2) ((i : ℝ) * Δi * eta / Δbar) := by
  unfold p_eta p_eta_real
  rw [← Real.rpow_add hlam]
  congr 1
  field_simp
  ring

/-- **Existence form of the change of partition.**  There exist (real)
    canonical-partition ticks `(i⋆, i°)` realizing the custom-partition
    price as a product of two canonical-partition prices. -/
theorem exists_partition_change
    (lam : ℝ) (hlam : 0 < lam)
    (Δi Δbar eta : ℝ) (hΔbar : Δbar ≠ 0) (i : Int) :
    ∃ istar icirc : ℝ,
      p_eta lam Δi eta i
        = p_eta_real lam Δbar (1 / 2) istar * p_eta_real lam Δbar (1 / 2) icirc :=
  ⟨_, _, p_eta_partition_change lam hlam Δi Δbar eta hΔbar i⟩

/-- **Change of state partition (integer ticks).**

    Any *integer* canonical-partition ticks `(i⋆, i°)` satisfying the
    commensurability relation (★)

        (i⋆ + i°) · Δ̄ᵢ = 2 · i · Δᵢ · η

    realize the custom-partition price exactly as the product of two
    canonical `(1/2, Δ̄ᵢ)` prices.  (No `Δ̄ᵢ ≠ 0` is needed in this
    direction.)  Exact integer witnesses exist precisely when the
    right-hand side is an integer multiple of `Δ̄ᵢ`; e.g. `(n, 0)` with
    `n · Δ̄ᵢ = 2 · i · Δᵢ · η`. -/
theorem p_eta_partition_change_int
    (lam : ℝ) (hlam : 0 < lam)
    (Δi Δbar eta : ℝ) (i istar icirc : Int)
    (h : ((istar : ℝ) + (icirc : ℝ)) * Δbar = 2 * (i : ℝ) * Δi * eta) :
    p_eta lam Δi eta i
      = p_eta lam Δbar (1 / 2) istar * p_eta lam Δbar (1 / 2) icirc := by
  unfold p_eta
  rw [← Real.rpow_add hlam]
  congr 1
  linarith [h]

end CFMM.Eta
