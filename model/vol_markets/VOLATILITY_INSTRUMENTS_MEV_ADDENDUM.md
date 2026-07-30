# PROPOSED addendum to `VOLATILITY_INSTRUMENTS.md` `### MEV` — the λ_MEV hazard and its infimum

> STATUS: APPROVED & APPLIED 2026-07-30 — blocks M0–M8 inserted into ../plank/notes/VOLATILITY_INSTRUMENTS.md per user approval (todo.md `## LEAN4 - MATH`). Committing the plank file is the plank agent's.
> Anchor: Milionis–Moallemi–Roughgarden, *Automated Market Making and Arbitrage Profits in the
> Presence of Fees*, arXiv:2305.14604v2 (2025-07-23), read from
> `../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf`.
> Notation: the paper's fee `γ` is this document's `φ`; the paper's Poisson block rate `λ` is <!-- notation-map -->
> written through its own primitive `Δt ≜ λ⁻¹` (this document's `λ` is the hazard rate); the <!-- notation-map -->
> paper's composite `η` is deliberately never named (`η` is the project's pricing-kernel eta). <!-- notation-map -->
> Minimal prose; each block is insert-ready LaTeX.

## **M0. [NOTATION]**

The paper's fee symbol `γ` is transcribed as this document's fee `φ`; this document's `γ_j` stays the sigmoid steepness. <!-- notation-map -->
The paper's Poisson block rate `λ` is transcribed through its own primitive `Δt ≜ λ⁻¹`, because this document's `λ` is the hazard rate. <!-- notation-map -->
The paper's composite parameter `η ≜ γ√(2λ)/σ` is deliberately never named, since `η` is reserved project-wide for the pricing kernel. <!-- notation-map -->
Consequently the paper's root-block-rate factor is written \(\sqrt{2/\Delta t}\) throughout, and no composite abbreviation is introduced.
The fee is this document's \(\phi\), with level ceiling \(\bar\phi\) and parameter set \(\Theta_{\phi}\); the glyph \(\varphi\) is NOT used here, because this document already binds it to the quote function feeding the R-sigmoid ratio.

\(\Delta t\) is the mean interblock time — for Angstrom, one bundle per block per pair, so the batch cadence *is* \(\Delta t\).
\(\sigma\) is the same \(\sigma(i(t))\) that already feeds the fee schedule; the identical \(\sigma_t\) enters both the fee and the trade probability.
\(a_t \geq 0\) is the PER-STEP (per-block) arbitrage-opportunity weight. The paper's leading-order LVR is a rate per unit time, so the per-step weight carries an explicit \(\Delta t\): see M3(i). Stating it as a rate would not be commensurable with \(\lambda_{\text{FLAIR}}\), whose \(w_t\) is a per-step traded amount.
\(D_t > 0\) is the SAME deployed-capital denominator as \(\lambda_{\text{FLAIR}}\); with \(a_t\) and \(w_t\) both per-step amounts the two hazards are then commensurable.

Two hazard symbols are used and are never interchangeable.
\(\lambda_{\text{ARB}}\) is the arbitrage-channel hazard, defined in M3; blocks M3–M6b are statements about \(\lambda_{\text{ARB}}\) alone.
\(\lambda_{\text{MEV}}\) is the aggregate over the two channels modelled here, defined in M7 and nowhere else.
Relative to this document's hazard index set, \(\lambda_{\text{ARB}}\) ABSORBS the "arb toxicity" entry: it is not a sibling of \(\lambda_{\text{MEV}}\) but a summand of it, and the index set must not carry both or the aggregate double-counts.

The paper's `FEE` (fees paid by arbitrageurs) is a strict sub-flow of \(\lambda_{\text{FLAIR}}\), which also carries noise-trader flow; the two are NOT identified.

Standing hypotheses for every transcribed closed form below: the paper's Assumption 2 (symmetry — a driftless mispricing and a fee equal on both sides), which the paper calls WLOG with the non-symmetric variant in its Appendix C; and, for M2, the regularity conditions (13) and (15) bounding the convexity of the arbitrage and fee functions in the mispricing.

## **M1. [ADDITION] The trade probability**

\[
	\begin{aligned}
		P_{\text{trade}}(\phi,\sigma,\Delta t) \, = \, \frac{\sigma}{\sigma + \phi\sqrt{2/\Delta t}}
	\end{aligned}
\]

From MMR Theorem 1's stationary distribution, section 4.1 (arXiv:2305.14604v2), under Assumption 2: the long-run fraction of blocks carrying a profitable arbitrage. It is independent of the bonding function and of the feasible set — the only pool property that enters is the fee.

