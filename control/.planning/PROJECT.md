# MEV-Tax Set-Point Controller — Verified Design Spec

## What This Is

A control-theoretic design specification for the **optimal MEV tax** `\tau_{\text{MEV}}^\star` — the
protocol-side actuator that drives the volatility-instrument market's realized
liquidity-kernel payoff `\widehat\pi^\sigma` onto its contractual variance-swap payoff `\pi^\sigma`.
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
- [ ] Run the null-space test (`HF = 0`) as a **control-theoretic** result: does a
      disturbance-invariant controlled variable exist?
- [ ] The **formal controller document** — theory, entrywise plant, verdicts, typed
      hypotheses, salvage — plus a gap register and hand-off to the deferred
      EVM-feasibility and estimation tracks

### Out of Scope

- **The entire EVM-feasibility track** (user ruling 2026-08-08: *"we are only
  concerned with designing the formal document of the controller grounded on theory
  and formal results"*). Primitive and state-variable inventories, the call site,
  scale/rounding/saturation semantics, the `Σ_{i_K}` gas question — all moved to v2
  intact. The Solidity review's findings are preserved there, not discarded.
- **EVM implementation of `τ*_MEV`** (Plank / Solidity code) — `src/` is owned by peer
  `ul2inqpl` and would need coordination
- **Estimating the behavioral gains** — `∂L̄/∂π^φ` and `Ḡ_(ν,λ_MEV)` are stated as
  typed hypotheses here and measured in the deferred `EST-01` track
- **Closed-loop feedback law over `e^σ = |π^σ − π̂^σ|`** — the control target is an
  *optimal set-point*; a regulator wrapped around it is a later question
- **`spec/01_STATE_DELTA_ELASTICITY_CONTROLLER/`** — explicitly removed from scope
- **`(β_j, γ_j)` as actuators** — held fixed ∀t as a **modelling assumption of the
  source derivation**, and they enter as fixed parameters only.
  ⚠ CORRECTION (2026-08-08): the source note at line 70 justifies this by "the
  theorem that `(β_j, γ_j)` does not control `λ_MEV`". **No such theorem exists in
  the tree**, and `MevOptimization.lean:465` (T12 `mevMulti_mono_beta`) proves the
  opposite for `β` — raising the sigmoid centers raises the arbitrage hazard
  monotonically. What IS established is that the *unconstrained joint program* is
  degenerate, so `(β,γ)` are not *essential* there — a strictly weaker claim.
  Freezing them is therefore an assumption to be declared, not a consequence to be
  cited. Registered as an open item for the spec.
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
  | In-depth content | `cfmm-wt/lean4-spec/lean/vol_markets/` (23 files, 10 651 lines) |
  | This project's derivation | `notes/VOLATILITY_INTRUMENTS_MEV.md` (this tree, uncommitted) |
  | Read-only prior art | `.planning/research/v2-controller/` (13 docs) |
- **The plant, as written in the source.** Transcribed in the source's own glyphs —
  note `\phi` (fee) and `\varphi` (quote function) are DISTINCT symbols and must not
  be collapsed or decorated:
  state `x = [\phi, \nu, \pi^{\phi}, \pi^{\varphi}]^T` with
  `\pi^{\varphi} \equiv \pi^{\phi} - \pi^{\text{LVR}}`; exogenous input
  `u_{\text{ex}} = [\Delta Q_X, \Delta Q_M, \sigma^2(i(t))]^T`; control input
  `u_{\text{en}} = [\tau_{\text{MEV}}, \phi_M, \phi_X]^T`; output
  `y = [\pi^\sigma, \widehat\pi^\sigma]^T`; parameter block
  `\Theta_\sigma = [\sigma_K^2, \#_\sigma, s_\upsilon, \Delta Q_\upsilon]^T`. Replication target:
  `π^σ = ΔQ_v*(σ²(i(t)) − σ_K²)⁺` versus `π̂^σ = Σ_{i_K} L(i_K) π^l(σ(i_K; Θ_σ))`.
- **USER RULING 2026-08-08 — the `L` question, and what is behavioral vs mechanical.**
  This settles the pivot the whole verdict turned on.
  1. `L(i_K) = \bar L \cdot \ell(\xi, \iota; i_K)`, so
     `\partial L(i_K)/\partial \pi^{\phi} = \ell(\xi,\iota;i_K)\cdot \partial \bar L/\partial \pi^{\phi}`.
     The geometric kernel `\ell` is **geometry — invariant to the fee payoff**. Only
     aggregate `\bar L` responds.
  2. **Two liquidity unit systems.** `\Delta Q_v^{\star}` is in **vol-asset** `L` units,
     not pool `L` units — normative in `plank/notes/UNITS_AND_SCALES.md:70` ("RAW
     LIQUIDITY units — the Uniswap L dimension. The quantity of the priced **vol
     asset**"), `:71`, `:59-61`. Pricing a volatility level assigns it a tick;
     liquidity on the volatility tick is a DIFFERENT object from liquidity on the
     underlying's price tick. **Rule 9 is an identity on the vol axis and constrains
     nothing on the pool axis.** The "`L` overload" is not a notation slip — it is two
     assets.
  3. `\partial \bar L/\partial \pi^{\phi} > 0` is **BEHAVIORAL**: the LP supply
     response (attractive payoff draws liquidity in, unattractive drives it out).
     It is an **estimand observed from add/remove-liquidity events**, not a theorem.
     The same status applies to `\bar{\mathcal{G}}_{(\nu,\lambda_{\text{MEV}})}`.
     Both are formalized as named typed hypotheses; **neither is ever sent to
     Aristotle as a claim to prove.** Their identifiability from events is what makes
     an *adaptive* controller possible in a downstream milestone.

  **Consequence:** the `\tau^{\star}=1` refutation (Rule 9 zeroing the bracket) is
  **DEAD**. Refutations that SURVIVE this ruling: the direct monoid path
  (`\tau_{\text{MEV}}` reaches `\phi_{\text{total}}` via Rule 12 bypassing `\nu`, so the
  chain's "no other path" clause is still false), and the finding that the box solves
  `\partial\widehat\pi^\sigma/\partial\tau_{\text{MEV}} = \Delta Q_v^{\star}` rather than
  the stated replication relation.

- **USER NOTATION RULINGS 2026-08-08 (binding).**
  1. **Axis naming for liquidity — `L_{\sigma} \equiv \Delta Q_v^{\star}`.** The
     volatility-axis liquidity takes the glyph `L_{\sigma}`, identified with the
     **starred, stored** target vega — `UNITS_AND_SCALES.md:70`, RAW LIQUIDITY units,
     the Uniswap `L` dimension. Plain `L` / `\bar L` remain the **price axis** (pool
     liquidity). This supersedes the `L^{\text{pool}}`/`L^{\text{vol}}` superscript
     tags a plan proposed: the subscript carries the axis, and both letters come from
     the doc's own symbols.
     **Not** the unstarred `\Delta Q_v` (`UNITS_AND_SCALES.md:72`), which is the lens
     readout in *collateral base units per Algebra vol unit*, never stored — a
     sensitivity, not a liquidity. The star distinction is load-bearing.
     Consistent with the mint-sizing chain at `UNITS_AND_SCALES.md:114`
     (`L(i_K) = \Delta Q_v^{\star}\cdot\ell(\xi^{\star},\iota;i_K)`,
     `\sum_{i_K} L(i_K) = \Delta Q_v^{\star}`) — that row is labelled **mint SIZING**
     and is therefore the vol axis, corroborating the two-axis ruling rather than
     competing with it.
  2. **`\pi^{\varphi}` collision — rename the SOURCE side.** `DOC` keeps
     `\pi^{\varphi}` for its numbered **Definition 25** (portfolio value function,
     conic dual of the trading function; standing `\phi`/`\varphi` split stated at
     `DOC:919`). `SRC:28`'s composite `\pi^{\phi} - \pi^{\text{LVR}}` is the one that
     gets a new name. This follows the standing precedence — doc notation preserved,
     the conflicting symbol gets the new glyph — and it breaks the circularity, since
     `DOC:823` Definition 26 computes `\pi^{\text{LVR}}` **from** `\pi^{\varphi}`, so
     `SRC:28` currently places the glyph on both sides of its own definition.
     **The replacement glyph is not yet minted** — it must be built from the doc's own
     symbols and put to the user before use.

- **USER RULING 2026-08-08 — the objective is EXPOSURE MINIMIZATION, not replication.**
  The MEV tax does **not** enforce replication; that is the job of `\Theta_\sigma` and
  the ladder. The tax minimizes the **exposure of the realizable payoff
  `\widehat\pi^\sigma` to the adversarial environment**:

  \[
    \min_{\tau_{\text{MEV}} \in [0,1]} \ \mathcal{E}\bigl(\widehat\pi^\sigma;\lambda_{\text{MEV}}\bigr)
    \quad\text{s.t.}\quad \pi^\sigma = \widehat\pi^\sigma ,
    \qquad\text{FOC}\quad \frac{\partial\widehat\pi^\sigma}{\partial\tau_{\text{MEV}}} = 0 .
  \]

  The replication relation is a **feasibility region the optimization is constrained
  to**, NOT the objective. `SRC`'s "target replication relation" sentence misstates
  this and is an **erratum** (still live in the source as of `c521af5`). The objective
  functional `\mathcal{E}` is **not yet given a form** — naming it, or writing it
  explicitly, is an open notation decision.

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
| Aristotle receives only the **mechanical** claims; behavioral gains are typed hypotheses | User ruling 2026-08-08: `∂L̄/∂π^φ` and `∂ν/∂λ_MEV` are LP-supply estimands identified from liquidity events, not provable propositions | ✓ Good — settled |
| `Σ_{i_K} L(i_K)`'s `L̄` is **pool** liquidity; `ΔQ_v★` is **vol-asset** liquidity | User ruling 2026-08-08, confirmed by `UNITS_AND_SCALES.md:70`. Kills the `τ*=1` refutation; the `L` overload is two assets, not one ambiguous symbol | ✓ Good — settled |
| Stop at verified design; no EVM implementation | Mirrors how v2-controller was scoped; `src/` is peer-owned | — Pending |
| `(β_j, γ_j)` and `φ_M` are parameters, not actuators | Both are **declared assumptions** of the source derivation. The `(β,γ)` justification originally cited a non-existent non-control theorem — contradicted by T12 `mevMulti_mono_beta` | ⚠️ Revisit — assumption, not theorem |
| v2-controller research is read-only input | Saves re-deriving the Lean/GAMS/EVM-primitive maps; v2 covers the spatial axis, this covers the event-time axis | — Pending |
| Two-step review runs before execution, not deferred | v2-controller deferred its SPEC-04 review and still owes it | — Pending |

---
*Last updated: 2026-08-08 after initialization*
