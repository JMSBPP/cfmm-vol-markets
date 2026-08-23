# Phase 15 — Greeks formalization (the UNFORMALIZED bundle)

**Requirement:** CTX-GREEKS (new).
**Core claim:** CC-GREEK.
**Status:** NOT STARTED, and **not yet bundleable** — two decisions must land first (§Prerequisites).
**Registered 2026-08-03** at the user's instruction. Previously the doc carried G0–G6 as inserted
blocks and `.planning/greeks/` carried 43 KB of research, but the formalization gap appeared in no
roadmap, no requirement, and no phase — it was visible only as a caveat line inside G6.

## What is already done

- Doc blocks **G0–G6** inserted (`## GREEKS`, notation-map through caveats).
- `.planning/greeks/GREEKS-RESEARCH.md` (43 KB, 2026-07-31) and `ETATILDE-SUBMISSION.md`.
- `EtaTilde.lean` (23 decls, axiom-clean, `1417958`) — landed after Phase 12 closed; registered in
  Phase 13's module table.

## What is MISSING — the bundle that does not exist

G6(3) states it outright: **the `D_p` and `Γ` ladder displays, the θ split, the
`Δθ_fee/Δσ` statics, and the G4 deficit lemmas are UNFORMALIZED.** That is the deliverable:

| Target | Source block | Note |
|---|---|---|
| `D_p` ladder, `Γ` ladder | G1 | the LP-payoff kernel's Greek ladder |
| the θ split | G1 | **blocked** by PR-THETA — the exponent sign is unresolved |
| `Δθ_fee/Δσ` comparative statics | G1/G3 | feeds the control matrix |
| **the G4 deficit lemmas** | G4 | the headline — see below |
| t-semantics in the Lean signatures | G6(7) | `T` (`υ = T/2`) vs calendar `t` (`T⋆ − t`): *"stated, not yet carried into the Lean signatures"* |

**The G4 result is the headline and it is a NEGATIVE one.** The underspecification deficit is
**structural, not numeric** — the matrix is block-triangular, and `(β_j, γ_j)`'s column is **zero on
every shape row**, so the free `(β,γ)` **cannot close it**. Raw count `6 + 2n ≥ 10` for `n ≥ 2`;
shape rows `{D_p, Γ, υ-flatness}` are reachable only through `{ξ, ι, η, Δ_i, L̄}`, and the ladder
resolution deficit is `ι − 2`. This is the formal answer to "can Greeks bind the free (β,γ)?" —
**no, and provably not by rank** — and it is exactly what is unformalized.

## G2 is OFF-BUNDLE

G2's skew law is an `η_L` statement, and **E8(6) (`η_L = η`) is OPEN** — so G2 cannot be bundled as
a statement about `η` until that closes. Recorded as PR-ETAL; G2 stays out of the first bundle.

## Prerequisites — both are DECISIONS, not work

| id | What must be decided | Why it blocks |
|---|---|---|
| **PR-THETA** | the θ exponent-sign FLAG | blocks G1's `θ_decay` finalization and any frozen on-chain constant; also blocks Phase 12.1 |
| **PR-CARRY** | carry-profile objective: **per-event (M6b) vs time-integrated (λ_FLAIR)** | G6(4) says *"decide before bundling"*; the M2 hedge claim needs the **time-integrated** form, so bundling the per-event form would prove the wrong statement |
| **PR-ETAL** | E8(6) `η_L = η` | keeps G2 off-bundle until closed |

`PR-CARRY` is the one that decides *what gets proved*, not merely how — sending the bundle before it
is ruled risks a correct proof of the wrong objective.

## Out of scope — the declared future milestone

G4 carries a **user-declared FUTURE MILESTONE, explicitly not executed there**:
`ℓ(ξ,ι;·) ⇝ ℓ_LDF(θ_LDF; i_K)` — the Bunni-v2 LDF port. The underspecification count is what points
at it (the ladder-resolution deficit `ι − 2` is what a general LDF would absorb), but it is a
separate milestone and **not part of this phase**.

## Definition of done

The G1 ladder displays, the `Δθ_fee/Δσ` statics and the **G4 deficit lemmas** landed axiom-clean in
`lean/vol_markets/`, with the structural-deficit result (`(β,γ)`'s column is zero on every shape row)
proved rather than asserted — plus traceability rows and a doc back-annotation. G2 excluded, and the
t-semantics carried into the Lean signatures. Not "the Greeks are formalized".

## Gate

`PR-THETA` and `PR-CARRY` both ruled, plus PR-GATE (the notation gate) before any doc back-annotation.
