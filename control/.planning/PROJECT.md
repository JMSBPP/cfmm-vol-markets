# MEV-Tax Set-Point Controller — Verified Design Spec

## What This Is

A control-theoretic design specification for the **optimal MEV tax** `τ*_MEV` — the
protocol-side actuator that drives the volatility-instrument market's realized
liquidity-kernel payoff `π̂^σ` onto its contractual variance-swap payoff `π^σ`.
The market is modelled as a **multivariable (MIMO) state-space plant in event time**
(`t → t+1 := event swap`), with exogenous disturbance input `u_ex` and protocol
control input `u_en`; the deliverable is the derivation of the optimal set-point on
that plant, together with **machine proofs (Lean 4 / Aristotle)** of the four claims
the derivation rests on, and an EVM-feasibility analysis of the resulting law.

This project produces a **design specification, not an implementation**. It hands
off to a downstream implementation milestone.

## Core Value

**The artifact under construction is the artifact under proof.** The boxed closed
form for `τ*_MEV` currently carries the author's own `> note: This needs
verification`. If everything else is deferred, this project must return a *verdict*
on that closed form — PROVEN or REFUTED, axiom-clean, with the counterexample if it
falls. A refutation is a successful outcome; an unverified restatement is not.

## Requirements

### Validated

(None yet — this is a fresh project; the Lean results it builds on are *inputs*,
recorded under Context, not deliverables of this project.)

### Active

<!-- Hypotheses until shipped. -->

- [ ] Curate the control-theory basis (Ogata; multivariable feedback control) and
      select/justify the frame for **set-point optimization on a MIMO plant with
      disturbance inputs**, against EVM constraints
- [ ] Transcribe the event-time state-space representation
      (`x`, `u_ex`, `u_en`, `y`, `Θ_σ`) into a formal statement, preserving the
      source notation exactly
- [ ] **Prove or refute: well-posedness** of the
      `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition over event time, and the
      legitimacy of optimizing a *set-point* given `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j)`
      frozen
- [ ] **Prove or refute: the 5-factor channel** —
      `∂π̂^σ/∂τ_MEV = (∂π̂^σ/∂L)(∂L/∂π^φ)(∂π^φ/∂φ)(∂φ/∂ν)(∂ν/∂τ_MEV)`,
      i.e. that `τ_MEV` reaches the output through no other path
- [ ] **Prove or refute: the sign** `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0`, currently
      argued in prose and assumed constant
- [ ] **Prove or refute: the boxed closed form** for `τ*_MEV` obtained by solving
      the replication relation `π^σ ≡^R π̂^σ`
- [ ] EVM-feasibility analysis of the resulting law: required fixed-point
      primitives, saturate-never-revert behaviour, bounds, cost envelope
- [ ] Consolidated design spec integrating theory + proofs + EVM analysis, plus a
      gap register and hand-off to the implementation milestone

### Out of Scope

- **EVM implementation of `τ*_MEV`** (Plank / Solidity code) — this project stops at
  the verified design; `src/` is owned by peer `ul2inqpl` and would need coordination
- **Closed-loop feedback law over `e^σ = |π^σ − π̂^σ|`** — the control target is an
  *optimal set-point*; a regulator wrapped around it is a later question
- **`spec/01_STATE_DELTA_ELASTICITY_CONTROLLER/`** — explicitly removed from scope
- **`(β_j, γ_j)` as actuators** — frozen by the theorem that they do not control
  `λ_MEV`; they enter as fixed parameters only
- **`φ_M` as an actuator** — fixed at `φ̄_M ∀t` by assumption; `φ_X(t) = Φ(Θ_φ; σ²(i(t)))`
- **Any edit to the repo-root `.planning/`** — the shared v1 (open-loop plumbing,
  in-flight across peers) and the v2-controller milestone are read-only here
- **Re-deriving the static/spatial controller** — v2-controller covers the tick-lattice
  (spatial index) case; this project is the time/event-indexed axis v2 excluded

## Context

- **Planning is isolated by construction.** This project's root is
  `control/.planning/` inside the `evm-controller` worktree. GSD anchors `.planning/`
  strictly at the directory it runs from (verified: no walk-up; `--cwd` override
  available), so the repo-root `.planning/` is untouched. All GSD commands for this
  project must be run with `--cwd control` (or from `control/`).
