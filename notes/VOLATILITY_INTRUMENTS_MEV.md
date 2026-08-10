
import [MEV](feat/plank::notes/VOLATILITY_INSTRUMENTS.md)

> **Numbering.** Blocks in this document continue the sequence of
> `VOLATILITY_INSTRUMENTS.md` (one shared corpus). Next unused:
> `Convention 10`, `Definition 37`, `Theorem 36`, `Proposition 14`, `Rule 14`.
> Those numbers are reserved here and are not to be reused independently in the
> entry-point doc. (`Proposition` corrected from an earlier `15+` reservation:
> the entry-point doc's Propositions run 2–11, so 12 is next and 12–14 were
> orphaned by the error.)

**Convention 7 (Event time) [M11].** The iteration index is the **swap event**, not the
block and not calendar time:

\[
	\begin{aligned}
		t \, \to \, t+1 \; := \; \text{event swap}
	\end{aligned}
\]

**Convention 8 (Liquidity axis) [M18].**

\[
	\begin{aligned}
		L_{\sigma} \; &\equiv \; \Delta Q_v^{\star} && \text{(volatility axis)} \\
		L, \; \bar L \; & && \text{(price axis)}
	\end{aligned}
\]

\[
	\begin{aligned}
		L_{\sigma}(i_K) \; = \; L_{\sigma}\,\ell(\xi^{\star},\iota;i_K),
		\qquad
		\sum_{i_K} L_{\sigma}(i_K) \; = \; \Delta Q_v^{\star},
		\qquad
		\sum_{i_K}\ell \; = \; 1
	\end{aligned}
\]

\[
	\begin{aligned}
		L(i_K) \; = \; \bar L\,\ell(\xi,\iota;i_K),
		\qquad
		\frac{\partial L(i_K)}{\partial \pi^{\phi}} \; = \; \ell(\xi,\iota;i_K)\,\frac{\partial \bar L}{\partial \pi^{\phi}}
	\end{aligned}
\]

**Definition 32 (Event-time plant) [M11].**

\[
	\begin{aligned}
		x &= 
		\begin{bmatrix}
			\phi \\
			\nu \\
			\pi^{\phi} \\
			\pi^{\phi} - \pi^{\text{LVR}}
		\end{bmatrix} \, \quad 		u_{\text{ex}}= 
		\begin{bmatrix}
			\Delta Q_X \\
			\Delta Q_M \\
			\sigma^2 \, (i (t))
		\end{bmatrix}
		\, \quad y = \begin{bmatrix}
			\pi^\sigma \\
			\widehat\pi^\sigma\
		\end{bmatrix} \quad u_{\text{en}} = \, \begin{bmatrix} \tau_{\text{MEV}} \\ \phi_M \\ \phi_X \end{bmatrix} \quad \Theta_{\sigma} = \begin{bmatrix} \sigma_K^2 \\ \#_{\sigma} \\ s_{\upsilon}\\ \Delta Q_v^{\star}\end{bmatrix} 
	\end{aligned}
\]

**Definition 33 (Replication residual) [M19].**

\[
	\begin{aligned}
		e^{\sigma} \, &= \, \bigl|\pi^{\sigma} - \widehat \pi^{\sigma}\bigr|
	\end{aligned}
\]

**Definition 34 (State-space representation) [M11].**

\[
	\begin{aligned}
		\begin{cases}
			x_{t+1} &= \, \partial_{(t+1,t)} \, x_t \, + \, \partial_{(x,u)}\, u_t \\
			y_t &= \, \partial_{(y,x)}\, x_t \, + \, \partial_{(y,u)} \, u_t
		\end{cases}
	\end{aligned}
\]


**Definition 35 (Monoid gradient) [M12].**

\[
	\begin{aligned}
		\nabla \phi \; \equiv \; \begin{bmatrix} (1-\phi_X)(1- \tau_{\text{MEV}}) \\ (1 - \phi_M)(1 - \tau_{\text{MEV}}) \\ (1- \phi_X)( 1 - \phi_M)\end{bmatrix}
	\end{aligned}
\]

