# Design — Econometric identification of `Ḡ = ∂ν/∂λ_MEV`

**Date:** 2026-08-08
**Status:** DESIGN APPROVED (brainstorm). Not yet a GSD phase — see §7.
**Supersedes:** nothing. **Feeds:** the deferred `EST-01` track (v2 requirements).

---

## 1. The estimand, and why it is the only empirical object

The corrected control law (`MevTaxProgram.Proposition16_corrected_law`) is

\[
\frac{\partial\widehat\pi^{\sigma}}{\partial\tau_{\text{MEV}}} = 0
\quad\Longleftrightarrow\quad
\tau^{\star}_{\text{MEV}} \; = \; 1 \; + \; \frac{1-\phi_X}{(\partial\phi/\partial\nu)\,(\partial\nu/\partial\tau_{\text{MEV}})}
\]

stated with a **signed denominator**. The frequently-quoted
`τ* = 1 − (1−φ_X)/|(∂φ/∂ν)(∂ν/∂τ_MEV)|` is the *equivalent form under the M21 signs*
(`∂φ/∂ν > 0`, `∂ν/∂τ_MEV < 0`) and must never be written as though it were the
theorem — the absolute value silently embeds the sign result.

Every factor except one is structural:

| Factor | Status |
|---|---|
| `φ_X` | `DOC` Definition 18, closed form (carries **both** `σ` and `ν`) |
| `∂φ/∂ν` | closed form, `ENTRY_POINT.md` boxed expression |
| `∂λ_MEV/∂τ_MEV` | **derivable** — `τ` enters the fee explicitly via the Rule 12 monoid, and `λ` is built from `ptrade(multiFee(·))` |
| `∂ν/∂λ_MEV` | **the estimand.** Behavioural. Not derivable. |

`τ_MEV` is **not implemented**, so `∂ν/∂τ_MEV` is not directly observable. The
decomposition

\[
\frac{\partial\nu}{\partial\tau_{\text{MEV}}}
=
\frac{\partial\nu}{\partial\lambda_{\text{MEV}}}\cdot\frac{\partial\lambda_{\text{MEV}}}{\partial\tau_{\text{MEV}}}
\]

is what makes estimation possible at all: `λ` varies naturally in existing pools even
though `τ` does not exist. **This estimation is simultaneously the test of H2**
(`H2_dnu_dlamMEV_pos`), which both Lean bundles carry as an undischarged hypothesis.

**Runtime target (user ruling):** a **cheap parametric function of state**, not a
stored constant and not a full response curve.

---

## 2. Identification

### The problem

The dynamic fee plugin closes a loop:

```
ν(s) ──gate──> φ(s) ──> ℙ_{Δ_ARB}(s) ──Σ_{s<t}──> λ_ARB(t) ──?──> ν(t)
```

