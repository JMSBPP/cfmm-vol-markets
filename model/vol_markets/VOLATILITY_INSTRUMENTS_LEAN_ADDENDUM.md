# PROPOSED corrections/additions to `VOLATILITY_INSTRUMENTS.md` — from the Lean layer

> STATUS: APPROVED & APPLIED 2026-07-30 — blocks A–G inserted into
> `../cfmm-wt/plank/notes/VOLATILITY_INSTRUMENTS.md` per user approval
> (todo.md `## LEAN4 - MATH`); block H left as an in-doc FLAG pending the
> author's sign decision. Committing the plank file is the plank agent's.
> Every block cites the machine-checked lemma (`lean/vol_markets/*`, mirrored at
> `JMSBPP/cfmm-lean4-spec`). Minimal prose; each block is insert-ready LaTeX.

## A. [CORRECTION] Amount nonnegativity — insert after the `ΔQ_M^L, ΔQ_X^L` display

\[
	\begin{aligned}
		0 \leq L, \; \eta\,\Delta_i > 0, \; \Delta_i \geq 0
		\;\implies\;
		\Delta Q_M^L(i_K) \geq 0 \;\wedge\; \Delta Q_X^L(i_K) \geq 0
	\end{aligned}
\]
\(\eta\,\Delta_i > 0\) alone is insufficient: \(\eta,\Delta_i < 0\) gives \(i_K + \Delta_i < i_K\) and reverses both signs.
`VolInstrument.deltaQM_nonneg`, `deltaQX_nonneg`.

## B. [ADDITION] Token0 identity and closed-form cumulatives — insert after the cumulative definitions

\[
	\begin{aligned}
		\Delta Q_M^{L}(i_K) \, &= \, L(i_K)\Big[\frac{1}{p_{(\eta,\Delta_i)}(i_K)} - \frac{1}{p_{(\eta,\Delta_i)}(i_K+\Delta_i)}\Big]
	\end{aligned}
\]
For \(L \equiv \bar c\), over \(n\) grid steps from \(i_{\min}\):
\[
	\begin{aligned}
		Q_X^L \, &= \, \bar c\,\big[p_{(\eta,\Delta_i)}(i_{\min}+n\Delta_i) - p_{(\eta,\Delta_i)}(i_{\min})\big] \\
		Q_M^L \, &= \, \bar c\,\Big[\frac{1}{p_{(\eta,\Delta_i)}(i_{\min})} - \frac{1}{p_{(\eta,\Delta_i)}(i_{\min}+n\Delta_i)}\Big]
	\end{aligned}
\]
Both cumulatives are monotone in \(n\) (for \(L \geq 0\)), hence the inverse cumulatives
\((Q^L)^{-1}(\bar Q)\) are well-defined as least attaining steps.
`deltaQM_token0`, `cumulativeQX_const`, `cumulativeQM_const`, `cumulativeQ{M,X}_monotone`, `exists_least_reaching`.

## C. [CORRECTION] The delta-neutral \(\xi\) — insert after "The weights on the strike ... are encoded on \(\xi, \iota\)"

On the price grid \(K_{i} = \lambda^{i\,\Delta_i}\) the discretized strike-notional weights
of the log contract are exactly geometric,
\[
	\begin{aligned}
		\frac{K_{i+1}-K_i}{K_i^2} \, = \, (\lambda^{\Delta_i}-1)\,\big(\lambda^{-\Delta_i}\big)^{i},
	\end{aligned}
\]
but the per-tick \emph{liquidity} replicating the log contract obeys
\(\ell(K) \propto K^{-1/2}\) (curvature \(\ell(P) = -2P^{3/2}V''(P)\), \(V''=-1/P^2\)), i.e.
\[
	\begin{aligned}
		\xi^{\star} \, = \, \lambda^{-\Delta_i/2}
		\qquad \text{(NOT } \lambda^{-\Delta_i}\text{; the two differ by the tranche-gamma Jacobian).}
	\end{aligned}
\]
Moreover \(\sum_{i_K} \ell(\xi,\iota;i_K) = 1\), \(\ell > 0\) on both branches
\(\xi \in (0,1)\), \(\xi > 1\), and \(\ell \to 1/\iota\) as \(\xi \to 1\).
`GeomProfile.varswapWeight_geometric`, `logContractLiquidity_geometric`, `geomWeight_sum`, `geomWeight_pos`, `geomWeight_tendsto_uniform`, `VolInstrument.strikeWeight_bridge`.

## D. [CORRECTION] \(\upsilon\) of the portfolio is a \(\sigma^2\)-derivative — replace `Δ Π/Δσ = t/2`

