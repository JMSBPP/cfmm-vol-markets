# Risk Price and H1 Issuance

## 1. Issuance risk price

The issuance risk price is the haircut-adjusted oracle price:

    p_risk = oracle / (1 − h)

Design authority — machine-checked Lean (`JMSBPP/cfmm-vol-markets-spec`: `lean/vol_markets/RiskDesign.lean`, no `sorry`):

- `haircutRiskPrice` (RiskDesign.lean ~line 113) — the definition above.
- `haircutRiskPrice_ge_oracle` (RiskDesign.lean ~line 119) — `p_risk ≥ oracle` for all `0 ≤ oracle` and `0 ≤ h < 1`.
- `issuance_haircut_equiv` (RiskDesign.lean ~line 123) — the composed and direct issuance paths are equal OVER ℝ (see §4).

The earlier draft `RiskDiscount` formula — collateral scaled by the ratio of price to haircut — is
REFUTED by the Lean (singular at `h = 0`, inverted monotonicity: value grew as the haircut shrank)
and is removed, in prose AND in its `.plk` embodiment (the deleted `RiskDiscount.plk` /
`RiskMeasureLib.plk`). It must never be reintroduced in `spec/` or `src/`.

## 2. Quote convention

- `p_risk` is **Q64.96**, a **LINEAR** price (NOT a `sqrtPriceX96`), quoted as **collateral units per 1 vega-exposure unit**, in **raw smallest units on both sides** (collateral base units per vega-exposure base unit).
- `oracleX96` (the pre-haircut risk price) uses the **same** convention.
- Direction of conservatism: higher `p_risk` → fewer shares per deposit. The haircut RAISES `p_risk`
  (`oracle/(1−h) ≥ oracle`, `haircutRiskPrice_ge_oracle`), so it can only REDUCE issuance.

## 3. Per-operation integer realization

Fixed-point conventions: price **Q64.96** (`X96`); haircut **Q0.96** (`hX96 < 2^96`). (This REPLACES
the draft's obsolete 64-bit-fraction haircut convention.)

Note on notation: the `−` below is the Unicode minus for readability; `.plk` CODE must use ASCII `-`
(the checked subtraction operator — never the wrapping `-%`).

- Risk price — rounds UP (it is a divisor; larger is conservative), computed with Plank's default
  CHECKED subtraction `2^96 - hX96`:

      p_risk = mulDivRoundingUp(oracleX96, 2^96, 2^96 − hX96)

  Revert envelope: the checked `-` reverts (never wraps) for `hX96 > 2^96`. At the boundary
  `hX96 = 2^96` the subtraction yields `0` WITHOUT reverting — the revert then comes for free one
  operation later from `mulDivRoundingUp`'s zero-denominator check (`full_math.plk:13–24`,
  `revert_empty()`, inherited from `mulDiv`). So the `hX96 ≥ 2^96` inputs are fully excluded by the
  composition of the two operations; no separate explicit `h < 1` guard is required for the revert
  envelope. (Phase 13's `haircut_risk_price` MAY still add an explicit `hX96 < 2^96` guard for a
  clearer error, but a mutant that deletes it is EQUIVALENT here, not a kill — the zero-denominator
  revert masks it.)

- Shares, composed path — rounds DOWN / FLOOR:

      shares = mulDiv(deposit, 2^96, pRiskX96)

- Shares, direct path — rounds DOWN / FLOOR:

      shares_direct = mulDiv(deposit, 2^96 − hX96, oracleX96)

### Share units

Shares inherit the collateral token's **native decimals**: in `shares = mulDiv(deposit, 2^96, pRiskX96)`
the `2^96` in the numerator and the Q96 scale of `pRiskX96` in the denominator cancel, so `shares`
carries the same decimals (raw smallest units) as `deposit`. There is no separate "share decimals"
quantity.

## 4. ℝ-only status of `issuance_haircut_equiv`

`issuance_haircut_equiv` is proven over ℝ ONLY. In integers the composed path (§3, ceil then floor)
and the direct path round at different points, so exact cross-path equality is FALSE. Only the
one-sided transfer holds:

    composed ≤ direct        (verified: 0 violations in a 200k-sample random sweep)

### Verified counterexample — also the Phase 13 rounding anchor

Inputs: `deposit = 10`, `oracleX96 = 10·2^92`, `hX96 = 3·2^92`, so `2^96 − hX96 = 13·2^92`.

- `oracleX96 · 2^96 = 160·2^184`; `160 mod 13 = 4`, so the division is INEXACT and `p_risk` rounds up:
  `pRiskX96 = mulDivRoundingUp(10·2^92, 2^96, 13·2^92) = 60944740395587951995033807951`.
- Composed: `shares = mulDiv(10, 2^96, pRiskX96) = 12`.
- Direct:  `shares_direct = mulDiv(10, 13·2^92, 10·2^92) = 13`.

So composed = 12, direct = 13 (gap 1). The gap grows with `deposit / 2^96`: at
`deposit = 2^100, oracleX96 = 10·2^92, hX96 = 3·2^92` the gap is exactly 6 (verified). This
counterexample point is INEXACT at BOTH hops — the `p_risk` ceil and the `shares` floor are each
load-bearing here — which is why Phase 13's non-fuzz unit anchor must sit here: a floor-instead-of-
ceil `p_risk` mutant yields `pRiskX96 − 1` and flips `shares` 12 → 13, AND a ceil-instead-of-floor
`shares` mutant also yields 13. (An anchor whose divisions are exact would kill neither mutant; an
`h = 0` anchor still exercises the `shares` division, so it can catch a shares-rounding flip only if
that division happens to be inexact — the prescribed both-hops-inexact anchor is what pins BOTH
rounding sites at once.)

## 5. Deferred (future sections — NOT specified here)

Distance pipeline D2, risk-price composition P0/P2, stateful `setHaircut`, oracle wiring to
`RealizedVolatilityMod`, and `p_vol(σ̄)` from `pos_spec` are out of scope for v1 — see
`REQUIREMENTS.md` "Out of Scope". They may be referenced as future work but must not be specified here.
