---
phase: 08-panoptic-vol-claim-lean4-formalization
plan: 04
status: complete
completed: 2026-07-19
requirements-completed: [CTX-UPSILON, CTX-CONJ]
one_liner: "Upsilon.lean: υ finite difference + ΔQ_v bridge (statements drafted locally, proofs by Aristotle) + ATM/OTM Prop conjecture; wired into vol_markets roots"
key-files:
  created:
    - lean/vol_markets/Upsilon.lean
  modified:
    - lean/lakefile.toml
commits:
  - 0eebadb: "feat(08-04): υ finite-difference + ΔQ_v bridge statements (sorry'd for Aristotle), ATM/OTM Prop conjecture; wire lakefile root"
  - d46581d: "feat(08-05): integrate Aristotle proofs — θ_ATM closed form, centralBinom asymptotic, υ lemmas all sorry-free (shared with 08-05)"
---

# 08-04 Summary — Upsilon.lean

## What shipped
- `Upsilon.upsilon` — υ ≡ Δπ/Δσ² as a lattice finite difference for any payoff functional.
- `Upsilon.upsilon_volOption` — υ of π^σ recovers ΔQ_v on the in-the-money region (proof: Aristotle, via `Panoptic.deltaQv_of_payoff`).
- `Upsilon.upsilon_eq_deltaShares_slot` — the dimensional bridge: υ occupies the `Flow.deltaShares` ΔQ_v slot (proof: Aristotle).
- `Upsilon.upsilonTickSlope` + `Upsilon.ATMOTMNullHypothesis` — the ATM/OTM null hypothesis pinned as a `Prop` VALUE, no proof/axiom/sorry (econometric twin: κ > 0 test in the 08-03 spec).
- Lakefile: `vol_markets.Upsilon` added to roots. `lake build vol_markets` exit 0.

## Deviation (user-directed, Rule: Aristotle-heavy)
The plan's "all lemmas close locally" was overridden by the user mid-execution: the local gsd-executor was killed and the workflow pivoted to statements-only locally, proofs via a single Aristotle submission bundled with 08-05's θ goals (memory: lean-aristotle-heavy-workflow). Same end state: sorry-free, axiom-clean.
