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

**Definition 2 (Theta).** The **theta** of the call (resp. put) at strike tick \(i_K\) is the per-time-step payoff variation

\[
	\begin{aligned}
		\theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; t) \, , p_{(\eta, \Delta_i)} \, (i_K),  \sigma \, (i (t)) \Big ) \, &\equiv \, \frac{\Delta \pi^{\text{call | put}}}{\Delta\, t }
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

**Rule 1 (Option pricing).** The protocol prices the call (resp. put) at strike tick \(i_K\) as **accumulated theta along the realized tick path**:

\[
	\begin{aligned}
		p_{\pi^{\text{call | put}}}\, (t) \, &\leftarrow \, \int_{t_0}^{t} \, \theta \, \Big (\, p_{(\eta, \Delta_i)} \, (i; s) \, , p_{(\eta, \Delta_i)} \, (i_K),  \sigma \, (i (s)) \Big ) \, \mathcal{d}\, s
	\end{aligned}
\]

The left arrow marks a Rule, not an identity: this is a stipulation of the protocol, and the implementation either complies with it or does not.

*Formalized:* `Panoptic.streamingPremium` (the discrete accumulation \(\sum_j \theta_j\,\Delta t\)); `streamingPremium_succ`.


> RESOLVED (user ruling, 2026-08-03): exponent sign is **NEGATIVE**. Two-part justification: (i) with the display's own prefactor \(p(\cdot)\sigma/\sqrt{8\pi t}\), the bracket is \(-\sigma\sqrt{t}\,d_2\), so the negative sign gives \(e^{-d_2^2/2} \propto \varphi(d_2)\) — exactly the \(r=0\) Black–Scholes dt-leg \(\theta = S\sigma\varphi(d_1)/(2\sqrt t)\) via \(S\varphi(d_1)=K\varphi(d_2)\); (ii) DECISIVE and internal: \(p_{\pi^{\text{call|put}}} \leftarrow \int\theta\) over the price grid CONVERGES only with the negative sign (Gaussian tails) — under \(+\) the assignment defining the option prices diverges. The ATM form cannot discriminate (`theta_atm_closed_form`, exponent vanishes ATM); the tails do.

**Definition 4 (Upsilon).** The **upsilon** of a premium or payoff functional at strike tick \(i_K\) is its per-unit-variance sensitivity, as a lattice finite difference in the variance argument:

\[
	\begin{aligned}
		\upsilon \, \Big (p_{(\eta, \Delta_i)} \, (i; t) \, , p_{(\eta, \Delta_i)} \, (i_K)\Big)\, &\equiv \, \frac{\Delta \pi^{\text{call | put}}}{\Delta \sigma^2 \, (\cdot)}
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

**Definition 5 (Replicating portfolio).** The **replicating portfolio** \(\Pi^{\text{call|put}}(\sigma; p_{(\eta,\Delta_i)}(i;t))\) is the option portfolio whose sensitivity to realized variance is independent of the underlying price [PG7](../refs/DemeterfietalVarianceSwaps.pdf) — a single option cannot serve, since a price move alters its variance sensitivity.

**Convention 1 (Replication relation).** For payoff claims \(A, B\) we write \(A \equiv^{R} B\) — "\(A\) **is replicated by** \(B\)" — when \(B\)'s payoff reproduces \(A\)'s. This is a *claim about two objects*, not a definitional identity: each instance must be proved, and until it is, it is stated OPEN. (This is the relation the two-instrument question above is posed in.)

**Definition 6 (Log portfolio).** For \(p^{\star}\) the approximate at-the-money forward level marking the boundary between liquid puts and liquid calls [PG9](../refs/DemeterfietalVarianceSwaps.pdf), the **log portfolio** and its running form are

\[
	\begin{aligned}
		\Pi^{\text{call|put}}\big(\sigma; p_{(\eta,\Delta_i)}(i;t)\big) \, &= \, \frac{p_{(\eta,\Delta_i)}(i;t) - p^{\star}}{p^{\star}} \, - \, \log\Big(\frac{p_{(\eta,\Delta_i)}(i;t)}{p^{\star}}\Big) \, + \, \frac{\sigma^2(i(t))\, t}{2}
	\end{aligned}
\]

(at \(t=0\) the running term vanishes; \(\Pi \geq 0\) with \(\Pi(p^{\star}) = 0\)). Its **unit-vega normalized form** (Theorem 3's \(\text{Id}_{N_\sigma}\)), with the remaining-variance tail:

\[
	\begin{aligned}
		\Pi^{\text{call | put}} \, (\sigma ;p_{(\eta, \Delta_i)} \, (i; t); T) \, &= \, \text{Id}_{ N_{\sigma}} \Big [\frac{p_{(\eta, \Delta_i)} - p^{\star}}{p^{\star}} \, - \, \log (\frac{p_{(\eta, \Delta_i)}}{p^{\star}})\Big] \, + \, \frac{T - t}{T}\, \sigma^2(i(t))
	\end{aligned}
\]

*Formalized:* `VolInstrument.logPortfolio`; `variancePortfolio` (\(= \text{logPortfolio} + \sigma^2(i(t))\, t/2\)); `logPortfolio_nonneg`; `logPortfolio_atm`.

**Settlement instantiation** (Convention 2): \(\Pi^{\text{call|put}}\big(\sigma^2(i(T));\, p_{(\eta,\Delta_i)}(i;t);\, T\big) \, = \, \text{Id}_{ N_{\sigma}} \Big [\frac{p_{(\eta, \Delta_i)} - p^{\star}}{p^{\star}} \, - \, \log (\frac{p_{(\eta, \Delta_i)}}{p^{\star}})\Big] \, + \, \frac{T - t}{T}\, \sigma^2(i(t))\).

**Proposition 4 (Ladder replication).** The volatility option is replicated by the log portfolio:

\[
	\begin{aligned}
		\pi^{\sigma}(t) \, \equiv^{R} \, \Pi^{\text{call|put}}\big(\sigma; p_{(\eta,\Delta_i)}(i;t)\big)
	\end{aligned}
\]

and \(\Pi\) has Definition 5's defining property: its variance sensitivity is **constant in the underlying price**, \(\upsilon(\Pi) = T/2\).

*Status:* the \(\equiv^R\) core is **adapted from the variance-swap text** [Demeterfi](../refs/DemeterfietalVarianceSwaps.pdf) and is **OPEN in-tree** — Convention 1's discipline applies. PROVED: the sensitivity half. OWED: the payoff-reproduction step connecting `variancePortfolio` to `volOptionPayoff` — an Aristotle target.

*Formalized (sensitivity half):* `variancePortfolio_upsilon` (\(\upsilon = t/2\), \(p_{(\eta,\Delta_i)}\)-independent).

**Rule 3 (Ladder allocation).** The protocol realizes the log portfolio on the grid as the strike ladder — the weight profile \(\ell(\xi^{\star},\iota;i_K)\) being a geometric liquidity distribution in the sense of the [Bunni v2 whitepaper](../refs/bunni-v2.pdf) (whose general LDFs \(\ell_{\text{LDF}}(\theta_{\text{LDF}};i_K)\) are the declared FUTURE MILESTONE, G4):

\[
	\begin{aligned}
		\Pi^{\text{call|put}}\big(\sigma; p_{(\eta,\Delta_i)}(i;t)\big) \, \leftarrow \, \sum_{i_K} L(i_K)\, \Pi^{\text{call|put}}\big(\sigma_K; p_{(\eta,\Delta_i)}(i;t)\big), \qquad L(i_K) = \bar L\,\ell(\xi^{\star},\iota; i_K)
	\end{aligned}
\]

The left arrow marks the Rule: an **allocation the protocol enforces**, not an equality — \(\Pi^{\text{call|put}}(\sigma_K;\cdot)\) is the per-strike member at strike tick \(i_K\), and \(L\) is Definition 7's ladder. Whether the enforced ladder's payoff reproduces the log contract is part of Proposition 4's OPEN core, not asserted here.

*Formalized (weight law):* `GeomProfile.varswapWeight_geometric`; `logContractLiquidity_geometric`; `VolInstrument.strikeWeight_bridge` (\(\xi^{\star} = \lambda^{-\Delta_i/2}\)).

**Definition 7 (Liquidity ladder).** Per strike tick \(i_K\), the ladder allocates the total liquidity \(\bar L\) by the geometric weight profile

\[
	\begin{aligned}
		L \, (i_K) \, &= \, \bar L \, \ell \, (\xi, \iota; i_K), \qquad \bar L \, = \sum_{i_K = i_{\text{min}}}^{i_{\text{max}}} \, L \, (i_K), \qquad \ell \, (\xi, \iota; i_K) \, = \, \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)}
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
		\frac{\Delta \pi^{\text{call | put}}}{\Delta \, \sigma} \, &\approx \frac{\Delta \theta}{\Delta \sigma}
	\end{aligned}
\]

inheriting the sign of \(\ln \big(p_{(\eta, \Delta_i)}(i;t) / p_{(\eta, \Delta_i)}(i_K)\big)\) — a single option cannot carry Definition 5's price-independence, which is why the ladder exists.

*Status:* **OPEN** — pinned in-tree as `Upsilon.ATMOTMNullHypothesis`, a Prop **conjecture, no proof, no axiom**. One correction is machine-recorded and travels with it: the naive strike-centered envelope \(e^{-c|i-i_K|}\) is **FALSE on the entire left branch for every** \(c > 0\) (the forward difference is right-shifted; a parameter-independent obstruction) — the honest envelope is centered on the peak pair \(\{i_K{-}1, i_K\}\). The conjecture's originally named test avenue (the econometric track) is CLOSED-terminal, so it either gets a formal proof or stays open.

**Theorem 3 (Unit vega).**

\[
	\begin{aligned}
		\frac{\Delta \, \Pi^{\text{call | put}} \, ( \cdot )}{\Delta \, \sigma^{2} } N_{\sigma} \, &= \, T/2 \, N_{\sigma} \, \implies \text{Id}_{ N_{\sigma}} \, \equiv \frac{2}{T}
	\end{aligned}
\]

*Formalized:* `VolInstrument.variancePortfolio_unit_upsilon`.

**Rule 4 (Position ledger).** The protocol books a position as its **net signed liquidity** per strike: each leg carries the direction sign \(\mathbb{I}_{\text{long|short}}\), and the ladder's ledger is

\[
	\begin{aligned}
		\pi^{\sigma} \, (\sigma_K, T; t) \, &\leftarrow \sum_{i_K} \, L(i_K) \, \mathbb{I}_{\text{long|short}}, \qquad \mathbb{I}_{\text{long|short}} \, \equiv \,
		\begin{cases}
		- \, 1 & \, \text{long (liquidity removed — burn)} \\
		1 \, & \, \text{short (liquidity minted)}
		\end{cases}
	\end{aligned}
\]

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

*Status:* the sampling half is **proved** — \(K^{-1/2}\) on the grid is geometric with ratio \(\lambda^{-\Delta_i/2}\) (`logContractLiquidity_geometric`). The replication premise — \(\ell(K) \propto K^{-1/2}\) from the curvature relation \(\ell(P) = -2P^{3/2}V''(P)\), \(V''(P) = -1/P^2\), adapted from [VOL_SWAPS](../refs/DemeterfietalVarianceSwaps.pdf) — is **OPEN** in-tree (the payoff-level curvature bridge is future work).

*Formalized (sampling half):* `GeomProfile.logContractLiquidity_geometric`; bridge to the ladder weights: `VolInstrument.strikeWeight_bridge`.

# TRADING_REGION

**Definition 9 (Per-strike amounts).** On the underlying market \((X, M)\), the liquidity \(L(i_K)\) at strike tick \(i_K\) holds the per-strike token amounts

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
		\Delta Q_M^{L}(i_K) \, = \, L(i_K)\Big[\frac{1}{p_{(\eta, \Delta_i)}(i_K)} - \frac{1}{p_{(\eta, \Delta_i)}(i_K+\Delta_i)}\Big]
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

**Theorem 6 (Monotonicity and telescoping).** Both cumulatives are monotone in the step count (for \(L \geq 0\)), so the inverse cumulatives of Definition 11 are well-defined least attaining steps; for the constant ladder \(L \equiv \bar L\) they telescope to closed form:

\[
	\begin{aligned}
		Q_X^L \, = \, \bar L\,\big[p_{(\eta, \Delta_i)}(i_{\min}+n\Delta_i) - p_{(\eta, \Delta_i)}(i_{\min})\big], \qquad
		Q_M^L \, = \, \bar L\,\Big[\frac{1}{p_{(\eta, \Delta_i)}(i_{\min})} - \frac{1}{p_{(\eta, \Delta_i)}(i_{\min}+n\Delta_i)}\Big]
	\end{aligned}
\]

*Formalized:* `VolInstrument.cumulativeQM_monotone`; `cumulativeQX_monotone`; `cumulativeQM_const`; `cumulativeQX_const`; `exists_least_reaching`.

**Notation map (Bunni v2 remap — collision-driven).** [BUNNI_V2](../refs/bunni-v2.pdf)'s symbols do not enter this document because \(a_0, a_1\) collide with the replication weights \(a_1, a_2\) (Settlement form of Definition 1). The remap: \(a_0 \mapsto \Delta Q_M^L\), \(a_1 \mapsto \Delta Q_X^L\), \(A_0 \mapsto Q_M^L\), \(A_1 \mapsto Q_X^L\), \(A_0^{-1} \mapsto Q_M^L(\cdot)^{-1}\), \(A_1^{-1} \mapsto Q_X^L(\cdot)^{-1}\), \(w \mapsto \Delta_i\), \(r \mapsto i_K\), \(l_r \mapsto L(i_K)\), \(1.0001 \mapsto \lambda\) (\(\mathcal{C}_p\)). Structural identification: Definition 7's weight profile \(\ell\) **is** Bunni's geometric LDF \(d_{\alpha,l}\) (§2.2.1, eq. (9)) under \(\alpha \mapsto \xi\), \(l \mapsto \iota\), and Definition 7's \(L(i_K) = \bar L\,\ell(\cdot)\) is his \(l_r = L \cdot LDF_w(r)\) (eq. (5)). <!-- notation-map -->

**Definition 12 (Weighted-geometric-mean trading function).** For share parameter \(\chi_{X/M} \in (0,1)\), the **trading function** at strike tick \(i_K\) takes as exogenous a trading flow \(\Delta Q = (\Delta Q_M, \Delta Q_X)\) and returns

\[
	\begin{aligned}
		\varphi_{(\chi_{X/M},\,0)} \, (i_K ; \Delta Q , L)\, &\equiv \, \big(\Delta Q_M^{L} (i_K) + \Delta Q_M\big)^{\chi_{X/M}}\cdot\big(\Delta Q_X^L \, (i_K) \, + \, \Delta Q_X\big)^{1-\chi_{X/M}}
	\end{aligned}
\]

The flow is **exogenous** — trade legs arriving against the endowed per-strike amounts of Definition 9: the endowments are the state, the flow is the input. It is a **trading function** in the sense of [CFMM_GEOMETRY](../refs/cfmm/angeris-geometry_of_cfmms-2023.pdf), already in canonical form (nondecreasing, concave, homogeneous); its logarithm is the weighted logarithmic utility of [AMM_AXIOMS](../refs/cfmm/bichuch_feinstein-axioms_for_amms-2022.pdf) App. B.2 (their weight \(w \mapsto \chi_{X/M}\) — \(w\) collides with the order width \(w \in \mathcal{I}_{\text{ord}}\)), evaluated on per-strike **virtual reserves** in the sense of their App. B.3 (\(\alpha, \beta \mapsto \Delta Q_M^L(i_K), \Delta Q_X^L(i_K)\)). <!-- notation-map -->

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

**Definition 14 (Curvature).** The **curvature** \(\kappa_{\varphi}\) of a trading function is the price-impact elasticity of its marginal price along the trading curve, normalized against the constant-product member: with marginal price \(p = \partial_{Q_X}\varphi \,/\, \partial_{Q_M}\varphi\) and

\[
	\begin{aligned}
		\epsilon_{p/X} \, \equiv \, \frac{d \ln p}{d \ln Q_X}\Big|_{\varphi = \text{const}}, \qquad
		\kappa_{\varphi} \, \equiv \, \frac{|\epsilon_{p/X}|}{|\epsilon_{p/X}| + |\epsilon_{p/X}^{\,0}|}
	\end{aligned}
\]

