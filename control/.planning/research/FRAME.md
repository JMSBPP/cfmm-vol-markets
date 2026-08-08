# Frame Research — Control-theoretic basis for optimal set-point selection on an event-time MIMO plant

**Domain:** Static optimal set-point (`τ*_MEV`) on a multivariable, event-indexed, disturbance-driven plant; deliverable is a Lean-verifiable, EVM-analyzable design spec.
**Researched:** 2026-08-08
**Overall confidence:** MEDIUM-HIGH (frame recommendation HIGH; two named findings against the source derivation MEDIUM; the event↔time bridge is reported as an OPEN modelling question, not resolved)

> **Sourcing disclosure (read first).** The brief instructed me to prioritise the arXiv MCP server. **The arXiv MCP tools were not present in this agent's toolset** (no `mcp__arxiv__*`, no `ToolSearch`), and outbound `curl` is blocked in the sandbox. I therefore queried the **arXiv API directly through `WebFetch`** (`export.arxiv.org/api/query`) for arXiv-hosted work — that is a primary-source route and IDs/titles/authors below are verified against it — and used web search only for pre-arXiv classics (Ogata, Skogestad, Mason, Davis, Kreindler–Sarachik, Wolff, Fiacco, Brockett–Mesarović, Silverman, Blondel–Tsitsiklis, Rugh–Shamma, Bertsimas–Kogan–Lo). Every citation below carries an explicit confidence tag. **Nothing is cited from memory without a tag.** Where I could not verify a detail (notably the internal section numbering of Skogestad & Postlethwaite Ch. 10, and one quantitative detail in Fukasawa) I say UNVERIFIED rather than assert it.

---

## 0. Verdict — the recommended frame, in one sentence

> **Frame the problem as *per-event static plant inversion at an operating point*, formulated in the language of *controlled-variable selection / self-optimizing control*, on the *embedded jump chain of a piecewise-deterministic event process*; discharge well-posedness with the *Implicit Function Theorem + intermediate-value + strict-monotonicity* triple (not a controllability Gramian, not a Riccati equation); and discharge the 5-factor channel claim as a *single-forward-path statement in the signal-flow graph via Mason's gain formula*.**

Compact name to use in the spec: **static plant inversion (exact feedforward) on the event-indexed jump chain**.

This frame is recommended because it is the *only* one surveyed in which (i) the unknown solved for is a **value** `τ*` rather than a **gain** `K`, (ii) the exogenous disturbance `u_ex` enters natively rather than as a robustness nuisance, (iii) the well-posedness obligations reduce to statements Mathlib already carries (`HasStrictDerivAt`, `StrictMonoOn`, `intermediate_value_Icc`, the implicit function theorem), and (iv) the resulting on-chain object is one closed-form algebraic evaluation, not an iterative solve.

---

## 1. Recommended frame — core results

| Frame element | Canonical source | What it supplies | Why this one | Conf. |
|---|---|---|---|---|
| **Linearization about an operating point** — the honest reading of `∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u)` | Ogata, *Modern Control Engineering*, 5th ed., **Ch. 2 (Mathematical Modeling of Control Systems)** | The ∂-partition is a **Jacobian of a nonlinear event map at `(x̄,ū)`**, valid in *deviation* coordinates only | The source's recursion is otherwise a category error (missing affine offset); this names it correctly and bounds its validity | HIGH (TOC verified from publisher) |
| **Steady-state / DC-gain map + steady-state error analysis** | Ogata, 5th ed., **Ch. 5 (Transient and Steady-State Response Analyses)** — the *steady-state* half only | `x_ss = (I−A)⁻¹Bu_ss`, `y_ss = [C(I−A)⁻¹B + D]u_ss`; existence ⟺ `1 ∉ spec(A)` | This is the object a "set-point" actually lives on. The existence test is a real, load-bearing gate here (see §4, W1) | HIGH |
| **Controlled-variable selection / self-optimizing control** — *the* frame for "which variable do we hold, at what set-point, so operation stays near-optimal under disturbances" | **Skogestad (2000)**, *J. Process Control* **10**, 487–507, "Plantwide control: the search for the self-optimizing control structure"; **Jäschke, Cao & Kariwala (2017)**, *Annual Reviews in Control* **43**, 199–223, "Self-optimizing control — A survey"; textbook home: Skogestad & Postlethwaite, *Multivariable Feedback Control*, 2nd ed. (Wiley 2005), **Ch. 10 Control Structure Design** | The formal apparatus for `c = Hy`: which combination of outputs is the controlled variable, and the *loss* incurred by holding it constant under `u_ex` | Directly resolves the "2 outputs, 1 actuator" apparent underactuation (§5): `π^σ` is a **measured disturbance**, not an output; `c = π^σ − π̂^σ` is the CV | HIGH for the two papers; **MEDIUM** for the textbook chapter *title*; **UNVERIFIED** for its internal section numbers |
| **Null-space method** — construct `H` so the set-point is *invariant* to the disturbance | **Alstad & Skogestad (2007)**, *Ind. Eng. Chem. Res.* **46**(3), 846–853; extended in **Alstad, Skogestad & Hori (2009)**, *J. Process Control* **19**, 128–148 | `H` in the left null space of `F = dy_opt/dd` ⟹ **zero loss** at constant set-point, noise-free | The single highest-leverage EVM-cost question: if such an `H` exists, `τ*` need not be recomputed per swap. Gives an *exact test*, not a heuristic | HIGH |
| **Exact local method / maximum-gain (minimum-singular-value) rule** — screening a candidate CV | **Halvorsen, Skogestad, Morud & Alstad (2003)**, *Ind. Eng. Chem. Res.* **42**(14), 3273–3284, "Optimal selection of controlled variables" | Quantifies the economic loss of a CV choice; the max-gain rule is the steady-state σ̲ screen | The correct steady-state conditioning test for "is `τ_MEV` a well-conditioned actuator for `π̂^σ`" | HIGH |
| **Right-invertibility / functional reproducibility** — can the output be made to follow a prescribed function by choice of input | **Brockett & Mesarović (1965)**, *J. Math. Anal. Appl.* **11**, 548–563, "The reproducibility of multivariable control systems"; **Silverman (1969)**, *IEEE Trans. Automat. Control* **AC-14**, 270–276, "Inversion of multivariable linear systems" (structure algorithm) | The exact control-theoretic name for "solve the plant backwards for the input that produces the target output" | This *is* what `τ* = …` is. Naming it correctly stops the spec from reaching for a controllability Gramian | HIGH on existence/venue; **MEDIUM** on the volume number for Silverman (sources report both AC-14 and AC-19 for 1969) |
| **Output controllability rank condition** | **Kreindler & Sarachik (1964)**, *IEEE Trans. Automat. Control* **9**(2), 129–136 | `rank[CB, CAB, …, CA^{n−1}B, D] = p` — the output analogue of the Kalman rank test | Needed to state precisely *what* underactuation does and does not forbid (§5). Cite it to *bound* the claim, not to establish well-posedness | HIGH |
| **Implicit Function Theorem (Dini)** + IVT + strict monotonicity | Standard analysis; Mathlib has all three | **The actual well-posedness theorem** for the boxed `τ*`: existence, local uniqueness, and `C¹` dependence on `(u_ex, Θ)` | Machine-verifiable in Lean today, with no new mathematical library | HIGH |
| **Parametric sensitivity of an optimal solution** | **Fiacco (1976)**, *Mathematical Programming* **10**, 287–331, "Sensitivity analysis for nonlinear programming using penalty methods"; book: Fiacco (1983), *Introduction to Sensitivity and Stability Analysis in Nonlinear Programming* | Differentiability of `τ*(d)` w.r.t. the disturbance, under LICQ + strict complementarity + second-order sufficiency | Required *only if* `τ*` is defined by a minimization rather than a root. See §4 W4 — the source is ambiguous and the ambiguity matters | HIGH |
| **Mason's gain formula / signal-flow graphs** | **Mason (1953)**, *Proc. IRE* **41**, 1144–1156, "Feedback Theory — Some Properties of Signal Flow Graphs"; sequel **Mason (1956)**, *Proc. IRE* **44**, 920–926, "…Further Properties…" | Total transmittance = Σ over **forward paths** × path cofactors / Δ, with `Δ = 1 − ΣLᵢ + ΣLᵢLⱼ − …` | **This is the exact formalism for PROJECT.md's 5-factor-channel claim.** The claim is precisely "there is one forward path and no touching loops" | HIGH |
| **Piecewise-deterministic Markov process (PDMP)** — the event-time carrier | **Davis (1984)**, *J. R. Statist. Soc. B* **46**(3), 353–388, "Piecewise-Deterministic Markov Processes: A General Class of Non-Diffusion Stochastic Models" | Deterministic flow between events + random jumps at event epochs; the **embedded jump chain** is exactly `t → t+1 := event swap`; extended generator converts event statements to time statements | The plant literally is this: price/vol drifts between swaps, jumps at swaps. Nothing else surveyed matches | HIGH |
| **PASTA / ASTA** — the event-clock ↔ wall-clock bridge | **Wolff (1982)**, *Operations Research* **30**(2), 223–231, "Poisson Arrivals See Time Averages"; **Melamed & Whitt (1990)** on ASTA under the weak lack-of-anticipation assumption | Event-indexed averages equal time averages **iff** a lack-of-anticipation condition holds | The spec mixes per-event objects (`ΔQ_M`, `ΔQ_X`) with per-*time* objects (`π^LVR·Δt`, `σ²`, `λ`). This is the theorem that licenses — or forbids — that mixing. **In a CFMM, arb swaps arrive *because of* the state, so LAA fails and PASTA does NOT hold.** | HIGH on the theorems; **HIGH** on the LAA-failure argument being *required*, MEDIUM on it being fatal |
| **Gain scheduling / quasi-LPV** — what `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` makes the plant | **Rugh & Shamma (2000)**, *Automatica* **36**(10), 1401–1425, "Research on gain scheduling" | The correct name for a plant whose "matrices" depend on a measured exogenous signal | `φ_X` is not an actuator and not a constant: it is a **scheduling variable**. `τ*` is therefore a *scheduled static map*, not a number | HIGH |