- **Context sources, in the order the user specified:**
  | Role | Path |
  |------|------|
  | Entry point | `cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` (1636 lines; `CONTROL_OPERATORS`, `MEV`, `FLAIR`, `JIT`, `GREEKS`) |
  | In-depth content | `cfmm-wt/lean4-spec/lean/vol_markets/` (37 files) |
  | This project's derivation | `notes/VOLATILITY_INTRUMENTS_MEV.md` (this tree, uncommitted) |
  | Read-only prior art | `.planning/research/v2-controller/` (13 docs) |
- **The plant, as written in the source.** State `x = [φ, ν, π^φ, π^φ̃]ᵀ` with
  `π^φ̃ ≡ π^φ − π^LVR`; exogenous input `u_ex = [ΔQ_X, ΔQ_M, σ²(i(t))]ᵀ`; control
  input `u_en = [τ_MEV, φ_M, φ_X]ᵀ`; output `y = [π^σ, π̂^σ]ᵀ`; parameter block
  `Θ_σ = [σ_K², #_σ, s_υ, ΔQ_υ]ᵀ`. Replication target:
  `π^σ = ΔQ_v*(σ²(i(t)) − σ_K²)⁺` versus `π̂^σ = Σ_{i_K} L(i_K) π^l(σ(i_K; Θ_σ))`.
- **Relevant existing Lean results (inputs, already landed).** `TauMevAlgebra.lean`
  (τ_MEV monoid = intensity not targeting; split = incidence not intensity),
  `MevOptimization.lean`, `MevJointProgram.lean`, `JitLiquidity.lean`, `TauJit.lean`,
  `FlairOptimization.lean`, `VolInstrument.lean`. Carry-forwards that constrain this
  work: the unconstrained joint program is **degenerate** so `(β,γ)` is not essential
  and the degeneracy-breaker lies outside `Θ_φ`; **T24 was refuted** by counterexample;
  the Capponi–CES interior embedding was machine-refuted.
- **Aristotle is the proving mechanism, not a reviewer.** The established workflow is:
  draft `sorry`'d statements locally → Aristotle proves → integrate the returned tar
  into the Lake project. Send the *document* to Aristotle rather than hand-drafting
  proofs.

## Constraints

- **Planning root**: `control/.planning/` — never write to the repo-root `.planning/`.
- **Branch / delivery**: work lands on `feat/evm-controller`, ships via PR → `develop`
  (gate-green). Peer ownership: `src/` and Plank belong to `ul2inqpl`; the Lean
  project and `model/spec/*.md` belong to the Lean4+math session; `test/` to the
  Solidity-testing session.
- **Notation is binding**: preserve the user's and the source documents' notation
  exactly. No interpretive renaming, no convenience abbreviations, no new symbol
  minted without discussing it first. Conflicting *external* symbols get new symbols,
  recorded in a notation-map paragraph. This applies to Aristotle prompts too.
- **Curvature is `κ_φ`** (never `χ`); tilde `λ̃` denotes the incidence operator versus
  plain-`λ` hazard; probabilities are written `ℙ_event`.
- **Aristotle operational rules**: never run parallel `aristotle continue` on the same
  project; on `OUT_OF_BUDGET` run a single `continue` on the same project rather than
  a fresh scoped submit; the CLI requires full UUIDs.
- **Two-step review**: every pre-commit artifact (spec, plan, roadmap) passes Reality
  Checker + one specialist in parallel before it is committed or executed.
- **Design spec only**: no Plank/Solidity implementation of the control law.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Isolated planning root at `control/.planning/` | The repo-root `.planning/` is shared v1 planning in flight across peers; this work must not touch it | — Pending |
| Control target = **optimal set-point** `τ*_MEV`, not a feedback law over `e^σ` | User decision; the set-point is what the source derivation actually solves for | — Pending |
| The set-point derivation is itself the proof obligation | The boxed `τ*_MEV` is marked "needs verification" by its author — shipping it unverified would be the failure mode | — Pending |
| All four claims go to Aristotle (closed form, 5-factor channel, `∂ν/∂λ_MEV > 0` sign, state-space well-posedness) | The closed form is not independently meaningful if the channel or the sign fails | — Pending |
| Stop at verified design; no EVM implementation | Mirrors how v2-controller was scoped; `src/` is peer-owned | — Pending |
| `(β_j, γ_j)` and `φ_M` are parameters, not actuators | The non-control theorem for `(β,γ)`; `φ_M ≡ φ̄_M ∀t` by assumption | — Pending |
| v2-controller research is read-only input | Saves re-deriving the Lean/GAMS/EVM-primitive maps; v2 covers the spatial axis, this covers the event-time axis | — Pending |
| Two-step review runs before execution, not deferred | v2-controller deferred its SPEC-04 review and still owes it | — Pending |

---
*Last updated: 2026-08-08 after initialization*
