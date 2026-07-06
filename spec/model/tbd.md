
Consider a risk-meaure price \(p_{\text{risk}} \, Q64.96\).

> NOTE: \(p_{\text{risk}}\) is to be comparable with \(p \, (i \, (\sigma_{X96})) \, \in \,Q64.96\), we assume from now \(p_{\text{risk}}\) is exogenous

Given an "appropiate" distance function \(d \, (\cdot , \cdot )\), and a pair of sequences \( \{Q_{v}^{i}\}_{i=1}^{N}, \{ Q_{M}^{i}\}_{i=1}^N \, \forall_i  \, Q_{(\cdot)}^{i} > 0\):

\[
	\begin{aligned}
		\mathcal{Q}_{v}^{\Sigma} \,= \, \Big \{Q_{v}^{\Sigma} \, = \, \sum_{i=1}^N \, Q_{v}^{i}\, d(p_{\text{risk}},p \, (i \, (\sigma_{x96})) ) \, \mid \,Q_{v}^{\Sigma} \leq \sum_{i=1}^N \, \Delta Q_{M}^{i} \Big \}
	\end{aligned}
\]

Define:

\[
	\begin{aligned}
		Q_{M}^{\Sigma} \, \equiv \, \sum_{j=1}^{N} \, \Delta \, Q_{M}^{i}
	\end{aligned}
\]

The state-space rpt is given by: 

\[
	\begin{aligned}
		\text{state} \, \to \, \Big (Q_{v}^{\Sigma}\Big)_{\text{next}} \, = \, Q_{v}^{\Sigma} \, + \, \partial_{(M, v)}\,  \Delta \, Q_{M}^{\Sigma} : RAY (\text{ 1e27} \, \text{ precision})\\
 
	\end{aligned}
\]

> * \(\Delta \, Q_{M}^{\Sigma}\) is a exogenous flow:

Define:

\[
	\begin{aligned}
		\Delta \, Q_{v}^{\Sigma} \, &\equiv \, \partial_{(M, v)}\,  \Delta \, Q_{M}^{\Sigma}
	\end{aligned}
\]


And the admissible region:

\[
	\begin{aligned}
		\Delta \, Q_{v}^{\Sigma} \, \leq \, \frac{Q_{M}^{\Sigma}}{p_{\text{risk}}}
	\end{aligned}
\]


The state variables are:

\[
	\begin{aligned}
		\begin{bmatrix}
 			\text{totalDeposits}\, \to \, \sum_{j=1}^{N} \, Q_{M}^{i} \\
            \text{totalShares} \, \to \sum_{i=1}^N \, Q_{v}^{i} \\
			\text{riskWeightedShares} \, \to \sum_{i=1}^N \, Q_{v}^{i} \, d_i
		\end{bmatrix}
	\end{aligned}
\]


> Every time some position enters \(N \leftarrow  N + 1\) there is a risk measure \(d_N\) note this last is updated not per order event BUT as price changes or price of risk changes

Now we need to define the "admissibility" of \(d \, (\cdot, \cdot)\):

Since we have the accounting identity:

\[
	\begin{aligned}
		Q_{v}^{\Sigma} \, \equiv \, \sum_{i=1}^N \, Q_{v}^{i}
	\end{aligned}
\]


Then:
\[
	\begin{aligned}
		d \, \in \,[0,1]^{\text{Q64.96} \times \text{Q64.96}} \\
		\implies \\
		0 \, \leq \,  \forall_N \, \sum_{i=1}^N \, Q_{v}^{i}\, d(p_{\text{risk}},p \, (i \, (\sigma_{x96})) ) \, \leq \, \sum_{i=1}^N \, Q_{v}^{i}
	\end{aligned}
\]


| `d`    | `Q0.96` / X96 (`2^96`), clamp `≤ 2^96` | `uint128`/`uint160` | discount = shift `>>96`; keeps `Σ Qᵥⁱ·dᵢ ∈ [0, Σ Qᵥⁱ]` |
| `∂_(M,v)` / `Δ` | RAY (`1e27`), unsigned, round down | `uint256` | guard `Δ·p_risk ≤ Q_M^Σ` (no division); state ∈ `[Qᵥ^Σ, Qᵥ^Σ + Q_M^Σ/p_risk]` |

Questions:

- We need to get the EVM aware design space for \(d\) what numder representation better fits
- We need to get the EVM aware design space of \(\partial_{(M, v)}\) subject to the above:


Then we have:

\[
	\begin{aligned}
		(\Delta Q_M ,p_{\text{risk}}) \, \to \, (\Delta Q_M, \Delta Q_{v} )
	\end{aligned}
\]