- \(P_{\text{trade}} \in (0,1]\)
- \(P_{\text{trade}} = 1 \iff \phi = 0\)
- strictly decreasing in \(\phi\)
- **strictly convex** in \(\phi\)
- increasing in \(\Delta t\)
- increasing in \(\sigma\)
- \(P_{\text{trade}} \to 0\) as \(\phi \to \infty\)

Strictness of the convexity is recorded deliberately: the strict half of M6b is exactly where it is consumed.

## **M2. [ADDITION] The MMR split**

\[
	\begin{aligned}
		\mathrm{ARB} \, \approx \, \mathrm{LVR}\cdot P_{\text{trade}}, \qquad
		\mathrm{FEE} \, \approx \, \mathrm{LVR}\cdot(1-P_{\text{trade}}), \qquad
		\mathrm{ARB}+\mathrm{FEE} \, \approx \, \mathrm{LVR}
	\end{aligned}
\]

MMR Theorem 3 with eq. (12), and Theorem 4, each under its stated regularity condition: LVR is *split* between arbitrageur profit and arbitrageur-paid fees according to \(P_{\text{trade}}\).
The `≈` is the fast-block (\(\Delta t \to 0\)) small-fee leading order, so every object built on it below is a leading-order object.

## **M3. [ADDITION] The discrete \(\lambda_{\text{ARB}}\)**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, = \, \sum_{t<T} P_{\text{trade}}\big(\phi(\sigma_t),\sigma_t,\Delta t\big)\,\frac{a_t}{D_t}
	\end{aligned}
\]

This is the ARBITRAGE channel, not the aggregate. Its \(\Theta_{\phi}\) specialization takes \(\phi(\sigma) = \texttt{multiFee}(n,\gamma,\beta,\alpha,\bar\phi,u)\) — the SAME \(\Theta_{\phi}\) as FLAIR.

CPMM instantiation, two tiers:

(i) the LEADING-ORDER per-step weight

\[
	\begin{aligned}
		a_t \, = \, \frac{\sigma_t^2}{8}\,V_t\,\Delta t
	\end{aligned}
\]

The paper's \(\mathrm{LVR} = (\sigma^2/8)\,V(P)\) is a limit of expected LVR per unit time, i.e. a RATE; the \(\Delta t\) factor converts it to the per-block amount this sum requires. Consistency check: the per-block summand then scales as \(\Delta t\cdot\sqrt{\Delta t} = \Delta t^{3/2}\), which is the paper's own section 7.1 statement that arbitrage profits per block scale as \(\Delta t^{3/2}\) while per unit time they scale as \(\Delta t^{1/2}\). This tier needs no finiteness guard.

(ii) the EXACT Corollary-2 kernel

\[
	\begin{aligned}
		(\mathrm{ARB}/V)_{\text{exact}} \, = \, \frac{(\sigma^2/8)\,P_{\text{trade}}\,e^{\phi/2}}{1-\sigma^2\Delta t/8}
	\end{aligned}
\]

which is the ONLY object carrying the guard \(\sigma_t^2\Delta t < 8\). Downstream formalization must reuse this symbol under this name.

## **M4. [ADDITION] Identification \(\Theta_{\lambda_{\text{ARB}}}\)**

For positive sigmoid slopes \(\gamma_j > 0\), \(\lambda_{\text{ARB}}\) is antitone in \(\bar\phi\), in each \(\alpha_j\), and in \(u\); isotone in each \(\beta_j\); and convex in the fee.

There is **no affine** identification analogous to `flairMulti_affine`, because \(P_{\text{trade}}\) is not affine — the level and shape coordinates do not separate, and the uniform bound of M5 is a SUM rather than a scalar times a path weight.

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{ARB}}} \, = \, \{\bar\phi,\, \alpha,\, u\}
	\end{aligned}
\]

Under M7's batch-clearing reduction (\(\lambda_{\text{sandwich}} = 0\)) this reads \(\Theta_{\lambda_{\text{MEV}}} = \Theta_{\lambda_{\text{ARB}}} = \{\bar\phi,\, \alpha,\, u\}\) — the sense in which the identification is named for the aggregate.

## **M5. [ADDITION] The infimum program (on \(\lambda_{\text{ARB}}\))**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, \sum_{t<T} P_{\text{trade}}\Big(\bar\phi_{\max} + u_{\max}\textstyle\sum_j \alpha_{\max,j},\, \sigma_t,\, \Delta t\Big)\frac{a_t}{D_t}
	\end{aligned}
\]

