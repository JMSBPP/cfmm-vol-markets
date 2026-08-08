# Roadmap: MEV-Tax Set-Point Controller — Verified Design Spec

## Overview

This project does not build software. It adjudicates a derivation. The boxed closed form
for `τ*_MEV` carries its own author's `> note: This needs verification`, and four
independent researchers converged on the prediction that it will not survive formal
verification. The journey therefore runs: close every notational and definitional question
that would make a proof be *about the wrong object* (Phase 1), choose and justify a control
frame that the plant's actual `∂`-partition can carry (Phase 2), wrap the obligations in a
freeze/diff/gate protocol and run the cheap detectors that could refute the law for free
(Phase 3), then spend Aristotle budget on the obligations in strict dependency order —
well-posedness and the channel first, behind a hard halt gate (Phase 4), then the tax-side
gain and the `τ↔λ` bridge (Phase 5), then the law itself and, where it falls, its correction
(Phase 6). Only a law that survives is analysed for EVM realizability (Phase 7), and the
whole thing consolidates into one spec with an honest gap register and a named hand-off
(Phase 8).

**Execution is sequential** (`parallelization: false`, a deliberate user choice) so that an
early refutation halts downstream spend. **A refutation is a delivered result, not an
abort** — per the project's Core Value, and per the 2026-08-08 scoping decision the project
does not stop at the verdict but derives and verifies the *corrected* law.

**This project executes zero steps of the proving pipeline in its own worktree.** The Lean
tree, the bundle assembly, and the Aristotle API key all belong to the Lean4+Math peer
session. Every proof obligation therefore terminates in a PROOF-REQUEST hand-off artifact,
and a phase's proof criterion is satisfied by *the artifact plus the returned verdict* —
never by this project running a prover.

### Deviations from the researched build order (stated, not silent)

ARCHITECTURE.md's six-phase order (A → B → C → D → E → F) is the strong default and is
mostly adopted. Six deliberate deviations:

1. **Research Phase A is split into Phases 1 and 2.** SUMMARY.md preserves a conflict:
   FRAME treats the apparent underactuation as already resolved (`π^σ` is a measured
   disturbance; `c = Hy`, `H = [1,−1]`, square 1×1), while PITFALLS (M3) wants an entrywise
   `∂`-matrix check first in case `∂_(t+1,t)` is structurally zero. Splitting puts
   PITFALLS's check (`NOT-04`) in Phase 1 and makes Phase 2's frame selection *depend on its
   result* — the conflict is resolved at a phase boundary, where it is visible, rather than
   inside one phase where it could be quietly skipped.
2. **E0 (`EVM-01`) is not parallel to A.** Parallelization is off, and PROJECT.md's own
   framing requires the frame to be justified *against EVM constraints*, so the refreshed
   primitive inventory is an input to Phase 2's frame selection, not a side task.
3. **A phase research did not name — Phase 3.** ARCHITECTURE treats the integration gate as
   "a deliverable of the theory-basis phase". The requirements promote it to five first-class
   items (`PRF-06`…`PRF-10`), and `PRF-09`'s detectors can refute the boxed law numerically
   *before any Aristotle spend*. Cheap detectors that can end the project deserve their own
   exit, not a footnote in someone else's phase.
4. **On P2 REFUTED, Phase 5 stays live.** ARCHITECTURE says skip C, D and E1. But the
   2026-08-08 salvage decision requires a *corrected* law (`SAL-02`/`SAL-04`), and any
   corrected law's sign rests on the same `∂ν/∂τ_MEV` composition that Phase 5 settles. What
   is dropped on the refuted branch is the *spend* on P4-as-boxed, not the verdict.
5. **Research Phase D and the salvage work merge into Phase 6.** On the refuted branch the
   boxed-form phase collapses to a ledger entry and the real work is the correction;
   splitting them would leave a near-empty phase. Phase 6 is one capability: *a set-point
   law with a verdict*.
6. **`HND-04` (mark the stale v2 documents do-not-cite) moves from consolidation into
   Phase 1.** Its entire value is preventing consumption of a stale inventory; performed last
   it prevents nothing. `EVM-01` already supersedes one of the two documents.

### Record correction

