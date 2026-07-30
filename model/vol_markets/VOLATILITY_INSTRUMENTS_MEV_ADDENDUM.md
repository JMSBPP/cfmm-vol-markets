# PROPOSED addendum to `VOLATILITY_INSTRUMENTS.md` `### MEV` — the λ_MEV hazard and its infimum

> STATUS: DRAFT — pending two-reviewer gate and user approval.
> Anchor: Milionis–Moallemi–Roughgarden, *Automated Market Making and Arbitrage Profits in the
> Presence of Fees*, arXiv:2305.14604v2 (2025-07-23), read from
> `../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf`.
> Notation: the paper's fee `γ` is this document's `φ`; the paper's Poisson block rate `λ` is <!-- notation-map -->
> written through its own primitive `Δt ≜ λ⁻¹` (this document's `λ` is the hazard rate); the <!-- notation-map -->
> paper's composite `η` is deliberately never named (`η` is the project's pricing-kernel eta). <!-- notation-map -->
> Minimal prose; each block is insert-ready LaTeX.

## **M0. [NOTATION]**

The paper's fee symbol `γ` is transcribed as `φ` throughout; this document's `γ_j` stays the sigmoid steepness of the fee schedule. <!-- notation-map -->
The paper's Poisson block rate `λ` is transcribed through its own primitive `Δt ≜ λ⁻¹`, because this document's `λ` is the hazard rate. <!-- notation-map -->
The paper's composite parameter `η ≜ γ√(2λ)/σ` is deliberately never named, since `η` is reserved project-wide for the pricing kernel. <!-- notation-map -->
Consequently the paper's root-block-rate factor is written \(\sqrt{2/\Delta t}\) throughout, and no composite abbreviation is introduced.

\(\Delta t\) is the mean interblock time — for Angstrom, one bundle per block per pair, so the batch cadence *is* \(\Delta t\).
\(\sigma\) is the same \(\sigma(i(t))\) that already feeds the fee schedule; the identical \(\sigma_t\) enters both the fee and the trade probability.
\(a_t \geq 0\) is the per-step arbitrage-opportunity weight (the leading-order LVR of the split in M2).
\(D_t > 0\) is the SAME deployed-capital denominator as \(\lambda_{\text{FLAIR}}\), so the two hazards are commensurable.

Two hazard symbols are used and are never interchangeable.
\(\lambda_{\text{ARB}}\) is the arbitrage-channel hazard, defined in M3; blocks M3–M6b are statements about \(\lambda_{\text{ARB}}\) alone.
\(\lambda_{\text{MEV}} \coloneqq \lambda_{\text{ARB}} \oplus \lambda_{\text{sandwich}}\) is the TOTAL, defined once, in M7.

The paper's `FEE` (fees paid by arbitrageurs) is a strict sub-flow of \(\lambda_{\text{FLAIR}}\), which also carries noise-trader flow; the two are NOT identified.

## **M1. [ADDITION] The trade probability**

\[
	\begin{aligned}
		P_{\text{trade}}(\varphi,\sigma,\Delta t) \, = \, \frac{\sigma}{\sigma + \varphi\sqrt{2/\Delta t}}
	\end{aligned}
\]

MMR Theorem 1 (arXiv:2305.14604v2): the long-run fraction of blocks carrying a profitable arbitrage. It is independent of the bonding function and of the feasible set — the only pool property that enters is the fee.

- \(P_{\text{trade}} \in (0,1]\)
- \(P_{\text{trade}} = 1 \iff \varphi = 0\)
- strictly decreasing in \(\varphi\)
- **strictly convex** in \(\varphi\)
- increasing in \(\Delta t\)
- increasing in \(\sigma\)
- \(P_{\text{trade}} \to 0\) as \(\varphi \to \infty\)

Strictness of the convexity is recorded deliberately: the strict half of M6b is exactly where it is consumed.

## **M2. [ADDITION] The MMR split**