\[
	\begin{aligned}
		\upsilon \, = \, \frac{\Delta\,\Pi^{\text{call | put}}(\cdot)}{\Delta\,\sigma^{2}} \, = \, \frac{t}{2},
		\qquad
		\frac{\Delta}{\Delta \sigma^{2}}\Big[\text{Id}_{N_\sigma}\,\Pi\Big] \, = \, 1, \;\; \text{Id}_{N_\sigma} = \tfrac{2}{t},
	\end{aligned}
\]
independent of \(p_{(\eta,\Delta_i)}\) — proved through the same finite-difference
operator \(\upsilon\) used for the contract (consistent dimensional slot with \(\Delta Q_v\)).
Also \(\Pi \geq 0\) with \(\Pi(p^{\star}) = 0\).
`FlairOptimization`-adjacent: `VolInstrument.variancePortfolio_upsilon`, `variancePortfolio_unit_upsilon`, `logPortfolio_nonneg`, `logPortfolio_atm`; operator: `Upsilon.upsilon`.

## E. [ADDITION] Multi-sigmoid \(\phi\) — insert after the \(\phi(\sigma(i(t));t)\) display

Writing \(u = \alpha_R/(1+\exp(\gamma_R(\beta_R - x)))\), \(x = \varphi(i_K;\Delta Q,0;t)/\varphi(i_K;0,L;t)\):
\[
	\begin{aligned}
		0 \leq u \leq \alpha_R, \qquad
		\bar\phi \, \leq \, \phi(\sigma) \, \leq \, \bar\phi + \Big(\sum_j \alpha_j\Big)u,
		\qquad \sigma \mapsto \phi(\sigma) \; \text{monotone } (\gamma_j > 0,\, \alpha_j \geq 0,\, u \geq 0).
	\end{aligned}
\]
The single-term case is the sigmoid fee schedule with steepness \(s_f = 1/\gamma\):
\(\bar\phi + \alpha_0\,\Lambda(\gamma_0(\sigma-\beta_0)) = f(\sigma;\, f_{\min}=\bar\phi,\, f_{\max}=\bar\phi+\alpha_0,\, \bar\sigma_f=\beta_0,\, s_f=\gamma_0^{-1})\).
`VolInstrument.sigmoidR_mem`, `multiFee_bounds`, `multiFee_monotone`, `multiFee_single_bridge`.

## F. [ADDITION] \(\otimes_\phi\) and hazards — insert in HAZARD RATES

\((\,[0,1],\, \otimes_\phi,\, 0\,)\) with \(\phi_M \otimes_\phi \phi_X = 1-(1-\phi_M)(1-\phi_X)\) is an abelian monoid
(commutative, associative, identity \(0\), closed on \([0,1]\), monotone), and under \(\phi = 1-e^{-\lambda}\):
\[
	\begin{aligned}
		\big(1-e^{-\lambda_M}\big) \otimes_\phi \big(1-e^{-\lambda_X}\big) \, = \, 1-e^{-(\lambda_M+\lambda_X)}
		\qquad\Longleftrightarrow\qquad \lambda \, \equiv \, \lambda_M + \lambda_X .
	\end{aligned}
\]
`VolInstrument.probOr_{eq,comm,assoc,zero,mem_Icc,mono,hazard}`.

## G. [ADDITION — replaces the bare \(\exists\,\Theta_\lambda\) claim] FLAIR sup: solved

Discretizing \(\lambda_{\text{FLAIR}}\) with flow weights \(w_t \geq 0\) and capital \(D_t > 0\):
\[
	\begin{aligned}
		\lambda_{\text{FLAIR}} \, = \, \bar\phi\, W \, + \, u \sum_j \alpha_j\, W_j,
		\qquad
		W = \sum_t \frac{w_t}{D_t}, \quad
		W_j = \sum_t \frac{\Lambda\big(\gamma_j(\sigma_t-\beta_j)\big)\, w_t}{D_t}, \quad 0 \leq W_j < W .
	\end{aligned}
\]
\[
	\begin{aligned}
		\Theta_{\lambda_{\text{FLAIR}}} \, = \, \{\bar\phi,\, \alpha,\, u(\alpha_R)\} :
		\quad
		\lambda_{\text{FLAIR}} \, \leq \, \Big(\bar\phi_{\max} + u_{\max}\sum_j \alpha_{j,\max}\Big)\, W,
	\end{aligned}
\]
attained bang-bang at the level corner for any fixed \((\beta,\gamma)\); in \((\beta,\gamma)\) the bound is
approached only as \(\beta \to -\infty\) (strict gap at every finite \(\beta\); the sup over unbounded shape
parameters is a saturation boundary, not a maximum). Caveat: this functional has no demand
elasticity — the fee–volume trade-off lives in the optimal-fee layer.
`FlairOptimization.flairMulti_affine`, `W_j_lt_W`, `flairMulti_le_corner`, `flairMulti_corner_attained_levels`, `flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`, `Theta_lambda_identification`.

## H. [FLAG — needs a decision, NOT proven either way] Sign in the \(\theta\) display

The doc's \(\theta\) has \(\exp\big(+[\cdot]^2/(2\sigma^2 t)\big)\); the Black–Scholes-type dt-leg decays
OTM, suggesting \(\exp\big(-[\cdot]^2/(2\sigma^2 t)\big)\). The Lean layer proves only the ATM closed form
\(\Theta_{ATM}(\tau) = k\sigma/\sqrt{8\pi\tau}\) (`Panoptic.theta_atm_closed_form`), where the exponent
vanishes — so it cannot discriminate the sign. Flagged for author decision.