where \(\epsilon_{p/X}^{\,0}\) is the same elasticity for the \(\epsilon_{X/M} = 0\) (constant-product) member at the same point. \(\epsilon_{p/X}\) is an **observable** of any member of the trading-function class (Definition 12), not a parameter: the second derivative of \(\varphi\) enters through it (the derivative of the marginal price), and the benchmark normalization makes \(\kappa_{\varphi}\) scale-free, with the constant-product pool at \(\kappa_{\varphi} = 1/2\). Notation binding: \(\kappa_{\varphi}\) names the **genuine** curvature (\(\varphi\) the quote function, never the fee \(\phi\)); the share-asymmetry index \(\varsigma_{X/M}\) is NOT a curvature. <!-- notation-map -->

*Formalized:* the definitional layer is **UNFORMALIZED** — the in-tree `CurvatureTwo.curvTwo` is the closed form of Proposition 7 by fiat, not this definition.

**Proposition 7 (CES curvature closed form).** For the CES family (Definition 13), at the balanced point \(|\epsilon_{p/X}| = \dfrac{1-\epsilon_{X/M}}{1-\chi_{X/M}}\), and

\[
	\begin{aligned}
		\kappa_{\varphi}(\epsilon_{X/M}) \, = \, \frac{1 - \epsilon_{X/M}}{2 - \epsilon_{X/M}} \, \in \, [0,1), \qquad
		\epsilon_{X/M}(\kappa_{\varphi}) \, = \, \frac{1 - 2\kappa_{\varphi}}{1 - \kappa_{\varphi}}
	\end{aligned}
\]

— the \(\chi_{X/M}\)-dependence cancels identically: \(\kappa_{\varphi}\) is a function of the SUBSTITUTION axis alone (equivalently \(\kappa_{\varphi} = 1/(1+\bar\epsilon_{X/M})\)). The inverse is the DESIGN DIAL — choose a target curvature, read off the substitution exponent. *Status:* **OPEN in-tree** — Aristotle target: (i) the elasticity computation \(|\epsilon_{p/X}| = (1-\epsilon_{X/M})/(1-\chi_{X/M})\), (ii) the normalization identity.

**Theorem 8 (Properties of the closed form).** The closed form is zero exactly at the linear member (\(\epsilon_{X/M} = 1\)), strictly positive below it, strictly decreasing in \(\epsilon_{X/M}\), with range \([0,1)\); \(\chi_{X/M}\) and \(\Delta_i\) do NOT enter it; both round trips with the inverse hold.

*Formalized:* `CurvatureTwo.curvTwo`; `curvTwo_linear_zero`; `curvTwo_pos_of_lt_one`; `curvTwo_strictAnti_rho`; `curvTwo_mem_Ico`; `rhoOfCurv` (both round trips); \(\bar\epsilon_{X/M}\) = `subElast` (`subElast_zero`, `subElast_tendsto_one`).

**Refutation note (what curvature is NOT).** The Gaussian curvature of \(\varphi\)'s graph is **identically zero** for every member — 1-homogeneity forces \(\mathrm{Hess}\,\varphi \cdot (Q_X,Q_M)^{\top} = 0\), so \(\det \mathrm{Hess} \equiv 0\) and the graph is a ruled surface; the Gaussian reading cannot distinguish linear from Leontief. The un-normalized planar curvature of the trading curve is scale-dependent (\((1-\epsilon_{X/M})/(\sqrt{2}\,t)\) at the symmetric point \(Q_X = Q_M = t\), \(\chi_{X/M} = 1/2\)) and cannot equal a constant. The normalization of Definition 14 is what makes Proposition 7 well-posed. *Status:* unformalized (cheap machine-check; rider on the Proposition 7 Aristotle bundle).

**Definition 15 (Share asymmetry).** The **share asymmetry** (grid tilt) of the trading-function family is

\[
	\begin{aligned}
		\varsigma_{X/M} \, \equiv \, 1 - \Big(\frac{1-\chi_{X/M}}{\chi_{X/M}}\Big)^{\Delta_i}
	\end{aligned}
\]

zero exactly at \(\chi_{X/M} = 1/2\). It is a **derived observable** — a function of the registered parameters \(\chi_{X/M} \in \Theta_{\varphi}\) and \(\Delta_i \in \Theta_p\), adding no degree of freedom; hence no registry entry.

*Formalized:* `EtaTilde.curvOfTilde` / `EtaCurvature.curvIndex`. *(Lean names predate the doc symbols and are NOT renamed — standing doc-glyph/Lean-name split.)* <!-- notation-map -->

**Theorem 9 (\(\varsigma_{X/M}\) is not a curvature).** At equal shares \(\varsigma_{X/M}\) vanishes both at the constant-product member and at the linear member — although the former has \(\kappa_{\varphi} = 1/2 > 0\) (Proposition 7) and only the latter is flat. So \(\varsigma_{X/M}\) measures SHARE asymmetry (the grid-price tilt), not curvature across the substitution axis. Blocks E1–E7 are theorems about \(\varsigma_{X/M}\): their mathematics stands; their reading is about SHARE, not curvature.

*Formalized:* `curvOfTilde_not_curvature` (the machine-checked discriminating witness); \(\varsigma_{X/M}\) factors through the share alone: `curvIndex_is_rho_zero_slice`.

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

*Formalized:* `curvOfTilde_strictMono` (the true direction); **REFUTED:** `not_curvOfTilde_strictAnti` — machine-checked negation of the antitone reading, witness above. *(Retitled from the in-doc "Lemma (Curvature–Share Monotonicity)": "Lemma" is not a taxonomy class, and per Theorem 9 \(\varsigma_{X/M}\) is share asymmetry, not curvature.)*

CONSEQUENCE FOR E8(6): the factor-share reading was recorded UNAVAILABLE because \(\eta^{\star} \approx 458/\Delta_i^{2}\) cannot be a Cobb–Douglas share. It never had to be — the share is \(\chi_{X/M}(\eta^{\star}) \in (0,1)\) for EVERY \(\eta\) (Theorem 10), so the identification is reachable through \(\chi_{X/M}\), not through \(\eta\) directly. *Carriers:* `etaStar_tilde_mem_Ioo`, `curvIndex_etaStar_via_tilde`. *(E-block cross-note; converts when the E-blocks are swept.)*

> Provenance: `EtaTilde` 23/23 axiom-clean, project `67b1c841` (doc \(\chi_{X/M}\) ↔ Lean `etaTilde`, the Lean name fixed by the bundle and never hand-edited); `PhiCES` 12/12 axiom-clean, project `cd3558f7`. Carriers not yet attached to a numbered statement: `phiCES_agreement_point` (evaluation form, scope declared in-file); CONDITIONAL, NOT an identification: `phiCES_rho_vs_pi_eta_trader` gives \(1/(1-\epsilon_{X/M}) = 1/(1-\eta) \iff \epsilon_{X/M} = \eta\) away from the poles for `exp/CESLongVolPayoff`'s η, and its docstring states outright that this does NOT identify the payoff parameter with the trading-function parameter — E8(6) untouched.

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

