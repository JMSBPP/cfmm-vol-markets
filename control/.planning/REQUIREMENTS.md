# Requirements: MEV-Tax Set-Point Controller — Verified Design Spec

**Defined:** 2026-08-08
**Core Value:** The artifact under construction is the artifact under proof — the project must return a *verdict* on the boxed `τ*_MEV`, and (per the 2026-08-08 scoping decision) a **corrected law** where it refutes.

> **Scope (user ruling 2026-08-08): the deliverable is the FORMAL DOCUMENT of the
> controller, grounded on theory and formal results.** Nothing else.
>
> - **verdict + salvage** — where an obligation refutes, the corrected law is derived and verified
> - the τ↔λ bridge is a full obligation **P5**
> - the behavioral gains (`∂L̄/∂π^φ`, `∂ν/∂λ_MEV`) are stated as **typed hypotheses** in the formal layer and are **never proved** — they are LP-supply estimands
> - **EVM feasibility is OUT** — the entire E0/E1 track moved to v2. This project is theory + formal results + the document.
>
> **AMENDED 2026-08-08 — the Estimation category is now v1.** `Ḡ = ∂ν/∂λ_MEV` is the
> only empirical object in the corrected law; estimating it *is* the test of H2, which
> both Lean bundles carry undischarged. Design: `control/spec/ECONOMETRICS-DESIGN.md`.
> The formal layer still never proves the gains — `EST-03`'s sign test discharges or
> refutes them from data instead.
>
> **AMENDED 2026-08-09 — two categories added. The "free option" premise was REFUTED at
> the review gate on the day it was written; `Ḡ` remains a single point of failure.**
>
> The proposal was: because `ν` and `λ_MEV` are both protocol state, a loop could drive the
> FOC residual `∂π̂^σ/∂τ_MEV → 0` **without forming `Ḡ`**, demoting `EST-04` from dependency
> to refinement. **Both reviewers independently refuted it by composing this project's own
> carriers**, and the composition was verified before acceptance:
>
> ```
> Theorem 30 (SRC:122) + Theorem 29 (SRC:113) + the chain dnu/dtau = Gbar*(dlambda/dtau)
>   ==>  dpihat/dtau = (dpihat/dphi) * [ (1-phi_M)(1-phi_X) + (dphi/dnu)*Gbar*(dlambda_MEV/dtau_MEV) ]
> ```
>
> `Ḡ` is a **multiplicative factor of one of only two bracket terms**, so the residual is
> affine in `Ḡ` with nonzero coefficient. Evaluating the residual *from state* **is**
> evaluating `Ḡ`. "Never stores `Ḡ`" is literally satisfiable and substantively empty.
>
> **Consequences, recorded rather than absorbed:**
>
> - **`EST-04`'s demotion is WITHDRAWN.** The Estimation category returns to fully
>   load-bearing on every branch. Nothing downstream may cite the demotion.
> - **The sign/magnitude split as first written was FALSE.** Loop direction is
>   `sign(∂²π̂^σ/∂τ²)`, not `sign(Ḡ)`; the plant is discrete-time (`Convention 7`,
>   `Definition 34`), so a stability certificate needs a **bound on `|Ḡ|`**, not a sign.
>   And the residual's prefactor `∂π̂^σ/∂φ` carries **`H1`** (`∂L̄/∂π^φ`) via
>   `Proposition 12` — a second undischarged behavioral hypothesis the original category
>   never mentioned. `H1` cancels at the *root* but not in the *signal*.
> - **Phase 6a SURVIVES, RE-SCOPED.** What the on-chain route actually is: a **fixed-point
>   iteration of the `Ḡ`-dependent closed-form law**, not a controller that avoids `Ḡ`.
>   That is worth specifying — it removes a stored constant and tracks drift — but it is
>   not a hedge against the estimation failing, and the roadmap no longer says it is.
> - **Two categories still stand on their own merits:**
>   **Non-Estimated Control (`NEC-00`…`NEC-09`)** — v1, **promotes v2 `CTL-01`**, re-scoped
>   per the above and now front-loaded with the precondition checks the first draft lacked.
>   **Literature & Venue Research (`LIT-01`…`LIT-04`)** — v1, unaffected by the refutation.
>   The estimation had no research requirement at all: 14 PDFs unread for their empirical
>   design, no external sweep specified, and the venue assumed rather than chosen.
>
> **Status of the refutation itself.** It rests on two independent reviewer derivations plus
> my own, **not on a machine-checked carrier**. That is exactly why `NEC-00` exists and why it
> **blocks the category**: a reviewer consensus is not a verified identity. Until `NEC-00`
> returns, every document must write this as *refuted by independent derivation, pending
> `NEC-00`'s carrier* — never as a closed result.
>
> **This is the review gate working as designed.** The refutation is the deliverable, on the
> same footing as the P2 refutation that reshaped Phases 4–5.

---

## v1 Requirements

### Frame

- [ ] **FRM-01**: The control-theoretic frame is selected and justified in writing, with the excluded alternatives named and the reason for each exclusion stated (LQR/LQG/servo, root locus, Bode/Nyquist, PID, Gramian rank tests, and the "static output feedback" name-collision).
- [ ] **FRM-02**: Well-posedness conditions for a set-point (as opposed to a regulator) are enumerated as a checklist that each downstream obligation is tested against.
- [ ] **FRM-03**: The event-clock question is resolved or explicitly declared OPEN with its consequences stated — specifically whether `t` indexes swaps or blocks, and whether event-averaged quantities (`ΔQ_M`, `ΔQ_X`) may be combined with time-averaged ones (`π^LVR·Δt`, `σ²`, `λ`) given that PASTA/ASTA is argued not to hold in a CFMM.
- [ ] **FRM-04**: Every literature citation entering the document is verified against a primary source, or carries an explicit UNVERIFIED tag. **Scope corrected:** the true not-primary-verified set is ≈13, not 5 — the recommendation's own four pillars (Skogestad 2000, Mason 1953, Davis 1984, Wolff 1982) sit in the same web-search tier as the flagged failures, and Carr–Madan / Breeden–Litzenberger is invoked five times with no citation anywhere. Every `FRAME.md` HIGH tag is treated as unverified pending re-check. Use the arxiv MCP (available to this session, unlike the frame researcher's).
- [ ] **FRM-05**: The **null-space test** (`HF = 0`, Alstad & Skogestad 2007) is run over an explicitly partitioned disturbance vector, separating trade-specific components (`ΔQ_M`, `ΔQ_X`) from slow-moving ones (`σ²`, `Θ_φ`), and the partition used is stated. This is a **control-theoretic** result about whether a disturbance-invariant controlled variable exists — reported as theory, with no on-chain cost claim attached.

