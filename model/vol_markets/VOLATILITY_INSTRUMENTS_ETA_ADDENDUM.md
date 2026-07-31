# PROPOSED addendum to `VOLATILITY_INSTRUMENTS.md` — the `## ETA` section: the curvature controller and the interior η*

> STATUS: DRAFT — pending two-reviewer gate and user approval.
> Anchor: Capponi & Jia, *The Adoption of Blockchain-Based Decentralized Exchanges*,
> arXiv:2103.08842v4 (2021-07-21), read from `../plank/refs/mev/CapponiJiaAdoptionDEX.pdf`.
> The curvature results transcribed here are **Lemma 3**, **Proposition 5** and **Proposition 6**.
> Notation: η is PROTECTED and is this document's pricing-kernel exponent throughout. The <!-- notation-map -->
> paper's curvature index `k` is written `χ`; his investor private-use premium `α` is written <!-- notation-map -->
> `ϱ_I` and his price-shock magnitude `β` is written `ϱ_S`; his fee `f` IS this document's `φ`; <!-- notation-map -->
> his arrival and shock probabilities `θ, κ_I, κ_com, κ₁, κ₂` are never named and are absorbed <!-- notation-map -->
> into the four constants `ϖ_A, ϖ_I, ϖ_H, ϖ_D`. <!-- notation-map -->
> Minimal prose; each block is insert-ready LaTeX.

## **E0. [NOTATION]**

The paper's curvature index `k` is transcribed as `χ` (`\chi`); Lean `curv` / `curvIndex`. <!-- notation-map -->
The paper's investor private-use premium `α` is transcribed as `ϱ_I` (`\varrho_I`); Lean `premInv`. <!-- notation-map -->
The paper's price-shock magnitude `β` is transcribed as `ϱ_S` (`\varrho_S`); Lean `premShock`. <!-- notation-map -->
The paper's proportional trading fee `f` is IDENTIFIED with this document's `φ` (`\varphi`) and is not renamed; this document's `α_j`, `β_j`, `γ_j` remain the `Θ_φ` sigmoid parameters and are always subscripted. <!-- notation-map -->
The paper's probabilities `θ, κ_I, κ_com, κ₁, κ₂` are NEVER NAMED; they enter only as the four constants below. `θ` collides with this document's option theta and `κ` with the Phase-11 scalarization weight. <!-- notation-map -->
The paper's Proposition-5 coefficients `τ₁, τ₂, τ₃` are transcribed as `c₁, c₂, c₃` (Lean `cOne`, `cTwo`, `cThree`), because `τ` is TAKEN by this document's `τ = τ_MEV` (block M9). <!-- notation-map -->
The symbol `ν` is TAKEN by block M6b (`ν_t = w_t/D_t`) and is NEVER introduced here. <!-- notation-map -->

The four absorbed constants, each \(\geq 0\) and each constant in \(\chi\):

\[
	\begin{aligned}
		\varpi_A \;&:\; \text{probability an arbitrage occurs in a period} \\
		\varpi_I \;&:\; \text{probability an investor arrives} \\
		\varpi_H \;&:\; \text{the hold-benchmark coefficient, } \; \mathbb{E}[R_A] = \varpi_H\,\varrho_S \\
		\varpi_D \;&:\; \text{the constant subtracted in the LP excess return}
	\end{aligned}
\]

Standing hypotheses for every display below: \(0 \leq \varphi < \varrho_S \leq \varrho_I\), \(0 < \Delta_i\), \(1 < \lambda_{\text{tick}}\).

TICK-BASE READING: in this section an unsubscripted `\lambda` inside an exponential is the tick base λ = 1.0001 (`PosSpec.lam`), never a hazard; every hazard of `### MEV` is subscripted (`\lambda_{\text{ARB}}`, `\lambda_{\text{FLAIR}}`, `\lambda_{\text{MEV}}`).

NOT PROBABILITIES: `\varrho_I` and `\varrho_S` are VALUATION PREMIA — they are not probabilities, they are not arrival probabilities, and they are not confined to \([0,1]\). `\varrho_I` is the markup a type-`i` investor places on token `i` and may exceed 1; `\varrho_S` is the magnitude of the price shock. Under a probability reading the closed form \(\chi^{\star} = 1 - \sqrt{(1+\varphi)/(1+\varrho_I)}\) is uninterpretable.

