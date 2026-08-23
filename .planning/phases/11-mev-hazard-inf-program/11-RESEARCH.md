# Phase 11: MEV hazard-rate metric and infimum program (λ_MEV) — Research

**Researched:** 2026-07-30
**Domain:** CFMM arbitrage/MEV theory (Milionis–Moallemi–Roughgarden 2305.14604) → discrete hazard functional → Lean4/Mathlib optimization over the multi-sigmoid fee space Θ_φ
**Confidence:** HIGH on the anchor mathematics (paper read end-to-end from the local PDF), HIGH on the Lean mirror structure (FlairOptimization.lean read line-by-line), MEDIUM on the Angstrom parameter mapping (repo constants vs live docs disagree — see §Open Questions Q3)

---

<user_constraints>
## User Constraints (from 11-CONTEXT.md)

### Locked Decisions (verbatim from `## Constraints / workflow rules (binding)`)

- Doc-driven Aristotle workflow: the reference note is
  `VOLATILITY_INSTRUMENTS.md ### MEV`; when the math spec is drafted into
  the doc (LaTeX, minimal prose), the DOC goes to Aristotle with
  instructions — no locally hand-drafted proofs. Strictly serial queue.
- Notation binding: identifiers from the doc's symbols only; λ_MEV,
  Θ_{λ_MEV} notation matches the doc's λ, Θ pattern; no interpretive
  names (memory `vol-instruments-notation-binding`).
- Doc edits to `VOLATILITY_INSTRUMENTS.md` require HEAVY USER APPROVAL
  (plank todo.md `## LEAN4 - MATH` precedent).
- Two-reviewer gate (Reality Checker + specialist) on the phase plan and
  on any spec artifact before execution.
- λ_MEV theorems land in a new `lean/vol_markets/` module beside
  `FlairOptimization.lean`; traceability rows go to
  `model/vol_markets/LEAN_TRACEABILITY.md` §7.

### The mathematical target (verbatim, `## The mathematical target`)

1. **Metric**: discrete `mevHazard` mirroring `flairHazard` — per-block
   arb/sandwich intensity over capital, where the per-step extraction is
   fee-DEPENDENT and DECREASING (from 2305.14604: arb trades only when the
   price gap exceeds the fee band; the fraction of profitable blocks
   shrinks with the fee). The fee is `multiFee` evaluated on the σ-path —
   the SAME Θ_φ as FLAIR.
2. **Identification**: `Θ_{λ_MEV} ⊂ Θ_φ` — which coordinates control
   inf λ_MEV. Expected structure: the level block `{φ̄, α, u}` is again
   controlling but with OPPOSITE monotonicity (fees up ⟹ λ_MEV down ⟹
   inf at the level corner TOP, same corner as sup λ_FLAIR — check!), and
   the shape block `(β, γ)` becomes ESSENTIAL rather than
   reallocation-only, because arb intensity concentrates where σ realizes:
   centering β at the realized-vol mass is where fee deterrence binds.
3. **The infimum program**: uniform lower bound, attainment/boundary
   characterization (mirror of `flairMulti_le_corner` /
   `_saturation_limit`), with the necessary-hypothesis discipline
   (Aristotle has twice added missing hypotheses; expect e.g. positivity
   of the arb-opportunity weights).
4. **Joint program**: state sup λ_FLAIR vs inf λ_MEV jointly — if both
   optima sit at the same level corner, the trade-off is degenerate at the
   level block and the ENTIRE tension lives in `(β, γ)` + the demand
   elasticity absent from both functionals (record the caveat again).
5. **Angstrom bridge (statement-level)**: the ToB-auction recycling maps
   to a rebate term in the hazard (extraction returned to LPs reduces net
   λ_MEV); the l2 MEV-tax factor 49/50 is a concrete `τ` in a
   `(1−τ)·extraction` term — a candidate protocol-controllable parameter
   OUTSIDE Θ_φ, to be recorded as such.

### Claude's Discretion

CONTEXT.md has no explicit `## Claude's Discretion` section. By the shape of
target items 2 and 3 ("check!", "expect e.g. …"), the *verification* of the
monotonicity/essentiality hypotheses is discretionary research output — and
this research **confirms item 2's first half and REFUTES its second half**
(see §Findings F4, F5). The choice of Lean identifiers subject to the notation
rule, and the resolution of the three symbol collisions (§Findings F2), are
discretionary but must be user-approved as part of the doc edit.

### Deferred Ideas (OUT OF SCOPE)

CONTEXT.md has no `## Deferred Ideas` section. Out of scope by the project
ownership map (`CLAUDE.md`): GAMS `.gms`, Plank `.plk`, Solidity `src/`,
Foundry `test/`. Out of scope by the phase's own framing: the continuum
path-integral form of λ_MEV (the discrete functional is the deliverable, as
with λ_FLAIR); any demand-elasticity / optimal-fee equilibrium layer (belongs
to `FeeSchedule` / arXiv:2508.08152).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

**ROADMAP Phase 11 says `**Requirements**: TBD`. THIS IS A REAL GAP AND MUST BE
CLOSED AT PLANNING TIME.**

`.planning/REQUIREMENTS.md` covers only the v1 GAMS↔Plank plumbing milestone
(REPO/TOOL/KERN/MAP/REF/PLNK/GAMS/BRDG/PIPE). It has **no** Lean/math-track IDs
and should NOT be extended — the established convention for the Lean-track
phases is CTX-* tags minted at planning:

- Phase 08: "no formal REQ-IDs — the locked decisions in `08-CONTEXT.md` are the requirements (CTX-HYGIENE, CTX-VENDOR, …)"
- Phase 09: "CTX-PANEL, CTX-VAR, CTX-EST, … (CTX-* tags minted at planning, per the Phase-8 convention)"
- Phase 10: "CTX-SIZE, CTX-FEE, CTX-PREM, CTX-GATE, CTX-PANEL2, CTX-EST2, CTX-XWALK, CTX-REPLAY-OPT"

**Recommended CTX-* set for Phase 11** (each maps 1:1 to a CONTEXT.md target
or binding constraint; the planner should mint these into ROADMAP line 250):

