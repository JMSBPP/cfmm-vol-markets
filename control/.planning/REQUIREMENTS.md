# Requirements: MEV-Tax Set-Point Controller — Verified Design Spec

**Defined:** 2026-08-08
**Core Value:** The artifact under construction is the artifact under proof — the project must return a *verdict* on the boxed `τ*_MEV`, and (per the 2026-08-08 scoping decision) a **corrected law** where it refutes.

> **Scope (user ruling 2026-08-08): the deliverable is the FORMAL DOCUMENT of the
> controller, grounded on theory and formal results.** Nothing else.
>
> - **verdict + salvage** — where an obligation refutes, the corrected law is derived and verified
> - the τ↔λ bridge is a full obligation **P5**
> - the behavioral gains (`∂L̄/∂π^φ`, `∂ν/∂λ_MEV`) are stated as **typed hypotheses** in the formal layer and are **never proved** — they are LP-supply estimands
> - **EVM feasibility is OUT** — the entire E0/E1 track moved to v2. This project is theory + formal results + the document.
>
> **AMENDED 2026-08-08 — the Estimation category is now v1.** `Ḡ = ∂ν/∂λ_MEV` is the
> only empirical object in the corrected law; estimating it *is* the test of H2, which
> both Lean bundles carry undischarged. Design: `control/spec/ECONOMETRICS-DESIGN.md`.
> The formal layer still never proves the gains — `EST-03`'s sign test discharges or
> refutes them from data instead.

---

## v1 Requirements

### Frame

- [ ] **FRM-01**: The control-theoretic frame is selected and justified in writing, with the excluded alternatives named and the reason for each exclusion stated (LQR/LQG/servo, root locus, Bode/Nyquist, PID, Gramian rank tests, and the "static output feedback" name-collision).
- [ ] **FRM-02**: Well-posedness conditions for a set-point (as opposed to a regulator) are enumerated as a checklist that each downstream obligation is tested against.
- [ ] **FRM-03**: The event-clock question is resolved or explicitly declared OPEN with its consequences stated — specifically whether `t` indexes swaps or blocks, and whether event-averaged quantities (`ΔQ_M`, `ΔQ_X`) may be combined with time-averaged ones (`π^LVR·Δt`, `σ²`, `λ`) given that PASTA/ASTA is argued not to hold in a CFMM.
- [ ] **FRM-04**: Every literature citation entering the document is verified against a primary source, or carries an explicit UNVERIFIED tag. **Scope corrected:** the true not-primary-verified set is ≈13, not 5 — the recommendation's own four pillars (Skogestad 2000, Mason 1953, Davis 1984, Wolff 1982) sit in the same web-search tier as the flagged failures, and Carr–Madan / Breeden–Litzenberger is invoked five times with no citation anywhere. Every `FRAME.md` HIGH tag is treated as unverified pending re-check. Use the arxiv MCP (available to this session, unlike the frame researcher's).
- [ ] **FRM-05**: The **null-space test** (`HF = 0`, Alstad & Skogestad 2007) is run over an explicitly partitioned disturbance vector, separating trade-specific components (`ΔQ_M`, `ΔQ_X`) from slow-moving ones (`σ²`, `Θ_φ`), and the partition used is stated. This is a **control-theoretic** result about whether a disturbance-invariant controlled variable exists — reported as theory, with no on-chain cost claim attached.

### Notation & Transcription