Utilization sets the fee (`DOC` Definition 18's gate), the fee sets the arb
probability (Definition 21), and that accumulates into the hazard (Definition 22).
Regressing `ν` on `λ` recovers a mixture of both directions.

### The instrument: `Δt`

`Δt` enters the arb probability

\[
\mathbb{P}_{\Delta_{\text{ARB}}} = \frac{\sigma}{\sigma + \phi\sqrt{2/\Delta t}}
\]

— increasing in `Δt` (Theorem 16) — and does **not** appear anywhere in
`φ = φ̄ + \text{volSurcharge}(σ)\cdot\text{gate}(ν)`. Clean exclusion restriction, and
`Δt` is chain-level rather than pool-level, so it is plausibly exogenous to a single
pool's utilization.

**First stage regresses `λ_ARB` on `√Δt`**, the transform the hazard actually carries —
not on `Δt` raw.

### Named risk — weak instrument

Post-merge Ethereum slots are 12 s with variation only from missed slots. On a venue
with near-constant `Δt` the first stage is weak and IV is biased **toward OLS**, which
is precisely the bias being escaped. Mitigations, in order:

1. Select a venue with genuine block-time dispersion.
2. Report the **first-stage F before** examining the second stage. A weak first stage
   is a stop, not a caveat.
3. If dispersion is insufficient everywhere available, that is a **terminal
   non-identification** result — see §4.

### Secondary defence

`λ_ARB(t) = Σ_{s<t}(·)` is **predetermined** — measurable at `t−1`. This supports
sequential-exogeneity arguments and lagged instruments, but is a second line of
defence, not the primary identification.

---

## 3. Staged estimation

### Stage 1 — sign test (gate)

Test `∂ν/∂λ_MEV > 0` only. One endogenous regressor, one instrument, no
functional-form freedom. Three outcomes, **all terminal and all reportable**:

| Outcome | Consequence |
|---|---|
| positive, significant, strong first stage | gate opens → Stage 2 |
| **wrong sign** | **H2 REFUTED.** Propagates into both Lean bundles: `Theorem34`'s opposed-signs result and the corrected law's sign both flip |
| not identified | terminal, exactly as the `υ` exercise. The controller is not buildable from this data. **A delivered result, not a failure to re-specify around** |

### Stage 2 — magnitude (only behind the gate)

\[
\nu \; = \; a \; + \; b\,\sigma_\ell\bigl(c(\lambda - d)\bigr)
\]

by nonlinear IV / GMM. Then

\[
\boxed{\;\Ḡ \; = \; b\,c\,\sigma_\ell'\bigl(c(\lambda-d)\bigr)\;}
\]

a **logistic bump** — the same shape `∂φ/∂ν` already has on-chain, so the controller
reuses `AdaptiveFee`'s sigmoid machinery rather than adding new. `Ḡ → 0` in the tails,
matching `Theorem36`: where the gate saturates there is no interior root anyway.

---

## 4. Anti-fishing discipline

The `υ` precedent is binding: that exercise terminated in *"this market cannot
identify υ"* and was correctly never reopened. This design inherits that discipline.

- Stage 1's specification, instrument, sample and power floor are **fixed before the
  data is touched**.
- The stage gate exists so that a failed sign test **stops the work** rather than
  motivating a search over specifications.
- Stage 2's `(c, d)` placement is the main remaining researcher degree of freedom;
  it is entered only after Stage 1 has already passed on a pre-fixed spec.
- A wrong-signed or unidentified `Ḡ` is a **result to report**, and it back-propagates
  into the Lean corpus rather than being absorbed.

---

## 5. Output contract

**Delivered:** `(a, b, c, d)` with covariance; the first-stage F; and the **admissible
band** where `Ḡ` is bounded away from zero — the controller's domain, intersected with
`Theorem36`'s responsive band.

**On-chain:** four stored parameters plus one sigmoid evaluation, reusing existing
fixed-point machinery.

**Back-propagation:** Stage 1's verdict discharges or refutes **H2** in
`MevTaxControl.lean` and `MevTaxProgram.lean`.

---

## 6. Open — not assumed

1. **Data source and venue.** Dune MCP is available; the repo carries an
   events→subgraph layer. Which chain and which Algebra Integral pools, and whether
   that venue has sufficient `Δt` dispersion, decides whether §2 works at all.
2. **`ν`'s empirical construction.**
   `ν = φ_{(1/2,0)}(i_K; ΔQ, 0; t) / φ_{(1/2,0)}(i_K; 0, L; t)` is a ratio of
   trading-function evaluations. Whether it is directly computable from pool state and
   swap events, or requires reconstruction, is unresolved.
3. **`φ_X`'s ν-dependence in the estimating equation.** `φ_X` carries both `σ` and `ν`
   (`DOC` Definition 18), so `φ_X` is itself a function of the outcome. Any
   specification conditioning on `φ_X` must account for this.
4. **`σ` versus `σ²` units.** `DOC` Definition 18's sigmoid argument is `σ(i(t))`; the
   plant's `u_ex` carries `σ²(i(t))`. `Θ_φ`'s centers live in σ-units, the disturbance
   in σ²-units. A regression mixing them silently is wrong.
5. **The FOC root is not established to be the minimiser**
   (`Proposition15_level_reading_second_order_undetermined`). Single crossing from
   below would settle it and is not proved. If the estimation calibrates toward a `τ`
   assumed to minimise exposure, that assumption is load-bearing.

---

## 7. Relation to GSD

This design is **not yet a phase**. `EST-01` currently sits in the v2 requirements
("identify the behavioural gains from add/remove-liquidity events"). Folding this in
requires a roadmap update: `EST-01` becomes a phase with Stage 1 and Stage 2 as
separate plans separated by the gate, and §6's five open items enter the gap register.

Sequencing: Phase 1's notation map and units ledger (`NOT-02`, `NOT-05`, `NOT-07`) are
**direct inputs** to this work — item 4 above is exactly a units question. Phase 1
should land before Stage 1 is specified in detail.

---
*Design approved 2026-08-08 via brainstorming. Estimand, identification lever, functional form and staging all ruled by the user.*