### Notation & Transcription

- [ ] **NOT-01**: All 13 blocking decisions collected in `research/SUMMARY.md` are put to the user and resolved, each with the ruling recorded.
- [ ] **NOT-02**: A notation map paragraph exists, resolving every collision — including `π^{\varphi}` (source: `π^{\phi} − π^{LVR}`; entry-point doc: the portfolio value function), the `L` overload (order ladder vs aggregate pool), `ν` vs `u`, and leg pairing in `π^{\phi}`.
- [ ] **NOT-03**: A crosswalk maps the four research documents' non-aligned claim taxonomies (`P1–P4`/`C-P#-#`/`A#`, `B#`/`M#`/`N#`/`R#`, `FINDING A/B`/`W#`) onto one identifier scheme.
- [ ] **NOT-04**: The `∂`-partition is constructed **entrywise** from the source, and each entry is checked for whether it is a constant, a Jacobian entry, or structurally zero — before any claim relying on the plant being non-degenerate is made.
- [ ] **NOT-05**: The unit/dimension ledger **EXTENDS** the existing normative table at `plank/notes/UNITS_AND_SCALES.md` (sha-pinned, peer-owned, already two-step reviewed) with the symbols it lacks — `ν`, `τ_MEV`, `π^l`, `π^φ`, `π^LVR`, `ΔQ_υ`. It does **not** re-derive a parallel ledger. The extension is routed to `ul2inqpl` as a proposed diff, never edited in the peer's tree.
- [ ] **NOT-06**: No symbol is minted that is not either in the source or recorded in the notation map with a stated reason.
- [ ] **NOT-07**: The **two-axis liquidity distinction is recorded as settled** (user ruling 2026-08-08): `L(i_K) = L̄·ℓ(ξ,ι;i_K)` with `ℓ` geometry-invariant; `ΔQ_v★` is **vol-asset** L units (`UNITS_AND_SCALES.md:70`) while the pool's `L̄` is price-axis liquidity — two assets, not one ambiguous symbol. Every downstream use of `L` names its axis.
- [ ] **NOT-08**: An **inventory sweep** of `evm-controller/spec/`, `evm-controller/notes/` and `plank/notes/` identifies every normative artifact **before** any notation map or ledger is written — closing the discovery failure that missed `UNITS_AND_SCALES.md`, `VOLATILITY_INSTRUMENTS_MEV.tex` (1063 lines, 29 numbered Definitions / 21 Theorems / 9 Propositions, defines `ι` = our `#_σ` at :212), and `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/ENTRY_POINT.md` (carries a correct boxed `∂φ/∂ν`; currently **untracked** and at risk of destruction — track it).
- [ ] **NOT-09**: The `ΔQ_v★` / `ΔQ_υ` glyph collision is resolved (`DOC:672` — i.e. `plank/notes/VOLATILITY_INSTRUMENTS.md` — indicates they occupy the same `I_ord` slot), and `∂φ/∂ν` from `ENTRY_POINT.md` is carried into the channel's factor list as a **determinate, strictly positive** factor.

- [ ] **NOT-10**: **The `SRC` block programme.** Every result landed from a bundle is transcribed into `SRC` as a **numbered block** continuing the shared doc sequence, in the entry-point doc's own register — **heading, math, stop**; minimal prose, maximal math; rationale goes to the user in conversation, never into the file.
      **HEAVY USER APPROVAL, one block at a time.** Each block is presented to the user *in full* before it is written; the user approves or revises; only then is it committed. **No batch writes, and no block written without an explicit approval for that block.** This is the cadence already used for `Convention 7`, `Definitions 32–35` and `Rule 13`.
      Each block states its **conditionality**: unconditional results are written plainly; results resting on a hypothesis (`H1`, `H2`, `hclearing`, single-crossing) name that hypothesis inside the block. **Blocks whose sign depends on `EST-03`'s verdict are NOT written until Phase 6 returns** — currently `tau_to_nu_strictAntiOn_under_H2`, `Theorem34`'s opposed signs, the corrected law's `1 −` sign reading, and the `∂ν/∂τ` `SIGN CORRECTED` audit row.
      No symbol may be minted by a block; the notation map (`NOT-02`, `NOT-06`) governs, which is why this requirement sits behind the map rather than beside it.

### Proof Obligations

