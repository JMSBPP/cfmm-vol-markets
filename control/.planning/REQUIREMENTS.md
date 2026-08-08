# Requirements: MEV-Tax Set-Point Controller — Verified Design Spec

**Defined:** 2026-08-08
**Core Value:** The artifact under construction is the artifact under proof — the project must return a *verdict* on the boxed `τ*_MEV`, and (per the 2026-08-08 scoping decision) a **corrected law** where it refutes.

> **Scope (user ruling 2026-08-08): the deliverable is the FORMAL DOCUMENT of the
> controller, grounded on theory and formal results.** Nothing else.
>
> - **verdict + salvage** — where an obligation refutes, the corrected law is derived and verified
> - the τ↔λ bridge is a full obligation **P5**
> - the behavioral gains (`∂L̄/∂π^φ`, `∂ν/∂λ_MEV`) are stated as **typed hypotheses**, never proved and never estimated here
> - **EVM feasibility is OUT** — the entire E0/E1 track moved to v2. This project is theory + formal results + the document.

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
- [ ] **NOT-08**: An **inventory sweep** of `evm-controller/spec/`, `evm-controller/notes/` and `plank/notes/` identifies every normative artifact **before** any notation map or ledger is written — closing the discovery failure that missed `UNITS_AND_SCALES.md`, `VOLATILITY_INSTRUMENTS_MEV.tex` (1063 lines, numbered Definitions/Theorems, defines `ι` = our `#_σ`), and `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/ENTRY_POINT.md` (carries a correct boxed `∂φ/∂ν`; currently **untracked** and at risk of destruction — track it).
- [ ] **NOT-09**: The `ΔQ_v★` / `ΔQ_υ` glyph collision is resolved (entry-point doc `:672` indicates they occupy the same `I_ord` slot), and `∂φ/∂ν` from `ENTRY_POINT.md` is carried into the channel's factor list as a **determinate, strictly positive** factor.

### Proof Obligations

