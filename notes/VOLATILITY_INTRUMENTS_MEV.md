
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

From $\Theta_{\sigma}$ define the left- and right-hand cardinalities of the volatility ladder:

\[
\begin{aligned}
n_{-}
&=
\left\lfloor
\frac{\#_{\sigma}-1}{2}
\left(1-s_{\sigma}\right)
\right\rfloor,
\\[4pt]
n_{+}
&=
\left(\#_{\sigma}-1\right)-n_{-}.
\end{aligned}
\]

Define the strike-volatility coordinate

\[
i_{\sigma_K}
:=
i_K(\sigma_K),
\]

and the fixed support of the volatility claim

\[
\begin{aligned}
i_{\sigma}^{-}
&=
i_{\sigma_K}-n_{-}\Delta_i,
\\
i_{\sigma}^{+}
&=
i_{\sigma_K}+n_{+}\Delta_i.
\end{aligned}
\]

At event $t$, realized volatility induces the volatility coordinate

\[
i_{\sigma}(t)
:=
i_K\!\left(\sigma(i(t))\right).
\]

Its displacement from the strike in volatility-grid units is

\[
k_{\sigma}(t)
:=
\left\lfloor
\frac{
i_{\sigma}(t)-i_{\sigma_K}
}{
\Delta_i
}
\right\rfloor.
\]

Hence the realized volatility node is

\[
i_K(t)
=
i_{\sigma_K}
+
k_{\sigma}(t)\Delta_i.
\]

The realized volatility lies inside the instrument support iff

\[
-n_{-}
\leq
k_{\sigma}(t)
\leq
n_{+} \iff i_{\sigma}^{-}
\leq
i_K (t)
\leq
i_{\sigma}^{+}
\]

Then recall:

\[
	\begin{aligned}
		\Delta Q_{\upsilon} \, (\sigma^2 - \sigma^2_K)^+ \, \equiv \pi^{\sigma} \, \equiv \, \sum_{i_K = i_{\sigma}^{-}}^{i_{\sigma}^{+}} L_{(\chi_{X/M} , \epsilon_{(X/M)})} \, (i_K) \, \pi^{\varphi} \, (i_K)
	\end{aligned}
\]

Then:
\[
	\begin{aligned}
		\frac{\partial}{\partial t} \, \Big [ \Delta Q_{\upsilon} \, (\sigma^2 - \sigma^2_K)^+\Big] \, \equiv \frac{\partial \pi^{\sigma}}{\partial t} \, \equiv \frac{\partial}{\partial t} \, \Big [ \sum_{i_K = i_{\sigma}^{-}}^{i_{\sigma}^{+}} L_{(\chi_{X/M} , \epsilon_{(X/M)})} \, (i_K) \, \pi^{\varphi} \, (i_K)\Big]
	\end{aligned}
\]

> TODO: The belwo mentioned definition is to be modefied to include the derivative terms of LVR and pi^{\phi} and the identity of derivative with respect to time of \pi^{\varphi} is the difference between these two

Using **Definition 16** and expanding:

\[
	\begin{aligned}
		\frac{\partial \Delta Q_{\upsilon}}{\partial t} \, (\sigma^2 \, - \,\sigma^2_K)^+ \, + \, \frac{\partial \, (\sigma^2 \, - \,\sigma^2_K)^+}{\partial t} \, \Delta Q_{\upsilon} \, = \, \Big (\frac{(1-\phi)(1+\phi)}{\phi} \, \frac{\Delta p}{p} - \frac{\sigma^2}{8}\Big) \,  \sum_{i_K} \, L (i_K) + \sum_{i_K}\, \frac{\partial L (i_K)}{\partial t} \, \pi^{\varphi} \, (i_K) 
	\end{aligned}
\]
 
From where using **Convention 8** we have:

\[
	\begin{aligned}
		\frac{\partial \, (\sigma^2 \, - \,\sigma^2_K)^+}{\partial t} \, = \, \frac{(1-\phi)(1+\phi)}{\phi} \, \frac{\Delta p}{p} - \frac{\sigma^2}{8}
	\end{aligned}
\]


And:

\[
	\begin{aligned}
		\frac{\partial \Delta Q_{\upsilon}}{\partial t} \, (\sigma^2 \, - \,\sigma^2_K)^+ \, = \,  \sum_{i_K} \,\Big [ \frac{\partial L (i_K)}{\partial t} \, \pi^{\varphi} \, (i_K) \Big]
	\end{aligned}
\]

Deriving **Convention 8** we have:

\[
	\begin{aligned}
		\bigg (\sum_{i_K} \, \frac{\partial L (i_K)}{\partial t}\bigg) \, (\sigma^2 \, - \,\sigma^2_K)^+ \, = \,  \sum_{i_K} \,\Big [ \frac{\partial L (i_K)}{\partial t} \, \pi^{\varphi} \, (i_K) \Big]
	\end{aligned}
\]


Note: 
\[
	\begin{aligned}
		\frac{\partial \hat \pi^{\sigma}}{\partial \tau_{\text{MEV}}} \, = \, 0 \, \implies \sum_{i_K} \, \frac{\partial L (i_K)}{\partial \tau_{\text{MEV}}} \, \pi^{\varphi} \, (i_K) \, = - \sum_{i_K} \frac{\partial \pi^{\varphi}}{\partial \tau_{\text{MEV}}} \, L(i_K)
	\end{aligned}
\]



Define the common normalization factor and **normalized payoff returns** as:
\[ 
	\begin{aligned}
	\mathcal N_{\pi}
	:=
	\frac{1}{\pi^{\mathrm{linear}}(t_0)}  \, \implies \, \begin{cases} r_t^{\phi}
:=
\frac{\pi_t^{\phi}}
{\pi^{\mathrm{linear}}(t_0)} \\
r_t^{\mathrm{LVR}}
:=
\frac{\pi_t^{\mathrm{LVR}}}
{\pi^{\mathrm{linear}}(t_0)}
\end{cases}
 \implies r_t^{\varphi}
=
r_t^\phi-r_t^{\mathrm{LVR}}
 
	\end{aligned}
\]

Where

\[
	\begin{aligned}
		r_t^\phi = \phi_t,\delta_{\mathrm{trans},t} \\
		r_t^{\mathrm{LVR}} = \frac{\sigma_t^2}{8}\Delta t
	\end{aligned}
\]

for the CPMM specialization.

Thus; normalized control objective becomes:

\[
\boxed{
\max_{\tau_{\mathrm{MEV}}}
;
\mathbb E
\left[
r_t^\phi-r_t^{\mathrm{LVR}}
\right].
}
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
*Under Convention 11. Participation iff $(1+\Delta p/p)(1-\phi) > 1$.*

\[
	\begin{aligned}
		\frac{\partial \nu}{\partial t} \; &= \; \Bigl|\,
		\bigl((1+\tfrac{\Delta p}{p})(1-\phi)\bigr)^{\frac{1-\kappa_{\varphi}}{4\kappa_{\varphi}}}
		\, - \,
		\bigl((1+\tfrac{\Delta p}{p})(1-\phi)\bigr)^{-\frac{1-\kappa_{\varphi}}{4\kappa_{\varphi}}}
		\,\Bigr| \\[8pt]
		\frac{1-\kappa_{\varphi}}{4\kappa_{\varphi}} \; &= \; \frac{1}{2\,\bigl|\epsilon_{p/X}\bigr|} \\[8pt]
	\end{aligned}
\]


**Theorem 37 (One driver, no root) [M35].**
*Price-shock-only model — before Definition 36. Under Convention 11 and Theorem 36.*

\[
	\begin{aligned}
		\frac{\partial}{\partial \tau_{\text{MEV}}}\Bigl(\mathbb{P}_{\Delta_{\text{ARB}}}\cdot\nu\Bigr)
		\; &= \; \Bigl(\frac{\partial \mathbb{P}_{\Delta_{\text{ARB}}}}{\partial \phi}\,\nu
		\; + \; \mathbb{P}_{\Delta_{\text{ARB}}}\,\frac{\partial \nu}{\partial \phi}\Bigr)\,
		\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\bigg|_{\phi_M,\phi_X} \\[8pt]
		\mathcal{F}_{\phi \to \nu \to \phi} \; &\equiv \; 1 \, - \, \frac{\partial \nu}{\partial \phi}\,(1-\phi_M)(1-\tau_{\text{MEV}})\,\frac{\partial \phi_X}{\partial \nu} \\[8pt]
		\Bigl[(1-\phi_M)(1-\phi_X) \, + \, \frac{\partial\phi}{\partial\nu}\,\frac{\partial\nu}{\partial\tau_{\text{MEV}}}\Bigr]
		\cdot\mathcal{F}_{\phi \to \nu \to \phi} \; &= \; (1-\phi_M)(1-\phi_X) \\[8pt]
	\end{aligned}
\]


Define the replication residual*

\[
e^{\sigma}(\tau_{\mathrm{MEV}})
\, \equiv\, \widehat{\pi}^{\sigma}(\tau_{\mathrm{MEV}})
-
\pi^{\sigma},
\]

*where the contractual volatility payoff \(\pi^\sigma\) is invariant to the MEV tax.* Hence, on the admissible domain,

\[

\forall,
\tau_{\mathrm{MEV}}\in[0,1]:
\qquad
\frac{\partial e^\sigma}
{\partial\tau_{\mathrm{MEV}}}

> 0
\]

Therefore \(e^\sigma\) is strictly increasing in \(\tau_{\mathrm{MEV}}\), and consequently

\[
	|
		\tau_{\mathrm{MEV}}\in[0,1]
	:
	e^\sigma(\tau_{\mathrm{MEV}})=0
	|
	\leq 1.
    
\]

In particular, the price-shock-only plant admits **at most one exact replication tax**.



**Definition 36 (Transactional payoff and valuation shock) [M36].**
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

**Definition 37 (Tax program) [M19, M38].**
Objective in returns coordinates (per $\pi^{\varphi}$, DOC Proposition 9); under (A-route), (A-size).*

\[
	\begin{aligned}
		\max_{\tau_{\text{MEV}} \in [0,1]}
		\;\; \bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}} (\phi)\bigr)\,
		\mathbb{P}_{\Delta_{\text{transactional}}}\,
	    (\phi_M \, \otimes_{\phi} \phi_X) \,\delta_{\text{trans}}
		\; - \; \frac{\sigma^2 \Delta t}{8}\,\mathbb{P}_{\Delta_{\text{ARB}}} (\phi) \\
		\qquad \text{s.t.} \\
		e^{\sigma} (\tau_{\text{MEV}}) = 0\\
	     \\
		\text{Definition 36}
	\end{aligned}
\]



**Theorem 39 (Top-up law and pro-cyclicality) [M38].**
*Under Definitions 36–37, Rule 14, (A-tail). The shutdown regime — objective negative at every fee — is loss-minimization, not optimization.*

\[
	\begin{aligned}
		\phi^{\star} \; &\equiv \; \arg\max_{\phi\,\in\,[0,1)}
		\Bigl[\,\bigl(1-\mathbb{P}_{\Delta_{\text{ARB}}} (\phi)\big)\,
		\mathbb{P}_{\Delta_{\text{transactional}}}\,
		\bigl(\phi_M \otimes_{\phi} \phi_X\bigr)\,\delta_{\text{transactional}}
		\; - \; \tfrac{\sigma^2\Delta t}{8}\,\mathbb{P}_{\Delta_{\text{ARB}}} (\phi)\,\Bigr] \\[8pt]
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

**Theorem 42 (Explicit gate derivative) [M42].**
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