- [ ] **NOT-01**: All 13 blocking decisions collected in `research/SUMMARY.md` are put to the user and resolved, each with the ruling recorded.
- [ ] **NOT-02**: A notation map paragraph exists, resolving every collision — including `π^{\varphi}` (source: `π^{\phi} − π^{LVR}`; entry-point doc: the portfolio value function), the `L` overload (order ladder vs aggregate pool), `ν` vs `u`, and leg pairing in `π^{\phi}`.
- [ ] **NOT-03**: A crosswalk maps the four research documents' non-aligned claim taxonomies (`P1–P4`/`C-P#-#`/`A#`, `B#`/`M#`/`N#`/`R#`, `FINDING A/B`/`W#`) onto one identifier scheme.
- [ ] **NOT-04**: The `∂`-partition is constructed **entrywise** from the source, and each entry is checked for whether it is a constant, a Jacobian entry, or structurally zero — before any claim relying on the plant being non-degenerate is made.
- [ ] **NOT-05**: The unit/dimension ledger **EXTENDS** the existing normative table at `plank/notes/UNITS_AND_SCALES.md` (sha-pinned, peer-owned, already two-step reviewed) with the symbols it lacks — `ν`, `τ_MEV`, `π^l`, `π^φ`, `π^LVR`, `ΔQ_υ`. It does **not** re-derive a parallel ledger. The extension is routed to `ul2inqpl` as a proposed diff, never edited in the peer's tree.
- [ ] **NOT-06**: No symbol is minted that is not either in the source or recorded in the notation map with a stated reason.
- [ ] **NOT-07**: The **two-axis liquidity distinction is recorded as settled** (user ruling 2026-08-08): `L(i_K) = L̄·ℓ(ξ,ι;i_K)` with `ℓ` geometry-invariant; `ΔQ_v★` is **vol-asset** L units (`UNITS_AND_SCALES.md:70`) while the pool's `L̄` is price-axis liquidity — two assets, not one ambiguous symbol. Every downstream use of `L` names its axis.
- [ ] **NOT-08**: An **inventory sweep** of `evm-controller/spec/`, `evm-controller/notes/` and `plank/notes/` identifies every normative artifact **before** any notation map or ledger is written — closing the discovery failure that missed `UNITS_AND_SCALES.md`, `VOLATILITY_INSTRUMENTS_MEV.tex` (1063 lines, 29 numbered Definitions / 21 Theorems / 9 Propositions, defines `ι` = our `#_σ` at :212), and `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/ENTRY_POINT.md` (carries a correct boxed `∂φ/∂ν`; currently **untracked** and at risk of destruction — track it).
- [ ] **NOT-09**: The `ΔQ_v★` / `ΔQ_υ` glyph collision is resolved (`DOC:672` — i.e. `plank/notes/VOLATILITY_INSTRUMENTS.md` — indicates they occupy the same `I_ord` slot), and `∂φ/∂ν` from `ENTRY_POINT.md` is carried into the channel's factor list as a **determinate, strictly positive** factor.

### Proof Obligations

