# DRAFT — τ_MEV algebra blocks (M9–M10) for `VOLATILITY_INSTRUMENTS.md ### MEV`

> STATUS: DRAFT spec for the Aristotle τ-bundle. Doc insertion requires HEAVY
> USER APPROVAL (pending); this file is the bundled specification meanwhile.
> Notation: τ_MEV ∈ [0,1] is the MEV tax parameter; all other symbols per the
> doc (⊗_φ, φ_M, φ_X, φ(σ), λ_ARB, λ_MEV, τ(k)); no doc symbol reassigned.

## **M9. [ADDITION — τ_MEV ENTRY ALGEBRA] The three channels**

MEV realizes through trading; the tax is a trading tax routed as protocol
fee → donation to the affected population (LPs). Three algebraically
distinct entries for τ_MEV:

**(A) Monoid entry** (sequential fee composition, the proven abelian monoid
\(([0,1], \otimes_\phi, 0)\)):

\[
	\begin{aligned}
		\phi_{\text{total}} \, = \, \phi_M \otimes_\phi \phi_X \otimes_\phi \tau_{\text{MEV}}, \qquad
		\phi \otimes_\phi \tau_{\text{MEV}} \, \geq \, \phi \;\; (\tau_{\text{MEV}} \geq 0,\, \phi \leq 1)
	\end{aligned}
\]

**(B) Convex separation** of the realized fee (revenue routing; trader-facing
fee unchanged):

\[
	\begin{aligned}
		\phi(\sigma) \, = \, \underbrace{(1-\tau_{\text{MEV}})\,\phi(\sigma)}_{\text{LP share}} \, + \, \underbrace{\tau_{\text{MEV}}\,\phi(\sigma)}_{\text{donation}}, \qquad \tau_{\text{MEV}} \in [0,1]
	\end{aligned}
\]

**(C) Auction lump-sum** on the extractor (outside \(\Theta_\phi\); already
parametric): \(\tau(k) = k/(k+1)\), net form \((1-\tau)\cdot\text{extraction}\)
(`MevJointProgram.taxFraction`, `mevNet`).

## **M10. [ADDITION — THE DISCRIMINATING ALGEBRA] What each choice can and cannot do**

\[
	\begin{aligned}
		\text{(A) intensity:} \quad & P_{\text{trade}}\big(\phi \otimes_\phi \tau_{\text{MEV}}\big) \, \leq \, P_{\text{trade}}(\phi) \quad \text{(strict for } \tau_{\text{MEV}} > 0,\, \phi < 1\text{)} \\
		\text{(A) no targeting:} \quad & (\phi_M \otimes_\phi \tau_{\text{MEV}}) \otimes_\phi \phi_X \, = \, \phi_M \otimes_\phi (\phi_X \otimes_\phi \tau_{\text{MEV}}) \quad \text{(aggregate leg-invariant)} \\
		\text{(A) hazard-exact:} \quad & (1-e^{-\lambda_M}) \otimes_\phi (1-e^{-\lambda_X}) \otimes_\phi (1-e^{-\lambda_\tau}) \, = \, 1-e^{-(\lambda_M+\lambda_X+\lambda_\tau)} \\
		\text{(B) intensity-neutral:} \quad & P_{\text{trade}} \text{ unchanged (trader-facing fee is } \phi\text{)} \\
		\text{(B) FLAIR-linear:} \quad & \lambda_{\text{FLAIR}}^{\text{LP}} \, = \, (1-\tau_{\text{MEV}})\,\big(\bar\phi\,W + u\textstyle\sum_j \alpha_j W_j\big) \quad \text{(distributes over the affine identification)} \\
		\text{(B) budget identity:} \quad & (1-\tau_{\text{MEV}})\,\phi + \tau_{\text{MEV}}\,\phi \, = \, \phi; \qquad \text{donation} \to \text{net-MEV compensation via } \texttt{mevNet} \\
		\text{(A} \neq \text{B):} \quad & \exists\, \phi, \tau:\; (1-\tau)\big(\phi_M \otimes_\phi \phi_X\big) \, \neq \, \big((1-\tau)\phi_M\big) \otimes_\phi \big((1-\tau)\phi_X\big) \\
		\text{(B breaks hazard):} \quad & \exists\, \tau, \lambda:\; 1-e^{-\tau\lambda} \, \neq \, \tau\,(1-e^{-\lambda})
	\end{aligned}
\]

> The choice among (A)/(B)/(C) is an AUTHOR DECISION: (A) is the unique
> hazard-additive entry (intensity effect, cannot target); (B) is the unique
> revenue-linear entry (targets incidence/compensation, no intensity effect);
> (C) targets the extractor directly. They are pairwise formally inequivalent
> (discriminating instances above). Hybrid A∘B admissible; order matters.
