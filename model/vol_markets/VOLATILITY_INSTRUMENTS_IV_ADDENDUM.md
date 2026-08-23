# DRAFT — σ_IV blocks (V0–V9) for `## IMPLIED VOLATILITY` of VOLATILITY_INSTRUMENTS.md

> STATUS: DRAFT pending HEAVY USER APPROVAL. Nothing inserted. No Lean exists for V1–V8.
> Source: Kristensen, *Perpetual Options with Uniswap V3* (2024), `refs/lp-derivatives/kristensen-perpetual_options_uniswap_v3-2024.pdf`. Page numbers are the book's PRINTED footer (PDF index = printed + 7).
> Research record: `.planning/implied-vol/IV-RESEARCH.md`. Minimal prose, maximal math.

## **V0. [NOTATION-MAP]**

Kristensen's `IV` → this document's EXISTING \(\sigma_{IV}\), specifically \(\sigma_{IV}^{ATM}\) — his derivation is at-the-money by construction (\(k = p_0\), p. 66). **NO new volatility symbol is minted.** <!-- notation-map -->
Kristensen's `VOL` → \(w_t/\Delta t\) (per-step traded amount, `### FLAIR`). <!-- notation-map -->
Kristensen's `AMT_tick` → the tick's inventory value; aggregate \(D_t\). <!-- notation-map -->
Kristensen's `VOL/AMT_tick` → \(\nu_t = w_t/D_t\) (M6b). `ν` is REUSED, never re-minted. <!-- notation-map -->
Kristensen's `AMT_pos` → \(\sum_{i_K} L(i_K) = \Delta Q_v^{\star}\). <!-- notation-map -->
Kristensen's `k = \sqrt{p_a p_b}` → \(\bar p (i_K)\) of V1. <!-- notation-map -->
Kristensen's `TIT M` → written out as \(\int_{t_0}^{t}\mathbb{P}_{i(s) \in K}\,ds\); NO symbol minted (`Υ` REJECTED — confusable with \(\upsilon\), the vega, 38 uses). <!-- notation-map -->
Kristensen's `r` (range factor) → \(\lambda^{n\Delta_i\eta/2}\); bare `r` is NEVER written here. <!-- notation-map -->
Kristensen's **`α` (risk-free rate)** COLLIDES with \(\alpha_j, \alpha_R\) (fee amplitudes, \(\Theta_{\phi}\)) → REMAPPED to \(r_{\text{fix}}\) (V8). <!-- notation-map -->
Kristensen's `ϕ` → this document's \(\phi\), unchanged. <!-- notation-map -->

**NEW SYMBOLS (2 elasticities + 1 parameter + 1 derived; freeness verified by grep against `VOLATILITY_INSTRUMENTS.md`):**