- [ ] **PRF-01**: **P1 — well-posedness.** A verdict on whether the `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is well-posed over event time, and whether set-point optimization is legitimate given `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j)` frozen.
- [ ] **PRF-02**: **P2 — the 5-factor channel.** A verdict on whether `τ_MEV` reaches `π̂^σ` through no path other than the stated chain, with the counterexample exhibited if it does not.
- [ ] **PRF-03**: **P3 — the behavioral gains, as HYPOTHESES.** `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0` and `∂L̄/∂π^φ > 0` are **LP-supply responses, not propositions** (user ruling 2026-08-08). Each is formalized as an explicitly named typed hypothesis, with its estimand, its sign convention, and its observation channel (add/remove-liquidity events) documented. **Neither is sent to Aristotle as a claim to prove.** Estimating their magnitudes is the **Estimation** category (`EST-01`…`EST-05`), promoted to v1 on 2026-08-08; `EST-03`'s sign test is what finally discharges or refutes them.
- [ ] **PRF-04**: **P4 — the boxed closed form.** A verdict on the boxed `τ*_MEV`, resolving first *which relation it actually solves* (the research finds it equivalent to `∂π̂^σ/∂τ_MEV = ΔQ_v*`, not to `π^σ ≡^R π̂^σ`).
- [ ] **PRF-05**: **P5 — the τ↔λ bridge.** A verdict on whether `∂ν/∂λ_MEV` may be substituted for `∂ν/∂τ_MEV`, stated as a first-class obligation rather than an implicit step.
- [ ] **PRF-06**: Every obligation is stated in the Lean tree's native idiom (`Monotone`/`StrictAnti`/`ConvexOn`) wherever a sign or ordering claim suffices. **Rationale corrected:** the tree is NOT devoid of differential-calculus infrastructure — `CapponiEmbed.lean` carries 132 `HasDerivAt` / 128 `deriv` / 19 `Differentiable` — **all three are `grep -c` LINE counts, not occurrence counts** (`grep -o '\bderiv\b' | wc -l` gives 306; both are correct, the unit is what differs — state the method with any count), including `HasDerivAt.div`, `Real.hasDerivAt_rpow_const` and a fourth-derivative computation. The real gap is narrower: no derivative lemmas for the five named schedule functions (`logistic`, `sigmoidR`, `multiFee`, `probOr`, `ptrade`). Any derivative layer is priced against `CapponiEmbed` as in-tree precedent, not from scratch.
- [ ] **PRF-07**: Each obligation is frozen and sha-pinned at submission time, and its statement is byte-diffed against what returns — so a silently strengthened hypothesis cannot land unnoticed.
- [ ] **PRF-08**: Every returned proof passes an integration gate before being treated as landed: statement byte-diff, axiom check, zero `sorry`s, proof-body triage, dependency byte-identity, and provenance.
- [ ] **PRF-09**: Cheap detectors run **before** any Aristotle submission. The numerical harness is **conditional by construction**: it records the sign/range of `τ*` *as a function of the named hypothesis set* (`PRF-03`'s gains have no closed form — they are estimands), with the hypotheses enumerated alongside the output. A hypothesis-dependent range violation may **not** be logged as a refutation. Plus a back-substitution check on each closed form.
- [ ] **PRF-10**: Each obligation ships as a self-contained PROOF-REQUEST hand-off artifact, since no step of the proving pipeline executes in this worktree.

### Salvage

- [ ] **SAL-01**: For each refuted obligation, the *specific defect* is recorded — not merely that it failed, but which step, which line, and which error class.
- [ ] **SAL-02**: A corrected set-point law is derived under the selected frame, addressing the defects the verdicts expose.
- [ ] **SAL-03**: The corrected law is stated over an explicit domain, including the branch structure the kinks force (`(·)⁺` at the strike, the OTM branch where no interior solution exists, and the `min(·)` funded cap).
- [ ] **SAL-04**: The corrected law is itself submitted for verification, and carries its own verdict.
- [ ] **SAL-05**: Every assumption the corrected law rests on is declared as an assumption, never justified by citing a theorem that does not exist.

### Estimation

Promoted from v2 by the 2026-08-08 design (`control/spec/ECONOMETRICS-DESIGN.md`).
`Ḡ = ∂ν/∂λ_MEV` is the **only empirical object** in the corrected law — every other
factor is structural. Estimating it is simultaneously the **test of H2**, carried
undischarged through both Lean bundles.

- [ ] **EST-01**: `ν`'s **empirical construction** is established — whether `ν = φ_{(1/2,0)}(i_K; ΔQ, 0; t) / φ_{(1/2,0)}(i_K; 0, L; t)` is directly computable from pool state and swap events, or requires reconstruction, with the read path named. Blocks everything else in this category.
- [ ] **EST-02**: The **identification lever is validated before use** — `Δt` enters `ℙ_{Δ_ARB}` but not the fee schedule (a clean exclusion), yet its exogeneity and, critically, its **dispersion** on the chosen venue are open. Run the structural-econometrics discipline over the choice; a venue with near-constant `Δt` yields a weak first stage biased *toward* OLS, which is the bias being escaped. **Decision #10 (`Δt` exogenous or endogenous) is deferred here, not closed in the doc layer.**
- [ ] **EST-03**: **Stage 1 — the sign test, as a gate.** Test `∂ν/∂λ_MEV > 0` only, on a specification, instrument, sample and power floor **fixed before the data is touched**. Report the first-stage F **before** examining the second stage. Three terminal outcomes, all reportable: gate opens; **wrong sign ⟹ H2 REFUTED**; or **not identified**, exactly as the `υ` exercise — a delivered result, never a prompt to re-specify.
- [ ] **EST-04**: **Stage 2 — magnitude, only behind the gate.** Fit `ν = a + b·σ_ℓ(c(λ − d))` by nonlinear IV/GMM, giving `Ḡ = b·c·σ_ℓ'(c(λ−d))` — a logistic bump reusing `AdaptiveFee`'s on-chain sigmoid machinery, vanishing on the saturation bands per `Theorem36`.
- [ ] **EST-05**: **Output contract and back-propagation.** Deliver `(a,b,c,d)` with covariance, the first-stage F, and the **admissible band** where `Ḡ` is bounded away from zero, intersected with `Theorem36`'s responsive band. Stage 1's verdict **discharges or refutes H2** in `MevTaxControl.lean` and `MevTaxProgram.lean`; a refutation flips `Theorem34`'s opposed-signs result and the corrected law's sign.