**Convention 9 (Gate derivative — composed, never bare) [M25].**

\[
	\begin{aligned}
		\frac{\partial \phi}{\partial \nu} \; &\equiv \; \frac{\partial \phi}{\partial \phi_X}\,\frac{\partial \phi_X}{\partial \nu}
		\; = \; (1-\phi_M)(1-\tau_{\text{MEV}})\,\frac{\partial \phi_X}{\partial \nu} \\[6pt]
		\frac{\partial \phi_X}{\partial \nu} \; &= \; \text{DOC Definition 18 (bare)}
	\end{aligned}
\]

**Rule 13 (Fee schedule and standing assumptions) [M11].**

\[
	\begin{aligned}
		\phi_X (t) \; &= \; \Phi \, (\Theta_{\phi}; \sigma (i (t)), \nu (t)) \\
		\phi_M (t) \; &= \; \bar \phi_M \qquad \forall t \\
		(\beta_j , \gamma_j) , \; (\beta_R, \gamma_R, \alpha_R) \; &\text{ fixed} \qquad \forall t
	\end{aligned}
\]

**Theorem 29 (The monoid path is direct) [M12].**

\[
	\begin{aligned}
		\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\bigg|_{\phi_M,\,\phi_X} \; = \; (1-\phi_M)(1-\phi_X) \; > \; 0
		\qquad (\phi_M, \phi_X < 1)
	\end{aligned}
\]

**Theorem 30 (Path decomposition) [M20].**

\[
	\begin{aligned}
		\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}}
		\; = \;
		\underbrace{\frac{\partial \widehat\pi^{\sigma}}{\partial \phi}\,\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\bigg|_{\phi_M,\,\phi_X}}_{\text{direct}}
		\; + \;
		\underbrace{\frac{\partial \widehat\pi^{\sigma}}{\partial \phi}\,\frac{\partial \phi}{\partial \nu}\,\frac{\partial \nu}{\partial \tau_{\text{MEV}}}}_{\text{gate}}
	\end{aligned}
\]

**Proposition 12 (Kernel differentiation) [M20].** *Under (A1).*

\[
	\begin{aligned}
		\text{(A1)} \qquad \pi^{\phi} \; \to \; \widehat\pi^{\sigma} \quad \text{only via} \quad L
	\end{aligned}
\]

\[
	\begin{aligned}
		\widehat\pi^{\sigma} \; &= \; \sum_{i_K} L (i_K) \, \pi^{l} \, (\sigma \, (i_K; \cdot)) \\[4pt]
		\frac{\partial \widehat\pi^{\sigma}}{\partial \pi^{\phi}} \; &\overset{\text{(A1)}}{=} \; \sum_{i_K} \, \frac{\partial L (i_K)}{\partial \pi^{\phi}} \, \pi^{l} \, (\sigma \, (i_K; \cdot)) \\[4pt]
		\frac{\partial \widehat\pi^{\sigma}}{\partial L (i_K)} \; &= \; \pi^{l} \, (\sigma \, (i_K; \cdot))
	\end{aligned}
\]


**Theorem 31 (The section sum is ill-posed) [M13].**

\[
	\begin{aligned}
		(\phi_M, \phi_X, \tau_{\text{MEV}}) \; &\longmapsto \; \phi
		\qquad \text{is a submersion } \mathbb{R}^3 \to \mathbb{R} \\[4pt]
		\Longrightarrow \quad \frac{\partial \phi_M}{\partial \phi}, \; \frac{\partial \phi_X}{\partial \phi} \; &\text{ not simultaneously defined} \\[4pt]
		\Longrightarrow \quad \frac{\partial \phi_M}{\partial \phi}\,\Delta Q_M \, + \, p_{(\eta,\Delta_i)}\,\frac{\partial \phi_X}{\partial \phi}\,\Delta Q_X \; &\text{ has no section-independent value}
	\end{aligned}
\]



