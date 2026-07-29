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
		\upsilon = \frac{\Delta \, \Pi^{\text{call | put}} \, ( \cdot )}{\Delta \, \sigma } \, = t/2
	\end{aligned}
\]


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
		\frac{\Delta \, \Pi^{\text{call | put}} \, ( \cdot )}{\Delta \, \sigma } N_{\sigma} \, &= \, t/2 \, N_{\sigma} \, \implies \text{Id}_{ N_{\sigma}} \, = \frac{2}{t} \, \iff \, \frac{\Delta \, \Pi^{\text{call | put}} \, ( \cdot )}{\Delta \, \sigma } \text{Id}_{ N_{\sigma}} \, \equiv \, 1
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
Make:

\[
	\begin{aligned}
		\phi \, ( \sigma \, (i (t));t) \, & \leftarrow \, \theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , K,  \sigma \, (i (t)) \Big )
	\end{aligned}
\]

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


### MEV
