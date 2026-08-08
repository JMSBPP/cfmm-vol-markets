# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-08)

**Core value:** The artifact under construction is the artifact under proof — return a *verdict* on the boxed `τ*_MEV` (PROVEN or REFUTED, axiom-clean, with the counterexample if it falls), and a corrected law where it refutes.
**Current focus:** Phase 1 — Ground Truth, Notation, and the Rulings Triage

## Current Position

Phase: 1 of 6 (Ground Truth, Notation, and the Rulings Triage)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-08-08 — ROADMAP.md rewritten 8 phases → 6 after the scope-narrowing ruling and the two-step review

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Recent decisions affecting current work:

- **Scope (2026-08-08 user ruling):** the deliverable is the formal controller document, grounded on theory and formal results. The **entire EVM-feasibility track is out** (`EVM-01a/01b/02/03/05/06` → v2). `FRM-05` (null-space `HF = 0`) survives as pure theory with **no on-chain cost claim attached**.
- **`L` is two assets, not one ambiguous symbol (2026-08-08):** `L(i_K) = L̄·ℓ(ξ,ι;i_K)` with `ℓ` geometry-invariant; `ΔQ_v★` is in **vol-asset** L units (`UNITS_AND_SCALES.md:70`) while `L̄` is price-axis pool liquidity. Rule 9 is an identity on the vol axis and constrains nothing on the pool axis — **this kills the `τ* = 1` refutation.**
- **Behavioral gains are hypotheses, not obligations (2026-08-08):** `∂L̄/∂π^φ > 0` and `Ḡ_(ν,λ_MEV) > 0` are LP-supply estimands from add/remove-liquidity events. Named typed hypotheses; **neither is ever sent to Aristotle**. Magnitudes = `EST-01` (v2).
- **Proving route is undecided:** an Aristotle key is now available to *this* session, and the Lean4+Math peer dependency was never agreed. `PRF-10`'s hand-off artifact must be route-agnostic.

### Pending Todos

None yet.

### Blockers/Concerns

- **The project has no defined failure condition.** Every outcome is written as a success. Flagged for the user; routed to the gap register (`HND-01`, Phase 6). Not invented by the roadmap.
- **13 blocking decisions are untriaged.** At least 3 are already answered on disk (`ν` vs `u` at `DOC:620-622`; Proposition 10 DECIDED at `DOC:803`; leg pairing is an errata artifact). Phase 1 triages before anything goes to the user.
- **Discovery failure is unclosed until `NOT-08` runs.** Three normative artifacts were missed by four researchers: `plank/notes/UNITS_AND_SCALES.md`, `plank/notes/VOLATILITY_INSTRUMENTS_MEV.tex`, `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/ENTRY_POINT.md` (**untracked — at risk of destruction**).
- **`research/SUMMARY.md` is partly known-wrong** (its Rule-9 / `τ*>1` findings are superseded) and its "4 of 4 converged" claim is a shared-prior artifact. Honest count: two independent derivations, one restatement, one invalid.
- **Review-gate debt:** the founding artifacts (`b5f5e82`, `9658375`, `d3b226a`) were committed before their two-step review ran. `HND-05` records this as retroactive first entries.

## Session Continuity

Last session: 2026-08-08
Stopped at: ROADMAP.md rewritten (6 phases, 34/34 requirements mapped and verified programmatically); STATE.md and REQUIREMENTS.md traceability updated. Not committed — the orchestrator commits.
Resume file: None
