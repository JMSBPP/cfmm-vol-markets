# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-08)

**Core value:** The artifact under construction is the artifact under proof — return a *verdict* on the boxed `τ*_MEV`, and a corrected law where it refutes.
**Status of the core value:** ✅ **DELIVERED.** The box is refuted factor by factor (`auditTable`, M24) and the corrected law is derived and machine-verified (`Proposition16_corrected_law`). What remains is the supporting apparatus, the empirical `Ḡ`, and the document.
**Current focus:** Phase 1 — Ground Truth, Notation, and the Rulings Triage (plans staged, unexecuted). **Phase 6 was split into 6a/6b on 2026-08-09**, and the free-option premise was **refuted at the review gate the same day**; Phase 1 execution is unchanged and still owed.

## Current Position

Phase: 1 of 8 (Ground Truth, Notation, and the Rulings Triage) — **remaining** work
Plan: 0 of 5 in current phase (all 5 written, reviewed twice, refreshed once; staged and uncommitted)
Status: **Ready to execute** — not "ready to plan"
Last activity: 2026-08-09 — Phase 6 **SPLIT** into 6a (On-Chain Fixed-Point Iteration of the Law, `NEC-*`) and 6b (Research, Venue, Estimation, `LIT-*` + `EST-*`), with 6a ordered first; the free-option premise **REFUTED at the review gate** and `EST-04`'s demotion withdrawn

Progress: [█░░░░░░░░░] ~16% (2 of 8 phases complete; 9 of 58 requirements delivered)

> The percentage fell from 31% without any work being lost: the denominator grew from a
> corrected 40 requirements to 58, and the phase count from 7 to 8. The prior "39" was an
> arithmetic slip carried in **both** `REQUIREMENTS.md`'s summary line and `ROADMAP.md`'s
> coverage table — `NOT-*` has ten members, not nine.

**Phase status at a glance:**

| Phase | Status |
|-------|--------|
| 1. Ground Truth, Notation, Rulings Triage | Planned, **not executed** (5 plans on disk) |
| 2. Entrywise Plant and Control Frame | **Partial** — frame research exists; `NOT-04`, `FRM-05` undone |
| 3. Verification Protocol, Ratified Retroactively | **Ad hoc** — applied by hand; protocol unwritten, `PRF-09` detectors never ran |
| 4. Verdicts — P1, P2, P5 (BRANCH GATE) | ✅ **COMPLETE** (Bundle 1, out of order) — branch gate FIRED: P2 REFUTED |
| 5. The Set-Point Law — Verdict and Salvage | ✅ **COMPLETE** (Bundle 2, out of order) — corrected law delivered |
| 6a. On-Chain Fixed-Point Iteration of the Law (NEW) | Not started — **runs before 6b**; founding premise refuted at the gate, phase re-scoped |
| 6b. Research, Venue, and Estimating `Ḡ = ∂ν/∂λ_MEV` | Not started — now carries `LIT-01`…`LIT-04` and `EST-06`…`EST-09`; **fully load-bearing**, the demotion was withdrawn |
| 7. Formal Controller Document and Hand-off | **In progress** — `SRC` restructured; PR #22 → `develop` open |

**Remaining execution order:** 1 → 2 → 3 → 6a → 6b → 7 (sequential; `parallelization: false`).

## Performance Metrics

**Velocity:**
- Total plans completed: 0 (Phases 4 and 5 were delivered by direct Aristotle submission, not through GSD plans)
- Bundles landed: 2 (1985 Lean lines, 96 declarations, 0 `sorry`)
- Average duration: —
- Total execution time: not tracked for the direct-submission route

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 4 | 0 (direct submission) | — | — |
| 5 | 0 (direct submission) | — | — |

**Recent Trend:**
- Last 5 plans: —
- Trend: — (the two delivered phases bypassed the plan mechanism entirely; this is recorded as the route taken, not retrofitted)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Recent decisions affecting current work:

- **The boxed `τ*_MEV` is REFUTED and replaced (2026-08-08).** The corrected law, **with a signed denominator**, is `τ*_MEV = 1 + (1−φ_X)/((∂φ/∂ν)(∂ν/∂τ_MEV))`. It is **implicit, not closed** — all three factors are evaluated at `ν(τ*)`. Domain: `τ* < 1` always; `τ* > 0` iff the gate dominates. The absolute-value form `1 − (1−φ_X)/|·|` is conditional on the M21 signs and **must never be quoted as the theorem.**
- **The branch gate fired on P2 REFUTED (2026-08-08).** `Corollary29_five_factor_product_not_total_derivative` exhibits the witness; `Theorem29_monoid_path_is_direct` names the second path. Salvage became the main work, exactly as the branch table prescribed. The gate is not re-run.
- **Estimation promoted from v2 to v1 (2026-08-08).** `Ḡ = ∂ν/∂λ_MEV` is the only empirical object in the corrected law, and estimating it **is** the test of `H2`. Design approved: `control/spec/ECONOMETRICS-DESIGN.md` — `Δt` as instrument (clean exclusion), logistic-in-`λ` functional form, and a **staged gate** with Stage 1 (sign test) hard-gating Stage 2 (magnitude).
- **Decision #10 (`Δt` exogenous or endogenous) is DEFERRED to Phase 6** and is **NOT closed** in the doc layer. It is adjudicated by the structural-econometrics discipline in `EST-02`.
- **Scope (2026-08-08 user ruling):** the deliverable is the formal controller document. The entire EVM-feasibility track is v2 (`EVM-01a/01b/02/03/05/06`). `FRM-05` survives as pure theory with **no on-chain cost claim attached**.
- **Behavioral gains are hypotheses, never proved (2026-08-08):** `H1_dLbar_dpiPhi_pos` and `H2_dnu_dlamMEV_pos` are LP-supply estimands. Neither is ever sent to Aristotle. **`EST-03`'s sign test is what discharges or refutes them** — this replaces the old "magnitudes are v2" disposition.
- **`L` is two assets (2026-08-08):** `L(i_K) = L̄·ℓ(ξ,ι;i_K)` with `ℓ` geometry-invariant; `ΔQ_v★` is vol-asset L (`UNITS_AND_SCALES.md:70`), `L̄` is price-axis pool liquidity. This killed the `τ* = 1` refutation.
- **The "controller without `Ḡ`" premise is REFUTED (2026-08-09, Decision #15).** Composing `Theorem 30` + `Theorem 29` + `∂ν/∂τ = Ḡ·(∂λ/∂τ)` gives `∂π̂^σ/∂τ = (∂π̂^σ/∂φ)·[(1−φ_M)(1−φ_X) + (∂φ/∂ν)·Ḡ·(∂λ/∂τ)]` — `Ḡ` multiplies one of two bracket terms, so **evaluating the residual is evaluating `Ḡ`**. Both review-gate reviewers derived it independently; verified before acceptance. **`EST-04`'s demotion is WITHDRAWN** and the Estimation category is fully load-bearing on every branch. Phase 6a survives re-scoped as **on-chain fixed-point iteration of the `Ḡ`-dependent law** — it removes a stored constant and tracks drift, and is **not** a hedge against the estimation failing.
- **The sign/magnitude split as first written was FALSE.** Loop direction is `sign(∂²π̂^σ/∂τ²)`, not `sign(Ḡ)`; the plant is discrete-time so a stability certificate needs a **bound on `|Ḡ|`**; and **`H1`** (`∂L̄/∂π^φ`) scales and signs the loop gain through the residual's prefactor (`Proposition 12`) while `EST-03` tests `H2` only — so **`H1` is undischarged on every branch**.
- **`λ_MEV = λ_ARB` requires the Angstrom regime** (`DOC:1041`), which neither Algebra Integral (continuous execution) nor a Uniswap v4 hook under one-hook-per-pool exclusivity provides — and the sandwich-zero result is **UNFORMALIZED, no carrier** (`DOC:1026`). `NEC-01` checks the precondition instead of asserting it.
- **The on-chain `λ` is an OBSERVER, not a measurement (O6), and it is SELF-CONFIRMING (O7).** `ℙ_{Δ_ARB}` is leading-order and quasi-static (`[M8]`), so an accumulator emits a model output; and because `λ_ARB` depends on `φ`, which contains `τ_MEV`, the controller's action moves its own measurement exactly as the model prescribes — the loop cannot detect model error and converges to *the model's root*. Also **O8**: `λ_ARB` is a monotone divergent accumulator, so `Ḡ → 0` asymptotically and the loop **stalls**; whether `λ` needs a decay or window is OPEN.
- **Decision #11 (where on-chain the `∂ν/∂λ_MEV` feedback is implemented) is OPEN and routed to Phase 6a (`NEC-05`, `NEC-07`).** It cannot be chosen before the precondition and constructibility verdicts, and its own phrasing presumes an object those verdicts decide.
- **Codebase = Algebra Integral, CHAIN = TBD (Decision #13, scope corrected).** The `AdaptiveFee`-port argument settles `φ`'s functional form, **not the instrument**: `Δt` is chain-level, so pool selection buys zero instrument variation. Chain is selected on measured `Δt` dispersion, and `EST-08` registers the likelier-fatal threat — `Δt ⟂̸ σ`, since missed slots cluster with volatility and `σ` enters `φ`.
- **Research sources = internal re-read + arXiv + non-arXiv on-chain material (Decision #14).** Dynamic-fee **natural experiments** were offered and **declined by the user**; recorded as a decision, so reopening is a scope change.

### Pending Todos

- Refresh three Phase 1 plans before executing them: `01-02` must carry Decision #10 as DEFERRED-TO-PHASE-6; `01-03` must carry the retroactive reconciliation of the symbols M11–M24 minted ahead of the register, plus open item O3; `01-05` must carry open item O4 and the bundles' reviewed-after-landing register entries.
- Phase 1's five plans are staged and uncommitted (`git status` shows all five as `M`).
- **`SRC` re-pin owed.** Commit `cf386de` restructured `notes/VOLATILITY_INTRUMENTS_MEV.md` into 14 numbered blocks and moved every line; the Phase 1 plans and the research docs still cite `SRC:NNN` against the superseded pin. Blocks are now citable **by number**, so this is the last re-pin the plans should ever need.
- **Phases 6a and 6b have no plans on disk** — only requirement mappings and expected plan titles. `/gsd:plan-phase 6a --cwd control` is the entry point **after Phases 1–3 land**; the execution order is sequential with `parallelization: false` and there is no pull-forward exception.

### Blockers/Concerns

**Standing open items (O1–O5), carried explicitly and routed:**

- **O1 — `#print axioms` is UNVERIFIED on both bundles.** Axiom-cleanliness is asserted from 0 `sorry` and the absence of `axiom` declarations, not from a sweep. A Mathlib build is required. → Phase 3 criterion 1. **Until it runs, "axiom-clean" is a claim, not a check.**
- **O2 — the FOC root is NOT established to be the minimiser.** `Proposition15_level_reading_second_order_undetermined` (`MevTaxProgram.lean:823`) exhibits the undetermination; `Proposition15_single_crossing_gives_minimum` (:890) is conditional on a single-crossing-from-below property that **nothing proves**. → Phase 7 gap register; load-bearing for Phase 6.
- **O3 — `φ_X` carries `ν`-dependence** (`DOC` Definition 18) but `Rule 13` at `SRC:69` writes `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` with no `ν` argument. Rule 13's signature may be incomplete. → Phase 1 notation map → Phase 2 entrywise table.
- **O4 — `σ` versus `σ²` units.** Definition 18's sigmoid argument is `σ(i(t))`; the plant's `u_ex` carries `σ²(i(t))`. A regression mixing them silently is wrong. → Phase 1 units ledger (`NOT-05`) → Phase 6.
- **O5 — the project has no defined failure condition.** Every outcome is written as a success. Flagged for the user; routed to the gap register (`HND-01`, Phase 7). **Not invented by the roadmap.**

**Process concerns:**

- **The delivered work inverted the dependency order.** Bundles 1 and 2 landed before the notation map, units ledger, symbol register and entrywise plant table existed. Phase 1 acquires a retroactive reconciliation burden; Phase 3 is retro-ratification rather than gate-keeping, which is strictly weaker than the original intent.
- **13 blocking decisions remain untriaged.** At least 3 are answered on disk (`ν` vs `u` at `DOC:620-622`; Proposition 10 DECIDED at `DOC:803`; leg pairing is an errata artifact).
- **`research/SUMMARY.md` is partly known-wrong** (Rule-9 / `τ*>1` superseded); its "4 of 4 converged" claim is a shared-prior artifact. Honest P2 count: two independent derivations, one restatement, one invalid.
- **Review-gate debt:** the founding artifacts (`b5f5e82`, `9658375`, `d3b226a`) and **both Aristotle bundles** were landed before their two-step review. `HND-05` records these as retroactive entries; they are not back-dated.
- **`NOT-08`'s discovery failure is unclosed.** `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/` is still untracked (`git status` shows `??`) and at risk of destruction.

## Session Continuity

Last session: 2026-08-09
Stopped at: **Phase 6b PLANNED and COMMITTED (`e3b57cb`)** — seven plans, 13 requirement IDs 1:1, six of seven non-autonomous. Preceded by `06B-CONTEXT.md` (`c51b8e8`) captured with the user, and by the roadmap leak purge (`448331a`). Three review rounds (GSD plan-checker + Reality Checker + Model QA, in parallel each round): **21 blockers → 9 → 4 → punch list → 0**. Config: `workflow.nyquist_validation` disabled — it generates tests and checks code coverage, and this project ships documents and proofs.
Resume file: None
Next action: execution still waits on the sequential order — `1 → 2 → 3 → 6a → 6b → 7`. Phase 1's five plans are staged, twice-reviewed, and owe only an `SRC` re-pin against `cf386de` before `/gsd:execute-phase 1 --cwd control`. Phase 6a has no plans on disk.

**Phase 6b known gaps — recorded, not closed.** Carry these into the Phase 7 gap register:
- **The Dune data is checked only for internal consistency.** Row counts reconcile against `wc -l`, the script sha256 against the file, the timestamp against a git `%cI` — but MCP tools cannot be invoked from a bash `<verify>`, so nothing is checked against Dune itself. The CSV underlying the venue pick can be fabricated wholesale. The `mcp__dune__getExecutionResults` re-fetch is a **reviewer obligation**, and the "non-forgeable clock" claim was withdrawn in writing across all six sites where it appeared. A small CLI wrapper around the MCP call would make it checkable.
- **Evidence anchors are satisfiable from an arXiv abstract.** Twelve of the fourteen papers are on arXiv and nothing greps the quoted span against the PDF. `Abstract` is an explicitly accepted locator token, so the criterion is honest about what it accepts — it does not claim the paper was read.
- **The cited Montiel Olea–Pflueger critical value is not machine-verifiable.** `published critical value: 5.0` with `floor: 5.0` passes every assertion while the true value at τ=10%, size 5%, K=1 is ≈23.1. `MOP CRIT VERIFIED:` routes this to the two-step review that must run before the §5 blob is locked — the same gate that would have caught the `(β,γ)` non-control theorem.
- **`%ct` ordering detects an accident, not an adversary.** Re-justified on its own terms at `06B-01`; the guarantees that survive an adversary are structural (terminal markers, the dimensional gate, frozen-blob reads, the §5a lock).
