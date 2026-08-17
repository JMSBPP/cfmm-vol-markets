

import the base forms [\mathbf{e}_i / \mathbf{a}_{ij} / \mathbf{w}_{ij}](./INTEGRATION.md)

\[
	\begin{aligned}
		\mathbf{d} \, \mathbf{e}_i^{P} \, &= \, \sum_{j} \, \Big (\, \mathbf{a}_{ij}^{P} - \, \mathbf{a}_{ji}^{P}\, \Big )  \, \implies \, \mathbf{d} \, \pi \, = \, \sum_{(i,j)} \, \Big [\,\pi \, (j) \, - \, \pi \, (i) \, \Big] \, \mathbf{a}_{ij}^{P} \\
		\overbrace{\downarrow}^{\text{FTC}} & \\
		\\		
		\int_{\mathbf{a}_{ij}^{P}} \mathbf{d} \, \mathbf{e}_k^{P} \, = \, \int_{\partial \,\mathbf{a}_{ij}^{P}} \, \mathbf{e}_k^{P} \, = \int_{\mathbf{e}_{j}^{P} \, - \, \mathbf{e}_{i}^{P}} \, \mathbf{e}_k^{P} \, = \, \mathbf{w}_{kj}^{P} \, - \, \mathbf{w}_{ki}^{P}& 
	\end{aligned}
\]




\[
	\begin{aligned}
		\mathbf{d} \, (\pi^{(a)}\, \pi^{(b)}) \, &\overset{d}{\equiv} \, \mathbf{d} \, \pi^{(a)} \, \pi^{(b)} \, + \, \mathbf{d} \, \pi^{(b)} \, \pi^{(a)} \\
		&= \, \sum_{(i,j)}\, \Big [\, \pi^{(a)} \, (j) \, \pi^{(b)} \, (j) \, - \, \pi^{(a)} \, (i) \, \pi^{(b)} \, (i) \, \Big] \, \mathbf{a}_{ij}^{P}
	\end{aligned}
\]



Discrete **Calculus** <-> Directed Graphs **contains** `BinaryTrees`



> **Graded Leibniz.** The symmetric product rule above is the **grade-0 special case** of graded Leibniz \(\mathbf{d}(\alpha\beta)=(\mathbf{d}\alpha)\,\beta+(-1)^{r}\,\alpha\,(\mathbf{d}\beta)\) — it holds here because both \(\pi^{(a)},\pi^{(b)}\) are 0-forms (\((-1)^{0}=+1\)); the relation tag \(\overset{d}{\equiv}\) is the sanctioned Leibniz identity (\(\equiv^{d}\), NOTATION.md).

---

## Concept grounding (Forgy/Murota — symbols are graph-native, KEPT)

The coboundary \(\mathbf{d}\), the node/arc forms \(\mathbf{e}_i\)/\(\mathbf{a}_{ij}\), the incidence weight \(\mathbf{w}_{ij}\), the chain boundary \(\partial\) and the integral \(\int\) are the repo's own graph-native symbols; the discrete-exterior-calculus **concepts** are grounded in DDG: the coboundary \(\mathbf{d}:=\partial^{\mathsf t}\) (2.71), the structure equation \(\mathbf{d}\mathbf{e}_i=\sum_j(\mathbf{a}_{ij}-\mathbf{a}_{ji})\) (2.78), discrete Stokes / the FTC \(\int_S\mathbf{d}\alpha=\int_{\partial S}\alpha\) (3.123), and graded Leibniz (2.3). The FTC pairing values \(\mathbf{w}_{kj}-\mathbf{w}_{ki}\) are incidence weights; the Hodge metric \(\hat g/\ell^2\) is a *distinct* operator (related, not renamed-to). No Dirac bra-ket / braced-set cochain is imported.

## Economic Meaning

The coboundary \(\mathbf{d}\) turns a per-tick **stock** 0-form \(\pi\) (e.g. reserves or an LP position) into the **flow** 1-form \(\mathbf{d}\pi\) of tick-to-tick *differences* — the discrete price/quantity **change** carried across each arc of the pool's state graph. The discrete FTC \(\int_{\mathbf{a}_{ij}}\mathbf{d}\mathbf{e}_k=\int_{\partial\mathbf{a}_{ij}}\mathbf{e}_k=\mathbf{w}_{kj}-\mathbf{w}_{ki}\) says integrating that change along an arc recovers the **endpoint difference** — the discrete accounting identity behind net-flow / LP P&L over a tick path. Graded Leibniz is the **product rule for composite positions** (e.g. a mark = price 0-form \(\times\) quantity 0-form): the change of a product decomposes into the changes of its factors, which is exactly how fee accrual and impermanent-loss terms separate in the discrete apparatus.
