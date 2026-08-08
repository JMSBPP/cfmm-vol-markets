# Pitfalls Research

**Domain:** Lean-verified control-design specification for an optimal MEV-tax set-point `τ*_MEV` on an event-time MIMO plant.
**Researched:** 2026-08-08
**Confidence:** HIGH on the mathematical traps (read line-by-line against the source derivation and the actual Lean declarations); MEDIUM on the process/scope traps (read against PROJECT.md, IN-FLIGHT.md and the plank entry-point doc).

---

## How to read this file

Every entry carries four fields the roadmap consumes: **Severity**, **Status**, **Warning signs**, **Prevention**, **Phase**.

**Status labels** (quality gate for section 2):

| Label | Meaning |
|-------|---------|
| **CONFIRMED** | I read the exact lines / declarations and the defect is present as written. Line numbers cited. |
| **PLAUSIBLE** | The defect follows from objects I read, but closing it needs a definition or ruling I could not locate in-tree. |
| **SPECULATIVE** | Reasoned from the structure, not from a specific line. Flagged as such. |

**Severity:** BLOCKER = the deliverable is wrong or hollow if unaddressed. MAJOR = a substantive result is unsound or unverifiable. MINOR = correctness-preserving but costs time or invites drift.

**Source files under scrutiny:**

- `SRC` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/notes/VOLATILITY_INTRUMENTS_MEV.md` (235 lines — the derivation)
- `DOC` = `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` (1636 lines — the entry point / binding notation)
- `LEAN` = `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/vol_markets/`
- `PROJ` = `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/PROJECT.md`

---

## The one-paragraph verdict

Reverse-engineering the boxed `τ*_MEV` from `SRC:110` and `SRC:208-233` shows it is **algebraically equivalent to the single equation `∂π̂^σ/∂τ_MEV = ΔQ_v*`** — not to the stated replication relation `π^σ ≡^R π̂^σ`. The factor `(σ²(i(t)) − σ_K²)⁺` has vanished from the boxed law entirely. The whole "solve for `τ`" step consists of inverting one `(1 − τ_MEV)⁻¹` factor, and that factor itself comes from a chain-rule step (`SRC:108-110`) that adds derivatives taken along two incompatible sections of the same composed-fee level set. Independently, the 5-factor channel's "no other path" clause is **falsified by the source's own `∇φ` display three pages earlier** (`SRC:56`), which exhibits a direct partial `∂φ/∂τ_MEV = (1−φ_M)(1−φ_X) ≠ 0`. And the second factor `∂L(i_K)/∂π^φ` is **identically zero** under `DOC` Rule 9 as written. Any one of these is enough for a REFUTED verdict; the project's job is to produce that verdict rigorously rather than to patch around it.

---

# Critical Pitfalls (BLOCKER)

### B1. The boxed `τ*_MEV` does not solve the stated replication relation — it solves a different equation, and `(σ²−σ_K²)⁺` has disappeared

**Status: CONFIRMED** (reverse-engineered from `SRC:110`, `SRC:149-159`, `SRC:174-233`).

**What goes wrong.**
`SRC:110` gives

```
∂π^φ/∂φ = ΔQ_M / [(1−τ_MEV)(1−φ_X)]  +  p_{(η,Δᵢ)} ΔQ_X / [(1−τ_MEV)(1−φ_M)]
        = (1−τ_MEV)⁻¹ · [ ΔQ_M/(1−φ_X) + p_{(η,Δᵢ)} ΔQ_X/(1−φ_M) ]
