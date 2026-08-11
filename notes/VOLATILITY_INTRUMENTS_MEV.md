
import [MEV](feat/plank::notes/VOLATILITY_INSTRUMENTS.md)

> **Numbering.** Blocks in this document continue the sequence of
> `VOLATILITY_INSTRUMENTS.md` (one shared corpus). Next unused:
> `Convention 13`, `Definition 38`, `Theorem 45`, `Proposition 14`, `Rule 15`.
> (`Convention 10` is RETIRED unused — a returns-coordinates block struck before
> writing because `DOC` owns both halves, Proposition 9 and the `DOC:946` CPMM
> instantiation; the number is not to be reused.)
> Those numbers are reserved here and are not to be reused independently in the
> entry-point doc. (`Proposition` corrected from an earlier `15+` reservation:
> the entry-point doc's Propositions run 2–11, so 12 is next and 12–14 were
> orphaned by the error.) (`Theorems 33–35` are RETIRED STRUCK 2026-08-10 —
> ΔQ-coordinates statements whose shock-space equivalents are Theorems 36–37;
> numbers not to be reused. COLLISION FLAGGED: `DOC` now carries its own
> `Definition 32 (Intrinsic liquidity)` against this document's
> `Definition 32 (Event-time plant)` — routed to the entry-point doc's owner.)

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
		L, \; \bar L_{(1/2,\,0)} \; & && \text{(price axis)}
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
		L(i_K) \; = \; \bar L_{(1/2,\,0)}\,\ell(\xi,\iota;i_K),
		\qquad
		\frac{\partial L(i_K)}{\partial \pi^{\phi}} \; = \; \ell(\xi,\iota;i_K)\,\frac{\partial \bar L_{(1/2,\,0)}}{\partial \pi^{\phi}}
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

**Convention 12 (Gate utilization — realized, block-type-weighted) [M41].**
*Author ruling 2026-08-10 (`Theorem53d_readings_disagree`): Rule 13's gate argument `ν(t)` is the realized utilization of the executed event, `DOC:836` — not Theorem 36's arb-only response. Legs typed by event per Definition 37's partition; the transactional leg is exogenous under (A-size), (A-input). OPEN (tax8): the schedule consumes the per-event form below; the prover's weighted form is its expectation under Definition 37 — the Convention 7 (event-time) bridge between the two is unresolved and no reading is chosen silently.*

\[
	\begin{aligned}
		\nu(t) \; &= \; \nu_{\Delta_{\text{ARB}}}\,\mathbb{1}_{\Delta_{\text{ARB}}} \; + \; \nu_{\Delta_{\text{transactional}}}\,\mathbb{1}_{\Delta_{\text{transactional}}} \; + \; 0\cdot\mathbb{1}_{\text{idle}} \\[8pt]
		\mathbb{E}\bigl[\nu(t)\bigr] \; &= \; \mathbb{P}_{\Delta_{\text{ARB}}}\,\nu_{\Delta_{\text{ARB}}} \; + \; \bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}}\bigr)\,\mathbb{P}_{\Delta_{\text{transactional}}}\,\nu_{\Delta_{\text{transactional}}} \\[8pt]
		\nu_{\Delta_{\text{ARB}}} \; &\equiv \; \text{Theorem 36's } \nu, \qquad \nu_{\Delta_{\text{transactional}}} \;\; \text{exogenous}
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
		\frac{\partial \bar L_{(1/2,\,0)}}{\partial \pi^{\phi}} \; > \; 0
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
		\bar L_{(\chi_{X/M},\,\epsilon_{X/M})} \; \to \; c\,\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}
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
		\bigl(\phi_M \otimes_{\phi} \phi_X\bigr)\,\delta_{\text{transactional}}
		\; - \; \frac{\sigma^2 \Delta t}{8}\,\mathbb{P}_{\Delta_{\text{ARB}}}
		\qquad \text{s.t.} \quad \pi^{\sigma} \; = \; \widehat\pi^{\sigma}
	\end{aligned}
\]