- [ ] **PRF-01**: **P1 — well-posedness.** A verdict on whether the `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is well-posed over event time, and whether set-point optimization is legitimate given `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j)` frozen.
- [ ] **PRF-02**: **P2 — the 5-factor channel.** A verdict on whether `τ_MEV` reaches `π̂^σ` through no path other than the stated chain, with the counterexample exhibited if it does not.
- [ ] **PRF-03**: **P3 — the behavioral gains, as HYPOTHESES.** `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0` and `∂L̄/∂π^φ > 0` are **LP-supply responses, not propositions** (user ruling 2026-08-08). Each is formalized as an explicitly named typed hypothesis, with its estimand, its sign convention, and its observation channel (add/remove-liquidity events) documented. **Neither is sent to Aristotle as a claim to prove.** Estimating their magnitudes is the **Estimation** category (`EST-01`…`EST-05`), promoted to v1 on 2026-08-08; `EST-03`'s sign test is what finally discharges or refutes them.
- [ ] **PRF-04**: **P4 — the boxed closed form.** A verdict on the boxed `τ*_MEV`, resolving first *which relation it actually solves* (the research finds it equivalent to `∂π̂^σ/∂τ_MEV = ΔQ_v*`, not to `π^σ ≡^R π̂^σ`).
- [ ] **PRF-05**: **P5 — the τ↔λ bridge.** A verdict on whether `∂ν/∂λ_MEV` may be substituted for `∂ν/∂τ_MEV`, stated as a first-class obligation rather than an implicit step.
- [ ] **PRF-06**: Every obligation is stated in the Lean tree's native idiom (`Monotone`/`StrictAnti`/`ConvexOn`) wherever a sign or ordering claim suffices. **Rationale corrected:** the tree is NOT devoid of differential-calculus infrastructure — `CapponiEmbed.lean` carries 132 `HasDerivAt` / 128 `deriv` / 19 `Differentiable` — **all three are `grep -c` LINE counts, not occurrence counts** (`grep -o '\bderiv\b' | wc -l` gives 306; both are correct, the unit is what differs — state the method with any count), including `HasDerivAt.div`, `Real.hasDerivAt_rpow_const` and a fourth-derivative computation. The real gap is narrower: no derivative lemmas for the five named schedule functions (`logistic`, `sigmoidR`, `multiFee`, `probOr`, `ptrade`). Any derivative layer is priced against `CapponiEmbed` as in-tree precedent, not from scratch.
- [ ] **PRF-07**: Each obligation is frozen and sha-pinned at submission time, and its statement is byte-diffed against what returns — so a silently strengthened hypothesis cannot land unnoticed.
- [ ] **PRF-08**: Every returned proof passes an integration gate before being treated as landed: statement byte-diff, axiom check, zero `sorry`s, proof-body triage, dependency byte-identity, and provenance.
- [ ] **PRF-09**: Cheap detectors run **before** any Aristotle submission. The numerical harness is **conditional by construction**: it records the sign/range of `τ*` *as a function of the named hypothesis set* (`PRF-03`'s gains have no closed form — they are estimands), with the hypotheses enumerated alongside the output. A hypothesis-dependent range violation may **not** be logged as a refutation. Plus a back-substitution check on each closed form.
- [ ] **PRF-10**: Each obligation ships as a self-contained PROOF-REQUEST hand-off artifact, since no step of the proving pipeline executes in this worktree.

### Salvage

- [ ] **SAL-01**: For each refuted obligation, the *specific defect* is recorded — not merely that it failed, but which step, which line, and which error class.
- [ ] **SAL-02**: A corrected set-point law is derived under the selected frame, addressing the defects the verdicts expose.
- [ ] **SAL-03**: The corrected law is stated over an explicit domain, including the branch structure the kinks force (`(·)⁺` at the strike, the OTM branch where no interior solution exists, and the `min(·)` funded cap).
- [ ] **SAL-04**: The corrected law is itself submitted for verification, and carries its own verdict.
- [ ] **SAL-05**: Every assumption the corrected law rests on is declared as an assumption, never justified by citing a theorem that does not exist.

### Non-Estimated Control

Added 2026-08-09. **Promotes v2 `CTL-01`.** **RE-SCOPED the same day**, after both reviewers
refuted the founding premise (see the front-matter amendment): the FOC residual is affine in
`Ḡ`, so an on-chain loop does not avoid `Ḡ` — it evaluates it every block. What survives is
worth specifying anyway: an **on-chain fixed-point iteration of the `Ḡ`-dependent law**,
which removes a stored constant and tracks drift. It is **not** a hedge against the estimation
failing, and no requirement below may be read as one. Runs before Estimation because its
precondition checks can terminate cheaply.

- [ ] **NEC-00**: **The refutation is verified, not assumed.** The composition `∂π̂^σ/∂τ = (∂π̂^σ/∂φ)·[(1−φ_M)(1−φ_X) + (∂φ/∂ν)·Ḡ·(∂λ_MEV/∂τ_MEV)]` — from `Theorem 30`, `Theorem 29` and the chain `∂ν/∂τ = Ḡ·(∂λ/∂τ)` — is an **algebraic identity**, hence a legitimate claim for the proving pipeline (the standing ban is on sending *behavioral gains*, not identities). It is submitted and carries a verdict. **If it holds, the "controller without `Ḡ`" reading is closed permanently and every downstream document says so.** This requirement blocks the category: nothing below is specified against the refuted reading.
- [ ] **NEC-01**: **The uniform-clearing precondition is CHECKED against the actual venue and deployment, not merely stated.** `λ_MEV = λ_ARB` holds only where `λ_sandwich = 0`, which `DOC:1041` scopes explicitly to **the Angstrom regime** — batch auction with uniform clearing. But Decision #13's venue (Algebra Integral) is a continuous-execution concentrated-liquidity AMM where sandwiching is live, and the deployment target is a Uniswap v4 hook under one-hook-per-pool exclusivity, so composition with Angstrom is unavailable. The sandwich-zero result is itself **UNFORMALIZED with no Lean carrier** (`DOC:1026`). Either the precondition is satisfied on a named venue, or `λ_MEV ≠ λ_ARB` there and the category terminates before `NEC-02`. **Blocking.**
- [ ] **NEC-02**: **`λ_ARB`'s constructibility as an observer, stated completely.** Every argument of `DOC` Definition 22 is traced to a read path — including the `π^LVR(s)/π^linear(s)` factor, whose `π^{\varphi}` carrier is **UNFORMALIZED** (`DOC:821`) and whose exact tier carries the `σ²Δt < 8` guard with **no carrier** (`DOC:959`, T19 omitted). Two further defects the first draft's narrative concealed: `Δt` is the **mean** interblock time (`DOC:901`), not a per-swap read, so the observer carries an **undeclared window-length parameter**; and the accumulator index `s` is a *swap* (`Convention 7`) while `Δt` is *interblock* — **two clocks in one summand**, which the event-clock ruling (`FRM-03`) must adjudicate. Declared an **OBSERVER, never a measurement** (`ℙ_{Δ_ARB}` is leading-order and quasi-static, caveats `[M8]`). A dimensional-consistency check on `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` is a **pass/fail acceptance criterion**: `φ` is dimensionless and `√(2/Δt)` carries time^(−1/2), so `σ` must be a volatility **rate**, which open item **O4** must pin before the accumulator sums anything.
- [ ] **NEC-03**: **`ν`'s constructibility from state the protocol owns.** Each factor of `ν = \varphi_{(1/2,0)}(i_K; ΔQ, 0; t) / \varphi_{(1/2,0)}(i_K; 0, L; t)` mapped to its slot. **Glyph note:** the trading function is `\varphi`, distinct from the fee glyph `φ` (`DOC:920`, standing φ/varphi split) — an earlier draft of this requirement wrote `φ_{(1/2,0)}` and was wrong. Distinct from `EST-01`, which asks whether an *external* venue's events permit reconstruction. Open item **O3** is load-bearing in **two** senses, and the implementation sense must not displace the other: (i) if `φ_X` carries `ν`, the read sits inside a loop and the `beforeSwap` ordering must be stated; (ii) **`φ_X` is a function of the outcome**, which is a bad-control hazard for any estimating equation — see `EST-06`.
- [ ] **NEC-04**: **The `ν ↔ λ` coupling, with its falsification standard fixed BEFORE the verdict is sought.** The tempting reading — that `ν`'s numerator and `π^LVR` are the same trading-function evaluation — must survive three objections, each recorded: (a) `DOC:995` is **not a result**; it is an *assumed hypothesis* of Theorem 19, labelled STRONG, and Theorem 19 is **REFUTED for σ-varying schedules** (`mev_ge_flat_under_flair_budget_false`) while our schedule is σ-varying by construction (`Rule 13`); (b) the alignment is **CROSS-COORDINATE**, i.e. liquidity-units ∝ money-units with an **unstated dimensional constant**, so it cannot yield a magnitude even in the best case; (c) the two evaluations differ — `(i_K; ΔQ, 0; t)` at the strike versus `(i(t); ΔQ(t), 0)` at spot, and a level at `t` sharing a functional form with a summand at `s < t` yields no derivative identity absent a law of motion. **The "fully derivable / estimand dissolves" branch is therefore a priori implausible and must state in advance what would count as derivability.** `ECONOMETRICS-DESIGN.md:31` classified `∂ν/∂λ_MEV` as "Behavioural. Not derivable." — reopening an approved ruling is recorded as such. Where the verdict is "partially derivable", a **recomposition rule** (`sign(residual) ⇏ sign(total)`) is written **before** `EST-03` runs; where "fully derivable" with a **negative** sign, `H2` is refuted algebraically and the gate table's fully-derivable branches — both signs — govern.
- [ ] **NEC-05**: **Computed or dithered — the disjunction is stated explicitly, because both readings have consequences the first draft equivocated over.** If the residual is **computed** from state, `NEC-00` applies and `Ḡ`'s magnitude is required. If it is **dithered** (extremum-seeking / gradient), then: it is an **online estimation of the same behavioral gain**, with no instrument, no first-stage F, no power floor, no pre-registration and no standard errors — **the anti-fishing discipline of `EST-03` applies to it in full**, and it is recorded as strictly weaker than the offline route, not stronger; it requires a **persistency-of-excitation** condition; it violates **timescale separation** unless analysed, since the iteration index is the swap event while `∂ν/∂τ` is LP repositioning settling over hours to days; and it is an **experiment on live users' fees**, which is acknowledged in writing rather than left implicit.
- [ ] **NEC-06**: **What the loop actually is, stated without euphemism.** Three structural facts, each of which the first draft's framing hid: (a) **the observer is self-confirming** — `λ_ARB` is a function of `φ`, and `φ` contains `τ_MEV` through the Rule 12 monoid, so the controller's own action moves its own "measurement" exactly as the model prescribes; the loop cannot detect model error and converges to **the model's root**, i.e. to the `Ḡ`-dependent closed form solved by on-chain fixed-point iteration (open item **O7**); (b) **`λ_ARB` is a monotone divergent accumulator** — every summand is nonnegative (`mevMulti_nonneg`), so under `EST-04`'s logistic form `Ḡ → 0` asymptotically and the loop **stalls**; whether `λ` needs a decay or window is **open, not settled by omission** (open item **O8**); (c) consequently, and consistently with `Theorem36_no_interior_root_off_the_band`, "drive the residual to zero" is **unachievable in the asymptotic regime**. No requirement may describe the pair `(ν, λ_MEV)` as *measured* while `NEC-02` declares `λ` a model output.
- [ ] **NEC-07**: **Stability, stated correctly.** Loop direction is `sign(∂²π̂^σ/∂τ²)` — **not** `sign(Ḡ)`. The plant is **discrete-time** (`Convention 7`, `Definition 34`), so for `τ_{k+1} = τ_k + k·residual` the closed loop is `(1 + kJ)` and stability requires `−2 < kJ < 0`: **an upper bound on `|J|`, hence on `|Ḡ|`, is required to choose `k` at all.** `H1` (`∂L̄/∂π^φ`) enters through the residual's prefactor `∂π̂^σ/∂φ` by `Proposition 12` — it cancels at the root but **scales and signs the loop gain**, and `EST-03`'s specification tests `H2` only, so **`H1` is undischarged on every branch**. The box `τ_MEV ∈ [0,1]` and the corner solution (`Proposition 13`: `τ* > 0` **iff** the gate dominates) require **projection and anti-windup**. Open item **O2** restated unweakened: the loop reaches a stationary point, not a proved minimiser. **Kill condition:** if Phase 2 returns `∂_(t+1,t)` structurally zero, the plant is memoryless, `ROADMAP.md`'s Phase 2 SC2 re-scopes to static inversion, and this requirement's dynamic machinery is **void as written**.
- [ ] **NEC-08**: **The equality constraint is not dropped.** `Definition 36` is `min (∂π̂^σ/∂τ)²` **subject to `π^σ = π̂^σ`**. A loop closing on the objective alone neither enforces nor monitors feasibility, and if the constraint binds the unconstrained stationary point is not the constrained optimum. Either the loop monitors `e^σ = |π^σ − π̂^σ|` and reports excursions, or the document states plainly that feasibility is unenforced and what that costs.
- [ ] **NEC-09**: **The ledger, with the demotion withdrawn.** For each of `EST-03`'s three terminal verdicts, what Phase 6a delivers and what it loses. **`EST-04`'s demotion to refinement is WITHDRAWN** by `NEC-00`'s refutation; the ledger records the withdrawal explicitly so no downstream document inherits the retracted reading. The claim "the estimation is no longer load-bearing" is **banned outright** — from this planning layer and from the Phase 7 deliverable alike — unless `NEC-00` returns a verdict overturning the refutation.

### Literature & Venue Research

Added 2026-08-09. The Estimation category was specified with **no research requirement**:
`06-02` said "venue selection" while `ECONOMETRICS-DESIGN.md` §6 conceded the data source
and venue were open and assumed Dune. Venue is an **output** of this category, never a prior.

- [ ] **LIT-01**: **The internal corpus is re-read for empirical design, not theory.** The 14 PDFs in `plank/refs/{mev,flair}` — Milionis–Moallemi–Roughgarden, the five Capponi papers, Mazorra, Kulkarni–Diamandis–Chitra, **Chitra (Theory of MEV II: Uncertainty)**, Daian, Guo, Obadia, Campbell–Bergault–Milionis–Nutz, Milionis–Wan–Adams — **all fourteen, enumerated so the roster is exact** — have been mined only for their theory. Each is re-read for **identification strategy, data source, unit of observation, estimated pool-level effect sizes, and instruments used**, with an explicit transfer verdict per paper: transfers / transfers with modification / does not transfer, and why.
- [ ] **LIT-02**: **arXiv sweep**, via the arxiv MCP (standing rule: arXiv over web search for academic work). Target classes: empirical AMM/LVR studies, fee-versus-flow elasticity, pool-level panel regressions, and — critically — what other work has used as an **instrument** on block time or realized volatility, since `Δt` is our proposed lever and its weakness is the named risk. Each hit carries the same transfer verdict as `LIT-01`. **Because this requirement manufactures a menu of candidate instruments, the selection rule among them is written into the frozen research register BEFORE any dispersion is measured.** `06b-00` closes with that register timestamped; **adding literature after `EST-03` returns is a protocol violation on the same footing as re-specification**, since "we found a paper suggesting a better instrument" is the standard laundering route around a re-specification ban.
- [ ] **LIT-03**: **On-chain empirical literature outside arXiv** — Dune-published studies, protocol research posts, and foundation reports on realized fee-versus-volume and live dynamic-fee experiments. **Tagged lower-rigor as a class**: this material may motivate a specification and may **screen candidate chains**, but it may **never** be the sole justification for a specification and may **never supply the reported dispersion number** — dispersion is a measurement, not a motivation (`EST-02` measures it). Where it conflicts with `LIT-01`/`LIT-02`, the peer-reviewed source governs and the conflict is recorded.
- [ ] **LIT-04**: **The pool algebra, and the venue chosen from it.** `ν` and `λ_ARB` are derived in **Algebra Integral**'s own state variables (user ruling 2026-08-09) — the venue whose `AdaptiveFee` our `φ` is a port of, so `Φ`'s functional form and the volatility-oracle object are structurally the same, not merely analogous. The **chain** is then chosen from measured `Δt` dispersion and the **pool set** from measured `φ` dispersion, feeding `EST-02`. **These are different axes and the distinction is load-bearing:** `Δt` is **chain-level, not pool-level** (`ECONOMETRICS-DESIGN.md:74-76`), so pool selection buys *exactly zero* instrument variation — every pool on a chain sees the same cadence. Decision #13 settles the **codebase** (Algebra Integral), not the **chain**, and the `AdaptiveFee`-port argument justifies structural similarity of `φ` while saying nothing about the instrument. **Candidate chains and pools are pre-declared as a set; neither may be pruned on realized first-stage F**, which would be instrument-strength selection and a winner's curse on the reported F. If the derivation shows `ν` is not expressible in the venue's state, that is recorded as terminal for the external route and `NEC-02`'s own-protocol route becomes the only one.

### Estimation

Promoted from v2 by the 2026-08-08 design (`control/spec/ECONOMETRICS-DESIGN.md`).
`Ḡ = ∂ν/∂λ_MEV` is the **only empirical object** in the corrected law — every other
factor is structural. Estimating it is simultaneously the **test of H2**, carried
undischarged through both Lean bundles.

- [ ] **EST-01**: `ν`'s **empirical construction** is established — whether `ν = \varphi_{(1/2,0)}(i_K; ΔQ, 0; t) / \varphi_{(1/2,0)}(i_K; 0, L; t)` is directly computable from pool state and swap events, or requires reconstruction, with the read path named. Blocks everything else in this category.
- [ ] **EST-02**: The **identification lever is validated before use** — `Δt` enters `ℙ_{Δ_ARB}` but not the fee schedule (a clean exclusion), yet its exogeneity and, critically, its **dispersion** on the chosen venue are open. Run the structural-econometrics discipline over the choice; a venue with near-constant `Δt` yields a weak first stage biased *toward* OLS, which is the bias being escaped. **Decision #10 (`Δt` exogenous or endogenous) is deferred here, not closed in the doc layer.**
- [ ] **EST-03**: **Stage 1 — the sign test, as a gate.** Test `∂ν/∂λ_MEV > 0` only, on a specification, instrument, sample and power floor **fixed before the data is touched**. Report the first-stage F **before** examining the second stage. Three terminal outcomes, all reportable: gate opens; **wrong sign ⟹ H2 REFUTED**; or **not identified**, exactly as the `υ` exercise — a delivered result, never a prompt to re-specify.
- [ ] **EST-04**: **Stage 2 — magnitude, only behind the gate.** Fit `ν = a + b·σ_ℓ(c(λ − d))` by nonlinear IV/GMM, giving `Ḡ = b·c·σ_ℓ'(c(λ−d))` — a logistic bump reusing `AdaptiveFee`'s on-chain sigmoid machinery, vanishing on the saturation bands per `Theorem36`.
- [ ] **EST-05**: **Output contract and back-propagation.** Deliver `(a,b,c,d)` with covariance, the first-stage F, and the **admissible band** where `Ḡ` is bounded away from zero, intersected with `Theorem36`'s responsive band. Stage 1's verdict **discharges or refutes H2** in `MevTaxControl.lean` and `MevTaxProgram.lean`; a refutation flips `Theorem34`'s opposed-signs result and the corrected law's sign.
- [ ] **EST-06**: **The bad-control hazard is resolved in writing before Stage 1 is specified.** `φ_X` carries `ν` (`DOC` Definition 18), so `φ_X` is a **function of the outcome**; conditioning on it is conditioning on a descendant of the dependent variable. This is open item **O3**'s *identification* content, which must not be displaced by its implementation content in `NEC-03`. **`φ_X` may not enter the Stage 1 specification as a control** unless this is resolved and the resolution written down.
- [ ] **EST-07**: **Numeric thresholds are pre-registered, or the pre-registration is one in name only.** Every "terminal" verdict is adjudicable after the fact until these carry numbers: the **first-stage strength floor** (and which criterion — a conventional `F ≥ 10` or a Montiel Olea–Pflueger effective-`F`, the latter being the right one for a single weak instrument), the **minimum `Δt` dispersion**, the **minimum N**, the **target power**, and the **clustering level**. Clustering is not a detail: with a **chain-level** instrument and **pool-level** outcomes, effective N is the number of periods carrying `Δt` variation, **not** the number of swaps, and standard errors cluster at chain-time. The `υ` precedent exists to remove exactly this discretion.
- [ ] **EST-08**: **Validity threat `Δt ⟂̸ σ` is registered with a pre-committed test.** The exclusion argument is that `Δt` does not appear in `φ = φ̄ + volSurcharge(σ)·gate(ν)` — structurally true. But `Δt`'s realized variation comes from missed slots, congestion and reorgs, which **cluster with volatility events**, and `σ` enters `φ` directly; so `Δt` correlates with the second-stage error **through the `σ` channel** without ever appearing in the fee formula. This is plausibly more fatal than the weak-instrument risk the design already names, and **conditioning on `σ` is not a free fix** because `σ` is itself a determinant of `φ`.
- [ ] **EST-09**: **Selection and estimation are separated.** Selecting venue and pool set on measured dispersion and then reporting the first-stage F on that same selection makes the reported F conditional on an argmax, upward-biased, and destroys the nominal size of the pre-registered threshold — the mechanism by which a weak instrument passes a strength test. Either **split-sample** (select on window A, timestamp the pre-registration, estimate on window B), or the F is labelled **descriptive** and the threshold rule is stated to be void.