`REQUIREMENTS.md` stated **31** v1 requirements. A direct count returns **34**
(FRM 4 + NOT 6 + PRF 10 + SAL 5 + EVM 4 + HND 5). All 34 are mapped below; the traceability
table and the coverage count in `REQUIREMENTS.md` have been corrected.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Rulings & Ground Truth** - Every notational, definitional and dimensional question closed by a recorded user ruling; the `∂`-partition written out entrywise
- [ ] **Phase 2: Frame Selection & EVM Substrate** - The control frame chosen and justified against both the entrywise plant result and the live Plank primitive inventory
- [ ] **Phase 3: Obligation Machinery & Cheap Detectors** - Obligations stated in the tree's native idiom, wrapped in a freeze/diff/gate protocol, with the numerical and back-substitution detectors already run
- [ ] **Phase 4: P1 + P2 — Well-Posedness and the Channel (HALT GATE)** - One bundle, two verdicts, and the branch decision that routes the rest of the project
- [ ] **Phase 5: P3 Sign + P5 τ↔λ Bridge** - The tax-side gain settled: is `∂ν/∂λ_MEV` substitutable for `∂ν/∂τ_MEV`, and what is the composed sign
- [ ] **Phase 6: The Set-Point Law — Verdict and Correction** - A terminal verdict on the boxed `τ*_MEV` and, where it falls, a corrected law that carries its own verdict
- [ ] **Phase 7: EVM Feasibility of the Surviving Law** - Term-by-term realizability, signatures only, saturate-never-revert, loop and null-space resolution
- [ ] **Phase 8: Consolidation & Hand-off** - One consolidated spec, an honest gap register, and a hand-off with every peer coordination point named

## Phase Details

### Phase 1: Rulings & Ground Truth
**Goal**: Every notational, definitional and dimensional question that could make a proof be about the wrong object is closed by a recorded user ruling, and the plant's `∂`-partition exists on paper entry by entry.
**Depends on**: Nothing (first phase)
**Requirements**: NOT-01, NOT-02, NOT-03, NOT-04, NOT-05, NOT-06, HND-04, HND-05
**Success Criteria** (what must be TRUE):
  1. All 13 blocking decisions collected in `research/SUMMARY.md` carry a recorded ruling with its rationale — including which relation the boxed form solves, the `τ`-vs-`λ` substitution, `e^σ`'s status, `Δt`'s status, and the import-or-assume decision on demand elasticity. None is deferred.
  2. A notation-map paragraph resolves every named collision — `π^{\varphi}` (source: `π^{\phi} − π^{LVR}`; entry-point doc: the portfolio value function), the `L` overload (order ladder vs aggregate pool), `ν` vs `u`, leg pairing in `π^{\phi}`, the contractual-vs-replicated `π^σ`, and `PROJECT.md`'s self-minted `π^{\tilde\phi}` — and no symbol appears anywhere downstream that is not either in the source or in that map with a stated reason; one identifier scheme replaces the four researchers' non-aligned taxonomies (`P1–P4`/`C-P#-#`/`A#`, `B#`/`M#`/`N#`/`R#`, `FINDING A/B`/`W#`).
  3. The `(∂_(t+1,t), ∂_(x,u), ∂_(y,x), ∂_(y,u))` partition is written out entry by entry from the source, each entry classified as a constant, a Jacobian entry, or structurally zero — and in particular the document states plainly whether `∂_(t+1,t)` is the zero matrix, whether `u_en` contains non-actuators, and whether the `y` row for `π^σ` is structurally zero. No claim relying on the plant being non-degenerate is made anywhere before this exists.
  4. A unit/dimension ledger covers every symbol crossing the channel (at minimum `ΔQ_v*, L(i_K), π^l, π^σ, π̂^σ, π^φ, π^LVR, ν, σ², φ, τ_MEV, p_(η,Δ_i)`), the boxed law is checked against it, and any inhomogeneity found is routed to the user as a ruling request rather than silently repaired.
  5. `research/v2-controller/LEAN-MAP.md` and `EVM-CONTROL-PRIMITIVES-MAP.md` carry an explicit do-not-cite marker with the reason, and a review register exists that instantiates the two-step review (Reality Checker + one specialist, in parallel, blind) as a standing pre-commit gate — with this phase's own artifacts as its first passing entries.
**Plans**: TBD

