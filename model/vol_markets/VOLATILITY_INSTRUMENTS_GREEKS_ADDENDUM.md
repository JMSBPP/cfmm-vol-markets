# APPROVED + INSERTED addendum to `VOLATILITY_INSTRUMENTS.md` — the `## GREEKS` section: the Greek ladder of the LP-payoff kernel and the (β,γ) carry role

> STATUS: INSERTED 2026-07-31 (HEAVY USER APPROVAL granted) into
> ../plank/notes/VOLATILITY_INSTRUMENTS.md `## GREEKS`, appended after the
> user's section prose (never edited). Two-reviewer gate passed (3 BLOCKERs +
> 7 MAJORs resolved, commit 2460f7f). This file remains the spec of record.
> Research record: `.planning/greeks/GREEKS-RESEARCH.md` (anchors for every display).
> Anchors: Bardoscia–Nodari arXiv:2302.11942v3 (§3.1 pp. 6–8, §3.3 pp. 10–13);
> Maymin arXiv:2603.29763v1 (Thm 1 eq (11)–(13), Prop 4 eq (20), Prop 5,
> Thm 7 eq (22)–(27), Def 2 eq (31)–(34), Prop 10 eq (41));
> Demeterfi et al., GS QSRN 1999 (EQ 8–12, pp. 11–12);
> Clark SSRN 3898384 (value eq (10); delta = the UNNUMBERED display in §4.2 "Greeks", p. 5; gamma = eq (12); eq (13) = the Green–Jarrow spanning formula of §5, NOT a Greek);
> Kristensen 2024 (eq (3.21)–(3.24)); Fateh Singh et al. arXiv:2508.02971v1 (eq (3)–(8); the q→∞ funding-equals-LVR limit = abstract/§1 prose + their Lemmas 1 and 3, NOT eq (7)–(8)); Bichuch–Feinstein 2025 (Thm 4.2, Thm 5.1).
> Frame: LPing = shorting an option. OBJECT TYPING (load-bearing): Bardoscia §3.1/§3.3, Clark §4.2, Kristensen (3.21)/(3.24), Fateh–Singh eq (4) price the LP position π directly (Γ < 0, short vol); Demeterfi's log-contract portfolio is the LONG side; Maymin Def 2 eq (31)–(34) prices a LONG EUROPEAN CALL C **on** the AMM token — his Δ_CEV, Γ_CEV, Λ, E are Greeks of C, an object DISTINCT from π, and every LP-side reading of them requires an explicit composition (G2).
> η PROTECTED (pricing-kernel exponent); probabilities ℙ_{event}; curvature
> κ_φ never χ; τ is τ_MEV and is NEVER a time variable in this section.

## **G0. [NOTATION-MAP]**

The sensitivity operator (NEW symbol; `\mathcal{D}` unused in this document — in-use mathcal: 𝒞, ℰ, 𝒢_φ, ℛ, 𝒰): <!-- notation-map -->

\[
	\begin{aligned}
		\mathcal{D}_x \, [\pi] \, &\equiv \, \frac{\Delta \pi}{\Delta x}, \qquad \mathcal{D}^2_x \, [\pi] \, \equiv \, \frac{\Delta}{\Delta x}\Big( \mathcal{D}_x[\pi] \Big)
	\end{aligned}
\]

