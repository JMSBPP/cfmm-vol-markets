# Implementable alternatives for `d`, `p_risk`, and haircut

The formal specification is `RequestProject/RiskDesign.lean`. It distinguishes
three quantities that should have separate types and invariants:

- **distance/weight `d`**: dimensionless, unsigned, in `[0,1]`;
- **risk price `p_risk`**: strictly positive, in the same price convention as
  `p(i(σx96))` (in this project, Q64.96/X96);
- **haircut `h`**: a dimensionless loss fraction in `[0,1]`; the retained-value
  factor is `1-h`.

Do not call the haircut itself a “price”, and do not implement collateral value
as `price / haircut`: that expression is singular at zero haircut and becomes
*larger* as the haircut becomes smaller. Use either retained value
`amount × oracle × (1-h)` or the equivalent issuance risk price
`oracle/(1-h)`.

## 1. Alternatives for `d(p_risk,p)`

All dynamic alternatives must be clamped to `[0,1]`, represented as unsigned
Q0.96, and multiplied with `mulDiv(amount,dX96,2^96)` rounding down.

### D0 — identity weight

`d = 1`.

- Operations: none.
- Use: exact accounting identity, migration/fallback mode.
- Limitation: expresses no price risk.
- Formal facts: the earlier `discounted_eq_total_iff_pos` proves that, with
  positive positions, this is the **only** universal choice for which
  `Σ Qvᵢ dᵢ = Σ Qvᵢ`.

### D1 — two-band/step weight (lowest dynamic gas)

`d = 1` when `abs(p-p_risk) ≤ tolerance`, otherwise `floorWeight`.

- Storage: `toleranceX96`, `floorWeightX96 ≤ 2^96`.
- Operations: safe absolute difference, comparison, branch.
- Strength: no division and easy governance parameters.
- Limitation: discontinuity at the band edge.
- Formal facts: `distanceBand_mem`, `distanceBand_eq_one_of_close`.

### D2 — clipped linear distance (recommended smooth default)

`d = clamp01(1 - abs(p-p_risk)/scale)`, with `scale > 0`.

Integer implementation without signed arithmetic:

```text
dev = absDiff(pX96, riskX96)
if dev >= scaleX96: dX96 = 0
else:                dX96 = 2^96 - mulDiv(dev, 2^96, scaleX96, roundUp)
```

Rounding the penalty upward makes the resulting weight conservative. This is
continuous, equals one when prices agree, and reaches zero at `scale`.
Formal facts: `distanceLinear_mem`, `distanceLinear_self`,
`distanceLinear_eq_zero_of_far`.

### D3 — ratio weight (useful but more convention-sensitive)

A symmetric multiplicative alternative is
`min(p,p_risk)/max(p,p_risk)` for positive prices. It is scale-invariant and in
`(0,1]`, but costs a full-precision division. It should be used only if both
inputs are unquestionably the same kind of price. In particular, do not mix a
spot price with a square-root price.

## 2. Alternatives for `p_risk`

Every choice needs the invariants `p_risk > 0`, common decimals/base, common
quote direction, freshness, and bounded oracle deviation. Store the result as
`uint160` X96 if it must compare directly to `sqrtPriceX96`; otherwise first
convert all feeds into one explicitly documented price convention.

### P0 — conservative maximum

`p_risk = max(spot,TWAP)`.

- Operations: one comparison.
- Effect: because issuance is `deposit/p_risk`, it never issues more shares than
  using either input alone.
- Good default when “larger price means more risk” under the chosen quote
  convention.
- Formal facts: `riskPriceMax_ge_left/right`, `riskPriceMax_pos`.

If the quote direction is reversed, conservatism may require `min`, not `max`;
this must be decided at the type/API boundary rather than inside the formula.

### P1 — buffered oracle

`p_risk = oracle × (1 + premium)`, with `premium` clamped to `[0,1]`.

- Encode `premium` as Q0.96 and use one full-precision `mulDiv`.
- Produces a price between `oracle` and `2×oracle` for nonnegative oracle.
- Suitable when governance or a volatility module supplies a premium.
- Formal facts: `riskPriceBuffered_bounds`, `riskPriceBuffered_pos`.

### P2 — max plus premium (recommended conservative composition)

`p_risk = max(spot,TWAP) × (1 + premium)`.

This combines manipulation resistance from a lagging reference with an explicit
risk buffer. Check oracle freshness before arithmetic and define a fallback
policy (revert, or use a separately validated feed); never silently use zero.

## 3. Haircut alternatives

### H0 — retained-value haircut (recommended for valuation)

`collateralValue = amount × oracle × (1-h)`, `0 ≤ h ≤ 1`.

- `h=0`: full value; `h=1`: zero value.
- Use two fused `mulDiv` calls, rounding down at each externally visible
  collateral-value boundary.
- Formal facts: `haircutFactor_mem`, `haircutValue_bounds` prove the result lies
  in `[0, amount×oracle]` for nonnegative inputs.

### H1 — haircut embedded in risk price (recommended for issuance API)

`p_risk = oracle/(1-h)`, requiring `0 ≤ h < 1`, then
`shares = deposit/p_risk`.

This is algebraically equal to `deposit×(1-h)/oracle`, proved by
`issuance_haircut_equiv`. It also satisfies `p_risk ≥ oracle`, proved by
`haircutRiskPrice_ge_oracle`; hence it can only reduce issuance. Reject `h=1`
rather than dividing by zero.

### H2 — tiered haircut

Choose `h` from a small governance table keyed by collateral/risk tier, then use
H0 or H1. It is cheaper and more auditable than evaluating a nonlinear curve
on-chain. A dynamic off-chain risk engine can update the tier subject to delay,
bounds, and access control.

## 4. Recommended typed pipeline

```text
OraclePriceX96  := uint160, validated > 0 and fresh
WeightX96       := uint128, invariant <= 2^96
HaircutX96      := uint128, invariant <= 2^96
Amount          := uint256 in documented token/RAY units

baseRisk = max(validSpotX96, validTwapX96)                    // P0
riskX96  = mulDiv(baseRisk, 2^96 + premiumX96, 2^96, Up)     // P2
dX96     = clippedLinearDistance(riskX96, positionPriceX96)   // D2
kept     = mulDiv(amount, 2^96 - haircutX96, 2^96, Down)      // H0
adjusted = mulDiv(kept, dX96, 2^96, Down)
```

For an admissible share flow, compute `ΔQv = ΔQM/p_risk` with full-precision
`mulDiv` rounding down, and enforce the already formalized cross-multiplied
bound. Avoid raw 256-bit products in guards: use a 512-bit `mulDiv` routine or a
division-based overflow-safe equivalent.

`RiskDesign.mulX96Down_le` proves at the integer level that a clamped X96 weight
cannot increase an amount, including floor rounding; `mulX96Down_one` proves
that encoded one preserves it exactly.

## 5. Decision summary

- Need exact original accounting equality: **D0**.
- Need cheapest dynamic rule: **D1 + P0 + tiered H2**.
- Need a smooth conservative default: **D2 + P2 + H0**.
- Need a share-issuance API with one effective price: **D2 + P2/H1**, with
  `h<1` checked explicitly.

The key correction remains: a nontrivial `d∈[0,1]` defines a *risk-adjusted
subtotal*, not the accounting `totalShares`. Keep both state variables or derive
the former without overwriting the latter.
