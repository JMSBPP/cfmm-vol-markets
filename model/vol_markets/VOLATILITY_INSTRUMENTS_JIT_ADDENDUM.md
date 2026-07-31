# DRAFT — λ_JIT blocks (J0–J8) extending `## JIT` of VOLATILITY_INSTRUMENTS.md

> STATUS: DRAFT bundled spec (doc insertion pending HEAVY USER APPROVAL at landing).
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

\[ \tilde d_J^{\star} = \frac{\phi\,\tilde d_P(\tilde d_P + q_R) + \sqrt{q_R(1+\phi)\,\tilde d_P(\tilde d_P + q_R)}}{q_R - \phi\,\tilde d_P} \]

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

## **J7. [λ_JIT INCIDENCE] our ledger**

\[ \lambda_{\text{FLAIR}}^{\text{PLP}} = \lambda_{\text{FLAIR}} - \lambda_{\text{JIT}}, \quad \lambda_{\text{ARB}}^{\text{PLP}} = \lambda_{\text{ARB}} \implies \frac{\lambda_{\text{ARB}}^{\text{PLP}}}{\lambda_{\text{FLAIR}}^{\text{PLP}}} \uparrow \lambda_{\text{JIT}} \;\text{(strict, } 0 \leq \lambda_{\text{JIT}} < \lambda_{\text{FLAIR}},\, \lambda_{\text{ARB}} > 0) \]

\(\lambda_{\text{JIT}}\): incidence operator on \((\lambda_{\text{FLAIR}}, \lambda_{\text{ARB}})\), NOT an \(\oplus\)-summand of \(\lambda_{\text{MEV}}\); adversarial mirror of \(\tau\).

## **J8. [THE (β,γ) QUESTION + ANGSTROM BRIDGE] conditional, not assumed**

CJZ's JIT discriminator is DURATION, not fee level. Candidate: fee \(\phi\cdot m(\beta,\gamma;x_t)\) with \(x_t\) a settlement-time JIT observable earns \((\beta_j,\gamma_j)\) a genuine role IFF (i) sub-block deposits accrue \(\vartheta_{\text{eff}}(\beta,\gamma)\cdot\phi\) of pro-rata, (ii) surplus credited to long-duration positions, (iii) trader-paid fee INVARIANT — then the game is payoff-identical to J6 with \(\vartheta = \vartheta_{\text{eff}}(\beta,\gamma)\) and the corner statics transfer. WITHOUT (iii): trader-fee raises at JIT times WIDEN the crowding region (\(\underline\zeta, \zeta^{\star} \uparrow \phi\)) — the naive channel can worsen the paradox. l2-angstrom instance: JIT tax factor \(= \tfrac{3}{2}\cdot\)swap factor, rate \(x/(x+1)\)-form, charged on add AND remove, protocol-kept 100% (NOT rebated to passives — differs from CJZ's remedy; it prices inclusion urgency, an incentive-compatible proxy for \(\pi\)). L1 Angstrom: JIT structurally neutralized (no visible victim order, uniform clearing, reward-growth invariance).
