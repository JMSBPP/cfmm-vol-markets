# Claim Research — the four proof obligations of the `τ*_MEV` set-point derivation

**Domain:** Lean 4 / Aristotle formalization of a control-theoretic set-point derivation
**Researched:** 2026-08-08
**Confidence:** MEDIUM-HIGH on the *existing-Lean* verdicts (every citation below was read in
source); MEDIUM on the *reconstruction* of what the boxed `τ*_MEV` actually solves (the source does
not show the algebra — my reconstruction is stated explicitly and flagged for author confirmation).

---

## 0. Executive verdict

**Three of the four obligations look REFUTABLE as literally stated, and that is the useful outcome.**

| Obl. | Headline | My bet |
|------|----------|--------|
| **P1** | The `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is not a *linear* partition: the output map carries the kink `(σ²(i(t)) − σ_K²)^+`, and the `φ`-row of the state map is the non-affine logistic gate. Set-point optimization is legitimate only on a **saturation-limited band**. | **Refute the linear reading; salvage a saturated set-point.** |
| **P2** | The two boxes in the source contradict each other: the control objective is conditioned `\|_{λ_MEV}`, but the 5-factor chain's last factor `∂ν/∂τ_MEV` is (per P3's own prose) mediated *entirely* by `λ_MEV`. Under the stated conditioning the whole chain is identically zero. Separately, Rule 12 gives `τ_MEV` a **direct** monoid path to `φ` that the chain omits. | **"No other path" is FALSE.** High confidence. |
| **P3** | `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0` cannot be *proved* in the current model — the model has **no map `λ_MEV ↦ ν`** and deliberately carries **no demand elasticity** (the omitted MMR §7.3 eq. (27) term). It is an assumption; the honest deliverable is to make it a named, typed hypothesis. | **Not provable in-tree; formalize as hypothesis.** |
| **P4** | The box is (a) not a closed form — `τ_MEV` sits on both sides through `∂ν/∂τ_MEV`; and (b) under P3's own sign plus Theorem 20(A), the RHS bracket product is **negative**, giving `τ*_MEV > 1` — outside the fee-monoid carrier `[0,1]`. | **Refute on admissibility.** This is the project's headline candidate. |

The author's own `> note: This needs verification` is well-placed. **A refutation of P4 on the
admissibility ground, with the sign chain machine-checked, is a complete and successful project.**

---

## 1. Binding notation, and the collisions that must be adjudicated first

Notation is preserved exactly as written in
`notes/VOLATILITY_INTRUMENTS_MEV.md` (the derivation) and
`plank/notes/VOLATILITY_INSTRUMENTS.md` (the entry point). Where the derivation names no object, the
identifier below is **built from the source's own symbols** and is marked *(identifier minted from
source symbols)*. **No new glyphs are minted anywhere in this file.**

### 1.1 Blocking collisions — these gate formalization, they are not research questions

| id | The collision | Why it blocks |
|----|---------------|---------------|
| **NC-1** | `π^{\varphi}`. The derivation states `π^{\varphi} ≡ π^{\phi} − π^{LVR}` (line 28). The entry-point doc's **Definition 25** mints `π^{\varphi}(p_{\varphi}) ≡ p_{\varphi} Q_X^L(p_{\varphi}) + Q_M^L(p_{\varphi})` — the *portfolio value function*, the conic dual of the trading function. The doc explicitly warns at Proposition 9 [M2] that `π^{\phi}` (fee income) is "DISTINCT from `π^{\varphi}`, the trading-function glyph, per the standing `\phi`/`\varphi` split". `PROJECT.md` transcribes the derivation's 4th state coordinate as `π^{φ̃}` — a **third** glyph, appearing in neither source. | Every P1 statement about the state vector, and every P4 statement about `∂L/∂π^{\phi}`, is ill-posed until one reading is chosen. |
| **NC-2** | The leg pairing in `π^{\phi}`. The derivation writes `π^{\phi} ≡ φ_M ΔQ_M + p_{(η,Δ_i)} φ_X ΔQ_M` (line 106 — **both legs money**); its own derivative two lines later uses `ΔQ_X` in the second term (lines 108–110); and the later pair `(∂π^σ/∂φ_M, ∂π^σ/∂φ_X) = (p_{(η,Δ_i)} ΔQ_X, ΔQ_M)` (line 118) **swaps** the pairing again. Three mutually inconsistent readings. **Rule 6** of the entry-point doc (per-leg accrual `ΔQ_M^L ← ΔQ_M^L + φ_M ΔQ_M`, `ΔQ_X^L ← ΔQ_X^L + φ_X ΔQ_X`) supports `φ_M ↔ ΔQ_M`, `φ_X ↔ ΔQ_X`. | The boxed `τ*_MEV` carries the second bracket verbatim; which pairing is intended changes the box. **Flagged, not repaired** (notation rule). |
| **NC-3** | `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` (derivation line 63) lists **only** `σ²` as argument, while **Definition 18** makes the schedule a function of *both* `σ(i(t))` and the utilization gate whose argument is `ν`. The chain's `∂φ/∂ν` factor differentiates against an argument the derivation's own display does not contain. | Under the display as written, `∂φ/∂ν = 0` and the whole chain vanishes. See **C-P2-4**. |
| **NC-4** | `ν` vs `u`. The entry-point doc's discretization frame defines `ν_t ≡ φ_{(1/2,0)}(i(t); ΔQ(t),0) / φ_{(1/2,0)}(i(t); 0, L)` — the **per-step utilization ratio**, which is the *argument* of the gate; **Theorem 1**'s `u` is the gate's *value*, `u = α_R/(1 + exp(γ_R(β_R − ν_t)))`. In Lean these are two different slots: `VolInstrument.sigmoidR αR γR βR x` takes the ratio in slot `x`; `VolInstrument.multiFee n γ β α φbar u σ` takes the gate *value* in slot `u`. | `∂φ/∂ν` is therefore a **composite**: `∂φ/∂ν = (∂φ/∂u)(∂u/∂ν)`, i.e. `(Σ_j α_j Λ(γ_j(σ − β_j))) · α_R γ_R Λ'(γ_R(ν − β_R))`. Neither factor has a Lean carrier today. |