| ID | Description | Research Support |
|----|-------------|-----------------|
| **CTX-MEVDOC** | Draft the λ_MEV LaTeX block into `VOLATILITY_INSTRUMENTS.md ### MEV` (minimal prose), resolving the three symbol collisions; HEAVY USER APPROVAL before any commit | §Findings F1 (exact closed forms to transcribe), F2 (collisions), §Code Examples (draft LaTeX), §Don't Hand-Roll (addendum-file precedent 489bb43) |
| **CTX-PTRADE** | The fee-decreasing kernel: `ptrade` definition + antitone/convex/limit/`Δt`-monotone lemmas; MMR bridge identities `arb = lvr·ptrade`, `fee = lvr·(1−ptrade)`, `arb+fee = lvr` | §Findings F1, F3; §Theorem Mirror List T1–T6, T20 |
| **CTX-MEVHAZ** | `mevHazard` / `mevMulti` discrete functionals mirroring `flairHazard`/`flairMulti`, + the CPMM instantiation lemma (mirror of `capitalDenominator_pos`) | §Architecture Patterns P1; §Theorem Mirror List (definitions) |
| **CTX-INF** | Identification `Θ_{λ_MEV} = {φ̄, α, u}` + the SOLVED infimum: monotonicity block, level-corner attainment, β→−∞ saturation limit + strict gap, compact minimizer existence | §Findings F4; §Theorem Mirror List T7–T15 |
| **CTX-JOINT** | The joint program: (a) the DEGENERACY theorem (same argopt), (b) the Jensen/constrained reformulation where shape becomes essential, (c) the demand-elasticity caveat pinned to MMR eq. (27) | §Findings F5, F6 (**the phase's headline result**); §Theorem Mirror List T16–T18, T21 |
| **CTX-ANGSTROM** | Statement-level bridge: `τ`-rebate factorization + argmin invariance, the batch-cadence clock `Δt` as a parameter OUTSIDE Θ_φ, sandwich-nulling via the existing `probOr_zero` | §Findings F7, F8; §Theorem Mirror List T19, T22–T24 |
| **CTX-TRACE** | LEAN_TRACEABILITY §0 notation-dictionary rows + §7 claim rows; §6 "MEV section OPEN" flipped | §Don't Hand-Roll; §Validation Architecture |
| **CTX-REVIEW** | Two-reviewer gate (Reality Checker + one specialist) on the doc addendum AND on the Aristotle prompt, before submission | §Common Pitfalls PIT-7; §Validation Architecture |

</phase_requirements>

---

## Summary

The anchor paper delivers **exactly** the object this phase needs, in closed
form, and it is *simpler* than CONTEXT anticipated. Milionis–Moallemi–
Roughgarden (arXiv:2305.14604 v2, 23 Jul 2025 — read in full from
`../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf`) prove that
under a Poisson block-arrival model the steady-state fraction of blocks that
contain a profitable arbitrage trade is

> **P_trade = 1 / (1 + φ·√(2/Δt)/σ) = σ / (σ + φ·√(2/Δt))**

(their Theorem 1, where their fee symbol γ is our φ and their block rate λ is
1/Δt), and that in the fast-block regime the expected instantaneous arb-profit
rate factorizes as **ARB ≈ LVR × P_trade** (their Theorem 3 / eq. (12)), with
the complementary split **FEE ≈ LVR × (1 − P_trade)** (their Theorem 4) so that
**ARB + FEE ≈ LVR**. The fee-decreasing object CONTEXT asked me to extract is
`P_trade`, and it is a **hyperbolic (Möbius) function of the fee — strictly
decreasing, strictly convex, valued in (0,1]** — *not* the
`max(gap − fee, 0)` convex-piecewise-linear shape hypothesized in the phase
brief. That correction is load-bearing: it is what makes the Lean mirror both
possible (monotonicity survives) and structurally different from FLAIR
(affineness does not).

Consequences for the program, all verified rather than assumed:

1. **The level block behaves exactly as CONTEXT predicted.** `mevMulti` is
   coordinatewise antitone in (φ̄, α, u), so **inf λ_MEV sits at the level
   corner TOP — the SAME corner as sup λ_FLAIR.** Confirmed.
2. **The shape block does NOT become essential — CONTEXT's expectation here is
   REFUTED for the unconstrained functional.** Because `P_trade` is antitone
   in the fee and `multiFee` is antitone in β, `mevMulti` is *isotone* in β, so
   its infimum is again approached as **β → −∞**, the same boundary that
   saturates sup λ_FLAIR. The unconstrained joint program is therefore
   **degenerate at every coordinate of Θ_φ**: one point of the parameter space
   simultaneously maximizes λ_FLAIR and minimizes λ_MEV. There is nothing to
   trade off.
3. **The trade-off is recovered — sharply — only by stating the joint program
   as a CONSTRAINED one.** Fix the FLAIR fee budget (λ_FLAIR = target) and
   minimize λ_MEV. Since `P_trade` is strictly convex in the fee and λ_FLAIR
   pins the weighted *mean* fee, **Jensen gives a strict, attained answer: for a
   fixed fee budget, λ_MEV is minimized by a FLAT fee (α = 0 / u = 0), and every
   volatility-responsive sigmoid schedule delivering the same fee income is
   strictly WORSE for MEV.** This is the phase's substantive, non-degenerate,
   provable result, and it is the honest replacement for CONTEXT target item 4.
4. The Angstrom objects (`τ`-rebate, batch cadence `Δt`) are genuinely
   **outside Θ_φ** and admit thin provable statements — including an argmin-
   invariance lemma showing the rebate cannot move the Θ_φ optimum at all.

**Primary recommendation:** Formalize `ptrade` as the *only* new nonlinearity,
mirror FlairOptimization's 15 theorems with every inequality reversed, and make
the **degeneracy theorem + the Jensen constrained-program theorem** the phase's
headline deliverables. Do NOT promise "shape becomes essential" in the doc
addendum without the constraint — it is false as stated.

---

## Findings

### F1 — The exact closed forms (CONTEXT Q1). Confidence: HIGH (paper read directly)

Source: `../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf`
(arXiv:2305.14604v2, 23 Jul 2025). Text extracted with `pdftotext -layout`.

**Model (their §2–§3).** Two assets; external price `P_t` a GBM with volatility
σ > 0; CFMM with proportional fee γ ≥ 0 (per side, so the no-trade band on
log-mispricing `z` is `[−γ, +γ]`); arbitrageurs arrive at Poisson times of rate
λ > 0 with mean interarrival `Δt ≜ λ⁻¹` calibrated to the mean interblock time.
Arbitrageurs are **myopic** (competition). At each arrival the mispricing jumps
to the nearest band endpoint; between arrivals it diffuses.

**Assumption 2 (Symmetry), REQUIRED for the closed forms:** `μ = ½σ²` and
`γ₊ = γ₋ ≜ γ`. Paper states this is WLOG at the cost of algebra (their
Appendix C carries the non-symmetric variant).

**Theorem 1 (stationary distribution).** `z_t` is ergodic with density

```
              ⎧ π₊ · (η/γ)·e^{−(η/γ)(z−γ)}     z > +γ
  p_π(z)  =   ⎨ π₀ · 1/(2γ)                    z ∈ [−γ, +γ]
              ⎩ π₋ · (η/γ)·e^{−(η/γ)(−γ−z)}    z < −γ
```
with the composite parameter **η ≜ γ√(2λ)/σ**, `π₀ = η/(1+η)`,
`π₊ = π₋ = ½·1/(1+η)`. (Confirmed LINEAR in γ: the paper fixes
`η/γ = √(2λ)/σ` as the exponential rate.)

**The fee-decreasing object (THE extraction target):**

```
  P_trade  ≜  π₊ + π₋  =  1 / (1 + η)  =  1 / (1 + γ√(2λ)/σ)  =  σ / (σ + γ√(2λ))
```

= "the long-run fraction of blocks that contain an arbitrage trade". Note
explicitly (paper, §4.1): **`P_trade` does not depend on the bonding function
or the feasible set — the only pool property relevant is the fee γ.** That is
precisely what makes it composable with our `multiFee(σ_t)` with no CFMM-shape
baggage. Reference values (their Table 1, σ = 5% daily): Δt = 12 s, γ = 1 bp →
80.7%; γ = 30 bp → 12.3%; Δt = 2 s, γ = 30 bp → 5.4%.

**Theorem 2 (exact rate).** `ARB = λE_π[A(P,z)] = λP_trade·(√(2λ)/σ)·∫₀^∞ Ā(P,x)e^{−√(2λ)x/σ}dx`
— a Laplace transform, semi-closed. Similarly `FEE = λE_π[F(P,z)]`.

**Theorem 3 (fast-block asymptotics, λ → ∞) — the discretization anchor:**

```
  ARB = (σ²P/2) · [ y*′(Pe^{−γ}) + e^{+γ}·y*′(Pe^{+γ}) ] / 2 · P_trade + o(√(Δt))
        └────────────── = y*′(P) + O(γ) for small γ ──────────────┘
```
where `y*′(P)` is the pool's marginal liquidity in the numéraire, and
`LVR ≜ (σ²P/2)·y*′(P)` is the frictionless Milionis et al. [2022] rate. Hence
**eq. (12): ARB ≈ LVR × P_trade** when the fee is small in the fast-block
regime.

**Theorem 4:** `FEE ≈ LVR × (1 − P_trade)`, hence **ARB + FEE ≈ LVR** — LVR is
*split* between arbitrageur profit and LP fee income according to `P_trade`.

**Corollary 2 (constant-product, fully explicit — the instantiation to use):**

```
  ARB/V(P) = (σ²/8) · P_trade · e^{+γ/2} / (1 − σ²/(8λ))     if σ²/8 < λ
           = +∞                                               otherwise
  FEE/V(P) = (σ²/8) · (e^{γ/2}−e^{−γ/2})/γ · 1/(1+σ/√(2λγ)) · 1/(1+σ/(2√(2λ)))
```
with `LVR/V(P) = σ²/8`. **The `σ²/8 < λ` side condition is the paper's own
non-degeneracy hypothesis and MUST be carried into any Lean statement using
this kernel** — below it the expected arb profit is literally infinite.

**Hypotheses that must carry into Lean statements:** σ > 0; λ > 0 (⟺ Δt > 0);
γ ≥ 0; Assumption 2 (symmetry) for the closed form; the technical convexity
bound (13) `∂ₓₓĀ(P,x) ≤ A₀e^{cx}` for Theorem 3; `σ²/8 < λ` for Corollary 2.
Also: fast-block regime (λ → ∞) and small-fee (γ → 0) for the `≈` in eq. (12) —
so the discrete functional built on `LVR·P_trade` is a **leading-order** object
and the docstring must say so, exactly as `flairHazard`'s docstring flags the
`dp`-as-volume reading.

**Also extracted (used below):** §7.1 — arb profits per unit time scale as
`Δt^{1/2}`, so faster chains reduce LP loss; multi-block MEV = censoring to
inflate effective `Δt`. §7.2 — the mispricing/arb efficient frontier
(Corollary 1: `σ_z → γ/√3` as λ→∞). §7.3 eq. (27) — **delta-hedged LP P&L =
E[NT_FEE] − E[ARB]**, and "higher fees reduce noise-trader activity (decreasing
E[NT_FEE]) but also reduce arbitrage profits" — the *exact* location of the
demand elasticity absent from both our functionals.

### F2 — THREE notation collisions must be resolved BEFORE the doc edit. Confidence: HIGH

`LEAN_TRACEABILITY.md` §0 is explicit: *"Reserved project-wide: **`η` is the
pricing-kernel eta** … It is never reused. The fee paper's `η⁰`/`η¹` are mapped
to Latin names below."* The MMR symbol set collides with the doc's in three
places. **These are the highest-risk items in the phase** — a collision that
reaches Aristotle produces a module that is either wrong or unmergeable.

| MMR symbol | Meaning in MMR | Collides with | Resolution (recommended) |
|---|---|---|---|
| `γ` | the proportional **trading fee** | `Θ_φ = {γ, φ̄, β, α}` where **`γ_j` is sigmoid steepness** (`FeeSchedule`: `s_f = 1/γ`) | Transcribe MMR's `γ` as **`φ`** throughout. The doc's `φ` *is* the fee. No-trade band becomes `[Pe^{−φ}, Pe^{+φ}]`. Pure substitution, no invention. |
| `λ` | the **Poisson block rate** | the doc's `λ` = the **hazard rate** (`λ ≡ ⊕λ_i`, `λ_M + λ_X`) | Use MMR's OWN alternative primitive **`Δt ≜ λ⁻¹`** (mean interblock time). Consistent with the project's existing `Δ_i` tick-spacing style. Lean identifier `Δt`. Then `√(2λ) = √(2/Δt)`. |
| `η` | the composite `γ√(2λ)/σ` | **RESERVED** — `η` is the pricing-kernel eta (`model/exp/eta.md`, `VolInstrument.priceEta`) | **Do not name it at all.** Define `ptrade` directly as `σ/(σ + φ·√(2/Δt))`. Avoiding the identifier avoids the clash and satisfies the no-interpretive-names rule by construction. |