\(\mathcal{G}_{\phi}\) is an **Abelian monoid** — identity \(\phi = 0\), no inverses (a charged fee cannot be un-charged) — **not a group, and \(\otimes_{\phi}\) is a composition law, not an inner product** (correcting the note's original wording). The monoid axioms are machine-proved — Theorem 14 (`probOr_comm`, `probOr_assoc`, `probOr_zero`, closure `probOr_mem_Icc`). The carrier is \([0,1]\) as proved; the boundary \(\phi = 1\) (full confiscation) is admitted by the algebra and excluded economically by Rule 6's domain \(\phi_{\bullet} \in (0,1)\).

**Rule 7 (Trader-paid fee).** The protocol composes the leg fees into the trader-paid fee by the monoid law:

\[
	\begin{aligned}
		\phi \, \leftarrow \, \phi_M \otimes_{\phi} \phi_X
	\end{aligned}
\]

This is the M9 **DECIDED** entry (see the M9–M10 blocks below; their \(\tau_{\text{MEV}}\)-entry theorems attach here when that material is converted — hazards and hazard controls are not yet introduced at this point in the document).

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

**Theorem 1 (Fee Envelope).** Writing \(u = \alpha_R\Big/\Big(1+\exp\Big(\gamma_R\Big(\beta_R - \frac{\varphi_{(1/2,\,0)}(i_K;\Delta Q,0;t)}{\varphi_{(1/2,\,0)}(i_K;0,L;t)}\Big)\Big)\Big)\) — the utilization gate of Definition 18:
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

## VOL ORDER COMPLETION — ENDOGENOUS MATURITY

# PROTOCOL_INPUTS

Every **Protocol Input** is a quantity supplied by the USER, per order, at interaction time — the third registry class. The classifying test across the three registries is *who sets it, and when*: a Protocol Constant (\(\mathcal{C}_p\)) is fixed by the design once and forever; a Protocol Parameter (\(\Theta_{\bullet}\)) is set by the protocol, uniformly for all users; a Protocol Input is chosen by the user for each interaction. Input entries carry a *Carrier* line — inputs are calldata, and the on-chain field is part of their definition. The input set of the **vol order** (retiring the former \(\Theta_{\text{ord}}\) symbol: inputs are not parameters, so the index letter changes):

\[
	\mathcal{I}_{\text{ord}} \,=\, \{\sigma^2_K,\, w,\, s\}
\]

(strike, width, skew) pins only the scale-free leg shape \(\ell\,(\xi, \iota; i_K)\).

**Rule 8 (Target-vega completion — DECIDED, 2026-07-30).** The order is completed with the target vega:

\[
	\mathcal{I}_{\text{ord}} \,\leftarrow\, \mathcal{I}_{\text{ord}} \,\cup\, \{\Delta Q_v^{\star}\}
\]

**Protocol Input (\(\mathcal{I}_{\text{ord}} = \{\sigma^2_K, w, s, \Delta Q_v^{\star}\}\) — the vol order).**

- \(\sigma^2_K\) — the **strike variance**.
  *Domain:* a variance level (Convention 2: \(\sigma^2(i_K) \equiv \sigma^2_K\)); on-chain packing per `VolOrderValidationLib`.
  *Purpose:* the strike of the volatility option (Definition 1).
  *Economic meaning:* the variance level above which the option pays.
  *Carrier:* `create_order(strike, …)`.

- \(w\) — the **width**.
  *Domain:* the packed order field (validation predicate in `VolOrderValidationLib`).
  *Purpose:* with \(s\), pins the scale-free leg shape \(\ell(\xi,\iota;i_K)\).
  *Economic meaning:* the strike-band width of the replication ladder.
  *Carrier:* `create_order(…, width, …)`. (This \(w\) is the collision target of the [AMM_AXIOMS](../refs/cfmm/bichuch_feinstein-axioms_for_amms-2022.pdf) remap — Definition 12.)

- \(s\) — the **skew**.
  *Domain:* the packed order field (validation predicate in `VolOrderValidationLib`).
  *Purpose:* with \(w\), pins the leg shape.
  *Economic meaning:* the asymmetry of the ladder around the strike.
  *Carrier:* `create_order(…, skew, …)`.

- \(\Delta Q_v^{\star}\) — the **target vega** (enters by Rule 8).
  *Domain:* `u96`, RAW LIQUIDITY units — \(\Delta Q_v^{\star}\) carries the dimension of the replication carrier \(L\) (the DECIDED dimension ruling below).
  *Purpose:* sizes the ladder and induces the implied maturity (Theorem 13).
  *Economic meaning:* the vega notional the user targets — the one sizing decision the order stores.
  *Carrier:* `targetVega : u96` at bits 152..247 of the packed `VolOrder` word (plank `feat/plank`); `targetVega` \(= \Delta Q_v^{\star}\) exactly; emitted by `VolOrderCreated(orderId, strike, width, skew, targetVega)`; fits-packed predicate in `VolOrderValidationLib`.

**Theorem 13 (Maturity equivalence).** From \(\upsilon = T/2\) (`variancePortfolio_upsilon`) and \(\text{Id}_{N_\sigma} = 2/T\) (`variancePortfolio_unit_upsilon`):

\[
	T^{\star} \,=\, 2\,\frac{\Delta Q_v^{\star}}{N_\sigma} \quad\Longleftrightarrow\quad \Delta Q_v^{\star} \,=\, \frac{T^{\star}}{2}\, N_\sigma
\]

with \(\Delta Q_v^{\star}, N_\sigma > 0 \implies T^{\star} > 0\), and \(T^{\star}\) strictly increasing in \(\Delta Q_v^{\star}\), strictly decreasing in \(N_\sigma\). The perpetual order specifies no \(T\); \(T^{\star}\) is the implied maturity of the equivalent dated variance contract — derived from \(\Delta Q_v^{\star}\), never stored.

*Formalized* (`EndogenousMaturity.lean`; \(N_\sigma \neq 0\)): bijection `dQvStarOfMaturity_tStar` / `tStar_dQvStarOfMaturity` / `maturity_equivalence`; vega-exactness `tStar_variancePortfolio_upsilon`, `tStar_unit_upsilon`; `tStar_pos`; `tStar_strictMono_dQvStar`; `tStar_strictAnti_Nσ`.

**Convention 3 (Vega dimension — stored target vs lens readout; DECIDED 2026-07-30).** \(\Delta Q_v^{\star}\) carries the dimension of the REPLICATION CARRIER — liquidity \(L\), the quantity of the priced vol asset, per Rule 4's ledger

\[
	\pi^{\sigma} \, = \sum_{i_K} \, L(i_K) \, \mathbb{I}_{\text{long|short}}
\]

The quotient \(\Delta Q_v \equiv \Delta\pi^{\sigma}/\Delta(\sigma^2-\sigma^2_K)^{+}\) (collateral per vol unit, Definition 1) is the LENS READOUT — computed from a position through the \(Q_M^L\) range conversion (Definition 10), never stored. One instrument, two views: the \(\mathcal{I}_{\text{ord}}\) entry names the **stored quantity**, Definition 1's quotient names the **measured sensitivity**.

**Rule 9 (Sizing — quantity-exact, no price in the map).** The mint sizes the ladder from the target vega alone:

\[
	L(i_K) \,\leftarrow\, \Delta Q_v^{\star}\,\ell\,(\xi^{\star}, \iota; i_K), \qquad \sum_{i_K} L(i_K) \,=\, \Delta Q_v^{\star} \;\; \big(\textstyle\sum_{i_K}\ell = 1,\ \text{Theorem 2}\big)
\]

\(p_{\text{vol}}, p_{\text{risk}}\) enter at the ISSUANCE/ADMISSIBILITY layer (shares, deleverage — Rule 10), never the sizing map; the mint's collateral requirement is the actual replication cost, slippage-bounded.

**Proposition 8 (The lens obligation).** Delivered quantity recovers the stored target, one-sided under per-leg floor rounding:

\[
	\sum_{i_K} L(i_K) \,\leq\, \Delta Q_v^{\star}
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

**MEV is struck from the index set** (correcting the note's original listing, per Convention 4): \(\tilde\lambda_{\text{MEV}}\) is an incidence operator, not a hazard — its entry into the trader-paid fee goes through the \(\otimes_{\phi}\) monoid (Rule 7, the M9 route), never through \(\bigoplus\). The second line is the per-leg split, mirroring the leg fees of Rule 6.

**Theorem 14 (Fee monoid and hazard exactness).** \(\mathcal{G}_{\phi} = \big([0,1],\, \otimes_{\phi},\, 0\big)\) is an Abelian monoid — commutative, associative, identity \(0\), closed on \([0,1]\), monotone — and the hazard correspondence is **exact** under \(\phi = 1 - e^{-\lambda}\):

\[
	\begin{aligned}
		\big(1-e^{-\lambda_M}\big) \otimes_{\phi} \big(1-e^{-\lambda_X}\big) \, = \, 1-e^{-(\lambda_M+\lambda_X)}
		\quad\Longleftrightarrow\quad \lambda \, \equiv \, \lambda_M + \lambda_X
	\end{aligned}
\]

Definition 19's \(\bigoplus\)-is-addition is exactly this exactness: fee composition and hazard addition are the same law in two coordinate systems.

*Formalized:* `VolInstrument.probOr_eq`; `probOr_comm`; `probOr_assoc`; `probOr_zero`; `probOr_mem_Icc`; `probOr_mono`; `probOr_hazard`.

### FLAIR

Define:

\[
	\begin{aligned}
		\lambda_{\text{FLAIR}}\, (t) \, &\equiv \, \displaystyle\int_{t_0}^t \frac{\displaystyle\int_{p_{(\cdot) \,(t)}} \, \phi \, ( \sigma \, (i (t));t) \, d\, p_{(\cdot)} \,(t)}{p_{(\cdot)} \,(t)\, Q_M^L \Big (\sum_{j}^{\# \text{LP}} \, L_j \, (i(t); \cdot)\Big ) \, +\,  Q_M^L \Big(\sum_{j}^{\# \text{LP}} \, L_j \, (i(t); \cdot)\Big) } \, dt
	\end{aligned}
\]


\[
	\begin{aligned}
		\exists \, \Theta_{\lambda_{\text{FLAIR}}} \, \subset \, \Theta_{\phi} \, \quad \, \sup_{\Theta_{\lambda_{\text{FLAIR}}}} \, \lambda_{\text{FLAIR}}\, (t)
	\end{aligned}
	
\]


> LEAN (proved — the claim above is now identified AND solved): discretizing with flow weights \(w_t \geq 0\) and capital \(D_t > 0\):

\[
	\begin{aligned}
		\lambda_{\text{FLAIR}} \, = \, \bar\phi\, W \, + \, u \sum_j \alpha_j\, W_j, \qquad
		W = \sum_t \frac{w_t}{D_t}, \quad
		W_j = \sum_t \frac{\Lambda\big(\gamma_j(\sigma_t-\beta_j)\big)\, w_t}{D_t}, \quad 0 \leq W_j < W
	\end{aligned}
\]

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{FLAIR}}} \, = \, \{\bar\phi,\, \alpha,\, u(\alpha_R)\}: \qquad
		\lambda_{\text{FLAIR}} \, \leq \, \Big(\bar\phi_{\max} + u_{\max}\sum_j \alpha_{j,\max}\Big)\, W
	\end{aligned}
\]

attained bang-bang at the level corner for any fixed \((\beta,\gamma)\); in \((\beta,\gamma)\) the bound is approached only as \(\beta \to -\infty\) (strict gap at every finite \(\beta\): the sup over unbounded shape parameters is a saturation boundary, not a maximum).

> Caveat: this functional has no demand elasticity — the fee–volume trade-off lives in the optimal-fee layer (`FeeSchedule`, arXiv:2508.08152).
> `FlairOptimization.flairMulti_affine`, `W_j_lt_W`, `flairMulti_le_corner`, `flairMulti_corner_attained_levels`, `flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`, `Theta_lambda_identification`.

### MEV

- Angstrom holds the reference for an implementation 
- Literature that helps on tracking a \(\lambda_{\text{MEV}}\) (My=ust be saved on refs/{flair, mev}/ **.pdf) and then once acquired we can do \(\Theta_{\lambda_{\text{MEV}}}\)

## **M0. [NOTATION]**

The paper's fee symbol `γ` is transcribed as this document's fee `φ`; this document's `γ_j` stays the sigmoid steepness. <!-- notation-map -->
The paper's Poisson block rate `λ` is transcribed through its own primitive `Δt ≜ λ⁻¹`, because this document's `λ` is the hazard rate. <!-- notation-map -->
The paper's composite parameter `η ≜ γ√(2λ)/σ` is deliberately never named, since `η` is reserved project-wide for the pricing kernel. <!-- notation-map -->
Probability convention (user, 2026-07-31): probabilities are \(\mathbb{P}_{\text{event}}\) — \(\mathbb{P}_{\Delta_{\text{ARB}}}\) = arbitrage-trade probability (the paper's `P_trade`; Lean `MevOptimization.ptrade`), \(\mathbb{P}_{L_{\text{JIT}}}\) = JIT-arrival probability (CJZ's `π`; Lean `πJ`). <!-- notation-map -->
Root-block-rate factor: \(\sqrt{2/\Delta t}\) throughout, no composite abbreviation. Fee \(= \phi\) (ceiling \(\bar\phi\), set \(\Theta_{\phi}\)); the quote function is \(\varphi_{\chi_{X/M},\,\epsilon_{X/M}}\) (CES; \(\chi_{X/M}\) = share axis, \(\epsilon_{X/M}\) = substitution axis), currently \(\varphi_{1/2,\,0}\); bare \(\varphi\) is NOT used.

\(\Delta t\): mean interblock time (Angstrom: 1 bundle/block/pair ⟹ batch cadence \(= \Delta t\)).
\(\sigma_t = \sigma(i(t))\): enters BOTH the fee and \(\mathbb{P}_{\Delta_{\text{ARB}}}\).
\(a_t \geq 0\): PER-STEP arb-opportunity weight \(= \text{LVR rate}\cdot\Delta t\) (M3(i)); \(w_t\) (FLAIR) is per-step traded amount — commensurable.
\(D_t > 0\): the SAME capital denominator as \(\lambda_{\text{FLAIR}}\).

\(\lambda_{\text{ARB}}\) (M3, blocks M3–M6b) \(\subsetneq \lambda_{\text{MEV}}\) (M7): SUMMAND, not sibling — index set carries one, never both (double-count). \(\lambda_{\text{ARB}}\) absorbs the "arb toxicity" entry. Paper's `FEE` \(\subsetneq \lambda_{\text{FLAIR}}\) (noise flow excluded there).

Standing hypotheses: paper's Assumption 2 (symmetric driftless mispricing, two-sided fee; non-symmetric variant App. C); M2 additionally: regularity (13), (15).

## **M1. [ADDITION] The trade probability**

\[
	\begin{aligned}
		\mathbb{P}_{\Delta_{\text{ARB}}}(\phi,\sigma,\Delta t) \, = \, \frac{\sigma}{\sigma + \phi\sqrt{2/\Delta t}}
	\end{aligned}
\]

MMR Thm 1 (§4.1, Assumption 2): long-run fraction of blocks with profitable arb; bonding-function-independent — only the fee enters.

- \(\mathbb{P}_{\Delta_{\text{ARB}}} \in (0,1]\)
- \(\mathbb{P}_{\Delta_{\text{ARB}}} = 1 \iff \phi = 0\)
- strictly decreasing in \(\phi\)
- **strictly convex** in \(\phi\)
- increasing in \(\Delta t\)
- increasing in \(\sigma\)
- \(\mathbb{P}_{\Delta_{\text{ARB}}} \to 0\) as \(\phi \to \infty\)

(Strict convexity ⟹ M6b's strict half.)

> LEAN (proved, `MevOptimization.lean`, run cb371ee5): \(\mathbb{P}_{\Delta_{\text{ARB}}} \in (0,1]\), `ptrade_mem_Ioc`, `_eq_one_iff`; strictly \(\downarrow \phi\) on \([0,\infty)\): `ptrade_strictAntiOn`; \(\uparrow \Delta t\), \(\uparrow \sigma\): `_monotoneOn_dt`, `_monotoneOn_sigma`; STRICTLY convex: `ptrade_strictConvexOn` (+`_convexOn`); \(\to\) pole limit `_tendsto_atTop`.

## **M2. [ADDITION] The MMR split**

\[
	\begin{aligned}
		\mathrm{ARB} \, \approx \, \mathrm{LVR}\cdot \mathbb{P}_{\Delta_{\text{ARB}}}, \qquad
		\mathrm{FEE} \, \approx \, \mathrm{LVR}\cdot(1-\mathbb{P}_{\Delta_{\text{ARB}}}), \qquad
		\mathrm{ARB}+\mathrm{FEE} \, \approx \, \mathrm{LVR}
	\end{aligned}
\]

MMR Thm 3 + eq. (12), Thm 4: LVR splits by \(\mathbb{P}_{\Delta_{\text{ARB}}}\). \(\approx\) = fast-block small-fee leading order (inherited by everything below).

> LEAN: `arb_add_fee_eq_lvr` (bridge identity, not MMR Thm 3/4).

## **M3. [ADDITION] The discrete \(\lambda_{\text{ARB}}\)**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, = \, \sum_{t<T} \mathbb{P}_{\Delta_{\text{ARB}}}\big(\phi(\sigma_t),\sigma_t,\Delta t\big)\,\frac{a_t}{D_t}
	\end{aligned}
\]

ARB channel only; \(\Theta_{\phi}\) specialization: \(\phi(\sigma) = \texttt{multiFee}(n,\gamma,\beta,\alpha,\bar\phi,u)\) — the SAME \(\Theta_{\phi}\) as FLAIR.

CPMM instantiation, two tiers:

(i) the LEADING-ORDER per-step weight

\[
	\begin{aligned}
		a_t \, = \, \frac{\sigma_t^2}{8}\,V_t\,\Delta t
	\end{aligned}
\]

\(\mathrm{LVR} = (\sigma^2/8)V(P)\) is a RATE ⟹ \(\cdot\Delta t\) per block. Check: summand \(\propto \Delta t\cdot\sqrt{\Delta t} = \Delta t^{3/2}\) (= MMR §7.1 per-block scaling; \(\Delta t^{1/2}\) per unit time). No guard needed.

(ii) the EXACT Corollary-2 kernel

\[
	\begin{aligned}
		(\mathrm{ARB}/V)_{\text{exact}} \, = \, \frac{(\sigma^2/8)\,\mathbb{P}_{\Delta_{\text{ARB}}}\,e^{\phi/2}}{1-\sigma^2\Delta t/8}
	\end{aligned}
\]

(the ONLY object with the guard \(\sigma_t^2\Delta t < 8\); reuse this symbol/name downstream).

> LEAN (proved): \(\lambda_{\text{ARB}} \geq 0\) (`mevMulti_nonneg`, CPMM weight `mevWeight_cpmm_pos`, \(\cdot\Delta t\) carried). M3(ii) exact kernel (\(\sigma^2\Delta t < 8\) guard): UNFORMALIZED (T19 omitted — no carrier).

## **M4. [ADDITION] Identification \(\Theta_{\lambda_{\text{ARB}}}\)**

\(\gamma_j > 0\): \(\lambda_{\text{ARB}} \downarrow \bar\phi,\, \downarrow \alpha_j,\, \downarrow u\); \(\uparrow \beta_j\); convex in \(\phi\).

**No affine** analogue of `flairMulti_affine` (\(\mathbb{P}_{\Delta_{\text{ARB}}}\) non-affine ⟹ level/shape don't separate; M5's bound is a SUM, not scalar × path weight).

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{ARB}}} \, = \, \{\bar\phi,\, \alpha,\, u\}
	\end{aligned}
\]

Batch clearing (M7, \(\lambda_{\text{sandwich}} = 0\)) ⟹ \(\Theta_{\lambda_{\text{MEV}}} = \Theta_{\lambda_{\text{ARB}}} = \{\bar\phi, \alpha, u\}\).

> LEAN (proved): mirrored monotonicities \(\downarrow \bar\phi, \alpha, u\); \(\uparrow \beta\): `mevMulti_anti_phibar`, `_anti_alpha`, `_anti_u`, `_mono_beta`.

## **M5. [ADDITION] The infimum program (on \(\lambda_{\text{ARB}}\))**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, \sum_{t<T} \mathbb{P}_{\Delta_{\text{ARB}}}\Big(\bar\phi_{\max} + u_{\max}\textstyle\sum_j \alpha_{\max,j},\, \sigma_t,\, \Delta t\Big)\frac{a_t}{D_t}
	\end{aligned}
\]

Three attainment statements (RHS uses the fee CEILING — unreachable at finite shape):
(i) fixed shape ⟹ level-block inf attained bang-bang at the corner TOP;
(ii) bound approached only as \(\beta_j \to -\infty\), STRICT gap at every finite \(\beta\) (boundary value, not minimum);
(iii) compact box ⟹ minimizer exists, value \(>\) bound.

> LEAN (proved): sum-form lower bound `mevMulti_ge_corner`; level-corner attainment `mevMulti_corner_attained_levels`; saturation `mevMulti_saturation_limit` [CORRECTED: Aristotle-added \(0 \leq \bar\phi_{\max} + u_{\max}\alpha_{\max}\) — the \(\mathbb{P}_{\Delta_{\text{ARB}}}\) pole]; strict gap `mevMulti_strict_above_saturation`; compact minimizer `mevMulti_exists_min_compact` [CORRECTED: fees \(\geq 0\) required — unbounded below on arbitrary compact \(\Theta\)]; packaged `Theta_lambdaMEV_identification`, `mevMulti_min_gt_corner` (at \(u = u_{\max}\)).

## **M6a. [ADDITION — THE DEGENERACY] The unconstrained joint program**

(arg-set equality ill-posed over unbounded shape; stated as three claims:)
(i) fixed shape ⟹ level-block \(\max \lambda_{\text{FLAIR}}\) and \(\min \lambda_{\text{ARB}}\) at the SAME corner \((\bar\phi,\alpha,u)\) TOP;
(ii) both saturate along the SAME \(\beta_j \to -\infty\) (one common sequence; neither attained finitely);
(iii) ⟹ \(\forall \kappa \geq 0\): same corner + direction extremize \(\lambda_{\text{FLAIR}} - \kappa\lambda_{\text{ARB}}\) (robust to linear scalarization).

**Unconstrained: no trade-off in \(\Theta_{\phi}\); \((\beta, \gamma_j)\) NOT essential** (REFUTES the phase brief — stated, not dropped). M7 reduction ⟹ verbatim for \(\lambda_{\text{MEV}}\) under uniform clearing.

## **M6b. [ADDITION — THE CONSTRAINED PROGRAM] Where the trade-off lives**

Over arbitrary nonnegative fee PATHS \(\{\phi_t\}\) — NOT \(\Theta_{\phi}\) schedules (load-bearing; see OPEN). \(\nu_t = w_t/D_t\), \(W = \sum_t \nu_t > 0\), budget \(\sum_t \phi_t\nu_t = B\), aligned measure \(a \equiv w\), \(\sigma_t \equiv \sigma_0\):

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, W\cdot \mathbb{P}_{\Delta_{\text{ARB}}}\!\left(\frac{B}{W},\,\sigma_0,\,\Delta t\right),
		\qquad \text{equality} \iff \phi_t\ \text{constant on}\ \{t : \nu_t > 0\}
	\end{aligned}
\]

