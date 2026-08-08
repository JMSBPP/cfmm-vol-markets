# DRAFT — MEV-tax control blocks (M11–M18) for `VOLATILITY_INSTRUMENTS.md ### MEV`

> STATUS: DRAFT spec for the Aristotle tax bundle. Doc insertion requires HEAVY
> USER APPROVAL (pending); this file is the bundled specification meanwhile.
> Numbering continues the live doc: `Definition 32+`, `Theorem 29+`,
> `Proposition 12+`, `Rule 13+`, provenance tag `[M11]+`.
>
> **Source of the derivation:** `evm-controller/notes/VOLATILITY_INTRUMENTS_MEV.md`
> at commit `78381d4` (blob `0ec3018`), cited below as `SRC:NNN @ 78381d4`. It
> carries no numbered items, so it is cited by line against that pin.
>
> **Notation.** No doc symbol is reassigned and no new symbol is minted here.
> Two bindings are load-bearing and were ruled by the user 2026-08-08:
> - `L_{\sigma} \equiv \Delta Q_v^{\star}` is the **volatility-axis** liquidity
>   (`UNITS_AND_SCALES.md:70`, RAW LIQUIDITY / the Uniswap `L` dimension, stored).
>   Plain `L`, `\bar L` remain the **price axis** (pool liquidity). Every use of
>   `L` below names its axis.
> - `\pi^{\varphi}` remains **`DOC` Definition 25's portfolio value function**.
>   `SRC:28`'s composite is written out in full as `\pi^{\phi} - \pi^{\text{LVR}}`
>   throughout — it has **no shorthand**, by the standing no-convenience-
>   abbreviation rule, and none is to be introduced.

---

## **M11. [ADDITION — THE EVENT-TIME PLANT] State, inputs, output**

Iteration is by **event**: \(t \to t+1\) is one swap. All objects below are the
source's, transcribed without reassignment (`SRC:4-25 @ 78381d4`).

**Definition 32 (Event-time plant) [M11].**

\[
	\begin{aligned}
		x \, &= \, \begin{bmatrix} \phi \\ \nu \\ \pi^{\phi} \\ \pi^{\phi} - \pi^{\text{LVR}} \end{bmatrix},
		\qquad
		u_{\text{ex}} \, = \, \begin{bmatrix} \Delta Q_X \\ \Delta Q_M \\ \sigma^2(i(t)) \end{bmatrix},
		\qquad
		u_{\text{en}} \, = \, \begin{bmatrix} \tau_{\text{MEV}} \\ \phi_M \\ \phi_X \end{bmatrix}, \\[4pt]
		y \, &= \, \begin{bmatrix} \pi^{\sigma} \\ \widehat\pi^{\sigma} \end{bmatrix},
		\qquad
		\Theta_{\sigma} \, = \, \begin{bmatrix} \sigma_K^2 \\ \#_{\sigma} \\ s_{\upsilon} \\ \Delta Q_v^{\star} \end{bmatrix}
	\end{aligned}
\]

with the replication target (`SRC:174-202 @ 78381d4`)

\[
	\begin{aligned}
		\pi^{\sigma} \, &= \, \Delta Q_v^{\star}\,\big(\sigma^2(i(t)) - \sigma^2_K\big)^{+},
		\qquad
		\widehat\pi^{\sigma} \, = \, \sum_{i_K} L_{\sigma}(i_K)\; \pi^{l}\big(\sigma(i_K;\Theta_\sigma)\big).
	\end{aligned}
\]

**Standing assumptions (declared, NOT derived).** `\phi_M \equiv \bar\phi_M` for all
\(t\); \((\beta_j,\gamma_j)\) fixed for all \(t\); \(\phi_X(t) = \Phi(\Theta_\phi;\sigma^2(i(t)))\).
**No theorem in the tree licenses freezing \((\beta_j,\gamma_j)\)** — `MevOptimization.lean:465`
(`mevMulti_mono_beta`, T12) proves the *opposite* for \(\beta\): raising positive-slope
sigmoid centers raises the arbitrage hazard. These are modelling assumptions and are to
be carried as hypotheses, never cited as results.