### Consolidation & Hand-off

- [ ] **HND-01**: A gap register lists every open item with severity and disposition (in-scope vs deferred), including the event-clock question and any obligation left as a hypothesis.
- [ ] **HND-02**: The **formal controller document** integrates frame, entrywise plant, verdicts, typed hypotheses and salvage, each section delegating detail to its owning document. This is the project's deliverable.
- [ ] **HND-03**: The hand-off to downstream milestones is defined — the deferred **EVM-01a/01b/02/03/05/06** feasibility track — with cross-worktree coordination points named and their owning peer sessions identified. Peer agreement is **obtained**, not assumed: `list_peers` at repo scope returns nothing, `CLAUDE.md` has no row for this track, and silence is not consent.
- [ ] **HND-04**: The stale v2-controller documents (`LEAN-MAP.md`, `EVM-CONTROL-PRIMITIVES-MAP.md`) are marked do-not-cite so they are not consumed as current.
- [ ] **HND-05**: A review register exists and is honest about its own history: the founding artifacts (`b5f5e82`, `9658375`, `d3b226a`) were committed **before** their two-step review ran, and that review's findings are recorded as the register's **retroactive first entries**. Every subsequent artifact passes the gate before commit. The v2-controller `SPEC-04` precedent is what this exists to avoid repeating — and did not.

