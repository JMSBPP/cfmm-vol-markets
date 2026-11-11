import Mathlib
import RequestProject.TickDualMapping

/-!
# The control layer restarted in `g`-space

This module restarts the control layer of the realized-volatility forge **in the transformed
variable** `x = g (i) = exp (β i)` of `RequestProject/TickDualMapping.lean`.  It does *not* extend
the `κ`/IVT construction of `RequestProject/TickControlLayer.lean`: here the control gains are
given by an explicit closed-form expression in the data (including the shock stream), so no
intermediate-value argument and no `Classical.choose` occurs anywhere.

## The state space

* **state**   `x j = g (i j) = exp (β · i j)`  (strictly positive),
* **output**  `y j = ln σ (i j) = α - ln (x j)`,
* **input**   `u j = ε j` — the exogenous shock (*Shape B*: the shocks are the input, they are
  never solved for),
* **lag identity**  `x j = x (j-1) · g (Δ i j)` (`xPath_lag_identity`).

## The `g`-native recursion

Because `g` turns increments into quotients (`TickDualMapping.tickMap_separable`), the natural
recursion in `g`-space is **multiplicative**:

`x j = A · x (j-1) · B j (u j)`,      `B j u = exp (b j · u)`.

`b : ℕ → ℝ` is the (deterministic, pre-scheduled) per-step log-gain of the shock — in the
Lamperti/variance-stabilised coordinate the noise enters `ln x` with a coefficient that is
constant over the step, `b j = β · σ_j · √d̄t` (`gGain`, `iPath_euler_step`).

The single scalar gain `A` is fixed **in closed form** by the terminal pin `y N = ln σ̄`,
equivalently `x N = e^α / σ̄`:

`A = exp (lnGainA)`,   `lnGainA = ((α - ln σ̄ - β i₀) - Σ_{j=1}^{N} b j · ε j) / N`,

a plain arithmetic expression in `(α, β, σ̄, i₀, N, b)` and the shock stream (through one sum).
This is the whole design: a geometric (log-bridge) drift correction that lands the `g`-state on
the target exactly, whatever the realized shocks are.

## What is proved

* `xPath_pos`, `xPath_closed_form` — the path is well defined (positive, so `ln` is licit) and
  has the explicit product/exponential-of-sum form;
* `gainA_pow_spec` — `A` is characterised algebraically by `A^N · x₀ · e^{Σ b ε} = e^α / σ̄`;
* `xPath_lag_identity`, `gStep_eq` — the lag identity `x j = x (j-1) · g (Δ i j)`, with the step
  factor identified as `A · B j (ε j)`;
* `xPath_terminal`, `yOut_terminal`, `vol_terminal` — the terminal pin, in `x`-, `y`- and
  `σ`-form;
* `vol_eq_expAlpha_div_x`, `yOut_eq`, `vol_eq_exp_yOut` — σ-profile consistency: at every node
  `σ = e^α / x`, `y = α - β i = ln σ`;
* `iPath_succ`, `iPath_euler_step` — the induced tick recursion, and its reading as an Euler step
  with per-step volatility `b j / (β √d̄t)`.

## Forge order

`ε → (A, B) → {x j} → {i j}` — see `forgeEvaluationOrder` and `forgeEvaluationOrder_spec`.
-/

namespace TickGSpaceControl

open Real
open TickDualMapping

/-! ## Part 1: the `g`-space data and the closed-form gains -/

/-- Parameters of the `g`-space forge schedule.

`b` is the deterministic per-step log-gain schedule of the shock (`b j = β σ_j √d̄t` in the
variance-stabilised coordinate, cf. `gGain`); `ε` is supplied separately, since every statement
below holds for an arbitrary fixed shock stream. -/
structure GParams where
  /-- Intercept of `ln σ`: `α = ln (σ_F / (L_{1/2} ln 1.0001))`. -/
  alpha : ℝ
  /-- Slope of `ln σ` in the tick: `β = ln 1.0001 > 0`. -/
  beta : ℝ
  /-- Initial tick `i (0)`. -/
  i0 : ℝ
  /-- Target realized volatility `σ̄ > 0`. -/
  sigbar : ℝ
  /-- Number of steps `N = Window / d̄t ≥ 1`. -/
  N : ℕ
  /-- Fixed time step `d̄t > 0`. -/
  dt : ℝ
  /-- Per-step log-gain of the shock (deterministic schedule). -/
  b : ℕ → ℝ
  beta_pos : 0 < beta
  dt_pos : 0 < dt
  sigbar_pos : 0 < sigbar
  N_pos : 0 < N

