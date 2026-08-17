
> NOTE: [CALCULUS IS THIS ONE](refs/cfmm-discrete/) (canonical KB: cfmm-theory `cfmm-discrete/` — cited, not vendored-as-authority) . We need to fgind the discrete ficnacnial caluclus pdf byut Frogy eithr online or locally

> TODO: Formalize in lean4
Note that consistent with the lean 4 spec our contract is essentially a volatility option:

\[
	\begin{aligned}
		\pi^{\sigma} \, &= \, \Delta Q_{v} \, \Big ( \, \sigma^2 \, (i (t)) - \sigma^2_K\Big)^{+} \, \implies \, \Delta Q_{v} \, \equiv \, \frac{\Delta \pi^{\sigma}}{\Delta \Big ( \, \sigma^2 \, (i (t)) - \sigma^2_K\Big)^{+}}
	\end{aligned}
\];
Note that following the main reference on [VOL_SWAPS](https://emanuelderman.com/wp-content/uploads/1999/02/gs-volatility_swaps.pdf) (Demeterfi, Derman, Kamal, Zou 1999, "More Than You Ever Wanted To Know About Volatility Swaps", Goldman Sachs Quantitative Strategies Research Notes), the price of the vol claim \(p_{\pi^{\sigma}}\) is the *cost of replicating it using options as the underlying*. This is where [panoptic](https://arxiv.org/pdf/2204.14232) enters:

We have somehow simplified:

\[
	\begin{aligned}
		p_{\pi^{\sigma}} \, = p_0 \, + \, \alpha_1 \, p_{\pi^{\text{call}}} \, + \, \alpha_2 \, p_{\pi^{\text{put}}} 
	\end{aligned}
\]

Where:

\[
	\begin{aligned}
		p_{\pi^{\text{call | put}}} \, &= \, \int_{p_{(\eta, \Delta_i)} \, (i; t)} \, \theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , K,  \sigma \, (i (t)) \Big ) \, \mathcal{d}\, t
	\end{aligned}
\]


Where:

\[
	\begin{aligned}
		\theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , K,  \sigma \, (i (t)) \Big ) \, &\equiv \, \frac{\Delta \pi^{\text{call | put}}}{d\, t } \equiv \int \phi \, dt\\
		&= \,  \frac{p_{(\eta, \Delta_i)} \, (\cdot)\, \sigma \, (\cdot)}{\sqrt{8\, \pi \, t}} \, \exp \Big (-\,\frac{\Big [- \ln (\frac{p \, (t_0)}{K}) \, + \, \frac{\sigma^2 \, t}{2} \Big ]^2}{2\, \sigma^2 \, (\cdot)\, t}\Big)
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


In particualr WE EXPECT as null hyppthesis to see that for tick strike \(\frac{\Delta \upsilon (t)}{\Delta i(t)} (i_K)\) exhibit a max point on at the money and exp decreasing out the money

## CONTRACT LEVEL

> This requires the analyticsal formula and a realiable way to test and track on a Lens.sol/plank contract as a state viewer
