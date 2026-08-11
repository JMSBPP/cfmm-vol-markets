# DRAFT — Equating the two laws, the explicit gate derivative, computability of φ* (M41–M43)

**The situation.** The corpus now carries **two** `τ*` objects:

1. **`SRC` Proposition 13 (corrected law)** — an *implicit stationarity condition* from the
   pre-extension model, slot **BARE** (`MevTaxProgram.hasDerivAt_phiTot`), guard conjunct 2
   resting on undischarged sign assumptions:

\[
\tau^{\star}_{\text{MEV}} \; = \; 1 \; + \; \frac{1-\phi_X}{\bigl(\partial\phi_X/\partial\nu\bigr)\bigl(\partial\nu/\partial\tau_{\text{MEV}}\bigr)}
\]

2. **`SRC` Theorem 39 (top-up law)** — an *explicit solution* in the extended
   (transactional-channel) model (`MevTransactionalOptimum.Theorem50_*`):

\[
\tau^{\star}_{\text{MEV}} \; = \; \frac{\phi^{\star} - \phi_M \otimes_{\phi} \phi_X}{1 - \phi_M \otimes_{\phi} \phi_X},
\qquad \phi_M \otimes_{\phi} \phi_X \; \equiv \; 1-(1-\phi_M)(1-\phi_X)
\]

They are FOCs of **different objectives in different models** — Proposition 13's model was
proved rootless (`MevTaxShock.Theorem47_shared_driver_leaves_no_root`), the top-up law's model
is the cure (`Theorem49`). Whether they can be equated, and what equating buys, is **not to be
asserted — it is this bundle's question.** Reasoning-without-checking has been wrong repeatedly
in this project (the literal bracket, Corollary 40b, Theorem 48(d)).

**New author rulings (2026-08-10).**

- **(A-input)** `α_transactional` and `δ_transactional` are **exogenous on-chain inputs** to the
  controller — supplied as calldata/configuration when used, never estimated, never solved for.
  Formal status is unchanged: free typed parameters, exactly as (A-tail)/(A-size) carry them.
  No theorem may fix them to numerals; witnesses may instantiate them, as before.
- The gate derivative `∂φ_X/∂ν` is **protocol-known, not behavioral**: `SRC` Rule 13 sets
  `φ_X = Φ(Θ_φ; σ(i(t)), ν(t))` and `DOC` Definition 18 gives `Φ` in closed form. Only
  `∂ν/∂τ_MEV` is behavioral — and `SRC` Theorem 36 now gives `ν` explicitly on the
  participation region. **Both factors of Proposition 13's slope product are candidates for
  explicit form.** M42 makes this precise.

**A refutation is a successful outcome.** All six prior bundles returned refutations that
redirected this project. Do not narrow a claim to make it provable; exhibit the witness.

---

## Standing bans — carried forward, unchanged

1. Never identify Capponi's `κ` with the `ε_{X/M}` axis (`canon_Fcap_not_CES`; endpoints only).
2. `η` is the **grid-side tilt** (`DOC:184`); `κ_φ` depends on `ε_{X/M}` alone (`DOC` Prop. 7).
3. `π^{\varphi}` (portfolio value) ≠ `π^{\phi}` (fee revenue) ≠ `π^{transactional}` (trader-side).
4. **The `dphidnu` slot is BARE** (`MevTaxProgram.hasDerivAt_phiTot`); `SRC` Convention 9's
   composed `∂φ/∂ν` carries the monoid Jacobian `(1−φ_M)(1−τ_MEV)` explicitly. **M41 lives
   exactly on this distinction — check which slot every equation uses, every time.**
5. Cite prior results by **declaration name AND file**.
6. Isoelastic demand `Q ∝ φ^{−ε}` is banned as a specification; the hazard
   `e^{−α_transactional·φ}` is the only admissible demand object.
7. **No numerals from any implementation** may enter a theorem; witnesses may use numerals.

---

## **M41. [QUESTION — THE EQUATING] Do the two laws meet, and what does equality pin?**

**Theorem 53 (Equating the corrected law and the top-up law) [M41].**

(a) **The algebraic reduction — verify, do not trust the author's hand.** Prove: on
    `τ*_MEV ∈ (0,1)`, with the monoid `1−φ = (1−φ_M)(1−φ_X)(1−τ_MEV)` at the optimum,

\[
\tau^{\star}_{\text{law}} \; = \; \tau^{\star}_{\text{top-up}}
\quad\Longleftrightarrow\quad
\frac{\partial\phi_X}{\partial\nu}\,\frac{\partial\nu}{\partial\tau_{\text{MEV}}}\bigg|_{\tau^{\star}}
\; = \; -\,\frac{1-\phi_X}{1-\tau^{\star}_{\text{MEV}}}
\; = \; -\,\frac{(1-\phi_X)(1-\phi_M)(1-\phi_X)}{1-\phi^{\star}}
\]

   and that this coincides with the vanishing of `MevLVRCancellation`'s bracket
    `(1−φ_M)(1−φ_X) + (∂φ/∂ν)(∂ν/∂τ_MEV)` (composed slot) at `τ*` — i.e. the corrected law
    **is** bracket-zero, restated.

