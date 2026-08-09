# Phase 6b: Research, Venue, and Estimating `Ḡ = ∂ν/∂λ_MEV` - Context

**Gathered:** 2026-08-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Source the prior empirical work, derive `ν` and `λ_ARB` in a real venue's own state
variables, choose the venue **from that research**, and then either estimate `Ḡ` behind a
pre-registered gate or terminate with a reportable verdict.

`Ḡ = ∂ν/∂λ_MEV` is the only non-structural factor in `Proposition16_corrected_law`, and
establishing its **sign** is simultaneously the test of `H2_dnu_dlamMEV_pos`, which both
landed Lean bundles carry undischarged.

**Fixed by the roadmap, not reopened here:** the phase is 13 requirements — `LIT-01`…`LIT-04`
and `EST-01`…`EST-09`. Adding capabilities is out of scope; this document decides *how*.

</domain>

<decisions>
## Implementation Decisions

### Method — how the phase is actually executed

- **The phase runs the `structural-econometrics` skill and specialized agency agents, fed by
  the literature research outputs.** This is a user instruction (2026-08-09), not an
  inference. Research first, skill second, agents third — never the reverse.
- **`structural-econometrics` is scoped "before any estimation or simulation code"**, so the
  phase's core output is a **derived specification plus a pre-registration**, not a fitted
  model. Whether estimation code runs at all is decided by what the spec derivation returns —
  it is not assumed in either direction, and the planner must not write plans that presume
  data gets touched before `EST-02` reports.
- **`anti-fishing-replication` is the standing guard.** It fires on exactly the situation this
  phase is most exposed to: a result short of its target and someone proposing to proceed,
  footnote, swap spec, drop outliers, or add "one more robustness." Any plan that reaches a
  short result invokes it before writing anything else.

### Estimation scope and freeze

- **The pre-registration is a committed file, sha-pinned, and its commit sha is quoted in
  every downstream document.** Git history is what makes the ordering auditable — no separate
  hash ledger. This matches the sha-pinning discipline already used against
  `UNITS_AND_SCALES.md` and `SRC`.
- **Terminal "not identified" ships a verdict document AND a named alternative-data
  proposal.** User decision, made with the risk stated: a proposal can read as a
  re-specification invitation. **Guard, binding:** the proposal names what data *could*
  identify `Ḡ` and does **not** act on it, does not re-open the frozen instrument menu, and
  is written only after the verdict is recorded — never as an alternative to recording it.
  `anti-fishing-replication` is invoked at that boundary.
- The verdict back-propagates into `MevTaxControl.lean` and `MevTaxProgram.lean` against
  `H2_dnu_dlamMEV_pos` per `EST-05`, rather than waiting for Phase 7's gap register.

### Data route

- **Dune MCP is the primary data route.** Already connected, carries Algebra pool tables and
  block-level data, needs no new infrastructure, and is cheap to abandon if the dispersion
  measurement kills the exercise.
- **The plank events→subgraph layer is NOT the route.** It indexes *our* hook, not Algebra's
  pools, and its GAMS consumer has no ingestion path built
  (`plank/.planning/events-subgraph-gams-SPEC.md`). Wrong venue for an external-pool study.
- **Whether `ν` is reconstructible from an external venue's events is a question for the
  literature to answer, not a decision made now** (user ruling). `LIT-01`…`LIT-03` must
  establish whether prior work has constructed `ν` or a defensible analogue from venue events,
  and with what read path. `EST-01`'s verdict follows that finding.

### Venue and chain selection

- **The chain and pool set are OUTPUTS of the research, not priors** (user ruling). Decision
  #13 settles the *codebase* (Algebra Integral) and explicitly leaves the *chain* open,
  because `Δt` is chain-level and pool selection buys zero instrument variation.
- **`LIT-04` plus the sweep return 3–5 ranked candidates**, each carrying: measured `Δt`
  dispersion as a number, Algebra deployment depth, and the specific identification threat it
  presents. **The user picks. The freeze follows the pick.** This is a checkpoint inside the
  phase, not a research deliverable that proceeds automatically.
- **If no candidate has sufficient `Δt` dispersion, that is terminal non-identification.** No
  instrument substitution — the `υ` precedent applied. The roadmap's ban on post-hoc
  substitution stays binding.

### Winner's-curse resolution (RULING — resolves a tension this discussion created)

Ranking candidates *by measured dispersion* means dispersion is measured **before** the
freeze, which is precisely the selection-then-test problem `EST-09` registers: an F reported
on an argmax-selected sample is upward-biased and voids the nominal size of the
pre-registered threshold.

**Therefore `EST-09`'s split-sample is MANDATORY, not optional:**

1. Measure dispersion and rank candidates on **window A**.
2. User picks; specification, thresholds and clustering are frozen and sha-pinned.
3. Estimate on **window B**, disjoint from A.

If a split is infeasible on the chosen venue, the first-stage F is labelled **descriptive**
and the threshold rule is stated to be void — it is not quietly reported as if pre-registered.

### Research output shape

