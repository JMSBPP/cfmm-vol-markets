# Phase 11 — CONTEXT: MEV hazard-rate metric and infimum program (λ_MEV)

**Origin (user, 2026-07-30):** `VOLATILITY_INSTRUMENTS.md ### MEV` (plank
worktree) names two references: (1) Angstrom — the implementation that
minimizes the associated λ_MEV; (2) MEV literature enabling a λ_MEV metric
analogous to λ_FLAIR — with the exercise being the INFIMUM (minimize, not
maximize), finding the parameters that control it, "considering that there
are some parameters that already control FLAIR".

## Inputs already in place

- **Solved FLAIR layer** (`lean/vol_markets/FlairOptimization.lean`,
  commits 6914fba/5e08578, mirrored at cfmm-lean4-spec): discrete
  `flairHazard φfun σpath w D T = Σ_t φ(σ_t)·w_t/D_t`; affine
  identification `λ_FLAIR = φ̄·W + u·Σ_j α_j·W_j`; `Θ_{λ_FLAIR} = {φ̄, α, u}`
  with corner max; `(β, γ)` reallocation-only, β→−∞ saturation.
- **Fee space** `Θ_φ = {γ, φ̄, β, α(, α_R)}`: `VolInstrument.multiFee` +
  `sigmoidR` (notation binding — identifiers from the doc's symbols only).
- **Literature** (PDFs in `../plank/refs/mev/`, see memory
  `mev-lambda-literature`): anchor = Milionis–Moallemi–Roughgarden
  *Arbitrage Profits in the Presence of Fees* (2305.14604) — closed-form
  expected instantaneous arb-profit rate, DECREASING in the fee, Poisson
  blocks. Supporting: Theory of MEV I (CFMM sandwich/reordering,
  2207.11835), Theory of MEV II (uncertainty trade-offs, 2309.14201),
  Guo invariance (2304.11010), Mazorra–Della Penna (2211.07220), Flash
  Boys 2.0 (1904.05234), cross-domain (2112.01472). FLAIR refs in
  `../plank/refs/flair/`.
- **Angstrom architecture** (memory `angstrom-structure`): batch/uniform
  clearing kills sandwich MEV by construction; ToB auction recycles
  CEX-DEX arb to LPs; parameter surface = batch cadence (1 bundle/block),
  `fee_in_e6`, unlocked fees, gas/fee bounds, stake sizing; l2-angstrom =
  on-chain MEV tax `priority_fee·100000·49` (≈98%) to LPs.

## The mathematical target

1. **Metric**: discrete `mevHazard` mirroring `flairHazard` — per-block
   arb/sandwich intensity over capital, where the per-step extraction is
   fee-DEPENDENT and DECREASING (from 2305.14604: arb trades only when the
   price gap exceeds the fee band; the fraction of profitable blocks
   shrinks with the fee). The fee is `multiFee` evaluated on the σ-path —
   the SAME Θ_φ as FLAIR.
2. **Identification**: `Θ_{λ_MEV} ⊂ Θ_φ` — which coordinates control
   inf λ_MEV. Expected structure: the level block `{φ̄, α, u}` is again
   controlling but with OPPOSITE monotonicity (fees up ⟹ λ_MEV down ⟹
   inf at the level corner TOP, same corner as sup λ_FLAIR — check!), and
   the shape block `(β, γ)` becomes ESSENTIAL rather than
   reallocation-only, because arb intensity concentrates where σ realizes:
   centering β at the realized-vol mass is where fee deterrence binds.
3. **The infimum program**: uniform lower bound, attainment/boundary
   characterization (mirror of `flairMulti_le_corner` /
   `_saturation_limit`), with the necessary-hypothesis discipline
   (Aristotle has twice added missing hypotheses; expect e.g. positivity
   of the arb-opportunity weights).
4. **Joint program**: state sup λ_FLAIR vs inf λ_MEV jointly — if both
   optima sit at the same level corner, the trade-off is degenerate at the
   level block and the ENTIRE tension lives in `(β, γ)` + the demand
   elasticity absent from both functionals (record the caveat again).
5. **Angstrom bridge (statement-level)**: the ToB-auction recycling maps
   to a rebate term in the hazard (extraction returned to LPs reduces net
   λ_MEV); the l2 MEV-tax factor 49/50 is a concrete `τ` in a
   `(1−τ)·extraction` term — a candidate protocol-controllable parameter
   OUTSIDE Θ_φ, to be recorded as such.

## Constraints / workflow rules (binding)

- Doc-driven Aristotle workflow: the reference note is
  `VOLATILITY_INSTRUMENTS.md ### MEV`; when the math spec is drafted into
  the doc (LaTeX, minimal prose), the DOC goes to Aristotle with
  instructions — no locally hand-drafted proofs. Strictly serial queue.
- Notation binding: identifiers from the doc's symbols only; λ_MEV,
  Θ_{λ_MEV} notation matches the doc's λ, Θ pattern; no interpretive
  names (memory `vol-instruments-notation-binding`).
- Doc edits to `VOLATILITY_INSTRUMENTS.md` require HEAVY USER APPROVAL
  (plank todo.md `## LEAN4 - MATH` precedent).
- Two-reviewer gate (Reality Checker + specialist) on the phase plan and
  on any spec artifact before execution.
- λ_MEV theorems land in a new `lean/vol_markets/` module beside
  `FlairOptimization.lean`; traceability rows go to
  `model/vol_markets/LEAN_TRACEABILITY.md` §7.