namespace GParams

variable (P : GParams) (ε : ℕ → ℝ)

/-- The initial `g`-state `x₀ = g (i₀) = exp (β i₀)`. -/
noncomputable def x0 : ℝ := tickMap P.beta P.i0

theorem x0_pos : 0 < P.x0 := tickMap_pos _ _

/-- The target `g`-state pinned by `σ̄`: `x N = e^α / σ̄`. -/
noncomputable def xTarget : ℝ := Real.exp P.alpha / P.sigbar

theorem xTarget_pos : 0 < P.xTarget := div_pos (Real.exp_pos _) P.sigbar_pos

/-- Accumulated shock log-gain over the first `n` steps, `Σ_{j=1}^{n} b j · ε j`.
This is the *only* way the shock stream enters the gains — through a closed-form sum. -/
noncomputable def shockSum (n : ℕ) : ℝ := ∑ j ∈ Finset.range n, P.b (j + 1) * ε (j + 1)

@[simp] theorem shockSum_zero : P.shockSum ε 0 = 0 := by simp [shockSum]

theorem shockSum_succ (n : ℕ) :
    P.shockSum ε (n + 1) = P.shockSum ε n + P.b (n + 1) * ε (n + 1) := by
  simp [shockSum, Finset.sum_range_succ]

/-- **The closed-form drift gain, in logs.**  A log-bridge correction: the shortfall between the
target log-state and the accumulated shock log-gain, spread evenly over the `N` steps. -/
noncomputable def lnGainA : ℝ :=
  ((P.alpha - Real.log P.sigbar - P.beta * P.i0) - P.shockSum ε P.N) / (P.N : ℝ)

/-- **`A`** — the multiplicative drift gain of the `g`-native recursion. -/
noncomputable def gainA : ℝ := Real.exp (P.lnGainA ε)

theorem gainA_pos : 0 < P.gainA ε := Real.exp_pos _

/-- **`B`** — the multiplicative input gain: the shock `u = ε j` enters the `g`-state through
`B j u = exp (b j · u)`. -/
noncomputable def gainB (j : ℕ) (u : ℝ) : ℝ := Real.exp (P.b j * u)

theorem gainB_pos (j : ℕ) (u : ℝ) : 0 < P.gainB j u := Real.exp_pos _

theorem log_gainB (j : ℕ) (u : ℝ) : Real.log (P.gainB j u) = P.b j * u := by
  simp [gainB, Real.log_exp]

/-- The canonical Lamperti log-gain schedule: a step of tick volatility `σ` over `d̄t` moves
`ln x = β i` by `β σ √d̄t · ε`. -/
noncomputable def gGain (beta sig dt : ℝ) : ℝ := beta * sig * Real.sqrt dt

/-! ## Part 2: the path in `g`-space -/

/-- **The `g`-native recursion**: `x j = A · x (j-1) · B j (ε j)`, driven by the exogenous input
`u j = ε j`. -/
noncomputable def xPath : ℕ → ℝ
  | 0 => P.x0
  | (j + 1) => P.gainA ε * xPath j * P.gainB (j + 1) (ε (j + 1))

@[simp] theorem xPath_zero : P.xPath ε 0 = P.x0 := by simp [xPath]

theorem xPath_succ (j : ℕ) :
    P.xPath ε (j + 1) = P.gainA ε * P.xPath ε j * P.gainB (j + 1) (ε (j + 1)) := by
  simp [xPath]

/-- **The path is well defined**: the `g`-state stays strictly positive, so `ln` (hence the tick
and the output) is defined at every node. -/
theorem xPath_pos (j : ℕ) : 0 < P.xPath ε j := by
  induction j with
  | zero => simpa [xPath] using P.x0_pos
  | succ j ih =>
      rw [xPath_succ]
      exact mul_pos (mul_pos (P.gainA_pos ε) ih) (P.gainB_pos _ _)

theorem xPath_ne_zero (j : ℕ) : P.xPath ε j ≠ 0 := ne_of_gt (P.xPath_pos ε j)

