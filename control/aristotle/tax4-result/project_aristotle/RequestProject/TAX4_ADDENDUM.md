# DRAFT — The returns reduction of `τ*_MEV` (M28–M32)

**Scope.** One reduction and four consequences. All algebraic. `H1` and `H2` remain **typed
hypotheses, never proved**. `ScaleHomogeneous` likewise.

**A refutation is a successful outcome.** M28's derivation is the orchestrator's own algebra,
done by substitution and **not otherwise checked**. It is submitted precisely so it receives the
treatment its author cannot give it. **Do not narrow a claim to make it provable** — exhibit the
witness and say so. The three prior bundles each returned refutations that redirected the
project, and the same is expected here.

---

## Standing bans — carried forward, unchanged

1. **Never identify Capponi's curvature `κ` with the `ε_{X/M}` substitution axis.** CES embedding
   **machine-refuted** (`canon_Fcap_not_CES`); only endpoints embed.
2. **`η` is the GRID-SIDE TILT** (`DOC:184`), not the trading-curve share. `κ_φ` depends on
   `ε_{X/M}` alone — `χ` cancels identically (`DOC` Proposition 7).
3. **`π^{\varphi}` (portfolio value, `DOC:821`) ≠ `π^{\phi}` (fee revenue).** The `φ`/`varphi`
   split is binding.
4. **`Proposition 13`'s domain lines stay guarded.** Never restate `τ* < 1` or the `τ* > 0` iff
   without `0 < ∂φ/∂ν, ∂ν/∂τ < 0, φ_X < 1`.
5. Cite prior results by **declaration name AND file**.

---

## The reformulation this bundle rests on

`DOC` Proposition 9 and Definition 26 give all three payoff objects as **one level times
scale-free factors** (CPMM, `DOC:946`):

\[
\frac{\pi^{\mathrm{LVR}}}{\pi^{\varphi}} = \frac{\sigma^2 \Delta t}{8},
\qquad
\frac{\pi^{\text{ARB}}}{\pi^{\varphi}} = \frac{\sigma^2 \Delta t}{8}\,\mathbb{P}_{\Delta_{\text{ARB}}},
\qquad
\frac{\pi^{\phi}}{\pi^{\varphi}} = \frac{\sigma^2 \Delta t}{8}\bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)
\]

This is not new coordinates — `DOC:838` already rules *"MEV runs in MONEY coordinates
`(π^LVR/π^linear)`"*, and `λ_ARB`'s summand is already normalized. The reformulation propagates
that convention to the `ν` side.

---

## **M28. [CLAIM — THE REDUCTION] `τ*` is explicit, not implicit**

Write `ε ≡ ∂\log \Delta Q / ∂\log \phi`, the **fee elasticity of flow** — scale-free, and the
object `MevTaxChannels.Theorem39_elasticity_closes` already establishes as closing.

Substituting `SRC` Convention 9 (`∂φ/∂ν = (1−φ_M)(1−τ_MEV)·∂φ_X/∂ν`) and `SRC` Theorem 33 route
(ii), with `∂ν/∂φ = ν ε/φ`, into `SRC` Theorem 32's bracket:

\[
\begin{aligned}
\text{bracket}
&= (1-\phi_M)(1-\phi_X) \; + \; (1-\phi_M)(1-\tau_{\text{MEV}})\frac{\partial \phi_X}{\partial \nu}\cdot\frac{\nu\epsilon}{\phi}\,(1-\phi_M)(1-\phi_X) \\
&= (1-\phi_M)(1-\phi_X)\Bigl[\,1 \; + \; (1-\phi_M)(1-\tau_{\text{MEV}})\frac{\partial \phi_X}{\partial \nu}\frac{\nu\epsilon}{\phi}\,\Bigr]
\end{aligned}
\]

**Theorem 40 (Returns reduction) [M28].** Prove or refute: `(1−φ_M)(1−φ_X) > 0` divides out, and

\[
\boxed{\;\tau^{\star}_{\text{MEV}} \; = \; 1 \; + \; \frac{\phi}{(1-\phi_M)\,\bigl(\partial \phi_X/\partial \nu\bigr)\,\nu\,\epsilon}\;}
\]

**Corollary 40 (Consistency) [M28].** Prove that this **agrees with**
`MevTaxProgram.Proposition16_corrected_law`'s conjunct 1. **This is the claim's real content.**
If the two disagree, one is wrong and the disagreement is the deliverable.

**Corollary 40b (The implicitness was an artifact) [M28].** `Proposition 13` is implicit — every
factor evaluated at `ν(τ*)` — **because `∂φ/∂ν` hides a `(1−τ_MEV)` inside it** via Convention 9.
Extract that factor and `τ_MEV` appears exactly once. Prove or refute: the self-reference the M24
audit recorded as a defect of the boxed law is a property of the **composite denominator**, not of
the optimization.

**Note what vanishes.** `(1−φ_X)` cancels. `H1` does not appear — it lives in `K`
(`MevTaxLVR.Theorem37_K_pos`), which cancels at the root. The surviving unknown is `ε` alone.

