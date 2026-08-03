# VOLATILITY_INSTRUMENTS — EMPIRICAL

> SPLIT OUT of `VOLATILITY_INSTRUMENTS.md` on 2026-08-03 (user instruction, 12.1 pair session):
> the main document is becoming the MATHEMATICAL document (Definitions / Rules / Propositions /
> Conventions); the econometric and empirical material lives here. Content moved BYTE-PRESERVED.
> The υ econometric result recorded here is TERMINAL (phases 09–10): "this market cannot identify
> υ" is never reopened.

## ECONOMETRIC

> As hypothesised ways to achieve such. One can regress the collateral at a contratc level. REcall Panoptic is a tolkenId for uniswap v4/v3 OR per posision. This needs to be thought
> The access point  is the panoptic subgraph

\[
	\begin{aligned}
		Q_M \, &= \, Q_M (\upsilon = 0) \, + \, \upsilon \, (t) \, \sigma^{2} \, (\cdot, t)
	\end{aligned}
\]

And from there we have the API's:

\[
	\begin{aligned}
		\upsilon \, (t) \, = \, \upsilon ( \bar i) \, + \, \frac{\Delta \upsilon (t)}{\Delta i(t)} \, i (t)
	\end{aligned}
\]

Where:

\[
	\upsilon \, (\cdot; t) = \upsilon \, (t)
\]

> DATA (RUN, CLOSED 2026-07-27): \(\pi_{it} = \beta_0 + \upsilon_0 e^{-\kappa|i_K-i_t|}\hat\sigma^2_t + v_{it}\), Base. Ph.9 \(\hat\upsilon_0 = 2.27\text{e-}9\) (61 spells/55 tokenIds/4 accts); Ph.10 LHS ← chain state (6,760 obs/55 clusters): \(\hat\upsilon_0 = 0.036\) (SE 0.075), pivot-locked seller-norm \(0.106\) (SE 0.101); both UNINFORMATIVE vs bar \(6.2\text{e-}5\) ⟹ **\(\upsilon\) NOT IDENTIFIED**, observational estimation never reopened.
> SURVIVED: \(\hat\kappa \approx 0.031\), flat-profile null rejected ×2 (\(p = 9.5\text{e-}3,\, 7.3\text{e-}3\)) ⟹ decay EXISTS, point unvalidated (\(\approx[0.006,\,0.055]\), wedge-biased ↓). `multiplierWedge` measured: med \(1.1125\), p90 \(1.2917\), \(38.9\%/8{,}910 = 1\), \(R/N\) UNBOUNDED (max \(2.33\) ⟹ the \(1.125\) "bound" REFUTED); rig-exact \(1+\nu R/N\) (long), \(1+\nu R^2/(NT)\) (short), \(\nu = 1/8\).
> SUPERSEDED: \(\Delta Q_v\) model-implied ← position state (`volOptionPayoff`, `deltaQv_of_payoff`, `variancePortfolio_upsilon`); validity ← wedge-exact per-obs cross-check + rig level test \(|\hat\upsilon_{FD}-\Delta Q_v|/\Delta Q_v \leq \mathrm{tol}\). TRAP: `volStrike` MASKED, consumed as Q64.96 sqrt-price ⟹ units contradiction. \(\kappa \notin\) lens inputs.