- [ ] **PRF-01**: **P1 — well-posedness.** A verdict on whether the `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is well-posed over event time, and whether set-point optimization is legitimate given `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j)` frozen.
- [ ] **PRF-02**: **P2 — the 5-factor channel.** A verdict on whether `τ_MEV` reaches `π̂^σ` through no path other than the stated chain, with the counterexample exhibited if it does not.
- [ ] **PRF-03**: **P3 — the behavioral gains, as HYPOTHESES.** `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0` and `∂L̄/∂π^φ > 0` are **LP-supply responses, not propositions** (user ruling 2026-08-08). Each is formalized as an explicitly named typed hypothesis, with its estimand, its sign convention, and its observation channel (add/remove-liquidity events) documented. **Neither is sent to Aristotle as a claim to prove.** Estimating their magnitudes is out of scope — see `EST-01` (v2).
- [ ] **PRF-04**: **P4 — the boxed closed form.** A verdict on the boxed `τ*_MEV`, resolving first *which relation it actually solves* (the research finds it equivalent to `∂π̂^σ/∂τ_MEV = ΔQ_v*`, not to `π^σ ≡^R π̂^σ`).
- [ ] **PRF-05**: **P5 — the τ↔λ bridge.** A verdict on whether `∂ν/∂λ_MEV` may be substituted for `∂ν/∂τ_MEV`, stated as a first-class obligation rather than an implicit step.
- [ ] **PRF-06**: Every obligation is stated in the Lean tree's native idiom (`Monotone`/`StrictAnti`/`ConvexOn`) wherever a sign or ordering claim suffices. **Rationale corrected:** the tree is NOT devoid of differential-calculus infrastructure — `CapponiEmbed.lean` carries 132 `HasDerivAt` / 128 `deriv` / 19 `Differentiable`, including `HasDerivAt.div`, `Real.hasDerivAt_rpow_const` and a fourth-derivative computation. The real gap is narrower: no derivative lemmas for the five named schedule functions (`logistic`, `sigmoidR`, `multiFee`, `probOr`, `ptrade`). Any derivative layer is priced against `CapponiEmbed` as in-tree precedent, not from scratch.
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

### Consolidation & Hand-off

- [ ] **HND-01**: A gap register lists every open item with severity and disposition (in-scope vs deferred), including the event-clock question and any obligation left as a hypothesis.
- [ ] **HND-02**: The **formal controller document** integrates frame, entrywise plant, verdicts, typed hypotheses and salvage, each section delegating detail to its owning document. This is the project's deliverable.
- [ ] **HND-03**: The hand-off to downstream milestones is defined — the deferred **EVM-01a/01b/02/03/05/06** feasibility track and the **EST-01** estimation track — with cross-worktree coordination points named and their owning peer sessions identified. Peer agreement is **obtained**, not assumed: `list_peers` at repo scope returns nothing, `CLAUDE.md` has no row for this track, and silence is not consent.
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

### Estimation

- **EST-01**: identify the behavioral gains `∂L̄/∂π^φ` and `Ḡ_(ν,λ_MEV)` from add/remove-liquidity events. `PRF-03` states them as typed hypotheses; **this** track measures them. The controller is not actionable without both magnitudes, and the event layer already emits the data

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

Populated during roadmap creation (2026-08-08).

| Requirement | Phase | Status |
|-------------|-------|--------|
| NOT-01 | Phase 1 — Rulings & Ground Truth | Pending |
| NOT-02 | Phase 1 — Rulings & Ground Truth | Pending |
| NOT-03 | Phase 1 — Rulings & Ground Truth | Pending |
| NOT-04 | Phase 1 — Rulings & Ground Truth | Pending |
| NOT-05 | Phase 1 — Rulings & Ground Truth | Pending |
| NOT-06 | Phase 1 — Rulings & Ground Truth | Pending |
| HND-04 | Phase 1 — Rulings & Ground Truth | Pending |
| HND-05 | Phase 1 — Rulings & Ground Truth | Pending |
| FRM-01 | Phase 2 — Frame Selection & EVM Substrate | Pending |
| FRM-02 | Phase 2 — Frame Selection & EVM Substrate | Pending |
| FRM-03 | Phase 2 — Frame Selection & EVM Substrate | Pending |
| FRM-04 | Phase 2 — Frame Selection & EVM Substrate | Pending |
| EVM-01 | Phase 2 — Frame Selection & EVM Substrate | Pending |
| PRF-06 | Phase 3 — Obligation Machinery & Cheap Detectors | Pending |
| PRF-07 | Phase 3 — Obligation Machinery & Cheap Detectors | Pending |
| PRF-08 | Phase 3 — Obligation Machinery & Cheap Detectors | Pending |
| PRF-09 | Phase 3 — Obligation Machinery & Cheap Detectors | Pending |
| PRF-10 | Phase 3 — Obligation Machinery & Cheap Detectors | Pending |
| PRF-01 | Phase 4 — P1 + P2 (HALT GATE) | Pending |
| PRF-02 | Phase 4 — P1 + P2 (HALT GATE) | Pending |
| PRF-03 | Phase 5 — P3 Sign + P5 τ↔λ Bridge | Pending |
| PRF-05 | Phase 5 — P3 Sign + P5 τ↔λ Bridge | Pending |
| PRF-04 | Phase 6 — The Set-Point Law: Verdict and Correction | Pending |
| SAL-01 | Phase 6 — The Set-Point Law: Verdict and Correction | Pending |
| SAL-02 | Phase 6 — The Set-Point Law: Verdict and Correction | Pending |
| SAL-03 | Phase 6 — The Set-Point Law: Verdict and Correction | Pending |
| SAL-04 | Phase 6 — The Set-Point Law: Verdict and Correction | Pending |
| SAL-05 | Phase 6 — The Set-Point Law: Verdict and Correction | Pending |
| EVM-02 | Phase 7 — EVM Feasibility of the Surviving Law | Pending |
| EVM-03 | Phase 7 — EVM Feasibility of the Surviving Law | Pending |
| EVM-04 | Phase 7 — EVM Feasibility of the Surviving Law | Pending |
| HND-01 | Phase 8 — Consolidation & Hand-off | Pending |
| HND-02 | Phase 8 — Consolidation & Hand-off | Pending |
| HND-03 | Phase 8 — Consolidation & Hand-off | Pending |

**Coverage:**
- v1 requirements: 34 total
- Mapped to phases: 34
- Unmapped: 0 ✓

> **Record correction (2026-08-08, roadmapping):** this section previously recorded
> **31** v1 requirements. A direct count of the checklist above returns **34**
> (FRM 4 + NOT 6 + PRF 10 + SAL 5 + EVM 4 + HND 5). The count is corrected here; no
> requirement was added or removed.

---
*Requirements defined: 2026-08-08*
*Last updated: 2026-08-08 after roadmap creation — traceability populated, coverage count corrected 31 → 34*
