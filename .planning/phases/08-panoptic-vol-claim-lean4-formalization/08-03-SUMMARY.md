---
phase: 08-panoptic-vol-claim-lean4-formalization
plan: 03
status: complete
completed: 2026-07-19
requirements-completed: [CTX-ECONO]
one_liner: "Reiss-Wolak econometric spec for υ identification derived via the structural-econometrics skill's interactive questioning; user-approved at the human-verify checkpoint"
key-files:
  created:
    - notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md
commits:
  - 481554f: "docs(08-03): econometric υ-identification spec via structural-econometrics skill"
---

# 08-03 Summary — Econometric υ-Identification Spec

## What shipped

`notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md` (133 lines) — the derived Reiss & Wolak (2007) structural econometric specification for identifying υ ≡ Δπ/Δσ², produced by the `structural-econometrics` skill's mandatory interactive questioning (one question at a time, per user preference) and approved by the user at the blocking human-verify checkpoint.

## Decisions captured (all user-confirmed)

- **Question/unit/outcome:** parameter identification; position-epoch panel (tokenId × t); outcome reframed from the seed's collateral Q_M to the **streaming premium π itself** (υ targeted by definition; Q_M demoted to robustness).
- **Economic model:** single Panoptic market; four actors; symmetric public-chain-state information; **only primitive = tick grid + CFMM**; σ² and pool parameters exogenous (strikes deliberately not); mechanical accrual, no FOCs; **protocol-law closure**.
- **Stochastic model:** no unobserved heterogeneity, no agent uncertainty — measurement error only (four components); σ̂² errors-in-variables = the attenuation threat, remedied by two-noisy-measures IV.
- **Estimation:** exponential-moneyness parametric vega profile υ(i_K,t) = υ₀·exp(−κ|i_K − i_t|); no error distribution — NLS/GMM, robust SEs clustered by tokenId. **The ATM/OTM null hypothesis is the parameter test κ > 0** (econometric twin of the Lean `ATMOTMNullHypothesis` Prop in `lean/vol_markets/Upsilon.lean`). Committed tests: sign tests (υ₀>0, κ>0) + symmetry (κ⁺=κ⁻).
- **Sensitivity:** form (semiparametric alternative) and no-selection (position-FE diagnostic); all four alternative specifications scheduled, including the seed linearization and the collateral channel.

## Deviations

1. **Execution locus** — the plan's `autonomous: false` executor could not drive the interactive skill (subagents cannot AskUserQuestion); the orchestrator ran the skill in the main session instead. Same deliverable, same gates.
2. **Skill scope** — user selected "Spec only": Phases −2/−1 (scaffold bootstrap, identification-with-Aristotle) and 5b/5c (data/estimation) skipped; consistent with the plan's SCOPE GUARD and the phase's Wave-4-exclusive serial-Aristotle constraint.
3. **First questioning attempt rejected** — user required strictly one-question-at-a-time pacing (preference saved to memory).

## Verification

- All plan acceptance greps pass: file exists (133 lines), υ/collateral/ATM-null/linearization blocks present, no `/home/`-style paths, no Lean file created for econometrics.
- User typed "approved" at the checkpoint (econometrics approved).
