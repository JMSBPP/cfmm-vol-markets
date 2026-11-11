import [\(\mathcal{L}\)](@spec/LiquidityChunk.spec/LiquidityChunk.md)

import [\(\pi^{c|p}\)](@spec/CoveredCall.spec/CoveredCall.md)

import [\(\pi^{\mathrm{RAN}}\)](@spec/RangeAccrual.spec/RangeAccrual.md)

# TYPE
\[
	\begin{aligned}
	        \pi^{\sigma}_{\phi} = \texttt{getAccountPremium} \\
			\int_{i_{\texttt{path}}} \, \phi \mathcal{V} \Delta i \, \equiv \,  \pi^{\sigma}_{\phi} (i_j)\, = \, G(\iota)\,\sigma_{\mathrm{RV}}^{2} \, (i_j)
	\end{aligned}
\]



\(\pi_{\phi}^{\sigma}\) :  Premium = PremiumRate | Utilization

## Premium \(\pi_{\phi}^{\sigma}\)


###  PremiumRate \(\phi\)


### Utilization \(\nu\)


# DEFINE

\[
	\begin{aligned}
		\forall\, j
		\quad
		\pi(\bar L; j)
		&=
		\pi^{c|p}(\bar L; j)
		+
		\pi^{\mathrm{RAN}}(\bar L; j)
	\end{aligned}
\]

# REFINE
