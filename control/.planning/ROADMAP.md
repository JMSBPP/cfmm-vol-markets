# Roadmap: MEV-Tax Set-Point Controller — Verified Design Spec

> **RE-BASELINED 2026-08-08.** The previous 6-phase roadmap described a sequence that did not
> happen. Phases 4 and 5 were **delivered out of order** by two Aristotle bundles submitted
> directly, before Phases 1–3's machinery ran. Phase 1 is planned but unexecuted, Phase 2 is
> partial, Phase 3 was performed ad hoc without its artifacts, Phase 6 is in progress, and a
> new requirement category (**Estimation**, `EST-01`…`EST-05`) was promoted from v2. This
> document is rewritten against what actually happened, not against what was planned.
>
> **AMENDED 2026-08-09 — Phase 6 splits into 6a and 6b, and 6a runs first.** Two categories
> were added: **Non-Estimated Control** (`NEC-01`…`NEC-06`, promoting v2 `CTL-01`) and
> **Literature & Venue Research** (`LIT-01`…`LIT-04`). The motive is a structural defect in the
> previous roadmap: every branch made `Ḡ = ∂ν/∂λ_MEV` load-bearing, so an `EST-03`
> "not identified" verdict shipped a verdict with **no controller**. Since `ν` and `λ_MEV` are
> both protocol state, a loop can close on the FOC residual without forming `Ḡ` at all — and
> the estimation had, separately, **no research requirement, no named venue, and 14 unread
> PDFs**. **The free-option premise was then REFUTED at the review gate on the same day** —
> the FOC residual is affine in `Ḡ`, so no on-chain loop escapes it; `EST-04`'s proposed
> demotion is **withdrawn** and Phase 6a is re-scoped to on-chain fixed-point iteration of the
> `Ḡ`-dependent law. Requirement count 40 → 58 (the previously recorded 39 was an arithmetic
> slip carried in **both** the summary line and this file's coverage table; `NOT-*` has ten
> members, not nine). Execution order **1 → 2 → 3 → 6a → 6b → 7**.

## Overview

This project does not build software. It adjudicates a derivation and ships **one document**:
the formal controller spec, grounded on theory and formal results.

The project's headline result is **already in hand**. The boxed `τ*_MEV` was audited factor by
factor and **refuted**, and a corrected law was derived and machine-verified in its place:

```
τ*_MEV = 1 + (1 − φ_X) / ( (∂φ/∂ν)(∂ν/∂τ_MEV) )
```

**stated with a SIGNED denominator.** This form is primary. The frequently-quoted
`τ* = 1 − (1−φ_X)/|(∂φ/∂ν)(∂ν/∂τ_MEV)|` is the equivalent form *conditional on the M21 signs*
(`∂φ/∂ν > 0`, `∂ν/∂τ_MEV < 0`); the absolute value silently embeds the sign result and **must
never be quoted as the theorem.** The law is **implicit, not closed** — `φ_X`, `∂φ/∂ν` and
`∂ν/∂τ_MEV` are all evaluated at `ν(τ*)`. Domain: `τ* < 1` always; `τ* > 0` iff the gate
dominates.

What therefore remains is (a) the ground-truth and notation work the delivered bundles ran
*ahead of*, (b) the plant/frame work that is still partial, (c) the verification protocol
ratified retroactively against the two landed bundles — which is where the unverified
`#print axioms` claim is discharged, (d) **the estimation of `Ḡ = ∂ν/∂λ_MEV`**, the only
empirical object in the corrected law and simultaneously the test of `H2` — now preceded by
(d′) **the on-chain route**: what a fixed-point iteration of the law costs and requires. The
route was proposed as a controller needing **no** estimated parameter — `λ_ARB(t) = Σ_{s<t}(·)`
is predetermined and its arguments are protocol state — but that premise was **refuted at the
review gate**: the FOC residual is affine in `Ḡ`, so evaluating it *is* evaluating `Ḡ`. The
phase survives with a narrower promise. Then (e) the document itself.

**Execution is sequential** (`parallelization: false`, a deliberate user choice). The
remaining execution order is **1 → 2 → 3 → 6a → 6b → 7**; Phases 4 and 5 keep their numbers because
their requirement mappings and evidence are recorded against them, and renumbering them would
destroy the audit trail.

### What actually happened, versus what the previous roadmap planned

| Phase | Planned | Actual |
|---|---|---|
| 1 — Ground truth, notation, rulings triage | Runs first | **PLANNED, NOT EXECUTED.** Five plans exist on disk, through two full two-step review rounds plus a third refresh against the re-pinned source. Staged, uncommitted, ready to run. |
| 2 — Entrywise plant and control frame | Runs second | **PARTIAL.** The frame research exists (`.planning/research/FRAME.md`, `PITFALLS.md`, `ARCHITECTURE.md`, `CLAIMS.md`, `SUMMARY.md`). The entrywise `∂`-partition (`NOT-04`) and the null-space test (`FRM-05`) are **undone**. |
| 3 — Obligation protocol, typed hypotheses, cheap detectors | Runs third, gates all submissions | **DONE AD HOC.** `H1_dLbar_dpiPhi_pos` / `H2_dnu_dlamMEV_pos` landed as typed hypotheses; the freeze / gate / PROOF-REQUEST discipline was applied **by hand** via `spec/TAX_ADDENDUM.md` and `spec/TAX2_ADDENDUM.md`. The written protocol does not exist and **`PRF-09`'s detectors never ran.** |
| 4 — Verdicts (P1, P2, P5) + BRANCH GATE | Runs fourth, after 1–3 | **DELIVERED** by Bundle 1, ahead of 1–3. Branch gate fired: **P2 REFUTED**. |
| 5 — The set-point law: verdict and salvage | Runs fifth | **DELIVERED** by Bundle 2, ahead of 1–3. Salvage was the main work, exactly as the P2-REFUTED branch prescribed. |
| 6 — *(was)* Formal document and hand-off | Runs last | **Renumbered to Phase 7.** Its `SRC` restructure is in progress (`Convention 7`, `Definitions 32–35`, `Rule 13`), PR #22 → `develop` is open carrying everything. |
| **6b — Estimation of `Ḡ`** | did not exist (v2) | **Promoted to v1** on 2026-08-08. Design approved: `control/spec/ECONOMETRICS-DESIGN.md`. **Split from Phase 6 and given the research it never had** on 2026-08-09 (`LIT-01`…`LIT-04`). |
| **6a — On-chain fixed-point iteration (NEW)** | did not exist (v2 `CTL-01`) | **Promoted to v1** on 2026-08-09 and ordered **ahead of** the estimation. Proposed as closing the single point of failure; **the premise was refuted at the review gate the same day** and the phase re-scoped. The single point of failure **remains**. |

### The delivered result, in evidence

**Bundle 1** — `control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean`,
855 lines, 42 declarations, blocks M11–M18 of `spec/TAX_ADDENDUM.md`. Delivers `PRF-01`,
`PRF-02`, `PRF-05`:

| Declaration | Line | What it settles |
|---|---|---|
| `Theorem29_monoid_path_is_direct` | :213 | `τ_MEV` reaches the fee **directly** through the Rule 12 monoid, bypassing `ν`. |
| `Corollary29_five_factor_product_not_total_derivative` | :239 | The five-factor "no other path" identity is **REFUTED with witness**. |
| `Theorem30_composed_fee_submersion_section_sum_ill_posed` | :367 | `(φ_M, φ_X, τ) ↦ φ_total` is a submersion `ℝ³→ℝ`; the section sum at `SRC:110` is **ill-posed**. |
| `Theorem32_hazard_strictAntiOn_tau` | :702 | NEW lemma — the hazard is strictly antitone in `τ`. This is what corrects the `∂ν/∂τ` sign. |
| `M18_axis_error_refuted` | :809 | The ladder-bracket axis error. |