THE η CONVENTION BRIDGE, AS TWO SEPARATE CLAIMS. (i) THE EXPONENT IDENTITY (provable algebra): on integer ticks, `priceEta η Δ_i i = p_eta(lam, Δ_i, η/2, i) = P_half(lam, Δ_i·η/2, i)` with `lam = PosSpec.lam` the tick base, the factor 2 being `priceEta`'s sqrt-price convention `i/2`; the second equality is the existing `CFMM.Eta.p_eta_eq_P_half_rescaled`. (ii) THE FACTOR-SHARE IDENTIFICATION (a MODELLING claim, NOT implied by (i)): that this same η is the exponent of the weighted-CFMM trading function `L_eta η X Y = X^{η}·Y^{1−η}` of `model/exp/eta.md`. Claim (ii) is listed in E8 as **OPEN** unless E6 displays a derivation. `exp/eta.lean`'s own `P_half` docstring states that η does not enter the tick→price map — it enters at the reserve / impact level — which is precisely why (ii) cannot ride in on (i).

TERMINOLOGY: η is a FACTOR SHARE on reserves, not an elasticity of substitution; for a weighted-geometric trading function the elasticity of substitution is 1. The loose phrase "substitution elasticity" is not used here.

## **E1. [ADDITION] The curvature family and the discrete index**

The anchor's family (§5.1, p. 22), with `A` the scaling coefficient:

\[
	\begin{aligned}
		F_{\chi}(x,y) \, &= \, (1-\chi)\,A\,F_0(x,y) \, + \, \chi\,F_1(x,y), \qquad \chi \in [0,1] \\
		F_0(x,y) \, &= \, p_A x + p_B y \quad \text{(linear, zero curvature)}, \qquad
		F_1(x,y) \, = \, x\,y \quad \text{(constant product)} \\
		A \, &= \, \big(y_A\,y_B / (p_A\,p_B)\big)^{1/2}
	\end{aligned}
\]

The curvature of \(F_{\chi} = C\) is increasing in \(\chi\). OUR discrete index, from `VolInstrument.priceEta η Δ_i i` \(= \lambda^{(i/2)\Delta_i\eta}\):

\[
	\begin{aligned}
		\frac{p_{(\eta,\Delta_i)}(i+\Delta_i)}{p_{(\eta,\Delta_i)}(i)} \, &= \, \lambda^{\Delta_i^{2}\eta/2}
		\qquad \text{(INDEPENDENT of } i \text{)} \\
		\chi(\eta,\Delta_i) \, &:= \, 1 \, - \, \frac{p_{(\eta,\Delta_i)}(i)}{p_{(\eta,\Delta_i)}(i+\Delta_i)}
		\, = \, 1 \, - \, \lambda^{-\Delta_i^{2}\eta/2}
	\end{aligned}
\]

This is the anchor's OWN definition of curvature — "the rate of change of the marginal exchange rate" (§5.1, p. 22) — in discrete form on a geometric grid. Properties: strictly increasing in \(\eta\); a bijection \((0,\infty) \to (0,1)\); \(\to 0\) as \(\eta \to 0^{+}\) (the zero-curvature constant-price grid, the anchor's \(\chi = 0\)) and \(\to 1\) as \(\eta \to \infty\).

**WARNING — `η = 1` is the standard sqrt-price grid (`VolInstrument.priceEta_one`: `priceEta 1 Δ_i = tickPrice Δ_i`), and is NOT Capponi's `χ = 1`. \(\chi(1,\Delta_i) \neq 1\), our η range is unbounded above where his `k` caps at 1, and no display here equates `η = 1` with `χ = 1`.**

## **E2. [ADDITION] The arbitrage-loss ratio** (Lemma 3(1))

\[
	\begin{aligned}
		\chi_S \, &= \, 1 - \sqrt{\tfrac{1+\varphi}{1+\varrho_S}}, \qquad s \, := \, \sqrt{\tfrac{1+\varphi}{1+\varrho_S}} \, = \, 1 - \chi_S \\[2pt]
		\mathrm{arbLoss}(\chi) \, &= \, \frac{\varpi_A}{2}\cdot
		\begin{cases}
			(1+\varrho_S) \, - \, \dfrac{1+\varphi}{1-\chi}, & \chi \in [0,\ \chi_S] \quad \text{(A.38, corner)} \\[8pt]
			(1+\varrho_S)\,\dfrac{\chi_S^{2}}{\chi}, & \chi \in [\chi_S,\ 1] \quad \text{(A.36, interior)}
		\end{cases}
	\end{aligned}
\]

