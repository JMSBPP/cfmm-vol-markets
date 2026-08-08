# Roadmap: MEV-Tax Set-Point Controller — Verified Design Spec

## Overview

This project does not build software. It adjudicates a derivation and ships **one document**:
the formal controller spec, grounded on theory and formal results. Per the user ruling of
2026-08-08 the entire EVM-feasibility track is out (moved to v2 intact), and the two
behavioral gains are stated as typed hypotheses rather than proved — so what remains is
narrower and cheaper than the eight-phase predecessor: find what is already settled on disk
(Phase 1), write the plant out entry by entry and choose a frame it can carry (Phase 2),
state the obligations in an idiom the Lean tree carries and run the free detectors (Phase 3),
take verdicts on well-posedness, the channel and the `τ↔λ` bridge behind a branch gate
(Phase 4), settle the boxed law and derive its correction (Phase 5), and consolidate
(Phase 6).

**Execution is sequential** (`parallelization: false`, a deliberate user choice) so an early
refutation halts downstream spend. Consequently the ordering rule is **cheapest decisive
check first**: Phase 1 is entirely reading artifacts that already exist, and it is capable of
settling several questions that the previous roadmap had queued behind three phases of
machinery.

**A refutation is a delivered result, not an abort.** Where an obligation refutes, the branch
routes to *salvage* — a corrected law, derived and verified — never to termination.

### What changed from the previous (8-phase) roadmap

| Change | Reason |
|---|---|
| **EVM track deleted** (old Phase 7 and `EVM-01`) | User ruling 2026-08-08: theory and the formal document only. `EVM-01a/01b/02/03/05/06` are preserved in `REQUIREMENTS.md` v2, not discarded. |
| **`FRM-05` (null-space `HF = 0`) survives, reclassified** | It is a control-theoretic question — does a disturbance-invariant controlled variable exist — and is reported with **no on-chain cost claim attached**. |
| **The `τ* = 1` headline refutation is DEAD** | `L(i_K) = L̄·ℓ(ξ,ι;i_K)` with `ℓ` geometry-invariant, and `ΔQ_v★` is in **vol-asset** L units (`UNITS_AND_SCALES.md:70`) while the pool's `L̄` is price-axis liquidity. Rule 9 is an identity on the vol axis and constrains nothing on the pool axis. The "`L` overload" is two assets, not one ambiguous symbol (`NOT-07`). |
| **`PRF-03` is no longer a proof bundle** | `∂L̄/∂π^φ > 0` and `Ḡ_(ν,λ_MEV) > 0` are LP-supply estimands observed from add/remove-liquidity events. They are named typed hypotheses; **neither is ever sent to Aristotle**. Magnitudes are `EST-01` (v2). This removed a whole phase's worth of work. |
| **8 phases → 6** | Derived from the surviving work, not compressed to a target. |

### Refutations that survive the ruling

These are the project's likely output and each is checkable by reading the pinned source:

1. **The direct monoid path.** `τ_MEV` reaches `φ_total` via the Rule 12 monoid, bypassing
   `ν` — visible in the source's own `∇φ` display at `SRC:56`, entry `(1−φ_X)(1−φ_M)`. P2's
   "no other path" clause is therefore still false.
2. **The box solves the wrong relation.** It solves `∂π̂^σ/∂τ_MEV = ΔQ_v★`, not the stated
   `π^σ ≡^R π̂^σ`; the `(σ²−σ_K²)⁺` factor is absent from the box.
3. **Two incompatible sections.** `(φ_M, φ_X, τ) ↦ φ_total` is a submersion `ℝ³→ℝ` with no
   inverse, so the step at `SRC:110` adds directional derivatives taken along different
   sections.

### Deviations from the researched build order (stated, not silent)

1. **`research/SUMMARY.md` is used as input, not as mandate, and parts of it are known
   wrong.** Its `τ*>1` / Rule-9 findings are superseded by the 2026-08-08 ruling. Any finding
   carried forward from it is re-verified at its cited line in Phase 1 before it is used.
