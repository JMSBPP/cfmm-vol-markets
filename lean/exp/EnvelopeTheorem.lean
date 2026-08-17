/-
  exp/EnvelopeTheorem.lean

  Comparative statics via the **envelope theorem** for the mean–variance program
  of `exp/MeanVarianceOptimization.lean` / `exp/ComparativeStatics.lean`.

  ## What this file delivers (and why it answers the design question)

  The previous files established that the optimum is *attained* — the solution map
  `g(θ) = (Δᵢ⋆, η⋆)` and the value function `V(θ) = MVobj(θ, g(θ))` are well
  defined (`exists_optimizer`, `value`).  That existence result, on its own, does
  not give comparative statics: it does not say how `V` and `g` move when the
  market state `θ` moves.

  The requested tool is the **envelope representation**: express the optimal value
  through the optimal action and read off its sensitivity from the objective
  *holding the optimal action fixed*.  Concretely, for any smooth one-parameter
  perturbation `s ↦ Θ s` of the state that leaves the admissible box unchanged,

        d/ds V(Θ s) │_{s=0}  =  d/ds MVobj(Θ s, g(Θ 0)) │_{s=0}.            (ENV)

  i.e. the *total* derivative of the value equals the *partial* derivative of the
  objective with respect to the state, evaluated at the optimizer — the indirect
  effect through the moving optimizer `g(Θ s)` contributes nothing to first order.
  This is exactly the Milgrom–Segal (2002) envelope theorem, and it is the device
  that turns "the optimum exists" into "here is how the optimum responds".

  We provide three layers:

  * `envelope_abstract` — the pure real-analysis core (a nonnegative gap with a
    zero at the base point has matching derivatives there).
  * `value_ge_of_box_eq`, `value_diff_lower`, `value_diff_upper`,
    `value_diff_sandwich` — the *robust* (no differentiability) Milgrom–Segal
    inequalities.  For any two states with the same box, the change in the optimal
    value is sandwiched between the change of the objective evaluated at the old
    optimizer and at the new optimizer.  These hold with no smoothness whatsoever
    and already deliver monotone comparative statics by inspection (they
    specialize to the existing `value_antitone_gamma`).
  * `envelope_deriv` — the differentiable envelope identity (ENV) above.

  ## How the two attached papers fit

  * Strulovici–Weber, *Monotone Comparative Statics: A Geometric Approach* — its
    program is precisely "reparameterize the parameter space, using the
    first-order conditions, so that the optimal action moves monotonically even
    when Milgrom–Shannon fails."  (ENV) is the first-order object that paper
    differentiates: a reparameterization `θ ↦ φ(θ)` achieves monotone comparative
    statics in a chosen action component exactly when the envelope/FOC vector
    field points the right way.  `envelope_deriv` and the sandwich are the Lean
    handles on that vector field.
  * Che–Kim–Kojima, *Monotone Comparative Statics without Lattices* — the
    admissible box `[1,200]×[a,b]` is a (pseudo) lattice, but the model's η̃ layer
    randomizes over ticks, and lottery spaces `Δ(X)` are the canonical *non*-lattice
    example.  Their pseudo-lattice machinery (`single crossing` + `pseudo
    quasi-supermodularity` ⇒ argmax monotone in the weak/strong pSS order) is what
    licenses MCS once the control is a distribution rather than a point; the
    sandwich inequalities here are the ordinal, derivative-free inputs that those
    theorems consume.

  Everything reuses `CFMM.ComparativeStatics` (`MVobj`, `box`, `g`, `g_mem`,
  `g_isMax`, `value`, `value_isMax`); no economic primitive is redefined.
-/
import Mathlib
import exp.ComparativeStatics

open scoped BigOperators Topology
open CFMM.ComparativeStatics

namespace CFMM.Envelope

variable {m : ℕ}

/-! ## Pure core: a nonnegative gap, zero at the base point, has equal derivatives -/

/-- **Abstract envelope core.**  If `f ≤ V` everywhere and `f 0 = V 0`, then at the
    base point `0` any derivatives of `f` and `V` coincide.  (The gap `V − f ≥ 0`
    attains its minimum `0` at `s = 0`, so its derivative there vanishes.)  This is
    the analytic engine of the envelope theorem. -/