**Flat path minimizes \(\lambda_{\text{ARB}}\) at equal FLAIR income; non-constant on \(\{\nu_t > 0\}\) strictly worse** (⟹ \(\lambda_{\text{MEV}}\) via M7; strict half consumes M1's STRICT convexity).

\(a \equiv w\) is STRONG (traded volume ∝ LVR path block-by-block); without it: different measures, Jensen inapplicable, minimizer can tilt UP where the arb measure is heavy — conclusion can reverse.

Scope: \(\sigma_t \equiv \sigma_0\), PATHS only — every \(\Theta_{\phi}\) schedule is \(\sigma\)-only ⟹ already constant here (strict half toothless inside \(\Theta_{\phi}\) at constant \(\sigma\)).

**AMENDED 2026-07-31 — σ-varying schedule comparison: REFUTED** (`mev_ge_flat_under_flair_budget_false`):

\[
	\begin{aligned}
		\exists\, \phi(\cdot) \geq 0: \;\; \lambda_{\text{ARB}}^{\text{flat}} \, > \, \lambda_{\text{ARB}}^{\phi} \;\; \text{at equal FLAIR income}; \quad \text{witness } T{=}2,\, \Delta t{=}2,\, B{=}2,\, \sigma{=}(1,10),\, \text{fees } (2,0): \;\; \tfrac{31}{22} \, > \, \tfrac{4}{3}
	\end{aligned}
\]

> (σ-varying ⟹ summands are different convex functions; Jensen inapplicable.)

**OPEN — \(\Theta_{\phi}\)-RESTRICTED case**: witness \(\phi(x) = 2\cdot\mathbb{1}[x{=}1]\) is \(\sigma\)-DEcreasing; \(\Theta_{\phi}\)-reachable schedules are isotone (`multiFee_monotone`) ⟹ refutation settles the general claim only. (Float exploration agrees; NOT machine-checked, no claim; explicit `multiFee` witness = named follow-up.)

## **M7. [ADDITION] The aggregate \(\lambda_{\text{MEV}}\), and the Angstrom bridge**

\[
	\begin{aligned}
		\lambda_{\text{MEV}} \, \coloneqq \, \lambda_{\text{ARB}} \oplus \lambda_{\text{sandwich}}
	\end{aligned}
\]

\(\oplus\) = hazard-side addition (image of \(\otimes_\phi\) under \(\phi_i = 1-e^{-\lambda_i}\); \(\otimes_\phi\) acts on \([0,1]\), NEVER on unbounded hazards). \(\lambda_{\text{sandwich}} = 0 \implies \lambda_{\text{MEV}} = \lambda_{\text{ARB}}\) (uniform clearing delivers by construction ⟹ M3–M6b hold for \(\lambda_{\text{MEV}}\) in the Angstrom regime). Sandwich: distinct channel (arXiv:2207.11835), unmodelled here.

Two parametric items, both OUTSIDE \(\Theta_{\phi}\):

(i) recycling/rebate — LP-INCIDENCE, not extraction intensity:

\[
	\begin{aligned}
		\lambda_{\text{MEV}}^{\text{LP-net}} \, = \, (1-\tau)\,\lambda_{\text{MEV}}, \qquad \tau \in [0,1], \qquad \tau(k) = \frac{k}{k+1}
	\end{aligned}
\]

\(k\) FREE. The ToB auction awards the arb and routes the bid to LPs: \(\tau\) redistributes, \(\lambda_{\text{MEV}}\) invariant, LP share falls — \((1-\tau)\) is NOT an MEV reduction. \(\tau(k) = k/(k+1)\) presumes priority-fee bidding + full-value competition (monopoly/collusion ⟹ realized \(\tau\) arbitrarily lower). Dated instance only: l2-angstrom 2026-07-30 `k = 49` ⟹ `τ = 0.98`; live docs disagree (`TAXED_GAS` 120000, floor, jit factor, creator/protocol/LP split) — no numeral in any claim. \(\tau \in [0,1)\): objective rescaled, minimizers unmoved (the sense in which \(\tau \notin \Theta_{\phi}\)); \(\tau = 1\) vacuous.

(ii) cadence \(= \Delta t\): moves \(\lambda_{\text{ARB}}\) monotonically, absent from \(\lambda_{\text{FLAIR}}\) — the second non-degenerate lever.

> LEAN (M6a, M6b, M7 — `MevJointProgram.lean`, run `19f777ab`; 27 declarations, axiom-clean).
> **M6a proved, and the result IS the degeneracy**: `joint_corner_degeneracy` (i), `joint_beta_degeneracy` (ii), `joint_scalarization_degeneracy` (iii, every \(\kappa \geq 0\)) — no trade-off over \(\Theta_{\phi}\); \((\beta,\gamma)\) NOT essential unconstrained.
> **M6b, budget half**: `flair_budget_pins_mean_fee`, `flair_budget_mean`, with path carriers `flairPath`/`mevPath` and bridges `flairPath_schedule`, `mevPath_schedule`, `flairPath_sum`, `flairPath_budget_mean`. **Constant-\(\sigma\) display proved at the PATH level**: `mev_ge_flat_under_flair_budget_const_sigma`, strict companion `mev_gt_flat_under_flair_budget_const_sigma` (consumes `ptrade_strictConvexOn`). **The \(\sigma\)-VARYING SCHEDULE claim is REFUTED**: `mev_ge_flat_under_flair_budget_false`, witness \(T=2,\ \Delta t=2,\ B=2,\ \sigma=(1,10)\), unit \(w,D\), fees \((2,0)\) — flat \(31/22 \approx 1.4091\) vs tilted \(4/3 \approx 1.3333\). The \(\Theta_{\phi}\)-restricted isotone case stays OPEN (`VolInstrument.multiFee_monotone`).
> **M7 proved**: `mevTotal` \(:= \lambda_{\text{ARB}} + \lambda_{\text{sandwich}}\) — PLAIN addition, with the \(\otimes_\phi\) correspondence as its own lemma `mevTotal_probOr_hazard`; `mevTotal_eq_arb_of_sandwich_zero`, `mevTotal_mevMulti_eq_of_sandwich_zero`. (i) `mevNet`, `mevNet_le_mev` (nonnegativity DISCHARGED on `mevMulti_nonneg`), `mevNet_anti_tau`, `mevNet_eq_zero_of_tau_one`, `mevNet_argmin_invariant` (for \(\tau < 1\) the rebate moves the VALUE, not the SOLUTION), `taxFraction` \(= k/(k+1)\) with \(k\) FREE, `taxFraction_mem_Ico`, `taxFraction_mono` — no numeral in any statement. (ii) `mev_mono_dt`, ISOTONE in \(\Delta t\).

## **M8. [CAVEATS]**

- LEADING ORDER — all rests on eq. (12) fast-block small-fee asymptotics; only M3(ii) (under its guard) is exact.
- QUASI-STATIC — \(\mathbb{P}_{\Delta_{\text{ARB}}}\) is steady-state; M3 applies it per step on a \(\sigma\)-varying path (this doc's extension; valid iff parameters slow vs mispricing mixing).
- NO DEMAND ELASTICITY — missing term: MMR §7.3 eq. (27) `E[hedged LP P&L] = E[NT_FEE] − E[ARB]`; corner solutions = objective properties, NOT equilibrium claims.
- AGGREGATE SCOPE — two channels only. Unmodelled: noise backruns; multi-block (censoring lengthens \(\Delta t\), attacks M7(ii); §7.1); JIT (taxed separately, l2 docs); gas (additive fee, moves \(\mathbb{P}_{\Delta_{\text{ARB}}}\); §6).
- CADENCE VALIDITY — \(\Delta t\) law validated for block times \(\gtrsim 1\)s; sub-second needs jump-diffusion, out of scope.
- M6b \(\sigma\)-varying schedule comparison: **REFUTED** (general paths), **OPEN** (\(\Theta_{\phi}\)-restricted) — as labelled there.

## **M9. [τ_MEV ENTRY — DECIDED: (A) MONOID] the tax composes into the trader-paid fee**

**DECIDED (user, 2026-07-31): channel (A).** Entry through the proven abelian monoid \(([0,1], \otimes_\phi, 0)\):

\[
	\begin{aligned}
		\phi_{\text{total}} \, = \, \phi_M \otimes_\phi \phi_X \otimes_\phi \tau_{\text{MEV}}, \qquad
		\phi \otimes_\phi \tau_{\text{MEV}} \, \geq \, \phi \;\; (\tau_{\text{MEV}} \geq 0,\, \phi \leq 1)
	\end{aligned}
\]

Alternates formalized, NOT adopted: (B) convex separation \(\phi = (1-\tau_{\text{MEV}})\phi + \tau_{\text{MEV}}\phi\) (incidence-targeting, intensity-neutral); (C) auction lump-sum \(\tau(k) = k/(k+1)\) (`taxFraction`, `mevNet`).

## **M10. [THE DISCRIMINATING ALGEBRA] what (A) buys / cannot buy**

\[
	\begin{aligned}
		\text{(A) intensity:} \quad & \mathbb{P}_{\Delta_{\text{ARB}}}\big(\phi \otimes_\phi \tau_{\text{MEV}}\big) \, \leq \, \mathbb{P}_{\Delta_{\text{ARB}}}(\phi) \quad \text{(strict for } \tau_{\text{MEV}} > 0,\, \phi < 1\text{)} \\
		\text{(A) no targeting:} \quad & (\phi_M \otimes_\phi \tau_{\text{MEV}}) \otimes_\phi \phi_X \, = \, \phi_M \otimes_\phi (\phi_X \otimes_\phi \tau_{\text{MEV}}) \quad \text{(aggregate leg-invariant)} \\
		\text{(A) hazard-exact:} \quad & (1-e^{-\lambda_M}) \otimes_\phi (1-e^{-\lambda_X}) \otimes_\phi (1-e^{-\lambda_\tau}) \, = \, 1-e^{-(\lambda_M+\lambda_X+\lambda_\tau)} \\
		\text{(A} \neq \text{B):} \quad & \exists\, \phi, \tau:\; (1-\tau)\big(\phi_M \otimes_\phi \phi_X\big) \, \neq \, \big((1-\tau)\phi_M\big) \otimes_\phi \big((1-\tau)\phi_X\big) \\
		\text{(B breaks hazard):} \quad & \exists\, \tau, \lambda:\; 1-e^{-\tau\lambda} \, \neq \, \tau\,(1-e^{-\lambda})
	\end{aligned}
\]

> (A) consequences (proved): \(\lambda_\tau\) a genuine \(\oplus\)-summand (hazard-exact); intensity STRICT \(\Rightarrow \lambda_{\text{ARB}} \downarrow\); NO leg-targeting (benign flow pays); NO compensation routed (donation ⟹ compose with (B)/(C), ORDER-SENSITIVE: tax-then-compose \(\neq\) compose-then-split); \(\phi \otimes_\phi \tau\) moves the M6a level direction (\(\lambda_{\text{FLAIR}} \uparrow\), \(\lambda_{\text{ARB}} \downarrow\) jointly).
> LEAN (proved, `TauMevAlgebra`, 14/14 axiom-clean): (A) `tau_monoid_mem`, `tau_monoid_ge/gt`, `tau_intensity_effect(_strict)`, `tau_no_targeting`, `tau_hazard_exact`; (B) `tau_split_budget`, `tau_split_intensity_neutral`, `tau_split_flair_linear`, `tau_split_mevNet_bridge`; (D) `tau_scaling_not_monoid_hom`, `tau_order_matters`, `tau_split_breaks_hazard`.


## FLAIR & MEV

## **E0. [NOTATION]**

ANCHOR: Capponi & Jia, *The Adoption of Blockchain-Based Decentralized Exchanges*, arXiv:2103.08842v4 [q-fin.TR], 21 Jul 2021, §5.1. The curvature results transcribed in this section are **Lemma 3** (both ratios antitone in curvature), **Proposition 5** (the interior optimum and the liquidity-freeze corollary) and **Proposition 6** (deposit efficiency; its welfare half is OPEN, see E5). Lemma 1 and Lemma 2 are cited only for their own trade-occurrence conditions and are NOT curvature results. η is PROTECTED throughout and is this document's pricing-kernel exponent.

The paper's curvature index `k` is transcribed as `ς_{X/M}` (`\varsigma_{X/M}`) — USER DECISION, 2026-07-31. `χ` is NOT used anywhere in this section. <!-- notation-map -->
The subscript in `ς_{X/M}` is `\varphi`, this document's QUOTE-FUNCTION symbol (M0: "`\varphi` NOT used (bound to the quote function)") — it is NOT the fee. The fee is `\phi`, with ceiling `\bar\phi` and parameter set `\Theta_{\phi}`, exactly as M0 binds them. The two must never be conflated: `ς_{X/M}` is the curvature of the quote function, and `\phi` is what the trader pays. <!-- notation-map -->
Bare `κ` remains FORBIDDEN — it is the anchor's absorbed arrival symbol and the Phase-11 scalarization weight. Only the `\varphi`-subscripted forms `\varsigma_{X/M}`, `\varsigma_{X/M,S}`, `\varsigma_{X/M,I}`, `\varsigma_{X/M}^{\star}` are admissible, and the gate enforces exactly that. <!-- notation-map -->
The paper's investor private-use premium `α` is transcribed as `ϱ_I` (`\varrho_I`); Lean `premInv`. <!-- notation-map -->
The paper's price-shock magnitude `β` is transcribed as `ϱ_S` (`\varrho_S`); Lean `premShock`. <!-- notation-map -->
The paper's proportional trading fee `f` is IDENTIFIED with this document's `φ` (`\phi`) and is not renamed; this document's `α_j`, `β_j`, `γ_j` remain the `Θ_φ` sigmoid parameters and are always subscripted. <!-- notation-map -->
The paper's probabilities `θ, κ_I, κ_com, κ₁, κ₂` are NEVER NAMED; they enter only as the four constants below. The two that ARE probabilities follow the `ℙ_{event}` convention (M0): the arbitrage-occurrence probability is `ℙ_{Δ_ARB^{CJ}}` and the investor-arrival probability is `ℙ_{L_INV}` (arrival events take the `L_` prefix, as `ℙ_{L_JIT}` does). **The `CJ` tag is load-bearing**: it keeps this two-period-model arbitrage event distinct from MMR's `ℙ_{Δ_ARB}`, whose identification E8(3) forbids. `ϖ_H` and `ϖ_D` keep `ϖ` — they are a coefficient and a constant, NOT probabilities. Lean is unchanged (`probArb`, `probInv`, `coefD`). `θ` collides with this document's option theta and `κ` with the Phase-11 scalarization weight. <!-- notation-map -->
The paper's Proposition-5 coefficients `τ₁, τ₂, τ₃` are transcribed as `c₁, c₂, c₃` (Lean `cOne`, `cTwo`, `cThree`), because `τ` is TAKEN by this document's `τ = τ_MEV` (block M9). <!-- notation-map -->
The symbol `ν` is TAKEN by block M6b (`ν_t = w_t/D_t`) and is NEVER introduced here. <!-- notation-map -->

The four absorbed constants, each constant in \(\varsigma_{X/M}\):

\[
	\begin{aligned}
		\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}} \, > \, 0 \;&:\; \text{probability an arbitrage occurs in a period} \\
		\mathbb{P}_{L_{\text{INV}}} \, > \, 0 \;&:\; \text{probability an investor arrives} \\
		\varpi_H \, \geq \, 0 \;&:\; \text{the hold-benchmark coefficient, } \; \mathbb{E}[R_A] = \varpi_H\,\varrho_S \\
		\varpi_D \, \geq \, 0 \;&:\; \text{the constant subtracted in the LP excess return}
	\end{aligned}
\]

THE POSITIVITY IS LOAD-BEARING, NOT COSMETIC. At \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}} = 0\) the whole of E2 collapses to \(\mathrm{arbLoss} \equiv 0\), every η is arb-minimal, and E7's first-branch weight condition degenerates to \(-w_2/2\); at \(\mathbb{P}_{L_{\text{INV}}} = 0\) E4's strict increase **SURVIVES** (the arb-loss term carries it) — what fails is the **PEAK**, via \(c_1 < 0\). <!-- CORRECTION 2026-07-31 (ESC-2): "strict increase fails" was the wrong failure mode --> Both are strictly positive in the anchor: \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}\) is built from its two idiosyncratic-shock probabilities, each strictly inside \((0,1)\) by its eq. (2) **and \(\theta < 1\)** <!-- CORRECTION 2026-07-31 (ESC-3): the θ < 1 conjunct was omitted -->, and \(\mathbb{P}_{L_{\text{INV}}}\) is a strictly positive arrival probability. \(\varpi_D \geq 0\) likewise comes from a structural anchor assumption — eq. (2) imposes a strict ordering on those two shock probabilities — and is recorded here so a reader can check it rather than take it on trust.

Standing hypotheses for every display below: \(0 \leq \phi < \varrho_S \leq \varrho_I\), \(0 < \Delta_i\), \(1 < \lambda_{\text{tick}}\). These give \(\varsigma_{X/M,S} > 0\) and \(\varsigma_{X/M,I} > 0\), which is what keeps every \(1/\varsigma_{X/M}\) branch below away from its pole; the guard is ALSO restated inline on each at-risk display, because a guard that lives only in a global prose sentence is exactly how this project's `ptrade` negative-fee pole reached two theorem statements.

THE ANCHOR'S PREMIUM ORDERING: Propositions 5 and 6 DISPLAY the strict ordering (ours: \(\varrho_S < \varrho_I\)); their proofs consume only the weak form \(\varrho_S \leq \varrho_I\), through the branch-point ordering \(\varsigma_{X/M,S} \leq \varsigma_{X/M,I}\) alone. The weak form is what is transcribed. At \(\varrho_S = \varrho_I\) the middle branch \([\varsigma_{X/M,S},\varsigma_{X/M,I}]\) of E4 is EMPTY and the three-branch display degenerates to two; the peak statement is unaffected.

TICK-BASE READING: in this section an unsubscripted `\lambda` inside an exponential is the tick base λ = 1.0001 (`PosSpec.lam`), never a hazard; every hazard of `### MEV` is subscripted (`\lambda_{\text{ARB}}`, `\lambda_{\text{FLAIR}}`, `\lambda_{\text{MEV}}`).

NOT PROBABILITIES: `\varrho_I` and `\varrho_S` are VALUATION PREMIA — they are not probabilities, they are not arrival probabilities, and they are not confined to \([0,1]\). `\varrho_I` is the markup a type-`i` investor places on token `i` and may exceed 1; `\varrho_S` is the magnitude of the price shock. Under a probability reading the closed form \(\varsigma_{X/M}^{\star} = 1 - \sqrt{(1+\phi)/(1+\varrho_I)}\) is uninterpretable.