**Proposition 13 (Corrected law) [M24].** *All of $\phi_X$, $\partial\phi_X/\partial\nu$, $\partial\nu/\partial\tau_{\text{MEV}}$ evaluated at $\nu(\tau^{\star}_{\text{MEV}})$. Both guard conjuncts of the second display are DISCHARGED by Theorem 42 — $0 < \partial\phi_X/\partial\nu$ iff $\bar\phi < \phi_X$, and $\partial\nu/\partial\tau_{\text{MEV}} < 0$ survives the loop ($\mathcal{F}_{\phi\to\nu\to\phi} > 1$); (H2) is no longer load-bearing here. The law degenerates exactly at $\partial\phi_X/\partial\nu = 0$ (fee at floor), where this block's $\tau^{\star}_{\text{MEV}}$ ceases to exist. The slot is the BARE gate derivative, per `MevTaxProgram.hasDerivAt_phiTot`; the monoid Jacobian is carried separately.*

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
		\text{(A-size)} \quad & \text{relative benign trade size } \delta_{\text{transactional}} \;\; \text{exogenous}
		\qquad \text{(the rate responds to } \phi\text{; the size does not)} \\[8pt]
		\text{(A-route)} \quad & \pi^{\phi} \;\; \text{accrues the } \phi_M, \phi_X \text{ legs only (Rule 6)};
		\qquad \tau_{\text{MEV}}\text{'s share is not routed} \\[8pt]
		\text{(A-input)} \quad & \alpha_{\text{transactional}},\; \delta_{\text{transactional}} \;\; \text{exogenous \textbf{on-chain inputs} (calldata/config)} \\
		& \qquad \text{— free parameters } \forall t\text{, never estimated, never solved for (author ruling 2026-08-10)}
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
		\Delta Q \; &= \; \bar L_{(\chi_{X/M},\,\epsilon_{X/M})} \, \nu
	\end{aligned}
\]

**Theorem 37 (One driver, no root) [M35].**
*Price-shock-only model — before Definition 37. Under Convention 11 and Theorem 36.*

