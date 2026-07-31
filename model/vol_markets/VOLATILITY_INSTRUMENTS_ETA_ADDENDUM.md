# PROPOSED addendum to `VOLATILITY_INSTRUMENTS.md` — the `## ETA` section: the curvature controller and the interior η*

> STATUS: APPROVED & APPLIED 2026-07-31 — blocks E0–E8 inserted into ../plank/notes/VOLATILITY_INSTRUMENTS.md at the user-decided placement per user approval (todo.md `## LEAN4 - MATH`). Committing the plank file is the plank agent's.
> Placement DECIDED by the user: the DEFAULT — the body of the user-authored `## FLAIR & MEV` stub is replaced by these blocks and the user's section title is kept.
> Scope ruling DECIDED by the user (ESCALATE E-1, 12-01-REVIEW.md): the narrowed CTX-DEGEN is ACCEPTED. There is **no literal de-degeneration theorem**; what ships is the interior optimum in the Capponi-anchored model plus the η-bridge transport, with the Phase-11 contrast as an honest scope statement. **This governs what 12-02 may ask Aristotle to prove.**
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

ANCHOR: Capponi & Jia, *The Adoption of Blockchain-Based Decentralized Exchanges*, arXiv:2103.08842v4 [q-fin.TR], 21 Jul 2021, §5.1. The curvature results transcribed in this section are **Lemma 3** (both ratios antitone in curvature), **Proposition 5** (the interior optimum and the liquidity-freeze corollary) and **Proposition 6** (deposit efficiency; its welfare half is OPEN, see E5). Lemma 1 and Lemma 2 are cited only for their own trade-occurrence conditions and are NOT curvature results. η is PROTECTED throughout and is this document's pricing-kernel exponent.

The paper's curvature index `k` is transcribed as `χ` (`\chi`); Lean `curv` / `curvIndex`. <!-- notation-map -->
The paper's investor private-use premium `α` is transcribed as `ϱ_I` (`\varrho_I`); Lean `premInv`. <!-- notation-map -->
The paper's price-shock magnitude `β` is transcribed as `ϱ_S` (`\varrho_S`); Lean `premShock`. <!-- notation-map -->
The paper's proportional trading fee `f` is IDENTIFIED with this document's `φ` (`\varphi`) and is not renamed; this document's `α_j`, `β_j`, `γ_j` remain the `Θ_φ` sigmoid parameters and are always subscripted. <!-- notation-map -->
The paper's probabilities `θ, κ_I, κ_com, κ₁, κ₂` are NEVER NAMED; they enter only as the four constants below. `θ` collides with this document's option theta and `κ` with the Phase-11 scalarization weight. <!-- notation-map -->
The paper's Proposition-5 coefficients `τ₁, τ₂, τ₃` are transcribed as `c₁, c₂, c₃` (Lean `cOne`, `cTwo`, `cThree`), because `τ` is TAKEN by this document's `τ = τ_MEV` (block M9). <!-- notation-map -->
The symbol `ν` is TAKEN by block M6b (`ν_t = w_t/D_t`) and is NEVER introduced here. <!-- notation-map -->

The four absorbed constants, each constant in \(\chi\):

\[
	\begin{aligned}
		\varpi_A \, > \, 0 \;&:\; \text{probability an arbitrage occurs in a period} \\
		\varpi_I \, > \, 0 \;&:\; \text{probability an investor arrives} \\
		\varpi_H \, \geq \, 0 \;&:\; \text{the hold-benchmark coefficient, } \; \mathbb{E}[R_A] = \varpi_H\,\varrho_S \\
		\varpi_D \, \geq \, 0 \;&:\; \text{the constant subtracted in the LP excess return}
	\end{aligned}
\]