\[
	\begin{aligned}
		\mathrm{ARB} \, \approx \, \mathrm{LVR}\cdot P_{\text{trade}}, \qquad
		\mathrm{FEE} \, \approx \, \mathrm{LVR}\cdot(1-P_{\text{trade}}), \qquad
		\mathrm{ARB}+\mathrm{FEE} \, \approx \, \mathrm{LVR}
	\end{aligned}
\]

MMR Theorem 3 with eq. (12), and Theorem 4: LVR is *split* between arbitrageur profit and arbitrageur-paid fees according to \(P_{\text{trade}}\).
The `≈` is the fast-block (\(\Delta t \to 0\)) small-fee leading order, so every object built on it below is a leading-order object.

## **M3. [ADDITION] The discrete \(\lambda_{\text{ARB}}\)**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, = \, \sum_{t<T} P_{\text{trade}}\big(\varphi(\sigma_t),\sigma_t,\Delta t\big)\,\frac{a_t}{D_t}
	\end{aligned}
\]

This is the ARBITRAGE channel, not the total. Its \(\Theta_{\varphi}\) specialization takes \(\varphi(\sigma) = \texttt{multiFee}(n,\gamma,\beta,\alpha,\bar\varphi,u)\) — the SAME \(\Theta_{\varphi}\) as FLAIR.

CPMM instantiation, two tiers:

(i) the LEADING-ORDER weight \(a_t = (\sigma_t^2/8)\,V_t\), which needs no finiteness guard;

(ii) the EXACT Corollary-2 kernel

\[
	\begin{aligned}
		(\mathrm{ARB}/V)_{\text{exact}} \, = \, \frac{(\sigma^2/8)\,P_{\text{trade}}\,e^{\varphi/2}}{1-\sigma^2\Delta t/8}
	\end{aligned}
\]

which is the ONLY object carrying the guard \(\sigma_t^2\Delta t < 8\). Downstream formalization must reuse this symbol under this name.

## **M4. [ADDITION] Identification \(\Theta_{\lambda_{\text{MEV}}}\)**

\(\lambda_{\text{ARB}}\) is antitone in \(\bar\varphi\), in each \(\alpha_j\), and in \(u\); isotone in each \(\beta_j\); and convex in the fee.

There is **no affine** identification analogous to `flairMulti_affine`, because \(P_{\text{trade}}\) is not affine — the level and shape coordinates do not separate, and the uniform bound of M5 is a SUM rather than a scalar times a path weight.

\[
	\begin{aligned}
		\Theta_{\lambda_{\text{ARB}}} \, = \, \{\bar\varphi,\, \alpha,\, u\}
	\end{aligned}
\]

Under M7's batch-clearing reduction (\(\lambda_{\text{sandwich}} = 0\)) this reads \(\Theta_{\lambda_{\text{MEV}}} = \Theta_{\lambda_{\text{ARB}}} = \{\bar\varphi,\, \alpha,\, u\}\) — the sense in which the identification is named for the total.

## **M5. [ADDITION] The infimum program (on \(\lambda_{\text{ARB}}\))**

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, \sum_{t<T} P_{\text{trade}}\Big(\bar\varphi_{\max} + u_{\max}\textstyle\sum_j \alpha_{\max,j},\, \sigma_t,\, \Delta t\Big)\frac{a_t}{D_t}
	\end{aligned}
\]

The bound is attained bang-bang at the level-corner TOP for any fixed shape block, approached as \(\beta_j \to -\infty\), strict at every finite \(\beta\); a minimizer exists on any nonempty compact box.

## **M6a. [ADDITION — THE DEGENERACY] The unconstrained joint program**

\[
	\begin{aligned}
		\operatorname{argsup}_{\Theta_{\varphi}} \lambda_{\text{FLAIR}} \, = \, \operatorname{arginf}_{\Theta_{\varphi}} \lambda_{\text{ARB}}
	\end{aligned}
\]

at EVERY coordinate — the level corner top, and \(\beta \to -\infty\) — and for every scalarization weight \(\kappa \geq 0\) the point maximizing \(\lambda_{\text{FLAIR}} - \kappa\,\lambda_{\text{ARB}}\) is that same point, so the degeneracy is robust to linear scalarization.

