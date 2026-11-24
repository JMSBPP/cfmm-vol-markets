import [\(\mathcal{L}\)](@spec/LiquidityChunk.spec/LiquidityChunk.md)

import [\(\pi^{c|p}\)](@spec/CoveredCall.spec/CoveredCall.md)


import [\(\pi^{\mathrm{RAN}}\)](@spec/RangeAccrual.spec/RangeAccrual.md)



# TODO

- Add premium rate to Context and fix issues arising from it (DONE)
- refactor Premium.t.sol to account for DiffTest structure  (DONE)

- refactor Premium.t.sol to have Observer instead of AlignTick (PENDING)

# TYPE :: GOAL


\[
	\begin{aligned}
		\pi^{\sigma}_{\phi} \star (j; \sigma_K)\, = \, G(\iota)\,\Big (\sigma_{\mathrm{RV}}^{2} \, (j) \, - \, \sigma^{2}_K\Big )
	\end{aligned}
\]

## Premium \(\pi_{\phi}^{\sigma}\)
\(\pi_{\phi}^{\sigma}\) :  Premium = PremiumRate \(\phi\) | Utilization \(\nu\) | Exposure \(N_{\sigma}\)

\[
	\begin{aligned}
		 \pi^{\sigma}_{\phi} ( j + 1) = \Upsilon_{\phi} \, (j+1) - \Gamma \, (j+1)
	\end{aligned}
\]


\[
	\begin{aligned}
	    \Delta\Upsilon_{\phi}^{(X)} (j+1) =  \frac{\phi}{1-\phi} \cdot \frac{V^{(X)} (j+1)}{L_{1/2} (j+1)}\cdot\,2^{128} \\
		\\
		\Upsilon_{\phi}^{(X)} (j+1) \, = \, \Upsilon_{\phi}^{(X)} (j) + \Delta\Upsilon_{\phi}^{(X)} (j+1)
    \end{aligned}
\]

Consider:

\[
	\begin{aligned}
		\pi^{\sigma}_{\phi} \star (j; \sigma_K)\, &= \, G(\iota)\,\Big (\sigma_{\mathrm{RV}}^{2} \, (j) \, - \, \sigma^{2}_K\Big ) \\
		\\&\implies  \langle \sigma^{2}_{RV} \approx \frac{1}{W} \sum_{j=1}^{n_W} \, \ln \Big(\frac{\sqrt{p} (j+1)}{\sqrt{p} (j)}\Big)^{2}\rangle \\
		\\
		&\approx \, G(\iota)\,\Big (\, \frac{1}{W} \sum_{j=1}^{n} \, \ln \Big(\frac{\sqrt{p} (j+1)}{\sqrt{p} (j)}\Big)^{2} \, - \, \sigma^{2}_K\Big )
	\end{aligned}
\]