External delta `Δ`/`δ` → \(\mathcal{D}_p[\pi]\), \(p = p_{(\eta,\Delta_i)}(i;t)\) (`Δ` is this document's difference operator; `δ_S, δ_R` are J1's swap curves). <!-- notation-map -->
External gamma → \(\Gamma \equiv \mathcal{D}^2_p[\pi]\); bare `Γ` is FREE here and is bound to gamma ONLY; the sigmoid steepness is ALWAYS subscripted `γ_j` (mirror of the κ/κ_φ rule). <!-- notation-map -->
External theta Θ → IDENTIFIED with this document's \(\theta \equiv \Delta\pi/\Delta t\) (the exponent-sign FLAG on its display stands); `Θ_•` remains parameter-set notation and is never a Greek. <!-- notation-map -->
External vega ν → NEVER imported (`ν_t = w_t/D_t`, M6b); all vegas through \(\upsilon \equiv \Delta\pi/\Delta\sigma^2\) (bound, = t/2); σ-convention vega is written \(2\,\sigma(i(t))\,\upsilon\). <!-- notation-map -->
Maymin's liquidity Greek `Λ = ∂C/∂k` → \(\mathcal{D}_{\bar L}[C]\) (Greek of the LONG CALL C, Def 2 eq (33) — NOT of π) via \(k = \bar L^2\) (CPMM), his \(\Lambda = \mathcal{D}_{\bar L}[C]/(2\bar L)\); `Λ(·)` stays the logistic. <!-- notation-map -->
Maymin's emission Greek `E = ∂C/∂e` → \(\mathcal{D}_{\Delta Q_M}[C]\) (Def 2 eq (34), again a C-Greek; our emission policy IS the ΔQ_M schedule). <!-- notation-map -->
Maymin's CEV exponent `β = w` = the NUMERAIRE weight (his §3.2 eq (4)–(5): \(x^w y^{1-w} = K\), \(x\) = numeraire, \(P = \tfrac{1-w}{w}\tfrac{x}{y}\)) → \(w = 1 - \eta_L\), i.e. \(\eta_L = 1 - w\) = the ASSET share (eta.md line 12: \(L = X^{\eta}Y^{1-\eta}\), \(P\) = price of \(X\) in \(Y\) ⟹ η = exponent on the ASSET). ORIENTATION DECIDED AT FORMULA LEVEL by eq (12): \(P \propto x^{1/(1-w)} \implies \partial_x P = \tfrac{1}{1-w}\tfrac{P}{x}\), and \(x = P^{1-w}(\tfrac{w}{1-w})^{1-w}K\), so \(\delta = \tfrac{1}{1-w}\big(\tfrac{1-w}{w}\big)^{1-w}K^{-1}\sigma_F\) EXACTLY — the \(1/(1-w)\) prefactor is the reciprocal of the ASSET weight, and the \(w \leftrightarrow 1-w\) swap gives \(\tfrac{1}{w}(\tfrac{w}{1-w})^{w}K^{-1}\sigma_F\), ≠ eq (12) for \(w \neq \tfrac12\). \(\eta_L = \eta\) is E8(6) and remains OPEN — no display below assumes it. <!-- notation-map -->
Maymin's `δ` (CEV vol coefficient) → eliminated through primitives: \(\sigma(i(t)) = \delta\, p^{\,\beta-1} = \delta\, p^{-\eta_L}\) (his σ_ret, Prop 4 eq (20), under \(\beta = w = 1-\eta_L\)) and CPMM \(\delta = 2\sigma_Q/\bar L\) (eq (12) at \(w = \tfrac12\), \(K = \bar L\)); his flow vol `σ_F` → \(\sigma_Q\) (σ̄_f is the FeeSchedule strike); his invariant `K` → \(\bar L\); his strike `K_str` → \(K\); his `κ` (eq 23) → \(c_0\) (bare κ FORBIDDEN); his CDF `χ²(x;n,·)` → \(\mathbb{P}_{Y_{n,\cdot} \leq x}\) (probability-typed ⟹ ℙ_{event}; χ banned). <!-- notation-map -->
Bardoscia's `V0` → \(\Delta Q_M\) (V₀ is CJZ's, J5); his APY `φ` → eliminated in TWO commensurable forms, always labelled (B1): SCHEDULE-LEVEL per-unit carry \(\phi(\sigma_t)\,\nu_t\) (M6b's own units, \(\nu_t = w_t/D_t\), what \(\lambda_{\text{FLAIR}}\) sums) and POSITION-LEVEL carry \(\phi(\sigma_t)\,\nu_t\,\Delta Q_M\) (what an LP position of money leg ΔQ_M earns); his `S_t` → \(p_{(\eta,\Delta_i)}(i;t)\); maturity `T`, remaining `τ = T−t` → \(t^{\star}\), \(t^{\star}-t\) (τ is τ_MEV — NEVER time). <!-- notation-map -->
Demeterfi's `S*` → \(p^{\star}\); his variance vega `V = (T−t)/T` (a REMAINING-CALENDAR-TIME ratio) → \(\upsilon\) under this document's normalization, where the argument of \(\upsilon = t/2\) is the MATURITY PARAMETER \(t\), not calendar time: at inception \(\upsilon = t^{\star}/2\), and the calendar-time form is \(\upsilon(t) = (t^{\star}-t)/2\) (`variancePortfolio_upsilon`; t-SEMANTICS clause, G6(7)). <!-- notation-map -->
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
		\upsilon \, = \, \frac{t}{2} \quad (\text{PROVEN}) \qquad \implies \qquad \upsilon \; \text{is controlled by } t^{\star} \text{ alone}; \qquad
		\text{locked-LP short vega (Bardoscia §3.3.5): } \; \frac{\Delta \pi}{\Delta \sigma^2} = -\tfrac{t^{\star}-t}{8}\,(\text{asset leg})
	\end{aligned}
\]