**Bundle 2** — `control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean`,
1130 lines, 54 declarations, blocks M19–M24 of `spec/TAX2_ADDENDUM.md`. Delivers `PRF-04` and
`SAL-01`…`SAL-05`: the M24 per-factor audit (`Verdict`, `BoxFactor`, `auditTable`,
`Proposition16_audit_justification`) and the corrected law (`Proposition16_corrected_law`,
:1054), with `Theorem34_opposed_signs`, `Theorem36_no_interior_root_off_the_band` and the
`Proposition15_*` second-order family.

**The M24 audit verdicts, verbatim from `auditTable`:**

| Factor of the boxed law | Verdict |
|---|---|
| leading `1 −` | **SURVIVES** (as the shape of the corrected law, for a different reason) |
| `1/ΔQ_v★` (normalizer) | **SPURIOUS** |
| `[Σ_{i_K} π^l ∂L(i_K)/∂π^φ]` (ladder bracket) | **SPURIOUS** |
| `[ΔQ_M/(1−φ_X) + p·ΔQ_X/(1−φ_M)]` (fee-Jacobian bracket) | **ILL-POSED** |
| `∂φ/∂ν` | **SURVIVES** (same form and sign, relocated into the denominator) |
| `∂ν/∂τ_MEV` | **SIGN CORRECTED** |
| `(1−φ_M)(1−φ_X)` — the direct monoid path | **MISSING** |
| `(1−φ_M)(1−τ_MEV)` — the monoid Jacobian on the gate path | **MISSING** |
| self-reference of `τ*_MEV` on the right | **MISSING** |

Both bundles: **0 `sorry`** (verified: `grep -c sorry` returns 0 on each), 0 axioms declared,
dependency files byte-identical. **`#print axioms` is NOT independently verified** — that
needs a Mathlib build and is carried as an open item, discharged in Phase 3.

### The branch gate fired: P2 REFUTED

The single branch gate lived at the end of Phase 4 and turned on `PRF-02`. It **fired on the
REFUTED branch**: `Corollary29_five_factor_product_not_total_derivative` exhibits the
counterexample, and the direct monoid path is exhibited by name at `SRC:56` / `Definition 35`
as the entry `(1−φ_X)(1−φ_M)`. Per the branch table, `SAL-01`…`SAL-05` became Phase 5's main
work — which is what Bundle 2 delivered. **The gate did not terminate the project**, as
designed. It is recorded here as FIRED and is not re-run.

### Open items carried explicitly (not buried)

These are the project's live liabilities. Each is routed to a phase and appears again in the
Phase 7 gap register.

| # | Open item | Routed to |
|---|---|---|
| **O1** | **`#print axioms` is unverified on both bundles.** Axiom-cleanliness is asserted from the absence of `axiom` declarations and 0 `sorry`, not from a sweep. A Mathlib build is required. Until it runs, "axiom-clean" is a claim, not a check. | Phase 3 (`PRF-08`) |
| **O2** | **The FOC root is NOT established to be the minimiser.** `Proposition15_level_reading_second_order_undetermined` (:823) exhibits the undetermination. `Proposition15_single_crossing_gives_minimum` (:890) would settle it, **but single crossing from below is unproved.** Any use of `τ*` as a minimiser rests on this. | Phase 7 gap register; load-bearing for Phase 6b (`EST-02`, `EST-05`) **and for Phase 6a (`NEC-05`)**, where a gradient loop's stationary point inherits exactly this undetermination |
| **O3** | **`φ_X` carries `ν`-dependence** (`DOC` Definition 18 — the sigmoid gate takes both `σ` and `ν`), but `Rule 13` at `SRC:69` writes `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` with **no `ν` argument**. Rule 13's signature may be incomplete, and if so every downstream `∂φ_X/∂·` is taken along the wrong section. | Phase 1 (notation map) → Phase 2 (entrywise table) |
| **O4** | **`σ` versus `σ²` units.** `DOC` Definition 18's sigmoid argument is `σ(i(t))`; the plant's `u_ex` carries `σ²(i(t))`. `Θ_φ`'s centers live in σ-units, the disturbance in σ²-units. A regression that mixes them silently is wrong. | Phase 1 (`NOT-05` units ledger) → Phase 6a (`NEC-01`, the accumulator's summands) → Phase 6b |
| **O5** | **The project has no defined failure condition.** Every outcome in `PROJECT.md`, `REQUIREMENTS.md` and this roadmap is written as a success — proven, or refuted-with-witness, or corrected, or recorded as a hypothesis. There is **no criterion under which this project would be judged to have failed.** This roadmap deliberately **does not invent one**; it is routed to the user. | Phase 7 (`HND-01`) |

### Deviations from the researched build order (stated, not silent)

1. **The delivered work inverted the intended dependency order.** Bundles 1 and 2 were
   submitted before the notation map (`NOT-02`), the units ledger (`NOT-05`), the symbol
   register (`NOT-06`) and the entrywise plant table (`NOT-04`) existed. Consequently
   `Convention 7`, `Definitions 32–35`, `Rule 13` and every Lean identifier in the two bundles
   were **minted ahead of the register that governs minting**. Phase 1 therefore acquires a
   retroactive reconciliation burden it did not have before, and Phase 2's entrywise table is
   now a **check against** `Definition 32`/`34` rather than a fresh construction.
2. **Phase 3 is now retro-ratification, not gate-keeping.** Its original function — gate every
   submission before it happens — is unrecoverable for the two landed bundles. It is
   re-scoped to: write the protocol, run the gate **retroactively** on both bundles (which is
   where O1 is discharged), and run the detectors that never ran. This is weaker than the
   original intent, and the roadmap says so rather than pretending the gate held.
3. **The old Phase 6 is renumbered to Phase 7** so that the new Estimation phase can take the
   number 6 and the remaining execution order stays numerically monotone
   (1 → 2 → 3 → 6a → 6b → 7). No plan directory exists for either, so nothing on disk is orphaned.
   Phases 4 and 5 keep their numbers **despite being delivered out of order** — their evidence
   is recorded against those numbers.
4. **Decision #10 (`Δt` exogenous or endogenous) is DEFERRED to Phase 6b**, to be judged by the
   structural-econometrics discipline rather than settled in the doc layer. It is **NOT
   closed** and must not be marked resolved anywhere.
5. **`research/SUMMARY.md` remains input, not mandate, and parts of it are known wrong.** Its
   `τ*>1` / Rule-9 findings are superseded by the 2026-08-08 ruling. Any carried finding is
   re-verified at its cited line in Phase 1.
6. **The "4 of 4 researchers converged" claim sizes nothing.** The honest count on P2 is two
   independent derivations, one restatement, one invalid. Moot for the gate itself, which has
   already fired on machine evidence rather than on a vote.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Ground Truth, Notation, and the Rulings Triage** - Everything already settled on disk is found and recorded, and the symbols the two delivered bundles minted ahead of the register are reconciled into it
- [ ] **Phase 2: The Entrywise Plant and the Control Frame** - The `∂`-partition written out entry by entry and checked against the landed `Definition 32`/`34`, a frame it can actually carry, and the null-space test as theory
- [ ] **Phase 3: The Verification Protocol, Ratified Retroactively** - The protocol written, the gate run after the fact on both landed bundles (where `#print axioms` is finally checked), and the detectors that never ran
- [x] **Phase 4: Verdicts — Well-Posedness, the Channel, the τ↔λ Bridge (BRANCH GATE)** - DELIVERED out of order by Bundle 1; the gate fired on P2 REFUTED
- [x] **Phase 5: The Set-Point Law — Verdict and Salvage** - DELIVERED out of order by Bundle 2; the box is refuted factor by factor and the corrected law is derived and verified
- [ ] **Phase 6a: On-Chain Fixed-Point Iteration of the Law (NEW)** - the "controller without `Ḡ`" premise was refuted at the review gate (the residual is affine in `Ḡ`); what survives is an on-chain fixed-point iteration that removes a stored constant and tracks drift, plus the precondition checks the first draft lacked
- [ ] **Phase 6b: Research, Venue, and Estimating `Ḡ = ∂ν/∂λ_MEV`** - The three-source research sweep and the Algebra Integral pool algebra that choose the venue, then the estimation itself behind a hard stage gate with three terminal outcomes
- [ ] **Phase 7: The Formal Controller Document and Hand-off** - The deliverable, an honest gap register, and a hand-off with agreement obtained rather than assumed

