
import [MEV](feat/plank::notes/VOLATILITY_INSTRUMENTS.md)

> **Numbering.** Blocks in this document continue the sequence of
> `VOLATILITY_INSTRUMENTS.md` (one shared corpus). Next unused:
> `Convention 12`, `Definition 38`, `Theorem 40`, `Proposition 14`, `Rule 15`.
> (`Convention 10` is RETIRED unused — a returns-coordinates block struck before
> writing because `DOC` owns both halves, Proposition 9 and the `DOC:946` CPMM
> instantiation; the number is not to be reused.)
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

**Definition 32 (Event-time plant) [M11, M33, M36].**

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
				\Delta p / p \\[4pt]
				\Delta \pi^{\text{transactional}} / \pi^{\text{transactional}} \\[4pt]
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

**Convention 11 (Flow reading — unsigned legs) [M34].**

\[
	\begin{aligned}
		\Delta Q_M \cdot \Delta Q_X \; &< \; 0 \qquad \text{(shock-induced flow is a swap)} \\[6pt]
		\nu \;\; &\text{reads} \;\; \bigl(|\Delta Q_M|,\, |\Delta Q_X|\bigr)
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

**Hypothesis (H3 — ScaleHomogeneous) [M27].**

\[
	\begin{aligned}
		\bar L \; \to \; c\,\bar L
		\quad &\Longrightarrow \quad
		\text{band}(\phi) \;\; \text{invariant}, \qquad \nu(s, \phi, \kappa_{\varphi}) \;\; \text{invariant}
	\end{aligned}
\]

**Definition 36 (Tax program) [M19, M38].**
*The $(\partial\widehat\pi^{\sigma}/\partial\tau_{\text{MEV}})^2$ reading is superseded — every root minimizes it (`Theorem44_objective_reading_does_not_discriminate`). Objective in returns coordinates (per $\pi^{\varphi}$, DOC Proposition 9); under (A-route), (A-size).*

\[
	\begin{aligned}
		\max_{\tau_{\text{MEV}} \in [0,1]}
		\;\; \bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)\,
		\mathbb{P}_{\Delta_{\text{transactional}}}\,
		\bigl(\phi_M \otimes_{\phi} \phi_X\bigr)\,\delta
		\; - \; \frac{\sigma^2 \Delta t}{8}\,\mathbb{P}_{\Delta_{\text{ARB}}}
		\qquad \text{s.t.} \quad \pi^{\sigma} \; = \; \widehat\pi^{\sigma}
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
*Route (ii) requires (a) — recovered under Convention 11 (Theorem 46). Scope: (i) and (ii) share the price-shock driver — see Theorem 37; a genuinely second channel requires Definition 37.*

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
*Scope: in the price-shock-only model the loop's exogenous input is 0 (Theorem 37); Definition 37's channel restores it.*

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

**Theorem 35 (The arb side does not close) [M27].** *Under (H3).*

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

**Definition 37 (Transactional payoff and valuation shock) [M36].**
*Under (A-ind): $\Delta\pi^{\text{transactional}}/\pi^{\text{transactional}}$ independent of $\Delta p/p$.*

\[
	\begin{aligned}
		\pi^{\text{transactional}} \; &: \; \text{benign-trader payoff} \\[6pt]
		\mathbb{P}_{\Delta_{\text{transactional}}}(\phi) \; &\equiv \;
		\mathbb{P}\Bigl(\Bigl|\tfrac{\Delta \pi^{\text{transactional}}}{\pi^{\text{transactional}}}\Bigr| \, > \, \phi\Bigr)
		\; = \; e^{-\alpha_{\text{transactional}}\phi} \quad \text{under (A-tail)} \\[8pt]
		1 \; &= \; \underbrace{\mathbb{P}_{\Delta_{\text{ARB}}}}_{\text{arb}}
		\; + \; \underbrace{\bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)\,\mathbb{P}_{\Delta_{\text{transactional}}}}_{\text{transactional}}
		\; + \; \underbrace{\bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)\bigl(1-\mathbb{P}_{\Delta_{\text{transactional}}}\bigr)}_{\text{idle}} \\[8pt]
		\mathbb{E}\Bigl[\Bigl(\Bigl|\tfrac{\Delta \pi^{\text{transactional}}}{\pi^{\text{transactional}}}\Bigr| - b\Bigr)^{+}\Bigr] \; &= \; \frac{e^{-\alpha_{\text{transactional}} b}}{\alpha_{\text{transactional}}}
	\end{aligned}
\]

**Rule 14 (Standing assumptions of the transactional channel) [M36].**

