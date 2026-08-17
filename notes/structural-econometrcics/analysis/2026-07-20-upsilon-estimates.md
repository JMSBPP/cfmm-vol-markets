# Panoptic vol-claim upsilon: live estimates — 2026-07-20

Phase 09 plan 09-09 (CTX-ALT + the live run). Estimation of

> `pi_it = beta0 + upsilon0 * exp(-kappa * |i_K - i_t|) * sigma2_t + v_it`

on LIVE Base Panoptic + Uniswap V4 data. Every number below is traceable to
raw data through the DATA LINEAGE section at the end; nothing here is
simulated, padded, or substituted.

## 0. Headline

**NULL RESULT: no vega structure is detectable in this cross-section.** The fitted vega level upsilon0-hat = 2.272704e-9 is numerically zero, so the moneyness decay kappa is STRUCTURALLY UNIDENTIFIED (SE 18.823959) and its test is vacuous. The best fit to the 61 observations is a constant premium rate beta0-hat = 2.357268e-4 USD/day (clustered SE 8.812796e-5). The formal witness does NOT obtain; see sections 3 and 6.

## 1. What the data actually supports (read before the estimates)

The specification asks for a POSITION-EPOCH panel: `pi_it` per tokenId per
daily epoch, from diffed cumulative settled-premia snapshots. **The live
subgraph cannot produce that object.** Introspection at this run established:

- `TokenId` has NO `snapshots` field — there is no per-epoch premium series.
- The `premiumSettleds` event collection is EMPTY for this deployment.
- `AccountBalance.premiaSettled0Total` and `premiaSettled1Total` are
  IDENTICALLY ZERO for every account balance on this market.
- `Leg.strike` is already an int24 TICK (observed range -202,990 … -197,280),
  not a price. (Plan 09-04's `round(log K / log 1.0001)` took the log of a
  negative number; that bug is fixed.)

The only premium the chain reports is `OptionBurn.premium{0,1}` — the premium
realized over a position's ENTIRE life. The unit of observation is therefore
the **accrual spell** (one (mint, burn) pair), with `pi` expressed as USD PER
DAY over the spell and `sigma2` averaged over the same epoch window.

**This is a departure from the spec's stated design.** Its consequences:

- There is no within-position time variation, so the position-FE alternative
  is expected to be unidentified (every tokenId is close to a singleton).
- `upsilon0` is identified off CROSS-SPELL covariation of the premium rate
  with the window-average variance, not off within-position covariation as
  spec 4.4 intends. This is a weaker identifying argument and should be
  treated as such.
- Spreading a spell's premium uniformly across its days was REJECTED: a
  constant `pi` against a varying `sigma2` would manufacture a mechanical
  null. No synthetic variation was introduced anywhere.

Sample: **61 accrual spells**, 61 usable after the sigma2 join, 55 distinct tokenIds, 4 distinct accounts, 119 variance epochs.
This is a THIN cross-section and the estimates below must be read as such.

## 2. Headline estimates

### Primary — GSL Levenberg-Marquardt NLS, tokenId-clustered CR0 sandwich SEs

| parameter | estimate | clustered SE | 95% CI |
|---|---|---|---|
| beta0 (intercept, USD/day) | 2.357268e-4 | 8.812796e-5 | [6.299596e-5, 4.084576e-4] |
| upsilon0 (vega level) | 2.272704e-9 | 1.263759e-4 | [-2.476946e-4, 2.476991e-4] |
| kappa (moneyness decay, per tick) | -7.415292e-3 | 18.823959 | [-36.902376, 36.887545] |

Account-clustered SEs (coarser, 4 clusters): beta0 1.387054e-4, upsilon0 1.069874e-4, kappa 15.935991.
With only 4 clusters the Normal approximation on the
account-clustered covariance is unreliable; it is reported for transparency,
not for inference.

### EIV IV (two noisy measures: sigma~2 instruments sigma2)

| parameter | IV estimate |
|---|---|
| beta0 | 2.357268e-4 |
| upsilon0 | 2.272823e-9 |
| kappa (held at the NLS value by construction) | -7.415292e-3 |

The IV corrects attenuation on `upsilon0` from measurement error in the
realized-variance regressor (spec 3.3 threat M1). `kappa` is identified off
moneyness, not the variance level, so it is conditioned on rather than
re-estimated (spec 4.3).

## 3. The three committed specification tests (spec 5)

All computed on the tokenId-CLUSTERED covariance, never naive OLS SEs.