- **`LIT-01` uses targeted extraction against a fixed schema**, not full reads. Six fields per
  paper: identification strategy, data source, unit of observation, instrument used, estimated
  effect size, transfer verdict (transfers / transfers-with-modification / does-not-transfer,
  with the reason). The schema is what makes the register comparable row-to-row and auditable.
  All **fourteen** PDFs get a row, including ones with no empirical design — "no empirical
  content" is a valid verdict, an omission is not.
- **`LIT-02` uses the `lit-review` skill**, which dispatches parallel sub-agents across three
  search dimensions and stress-tests the synthesis with an adversarial referee until
  convergence. The adversarial pass is the point: this sweep is the input everything
  downstream rests on, and "what did we miss" is the failure mode.
- **`LIT-03` (non-arXiv on-chain material) is hand-run**, not routed through `lit-review` —
  its academic screening does not apply. Tagged lower-rigor as a class.
- **One committed register: `control/spec/RESEARCH-REGISTER.md`**, one row per source across
  all three classes, closing with the **instrument-selection rule written before any
  dispersion is measured**. Sha-pinned; the sha is quoted downstream. Adding a source after
  `EST-03` returns is a protocol violation recorded as one.

### Claude's Discretion

- Exact Dune query construction and table selection.
- How the six-field schema is laid out in the register (table vs per-source block).
- Which specialized agency agents are dispatched for which sub-task, beyond the named skills.
- Plan-level task decomposition within each of the seven plans.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

Paths are relative to the `evm-controller` worktree root
(`~/cfmms-playground/cfmm-wt/evm-controller/`) unless prefixed `../`, which reaches the
sibling peer worktree. **Peer trees are READ-ONLY** — findings are routed as messages and
proposed diffs, never edited in place.

### The approved econometric design
- `control/spec/ECONOMETRICS-DESIGN.md` — the estimand, the `Δt` exclusion restriction, the
  staged gate, the logistic form `ν = a + b·σ_ℓ(c(λ−d))`, the anti-fishing discipline, and §6's
  five open items. **Note §31 classifies `∂ν/∂λ_MEV` as "Behavioural. Not derivable."** — Phase
  6a's `NEC-04` reopens that ruling and this phase must not assume either verdict.

### Phase definition and requirements
- `control/.planning/ROADMAP.md` — Phase 6b section: goal, six success criteria, seven plans,
  and the hard-gate semantics. **The gate retains full force**; the softening proposed on
  2026-08-09 was withdrawn.
- `control/.planning/REQUIREMENTS.md` — `LIT-01`…`LIT-04`, `EST-01`…`EST-09`, and open items
  O1–O8. **O4** (`σ` vs `σ²` units) is a direct blocker on the estimating equation.

### The controller source and its carriers
- `notes/VOLATILITY_INTRUMENTS_MEV.md` — `SRC`. `Theorem 29` (:113), `Theorem 30` (:122),
  `Proposition 12` (:141), `Definition 36` (:172), `Proposition 13` (:184), `Rule 13` (:103).
  Pinned at commit `cf386de`, blob `04bac0a`.
- `../plank/notes/VOLATILITY_INSTRUMENTS.md` — `DOC`. Definition 18 (the fee schedule, which
  carries **both** `σ` and `ν`), Definition 22 (:931, the discrete `λ_ARB`), Definition 23
  (:1037–1041, `λ_MEV = λ_ARB ⊕ λ_sandwich` and the Angstrom-regime scoping), the
  `π^LVR` alignment (:995 — an **assumed hypothesis** of a σ-varying-REFUTED theorem, not a
  result), and the `[M8]` caveats (:1047).
- `../plank/notes/UNITS_AND_SCALES.md` — normative units table, sha-pinned and peer-owned.
  `ΔQ_v★` is vol-asset `L` at :70.

### Lean carriers for back-propagation (EST-05)
- `control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean` —
  carries `H2_dnu_dlamMEV_pos` undischarged.
- `control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean` —
  `Proposition16_corrected_law` (:1054), `Theorem34_opposed_signs`,
  `Theorem36_no_interior_root_off_the_band`, and the `Proposition15_*` second-order family
  including the undetermined-minimiser result (:823) that open item **O2** names.

### The venue's fee machinery (why Algebra Integral is structurally comparable)
- `../plank/src/lib/premium/AdaptiveFee.plk` — our `φ` is a port of Algebra's `AdaptiveFee`;
  `get_fee` (:72) takes a `uint88` volatility and a packed `u144` config. Same functional form
  and same oracle object as the venue, not an analogue.
- `../plank/src/types/premium/AlgebraFeeConfiguration.plk` — the `Θ_φ` parameter block.

### The 14 internal PDFs (LIT-01 — every one gets a row)
- `../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf` — the anchor; §7.3 eq. (27)
  is the missing demand-elasticity term the `[M8]` caveats name.
- `../plank/refs/mev/CapponiJiaZhuJITLiquidity.pdf`, `CapponiJiaAdoptionDEX.pdf`,
  `CapponiCarteaDrissiDiscreteClearing.pdf`, `CapponiJiaWangLitToDark.pdf`,
  `CapponiZhuTimeboost.pdf` — the five Capponi papers.