2. **The "4 of 4 researchers converged" claim is not used to size any gate.** All four read a
   `PROJECT.md` that rewarded refutation — a shared prior, not independence. One vote analysed
   the wrong object (`π^σ`, which carries no `τ_MEV` dependence, instead of `π̂^σ`) and two
   researchers contradict each other on P2. The honest count is **two independent
   derivations, one restatement, one invalid**, and that is what Phase 1 records.
3. **`NOT-08` (the inventory sweep) is the first thing the project does.** Three normative
   on-disk artifacts were missed by four researchers and four planning documents. The sweep
   precedes every notation map, ledger and obligation.
4. **`PRF-05` (the `τ↔λ` bridge) joins P1 and P2 in one phase** rather than standing alone.
   With `PRF-03` demoted to a hypothesis, P5 would otherwise be a solo phase, and it shares
   the entire `τ → φ → ν` definitional payload with P2.
5. **`PRF-03` sits in Phase 3, not with the verdicts.** Its operative content is *which
   claims are excluded from the submission set* — which is exactly what Phase 3's protocol
   governs.
6. **Phase 1 carries ten requirements**, heavier than standard granularity would suggest.
   They are one capability (read what exists; close what is already closed) and they are the
   cheapest work in the project. Splitting them would put a document read behind a phase
   boundary, which is the specific defect this rewrite exists to fix.

### Open item for the user — the project has no defined failure condition

Every outcome in `PROJECT.md`, `REQUIREMENTS.md` and this roadmap is written as a success:
the law is proven, or it is refuted-with-witness, or it is corrected, or it is recorded as a
hypothesis. There is presently **no criterion under which this project would be judged to
have failed.** That is a real gap in the specification of the work and it is flagged here
rather than papered over. **This roadmap deliberately does not invent one** — it is routed to
the user via the gap register (`HND-01`, Phase 6, criterion 2).

### The proving route is an open decision, not an assumption

The previous roadmap asserted that zero steps of the proving pipeline run in this worktree
and hard-depended on the Lean4+Math peer. That dependency was never agreed: `list_peers` at
repo scope returns nothing, `CLAUDE.md` has no row for this track, and it never mentions
Aristotle. The user has since supplied an Aristotle API key to **this** session. The roadmap
is therefore written to be **route-agnostic**: `PRF-10`'s hand-off artifact must be
self-contained and valid whether submission happens here or via a peer, and `HND-03` requires
peer agreement to be *obtained and evidenced*, never assumed.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Ground Truth, Notation, and the Rulings Triage** - Everything already settled on disk is found and recorded before anything new is written
- [ ] **Phase 2: The Entrywise Plant and the Control Frame** - The `∂`-partition written out entry by entry, a frame it can actually carry, and the null-space test as theory
- [ ] **Phase 3: Obligation Protocol, Typed Hypotheses, and Cheap Detectors** - What must be true before one obligation is submitted — including the detectors that could refute for free
- [ ] **Phase 4: Verdicts — Well-Posedness, the Channel, the τ↔λ Bridge (BRANCH GATE)** - Three verdicts in one bundle, and the branch decision that routes the rest
- [ ] **Phase 5: The Set-Point Law — Verdict and Salvage** - A terminal verdict on the boxed `τ*_MEV` and, where it falls, a corrected law under a stated budget
- [ ] **Phase 6: The Formal Controller Document and Hand-off** - The deliverable, an honest gap register, and a hand-off with agreement obtained rather than assumed

## Phase Details