### 1.2 A registry-fact correction

`PROJECT.md` describes `lean/vol_markets/` as **37 files**. The directory contains **23 `.lean`
files** (10,651 lines total). Triage below.

---

## 2. What already exists in `lean/vol_markets/` — triage against these four obligations

Every declaration named here was read in source; file and role are given. Nothing is inferred from a
filename.

### 2.1 Directly load-bearing (READ IN FULL)

| File | Declarations that matter here | Relevance |
|------|-------------------------------|-----------|
| `VolInstrument.lean` | `probOr`, `probOr_eq`, `probOr_comm`, `probOr_assoc`, `probOr_zero`, `probOr_mem_Icc`, `probOr_mono`, `probOr_hazard`; `multiFee`, `multiFee_bounds`, `multiFee_monotone`, `multiFee_single_bridge`; `sigmoidR`, `sigmoidR_mem`; `flowRegion`, `flowRegion_mono_left`, `flowRegion_mono_right`, `flowRegion_sq`, `tickFlowRegion` | The `⊗_φ` monoid (`probOr`), the fee schedule `Φ(Θ_φ; ·)` (`multiFee`), the utilization gate (`sigmoidR`), and `φ_{(1/2,0)}` itself (`flowRegion`, `= √a·√b`) — i.e. the numerator/denominator of `ν_t`. |
| `MevOptimization.lean` | `ptrade` (`= σ/(σ + φ√(2/Δt))`), `ptrade_mem_Ioc`, `ptrade_eq_one_iff`, `ptrade_strictAntiOn`, `ptrade_monotoneOn_dt`, `ptrade_monotoneOn_sigma`, `ptrade_tendsto_atTop`, `ptrade_strictConvexOn`, `ptrade_convexOn`, `arb_add_fee_eq_lvr`, `mevHazard`, `mevMulti`, `mevMulti_nonneg`, `mevMulti_anti_phibar`, `mevMulti_anti_alpha`, `mevMulti_anti_u`, `mevMulti_mono_beta`, `mevMulti_ge_corner`, `mevMulti_corner_attained_levels`, `mevMulti_saturation_limit`, `mevMulti_strict_above_saturation`, `mevMulti_exists_min_compact`, `Theta_lambdaMEV_identification`, `mevMulti_min_gt_corner` | `ℙ_{Δ_ARB}` and `λ_ARB` in full. Note `mevMulti_exists_min_compact` carries the hypothesis `hadm : ∀ θ ∈ Θ, 0 ≤ θ.1 ∧ 0 ≤ θ.2.1` **precisely** to avoid the `ptrade` pole — the guard discipline this project must inherit. |
| `TauMevAlgebra.lean` | `lpShare`, `donation`; `tau_monoid_mem`, `tau_monoid_ge`, `tau_monoid_gt`, `tau_intensity_effect`, `tau_intensity_effect_strict`, `tau_no_targeting`, `tau_hazard_exact`; `tau_split_budget`, `tau_split_intensity_neutral`, `tau_split_flair_linear`, `tau_split_mevNet_bridge`; `tau_scaling_not_monoid_hom`, `tau_order_matters`, `tau_split_breaks_hazard` | The **only** place `τ_MEV` is formalized. `tau_intensity_effect_strict` is the monotone ancestor of `∂λ_MEV/∂τ_MEV < 0`. `tau_split_intensity_neutral` is the reason anti-claim **A6** exists. |
| `MevJointProgram.lean` | `joint_corner_degeneracy`, `joint_beta_degeneracy`, `joint_scalarization_degeneracy`; `flairPath`, `mevPath`, `flairPath_schedule`, `mevPath_schedule`, `flair_budget_pins_mean_fee`, `flair_budget_mean`, `flairPath_sum`, `flairPath_budget_mean`; `mev_ge_flat_under_flair_budget_false` (**T24 refutation**), `mev_ge_flat_under_flair_budget_const_sigma`; `mevNet`, `mevNet_anti_tau`, `mevNet_eq_zero_of_tau_one`, `mevNet_argmin_invariant`, `taxFraction`, `taxFraction_mem_Ico`, `taxFraction_mono`; `mev_mono_dt`; `mevTotal`, `mevTotal_eq_arb_of_sandwich_zero`, `mevTotal_mevMulti_eq_of_sandwich_zero`, `mevTotal_probOr_hazard` | Confirms the `(β,γ)` degeneracy that `PROJECT.md` relies on. `mevTotal_eq_arb_of_sandwich_zero` is the bridge that lets `λ_ARB` results be read as `λ_MEV` results under uniform clearing. |
| `Flow.lean` | `deltaShares`, `deltaShares_admissible_iff`; `liquidity0`, `liquidity1`, `getLiquidity`, `liquidity1_eq_div`; `terminalPayoff`, `trajPayoff`, `terminalPayoff_nonneg`; `trajPayoff_control`, `schedule_min_high`, `schedule_min_low`, `schedule_isLeast` | The `L`-side plumbing. `schedule_isLeast` is a bang-bang `IsLeast` precedent — the shape a saturated `τ*_MEV` selector should copy. |
| `FeeSchedule.lean` | `logistic`, `logistic_mem_Ioo`, `logistic_strictMono`, `logistic_tendsto_atTop`, `logistic_tendsto_atBot`; `Params`, `feeRaw`, `fee`, `fee_mem_Icc`, `fee_monotone`, `feeRaw_interpolate`, `feeRaw_interpolate_unique`, `exists_optimal_params`, `fee_mem_unit`, … | `logistic_strictMono` is the sole ancestor available for `∂φ/∂ν > 0`. `Λ` has **no derivative lemma** in this tree. |

### 2.2 Peripherally relevant (declaration lists inspected)

- `Panoptic.lean` — **`volOptionPayoff (dQv sig2 sig2K) := dQv * max 0 (sig2 - sig2K)` is literally
  `π^σ = ΔQ_v^⋆(σ²(i(t)) − σ_K²)^+`.** Also `volOptionPayoff_nonneg`, `deltaQv_of_payoff`,
  `replicationPrice`, `streamingPremium`, `latticeTheta`, `theta_atm_closed_form`. This is the single
  most valuable pre-existing carrier for P1/P4.
