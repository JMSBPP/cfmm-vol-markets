Consider the price and liquidity *base-nodes*:

\[
	\begin{aligned}
		\mathbf{e}_{i}^{P} := \lambda^{i} \, \iff \, \int_{\mathbf{e}_{i}^{P}} \, \mathbf{e}_{j}^{P} \, = \, \mathbf{w}_{ij}^{(P)}\\
		\mathbf{e}_{i}^{\ell} := \xi^{i} \, \iff \, \int_{\mathbf{e}_{i}^{\ell}} \, \mathbf{e}_{j}^{\ell} \, = \, \mathbf{w}_{ij}^{(\ell)}
	\end{aligned}
\]

> The pairing \(\int_{\mathbf{e}_i}\mathbf{e}_j = \mathbf{w}_{ij}\) is the **primitive** defining the incidence weight \(\mathbf{w}_{ij}\) — the graph-native weighted/Markov deformation of the canonical node–node pairing (concept: DDG p.16, 2.69/2.73). Its **unweighted limit** is the Iverson bracket \(\mathbf{w}_{ij} = [i=j]\) (\(1\) if \(i=j\), else \(0\)).


\[
	\begin{aligned}
		\mathbf{e}_{i}^{P} \, \mathbf{e}_{j}^{P} \, &= \, \mathbf{w}^{P}_{ij} \, \mathbf{e}_{j}^{P}
	\end{aligned}
\]

> Unweighted limit \(\mathbf{w}^{P}_{ij}=[i=j]\) recovers the idempotent \(\mathbf{e}_{i}^{P}\mathbf{e}_{j}^{P}=[i=j]\,\mathbf{e}_{j}^{P}\) (concept: DDG 2.80).


# 0-FORMS

The stock-like variables:
\[
	\begin{aligned}
		\int_{\mathbf{e}_{j}^{P}} \, \pi \, &= \, \pi \, (j) \, \implies \, \pi \, &= \, \sum_{i} \, \pi \, (i) \, \mathbf{e}_{i}^{P} \\
		& \, &= \, \sum_{i} \, \pi \, (i) \, \int_{\mathbf{e}_{j}^{P}} \, \mathbf{e}_{i}^{P} \, =  \sum_{i} \, \pi \, (i)\, \mathbf{w}_{ij}^{P} = \pi \, (j)\\
		
		\int_{\mathbf{e}_{j}^{\ell}} \, L \, &= \, L \, (j) \, \implies \, L \, &= \, \sum_{i} \, L \, (i) \, \mathbf{e}_{i}^{\ell} 
	\end{aligned}
\]

For \(\mathbf{I} \, = \{1, \cdots , N\}\):

\[
	\begin{aligned}
		\prod_{i \, \in \mathbf{I}} \, L_i \, &= \, \sum_{i \, \in \mathbf{I}} \bigg (\prod_{j \, \in \mathbf{I}} \, L_j \, (i)\bigg) \, \mathbf{e}_i^{P}
	\end{aligned}
\]

# 1-FORMS

Conside the *base-arcs*:

\[
	\begin{aligned}
		\mathbf{a}_{ij}^{P} := \lambda^{ij} \, \iff \, \int_{\mathbf{a}_{i_1i_2}^{P}} \, \mathbf{a}_{i_3i_4}^{P} \, = \, \mathbf{w}_{i_1i_3}^{(P)} \, \mathbf{w}_{i_2i_4}^{(P)}\\
		\mathbf{a}_{ij}^{\ell} := \xi^{ij} \, \iff \, \int_{\mathbf{a}_{i_1i_2}^{\ell}} \, \mathbf{a}_{i_3i_4}^{\ell} \, = \, \mathbf{w}_{i_1i_3}^{(\ell)} \, \mathbf{w}_{i_2i_4}^{(\ell)}\\
	\end{aligned}
\]

> *0-forms and 1-forms DO NOT **COMMUTE** ON product

\[
	\begin{aligned}
		\mathbf{a}_{ij}^{(\cdot)} \, \mathbf{e}_k^{(\cdot)} \, &= \, \mathbf{w}_{jk}^{(\cdot)} \, \mathbf{a}_{ij}^{(\cdot)} \
		\quad \wedge \quad
		\mathbf{e}_k^{(\cdot)} \, \mathbf{a}_{ij}^{(\cdot)}= \, \mathbf{w}_{ki}^{(\cdot)} \, \mathbf{a}_{ij}^{(\cdot)} \\
		\\
		(\text{stock}) \, \mathbf{a}_{ij}^{(\cdot)}  \, &= \, (\text{stock}) \, (i) \, \mathbf{a}_{ij}^{(\cdot)} \
		\quad \wedge \quad
		\mathbf{a}_{ij}^{(\cdot)}\, (\text{stock}) \, \, = \, (\text{stock}) \, (j) \, \mathbf{a}_{ij}^{(\cdot)}

	\end{aligned}
\]


The flow-like variables:

\[
	\begin{aligned}
		\int_{\mathbf{a}_{ij}^{P}} \, \mathbf{V} \, = \, \mathbf{V}_i \, (j) \\
		\int_{\mathbf{a}_{ij}^{\ell}} \, \mathbf{\Delta \, L} \, = \, \mathbf{\Delta \, L}_i \, (j)
	\end{aligned}
\]



(Here \(\mathbf{\Delta \, L}\) is the per-arc liquidity **increment** — a flow 1-form — not the Hodge–de Rham Laplacian \(\Delta\).)

---

## Concept grounding (Forgy/Murota — symbols are graph-native, KEPT)

The symbols \(\mathbf{e}_i\) (node 0-form), \(\mathbf{a}_{ij}\) (arc 1-form), \(\mathbf{w}_{ij}\) (incidence weight) and the integration pairing \(\int\) are the repo's own graph-native notation; the discrete-exterior-calculus **concepts** they instantiate are grounded in DDG: node basis 0-form (2.15) and its evaluation/pairing (2.69/2.73), the idempotent product (2.80), the arc 1-form (2.19), and the non-commuting node–arc products (2.12–2.13). No Dirac bra-ket / braced-set cochain is imported.

## Economic Meaning

The price/liquidity base-nodes \(\mathbf{e}_i^{P}\) / \(\mathbf{e}_i^{\ell}\) index the **tick states** of a CFMM pool (price ticks \(P\), liquidity ticks \(\ell\)). The 0-form \(\pi\) is a **stock** (reserves / LP position held *at* a tick); the 1-form \(\mathbf{V}\) (and \(\mathbf{\Delta\,L}\)) is a **flow** (a per-tick trade or liquidity increment *across* an arc). The incidence weight \(\mathbf{w}_{ij}\) couples ticks \(i,j\) on the pool's state graph — in the unweighted limit \([i=j]\) it is the diagonal "stay-at-tick" pairing; a non-trivial \(\mathbf{w}_{ij}\) encodes the Markov/metric structure of how reserves and flows redistribute across ticks. Integration \(\int_{\mathbf{e}_i}\) / \(\int_{\mathbf{a}_{ij}}\) reads off the stock at a tick and the flow along an arc — the discrete accounting primitives the fee/IL apparatus is built on.
