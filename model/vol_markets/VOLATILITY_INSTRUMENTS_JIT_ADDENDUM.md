# APPROVED + INSERTED — λ_JIT blocks (J0–J9) in `## JIT` of VOLATILITY_INSTRUMENTS.md

> STATUS: INSERTED 2026-07-31. J1–J8 PROVEN (`JitLiquidity.lean`, 62 decls, axiom-clean, project 610bb259); J2 radicand CORRECTED (q_R² factor); J9 τ_JIT DECIDED, formalization IN FLIGHT (project 4cb6d5ca, K1–K5).
> Source: Capponi–Jia–Zhu arXiv:2311.18164 (CJZ). Minimal prose, maximal math.

## **J0. [NOTATION-MAP]**

CJZ's fee-transfer rate `λ` → `ϑ` (ours: λ = hazards). <!-- notation-map -->
CJZ's informed-arrival probability `α` → `ϖ` (ours: α_j = amplitudes). <!-- notation-map -->
CJZ's pool fee `f` → this document's `φ`. <!-- notation-map -->
CJZ's deposit multiple `ν(π)` → `m_J` (ours: ν_t = w_t/D_t). <!-- notation-map -->
CJZ kept as-is: π (JIT arrival prob), ζ, ζ_U, ζ̲, ζ★, ζ̂, ψ, ψ_U, μ(π), d_P, d_J, d̃ = p^{1/2}d, q_R, q_S, δ_S, δ_R, 𝒞, ℛ, 𝒰, W, M_T, M_J, V, V₀. CJZ's strategy-profile σ and duration flag are implementation objects, untranscribed. Known CJZ typo: main-text expected utility weights both US/UB by ψ_U; App. A.4's ψ_U/(1−ψ_U) is correct — transcribe from A.4.

## **J1. [PRIMITIVES] swap curves**

\[ \delta_S(r,d) = \frac{p\,\tilde d\,r}{\tilde d + r}, \qquad \delta_R(s,d) = \frac{\tilde d\, s}{p\tilde d + s} \]

1-homogeneous in \((r,\tilde d)\)/(\(s,\tilde d\)); increasing and concave in the first argument; increasing in \(\tilde d\).

## **J2. [JIT BEST RESPONSE] closed form + THE THIRD POLE**

For \(q_R > \varphi\text{-fee-adjusted floor } \phi\,\tilde d_P\):

\[ \tilde d_J^{\star} = \frac{\phi\,\tilde d_P(\tilde d_P + q_R) + \sqrt{q_R^{2}\,(1+\phi)\,\tilde d_P(\tilde d_P + q_R)}}{q_R - \phi\,\tilde d_P} \]

> LEAN (correction): the first-transcribed radicand \(\sqrt{q_R(1+\phi)\tilde d_P(\tilde d_P+q_R)}\) is NOT a root of \(M_J\) — exact witness `dJstar_not_root_witness` (\(\phi=0, \tilde d_P=1, q_R=2\)); the display above carries the corrected factor \(q_R^2\): `dJroot`, `dJroot_root`, `dJroot_unique_positive_root`, pole `dJstar_pole`, no root below `MJfun_no_positive_root_below_pole`.

unique positive root of \(M_J(\tilde d_J) = \frac{(1+\phi)\tilde d_P}{(\tilde d_P+\tilde d_J)^2} - \frac{\tilde d_P + q_R}{(\tilde d_P+\tilde d_J+q_R)^2}\); unique max of the quasiconcave \(u_J\). POLE: \(\tilde d_J^{\star} \to \infty\) as \(q_R \downarrow \phi\tilde d_P\); no interior optimum for \(q_R \leq \phi\tilde d_P\).

## **J3. [UNINFORMED DEPTH] fixed point**

\(M_T(\mu;\pi) = \frac{1-\pi}{(1+\mu)^2} + \frac{\pi(2+\mu)\sqrt{(1+\phi)(1+\mu)}}{2(1+\mu)^2}\) strictly decreasing, \(M_T(0) > 1\), \(\to 0\) ⟹ unique \(\mu(\pi)\) solving \(M_T = (1+\phi)/\zeta_U\); \(\mu(\pi) \uparrow \pi, \uparrow \zeta_U\). Threshold: \(\mu(\pi) > \phi \iff \zeta_U > \underline{\zeta}(\phi,\pi) = \frac{2(1+\phi)^3}{2+\pi\phi(3+\phi)}\). \(m_J(\mu) = \frac{\phi(1+\mu)+\mu\sqrt{(1+\phi)(1+\mu)}}{\mu-\phi}\): positive, pole at \(\mu = \phi\), monotone.