---

## **M12. [ADDITION — THE DIRECT PATH] `τ_MEV` reaches the fee without passing through `ν`**

`SRC:146-160 @ 78381d4` asserts a single five-factor channel

\[
	\frac{\partial\widehat\pi^{\sigma}}{\partial\tau_{\text{MEV}}}
	\; = \;
	\frac{\partial\widehat\pi^{\sigma}}{\partial L_{\sigma}}\;
	\frac{\partial L_{\sigma}}{\partial\pi^{\phi}}\;
	\frac{\partial\pi^{\phi}}{\partial\phi}\;
	\frac{\partial\phi}{\partial\nu}\;
	\frac{\partial\nu}{\partial\tau_{\text{MEV}}},
\]

i.e. that \(\tau_{\text{MEV}}\) reaches the output through **no other path**. Rule 12
(`DOC:1049`, the DECIDED monoid entry) contradicts this.

**Theorem 29 (The monoid path is direct) [M12].** Under Rule 12's
\(\phi_{\text{total}} = \phi_M \otimes_{\phi} \phi_X \otimes_{\phi} \tau_{\text{MEV}}\),

\[
	\begin{aligned}
		\frac{\partial \phi_{\text{total}}}{\partial \tau_{\text{MEV}}}\bigg|_{\phi_M,\,\phi_X}
		\; = \; (1-\phi_M)(1-\phi_X) \; > \; 0
		\qquad (\phi_M,\phi_X < 1),
	\end{aligned}
\]

a path from \(\tau_{\text{MEV}}\) to \(\phi_{\text{total}}\) that does not factor
through \(\nu\). The source's own \(\nabla\phi\) display (`SRC:56 @ 78381d4`) already
carries \((1-\phi_X)(1-\phi_M)\) in the \(\tau\)-slot.

**Corollary (the five-factor product is not the total derivative) [M12].** With two or
more forward paths, the total derivative is the **sum** over paths; the boxed product
is at most the \(\nu\)-mediated partial. Hence the "no other path" clause is **FALSE**
as stated.

**Also to be settled here.** `SRC:129-142 @ 78381d4` boxes the objective as
\(\mathcal G_{\widehat\pi^{\sigma},\tau_{\text{MEV}}} := \partial\widehat\pi^{\sigma}/\partial\tau_{\text{MEV}}\big|_{\lambda_{\text{MEV}}}\)
— conditioned on \(\lambda_{\text{MEV}}\) — while the chain's last factor is
\(\partial\nu/\partial\tau_{\text{MEV}}\). If \(\nu\) reaches \(\tau_{\text{MEV}}\)
only through \(\lambda_{\text{MEV}}\), that conditioning sets the last factor to zero
and the whole product vanishes. State whether the conditioned partial and the
unrestricted total derivative can both satisfy the identity.

---

## **M13. [ADDITION — THE SECTION DEFECT] `∂φ_M/∂φ` and `∂φ_X/∂φ` are not simultaneously defined**

`SRC:102-112 @ 78381d4` computes

\[
	\frac{\partial \pi^{\phi}}{\partial \phi}
	\; = \;
	\frac{\partial \phi_M}{\partial \phi}\,\Delta Q_M
	\; + \;
	p_{(\eta,\Delta_i)}\,\frac{\partial \phi_X}{\partial \phi}\,\Delta Q_X .
\]

**Theorem 30 (Composed fee is a submersion; the section sum is ill-posed) [M13].** The
map \((\phi_M,\phi_X,\tau_{\text{MEV}}) \mapsto \phi_{\text{total}}\) is a submersion
\(\mathbb{R}^3 \to \mathbb{R}\) and admits no inverse. The two summands above are
directional derivatives taken along **different sections** of one level set, so their
sum is not a derivative of \(\pi^{\phi}\) along any single section. Exhibit two
sections agreeing at a point whose induced sums differ.