THE η CONVENTION BRIDGE, AS TWO SEPARATE CLAIMS. (i) THE EXPONENT IDENTITY (provable algebra): on integer ticks, `priceEta η Δ_i i = p_eta(lam, Δ_i, η/2, i) = P_half(lam, Δ_i·η/2, i)` with `lam = PosSpec.lam` the tick base, the factor 2 being `priceEta`'s sqrt-price convention `i/2`; the second equality is the existing `CFMM.Eta.p_eta_eq_P_half_rescaled`. (ii) THE FACTOR-SHARE IDENTIFICATION (a MODELLING claim, NOT implied by (i)): that this same η is the exponent of the weighted-CFMM trading function `L_eta η X Y = X^{η}·Y^{1−η}` of `model/exp/eta.md`. Claim (ii) is listed in E8 as **OPEN** unless E6 displays a derivation. `exp/eta.lean`'s own `P_half` docstring states that η does not enter the tick→price map — it enters at the reserve / impact level — which is precisely why (ii) cannot ride in on (i).

TERMINOLOGY: for a weighted-geometric trading function \(L = X^{\eta_L}Y^{1-\eta_L}\), the exponent \(\eta_L\) is a FACTOR SHARE on reserves and the elasticity of substitution is 1. The plank-side phrase "asset-demand substitution elasticity" is therefore loose and is NOT propagated here. Note that this sentence is about \(\eta_L\), the `L_eta` exponent — whether \(\eta_L\) equals this section's grid exponent η is claim (ii) above and is listed **OPEN** at E8(6); no display in E1–E7 assumes it.

PROPOSED LEAN NAMES (these do NOT yet exist anywhere in the tree; every OTHER backticked Lean identifier in this section resolves to a real declaration): `curvIndex` for the definition of \(\varsigma_{X/M}(\eta,\Delta_i)\), with `curv` reserved as the bound VARIABLE name so that it does not shadow `MevJointProgram.taxFraction (k : ℝ)`; `premInv`, `premShock`, `cOne`, `cTwo`, `cThree`, `kphiS`, `kphiI`, `kphiStar`, `etaStar`.

## **E1. [ADDITION] The curvature family and the discrete index**

**VERDICT ON "F IS \(\varphi\)" — SETTLED, PART PROVEN PART REFUTED.** Mechanism: Angeris–Chitra–Diamandis–Evans–Kulkarni, *The Geometry of CFMMs*, arXiv:2308.08066 §1.3.2 eq (6) — the CANONICAL trading function \(\mathrm{canon}\,\psi\,k\,(R) = \sup\{\lambda > 0 : \psi(R/\lambda) \geq k\}\), which is nondecreasing, concave and homogeneous, and is shared by any two \(\psi\) describing the same reachable set.

\[
	\begin{aligned}
		\mathrm{canon}\,\varphi_{\chi_{X/M},\,0}\,k \, &= \, \varphi_{\chi_{X/M},\,0}/k \qquad \text{(ours is ALREADY canonical up to scale)} \\
		\mathrm{canon}\,F_{\kappa}\,C \, &= \, \frac{b + \sqrt{b^{2} + 4C\kappa\,Q_X Q_M}}{2C}, \qquad b = (1-\kappa)A\,L, \quad L = p^{2}\,\Delta Q_M + \Delta Q_X \\
		\kappa = 1 \, &\Rightarrow \, \sqrt{Q_X Q_M}/\sqrt{C}; \qquad \kappa = 0 \, \Rightarrow \, A\,L/C \;\; \text{(linear)}
	\end{aligned}
\]

SURVIVES: as a CANONICAL-FORM statement, and at ONE point — at \(\kappa = 1\) the canonical form IS \(\varphi_{1/2,\,0}\) up to a positive scalar (same CFMM).
REFUTED as a FAMILY identity: for \(\kappa \in (0,1)\) there is NO \((\chi_{X/M}, c > 0)\) with \(\mathrm{canon}\,F_{\kappa} = c\,\varphi_{\chi_{X/M},\,0}\) pointwise.
REFUTED at the linear end: \(F_0 = \varphi_{\chi_{X/M}(\varsigma_{X/M}=0),\,0}\) is FALSE — \(\chi_{X/M}(\varsigma_{X/M}=0) = 1/2\), and the linear function is not a positive multiple of \(\varphi_{1/2,\,0}\).
ORIENTATION: the identification HOLDS at Capponi \(\kappa = 1\) and FAILS at \(\kappa = 0\) ⟹ any identification respecting the agreement point must REVERSE orientation.
DIAGNOSIS: Capponi's \(\kappa\) travels the \(\epsilon_{X/M}\) axis of \(\varphi_{\chi_{X/M},\epsilon_{X/M}}\); this document's \(\varsigma_{X/M}\) is a function of the SHARE \(\chi_{X/M}\) alone. They coincide only where both axes sit at base values — the CPMM. **E8(1) therefore remains OPEN, now for a precise reason with a witness rather than a vague one.**

> LEAN (proved, `CanonicalCurve`, 16/16 axiom-clean, project `ffdb83fe`): `canon_phiEps`, `canon_Fcap`, `canon_Fcap_homogeneous`, `canon_Fcap_one`, `canon_Fcap_zero`, `canon_Fcap_one_eq_phiEps_half` (the agreement), `canon_Fcap_numeraire` (\(p_B = 1\), \(p_A = p^2\) — Capponi's two free prices collapse to ONE grid price).
> REFUTED: `canon_Fcap_not_phiEps` (family identity), `linear_not_phiEps_half` + `tildeOfCurv_zero` + `curvIndex_orientation_inconsistent` (the \(F_0\) substitution), with `cpmm_sits_at_curvIndex_zero` carrying both halves as one conjunction. PDF: `../refs/cfmm/angeris-geometry_of_cfmms-2023.pdf`.
The anchor's family (§5.1, p. 23), with `A` the scaling coefficient:

\[
	\begin{aligned}
		F_{\varsigma_{X/M}}(Q_X,Q_M) \, &= \, (1-\varsigma_{X/M})\,A\,F_0(Q_X,Q_M) \, + \, \varsigma_{X/M}\,F_1(Q_X,Q_M), \qquad \varsigma_{X/M} \in [0,1] \\
		F_0(Q_X,Q_M) \, &= \, p_{(\chi_{X/M}, \Delta_i)}\,Q_X + p_B\,Q_M \quad \text{(linear, zero curvature; numeraire-relative \(p_B = 1\))}, \qquad
		F_1(Q_X,Q_M) \, = \, Q_X\,Q_M \quad \text{(constant product)} \\
		A \, &= \, \big(Q_X^{0}\,Q_M^{0} / (p_{(\chi_{X/M}, \Delta_i)}\,p_B)\big)^{1/2} \quad (Q^{0} = \text{the anchor's initial reserves})
	\end{aligned}
\]

The curvature of \(F_{\varsigma_{X/M}} = C\) is increasing in \(\varsigma_{X/M}\). OUR discrete index, from `VolInstrument.priceEta η Δ_i i` \(= \lambda^{(i/2)\Delta_i\eta}\):

\[
	\begin{aligned}
		\frac{p_{(\eta, \Delta_i)}(i+\Delta_i)}{p_{(\eta, \Delta_i)}(i)} \, &= \, \lambda^{\Delta_i^{2}\eta/2}
		\qquad \text{(INDEPENDENT of } i \text{)} \\
		\varsigma_{X/M}(\eta,\Delta_i) \, &:= \, 1 \, - \, \frac{p_{(\eta, \Delta_i)}(i)}{p_{(\eta, \Delta_i)}(i+\Delta_i)}
		\, = \, 1 \, - \, \lambda^{-\Delta_i^{2}\eta/2}
	\end{aligned}
\]

Properties: strictly increasing in \(\eta\); a bijection \((0,\infty) \to (0,1)\); \(\to 0\) as \(\eta \to 0^{+}\) (the zero-curvature constant-price grid, the anchor's \(\varsigma_{X/M} = 0\)) and \(\to 1\) as \(\eta \to \infty\).

**\(\varsigma_{X/M}(\eta,\Delta_i)\) IS A MONOTONE PROXY FOR THE ANCHOR'S CURVATURE, NOT A DEFINITIONAL RESTATEMENT OF IT — AND THE DIFFERENCE IS LOAD-BEARING.** The anchor's curvature is the rate of change of the marginal exchange rate *with respect to the amount traded* (§5.1, p. 22), which is what produces slippage; and its `k` is the MIXING WEIGHT of the family above, entering structurally in the arbitrageur's constraint (A.31) and the investor's (A.39) from which every closed form in E2–E5 is derived. Our \(\varsigma_{X/M}\) is the relative price step *per tick index*, and it carries NO per-tick liquidity term — two grids with the same \(\varsigma_{X/M}\) and different liquidity have different slippage per unit traded, hence different curvature in the anchor's sense. What \(\varsigma_{X/M}\) shares with `k` is its qualitative content: increasing in curvature, \(\to 0\) at zero curvature, \(\to 1\) at maximal. **Placing \(\varsigma_{X/M}\) in the anchor's `k` slot is a MODELLING step, not a definition — see E8(1), which covers this object-level identification as well as the equilibrium transfer.**

**WARNING — `η = 1` is the standard sqrt-price grid (`VolInstrument.priceEta_one`: `priceEta 1 Δ_i = tickPrice Δ_i`), and is NOT Capponi's `ς_{X/M} = 1`. \(\varsigma_{X/M}(1,\Delta_i) \neq 1\), and no display here equates `η = 1` with `ς_{X/M} = 1`.** Nor does the unbounded η range EXTEND the anchor's family: \(\varsigma_{X/M}(\cdot,\Delta_i)\) maps \((0,\infty)\) onto the OPEN interval \((0,1) \subsetneq [0,1]\), so \(\eta \to \infty\) only approaches constant product and never attains it, and the anchor's two corners are unreachable. Interiority in η is therefore INHERITED from \(\varsigma_{X/M}^{\star} \in (0,1)\) — the anchor's Proposition-5 result — and is not additional evidence supplied by the reparametrization.
> note: arbLoss is a payoff \pi^{- arb} and if a ratio is \pi^{-arb} / whatever denominator that makes it a ratio
## **E2. [ADDITION] The arbitrage-loss ratio** (Lemma 3(1))

\[
	\begin{aligned}
		\varsigma_{X/M,S} \, &= \, 1 - \sqrt{\tfrac{1+\phi}{1+\varrho_S}}, \qquad s \, := \, \sqrt{\tfrac{1+\phi}{1+\varrho_S}} \, = \, 1 - \varsigma_{X/M,S} \\[2pt]
		\mathrm{arbLoss}(\varsigma_{X/M}) \, &= \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\cdot
		\begin{cases}
			(1+\varrho_S) \, - \, \dfrac{1+\phi}{1-\varsigma_{X/M}}, & \varsigma_{X/M} \in [0,\ \varsigma_{X/M,S}] \quad \text{(A.38, corner)} \\[8pt]
			(1+\varrho_S)\,\dfrac{\varsigma_{X/M,S}^{2}}{\varsigma_{X/M}}, & \varsigma_{X/M} \in [\varsigma_{X/M,S},\ 1] \quad \text{(A.36, interior)}
		\end{cases}
	\end{aligned}
\]

GUARD (restated inline, not inherited from E0): \(0 \leq \phi < \varrho_S\), hence \(\varsigma_{X/M,S} > 0\); the interior branch is stated on \([\varsigma_{X/M,S},1] \subset (0,1]\) and never touches the \(1/\varsigma_{X/M}\) pole. Lean domain: `Set.Ioc 0 1`, glued at `Set.Icc 0 kphiS` and `Set.Icc kphiS 1`, with `hkphiS : 0 < kphiS` an explicit hypothesis.

Branch agreement at \(\varsigma_{X/M,S}\): both branches equal \(\tfrac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}(1+\varrho_S)(1-s)\), so the glued function is continuous. **Strictly decreasing in \(\varsigma_{X/M}\)** on \((0,1]\) (each branch is: \((1+\phi)/(1-\varsigma_{X/M})\) increases, \(1/\varsigma_{X/M}\) decreases) — strictly, because \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}} > 0\) by E0.

`\varrho_S > \phi` is Lemma 1's condition that an arbitrage occurs at all; Lemma 1 is the one-token shock result and is NOT the curvature lemma.
> note: Investor surplus is a payoff \pi^{trader} same ratio condition as above
## **E3. [ADDITION] The investors' surplus ratio** (Lemma 3(2))

\[
	\begin{aligned}
		\varsigma_{X/M,I} \, &= \, 1 - \sqrt{\tfrac{1+\phi}{1+\varrho_I}} \\[2pt]
		\mathrm{surplus}(\varsigma_{X/M}) \, &= \, \frac{1}{2}\cdot
		\begin{cases}
			(1+\varrho_I) \, - \, \dfrac{1+\phi}{1-\varsigma_{X/M}}, & \varsigma_{X/M} \in [0,\ \varsigma_{X/M,I}] \quad \text{(A.43, corner)} \\[8pt]
			(1+\varrho_I)\,\dfrac{\varsigma_{X/M,I}^{2}}{\varsigma_{X/M}}, & \varsigma_{X/M} \in [\varsigma_{X/M,I},\ 1] \quad \text{(A.42, interior)}
		\end{cases}
	\end{aligned}
\]

GUARD (restated inline): \(0 \leq \phi < \varrho_I\), hence \(\varsigma_{X/M,I} > 0\); the interior branch is stated on \([\varsigma_{X/M,I},1] \subset (0,1]\). Lean domain `Set.Ioc 0 1` with `hkphiI : 0 < kphiI` explicit.

Same shape, same continuity at \(\varsigma_{X/M,I}\), **strictly decreasing in \(\varsigma_{X/M}\)** on \((0,1]\).

SCALE: \(\mathrm{surplus}\) is the PER-INVESTOR ratio. Lemma 3(2)'s object is the sum over both investor types, and the anchor shows the two type-ratios are equal, so Lemma 3(2)'s quantity is \(2\,\mathrm{surplus}\). The welfare weight attached to it is \(\mathbb{P}_{L_{\text{INV}}}\), whereas E2's \(\mathrm{arbLoss}\) already carries \(\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}\) — the two blocks are NOT conditioned alike, and anything that combines them additively must supply the missing \(\mathbb{P}_{L_{\text{INV}}}\). Monotonicity is unaffected by either factor.

`\varrho_I > \phi` is Lemma 2's condition for the investor to trade. And \(\varrho_S \leq \varrho_I \iff \varsigma_{X/M,S} \leq \varsigma_{X/M,I}\) — the geometrized form of the premium ordering that Proposition 5's PROOF consumes (E0 records that the Proposition DISPLAYS the strict form), which it uses ONLY through the ordering of the two branch points.

## **E4. [ADDITION — THE INTERIOR OPTIMUM]** (Proposition 5)

The LP one-period excess return \(D(\varsigma_{X/M}) = \mathbb{E}[R_D] - \mathbb{E}[R_A]\), equations (A.50)–(A.52):

\[
	\begin{aligned}
		D(\varsigma_{X/M}) \, &= \,
		\begin{cases}
			c_3(\varsigma_{X/M}) \, - \, \varpi_D\,\varrho_S, & \varsigma_{X/M} \in [0,\ \varsigma_{X/M,S}] \quad \text{(A.52)} \\
			c_2(\varsigma_{X/M}) \, - \, \varpi_D\,\varrho_S, & \varsigma_{X/M} \in [\varsigma_{X/M,S},\ \varsigma_{X/M,I}] \quad \text{(A.51)} \\
			\dfrac{c_1}{\varsigma_{X/M}} \, - \, \varpi_D\,\varrho_S, & \varsigma_{X/M} \in [\varsigma_{X/M,I},\ 1] \quad \text{(A.50)}
		\end{cases} \\[6pt]
		c_3(\varsigma_{X/M}) \, &= \, \frac{\mathbb{P}_{L_{\text{INV}}}}{2}\Big(\frac{1+\phi}{1-\varsigma_{X/M}} - 1\Big)
		\, - \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\Big((1+\varrho_S) - \frac{1+\phi}{1-\varsigma_{X/M}}\Big) \\
		c_2(\varsigma_{X/M}) \, &= \, \frac{\mathbb{P}_{L_{\text{INV}}}}{2}\Big(\frac{1+\phi}{1-\varsigma_{X/M}} - 1\Big)
		\, - \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\,\frac{(1+\varrho_S)\,\varsigma_{X/M,S}^{2}}{\varsigma_{X/M}} \\
		c_1 \, &= \, \frac{\mathbb{P}_{L_{\text{INV}}}}{2}\Big(1+\phi-\sqrt{\tfrac{1+\phi}{1+\varrho_I}}\Big)\Big(\sqrt{\tfrac{1+\varrho_I}{1+\phi}}-1\Big)
		\, - \, \frac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}\,(1+\varrho_S)\,\varsigma_{X/M,S}^{2} \qquad \text{(constant in } \varsigma_{X/M}\text{)}
	\end{aligned}
