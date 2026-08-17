# η̃ substitution-parameter bundle — submitted 2026-08-02

Project `67b1c841-26d9-4dea-b0f8-1f6198d481c9`, task `92f10c51-786d-42d1-a4aa-c88761b304cb`.
Bundle `scratch/aristotle-etatilde/` = 20 proven modules (17 `vol_markets` incl. the landed
`EtaCurvature` and `TauJit`, + 3 `exp`) + the live doc + `ETATILDE_ADDENDUM.md` (S0–S3).
Prompt `scratch/aristotle-etatilde-PROMPT.txt`. Import closure verified; `EtaCurvature` sorry-free.

Target `RequestProject/EtaTilde.lean`, 20 theorems in five groups:
- **A** the anchor identity: `η̃/(1−η̃) = λ^{ηΔi/2}` AND that this ratio IS the per-tick
  `priceEta` step (so η̃ is an observable of the existing grid, not a new primitive).
- **B** the η ↔ η̃ bijection: range `(0,1)` unconditionally, strict monotonicity, both round
  trips, `η̃ = 1/2 ↔ η = 0`, and the two limits.
- **C** THE κ_φ SIDE (required, not optional): `curvIndex η Δi = 1 − ((1−η̃)/η̃)^Δi`, the
  composition form, the inverse `tildeOfCurv`, strict antitonicity, and `curvIndex ∈ (0,1)`
  exactly on the asset-heavy half.
- **D** the domain coincidence `0 < ηΔi ↔ η̃ > 1/2 ↔ curvIndex ∈ (0,1)`, with the docstring
  noting the first condition is exactly `deltaQM_nonneg`'s hypothesis.
- **E** the E8(6) consequence: the induced share at the LANDED `etaStar` lies in `(0,1)`
  unconditionally, and `κ_φ⋆` factors through it.

Guarded in the prompt: real powers need positive bases; `Real.log` is `log|x|` (the trap that
already falsified `etaStar_pos_iff`); `EtaCurvature.curvIndex` is the ONLY curvature — a bundle
proving only the η↔η̃ bijection and skipping the curvature side FAILS its purpose.