\[
	\begin{aligned}
		\frac{\partial}{\partial \tau_{\text{MEV}}}\Bigl(\mathbb{P}_{\Delta_{\text{ARB}}}\cdot\nu\Bigr)
		\; &= \; \Bigl(\frac{\partial \mathbb{P}_{\Delta_{\text{ARB}}}}{\partial \phi}\,\nu
		\; + \; \mathbb{P}_{\Delta_{\text{ARB}}}\,\frac{\partial \nu}{\partial \phi}\Bigr)\,
		\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\bigg|_{\phi_M,\phi_X} \\[8pt]
		\mathcal{F}_{\phi \to \nu \to \phi} \; &\equiv \; 1 \, - \, \frac{\partial \nu}{\partial \phi}\,(1-\phi_M)(1-\tau_{\text{MEV}})\,\frac{\partial \phi_X}{\partial \nu} \\[8pt]
		\Bigl[(1-\phi_M)(1-\phi_X) \, + \, \frac{\partial\phi}{\partial\nu}\,\frac{\partial\nu}{\partial\tau_{\text{MEV}}}\Bigr]
		\cdot\mathcal{F}_{\phi \to \nu \to \phi} \; &= \; (1-\phi_M)(1-\phi_X) \\[8pt]
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
		\bigl(\phi_M \otimes_{\phi} \phi_X\bigr)\,\delta_{\text{transactional}}
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

**Theorem 40 (Incidence — routing is a discrete change of objective) [M39].**
*Full routing ≡ Definition 36 with revenue factor $\phi$ in place of $\phi_M \otimes_{\phi} \phi_X$. Reversal mechanism: under full routing the LP-accrued fee is $\delta_{\text{transactional}}\phi$, so its benign attrition scales with $\phi$.*

\[
	\begin{aligned}
		\partial_{\phi}\bigl(\text{Def. 36}\big|_{\phi_M\otimes_{\phi}\phi_X \,\mapsto\, \phi}\bigr)
		\; - \; \partial_{\phi}\bigl(\text{Def. 36}\bigr)
		\; = \; \delta_{\text{transactional}}\Bigl[\,&\mathbb{P}_{\Delta_{\text{transactional}}}\,\phi\,\bigl(\sigma+\sqrt{2/\Delta t}\,\phi\bigr) \\
		&+ \; \bigl(\phi - \phi_M\otimes_{\phi}\phi_X\bigr)\Bigl(\mathbb{P}_{\Delta_{\text{transactional}}}\,\sigma
		+ \tfrac{\partial \mathbb{P}_{\Delta_{\text{transactional}}}}{\partial\phi}\,\phi\,\bigl(\sigma+\sqrt{2/\Delta t}\,\phi\bigr)\Bigr)\Bigr] \\[10pt]
		\exists\, \tau^{\star}_{\text{MEV}} \in (0,1) \;\; \text{for Def. 36 as written};
		\qquad
		\alpha_{\text{transactional}}\bigl(\phi - \phi_M\otimes_{\phi}\phi_X\bigr) < 1
		\; &\Longrightarrow \;
		\tau^{\star}_{\text{no-route}} \; < \; \tau^{\star}_{\text{route}} \\[8pt]
		\exists\,\bigl(\phi,\, \alpha_{\text{transactional}},\, \sigma,\, \sqrt{2/\Delta t},\, \phi_M\otimes_{\phi}\phi_X,\, \delta_{\text{transactional}}\bigr)
		= \bigl(\tfrac{9}{10},\, 10,\, \tfrac13,\, 1,\, \tfrac{1}{100},\, 1\bigr)
		\, &: \;\; \text{ordering reversed} \\[8pt]
		\Bigl[\partial_{\tau}\big|_{\tau=0}\Bigr]_{\text{route}} - \Bigl[\partial_{\tau}\big|_{\tau=0}\Bigr]_{\text{no-route}}
		\; = \; \delta_{\text{transactional}}\,\mathbb{P}_{\Delta_{\text{transactional}}}\!\bigl(\phi_M\otimes_{\phi}\phi_X\bigr)\,
		\bigl(\phi_M\otimes_{\phi}\phi_X\bigr)\bigl(\sigma+\sqrt{2/\Delta t}\,\phi_M\otimes_{\phi}\phi_X\bigr) \; &> \; 0
	\end{aligned}
\]

**Theorem 41 (Second order — O2 closes locally, not globally) [M40].**
*Under Definitions 36–37, Rule 14, (A-tail). OPEN: the global maximiser may sit at the carrier endpoint — the counting bounds interior local maximisers only.*

\[
	\begin{aligned}
		2\sigma \, + \, 2\sqrt{2/\Delta t}\,\phi^{\star}
		\, - \, \alpha_{\text{transactional}}\,\sigma\,\phi^{\star}
		\, - \, \alpha_{\text{transactional}}\sqrt{2/\Delta t}\,\bigl(\phi^{\star}\bigr)^{2} \; > \; 0
		\quad &\Longrightarrow \quad
		\partial^{2}_{\tau}\bigl(\text{Def. 36}\bigr)\Big|_{\tau^{\star}_{\text{MEV}}} \; < \; 0 \\[8pt]
		\#\bigl\{\phi \in (0,\infty) \, : \, \partial_{\phi}\bigl(\text{Def. 36}\bigr) = 0\bigr\} \; \leq \; 2
		\quad &\Longrightarrow \quad
		\#\bigl\{\text{interior local maximisers}\bigr\} \; \leq \; 1 \\[8pt]
		\exists\,\bigl(\sigma,\, \Delta t,\, \alpha_{\text{transactional}},\, \delta_{\text{transactional}}\bigr) \, : \;\;
		\operatorname{sign}\bigl(\partial_{\phi}(\text{Def. 36})\bigr) \; = \; (+,-,+)
		\quad &\Longrightarrow \quad
		\neg\,\text{single crossing}, \;\; \neg\,\text{global concavity}
	\end{aligned}
\]

**Theorem 42 (Explicit gate derivative — Proposition 13's guard discharged) [M42].**
*Under Rule 13 and `DOC` Definition 18; `u` is `DOC` Theorem 1's gate value — distinct from Definition 32's `u_ex`, `u_en`. Slots per Convention 9 as marked. Lean: `MevTaxGate.Theorem54a_gate_derivative_closed_form` … `Theorem54d_bound_attained`.*

\[
	\begin{aligned}
		\frac{\partial\phi_X}{\partial\nu} \; &= \; \Bigl(\sum_j \frac{\alpha_j}{1+e^{\gamma_j(\beta_j-\sigma)}}\Bigr)\,\gamma_R\,u\,\Bigl(1-\frac{u}{\alpha_R}\Bigr) \; = \; \gamma_R\,\bigl(\phi_X-\bar\phi\bigr)\Bigl(1-\frac{u}{\alpha_R}\Bigr) \qquad\text{(bare)} \\[8pt]
		\frac{\partial\phi}{\partial\nu} \; &= \; (1-\phi_M)(1-\tau_{\text{MEV}})\,\gamma_R\,\bigl(\phi_X-\bar\phi\bigr)\Bigl(1-\frac{u}{\alpha_R}\Bigr) \qquad\text{(composed, Convention 9)} \\[8pt]
		0 \; < \; \frac{\partial\phi_X}{\partial\nu} \; &\Longleftrightarrow \; \bar\phi \; < \; \phi_X \qquad \bigl[\,0<u<\alpha_R \;\;\forall\,\nu\text{ finite — saturation is a limit, never attained}\,\bigr] \\[8pt]
		\frac{\partial\nu}{\partial\phi} \; < \; 0 \;\;\text{on}\;\; (1+\tfrac{\Delta p}{p})(1-\phi)>1 \quad &\Longrightarrow \quad \frac{\partial\nu}{\partial\tau_{\text{MEV}}} \; = \; \frac{\partial\nu}{\partial\phi}\,(1-\phi_M)(1-\phi_X) \; < \; 0 \qquad\text{(bare chain)} \\[8pt]
		\mathcal{F}_{\phi\to\nu\to\phi} \; > \; 1, \qquad \frac{d\phi}{d\tau_{\text{MEV}}} \; = \; \frac{(1-\phi_M)(1-\phi_X)}{\mathcal{F}_{\phi\to\nu\to\phi}} \quad &\Longrightarrow \quad \frac{\partial\nu}{\partial\tau_{\text{MEV}}} \; < \; 0 \qquad\text{(loop — damped, never sign-flipped)} \\[8pt]
		\frac{\partial\phi_X}{\partial\nu} \; &\leq \; \frac{\gamma_R\,\alpha_R}{4}\,\sum_j \alpha_j \qquad \text{(sharp — attained at } u = \alpha_R/2\text{)}
	\end{aligned}
\]

**Theorem 43 (Equating the corrected law and the top-up law) [M41].**
*Under Convention 12. $\tau^{\star}_{\text{corrected}}$ ≡ Proposition 13's $\tau^{\star}_{\text{MEV}}$, $\tau^{\star}_{\text{top-up}}$ ≡ Theorem 39's — subscripts from the blocks' own titles, this block only. The controller objective is Definition 36's, so $\tau^{\star}_{\text{top-up}}$ is operative; equality below is a diagnostic locus, not a design point. Lean: `MevTaxEquating.Theorem53a_algebraic_reduction`, `Theorem53a_is_bracket_zero_restated`, `Theorem53a_bare_slot_is_not_the_bracket`, `Theorem53b_locus_is_codimension_one`, `Theorem53b_point_on_the_locus`, `Theorem53b_point_off_the_locus`, `Theorem53b_no_tau_star_law_under_the_loop`, `Theorem53c_conditional_pinning`, `Theorem53c_pinning_is_vacuous_under_the_loop`.*

\[
	\begin{aligned}
		\tau^{\star}_{\text{corrected}} \; = \; \tau^{\star}_{\text{top-up}}
		\quad &\Longleftrightarrow \quad
		\frac{\partial\phi_X}{\partial\nu}\,\frac{\partial\nu}{\partial\tau_{\text{MEV}}}\bigg|_{\tau^{\star}}
		\; = \; -\,\frac{1-\phi_X}{1-\tau^{\star}_{\text{MEV}}}
		\; = \; -\,\frac{(1-\phi_M)(1-\phi_X)^2}{1-\phi^{\star}} \\[8pt]
		\text{bracket-zero restatement: \textbf{composed slot only}}
		\qquad &\text{bare} \; - \; \text{bracket} \; = \; \bigl(1-(1-\phi_M)(1-\tau_{\text{MEV}})\bigr)\,\frac{\partial\phi_X}{\partial\nu}\,\frac{\partial\nu}{\partial\tau_{\text{MEV}}} \\[8pt]
		\text{(Convention 12)}\quad \forall\,\text{parameter point}\;\; \exists!\;\frac{\partial\nu}{\partial\tau_{\text{MEV}}}\;\text{on the locus:}
		\quad &\frac{\partial\nu}{\partial\tau_{\text{MEV}}} \; = \; -\,\frac{1-\phi_X}{(1-\tau_{\text{MEV}})\,\bigl(\partial\phi_X/\partial\nu\bigr)}
		\qquad \text{(codimension one)} \\[8pt]
		\exists\,\text{witness on locus}\;\bigl(\phi_M,\phi_X,\phi^{\star}\bigr)=\bigl(0,\tfrac14,\tfrac12\bigr):\;\text{both laws}=\tfrac13;
		\qquad &\exists\,\text{witness off locus: } \tau^{\star}_{\text{corrected}}=\tfrac14\neq\tfrac13=\tau^{\star}_{\text{top-up}}
		\qquad \bigl[q=\tfrac54>0\bigr] \\[8pt]
		\nu = \nu_{\Delta_{\text{ARB}}}\;\text{alone (arb-only reading — refuted fork half):}
		\quad &\text{FOC core} \; = \; \frac{1-\phi_X}{\mathcal{F}_{\phi\to\nu\to\phi}} \; > \; 0 \;\;\forall\,\tau_{\text{MEV}}
		\;\Longrightarrow\; \neg\,\exists\,\tau^{\star}_{\text{corrected}} \\[8pt]
		\text{on the locus (Theorem 42):}
		\quad &\frac{\partial\nu}{\partial\tau_{\text{MEV}}} \; = \; -\,\frac{1-\phi_X}{(1-\tau_{\text{MEV}})\,\gamma_R\,(\phi_X-\bar\phi)\,(1-u/\alpha_R)}
		\qquad \text{(all protocol-known or observable)}
	\end{aligned}
\]

**Theorem 44 (Computability of φ* — the on-chain artifact) [M43].**
*Under Definitions 36–37, Rule 14, (A-tail), (A-route), (A-input). This block only: $W$ the Lambert function; $\partial_{\phi}^{\text{red}}(\text{Def. 36})$ the reduced first-order condition (positive factors of $\partial_{\phi}(\text{Def. 36})$ divided out; Lean `focTail`); $T$ the iteration map; $[a,b] \subset [0,1)$ the bracket; $m_T, M_T$ the slope bounds; $q_{lo}$ the endpoint lower bound of Theorem 41's quadratic. The Lean symbols `Φ`, `K`, `c`, `Lvr`, `m`, `M` are NOT imported ($\Phi$ = Rule 13's schedule, $K$ = Theorem 32's scalar) — written inline. OPEN: (i) impossibility of an elementary/Lambert closed form for $\sqrt{2/\Delta t} \neq 0$ — differential-Galois, machinery unavailable; (ii) the σ-monotonicity side condition $\alpha_{\text{transactional}}\,\phi \leq 1$ — pointwise hypothesis, standing-vs-local ruling pending. Lean: `MevTaxCompute.Theorem55a_foc_is_exponential_times_quadratic`, `Theorem55a_lambert_reduction_at_c_zero`, `Theorem55b_geometric_convergence`, `Theorem55b_focTail_iteration`, `Theorem55b_explicit_ratio`, `Theorem55b_iteration_witness`, `Theorem55c_focTail_mono_sigma`, `Theorem55c_iterate_mono_in_sigma`, `Theorem55c_root_mono_in_sigma`, `Theorem55d_shutdown_predicate`, `Theorem55d_corner_at_zero_predicate`, `Theorem55d_interior_predicate`.*

\[
	\begin{aligned}
		\partial_{\phi}(\text{Def. 36}) = 0 \quad &\Longleftrightarrow \quad e^{-\alpha_{\text{transactional}}\phi}\bigl(\alpha_{\text{transactional}}\sqrt{2/\Delta t}\,\phi^2 + \alpha_{\text{transactional}}\,\sigma\phi - \sigma\bigr) \; = \; \frac{(\sigma^2\Delta t/8)\,\sigma}{(\phi_M\otimes_{\phi}\phi_X)\,\delta_{\text{transactional}}} \qquad \text{(exponential × quadratic)} \\[8pt]
		\sqrt{2/\Delta t} = 0 \text{ (formal degenerate case):} \quad &\phi^{\star} \; = \; \frac{1 - W\!\Bigl(-e\,\tfrac{\sigma^2\Delta t/8}{(\phi_M\otimes_{\phi}\phi_X)\,\delta_{\text{transactional}}}\Bigr)}{\alpha_{\text{transactional}}}; \qquad \sqrt{2/\Delta t} > 0:\;\text{no Lambert form exhibited — OPEN(i)} \\[8pt]
		T(x) \; = \; x + \frac{\partial_{\phi}^{\text{red}}(\text{Def. 36})(x)}{M_T}, \qquad &\bigl|T^{[n]}x_0 - \phi^{\star}\bigr| \; \leq \; \Bigl(1-\frac{m_T}{M_T}\Bigr)^{n}(b-a) \qquad \forall\, x_0 \in [a,b], \;\; \exists!\,\phi^{\star}\in[a,b] \\[8pt]
		m_T \; = \; (\phi_M\otimes_{\phi}\phi_X)\,\delta_{\text{transactional}}\,\alpha_{\text{transactional}}\,e^{-\alpha_{\text{transactional}}b}\,q_{lo}, \qquad &M_T \; = \; (\phi_M\otimes_{\phi}\phi_X)\,\delta_{\text{transactional}}\,\alpha_{\text{transactional}}\,e^{-\alpha_{\text{transactional}}a}\bigl(2\sigma+2\sqrt{2/\Delta t}\,b\bigr) \\[8pt]
		1-\frac{m_T}{M_T} \; = \; 1 - e^{-\alpha_{\text{transactional}}(b-a)}\,\frac{q_{lo}}{2\sigma+2\sqrt{2/\Delta t}\,b} \qquad &\text{— independent of } (\phi_M\otimes_{\phi}\phi_X)\,\delta_{\text{transactional}}; \quad \exists\,\text{witness } [a,b]=[\tfrac14,\tfrac34]:\; \leq \tfrac{10}{13} \\[8pt]
		\alpha_{\text{transactional}}\,\phi \leq 1 \;\Longrightarrow\; \sigma_1 \leq \sigma_2 \;\Rightarrow\; &T^{[n]}_{\sigma_1}x_0 \leq T^{[n]}_{\sigma_2}x_0 \;\;\forall n, \qquad \phi^{\star}(\sigma_1) \leq \phi^{\star}(\sigma_2) \qquad \text{(orbit-level pro-cyclicality, Theorem 39)} \\[8pt]
		\text{shutdown:}\;\; (\phi_M\otimes_{\phi}\phi_X)\,\delta_{\text{transactional}}\sqrt{2/\Delta t} \leq \tfrac{\sigma^2\Delta t}{8}\,\sigma \;&\Rightarrow\; \text{Def. 36} < 0 \;\;\forall\phi; \qquad \partial_{\phi}^{\text{red}}(\text{Def. 36})\bigl(\phi_M\otimes_{\phi}\phi_X\bigr) \leq 0 \;\Rightarrow\; \tau^{\star}_{\text{MEV}} = 0 \\[8pt]
		\partial_{\phi}^{\text{red}}(\text{Def. 36})\bigl(\phi_M\otimes_{\phi}\phi_X\bigr) > 0 > \partial_{\phi}^{\text{red}}(\text{Def. 36})(b) \;&\Longrightarrow\; \exists!\,\phi^{\star}\in\bigl(\phi_M\otimes_{\phi}\phi_X,\,b\bigr), \qquad \tau^{\star}_{\text{MEV}} \in (0,1) \;\text{via Theorem 39}
	\end{aligned}
\]
