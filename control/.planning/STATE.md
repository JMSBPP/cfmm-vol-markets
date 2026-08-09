# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-08)

**Core value:** The artifact under construction is the artifact under proof — return a *verdict* on the boxed `τ*_MEV`, and a corrected law where it refutes.
**Status of the core value:** ✅ **DELIVERED.** The box is refuted factor by factor (`auditTable`, M24) and the corrected law is derived and machine-verified (`Proposition16_corrected_law`). What remains is the supporting apparatus, the empirical `Ḡ`, and the document.
**Current focus:** Phase 1 — Ground Truth, Notation, and the Rulings Triage (plans staged, unexecuted)

## Current Position

Phase: 1 of 7 (Ground Truth, Notation, and the Rulings Triage) — **remaining** work
Plan: 0 of 5 in current phase (all 5 written, reviewed twice, refreshed once; staged and uncommitted)
Status: **Ready to execute** — not "ready to plan"
Last activity: 2026-08-08 — ROADMAP.md **RE-BASELINED** against actual execution after Phases 4 and 5 were delivered out of order and the Estimation category was promoted to v1

Progress: [███░░░░░░░] ~31% (2 of 7 phases complete; 9 of 39 requirements delivered)

**Phase status at a glance:**

| Phase | Status |
|-------|--------|
| 1. Ground Truth, Notation, Rulings Triage | Planned, **not executed** (5 plans on disk) |
| 2. Entrywise Plant and Control Frame | **Partial** — frame research exists; `NOT-04`, `FRM-05` undone |
| 3. Verification Protocol, Ratified Retroactively | **Ad hoc** — applied by hand; protocol unwritten, `PRF-09` detectors never ran |
| 4. Verdicts — P1, P2, P5 (BRANCH GATE) | ✅ **COMPLETE** (Bundle 1, out of order) — branch gate FIRED: P2 REFUTED |
| 5. The Set-Point Law — Verdict and Salvage | ✅ **COMPLETE** (Bundle 2, out of order) — corrected law delivered |
| 6. Estimating `Ḡ = ∂ν/∂λ_MEV` (NEW) | Not started |
| 7. Formal Controller Document and Hand-off | **In progress** — `SRC` restructured; PR #22 → `develop` open |

**Remaining execution order:** 1 → 2 → 3 → 6 → 7 (sequential; `parallelization: false`).

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

### Pending Todos

- Refresh three Phase 1 plans before executing them: `01-02` must carry Decision #10 as DEFERRED-TO-PHASE-6; `01-03` must carry the retroactive reconciliation of the symbols M11–M24 minted ahead of the register, plus open item O3; `01-05` must carry open item O4 and the bundles' reviewed-after-landing register entries.
- Phase 1's five plans are staged and uncommitted (`git status` shows all five as `M`).

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

Last session: 2026-08-08
Stopped at: ROADMAP.md **re-baselined** against actual execution — 7 phases, 39/39 requirements mapped and verified programmatically; Phases 4 and 5 marked delivered with evidence; new Phase 6 (Estimation) created with a hard stage gate; old Phase 6 renumbered to Phase 7. STATE.md and REQUIREMENTS.md traceability updated. **Not committed** — the orchestrator commits.
Resume file: None
Next action: refresh the three Phase 1 plans listed under Pending Todos, then `/gsd:execute-phase 1 --cwd control`.