**Hypothesis (H1) [M25].**

\[
	\begin{aligned}
		\frac{\partial \bar L}{\partial \pi^{\phi}} \; > \; 0
	\end{aligned}
\]

**Hypothesis (H2) [M18].**

\[
	\begin{aligned}
		\bar{\mathcal{G}}_{(\nu, \lambda_{\text{MEV}})} \; := \; \frac{\partial \nu}{\partial \lambda_{\text{MEV}}} \; > \; 0
	\end{aligned}
\]

**Definition 36 (Tax program) [M19].**

\[
	\begin{aligned}
		&\min_{\tau_{\text{MEV}} \in [0,1]} \; \Bigl(\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}}\Bigr)^{\!2}
		\qquad \text{s.t.} \qquad \pi^{\sigma} \; = \; \widehat\pi^{\sigma} \\[6pt]
		&\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}} \; = \; 0
	\end{aligned}
\]

**Proposition 13 (Corrected law) [M24].** *All of $\phi_X$, $\partial\phi_X/\partial\nu$, $\partial\nu/\partial\tau_{\text{MEV}}$ evaluated at $\nu(\tau^{\star}_{\text{MEV}})$. $\partial\nu/\partial\tau_{\text{MEV}} < 0$ rests on $(H2)$ — UNDISCHARGED. The slot is the BARE gate derivative, per `MevTaxProgram.hasDerivAt_phiTot`; the monoid Jacobian is carried separately.*

\[
	\begin{aligned}
		\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}} \; = \; 0
		\quad &\Longleftrightarrow \quad
		\tau^{\star}_{\text{MEV}} \; = \; 1 \; + \; \frac{1-\phi_X}{\bigl(\partial\phi_X/\partial\nu\bigr)\,\bigl(\partial\nu/\partial\tau_{\text{MEV}}\bigr)}
		\qquad \Bigl[\bigl(\partial\phi_X/\partial\nu\bigr)\,\bigl(\partial\nu/\partial\tau_{\text{MEV}}\bigr) \neq 0\Bigr]
	\end{aligned}
\]

\[
	\begin{aligned}
		0 \; < \; \frac{\partial\phi_X}{\partial\nu},
		\qquad \frac{\partial\nu}{\partial\tau_{\text{MEV}}} \; < \; 0,
		\qquad \phi_X \; < \; 1
		\quad &\Longrightarrow \quad
		\begin{cases}
			\tau^{\star}_{\text{MEV}} \; < \; 1 \\[4pt]
			\tau^{\star}_{\text{MEV}} \; > \; 0 \; \Longleftrightarrow \; 1-\phi_X \; < \; \bigl|\bigl(\partial\phi_X/\partial\nu\bigr)\,\bigl(\partial\nu/\partial\tau_{\text{MEV}}\bigr)\bigr|
		\end{cases}
	\end{aligned}
\]

**Theorem 32 (LVR cancellation) [M25].** *Under (A1) and DOC Proposition 9.*

\[
	\begin{aligned}
		\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}}
		\; &= \; K \cdot \Bigl[\,(1-\phi_M)(1-\phi_X) \; + \; \frac{\partial \phi}{\partial \nu}\,\frac{\partial \nu}{\partial \tau_{\text{MEV}}}\,\Bigr] \\[8pt]
		K \; &= \; \Bigl[\sum_{i_K} \frac{\partial L(i_K)}{\partial \pi^{\phi}}\,\pi^{l}(\sigma(i_K;\cdot))\Bigr]
		\cdot \Bigl[\pi^{\mathrm{LVR}}\Bigl(-\frac{\partial \mathbb{P}_{\Delta_{\text{ARB}}}}{\partial \phi}\Bigr)\Bigr] \\[8pt]
		K \; &> \; 0
		\qquad \bigl[(H1),\; \pi^{l} > 0,\; \pi^{\mathrm{LVR}} > 0,\; \sigma > 0\bigr]
	\end{aligned}