```

Substituting into the 5-factor chain (`SRC:149-159`) and comparing term-by-term with the box (`SRC:208-233`) gives an exact match iff

```
(1 − τ*_MEV) · ΔQ_v*  =  [Σ_{i_K} π^l ∂L(i_K)/∂π^φ] · [bracket] · (∂φ/∂ν)(∂ν/∂τ_MEV)
⟺  ∂π̂^σ/∂τ_MEV  =  ΔQ_v*.
```

So the boxed law is the solution of **`∂π̂^σ/∂τ_MEV = ΔQ_v*`**, i.e. it equates a derivative *with respect to the tax* to a *vega notional*. The stated relation `π^σ ≡^R π̂^σ` with `π^σ = ΔQ_v*(σ²−σ_K²)⁺` is a **level** equation whose payoff factor `(σ²−σ_K²)⁺` appears nowhere in the box. There is no intermediate step in `SRC` connecting the two.

**Why it happens.** `ΔQ_v*` is simultaneously (i) the stored target-vega input (`DOC:692-698`) and (ii) `∂π^σ/∂σ²` on the ITM branch, since `π^σ = ΔQ_v*(σ²−σ_K²)⁺`. Definition 1 in `DOC:704` literally defines the lens readout as `ΔQ_v ≡ Δπ^σ/Δ(σ²−σ_K²)⁺`. It is therefore *very* easy to write `ΔQ_v*` on the right of a derivative-matching condition and believe you have solved a level-matching condition. The two differ by an entire factor, and the differentiation variables (`τ_MEV` on the left, `σ²` implicit on the right) do not even match.

**Warning signs.**
- Any draft that carries `ΔQ_v*` into an equation whose other side is a `∂/∂τ_MEV`.
- The boxed law being τ-free on its right-hand side (it is not — see B4) *and* `(σ²−σ_K²)⁺`-free.
- Anyone describing the box as "the closed form for the set-point" without being able to write the one intermediate line `π^σ = π̂^σ ⟹ …`.

**Prevention (actionable).**
1. Before any proving work, write the **missing intermediate line** explicitly and get a user ruling on which relation is intended:
   - **(R-level)** `ΔQ_v*(σ²−σ_K²)⁺ = Σ_{i_K} L(i_K) π^l(σ(i_K;Θ_σ))` — a nonlinear scalar equation in `τ`, which admits *no closed form* without an existence/uniqueness argument (monotonicity in `τ` + IVT).
   - **(R-vega)** `∂π̂^σ/∂(σ²) = ΔQ_v*` — the vega-matching read, consistent with `DOC:704`'s definition of `ΔQ_v`. `τ` then enters as a *parameter of the equation*, not the differentiation variable.
   - **(R-as-written)** `∂π̂^σ/∂τ_MEV = ΔQ_v*` — what the box actually is. State plainly that this equates objects with different differentiation variables and is dimensionally suspect (see B7).
2. Send **exactly one** of these to Aristotle as the target, with the other two named as rejected alternates in the prompt (the rejection record is first-class in this programme — cf. `tStarJointMult`'s rejected alternates at `DOC:756`).
3. If (R-as-written) is what the author meant, the honest deliverable is a **REFUTATION with the derivation gap named**, which `PROJ:17-23` explicitly counts as success.

**Phase:** Boxed-closed-form phase (must be the *first* thing settled — the channel and sign phases are downstream of which relation is being solved).

---

### B2. The 5-factor chain's "no other path" clause is false in the document's own notation — `τ_MEV` reaches the output by at least three additional routes

**Status: CONFIRMED** (`SRC:56` vs `SRC:149-159`; `SRC:123`; `DOC:1049-1056`, `DOC:1064`; `LEAN/TauMevAlgebra.lean:77-86`).

**What goes wrong.** The chain asserts

```
∂π̂^σ/∂τ_MEV = (∂π̂^σ/∂L)(∂L/∂π^φ)(∂π^φ/∂φ)(∂φ/∂ν)(∂ν/∂τ_MEV)
```

i.e. `τ_MEV → ν → φ → π^φ → L → π̂^σ` and nothing else. Enumerated counter-routes, all sourced from the same corpus:

- **P1 — the direct monoid path (fatal).** `SRC:56` itself displays
  `∇φ = [(1−φ_X)(1−τ_MEV), (1−φ_M)(1−τ_MEV), (1−φ_X)(1−φ_M)]ᵀ`.
  That third entry *is* `∂φ/∂τ_MEV = (1−φ_M)(1−φ_X)`, a **direct** partial of the composed fee w.r.t. the tax. It is exactly `DOC` Rule 12 (`DOC:1049-1056`): `φ_total ← φ_M ⊗_φ φ_X ⊗_φ τ_MEV`, so `1 − φ_total = (1−φ_M)(1−φ_X)(1−τ_MEV)` and the partial is nonzero for any `φ_M, φ_X < 1`. The chain omits it. **The source refutes its own exclusivity clause on page 2.**
- **P2 — the toxicity→liquidity path.** `SRC:123` argues `Ḡ > 0` partly via "a reduction on the denominator **by discouraging liquidity**". That is `∂L/∂λ_MEV < 0`, a route `τ → φ → λ_ARB → L → π̂^σ` that does not pass through `π^φ`. The source's own justification for the sign supplies a second path.
- **P3 — the demand-response path.** `τ` raises the composed fee, which lowers `ℙ_{Δ_ARB}` (proved: `TauMevAlgebra.tau_intensity_effect_strict`), which changes traded flow `ΔQ_X, ΔQ_M` — both of which sit in `u_ex` as *exogenous*. If flow responds to fee, `u_ex` is not exogenous and both `π^φ` and `ν` move by a route the chain does not contain.
- **P4 — the `π^φ` split path.** Under `DOC` Proposition 9 (`DOC:919-927`), `π^φ ≈ π^LVR·(1 − ℙ_{Δ_ARB})`, and `ℙ_{Δ_ARB}` depends on `φ_total` which depends on `τ` directly (P1). So even the `π^φ` node is reached without going through `ν`.

**Why it happens.** The chain is written as a scalar product of five univariate derivatives. That notation cannot represent a multivariate map with several arguments; the moment `φ` has three arguments `(φ_M, φ_X, τ_MEV)`, `∂φ/∂ν` alone is not the whole `dφ`.

**Warning signs.**
- A "channel" written as a product of five scalar derivatives with no Jacobian, no `Σ` over paths, and no explicit "held fixed" list on each factor.
- The `|_{λ_MEV}` restriction appearing on the objective (`SRC:133-139`) but on none of the five factors.
- Anyone saying "the other paths are second-order" without an order-of-magnitude estimate.

**Prevention (actionable).**
1. Replace the product with an explicit **total-derivative statement**: `dπ̂^σ/dτ = Σ_paths` over the dependency DAG of `(φ_M, φ_X, τ, ν, π^φ, L)`, and *prove* that the omitted paths are zero — not assume it. The DAG must be drawn in the state-space transcription phase, before the channel phase runs.
2. Give Aristotle the **negation as the target too**: `¬ (∀ …, ∂π̂^σ/∂τ = five-factor-product)`. P1 makes a witness cheap: pick `φ_M = φ_X = 0`, `∂ν/∂τ = 0`; then the RHS is 0 while `∂φ/∂τ = 1 ≠ 0` moves `π^φ` and hence `π̂^σ`. Expect the refutation to land fast.
3. Whatever survives must be stated as a **restricted** claim ("the chain is the total derivative *on the submanifold where φ_M, φ_X are held at 1*" — note that is the pole of B5, so it is not a usable restriction). Watch for the restriction quietly becoming vacuous.

**Phase:** 5-factor-channel phase; the DAG is owed by the state-space-transcription phase.

---

### B3. `∂ν/∂λ_MEV > 0` is substituted for `∂ν/∂τ_MEV`, and the two have opposite signs — the boxed law's sign is unestablished and probably inverted

**Status: CONFIRMED as a substitution** (`SRC:126` asserts `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0`; `SRC:158` and `SRC:231` then use `∂ν/∂τ_MEV`, which is never argued). **The sign composition is CONFIRMED-by-composition** against proved Lean results.

**What goes wrong.** Decompose the substituted object:

```
∂ν/∂τ_MEV = (∂ν/∂λ_MEV) · (∂λ_MEV/∂τ_MEV)
```

The first factor is asserted `> 0` (`SRC:123-126`). The second factor is **negative** and this is proved, not conjectured:
- `TauMevAlgebra.tau_monoid_gt` (`:53-56`): `φ < φ ⊗_φ τ` strictly, for `τ > 0`, `φ < 1` — the tax strictly raises the trader-paid fee.
- `TauMevAlgebra.tau_intensity_effect_strict` (`:77-86`): `ℙ_{Δ_ARB}(φ ⊗_φ τ) < ℙ_{Δ_ARB}(φ)` strictly.
- `MevOptimization.mevMulti_anti_phibar` / `_anti_alpha` / `_anti_u`: `λ_ARB` is antitone in every level parameter of the fee.
- Under uniform clearing, `MevJointProgram.mevTotal_eq_arb_of_sandwich_zero` gives `λ_MEV = λ_ARB`.

Hence `∂λ_MEV/∂τ_MEV < 0`, hence `∂ν/∂τ_MEV < 0` if `Ḡ > 0`. Substituting a **positive** `Ḡ` where a **negative** quantity belongs flips the sign of the entire boxed law.

**Consequence (and this is the punchline).** With `Σ π^l ∂L/∂π^φ > 0`, `[bracket] > 0`, `∂φ/∂ν > 0` (all the natural signs), and `∂ν/∂τ < 0`, the box gives

```
τ*_MEV = 1 − (1/ΔQ_v*)·(negative) = 1 + positive > 1,
```

which is **outside the monoid's admissible domain** — `TauMevAlgebra.tau_monoid_mem` requires `τ_MEV ∈ [0,1]`. So the corrected-sign box has *no admissible solution*.

**The second reading is no better.** The control objective at `SRC:133-139` is boxed as `𝒢 := ∂π̂^σ/∂τ_MEV |_{λ_MEV}` — **at constant `λ_MEV`**. But the only mechanism offered for `∂ν/∂τ_MEV` is via `λ_MEV` (`SRC:123`). At constant `λ_MEV`, that mechanism gives `∂ν/∂τ_MEV = 0`, the chain vanishes, and the box degenerates to `τ*_MEV = 1` — the corner. The two boxed displays (`SRC:133-139` objective vs `SRC:149-159` channel) are mutually inconsistent.

**Why it happens.** `λ` and `τ` are adjacent in every sentence of the MEV section, and the binding convention (`DOC:764`, Convention 4) distinguishes *`λ̃` incidence vs plain-`λ` hazard* — but does not warn about *`λ` hazard vs `τ` actuator*. Nothing in the notation makes the substitution look wrong.

**Warning signs.**
- Any factor written `∂·/∂τ_MEV` whose only supporting argument is a sentence about `λ_MEV`.
- A "gain" asserted constant (`SRC:126` says "we assume constant") while its factors are state-dependent.
- A `τ*` value that comes out `> 1` or `< 0` in any numerical sanity check. **This is the cheapest early detector: plug plausible numbers into the box before any proving starts.**

**Prevention (actionable).**
1. Make the two objects **separate named symbols** and never let them collide: keep `Ḡ_(ν,λ_MEV)` exactly as the source minted it, and require any tax-side gain to be written as the explicit composition `Ḡ_(ν,λ_MEV) · ∂λ_MEV/∂τ_MEV`. Do **not** mint a new symbol for the composition without a user ruling (binding rule, `PROJ:111-114`).
2. Prove `∂λ_MEV/∂τ_MEV < 0` in Lean first — it is nearly free by composing `tau_intensity_effect_strict` with `mevMulti_anti_phibar`, and it immediately settles the sign of the box.
3. Run the **numerical sanity harness before the proving phase**: instantiate the box with `φ_M = 0.003`, `φ_X = 0.01`, `ΔQ_M, ΔQ_X, ΔQ_v*` of realistic magnitude, and record whether `τ*` lands in `[0,1]`. A range violation is a refutation-in-waiting and costs an hour, not an Aristotle budget.
4. Resolve the `|_{λ_MEV}` contradiction with the user *before* drafting Lean statements — it changes what is being proved.

**Phase:** Sign phase, with a hard dependency edge into the closed-form phase (the closed form is not independently meaningful if the sign fails — already recorded at `PROJ:131`).

---

### B4. The "closed form" is an implicit equation — `τ_MEV` appears on both sides

**Status: CONFIRMED** (`SRC:208-233` in combination with `SRC:63`, `SRC:126`, `DOC:612-620`).

**What goes wrong.** The box presents `τ*_MEV = 1 − (…)` as if the right side were `τ`-free. It is not:
- `∂ν/∂τ_MEV` is a function of the operating point, which depends on `τ` (B3).
- `∂φ/∂ν` is the derivative of `DOC` Definition 18's utilization gate, evaluated at `ν(τ)`.
- `∂L(i_K)/∂π^φ` and `π^l(σ(i_K;·))` are evaluated at a state that `τ` moves.
- The *only* place the algebra actually removed `τ` is the single `(1−τ_MEV)⁻¹` factor of `SRC:110` — and that factor is itself the product of the defective section-choice in B5.

So the boxed law is a **fixed-point equation** `τ = F(τ)` dressed as a closed form. Nothing establishes existence, uniqueness, or a contraction property.

**Why it happens.** Factoring `(1−τ)⁻¹` out of one term makes the remaining expression *look* τ-free, because the remaining τ-dependence is hidden inside symbols (`∂ν/∂τ`, `∂φ/∂ν`) rather than displayed.

**Warning signs.**
- A "closed form" whose right side contains a derivative *with respect to the very variable being solved for* (`∂ν/∂τ_MEV` on the RHS of `τ* = …`). This is visible at a glance in `SRC:231`.
- Any implementation sketch (EVM phase) that computes `τ*` in one pass with no iteration and no convergence guard.

**Prevention (actionable).**
1. Restate the box as `τ = F(τ; state)` and add three explicit obligations to the closed-form phase: **existence**, **uniqueness**, **monotonicity of `F`** (so a bisection is well-defined on-chain). If any fails, that is the verdict.
2. If a genuine closed form is wanted, the derivation must show every RHS factor is evaluated at a `τ`-independent operating point — and that claim is itself a theorem, not a convention.
3. Feed the EVM-feasibility phase the *fixed-point* form, not the boxed form, so the cost envelope is honest (iteration count, saturation behaviour).

**Phase:** Closed-form phase (existence/uniqueness); EVM-feasibility phase (iteration cost).

---

### B5. `∂π^φ/∂φ` adds derivatives taken along two incompatible sections of the composed-fee level set

**Status: CONFIRMED** (`SRC:104-112` against `SRC:56` / `DOC` Rule 12).

**What goes wrong.** The map `(φ_M, φ_X, τ_MEV) ↦ φ_total = 1 − (1−φ_M)(1−φ_X)(1−τ_MEV)` is a submersion `ℝ³ → ℝ`. It has **no inverse**, so `∂φ_M/∂φ` and `∂φ_X/∂φ` are not defined without choosing a section (a curve in `ℝ³` projecting onto the `φ` axis). `SRC:110`'s two terms make **different** choices:

- Term 1, `ΔQ_M / [(1−τ)(1−φ_X)]` = `∂φ_M/∂φ` holding `(φ_X, τ)` fixed.
- Term 2, `p ΔQ_X / [(1−τ)(1−φ_M)]` = `∂φ_X/∂φ` holding `(φ_M, τ)` fixed.

You cannot add two directional derivatives taken along two different curves and call the sum `d/dφ`. Along any single admissible section, the correct object is a directional derivative whose value depends on the direction chosen; along the "move both legs proportionally" section, for instance, the answer is different from either term and from their sum.

**Why it happens.** The scalar notation `∂π^φ/∂φ` invites treating a 3→1 map as if it were invertible; the reciprocal of a partial derivative *is* correct for a 1→1 map, and the formula is written by analogy.

**Warning signs.**
- Reciprocals of partial derivatives of a multi-argument function appearing without a stated section.
- Two terms in one sum with *different* variables held fixed (visible here: term 1 has `(1−φ_X)`, term 2 has `(1−φ_M)` — the cross-pairing is the tell).
- Any statement of the form "`∂a/∂b = 1/(∂b/∂a)`" where `b` has more than one argument.

**Prevention (actionable).**
1. Fix the section **explicitly and once**, as a modelling decision recorded in the state-space phase. Natural candidates: (i) `φ_X` is the only free leg (`φ_M ≡ φ̄_M` is already assumed at `SRC:67`), which makes term 1 illegitimate and leaves only term 2; (ii) a pseudo-inverse / minimum-norm lift.
2. Prefer eliminating the step entirely: `π^φ` is a function of `(φ_M, φ_X)` directly (`SRC:106`), so write `dπ^φ = (∂π^φ/∂φ_M)dφ_M + (∂π^φ/∂φ_X)dφ_X` and never introduce `∂π^φ/∂φ` at all. This also removes the `(1−τ)⁻¹` factor — which removes the entire basis of the boxed inversion (B1, B4). **Expect this repair to dissolve the closed form.** That is a result, not a failure.
3. This is the single highest-leverage line in the derivation: the `(1−τ)⁻¹` produced here is the whole content of "solving for `τ`". The closed-form phase should audit this line first.

**Phase:** State-space-transcription phase (declare the section); channel phase (rework or delete the step).

---

### B6. `∂L(i_K)/∂π^φ` is identically zero under `DOC` Rule 9 — the control channel is dead in normal operation

**Status: CONFIRMED against `DOC` Rule 9 (`DOC:706-712`) and Rule 10 (`DOC:722-733`).**

**What goes wrong.** The chain's second factor is `∂L/∂π^φ` — the response of ladder liquidity to fee income. But `DOC` Rule 9 states the sizing map exactly:

```
L(i_K) ← ΔQ_v* · ℓ(ξ*, ι; i_K),    Σ_{i_K} L(i_K) = ΔQ_v*
```

"The mint sizes the ladder from the target vega **alone**"; `p_vol, p_risk` "enter at the ISSUANCE/ADMISSIBILITY layer … **never the sizing map**". Rule 10 adds: "The contract holds `ΔQ_v*` **fixed**, so all adaptation lands on collateral." Therefore, as written, `∂L(i_K)/∂π^φ = 0`, the chain is identically zero, and the box collapses to `τ*_MEV = 1`.

**The only surviving route is non-smooth and normally inactive.** Rule 10's funded-cap is
`ΔQ_v(t) ← min(ΔQ_v*, Q_M(t)/p_risk(t))`. Fee income can raise `Q_M`, so there *is* a route `π^φ → Q_M → ΔQ_v(t) → L(i_K)`. But:
- it is a `min`, so `∂L/∂π^φ` is **piecewise constant with a kink** at the funding boundary;
- it is **exactly zero** on the healthy branch `ΔQ_v* < Q_M/p_risk`;
- it is `ℓ(i_K)/p_risk` only on the collateral-constrained branch.

So the MEV tax controls the replication error **only when the vol position is under-collateralized**. That is a defensible mechanism but a completely different story from the one the derivation tells, and it must be stated as such.

**Compounding: the symbol `L` is overloaded.** In `π̂^σ = Σ_{i_K} L(i_K) π^l` (`SRC:193-202`), `L(i_K)` is the *order's* ladder allocation, pinned by Rule 9. In `ν_t = φ_(1/2,0)(i(t); ΔQ(t), 0) / φ_(1/2,0)(i(t); 0, L)` (`DOC:836`), `L` is the *aggregate pool* liquidity `Σ_j L_j`, which does respond to fee income. The chain silently uses one `L` for both. Fixing this is not cosmetic — it decides whether the channel exists.

**Warning signs.**
- A chain factor whose defining relation, when you look it up, contains the word "alone" or "never" (Rule 9 contains both).
- Two occurrences of `L` in one derivation with different index structure (`L(i_K)` vs bare `L`).
- Anyone estimating `∂L/∂π^φ` empirically without first asking *which* `L`.

**Prevention (actionable).**
1. In the state-space-transcription phase, **split the symbol**: keep `L(i_K)` for the ladder (Rule 9) and require a distinct, user-ruled symbol for aggregate pool liquidity. Do not mint it unilaterally — `PROJ:111-114` forbids that. Record the pair in a notation-map paragraph.
2. Then re-ask: which `L` does `π̂^σ` sum over, and which `L` sits in `ν`'s denominator? The answer determines whether the channel is (a) identically zero, (b) live only on the constrained branch, or (c) live via aggregate LP supply — and (c) collides with B8's no-elasticity caveat.
3. If the answer is (b), the deliverable changes: the design spec is for a controller that is **inactive in normal operation**, and the EVM-feasibility phase must handle a piecewise-constant, kinked gain.

**Phase:** State-space-transcription phase (symbol split, mandatory before anything else); channel phase (verdict on whether the factor is zero).

---

### B7. Three non-differentiabilities sit exactly at the point the derivation differentiates

**Status: CONFIRMED** for all three; the interaction with the stationarity argument is CONFIRMED.

**What goes wrong.**

1. **`(·)⁺` in `π^σ = ΔQ_v*(σ² − σ_K²)⁺`** (`SRC:182-189`). Kink at `σ² = σ_K²`. `∂π^σ/∂σ²` is `ΔQ_v*` above the strike, `0` below, undefined at it. `SRC:167` writes `∂π^σ/∂σ² ∈ (ΔQ_v, ∂π^σ/∂σ²(λ_MEV))` — an interval whose upper endpoint is defined in terms of the object itself, with no ordering guarantee that it *is* an interval.
2. **`|·|` in `e^σ = |π^σ − π̂^σ|`** (`SRC:34`). The derivation says "solving for `τ_MEV` on the **minimization**" (`SRC:204`). But the minimum of `|·|` is attained precisely where the argument is zero, which is exactly where `|·|` is non-differentiable. A first-order condition `∂e^σ/∂τ = 0` is **not** the optimality condition there; the correct statement is `0 ∈ ∂|·|`, which holds trivially at the root and gives no information about `τ`. Either the step is a *constraint solve* (then there is no minimization and no FOC), or it is an FOC (then it is applied at a kink). The source does not say which.
3. **`min` in Rule 10's funded cap** (`DOC:731`), inherited via B6.

**On the OTM branch the replication relation has no interior solution at all.** For `σ² < σ_K²`, `π^σ = 0`, so `π^σ = π̂^σ` forces `Σ_{i_K} L(i_K) π^l = 0` — attainable only at `L ≡ 0` or `π^l ≡ 0`. So `τ*` is either undetermined (any `τ` works) or infeasible on the entire out-of-the-money region, i.e. **half the state space**. Nothing in `SRC` acknowledges a branch structure.

**Why it happens.** Variance-swap payoffs are written with `(·)⁺` as a matter of course, and the kink is invisible until you differentiate. The `|·|` in the tracking error is standard control notation carried over without noticing that it is being *minimized to zero*, not regulated.

**Warning signs.**
- Any derivative of `π^σ` written without a branch condition `σ² ≷ σ_K²`.
- The word "minimization" (`SRC:204`) with no stated first-order condition, no subdifferential, and no argmin set.
- A Lean statement of the closed form with no hypothesis mentioning `σ_K²`.

**Prevention (actionable).**
1. **Split every statement by branch** from the outset: `σ² > σ_K²` (ITM), `σ² < σ_K²` (OTM), `σ² = σ_K²` (kink). Prove the ITM branch; state the OTM branch's degeneracy as a theorem (`τ*` undetermined), not as an omission.
2. Replace `|·|` with `(π^σ − π̂^σ)²` **only if the user rules it** — that changes the objective and is a notation/semantics decision, not a convenience. Otherwise state the problem as an equality constraint and drop all optimization language.
3. Require every Lean statement in this project to carry an explicit branch hypothesis. Aristotle will otherwise "helpfully" add guards of its own choosing — as it already did on `mevMulti_saturation_limit` and `mevMulti_exists_min_compact` (see the `[CORRECTED:]` annotations at `DOC:982`), and those additions changed what the theorem said.

**Phase:** Closed-form phase (branch split); state-space phase (declare `e^σ`'s status: constraint or objective).

---

# Major Pitfalls (MAJOR)

### M1. Poles at `φ_X → 1`, `φ_M → 1`, `ΔQ_v* → 0` — and the negative-fee pole that already falsified T15/T17

**Status: CONFIRMED** (`SRC:222-228`, `SRC:213`; `LEAN/MevOptimization.lean:36-37, 683-685, 795-798`).

**What goes wrong.** The bracket `[ΔQ_M/(1−φ_X) + p ΔQ_X/(1−φ_M)]` blows up as either leg fee approaches 1. This is **in-domain**: `TauMevAlgebra.tau_monoid_mem` closes the monoid on `[0,1]` *inclusive*, and `probOr` reaches 1. The prefactor `1/ΔQ_v*` has a pole at zero target vega, and `ΔQ_v*` is a user-supplied `u96` (`DOC:693-696`) with no positive lower bound stated in `SRC`.

Separately, `ptrade φ σ Δt = σ/(σ + φ√(2/Δt))` (`MevOptimization.lean:36-37`) is a **Möbius function with a pole at `φ = −σ/√(2/Δt)`**. The Lean tree records this as load-bearing twice:
- `mevMulti_saturation_limit` docstring (`:683-685`): "The additional nonnegativity of the limiting fee is necessary to keep the limit away from `ptrade`'s negative-fee pole."
- `mevMulti_exists_min_compact` docstring (`:795-798`): "The explicit nonnegative-level region is essential: **compactness alone does not avoid the pole**."
- `DOC:982` records both as `[CORRECTED:]` — Aristotle added the guards; the drafts were wrong as written.

A `τ*` outside `[0,1]` (B3) drives the composed fee out of `[0,1]`, which is exactly how a negative effective fee — and the pole — becomes reachable.

**Warning signs.** Any denominator in a drafted statement without a hypothesis naming it. Any compactness hypothesis offered as a substitute for a domain guard. Any `τ*` numeric that is not in `[0,1]`.

**Prevention.** Adopt a mechanical rule for this project: **every drafted Lean statement is grep'd for `/` and `⁻¹`, and each hit must be traceable to a named hypothesis.** Add `0 < ΔQ_v*`, `φ_M < 1`, `φ_X < 1`, `0 ≤ τ_MEV ≤ 1` and `0 ≤ φ_total` as standing hypotheses of the closed-form statement, and note in the spec that `φ = 1` is admissible in the monoid but inadmissible in the control law — that gap is itself a finding for the EVM phase (saturate-never-revert).

**Phase:** Closed-form phase (hypotheses); EVM-feasibility phase (saturation and bounds).

---

### M2. The prior result is misquoted: `(β_j, γ_j)` **do** control `λ_MEV`; what was proved is that they are not *essential* to the unconstrained joint program

**Status: CONFIRMED misquotation** (`SRC:70` and `PROJ:65-66` vs `MevJointProgram.lean:39-94` and `MevOptimization.mevMulti_mono_beta`).

**What goes wrong.** `SRC:70` says "the theorem that says `(β_j, γ_j)` does not control for `λ_MEV`". `PROJ:65-66` repeats it: "frozen by the theorem that they do not control `λ_MEV`". **No such theorem exists.** What exists is:

- `MevOptimization.mevMulti_mono_beta` — `λ_ARB` **is** monotone in `β`. So `β` *does* control it.
- `MevJointProgram.joint_corner_degeneracy` (T20), `joint_beta_degeneracy` (T21), `joint_scalarization_degeneracy` (T22) — FLAIR and `λ_ARB` are improved by the **same** `β → −∞` direction and the same level corner, robustly under every nonnegative scalarization. The module header (`:24-28`) states it precisely: "T20–T22 refute an unconstrained trade-off in `Θ_φ`: the shape block `(β, γ)` **is not essential**. It becomes relevant only under the fee-budget constraint."

Freezing `(β,γ)` remains a perfectly good modelling choice. But the *justification* as written is a fabricated theorem, and it is now in two documents.

**Why it matters beyond pedantry.** If `β` moves `λ_MEV`, then any claim that `τ` is *the* MEV actuator is a claim about a chosen restriction, not a structural fact — and the degeneracy carry-forward says the degeneracy-breaker lies **outside** `Θ_φ` (`DOC:984`). `τ` enters `Θ_φ`'s coordinate through Rule 12's monoid, so `τ` is a *level* lever: raising it raises the composed fee, raising FLAIR and lowering `λ_ARB` monotonically — **the same direction as the level corner**. If an *interior* `τ*` emerges, the interiority must be traced to a specific term (the replication constraint), not asserted. Otherwise this is the degeneracy error in a new guise.

**Warning signs.** Any sentence beginning "because of the theorem that says…" with no declaration name. Any claim that a monotone objective has an interior optimum. Any use of `τ` as "the degeneracy-breaker".

**Prevention.**
1. **Every prior-result citation in this project's artifacts carries the Lean declaration name and file.** Fix `SRC:70` and `PROJ:65-66` in the first phase that touches them; restate as "`(β,γ)` are frozen as a modelling choice; the joint program is degenerate in them (`joint_corner_degeneracy`, `joint_beta_degeneracy`, `joint_scalarization_degeneracy`), so freezing costs nothing in the unconstrained program."
2. In the closed-form phase, **require an explicit interiority argument**: name the term that makes `∂π̂^σ/∂τ` change sign. If none exists, `τ*` is a corner and the "set-point" is `0` or `1`.

**Phase:** Theory-basis phase (fix the citations); closed-form phase (interiority argument).

---

### M3. The state-space realization has no dynamic part — `x_{t+1} = A x_t + B u_t` may be `x_{t+1} = f(u_t)`

**Status: CONFIRMED structurally** (`SRC:8-25`, `SRC:42-49` against `DOC:612-620`, `DOC:833-836`, `SRC:106`).

**What goes wrong.** Of the four state coordinates `x = [φ, ν, π^φ, π^φ̃]ᵀ`:

- `φ` is an **algebraic function of the input** — it is `φ_M ⊗_φ φ_X ⊗_φ τ_MEV`, and all three arguments are declared in `u_en`. There is no `φ_t → φ_{t+1}` recursion anywhere.
- `π^φ` is an algebraic function of `(φ_M, φ_X, ΔQ_M, ΔQ_X)` by `SRC:106` — inputs only.
- `π^φ̃ ≡ π^φ − π^LVR` is algebraic given `π^LVR`, which `DOC:823-829` makes a state function of the current tick.
- `ν_t` is a per-step ratio of current flow to current liquidity (`DOC:836`) — again current-period.

So the `∂_{(t+1,t)}` block may be **structurally zero**, making the "plant" a memoryless map. If so, "set-point optimization on a MIMO plant with disturbance inputs" is a framing that adds a control-theoretic superstructure to a static inversion, and the entire Ogata/multivariable-feedback curation phase produces decoration rather than content.

Two further structural defects in the same display:
- **`u_en` contains non-actuators.** `PROJ:66-70` excludes `φ_M` (fixed at `φ̄_M`) and `φ_X` (`= Φ(Θ_φ; σ²(i(t)))`, a deterministic function of the *exogenous* `σ²`). A "control input" that is a function of a disturbance input makes the `B` columns linearly dependent on the disturbance channel — the realization is not well-posed as written.
- **`y` has an uncontrollable row.** `y = [π^σ, π̂^σ]ᵀ`, but `τ_MEV` does not appear in `π^σ = ΔQ_v*(σ²−σ_K²)⁺` at all. The transfer matrix has a structurally zero row; this is a single-output tracking problem wearing a MIMO costume.
- **Ordering mismatch.** `u_en = [τ_MEV, φ_M, φ_X]ᵀ` (`SRC:23`) but `∇φ` (`SRC:56`) is listed in the order `(∂/∂φ_M, ∂/∂φ_X, ∂/∂τ_MEV)`. A permuted Jacobian in a state-space display is a real bug once anyone multiplies matrices.

**Warning signs.** Nobody can exhibit a nonzero entry of `∂_{(t+1,t)}`. The `A` matrix is never written out. A control-theory literature review that never gets applied to a specific matrix.

**Prevention.**
1. In the well-posedness phase, **write the four matrices out entrywise** before proving anything about them. If `A = 0`, say so and re-scope: the honest object is a static inversion with an exogenous driver, and the theory-basis phase should curate *static optimization under uncertainty*, not Ogata.
2. Move `φ_X` out of `u_en` (it belongs in the exogenous-driven signal path) or state the assumption that makes it an actuator. Fix the `∇φ` ordering.
3. State the rank deficiency of the output map explicitly — it is a legitimate finding, and it justifies the single-output framing.

**Phase:** State-space-transcription phase (write the matrices); well-posedness phase (verdict); theory-basis phase (re-scope if `A = 0`).

---

### M4. An algebraic loop: `L → ν → φ → π^φ → L`. The 5-factor product is an open-loop gain, not a total derivative

**Status: CONFIRMED as a loop** (`DOC:836` gives `ν = flow/L`; `DOC:612-620` gives `φ` gated by `ν`; `SRC:106` gives `π^φ(φ)`; the chain itself asserts `∂L/∂π^φ ≠ 0`). **The magnitude of the correction is PLAUSIBLE** (depends on unmeasured elasticities).

**What goes wrong.** The chain traverses `∂L/∂π^φ` *and* `∂φ/∂ν`, while `ν` has `L` in its denominator. That is a closed loop. The total derivative is not the open-loop product `G`; it is `G/(1 − 𝓛)` where the loop gain is

```
𝓛 = (∂ν/∂L)(∂L/∂π^φ)(∂π^φ/∂φ)(∂φ/∂ν).
```

Since `∂ν/∂L = −flow/L² < 0` and the other three factors are positive under the natural signs, `𝓛 < 0`, so `1 − 𝓛 > 1` and the open-loop product **systematically overstates** the true gain. That is a concrete, falsifiable prediction the project can check.

The `∂φ/∂ν` factor does exist and is computable: `DOC:612-620`'s gate is `u = α_R·Λ(γ_R(ν − β_R))`, so
`∂φ/∂ν = (Σ_j α_j Λ_j) · α_R γ_R Λ_R(1−Λ_R) > 0` for `γ_R > 0`. Good — but note this is `∂φ_X/∂ν`, the **schedule** fee, whereas the adjacent factor `∂π^φ/∂φ` used the **composed** fee's inverse (B5). The symbol `φ` therefore denotes two different objects in adjacent factors of one product. A chain rule whose links are different functions does not compose.

**Warning signs.** A chain rule that visits a variable twice (here `L` appears in factor 2 and, implicitly, inside factor 4's argument). A gain that is asserted "constant" (`SRC:126`) in a system with feedback. `φ` used without a subscript in a document where `φ_M`, `φ_X`, `φ_total` and `φ(σ;t)` all exist.

**Prevention.**
1. Draw the dependency DAG in the state-space phase and **check it is acyclic**. It is not — record the cycle and compute `𝓛` symbolically.
2. Add a well-posedness obligation: `1 − 𝓛 ≠ 0` (no singular loop). Under the natural signs this is provable; state it as a theorem rather than assuming it.
3. **Disambiguate `φ`** in the channel statement: subscript every occurrence. If factor 3 uses `φ_total` and factor 4 uses `φ_X`, the product is not a chain rule and must be rewritten.

**Phase:** State-space-transcription phase (DAG, `𝓛`); well-posedness phase (`1 − 𝓛 ≠ 0`); channel phase (`φ` disambiguation).

---

### M5. The central mechanism is precisely the term the existing Lean corpus declares absent

**Status: CONFIRMED** (`MevOptimization.lean:21-24`; `MevJointProgram.lean:17-22`; `DOC:889`, `DOC:1047`).

**What goes wrong.** The whole channel is a **supply/demand-response** channel: fee income moves liquidity (`∂L/∂π^φ`), and utilization moves the fee (`∂φ/∂ν`, whose numerator is traded flow). But the existing carriers state flatly:

- `MevOptimization.lean:21-24`: "The `lambda_ARB` objective formalized here **has no demand response to the fee**. Its corner solution is consequently a property of the stated objective, not a market-equilibrium claim. The omitted term is the anchor's section 7.3, equation (27)."
- `MevJointProgram.lean:19-22`: "Neither functional contains demand response to fees, so its corner solutions are properties of these **volume-inelastic** objectives, not market equilibria."
- `DOC:1047` (Caveats [M8]): "NO DEMAND ELASTICITY — the missing term is MMR §7.3 eq. (27); corner solutions are objective properties, NOT equilibrium claims."
- `DOC:889`: FLAIR "has no demand elasticity — the fee–volume trade-off lives in the optimal-fee layer (`FeeSchedule`, arXiv:2508.08152)."

So the new derivation cannot be verified *against* the existing Lean carriers: they assume the channel is zero. Worse, `π^φ = φ_M ΔQ_M + p φ_X ΔQ_X` differentiated holding `ΔQ` fixed (`SRC:108-110`) **is** the volume-inelastic assumption in the small — the true derivative carries a `+ φ ∂ΔQ/∂φ` term whose sign can flip the bracket (the Laffer/optimal-fee term).

**Warning signs.** Reusing a `MevOptimization`/`MevJointProgram` lemma as a step in a proof that requires elasticity. A "gain" whose sign depends on flow responding to fees, cited to a module whose header says flow does not respond to fees.

**Prevention.**
1. Decide, in the theory-basis phase, whether this project **imports the elasticity layer** (`OPT_FEES`, arXiv:2508.08152 — vendored per `DOC:895`) or **assumes inelastic flow**. Record the decision in `PROJ` Key Decisions. There is no third option, and the answer changes the sign of the bracket.
2. If inelastic: state that the resulting `τ*` is a property of the objective, not an equilibrium — the exact disclaimer the Lean headers already carry. Do not let it be read as a market prediction.
3. If elastic: the existing corner/monotonicity carriers are **not** reusable and the project owes new ones. Budget for that.

**Phase:** Theory-basis phase (the decision); channel phase (which carriers are importable).

---

### M6. Event-time indexing makes `Δt` a state-dependent random variable, but `ℙ_{Δ_ARB}` is a steady-state object and `λ_ARB` is monotone in `Δt`

**Status: CONFIRMED as a tension** (`PROJ:8-9` defines `t → t+1 := event swap`; `MevJointProgram.lean:20-22`; `MevOptimization.lean:26-30`; `MevJointProgram.mev_mono_dt` / `DOC:1043`).

**What goes wrong.** The plant is declared in **event time** (`t+1 := event swap`), so the inter-sample interval is non-uniform and endogenous to the trading process. But:
- `ptrade` is explicitly a *steady-state* quantity: "applying it stepwise along a path with varying volatility is the document's quasi-static extension … legitimate only if the parameters move slowly relative to mixing of the mispricing process" (`MevOptimization.lean:26-30`).
- `Δt` is not a nuisance parameter: `MevJointProgram.mev_mono_dt` (T29) proves `λ_ARB` is **isotone** in `Δt`, and `DOC:1043` names cadence "the non-degenerate lever outside `Θ_φ`".
- `mev_mono_dt`'s own docstring (`:422-428`) warns that `Δt` occurs *twice* — inside the weight `a t` and via `T ∝ 1/Δt` per calendar time — "both occurrences must be reconciled."

If events arrive faster when `τ` is low (more profitable arb), then `Δt` is a *function of the control*, and the model has a feedback path the derivation does not contain — a fifth path for B2, and a non-uniform-sampling problem for the well-posedness phase.

**Warning signs.** `Δt` treated as a constant parameter in a document whose time index is event-driven. Any statement about "per-block" quantities in a per-event plant. Sub-second cadence claims (`MevJointProgram.lean:425-427` restricts the diffusion scaling to `≳ 1s`).

**Prevention.** Add an explicit assumption to the state-space phase: either (a) `Δt` is exogenous and constant (Angstrom's one-bundle-per-block cadence, `DOC:901` — defensible, and it makes event time = block time), or (b) `Δt` is endogenous and the plant is a non-uniformly-sampled system. Choose (a) and say so; (b) is a research project of its own. Record the quasi-static validity condition verbatim from `MevOptimization.lean:26-30` in the gap register.

**Phase:** State-space-transcription phase (the assumption); well-posedness phase (non-uniform sampling if (b)).

---

### M7. Notation collisions already present in the derivation and in `PROJECT.md`

**Status: CONFIRMED** (four instances).

**What goes wrong.**

| # | Collision | Evidence |
|---|-----------|----------|
| 1 | `SRC:14, 28` uses `π^{\varphi}` (varphi) for `π^φ − π^LVR`. But `DOC` Definition 25 (`DOC:813-821`) reserves `π^{\varphi}` for the **portfolio value function**, the conic dual of the trading function. Under `DOC` Proposition 9 the source's object is `≈ −π^ARB`. Two different objects, one glyph. | `SRC:14,28` vs `DOC:813-821`, `DOC:919-927` |
| 2 | `PROJ:87` silently renames it to `π^φ̃` — a **newly minted symbol**, with no notation-map paragraph and no user ruling. This is precisely what `PROJ:111-114` forbids. | `PROJ:87` |
| 3 | `π^σ` is used for the **contractual** payoff at `SRC:182-189` but the derivative expansions at `SRC:76, 87, 89, 97, 118, 167` differentiate `Σ_{i_K} L(i_K) π^l(σ(i_K;·))` — which is `π̂^σ`. Six occurrences; systematic, not a typo. `DOC:701` adds a **third** `π^σ` (Rule 4's ledger `Σ L(i_K) 𝕀_{long\|short}`). | `SRC:76-99, 118, 167` vs `SRC:193-202`, `DOC:701` |
| 4 | `L` overloaded (ladder vs aggregate pool) — see B6. | `SRC:196` vs `DOC:836` |

Item 3 is load-bearing: `π^σ` (contractual) has **zero** sensitivity to `φ, π^φ, ν, τ_MEV, φ_M, φ_X`, so the entire expansion at `SRC:76-79` is identically zero if read literally. `π̂^σ` has the sensitivities the derivation wants. The derivation is not decidable as written without a ruling.

**Two more errata in the same block, both CONFIRMED:**
- `SRC:106` defines `π^φ ≡ φ_M ΔQ_M + p_{(η,Δᵢ)} φ_X ΔQ_M` — the second leg should be `ΔQ_X`, as `SRC:108` itself then writes. Typo, but it is in the *definition*.
- `SRC:118` states `(∂π^σ/∂φ_M, ∂π^σ/∂φ_X) = (p ΔQ_X, ΔQ_M)` — **reversed** relative to `SRC:106/108`, which give `(ΔQ_M, p ΔQ_X)`. And the glyph should be `π^φ`, not `π^σ`.

**Warning signs.** A derivative expansion in which every term of a contractual payoff is nonzero. A glyph appearing in a project artifact that does not appear in `DOC`'s notation-map comments (`<!-- notation-map -->`).

**Prevention.**
1. **Phase 1 deliverable: a notation-map paragraph** listing every symbol `SRC` uses, its `DOC` definition (by Definition/Rule number), and every collision, with the user's ruling on each. Nothing goes to Aristotle before this exists — `PROJ:114` says the binding rule "applies to Aristotle prompts too."
2. Fix `PROJ:87`'s minted `π^φ̃` in the same pass: either get it ruled, or revert to the source glyph with the collision flagged.
3. Add a mechanical check: grep every drafted artifact for `π^σ` and confirm each occurrence is branch-tagged as contractual or replicated.

**Phase:** Theory-basis / state-space phase (the notation map is a gate on everything else).

---

### M8. Dimensional inhomogeneity in the boxed law

**Status: PLAUSIBLE — needs one ruling to become CONFIRMED.**

**What goes wrong.** `DOC:693` and `DOC:698` (Convention 3, DECIDED 2026-07-30) state `ΔQ_v*` "carries the dimension of the REPLICATION CARRIER — liquidity `L`", raw liquidity units. Tracking the box:

- `π^l` has units payoff-per-liquidity (since `π̂^σ = Σ L π^l`);
- `∂L/∂π^φ` has units liquidity-per-money;
- so `Σ π^l ∂L/∂π^φ` is payoff-per-money = dimensionless if payoff is money;
- `[ΔQ_M/(1−φ_X) + p ΔQ_X/(1−φ_M)]` has units of money;
- `(∂φ/∂ν)(∂ν/∂τ)` is dimensionless.

Product: **money**. Divided by `ΔQ_v*` in **liquidity** units, giving money-per-liquidity — subtracted from the pure number `1`. Inhomogeneous unless `π^l` is normalized so the quotient is dimensionless, or unless `ΔQ_v*` is read in money units (contradicting Convention 3).

The same check on the replication relation itself: `π^σ = ΔQ_v*(σ²−σ_K²)⁺` is liquidity × variance, while `π̂^σ = Σ L π^l` is liquidity × payoff-per-liquidity. These match only if `π^l` carries variance units — which is a real claim about `π^l` that `SRC` never states. Note the prior record already flags a "volStrike units contradiction" as a blocking trap on the adjacent lens spec.

**Warning signs.** A design spec with no unit ledger. Any equation adding a `1` to a ratio of two differently-dimensioned quantities.

**Prevention.** Produce a **unit ledger table** (symbol / units / source ruling) as a deliverable of the state-space phase, covering at minimum `ΔQ_v*, L(i_K), π^l, π^σ, π̂^σ, π^φ, π^LVR, π^linear, ν, σ², φ, τ_MEV, p_{(η,Δᵢ)}`. Check the box against it before drafting the Lean statement. Route any contradiction to the user as a ruling request, not a silent repair.

**Phase:** State-space-transcription phase.

---

### M9. `p_{(η,Δᵢ)}` may be the banned identification

**Status: PLAUSIBLE.**

**What goes wrong.** `SRC:106/110/118/225` uses the grid map `p_{(η,Δᵢ)}` to convert the asset leg to money. `DOC` Proposition 10 (`DOC:803-811`) is explicit: "The grid map and the marginal price are DISTINCT objects — the identification `p_{(η,Δᵢ)} ≡ p_φ` is **NOT admissible**", and gives the exact relation
`p_φ(i_K) = 1/[p_{(η,Δᵢ)}(i_K)·p_{(η,Δᵢ)}(i_K+Δᵢ)]` — the inverse *product* of adjacent grid values, i.e. off by a squaring and an orientation. If the fee-revenue conversion requires a marginal price, `SRC` has used the banned object; if it requires the grid map, it is correct and should say why.

Note `DOC:811` marks Proposition 10 itself as "**unproved in-tree**", so this cannot be settled by citing a Lean declaration today.

**Warning signs.** `p_{(η,Δᵢ)}` appearing in any expression where a marginal price (a derivative of the trading function) is what is economically meant.

**Prevention.** In the state-space phase, state which price object converts each leg and cite the Definition. If the marginal price is required, either land Proposition 10 (it is queued as a "cheap Aristotle rider", `DOC:811`) or carry the discrepancy as a named gap in the register.

**Phase:** State-space-transcription phase; gap register in the consolidation phase.

---

### M10. Aristotle operational and fabrication risks specific to this workflow

**Status: CONFIRMED risks** (documented failures in `IN-FLIGHT.md` and `DOC`).

**What goes wrong.**

- **Silent hypothesis strengthening.** `DOC:982` records two `[CORRECTED:]` events where Aristotle *added* hypotheses to make statements true (`mevMulti_saturation_limit` gained `0 ≤ φ̄_max + u_max·α_max`; `mevMulti_exists_min_compact` gained `fees ≥ 0`). A returned proof of a *weakened* statement reads as success unless you diff the statement.
- **Transcription refutation.** `DOC:1323`: the first-transcribed radicand for `d̃_J*` "is NOT a root of `M_J`" — refuted by exact witness `dJstar_not_root_witness` (`JitLiquidity.lean:206`). Hand-transcription from a paper into a formula is where this programme has actually been wrong.
- **Partial-return contamination.** `IN-FLIGHT.md:34-36`: "**Never integrate this partial** (2 sorries)."
- **CLI cost.** `IN-FLIGHT.md:18-21`: `aristotle show|tasks` returns HTTP 500 on short project ids — "this has cost time twice." Always full UUIDs; `list` before concluding an outage.
- **Queue discipline.** `PROJ:116-119`: never parallel `continue` on the same project; on `OUT_OF_BUDGET` run a single `continue` on the same project, not a fresh scoped submit.
- **Tautology inflation.** `MevOptimization.arb_add_fee_eq_lvr` (`:230-232`) is `lvr*p + lvr*(1−p) = lvr`, proved `by ring`. Its docstring (`:226-229`) and `DOC:929` both say it is a **bridge identity** and "is never to be cited as MMR Thm 3 formalized." A one-line `ring` proof in a returned bundle proves nothing about the economics.

**Warning signs.** A returned theorem whose statement differs by one hypothesis from the one submitted. A proof body that is `by ring`, `by simp`, `by norm_num`, or `rfl` for a claim described as substantive. A declaration count that matches the submission while the *content* does not. Any integration performed without a byte-diff of the definitions.

**Prevention (this project's gate, non-negotiable).** Before integrating any Aristotle return:
1. **Statement diff** — byte-compare each returned statement against the submitted `sorry`'d statement. Any added hypothesis is a *narrowing* and must be reported as such in the verdict, with the narrowing's economic meaning stated.
2. **Axiom check** — `#print axioms` on every declaration; only `propext`, `Classical.choice`, `Quot.sound`.
3. **Sorry count = 0** in anything integrated; partials are never integrated.
4. **Proof-body triage** — flag every proof that is a single tactic; classify each as tautology-grade or substantive *before* it enters the spec.
5. **Dependency byte-identity** — imported definitions unchanged (the standard used at `IN-FLIGHT.md:26`: "endpoints byte-identical vs the embed base, deps import-rewrite-only, full `lake build`").
6. **Provenance in the artifact** — project UUID, task id, and return date recorded next to each cited declaration.

