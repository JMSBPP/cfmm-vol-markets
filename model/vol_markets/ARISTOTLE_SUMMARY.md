# Summary of changes for run ad0d9444-b9a1-407f-b530-50352f2dd4b5
Completed the formalization and implementable design alternatives for `d`, `p_risk`, and haircut.

### Added `RequestProject/RiskDesign.lean`
Machine-checked definitions and proofs now cover:
- Unit-interval clamping.
- Three distance choices: identity, low-gas two-band, and clipped linear decay.
- Conservative risk prices based on `max(spot, TWAP)` and a clamped premium.
- Haircut valuation via the retained factor `1-h`.
- The equivalent issuance convention `p_risk = oracle/(1-h)`.
- Proofs that adjusted collateral remains between zero and unhaircut value.
- Exact unsigned X96 multiplication with floor rounding, including proofs that a clamped weight cannot increase an amount and encoded one preserves it exactly.

### Added `RISK_ALTERNATIVES.md`
This provides EVM-oriented alternatives, formulas, rounding directions, pseudocode, trade-offs, and a recommended typed pipeline. The principal recommendation is:
- clipped-linear Q0.96 distance,
- `max(spot,TWAP)` plus a bounded premium for `p_risk`,
- retained-value haircut `amount × oracle × (1-h)`, rounding down.

It also corrects the draft haircut expression: `price / haircut` is singular at zero haircut and has the wrong monotonic behavior. For issuance, use `oracle/(1-h)` instead.

The note emphasizes that a nontrivial `d ∈ [0,1]` produces a risk-adjusted subtotal, not the accounting `totalShares`; exact equality for all positive positions forces `d = 1`.

The full Lean project builds successfully with no `sorry`, `admit`, or added axioms. Changes were committed and pushed in commit `85e1d11`.

# Summary of changes for run b4826566-8171-49ab-83e0-bba52b5195e0
I extended the project to cover the new prompt's full pipeline, adding a machine-checked mathematical backbone (no `sorry`, only standard axioms) plus EVM design notes. Everything builds and is committed/pushed.

## New Lean modules (build clean, no warnings)

`RequestProject/PosSpec.lean` — position-spec map `(σ̄, #_σ̄, s_v) → (p(i), p(i_l), p(i_u))`:
- `skewTick` + `skewTick_one/zero/mem/gap_upper/gap_lower`: the skew interpolation `i(σ̄) = s_v·i_l + (1−s_v)·i_u` is a convex combination lying in `[i_l, i_u]`, with the endpoint gaps `i_u−i = s_v(i_u−i_l)`, `i−i_l = (1−s_v)(i_u−i_l)`.
- `width_span`: the width identity `Δ_i·#_σ̄ = |i_l−i_u|` gives the oriented span `i_u−i_l = Δ_i·#_σ̄`.
- `tickPrice` (`p(i)=1.0001^{(i/2)Δ_i}`) with `tickPrice_pos`, `tickPrice_le`, `tickPrice_lt`, and `tickPrice_skew_mem`: prices are positive, strictly increasing in the tick, so `p(i_l) ≤ p(i(σ̄)) ≤ p(i_u)`.

`RequestProject/Flow.lean` — flow, liquidity, payoff, schedule:
- `deltaShares` (`ΔQ_v = ΔQ_M/p_risk`) with nonnegativity, monotonicity, and `deltaShares_admissible_iff`: admissibility `ΔQ_v ≤ Q_M^Σ/p_risk` collapses to the clean money ceiling `ΔQ_M ≤ Q_M^Σ`.
- Uniswap `getLiquidity`/`liquidity0`/`liquidity1` with nonnegativity, monotonicity in `ΔQ_M`, and `liquidity1_eq_div` (`L = ΔQ_M/(p(i_u)−p(i_l))`).
- `terminalPayoff`/`trajPayoff` with `terminalPayoff_nonneg`, and `trajPayoff_control` reducing the trajectory payoff to the linear control `π(x) = (k/w)·x`.
- The optimal schedule: `schedule_min_high` (deposit the full admissible amount when the realized-vol price exceeds the target), `schedule_min_low` (deposit nothing otherwise), and `schedule_isLeast`, the complete least-value statement `min 0 ((k/w)·X)` over `[0, Q_M^Σ]`.