### Phase 1: Ground Truth, Notation, and the Rulings Triage
**Goal**: Every question that could make a proof be about the wrong object is closed from what is *already on disk*, before this project writes anything of its own — including the notation map, the unit ledger, and the review register that governs everything after.
**Depends on**: Nothing (first phase)
**Requirements**: NOT-01, NOT-02, NOT-03, NOT-05, NOT-06, NOT-07, NOT-08, NOT-09, HND-04, HND-05
**Success Criteria** (what must be TRUE):
  1. The inventory sweep of `evm-controller/spec/`, `evm-controller/notes/` and `plank/notes/` is complete, and its output names at minimum `plank/notes/UNITS_AND_SCALES.md`, `plank/notes/VOLATILITY_INSTRUMENTS_MEV.tex` (1063 lines, 29 numbered Definitions / 21 Theorems / 9 Propositions, defines `ι` = our `#_σ` at :212) and `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/ENTRY_POINT.md` (carries a correct boxed `∂φ/∂ν`) — each with a sha pin and a one-line statement of what it is normative *for*. `ENTRY_POINT.md` is git-tracked by the end of the phase (`git ls-files` returns it). The sweep's artifact is dated before every other artifact this project writes, and it records that `VOLATILITY_INSTRUMENTS_MEV.tex` is **not** a superset of `SRC` (zero hits for `u_ex`, `x_{t+1}`, `\widehat\pi`, `\frac{\partial`) so `SRC` remains the citation target — cited **by line against a pinned sha**, since it carries no numbered Definitions or Rules.
  2. The 13 blocking decisions are triaged into three named buckets, none left untriaged: **ALREADY ANSWERED ON DISK** (each with the `file:line` that answers it), **AGENT-ANSWERABLE** (each with the answer and the evidence), **NEEDS THE AUTHOR** (each with the question as posed). The triage records at minimum that `ν` vs `u` is answered at `DOC:620-622`, that Proposition 10 is DECIDED at `DOC:803`, and that the `π^φ` leg-pairing "collision" is an errata artifact — naming the four agreeing sources and the two dissenting ones. **Only the NEEDS-THE-AUTHOR bucket is put to the user**; the other two are closed by this phase.
  3. A notation map resolves each collision with the chosen reading *and* the rejected reading stated — `π^{\varphi}` (source: `π^{\phi} − π^{LVR}`; entry-point doc: the portfolio value function), `ν` vs `u`, leg pairing in `π^{\phi}`, and the `ΔQ_v★`/`ΔQ_υ` glyph collision (`DOC:672`, same `I_ord` slot). It records the two-axis liquidity distinction as **SETTLED**, quoting `L(i_K) = L̄·ℓ(ξ,ι;i_K)` with `ℓ` geometry-invariant and `UNITS_AND_SCALES.md:70` for `ΔQ_v★` being vol-asset L, and requiring every downstream use of `L` to name its axis. It states that `∂φ/∂ν` from `ENTRY_POINT.md` enters the channel's factor list as a **determinate, strictly positive** factor. No symbol appears in any artifact this project writes that is not in the source or in this map with a stated reason.
  4. One identifier scheme replaces the four research taxonomies (`P1–P4`/`C-P#-#`/`A#`, `B#`/`M#`/`N#`/`R#`, `FINDING A/B`/`W#`), and **each carried-over finding is re-verified at its cited line against the pinned source sha** — findings that no longer verify are dropped with the reason recorded, and findings superseded by the 2026-08-08 ruling (the Rule-9 `τ*=1` route, the `∂L(i_K)/∂π^φ ≡ 0` channel-death claim) are marked SUPERSEDED, not carried. The record states the honest independence count for P2 — two independent derivations, one restatement, one invalid (it analysed `π^σ`, which carries no `τ_MEV` dependence, rather than `π̂^σ`) — and never "4 of 4". `research/v2-controller/LEAN-MAP.md` and `EVM-CONTROL-PRIMITIVES-MAP.md` each carry a do-not-cite header naming the specific stale claim that makes them unusable.
  5. The unit ledger exists as a **proposed diff extending** `UNITS_AND_SCALES.md` at a pinned sha — adding exactly the symbols it lacks (`ν`, `τ_MEV`, `π^l`, `π^φ`, `π^LVR`, `ΔQ_υ`) and re-deriving nothing the table already carries — routed to `ul2inqpl` as a message, with `git -C plank status` unchanged by this project. A review register exists and is honest about its own history: the founding artifacts (`b5f5e82`, `9658375`, `d3b226a`) appear as **retroactive** first entries stating that they were committed *before* their two-step review ran, with that review's findings listed as entries against them; every artifact after them shows a review date preceding its commit date.