### Consolidation & Hand-off

- [ ] **HND-01**: A gap register lists every open item with severity and disposition (in-scope vs deferred), including the event-clock question and any obligation left as a hypothesis.
- [ ] **HND-02**: The **formal controller document** integrates frame, entrywise plant, verdicts, typed hypotheses and salvage, each section delegating detail to its owning document. This is the project's deliverable.
- [ ] **HND-03**: The hand-off to downstream milestones is defined — the deferred **EVM-01a/01b/02/03/05/06** feasibility track — with cross-worktree coordination points named and their owning peer sessions identified. Peer agreement is **obtained**, not assumed: `list_peers` at repo scope returns nothing, `CLAUDE.md` has no row for this track, and silence is not consent.
- [ ] **HND-04**: The stale v2-controller documents (`LEAN-MAP.md`, `EVM-CONTROL-PRIMITIVES-MAP.md`) are marked do-not-cite so they are not consumed as current.
- [ ] **HND-05**: A review register exists and is honest about its own history: the founding artifacts (`b5f5e82`, `9658375`, `d3b226a`) were committed **before** their two-step review ran, and that review's findings are recorded as the register's **retroactive first entries**. Every subsequent artifact passes the gate before commit. The v2-controller `SPEC-04` precedent is what this exists to avoid repeating — and did not.

---

## v2 Requirements

Deferred — tracked, not in this roadmap.

### EVM Feasibility — moved out of v1 by the 2026-08-08 scope ruling

Carried here intact so the analysis is not lost. Each row is BLOCKER-grade for an
implementation milestone and none of it is answerable from theory alone.

- **EVM-01a**: fixed-point primitive inventory refreshed against the live Plank tree (supersedes the stale `EVM-CONTROL-PRIMITIVES-MAP.md`; the "no WAD `exp`/`ln`/`pow`" claim is already false — `FixedPointMath.plk` ports solady `rpow`, `AdaptiveFee.plk` has a Taylor `exp`)
- **EVM-01b**: on-chain **state-variable** inventory. `grep -rin "tau\|mev\|utilization" plank/src/` → **zero hits**: `τ_MEV` and `ν` have no slot, setter or type, so three of the law's five factors have no on-chain referent
- **EVM-05**: name the call site (`beforeSwap` hook / separate hook / permissioned setter / keeper). Determines everything else — saturate-never-revert is right in `beforeSwap` and wrong in a mint path, where the live tree deliberately reverts (`PanopticTokenIdSetterLib.plk:132-135`)
- **EVM-02**: feasibility analysis of the verified law — primitives, scale, signedness, rounding, saturation semantics, cost envelope. **Scale is inherited, not chosen**: `plank/notes/UNITS_AND_SCALES.md` at a pinned sha (the tree is Q64.96; `φ_X` is 1e-6 masked to `uint16` — WAD is the wrong mandate)
- **EVM-03**: reconcile the model's strike count `#_σ` with `ι` (`VOLATILITY_INSTRUMENTS_MEV.tex:212`) and the structural 4-leg bound at `PanopticTokenIdSetterLib.plk:140`
- **EVM-06**: real numeric hazards — actuator quantization (`φ_X` in 1e-6 steps, `Θ_φ` `uint16`) and sigmoid **saturation bands** (`AdaptiveFee.plk:53-60`), where `∂φ_X/∂ν = 0` exactly. The `(1−φ)` pole is structurally unreachable (`φ_X ≤ 0.065535`) and is not the hazard

