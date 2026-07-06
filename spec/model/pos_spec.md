
At some instant \(t\) there are known values of tick realized volatility and mean tick:

\[
	\begin{aligned}
		\sigma (t) \, :: \, \text{u88} \\
		i_{\mu} \, (t) \, :: \text{i24}
	\end{aligned}
\]

A user reveals a target volatility level \(\bar \sigma :: \text{u88}\) the value, is brougth to \(\text{Q64.96}\, \quad \bar \sigma_{96}\) from where it can now be assigned a tick coordinate \(i (\bar \sigma_{96})\), and thus give it a price coordinate for a given tick spacing \(\Delta_i\):

\[
	\begin{aligned}
		p \, (i (\bar \sigma_{96})) \, = \, \lambda^{\frac{i (\sigma_{96})}{2} \, \Delta_i}; \, \quad \, \lambda = 1.0001
		
	\end{aligned}
\]

In addition to \(\bar \sigma\) the user reveals a skew \(s_{v} :: \text{u16}\) (*parameter between zero and one) and width lenght \(\#_{\bar \sigma} \, (\Delta_i) :: \text{u24}\) such that:

\[
	\begin{aligned}
		i (\bar \sigma_{96}) \, = s_v \, i_{l} \, (\bar \sigma_{96}) \, + (1 \, - s_v) \, i_{u} \, (\bar \sigma_{96}) \\
		\\
		\Delta_i \,\#_{\bar \sigma} \, (\Delta_i) \, = \, \mid i_{l} \, - \, i_{u} \mid
		
	\end{aligned}
\]

Thus we have:

\[
	\begin{aligned}
		(\bar \sigma,\,  \#_{\bar \sigma}, \, s_v) \to (p (i), p (i_l), p(i_u)) 
	\end{aligned}
\]