| # | restriction | statistic | p-value | reject at 5%? |
|---|---|---|---|---|
| 1 | upsilon0 > 0 (upsilon is a vega) | z = 1.798367e-5 | 0.499993 | False |
| 2 | **kappa > 0 (THE null test)** | z = -3.939284e-4 | 0.500157 | False |
| 3 | kappa+ = kappa- (symmetric decay) | W = 5.909836e-6 | 0.998060 | False |

Test 3 identification: 34 observations above the money, 27 below.

> **kappa IS NOT IDENTIFIED ON THIS SAMPLE — read test 2 as vacuous.**
>
> kappa enters the model ONLY through `upsilon0 * exp(-kappa*d) * sigma2`.
> The fitted `upsilon0-hat = 2.272704e-9` is numerically zero: the
> largest contribution the vega term can make to `pi` anywhere in the
> sample is 5.771954e-12, against a fitted intercept
> of 2.357268e-4. With the vega term extinguished, kappa has NO
> effect on the fit at ANY value — which is exactly why its standard error
> is 18.823959, orders of magnitude larger than the estimate.
>
> The honest reading is that the best fit to this cross-section is a
> CONSTANT premium rate `pi = beta0`, with no detectable variance-times-
> moneyness structure at all. The `kappa > 0` test statistic is reported
> above for completeness but carries no information, and neither
> rejecting nor failing to reject it says anything about the conjecture.

Test 2 is the econometric twin of the Lean conjecture
`Upsilon.ATMOTMNullHypothesis`: H0 kappa = 0 (flat vega profile) versus
H1 kappa > 0 (maximal at the money, exponential decay out of the money).

**Verdict: the null test is VACUOUS on this sample.** kappa is not identified (see the box above), so H0: kappa = 0 can be neither rejected nor sustained. This is a NULL RESULT about the data's information content, not evidence about the vega profile.

## 4. The four locked alternative specifications (spec 6.2)

### semiparametric

Observations: 61, clusters: 55.

| coefficient | estimate | clustered SE |
|---|---|---|
| beta0 | 1.092526e-4 | 1.405334e-4 |
| upsilon_bin0 | 0.115242 | 0.498201 |
| upsilon_bin1 | 2.696335 | 1.280099 |
| upsilon_bin2 | -6.896538e-2 | 0.109005 |
| upsilon_bin3 | 7.514111e-2 | 0.351849 |
| upsilon_bin4 | 8.648794e-2 | 0.105794 |

Estimated vega profile (the SHAPE the null is read off):

| moneyness d (ticks) | upsilon-hat(d) |
|---|---|
| 35.083333 | 0.115242 |
| 87.583333 | 2.696335 |
| 165.272727 | -6.896538e-2 |
| 288.461538 | 7.514111e-2 |
| 876.461538 | 8.648794e-2 |

Shape read-off: **NOT INTERPRETABLE.** The estimated profile is NON-MONOTONE in moneyness (bin values 0.115242, 2.696335, -6.896538e-2, 7.514111e-2, 8.648794e-2), so it exhibits neither the exponential decay of H1 nor the flat profile of H0.

Note: degree-0 B-spline (regressogram) vega profile on 5 moneyness quantile bins, σ̂² linear; read the null off estCurve: declining υ̂ in moneyness = evidence for κ>0, flat = evidence for H₀

### seed-linear

Observations: 61, clusters: 55.

| coefficient | estimate | clustered SE |
|---|---|---|
| beta0 | 2.474178e-4 | 9.812598e-5 |
| upsilon_ibar | 0.181392 | 0.186555 |
| gamma | 5.475312e-4 | 2.699576e-4 |

Note: seed tick-linearization, strike centered at the mean pool tick i-bar = -201488. This form cannot express an ATM PEAK (it is monotone in the tick), so it detects only a local slope. gamma = 5.475312344362469e-4 > 0 - the OPPOSITE sign to the one kappa > 0 predicts (vega RISING with the strike). Read alongside the semiparametric profile before concluding anything from it.

### position-FE

**NOT IDENTIFIED / NOT ESTIMABLE.**

Reason: kappa_FE = 1.0e-6 sits ON THE BOUNDARY of the search grid, so the within objective is FLAT in kappa: the within variation (only 11 observations across 5 multi-spell tokenIds) does not identify the decay rate. The no-selection diagnostic is therefore UNAVAILABLE and the strike-composition threat is UNRESOLVED, not cleared.

Observations seen: 11, clusters: 5.

### collateral

Observations: 372, clusters: 4.

| coefficient | estimate | clustered SE |
|---|---|---|
| QM_upsilon0 | 16643.666250 | 12667.916594 |
| upsilon_collateral | -209748.377601 | 199992.357825 |

