import the tree substrate [\mathbf{e}_{(i,j)} / \mathbf{a}_{ij}](./BINARY_TREES.md)


\[
	\begin{aligned}
		X \, &= \, \sum_{(i,j)} \, X \, (i,j) \, \mathbf{e}^{(\cdot)}_{(i,j)} \, \implies \, \Delta \, X \, = X \, (i+1,j+1)\, - \, X \, (i,j)
	\end{aligned}
\]

And:

\[
	\begin{aligned}
		\Delta \, X \, (i,j) \, = \, X \, (i+1,j+1) - X \, (i-1,j+1)
	\end{aligned}
\]


\[
	\begin{aligned}
		d\, X \, (i,j) &= \, \Delta X \Big [ \, \mathbf{a}_{(i,j)(i+1, j+1)}^{P} \, - \, \mathbf{a}_{(i,j)(i-1, j+1)}^{P}\,\Big] \, \implies \, \mathbf{d} \, X \, = \, \sum_{(i,j)} \, d \, X \, (i,j)
	\end{aligned}
\]

# PARAMETERS



# STOCKS

---

## Notes & concept grounding (graph-native symbols KEPT)

- **`X` is the reserve / state 0-form** `X = \sum_{(i,j)} X(i,j)\,\mathbf{e}_{(i,j)}` — the asset **quantity** in the CFMM (the DCA M-convex variable). It is a function *on* the tree, **NOT** the lattice space axis: the lattice axes are the **tick `i` = log-price** (`i = ln P_X/ln λ`, the diffusion direction — see [BINARY_TREES](./BINARY_TREES.md)) and time `j`. `\mathbf{d}X` is the **change 1-form** of the reserve; `d\,X(i,j)` is its per-node contribution (`\mathbf{d}X = \sum_{(i,j)} d\,X(i,j)`).
- **`Δ\,X = X(i+1,j+1) − X(i,j)`** is the forward reserve increment — the **trading flow** on the asset holding — NOT the Hodge–de Rham Laplacian `Δ (= ±D_±²)`.
- The price/log-price **diffusion** and the `σ=σ_X` bridge — the DSC graph-commutator `[\mathbf{d}i,i]=σ²\mathbf{d}t` — live on the **tick `i`** (BINARY_TREES), **not** on the reserve `X`.
- The linearizing change-of-coordinates `z = 1/√P_X` is a **later** construction — **deferred**, not used here.
- No Dirac bra-ket / braced-set cochain is imported.

## Economic Meaning

`X` is the **reserve / state variable** — the asset quantity in the CFMM (the DCA M-convex variable) — carried on the tree nodes; the quantity whose variation drives the claim 0-form `π` and the liquidity `L`. Its increment `Δ\,X` is the **trading flow** on the asset holding, and `\mathbf{d}X` the change 1-form. Crucially, `X` establishes — directly, or **implicitly via a differential equation** (the CFMM trading function) — the **functional relations** `π(X)` and `L(X)`. These are the objects later handed to **discrete convex analysis**: `π(X)`, `L(X)` become the M♮-/L♮-convex functions (and conjugates) of the DCA layer — the reserve `x` ↔ price `p` duality — so this file bridges the discrete-geometry tree to the convex-analytic structure downstream. The price/log-price diffusion (and the `σ=σ_X` bridge) live on the **tick `i`** (see BINARY_TREES); `X` is the **quantity** axis.