Secondary, lower-risk: MMR's `FEE` (arbitrageur fee payments) is a *different*
object from `λ_FLAIR` (all traded-flow fee over capital, which includes noise
traders). Do not conflate them in the doc; the honest relation is that MMR's
`FEE` is the arb-only sub-flow, and the LP-P&L bridge (§F6) uses `λ_FLAIR` in
the `NT_FEE` slot with that caveat stated. MMR's `σ` is the GBM volatility and
maps cleanly onto the doc's `σ(i(t))` / `σpath` — **the same σ_t enters both
`multiFee(σ_t)` and the `ptrade` denominator**, which is a genuine and
non-obvious composition (see F3).

### F3 — The fee-dependence composition (CONTEXT Q2). Confidence: HIGH

Per-step kernel, with `c_t ≜ √(2/Δt)/σ_t > 0`:

```
  g(σ_t, φ)  =  ptrade φ σ_t Δt  =  1 / (1 + c_t·φ)  =  σ_t / (σ_t + φ·√(2/Δt))
```

Properties, all elementary and provable:

- **Antitone in φ, strictly**, on `[0,∞)`: `∂g/∂φ = −c_t/(1+c_tφ)² < 0`. ✅
  CONTEXT's core premise is CONFIRMED: the per-step term is antitone in the fee
  **pointwise**, so `inf` over the level box sits at the level corner TOP — the
  **same corner as `sup λ_FLAIR`**.
- **Strictly convex in φ**: `∂²g/∂φ² = 2c_t²/(1+c_tφ)³ > 0`. This is where the
  FLAIR mirror breaks (see F4) and where the constrained program gets its teeth
  (see F6).