**Plans**: 5 plans, 5 waves (sequential; `parallelization: false`)
- [ ] `01-01-PLAN.md` — Inventory sweep, pin register, `ENTRY_POINT.md` git-tracked (`NOT-08`)
- [ ] `01-02-PLAN.md` — The 13 blocking decisions triaged into three buckets; only NEEDS-THE-AUTHOR goes to the user (`NOT-01`) — has a checkpoint
- [ ] `01-03-PLAN.md` — Notation map: four collisions, two-axis liquidity SETTLED, `∂φ/∂ν` determinate, symbol register (`NOT-02`, `NOT-06`, `NOT-07`, `NOT-09`)
- [ ] `01-04-PLAN.md` — Finding register: one `CF-NN` scheme, every carried finding re-verified, 4 SUPERSEDED, do-not-cite ruling (`NOT-03`, `HND-04`)
- [ ] `01-05-PLAN.md` — Unit ledger extension as a proposed diff routed to `ul2inqpl`; review register with retroactive founding entries (`NOT-05`, `HND-05`)

### Phase 2: The Entrywise Plant and the Control Frame
**Goal**: The plant exists on paper entry by entry, a control frame is selected that the actual partition can carry (and justified against the alternatives), and the null-space test is run as a control-theoretic result.
**Depends on**: Phase 1
**Requirements**: NOT-04, FRM-01, FRM-02, FRM-03, FRM-04, FRM-05
**Success Criteria** (what must be TRUE):
  1. Every entry of the `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is written out from the pinned source and classified as a constant, a Jacobian entry, or structurally zero — with an explicit yes-or-no on three questions: whether `∂_(t+1,t)` is the zero matrix, whether `u_en = [τ_MEV, φ_M, φ_X]^T` contains entries that are not actuators (`φ_M ≡ φ̄_M` frozen; `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` a schedule, not a free input), and whether the `π^σ` row of `∂_(y,u)` is structurally zero. **No artifact anywhere asserts the plant is non-degenerate before this table exists.**
  2. The selected frame is named, and every excluded alternative carries its own stated reason: LQR/LQG/servo tracking, root locus, Bode/Nyquist, PID, the Gramian/Kalman rank test as a well-posedness tool, and the "static output feedback" name-collision. The selection **cites criterion 1's table by entry**: if `∂_(t+1,t)` is structurally zero the document says so and re-scopes to static inversion under uncertainty rather than importing dynamic-control machinery over a memoryless map. The FRAME-vs-PITFALLS tension on underactuation (`H = [1,−1]` already-resolved vs. entrywise-check-first) is recorded with which side the table's evidence supports.
  3. A well-posedness checklist for a **set-point** (as distinct from a regulator) is enumerated as numbered conditions, each of P1/P2/P4/P5 is mapped to the specific conditions it must satisfy, and `e^σ` is declared an equality constraint rather than an objective so a regulator cannot creep in. The event-clock question is item zero of that checklist and is resolved **or** declared OPEN — either way the document states whether `t` indexes swaps or blocks, states whether event-averaged `ΔQ_M, ΔQ_X` may be combined with time-averaged `π^LVR·Δt, σ², λ`, writes out the PASTA/ASTA argument for why the combination is not free in a CFMM, and — if OPEN — names the downstream results it puts at risk.
  4. Every literature citation entering the document is either primary-verified (via the arxiv MCP, with the identifier recorded) or carries an explicit `UNVERIFIED` tag. The verified-or-tagged set covers the **≈13** not-primary-verified items, not the 5 originally flagged: the recommendation's own four pillars (Skogestad 2000, Mason 1953, Davis 1984, Wolff 1982) sit in the same web-search tier as the flagged failures and are re-checked, and the five Carr–Madan / Breeden–Litzenberger invocations either acquire a citation or are tagged. **No `FRAME.md` HIGH tag is inherited without re-check.**
  5. The null-space test `HF = 0` (Alstad & Skogestad 2007) has **run** over an explicitly partitioned disturbance vector separating trade-specific components (`ΔQ_M`, `ΔQ_X`) from slow-moving ones (`σ²`, `Θ_φ`), the partition used is stated, and the result is recorded as exists / does-not-exist with either the `H` it produces or the rank obstruction that prevents it. It is reported as **theory only**: no on-chain cost, gas, or storage claim appears anywhere in the document.
**Plans**: TBD

### Phase 3: Obligation Protocol, Typed Hypotheses, and Cheap Detectors
**Goal**: Everything that must be true before a single obligation is submitted — the excluded hypotheses are named, the obligations are stated in an idiom the Lean tree actually carries, the freeze/diff/gate protocol exists and has been exercised, and the free detectors have already been run.
**Depends on**: Phase 2
**Requirements**: PRF-03, PRF-06, PRF-07, PRF-08, PRF-09, PRF-10
**Success Criteria** (what must be TRUE):
  1. `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV` and `∂L̄/∂π^φ` each appear as an **explicitly named typed hypothesis** carrying its estimand, its sign convention, and its observation channel (add/remove-liquidity events, with the emitting event named). The Aristotle submission set is enumerated in one place and **neither hypothesis appears in it**; each carries a NOT-SUBMITTED marker with the ruling that makes it an estimand rather than a proposition, and `EST-01` (v2) is named as the track that measures the magnitudes.
  2. Each obligation is stated in the tree's native `Monotone` / `StrictAnti` / `ConvexOn` idiom wherever a sign or ordering claim suffices. Where derivative infrastructure is genuinely needed, the gap is stated **narrowly and correctly**: no derivative lemmas exist for the five named schedule functions (`logistic`, `sigmoidR`, `multiFee`, `probOr`, `ptrade`), and the cost of building them is priced against `CapponiEmbed.lean` as in-tree precedent (132 `HasDerivAt`, 128 `deriv`, 19 `Differentiable` — **all three are `grep -c` LINE counts, not occurrence counts** (`grep -o '\bderiv\b' | wc -l` gives 306; both are correct, the unit is what differs — state the method with any count), including `HasDerivAt.div` and `Real.hasDerivAt_rpow_const`). The false claim that the tree is devoid of differential-calculus infrastructure appears nowhere.
  3. The cheap detectors have **run** and their outputs are recorded as findings, not scheduled: the back-substitution check states whether the boxed form actually satisfies the relation Phase 1's triage says it solves, and the numerical harness reports `τ*`'s sign and range **as a function of the named hypothesis set**, with the hypotheses enumerated beside every number. A sign or range violation whose value depends on a hypothesis is recorded as `HYPOTHESIS-DEPENDENT` and **may not be logged as a refutation**.
  4. The freeze protocol is written and has been **exercised once end-to-end on a real obligation**: byte-frozen at submission with a **section-scoped** sha (never a whole-file hash of a concurrently edited document), with the byte-diff procedure against the returned statement written down and dry-run.
  5. A six-point integration gate is written as a stated precondition on every later landing — statement byte-diff (an added hypothesis is a disclosed narrowing and is reported; a renamed-but-weaker theorem is a MISS), `#print axioms` sweep, zero `sorry`/`admit`, proof-body triage (a `ring`/`simp` one-liner for a claim described as substantive is flagged, not counted), dependency byte-identity, provenance. The PROOF-REQUEST template is self-contained and **route-agnostic**: it records the submission route as a decision (this session's Aristotle key vs. the Lean4+Math peer) and is valid under either, with the module import closure re-derived from `lean/lakefile.toml` at assembly time rather than from the do-not-cite `LEAN-MAP.md`.