## Phase Details

### Phase 1: Ground Truth, Notation, and the Rulings Triage
**Status**: PLANNED, NOT EXECUTED — 5 plans on disk at `.planning/phases/01-ground-truth-notation-and-the-rulings-triage/01-0{1..5}-PLAN.md`, through two full two-step review rounds plus a third refresh against the re-pinned source; staged and uncommitted.
**Goal**: Every question that could make a proof be about the wrong object is closed from what is *already on disk* — and, because two bundles have already landed ahead of this phase, the symbols they minted are reconciled into the register retroactively rather than grandfathered.
**Depends on**: Nothing (first phase)
**Requirements**: NOT-01, NOT-02, NOT-03, NOT-05, NOT-06, NOT-07, NOT-08, NOT-09, NOT-10, HND-04, HND-05
**Success Criteria** (what must be TRUE):
  1. The inventory sweep names, at minimum, `plank/notes/UNITS_AND_SCALES.md`, `plank/notes/VOLATILITY_INSTRUMENTS_MEV.tex` and `spec/VOLATILITY_INSTRUMENTS_MEV_TAX/ENTRY_POINT.md`, each with a sha pin and a one-line statement of what it is normative *for*; `git ls-files` returns `ENTRY_POINT.md` by the end of the phase. The sweep records that `VOLATILITY_INSTRUMENTS_MEV.tex` is **not** a superset of `SRC` (zero hits for `u_ex`, `x_{t+1}`, `\widehat\pi`, `\frac{\partial`), so `SRC` remains the citation target.
  2. Each of the 13 blocking decisions sits in exactly one of three named buckets — **ALREADY ANSWERED ON DISK** (with the `file:line`), **AGENT-ANSWERABLE** (with the answer and its evidence), **NEEDS THE AUTHOR** (with the question as posed) — and none is untriaged. Only the NEEDS-THE-AUTHOR bucket is put to the user. **Decision #10 (`Δt` exogenous or endogenous) is recorded as DEFERRED-TO-PHASE-6b and appears in no bucket as resolved.**
  3. The notation map resolves `π^{\varphi}`, `ν` vs `u`, leg pairing in `π^{\phi}`, and the `ΔQ_v★`/`ΔQ_υ` glyph collision, each with the chosen *and* the rejected reading; and it **reconciles the symbols the two landed bundles already minted** — `Convention 7`, `Definitions 32–35`, `Rule 13`, and every identifier in `MevTaxControl.lean` / `MevTaxProgram.lean` — each marked ACCEPTED or FLAGGED with a reason. **Open item O3 is recorded by name**: `Rule 13` at `SRC:69` writes `φ_X(t) = Φ(Θ_φ; σ²(i(t)))` while `DOC` Definition 18's gate takes `ν` as well, so the map states whether Rule 13's signature is incomplete or the two objects differ.
  4. Every carried-over research finding is re-verified at its cited line against the pinned sha under one `CF-NN` identifier scheme; findings that no longer verify are dropped with the reason recorded, and the ones superseded by the 2026-08-08 ruling are marked SUPERSEDED. The record states the honest independence count for P2 (two independent derivations, one restatement, one invalid) and never "4 of 4". `LEAN-MAP.md` and `EVM-CONTROL-PRIMITIVES-MAP.md` each carry a do-not-cite header naming the specific stale claim.
  5. The unit ledger exists as a **proposed diff extending** `UNITS_AND_SCALES.md` at a pinned sha (adding `ν`, `τ_MEV`, `π^l`, `π^φ`, `π^LVR`, `ΔQ_υ` and re-deriving nothing), routed to `ul2inqpl` as a message with `git -C plank status` unchanged by this project — and it **answers open item O4 explicitly**, stating for `σ` and `σ²` which object each schedule and each disturbance entry carries, because Phase 6b's estimating equation cannot be written without that answer. The review register lists the founding artifacts (`b5f5e82`, `9658375`, `d3b226a`) as **retroactive** first entries and additionally records the two Aristotle bundles as **reviewed-after-landing**, with the inversion stated rather than back-dated.
**Plans**: 6 plans, 6 waves (sequential; `parallelization: false`) — on disk, unexecuted
- [ ] `01-01-PLAN.md` — Inventory sweep, pin register, `ENTRY_POINT.md` git-tracked (`NOT-08`)
- [ ] `01-02-PLAN.md` — The 13 blocking decisions triaged into four statuses (`NOT-01`) — has a checkpoint; item 10 DEFERRED — refreshed 2026-08-08
- [ ] `01-03-PLAN.md` — Notation map (`NOT-02`, `NOT-06`, `NOT-07`, `NOT-09`) — refreshed 2026-08-08
- [ ] `01-04-PLAN.md` — Finding register, re-verification, do-not-cite ruling (`NOT-03`, `HND-04`)
- [ ] `01-05-PLAN.md` — Unit ledger extension and review register (`NOT-05`, `HND-05`) — refreshed 2026-08-08
- [ ] `01-06-PLAN.md` — The SRC block programme: queue, writable-vs-gated split, register spec, at most one block written under user approval (`NOT-10`) — has a checkpoint