---

## **M14. [ADDITION — WHAT THE BOX SOLVES] The payoff factor is absent**

**Proposition 12 (The boxed law solves a different equation) [M14].** The boxed
\(\tau^{\star}_{\text{MEV}}\) at `SRC:207-234 @ 78381d4` is algebraically equivalent to

\[
	\frac{\partial\widehat\pi^{\sigma}}{\partial\tau_{\text{MEV}}} \; = \; \Delta Q_v^{\star},
\]

**not** to the stated replication relation \(\pi^{\sigma} \equiv^{R} \widehat\pi^{\sigma}\).
The factor \(\big(\sigma^2(i(t)) - \sigma^2_K\big)^{+}\) of \(\pi^{\sigma}\) does not
appear in the boxed form. Establish the equivalence and the absence.

**Proposition 13 (Implicit, not closed) [M14].** \(\tau_{\text{MEV}}\) appears on both
sides: the \((1-\tau_{\text{MEV}})\) factors produced at `SRC:110 @ 78381d4` are cleared
into the leading \(1-\), while \(\partial\phi/\partial\nu\) differentiates the composed
fee, which contains \(\tau_{\text{MEV}}\). State the condition under which the boxed
form is genuinely closed; if it fails, the object is a fixed-point equation and
existence/uniqueness must be stated separately.

---

## **M15. [ADDITION — ROOT, NOT ARGMIN] The objective has no first-order condition**

**Proposition 14 (No stationarity at the minimum) [M15].** `SRC:204 @ 78381d4` solves
"the minimization" of \(e^{\sigma} = \big|\pi^{\sigma} - \widehat\pi^{\sigma}\big|\).
The absolute value attains its minimum where it is not differentiable, so no
first-order condition characterises the minimiser. The correct object is the **root of
the signed residual**,

\[
	\pi^{\sigma} - \widehat\pi^{\sigma} \; = \; 0 ,
\]

and existence follows from IVT plus strict monotonicity in \(\tau_{\text{MEV}}\), not
from stationarity. State the monotonicity hypothesis this requires.

---

## **M16. [ADDITION — ADMISSIBILITY] The carrier is `[0,1]`**

**Theorem 31 (Admissibility and projection) [M16].** \(\tau_{\text{MEV}}\) lives in the
fee-monoid carrier \([0,1]\) (`TauMevAlgebra`, `tau_monoid_mem`). Give necessary and
sufficient conditions on the signed-residual root for it to lie in \([0,1]\); where the
root leaves the carrier, the admissible control is its **projection**, and the
replication target is **infeasible** at that state rather than attained at a corner.
Treat the two branches separately:

- **ITM branch** \(\sigma^2(i(t)) > \sigma^2_K\): the kink is inactive.
- **OTM branch** \(\sigma^2(i(t)) \le \sigma^2_K\): \(\pi^{\sigma} = 0\), and the
  relation has no interior solution.

---

## **M17. [ADDITION — THE `τ → λ` BRIDGE] The substitution is not licensed**

`SRC:123-142 @ 78381d4` assumes \(\bar{\mathcal G}_{(\nu,\lambda_{\text{MEV}})} :=
\partial\nu/\partial\lambda_{\text{MEV}} > 0\) and then uses it where the channel
requires \(\partial\nu/\partial\tau_{\text{MEV}}\).

**Theorem 32 (Hazard monotonicity in the tax) [M17].** Establish the sign of
\(\partial\lambda_{\text{ARB}}/\partial\tau_{\text{MEV}}\) under the **joint** action of
\(\text{probOr}\,\phi\,\tau = \phi(1-\tau) + \tau\) on `multiFee`'s output — which moves
\(\bar\phi \mapsto \bar\phi(1-\tau)+\tau\) **and** \(\alpha \mapsto \alpha(1-\tau)\)
simultaneously.