(b) **Status of the equality in the extended model.** In the extended model the total
    derivative is `K·[bracket] + (transactional terms)` — the bracket alone is no longer the
    FOC. Determine which of the following holds, with proof or witness:
    (i) the equality in (a) is an **identity** forced by the extended model at its own
    optimum; (ii) it is a **nontrivial constraint** — a codimension-one condition on
    `(Δp/p, σ, Δt, Θ_φ, α_transactional, δ_transactional)` — characterize the locus and
    exhibit a point ON it and a point OFF it; (iii) it is **generically false** and the two
    laws never meet on the interior — witness.

(c) **The calibration reading — conditional, never asserted.** Under the equality of (a) and
    M42's explicit gate derivative, prove that the behavioral slope is **pinned** at the
    optimum:

\[
\frac{\partial\nu}{\partial\tau_{\text{MEV}}}\bigg|_{\tau^{\star}}
\; = \; -\,\frac{1-\phi_X}{\bigl(1-\tau^{\star}_{\text{MEV}}\bigr)\,\gamma_R\,\bigl(\phi_X-\bar\phi\bigr)\bigl(1-u/\alpha_R\bigr)}
\]

    with `u` the gate value of `DOC` Theorem 1 — every quantity on the right protocol-known or
    on-chain observable. State precisely what dies if (b) resolves to (iii): the pinning is
    then vacuous, and say so.

(d) **The ν-decomposition flag — do not resolve silently.** The gate argument `ν(t)` in
    Rule 13 is the realized per-event utilization; `SRC` Theorem 36's `ν` is the
    **price-shock (arb) response**. In the extended model transactional flow
    (`δ_transactional`, on the complement event) also contributes realized utilization. State
    explicitly which `ν` each claim uses, and whether (a)–(c) require the arb-only reading, a
    block-type-weighted reading, or are insensitive. If a further author ruling is needed,
    say so and stop there — do not rule.

---

## **M42. [CLAIM — THE EXPLICIT GATE DERIVATIVE] Proposition 13's guard becomes a theorem**

From `SRC` Rule 13 and `DOC` Definition 18,

\[
\phi_X \; = \; \bar\phi \; + \; \Bigl(\sum_j \frac{\alpha_j}{1+e^{\gamma_j(\beta_j-\sigma)}}\Bigr)\cdot u,
\qquad
u \; = \; \frac{\alpha_R}{1+e^{\gamma_R(\beta_R-\nu)}}
\]

**Theorem 54 (Explicit gate derivative) [M42].** Prove, on the domain `γ_R > 0`,
`α_j ≥ 0`, `α_R > 0`:

