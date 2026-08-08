# DRAFT — Corrected MEV-tax program (M19–M24) for `VOLATILITY_INSTRUMENTS.md ### MEV`

> STATUS: DRAFT spec for the **second** Aristotle tax bundle. Numbering continues
> the live doc and the first bundle: `Definition 33+`, `Theorem 33+`,
> `Proposition 15+`, provenance tag `[M19]+`.
>
> **This bundle CORRECTS the objective of the first one.** Bundle 1
> (`MevTaxControl.lean`, blocks M11–M18) adjudicated the derivation as written in
> `SRC` and found that it solves `∂π̂^σ/∂τ_MEV = ΔQ_v^⋆`, which is not the
> replication relation. **The author has since ruled that replication was never the
> objective.** The corrected program is stated in M19 and supersedes
> `SRC:171-178 @ 78381d4` ("the target replication relation"), which misstates the
> author's intent and is to be treated as an erratum in the source, not as the spec.
>
> **Available and already proved** in `MevTaxControl.lean` — cite, do not redo:
> `Theorem29_monoid_path_is_direct`, `Theorem30_composed_fee_submersion_section_sum_ill_posed`,
> `Theorem32_hazard_strictAntiOn_tau`, `tau_to_nu_strictAntiOn_under_H2`,
> `M18_axis_error_refuted`, and the hypotheses `H1_dLbar_dpiPhi_pos`,
> `H2_dnu_dlamMEV_pos`.
>
> **Notation is unchanged and binding.** `L_{\sigma} \equiv \Delta Q_v^{\star}` is the
> volatility axis; plain `L`, `\bar L` the price axis. `\pi^{\varphi}` remains `DOC`
> Definition 25's portfolio value function; the source's composite is written out in
> full as `\pi^{\phi} - \pi^{\text{LVR}}`. Mint no symbol.

---

## **M19. [CORRECTION — THE PROGRAM] Exposure minimization, replication as a constraint**

The MEV tax does **not** enforce replication. Replication is the job of the order
parameters \(\Theta_\sigma\) and the ladder \((\xi^{\star},\iota)\). The tax's job is to
**minimize the exposure of the realizable payoff to the adversarial environment**.

**Definition 33 (The corrected tax program) [M19].**

\[
	\begin{aligned}
		\min_{\tau_{\text{MEV}} \in [0,1]} \;\; \mathcal{E}(\tau_{\text{MEV}})
		\qquad \text{subject to} \qquad
		\pi^{\sigma} \; = \; \widehat\pi^{\sigma},
	\end{aligned}
\]

where \(\mathcal{E}\) measures the sensitivity of the realizable payoff to the tax
lever, and the **first-order condition** is

\[
	\boxed{\;\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}} \; = \; 0\;}
\]

The constraint set is a **feasibility region**, not the objective. State explicitly
that a \(\tau_{\text{MEV}}\) satisfying the FOC need not satisfy the constraint, and
vice versa, and that the earlier condition
\(\partial\widehat\pi^{\sigma}/\partial\tau_{\text{MEV}} = \Delta Q_v^{\star}\) is
**neither** — it is the artefact of the superseded replication framing.

---

## **M20. [ADDITION — THE CORRECT TOTAL DERIVATIVE] All paths, not one**

**Theorem 33 (Path decomposition of `∂π̂^σ/∂τ_MEV`) [M20].** Enumerate **every**
route by which \(\tau_{\text{MEV}}\) reaches \(\widehat\pi^{\sigma}\) and state the
total derivative as their **sum**. At minimum both of:

- **(P-direct)** the Rule 12 monoid path, \(\partial\phi_{\text{total}}/\partial\tau_{\text{MEV}}\big|_{\phi_M,\phi_X} = (1-\phi_M)(1-\phi_X)\) — `Theorem29_monoid_path_is_direct`;
- **(P-gate)** the utilization-gate path, \(\tau_{\text{MEV}} \to \nu \to \phi \to \pi^{\phi} \to \bar L \to \widehat\pi^{\sigma}\),

carried through to \(\widehat\pi^{\sigma}\) via the price-axis liquidity response (H1).
If further routes exist, name them; if these two are exhaustive, prove exhaustiveness.
Show that the source's five-factor product is **exactly one summand** (P-gate), so it
is not the total derivative.

---

## **M21. [ADDITION — SIGN STRUCTURE] The two paths oppose**

**Theorem 34 (Opposed signs) [M21].** Under \(\alpha_R,\gamma_R > 0\),
\(\alpha_j \ge 0\) not all zero (the conditions making `DOC` Definition 18's gate
responsive), and (H2):

\[
	\begin{aligned}
		\text{(P-direct)} \quad & (1-\phi_M)(1-\phi_X) \; > \; 0, \\[2pt]
		\text{(P-gate)} \quad & \frac{\partial \phi}{\partial \nu}\,\frac{\partial \nu}{\partial \tau_{\text{MEV}}} \; = \; (+)\cdot(-) \; < \; 0 ,
	\end{aligned}
\]