> t-SEMANTICS (convention clause, binding for the whole section): the \(t\) in \(\upsilon = t/2\) is the MATURITY PARAMETER of the claim — \(\upsilon = t^{\star}/2\) at inception — whereas the \(t\) in Bardoscia's locked vega is CALENDAR time, entering only through the remaining span \(t^{\star}-t\). Calendar-time form of the same object: \(\upsilon(t) = (t^{\star}-t)/2\); the two coincide at \(t = 0\). Same remap for Demeterfi's `V = (T−t)/T` (G0). No display below mixes the two readings.

## **G2. [ADDITION] Depth and emission Greeks; the η_L skew law**

\[
	\begin{aligned}
		\mathcal{D}_{\bar L}[C] \, &< \, 0 \quad \big(\delta = 2\sigma_Q/\bar L \implies \tfrac{\Delta\sigma}{\sigma} = -\tfrac{\Delta \bar L}{\bar L}\big), \qquad
		\mathcal{D}_{\Delta Q_M}[C] \, < \, 0, \qquad
		\bar v^2 \, = \, \frac{4\sigma_Q^2}{\dot{\bar k}} \ln\Big(1 + \frac{\dot{\bar k}\,t^{\star}}{\bar L_0^2}\Big), \;\; \dot{\bar k} \equiv \tfrac{\Delta (\bar L^2)}{\Delta t} \\
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

> ORIENTATION (M1, decided at formula level against eq (12), not by the \(w = \eta_L = \tfrac12\) example where the flip is invisible): \(\eta_L\) = ASSET share (eta.md line 12), Maymin's \(w\) = NUMERAIRE weight (his §3.2), so \(w = 1-\eta_L\) and the CEV exponent is \(1-\eta_L\). LEVERAGE EFFECT: \(\sigma \propto p^{-\eta_L}\) is DECREASING in p for every \(\eta_L > 0\), and steepens as the asset share \(\eta_L\) rises (Maymin's negative price-elasticity-of-variance finding, Bittensor §6). The ATM-normalized skew depends ONLY on \(\eta_L\): sharp, depth-invariant, testable. Transfer to the grid exponent η requires E8(6) (η_L = η), which is OPEN — this display does NOT assume it.

## **G3. [CONTROL MATRIX]**

● = appears in the display; ○ = equilibrium-only / mediated (subscript names the mediator); — = provably absent.
LEVEL: every row is POSITION-LEVEL (B1) — θ_fee means \(\theta_{\text{fee}}^{\text{pos}} = \phi(\sigma_t)\nu_t\Delta Q_M\), and the hazard rows are the schedule-level ledgers they aggregate to.