---

## v2 Requirements

Deferred — tracked, not in this roadmap.

### EVM Feasibility — moved out of v1 by the 2026-08-08 scope ruling

Carried here intact so the analysis is not lost. Each row is BLOCKER-grade for an
implementation milestone and none of it is answerable from theory alone.

- **EVM-01a**: fixed-point primitive inventory refreshed against the live Plank tree (supersedes the stale `EVM-CONTROL-PRIMITIVES-MAP.md`; the "no WAD `exp`/`ln`/`pow`" claim is already false — `FixedPointMath.plk` ports solady `rpow`, `AdaptiveFee.plk` has a Taylor `exp`)
- **EVM-01b**: on-chain **state-variable** inventory. `grep -rin "tau\|mev\|utilization" plank/src/` → **zero hits**: `τ_MEV` and `ν` have no slot, setter or type, so three of the law's five factors have no on-chain referent
- **EVM-05**: name the call site (`beforeSwap` hook / separate hook / permissioned setter / keeper). Determines everything else — saturate-never-revert is right in `beforeSwap` and wrong in a mint path, where the live tree deliberately reverts (`PanopticTokenIdSetterLib.plk:132-135`)
- **EVM-02**: feasibility analysis of the verified law — primitives, scale, signedness, rounding, saturation semantics, cost envelope. **Scale is inherited, not chosen**: `plank/notes/UNITS_AND_SCALES.md` at a pinned sha (the tree is Q64.96; `φ_X` is 1e-6 masked to `uint16` — WAD is the wrong mandate)
- **EVM-03**: reconcile the model's strike count `#_σ` with `ι` (`VOLATILITY_INSTRUMENTS_MEV.tex:212`) and the structural 4-leg bound at `PanopticTokenIdSetterLib.plk:140`
- **EVM-06**: real numeric hazards — actuator quantization (`φ_X` in 1e-6 steps, `Θ_φ` `uint16`) and sigmoid **saturation bands** (`AdaptiveFee.plk:53-60`), where `∂φ_X/∂ν = 0` exactly. The `(1−φ)` pole is structurally unreachable (`φ_X ≤ 0.065535`) and is not the hazard