---

## 2. Supporting results — the replication / financial half

| Result | Source | Role here | Conf. |
|---|---|---|---|
| **Fenchel-conjugate duality between a CFMM trading function and the payoff it replicates** | Angeris, Evans & Chitra, **arXiv:2103.14769**, *Replicating Market Makers* (26 Mar 2021); companion **arXiv:2111.13740**, *Replicating Monotonic Payoffs Without Oracles* (26 Nov 2021) | The CFMM-side static inversion: concave payoff ⟺ convex CFMM. Closest existing thing to "replication as set-point selection" | HIGH (arXiv API verified: ids, titles, authors, dates) |
| **Variance-swap replication is *semi-static*: a static strike portfolio PLUS a continuously rebalanced underlying leg** | Demeterfi, Derman, Kamal & Zou (Mar 1999), *More Than You Ever Wanted To Know About Volatility Swaps*, Goldman Sachs Quantitative Strategies Research Notes — **locally vendored**: `cfmm-wt/plank/refs/DemeterfietalVarianceSwaps.pdf` | **This is the axis split.** v2-controller took the *static strike* leg (spatial). **This project is the rebalancing leg** (event/time). The two are the two halves of one replication | HIGH (PDF header read directly) |
| **Discrete-rebalancing replication error: asymptotic distribution and "temporal granularity"** | Bertsimas, Kogan & Lo (2000), *J. Financial Economics* **55**(2), 173–204, "When is time continuous?" | Quantifies what is lost by rebalancing at discrete epochs rather than continuously — i.e. the intrinsic error floor of an event-clocked replication | HIGH on venue/title; the specific `n^{-1/2}` rate was **not** confirmed in an accessible abstract → treat rate claims as UNVERIFIED until the paper is read |
| **Non-uniform / stochastic partitions can be *asymptotically efficient* for discretising stochastic integrals** | Fukasawa (2011), *Ann. Appl. Probab.* **21**(4), 1436–1465, "Discretization error of stochastic integrals" (arXiv:1004.2107); Fukasawa, *Finance and Stochastics* (2014), "Efficient discretization of stochastic integrals" (**arXiv:1204.0637**) | **The justification that event-time is not a defect.** Sharp asymptotic lower bounds on discretisation error, attained by adaptive (non-equidistant) partitions | HIGH on titles/venues/abstract content ("sharp asymptotic lower bounds… asymptotically efficient schemes which attain the lower bounds… applicable to hedging"). The stronger folk claim that *hitting-time* partitions beat equidistant ones by a factor `(d+2)/d` appeared only in a **secondary search summary** → **MEDIUM / UNVERIFIED**, must be confirmed from the PDF before it enters the spec |

**Answer to Q5, stated plainly: I found NO literature that bridges Carr–Madan / Breeden–Litzenberger static spanning to control-theoretic set-point selection.** The bridge is conceptually available — payoff replication by choice of input *is* plant inversion (Brockett–Mesarović; Silverman) — but **it is not written down anywhere I could find**. This is an *absence of evidence*, reported as such. If the spec asserts the bridge, it is constructing it, and must say so.

---

## 3. Q1 — What in Ogata and Skogestad & Postlethwaite actually applies

### Ogata, *Modern Control Engineering*, 5th ed. (chapter list verified from Pearson: 10 chapters)

