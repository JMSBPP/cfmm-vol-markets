import [*](../BUSINESS_MODEL.md)

Let \(\Delta_{ij}^{I}\) where \(i\) denotes agents and \(j\) denotes steps. 

Let's model the simplest case where there is only one agent who trades a couple of times. This is:

\[
	\begin{aligned}
	\Delta^I \, &= \, 
		\begin{bmatrix}
			\Delta_{11}^{I} &  \Delta^I_{12} \\
			0 & 0 
		\end{bmatrix}
	\end{aligned}
\]

The agent specifies a fixed notional exposure and target volatility level payoff: 

\[
	\begin{aligned}
		\pi \, &= \, \bar \#_{\sigma}\, 
		\begin{bmatrix}
             0 & \bar \sigma \\
			 0 & 0
		\end{bmatrix}
	\end{aligned}
\]

Then from the realization of \(p \, (\Delta_{11}^I) \, \) the trader wants to chose \( ( \Delta_{12}^{I \, \star} \, \, , \, p_{12} \, (\Delta_{12}^{I \, \star}) )\)such that:

\[
	\begin{aligned}
		\bar \sigma \, &= \, \frac{1}{2} \, \Big( \, p_{11} \, (\Delta_{11}^{I})  \, - p_{12} \, (\Delta_{12}^{I \, \star}) \,\Big )^2 \\
		\\
		\implies \\
		\\
		p_{12} \, (\Delta_{12}^{I \, \star}) \, &= \, p_{11} \, (\Delta_{11}^{I}) \, \pm \sqrt{2 \, \bar \sigma^2}	
	\end{aligned}
\]


Under the pricing rule, we have:

\[
	\begin{aligned}
		\Delta_{12}^{I \star} \, &= \, \frac{\bar L \, \Big ( p_{11} \, (\Delta_{11}^{I})\Big) \, - \, p_{12} \, (\Delta_{12}^{I \, \star} )\Big )}{p_{11} \, (\Delta_{11}^{I}) \, p_{12} \, (\Delta_{12}^{I \, \star})}
	\end{aligned}
\]


