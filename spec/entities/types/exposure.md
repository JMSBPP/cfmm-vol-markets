# Vega Exposure Architecture

## 1. Purpose

`VegaExposure` is an internal accounting layer between deposited collateral and CFMM token amounts.

It is not a separately traded token. It represents collateral discounted by a volatility price coordinate.

---

## 2. Core objects

Let:

\[
\Delta M
\]

be deposited collateral amount.

Let:

\[
\bar\sigma
\]

be the user’s volatility strike.

Let:

\[
p_{\mathrm{vol}}(\bar\sigma)
\]

be the Q64.96 price coordinate associated with that volatility strike.

Then vega notional is:

\[
N_v
=
\frac{\Delta M}{p_{\mathrm{vol}}(\bar\sigma)}
\]

Equivalently:

\[
\Delta M
=
N_v \cdot p_{\mathrm{vol}}(\bar\sigma)
\]

---

## 3. Type structure (v1 — live fields only)

```plank
const VegaExposure = struct {
      exposure: u256,     // u128 -- issued vega-exposure shares N_v
      priceVolX96: u256   // u160 -- Q64.96; carries the exogenous p_risk in v1
};
```

### v1 note — `priceVolX96` carries `p_risk`, not `p_vol(σ̄)`

In v1 there is no volatility oracle, so `priceVolX96` carries the EXOGENOUS, settable `p_risk`
(the haircut-adjusted risk price of `risk.md`), NOT the `p_vol(σ̄)` of §2. This tension is stated,
not silently renamed: the field keeps its `priceVol` lineage in the name while its v1 meaning is
`p_risk`. The §2 `N_v = ΔM/p_vol(σ̄)` derivation is the v2+ target that arrives with oracle wiring.

### Deferred fields

`collateralToken`, `underlyingToken`, and `riskOracleId` are intentionally ABSENT from the v1
`.plk` record. They return with the oracle-wiring milestone (see `REQUIREMENTS.md` "Out of Scope":
oracle wiring to `RealizedVolatilityMod`). The stub's `collateralUnits`/`priceVol` field names are
corrected to the spec names `exposure`/`priceVolX96`.