/-- **Closed form of the path**: a pure exponential of the accumulated drift and shock log-gains
(no recursion left). -/
theorem xPath_closed_form (n : ℕ) :
    P.xPath ε n = P.x0 * Real.exp ((n : ℝ) * P.lnGainA ε + P.shockSum ε n) := by
  induction n with
  | zero => simp [xPath]
  | succ n ih =>
      have hcollect : ∀ u v w : ℝ,
          Real.exp u * (P.x0 * Real.exp v) * Real.exp w = P.x0 * Real.exp (u + v + w) := by
        intro u v w; rw [Real.exp_add, Real.exp_add]; ring
      rw [xPath_succ, ih, gainA, gainB, shockSum_succ, hcollect]
      congr 1
      push_cast
      congr 1
      ring

/-- The log of the `g`-state along the path. -/
theorem log_xPath (n : ℕ) :
    Real.log (P.xPath ε n) = P.beta * P.i0 + ((n : ℝ) * P.lnGainA ε + P.shockSum ε n) := by
  rw [xPath_closed_form, Real.log_mul (ne_of_gt P.x0_pos) (ne_of_gt (Real.exp_pos _)),
    Real.log_exp, x0, tickMap, Real.log_exp]

/-- **`A` is the closed-form solution of the terminal pin**, algebraically: after `N` steps the
accumulated drift gain `A^N`, the initial state and the realized shock gain multiply to the
target `g`-state `e^α / σ̄`. -/
theorem gainA_pow_spec :
    P.gainA ε ^ P.N * P.x0 * Real.exp (P.shockSum ε P.N) = P.xTarget := by
  have hN : ((P.N : ℝ)) ≠ 0 := Nat.cast_ne_zero.mpr P.N_pos.ne'
  have hpow : P.gainA ε ^ P.N = Real.exp ((P.N : ℝ) * P.lnGainA ε) := by
    rw [gainA, ← Real.exp_nat_mul]
  have hlin : (P.N : ℝ) * P.lnGainA ε + P.shockSum ε P.N
      = P.alpha - Real.log P.sigbar - P.beta * P.i0 := by
    rw [lnGainA]
    field_simp
    ring
  have hgroup : Real.exp ((P.N : ℝ) * P.lnGainA ε) * Real.exp (P.beta * P.i0)
        * Real.exp (P.shockSum ε P.N)
      = Real.exp (((P.N : ℝ) * P.lnGainA ε + P.shockSum ε P.N) + P.beta * P.i0) := by
    rw [Real.exp_add, Real.exp_add]; ring
  rw [hpow, x0, tickMap, hgroup, hlin,
    show P.alpha - Real.log P.sigbar - P.beta * P.i0 + P.beta * P.i0
      = P.alpha - Real.log P.sigbar from by ring,
    xTarget, Real.exp_sub, Real.exp_log P.sigbar_pos]

/-- **Terminal pin in `g`-space**: `x N = e^α / σ̄`. -/
theorem xPath_terminal : P.xPath ε P.N = P.xTarget := by
  have := P.gainA_pow_spec ε
  rw [xPath_closed_form, Real.exp_add, ← mul_assoc]
  rw [gainA, ← Real.exp_nat_mul] at this
  calc P.x0 * Real.exp ((P.N : ℝ) * P.lnGainA ε) * Real.exp (P.shockSum ε P.N)
      = Real.exp ((P.N : ℝ) * P.lnGainA ε) * P.x0 * Real.exp (P.shockSum ε P.N) := by ring
    _ = P.xTarget := this

/-! ## Part 3: back to ticks, and the output map -/

/-- The tick path recovered from the `g`-state: `i j = ln (x j) / β` (the recoverable inverse of
`g`). -/
noncomputable def iPath (j : ℕ) : ℝ := Real.log (P.xPath ε j) / P.beta

/-- The output of the state-space model: `y j = ln σ (i j) = α - ln (x j)`. -/
noncomputable def yOut (j : ℕ) : ℝ := P.alpha - Real.log (P.xPath ε j)

@[simp] theorem iPath_zero : P.iPath ε 0 = P.i0 := by
  have hβ : P.beta ≠ 0 := ne_of_gt P.beta_pos
  rw [iPath, xPath_zero, x0, tickMap, Real.log_exp]
  field_simp

