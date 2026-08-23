import the discrete BS/Itô lattice [\mathbf{e}_{(i,j)} / \mathbf{a}_{(i,j)(\cdot)} / \mathbf{d}](./BINARY_TREES.md)
 
import [INTEGRATION](./INTEGRATION.md)


\[
	\begin{aligned}
		P_X(i)=\lambda^{i} \, = \, \mathbf{e}_i^{P}\, := \, \lambda^{i} \\
		\implies \\
		\begin{cases}
		     P_X(i{+}1)=\lambda\,P_X(i) \\
			 & \overset{i=\ln P_X/\ln\lambda}{\implies} \, \sigma=\sigma_X=\dfrac{\ln\lambda}{\sqrt{\Delta t}}\\
			 P_X(i{-}1)=P_X(i)/\lambda
		\end{cases}
	\end{aligned}
\]

## Financial 0-forms

\[
\pi=\sum_{i,j}\pi(i,j)\,\mathbf{e}_{(i,j)}\ (\text{claim}=V),\quad
B=\sum B(i,j)\,\mathbf{e}_{(i,j)}\ (\Delta B=[e^{r\Delta t}-1]B,\ 6.9),\quad
P_X(i)=\lambda^{i},\quad X(i,j)\ (\text{reserve}),\quad
\Pi=\sum\Pi(i,j)\,\mathbf{e}_{(i,j)}
\]