| Ch. | Title | Verdict |
|---|---|---|
| 1 | Introduction to Control Systems | — |
| **2** | **Mathematical Modeling of Control Systems** | **USE.** Linearization of a nonlinear system about an operating point. This is precisely what the ∂-partition is |
| 3 | Modeling of Mechanical / Electrical Systems | Not applicable (domain) |
| 4 | Modeling of Fluid / Thermal Systems | Not applicable (domain) |
| **5** | **Transient and Steady-State Response Analyses** | **USE THE STEADY-STATE HALF ONLY.** Static/DC gain, steady-state error. The *transient* half (rise time, overshoot, settling) is meaningless with no loop |
| 6 | Root-Locus Method | **DO NOT USE** — closed-loop pole migration under a scalar gain. There is no loop |
| 7 | Frequency-Response Method | **DO NOT USE** — Bode/Nyquist/gain & phase margins are loop-stability tools |
| 8 | PID and Modified PID Controllers | **DO NOT USE** — explicitly out of scope (regulator) |
| **9** | **Control Systems Analysis in State Space** | **USE WITH CAUTION.** State-space representation, discretisation, controllability/observability. See §5: the Kalman rank test on `(A,B)` is the **wrong** well-posedness test for a static problem and will mislead |
| 10 | Control Systems Design in State Space | **DO NOT USE** — pole placement, observers, **quadratic optimal regulator (LQR)**. Explicitly excluded by PROJECT.md scope |

### Skogestad & Postlethwaite, *Multivariable Feedback Control: Analysis and Design*, 2nd ed. (Wiley, 2005)