THE POSITIVITY IS LOAD-BEARING, NOT COSMETIC. At \(\varpi_A = 0\) the whole of E2 collapses to \(\mathrm{arbLoss} \equiv 0\), every η is arb-minimal, and E7's central sentence is FALSE; at \(\varpi_I = 0\) E4's strict increase fails. Both are strictly positive in the anchor: \(\varpi_A\) is built from its two idiosyncratic-shock probabilities, each strictly inside \((0,1)\) by its eq. (2), and \(\varpi_I\) is a strictly positive arrival probability. \(\varpi_D \geq 0\) likewise comes from a structural anchor assumption — eq. (2) imposes a strict ordering on those two shock probabilities — and is recorded here so a reader can check it rather than take it on trust.

Standing hypotheses for every display below: \(0 \leq \varphi < \varrho_S \leq \varrho_I\), \(0 < \Delta_i\), \(1 < \lambda_{\text{tick}}\). These give \(\chi_S > 0\) and \(\chi_I > 0\), which is what keeps every \(1/\chi\) branch below away from its pole; the guard is ALSO restated inline on each at-risk display, because a guard that lives only in a global prose sentence is exactly how this project's `ptrade` negative-fee pole reached two theorem statements.

THE ANCHOR'S PREMIUM ORDERING: Propositions 5 and 6 DISPLAY the strict ordering (ours: \(\varrho_S < \varrho_I\)); their proofs consume only the weak form \(\varrho_S \leq \varrho_I\), through the branch-point ordering \(\chi_S \leq \chi_I\) alone. The weak form is what is transcribed. At \(\varrho_S = \varrho_I\) the middle branch \([\chi_S,\chi_I]\) of E4 is EMPTY and the three-branch display degenerates to two; the peak statement is unaffected.

TICK-BASE READING: in this section an unsubscripted `\lambda` inside an exponential is the tick base λ = 1.0001 (`PosSpec.lam`), never a hazard; every hazard of `### MEV` is subscripted (`\lambda_{\text{ARB}}`, `\lambda_{\text{FLAIR}}`, `\lambda_{\text{MEV}}`).

NOT PROBABILITIES: `\varrho_I` and `\varrho_S` are VALUATION PREMIA — they are not probabilities, they are not arrival probabilities, and they are not confined to \([0,1]\). `\varrho_I` is the markup a type-`i` investor places on token `i` and may exceed 1; `\varrho_S` is the magnitude of the price shock. Under a probability reading the closed form \(\chi^{\star} = 1 - \sqrt{(1+\varphi)/(1+\varrho_I)}\) is uninterpretable.

THE η CONVENTION BRIDGE, AS TWO SEPARATE CLAIMS. (i) THE EXPONENT IDENTITY (provable algebra): on integer ticks, `priceEta η Δ_i i = p_eta(lam, Δ_i, η/2, i) = P_half(lam, Δ_i·η/2, i)` with `lam = PosSpec.lam` the tick base, the factor 2 being `priceEta`'s sqrt-price convention `i/2`; the second equality is the existing `CFMM.Eta.p_eta_eq_P_half_rescaled`. (ii) THE FACTOR-SHARE IDENTIFICATION (a MODELLING claim, NOT implied by (i)): that this same η is the exponent of the weighted-CFMM trading function `L_eta η X Y = X^{η}·Y^{1−η}` of `model/exp/eta.md`. Claim (ii) is listed in E8 as **OPEN** unless E6 displays a derivation. `exp/eta.lean`'s own `P_half` docstring states that η does not enter the tick→price map — it enters at the reserve / impact level — which is precisely why (ii) cannot ride in on (i).

TERMINOLOGY: for a weighted-geometric trading function \(L = X^{\eta_L}Y^{1-\eta_L}\), the exponent \(\eta_L\) is a FACTOR SHARE on reserves and the elasticity of substitution is 1. The plank-side phrase "asset-demand substitution elasticity" is therefore loose and is NOT propagated here. Note that this sentence is about \(\eta_L\), the `L_eta` exponent — whether \(\eta_L\) equals this section's grid exponent η is claim (ii) above and is listed **OPEN** at E8(6); no display in E1–E7 assumes it.