Three separate attainment statements, deliberately not merged — the displayed right-hand side uses the fee CEILING, which no finite shape block reaches:

(i) for any FIXED shape block, the infimum over the level block \(\{\bar\phi,\alpha,u\}\) is attained bang-bang at the level-corner TOP;
(ii) the displayed bound itself is only approached, as \(\beta_j \to -\infty\), with a STRICT gap at every finite \(\beta\) (the sigmoid is never saturated), so it is a boundary value and not a minimum;
(iii) on any nonempty compact parameter box a minimizer exists, and its value strictly exceeds the displayed bound.

## **M6a. [ADDITION — THE DEGENERACY] The unconstrained joint program**

The two programs are extremized by the same choices, coordinate by coordinate. Stated as two well-posed claims rather than as an equality of arg-sets, because over an unbounded shape block neither extremum is attained:

(i) for every FIXED shape block, the level-block maximizer of \(\lambda_{\text{FLAIR}}\) and the level-block minimizer of \(\lambda_{\text{ARB}}\) are the SAME corner point in \((\bar\phi,\alpha,u)\) — the top;
(ii) both objectives saturate along the SAME direction \(\beta_j \to -\infty\), i.e. one common sequence simultaneously drives \(\lambda_{\text{FLAIR}}\) to its supremum and \(\lambda_{\text{ARB}}\) to its infimum, neither being attained at finite \(\beta\);
(iii) consequently, for every scalarization weight \(\kappa \geq 0\), the same corner point and the same saturating direction extremize \(\lambda_{\text{FLAIR}} - \kappa\,\lambda_{\text{ARB}}\), so the degeneracy is robust to linear scalarization.

Therefore, **unconstrained, there is no trade-off in \(\Theta_{\phi}\) and the shape block \((\beta, \gamma_j)\) is not essential.** This REFUTES the expectation recorded in the phase brief, and is stated here as a refutation rather than quietly dropped.
By M7's reduction the same statement holds verbatim for \(\lambda_{\text{MEV}}\) in the uniform-clearing regime.

## **M6b. [ADDITION — THE CONSTRAINED PROGRAM] Where the trade-off lives**

Quantified over arbitrary nonnegative fee PATHS \(\{\phi_t\}\) — NOT over schedules in \(\Theta_{\phi}\); see the OPEN note below for why that distinction is load-bearing.
With \(\nu_t = w_t/D_t\), \(W = \sum_t \nu_t > 0\), the FLAIR budget \(\lambda_{\text{FLAIR}} = \sum_t \phi_t\,\nu_t = B\), the aligned-measure hypothesis \(a \equiv w\), and \(\sigma_t \equiv \sigma_0\):

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, W\cdot P_{\text{trade}}\!\left(\frac{B}{W},\,\sigma_0,\,\Delta t\right),
		\qquad \text{equality} \iff \phi_t\ \text{constant on}\ \{t : \nu_t > 0\}
	\end{aligned}
\]