Holdings: \(\alpha\) (claim), \(\beta\) (bond), and the **asset holding** \(\Delta_S\equiv\Delta X\) — the hedge **is** the trading flow on the reserve (Forgy's stock holding \(\Delta\) = our reserve increment \(\Delta X\)).

## ① Change of variables → \(\mathbf{d}P_X,\mathbf{d}t\) (Forgy 6.1–6.9)

\[
\mathbf{d}P_X=\sum\big[\Delta_{+}P_X\,\mathbf{a}_{(i,j)(i+1,j+1)}+\Delta_{-}P_X\,\mathbf{a}_{(i,j)(i-1,j+1)}\big],\qquad
\Delta_{\pm}P_X=P_X(i)\,(\lambda^{\pm1}-1)
\]
\[
\mathbf{d}\pi=\sum\frac{\Delta\pi}{\Delta P_X}\,\mathbf{d}P_X+(\cdots)\,\mathbf{d}t\ \ (6.7),\qquad
\mathbf{d}B=\sum\frac{\Delta B}{\Delta t}\,\mathbf{d}t\ \ (6.8)
\]

## ② Self-financing (6.10) · ③ No-arbitrage (6.11)

\[
\mathbf{d}\Pi=\alpha\,\mathbf{d}\pi+\Delta X\,\mathbf{d}P_X+\beta\,\mathbf{d}B,
\qquad
\Pi(i,j)=\Pi(0,0)\,e^{jr\Delta t}\ \Rightarrow\ \mathbf{d}\Pi\ \text{has no}\ \mathbf{d}P_X\ \text{term}
\]

## Δ-hedge (6.13) — the trading flow that cancels \(\mathbf{d}P_X\)

\[
\Delta X(i,j)=-\,\alpha(i,j)\,\frac{\Delta\pi(i,j)}{\Delta P_X(i,j)}
\]

## Discrete Black–Scholes = CRR (6.15, 6.18)

\[
\pi(i,j)=e^{-r\Delta t}\big\{\,q\,\pi(i{+}1,j{+}1)+(1-q)\,\pi(i{-}1,j{+}1)\,\big\},\qquad
q=\frac{\lambda e^{r\Delta t}-1}{\lambda^{2}-1}\ (\text{const}),\quad
\tilde r=\frac{e^{r\Delta t}-1}{\Delta t}
\]

The geometric grid \(P_X=\lambda^{i}\) makes the \(\lambda^{i-1}\) cancel in \(q=\frac{P_X(i)e^{r\Delta t}-P_X(i-1)}{P_X(i+1)-P_X(i-1)}\), so \(q\) is \((i,j)\)-independent.

## σ-bridge & absorbed φ* primitives (FOUND-02/03)

\(\Delta t=(\Delta i)^2\Rightarrow[\mathbf{d}i,i]=\sigma^2\mathbf{d}t\) (DSC graph-commutator), \(\sigma=\sigma_X=\ln\lambda/\sqrt{\Delta t}\). Upstream home for the φ* discrete primitives (FOUND-03 repoint target): \(i_X=i\) (tick), \(\Delta_{i_X}=\) tick step \(\ln\lambda\), \(\sigma_X=\) lattice \(\sigma\), \(L_K/\ell=L=\sum L(i,j)\,\mathbf{e}_{(i,j)}\).

## Adaptive fee & realized variance (FOUND-03 in-tree primitives)

A tick path to horizon \(\tau\): \(\mathbf{I}_X(\tau):=(i_X(s_1),\dots,i_X(\tau))\) over
\(s\) (block/time). Its **time-weighted realized variance** (the Algebra
`VolatilityOracle._volatilityOnRange` form, with \(\text{tick}=i_X\)):

\[
\overline{i_X}=\frac{1}{T}\sum_{\tau-T\le s\le\tau} i_X(s)\,\Delta s,\qquad
\sigma_X^{2}\big(\mathbf{I}_X(\tau)\big)=\frac{1}{T}\sum_{\tau-T\le s\le\tau}
\big(i_X(s)-\overline{i_X}\big)^{2}\Delta s,\qquad T=\sum\Delta s
\]

This is the **empirical** tick-level dispersion the pool observes (realized vol
\(\sigma_X=\sqrt{\sigma_X^2}\)); it is **calibrated** to — not dimensionally identical with —
the lattice parameter \(\sigma_X=\ln\lambda/\sqrt{\Delta t}\) (§σ-bridge): the grid is pinned so
its per-step vol matches the realized estimate over the window.

The **volatility-adaptive fee surcharge** (a sum of logistics in the realized \(\sigma_X\);
\(\alpha_j,\gamma_j>0\) ⟹ monotone-increasing, bounded in \((0,\sum_j\alpha_j)\);
\(\beta_j\)=vol thresholds, \(\gamma_j\)=steepness):

\[
	\phi_{Z}\big(\,;\sigma_X\big)=\sum_{j}\frac{\alpha_j}{1+\exp\!\big((\beta_j-\sigma_X)/\gamma_j\big)}
\]

The **total per-swap fee** on the trading flow \(\Delta X\) is the additive composition (the
discrete twin of Algebra's `baseFee + adaptiveFee`):

\[
\phi(\,;\sigma_X)=\bar\phi^{\star}+\phi_{Z}(\,;\sigma_X)
\]

— the base-fee **floor** \(\bar\phi^{\star}\) (the φ* of the Economic-Meaning note below) PLUS the
adaptive surcharge \(\phi_{Z}\). In-tree home for \(\phi_{Z}\) (the SHREVE \(\phi_{Z}\)
repoint) and the realized \(\sigma_X^2\) estimator (the IMPLIED_VOLATILITY repoint).

## Economic Meaning

Discrete **Black–Scholes / CRR pricing engine** for the CFMM: the LP-claim \(\pi\) is **replicated** (\(\overset{R}{\equiv}\)) by trading the asset — hedge \(\Delta X=-\alpha\,\Delta\pi/\Delta P_X\) (the trading flow on the reserve) — and **bond-financed** (\(\overset{F}{\equiv}\)) via \(\Pi=\Pi_0 e^{jr\Delta t}\). The risk-neutral \(q=(\lambda e^{r\Delta t}-1)/(\lambda^2-1)\) is fixed by the tick multiplier \(\lambda\), hence by \(\sigma=\sigma_X\). The φ* base-fee \(\bar\phi^{\star}\) sits *underneath* this \(q\)-priced claim — the fee charged on the trading flow \(\Delta X\) that drives \(P_X\). Relations glossed in NOTATION (cfmm-theory KB — not vendored).
