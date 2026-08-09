# RESEARCH REGISTER — Phase 6b, three-source sweep

**Requirements:** LIT-01, LIT-02, LIT-03
**Swept:** 2026-08-09
**Screened against:** `control/spec/ECONOMETRICS-DESIGN.md` — the estimand `Ḡ = ∂ν/∂λ_MEV`,
the `Δt` exclusion restriction, and the staged gate.

**This register is the input everything downstream rests on.** Adding a source after `EST-03`
returns is a **protocol violation** on the same footing as re-specification — "we found a paper
suggesting a better instrument" is the standard laundering route around a re-specification ban
(`LIT-02`). Any such addition is recorded in §6 as a violation, not appended silently.


## Inherited, not assumed

Phases 1, 2, 3 and 6a are UNEXECUTED. Nothing in this register presumes they landed.

1. **O4 — `σ` versus `σ²` units** (Phase 1 `NOT-05`). `DOC` Definition 18's sigmoid argument is
   `σ(i(t))`; the plant's `u_ex` carries `σ²(i(t))`. A register row reporting an effect size in
   volatility units states which of the two it is, or says it cannot tell. **This plan does not
   answer O4** — `06B-01` runs the dimensional check that bears on it. **UNRESOLVED at plan
   time.**
2. **The event-clock ruling** (Phase 2 `FRM-03`). Whether `t` indexes swaps or blocks, and
   whether event-averaged `ΔQ_M, ΔQ_X` may be combined with time-averaged `π^LVR·Δt, σ², λ`.
   Phase 2 SC3 names this phase's identification as one of the results at risk if it stays OPEN.
   **UNRESOLVED at plan time.**
3. **The hypothesis discipline** (Phase 3 `PRF-03`, `PRF-06`). `H1_dLbar_dpiPhi_pos` and
   `H2_dnu_dlamMEV_pos` are typed hypotheses, never submitted to the proving pipeline. **The
   written protocol does not exist at plan time.**
4. **`NEC-04`'s coupling verdict and its recomposition rule** (Phase 6a).
   `ECONOMETRICS-DESIGN.md:31` classifies `∂ν/∂λ_MEV` as **"Behavioural. Not derivable."** and
   `NEC-04` reopens that ruling. **This phase assumes NEITHER verdict.** The verdict **does not
   exist at plan time.**