### Phase 2: The Entrywise Plant and the Control Frame
**Status**: PARTIAL — the frame research exists (`.planning/research/FRAME.md`, `PITFALLS.md`, `ARCHITECTURE.md`, `CLAIMS.md`, `SUMMARY.md`). `NOT-04` (the entrywise `∂`-partition) and `FRM-05` (the null-space test) are **undone**.
**Goal**: The plant exists on paper entry by entry and is reconciled with the `Definition 32`/`34` that already landed in `SRC`, a control frame is selected that the actual partition can carry, and the null-space test is run as a control-theoretic result.
**Depends on**: Phase 1
**Requirements**: NOT-04, FRM-01, FRM-02, FRM-03, FRM-04, FRM-05
**Success Criteria** (what must be TRUE):
  1. Every entry of the `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is written out and classified as a constant, a Jacobian entry, or structurally zero, with an explicit yes-or-no on: whether `∂_(t+1,t)` is the zero matrix, whether `u_en = [τ_MEV, φ_M, φ_X]^T` contains entries that are not actuators, and whether the `π^σ` row of `∂_(y,u)` is structurally zero. The table is **diffed against `Definition 32` and `Definition 34` as they now stand in `SRC`**, and every discrepancy is recorded as a defect in one or the other — the landed definitions are not treated as ground truth merely because they landed first.
  2. The selected frame is named and every excluded alternative carries its stated reason (LQR/LQG/servo, root locus, Bode/Nyquist, PID, the Gramian/Kalman rank test as a well-posedness tool, the "static output feedback" name-collision), and the selection **cites criterion 1's table by entry**. If `∂_(t+1,t)` is structurally zero the document re-scopes to static inversion under uncertainty rather than importing dynamic-control machinery over a memoryless map. The frame is checked for consistency with `Theorem30`'s submersion result, which has already landed: a frame that presumes a well-defined `∂φ/∂φ_M` section is rejected by name.
  3. A well-posedness checklist for a **set-point** (not a regulator) is enumerated as numbered conditions with each of P1/P2/P4/P5 mapped to the conditions it must satisfy, and `e^σ` is declared an equality constraint rather than an objective. The event-clock question is item zero and is resolved **or** declared OPEN — either way the document states whether `t` indexes swaps or blocks, whether event-averaged `ΔQ_M, ΔQ_X` may be combined with time-averaged `π^LVR·Δt, σ², λ`, writes out the PASTA/ASTA argument, and names the downstream results it puts at risk. **The `Δt` that Phase 6b uses as its instrument is a time-axis object; if the clock question is left OPEN, this criterion names Phase 6b's identification as one of the results at risk — and Phase 6a's per-swap accumulator as the other, since `λ_ARB`'s `Σ_{s<t}` is indexed on the same clock.**
  4. Every literature citation entering the document is primary-verified (via the arxiv MCP, identifier recorded) or carries an explicit `UNVERIFIED` tag, over the **≈13**-item set rather than the 5 originally flagged — including the recommendation's own four pillars (Skogestad 2000, Mason 1953, Davis 1984, Wolff 1982) and the five Carr–Madan / Breeden–Litzenberger invocations. No `FRAME.md` HIGH tag is inherited without re-check.
  5. The null-space test `HF = 0` (Alstad & Skogestad 2007) has **run** over an explicitly partitioned disturbance vector separating trade-specific components (`ΔQ_M`, `ΔQ_X`) from slow-moving ones (`σ²`, `Θ_φ`), the partition is stated, and the result is recorded as exists / does-not-exist with either the `H` it produces or the rank obstruction that prevents it. Reported as **theory only** — no on-chain cost, gas or storage claim appears anywhere.

### Phase 3: The Verification Protocol, Ratified Retroactively
**Status**: DONE AD HOC — `H1_dLbar_dpiPhi_pos` (`MevTaxControl.lean:758`) and `H2_dnu_dlamMEV_pos` (:763) landed as typed hypotheses; the freeze / gate / PROOF-REQUEST discipline was applied by hand via `spec/TAX_ADDENDUM.md` (M11–M18) and `spec/TAX2_ADDENDUM.md` (M19–M24). **The written protocol does not exist and `PRF-09`'s detectors never ran.**
**Goal**: The protocol that governed two submissions only informally is written down, run **retroactively** on both landed bundles — which is where the unverified `#print axioms` claim is finally checked — and the cheap detectors that were skipped are executed against results that already exist.
**Depends on**: Phase 2
**Requirements**: PRF-03, PRF-06, PRF-07, PRF-08, PRF-09, PRF-10
**Success Criteria** (what must be TRUE):
  1. **Open item O1 is discharged or explicitly failed.** `#print axioms` has been *run* over every declaration of `MevTaxControl.lean` and `MevTaxProgram.lean` against a built Mathlib, and the output is recorded per declaration. If the build cannot be produced in this worktree, the criterion is met only by recording `AXIOMS UNVERIFIED` as a standing defect with the blocking reason named and routed into the Phase 7 gap register — **the "0 axioms declared, 0 `sorry`" evidence may not be presented as an axiom sweep.**
  2. `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV` and `∂L̄/∂π^φ` each appear as an explicitly named typed hypothesis carrying its estimand, sign convention and observation channel (the emitting add/remove-liquidity event named), cross-referenced to the landed `H2_dnu_dlamMEV_pos` and `H1_dLbar_dpiPhi_pos`. The submission set is enumerated in one place and **neither hypothesis appears in it**; each carries a NOT-SUBMITTED marker, and **`EST-03` is named as the requirement that discharges or refutes them** — no longer as a deferred v2 track.
  3. The cheap detectors have **run against the delivered bundles** and their outputs are recorded as findings: the back-substitution check states whether `Proposition16_corrected_law`'s implicit form actually satisfies the M22 first-order condition, and the numerical harness reports `τ*`'s sign and range **as a function of the named hypothesis set**, with the hypotheses enumerated beside every number and the implicit self-reference (`φ_X`, `∂φ/∂ν`, `∂ν/∂τ_MEV` all evaluated at `ν(τ*)`) handled as a fixed-point iteration rather than a substitution. A sign or range violation whose value depends on a hypothesis is recorded as `HYPOTHESIS-DEPENDENT` and **may not be logged as a refutation**.
  4. The six-point integration gate is written — statement byte-diff, `#print axioms` sweep, zero `sorry`/`admit`, proof-body triage (a `ring`/`simp` one-liner for a claim described as substantive is flagged, not counted), dependency byte-identity, provenance — and has been **applied to both landed bundles after the fact**, with a per-bundle result table. Every point it fails retroactively is recorded as a defect against the bundle, not waived because the bundle already landed. The freeze protocol is written with a **section-scoped** sha (never a whole-file hash of a concurrently edited document).
  5. Each obligation is stated in the tree's native `Monotone` / `StrictAnti` / `ConvexOn` idiom wherever a sign or ordering claim suffices, and where derivative infrastructure is needed the gap is stated **narrowly and correctly**: no derivative lemmas exist for the five named schedule functions (`logistic`, `sigmoidR`, `multiFee`, `probOr`, `ptrade`), priced against `CapponiEmbed.lean` as in-tree precedent (132 `HasDerivAt` / 128 `deriv` / 19 `Differentiable` — **`grep -c` LINE counts, not occurrence counts**; state the method with any count). The false claim that the tree lacks differential-calculus infrastructure appears nowhere. The PROOF-REQUEST template is self-contained and route-agnostic, with its module import closure re-derived from `lean/lakefile.toml` rather than from the do-not-cite `LEAN-MAP.md`.

### Phase 4: Verdicts — Well-Posedness, the Channel, the τ↔λ Bridge (BRANCH GATE)
**Status**: ✅ **DELIVERED 2026-08-08 — out of order, ahead of Phases 1–3**, by Aristotle Bundle 1.
**Goal**: Three verdicts sharing the plant and the `τ → φ → ν` definitional payload, plus the branch decision that routes the rest of the project.
**Depends on**: Phase 3 *(as planned — in fact executed without it; see the Deviations section)*
**Requirements**: PRF-01, PRF-02, PRF-05
**Evidence**: `control/aristotle/tax-result/project_aristotle/RequestProject/MevTaxControl.lean` — 855 lines, 42 declarations, blocks M11–M18. Request: `control/spec/TAX_ADDENDUM.md`.
**Success Criteria** (what must be TRUE):
  1. ✅ `PRF-01` carries a terminal verdict on well-posedness: **REFUTED in part** — `Theorem30_composed_fee_submersion_section_sum_ill_posed` (:367) establishes that `(φ_M, φ_X, τ) ↦ φ_total` is a submersion `ℝ³→ℝ` with no inverse, so the section sum is ill-posed. `Convention 7` fixes the iteration index as the swap event. The `φ_M ≡ φ̄_M` and `(β_j, γ_j)`-frozen freezings appear as **declared modelling assumptions** in `Rule 13`, not as consequences of a theorem — and the record states that the cited "`(β,γ)` do not control `λ_MEV`" theorem does not exist, `MevOptimization.lean:465` (`mevMulti_mono_beta`) proving monotone *increase* in `β`.
  2. ✅ `PRF-02` carries a terminal verdict: **REFUTED with witness.** `Theorem29_monoid_path_is_direct` (:213) names the second path — `τ_MEV` reaches `φ_total` through the Rule 12 monoid, bypassing `ν` — and `Corollary29_five_factor_product_not_total_derivative` (:239) exhibits the counterexample to the "no other path" identity. The path's factors are written out: `Definition 35`'s `∇φ` carries the entry `(1−φ_X)(1−φ_M)`. No restricted form was claimed to survive, so no vacuity check is owed.
  3. ✅ `PRF-05` carries a verdict on the `τ↔λ` bridge as a first-class obligation: the substitution of `∂ν/∂λ_MEV` for `∂ν/∂τ_MEV` is **not licensed** (M17), and `Theorem32_hazard_strictAntiOn_tau` (:702) supplies the missing leg — the hazard is strictly antitone in `τ`, which is what makes the composed sign `∂ν/∂τ_MEV ≤ 0` rather than the imported `> 0`. Downstream statements use the written-out composition; no new symbol was minted for it.
  4. ⚠️ **PARTIALLY MET — the residual is open item O1.** Checkable now and checked: 0 `sorry` (`grep -c` returns 0), no `axiom` declarations, dependency files byte-identical, every declaration name above present at the cited line. **Not checked: `#print axioms`.** The phase is recorded as delivered with this defect named, and the sweep is owed by Phase 3 criterion 1.
  5. ✅ **The branch gate executed and is recorded: P2 REFUTED.** Per the branch table, `PRF-04` was not adjudicated on a fresh premise and `SAL-01`…`SAL-05` became Phase 5's main work. The gate did not terminate the project. It is FIRED and is not re-run.