## **J4. [DELEGATION] adverse selection onto passive LPs**

JIT deposits ONLY facing uninformed: \(d_J^{\star} = 0\) on informed events, \(= m_J\cdot d_P\) on uninformed. Passive per-unit utility \(u_P = p(\varpi\,\mathcal{C} + (1-\varpi)\,\mathcal{R}(\pi))d_P\), with the full adverse-selection cost borne by passives:

\[ \mathcal{C} = -\Big[\psi\big(1 - \tfrac{1+\phi}{\zeta}\big)^2 + (1-\psi)\big(\sqrt{\zeta} - \sqrt{1+\phi}\big)^2\Big] < 0 \quad (\zeta > 1+\phi) \]

\(\mathcal{U} = \varpi\mathcal{C} + (1-\varpi)\mathcal{R}\) strictly \(\downarrow \varpi\); \(d_P^{\star} = e_P\cdot\mathbb{1}[\mathcal{U} \geq 0]\) — freeze at \(\mathcal{U} < 0\); JIT-induced freeze interval \(\varpi \in [\underline\varpi, \bar\varpi]\) exists when \(\mathcal{R}(0) > \mathcal{R}(\pi)\).

## **J5. [CROWDING] threshold + volume identity**

\(\mathcal{R}(\pi) = \phi\,V(\mu(\pi))\), \(\mathcal{R}(0) = \phi V_0\), \(V_0 = \sqrt{\zeta_U/(1+\phi)} - \sqrt{(1+\phi)/\zeta_U}\), \(V(\mu) = (1-\pi)[\mu + \tfrac{\mu}{1+\mu}] + \pi[\sqrt{\tfrac{1+\mu}{1+\phi}} - \sqrt{\tfrac{1+\phi}{1+\mu}}]\).

\[ \text{crowding out} \iff V(\mu(\pi)) < V_0; \qquad \zeta^{\star}(\phi, 1) = (\sqrt{\phi} + \sqrt{1+\phi})^2 \]

(crowding region widens in \(\phi\) — a hazard-style comparative static in the fee.)

## **J6. [TWO-TIERED FEE ϑ] convex split + corner welfare**

JIT retains \(\vartheta \in [0,1]\) of its pro-rata share; \((1-\vartheta)\) → passives. Effective shares: passive \(= 1 - \vartheta\, s_J\), JIT \(= \vartheta\, s_J\), \(s_J = d_J/(d_P+d_J)\) — affine in \(\vartheta\); trader-paid \(\phi\) UNCHANGED (instance of the τ-blocks' choice-(B) algebra with \(\tau \mapsto 1-\vartheta\)). Dampening: \(\vartheta \downarrow\) ⟹ \(d_J^{\star}/d_P \downarrow\), uninformed swap \(\downarrow\). Welfare corner (skeleton, monotone forces as hypotheses): \(W \uparrow \vartheta\), \(\mathcal{U} \downarrow \vartheta\) ⟹ \(\arg\max_{\{\mathcal{U} \geq 0\}} W = \vartheta^{\star} = \max\{\vartheta : \mathcal{U}(\vartheta,\pi) \geq 0\}\), passive utility pinned to 0 there. Passive-optimal \(\vartheta = 0\); welfare-optimal \(\vartheta = \vartheta^{\star}\). Freeze prevention on \([\underline\beta,\bar\beta] \subseteq [\underline\varpi,\bar\varpi]\).

## **J7. [λ̃_JIT INCIDENCE] our ledger**

Tilde convention (user, 2026-07-31): \(\tilde\lambda\) marks INCIDENCE operators (act ON the hazard pair); plain \(\lambda\) marks hazards (\(\oplus\)-summands). <!-- notation-map -->

\[ \lambda_{\text{FLAIR}}^{\text{PLP}} = \lambda_{\text{FLAIR}} - \tilde\lambda_{\text{JIT}}, \quad \lambda_{\text{ARB}}^{\text{PLP}} = \lambda_{\text{ARB}} \implies \frac{\lambda_{\text{ARB}}^{\text{PLP}}}{\lambda_{\text{FLAIR}}^{\text{PLP}}} \uparrow \tilde\lambda_{\text{JIT}} \;\text{(strict, } 0 \leq \tilde\lambda_{\text{JIT}} < \lambda_{\text{FLAIR}},\, \lambda_{\text{ARB}} > 0) \]

\(\tilde\lambda_{\text{JIT}}\): incidence operator on \((\lambda_{\text{FLAIR}}, \lambda_{\text{ARB}})\), NOT an \(\oplus\)-summand of \(\lambda_{\text{MEV}}\) (`incidence_mevTotal_invariant`, `incidence_FLAIR_falls`, `toxicity_ratio_strictMono`); adversarial mirror of \(\tau\).

## **J8. [THE (β,γ) QUESTION + ANGSTROM BRIDGE] conditional, not assumed**

CJZ's JIT discriminator is DURATION, not fee level. Candidate: fee \(\phi\cdot m(\beta,\gamma;x_t)\) with \(x_t\) a settlement-time JIT observable earns \((\beta_j,\gamma_j)\) a genuine role IFF (i) sub-block deposits accrue \(\vartheta_{\text{eff}}(\beta,\gamma)\cdot\phi\) of pro-rata, (ii) surplus credited to long-duration positions, (iii) trader-paid fee INVARIANT — then the game is payoff-identical to J6 with \(\vartheta = \vartheta_{\text{eff}}(\beta,\gamma)\) and the corner statics transfer. WITHOUT (iii): trader-fee raises at JIT times WIDEN the crowding region (\(\underline\zeta, \zeta^{\star} \uparrow \phi\)) — the naive channel can worsen the paradox. l2-angstrom instance: JIT tax factor \(= \tfrac{3}{2}\cdot\)swap factor, rate \(x/(x+1)\)-form, charged on add AND remove, protocol-kept 100% (NOT rebated to passives — differs from CJZ's remedy; it prices inclusion urgency, an incentive-compatible proxy for \(\pi\)). L1 Angstrom: JIT structurally neutralized (no visible victim order, uniform clearing, reward-growth invariance).