\]

WHAT \(D\) IS MADE OF — read this before E7. \(D\) is LP REVENUE FROM INVESTOR FLOW minus \(\mathrm{arbLoss}\). The investor's own SURPLUS (E3) does NOT appear in \(D\) at all. The revenue term is \(\tfrac{\mathbb{P}_{L_{\text{INV}}}}{2}\big((1+\phi)/(1-\varsigma_{X/M}) - 1\big)\) on the two lower branches and \(\propto 1/\varsigma_{X/M}\) on the top branch; it is "LP revenue from investor flow", i.e. SLIPPAGE RENT PLUS FEE, and it is strictly positive even at \(\phi = 0\), where it equals \(\mathbb{P}_{L_{\text{INV}}}\varsigma_{X/M}/(2(1-\varsigma_{X/M}))\). It is INCREASING in \(\varsigma_{X/M}\) below \(\varsigma_{X/M,I}\) and DECREASING above — the opposite sign to E3's surplus below \(\varsigma_{X/M,I}\), not the same sign.

GUARD (restated inline): \(\varsigma_{X/M,S} > 0\) and \(\varsigma_{X/M,I} > 0\) from \(0 \leq \phi < \varrho_S \leq \varrho_I\); the \(c_2\) and \(c_1/\varsigma_{X/M}\) branches are stated on \([\varsigma_{X/M,S},\varsigma_{X/M,I}]\) and \([\varsigma_{X/M,I},1]\), both bounded away from the pole. Lean: `Set.Icc kphiS kphiI`, `Set.Icc kphiI 1`, with `hkphiS`, `hkphiI` explicit.

Continuity at BOTH branch points: at \(\varsigma_{X/M,S}\) by E2's branch agreement; at \(\varsigma_{X/M,I}\) both sides equal \(\tfrac{\mathbb{P}_{L_{\text{INV}}}}{2}\big(\sqrt{(1+\phi)(1+\varrho_I)}-1\big) - \tfrac{\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}}}{2}(1+\varrho_S)\varsigma_{X/M,S}^{2}/\varsigma_{X/M,I}\). \(D\) is strictly increasing on \([0,\varsigma_{X/M,I}]\) and, **under \(c_1 > 0\)**, strictly decreasing on \([\varsigma_{X/M,I},1]\), so

\[
	\begin{aligned}
		\varsigma_{X/M}^{\star} \, = \, \varsigma_{X/M,I} \, = \, 1 - \sqrt{\tfrac{1+\phi}{1+\varrho_I}}, \qquad
		\varsigma_{X/M}^{\star} \in (0,1) \iff \phi < \varrho_I
	\end{aligned}
\]

**\(\varsigma_{X/M}^{\star}\) is a BRANCH POINT — a kink, where the investor's trade switches from draining the pool to an interior marginal condition. The derivative jumps there. There is no first-order condition and none is claimed.**

Liquidity-freeze corollary (Proposition 5(2)): \(D(\varsigma_{X/M}^{\star}) < 0 \implies D(\varsigma_{X/M}) < 0\) for every \(\varsigma_{X/M} \in [0,1]\).

BOUNDARY OF THE CLAIM: when \(c_1 \leq 0\) the anchor's own argument puts the pool in the freeze region, where the LP payoff is \(\mathbb{E}[R_A] = \varpi_H\varrho_S\), constant in \(\varsigma_{X/M}\); strict single-peakedness is therefore FALSE in general, and the strict statement is made only under \(c_1 > 0\).

## **E5. [ADDITION] Deposit efficiency and the welfare bound** (Proposition 6)

Deposit efficiency (A.56) — expected investor trading volume over deposited value — has the same two-branch shape with the SAME branch point \(\varsigma_{X/M}^{\star}\): increasing in \(\varsigma_{X/M}\) below \(\varsigma_{X/M}^{\star}\) (the corner branch, from A.41) and decreasing above (the interior branch, from A.40). Maximized at \(\varsigma_{X/M}^{\star}\).

WELFARE: **OPEN — and NOT reducible to a sum of E3 and E4.** This block transcribes Proposition 6's DEPOSIT-EFFICIENCY half only. The welfare half does NOT follow from the pieces stated here, and saying it did would be the document's most inviting error: below \(\varsigma_{X/M}^{\star}\) the LP payoff RISES while the investor surplus FALLS (E3 is antitone on all of \([0,1]\)), so "LP peaked at \(\varsigma_{X/M}^{\star}\), surplus antitone, arbitrageur zero" points a reader toward the OPPOSITE conclusion. The anchor's welfare argument is a two-period COMPOUNDED expression carrying a freeze indicator and its own coefficient, and that coefficient's monotonicity is a separate computation, not a corollary of Lemma 3 plus Proposition 5. Formalizing it means transcribing that carrier; until then the welfare half is **OPEN**.

What IS clean, and is the sharp statement of what curvature does below the peak: on the corner branch the investor surplus and the LP revenue from investor flow sum to a CONSTANT,

\[
	\begin{aligned}
		\underbrace{\tfrac{1}{2}\Big[(1+\varrho_I) - \tfrac{1+\phi}{1-\varsigma_{X/M}}\Big]}_{\text{investor surplus}}
		\; + \;
		\underbrace{\tfrac{1}{2}\Big[\tfrac{1+\phi}{1-\varsigma_{X/M}} - 1\Big]}_{\text{LP revenue per investor}}
		\; = \; \frac{\varrho_I}{2}
		\qquad \text{on } [0,\varsigma_{X/M,I}]
	\end{aligned}
\]

so below \(\varsigma_{X/M}^{\star}\) curvature is a PURE ZERO-SUM TRANSFER from investor to LP at a one-to-one rate — the gains from trade do not shrink, because the investor still clears the pool. The pie only starts shrinking above \(\varsigma_{X/M}^{\star}\), where the investor curtails volume. That, and not any weighting of objectives, is where the peak comes from.

GAS is absorbed, not modelled, and the absorption has a consequence this document must not hide. Assumption 3 (the arbitrageur pays a gas fee equal to its full profit) makes the arbitrageur's equilibrium payoff zero AND makes the arbitrage rent a DEADWEIGHT LOSS rather than a transfer — the latter only because miners/validators sit OUTSIDE the anchor's welfare agent set. **That assumption is contradicted by this document's own `### MEV` premises**: a top-of-block auction that recycles arbitrage rent to LPs, or an MEV tax, puts the recipient back inside the agent set and turns the rent into a transfer, under which the anchor's welfare ranking over \(\varsigma_{X/M}\) does not carry. A reader holding `### MEV` and `## ETA` in the same head must not import that ranking.

## **E6. [ADDITION — THE BRIDGE]**

\[
	\begin{aligned}
		\eta^{\star} \, = \, \frac{\ln\!\big((1+\varrho_I)/(1+\phi)\big)}{\Delta_i^{2}\,\ln\lambda},
		\qquad \varsigma_{X/M}(\eta^{\star},\Delta_i) \, = \, \varsigma_{X/M}^{\star}
	\end{aligned}
\]

Obtained by INVERTING E1's bijection at \(\varsigma_{X/M}^{\star}\): setting \(1 - \lambda^{-\Delta_i^{2}\eta/2} = 1 - \sqrt{(1+\phi)/(1+\varrho_I)}\) and taking logarithms. This is `Real.log` algebra on a closed form, NOT an existence argument.

Comparative statics: \(\eta^{\star} > 0 \iff \phi < \varrho_I\); strictly increasing in \(\varrho_I\); **strictly decreasing in \(\phi\)**. The dependence on \(\Delta_i\) is a NORMALIZATION IDENTITY rather than a comparative static: \(\varsigma_{X/M}^{\star}\) depends only on \((\phi,\varrho_I)\), and \(\eta^{\star} \propto 1/\Delta_i^{2}\) is simply whichever exponent reproduces that same \(\varsigma_{X/M}^{\star}\) on the chosen grid. Two-sided shape: \(D \circ \varsigma_{X/M}(\cdot,\Delta_i)\) is strictly increasing on \((0,\eta^{\star}]\) and strictly decreasing on \([\eta^{\star},\infty)\) under E4's hypotheses, INCLUDING \(c_1 > 0\).

ADMISSIBILITY OF THE FACTOR-SHARE READING. A factor share must lie in \((0,1)\), but \(\eta^{\star} \in (0,1)\) requires \(\Delta_i^{2}\ln\lambda > \ln((1+\varrho_I)/(1+\phi))\). At \(\lambda = 1.0001\), \(\varrho_I = 0.05\), \(\phi = 0.003\) this is \(\Delta_i \gtrsim 21\); at \(\Delta_i = 1\) and \(\Delta_i = 10\) — both in standard use — \(\eta^{\star} \approx 458\) and \(\approx 4.6\). So on a large part of the tick-spacing range the factor-share reading is not merely OPEN but UNAVAILABLE, and the grid-exponent reading is the only one. This is recorded here rather than left for a downstream reader to discover.

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

TWO ARBITRAGE MINIMANDS, NEVER INTERCHANGEABLE. Write **the \(\lambda_{\text{ARB}}\)-minimizer** for the Phase-11 object (`MevOptimization.mevMulti`, over \(\Theta_{\phi}\)) and **the \(\mathrm{arbLoss}\)-minimizer** for this section's (E2, over \(\varsigma_{X/M}\)). E8(3) says these are NOT identified, and nothing below identifies them.

Over \(\Theta_{\phi}\): `MevJointProgram.joint_corner_degeneracy` (T20) puts the FLAIR maximum and the \(\lambda_{\text{ARB}}\)-minimum at the SAME level corner, and `joint_beta_degeneracy` (T21) does the same for the shape block \((\beta_j,\gamma_j)\), the two together being robust to every linear scalarization with nonnegative weight (T22). There is no trade-off there.

**WHERE THE INTERIOR PEAK ACTUALLY COMES FROM — and it is NOT a weighting of two objectives.** Per E4, \(D\) = LP revenue from investor flow \(-\;\mathrm{arbLoss}\); the investor's SURPLUS is not a term of \(D\). The peak is produced by the LP revenue term alone, which is INCREASING in \(\varsigma_{X/M}\) below \(\varsigma_{X/M,I}\) and DECREASING above, because the investor's constraint switches from the corner regime (it drains the pool, A.41) to the interior regime (it curtails volume, A.40) exactly at \(\varsigma_{X/M,I}\). \(\mathrm{arbLoss}\) is monotone throughout and generates no peak at all; it only fixes, through \(c_1 > 0\), whether the post-peak decline survives. Below \(\varsigma_{X/M}^{\star}\) the surplus and the revenue sum to a constant (E5's zero-sum identity), so curvature there is a pure transfer and the pie is intact; above \(\varsigma_{X/M}^{\star}\) the pie itself shrinks.

**The "two antitone objectives, opposite corners, therefore an interior peak" reading is FALSE and is not made here.** On \([0,\varsigma_{X/M,S}]\) a nonnegative weighting \(w_1(-\mathrm{arbLoss}) + w_2\,\mathrm{surplus}\) has derivative \(\tfrac{w_1\mathbb{P}_{\Delta_{\text{ARB}}^{\text{CJ}}} - w_2}{2}\cdot\tfrac{1+\phi}{(1-\varsigma_{X/M})^2}\): sign CONSTANT and weight-determined, no interior crossing on that branch.

> CORRECTION (2026-07-31, ESC-1, recomputed): the generalization of the line above to EVERY branch is **FALSE**. \(\mathrm{arbLoss}\) and \(\mathrm{surplus}\) switch branches at DIFFERENT points (\(\varsigma_{X/M,S} < \varsigma_{X/M,I}\)) ⟹ on the middle region the two derivatives share no common positive factor and the weighted sum CAN cross zero strictly inside: \(+0.637\) at \(\varsigma_{X/M} = 0.19\) → \(-1.40\) at \(0.45\), crossing \(\approx 0.2412 \in (0.1835,\, 0.5)\), NO branch point. Correct claim (narrower): scalarization is not INCAPABLE of interior optima — it is simply not the SOURCE of this section's peak (E4's regime switch is), and Phase 11's T22 over \(\Theta_{\phi}\) is untouched (different model, different objects — E8(3)). Submitted bundle `4878ca32` carries the PRE-correction bytes with the false form explicitly PROHIBITED in its prompt; no requested theorem depends on it.

**WHAT THIS DOES AND DOES NOT DO TO THE PHASE-11 DEGENERACY.** It does NOT resolve it. `mevMulti` contains no η, no \(\varsigma_{X/M}\) and no \(\varrho_I\); nothing in E1–E6 moves it, so the \(\Theta_{\phi}\) degeneracy stands exactly where Phase 11 left it. What this section supplies is a SEPARATE model in which a curvature trade-off genuinely exists and its optimum is interior. The honest connection to Phase 11 is narrower and better than a de-degeneration claim: `MevJointProgram`'s MODULE docstring locates the escape in DEMAND RESPONSE, and `LEAN_TRACEABILITY` §6(b) records the missing layer as the demand-elasticity / optimal-fee equilibrium layer. \(\varrho_I\) is a CANDIDATE for that layer — a demand-side valuation parameter — though neither source names it. Closing the gap for real means ONE objective containing both a demand-elastic investor and \(\lambda_{\text{ARB}}\); that object exists in neither model and is **OPEN** (E8(7)).

**THE COUPLING, WITH ITS HYPOTHESES.** Under \(c_1(\phi) > 0\) and \(\phi < \varrho_I\), at any FIXED realized fee \(\phi\):

\[
	\begin{aligned}
		\frac{\partial \eta^{\star}}{\partial \phi} \, = \, \frac{-1}{(1+\phi)\,\Delta_i^{2}\,\ln\lambda} \, < \, 0
	\end{aligned}
\]

The mechanism: fee and curvature are SUBSTITUTE FRICTIONS on the investor's marginal cost. \(\varsigma_{X/M}^{\star} = \varsigma_{X/M,I}\) is the curvature at which the investor stops draining the pool; a higher fee already raises that marginal cost, so the drain regime ends at lower curvature. That is what makes the non-separability economic rather than a chain-rule artifact — and note the rent channel exists at \(\phi = 0\), so \(\phi\) modulates the optimum rather than creating it.

THREE BOUNDARIES ON THAT COUPLING, none of which may be dropped:

- \(c_1\) DEPENDS ON \(\phi\), and its sign at the fee corner is not pinned by anything here. Where \(c_1 \leq 0\) the anchor's own argument puts the pool in the freeze region, the LP payoff is flat in \(\varsigma_{X/M}\), and **no η is optimal at all** — \(\eta^{\star}\) is then not an argmax.
- FOLLOWING THE COUPLING TO ITS LIMIT SWITCHES THE CONTROLLER OFF: as \(\phi \to \varrho_I^{-}\), \(\varsigma_{X/M}^{\star} \to 0\) and \(\eta^{\star} \to 0^{+}\), which E1 identifies as the zero-curvature constant-price grid. Nothing in \(\Theta_{\phi}\) bounds its fee corner away from \(\varrho_I\), because \(\Theta_{\phi}\) comes from a model with no \(\varrho_I\) in it. So "η INTERIOR" is not uniform in \(\phi\).
- \(\bar\phi\) IS NOT \(\phi\). `VolInstrument.multiFee` has \(\bar\phi\) as its FLOOR, not its value (`multiFee_bounds`), and the realized fee is \(\sigma\)-dependent; the Phase-11 corner pins a \(\sigma\)-indexed fee PATH, not a scalar. The corner therefore lowers \(\eta^{\star}(\sigma)\) POINTWISE, giving a \(\sigma\)-indexed \(\eta^{\star}\) while η is a design constant of the grid. Reconciling those two is **OPEN** (E8(8)), and this whole section is stated at a fixed \(\phi\).

