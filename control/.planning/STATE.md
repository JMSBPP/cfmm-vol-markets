# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-08)

**Core value:** The artifact under construction is the artifact under proof — return a *verdict* on the boxed `τ*_MEV`, and a corrected law where it refutes.
**Status of the core value:** ✅ **DELIVERED.** The box is refuted factor by factor (`auditTable`, M24) and the corrected law is derived and machine-verified (`Proposition16_corrected_law`). What remains is the supporting apparatus, the empirical `Ḡ`, and the document.
**Current focus:** Phase 1 — Ground Truth, Notation, and the Rulings Triage (plans staged, unexecuted). **Phase 6 was split into 6a/6b on 2026-08-09**, and the free-option premise was **refuted at the review gate the same day**; Phase 1 execution is unchanged and still owed.

## Current Position

Phase: 1 of 8 (Ground Truth, Notation, and the Rulings Triage) — **remaining** work
Plan: 0 of 6 in current phase (all 6 written, reviewed twice, refreshed once, and re-pinned 2026-08-09 against `SRC` @ `cf386de` / blob `04bac0a5` and again against **`0fc821a` / blob `33af6a85`**; staged and uncommitted)
Status: **Ready to execute** — not "ready to plan"
Last activity: 2026-08-09 — **`06B-00` EXECUTED OUT OF ORDER and now COMPLETE (3 of 3 tasks).** Resumed from Task 2 after the prior executor blocked for want of the `Task` tool, MCP and `WebSearch`. `LIT-01`, `LIT-02` and `LIT-03` are closed and `control/spec/RESEARCH-REGISTER.md` is committed in a single commit at `5f7f3d8` (`REGISTER FIRST COMMIT 5f7f3d81fce1c1c00e60a03814927a5a96b991ac 1786298674 2026-08-09T14:04:34-04:00`) — the sha four downstream plans pin as evidence that §5's instrument-selection rule predates every dispersion measurement. Phase 6b is now **1/7**. **The out-of-order deviation stands and is NOT normalised away.** Three findings materially change the phase: the `Δt` identification *idea* is not novel (a peer-reviewed latency-instrument family exists off arXiv); the estimand's **sign is indeterminate** until a time-base convention is ruled; and the exclusion restriction is **already refuted** by a direct participation channel. **Neither of the two reviewers certified the register** — it is committed as an honest record, explicitly not as a certificate that the design is sound. Preceded the same day by the Phase 6 **SPLIT** into 6a (On-Chain Fixed-Point Iteration of the Law, `NEC-*`) and 6b (Research, Venue, Estimation, `LIT-*` + `EST-*`), with 6a ordered first; the free-option premise **REFUTED at the review gate** and `EST-04`'s demotion withdrawn

Progress: [█░░░░░░░░░] ~16% (2 of 8 phases complete; 9 of 58 requirements delivered)

> The percentage fell from 31% without any work being lost: the denominator grew from a
> corrected 40 requirements to 58, and the phase count from 7 to 8. The prior "39" was an
> arithmetic slip carried in **both** `REQUIREMENTS.md`'s summary line and `ROADMAP.md`'s
> coverage table — `NOT-*` has ten members, not nine.

**Phase status at a glance:**

| Phase | Status |
|-------|--------|
| 1. Ground Truth, Notation, Rulings Triage | Planned, **not executed** (6 plans on disk, re-pinned against `0fc821a` / `33af6a85`) |
| 2. Entrywise Plant and Control Frame | **Partial** — frame research exists; `NOT-04`, `FRM-05` undone |
| 3. Verification Protocol, Ratified Retroactively | **Ad hoc** — applied by hand; protocol unwritten, `PRF-09` detectors never ran |
| 4. Verdicts — P1, P2, P5 (BRANCH GATE) | ✅ **COMPLETE** (Bundle 1, out of order) — branch gate FIRED: P2 REFUTED |
| 5. The Set-Point Law — Verdict and Salvage | ✅ **COMPLETE** (Bundle 2, out of order) — corrected law delivered |
| 6a. On-Chain Fixed-Point Iteration of the Law (NEW) | Not started — **runs before 6b**; founding premise refuted at the gate, phase re-scoped |
| 6b. Research, Venue, and Estimating `Ḡ = ∂ν/∂λ_MEV` | **1/7 — `06B-00` COMPLETE** (out of order). `LIT-01`…`LIT-03` closed; register committed at `5f7f3d8`. `06B-01`/`06B-02` **must be re-scoped before measuring** — they assume `Δt` *dispersion* is the identifying moment and the register records that as undetermined. Two rulings owed: the **time base** and the **`S-35` exclusion channel** |
| 7. Formal Controller Document and Hand-off | **In progress** — `SRC` restructured; PR #22 → `develop` open |