theorem envelope_abstract {f V : ℝ → ℝ} {df dV : ℝ}
    (hle : ∀ s, f s ≤ V s) (heq : f 0 = V 0)
    (hf : HasDerivAt f df 0) (hV : HasDerivAt V dV 0) : dV = df := by
  have hmin : IsLocalMin (fun s => V s - f s) 0 :=
    Filter.Eventually.of_forall (fun s => by
      simp only; have := hle s; linarith [heq])
  have := hmin.hasDerivAt_eq_zero (hV.sub hf)
  linarith

/-! ## Robust Milgrom–Segal inequalities (no differentiability) -/

/-- The optimizer of `θ` is feasible at any state `θ'` with the same box, hence is
    dominated by the value of `θ'`. -/
theorem value_ge_of_box_eq (θ θ' : MarketState m) (hbox : box θ = box θ') :
    MVobj θ' (g θ) ≤ value θ' :=
  value_isMax θ' (g θ) (hbox ▸ g_mem θ)

/-- **Lower envelope inequality.**  When the two states share the admissible box,
    the increase in optimal value is at least the increase of the objective
    evaluated at the *old* optimizer `g θ` (a feasible deviation at `θ'`). -/
theorem value_diff_lower (θ θ' : MarketState m) (hbox : box θ = box θ') :
    MVobj θ' (g θ) - MVobj θ (g θ) ≤ value θ' - value θ := by
  have h1 : MVobj θ' (g θ) ≤ value θ' := value_ge_of_box_eq θ θ' hbox
  have h2 : value θ = MVobj θ (g θ) := rfl
  linarith

/-- **Upper envelope inequality.**  Symmetrically, the increase in optimal value
    is at most the increase of the objective evaluated at the *new* optimizer
    `g θ'` (a feasible deviation at `θ`). -/
theorem value_diff_upper (θ θ' : MarketState m) (hbox : box θ = box θ') :
    value θ' - value θ ≤ MVobj θ' (g θ') - MVobj θ (g θ') := by
  have h1 : MVobj θ (g θ') ≤ value θ := value_ge_of_box_eq θ' θ hbox.symm
  have h2 : value θ' = MVobj θ' (g θ') := rfl
  linarith

/-- **Milgrom–Segal sandwich.**  The change in optimal value lies between the two
    "fixed-action" objective changes.  This is the derivative-free heart of
    comparative statics: any monotonicity of the bounds transfers to `V`. -/
theorem value_diff_sandwich (θ θ' : MarketState m) (hbox : box θ = box θ') :
    MVobj θ' (g θ) - MVobj θ (g θ) ≤ value θ' - value θ
      ∧ value θ' - value θ ≤ MVobj θ' (g θ') - MVobj θ (g θ') :=
  ⟨value_diff_lower θ θ' hbox, value_diff_upper θ θ' hbox⟩

/-! ## The differentiable envelope theorem -/

/-- **Envelope theorem (ENV).**  Let `Θ : ℝ → MarketState` be a one-parameter
    perturbation of the market state whose admissible box is constant in the
    perturbation.  Then the derivative of the value function equals the derivative
    of the objective with the optimal action held fixed at `g (Θ 0)`:

        d/ds V(Θ s)│₀ = d/ds MVobj(Θ s, g (Θ 0))│₀.

    The optimizer moves, but to first order its movement does not affect the
    optimal value — the classical envelope/indirect-effect-vanishes statement,
    here in the robust Milgrom–Segal form. -/
theorem envelope_deriv (Θ : ℝ → MarketState m)
    (hbox : ∀ s, box (Θ s) = box (Θ 0)) {df dV : ℝ}
    (hf : HasDerivAt (fun s => MVobj (Θ s) (g (Θ 0))) df 0)
    (hV : HasDerivAt (fun s => value (Θ s)) dV 0) :
    dV = df := by
  -- `f s := MVobj (Θ s) (g (Θ 0))` underestimates `V s := value (Θ s)`, with
  -- equality at `s = 0`; apply the abstract core.
  refine envelope_abstract (f := fun s => MVobj (Θ s) (g (Θ 0)))
    (V := fun s => value (Θ s)) (fun s => ?_) ?_ hf hV
  · -- feasibility: `g (Θ 0) ∈ box (Θ 0) = box (Θ s)`, so it is dominated by `V (Θ s)`.
    exact value_isMax (Θ s) (g (Θ 0)) ((hbox s).symm ▸ g_mem (Θ 0))
  · -- equality at the base point: `value (Θ 0) = MVobj (Θ 0) (g (Θ 0))` by definition.
    rfl

end CFMM.Envelope
