# 12-03 BLOCKED — Aristotle project `4878ca32` returned `OUT_OF_BUDGET`

Task `e1c846ae` terminal state: **`OUT_OF_BUDGET`** (not `COMPLETE`). `EtaCurvature.lean`
returned at 723 lines / 51 declarations, **15 carrying `sorry`**. Integration NOT performed:
`lean/vol_markets/` requires sorry-free, axiom-clean modules, and the standing rule bars
hand-proving the gap locally. Partial artifact preserved at
`scratch/eta-partial-return/EtaCurvature.lean` (gitignored).

**Inputs verified clean:** all 18 bundled modules byte-identical to what was submitted — the
prover modified nothing. This is resource exhaustion, not a payload or logic failure.

## Proven (36) — the definitional, κ_φ and exponent-bridge layers

`kphiS_mem_Ioo`, `arbLossRatio_branch_agree`, `arbLossRatio_strictAntiOn`, `arbLossRatio_pos`,
`kphiS_eq_zero_of_eq`, `arbLossRatio_eq_zero_of_kphiS_eq_zero` (the honest T5' replacement —
the F4 fix held), `surplusRatio_strictAntiOn`, `kphiS_le_kphiI_iff` (T8' with the added
`premInv` guard), `lpExcess_branch_agree_kphiS`, `lpExcess_branch_agree_kphiI`,
**`kphiStar_eq_kphiI`**, **`kphiStar_mem_Ioo_iff`** (interior ⟺ `fee < premInv`),
`depositEfficiency_branch_agree`, **`surplus_add_revenue_const`** (E5 zero-sum),
`priceEta_step_ratio`, `curvIndex_eq_of_priceEta`, `curvIndex_mem_Ioo`, `curvIndex_strictMono`,
**`priceEta_eq_p_eta_half`** + **`priceEta_eq_P_half`** (T28'a — the η-identity exponent half,
the user's 2026-07-31 decision, DISCHARGED), `etaStar_strictAnti_fee`,
`etaStar_strictAnti_spacing`, `etaStar_coupled_to_fee_corner`, + the 4 defs and helpers.

## Sorried (15) — the optimality family and the η*-defining equation

| Sorried | What it was to deliver |
|---|---|
| `lpExcess_strictMonoOn`, `lpExcess_strictAntiOn`, `lpExcess_isMaxOn` | THE PEAK itself (E4 interior optimum) |
| `lpPayoff_isMaxOn`, `liquidity_freeze_minimal` | payoff-level optimum, `c₁ ≤ 0` freeze |
| `depositEfficiency_isMaxOn` | E5 efficiency optimum |
| `curvIndex_tendsto_zero`, `curvIndex_tendsto_one` | E1 boundary limits |
| **`curvIndex_etaStar`** | **the η* ↔ κ_φ* bridge equation** (E6 headline) |
| `etaStar_pos_iff`, `etaStar_strictMono_premInv` | η* sign + monotonicity |
| `lpExcessEta_isMaxOn`, `lpExcessEta_strictMonoOn`, `lpExcessEta_strictAntiOn` | the η-side transport |
| `eta_no_common_argmax` | the de-degeneration analogue (T29') |

**Reading:** the location of the optimum (`kphiStar_eq_kphiI`) and its interiority condition are
proven; that it IS the maximum is not. The exponent bridge landed; the η*-defining equation did
not. CTX-CAPTRANS partially satisfied; CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN NOT satisfied.

## Sanctioned repairs (12-CONTINGENCY: only two outcomes are allowed)

1. **Second bundle** — the 18 modules + the partial return, prompt covering ONLY the 15 sorried
   items, submitted as a NEW project (or a serial `continue` on `4878ca32`; the standing ban is
   on PARALLEL `continue`, not a single one). Requires user approval — it is a fresh spend.
2. **Honest `OPEN` rows** — record the 15 as OPEN in traceability and close the phase with
   partial coverage.

Hand-proving locally is barred (workflow rule: Aristotle authors statements AND proofs).

## REPAIR SUBMITTED (user `submit eta -b`, 2026-07-31)

Project `c3a617f3-fac9-4ddb-bb7b-a903f10a26c8`, task `4ec89173-19dd-4f9e-b206-9bd99940a699`.
Bundle `scratch/aristotle-eta-b/` = the ORIGINAL 18 bundled inputs (byte-identical, verified)
+ the partial `EtaCurvature.lean` as the working base; import closure re-verified. Prompt
`scratch/aristotle-eta-b-PROMPT.txt` (623 words) is scoped to the 15 sorried declarations ONLY.

Why no re-gate: the 15 statements are Aristotle's OWN, already type-correct, and the file
already builds — the transcription-defect class the original two-reviewer gate existed to catch
(wrong arity, missing `Real.sqrt` guards, false-as-displayed statements) cannot recur, because
no statement is being authored. The prompt adds only proof-order guidance.

Prompt carries: the no-FOC rule (κ_φ* is a KINK; the max comes from the two one-sided
monotonicity results, never stationarity); pole discipline on `1/curv`; the anti-narrowing rule
(add a hypothesis and SAY SO, or prove a REFUTATION under a different name — never weaken
silently); a transport hint (prove gap 9 `curvIndex_etaStar` first, then 12–14 follow by
composition with the proven bijection rather than re-deriving in η); and a PRIORITY ORDER for
budget exhaustion — 9, then 3/1/2, then 10/11, then 12–14, then the rest — so a second
truncation degrades gracefully instead of losing the headline.