### Implementation

- **IMP-01**: Plank/Solidity implementation of the verified law
- **IMP-02**: Gas benchmarking against a live pool
- **IMP-03**: Differential testing of the on-chain law against the off-chain reference

### Control extensions

- **CTL-01**: Closed-loop feedback regulator wrapped around the set-point
- **CTL-02**: General `η ≠ ½`
- **CTL-03**: Relaxing `φ_M ≡ φ̄_M` to make `φ_M` a live actuator
- **CTL-04**: Re-opening `(β_j, γ_j)` as actuators, now that the non-control justification is known to be unsupported

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| EVM implementation of the control law | Design spec only; `src/` is peer-owned by `ul2inqpl` |
| Closed-loop feedback law over `e^σ` | Control target is an optimal set-point (user decision) |
| `spec/01_STATE_DELTA_ELASTICITY_CONTROLLER/` | Explicitly removed from scope by the user |
| Any edit to the repo-root `.planning/` | Shared v1 planning, in flight across peers |
| Re-deriving the spatial/tick-lattice controller | Owned by the v2-controller milestone; this is the event-time axis |
| Re-attempting T24 | Refuted by counterexample; only the Θ_φ-restricted varying-σ case remains open |
| Identifying `υ` econometrically | Terminal null result on the planning record; never reopen |
| Dimensional analysis / event-time indexing sent to Aristotle | Not proof-shaped; resolved in the spec layer instead |

---

## Traceability