- `../plank/refs/mev/MazorraDellaPennaCFMMWelfareMEV.pdf`,
  `KulkarniDiamandisChitraTheoryMEV1.pdf`, `ChitraTheoryMEV2Uncertainty.pdf`,
  `DaianEtAlFlashBoys2.pdf`, `GuoInvarianceMEV.pdf`, `ObadiaEtAlCrossDomainMEV.pdf`.
- `../plank/refs/flair/MilionisWanAdamsFLAIR.pdf`,
  `CampbellBergaultMilionisNutzOptimalFees.pdf`.

### Skills this phase invokes by name
- `structural-econometrics` — derive the formal specification from the economic question,
  **before any estimation code**. The phase's core method.
- `anti-fishing-replication` — the guard, invoked at every short-result boundary and before
  the alternative-data proposal is written.
- `lit-review` — `LIT-02`'s arXiv sweep with its adversarial-referee convergence.
- `dimensional-analysis` — open item **O4**, the `σ` vs `σ²` question, which is dimensional
  rather than bookkeeping: in `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))`, `φ` is dimensionless and
  `√(2/Δt)` carries time^(−1/2), so `σ` must be a rate.
- `python-panel-data` / `stata-regression` / `r-econometrics` — available if and only if the
  spec derivation returns something to estimate.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`AdaptiveFee.plk`** — the ported Algebra fee function and its `uint88` volatility oracle.
  This is what makes the venue choice structural rather than convenient: `Φ`'s functional form
  and the oracle object are the same objects, so `Θ_φ` maps across without reinterpretation.
- **Dune MCP** — connected, with Algebra pool tables and block-level data. No new
  infrastructure needed to measure `Δt` dispersion or pull swap-level state.
- **`ECONOMETRICS-DESIGN.md`** — an already-approved design, two-step reviewed. This phase
  implements it under added discipline; it does not re-derive it.

### Established Patterns
- **Sha-pinning for cross-document references** — used against `UNITS_AND_SCALES.md` and
  `SRC`. The pre-registration freeze reuses this rather than inventing a hash ledger.
- **Terminal verdicts are deliverables** — the `υ` exercise ended in "this market cannot
  identify `υ`" and was correctly never reopened. Same discipline governs here.
- **Behavioral gains are never sent to the proving pipeline** — only algebraic identities are.
  `H1` and `H2` stay typed hypotheses in Lean; data discharges or refutes them.

### Integration Points
- **`EST-05` writes back into two Lean files** in `control/aristotle/*-result/` — the verdict
  is recorded against `H2_dnu_dlamMEV_pos` in both.
- **Phase 6a's `NEC-04`** can narrow the estimand before a regression is specified, and
  carries the recomposition rule (`sign(residual) ⇏ sign(total)`) that keeps `EST-05`'s
  back-propagation honest under a "partially derivable" verdict.
- **Phase 1's units ledger** settles **O4**, which the estimating equation cannot be written
  without.

### Dependencies NOT yet met (plans must state what they inherit, not assume it)
Phases 1, 2, 3 and 6a are all unexecuted. Planning proceeds anyway (user ruling: "plan now,
execute later"), but every plan names what it inherits: **O4** units from Phase 1, the
event-clock ruling from Phase 2, the hypothesis discipline from Phase 3, and `NEC-04`'s
coupling verdict from Phase 6a.

</code_context>

<specifics>
## Specific Ideas

- "Phase 6b uses and has the instruction to run the structural-econometrics skill and
  specialized agents from the agency using the results from the research that looks at the
  literature." — the method is fixed: **research → skill → agents**.
- Whether `ν` is externally reconstructible is "what the research literature must show" — the
  literature answers it; this document does not pre-empt it.
- Chain and pool selection comes "after research on the most appropriate pool returns and
  gives options" — 3–5 ranked candidates with measured dispersion, and the user picks.
- The `υ` precedent is the template for every terminal branch: a delivered result, never a
  prompt to re-specify.

</specifics>

<deferred>
## Deferred Ideas

- **Dynamic-fee natural experiments** as a research source class (Algebra `AdaptiveFee`
  rollouts, Uniswap fee-tier migrations — the closest thing to an exogenous shock to `φ` that
  exists). Offered and **declined by the user** on 2026-08-09, recorded as Decision #14.
  Reopening is a scope change, not a research decision.
- **Running the estimation as its own milestone**, if the `structural-econometrics` derivation
  returns a specification but executing it exceeds this project's document scope.
- **The GAMS ingestion path** (`cfmm-gams` `DATA-01`…`DATA-08`) — specified, unbuilt, and
  owned by the GAMS session. Not this phase's concern even though the events layer touches it.
- **Estimating `H1` (`∂L̄/∂π^φ`)** — `EST-03`'s specification tests `H2` only, so `H1` stays
  undischarged on every branch of this phase. Phase 6a's `NEC-07` records that it scales and
  signs the on-chain loop gain. A second estimation exercise, not this one.

</deferred>

---

*Phase: 06B-research-venue-and-estimating-mev*
*Context gathered: 2026-08-09*