**Plans**: TBD

### Phase 4: Verdicts — Well-Posedness, the Channel, the τ↔λ Bridge (BRANCH GATE)
**Goal**: Three verdicts requested as one bundle because they share the entire plant and `τ → φ → ν` definitional payload, plus the recorded branch decision that routes the rest of the project.
**Depends on**: Phase 3
**Requirements**: PRF-01, PRF-02, PRF-05
**Success Criteria** (what must be TRUE):
  1. `PRF-01` carries a terminal verdict (`PROVEN` / `CORRECTED` / `REFUTED` / `OPEN`-with-named-hypothesis) on whether the `∂`-partition is well-posed over event time and whether set-point optimization is legitimate with `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j)` frozen. The freezing appears as a **declared modelling assumption**, and the record states plainly that the cited "`(β,γ)` do not control `λ_MEV`" theorem does not exist and that `MevOptimization.lean:465` (`mevMulti_mono_beta`) proves monotone *increase* in `β`.
  2. `PRF-02` carries a terminal verdict on the "no other path" clause and **adjudicates the direct monoid path by name**: the source's own `∇φ` display at `SRC:56` carries the entry `(1−φ_X)(1−φ_M)`, so `τ_MEV` reaches `φ_total` without passing through `ν`. If the clause falls, the counterexample is exhibited as a concrete second path with its factors written out. If a restricted form survives, the restriction is stated and checked for vacuity — a restriction that holds only on a measure-zero or empty branch is recorded as vacuous, not as a survival.
  3. `PRF-05` carries a verdict on whether `∂ν/∂λ_MEV` may stand in for `∂ν/∂τ_MEV`, as a first-class obligation rather than an implicit step. If it may not, every downstream statement uses the written-out composition `Ḡ_(ν,λ_MEV) · ∂λ_MEV/∂τ_MEV` and no new symbol is minted for it. **Any route that composes landed declarations by name is accompanied by a written closure check** demonstrating the composition actually closes — pointwise-vs-hazard-sum and joint-vs-single-argument mismatches named and excluded — and no `ring`-grade identity (e.g. `mevTotal_eq_arb_of_sandwich_zero`, which is `lamARB + 0 = lamARB`) is counted as a substantive step.
  4. Each verdict passes Phase 3's integration gate before it is treated as landed, and the ledger records per verdict: the landed declaration names, every added hypothesis with its economic meaning, every narrowing, the axiom-sweep result, build evidence, and the submission UUIDs — or, where a verdict was settled by document argument rather than a machine proof, that fact and the argument's location, so a prose verdict can never be mistaken for a machine one.
  5. **The branch gate is executed and the branch is recorded in writing before Phase 5 begins.** *P2 upheld (possibly restricted)* ⟹ Phase 5 adjudicates the boxed form as submitted. *P2 refuted* ⟹ Phase 5's `PRF-04` is settled by a recorded dependency refutation naming the voiding result instead of a spent bundle, and salvage becomes the phase's main work. **Neither branch aborts the project**; both reach Phase 6, and a refutation with a witness satisfies the Core Value.