Populated during roadmap creation (2026-08-08); repopulated after the 2026-08-08 roadmap
rewrite (8 phases -> 6); **repopulated again after the 2026-08-08 RE-BASELINE** (6 phases -> 7)
that recorded Phases 4 and 5 as delivered out of order by two Aristotle bundles and promoted
the Estimation category from v2 to v1.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NOT-01 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-02 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-03 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-05 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-06 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-07 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-08 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-09 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| HND-04 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| HND-05 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-04 | Phase 2 -- Entrywise Plant & Control Frame | Pending |
| FRM-01 | Phase 2 -- Entrywise Plant & Control Frame | Partial (frame research exists) |
| FRM-02 | Phase 2 -- Entrywise Plant & Control Frame | Partial (frame research exists) |
| FRM-03 | Phase 2 -- Entrywise Plant & Control Frame | Partial (frame research exists) |
| FRM-04 | Phase 2 -- Entrywise Plant & Control Frame | Pending |
| FRM-05 | Phase 2 -- Entrywise Plant & Control Frame | Pending |
| PRF-03 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (H1/H2 landed as typed hypotheses; protocol unwritten) |
| PRF-06 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (idiom used ad hoc) |
| PRF-07 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (freeze applied by hand; unwritten) |
| PRF-08 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (gate applied by hand; `#print axioms` UNVERIFIED -- open item O1) |
| PRF-09 | Phase 3 -- Verification Protocol, Ratified Retroactively | Pending (detectors never ran) |
| PRF-10 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (TAX_ADDENDUM.md / TAX2_ADDENDUM.md served as the hand-off; template unwritten) |
| PRF-01 | Phase 4 -- Verdicts: P1, P2, P5 (BRANCH GATE) | **DELIVERED** -- Bundle 1, `Theorem30_composed_fee_submersion_section_sum_ill_posed` |
| PRF-02 | Phase 4 -- Verdicts: P1, P2, P5 (BRANCH GATE) | **DELIVERED** -- REFUTED with witness, `Corollary29_five_factor_product_not_total_derivative` |
| PRF-05 | Phase 4 -- Verdicts: P1, P2, P5 (BRANCH GATE) | **DELIVERED** -- substitution not licensed, `Theorem32_hazard_strictAntiOn_tau` |
| PRF-04 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- box REFUTED factor by factor, `auditTable` (M24) |
| SAL-01 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- `Proposition16_audit_justification`, per-factor defect + error class |
| SAL-02 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- `Proposition16_corrected_law` |
| SAL-03 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- domain `tau*<1`; `tau*>0` iff the gate dominates; `Theorem36_no_interior_root_off_the_band` |
| SAL-04 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- machine-verified declaration, not prose |
| SAL-05 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- signs derived from H1/H2 by name (`Theorem34_signs_from_H1_H2`) |
| EST-01 | Phase 6 -- Estimating `Gbar = dnu/dlambda_MEV` | Pending (BLOCKS the rest of the category) |
| EST-02 | Phase 6 -- Estimating `Gbar = dnu/dlambda_MEV` | Pending (carries Decision #10, deferred here) |
| EST-03 | Phase 6 -- Estimating `Gbar = dnu/dlambda_MEV` | Pending (**HARD GATE** -- three terminal outcomes) |
| EST-04 | Phase 6 -- Estimating `Gbar = dnu/dlambda_MEV` | Pending (runs only behind EST-03's gate) |
| EST-05 | Phase 6 -- Estimating `Gbar = dnu/dlambda_MEV` | Pending (back-propagates into both Lean bundles) |
| HND-01 | Phase 7 -- Formal Controller Document & Hand-off | Pending (must carry open items O1-O5) |
| HND-02 | Phase 7 -- Formal Controller Document & Hand-off | Pending |
| HND-03 | Phase 7 -- Formal Controller Document & Hand-off | Pending |

**Coverage:**
- v1 requirements defined: 39 (FRM 5 + NOT 9 + PRF 10 + SAL 5 + **EST 5** + HND 5)
- Mapped to phases: 39
- Mapped to more than one phase: 0
- Unmapped: 0 (verified programmatically: the set of IDs defined above equals the set mapped
  in `ROADMAP.md`'s `**Requirements**:` lines)
- Delivered: 9 (PRF-01, PRF-02, PRF-04, PRF-05, SAL-01..05)

**Standing open items against the delivered requirements** -- these are NOT closed by the
DELIVERED status above and are carried into the Phase 7 gap register:

| # | Open item | Against |
|---|---|---|
| O1 | `#print axioms` UNVERIFIED on both bundles (needs a Mathlib build) | PRF-08; all of Phase 4 and 5 |
| O2 | The FOC root is **not** established to be the minimiser (`Proposition15_level_reading_second_order_undetermined`); `Proposition15_single_crossing_gives_minimum` is conditional on an unproved single-crossing property | SAL-02, SAL-04 |
| O3 | `phi_X` carries `nu`-dependence (`DOC` Definition 18) so `Rule 13`'s signature at `SRC:69` may be incomplete | NOT-02, NOT-04 |
| O4 | `sigma` versus `sigma^2` units | NOT-05, EST-03 |
| O5 | The project has **no defined failure condition** | HND-01 |

> **Record correction (2026-08-08, re-baseline):** the previous traceability table mapped 34
> requirements across 6 phases and listed `EST-01` as v2. The Estimation category is now v1
> (`EST-01`..`EST-05`), mapped to the new Phase 6; the old Phase 6 (document and hand-off) is
> renumbered Phase 7. Phases 4 and 5 are recorded as DELIVERED **out of order** -- they were
> executed by direct Aristotle submission ahead of Phases 1-3, not after them. The earlier
> correction stands: `EVM-01`..`EVM-04` are not v1 requirements and `EVM-04` does not exist.

---
*Requirements defined: 2026-08-08*
*Last updated: 2026-08-08 after the ROADMAP RE-BASELINE -- traceability remapped onto the 7-phase structure, 39 requirements, delivered work recorded with evidence*
