# DRAFT — the trading curve `φ_{χ_{X/M}}`, the SHARE parameter, and its link to `ς_{X/M}` and `η`

> STATUS: **SUPERSEDED 2026-08-03 — DO NOT USE AS A SOURCE.** The live
> `../plank/notes/VOLATILITY_INSTRUMENTS.md` already carries the correct semantics for this
> material and is the **canonical source for notation**. This file is kept only as the provenance
> record of where the share/substitution conflation entered the program. Its symbols were aligned
> and its false identification struck on 2026-08-03 so that a future reader is not misled by it —
> but nothing here should be transcribed into the document, and it is no longer a pending draft.
>
> **WHAT WAS WRONG WITH IT (provenance).** This draft asserted that the
> weighted-geometric exponent IS the substitution elasticity. It is a SHARE. The claim was the origin
> of the same false sentence later found in the live document and repaired at plank `838289f`, and it
> is refuted by `curvOfTilde_not_curvature` / `canon_Fcap_not_phiEps`. The symbol is aligned to the
> live document (`\chi_{X/M}`, the canonical source for notation) and the identification is struck.
> The MATHEMATICS is untouched — only the claim about what the exponent means. Placement: the pricing-geometry section, replacing the
> unlabelled lead-in "Consider a exogenous tuple flow … on the region:" that currently precedes the
> `φ` display. Block labels `S0`–`S3` (S = substitution) are PROPOSED — **and now mis-named**: this block is about the SHARE axis, not substitution. Confirm or rename (user call; not renamed unilaterally).
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

**DOC ↔ LEAN NAME MAP (binding).** The doc symbol is \(\chi_{X/M}\) — the **SHARE** (pool value share) parameter (user decision, 2026-08-02 as `\chi_{X/M}`, moved onto `\chi_{X/M}` by the 2026-08-03 rename; it replaced the earlier `η̃`). **It is NOT the substitution elasticity** — that claim was carried here and is REMOVED 2026-08-03. The exponent of a weighted-geometric form is a share, and identifying it with the elasticity of substitution is exactly the conflation refuted by `CurvatureTwo.curvOfTilde_not_curvature` and `CanonicalCurve.canon_Fcap_not_phiEps`. The object's own Lean identifiers settle it: `etaTilde` is the pool's ASSET VALUE SHARE, valued in `(0,1)`. The substitution parameter is a different axis, now written `\chi_{X/M}`, with elasticity of substitution `\bar\chi_{X/M} = 1/(1-\chi_{X/M})`. Its Lean identifiers are `etaTilde`, `etaOfTilde`, `tildeOfCurv`, fixed by the bundle submitted before the rename and NOT to be hand-edited — a file Aristotle has proven is never modified. This doc-glyph / Lean-name split is the project's standing practice: `ℙ_{Δ_ARB}`↔`ptrade`, `ς_{X/M}`↔`curvIndex`, `λ̃_JIT`↔`lamJITtax`. <!-- notation-map -->

## **S1. [THE TRADING CURVE]** \(\varphi_{\chi_{X/M}}\)

The exogenous flow \(\Delta Q = (\Delta Q_M, \Delta Q_X)\) moves along the TRADING CURVE

\[
	\begin{aligned}
		\varphi_{\chi_{X/M}}\,(i_K ; \Delta Q, L) \, &= \, \big(\Delta Q_M^{L}(i_K) + \Delta Q_M\big)^{\chi_{X/M}}\cdot\big(\Delta Q_X^{L}(i_K) + \Delta Q_X\big)^{1-\chi_{X/M}}, \qquad \chi_{X/M} \in (0,1)
	\end{aligned}
\]

\(\chi_{X/M}\) = the SHARE parameter = the exponent on the ASSET leg = the pool's asset VALUE SHARE. (This line previously read "the SUBSTITUTION PARAMETER" — a second copy of the removed claim, and self-contradictory with its own "VALUE SHARE" clause.) \(\varphi_{1/2}\) is the current constant-product case.

## **S2. [THE IDENTIFICATION]** \(\chi_{X/M} \leftrightarrow \eta \leftrightarrow \varsigma_{X/M}\)

\[
	\begin{aligned}
		\frac{\chi_{X/M}}{1-\chi_{X/M}} \, = \, \frac{p_{(\eta,\Delta_i)}(i_K+1)}{p_{(\eta,\Delta_i)}(i_K)} \, = \, \lambda^{\eta\,\Delta_i/2}
	\end{aligned}
\]

— the weight ratio IS the per-tick square-root-price step. Both directions follow:

\[
	\begin{aligned}
		\chi_{X/M}\,(\eta) \, &= \, \Lambda\Big(\frac{\eta\,\Delta_i\,\ln\lambda}{2}\Big), \qquad\qquad
		\eta\,(\chi_{X/M}) \, = \, \frac{2}{\Delta_i\,\ln\lambda}\,\ln\frac{\chi_{X/M}}{1-\chi_{X/M}} \\
		\varsigma_{X/M}(\chi_{X/M}) \, &= \, 1 - \Big(\frac{1-\chi_{X/M}}{\chi_{X/M}}\Big)^{\Delta_i}, \qquad
		\chi_{X/M}\,(\varsigma_{X/M}) \, = \, \frac{1}{1 + (1-\varsigma_{X/M})^{1/\Delta_i}}
	\end{aligned}
\]

CONSISTENCY (not a new definition): composing recovers E1 exactly, since the per-SPACING step is the per-TICK step raised to \(\Delta_i\),

\[
	\begin{aligned}
		\varsigma_{X/M}\big(\chi_{X/M}(\eta)\big) \, = \, 1 - \big(\lambda^{-\eta\Delta_i/2}\big)^{\Delta_i} \, = \, 1 - \lambda^{-\Delta_i^{2}\eta/2}
	\end{aligned}
\]

## **S3. [DOMAIN]** the three admissibility conditions coincide

\[
	\begin{aligned}
		\eta\,\Delta_i \, > \, 0 \quad &\Longleftrightarrow \quad \chi_{X/M} \, > \, \tfrac{1}{2} \quad \Longleftrightarrow \quad \varsigma_{X/M} \, \in \, (0,1) \\
		\eta \, = \, 0 \quad &\Longleftrightarrow \quad \chi_{X/M} \, = \, \tfrac{1}{2} \quad \Longleftrightarrow \quad \varsigma_{X/M} \, = \, 0
	\end{aligned}
\]

(flat grid = symmetric constant-product pool = zero curvature; the first line is the hypothesis Aristotle ADDED to `VolInstrument.deltaQM_nonneg`, recovered here as an economic condition.)

> CONSEQUENCE FOR E8(6): the factor-share identification was recorded UNAVAILABLE because \(\eta^{\star} \approx 458/\Delta_i^{2}\) cannot be a Cobb–Douglas share. It never had to be — the share is \(\chi_{X/M}^{\star} = \Lambda(\eta^{\star}\Delta_i\ln\lambda/2) \in (0,1)\) for EVERY \(\eta\). E8(6) is reachable through \(\chi_{X/M}\), not through \(\eta\) directly.
> ALREADY PROVEN (E1/pricing geometry): `curvIndex` \(= 1 - \lambda^{-\Delta_i^2\eta/2}\), `curvIndex_strictMono`, `curvIndex_mem_Ioo`, `priceEta_step_ratio`, `deltaQM_token0`, `deltaQM_nonneg` (\(\eta\Delta_i > 0\)).
> PROPOSED, NOT YET PROVEN: every display in S2 and S3, and the E8(6) consequence. Formalization target.