**Phase:** Every proving phase; the gate itself is a deliverable of the theory-basis phase.

---

# Minor Pitfalls (MINOR)

### N1. `∂/∂σ` vs `∂/∂σ²` bookkeeping
**Status: CONFIRMED as a live risk.** `ptrade` takes `σ` (`MevOptimization.lean:36`), while `π^σ`, `u_ex` and `SRC:167` are all in `σ²`. Every conversion carries a factor `1/(2σ)`. **Prevention:** pick `σ²` as the canonical variable for this project (it is what `u_ex` and `Θ_σ` use) and convert `ptrade`'s argument once, explicitly, in the state-space phase. **Phase:** state-space.

### N2. `∂π̂^σ/∂L` written as a scalar
**Status: CONFIRMED.** `L` is indexed by `i_K`; `SRC:154` writes `∂π̂^σ/∂L` as a scalar factor while the box (`SRC:216-219`) correctly carries `Σ_{i_K}`. Harmless as long as nobody reuses the scalar display. **Prevention:** state the channel with the sum from the start. **Phase:** channel.

### N3. `≈` with no order
**Status: CONFIRMED.** `SRC:56` and `SRC:76-79` use `≈` and `+ ⋯` with no statement of what is being neglected or to what order. The corpus's `≈` elsewhere is precisely defined (MMR's fast-block small-fee leading order, `MevOptimization.lean:16-19`). **Prevention:** every `≈` in this project's artifacts names its expansion parameter and order, or becomes `=`. **Phase:** state-space.

