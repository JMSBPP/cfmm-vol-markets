# Requirements: MEV-Tax Set-Point Controller — Verified Design Spec

**Defined:** 2026-08-08
**Core Value:** The artifact under construction is the artifact under proof — the project must return a *verdict* on the boxed `τ*_MEV`, and (per the 2026-08-08 scoping decision) a **corrected law** where it refutes.

> Scope decisions taken at definition time: **verdict + salvage** (not verdict-only);
> the τ↔λ bridge is **promoted to a full obligation P5**; EVM feasibility is **split**
> into E0 (primitive inventory, early) and E1 (law-specific, post-verdict).

---

## v1 Requirements

### Frame

- [ ] **FRM-01**: The control-theoretic frame is selected and justified in writing, with the excluded alternatives named and the reason for each exclusion stated (LQR/LQG/servo, root locus, Bode/Nyquist, PID, Gramian rank tests, and the "static output feedback" name-collision).
- [ ] **FRM-02**: Well-posedness conditions for a set-point (as opposed to a regulator) are enumerated as a checklist that each downstream obligation is tested against.
- [ ] **FRM-03**: The event-clock question is resolved or explicitly declared OPEN with its consequences stated — specifically whether `t` indexes swaps or blocks, and whether event-averaged quantities (`ΔQ_M`, `ΔQ_X`) may be combined with time-averaged ones (`π^LVR·Δt`, `σ²`, `λ`) given that PASTA/ASTA is argued not to hold in a CFMM.
- [ ] **FRM-04**: Every literature citation entering the spec is verified against a primary source, or carries an explicit UNVERIFIED tag. The five citations the frame research could not verify are each closed or tagged.

### Notation & Transcription

- [ ] **NOT-01**: All 13 blocking decisions collected in `research/SUMMARY.md` are put to the user and resolved, each with the ruling recorded.
- [ ] **NOT-02**: A notation map paragraph exists, resolving every collision — including `π^{\varphi}` (source: `π^{\phi} − π^{LVR}`; entry-point doc: the portfolio value function), the `L` overload (order ladder vs aggregate pool), `ν` vs `u`, and leg pairing in `π^{\phi}`.
- [ ] **NOT-03**: A crosswalk maps the four research documents' non-aligned claim taxonomies (`P1–P4`/`C-P#-#`/`A#`, `B#`/`M#`/`N#`/`R#`, `FINDING A/B`/`W#`) onto one identifier scheme.
- [ ] **NOT-04**: The `∂`-partition is constructed **entrywise** from the source, and each entry is checked for whether it is a constant, a Jacobian entry, or structurally zero — before any claim relying on the plant being non-degenerate is made.
- [ ] **NOT-05**: A unit/dimension ledger covers every symbol crossing the channel, so a dimensional mismatch cannot survive into a proof statement.
- [ ] **NOT-06**: No symbol is minted that is not either in the source or recorded in the notation map with a stated reason.

### Proof Obligations

- [ ] **PRF-01**: **P1 — well-posedness.** A verdict on whether the `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is well-posed over event time, and whether set-point optimization is legitimate given `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j)` frozen.
- [ ] **PRF-02**: **P2 — the 5-factor channel.** A verdict on whether `τ_MEV` reaches `π̂^σ` through no path other than the stated chain, with the counterexample exhibited if it does not.
- [ ] **PRF-03**: **P3 — the sign.** A verdict on `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0`, or — if unprovable in-tree as the research predicts — its formalization as an explicitly named hypothesis with the missing `λ_MEV ↦ ν` map documented as a definitional gap.
- [ ] **PRF-04**: **P4 — the boxed closed form.** A verdict on the boxed `τ*_MEV`, resolving first *which relation it actually solves* (the research finds it equivalent to `∂π̂^σ/∂τ_MEV = ΔQ_v*`, not to `π^σ ≡^R π̂^σ`).
- [ ] **PRF-05**: **P5 — the τ↔λ bridge.** A verdict on whether `∂ν/∂λ_MEV` may be substituted for `∂ν/∂τ_MEV`, stated as a first-class obligation rather than an implicit step.
- [ ] **PRF-06**: Every obligation is stated in the Lean tree's native idiom (`Monotone`/`StrictAnti`/`ConvexOn`) wherever a sign or ordering claim suffices, rather than requiring a differential-calculus layer the tree does not have.
- [ ] **PRF-07**: Each obligation is frozen and sha-pinned at submission time, and its statement is byte-diffed against what returns — so a silently strengthened hypothesis cannot land unnoticed.
- [ ] **PRF-08**: Every returned proof passes an integration gate before being treated as landed: statement byte-diff, axiom check, zero `sorry`s, proof-body triage, dependency byte-identity, and provenance.
- [ ] **PRF-09**: Cheap detectors run **before** any Aristotle submission — a numerical harness checking whether `τ*` lands in `[0,1]`, and a back-substitution check on each closed form.
- [ ] **PRF-10**: Each obligation ships as a self-contained PROOF-REQUEST hand-off artifact, since no step of the proving pipeline executes in this worktree.

### Salvage

- [ ] **SAL-01**: For each refuted obligation, the *specific defect* is recorded — not merely that it failed, but which step, which line, and which error class.
- [ ] **SAL-02**: A corrected set-point law is derived under the selected frame, addressing the defects the verdicts expose.
- [ ] **SAL-03**: The corrected law is stated over an explicit domain, including the branch structure the kinks force (`(·)⁺` at the strike, the OTM branch where no interior solution exists, and the `min(·)` funded cap).
- [ ] **SAL-04**: The corrected law is itself submitted for verification, and carries its own verdict.
- [ ] **SAL-05**: Every assumption the corrected law rests on is declared as an assumption, never justified by citing a theorem that does not exist.

### EVM Feasibility

- [ ] **EVM-01**: **E0** — the fixed-point primitive inventory is refreshed against the live Plank tree, superseding the stale `EVM-CONTROL-PRIMITIVES-MAP.md`.
- [ ] **EVM-02**: **E1** — the feasibility analysis of the *verified* law: required primitives, saturate-never-revert behaviour, domain bounds, and cost envelope. Signatures only, no implementation.
- [ ] **EVM-03**: The `Σ_{i_K}` unbounded-loop gas problem is addressed — either `#i_K` is bounded and the bound stated, or the cost is declared unbounded.
- [ ] **EVM-04**: The null-space test (`HF = 0`) is run — if a disturbance-invariant controlled variable exists, `τ*` reduces to a stored constant and the per-swap cost collapses.

### Consolidation & Hand-off

- [ ] **HND-01**: A gap register lists every open item with severity and disposition (in-scope vs deferred), including the event-clock question and any obligation left as a hypothesis.
- [ ] **HND-02**: A consolidated spec integrates frame, verdicts, salvage, and EVM analysis, with each section delegating detail to its owning document.
- [ ] **HND-03**: The hand-off to a future implementation milestone is defined, with cross-worktree coordination points named and their owning peer sessions identified.
- [ ] **HND-04**: The stale v2-controller documents (`LEAN-MAP.md`, `EVM-CONTROL-PRIMITIVES-MAP.md`) are marked do-not-cite so they are not consumed as current.
- [ ] **HND-05**: Every artifact passes the two-step review (Reality Checker + Solidity Smart Contract Engineer) before it is treated as ready to execute.

---

## v2 Requirements

Deferred — tracked, not in this roadmap.

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

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| — | — | Pending |

**Coverage:**
- v1 requirements: 31 total
- Mapped to phases: 0
- Unmapped: 31 ⚠️

---
*Requirements defined: 2026-08-08*
*Last updated: 2026-08-08 after initial definition*