\[
	\begin{aligned}
		\text{(A-ind)} \quad & \Bigl\langle \tfrac{\Delta\pi^{\text{transactional}}}{\pi^{\text{transactional}}} \, , \; \tfrac{\Delta p}{p} \Bigr\rangle
		\; \equiv \; \mathbb{E}\Bigl[\tfrac{\Delta\pi^{\text{transactional}}}{\pi^{\text{transactional}}}\cdot\tfrac{\Delta p}{p}\Bigr] \; = \; 0
		\qquad \text{(carrier: independence — strictly stronger)} \\[8pt]
		\text{(A-tail)} \quad & \mathbb{P}_{\Delta_{\text{transactional}}}(\phi) \; = \; e^{-\alpha_{\text{transactional}}\phi},
		\qquad \alpha_{\text{transactional}} \;\; \text{ASSUMED — no causal estimate exists} \\[8pt]
		\text{(A-size)} \quad & \text{relative benign trade size } \delta \;\; \text{exogenous}
		\qquad \text{(the rate responds to } \phi\text{; the size does not)} \\[8pt]
		\text{(A-route)} \quad & \pi^{\phi} \;\; \text{accrues the } \phi_M, \phi_X \text{ legs only (Rule 6)};
		\qquad \tau_{\text{MEV}}\text{'s share is not routed}
	\end{aligned}
\]

**Theorem 36 (Shock-driven utilization) [M33].**
*Under (H3) and Convention 11. Participation iff $(1+\Delta p/p)(1-\phi) > 1$.*

\[
	\begin{aligned}
		\nu \; &= \; \Bigl|\,
		\bigl((1+\tfrac{\Delta p}{p})(1-\phi)\bigr)^{\frac{1-\kappa_{\varphi}}{4\kappa_{\varphi}}}
		\, - \,
		\bigl((1+\tfrac{\Delta p}{p})(1-\phi)\bigr)^{-\frac{1-\kappa_{\varphi}}{4\kappa_{\varphi}}}
		\,\Bigr| \\[8pt]
		\frac{1-\kappa_{\varphi}}{4\kappa_{\varphi}} \; &= \; \frac{1}{2\,\bigl|\epsilon_{p/X}\bigr|} \\[8pt]
		\Delta Q \; &= \; \bar L \, \nu
	\end{aligned}
\]

**Theorem 37 (One driver, no root) [M35].**
*Price-shock-only model — before Definition 37. Under Theorem 33's signs.*

\[
	\begin{aligned}
		\frac{\partial}{\partial \tau_{\text{MEV}}}\Bigl(\mathbb{P}_{\Delta_{\text{ARB}}}\cdot\nu\Bigr)
		\; &= \; \Bigl(\frac{\partial \mathbb{P}_{\Delta_{\text{ARB}}}}{\partial \phi}\,\nu
		\; + \; \mathbb{P}_{\Delta_{\text{ARB}}}\,\frac{\partial \nu}{\partial \phi}\Bigr)\,
		\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\bigg|_{\phi_M,\phi_X} \\[8pt]
		\Bigl[(1-\phi_M)(1-\phi_X) \, + \, \frac{\partial\phi}{\partial\nu}\,\frac{\partial\nu}{\partial\tau_{\text{MEV}}}\Bigr]
		\cdot\bigl(1-\text{loop}\bigr) \; &= \; (1-\phi_M)(1-\phi_X) \\[8pt]
		\forall\, \tau_{\text{MEV}} \in [0,1] \, : \;\; \frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}} \; > \; 0
		\qquad &\Longrightarrow \qquad
		\neg\,\exists\, \tau_{\text{MEV}} \in [0,1] \, : \;\; \frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}} \; = \; 0
	\end{aligned}
\]

**Theorem 38 (The transactional channel restores the root) [M37].**
*Under Definitions 36–37 and Rule 14. Relaxes exactly one premise of Theorem 37 — the fee-sufficiency hypothesis (`Theorem47_no_exogenous_hazard_input`), which holds under full routing and fails under (A-route). Theorem 37 stands on its own domain.*

\[
	\begin{aligned}
		\neg\,\forall\, \tau_{\text{MEV}} \in [0,1] \, &: \;\;
		\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}} \; > \; 0 \\[8pt]
		\exists\, \tau^{\star}_{\text{MEV}} \in (0,1) \, &: \;\;
		\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}}\bigg|_{\tau^{\star}_{\text{MEV}}} \; = \; 0,
		\qquad
		\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\bigg|_{\tau^{\star}_{\text{MEV}}} \; \neq \; 0
	\end{aligned}
\]

**Theorem 39 (Top-up law and pro-cyclicality) [M38].**
*Under Definitions 36–37, Rule 14, (A-tail). The shutdown regime — objective negative at every fee — is loss-minimization, not optimization.*

\[
	\begin{aligned}
		\phi^{\star} \; &\equiv \; \arg\max_{\phi\,\in\,[0,1)}
		\Bigl[\,\bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)\,
		\mathbb{P}_{\Delta_{\text{transactional}}}\,
		\bigl(\phi_M \otimes_{\phi} \phi_X\bigr)\,\delta
		\; - \; \tfrac{\sigma^2\Delta t}{8}\,\mathbb{P}_{\Delta_{\text{ARB}}}\,\Bigr] \\[8pt]
		\tau^{\star}_{\text{MEV}} \; &= \;
		\frac{\phi^{\star} \, - \, \phi_M \otimes_{\phi} \phi_X}{1 \, - \, \phi_M \otimes_{\phi} \phi_X},
		\qquad
		\tau^{\star}_{\text{MEV}} \in (0,1)
		\; \Longleftrightarrow \;
		\phi_M \otimes_{\phi} \phi_X \; < \; \phi^{\star} \; < \; 1 \\[8pt]
		\alpha_{\text{transactional}}\,\phi^{\star} \; &> \; \mathbb{P}_{\Delta_{\text{ARB}}}(\phi^{\star})
		\qquad \text{(interior maximiser, (A-route))} \\[8pt]
		\phi^{\star} \; \leq \; \phi_M \otimes_{\phi} \phi_X
		\; &\Longrightarrow \; \tau^{\star}_{\text{MEV}} \; = \; 0 \\[8pt]
		\frac{\partial \phi^{\star}}{\partial \sigma} \; > \; 0
		\quad &\Longrightarrow \quad
		\frac{\partial \tau^{\star}_{\text{MEV}}}{\partial \sigma} \; > \; 0
	\end{aligned}
\]