### N4. The interval at `SRC:167` is not well-formed
**Status: CONFIRMED.** `∂π^σ/∂σ² ∈ (ΔQ_υ, ∂π^σ/∂σ²(λ_MEV))` has the object under study as an endpoint of its own containing interval, with no ordering guarantee. **Prevention:** restate as two inequalities with named hypotheses, or delete. **Phase:** state-space.

### N5. `SRC:2`'s import link is a branch-relative path
`import [MEV](feat/plank::notes/VOLATILITY_INSTRUMENTS.md)` — a branch-qualified reference to a file that is actively edited by peer `ul2inqpl`. Cited content can move (`DOC:895` already records "byte-pins on them are invalidated by the move — disclosed"). **Prevention:** cite by Definition/Rule/Theorem number, never by line number, and record the commit sha of `DOC` at the time of citation. **Phase:** all phases; enforce in the consolidation phase.

---

# Prior-refutation register — verified against the Lean source

Every row below was read in the file named. **The general lesson column is the operative part**: it names the *class* of reasoning error, so the same mistake in a new guise is detectable.

| # | Claim refuted | Declaration (VERIFIED) | File:line | General lesson (the error class) | New-guise risk in THIS project |
|---|---|---|---|---|---|
| R1 | T24: under a FLAIR fee budget, the flat fee minimizes `λ_ARB` for arbitrary `σ`-paths | `mev_ge_flat_under_flair_budget_false` | `MevJointProgram.lean:155-175` | **Convexity does not aggregate across summands that are different functions.** The witness `σ = (1,10)`, fees `(2,0)`, `T=Δt=B=2` gives `31/22 > 4/3`: each `t` has its own `ptrade(·, σ_t, Δt)`, so Jensen has no single convex function to apply. Constant `σ` survives (`mev_ge_flat_under_flair_budget_const_sigma`, `:182`; strict `:259`). | **HIGH.** `π̂^σ = Σ_{i_K} L(i_K) π^l(σ(i_K;Θ_σ))` sums a *different* `π^l` at each strike tick. Any claim that the sum is extremized at a uniform/flat ladder `L`, or any Jensen/convexity argument across `i_K`, repeats R1 exactly. Detection: does every summand use the same function of the same argument? Here it does not. |
| R2 | Capponi's interior canonical family embeds in CES | `canon_Fcap_not_CES`; `kappa_not_reparam_of_rho` | `CapponiEmbed.lean:1156-1180`, `:1224-1234` | **Endpoint agreement does not imply family embedding.** Both endpoints DO embed (`Fcap_zero_is_rho_one` `:1184`; `Fcap_one_is_rho_zero_limit` `:1205`), yet the interior witness `κ = 1/2` fails — detected only at the **fourth derivative** (`:1132-1139`). Corollary: symbol substitution ≠ object identification (`DOC:1089`, `DOC:1263`). | **HIGH.** Validating the boxed `τ*` at `τ=0` and `τ=1`, or at `σ² = σ_K²` and `σ² → ∞`, proves nothing about the interior. Also: `DOC:1265` records a **STANDING BAN** on identifying `ℙ_{Δ_ARB}^{CJ}` with `λ_ARB` — do not import any Capponi–Jia comparative static into the `τ` derivation by name-matching. |
| R3 | T15/T17 as originally drafted | `mevMulti_saturation_limit` (guard `hfee : 0 ≤ φ̄_max + u_max·α_max`); `mevMulti_exists_min_compact` (nonneg-fee region required) | `MevOptimization.lean:686-695`, `:795-799`; corrections recorded at `DOC:982` | **A rational function's domain IS the theorem.** `ptrade = σ/(σ + φ√(2/Δt))` (`:36-37`) is Möbius with a pole at negative fee. Docstring `:797-798`: "**compactness alone does not avoid the pole**." | **HIGH.** The box has `1/ΔQ_v*`, `1/(1−φ_X)`, `1/(1−φ_M)`, and its output `τ*` can leave `[0,1]` (B3), driving the composed fee negative. Detection rule: grep every statement for `/`; each denominator must map to a named hypothesis. |
| R4 | An unconstrained trade-off exists in `Θ_φ`; `(β,γ)` are essential | `joint_corner_degeneracy` (T20), `joint_beta_degeneracy` (T21), `joint_scalarization_degeneracy` (T22) | `MevJointProgram.lean:39-94` | **A lever that moves both objectives the same way is not an actuator that resolves a trade-off**, and corner solutions of *volume-inelastic* objectives are properties of the objective, not the market (`:76-79`). The degeneracy-breaker must come from **outside** `Θ_φ` (`DOC:984`). Note the precise scope: `β` DOES move `λ_ARB` (`mevMulti_mono_beta`) — see M2. | **HIGH.** `τ` enters `Θ_φ`'s coordinate via Rule 12's monoid and moves the composed fee monotonically up ⟹ FLAIR ↑, `λ_ARB` ↓ — the same direction as the level corner. So `τ` is a level lever, not a degeneracy-breaker. If `τ*` comes out interior, name the term that creates the interiority; if none, `τ*` is a corner (`0` or `1`), which is exactly what B3's two readings both predict. |
| R5 | `υ` (vega) is identifiable from this market | **No Lean declaration found.** Honest report: `Upsilon.lean` contains `ATMOTMNullHypothesis` (`:83`) as an explicitly *unproved* `Prop` — its docstring says "Lean only fixes the statement", tested by the econometric track — plus the proved witness `exp_family_witnesses_ATMOTM` (`:95`). The **non-identification verdict itself lives in the planning/econometric record, not in a machine artifact.** | `Upsilon.lean:61-100` | **A parameter appearing in a model need not be identified by the available data.** A terminal "cannot identify" is a result with standing; reopening it without new data is wasted effort. Also visible in `Upsilon.lean`'s own docstring: a naive `exp(−c\|i−i_K\|)` envelope is "**FALSE on the entire left branch for every c > 0 — a parameter-independent obstruction**" because a forward difference is right-shifted by one index. Discretization artifacts masquerade as economics. | **HIGH.** `Ḡ_(ν,λ_MEV)` and `∂L/∂π^φ` are exactly the kind of elasticities a null result already covers. Any plan step that says "estimate/measure `Ḡ` from data" is R5 in a new guise. **Prevention:** treat `Ḡ` as a design constant with a *sign assumption only*, and make the verdict robust to its magnitude — or make the verdict sign-only. |
| R6 | The `Θ_φ` branch of the `tol_slip` conjecture | `sandwich_fee_hurdle_false` (30 bp witness); corrected form `sandwich_fee_hurdle_corrected`; exact frontier `pnlFee_pos_iff` | `SandwichTol.lean` (per `DOC:1026-1031`, `IN-FLIGHT.md:25`) | **"Parameter X controls channel Y" is a claim about which variable actually appears in the frontier condition.** The fee turned out to pin an admissible *trade size*, not the tolerance — `tol_slip` does not enter the frontier at all. The `Θ_p` branch was PROVED as stated (`sandwich_grid_cap`), so the verdict was a **split**, not a binary. | **MEDIUM.** "`τ_MEV` controls the replication error" is structurally the same claim. B6 suggests the true controlling variable may be collateral `Q_M` via Rule 10's funded cap, with `τ` entering only through it. Expect and plan for a **split verdict**. |
| R7 | The transcribed `d̃_J*` radicand | `dJstar_not_root_witness` (`MJfun 0 1 2 (dJstar 0 1 2) ≠ 0`); corrected `dJroot`, `dJroot_root`, `dJroot_unique_positive_root`, `dJstar_pole` | `JitLiquidity.lean:206`, `:393`, `:499` | **Hand-transcription of a closed form from a paper is where this programme has actually been wrong** — a missing `q_R` factor. Cheapest detector: substitute the claimed root back into the defining equation with small integers. | **HIGH.** The boxed `τ*` is exactly a hand-transcribed closed form with no back-substitution check. **Do this first**: substitute the box back into `∂π̂^σ/∂τ = ΔQ_v*` (or into the level relation) with small integers and confirm it satisfies it. |
| R8 | `arb_add_fee_eq_lvr` as "MMR Theorem 3 formalized" | `arb_add_fee_eq_lvr`, proof body `by ring` | `MevOptimization.lean:226-232`; ban restated at `DOC:929` | **A ring tautology in the right notation looks like a theorem.** The docstring: "This is a **bridge identity** … and it is NOT a formalization of those theorems, which are asymptotic approximations and are not formalized here." | **HIGH.** `TauMevAlgebra.tau_split_budget` (`:111`, `by simp; ring`) and `tau_split_intensity_neutral` (`:121`, one `rw`) are the same genre — both docstrings say so ("definitional accounting, not a deep result"). If the `τ*` verdict rests on a `by ring` step, the verdict is hollow. **Detection:** proof-body triage (M10.4). |