**Plans**: None — delivered by direct Aristotle submission rather than through GSD plans. This is recorded as the route actually taken, not retrofitted into plan files.

### Phase 5: The Set-Point Law — Verdict and Salvage
**Status**: ✅ **DELIVERED 2026-08-08 — out of order, ahead of Phases 1–3**, by Aristotle Bundle 2. This phase delivers the Core Value.
**Goal**: A terminal verdict on the boxed `τ*_MEV` and, where it falls, a corrected set-point law that carries its own verdict.
**Depends on**: Phase 4
**Requirements**: PRF-04, SAL-01, SAL-02, SAL-03, SAL-04, SAL-05
**Evidence**: `control/aristotle/tax2-result/project_aristotle/RequestProject/MevTaxProgram.lean` — 1130 lines, 54 declarations, blocks M19–M24. Request: `control/spec/TAX2_ADDENDUM.md`.
**Success Criteria** (what must be TRUE):
  1. ✅ `PRF-04` carries a terminal verdict and is not left OPEN: the boxed form is **REFUTED factor by factor**. `auditTable` assigns one of five verdicts to each of nine factors (three SURVIVES/SIGN-CORRECTED, two SPURIOUS, one ILL-POSED, three MISSING — the full table is in the Overview), and `Proposition16_audit_justification` supplies the reason for each. The ledger names the relation the box was adjudicated against: **the M19 exposure-minimization program with replication as a feasibility constraint**, per the user ruling, with the level reading `π^σ ≡^R π̂^σ` and the as-written `∂π̂^σ/∂τ_MEV = ΔQ_v★` both named as rejected alternates.
  2. ✅ Every refuted factor carries its **specific defect** and an error class from the `Verdict` enumeration: `1/ΔQ_v★` and the ladder bracket are strictly positive common factors that cancel out of `= 0` (**SPURIOUS**); the fee-Jacobian bracket has no section-independent value by `Theorem30` (**ILL-POSED** — the strictly stronger verdict); `∂ν/∂τ_MEV` is **SIGN CORRECTED** because the source imported `Ḡ > 0` where `∂ν/∂τ_MEV ≤ 0` is required; the direct monoid path, the monoid Jacobian and the implicit self-reference are **MISSING**, the box differing from the total derivative by exactly the direct summand (`Theorem33_five_factor_product_is_one_summand`).
  3. ✅ A corrected set-point law is derived and stated over an explicit domain: `Proposition16_corrected_law` (:1054) gives `τ*_MEV = 1 + (1−φ_X)/((∂φ/∂ν)(∂ν/∂τ_MEV))` **with a signed denominator** — the absolute-value form being conditional on the M21 signs and never the theorem. It is **implicit, not closed**: all three factors are evaluated at `ν(τ*)`. Domain: `τ* < 1` always, `τ* > 0` iff the gate dominates, restricted to `Theorem36_no_interior_root_off_the_band`'s (:703) responsive band, and the branch structure is stated.
  4. ✅ The corrected law is itself machine-verified rather than asserted — it is a declaration in the returned bundle, not prose — with `Theorem34_opposed_signs` (:434) and `Theorem34_signs_from_H1_H2` (:487) supplying its sign structure, and `Theorem34_omitting_direct_can_reverse_sign` (:457) showing what dropping the direct path costs. No `VERIFICATION OUTSTANDING` residual is carried for the law's own statement.
  5. ⚠️ **PARTIALLY MET — two named residuals.** Every assumption is declared as an assumption with a real declaration name (`SAL-05` satisfied: the sign structure is derived *from* `H1`/`H2` by name, never from a theorem that does not exist). But: **(O2)** the FOC root is **not** established to be the minimiser — `Proposition15_level_reading_second_order_undetermined` (:823) exhibits the undetermination and `Proposition15_single_crossing_gives_minimum` (:890) is conditional on a single-crossing property that **nothing in the bundle proves**; and **(O1)** `#print axioms` is unverified. Both are routed — O1 to Phase 3, O2 to the Phase 7 gap register — and neither may be silently dropped.
**Plans**: None — delivered by direct Aristotle submission. Recorded as the route actually taken.

### Phase 6a: On-Chain Fixed-Point Iteration of the Law
**Status**: NEW (2026-08-09). **Promotes v2 `CTL-01`.** **RE-SCOPED the same day** — see the refutation below. Runs before Phase 6b because its precondition checks terminate cheaply.
**Goal**: Determine what an on-chain evaluation of the control law actually is, and what it costs — having established that it is **not** a controller that avoids `Ḡ`.

**The founding premise was REFUTED at the review gate, and this phase is what survives.** The
proposal was that because `ν` and `λ_MEV` are protocol state, a loop could drive
`∂π̂^σ/∂τ_MEV → 0` without forming `Ḡ`, demoting `EST-04`. Both reviewers refuted it
independently by composing this project's own carriers:

```
Theorem 30 (SRC:122) + Theorem 29 (SRC:113) + the chain dnu/dtau = Gbar*(dlambda/dtau)
  ==>  dpihat/dtau = (dpihat/dphi) * [ (1-phi_M)(1-phi_X) + (dphi/dnu)*Gbar*(dlambda_MEV/dtau_MEV) ]
```

`Ḡ` multiplies one of only two bracket terms, so the residual is **affine in `Ḡ`** and any
evaluation of it from state **is** an evaluation of `Ḡ`. "Never stores `Ḡ`" is satisfiable and
empty. What remains is still worth specifying — an on-chain **fixed-point iteration** of the
`Ḡ`-dependent law removes a stored constant and tracks drift — but it is **not a hedge against
the estimation failing**, and no criterion below may be read as one. `EST-04`'s demotion is
**withdrawn**.