Branch agreement at \(\chi_S\): both branches equal \(\tfrac{\varpi_A}{2}(1+\varrho_S)(1-s)\), so the glued function is continuous. **Strictly decreasing in \(\chi\)** on \((0,1]\) (each branch is: \((1+\varphi)/(1-\chi)\) increases, \(1/\chi\) decreases).

`\varrho_S > \varphi` is Lemma 1's condition that an arbitrage occurs at all; Lemma 1 is the one-token shock result and is NOT the curvature lemma.

## **E3. [ADDITION] The investors' surplus ratio** (Lemma 3(2))

\[
	\begin{aligned}
		\chi_I \, &= \, 1 - \sqrt{\tfrac{1+\varphi}{1+\varrho_I}} \\[2pt]
		\mathrm{surplus}(\chi) \, &= \, \frac{1}{2}\cdot
		\begin{cases}
			(1+\varrho_I) \, - \, \dfrac{1+\varphi}{1-\chi}, & \chi \in [0,\ \chi_I] \quad \text{(A.43, corner)} \\[8pt]
			(1+\varrho_I)\,\dfrac{\chi_I^{2}}{\chi}, & \chi \in [\chi_I,\ 1] \quad \text{(A.42, interior)}
		\end{cases}
	\end{aligned}
\]

Same shape, same continuity at \(\chi_I\), **strictly decreasing in \(\chi\)** on \((0,1]\).

`\varrho_I > \varphi` is Lemma 2's condition for the investor to trade. And \(\varrho_S \leq \varrho_I \iff \chi_S \leq \chi_I\) — the geometrized form of Proposition 5's displayed hypothesis, whose proof consumes it ONLY through the ordering of the two branch points.

## **E4. [ADDITION — THE INTERIOR OPTIMUM]** (Proposition 5)

The LP one-period excess return \(D(\chi) = \mathbb{E}[R_D] - \mathbb{E}[R_A]\), equations (A.50)–(A.52):

\[
	\begin{aligned}
		D(\chi) \, &= \,
		\begin{cases}
			c_3(\chi) \, - \, \varpi_D\,\varrho_S, & \chi \in [0,\ \chi_S] \quad \text{(A.52)} \\
			c_2(\chi) \, - \, \varpi_D\,\varrho_S, & \chi \in [\chi_S,\ \chi_I] \quad \text{(A.51)} \\
			\dfrac{c_1}{\chi} \, - \, \varpi_D\,\varrho_S, & \chi \in [\chi_I,\ 1] \quad \text{(A.50)}
		\end{cases} \\[6pt]
		c_3(\chi) \, &= \, \frac{\varpi_I}{2}\Big(\frac{1+\varphi}{1-\chi} - 1\Big)
		\, - \, \frac{\varpi_A}{2}\Big((1+\varrho_S) - \frac{1+\varphi}{1-\chi}\Big) \\
		c_2(\chi) \, &= \, \frac{\varpi_I}{2}\Big(\frac{1+\varphi}{1-\chi} - 1\Big)
		\, - \, \frac{\varpi_A}{2}\,\frac{(1+\varrho_S)\,\chi_S^{2}}{\chi} \\
		c_1 \, &= \, \frac{\varpi_I}{2}\Big(1+\varphi-\sqrt{\tfrac{1+\varphi}{1+\varrho_I}}\Big)\Big(\sqrt{\tfrac{1+\varrho_I}{1+\varphi}}-1\Big)
		\, - \, \frac{\varpi_A}{2}\,(1+\varrho_S)\,\chi_S^{2} \qquad \text{(constant in } \chi\text{)}
	\end{aligned}
\]

Continuity at BOTH branch points: at \(\chi_S\) by E2's branch agreement; at \(\chi_I\) both sides equal \(\tfrac{\varpi_I}{2}\big(\sqrt{(1+\varphi)(1+\varrho_I)}-1\big) - \tfrac{\varpi_A}{2}(1+\varrho_S)\chi_S^{2}/\chi_I\). \(D\) is strictly increasing on \([0,\chi_I]\) and, **under \(c_1 > 0\)**, strictly decreasing on \([\chi_I,1]\), so