5. **`NEC-00`'s affine-in-`Ḡ` verdict** (Phase 6a). The composition
   `∂π̂^σ/∂τ = (∂π̂^σ/∂φ)·[(1−φ_M)(1−φ_X) + (∂φ/∂ν)·Ḡ·(∂λ/∂τ)]` was refuted-as-a-free-option by
   two independent reviewers and by the orchestrator's own derivation, but a two-reviewer
   consensus is **not** a machine-checked identity (`REQUIREMENTS.md` `NEC-00`: "verified, not
   inherited"; the Gates table lists it **NOT REACHED**). Everywhere this register or any
   downstream artifact relies on it, it is stated as **PENDING `NEC-00`'s formal carrier**,
   never as established.

**The review register** (Phase 1 `HND-05`) does not exist at plan time, so this artifact carries
its own `## Review` section instead of an entry in it. That section is **not yet written** — see
the status note above.

## 1. Class A — the internal corpus (LIT-01)

Roster confirmed on disk on 2026-08-09 by
`ls -1 ../plank/refs/mev/ ../plank/refs/flair/`: exactly the fourteen basenames below, no drift,
no extras, no missing files. Extraction was **targeted** (user ruling): abstract, data/empirics
section and results tables only, via `pdftotext` page-ranged text extraction against the
peer-owned PDFs, which were **read, not modified**.

**A note on what the `Estimated effect size` field means here.** Several of these papers report
numbers that are *computed from a closed-form model* rather than *estimated from data*. Those
are recorded as `NO EMPIRICAL CONTENT` with the model-computed numbers named, because a
model-computed number carries no standard error and cannot discharge an empirical claim. The
distinction is load-bearing for this phase and is not smoothed over.

### S-01 — CapponiCarteaDrissiDiscreteClearing.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** structural model (equilibrium model of discrete clearing with paid-priority ordering and endogenous participation), supported by descriptive empirics — no causal design, no counterfactual estimation
**Data source:** Uniswap v3 on Ethereum — 15 pools, transactions between 1 January 2023 and 31 December 2023, restricted to pools with multiple transactions in at least 10 different blocks; a separate Ethereum priority-fee sample covering 20–21 March 2024 appears in the appendix
**Unit of observation:** transaction, indexed by its queue position within a block
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT in the estimation sense — Figure 1 plots normalized average trading volume declining in within-block queue position with no coefficient and no standard error; the cross-venue magnitude it invokes (mean liquidity-taking trade ≈ $70,000 on the most active Ethereum DEX versus ≈ $1,200 on Binance, 1 Jul 2021 – 31 Dec 2023) is quoted from Cartea, Drissi and Monga (2025), not estimated here
**Evidence anchor:** Figure 1 caption, §3 — "The transactions are between 1 January 2023 and 31 December 2023 in 15 different Uniswap v3 pools with multiple transactions in at least 10 different blocks."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — block time is the paper's central comparative static and it establishes that longer block times amplify adverse selection, which is a sign-consistent prior for the `Δt` first stage; but it supplies no instrument, no dispersion number and no LP-supply quantity, so it motivates rather than identifies.

### S-02 — CapponiJiaAdoptionDEX.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** structural model plus two-way fixed-effects panel regression (AMM and week fixed effects); associational, explicitly framed as statistical support for model implications rather than as causal identification
**Data source:** transaction-level histories of trades, deposits and withdrawals for 80 AMMs on Uniswap V2 and Sushiswap; the estimation panel uses the 30 AMMs initiated by 22 December 2020, over the 25-week period 22 December 2020 – 20 June 2021
**Unit of observation:** AMM-week (pool-week); N = 750
**Instrument used:** NONE — identification rests on within-pool variation net of AMM and week fixed effects, with standard errors clustered at the AMM level (30 clusters)
**Estimated effect size:** deposit-flow rate on exchange-rate volatility, −0.394 (s.e. 0.182, p<0.05) without controls and −1.451 (s.e. 0.405, p<0.01) controlling for volume; trading volume +0.052 (s.e. 0.020, p<0.01); R² = 0.14. Standardized: a one-standard-deviation rise in weekly spot-rate volatility (0.04) lowers the deposit-flow rate by 0.25 of its own standard deviation, and a one-standard-deviation rise in volume (1.98) raises it by 0.35.
**Evidence anchor:** §6.4.1 / Table 2 — "After controlling for trading volume, a one-standard-deviation increase in weekly spot rate volatility (which is equal to 0.04) decreases the deposit flow rate by 25% standard deviations of that variable."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — this is the closest analogue in the corpus to `H1` (`∂L̄/∂π^φ`): an LP-supply quantity regressed on a pool-level covariate, on the pool-period unit `EST-07` must cluster over, and its 30-cluster design is a directly usable effective-N precedent. It does NOT transfer as identification: the outcome is deposit flow rather than `ν`, the regressor is volatility rather than `π^φ`, and there is no instrument, so it prices the panel design, not `Ḡ`.

### S-03 — CapponiJiaWangLitToDark.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** theory plus reduced-form regressions with day fixed effects and day-clustered standard errors, around the introduction of a dark venue (Flashbots); no excluded instrument and no formal difference-in-differences design
**Data source:** own Ethereum archive node (modified geth) exporting all Uniswap/Sushiswap swap receipts from block 10,000,835 (4 May 2020) to block 12,344,944 (30 April 2021); Flashbots API private-channel transactions 11 February – 31 July 2021, cut before EIP-1559; Blockchair Ethereum block data 1 May 2020 – 31 July 2021
**Unit of observation:** block (miner-revenue regression, N = 1,762,017) and day (adoption rate, frontrun probability, cost-to-revenue ratio)
**Instrument used:** NONE
**Estimated effect size:** joining the dark venue raises miner revenue by 0.16 ETH per block (s.e. 0.032, p<0.01; R² = 0.02); a 1% increase in the probability of being frontrun raises users' dark-venue adoption rate by 0.6%; arbitrageurs' cost-to-revenue ratio rises by about one third with a dark venue; measured adoption rises from 0.02 (Feb–Mar 2021) to 0.348 (Apr–May) to 0.597 (Jun–Jul)
**Evidence anchor:** §6.4.2 / Table 2 — "Table 2 indicates that joining the dark venue on average increases miners’ revenue by around 0.16 ETH per block."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — it demonstrates a block-level, day-clustered design on exactly the Ethereum MEV data class this project would use, and reports a behavioural elasticity of the same shape as `Ḡ` (a 1%-on-0.6% response of a user-side choice to an MEV-exposure measure). It does not transfer as identification: the treatment is a venue introduction rather than block time, and no exclusion restriction is stated or defended anywhere in the paper.

### S-04 — CapponiJiaZhuJITLiquidity.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — THEORY ONLY (game-theoretic model with asymmetrically informed agents; subgame-perfect Nash equilibrium and comparative statics)
**Data source:** NONE
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the quantitative content is existence conditions and comparative statics (Proposition 4.1 gives an equilibrium-existence threshold under a two-tiered fee with transfer rate in [0,1]). The empirical magnitudes the paper cites — a 0.6 bp price improvement on a million-dollar order, and over 30,000 JIT provision instances — are attributed to Adams et al. (2023) and Xiong et al. (2023) and are not estimated here.
**Evidence anchor:** Abstract, and §4 Proposition 4.1 — "JIT LPs thus only provide liquidity to uninformed orders and crowd out passive LPs when order volume is not sufficiently elastic to pool depth, possibly reducing overall market liquidity."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the crowding-out condition is stated as an elasticity of order volume to pool depth, i.e. exactly the behavioural-elasticity class `Ḡ` belongs to, and it establishes that the sign of an aggregate LP-supply response can invert relative to naive intuition. It is unestimated, so it constrains interpretation rather than supplying evidence. **Notation collision recorded, not adopted:** this paper's fee transfer rate is written with the same glyph this project uses for the MEV hazard. They are unrelated objects; no symbol is minted or remapped here.

### S-05 — CapponiZhuTimeboost.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** difference-in-differences / two-way fixed-effects event study around a natural experiment — the deployment of Timeboost on Arbitrum on 17 April 2025 — with other EVM Layer-2 networks as controls; the parallel-trends assumption is stated and defended explicitly
**Data source:** Dune Analytics transaction-level panel over Arbitrum, Optimism, Polygon, Base and Avalanche (C-Chain), 17 February – 17 June 2025
**Unit of observation:** chain-day; 605 observations across 5 groups
**Instrument used:** NONE — the design turns on a policy-date × treated-chain interaction, not on an excluded variable
**Estimated effect size:** log repeated transactions −0.699 (s.e. 0.281, p<0.05) and −0.698 (s.e. 0.254, p<0.01) with controls; log platform revenue +0.726 (s.e. 0.123, p<0.01) and +0.711 (s.e. 0.112, p<0.01) with controls. Standard errors clustered by chain over **only 5 clusters**, with HC3 robust errors reported as a check precisely because clustered errors are biased at that group count.
**Evidence anchor:** §6 / Table 4 — "The coefficient on Post×Treated is negative and statistically significant (about −0.70 standard deviations), indicating that after Timeboost implementation, Arbitrum experienced a sizable decline in repeated transactions relative to the comparison L2s."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — this is the only paper in the corpus operating on the **chain-level axis** `LIT-04` must choose over, and it is direct evidence that a multi-L2 Dune-sourced panel is constructible over Arbitrum/Optimism/Polygon/Base/Avalanche, which is a candidate-chain finding rather than a specification. It does not transfer as identification — its estimand is a mechanism-adoption effect, not `∂ν/∂λ_MEV` — and its 5-cluster inference is a **warning** for `EST-07`, not a template to copy.

### S-06 — ChitraTheoryMEV2Uncertainty.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — THEORY ONLY (uncertainty principles in the harmonic-analysis sense, applied to transaction ordering)
**Data source:** NONE
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — no dataset, no regression and no calibration appear anywhere in the paper; the results are qualitative trade-off bounds
**Evidence anchor:** Abstract — "This provides a quantitative trade-off between the freedom to reorder transactions and the complexity of an economic payoff to a user in a decentralized network."
**Transfer verdict:** DOES NOT TRANSFER — it supplies no data, no unit of observation and no instrument. Its ordering-versus-payoff-complexity bound constrains what any MEV mitigation can achieve in principle, but it is silent on `∂ν/∂λ_MEV` and silent on `Δt` as an excluded variable.

### S-07 — DaianEtAlFlashBoys2.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** measurement study plus a game-theoretic model of priority gas auctions; descriptive throughout, with no causal design and no reported standard errors
**Data source:** purpose-built instrumentation — a forked go-ethereum client on six geo-distributed nodes with NTP-synchronised timestamps, nine months of mempool observations, supplemented by Google BigQuery Ethereum on-chain data and coinmetrics.io daily prices for USD conversion
**Unit of observation:** transaction, and bid within a priority gas auction
**Estimated effect size:** NO EMPIRICAL CONTENT in the estimation sense — the headline quantity is a measured **lower bound** of over USD 6M on the pure-revenue arbitrage economy, plus per-auction worked examples (a 0.77 ETH ≈ 267 USD profit at November-2018 prices). These are descriptive totals; no coefficient, no standard error, no elasticity.
**Instrument used:** NONE
**Evidence anchor:** §V, deployed PGA measurement infrastructure — "We collected nine months of data, amounting to over 300 gigabytes, including 708,385,840 unique observations of PGA arbitrage bots."
**Transfer verdict:** DOES NOT TRANSFER — the mempool-level instrumentation that produces its measurements is unavailable to this project's Dune route, the unit of observation is the auction bid rather than the pool, and it reports no regression, no instrument and no LP-side quantity.

### S-08 — GuoInvarianceMEV.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — THEORY ONLY (formal invariance theorems over a measure-theoretic model of blockchain markets)
**Data source:** NONE
**Unit of observation:** NONE
**Instrument used:** NONE — but the paper is directly *about* the excluded variable this project proposes, which is why it is the most consequential theory entry in Class A
**Estimated effect size:** NO EMPIRICAL CONTENT — the results are qualitative invariance and monotonicity statements, with no magnitudes: Theorem 6 gives equality of MEV under block subdivision in the frictionless case, and Theorem 7 gives a weak inequality with fees while the noncompetitive component stays exactly invariant
**Evidence anchor:** §3, Theorem 7 (MEV is nonincreasing with shorter block times with fees) — "In the setting with fees, if the underlying pool is efficient, frictionless, and path-independent, and the asset price is a martingale, then the noncompetitive MEV does not depend on block times, but the competitive MEV may shrink as block times get shorter."
**Transfer verdict:** TRANSFERS — and it transfers **adversely**, which is why it is recorded rather than filed. It bears on the *relevance* half of the `Δt` exclusion restriction, not the exogeneity half: block-time variation moves MEV only through a strictly positive fee, only for the *competitive* component, and only weakly — an inequality, not a magnitude — while the noncompetitive component is exactly invariant. A first stage regressing `λ_ARB` on `√Δt` therefore has relevance that is theoretically signed but **unbounded below**, which is a formal statement of the weak-instrument risk `ECONOMETRICS-DESIGN.md` §2 already names. Recorded as a threat to be priced by `EST-02`, never as a rebuttal to it.

> **CORRECTED DOWNSTREAM — this block's verdict is superseded by `S-33`.** `S-08` and `S-33` are
> the same paper. This block reads `TRANSFERS` and treats the theorem as a signed-relevance result.
> §2.5's adversarial pass established that the paper's §7 takes **liquidity providers to be
> passive** — this project's estimand assumed zero — and that the noncompetitive component is
> **exactly invariant**. The governing verdict is `S-33`'s **DOES NOT TRANSFER as support for the
> instrument**. **§1.15's verdict tally counts this block in the `TRANSFERS` bucket and is
> therefore stale by one**; it is left as originally written rather than silently re-tallied, and
> this banner is the correction.

### S-09 — KulkarniDiamandisChitraTheoryMEV1.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — THEORY ONLY (game-theoretic; price-of-anarchy and worst-case reordering bounds), illustrated with constructed numerical instances
**Data source:** NONE — the Pigou and Braess network instances are constructed, not observed
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the quantitative content is worst-case bounds: a constant price of anarchy when sandwich impact is suitably localized, and a logarithmic bound on maximum reordering price impact. The paper names empirical estimation of MEV as future work, not as something it performs.
**Evidence anchor:** Abstract — "In the case of reordering, we show conditions when the maximum price impact caused by the reordering of sandwich attacks in a sequence of trades, relative to the average price, impact is O(log n) in the number of user trades."
**Transfer verdict:** DOES NOT TRANSFER — the bounds are worst-case and unit-free, there is no data, and the sandwich channel it prices is precisely the `λ_sandwich` term that `DOC:1041` already scopes out of the `λ_MEV = λ_ARB` regime this project works in.

### S-10 — MazorraDellaPennaCFMMWelfareMEV.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — THEORY ONLY (welfare analysis; asymptotic approximation to Walrasian equilibrium under an exchange economy with random endowments)
**Data source:** NONE
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the result is an asymptotic welfare-approximation statement and an unquantified lower bound on extractable value under scarce blockspace
**Evidence anchor:** Abstract — "This gives a lower bound on the maximal extractable value exposed when blockspace is scarce."
**Transfer verdict:** DOES NOT TRANSFER — no data, no unit of observation, no instrument, and the bound is asymptotic and unquantified, so it can neither motivate a specification nor bound a first stage.

### S-11 — MilionisMoallemiRoughgardenArbProfitsFees.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — THEORY ONLY. A continuous-time structural model of arbitrage against a two-asset AMM with proportional fees, discrete Poisson block generation and (in §6) gas fees, solved in closed form with fast-block asymptotics. **No estimation is performed anywhere in the paper. The anchor paper of this project's identification argument is not an empirical paper.**
**Data source:** NONE
**Unit of observation:** NONE — the model's index is the block, arriving as a Poisson process, and its quantities are instantaneous rates per unit time
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — every number is model-computed rather than estimated, and none carries a standard error. Table 1 tabulates the probability of trade (the fraction of blocks containing an arbitrage trade) at a daily volatility of 5% across mean interblock times and fee levels in basis points, spanning roughly 22.8% down to 0.3%. The scaling result is that with a strictly positive fee, in the fast-block regime, arbitrage profits go as the square root of the mean interblock time, the cube of volatility and the reciprocal of the fee.
**Evidence anchor:** §1 Results, below eq. (2) and Table 1 — "in the fast block regime arbitrage profits are proportional to the square root of the mean interblock time"
**Transfer verdict:** TRANSFERS WITH MODIFICATION — this is the source of the `√Δt` transform that `ECONOMETRICS-DESIGN.md` §2 puts in the first stage, and of the functional form of the arb probability the plant carries; it transfers as **structure**. It transfers as **nothing else**: no data, no unit of observation, no instrument, no standard error, so it cannot validate the exclusion restriction it motivates. Two further findings are recorded rather than lost. (a) §7.3's decomposition eq. (27) writes the delta-hedged LP P&L as the noise-trader fee term minus the arbitrage term, and the paper states that its structural contribution covers the **second** term only, leaving noise-trader activity to reduced-form modelling — that is the missing demand-elasticity term the `[M8]` caveats name, confirmed at source rather than inferred. (b) §7.3 names predicting the equilibrium liquidity level under a fee change, via free entry and exit of LPs, as an *application* of the framework — that object is `H1` (`∂L̄/∂π^φ`), and the paper leaves it open rather than estimating it, so `H1` gains no support here.

### S-12 — ObadiaEtAlCrossDomainMEV.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — THEORY ONLY (definitional formalism, self-described by the authors as a work in progress)
**Data source:** NONE
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the paper defines cross-domain MEV and enumerates open questions and externalities; it measures nothing
**Evidence anchor:** Abstract — "We note that the formalism in this work is a work-in-progress, and we hope that it can serve as the basis for formal analysis tools"
**Transfer verdict:** DOES NOT TRANSFER — no data, no design, no instrument. Its one relevance to this phase is negative and is recorded as such: cross-domain extraction implies a candidate chain's MEV is not a closed system, which is a threat to any single-chain exogeneity argument, but the paper supplies no way to bound that threat.

### S-13 — CampbellBergaultMilionisNutzOptimalFees.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** calibration — simulated-distribution matching that minimizes the L2 distance between the empirical and simulated distributions of the log AMM/CEX price ratio; there is no causal design, no instrument and no reported parameter uncertainty
**Data source:** Dune Analytics minute-level reserve balances for the ETH/USDC Uniswap v2 pool for January 2025 (fee fixed at 30 bp; opening reserves ≈ $23,000,000 and 6,903 ETH), plus minute-level Binance ETH/USDC prices for the same month as the reference price
**Unit of observation:** minute
**Instrument used:** NONE — the identifying variation is the shape of the log price-ratio distribution, matched by simulation rather than by an excluded variable
**Estimated effect size:** calibrated rather than estimated, and reported without a covariance matrix. At an AMM fee of 30 bp: fundamental buy/sell rate 19,068 ETH/day, CEX trading cost 6.58 bp, daily volatility 2.60% carrying the explicit unit day^(−1/2). Re-calibrated at 35 bp to proxy gas costs: 10,338 ETH/day, 11.78 bp, same 2.60% day^(−1/2). A robustness variant using the historical Binance series directly returns 11,684 ETH/day and 9.87 bp.
**Evidence anchor:** §5.2 / Table 2 (Calibrated parameters) — "Although historical volatility could be used for the value of σ, this leads to an overestimation of the volatility due to clustering effects, and we rather rely here on a model-implied volatility that allows for a better fit to the price ratio."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — it is the only source in the corpus that both takes an optimal-fee schedule to real pool data and reports volatility with an explicit time dimension of day^(−1/2), i.e. as a **rate to the half power** and not a variance. That is evidence bearing on open item **O4** but is **NOT a ruling on it** — `06B-01` runs the dimensional check, and this register does not pre-empt it. Its route is calibration, so it may motivate a specification and screen a venue but supplies no first stage, no F statistic and no dispersion number. Its substantive finding — that the optimal fee is close to the CEX trading cost and stable except under high volatility, favouring a threshold-type dynamic schedule — is a prior about the venue's `AdaptiveFee` shape, not an estimate of `Ḡ`.

### S-14 — MilionisWanAdamsFLAIR.pdf
**Class:** INTERNAL-PDF
**Identification strategy:** NONE — METRIC DEFINITION ONLY. The abstract claims particular merit in empirical analyses, but no empirical analysis is performed in the paper.
**Data source:** NONE — the figures are stated by the authors to be synthetic
**Unit of observation:** NONE — the metric is defined per LP position per unit time, but no observations are taken
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the worked cases (a simple full-range CFMM, and Uniswap v3 with fully competitive positions) are analytic limits, not measurements
**Evidence anchor:** §2.2, footnote 8 to Figure 1 — "Note that the figures amount to synthetic data, and we did not perform empirical analysis of actual pools to generate the data."
**Transfer verdict:** DOES NOT TRANSFER — and the verdict is recorded explicitly to block a conflation this project has already been warned about. FLAIR is an ex-post fee-return-on-capital competitiveness metric for LPs; it is not a hazard, it is not this project's `λ_FLAIR` versus `λ_MEV` monotonicity carry-forward, and this paper establishes nothing about the relation between them — because it establishes nothing empirically at all.

### 1.15 Roster check

- **Blocks written:** fourteen (`S-01` … `S-14`).
- **Basenames enumerated:** fourteen — twelve under `PLANK/refs/mev/`
  (`CapponiCarteaDrissiDiscreteClearing.pdf`, `CapponiJiaAdoptionDEX.pdf`,
  `CapponiJiaWangLitToDark.pdf`, `CapponiJiaZhuJITLiquidity.pdf`, `CapponiZhuTimeboost.pdf`,
  `ChitraTheoryMEV2Uncertainty.pdf`, `DaianEtAlFlashBoys2.pdf`, `GuoInvarianceMEV.pdf`,
  `KulkarniDiamandisChitraTheoryMEV1.pdf`, `MazorraDellaPennaCFMMWelfareMEV.pdf`,
  `MilionisMoallemiRoughgardenArbProfitsFees.pdf`, `ObadiaEtAlCrossDomainMEV.pdf`) and two under
  `PLANK/refs/flair/` (`CampbellBergaultMilionisNutzOptimalFees.pdf`,
  `MilionisWanAdamsFLAIR.pdf`).
- **Evidence anchors:** fourteen, each naming a locator inside its own paper and quoting a
  verbatim span from that locator.
- **Transfer verdicts, summing to fourteen:** `TRANSFERS` 1 (`S-08`); `TRANSFERS WITH
  MODIFICATION` 7 (`S-01`, `S-02`, `S-03`, `S-04`, `S-05`, `S-11`, `S-13`); `DOES NOT TRANSFER`
  6 (`S-06`, `S-07`, `S-09`, `S-10`, `S-12`, `S-14`). 1 + 7 + 6 = 14.
- **Roster drift:** none. The directory listing matched the specified fourteen exactly, so no
  drift entry is owed in §6.

### 1.16 What Class A did and did not settle

Recorded here because §2's sweep is scoped against it and because these are the findings most at
risk of being lost between plans.

1. **The anchor paper is not empirical.** `S-11` supplies the `√Δt` structure the first stage
   rests on and supplies no identification whatsoever. Anything downstream that cites it as
   evidence *for* the instrument is citing structure as if it were evidence.
2. **The relevance of `Δt` is theoretically conditional and weak.** `S-08` Theorem 7 makes
   block-time sensitivity of MEV contingent on a strictly positive fee, confined to the
   competitive component, and expressed as an inequality with no lower bound on magnitude. This
   is the sharpest statement of the weak-instrument risk available in the corpus and it comes
   from theory, not from a failed first stage.
3. **No paper in Class A instruments block time.** Zero of fourteen use `Δt`, interblock
   interval or slot cadence as an excluded variable. The `Instrument used` field reads `NONE`
   on all fourteen. Whether *any* prior work does is `LIT-02`'s question and is **not answered
   by Class A**.
4. **No paper in Class A estimates `∂ν/∂λ_MEV` or any close analogue.** The nearest objects are
   `S-02`'s pool-week LP deposit-flow response to volatility and `S-03`'s user-side response to
   frontrunning probability. Both are LP- or user-supply responses to an exposure measure; both
   are estimated without an instrument.
> **CORRECTED DOWNSTREAM — read with §2.5 and §4.** Items 3 and 4 above are true **as statements
> about Class A**, which is all they claim. They are **not** true as statements about the
> literature, and the first draft of §2.6 wrongly rested on them. §2.4 records that a
> peer-reviewed family of speed-and-latency instruments exists off arXiv; §4 row 9 records two
> published estimates of this project's own derivative, with coefficients and standard errors.
> Anything downstream citing item 3 or item 4 as evidence that the instrument or the estimand is
> unclaimed is citing a corrected finding.

5. **Two clustering precedents, in tension.** `S-02` clusters at the pool level over 30 clusters
   on a pool-week panel; `S-05` clusters by chain over 5 and reports HC3 because 5 is too few.
   `EST-07` must answer the effective-N question on the chain-level axis, where `S-05`'s problem
   is the one it inherits.

## 2. Class B — arXiv (LIT-02)

**Method, recorded as run rather than as specified.** The sweep was routed through the
`lit-review` skill at `--depth deep`. Phase 1 discovery ran as four sub-agents dispatched **in
parallel**, one per target class, each instructed to resolve every identifier through the arxiv
MCP and to return a complete query record. A fifth agent ran the Class C sweep of §3 concurrently
over web sources only.

**An incident is recorded because it bears on completeness.** Five concurrent agents plus the
orchestrator drove the arXiv MCP into sustained `HTTP 429` rate limiting. All four arXiv
dimension agents stalled mid-sweep for roughly twelve minutes; two of the fee-elasticity
dimension's planned queries **never executed**, and roughly a dozen identifiers that agent
surfaced remain unverified and are therefore **excluded from this register entirely** rather than
recorded on search metadata alone. Where an agent reported a resolution it had made, the
orchestrator **re-resolved the identifier itself** before writing the block. **Every identifier
below was resolved by the orchestrator through `mcp__arxiv__get_abstract` in this session, and
every recorded title is the string that call returned.** No identifier appears here on an agent's
assurance alone.

**Three of §1's fourteen internal PDFs turn out to have arXiv twins**, which the sweep surfaced
independently: `GuoInvarianceMEV` = `arXiv:2304.11010` (`S-33`),
`CapponiCarteaDrissiDiscreteClearing` = `arXiv:2605.17425` (`S-35`), and `CapponiZhuTimeboost` =
`arXiv:2512.10094` (`S-26`). This is not duplication to be pruned — it is a **cross-check on
Task 1**, and §4 records what it found.

### 2.1 Empirical AMM / LVR studies

Papers that *measure* an AMM quantity rather than deriving it. The class-level finding, which
recurs in every block below: **no source in this class reports a standard error on an LVR or MEV
magnitude.** Every number is either an accounting total or a simulated counterfactual. The
estimation-versus-calibration boundary this project depends on is essentially uncrossed here.

### S-15 — arXiv empirical AMM/LVR
**Class:** ARXIV
**arXiv id:** arXiv:2404.05803
**Resolved title:** Measuring Arbitrage Losses and Profitability of AMM Liquidity
**Identification strategy:** descriptive measurement plus a counterfactual simulation over block times — no causal design, no excluded variable
**Data source:** the largest Uniswap v2 and v3 liquidity pools, on-chain, against CEX reference prices
**Unit of observation:** block, aggregated to pool
**Instrument used:** NONE
**Estimated effect size:** MODEL-COMPUTED for the block-time comparison, with no standard errors — moving from Ethereum's 12-second blocks to 100ms blocks reduces losses to arbitrageurs by **20% to 70%**, varying by trading pair. Separately measured from data: arbitrage losses **exceed** fees earned across many of the largest pools, and v2 pools are more profitable for passive LPs than v3.
**Evidence anchor:** Abstract — "when comparing 100ms block times to Ethereum's current 12-second block times, the decrease in losses to arbitrageurs ranges between 20% to 70%, depending on the specific trading pair."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — this is the best available quantification of the `Δt` channel's magnitude, and the closest thing to a prior on the first stage's strength. It transfers as a **power input, never as an estimate**: the block-time variation is imposed by resampling rather than observed across treated and control units, so it carries no standard error and no exclusion argument. Its pair-level heterogeneity is a direct warning that the first stage will be heterogeneous across pools.

### S-16 — arXiv empirical AMM/LVR
**Class:** ARXIV
**arXiv id:** arXiv:2410.19107
**Resolved title:** What Drives Liquidity on Decentralized Exchanges? Evidence from the Uniswap Protocol
**Identification strategy:** predictive and associational factor regressions with an explicit channel decomposition; the authors claim predictive power, not causal identification
**Data source:** Uniswap protocol on-chain data across platform, blockchain, token-pair and pool levels, plus competing-DEX external liquidity and DEX-aggregator private inventory
**Unit of observation:** liquidity pool, with regressors at four nested levels
**Instrument used:** NONE
**Estimated effect size:** signs and channels rather than magnitudes — gas prices, returns and DEX volume share act through **concentration**; private-market-maker internalization moves **TVL but not overall market depth**; volatility, fee revenue and markout act through **both** channels
**Evidence anchor:** Abstract — "volatility, fee revenue, and markout affect liquidity through both channels."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the most useful source in the class for the **outcome** side. Its decomposition of market depth into a TVL channel and a concentration channel is a direct warning that `ν` must specify which margin it measures, since a fee or hazard shock can move one and not the other. It is also the canonical statement that DEX liquidity regressors live at four nested levels, which is the citation for why a chain-level instrument and a pool-level outcome must not share a clustering level. No instrument, so it identifies conditional correlations only.

### S-17 — arXiv empirical AMM/LVR
**Class:** ARXIV
**arXiv id:** arXiv:2507.13023
**Resolved title:** Measuring CEX-DEX Extracted Value and Searcher Profitability: The Darkest of the MEV Dark Forest
**Identification strategy:** descriptive measurement with a heuristic-refinement and revenue-estimation framework for the unobservable CEX leg
**Data source:** Ethereum on-chain DEX trades with CEX pricing and MEV-Boost data, August 2023 – March 2025 (19 months)
**Unit of observation:** arbitrage transaction (7,203,560 identified), aggregated to searcher and builder
**Instrument used:** NONE
**Estimated effect size:** measured aggregates without standard errors — **233.8M USD** extracted by 19 major CEX-DEX searchers across 7,203,560 arbitrages, with three searchers capturing three-quarters of both volume and extracted value. The binding uncertainty is classification error in the heuristic, not sampling error.
**Evidence anchor:** Abstract — "we estimate a total of 233.8M USD extracted by 19 major CEX-DEX searchers from 7,203,560 identified CEX-DEX arbitrages."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the most credible published route to constructing a realized `λ_MEV` regressor at block or pool level on Ethereum, directly relevant to `EST-01`'s constructibility verdict. The heuristic classifier is the weak link and cuts two ways: measurement error in `λ_MEV` attenuates OLS toward zero, which is an argument *for* instrumenting, but it also means the endogenous regressor is itself an estimate carrying unquantified classification error into the second stage.

### S-18 — arXiv empirical AMM/LVR
**Class:** ARXIV
**arXiv id:** arXiv:2401.01622
**Resolved title:** Non-Atomic Arbitrage in Decentralized Finance
**Identification strategy:** descriptive measurement via transaction classification; no causal design
**Data source:** Ethereum's five biggest DEXes, from the Merge to 31 October 2023
**Unit of observation:** transaction / arbitrage event, aggregated to searcher
**Instrument used:** NONE
**Estimated effect size:** descriptive shares without standard errors — more than **a fourth** of volume on Ethereum's five biggest DEXes is attributable to non-atomic arbitrage; eleven searchers account for over 80% of identified volume, totalling 132 billion USD; these transactions account for more than 10% of Ethereum's total block value
**Evidence anchor:** Abstract — "we uncover that more than a fourth of the volume on Ethereum's biggest five DEXes from the merge until 31 October 2023 can likely be attributed to this type of MEV."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — it establishes that the arbitrage flow this project models is a *first-order* share of observed DEX volume rather than a residual, which matters because `ν` is a utilization measure and a quarter of its numerator may be the very hazard being instrumented. That is a simultaneity warning for the outcome's construction, not an identification result.

### S-19 — arXiv empirical AMM/LVR
**Class:** ARXIV
**arXiv id:** arXiv:2501.17335
**Resolved title:** Cross-Chain Arbitrage: The Next Frontier of MEV in Decentralized Finance
**Identification strategy:** profit-cost model plus a year-long descriptive measurement; no causal design
**Data source:** transactions across **nine blockchains**, September 2023 – August 2024
**Unit of observation:** arbitrage trade (242,535 identified), aggregated to address and chain pair
**Instrument used:** NONE
**Estimated effect size:** descriptive totals without standard errors — 242,535 arbitrages totalling 868.64 million USD; activity grows 5.5x over the period and surges after the Dencun upgrade of 13 March 2024; 66.96% use pre-positioned inventory settling in 9s versus 242s for bridge-based; the five largest addresses execute more than half of all trades
**Evidence anchor:** Abstract — "we analyze one year of transactions (September 2023 - August 2024) across nine blockchains and identify 242,535 executed arbitrages totaling 868.64 million USD volume."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — its relevance to this phase is a **threat**, and it corroborates §1's `S-12` from data rather than from definition. Cross-chain extraction means a candidate chain's MEV is not a closed system, so a chain-level instrument's exogeneity argument must contend with arbitrage flowing across the very boundary that defines the cluster. It also names Dencun as a candidate event shock while showing that shock is bundled with fee changes.

### S-20 — arXiv empirical AMM/LVR
**Class:** ARXIV
**arXiv id:** arXiv:2403.09494
**Resolved title:** Layer 2 be or Layer not 2 be: Scaling on Uniswap v3
**Identification strategy:** descriptive cross-chain comparison; no formal identification and no controls for chain composition
**Data source:** Uniswap v3 on Ethereum mainnet versus the highest-activity L2 chains
**Unit of observation:** swap and LP position, aggregated by chain
**Instrument used:** NONE
**Estimated effect size:** directional, without standard errors — better gas-adjusted execution on cheaper and faster chains, more capital-efficient LPs, and higher LP fee returns from more arbitrage; plus the claim that two-second block times may already be too long for optimal LP returns
**Evidence anchor:** Abstract — "We also present evidence that two second block times may be too long for optimal liquidity provider returns, compared to first come, first served."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the clearest statement that the *raw material* for a `Δt` design exists, namely the same protocol deployed across chains with different cadence. It is equally the clearest statement of why that variation is not yet an instrument: the comparison confounds block time with gas price and chain composition, and separating them is exactly the exclusion restriction this project must defend and this paper does not.

### 2.2 Fee-versus-flow elasticity

The closest analogue class to `H1` (`∂L̄/∂π^φ`) and to the behavioural content of `Ḡ`.

### S-21 — arXiv fee-versus-flow elasticity
**Class:** ARXIV
**arXiv id:** arXiv:2607.08525
**Resolved title:** Causal Effects of Protocol-Fee Changes on Liquidity Provision in Automated Market Makers
**Identification strategy:** pre-specified matched-overlap event-study difference-in-differences around the Uniswap protocol-fee switch, with named assumptions, a parallel-trends gate that some outcomes fail, and a channel-admissibility audit; treatment read from on-chain events, panel frozen and hash-checked before any estimate
**Data source:** Uniswap v3 public on-chain logs, 2024-01 to 2026-06, canonical-factory filtered; treatment is the LP take-rate cut with tier-differentiated intensity, trader-facing fee unchanged
**Unit of observation:** pool × UTC week — 779 matched treated pools, 303 matched controls, 17,598 pool-weeks in the primary ±8-week window
**Instrument used:** NONE — design-based DiD, no excluded variable
**Estimated effect size:** ESTIMATED and reported as intervals rather than point-plus-standard-error, and it is a **non-detection**. Time-weighted active liquidity ATT interval **[−1.11, 0.33]** on the inverse-hyperbolic-sine scale with an 80% minimum detectable effect of about 1.03 asinh units; local depth **[−2.02, 1.27]**; LP participation and composition are tightly estimated nulls with minimum detectable effects near 0.1 asinh. **Token-1 volume and native fee income fail the parallel-trends gate and are demoted to descriptive.** Clustering is at the **token-pair** level with a restricted wild cluster bootstrap: **1,013 clusters** over 17,598 pool-weeks.
**Evidence anchor:** §4.2 Precision and robustness — "This is a non-detection at the design's resolution, not a high-precision zero."
**Transfer verdict:** TRANSFERS — and it is the most consequential single entry in this register. It estimates almost exactly this project's `H1` kernel, the LP-supply response to a fee-income shock, and finds nothing detectable. Three consequences, all binding. **(a)** The well-powered part is only participation and composition; the intensive margin carries a minimum detectable effect of roughly a factor of 2.8, so `H1` survives as an extensive-margin null with the intensive margin entirely live — this is **not** evidence that `∂L̄/∂π^φ = 0`. **(b)** Its volume outcome — the closest published object to `ν` — **failed the causal gate**, which is the most informative fact available about `H2`'s identifiability: the same fee variation that identifies the LP side does not identify the flow side. **(c)** Its protocol devices are directly adoptable and are named in §5.4 and §6: freezing and hashing the panel before estimating, pre-committing a gate that demotes failing outcomes to descriptive rather than dropping them, and pre-committing the phrase "non-detection at the design's resolution" so that a null cannot later be written up as a zero.

### S-22 — arXiv fee-versus-flow elasticity
**Class:** ARXIV
**arXiv id:** arXiv:2606.13555
**Resolved title:** Price Elasticity of Gas Demand on L1 and L2: Evidence from Ethereum and Arbitrum
**Identification strategy:** IV — two-way fixed-effects panel instrumented by each wallet's own lagged base fee, motivated as removing congestion-driven endogeneity
**Data source:** Ethereum mainnet for calendar year 2025; Arbitrum One October 2025 – April 2026
**Unit of observation:** wallet × period, with behavioural clusters of wallets reported separately
**Instrument used:** the wallet's **own lagged base fee**; the exclusion argument is that a lagged own fee shifts the fee faced without correlating with contemporaneous congestion shocks. The argument is asserted rather than defended, and a lagged own outcome is a weak exclusion in a serially correlated series.
**Estimated effect size:** ESTIMATED with significance markers — pooled IV elasticity **−0.006** on Ethereum L1 and **−0.036** on Arbitrum; per-resource L2 decomposition from −0.027 for computation to −0.27 for refunds; behavioural clusters differ by up to roughly **6x** the pooled estimate. Clustering level is not stated in the abstract and was not verified.
**Evidence anchor:** Abstract — "On Ethereum mainnet (full year 2025), the pooled IV elasticity is -0.006***, near-inelastic: a 10% fee increase reduces total gas demand by approximately 0.06%."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the cleanest *design template* in the sweep for a behavioural on-chain elasticity estimated by IV on panel data, and the only verified paper here that both instruments and reports an on-chain elasticity. It shows the community accepts an own-lagged-price instrument in this setting, which is the "secondary defence" of `ECONOMETRICS-DESIGN.md` §2, the predeterminedness of `λ_ARB`, already contemplated. Its magnitudes are a warning: aggregate on-chain demand quantities are **near-inelastic**, so `Ḡ` may be small enough that detection requires an agent-type decomposition rather than a pooled estimate.

### S-23 — arXiv fee-versus-flow elasticity
**Class:** ARXIV
**arXiv id:** arXiv:2307.13772
**Resolved title:** Fragmentation and optimal liquidity supply on decentralized exchanges
**Identification strategy:** theoretical model with descriptive cross-sectional empirics on Uniswap fee-tier choice; no DiD and no instrument
**Data source:** Uniswap fee-tier data, on-chain
**Unit of observation:** LP position / pool-tier
**Instrument used:** NONE
**Estimated effect size:** descriptive shares rather than elasticities — high-fee pools attract **58%** of liquidity supply yet execute only **21%** of volume; large LPs dominate low-fee pools and adjust out-of-range positions against informed flow, while small LPs converge to high-fee pools
**Evidence anchor:** Abstract — "Analyzing Uniswap data, we find that high-fee pools attract 58% of liquidity supply yet execute only 21% of volume."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the strongest cross-sectional evidence that LP capital sorts toward higher fees, i.e. that `∂L̄/∂π^φ > 0` in the sorting sense. It is selection across venues, not a causal elasticity within one. It carries a structural warning this project must absorb: fee and flow move in **opposite** directions across tiers, so `L̄` and `ν` cannot both be read off the same cross-sectional fee variation without a model of which margin is moving.

### S-24 — arXiv fee-versus-flow elasticity
**Class:** ARXIV
**arXiv id:** arXiv:2410.10324
**Resolved title:** Liquidity Fragmentation or Optimization? Analyzing Automated Market Makers Across Ethereum and Rollups
**Identification strategy:** Lagrangian optimization model with descriptive elasticity measurement; no DiD and no instrument
**Data source:** AMMs on Ethereum and its L2 rollups, with the staking rate as a benchmark
**Unit of observation:** AMM pool / chain
**Instrument used:** NONE
**Estimated effect size:** the numeric elasticities were **not verified at source** and are therefore not reported here. The qualitative finding is that the measured elasticity of trading volume with respect to TVL is **not reliably positive** on well-established chains, and that Ethereum pools are oversubscribed relative to L2s.
**Evidence anchor:** Abstract — "we measure the elasticity of trading volume with respect to Total Value Locked (TVL) in AMMs and find that, on well-established blockchains, an increase in TVL does not necessarily lead to higher trading volume."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the closest published measurement of a flow-to-liquidity elasticity, which is the reverse leg of `Ḡ`, and its near-zero or ambiguous finding is a direct threat to any specification that assumes utilization rises mechanically with depth. Recorded with its magnitudes withheld because they were not verified at source; it may motivate, and may not supply a number.

### 2.3 Pool-level panel regressions, clustering, and weak-instrument inference

`EST-07` must answer the effective-`N` and clustering questions **with numbers**. This subsection
supplies the citations that let those numbers be fixed by rule rather than asserted. It is
deliberately split between DeFi panel *practice* and econometric *method*, because the two
literatures disagree with each other.

### S-25 — arXiv pool-level panel
**Class:** ARXIV
**arXiv id:** arXiv:2306.17742
**Resolved title:** Blockchain scaling and liquidity concentration on decentralized exchanges
**Identification strategy:** IV / 2SLS — the only published chain-level-instrument, pool-level-outcome design found anywhere in this sweep
**Data source:** Uniswap v3 on Ethereum, Arbitrum and Polygon; hourly snapshots with mint and burn events, 2022-01-01 to 2023-06-30
**Unit of observation:** pool × 5-minute interval, with regressions run separately per pool
**Instrument used:** **the entry of the scaling solutions Arbitrum and Polygon** — a chain-level binary — instrumenting LP repositioning intensity. The exclusion argument runs explicitly through **gas cost**: scaling entry lowers gas, which raises repositioning frequency, which affects concentration only through repositioning.
**Estimated effect size:** ESTIMATED — a reported first-stage coefficient on the Arbitrum instrument of **0.24** for ETH/USDC 0.05%; higher repositioning intensity and precision raise liquidity concentration and reduce small-trade slippage. Hour and day fixed effects, with **standard errors clustered at the day level** despite an instrument that varies across only two or three chains.
**Evidence anchor:** Abstract — "We analyze the causal relation between repositioning and liquidity concentration around the market price, using the entry of blockchain scaling solutions, Arbitrum and Polygon, as our instruments."
**Transfer verdict:** TRANSFERS — the single most important precedent in §2, and it transfers as both template and warning. **Template:** a chain-level infrastructure shock instrumenting a pool-level LP outcome is a publishable design in this literature, which is structurally what `√Δt` proposes. **Warning, twofold.** Its exclusion restriction runs through **gas, not block time**, and an L2 entry moves gas and cadence together — so this design does not isolate `Δt`, and any project citing it as precedent inherits the confound rather than the solution. And it clusters on the **time** dimension while its instrument varies across a handful of chains, which does nothing for the effective-`N` problem; `S-29` shows why that is the wrong level.

### S-26 — arXiv pool-level panel
**Class:** ARXIV
**arXiv id:** arXiv:2512.10094
**Resolved title:** Auctioning Time to Mitigate Latency Races: Theory and Evidence from Blockchains
**Identification strategy:** two-way fixed-effects difference-in-differences around the Timeboost launch on Arbitrum of 17 April 2025, against comparison L2s with no sequencer-rule change; parallel trends discussed, with a placebo date and a narrower window
**Data source:** on-chain L2 data, 17 February – 17 June 2025
**Unit of observation:** chain × day
**Instrument used:** NONE — the design turns on a policy-date by treated-chain interaction
**Estimated effect size:** ESTIMATED — `Post×Treated` of **−0.699 (s.e. 0.281)** on log repeated transactions and **+0.726 (s.e. 0.123)** on log platform revenue, on **605 observations across 5 groups**, with standard errors **clustered by chain over only 5 clusters** and HC3 reported as an explicit robustness because clustered errors are biased at that group count.
**Evidence anchor:** §6.2, table note — "Includes chain and day fixed effects. Standard errors are clustered by chain."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the arXiv twin of §1's `S-05`, and its numbers match that block exactly, recorded in §4 as a cross-check that Task 1's extraction is accurate. It transfers as the live **5-cluster precedent** on the chain-level axis this phase must work on, and it transfers as the **trap**: `S-30` and the refinement literature say a 5-cluster design with an HC3 fallback is precisely the configuration that over-rejects. Cite it as the precedent; do not inherit its inference.

### S-27 — arXiv weak-instrument method
**Class:** ARXIV
**arXiv id:** arXiv:2010.05058
**Resolved title:** Valid t-ratio Inference for IV
**Identification strategy:** econometric theory with a re-examination of published applied work
**Data source:** 57 American Economic Review papers, re-analysed
**Unit of observation:** published IV specification
**Instrument used:** NONE — this is the paper that governs how instrument strength is tested
**Estimated effect size:** ESTIMATED over the literature — in the **single-IV model** the conventional first-stage `F > 10` rule is anti-conservative; a true 5% test requires **F > 104.7**, and retaining a threshold of 10 requires replacing the critical value 1.96 with **3.43**. Corrected inference turns **half** of the presumed-significant results in 57 AER papers insignificant.
**Evidence anchor:** Abstract — "We show that a true 5 percent test instead requires an F greater than 104.7."
**Transfer verdict:** TRANSFERS — and it is binding, because this project's design is exactly the single-IV model the paper addresses. `ECONOMETRICS-DESIGN.md` §2 says to report the first-stage F before the second stage but names no number, and `EST-07` requires one. This is the number, and it is an order of magnitude above the conventional threshold the design's own text gestures at. A pre-registration fixing `F ≥ 10` for a single instrument is, on this authority, pre-registering an anti-conservative test.

### S-28 — arXiv clustering method
**Class:** ARXIV
**arXiv id:** arXiv:1710.02926
**Resolved title:** When Should You Adjust Standard Errors for Clustering?
**Identification strategy:** econometric theory, framed as sampling inference and design inference
**Data source:** NONE — theory with illustrative cases
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the deliverable is a decision rule. Clustering is required for **design** reasons when treatment assignment is correlated with cluster membership, and for **sampling** reasons under two-stage sampling of clusters; conventional clustering is characterised as a potentially conservative all-or-nothing adjustment, and intermediate variance estimators are proposed.
**Evidence anchor:** Abstract — "Clustering can be needed to account for design issues if treatment assignment is correlated with membership in a cluster."
**Transfer verdict:** TRANSFERS — this settles the clustering level **on design grounds and before any data is seen**, which is what a pre-registration requires. The proposed instrument is assigned at the chain level, so the design criterion fires and the clustering level is the chain. Recording this in advance is what distinguishes a pre-registered clustering choice from one selected after seeing which level produces significance.

### S-29 — arXiv clustering and weak-instrument method
**Class:** ARXIV
**arXiv id:** arXiv:2306.08559
**Resolved title:** Inference in clustered IV models with many and weak instruments
**Identification strategy:** econometric theory with simulations and a re-analysis of an applied study
**Data source:** NONE — theory; the empirical revisitation concerns queenly reign and war
**Unit of observation:** NONE
**Instrument used:** NONE — the paper is about how clustering degrades instruments
**Estimated effect size:** NO EMPIRICAL CONTENT in this project's sense — the result is structural: clustering reduces the effective sample size from the number of observations toward the **number of clusters**, which makes instruments *more likely to be weak*; existing many-and-weak-instrument-robust tests assume independent observations and are inapplicable to clustered data, so jackknife Anderson–Rubin and jackknife score tests are adapted by deleting **clusters** rather than observations.
**Evidence anchor:** Abstract — "Data clustering reduces the effective sample size from the number of observations towards the number of clusters. For instrumental variable models this reduced effective sample size makes the instruments more likely to be weak"
**Transfer verdict:** TRANSFERS — this converts `EST-07`'s effective-`N` requirement from an assertion into a citation, and it does something sharper: it establishes that two of this project's problems are **the same problem**. A chain-level instrument with pool-level outcomes has an effective `N` near the chain count, and that shrinkage *mechanically weakens the instrument*. The weak-instrument risk named in `ECONOMETRICS-DESIGN.md` §2 and the clustering question in `EST-07` are therefore not independent items to be checked off separately.

### S-30 — arXiv few-clusters IV method
**Class:** ARXIV
**arXiv id:** arXiv:2108.13707
**Resolved title:** Wild Bootstrap for Instrumental Variables Regressions with Weak and Few Clusters
**Identification strategy:** econometric theory in the fixed-number-of-large-clusters asymptotic framework, with simulations and an application
**Data source:** NONE — theory; the application concerns US local labour markets
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the deliverable is a size-control result. The wild bootstrap Wald test controls size asymptotically **provided the endogenous parameter is strongly identified in at least one cluster**, and the required number of strong clusters for power against local alternatives is derived; a wild bootstrap Anderson–Rubin test controls size **even under weak or partial identification in all clusters**.
**Evidence anchor:** Abstract — "controls size asymptotically up to a small error as long as the parameters of endogenous variables are strongly identified in at least one of the clusters"
**Transfer verdict:** TRANSFERS — the prescription that fits a handful-of-chains IV panel exactly, and the reason a terminal non-identification verdict can still be *reported with valid size* rather than merely declared. The Anderson–Rubin variant survives weak identification in every cluster, which is the regime `S-29` says this design is most likely to occupy.

### S-31 — arXiv weak-instrument method
**Class:** ARXIV
**arXiv id:** arXiv:2309.01637
**Resolved title:** The Robust F-Statistic as a Test for Weak Instruments
**Identification strategy:** econometric theory generalizing the effective-F methodology to a class of linear GMM estimators
**Data source:** NONE — theory, with the grouped-data IV designs of Andrews (2018) as the motivating case
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the results are closed-form weak-instrument critical values requiring no simulation or distributional approximation, plus the finding that in grouped-data designs where the robust F is large but the effective F is small, the associated GMMf estimator is much less biased than 2SLS
**Evidence anchor:** Abstract — "In the grouped-data IV designs of Andrews (2018), where the robust F-statistic is large but the effective F-statistic is small, the GMMf estimator is shown to behave much better in terms of bias than the 2SLS estimator"
**Transfer verdict:** TRANSFERS — and it is load-bearing for a reason beyond convenience. Montiel Olea and Pflueger's effective-F paper, which `EST-07` names as the right criterion for a single weak instrument, is **not on arXiv** (§3 records this). This paper generalizes that methodology and is citable, and its motivating case — **grouped data where the robust F is large but the effective F is small** — is structurally this project's case, since a chain-level instrument groups the data by chain. It is the reason `EST-07` must report an *effective* F rather than a robust F.

### 2.4 Instruments on block time or realized volatility — the critical subsection

This is the question §1 could not answer and the reason `LIT-02` exists. `ECONOMETRICS-DESIGN.md`
§2 names weak instrumentation as the design's leading risk; this subsection prices it.

**VERDICT — FIRST DRAFTED AS AN ABSENCE, THEN DEMOLISHED BY §2.5's REFEREE. THE CORRECTED
VERDICT IS RECORDED HERE; THE SUPERSEDED ONE IS RECORDED WITH IT, BECAUSE THE CORRECTION IS THE
MOST IMPORTANT THING THIS SWEEP PRODUCED.**

**What the arXiv sweep returned.** Across the dimension agent's 13 arXiv queries and 18 web
queries, plus the orchestrator's own searches, **no arXiv paper uses block time, interblock
interval, slot time, or confirmation latency as an excluded instrument in an IV or 2SLS design.**
Three arXiv queries returned *literally zero results*: `"instrumental variable" AND blockchain AND
latency`; `"realized volatility" AND "instrumental variable"`; and `"exclusion restriction" AND
(crypto OR blockchain OR DeFi OR "decentralized exchange")`. On the arXiv corpus alone the
finding is `no prior instrument found`.

**That verdict was wrong as a statement about the literature, and it was wrong for a reason the
sweep's own design guaranteed.** The referee executed the SSRN / NBER / RePEc / journal attack
this register's arXiv-centred method could not, and found a **large, established, peer-reviewed
family of speed-and-latency instruments** in market microstructure. Verified by the referee from
methods text, with venue and DOI:

- **Hendershott, Jones and Menkveld (2011)**, *Journal of Finance* 66(1), 1–33, DOI
  `10.1111/j.1540-6261.2010.01624.x` — NYSE autoquote as an exogenous instrument for algorithmic
  trading, with a reported first stage.
- **Boehmer, Fong and Wu (2021)**, *JFQA* 56(8), 2659–2688, DOI `10.1017/S0022109020000782` —
  co-location introductions across 42 markets as the excluded instrument.
- **Rzayev, Ibikunle and Steffen (2023)**, *Journal of Financial Markets* 66, 100853, DOI
  `10.1016/j.finmar.2023.100853` — **transmission latency itself as the endogenous regressor**,
  instrumented by exchange latency upgrades and microwave-network counts, minimum first-stage
  F = 39, with an explicit argument for 2SLS over DiD in a speed setting.
- **Nimalendran, Rzayev and Sagade (2024)**, *JFE* 159, 103900, DOI
  `10.1016/j.jfineco.2024.103900` — a 500ms latency feature as the excluded instrument.
- **Chaboud, Chiquoine, Hjalmarsson and Vega (2014)**, *Journal of Finance* 69(5), 2045–2084,
  DOI `10.1111/jofi.12186` — installed algorithmic capacity as the instrument, LIML for
  weak-instrument robustness.

And **realized volatility has been used as an excluded instrument**, contrary to the arXiv-only
finding: **Christensen and Prabhala (1998)**, *JFE* **50(2)**, 125–150, DOI
`10.1016/S0304-405X(98)00034-8` — which uses lagged realized volatility as an instrument for
**implied** volatility in an errors-in-variables correction, **not** for contemporaneous
volatility as an earlier draft of this section stated; and **Jeanneau and Micu (2003)**, *BIS
Quarterly Review*, March 2003, which uses the first lag of volatility as an instrument for the
contemporaneous value. Both corrections were made at the two-step review.

Per §3.0 these are **peer-reviewed journal articles and are NOT Class C lower-rigor material**;
absence from a preprint server is not a rigour property, and they are cited from their venue of
record.

**PROVENANCE FLAG, required by the two-step review and stated because it qualifies the most
important correction in this register.** §2 states that no identifier appears on an agent's
assurance alone, and that rule was honoured for **every arXiv identifier**, each of which the
orchestrator re-resolved itself. **It was NOT honoured for the journal citations immediately
above.** They are **referee-sourced**: the referee reported reading their methods text, and the
orchestrator **did not independently re-verify them**, has attached no evidence anchor and no
verbatim quote to them, and the venues involved return 403 to automated retrieval. The review
additionally found that one of them was mis-cited in an earlier draft of this section (journal
issue and the instrumented object, both corrected above), which is direct evidence that this
class of citation in this register is **not** error-free. Downstream work must **re-verify these
citations at source before relying on them**, and `LIT-04` inherits that obligation. The
correction they support — that the latency-instrument family exists and the identification idea is
not novel — is retained because it is corroborated independently by `S-25`, which **is** fully
resolved and anchored, and which names the same traditional-market template.

**The corrected verdict, stated narrowly enough to be true.** `no prior instrument found` survives
only in this restricted form: **no prior work uses inter-block time specifically as the excluded
instrument.** The identification *idea* — instrumenting a market outcome with an exogenous shock
to execution speed — is not novel, is roughly fifteen years old, and has an established template
this project must position against rather than reinvent. `S-25` is the DeFi-native member of that
same family and cites Hendershott, Jones and Menkveld as its own template.

**One further correction, and it is adverse.** `S-25`'s first stage uses **realized volatility
over the prior 24 hours as a CONTROL, not as an instrument**. The DeFi IV literature has
therefore already taken the opposite position on the variable this subsection's original verdict
treated as unclaimed.

The original absence claim is left on the record above rather than deleted, because the
difference between it and the corrected verdict is exactly the value the adversarial pass added,
and because §5.5 forbids silent amendment of this register.

What the subsection *did* return is a body of work bearing on the instrument's **relevance** and
on its **exclusion restriction**. Both halves must be argued, and neither can be argued from
`S-11`'s structure alone.

### S-32 — arXiv block-time theory
**Class:** ARXIV
**arXiv id:** arXiv:2505.05113
**Resolved title:** Loss-Versus-Rebalancing under Deterministic and Generalized block-times
**Identification strategy:** NONE — THEORY ONLY (random-walk and ladder-height analysis), validated by Monte Carlo
**Data source:** NONE
**Unit of observation:** block — per block, per unit of liquidity
**Instrument used:** NONE
**Estimated effect size:** MODEL-COMPUTED with no standard errors — a closed-form per-block LVR under constant block time, and, extending to arbitrary block-time distributions, the result that under **every** admissible inter-block law the probability a block carries an arbitrage trade converges to a universal limit, with only constant block spacing attaining asymptotically minimal LVR
**Evidence anchor:** §4 Results on general distributions, Corollary on distribution-independent arbitrage probability — "To first order in the intra-block volatility, the asymptotic arbitrage probability is independent of the block-time distribution"
**Transfer verdict:** TRANSFERS — and the scope of the invariance is the whole point, so it is stated precisely rather than paraphrased. The invariance is over the **shape** of the inter-block law **at fixed mean**, to first order as intra-block volatility goes to zero. It is **not** invariance in the mean block time: the paper's intra-block volatility carries `Δt` inside it, so the universal limit is itself a `√Δt` law. Two consequences, one supporting and one restricting. **Supporting:** the limit appears to be the linearization of this project's own `ℙ` under a correspondence between the AMM spread and the fee, which would be independent corroboration of the first stage's functional form from a source outside the anchor paper. That correspondence is an algebraic claim carried into §2.5 for adversarial checking and is **not** treated as established here. **Restricting — AND CORRECTED AT THE ADVERSARIAL PASS, so the corrected form is what stands.** The first reading of this block asserted that block-time dispersion is not a source of instrument variation at all. That is **true of arbitrage INCIDENCE and false of arbitrage VALUE**: the shape of the inter-block law is first-order irrelevant for the per-block arbitrage *probability* at fixed mean, while the paper's dispersion functional enters the per-block LVR *magnitude* at leading order and vanishes only for a degenerate law. Which moment carries identifying variation therefore depends on whether `λ_MEV` is an incidence object or a value object — §5.4's voiding condition 7, unresolved. `06B-01` and `06B-02` are specified around measuring `Δt` **dispersion** as though that were settled, and must state which moment they measure, and why, before measuring anything. Recorded as the sweep's most consequential finding for the phase's own design, and carried into §5.4 as a voiding condition.

### S-33 — arXiv block-time theory
**Class:** ARXIV
**arXiv id:** arXiv:2304.11010
**Resolved title:** Invariance properties of maximal extractable value
**Identification strategy:** NONE — THEORY ONLY (formal invariance theorems)
**Data source:** NONE
**Unit of observation:** NONE
**Instrument used:** NONE — but the paper is directly about the proposed excluded variable
**Estimated effect size:** NO EMPIRICAL CONTENT — qualitative invariance and monotonicity statements with no magnitudes
**Evidence anchor:** Abstract — "this form of MEV is invariant under changes to the ordering mechanism of the blockchain and distribution of block times"
**Transfer verdict:** DOES NOT TRANSFER as support for the instrument — **this verdict was reversed by §2.5's referee and the reversal is the single most important correction in this register.** The block first read Guo as a relevance-*sign* result: §1's `S-08` had it adverse (an inequality with **no lower bound on magnitude**), the dimension-4 agent had it supportive (with fees the competitive component is **nonincreasing** in shorter block times, so a sign is established), and both readings are consistent with the theorem. That synthesis stands as far as it goes. **It does not go far enough, and the referee found why: §7 of the paper states its results assume liquidity providers are PASSIVE.** The theorem holds *because* LPs do not respond. This project's entire estimand **is** the LP response. Citing this paper as first-stage support therefore means citing, in favour of an LP-response regression, a theorem whose maintained hypothesis is that the response is zero — which is incoherent, not merely weak. Three further points compound it: the noncompetitive component is **exactly invariant**, so in the exclusive-orderflow and batch-auction regimes `DOC:1041` scopes into, the first stage is **zero**; the theorem concerns **k-fold subdivision** of one chain's blocks, not arbitrary cross-chain `Δt`, so Ethereum-versus-Arbitrum is not an instance of it; and the paper's own abstract states its results **rule out** designs aiming to increase trading opportunity by shortening block times. The paper is retained on the register as a **constraint to be satisfied**, never as evidence for relevance.

### S-34 — arXiv block-interval causal design
**Class:** ARXIV
**arXiv id:** arXiv:2305.02552
**Resolved title:** Understand Waiting Time in Transaction Fee Mechanism: An Interdisciplinary Perspective
**Identification strategy:** **regression discontinuity design** at the Merge, with robustness against censorship and privately routed transactions, plus a time-series analysis of NFT drops
**Data source:** Ethereum blockchain and mempool data around the Merge of 15 September 2022
**Unit of observation:** transaction / time
**Instrument used:** NONE — RDD, not IV; the excluded variation is the Merge cutoff
**Estimated effect size:** ESTIMATED, reported directionally — the Merge significantly reduces long waiting times, network loads and market congestion, with block-interval shortening identified as the most plausible cause among three concurrent protocol changes
**Evidence anchor:** Abstract — "examining three major protocol changes during the merge, we identify block interval shortening as the most plausible cause for our empirical results"
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the **closest prior in the literature** to treating block interval as a causal channel, and the strongest single piece of evidence that the channel is taken seriously as identifiable. It is not an instrument and gives no first stage, and its outcomes are latency and congestion rather than an arbitrage hazard or an LP-side quantity. It also demonstrates the hazard this project faces at the Merge: three protocol changes moved together, and separating them required an argument rather than a design.

### S-35 — arXiv block-time theory
**Class:** ARXIV
**arXiv id:** arXiv:2605.17425
**Resolved title:** The Viability of Blockchain Markets under Discrete Clearing and Paid Priority
**Identification strategy:** NONE — THEORY ONLY (equilibrium model of discrete clearing with paid-priority ordering and endogenous participation)
**Data source:** NONE for the theoretical results
**Unit of observation:** trader / transaction in queue position
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the results are comparative statics: paid-priority ordering induces endogenous selection through a participation cutoff that rises with competition, hindering price discovery, biasing prices, and increasing the adverse selection liquidity suppliers absorb
**Evidence anchor:** Abstract — "Although longer block times enhance consensus security, they amplify these effects and can cause markets to shut down."
**Transfer verdict:** TRANSFERS — and it transfers **adversely**, replacing weak relevance as the leading threat to this design. This is the arXiv twin of §1's `S-01`, but read for identification rather than for priors it says something `S-01`'s block did not: block time has a **direct path to participation, price discovery and adverse selection that does not run through the fee schedule**. The exclusion argument in `ECONOMETRICS-DESIGN.md` §2 establishes only that `Δt` is absent from `φ`; that is necessary and **not sufficient**, because the second-stage outcome `ν` is a utilization measure and this paper supplies a mechanism by which `Δt` moves participation directly. `EST-08` currently registers one violation path, through the `σ` channel; this is a **second and distinct** path, and it is not repaired by conditioning on `σ`.

### S-36 — arXiv block-time simulation
**Class:** ARXIV
**arXiv id:** arXiv:2601.00738
**Resolved title:** Second Thoughts: How 1-second subslots transform CEX-DEX Arbitrage on Ethereum
**Identification strategy:** NONE — simulation of a trading model with execution risk, calibrated to market data
**Data source:** calibrated to Binance and Uniswap v3 data, July – September 2025
**Unit of observation:** simulated arbitrage decision
**Instrument used:** NONE
**Estimated effect size:** MODEL-COMPUTED with no standard errors — moving from 12-second slots to 1-second subslots increases arbitrage transaction count by **535%** and trading volume by **203%** on average, driven by reduced variance of trade outcomes raising risk-adjusted returns
**Evidence anchor:** Abstract — "faster slot times increase arbitrage transaction count by 535% and trading volume by 203% on average."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the largest relevance magnitude anywhere in the sweep, and entirely simulated, so it transfers as a **power-calculation input and never as an estimate**. Its mechanism is also a caution: the effect runs through the *variance* of execution outcomes and the resulting risk-adjusted return, a channel absent from this project's `ℙ`, so a first stage calibrated on this magnitude would be assuming a mechanism the plant does not model.

### S-37 — arXiv block-time theory
**Class:** ARXIV
**arXiv id:** arXiv:2502.04097
**Resolved title:** Impermanent loss and Loss-vs-Rebalancing II
**Identification strategy:** NONE — THEORY ONLY, with simulation
**Data source:** NONE
**Unit of observation:** NONE — the analysis is in time steps and block times
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — the results are regime statements: three regimes distinguished by timescale, with fees creating a no-trade region that introduces a characteristic arbitrage timescale competing against the block time
**Evidence anchor:** Abstract — "Our main focus is on statistical properties, the impact of fees, the role of block times, and, related to the latter, the continuous time limit."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — it supplies the structural justification for the *form* of the hazard rather than evidence for it. A fee-induced arbitrage timescale competing against the block time, with a regime transition where they cross, is the qualitative content of `σ/(σ + φ√(2/Δt))`, and it independently reproduces the square-root scaling. Like `S-11` it transfers as structure and supplies no identification. Its regime result carries a warning for pooling across chains: if candidate chains sit on opposite sides of the fee-dominated transition, a single first-stage coefficient is misspecified.

### S-38 — arXiv chain-event study
**Class:** ARXIV
**arXiv id:** arXiv:2210.13655
**Resolved title:** An Event Study of the Ethereum Transition to Proof-of-Stake
**Identification strategy:** event study in a two-month window around the Merge, with spillover comparison to Polygon and Solana; no instrument and no formal control group
**Data source:** Ethereum, Polygon and Solana network data around 15 September 2022
**Unit of observation:** chain × day, across three chains
**Instrument used:** NONE
**Estimated effect size:** measured deltas without standard errors — energy consumption down 99.98%, block reward income down 97%, transaction fees in ETH up nearly 10%, the network 19% less concentrated, transactions per day up 7.0%; Polygon 3.3% fewer transactions per day and Solana 48% fewer
**Evidence anchor:** Abstract — "The time between consecutive blocks is now steady at 12 seconds and transactions per day are up 7.0%."
**Transfer verdict:** TRANSFERS — and it is the sharpest single constraint on this design's feasible sample. It establishes on measurement that **post-Merge Ethereum block time is a constant**, not a noisy quantity, so post-Merge Ethereum contributes **essentially zero instrument variation**. `ECONOMETRICS-DESIGN.md` §2 anticipated this qualitatively as 12 s with variation only from missed slots; this is the citable version, and it must enter the effective-`N` calculation **before** power is computed rather than being discovered during `EST-02`.

### S-39 — arXiv volatility-instrument attempt
**Class:** ARXIV
**arXiv id:** arXiv:2602.07018
**Resolved title:** The Extremity Premium: Sentiment Regimes and Adverse Selection in Cryptocurrency Markets
**Identification strategy:** predictive and Granger-causal design with stratification, plus an **attempted IV/2SLS robustness check that fails**; the paper is unusually candid about its own multiple-testing and functional-form fragility
**Data source:** Crypto Fear and Greed Index with Bitcoin daily data, extended to the full 2018–2026 history, N = 2,896
**Unit of observation:** asset-day
**Instrument used:** **volatility-proxy and calendar shocks** — VIX jumps, Monday effects and direction changes — instrumenting an uncertainty regressor. This is the closest thing in the sweep to a realized-volatility instrument, and it does not work.
**Estimated effect size:** ESTIMATED, and the instrument **fails**: a first-stage `F = 4.14`, below the threshold of 10 the paper cites and far below `S-27`'s 104.7. **Recorded against the source's own framing:** the familiar 10 is the Staiger–Stock rule of thumb; Stock–Yogo's single-instrument 10%-maximal-size critical value is 16.38, and `S-27` supersedes both for this design. The paper accordingly declines to make causal claims from the IV.
**Evidence anchor:** §5.9.2 — "These instruments proved weak (first-stage F=4.14, well below the Stock-Yogo threshold of 10), precluding formal causal claims via IV."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the most useful cautionary datapoint in the sweep, and the only observed first-stage strength for anything resembling a volatility instrument in crypto. It is not a `Δt` instrument, so it does not bound this project's first stage; it establishes that the one prior attempt to instrument with volatility-type shocks in this asset class produced a weak instrument and was correctly abandoned. The structural difference `EST-02` must argue rather than assume is that `Δt` is chain-level and protocol-set rather than a market outcome.

### S-40 — arXiv latency and arbitrage
**Class:** ARXIV
**arXiv id:** arXiv:1812.00595
**Resolved title:** Building Trust Takes Time: Limits to Arbitrage for Blockchain-Based Assets
**Identification strategy:** reduced-form empirical analysis of cross-exchange price differences against settlement latency; correlational, with no excluded instrument
**Data source:** Bitcoin network data and cross-exchange order-book data
**Unit of observation:** exchange-pair × time interval
**Instrument used:** NONE
**Estimated effect size:** ESTIMATED in the reduced-form sense and reported directionally in the abstract — cross-exchange price differences coincide with periods of high settlement latency, asset flows chase arbitrage opportunities, and price differences are smaller across exchanges with low default risk
**Evidence anchor:** Abstract — "We show with Bitcoin network and order book data that cross-exchange price differences coincide with periods of high settlement latency"
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the best *empirical* evidence in the sweep that settlement latency and arbitrage co-move on real data rather than in a model, which is the economic content of the `√Δt` channel. It is co-movement, not a causal design, and it is measured on cross-exchange Bitcoin settlement rather than on an AMM pool, so it supports the mechanism's existence and neither the exclusion restriction nor a magnitude.

### 2.5 Adversarial referee

**Rounds run:** 1 full round, dispatched with six named claims drawn from §2.1–§2.4 and
instructed to demolish them. The referee had the arxiv MCP, web search and fetch, and read
primary LaTeX source for the theory claims. A second round was **not** run — see `**Status:**`
below, which records why that is a limitation and not a conclusion.

**Challenges raised:**

1. **Is `Ḡ` even signed?** From `ℙ = σ_b/(σ_b + √2·φ)` with `σ_b = σ√Δt`, three distinct objects
   scale in opposite directions: arb probability **per block** goes as `Δt^{+1/2}`, arb **count
   per unit time** as `Δt^{−1/2}`, and arb **value per unit time** as `Δt^{+1/2}`. Count and value
   move in **opposite directions in `Δt`**. `S-33` is the value reading, `S-32` the per-block
   reading, and `S-36`'s +535% arbitrage count is the count-per-unit-time reading. All three are
   correct simultaneously. **The first stage's sign therefore depends on a time-base convention
   this project has not fixed**, and `Ḡ` is not well defined until it is.
2. **How does the design survive `S-35` Corollary 5?** The authors state the noise-demand channel
   lowers DEX liquidity **"for any fixed number of informed traders"** — a direct `Δt` → liquidity
   path with the arbitrage channel held fixed. Conditioning on noise or retail volume is
   conditioning on a post-treatment mediator, which induces collider bias rather than restoring
   exclusion.
3. **Why cite `S-33` at all, given that its §7 assumes liquidity providers are passive?** The
   theorem holds *because* LPs do not respond. This project's estimand **is** the LP response. The
   referee's charge is that the paper is being cited as first-stage support while its maintained
   hypothesis is that the estimand is zero.
4. **What is the novelty claim, now that the latency-IV family in §2.4 is on the record?**
5. **What does this add over already-published estimates of the same derivative?** See challenge
   6's evidence.
6. **Is `Ḡ` even monotone?** Hump-shaped optimal liquidity in volatility is claimed in the
   literature, and a tragedy-of-the-commons argument predicts the exit margin is attenuated
   toward zero. A linear or monotone specification is contradicted from two directions at once.
7. **Is the estimation underpowered before it starts?** `S-21`'s minimum detectable effect of
   about 1.03 asinh units is a factor of roughly **2.8x** — only a very large liquidity change was
   detectable, and that was from a sharp DiD on a clean fee change. IV inflates variance by `1/F`,
   with fewer clusters and an attenuated first stage.
8. **If noncompetitive MEV is exactly invariant, what is the first stage in pools with exclusive
   orderflow or batch auctions?** This is the Angstrom regime `DOC:1041` already scopes into.
9. **Which constant governs the calibration?** `S-32`'s abstract and its §4 corollary imply
   per-block LVR constants differing by exactly `1/√2`, leaving the spread-to-fee correspondence
   ambiguous between two values and scaling the first stage by 40%.
10. **How is a linearization error that is monotone in the instrument handled?** The referee's
    arithmetic puts the linearization roughly **+52%** off at Ethereum's 12s with a 5bp fee, and
    near-exact at 250ms — largest exactly where the identifying variation is largest.
11. **How is the multi-channel exclusion violation answered?** The template is Mellon, *American
    Journal of Political Science* 69(3), 2025, 881–898, DOI `10.1111/ajps.12894`, a published
    catalogue of exclusion-restriction violations across a large body of weather-instrument
    studies. **The two counts the referee attached to it are recorded as referee-reported and
    unverified**, and are therefore not quoted here; the venue and DOI were confirmed at the
    two-step review. Block time plausibly affects DEX outcomes through congestion, gas, bundle
    economics and reorg risk simultaneously, which is the multi-channel pattern that catalogue
    targets.
12. **Why discard dispersion?** The dispersion functional enters the per-block LVR *magnitude* at
    leading order and is zero only for a degenerate block-time law.
13. **How many effective clusters, and is Arbitrum admissible at all** given that Orbit-stack
    chains produce no block when there are no transactions?
14. **Why not a within-chain design?** BNB Chain halved its block time twice on known dates in
    2025, giving two sharp mean-`Δt` shocks with chain fixed effects absorbing what cross-chain
    variation cannot.

**Resolution per challenge:**

- **Challenge 1 — ACCEPTED AS A GAP, and promoted.** This is the deepest finding of the sweep and
  it is upstream of everything: it is a **units and time-base question**, and it is therefore the
  same class of defect as inherited item **O4**. Recorded in §5.4 as voiding condition 7. No
  search resolves it; a ruling does.
- **Challenge 2 — ACCEPTED, and it escalates `S-35` from threat to likely-fatal — but its
  LOCATOR WAS WRONG AND IS CORRECTED HERE.** The referee attributed the result to "Corollary 5";
  the two-step review established that **the paper contains exactly one corollary**, so that
  locator was fabricated and is withdrawn. **The substance survives on the verbatim quote**, which
  the review confirmed at source: the noise-demand channel lowers liquidity "for any fixed number
  of informed traders." Two caveats the referee's framing dropped are restored: the paper contains
  **no arbitrage channel at all**, and separability from the informed-trader channel holds only at
  a **fixed number of informed traders**, which is what the quote's own qualifier says. No control repairs it and no second instrument is proposed.
  §5.4 voiding condition 2 already carried this; it is now the leading one.
- **Challenge 3 — ACCEPTED. `S-33`'s block was rewritten as a result.** The passivity assumption
  is decisive and neither §1 nor the first pass of §2 caught it.
- **Challenge 4 — RESOLVED BY SEARCH, against the register.** §2.4's verdict was corrected in
  place and the superseded version left visible.
- **Challenge 5 — PARTIALLY RESOLVED, AND THE REFEREE'S NUMBERS ARE WITHDRAWN.** The referee
  produced two published coefficients as proof that the estimand is already estimated. **The
  two-step review of §Review checked them and both are defective, so neither is relied on here.**
  (i) The Lehar and Parlour figure the referee quoted traces to an **August 2021 preliminary
  draft**, whose authors **superseded it in a January 2022 revision** with a rescaled coefficient
  and a changed specification; the referee attributed it to the 2025 *Journal of Finance* article,
  whose published table is paywalled and **has been verified by no one in this process**. A number
  nobody has read in the version cited cannot discharge anything. (ii) The markout coefficient
  from the published version of `S-16` (DOI `10.1007/978-3-032-00492-5_6`) does verify at
  38,440 observations with pool and day fixed effects and pool-clustered errors — but **log TVL is
  the dependent variable, not the regressor**, and the paper states that column is **mechanically
  the negative of another column by construction** rather than an independent estimate.
  **What survives, and it is weaker than the referee claimed:** work estimating *an adverse-selection
  proxy against a liquidity quantity* on pool panels plainly exists, so §1's finding 4 must not be
  read as "the estimand is unclaimed." But **neither produced number is a verified estimate of
  `∂ν/∂λ_MEV`** — markout is not `λ_MEV` and TVL is not `ν`, which is the very conflation §1's
  `S-02` correctly refused. The narrow surviving claim is unchanged: no published work
  *instruments* arbitrage or MEV intensity with liquidity supply as the second-stage outcome.
- **Challenge 6 — ACCEPTED AS A GAP.** Bears directly on `EST-04`'s logistic form and on
  `Theorem36`'s band reading. Not resolvable by search within this plan.
- **Challenge 7 — ACCEPTED AS A GAP, and routed.** `EST-07` must carry a power calculation
  *before* data collection, benchmarked against `S-21`'s realized minimum detectable effect.
- **Challenges 8, 9, 10, 11, 13 — ACCEPTED AS GAPS**, each routed to a named downstream
  requirement in §2.6 and §5.4 rather than answered here.
- **Challenge 12 — ACCEPTED, and it corrects this register.** §5.3's first draft asserted that
  block-time dispersion is not a source of identifying variation. That is **true of the arbitrage
  *probability* and false of the arbitrage *value***. §5.3 was corrected accordingly, and
  dispersion re-enters the §2.6 menu as candidate 3.
- **Challenge 14 — ACCEPTED, and it adds a menu entry.** Within-chain mean-`Δt` shocks are
  admitted to §2.6 as candidate 2. They were absent from the first draft of the menu, which is
  precisely the kind of omission the adversarial pass exists to catch.

**Referee verdicts on the six claims put to it:** Claim 1 (no prior instrument) **DEMOLISHED**;
Claim 2 (`S-32` corroborates relevance) **WEAKENED**; Claim 3 (`S-33` supports monotonicity)
**DEMOLISHED**; Claim 4 (dispersion useless) **WEAKENED**; Claim 5 (`S-35` is the leading threat)
**UPHELD, and reclassified as fatal rather than as a threat**; Claim 6 (estimand unclaimed)
**DEMOLISHED**.

**What survived the round, recorded because a referee that breaks everything is as useless as one
that breaks nothing:** the algebraic correspondence between the AMM spread and twice the one-way
fee is exact rather than a fudge; `S-32`'s invariance really is shape-at-fixed-mean; the
intra-block volatility really is `σ√Δt`; and `S-33`'s theorem does say what §2.4 says it says.
The problem is not that these are wrong — it is that none of them carries the weight that was
placed on it.

**Status:** NOT CONVERGED — three of six claims were demolished outright, one was upheld only by
being reclassified as fatal, and **eight challenges are recorded as accepted gaps rather than
resolved**. Convergence would require a second round after the units and time-base ruling
(challenge 1) and the `S-35` exclusion question (challenge 2) are answered, and both are rulings
this plan has no authority to make. A `CONVERGED` status here would be a fabrication: the gap
claim this sweep started from did not survive, and the corrected position has not itself been
refereed.

### 2.6 Candidate instrument menu (RAW — not yet ruled on)

Every instrument the sweep surfaced, including `√Δt` itself. **This is a menu, not a selection.**
The rule that selects among these is §5 and nowhere else — nothing here is ranked, preferred or
endorsed, and no dispersion or first-stage number has been measured at the time of writing.

1. **`√Δt`, cross-chain mean inter-block time.** Excluded variable: the chain's mean block
   interval. Exclusion argument: `Δt` does not appear in `φ = φ̄ + volSurcharge(σ)·gate(ν)`
   (`ECONOMETRICS-DESIGN.md` §2). Reported first-stage strength in a prior source: **none exists**
   (§2.4). Structural support: `S-11`, `S-32`, `S-37`. Recorded threats: `S-35`'s direct
   participation channel; the units ambiguity of challenge 1; `S-38`'s zero Ethereum variation.
2. **Within-chain mean-`Δt` step changes.** Excluded variable: a dated protocol change to the
   block interval on a single chain, with chain fixed effects absorbing composition. Exclusion
   argument: the change is set by consensus upgrade rather than by market conditions. Reported
   first-stage strength: none reported; the referee names BNB Chain's two 2025 block-time halvings
   as concrete instances, **unverified at source by this register**. Recorded threat: upgrades
   bundle other changes, exactly as `S-34` found at the Merge.
3. **Block-time dispersion, as a distinct excluded variable from the mean.** Excluded variable: a
   dispersion functional of the inter-block law at fixed mean. Exclusion argument: same as (1).
   Reported first-stage strength: none. Structural support: `S-32`'s dispersion functional enters
   per-block LVR **magnitude** at leading order while leaving arbitrage **incidence** invariant —
   so this candidate is admissible for a value-based hazard and inadmissible for an
   incidence-based one, which is challenge 1's question again. Recorded instance: the Merge is a
   near-pure dispersion shock, confounded by simultaneous proposer-builder-separation adoption.
4. **Chain-infrastructure entry (an L2 launch), as in `S-25`.** Excluded variable: the entry of a
   scaling solution. Exclusion argument: entry lowers gas, which changes LP repositioning, which
   affects the outcome only through repositioning. Reported first-stage strength: **none reported
   as a strength statistic.** `S-25` reports a first-stage *coefficient* of **0.24** on the
   Arbitrum instrument for one pool, which is not an F and carries no standard error here; it must
   not be credited as strength under §5.2's ordering. Recorded threat: the shock moves gas **and**
   cadence together, so it does not isolate `Δt`.
5. **Own lagged base fee, as in `S-22`.** Excluded variable: the wallet's or pool's own lagged
   fee. Exclusion argument: a lagged own fee shifts the fee faced without correlating with
   contemporaneous congestion shocks. Reported first-stage strength: not reported in the source;
   the resulting IV elasticities are **−0.006** (L1) and **−0.036** (L2). Recorded threat: a
   lagged own outcome is a weak exclusion under serial correlation, and it is the "secondary
   defence" `ECONOMETRICS-DESIGN.md` §2 already classes as second-line.
6. **Realized-volatility and calendar shocks, as in `S-39`.** Excluded variable: volatility-proxy
   jumps and calendar effects. Exclusion argument: as given in that source. Reported first-stage
   strength: **F = 4.14**, a failure, below both the conventional threshold of 10 and `S-27`'s
   104.7. Recorded additionally: `S-25` uses realized volatility as a **control**, not an
   instrument.
7. **Latency and speed shocks from the traditional-market family** named in §2.4 — exchange
   latency upgrades, co-location introductions, microwave-network counts, installed algorithmic
   capacity. Excluded variables as in those sources. Reported first-stage strength: a minimum
   first-stage **F = 39** in Rzayev, Ibikunle and Steffen (2023). Recorded status: these are the
   template family rather than instruments available on-chain, and no on-chain analogue of a
   co-location shock has been identified.

### 2.7 Sweep boundary

**Date:** 2026-08-09.

**Query set.** Four arXiv dimensions were swept by dedicated agents — empirical AMM/LVR studies
(11 arXiv queries plus 3 web); fee-versus-flow elasticity (9 arXiv queries plus 6 web, **2
planned queries unexecuted** owing to rate limiting); pool-level panels and few-cluster and
weak-instrument methods (15 arXiv queries plus 4 web); and block-time and realized-volatility
instruments (13 arXiv queries plus 18 web). The orchestrator ran a further 6 arXiv searches and
resolved 26 identifiers directly. The adversarial referee of §2.5 ran an additional
SSRN/NBER/RePEc/journal sweep that the four dimensions structurally could not, and it is the
reason §2.4's verdict was corrected.

**Stated limitations, because a boundary that hides its own holes is not a boundary.** This was an
**arXiv-centred** sweep of a literature that is not principally on arXiv, and the referee
demonstrated the cost of that concretely. Two fee-elasticity queries never ran. Roughly a dozen
identifiers surfaced by the fee-elasticity agent were left unverified and excluded. Four of the
referee's own citations are flagged unverified in its report and are **not** relied on anywhere in
this register. No Dune source could be retrieved (§3.2).

The menu in §2.6 is closed as of this date. Additions after EST-03 returns are a protocol
violation recorded in §6.

## 3. Class C — non-arXiv on-chain material (LIT-03)

**LOWER-RIGOR AS A CLASS.** Everything in §3 may motivate a specification and may screen
candidate chains. It may **never** be the sole justification for a specification, and it may
**never supply the reported dispersion number** — dispersion is a measurement, made by `EST-02`
on window A, not a motivation. Where §3 conflicts with §1 or §2, the peer-reviewed source
governs and the conflict is recorded in §4.

### 3.0 A distinction the requirement does not draw, recorded rather than assumed

`LIT-03` defines Class C as "on-chain empirical literature outside arXiv" and tags it
lower-rigor. The sweep surfaced a second, entirely different population of non-arXiv sources:
**canonical peer-reviewed econometrics references that simply are not on arXiv.** §2.3's search
established that Montiel Olea and Pflueger's effective-F paper, Cameron–Gelbach–Miller,
Stock–Yogo, Bertrand–Duflo–Mullainathan, Donald–Lang, Ibragimov–Müller and Callaway–Sant'Anna
have **no arXiv version**, while Abadie–Athey–Imbens–Wooldridge (`S-28`) and
Lee–McCrary–Moreira–Porter (`S-27`) do.

**These are not Class C and the lower-rigor tag does not apply to them.** Absence from a preprint
server is not a rigour property. They are peer-reviewed journal articles that this project must
cite from the journal of record, and `EST-07` may rest on them exactly as it would rest on §2.
Recorded here because a register that silently swept them into the lower-rigor class would have
made `EST-07`'s thresholds uncitable, and because the requirement as written does not anticipate
the case. The venue of record for each is named where it is used, and `S-31` is the arXiv-citable
generalization standing in for Montiel Olea–Pflueger.

### 3.1 The sources

**Retrieval was hand-run, not routed through `lit-review`**, per `06B-CONTEXT.md`. A sub-agent
searched fourteen query strings across the venues named in §3.3, using web search and fetch only;
the arxiv MCP was deliberately withheld from it. Only sources actually retrieved and read are
recorded below.

### S-41 — protocol documentation
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://docs.arbitrum.io/build-decentralized-apps/arbitrum-vs-ethereum/block-numbers-and-time
**Identification strategy:** NONE — DESCRIPTIVE (normative protocol specification, not measurement)
**Data source:** NONE — describes sequencer block-production rules
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — no estimates of any kind. The load-bearing content is a mechanism statement: Arbitrum block production is **event-driven, not clocked**, occurring only when there are transactions to sequence, and block timestamps come from the sequencer's own clock rather than from the parent chain.
**Evidence anchor:** Section on block timestamps — "Block timestamps on Arbitrum are not linked to the timestamp of the parent chain block. They are updated every child chain block based on the sequencer's clock."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the single most decision-relevant Class C source, and it is a screening input rather than evidence. It establishes *a priori* that Arbitrum's `Δt` is **endogenous to transaction arrival**, hence mechanically correlated with volume and volatility — the two quantities that drive the second-stage error. For the fastest-block candidate chain, the exclusion restriction is therefore threatened at the level of protocol design, before any measurement. This is a chain-screening finding and supplies no dispersion number.

**A source deliberately NOT given a block, and why.** The chain-comparison dashboard at
`https://chainspect.app/dashboard` was retrieved and reports one-hour mean block times of
Ethereum 12.04s, Arbitrum 251ms, Base 2s, Optimism 2s, Polygon 1.5s, Avalanche 1.1s, BNB Chain
451ms and Solana 425ms. **It is recorded here as an attributed claim rather than as a numbered
source, because it is a bare data table carrying no prose from which a locating verbatim quote
could honestly be taken**, and this register requires an evidence anchor on every source block.
The figures are one-hour means with no variance, no distribution and no published methodology, so
under the standing rule they could not have supplied a dispersion number in any case. They are
usable only as a coarse ordering of nominal cadence for screening.

### S-42 — infrastructure-provider documentation
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://docs.chainstack.com/docs/solana-understanding-block-time
**Identification strategy:** NONE — DESCRIPTIVE
**Data source:** Solana mainnet, with a worked example from Epoch 763, 27–29 March 2025, covering 233,011 slots
**Unit of observation:** slot
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT in the estimation sense — the page reports *protocol bounds* rather than a measured distribution: a nominal 400ms slot with drift caps implying roughly a 0.3s floor and a 1.0s ceiling. Skipped slots are acknowledged but not quantified.
**Evidence anchor:** Section on timestamp drift — "Solana caps timestamp drift (up to 25% fast and 150% slow) from expected progression to safeguard against manipulation."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the only source in the class that constrains the *support* of `Δt` on a chain, which bounds where dispersion could live without measuring it. It also flags a measurement trap `06B-02` must respect: on Solana the slot index and the block index diverge because of skipped slots, so a `Δt` series must be built from block timestamps rather than slot deltas.

### S-43 — protocol blog
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://blog.base.dev/accelerating-base-with-flashblocks
**Identification strategy:** NONE — DESCRIPTIVE (product announcement)
**Data source:** NONE — engineering description only
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — no effect estimates. Two structural facts: canonical Base blocks remain 2s, with 200ms preconfirmation sub-blocks layered above them.
**Evidence anchor:** Section on the Flashblocks mechanism — "Flashblocks are sub-blocks issued by the block builder and streamed to nodes every 200ms, allowing for early confirmation times."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — recorded as a **definitional hazard** rather than as evidence. On Base and any OP-Stack chain running the same sidecar there are now two distinct quantities both called block time, 2s canonical and 200ms preconfirmation, and the 2025 activation is a **structural break** in any `Δt` series spanning it. `06B-02` must state which quantity it measures. The post makes no MEV, arbitrage or LP-loss claim.

### S-44 — protocol research forum
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://research.arbitrum.io/t/the-power-of-faster-blocks/9609
**Identification strategy:** NONE — DESCRIPTIVE, and specifically a theoretical extrapolation: a published `√Δt` formula applied to two block-time values, with no estimation performed
**Data source:** NONE of its own — cites a Uniswap Labs paper and the Milionis et al. LVR-with-fees model
**Unit of observation:** NONE — parameter plug-in
**Instrument used:** NONE
**Estimated effect size:** a single derived number with no interval and no data behind it — a claimed 65% lower arbitrage loss at 250ms versus 2s block times, asserted as an arithmetic consequence of `√Δt` scaling
**Evidence anchor:** Section containing the reply from a discussion participant contesting the claim — "The decrease in LVR varies quite a bit between trading pair, and is generally slower than the theoretical formula by Milionis et al. predicts."
**Transfer verdict:** DOES NOT TRANSFER — the number is an arithmetic consequence of assuming the very scaling law under test, published by the chain whose block time it flatters, and it is contested in its own comment thread by a participant citing measurement. It is recorded because it is the clearest specimen of the practitioner prior this project intends to *test* rather than inherit, and because §4 logs it as conflicting with §1's peer-reviewed invariance result.

### S-45 — protocol specification
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://eips.ethereum.org/EIPS/eip-7782
**Identification strategy:** NONE — DESCRIPTIVE (rationale advocacy)
**Data source:** NONE — no empirical work is presented
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — directional assertions with no quantities and no errors, proposing a slot reduction from 12s to 6s and listing reduced MEV among the benefits
**Evidence anchor:** Section on motivation and rationale — "More frequent blocks decrease LVR (Loss Versus Rebalancing), which improves the economics for liquidity providers."
**Transfer verdict:** DOES NOT TRANSFER as evidence — an unsourced directional claim in an advocacy document, logged in §4 as conflicting with `S-33`. It transfers as **context** with a real consequence: if this proposal ships, Ethereum's 12s slot becomes a structural break, and `S-38`'s finding that post-Merge Ethereum block time is constant acquires an expiry date that `EST-09`'s window selection must respect.

### S-46 — research forum
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://ethresear.ch/t/cex-dex-arbitrage-transaction-fees-block-times-and-lp-profits/19444
**Identification strategy:** NONE — DESCRIPTIVE, and explicitly a **simulation** in which block time is varied as an exogenous parameter; no causal design and no quasi-experiment
**Data source:** simulated, calibrated to the Uniswap v3 ETH/USDC 0.05% pool as of April 2024 at 50% annualised volatility, with scenarios at 12s and 8s
**Unit of observation:** simulated arbitrage trade, aggregated to USD per hour and annualised
**Instrument used:** NONE
**Estimated effect size:** MODEL-COMPUTED with no standard errors. The useful content is the *direction of departure* from theory: shortening block time reduces LP losses by materially **less** than `√Δt` predicts once gas costs enter, because a rising share of nominal LVR is absorbed by transaction fees.
**Evidence anchor:** Section on block times and fees — "LP losses from arbitrage trades do not have the same magnitude as the profits of the arbitrager (searcher-builder-proposer), and as such, are not accurately predicted by a model that approximates them with the square root of the block time."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the closest practitioner work to treating block time as an exogenous lever, and it is simulation rather than identification. Its value is the three-way split of nominal LVR between LPs, stakers and the searcher-builder-proposer: **what an LP loses is not what an arbitrageur gains**, so a specification must state which component `Δt` is supposed to move. That distinction bears directly on whether `ν` responds to the same object `λ_ARB` accumulates. It supplies no dispersion number and supports no causal claim.

### S-47 — research collective writings
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://writings.flashbots.net/mev-and-the-limits-of-scaling
**Identification strategy:** NONE — DESCRIPTIVE, via transaction-trace classification with a custom tool; no design and no counterfactual
**Data source:** OP-Stack rollups — Base, OP Mainnet, Unichain — with reference to Solana; primary window November 2024 to February 2025
**Unit of observation:** transaction, aggregated to gas share and fee share per rollup
**Instrument used:** NONE
**Estimated effect size:** descriptive shares without standard errors — spam consuming a majority of gas while paying a small minority of fees, and a roughly 350:1 ratio of failed to successful arbitrage attempts. Classification is heuristic and shares are unstable across rollups and windows.
**Evidence anchor:** Section on spam measurement — "Spam bots across multiple rollups are consuming more than 50% of gas and paying less than 10% of fees."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — the most decision-relevant measurement in the class after `S-41`, and the one that bears most directly on this project's theory. It is measurement rather than simulation, on exactly the sub-second L2s under consideration, and it documents that on fast chains the binding phenomenon is a **concentrated, non-competitive latency race** rather than the elimination of extraction. That is the competitive-component-only prediction of `S-33` observed in the wild, and it cuts against the naive practitioner claim in `S-44` and `S-45`. Magnitudes are indicative only.

### S-48 — infrastructure-provider research note
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://www.helius.dev/blog/solana-mev-report
**Identification strategy:** NONE — DESCRIPTIVE; MEV is attributed by proprietary algorithmic pattern detection, not by any econometric design
**Data source:** Solana mainnet-beta, calendar 2024 with some series into January 2025, aggregating bundle data and on-chain traces
**Unit of observation:** transaction and bundle, aggregated daily and by validator
**Instrument used:** NONE
**Estimated effect size:** large descriptive counts with **no standard errors and no confidence intervals** — 90,445,905 detected arbitrage transactions over one year at a mean profit of 1.58 USD, and reverted transactions peaking at 75.7% of non-vote transactions in April 2024
**Evidence anchor:** Section on arbitrage — "Jito's arbitrage detection algorithm identified 90,445,905 successful arbitrage transactions over the past year. The average profit per arbitrage was $1.58, with the most profitable single arbitrage yielding $3.7 million."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — genuine measured MEV on real pools on the one candidate chain with a genuinely variable and bounded `Δt` (`S-42`), and the per-event magnitude is a useful order-of-magnitude sanity check on any modelled MEV rent. Every figure depends on an unpublished proprietary classifier with no reported false-positive or false-negative rate, and the publisher has a commercial interest in the totals. It can bound plausibility; it cannot anchor a specification.

### S-49 — vendor documentation
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://docs.algebra.finance/algebra-integral-documentation/overview-faq/algebra-integral
**Identification strategy:** NONE — DESCRIPTIVE (vendor material)
**Data source:** NONE — self-reported integration counts and architectural description
**Unit of observation:** NONE
**Instrument used:** NONE
**Estimated effect size:** NO EMPIRICAL CONTENT — self-reported and unaudited adoption counts of 100+ integrated DEXes across 50+ EVM chains, with named hosts including Camelot, THENA, QuickSwap and StellaSwap. No per-chain pool counts are published.
**Evidence anchor:** Section on the fee mechanism — "information from TWAP-oracle about price changes, the Plugin calculates the fee based on the volatility of the pair."
**Transfer verdict:** TRANSFERS WITH MODIFICATION — adequate for **candidate-venue screening only**, which is the question `LIT-04` asks of it: it establishes that the Algebra Integral codebase is deployed broadly enough that chain choice is not constrained to a single venue. It is vendor self-report and must be reproduced from on-chain factory deployments before use. **One material gap for `06B-01`:** the AdaptiveFee technical page documenting the sigmoid parameterisation returned HTTP 404 at its documented URL, so the parameter block this project ports must be read from the contracts rather than the documentation.

### S-50 — vendor blog
**Class:** NON-ARXIV (LOWER-RIGOR)
**URL:** https://medium.com/@crypto_algebra/celebrating-algebras-impact-on-thena-s-success-fc7858a4fa98
**Identification strategy:** NONE — DESCRIPTIVE; a before-and-after comparison of two coexisting products with no counterfactual and no controls
**Data source:** THENA on BNB Chain, cumulative figures from April 2023 to November 2024
**Unit of observation:** product-level cumulative totals
**Instrument used:** NONE
**Estimated effect size:** raw ratios with no standard errors and no controls — cumulative volume of 15bn USD against 2.7bn, and cumulative fees of 13.25m USD against 1.35m
**Evidence anchor:** Section containing the comparison tables — "THENA FUSION's cumulative trading fees is 10x higher than V1's" is presented without controls, without a common time window per pool, and without any counterfactual.
**Transfer verdict:** DOES NOT TRANSFER — the closest thing found to a published before-and-after on a live dynamic-fee deployment, and badly confounded: it compares two coexisting products, bundling concentrated liquidity, dynamic fees and a new incentive programme into one ratio, so the headline efficiency gain is largely a mechanical consequence of concentrated liquidity rather than of the dynamic fee. Recorded as a pointer to a venue worth measuring properly, never as a fee-versus-volume estimate.

### 3.2 What Class C did and did not answer

1. **No Class C source measures block-time dispersion.** Every figure retrieved is a nominal
   protocol target or a single-window mean. The standing rule above is therefore not merely a
   precaution in this sweep — it is the factual situation, and `EST-02` has no practitioner
   number to be anchored by even if the rule permitted it.
2. **Chain screening, as claims rather than measurements.** Ethereum's 12s is a genuine protocol
   constant, on `S-38`'s peer-reviewed measurement rather than on any Class C source; Arbitrum is
   nominally 250ms but **event-driven and therefore endogenous** (`S-41`); Base and Optimism are
   2s with a preconfirmation ambiguity and a structural break (`S-43`); Solana is nominally 400ms
   with a protocol-bounded support and a slot-versus-block measurement trap (`S-42`). **On the
   screening question that matters most, the two fastest candidate chains are the two most
   compromised**: Arbitrum's cadence is endogenous by construction, and Base's is ambiguous and
   broken mid-series. That is a Class C finding about *venue admissibility*, not a dispersion
   measurement, and `LIT-04` inherits it.
3. **Live dynamic-fee experiments with usable before-and-after data: effectively a null.** The
   one candidate (`S-50`) is confounded beyond use, and the flagship Uniswap v4 dynamic-fee
   deployment published no data at all. This is a null on the question `06B-CONTEXT.md` deferred
   under Decision #14, and it is recorded to show the decision cost little.
4. **No practitioner work uses block time as an instrument or exploits a cadence change as a
   quasi-experiment** — consistent with §2.4's verdict from a wholly separate source population.
5. **No Dune source could be retrieved.** Three attempted Dune URLs returned HTTP 500, 500 and
   404; Dune renders client-side and was not reachable by fetch. **No Dune content is quoted
   anywhere in this register.** Since `06B-CONTEXT.md` names Dune MCP as the primary data route,
   this is recorded as a gap in the *literature* sweep only, and it is not evidence about the
   data route's availability — the Dune MCP server was not exercised by this task.

### 3.3 Search record

Fourteen query strings were run on 2026-08-09 via web search, with page retrieval by fetch:
Algebra Integral dynamic fee deployments across chains; Arbitrum 250ms block times and Timeboost
block-time variation; Dune Analytics dashboards for LVR on Uniswap pools; ethresear.ch on shorter
block times and MEV/LVR; Algebra Integral adaptive-fee plugin documentation; Base Flashblocks and
Optimism 2-second blocks; Dune dashboards for Algebra dynamic-fee DEX volume; Dune blog on
measured MEV and sandwiching; Solana slot-time variance and skipped slots; Ethereum missed-slot
statistics and the actual 12-second distribution; Uniswap v4 dynamic-fee hook live before-and-after
results; Dune blog on AMM fee-versus-volume relationships; Flashbots and Paradigm research on
block-time reduction and MEV; and block time as an instrumental variable or natural experiment in
DeFi.

Venues searched: Dune Analytics dashboards and blog, Algebra Finance documentation and plugin
marketplace and Medium, Arbitrum documentation and research forum, the Base and Coinbase blog,
Optimism, Chainstack documentation, Chainspect, Ethereum Research, the Ethereum EIP repository,
Flashbots Writings, Arrakis Finance, Helius, Uniswap documentation and blog, and Camelot
documentation.

**Retrieval failures, recorded rather than quoted:** three Dune URLs (HTTP 500, HTTP 500, HTTP
404); the Algebra AdaptiveFee technical reference (HTTP 404); and one slot-timing analysis whose
content had been replaced by a service-sunset notice, which was therefore dropped rather than
cited. A New York Fed staff report describing a DeFi instrumental-variable design returned HTTP
403 to fetch and is **not** recorded as a source anywhere in this register, because its
instrument description could not be verified at source.

**Dynamic-fee natural experiments are EXCLUDED by user decision (Decision #14, 2026-08-09).**
Algebra `AdaptiveFee` rollouts and Uniswap fee-tier migrations were offered as a fourth source
class and declined. Reopening this is a **scope change**, not a research decision.

## 4. Conflict log

Where a §3 source asserts something a peer-reviewed source contradicts, **the peer-reviewed
source governs.** The log also records two tensions *internal* to the peer-reviewed material,
because the sweep's cross-check between §1 and §2 surfaced them and burying them would defeat the
purpose of having run it.

| # | Claim | Class C source | Governing source (§1/§2) | Resolution |
|---|---|---|---|---|
| 1 | More frequent blocks decrease LVR and reduce MEV | `S-45` (EIP-7782, advocacy) | `S-33` / `S-08` (Guo) | **Peer-reviewed governs.** Frictionless MEV is invariant to block subdivision; with fees only the *competitive* component moves, weakly. The EIP asserts an unqualified reduction with no data, no model and no citation. **Not citable in support of a `Δt` → MEV mechanism.** |
| 2 | 250ms blocks give 65% lower arbitrage loss than 2s | `S-44` (Arbitrum Research) | `S-32` (Nezlobin–Tassy), `S-15` (Fritsch–Canidio) | **Peer-reviewed governs.** The 65% is an arithmetic consequence of assuming the very `√Δt` law under test, published by the chain it flatters, and contested in its own comment thread. `S-15` gives a **20–70% range that is strongly pair-dependent**, and is itself simulated. **The two are NOT the same quantity and must not be compared as though they were**: `S-44` contrasts 250ms with 2s, `S-15` contrasts 100ms with 12s — different comparisons over different ranges. **Neither is citable as a magnitude.** |
| 3 | Dynamic fees produced a 10x fee increase and a 28x efficiency gain | `S-50` (Algebra/THENA vendor blog) | `S-21` (`arXiv:2607.08525`) | **Peer-reviewed governs.** The vendor comparison is cross-product and confounds concentrated liquidity, dynamic fees and an incentive programme. The one pre-specified causal design on a fee change reports a **non-detection**. **Not citable as a fee-versus-liquidity effect.** |
| 4 | Chain "block time" as a single reported number | Chainspect (attributed claim, §3.1) | `S-38` (Kapengut–Mizrach), `S-41` (Arbitrum docs) | **Peer-reviewed and protocol-normative govern.** A one-hour mean conceals the variation at issue; post-Merge Ethereum is a *constant*, and Arbitrum's cadence is *event-driven*. **No Class C source may supply the dispersion number**, per §3's standing rule. |
| 5 | Faster chains eliminate extraction | `S-44`, `S-45` | `S-47` (Flashbots, measurement) | **The practitioner corpus refutes itself, and the peer-reviewed reading wins.** On sub-second L2s, extraction persists as a concentrated, non-competitive latency race. This is `S-33`'s competitive-component-only prediction observed in the wild, and it is recorded because the counter-evidence comes from *within* Class C. |

**Internal tensions in the peer-reviewed material — recorded, not resolved by fiat.**

| # | Tension | Sources | Resolution |
|---|---|---|---|
| 6 | Is Guo adverse to the `Δt` instrument or supportive of it? | §1 `S-08` versus the §2.4 reading in `S-33` | **SUPERSEDED — the synthesis below was itself overturned, and the final position is `S-33`'s.** Both original readings are consistent with the theorem (§1: an inequality with **no lower bound on magnitude**; §2.4: with fees the sign is **established**, invariance confined to the frictionless case), so the first synthesis was that Guo is a relevance-*sign* result and not a relevance-*strength* result. **§2.5's referee then demolished the use of the paper altogether:** its §7 discussion states the analysis takes liquidity providers to be **passive**, which is precisely this project's estimand set to zero, and the noncompetitive component is exactly invariant. `S-33` therefore now reads **DOES NOT TRANSFER as support for the instrument** and is retained only as a constraint. **`S-08` in §1 still carries the pre-reversal TRANSFERS verdict and is corrected by a banner on that block**; §1.15's tally is stale by one and is annotated there. |
| 7 | Does §1's reading of `CapponiCarteaDrissiDiscreteClearing` survive an identification-focused re-read? | §1 `S-01` versus §2 `S-35` (same paper, arXiv twin) | **`S-01` is incomplete rather than wrong.** It recorded the paper as motivating a sign prior for the first stage. Re-read for *identification*, the same model supplies a **direct path from `Δt` to participation and adverse selection that bypasses the fee schedule** — an exclusion-restriction threat `S-01` did not name. `S-35` carries it, and §5.4 makes it a voiding condition. |
| 8 | Does §1's extraction of `CapponiZhuTimeboost` match the source? | §1 `S-05` versus §2 `S-26` (same paper, arXiv twin) | **Cross-check PASSED.** Independently re-extracted coefficients, standard errors, observation count and cluster count agree exactly (−0.699/0.281, +0.726/0.123, 605 observations, 5 groups, HC3 fallback). This is the only direct audit available of Task 1's accuracy, and Task 1 passed it. |
| 9 | **§1's finding 4 — "no paper in Class A estimates `∂ν/∂λ_MEV` or any close analogue" — generalized into a claim about the literature.** | §1 §1.16 item 4 versus §2.5 challenge 5 | **CORRECTED, against this register.** As a statement about *Class A* the finding stands. As the basis for treating the estimand as unclaimed it is **false**, and §2.6's first draft rested on it. Two published estimates of the derivative exist with coefficients, standard errors and sample sizes: a markout coefficient of **+0.169 (s.e. 0.019)** on log TVL over 38,440 pool-days, pool and day fixed effects, pool-clustered errors, in the published version of `S-16` (DOI `10.1007/978-3-032-00492-5_6`); and a pool-size-on-volatility coefficient of **−14,646,278 (s.e. 1,907,119)** over 263,750 pool-days in Lehar and Parlour, *Journal of Finance* 80(1), 321–374, DOI `10.1111/jofi.13405`. A traditional-market twin predates both by decades (Kavajecz, *Journal of Finance* 54(2), 747–771). **What survives is narrower and is the only novelty claim this register supports:** no published work *instruments* arbitrage or MEV intensity with liquidity supply as the second-stage outcome. |
| 10 | Is the `√Δt` identification idea novel? | §2.4's original verdict versus §2.5 challenge 4 | **CORRECTED, against this register.** Instrumenting a market outcome with an exogenous shock to execution speed is an established peer-reviewed design roughly fifteen years old, and `S-25` is its DeFi-native member citing Hendershott, Jones and Menkveld as template. The surviving claim is narrow: **inter-block time specifically has not been used as the excluded instrument.** §2.4 carries the corrected verdict and the superseded one. |

**Class C claims checked against §1/§2 findings, with no conflict found:** `S-41`'s event-driven
block production (no peer-reviewed source contradicts it; it is a protocol specification);
`S-42`'s Solana drift bounds (no peer-reviewed source addresses them); `S-43`'s Flashblocks
two-tier cadence (no peer-reviewed source addresses it); `S-46`'s finding that gas costs make LP
loss fall by **less** than `√Δt` predicts (consistent with, not contradicted by, `S-15`'s
pair-dependent range and `S-32`'s fee-dependence); `S-48`'s Solana MEV totals (no peer-reviewed
counterpart exists to contradict); `S-49`'s Algebra deployment breadth (no peer-reviewed
counterpart). An empty conflict finding for these six is a **checked** result, not an unchecked
one.

## 5. Instrument-selection rule

**Written:** 2026-08-09. **No dispersion has been measured at the time of writing.**
`EST-02` measures dispersion on window A; `06B-01` pre-declares the candidate set. Both are
downstream of this section by construction, and the git history records the order. At the moment
these words are committed, this project has measured **no** `Δt` series, **no** first stage and
**no** dispersion statistic on any chain, and no such measurement exists anywhere in this
repository.

**This section was rewritten once, before its first commit, in response to the two-step review of
§Review.** The specialist reviewer returned six blockers, all of them in §4 and §5, and the
central one was that the first draft's rule **did not select the instrument the first draft then
selected**. That draft is not preserved here, because it was never committed and therefore never
relied on; what is preserved is the correction, and §Review records the finding that forced it.

**5.0 Bottom line, stated in one place because a conclusion distributed across ten numbered
conditions is a conclusion hidden.** **On the evidence assembled in §1–§4, no member of the closed
§2.6 menu has been shown admissible under §5.2.** The primary candidate `√Δt` **fails clause
5.2(b)** on `S-35`'s direct participation channel; menu candidates 2 and 3 share the same excluded
variable and therefore inherit the same failure; candidate 4 is inadmissible against this plant on
(d); candidate 6 failed in its own source; candidates 5 and 7 are not `Δt` instruments and have not
been run through 5.2 here. Three voiding conditions are **live or near-live** — condition 2 is
already true, condition 5 is close to it, and condition 7 (the undefined time base) blocks
admission under 5.2(d) for *every* candidate until a ruling this register cannot make. §5.6's own
benchmark says that even if an override were exercised, the achievable precision is unlikely to
separate an effect of the magnitude at stake.

**What follows, stated plainly:** the phase **cannot proceed to estimation as currently designed**.
The only permitted route is §5.2.1's override, which reports a **set, not a point**, and §5.7
records that no procedure for that route is yet pre-committed. The alternative permitted by §5.1 is
**terminal non-identification** — a delivered result on the `υ` precedent, not a failure. Which of
the two applies is decided by the rulings named in conditions 2 and 7, and **not** by anything this
register may measure.

**5.1 The menu is closed, and the closure has a cost that must be stated.** The admissible
instrument set is exactly §2.6's numbered menu. Nothing may be added later. **If no member of the
closed menu identifies `Ḡ`, that is terminal non-identification** — the `υ` precedent — and
**no instrument substitution is permitted**, before or after any measurement.

**The cost, stated because the first draft presented this closure as free and it is not.** With
one excluded instrument, the order condition is satisfied for a **single** linear endogenous
regressor and is **not** satisfied for `ECONOMETRICS-DESIGN.md` §3's Stage 2, which estimates
four parameters `(a, b, c, d)` in `ν = a + b·σ_ℓ(c(λ − d))` by nonlinear IV/GMM. A constant plus
one instrument gives **two** moment conditions for **four** parameters. The standard remedy is to
expand the instrument basis in the excluded variable, and §5.1 as written **forbids exactly
that**. Therefore:

- **This register's §5 guarantee is scoped to Stage 1, the sign test**, which has one endogenous
  regressor and one instrument and is exactly identified.
- **Stage 2 is not identified under the closed menu as written.** Any functional basis in the
  excluded variable that Stage 2 would require — powers, interactions, splines — must be
  **pre-authorised by name before any data is touched**, or Stage 2 is out of scope for this
  register and `EST-04` must record that its estimation cannot proceed under §5.1. Pre-authorising
  a basis *after* `EST-03` returns is a §5.5 violation.

**5.2 The rule that selects among the menu.** A menu member is **admissible** only if it satisfies
all four of the following. Each is decidable from information on this register or from a document
that exists now, and none refers to any realized first-stage, dispersion or outcome statistic.

- **(a) Exogeneity by construction.** The excluded variable is set by protocol or consensus rule,
  not realized as a market outcome, and **not mechanically a function of the activity being
  explained**. This is what distinguishes the proposal from `S-39`'s failed volatility-proxy
  instrument, and it is what disqualifies Arbitrum outright (`S-41`: blocks are produced only when
  there are transactions to sequence).
- **(b) No standing refutation.** Its exclusion argument is not refuted by any §1 or §2 source.
  **This clause is binary and admits no "subject to" qualifier.** A candidate against which a
  §1/§2 source supplies a direct outcome path bypassing `φ` **fails (b)**. If the project wishes
  to proceed against a failed (b), that is an **override**, and an override is governed by 5.2.1
  below — it is never a pass.
- **(c) Availability, as a screening presumption pending one named check.** The excluded variable
  is observable, on a documented read path, on at least `G_min` candidate chains carrying an
  Algebra Integral deployment. **The evidence currently available for this clause is `S-49`, which
  is vendor self-report that this register's own transfer verdict says "must be reproduced from
  on-chain factory deployments before use."** Clause (c) is therefore discharged only as a
  *presumption*; the on-chain factory enumeration is a **named precondition** on `LIT-04` and must
  be run before any selection is acted on. Recorded explicitly because a clause dischargeable only
  by a measurement is not fully ex ante, and the first draft claimed it was.
- **(d) Structural derivation.** A derivation links the excluded variable to `λ_ARB` inside this
  project's own plant, rather than by analogy.

**`G_min` is fixed here at a cluster count, not a chain count, and the distinction is the point.**
The first draft set the floor at "at least two chains," reasoning that two is the minimum at which
a between-chain contrast exists. That is arithmetically true and inferentially useless: two chains
is **two clusters**, and no procedure on this register delivers valid inference there. Worse,
`S-30`'s Wald result requires the parameter to be strongly identified **in at least one cluster**,
and a chain-level instrument has **zero within-cluster variation by construction**, so no cluster
is ever strongly identified and only the Anderson–Rubin variant survives. The binding authority
for a regressor that varies only at the group level is **Donald and Lang (2007)** — non-arXiv, and
per §3.0 not lower-rigor — which gives a group-level two-step with `t` on `G − 2` degrees of
freedom. **`G_min` is therefore set to the smallest `G` at which the pre-committed inference
procedure of §5.6 has any power against the alternative, and that number must be stated by
`EST-07` before window A is opened.** It is not set here because setting it requires the power
calculation §5.6 mandates, and this register will not invent a number it has not computed.

**Ordering among admissible members** is by the class of supporting evidence, **strongest first**:
peer-reviewed and identified, then peer-reviewed theory, then simulation or calibration, then
practitioner material. Class C may never raise a candidate's rank above a peer-reviewed one.

**Tie-break, corrected.** The first draft broke ties by counting documented direct paths from the
excluded variable to the outcome that bypass `φ`, preferring the candidate with fewer. The
reviewer's objection is decisive and is adopted: a count over a corpus **rewards the
least-researched candidate**, and §2.7 concedes this corpus is unevenly searched. The tie-break is
therefore replaced: ties are broken by **the number of bypass mechanisms admitted by the plant's
own structure**, which is a property of the model rather than of how hard anyone looked. Where two
candidates still tie, they are carried forward jointly and `EST-07` states which is estimated
first, before data.

**5.2.1 Override of a failed (b), and its price.** Proceeding on a candidate that fails (b) is
permitted **only** if all of the following are recorded before window A opens: the specific
bypass path and its source; the sign of the resulting bias where the source implies one; a
pre-committed **partial-identification** treatment (bounds under a bounded violation, e.g. the
plausibly-exogenous or imperfect-IV families) rather than a point estimate; and an explicit
statement that the reported object is a **set, not a point**. An override that yields a point
estimate reported as if exclusion held is a §6 violation.

**5.3 The primary instrument under 5.2, and its true status.** The primary instrument is **`√Δt`,
the square root of the *mean* inter-block time, varying across chains** — the transform the hazard
carries, not raw `Δt`. `ECONOMETRICS-DESIGN.md` §2 proposed it and **the sweep did not displace
it**.

**But it does not currently pass 5.2, and the register says so rather than asserting otherwise.**

- It satisfies **(a)** by protocol construction on chains whose cadence is clocked — and **fails
  (a) on Arbitrum**, which is therefore inadmissible as a venue rather than merely risky.
- It **FAILS (b) as of this writing.** `S-35` supplies a direct path from `Δt` to participation,
  price discovery and adverse selection that does not run through `φ`, with the authors stating
  the channel operates "for any fixed number of informed traders." §2.5 upheld this and
  reclassified it from threat to fatal. The first draft wrote that `√Δt` satisfies (b) "subject to
  the live threat" — which is an override wearing a pass's clothing, and it is withdrawn.
  **Proceeding therefore requires 5.2.1's override, with bounds rather than a point estimate.**
- It satisfies **(c)** only as the presumption described above.
- It satisfies **(d)** via `S-11`, `S-32` and `S-37` — **and so do menu candidates 2 and 3**, which
  share the same excluded variable and therefore the same derivation. The first draft's claim that
  no alternative satisfies (d) was false and is withdrawn.

**On evidence class, `√Δt` does not rank first, and this is recorded against the project's own
preference.** Candidate 1's reported prior first-stage strength is, per §2.6, **none exists**, and
its support is peer-reviewed *theory*. Menu candidate 4 (`S-25`, chain-infrastructure entry) sits
inside a published, identified 2SLS design with a reported first stage. Under 5.2's own ordering,
**candidate 4 outranks candidate 1.** It is not adopted here — its shock moves gas and cadence
together and so does not isolate `Δt`, which is a (d)-relevant defect against *this* plant — but
the ordering is recorded honestly, and `LIT-04` inherits the question of whether the project's
preferred instrument is the one its own rule selects.

**Supersession recorded.** `ECONOMETRICS-DESIGN.md` §2 is **not** superseded on the choice of
instrument. The phase's *operationalization* is under-determined: `S-32` makes the shape of the
inter-block law first-order irrelevant for arbitrage **incidence** at fixed mean, while its
dispersion functional enters per-block LVR **magnitude** at leading order. Which moment carries
the identifying variation therefore depends on the ruling demanded by voiding condition 7.
`06B-01` and `06B-02` are specified around measuring **dispersion** as though that were settled;
they must state which moment they measure, and why, before they measure anything.

**5.4 What would void this rule.** Any one of the following voids it, and each is checkable:

1. The excluded variable is unavailable on fewer than `G_min` admissible chains.
2. **The exclusion argument is refuted by a §1 or §2 source — ALREADY TRUE.** `S-35` is the
   refutation, `EST-08`'s `σ` channel is a second and distinct one, and conditioning on `σ` or on
   noise volume repairs neither: noise volume is a post-treatment mediator, so conditioning on it
   induces collider bias rather than restoring exclusion. This condition is **not** hypothetical;
   it is the current state, and 5.2.1 governs whether the phase may proceed at all.
3. Phase 2's event-clock ruling (`FRM-03`, **UNRESOLVED at plan time**) makes a time-axis
   instrument inadmissible against event-indexed outcomes.
4. The identifying moment is not the one measured — dispersion versus cross-chain mean (`S-32`),
   unresolved pending condition 7.
5. Every chain with usable mean-`Δt` variation is compromised at the protocol level. **This is
   close to already true.** After §3.2's screening: Ethereum contributes essentially zero
   variation (`S-38`); Arbitrum fails 5.2(a) outright (`S-41`); Base carries a definitional
   ambiguity and a mid-series structural break (`S-43`). The plausible remainder is roughly four
   chains, i.e. **`G ≈ 4`**.
6. The effective `N` — chain-periods carrying instrument variation, **not** swaps (`S-29`) —
   cannot support the strength and power standard of §5.6.
7. **The time base is not fixed, and this is the binding blocker on the phase.** Arbitrage
   *incidence per block*, *count per unit time* and *value per unit time* scale in `Δt` as
   `+1/2`, `−1/2` and `+1/2`, so **the first stage's sign flips** between the count reading and
   the other two (§2.5, challenge 1). Precisely: `Ḡ = (∂ν/∂Z)/(∂λ/∂Z)`, the numerator is
   convention-free and **the denominator changes sign with the time base**, so what is
   indeterminate is *which estimand `Ḡ` names*. **This is a live researcher degree of freedom that
   mechanically determines the sign of `H2`**, and anyone free to fix it after seeing the reduced
   form can guarantee the hypothesised sign. It is therefore **pre-committed here as a required
   ruling, dated and named, to be made before window A opens and recorded in the
   pre-registration**; this register does not make the ruling, and no member of §2.6 may be
   admitted under 5.2(d) until it is made, because no derivation can link an excluded variable to
   an undefined object. Related to inherited item **O4** but **not the same severity**: O4 is a
   scale error in `σ` versus `σ²`, which leaves the `Δt` exponent unchanged; this is a **sign**
   error.
8. **`ν` and `λ_MEV` share an accounting component.** `ν`'s numerator carries traded quantity, and
   `S-18` puts more than a fourth of the volume on Ethereum's five biggest DEXes in non-atomic
   arbitrage. Part of `∂ν/∂λ_MEV` is therefore an **accounting** derivative rather than a
   behavioural one, and it is **positive by construction — the sign `H2` predicts.** Unless `ν`'s
   construction excludes arbitrage flow from its numerator, or the accounting component is
   bounded and netted, a confirmatory result is uninformative. `EST-01` must resolve this when it
   fixes `ν`'s empirical construction, and it is a voiding condition because a design that cannot
   separate the two cannot test `H2` at all.
9. **The design has no fixed-effects defence.** A cross-chain mean `Δt` is constant within chain
   and, Ethereum aside, constant over time, so it is **collinear with chain fixed effects** and
   they cannot be included. Every cross-chain confound — token composition, gas, user base, venue
   age, regulatory regime — therefore loads directly onto the instrument. `S-20` documents this
   confound and `S-25` inherits it. If no within-chain variation is admitted (menu candidate 2),
   this is unmitigable.
10. **`Ḡ` is not a scalar.** Under `EST-04`'s form, `Ḡ = b·c·σ_ℓ′(c(λ − d))` is a function of `λ`
    that vanishes in both tails by construction. Every sign, power and detectability statement is
    ill-posed until the **evaluation point** at which `Ḡ` is reported is pre-committed. `EST-05`'s
    admissible band presumes this and it is not yet fixed.

**5.5 The ban, scoped.** Adding a **source or an instrument** to this register after `EST-03`
returns is a protocol violation recorded in §6, **not** an amendment. **Correcting a
misstatement of fact is not an addition and is not banned** — it is required, and it is recorded
in §6 as a correction with its date and cause. The first draft's wording banned both, which would
have made this register unfixable in the face of a demonstrated error; §2.4's corrected verdict
and this section's own rewrite are the proof that the narrower scope is the right one.

**5.6 The inference and power standard, pre-committed.** `ECONOMETRICS-DESIGN.md` §4 requires the
specification, instrument, sample **and power floor** to be fixed before the data is touched. The
first three are fixed above; this clause fixes the fourth, and corrects a confusion in the first
draft that adopted two mutually redundant standards at once.

- **Strength is reported as an *effective* F**, per `S-31`, not a robust F — the grouped-data case
  where the robust F is large and the effective F small is structurally this design's case.
- **`F > 104.7` (`S-27`) is a POWER diagnostic, not a validity gate.** The first draft used it as
  a voiding condition while simultaneously adopting Anderson–Rubin as inference of record; those
  are incompatible, since AR is size-valid *under weak identification in all clusters* and would
  never be reached if 104.7 gated the phase. `S-27`'s own remedy is the **tF procedure**, which
  supplies F-dependent adjusted critical values — a graduated correction, not a cliff — and the
  first draft omitted it. tF is adopted.
- **Wild bootstrap Anderson–Rubin (`S-30`) is the size-valid inference of record**, with two
  limitations recorded rather than hidden: it is a **full-vector** procedure, so a confidence set
  for `Ḡ` alone requires exactly one endogenous regressor with controls partialled out — which
  `ECONOMETRICS-DESIGN.md` §6 item 3 puts in doubt, since `φ_X` carries `ν`; and AR tests the
  **joint** null of the parameter value *and* exclusion, so under the live §5.4(2) violation a
  rejection cannot be attributed to `Ḡ`.
- **`S-29` is cited for effective `N` only.** Its jackknife methods are built for many
  instruments and do not transfer to a just-identified design.
- **A numeric power floor is required of `EST-07` before window A opens**, benchmarked against
  `S-21`, which achieved a minimum detectable effect of about 1.03 asinh units — a factor of
  roughly 2.8 — from a design-based DiD with **1,013 clusters** and 17,598 pool-weeks. This design
  has `G ≈ 4`, an instrument with zero within-cluster variation, and variance inflated by `1/F` on
  a first stage `S-33` leaves unbounded below, while `S-22`'s comparable on-chain elasticities are
  **−0.006 to −0.036**. **The register states plainly what follows: a design whose best-case
  comparator could not detect a factor of 2.8 is unlikely to detect an elasticity of order 0.03.**
  `EST-07` must state an MDE ceiling and pre-commit that exceeding it is a **non-identification
  verdict, not a caveat**.
- **Estimand scale and heterogeneity are disclosed, not assumed away.** With a continuous
  chain-level instrument and a first stage `S-15` documents as heterogeneous across pools, 2SLS
  returns a first-stage-weighted average of pool-specific effects, not a population parameter;
  **monotonicity** is required for even that reading and is not established. Comparisons of
  `S-21`'s asinh minimum detectable effect with `S-22`'s elasticities are **not on a common
  scale**, and `EST-07` must place any power claim on one stated scale.

**5.7 Two gaps in this section, recorded rather than closed.**

1. **The inference of record cannot serve the only route §5 permits.** §5.2.1 requires a failed-(b)
   override to report a **set, not a point**; §5.6 makes wild bootstrap Anderson–Rubin the
   size-valid inference of record, which is a point-null full-vector procedure, and concedes that
   under the live condition-2 violation a rejection cannot be attributed to `Ḡ`. **No
   partial-identification estimator is pre-committed here**, and naming one after `EST-03` returns
   would be a §5.5 violation. `EST-07` must therefore name the bounds procedure and its inference
   **before window A opens**, or record that the override is unavailable and §5.1's terminal branch
   is the only one left.
2. **A condition was deleted from §5.4, and the deletion is recorded because deletions are how
   findings get lost.** An earlier draft carried a ninth condition asserting that the plant's
   `ν → φ → ℙ` feedback makes the system *underidentified* with one instrument. **The specialist
   reviewer demonstrated this is econometrically false** — simultaneity with a valid excluded
   instrument is the canonical case *for* IV, the order condition is satisfied for the equation of
   interest, and the feedback multiplier cancels in the probability limit; `ECONOMETRICS-DESIGN.md`
   §2 further notes `λ_ARB` is **predetermined**, making the system recursive rather than
   simultaneous. The condition was removed as a **false** voiding condition, not as an
   inconvenient one. What survives of it is real and is carried elsewhere: the feedback is why OLS
   is inconsistent and why an instrument is needed at all; a stability requirement on the loop gain
   should be pre-stated; and the genuine order-condition failure is at Stage 2, recorded in §5.1.

## 6. Protocol-violation log

| # | Date | Violation | Recorded by | Disposition |
|---|---|---|---|---|

No violations recorded as of 2026-08-09.

**This section is APPEND-ONLY and downstream plans are authorised to write to it.** `06B-03` and
`06B-04` both carry `control/spec/RESEARCH-REGISTER.md` in their `files_modified` and commit paths
precisely so that disclosing a protocol note is not blocked by a single-path commit assertion.
**Disclosure must never be harder than concealment.**

## Review

The review register (`HND-05`, Phase 1) does not exist, so the two-step review is recorded here.
Both reviewers received the same artifact, **neither edited it**, and both were dispatched **in
parallel** per the standing constraint that every artifact passes the two-step review before it is
committed.

**Reviewer 1 (always):** Reality Checker — 2026-08-09.
  findings: 7 BLOCKER / 20 MAJOR / 6 MINOR. disposition: resolved 13, carried 20 — carried items
  named below.
**Reviewer 2 (named specialist):** Model QA Specialist — chosen because this artifact is an
  econometric evidence base whose failure modes are identification, inference and replication
  failures rather than prose defects, which is that agent's domain; the alternative candidates
  (Analytics Reporter, Trend Researcher) review reporting and market intelligence, not
  identification. 2026-08-09.
  findings: 6 BLOCKER / 12 MAJOR / 7 MINOR. disposition: resolved 9, carried 16 — carried items
  named below.
**Review date precedes commit date:** yes — the commit follows this block being written.

**BLOCKERs resolved before commit (both reviewers).** The stale status banner that declared the
file uncommittable was removed. **A structural defect was found and fixed: the corrected §5 had
been spliced inside that banner, leaving two mutually contradictory copies of §5 in one file** —
the pre-review copy was deleted and the corrected one placed after §4. §5 was then rewritten
wholesale: 5.2's clauses no longer claim to select an instrument they do not select, 5.3 states
plainly that `√Δt` **fails** clause (b), §5.0 states the bottom line in one place, 5.2.1 governs
overrides, and §5.6 replaces the incoherent double standard (a validity gate at `F > 104.7`
alongside Anderson–Rubin) with an effective-F reporting standard plus tF. A voiding condition
asserting the system was underidentified by simultaneity was **deleted as econometrically false**
on the specialist's demonstration, with the deletion recorded in §5.7. Off-by-one source
references in §4 and §5.3 were corrected. Stale pre-correction claims were corrected at source in
`S-32` (dispersion), `S-08`/`S-33` and §4 row 6 (Guo), and §1.16 (a forward-pointing banner).

**The most serious finding, and its disposition.** The Reality Checker verified citations at full
text and established that **both coefficients this register had quoted as proof that the estimand
is already estimated were defective** — one traced to a superseded 2021 draft while being cited to
a 2025 journal article, the other has the liquidity quantity as its *dependent* variable and is
stated by its own authors to be mechanically determined by another column. **Both numbers are
withdrawn** (§2.5 challenge 5, §4 row 9), and the claim they supported is downgraded to its
defensible form. Two further well-fitted numbers were corrected: a fabricated corollary locator on
the leading threat, and a first-stage `F = 4.14` that is the sub-variant rather than the source's
headline first stage. A provenance flag now marks §2.4's journal citations as referee-sourced and
**not** independently re-verified, unlike every arXiv identifier here.

**MAJOR findings carried, not resolved — each is real and none is silently dropped.** §5 does not
run 5.2 over menu candidates 2, 3, 5, 6 and 7 individually (routed to `LIT-04`). `G_min` is left
unset, so voiding condition 1 is checkable only after `EST-07` reports. No numeric power floor or
MDE ceiling is stated here; §5.6 requires `EST-07` to state one before window A opens. No
partial-identification estimator is pre-committed (§5.7 item 1). The clustering level recorded here
is the chain while `EST-07` says chain-time. The switch from dispersion to cross-chain mean is
scoped to plans rather than to requirements. `S-49`'s deployment count carries no evidence anchor,
so §5.2(c) rests on unanchored vendor self-report and is discharged only as a presumption. Several
quantitative challenges in §2.5 (the `1/√2` constant discrepancy, the linearization error, the
hump-shaped-liquidity claim) remain referee-reported and unreproduced. The adversarial referee ran
**one** round and returned **NOT CONVERGED**; a second round was not run.

**A limitation both reviewers raised and this register accepts.** Most evidence anchors quote
abstracts while the surrounding text asserts full-text facts; where a claim was checked at full
text this is now said explicitly, and where it was not, the anchor is the abstract and nothing
stronger should be inferred from it.

**Neither reviewer certified this artifact as safe to commit**, and both verdicts are recorded
without softening: Reality Checker, "NOT safe to commit as the sha-pinned evidence base"; Model QA
Specialist, "not sound enough to sha-pin as the pre-registration evidence base in its current
state." **Both verdicts were rendered against the pre-fix file.** The blockers each named have been
resolved above, and the carried MAJORs are recorded here and routed to named downstream
requirements rather than closed. **This register is committed as an honest record of what the
sweep found — including that it found the phase cannot proceed to estimation as designed — and not
as a certificate that the design is sound.** §5.0 states that conclusion in one place; §6 remains
append-only so any later disclosure is never blocked.
