# DRAFT — the trading curve `φ_{ε_{X/M}}`, the substitution elasticity, and its link to `κ_φ` and `η`

> STATUS: DRAFT pending HEAVY USER APPROVAL. Placement: the pricing-geometry section, replacing the
> unlabelled lead-in "Consider a exogenous tuple flow … on the region:" that currently precedes the
> `φ` display. Block labels `S0`–`S3` (S = substitution) are PROPOSED — confirm or rename.
> Derived 2026-08-02 from the user's relation `λ^{η Δ_i/2} = ε_{X/M}/(1−ε_{X/M})`.

## **S0. [DECLARATIONS]** — nothing below is used before it is defined

\[
	\begin{aligned}
		\lambda \, &\triangleq \, 1.0001 \qquad \text{(the tick base; UNSUBSCRIPTED } \lambda \text{ is always the tick base —} \\
		&\qquad\qquad\quad\;\; \text{every hazard carries a subscript: } \lambda_{\text{FLAIR}},\, \lambda_{\text{ARB}},\, \tilde\lambda_{\text{JIT}}) \\
		\Lambda(z) \, &\triangleq \, \frac{1}{1 + e^{-z}} \qquad \text{(the logistic; the same } \Lambda \text{ consumed by the fee schedule below)}
	\end{aligned}
\]

**LEG IDENTIFICATION (binding).** \(p_{(\eta,\Delta_i)}\) is the SQUARE ROOT of the price of the asset in money. On the market \((X, M)\) the two legs are then fixed by their form, NOT by their letters — the letters are historical and are **not** mnemonics: <!-- notation-map -->

\[
	\begin{aligned}
		\Delta Q_M^{L}(i_K) \; &= \; L(i_K)\Big[\tfrac{1}{p_{(\eta,\Delta_i)}(i_K)} - \tfrac{1}{p_{(\eta,\Delta_i)}(i_K+\Delta_i)}\Big] \;\;\longrightarrow\;\; \textbf{the ASSET leg} \\
		\Delta Q_X^{L}(i_K) \; &= \; L(i_K)\big[p_{(\eta,\Delta_i)}(i_K+\Delta_i) - p_{(\eta,\Delta_i)}(i_K)\big] \;\;\longrightarrow\;\; \textbf{the MONEY leg}
	\end{aligned}
\]

(`VolInstrument.deltaQM_token0` proves the first form; the \(1/p\) leg is held when the price is low and is therefore the asset, the \(p\) leg when the price is high and is therefore the money.)

**DOC ↔ LEAN NAME MAP (binding).** The doc symbol is \(\epsilon_{X/M}\) — the substitution ELASTICITY between the two legs (user decision, 2026-08-02, replacing the earlier `η̃`). Its Lean identifiers are `etaTilde`, `etaOfTilde`, `tildeOfCurv`, fixed by the bundle submitted before the rename and NOT to be hand-edited — a file Aristotle has proven is never modified. This doc-glyph / Lean-name split is the project's standing practice: `ℙ_{Δ_ARB}`↔`ptrade`, `κ_φ`↔`curvIndex`, `λ̃_JIT`↔`lamJITtax`. <!-- notation-map -->

## **S1. [THE TRADING CURVE]** \(\varphi_{\epsilon_{X/M}}\)

The exogenous flow \(\Delta Q = (\Delta Q_M, \Delta Q_X)\) moves along the TRADING CURVE

\[
	\begin{aligned}
		\varphi_{\epsilon_{X/M}}\,(i_K ; \Delta Q, L) \, &= \, \big(\Delta Q_M^{L}(i_K) + \Delta Q_M\big)^{\epsilon_{X/M}}\cdot\big(\Delta Q_X^{L}(i_K) + \Delta Q_X\big)^{1-\epsilon_{X/M}}, \qquad \epsilon_{X/M} \in (0,1)
	\end{aligned}
\]