/-- `g` maps the tick path back to the `g`-state: the change of variable is exact. -/
theorem tickMap_iPath (j : ℕ) : tickMap P.beta (P.iPath ε j) = P.xPath ε j := by
  rw [tickMap, iPath, mul_div_cancel₀ _ (ne_of_gt P.beta_pos),
    Real.exp_log (P.xPath_pos ε j)]

/-- The induced **tick recursion**: an affine step whose drift is `lnGainA / β` and whose shock
coefficient is `b j / β`. -/
theorem iPath_succ (j : ℕ) :
    P.iPath ε (j + 1) = P.iPath ε j + (P.lnGainA ε + P.b (j + 1) * ε (j + 1)) / P.beta := by
  have hβ : P.beta ≠ 0 := ne_of_gt P.beta_pos
  rw [iPath, iPath, log_xPath, log_xPath, shockSum_succ]
  push_cast
  field_simp
  ring

/-- Reading the tick step as an **Euler step**: with the Lamperti schedule `b j = β σ_j √d̄t`,
the shock enters the tick with coefficient `σ_j √d̄t`, i.e. the step volatility is
`b j / (β √d̄t)`. -/
theorem iPath_euler_step (j : ℕ) :
    P.iPath ε (j + 1) - P.iPath ε j
      = P.lnGainA ε / P.beta
        + (P.b (j + 1) / (P.beta * Real.sqrt P.dt)) * Real.sqrt P.dt * ε (j + 1) := by
  have hβ : P.beta ≠ 0 := ne_of_gt P.beta_pos
  have hdt : Real.sqrt P.dt ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr P.dt_pos)
  rw [iPath_succ]
  field_simp
  ring

/-- With the Lamperti schedule `b j = β σ √d̄t` the per-step volatility read off from
`iPath_euler_step` is exactly `σ`. -/
theorem stepVol_of_gGain (sig : ℝ) (j : ℕ) (h : P.b j = gGain P.beta sig P.dt) :
    P.b j / (P.beta * Real.sqrt P.dt) = sig := by
  have hβ : P.beta ≠ 0 := ne_of_gt P.beta_pos
  have hdt : Real.sqrt P.dt ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr P.dt_pos)
  rw [h, gGain]
  field_simp

/-- The one-step factor in `g`-space, `g (Δ i j) = A · B j (ε j)`: the gains are exactly the
increment of the transformed state. -/
theorem gStep_eq (j : ℕ) :
    tickMap P.beta (P.iPath ε (j + 1) - P.iPath ε j) = P.gainA ε * P.gainB (j + 1) (ε (j + 1)) := by
  have hβ : P.beta ≠ 0 := ne_of_gt P.beta_pos
  rw [iPath_succ, tickMap, gainA, gainB, ← Real.exp_add]
  congr 1
  field_simp
  ring

/-- **The lag identity** `x j = x (j-1) · g (Δ i j)` holds along the generated path. -/
theorem xPath_lag_identity (j : ℕ) :
    P.xPath ε (j + 1) = P.xPath ε j * tickMap P.beta (P.iPath ε (j + 1) - P.iPath ε j) := by
  rw [gStep_eq, xPath_succ]; ring

/-! ### σ-profile consistency -/

/-- **σ-profile consistency**: the model volatility at the generated tick is exactly `e^α / x`. -/
theorem vol_eq_expAlpha_div_x (j : ℕ) :
    vol P.alpha P.beta (P.iPath ε j) = Real.exp P.alpha / P.xPath ε j := by
  rw [vol_eq_div_tickMap, tickMap_iPath]

/-- The output map is the affine one, `y = α - β i = C · i + α` with `C = -β = -ln 1.0001`. -/
theorem yOut_eq (j : ℕ) : P.yOut ε j = P.alpha - P.beta * P.iPath ε j := by
  have hβ : P.beta ≠ 0 := ne_of_gt P.beta_pos
  rw [yOut, iPath]
  field_simp

/-- The output is the log volatility: `y j = ln σ (i j)`. -/
theorem yOut_eq_log_vol (j : ℕ) : P.yOut ε j = Real.log (vol P.alpha P.beta (P.iPath ε j)) := by
  rw [log_vol_affine, yOut_eq]

/-- Equivalently `σ (i j) = exp (y j)`. -/
theorem vol_eq_exp_yOut (j : ℕ) : vol P.alpha P.beta (P.iPath ε j) = Real.exp (P.yOut ε j) := by
  rw [yOut_eq, vol]