### Implementation

- **IMP-01**: Plank/Solidity implementation of the verified law
- **IMP-02**: Gas benchmarking against a live pool
- **IMP-03**: Differential testing of the on-chain law against the off-chain reference

### Control extensions

- ~~**CTL-01**: Closed-loop feedback regulator wrapped around the set-point~~ — **PROMOTED TO v1 on 2026-08-09** as the Non-Estimated Control category (`NEC-01`…`NEC-06`, Phase 6a). Closed here; do not plan against this ID.
- **CTL-02**: General `η ≠ ½`
- **CTL-03**: Relaxing `φ_M ≡ φ̄_M` to make `φ_M` a live actuator
- **CTL-04**: Re-opening `(β_j, γ_j)` as actuators, now that the non-control justification is known to be unsupported

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| EVM implementation of the control law | Design spec only; `src/` is peer-owned by `ul2inqpl` |
| Closed-loop feedback law over `e^σ` | Control target is an optimal set-point (user decision). **Still out of scope, and narrowly so:** `NEC-04`'s loop closes on the **FOC residual `∂π̂^σ/∂τ_MEV`**, not on the replication residual `e^σ = \|π^σ − π̂^σ\|`. Replication remains a feasibility region, never the objective. This row must not be read as excluding the Non-Estimated Control category |
| Dynamic-fee **natural experiments** as a research source class | Considered as a fourth source for `LIT-*` (live pools that changed fee schedule — Algebra `AdaptiveFee` rollouts, Uniswap fee-tier migrations, the closest thing to an exogenous shock to `φ` that exists) and **deliberately not selected** by the user on 2026-08-09. Recorded as a decision, not an oversight; reopening it is a scope change |
| `spec/01_STATE_DELTA_ELASTICITY_CONTROLLER/` | Explicitly removed from scope by the user |
| Any edit to the repo-root `.planning/` | Shared v1 planning, in flight across peers |
| Re-deriving the spatial/tick-lattice controller | Owned by the v2-controller milestone; this is the event-time axis |
| Re-attempting T24 | Refuted by counterexample; only the Θ_φ-restricted varying-σ case remains open |
| Identifying `υ` econometrically | Terminal null result on the planning record; never reopen |
| Dimensional analysis / event-time indexing sent to Aristotle | Not proof-shaped; resolved in the spec layer instead |

