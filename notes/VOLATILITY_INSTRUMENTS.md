# VOLATILITY_INSTRUMENTS

> NOTE: [CALCULUS IS THIS ONE](~/learning/cfmm-theory/cfmm-discrete/**) . We need to fgind the discrete ficnacnial caluclus pdf byut Frogy eithr online or locally

> TODO: Formalize in lean4
Note that consistent with the lean 4 spec our contract is essentially a volatility option:

\[
	\begin{aligned}
		\pi^{\sigma} \, &= \, \Delta Q_{v} \, \Big ( \, \sigma^2 \, (i (t)) - \sigma^2_K\Big)^{+} \, \implies \, \Delta Q_{v} \, \equiv \, \frac{\Delta \pi^{\sigma}}{\Delta \Big ( \, \sigma^2 \, (i (t)) - \sigma^2_K\Big)^{+}}
	\end{aligned}
\];
Note that following the main reference on [VOL_SWAPS](../refs/DemeterfietalVarianceSwaps.pdf), the price of the vol claim \(p_{\pi^{\sigma}}\) is the *cost of replicating it using options as the underlying*. This is where [panoptic](https://arxiv.org/pdf/2204.14232) enters:

We have somehow simplified:

\[
	\begin{aligned}
		p_{\pi^{\sigma}} \, = p_0 \, + \, \alpha_1 \, p_{\pi^{\text{call}}} \, + \, \alpha_2 \, p_{\pi^{\text{put}}} 
	\end{aligned}
\]

Where:

\[
	\begin{aligned}
		p_{\pi^{\text{call | put}}}\, (t) \, &= \, \int_{p_{(\eta, \Delta_i)} \, (i; t)} \, \theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , K,  \sigma \, (i (t)) \Big ) \, \mathcal{d}\, t
	\end{aligned}
\]


Where:

\[
	\begin{aligned}
		\theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , K,  \sigma \, (i (t)) \Big ) \, &\equiv \, \frac{\Delta \pi^{\text{call | put}}}{\Delta\, t } \\
		&= \,  \frac{p_{(\eta, \Delta_i)} \, (\cdot)\, \sigma \, (\cdot)}{\sqrt{8\, \pi \, t}} \, \exp \, \Big (\frac{\Big [- \ln (\frac{p \, (t_0)}{K}) \, + \, \frac{\sigma^2 \, t}{2} \Big ]^2}{2\, \sigma^2 \, (\cdot)\, t}\Big)
	\end{aligned}
\]


> FLAG (lean layer, undecided): the sign of the exponent above. A Black–Scholes-type dt-leg decays OTM, suggesting \(\exp(-[\cdot]^2/(2\sigma^2 t))\); the proven ATM closed form \(\Theta_{ATM}(\tau) = k\sigma/\sqrt{8\pi\tau}\) (`Panoptic.theta_atm_closed_form`) has vanishing exponent ATM and cannot discriminate. Author decision pending.

One greek of special interest that we wnat to identify and is the bridge with our protocol is \(\upsilon\); this is beacuse dimensioally lives on the place that \(\Delta Q_v\):

\[
	\begin{aligned}
		\upsilon \, \Big (p_{(\eta, \Delta_i)} \, (i; t) \, , K\Big)\, &\equiv \, \upsilon \, &\equiv \, \frac{\Delta \pi^{\text{call | put}}}{\Delta \sigma^2 \, (\cdot)} \\
	\end{aligned}
\]

Once we identify \(\upsilon \, (\cdot)\) we can build on top of panoptic from our protocol or vice versa:

# \(\upsilon\) IDENTIFICATION

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



# FAQ
- Why one leg on the tokenId is not enough for buidlign the variance instrument  ?

"If you want a long position in future realized variance, a single option
is an imperfect vehicle: as soon as the stock price moves, your sensitiv-
ity to further changes in variance is altered ?"[PG7](../refs/DemeterfietalVarianceSwaps.pdf)

- **Solution**  What you want is a portfolio \(\Pi\)whose sensitivity to realized variance is independent of the underlying price \(p_{(\eta, \Delta_i)} \, (i; t)\) [PG7](../refs/DemeterfietalVarianceSwaps.pdf)

This is:

\[
	\begin{aligned}
		\pi^{\sigma} (t) \, &= \, \Pi^{\text{call | put}} \, (\sigma ;p_{(\eta, \Delta_i)} \, (i; t)) \\
		&= \, \sum_{i_K} \, L (i_K) 
	\end{aligned}
\]
For some \(p^{\star}\) (the approxi-mate at-the-money forward stock level that marks the boundary
between liquid puts and liquid calls.) [PG9](../refs/DemeterfietalVarianceSwaps.pdf)

We have the regions:

\[
	\begin{aligned}
		\Pi^{\text{call | put}} \, (\sigma ;p_{(\eta, \Delta_i)} \, (i; 0)) \, &= \, \frac{p_{(\eta, \Delta_i)} \, (i; 0) - p^{\star}}{p^{\star}} \, - \, \log(\frac{p_{(\eta, \Delta_i)} \, (i; 0)}{p^{\star}}) \\
		\\
		\Pi^{\text{call | put}} \, (\sigma ;p_{(\eta, \Delta_i)} \, (i; t)) \, &= \, \frac{p_{(\eta, \Delta_i)} \, (i; t) - p^{\star}}{p^{\star}} \, - \, \log(\frac{p_{(\eta, \Delta_i)} \, (i; t)}{p^{\star}}) \, + \, \frac{\sigma^2 \, t}{2}
	\end{aligned}
\]


Then:
\[
	\begin{aligned}
		\upsilon = \frac{\Delta \, \Pi^{\text{call | put}} \, ( \cdot )}{\Delta \, \sigma^{2} } \, = t/2
	\end{aligned}
\]


> LEAN (correction applied): \(\upsilon\) is the \(\sigma^{2}\)-derivative, matching \(\upsilon \equiv \Delta\pi/\Delta\sigma^2\) above; proved through the finite-difference operator `Upsilon.upsilon`: `variancePortfolio_upsilon` (\(= t/2\), independent of \(p_{(\eta,\Delta_i)}\)), `variancePortfolio_unit_upsilon` (\(\text{Id}_{N_\sigma}\)-scaled portfolio has unit vega). Also \(\Pi \geq 0\) with \(\Pi(p^{\star}) = 0\): `logPortfolio_nonneg`, `logPortfolio_atm`.

> Note: A single leg portaflio gives:

\[
	\begin{aligned}
		\frac{\Delta \pi^{\text{call | put}}}{\Delta \, \sigma} \, &\approx \frac{\Delta \theta}{\Delta \sigma}
	\end{aligned}
\];

Which is higly sensible to the direction of \(p_{(\eta, \Delta_i)}\)  from the term \(\ln (p_{(\eta, \Delta_i)} / K)\)

Then:

\[
	\begin{aligned}
		\frac{\Delta \, \Pi^{\text{call | put}} \, ( \cdot )}{\Delta \, \sigma^{2} } N_{\sigma} \, &= \, t/2 \, N_{\sigma} \, \implies \text{Id}_{ N_{\sigma}} \, = \frac{2}{t} \, \iff \, \frac{\Delta \, \Pi^{\text{call | put}} \, ( \cdot )}{\Delta \, \sigma^{2} } \text{Id}_{ N_{\sigma}} \, \equiv \, 1
	\end{aligned}
\]

Then:

\[
	\begin{aligned}
		\Pi^{\text{call | put}} \, (\sigma ;p_{(\eta, \Delta_i)} \, (i; t); T) \, &= \, \text{Id}_{ N_{\sigma}} \Big [\frac{p_{(\eta, \Delta_i)} - p^{\star}}{p^{\star}} \, - \, \log (\frac{p_{(\eta, \Delta_i)}}{p^{\star}})\Big] \, + \, \frac{T - t}{T}\, \sigma^2
	\end{aligned}
\]


Then:

\[
	\begin{aligned}
		\sigma^2_R\, (T), \sigma^2_I \, (0) , \bar \sigma^2_K\equiv [\frac{t}{T} \, \sigma^2]
	\end{aligned}
\]


\[
	\begin{aligned}
		\Pi^{\text{call | put}} \, (\sigma^2_R\, (T) ;p_{(\eta, \Delta_i)} \, (i; t); T) \, &= \, \text{Id}_{ N_{\sigma}} \Big [\frac{p_{(\eta, \Delta_i)} - p^{\star}}{p^{\star}} \, - \, \log (\frac{p_{(\eta, \Delta_i)}}{p^{\star}})\Big] \, + \, \sigma^2_R\, (T) 
	\end{aligned}
\]

\[
	\begin{aligned}
		\pi^{\sigma} \, (\sigma_K, T; t) \, &= \, \Big (\sigma^2_R\, (T) - \sigma^2_K\Big)^{+}
	\end{aligned}
\]
 

Note that:

\[
	\begin{aligned}
		\pi^{\sigma} \, (\sigma_K, T; t) \, &= \sum_{i_K} \, L(i_K) \, \mathbb{I}_{\text{long | short}} \\
		\\
		\mathbb{I}_{\text{put | call}} \, &= \, 
		\begin{cases}
		- \, 1 & \, \text{long} \\
		1 \, & \, \text{short}
		\end{cases}
	\end{aligned}
	
\]

> The weights on the strike to make the protafolio delta neutral are encoded on the parameters \(\xi, \iota\)
Where:

\[
	\begin{aligned}
		L \, (i_K) \, &= \, \bar L \, \ell \, (\xi, \iota; i_k) \\
		\\
		\bar L \, &= \sum_{i_K = i_{\text{min}}}^{i_{\text{max}}} \, L \, (i_K)\, \quad \, \ell \, (\xi, \iota; i_k) \, = \, \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)}
	\end{aligned}
\]

Define:

\[
	\begin{aligned}
		\Theta_{\ell} \, &= \, \{\xi, \iota\}
	\end{aligned}
\]

> LEAN (proved + correction): the weights are a partition of unity and the delta-neutral ratio is pinned:

\[
	\begin{aligned}
		\sum_{i_K} \, \ell \, (\xi, \iota; i_K) \, = \, 1, \quad \ell > 0 \; (\xi \in (0,1) \cup (1,\infty)), \quad \lim_{\xi \to 1} \ell = \frac{1}{\iota}
	\end{aligned}
\]

On the price grid \(K_i = \lambda^{i \Delta_i}\) the discretized strike-notional weights of the log contract are exactly geometric,

\[
	\begin{aligned}
		\frac{K_{i+1}-K_i}{K_i^2} \, = \, (\lambda^{\Delta_i}-1)\,\big(\lambda^{-\Delta_i}\big)^{i}
	\end{aligned}
\]

but the per-tick *liquidity* replicating the log contract obeys \(\ell(K) \propto K^{-1/2}\) (curvature \(\ell(P) = -2P^{3/2}V''(P)\), \(V'' = -1/P^2\)), hence

\[
	\begin{aligned}
		\xi^{\star} \, = \, \lambda^{-\Delta_i/2} \quad \text{(NOT } \lambda^{-\Delta_i}\text{; the two differ by the tranche-gamma Jacobian)}
	\end{aligned}
\]

> `GeomProfile.geomWeight_sum/_pos/_tendsto_uniform`, `varswapWeight_geometric`, `logContractLiquidity_geometric`, `VolInstrument.strikeWeight_bridge`.

Where under the prcing geometry:

\[
	\begin{aligned}
		p_{(\eta, \Delta_i)} (i_K) \, &= \, \lambda^{i/2 \, \Delta_i \, \eta}
	\end{aligned}
\]
Define:

\[
	\begin{aligned}
		\Theta_{p} \, &= \, \{\eta, \Delta_i\}
	\end{aligned}
\]
We have on the underlying market \(X, M\):

\[
	\begin{aligned}
		\Delta Q_M^{L} (i_K) \, &= \, L \, (i_K) \Big [ \frac{p_{(\eta, \Delta_i)} (i_K + \Delta_i) \, - \, p_{(\eta, \Delta_i)} (i_K)}{p_{(\eta, \Delta_i)} (i_K) \, p_{(\eta, \Delta_i)} (i_K + \Delta_i)}\Big] \\
		\\
		\Delta Q_X^L \, (i_K) \, &= \, L \, (i_K) \Big [ p_{(\eta, \Delta_i)} (i_K + \Delta_i) \, - \, p_{(\eta, \Delta_i)} (i_K) \Big ]
	\end{aligned}
\]


> LEAN (proved, with corrected hypotheses): nonnegativity of both legs requires \(\Delta_i \geq 0\) in addition to \(\eta\,\Delta_i > 0\) (\(\eta,\Delta_i < 0\) makes \(i_K + \Delta_i < i_K\) and reverses signs), and the money leg is the reciprocal-price difference:

\[
	\begin{aligned}
		0 \leq L, \; \eta\,\Delta_i > 0, \; \Delta_i \geq 0 \;\implies\; \Delta Q_M^L, \Delta Q_X^L \geq 0; \qquad
		\Delta Q_M^{L}(i_K) \, = \, L(i_K)\Big[\frac{1}{p_{(\eta,\Delta_i)}(i_K)} - \frac{1}{p_{(\eta,\Delta_i)}(i_K+\Delta_i)}\Big]
	\end{aligned}
\]

> `VolInstrument.deltaQM_nonneg`, `deltaQX_nonneg`, `deltaQM_token0`.

Then define the cummulatives as: 

\[
	\begin{aligned}
		Q_M^L (i_K) \, &= \sum_{i=i_K}^{i_{\text{max}}} \, \Delta Q_M^{L}\, (i) \\
		\\
		Q_X^L \, (i_K) \, &= \, \sum_{i=i_{\text{min}}}^{i_K} \Delta Q_X^L \, (i)
	\end{aligned}
\]

And the inverse cummulatives as:

\[
	\begin{aligned}
	    Q_M^L (\bar Q_M)^{-1} \, &= \, \text{arg max}_{i} \Big \{ Q_M^L (i_K): Q_M^L (i_K) \geq \bar Q_M\Big\}\\
		\\
			Q_X^L (\bar Q_X )^{-1} \, &= \, \text{arg min}_{i} \Big \{ Q_X^L (i_K): Q_X^L (i_K) \geq \bar Q_X\Big\}\\
	\end{aligned}
\]


> LEAN (proved): both cumulatives are monotone in the step count (for \(L \geq 0\)), so the inverse cumulatives are well-defined least attaining steps; for \(L \equiv \bar c\) they telescope:

\[
	\begin{aligned}
		Q_X^L \, = \, \bar c\,\big[p_{(\eta,\Delta_i)}(i_{\min}+n\Delta_i) - p_{(\eta,\Delta_i)}(i_{\min})\big], \qquad
		Q_M^L \, = \, \bar c\,\Big[\frac{1}{p_{(\eta,\Delta_i)}(i_{\min})} - \frac{1}{p_{(\eta,\Delta_i)}(i_{\min}+n\Delta_i)}\Big]
	\end{aligned}
\]

> `VolInstrument.cumulativeQ{M,X}_monotone`, `cumulativeQ{M,X}_const`, `exists_least_reaching`.

Consider a exogenous tuple flow \( \Delta Q = ( \Delta Q_M, \Delta Q_X )\) on the region:

\[
	\begin{aligned}
		\varphi \, (i_K ; \Delta Q , L)\, &= \, (\Delta Q_M^{L} (i_K) + \Delta Q_M)^{1/2}\cdot(\Delta Q_X^L \, (i_K) \, + \, \Delta Q_X)^{1/2}
	\end{aligned}
\]

Define the convex segment:

\[
	\begin{aligned}
		\Delta Q_M \, &= \ (1 - \phi_M) \, \Delta Q_M \, + \, \phi_M \, \Delta Q_M; \, \quad \, \phi_M \, \in (0,1) \\
	    \Delta Q_X \, &= \, (1 \, - \phi_X)\, \Delta Q_X \, + \, \phi_X \, \Delta Q_X \, \quad \, \phi_X \, \in (0,1)
	\end{aligned}
\]


such that:

\[
	\begin{aligned}
		\Delta Q_M^{L} (i_K) \, + \, \phi_M \, \Delta Q_M \\
		\\
	    \Delta Q_X^{L} (i_K) \, + \, \phi_X \, \Delta Q_X
	\end{aligned}
\]

And a group with inner product \(\otimes_{\phi}\):

\[
	\begin{aligned}
		\mathcal{G}_{\phi}: \phi_M \times \phi_X \to \phi := \phi_M \otimes_{\phi} \phi_X \, \in \, \mathcal{G}_{\phi}
	\end{aligned}
\]


| Economic process         | Operator                 | Structure            |
| ------------------------ | ------------------------ | -------------------- |
| Sequential fee charging  | (1-(1-\phi_1)(1-\phi_2)) | Abelian monoid       |
| Strongest policy wins    | (\max)                   | Join semilattice     |
| Cheapest route wins      | (\min)                   | Meet semilattice     |
| Liquidity aggregation    | Weighted average         | Convex algebra       |
| Feature flags            | OR                       | Monoid               |
| Permission intersection  | AND                      | Monoid               |
| Bit toggling             | XOR                      | Abelian group        |
| Cyclic governance states | Addition mod (N)         | Finite abelian group |

And define:

\[
	\begin{aligned}
\phi \, ( \sigma \, (i (t));t) \, &= \bar \phi\, + \, \Big (\sum_j \, \frac{\alpha_j}{1 + \exp(\gamma_j \, (\beta_j - \sigma (i (t))))} \Big )\, \cdot \frac{\alpha_R}{1 \, + \, \exp(\gamma_R \, (\beta_R - \frac{\varphi \, (i_K ; \Delta Q , 0; t)}{\varphi \, (i_K ; 0, L; t)}))}
	\end{aligned}
\]

Define:

\[
	\begin{aligned}
		\Theta_{\phi} \, &= \, \{ \gamma, \bar \phi, \beta, \alpha\}
	\end{aligned}
\]
> LEAN (proved): writing \(u = \alpha_R/(1+\exp(\gamma_R(\beta_R - x)))\), \(x = \varphi(i_K;\Delta Q,0;t)/\varphi(i_K;0,L;t)\):

\[
	\begin{aligned}
		0 \leq u \leq \alpha_R, \qquad
		\bar\phi \, \leq \, \phi(\sigma) \, \leq \, \bar\phi + \Big(\sum_j \alpha_j\Big)u, \qquad
		\sigma \mapsto \phi(\sigma) \; \text{monotone} \; (\gamma_j > 0, \alpha_j \geq 0, u \geq 0)
	\end{aligned}
\]

The single-term case is the sigmoid fee schedule with steepness \(s_f = 1/\gamma_0\):

\[
	\begin{aligned}
		\bar\phi + \alpha_0\,\Lambda(\gamma_0(\sigma-\beta_0)) \, = \, f\big(\sigma;\, f_{\min}=\bar\phi,\, f_{\max}=\bar\phi+\alpha_0,\, \bar\sigma_f=\beta_0,\, s_f=\gamma_0^{-1}\big)
	\end{aligned}
\]

> `VolInstrument.sigmoidR_mem`, `multiFee_bounds`, `multiFee_monotone`, `multiFee_single_bridge`.

Make:

\[
	\begin{aligned}
		\phi \, ( \sigma \, (i (t));t) \, & \leftarrow \, \theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , K,  \sigma \, (i (t)) \Big )
	\end{aligned}
\]

## VOL ORDER COMPLETION — ENDOGENOUS MATURITY

The order parameter set

\[
	\Theta_{\text{ord}} \,=\, \{\sigma^2_K,\, w,\, s\}
\]

(strike, width, skew) pins only the scale-free leg shape \(\ell\,(\xi, \iota; i_K)\). Complete it with the target vega (DECIDED, 2026-07-30):

\[
	\Theta_{\text{ord}} \,\leftarrow\, \Theta_{\text{ord}} \,\cup\, \{\Delta Q_v^{\star}\}
\]

**Maturity equivalence.** From \(\upsilon = t/2\) (`variancePortfolio_upsilon`) and \(\text{Id}_{N_\sigma} = 2/t\) (`variancePortfolio_unit_upsilon`):

\[
	t^{\star} \,=\, 2\,\frac{\Delta Q_v^{\star}}{N_\sigma} \quad\Longleftrightarrow\quad \Delta Q_v^{\star} \,=\, \frac{t^{\star}}{2}\, N_\sigma
\]

The perpetual order specifies no \(T\); \(t^{\star}\) is the implied maturity of the equivalent dated variance contract — derived from \(\Delta Q_v^{\star}\), never stored.

> LEAN (proved, `EndogenousMaturity.lean`, run 128b24ae): the equivalence is a bijection for \(N_\sigma \neq 0\) — `tStar`/`dQvStarOfMaturity` inverse pair (`dQvStarOfMaturity_tStar`, `tStar_dQvStarOfMaturity`, `maturity_equivalence`); the vega bridges hold exactly: the \(N_\sigma\)-scaled dated portfolio at \(t^{\star}\) has vega \(\Delta Q_v^{\star}\) (`tStar_variancePortfolio_upsilon`, `tStar_unit_upsilon` via `variancePortfolio_upsilon`/`_unit_upsilon`); and

\[
	\begin{aligned}
		\Delta Q_v^{\star}, N_\sigma > 0 \implies t^{\star} > 0; \qquad t^{\star} \uparrow \Delta Q_v^{\star}, \quad t^{\star} \downarrow N_\sigma \;\; \text{(both strict)}
	\end{aligned}
\]

> `tStar_pos`, `tStar_strictMono_dQvStar`, `tStar_strictAnti_Nσ`.

**Dimension (DECIDED, 2026-07-30):** \(\Delta Q_v^{\star}\) carries the dimension of the
REPLICATION CARRIER — liquidity \(L\) — i.e. the quantity of the priced vol asset, per

\[
	\pi^{\sigma} \, = \sum_{i_K} \, L(i_K) \, \mathbb{I}_{\text{long|short}}
\]

The quotient \(\Delta Q_v \equiv \Delta\pi^{\sigma}/\Delta(\sigma^2-\sigma^2_K)^{+}\)
(collateral per vol unit) is the LENS READOUT — computed from a position through the
\(Q_M^L\) range conversion, never stored. One instrument, two views: line-177 names the
stored quantity, line-10 names the measured sensitivity.

**Sizing (forward map — quantity-exact, no price in the map):**

\[
	L(i_K) \,=\, \Delta Q_v^{\star}\,\ell\,(\xi^{\star}, \iota; i_K), \qquad \sum_{i_K} L(i_K) \,=\, \Delta Q_v^{\star} \;\; \big(\textstyle\sum_{i_K}\ell = 1\big)
\]

\(p_{\text{vol}}, p_{\text{risk}}\) enter at the ISSUANCE/ADMISSIBILITY layer (shares,
deleverage), not the sizing map; the mint's collateral requirement is the actual
replication cost, slippage-bounded.

**Identity (the lens obligation):** delivered quantity recovers the stored target,
one-sided under per-leg floor rounding:

\[
	\sum_{i_K} L(i_K) \,\leq\, \Delta Q_v^{\star}
\]

**Collateral channel + AUTO-DELEVERAGE (DECIDED, 2026-07-30).** The contract holds \(\Delta Q_v^{\star}\) fixed, so all adaptation lands on collateral. The live backing requirement and the (division-free) admissibility condition:

\[
	\Delta M_{\text{req}}(t) \,=\, \Delta Q_v^{\star}\cdot p_{\text{vol}}(\bar\sigma; t), \qquad \Delta Q_v \cdot p_{\text{risk}}(t) \,\leq\, Q_M
\]

On violation the position is NOT hard-liquidated: the enforced exposure contracts to the funded level,

\[
	\Delta Q_v(t) \,=\, \min\Big(\Delta Q_v^{\star},\; \frac{Q_M(t)}{p_{\text{risk}}(t)}\Big) \quad \text{(floor)}, \qquad t^{\star}(t) \,=\, 2\,\frac{\Delta Q_v(t)}{N_\sigma}
\]

so the implied maturity CONTRACTS continuously with the funded exposure instead of truncating; a top-up restores both. Liquidation is the degenerate case \(Q_M \to 0\), where the realized life \([t_{\text{mint}}, t_{\text{liq}}]\) is the maturity the position actually had.

> LEAN (proved, `EndogenousMaturity.lean`): the floor is the GREATEST admissible exposure —

\[
	\begin{aligned}
		\forall x,\; 0 \leq x \leq \Delta Q_v^{\star} \wedge x\, p_{\text{risk}} \leq Q_M \implies x \leq \Delta Q_v(t), \qquad \Delta Q_v(t)\, p_{\text{risk}} \leq Q_M \;\;\text{(on violation)}
	\end{aligned}
\]

> `dQvFunded_maximal`, `dQvFunded_mul_le_of_violation`, `dQvFunded_admissible`(`_iff_mul`, division-free via `Main.admissible_iff_mul`); no-violation identity `dQvFunded_eq_of_no_violation`; \(t^{\star}(t)\) monotone in \(Q_M\), antitone in \(p_{\text{risk}}\) (`tStarFunded_mono_QM`, `tStarFunded_antitone_prisk`); EXACT top-up restoration \(Q_M \geq \Delta Q_v^{\star} p_{\text{risk}} \implies t^{\star}(t) = t^{\star}\) (`tStarFunded_eq_tStar_of_topup`); liquidation \(Q_M = 0 \implies \Delta Q_v = 0,\, t^{\star}(t) = 0\) (`dQvFunded_zero_QM`); floor-rounding conservativity at the real layer (min-monotonicity).

**RECALIBRATION LAW (DECIDED, 2026-07-30: multiplicative).** The joint evolution of the implied maturity under the collateral channel AND realized variance \(\sigma^2_R(t)\) accruing against the strike:

\[
	\begin{aligned}
		t^{\star}_{\text{joint}}(t) \, = \, t^{\star}(t)\cdot\Big(1 - \frac{\sigma^2_R(t)}{\sigma^2_K}\Big)^{+} \, = \, \underbrace{\frac{2\,\Delta Q_v^{\star}}{N_\sigma}}_{t^{\star}} \cdot \underbrace{\frac{\min\big(\Delta Q_v^{\star},\, Q_M/p_{\text{risk}}\big)}{\Delta Q_v^{\star}}}_{\text{funding factor}} \cdot \underbrace{\Big(1 - \frac{\sigma^2_R}{\sigma^2_K}\Big)^{+}}_{\text{budget factor}}
	\end{aligned}
\]

> LEAN (proved, `EndogenousMaturity.lean` `tStarJointMult`): nonnegative on \(t^{\star}(t) \geq 0\) (`tStarJointMult_nonneg`; discharged on the economic domain), contracting in \(\sigma^2_R\) (`tStarJointMult_antitone`), agrees with \(t^{\star}(t)\) at \(\sigma^2_R = 0\) (`tStarJointMult_zero`), expires exactly at budget exhaustion \(\sigma^2_R = \sigma^2_K\) (`tStarJointMult_exhausted`).

> Rationale (recorded): the linear burn is the unique law preserving the maturity-equivalence bijection under accrual (\(\upsilon = t/2\) makes variance and time proportional — the \(\sigma^2 t/2\) leg of \(\Pi\)); the two channels factor multiplicatively, so the deleverage monotonicities (`tStarFunded_mono_QM`, `_antitone_prisk`, `_eq_tStar_of_topup`) chain through the product; constant burn rate ⟹ no end-of-life cliff. Rejected alternates remain formalized: \(t^{\star}_{\text{sub}}\) (`tStarJointSub*` — identical on \(t^{\star}(t) \geq 0\), floor placement differs off-domain per `joint_candidates_disagree`) and \(t^{\star}_{\text{quad}}\) (`tStarJointQuadratic*` — REJECTED: grants extra life \((1-r^2) \geq (1-r)\), breaking the dated-equivalent reading and shifting residual vega onto LPs exactly under vol clustering).

> NOTE (cascade, recorded): \(\Delta Q_v^{\star}\) on-chain lands on the PAIR \((\text{PanopticTokenId},\, \text{positionSize})\) — the tokenId is scale-free (strikes, widths, per-leg optionRatio); positionSize is an SFPM mint argument. The ratio-vs-size split of \(\ell(\xi^{\star},\iota;i_K)\) across the pair is the task-#14 sizing decision. Spec: `.planning/vol-order-v2-target-vega-SPEC.md`.

## HAZARD RATES

These are the instrument to map bevhavior objectives with fee parameters. Mathematically, this is:

\[
	\begin{aligned}
	    \lambda\, &\equiv \, \displaystyle \bigoplus_{i=1}^n \lambda_i \, \quad \, i \, \in \, \{\text{lp-competition (FLAIR)}, \text{arb toxicity}, \text{MEV}, \text{TBD}, \cdots \} \\
		\lambda \, &\equiv \, \lambda_M \, + \, \lambda_X
	\end{aligned}
\]

\[
	\begin{aligned}
		\otimes_{\phi} \, \leftarrow \, 1 - (1-\phi_M)(1-\phi_X)
	\end{aligned}
\] 

> LEAN (proved): \(([0,1], \otimes_\phi, 0)\) with \(\phi_M \otimes_\phi \phi_X = 1-(1-\phi_M)(1-\phi_X)\) is an abelian monoid (commutative, associative, identity \(0\), closed on \([0,1]\), monotone), and the hazard correspondence is exact under \(\phi = 1 - e^{-\lambda}\):

\[
	\begin{aligned}
		\big(1-e^{-\lambda_M}\big) \otimes_\phi \big(1-e^{-\lambda_X}\big) \, = \, 1-e^{-(\lambda_M+\lambda_X)}
		\quad\Longleftrightarrow\quad \lambda \, \equiv \, \lambda_M + \lambda_X
	\end{aligned}
\]

> `VolInstrument.probOr_{eq,comm,assoc,zero,mem_Icc,mono,hazard}`.

### FLAIR

Define:

\[
	\begin{aligned}
		\lambda_{\text{FLAIR}}\, (t) \, &\equiv \, \displaystyle\int_{t_0}^t \frac{\displaystyle\int_{p_{(\cdot) \,(t)}} \, \phi \, ( \sigma \, (i (t));t) \, d\, p_{(\cdot)} \,(t)}{p_{(\cdot)} \,(t)\, Q_M^L \Big (\sum_{j}^{\# \text{LP}} \, L_j \, (i(t); \cdot)\Big ) \, +\,  Q_M^L \Big(\sum_{j}^{\# \text{LP}} \, L_j \, (i(t); \cdot)\Big) } \, dt
	\end{aligned}
\]


\[
	\begin{aligned}
		\exists \, \Theta_{\lambda_{\text{FLAIR}}} \, \subset \, \Theta_{\phi} \, \quad \, \sup_{\Theta_{\lambda_{\text{FLAIR}}}} \, \lambda_{\text{FLAIR}}\, (t)
	\end{aligned}
	
\]


> LEAN (proved — the claim above is now identified AND solved): discretizing with flow weights \(w_t \geq 0\) and capital \(D_t > 0\):

\[
	\begin{aligned}
		\lambda_{\text{FLAIR}} \, = \, \bar\phi\, W \, + \, u \sum_j \alpha_j\, W_j, \qquad
		W = \sum_t \frac{w_t}{D_t}, \quad
		W_j = \sum_t \frac{\Lambda\big(\gamma_j(\sigma_t-\beta_j)\big)\, w_t}{D_t}, \quad 0 \leq W_j < W
	\end{aligned}
\]

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{FLAIR}}} \, = \, \{\bar\phi,\, \alpha,\, u(\alpha_R)\}: \qquad
		\lambda_{\text{FLAIR}} \, \leq \, \Big(\bar\phi_{\max} + u_{\max}\sum_j \alpha_{j,\max}\Big)\, W
	\end{aligned}
\]

attained bang-bang at the level corner for any fixed \((\beta,\gamma)\); in \((\beta,\gamma)\) the bound is approached only as \(\beta \to -\infty\) (strict gap at every finite \(\beta\): the sup over unbounded shape parameters is a saturation boundary, not a maximum).

> Caveat: this functional has no demand elasticity — the fee–volume trade-off lives in the optimal-fee layer (`FeeSchedule`, arXiv:2508.08152).
> `FlairOptimization.flairMulti_affine`, `W_j_lt_W`, `flairMulti_le_corner`, `flairMulti_corner_attained_levels`, `flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`, `Theta_lambda_identification`.

### MEV

- Angstrom holds the reference for an implementation 
- Literature that helps on tracking a \(\lambda_{\text{MEV}}\) (My=ust be saved on refs/{flair, mev}/ **.pdf) and then once acquired we can do \(\Theta_{\lambda_{\text{MEV}}}\)

## **M0. [NOTATION]**

The paper's fee symbol `γ` is transcribed as this document's fee `φ`; this document's `γ_j` stays the sigmoid steepness. <!-- notation-map -->
The paper's Poisson block rate `λ` is transcribed through its own primitive `Δt ≜ λ⁻¹`, because this document's `λ` is the hazard rate. <!-- notation-map -->
The paper's composite parameter `η ≜ γ√(2λ)/σ` is deliberately never named, since `η` is reserved project-wide for the pricing kernel. <!-- notation-map -->
Consequently the paper's root-block-rate factor is written \(\sqrt{2/\Delta t}\) throughout, and no composite abbreviation is introduced.
The fee is this document's \(\phi\), with level ceiling \(\bar\phi\) and parameter set \(\Theta_{\phi}\); the glyph \(\varphi\) is NOT used here, because this document already binds it to the quote function feeding the R-sigmoid ratio.

\(\Delta t\) is the mean interblock time — for Angstrom, one bundle per block per pair, so the batch cadence *is* \(\Delta t\).
\(\sigma\) is the same \(\sigma(i(t))\) that already feeds the fee schedule; the identical \(\sigma_t\) enters both the fee and the trade probability.
\(a_t \geq 0\) is the PER-STEP (per-block) arbitrage-opportunity weight. The paper's leading-order LVR is a rate per unit time, so the per-step weight carries an explicit \(\Delta t\): see M3(i). Stating it as a rate would not be commensurable with \(\lambda_{\text{FLAIR}}\), whose \(w_t\) is a per-step traded amount.
\(D_t > 0\) is the SAME deployed-capital denominator as \(\lambda_{\text{FLAIR}}\); with \(a_t\) and \(w_t\) both per-step amounts the two hazards are then commensurable.

Two hazard symbols are used and are never interchangeable.
\(\lambda_{\text{ARB}}\) is the arbitrage-channel hazard, defined in M3; blocks M3–M6b are statements about \(\lambda_{\text{ARB}}\) alone.
\(\lambda_{\text{MEV}}\) is the aggregate over the two channels modelled here, defined in M7 and nowhere else.
Relative to this document's hazard index set, \(\lambda_{\text{ARB}}\) ABSORBS the "arb toxicity" entry: it is not a sibling of \(\lambda_{\text{MEV}}\) but a summand of it, and the index set must not carry both or the aggregate double-counts.

The paper's `FEE` (fees paid by arbitrageurs) is a strict sub-flow of \(\lambda_{\text{FLAIR}}\), which also carries noise-trader flow; the two are NOT identified.

Standing hypotheses for every transcribed closed form below: the paper's Assumption 2 (symmetry — a driftless mispricing and a fee equal on both sides), which the paper calls WLOG with the non-symmetric variant in its Appendix C; and, for M2, the regularity conditions (13) and (15) bounding the convexity of the arbitrage and fee functions in the mispricing.

## **M1. [ADDITION] The trade probability**

\[
	\begin{aligned}
		P_{\text{trade}}(\phi,\sigma,\Delta t) \, = \, \frac{\sigma}{\sigma + \phi\sqrt{2/\Delta t}}
	\end{aligned}
\]

From MMR Theorem 1's stationary distribution, section 4.1 (arXiv:2305.14604v2), under Assumption 2: the long-run fraction of blocks carrying a profitable arbitrage. It is independent of the bonding function and of the feasible set — the only pool property that enters is the fee.

- \(P_{\text{trade}} \in (0,1]\)
- \(P_{\text{trade}} = 1 \iff \phi = 0\)
- strictly decreasing in \(\phi\)
- **strictly convex** in \(\phi\)
- increasing in \(\Delta t\)
- increasing in \(\sigma\)
- \(P_{\text{trade}} \to 0\) as \(\phi \to \infty\)

Strictness of the convexity is recorded deliberately: the strict half of M6b is exactly where it is consumed.

## **M2. [ADDITION] The MMR split**

\[
	\begin{aligned}
		\mathrm{ARB} \, \approx \, \mathrm{LVR}\cdot P_{\text{trade}}, \qquad
		\mathrm{FEE} \, \approx \, \mathrm{LVR}\cdot(1-P_{\text{trade}}), \qquad
		\mathrm{ARB}+\mathrm{FEE} \, \approx \, \mathrm{LVR}
	\end{aligned}
\]

MMR Theorem 3 with eq. (12), and Theorem 4, each under its stated regularity condition: LVR is *split* between arbitrageur profit and arbitrageur-paid fees according to \(P_{\text{trade}}\).
The `≈` is the fast-block (\(\Delta t \to 0\)) small-fee leading order, so every object built on it below is a leading-order object.

## **M3. [ADDITION] The discrete \(\lambda_{\text{ARB}}\)**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, = \, \sum_{t<T} P_{\text{trade}}\big(\phi(\sigma_t),\sigma_t,\Delta t\big)\,\frac{a_t}{D_t}
	\end{aligned}
\]

This is the ARBITRAGE channel, not the aggregate. Its \(\Theta_{\phi}\) specialization takes \(\phi(\sigma) = \texttt{multiFee}(n,\gamma,\beta,\alpha,\bar\phi,u)\) — the SAME \(\Theta_{\phi}\) as FLAIR.

CPMM instantiation, two tiers:

(i) the LEADING-ORDER per-step weight

\[
	\begin{aligned}
		a_t \, = \, \frac{\sigma_t^2}{8}\,V_t\,\Delta t
	\end{aligned}
\]

The paper's \(\mathrm{LVR} = (\sigma^2/8)\,V(P)\) is a limit of expected LVR per unit time, i.e. a RATE; the \(\Delta t\) factor converts it to the per-block amount this sum requires. Consistency check: the per-block summand then scales as \(\Delta t\cdot\sqrt{\Delta t} = \Delta t^{3/2}\), which is the paper's own section 7.1 statement that arbitrage profits per block scale as \(\Delta t^{3/2}\) while per unit time they scale as \(\Delta t^{1/2}\). This tier needs no finiteness guard.

(ii) the EXACT Corollary-2 kernel

\[
	\begin{aligned}
		(\mathrm{ARB}/V)_{\text{exact}} \, = \, \frac{(\sigma^2/8)\,P_{\text{trade}}\,e^{\phi/2}}{1-\sigma^2\Delta t/8}
	\end{aligned}
\]

which is the ONLY object carrying the guard \(\sigma_t^2\Delta t < 8\). Downstream formalization must reuse this symbol under this name.

## **M4. [ADDITION] Identification \(\Theta_{\lambda_{\text{ARB}}}\)**

For positive sigmoid slopes \(\gamma_j > 0\), \(\lambda_{\text{ARB}}\) is antitone in \(\bar\phi\), in each \(\alpha_j\), and in \(u\); isotone in each \(\beta_j\); and convex in the fee.

There is **no affine** identification analogous to `flairMulti_affine`, because \(P_{\text{trade}}\) is not affine — the level and shape coordinates do not separate, and the uniform bound of M5 is a SUM rather than a scalar times a path weight.

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{ARB}}} \, = \, \{\bar\phi,\, \alpha,\, u\}
	\end{aligned}
\]

Under M7's batch-clearing reduction (\(\lambda_{\text{sandwich}} = 0\)) this reads \(\Theta_{\lambda_{\text{MEV}}} = \Theta_{\lambda_{\text{ARB}}} = \{\bar\phi,\, \alpha,\, u\}\) — the sense in which the identification is named for the aggregate.

## **M5. [ADDITION] The infimum program (on \(\lambda_{\text{ARB}}\))**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, \sum_{t<T} P_{\text{trade}}\Big(\bar\phi_{\max} + u_{\max}\textstyle\sum_j \alpha_{\max,j},\, \sigma_t,\, \Delta t\Big)\frac{a_t}{D_t}
	\end{aligned}
\]

Three separate attainment statements, deliberately not merged — the displayed right-hand side uses the fee CEILING, which no finite shape block reaches:

(i) for any FIXED shape block, the infimum over the level block \(\{\bar\phi,\alpha,u\}\) is attained bang-bang at the level-corner TOP;
(ii) the displayed bound itself is only approached, as \(\beta_j \to -\infty\), with a STRICT gap at every finite \(\beta\) (the sigmoid is never saturated), so it is a boundary value and not a minimum;
(iii) on any nonempty compact parameter box a minimizer exists, and its value strictly exceeds the displayed bound.

## **M6a. [ADDITION — THE DEGENERACY] The unconstrained joint program**

The two programs are extremized by the same choices, coordinate by coordinate. Stated as two well-posed claims rather than as an equality of arg-sets, because over an unbounded shape block neither extremum is attained:

(i) for every FIXED shape block, the level-block maximizer of \(\lambda_{\text{FLAIR}}\) and the level-block minimizer of \(\lambda_{\text{ARB}}\) are the SAME corner point in \((\bar\phi,\alpha,u)\) — the top;
(ii) both objectives saturate along the SAME direction \(\beta_j \to -\infty\), i.e. one common sequence simultaneously drives \(\lambda_{\text{FLAIR}}\) to its supremum and \(\lambda_{\text{ARB}}\) to its infimum, neither being attained at finite \(\beta\);
(iii) consequently, for every scalarization weight \(\kappa \geq 0\), the same corner point and the same saturating direction extremize \(\lambda_{\text{FLAIR}} - \kappa\,\lambda_{\text{ARB}}\), so the degeneracy is robust to linear scalarization.

Therefore, **unconstrained, there is no trade-off in \(\Theta_{\phi}\) and the shape block \((\beta, \gamma_j)\) is not essential.** This REFUTES the expectation recorded in the phase brief, and is stated here as a refutation rather than quietly dropped.
By M7's reduction the same statement holds verbatim for \(\lambda_{\text{MEV}}\) in the uniform-clearing regime.

## **M6b. [ADDITION — THE CONSTRAINED PROGRAM] Where the trade-off lives**

Quantified over arbitrary nonnegative fee PATHS \(\{\phi_t\}\) — NOT over schedules in \(\Theta_{\phi}\); see the OPEN note below for why that distinction is load-bearing.
With \(\nu_t = w_t/D_t\), \(W = \sum_t \nu_t > 0\), the FLAIR budget \(\lambda_{\text{FLAIR}} = \sum_t \phi_t\,\nu_t = B\), the aligned-measure hypothesis \(a \equiv w\), and \(\sigma_t \equiv \sigma_0\):

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, W\cdot P_{\text{trade}}\!\left(\frac{B}{W},\,\sigma_0,\,\Delta t\right),
		\qquad \text{equality} \iff \phi_t\ \text{constant on}\ \{t : \nu_t > 0\}
	\end{aligned}
\]

i.e. **among all fee PATHS with the same FLAIR income, the FLAT path minimizes \(\lambda_{\text{ARB}}\), and any path non-constant on the positive-weight steps is strictly worse for \(\lambda_{\text{ARB}}\)** (hence for \(\lambda_{\text{MEV}}\) under M7's reduction). The strict half consumes M1's STRICT convexity.

The aligned-measure hypothesis \(a \equiv w\) is STRONG: it forces the traded-volume path, which carries noise-trader flow, to be proportional block-by-block to the leading-order LVR path. Without it the two sides live under different measures, Jensen does not apply, and the constrained minimizer can tilt the fee UP where the arbitrage measure is heavy — i.e. the conclusion can reverse.

**OPEN**: the display holds at constant \(\sigma_t \equiv \sigma_0\), where it is a statement about fee PATHS. It does NOT deliver a comparison between fee SCHEDULES, because every schedule in \(\Theta_{\phi}\) is a function of \(\sigma\) alone and therefore already produces a constant path when \(\sigma\) is constant — the strict half has no bite inside \(\Theta_{\phi}\) in this regime. Whether a volatility-responsive schedule beats or loses to a flat fee at equal income when \(\sigma_t\) actually VARIES is the open question: the summands are then *different* convex functions, plain Jensen does not apply, and the correct statement is a two-measure/covariance one. It is NOT claimed here.

## **M7. [ADDITION] The aggregate \(\lambda_{\text{MEV}}\), and the Angstrom bridge**

\[
	\begin{aligned}
		\lambda_{\text{MEV}} \, \coloneqq \, \lambda_{\text{ARB}} \oplus \lambda_{\text{sandwich}}
	\end{aligned}
\]

Here \(\oplus\) is hazard-side addition — plain addition of rates, the hazard-side image of this document's \(\otimes_\phi\) monoid under the componentwise correspondence \(\phi_i = 1-e^{-\lambda_i}\). The \(\otimes_\phi\) operation itself acts on probabilities in \([0,1]\) and is NOT applied to the unbounded hazards directly.
Reduction: \(\lambda_{\text{sandwich}} = 0 \implies \lambda_{\text{MEV}} = \lambda_{\text{ARB}}\), which uniform-clearing batches deliver by construction — hence every M3–M6b statement is a statement about \(\lambda_{\text{MEV}}\) in the Angstrom regime.
Sandwich extraction is a distinct MEV channel (arXiv:2207.11835); no sandwich profit shape is modelled here.

Two parametric items, both OUTSIDE \(\Theta_{\phi}\):

(i) the recycling/rebate, an LP-INCIDENCE object rather than an extraction intensity

\[
	\begin{aligned}
		\lambda_{\text{MEV}}^{\text{LP-net}} \, = \, (1-\tau)\,\lambda_{\text{MEV}}, \qquad \tau \in [0,1], \qquad \tau(k) = \frac{k}{k+1}
	\end{aligned}
\]

with \(k\) FREE. The top-of-block auction does NOT prevent the arbitrage — it awards it and routes the winning bid back to liquidity providers, so \(\tau\) redistributes extracted value and leaves the extraction intensity \(\lambda_{\text{MEV}}\) invariant; only the LP-borne share falls. Reading \((1-\tau)\) as a reduction in MEV would be wrong.
The map \(\tau(k) = k/(k+1)\) additionally presumes searchers express their bid through the priority fee and that competition drives the payment to the full arbitrage value under honest priority ordering; under searcher monopoly or proposer collusion the realized \(\tau\) can fall arbitrarily far below it.
As a dated worked instance only, the l2-angstrom snapshot of 2026-07-30 has `k = 49`, giving `τ = 0.98`; the live docs disagree with that snapshot (`TAXED_GAS` 120,000, a `priorityFeeTaxFloor`, a `jitMEVTaxFactor`, and a creator/protocol/LP split), so no numeric constant may enter a claim.
For \(\tau \in [0,1)\) the rebate rescales the objective WITHOUT moving its minimizers, which is precisely the sense in which \(\tau\) sits outside \(\Theta_{\phi}\); at \(\tau = 1\) the objective is identically zero and the statement is vacuous.

(ii) the batch cadence IS \(\Delta t\): it moves \(\lambda_{\text{ARB}}\) monotonically and does not enter \(\lambda_{\text{FLAIR}}\) at all — the second, genuinely non-degenerate lever.

## **M8. [CAVEATS]**

- LEADING ORDER — everything above rests on eq. (12)'s fast-block, small-fee asymptotics; none of it is an exact finite-\(\Delta t\) statement except the M3(ii) kernel under its guard.
- QUASI-STATIC EXTENSION — \(P_{\text{trade}}\) is a STEADY-STATE quantity, derived for constant parameters. M3 applies it per step along a \(\sigma\)-varying path. That is an extension made by this document, not by the paper, and it is legitimate only if the parameters move slowly relative to mixing of the mispricing process.
- NO DEMAND ELASTICITY in EITHER functional. The missing term is MMR section 7.3 eq. (27), `E[delta-hedged LP P&L] = E[NT_FEE] − E[ARB]` — the delta-hedged form; the unhedged decomposition additionally carries the rebalancing term. The paper's own reading: "higher fees reduce noise trader activity ... but also reduce arbitrage profits". Every corner solution here is therefore a property of the formalized objective, not a market-equilibrium claim.
- SCOPE OF THE AGGREGATE — \(\lambda_{\text{MEV}}\) covers the two channels modelled here and is not all of MEV. Not modelled: backruns of noise-trader flow; multi-block MEV, where a censoring agent lengthens the effective \(\Delta t\) and so attacks the M7(ii) lever directly (MMR section 7.1); JIT liquidity, which the cited l2 docs already tax separately; and fixed gas costs, which act as an additive fee and move \(P_{\text{trade}}\) (MMR section 6).
- EMPIRICAL VALIDITY OF THE CADENCE LEVER — the \(\Delta t\) scaling law is validated only for block times of roughly one second and above; below that, reported arbitrage profits decline more slowly than this diffusion model predicts, because real prices jump. Sub-second cadence claims need a jump-diffusion extension and are out of scope.
- The \(\sigma\)-varying schedule comparison of M6b is **OPEN**, as labelled there.