- **Ch. 10, "Control Structure Design" — the only squarely on-topic chapter.** The publisher's "new to this edition" material states this chapter was reorganised with new content on **selection of controlled variables and self-optimizing control**. **USE.**
  - *Verification status:* the chapter **title and topical content are MEDIUM confidence** (from publisher/secondary summaries); I could **not** retrieve the extended TOC (the NTNU book page's TOC link 404s; Wiley returns 403; dokumen.pub is down). **Internal section numbers are UNVERIFIED — do not cite `§10.3` in the spec.** Route the primary citation through **Skogestad (2000)** and **Jäschke–Cao–Kariwala (2017)**, both verified above.
- **The MIMO "limitations on performance" material** (RGA, condition number, minimum singular value, directionality, right-half-plane zeros): **use only the steady-state (`ω = 0`) instruments** — the steady-state RGA and the maximum-gain/minimum-singular-value rule, as the screen for whether `τ_MEV` is a well-conditioned actuator for `π̂^σ`. The RHP-zero / bandwidth / waterbed content is about achievable *loop* performance and does not apply. *(Chapter number UNVERIFIED — refer to this material by topic, and cite Halvorsen et al. 2003 for the max-gain rule, which is verified.)*
- **Everything else — DO NOT USE:** classical SISO loop shaping, uncertainty description, robust stability, robust performance, μ-synthesis, H∞ / LQG controller synthesis, decentralized-control pairing (RGA pairing rules presuppose loops).

---

## 4. Q2 — Set-point selection vs LQR/LQG/servo, and its well-posedness

### The distinction, sharply

| | **(a) Optimal set-point / operating-point selection** | **(b) LQR / LQG / servo tracking** |
|---|---|---|
| Unknown solved for | a **value** `u* ∈ ℝᵐ`, or a static map `u*(d)` | a **gain** `K`, or a dynamic compensator |
| Governing equation | algebraic: `f(x*,u*,d) = 0` and `h(x*,u*) = r` (or a stationarity/KKT system) | Riccati (algebraic or difference) equation |
| Does time enter? | **No.** The object is an equilibrium or a per-event static map | **Essentially.** Horizon, accumulated cost, closed-loop eigenvalues |
| Well-posedness conditions | Jacobian regularity (IFT); right-invertibility of the steady-state gain; second-order sufficiency if it is a minimisation; feasibility of the admissible box | Stabilizability of `(A,B)`, detectability of `(A,C)`, `Q ⪰ 0`, `R ≻ 0`, no undamped unobservable modes |
| Stability question | **None.** There is no loop to destabilise | Central |
| Lean formalisation cost | Low — IFT, IVT, `StrictMonoOn` are all in Mathlib | Very high — matrix Riccati, spectral theory, existence of stabilising solutions |
| EVM cost | One algebraic evaluation | Off-chain synthesis + on-chain matvec (v2's frame) |

**The exclusion is justified by construction, not by preference:** PROJECT.md solves for a *number in `[0,1]`* that makes a *payoff identity* hold. There is no state to drive to zero over time, no error dynamics, no horizon, and no closed loop. Every LQ/servo instrument answers a question this project does not ask.

### Well-posedness conditions the spec must discharge — and where each can fail

**W1 — Existence of the steady state. `1 ∉ spec(∂_(t+1,t))`.**
`x_ss = (I − A)⁻¹Bu_ss` requires `(I − A)` invertible. **This is a live hazard in this plant.** The document's hazard objects are *running sums*: `λ_FLAIR(t) = ∫`, `λ_ARB(t) = Σ_{s<t}(…)`, `λ̃_JIT = Σ_{e∈𝓔}(…)`. **Any coordinate that is a running sum carries a unit eigenvalue and has no steady state.** The declared state `x = [φ, ν, π^φ, π^φ̃]ᵀ` looks safe (all four are per-step objects under the CONTROL_OPERATORS discretisation frame), but the control channel routes through `∂ν/∂λ_MEV`, and `λ_MEV` *is* an accumulator. **Obligation: prove that no state coordinate is an accumulator, or replace accumulator coordinates by their per-event increments before the ∂-partition is written.**

**W2 — Right-invertibility of the steady-state map at the operating point.** Brockett–Mesarović (1965) / Silverman (1969). For a *static* target only the rank of the steady-state gain matters (see §5).

**W3 — The Implicit Function Theorem is the actual well-posedness theorem.** Define the **signed** residual
`r(τ; d, Θ) := π^σ(d,Θ) − π̂^σ(τ, d, Θ)`.
Then:
- **Existence** on the admissible box: `r` continuous on `[0,1]` with `r(0)·r(1) ≤ 0` ⟹ a root exists (IVT).
- **Uniqueness**: `r` strictly monotone in `τ` on `[0,1]`.
- **Local `C¹` dependence on `(u_ex, Θ)`**: `r ∈ C¹` and `∂r/∂τ ≠ 0` at the root ⟹ IFT gives `τ*(d,Θ)` locally unique and `C¹`, with `dτ*/dd = −(∂r/∂τ)⁻¹(∂r/∂d)`.
This triple **is** the "well-posedness of optimizing a set-point" obligation, and it is the whole of it.

**W4 — Root vs argmin: the source is ambiguous, and it matters.** `notes/VOLATILITY_INTRUMENTS_MEV.md` line 204 says *"solving for `τ_MEV` on the **minimization**"* but then displays a closed form obtained from the **equation** `π^σ ≡^R π̂^σ`. The document also defines `e^σ = |π^σ − π̂^σ|`. These coincide **only if the residual actually attains zero inside `[0,1]`**.
> **FINDING (MEDIUM–HIGH confidence, concrete):** if `τ*` is defined as `argmin |π^σ − π̂^σ|`, then **no first-order condition exists at the solution** — `|·|` is not differentiable at `0`, so setting a derivative to zero is invalid. This is *exactly the failure mode the source itself already documented elsewhere*: `VOLATILITY_INSTRUMENTS.md` Theorem 25 states of `ς*_{X/M}` that it "is a BRANCH POINT — a kink; the derivative jumps; **no first-order condition exists and none is claimed**." The spec must be consistent: **state `τ*` as the root of the signed residual, not the stationary point of the absolute error.** If the objective genuinely is a minimisation over a box where the residual cannot reach zero, then Fiacco (1976) supplies the parametric-sensitivity machinery and the answer is a boundary/KKT point, not the boxed formula.

**W5 — Admissibility. `τ_MEV ∈ [0,1]`.** Forced by Theorem 14 (`⊗_φ` is closed on `[0,1]`). The boxed form is `1 − (bracket)` with nothing bounding the bracket. When the unconstrained root leaves the box, the correct object is the **projection**, and the replication target is *infeasible* — this is precisely the constrained steady-state target calculation of **Rao & Rawlings (1999)**, *AIChE J.* **45**(6), "Steady states and constraints in model predictive control" (verified). The spec must state the infeasible-case fallback, and on-chain must **saturate, never revert** (inherited from v2 SPEC-02).

**W6 — Dimensional consistency.** `τ` is dimensionless in `[0,1]`; the RHS bracket is `[payoff · ∂L/∂π^φ] × [quantity/(1−fee)] × [∂φ/∂ν] × [∂ν/∂τ] / ΔQ_v*`. A dimensional-analysis lemma is a cheap, high-value gate and should be an explicit proof obligation.

**W7 — Is the "closed form" actually closed?**
> **FINDING (MEDIUM confidence, checkable by substitution):** the source computes `∂π^φ/∂φ = ΔQ_M/((1−τ)(1−φ_X)) + p·ΔQ_X/((1−τ)(1−φ_M))` (line 110) — **`τ` appears inside the channel**. The boxed `τ*` clears the `(1−τ)` denominators into the leading `1 −`. That rearrangement is valid **only if `(∂φ/∂ν)(∂ν/∂τ)` is itself independent of `τ`**. `∂ν/∂τ` is assumed constant (`Ḡ_(ν,λ_MEV)`), but `∂φ/∂ν` is a derivative of the *composed* fee, which by Rule 12 contains `τ`. If it does, the display is an **implicit fixed-point equation in `τ`, not a closed form** — with material EVM consequences (a fixed-point iteration is not on-chain-affordable). **Obligation: verify by substitution.**

### What specifically breaks under event indexing

- **"Steady state" loses its meaning.** Classical steady state = constant input, `t → ∞`. In event time the exogenous input *is* the swap flow; there is no "constant input" regime. The correct substitute is **per-event static inversion**: `τ*` is recomputed at each event as a static map of the current disturbance. That is legitimate and is exactly what an on-chain hook does — but it **invalidates every argument appealing to convergence, settling, asymptotic tracking, or steady-state error constants.** Delete such language from the spec.
- **Timescale separation is unavailable.** The classical licence for a static optimisation layer above a plant is timescale separation, quantified in Hauswirth, Bolognani, Hug & Dörfler, **arXiv:1905.06291**, *Timescale Separation in Autonomous Optimization* (verified). Here the set-point moves at *exactly* the disturbance rate — zero separation. The replacement justification must be **exactness**: the inversion is algebraically exact per event, so no separation is needed — **provided the plant map is memoryless in the event index.** If `∂_(t+1,t) ≠ 0` (the plant carries state across swaps), the per-event inverse is only first-order correct and the residual **accumulates**. This is a first-class obligation, not a footnote.

---

## 5. Q4 — Underactuation: one free actuator against a 2-vector output

**Direct answer: the underactuation is apparent, not real. It does not invalidate set-point optimization. But the spec must say why, explicitly, in controlled-variable-selection language.**

**5.1 What is genuinely forbidden.** The steady-state gain from a scalar input to a 2-vector output is a `2×1` matrix, hence `rank ≤ 1 < 2`. **You cannot assign `(π^σ, π̂^σ)` independently at steady state.** True, unavoidable, and correctly diagnosed by the max-gain/σ̲ screen.

**5.2 Why that does not matter here.** `π^σ = ΔQ_v*(σ²(i(t)) − σ_K²)⁺` **does not depend on `τ_MEV` at all** — it is a function of exogenous inputs (`σ²(i(t)) ∈ u_ex`) and the parameter block `Θ_σ`. It is therefore **not a controlled output; it is a reference / measured disturbance.** The actual controlled variable is the scalar
`c := H y, H = [1, −1] ⟹ c = π^σ − π̂^σ`
and the problem is **1-input / 1-output, square, and generically well-posed.** In self-optimizing-control terms this is the CV-selection step (Skogestad 2000; Halvorsen et al. 2003; Jäschke et al. 2017) and it should be written down as such, with `H` stated.

**5.3 What the classical output-controllability test says — and why it is the wrong tool.** Kreindler & Sarachik (1964) requires `rank[CB, CAB, …, CA^{n−1}B, D] = p`. Note carefully: with `m = 1` input this matrix is `p × (n+1)`, so **`rank = 2` is not automatically excluded** — a single input can excite two output directions at different lags. So the naive "1 actuator can't control 2 outputs" is *false as a dynamic statement* and *true only as a static/steady-state statement*. Either way the test is the wrong instrument for a static problem: **cite it to bound the claim, never to establish well-posedness.** The Kalman rank test on `(A,B)` is likewise the wrong tool and will mislead.

**5.4 The condition that actually is the "controllability" obligation.** For the 1×1 problem, well-posedness needs
`∂π̂^σ/∂τ_MEV ≠ 0` on the admissible box.
Under the source's own factorisation, that is exactly **all five factors nonvanishing**. So the controllability obligation *reduces to five nonvanishing-derivative lemmas* — a very clean Lean target, and it explains why PROJECT.md's claim 3 (`∂ν/∂λ_MEV > 0`) is load-bearing: if that sign can vanish or flip anywhere on the box, monotonicity fails and the set-point becomes non-unique or non-existent.

**5.5 `φ_X` is a scheduling variable, not an actuator.** `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` is a function of a measured exogenous signal. This makes the plant **gain-scheduled / quasi-LPV** (Rugh & Shamma 2000). Consequence for the deliverable's *name*: **`τ*_MEV` is not a set-point number. It is a scheduled static map `τ*(σ², ΔQ_M, ΔQ_X; Θ)` — i.e. an exact static feedforward law.** The spec should say this in its first paragraph; it changes what "verified" means and it changes the EVM cost model (evaluated per swap, not written once).

**5.6 The degrees-of-freedom question that *is* real, deferred.** With one input and one CV the count is exactly square. If a second economic objective is later added (e.g. simultaneously maximising `λ_FLAIR`), the problem becomes genuinely underactuated and the answer is a scalarization or lexicographic priority — Rao & Rawlings' constrained target calculation with output ranking. Worth recording that this is *consistent with, and possibly resolves*, the source's own degeneracy finding [M6a]: the joint program over `Θ_φ` is degenerate and "the degeneracy-breaker must come from OUTSIDE `Θ_φ`." **`τ_MEV` is outside `Θ_φ`** (Rule 12 is a monoid entry, not a `Θ_φ` parameter). So `τ_MEV` is a *candidate* degeneracy-breaker alongside `η` and cadence `Δt`. Flag for the roadmap; do not assert it.

---

## 6. Q3 — The event-time formalism: a definite answer

### Is `x_{t+1} = ∂_(t+1,t) x_t + ∂_(x,u) u_t` legitimate?

**Verdict: legitimate as a *local Jacobian linearization, in deviation coordinates, of the embedded jump chain of a piecewise-deterministic event process*. Illegitimate as written — as an LTI recursion in absolute variables.** Three specific repairs:

1. **Write the nonlinear event map first.** On the event index `k ∈ ℕ`:
   `x_{k+1} = f(x_k, u^en_k, u^ex_k; Θ)`, `y_k = h(x_k, u_k; Θ)`.
   Then *define* `∂_(t+1,t) := D_x f|_{(x̄,ū)}`, `∂_(x,u) := D_u f|_{(x̄,ū)}`, etc. This is Ogata Ch. 2 and it is honest.
2. **Deviation coordinates and the affine offset.** As displayed, the recursion is missing the offset `f(x̄,ū) − Ax̄ − Bū`. It is valid for `δx = x − x̄`, `δu = u − ū`, locally. The ∂-symbols are **state- and input-dependent Jacobians**, so the object is **quasi-LPV at best, never LTI.** Any claim requiring constant matrices (transfer functions, eigenvalue arguments, DC gain as a fixed matrix) must be re-derived or dropped.
3. **The event↔wall-clock bridge — this is the OPEN modelling question.** The state carries genuine *time-rate* objects: `π^LVR` is a rate (`·Δt` per block), `σ²(i(t))` is a per-unit-time variance, `λ_FLAIR`/`λ_ARB` are time-integrated hazards, `Δt` is the mean interblock time. If `k` indexes **swaps** and `Δt` indexes **blocks**, these are two different clocks. **The document currently mixes them without a stated bridge.**
   - **Recommended carrier: PDMP (Davis 1984).** Deterministic flow between events + jumps at events; the source's recursion is the **embedded jump chain**; Davis's extended generator is the machinery that converts event-indexed statements into time-indexed ones.
   - **The bridge theorem: PASTA / ASTA.** Event-averages equal time-averages only under lack of anticipation (Wolff 1982; Melamed & Whitt 1990 for the weak version). **In a CFMM this condition plainly fails** — arbitrage swaps arrive *because* the state is mispriced, so the arrival process anticipates the observed state. **Therefore PASTA does not apply and event-averaged ≠ time-averaged in this market.** Any formula mixing `ΔQ_M, ΔQ_X` (per-event) with `π^LVR·Δt, σ², λ` (per-time) needs an explicit Palm-inversion argument, or an explicit assumption stated and flagged.
   - **Status: this is an OPEN modelling question the spec MUST resolve** — either by supplying the Palm/inversion argument, by adopting a stated LAA-violating correction, or by restricting every object in the derivation to a single clock. It cannot be left implicit.

### Near-miss formalisms — name them so they don't get miscited

| Formalism | Why it looks right | Why it is wrong here | Conf. |
|---|---|---|---|
| **Max-plus algebra / timed event graphs** (Baccelli, Cohen, Olsder & Quadrat, *Synchronization and Linearity*, Wiley 1992) | Gives literally `x(k+1) = A ⊗ x(k) ⊕ B ⊗ u(k)` with `k` an **event counter** | That recursion lives in the `(max,+)` semiring and its state entries are event **times**. Here the state is real economic quantities in ordinary `(+,×)` algebra | HIGH (structural argument) |
| **Automata-theoretic discrete-event systems** (Cassandras & Lafortune) | "Discrete event" in the name | The state there is a discrete language/marking; ours is continuous | HIGH |
| **Event-triggered control** (Tabuada 2007, *IEEE TAC* **52**(9)) | Control updates at events, not on a clock | There the **designer chooses** the triggering rule to save communication. Here events are **exogenous** — swaps arrive whether or not we want them | HIGH on the distinction; MEDIUM on the exact Tabuada citation details (not independently re-verified this session) |

---

## 7. Alternatives considered

| Recommended | Alternative | When the alternative is better | Conf. |
|---|---|---|---|
| Static plant inversion (IFT) | **Online Feedback Optimization** — Colombino, Dall'Anese & Bernstein, **arXiv:1805.09877**, *Online Optimization as a Feedback Controller: Stability and Tracking*; Hauswirth, He, Bolognani, Hug & Dörfler, **arXiv:2103.11329**, *Optimization Algorithms as Robust Feedback Controllers* | If the model gains (`∂ν/∂τ`, `∂L/∂π^φ`) turn out to be unknowable on-chain, OFO drives the plant to the optimiser *using the plant itself as part of the solver*, needing far less model. **Cost:** it is a *dynamic* controller (an iteration), which PROJECT.md excludes, and it needs timescale separation, which event time does not provide. Keep in the back pocket if the 5-factor channel is refuted | HIGH (arXiv API verified) |
| Static plant inversion | **Extremum seeking** — Krstić & Wang (2000), *Automatica* **36**(4), 595–601, "Stability of extremum seeking feedback for general nonlinear dynamic systems" | If the gain sign is genuinely unknown, ES finds the optimum model-free. **Not recommended:** requires persistent dither (deliberately perturbing the protocol fee every block) — a governance and MEV hazard — and its proofs rest on averaging/singular-perturbation timescale arguments unavailable in event time | HIGH |
| Root formulation | **Constrained steady-state target QP** — Rao & Rawlings (1999) | Adopt its *constraint-handling discipline* now regardless: `τ ∈ [0,1]` active-set, and a stated fallback when the target is unreachable. Adopt the full QP if a second objective is ever added | HIGH |
| Recompute `τ*` per event | **Null-space method** — Alstad & Skogestad (2007) | **Investigate this explicitly.** If an `H` exists with `HF = 0` (`F = dy_opt/dd`), the controlled variable is disturbance-invariant and `τ` can be *fixed* rather than recomputed per swap. This is the cheapest possible on-chain outcome and the literature supplies an *exact test*, not a heuristic. **Recommend a dedicated roadmap item.** | HIGH |

---

## 8. What NOT to use

| Avoid | Why | Use instead | Conf. |
|---|---|---|---|
| **LQR / discrete algebraic Riccati** (Ogata Ch. 10; Bryson & Ho) | Solves for a *gain* minimising an accumulated cost over a horizon. The deliverable is a *value*. Also: Riccati is not EVM-computable and is a formalisation nightmare in Lean | Algebraic stationarity + IFT | HIGH |
| **LQG / Kalman filter** | Presumes state estimation from noisy partial measurements. All plant states here (`φ, ν, π^φ`) are directly readable on-chain | Direct measurement | HIGH |
| **Internal model principle / integral action / servo compensator** (Francis & Wonham lineage) | Machinery for asymptotic *tracking* of a signal class **by a loop**. Excluded by scope; there is no loop | Nothing — the obligation does not exist | HIGH (structural) |
| **Root locus, Bode, Nyquist, gain/phase margin** (Ogata Ch. 6–7) | Loop-stability margins. There is no loop | Nothing | HIGH |
| **Routh–Hurwitz / Lyapunov stability** | No closed loop to stabilise. The only remaining "stability" question is well-posedness of the *inverse* | IFT + strict monotonicity | HIGH |
| **The phrase "static output feedback"** | **Name-collision trap.** It means `u = −Ky` with constant `K`, and its synthesis is **NP-hard** — Blondel & Tsitsiklis (1997), *SIAM J. Control Optim.* **35**, 2118–2127, "NP-hardness of some linear control design problems". It is *not* what "static set-point" means. A reviewer who sees the phrase will assume the hard problem | Say "static set-point" or "exact static feedforward / plant inversion" | HIGH |
| **Kalman rank test / controllability Gramian on `(A,B)`** as the well-posedness test | Wrong tool for a static problem; gives a misleading verdict (see §5.3) | Nonvanishing scalar sensitivity + IFT | HIGH |
| **Setting `d\|π^σ − π̂^σ\|/dτ = 0`** | `\|·\|` is non-differentiable at the solution; **no FOC exists there.** The source's own EtaCurvature Theorem 25 already records exactly this failure mode for `ς*_{X/M}` | Root of the **signed** residual | HIGH |
| **Max-plus / timed-event-graph DES** | Wrong algebra (see §6) | PDMP jump chain | HIGH |
| **Event-triggered control** (Tabuada) | The trigger is exogenous here, not designed | PDMP jump chain | HIGH |
| **Bamieh–Paganini–Dahleh spatial invariance, DFT decoupling, poset-Riccati, chordal-sparsity LMIs** (all of v2's §A) | These synthesise *gains* over a *shift-invariant spatial* index. The event index has no group structure the plant commutes with — swaps are not translations | See §10 | HIGH (structural) |

---

## 9. Proof-obligation map — how each PROJECT.md claim should be *stated*

This section is the direct input to the Lean/Aristotle bundle.

| PROJECT.md claim | Restate as | Theorem / formalism to invoke | Lean shape (Mathlib) |
|---|---|---|---|
| **Well-posedness of the `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition over event time** | (a) the recursion is the Jacobian linearization of a `C¹` event map **in deviation coordinates**, with the affine offset stated; (b) **no state coordinate is a running sum** (else `1 ∈ spec(A)` and no steady state exists — W1); (c) the event↔time clock is fixed by an explicit bridge | Ogata Ch. 2 linearization; existence of `x_ss ⟺ (I−A)` invertible; Davis (1984) jump chain; Wolff (1982)/Melamed–Whitt (1990) for the clock bridge | `HasFDerivAt f A x̄`; `IsUnit (1 - A)`; explicit hypothesis carrying the clock assumption |
| **The 5-factor channel** | The signal-flow graph from `τ_MEV` to `π̂^σ` has **exactly one forward path**, and no loop touches it, so Mason's formula collapses `Δ = 1` and the total transmittance = the product of the five edge gains | **Mason (1953)**, *Proc. IRE* **41**, 1144–1156 | a `Finset` of forward paths + `Finset.sum_eq_single`, plus `Δ = 1` |
| **The sign `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0`** | **Strict monotonicity on the admissible box**, not a constant. "Constant" is a much stronger and probably false claim; only the sign is needed | — | `StrictMonoOn ν box` or `∀ x ∈ box, 0 < deriv ν x` |
| **The boxed closed form for `τ*_MEV`** | (i) `τ*` is the **root of the signed residual** `r(τ) = π^σ − π̂^σ` (NOT the argmin of `\|r\|` — W4); (ii) existence by IVT with a sign change on `[0,1]`; (iii) uniqueness by strict monotonicity; (iv) `C¹` dependence on `(u_ex, Θ)` by IFT; (v) admissibility `τ* ∈ [0,1]`, else the projection (W5); (vi) the display is **algebraically closed** — verify by substitution (W7); (vii) dimensional consistency (W6) | IFT (Dini); IVT; Fiacco (1976) only if the minimisation reading is kept | `intermediate_value_Icc`; `StrictMonoOn.injOn`; Mathlib implicit function theorem; a `Set.projIcc` for the clamp |

### Two findings the spec should settle FIRST

**FINDING A — the 5-factor channel is very likely REFUTABLE as stated. (MEDIUM–HIGH confidence.)**
Rule 12 ([M9], `VOLATILITY_INSTRUMENTS.md` line 1049) gives `τ_MEV` a **direct** edge into the trader-paid fee: `φ_total ← φ_M ⊗_φ φ_X ⊗_φ τ_MEV`, so `∂φ_total/∂τ_MEV = (1−φ_M)(1−φ_X) ≠ 0`. The source's *own* `∇φ` display (`notes/VOLATILITY_INTRUMENTS_MEV.md` line 56) lists `(1−φ_X)(1−φ_M)` as the `τ`-slot entry. Therefore the signal-flow graph carries **at least two forward paths**:
- `τ → φ → π^φ → L → π̂^σ` (direct, via Rule 12), and
- `τ → ν → φ → π^φ → L → π̂^σ` (the claimed 5-factor path).

By Mason's gain formula the **total** derivative is the **sum** over forward paths, so the boxed product can be at most the `ν`-mediated **partial**. Note also that the source's target is written `∂π̂^σ/∂τ_MEV |_{λ_MEV}` — a *partial* holding `λ_MEV` fixed — while the boxed identity is asserted for the unrestricted `∂π̂^σ/∂τ_MEV`. **That is a partial-vs-total-derivative mismatch.** If confirmed, the boxed closed form is missing a term. This should be the first thing the spec settles, because everything downstream depends on it — and per PROJECT.md, *a refutation is a successful outcome*.

**FINDING B — the closed form may be only implicitly closed. (MEDIUM confidence, checkable by substitution.)** See W7 above. Material for EVM: an implicit fixed point is not on-chain-affordable.

---

## 10. Differentiation from the v2-controller spatial-axis frame

`.planning/research/v2-controller/` chose **Bamieh–Paganini–Dahleh spatially-invariant control diagonalized by the lattice DFT, realized financially as Carr–Madan / Breeden–Litzenberger static spanning over the tick grid**, with the on-chain object a **fixed banded Toeplitz/circulant matvec**.

**What carries over (reuse, do not re-derive):**
- The **off-chain synthesis → on-chain fixed evaluation** split — architecturally identical.
- The **EVM primitive obligations** from `ON-CHAIN-REALIZATION.md` (SPEC-02) wholesale: `signedMulDiv` (the #1 correctness hazard), fixed-point `sqrt`, `clamp`/`satAdd`, `int24` bounds, round-toward-zero, one consistent WAD scale, and the hard rule **saturate, never revert** (a reverting `beforeSwap` DoSes the swap).
- The toolchain: **Lean = proof authority, SymPy/GAMS = reference oracle, `gamsDiff`/`forge --via-ir` = differential gate.**
- **Carr–Madan / Breeden–Litzenberger as the strike-axis spanning basis.** `π̂^σ = Σ_{i_K} L(i_K) π^l(σ(i_K;Θ_σ))` **is** a strike-grid spanning sum. v2's `w = M f` map therefore supplies exactly the `∂L(i_K)/∂π^φ` entries this project's formula needs. **The two projects compose: v2 gives the strike-axis operator; this project gives the scalar per-event input that moves it.**

**What does NOT carry over (do not import):**
- **Spatial invariance / DFT decoupling / Toeplitz-circulant structure.** The event index has **no group structure the plant commutes with** — a swap is not a translation. There is no wavenumber to decouple over.
- **Poset-Riccati (arXiv:1111.1498), D'Andrea–Dullerud LMIs, chordal-sparsity synthesis.** All synthesise *gains*; irrelevant to a set-point.
- **CRR backward induction.** A terminal-value recursion over a recombining spatial lattice; the event axis has no terminal condition.
- **The "banded matvec" as the on-chain object.** Here the on-chain object is a **scalar closed form** — strictly cheaper, but with a new hazard v2 did not have: the `Σ_{i_K}` is a loop over the strike set, so **gas is unbounded unless the strike set is bounded**. Flag as an EVM obligation.
- **v2's `LIT-LATTICE-CONTROL.md` §A (spatially-distributed control) in its entirety.** Cite it as prior art for the sibling axis; do not reuse its recommendation.

**The clean statement of the split, for the spec's opening:** variance-swap replication is *semi-static* (Demeterfi–Derman–Kamal–Zou 1999, vendored) — a **static strike portfolio** plus a **continuously rebalanced underlying leg**. **v2-controller formalised the static strike leg. This project formalises the rebalancing leg, clocked on events.** Fukasawa's discretisation results are the argument that an event clock is a legitimate — and possibly efficient — rebalancing clock rather than a defect.

---

## 11. EVM-feasibility implications of the frame

| Implication | Detail | Status |
|---|---|---|
| **Per-event evaluation, not a one-time write** | Because `φ_X` is scheduled on `σ²` and `τ*` depends on `ΔQ_M, ΔQ_X` (both in `u_ex`), `τ*` is a **map evaluated every swap**, not a stored constant | Confirmed by the frame (§5.5) |
| **Cost envelope** | One division by `ΔQ_v*`, a `Σ_{i_K}` of products, two divisions by `(1−φ)`, two multiplies. **No `pow`/`log`/`sqrt` if `∂φ/∂ν` and `∂ν/∂τ` are constants** — cheaper than v2's banded matvec | Contingent on FINDING B |
| **Unbounded loop hazard** | `Σ_{i_K}` iterates the strike set. **Gas is unbounded unless `#i_K` is bounded** and the bound is stated | NEW obligation, not present in v2 |
| **Saturation** | The `1 − (bracket)` structure sends `τ*` negative for a large bracket. Must clamp to `[0,1]`; must state the infeasible-target fallback (Rao & Rawlings) | Reuse v2 SPEC-02 clamp primitives |
| **Fixed-point iteration would be fatal** | If FINDING B holds and the form is implicit, an on-chain fixed point is not affordable. A refutation of the closed form is therefore **also** an EVM finding | Contingent |
| **Highest-leverage cost question** | Does a **null-space `H`** exist making the CV disturbance-invariant (Alstad & Skogestad 2007)? If yes, `τ` becomes a stored constant and per-swap cost collapses to zero | Recommend a dedicated roadmap phase |

---

## 12. Confidence assessment

| Recommendation | Confidence | Basis |
|---|---|---|
| Frame = static plant inversion / exact feedforward, in CV-selection language | **HIGH** | Structural fit to the stated deliverable + verified SOC literature (Skogestad 2000; Jäschke et al. 2017) |
| Well-posedness = IFT + IVT + strict monotonicity, not Gramian/Riccati | **HIGH** | Standard analysis; directly matches the object solved for |
| Exclusion of LQR/LQG/servo/loop-shaping | **HIGH** | Follows from "no loop, solve for a value"; Ogata TOC verified |
| Mason's gain formula as the frame for the 5-factor claim | **HIGH** | Mason (1953) verified; the claim is literally a forward-path statement |
| **FINDING A** (5-factor channel likely refutable; ≥2 forward paths) | **MEDIUM–HIGH** | Two independent textual anchors (Rule 12 [M9]; the source's own `∇φ` display). Not yet checked against the full `∂φ/∂ν` definition |
| **FINDING B** (closed form may be implicit) | **MEDIUM** | Reading of source lines 108–112 vs the boxed display; settled by substitution |
| **W4** (argmin of `\|·\|` has no FOC; use the signed root) | **HIGH** | Elementary; and the source's own Theorem 25 records the identical failure mode |
| **W1** (accumulator states ⟹ no steady state) | **HIGH** as a general principle; **MEDIUM** as applied — depends on whether `λ_MEV` enters the state through `ν` | `λ_ARB`, `λ_FLAIR`, `λ̃_JIT` are all explicitly running sums in the source |
| PDMP (Davis 1984) as the event-time carrier | **HIGH** | Verified; exact structural match (flow + jumps) |
| PASTA fails in a CFMM ⟹ event-avg ≠ time-avg | **HIGH** that the question must be answered; **MEDIUM** that it is fatal | Wolff (1982) verified; the LAA-violation argument is mine, from the arb-arrival mechanism |
| Underactuation does not invalidate set-point optimization | **HIGH** | `π^σ` is `τ`-independent by inspection of its own definition |
| No literature bridging Carr–Madan spanning to control set-point selection | **MEDIUM** (absence of evidence) | Searched; found the CFMM-duality half (Angeris et al.) and the control-inversion half separately, never joined |
| Skogestad & Postlethwaite Ch. 10 = "Control Structure Design", holds the SOC material | **MEDIUM** (title/topic); **UNVERIFIED** (section numbers) | Publisher/secondary summaries only; TOC unreachable |
| Fukasawa: adaptive partitions attain sharp discretisation lower bounds | **HIGH** | Abstracts verified (AAP 2011; arXiv:1204.0637) |
| Fukasawa: hitting-time partitions beat equidistant by `(d+2)/d` | **UNVERIFIED** | Secondary search summary only. **Must read the PDF before this enters the spec** |
| Silverman (1969) volume number | **MEDIUM** | Sources disagree (AC-14 vs AC-19). Verify before citing |

---

## 13. Open questions the roadmap must carry

1. **The clock.** Does `t` index swaps or blocks? Every object in the derivation must be re-tagged with its clock, and the event↔time bridge stated (PDMP + an explicit Palm/ASTA assumption, or a single-clock restriction). **This is the one genuinely open modelling question and it gates everything else.**
2. **FINDING A.** Enumerate the forward paths from `τ_MEV` to `π̂^σ` in the signal-flow graph and apply Mason. Settle whether the boxed identity is total or partial.
3. **FINDING B.** Substitute back: is `(∂φ/∂ν)(∂ν/∂τ)` `τ`-free? If not, the form is implicit.
4. **Root or argmin?** Fix the definition of `τ*` (recommend: root of the signed residual) and delete the FOC-on-`|·|` route.
5. **Accumulator audit (W1).** Confirm no state coordinate is a running sum, or re-coordinate to increments.
6. **Null-space feasibility.** Does an `H` exist with `HF = 0`? Highest-leverage EVM-cost question.
7. **Strike-set bound.** Bound `#i_K` for the `Σ_{i_K}` loop.
8. **Infeasible-target policy.** What the protocol does when the unconstrained `τ*` leaves `[0,1]`.
9. **Unverified citations to close before the spec is committed:** Skogestad & Postlethwaite chapter/section numbering; Silverman (1969) volume; the Fukasawa hitting-time factor; the Bertsimas–Kogan–Lo error rate; the Tabuada (2007) details.

---

## 14. Sources

**Verified via arXiv API (`export.arxiv.org/api/query`) — ids, titles, authors, dates all confirmed:**
- arXiv:2103.14769 — Angeris, Evans, Chitra, *Replicating Market Makers* (26 Mar 2021) — HIGH
- arXiv:2111.13740 — Angeris, Evans, Chitra, *Replicating Monotonic Payoffs Without Oracles* (26 Nov 2021) — HIGH
- arXiv:1805.09877 — Colombino, Dall'Anese, Bernstein, *Online Optimization as a Feedback Controller: Stability and Tracking* (24 May 2018) — HIGH
- arXiv:2103.11329 — Hauswirth, He, Bolognani, Hug, Dörfler, *Optimization Algorithms as Robust Feedback Controllers* (21 Mar 2021) — HIGH
- arXiv:1905.06291 — Hauswirth, Bolognani, Hug, Dörfler, *Timescale Separation in Autonomous Optimization* (15 May 2019) — HIGH
- arXiv:1204.0637 / arXiv:1004.2107 — Fukasawa, *Efficient Discretization of Stochastic Integrals* / *Discretization Error of Stochastic Integrals* — HIGH (abstracts read)

**Control theory (verified via publisher / society pages and search corroboration):**
- Ogata, *Modern Control Engineering*, 5th ed., Pearson — TOC verified from the publisher page — HIGH
- Skogestad & Postlethwaite, *Multivariable Feedback Control: Analysis and Design*, 2nd ed., Wiley 2005 — existence/edition HIGH; **chapter internals UNVERIFIED**
- Skogestad (2000), *J. Process Control* **10**, 487–507 — HIGH
- Jäschke, Cao & Kariwala (2017), *Annual Reviews in Control* **43**, 199–223 — HIGH
- Halvorsen, Skogestad, Morud & Alstad (2003), *Ind. Eng. Chem. Res.* **42**(14), 3273–3284 — HIGH
- Alstad & Skogestad (2007), *Ind. Eng. Chem. Res.* **46**(3), 846–853; Alstad, Skogestad & Hori (2009), *J. Process Control* **19**, 128–148 — HIGH
- Rao & Rawlings (1999), *AIChE J.* **45**(6), "Steady states and constraints in model predictive control" — HIGH
- Kreindler & Sarachik (1964), *IEEE Trans. Automat. Control* **9**(2), 129–136 — HIGH
- Brockett & Mesarović (1965), *J. Math. Anal. Appl.* **11**, 548–563 — HIGH
- Silverman (1969), *IEEE Trans. Automat. Control*, "Inversion of multivariable linear systems", 270–276 — MEDIUM (volume number disputed across sources)
- Mason (1953), *Proc. IRE* **41**, 1144–1156; Mason (1956), *Proc. IRE* **44**, 920–926 — HIGH
- Blondel & Tsitsiklis (1997), *SIAM J. Control Optim.* **35**, 2118–2127 — HIGH
- Krstić & Wang (2000), *Automatica* **36**(4), 595–601 — HIGH
- Rugh & Shamma (2000), *Automatica* **36**(10), 1401–1425 — HIGH
- Fiacco (1976), *Mathematical Programming* **10**, 287–331 — HIGH

**Stochastic / event-time:**
- Davis (1984), *J. R. Statist. Soc. B* **46**(3), 353–388 — HIGH
- Wolff (1982), *Operations Research* **30**(2), 223–231 — HIGH
- Melamed & Whitt (1990), ASTA under WLAA — MEDIUM (corroborated in secondary literature; primary citation not opened this session)
- Baccelli, Cohen, Olsder & Quadrat (1992), *Synchronization and Linearity*, Wiley — cited as a **near-miss to exclude**; not independently re-verified this session — MEDIUM

**Finance / replication:**
- Demeterfi, Derman, Kamal & Zou (Mar 1999), Goldman Sachs QSRN — **locally vendored and read**: `cfmm-wt/plank/refs/DemeterfietalVarianceSwaps.pdf` — HIGH
- Bertsimas, Kogan & Lo (2000), *J. Financial Economics* **55**(2), 173–204 — HIGH on venue/title; error-rate detail UNVERIFIED

**In-tree read-only prior art (differentiated, not duplicated):**
- `evm-controller/.planning/research/v2-controller/LIT-LATTICE-CONTROL.md`
- `evm-controller/.planning/research/v2-controller/STATIC-CONTROL-KERNEL-SPEC.md`
- `plank/notes/VOLATILITY_INSTRUMENTS.md` — `CONTROL_OPERATORS` (§760), `MEV` (§893), `BEHAVIOR_WELFARE_UTILIZATION` (§1076), `JIT` (§1279)
- `evm-controller/notes/VOLATILITY_INTRUMENTS_MEV.md` — the derivation under proof

---
*Frame research for: optimal MEV-tax set-point on an event-time MIMO CFMM plant.*
*Researched: 2026-08-08. Not committed — orchestrator commits.*