## **J9. [τ_JIT — THE LIQUIDITY TAX] DECIDED: tax, not (β,γ)**

**DECIDED (user, 2026-07-31):** \((\beta,\gamma)\) DISCARDED for JIT control (duration-blind, J8); the control is \(\tau_{\text{JIT}}\), a tax on JIT liquidity provision.

Structural asymmetry vs \(\tau_{\text{MEV}}\) (M9): swaps carry \(\phi\) ⟹ the tax could COMPOSE (\(\otimes_\phi\), monoid) or SPLIT (convex) an existing price. Liquidity provision carries NO fee ⟹ no monoid/split algebra exists; \(\tau_{\text{JIT}}\) is the ONLY price on the action — payoff-additive levy:

\[ u_J^{\tau}(\tilde d_J) \, = \, u_J(\tilde d_J) \, - \, \tau_{\text{JIT}}\,(\tilde d_J^{\text{add}} + \tilde d_J^{\text{rm}}); \qquad \text{rate } \tfrac{x}{x+1},\; x = \tfrac{3}{2}\cdot\text{swapFactor (l2-angstrom, J8c)} \]

Incidence on PAYOFFS (the endogenous objects) ⟹ the program is comparative statics:

\[
	\begin{aligned}
		\frac{\partial u_J^{\tau}}{\partial \tau_{\text{JIT}}} \, &= \, -(\tilde d_J^{\text{add}}+\tilde d_J^{\text{rm}}) \, < \, 0, \qquad \frac{\partial \tilde d_J^{\tau\star}}{\partial \tau_{\text{JIT}}} \, \leq \, 0, \qquad \tilde\lambda_{\text{JIT}} = \tilde\lambda_{\text{JIT}}(\tau_{\text{JIT}}) \, \downarrow \\
		\text{participation:} \quad & \text{JIT enters} \iff u_J(\tilde d_J^{\star}) \geq \tau_{\text{JIT}}\cdot(\text{base}) \implies \text{extensive-margin threshold } \tau_{\text{JIT}}^{\star} \text{ (FIFTH POLE candidate)} \\
		\kappa_{\varphi}\text{-entry:} \quad & \text{second-order statics signed by the strict concavity of } \delta_S, \delta_R \text{ (J1)} \implies \text{conditions in } \kappa_{\varphi} \text{ [TO PROVE]} \\
		\text{remedy direction:} \quad & \frac{\partial \zeta^{\star}}{\partial \tau_{\text{JIT}}} \, \leq \, 0 \; ? \quad \text{(does the tax SHRINK the crowding region — the mirror of J8(b)) [TO PROVE]}
	\end{aligned}
\]

Ledger classification: \(\tau_{\text{JIT}}\) is an INTENSITY lever ON the incidence operator \(\tilde\lambda_{\text{JIT}}\) — contrast \(\tau_{\text{MEV}}\) (B)/(C), intensity-neutral on \(\lambda_{\text{MEV}}\). \(\tau_{\text{JIT}} \neq \vartheta\): the two-tier split (J6) redistributes fee income; the tax prices the deposit-withdraw event itself.