The existing `RequestProject/Main.lean` (admissible region, discounted-sum correction) is unchanged and still used.

## Design documents (referenced imports + the requested schedule)
- `pos_spec.md`: the `(σ̄, #_σ̄, s_v) → (p(i), p(i_l), p(i_u))` module — EVM types (u88/i24/u16/u24, Q64.96), the shift-based skew, and how each claim maps to a `PosSpec` lemma.
- `tbd.md`: the `(ΔQ_M, p_risk) → (ΔQ_M, ΔQ_v)` module — representations (RAY/X96), the fused `mulDiv`, and the division-free admissibility guard, mapped to `Flow`/`Main` lemmas.
- `SCHEDULE.md`: combines `getLiquidityForAmounts`, the payoff, and the answer to "get the EVM-implementable schedule for ΔQ_M" — a proven bang-bang/threshold controller (a single price comparison `p(σ(t)) ⋛ p(i(σ̄))` selects `ΔQ_M = Q_M^Σ` or `0`), with pseudocode and rounding directions, justified by `schedule_isLeast`.

A note on faithfulness: the "min over ΔQ_M(t)" objective is well-posed only after fixing the liquidity branch; I used the token1 (below-range) branch `L = ΔQ_M/w`, where the payoff is linear in the control and the optimum is exactly the bang-bang endpoint rule proved in `schedule_isLeast`.

# Summary of changes for run 8011be2a-03e0-4fa6-870e-973f9b81fad4
I turned the design question into a machine-checked mathematical backbone plus an EVM design-space analysis. Everything is committed and pushed.

## What was found first (a correction)
The informal "admissibility" claim — that `d ∈ [0,1]` implies `Σ Qᵥⁱ·d(p_risk,p(i)) = Σ Qᵥⁱ` — is **false**. Being valued in `[0,1]` only gives an inequality; equality forces `d ≡ 1`. I formalized both the true facts and an explicit counterexample.

## Formal results (`RequestProject/Main.lean`, builds with no `sorry`, no warnings)
- `discounted_nonneg` : `0 ≤ Σ Qᵥⁱ·dᵢ`.
- `discounted_le_total` : `Σ Qᵥⁱ·dᵢ ≤ Σ Qᵥⁱ` (= the accounting identity `Qᵥ^Σ`) when `d ≤ 1`, `Qᵥⁱ ≥ 0`.
- `discounted_eq_total_iff` : equality holds iff termwise `Qᵥⁱ·dᵢ = Qᵥⁱ`.
- `discounted_eq_total_iff_pos` : with `Qᵥⁱ > 0`, equality holds iff `dᵢ = 1` for all i.
- `discounted_claim_counterexample` : an explicit instance (`N=1, Qᵥ≡1, d≡0`) where the stated identity fails.
- `admissible_iff_mul` : the division-free EVM reformulation of the admissible region, `Δ ≤ Q_M^Σ/p_risk ⟺ Δ·p_risk ≤ Q_M^Σ` (for `p_risk > 0`).
- `admissible_state_bounds` : a nonnegative admissible flow keeps the post-update state in `[Qᵥ^Σ, Qᵥ^Σ + Q_M^Σ/p_risk]`.

## Answers to the two design questions (`DESIGN_SPACE.md`)
- **Representation for `d`:** since `d ∈ [0,1]` and its inputs `p(i(σ_x96))`, `p_risk` are already X96, store `d` as unsigned `Q0.96`/X96 (scale `2^96`, clamp `≤ 2^96`). The discount `Qᵥ·d` then becomes an exact right-shift `>>96` (no rounding division), stays base-consistent with the price side, and preserves the proved invariant `Σ Qᵥⁱ·dᵢ ∈ [0, Σ Qᵥⁱ]`. WAD/RAY are acceptable but cost a base change and a true `mulDiv`; signed/float and any unclamped `>1` format are rejected.
- **Design space for `∂_(M,v)` (the flow `Δ`):** carry it in RAY (`1e27`) to match the state accumulator; it is nonnegative and upper-bounded, so an unsigned RAY slot suffices. Compute `Q_M^Σ/p_risk` as a single fused `mulDiv` rounding **down**, and enforce admissibility via the cross-multiplied guard `Δ·p_risk ≤ Q_M^Σ` to avoid a rounding division (both properties are the proved `admissible_iff_mul` / `admissible_state_bounds`).