\[
	\begin{aligned}
		\chi^{\star} \, = \, \chi_I \, = \, 1 - \sqrt{\tfrac{1+\varphi}{1+\varrho_I}}, \qquad
		\chi^{\star} \in (0,1) \iff \varphi < \varrho_I
	\end{aligned}
\]

**\(\chi^{\star}\) is a BRANCH POINT — a kink, where the investor's trade switches from draining the pool to an interior marginal condition. The derivative jumps there. There is no first-order condition and none is claimed.**

Liquidity-freeze corollary (Proposition 5(2)): \(D(\chi^{\star}) < 0 \implies D(\chi) < 0\) for every \(\chi \in [0,1]\).

BOUNDARY OF THE CLAIM: when \(c_1 \leq 0\) the anchor's own argument puts the pool in the freeze region, where the LP payoff is \(\mathbb{E}[R_A] = \varpi_H\varrho_S\), constant in \(\chi\); strict single-peakedness is therefore FALSE in general, and the strict statement is made only under \(c_1 > 0\).

## **E5. [ADDITION] Deposit efficiency and the welfare bound** (Proposition 6)

Deposit efficiency (A.56) — expected investor trading volume over deposited value — has the same two-branch shape with the SAME branch point \(\chi^{\star}\): increasing in \(\chi\) below \(\chi^{\star}\) (the corner branch, from A.41) and decreasing above (the interior branch, from A.40). Maximized at \(\chi^{\star}\).

WELFARE, BOUNDED EXPLICITLY: the anchor's welfare half is a statement about three GIVEN pieces — the LP aggregate payoff (E4), the arbitrageur's payoff, which is \(0\) by his Assumption 3, and the investor surplus (E3). Transcribed only in that reduced form, under an explicit zero-arbitrageur-payoff hypothesis; as a welfare theorem about the underlying game it is **OPEN** and is not asserted.

GAS is absorbed, not modelled: Assumption 3 (the arbitrageur pays a gas fee equal to its full profit) is what makes that payoff zero and is the reason the welfare statement is bounded where it is.

## **E6. [ADDITION — THE BRIDGE]**

\[
	\begin{aligned}
		\eta^{\star} \, = \, \frac{\ln\!\big((1+\varrho_I)/(1+\varphi)\big)}{\Delta_i^{2}\,\ln\lambda},
		\qquad \chi(\eta^{\star},\Delta_i) \, = \, \chi^{\star}
	\end{aligned}
\]

Obtained by INVERTING E1's bijection at \(\chi^{\star}\): setting \(1 - \lambda^{-\Delta_i^{2}\eta/2} = 1 - \sqrt{(1+\varphi)/(1+\varrho_I)}\) and taking logarithms. This is `Real.log` algebra on a closed form, NOT an existence argument.

Comparative statics: \(\eta^{\star} > 0 \iff \varphi < \varrho_I\); strictly increasing in \(\varrho_I\); **strictly decreasing in \(\varphi\)**; strictly decreasing in \(\Delta_i^{2}\). Two-sided shape: \(D \circ \chi(\cdot,\Delta_i)\) is strictly increasing on \((0,\eta^{\star}]\) and strictly decreasing on \([\eta^{\star},\infty)\) under E4's hypotheses.

NORMALIZATION BRIDGE — claim (i), THE EXPONENT IDENTITY (provable):

\[
	\begin{aligned}
		\texttt{priceEta}\,\eta\,\Delta_i\,i \, = \, \lambda^{(i/2)\Delta_i\eta} \, = \, \texttt{p\_eta}\,(\texttt{lam},\,\Delta_i,\,\eta/2,\,i) \, = \, \texttt{P\_half}\,(\texttt{lam},\ \Delta_i\eta/2,\ i)
	\end{aligned}
\]

The factor 2 IS the normalization — `priceEta`'s sqrt-price convention. The identity is stated on integer ticks \(i : \mathbb{Z}\), the domain on which the two conventions are comparable, and the last equality is the existing `CFMM.Eta.p_eta_eq_P_half_rescaled`.

NORMALIZATION BRIDGE — claim (ii), THE FACTOR-SHARE IDENTIFICATION: that this η is also the exponent of `L_eta η X Y` \(= X^{\eta}Y^{1-\eta}\), the weighted-CFMM trading function of `model/exp/eta.md`. This is a claim ABOUT THE MODEL — a reserve-side factor share identified with a grid-side exponent — and it is **OPEN** (E8, item 6). It does not follow from (i) and is not assumed by any display above.

