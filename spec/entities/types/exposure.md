# Vega Exposure Architecture

## 1. Purpose

`VegaExposure` is an internal accounting layer between deposited collateral and CFMM token amounts.

It is not a separately traded token. It represents collateral discounted by a volatility price coordinate.

---

## 2. Core objects

Let:

\[
C
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

Then vega exposure is:

\[
E_v
=
\frac{C}{p_{\mathrm{vol}}(\bar\sigma)}
\]

Equivalently:

\[
C
=
E_v \cdot p_{\mathrm{vol}}(\bar\sigma)
\]

---

## 3. Type structure

```solidity
struct VegaExposure {
    uint128 exposure;
    uint160 priceVolX96;
    address collateralToken;
    address underlyingToken;
    uint16 riskOracleId;
}
```
