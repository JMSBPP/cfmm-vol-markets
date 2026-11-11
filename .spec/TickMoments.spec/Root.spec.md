\[
	\begin{aligned}
				\Big ( W \, (\texttt{Tx})\, , \,\{i \, (t_j)\}_{j=1}^{N_K} \, \Big) \, \overbrace{\leadsto}^{\texttt{TickPathMoments}} \, \Big (\, i_{\mu}, \sigma_{\texttt{RV}}\Big)
	\end{aligned}
\]


# [WINDOW](./Window.spec/Window.md) \(W\)

In general for some \(j \, \in [1:W]\); one can define:

\[
	\begin{aligned}
	     \Sigma^{g} &::\, j \times g(x_1), \cdots, g(x_W)  \, \mapsto  \sum_{i=1}^{j} \, g(x_i)\\
		\delta_\Sigma^{g}&:: j \, \times \, \Sigma^{g} (j-1) \, \mapsto \, \Sigma^{g} (j) \\
		\\
		\delta_\Sigma^{g} \, \Big(\, j, \, \Sigma^{g} (j-1) \, \Big) &= g(x_j)\, +\, \Sigma^{g} (j) 
	\end{aligned}
\]