- `GeomProfile.lean` — `geomWeight`, `geomLiquidity`, `geomWeight_sum` (partition of unity),
  `geomLiquidity_sum` (`Σ L = L̄`), `geomWeight_pos`, `geom_terminalPayoff_total`,
  `geom_terminalPayoff_total_tickPrice`. The `Σ_{i_K} L(i_K) · (payoff)` shape of `π̂^σ` already
  exists here, with `p` abstract.
- `EndogenousMaturity.lean` — `dQvFunded (QM prisk dQvStar) = min(...)`, `dQvFunded_maximal`,
  `dQvFunded_admissible(_iff_mul)`, `tStarFunded_*`, `tStarJointMult_*`, `joint_candidates_disagree`.
  **The design precedent for a saturated actuator**: "the floor is the GREATEST admissible exposure".
  Copy this shape for the saturated `τ*_MEV` (C-P4-6).
- `TauJit.lean` — `uJtax`, `tauStarJIT (uJstar base) = uJstar / base`, `participates_iff_tau_le`,
  `lamJITtax_antitone_tau`, `tauStarJIT_tendsto_atTop`, `split_positive_tax_negative_witness`.
  **The only in-tree precedent for an "optimal tax closed form"** — and it is a *threshold*, defined
  by a participation constraint, not by a replication solve. Structural template for P4.
- `Upsilon.lean` — `upsilon`, `upsilon_volOption`, `upsilonTickSlope`,
  `ATMOTMNullHypothesis`, `exp_family_witnesses_ATMOTM`.
- `FlairOptimization.lean` — `flairHazard`, `flairMulti`, `pathWeight`, `shapeWeight`,
  `flairMulti_affine`, `flairMulti_mono_u`, `flairMulti_anti_beta`, `W_j_lt_W`,
  `flairMulti_le_corner`, `flairMulti_corner_attained_levels`, `flairMulti_saturation_limit`,
  `Theta_lambda_identification`. Needed only for the `(β,γ)`-freeze citation.
- `JitLiquidity.lean`, `SandwichTol.lean` — `λ_sandwich`/JIT channels; needed only to justify the
  `λ_sandwich = 0` (uniform clearing) reduction.

### 2.3 Out of scope for these four obligations

`CanonicalCurve.lean`, `CapponiEmbed.lean`, `CurvatureTwo.lean`, `EtaCurvature.lean`,
`EtaTilde.lean`, `PhiCES.lean`, `RiskDesign.lean`, `PosSpec.lean`, `Main.lean`. These are the
curvature/`ς_{X/M}`/CES track. `CapponiEmbed.canon_Fcap_not_CES` matters only as **anti-claim A5**.

### 2.4 The single largest methodological finding

**The tree contains essentially no differential-calculus infrastructure.** A grep for
`HasDerivAt` / `deriv` / `Differentiable` across all 23 files returns real uses in exactly one
place — `PhiCES.lean` (a `ρ → 0` CES limit). Everything else is `Monotone` / `StrictAntiOn` /
`ConvexOn` / `StrictConvexOn` / `Tendsto`.

P2, P3 and P4 are **all** derivative statements. The project must therefore either

1. **build the derivative layer** (`HasDerivAt` for `logistic`, `sigmoidR`, `multiFee`, `probOr`,
   `ptrade`) — real, bounded, ~150-250 lines of Lean, and the honest cost line; or
2. **restate the obligations in the tree's native monotone/convex idiom** — e.g. replace
   `∂ν/∂λ_MEV > 0` with `StrictMono (ν ∘ ·)`, and replace the chain rule with a composition-of-
   strict-monotone statement.