**Plans**: TBD

### Phase 5: The Set-Point Law — Verdict and Salvage
**Goal**: A terminal verdict on the boxed `τ*_MEV` and, where it falls, a corrected set-point law derived under the Phase 2 frame that carries its own verdict — under a budget declared before the first submission. This phase delivers the Core Value.
**Depends on**: Phase 4
**Requirements**: PRF-04, SAL-01, SAL-02, SAL-03, SAL-04, SAL-05
**Success Criteria** (what must be TRUE):
  1. `PRF-04` carries a terminal verdict and is never left OPEN. The ledger names **which relation the box was adjudicated against** — level `π^σ ≡^R π̂^σ`, vega-matching, or as-written `∂π̂^σ/∂τ_MEV = ΔQ_v★` — with the rejected alternates named, and states explicitly whether the `(σ²−σ_K²)⁺` payoff factor is present in the boxed form. Where Phase 4 voided the premise, the verdict is a recorded dependency refutation naming the voiding result rather than a spent bundle.
  2. Every refuted obligation carries its **specific defect**: the step, the line (cited against the pinned sha, since `SRC` has no numbered Definitions or Rules), and an error class drawn from a stated enumeration. Where they survive re-check, this includes the two-incompatible-sections defect at `SRC:110` — `(φ_M, φ_X, τ) ↦ φ_total` is a submersion `ℝ³→ℝ` with no inverse, so derivatives along different sections are being summed — and the missing `(σ²−σ_K²)⁺` factor. Where nothing refuted, "no defects" is recorded explicitly rather than left blank.
  3. A corrected set-point law is derived under the Phase 2 frame, addressing the recorded defects, and is stated over an **explicit domain** carrying the branch structure the kinks force: the `(·)⁺` kink at the strike, the OTM branch (stated as a degeneracy result — no interior solution exists there — not as an omission), and the `min(·)` funded cap. If the law is implicit rather than closed, existence, uniqueness and monotonicity are stated as named obligations. Every assumption it rests on is declared **as an assumption**, with a real Lean declaration name and file wherever a prior result is cited, and no assumption is justified by citing a theorem that does not exist.
  4. The corrected law is itself submitted through the same freeze-and-gate cycle and carries its own verdict — a corrected law asserted but unverified does not satisfy this phase — **or**, if the declared budget is exhausted first, it ships with an explicit `VERIFICATION OUTSTANDING` verdict naming exactly what was submitted, what returned, and what remains, and that residual is carried into `HND-01`.
  5. **The salvage budget is declared before the first submission and its escalation trigger is recorded as fired or not fired.** The corrected law's form is unknown until criterion 1 lands, so its proof burden is unknown and an open-ended commitment would be dishonest: the phase states a budget (submission rounds and/or wall-clock) up front and, on exhaustion, escalates to the user with the residual obligation stated rather than continuing.