**Falsification targets.** (a) Is `∂ν/∂φ = νε/φ` licensed? It presumes `ν ∝ ΔQ` under
proportional legs; `SRC` Theorem 33(a) and the open **PR-REGION** ruling (`DOC:423`) bear on this,
and the one-sided flow case gives `∂ν/∂ΔQ = 0`
(`MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`). (b) Does the division by
`(1−φ_M)(1−φ_X)` require `φ_M, φ_X < 1` strictly, and is that guaranteed? (c) Does the reduction
survive when **both** channels of `SRC` Theorem 34 are live, i.e. under the loop correction
`naive/(1−loop)`?

---

## **M29. [CLAIM — SCALE] `τ*` does not depend on the pool scale**

**Theorem 41 (Scale-freeness of the control law) [M29].** Prove or refute: every factor of
Theorem 32's bracket is scale-free — `(1−φ_M)(1−φ_X)` trivially; `∂φ/∂ν` is fee-per-ratio;
`∂ν/∂τ` is ratio-per-fee — while `K` carries every dimension. Hence `τ*` is **invariant under
`L̄ → cL̄`**.

**Corollary 41 (M27's obstruction does not reach the control law) [M29].**
`MevTaxChannels.Theorem39_arb_side_does_not_close` names the pool scale as the missing primitive
for `∂ΔQ^{ARB}/∂φ`, **a quantity**. Prove or refute: the controller never requires that object —
only the ratio derivative `∂ν/∂φ`, in which the scale cancels between `∂ν/∂ΔQ ∝ 1/\bar L` and
`∂ΔQ/∂φ ∝ \bar L`. If so, the missing primitive is missing from a question the control law does
not ask, and `π^{\varphi}` is needed only to report `π̂^σ`'s **magnitude**, never its stationary
point.

---

## **M30. [CLAIM — COMPARATIVE STATICS] Which way does the optimal tax move?**

**Theorem 42 (Comparative statics of `τ*`) [M30].** Determine the sign of each, stating the
domain on which it holds:

\[
\frac{\partial \tau^{\star}}{\partial \epsilon},
\qquad
\frac{\partial \tau^{\star}}{\partial \nu},
\qquad
\frac{\partial \tau^{\star}}{\partial \gamma_R},
\qquad
\frac{\partial \tau^{\star}}{\partial \alpha_R},
\qquad
\frac{\partial \tau^{\star}}{\partial \bar\phi}
\]

with `∂φ_X/∂ν` expanded from `DOC` Definition 18's gate
`u(ν) = α_R/(1+\exp(γ_R(β_R − ν)))`.

**Also give the limits** `ε → 0^-` (inelastic) and `|ε| → ∞` (elastic), and say what each means
for the admissible set.

**No sign is asserted here, deliberately.** The orchestrator has a reading of the `ε` limits and
has withheld it, having been wrong three times in one session on signs reasoned rather than
checked. Derive them.

---

## **M31. [CLAIM — ADMISSIBILITY] The threshold elasticity**

`Proposition 13` gives `τ* > 0 ⟺ 1−φ_X < |(∂φ/∂ν)(∂ν/∂τ)|`, under its guard.

**Theorem 43 (Threshold elasticity) [M31].** Prove or refute: in the reduced form that condition
becomes a threshold on `ε` alone,

\[
|\epsilon| \; > \; \epsilon^{\star}\bigl(\phi, \phi_M, \nu, \Theta_{\phi}\bigr)
\]

with `ε*` in closed form. Below the threshold **no interior tax is optimal** and the constrained
optimum is the corner `τ = 0`.

**Why this is asked.** It converts an unobservable-gain problem into a **design question with a
number**: given the pool's `Θ_φ` and operating `ν`, how elastic must flow be before taxing is
worth doing at all? That is actionable without ever point-identifying `ε`.

---

## **M32. [CLAIM — SECOND ORDER] Is the root a minimum?**

`MevTaxProgram.Proposition15_level_reading_second_order_undetermined` leaves this **OPEN**, and
`Proposition15_single_crossing_gives_minimum` is conditional on a single-crossing property
**nothing proves**. This is the project's standing open item **O2** and it is load-bearing:
`SRC` Definition 36 minimizes `(∂π̂^σ/∂τ)²`, so a root that is a maximum of `π̂^σ` is still a
minimum of the objective, and the two readings differ.

**Theorem 44 (Second-order condition in the reduced form) [M32].** With `ε` explicit rather than
buried inside `∂ν/∂τ`, compute `∂²π̂^σ/∂τ²` at the root and determine whether its sign is settled
by `(ε, ν, Θ_φ, φ_M)`. If it is, **O2 closes**. If it is not, state precisely what remains
undetermined and whether single crossing is now decidable.

---

## What a complete return looks like

- `Theorem 40` + `Corollary 40` + `Corollary 40b`, or a witness against the reduction.
  **The consistency check against `Proposition16_corrected_law` is mandatory either way.**
- `Theorem 41` + `Corollary 41`.
- `Theorem 42` with signs and domains; the two `ε` limits.
- `Theorem 43` with `ε*` in closed form, or a refutation of the threshold's existence.
- `Theorem 44`, or a precise statement of what still blocks O2.
- Every declaration `#print axioms`-clean or its dependency stated. **No new `sorry`.** A stated
  `OPEN` with a reason is preferred to a narrowed theorem.
