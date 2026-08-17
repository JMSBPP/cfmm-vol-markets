
import the base forms [\mathbf{e}_i / \mathbf{a}_{ij} / \mathbf{w}_{ij}](./INTEGRATION.md)

import the coboundary [\mathbf{d}](./DIFFERENTIATION.md)


\[
	\begin{aligned}
		\mathbf{e}_{(i,j)}^{P} \, \overset{D}{\equiv} \, \mathbf{e}_{i}^{P} \, = \, \sum_{(i,j)} \, \mathbf{e}_{i}^{P} \, \mathbf{e}_{(i,j)}^{P}
	\end{aligned}
\]


# 0-FORMS
\[
	\begin{aligned}
		\pi \, &= \, \sum_{(i,j)} \, \pi \, (i,j) \, \mathbf{e}_{(i,j)}^{P}
	\end{aligned}
\]

## DIFFERENTIATION 

\[
	\begin{aligned}
		\mathbf{d}\, \pi \, &= \, \sum_{(i,j)} \, \Big [ \, \pi \, (i+1, j+1)\, - \pi \, (i, j)\, \Big] \, \mathbf{a}_{(i,j)(i+1,j+1)}^{P}\, +  \, \sum_{(i,j)} \, \Big [ \, \pi \, (i-1, j+1)\, - \pi \, (i, j)\, \Big]\, \mathbf{a}_{(i,j)(i-1,j+1)}^{P} \\
		\\
		&= \, \Big (\partial_{t}\, \pi  + \frac{1}{2} \, \partial_{i}^2 \, \pi \, \Big) \, \mathbf{d}\, t \, + \, (\partial_{i} \, \pi) \, \mathbf{d}\, i
	\end{aligned}
\]



Where:

\[
	\begin{aligned}
		\begin{cases}
			\partial_t \, \pi \, = \, \sum_{(i,j)}\, \Big [ \, \frac{\pi \, (i, j+1) \, - \, \pi\, (i,j) }{\Delta \, t}\, \Big] \,  \mathbf{e}_{(i,j)}^{P}\\
			\partial_i \, \pi \, = \, \sum_{(i,j)}\, \Big [ \, \frac{\pi \, (i+1, j+1) \, - \, \pi\, (i-1,j+1) }{2\, \Delta \, i}\, \Big] \,  \mathbf{e}_{(i,j)}^{P} \\
			\partial^2_i \, \pi \, = \, \sum_{(i,j)}\, \Big [ \, \frac{\pi \, (i+1, j+1) \, - \,  \, 2 \, \pi \, (i,j+1) \, + \, \pi\, (i-1,j+1) }{ (\Delta \, i)^2}\, \Big] \,  \mathbf{e}_{(i,j)}^{P}
		\end{cases}
	\end{aligned}
\]


If \(\Delta t \, = (\Delta i)^2\):

\[
	\begin{aligned}
		\partial_{t}\, \pi \, + \,  \frac{1}{2} \, \partial^2_i \, \pi \overset{\Delta t \, = (\Delta i)^2}{=} \, \Big [\, \frac{\pi \, (i+1, j+1) \, - \, 2\, \pi \, (i,j) \, + \,\pi \, (i-1,j+1)}{2 \, \Delta \, t}\, \Big] \, \mathbf{e}_{(i,j)}^{P} 
	\end{aligned}
\]




# 1-FORMS


\[
	\begin{aligned}
		\mathbf{V} \, &= \, \sum_{(i, j)} \Big [\, \mathbf{V}_{+} \, (i,j)\, \mathbf{a}_{(i,j)(i+1, j+1)}^{P} \,  \Big] \, + \, \sum_{(i, j)} \, \Big [\mathbf{V}_{-} \, (i,j)\, \mathbf{a}_{(i,j)(i-1, j+1)}^{P}\, \Big]
	\end{aligned}
\]




---

## Concept grounding — FOUND-DBS-01 (Forgy discrete stochastic calculus; symbols graph-native, KEPT)

The decomposition \(\mathbf{d}\pi=(\partial_t+\tfrac12\partial^2_i)\pi\,\mathbf{d}t+(\partial_i\pi)\,\mathbf{d}i\) is the **discrete Itô formula** (concept: DSC §5, eq 5.16). The space axis is the **tick \(i\) = log-price** (\(i=\ln P_X/\ln\lambda\), see below) — NOT the reserve. The lattice spacing \(\Delta t=(\Delta i)^2\) makes the DSC graph-commutator \([\mathbf{d}i,i]=\sigma^2\,\mathbf{d}t\) with **\(\sigma=\sigma_X\)** (per ARBITRATION §σ-identity), collapsing drift+diffusion to the discrete **heat / Black–Scholes operator** \(\partial_t\pi+\tfrac12\sigma^2\partial^2_i\pi\).

**Forgy DOES derive the discrete Black–Scholes equation** (DSC §6.1, eq 6.15) and shows it equals the **CRR** binomial formula (eq 6.18) — see `FINANCE.md`. The *continuous* BS **PDE** is the \(\Delta t\to0\) limit (a derived continuum object); the *discrete* BS equation is exact on this tree. Relation operators (\(\overset{D}{\equiv}\) = *is defined*, etc.) are glossed in `cfmm-options/notes/NOTATION.md`.

### Geometric price grid (CFMM ticks ⟹ CRR)

The price base-node \(\mathbf{e}_i^{P}:=\lambda^{i}\) makes the asset price **geometric in the tick**: \(P_X(i)=\lambda^{i}\) ⟹ up-move \(\times\lambda\), down-move \(\div\lambda\) (\(u=\lambda,\ d=1/\lambda\)). Hence the tick \(i=\ln P_X/\ln\lambda\) is the discretized **log-price** (the diffusion axis above), the risk-neutral up-probability \(q=\dfrac{\lambda e^{r\Delta t}-1}{\lambda^{2}-1}\) is **constant**, and \(\sigma=\sigma_X=\dfrac{\ln\lambda}{\sqrt{\Delta t}}\) (log-tick size per \(\sqrt{\text{time}}\)).

## Economic Meaning

On the recombining binary tree, \(\pi(i,j)\) is an **option-value / contingent-claim 0-form** at price-tick \(i\) (price \(P_X=\lambda^i\)), time-step \(j\). The discrete Itô formula splits its one-step change into a **drift** (\(\partial_t+\tfrac12\sigma^2\partial^2_i\)) plus a **diffusion** (\(\partial_i\pi\)) along the **tick / log-price** axis; under \(\Delta t=(\Delta i)^2\) this *is* the **discrete Black–Scholes / CRR pricing operator** — the lattice on which the fee / replication apparatus values claims. The reserve \(X(i,j)\) (the DCA quantity) and liquidity \(L(i,j)\) are **0-forms on this tree**, NOT the diffusion axis. \(\mathbf{V}\) is the per-arc **trade / hedge flow** 1-form (\(\mathbf{V}_{+}\) on the up-move arc \((i,j)\!\to\!(i+1,j+1)\), \(\mathbf{V}_{-}\) on the down-move) — the discrete self-financing hedge whose cost the claim \(\pi\) must equal (\(\overset{F}{\equiv}\), *is financed by*).