**Plans**: TBD

### Phase 6: The Formal Controller Document and Hand-off
**Goal**: The project's single deliverable — the formal controller document — plus an honest gap register and a hand-off whose peer agreement is obtained rather than assumed.
**Depends on**: Phase 5
**Requirements**: HND-01, HND-02, HND-03
**Success Criteria** (what must be TRUE):
  1. The formal controller document exists and integrates frame, entrywise plant, verdicts, typed hypotheses and salvage, written last, with each section delegating detail to its owning document by an explicit `> Authoritative detail:` pointer and duplicating no derivation. **Every claim in it resolves to exactly one of: a verdict, a named typed hypothesis, or a gap-register entry** — a reader can trace any statement to its status without leaving the document.
  2. The gap register lists every open item with severity and disposition (in-scope / deferred / needs-the-user) and carries at minimum: the event-clock question if left OPEN, every obligation left as a named hypothesis, the `(β_j,γ_j)`-frozen assumption and its missing justification, the `FRM-05` null-space result's consequences, any `VERIFICATION OUTSTANDING` residual from Phase 5, and **the project's undefined failure condition** — recorded as an open item addressed to the user, stating that every outcome is presently written as a success and that no criterion exists under which this project would be judged to have failed. The register **does not invent one**.
  3. The hand-off names each deferred track — `EVM-01a`, `EVM-01b`, `EVM-02`, `EVM-03`, `EVM-05`, `EVM-06` and `EST-01` — with what it inherits from this project, what it still needs, and its owning session. **Peer agreement is obtained and evidenced**: a sent message with a reply, or a `CLAUDE.md` row landed for this track. Where agreement was not obtained, the register says so plainly — silence is recorded as silence, never as consent.
  4. Findings against peer-owned documents (the `SRC` errata, the misquoted `(β,γ)` theorem, the unit-ledger extension) are routed by peer message plus a gap-register entry and never fixed in the peer's tree: no diff produced by this project touches the repo-root `.planning/`, `src/`, `test/`, `plank/` or `lean4-spec/`, verifiable by `git status` across those worktrees.
  5. Every artifact this project wrote under `spec/` appears in the review register having passed the two-step review (Reality Checker + one named specialist, in parallel) **before** its commit, with a review date preceding its commit date — and the founding artifacts remain marked as retroactive first entries rather than being back-dated into compliance.
**Plans**: TBD

## Branch Gate — explicit semantics

