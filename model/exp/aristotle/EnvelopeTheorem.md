# What the two papers buy us, and the envelope deliverable

Companion to `exp/EnvelopeTheorem.lean`.

## The two attached papers

**Strulovici–Weber, *Monotone Comparative Statics: A Geometric Approach*.**
This is the paper that directly matches the request ("reparametrizations / express
the optimum through the optimal actions to do comparative statics"). Its thesis:
when the standard Milgrom–Shannon characterization fails (the objective is not
quasi-supermodular / single-crossing in the *given* parameterization), you can
still get monotone comparative statics by **reparameterizing the parameter
space** through a one-to-one map. The object they build and differentiate is the
first-order condition / a vector field on parameter space pointing in a direction
along which the optimal action moves monotonically. For a smooth problem this is
*always* achievable for any single chosen action component, given enough knowledge
of where the optimizer sits.

**Che–Kim–Kojima, *Monotone Comparative Statics without Lattices*.**
This generalizes Topkis / Milgrom–Shannon from lattices to **pseudo lattices**
(any compact set with a largest and smallest element). It characterizes when the
argmax correspondence is monotone (in the weak/strong pseudo-strong-set order) via
**pseudo quasi-supermodularity** plus **single crossing**. The reason this matters
here: the model's η̃ layer randomizes over ticks, and lottery spaces `Δ(X)` are the
canonical *non*-lattice example, so once the control is a distribution rather than
a point the classical lattice theory does not apply — but the pseudo-lattice
theory does.

So, concretely, the two buy us:
- a license (Che–Kim–Kojima) to do MCS on the optimizer set even over the
  distributional/η̃ control, where the lattice property fails; and
- a constructive program (Strulovici–Weber) to *reparameterize* `θ` so that the
  optimal `Δᵢ⋆` and `η⋆` respond monotonically, built on the FOC / envelope.

Both consume the same low-level input: derivative-free *ordinal* comparisons of the
objective, and, in the smooth case, the **envelope identity**. That is what this
file formalizes first.

## The envelope deliverable (`exp/EnvelopeTheorem.lean`)

Existence (`exists_optimizer`, `value`) alone says nothing about how the optimum
*moves*. The envelope representation expresses the optimal value through the
optimal action and reads its sensitivity from the objective with the action held
fixed.

- **Robust (no smoothness) Milgrom–Segal sandwich.** For any two states `θ, θ'`
  sharing the admissible box,
  ```
  MVobj θ' (g θ)  − MVobj θ (g θ)   ≤  V(θ') − V(θ)  ≤  MVobj θ' (g θ') − MVobj θ (g θ')
  ```
  (`value_diff_lower`, `value_diff_upper`, `value_diff_sandwich`). The value change
  is trapped between the objective change at the old optimizer and at the new
  optimizer. Any monotonicity of these bounds transfers to `V` immediately — this
  is exactly the derivative-free ordinal input the MCS theorems above use, and it
  specializes to the existing `value_antitone_gamma`.

- **Differentiable envelope theorem.** For a smooth one-parameter perturbation
  `s ↦ Θ s` of the state with constant box,
  ```
  d/ds V(Θ s)│₀  =  d/ds MVobj(Θ s, g (Θ 0))│₀
  ```
  (`envelope_deriv`): the *total* derivative of the value equals the *partial*
  derivative of the objective at the fixed optimizer — the optimizer moves, but its
  movement contributes nothing to first order. This is the FOC object that the
  Strulovici–Weber reparameterization differentiates.

- **Analytic core.** `envelope_abstract`: a nonnegative gap with a zero at the base
  point has matching derivatives there (the gap `V − f ≥ 0` is minimized at `0`).

All results reuse `CFMM.ComparativeStatics` and depend only on the standard axioms
`propext`, `Classical.choice`, `Quot.sound`; the file has no `sorry`.

## Suggested next steps (the other two toolkit pieces)

1. The `P = λ^(i·Δᵢ·η)` reparameterization that turns the transcendental objective
   into a rational one in `P` — the explicit Strulovici–Weber-style change of
   coordinates that makes the FOC algebraic.
2. The monotone-comparative-statics layer proper: single crossing /
   (pseudo) quasi-supermodularity of `MVobj` in `(control; θ)`, feeding the
   Che–Kim–Kojima / Milgrom–Shannon monotonicity theorems to get `g(θ)` monotone.