\]

**Theorem 33 (Two channels to $\partial\nu/\partial\tau_{\text{MEV}}$) [M26].**
*Route (ii) requires (a); the CES boundary case is OPEN — see PR-REGION.*

\[
	\begin{aligned}
		\text{(i)} \quad \frac{\partial \nu}{\partial \tau_{\text{MEV}}}
		\; &= \; \bar{\mathcal{G}}_{(\nu,\lambda_{\text{MEV}})}\,\frac{\partial \lambda_{\text{MEV}}}{\partial \tau_{\text{MEV}}}
		\; \leq \; 0 \qquad \bigl[(H2)\bigr] \\[8pt]
		\text{(ii)} \quad \frac{\partial \nu}{\partial \tau_{\text{MEV}}}
		\; &= \; \frac{\partial \nu}{\partial \Delta Q}\,\frac{\partial \Delta Q}{\partial \phi}\,\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\bigg|_{\phi_M,\phi_X}
		\; < \; 0 \qquad \Bigl[\text{(a)},\; \tfrac{\partial \Delta Q}{\partial \phi} < 0\Bigr] \\[8pt]
		\text{(a)} \quad \frac{\partial \nu}{\partial \Delta Q} \; &> \; 0
		\qquad \text{1-homogeneous, strictly positive at the flow direction} \\[8pt]
		\text{(ii)} \; &\perp \; (H2)
	\end{aligned}
\]

**Theorem 34 (The channels close a loop) [M26].**

\[
	\begin{aligned}
		\phi \; &\to \; \Delta Q \; \to \; \nu \; \to \; \phi \\[8pt]
		\text{loop} \; &= \; \frac{\partial \nu}{\partial \Delta Q}\,\frac{\partial \Delta Q}{\partial \phi}\,(1-\phi_M)(1-\tau_{\text{MEV}})\,\frac{\partial \phi_X}{\partial \nu}
		\; < \; 0 \\[8pt]
		\frac{\partial \nu}{\partial \tau_{\text{MEV}}}\bigg|_{\text{total}}
		\; &= \; \frac{\text{(i)} \, + \, \text{(ii)}}{1 \, - \, \text{loop}},
		\qquad 1 - \text{loop} \; > \; 1
	\end{aligned}
\]

**Theorem 35 (The arb side does not close) [M27].** *Under ScaleHomogeneous.*

\[
	\begin{aligned}
		\frac{\partial \Delta Q^{\text{ARB}}}{\partial \phi} \; &\neq \; f\bigl(\sigma,\, \phi,\, \Delta t,\, \epsilon_{p/X}\bigr)
		\qquad \text{(any such } f \Longrightarrow \text{the response vanishes identically)} \\[8pt]
		\bigl[\sigma\bigr] = \bigl[\phi\bigr] = \bigl[\epsilon_{p/X}\bigr] \; &= \; \text{scale-free},
		\qquad \Bigl[\tfrac{\partial \Delta Q^{\text{ARB}}}{\partial \phi}\Bigr] \; = \; \text{quantity} \\[8pt]
		\text{missing primitive} \; &= \; \bar L \quad \text{(equivalently } \pi^{\varphi}\text{)} \\[8pt]
		\mathbb{P}_{\Delta_{\text{ARB}}},\; \frac{\partial \mathbb{P}_{\Delta_{\text{ARB}}}}{\partial \phi} \; &= \; f\bigl(\sigma,\, \phi,\, \Delta t\bigr)
		\qquad\quad\;\, \text{(closes)} \\[4pt]
		\frac{\partial \log \Delta Q^{\text{ARB}}}{\partial \log \phi} \; &= \; \text{scale-free}
		\qquad\qquad\qquad\;\;\, \text{(closes)}
	\end{aligned}
\]