The single branch gate lives at the end of **Phase 4** and turns on `PRF-02` (the "no other
path" clause). It is **not** sized on the discredited "4 of 4 researchers" count; it is sized
on one checkable fact: the source's own `∇φ` display at `SRC:56` exhibits the entry
`(1−φ_X)(1−φ_M)`.

| Branch | Phase 5 | Phase 6 |
|--------|---------|---------|
| **P2 upheld** (possibly restricted, restriction checked for vacuity) | `PRF-04` adjudicated on a submitted bundle; salvage engages only against defects actually found | Unchanged |
| **P2 REFUTED** | `PRF-04` settled by recorded dependency refutation (no bundle spent); `SAL-01`…`SAL-05` become the phase's main work, under the declared budget | Unchanged; the refutation and its witness are the headline deliverable |

A secondary **escalation trigger** sits inside Phase 5 (criterion 5): if the salvage budget is
exhausted, the residual is escalated to the user rather than pursued open-endedly.

**Neither gate can terminate the project.** A refutation routes to salvage; both branches
reach Phase 6.

## Progress

**Execution Order:** Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 (sequential;
`parallelization: false`).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Ground Truth, Notation, Rulings Triage | 0/5 | Planned | - |
| 2. Entrywise Plant and Control Frame | 0/TBD | Not started | - |
| 3. Obligation Protocol and Cheap Detectors | 0/TBD | Not started | - |
| 4. Verdicts — P1, P2, P5 (BRANCH GATE) | 0/TBD | Not started | - |
| 5. The Set-Point Law — Verdict and Salvage | 0/TBD | Not started | - |
| 6. Formal Controller Document and Hand-off | 0/TBD | Not started | - |

## Requirement Coverage

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | NOT-01, NOT-02, NOT-03, NOT-05, NOT-06, NOT-07, NOT-08, NOT-09, HND-04, HND-05 | 10 |
| 2 | NOT-04, FRM-01, FRM-02, FRM-03, FRM-04, FRM-05 | 6 |
| 3 | PRF-03, PRF-06, PRF-07, PRF-08, PRF-09, PRF-10 | 6 |
| 4 | PRF-01, PRF-02, PRF-05 | 3 |
| 5 | PRF-04, SAL-01, SAL-02, SAL-03, SAL-04, SAL-05 | 6 |
| 6 | HND-01, HND-02, HND-03 | 3 |
| **Total** | | **34 / 34** |

Verified programmatically: the set of IDs defined in `REQUIREMENTS.md` v1 equals the set
mapped above (34 = FRM 5 + NOT 9 + PRF 10 + SAL 5 + HND 5). No orphans; no requirement mapped
to more than one phase. The v2 `EVM-*` and `EST-01` items are deliberately **not** mapped —
they are out of scope for this milestone.

## Standing constraints (apply to every phase)

- All GSD commands run with `--cwd control`. The repo-root `.planning/` is read-only.
- Notation is binding. No symbol is minted without a user ruling, in artifacts *and* in
  Aristotle prompts. Curvature is `κ_φ` (never `χ`); `λ̃` is the incidence operator vs plain-`λ`
  hazard; probabilities are `ℙ_event`.
- `SRC` (`notes/VOLATILITY_INTRUMENTS_MEV.md`) is **tracked-and-dirty**, not uncommitted, and
  carries no numbered Definitions or Rules — cite it by line against a pinned sha. `DOC`
  (`plank/notes/VOLATILITY_INSTRUMENTS.md`) is cited by numbered item plus sha.
- **Never prescribe a composition of named Lean declarations without a written check that it
  closes.** The predecessor roadmap prescribed a three-declaration route that does not (a
  pointwise result composed against a hazard sum, and a single-argument monotonicity applied to
  a jointly-acting `probOr`). A route that has not been checked is a hypothesis, not a plan.
- Every artifact passes the two-step review (Reality Checker + one specialist, in parallel)
  before it is committed or executed — never deferred.
- Every prior-result citation carries a real Lean declaration name and file. No `ring`/`simp`
  bridge identity is presented as a substantive result.
- Aristotle: full UUIDs only; never parallel `continue` on one project; on `OUT_OF_BUDGET` a
  single `continue` on the same project; never integrate a `sorry`-carrying partial and never
  hand-prove the gap.
- No `.plk` or `.sol` artifact is produced anywhere, and no on-chain cost claim is attached to
  any result — the EVM track is v2.

---
*Roadmap created: 2026-08-08*
*Rewritten: 2026-08-08 — 8 phases → 6 after the scope-narrowing ruling and the two-step review*