The document maps each recommendation to the corresponding verified lemma and includes the fixed-point conventions (X96 = `2^96`, WAD = `1e18`, RAY = `1e27`).
# Summary of changes for run 664d9abb (task 6240b273)
Aristotle proved all 35 sorry'd lemmas in `GeomProfile.lean` (11) and
`FeeSchedule.lean` (24); integrated, lake build green, axiom-clean.

- GDF profile (tbd2.md): partition of unity, positivity (both branches),
  strict concentration for ξ<1, uniform 1/ι limit as ξ→1; payoff
  decomposition into `Flow.terminalPayoff` (plus the sqrt-price-grid
  instantiation).
- Variance-swap identification, with the review-caught correction: the
  Carr–Madan strike-notional weights `dK/K²` on `K_i = 1.0001^(i·Δ_i)` are
  geometric with ratio `1.0001^(-Δ_i)`; the v3 *liquidity* profile
  replicating the log contract is geometric with ratio
  `ξ* = 1.0001^(-Δ_i/2)`. Convention bridge `priceGrid = tickPrice²`.
- Sigmoid fee schedule (arXiv:2508.08152 / FLAIR 2306.09421):
  range/monotonicity/undercutting; `ℝ*⋉ℝ` action on `(σ̄_f, s_f)` and output
  affine action with order preservation; `s_f → 0⁺` threshold limits;
  two-point calibration existence AND uniqueness; EVT optimizer interface;
  halt-regime monotonicity; typed `RiskDesign` P1/P2 bridges (`clamp01`
  identity on `[0,1]`, `p_risk` monotone in realized vol).

Post-integration notation alignment (see `LEAN_TRACEABILITY.md` §0): fee
parameters renamed off `η` (reserved for the pricing kernel) to
`feeMin`/`feeMax`/`cexFee`; sigmoid center/steepness named
`volStrike` (σ̄_f) / `steepness` (s_f); tick spacing uniformly `Δi` matching
`PosSpec`/`tbd.md`.

# Summary of changes for run da1c9fce (task 5dc95184)
Workflow change (user rule): the reference doc itself — plank's
`notes/VOLATILITY_INSTRUMENTS.md` — was bundled with the 8 proved modules and
Aristotle authored BOTH statements and proofs (no locally drafted sorries).
Result: `vol_markets/VolInstrument.lean`, 36 proved lemmas/theorems + 8 defs,
sorry-free, axiom-clean; none of the 8 existing files modified.

- §1 pricing-kernel geometry `priceEta η Δi i = λ^((i/2)·Δi·η)` (Θ_p = {η, Δ_i});
  positivity, strict monotonicity for η·Δi > 0, and `priceEta 1 = tickPrice`.
- §2 per-tick amounts `deltaQM`/`deltaQX` (token0 identity, nonnegativity —
  Aristotle added the mathematically necessary `Δi ≥ 0` alongside η·Δi > 0),
  cumulatives with succ/monotone/constant-L telescoping laws, and the
  least-step inverse cumulative (`exists_least_reaching`).
- §3 flow region `flowRegion`/`tickFlowRegion` (square identity, monotone).
- §4 multi-sigmoid fee `multiFee` over Θ_φ = {γ, φ̄, β, α} with `utilization`;
  bounds, monotonicity, and the exact single-term bridge
  `multiFee 1 ... = FeeSchedule.feeRaw φ̄ (φ̄+α₀) β₀ γ₀⁻¹` (s_f = 1/γ).
- §5 `probOr` (⊗_φ): abelian-monoid laws, [0,1] closure, monotonicity, and the
  hazard correspondence `probOr (1−e^{−λM}) (1−e^{−λX}) = 1 − e^{−(λM+λX)}`.
- §6 Demeterfi `logPortfolio`/`variancePortfolio`: nonnegativity, ATM zero,
  `Upsilon.upsilon (Π + σ²t/2) = t/2` (price-independent), unit-vega `2/t`.