\(\epsilon_{X/M}\) = the SUBSTITUTION PARAMETER = the exponent on the ASSET leg = the pool's asset VALUE SHARE. \(\varphi_{1/2}\) is the current constant-product case.

## **S2. [THE IDENTIFICATION]** \(\epsilon_{X/M} \leftrightarrow \eta \leftrightarrow \kappa_{\varphi}\)

\[
	\begin{aligned}
		\frac{\epsilon_{X/M}}{1-\epsilon_{X/M}} \, = \, \frac{p_{(\eta,\Delta_i)}(i_K+1)}{p_{(\eta,\Delta_i)}(i_K)} \, = \, \lambda^{\eta\,\Delta_i/2}
	\end{aligned}
\]

— the weight ratio IS the per-tick square-root-price step. Both directions follow:

\[
	\begin{aligned}
		\epsilon_{X/M}\,(\eta) \, &= \, \Lambda\Big(\frac{\eta\,\Delta_i\,\ln\lambda}{2}\Big), \qquad\qquad
		\eta\,(\epsilon_{X/M}) \, = \, \frac{2}{\Delta_i\,\ln\lambda}\,\ln\frac{\epsilon_{X/M}}{1-\epsilon_{X/M}} \\
		\kappa_{\varphi}(\epsilon_{X/M}) \, &= \, 1 - \Big(\frac{1-\epsilon_{X/M}}{\epsilon_{X/M}}\Big)^{\Delta_i}, \qquad
		\epsilon_{X/M}\,(\kappa_{\varphi}) \, = \, \frac{1}{1 + (1-\kappa_{\varphi})^{1/\Delta_i}}
	\end{aligned}
\]

CONSISTENCY (not a new definition): composing recovers E1 exactly, since the per-SPACING step is the per-TICK step raised to \(\Delta_i\),

\[
	\begin{aligned}
		\kappa_{\varphi}\big(\epsilon_{X/M}(\eta)\big) \, = \, 1 - \big(\lambda^{-\eta\Delta_i/2}\big)^{\Delta_i} \, = \, 1 - \lambda^{-\Delta_i^{2}\eta/2}
	\end{aligned}
\]

## **S3. [DOMAIN]** the three admissibility conditions coincide

\[
	\begin{aligned}
		\eta\,\Delta_i \, > \, 0 \quad &\Longleftrightarrow \quad \epsilon_{X/M} \, > \, \tfrac{1}{2} \quad \Longleftrightarrow \quad \kappa_{\varphi} \, \in \, (0,1) \\
		\eta \, = \, 0 \quad &\Longleftrightarrow \quad \epsilon_{X/M} \, = \, \tfrac{1}{2} \quad \Longleftrightarrow \quad \kappa_{\varphi} \, = \, 0
	\end{aligned}
\]

(flat grid = symmetric constant-product pool = zero curvature; the first line is the hypothesis Aristotle ADDED to `VolInstrument.deltaQM_nonneg`, recovered here as an economic condition.)

> CONSEQUENCE FOR E8(6): the factor-share identification was recorded UNAVAILABLE because \(\eta^{\star} \approx 458/\Delta_i^{2}\) cannot be a Cobb–Douglas share. It never had to be — the share is \(\epsilon_{X/M}^{\star} = \Lambda(\eta^{\star}\Delta_i\ln\lambda/2) \in (0,1)\) for EVERY \(\eta\). E8(6) is reachable through \(\epsilon_{X/M}\), not through \(\eta\) directly.
> ALREADY PROVEN (E1/pricing geometry): `curvIndex` \(= 1 - \lambda^{-\Delta_i^2\eta/2}\), `curvIndex_strictMono`, `curvIndex_mem_Ioo`, `priceEta_step_ratio`, `deltaQM_token0`, `deltaQM_nonneg` (\(\eta\Delta_i > 0\)).
> PROPOSED, NOT YET PROVEN: every display in S2 and S3, and the E8(6) consequence. Formalization target.