### Phase 2: Frame Selection & EVM Substrate
**Goal**: `CONTROL-FRAME.md` v1 exists and is sha-pinned: the control-theoretic frame is selected and justified in writing, defensible against both Phase 1's entrywise plant result and the live Plank primitive inventory.
**Depends on**: Phase 1
**Requirements**: FRM-01, FRM-02, FRM-03, FRM-04, EVM-01
**Success Criteria** (what must be TRUE):
  1. The selected frame is named, and every excluded alternative — LQR/LQG/servo tracking, root locus, Bode/Nyquist, PID, the Kalman/Gramian rank test as a well-posedness tool, and the "static output feedback" name-collision — carries its own stated reason for exclusion.
  2. The frame selection cites Phase 1's entrywise `∂`-result explicitly. If `∂_(t+1,t)` is structurally zero the document says so and the frame is re-scoped to static inversion under uncertainty; dynamic-control machinery is not imported over a memoryless map. FRAME's `H = [1,−1]` controlled-variable resolution is adopted only if the entrywise check supports it, and the researcher tension is recorded either way.
  3. A well-posedness checklist for a *set-point* (as opposed to a regulator) is enumerated, and each of P1–P5 is explicitly testable against it — with `e^σ` declared as an equality constraint, not an objective, so a regulator over `e^σ` cannot creep in.
  4. The event-clock question is either resolved or declared OPEN with its consequences written down: whether `t` indexes swaps or blocks, whether event-averaged `ΔQ_M, ΔQ_X` may be combined with time-averaged `π^LVR·Δt, σ², λ`, and the PASTA/ASTA argument for why the combination is not free in a CFMM.
  5. Every literature citation entering the spec is verified against a primary source or carries an explicit UNVERIFIED tag — the five FRAME could not verify are each closed or tagged; and the fixed-point primitive inventory is re-derived from `cfmm-wt/plank` (never this worktree's `src/`, a confirmed stale mirror), superseding the 2026-06-28 map.
**Plans**: TBD

### Phase 3: Obligation Machinery & Cheap Detectors
**Goal**: Every obligation is stated in an idiom the Lean tree can actually carry, wrapped in a freeze/diff/gate protocol and a hand-off shape, and the cheap detectors have already been run — before one unit of Aristotle budget is spent.
**Depends on**: Phase 2
**Requirements**: PRF-06, PRF-07, PRF-08, PRF-09, PRF-10
**Success Criteria** (what must be TRUE):
  1. The numerical detector has **run** and recorded whether `τ*` lands in `[0,1]` under realistic parameters, and the back-substitution check has **run** and recorded whether the boxed form actually satisfies the relation Phase 1 ruled it solves. Both results are written down as findings — a range violation or a failed back-substitution is a refutation-in-waiting and is reported as such, not smoothed over.
  2. P1–P5 are each stated in the tree's native `Monotone`/`StrictAnti`/`ConvexOn` idiom wherever a sign or ordering claim suffices; any statement that genuinely needs differential-calculus infrastructure the tree does not have is flagged, with the cost of building that layer stated, rather than assumed available.
  3. A freeze-and-sha-pin protocol exists and is exercisable: each obligation is byte-frozen at submission time with a **section-scoped** sha (never a whole-file hash of the concurrently-edited entry-point doc), and the byte-diff procedure against what returns is written down.
  4. A six-point integration gate is written and is a stated precondition on every later landing: statement byte-diff (an added hypothesis is a disclosed narrowing and is reported; a renamed-but-weaker theorem is a MISS), `#print axioms` sweep, zero `sorry`/`admit`, proof-body triage (a one-tactic proof of a claim described as substantive is flagged, not counted), dependency byte-identity, and provenance.
  5. A self-contained PROOF-REQUEST hand-off template exists — obligations, the prompt, the module import closure re-derived from `lean/lakefile.toml` at assembly time (never from the do-not-cite `LEAN-MAP.md`), the module-origin map for the return rewrite, and the sha pins — with the owning peer session named as the delivery target and an explicit statement that no step of the pipeline runs in this worktree.
**Plans**: TBD

### Phase 4: P1 + P2 — Well-Posedness and the Channel (HALT GATE)
**Goal**: Verdicts on well-posedness and on the exclusivity of the 5-factor channel, requested in one bundle because they share the entire plant definitional payload, with the project's downstream routing decided by P2's outcome.
**Depends on**: Phase 3
**Requirements**: PRF-01, PRF-02
**Success Criteria** (what must be TRUE):
  1. `PRF-01` carries a terminal verdict (`PROVEN` / `CORRECTED` / `REFUTED` / `OPEN`-with-named-hypothesis) on whether the `∂`-partition is well-posed over event time and whether set-point optimization is legitimate given `φ_M ≡ φ̄_M ∀t` and `(β_j, γ_j)` frozen — with the freezing recorded as a declared modelling assumption and never justified by the non-existent "`(β,γ)` do not control `λ_MEV`" theorem.
  2. `PRF-02` carries a terminal verdict on the "no other path" clause. If it falls, the counterexample is exhibited; the direct monoid path `∂φ/∂τ_MEV = (1−φ_M)(1−φ_X)` displayed in the source's own `∇φ` is explicitly adjudicated rather than silently absent, and any surviving form of the claim is stated as a *restricted* claim whose restriction is checked for vacuity.
  3. Both verdicts pass Phase 3's six-point integration gate before being treated as landed, and `PROOF-LEDGER.md` records for each: the landed declaration names, every added hypothesis with its economic meaning, every narrowing, the axiom sweep, the build evidence, and the Aristotle project/task UUIDs.
  4. **The halt gate is executed and its branch is recorded in writing.** *P2 upheld* ⟹ Phase 5 proceeds as planned. *P2 REFUTED* ⟹ Phase 6's boxed-form obligation is settled by a recorded dependency refutation naming the voiding result instead of a spent bundle, and Phase 7 targets the corrected law rather than the boxed one. **In neither branch does the project abort** — a refutation with a witness satisfies the Core Value, and the salvage route in Phase 6 is the successor, not an exception.
**Plans**: TBD

### Phase 5: P3 Sign + P5 τ↔λ Bridge
**Goal**: The tax-side gain is settled — whether `∂ν/∂λ_MEV` may stand in for `∂ν/∂τ_MEV` at all, and what the composed sign actually is.
**Depends on**: Phase 4 (runs on both halt-gate branches — see Overview deviation 4)
**Requirements**: PRF-03, PRF-05
**Success Criteria** (what must be TRUE):
  1. `PRF-05` carries a verdict on the substitution as a first-class obligation, not an implicit step. If the substitution is illegitimate, the object every downstream statement uses is the explicit composition `Ḡ_(ν,λ_MEV) · ∂λ_MEV/∂τ_MEV`, written out — no new symbol is minted for it without a user ruling.
  2. The sign of `∂λ_MEV/∂τ_MEV` is settled by composing landed declarations by name (`tau_intensity_effect_strict`, `mevMulti_anti_phibar`, `mevTotal_eq_arb_of_sandwich_zero`) rather than asserted, and the resulting composed sign of `∂ν/∂τ_MEV` is stated.
  3. `PRF-03` carries a verdict on `Ḡ_(ν,λ_MEV) > 0`, or — if unprovable in-tree as the research predicts — is formalized as an explicitly named hypothesis with the missing `λ_MEV ↦ ν` map recorded as a definitional gap. No step attempts to estimate `Ḡ`'s magnitude from data; the verdict is sign-only and says so.
  4. The `|_{λ_MEV}` conditioning contradiction between the boxed objective and the boxed channel is resolved by user ruling before any statement is drafted, and the resolution is recorded.
  5. **Escalation gate:** if the composed sign is refuted or indeterminate, that is recorded and escalated to the user *before* Phase 6 attempts an inversion, rather than proceeding on an undefined one.
**Plans**: TBD

### Phase 6: The Set-Point Law — Verdict and Correction
**Goal**: A terminal verdict on the boxed `τ*_MEV`, and — where it falls — a corrected set-point law derived under the selected frame that itself carries a verdict. This phase delivers the project's Core Value.
**Depends on**: Phase 5
**Requirements**: PRF-04, SAL-01, SAL-02, SAL-03, SAL-04, SAL-05
**Success Criteria** (what must be TRUE):
  1. `PRF-04` carries a terminal verdict and is never left OPEN. The ledger states which relation the box was adjudicated against per Phase 1's ruling (level `π^σ ≡^R π̂^σ`, vega-matching, or as-written `∂π̂^σ/∂τ_MEV = ΔQ_v*`), with the rejected alternates named. Where Phase 4 or Phase 5 has voided its premise, the verdict is a recorded dependency refutation naming the voiding result rather than a spent bundle.
  2. For each refuted obligation the *specific defect* is recorded — which step, which line, which error class — not merely that it failed; and where nothing refutes, that is recorded explicitly as "no defects" rather than left blank.
  3. A corrected set-point law is derived under the Phase 2 frame, addressing the recorded defects, and is stated over an explicit domain carrying the branch structure the kinks force: the `(·)⁺` kink at the strike, the OTM branch where no interior solution exists (stated as a theorem about degeneracy, not as an omission), and the `min(·)` funded cap. If the law turns out to be implicit rather than closed, existence, uniqueness and monotonicity are stated as obligations.
  4. The corrected law is itself submitted through the same freeze-and-gate cycle and carries its own verdict in `PROOF-LEDGER.md` — a corrected law asserted but unverified does not satisfy this phase.
  5. Every assumption the corrected law rests on is declared as an assumption, with a real Lean declaration name and file wherever a prior result is cited; no assumption is justified by citing a theorem that does not exist, and no `by ring`/`by simp` bridge identity is presented as a substantive result.
**Plans**: TBD

### Phase 7: EVM Feasibility of the Surviving Law
**Goal**: `EVM-FEASIBILITY.md` analyses the law that actually survived Phase 6 for on-chain realizability — signatures only, no implementation, with an explicit honesty section.
**Depends on**: Phase 6
**Requirements**: EVM-02, EVM-03, EVM-04
**Success Criteria** (what must be TRUE):
  1. A term-by-term realizability table covers the surviving law, the required-but-missing fixed-point primitives appear as signatures only (`signedMulDiv`, `clamp`, `satAdd` — with scale convention, rounding mode, and why each is needed), saturate-never-revert is stated as a hard rule with both `(1−φ)` poles and the `ΔQ_v*` pole guarded, and domain bounds, rounding and a cost envelope are given.
  2. The analysis targets the form the verdicts actually left standing — a fixed-point form with an iteration count and convergence guard if the law is implicit, a piecewise/kinked gain if the channel is live only on the collateral-constrained branch, and branch-conditioned behaviour across `σ² ≷ σ_K²` — not the boxed one-pass expression. If no law survives, the document states what would have to be true instead.
  3. The `Σ_{i_K}` loop question is resolved rather than deferred: either `#_σ` is hard-capped and the bound stated, or the operator is collapsed to a closed form, or the cost is declared unbounded and the gas-DoS surface named.
  4. The null-space test `HF = 0` has been run and its result stated; if a disturbance-invariant controlled variable exists, the reduction of `τ*` to a stored constant and the resulting collapse of the per-swap cost is quantified.
  5. The mandatory honesty section states that nothing in the document is proof-backed (LeanEVM is removed from the toolchain, so no fixed-point reasoning is available in-tree) and that every primitive citation is against `cfmm-wt/plank`; no `.plk` or `.sol` artifact is produced anywhere under this worktree and no diff touches `src/`, `script/`, `foundry.toml` or `test/`.
**Plans**: TBD

### Phase 8: Consolidation & Hand-off
**Goal**: The project's output is one consolidated, reviewed spec with an honest gap register and a hand-off whose every cross-worktree coordination point is named and owned.
**Depends on**: Phase 7
**Requirements**: HND-01, HND-02, HND-03
**Success Criteria** (what must be TRUE):
  1. `GAP-REGISTER.md` lists every open item with severity and disposition (in-scope vs deferred) — including the event-clock question, every obligation left as a named hypothesis, the grid-map-vs-marginal-price question (`DOC` Proposition 10, unproved in-tree), the quasi-static validity condition, and the deferred closed-loop regulator over `e^σ`. Nothing that was found is missing from it.
  2. `TAU-MEV-SETPOINT-SPEC.md` integrates frame, verdicts, salvage and EVM analysis, and contains no detail that duplicates an owning document — each section delegates by explicit `> Authoritative detail:` pointer, and the consolidated doc is written last.
  3. The hand-off to a future implementation milestone is defined, with every cross-worktree coordination point named and its owning peer session identified (the Lean tree and the Aristotle key with Lean4+Math; `src/` and the entry-point doc with `ul2inqpl`; `test/` with the Solidity-testing session), and peer identity re-verified via `list_peers` rather than trusted from a stale PID.
  4. Findings against peer-owned documents — the Rule 9 sizing map conflict, the `SRC:106`/`SRC:118` errata, the misquoted `(β,γ)` theorem — are routed through the gap register and a peer message, never fixed in the peer's tree from here.
  5. Every artifact in `spec/` appears in the review register having passed the two-step review, and no diff produced by this project touches the repo-root `.planning/`, `src/`, `test/`, `plank/`, or `lean4-spec/`.
**Plans**: TBD

## Halt Gate — explicit branch semantics

The single halt gate lives at the end of **Phase 4** and turns on `PRF-02` (P2, the
"no other path" clause), which 4 of 4 researchers predict will refute.

| Branch | Phase 5 | Phase 6 | Phase 7 | Phase 8 |
|--------|---------|---------|---------|---------|
| **P2 upheld** (possibly restricted) | Runs as planned | `PRF-04` adjudicated by a submitted bundle; salvage engages only where a defect was found | Analyses the surviving law | Unchanged |
| **P2 REFUTED** | **Still runs** — the corrected law's sign rests on the same composition | `PRF-04` settled by recorded dependency refutation (no bundle); `SAL-02`…`SAL-05` become the phase's main work | Analyses the **corrected** law; if none survives, states what would have to be true | Unchanged; the refutation and its witness are the headline deliverable |

A secondary **escalation gate** sits at the end of Phase 5: if the composed sign of
`∂ν/∂τ_MEV` is refuted or indeterminate, Phase 6's inversion is undefined and the
situation is escalated to the user rather than proceeding.

**Neither gate can terminate the project.** The Core Value is a verdict; the 2026-08-08
scoping decision extends it to a corrected law. Both branches reach Phase 8.

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Rulings & Ground Truth | 0/TBD | Not started | - |
| 2. Frame Selection & EVM Substrate | 0/TBD | Not started | - |
| 3. Obligation Machinery & Cheap Detectors | 0/TBD | Not started | - |
| 4. P1 + P2 — Well-Posedness and the Channel | 0/TBD | Not started | - |
| 5. P3 Sign + P5 τ↔λ Bridge | 0/TBD | Not started | - |
| 6. The Set-Point Law — Verdict and Correction | 0/TBD | Not started | - |
| 7. EVM Feasibility of the Surviving Law | 0/TBD | Not started | - |
| 8. Consolidation & Hand-off | 0/TBD | Not started | - |

## Requirement Coverage

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | NOT-01, NOT-02, NOT-03, NOT-04, NOT-05, NOT-06, HND-04, HND-05 | 8 |
| 2 | FRM-01, FRM-02, FRM-03, FRM-04, EVM-01 | 5 |
| 3 | PRF-06, PRF-07, PRF-08, PRF-09, PRF-10 | 5 |
| 4 | PRF-01, PRF-02 | 2 |
| 5 | PRF-03, PRF-05 | 2 |
| 6 | PRF-04, SAL-01, SAL-02, SAL-03, SAL-04, SAL-05 | 6 |
| 7 | EVM-02, EVM-03, EVM-04 | 3 |
| 8 | HND-01, HND-02, HND-03 | 3 |
| **Total** | | **34 / 34** |

No orphaned requirements. No requirement mapped to more than one phase.

## Standing constraints (apply to every phase)

- All GSD commands run with `--cwd control`. The repo-root `.planning/` is read-only.
- Notation is binding. No symbol is minted without a user ruling, in artifacts *and* in
  Aristotle prompts.
- Every artifact passes the two-step review (Reality Checker + one specialist, in parallel)
  before it is committed or executed — never deferred.
- Every prior-result citation carries a real Lean declaration name and file.
- `DOC` is cited by Definition/Rule/Theorem number plus a commit sha, never by line number.
- Aristotle: full UUIDs only; never `aristotle show`; never parallel `continue` on one
  project; on `OUT_OF_BUDGET` a single `continue` on the same project; never integrate a
  sorry-carrying partial and never hand-prove the gap.

---
*Roadmap created: 2026-08-08*