---

## Traceability

Populated during roadmap creation (2026-08-08); repopulated after the 2026-08-08 roadmap
rewrite (8 phases -> 6); **repopulated again after the 2026-08-08 RE-BASELINE** (6 phases -> 7)
that recorded Phases 4 and 5 as delivered out of order by two Aristotle bundles and promoted
the Estimation category from v2 to v1.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NOT-01 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-02 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-03 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-05 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-06 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-07 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-08 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-09 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-10 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| HND-04 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| HND-05 | Phase 1 -- Ground Truth, Notation, Rulings Triage | Pending |
| NOT-04 | Phase 2 -- Entrywise Plant & Control Frame | Pending |
| FRM-01 | Phase 2 -- Entrywise Plant & Control Frame | Partial (frame research exists) |
| FRM-02 | Phase 2 -- Entrywise Plant & Control Frame | Partial (frame research exists) |
| FRM-03 | Phase 2 -- Entrywise Plant & Control Frame | Partial (frame research exists) |
| FRM-04 | Phase 2 -- Entrywise Plant & Control Frame | Pending |
| FRM-05 | Phase 2 -- Entrywise Plant & Control Frame | Pending |
| PRF-03 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (H1/H2 landed as typed hypotheses; protocol unwritten) |
| PRF-06 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (idiom used ad hoc) |
| PRF-07 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (freeze applied by hand; unwritten) |
| PRF-08 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (gate applied by hand; `#print axioms` UNVERIFIED -- open item O1) |
| PRF-09 | Phase 3 -- Verification Protocol, Ratified Retroactively | Pending (detectors never ran) |
| PRF-10 | Phase 3 -- Verification Protocol, Ratified Retroactively | Partial (TAX_ADDENDUM.md / TAX2_ADDENDUM.md served as the hand-off; template unwritten) |
| PRF-01 | Phase 4 -- Verdicts: P1, P2, P5 (BRANCH GATE) | **DELIVERED** -- Bundle 1, `Theorem30_composed_fee_submersion_section_sum_ill_posed` |
| PRF-02 | Phase 4 -- Verdicts: P1, P2, P5 (BRANCH GATE) | **DELIVERED** -- REFUTED with witness, `Corollary29_five_factor_product_not_total_derivative` |
| PRF-05 | Phase 4 -- Verdicts: P1, P2, P5 (BRANCH GATE) | **DELIVERED** -- substitution not licensed, `Theorem32_hazard_strictAntiOn_tau` |
| PRF-04 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- box REFUTED factor by factor, `auditTable` (M24) |
| SAL-01 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- `Proposition16_audit_justification`, per-factor defect + error class |
| SAL-02 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- `Proposition16_corrected_law` |
| SAL-03 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- domain `tau*<1`; `tau*>0` iff the gate dominates; `Theorem36_no_interior_root_off_the_band` |
| SAL-04 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- machine-verified declaration, not prose |
| SAL-05 | Phase 5 -- The Set-Point Law: Verdict & Salvage | **DELIVERED** -- signs derived from H1/H2 by name (`Theorem34_signs_from_H1_H2`) |
| NEC-00 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (**BLOCKS the category**; verifies the refutation as an algebraic identity) |
| NEC-01 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (**BLOCKING** -- uniform clearing checked against venue AND deployment) |
| NEC-02 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (observer, not measurement; carries O4, O6; two-clock defect) |
| NEC-03 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (carries O3's implementation sense; identification sense goes to EST-06) |
| NEC-04 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (falsification standard fixed first; three objections to clear) |
| NEC-05 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (computed-or-dithered disjunction; anti-fishing applies to the dither) |
| NEC-06 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (carries O7, O8 -- self-confirming observer, divergent accumulator) |
| NEC-07 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (restates O2; **H1 undischarged on every branch**; Phase 2 kill condition) |
| NEC-08 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (the equality constraint is monitored or its absence is costed) |
| NEC-09 | Phase 6a -- On-Chain Fixed-Point Iteration of the Law | Pending (ledger; **records the withdrawal of EST-04's demotion**) |
| LIT-01 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (14 internal PDFs, re-read for empirical design) |
| LIT-02 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (arxiv MCP sweep) |
| LIT-03 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (lower-rigor class; never a sole justification) |
| LIT-04 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (Algebra Integral pool algebra; feeds EST-02) |
| EST-01 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (BLOCKS the rest of the Estimation category) |
| EST-02 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (carries Decision #10, deferred here; consumes LIT-04) |
| EST-03 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (**HARD GATE** -- three terminal outcomes) |
| EST-04 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (runs only behind EST-03's gate; **FULLY LOAD-BEARING -- the demotion was withdrawn 2026-08-09**) |
| EST-05 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (back-propagates into both Lean bundles) |
| EST-06 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (bad control -- `phi_X` is a function of the outcome; O3's identification sense) |
| EST-07 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (numeric thresholds; clustering at chain-time, not swap) |
| EST-08 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (`Delta t` not orthogonal to `sigma` -- the likely-fatal validity threat) |
| EST-09 | Phase 6b -- Research, Venue, and Estimating `Gbar` | Pending (winner's curse -- selection separated from estimation) |
| HND-01 | Phase 7 -- Formal Controller Document & Hand-off | Pending (must carry open items O1-O8) |
| HND-02 | Phase 7 -- Formal Controller Document & Hand-off | Pending |
| HND-03 | Phase 7 -- Formal Controller Document & Hand-off | Pending |

**Coverage:**
- v1 requirements defined: 58 (FRM 5 + NOT 10 + PRF 10 + SAL 5 + **NEC 10** + **LIT 4** + **EST 9** + HND 5)
- Mapped to phases: 58
- **Arithmetic correction (2026-08-09):** the previous coverage block read "39 (… + NOT 9 + …)". `NOT-*` runs `NOT-01`…`NOT-10` — **ten** requirements, all ten mapped in `ROADMAP.md`. The prior true total was **40**, not 39. The error sat in **both** this summary line and `ROADMAP.md`'s coverage-table cell — the first pass claimed it was "in the summary line only", which was itself wrong. No requirement was ever unmapped. Verified by set comparison of the IDs defined here against the IDs in `ROADMAP.md`'s `**Requirements**:` lines **and against `ROADMAP.md`'s own Requirement Coverage table**, which the first pass left stale at 39 while the header said 50 — a document stating two totals in one file is not commit-ready, and the earlier claim that "the error was in the summary line only" was itself wrong: the coverage **table cell** carried it too.
- Mapped to more than one phase: 0
- Unmapped: 0 (verified programmatically: the set of IDs defined above equals the set mapped
  in `ROADMAP.md`'s `**Requirements**:` lines)
- Delivered: 9 (PRF-01, PRF-02, PRF-04, PRF-05, SAL-01..05) — **16%**, down from 23% because
  the denominator grew, not because work was lost

**Standing open items against the delivered requirements** -- these are NOT closed by the
DELIVERED status above and are carried into the Phase 7 gap register:

| # | Open item | Against |
|---|---|---|
| O1 | `#print axioms` UNVERIFIED on both bundles (needs a Mathlib build) | PRF-08; all of Phase 4 and 5 |
| O2 | The FOC root is **not** established to be the minimiser (`Proposition15_level_reading_second_order_undetermined`); `Proposition15_single_crossing_gives_minimum` is conditional on an unproved single-crossing property | SAL-02, SAL-04, **NEC-07** (the on-chain loop inherits this defect; a gradient loop reaches a stationary point, not a proved minimiser) |
| O3 | `phi_X` carries `nu`-dependence (`DOC` Definition 18) so `Rule 13`'s signature at `SRC:69` may be incomplete | NOT-02, NOT-04, **NEC-03** (decides whether the `nu` read sits inside a loop in `beforeSwap`), **EST-06** (the identification sense: `phi_X` is a function of the outcome, a bad control). *Routing corrected 2026-08-09 -- this row pointed at `NEC-02` before the category was renumbered.* |
| O4 | `sigma` versus `sigma^2` units | NOT-05, EST-03, **NEC-02** (the accumulator reads a volatility-oracle quantity whose units must be pinned before it is summed), **LIT-04** (the dimensional check against Algebra's oracle). *Routing corrected 2026-08-09 -- this row pointed at `NEC-01` before the category was renumbered; `NEC-01` is now the uniform-clearing precondition.* |
| O5 | The project has **no defined failure condition** | HND-01 |
| O6 | **The on-chain observer is a model output, not a measurement.** `P_{Delta_ARB}` is leading-order and quasi-static (caveats `[M8]`), so an on-chain `lambda` accumulator computes what the model says the hazard is. The on-chain route **relocates the empirical burden and destroys its audit trail** -- an online gain estimate has no first-stage F, no covariance and no pre-registration, unlike the offline route it was proposed to replace | NEC-02, NEC-05, LIT-01 |
| O7 | **The observer is SELF-CONFIRMING.** `lambda_ARB` is a function of `phi`, and `phi` contains `tau_MEV` via the Rule 12 monoid, so the controller's action moves its own measurement exactly as the model prescribes. The loop cannot detect model error; it converges to the model's root -- i.e. it is the `Gbar`-dependent closed form solved by on-chain fixed-point iteration, not a controller that avoids `Gbar` | NEC-06 |
| O8 | **`lambda_ARB` is monotone NON-DECREASING -- as a DERIVED reading, not a citation.** `mevMulti_nonneg` (`control/aristotle/{tax,tax2}-result/project_aristotle/RequestProject/MevOptimization.lean:250`, byte-identical in both bundles) concludes `0 <= mevMulti ...` -- the **total**. Per-summand nonnegativity is a proof-internal step (`Finset.sum_nonneg`) that holds under the same hypotheses and yields monotonicity, but **no carrier states monotonicity** and the declaration does not assert it. **CORRECTIONS 2026-08-09 (twice):** the original wording said "monotone **divergent**" and cited that theorem for it -- divergence requires non-summability, which no carrier establishes. The first correction then said "all summands are nonnegative (`mevMulti_nonneg` ... which states `lambda_ARB >= 0` and nothing more)", which asserts and denies the same thing in one sentence. Both are fixed above. Whether `lambda_ARB` diverges -- and hence whether `Gbar -> 0` asymptotically and the loop stalls -- is **OPEN**, as is whether `lambda` needs a decay or a window | NEC-06, EST-04 |

> **Record correction (2026-08-08, re-baseline):** the previous traceability table mapped 34
> requirements across 6 phases and listed `EST-01` as v2. The Estimation category is now v1
> (`EST-01`..`EST-05`), mapped to the new Phase 6; the old Phase 6 (document and hand-off) is
> renumbered Phase 7. Phases 4 and 5 are recorded as DELIVERED **out of order** -- they were
> executed by direct Aristotle submission ahead of Phases 1-3, not after them. The earlier
> correction stands: `EVM-01`..`EVM-04` are not v1 requirements and `EVM-04` does not exist.

> **Record correction (2026-08-09):** Phase 6 is split into **6a** (Non-Estimated State
> Feedback, `NEC-*`) and **6b** (Research, Venue, and Estimating `Gbar`, `LIT-*` + `EST-*`),
> with **6a executing first** (user ruling). Execution order becomes `1 -> 2 -> 3 -> 6a ->
> 6b -> 7`. v2 `CTL-01` is promoted into `NEC-*` and closed; `CTL-02`/`CTL-03`/`CTL-04`
> remain v2 and keep their IDs. A sixth standing open item **O6** is opened against the
> observer/measurement distinction, and **O7**/**O8** on the self-confirming observer and the
> divergent accumulator. Requirement count 40 -> 58 (the previously recorded 39 was an
> arithmetic slip carried in BOTH the summary line and the roadmap's coverage table).
>
> **What this correction does NOT claim:** that the estimation is optional, or ever was.
> `EST-04`'s demotion **was proposed on 2026-08-09 and withdrawn the same day** when both
> reviewers refuted its premise. The Estimation category is fully load-bearing on every
> branch. The phrase "no longer a single point of failure" is **banned** from this project's
> documents unless `NEC-00` returns a verdict overturning the refutation.

---
*Requirements defined: 2026-08-08*
*Last updated: 2026-08-09 -- Phase 6 split into 6a/6b; the free-option premise refuted by independent derivation (pending NEC-00's carrier) and Phase 6a re-scoped; EST-04's demotion withdrawn; O8's divergence overclaim corrected; O3/O4 routings corrected after the NEC renumber; 58 requirements*
