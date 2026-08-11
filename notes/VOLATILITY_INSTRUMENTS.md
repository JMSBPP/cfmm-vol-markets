# VOLATILITY_INSTRUMENTS

> NOTE: [CALCULUS IS THIS ONE](~/learning/cfmm-theory/cfmm-discrete/**) . We need to fgind the discrete ficnacnial caluclus pdf byut Frogy eithr online or locally

# PAYOFF

**Definition 1 (Volatility option).** Fix a strike variance \(\sigma^2_K\). The **volatility option** with vega notional \(\Delta Q_v\) is the contract paying

\[
	\begin{aligned}
		\pi^{\sigma} \, &= \, \Delta Q_{v} \, \Big ( \, \sigma^2 \, (i (t)) - \sigma^2_K\Big)^{+}
	\end{aligned}
\]

where \(\sigma^2(i(t))\) is the realized tick variance. Consequently \(\Delta Q_v \equiv \Delta \pi^{\sigma} / \Delta\big(\sigma^2(i(t)) - \sigma^2_K\big)^{+}\): the notional **is** the option's vega.

*Formalized:* `Panoptic.volOptionPayoff`; `volOptionPayoff_nonneg`; `deltaQv_of_payoff`.

**Convention 2 (Volatility tick argument).** Volatility always takes a **tick argument**: \(\sigma^2(i(t))\) is the variance along the tick path at calendar time \(t\), \(\sigma^2(i(T))\) its value at the horizon \(T\), and \(\sigma^2(i_K) \equiv \sigma^2_K\) the strike variance at the strike tick — the subscript form is declared shorthand for the tick-argument form, as is \(\sigma^2_R(T) \equiv \sigma^2(i(T))\). A bare \(\sigma^2\) is not well-formed. *(Adopted from the converted region upward; the sections below are swept as the pair pass reaches them.)*

**Settlement form of Definition 1.** At unit notional, the contract settles on realized variance at the horizon:

\[
	\begin{aligned}
		\pi^{\sigma} \, (\sigma_K, T; t) \, &= \, \Big (\sigma^2(i(T)) - \sigma^2(i_K)\Big)^{+}
	\end{aligned}
\]
Following [VOL_SWAPS](../refs/DemeterfietalVarianceSwaps.pdf), the price of the volatility option is the *cost of replicating it with options*. This is where [panoptic](https://arxiv.org/pdf/2204.14232) enters. The replication proved in-tree is the **ladder** form (the \(\xi^\star\) log-contract weights, `variancePortfolio_upsilon`); whether it collapses to a **two-instrument** affine form \(p_{\pi^\sigma} = p_0 + a_1\, p_{\pi^{\text{call}}} + a_2\, p_{\pi^{\text{put}}}\) is **OPEN** — statement parked pending the liquidity-side definitions, per the 12.1 ledger.

**Definition 2 (Theta).** The **theta** of the volatility option at strike tick \(i_K\) is the per-time-step payoff variation

\[
	\begin{aligned}
		\theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , p_{(\eta, \Delta_i)} \, (i_K),  \sigma \, (i (t)) \Big ) \, &\equiv \, \frac{\Delta \pi^{\sigma}}{\Delta\, t }
	\end{aligned}
\]

The strike is the price at the STRIKE TICK \(i_K\), on the price grid \(p_{(\eta, \Delta_i)}\) defined under the pricing geometry below (\(\texttt{VolInstrument.priceEta}\)).

*Formalized:* `Panoptic.latticeTheta` (the lattice quotient); `thetaAtm`.

**Proposition 2 (Closed form of θ).** Under the price grid \(p_{(\eta,\Delta_i)}\),

\[
	\begin{aligned}
		\theta \, &= \,  \frac{p_{(\eta, \Delta_i)} \, (\cdot)\, \sigma \, (i(t))}{\sqrt{8\, \pi \, t}} \, \exp \, \Big (-\frac{\Big [- \ln \Big(\frac{p_{(\eta, \Delta_i)} \, (i (t_0))}{p_{(\eta, \Delta_i)} \, (i_K)}\Big) \, + \, \frac{\sigma^2(i(t)) \, t}{2} \Big ]^2}{2\, \sigma^2(i(t))\, t}\Big)
	\end{aligned}
\]

*Formalized (ATM case):* `theta_atm_closed_form` — \(\Theta_{ATM} = k\sigma/\sqrt{8\pi\tau}\). **General form OPEN** — an Aristotle target (lattice → closed form).

**Rule 1 (Option pricing).** The protocol prices the volatility option at strike tick \(i_K\) as **accumulated theta along the realized tick path**:

\[
	\begin{aligned}
		p_{\pi^{\sigma}}\, (t) \, &\leftarrow \, \int_{t_0}^{t} \, \theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; s) \, , p_{(\eta, \Delta_i)} \, (i_K),  \sigma \, (i (s)) \Big ) \, \mathcal{d}\, s
	\end{aligned}
\]

The left arrow marks a Rule, not an identity: this is a stipulation of the protocol, and the implementation either complies with it or does not.

*Formalized:* `Panoptic.streamingPremium` (the discrete accumulation \(\sum_j \theta_j\,\Delta t\)); `streamingPremium_succ`.

**Definition 4 (Upsilon).** The **upsilon** of a premium or payoff functional at strike tick \(i_K\) is its per-unit-variance sensitivity, as a lattice finite difference in the variance argument:

\[
	\begin{aligned}
		\upsilon \, \Big (p_{(\eta, \Delta_i)} \, (i; t) \, , p_{(\eta, \Delta_i)} \, (i_K)\Big)\, &\equiv \, \frac{\Delta \pi^{\sigma}}{\Delta \sigma^2 \, (\cdot)}
	\end{aligned}
\]

*Formalized:* `Upsilon.upsilon` (\(\upsilon[p_\ell] = (p_\ell(\sigma^2{+}\Delta s) - p_\ell(\sigma^2))/\Delta s\)).

**Proposition 3 (Vega bridge).** On the region where the volatility option is in-the-money at both variance endpoints (\(\sigma^2(i_K) \le \sigma^2(i(t))\) and \(\sigma^2(i_K) \le \sigma^2(i(t)) + \Delta s\)), its upsilon **is** its vega notional:

\[
	\begin{aligned}
		\upsilon\big(\pi^{\sigma}\big) \;&=\; \Delta Q_v
	\end{aligned}
\]

— the dimensional bridge the identification sought: \(\upsilon\) occupies the \(\Delta Q_v\) slot (\(= \Delta Q_M/p_{\text{risk}}\) via `Flow.deltaShares`). Off that region the recovery FAILS by construction (the kink); the ATM/OTM null is recorded as a conjecture, unproven.

*Formalized:* `Upsilon.upsilon_volOption`; `upsilon_eq_deltaShares_slot`; at the endogenous maturity \(\upsilon = T^\star/2\) (`variancePortfolio_upsilon_at_tStar`, `tStar_unit_upsilon`).

**Definition 5 (Replicating portfolio).** The **replicating portfolio** \(\Pi^{\sigma}(\sigma; p_{(\eta,\Delta_i)}(i;t))\) is the option portfolio whose sensitivity to realized variance is independent of the underlying price [PG7](../refs/DemeterfietalVarianceSwaps.pdf) — a single option cannot serve, since a price move alters its variance sensitivity.

**Convention 1 (Replication relation).** For payoff claims \(A, B\) we write \(A \equiv^{R} B\) — "\(A\) **is replicated by** \(B\)" — when \(B\)'s payoff reproduces \(A\)'s. This is a *claim about two objects*, not a definitional identity: each instance must be proved, and until it is, it is stated OPEN. (This is the relation the two-instrument question above is posed in.)

**Definition 34 (Forward payoff).** \(\pi^{f}(p_{\varphi};\, p^{\star}) \, \equiv \, p_{\varphi} - p^{\star}\) — unit-notional forward struck at \(p^{\star}\).

**Definition 35 (Log payoff).** \(\pi^{\log}(p_{\varphi};\, p^{\star}) \, \equiv \, \ln\big(p_{\varphi}/p^{\star}\big)\).

([VOL_SWAPS](../refs/DemeterfietalVarianceSwaps.pdf) PG9: the variance exposure is the forward leg net of the log leg, \(\tfrac{2}{T}\big(\pi^{f}/p^{\star} - \pi^{\log}\big)\); Definition 6's log portfolio is the grid realization of \(-\pi^{\log}\)'s spanning, and Definition 5's replicating portfolio is exactly \(\pi^{f}/p^{\star} - \pi^{\log}\) up to the \(2/T\) normalization.)

**Definition 6 (Log portfolio).** For \(p^{\star}\) the approximate at-the-money forward level marking the boundary between liquid puts and liquid calls [PG9](../refs/DemeterfietalVarianceSwaps.pdf), the **log portfolio*  * and its running form are

\[
	\begin{aligned}
		\Pi^{\sigma}\big(\sigma; p_{(\eta,\Delta_i)}(i;t)\big) \, &= \, \frac{p_{(\eta,\Delta_i)}(i;t) - p^{\star}}{p^{\star}} \, - \, \log\Big(\frac{p_{(\eta,\Delta_i)}(i;t)}{p^{\star}}\Big) \, + \, \frac{\sigma^2(i(t))\, t}{2}
	\end{aligned}
\]

(at \(t=0\) the running term vanishes; \(\Pi \geq 0\) with \(\Pi(p^{\star}) = 0\)). Its **unit-vega normalized form** (Theorem 3's \(\text{Id}_{N_\sigma}\)), with the remaining-variance tail:

\[
	\begin{aligned}
		\Pi^{\sigma} \, (\sigma ;p_{(\eta, \Delta_i)} \, (i; t); T) \, &= \, \text{Id}_{ N_{\sigma}} \Big [\frac{p_{(\eta, \Delta_i)} - p^{\star}}{p^{\star}} \, - \, \log (\frac{p_{(\eta, \Delta_i)}}{p^{\star}})\Big] \, + \, \frac{T - t}{T}\, \sigma^2(i(t))
	\end{aligned}
\]

*Formalized:* `VolInstrument.logPortfolio`; `variancePortfolio` (\(= \text{logPortfolio} + \sigma^2(i(t))\, t/2\)); `logPortfolio_nonneg`; `logPortfolio_atm`.

**Settlement instantiation** (Convention 2): \(\Pi^{\sigma}\big(\sigma^2(i(T));\, p_{(\eta,\Delta_i)}(i;t);\, T\big) \, = \, \text{Id}_{ N_{\sigma}} \Big [\frac{p_{(\eta, \Delta_i)} - p^{\star}}{p^{\star}} \, - \, \log (\frac{p_{(\eta, \Delta_i)}}{p^{\star}})\Big] \, + \, \frac{T - t}{T}\, \sigma^2(i(t))\).

**Proposition 4 (Ladder replication).** The volatility option is replicated by the log portfolio:

\[
	\begin{aligned}
		\pi^{\sigma}(t) \, \equiv^{R} \, \Pi^{\sigma}\big(\sigma; p_{(\eta,\Delta_i)}(i;t)\big)
	\end{aligned}
\]

and \(\Pi\) has Definition 5's defining property: its variance sensitivity is **constant in the underlying price**, \(\upsilon(\Pi) = T/2\).

*Status:* the \(\equiv^R\) core is **adapted from the variance-swap text** [Demeterfi](../refs/DemeterfietalVarianceSwaps.pdf) and is **OPEN in-tree** — Convention 1's discipline applies. PROVED: the sensitivity half. OWED: the payoff-reproduction step connecting `variancePortfolio` to `volOptionPayoff` — an Aristotle target.

*Formalized (sensitivity half):* `variancePortfolio_upsilon` (\(\upsilon = t/2\), \(p_{(\eta,\Delta_i)}\)-independent).

**Rule 3 (Ladder allocation).** The protocol realizes the log portfolio on the grid as the strike ladder — the weight profile \(\ell(\xi^{\star},\iota;i_K)\) being a geometric liquidity distribution in the sense of the [Bunni v2 whitepaper](../refs/bunni-v2.pdf) (whose general LDFs \(\ell_{\text{LDF}}(\theta_{\text{LDF}};i_K)\) are the declared FUTURE MILESTONE, G4):

\[
	\begin{aligned}
		\Pi^{\sigma}\big(\sigma; p_{(\eta,\Delta_i)}(i;t)\big) \, \leftarrow \, \sum_{i_K} L_{(1/2,\,0)}(i_K)\, \Pi^{\sigma}\big(\sigma_K; p_{(\eta,\Delta_i)}(i;t)\big), \qquad L_{(1/2,\,0)}(i_K) = \bar L_{(1/2,\,0)}\,\ell(\xi^{\star},\iota; i_K)
	\end{aligned}
\]

The left arrow marks the Rule: an **allocation the protocol enforces**, not an equality — \(\Pi^{\sigma}(\sigma_K;\cdot)\) is the per-strike member at strike tick \(i_K\), and \(L\) is Definition 7's ladder. Whether the enforced ladder's payoff reproduces the log contract is part of Proposition 4's OPEN core, not asserted here.

*Formalized (weight law):* `GeomProfile.varswapWeight_geometric`; `logContractLiquidity_geometric`; `VolInstrument.strikeWeight_bridge` (\(\xi^{\star} = \lambda^{-\Delta_i/2}\)).

**Definition 7 (Liquidity ladder).** Per strike tick \(i_K\), the ladder allocates the total liquidity \(\bar L_{(1/2,\,0)}\) by the geometric weight profile

\[
	\begin{aligned}
		L \, (i_K) \, &= \, \bar L_{(1/2,\,0)} \, \ell \, (\xi, \iota; i_K), \qquad \bar L_{(1/2,\,0)} \, = \sum_{i_K = i_{\text{min}}}^{i_{\text{max}}} \, L \, (i_K), \qquad \ell \, (\xi, \iota; i_K) \, = \, \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)}
	\end{aligned}
\]

with ladder parameter set \(\Theta_{\ell} = \{\xi, \iota\}\) — see **PROTOCOL_PARAMETERS (\(\Theta_{\ell}\))**.

*Formalized:* `GeomProfile.geomWeight`.

**Theorem 2 (Partition of unity).** The weights are a partition of unity and the δ-neutral ratio is pinned:

\[
	\begin{aligned}
		\sum_{i_K} \, \ell \, (\xi, \iota; i_K) \, = \, 1, \quad \ell > 0 \; (\xi \in (0,1) \cup (1,\infty)), \quad \lim_{\xi \to 1} \ell \, = \, \frac{1}{\iota}
	\end{aligned}
\]

*Formalized:* `GeomProfile.geomWeight_sum`; `geomWeight_pos`; `geomWeight_tendsto_uniform`.

### PROTOCOL_PARAMETERS

Every parameter of the protocol enters here as a **Protocol Parameter** — a special definition that
fully specifies its **domain**, its **purpose**, and its **economic meaning**, indexed by its
parameter set. A parameter not listed here is not a parameter of the protocol.

**Protocol Parameter (\(\Theta_{\ell} = \{\xi, \iota\}\) — the ladder).**

- \(\xi\) — the **liquidity ratio**.
  *Domain:* \(\xi \in (0,1) \cup (1,\infty)\); \(\xi = 1\) is reached by limit only (Theorem 2).
  *Purpose:* sets the geometric decay of per-strike liquidity in the ladder (Definition 7); with \(\iota\), encodes the strike weights that make the portfolio **delta-neutral**.
  *Economic meaning:* the ratio of liquidity between adjacent strikes; pinned at \(\xi^{\star} = \lambda^{-\Delta_i/2}\), the log-contract weight law under which the ladder replicates the variance payoff (Proposition 4).

- \(\iota\) — the **ladder resolution**.
  *Domain:* \(\iota \in \mathbb{N}\), \(\iota \ge 1\).
  *Purpose:* the number of strikes carrying the ladder (Definition 7); the weight profile lives on the simplex \(\Delta^{\iota-1}\); with \(\xi\), encodes the **delta-neutral** strike weighting.
  *Economic meaning:* the resolution at which the continuous log-contract strip is discretized — the finite-strip replication error and the G4 underspecification deficit (\(\iota - 2\)) are both functions of it.

**Protocol Parameter (\(\Theta_{p} = \{\eta, \Delta_i\}\) — the pricing geometry).**

- \(\eta\) — the **grid exponent**.
  *Domain:* \(\eta > 0\) (jointly with \(\Delta_i > 0\) this is exactly the strict-monotonicity hypothesis \(\eta\,\Delta_i > 0\), `priceEta_strictMono`; \(\eta = 1\) is the canonical grid).
  *Purpose:* the one-parameter deformation of the tick-price law (Definition 8) — the exponent tilting the grid away from the square-root-price member.
  *Economic meaning:* the grid-side tilt dial. It is **not** the trading-curve share: \(\eta\) enters the curve only through the proven bridge \(\chi_{X/M}(\eta) = \Lambda(\eta\,\Delta_i \ln\lambda/2)\), and the genuine curvature \(\kappa_{\varphi}\) does not depend on it at all (a function of \(\epsilon_{X/M}\) alone).

- \(\Delta_i\) — the **tick spacing**.
  *Domain:* \(\Delta_i > 0\) (the Lean leg-nonnegativity theorem needs \(\Delta_i \geq 0\) in addition to \(\eta\,\Delta_i > 0\); on-chain it is the positive integer tick spacing of [UNI_V3](../refs/uniswap-v3-core.pdf)).
  *Purpose:* grid granularity — the quantization step at which strikes, hence ladder legs, may sit (Definition 8).
  *Economic meaning:* the spacing pins the ladder ratio \(\xi^{\star} = \lambda^{-\Delta_i/2}\) (\(\Theta_{\ell}\) entry) and sets the per-spacing price step \(\lambda^{\eta\Delta_i/2}\) — the coarseness lever coupling the pricing geometry to the replication ladder.

> On the grid, \(\eta\) and \(\Delta_i\) are REDUNDANT — they enter only through the product \(\eta\Delta_i\) (Theorem 21); they separate off-grid (\(\xi^{\star}\), Proposition 6).

**Protocol Parameter (\(\Theta_{\varphi} = \{\chi_{X/M}, \epsilon_{X/M}\}\) — the trading curve).**

- \(\chi_{X/M}\) — the **share parameter**.
  *Domain:* \(\chi_{X/M} \in (0,1)\) (Definition 12).
  *Purpose:* the exponent weighting the \(\Delta Q_M\) leg of the trading function (Definition 12); first slot of the subscript tuple \((\chi_{X/M}, \epsilon_{X/M})\).
  *Economic meaning:* the SHARE (distribution) parameter — the fraction of pool value held in the \(\Delta Q_M\) leg; it says WHERE the value sits. \(\chi_{X/M} = 1/2\) is the balanced pool; moving it tilts inventory toward one leg WITHOUT changing how the curve resists trade. Via the proven bridge \(\chi_{X/M}/(1-\chi_{X/M}) = \lambda^{\eta\Delta_i/2}\) it is an **observable of the price grid**, not an independent primitive — subject to the OPEN leg-orientation FLAG (Definition 12), which flips the bridge.

- \(\epsilon_{X/M}\) — the **substitution parameter**.
  *Domain:* \(\epsilon_{X/M} \in (-\infty, 1]\) — \(\epsilon_{X/M} = 1\) the linear member (perfect substitutes, \(\bar\epsilon_{X/M} = \infty\)); \(\epsilon_{X/M} = 0\) the defined Cobb–Douglas case (constant product); \(\epsilon_{X/M} \to -\infty\) the Leontief limit (no trade).
  *Purpose:* the substitution axis of Definition 13, second slot of the subscript tuple; the elasticity of substitution is \(\bar\epsilon_{X/M} = 1/(1-\epsilon_{X/M})\), and the genuine curvature \(\kappa_{\varphi}\) is a function of this axis ALONE. Proven orthogonal to the share axis (`phiCES_rho_ne_eps_axis`; \(\varsigma_{X/M}\) factors through the share, `curvIndex_is_rho_zero_slice`).
  *Economic meaning:* the slippage dial — HOW HARD the pool resists being moved. This is what an arbitrageur pays for: less substitutability means more price impact per unit extracted — and equally worse execution for the ordinary investor, which is why both effects move together and produce an interior optimum.

**Protocol Parameter (\(\Theta_{\phi} = \{\gamma, \bar\phi, \beta, \alpha\}\) — the fee schedule).**

- \(\bar\phi\) — the **fee floor**.
  *Domain:* \(\bar\phi \geq 0\).
  *Purpose:* the unconditional base of the schedule (Definition 18).
  *Economic meaning:* LPs take a base fee at every volatility — the schedule never degenerates to free execution (Theorem 1's lower envelope).

- \(\alpha = \{\alpha_j, \alpha_R\}\) — the **surcharge scales**.
  *Domain:* \(\alpha_j \geq 0\), \(\alpha_R \geq 0\).
  *Purpose:* scale each sigmoid's maximum ([ALGEBRA](../refs/algebra-tech-paper.pdf) eq. (4)); \(\sum_j \alpha_j\) times the gate ceiling \(\alpha_R\) sets the width of Theorem 1's fee band.
  *Economic meaning:* the volatility surcharge budget — what heavy trading in volatile conditions can add above the floor.

- \(\beta = \{\beta_j, \beta_R\}\) — the **transition midpoints**.
  *Domain:* real.
  *Purpose:* place each sigmoid's transition; they position the ramp *inside* the band without moving its edges.
  *Economic meaning:* the volatility (resp. utilization) levels at which the surcharge switches on — G3's placement-not-level reading.

- \(\gamma = \{\gamma_j, \gamma_R\}\) — the **steepnesses**.
  *Domain:* \(\gamma_j > 0\) (Theorem 1's monotonicity hypothesis).
  *Purpose:* the ramp steepness (single-term case: \(s_f = 1/\gamma_0\)).
  *Economic meaning:* how sharply the schedule reacts near its midpoint — the dial between smooth repricing and a near-step surcharge.

> Parameter registry COMPLETE: \(\Theta_{\ell}\), \(\Theta_{p}\), \(\Theta_{\varphi}\), \(\Theta_{\phi}\). The former \(\Theta_{\text{ord}}\) is NOT a parameter set — it is user-supplied per order and lives as \(\mathcal{I}_{\text{ord}}\) under **# PROTOCOL_INPUTS** (the third registry class).

### PROTOCOL_CONSTANTS

Every fixed numeral of the protocol enters here as a **Protocol Constant** — a value the protocol fixes once, **not a design dial**: it belongs to no \(\Theta_{\bullet}\), and no statement may treat it as free. Indexed by its constant set.

**Protocol Constant (\(\mathcal{C}_{p} = \{\lambda\}\) — the pricing geometry).**

- \(\lambda\) — the **tick base**.
  *Value:* \(\lambda = 1.0001\) ([UNI_V3](../refs/uniswap-v3-core.pdf)).
  *Purpose:* the base of the price grid (Definition 8); every grid ratio in the document — \(\lambda^{-\Delta_i}\) (Theorem 4), \(\xi^{\star} = \lambda^{-\Delta_i/2}\) (Proposition 6, \(\Theta_{\ell}\)) — is a power of it.
  *Economic meaning:* one tick = one basis point of price — the minimal price quantum of the underlying market.
  *Formalized:* `PosSpec.lam` (`lam_pos`); hardcoded as `1.0001` in the `GeomProfile` carriers.

**Proposition 5 (Single-leg direction sensitivity).** A single leg's variance sensitivity is direction-sensitive:

\[
	\begin{aligned}
		\frac{\Delta \pi^{\sigma}}{\Delta \, \sigma} \, &\approx \frac{\Delta \theta}{\Delta \sigma}
	\end{aligned}
\]

inheriting the sign of \(\ln \big(p_{(\eta, \Delta_i)}(i;t) / p_{(\eta, \Delta_i)}(i_K)\big)\) — a single option cannot carry Definition 5's price-independence, which is why the ladder exists.

*Status:* **OPEN** — pinned in-tree as `Upsilon.ATMOTMNullHypothesis`, a Prop **conjecture, no proof, no axiom**. One correction is machine-recorded and travels with it: the naive strike-centered envelope \(e^{-c|i-i_K|}\) is **FALSE on the entire left branch for every** \(c > 0\) (the forward difference is right-shifted; a parameter-independent obstruction) — the honest envelope is centered on the peak pair \(\{i_K{-}1, i_K\}\). The conjecture's originally named test avenue (the econometric track) is CLOSED-terminal, so it either gets a formal proof or stays open.

**Theorem 3 (Unit vega).**

\[
	\begin{aligned}
		\frac{\Delta \, \Pi^{\sigma} \, ( \cdot )}{\Delta \, \sigma^{2} } N_{\sigma} \, &= \, T/2 \, N_{\sigma} \, \implies \text{Id}_{ N_{\sigma}} \, \equiv \frac{2}{T}
	\end{aligned}
\]

*Formalized:* `VolInstrument.variancePortfolio_unit_upsilon`.

**Theorem 13 (Maturity equivalence).** *(Moved here from # PROTOCOL_INPUTS, user ruling 2026-08-04 — both premises are this section's results; \(\Delta Q_v^{\star}\) is the target-vega Protocol Input, # PROTOCOL_INPUTS.)* From \(\upsilon = T/2\) (`variancePortfolio_upsilon`) and \(\text{Id}_{N_\sigma} = 2/T\) (`variancePortfolio_unit_upsilon`):

\[
	T^{\star} \,=\, 2\,\frac{\Delta Q_v^{\star}}{N_\sigma} \quad\Longleftrightarrow\quad \Delta Q_v^{\star} \,=\, \frac{T^{\star}}{2}\, N_\sigma
\]

with \(\Delta Q_v^{\star}, N_\sigma > 0 \implies T^{\star} > 0\), and \(T^{\star}\) strictly increasing in \(\Delta Q_v^{\star}\), strictly decreasing in \(N_\sigma\). The perpetual order specifies no \(T\); \(T^{\star}\) is the implied maturity of the equivalent dated variance contract — derived from \(\Delta Q_v^{\star}\), never stored.

*Formalized* (`EndogenousMaturity.lean`; \(N_\sigma \neq 0\)): bijection `dQvStarOfMaturity_tStar` / `tStar_dQvStarOfMaturity` / `maturity_equivalence`; vega-exactness `tStar_variancePortfolio_upsilon`, `tStar_unit_upsilon`; `tStar_pos`; `tStar_strictMono_dQvStar`; `tStar_strictAnti_Nσ`.
**Rule 4 (Position ledger — measure form; AMENDED 2026-08-11, the indicator replaced by the Dirac pair).** The protocol books a position as a **signed measure on the price line**: each leg at strike \(i_K\) contributes the Dirac pair at its fee prices (Definition 39), signed by direction —

\[
	\begin{aligned}
		d\widetilde{L}_{(\chi_{X/M},\,\epsilon_{X/M})}(i_K) \, &\leftarrow \, \pm\, L_{(1/2,\,0)}(i_K)\,\Big[\delta\big(P_{\varphi}^{(\mathrm{ask})}(i_K)\big) - \delta\big(P_{\varphi}^{(\mathrm{bid})}(i_K)\big)\Big], \qquad
		\begin{cases}
		- & \text{long (liquidity removed — burn)} \\
		+ & \text{short (liquidity minted)}
		\end{cases} \\
		\pi^{\sigma}(\sigma_K, T; t) \, &\leftarrow \, \sum_{i_K} \int_{i_K} d\widetilde{L}_{(\chi_{X/M},\,\epsilon_{X/M})}(i)
	\end{aligned}
\]

\(\delta\) the Dirac function ([CLMM_DYN](../refs/cfmm/tung_wang-clmm_dynamics_continuous_time-2024.pdf) §3.2.2 — the liquidity profile as the CDF of a σ-finite signed measure; a concentrated position IS an atom pair). **THE PROVED LAYER sits one derivative below** (Theorem 37): the reserve is the call spread whose FIRST derivative is the Heaviside step pair; the Dirac pair is its distributional second derivative — DECLARED, not machine-claimed.

**Theorem 37 (Ramp band — the proved layer).** For band edges \(a \leq b\) and the call payoff \((t-K)^{+}\):

\[
	\begin{aligned}
		(t-a)^{+} - (t-b)^{+} \, = \,
		\begin{cases}
			0 & t \leq a \\
			t - a & a \leq t \leq b \\
			b - a & b \leq t
		\end{cases}, \qquad
		\frac{\partial}{\partial t}\Big[(t-a)^{+} - (t-b)^{+}\Big] \, = \, \mathbb{1}_{(a,b)}(t) \;\; \text{off the kinks}
	\end{aligned}
\]

— \(Q_X^L\big(P_{\varphi}\big) = \bar L_{(\chi_{X/M},\epsilon_{X/M})}\big[(P_{eq} - P_{\varphi}^{(\mathrm{ask})})^{+} - (P_{eq} - P_{\varphi}^{(\mathrm{bid})})^{+}\big]\) (user TODO item 4) is this object; its second distributional derivative is Rule 4's Dirac pair.

*Formalized* (`MarketMaking`, project `d1ad6474`, axiom-clean): `ramp_band`; `ramp_band_deriv`.

The sign is **per leg** (`isLong` in the Panoptic tokenId), so mixed-direction ladders are expressible. Leg **type** is not an index here: put or call is determined structurally by the strike against \(p^{\star}\) — puts below, calls above (Definition 6) — and is carried by `tokenType`.

*Formalized:* the leg encoding lives in `PanopticTokenId.plk` (`isLong`, `tokenType`); the doc-side ledger statement is **UNFORMALIZED** — no Lean carrier states it yet.

# PRICING_GEOMETRY

**Definition 8 (Price grid).** The **price grid** is the map assigning to each tick \(i\) the value

\[
	\begin{aligned}
		p_{(\eta, \Delta_i)} (i) \, &\equiv \, \lambda^{i/2 \, \Delta_i \, \eta}
	\end{aligned}
\]

where \(\lambda\) is the fixed tick base — a **Protocol Constant** (see **PROTOCOL_CONSTANTS (\(\mathcal{C}_p\))**), not a member of \(\Theta_p\) — and \((\eta, \Delta_i) = \Theta_p\) are Protocol Parameters (see **PROTOCOL_PARAMETERS (\(\Theta_p\))**). At \(\eta = 1\) the grid is the canonical square-root-price tick law of [UNI_V3](../refs/uniswap-v3-core.pdf) (`priceEta_one`); the strike price of Definition 1 is the grid at the strike tick, \(p_{(\eta,\Delta_i)}(i_K)\).

*Formalized:* `VolInstrument.priceEta`; `priceEta_pos` (positivity, unconditional); `priceEta_strictMono` (under \(\eta\,\Delta_i > 0\)); `priceEta_one` (\(\eta = 1\) recovers `PosSpec.tickPrice`).

\(\eta\) (price grid) and \(\chi_{X/M}\) (trading curve, \(\varphi_{(\chi_{X/M},\,0)}\)) are DISTINCT parameters on distinct objects; they are not two names for one exponent. Their relation is a THEOREM, not a definition — see the \(\chi_{X/M} \leftrightarrow \eta \leftrightarrow \varsigma_{X/M}\) block. <!-- notation-map -->

**Theorem 21 (Half-kernel factorization: rescaling and partition change).** Definition 8's grid factors through the canonical geometry in two ways.

(i) **Rescaling:** \(p_{(\eta,\Delta_i)} = p_{(1,\,\eta\Delta_i)}\) — on the grid, \(\eta\) and \(\Delta_i\) enter ONLY through the product \(\eta\Delta_i\); the grid alone cannot identify them separately (they separate off-grid: \(\xi^{\star} = \lambda^{-\Delta_i/2}\), Proposition 6, depends on \(\Delta_i\) alone).

(ii) **Partition change (the pricing-implementation theorem):** for ANY admissible \((\eta, \Delta_i)\) and any reference spacing \(\bar\Delta_i \neq 0\), the price is a PRODUCT of two canonical-geometry prices whose tick arguments are functions of the current tick:

\[
	\begin{aligned}
		p_{(\eta,\Delta_i)}(i) \, = \, p_{(1,\bar\Delta_i)}(i^{\star}) \cdot p_{(1,\bar\Delta_i)}(i^{\circ}), \qquad i^{\star} = i^{\circ} = \frac{i\,\Delta_i\,\eta}{2\,\bar\Delta_i}
	\end{aligned}
\]

exactly on integer ticks under the commensurability \((i^{\star}+i^{\circ})\,\bar\Delta_i = i\,\Delta_i\,\eta\); an Int24-windowed split with witnesses \(i_- = \lfloor \eta\, i \rfloor\), \(i_+ = i - i_-\) realizes it inside the Uniswap/Plank tick domain. This is why the ½ sqrt-price algebra CLOSES under \(\eta\) — the plank implementation prices every \(\eta\) member using only canonical-kernel evaluations. *Convention bridge:* the exp layer states these on its \(\bar\eta\)-kernel, whose canonical member is written \(\bar\eta = 1/2\); by T28'a's factor two that member IS Definition 8's \(\eta = 1\) grid, and the identity makes no factor-share identification.

*Formalized:* `CFMM.Eta.p_eta_partition_change`; `exists_partition_change`; `p_eta_partition_change_int` (`exp/EtaPartitionChange`); Int24 split `eta_split_kernel_identity` (`exp/eta`); rescaling `p_eta_eq_P_half_rescaled`; update rule `p_eta_post_eq` (`exp/EtaReplication` — the plank-implemented half); convention bridge `EtaCurvature.priceEta_eq_p_eta_half`, `priceEta_eq_P_half` (T28'a).

**Theorem 4 (Geometric strike-notional weights).** On the price grid \(\lambda^{i\,\Delta_i}\) — the square of Definition 8's grid at \(\eta = 1\) (`priceGrid_eq_tickPrice_sq`) — the discretized strike-notional weights of the log contract are exactly geometric:

\[
	\begin{aligned}
		\frac{\lambda^{(i+1)\Delta_i} - \lambda^{i\,\Delta_i}}{\big(\lambda^{i\,\Delta_i}\big)^{2}} \, = \, (\lambda^{\Delta_i}-1)\,\big(\lambda^{-\Delta_i}\big)^{i}
	\end{aligned}
\]

with ratio \(\lambda^{-\Delta_i}\) — \(\lambda\) the fixed tick base (Protocol Constant \(\mathcal{C}_p\)), so the ratio is a function of the protocol parameter \(\Delta_i\) alone. Normalized, the weights are the geometric profile at that ratio, and Theorem 2's partition of unity applies.

*Formalized:* `GeomProfile.varswapWeight_geometric`; `varswapWeight_normalized`.

**Proposition 6 (The liquidity ratio \(\xi^{\star}\)).** The per-tick *liquidity* replicating the log contract scales as the inverse square root of that grid, hence

\[
	\begin{aligned}
		\xi^{\star} \, = \, \lambda^{-\Delta_i/2} \quad \text{(NOT } \lambda^{-\Delta_i}\text{; the two differ by the tranche-gamma Jacobian)}
	\end{aligned}
\]

\(\lambda\) being fixed (\(\mathcal{C}_p\)), \(\xi^{\star}\) is pinned by \(\Delta_i\) alone — consistent with the \(\Theta_{\ell}\) registry entry, where \(\xi\) is the parameter and \(\xi^{\star} = \lambda^{-\Delta_i/2}\) its pinned value.

**Definition 38 (Gamma).** \(\Gamma_{\varphi} \, \equiv \, \frac{\partial^2 \pi^{\varphi}}{\partial (p_{\varphi})^2}\) — the second derivative of Definition 25's portfolio value against the marginal price (Definition 14). Closed form, for every member (Theorem 32):

\[
	\begin{aligned}
		\Gamma_{\varphi} \, = \, -\tfrac{1}{2}\;\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}\;p_{\varphi}^{-3/2}
	\end{aligned}
\]

SUBSTITUTION RULE: \(\Gamma_{\varphi}\) replaces the \(p_{\varphi}^{\pm 3/2}\)-shaped EXPRESSIONS where they are this object — never a derivative operator (user ruling 2026-08-11).

**Theorem 38 (Gamma grid — the \(\xi\)-coordinatization) *(promoted from Proposition 14 — the number is retired, not reused)*.** On the grid, at the pinned member (\(\chi_{X/M} = 1/2\); consumes Theorem 40's inverse-product form and inherits its orientation FLAG):

\[
	\begin{aligned}
		\Gamma_{\varphi}(i_K) \, = \, -\tfrac{1}{2}\,\bar L_{(1/2,\,0)}\;\xi^{\,-3\eta\,(i_K + \Delta_i/2)}, \qquad
		\frac{\Gamma_{\varphi}(i_K+\Delta_i)}{\Gamma_{\varphi}(i_K)} \, = \, \xi^{\,-3\eta\,\Delta_i}
	\end{aligned}
\]

— **gamma units**: \(\Gamma_{\varphi}\) is a pure \(\xi\)-power of the tick, exactly as \(p_{(\eta,\Delta_i)}\) is a \(\lambda\)-power of it; the factor \(3 = \tfrac{3}{2}\times 2\) (the \(p^{3/2}\) shape composed with the marginal-price step being the SQUARE of the grid step). *Formalized* (`GammaGrid`, project `589d44ac`, axiom-clean): `gamma_grid_level`, `gamma_grid_ratio`, via `pPhiGrid_eq` — the marginal grid price is itself a pure \(\lambda\)-power.

**Definition 41 (The gamma coordinate).** \(\gamma(i) \, \equiv \, -\,3\eta\,\big(i + \tfrac{\Delta_i}{2}\big)\) — the \(\xi\)-coordinate warped by the factor \(3\eta\), the half-spacing offset from the marginal price's adjacent product. \(\xi\) is the LIQUIDITY coordinate; \(\gamma\) is DERIVED from it (user proposal 2026-08-11).

**Theorem 39 (The compositional reading; the flatness threshold).** With \(L(t) \equiv \bar L_{(1/2,\,0)}\,\xi^{t}\) the \(\xi\)-geometric liquidity read on the tick coordinate:

\[
	\begin{aligned}
		\Gamma_{\varphi}(i_K) \, &= \, -\tfrac{1}{2}\,L\big(\gamma(i_K)\big) \qquad \textbf{(gamma IS the liquidity at the warped tick)} \\
		\text{ladder in place of } \bar L: \quad \Gamma_{\varphi}(i_K) \, &= \, -\tfrac{1}{2}\,\bar L_{(1/2,\,0)}\;\xi^{\,(i_K - i_0)/\Delta_i \, - \, 3\eta(i_K + \Delta_i/2)} \\
		\text{strike-independent} \; &\iff \; \eta\,\Delta_i \, = \, \tfrac{1}{3}, \qquad \text{flat value } \; -\tfrac{1}{2}\,\bar L_{(1/2,\,0)}\;\xi^{-(i_0/\Delta_i + 1/2)}
	\end{aligned}
\]

The state-space closed form (Theorem 32) and this grid-space reading COINCIDE — two presentations of one object. At \(\eta\Delta_i = 1/3\) the grid+ladder EMULATES the constant-gamma curve \(\varphi^{\sigma}\) (Theorem 36) on the existing primitive. BRIDGES: the LDF (Phase 15.2) designs the \(\Gamma_{\varphi}\) profile through a pure coordinate change; on-chain (G5) \(\Gamma_{\varphi}\) is a \(\xi\)-exponent lookup, no \(p^{3/2}\) mulDiv chain.

*Formalized* (`GammaCoordinate`, project `2370c633`, axiom-clean): `gamma_is_L_at_gammaCoord`; `ladder_gamma_power`; `ladder_gamma_flat_iff` (both directions); `ladder_gamma_flat_value`.

*(Proposition 6's sampling half stays proved — `logContractLiquidity_geometric`, `strikeWeight_bridge`; its replication premise is the log-payoff instance \(\Gamma_{\varphi}[\pi^{\log}] = -1/p_{\varphi}^{2}\), OPEN pending \(\pi^{\log}\)'s carrier.)*


# TRADING_REGION

> Use L_{1/2,  0} not plain L
**Definition 9 (Per-strike amounts).** On the underlying market \((X, M)\), the liquidity \(L_{(1/2,\,0)}(i_K)\) at strike tick \(i_K\) holds the per-strike token amounts

\[
	\begin{aligned}
		\Delta Q_M^{L} (i_K) \, &\equiv \, L \, (i_K) \Big [ \frac{p_{(\eta, \Delta_i)} (i_K + \Delta_i) \, - \, p_{(\eta, \Delta_i)} (i_K)}{p_{(\eta, \Delta_i)} (i_K) \, p_{(\eta, \Delta_i)} (i_K + \Delta_i)}\Big] \\
		\\
		\Delta Q_X^L \, (i_K) \, &\equiv \, L \, (i_K) \Big [ p_{(\eta, \Delta_i)} (i_K + \Delta_i) \, - \, p_{(\eta, \Delta_i)} (i_K) \Big ]
	\end{aligned}
\]

identical to the per-rick amounts of [BUNNI_V2](../refs/bunni-v2.pdf) §2.3, eqs. (10)–(13), at \(\eta = 1\) — stated here on the general grid \(p_{(\eta,\Delta_i)}\) (Definition 8). \(M \leftrightarrow \text{token}_0\), \(X \leftrightarrow \text{token}_1\). **PR-REGION OPEN:** the legs are stated unsigned; the admissibility region of signed flows is not yet defined — Theorem 5's \(\Delta_i \geq 0\) hypothesis currently stands in for it.

*Formalized:* `VolInstrument.deltaQM`, `deltaQX` (the defining displays).

**Theorem 5 (Leg nonnegativity, reciprocal money leg).** Nonnegativity of both legs requires \(\Delta_i \geq 0\) in addition to \(\eta\,\Delta_i > 0\) (\(\eta,\Delta_i < 0\) makes \(i_K + \Delta_i < i_K\) and reverses signs), and the money leg is the reciprocal-price difference:

\[
	\begin{aligned}
		0 \leq L, \; \eta\,\Delta_i > 0, \; \Delta_i \geq 0 \;\implies\; \Delta Q_M^L, \Delta Q_X^L \geq 0; \qquad
		\Delta Q_M^{L}(i_K) \, = \, L_{(1/2,\,0)}(i_K)\Big[\frac{1}{p_{(\eta, \Delta_i)}(i_K)} - \frac{1}{p_{(\eta, \Delta_i)}(i_K+\Delta_i)}\Big]
	\end{aligned}
\]

The reciprocal form is exactly [BUNNI_V2](../refs/bunni-v2.pdf) eq. (10)'s shape.

*Formalized:* `VolInstrument.deltaQM_nonneg`; `deltaQX_nonneg`; `deltaQM_token0`.

**Definition 10 (Cumulative amounts).** The **cumulative amounts** aggregate the per-strike amounts from the money side down and the asset side up:

\[
	\begin{aligned}
		Q_M^L (i_K) \, &\equiv \sum_{i=i_K}^{i_{\text{max}}} \, \Delta Q_M^{L}\, (i) \\
		\\
		Q_X^L \, (i_K) \, &\equiv \, \sum_{i=i_{\text{min}}}^{i_K} \Delta Q_X^L \, (i)
	\end{aligned}
\]

identical to the cumulative amount functions of [BUNNI_V2](../refs/bunni-v2.pdf) §2.3, eqs. (14)–(15).

**Definition 11 (Inverse cumulative amounts).** The **inverse cumulative amounts** map a target amount back to the extremal strike tick attaining it:

\[
	\begin{aligned}
	    Q_M^L (\bar Q_M)^{-1} \, &\equiv \, \text{arg max}_{i} \Big \{ Q_M^L (i_K): Q_M^L (i_K) \geq \bar Q_M\Big\}\\
		\\
			Q_X^L (\bar Q_X )^{-1} \, &\equiv \, \text{arg min}_{i} \Big \{ Q_X^L (i_K): Q_X^L (i_K) \geq \bar Q_X\Big\}\\
	\end{aligned}
\]

identical to the inverse cumulative amount functions of [BUNNI_V2](../refs/bunni-v2.pdf) §2.4, eqs. (22)–(23) — including the arg max/arg min asymmetry, which mirrors the opposed summation directions of Definition 10.

**Theorem 6 (Monotonicity and telescoping).** Both cumulatives are monotone in the step count (for \(L \geq 0\)), so the inverse cumulatives of Definition 11 are well-defined least attaining steps; for the constant ladder \(L \equiv \bar L_{(1/2,\,0)}\) they telescope to closed form:

\[
	\begin{aligned}
		Q_X^L \, = \, \bar L_{(1/2,\,0)}\,\big[p_{(\eta, \Delta_i)}(i_{\min}+n\Delta_i) - p_{(\eta, \Delta_i)}(i_{\min})\big], \qquad
		Q_M^L \, = \, \bar L_{(1/2,\,0)}\,\Big[\frac{1}{p_{(\eta, \Delta_i)}(i_{\min})} - \frac{1}{p_{(\eta, \Delta_i)}(i_{\min}+n\Delta_i)}\Big]
	\end{aligned}
\]

*Formalized:* `VolInstrument.cumulativeQM_monotone`; `cumulativeQX_monotone`; `cumulativeQM_const`; `cumulativeQX_const`; `exists_least_reaching`.

*(The Bunni-v2 symbol remap that stood here was REMOVED — user ruling 2026-08-11; the structural identification of Definition 7's \(\ell\) with Bunni's geometric LDF survives at Rule 3 and Phase 15.2's reference.)*

**Definition 12 (Weighted-geometric-mean trading function).** *This family — and every member of Definition 13 — is the QUANTITY-COORDINATE (reserve-space) parametrization of the trading function; the price-coordinate parametrization is the canonical one (Theorem 33), reached through the level set.* For share parameter \(\chi_{X/M} \in (0,1)\), the **trading function** at strike tick \(i_K\) takes as exogenous a trading flow \(\Delta Q = (\Delta Q_M, \Delta Q_X)\) and returns

\[
	\begin{aligned}
		\varphi_{(\chi_{X/M},\,0)} \, (i_K ; \Delta Q , L)\, &\equiv \, \big(\Delta Q_M^{L} (i_K) + \Delta Q_M\big)^{\chi_{X/M}}\cdot\big(\Delta Q_X^L \, (i_K) \, + \, \Delta Q_X\big)^{1-\chi_{X/M}}
	\end{aligned}
\]

The flow is **exogenous** — trade legs arriving against the endowed per-strike amounts of Definition 9: the endowments are the state, the flow is the input. It is a **trading function** in the sense of [CFMM_GEOMETRY](../refs/cfmm/angeris-geometry_of_cfmms-2023.pdf), already in canonical form (nondecreasing, concave, homogeneous); its logarithm is the weighted logarithmic utility of [AMM_AXIOMS](../refs/cfmm/bichuch_feinstein-axioms_for_amms-2022.pdf) App. B.2 (their weight \(w \mapsto \chi_{X/M}\); the former collision with the order width is MOOT — the width is now \(\#_{\sigma} \in \mathcal{I}_{\text{ord}}\)), evaluated on per-strike **virtual reserves** in the sense of their App. B.3 (\(\alpha, \beta \mapsto \Delta Q_M^L_{(1/2,\,0)}(i_K), \Delta Q_X^L_{(1/2,\,0)}(i_K)\)). <!-- notation-map -->

The display is one member of a parameterized class: the subscript tuple is \((\chi_{X/M}, \epsilon_{X/M})\), the second slot the substitution parameter, with \(\epsilon_{X/M} = 0\) the Cobb–Douglas member. Whether \(\varphi_{(\chi_{X/M},\,\epsilon_{X/M})}\) satisfies the Bichuch–Feinstein axioms is **not asserted here** — their B.2 alone satisfies all of them (Table 1), but its composition with B.3 virtual reserves is unverified (a later Proposition). **The domain of the flow is OPEN (PR-REGION):** the region over which \(\Delta Q\) ranges — signedness of the legs and the admissibility set — is not yet defined; no region symbol is minted pending that ruling.

*Formalized:* `PhiCES.phiCES` — **opposite leg orientation; the FLAG below is OPEN**.

> **FLAG (open, 2026-08-03): LEG ORIENTATION OF \(\chi_{X/M}\).** The display above puts \(\chi_{X/M}\) on the \(\Delta Q_M\) leg; the CES definition below puts it on the \(Q_X\) leg (and matches Lean `PhiCES.phiCES`). One of the two must change, and the choice flips the \(\chi/(1-\chi) = \lambda^{\eta\Delta_i/2}\) bridge and the reading of `curvIndex_is_rho_zero_slice`. Theorem 1 consumes the \(\Delta Q_M\)-leg form. AUTHOR DECISION REQUIRED — not resolved by the rename. <!-- notation-map -->

**BINDING (user, 2026-08-03): \(\epsilon\) is reserved for ELASTICITIES, always subscripted to differentiate; \(\sigma\) is reserved for VOLATILITIES and VARIANCES and is never an elasticity.** <!-- notation-map -->

**Definition 13 (CES trading-function family).** Every trading function in this document is a member of ONE two-parameter CES family — \(\chi_{X/M}\) the SHARE axis, \(\epsilon_{X/M}\) the SUBSTITUTION axis:

\[
	\begin{aligned}
		\varphi_{(\chi_{X/M},\,\epsilon_{X/M})}\,(Q_X,Q_M) \, \equiv \,
		\begin{cases}
			\big(\chi_{X/M}\,Q_X^{\epsilon_{X/M}} + (1-\chi_{X/M})\,Q_M^{\epsilon_{X/M}}\big)^{1/\epsilon_{X/M}}, & \epsilon_{X/M} \neq 0 \\[4pt]
			Q_X^{\chi_{X/M}}\,Q_M^{1-\chi_{X/M}}, & \epsilon_{X/M} = 0
		\end{cases}
		\qquad \chi_{X/M} \in (0,1)
	\end{aligned}
\]

\(\epsilon_{X/M} = 0\) is a DEFINED CASE, not an evaluation — \(1/\epsilon_{X/M}\) is undefined there, so the Cobb–Douglas branch is supplied by definition and CONTINUITY at \(\epsilon_{X/M} = 0\) is a **theorem** (`phiCES_tendsto_phiEps`), not a substitution. Every display in this document sits on the \(\epsilon_{X/M} = 0\) slice and is subscripted accordingly; Definition 12 is the \(\epsilon_{X/M} = 0\) member evaluated on the per-strike virtual reserves. **ORIENTATION (PR-ORIENT, OPEN):** this display carries \(\chi_{X/M}\) on the \(Q_X\) leg — the **opposite** of Definition 12's \(\Delta Q_M\)-leg placement; the FLAG applies to the *pair* and one of the two must eventually change.

*Formalized:* `PhiCES.phiCES` (12/12 axiom-clean): `phiCES_tendsto_phiEps`; `phiCES_one` (\(\epsilon_{X/M} = 1\) linear); `phiCES_zero_half_eq_geom`; `phiCES_homogeneous`/`_pos`/`_mono`. *Narrowed, declared:* `phiCES_concave` is RADIAL concavity only — joint concavity in \((Q_X,Q_M)\) is OPEN.

**Definition 14 (Curvature).** The **curvature** \(\kappa_{\varphi}\) of a trading function is the price-impact elasticity of its marginal price along the trading curve, normalized against the constant-product member: with the **marginal price** minted as its own object — \(p_{\varphi} \equiv \partial_{Q_X}\varphi \,/\, \partial_{Q_M}\varphi\), the quotient of partials of the trading function (bare \(p\) is not used; the subscript \(p\) in \(\epsilon_{p/X}\) names this object; Lean `CurvatureTwo.margPrice`, subject to the PR-ORIENT argument-order FLAG) — and

\[
	\begin{aligned}
		\epsilon_{p/X} \, \equiv \, \frac{d \ln p_{\varphi}}{d \ln Q_X}\Big|_{\varphi = \text{const}}, \qquad
		\kappa_{\varphi} \, \equiv \, \frac{|\epsilon_{p/X}|}{|\epsilon_{p/X}| + |\epsilon_{p/X}^{\,0}|}
	\end{aligned}
\]

where \(\epsilon_{p/X}^{\,0}\) is the same elasticity for the \(\epsilon_{X/M} = 0\) (constant-product) member at the same point. \(\epsilon_{p/X}\) is an **observable** of any member of the trading-function class (Definition 12), not a parameter: the second derivative of \(\varphi\) enters through it (the derivative of the marginal price), and the benchmark normalization makes \(\kappa_{\varphi}\) scale-free, with the constant-product pool at \(\kappa_{\varphi} = 1/2\). Notation binding: \(\kappa_{\varphi}\) names the **genuine** curvature (\(\varphi\) the quote function, never the fee \(\phi\)); the share-asymmetry index \(\varsigma_{X/M}\) is NOT a curvature. <!-- notation-map -->

*Formalized:* the definitional layer is now carried AT THE BALANCED POINT — `PayoffGeometry.epsPX` (the elasticity as a genuine along-curve derivative) and `kappaPhi` (this definition's benchmark normalization), with Theorem 31 proving the closed form FROM them; `CurvatureTwo.curvTwo`'s by-fiat status is resolved by agreement with `kappaPhi_closed_form`. The GENERAL-point elasticity remains an observable without a dedicated carrier.

*(The grid–marginal-price relation is Theorem 40, stated with the portfolio-value machinery in # CONTROL_OPERATORS.)*

**Theorem 31 (CES curvature closed form) *(promoted from Proposition 7 — the number 7 is retired, not reused)*.** For the CES family (Definition 13), at the balanced point \(|\epsilon_{p/X}| = \dfrac{1-\epsilon_{X/M}}{1-\chi_{X/M}}\), and

\[
	\begin{aligned}
		\kappa_{\varphi}(\epsilon_{X/M}) \, = \, \frac{1 - \epsilon_{X/M}}{2 - \epsilon_{X/M}} \, \in \, [0,1), \qquad
		\epsilon_{X/M}(\kappa_{\varphi}) \, = \, \frac{1 - 2\kappa_{\varphi}}{1 - \kappa_{\varphi}}
	\end{aligned}
\]

— the \(\chi_{X/M}\)-dependence cancels identically: \(\kappa_{\varphi}\) is a function of the SUBSTITUTION axis alone (equivalently \(\kappa_{\varphi} = 1/(1+\bar\epsilon_{X/M})\)). The inverse is the DESIGN DIAL — choose a target curvature, read off the substitution exponent. *Formalized* (`PayoffGeometry`, project `68d1b02a`, axiom-clean): (i) the elasticity at the balanced point `epsPX_balanced` (with `balanced_state_exists` guarding non-vacuity); (ii) the normalization identity `kappaPhi_closed_form` — the share cancels against the substitution-0 benchmark, CPMM at \(1/2\). Both TRUE as stated; the refute-and-correct clause went unused.

**Theorem 8 (Properties of the closed form).** The closed form is zero exactly at the linear member (\(\epsilon_{X/M} = 1\)), strictly positive below it, strictly decreasing in \(\epsilon_{X/M}\), with range \([0,1)\); \(\chi_{X/M}\) and \(\Delta_i\) do NOT enter it; both round trips with the inverse hold.

*Formalized:* `CurvatureTwo.curvTwo`; `curvTwo_linear_zero`; `curvTwo_pos_of_lt_one`; `curvTwo_strictAnti_rho`; `curvTwo_mem_Ico`; `rhoOfCurv` (both round trips); \(\bar\epsilon_{X/M}\) = `subElast` (`subElast_zero`, `subElast_tendsto_one`).

**Refutation note (what curvature is NOT).** The Gaussian curvature of \(\varphi\)'s graph is **identically zero** for every member — 1-homogeneity forces \(\mathrm{Hess}\,\varphi \cdot (Q_X,Q_M)^{\top} = 0\), so \(\det \mathrm{Hess} \equiv 0\) and the graph is a ruled surface; the Gaussian reading cannot distinguish linear from Leontief. The un-normalized planar curvature of the trading curve is scale-dependent (\((1-\epsilon_{X/M})/(\sqrt{2}\,t)\) at the symmetric point \(Q_X = Q_M = t\), \(\chi_{X/M} = 1/2\)) and cannot equal a constant. The normalization of Definition 14 is what makes Theorem 31 well-posed. *Formalized* (`GammaGrid`, project `589d44ac`, axiom-clean): `hessian_det_zero` — closed-form CES second derivatives, \(f_{xx}f_{yy} = f_{xy}^2\) identically.

**Definition 15 (Share asymmetry).** The **share asymmetry** (grid tilt) of the trading-function family is

\[
	\begin{aligned}
		\varsigma_{X/M} \, \equiv \, 1 - \Big(\frac{1-\chi_{X/M}}{\chi_{X/M}}\Big)^{\Delta_i}
	\end{aligned}
\]

zero exactly at \(\chi_{X/M} = 1/2\). It is a **derived observable** — a function of the registered parameters \(\chi_{X/M} \in \Theta_{\varphi}\) and \(\Delta_i \in \Theta_p\), adding no degree of freedom; hence no registry entry.

*Formalized:* `EtaTilde.curvOfTilde` / `EtaCurvature.curvIndex`. *(Lean names predate the doc symbols and are NOT renamed — standing doc-glyph/Lean-name split.)* <!-- notation-map -->

**Theorem 9 — REMOVED (user ruling 2026-08-11).** The number is retired, not reused. Its content — \(\varsigma_{X/M}\) measures SHARE asymmetry, not curvature — survives as the notation binding at Definition 14 and the machine carrier `curvOfTilde_not_curvature`; E1–E7 remain SHARE statements.

**Rule 5 (Current trading curve).** The protocol pins the balanced Cobb–Douglas member:

\[
	\begin{aligned}
		\chi_{X/M} \, \leftarrow \, \tfrac{1}{2}, \quad \epsilon_{X/M} \, \leftarrow \, 0: \qquad
		\varphi_{(1/2,\,0)} \, (i_K ; \Delta Q , L)\, = \, (\Delta Q_M^{L} (i_K) + \Delta Q_M)^{1/2}\cdot(\Delta Q_X^L \, (i_K) \, + \, \Delta Q_X)^{1/2}
	\end{aligned}
\]

The leg reading — \(\chi_{X/M}\) as the \(\Delta Q_M\)-leg exponent (the \(1/p_{(\eta,\Delta_i)}\) leg), that leg's share of pool value — is Definition 12's orientation. At \(\chi_{X/M} = 1/2\) the two orientations of the OPEN FLAG coincide, so the current case is orientation-blind — which is why the Definition 12 / Definition 13 contradiction stayed invisible in practice.

*Formalized:* `phiCES_zero_half_eq_geom` (the \((\epsilon_{X/M} \to 0,\ \chi_{X/M} = 1/2)\) member is the geometric mean).

**Theorem 10 (The bridge \(\chi_{X/M} \leftrightarrow \eta \leftrightarrow \varsigma_{X/M}\)).** The weight ratio IS the per-TICK square-root-price step — so \(\chi_{X/M}\) is an OBSERVABLE of the grid already defined, not a new primitive:

\[
	\begin{aligned}
		\frac{\chi_{X/M}}{1-\chi_{X/M}} \, = \, \frac{p_{(\eta, \Delta_i)}(i+1)}{p_{(\eta, \Delta_i)}(i)} \, = \, \lambda^{\eta\,\Delta_i/2}
	\end{aligned}
\]

Both directions, both round trips; and the share asymmetry (Definition 15) factors through the share, the per-SPACING step being the per-TICK step raised to \(\Delta_i\) — with \(\Lambda\) the logistic, \(\Lambda(z) = 1/(1+e^{-z})\) (the same \(\Lambda\) the fee schedule uses below):

\[
	\begin{aligned}
		\chi_{X/M}(\eta) \, &= \, \Lambda\Big(\frac{\eta\,\Delta_i\,\ln\lambda}{2}\Big) \, \in \, (0,1) \;\; \forall\,\eta, \qquad
		\eta(\chi_{X/M}) \, = \, \frac{2}{\Delta_i\,\ln\lambda}\,\ln\frac{\chi_{X/M}}{1-\chi_{X/M}} \\[4pt]
		\varsigma_{X/M}(\eta,\Delta_i) \, &= \, 1 - \Big(\frac{1-\chi_{X/M}}{\chi_{X/M}}\Big)^{\Delta_i}, \qquad
		\chi_{X/M}(\varsigma_{X/M}) \, = \, \frac{1}{1 + (1-\varsigma_{X/M})^{1/\Delta_i}}
	\end{aligned}
\]

*Formalized* (`EtaTilde`, 23/23 axiom-clean; doc \(\chi_{X/M}\) ↔ Lean `etaTilde`): anchor `etaTilde_ratio`; observable `etaTilde_eq_priceEta_step`; bijection `etaTilde_mem_Ioo`, `etaTilde_strictMono`, `etaOfTilde_etaTilde`, `etaTilde_etaOfTilde`, `etaTilde_half_iff`, `etaTilde_tendsto_atTop`/`_atBot`; bridge to \(\varsigma_{X/M}\): `curvIndex_eq_of_etaTilde`, `curvOfTilde_etaTilde`, `tildeOfCurv_curvOfTilde`; range `curvOfTilde_mem_Ioo` (the \(t \in (0,1)\) hypothesis is NECESSARY — `Real.rpow` is \(\log|x|\)-based outside it).

**Theorem 11 (Domain coincidence).** Three conditions stated independently, in different blocks, are one:

\[
	\begin{aligned}
		0 \, < \, \eta\,\Delta_i \quad &\Longleftrightarrow \quad \chi_{X/M} \, > \, \tfrac{1}{2} \quad \Longleftrightarrow \quad \varsigma_{X/M} \, \in \, (0,1) \\
		\eta \, = \, 0 \quad &\Longleftrightarrow \quad \chi_{X/M} \, = \, \tfrac{1}{2} \quad \Longleftrightarrow \quad \varsigma_{X/M} \, = \, 0
	\end{aligned}
\]

The first line is exactly the hypothesis Theorem 5's `deltaQM_nonneg` requires — an analytic guard that IS the economic condition "the pool is asset-heavy in value"; the second says flat grid = symmetric pool = zero tilt.

*Formalized:* `admissible_iff`; `zero_curv_iff`.

**Theorem 12 (Share-asymmetry monotonicity; the antitone reading is REFUTED).** \(\varsigma_{X/M}\) is strictly INCREASING in \(\chi_{X/M}\) on \((0,1)\), vanishing exactly at \(\chi_{X/M} = \tfrac12\). The opposite reading — a larger asset share means LESS tilt — is FALSE:

\[
	\begin{aligned}
		\Delta_i = 1: \qquad \chi_{X/M} = \tfrac14 \, < \, \tfrac34 \quad \text{but} \quad \varsigma_{X/M}\big(\tfrac14\big) \, < \, \varsigma_{X/M}\big(\tfrac34\big)
	\end{aligned}
\]

(raising \(\chi_{X/M}\) shrinks \((1-\chi_{X/M})/\chi_{X/M}\), hence RAISES \(1 - (\cdot)^{\Delta_i}\).)

*Formalized:* `curvOfTilde_strictMono` (the true direction); **REFUTED:** `not_curvOfTilde_strictAnti` — machine-checked negation of the antitone reading, witness above. *(Retitled from the in-doc "Lemma (Curvature–Share Monotonicity)": "Lemma" is not a taxonomy class, and \(\varsigma_{X/M}\) is share asymmetry, not curvature (carrier `curvOfTilde_not_curvature`; formerly Theorem 9, removed).)*

CONSEQUENCE FOR E8(6): the factor-share reading was recorded UNAVAILABLE because \(\eta^{\star} \approx 458/\Delta_i^{2}\) cannot be a Cobb–Douglas share. It never had to be — the share is \(\chi_{X/M}(\eta^{\star}) \in (0,1)\) for EVERY \(\eta\) (Theorem 10), so the identification is reachable through \(\chi_{X/M}\), not through \(\eta\) directly. *Carriers:* `etaStar_tilde_mem_Ioo`, `curvIndex_etaStar_via_tilde`. *(E-block cross-note; converts when the E-blocks are swept.)*

 > Provenance: `EtaTilde` 23/23 axiom-clean, project `67b1c841` (doc \(\chi_{X/M}\) ↔ Lean `etaTilde`, the Lean name fixed by the bundle and never hand-edited); `PhiCES` 12/12 axiom-clean, project `cd3558f7`. Carriers not yet attached to a numbered statement: `phiCES_agreement_point` (evaluation form, scope declared in-file); CONDITIONAL, NOT an identification: `phiCES_rho_vs_pi_eta_trader` gives \(1/(1-\epsilon_{X/M}) = 1/(1-\eta) \iff \epsilon_{X/M} = \eta\) away from the poles for `exp/CESLongVolPayoff`'s η, and its docstring states outright that this does NOT identify the payoff parameter with the trading-function parameter — E8(6) untouched.

**Definition 32 (Intrinsic liquidity).** For \(\varphi_{(\chi_{X/M},\,\epsilon_{X/M})}\), the **intrinsic liquidity** at a reserve state is

\[
	\begin{aligned}
		\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}(Q_X^{L},Q_M^{L}) \, &\equiv \, \frac{-2\,\big(\partial_{Q_X}\varphi\;\partial_{Q_M}\varphi\big)^{3/2}}{\partial^2_{Q_M}\varphi\,(\partial_{Q_X}\varphi)^2 \, - \, 2\,\partial^2_{Q_XQ_M}\varphi\,\partial_{Q_X}\varphi\,\partial_{Q_M}\varphi \, + \, \partial^2_{Q_X}\varphi\,(\partial_{Q_M}\varphi)^2} \, = \, \frac{-2\,p_{\varphi}^{3/2}}{\frac{\partial p_{\varphi}}{\partial Q_X^{L}}}
	\end{aligned}
\]

([INTRINSIC_LIQ](../refs/cfmm/risk_tung_wang-pricing_hedging_liquidity_provision-2026.pdf) §2.1; construction from [CLMM_DYN](../refs/cfmm/tung_wang-clmm_dynamics_continuous_time-2024.pdf) App. B), with \(p_{\varphi}\) the marginal price of Definition 14. ARGUMENTS ARE RESERVES: the \(L\)-superscripted quantities of Definition 10 (Definition 25's split — bare \(Q_X, Q_M\) are Definition 13's trading-side arguments); the partials inside the display remain with respect to Definition 13's arguments, EVALUATED at the reserve state. It carries the dimension of \(\bar L_{(1/2,\,0)}\) for EVERY \((\chi_{X/M},\epsilon_{X/M})\) — the level of \(\varphi_{(\chi_{X/M},\epsilon_{X/M})}\) does not, carrying \((Q_X^{L})^{\chi_{X/M}}(Q_M^{L})^{1-\chi_{X/M}}\) — and it is invariant under reparametrization of the curve. \(\bar L_{(1/2,\,0)}\) is the object this document writes throughout: it is the intrinsic liquidity AT THE MEMBER RULE 5 PINS. The bar is exact only there — constancy along the curve holds iff \(\epsilon_{X/M} = 0\) (Theorem 29); in general this is a state function, not a level.

**Theorem 29 (Closed form; limits; the state-constancy boundary).** On the interior of the level set,

\[
	\begin{aligned}
		\bar L_{(\chi_{X/M},\,\epsilon_{X/M})} \, &= \, \frac{2\sqrt{\chi_{X/M}(1-\chi_{X/M})}\;\big(Q_X^{L}\,Q_M^{L}\big)^{(\epsilon_{X/M}+1)/2}}{(1-\epsilon_{X/M})\big(\chi_{X/M}\,(Q_X^{L})^{\epsilon_{X/M}} \, + \, (1-\chi_{X/M})\,(Q_M^{L})^{\epsilon_{X/M}}\big)} \\
		\epsilon_{X/M} \to 0 \; &\implies \; \bar L_{(\chi_{X/M},\,0)} \, = \, 2\sqrt{\chi_{X/M}(1-\chi_{X/M})}\;\bar L_{(1/2,\,0)} \\
		\epsilon_{X/M} \to 1^{-} \; &\implies \; \bar L_{(\chi_{X/M},\,\epsilon_{X/M})} \, \to \, \infty \qquad \text{(the linear member has no price impact)} \\
		\bar L_{(\chi_{X/M},\,\epsilon_{X/M})} \big/ \bar L_{(1/2,\,0)} \; \text{state-constant} \; &\iff \; \epsilon_{X/M} \, = \, 0
	\end{aligned}
\]

and \(\bar L_{(\chi_{X/M},\epsilon_{X/M})}\) is positively homogeneous of degree one in \((Q_X^{L},Q_M^{L})\).

*Formalized* (`EllIntrinsic`, 10/10 axiom-clean, project `9786b137`; doc \(\bar L_{(\chi,\epsilon)}\) ↔ Lean `ell`, doc \(\chi_{X/M}\) ↔ Lean `ε`, doc \(\epsilon_{X/M}\) ↔ Lean `ρ` — the Lean names predate the doc glyphs and are NOT renamed): closed form `ellAt_eq_ell_corrected`; limits `ell_tendsto_geom`, `ell_tendsto_cpmm`, `ell_tendsto_atTop_rho_one`; `ell_homogeneous`; state-constancy `ell_ratio_const_iff`. **REFUTED as first stated:** `ellAt_eq_ell_false` — the guard \(0 < Q_M\) does NOT place the state inside the level set (`Real.rpow` off the positives carries a \(\cos(\pi\cdot)\) factor, so a NEGATIVE radicand can still yield a positive leg); at the witness the two sides carry opposite signs. The interior guard below is that correction, not a hedge.

**Theorem 30 (Half-kernel reduction).** Strictly inside the level set, the \(\chi_{X/M} = 1/2\) member carrying \(\bar L_{(1/2,\,0)} \leftarrow \bar L_{(\chi_{X/M},\,\epsilon_{X/M})}\) reproduces BOTH the marginal price and its first-order price impact, the latter being exactly \(-2\,p_{\varphi}^{3/2}\big/\bar L_{(1/2,\,0)}\). Every quantity factoring through \((p_{\varphi}, \frac{\partial p_{\varphi}}{\partial Q_X^{L}})\) — \(\frac{\partial \pi}{\partial p}\), \(\Gamma_{\varphi}\), \(\pi^{\mathrm{LVR}}\), the per-strike amounts of Definitions 9–11 — is therefore computable on the half-kernel, which is what on-chain venues instantiate. **Scope, stated not buried:** the match is LOCAL and SECOND-ORDER — it pins \(\Gamma_{\varphi}\), NOT \(\frac{\partial^2 p_{\varphi}}{\partial (Q_X^{L})^2}\); and a local match is not a global match of Definition 25's value function, which is obtained by integration.

*Formalized:* `halfKernel_price_impact` (the impact law, proved as stated); `halfKernel_osculates_corrected`. **REFUTED as first stated:** `halfKernel_osculates_false` — same defective guard as Theorem 29; at the witness the prices agree while the impacts carry opposite signs.

**Proposition 12 (Profile–field relation) — SETTLED (split verdict).** The ladder carries the per-strike liquidity \(L_{(1/2,\,0)}(i_K) = \bar L_{(1/2,\,0)}\,\ell(\xi,\iota;i_K)\) (Definition 7); the smooth member carries the field \(\bar L_{(\chi_{X/M},\epsilon_{X/M})}\). Whether a given \(\varphi_{(\chi_{X/M},\epsilon_{X/M})}\) admits \((\xi,\iota) \in \Theta_{\ell}\) with \(\bar L_{(1/2,\,0)}\,\ell(\xi,\iota;i_K) = \bar L_{(\chi_{X/M},\epsilon_{X/M})}\) at every strike is now ANSWERED: **the map exists iff \(\epsilon_{X/M} = 0\)** — a geometric ladder is the discretization of a pure power of the reserve ratio, and the normalized field is a pure power iff \(\epsilon_{X/M} = 0\) (`fieldRatio_isPower_iff`: constancy of the mixed comparison forces \(\chi_{X/M}(1-\chi_{X/M})(t^{\epsilon_{X/M}}-1)^2 = 0\)). At \(\epsilon_{X/M} = 0\) the field is state-constant (Theorem 29) and any \((\xi,\iota)\) realization is available; OFF the slice NO geometric ladder reproduces the field — the G4 ladder deficit \(\iota - 2\) is confirmed FROM GEOMETRY, and the parametrized density is the machine-warranted repair (Phase 15.2). *Retained as a Proposition:* the ladder⟺power-law identification is a modelling step; the power-law iff is the machine-proved part.


**Definition 37 (The level).** \(c \, \equiv \, \varphi_{(\chi_{X/M},\,\epsilon_{X/M})}(Q_X^L, Q_M^L)\) — the value of the trading function at the reserves. ENDOGENOUS state: set by liquidity events, INVARIANT under trading (Theorem 33's on-curve identity); frozen during any trade, hence it sits AFTER the semicolon in price-coordinate signatures — the same slot as \(L\) in \(\varphi(i_K;\Delta Q, L;t)\). Dimension \((Q_X^{L})^{\chi_{X/M}}(Q_M^{L})^{1-\chi_{X/M}}\) (Definition 32's disparity). At the pinned member the level and the intrinsic liquidity COINCIDE — \(c_{(1/2,\,0)} = \bar L_{(1/2,\,0)}\) — a coincidence, not an identity, and the reason this document never needed \(c\) before the general member entered.

**Theorem 33 (Canonical parametrization — the transition channel).** Strictly inside the level set, with \((Q_X^L(p_{\varphi}), Q_M^L(p_{\varphi}))\) Definition 25's price-indexed reserves ([INTRINSIC_LIQ](../refs/cfmm/risk_tung_wang-pricing_hedging_liquidity_provision-2026.pdf) §2.2; differential form only — the integral form's boundary conditions fail off \(\epsilon_{X/M} = 0\)):

\[
	\begin{aligned}
		\frac{\partial Q_X^L}{\partial p_{\varphi}} \, = \, \frac{-\,\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}}{2\,p_{\varphi}^{3/2}} \, = \, \Gamma_{\varphi}, \qquad
		\frac{\partial Q_M^L}{\partial p_{\varphi}} \, = \, \frac{\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}}{2\,\sqrt{p_{\varphi}}}, \qquad
		\frac{\partial Q_M^L}{\partial Q_X^L} \, = \, -\,p_{\varphi}, \qquad
		\varphi_{(\chi_{X/M},\,\epsilon_{X/M})}\big(Q_X^L, Q_M^L\big) \, = \, c
	\end{aligned}
\]

— the trading curve (reserve coordinates) and the pair (price, intrinsic liquidity) are the same data; the level set is the channel between them.

*Formalized* (`CanonicalParam`, 6/6 axiom-clean, project `4d696a77`): `canonical_x`, `canonical_y`, `tangent_slope`, `on_curve`.

**Definition 33 (Liquidity profile in price coordinates).**

\[
	\begin{aligned}
		L(p_{\varphi}) \, \equiv \, \frac{\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}}{2\,p_{\varphi}^{3/2}}
	\end{aligned}
\]

**Theorem 34 (Profile identities; the pushforward).**

\[
	\begin{aligned}
		L(p_{\varphi}) \, = \, -\,\frac{\partial Q_X^L}{\partial p_{\varphi}} \, = \, -\,\Gamma_{\varphi} \quad \text{(Theorem 32's object)}, \qquad
		\frac{\partial p_{\varphi}}{\partial Q_X^L} \, = \, -\,\frac{1}{L(p_{\varphi})} \quad \textbf{(the price-impact law)}
	\end{aligned}
\]
and the field factors through the pair (price; level) ALONE: \(\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}(Q_X^L, Q_M^L) = \bar L_{(\chi_{X/M},\,\epsilon_{X/M})}(p_{\varphi};\, c)\) in closed form — the coordinate change itself, the level in the post-semicolon slot per Definition 37 (supersedes the 2026-08-10 argument-tuple-abuse note).

*Formalized:* `profile_eq_neg_gamma`; `field_factors_through_price` — the hand-derived price-coordinate closed form (`ellP`) CONFIRMED under proof; the invited refutation of its exponent bookkeeping did not materialize.


**Definition 40 (Vol-market trading function).** On the vol market, with \(L_{\sigma}\) the vol-asset liquidity (\(\Theta_{\nu} \to L_{\nu} = \Delta Q_{\nu}(\sigma_K)\), user TODO 2026-08-11):

\[
	\begin{aligned}
		\varphi^{\sigma}\big(Q_X^{L_{\sigma}}, Q_M^{L_{\sigma}}\big) \, = \, Q_M^{L_{\sigma}} \, - \, \Big(L_{\sigma} - \tfrac{1}{2}\,Q_X^{L_{\sigma}}\Big)^{2}
	\end{aligned}
\]

**Theorem 36 (\(\varphi^{\sigma}\) is the constant-gamma curve; it is NOT a member).** Along the level set:

\[
	\begin{aligned}
		p_{\varphi^{\sigma}} \, = \, L_{\sigma} - \tfrac{1}{2}Q_X^{L_{\sigma}}, \qquad
		\frac{\partial p_{\varphi^{\sigma}}}{\partial Q_X^{L_{\sigma}}} \, = \, -\tfrac{1}{2}, \qquad
		\Gamma_{\varphi^{\sigma}} \, = \, -2, \qquad
		\bar L_{\varphi^{\sigma}} \, = \, 4\,p_{\varphi^{\sigma}}^{3/2}
	\end{aligned}
\]

and \(\varphi^{\sigma}\) is NOT a positive multiple of any member of Definition 13's family — the boxed \(\varphi^{\nu} \to \varphi_{(\chi_{X/M},\epsilon_{X/M})}\) question is ANSWERED NO (1-homogeneity forces \(L_{\sigma}^2 = 0\)); no degenerate identification survives. *Bridge (in flight, `2370c633`):* at \(\eta\,\Delta_i = 1/3\) the geometric ladder's per-strike gamma is CONSTANT — the grid+ladder emulates \(\varphi^{\sigma}\) on the existing primitive.

*Formalized* (`MarketMaking`, project `d1ad6474`, axiom-clean): `phiSigma_kit`; `phiSigma_not_CES` (via `phiCES_smul`).


# FEE_ALGEBRA

**Rule 6 (Per-leg fee split).** Each incoming trade leg is split by its **leg fee** \(\phi_M, \phi_X \in (0,1)\) (the M9 leg fees — fee *variables*, produced by the schedule below, not members of \(\Theta_{\phi}\)): the trading function is quoted on the net flow, and the fee fraction accrues to the per-strike reserves —

\[
	\begin{aligned}
		\Delta Q_M \, &= \, (1 - \phi_M) \, \Delta Q_M \, + \, \phi_M \, \Delta Q_M \\
	    \Delta Q_X \, &= \, (1 - \phi_X)\, \Delta Q_X \, + \, \phi_X \, \Delta Q_X
	\end{aligned}
\]

\[
	\begin{aligned}
		\Delta Q_M^{L} (i_K) \, &\leftarrow \, \Delta Q_M^{L} (i_K) \, + \, \phi_M \, \Delta Q_M \\
	    \Delta Q_X^{L} (i_K) \, &\leftarrow \, \Delta Q_X^{L} (i_K) \, + \, \phi_X \, \Delta Q_X
	\end{aligned}
\]

The first display is an identity (the decomposition); the Rule is the second — the **accrual assignment**: fees deposit into Definition 9's endowments at the strike where they are charged.

**Definition 17 (Fee composition).** The **fee-composition law** on the carrier \([0,1)\) is

\[
	\begin{aligned}
		\phi_M \otimes_{\phi} \phi_X \, \equiv \, 1 - (1-\phi_M)(1-\phi_X), \qquad \mathcal{G}_{\phi} \, \equiv \, \big([0,1],\, \otimes_{\phi},\, 0\big)
	\end{aligned}
\]

\(\mathcal{G}_{\phi}\) is an **Abelian monoid** — identity \(\phi = 0\), no inverses (a charged fee cannot be un-charged) — **not a group, and \(\otimes_{\phi}\) is a composition law, not an inner product** (correcting the note's original wording). The monoid axioms are machine-proved — Theorem 14 (`probOr_comm`, `probOr_assoc`, `probOr_zero`, closure `probOr_mem_Icc`). The carrier is \([0,1]\) as proved; the boundary \(\phi = 1\) (full confiscation) is admitted by the algebra and excluded economically by Rule 6's domain \(\phi_{\bullet} \in (0,1)\). **THE ALGEBRA'S READING (machine-settled):** \(1 - (\phi_M \otimes_{\phi} \phi_X) = (1-\phi_M)(1-\phi_X)\) — \(\otimes_{\phi}\) IS plain multiplication on RETAINED fractions (`otimes_is_retention_mul`); composition laws that fail on fee factors hold through the complement map (`ask_comp_otimes_corrected`, its uncorrected form REFUTED at witness \(1/4 \neq 3/4\)).

**Definition 39 (Bid and ask fee prices).** For the marginal price \(P_{\varphi}\) and fee \(\phi\):

\[
	\begin{aligned}
		P_{\varphi}^{(\mathrm{bid})} \, \equiv \, \frac{P_{\varphi}}{\phi}, \qquad
		P_{\varphi}^{(\mathrm{ask})} \, \equiv \, \phi\, P_{\varphi}
	\end{aligned}
\]

LABELS AS THE SOURCE ASSIGNS THEM (notation precedence; user TODO 2026-08-11). MACHINE FACT, recorded not repaired: on \(\phi \in (0,1)\) the labelled ask sits strictly BELOW the labelled bid (`bidask_labels_inverted`) — the economic buyer-pays price is \(P_{\varphi}/\phi\); a one-line ruling flips the labels.

**Theorem 35 (Fee-price identities).**

\[
	\begin{aligned}
		\frac{P_{\varphi}^{(\mathrm{ask})} - P_{\varphi}^{(\mathrm{bid})}}{P_{\varphi}} \, = \, \frac{(\phi-1)(\phi+1)}{\phi} \; < \, 0 \;\; \text{on } \phi \in (0,1), \qquad
		P_{\varphi}^{(\mathrm{ask})}\big|_{\phi_M} \circ P_{\varphi}^{(\mathrm{ask})}\big|_{\phi_X} \, = \, P_{\varphi}^{(\mathrm{ask})}\big|_{\phi_M \phi_X}
	\end{aligned}
\]

— ask-composition is MULTIPLICATIVE in the fee factor and NOT \(\otimes_{\phi}\)-compatible (refuted; witness \(\phi_M = \phi_X = 1/2\): \(1/4 \neq 3/4\)); the \(\otimes_{\phi}\)-composition law holds through the complement map (Definition 17's retention reading).

*Formalized* (`MarketMaking`, project `d1ad6474`, axiom-clean): `spread_identity`, `bidask_labels_inverted`, `ask_comp_mul`, `ask_comp_otimes_false`, `ask_comp_otimes_corrected`, `otimes_is_retention_mul`.


**Rule 7 (Trader-paid fee).** The protocol composes the leg fees into the trader-paid fee by the monoid law:

\[
	\begin{aligned}
		\phi \, \leftarrow \, \phi_M \otimes_{\phi} \phi_X
	\end{aligned}
\]

This is the [M9] **DECIDED** entry — enacted as **Rule 12**, with its algebra as **Theorem 20** (`TauMevAlgebra` carriers), inside the MEV subsection of # CONTROL_OPERATORS, where hazards are introduced.

**Design menu.** Row 1 is the **DECIDED** structure — Rules 6–7 enact it; the remaining rows are alternative composition structures considered and **not adopted** (candidate Rules never enacted):

| Economic process         | Operator                 | Structure            |
| ------------------------ | ------------------------ | -------------------- |
| Sequential fee charging  | (1-(1-\phi_M)(1-\phi_X)) | Abelian monoid       |
| Strongest policy wins    | (\max)                   | Join semilattice     |
| Cheapest route wins      | (\min)                   | Meet semilattice     |
| Liquidity aggregation    | Weighted average         | Convex algebra       |
| Feature flags            | OR                       | Monoid               |
| Permission intersection  | AND                      | Monoid               |
| Bit toggling             | XOR                      | Abelian group        |
| Cyclic governance states | Addition mod (N)         | Finite abelian group |

**Definition 18 (Dynamic fee schedule).** The fee *level* is produced by the volatility-and-utilization schedule — the sum-of-sigmoids dynamic fee of [ALGEBRA](../refs/algebra-tech-paper.pdf) (their eq. (4)–(5); \(\alpha\) scales, \(\gamma\) steepens, \(\beta\) centers), gated by utilization:

\[
	\begin{aligned}
\phi \, ( \sigma \, (i (t));t) \, &\equiv \bar \phi\, + \, \Big (\sum_j \, \frac{\alpha_j}{1 + \exp(\gamma_j \, (\beta_j - \sigma (i (t))))} \Big )\, \cdot \frac{\alpha_R}{1 \, + \, \exp(\gamma_R \, (\beta_R - \frac{\varphi_{(1/2,\,0)} \, (i_K ; \Delta Q , 0; t)}{\varphi_{(1/2,\,0)} \, (i_K ; 0, L; t)}))}
	\end{aligned}
\]

The gate's argument is the **utilization ratio** — the trading function evaluated on flow alone over its evaluation on the endowments alone (Theorem 1's \(u\) is the gate's value). The parameters \(\Theta_{\phi} = \{\gamma, \bar\phi, \beta, \alpha\}\) are Protocol Parameters (see **PROTOCOL_PARAMETERS (\(\Theta_{\phi}\))**); the R-suffixed trio \((\alpha_R, \beta_R, \gamma_R)\) enters as members of the \(\alpha/\beta/\gamma\) families. **Signature note:** the \(t\) argument extends Definition 12's \((i_K; \Delta Q, L)\) signature — the time dependence enters through the flow and endowments at \(t\); flagged, not silently repaired.
**Definition 36 (Utilization).** \(\nu(i_K;\Delta Q, L; t) \, \equiv \, \dfrac{\varphi_{(1/2,\,0)}(i_K;\Delta Q,0;t)}{\varphi_{(1/2,\,0)}(i_K;0,L;t)}\) — the trading function evaluated on the flow alone over its evaluation on the endowments alone. The FLAIR discretization's \(\nu_t\) is this object at \(t\).

**Theorem 1 (Fee Envelope).** Writing \(u = \alpha_R\,\Lambda\big(\gamma_R(\nu - \beta_R)\big)\) — Definition 36's utilization through Definition 18's gate:
\[
	\begin{aligned}
		0 \leq u \leq \alpha_R, \qquad
		\bar\phi \, \leq \, \phi(\sigma) \, \leq \, \bar\phi + \Big(\sum_j \alpha_j\Big)u, \qquad
		\sigma \mapsto \phi(\sigma) \; \text{monotone} \; (\gamma_j > 0, \alpha_j \geq 0, u \geq 0)
	\end{aligned}
\]

The single-term case is the sigmoid fee schedule with steepness \(s_f = 1/\gamma_0\), where \(\Lambda\) is the logistic \(\Lambda(z) = 1/(1+e^{-z})\):
\[
	\begin{aligned}
		\bar\phi + \alpha_0\,\Lambda(\gamma_0(\sigma-\beta_0)) \, = \, f\big(\sigma;\, f_{\min}=\bar\phi,\, f_{\max}=\bar\phi+\alpha_0,\, \bar\sigma_f=\beta_0,\, s_f=\gamma_0^{-1}\big)
	\end{aligned}
\]

> `VolInstrument.sigmoidR_mem`, `multiFee_bounds`, `multiFee_monotone`, `multiFee_single_bridge`.

ECONOMIC CONTENT OF THEOREM 1. The floor \(\bar\phi\) is unconditional — LPs take a base fee at every volatility, so the schedule never degenerates to free execution. The ceiling is NOT a constant: it is \(\bar\phi + (\sum_j\alpha_j)\,u\), GATED by the utilization factor \(u \in [0,\alpha_R]\), so a pool nobody is trading against cannot levy the volatility surcharge at all — at \(u = 0\) the band collapses to the floor, and the surcharge is earned only where flow exists to earn it on. Monotonicity in \(\sigma\) is what makes the schedule a genuine VOLATILITY SURCHARGE rather than an arbitrary function of state: higher realized volatility always costs the trader weakly more. That is the property the FLAIR identification consumes — \(\Theta_{\lambda_{\text{FLAIR}}} = \{\bar\phi, \alpha, u\}\) is a LEVEL block precisely because the band's two edges are the level parameters, while \((\beta_j,\gamma_j)\) only place the transition inside the band (G3).

**Rule 2 (Streamia).** Assign the per-time-step payoff variation to the trading fee — the *streamia* of the [Panoptic whitepaper](https://arxiv.org/pdf/2204.14232):

\[
	\begin{aligned}
		\phi \, ( \sigma \, (i (t));t) \, & \overset{\text{streamia}}{\longleftarrow} \, \theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , p_{(\eta, \Delta_i)} \, (i_K),  \sigma \, (i (t)) \Big )
	\end{aligned}
\]

\(\overset{\text{streamia}}{\longleftarrow}\) denotes this Rule throughout.

**Definition 3 (Streaming premium).** The **streaming premium** over \(N\) steps of length \(\Delta t\) is the accumulated streamia \(\sum_{j<N}\theta_j\,\Delta t\) — the seller's fee income under Rule 2. It replicates the option's time decay, which is exactly why the perpetual instrument needs no expiry: the decay that a dated option pays out at \(T\) is instead streamed continuously.

*Formalized:* `Panoptic.streamingPremium`; `streamingPremium_succ` (\(\Sigma_{N+1} = \Sigma_N + \theta_N\Delta t\)).

# PROTOCOL_INPUTS

Every **Protocol Input** is a quantity supplied by the USER, per order, at interaction time — the third registry class. The classifying test across the three registries is *who sets it, and when*: a Protocol Constant (\(\mathcal{C}_p\)) is fixed by the design once and forever; a Protocol Parameter (\(\Theta_{\bullet}\)) is set by the protocol, uniformly for all users; a Protocol Input is chosen by the user for each interaction. Input entries carry a *Carrier* line — inputs are calldata, and the on-chain field is part of their definition. The input set of the **vol order** (retiring the former \(\Theta_{\text{ord}}\) symbol: inputs are not parameters, so the index letter changes):

\[
	\mathcal{I}_{\text{ord}} \,=\, \{\sigma^2_K,\, \#_{\sigma},\, s_{\upsilon}\}
\]

(strike, width, skew) pins only the scale-free leg shape \(\ell\,(\xi, \iota; i_K)\).

**Rule 8 (Target-vega completion — DECIDED, 2026-07-30).** The order is completed with the target vega:

\[
	\mathcal{I}_{\text{ord}} \,\leftarrow\, \mathcal{I}_{\text{ord}} \,\cup\, \{\Delta Q_v^{\star}\}
\]

**Protocol Input (\(\mathcal{I}_{\text{ord}} = \{\sigma^2_K, \#_{\sigma}, s_{\upsilon}, \Delta Q_v^{\star}\}\) — the vol order).**

- \(\sigma^2_K\) — the **strike variance**.
  *Domain:* a variance level (Convention 2: \(\sigma^2(i_K) \equiv \sigma^2_K\)); on-chain packing per `VolOrderValidationLib`.
  *Purpose:* the strike of the volatility option (Definition 1).
  *Economic meaning:* the variance level above which the option pays.
  *Carrier:* `create_order(strike, …)`.

- \(\#_{\sigma}\) — the **width** (symbol per user ruling 2026-08-04; formerly \(w\), retired — the [AMM_AXIOMS](../refs/cfmm/bichuch_feinstein-axioms_for_amms-2022.pdf) \(w\)-collision noted at Definition 12 is thereby MOOT). <!-- notation-map -->
  *Domain:* the packed order field (validation predicate in `VolOrderValidationLib`).
  *Purpose:* with \(s_{\upsilon}\), pins the scale-free leg shape \(\ell(\xi,\iota;i_K)\).
  *Economic meaning:* the strike-band width of the replication ladder.
  *Carrier:* `create_order(…, width, …)`.

- \(s_{\upsilon}\) — the **skew** (symbol per user ruling 2026-08-04; formerly bare \(s\), retired — it collided with the fee-schedule steepness \(s_f\)). <!-- notation-map -->
  *Domain:* the packed order field (validation predicate in `VolOrderValidationLib`).
  *Purpose:* with \(\#_{\sigma}\), pins the leg shape.
  *Economic meaning:* the asymmetry of the ladder around the strike.
  *Carrier:* `create_order(…, skew, …)`.

- \(\Delta Q_v^{\star}\) — the **target vega** (enters by Rule 8).
  *Domain:* `u96`, RAW LIQUIDITY units — \(\Delta Q_v^{\star}\) carries the dimension of the replication carrier \(L\) (the DECIDED dimension ruling below).
  *Purpose:* sizes the ladder and induces the implied maturity (Theorem 13, # PAYOFF).
  *Economic meaning:* the vega notional the user targets — the one sizing decision the order stores.
  *Carrier:* `targetVega : u96` at bits 152..247 of the packed `VolOrder` word (plank `feat/plank`); `targetVega` \(= \Delta Q_v^{\star}\) exactly; emitted by `VolOrderCreated(orderId, strike, width, skew, targetVega)`; fits-packed predicate in `VolOrderValidationLib`.

> *(AMENDED pointer 2026-08-11: Rule 4's ledger is now the MEASURE form — the Dirac pair at the fee prices — and the dimension statement below reads against it; the indicator form it cites survives only inside the proved ramp-band layer, Theorem 37.)*
**Convention 3 (Vega dimension — stored target vs lens readout; DECIDED 2026-07-30).** \(\Delta Q_v^{\star}\) carries the dimension of the REPLICATION CARRIER — liquidity \(L\), the quantity of the priced vol asset, per Rule 4's ledger

\[
	\pi^{\sigma} \, = \sum_{i_K} \, L_{(1/2,\,0)}(i_K) \, \mathbb{I}_{\text{long|short}}
\]

The quotient \(\Delta Q_v \equiv \Delta\pi^{\sigma}/\Delta(\sigma^2-\sigma^2_K)^{+}\) (collateral per vol unit, Definition 1) is the LENS READOUT — computed from a position through the \(Q_M^L\) range conversion (Definition 10), never stored. One instrument, two views: the \(\mathcal{I}_{\text{ord}}\) entry names the **stored quantity**, Definition 1's quotient names the **measured sensitivity**.

**Rule 9 (Sizing — quantity-exact, no price in the map).** The mint sizes the ladder from the target vega alone:

\[
	L_{(1/2,\,0)}(i_K) \,\leftarrow\, \Delta Q_v^{\star}\,\ell\,(\xi^{\star}, \iota; i_K), \qquad \sum_{i_K} L_{(1/2,\,0)}(i_K) \,=\, \Delta Q_v^{\star} \;\; \big(\textstyle\sum_{i_K}\ell = 1,\ \text{Theorem 2}\big)
\]

\(p_{\text{vol}}, p_{\text{risk}}\) enter at the ISSUANCE/ADMISSIBILITY layer (shares, deleverage — Rule 10), never the sizing map; the mint's collateral requirement is the actual replication cost, slippage-bounded.

**Proposition 8 (The lens obligation).** Delivered quantity recovers the stored target, one-sided under per-leg floor rounding:

\[
	\sum_{i_K} L_{(1/2,\,0)}(i_K) \,\leq\, \Delta Q_v^{\star}
\]

*Status:* **OPEN in-tree** — the per-leg floor rounding of Rule 9's map has no Lean carrier (the induced-ladder floor-maximal construction is plank-side). The *adjacent* rounding conservativity that IS proved is the funded-cap side of Rule 10: `dQvFunded_roundDown`, `roundDown_preserves_invariant` — related, not carriers of this statement.

**Rule 10 (Collateral channel and auto-deleverage; DECIDED 2026-07-30).** The contract holds \(\Delta Q_v^{\star}\) fixed, so all adaptation lands on collateral. The live backing requirement, and the (division-free) admissibility condition:

\[
	\Delta M_{\text{req}}(t) \,\leftarrow\, \Delta Q_v^{\star}\cdot p_{\text{vol}}(\bar\sigma; t), \qquad \Delta Q_v \cdot p_{\text{risk}}(t) \,\leq\, Q_M
\]

On violation the position is NOT hard-liquidated: the enforced exposure contracts to the funded level,

\[
	\Delta Q_v(t) \,\leftarrow\, \min\Big(\Delta Q_v^{\star},\; \frac{Q_M(t)}{p_{\text{risk}}(t)}\Big) \quad \text{(floor)}, \qquad T^{\star}(t) \,\leftarrow\, 2\,\frac{\Delta Q_v(t)}{N_\sigma}
\]

so the implied maturity CONTRACTS continuously with the funded exposure instead of truncating; a top-up restores both. Liquidation is the degenerate case \(Q_M \to 0\), where the realized life \([t_{\text{mint}}, t_{\text{liq}}]\) is the maturity the position actually had. **FLAG (define-before-use, OPEN):** \(p_{\text{vol}}\), \(p_{\text{risk}}\), and the reference volatility \(\bar\sigma\) are consumed here but not yet defined in the converted region — they are plank-side price feeds (the `priceOfRisk` entry point); their formal definitions are owed before this Rule's symbols close.

*Formalized* (`EndogenousMaturity.lean` — the floor is the GREATEST admissible exposure):

\[
	\begin{aligned}
		\forall x,\; 0 \leq x \leq \Delta Q_v^{\star} \wedge x\, p_{\text{risk}} \leq Q_M \implies x \leq \Delta Q_v(t), \qquad \Delta Q_v(t)\, p_{\text{risk}} \leq Q_M \;\;\text{(on violation)}
	\end{aligned}
\]

`dQvFunded_maximal`; `dQvFunded_admissible(_iff_mul)`, `_mul_le_of_violation`, `_eq_of_no_violation`; \(T^{\star}(t) \uparrow Q_M,\, \downarrow p_{\text{risk}}\): `tStarFunded_mono_QM`, `_antitone_prisk`; \(Q_M \geq \Delta Q_v^{\star} p_{\text{risk}} \implies T^{\star}(t) = T^{\star}\): `_eq_tStar_of_topup`; \(Q_M = 0 \implies T^{\star}(t) = 0\): `dQvFunded_zero_QM`; floor rounding conservative (min-monotone).

**Rule 11 (Recalibration law; DECIDED 2026-07-30: multiplicative).** The joint evolution of the implied maturity under the collateral channel AND realized variance \(\sigma^2_R(t)\) accruing against the strike:

\[
	\begin{aligned}
		T^{\star}_{\text{joint}}(t) \, \leftarrow \, T^{\star}(t)\cdot\Big(1 - \frac{\sigma^2_R(t)}{\sigma^2_K}\Big)^{+} \, = \, \underbrace{\frac{2\,\Delta Q_v^{\star}}{N_\sigma}}_{T^{\star}} \cdot \underbrace{\frac{\min\big(\Delta Q_v^{\star},\, Q_M/p_{\text{risk}}\big)}{\Delta Q_v^{\star}}}_{\text{funding factor}} \cdot \underbrace{\Big(1 - \frac{\sigma^2_R}{\sigma^2_K}\Big)^{+}}_{\text{budget factor}}
	\end{aligned}
\]

The arrow is the Rule (the enacted law); the second equality is the factorization identity. *Rationale (recorded):* \(\upsilon = T/2 \implies \sigma^2\text{-budget} \propto T\) (bijection preserved); \(T^{\star}_{\text{joint}} = T^{\star}\cdot f_{\text{fund}}\cdot f_{\text{budget}}\) (monotonicities chain); burn rate constant (no cliff).

*Formalized:* `tStarJointMult`: `_nonneg` (on \(T^{\star}(t) \geq 0\)), `_antitone` (\(\downarrow \sigma^2_R\)), `_zero` (\(= T^{\star}(t)\) at \(\sigma^2_R = 0\)), `_exhausted` (\(= 0\) at \(\sigma^2_R = \sigma^2_K\)). **Alternates formalized and REJECTED** (the rejection record is first-class): \(T^{\star}_{\text{sub}}\) (`joint_candidates_disagree` — off-domain floor placement only), \(T^{\star}_{\text{quad}}\) (\((1-r^2) \geq (1-r)\): pro-holder under vol clustering).

> NOTE (cascade, recorded): \(\Delta Q_v^{\star}\) on-chain lands on the PAIR \((\text{PanopticTokenId},\, \text{positionSize})\) — the tokenId is scale-free (strikes, widths, per-leg optionRatio); positionSize is an SFPM mint argument. The ratio-vs-size split of \(\ell(\xi^{\star},\iota;i_K)\) across the pair is the task-#14 sizing decision. Spec: `.planning/vol-order-v2-target-vega-SPEC.md`.

# CONTROL_OPERATORS

These are the instruments mapping **behavior objectives** to **protocol parameters** — all of \(\Theta_{\bullet}\), not only the fee schedule \(\Theta_{\phi}\).

**Convention 4 (Hazard rate vs incidence operator).** The control operators come in two types, distinguished by the glyph: plain \(\lambda_{\bullet}\) names a **hazard rate** — an arrival intensity (probability per unit time) of a behavior (arb toxicity, LP competition); tilde \(\tilde\lambda_{\bullet}\) names an **incidence operator** — a re-routing of already-arriving flow that leaves the total invariant. A hazard *adds* under composition (\(\bigoplus\), Definition 19); an incidence operator *applies* — it changes who bears the flow, not how much arrives. The distinction is proved, not stylistic: the JIT operator leaves `mevTotal` invariant while FLAIR falls and the toxicity ratio rises (`JitLiquidity` carriers) — it cannot be a hazard.

**Definition 19 (Hazard aggregation).** The aggregate hazard is the composition of the behavior hazards, and \(\bigoplus\) on hazard rates **is addition** (the hazard-coordinate image of \(\otimes_{\phi}\) — Theorem 14):

\[
	\begin{aligned}
	    \lambda\, &\equiv \, \displaystyle \bigoplus_{i=1}^n \lambda_i \, \quad \, i \, \in \, \{\text{lp-competition (FLAIR)}, \text{arb toxicity}, \text{TBD}, \cdots \} \\
		\lambda \, &\equiv \, \lambda_M \, + \, \lambda_X
	\end{aligned}
\]

**MEV is struck from the index set** (correcting the note's original listing): \(\lambda_{\text{ARB}}\) — already a member — is \(\lambda_{\text{MEV}}\)'s SUMMAND (Definition 23), so listing MEV double-counts; and the MEV tax enters the trader-paid fee through the \(\otimes_{\phi}\) monoid (Rule 12), never through \(\bigoplus\). The second line is the per-leg split, mirroring the leg fees of Rule 6.

**Theorem 14 (Fee monoid and hazard exactness).** \(\mathcal{G}_{\phi} = \big([0,1],\, \otimes_{\phi},\, 0\big)\) is an Abelian monoid — commutative, associative, identity \(0\), closed on \([0,1]\), monotone — and the hazard correspondence is **exact** under \(\phi = 1 - e^{-\lambda}\):

\[
	\begin{aligned}
		\big(1-e^{-\lambda_M}\big) \otimes_{\phi} \big(1-e^{-\lambda_X}\big) \, = \, 1-e^{-(\lambda_M+\lambda_X)}
		\quad\Longleftrightarrow\quad \lambda \, \equiv \, \lambda_M + \lambda_X
	\end{aligned}
\]

Definition 19's \(\bigoplus\)-is-addition is exactly this exactness: fee composition and hazard addition are the same law in two coordinate systems.

*Formalized:* `VolInstrument.probOr_eq`; `probOr_comm`; `probOr_assoc`; `probOr_zero`; `probOr_mem_Icc`; `probOr_mono`; `probOr_hazard`.


**Definition 24 (Linear pool value).** The **linear pool value** is the pool's holdings marked at spot — the money-units valuation with no curvature adjustment:

\[
	\begin{aligned}
		\pi^{\text{linear}}(t) \, \equiv \, p_{(\eta,\Delta_i)}(i(t))\; Q_X^L\Big(\textstyle\sum_j^{\#\text{LP}} L_j(i(t);\cdot)\Big) \, + \, Q_M^L\Big(\textstyle\sum_j^{\#\text{LP}} L_j(i(t);\cdot)\Big)
	\end{aligned}
\]

*(Symbol per user rulings 2026-08-04: values are \(\pi\)-objects and this valuation is linear; the former ad-hoc \(D_t\) is retired — \(D\) reads as debt.)*

**Recall (the marginal price).** \(p_{\varphi} \equiv \partial_{Q_X}\varphi \,/\, \partial_{Q_M}\varphi\) — the quotient of partials of the trading function, minted at Definition 14; its relation to the grid is the next statement, placed here because Definitions 25–26 consume both objects (user ruling 2026-08-04).

**Theorem 40 (Grid–marginal-price relation) *(promoted from Proposition 10 — the number is retired, not reused)*.** The grid map and the marginal price are DISTINCT objects — the identification \(p_{(\eta,\Delta_i)} \equiv p_{\varphi}\) is NOT admissible. At Definition 9's reserves, for the \(\chi_{X/M} = 1/2\) member,

\[
	\begin{aligned}
		p_{\varphi}(i_K) \, = \, \frac{\Delta Q_M^L_{(1/2,\,0)}(i_K)}{\Delta Q_X^L_{(1/2,\,0)}(i_K)} \, = \, \frac{1}{p_{(\eta,\Delta_i)}(i_K)\; p_{(\eta,\Delta_i)}(i_K+\Delta_i)}
	\end{aligned}
\]

— the grid enters the marginal price as the INVERSE PRODUCT of adjacent grid values: the √price-vs-price gap Theorem 4 already flags (`priceGrid_eq_tickPrice_sq`), plus the leg orientation. *Formalized* (`GammaGrid`, project `589d44ac`, axiom-clean): `grid_marginal_price` — discharged after being owed through two bundle cycles.

**Definition 25 (Portfolio value function).** With \((Q_X^L(p_{\varphi}), Q_M^L(p_{\varphi}))\) the point of the trading curve \(\varphi_{(\chi_{X/M},\,\epsilon_{X/M})} = \text{const}\) at which the marginal price \(p_{\varphi}\) (Definition 14) attains a given value, the **portfolio value function** is the on-curve valuation of the RESERVES — the \(L\)-superscripted quantities (Definition 10): bare \(Q_X, Q_M\) remain the trading-side arguments of Definition 13, while the reserves derived from liquidity are what the pool holds and what is valued here —

\[
	\begin{aligned}
		\pi^{\varphi}(p_{\varphi}) \, \equiv \, p_{\varphi}\, Q_X^L(p_{\varphi}) \, + \, Q_M^L(p_{\varphi})
	\end{aligned}
\]

— the portfolio value function of [CFMM_GEOMETRY](../refs/cfmm/angeris-geometry_of_cfmms-2023.pdf), the conic dual of the trading function (their equivalence theorem); concave and nondecreasing in \(p_{\varphi}\). **Relation to Definition 24:** \(\pi^{\text{linear}}\) marks FIXED holdings at spot; \(\pi^{\varphi}\) moves holdings ALONG the curve — at the current price the two coincide, away from it \(\pi^{\varphi}\) falls below the fixed-holdings line, and that concavity gap is what LVR prices. *Status:* **UNFORMALIZED** — no Lean carrier (`exp/CESLongVolPayoff.pi_eta_trader` is the trader-side Bregman object, distinct).

**Definition 26 (LVR rate).** The loss-versus-rebalancing rate is a PAYOFF-shaped object — a loss — hence the \(\pi\) glyph (user ruling 2026-08-04): \(\pi^{\mathrm{LVR}}\), carrying NO time argument (it is a state function of the current tick); the time-argument form \(\pi^{\mathrm{LVR}}(t)\) is the per-block realized loss below, so no bar normalization is needed. Per [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf), with the second derivative well-defined on Definition 25's object — and the evaluation point CORRECTED (user-exposed 2026-08-04) to the current MARGINAL price \(p_{\varphi}(i(t))\), not the grid value, the two differing by Theorem 40's relation:

\[
	\begin{aligned}
		\pi^{\mathrm{LVR}} \, \equiv \, \frac{\sigma^2(i(t))\, p_{\varphi}^2}{2}\,\Big|\frac{d^2\pi^{\varphi}}{dp_{\varphi}^2}\Big|\;\Big|_{p_{\varphi} = p_{\varphi}(i(t))} \qquad \big(\text{CPMM: } \pi^{\mathrm{LVR}} = \tfrac{\sigma^2}{8}\,\pi^{\varphi}\big)
	\end{aligned}
\]

**Discretization frame** (\(t\)-indexed, shared by FLAIR and MEV; the Lean carriers keep their `w_t`/`D_t`/`a_t` names — standing doc-glyph/Lean-name split). Time is stepped by the cadence \(\Delta t\); per step \(t\):

- the per-step traded VOLUME in LIQUIDITY UNITS is \(\varphi_{(1/2,\,0)}\big(i(t);\, \Delta Q(t),\, 0\big) \, = \, \sqrt{\Delta Q_M(t)\,\Delta Q_X(t)} \, \geq \, 0\) — Definition 18's zero-liquidity convention: the symmetric geometric mean of the two legs, neither money nor asset alone, commensurable with \(L\) and \(\Delta Q_v^{\star}\); NO alias symbol is minted for it (the former \(\Delta Q_{\cdot}(t)\) is retired — user ruling 2026-08-04);
- \(\pi^{\text{linear}}(t) > 0\) — the per-step capital in MONEY units (Definition 24), serving the MEV/LVR side, where LVR is intrinsically a money rate;
- \(\pi^{\mathrm{LVR}}(t) \, \equiv \, \pi^{\mathrm{LVR}}\cdot\Delta t \, \geq \, 0\) — the per-block arb-opportunity weight: the rate (Definition 26, no time argument) over one block; the time argument itself marks the per-block object, so no bar normalization is needed (user ruling 2026-08-04);
- \(\nu_t \, \equiv \, \varphi_{(1/2,\,0)}\big(i(t);\, \Delta Q(t),\, 0\big)\,\big/\,\varphi_{(1/2,\,0)}\big(i(t);\, 0,\, L\big)\) — the PER-STEP UTILIZATION RATIO, exactly Definition 18's gate argument: FLAIR's capital-normalized flow, dimensionless with no numéraire choice.

**Coordinates (user ruling (i), 2026-08-04):** FLAIR runs in UTILIZATION coordinates (\(\nu_t\)); MEV runs in MONEY coordinates (\(\pi^{\mathrm{LVR}}(t)/\pi^{\text{linear}}(t)\)). No other \(t\)-indexed symbols are introduced in this section.

**Definition 30 (HODL value).** The inception basket marked at the current price — the tangent line to \(\pi^{\varphi}\) at \(p_{\varphi}(t_0)\):

\[
	\begin{aligned}
		\pi^{\text{HODL}}(t) \, \equiv \, p_{(\eta,\Delta_i)}(i(t))\,Q_X^L(t_0) \, + \, Q_M^L(t_0)
	\end{aligned}
\]

\(\pi^{\text{HODL}}(t_0) = \pi^{\text{linear}}(t_0)\), and thereafter \(\pi^{\text{HODL}}(t) \geq \pi^{\varphi}(p_{\varphi}(t)) = \pi^{\text{linear}}(t)\) (tangent above the concave curve) — the gap's expected rate is \(\pi^{\mathrm{LVR}}\) (Definition 26).

**Definition 31 (Returns).** Gross returns in the form of [DUFFIE] (D. Duffie, *Dynamic Asset Pricing Theory*, 3rd ed., Princeton UP, 2001 — the book is copyrighted and not vendored; author-hosted companions: [survey](../refs/duffie-intertemporal_asset_pricing_survey.pdf), [revisions](../refs/duffie-dapt-revisions-2002.pdf)): payoff over INCEPTION capital — the denominator must be \(t_0\) (a contemporaneous denominator makes \(R^{\varphi} \equiv 1\) by tangency):

\[
	\begin{aligned}
		R^{\varphi}(t) \, \equiv \, \frac{\pi^{\varphi}(p_{\varphi}(t))}{\pi^{\text{linear}}(t_0)}, \qquad
		R^{\text{HODL}}(t) \, \equiv \, \frac{\pi^{\text{HODL}}(t)}{\pi^{\text{linear}}(t_0)}
	\end{aligned}
\]

### FLAIR

**Definition 20 (FLAIR).** The **LP-competition hazard** \(\lambda_{\text{FLAIR}}\) is the time-integrated fee yield per unit of pooled capital — the FLAIR metric of [FLAIR](../refs/flair/MilionisWanAdamsFLAIR.pdf), instantiated on this document's objects:

\[
	\begin{aligned}
		\lambda_{\text{FLAIR}}\, (t) \, &\equiv \, \displaystyle\int_{t_0}^t \frac{\displaystyle\int_{p_{(\eta,\Delta_i)} \,(i(t))} \, \phi \, ( \sigma \, (i (t));t) \, d\, p_{(\eta,\Delta_i)} \,(t)}{\varphi_{(1/2,\,0)}\Big(i(t);\, 0,\, \sum_{j}^{\# \text{LP}} \, L_j \, (i(t); \cdot)\Big)} \, dt
	\end{aligned}
\]

— numerator: the fee density collected across the price range; denominator: the pool capital in **LIQUIDITY UNITS** — the trading function at zero flow on the aggregate liquidity, per Definition 18's utilization convention (user ruling (i), 2026-08-04: FLAIR is utilization-based; the money-units \(\pi^{\text{linear}}\) serves the LVR/MEV and ADL layers). It is a plain-\(\lambda\) hazard (Convention 4): fee income *arrives*; nothing is re-routed. **Two repairs vs the raw note (user-approved 2026-08-04):** the undeclared \(p_{(\cdot)}\) contraction is expanded to \(p_{(\eta,\Delta_i)}\) (no new shorthand minted), and the denominator's first term was corrected \(Q_M^L \to Q_X^L\) (both terms were the money leg) — that money-units form was then SUPERSEDED by the utilization-coordinates restatement above.

**Theorem 15 (FLAIR identification and corner solution).** The program \(\sup_{\Theta_{\lambda_{\text{FLAIR}}}} \lambda_{\text{FLAIR}}\) over a sub-block \(\Theta_{\lambda_{\text{FLAIR}}} \subset \Theta_{\phi}\) is **identified and solved**. Discretizing per the frame (\(\nu_t\) the per-step utilization ratio; \(\Lambda\) the logistic of Theorem 10):
\[
	\begin{aligned}
		\lambda_{\text{FLAIR}} \, = \, \bar\phi\, W \, + \, u \sum_j \alpha_j\, W_j, \qquad
		W = \sum_t \nu_t, \quad
		W_j = \sum_t \Lambda\big(\gamma_j(\sigma(i(t))-\beta_j)\big)\, \nu_t, \quad 0 \leq W_j < W
	\end{aligned}
\]

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{FLAIR}}} \, = \, \{\bar\phi,\, \alpha,\, u(\alpha_R)\}: \qquad
		\lambda_{\text{FLAIR}} \, \leq \, \Big(\bar\phi_{\max} + u_{\max}\sum_j \alpha_{j,\max}\Big)\, W
	\end{aligned}
\]

attained **bang-bang at the level corner** for any fixed \((\beta,\gamma)\); in \((\beta,\gamma)\) the bound is approached only as \(\beta \to -\infty\) — a saturation boundary, not a maximum: the shape parameters never attain it (strict gap at every finite \(\beta\)). This is the G3 level/shape split: \(\Theta_{\lambda_{\text{FLAIR}}}\) is a LEVEL block; \((\beta_j, \gamma_j)\) only place the transition.

*Caveat (kept):* this functional has no demand elasticity — the fee–volume trade-off lives in the optimal-fee layer (`FeeSchedule`, arXiv:2508.08152). *Note (OPEN):* Rule 6 charges fees PER LEG; the discretization applies the composed fee (Rule 7) to volume — the leading-order equivalence of per-leg fee income and composed-fee-on-volume is assumed, unformalized.

*Formalized:* `FlairOptimization.flairMulti_affine`; `W_j_lt_W`; `flairMulti_le_corner`; `flairMulti_corner_attained_levels`; `flairMulti_saturation_limit`; `flairMulti_strict_below_saturation`; `Theta_lambda_identification`.

### MEV

Sources, all vendored: [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf) (the anchor — arb profits with fees), [MEV_THEORY_I](../refs/mev/KulkarniDiamandisChitraTheoryMEV1.pdf) (arXiv 2207.11835, the sandwich channel), [OPT_FEES](../refs/flair/CampbellBergaultMilionisNutzOptimalFees.pdf) (arXiv 2508.08152, the optimal-fee layer). Angstrom is the implementation reference (batch auction / uniform clearing). Statements below carry their provenance tags [M0]–[M10]; the former standalone M-blocks are consumed by this section (byte-pins on them are invalidated by the move — disclosed).

**Convention 5 (Event probabilities) [M0].** Probabilities are written \(\mathbb{P}_{\text{event}}\): \(\mathbb{P}_{\Delta_{\text{ARB}}}\) = arbitrage-trade probability (the paper's `P_trade`; Lean `MevOptimization.ptrade`), \(\mathbb{P}_{L_{\text{JIT}}}\) = JIT-arrival probability (CJZ's `π`; Lean `πJ`). <!-- notation-map -->

**Notation map [M0].** [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf)'s fee symbol `γ` is transcribed as this document's fee `φ`; this document's `γ_j` stays the sigmoid steepness. The paper's Poisson block rate `λ` is transcribed through its own primitive `Δt ≜ λ⁻¹`, because this document's `λ` is the hazard rate (Convention 4). The paper's composite parameter `η ≜ γ√(2λ)/σ` is deliberately never named — `η` is reserved project-wide for the pricing grid (Definition 8). <!-- notation-map --> Root-block-rate factor: \(\sqrt{2/\Delta t}\) throughout, no composite abbreviation. Fee \(= \phi\) (ceiling \(\bar\phi\), set \(\Theta_{\phi}\)); the quote function is \(\varphi_{(\chi_{X/M},\,\epsilon_{X/M})}\) (Definition 13), currently \(\varphi_{(1/2,\,0)}\) (Rule 5); bare \(\varphi\) is NOT used.

\(\Delta t\): mean interblock time (Angstrom: 1 bundle/block/pair ⟹ batch cadence \(= \Delta t\)). \(\sigma(i(t))\) enters BOTH the fee and \(\mathbb{P}_{\Delta_{\text{ARB}}}\) — always written in full tick-argument form (Convention 2; no \(\sigma_t\) shorthand). The \(t\)-indexed symbols \(\pi^{\text{linear}}(t)\), \(\pi^{\mathrm{LVR}}(t)\), \(\nu_t\)(and the unaliased traded volume \(\varphi_{(1/2,\,0)}(i(t); \Delta Q(t), 0)\)) are the discretization frame at the head of this section (FLAIR in utilization coordinates, MEV in money coordinates — user ruling (i), 2026-08-04).

\(\lambda_{\text{ARB}}\) (Definition 22) \(\subsetneq \lambda_{\text{MEV}}\) (Definition 23): SUMMAND, not sibling — Definition 19's index set carries one, never both (double-count); \(\lambda_{\text{ARB}}\) absorbs the "arb toxicity" entry. The paper's `FEE` \(\subsetneq \lambda_{\text{FLAIR}}\) (noise flow excluded there). Standing hypotheses: the paper's Assumption 2 (symmetric driftless mispricing, two-sided fee; non-symmetric variant App. C); Proposition 9 additionally: regularity (13), (15).

**Definition 21 (Arbitrage-trade probability) [M1].** Per [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf) Thm 1 (§4.1, Assumption 2) — the long-run fraction of blocks with a profitable arb; bonding-function-independent, only the fee enters:

\[
	\begin{aligned}
		\mathbb{P}_{\Delta_{\text{ARB}}}\big(\phi(\sigma(i(t));t),\sigma(i(t)),\Delta t\big) \, \equiv \, \frac{\sigma(i(t))}{\sigma(i(t)) + \phi(\sigma(i(t));t)\sqrt{2/\Delta t}}
	\end{aligned}
\]

Both slots are instantiated (user comments 2026-08-04): the \(\sigma\) slot at the realized tick volatility \(\sigma(i(t))\) (Convention 2), the \(\phi\) slot at the schedule value \(\phi(\sigma(i(t));t)\) (Definition 18). Lean's `ptrade` keeps both slots abstract — Theorem 16's monotonicities and convexity are statements in the abstract \(\phi\) slot.

**Theorem 16 (Properties of \(\mathbb{P}_{\Delta_{\text{ARB}}}\)) [M1].** \(\mathbb{P}_{\Delta_{\text{ARB}}} \in (0,1]\), with \(\mathbb{P}_{\Delta_{\text{ARB}}} = 1 \iff \phi = 0\); strictly decreasing AND **strictly convex** in \(\phi\); increasing in \(\Delta t\) and in \(\sigma\); \(\to 0\) as \(\phi \to \infty\). (The strict convexity is what Theorem 19's strict half consumes.)

*Formalized* (`MevOptimization.lean`): `ptrade_mem_Ioc`; `ptrade_eq_one_iff`; `ptrade_strictAntiOn` (on \([0,\infty)\)); `ptrade_monotoneOn_dt`; `ptrade_monotoneOn_sigma`; `ptrade_strictConvexOn` (+ `_convexOn`); `ptrade_tendsto_atTop`.

**Proposition 9 (The MMR split) [M2].** At fast-block small-fee leading order (\(\approx\) inherited by everything below), the rebalancing loss splits by the trade probability. In this document's \(\pi\)-convention (payoff/value objects; user ruling 2026-08-04): the paper's `ARB` is the arb-extracted payoff \(\pi^{\text{ARB}}\), its `FEE` is the fee-income payoff \(\pi^{\phi}\) (fee glyph \(\phi\) — DISTINCT from \(\pi^{\varphi}\), the trading-function glyph, per the standing \(\phi\)/\(\varphi\) split), and its `LVR` is the loss payoff \(\pi^{\mathrm{LVR}}\) (Definition 26): <!-- notation-map -->

\[
	\begin{aligned}
		\pi^{\text{ARB}} \, \approx \, \pi^{\mathrm{LVR}}\cdot \mathbb{P}_{\Delta_{\text{ARB}}}, \qquad
		\pi^{\phi} \, \approx \, \pi^{\mathrm{LVR}}\cdot(1-\mathbb{P}_{\Delta_{\text{ARB}}}), \qquad
		\pi^{\text{ARB}}+\pi^{\phi} \, \approx \, \pi^{\mathrm{LVR}}
	\end{aligned}
\]

*Status:* asserted from [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf) Thm 3 + eq. (12), Thm 4 — a Proposition, not a Theorem: the in-tree `arb_add_fee_eq_lvr` is a bridge identity only and is never to be cited as MMR Thm 3 formalized.

**Definition 22 (The discrete \(\lambda_{\text{ARB}}\)) [M3].** The ARB-channel hazard, on the SAME \(\Theta_{\phi}\) as FLAIR (\(\phi(\sigma) = \texttt{multiFee}(n,\gamma,\beta,\alpha,\bar\phi,u)\)):
\[
	\begin{aligned}
		\lambda_{\text{ARB}}(t) \, \equiv \, \sum_{s<t} \mathbb{P}_{\Delta_{\text{ARB}}}\big(\phi(\sigma(i(s))),\sigma(i(s)),\Delta t\big)\,\frac{\pi^{\mathrm{LVR}}(s)}{\pi^{\text{linear}}(s)}
	\end{aligned}
\]

The running-time argument mirrors \(\lambda_{\text{FLAIR}}(t)\) (Definition 20); \(s\) is the step dummy (user comment 2026-08-04).



CPMM instantiation — NOT a new definition: both tiers instantiate Definition 26's object on the CPMM member, per [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf) §7.1 (leading order) and Corollary 2 (exact). Two tiers: (i) the LEADING-ORDER per-step weight

\[
	\begin{aligned}
		\pi^{\mathrm{LVR}}(t) \, = \, \frac{\sigma^2(i(t))}{8}\,\pi^{\varphi}(t)\,\Delta t
	\end{aligned}
\]

(Definition 26's CPMM case — \(\pi^{\mathrm{LVR}}\) is a RATE ⟹ \(\cdot\Delta t\) per block; summand \(\propto \Delta t^{3/2}\) = [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf) §7.1 per-block scaling; no guard needed); (ii) the EXACT Corollary-2 kernel, restated in this document's objects (\(\pi^{\text{ARB}}\), \(\pi^{\varphi}\), Convention 2 — the paper's `ARB/V` form was stale notation):

\[
	\begin{aligned}
		\big(\pi^{\text{ARB}}/\pi^{\varphi}\big)_{\text{exact}} \, = \, \frac{\big(\sigma^2(i(t))/8\big)\,\mathbb{P}_{\Delta_{\text{ARB}}}\,e^{\phi/2}}{1-\sigma^2(i(t))\,\Delta t/8}
	\end{aligned}
\]

— the ONLY object carrying the guard \(\sigma^2(i(t))\,\Delta t < 8\); reuse this symbol downstream. *Formalized:* \(\lambda_{\text{ARB}} \geq 0\): `mevMulti_nonneg`, CPMM weight `mevWeight_cpmm_pos` (\(\cdot\Delta t\) carried). Tier (ii) is **UNFORMALIZED/OPEN** (T19 omitted — no carrier).

**Theorem 17 (Identification of \(\Theta_{\lambda_{\text{ARB}}}\)) [M4].** For \(\gamma_j > 0\): \(\lambda_{\text{ARB}}\) is decreasing in \(\bar\phi\), \(\alpha_j\), \(u\), increasing in \(\beta_j\), convex in \(\phi\); and there is **no affine analogue** of Theorem 15's `flairMulti_affine` — \(\mathbb{P}_{\Delta_{\text{ARB}}}\) is non-affine, level/shape do not separate, Theorem 18's bound is a SUM, not scalar × path weight. The identified block:

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{ARB}}} \, = \, \{\bar\phi,\, \alpha,\, u\}
	\end{aligned}
\]

Batch clearing (Definition 23, \(\lambda_{\text{sandwich}} = 0\)) ⟹ \(\Theta_{\lambda_{\text{MEV}}} = \Theta_{\lambda_{\text{ARB}}} = \{\bar\phi, \alpha, u\}\).

*Formalized:* `mevMulti_anti_phibar`; `mevMulti_anti_alpha`; `mevMulti_anti_u`; `mevMulti_mono_beta`.

**Theorem 18 (The infimum program on \(\lambda_{\text{ARB}}\)) [M5].**

\[
	\begin{aligned}
		\lambda_{\text{ARB}}(t) \, \geq \, \sum_{s<t} \mathbb{P}_{\Delta_{\text{ARB}}}\Big(\bar\phi_{\max} + u_{\max}\textstyle\sum_j \alpha_{\max,j},\, \sigma(i(s)),\, \Delta t\Big)\frac{\pi^{\mathrm{LVR}}(s)}{\pi^{\text{linear}}(s)}
	\end{aligned}
\]

Three attainment statements (the RHS uses the fee CEILING — unreachable at finite shape): (i) fixed shape ⟹ the level-block infimum is attained bang-bang at the corner TOP; (ii) the bound is approached only as \(\beta_j \to -\infty\), with a STRICT gap at every finite \(\beta\) (a saturation boundary, not a minimum); (iii) on a compact box a minimizer exists, with value strictly above the bound.

*Formalized:* `mevMulti_ge_corner`; `mevMulti_corner_attained_levels`; `mevMulti_saturation_limit` [CORRECTED: Aristotle-added \(0 \leq \bar\phi_{\max} + u_{\max}\alpha_{\max}\) — the \(\mathbb{P}_{\Delta_{\text{ARB}}}\) pole]; `mevMulti_strict_above_saturation`; `mevMulti_exists_min_compact` [CORRECTED: fees \(\geq 0\) required — unbounded below on arbitrary compact \(\Theta\)]; packaged `Theta_lambdaMEV_identification`, `mevMulti_min_gt_corner` (at \(u = u_{\max}\)).

*Annotation [M6a] (internal reference — deliberately not a numbered statement, user ruling 2026-08-04):* over \(\Theta_{\phi}\) unconstrained there is NO trade-off — \(\max \lambda_{\text{FLAIR}}\) and \(\min \lambda_{\text{ARB}}\) sit at the SAME level corner, saturate along the SAME \(\beta_j \to -\infty\), robustly to every linear scalarization; \((\beta, \gamma_j)\) are NOT essential. Carriers: `joint_corner_degeneracy`, `joint_beta_degeneracy`, `joint_scalarization_degeneracy` (`MevJointProgram.lean`). The degeneracy-breaker must come from OUTSIDE \(\Theta_{\phi}\).

**Theorem 19 (Flat-path optimality at constant \(\sigma\); the \(\sigma\)-varying comparison is REFUTED) [M6b].** Over arbitrary nonnegative fee PATHS \(\{\phi_t\}\) — NOT \(\Theta_{\phi}\) schedules — with \(\nu_t\) per the frame, \(W = \sum_t \nu_t > 0\), the FLAIR fee budget \(B \equiv \sum_t \phi_t\nu_t\) (the fee income the path is constrained to deliver), aligned measure \(\pi^{\mathrm{LVR}}(t) \equiv \varphi_{(1/2,\,0)}(i(t); \Delta Q(t), 0)\), and constant volatility \(\sigma(i(t)) \equiv \sigma(i(t_0))\):

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, W\cdot \mathbb{P}_{\Delta_{\text{ARB}}}\!\left(\frac{B}{W},\,\sigma(i(t_0)),\,\Delta t\right),
		\qquad \text{equality} \iff \phi_t\ \text{constant on}\ \{t : \nu_t > 0\}
	\end{aligned}
\]

\(B/W\) is the **budget-mean fee** — the flat fee delivering the same FLAIR income as the path (`flair_budget_pins_mean_fee`) — the flat path minimizes \(\lambda_{\text{ARB}}\) at equal FLAIR income; non-constant on \(\{\nu_t > 0\}\) is strictly worse (the strict half consumes Theorem 16's strict convexity). The alignment \(\pi^{\mathrm{LVR}}(t) \equiv \varphi_{(1/2,\,0)}(i(t); \Delta Q(t), 0)\) is STRONG (traded volume ∝ LVR path block-by-block — and CROSS-COORDINATE under ruling (i): a liquidity-units path proportional to a money-units path); without it Jensen is inapplicable and the conclusion can reverse. **REFUTED for \(\sigma\)-varying schedules** (`mev_ge_flat_under_flair_budget_false`): \(\exists\, \phi(\cdot) \geq 0\) with \(\lambda_{\text{ARB}}^{\text{flat}} > \lambda_{\text{ARB}}^{\phi}\) at equal FLAIR income — witness \(T{=}2,\ \Delta t{=}2,\ B{=}2,\ \sigma=(1,10)\), fees \((2,0)\): \(\tfrac{31}{22} > \tfrac{4}{3}\) (\(\sigma\)-varying ⟹ different convex summands, Jensen inapplicable). **OPEN — the \(\Theta_{\phi}\)-restricted case:** the witness is \(\sigma\)-DEcreasing while \(\Theta_{\phi}\)-reachable schedules are isotone (`multiFee_monotone`); the refutation settles only the general claim.

*Formalized:* budget half `flair_budget_pins_mean_fee`, `flair_budget_mean`; path carriers `flairPath`/`mevPath` with bridges `flairPath_schedule`, `mevPath_schedule`, `flairPath_sum`, `flairPath_budget_mean`; the constant-\(\sigma\) display at PATH level `mev_ge_flat_under_flair_budget_const_sigma`, strict `mev_gt_flat_under_flair_budget_const_sigma`; the refutation `mev_ge_flat_under_flair_budget_false`.

**Definition 28 (Forward exchange function) [M7].** \(\mathcal{S}(\Delta Q_M)\) is the output delivered against the money-leg input \(\Delta Q_M\) at constant trading function — stated in Definition 12's signature (tick slot first, flow in the middle slot, \(L\) in the last slot; function signatures are never changed — user ruling 2026-08-04); the input rides the money leg of the flow, the output \(\mathcal{S}(\Delta Q_M)\) is withdrawn from the asset leg (orientation per Definition 12, subject to the PR-ORIENT FLAG):

\[
	\begin{aligned}
		\varphi_{(\chi_{X/M},\,\epsilon_{X/M})}\Big(i(t);\, \big(\Delta Q_M,\, -\mathcal{S}(\Delta Q_M)\big),\, L\Big) \, = \, \varphi_{(\chi_{X/M},\,\epsilon_{X/M})}\big(i(t);\, 0,\, L\big)
	\end{aligned}
\]

\(\mathcal{S}^{-1}\) is the reverse exchange function ([CFMM_GEOMETRY](../refs/cfmm/angeris-geometry_of_cfmms-2023.pdf)); the source's glyph \(G\) enters as \(\mathcal{S}\) (user ruling 2026-08-04 — sandwich semantics; also avoids any confusion with the G0–G6 block labels). <!-- notation-map -->

**Definition 27 (Sandwich hazard) [M7].** Per [MEV_THEORY_I](../refs/mev/KulkarniDiamandisChitraTheoryMEV1.pdf) eqs. (4)–(6) — the paper's slippage limit \(\eta\) enters as \(\mathrm{tol}_{\text{slip}}\) (\(\eta\) is the grid exponent, Definition 8; \(\mathrm{tol}\) is the tolerance family), its user trade \(\Delta\) is the money-leg flow \(\Delta Q_M\), and its `PNL` is the sandwich payoff \(\pi^{\text{sandwich}}\) (\(\pi\)-convention) <!-- notation-map -->. For a user trade \(\Delta Q_M\) with slippage floor \((1-\mathrm{tol}_{\text{slip}})\mathcal{S}(\Delta Q_M)\), the front-run \(\Delta Q_M^{\text{sand}}(\Delta Q_M, \mathrm{tol}_{\text{slip}})\) solves the slippage-binding equation, the back-run recovers the position, and the attacker's payoff is:
\[
	\begin{aligned}
		\mathcal{S}(\Delta Q_M^{\text{sand}} + \Delta Q_M) - \mathcal{S}(\Delta Q_M^{\text{sand}}) \, &= \, (1-\mathrm{tol}_{\text{slip}})\,\mathcal{S}(\Delta Q_M) \\[4pt]
		\Delta Q_M^{\text{sand}\prime} \, &= \, \Delta Q_M^{\text{sand}} + \Delta Q_M - \mathcal{S}^{-1}\big(\mathcal{S}(\Delta Q_M + \Delta Q_M^{\text{sand}}) - \mathcal{S}(\Delta Q_M^{\text{sand}})\big) \\[4pt]
		\pi^{\text{sandwich}}(\Delta Q_M, \mathrm{tol}_{\text{slip}}) \, &= \, \Delta Q_M^{\text{sand}\prime} - \Delta Q_M^{\text{sand}} \, = \, \Delta Q_M - \mathcal{S}^{-1}\big(\mathcal{S}(\Delta Q_M + \Delta Q_M^{\text{sand}}) - \mathcal{S}(\Delta Q_M^{\text{sand}})\big), \qquad \pi^{\text{sandwich}}(\Delta Q_M, 0) = 0
	\end{aligned}
\]

The **sandwich hazard** mirrors Definition 22's shape — extracted sandwich value per unit capital:

\[
	\begin{aligned}
		\lambda_{\text{sandwich}}(t) \, \equiv \, \sum_{s<t} \frac{\pi^{\text{sandwich}}\big(\Delta Q_M(s), \mathrm{tol}_{\text{slip}}\big)}{\pi^{\text{linear}}(s)} \, \geq \, 0
	\end{aligned}
\]

Under uniform batch clearing there is no ordering to exploit: \(\Delta Q_M^{\text{sand}} = 0 \implies \pi^{\text{sandwich}} = 0 \implies \lambda_{\text{sandwich}} = 0\) (the Angstrom regime). *Status:* **UNFORMALIZED** — no Lean carrier; the paper's profit bound (linear in \(\mathrm{tol}_{\text{slip}}\), with a liquidity hurdle) is cited, not transcribed. **\(\mathrm{tol}_{\text{slip}}\) — the conjecture is RESOLVED, split (`SandwichTol.lean`, CPMM member, all axiom-clean):**

- **\(\Theta_{\phi}\) branch REFUTED** (`sandwich_fee_hurdle_false`, 30 bp witness): the exact profitability frontier is \(0 < \pi^{\text{sandwich}}_{\phi} \iff \phi(1-\phi)\,\Delta Q_M^{\text{sand}} < (1-\phi)(Q_M^L+\Delta Q_M) - Q_M^L\) (`pnlFee_pos_iff`) — \(\mathrm{tol}_{\text{slip}}\) does not enter. The fee's true relationship pins an admissible TRADE SIZE, not the tolerance: \(\Delta Q_M \leq \tfrac{\phi}{1-\phi}\,Q_M^L \implies \pi^{\text{sandwich}}_{\phi} \leq 0\) for every front-run (`sandwich_fee_hurdle_corrected`); above it, NO positive \(\mathrm{tol}_{\text{slip}}\) closes the channel.
- **\(\Theta_p\) branch PROVED as stated** (`sandwich_grid_cap`): within one spacing of the MARGINAL price (\(\texttt{priceRatio} \leq r\), \(r = \lambda^{\eta\Delta_i}\) — the marginal-price step, the SQUARE of the grid step per Theorem 40), the binding tolerance is capped: \(\mathrm{tol}_{\text{slip}} \leq 1 - r^{-1}\).

So \(\mathrm{tol}_{\text{slip}}\) is functionally BOUNDED by \(\Theta_p\) and unconstrained by \(\Theta_{\phi}\); it remains a free tolerance of the \(\mathrm{tol}\) family inside the \(\Theta_p\) cap. Supporting: `pnl_pos` (feeless sandwiches always profit), `slip_strictMono` (binding bijection), closed forms `slip_eq`/`pnl_eq`/`priceRatio_eq`/`pnlFee_eq` (\(Q_X^L\) cancels in every payoff).

**Definition 23 (Aggregate MEV hazard) [M7].** The aggregate extraction hazard is the hazard-side sum

\[
	\begin{aligned}
		\lambda_{\text{MEV}} \, \equiv \, \lambda_{\text{ARB}} \oplus \lambda_{\text{sandwich}}
	\end{aligned}
\]

with \(\oplus\) per Definition 19 / Theorem 14 (\(\otimes_{\phi}\) acts on \([0,1]\), NEVER on unbounded hazards). \(\lambda_{\text{sandwich}} = 0 \implies \lambda_{\text{MEV}} = \lambda_{\text{ARB}}\) — uniform clearing delivers this by construction, so Definition 22 through Theorem 19 transfer to \(\lambda_{\text{MEV}}\) verbatim in the Angstrom regime; the sandwich channel is a distinct object ([MEV_THEORY_I](../refs/mev/KulkarniDiamandisChitraTheoryMEV1.pdf)), unmodelled here. **Protocol choice (DECIDED 2026-08-04):** MEV is controlled by the TAX — Rule 12's monoid entry (and the JIT liquidity tax when that section converts); auction-recycling mechanisms (ToB rebates) are NOT part of this protocol and are removed from this document — their formalized-not-adopted carriers remain in-tree. One parametric lever OUTSIDE \(\Theta_{\phi}\):

**Cadence** \(= \Delta t\): moves \(\lambda_{\text{ARB}}\) monotonically, absent from \(\lambda_{\text{FLAIR}}\) — the non-degenerate lever outside \(\Theta_{\phi}\).

*Formalized* (`MevJointProgram.lean`): `mevTotal` (plain addition, with the \(\otimes_{\phi}\) correspondence as its own lemma `mevTotal_probOr_hazard`); `mevTotal_eq_arb_of_sandwich_zero`; `mevTotal_mevMulti_eq_of_sandwich_zero`; cadence `mev_mono_dt`. *(The removed recycling mechanism's carriers — the `mevNet` family, `taxFraction` — remain in-tree as formalized-not-adopted.)*

**Caveats [M8]** (annotations, no statement class): LEADING ORDER — everything rests on eq. (12) fast-block small-fee asymptotics; only Definition 22(ii), under its guard, is exact. QUASI-STATIC — \(\mathbb{P}_{\Delta_{\text{ARB}}}\) is steady-state, applied per step on a \(\sigma\)-varying path (this document's extension; valid iff parameters are slow vs mispricing mixing). NO DEMAND ELASTICITY — the missing term is [MMR](../refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf) §7.3 eq. (27); corner solutions are objective properties, NOT equilibrium claims (the elasticity layer is [OPT_FEES](../refs/flair/CampbellBergaultMilionisNutzOptimalFees.pdf)). AGGREGATE SCOPE — two channels only; unmodelled: noise backruns, multi-block censoring (lengthens \(\Delta t\)), JIT (taxed separately), gas (additive fee). CADENCE VALIDITY — the \(\Delta t\) law is validated for block times \(\gtrsim 1\)s; sub-second needs jump-diffusion, out of scope. The Theorem 19 \(\sigma\)-varying/\(\Theta_{\phi}\)-restricted split stands as labelled there.

**Rule 12 (\(\tau_{\text{MEV}}\) entry — monoid channel; DECIDED 2026-07-31) [M9].** The MEV tax enters the trader-paid fee through the proven Abelian monoid (Definition 17 / Theorem 14):

\[
	\begin{aligned}
		\phi_{\text{total}} \, \leftarrow \, \phi_M \otimes_{\phi} \phi_X \otimes_{\phi} \tau_{\text{MEV}}, \qquad
		\phi \otimes_{\phi} \tau_{\text{MEV}} \, \geq \, \phi \;\; (\tau_{\text{MEV}} \geq 0,\, \phi \leq 1)
	\end{aligned}
\]

Alternates formalized, NOT adopted: (B) convex separation \(\phi = (1-\tau_{\text{MEV}})\phi + \tau_{\text{MEV}}\phi\) (incidence-targeting, intensity-neutral); (C) auction lump-sum ToB recycling (`taxFraction`, `mevNet` — mechanism not part of this protocol; removed from the document 2026-08-04).

**Theorem 20 (The discriminating algebra — what the monoid entry buys and cannot buy) [M10].**

\[
	\begin{aligned}
		\text{(A) intensity:} \quad & \mathbb{P}_{\Delta_{\text{ARB}}}\big(\phi \otimes_{\phi} \tau_{\text{MEV}}\big) \, \leq \, \mathbb{P}_{\Delta_{\text{ARB}}}(\phi) \quad \text{(strict for } \tau_{\text{MEV}} > 0,\, \phi < 1\text{)} \\
		\text{(A) no targeting:} \quad & (\phi_M \otimes_{\phi} \tau_{\text{MEV}}) \otimes_{\phi} \phi_X \, = \, \phi_M \otimes_{\phi} (\phi_X \otimes_{\phi} \tau_{\text{MEV}}) \quad \text{(aggregate leg-invariant)} \\
		\text{(A) hazard-exact:} \quad & (1-e^{-\lambda_M}) \otimes_{\phi} (1-e^{-\lambda_X}) \otimes_{\phi} (1-e^{-\lambda_\tau}) \, = \, 1-e^{-(\lambda_M+\lambda_X+\lambda_\tau)} \\
		\text{(A} \neq \text{B):} \quad & \exists\, \phi, \tau:\; (1-\tau)\big(\phi_M \otimes_{\phi} \phi_X\big) \, \neq \, \big((1-\tau)\phi_M\big) \otimes_{\phi} \big((1-\tau)\phi_X\big) \\
		\text{(B breaks hazard):} \quad & \exists\, \tau, \lambda:\; 1-e^{-\tau\lambda} \, \neq \, \tau\,(1-e^{-\lambda})
	\end{aligned}
\]

Consequences (proved): \(\lambda_\tau\) is a genuine \(\oplus\)-summand (hazard-exact); the intensity effect is STRICT ⟹ \(\lambda_{\text{ARB}} \downarrow\); NO leg-targeting (benign flow pays); NO compensation routed (donation ⟹ compose with (B)/(C), ORDER-SENSITIVE: tax-then-compose \(\neq\) compose-then-split); \(\phi \otimes_{\phi} \tau\) moves the level direction jointly (\(\lambda_{\text{FLAIR}} \uparrow\), \(\lambda_{\text{ARB}} \downarrow\)).

*Formalized* (`TauMevAlgebra`, 14/14 axiom-clean — the carriers parked at Rule 7 now attached): (A) `tau_monoid_mem`; `tau_monoid_ge`/`_gt`; `tau_intensity_effect(_strict)`; `tau_no_targeting`; `tau_hazard_exact`; (B) `tau_split_budget`; `tau_split_intensity_neutral`; `tau_split_flair_linear`; `tau_split_mevNet_bridge`; (D) `tau_scaling_not_monoid_hom`; `tau_order_matters`; `tau_split_breaks_hazard`.

# BEHAVIOR_WELFARE_UTILIZATION

ANCHOR: [CJ](../refs/mev/CapponiJiaAdoptionDEX.pdf) §5.1 — Lemma 3, Propositions 5–6 (Lemmas 1–2 cited only for trade-occurrence conditions). Role of this section: the interior selector for the grid tilt \(\eta^{\star}\) — the degeneracy-breaker outside \(\Theta_{\phi}\) ([M6a]).

**Convention 6 (Anchor imports) [E0].** Exogenous anchor objects carry a HAT over their RAW value — no compact glyph is assigned (user ruling 2026-08-04); \(\pi^{\bullet}\) = payoff/value objects (protocol or anchor). <!-- notation-map --> The paper's objects enter as:

- \(\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}} \, \equiv \, \) the investor private-use payoff — the EXOGENOUS relative payoff increment (hat = exogeneity; parallel to \(\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}\)); Lean `premInv`;
- \(\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}\) — the per-period price shock, raw hatted value (Lean `premShock`; one-spacing move: \(\lambda^{\eta\Delta_i} - 1\) in marginal price);
- \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}} \, > \, 0\) — per-period arbitrage-occurrence probability (the `CJ` tag is load-bearing: NEVER identified with MMR's \(\mathbb{P}_{\Delta_{\text{ARB}}}\), E8(3));
- \(\mathbb{P}_{L_{\text{INV}}} \, > \, 0\) — investor-arrival probability;
- \(\varpi_H \, \geq \, 0\) — hold-benchmark coefficient, \(\mathbb{E}[R^{\text{HODL}}] = \varpi_H\,\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}\) (\(R^{\text{HODL}}\): Definition 31; the anchor's \(R_A\));
- \(\varpi_D \, \geq \, 0\) — the constant subtracted in the LP excess return.

The paper's curvature-indexed results are RE-INDEXED by \(\varsigma_{X/M}\) — a SHARE object (`curvOfTilde_not_curvature`; formerly Theorem 9, removed); symbol substitution, NOT an object identification (interior embedding REFUTED, `canon_Fcap_not_CES`). Collision glyphs `κ`, `χ`, `θ`, `τ`, `ν` are not used in this section; remaining paper symbols are renamed at first use. <!-- notation-map -->

Positivity is load-bearing: \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}} = 0\) collapses E2 (\(\mathrm{arbLoss} \equiv 0\)); \(\mathbb{P}_{L_{\text{INV}}} = 0\) kills E4's PEAK (via \(c_1 < 0\)), NOT its strict increase.

## **E1. [ADDITION] The curvature family and the discrete index**

**Theorem 28 (Curvature family — \(\varphi\)-separation) [E1].** The anchor's family ([CJ](../refs/mev/CapponiJiaAdoptionDEX.pdf) §5.1, p. 23) is the convex separation of the two ENDPOINT members of Definition 13 — the \(\epsilon_{X/M} = 1\) member rescaled, and the SQUARE of the balanced \(\epsilon_{X/M} = 0\) member:

\[
	\begin{aligned}
		(1-\varsigma_{X/M})\,A\,(\hat p + 1)\,\varphi_{(\hat p/(\hat p+1),\,1)}(Q_X,Q_M) \; &+ \; \varsigma_{X/M}\,\big(\varphi_{(1/2,\,0)}(Q_X,Q_M)\big)^{2}, \qquad \varsigma_{X/M} \in [0,1] \\
		\text{1-homogeneous in } (Q_X,Q_M) \; &\iff \; \varsigma_{X/M} = 0 \\
		A \, &= \, \big(Q_X^{0}\,Q_M^{0}/\hat p\big)^{1/2} \qquad (Q^{0} = \text{the anchor's initial reserves})
	\end{aligned}
\]

\(\hat p\) = the anchor's numeraire-relative price of \(X\) (raw value, Convention 6; \(p_B = 1\)). The SQUARE is the homogeneity obstruction — every \(\varsigma_{X/M} > 0\) member fails 1-homogeneity, an independent route to the refuted CES embedding (`canon_Fcap_not_CES` — the E1 settled note; the earlier Theorem 9 citation here was a misattribution, corrected at removal).

*Formalized* (`PhiMix`, 4/4 axiom-clean, project `7d9a8baa`): `Fmix_eq_phi` (the separation); `F0_eq_phiLin`, `F1_eq_phiGeom_sq` (the two components); `Fmix_homogeneous_iff` (the obstruction — TRUE as stated; the refute-and-correct clause went unused).

OUR discrete index, from `VolInstrument.priceEta`:

\[
	\begin{aligned}
		\frac{p_{(\eta, \Delta_i)}(i+\Delta_i)}{p_{(\eta, \Delta_i)}(i)} \, &= \, \lambda^{\Delta_i^{2}\eta/2}
		\qquad \text{(INDEPENDENT of } i \text{)} \\
		\varsigma_{X/M}(\eta,\Delta_i) \, &:= \, 1 \, - \, \frac{p_{(\eta, \Delta_i)}(i)}{p_{(\eta, \Delta_i)}(i+\Delta_i)}
		\, = \, 1 \, - \, \lambda^{-\Delta_i^{2}\eta/2}
	\end{aligned}
\]

strictly increasing in \(\eta\); a bijection \((0,\infty) \to (0,1)\); \(\to 0\) as \(\eta \to 0^{+}\), \(\to 1\) as \(\eta \to \infty\).

**"F is \(\varphi\)" — SETTLED, part proven part refuted** (via the canonical trading function of [CFMM_GEOMETRY](../refs/cfmm/angeris-geometry_of_cfmms-2023.pdf) §1.3.2): agreement at \(\kappa = 1\) ONLY (\(\mathrm{canon}\,F_1 = \varphi_{(1/2,\,0)}\) up to scale); the FAMILY identity is REFUTED for \(\kappa \in (0,1)\); the \(F_0\)-substitution is REFUTED; any agreement-respecting identification must REVERSE orientation. DIAGNOSIS: Capponi's \(\kappa\) travels the \(\epsilon_{X/M}\) axis; \(\varsigma_{X/M}\) is share-only — **E8(1) stays OPEN, with a witness.**

*Formalized* (`CanonicalCurve`, 16/16 axiom-clean): `canon_phiEps`; `canon_Fcap(_homogeneous/_one/_zero)`; agreement `canon_Fcap_one_eq_phiEps_half`; `canon_Fcap_numeraire` (two anchor prices collapse to ONE grid price). REFUTED: `canon_Fcap_not_phiEps`; `linear_not_phiEps_half` + `tildeOfCurv_zero` + `curvIndex_orientation_inconsistent`; `cpmm_sits_at_curvIndex_zero`.

\(\varsigma_{X/M}(\eta,\Delta_i)\) is a MONOTONE PROXY for the anchor's `k`, not a restatement: it carries NO per-tick liquidity term (same \(\varsigma\), different liquidity ⟹ different slippage), so placing it in the `k` slot is a MODELLING step — E8(1). WARNING: \(\eta = 1\) is the sqrt-price grid (`priceEta_one`), NOT \(\varsigma_{X/M} = 1\); the range is the OPEN \((0,1)\) — the anchor's corners are unreachable, and interiority in \(\eta\) is INHERITED from \(\varsigma_{X/M}^{\star} \in (0,1)\), not evidence supplied by the reparametrization.

**Definition 29 (Branch points) [E2, E3].** The premia generate the **branch points** (subscripts tag the generating premium — S = shock, I = investor:

\[
	\begin{aligned}
		\varsigma_{X/M,S} \, \equiv \, 1 - \sqrt{\tfrac{1+\phi}{1+\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}}}, \qquad
		\varsigma_{X/M,I} \, \equiv \, 1 - \sqrt{\tfrac{1+\phi}{1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}}}
	\end{aligned}
\]

Anchor payoffs (bare, user ruling 2026-08-04): \(\pi^{-\text{arb}}\) the arb-loss payoff, \(\pi^{\text{trader}}\) the investor-surplus payoff, \(\pi^{\text{dep}}\) the initial-deposit value — ratios are written as explicit quotients. <!-- notation-map -->

**Theorem 22 (Arbitrage-loss ratio) [E2]** (anchor Lemma 3(1)):

\[
	\begin{aligned}
		\frac{\pi^{-\text{arb}}}{\pi^{\text{dep}}}(\varsigma_{X/M}) \, &= \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\cdot
		\begin{cases}
			(1+\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}) \, - \, \dfrac{1+\phi}{1-\varsigma_{X/M}}, & \varsigma_{X/M} \in [0,\ \varsigma_{X/M,S}] \quad \text{(A.38, corner)} \\[8pt]
			(1+\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}})\,\dfrac{\varsigma_{X/M,S}^{2}}{\varsigma_{X/M}}, & \varsigma_{X/M} \in [\varsigma_{X/M,S},\ 1] \quad \text{(A.36, interior)}
		\end{cases}
	\end{aligned}
\]

GUARD: \(0 \leq \phi < \hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}\) (Lemma 1's arbitrage-occurrence condition), hence \(\varsigma_{X/M,S} > 0\); the interior branch never touches the \(1/\varsigma_{X/M}\) pole (Lean domain `Set.Ioc 0 1`, glued halves, `hkphiS : 0 < kphiS` explicit). Branches agree at \(\varsigma_{X/M,S}\) — common value \(\tfrac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}(1+\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}})\,\varsigma_{X/M,S}\) — and the glued function is **strictly decreasing** on \((0,1]\) (strict by \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}} > 0\), Convention 6).

*Formalized* (`EtaCurvature`): `arbLossRatio_branch_agree`; `arbLossRatio_strictAntiOn`; `arbLossRatio_pos`; `kphiS_mem_Ioo`; `kphiS_eq_zero_of_eq`.

**Theorem 23 (Investor-surplus ratio) [E3]** (anchor Lemma 3(2)):

\[
	\begin{aligned}
		\frac{\pi^{\text{trader}}}{\pi^{\text{dep}}}(\varsigma_{X/M}) \, &= \, \frac{1}{2}\cdot
		\begin{cases}
			(1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}) \, - \, \dfrac{1+\phi}{1-\varsigma_{X/M}}, & \varsigma_{X/M} \in [0,\ \varsigma_{X/M,I}] \quad \text{(A.43, corner)} \\[8pt]
			(1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}})\,\dfrac{\varsigma_{X/M,I}^{2}}{\varsigma_{X/M}}, & \varsigma_{X/M} \in [\varsigma_{X/M,I},\ 1] \quad \text{(A.42, interior)}
		\end{cases}
	\end{aligned}
\]

GUARD: \(0 \leq \phi < \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\) (Lemma 2's investor-trades condition), hence \(\varsigma_{X/M,I} > 0\) (`hkphiI : 0 < kphiI`). Same continuity at \(\varsigma_{X/M,I}\); **strictly decreasing** on \((0,1]\). SCALE + CONDITIONING (one line): this is the PER-INVESTOR ratio — Lemma 3(2)'s object is \(2\times\) it, weighted \(\mathbb{P}_{L_{\text{INV}}}\), while Theorem 22 carries \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}\) — additive combinations must supply the missing \(\mathbb{P}_{L_{\text{INV}}}\).

*Formalized* (`EtaCurvature`): `surplusRatio_strictAntiOn`.

**Theorem 24 (Premium ordering, geometrized) [E3].**

\[
	\begin{aligned}
		\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}} \, \leq \, \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}} \quad \Longleftrightarrow \quad \varsigma_{X/M,S} \, \leq \, \varsigma_{X/M,I}
	\end{aligned}
\]

The anchor's Proposition 5 consumes the premia ONLY through this ordering of the branch points.

*Formalized* (`EtaCurvature`): `kphiS_le_kphiI_iff`.

**Assumption 1 (LP excess return — behavioral) [E4]** (anchor (A.50)–(A.52)). *The class ASSUMPTION is minted here (user ruling 2026-08-04): behavioral structure imported from an anchor model — assigned, not proved; \(\leftarrow\) syntax; per-class counter.* The anchor's returns \(R_D, R_A\) enter as \(R^{\varphi}, R^{\text{HODL}}\) (Definitions 30–31); its Proposition-5 coefficients \(\tau_1, \tau_2, \tau_3\) enter as \(\varpi_1, \varpi_2, \varpi_3\) (\(\tau\) is TAKEN by \(\tau_{\text{MEV}}\); joins the anchor-coefficient family \(\varpi_H, \varpi_D\); Lean `cOne`/`cTwo`/`cThree` unchanged). <!-- notation-map -->

\[
	\begin{aligned}
		\mathbb{E}[R^{\varphi}] - \mathbb{E}[R^{\text{HODL}}]\,(\varsigma_{X/M}) \, &\leftarrow \,
		\begin{cases}
			\varpi_3(\varsigma_{X/M}) \, - \, \varpi_D\,\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}, & \varsigma_{X/M} \in [0,\ \varsigma_{X/M,S}] \quad \text{(A.52)} \\
			\varpi_2(\varsigma_{X/M}) \, - \, \varpi_D\,\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}, & \varsigma_{X/M} \in [\varsigma_{X/M,S},\ \varsigma_{X/M,I}] \quad \text{(A.51)} \\
			\dfrac{\varpi_1}{\varsigma_{X/M}} \, - \, \varpi_D\,\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}, & \varsigma_{X/M} \in [\varsigma_{X/M,I},\ 1] \quad \text{(A.50)}
		\end{cases} \\[6pt]
		\varpi_3(\varsigma_{X/M}) \, &= \, \frac{\mathbb{P}_{L_{\text{INV}}}}{2}\Big(\frac{1+\phi}{1-\varsigma_{X/M}} - 1\Big)
		\, - \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\Big((1+\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}) - \frac{1+\phi}{1-\varsigma_{X/M}}\Big) \\
		\varpi_2(\varsigma_{X/M}) \, &= \, \frac{\mathbb{P}_{L_{\text{INV}}}}{2}\Big(\frac{1+\phi}{1-\varsigma_{X/M}} - 1\Big)
		\, - \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\,\frac{(1+\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}})\,\varsigma_{X/M,S}^{2}}{\varsigma_{X/M}} \\
		\varpi_1 \, &= \, \frac{\mathbb{P}_{L_{\text{INV}}}}{2}\Big(1+\phi-\sqrt{\tfrac{1+\phi}{1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}}}\Big)\Big(\sqrt{\tfrac{1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}}{1+\phi}}-1\Big)
		\, - \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\,(1+\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}})\,\varsigma_{X/M,S}^{2} \qquad \text{(constant in } \varsigma_{X/M}\text{)}
	\end{aligned}
\]

Composition: the excess return is LP revenue from investor flow MINUS the arb loss; the investor's own surplus (Theorem 23) does NOT enter. The revenue term is positive even at \(\phi = 0\), increasing in \(\varsigma_{X/M}\) below \(\varsigma_{X/M,I}\) and decreasing above — the OPPOSITE sign to Theorem 23's surplus below \(\varsigma_{X/M,I}\). GUARD: \(0 \leq \phi < \hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}} \leq \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\) ⟹ both branch points positive; poles avoided (Lean glued `Set.Icc` domains, `hkphiS`, `hkphiI` explicit).

**Theorem 25 (Interior optimum — the kink maximum) [E4]** (anchor Proposition 5). Under Assumption 1: the glued function is continuous at BOTH branch points; strictly increasing on \([0, \varsigma_{X/M,I}]\); and under \(\varpi_1 > 0\) strictly decreasing on \([\varsigma_{X/M,I}, 1]\), so

\[
	\begin{aligned}
		\varsigma_{X/M}^{\star} \, = \, \varsigma_{X/M,I} \, = \, 1 - \sqrt{\tfrac{1+\phi}{1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}}}, \qquad
		\varsigma_{X/M}^{\star} \in (0,1) \iff \phi < \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}
	\end{aligned}
\]

\(\varsigma_{X/M}^{\star}\) is a BRANCH POINT — a kink; the derivative jumps; no first-order condition exists and none is claimed. Liquidity-freeze corollary (Proposition 5(2)): excess return negative at \(\varsigma_{X/M}^{\star}\) ⟹ negative on all of \([0,1]\). BOUNDARY: at \(\varpi_1 \leq 0\) the pool is in the freeze region, the LP payoff is \(\mathbb{E}[R^{\text{HODL}}] = \varpi_H\hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}}\) (constant in \(\varsigma_{X/M}\)), and strict single-peakedness is FALSE — the strict statement holds only under \(\varpi_1 > 0\).

*Formalized* (`EtaCurvature`): `lpExcess_branch_agree_kphiS`/`_kphiI`; `lpExcess_strictMonoOn`; `lpExcess_strictAntiOn`; `lpExcess_isMaxOn`; `kphiStar_eq_kphiI`; `kphiStar_mem_Ioo_iff` (interior ⟺ \(\phi < \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\)); `lpPayoff_isMaxOn`; `liquidity_freeze_minimal` (\(c_1 \leq 0\)).

**Theorem 26 (Deposit efficiency; the zero-sum band) [E5]** (anchor Proposition 6, deposit half; under Assumption 1). Deposit efficiency (A.56) — expected investor volume over deposited value — has the two-branch shape with the SAME kink: increasing on \([0, \varsigma_{X/M}^{\star}]\), decreasing above, maximized at \(\varsigma_{X/M}^{\star}\). On the corner branch, at the \(\times 2\) (per-deposit) scale of Theorem 23's normalization, the zero-sum identity in \(\pi\)-terms (per-capita LP revenue deflated by the LP population \(\#_{\text{LP}}\)):

\[
	\begin{aligned}
		\underbrace{\pi^{\text{trader}}}_{= \,(1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}) - \frac{1+\phi}{1-\varsigma_{X/M}}}
		\; + \;
		\underbrace{\frac{\pi^{\phi}}{\#_{\text{LP}}}}_{= \,\frac{1+\phi}{1-\varsigma_{X/M}} - 1}
		\; = \; \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}
		\qquad \text{on } [0,\varsigma_{X/M,I}]
	\end{aligned}
\]

— below \(\varsigma_{X/M}^{\star}\), tilt is a PURE ZERO-SUM transfer investor→LP; the pie shrinks only above, where the investor curtails volume. That is where the peak comes from.

*Formalized* (`EtaCurvature`): `depositEfficiency_branch_agree`; `depositEfficiency_isMaxOn`; `surplus_add_revenue_const`.

**OPEN — the welfare half.** NOT a corollary of Theorems 23 + 25 (below \(\varsigma_{X/M}^{\star}\) the LP payoff RISES while the surplus FALLS); the anchor's welfare object is a two-period compounded carrier with its own coefficient — untranscribed. GAS caveat (two lines): the anchor's Assumption 3 zeroes the arbitrageur and books the rent as DEADWEIGHT only because validators sit OUTSIDE its agent set; the `### MEV` premises (tax; batch clearing) put the recipient back inside, making the rent a TRANSFER — the anchor's welfare ranking over \(\varsigma_{X/M}\) does NOT import.

**Theorem 27 (The \(\eta^{\star}\) transport) [E6].** By inverting E1's bijection at the kink (log algebra; no FOC — Theorem 25):

\[
	\begin{aligned}
		\eta^{\star} \, = \, \frac{\ln\!\big((1+\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}})/(1+\phi)\big)}{\Delta_i^{2}\,\ln\lambda},
		\qquad \varsigma_{X/M}(\eta^{\star},\Delta_i) \, = \, \varsigma_{X/M}^{\star}
	\end{aligned}
\]

REQUIRES: Assumption 1; \(\varpi_1 > 0\) (else freeze — Theorem 25's boundary); \(0 \leq \phi < \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\) (interiority: \(\eta^{\star} > 0 \iff\) this); Convention 6's positivity; the \(\varsigma_{X/M}\)-in-the-`k`-slot modelling step (E1, E8(1)).

Statics: strictly \(\uparrow \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\), strictly \(\downarrow \phi\); \(\Delta_i\) is a NORMALIZATION identity (\(\eta^{\star} \propto 1/\Delta_i^{2}\); \(\varsigma_{X/M}^{\star}\) is \(\Delta_i\)-free). The excess return \(\circ\, \varsigma_{X/M}(\cdot,\Delta_i)\): strictly \(\uparrow\) on \((0,\eta^{\star}]\), \(\downarrow\) on \([\eta^{\star},\infty)\). Factor-share reading UNAVAILABLE for \(\Delta_i \lesssim 21\) (e.g. \(\eta^{\star} \approx 458, 4.6\) at \(\Delta_i = 1, 10\)) — grid-exponent reading only. Bridge (i) = Theorem 21; the reserve-side factor-share identification (ii) is **OPEN** (E8(6)); NO relation asserted to `exp/DynamicsOptimization` (different objective, claim-(ii)'s η).

*Formalized* (`EtaCurvature`): `priceEta_step_ratio`; `curvIndex_eq_of_priceEta`; `curvIndex_mem_Ioo`; `curvIndex_strictMono`; `curvIndex_tendsto_zero`/`_one`; **`curvIndex_etaStar`**; `etaStar_pos_iff`; `etaStar_strictMono_premInv`; `etaStar_strictAnti_fee`/`_spacing`; `lpExcessEta_isMaxOn`/`_strictMonoOn`/`_strictAntiOn`; T28'a `priceEta_eq_p_eta_half`/`priceEta_eq_P_half`.

**Proposition 11 (The fee–geometry coupling) [E7].** Under \(\varpi_1(\phi) > 0\) and \(\phi < \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\), at any FIXED realized fee \(\phi\):

\[
	\begin{aligned}
		\frac{\partial \eta^{\star}}{\partial \phi} \, = \, \frac{-1}{(1+\phi)\,\Delta_i^{2}\,\ln\lambda} \, < \, 0
	\end{aligned}
\]

— pushing the fee toward the level corner (Theorems 15/18) moves the geometry optimum DOWN: the two dials are coupled, and no common argmax exists.

*Formalized (antitonicity half):* `etaStar_strictAnti_fee`; `etaStar_coupled_to_fee_corner`; `eta_no_common_argmax`. The displayed exact derivative is UNFORMALIZED — hence Proposition.

## TODO — OPEN register [E8]

Item numbers are LOAD-BEARING (cited as E8(n) throughout).

1. **The identification and the equilibrium transfer.** (a) OBJECT: \(\varsigma_{X/M}(\eta,\Delta_i)\) in the anchor's `k` slot is a MODELLING step (Theorem 27's REQUIRES; the indices provably do NOT line up except at the CPMM — `curvIndex_orientation_inconsistent`, `canon_Fcap_not_CES`). (b) EQUILIBRIUM: the anchor's closed forms on THIS AMM are ASSUMED (Assumption 1), not derived — deriving them means re-solving (A.31)/(A.39) on a discrete grid with per-tick liquidity. Nothing in Theorems 22–27 is a theorem about this project's AMM.
2. **Welfare.** The anchor's welfare half: untranscribed, not a corollary, ranking non-importable — Theorem 26.
3. **The two arbitrage objects are NOT identified.** The CJ per-period ratio vs \(\lambda_{\text{ARB}}\) (Definition 22): different models, different units; no identification attempted. STANDING BAN.
4. **Gas.** Absorbed (anchor Assumption 3), not modelled; the deadweight-vs-transfer contradiction is recorded at Theorem 26.
5. **The \(\Theta_{\phi}\)-restricted \(\sigma\)-varying MEV comparison** — Theorem 19's OPEN, untouched here.
6. **The factor-share identification** (Theorem 27, claim (ii)): open as a modelling claim; UNAVAILABLE wherever \(\eta^{\star} \notin (0,1)\) (low spacings in standard use). T28'b remains ABSENT.
7. **The Phase-11 degeneracy is not resolved here**: no single objective carries both a demand-elastic investor and \(\lambda_{\text{ARB}}\); \(\hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\) is a CANDIDATE demand layer, not a closure.
8. **\(\eta^{\star}\) is \(\sigma\)-indexed, η is a design constant**: the transcription is at FIXED \(\phi\), the protocol's fee is \(\phi(\sigma(i(t));t)\) — the corner induces \(\eta^{\star}(\sigma)\); reconciling a state-dependent target with a fixed grid parameter is unaddressed.
9. **The strict single-peakedness boundary**: at \(\varpi_1 \leq 0\) the payoff is flat (Theorem 25's boundary) and \(\eta^{\star}\) is no argmax; the SIGN of \(\varpi_1\) at the fee corner is unpinned.

Scope reminders (one line each): the anchor is a two-period discrete-shock model, not MMR's fast-block diffusion; the η-parametrization covers \((0,1) \subsetneq [0,1]\) — no `η = 1` ⇔ \(\varsigma_{X/M} = 1\) reading.

> Provenance: `EtaCurvature` 51/51 axiom-clean (projects `4878ca32` + repair `c3a617f3`); carriers distributed into the Theorem 22–27 footers. AMENDED hypotheses (conclusions intact): `lpExcess_strictAntiOn` + the standing premium order \(\phi < \hat{\tfrac{\Delta p_{(\eta,\Delta_i)}}{p_{(\eta,\Delta_i)}}} \leq \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\); `etaStar_pos_iff` + \(-1 < \hat{\tfrac{\Delta \pi^{\text{trader}}}{\pi^{\text{trader}}}}\) (`Real.log` is \(\log|x|\); unguarded criterion FALSE).

<!-- END ETA -->

## JIT — the event-time incidence operator \(\tilde\lambda_{\text{JIT}}\)

Scale separation: a JIT event \(e = (\text{deposit}, \text{order}, \text{withdraw})\) is intra-block, \(\text{supp}(e) \subseteq \{t(e)\}\) ⟹ invisible to time-integrated hazards (\(\lambda_{\text{FLAIR}}\) sees at most one step's weight). Event-indexed, over the JIT event set \(\mathcal{E}\):

\[
	\begin{aligned}
		\tilde\lambda_{\text{JIT}} \, = \, \sum_{e \in \mathcal{E}} \phi\big(\sigma_{t(e)}\big)\,\frac{w^{\text{JIT}}_e}{D_{t(e)}}, \qquad w^{\text{JIT}}_e \, = \, \text{intercepted (uninformed) flow of } e
	\end{aligned}
\]

Delegation/incidence (Capponi–Jia–Zhu 2311.18164: the JIT LP selects against toxic flow):

\[
	\begin{aligned}
		\lambda_{\text{FLAIR}}^{\text{PLP}} \, = \, \lambda_{\text{FLAIR}} - \tilde\lambda_{\text{JIT}}, \qquad
		\lambda_{\text{ARB}}^{\text{PLP}} \, = \, \lambda_{\text{ARB}} \;\; \text{(toxic flow undelegated)}
		\;\; \implies \;\;
		\frac{\lambda_{\text{ARB}}^{\text{PLP}}}{\lambda_{\text{FLAIR}}^{\text{PLP}}} \, \uparrow \, \tilde\lambda_{\text{JIT}} \;\; \text{(strict)}
	\end{aligned}
\]

Classification: \(\tilde\lambda_{\text{JIT}} \notin\) the \(\oplus\)-sum of \(\lambda_{\text{MEV}}\) — it is an INCIDENCE operator on \((\lambda_{\text{FLAIR}}, \lambda_{\text{ARB}})\) (adversarial mirror of \(\tau\): \(\tau\) compensates PLPs, JIT strips them). Two-tiered fee remedy = convex separation on the JIT LP's capture (share transferred to PLPs — the choice-(B) algebra of the \(\tau_{\text{MEV}}\) blocks).

## **J0. [NOTATION-MAP]**

CJZ's fee-transfer rate `λ` → `ϑ` (ours: λ = hazards). <!-- notation-map -->
CJZ's informed-arrival probability `α` → `ϖ` (ours: α_j = amplitudes). <!-- notation-map -->
CJZ's pool fee `f` → this document's `φ`. <!-- notation-map -->
CJZ's deposit multiple `ν(π)` → `m_J` (ours: ν_t = w_t/D_t). <!-- notation-map -->
CJZ's JIT-arrival probability `π` → `\mathbb{P}_{L_{\text{JIT}}}` (probability convention: ℙ_{event}; Lean binder `πJ`). <!-- notation-map -->
CJZ kept as-is: ζ, ζ_U, ζ̲, ζ★, ζ̂, ψ, ψ_U, μ(·), d_P, d_J, d̃ = p^{1/2}d, q_R, q_S, δ_S, δ_R, 𝒞, ℛ, 𝒰, W, M_T, M_J, V, V₀. CJZ's strategy-profile σ and duration flag are implementation objects, untranscribed. Known CJZ typo: main-text expected utility weights both US/UB by ψ_U; App. A.4's ψ_U/(1−ψ_U) is correct — transcribe from A.4.

## **J1. [PRIMITIVES] swap curves**

\[ \delta_S(r,d) = \frac{p\,\tilde d\,r}{\tilde d + r}, \qquad \delta_R(s,d) = \frac{\tilde d\, s}{p\tilde d + s} \]

1-homogeneous in \((r,\tilde d)\)/(\(s,\tilde d\)); increasing and concave in the first argument; increasing in \(\tilde d\).

## **J2. [JIT BEST RESPONSE] closed form + THE THIRD POLE**

For \(q_R > the fee-adjusted floor  \phi\,\tilde d_P\):

\[ \tilde d_J^{\star} = \frac{\phi\,\tilde d_P(\tilde d_P + q_R) + \sqrt{q_R^{2}\,(1+\phi)\,\tilde d_P(\tilde d_P + q_R)}}{q_R - \phi\,\tilde d_P} \]

> LEAN (correction): the first-transcribed radicand \(\sqrt{q_R(1+\phi)\tilde d_P(\tilde d_P+q_R)}\) is NOT a root of \(M_J\) — exact witness `dJstar_not_root_witness` (\(\phi=0, \tilde d_P=1, q_R=2\)); the display above carries the corrected factor \(q_R^2\): `dJroot`, `dJroot_root`, `dJroot_unique_positive_root`, pole `dJstar_pole`, no root below `MJfun_no_positive_root_below_pole`.

unique positive root of \(M_J(\tilde d_J) = \frac{(1+\phi)\tilde d_P}{(\tilde d_P+\tilde d_J)^2} - \frac{\tilde d_P + q_R}{(\tilde d_P+\tilde d_J+q_R)^2}\); unique max of the quasiconcave \(u_J\). POLE: \(\tilde d_J^{\star} \to \infty\) as \(q_R \downarrow \phi\tilde d_P\); no interior optimum for \(q_R \leq \phi\tilde d_P\).

## **J3. [UNINFORMED DEPTH] fixed point**

\(M_T(\mu;\mathbb{P}_{L_{\text{JIT}}}) = \frac{1-\mathbb{P}_{L_{\text{JIT}}}}{(1+\mu)^2} + \frac{\mathbb{P}_{L_{\text{JIT}}}(2+\mu)\sqrt{(1+\phi)(1+\mu)}}{2(1+\mu)^2}\) strictly decreasing, \(M_T(0) > 1\), \(\to 0\) ⟹ unique \(\mu(\mathbb{P}_{L_{\text{JIT}}})\) solving \(M_T = (1+\phi)/\zeta_U\); \(\mu(\mathbb{P}_{L_{\text{JIT}}}) \uparrow \mathbb{P}_{L_{\text{JIT}}}, \uparrow \zeta_U\). Threshold: \(\mu(\mathbb{P}_{L_{\text{JIT}}}) > \phi \iff \zeta_U > \underline{\zeta}(\phi,\mathbb{P}_{L_{\text{JIT}}}) = \frac{2(1+\phi)^3}{2+\mathbb{P}_{L_{\text{JIT}}}\phi(3+\phi)}\). \(m_J(\mu) = \frac{\phi(1+\mu)+\mu\sqrt{(1+\phi)(1+\mu)}}{\mu-\phi}\): positive, pole at \(\mu = \phi\) (THE FOURTH POLE), monotone.

## **J4. [DELEGATION] adverse selection onto passive LPs**

JIT deposits ONLY facing uninformed: \(d_J^{\star} = 0\) on informed events, \(= m_J\cdot d_P\) on uninformed. Passive per-unit utility \(u_P = p(\varpi\,\mathcal{C} + (1-\varpi)\,\mathcal{R}(\mathbb{P}_{L_{\text{JIT}}}))d_P\), with the full adverse-selection cost borne by passives:

\[ \mathcal{C} = -\Big[\psi\big(1 - \tfrac{1+\phi}{\zeta}\big)^2 + (1-\psi)\big(\sqrt{\zeta} - \sqrt{1+\phi}\big)^2\Big] < 0 \quad (\zeta > 1+\phi) \]

\(\mathcal{U} = \varpi\mathcal{C} + (1-\varpi)\mathcal{R}\) strictly \(\downarrow \varpi\); \(d_P^{\star} = e_P\cdot\mathbb{1}[\mathcal{U} \geq 0]\) — freeze at \(\mathcal{U} < 0\); JIT-induced freeze interval \(\varpi \in [\underline\varpi, \bar\varpi]\) exists when \(\mathcal{R}(0) > \mathcal{R}(\mathbb{P}_{L_{\text{JIT}}})\).

## **J5. [CROWDING] threshold + volume identity**

\(\mathcal{R}(\mathbb{P}_{L_{\text{JIT}}}) = \phi\,V(\mu(\mathbb{P}_{L_{\text{JIT}}}))\), \(\mathcal{R}(0) = \phi V_0\), \(V_0 = \sqrt{\zeta_U/(1+\phi)} - \sqrt{(1+\phi)/\zeta_U}\), \(V(\mu) = (1-\mathbb{P}_{L_{\text{JIT}}})[\mu + \tfrac{\mu}{1+\mu}] + \mathbb{P}_{L_{\text{JIT}}}[\sqrt{\tfrac{1+\mu}{1+\phi}} - \sqrt{\tfrac{1+\phi}{1+\mu}}]\).

\[ \text{crowding out} \iff V(\mu(\mathbb{P}_{L_{\text{JIT}}})) < V_0; \qquad \zeta^{\star}(\phi, 1) = (\sqrt{\phi} + \sqrt{1+\phi})^2 \]

(crowding region widens in \(\phi\) — a hazard-style comparative static in the fee.)

## **J6. [TWO-TIERED FEE ϑ] convex split + corner welfare**

JIT retains \(\vartheta \in [0,1]\) of its pro-rata share; \((1-\vartheta)\) → passives. Effective shares: passive \(= 1 - \vartheta\, s_J\), JIT \(= \vartheta\, s_J\), \(s_J = d_J/(d_P+d_J)\) — affine in \(\vartheta\); trader-paid \(\phi\) UNCHANGED (instance of the τ-blocks' choice-(B) algebra with \(\tau \mapsto 1-\vartheta\)). Dampening: \(\vartheta \downarrow\) ⟹ \(d_J^{\star}/d_P \downarrow\), uninformed swap \(\downarrow\). Welfare corner (monotone forces as hypotheses): \(W \uparrow \vartheta\), \(\mathcal{U} \downarrow \vartheta\) ⟹ \(\arg\max_{\{\mathcal{U} \geq 0\}} W = \vartheta^{\star} = \max\{\vartheta : \mathcal{U}(\vartheta,\mathbb{P}_{L_{\text{JIT}}}) \geq 0\}\), passive utility pinned to 0 there. Passive-optimal \(\vartheta = 0\); welfare-optimal \(\vartheta = \vartheta^{\star}\).

## **J7. [λ̃_JIT INCIDENCE] our ledger**

Tilde convention (user, 2026-07-31): \(\tilde\lambda\) marks INCIDENCE operators (act ON the hazard pair); plain \(\lambda\) marks hazards (\(\oplus\)-summands). <!-- notation-map -->

\[ \lambda_{\text{FLAIR}}^{\text{PLP}} = \lambda_{\text{FLAIR}} - \tilde\lambda_{\text{JIT}}, \quad \lambda_{\text{ARB}}^{\text{PLP}} = \lambda_{\text{ARB}} \implies \frac{\lambda_{\text{ARB}}^{\text{PLP}}}{\lambda_{\text{FLAIR}}^{\text{PLP}}} \uparrow \tilde\lambda_{\text{JIT}} \;\text{(strict, } 0 \leq \tilde\lambda_{\text{JIT}} < \lambda_{\text{FLAIR}},\, \lambda_{\text{ARB}} > 0) \]

\(\tilde\lambda_{\text{JIT}}\): incidence operator on \((\lambda_{\text{FLAIR}}, \lambda_{\text{ARB}})\), NOT an \(\oplus\)-summand of \(\lambda_{\text{MEV}}\) (`incidence_mevTotal_invariant`, `incidence_FLAIR_falls`, `toxicity_ratio_strictMono`); adversarial mirror of \(\tau\).

## **J8. [THE (β,γ) QUESTION + ANGSTROM BRIDGE] conditional, not assumed**

CJZ's JIT discriminator is DURATION, not fee level. Candidate: fee \(\phi\cdot m(\beta,\gamma;x_t)\) with \(x_t\) a settlement-time JIT observable earns \((\beta_j,\gamma_j)\) a genuine role IFF (i) sub-block deposits accrue \(\vartheta_{\text{eff}}(\beta,\gamma)\cdot\phi\) of pro-rata, (ii) surplus credited to long-duration positions, (iii) trader-paid fee INVARIANT — then the game is payoff-identical to J6 with \(\vartheta = \vartheta_{\text{eff}}(\beta,\gamma)\) and the corner statics transfer. WITHOUT (iii): trader-fee raises at JIT times WIDEN the crowding region (\(\underline\zeta, \zeta^{\star} \uparrow \phi\)) — the naive channel can worsen the paradox. l2-angstrom instance: JIT tax factor \(= \tfrac{3}{2}\cdot\)swap factor, rate \(x/(x+1)\)-form, charged on add AND remove, protocol-kept 100% (NOT rebated to passives — differs from CJZ's remedy; it prices inclusion urgency, an incentive-compatible proxy for \(\mathbb{P}_{L_{\text{JIT}}}\)). L1 Angstrom: JIT structurally neutralized (no visible victim order, uniform clearing, reward-growth invariance).

## **J9. [τ_JIT — THE LIQUIDITY TAX] DECIDED: tax, not (β,γ)**

**DECIDED (user, 2026-07-31):** \((\beta,\gamma)\) DISCARDED for JIT control (duration-blind, J8); the control is \(\tau_{\text{JIT}}\), a tax on JIT liquidity provision.

Structural asymmetry vs \(\tau_{\text{MEV}}\) (M9): swaps carry \(\phi\) ⟹ the tax could COMPOSE (\(\otimes_\phi\), monoid) or SPLIT (convex) an existing price. Liquidity provision carries NO fee ⟹ no monoid/split algebra exists; \(\tau_{\text{JIT}}\) is the ONLY price on the action — payoff-additive levy:

\[ u_J^{\tau}(\tilde d_J) \, = \, u_J(\tilde d_J) \, - \, \tau_{\text{JIT}}\,(\tilde d_J^{\text{add}} + \tilde d_J^{\text{rm}}); \qquad \text{rate } \tfrac{x}{x+1},\; x = \tfrac{3}{2}\cdot\text{swapFactor (l2-angstrom, J8c)} \]

Incidence on PAYOFFS (the endogenous objects) ⟹ the program is comparative statics:

\[
	\begin{aligned}
		\frac{\partial u_J^{\tau}}{\partial \tau_{\text{JIT}}} \, &= \, -(\tilde d_J^{\text{add}}+\tilde d_J^{\text{rm}}) \, < \, 0, \qquad \frac{\partial \tilde d_J^{\tau\star}}{\partial \tau_{\text{JIT}}} \, \leq \, 0, \qquad \tilde\lambda_{\text{JIT}} = \tilde\lambda_{\text{JIT}}(\tau_{\text{JIT}}) \, \downarrow \\
		\text{participation:} \quad & \text{JIT enters} \iff u_J(\tilde d_J^{\star}) \geq \tau_{\text{JIT}}\cdot(\text{base}) \implies \text{extensive-margin threshold } \tau_{\text{JIT}}^{\star} \text{ (FIFTH POLE candidate)} \\
		\varsigma_{X/M}\text{-entry:} \quad & \text{second-order statics signed by the strict concavity of } \delta_S, \delta_R \text{ (J1)} \implies \text{conditions in } \varsigma_{X/M} \text{ [TO PROVE]} \\
		\text{remedy direction:} \quad & \frac{\partial \zeta^{\star}}{\partial \tau_{\text{JIT}}} \, \leq \, 0 \; ? \quad \text{(does the tax SHRINK the crowding region — the mirror of J8(b)) [TO PROVE]}
	\end{aligned}
\]

Ledger classification: \(\tau_{\text{JIT}}\) is an INTENSITY lever ON the incidence operator \(\tilde\lambda_{\text{JIT}}\) — contrast \(\tau_{\text{MEV}}\) (B)/(C), intensity-neutral on \(\lambda_{\text{MEV}}\). \(\tau_{\text{JIT}} \neq \vartheta\): the two-tier split (J6) redistributes fee income; the tax prices the deposit-withdraw event itself.

> LEAN (proved, `TauJit`, 25/25 axiom-clean, project `4cb6d5ca`): K1 `uJtax`, `uJtax_jitRate`, `uJtax_strict_decrease`, `uJtax_additivity`; **NO-COMPOSITION** `uJtax_not_probOr_factor` — \(\nexists f\) with \(u_J^{\tau} = f(u_J \otimes_\phi \tau_{\text{JIT}})\), witness \((1,0)/(0,1)\): equal \(\otimes_\phi = 1\), payoffs \(1\) vs \(-\text{base}\) ⟹ no monoid/split algebra exists for a fee-free action. K2 FIFTH POLE `tauStarJIT` \(= u_J^{\star}/\text{base}\), `participates_iff_tau_le` (exact), `_antitone_tau`, `_isotone_uJstar`, `not_participates_of_tauStar_lt`, `tauStarJIT_tendsto_atTop` (base \(\to 0^+\)). K3 `lamJITtax_antitone_tau`, `_eq_of_tau_le`, `_eq_zero_of_tauStar_lt`, `lamJITtax_mevTotal_invariant`, `flair_restored_of_tauStar_lt`. K4 **`tax_shrinks_while_fee_widens`** — \(\tau_{\text{JIT}} \uparrow\) weakly SHRINKS `crowdingActive` while \(\zeta^{\star} \uparrow\) strictly in \(\phi\) (`trader_fee_raises_crowding_threshold`) ⟹ the tax is the remedy channel exactly where fee-raising backfires; also `gatedVolume_eq_baseline_of_tauStar_lt`, `crowdingActive_antitone_tau`. K5 `split_positive_tax_negative_witness` — at \(u_J = s_J = \text{base} = 1,\ \tau_{\text{JIT}} = 2\): split \(> 0\) ∀\(\vartheta \in (0,1]\), taxed \(= -1\) ⟹ \(\tau_{\text{JIT}} \neq \vartheta\). \(\varsigma_{X/M}\)-entry: OPEN (out of bundle scope).

> LEAN (proved, `JitLiquidity`, 62/62 axiom-clean, project 610bb259): J1 `deltaS/R_homogeneous/_strictMono_first/_strictConcave_first/_monotone_depth`; J2 `dJroot`, `dJroot_root`, `dJroot_unique_positive_root`, `dJstar_pole`, `MJfun_no_positive_root_below_pole` (+ REFUTED transcription `dJstar_not_root_witness`); J3 `MTfun_strictAnti/_zero_gt_target/_tendsto_zero`, `existsUnique_MTfun_solution`, `MTfun_solution_threshold`, `mJ_pos/_pole`; J4 `Ccost_neg`, `Uutil_strictAnti/_neg_iff`; J5 `Rrev_eq_fee_mul_V`, `Rrev0_eq_fee_mul_V0`, `V0fun_zetaStar_eq_Vfun_one`, `ζstar_strictMono`; J6 `effective_shares_sum/_mem`, `passive_share_affine/_tax_bridge`, `welfare_corner` (∃!); J7 `toxicity_ratio_strictMono`, `incidence_preserves_ARB`, `incidence_mevTotal_invariant`, `incidence_FLAIR_falls`; J8 `conditional_payoff_identity` (ϑ_eff(β,γ) OPEN), `trader_fee_raises_crowding_threshold`, `jitRate_gt_swapRate`, `swapRate/jitRate_strictMono/_strictConcave`. J9 = DECIDED spec; formalization bundle next.


## GREEKS

There are the classic greesks on the ppaer just waht yuou need to know abut variance swaps AND there are ones on Opition Pricing in AUotmated Market makers related wto emission polcit=ies and one I do not remember, the claim is that the parameter base for payoff shaping is \xi and iota. BUt adding all the greeks plus the behavioral mapped control parameters we might have an underspecifed system where with the fgreeks haszards there are more things to be controlled than paramteres to control them. This calls for (reading the BUnni V2 paper) buidlign LDF's on top of the geometric one, introducion  the necessary parameter. tshis is the other milestomne of the gsd

## **G0. [NOTATION-MAP]**

Sensitivities are written in REGULAR partial-derivative notation (user ruling 2026-08-11 — the calligraphic operator that stood here is retired): <!-- notation-map -->

\[
	\begin{aligned}
		\frac{\partial \pi}{\partial x} \, &\equiv \, \frac{\Delta \pi}{\Delta x}, \qquad \frac{\partial^2 \pi}{\partial x^2} \, \equiv \, \frac{\Delta}{\Delta x}\Big( \frac{\Delta \pi}{\Delta x} \Big)
	\end{aligned}
\]

— on-lattice these ARE the finite differences (the identification is the convention, stated once here).

External delta `Δ`/`δ` → \(\frac{\partial \pi}{\partial p}\), \(p = p_{(\eta, \Delta_i)}(i;t)\) (`Δ` is this document's difference operator; `δ_S, δ_R` are J1's swap curves). <!-- notation-map -->
External gamma → \(\Gamma_{\varphi} \equiv \frac{\partial^2 \pi^{\varphi}}{\partial (p_{\varphi})^2}\) — STRUCTURALLY: the second derivative of Definition 25's portfolio value against the MARGINAL price (user ruling 2026-08-11; closed form \(-\tfrac12\,\bar L_{(\chi_{X/M},\epsilon_{X/M})}\,p_{\varphi}^{-3/2}\), Theorem 32). The glyph is \(\Gamma_{\varphi}\) document-wide, mirroring \(\kappa_{\varphi}\); bare Γ is not used. SUBSTITUTION RULE: \(\Gamma_{\varphi}\) replaces the \(p_{\varphi}^{\pm 3/2}\)-SHAPED EXPRESSIONS where they are this object — never a derivative operator; the sigmoid steepness is ALWAYS subscripted `γ_j` (mirror of the κ/ς_{X/M} rule). <!-- notation-map -->
External theta Θ → IDENTIFIED with this document's \(\theta \equiv \Delta\pi/\Delta t\) (the exponent-sign FLAG — RESOLVED 2026-08-03, negative — on its display stands); `Θ_•` remains parameter-set notation and is never a Greek. <!-- notation-map -->
External vega ν → NEVER imported (`ν_t = w_t/D_t`, M6b); all vegas through \(\upsilon \equiv \Delta\pi/\Delta\sigma^2\) (bound, = t/2); σ-convention vega is written \(2\,\sigma(i(t))\,\upsilon\). <!-- notation-map -->
Maymin's liquidity Greek `Λ = ∂C/∂k` → \(\frac{\partial C}{\partial \bar L_{(1/2,\,0)}}\) (Greek of the LONG CALL C, Def 2 eq (33) — NOT of π) via \(k = \bar L_{(1/2,\,0)}^2\) (CPMM), his \(\Lambda = \frac{\partial C}{\partial \bar L_{(1/2,\,0)}}/(2\bar L_{(1/2,\,0)})\); `Λ(·)` stays the logistic. <!-- notation-map -->
Maymin's emission Greek `E = ∂C/∂e` → \(\frac{\partial C}{\partial \Delta Q_M}\) (Def 2 eq (34), again a C-Greek; our emission policy IS the ΔQ_M schedule). <!-- notation-map -->
Maymin's CEV exponent `β = w` = the NUMERAIRE weight (his §3.2 eq (4)–(5): \(x^w y^{1-w} = K\), \(x\) = numeraire, \(P = \tfrac{1-w}{w}\tfrac{x}{y}\)) → \(w = 1 - \eta_L\), i.e. \(\eta_L = 1 - w\) = the ASSET share (eta.md line 12: \(L = X^{\eta}Y^{1-\eta}\), \(P\) = price of \(X\) in \(Y\) ⟹ η = exponent on the ASSET). ORIENTATION DECIDED AT FORMULA LEVEL by eq (12): \(P \propto x^{1/(1-w)} \implies \partial_x P = \tfrac{1}{1-w}\tfrac{P}{x}\), and \(x = P^{1-w}(\tfrac{w}{1-w})^{1-w}K\), so \(\delta = \tfrac{1}{1-w}\big(\tfrac{1-w}{w}\big)^{1-w}K^{-1}\sigma_F\) EXACTLY — the \(1/(1-w)\) prefactor is the reciprocal of the ASSET weight, and the \(w \leftrightarrow 1-w\) swap gives \(\tfrac{1}{w}(\tfrac{w}{1-w})^{w}K^{-1}\sigma_F\), ≠ eq (12) for \(w \neq \tfrac12\). \(\eta_L = \eta\) is E8(6) and remains OPEN — no display below assumes it. <!-- notation-map -->
Maymin's `δ` (CEV vol coefficient) → eliminated through primitives: \(\sigma(i(t)) = \delta\, p^{\,\beta-1} = \delta\, p^{-\eta_L}\) (his σ_ret, Prop 4 eq (20), under \(\beta = w = 1-\eta_L\)) and CPMM \(\delta = 2\sigma_Q/\bar L_{(1/2,\,0)}\) (eq (12) at \(w = \tfrac12\), \(K = \bar L_{(1/2,\,0)}\)); his flow vol `σ_F` → \(\sigma_Q\) (σ̄_f is the FeeSchedule strike); his invariant `K` → \(\bar L_{(1/2,\,0)}\); his strike `K_str` → \(K\); his `κ` (eq 23) → \(c_0\) (bare κ FORBIDDEN); his CDF `χ²(x;n,·)` → \(\mathbb{P}_{Y_{n,\cdot} \leq x}\) (probability-typed ⟹ ℙ_{event}; χ banned). <!-- notation-map -->
Bardoscia's `V0` → \(\Delta Q_M\) (V₀ is CJZ's, J5); his APY `φ` → eliminated in TWO commensurable forms, always labelled (B1): SCHEDULE-LEVEL per-unit carry \(\phi(\sigma_t)\,\nu_t\) (M6b's own units, \(\nu_t = w_t/D_t\), what \(\lambda_{\text{FLAIR}}\) sums) and POSITION-LEVEL carry \(\phi(\sigma_t)\,\nu_t\,\Delta Q_M\) (what an LP position of money leg ΔQ_M earns); his `S_t` → \(p_{(\eta, \Delta_i)}(i;t)\); maturity `T`, remaining `τ = T−t` → \(T^{\star}\), \(T^{\star}-t\) (τ is τ_MEV — NEVER time). <!-- notation-map -->
Demeterfi's `S*` → \(p^{\star}\); his variance vega `V = (T−t)/T` (a REMAINING-CALENDAR-TIME ratio) → \(\upsilon\) under this document's normalization, where the argument of \(\upsilon = t/2\) is the MATURITY PARAMETER \(t\), not calendar time: at inception \(\upsilon = T^{\star}/2\), and the calendar-time form is \(\upsilon(t) = (T^{\star}-t)/2\) (`variancePortfolio_upsilon`; t-SEMANTICS clause, G6(7)). <!-- notation-map -->
Band edges `p_a, p_b` / `a, b` (Clark, Fateh–Singh) → \(p(i_l), p(i_u)\); Clark's reserves `R_α, R_β` → cumulative \(\Delta Q_X, \Delta Q_M\) (`VolInstrument.cumulativeQX/QM`); Kristensen's range factor `r` → \(\lambda_{\text{tick}}^{\iota\Delta_i}\) (through its own primitive). <!-- notation-map -->
Bichuch–Feinstein's LVR rate `ℓ(q)` → eliminated: \(a_t \equiv \ell_{\text{BF}}(\cdot)\,\Delta t\) (M0/M3; `ℓ` here stays the weight \(\ell(\xi,\iota;i_K)\)); their implied vol `σ*_x` → \(\sigma^{\star}_{\phi}\) (fee-implied); Fateh–Singh's installment rate `q` → \(q_{\text{CI}}\) (`q_R, q_S` are CJZ's). <!-- notation-map -->
Any probability reading of delta ("ATM delta = 50%") is written \(\mathbb{P}_{\text{ITM}}\), never δ. <!-- notation-map -->

## **G1. [ADDITION] The Greek ladder of the LP-payoff kernel**

Per tick \(i_K\), band \([i_l, i_u]\), sqrt-price convention (`PosSpec.tickPrice`), \(L_{(1/2,\,0)}(i_K) = \bar L_{(1/2,\,0)}\,\ell(\xi,\iota;i_K)\):

\[
	\begin{aligned}
		\frac{\partial \pi}{\partial p}\,(i_K) \, &= \,
		\begin{cases}
			\Delta Q_X(i_K) & p \leq p(i_l) \\
			L_{(1/2,\,0)}(i_K)\,\Big( p^{-1/2} - p(i_u)^{-1/2} \Big) & p(i_l) < p < p(i_u) \\
			0 & p \geq p(i_u)
		\end{cases} \\
		\Gamma_{\varphi}\,(i_K) \, &= \,
		\begin{cases}
			-\tfrac{1}{2}\, L_{(1/2,\,0)}(i_K)\, p^{-3/2} & p(i_l) < p < p(i_u) \\
			0 & \text{otherwise}
		\end{cases}
		\, = \, -\tfrac{1}{2}\,\bar L_{(1/2,\,0)}\,\ell(\xi,\iota;i_K)\,p^{-3/2}\,\mathbb{1}_{(i_l,i_u)}
	\end{aligned}
\]

> \(L_{(1/2,\,0)}(i_K)\) IN THIS DISPLAY IS THE INTRINSIC LIQUIDITY (Definition 32): \(\Gamma_{\varphi} = -\tfrac12\,\bar L_{(\chi_{X/M},\epsilon_{X/M})}\,p_{\varphi}^{-3/2}\) holds for EVERY member, because \(\frac{\partial^2 \pi}{\partial p^2} = \frac{\partial Q_X^{L}}{\partial p}\) (envelope) and Definition 32 is exactly \(-2p_{\varphi}^{3/2}/\frac{\partial p_{\varphi}}{\partial Q_X^{L}}\). The ladder form below is the \(\chi_{X/M} = 1/2\) instance, \(L_{(1/2,\,0)}(i_K) = \bar L_{(1/2,\,0)}\,\ell(\xi,\iota;i_K)\); off that member the coefficient is the state-dependent field, not a level (Theorem 29). Whether a ladder REALIZES a given member's field is Proposition 12, OPEN.
>
> Clark: value eq (10), delta = the UNNUMBERED §4.2 p. 5 display (`L/√p − L/√p_b` in-range, current p), gamma = eq (12) (`−½Lp^{−3/2}`); eq (13) is Green–Jarrow spanning, never cite it for a Greek. Kristensen eq (3.21)/(3.24). Γ jumps at the band edges (the bounded-range correction); \(\partial\pi/\partial p\) is continuous, kinked. LEAN: the value layer is `Flow.terminalPayoff` + `GeomProfile.geom_terminalPayoff_total`; the \(\partial\pi/\partial p, \Gamma_{\varphi}\) displays are UNFORMALIZED (bundle targets).

Aggregate over the ladder (partition of unity `geomWeight_sum`):

\[
	\begin{aligned}
		\Gamma^{\Sigma}_{\varphi}(p) \, &= \, -\tfrac{1}{2}\,\bar L_{(1/2,\,0)}\, p^{-3/2} \sum_{i_K}\,\ell(\xi,\iota;i_K)\,\mathbb{1}_{p \in (i_l,i_u)(i_K)} \\
		\xi = \xi^{\star} = \lambda_{\text{tick}}^{-\Delta_i/2} \; &\implies \; \Gamma^{\Sigma}_{\varphi}\big(p(i_K)\big)\, p(i_K)^2 \, = \, \text{const in } i_K \quad \textbf{(GRID-EXACT)} \\
		\text{but pointwise, inside band } i_K: \; \Gamma^{\Sigma}_{\varphi}p^2 \, &= \, -\tfrac{1}{2}\,\bar L_{(1/2,\,0)}\,\ell(\xi^{\star},\iota;i_K)\, p^{1/2} \;\propto\; p^{1/2}, \quad \text{swing } \lambda_{\text{tick}}^{\Delta_i/2} \text{ per band} \quad \textbf{(BAND-MODULATED)}
	\end{aligned}
\]

> Flat dollar gamma holds ON THE GRID, not pointwise: the log contract = the variance claim is the tick-indexed statement, PROVEN as `varswapWeight_geometric` / `logContractLiquidity_geometric` (Demeterfi EQ 11 Γ = (2/T)S⁻², 1/K² strike weighting pp. 9–10). The continuum "Γp² = const" is FALSE inside a band and must never be bundled as stated.

Theta splits; the dt-leg is REDUNDANT given (Γ, σ):

\[
	\begin{aligned}
		\theta \, &= \, \theta_{\text{fee}} \, - \, \theta_{\text{decay}}, \qquad
		\theta_{\text{decay}} \, + \, \tfrac{1}{2}\,\Gamma_{\varphi}\, p^2\, \sigma^2(i(t)) \, = \, 0 \\
		\theta_{\text{fee}}^{\text{sched}} \, &= \, \phi(\sigma_t)\,\nu_t
		\qquad \textbf{(SCHEDULE-LEVEL, per unit of money leg — M6b-commensurable; this is what } \lambda_{\text{FLAIR}} \text{ sums)} \\
		\theta_{\text{fee}}^{\text{pos}} \, &= \, \phi(\sigma_t)\,\nu_t\,\Delta Q_M \, = \, \theta_{\text{fee}}^{\text{sched}}\cdot \Delta Q_M
		\qquad \textbf{(POSITION-LEVEL — what an LP position with money leg } \Delta Q_M \text{ earns)}
	\end{aligned}
\]

> B1 CONVENTION: the two θ_fee forms differ by the factor ΔQ_M and are NEVER interchanged — M6b's budget \(\sum_t\phi_t\nu_t = B\) and \(\lambda_{\text{FLAIR}} = \bar\phi W + u\sum_j\alpha_j W_j\) (master doc) are SCHEDULE-LEVEL; G3's matrix rows and G4's target set are POSITION-LEVEL.
> Anchors: Demeterfi EQ 10, EQ 12 ("the essence of Black–Scholes"); Bardoscia §3.1.6 (unlocked Θ = APY·capital = pure fee carry, vega = 0 by §3.1.5 — his APY·V0 is the POSITION-LEVEL form); Fateh–Singh: the CI installment rate \(q_{\text{CI}}\) offsets θ exactly (their §4 Fig. caption (c)) and equals LVR in the q→∞ limit stated in the abstract/§1 prose and proved in their Lemmas 1 and 3 (NOT eq (7)–(8), which are only the ODE + boundary conditions) — the streamia bridge (`Panoptic.streamingPremium`, `theta_atm_closed_form` target). The θ display's exponent-sign FLAG (line ~42) is UNTOUCHED and blocks any frozen θ_decay constant.

Vega is maturity, not a free dial:

\[
	\begin{aligned}
		\upsilon \, = \, \frac{T}{2} \quad (\text{PROVEN}) \qquad \implies \qquad \upsilon \; \text{is controlled by } T^{\star} \text{ alone}; \qquad
		\text{locked-LP short vega (Bardoscia §3.3.5): } \; \frac{\Delta \pi}{\Delta \sigma^2} = -\tfrac{T^{\star}-t}{8}\,(\text{asset leg})
	\end{aligned}
\]

> t-SEMANTICS (binding, whole section): \(T \in \upsilon = T/2\) ≡ THE MATURITY (capital T; lowercase \(t\) is calendar time throughout), \(\upsilon = T^{\star}/2\) at inception; \(t \in\) Bardoscia locked vega ≡ CALENDAR, entering only via \(T^{\star}-t\) ⟹ \(\upsilon(t) = (T^{\star}-t)/2\), coinciding at \(t = 0\). Same remap: Demeterfi `V = (T−t)/T` (G0). No display below mixes the two.

## **G2. [ADDITION] Depth and emission Greeks; the η_L skew law**

\[
	\begin{aligned}
		\frac{\partial C}{\partial \bar L_{(1/2,\,0)}} \, &< \, 0 \quad \big(\delta = 2\sigma_Q/\bar L_{(1/2,\,0)} \implies \tfrac{\Delta\sigma}{\sigma} = -\tfrac{\Delta \bar L_{(1/2,\,0)}}{\bar L_{(1/2,\,0)}}\big), \qquad
		\frac{\partial C}{\partial \Delta Q_M} \, < \, 0, \qquad
		\bar v^2 \, = \, \frac{4\sigma_Q^2}{\dot{\bar k}} \ln\Big(1 + \frac{\dot{\bar k}\,T^{\star}}{\bar L_0^2}\Big), \;\; \dot{\bar k} \equiv \tfrac{\Delta (\bar L_{(1/2,\,0)}^2)}{\Delta t} \\
		\text{LP-side composition: } \; \frac{\partial \pi}{\partial \bar L_{(1/2,\,0)}} \, &= \, \frac{\Delta\pi}{\Delta\sigma^2}\cdot\frac{\Delta\sigma^2}{\Delta\bar L_{(1/2,\,0)}} \, = \, (\underbrace{<0}_{\text{short vega}})\cdot(\underbrace{<0}_{\text{depth compresses }\sigma}) \, \geq \, 0
	\end{aligned}
\]

> \(\bar L_0\) keeps the anchor's own subscripting: its slot is the time index, and imported anchor displays are not re-indexed (Convention 6). Everywhere else in this document the bare \(\bar L\) has been made explicit as \(\bar L_{(1/2,\,0)}\) — Definition 32.
>
> OBJECT TYPING (B3): Maymin Def 2 eq (33)–(34) and Prop 10 eq (41) are Greeks of the LONG CALL \(C\) ON the AMM token — \(\Lambda = \partial C/\partial k < 0\) ("deeper pools reduce option value by compressing volatility"), \(E = \partial C/\partial e < 0\) (emissions = our ΔQ_M schedule, bang-bang PROVEN `Flow.schedule_isLeast`, act as a dividend-yield-like variance drain). NO LP-side sign is imported: on π the depth Greek composes through the short vega and comes out with the OPPOSITE sign, \(\frac{\partial \pi}{\partial \bar L_{(1/2,\,0)}} \geq 0\) (a deeper pool damps σ, and the short-vol LP GAINS from that). C-Greeks and π-Greeks are distinct rows; both are hooks the classic BS set does not have.

The skew law (Maymin Thm 1 eq (11)–(12) + Prop 4 eq (20) + Prop 5), stated on \(\eta_L\), NOT on η, at the RESOLVED orientation \(\beta = w = 1-\eta_L\) (G0):

\[
	\begin{aligned}
		dp \, = \, \mu(p)\,dt \, + \, \delta\, p^{\,1-\eta_L}\, dW, \qquad \sigma(i(t)) = \delta\,p^{\,-\eta_L};\qquad
		\frac{\sigma_{IV}(K)}{\sigma_{IV}^{ATM}} \, = \, f(K/p;\, \eta_L) \quad \text{— independent of } \delta \text{ and } \bar L_{(1/2,\,0)}
	\end{aligned}
\]

> ORIENTATION (decided against eq (12), NOT at the invisible \(w = \eta_L = \tfrac12\) point): \(\eta_L\) ≡ ASSET share (eta.md:12), Maymin \(w\) ≡ NUMERAIRE weight (§3.2) ⟹ \(w = 1-\eta_L\), CEV exponent \(= 1-\eta_L\). LEVERAGE: \(\sigma \propto p^{-\eta_L}\) ↓ in \(p\) ∀ \(\eta_L > 0\), steepening in \(\eta_L\) (negative price-elasticity-of-variance, Bittensor §6). ATM-normalized skew depends ONLY on \(\eta_L\) — depth-invariant, testable. Grid-η transfer requires E8(6) \((\eta_L = \eta)\), OPEN — not assumed here.

## **G3. [CONTROL MATRIX]**

● = appears in the display; ○ = equilibrium-only / mediated (subscript names the mediator); — = provably absent.
LEVEL: every row is POSITION-LEVEL (B1) — θ_fee means \(\theta_{\text{fee}}^{\text{pos}} = \phi(\sigma_t)\nu_t\Delta Q_M\), and the hazard rows are the schedule-level ledgers they aggregate to.

\[
	\begin{array}{l|cccccccc}
		 & (\xi,\iota) & (\eta,\Delta_i)\to\varsigma_{X/M} & \bar L_{(1/2,\,0)} & (\bar\phi,\alpha,u) & (\beta_j,\gamma_j) & T^{\star} & \tau,\tau_{\text{JIT}} & \text{haz. inputs }(\sigma\text{-path},w_t,D_t) \\
		\hline
		\frac{\partial \pi}{\partial p} & \bullet & \bullet & \bullet & - & - & - & - & - \\
		\Gamma_{\varphi} & \bullet & \bullet & \bullet & - & - & - & - & - \\
		\upsilon\,(=t/2) & \circ_{\;\xi=\xi^{\star}} & - & - & - & - & \bullet & - & - \\
		\theta_{\text{fee}}^{\text{pos}} & \circ & \circ & \circ_{\;\text{via }\nu_t} & \bullet & \bullet & - & \circ_{\;\text{carve-out}} & \bullet \\
		\Delta\theta_{\text{fee}}/\Delta\sigma & - & - & \circ_{\;\text{via }\nu_t} & \bullet & \bullet & - & - & \bullet \\
		\frac{\partial \pi}{\partial \bar L_{(1/2,\,0)}} & \circ & \circ & \bullet & - & - & - & - & - \\
		\frac{\partial \pi}{\partial \Delta Q_M} & - & - & \bullet & - & - & \circ & - & - \\
		\sigma_{IV}/\sigma_{IV}^{ATM}\;[\textbf{DIAG}] & - & \bullet_{\;\text{uncond. in }\eta_L;\;\text{cond. on }E8(6)} & - & - & - & - & - & - \\
		\lambda_{\text{FLAIR}} & - & - & \circ & \bullet & \bullet & - & \bullet & \bullet \\
		\lambda_{\text{ARB}} & - & \bullet_{\;\eta^{\star}} & \circ & \bullet_{\;\mathbb{P}_{\Delta_{\text{ARB}}}} & \circ & - & \bullet & \bullet \\
		\tilde\lambda_{\text{JIT}} & - & \circ_{\;\text{J9 TO PROVE}} & \circ & \circ & - & - & \bullet_{\;\tau_{\text{JIT}}} & \bullet
	\end{array}
\]

> ROW COUNT (M3): 11 matrix rows, \(|\mathcal{T}| = 10\) design targets — the gap is the \(\sigma_{IV}/\sigma_{IV}^{ATM}\) row, declared **DIAGNOSTIC**: it is an OBSERVABLE (a depth-invariant identification readout for \(\eta_L\)), not a design target, and is excluded from \(\mathcal{T}\) and from every deficit count in G4. The \(\theta_{\text{fee}}^{\text{pos}}\) row's \(\bar L_{(1/2,\,0)}\) and \(\tau\) entries are ○, not ●: \(\bar L_{(1/2,\,0)}\) enters only through \(D_t\) inside \(\nu_t = w_t/D_t\), and \(\tau\) only through the tax carve-out — neither symbol appears in the display itself.

THE (β,γ) ROW, RESOLVED: \((\beta_j,\gamma_j)\) are ABSENT from every payoff-shaping Greek (\(\partial\pi/\partial p, \Gamma_{\varphi}, \upsilon\) — confirming (ξ,ι) as the shaping base) and BIND exactly in the carry profile, in both B1 forms:

\[
	\begin{aligned}
		\frac{\Delta \theta_{\text{fee}}^{\text{sched}}}{\Delta \sigma} \, &= \, u \sum_j \alpha_j\,\gamma_j\,\Lambda'\big(\gamma_j(\sigma - \beta_j)\big)\cdot \nu_t
		\qquad \textbf{(SCHEDULE-LEVEL)} \\
		\frac{\Delta \theta_{\text{fee}}^{\text{pos}}}{\Delta \sigma} \, &= \, u \sum_j \alpha_j\,\gamma_j\,\Lambda'\big(\gamma_j(\sigma - \beta_j)\big)\cdot \nu_t \,\Delta Q_M
		\qquad \textbf{(POSITION-LEVEL; the matrix row above)} \qquad \big(\Lambda' > 0:\; \beta_j \text{ translate},\; \gamma_j \text{ scale}\big)
	\end{aligned}
\]

— **at fixed \((\bar\phi,\alpha,u)\)**, the sigmoid shape ALONE places carry in σ-space and gives the short position a fee-vega \(\Delta\theta_{\text{fee}}/\Delta\sigma^2 \neq 0\).

> M4 CAVEAT — the comparative static above is PARTIAL, at fixed level parameters; it is NOT evaluated at the FLAIR optimum and must not be labelled "corner-pinned". Shaping carry RE-PRICES \(\lambda_{\text{FLAIR}}\): the master doc's \(\lambda_{\text{FLAIR}} = \bar\phi W + u\sum_j\alpha_j W_j\) has \(W_j = \sum_t \Lambda(\gamma_j(\sigma_t-\beta_j))w_t/D_t\) DEPENDING on \((\beta_j,\gamma_j)\), so every finite \((\beta,\gamma)\) leaves the sup's argument — the doc's saturating limit \(\beta\to-\infty\) (`flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`) is never attained. Level optimality is not importable into this row.

> UNITS (M2) — the locked-LP short vega \(\Delta\pi/\Delta\sigma^2 = -(T^{\star}-t)/8\cdot(\text{asset leg})\) is VALUE per σ², while \(\Delta\theta_{\text{fee}}/\Delta\sigma^2\) is VALUE per TIME per σ². The correctly-typed claim is the time-integrated one: \(\int_t^{T^{\star}} \Delta\theta_{\text{fee}}/\Delta\sigma^2\, ds\) is commensurable with the locked short vega and is the candidate hedge; the pointwise derivative alone "hedges" nothing. Signs verified: short vega < 0 (Bardoscia §3.3.5), fee-vega > 0 (Λ′ > 0, α, u ≥ 0), so the carry leg does offset in sign.
> Consistent with the priors: level programs saturate (β,γ) (corner), J9 discards them for JIT (duration-blind); the σ-profile of carry is the FIRST first-order display that contains them.

\((\beta_j,\gamma_j)\) identification channel: fee-swap price → \(\sigma^{\star}_{\phi}\) (Bichuch–Feinstein Thm 5.1 bijection) → multiFee inversion.

## **G4. [UNDERSPECIFICATION COUNT]**

\[
	\begin{aligned}
		\mathcal{T} \, &= \, \{\partial\pi/\partial p,\; \Gamma_{\varphi},\; \upsilon,\; \theta_{\text{fee}}^{\text{pos}},\; \Delta\theta_{\text{fee}}/\Delta\sigma,\; \partial/\partial \bar L_{(1/2,\,0)},\; \partial/\partial \Delta Q_M,\; \lambda_{\text{FLAIR}},\; \lambda_{\text{ARB}},\; \tilde\lambda_{\text{JIT}}\}, \quad |\mathcal{T}| = 10 \\
		&\quad (\theta_{\text{decay}} \text{ excluded: redundant by Demeterfi EQ 12};\;\; \sigma_{IV}/\sigma_{IV}^{ATM} \text{ excluded: DIAGNOSTIC, G3};\;\; \lambda_{\text{MEV}} \text{ excluded: the } \oplus\text{-sum}) \\
		\#\text{free} \, &= \, \underbrace{\iota,\, \bar L_{(1/2,\,0)}}_{2} \, + \, \underbrace{(\beta_j,\gamma_j)}_{2n} \, + \, \underbrace{T^{\star}}_{1} \, + \, \underbrace{\tau,\, \tau_{\text{JIT}}}_{2} \, + \, \underbrace{\Delta Q_M\text{-schedule}}_{1} \, = \, 6 + 2n
		\qquad (\xi = \xi^{\star},\; \eta = \eta^{\star},\; \Delta_i \text{ venue-quantized},\; (\bar\phi,\alpha,u) \text{ pinned by the level program — M4 caveat applies})
	\end{aligned}
\]

Raw count \(6+2n \geq 10\) **for \(n \geq 2\)** — the deficit is STRUCTURAL (block-triangular matrix), not numeric:

\[
	\begin{aligned}
		\text{shape rows } \{\partial\pi/\partial p, \Gamma_{\varphi}, \upsilon\text{-flatness}\}\;(3) \; &\text{reachable only through } \{\xi,\iota,\eta,\Delta_i,\bar L_{(1/2,\,0)}\} \implies 2 \text{ free for } 3: \; \textbf{deficit } 1 \\
		\text{ladder resolution: } \{\ell(i_K)\}_{i_K} \in \Delta^{\iota-1} \; &\text{vs the pinned-ξ geometric curve (dim } 1\text{)}: \; \textbf{deficit } \iota - 2 \\
		(\beta_j,\gamma_j) \; &\text{cannot close it: their column is } 0 \text{ on every shape row}
	\end{aligned}
\]

> FUTURE MILESTONE (user-declared, NOT executed here): \(\ell(\xi,\iota;\cdot) \rightsquigarrow \ell_{\text{LDF}}(\theta_{\text{LDF}}; i_K)\), \(\sum_{i_K}\ell_{\text{LDF}} = 1\) — bunni-v2.pdf §2.2 (\(l_r = L\cdot LDF_w(r)\)), geometric = §2.2.1 base example; \(\dim\theta_{\text{LDF}} \geq \iota-2\) ⟹ ladder deficit 0. Hazard rows: deficit 0 already (\(\bar\phi,\alpha,u,\tau,\tau_{\text{JIT}},\eta^{\star}\)).

## **G5. [EVM]**

The EXACT row is exact BY THEOREM 30, not by luck: a venue stores \((\texttt{sqrtPriceX96}, L\text{ per tick})\), i.e. the \(\chi_{X/M} = 1/2\) member with a liquidity coefficient — and the half-kernel carrying \(\bar L_{(\chi_{X/M},\epsilon_{X/M})}\) reproduces any member's marginal price and first-order price impact. So the whole \((p_{\varphi}, \frac{\partial p_{\varphi}}{\partial Q_X^{L}})\)-factoring family is on-chain-representable on the EXISTING primitive, with the curve choice entering only through the liquidity written per tick. The scope limits of Theorem 30 carry here verbatim: SECOND-ORDER only (\(\Gamma_{\varphi}\) yes, \(\frac{\partial^2 p_{\varphi}}{\partial (Q_X^{L})^2}\) no), and value functions need integration, not a per-tick read.

\[
	\begin{aligned}
		\text{EXACT on-chain: } & \partial\pi/\partial p\text{-ladder},\; \Gamma_{\varphi}\text{-ladder (sqrtPriceX96, ticks, } L\text{; } p^{3/2} = \text{mulDiv chain)},\; \upsilon = t/2,\; \theta_{\text{fee}} \text{ ex-post (feeGrowthInside, streamia)} \\
		\text{APPROXIMABLE: } & \phi(\sigma)\text{ (expWad logistic)},\; \theta_{\text{decay}} \text{ (expWad+sqrt; sign RESOLVED: negative)},\; \sigma^2(i(t)) \text{ (E2/E5 ledger — see caveat)},\; \frac{\partial \pi}{\partial \bar L_{(1/2,\,0)}} \text{ (relative form exact)} \\
		\text{OFF-CHAIN: } & \text{CEV prices and } \mathbb{P}_{Y_{n,c}\le x} \text{ tails},\; \sigma^{\star}_{\phi} \text{ inversion},\; \frac{\partial C}{\partial \bar L_{(1/2,\,0)}},\; \frac{\partial C}{\partial \Delta Q_M} \text{ model values (lnWad for } \bar v^2\text{; schedule input exact)}
	\end{aligned}
\]

> \(\sigma^2(i(t))\) CAVEAT: v4 has no built-in TWAP, and E2/E5 feed the OFF-chain subgraph reader (events→subgraph→GAMS layer) — so "APPROXIMABLE on-chain" presupposes EITHER an oracle hook OR a NEW on-chain accumulator (sum of squared int24 tick increments, Δt-weighted in seconds). Nothing in today's E-layer delivers \(\sigma^2\) to a contract.

## **G6. [CAVEATS / OPEN]**

1. θ exponent-sign FLAG — **RESOLVED 2026-08-03 (negative)**; G1's θ_decay and the on-chain constant are unblocked.
2. E8(6) \(\eta_L = \eta\) — OPEN; G2's skew law is an η_L statement until it closes.
3. The \(\partial\pi/\partial p, \Gamma_{\varphi}\) ladder displays, the θ split, the \(\Delta\theta_{\text{fee}}/\Delta\sigma\) statics, and the G4 deficit lemmas are UNFORMALIZED — the Aristotle bundle for this section. **G2: OFF-BUNDLE — analytic content (CEV pricing, noncentral χ², implied-vol inversion) beyond Mathlib v4.28.** Every bundled θ_fee statement MUST name which B1 form it formalizes (schedule-level \(\phi\nu_t\) or position-level \(\phi\nu_t\Delta Q_M\)); the two are not interchangeable and a mixed statement is unprovable.
4. Carry-profile objective: per-event (M6b) vs time-integrated (λ_FLAIR) statement — decide before bundling; the M2 hedge claim needs the time-integrated form.
5. 2n sigmoid parameters match ≤ 2n carry-profile moments — re-count if the hazard ladder demands finer σ-resolution.
6. Natenberg local copy is image-only (no text layer); classical displays are anchored to Demeterfi/Bardoscia instead. Lababidi (Greek.fi) contains no Greek formulas — infrastructure reference only.
7. t-SEMANTICS (G1 clause) — the maturity \(T\) (\(\upsilon = T/2\), \(= T^{\star}/2\) at inception) vs calendar \(t\) (\(T^{\star}-t\) in the locked vega): stated, not yet carried into the Lean signatures.


## GAMMA

**Theorem 32 (Gamma is the intrinsic liquidity) *(promoted from Proposition 13 — the number 13 is retired, not reused)*.** The envelope relation \(\frac{\partial^2 \pi}{\partial p^2} = \frac{\partial Q_X^{L}}{\partial p}\) — now PROVED (`deriv_piVal`, via `hasDerivAt_yOf`: the money leg falls at exactly the marginal price, \(dQ_M^L/dQ_X^L = -p_{\varphi}\)) — with Definition 32 gives, for every member,

\[
	\begin{aligned}
		\Gamma_{\varphi} \, &= \, -\tfrac{1}{2}\;\bar L_{(\chi_{X/M},\,\epsilon_{X/M})}\;p_{\varphi}^{-3/2}
	\end{aligned}
\]

**The proportionality to \(\kappa_{\varphi}\) is FALSE as first written, and no proportionality constant exists.** \(\kappa_{\varphi}\) is dimensionless and a function of \(\epsilon_{X/M}\) ALONE (\(\Theta_p\) entry); \(\Gamma_{\varphi}\) carries the dimension of \(\bar L_{(1/2,\,0)}\,p_{\varphi}^{-3/2}\) and its coefficient is the state-dependent field of Theorem 29. The two sit on different axes — \(\bar L_{(\chi,\epsilon)}\) moves with the SHARE, \(\kappa_{\varphi}\) with the SUBSTITUTION parameter — so no scalar relates them. *Formalized* (`PayoffGeometry`, project `68d1b02a`, axiom-clean): `deriv_piVal` (the envelope) + `gamma_eq_ell` (the identity, on the corrected interior guard).

**\(\Theta_{\Gamma_{\varphi}} = \Theta_{\varphi}\), with no proper subset.** Theorem 29's closed form carries BOTH \(\chi_{X/M}\) (through \(2\sqrt{\chi_{X/M}(1-\chi_{X/M})}\)) and \(\epsilon_{X/M}\) (through the exponent and the denominator), so neither parameter can be dropped; \(\Gamma_{\varphi}\) additionally depends on the reserve state whenever \(\epsilon_{X/M} \neq 0\). A separate index would be an alias, not a reduction — none is minted.

## TODO — OPEN register [GAMMA]

1. **The gamma payoff is not yet well-typed.** The drafted \(\pi^{\Gamma_{\varphi}} \equiv \Gamma_{\varphi}\,p_{(\eta,\Delta_i)}(\sigma^2(i(t)))\) feeds a VARIANCE to \(p_{(\eta,\Delta_i)}\), which takes a TICK (Definition 8, Convention 2). Two candidate repairs, both needing a user ruling: (i) it is the gamma leg \(\tfrac12\Gamma_{\varphi}\,p_{\varphi}^2\,\sigma^2(i(t))\), in which case it ALREADY EXISTS as \(\theta_{\text{decay}}\) (G1) and must not be re-minted; (ii) it is a genuinely new object, in which case it needs a well-typed display before any statement consumes it.
2. **The fee conjecture** \(\phi(\sigma^2(i(t))) \approx \big|\Delta\pi^{\Gamma_{\varphi}}/\pi^{\Gamma_{\varphi}}\big|\) is UNTOUCHED and depends on item 1. It is now COMPUTABLE — Theorem 29 supplies the closed form the relative increment needs — but it is not stated, and an \(\approx\) is not a statement class in this document.
3. **The two-axis control question** (move the payoff along the volatility price at fixed \(\Gamma_{\varphi}\), and along \(\Gamma_{\varphi}\) at fixed volatility price) is a RANK condition on the map from the free parameters to \((p_{\text{vol}}, \Gamma_{\varphi})\). Not posed as a statement; if the rank is deficient it is the concrete witness for the G4 shape-row deficit, which \(\Gamma_{\varphi}\) is one of.

## IMPLIED VOLATILTIY


THere is the Kristensen pdf on perpetula options which defines implied volatility \sigma^2_{IV} (t) as a 2\phi \sqrt{\frac{\varphi_{\chi, \epsilon} (\int_{t_0}^t) (some metric of ytrading volume)}{"The AMT_{tick}"}} semes to map to the L_{(\xi, \iota)}(i) but also an integrated quantity over time. W ebn eed to bring the pdf to refs AND brainstomr how to include this to the fraework formally the 2 and sqrt root might be an special case of traidijg ncurve parameters to 1/2. Also the priceOf risk on the plank branch seems to be the entry point for opportunity cost comparsion against fixed income yiled rates (interest rates). Note that there is a section on Krsitensen ion holding an LP vs lending it which might conbnect comparing priceOfRisk against exogenously given interet rates . The ratio VOL / AMT has a firect mapping but myust be proved explicityl to th eutiliation u


## OTHER KRSITENSEN CONNECTIONS

Our maturity T which is endogenously controlled by the specified target vega and controlled by liquiditations needs to be connected to the T_{ITM} /T = \int_{t_O}^{T} \mathbb{P}_{[i_l, i_u]} dt / T as defined on Krsitensen and see what can ew leverage from there