- Bridges: `realizedVariancePayoff_bridge` (= `Panoptic.volOptionPayoff 1`),
  `strikeWeight_bridge` (doc's ℓ(ξ,ι;i_K) = `GeomProfile.geomWeight`).

# Summary of changes for run 78bac8dd (task beed2796)
Aristotle formalized AND SOLVED the FLAIR sup of VOLATILITY_INSTRUMENTS.md
(`∃ Θ_λ ⊂ Θ_φ, sup λ_FLAIR`) in `vol_markets/FlairOptimization.lean`
(439 lines, 4 defs + 15 theorems, sorry-free, axiom-clean; 9 existing files
untouched).

- Discrete functional: `flairHazard φfun σpath w D T = Σ_t φ(σ_t)·w_t/D_t`,
  `flairMulti` = instantiation at `VolInstrument.multiFee`; capital
  denominator lemma `D_t = QM·(p_t+1) > 0`.
- IDENTIFICATION (`flairMulti_affine`): exact affine decomposition
  `λ_FLAIR = φ̄·W + u·Σ_j α_j·W_j`, W = pathWeight, W_j = shapeWeight;
  strict monotone in φ̄, monotone in α/u, ANTI-monotone in β;
  `0 ≤ W_j ≤ W` with strict `W_j < W` under any positive flow step.
  ⟹ Θ_λ = {φ̄, α, u} is the controlling level block; (β, γ) reallocate only.
- SOLUTION: uniform corner bound
  `λ_FLAIR ≤ (φ̄max + umax·Σ αmax_j)·W` for ALL shapes; bang-bang corner
  attainment in the level block; single-term `β → −∞` saturation Tendsto
  with STRICT inequality at every finite β (strictness needs uMax > 0,
  αmax0 > 0 — Aristotle-added necessary hypotheses); compact-box maximizer
  existence via `FeeSchedule.exists_optimal_params`;
  `Theta_lambda_identification` packages strict-below-saturation + limit.
- Docstring caveats recorded: traded-volume reading of `dp`; no demand
  elasticity in this functional (volume trade-off = FeeSchedule layer).

# Summary of changes for run 128b24ae (task 311f81e5) — issue cfmm-lean4-spec#1
Aristotle formalized the staged doc block `## VOL ORDER COMPLETION —
ENDOGENOUS MATURITY` (VolOrder v2 delegation) into
`vol_markets/EndogenousMaturity.lean` (331 lines, 8 defs + 34 theorems,
sorry-free, axiom-clean; 10 deps byte-identical). Ran PARALLEL to MEV
bundle A per user override (new-project isolation verified).

- Maturity bridge: `tStar = 2·dQvStar/Nσ` + inverse (`dQvStarOfMaturity`),
  bijection pair, `maturity_equivalence`, and the vega bridges
  (`variancePortfolio_upsilon_at_tStar`, `tStar_variancePortfolio_upsilon`,
  `tStar_unit_upsilon`); positivity + strict monotonicity both ways.
- Auto-deleverage (DECIDED): `dQvFunded = min(dQvStar, QM/prisk)` with
  admissibility (division-free via `Main.admissible_iff_mul`), violation/
  no-violation dichotomy, MAXIMALITY among admissible exposures,
  `tStarFunded` monotone in QM / antitone in prisk, exact top-up
  restoration, liquidation degenerate case, floor-rounding conservativity.
- OPEN FLAG preserved: `tStarJointMult`/`tStarJointSub`/
  `tStarJointQuadratic` as labeled CANDIDATES with per-candidate sanity
  (nonneg, contraction in sig2R, agreement at sig2R=0, exhaustion) and a
  discriminating instance — the joint recalibration law remains an author
  decision.

# Summary of changes for run cb371ee5 (task d1c57297)
Aristotle formalized blocks M0–M5 of the MEV section of
`VOLATILITY_INSTRUMENTS.md` (the user-approved addendum, `APPROVED-DOC-SHA256`
671000a5…) into `vol_markets/MevOptimization.lean` (1046 lines, 3 defs + 22
public theorems + 3 private helpers, sorry-free, axiom-clean on all 25
enumerated declarations; the 10 bundled dependency modules returned
byte-identical). Single serial submission; T1–T18 complete, optional T19
omitted. Fidelity diff: `.planning/phases/11-mev-hazard-inf-program/
11-03-FIDELITY.md`.

- `ptrade φ σ Δt = σ/(σ + φ·√(2/Δt))` — the steady-state probability a block
  carries a profitable arbitrage. All seven of block M1's properties carried:
  range `Ioc 0 1`; `= 1 ↔ φ = 0`; STRICT antitone in the fee; monotone in `Δt`
  and in `σ`; `→ 0` as `φ → ∞`; STRICT convexity on `Ici 0` plus its named
  weakening `ptrade_convexOn`. Strict convexity is the structural replacement
  for FLAIR's affineness and it came back strict, not downgraded.
- `mevHazard φfun σpath a D Δt T = Σ_t ptrade(φ(σ_t), σ_t, Δt)·a_t/D_t`;
  `mevMulti` = its instantiation at `VolInstrument.multiFee` — the SAME
  parameter space and the SAME deployed-capital denominator `D_t` as
  `FlairOptimization.flairHazard`, which is what makes the hazards
  commensurable. CPMM weight `a_t = (σ_t²/8)·V_t·Δt` positive (T8) — the `Δt`
  converts LVR's rate into the per-block amount the sum needs.
- IDENTIFICATION, reversed against FLAIR throughout: STRICT antitone in `φ̄`
  (needs the `∃ t₀ < T, 0 < a t₀` witness), antitone in `α` and in `u`,
  ISOTONE in `β`. NO affine decomposition exists here — `ptrade` is not affine,
  so the FLAIR mirror breaks and the corner bound stays a path SUM.
- SOLUTION (the infimum program): uniform lower bound at the fee ceiling as a
  path sum `Σ_t ptrade(φ̄max + umax·Σ_j αmax_j, σ_t, Δt)·a_t/D_t`; bang-bang
  attainment at the level-corner TOP; single-term `β → −∞` saturation Tendsto;
  STRICT gap at every finite `β`; compact-box MINIMIZER existence via
  `IsCompact.exists_isMinOn` with `ContinuousOn` PROVED, not assumed;
  `Theta_lambdaMEV_identification` packages strict-above-saturation + limit,
  and `mevMulti_min_gt_corner` carries M5(iii)'s "value strictly exceeds the
  displayed bound" half. ⟹ Θ_{λ_ARB} = {φ̄, α, u} at its UPPER corner; the
  shape block cannot attain the infimum.
- ARISTOTLE-ADDED HYPOTHESES (disclosed, not silent): `hfee : 0 ≤ φbarMax +
  uMax·αmax0` on the T15 saturation limit — the unguarded limit as requested is
  FALSE, because the limiting fee can land on `ptrade`'s negative-fee pole (the
  same pole that made the pre-review T17 false); `hupper` (box ≤ corner levels)
  on `mevMulti_min_gt_corner`; `0 ≤ u` on `mevMulti_anti_u`; a redundant
  `0 ≤ αmax j` on `mevMulti_corner_attained_levels`.
- Docstring caveats recorded, all mandatory ones present: this object is
  `λ_ARB`, a SUMMAND of `λ_MEV` and NOT a sibling of it (on `mevHazard`,
  `mevMulti` and the identification theorem — without it a later
  `mevHazard + sandwich` is the double-count block M0 forbids); the
  leading-order `ARB ≈ LVR·P_trade` factorization is the anchor's fast-block
  small-fee asymptotic, not an exact finite-`Δt` identity; no demand response
  to the fee, the omitted term being eq. (27); `P_trade` is a steady-state
  quantity and its stepwise use along a varying-σ path is the document's
  quasi-static extension, legitimate only under M8's slow-parameter condition.
  `arb_add_fee_eq_lvr` is labelled a BRIDGE IDENTITY (a ring tautology) and
  explicitly NOT a formalization of the anchor's Theorems 3/4.
- NOT DELIVERED: optional T19 `ARBoverV_exact` (block M3(ii)'s exact CPMM
  kernel, the only carrier of the `σ²·Δt < 8` finiteness guard) — designated
  non-blocking at submission and omitted by the prover as permitted. The exact
  kernel therefore has no formal carrier; nothing in the leading-order program
  depends on it.