**Depends on**: Phase 1 (`NOT-05`/`NOT-07`; open item **O4** decides the accumulator's units and is a pass/fail dimensional check here), Phase 2 — **twice**: the event-clock ruling (`FRM-03`) adjudicates the two-clock defect in `λ_ARB`'s summand, and **`∂_(t+1,t)` is a KILL CONDITION** — if Phase 2 returns it structurally zero, the plant is memoryless, Phase 2's own SC2 re-scopes to static inversion, and `NEC-07`'s dynamic machinery is void as written, Phase 3 (hypothesis discipline — **`H1` and `H2` are both live here**, which the first draft of this phase missed entirely).
**Requirements**: NEC-00, NEC-01, NEC-02, NEC-03, NEC-04, NEC-05, NEC-06, NEC-07, NEC-08, NEC-09
**Success Criteria** (what must be TRUE):
  1. **The refutation is verified, not inherited.** The composition above is an **algebraic identity**, hence a legitimate claim for the proving pipeline, and it carries a verdict. If it holds, the "controller without `Ḡ`" reading is closed permanently across every document. `NEC-00` **blocks the phase**.
  2. **The uniform-clearing precondition is checked against the actual venue and deployment.** `λ_MEV = λ_ARB` holds only where `λ_sandwich = 0`, which `DOC:1041` scopes to **the Angstrom regime**. Decision #13's venue is a **continuous-execution** AMM where sandwiching is live; the deployment target is a **Uniswap v4 hook** under one-hook-per-pool exclusivity, so composing with Angstrom is unavailable; and the sandwich-zero result is **UNFORMALIZED, no carrier** (`DOC:1026`). Stating a precondition is not satisfying it — either a venue satisfies it or `NEC-01` terminates the phase.
  3. **`λ_ARB`'s observer is specified completely, including what the first draft's narrative omitted**: the `π^LVR/π^linear` factor whose `π^{\varphi}` carrier is UNFORMALIZED (`DOC:821`) and whose exact tier's `σ²Δt < 8` guard has no carrier (`DOC:959`); `Δt` being the **mean** interblock time (`DOC:901`), which makes the **window length an undeclared observer parameter**; and the accumulator indexing swaps while `Δt` indexes blocks — **two clocks in one summand**. A dimensional check on `ℙ_{Δ_ARB}` is **pass/fail**: `σ` must be a rate, not `σ²`.
  4. **The `ν ↔ λ` coupling clears three objections or the derivable branch is closed.** `DOC:995` is an **assumed hypothesis** of Theorem 19, not a result; Theorem 19 is **REFUTED for σ-varying schedules** and `Rule 13`'s schedule is σ-varying by construction; the alignment is **CROSS-COORDINATE** with an unstated dimensional constant, so it cannot yield a magnitude; and the two evaluations sit at **different ticks**. The falsification standard is fixed **before** the verdict is sought, the "partially derivable" branch carries a **recomposition rule** (`sign(residual) ⇏ sign(total)`) written before `EST-03` runs, and the **fully-derivable-with-negative-sign** branch — which refutes `H2` algebraically — is written into the gate table.
  5. **Computed or dithered is stated, and the dither's costs are owned.** If dithered, the scheme is an **online estimation with no instrument, no first-stage F, no power floor, no pre-registration and no standard errors** — `EST-03`'s anti-fishing discipline applies to it in full, it needs persistency of excitation, it violates timescale separation (swap-indexed loop versus LP repositioning over hours to days) unless analysed, and it is an **experiment on live users' fees**, acknowledged in writing.
  6. **The loop's true character is stated without euphemism, and stability is stated correctly.** The observer is **self-confirming** (`λ_ARB` depends on `φ`, which contains `τ_MEV`), so the loop converges to *the model's root* and cannot detect model error (**O7**); `λ_ARB` is a **monotone divergent accumulator**, so `Ḡ → 0` and the loop **stalls** rather than converging slowly, with the decay/window question OPEN (**O8**). Direction is `sign(∂²π̂^σ/∂τ²)`, **not** `sign(Ḡ)`; the discrete-time closed loop `(1 + kJ)` needs `−2 < kJ < 0`, i.e. a **bound on `|Ḡ|`**; **`H1` scales and signs the loop gain** through the residual's prefactor by `Proposition 12` and is undischarged on every branch because `EST-03` tests `H2` only; the box `τ ∈ [0,1]` and the `τ* = 0` corner need **projection and anti-windup**; **O2** stands unweakened. The equality constraint `π^σ = π̂^σ` is monitored or its absence is costed.
  7. **The ledger records the withdrawal.** `NEC-09` states per `EST-03` verdict what this phase delivers, and records that `EST-04`'s demotion was proposed and **withdrawn**, so no downstream document inherits the retracted reading. **"The estimation is no longer load-bearing" is banned** from the planning layer and the deliverable alike unless `NEC-00` overturns the refutation.
**Plans**: TBD — 5 plans expected:
- `06a-00` — `NEC-00` + `NEC-01`: the refutation submitted as an identity, and the uniform-clearing precondition checked (**either can terminate the phase**)
- `06a-01` — `NEC-02` + `NEC-03`: observer and `ν` constructibility, with the omitted carriers, the two-clock defect and the dimensional check
- `06a-02` — `NEC-04`: the coupling verdict against a pre-fixed falsification standard
- `06a-03` — `NEC-05` + `NEC-07` + `NEC-08`: computed-or-dithered, stability stated correctly, the constraint
- `06a-04` — `NEC-06` + `NEC-09`: what the loop is, and the ledger

**Relation to Phase 6b.** This phase does **not** replace the estimation, does not license
skipping it, and — after the refutation — **does not reduce its load**. `EST-03` and `EST-04`
are both fully load-bearing. What Phase 6a can still do for Phase 6b is narrow the estimand:
`NEC-04`'s coupling verdict, if it clears its three objections, changes what `EST-03` is
testing, and `NEC-04` therefore carries the recomposition rule that keeps `EST-05`'s
back-propagation into `H2` honest.

### Phase 6b: Research, Venue, and Estimating `Ḡ = ∂ν/∂λ_MEV`
**Status**: Estimation category promoted from v2 on 2026-08-08 (design: `control/spec/ECONOMETRICS-DESIGN.md`); **Literature & Venue Research added 2026-08-09** — the phase previously had no research requirement at all, named no venue, and read none of the 14 internal PDFs for their empirical design. *(Renumbered from Phase 6 in the 2026-08-09 split.)*
**Goal**: The one empirical object in the corrected law is measured — or the attempt terminates with a reportable verdict. `Ḡ` is the only non-structural factor in `Proposition16_corrected_law`, and estimating it **is** the test of `H2_dnu_dlamMEV_pos`, which both landed bundles carry undischarged.
**Depends on**: Phase 1 (the notation map and units ledger — `NOT-02`, `NOT-05`, `NOT-07` — are direct inputs; open item O4 is literally a units question and Stage 1's specification cannot be fixed without it), Phase 2 (the event-clock ruling governs whether `Δt` is a legitimate time-axis instrument), Phase 3 (the detector and hypothesis discipline), **Phase 6a** (whose `NEC-04` coupling verdict can shrink the estimand before a single regression is specified, and which carries the recomposition rule that keeps `EST-05`'s back-propagation into `H2` honest). **Phase 6a does NOT reduce this phase's load** — the demotion proposed on 2026-08-09 was withdrawn the same day when the free-option premise was refuted.
**Requirements**: LIT-01, LIT-02, LIT-03, LIT-04, EST-01, EST-02, EST-03, EST-04, EST-05, EST-06, EST-07, EST-08, EST-09
**Success Criteria** (what must be TRUE):
  0. **The research precedes the specification, and the venue is an output of it.** The 14 internal PDFs are re-read for **empirical design** — identification strategy, data, unit of observation, effect sizes, instruments — each with an explicit transfer verdict, not a summary. The arXiv sweep runs through the arxiv MCP and targets, in particular, **what other work has used as an instrument on block time or realized volatility**, since `Δt` is our proposed lever and weakness is its named risk. Non-arXiv on-chain material is admitted **tagged lower-rigor** and may never be the sole justification for a specification; where it conflicts with peer-reviewed work the latter governs and the conflict is recorded. Finally `ν` and `λ_ARB` are derived in **Algebra Integral**'s own state variables — the venue whose `AdaptiveFee` our `φ` is a port of, so the fee form and the volatility-oracle object are structurally the same rather than analogous — and the pool set is chosen from that derivation **plus measured dispersion**. Dynamic-fee natural experiments were considered as a fourth source class and **deliberately excluded by the user**; that exclusion is recorded, and reopening it is a scope change, not a research decision.
  1. `ν`'s empirical construction is **established or declared non-constructible**: whether `ν = \varphi_{(1/2,0)}(i_K; ΔQ, 0; t) / \varphi_{(1/2,0)}(i_K; 0, L; t)` is directly computable from pool state and swap events, or requires reconstruction, with the read path named down to the event and the field. `EST-01` **blocks every other requirement in this phase** — no specification, instrument validation, or regression is written before it returns, and if `ν` is not constructible the phase terminates here with that as its delivered result.
  2. The identification lever is **validated before use, on measured dispersion, not asserted**: the venue and pool set are named, `Δt`'s realized dispersion on that venue is reported as a number, and the first stage regresses `λ_ARB` on `√Δt` (the transform the hazard actually carries, not raw `Δt`). **Decision #10 (`Δt` exogenous or endogenous) is adjudicated here by the structural-econometrics discipline and its ruling recorded** — it was deferred to this phase and was not closed in the doc layer. Insufficient dispersion everywhere available is recorded as terminal non-identification, not as a reason to substitute a different instrument post hoc.
  3. **Stage 1's specification, instrument, sample and power floor are timestamped as fixed BEFORE the data is touched**, and the first-stage F is reported **before** any second-stage output is examined. Stage 1 returns exactly one of three terminal verdicts, all reportable: gate opens; **wrong sign ⟹ `H2` REFUTED**; or **not identified** — the last being a delivered result on the `υ` precedent, never a prompt to re-specify. A re-specification after seeing Stage 1's output is a protocol violation and is recorded as one.
  4. **The hard gate is honoured: `EST-04` produces no output unless Stage 1's verdict is "gate opens".** On either of the other two verdicts, Stage 2 is not run and the phase closes with Stage 1's verdict as its deliverable. Where the gate opens, `ν = a + b·σ_ℓ(c(λ − d))` is fitted by nonlinear IV/GMM and `Ḡ = b·c·σ_ℓ'(c(λ−d))` is reported as a logistic bump that vanishes on the saturation bands, consistent with `Theorem36_no_interior_root_off_the_band`.
  5. The output contract is delivered and **back-propagated into the Lean corpus**: `(a, b, c, d)` with covariance, the first-stage F, and the **admissible band** where `Ḡ` is bounded away from zero, intersected with `Theorem36`'s responsive band. Stage 1's verdict is recorded against `H2_dnu_dlamMEV_pos` in **both** `MevTaxControl.lean` and `MevTaxProgram.lean` as discharged or refuted; if refuted, the roadmap and the document record that `Theorem34_opposed_signs` and the corrected law's sign both flip, and that consequence is propagated rather than absorbed. Open item **O2** is restated here: if the estimation calibrates toward a `τ` assumed to minimise exposure, that assumption is load-bearing and unproved.
**Plans**: TBD — 7 plans expected, structured around the design's own gate (`06b-02b` carries the four discipline requirements added at the 2026-08-09 review gate):
- `06b-00` — `LIT-01` + `LIT-02` + `LIT-03`: the three-source research sweep, each hit carrying a transfer verdict (**runs first; nothing downstream is specified before it returns**)
- `06b-01` — `LIT-04` + `EST-01`: the Algebra Integral pool algebra, `ν`'s read path, venue and pool set chosen from the derivation plus measured dispersion (**blocking**)
- `06b-02` — `EST-02`: `Δt` dispersion **measured and reported as a number**, Decision #10 adjudicated
- `06b-03` — `EST-03`: **Stage 1 sign test** — specification pre-registered, first-stage F reported first, three terminal outcomes ⟹ **HARD GATE**
- `06b-04` — `EST-04`: **Stage 2 magnitude** — runs only if `06b-03` returns "gate opens"
- `06b-02b` — `EST-06` + `EST-07` + `EST-08` + `EST-09`: the pre-registration instrument — bad-control resolution for `φ_X`, numeric thresholds with chain-time clustering, the `Δt ⟂̸ σ` validity test, and the selection/estimation split. **Lands with `06b-03`'s pre-registration, never after data is examined**
- `06b-05` — `EST-05`: output contract, admissible band, back-propagation into both Lean bundles

**Hard gate semantics (internal to Phase 6b):** `06b-03` has three terminal outcomes. Only one
of them permits `06b-04` to run. The other two close the phase with a delivered result. **None
of the three terminates the project** — Phase 7 runs in every case, and the document reports
whichever verdict returned. **What changed on 2026-08-09:** a softening of this gate
was proposed — that it would decide only whether a *calibrated magnitude* exists rather than
whether a *controller* does — and was **WITHDRAWN the same day**, when both reviewers refuted
its premise by showing the FOC residual is affine in `Ḡ`. **This gate retains full force on
every path.** Nothing in this phase or downstream may cite the withdrawn reading.

### Phase 7: The Formal Controller Document and Hand-off
**Status**: IN PROGRESS — `SRC` has been restructured into numbered blocks (`Convention 7` at :9, `Definition 32` at :18, `Definition 33` at :41, `Definition 34` at :49, `Definition 35` at :61, `Rule 13` at :69), and **PR #22 → `develop` is open** carrying everything. *(Renumbered from Phase 6 in the 2026-08-08 re-baseline.)*
**Goal**: The project's single deliverable — the formal controller document — plus an honest gap register and a hand-off whose peer agreement is obtained rather than assumed.
**Depends on**: Phase 6a (whether a non-estimated controller exists decides what the document's control section can claim) and Phase 6b (Stage 1's verdict on `H2` can flip the corrected law's sign, so the document cannot be finalized ahead of it)
**Requirements**: HND-01, HND-02, HND-03
**Success Criteria** (what must be TRUE):
  1. The formal controller document exists and integrates frame, entrywise plant, verdicts, typed hypotheses, salvage and the estimation verdict, each section delegating detail to its owning document by an explicit `> Authoritative detail:` pointer and duplicating no derivation. **Every claim in it resolves to exactly one of: a verdict, a named typed hypothesis, or a gap-register entry** — a reader can trace any statement to its status without leaving the document. The corrected law appears in its **signed-denominator** form; the absolute-value form appears only with its M21-sign precondition attached, or not at all.
  2. The gap register carries, at minimum and by name, all eight standing open items — **O1** (`#print axioms` unverified, or its Phase 3 disposition), **O2** (the FOC root is not established to be the minimiser; `Proposition15_single_crossing_gives_minimum` is conditional on an unproved single-crossing property), **O3** (`φ_X`'s `ν`-dependence versus `Rule 13`'s signature), **O4** (`σ` vs `σ²` units), **O6** (the on-chain `λ` is a model-based observer, not a measurement, and the online route destroys the offline audit trail), **O7** (the observer is **self-confirming** — the controller's action moves its own measurement exactly as the model prescribes, so the loop converges to the model's root and cannot detect model error), **O8** (`λ_ARB` is a **monotone divergent accumulator**, so `Ḡ → 0` asymptotically and the loop stalls; the decay/window question is OPEN), **O5** (**the project has no defined failure condition** — recorded as an open item addressed to the user, stating that every outcome is presently written as a success; the register **does not invent one**) — plus the event-clock question if left OPEN, every obligation left as a named hypothesis, the `(β_j,γ_j)`-frozen assumption and its missing justification, the `FRM-05` null-space result's consequences, and any Phase 6b non-identification verdict, plus **O6** (the on-chain `λ` accumulator is a model-based observer, not a measurement) and any negative constructibility verdict from Phase 6a. Each entry carries severity and disposition (in-scope / deferred / needs-the-user).
  3. The hand-off names each deferred track — `EVM-01a`, `EVM-01b`, `EVM-02`, `EVM-03`, `EVM-05`, `EVM-06`, and the `IMP-*` / `CTL-*` families — with what it inherits from this project, what it still needs, and its owning session. **Peer agreement is obtained and evidenced**: a sent message with a reply, or a `CLAUDE.md` row landed for this track. Where agreement was not obtained, the register says so plainly — silence is recorded as silence, never as consent. `EST-01` is **no longer listed as deferred**; it is Phase 6b of this milestone. `CTL-01` is likewise **no longer deferred** — it was promoted into the `NEC-*` category and is Phase 6a; only `CTL-02`/`CTL-03`/`CTL-04` remain in the `CTL-*` hand-off.
  4. Findings against peer-owned documents (the `SRC` errata, the misquoted `(β,γ)` theorem, the unit-ledger extension) are routed by peer message plus a gap-register entry and never fixed in the peer's tree: no diff produced by this project touches the repo-root `.planning/`, `src/`, `test/`, `plank/` or `lean4-spec/`, verifiable by `git status` across those worktrees.
  5. Every artifact this project wrote under `spec/` appears in the review register having passed the two-step review (Reality Checker + one named specialist, in parallel), with a review date preceding its commit date — and the artifacts that did **not** (the founding three, and the two Aristotle bundles reviewed after landing) remain marked as retroactive rather than back-dated into compliance. PR #22 does not merge with any `spec/` artifact missing from the register.

## Gates — explicit semantics

Two gates exist. One has already fired; one has not been reached.

| Gate | Location | Status | Semantics |
|---|---|---|---|
| **Branch gate — P2** | end of Phase 4 | ✅ **FIRED: P2 REFUTED** | `PRF-04` was settled against the corrected M19 program rather than the box's own premise, and `SAL-01`…`SAL-05` became Phase 5's main work. Not re-run. |
| **Stage gate — `EST-03`** | inside Phase 6b, between `06b-03` and `06b-04` | ⬜ not reached | Three terminal outcomes. *Gate opens* ⟹ `06b-04` runs. *Wrong sign* ⟹ `H2` REFUTED, `06b-04` does **not** run, the refutation back-propagates into both bundles. *Not identified* ⟹ `06b-04` does **not** run, terminal on the `υ` precedent. **A softening was proposed on 2026-08-09 and WITHDRAWN the same day** when both reviewers refuted its premise: the FOC residual is affine in `Ḡ`, so no on-chain loop escapes it. This gate retains **full force** on every path. |
| **Precondition gate — `NEC-00`/`NEC-01`** | inside Phase 6a, at `06a-00` | ⬜ not reached | Two blocking questions, **neither of which affects `EST-*`'s status**. *`NEC-00`*: does the proving pipeline confirm the residual is affine in `Ḡ`? If yes, the "controller without `Ḡ`" reading is closed permanently. *`NEC-01`*: does a named venue and deployment satisfy uniform clearing? If not, `λ_MEV ≠ λ_ARB` there and Phase 6a terminates with that as its delivered result. |
| **Coupling gate — `NEC-04`** | inside Phase 6a, at `06a-02` | ⬜ not reached | Four branches, all written before the verdict is sought. *Independent* ⟹ the estimand stands whole. *Partially derivable* ⟹ `EST-03` tests a residual and the pre-written recomposition rule governs what may be recorded against `H2`. *Fully derivable, positive* ⟹ `H2` discharged algebraically. *Fully derivable, negative* ⟹ **`H2` REFUTED with no data at all**, and `Theorem34`/the corrected law's sign flip on that basis. |

**Neither gate can terminate the project.** Phase 7 runs on every branch of both.

## Progress

**Execution Order:** Remaining phases execute in numeric order: 1 → 2 → 3 → 6a → 6b → 7 (sequential;
`parallelization: false`). Phases 4 and 5 are complete and are not re-executed.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Ground Truth, Notation, Rulings Triage | 0/6 | Planned (plans staged, unexecuted) | - |
| 2. Entrywise Plant and Control Frame | 0/TBD | Partial (frame research only; `NOT-04`, `FRM-05` undone) | - |
| 3. Verification Protocol, Ratified Retroactively | 0/TBD | Partial (applied ad hoc; protocol + detectors owed) | - |
| 4. Verdicts — P1, P2, P5 (BRANCH GATE) | n/a (direct submission) | ✅ **Complete** — Bundle 1, with residual O1 | 2026-08-08 |
| 5. The Set-Point Law — Verdict and Salvage | n/a (direct submission) | ✅ **Complete** — Bundle 2, with residuals O1, O2 | 2026-08-08 |
| 6a. On-Chain Fixed-Point Iteration of the Law | 0/5 (expected) | Not started — premise refuted at the gate, phase re-scoped | - |
| 6b. Research, Venue, and Estimating `Ḡ` | 0/7 (expected) | Not started — fully load-bearing (the demotion was withdrawn) | - |
| 7. Formal Controller Document and Hand-off | 0/TBD | In progress (`SRC` restructured; PR #22 open) | - |

## Requirement Coverage

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | NOT-01, NOT-02, NOT-03, NOT-05, NOT-06, NOT-07, NOT-08, NOT-09, NOT-10, HND-04, HND-05 | 11 |
| 2 | NOT-04, FRM-01, FRM-02, FRM-03, FRM-04, FRM-05 | 6 |
| 3 | PRF-03, PRF-06, PRF-07, PRF-08, PRF-09, PRF-10 | 6 |
| 4 | PRF-01, PRF-02, PRF-05 | 3 |
| 5 | PRF-04, SAL-01, SAL-02, SAL-03, SAL-04, SAL-05 | 6 |
| 6a | NEC-00, NEC-01, NEC-02, NEC-03, NEC-04, NEC-05, NEC-06, NEC-07, NEC-08, NEC-09 | 10 |
| 6b | LIT-01, LIT-02, LIT-03, LIT-04, EST-01, EST-02, EST-03, EST-04, EST-05, EST-06, EST-07, EST-08, EST-09 | 13 |
| 7 | HND-01, HND-02, HND-03 | 3 |
| **Total** | | **58 / 58** |

Verified programmatically: the set of IDs defined in `REQUIREMENTS.md` v1 equals the set mapped
above (58 = FRM 5 + NOT 10 + PRF 10 + SAL 5 + **NEC 10** + **LIT 4** + **EST 9** + HND 5). No
orphans; no requirement mapped to more than one phase. The v2 `EVM-*`, `IMP-*` and `CTL-*`
items are deliberately **not** mapped — they are out of scope for this milestone; `CTL-01` is
struck there because it was **promoted into `NEC-*`**, while `CTL-02`/`CTL-03`/`CTL-04` remain
v2. `EST-01`…`EST-09` are **no longer v2** and are mapped to Phase 6b.

> **Correction (2026-08-09).** This table previously read `| 1 | …11 IDs… | 10 |` and
> `**Total** | 39 / 39` while the header of this same file said 50 — the row-1 cell was
> miscounted and the total was never updated when the Estimation category was promoted. A
> roadmap stating two different totals in one file is not an audit artifact. Both reviewers
> caught it; the count is now derived from the rows, and the set comparison is run against
> **this table and** the per-phase `**Requirements**:` lines, not just the latter.

## Standing constraints (apply to every phase)

- All GSD commands run with `--cwd control`. The repo-root `.planning/` is read-only and
  belongs to a different, unrelated GSD project.
- Notation is binding. No symbol is minted without a user ruling, in artifacts *and* in
  Aristotle prompts. Curvature is `κ_φ` (never `χ`); `λ̃` is the incidence operator vs plain-`λ`
  hazard; probabilities are `ℙ_event`.
- **The corrected law is quoted with a signed denominator.** The absolute-value form is
  conditional on the M21 signs and is never presented as the theorem.
- `SRC` (`notes/VOLATILITY_INTRUMENTS_MEV.md`) now carries numbered blocks (`Convention 7`,
  `Definitions 32–35`, `Rule 13`) — cite those by number **and** sha; anything outside them is
  cited by line against a pinned sha. `DOC` (`plank/notes/VOLATILITY_INSTRUMENTS.md`) is cited
  by numbered item plus sha.
- **Never prescribe a composition of named Lean declarations without a written check that it
  closes.** A route that has not been checked is a hypothesis, not a plan.
- Every artifact passes the two-step review (Reality Checker + one specialist, in parallel)
  before it is committed or executed — never deferred. Where this was violated (the founding
  three artifacts and the two Aristotle bundles), the register says so.
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
***RE-BASELINED: 2026-08-08** — rewritten against actual execution: Phases 4 and 5 delivered out of order by two Aristotle bundles, Phase 1 planned-unexecuted, Phase 2 partial, Phase 3 ad hoc, old Phase 6 renumbered to 7, and a new Phase 6 created for the Estimation category (39 requirements, up from 34)*

***AMENDED: 2026-08-09** — Phase 6 split into 6a (Non-Estimated State Feedback, `NEC-*`, promoting v2 `CTL-01`) and 6b (Research, Venue, and Estimation, `LIT-*` + `EST-*`), with 6a executing first; a second gate added on constructibility; open items **O6**/**O7**/**O8** opened on the observer/measurement distinction, the self-confirming observer and the divergent accumulator; the free-option premise **refuted at the gate** and `EST-04`'s demotion withdrawn (58 requirements, up from a corrected 40)*