**Recommendation: option 2 for the sign claims (P3, and the sign half of P4), option 1 only where a
literal product-of-partials must be exhibited (P2, P4's algebra).** Option 2 is far cheaper, matches
the tree, and is *strictly stronger* for the refutation of P4 (a sign contradiction needs no
differentiability at all).

---

## 3. Claim catalogue

Complexity is Lean effort. "Verdict" is against the existing tree.

### 3.1 TABLE STAKES — the spec is worthless without these

| id | Claim, in source notation | Verdict | Cx | Falsity risk |
|----|---------------------------|---------|----|--------------|
| **C-P1-1** | The output row is not a linear/matrix partition: `π^σ = ΔQ_v^⋆(σ²(i(t)) − σ_K²)^+` is **not differentiable** at `σ²(i(t)) = σ_K²` for `ΔQ_v^⋆ ≠ 0`; hence `∂_(y,u)` is not a constant matrix on any domain containing the strike. | **NEW.** Object exists: `Panoptic.volOptionPayoff`. No differentiability lemma anywhere in tree. | LOW | **~0 — this is true.** The only way out is to restrict the domain to `σ² > σ_K²`, which is itself a finding. |
| **C-P1-4** | The `φ`-row admits **no** linear realization. `φ` is algebraic in `(ν, σ²(i(t)))` by Definition 18 (no memory ⟹ the `φ`-`φ` entry of `∂_(t+1,t)` is forced to `0`); the residual requirement is that `multiFee ∘ sigmoidR` be **affine in `ν`**, which fails because `Λ` is not affine. Three-point witness. | **NEW.** `FeeSchedule.logistic_strictMono` exists; **no non-affinity lemma**. `sigmoidR` has only `sigmoidR_mem` — no monotonicity, no derivative. | LOW | **~0.** A logistic is not affine; the witness is arithmetic. |
| **C-P1-5** | **Reachability / saturation.** With `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j, β_R, γ_R, α_R)` frozen, the attainable set of `π̂^σ` over admissible `τ_MEV ∈ [0,1)` is **bounded**, while `π^σ = ΔQ_v^⋆(σ²(i(t)) − σ_K²)^+` is unbounded in `σ²(i(t))`. Hence `∃ σ²(i(t))` for which **no** admissible `τ_MEV` solves `π^σ ≡^R π̂^σ`. | **PARTIAL.** Boundedness ancestors all exist: `VolInstrument.multiFee_bounds`, `sigmoidR_mem`, `probOr_mem_Icc`, `MevOptimization.ptrade_mem_Ioc`, `GeomProfile.geomLiquidity_sum` (`Σ L = L̄`). The *assembly* is new. | MED | **LOW**, conditional on the reading that `π^l(σ(i_K;Θ_σ))` is evaluated at the **leg** volatility `σ(i_K;Θ_σ)` (pinned by `Θ_σ`), not at realized `σ²(i(t))`. If it is evaluated at realized `σ²`, the claim can fail — **adjudicate this reading first.** |
| **C-P2-2** | **The conditioning contradiction.** The source boxes `𝒢_{π̂^σ, τ_MEV} := ∂π̂^σ/∂τ_MEV \|_{λ_MEV}` and, separately, the 5-factor chain for `∂π̂^σ/∂τ_MEV`. If `ν` depends on `τ_MEV` *only* through `λ_MEV` — which is exactly what the `Ḡ_(ν,λ_MEV)` paragraph asserts — then `(∂ν/∂τ_MEV)\|_{λ_MEV} = 0` and the boxed chain **vanishes identically** under the boxed conditioning. The two boxes cannot both be non-vacuous. | **NEW.** No carrier; it is a statement about the source's own bookkeeping. | LOW | **~0 as mathematics.** The risk is purely semantic — the author may intend `\|_{λ_MEV}` to mean something else (e.g. "at a reference `λ_MEV` level", a linearization point). **Escalate to the author; do not guess.** |
| **C-P2-3** | **"No other path" is false — the direct monoid path.** Rule 12 [M9] is `φ_total ← φ_M ⊗_φ φ_X ⊗_φ τ_MEV`, so `∂φ_total/∂τ_MEV \|_{φ_M, φ_X} = (1−φ_M)(1−φ_X) > 0` for `φ_M, φ_X < 1`. This is a `τ_MEV → φ` edge that does **not** pass through `ν`. The corrected total derivative is `∂π̂^σ/∂τ_MEV = (∂π̂^σ/∂L)(∂L/∂π^φ)(∂π^φ/∂φ)[(∂φ/∂ν)(∂ν/∂τ_MEV) + (1−φ_M)(1−φ_X)]` *(the bracketed correction; every symbol is the source's)*. | **PARTIAL.** `VolInstrument.probOr_eq` gives `⊗_φ` in the exact `1−(1−a)(1−b)` form; `TauMevAlgebra.tau_monoid_gt` gives the strict direction. The partial-derivative statement is new. | LOW | **LOW.** **I bet against the "no other path" clause.** The one counter-reading: the source's `∂π^φ/∂φ` already carries `1/(1−τ_MEV)` factors, i.e. it inverts the monoid *holding `τ_MEV` fixed as a parameter* — which is precisely the defect (the same symbol is used as a held parameter and as the differentiation variable in one chain). |
| **C-P2-4** | **The gate argument is missing from the schedule display.** `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` names only `σ²`; Definition 18's schedule is `φ(σ(i(t)); t)` gated by the utilization ratio. Under the display **as written**, `∂φ/∂ν = 0`, so the 5-factor chain is identically zero. Under Definition 18, the factor is the **composite** `∂φ/∂ν = (Σ_j α_j Λ(γ_j(σ(i(t)) − β_j))) · α_R γ_R Λ'(γ_R(ν − β_R))` (per **NC-4**). | **NEW.** `VolInstrument.multiFee` keeps `u` as a *separate argument*, so the Lean signature already encodes the distinction the source display elides. | LOW | **~0 as an inconsistency finding**; the composite form itself is a straightforward derivative computation once the derivative layer exists. |
| **C-P3-1** | **`∂ν/∂λ_MEV` is not defined.** `ν_t ≡ φ_{(1/2,0)}(i(t); ΔQ(t),0)/φ_{(1/2,0)}(i(t); 0, L)` and `λ_MEV ≡ λ_ARB ⊕ λ_sandwich` with `λ_ARB(t) ≡ Σ_{s<t} ℙ_{Δ_ARB}(·) π^LVR(s)/π^linear(s)`. Neither source supplies a map `λ_MEV ↦ ν`. `Ḡ_(ν,λ_MEV)` therefore has no referent until the model declares one. | **NEW / DEFINITIONAL GAP.** Confirmed absent: no declaration in any of the 23 files relates `mevHazard`/`mevTotal` to `flowRegion` or to any liquidity-supply object. | LOW to *state*; the *content* is a modelling decision | **N/A — this is a gap, not a proposition.** It is nonetheless table stakes: **P3 and P4 are both unformalizable until it is closed.** |
| **C-P3-5** | **Sign composition — the chain's last factor has the sign OPPOSITE to `Ḡ`.** `∂ν/∂τ_MEV = Ḡ_(ν,λ_MEV) · (∂λ_MEV/∂τ_MEV)`. Under uniform clearing `λ_sandwich = 0` so `λ_MEV = λ_ARB`, and Theorem 20(A) gives `ℙ_{Δ_ARB}(φ ⊗_φ τ_MEV) < ℙ_{Δ_ARB}(φ)` strictly, hence `λ_MEV` is strictly decreasing in `τ_MEV`. With `Ḡ_(ν,λ_MEV) > 0` this forces **`∂ν/∂τ_MEV < 0`**: raising the MEV tax **contracts** utilization. | **PARTIAL — the monotone form is essentially proven.** `TauMevAlgebra.tau_intensity_effect_strict` (strict, with the `0 ≤ φ`, `0 < τ_MEV`, `φ < 1`, `0 < σ`, `0 < Δt` guards), `MevOptimization.ptrade_strictAntiOn`, `MevJointProgram.mevTotal_eq_arb_of_sandwich_zero`. Only the *derivative-form* restatement and the composition are new. | LOW–MED | **LOW.** The ingredients are already axiom-clean in-tree. This is the highest-value/lowest-cost claim on the board. |
| **C-P4-1** | **Derivation audit: what equation does the box actually solve?** *(reconstruction — CONFIRM WITH AUTHOR)* The box is algebraically exactly the isolation of `(1−τ_MEV)` from `ΔQ_v^⋆ = [Σ_{i_K} π^l(σ(i_K;·)) ∂L(i_K)/∂π^φ] · (1/(1−τ_MEV)) · [ΔQ_M/(1−φ_X) + p_{(η,Δ_i)} ΔQ_X/(1−φ_M)] · (∂φ/∂ν)(∂ν/∂τ_MEV)`. Corollary: the box does **not** follow from `π^σ ≡^R π̂^σ` — that relation contains no free `(1−τ_MEV)` factor; the `(1−τ_MEV)` comes from `∂φ_M/∂φ` and `∂φ_X/∂φ`, i.e. from inverting `⊗_φ`, not from the replication relation. | **NEW.** Pure algebra + a negative (non-derivability) rider. | LOW for the algebra; MED for the rider | **MEDIUM on my reconstruction** — the source shows no intermediate step. The algebra check itself is certain; whether it is what the author meant is not. **Blocking question for the author.** |
| **C-P4-2** | **The box is not a closed form.** `τ_MEV` appears on the RHS through `∂ν/∂τ_MEV`, which is non-constant in `τ_MEV` whenever `λ_MEV` is — and `λ_MEV` is, because `ℙ_{Δ_ARB}` is a Möbius function of the composed fee `φ ⊗_φ τ_MEV`. So the box is a **fixed-point equation `τ_MEV = Ψ(τ_MEV)`**, not a closed form. | **PARTIAL.** `MevOptimization.ptrade_strictAntiOn` + `TauMevAlgebra.tau_monoid_gt` give the non-constancy immediately. | LOW | **LOW.** Escape hatch: the source's "we assume constant" applies to `Ḡ_(ν,λ_MEV)` only, **not** to `∂ν/∂τ_MEV`. If the author extends the constancy assumption to `∂ν/∂τ_MEV` the claim is neutralized — but then C-P3-4 bites instead. |
| **C-P4-3** | **ADMISSIBILITY REFUTATION — the box yields `τ*_MEV > 1`.** Under (i) `Ḡ_(ν,λ_MEV) > 0` [P3], (ii) `∂λ_MEV/∂τ_MEV < 0` [C-P3-5], (iii) `∂φ/∂ν > 0` [Definition 18 gate, `α_R, γ_R > 0`], (iv) `∂L(i_K)/∂π^φ ≥ 0` with strict somewhere and `π^l(σ(i_K;·)) ≥ 0`, (v) `ΔQ_M, ΔQ_X ≥ 0`, `φ_M, φ_X < 1`, `ΔQ_v^⋆ > 0` — the product on the box's RHS is strictly **negative**, hence `τ*_MEV = 1 − (negative)/ΔQ_v^⋆ > 1`. But `τ_MEV > 1` is outside Definition 17's carrier `[0,1]` (`VolInstrument.probOr_mem_Icc`) and outside Rule 6's economic domain `(0,1)`. **`τ*_MEV ∉ [0,1]`.** | **NEW — but every hypothesis has an in-tree ancestor.** Carrier for the violated conclusion: `VolInstrument.probOr_mem_Icc`. | MED | **LOW–MEDIUM, and I bet ON this refutation landing.** The soft spot is (iv): if `∂L(i_K)/∂π^φ < 0` (fee income *withdraws* liquidity) the sign flips. That reading contradicts the model's own economics ("discouraging liquidity" is what *λ_MEV* does, not what fee income does), but it is the one assumption with no in-tree carrier at all. **State (iv) as an explicit named hypothesis; do not smuggle it.** |

### 3.2 LOAD-BEARING — other claims depend on these; establish first

| id | Claim, in source notation | Verdict | Cx | Falsity risk |
|----|---------------------------|---------|----|--------------|
| **C-P1-2** | **State redundancy / non-minimal realization.** `π^{\varphi} ≡ π^{\phi} − π^{LVR}`. If `π^{LVR}` is not a coordinate of `(x, u_ex, u_en)`, the pair `(π^{\phi}, π^{\varphi})` is functionally dependent and the state trajectory lies in a proper affine subset of `ℝ⁴`; any realization on all of `ℝ⁴` has an unreachable subspace. | **NEW.** | LOW | **LOW**, but **gated on NC-1** — under the Definition 25 reading of `π^{\varphi}` the statement changes shape entirely (see C-P1-3). |
| **C-P1-3** | **Under the Definition 25 reading, the plant is a descriptor system, not a state recursion.** Definition 26's CPMM case gives `π^{LVR} = (σ²(i(t))/8) π^{\varphi}`. Combined with the derivation's `π^{\varphi} ≡ π^{\phi} − π^{LVR}` this yields the **algebraic constraint** `π^{\varphi}(1 + σ²(i(t))/8) = π^{\phi}` — two state coordinates tied through an exogenous input. Hence `∂_(x,u)` cannot be constant (the relation is bilinear in state × exogenous input) and the system is a DAE. | **NEW.** | MED | **LOW as mathematics**, but **entirely conditional on NC-1**. Under the derivation's own reading (`π^{\varphi}` = the fee-net-of-LVR residual) the claim is vacuous. **Present both branches; do not choose.** |
| **C-P2-1** | **The chain rule itself.** Given differentiability of each link `τ_MEV ↦ ν ↦ φ ↦ π^{\phi} ↦ L ↦ π̂^σ` at the operating point, the 5-factor product formula holds. | **NEW** (no derivative layer in tree). Mechanical from `HasDerivAt.comp`. | LOW (once the derivative layer exists) | **~0.** The source is right that this part is mechanical. **Its low value is exactly the point:** the entire content of P2 is the "no other path" clause, which is C-P2-3/C-P2-4. |
| **C-P3-2** | **The numerator half of `Ḡ_(ν,λ_MEV) > 0`.** Given a decomposition of the per-step flow into a noise part and an arbitrage part, and a hazard-monotone arbitrage part, `φ_{(1/2,0)}(i(t); ΔQ(t), 0)` is increasing in `λ_MEV`. | **PARTIAL — a real carrier exists.** `VolInstrument.flowRegion_mono_left` and `flowRegion_mono_right` establish that `φ_{(1/2,0)} = √a·√b` is monotone in **each** leg. | MED | **MEDIUM.** The flow decomposition primitive does not exist and must be minted. Sign hazard: an arbitrage trade moves one leg in and one out; the doc's traded-volume object is the geometric mean of *both legs of the same trade*, so both grow with trade size — but this must be *stated*, not assumed. |
| **C-P3-3** | **The denominator half.** "a reduction on the denominator by discouraging liquidity" — i.e. `φ_{(1/2,0)}(i(t); 0, L)` decreasing in `λ_MEV`, i.e. `L` decreasing in `λ_MEV`. | **NEW — and NOT PROVABLE IN-TREE.** This is exactly the omitted MMR §7.3 eq. (27) term. `MevOptimization.lean`'s own module docstring says the objective "has no demand response to the fee" and that corner solutions are "a property of the stated objective, not a market-equilibrium claim". `MevJointProgram.lean` repeats it. | HIGH if attempted as a theorem; LOW as a hypothesis | **HIGH as a theorem.** **I bet against proving this.** The correct deliverable is a named, typed hypothesis (an elasticity primitive) plus an explicit statement that the model does not derive it. |
| **C-P4-6** | **Saturated set-point.** Given C-P1-5, the well-posed object is not an exact solution but the **greatest admissible** `τ_MEV` (or the projection of the ideal solution onto the admissible interval), with the saturating branch proved to be the extremum — mirroring `EndogenousMaturity.dQvFunded_maximal` ("the floor is the GREATEST admissible exposure") and `Flow.schedule_isLeast`. | **NEW**, but with two exact in-tree design precedents (`dQvFunded_maximal`, `schedule_isLeast`) and one closed-form-tax precedent (`TauJit.tauStarJIT`, `participates_iff_tau_le`). | MED | **LOW.** This is the constructive salvage path if C-P4-3 refutes the box — and it feeds `PROJECT.md`'s "saturate-never-revert" EVM requirement directly. |

### 3.3 STRETCH — valuable, not required for a verdict

| id | Claim | Verdict | Cx | Falsity risk |
|----|-------|---------|----|--------------|
| **C-P3-4** | **The "assumed constant" clause is in tension with `ν`'s own shape.** `ν = φ_{(1/2,0)}(i(t); ΔQ(t),0)/φ_{(1/2,0)}(i(t); 0, L)` is a ratio with `L` in the denominator. Holding the numerator fixed, `ν` is strictly convex in `L`; so `∂ν/∂λ_MEV` constant forces `1/L` affine in `λ_MEV` — a strong, unstated structural restriction on the liquidity-supply response. | **NEW.** `VolInstrument.flowRegion_sq` gives the `√a√b` shape needed. | LOW | **LOW.** A cheap rider that materially weakens P4 even if C-P4-3 does not land. |
| **C-P4-4** | **Dimensional consistency.** `ΔQ_v^⋆` carries RAW LIQUIDITY units `L` (Convention 3, DECIDED). `π̂^σ = Σ_{i_K} L(i_K) π^l(·)` carries `L · [π^l]`; `τ_MEV` is dimensionless. Equating `∂π̂^σ/∂τ_MEV` with `ΔQ_v^⋆` therefore requires `π^l(σ(i_K;Θ_σ))` to be dimensionless (a per-unit-liquidity payoff). | **NEW.** | LOW as a spec check | **N/A.** Lean has no units system — **do this as a design-spec obligation, NOT an Aristotle target.** Sending a dimensional-analysis claim to Aristotle wastes budget. |
| **C-P1-6** | **Event-time index well-posedness.** `t → t+1 := event swap`. | **ALREADY SATISFIED BY CONSTRUCTION.** The whole hazard layer (`mevHazard`, `flairHazard`, `flairPath`, `mevPath`) is already indexed over `Finset.range T` with `ℕ`-indexed paths — that *is* the event-time frame. | — | **N/A.** Low value; record it as already-discharged and move on. **Do not spend Aristotle budget here.** |

### 3.4 ANTI-CLAIMS — provably false, degenerate, or out of scope. Do NOT attempt.

| id | Anti-claim | Why it must not be attempted |
|----|------------|------------------------------|
| **A1** | "`(β_j, γ_j)` tune `λ_MEV`" / any `(β,γ)`-as-actuator statement. | Refuted: `MevJointProgram.joint_corner_degeneracy`, `joint_beta_degeneracy`, `joint_scalarization_degeneracy` — the unconstrained joint program is degenerate and `(β,γ)` are not essential. The degeneracy-breaker lies **outside** `Θ_φ`. `PROJECT.md` already freezes them; do not reopen. |
| **A2** | Re-attempting T24 or any generalization of `mev_ge_flat_under_flair_budget_false`. | **Machine-refuted by counterexample** (`T=2, Δt=2, B=2, σ=(1,10)`, fees `(2,0)`: `31/22 > 4/3`). Only the `Θ_φ`-restricted varying-`σ` case is open — and it belongs to the lean4-spec Phase-11 carry-forwards, owned by the Lean4+math session, **not this project**. |
| **A3** | Citing `MevOptimization.arb_add_fee_eq_lvr` as substantive support for the MMR split. | Its own docstring calls it a **bridge identity — a ring tautology**, and the entry-point doc says it "is never to be cited as MMR Thm 3 formalized". Using it as evidence in this spec would be a review BLOCKER. |
| **A4** | Any unguarded fee/tax limit — `τ_MEV → ∞`, `φ ⊗_φ τ_MEV → ∞`, or a limit taken over an arbitrary compact `Θ`. | `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` is **Möbius with a negative-fee pole**, which falsified earlier drafts (T15/T17). The in-tree repairs are visible in the hypotheses: `mevMulti_exists_min_compact` carries `hadm : ∀ θ ∈ Θ, 0 ≤ θ.1 ∧ 0 ≤ θ.2.1`, and `mevMulti_saturation_limit` was CORRECTED with `0 ≤ φ̄_max + u_max α_max`. **Every `τ_MEV` statement in this project must carry an explicit `0 ≤ φ_M ⊗_φ φ_X ⊗_φ τ_MEV` guard.** |
| **A5** | Any Capponi-curvature ↔ `ε_{X/M}` identification, or reuse of the CES embedding to supply a curvature-based degeneracy-breaker. | **Machine-refuted:** `CapponiEmbed.canon_Fcap_not_CES`; only the endpoints embed (`Fcap_zero_is_rho_one`, `Fcap_one_is_rho_zero_limit`, `kappa_not_reparam_of_rho`). |
| **A6** | Formalizing the `τ_MEV` entry as revenue splitting (alternate (B), `φ = (1−τ_MEV)φ + τ_MEV φ`) and then running the 5-factor chain on it. | **Provably vacuous.** `TauMevAlgebra.tau_split_intensity_neutral` proves the split leaves `ℙ_{Δ_ARB}` *unchanged*; hence `λ_ARB`, hence `ν`, hence the whole chain would be identically zero. Also `tau_order_matters` proves the hybrid (A)∘(B) is order-sensitive. Rule 12 [M9] **DECIDED** the monoid entry (A); (B) and (C) are formalized-not-adopted. |
| **A7** | Proving that `∂_(t+1,t)`, `∂_(x,u)`, `∂_(y,x)`, `∂_(y,u)` **are** matrices / that the plant is LTI. | Refuted in advance by C-P1-1 (the `(·)^+` kink) and C-P1-4 (the non-affine logistic gate). Attempting the positive direction burns budget on a statement whose negation is cheap and certain. |
| **A8** | A closed-loop regulator over `e^σ = \|π^σ − π̂^σ\|`. | Explicitly **Out of Scope** in `PROJECT.md` ("the control target is an *optimal set-point*"). Also `\|·\|` is non-smooth at the replication point, compounding C-P1-1. |
| **A9** | The exact Corollary-2 kernel `(π^ARB/π^{\varphi})_exact` and its `σ²(i(t)) Δt < 8` guard. | Recorded **UNFORMALIZED/OPEN, T19 omitted, no carrier** — a parked lean4-spec item, not this project's work. |
| **A10** | Sending C-P4-4 (dimensional consistency) or C-P1-6 (event-time indexing) to Aristotle. | Neither is a Lean-shaped proposition. C-P4-4 needs a units discipline Lean does not have; C-P1-6 is already discharged by the existing `Finset.range T` frame. |

---

## 4. Dependency order (acyclic)

```
NC-1 (π^{\varphi} reading)  ─┬─> C-P1-2 ──> C-P1-3
NC-2 (leg pairing)          ─┼─────────────────────────────────> C-P4-1 ──┬──> C-P4-2
NC-3 (gate argument)        ─┴─> C-P2-4 ──┐                               └──> C-P4-3
NC-4 (ν vs u)               ─────────────>┤                                     ^   ^
                                          ├─> C-P2-1 ──> C-P2-3 ────────────────┘   │
C-P3-1 (mint ν = N(λ_MEV))  ──┬──> C-P3-2 ┘                                          │
                              ├──> C-P3-3 (hypothesis, not theorem)                  │
                              ├──> C-P3-4                                            │
                              └──> C-P3-5 ─────────────────────────────────────────-─┘
C-P1-1 (kink)               ──┬──> C-P1-5 ──> C-P4-6
C-P1-4 (non-affine gate)    ──┘
C-P2-2 (conditioning contradiction)  — independent, no prerequisites
```

### Dependency notes

- **The four `NC-*` collisions are hard prerequisites, not research.** They are author/user rulings.
  They cost nothing and unblock five claims. **Get them ruled before any Aristotle submission.**
  Precedent: the lean4-spec ledger's section C ("Awaiting a USER DECISION — the cheapest items on
  the whole board").
- **`C-P3-1` gates all of P3 and, through `C-P3-5`, the headline `C-P4-3`.** Minting the map
  `ν = N(λ_MEV; ·)` is the single highest-leverage act in the project.
- **`C-P2-2` is independent and cheap** — it needs no derivative layer and no new primitives. It
  should be resolved *first*, because if the `\|_{λ_MEV}` conditioning is affirmed, the 5-factor
  chain is vacuous and the whole P2/P4 branch changes shape.
- **`C-P4-3` depends on `C-P3-5` for sign (ii) and on `C-P4-1` for the algebra**, but **both can be
  supplied as explicit Lean hypotheses**, which decouples the Aristotle queue (see §5).
- `C-P1-1` and `C-P1-4` have no prerequisites and are the cheapest certain results on the board.

---

## 5. Aristotle bundling

**Operational constraints observed:** never run parallel `aristotle continue` on the **same**
project; parallel `submit` to **new** projects is permitted; on `OUT_OF_BUDGET` run a single
`continue` on the same project rather than a fresh scoped submit; the CLI requires **full UUIDs**
(`aristotle show|tasks` return HTTP 500 on short ids — `aristotle list` prints the full UUIDs).
Workflow: draft `sorry`'d statements locally → Aristotle proves → integrate the returned tar. **Send
the document, do not hand-draft proofs.** Every bundle must state its notation map in the prompt.

### Recommended bundles

| Bundle | Contents | Deps | Why grouped |
|--------|----------|------|-------------|
| **B-WELLPOSED** | C-P1-1, C-P1-4, C-P1-5, plus whichever of C-P1-2 / C-P1-3 survives the NC-1 ruling | NC-1 | All refutation-shaped with explicit witnesses — Aristotle's strongest mode. Needs **no** derivative layer except C-P1-1's non-differentiability (one Mathlib lemma). Self-contained: no new primitives. |
| **B-DERIV** | The derivative layer as a standalone deliverable: `HasDerivAt` for `FeeSchedule.logistic`, `VolInstrument.sigmoidR`, `VolInstrument.multiFee` (in both `σ` and `u`), `VolInstrument.probOr`, `MevOptimization.ptrade` — plus the two trivial monotonicity riders that are *missing* today: `sigmoidR` strictly monotone in its ratio slot (from `logistic_strictMono`), and `multiFee` monotone in `u` (from `multiFee`'s affine-in-`u` shape). | none | **This is infrastructure, and it should be its own project.** Nothing in P2/P3/P4 can be stated in derivative form without it, and bundling it with a contentful claim risks the whole submission timing out on scaffolding. Note `flairMulti_mono_u` and `mevMulti_anti_u` exist at the *hazard* level but **not** for `multiFee` itself. |
| **B-CHANNEL** | C-P2-1, C-P2-2, C-P2-3, C-P2-4 | NC-3, NC-4, B-DERIV (or hypothesis-parameterized) | The "how many paths does `τ_MEV` have" question, whole. C-P2-2 can be stated without derivatives at all (as a `∀` over any `ν` constant in `λ_MEV`) — **do that**, so the bundle is not hostage to B-DERIV. |
| **B-SIGN** | C-P3-2, C-P3-4, C-P3-5 | C-P3-1 ruling | **State these in the tree's native monotone idiom, not with derivatives** (`StrictAnti`, `StrictMono`, composition) — then this bundle needs no B-DERIV at all and reuses `tau_intensity_effect_strict` / `ptrade_strictAntiOn` directly. C-P3-3 is deliberately **excluded** — it is a hypothesis, not a target. |
| **B-TAUSTAR** | C-P4-1 (algebra + non-derivability rider), C-P4-2, C-P4-3, C-P4-6 | NC-2; C-P3-5 and C-P4-1's hypotheses **passed in as explicit hypotheses** | **Parameterize the hypotheses** — take `Ḡ_(ν,λ_MEV) > 0`, `∂λ_MEV/∂τ_MEV < 0`, `∂φ/∂ν > 0`, `∂L(i_K)/∂π^φ ≥ 0` as named Lean hypotheses rather than importing proved lemmas. This makes B-TAUSTAR submittable **in parallel** with B-SIGN and B-CHANNEL instead of serialized behind them. |

**Parallelization plan:** submit **B-WELLPOSED**, **B-DERIV**, **B-CHANNEL**, **B-SIGN**,
**B-TAUSTAR** as five *new* projects (parallel `submit` is permitted), each hypothesis-parameterized
so no bundle waits on another's return. This converts an otherwise 4-deep serial dependency chain
into one wave. **Do not** submit any two of them as `continue` on a shared project.

**Register every submission in `.planning/IN-FLIGHT.md`-style ledger rows with a RESUME TRIGGER at
the moment of submission**, per the lean4-spec maintenance rule ("hand-off creates a row … not
afterwards"). This project's planning root is `control/.planning/`.

---

## 6. What is already proven — the short answer to "how much of it exists?"

**None of P1, P2, P3 or P4 is proven.** What exists is *ancestry*:

| Obligation | Already in-tree | Genuinely new |
|------------|-----------------|---------------|
| **P1** | `Panoptic.volOptionPayoff` **is** `π^σ` verbatim; the event-time frame (`Finset.range T` hazard sums) is already the right index; boundedness ancestors (`multiFee_bounds`, `sigmoidR_mem`, `ptrade_mem_Ioc`, `probOr_mem_Icc`, `geomLiquidity_sum`) all exist | Every well-posedness *statement*. No state-space, realization, minimality, or differentiability object exists anywhere in the tree. |
| **P2** | The monoid in the exact needed form (`probOr_eq : probOr a b = 1 − (1−a)(1−b)`); `multiFee`'s signature already separates the `u` slot | The entire chain. **No derivative infrastructure exists.** The "no other path" clause has no ancestor because it has never been asked. |
| **P3** | `flowRegion_mono_left/right` (the numerator half's monotonicity of `φ_{(1/2,0)}`); `tau_intensity_effect_strict` + `ptrade_strictAntiOn` + `mevTotal_eq_arb_of_sandwich_zero` (the sign composition C-P3-5 is nearly assembled already) | The map `λ_MEV ↦ ν` does not exist. The liquidity-supply response (C-P3-3) is *deliberately excluded* by the model's stated scope. |
| **P4** | Structural precedents only: `TauJit.tauStarJIT` (a closed-form optimal tax, but a *participation threshold*, not a replication solve); `EndogenousMaturity.dQvFunded_maximal` and `Flow.schedule_isLeast` (the saturated-actuator shape); `probOr_mem_Icc` (the carrier the box violates) | The box itself, its audit, its fixed-point character, and its admissibility. `∂L(i_K)/∂π^φ` — the object the whole first bracket rests on — **has no carrier of any kind**. |

---

## 7. Falsity bets, stated plainly

Refutation is a valid outcome. Where I would put money:

- **BET AGAINST P2's "no other path" clause** (C-P2-3). Rule 12 is a DECIDED direct monoid path. High
  confidence.
- **BET AGAINST P4's box as a closed form** (C-P4-2) and **BET ON the admissibility refutation**
  (C-P4-3) — `τ*_MEV > 1`, outside `[0,1]`. Medium-high confidence, with the caveat that hypothesis
  (iv) `∂L(i_K)/∂π^φ ≥ 0` has no in-tree carrier and must be named, not smuggled.
- **BET AGAINST proving P3** (C-P3-3). The model has no demand elasticity by explicit design. The
  honest deliverable is a typed hypothesis plus a statement that the model does not derive it.
- **BET ON P1's refutation of the linear reading** (C-P1-1, C-P1-4) — near-certain — **and on the
  saturation finding** (C-P1-5), which is the constructive salvage and directly generates the EVM
  "saturate-never-revert" requirement in `PROJECT.md`.
- **NO BET on C-P2-2** — the mathematics is trivial, but whether `\|_{λ_MEV}` means what I read it to
  mean is an author question, not a research question.

---

## 8. Open questions this research could not resolve

1. **NC-1 through NC-4** — four notation/definition collisions requiring an author or user ruling.
   Nothing formalizable until they are closed. All four are zero-cost.
2. **What `∂L(i_K)/∂π^φ` *is*.** The first bracket of the box rests on it entirely, no source defines
   it, and no Lean carrier exists. Its sign is the one soft spot in the C-P4-3 refutation.
3. **Whether my C-P4-1 reconstruction is the author's derivation.** The source shows no intermediate
   algebra. My reconstruction reproduces the box exactly, which is strong evidence — but it is
   evidence, not confirmation.
4. **Whether `π^l(σ(i_K; Θ_σ))` is evaluated at the leg volatility or at realized `σ²(i(t))`.**
   C-P1-5's boundedness argument, and therefore the saturation finding, turns on this.
5. **The `Θ_φ`-restricted varying-`σ` case of Theorem 19** remains open upstream. It is **not** this
   project's work (anti-claim A2) but it is adjacent, and if the Lean4+math session closes it the
   result may constrain the fee path this controller sees.