> **This is a NEW lemma.** No declaration in the tree establishes it. In particular
> `tau_intensity_effect_strict` is pointwise on `ptrade` while \(\lambda_{\text{ARB}}\)
> is the hazard **sum** (`mevMulti`/`mevHazard`), and `mevMulti_anti_phibar` assumes a
> pure \(\bar\phi\)-shift, which `probOr` is not. Do **not** attempt to compose those
> two into this result — the route does not close. Do **not** cite
> `mevTotal_eq_arb_of_sandwich_zero` (`mevTotal lamARB 0 = lamARB`) in support of
> anything: it is a `ring` tautology.

---

## **M18. [ADDITION — HYPOTHESES, NOT THEOREMS] The behavioural gains**

The following are **LP-supply responses** — estimands observed from add/remove-liquidity
events, not propositions. They enter as **named hypotheses** with a declared sign and
are never to be proved:

\[
	\begin{aligned}
		\text{(H1)} \quad & \frac{\partial \bar L}{\partial \pi^{\phi}} \; > \; 0
		&& \text{(price-axis pool liquidity responds to fee income)} \\
		\text{(H2)} \quad & \bar{\mathcal G}_{(\nu,\lambda_{\text{MEV}})} \; := \; \frac{\partial \nu}{\partial \lambda_{\text{MEV}}} \; > \; 0
		&& \text{(utilization responds to the MEV hazard)}
	\end{aligned}
\]

**On the ladder factorization.** \(L_{\sigma}(i_K) = L_{\sigma}\,\ell(\xi^{\star},\iota;i_K)\)
with \(\ell\) a pure geometric weight, **invariant to the fee payoff**; and
\(\sum_{i_K} L_{\sigma}(i_K) = \Delta Q_v^{\star}\) (`UNITS_AND_SCALES.md:114`, the
**mint SIZING** chain — the volatility axis). Rule 9's sizing map is an identity on the
volatility axis and constrains **nothing** on the price axis. Any argument that
\(\partial L(i_K)/\partial\pi^{\phi} \equiv 0\), and the conclusion
\(\tau^{\star}_{\text{MEV}} = 1\) drawn from it, is an **axis error** and is refuted.

---

## Guards (bind every statement above)

1. **`ptrade` is Möbius with a negative-fee pole.** \(\text{ptrade} = \sigma/(\sigma + \phi\sqrt{2/\Delta t})\)
   is not \(\max(\text{gap} - \text{fee}, 0)\); its pole falsified earlier fee-limit
   theorems. Guard every fee limit against \(\phi < 0\) and against the pole.
2. **Three kinks sit at the differentiation point**: \((\cdot)^{+}\) at the strike,
   \(|\cdot|\) in \(e^{\sigma}\), and the \(\min(\cdot)\) funded cap. No statement may
   differentiate through them; branch instead.
3. **Prefer the tree's native idiom.** Where a sign or ordering claim suffices, state it
   as `Monotone` / `StrictMono` / `StrictAntiOn` / `ConvexOn` rather than building a
   derivative layer. Derivative infrastructure exists in `CapponiEmbed.lean` and may be
   used as precedent, but there are **no** derivative lemmas for `logistic`, `sigmoidR`,
   `multiFee`, `probOr` or `ptrade` — those must be introduced if a statement needs them.
4. **Do not re-attempt** T24 (refuted by counterexample, `mev_ge_flat_under_flair_budget_false`)
   or the Capponi–CES interior embedding (machine-refuted, `canon_Fcap_not_CES`).
5. **No symbol may be minted.** Where the source has no name for an object, write it out
   in full.

---

## What a returned bundle must contain

- One Lean declaration per numbered item above, axiom-clean, zero `sorry`.
- For every claim that **refutes**, an explicit counterexample witness — a refutation is
  the expected outcome for Theorem 29's corollary and Proposition 12, and is a delivered
  result, not a failure.
- Every hypothesis of M18 carried as an explicit typed argument, never discharged.
- No statement silently strengthened relative to the text above.

---
*Bundle spec drafted 2026-08-08 · source pinned at `78381d4` · notation per the user rulings of 2026-08-08.*