## **E8. [CAVEATS]**

1. **OPEN — THE IDENTIFICATION AND THE EQUILIBRIUM TRANSFER, BOTH.** (Now open for a PRECISE reason: E1's verdict block proves the identification HOLDS at Capponi \(\kappa = 1\) and FAILS at \(\kappa = 0\), and that \(\varsigma_{X/M}\) factors through the share \(\chi_{X/M}\) alone while Capponi's \(\kappa\) travels the \(\epsilon_{X/M}\) axis — `curvIndex_orientation_inconsistent`, `curvIndex_is_rho_zero_slice`. What remains open is the OBJECT-level and EQUILIBRIUM-level transfer, not the question of whether the two indices line up: they provably do not, except at the CPMM.) (a) OBJECT LEVEL: that \(\varsigma_{X/M}(\eta,\Delta_i)\) — a per-tick relative price step carrying no liquidity term — is the anchor's curvature index `k`, a mixing weight entering structurally in (A.31)/(A.39), is a MODELLING identification, not a definition (E1). (b) EQUILIBRIUM LEVEL: that the tick-grid AMM's arbitrage/investor equilibrium then HAS the anchor's closed forms with \(\varsigma_{X/M}(\eta,\Delta_i)\) in that slot is ASSUMED, not derived; deriving it means re-solving (A.31)/(A.39) on a discrete grid with per-tick liquidity. Every result above is a theorem about the displayed functions composed with \(\varsigma_{X/M}(\cdot,\Delta_i)\), and nothing above is a theorem about this project's AMM.
2. **OPEN — WELFARE.** Proposition 6's welfare half is NOT transcribed and does NOT follow from E3 + E4 (E5 gives the reason: the pieces move in opposite directions below \(\varsigma_{X/M}^{\star}\)). Only the deposit-efficiency half is transcribed. Additionally, the anchor's welfare ranking rests on arbitrage rent being a deadweight loss, which holds only because miners sit outside its agent set — an assumption this document's own `### MEV` section contradicts under rent recycling, so the ranking is not transferable here.
3. **OPEN — THE TWO ARBITRAGE OBJECTS ARE NOT IDENTIFIED.** \(\mathrm{arbLoss}\) and `MevOptimization.mevMulti` (\(\lambda_{\text{ARB}}\)) come from different models with different units — a two-period discrete-shock per-period ratio of pool value against a discrete hazard sum over \(D_t\). No identification is attempted or implied, as forcefully as M0 states that \(\lambda_{\text{ARB}}\) is a summand of \(\lambda_{\text{MEV}}\) and never a sibling.
4. **OPEN — GAS.** Assumption 3 (the arbitrageur pays a gas fee equal to its full profit) is absorbed, not modelled.
5. **OPEN — the \(\Theta_{\phi}\)-restricted σ-varying MEV comparison**, inherited from Phase 11 (`LEAN_TRACEABILITY` §7.1, last M6b row). This section does not touch it and must not appear to.
6. **OPEN — the factor-share identification** of E0(ii)/E6(ii): the grid exponent η and the reserve-side factor share of `L_eta` are the same parameter under different normalizations only up to a modelling claim; the exponent identity of E6(i) is proven algebra and is all that is claimed here. E6 records that the reading is not merely open but UNAVAILABLE wherever \(\eta^{\star} \notin (0,1)\), which includes the low tick spacings in standard use.
7. **OPEN — THE PHASE-11 DEGENERACY IS NOT RESOLVED HERE.** This section does not de-degenerate the \(\Theta_{\phi}\) program; `mevMulti` contains no η. Resolving it needs a single objective carrying both a demand-elastic investor and \(\lambda_{\text{ARB}}\), which exists in neither model (E7). \(\varrho_I\) is a candidate for the demand layer named in `LEAN_TRACEABILITY` §6(b), not a closure of it.
8. **OPEN — \(\eta^{\star}\) IS \(\sigma\)-INDEXED, η IS A DESIGN CONSTANT.** The fee entering \(\eta^{\star}\) is a fixed scalar \(\phi\), whereas this document's fee is \(\mathrm{multiFee}(\sigma)\) and \(\bar\phi\) is only its floor; the Phase-11 corner therefore induces \(\eta^{\star}(\sigma)\), while the grid exponent η is chosen once. Reconciling a state-dependent target with a fixed grid parameter is not addressed.
9. **OPEN — the strict single-peakedness boundary.** Under \(c_1 \leq 0\) the LP payoff is flat in \(\varsigma_{X/M}\) (E4) and \(\eta^{\star}\) is not an argmax; the sign of \(c_1\) at the fee corner is not pinned by anything in this section.

Further caveats: this is the anchor's two-period discrete-shock model, not MMR's fast-block diffusion of `### MEV`; the η-parametrization covers \((0,1) \subsetneq [0,1]\), so it neither reaches nor extends the anchor's corners and forbids any `η = 1` ⇔ `ς_{X/M} = 1` reading (E1); and \(\phi\) is here a FIXED fee, whereas this document's \(\phi = \mathrm{multiFee}(\sigma)\) varies — the transcription is at a fixed \(\phi\).