\[
	\begin{array}{l|cccccccc}
		 & (\xi,\iota) & (\eta,\Delta_i)\to\varsigma_{X/M} & \bar L & (\bar\phi,\alpha,u) & (\beta_j,\gamma_j) & t^{\star} & \tau,\tau_{\text{JIT}} & \text{haz. inputs }(\sigma\text{-path},w_t,D_t) \\
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

> UNITS (M2) — the locked-LP short vega \(\Delta\pi/\Delta\sigma^2 = -(t^{\star}-t)/8\cdot(\text{asset leg})\) is VALUE per σ², while \(\Delta\theta_{\text{fee}}/\Delta\sigma^2\) is VALUE per TIME per σ². The correctly-typed claim is the time-integrated one: \(\int_t^{t^{\star}} \Delta\theta_{\text{fee}}/\Delta\sigma^2\, ds\) is commensurable with the locked short vega and is the candidate hedge; the pointwise derivative alone "hedges" nothing. Signs verified: short vega < 0 (Bardoscia §3.3.5), fee-vega > 0 (Λ′ > 0, α, u ≥ 0), so the carry leg does offset in sign.
> Consistent with the priors: level programs saturate (β,γ) (corner), J9 discards them for JIT (duration-blind); the σ-profile of carry is the FIRST first-order display that contains them.

\((\beta_j,\gamma_j)\) identification channel: fee-swap price → \(\sigma^{\star}_{\phi}\) (Bichuch–Feinstein Thm 5.1 bijection) → multiFee inversion.

## **G4. [UNDERSPECIFICATION COUNT]**

\[
	\begin{aligned}
		\mathcal{T} \, &= \, \{\mathcal{D}_p,\; \Gamma,\; \upsilon,\; \theta_{\text{fee}}^{\text{pos}},\; \Delta\theta_{\text{fee}}/\Delta\sigma,\; \mathcal{D}_{\bar L},\; \mathcal{D}_{\Delta Q_M},\; \lambda_{\text{FLAIR}},\; \lambda_{\text{ARB}},\; \tilde\lambda_{\text{JIT}}\}, \quad |\mathcal{T}| = 10 \\
		&\quad (\theta_{\text{decay}} \text{ excluded: redundant by Demeterfi EQ 12};\;\; \sigma_{IV}/\sigma_{IV}^{ATM} \text{ excluded: DIAGNOSTIC, G3};\;\; \lambda_{\text{MEV}} \text{ excluded: the } \oplus\text{-sum}) \\
		\#\text{free} \, &= \, \underbrace{\iota,\, \bar L}_{2} \, + \, \underbrace{(\beta_j,\gamma_j)}_{2n} \, + \, \underbrace{t^{\star}}_{1} \, + \, \underbrace{\tau,\, \tau_{\text{JIT}}}_{2} \, + \, \underbrace{\Delta Q_M\text{-schedule}}_{1} \, = \, 6 + 2n
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
		\text{APPROXIMABLE: } & \phi(\sigma)\text{ (expWad logistic)},\; \theta_{\text{decay}} \text{ (expWad+sqrt; FLAG-blocked)},\; \sigma^2(i(t)) \text{ (E2/E5 ledger — see caveat)},\; \mathcal{D}_{\bar L}[\pi] \text{ (relative form exact)} \\
		\text{OFF-CHAIN: } & \text{CEV prices and } \mathbb{P}_{Y_{n,c}\le x} \text{ tails},\; \sigma^{\star}_{\phi} \text{ inversion},\; \mathcal{D}_{\bar L}[C],\; \mathcal{D}_{\Delta Q_M}[C] \text{ model values (lnWad for } \bar v^2\text{; schedule input exact)}
	\end{aligned}
\]

> \(\sigma^2(i(t))\) CAVEAT: v4 has no built-in TWAP, and E2/E5 feed the OFF-chain subgraph reader (events→subgraph→GAMS layer) — so "APPROXIMABLE on-chain" presupposes EITHER an oracle hook OR a NEW on-chain accumulator (sum of squared int24 tick increments, Δt-weighted in seconds). Nothing in today's E-layer delivers \(\sigma^2\) to a contract.

## **G6. [CAVEATS / OPEN]**

1. θ exponent-sign FLAG (line ~42) — author decision pending; blocks G1's θ_decay finalization and any on-chain constant.
2. E8(6) \(\eta_L = \eta\) — OPEN; G2's skew law is an η_L statement until it closes.
3. \(\mathcal{D}_p, \Gamma\) ladder displays, the θ split, the \(\Delta\theta_{\text{fee}}/\Delta\sigma\) statics, and the G4 deficit lemmas are UNFORMALIZED — the Aristotle bundle for this section. **G2: OFF-BUNDLE — analytic content (CEV pricing, noncentral χ², implied-vol inversion) beyond Mathlib v4.28.** Every bundled θ_fee statement MUST name which B1 form it formalizes (schedule-level \(\phi\nu_t\) or position-level \(\phi\nu_t\Delta Q_M\)); the two are not interchangeable and a mixed statement is unprovable.
4. Carry-profile objective: per-event (M6b) vs time-integrated (λ_FLAIR) statement — decide before bundling; the M2 hedge claim needs the time-integrated form.
5. 2n sigmoid parameters match ≤ 2n carry-profile moments — re-count if the hazard ladder demands finer σ-resolution.
6. Natenberg local copy is image-only (no text layer); classical displays are anchored to Demeterfi/Bardoscia instead. Lababidi (Greek.fi) contains no Greek formulas — infrastructure reference only.
7. t-SEMANTICS (G1 clause) — maturity-parameter \(t\) (\(\upsilon = t/2\), \(= t^{\star}/2\) at inception) vs calendar \(t\) (\(t^{\star}-t\) in the locked vega): stated, not yet carried into the Lean signatures.