**Remaining execution order:** 1 → 2 → 3 → 6a → 6b → 7 (sequential; `parallelization: false`).

## Performance Metrics

**Velocity:**
- Total plans completed: 0 (Phases 4 and 5 were delivered by direct Aristotle submission, not through GSD plans)
- Bundles landed: 2 (1985 Lean lines, 96 declarations, 0 `sorry`)
- Average duration: —
- Total execution time: not tracked for the direct-submission route

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 4 | 0 (direct submission) | — | — |
| 5 | 0 (direct submission) | — | — |

**Recent Trend:**
- Last 5 plans: —
- Trend: — (the two delivered phases bypassed the plan mechanism entirely; this is recorded as the route taken, not retrofitted)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Recent decisions affecting current work:

- **The boxed `τ*_MEV` is REFUTED and replaced (2026-08-08).** The corrected law, **with a signed denominator**, is `τ*_MEV = 1 + (1−φ_X)/((∂φ/∂ν)(∂ν/∂τ_MEV))`. It is **implicit, not closed** — all three factors are evaluated at `ν(τ*)`. Domain: `τ* < 1` always; `τ* > 0` iff the gate dominates. The absolute-value form `1 − (1−φ_X)/|·|` is conditional on the M21 signs and **must never be quoted as the theorem.**
- **The branch gate fired on P2 REFUTED (2026-08-08).** `Corollary29_five_factor_product_not_total_derivative` exhibits the witness; `Theorem29_monoid_path_is_direct` names the second path. Salvage became the main work, exactly as the branch table prescribed. The gate is not re-run.
- **Estimation promoted from v2 to v1 (2026-08-08).** `Ḡ = ∂ν/∂λ_MEV` is the only empirical object in the corrected law, and estimating it **is** the test of `H2`. Design approved: `control/spec/ECONOMETRICS-DESIGN.md` — `Δt` as instrument (clean exclusion), logistic-in-`λ` functional form, and a **staged gate** with Stage 1 (sign test) hard-gating Stage 2 (magnitude).
- **Decision #10 (`Δt` exogenous or endogenous) is DEFERRED to Phase 6** and is **NOT closed** in the doc layer. It is adjudicated by the structural-econometrics discipline in `EST-02`.
- **Scope (2026-08-08 user ruling):** the deliverable is the formal controller document. The entire EVM-feasibility track is v2 (`EVM-01a/01b/02/03/05/06`). `FRM-05` survives as pure theory with **no on-chain cost claim attached**.
- **Behavioral gains are hypotheses, never proved (2026-08-08):** `H1_dLbar_dpiPhi_pos` and `H2_dnu_dlamMEV_pos` are LP-supply estimands. Neither is ever sent to Aristotle. **`EST-03`'s sign test is what discharges or refutes them** — this replaces the old "magnitudes are v2" disposition.
- **`L` is two assets (2026-08-08):** `L(i_K) = L̄·ℓ(ξ,ι;i_K)` with `ℓ` geometry-invariant; `ΔQ_v★` is vol-asset L (`UNITS_AND_SCALES.md:70`), `L̄` is price-axis pool liquidity. This killed the `τ* = 1` refutation.
- **The "controller without `Ḡ`" premise is REFUTED (2026-08-09, Decision #15).** Composing `Theorem 30` + `Theorem 29` + `∂ν/∂τ = Ḡ·(∂λ/∂τ)` gives `∂π̂^σ/∂τ = (∂π̂^σ/∂φ)·[(1−φ_M)(1−φ_X) + (∂φ/∂ν)·Ḡ·(∂λ/∂τ)]` — `Ḡ` multiplies one of two bracket terms, so **evaluating the residual is evaluating `Ḡ`**. Both review-gate reviewers derived it independently; verified before acceptance. **`EST-04`'s demotion is WITHDRAWN** and the Estimation category is fully load-bearing on every branch. Phase 6a survives re-scoped as **on-chain fixed-point iteration of the `Ḡ`-dependent law** — it removes a stored constant and tracks drift, and is **not** a hedge against the estimation failing.
- **The sign/magnitude split as first written was FALSE.** Loop direction is `sign(∂²π̂^σ/∂τ²)`, not `sign(Ḡ)`; the plant is discrete-time so a stability certificate needs a **bound on `|Ḡ|`**; and **`H1`** (`∂L̄/∂π^φ`) scales and signs the loop gain through the residual's prefactor (`Proposition 12`) while `EST-03` tests `H2` only — so **`H1` is undischarged on every branch**.
- **`λ_MEV = λ_ARB` requires the Angstrom regime** (`DOC:1041`), which neither Algebra Integral (continuous execution) nor a Uniswap v4 hook under one-hook-per-pool exclusivity provides — and the sandwich-zero result is **UNFORMALIZED, no carrier** (`DOC:1026`). `NEC-01` checks the precondition instead of asserting it.
- **The on-chain `λ` is an OBSERVER, not a measurement (O6), and it is SELF-CONFIRMING (O7).** `ℙ_{Δ_ARB}` is leading-order and quasi-static (`[M8]`), so an accumulator emits a model output; and because `λ_ARB` depends on `φ`, which contains `τ_MEV`, the controller's action moves its own measurement exactly as the model prescribes — the loop cannot detect model error and converges to *the model's root*. Also **O8**: `λ_ARB` is a monotone divergent accumulator, so `Ḡ → 0` asymptotically and the loop **stalls**; whether `λ` needs a decay or window is OPEN.
- **Decision #11 (where on-chain the `∂ν/∂λ_MEV` feedback is implemented) is OPEN and routed to Phase 6a (`NEC-05`, `NEC-07`).** It cannot be chosen before the precondition and constructibility verdicts, and its own phrasing presumes an object those verdicts decide.
- **Codebase = Algebra Integral, CHAIN = TBD (Decision #13, scope corrected).** The `AdaptiveFee`-port argument settles `φ`'s functional form, **not the instrument**: `Δt` is chain-level, so pool selection buys zero instrument variation. Chain is selected on measured `Δt` dispersion, and `EST-08` registers the likelier-fatal threat — `Δt ⟂̸ σ`, since missed slots cluster with volatility and `σ` enters `φ`.
- **Research sources = internal re-read + arXiv + non-arXiv on-chain material (Decision #14).** Dynamic-fee **natural experiments** were offered and **declined by the user**; recorded as a decision, so reopening is a scope change.

### Pending Todos

- Refresh three Phase 1 plans before executing them: `01-02` must carry Decision #10 as DEFERRED-TO-PHASE-6; `01-03` must carry the retroactive reconciliation of the symbols M11–M24 minted ahead of the register, plus open item O3; `01-05` must carry open item O4 and the bundles' reviewed-after-landing register entries.
- Phase 1's five plans are staged and uncommitted (`git status` shows all five as `M`).
- ~~**`SRC` re-pin owed.**~~ **DONE 2026-08-09.** All six Phase 1 plans were re-pinned against `cf386de` / blob `04bac0a5`, and again against `0fc821a` / blob `33af6a85` (a **ZERO-RELOCATION** move — no citation needed relocating, because `SRC` is cited by numbered block): 10 citations moved onto their numbered blocks, **9 were recorded as STRUCK** (the `π^φ` algebra, the `(∂π^σ/∂φ_M,·)` pair, the boxed `τ*` and the root-vs-argmin sentence) and re-aimed at `DOC` Rule 6, `Theorem 31`, `Definition 36` and `Proposition 13`, and `SRC`'s citation form is now **BY NUMBERED BLOCK** — line-only citation of `SRC` is a defect. The plans still owe their two-step review before commit.
- **Two consequences of the re-pin are live work, not bookkeeping.** (a) `cf386de` wrote **eight blocks** into `SRC` — `Convention 8`, `Theorem 29`, `Theorem 30`, `Proposition 12`, `Theorem 31`, `Hypothesis (H2)`, `Definition 36`, `Proposition 13` — **delivered out of order**: `NOT-10`'s heavy-user-approval cadence ran for each of them (the requirement codifies that existing practice and names the `c521af5` blocks written under it), ahead of the GSD plan that encodes it, exactly as Phases 4 and 5 were delivered ahead of Phases 1–3. Plan `01-06` now opens with a **reconciliation**, retiring the four WRITABLE-NOW rows and one GATED row that named already-written blocks. **It does not re-approve them and puts no governance question to the user.** (b) ~~`Proposition 13`'s domain lines may be a G2-class sign claim ahead of its `EST-03` gate.~~ **RULED AND CLOSED AT SOURCE 2026-08-09 (`0fc821a`).** The gate found it, the user approved a corrected block under `NOT-10`'s cadence, and `Proposition 13` now states the non-degeneracy guard inline, the three sign/`φ_X` antecedents in an explicit guard, and `∂ν/∂τ_MEV < 0 rests on (H2) — UNDISCHARGED` in its rider. `01-06` §0.1 keeps its **measure-before-predict** form so it records the ruling rather than re-raising it. Residual carried to `HND-01` as a MINOR: `hA : A ≠ 0` and `hM : phiM ≠ 1` remain unstated — structural non-degeneracies, not sign claims, **not escalated**.
- **Phases 6a and 6b have no plans on disk** — only requirement mappings and expected plan titles. `/gsd:plan-phase 6a --cwd control` is the entry point **after Phases 1–3 land**; the execution order is sequential with `parallelization: false` and there is no pull-forward exception.

### Blockers/Concerns

**Standing open items (O1–O5), carried explicitly and routed:**

- **O1 — `#print axioms` is UNVERIFIED on both bundles.** Axiom-cleanliness is asserted from 0 `sorry` and the absence of `axiom` declarations, not from a sweep. A Mathlib build is required. → Phase 3 criterion 1. **Until it runs, "axiom-clean" is a claim, not a check.**
- **O2 — the FOC root is NOT established to be the minimiser.** `Proposition15_level_reading_second_order_undetermined` (`MevTaxProgram.lean:823`) exhibits the undetermination; `Proposition15_single_crossing_gives_minimum` (:890) is conditional on a single-crossing-from-below property that **nothing proves**. → Phase 7 gap register; load-bearing for Phase 6.
- **O3 — CLOSED AT SOURCE 2026-08-09 (`cf386de`).** `Rule 13 @ 04bac0a5` now reads `φ_X(t) = Φ(Θ_φ; σ(i(t)), ν(t))` and agrees with `DOC` Definition 18; at `45aeba4c` it read `Φ(Θ_φ; σ²(i(t)))` with no `ν`. **The consequence is carried, not the defect:** `φ_X` sits in `Proposition 13`'s numerator as `(1−φ_X)` and, through `ν`, inside its denominator, so the corrected law is self-referential in `φ_X` too. → Phase 1 records the closure (`CF-30`) → Phase 2 inherits the consequence.
- **O4 — `σ` versus `σ²` units — STILL OPEN, locus MOVED 2026-08-09.** It was a `DOC`-vs-`SRC` mismatch; after `cf386de` it is **internal to `SRC`**: `Rule 13 @ 04bac0a5` takes `σ(i(t))` while `Definition 32 @ 04bac0a5`'s `u_ex` third slot carries `σ²(i(t))`. A regression mixing them is wrong and dimensionally invisible. → Phase 1 units ledger (`NOT-05`, `CF-31`) → Phase 6a/6b.
- **O5 — the project has no defined failure condition.** Every outcome is written as a success. Flagged for the user; routed to the gap register (`HND-01`, Phase 7). **Not invented by the roadmap.**

**`06B-00` BLOCKED and the execution order broken (2026-08-09) — both recorded, neither normalised:**

- **Out-of-order execution.** `ROADMAP.md` declares `1 → 2 → 3 → 6a → 6b → 7`, `parallelization: false`,
  "no pull-forward exception". Phases 1, 2, 3 and 6a are unexecuted. `06B-00` was run first **by
  explicit user direction**, being the only Phase 6b plan with `depends_on: []`. No Phase 1 artifact
  was treated as existing. This is a second inversion of the dependency order, after Bundles 1 and 2.
- **`06B-00` stopped after Task 1 of 3.** `LIT-01`'s extraction is done and passes its `<verify>`
  (`control/spec/RESEARCH-REGISTER.md` §1, fourteen blocks, anchors, verdicts). **`LIT-02` and
  `LIT-03` were not attempted.** Cause: the executor had only `Read`/`Write`/`Edit`/`Bash` — no
  `Task` tool for the `lit-review` sub-agents or the adversarial referee, no arxiv MCP for
  identifier resolution, and **no way to run the mandatory two-step review that must precede the
  commit**. Resolvable by re-running from Task 2 with a fully-tooled executor.
- **The register is UNCOMMITTED, on purpose.** `06B-01`…`06B-04` pin the register's **first** commit
  as the record that §5's instrument-selection rule predates every dispersion measurement. A
  §1-only first commit would make that pin resolve to a commit containing no §5 — a false
  evidentiary claim no downstream check would catch. The file carries a do-not-commit banner.
- **Do NOT run `roadmap update-plan-progress 6b` or `requirements mark-complete LIT-01 LIT-02
  LIT-03` until `06B-00` actually completes.** `06B-00-SUMMARY.md` exists on disk for a plan that
  did **not** complete, and `update-plan-progress` counts SUMMARY files — running it would report
  Phase 6b as `1/7`. Phase 6b is **0/7**.
- **§1 is unreviewed.** Written by one executor with no reviewer available. Task 3's two-step review
  must cover §1, not only §2–§6.
- **Three Class A findings are already load-bearing** and are carried here so they survive the
  re-run: (a) the anchor paper `MilionisMoallemiRoughgardenArbProfitsFees` performs **no
  estimation** — it supplies the `√Δt` *structure*, never evidence for it, and its §7.3 eq. (27)
  confirms at source that noise-trader demand is left to reduced-form modelling, which is the
  missing demand-elasticity term the `[M8]` caveats name; (b) `GuoInvarianceMEV` Theorems 6–7 make
  the `Δt` first stage contingent on a strictly positive fee, confined to the *competitive* MEV
  component, and weak — an inequality with no lower bound, the sharpest available statement of
  `ECONOMETRICS-DESIGN.md` §2's weak-instrument risk, and adverse; (c) **zero of fourteen** papers
  use block time as an excluded variable, so `LIT-02`'s §2.4 question is wide open.

**Process concerns:**

- **The delivered work inverted the dependency order.** Bundles 1 and 2 landed before the notation map, units ledger, symbol register and entrywise plant table existed. Phase 1 acquires a retroactive reconciliation burden; Phase 3 is retro-ratification rather than gate-keeping, which is strictly weaker than the original intent.
- **13 blocking decisions remain untriaged.** At least 3 are answered on disk (`ν` vs `u` at `DOC:620-622`; Proposition 10 DECIDED at `DOC:803`; leg pairing is an errata artifact).
- **`research/SUMMARY.md` is partly known-wrong** (Rule-9 / `τ*>1` superseded); its "4 of 4 converged" claim is a shared-prior artifact. Honest P2 count: two independent derivations, one restatement, one invalid.
- **Review-gate debt:** the founding artifacts (`b5f5e82`, `9658375`, `d3b226a`) and **both Aristotle bundles** were landed before their two-step review. `HND-05` records these as retroactive entries; they are not back-dated.
- **`NOT-08`'s discovery failure is unclosed.** `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/` is still untracked (`git status` shows `??`) and at risk of destruction.

## Session Continuity

Last session: 2026-08-09
Stopped at: **Phase 6b's estimation route is TERMINAL.** `06B-00` executed (out of order, by user direction — the roadmap order `1 → 2 → 3 → 6a → 6b → 7` was not followed and Phase 1 has no execution record). The sweep delivered `control/spec/RESEARCH-REGISTER.md` @ `5f7f3d8` — 50 sources (14 internal PDFs, 26 arXiv all re-resolved through the arxiv MCP, 10 non-arXiv lower-rigor), §5's instrument-selection rule present in the first commit as required. It then ended the route it was built to serve: **`S-35` refutes the `Δt` exclusion restriction.** Verdict recorded at `control/spec/GBAR-VERDICT.md`.
Resume file: control/spec/GBAR-VERDICT.md

**LANDED — Aristotle bundle 3** (`f04c8802-09ea-47e7-b8a9-eb7ec7edbe1b`), extracted to
`control/aristotle/tax3-result/`. M25 PROVED (LVR cancels, fix 2 futile); M26(a) REFUTED on
one-sided flow, (b)(c)(d) hold with route (ii) STRICT and logically INDEPENDENT of `H2`, and the
two routes proved to close a loop; M27 REFUTED, missing primitive named as the **pool scale**, a
**dimensional** obstruction rather than a caveat one. Transcribed into `SRC` as `Convention 9`,
`Hypothesis (H1)`, `Theorem 32`–`Theorem 35` (commits `9a87ce1`, `3be0654`, `e4dbf72`, `b769c39`,
`236f635`, `c5649a7`) under `NOT-10`'s cadence.

**LANDED — Aristotle bundle 4** (`016fc0d1-fffa-4098-a379-48314c9ebd50`) →
`control/aristotle/tax4-result/`, `MevReturnsReduction.lean` (996 lines, 35 decls, axiom-clean).
**M28's algebra is correct**, but `Corollary 40` holds only under the **bare** slot reading —
`MevTaxProgram`'s `dphidnu` is bare, fixed by `hasDerivAt_phiTot`, while `SRC` Proposition 13 wrote
it as the composed `∂φ/∂ν`. Corrected at `d61f223` (third correction to that block). **REFUTED:**
`Corollary 40b` — `(1−φ_X)` does **not** cancel once the endogenous fee is carried; and
`Theorem40d` — **the loop removes `ε` entirely**, giving a second, different control law.
**HELD:** `Theorem 41` scale-freeness; `Theorem 42` comparative statics with signs derived
(`∂τ*/∂ε < 0`, `∂τ*/∂ν > 0`, `ε → 0⁻ ⟹ τ* → −∞`, `ε → −∞ ⟹ τ* → 1`, and `∂τ*/∂γ_R` has **no
global sign**); `Theorem 43` threshold elasticity `ε* = φ/((1−φ_M)(∂φ_X/∂ν)ν)`, quotable only with
its operating fee; **`Theorem 44` — open item O2 CLOSES on the reduced model**, single crossing
becomes a theorem, the root is unique and a **minimum**. Also: `Definition 36`'s
`min (∂π̂^σ/∂τ)²` **cannot discriminate** — every root minimizes it.

**LANDED — Aristotle bundle 5** (`a7249747-24b2-4584-b888-6f5475e08b67`) →
`control/aristotle/tax5-result/`, `MevShockInput.lean` (829 lines, 26 decls, axiom-clean).
**M33 HELD with `g` explicit**: `ν = g(s,φ,κ_φ) = |u^m − u^{−m}|`, `m = 1/(2|ε_{p/X}|)`,
`u = (1+s)(1−φ)`; consistency with `Theorem 39` **confirmed** (`L̄` is the explicit factor).
**M34 HELD for the domain**: one-sided flow unreachable from a shock; but the signed legs make
Rule 5's geometric mean undefined, so the unsigned reading is a **new OPEN: `UNSIGNED-LEGS`**
(replaces PR-REGION). **M35 — the two channels are ONE channel and BOTH control laws are
artifacts**: `Theorem47_shared_driver_leaves_no_root` — the FOC has **no root at any tax**, the
optimum is a boundary point; benign flow enters the loop *gain*, not the exogenous input. O2
recorded **resolved-empty**.

**The literature sweep then confirmed and redirected** (agent report, arXiv ids verified):
`2606.21769` Prop 4.1 **is our no-root result in print** (`α=0` ⟹ boundary), §6.2 names the fix;
MMR eq. (27) is an **accounting identity with an empty `NT_FEE` slot** — the `[M8]` citation
supplies a label, not a form; **no causal estimate of DEX swap-fee elasticity exists** (two 2026
papers state the identification failure; `S-21` non-detection); isoelastic `Q ∝ φ^{−ε}` appears
NOWHERE (monotone ⟹ no interior optimum); the field's uniform choice is the exponential hazard
`ν₀e^{−αφ}` with `α` **assumed, never measured**; and a state-space fee controller exists
(`2606.21769`, ergodic control, pro-cyclical volatility feedback, built on our exact `ℙ_ARB`).

**IN FLIGHT — Aristotle bundle 6, project `1be2b6f1-1dc2-42b9-872c-35f58c878c22`** (submitted
2026-08-10, RUNNING). Bundle `control/aristotle/tax6/`, spec `TAX6_ADDENDUM.md` (M36–M40), `SRC`
still at `d61f223`/`584b05e`. **The transactional channel**, by author ruling, in shock space:

- A second exogenous shock — a **private valuation shock `V ⊥ Δp/p`** — with payoff object
  **`π^{transactional}`**, and the measure connection the author specified:
  **`ℙ_trans = (1−ℙ_ARB)·h(φ)`** — benign execution lives on the complement of the arb event.
  Under an exponential tail, `h(φ) = e^{−αφ}`: **Form A is a shock-space participation
  probability and `α` is the tail rate of the valuation distribution.** Elasticity is never a
  primitive; isoelastic demand is BANNED (ban 6).
- Four new typed assumptions: **(A-ind)** the independence (load-bearing), **(A-tail)** with the
  no-causal-estimate finding attached, **(A-size)**, **(A-route)** — `τ`'s share NOT routed to
  LPs, per monoid entry (A).
- M36 the measure completes Proposition 9 (with the complement-vs-unconditional comparison
  derived BOTH ways); M37 the loop gains `i ≠ 0` and Theorem 47's no-root FAILS with the relaxed
  hypothesis named; M38 the interior optimum — profitability + undershoot conditions, **the
  top-up law `τ* = (φ*−φ_base)/(1−φ_base)`**, pro-cyclicality, corner taxonomy; **M39 the
  incidence question** (no-routing vs full-routing FOC, no sign asserted — flagged as the block
  most likely to surprise, since every paper has the fee-setter keep the revenue); M40 second
  order / O2 in the extended model, (A-tail) vs general log-concave `h` split.

**Pending user rulings, unchanged:** the channel fork (may be dissolved by M35), `PR-REGION` (may
be dissolved by M34), and — from before bundle 4 — `Convention 10` and the `Hypothesis (H3)`
promotion, both presented and unapproved. Bundle `control/aristotle/tax4/`, spec `RequestProject/TAX4_ADDENDUM.md`
(M28–M32), `SRC` pinned at `c5649a7`/blob `3f5ffb8`. The **returns reduction**:

- **M28** — `τ* = 1 + φ/[(1−φ_M)(∂φ_X/∂ν)νε]`. `(1−φ_X)` cancels, `H1` lives in `K` and cancels,
  and `τ` appears **once** — so `Proposition 13`'s implicitness may be an artifact of the
  composite denominator hiding a `(1−τ)` via `Convention 9`, not a property of the optimization.
  **The derivation is the orchestrator's own, unchecked**; `Corollary 40`'s consistency test
  against `Proposition16_corrected_law` is the load-bearing content.
- **M29** — the control law is scale-free, so M27's missing primitive is missing from a question
  the controller never asks.
- **M30** — comparative statics. **No sign asserted, deliberately.**
- **M31** — the **threshold elasticity**: how elastic must flow be before taxing is worth doing.
- **M32** — open item **O2**, the second-order condition, possibly decidable now that `ε` is
  explicit.

**Most likely failure:** M28 presumes `ν ∝ ΔQ` under proportional legs, and bundle 3 already
refuted the universal form on one-sided flow. **PR-REGION (`DOC:423`) is OPEN and is the
author's ruling**, not the prover's. Bundle at `control/aristotle/tax3/`, spec `RequestProject/TAX3_ADDENDUM.md`
(M25–M27). Three ALGEBRAIC claims, sent after the `Δt` route died:

- **M25 — LVR cancellation.** Under `DOC` Proposition 9's split and `(A1)`, does `π^LVR` factor
  out as a strictly positive common factor, leaving `Proposition 13`'s root invariant? If yes,
  adding the LVR channel to the objective is **futile by construction** and that work stops.
- **M26 — channel equivalence.** `∂ν/∂τ` via the flow route `(∂ν/∂ΔQ)(∂ΔQ/∂φ)(∂φ/∂τ)` instead of
  the hazard route `Ḡ·(∂λ/∂τ)`. Do they agree in sign, and does the flow route avoid needing
  `H2`? If yes, the controller's **direction** is free — no estimation, no clock ruling.
- **M27 — arb-side closure.** Does `∂ΔQ^ARB/∂φ` close in `(σ, φ, Δt, ε_{p/X})` with no free
  behavioural parameter? `ε_{p/X}` is declared **observable** at `DOC` Definition 14. If yes the
  empirical burden collapses to **benign flow only**.

Five standing bans written into the bundle: no Capponi-`κ`/`ε_{X/M}` identification (CES
embedding machine-refuted, `canon_Fcap_not_CES`); `η` is the **grid tilt**, not the trading-curve
share (`DOC:184`, and `κ_φ` depends on `ε_{X/M}` alone since `χ` cancels — this corrects a
memory that had `η` as the demand-substitution elasticity); `π^{\varphi}` ≠ `π^{\phi}`;
`Proposition 13`'s domain lines stay guarded; cite by declaration name AND file.
**Refutation counts as success** and is stated as such — both prior bundles returned refutations
that redirected the project.

**Do NOT run a parallel `continue` on this project.** On `OUT_OF_BUDGET`, a single
`aristotle continue` on the SAME project. Full UUIDs only; `aristotle show` streams and blocks —
use `aristotle list`.

**Two user rulings, 2026-08-09:**
1. **`Δt` instrument TERMINAL** — record and stop, no substitution. The `υ` precedent applied.
2. **Time base deferred to `FRM-03`** — `Ḡ`'s sign flips with it, so it is not a free choice. Phase 2, unexecuted. **`06B-01` is blocked on this and must not pre-empt it.**

**The binding constraint, now visible:** both routes to a controller need `sign(H2)` — Phase 6b's set-point through `Proposition 13`'s conjunct-2 antecedent, Phase 6a's on-chain loop through `NEC-05`/`NEC-07`'s loop direction (which also needs `H1`, undischarged on every branch). `H2` is not a Phase 6b problem Phase 6a routes around; it constrains the whole controller, and this verdict removes the one empirical route specified to settle it.

Next action: Phase 2 (`FRM-03`, the event clock) is now on the critical path for two independent reasons — the time base, and the two-clock defect in `λ_ARB`'s summand. Phase 1 still has no execution record and `NOT-05` still owes `O4`, which `06B-03` would hard-block on. Neither Phase 6a nor Phase 6b can deliver a signed controller until `H2` has a route.

**Open, carried:** `RESEARCH-REGISTER.md`'s MAJORs are unclosed — neither reviewer certified it (Reality Checker 7/20/6, Model QA 6/12/7); it was committed anyway so §5's ordering guarantee would bite, and that trade is recorded in its `## Review` and §5.0. One verification genuinely fails: Task 3's `00-3` sentinel post-dates the artifact by 10s because Tasks 2 and 3 interleaved — reported, not papered over; the substantive invariant holds and all three baselines are byte-identical.