Note: CAVEAT FIRST: Q_M here is DEPOSITED collateral shares reconstructed from CollateralDeposit/Withdraw events, NOT the protocol's required margin. The subgraph exposes no per-position collateral requirement (collateral*Shares is a CURRENT snapshot only; CollateralDayData is vault-level), so this is a behavioural quantity and is NOT the spec's Q_M. Any comparison with the premium-channel upsilon0 is suggestive at best. Clustered by ACCOUNT.


## 5. Lean <-> Haskell <-> spec cross-walk

The formal-witness claim below is only as good as the fidelity between the
Haskell estimator and the Lean definitions. The auditable object-by-object
table lives at `notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md`.
Load-bearing rows:

| Lean | Haskell | spec | note |
|---|---|---|---|
| `Upsilon.upsilon` vega family `u0*exp(-k*di*|i-iK|)` | `Model.Upsilon.model` = `b0 + u0*exp(-k*d)*s2` | 4.3 | the estimating equation verbatim |
| `\|(i:R) - (iK:R)\|` | `Model.Upsilon.moneyness iK it` | 4.3 | same absolute-tick metric |
| `PosSpec.lam = 1.0001` | `Model.Upsilon.tickBase = 1.0001` | 2.4 | the sole technological primitive |
| `Upsilon.ATMOTMNullHypothesis` | `Tests.Specification.testKappaPos` | 5 | Lean pins the statement, Haskell tests it |
| `Upsilon.exp_family_witnesses_ATMOTM` (PROVED) | a fitted `kappa > 0` | 4.4 | the bridge, see section 6 |

## 6. FORMAL WITNESS statement

The Lean library proves, axiom-clean and sorry-free
(`lean/vol_markets/Upsilon.lean`):

```lean
theorem exp_family_witnesses_ATMOTM
    (u0 k di : R) (iK : Z) (hu : 0 < u0) (hk : 0 < k) (hd : 0 < di) :
    ATMOTMNullHypothesis
      (fun i => u0 * Real.exp (-k * di * |(i:R) - (iK:R)|)) di iK (k*di)
```

Its three hypotheses are `hu : 0 < upsilon0`, `hk : 0 < kappa`, and
`hd : 0 < Delta_i` (the tick spacing, 10 on this market, so `hd` holds by
inspection). The fitted values are:

- `upsilon0-hat = 2.272704e-9`  ->  `hu` **NOT usable** — positive in sign but numerically zero, so the strict inequality is satisfied only vacuously.
- `kappa-hat = -7.415292e-3`  ->  `hk` **cannot be evaluated** — kappa is unidentified once the vega term vanishes.
- `Delta_i = 10` (pool tickSpacing)  ->  `hd` SATISFIED

**The witness does NOT obtain.** The theorem's hypothesis `hu : 0 < upsilon0` fails at the point estimate (upsilon0-hat = 2.272704e-9, numerically zero), and because the vega term is extinguished `kappa` is not identified at all, so `hk : 0 < kappa` cannot be evaluated against the data either. The fitted profile is NOT a witness of `ATMOTMNullHypothesis`. Note what this does and does NOT say: the Lean theorem remains proved and axiom-clean, and the conjecture remains open. This cross-section simply carries no information about it.


## 7. Threats and caveats

1. **Unit of observation** — accrual spells, not position-epochs (section 1).
   This is the single largest departure from the spec and weakens the
   identifying argument for `upsilon0`.
2. **Thin cross-section** — 61 observations over 4 accounts. Cluster-robust inference with this few clusters
   is fragile; treat p-values as indicative, not decisive.
3. **Functional form** — `kappa`'s meaning is exponential-form dependent
   (spec 6.1.1). The semiparametric alternative is the check; read its curve.
4. **Strike-composition selection** — strikes were never declared exogenous
   (spec 2.5). The position-FE diagnostic is the intended check and is
   unidentified here, so this threat is UNRESOLVED, not cleared.
5. **Sign normalization** — long positions PAY premium (the protocol emits a
   negative premium); they are sign-flipped so `pi` is uniformly premium
   accrued to the SHORT side. Without this the same vega would enter with
   two opposite signs and cancel.
6. **Premium denomination** — `premium0` (ETH, 18 decimals) converted at the
   burn-tick pool price, not `premium1` (USDC, 6 decimals): USDC's 6 decimals
   truncate small premia to zero. Where both are non-zero they agree to
   within a few tenths of a percent.

## DATA LINEAGE (audit trail)

Run date: 2026-07-20. Everything below is reproducible from a clean
checkout with the commands given; all paths are repo-root relative.

### Sources