i.e. **among all fee PATHS with the same FLAIR income, the FLAT path minimizes \(\lambda_{\text{ARB}}\), and any path non-constant on the positive-weight steps is strictly worse for \(\lambda_{\text{ARB}}\)** (hence for \(\lambda_{\text{MEV}}\) under M7's reduction). The strict half consumes M1's STRICT convexity.

The aligned-measure hypothesis \(a \equiv w\) is STRONG: it forces the traded-volume path, which carries noise-trader flow, to be proportional block-by-block to the leading-order LVR path. Without it the two sides live under different measures, Jensen does not apply, and the constrained minimizer can tilt the fee UP where the arbitrage measure is heavy — i.e. the conclusion can reverse.

**OPEN**: the display holds at constant \(\sigma_t \equiv \sigma_0\), where it is a statement about fee PATHS. It does NOT deliver a comparison between fee SCHEDULES, because every schedule in \(\Theta_{\phi}\) is a function of \(\sigma\) alone and therefore already produces a constant path when \(\sigma\) is constant — the strict half has no bite inside \(\Theta_{\phi}\) in this regime. Whether a volatility-responsive schedule beats or loses to a flat fee at equal income when \(\sigma_t\) actually VARIES is the open question: the summands are then *different* convex functions, plain Jensen does not apply, and the correct statement is a two-measure/covariance one. It is NOT claimed here.

## **M7. [ADDITION] The aggregate \(\lambda_{\text{MEV}}\), and the Angstrom bridge**

\[
	\begin{aligned}
		\lambda_{\text{MEV}} \, \coloneqq \, \lambda_{\text{ARB}} \oplus \lambda_{\text{sandwich}}
	\end{aligned}
\]

Here \(\oplus\) is hazard-side addition — plain addition of rates, the hazard-side image of this document's \(\otimes_\phi\) monoid under the componentwise correspondence \(\phi_i = 1-e^{-\lambda_i}\). The \(\otimes_\phi\) operation itself acts on probabilities in \([0,1]\) and is NOT applied to the unbounded hazards directly.
Reduction: \(\lambda_{\text{sandwich}} = 0 \implies \lambda_{\text{MEV}} = \lambda_{\text{ARB}}\), which uniform-clearing batches deliver by construction — hence every M3–M6b statement is a statement about \(\lambda_{\text{MEV}}\) in the Angstrom regime.
Sandwich extraction is a distinct MEV channel (arXiv:2207.11835); no sandwich profit shape is modelled here.

Two parametric items, both OUTSIDE \(\Theta_{\phi}\):

(i) the recycling/rebate, an LP-INCIDENCE object rather than an extraction intensity

\[
	\begin{aligned}
		\lambda_{\text{MEV}}^{\text{LP-net}} \, = \, (1-\tau)\,\lambda_{\text{MEV}}, \qquad \tau \in [0,1], \qquad \tau(k) = \frac{k}{k+1}
	\end{aligned}
\]

with \(k\) FREE. The top-of-block auction does NOT prevent the arbitrage — it awards it and routes the winning bid back to liquidity providers, so \(\tau\) redistributes extracted value and leaves the extraction intensity \(\lambda_{\text{MEV}}\) invariant; only the LP-borne share falls. Reading \((1-\tau)\) as a reduction in MEV would be wrong.
The map \(\tau(k) = k/(k+1)\) additionally presumes searchers express their bid through the priority fee and that competition drives the payment to the full arbitrage value under honest priority ordering; under searcher monopoly or proposer collusion the realized \(\tau\) can fall arbitrarily far below it.
As a dated worked instance only, the l2-angstrom snapshot of 2026-07-30 has `k = 49`, giving `τ = 0.98`; the live docs disagree with that snapshot (`TAXED_GAS` 120,000, a `priorityFeeTaxFloor`, a `jitMEVTaxFactor`, and a creator/protocol/LP split), so no numeric constant may enter a claim.
For \(\tau \in [0,1)\) the rebate rescales the objective WITHOUT moving its minimizers, which is precisely the sense in which \(\tau\) sits outside \(\Theta_{\phi}\); at \(\tau = 1\) the objective is identically zero and the statement is vacuous.

(ii) the batch cadence IS \(\Delta t\): it moves \(\lambda_{\text{ARB}}\) monotonically and does not enter \(\lambda_{\text{FLAIR}}\) at all — the second, genuinely non-degenerate lever.

## **M8. [CAVEATS]**

- LEADING ORDER — everything above rests on eq. (12)'s fast-block, small-fee asymptotics; none of it is an exact finite-\(\Delta t\) statement except the M3(ii) kernel under its guard.
- QUASI-STATIC EXTENSION — \(P_{\text{trade}}\) is a STEADY-STATE quantity, derived for constant parameters. M3 applies it per step along a \(\sigma\)-varying path. That is an extension made by this document, not by the paper, and it is legitimate only if the parameters move slowly relative to mixing of the mispricing process.
- NO DEMAND ELASTICITY in EITHER functional. The missing term is MMR section 7.3 eq. (27), `E[delta-hedged LP P&L] = E[NT_FEE] − E[ARB]` — the delta-hedged form; the unhedged decomposition additionally carries the rebalancing term. The paper's own reading: "higher fees reduce noise trader activity ... but also reduce arbitrage profits". Every corner solution here is therefore a property of the formalized objective, not a market-equilibrium claim.
- SCOPE OF THE AGGREGATE — \(\lambda_{\text{MEV}}\) covers the two channels modelled here and is not all of MEV. Not modelled: backruns of noise-trader flow; multi-block MEV, where a censoring agent lengthens the effective \(\Delta t\) and so attacks the M7(ii) lever directly (MMR section 7.1); JIT liquidity, which the cited l2 docs already tax separately; and fixed gas costs, which act as an additive fee and move \(P_{\text{trade}}\) (MMR section 6).
- EMPIRICAL VALIDITY OF THE CADENCE LEVER — the \(\Delta t\) scaling law is validated only for block times of roughly one second and above; below that, reported arbitrage profits decline more slowly than this diffusion model predicts, because real prices jump. Sub-second cadence claims need a jump-diffusion extension and are out of scope.
- The \(\sigma\)-varying schedule comparison of M6b is **OPEN**, as labelled there.