/-- **Terminal pin, output form**: `y N = ln σ̄`. -/
theorem yOut_terminal : P.yOut ε P.N = Real.log P.sigbar := by
  rw [yOut, xPath_terminal, xTarget,
    Real.log_div (ne_of_gt (Real.exp_pos _)) (ne_of_gt P.sigbar_pos), Real.log_exp]
  ring

/-- **Terminal pin, volatility form**: the generated path realizes the target, `σ (i N) = σ̄`. -/
theorem vol_terminal : vol P.alpha P.beta (P.iPath ε P.N) = P.sigbar := by
  rw [vol_eq_expAlpha_div_x, xPath_terminal, xTarget]
  field_simp

/-- **Terminal pin, tick form**: the endpoint tick is the one pinned by `σ̄`. -/
theorem iPath_terminal : P.iPath ε P.N = (P.alpha - Real.log P.sigbar) / P.beta := by
  rw [iPath, xPath_terminal, xTarget,
    Real.log_div (ne_of_gt (Real.exp_pos _)) (ne_of_gt P.sigbar_pos), Real.log_exp]

end GParams

/-! ## Part 4: the forge cron

Evaluation order: `ε → (A, B) → {x j} → {i j}`. -/

/-- The output of the `g`-space forge cron, in evaluation order: the closed-form gains `(A, B)`,
the `g`-state path `{x j}` and the emitted tick history `{i j}`. -/
noncomputable def forgeEvaluationOrder (P : GParams) (ε : ℕ → ℝ) :
    ℝ × (ℕ → ℝ → ℝ) × (ℕ → ℝ) × (ℕ → ℝ) :=
  -- 1. `ε` is exogenous;  2. compute `A`, `B` in closed form;  3. run `{x j}`;  4. emit `{i j}`.
  (P.gainA ε, P.gainB, P.xPath ε, P.iPath ε)

/-- **Specification of the cron.**  With `(A, B, x, i) = forgeEvaluationOrder P ε`:

* the `g`-state starts at `x₀ = g (i₀)` and follows the multiplicative recursion
  `x j = A · x (j-1) · B j (ε j)` driven by the exogenous shocks;
* the `g`-state is strictly positive, so the tick `i j = ln (x j) / β` is well defined and
  `g (i j) = x j`;
* the lag identity `x j = x (j-1) · g (Δ i j)` holds;
* the σ-profile is `σ (i j) = e^α / x j` at every node;
* the terminal pin holds: `σ (i N) = σ̄`, equivalently `x N = e^α / σ̄`. -/
theorem forgeEvaluationOrder_spec (P : GParams) (ε : ℕ → ℝ) :
    let out := forgeEvaluationOrder P ε
    let A := out.1
    let B := out.2.1
    let x := out.2.2.1
    let i := out.2.2.2
    x 0 = TickDualMapping.tickMap P.beta P.i0 ∧
    (∀ j, x (j + 1) = A * x j * B (j + 1) (ε (j + 1))) ∧
    (∀ j, 0 < x j) ∧
    (∀ j, TickDualMapping.tickMap P.beta (i j) = x j) ∧
    (∀ j, x (j + 1) = x j * TickDualMapping.tickMap P.beta (i (j + 1) - i j)) ∧
    (∀ j, TickDualMapping.vol P.alpha P.beta (i j) = Real.exp P.alpha / x j) ∧
    x P.N = Real.exp P.alpha / P.sigbar ∧
    TickDualMapping.vol P.alpha P.beta (i P.N) = P.sigbar :=
  ⟨rfl, fun j => P.xPath_succ ε j, fun j => P.xPath_pos ε j, fun j => P.tickMap_iPath ε j,
    fun j => P.xPath_lag_identity ε j, fun j => P.vol_eq_expAlpha_div_x ε j,
    P.xPath_terminal ε, P.vol_terminal ε⟩

/-- A witness that the `GParams` hypotheses are jointly satisfiable, so none of the statements
above is vacuous: unit slope, unit step, unit target volatility, one step, unit shock gain. -/
noncomputable def exampleParams : GParams where
  alpha := 1; beta := 1; i0 := 0; sigbar := 1; N := 1; dt := 1; b := fun _ => 1
  beta_pos := one_pos
  dt_pos := one_pos
  sigbar_pos := one_pos
  N_pos := Nat.one_pos

end TickGSpaceControl
