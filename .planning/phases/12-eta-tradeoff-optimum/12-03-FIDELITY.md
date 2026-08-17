# 12-03 FIDELITY RECORD — `EtaCurvature.lean` (projects `4878ca32` → repair `c3a617f3`)

**Outcome: 51/51 declarations proven, 0 sorries, all axiom-clean** (`propext`, `Classical.choice`, `Quot.sound`). Landed in two runs: `4878ca32` returned 36/51 and exhausted budget (`OUT_OF_BUDGET`); `c3a617f3` closed the remaining 15 with the partial as its working base.

## Input integrity
All 18 bundled inputs byte-identical to submission in BOTH runs — the prover modified nothing outside its target. Declaration list identical to the submitted partial: **no renames, no drops, no additions** (51 → 51).

## Statement fidelity: 13/15 verbatim, 2 AMENDED (added hypotheses, conclusions intact), 0 narrowed

| Decl | Change | Justification (prover docstring, verified) |
|---|---|---|
| `lpExcess_strictAntiOn` | + `hS : fee < premShock`, + `hord : premShock ≤ premInv` | ordering needed so the shock branch point does not lie above the investor switch; without it the function can still be increasing immediately after `kphiI`. These are E0's own standing hypotheses `0 ≤ φ < ϱ_S ≤ ϱ_I` made explicit |
| `etaStar_pos_iff` | + `hprem : -1 < premInv` | **Mathlib `Real.log` is `log|x|`** ⟹ unguarded criterion is FALSE; witness `premInv = -3, fee = 0`. This is the log-sign trap the 12-02 Model QA review predicted |

No conclusion was weakened; no statement was satisfied by restating a weaker form under the requested name.

## Requirement closure
- **CTX-CAPTRANS** — the κ_φ layer: `arbLossRatio_*`, `surplusRatio_strictAntiOn`, `kphiS_le_kphiI_iff`, branch agreements. **SATISFIED**
- **CTX-INTERIOR** — `lpExcess_strictMonoOn` / `_strictAntiOn` / `_isMaxOn`, `kphiStar_eq_kphiI`, `kphiStar_mem_Ioo_iff`, `lpPayoff_isMaxOn`, `liquidity_freeze_minimal`, `depositEfficiency_isMaxOn`. The maximum is established by the TWO ONE-SIDED MONOTONICITY results — **no first-order condition anywhere** (κ_φ* is a kink). **SATISFIED**
- **CTX-ETABRIDGE** — `curvIndex_etaStar` (the bridge equation), `curvIndex_strictMono`, `curvIndex_mem_Ioo`, `curvIndex_tendsto_zero/_one`, `etaStar_pos_iff`, `etaStar_strictMono_premInv`, `etaStar_strictAnti_fee/_spacing`, and the η-side transport `lpExcessEta_isMaxOn/_strictMonoOn/_strictAntiOn`. Plus **T28'a**: `priceEta_eq_p_eta_half`, `priceEta_eq_P_half` — the user's η-identity decision, exponent half, DISCHARGED. **SATISFIED**
- **CTX-DEGEN** — `eta_no_common_argmax` + `etaStar_coupled_to_fee_corner`, under the NARROWED scope ruled by the user 2026-07-31: no literal de-degeneration of the Θ_φ program; the interior optimum lives in the Capponi-anchored model and transports via the η bridge, with the Phase-11 contrast as an honest scope statement. **SATISFIED as narrowed**
- **T28'b** (factor-share half) — absent, as pre-authorized. **OPEN** (E8(6)); it was NOT satisfied by restating T28'a.
