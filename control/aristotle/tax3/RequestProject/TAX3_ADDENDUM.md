# DRAFT — The LVR cancellation, the channel equivalence, and arb-side closure (M25–M27)

**Scope.** Three claims about `∂π̂^σ/∂τ_MEV`. All three are **algebraic**, not behavioural —
they are legitimate to send. `H1` and `H2` remain **typed hypotheses and are never to be
proved**; they may be assumed by name.

**A refutation is a successful outcome.** Each block states its falsification target. Returning
a counterexample is worth more than a proof of a weakened statement. **Do not narrow a claim to
make it provable** — if it is false as stated, exhibit the witness and say so.

---

## Standing bans — violating any of these invalidates the bundle

1. **Never identify Capponi's curvature `κ` with the `ε_{X/M}` substitution axis.** The CES
   embedding is **machine-refuted** (`canon_Fcap_not_CES`): only the endpoints embed, the
   interior does not. Any interior-optimum-in-curvature result must be derived on the CES family
   of `DOC` Definition 13, never imported.
2. **`η` is the GRID-SIDE TILT, not the trading-curve share** (`DOC:184`). It enters the curve
   only through the bridge `χ_{X/M}(η)`, and `DOC` Proposition 7 shows `χ` **cancels
   identically**: `κ_φ` is a function of the substitution axis `ε_{X/M}` **alone**. Do not treat
   `η` as an elasticity.
3. **`π^{\varphi}` (portfolio value function, `DOC:821`) and `π^{\phi}` (fee revenue) are
   DISTINCT objects.** The `φ`/`varphi` split is binding throughout.
4. **`Proposition 13`'s domain lines are guarded.** In `SRC_VOLATILITY_INSTRUMENTS_MEV.md`,
   conjunct 1 is unconditional (modulo non-degeneracy); `τ* < 1` and
   `τ* > 0 ⟺ 1−φ_X < |…|` sit under `0 < ∂φ/∂ν, ∂ν/∂τ_MEV < 0, φ_X < 1`. Never restate them
   without their antecedent. This corrects an earlier erratum and must not be reintroduced.
5. Cite `MevTaxControl.lean` and `MevTaxProgram.lean` results by **declaration name and file**.
   Do not re-derive what is already proved there.

---

## **M25. [CLAIM] The LVR term cancels — `Proposition 13`'s root is invariant**

`DOC` **Proposition 9 (The MMR split)** gives, at fast-block small-fee leading order:

\[
\pi^{\text{ARB}} \approx \pi^{\mathrm{LVR}}\,\mathbb{P}_{\Delta_{\text{ARB}}},
\qquad
\pi^{\phi} \approx \pi^{\mathrm{LVR}}\,(1-\mathbb{P}_{\Delta_{\text{ARB}}}),
\qquad
\pi^{\text{ARB}}+\pi^{\phi} \approx \pi^{\mathrm{LVR}}
\]

with `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` (`DOC` Definition 21) evaluated at the **composed** fee `φ`,
and `π^LVR(t) = σ²(i(t))·π^{\varphi}(t)·Δt/8` in the CPMM case (`DOC:946`).

Assume **(A1)**: `π^φ` reaches `π̂^σ` **only via `L`** (`SRC` Proposition 12).

**Theorem 37 (LVR cancellation) [M25].** Prove or refute:

\[
\frac{\partial \widehat\pi^{\sigma}}{\partial \tau_{\text{MEV}}}
\; = \; K \cdot \Bigl[(1-\phi_M)(1-\phi_X) \; + \; \frac{\partial \phi}{\partial \nu}\,\frac{\partial \nu}{\partial \tau_{\text{MEV}}}\Bigr],
\qquad
K \; = \; \Bigl[\sum_{i_K} \frac{\partial L(i_K)}{\partial \pi^{\phi}}\,\pi^{l}(\sigma(i_K;\cdot))\Bigr]\cdot\Bigl[\pi^{\mathrm{LVR}}\cdot\Bigl(-\frac{\partial \mathbb{P}_{\Delta_{\text{ARB}}}}{\partial \phi}\Bigr)\Bigr]
\]

and that `K > 0` under: `H1_dLbar_dpiPhi_pos`, `π^l > 0`, `π^LVR > 0`, and `ℙ_{Δ_ARB}` strictly
decreasing in `φ`.

**Corollary 37 (Root invariance) [M25].** Hence the zero set of `∂π̂^σ/∂τ_MEV` is **unchanged**
by carrying `π^LVR` in the objective: `K` is a strictly positive common factor, and
`Proposition 13`'s root — `τ* = 1 + (1−φ_X)/((∂φ/∂ν)(∂ν/∂τ_MEV))` — is invariant.

**Why this is asked.** A proposal was made to add the LVR/net-profit channel to the objective on
the theory that it would restore an interior optimum. If M25 holds, that proposal is **futile by
construction** and the effort should not be spent. This is the same structure the M24 audit found
when it ruled the normalizer and the ladder bracket **SPURIOUS**.

**Falsification target.** Exhibit parameters where the factorization fails, or where `K = 0` or
changes sign, or where the zero set is **not** invariant. In particular: is `ℙ_{Δ_ARB}` strictly
decreasing in `φ` on the whole admissible domain, or only where `σ > 0`?

---

## **M26. [CLAIM] Two channels reach `∂ν/∂τ_MEV`, and both give the same sign**