| Symbol | Meaning | Freeness | Family rule (BINDING 2026-08-03) |
|---|---|---|---|
| \(\epsilon_{\text{hold},\sigma},\ \epsilon_{\text{lend},\sigma}\) | σ-elasticities of the two legs (V4) | only \(\epsilon_{X/M}\) exists (39 hits); `\text{hold}`/`\text{lend}` subscripts: 0 hits | ε = ELASTICITIES, always subscripted ✓ |
| \(r_{\text{fix}}\) | exogenous fixed-income rate (V8) | `\rho` free but RESERVED by Lean `phiCES ρ` = doc \(\epsilon_{X/M}\); `\varrho` (66), `\vartheta` (21), `\varpi` (16), `α`, bare `i` all TAKEN | roman, subscript MANDATORY (bare `r` = Kristensen's range factor) | <!-- notation-map -->
| \(T_c\) | rate-crossing horizon (V8) | `T`, `T^\star`, `T^\star_{\text{joint}}` in use; `T_c` free | derived, not a parameter |

**LEAN-SIDE TRAP (any bundle prompt MUST carry this):** `PhiCES.phiCES (ρ ε x y) = (ε·x^ρ + (1−ε)·y^ρ)^(1/ρ)` — Lean `ε` is the SHARE (doc \(\chi_{X/M}\)), Lean `ρ` is the SUBSTITUTION exponent (doc \(\epsilon_{X/M}\)). **The two letters are SWAPPED relative to this document.** The line-407 mapping note covers `EtaTilde`, not `PhiCES`. <!-- notation-map -->

## **V1. [TICK VALUE-BALANCE] the \(\chi_{X/M} = 1/2\) reading is EARNED, not imposed**

With \(s(i) := p_{(\eta,\Delta_i)}(i)\), \(\Delta s := s(i_K + \Delta_i) - s(i_K)\), and the document's standing guard \(0 \leq L,\ \eta\Delta_i > 0,\ \Delta_i \geq 0\):

\[
	\begin{aligned}
		\Delta Q_M^{L}(i_K) \, = \, \frac{L(i_K)\,\Delta s}{s(i_K)\,s(i_K+\Delta_i)}, \qquad
		\Delta Q_X^{L}(i_K) \, = \, L(i_K)\,\Delta s
	\end{aligned}
\]

\[
	\begin{aligned}
		\boxed{\;\bar p (i_K)\cdot \Delta Q_M^{L}(i_K) \, = \, \Delta Q_X^{L}(i_K)\;}, \qquad
		\bar p (i_K) \, := \, p_{(\eta,\Delta_i)}(i_K)\cdot p_{(\eta,\Delta_i)}(i_K + \Delta_i)
	\end{aligned}
\]

EXACT, all \(L, \eta, \Delta_i\). The tick inventory is value-balanced exactly at the GEOMETRIC MEAN of the tick's two edge prices — which is Kristensen's \(k = \sqrt{p_a p_b}\) (§3.5, p. 70). The equal-share weights of V3 are therefore a THEOREM of the grid, not a modelling choice.

> LEAN: none. Rests on `VolInstrument.deltaQM`, `deltaQX`, `deltaQM_token0`, `deltaQM_nonneg`, `deltaQX_nonneg` (all PROVEN). Target **IV1**.

## **V2. [FACTORIZATION] the utilization argument is a GEOMETRIC MEAN of per-leg turnovers**

Per-leg turnovers \(R_M := \Delta Q_M/\Delta Q_M^{L}(i_K)\), \(R_X := \Delta Q_X/\Delta Q_X^{L}(i_K)\). From Theorem 1's argument and \(\varphi_{1/2,\,0}(a,b) = \sqrt{ab}\):

\[
	\begin{aligned}
		\frac{\varphi_{1/2,\,0}(i_K;\Delta Q,0;t)}{\varphi_{1/2,\,0}(i_K;0,L;t)}
		\, = \, \frac{\sqrt{\Delta Q_M\,\Delta Q_X}}{\sqrt{\Delta Q_M^{L}(i_K)\,\Delta Q_X^{L}(i_K)}}
		\, = \, \sqrt{R_M\,R_X}
	\end{aligned}
\]

**GUARD (BLOCKER, restated inline and NOT inherited from prose):** \(\Delta Q_M, \Delta Q_X \geq 0\) and \(L(i_K) > 0\). The document does not state whether the flow tuple \(\Delta Q = (\Delta Q_M, \Delta Q_X)\) is SIGNED or a pair of MAGNITUDES. **If signed, \(\sqrt{\Delta Q_M \Delta Q_X}\) is not real on exactly the swaps this factor is meant to measure, and Theorem 1's \(u \in [0,\alpha_R]\) is ill-posed.** `VolInstrument.sigmoidR`'s docstring already hedges the vanishing-denominator case. This is the `ptrade` negative-fee pole pattern; it must be ruled on before any bundle.

> LEAN: none. Target **IV2**.

## **V3. [THE BRIDGE] Kristensen's ratio is the ARITHMETIC member — AM–GM separates them**

Aggregating both legs in value at \(\bar p\), and using V1 (so the two value weights are exactly \(\tfrac12,\tfrac12\)):

\[
	\begin{aligned}
		\nu \, = \, \frac{\texttt{VOL}}{\texttt{AMT}_{\text{tick}}}
		\, = \, \frac{\bar p\,\Delta Q_M + \Delta Q_X}{\bar p\,\Delta Q_M^{L} + \Delta Q_X^{L}}
		\, = \, \frac{R_M + R_X}{2}
	\end{aligned}
\]

\[
	\begin{aligned}
		\boxed{\;\sqrt{R_M R_X} \; \leq \; \nu \;}, \qquad
		\text{equality} \iff R_M = R_X
	\end{aligned}
\]

**Theorem 1's \(u\)-argument and Kristensen's `VOL/AMT` are NOT the same object.** They coincide exactly on LEG-BALANCED flow (a swap executed at \(\bar p\), leaving the tick's inventory ratio fixed); off it, the document's object is strictly smaller. **On ONE-SIDED flow the geometric member COLLAPSES to \(0\) while \(\nu > 0\)** — the inequality survives, the identification does not.

TIME BASE (open): Kristensen's \(\nu\) is per DAY, the \(u\)-argument's \(\Delta Q\) is per STEP. \(\beta_R\) is calibrated in whatever unit \(\Delta Q\) carries. The document states no time base for \(\Delta Q\); the two ratios are commensurable only after it does.

> LEAN: none. Target **IV2**.

## **V4. [THE CES UNIFICATION] the two members, and where \(\epsilon_{X/M}\) actually enters**

\[
	\begin{aligned}
		x_{\chi_{X/M},\,\epsilon_{X/M}} \, := \, \frac{\varphi_{\chi_{X/M},\,\epsilon_{X/M}}(\Delta Q_M, \Delta Q_X)}{\varphi_{\chi_{X/M},\,\epsilon_{X/M}}\big(\Delta Q_M^{L}(i_K), \Delta Q_X^{L}(i_K)\big)}
	\end{aligned}
\]

\[
	\begin{aligned}
		\epsilon_{X/M} = 0,\ \chi_{X/M} = \tfrac12 \; &\Longrightarrow \; x \, = \, \sqrt{R_M R_X} \quad \text{(Theorem 1's } u\text{-argument)} \\
		\epsilon_{X/M} = 1,\ \tfrac{\chi_{X/M}}{1-\chi_{X/M}} = \bar p \; &\Longrightarrow \; x \, = \, \nu \quad \text{(Kristensen's VOL/AMT — LINEAR, } \kappa_{\varphi} = 0,\ \bar\epsilon_{X/M} = \infty)
	\end{aligned}
\]

Under V1 the denominator is symmetric, so \(x_{1/2,\,\epsilon_{X/M}} = M_{\epsilon_{X/M}}(R_M,R_X)\) is the power mean and is **increasing in \(\epsilon_{X/M}\)** — V3's AM–GM is the \(\epsilon_{X/M}: 0 \to 1\) case.

INVARIANCE (why the price normalization is harmless): \(\varphi_{\chi_{X/M},\epsilon_{X/M}}(p\,Q_X, Q_M) = (\chi_{X/M}p^{\epsilon_{X/M}} + 1 - \chi_{X/M})^{1/\epsilon_{X/M}}\cdot \varphi_{\chi'_{X/M},\epsilon_{X/M}}(Q_X,Q_M)\) with \(\chi'_{X/M} = \chi_{X/M}p^{\epsilon_{X/M}}/(\chi_{X/M}p^{\epsilon_{X/M}} + 1 - \chi_{X/M})\); the prefactor is common to numerator and denominator, so **applying the tick price to a leg is exactly a shift along the SHARE axis and \(x\) is invariant.**

**WARNING — the ratio is NOT monotone in \(\epsilon_{X/M}\) in general.** Numerator and denominator are BOTH increasing in \(\epsilon_{X/M}\) by power-mean monotonicity; the quotient's direction is indeterminate. The monotonicity above holds ONLY because V1 makes the denominator's legs equal, pinning it to \(1\). Without V1 the display is FALSE.

> LEAN: none. Rests on `PhiCES.phiCES_homogeneous/_pos/_mono`, `phiCES_zero_half_eq_geom`, `phiCES_one`, `phiCES_tendsto_phiEps` (all PROVEN). Targets **IV3**, **IV4**.

## **V5. [THE LADDER] Kristensen's Remark 3.8 PINS \(\xi\) — and it pins it to \(\xi^{\star}\)**

Static part of Kristensen's denominator, from V1 (\(\texttt{AMT}_{\text{tick}} = \bar p\Delta Q_M^L + \Delta Q_X^L = 2\Delta Q_X^L\)):

\[
	\begin{aligned}
		\texttt{AMT}_{\text{tick}}(i_K) \, = \, 2\,\bar L\,\ell\,(\xi,\iota;i_K)\cdot\Delta s(i_K), \qquad
		\Delta s(i_K) \, = \, s(i_K)\,(g - 1), \quad g := \lambda^{\eta\Delta_i/2}
	\end{aligned}
\]

\[
	\begin{aligned}
		\texttt{AMT}_{\text{tick}}(\cdot) \ \text{constant in } i_K
		\;\iff\; \xi\,g = 1
		\;\iff\; \boxed{\;\xi \, = \, \lambda^{-\eta\Delta_i/2}\;}
		\;\overset{\eta = 1}{=}\; \lambda^{-\Delta_i/2} \, = \, \xi^{\star}
	\end{aligned}
\]

**Kristensen's constant-`AMT_tick` approximation (Remark 3.8, p. 58, where he calls it a narrow-range stabilization) is NOT an approximation in this framework — it is the exact statement that the ladder is the log-contract / variance-swap ladder.** Equivalently: \(\xi^{\star}\) is the unique ladder with UNIFORM NOTIONAL PER TICK, which is the geometry under which (3.14)–(3.16) hold exactly rather than approximately.

**\(\eta \neq 1\) SPLITS THE TWO \(\xi\)'s.** The coincidence is an \(\eta = 1\) statement: the AMT-flattening ladder is \(\lambda^{-\eta\Delta_i/2}\), the log-contract ladder is \(\lambda^{-\Delta_i/2}\). Which is primitive off \(\eta = 1\) is an OPEN design question this block creates and does not answer.

INDEX ORIGIN (must be pinned before formalizing): \(\ell(\xi,\iota;i_K) \propto \xi^{i_K}\) with \(i_K\) counted from \(i_{\min}\) (`GeomProfile.geomWeight`), not from the strike.

> LEAN: none. Rests on `GeomProfile.geomWeight_sum/_pos/_tendsto_uniform`, `logContractLiquidity_geometric`, `varswapWeight_geometric`, `VolInstrument.strikeWeight_bridge` (all PROVEN). Target **IV5**.

## **V6. [THE ACCUMULATOR] the time integral is the OCCUPATION TIME, not the volume**

\[
	\begin{aligned}
		\text{hold}(T) \, = \, \phi \cdot \underbrace{\frac{1}{T}\int_{t_0}^{t_0+T}\!\!\mathbb{P}_{i(s)\in K}\,ds}_{\text{occupation fraction}} \cdot\, T \cdot \nu
		\, = \, \phi \sum_{t} \mathbb{1}[\,i(t) \in K\,]\;\nu_t
		\, = \, \phi\,W \Big|_{\,w_t = 0 \text{ off-range}}
	\end{aligned}
\]

\(\nu_t = w_t/D_t\) IS Kristensen's `VOL/AMT_tick`, per block instead of per day; \(W = \sum_t \nu_t\) is the \(T\)-day accumulation; and the occupation fraction is the measure of \(\{t : \nu_t > 0\}\) — the very set M6b's equality condition is stated on. **NO new object is required.** At constant fee, \(\lambda_{\text{FLAIR}} = \phi W\) is exactly Kristensen's holding return; the dynamic-fee generalization is this document's own \(\lambda_{\text{FLAIR}} = \bar\phi W + u\sum_j \alpha_j W_j\).

On the writing side, `Panoptic.streamingPremium` \(\Sigma_N = \sum_{j<N}\theta_j\Delta t\) is the option's accumulated time decay. **The streamia assignment \(\phi \overset{\text{streamia}}{\longleftarrow} \theta\) taken as an AGGREGATE equality rather than a per-step identification IS Kristensen's implied-volatility condition.**

> LEAN (proved, reused unchanged): `FlairOptimization.flairMulti_affine`, `W_j_lt_W`; `Panoptic.streamingPremium`, `streamingPremium_succ`.

## **V7. [THE DEFINITION] \(\sigma_{IV}^{ATM}\), two readings — and the \(2\) is GAUSSIAN**

**REDUCED (observable, model-free):**

\[
	\begin{aligned}
		\boxed{\;\sigma_{IV}^{ATM}(T) \; = \; \sqrt{\tfrac{2\pi}{T}}\;\lambda_{\text{FLAIR}}(T)\;}
	\end{aligned}
\]

\(\lambda_{\text{FLAIR}}\) dimensionless, \(\sqrt{2\pi/T}\) of dimension \(T^{-1/2}\) ⟹ \(\sigma_{IV}^{ATM}\) is per \(\sqrt{\text{time}}\), which is why Kristensen's daily figure carries \(\sqrt{365}\) to annualize (Ex. 3.10, p. 69). **\(\sigma_{IV}^{ATM}\) is NOT dimensionless.** This reading makes implied volatility a FUNCTIONAL OF \(\Theta_{\phi}\) — new relative to the anchor, which has only a constant fee.

**STRUCTURAL (closed form), when the occupation law supplies \(W \propto 1/\sigma\):**

\[
	\begin{aligned}
		\sigma_{IV}^{ATM} \, = \, 2\,\sqrt{\;\phi\cdot\frac{\eta\,\Delta_i\ln\lambda}{2}\cdot\bar\nu\;}, \qquad \bar\nu := W/T
	\end{aligned}
\]

REDUCTION (numerically exact to 9 s.f.): at \(\eta = 1\), \(\lambda = 1.0001\), \(\Delta_i = t_s\), one has \(\tfrac{\eta\Delta_i\ln\lambda}{2} = t_s\!/20001\); Uniswap pairs \((\phi,t_s) \in \{(0.05\%,10),(0.3\%,60),(1\%,200)\}\) so \(t_s/20001 = \phi\) and the display collapses to Kristensen's \(2\phi\sqrt{\nu}\) (eq. 3.16, p. 69). Also \(2/\ln\lambda = 20000.9999\ldots\), so his `20001` IS \(2/\ln\lambda\).

**THE \(\phi^2\) IS AN ARTIFACT.** In general the exponent on the fee is \(1/2\), not \(1\): \((\sigma_{IV}^{ATM})^2 = 4\,\phi\,(t_s/20001)\,\nu\). The square exists only because Uniswap PAIRS its fee tiers with its tick spacings. Here \(\Theta_p = \{\eta,\Delta_i\}\) and \(\Theta_{\phi}\) are INDEPENDENT, so this framework's \(\sigma_{IV}^{ATM}\) carries \(\sqrt{\phi}\), and the fee and the grid are two separate levers on implied volatility.

**THE \(2\) IS A GAUSSIAN ARTIFACT, NOT A CURVE PARAMETER — THE \(\chi_{X/M}=1/2\) READING OF IT IS REFUTED:**

\[
	\begin{aligned}
		4 \, = \, \sqrt{\tfrac{8}{\pi}\cdot 2\pi} \, = \, \sqrt{16}, \qquad
		\underbrace{\sqrt{8/\pi}}_{\text{Erf}(z)\,\approx\,2z/\sqrt{\pi}\ \text{(p. 57)}} \;\cdot\;
		\underbrace{\sqrt{2\pi}}_{1/\varphi_{\mathcal N}(0)\ \text{(p. 66)}}
	\end{aligned}
\]

Both factors come from the normal distribution — the Erf Taylor expansion of the occupation time and the standard normal density at zero in the ATM premium. **Neither \(\chi_{X/M}\) nor \(\epsilon_{X/M}\) appears anywhere in the anchor's derivation.** \(8/\pi \cdot 2\pi = 16\) is a coincidence of two Gaussian constants that happens to be a perfect square.

**THE \(\sqrt{\ }\) IS A RATIO OF σ-ELASTICITIES — and THIS one is genuinely a \(1/2\):**

\[
	\begin{aligned}
		\text{hold} \propto \sigma^{-\epsilon_{\text{hold},\sigma}}\!\cdot\! K, \quad
		\text{write} \propto \sigma^{+\epsilon_{\text{lend},\sigma}}
		\;\Longrightarrow\;
		\sigma_{IV}^{ATM} \, = \, (C\,K)^{\,1/(\epsilon_{\text{hold},\sigma} + \epsilon_{\text{lend},\sigma})}
	\end{aligned}
\]

with \(\epsilon_{\text{hold},\sigma} = 1\) (occupation time \(\propto 1/\sigma\)) and \(\epsilon_{\text{lend},\sigma} = 1\) (ATM premium \(\propto \sigma\)), giving \(1/2\). It ceases to be \(1/2\) the moment either leg's σ-elasticity changes.

**SCOPE (the anchor's own guards, p. 57 and p. 66, NOT to be silently inherited):** \(T(\mu - \sigma^2/2) \ll 1\); start at the geometric mean \(p_0 = \sqrt{p_a p_b}\); \(\mu \ll \sigma^2/2\); \(\sigma\sqrt T/2 \ll 1\); GBM. **The occupation law is GBM-SPECIFIC and is NOT transferred to this framework's grid by any display above.**

> LEAN: none. Targets **IV6**, **IV8** (IV8 BLOCKED: the structural reading needs a σ-dependence law for \(W\) that this document does not have, so \(\sigma_{IV}^{ATM}\) is a FIXED POINT, not a closed form, until that law is supplied).

## **V8. [OPPORTUNITY COST] the LEND leg is OPTION WRITING — the interest rate is a NEW PARAMETER**

**FALSE FRIEND, stated first:** §3.4.2 "Lending a Uniswap V3 LP Position" (p. 65) means **WRITING a cash-secured put / covered call** — "a fair price for lending the LP position is the premium from the sold put (or call)". It does NOT mean fixed-income lending. The comparison is RISKY-vs-RISKY. Kristensen's risk-free rate \(\alpha\) appears ONLY in the exact Black–Scholes premium and is ANNIHILATED by the ATM approximation (p. 66); **his hold-vs-write condition and eq. (3.16) contain NO interest rate.**

The condition he does imply, in this document's objects:

\[
	\begin{aligned}
		\text{HOLD} \succ \text{WRITE}
		\;\iff\; \lambda_{\text{FLAIR}}(T) \, > \, \sigma_R\sqrt{\tfrac{T}{2\pi}}
		\;\iff\; \bar\nu \, > \, \frac{\sigma_R^{2}}{4\,\phi\cdot\frac{\eta\Delta_i\ln\lambda}{2}}
	\end{aligned}
\]

collapsing to \(\nu > (\sigma/2\phi)^2\) (p. 67) at \(\eta = 1,\ \Delta_i = 20001\phi\).

**THE THIRD LEG DOES NOT EXIST IN THIS DOCUMENT.** Grep evidence: `risk-free`, `risk free`, `interest rate`, `discount`, `yield`, `Sharpe`, `opportunity cost` — ZERO matches outside the author's own note. `numeraire` occurs only in the Capponi canonical-curve block (\(p_B = 1\)), a price normalization, not a rate. **An exogenous interest rate \(r_{\text{fix}}\) is a NEW PARAMETER and is flagged as such in V0; it is not introduced by any display above.**

**\(p_{\text{risk}}\) IS NOT IT.** The protocol computes \(p_{\text{risk}} = \text{oracle}/(1-h)\) (`VegaIssuanceLib.haircut_risk_price`), a HAIRCUT-INFLATED COLLATERAL PRICE — "collateral per L unit", exogenously set, no time dimension, no accrual, no alternative return. It is **not** a market price of risk and **not** a yield. It is the natural SOCKET for \(r_{\text{fix}}\) (the only exogenous oracle-fed price in the vega stack), but it does not currently carry a rate; wiring one in is plank-track scope, not this document's.

Conditional on \(r_{\text{fix}}\) being approved, the three-way comparison and its horizon:

\[
	\begin{aligned}
		\underbrace{\lambda_{\text{FLAIR}}(T)}_{\mathcal{O}(\sqrt T)} \;\; \text{vs} \;\;
		\underbrace{\sigma_{IV}^{ATM}\sqrt{\tfrac{T}{2\pi}}}_{\mathcal{O}(\sqrt T)} \;\; \text{vs} \;\;
		\underbrace{e^{\,r_{\text{fix}}T} - 1}_{\mathcal{O}(T)}
	\end{aligned}
\]

\[
	\begin{aligned}
		r_{\text{fix}}T \, = \, \sigma\sqrt{\tfrac{T}{2\pi}}
		\;\Longrightarrow\;
		T_c \, = \, \frac{\sigma^{2}}{2\pi\,r_{\text{fix}}^{2}}, \qquad
		\text{fixed income binds} \iff \sigma \, \leq \, r_{\text{fix}}\sqrt{2\pi T}
	\end{aligned}
\]

**HONEST QUANTITATIVE CAVEAT:** at \(r_{\text{fix}} = 5\%/\text{yr}\), \(T = 1\,\text{yr}\), the threshold is \(\sigma \leq 12.5\%/\text{yr}\). **At crypto volatilities the fixed-income leg is essentially never binding.** \(r_{\text{fix}}\) is conceptually necessary and quantitatively inert in the current regime; this block does not dress it up as a live lever.

> LEAN: none. Target **IV7**.

## **V9. [SYNTHESIS] the LEVEL the Greeks block is missing**

The Greeks blocks already carry \(\sigma_{IV}\), as a SHAPE normalized by an ATM level this document never pins, and the control matrix declares that row DIAGNOSTIC for exactly that reason:

\[
	\begin{aligned}
		\frac{\sigma_{IV}(K)}{\sigma_{IV}^{ATM}} \, = \, f(K/p;\,\eta_L) \quad \text{(shape, }\delta\text{- and }\bar L\text{-independent)}, \qquad
		\sigma_{IV}^{ATM} \, = \, 2\sqrt{\phi\cdot\tfrac{\eta\Delta_i\ln\lambda}{2}\cdot\bar\nu} \quad \text{(level, V7)}
	\end{aligned}
\]

⟹ **level and shape TOGETHER determine the whole smile from pool observables** — level from turnover and the \((\phi,\eta,\Delta_i)\) pair, shape from \(\eta_L\). NO new symbol is required for this.

**E8(6) IS NOT TOUCHED.** The level carries the GRID \(\eta\); the shape carries the CEV \(\eta_L\). \(\eta_L = \eta\) remains OPEN and no display above assumes it.

## **OPEN (this addendum's own)**

1. **[BLOCKER] Signed or magnitude \(\Delta Q\) legs?** V2's guard. Theorem 1's \(u\) is ill-posed on signed legs.
2. **[MAJOR] Does \(W\) depend on \(\sigma\)?** Without a law, V7's structural reading is a fixed point, not a closed form. IV8 is blocked on it.
3. **[MAJOR] Time base of \(\Delta Q\)** (V3) — \(\beta_R\) is calibrated in an unstated unit.
4. **[MAJOR] Two symbols for one concept:** \(\sigma^2_I(0)\) (line 160, declared, never defined) and \(\sigma_{IV}\) (Greeks, defined and used). PRE-EXISTING; raised, not resolved; this addendum uses \(\sigma_{IV}^{ATM}\) only.
5. **[MINOR] Which ladder is primitive off \(\eta = 1\)?** (V5.)
6. **[MINOR] Suspected typo, \(\lambda_{\text{FLAIR}}\) denominator:** \(p\,Q_M^L(\sum L) + Q_M^L(\sum L)\) — BOTH terms are \(Q_M^L\). The proved discretization uses an abstract \(D_t\), so nothing downstream is affected; the continuous display looks wrong.
7. **[MINOR] Anchor typo to record:** p. 67 states \(\phi = 0.0003\); the pool is the 0.3% pool and BOTH printed numerics (1.53%, 76.1) require \(\phi = 0.003\). Recomputed both ways.