| what | source |
|---|---|
| chain | Base mainnet (L2), chainId 8453 |
| Panoptic subgraph | `https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn` (keyless public Goldsky; no GRAPH_API_KEY required or used) |
| panopticPool | `0xb50e8bb68f5855da742f4579274902a20454174a` (ETH/USDC, fee tier 500, tickSpacing 10) |
| underlying pool (Uniswap V4 poolId) | `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a` |
| token0 / token1 | ETH (native, 18 dec) / USDC `0x833589fcd6edb6e08f4c7c32d4f71b54bda02913` (6 dec) |
| variance source | Base JSON-RPC `https://mainnet.base.org`, chunked `eth_getLogs` |
| V4 Swap topic0 | `0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f` |
| V4 PoolManager (log emitter) | `0x498581ff718922c3f8e6a244956af099b2652b2b` |
| block range pulled | 43781657 .. 48879461 |

**BigQuery is NOT used.** The GCP project is suspended (403 CONSUMER_SUSPENDED)
and the underlying pool is Uniswap V4 on Base, whose swaps are emitted by the
PoolManager singleton keyed by a 32-byte poolId — not by a pool address in
`crypto_ethereum`. See `notes/structural-econometrcics/data/DATA-SOURCES.md` 4.3.

### Files

| path | contents | rows |
|---|---|---|
| `notes/structural-econometrcics/data/panel.csv` | accrual-spell panel from the subgraph | 61 |
| `notes/structural-econometrcics/data/variance.csv` | daily sigma2, sigma2_instrument, pool_tick_mean | 119 |
| `notes/structural-econometrcics/data/swap-ticks-base-v4-full.csv` | raw (unix, tick) Swap cache (gitignored: large, regenerable) | see below |
| `notes/structural-econometrcics/data/collateral-flows.csv` | signed collateral share flows | see file |
| `notes/structural-econometrcics/data/estimation-panel.csv` | FINAL estimation panel (handed to the GAMS cross-check) | 61 |

### Epoch definition

`epoch = floor(unixSeconds / 86400)` — whole UTC days since the Unix epoch,
boundary at 00:00 UTC. Defined ONCE in `Panel.Build.dailyEpoch` and imported by
`Panel.Variance`, so the premium windows and the variance windows cannot drift
apart.

### Construction steps

1. `build-panel` pulls the FULL history of `optionMints`, `optionBurns` and
   `tokenIds { legs }` for the pool (cursor pagination on `timestamp_gt`, not
   `skip`, because `skip` is capped at 5000).
2. Each burn is paired with the LATEST mint of the same (tokenId, account)
   strictly preceding it -> an accrual spell.
3. `pi` = `premium0 / 1e18 * 1.0001^tickAtBurn * 1e12` (USD), sign-flipped for
   long positions, divided by the spell length in days -> USD/day.
4. `i_K` = `Leg.strike` of the position's first leg (already an int24 tick).
5. `variance` pulls V4 `Swap` logs over the block range, decodes the int24 tick
   from data word 4, and computes per UTC day: `sigma2` = sum of squared
   tick-implied log-price increments over the full within-day swap series;
   `sigma2_instrument` = the same estimator on the disjoint EVEN-indexed swap
   sub-window (two noisy measures, the EIV instrument); `pool_tick_mean` = the
   day's mean tick.
6. `estimate` joins the two by averaging `sigma2`, `sigma2_instrument` and
   `pool_tick_mean` over each spell's epoch window `[epoch_mint, epoch_burn]`,
   then sets `d = |i_K - i_t|` with `i_t` the window-average pool tick.
7. Fit: `Numeric.GSL.Fitting.fitModel` (Levenberg-Marquardt, analytic
   Jacobian). SEs: hand-rolled CR0 cluster sandwich `(J'J)^-1 [sum_g s_g s_g']
   (J'J)^-1`, golden-tested to 1e-9 (`Model.SandwichSE`). Tests: one-sided
   Normal for the sign restrictions, chi-squared(1) Wald for the symmetry
   restriction (`Tests.Specification`), p-values from the `statistics` package.

### Reproduce

```sh
stack --stack-yaml econometrics/stack.yaml exec econometrics -- build-panel \
  --endpoint <subgraph-endpoint> --pool <poolId>
stack --stack-yaml econometrics/stack.yaml exec econometrics -- variance \
  --from 43781657 --to 48879461 --chunk 10000
stack --stack-yaml econometrics/stack.yaml exec econometrics -- estimate \
  --endpoint <subgraph-endpoint> --pool <poolId> --rpc <base-rpc-url> \
  --from-block 43781657 --to-block 48879461
```

The endpoint, poolId and RPC URL are the values recorded in the Sources table
above. No API key is required for any of them.

