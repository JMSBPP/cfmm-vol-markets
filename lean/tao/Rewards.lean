import Mathlib

/-!
# Root-dividend ("rewards-per-tao") accounting (DTAO §5.3, eqns (78)–(83))

The efficient root-dividend accounting tracks a global `ρ` (`rewards_per_tao`)
and a per-user `δ` (`debt`), with claimable Alpha `α_c = τ·ρ − δ`.  The update
rules are:

* at a stake `Δτ`:   `τ' = τ + Δτ`,  `δ' = δ + ρ·Δτ`;
* at an injection `Δα`:  `ρ' = ρ + Δα / T`.

`DTAO.Rewards.accounting_step` is the inductive invariant (eqn (83)): after the
combined update the running claim agrees with `τ'·ρ' − δ'`.

**Correction to the source.**  The whitepaper's eqn (83) writes the final term
as `(δ + ρ·Δα)`.  That is a typo: with the stated update `δ' = δ + ρ·Δτ`
(eqn (80)) the correct closing term is `(δ + ρ·Δτ)`, as proved here.  The
literal `(δ + ρ·Δα)` version is *false* in general (it agrees only when
`Δτ = Δα`), recorded as `accounting_step_literal_false`.
-/

namespace DTAO.Rewards

/-
**Rewards-per-tao inductive invariant (corrected eqn (83)).**  The running
claim `α_c + (τ'/T)·Δα` equals `τ'·ρ' − δ'` with the updates
`τ' = τ+Δτ`, `ρ' = ρ+Δα/T`, `δ' = δ+ρ·Δτ` and `α_c = τ·ρ − δ`.
-/
theorem accounting_step (rho tau delta dtau dalpha T : ℝ) :
    (tau * rho - delta) + ((tau + dtau) / T) * dalpha
      = (tau + dtau) * (rho + dalpha / T) - (delta + rho * dtau) := by
        ring

/-
The literal eqn (83) closing term `(δ + ρ·Δα)` does **not** reproduce the
running claim in general: there exist parameter values for which it differs from
`τ'·ρ' − δ'`.
-/
theorem accounting_step_literal_false :
    ∃ rho tau delta dtau dalpha T : ℝ,
      (tau * rho - delta) + ((tau + dtau) / T) * dalpha
        ≠ (tau + dtau) * (rho + dalpha / T) - (delta + rho * dalpha) := by
          -- We can choose specific values for `rho`, `tau`, `delta`, `dtau`, `dalpha`, and `T` to demonstrate that the equation does not hold.
          use 0.3, 5, 0.7, 2, 1, 10
          norm_num

end DTAO.Rewards