the first from `Theorem29_monoid_path_is_direct`, the second from
\(\partial\phi/\partial\nu > 0\) (the boxed form of `ENTRY_POINT.md`, strictly positive
under the stated conditions) composed with `tau_to_nu_strictAntiOn_under_H2`.

**Consequence to state.** The total derivative is a **difference of a positive and a
negative contribution**, so dropping (P-direct) does not merely undercount — it can
**reverse the sign** of the answer. Economically: the tax stacks mechanically onto the
fee while suppressing utilization closes the volatility gate.

---

## **M22. [ADDITION — THE FIRST-ORDER CONDITION] Interior cancellation**

**Theorem 35 (Existence of an interior root) [M22].** Give necessary and sufficient
conditions for
\(\partial\widehat\pi^{\sigma}/\partial\tau_{\text{MEV}} = 0\) to have a solution in
the interior of \([0,1]\) — the point at which (P-direct) and (P-gate) cancel. Existence
should follow from IVT plus continuity given a sign change across the interval, not from
stationarity of an absolute value.

**Theorem 36 (Non-existence on the saturation bands) [M22].** `DOC` Definition 18's gate
is a sigmoid in \(\nu\). Where it saturates — \(\partial\phi/\partial\nu = 0\) — (P-gate)
vanishes identically and only the strictly positive (P-direct) survives, so
\(\partial\widehat\pi^{\sigma}/\partial\tau_{\text{MEV}} > 0\) throughout and **no
interior root exists**. State the band on which the root can live, in terms of
\(\beta_R, \gamma_R\) and \(\nu\). This is a **domain condition on the controller**, not
an implementation detail.

---

## **M23. [ADDITION — SECOND ORDER] Is the root a minimum?**

**Proposition 15 (Second-order condition) [M23].** The FOC locates a stationary point of
the exposure. State the second-order condition distinguishing a **minimum** of exposure
from a maximum or an inflection, and the hypotheses under which it holds. If the sign of
the second derivative cannot be settled without further structure, say so and name the
structure that would settle it — do **not** assume the stationary point is the minimiser.

---

## **M24. [ADDITION — TERM-BY-TERM AUDIT] What survives of the boxed law**

**Proposition 16 (Audit of the source's `τ*_MEV`) [M24].** For **each** factor of the
boxed law at `SRC:207-234 @ 78381d4`

\[
	\tau^{\star}_{\text{MEV}}
	=
	1 - \frac{1}{\Delta Q_v^{\star}}
	\Big[\textstyle\sum_{i_K} \pi^{l}\,\tfrac{\partial L(i_K)}{\partial \pi^{\phi}}\Big]
	\Big[\tfrac{\Delta Q_M}{1-\phi_X} + \tfrac{p_{(\eta,\Delta_i)}\Delta Q_X}{1-\phi_M}\Big]
	\tfrac{\partial \phi}{\partial \nu}\;\tfrac{\partial \nu}{\partial \tau_{\text{MEV}}},
\]

return a verdict from exactly one of:

- **SURVIVES** — the factor appears in the corrected FOC with the same form and sign;
- **SIGN CORRECTED** — same factor, opposite sign, with the corrected sign stated;
- **ILL-POSED** — the factor has no section-independent value (cf. `Theorem30`);
- **MISSING** — a factor the corrected FOC requires that the box omits;
- **SPURIOUS** — a factor the corrected FOC does not contain (in particular, whether the
  leading \(1-\) and the \(1/\Delta Q_v^{\star}\) normalizer survive once the RHS is
  \(0\) rather than \(\Delta Q_v^{\star}\)).

Then **derive the corrected law** from the FOC of M19: give
\(\tau^{\star}_{\text{MEV}}\) in closed form where the FOC admits one, or state it as an
implicit equation with existence and uniqueness conditions where it does not. State its
**domain** — the responsive band of M22 and the ITM/OTM branch structure.

---

## Guards (unchanged, and binding)

1. `ptrade` is Möbius with a negative-fee pole — guard every fee limit; keep the
   composed fee in \([0,1)\).
2. Branch the kinks: \((\cdot)^{+}\) at the strike and the \(\min(\cdot)\) funded cap.
   The \(|\cdot|\) objective of the superseded framing does **not** appear in this
   program — the FOC is on a derivative, not on an absolute value.
3. (H1) and (H2) remain typed hypotheses, never discharged.
4. Do not re-attempt T24 or the Capponi–CES interior embedding.
5. Mint no symbol.

---

## What a returned bundle must contain

- One declaration per numbered item, axiom-clean, zero `sorry`.
- An explicit statement of the corrected \(\tau^{\star}_{\text{MEV}}\), or of why no
  closed form exists, together with its domain.
- A per-factor verdict table for M24 covering every factor of the source's box.
- Every unsettled point named with the hypothesis that would settle it — nothing left
  looking proved.

---
*Bundle spec drafted 2026-08-08 · corrects the objective of bundle 1 · source pinned at `78381d4`.*