- **Bounded**: `g ∈ (0, 1]`, `g = 1 ⟺ φ = 0` (zero fee ⟹ ARB = LVR), `g → 0` as
  `φ → ∞` (the infimum's saturation boundary).
- **Isotone in `Δt`**: larger mean interblock time ⟹ larger `g`. Formalizes
  MMR §7.1 ("faster blockchains reduce LP losses") and the multi-block-MEV
  censoring incentive.
- **Also isotone in `σ_t`** at fixed φ: higher realized vol ⟹ more blocks carry
  a profitable trade. Worth stating; it interacts with `multiFee`'s own
  σ-monotonicity in opposite directions, which is exactly why the σ-responsive
  schedule is *not* obviously good (F6).
- **Bridge to existing machinery (optional, cheap):** for `c_tφ > 0`,
  `ptrade φ σ Δt = FeeSchedule.logistic (−Real.log (c_t·φ))`. Reuses a proven
  project definition, in the spirit that the FLAIR prompt rewarded.

**Correction to the phase brief.** CONTEXT Q3 hypothesizes the per-step term
might be "a nonlinear (e.g. `max(gap − fee, 0)`) function … convex
piecewise-linear in the fee?". **It is not.** The no-trade-band threshold is
*integrated out* by Theorem 1's stationary distribution; what survives is the
smooth rational function above. `max(·,0)` appears only inside the *pre-*
stationary per-arrival profit `A±(P,z)` via the indicators `I{z>+γ}`,
`I{z<−γ}`, which the ergodic average replaces. Formalizing the pathwise
`max(gap−fee,0)` form would be a **different, harder, and unanchored** object —
do not do it.

**Exact-CPMM caveat (a real, provable non-monotonicity).** If the plan uses the
Corollary-2 exact kernel rather than the leading-order one, the `e^{+φ/2}`
factor fights `P_trade`. With `f(φ) = e^{φ/2}/(1+cφ)`:
`f′ < 0 ⟺ φ < 2 − 1/c`. So **strict antitonicity of the exact CPMM kernel needs
a hypothesis**. A clean sufficient one for Lean: `σ_t ≤ √(2/Δt)` (⟺ `σ_t²Δt ≤ 2`)
together with `φ ≤ 1`. Note `σ_t²Δt ≤ 2` is strictly stronger than the paper's
own finiteness condition `σ_t²Δt < 8`. Pre-empt this: it is exactly the kind of
missing hypothesis Aristotle has caught twice (`deltaQM_nonneg` needed `Δi ≥ 0`;
`flairMulti_strict_below_saturation` needed `uMax>0 ∧ αmax0>0`).

### F4 — The Lean mirror: what carries, what breaks (CONTEXT Q3). Confidence: HIGH

`FlairOptimization.lean` (439 lines, 15 theorems, all axiom-clean) is the
template. Mapping:

| FLAIR structure | MEV mirror | Carries? |
|---|---|---|
| `flairHazard φfun σpath w D T = Σ_t φ(σ_t)·w_t/D_t` | `mevHazard φfun σpath a D Δt T = Σ_t ptrade(φ(σ_t)) σ_t Δt · a_t/D_t` | ✅ identical shape; only `φ` ↦ `ptrade∘φ` and `w` ↦ `a` |
| `w_t ≥ 0` traded-flow weight | `a_t ≥ 0` **arb-opportunity weight** = the per-step LVR | ✅ same role; CONTEXT correctly anticipated the positivity hypothesis |
| `D_t > 0` deployed capital | same `D_t > 0` | ✅ unchanged |
| `capitalDenominator_pos` (thin instantiation `D = QM·(p+1)`) | thin instantiation `a_t = (σ_t²/8)·V_t` (CPMM LVR, Corollary 2) | ✅ direct mirror, plus the `σ_t²Δt < 8` guard |
| **`flairMulti_affine`** — the exact affine identification `λ = φ̄W + uΣα_jW_j` | ❌ **NO MIRROR.** `ptrade` is not affine, so λ_MEV does **not** decompose into `pathWeight`/`shapeWeight` | ❌ **THIS IS WHERE THE MIRROR BREAKS** |
| `_mono_phibar` / `_mono_alpha` / `_mono_u` (isotone) | `_anti_phibar` (strict) / `_anti_alpha` / `_anti_u` — **inequalities reversed** | ✅ by `ptrade` antitone ∘ `multiFee` isotone |
| `_anti_beta` (antitone in β) | `_mono_beta` (**isotone** in β) | ✅ reversed |
| `W_j_le_W`, `W_j_lt_W` (0 ≤ W_j < W) | no direct mirror (no shapeWeight); replaced by `multiFee_bounds` (already PROVEN in `VolInstrument`) + `ptrade` antitone | ⚠️ substitute |
| `flairMulti_le_corner` — closed-form uniform bound `(φ̄max+umaxΣαmax)·W` | uniform **lower** bound `Σ_t ptrade(φ̄max+umaxΣαmax) σ_t Δt · a_t/D_t` — a sum, **not** a scalar × pathWeight | ⚠️ mirrors but does **not** collapse to a product |
| `_corner_attained_levels` (bang-bang at level corner) | ✅ direct mirror, reversed | ✅ |
| `_saturation_limit` (β→−∞ `Tendsto` to the bound) | ✅ direct mirror; needs `ptrade` continuity + `Tendsto` composition | ✅ |
| `_strict_below_saturation` (strict gap at finite β) | `_strict_above_saturation` | ✅ reversed |
| `_exists_max_compact` (`IsCompact.exists_isMaxOn`) | `_exists_min_compact` (**`IsCompact.exists_isMinOn`**, Mathlib `Mathlib/Topology/Order/Compact.lean:228` — verified present at v4.28.0) | ✅ |
| `Theta_lambda_identification` | `Theta_lambdaMEV_identification` | ✅ |

**The structural replacement for affineness is convexity.** Mathlib has
`strictConvexOn_zpow` (`Analysis/Convex/SpecificFunctions/Deriv.lean:99`) for
`x ↦ x^(-1)` on `Ioi 0`, and `ConvexOn.comp_affineMap`
(`Analysis/Convex/Function.lean:937`) to precompose with `φ ↦ σ_t + φ√(2/Δt)`.
That yields `ConvexOn ℝ (Ici 0) (ptrade · σ_t Δt)` — the ingredient for F6.
**Convexity is NOT needed for the corner result** (monotonicity alone gives it),
so plan it as a separate, lower-risk theorem, not a dependency.

### F5 — The unconstrained joint program is DEGENERATE (CONTEXT Q4). Confidence: HIGH

Chain of already-established facts:

1. `flairMulti` is isotone in (φ̄, α, u) and **antitone in β**
   (`flairMulti_anti_beta`, PROVEN); its sup is at the level corner and
   approached as **β → −∞** (`flairMulti_saturation_limit`, PROVEN).
2. `multiFee` is isotone in (φ̄, α, u) and antitone in β (same logistic
   argument).
3. `ptrade` is antitone in the fee (F3).
4. ⟹ `mevMulti` is **antitone in (φ̄, α, u)** and **isotone in β**; its inf is
   at the level corner and approached as **β → −∞**.

**Therefore `argsup λ_FLAIR = arginf λ_MEV` at EVERY coordinate of Θ_φ, not
just the level block.** CONTEXT's item 2 second half — "the shape block (β, γ)
becomes ESSENTIAL rather than reallocation-only" — is **REFUTED for the
functional as stated**. `γ_j` is inert in both objectives at the β→−∞ boundary
(logistic → 1 for any γ_j > 0), exactly as in FLAIR.

Stronger and worth stating: for **any** scalarization weight `κ ≥ 0`,
`sup (λ_FLAIR − κ·λ_MEV)` is *also* at the same point. The degeneracy is robust
to linear scalarization — you cannot repair it by weighting.

This is a legitimate, reportable, honest-null-flavoured terminal result, fully
in the spirit of Phase 10's culture. **The plan must be prepared to land it as
the answer, and must NOT let the doc addendum promise a trade-off that the math
does not deliver.**

### F6 — Where the trade-off actually lives: the CONSTRAINED program (the headline). Confidence: HIGH

Write `μ_t ≜ a_t/D_t ≥ 0`, `A ≜ Σ_t μ_t`, `ν_t ≜ w_t/D_t ≥ 0`, `W ≜ Σ_t ν_t`.

- `λ_FLAIR = Σ_t φ(σ_t)·ν_t` — **linear** in the fee path, pins its ν-weighted
  **mean**.
- `λ_MEV   = Σ_t h_t(φ(σ_t))·μ_t` with `h_t = ptrade(·) σ_t Δt` **strictly
  convex**.

**Theorem (the Jensen result).** In the aligned-measure case `a ≡ w` (so
`μ = ν`), subject to a fixed fee budget `λ_FLAIR = B`:

```
  λ_MEV  ≥  A · h( B / A )      with equality  ⟺  φ(σ_t) is CONSTANT in t
```

i.e. **for a fixed FLAIR fee income, the MEV-minimizing schedule is a FLAT fee**
(`α = 0`, or `u = 0`, with `φ̄ = B/W`), and **every volatility-responsive
sigmoid schedule delivering the same fee income is strictly worse for MEV.**
(Strictness needs `φ` non-constant on a positive-μ set, `h` strictly convex.)

This is sharp, attained, non-degenerate, economically meaningful, and exactly
the place where the shape block `(β, γ)` becomes essential in the way CONTEXT
hoped — but only *under the constraint*. It also has the right smell for the
two-reviewer gate: it is a claim that could be wrong, and it is checkable.

**Honest generalization gap:** when `a ≢ w` (LVR weights ≠ traded-flow weights —
the realistic case, since noise-trader flow is in `w` but not in `a`) the
single-measure Jensen argument does not close, and the answer becomes a
two-measure covariance statement. **Record this as an OPEN sub-question rather
than papering over it**; the aligned case is the theorem, the misaligned case is
the conjecture.

**The demand-elasticity caveat, now pinned to a citation rather than restated
vaguely.** Both functionals are volume-inelastic. MMR §7.3 eq. (27) gives the
exact missing term: `E[delta-hedged LP P&L] = E[NT_FEE] − E[ARB]`, with
"higher fees reduce noise trader activity (decreasing `E[NT_FEE]`) but also
reduce arbitrage profits". So the corner solution is a property of the
formalized objectives, not a market-equilibrium claim — the same caveat
`FlairOptimization.lean`'s module docstring already carries, now with a second,
independent citation. MMR §7.2 + Figure 7 additionally give the *real* frontier
(mispricing `σ_z` vs `ARB`), which our pair does not capture.

### F7 — Angstrom bridge, statement level (CONTEXT Q5). Confidence: MEDIUM-HIGH on structure, MEDIUM on constants

Two thin, provable statement families, both about parameters **outside Θ_φ**:

**(a) The rebate / recycling term.** Angstrom's ToB auction donates the winning
bid `bid = quantity_in − swap_input` to the LP ticks traversed
(`RewardsUpdate`, `GrowthOutsideUpdater.sol`); l2-angstrom implements the same
economics as an on-chain MEV tax on the priority fee. Model as
`mevNet τ ≜ (1 − τ)·mevMulti` with `τ ∈ [0,1]`. Provable, thin:

- `mevNet_le_mev`, `mevNet_antitone_tau`, `mevNet_eq_zero_of_tau_one`.
- **`mevNet_argmin_invariant`** — for every `τ < 1`, the set of minimizers over
  Θ_φ is unchanged (positive scaling preserves minimizers). **This is the
  statement that formalizes "τ is a protocol parameter OUTSIDE Θ_φ": the rebate
  changes the value of the program and not its solution.** Best single lemma in
  this group.
- Parametrize the tax factor: `taxFraction k = k/(k+1)`, with `k = 49` giving
  `τ = 49/50 = 0.98`. **State it parametrically; do NOT hardcode 49/50** — see
  Q3 below, the constants are not stable.

**(b) The batch-cadence clock.** Angstrom = one bundle per block per pair; that
cadence *is* MMR's `Δt`. So the cadence enters the hazard only through
`ptrade`'s `Δt` slot, and the relevant statement is already in the T4 mirror
(`ptrade` isotone in `Δt`). Clean framing: **`Δt` is the second
protocol-controllable parameter outside Θ_φ, and it moves λ_MEV monotonically
without touching λ_FLAIR at all** — unlike the fee, which moves both. That is a
*second*, genuinely non-degenerate lever, and it is the honest answer to "where
does the tension live" alongside F6.

### F8 — The sandwich component: reuse the doc's own hazard algebra. Confidence: HIGH

Angstrom's uniform-clearing batch kills *sandwich/ordering* MEV by construction
(no intra-batch ordering exists to exploit) while CEX-DEX arb (MMR's ARB)
survives and is handled by the ToB auction. The doc already has the right
algebra: `λ ≡ ⊕λ_i` over `{FLAIR, arb toxicity, MEV, …}` with
`VolInstrument.probOr` and the PROVEN `probOr_hazard`
(`(1−e^{−λ_M})⊗(1−e^{−λ_X}) = 1−e^{−(λ_M+λ_X)}`) and **`probOr_zero`**.

So the decomposition statement is nearly free:
`λ_MEV = λ_ARB + λ_sandwich`, and under batch/uniform clearing
`λ_sandwich = 0` ⟹ `λ_MEV = λ_ARB` — discharged by `probOr_zero` /
`add_zero` on already-proven machinery. Cite Theory of MEV I (2207.11835,
`KulkarniDiamandisChitraTheoryMEV1.pdf`) as the source for the sandwich
component being a *distinct* MEV channel; do **not** attempt to formalize
sandwich profit shapes in this phase.

---

## Standard Stack

### Core (no packages to install — this is a proof phase)

| Component | Version | Purpose | Why standard |
|---|---|---|---|
| Lean 4 | `leanprover/lean4:v4.28.0` | proof assistant | pinned in `lean/lean-toolchain`; **the toolchain all canonical Aristotle runs were proven under** (`lean/README.md`) |
| Mathlib4 | tag `v4.28.0`, rev `8f9d9cff6bd728b17a24e163c9402775d9e6a365` | analysis/topology/convexity | pinned in `lean/lakefile.toml`; changing it is a re-verification event |
| Aristotle CLI | `~/.local/bin/aristotle` (aristotlelib 2.1.0) | **the prover** — authors proofs from the doc | binding workflow rule; API key in worktree `.env`, passed via `--api-key` |
| `pdftotext -layout` | poppler | reading the anchor PDF | already used for this research; reproducible |

### Mathlib lemmas the new module will lean on (all verified present at v4.28.0)

| Lemma | Path | Use |
|---|---|---|
| `IsCompact.exists_isMinOn` | `Mathlib/Topology/Order/Compact.lean:228` | T14 compact minimizer existence (mirror of FLAIR's `exists_isMaxOn`) |
| `strictConvexOn_zpow` | `Mathlib/Analysis/Convex/SpecificFunctions/Deriv.lean:99` | `x ↦ x⁻¹` strictly convex on `Ioi 0` → `ptrade` convexity |
| `ConvexOn.comp_affineMap` | `Mathlib/Analysis/Convex/Function.lean:937` | precompose with `φ ↦ σ + φ√(2/Δt)` |
| `one_div_le_one_div_of_le` | `Mathlib/Algebra/Order/Field/Basic.lean:69` | the antitone core of `ptrade` |
| `Real.sqrt`, `Real.sq_sqrt`, `Real.sqrt_pos` | Mathlib | `√(2/Δt)` |
| `Finset.sum_le_sum`, `sum_lt_sum`, `sum_pos'`, `sum_nonneg` | Mathlib | every mirror of a FLAIR sum argument |
| `tendsto_finset_sum`, `Filter.Tendsto.const_mul`, `Filter.Tendsto.comp` | Mathlib | T13 β→−∞ saturation |
| `inner_le_nnorm…` / `inner_mul_le_norm_mul_norm` — **not needed** | — | Jensen route below is elementary, avoid heavy machinery |

For F6's Jensen step, `ConvexOn.inner_smul_le_norm_mul_norm` is the wrong tool.
Use `ConvexOn.smul_le_sum` / `inner_le_weight_mul_Lp_of_norm_le` family —
concretely, `ConvexOn.map_centerMass_le` or the finite-sum Jensen
`ConvexOn.map_sum_le` (Mathlib, `Analysis/Convex/Jensen.lean`). **Flag for the
planner: confirm the exact Jensen lemma name at bundle-build time by grepping
`.lake/packages/mathlib/Mathlib/Analysis/Convex/Jensen.lean`** — I did not
verify that file, so this row is MEDIUM confidence.

### Project modules to reuse (do NOT redefine — the FLAIR prompt's rule)

| Module | Reuse |
|---|---|
| `VolInstrument.multiFee`, `multiFee_bounds`, `multiFee_monotone` | the fee `φ(σ_t)` over Θ_φ; bounds give `0 ≤ φ ≤ φ̄+uΣα` for free |
| `VolInstrument.probOr*` (`_zero`, `_hazard`) | F8 sandwich decomposition |
| `FeeSchedule.logistic` + `_mem_Ioo`, `_strictMono`, `_tendsto_atTop/atBot` | inside `multiFee`; also the optional `ptrade_eq_logistic_neg_log` bridge |
| `FlairOptimization.flairMulti`, `pathWeight`, `flairMulti_affine`, `_le_corner`, `_saturation_limit` | **all of F5/F6's joint theorems import these** — the joint module must `import vol_markets.FlairOptimization` |

### Alternatives considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| Leading-order kernel `lvr·P_trade` (Thm 3, eq. 12) | Exact CPMM kernel (Cor. 2) with `e^{φ/2}` and `1/(1−σ²Δt/8)` | Exact is fully closed-form but needs `σ²Δt < 8` AND loses unconditional antitonicity (F3). **Recommend: leading-order as the primary functional, exact as a second-tier instantiation lemma.** |
| `Δt` as primitive | `λ_blk` as primitive with a renamed identifier | `Δt` is MMR's own symbol and dodges the λ collision; a renamed `λ_blk` invents notation, violating the binding rule |
| Free abstract weight `a_t` | CPMM-derived `a_t = (σ_t²/8)V_t` | Free `a_t` mirrors `flairHazard`'s free `w_t` exactly (maximum structural fidelity); CPMM version is the thin instantiation. **Do both, abstract first.** |
| New module `MevOptimization.lean` | Extend `FlairOptimization.lean` | CONTEXT binds: "new `lean/vol_markets/` module beside `FlairOptimization.lean`". Also: never modify a file Aristotle has already proven — every prior run's prompt says "Do NOT modify any of the N existing .lean files". |

**Module registration:** the new root must be added to `lean/lakefile.toml`
`[[lean_lib]] name = "vol_markets"` `roots = [...]`. Missing this is a silent
no-build.

---

## Architecture Patterns

### Recommended file layout

```
lean/vol_markets/
├── FlairOptimization.lean      # existing, UNTOUCHED
└── MevOptimization.lean        # NEW — ptrade, mevHazard, mevMulti, inf program, joint theorems
model/vol_markets/
└── LEAN_TRACEABILITY.md        # §0 notation rows + §7 claim rows; §6 "MEV section" flipped
.planning/phases/11-mev-hazard-inf-program/
└── 11-XX-MEV-ADDENDUM.md       # doc-addendum record (precedent: commit 489bb43 VOLATILITY_INSTRUMENTS_LEAN_ADDENDUM.md)
scratch/aristotle-mev/          # submission bundle (see P2)
scratch/aristotle-mev-PROMPT.txt
```

Naming: the doc's own symbol is `λ_MEV`, so the module name `MevOptimization`
mirrors `FlairOptimization` — a structural mirror, not an interpretive name.

### P1 — The discrete-functional mirror

**What:** `mevHazard` must be byte-shaped like `flairHazard` so a reader can
diff the two files.

```lean
/-- The fraction of blocks presenting a profitable arbitrage
(Milionis–Moallemi–Roughgarden, arXiv:2305.14604, Theorem 1), with the
paper's fee `γ` written as the document's `φ` and its Poisson rate `λ`
written through the mean interblock time `Δt ≜ λ⁻¹`.  The paper's composite
parameter is deliberately not named: `η` is reserved project-wide for the
pricing kernel. -/
noncomputable def ptrade (φ σ Δt : ℝ) : ℝ :=
  σ / (σ + φ * Real.sqrt (2 / Δt))

/-- The discrete λ_MEV hazard functional.  `a t ≥ 0` is the per-step
arbitrage-opportunity weight (the leading-order LVR of eq. (12)); `D t > 0`
is deployed capital — the same denominator as `flairHazard`. -/
noncomputable def mevHazard (φfun : ℝ → ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) : ℝ :=
  ∑ t ∈ Finset.range T, ptrade (φfun (σpath t)) (σpath t) Δt * a t / D t

/-- λ_MEV specialized to the project's multi-sigmoid fee — the SAME Θ_φ. -/
noncomputable def mevMulti (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) : ℝ :=
  mevHazard (VolInstrument.multiFee n γ β α φbar u) σpath a D Δt T
```

**When:** always — this is the phase's definitional spine and the thing the
doc addendum must state in LaTeX first.

### P2 — The Aristotle submission bundle (reproduce the FLAIR run exactly)

The FLAIR run (`scratch/aristotle-flair/`, commit 6914fba) is the working
template. Layout — reproduce it byte-for-byte in structure:

```
scratch/aristotle-mev/
├── lean-toolchain          # leanprover/lean4:v4.28.0
├── lakefile.toml           # name="RequestProject", require mathlib rev=v4.28.0,
│                           # [[lean_lib]] name="RequestProject" srcDir="." globs=["RequestProject.+"]
├── lake-manifest.json      # copied from lean/lake-manifest.json
└── RequestProject/
    ├── VOLATILITY_INSTRUMENTS.md   # the DOC — WITH the approved ### MEV block
    ├── PosSpec.lean  Flow.lean  RiskDesign.lean  Main.lean
    ├── Panoptic.lean  Upsilon.lean  GeomProfile.lean  FeeSchedule.lean
    ├── VolInstrument.lean
    └── FlairOptimization.lean      # ← NEW vs the FLAIR bundle (10 files, not 9)
```

Submit with `aristotle submit --project-dir scratch/aristotle-mev --api-key …`.
On COMPLETE: `aristotle download --destination scratch/mev-result`, then copy
`MevOptimization.lean` into `lean/vol_markets/` applying the
`RequestProject.` → `vol_markets.` import rewrite (established integration
rule, 08-05-SUMMARY / 09-06-PLAN).

**Prompt shape** (from `scratch/aristotle-flair-PROMPT.txt`, which produced 15
axiom-clean theorems in one run — copy its skeleton):
1. One-line imperative: "FORMALIZE AND SOLVE … in a NEW file
   `RequestProject/MevOptimization.lean`. You author both statements and
   complete proofs: no `sorry`, no `admit`, axiom-clean (only `propext`,
   `Classical.choice`, `Quot.sound`). Do NOT modify any of the 10 existing
   .lean files."
2. Quote the doc's definition + claim verbatim.
3. Section (A) the definitions to introduce, with **exact Lean signatures**.
4. Section (B) the identification theorems, **numbered**, each with its
   hypotheses spelled out.
5. Section (C) the solved optimization, numbered, with the corner /
   saturation / compactness split.
6. A docstring-caveat paragraph (the demand-elasticity + leading-order
   caveats).
7. A build requirement paragraph naming the modules to reuse and not redefine.

### P3 — Wave structure (the plan's shape)

The serial-Aristotle constraint makes wave design nearly forced:

```
Wave 0  CTX-MEVDOC   Draft the ### MEV LaTeX block → two-reviewer gate → USER APPROVAL
                     (nothing else can start; the doc IS the Aristotle input)
Wave 1  CTX-PTRADE + CTX-MEVHAZ + CTX-INF  →  ONE Aristotle submission (bundle A)
Wave 2  CTX-JOINT + CTX-ANGSTROM           →  ONE Aristotle submission (bundle B),
                                              only after bundle A has landed + lake build green
Wave 3  CTX-TRACE   traceability rows, doc "LEAN (proved)" back-annotation, close-out
```

Splitting into two bundles (rather than one) is a judgement call: bundle A is
the FLAIR-mirror (high prior of success, ~15 theorems, precedent exists);
bundle B is the novel content (degeneracy + Jensen + Angstrom, ~9 theorems, no
precedent). If A fails or returns weakened statements, B's premises change.
**Do not parallelize the two — the queue is strictly serial (memory
`aristotle-no-queue`).**

### Anti-patterns to avoid

- **Hand-writing proofs locally.** Binding rule (memory
  `lean-aristotle-heavy-workflow`): draft `sorry`'d statements at most, send the
  DOC to Aristotle. Phase 08 was mid-flight overridden by the user for exactly
  this.
- **Editing `FlairOptimization.lean` or any of the 9 proven modules.** Every
  prior prompt forbids it and every prior integration verified byte-identity of
  the untouched files.
- **Naming the composite parameter `η`.** Project-reserved. See F2.
- **Writing `λ` for the block rate anywhere in the doc or Lean.** See F2.
- **Asserting the shape block is essential.** Refuted unconstrained; true only
  under the fee-budget constraint. See F5/F6.
- **Hardcoding `49/50`.** The constants moved between the repo snapshot and the
  live docs. See Q3.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Proofs of the ~24 theorems | local tactic proofs | **Aristotle**, doc-driven, strictly serial | binding workflow rule; four prior runs (geom-fee, vol-instrument, flair, upsilon) all landed axiom-clean |
| Compact-set optimizer existence | ε-argument by hand | `IsCompact.exists_isMinOn` (+ `FeeSchedule.exists_optimal_params` as the generic interface) | FLAIR's `_exists_max_compact` does exactly this; verified present at v4.28.0 |
| Convexity of `x ↦ 1/x` | derivative computation | `strictConvexOn_zpow` + `ConvexOn.comp_affineMap` | already in Mathlib; hand-rolling invites a heartbeat blowup |
| Hazard composition `λ_ARB ⊕ λ_sandwich` | a new monoid | `VolInstrument.probOr` + `probOr_zero` + `probOr_hazard` (**already PROVEN**) | LEAN_TRACEABILITY §7 lists these as PROVEN; the doc's own `⊗_φ` |
| The sigmoid fee | a new fee model | `VolInstrument.multiFee` + `multiFee_bounds`/`_monotone` | the phase's whole point is the SAME Θ_φ |
| The path-weight/capital denominator | a new denominator | reuse `D t > 0` and `capitalDenominator_pos`'s pattern | keeps λ_FLAIR and λ_MEV commensurable — required for F5/F6 |
| Recording the doc edit | editing plank's file from this session | write the addendum record HERE and hand off | **plank's `notes/VOLATILITY_INSTRUMENTS.md` is owned by agent `ul2inqpl`** (CLAUDE.md ownership map); precedent commit 489bb43 wrote `VOLATILITY_INSTRUMENTS_LEAN_ADDENDUM.md` in *this* tree and left a handoff note in plank's `todo.md` |
| Reading the anchor paper | web summaries of 2305.14604 | the local PDF + `pdftotext -layout` | v2 (Jul 2025) differs from the widely-summarized v1 (Feb 2023); Theorem numbering and the Nezlobin–Tassy discussion are v2-only |

**Key insight:** every nonlinearity in this phase is a single one-variable
rational function. Everything else is a reversed copy of a file that already
exists and is already proven. The risk is *not* mathematical difficulty — it is
notation collision (F2), an over-promised doc claim (F5), and workflow
violations (serial queue, file ownership).

---

## Common Pitfalls

### PIT-1: Naming the composite parameter `η`
**What goes wrong:** MMR's `η ≜ γ√(2λ)/σ` is transcribed as `η` into the doc
and/or Lean, silently colliding with the project-reserved pricing-kernel `η`
(`VolInstrument.priceEta`, `model/exp/eta.md`).
**Why:** it is the paper's own symbol, and the notation rule says "identifiers
from the doc's symbols" — which *sounds* like it mandates `η`.
**How to avoid:** LEAN_TRACEABILITY §0 explicitly overrides: `η` "is never
reused", and the fee paper's `η⁰/η¹` were already mapped to Latin names
(`cexFee`, `fHalt`). Best fix: **do not introduce the composite at all** —
define `ptrade` directly.
**Warning sign:** the string `η` appearing anywhere in the new module other
than an existing `priceEta` reference.

### PIT-2: `λ` used for the block rate
**What goes wrong:** the doc's hazard `λ` and MMR's Poisson rate `λ` are the
same glyph in adjacent equations; the addendum becomes unreadable and Aristotle
formalizes the wrong thing.
**How to avoid:** parametrize by `Δt ≜ λ⁻¹` everywhere (MMR's own symbol, used
throughout their §5–§7 and all their tables).
**Warning sign:** `λ` on both sides of a `≜` in the addendum.

### PIT-3: `γ` used for the fee
**What goes wrong:** MMR's fee `γ` is transcribed into a doc where `γ_j` is
already the sigmoid steepness of `Θ_φ`. Aristotle then plausibly writes
`ptrade (γ j) …` and the module is silently nonsense.
**How to avoid:** substitute `φ` for MMR's `γ` in every transcribed formula, and
say so explicitly in one line of the addendum ("the paper's fee `γ` is this
document's `φ`; this document's `γ_j` is the sigmoid steepness").
**Warning sign:** any occurrence of `γ` in the addendum's MEV block that is not
subscripted `γ_j`.

### PIT-4: Missing hypotheses Aristotle will (correctly) add
**What goes wrong:** the statement as drafted is false; Aristotle strengthens
the hypotheses and the returned theorem no longer says what the doc claims.
**Precedent, twice:** `deltaQM_nonneg` needed `Δi ≥ 0` in addition to `η·Δi>0`
("Aristotle-caught", LEAN_TRACEABILITY §7); `flairMulti_strict_below_saturation`
needed `uMax > 0 ∧ αmax0 > 0` ("mathematically necessary — the claim is false if
u=0 or α=0").
**Pre-empt with this checklist in the prompt:** `σpath t > 0` for `t < T` (GBM
volatility; also `ptrade`'s denominator); `Δt > 0`; `φ ≥ 0` (from `φbar ≥ 0`,
`α_j ≥ 0`, `u ≥ 0`); `a t ≥ 0` with `∃ t₀ < T, 0 < a t₀` for every *strict*
claim; `D t > 0`; for the CPMM instantiation `σ_t²·Δt < 8` (MMR's own finiteness
condition); for the exact-kernel antitonicity `σ_t²·Δt ≤ 2` and `φ ≤ 1` (F3).
**Warning sign:** a returned theorem whose hypothesis list is shorter than this.

### PIT-5: Claiming the mirror where it breaks
**What goes wrong:** the addendum asserts an affine identification
`λ_MEV = …·A + …·Σα_j A_j` by analogy with `flairMulti_affine`. **No such
decomposition exists** — `ptrade` is not affine, so the fee's level and shape do
not separate.
**How to avoid:** state the identification as a *monotonicity block* +
*convexity*, not as an affine formula. The uniform lower bound is a **sum**
`Σ_t ptrade(φ_max) σ_t Δt · a_t/D_t`, not a scalar × pathWeight.
**Warning sign:** an addendum equation of the form `λ_MEV = c₀·A + c₁·ΣA_j`.

### PIT-6: Over-promising the trade-off
**What goes wrong:** the addendum states "(β,γ) becomes essential", the
reviewers pass it, Aristotle proves the opposite, and the doc has to be
retracted after user approval was already spent.
**How to avoid:** the addendum must state the **degeneracy** result and the
**constrained** result as two separate claims (F5, F6). Do not merge them.
**Warning sign:** any addendum sentence asserting a trade-off in Θ_φ without a
constraint in the same sentence.

### PIT-7: Skipping the two-reviewer gate on the Aristotle prompt
**What goes wrong:** the gate is run on the plan but not on the *prompt*, which
is the actual specification Aristotle formalizes.
**How to avoid:** treat `scratch/aristotle-mev-PROMPT.txt` as a spec artifact:
Reality Checker + one specialist, severity-sorted, BLOCKERs resolved, *before*
submit. Recommended specialist for this phase: a **quantitative-finance /
market-microstructure** reviewer (the risk is economic misstatement of ARB/LVR
and of what the Angstrom mechanism does, not Lean syntax).

### PIT-8: Bundle missing toolchain/manifest
**What goes wrong:** submitting only `.lean` files; Aristotle can't reproduce
the Mathlib environment.
**How to avoid:** the P2 layout — `lakefile.toml` + `lean-toolchain` +
`lake-manifest.json` + `RequestProject/`, passed whole via `--project-dir`. Pin
`v4.28.0` on **both** toolchain and Mathlib. (Carried forward from
`08-RESEARCH.md` Pitfall 4.)

### PIT-9: Parallel/queued Aristotle calls
**What goes wrong:** a second `continue --files`/`submit` overwrites the
in-flight task's server-side proof.
**How to avoid:** strictly serial; poll `aristotle tasks` every ~5 min; submit
bundle B only after A's proof has landed locally AND `lake build` is green.
Queue is currently **FREE** (memory `aristotle-flair-inflight` → RESOLVED).

### PIT-10: Editing plank's file directly
**What goes wrong:** this session edits
`../plank/notes/VOLATILITY_INSTRUMENTS.md`, colliding with agent `ul2inqpl`.
**How to avoid:** write the addendum record in this tree; hand off via
`claude-peers send_message` to `ul2inqpl` and a note in plank's `todo.md`
`## LEAN4 - MATH`. Precedent: commit 489bb43.

---

## Code Examples

### The `ptrade` kernel and its core lemma shapes (draft signatures for the prompt)

```lean
/-- MMR Theorem 1: the steady-state fraction of blocks carrying a profitable
arbitrage.  `φ` is the fee, `σ` the GBM volatility, `Δt ≜ λ⁻¹` the mean
interblock time. -/
noncomputable def ptrade (φ σ Δt : ℝ) : ℝ := σ / (σ + φ * Real.sqrt (2 / Δt))

lemma ptrade_mem_Ioc (φ σ Δt : ℝ) (hφ : 0 ≤ φ) (hσ : 0 < σ) (hΔ : 0 < Δt) :
    ptrade φ σ Δt ∈ Set.Ioc (0 : ℝ) 1

lemma ptrade_eq_one_iff (φ σ Δt : ℝ) (hφ : 0 ≤ φ) (hσ : 0 < σ) (hΔ : 0 < Δt) :
    ptrade φ σ Δt = 1 ↔ φ = 0                     -- zero fee ⟹ ARB = LVR

lemma ptrade_strictAnti (σ Δt : ℝ) (hσ : 0 < σ) (hΔ : 0 < Δt) :
    StrictAntiOn (fun φ => ptrade φ σ Δt) (Set.Ici 0)   -- THE fee-decreasing claim

lemma ptrade_convexOn (σ Δt : ℝ) (hσ : 0 < σ) (hΔ : 0 < Δt) :
    ConvexOn ℝ (Set.Ici 0) (fun φ => ptrade φ σ Δt)     -- the structural replacement for affineness

lemma ptrade_mono_Δt (φ σ : ℝ) (hφ : 0 ≤ φ) (hσ : 0 < σ) :
    MonotoneOn (fun Δt => ptrade φ σ Δt) (Set.Ioi 0)    -- MMR §7.1: faster chains ⟹ less arb

lemma ptrade_tendsto_atTop (σ Δt : ℝ) (hσ : 0 < σ) (hΔ : 0 < Δt) :
    Filter.Tendsto (fun φ => ptrade φ σ Δt) Filter.atTop (𝓝 0)
```

### The MMR split, as a definitional bridge (thin but it anchors the doc)

```lean
/-- MMR eq. (12) + Theorem 4: LVR splits into arbitrageur profit and
arbitrageur-paid fees according to `ptrade`. -/
lemma arb_add_fee_eq_lvr (lvr φ σ Δt : ℝ) :
    lvr * ptrade φ σ Δt + lvr * (1 - ptrade φ σ Δt) = lvr := by ring
```

### The degeneracy theorem (F5) — the shape the joint statement should take

```lean
/-- THE JOINT PROGRAM IS DEGENERATE ON Θ_φ: one admissible point simultaneously
maximizes λ_FLAIR and minimizes λ_MEV. -/
theorem joint_corner_degeneracy
    (n : ℕ) (γ β α αmax : ℕ → ℝ) (φbar φbarMax u uMax Δt : ℝ)
    (σpath w a D : ℕ → ℝ) (T : ℕ)
    (hφ : φbar ≤ φbarMax) (hu0 : 0 ≤ u) (hu : u ≤ uMax)
    (hα0 : ∀ j < n, 0 ≤ α j) (hα : ∀ j < n, α j ≤ αmax j)
    (hσ : ∀ t < T, 0 < σpath t) (hΔ : 0 < Δt)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) (ha : ∀ t < T, 0 ≤ a t) :
    FlairOptimization.flairMulti n γ β α φbar u σpath w D T ≤
      FlairOptimization.flairMulti n γ β αmax φbarMax uMax σpath w D T ∧
    mevMulti n γ β αmax φbarMax uMax σpath a D Δt T ≤
      mevMulti n γ β α φbar u σpath a D Δt T
```

### The constrained/Jensen theorem (F6) — the non-degenerate content

```lean
/-- Subject to a fixed FLAIR fee budget, a CONSTANT fee minimizes λ_MEV, and
any non-constant (volatility-responsive) schedule with the same budget is
strictly worse.  Aligned-measure case `a ≡ w`. -/
theorem mev_ge_flat_under_flair_budget
    (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) (B : ℝ)
    (hbudget : FlairOptimization.flairHazard φfun σpath w D T = B)
    (hσconst : ∀ t < T, σpath t = σ0)          -- the aligned/uniform-σ instance
    … :
    FlairOptimization.pathWeight w D T * ptrade (B / FlairOptimization.pathWeight w D T) σ0 Δt
      ≤ mevHazard φfun σpath w D Δt T
```

*(The `hσconst` restriction is one honest way to keep the Jensen step
one-measure; the general statement needs `h_t` to be the same convex function
at every `t`, i.e. `σ_t` constant, OR a two-measure argument. **Flag this to the
planner: the fully general σ-varying Jensen statement is the phase's main
mathematical risk item.**)*

### The Angstrom rebate (F7) — the argmin-invariance lemma

```lean
noncomputable def mevNet (τ : ℝ) (…) : ℝ := (1 - τ) * mevMulti …

/-- `k = SWAP_MEV_TAX_FACTOR`; the l2-angstrom snapshot has `k = 49`, τ = 49/50. -/
noncomputable def taxFraction (k : ℝ) : ℝ := k / (k + 1)

/-- The rebate is OUTSIDE Θ_φ: for any τ < 1 it rescales the objective without
moving its minimizers. -/
theorem mevNet_argmin_invariant (τ : ℝ) (hτ : τ < 1) (Θ : Set _) (θ : _) :
    IsMinOn (fun θ => mevNet τ …) Θ θ ↔ IsMinOn (fun θ => mevMulti …) Θ θ
```

### Reproducing the anchor extraction (for the plan's evidence trail)

```bash
pdftotext -layout \
  ../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf \
  /tmp/mmr.txt
grep -n "Theorem \|Corollary \|Assumption " /tmp/mmr.txt
```

---

## State of the Art

| Old approach | Current approach | When changed | Impact |
|---|---|---|---|
| LVR (Milionis et al. 2022) — frictionless, no fee | ARB with fees + discrete Poisson blocks; `ARB ≈ LVR·P_trade` | 2305.14604 v1 Feb 2023, **v2 23 Jul 2025** | LVR alone is the γ→0 upper bound; using it as λ_MEV would make the functional fee-INDEPENDENT and the whole phase vacuous |
| "fees ⟹ zero arb profit in continuous time" (Evans et al. 2021) | that is a degenerate artifact of continuous monitoring; discreteness is essential | 2305.14604 §1 | justifies the DISCRETE functional — the same reason `flairHazard` is a `Finset.range` sum |
| Poisson-only block times | Nezlobin–Tassy 2025 handle general block-time distributions; **ARB is minimized by DETERMINISTIC arrivals** among fixed-mean distributions | cited in 2305.14604 v2 §1.4 | a *third* protocol lever outside Θ_φ (arrival-time regularity); worth one sentence in the doc, out of scope to formalize |
| theoretical `√Δt` decay | empirically validated by Fritsch–Canidio 2024, with a documented breakdown below 1 s block times | 2305.14604 v2 §7.1 | bounds the claim: the `Δt` lever is validated at ≥1 s, not sub-second |
| Angstrom repo constants `SWAP_TAXED_GAS = 100_000`, `SWAP_MEV_TAX_FACTOR = 49` | live docs: `TAXED_GAS = 120,000`, a `priorityFeeTaxFloor`, a `jitMEVTaxFactor = 1.5×`, and a three-way creator/protocol/LP split | between the repo snapshot (memory `angstrom-structure`, 2026-07-30) and the current docs | **do not hardcode 49/50** — parametrize `τ` (see Q3) |

**Deprecated / do not use:**
- v1 (Feb 2023) theorem numbering of 2305.14604 — the local PDF is v2 and the
  Nezlobin–Tassy §1.4 discussion and Fritsch–Canidio validation are v2-only.
- The `max(gap − fee, 0)` pathwise formulation of the per-step MEV term
  (hypothesized in the phase brief) — superseded by the ergodic average, see F3.

---

## Open Questions

1. **The σ-varying Jensen statement (F6).** *What we know:* with `σ_t ≡ σ₀` and
   `a ≡ w`, the constrained program has a sharp, attained, strict answer (flat
   fee minimizes λ_MEV at fixed FLAIR budget). *What's unclear:* with `σ_t`
   varying, `h_t` varies with `t`, so it is a *sum of different* convex
   functions and plain Jensen does not apply; the correct statement is a
   two-measure / covariance one. *Recommendation:* have the plan carry BOTH —
   the constant-σ theorem as the deliverable, the general case as an explicitly
   `OPEN` row in LEAN_TRACEABILITY §7 (the project already does this cleanly:
   D3, H2, the `α`-cap term are all marked OPEN "deliberately"). **Do not let
   Aristotle silently weaken the general claim into the special case without it
   being labelled.**

2. **Do `a_t` and `w_t` coincide?** *What we know:* `flairHazard`'s `w_t` is
   "traded-price-flow weight … reads `dp` as traded volume" — i.e. ALL flow,
   noise + arb. `mevHazard`'s `a_t` is the per-step LVR, an arb-only object.
   They are structurally different. *What's unclear:* whether the doc wants
   them identified for the joint program. *Recommendation:* keep them as two
   free weight functions in the Lean definitions (maximum generality, zero
   cost), and state the joint theorems under an explicit `a = w` hypothesis
   where needed. This makes the assumption visible rather than baked in.

3. **The Angstrom τ constants.** *What we know:* memory `angstrom-structure`
   (repo exploration, 2026-07-30) records `tax = priority_fee ·
   SWAP_TAXED_GAS(100_000) · SWAP_MEV_TAX_FACTOR(49)` → LPs. The live docs
   (docs.angstrom.xyz/l2/arbitrage-auction, fetched 2026-07-30) give
   `TAXED_GAS = 120,000`, a `priorityFeeTaxFloor` deduction, `jitMEVTaxFactor =
   1.5 × swapMEVTaxFactor`, and — importantly — the proceeds **split** between
   creator/protocol/LP shares (`creatorTaxFeeE6`, `protocolTaxFeeE6`), with JIT
   tax going 100% to the protocol treasury. *What's unclear:* which snapshot is
   current, and whether "recycled to LPs" is even the right modelling of the
   split. *Recommendation:* **parametrize `τ ∈ [0,1]` and state `taxFraction k =
   k/(k+1)` with `k` free; mention `k = 49 ⟹ τ = 0.98` only as a worked
   instance with the date of the snapshot.** Additionally, the mapping
   "searcher bid ↔ priority_fee × gas" is itself a modelling assumption (the
   Robinson–White MEV-tax construction) — say so in the docstring. LOW-MEDIUM
   confidence; do not let a numeric constant into a theorem statement.

4. **Requirement IDs.** ROADMAP line 250 says `**Requirements**: TBD`.
   *Recommendation:* mint the CTX-* set proposed in `<phase_requirements>` at
   planning time and write it into ROADMAP, per the Phase 8/9/10 convention. Do
   NOT extend `.planning/REQUIREMENTS.md` — it is scoped to the v1 plumbing
   milestone only.

5. **Which Mathlib Jensen lemma.** I verified `IsCompact.exists_isMinOn`,
   `strictConvexOn_zpow`, `ConvexOn.comp_affineMap`, and
   `one_div_le_one_div_of_le` by grep at the pinned rev. I did **not** verify
   the exact name of the finite-sum Jensen lemma in
   `Mathlib/Analysis/Convex/Jensen.lean`. *Recommendation:* one grep at
   bundle-build time; and note that Aristotle authors its own proofs, so this is
   a prompt-hygiene nicety rather than a blocker.

6. **Should the exact-CPMM kernel be formalized at all?** *What we know:*
   Corollary 2 is fully explicit and would give a second, tighter instantiation;
   but it needs `σ²Δt < 8` for finiteness and `σ²Δt ≤ 2 ∧ φ ≤ 1` for
   antitonicity (F3). *Recommendation:* include it as a clearly-scoped
   second-tier theorem in bundle A, with those hypotheses stated up front. If
   the plan needs to cut scope, this is the first thing to cut — the
   leading-order kernel carries the entire program.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`. This is a
**proof phase**, not a test-suite phase: validation is compile-time and
review-time, not `pytest`.

### Test Framework

| Property | Value |
|---|---|
| Framework | Lean 4 kernel + `lake` (`leanprover/lean4:v4.28.0`), Mathlib `v4.28.0` |
| Config file | `lean/lakefile.toml` (new root must be added to the `vol_markets` `roots` list) |
| Quick run command | `cd lean && lake build vol_markets` |
| Full suite command | `cd lean && lake build` (all three libs: `exp`, `vol_markets`, `tao`) |
| Axiom check | `#print axioms <name>` per theorem — MUST be exactly `[propext, Classical.choice, Quot.sound]` |
| Sorry check | `grep -rn "sorry\|admit" lean/vol_markets/MevOptimization.lean` → empty |
| Fidelity check | `diff` returned Aristotle archive's untouched modules against the submitted bundle → byte-identical; statement-level diff of the new module against the prompt's numbered list |

### Phase Requirements → Validation Map

| CTX ID | Behavior | Check type | Automated command | Exists? |
|---|---|---|---|---|
| CTX-MEVDOC | addendum block is LaTeX-only, uses `φ`/`Δt`, contains no `η`, no bare `λ` for block rate, no `γ` for fee | grep gate | `! grep -nE '(^\|[^_])η\|\\\\lambda[^_{]' <addendum>` (tune) + manual read | ❌ Wave 0 — write the grep gate |
| CTX-MEVDOC | two-reviewer gate returns no unresolved BLOCKER/MAJOR | manual | reviewer transcripts recorded in the plan summary | ❌ Wave 0 |
| CTX-PTRADE | `ptrade` lemmas compile, sorry-free, axiom-clean | compile | `cd lean && lake build vol_markets` | ✅ (framework exists) |
| CTX-MEVHAZ | `mevHazard`/`mevMulti` signatures match the prompt verbatim | statement diff | `grep -A3 'def mevHazard' lean/vol_markets/MevOptimization.lean` vs prompt §A | ❌ Wave 1 — record the expected signatures in the plan |
| CTX-INF | all inf-program theorems present, none weakened | statement diff | per-theorem checklist in the plan; `#print axioms` each | ❌ Wave 1 |
| CTX-JOINT | degeneracy + constrained theorems present; the constrained one's hypotheses are LABELLED if specialized | statement diff + manual | as above; **any narrowing of the σ-varying claim must be recorded, not silently accepted** | ❌ Wave 2 |
| CTX-ANGSTROM | no numeric `49`/`50`/`0.98` inside any theorem statement | grep gate | `! grep -nE '49\|0\.98' lean/vol_markets/MevOptimization.lean` (allow in docstrings only) | ❌ Wave 2 |
| CTX-TRACE | every new theorem has a §7 row; no PROVEN row without a Lean name | manual + grep | cross-check §7 names against `grep -oE '^(theorem\|lemma) [A-Za-z_]+' MevOptimization.lean` | ❌ Wave 3 |
| all | untouched modules byte-identical after integration | diff | `git status --porcelain lean/` shows ONLY the new file | ✅ (`git` exists) |

### Sampling Rate

- **Per task commit:** `cd lean && lake build vol_markets` (green) +
  `grep -c sorry` on the touched file (0).
- **Per wave merge:** `cd lean && lake build` (all libs) + `#print axioms` on
  every theorem in the new module + `git status --porcelain lean/` shows only
  the intended file.
- **Phase gate:** full build green, zero sorries, all axioms in
  `{propext, Classical.choice, Quot.sound}`, statement-fidelity diff clean, both
  reviewer verdicts recorded, LEAN_TRACEABILITY §7 rows written, and the
  mirrored push to `JMSBPP/cfmm-lean4-spec` — before `/gsd:verify-work`.

### Wave 0 Gaps

- [ ] `scratch/aristotle-mev/` bundle skeleton (lakefile.toml, lean-toolchain,
      lake-manifest.json, `RequestProject/` with **10** modules) — covers
      CTX-PTRADE/CTX-MEVHAZ/CTX-INF submission
- [ ] `scratch/aristotle-mev-PROMPT.txt` — the numbered spec; itself a
      two-reviewer artifact (PIT-7)
- [ ] The addendum-hygiene grep gate (PIT-1/2/3) — a 3-line script, not present
- [ ] The per-theorem statement checklist (the thing the fidelity diff is run
      against) — must be written INTO the plan, not derived after the fact
- [ ] A recorded pre-submission `aristotle tasks` check showing the queue is
      empty (PIT-9)
- [ ] Framework install: **none needed** — `lake`, `aristotle`, `pdftotext` all
      present and verified in this research

---

## Sources

### Primary (HIGH confidence)

- `../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf` —
  arXiv:2305.14604v2, "Automated Market Making and Arbitrage Profits in the
  Presence of Fees", Milionis, Moallemi, Roughgarden; initial 2023-02-06,
  current 2025-07-23. **Read in full** (47 pp) via `pdftotext -layout`.
  Extracted: Assumption 2, Theorem 1 (stationary distribution, `P_trade`),
  Corollary 1 (`σ_z`), Theorem 2 (exact ARB/FEE), Corollary 2 (CPMM closed
  form + the `σ²/8 < λ` condition), Theorem 3 (`ARB ≈ LVR·P_trade`), Theorem 4
  (`FEE ≈ LVR·(1−P_trade)`), Theorems 5–7 + Corollaries 3–4 (gas fees), §7.1
  (block-time lever, multi-block MEV), §7.2 (mispricing/arb frontier), §7.3
  eq. (27) (LP P&L = NT_FEE − ARB).
- `lean/vol_markets/FlairOptimization.lean` (439 lines) — the mirror template;
  every theorem read.
- `lean/vol_markets/VolInstrument.lean` (353 lines) — `multiFee`, `sigmoidR`,
  `probOr*`, `priceEta`.
- `lean/vol_markets/FeeSchedule.lean` — `logistic` and its four lemmas.
- `model/vol_markets/LEAN_TRACEABILITY.md` — §0 notation dictionary (the `η`
  reservation), §6 (MEV = OPEN), §7 (FLAIR PROVEN rows).
- `../plank/notes/VOLATILITY_INSTRUMENTS.md` §HAZARD RATES, §FLAIR, §MEV
  (lines 393–464) — the doc the addendum edits.
- `.planning/phases/11-mev-hazard-inf-program/11-CONTEXT.md` — the binding
  constraints.
- `scratch/aristotle-flair-PROMPT.txt` + `scratch/aristotle-flair/` — the
  working submission template (produced 15 axiom-clean theorems, commit
  6914fba).
- `.planning/phases/08-panoptic-vol-claim-lean4-formalization/08-RESEARCH.md`
  Pitfalls 4–5 — bundle layout and serial-queue rules.
- Mathlib at the pinned rev, grepped directly:
  `Mathlib/Topology/Order/Compact.lean:228`,
  `Mathlib/Analysis/Convex/SpecificFunctions/Deriv.lean:99`,
  `Mathlib/Analysis/Convex/Function.lean:937`,
  `Mathlib/Algebra/Order/Field/Basic.lean:69`.
- `CLAUDE.md` ownership map; `.planning/config.json`; `.planning/ROADMAP.md`;
  `.planning/STATE.md`; `.planning/REQUIREMENTS.md`.

### Secondary (MEDIUM confidence)

- Memory `angstrom-structure` (repo exploration 2026-07-30) — Angstrom
  architecture, ToB auction/`RewardsUpdate`, l2 tax constants. Corroborated in
  *mechanism* but **contradicted in constants** by the live docs.
- Memory `mev-lambda-literature`, `vol-instruments-notation-binding`,
  `lean-aristotle-heavy-workflow`, `aristotle-no-queue`,
  `anti-fabrication-review-gate`.
- https://docs.angstrom.xyz/l2/arbitrage-auction — live L2 MEV-tax formula,
  `TAXED_GAS = 120,000`, `priorityFeeTaxFloor`, `jitMEVTaxFactor = 1.5×`,
  creator/protocol/LP split.
- https://github.com/SorellaLabs/angstrom/blob/main/contracts/docs/overview.md —
  the two-mechanism overview (batch uniform clearing / ToB auction).

### Tertiary (LOW confidence — flagged, not relied on)

- Web summary asserting "captures 98% of the marginal priority fee" and
  "100% of the proceeds flow to the protocol treasury" — these two statements
  are in tension with each other and with the docs' creator/protocol/LP split.
  **This is precisely why the Lean statement must be parametric in `τ`.**
- The six supporting MEV PDFs in `../plank/refs/mev/` (Theory of MEV I & II,
  Guo, Mazorra–Della Penna, Flash Boys 2.0, cross-domain) were **not read** for
  this research — only their roles from memory `mev-lambda-literature` are
  cited. Only Theory of MEV I is referenced above (F8), and only as the source
  for "sandwich MEV is a distinct channel", a claim safe at that granularity.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| The anchor closed forms (F1) | **HIGH** | read directly from the local v2 PDF; theorem statements transcribed, not paraphrased |
| Notation collisions (F2) | **HIGH** | LEAN_TRACEABILITY §0 states the `η` reservation explicitly; the `γ`/`λ` clashes are verifiable by inspection of both symbol sets |
| Fee-dependence composition (F3) | **HIGH** | elementary calculus on an explicit rational function; the CPMM non-monotonicity threshold `φ < 2 − 1/c` derived and checked |
| Lean mirror structure (F4) | **HIGH** | `FlairOptimization.lean` read line-by-line; each Mathlib lemma grepped at the pinned rev |
| Degeneracy of the unconstrained joint program (F5) | **HIGH** | follows from two already-PROVEN monotonicity theorems plus `ptrade` antitone; no new assumption |
| The Jensen/constrained result (F6) | **MEDIUM-HIGH** | sharp and correct in the aligned-measure, constant-σ case; the σ-varying generalization is genuinely open (Q1) |
| Angstrom mechanism mapping (F7, F8) | **MEDIUM-HIGH** structure, **MEDIUM** constants | mechanism corroborated by two sources; constants disagree between the repo snapshot and live docs (Q3) |
| Supporting MEV literature | **LOW** | six PDFs unread; cited only at the granularity memory supports |

**Research date:** 2026-07-30
**Valid until:** ~2026-08-29 for the mathematics (2305.14604 v2 is a settled
July-2025 paper; the FLAIR Lean layer is frozen and pinned). **~2026-08-06 for
the Angstrom constants** — they moved once already inside a single day's
sources and must be re-checked before any numeric enters an artifact.