(a) **the closed form** (author's hand — verify):

\[
\frac{\partial\phi_X}{\partial\nu}
\; = \; \Bigl(\sum_j \frac{\alpha_j}{1+e^{\gamma_j(\beta_j-\sigma)}}\Bigr)\,
\gamma_R\,u\,\Bigl(1-\frac{u}{\alpha_R}\Bigr)
\; = \; \gamma_R\,\bigl(\phi_X-\bar\phi\bigr)\Bigl(1-\frac{u}{\alpha_R}\Bigr)
\]

    and the composed form via `SRC` Convention 9:
    `∂φ/∂ν = (1−φ_M)(1−τ_MEV)·γ_R(φ_X−φ̄)(1−u/α_R)`;

(b) **guard discharge, first conjunct**: `0 < ∂φ_X/∂ν` **iff** `φ̄ < φ_X` and `u < α_R` —
    strictly inside `DOC` Theorem 1's fee envelope — so Proposition 13's first guard conjunct
    is a **theorem under Rule 13**, not an assumption; it fails exactly at gate saturation
    (`u ∈ {0, α_R}`, where the derivative vanishes and Proposition 13's law degenerates —
    state what happens to `τ*_law` there);

(c) **guard discharge, second conjunct**: with `SRC` Theorem 36's `ν` on the participation
    region `(1+Δp/p)(1−φ) > 1`, prove `∂ν/∂φ < 0`, and with
    `Theorem29_monoid_path_is_direct` conclude the sign chain delivering
    `∂ν/∂τ_MEV < 0` — **or** exhibit the obstruction (the feedback term
    `ℱ_{φ→ν→φ}` of `SRC` Theorem 37 sits between the bare chain and the total derivative;
    state whether the sign survives the loop);

(d) **the uniform bound** for fixed-point arithmetic:
    `∂φ_X/∂ν ≤ (γ_R α_R / 4)·Σ_j α_j`, attained at `u = α_R/2`, `σ → ∞` — the constant an
    EVM implementation must scale against.

---

## **M43. [CLAIM — COMPUTABILITY OF φ*] The optimum as an on-chain artifact**

`Theorem50` proved `φ*` exists interior under the profitability and (A-tail) conditions; it is
the root of a transcendental FOC — `e^{−α_transactional·φ}` against `σ/(σ+φ√(2/Δt))` — and the
top-up law consumes it. An EVM hook cannot take an `argmax`; it can run a closed form or a
proven iteration.

**Theorem 55 (Computability of φ*) [M43].** With
`m(φ) = (1−ℙ_{Δ_ARB}(φ))·e^{−α_transactional·φ}·(φ_M⊗_φφ_X)·δ_transactional − (σ²Δt/8)·ℙ_{Δ_ARB}(φ)`
per `SRC` Definition 36 under (A-route):

(a) **closed form or impossibility**: either express `φ*` in elementary functions or the
    Lambert `W` function, or prove no such expression exists in that class;

(b) **if no closed form — the iteration is the deliverable**: exhibit an explicit map
    `T : (0,1) → (0,1)` (Newton on the FOC, or a monotone fixed-point form) with a
    machine-checked convergence guarantee on the region cut out by `Theorem52`'s second-order
    guard `q(φ) > 0`, and an **explicit error bound after n steps** — geometric with a stated
    ratio, in the problem's parameters. This is the artifact the hook runs;

(c) **iteration respects pro-cyclicality**: the computed root is monotone increasing in `σ`
    along the iteration (consistency with `Theorem50`'s `∂φ*/∂σ > 0`), so a controller that
    warm-starts from the previous block's `φ*` iterates in the correct direction under a
    volatility rise;

(d) **corner detection**: state the computable predicates (in the model's parameters, no
    numerals) deciding the taxonomy of `Theorem50(e)` — `τ* = 0` (base fee covers `φ*`),
    interior, shutdown (`m < 0` everywhere) — so the hook can branch before iterating.

---

## What is already proved — cite by declaration name AND file, do not redo

- `RequestProject/MevTaxControl.lean`: `Theorem29_monoid_path_is_direct`,
  `Theorem32_hazard_strictAntiOn_tau`, `H1_dLbar_dpiPhi_pos`, `H2_dnu_dlamMEV_pos`
- `RequestProject/MevTaxProgram.lean`: `Proposition16_corrected_law` (:1054), `totalDeriv`,
  `focCore`, `pathGate`, `hasDerivAt_phiTot`
- `RequestProject/MevLVRCancellation.lean` (`MevTaxLVR`): `Theorem37_LVR_cancellation`,
  `Theorem37_K_pos`, `Corollary37_root_invariance`
- `RequestProject/MevChannelClosure.lean` (`MevTaxChannels`):
  `Theorem38_two_routes_close_a_loop`, `Theorem39_elasticity_closes`, `ScaleHomogeneous`
- `RequestProject/MevReturnsReduction.lean` (`MevTaxReturns`): `Theorem40_returns_reduction`,
  `Theorem40d_loop_correction_removes_epsilon`,
  `Theorem44_objective_reading_does_not_discriminate`
- `RequestProject/MevShockInput.lean` (`MevTaxShock`): `Theorem45_shock_driven_utilization`
  (`ν = g(s, φ, κ_φ)`, `g` explicit — **M42(c)'s input**), `Theorem46_shock_flow_is_two_legged`,
  `Theorem47_no_exogenous_hazard_input`, `Theorem47_shared_driver_leaves_no_root`
- `RequestProject/MevTransactional.lean`: `Theorem48_*` (partition, `NT_FEE`, complement
  reading, benign payoff)
- `RequestProject/MevTransactionalOptimum.lean`: `Theorem49_*` (root restored),
  `Theorem50_*` (top-up law, pro-cyclicality, corners), `Theorem51_*` (incidence wedge),
  `Theorem52_*` (second order, `q > 0` guard — **M43(b)'s region**)

## Sources

`RequestProject/SRC_VOLATILITY_INSTRUMENTS_MEV.md` is `SRC`, pinned at commit `e21efc1` /
blob `d5cf324`. `RequestProject/VOLATILITY_INSTRUMENTS.md` is `DOC` (peer-owned, read-only):
Definition 18 (the schedule), Theorem 1 (the envelope and the gate value `u`), Definition 21
(`ℙ_{Δ_ARB}`), Proposition 9, Rule 6. `RequestProject/TAX6_RETURN_prior.md` is bundle 6's
return.

## What a complete return looks like

- `Theorem 53` with (b) resolved to exactly one of (i)/(ii)/(iii) with proof or witness, the
  (d) flag answered honestly — a "further ruling needed" verdict is acceptable, a silent
  choice is not.
- `Theorem 54` (a)–(d), with both guard conjuncts either discharged or the obstruction
  exhibited.
- `Theorem 55` with (a) decided; if impossibility, (b)'s iteration with the convergence rate
  as an explicit expression — this is the block the EVM implementation will be built from.
- Every declaration `#print axioms`-clean or its dependency stated. **No new `sorry`.**
  A stated `OPEN` with a reason beats a narrowed theorem.