Therefore, **unconstrained, there is no trade-off in \(\Theta_{\varphi}\) and the shape block \((\beta, \gamma_j)\) is not essential.** This REFUTES the expectation recorded in the phase brief, and is stated here as a refutation rather than quietly dropped.
By M7's reduction the same statement holds verbatim for \(\lambda_{\text{MEV}}\) in the uniform-clearing regime.

## **M6b. [ADDITION — THE CONSTRAINED PROGRAM] Where the trade-off lives**

With \(\nu_t = w_t/D_t\), \(W = \sum_t \nu_t\), budget \(\lambda_{\text{FLAIR}} = B\), and the aligned-measure hypothesis \(a \equiv w\):

\[
	\begin{aligned}
		\lambda_{\text{ARB}} \, \geq \, W\cdot P_{\text{trade}}\!\left(\frac{B}{W},\,\sigma_0,\,\Delta t\right),
		\qquad \text{equality} \iff \varphi(\sigma_t)\ \text{constant in}\ t
	\end{aligned}
\]

i.e. **at a fixed FLAIR fee income, a FLAT fee minimizes \(\lambda_{\text{ARB}}\), and every volatility-responsive schedule with the same income is strictly worse for MEV.** The strict half consumes M1's STRICT convexity.

**OPEN**: the display is stated at constant \(\sigma_t \equiv \sigma_0\). With \(\sigma_t\) varying the summands are *different* convex functions, plain Jensen does not apply, and the correct statement is a two-measure/covariance one — which is NOT claimed here.

## **M7. [ADDITION] The total hazard \(\lambda_{\text{MEV}}\), and the Angstrom bridge**

\[
	\begin{aligned}
		\lambda_{\text{MEV}} \, \coloneqq \, \lambda_{\text{ARB}} \oplus \lambda_{\text{sandwich}}
	\end{aligned}
\]

in this document's own \(\otimes_\phi\) hazard algebra. Reduction: \(\lambda_{\text{sandwich}} = 0 \implies \lambda_{\text{MEV}} = \lambda_{\text{ARB}}\), which uniform-clearing batches deliver by construction — hence every M3–M6b statement is a statement about \(\lambda_{\text{MEV}}\) in the Angstrom regime.
Sandwich extraction is a distinct MEV channel (arXiv:2207.11835); no sandwich profit shape is modelled here.

Two parametric items, both OUTSIDE \(\Theta_{\varphi}\):

(i) the recycling/rebate

\[
	\begin{aligned}
		\lambda_{\text{MEV}}^{\text{net}} \, = \, (1-\tau)\,\lambda_{\text{MEV}}, \qquad \tau \in [0,1], \qquad \tau(k) = \frac{k}{k+1}
	\end{aligned}
\]

with \(k\) FREE. As a dated worked instance only, the l2-angstrom snapshot of 2026-07-30 has `k = 49`, giving `τ = 0.98`; the live docs disagree with that snapshot (`TAXED_GAS` 120,000, a `priorityFeeTaxFloor`, a `jitMEVTaxFactor`, and a creator/protocol/LP split), so no numeric constant may enter a claim.
The rebate rescales the objective WITHOUT moving its minimizers, which is precisely the sense in which \(\tau\) sits outside \(\Theta_{\varphi}\).

(ii) the batch cadence IS \(\Delta t\): it moves \(\lambda_{\text{ARB}}\) monotonically and does not enter \(\lambda_{\text{FLAIR}}\) at all — the second, genuinely non-degenerate lever.

## **M8. [CAVEATS]**

- LEADING ORDER — everything above rests on eq. (12)'s fast-block, small-fee asymptotics; none of it is an exact finite-\(\Delta t\) statement except the M3(ii) kernel under its guard.
- NO DEMAND ELASTICITY in EITHER functional. The missing term is MMR section 7.3 eq. (27), `E[LP P&L] = E[NT_FEE] − E[ARB]`, with "higher fees reduce noise-trader activity ... but also reduce arbitrage profits". Every corner solution here is therefore a property of the formalized objective, not a market-equilibrium claim.
- The \(\sigma\)-varying Jensen statement of M6b is **OPEN**, as labelled there.