`ν` is the utilization ratio (`DOC` Theorem 1's gate argument):

\[
\nu \; = \; \frac{\varphi_{(1/2,0)}(i_K;\,\Delta Q,\,0;\,t)}{\varphi_{(1/2,0)}(i_K;\,0,\,L;\,t)}
\]

**Route (i) — the hazard channel** (the route the project has assumed):

\[
\frac{\partial \nu}{\partial \tau_{\text{MEV}}} \; = \; \bar{\mathcal{G}}\cdot\frac{\partial \lambda_{\text{MEV}}}{\partial \tau_{\text{MEV}}},
\qquad \bar{\mathcal{G}} = \frac{\partial \nu}{\partial \lambda_{\text{MEV}}} > 0 \;\; (\texttt{H2\_dnu\_dlamMEV\_pos}),
\qquad \frac{\partial \lambda}{\partial \tau} < 0 \;\; (\texttt{Theorem32\_hazard\_strictAntiOn\_tau})
\]

**Route (ii) — the flow channel** (not previously stated):

\[
\frac{\partial \nu}{\partial \tau_{\text{MEV}}} \; = \; \frac{\partial \nu}{\partial \Delta Q}\cdot\frac{\partial \Delta Q}{\partial \phi}\cdot\frac{\partial \phi}{\partial \tau_{\text{MEV}}}\Big|_{\phi_M,\phi_X}
\]

with `∂φ/∂τ|_{φ_M,φ_X} = (1−φ_M)(1−φ_X) > 0` by `Theorem29_monoid_path_is_direct`.

**Theorem 38 (Channel equivalence of sign) [M26].** Prove or refute:

(a) `∂ν/∂ΔQ > 0` — i.e. `ν`'s numerator `φ_{(1/2,0)}(i_K; ΔQ, 0; t)` is strictly increasing in
    the flow `ΔQ`. **State exactly which property of the trading function this requires**, and
    whether `DOC` Definition 13's CES family supplies it.

(b) Under downward-sloping demand (`∂ΔQ/∂φ < 0`), route (ii) gives `∂ν/∂τ_MEV < 0`.

(c) Routes (i) and (ii) **agree in sign**.

(d) **The sign result of route (ii) does NOT require `H2`.** It requires only (a) and downward-
    sloping demand. State precisely what replaces `H2` in that route, and whether it is weaker.

**Why this is asked.** The whole estimation programme routed through `λ_MEV` because `τ_MEV` is
not implemented. Route (ii) reaches the same derivative without `λ`, hence without the
interblock-vs-swap **two-clock conflict** in `λ_ARB`'s summand (`DOC` Definition 22 sums over
swap events `s < t`; `Δt` inside `ℙ_{Δ_ARB}` is mean **interblock** time, `DOC:901`). If (c) and
(d) hold, the controller's **direction** is available with no estimation and no clock ruling.

**Falsification target.** A configuration where the two routes give **opposite** signs — that
would be the sharpest possible result and would mean the two channels are not describing the same
object. Also: is route (ii) a *decomposition* of route (i), or an *independent* path? If both are
live simultaneously, is the total the sum, and does that double-count?

---

## **M27. [CLAIM] The arbitrage component of `∂ΔQ/∂φ` closes in observables**

Split the flow into arbitrage and benign components:

\[
\Delta Q \; = \; \Delta Q^{\text{ARB}} \; + \; \Delta Q^{\text{benign}}
\]

**Theorem 39 (Arb-side closure) [M27].** Prove or refute: `∂ΔQ^{ARB}/∂φ` is a closed form in

\[
\bigl(\sigma(i(t)),\; \phi,\; \Delta t,\; \epsilon_{p/X}\bigr)
\]

with **no free behavioural parameter**, where `ε_{p/X}` is the price-impact elasticity of
`DOC` Definition 14 — declared there to be **"an observable of any member"** of the family.

Grounds: the arbitrageur's participation is `ℙ_{Δ_ARB}(φ, σ, Δt)`, a closed form; their welfare
is `π^ARB = π^LVR·ℙ_{Δ_ARB}` by Proposition 9, with `π^LVR = σ²π^{\varphi}Δt/8`; and their traded
quantity at a given mispricing is determined by the curve's price impact, which `Definition 14`
gives as `κ_φ = |ε_{p/X}|/(|ε_{p/X}| + |ε^0_{p/X}|)` with `DOC` Proposition 7's closed form
`κ_φ(ε_{X/M}) = (1−ε_{X/M})/(2−ε_{X/M})`.

**If it does not close, NAME the missing primitive precisely** — that is the more valuable answer.

**Explicitly NOT claimed:** that `∂ΔQ^{benign}/∂φ` closes. Noise traders have no profit function
in this model. `DOC`'s `[M8]` caveats record this as **"NO DEMAND ELASTICITY — the missing term
is MMR §7.3 eq. (27)"** and name `OPT_FEES` as the elasticity layer. Do not attempt to supply it.

**Why this is asked.** If M27 holds, the estimation burden collapses from "identify a behavioural
gain `Ḡ` with no valid instrument" to "one narrow primitive on **benign flow only**", and the
arbitrage side of the controller is derivable from quantities the pool already measures.

**Falsification target.** Show that `∂ΔQ^{ARB}/∂φ` requires a primitive beyond
`(σ, φ, Δt, ε_{p/X})` — e.g. a mispricing distribution, an arb-capital constraint, or a
competition parameter — and identify it. Note `[M8]`'s standing caveats: **LEADING ORDER**
(everything rests on fast-block small-fee asymptotics) and **QUASI-STATIC** (`ℙ_{Δ_ARB}` is
steady-state, applied per step on a `σ`-varying path). If either caveat is what blocks closure,
say so — that is a result.

---

## What a complete return looks like

- `Theorem 37` + `Corollary 37`, or a witness refuting either.
- `Theorem 38` (a)–(d), or a witness where the channels disagree.
- `Theorem 39`, or the **named** missing primitive.
- Every declaration `#print axioms`-clean or its dependency stated.
- **No new `sorry`.** A stated `OPEN` with a reason is preferred to a narrowed theorem.