RELATION TO THE EXISTING LAYER: `lean/exp/DynamicsOptimization.lean` (`foc_eta`, `optimal_controls`) HYPOTHESIZES an interior η* and characterizes it by a first-order condition in a DIFFERENT model; that characterization is SUPERSEDED here, not duplicated. This block instead proves existence and gives a closed form by construction, and no first-order condition is used or claimed anywhere in this section — E4's optimum is a kink.

## **E7. [ADDITION — THE DE-DEGENERATION]**

Over \(\Theta_{\varphi}\), `MevJointProgram.joint_corner_degeneracy` puts the FLAIR maximum and the arbitrage-channel minimum at the SAME point in every coordinate, robustly to every linear scalarization with nonnegative weight — there is no trade-off, and the shape block \((\beta_j,\gamma_j)\) is not essential.

Over η the structure is the opposite, and the reason is Lemma 3's TWO-SIDEDNESS: both \(\mathrm{arbLoss}\) and \(\mathrm{surplus}\) are strictly antitone in \(\chi\), hence the arb-minimizer sits at \(\eta \to \infty\) and the surplus-maximizer at \(\eta \to 0^{+}\). **No η is simultaneously arb-minimal and surplus-maximal**, and \(D\), which combines them, peaks strictly between. The joint optimum is therefore (\(\Theta_{\varphi}\) CORNER, η INTERIOR).

THE COUPLING:

\[
	\begin{aligned}
		\frac{\partial \eta^{\star}}{\partial \varphi} \, < \, 0
		\quad\text{and}\quad \Theta_{\varphi} \text{ sits at } \bar\varphi \text{ (Phase 11)}
		\;\;\implies\;\; \text{the fee corner strictly LOWERS the optimal curvature}
	\end{aligned}
\]

The two blocks are NOT separable even though one of them is a corner. And \(\varrho_I\) IS the demand-side parameter that `MevJointProgram`'s degeneracy docstring and `LEAN_TRACEABILITY` §6(b) both name as the missing layer.

## **E8. [CAVEATS]**

1. **OPEN — THE EQUILIBRIUM TRANSFER.** That the tick-grid AMM's arbitrage/investor equilibrium has the anchor's closed forms with \(\chi(\eta,\Delta_i)\) in the curvature slot is ASSUMED, not derived. Deriving it means re-solving (A.31)/(A.39) on a discrete grid with per-tick liquidity. Every result above is a theorem about the displayed functions composed with \(\chi(\cdot,\Delta_i)\).
2. **OPEN — WELFARE.** Proposition 6's welfare half is bounded to a statement about three given functions under the zero-arbitrageur-payoff assumption; it is never a welfare theorem about the game.
3. **OPEN — THE TWO ARBITRAGE OBJECTS ARE NOT IDENTIFIED.** \(\mathrm{arbLoss}\) and `MevOptimization.mevMulti` (\(\lambda_{\text{ARB}}\)) come from different models with different units — a two-period discrete-shock per-period ratio of pool value against a discrete hazard sum over \(D_t\). No identification is attempted or implied, as forcefully as M0 states that \(\lambda_{\text{ARB}}\) is a summand of \(\lambda_{\text{MEV}}\) and never a sibling.
4. **OPEN — GAS.** Assumption 3 (the arbitrageur pays a gas fee equal to its full profit) is absorbed, not modelled.
5. **OPEN — the \(\Theta_{\varphi}\)-restricted σ-varying MEV comparison**, inherited from Phase 11 (`LEAN_TRACEABILITY` §7.1, last M6b row). This section does not touch it and must not appear to.
6. **OPEN — the factor-share identification** of E0(ii)/E6(ii): the grid exponent η and the reserve-side factor share of `L_eta` are the same parameter under different normalizations only up to a modelling claim; the exponent identity of E6(i) is proven algebra and is all that is claimed here.

Further caveats: this is the anchor's two-period discrete-shock model, not MMR's fast-block diffusion of `### MEV`; the anchor's family caps at constant product while our η range does not, which HELPS interiority but forbids any `η = 1` ⇔ `χ = 1` reading (E1); and \(\varphi\) is here a FIXED fee, whereas this document's \(\varphi = \mathrm{multiFee}(\sigma)\) varies — the transcription is at a fixed \(\varphi\).

<!-- END ETA -->