PROPOSED LEAN NAMES (these do NOT yet exist anywhere in the tree; every OTHER backticked Lean identifier in this section resolves to a real declaration): `curvIndex` for the definition of \(\chi(\eta,\Delta_i)\), with `curv` reserved as the bound VARIABLE name so that it does not shadow `MevJointProgram.taxFraction (k : ℝ)`; `premInv`, `premShock`, `cOne`, `cTwo`, `cThree`, `chiS`, `chiI`, `chiStar`, `etaStar`.

## **E1. [ADDITION] The curvature family and the discrete index**

The anchor's family (§5.1, p. 23), with `A` the scaling coefficient:

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

Properties: strictly increasing in \(\eta\); a bijection \((0,\infty) \to (0,1)\); \(\to 0\) as \(\eta \to 0^{+}\) (the zero-curvature constant-price grid, the anchor's \(\chi = 0\)) and \(\to 1\) as \(\eta \to \infty\).

**\(\chi(\eta,\Delta_i)\) IS A MONOTONE PROXY FOR THE ANCHOR'S CURVATURE, NOT A DEFINITIONAL RESTATEMENT OF IT — AND THE DIFFERENCE IS LOAD-BEARING.** The anchor's curvature is the rate of change of the marginal exchange rate *with respect to the amount traded* (§5.1, p. 22), which is what produces slippage; and its `k` is the MIXING WEIGHT of the family above, entering structurally in the arbitrageur's constraint (A.31) and the investor's (A.39) from which every closed form in E2–E5 is derived. Our \(\chi\) is the relative price step *per tick index*, and it carries NO per-tick liquidity term — two grids with the same \(\chi\) and different liquidity have different slippage per unit traded, hence different curvature in the anchor's sense. What \(\chi\) shares with `k` is its qualitative content: increasing in curvature, \(\to 0\) at zero curvature, \(\to 1\) at maximal. **Placing \(\chi\) in the anchor's `k` slot is a MODELLING step, not a definition — see E8(1), which covers this object-level identification as well as the equilibrium transfer.**

**WARNING — `η = 1` is the standard sqrt-price grid (`VolInstrument.priceEta_one`: `priceEta 1 Δ_i = tickPrice Δ_i`), and is NOT Capponi's `χ = 1`. \(\chi(1,\Delta_i) \neq 1\), and no display here equates `η = 1` with `χ = 1`.** Nor does the unbounded η range EXTEND the anchor's family: \(\chi(\cdot,\Delta_i)\) maps \((0,\infty)\) onto the OPEN interval \((0,1) \subsetneq [0,1]\), so \(\eta \to \infty\) only approaches constant product and never attains it, and the anchor's two corners are unreachable. Interiority in η is therefore INHERITED from \(\chi^{\star} \in (0,1)\) — the anchor's Proposition-5 result — and is not additional evidence supplied by the reparametrization.

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

GUARD (restated inline, not inherited from E0): \(0 \leq \varphi < \varrho_S\), hence \(\chi_S > 0\); the interior branch is stated on \([\chi_S,1] \subset (0,1]\) and never touches the \(1/\chi\) pole. Lean domain: `Set.Ioc 0 1`, glued at `Set.Icc 0 chiS` and `Set.Icc chiS 1`, with `hchiS : 0 < chiS` an explicit hypothesis.

Branch agreement at \(\chi_S\): both branches equal \(\tfrac{\varpi_A}{2}(1+\varrho_S)(1-s)\), so the glued function is continuous. **Strictly decreasing in \(\chi\)** on \((0,1]\) (each branch is: \((1+\varphi)/(1-\chi)\) increases, \(1/\chi\) decreases) — strictly, because \(\varpi_A > 0\) by E0.

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

GUARD (restated inline): \(0 \leq \varphi < \varrho_I\), hence \(\chi_I > 0\); the interior branch is stated on \([\chi_I,1] \subset (0,1]\). Lean domain `Set.Ioc 0 1` with `hchiI : 0 < chiI` explicit.

Same shape, same continuity at \(\chi_I\), **strictly decreasing in \(\chi\)** on \((0,1]\).

SCALE: \(\mathrm{surplus}\) is the PER-INVESTOR ratio. Lemma 3(2)'s object is the sum over both investor types, and the anchor shows the two type-ratios are equal, so Lemma 3(2)'s quantity is \(2\,\mathrm{surplus}\). The welfare weight attached to it is \(\varpi_I\), whereas E2's \(\mathrm{arbLoss}\) already carries \(\varpi_A\) — the two blocks are NOT conditioned alike, and anything that combines them additively must supply the missing \(\varpi_I\). Monotonicity is unaffected by either factor.

`\varrho_I > \varphi` is Lemma 2's condition for the investor to trade. And \(\varrho_S \leq \varrho_I \iff \chi_S \leq \chi_I\) — the geometrized form of the premium ordering that Proposition 5's PROOF consumes (E0 records that the Proposition DISPLAYS the strict form), which it uses ONLY through the ordering of the two branch points.

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

WHAT \(D\) IS MADE OF — read this before E7. \(D\) is LP REVENUE FROM INVESTOR FLOW minus \(\mathrm{arbLoss}\). The investor's own SURPLUS (E3) does NOT appear in \(D\) at all. The revenue term is \(\tfrac{\varpi_I}{2}\big((1+\varphi)/(1-\chi) - 1\big)\) on the two lower branches and \(\propto 1/\chi\) on the top branch; it is "LP revenue from investor flow", i.e. SLIPPAGE RENT PLUS FEE, and it is strictly positive even at \(\varphi = 0\), where it equals \(\varpi_I\chi/(2(1-\chi))\). It is INCREASING in \(\chi\) below \(\chi_I\) and DECREASING above — the opposite sign to E3's surplus below \(\chi_I\), not the same sign.

GUARD (restated inline): \(\chi_S > 0\) and \(\chi_I > 0\) from \(0 \leq \varphi < \varrho_S \leq \varrho_I\); the \(c_2\) and \(c_1/\chi\) branches are stated on \([\chi_S,\chi_I]\) and \([\chi_I,1]\), both bounded away from the pole. Lean: `Set.Icc chiS chiI`, `Set.Icc chiI 1`, with `hchiS`, `hchiI` explicit.

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

WELFARE: **OPEN — and NOT reducible to a sum of E3 and E4.** This block transcribes Proposition 6's DEPOSIT-EFFICIENCY half only. The welfare half does NOT follow from the pieces stated here, and saying it did would be the document's most inviting error: below \(\chi^{\star}\) the LP payoff RISES while the investor surplus FALLS (E3 is antitone on all of \([0,1]\)), so "LP peaked at \(\chi^{\star}\), surplus antitone, arbitrageur zero" points a reader toward the OPPOSITE conclusion. The anchor's welfare argument is a two-period COMPOUNDED expression carrying a freeze indicator and its own coefficient, and that coefficient's monotonicity is a separate computation, not a corollary of Lemma 3 plus Proposition 5. Formalizing it means transcribing that carrier; until then the welfare half is **OPEN**.

What IS clean, and is the sharp statement of what curvature does below the peak: on the corner branch the investor surplus and the LP revenue from investor flow sum to a CONSTANT,

\[
	\begin{aligned}
		\underbrace{\tfrac{1}{2}\Big[(1+\varrho_I) - \tfrac{1+\varphi}{1-\chi}\Big]}_{\text{investor surplus}}
		\; + \;
		\underbrace{\tfrac{1}{2}\Big[\tfrac{1+\varphi}{1-\chi} - 1\Big]}_{\text{LP revenue per investor}}
		\; = \; \frac{\varrho_I}{2}
		\qquad \text{on } [0,\chi_I]
	\end{aligned}
\]

so below \(\chi^{\star}\) curvature is a PURE ZERO-SUM TRANSFER from investor to LP at a one-to-one rate — the gains from trade do not shrink, because the investor still clears the pool. The pie only starts shrinking above \(\chi^{\star}\), where the investor curtails volume. That, and not any weighting of objectives, is where the peak comes from.

GAS is absorbed, not modelled, and the absorption has a consequence this document must not hide. Assumption 3 (the arbitrageur pays a gas fee equal to its full profit) makes the arbitrageur's equilibrium payoff zero AND makes the arbitrage rent a DEADWEIGHT LOSS rather than a transfer — the latter only because miners/validators sit OUTSIDE the anchor's welfare agent set. **That assumption is contradicted by this document's own `### MEV` premises**: a top-of-block auction that recycles arbitrage rent to LPs, or an MEV tax, puts the recipient back inside the agent set and turns the rent into a transfer, under which the anchor's welfare ranking over \(\chi\) does not carry. A reader holding `### MEV` and `## ETA` in the same head must not import that ranking.

## **E6. [ADDITION — THE BRIDGE]**

\[
	\begin{aligned}
		\eta^{\star} \, = \, \frac{\ln\!\big((1+\varrho_I)/(1+\varphi)\big)}{\Delta_i^{2}\,\ln\lambda},
		\qquad \chi(\eta^{\star},\Delta_i) \, = \, \chi^{\star}
	\end{aligned}
\]

Obtained by INVERTING E1's bijection at \(\chi^{\star}\): setting \(1 - \lambda^{-\Delta_i^{2}\eta/2} = 1 - \sqrt{(1+\varphi)/(1+\varrho_I)}\) and taking logarithms. This is `Real.log` algebra on a closed form, NOT an existence argument.

Comparative statics: \(\eta^{\star} > 0 \iff \varphi < \varrho_I\); strictly increasing in \(\varrho_I\); **strictly decreasing in \(\varphi\)**. The dependence on \(\Delta_i\) is a NORMALIZATION IDENTITY rather than a comparative static: \(\chi^{\star}\) depends only on \((\varphi,\varrho_I)\), and \(\eta^{\star} \propto 1/\Delta_i^{2}\) is simply whichever exponent reproduces that same \(\chi^{\star}\) on the chosen grid. Two-sided shape: \(D \circ \chi(\cdot,\Delta_i)\) is strictly increasing on \((0,\eta^{\star}]\) and strictly decreasing on \([\eta^{\star},\infty)\) under E4's hypotheses, INCLUDING \(c_1 > 0\).

ADMISSIBILITY OF THE FACTOR-SHARE READING. A factor share must lie in \((0,1)\), but \(\eta^{\star} \in (0,1)\) requires \(\Delta_i^{2}\ln\lambda > \ln((1+\varrho_I)/(1+\varphi))\). At \(\lambda = 1.0001\), \(\varrho_I = 0.05\), \(\varphi = 0.003\) this is \(\Delta_i \gtrsim 21\); at \(\Delta_i = 1\) and \(\Delta_i = 10\) — both in standard use — \(\eta^{\star} \approx 458\) and \(\approx 4.6\). So on a large part of the tick-spacing range the factor-share reading is not merely OPEN but UNAVAILABLE, and the grid-exponent reading is the only one. This is recorded here rather than left for a downstream reader to discover.

NORMALIZATION BRIDGE — claim (i), THE EXPONENT IDENTITY (provable):

\[
	\begin{aligned}
		\texttt{priceEta}\,\eta\,\Delta_i\,i \, = \, \lambda^{(i/2)\Delta_i\eta} \, = \, \texttt{p\_eta}\,(\texttt{lam},\,\Delta_i,\,\eta/2,\,i) \, = \, \texttt{P\_half}\,(\texttt{lam},\ \Delta_i\eta/2,\ i)
	\end{aligned}
\]

The factor 2 IS the normalization — `priceEta`'s sqrt-price convention. The identity is stated on integer ticks \(i : \mathbb{Z}\), the domain on which the two conventions are comparable, and the last equality is the existing `CFMM.Eta.p_eta_eq_P_half_rescaled`.

NORMALIZATION BRIDGE — claim (ii), THE FACTOR-SHARE IDENTIFICATION: that this η is also the exponent of `L_eta η X Y` \(= X^{\eta}Y^{1-\eta}\), the weighted-CFMM trading function of `model/exp/eta.md`. This is a claim ABOUT THE MODEL — a reserve-side factor share identified with a grid-side exponent — and it is **OPEN** (E8, item 6). It does not follow from (i) and is not assumed by any display above.

RELATION TO THE EXISTING LAYER — **NO RELATION IS ASSERTED.** `lean/exp/DynamicsOptimization.lean` (`foc_eta`, `optimal_controls`) characterizes a stationary point of \(\pi^{+} = \Delta_i^{2}S(\eta)\), where η enters ONLY through the inventory-weight curve `w η j` — that is the reserve-side factor share, i.e. claim (ii)'s η, and the objective is \(\pi^{+}\), not \(D\). **A different objective and a different η.** Relating the two would require exactly the factor-share identification that E8(6) lists as OPEN, so this section neither duplicates nor supersedes those theorems, and it does not claim to: they are proven, axiom-clean results about their own model and stand untouched. What this section adds independently is a CLOSED FORM obtained by inverting a bijection; no first-order condition is used or claimed anywhere in it, because E4's optimum is a kink.

## **E7. [ADDITION — THE INTERIOR OPTIMUM AGAINST THE PHASE-11 CORNER]**

TWO ARBITRAGE MINIMANDS, NEVER INTERCHANGEABLE. Write **the \(\lambda_{\text{ARB}}\)-minimizer** for the Phase-11 object (`MevOptimization.mevMulti`, over \(\Theta_{\varphi}\)) and **the \(\mathrm{arbLoss}\)-minimizer** for this section's (E2, over \(\chi\)). E8(3) says these are NOT identified, and nothing below identifies them.

Over \(\Theta_{\varphi}\): `MevJointProgram.joint_corner_degeneracy` (T20) puts the FLAIR maximum and the \(\lambda_{\text{ARB}}\)-minimum at the SAME level corner, and `joint_beta_degeneracy` (T21) does the same for the shape block \((\beta_j,\gamma_j)\), the two together being robust to every linear scalarization with nonnegative weight (T22). There is no trade-off there.

**WHERE THE INTERIOR PEAK ACTUALLY COMES FROM — and it is NOT a weighting of two objectives.** Per E4, \(D\) = LP revenue from investor flow \(-\;\mathrm{arbLoss}\); the investor's SURPLUS is not a term of \(D\). The peak is produced by the LP revenue term alone, which is INCREASING in \(\chi\) below \(\chi_I\) and DECREASING above, because the investor's constraint switches from the corner regime (it drains the pool, A.41) to the interior regime (it curtails volume, A.40) exactly at \(\chi_I\). \(\mathrm{arbLoss}\) is monotone throughout and generates no peak at all; it only fixes, through \(c_1 > 0\), whether the post-peak decline survives. Below \(\chi^{\star}\) the surplus and the revenue sum to a constant (E5's zero-sum identity), so curvature there is a pure transfer and the pie is intact; above \(\chi^{\star}\) the pie itself shrinks.

**The "two antitone objectives, opposite corners, therefore an interior peak" reading is FALSE and is not made here.** A nonnegative weighting \(w_1(-\mathrm{arbLoss}) + w_2\,\mathrm{surplus}\) has, on each branch, a derivative whose SIGN IS CONSTANT on that branch and depends only on the weights — on \([0,\chi_S]\) it is \(\tfrac{w_1\varpi_A - w_2}{2}\cdot\tfrac{1+\varphi}{(1-\chi)^2}\). Such a combination is piecewise monotone and peaks at a branch point only by accident of the weights. Scalarization does not manufacture an interior optimum, which is the same lesson Phase 11's T22 already recorded.

**WHAT THIS DOES AND DOES NOT DO TO THE PHASE-11 DEGENERACY.** It does NOT resolve it. `mevMulti` contains no η, no \(\chi\) and no \(\varrho_I\); nothing in E1–E6 moves it, so the \(\Theta_{\varphi}\) degeneracy stands exactly where Phase 11 left it. What this section supplies is a SEPARATE model in which a curvature trade-off genuinely exists and its optimum is interior. The honest connection to Phase 11 is narrower and better than a de-degeneration claim: `MevJointProgram`'s MODULE docstring locates the escape in DEMAND RESPONSE, and `LEAN_TRACEABILITY` §6(b) records the missing layer as the demand-elasticity / optimal-fee equilibrium layer. \(\varrho_I\) is a CANDIDATE for that layer — a demand-side valuation parameter — though neither source names it. Closing the gap for real means ONE objective containing both a demand-elastic investor and \(\lambda_{\text{ARB}}\); that object exists in neither model and is **OPEN** (E8(7)).

**THE COUPLING, WITH ITS HYPOTHESES.** Under \(c_1(\varphi) > 0\) and \(\varphi < \varrho_I\), at any FIXED realized fee \(\varphi\):

\[
	\begin{aligned}
		\frac{\partial \eta^{\star}}{\partial \varphi} \, = \, \frac{-1}{(1+\varphi)\,\Delta_i^{2}\,\ln\lambda} \, < \, 0
	\end{aligned}
\]

The mechanism: fee and curvature are SUBSTITUTE FRICTIONS on the investor's marginal cost. \(\chi^{\star} = \chi_I\) is the curvature at which the investor stops draining the pool; a higher fee already raises that marginal cost, so the drain regime ends at lower curvature. That is what makes the non-separability economic rather than a chain-rule artifact — and note the rent channel exists at \(\varphi = 0\), so \(\varphi\) modulates the optimum rather than creating it.

THREE BOUNDARIES ON THAT COUPLING, none of which may be dropped:

- \(c_1\) DEPENDS ON \(\varphi\), and its sign at the fee corner is not pinned by anything here. Where \(c_1 \leq 0\) the anchor's own argument puts the pool in the freeze region, the LP payoff is flat in \(\chi\), and **no η is optimal at all** — \(\eta^{\star}\) is then not an argmax.
- FOLLOWING THE COUPLING TO ITS LIMIT SWITCHES THE CONTROLLER OFF: as \(\varphi \to \varrho_I^{-}\), \(\chi^{\star} \to 0\) and \(\eta^{\star} \to 0^{+}\), which E1 identifies as the zero-curvature constant-price grid. Nothing in \(\Theta_{\varphi}\) bounds its fee corner away from \(\varrho_I\), because \(\Theta_{\varphi}\) comes from a model with no \(\varrho_I\) in it. So "η INTERIOR" is not uniform in \(\varphi\).
- \(\bar\varphi\) IS NOT \(\varphi\). `VolInstrument.multiFee` has \(\bar\varphi\) as its FLOOR, not its value (`multiFee_bounds`), and the realized fee is \(\sigma\)-dependent; the Phase-11 corner pins a \(\sigma\)-indexed fee PATH, not a scalar. The corner therefore lowers \(\eta^{\star}(\sigma)\) POINTWISE, giving a \(\sigma\)-indexed \(\eta^{\star}\) while η is a design constant of the grid. Reconciling those two is **OPEN** (E8(8)), and this whole section is stated at a fixed \(\varphi\).

## **E8. [CAVEATS]**

1. **OPEN — THE IDENTIFICATION AND THE EQUILIBRIUM TRANSFER, BOTH.** (a) OBJECT LEVEL: that \(\chi(\eta,\Delta_i)\) — a per-tick relative price step carrying no liquidity term — is the anchor's curvature index `k`, a mixing weight entering structurally in (A.31)/(A.39), is a MODELLING identification, not a definition (E1). (b) EQUILIBRIUM LEVEL: that the tick-grid AMM's arbitrage/investor equilibrium then HAS the anchor's closed forms with \(\chi(\eta,\Delta_i)\) in that slot is ASSUMED, not derived; deriving it means re-solving (A.31)/(A.39) on a discrete grid with per-tick liquidity. Every result above is a theorem about the displayed functions composed with \(\chi(\cdot,\Delta_i)\), and nothing above is a theorem about this project's AMM.
2. **OPEN — WELFARE.** Proposition 6's welfare half is NOT transcribed and does NOT follow from E3 + E4 (E5 gives the reason: the pieces move in opposite directions below \(\chi^{\star}\)). Only the deposit-efficiency half is transcribed. Additionally, the anchor's welfare ranking rests on arbitrage rent being a deadweight loss, which holds only because miners sit outside its agent set — an assumption this document's own `### MEV` section contradicts under rent recycling, so the ranking is not transferable here.
3. **OPEN — THE TWO ARBITRAGE OBJECTS ARE NOT IDENTIFIED.** \(\mathrm{arbLoss}\) and `MevOptimization.mevMulti` (\(\lambda_{\text{ARB}}\)) come from different models with different units — a two-period discrete-shock per-period ratio of pool value against a discrete hazard sum over \(D_t\). No identification is attempted or implied, as forcefully as M0 states that \(\lambda_{\text{ARB}}\) is a summand of \(\lambda_{\text{MEV}}\) and never a sibling.
4. **OPEN — GAS.** Assumption 3 (the arbitrageur pays a gas fee equal to its full profit) is absorbed, not modelled.
5. **OPEN — the \(\Theta_{\varphi}\)-restricted σ-varying MEV comparison**, inherited from Phase 11 (`LEAN_TRACEABILITY` §7.1, last M6b row). This section does not touch it and must not appear to.
6. **OPEN — the factor-share identification** of E0(ii)/E6(ii): the grid exponent η and the reserve-side factor share of `L_eta` are the same parameter under different normalizations only up to a modelling claim; the exponent identity of E6(i) is proven algebra and is all that is claimed here. E6 records that the reading is not merely open but UNAVAILABLE wherever \(\eta^{\star} \notin (0,1)\), which includes the low tick spacings in standard use.
7. **OPEN — THE PHASE-11 DEGENERACY IS NOT RESOLVED HERE.** This section does not de-degenerate the \(\Theta_{\varphi}\) program; `mevMulti` contains no η. Resolving it needs a single objective carrying both a demand-elastic investor and \(\lambda_{\text{ARB}}\), which exists in neither model (E7). \(\varrho_I\) is a candidate for the demand layer named in `LEAN_TRACEABILITY` §6(b), not a closure of it.
8. **OPEN — \(\eta^{\star}\) IS \(\sigma\)-INDEXED, η IS A DESIGN CONSTANT.** The fee entering \(\eta^{\star}\) is a fixed scalar \(\varphi\), whereas this document's fee is \(\mathrm{multiFee}(\sigma)\) and \(\bar\varphi\) is only its floor; the Phase-11 corner therefore induces \(\eta^{\star}(\sigma)\), while the grid exponent η is chosen once. Reconciling a state-dependent target with a fixed grid parameter is not addressed.
9. **OPEN — the strict single-peakedness boundary.** Under \(c_1 \leq 0\) the LP payoff is flat in \(\chi\) (E4) and \(\eta^{\star}\) is not an argmax; the sign of \(c_1\) at the fee corner is not pinned by anything in this section.

Further caveats: this is the anchor's two-period discrete-shock model, not MMR's fast-block diffusion of `### MEV`; the η-parametrization covers \((0,1) \subsetneq [0,1]\), so it neither reaches nor extends the anchor's corners and forbids any `η = 1` ⇔ `χ = 1` reading (E1); and \(\varphi\) is here a FIXED fee, whereas this document's \(\varphi = \mathrm{multiFee}(\sigma)\) varies — the transcription is at a fixed \(\varphi\).

<!-- END ETA -->
