# Lean ↔ Haskell ↔ spec cross-walk (Panoptic υ identification)

**Purpose.** The "formal witness" claim of Phase 9 is that a fitted κ̂ > 0 makes the
estimated exponential-moneyness vega profile a witness of the Lean conjecture
`Upsilon.ATMOTMNullHypothesis`. That claim is only as good as the fidelity between
the Haskell estimator and the Lean definitions. This table is the auditable
evidence: every load-bearing object appears in all three registers — the Lean
formalization (`lean/vol_markets/*.lean`), the Haskell estimator
(`econometrics/src/…`), and the binding econometric spec
(`notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md`).

Keep this table in sync whenever any of the three sides changes.

| Lean name (`lean/vol_markets/…`) | Haskell name (`econometrics/src/…`) | spec § | Meaning / fidelity note |
|---|---|---|---|
| `Upsilon.upsilon` (vega family `υfun i = υ₀·exp(−κ·Δi·\|i−iK\|)`) | `Model.Upsilon.model [b0,u0,k] (d,s2) = b0 + u0*exp(negate k*d)*s2` | §4.3 | The estimating equation VERBATIM. Lean's `υ₀·exp(−κ·Δi·\|i−iK\|)` is the multiplicative vega; the Haskell `model` multiplies it by σ̂² and adds β₀ to give π (spec §4.3 `π = β₀ + υ₀·exp(−κ·\|i_K−i_t\|)·σ̂²`). |
| `Upsilon.upsilonTickSlope υfun Δi i = (υfun (i+1) − υfun i)/Δi` | discrete forward slope used by the ATM/κ>0 test (built in 09-08 `Model.Specification`) | §5 (test 2) | The forward-difference tick-slope whose \|·\| peaks at the money. The Haskell κ>0 Wald test is the econometric twin of asserting this slope is maximal at `iK`. |
| `\|(i:ℝ) − (iK:ℝ)\|` (inside `Upsilon.ATMOTMNullHypothesis`) | `Model.Upsilon.moneyness iK it = abs (fromIntegral (iK − it))` | §4.3 | The tick-grid moneyness distance `d = \|i_K − i_t\|`. Same absolute-tick-count metric on both sides. `Model.Upsilon.signedMoneyness` retains the sign for the κ⁺/κ⁻ split. |
| `PosSpec.lam = 1.0001`, `PosSpec.tickPrice Δi i = lam^((i/2)·Δi)` | `Model.Upsilon.tickBase = 1.0001`; `Panel.Build.strikeToTick = round (log K / log 1.0001)` | §2.4 | The λ = 1.0001 tick/price grid — the sole technological primitive. i_K = log_λ K is the strike tick; the distance lives on this grid. `tickBase` is annotated `-- mirrors PosSpec.lam`. |
| `Upsilon.ATMOTMNullHypothesis υfun Δi iK c` (the κ>0 `Prop`, conjunct 1 `0 < c`) | the one-sided κ̂ > 0 Wald/t test (`Model.Specification`, 09-08) fitting `Model.NLS.fitGSL` | §5 (test 2) | H₀: κ = 0 (flat) vs H₁: κ > 0 (ATM peak, OTM exp decay). Lean pins the statement (no proof); the Haskell test evaluates it on data. `c = κ·Δi` in the Lean witness. |
| `Upsilon.exp_family_witnesses_ATMOTM` (bridging lemma, one `sorry` → Aristotle 09-06) | `Model.NLS.fitGSL` producing κ̂ > 0 (with `Model.Upsilon.model` as the fitted family) | §4.4 | The exp family with κ > 0 witnesses `ATMOTMNullHypothesis` at `c = κ·Δi`. A fitted κ̂ > 0 instantiates the witness — hence the byte-for-byte fidelity requirement above. |
| `Upsilon.upsilon_volOption` / `upsilon_eq_deltaShares_slot` (υ = ΔQ_v slot, proved) | — (analytical, no estimator counterpart) | §1 | Dimensional bridge that υ ≡ Δπ/Δσ² occupies the ΔQ_v slot. Grounds why π is regressed on σ̂² at all; no direct Haskell object. |

## EIV remedy (spec §4.3) — not a Lean object, recorded for completeness

| Object | Haskell name | spec § | Note |
|---|---|---|---|
| Second-window variance instrument σ̃²_t | `Panel.Variance.instrumentVariance` (`Obs.obsSigma2Instr`); consumed by `Model.EIV.ivFit` | §4.3 | Two-noisy-measures IV: σ̂²_t is EIV-mismeasured (M1 → attenuation on υ̂₀); σ̃²_t (disjoint even-swap sub-window) instruments it. Hand-rolled; no Lean twin. |

## Fidelity checklist (grep-able anchors)

- `Model.Upsilon.model` body is `b0 + u0 * exp (negate k * d) * s2` — matches spec §4.3 term-for-term.
- `Model.Upsilon.tickBase == 1.0001` and `Panel.Build.strikeToTick` uses `log 1.0001` — both mirror `PosSpec.lam`.
- `Model.Upsilon.moneyness` is `abs (fromIntegral (iK − it))` — the `|i_K − i_t|` distance.
- The bridging lemma's fitted family is exactly `Model.Upsilon.model`'s vega part `υ₀·exp(−κ·d)`.