---

# Scope pitfalls

### S1. Drift into implementation
**Severity: MAJOR. Status: CONFIRMED as a live risk** (`PROJ:60-62`, `PROJ:122`; `CLAUDE.md` ownership map assigns `src/` and Plank to peer `ul2inqpl`).
**Warning signs:** a `.plk` or `.sol` file appearing under this worktree; the EVM-feasibility phase producing code rather than a *required-primitives + cost-envelope* table; any commit touching `src/`, `script/`, `foundry.toml`, `remappings.txt`, or `test/`.
**Prevention:** the EVM-feasibility phase's deliverable is defined up front as a **table** — required fixed-point primitives, saturate-never-revert behaviour, bounds, cost envelope — plus a hand-off note. No executable artifact. Check `claude-peers list_peers` before touching any shared path.
**Phase:** EVM-feasibility phase.

### S2. Drift into the closed-loop feedback law
**Severity: MAJOR. Status: CONFIRMED risk** (`PROJ:63-64` excludes it, yet `SRC:30-36` opens with "For feedback control we have: `e^σ = |π^σ − π̂^σ|`").
The source itself introduces the error signal on line 34, before the set-point derivation. The temptation to design a regulator around it is built into the primary document.
**Warning signs:** any appearance of gain tuning, stability margins, pole placement, integral action, or anti-windup; the words "controller performance"; any use of `e^σ` other than as the *definition of the target being solved to zero*.
**Prevention:** state in the state-space phase that `e^σ` enters **only** as the equality constraint `e^σ = 0`; a regulator over `e^σ` is out of scope and belongs to a later milestone. Note that B7 makes the non-smoothness of `|·|` a *reason* to stay out — designing a regulator on a non-smooth error is its own research problem.
**Phase:** State-space phase (declare `e^σ`'s status); consolidation phase (record the deferral in the gap register).

### S3. Drift into v2-controller's spatial axis
**Severity: MINOR. Status: CONFIRMED boundary.** `v2-controller/CONTROLLERS.md:9-14` is explicit: "**Static, not temporal.** … there is no time index, no feedback loop, no adaptive fee `φ(·;t)`. The state space is the tick lattice." This project owns the **event-time** axis; v2 owns the **tick-lattice** axis.
**Warning signs:** re-deriving tick-lattice inversions; producing a "controller catalog"; any statement indexed by `i` with no `t`.
**Prevention:** cite v2 artifacts as read-only inputs (`PROJ:86`) — never re-derive `LEAN-MAP.md`, `GAMS-MAP.md`, `EVM-CONTROL-PRIMITIVES-MAP.md`. Add a one-line axis declaration to the top of every artifact: *event-time axis; the spatial/tick axis is v2-controller's.*
**Phase:** Theory-basis phase (declare the axis); consolidation phase (cite, don't re-derive).

### S4. Writing outside the isolated planning root
**Severity: MAJOR. Status: CONFIRMED constraint** (`PROJ:68-71`, `PROJ:106`, `PROJ:76-79`).
The repo-root `.planning/` is shared v1 planning in flight across peers and is **read-only** here. GSD anchors `.planning/` at the directory it runs from; all commands need `--cwd control`.
**Warning signs:** a GSD command run from the worktree root; any diff touching `/evm-controller/.planning/` (as opposed to `/evm-controller/control/.planning/`); edits under `spec/01_STATE_DELTA_ELASTICITY_CONTROLLER/` (explicitly removed from scope, `PROJ:64`).
**Prevention:** put `--cwd control` in the phase-execution instructions themselves, not in a human's memory. Add a pre-commit check on the path prefix.
**Phase:** Every phase.

### S5. Editing peer-owned source documents
**Severity: MAJOR. Status: CONFIRMED.** `DOC` (`plank/notes/VOLATILITY_INSTRUMENTS.md`) is plank-owned; `IN-FLIGHT.md:28-32` records a precedent — a stale-notation defect in a plank-owned file was "**flagged, not edited**." The Lean tree is owned by the Lean4+math session (`PROJ:108-110`).
**Warning signs:** any diff to `plank/notes/`, `lean4-spec/lean/`, or `model/spec/*.md` from this worktree.
**Prevention:** findings against `DOC` or the Lean tree go into **this project's** gap register with a `send_message` to the owning peer. This file's B6/M2/M7 findings are exactly such items — route them, do not fix them here.
**Phase:** Consolidation phase (the gap register is the delivery vehicle).

---

# Technical debt patterns

| Shortcut | Immediate benefit | Long-term cost | When acceptable |
|----------|-------------------|----------------|-----------------|
| Prove the boxed `τ*` "as written" without settling which replication relation it solves (B1) | Aristotle can start today | Proves the wrong theorem; a green Lean build that certifies nothing. The programme's own standard (`PROJ:19-23`) makes this the defining failure mode | **Never** |
| Assume `∂ν/∂τ_MEV > 0` because `Ḡ > 0` (B3) | The chain has a sign | Inverts the boxed law; the resulting spec recommends a tax in the wrong direction | **Never** — the composition is a one-lemma proof |
| Keep `∂L/∂π^φ` abstract rather than resolving the `L` collision (B6) | Avoids a hard modelling question | The channel may be identically zero; the whole spec is vacuous | **Never** |
| Treat `Ḡ_(ν,λ_MEV)` as a constant of unknown magnitude, sign assumed | Unblocks the algebra without econometrics | Verdict is conditional on an unmeasured elasticity | **Acceptable** — R5 says the magnitude is likely unidentifiable. Make the verdict sign-only and say so |
| Ignore the algebraic loop and use the open-loop gain (M4) | Simpler expression | Overstates the gain systematically; a control law calibrated on it is mis-tuned | **Acceptable only** if the loop gain `𝓛` is computed and shown small, with the bound recorded |
| Defer the two-step review (Reality Checker + specialist) | Faster to execution | v2-controller did this and still owes SPEC-04 (`STATIC-CONTROL-KERNEL-SPEC.md:8-11`); `PROJ:135` names this as a decision *not* to repeat | **Never** |
| Skip the notation-map paragraph (M7) | Starts proving sooner | Aristotle prompts inherit the collisions; returned theorems are about the wrong objects | **Never** — `PROJ:114` binds the rule to Aristotle prompts |
| Cite `DOC` by line number | Precise today | `DOC` is peer-edited and already records invalidated byte-pins (`DOC:895`) | Only alongside a Definition/Rule/Theorem number and a commit sha |

---

# "Looks done but isn't" checklist

- [ ] **The channel is "proven."** Verify the proof covers the *total* derivative, not the five-factor product; verify the direct monoid path P1 (`∂φ/∂τ = (1−φ_M)(1−φ_X)`) is explicitly handled, not silently absent.
- [ ] **The sign is "proven."** Verify the statement is about `∂ν/∂τ_MEV`, not `∂ν/∂λ_MEV`. Grep the Lean statement for `tau` — if only `lam` appears, the wrong thing was proved.
- [ ] **The closed form is "proven."** Verify the RHS is `τ`-free (B4), that `(σ²−σ_K²)⁺` is accounted for (B1), and that branch hypotheses on `σ² ≷ σ_K²` are present (B7).
- [ ] **Well-posedness is "proven."** Verify someone wrote out `∂_{(t+1,t)}` entrywise and that it is not the zero matrix (M3).
- [ ] **The proofs are "axiom-clean."** Verify `#print axioms` on *every* declaration, and separately triage proof bodies: a `by ring` / `by simp` / `rfl` proof of a claim described as substantive is R8 (`arb_add_fee_eq_lvr`).
- [ ] **The Aristotle return "matches the submission."** Verify by byte-diff of statements, not by declaration count. Added hypotheses = narrowed theorem = must be reported (`DOC:982` has two precedents).
- [ ] **The prior results are "cited."** Verify each citation carries a real declaration name and file — M2 is a live instance of a cited theorem that does not exist.
- [ ] **The EVM analysis is "done."** Verify it analyses the *fixed-point* form (B4), the kinked/piecewise gain (B6/B7), and the pole guards (M1) — not the boxed one-pass expression.
- [ ] **The spec is "consistent."** Verify the unit ledger (M8) exists and the boxed law passes it.
- [ ] **The verdict is "delivered."** Verify it is PROVEN or REFUTED with a counterexample — not "conditionally valid under assumptions A–F", which is an unverified restatement wearing a hedge.

---

# Pitfall-to-phase mapping

Phases are named after `PROJ`'s Active requirements; the roadmap will number them.

| # | Pitfall | Severity | Prevention phase | Verification that prevention worked |
|---|---------|----------|------------------|-------------------------------------|
| B1 | Box solves a different equation | BLOCKER | Closed form (first) | The missing intermediate line exists and is user-ruled; the chosen relation is named in the Lean statement |
| B2 | "No other path" is false | BLOCKER | Channel (DAG owed by state-space) | Dependency DAG drawn; P1–P4 each either proved zero or included; negation submitted alongside |
| B3 | `λ_MEV` vs `τ_MEV` sign | BLOCKER | Sign → Closed form | `∂λ_MEV/∂τ_MEV < 0` proved in Lean; numerical harness shows `τ* ∈ [0,1]` or reports the violation; `\|_{λ_MEV}` contradiction ruled |
| B4 | Implicit, not closed, form | BLOCKER | Closed form; EVM feasibility | Existence + uniqueness + monotonicity of `F` stated as obligations; EVM analysis costs an iteration |
| B5 | Two incompatible sections in `∂π^φ/∂φ` | BLOCKER | State-space (declare section) → Channel | The section is written down; or the step is deleted in favour of `dπ^φ` in `(φ_M, φ_X)` |
| B6 | `∂L/∂π^φ = 0` under Rule 9 | BLOCKER | State-space (symbol split) → Channel | `L(i_K)` vs aggregate `L` are distinct ruled symbols; the channel's status (zero / constrained-branch-only / elastic) is stated |
| B7 | Three kinks + OTM degeneracy | BLOCKER | Closed form (branch split) | Every statement carries a `σ² ≷ σ_K²` hypothesis; OTM degeneracy is a theorem, not an omission |
| M1 | Poles incl. the negative-fee pole | MAJOR | Closed form; EVM feasibility | Every `/` in every statement maps to a named hypothesis; saturation behaviour specified |
| M2 | Misquoted `(β,γ)` theorem | MAJOR | Theory basis; Closed form | `SRC:70` and `PROJ:65-66` corrected with declaration names; interiority argument produced or corner conceded |
| M3 | No dynamic part | MAJOR | State-space; Well-posedness | Four matrices written entrywise; `φ_X` relocated or justified; `∇φ` ordering fixed |
| M4 | Algebraic loop | MAJOR | State-space; Well-posedness; Channel | `𝓛` computed; `1 − 𝓛 ≠ 0` proved; every `φ` subscripted |
| M5 | Elasticity assumed and denied | MAJOR | Theory basis; Channel | Import-or-assume decision recorded in `PROJ` Key Decisions; carrier reusability audited |
| M6 | Event time vs steady-state `Δt` | MAJOR | State-space; Well-posedness | `Δt` assumption stated; quasi-static validity condition in the gap register |
| M7 | Notation collisions (`π^φ`, `π^φ̃`, `π^σ`, `L`) + `SRC:106/118` errata | MAJOR | Theory basis / state-space (notation map gates everything) | Notation-map paragraph exists and is user-ruled; `PROJ:87`'s minted `π^φ̃` resolved; errata routed to the source owner |
| M8 | Dimensional inhomogeneity | MAJOR | State-space | Unit ledger table exists; the box is checked against it |
| M9 | `p_{(η,Δᵢ)}` vs marginal price | MAJOR | State-space; Consolidation | Price object named per leg with its Definition; Prop 10 landed or carried as a gap |
| M10 | Aristotle ops + fabrication | MAJOR | Every proving phase (gate defined in theory basis) | 6-point integration gate applied and its output recorded per return |
| N1–N5 | Bookkeeping, `≈`, ill-formed interval, fragile links | MINOR | State-space; Consolidation | Canonical variable chosen; every `≈` has an order; citations by Definition number + sha |
| S1 | Implementation drift | MAJOR | EVM feasibility | Deliverable is a table + hand-off note; no executable artifact; no diff outside `control/` |
| S2 | Closed-loop drift | MAJOR | State-space; Consolidation | `e^σ` declared as a constraint; regulator deferral in the gap register |
| S3 | Spatial-axis drift | MINOR | Theory basis; Consolidation | Axis declaration on every artifact; v2 artifacts cited, never re-derived |
| S4 | Writing outside `control/.planning/` | MAJOR | Every phase | `--cwd control` embedded in execution instructions; path-prefix check |
| S5 | Editing peer-owned documents | MAJOR | Consolidation | Findings routed via gap register + `send_message`; zero diffs to `plank/`, `lean4-spec/lean/`, `src/`, `test/` |

---

# Recovery strategies

| Pitfall | Recovery cost | Recovery steps |
|---------|---------------|----------------|
| B1 discovered after Aristotle submission | MEDIUM | Do **not** submit a competing project. Let the run finish, record the return as evidence about the wrong statement, then re-submit the corrected statement as a new project. `PROJ:116-119`: parallel `continue` on the same project is banned; parallel *submit* to a new project is permitted. |
| B3 sign flip discovered late | LOW | The sign change propagates as a single factor; the verdict flips from "interior set-point" to "corner / no admissible solution." Re-run the numerical harness. This is a REFUTATION and therefore a *successful* outcome (`PROJ:19-23`). |
| B6 resolves to "channel is zero" | LOW–MEDIUM | The deliverable becomes a refutation plus a redirected design question ("collateral `Q_M`, not `τ_MEV`, is the actuator on the constrained branch"). That is a stronger spec than a patched one. Route the Rule 9 conflict to the plank owner. |
| Aristotle returns a narrowed theorem | LOW | Report the narrowing explicitly in the verdict (precedent: `DOC:982`'s two `[CORRECTED:]` entries). Do not present the narrowed statement as the original. |
| A `by ring` proof is discovered inside a load-bearing step | LOW | Reclassify it as a bridge identity (R8), name what it does *not* prove, and mark the substantive claim as open in the gap register. |
| Notation collision discovered after Lean statements are drafted | MEDIUM | Statements must be re-drafted, not patched — a theorem about the wrong `L` or the wrong `π^σ` is not repairable by renaming. This is why M7 gates the proving phases. |

---

## Sources

All verified by direct read on 2026-08-08.

**Primary derivation under scrutiny**
- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/notes/VOLATILITY_INTRUMENTS_MEV.md` (235 lines, read in full)
- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/control/.planning/PROJECT.md`

**Binding notation and prior statements**
- `/home/jmsbpp/cfmms-playground/cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` — Definition 18 (`:612-620`), Theorem 1 (`:622-640`), Rule 9 / Convention 3 / Rule 10 (`:696-734`), `CONTROL_OPERATORS` incl. Convention 4 and Definitions 24–31 (`:760-857`), `MEV` §M0–M10 (`:893-1074`), `BEHAVIOR_WELFARE_UTILIZATION` (`:1076-1092`), TODO OPEN register E8 (`:1259-1275`), JIT (`:1279-1359`)

**Lean declarations (read, not summarized)**
- `lean/vol_markets/MevOptimization.lean` — `ptrade:36`, `ptrade_mem_Ioc:74`, `ptrade_strictAntiOn:100`, `ptrade_strictConvexOn:150`, `arb_add_fee_eq_lvr:230`, `mevMulti_anti_phibar:320`, `mevMulti_saturation_limit:686`, `mevMulti_strict_above_saturation:749`, `mevMulti_exists_min_compact:799`
- `lean/vol_markets/MevJointProgram.lean` — module header `:11-34`, `joint_corner_degeneracy:39`, `joint_beta_degeneracy:60`, `joint_scalarization_degeneracy:80`, `mev_ge_flat_under_flair_budget_false:155`, `mev_ge_flat_under_flair_budget_const_sigma:182`, `mev_gt_..._const_sigma:259`, `mevNet:341`, `taxFraction:406`, `mev_mono_dt:429`, `mevTotal:459`
- `lean/vol_markets/CapponiEmbed.lean` — `capponi_half_not_CES_at_forced_rho:1101`, `capponi_half_not_equal_weight_CES:1143`, `canon_Fcap_not_CES:1156`, `Fcap_zero_is_rho_one:1184`, `Fcap_one_is_rho_zero_limit:1205`, `kappa_not_reparam_of_rho:1224`
- `lean/vol_markets/TauMevAlgebra.lean` — full file (195 lines): `tau_monoid_mem:38`, `tau_monoid_ge:46`, `tau_monoid_gt:53`, `tau_intensity_effect:62`, `tau_intensity_effect_strict:77`, `tau_no_targeting:91`, `tau_hazard_exact:99`, `tau_split_budget:111`, `tau_split_intensity_neutral:121`, `tau_scaling_not_monoid_hom:160`, `tau_order_matters:170`, `tau_split_breaks_hazard:179`
- `lean/vol_markets/JitLiquidity.lean` — `dJstar_not_root_witness:206`, `dJstar_pole:393`, `MJfun_no_positive_root_below_pole:499`, `toxicity_ratio_strictMono:1106`, `incidence_preserves_ARB:1116`, `incidence_mevTotal_invariant:1121`, `incidence_FLAIR_falls:1124`
- `lean/vol_markets/Upsilon.lean` — module docstring `:13-36`, `upsilonTickSlope:64`, `ATMOTMNullHypothesis:83`, `exp_family_witnesses_ATMOTM:95`
- `lean/vol_markets/VolInstrument.lean` — `multiFee:199`, `multiFee_bounds:209`, `multiFee_monotone:229`, `probOr:257`

**Process record**
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/.planning/IN-FLIGHT.md` (84 lines, read in full)
- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/.planning/research/v2-controller/STATIC-CONTROL-KERNEL-SPEC.md`, `CONTROLLERS.md` (scope boundary only)
- `/home/jmsbpp/cfmms-playground/cfmm-wt/evm-controller/CLAUDE.md` (peer ownership map)

**Explicit absence of evidence**
- No Lean declaration was found asserting the `υ` non-identification verdict (R5). `Upsilon.lean` pins the ATM/OTM statement as an unproved `Prop` and proves only a witness lemma. The non-identification result stands on the planning/econometric record, not on a machine artifact — treat it as a standing decision, not a theorem.
- No Lean declaration was found stating "`(β_j, γ_j)` do not control `λ_MEV`" (M2). The nearest true statements are the three T20–T22 degeneracy theorems, which say something materially weaker, and `mevMulti_mono_beta`, which says the opposite about `β`.
- `DOC` Proposition 10 (grid vs marginal price, M9) is marked "**unproved in-tree**" at `DOC:811`; no carrier exists.

---
*Pitfalls research for: verified control-design specification of `τ*_MEV` (event-time axis)*
*Researched: 2026-08-08*
*Not committed — orchestrator commits.*