> LEAN (proved, `EtaCurvature`, **51/51 axiom-clean**, projects `4878ca32` + repair `c3a617f3`): E1–E3 `arbLossRatio_branch_agree/_strictAntiOn/_pos`, `kphiS_mem_Ioo`, `kphiS_eq_zero_of_eq`, `arbLossRatio_eq_zero_of_kphiS_eq_zero`, `surplusRatio_strictAntiOn`, `kphiS_le_kphiI_iff`. **E4 THE INTERIOR OPTIMUM**: `lpExcess_branch_agree_kphiS/_kphiI`, `lpExcess_strictMonoOn` on \([0,\varsigma_{X/M,I}]\), `lpExcess_strictAntiOn` on \([\varsigma_{X/M,I},1]\), `lpExcess_isMaxOn`, `kphiStar_eq_kphiI`, `kphiStar_mem_Ioo_iff` (interior ⟺ \(\phi < \varrho_I\)), `lpPayoff_isMaxOn`, `liquidity_freeze_minimal` (\(c_1 \leq 0\)) — the max rests on the TWO ONE-SIDED monotonicity results, **no FOC anywhere** (\(\varsigma_{X/M}^{\star}\) is a kink). E5 `depositEfficiency_branch_agree/_isMaxOn`, `surplus_add_revenue_const` (zero-sum). **E6 THE BRIDGE**: `priceEta_step_ratio`, `curvIndex_eq_of_priceEta`, `curvIndex_mem_Ioo`, `curvIndex_strictMono`, `curvIndex_tendsto_zero/_one`, **`curvIndex_etaStar`** (\(\varsigma_{X/M}(\eta^{\star}) = \varsigma_{X/M}^{\star}\)), `etaStar_pos_iff`, `etaStar_strictMono_premInv`, `etaStar_strictAnti_fee/_spacing`, η-transport `lpExcessEta_isMaxOn/_strictMonoOn/_strictAntiOn`, and **T28'a `priceEta_eq_p_eta_half` / `priceEta_eq_P_half`** (the η-identity EXPONENT half — DISCHARGED). E7 `eta_no_common_argmax`, `etaStar_coupled_to_fee_corner`.
> AMENDED (added hypotheses, conclusions intact): `lpExcess_strictAntiOn` + \(\phi < \varrho_S \leq \varrho_I\) (E0's own standing order, needed so the shock branch point does not sit above the investor switch); `etaStar_pos_iff` + \(-1 < \varrho_I\) — Mathlib's `Real.log` is \(\log|x|\), so the unguarded criterion is FALSE (witness \(\varrho_I = -3,\ \phi = 0\)). T28'b (factor-share half) ABSENT as pre-authorized ⟹ E8(6) stays **OPEN**; it was NOT satisfied by restating T28'a.

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

The sensitivity operator (NEW symbol; `\mathcal{D}` unused in this document — in-use mathcal: 𝒞, ℰ, 𝒢_φ, ℛ, 𝒰): <!-- notation-map -->

\[
	\begin{aligned}
		\mathcal{D}_x \, [\pi] \, &\equiv \, \frac{\Delta \pi}{\Delta x}, \qquad \mathcal{D}^2_x \, [\pi] \, \equiv \, \frac{\Delta}{\Delta x}\Big( \mathcal{D}_x[\pi] \Big)
	\end{aligned}
\]

External delta `Δ`/`δ` → \(\mathcal{D}_p[\pi]\), \(p = p_{(\eta, \Delta_i)}(i;t)\) (`Δ` is this document's difference operator; `δ_S, δ_R` are J1's swap curves). <!-- notation-map -->
External gamma → \(\Gamma \equiv \mathcal{D}^2_p[\pi]\); bare `Γ` is FREE here and is bound to gamma ONLY; the sigmoid steepness is ALWAYS subscripted `γ_j` (mirror of the κ/ς_{X/M} rule). <!-- notation-map -->
External theta Θ → IDENTIFIED with this document's \(\theta \equiv \Delta\pi/\Delta t\) (the exponent-sign FLAG — RESOLVED 2026-08-03, negative — on its display stands); `Θ_•` remains parameter-set notation and is never a Greek. <!-- notation-map -->
External vega ν → NEVER imported (`ν_t = w_t/D_t`, M6b); all vegas through \(\upsilon \equiv \Delta\pi/\Delta\sigma^2\) (bound, = t/2); σ-convention vega is written \(2\,\sigma(i(t))\,\upsilon\). <!-- notation-map -->
Maymin's liquidity Greek `Λ = ∂C/∂k` → \(\mathcal{D}_{\bar L}[C]\) (Greek of the LONG CALL C, Def 2 eq (33) — NOT of π) via \(k = \bar L^2\) (CPMM), his \(\Lambda = \mathcal{D}_{\bar L}[C]/(2\bar L)\); `Λ(·)` stays the logistic. <!-- notation-map -->
Maymin's emission Greek `E = ∂C/∂e` → \(\mathcal{D}_{\Delta Q_M}[C]\) (Def 2 eq (34), again a C-Greek; our emission policy IS the ΔQ_M schedule). <!-- notation-map -->
Maymin's CEV exponent `β = w` = the NUMERAIRE weight (his §3.2 eq (4)–(5): \(x^w y^{1-w} = K\), \(x\) = numeraire, \(P = \tfrac{1-w}{w}\tfrac{x}{y}\)) → \(w = 1 - \eta_L\), i.e. \(\eta_L = 1 - w\) = the ASSET share (eta.md line 12: \(L = X^{\eta}Y^{1-\eta}\), \(P\) = price of \(X\) in \(Y\) ⟹ η = exponent on the ASSET). ORIENTATION DECIDED AT FORMULA LEVEL by eq (12): \(P \propto x^{1/(1-w)} \implies \partial_x P = \tfrac{1}{1-w}\tfrac{P}{x}\), and \(x = P^{1-w}(\tfrac{w}{1-w})^{1-w}K\), so \(\delta = \tfrac{1}{1-w}\big(\tfrac{1-w}{w}\big)^{1-w}K^{-1}\sigma_F\) EXACTLY — the \(1/(1-w)\) prefactor is the reciprocal of the ASSET weight, and the \(w \leftrightarrow 1-w\) swap gives \(\tfrac{1}{w}(\tfrac{w}{1-w})^{w}K^{-1}\sigma_F\), ≠ eq (12) for \(w \neq \tfrac12\). \(\eta_L = \eta\) is E8(6) and remains OPEN — no display below assumes it. <!-- notation-map -->
Maymin's `δ` (CEV vol coefficient) → eliminated through primitives: \(\sigma(i(t)) = \delta\, p^{\,\beta-1} = \delta\, p^{-\eta_L}\) (his σ_ret, Prop 4 eq (20), under \(\beta = w = 1-\eta_L\)) and CPMM \(\delta = 2\sigma_Q/\bar L\) (eq (12) at \(w = \tfrac12\), \(K = \bar L\)); his flow vol `σ_F` → \(\sigma_Q\) (σ̄_f is the FeeSchedule strike); his invariant `K` → \(\bar L\); his strike `K_str` → \(K\); his `κ` (eq 23) → \(c_0\) (bare κ FORBIDDEN); his CDF `χ²(x;n,·)` → \(\mathbb{P}_{Y_{n,\cdot} \leq x}\) (probability-typed ⟹ ℙ_{event}; χ banned). <!-- notation-map -->
Bardoscia's `V0` → \(\Delta Q_M\) (V₀ is CJZ's, J5); his APY `φ` → eliminated in TWO commensurable forms, always labelled (B1): SCHEDULE-LEVEL per-unit carry \(\phi(\sigma_t)\,\nu_t\) (M6b's own units, \(\nu_t = w_t/D_t\), what \(\lambda_{\text{FLAIR}}\) sums) and POSITION-LEVEL carry \(\phi(\sigma_t)\,\nu_t\,\Delta Q_M\) (what an LP position of money leg ΔQ_M earns); his `S_t` → \(p_{(\eta, \Delta_i)}(i;t)\); maturity `T`, remaining `τ = T−t` → \(T^{\star}\), \(T^{\star}-t\) (τ is τ_MEV — NEVER time). <!-- notation-map -->
Demeterfi's `S*` → \(p^{\star}\); his variance vega `V = (T−t)/T` (a REMAINING-CALENDAR-TIME ratio) → \(\upsilon\) under this document's normalization, where the argument of \(\upsilon = t/2\) is the MATURITY PARAMETER \(t\), not calendar time: at inception \(\upsilon = T^{\star}/2\), and the calendar-time form is \(\upsilon(t) = (T^{\star}-t)/2\) (`variancePortfolio_upsilon`; t-SEMANTICS clause, G6(7)). <!-- notation-map -->
Band edges `p_a, p_b` / `a, b` (Clark, Fateh–Singh) → \(p(i_l), p(i_u)\); Clark's reserves `R_α, R_β` → cumulative \(\Delta Q_X, \Delta Q_M\) (`VolInstrument.cumulativeQX/QM`); Kristensen's range factor `r` → \(\lambda_{\text{tick}}^{\iota\Delta_i}\) (through its own primitive). <!-- notation-map -->
Bichuch–Feinstein's LVR rate `ℓ(q)` → eliminated: \(a_t \equiv \ell_{\text{BF}}(\cdot)\,\Delta t\) (M0/M3; `ℓ` here stays the weight \(\ell(\xi,\iota;i_K)\)); their implied vol `σ*_x` → \(\sigma^{\star}_{\phi}\) (fee-implied); Fateh–Singh's installment rate `q` → \(q_{\text{CI}}\) (`q_R, q_S` are CJZ's). <!-- notation-map -->
Any probability reading of delta ("ATM delta = 50%") is written \(\mathbb{P}_{\text{ITM}}\), never δ. <!-- notation-map -->

## **G1. [ADDITION] The Greek ladder of the LP-payoff kernel**

Per tick \(i_K\), band \([i_l, i_u]\), sqrt-price convention (`PosSpec.tickPrice`), \(L(i_K) = \bar L\,\ell(\xi,\iota;i_K)\):

\[
	\begin{aligned}
		\mathcal{D}_p[\pi]\,(i_K) \, &= \,
		\begin{cases}
			\Delta Q_X(i_K) & p \leq p(i_l) \\
			L(i_K)\,\Big( p^{-1/2} - p(i_u)^{-1/2} \Big) & p(i_l) < p < p(i_u) \\
			0 & p \geq p(i_u)
		\end{cases} \\
		\Gamma\,(i_K) \, &= \,
		\begin{cases}
			-\tfrac{1}{2}\, L(i_K)\, p^{-3/2} & p(i_l) < p < p(i_u) \\
			0 & \text{otherwise}
		\end{cases}
		\, = \, -\tfrac{1}{2}\,\bar L\,\ell(\xi,\iota;i_K)\,p^{-3/2}\,\mathbb{1}_{(i_l,i_u)}
	\end{aligned}
\]

> Clark: value eq (10), delta = the UNNUMBERED §4.2 p. 5 display (`L/√p − L/√p_b` in-range, current p), gamma = eq (12) (`−½Lp^{−3/2}`); eq (13) is Green–Jarrow spanning, never cite it for a Greek. Kristensen eq (3.21)/(3.24). Γ jumps at the band edges (the bounded-range correction); \(\mathcal{D}_p\) is continuous, kinked. LEAN: the value layer is `Flow.terminalPayoff` + `GeomProfile.geom_terminalPayoff_total`; the \(\mathcal{D}_p, \Gamma\) displays are UNFORMALIZED (bundle targets).

Aggregate over the ladder (partition of unity `geomWeight_sum`):

\[
	\begin{aligned}
		\Gamma^{\Sigma}(p) \, &= \, -\tfrac{1}{2}\,\bar L\, p^{-3/2} \sum_{i_K}\,\ell(\xi,\iota;i_K)\,\mathbb{1}_{p \in (i_l,i_u)(i_K)} \\
		\xi = \xi^{\star} = \lambda_{\text{tick}}^{-\Delta_i/2} \; &\implies \; \Gamma^{\Sigma}\big(p(i_K)\big)\, p(i_K)^2 \, = \, \text{const in } i_K \quad \textbf{(GRID-EXACT)} \\
		\text{but pointwise, inside band } i_K: \; \Gamma^{\Sigma}p^2 \, &= \, -\tfrac{1}{2}\,\bar L\,\ell(\xi^{\star},\iota;i_K)\, p^{1/2} \;\propto\; p^{1/2}, \quad \text{swing } \lambda_{\text{tick}}^{\Delta_i/2} \text{ per band} \quad \textbf{(BAND-MODULATED)}
	\end{aligned}
\]

> Flat dollar gamma holds ON THE GRID, not pointwise: the log contract = the variance claim is the tick-indexed statement, PROVEN as `varswapWeight_geometric` / `logContractLiquidity_geometric` (Demeterfi EQ 11 Γ = (2/T)S⁻², 1/K² strike weighting pp. 9–10). The continuum "Γp² = const" is FALSE inside a band and must never be bundled as stated.

Theta splits; the dt-leg is REDUNDANT given (Γ, σ):

\[
	\begin{aligned}
		\theta \, &= \, \theta_{\text{fee}} \, - \, \theta_{\text{decay}}, \qquad
		\theta_{\text{decay}} \, + \, \tfrac{1}{2}\,\Gamma\, p^2\, \sigma^2(i(t)) \, = \, 0 \\
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
		\mathcal{D}_{\bar L}[C] \, &< \, 0 \quad \big(\delta = 2\sigma_Q/\bar L \implies \tfrac{\Delta\sigma}{\sigma} = -\tfrac{\Delta \bar L}{\bar L}\big), \qquad
		\mathcal{D}_{\Delta Q_M}[C] \, < \, 0, \qquad
		\bar v^2 \, = \, \frac{4\sigma_Q^2}{\dot{\bar k}} \ln\Big(1 + \frac{\dot{\bar k}\,T^{\star}}{\bar L_0^2}\Big), \;\; \dot{\bar k} \equiv \tfrac{\Delta (\bar L^2)}{\Delta t} \\
		\text{LP-side composition: } \; \mathcal{D}_{\bar L}[\pi] \, &= \, \frac{\Delta\pi}{\Delta\sigma^2}\cdot\frac{\Delta\sigma^2}{\Delta\bar L} \, = \, (\underbrace{<0}_{\text{short vega}})\cdot(\underbrace{<0}_{\text{depth compresses }\sigma}) \, \geq \, 0
	\end{aligned}
\]

> OBJECT TYPING (B3): Maymin Def 2 eq (33)–(34) and Prop 10 eq (41) are Greeks of the LONG CALL \(C\) ON the AMM token — \(\Lambda = \partial C/\partial k < 0\) ("deeper pools reduce option value by compressing volatility"), \(E = \partial C/\partial e < 0\) (emissions = our ΔQ_M schedule, bang-bang PROVEN `Flow.schedule_isLeast`, act as a dividend-yield-like variance drain). NO LP-side sign is imported: on π the depth Greek composes through the short vega and comes out with the OPPOSITE sign, \(\mathcal{D}_{\bar L}[\pi] \geq 0\) (a deeper pool damps σ, and the short-vol LP GAINS from that). C-Greeks and π-Greeks are distinct rows; both are hooks the classic BS set does not have.

The skew law (Maymin Thm 1 eq (11)–(12) + Prop 4 eq (20) + Prop 5), stated on \(\eta_L\), NOT on η, at the RESOLVED orientation \(\beta = w = 1-\eta_L\) (G0):

\[
	\begin{aligned}
		dp \, = \, \mu(p)\,dt \, + \, \delta\, p^{\,1-\eta_L}\, dW, \qquad \sigma(i(t)) = \delta\,p^{\,-\eta_L};\qquad
		\frac{\sigma_{IV}(K)}{\sigma_{IV}^{ATM}} \, = \, f(K/p;\, \eta_L) \quad \text{— independent of } \delta \text{ and } \bar L
	\end{aligned}
\]

> ORIENTATION (decided against eq (12), NOT at the invisible \(w = \eta_L = \tfrac12\) point): \(\eta_L\) ≡ ASSET share (eta.md:12), Maymin \(w\) ≡ NUMERAIRE weight (§3.2) ⟹ \(w = 1-\eta_L\), CEV exponent \(= 1-\eta_L\). LEVERAGE: \(\sigma \propto p^{-\eta_L}\) ↓ in \(p\) ∀ \(\eta_L > 0\), steepening in \(\eta_L\) (negative price-elasticity-of-variance, Bittensor §6). ATM-normalized skew depends ONLY on \(\eta_L\) — depth-invariant, testable. Grid-η transfer requires E8(6) \((\eta_L = \eta)\), OPEN — not assumed here.

## **G3. [CONTROL MATRIX]**

● = appears in the display; ○ = equilibrium-only / mediated (subscript names the mediator); — = provably absent.
LEVEL: every row is POSITION-LEVEL (B1) — θ_fee means \(\theta_{\text{fee}}^{\text{pos}} = \phi(\sigma_t)\nu_t\Delta Q_M\), and the hazard rows are the schedule-level ledgers they aggregate to.

\[
	\begin{array}{l|cccccccc}
		 & (\xi,\iota) & (\eta,\Delta_i)\to\varsigma_{X/M} & \bar L & (\bar\phi,\alpha,u) & (\beta_j,\gamma_j) & T^{\star} & \tau,\tau_{\text{JIT}} & \text{haz. inputs }(\sigma\text{-path},w_t,D_t) \\
		\hline
		\mathcal{D}_p[\pi] & \bullet & \bullet & \bullet & - & - & - & - & - \\
		\Gamma & \bullet & \bullet & \bullet & - & - & - & - & - \\
		\upsilon\,(=t/2) & \circ_{\;\xi=\xi^{\star}} & - & - & - & - & \bullet & - & - \\
		\theta_{\text{fee}}^{\text{pos}} & \circ & \circ & \circ_{\;\text{via }\nu_t} & \bullet & \bullet & - & \circ_{\;\text{carve-out}} & \bullet \\
		\Delta\theta_{\text{fee}}/\Delta\sigma & - & - & \circ_{\;\text{via }\nu_t} & \bullet & \bullet & - & - & \bullet \\
		\mathcal{D}_{\bar L}[\pi] & \circ & \circ & \bullet & - & - & - & - & - \\
		\mathcal{D}_{\Delta Q_M}[\pi] & - & - & \bullet & - & - & \circ & - & - \\
		\sigma_{IV}/\sigma_{IV}^{ATM}\;[\textbf{DIAG}] & - & \bullet_{\;\text{uncond. in }\eta_L;\;\text{cond. on }E8(6)} & - & - & - & - & - & - \\
		\lambda_{\text{FLAIR}} & - & - & \circ & \bullet & \bullet & - & \bullet & \bullet \\
		\lambda_{\text{ARB}} & - & \bullet_{\;\eta^{\star}} & \circ & \bullet_{\;\mathbb{P}_{\Delta_{\text{ARB}}}} & \circ & - & \bullet & \bullet \\
		\tilde\lambda_{\text{JIT}} & - & \circ_{\;\text{J9 TO PROVE}} & \circ & \circ & - & - & \bullet_{\;\tau_{\text{JIT}}} & \bullet
	\end{array}
\]

> ROW COUNT (M3): 11 matrix rows, \(|\mathcal{T}| = 10\) design targets — the gap is the \(\sigma_{IV}/\sigma_{IV}^{ATM}\) row, declared **DIAGNOSTIC**: it is an OBSERVABLE (a depth-invariant identification readout for \(\eta_L\)), not a design target, and is excluded from \(\mathcal{T}\) and from every deficit count in G4. The \(\theta_{\text{fee}}^{\text{pos}}\) row's \(\bar L\) and \(\tau\) entries are ○, not ●: \(\bar L\) enters only through \(D_t\) inside \(\nu_t = w_t/D_t\), and \(\tau\) only through the tax carve-out — neither symbol appears in the display itself.

THE (β,γ) ROW, RESOLVED: \((\beta_j,\gamma_j)\) are ABSENT from every payoff-shaping Greek (\(\mathcal{D}_p, \Gamma, \upsilon\) — confirming (ξ,ι) as the shaping base) and BIND exactly in the carry profile, in both B1 forms:

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
		\mathcal{T} \, &= \, \{\mathcal{D}_p,\; \Gamma,\; \upsilon,\; \theta_{\text{fee}}^{\text{pos}},\; \Delta\theta_{\text{fee}}/\Delta\sigma,\; \mathcal{D}_{\bar L},\; \mathcal{D}_{\Delta Q_M},\; \lambda_{\text{FLAIR}},\; \lambda_{\text{ARB}},\; \tilde\lambda_{\text{JIT}}\}, \quad |\mathcal{T}| = 10 \\
		&\quad (\theta_{\text{decay}} \text{ excluded: redundant by Demeterfi EQ 12};\;\; \sigma_{IV}/\sigma_{IV}^{ATM} \text{ excluded: DIAGNOSTIC, G3};\;\; \lambda_{\text{MEV}} \text{ excluded: the } \oplus\text{-sum}) \\
		\#\text{free} \, &= \, \underbrace{\iota,\, \bar L}_{2} \, + \, \underbrace{(\beta_j,\gamma_j)}_{2n} \, + \, \underbrace{T^{\star}}_{1} \, + \, \underbrace{\tau,\, \tau_{\text{JIT}}}_{2} \, + \, \underbrace{\Delta Q_M\text{-schedule}}_{1} \, = \, 6 + 2n
		\qquad (\xi = \xi^{\star},\; \eta = \eta^{\star},\; \Delta_i \text{ venue-quantized},\; (\bar\phi,\alpha,u) \text{ pinned by the level program — M4 caveat applies})
	\end{aligned}
\]

Raw count \(6+2n \geq 10\) **for \(n \geq 2\)** — the deficit is STRUCTURAL (block-triangular matrix), not numeric:

\[
	\begin{aligned}
		\text{shape rows } \{\mathcal{D}_p, \Gamma, \upsilon\text{-flatness}\}\;(3) \; &\text{reachable only through } \{\xi,\iota,\eta,\Delta_i,\bar L\} \implies 2 \text{ free for } 3: \; \textbf{deficit } 1 \\
		\text{ladder resolution: } \{\ell(i_K)\}_{i_K} \in \Delta^{\iota-1} \; &\text{vs the pinned-ξ geometric curve (dim } 1\text{)}: \; \textbf{deficit } \iota - 2 \\
		(\beta_j,\gamma_j) \; &\text{cannot close it: their column is } 0 \text{ on every shape row}
	\end{aligned}
\]

> FUTURE MILESTONE (user-declared, NOT executed here): \(\ell(\xi,\iota;\cdot) \rightsquigarrow \ell_{\text{LDF}}(\theta_{\text{LDF}}; i_K)\), \(\sum_{i_K}\ell_{\text{LDF}} = 1\) — bunni-v2.pdf §2.2 (\(l_r = L\cdot LDF_w(r)\)), geometric = §2.2.1 base example; \(\dim\theta_{\text{LDF}} \geq \iota-2\) ⟹ ladder deficit 0. Hazard rows: deficit 0 already (\(\bar\phi,\alpha,u,\tau,\tau_{\text{JIT}},\eta^{\star}\)).

## **G5. [EVM]**

\[
	\begin{aligned}
		\text{EXACT on-chain: } & \mathcal{D}_p\text{-ladder},\; \Gamma\text{-ladder (sqrtPriceX96, ticks, } L\text{; } p^{3/2} = \text{mulDiv chain)},\; \upsilon = t/2,\; \theta_{\text{fee}} \text{ ex-post (feeGrowthInside, streamia)} \\
		\text{APPROXIMABLE: } & \phi(\sigma)\text{ (expWad logistic)},\; \theta_{\text{decay}} \text{ (expWad+sqrt; sign RESOLVED: negative)},\; \sigma^2(i(t)) \text{ (E2/E5 ledger — see caveat)},\; \mathcal{D}_{\bar L}[\pi] \text{ (relative form exact)} \\
		\text{OFF-CHAIN: } & \text{CEV prices and } \mathbb{P}_{Y_{n,c}\le x} \text{ tails},\; \sigma^{\star}_{\phi} \text{ inversion},\; \mathcal{D}_{\bar L}[C],\; \mathcal{D}_{\Delta Q_M}[C] \text{ model values (lnWad for } \bar v^2\text{; schedule input exact)}
	\end{aligned}
\]

> \(\sigma^2(i(t))\) CAVEAT: v4 has no built-in TWAP, and E2/E5 feed the OFF-chain subgraph reader (events→subgraph→GAMS layer) — so "APPROXIMABLE on-chain" presupposes EITHER an oracle hook OR a NEW on-chain accumulator (sum of squared int24 tick increments, Δt-weighted in seconds). Nothing in today's E-layer delivers \(\sigma^2\) to a contract.

## **G6. [CAVEATS / OPEN]**

1. θ exponent-sign FLAG — **RESOLVED 2026-08-03 (negative)**; G1's θ_decay and the on-chain constant are unblocked.
2. E8(6) \(\eta_L = \eta\) — OPEN; G2's skew law is an η_L statement until it closes.
3. \(\mathcal{D}_p, \Gamma\) ladder displays, the θ split, the \(\Delta\theta_{\text{fee}}/\Delta\sigma\) statics, and the G4 deficit lemmas are UNFORMALIZED — the Aristotle bundle for this section. **G2: OFF-BUNDLE — analytic content (CEV pricing, noncentral χ², implied-vol inversion) beyond Mathlib v4.28.** Every bundled θ_fee statement MUST name which B1 form it formalizes (schedule-level \(\phi\nu_t\) or position-level \(\phi\nu_t\Delta Q_M\)); the two are not interchangeable and a mixed statement is unprovable.
4. Carry-profile objective: per-event (M6b) vs time-integrated (λ_FLAIR) statement — decide before bundling; the M2 hedge claim needs the time-integrated form.
5. 2n sigmoid parameters match ≤ 2n carry-profile moments — re-count if the hazard ladder demands finer σ-resolution.
6. Natenberg local copy is image-only (no text layer); classical displays are anchored to Demeterfi/Bardoscia instead. Lababidi (Greek.fi) contains no Greek formulas — infrastructure reference only.
7. t-SEMANTICS (G1 clause) — the maturity \(T\) (\(\upsilon = T/2\), \(= T^{\star}/2\) at inception) vs calendar \(t\) (\(T^{\star}-t\) in the locked vega): stated, not yet carried into the Lean signatures.


## IMPLIED VOLATILTIY


THere is the Kristensen pdf on perpetula options which defines implied volatility \sigma^2_{IV} (t) as a 2\phi \sqrt{\frac{\varphi_{\chi, \epsilon} (\int_{t_0}^t) (some metric of ytrading volume)}{"The AMT_{tick}"}} semes to map to the L_{(\xi, \iota)}(i) but also an integrated quantity over time. W ebn eed to bring the pdf to refs AND brainstomr how to include this to the fraework formally the 2 and sqrt root might be an special case of traidijg ncurve parameters to 1/2. Also the priceOf risk on the plank branch seems to be the entry point for opportunity cost comparsion against fixed income yiled rates (interest rates). Note that there is a section on Krsitensen ion holding an LP vs lending it which might conbnect comparing priceOfRisk against exogenously given interet rates . The ratio VOL / AMT has a firect mapping but myust be proved explicityl to th eutiliation u


## OTHER KRSITENSEN CONNECTIONS

Our maturity T which is endogenously controlled by the specified target vega and controlled by liquiditations needs to be connected to the T_{ITM} /T = \int_{t_O}^{T} \mathbb{P}_{[i_l, i_u]} dt / T as defined on Krsitensen and see what can ew leverage from there
