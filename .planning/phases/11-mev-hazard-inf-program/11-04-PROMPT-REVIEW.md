# 11-04 — Two-reviewer gate on Aristotle prompt B (T20–T30)

The gate runs on **the prompt** — the artifact the prover actually consumes — not on the plan
(11-RESEARCH PIT-7). Both reviewers were spawned as **independent read-only processes in parallel**
(`claude -p`, `--permission-mode plan`), each given the artifact, the landed Lean modules, the
user-approved addendum and the research file, and each charged with a distinct question set. Neither
was shown the other's findings, and neither could edit any file.

| Field | Value |
| --- | --- |
| artifact reviewed | `scratch/aristotle-mev-joint-PROMPT.txt` |
| pre-review sha256 | `9a33f2f57d5bf7d2fac6bf90e032611c8d92247df18dc968b16250330521c0a6` (760 lines) |
| post-resolution sha256 | `f471801914b304aa4c2cc44f4412ef7d1a7104d7fe6b6f6ac8c7a8454c819a12` (850 lines) |
| reviewers | Reality Checker (mandatory) + Model QA Specialist |
| verdicts | **NEEDS WORK** and **NEEDS WORK** |
| findings | **2 BLOCKER (the same one, found independently), 2 MAJOR, 8 MINOR, 1 DOC-LEVEL** |
| blocking rows unresolved at close | **0** |

## Reviewer 1 — Reality Checker (mandatory, per the global two-step rule)

Role file `~/.claude/agents/testing/testing-reality-checker.md`. Charged with: is T24 asked for
honestly (formal refutation shape, explicit numeral witnesses, accurate difficulty)? Is the T25
anti-relabelling instruction unambiguous? Do T20–T22 carry `hφ0 : 0 ≤ φbar`, and are the drafted
hypothesis blocks *sufficient* to discharge each conjunct from the landed lemmas? Is the
ADD-the-hypothesis instruction present? Does any statement cite a `MevOptimization.` /
`FlairOptimization.` / `VolInstrument.` name that does not exist, or quote a signature that does not
match? Is `mevTotal` defined rather than left to the prover? Does any theorem statement carry a
numeric Angstrom constant? Is T27's `IsMinOn` iff true over the stated packing? Is T29's isotone
direction right? Is the new path-level treatment of T25 correct?

**Verdict: NEEDS WORK.** 1 BLOCKER, 1 MAJOR, 3 MINOR.

The reviewer re-derived the prompt's covariance sketch by hand and confirmed it correct
(`∂ₓ h = −σc/(σ+xc)²` is increasing in `σ` iff `σ > xc`), diffed every quoted signature
byte-for-byte against the landed modules, and verified all four Mathlib Jensen citations including
line numbers. It explicitly cleared: T24's honesty, the `hφ0` presence and sufficiency across
T20–T22, the ADD-the-hypothesis instruction, zero phantom names, no numeric constant in any
statement, T27's packing, T29's direction, the path-level argument, and the absence of any request
exceeding the approved document.

## Reviewer 2 — Model QA Specialist

**Specialist pick and reason.** The catalog's Model QA Specialist
(`~/.claude/agents/specialized/specialized-model-qa.md`), operated in the quantitative-finance /
market-microstructure register. It is the closest catalog match to an artifact whose content is AMM
fee design, MEV and arbitrage-hazard modelling, and batch-auction protocol mechanics — and it is
**deliberately the same pick as 11-01 and 11-02**, so that the three gates of this phase are
comparable to one another rather than each measuring something different.

Charged with: is "a flat fee minimizes MEV at fixed fee income" correct economics, and is the
aligned-measure caveat foregrounded? Is the top-of-block auction defensibly modelled as a `(1−τ)`
rescaling given the live protocol's creator/protocol/LP split? Is `Δt`-as-batch-cadence the right
identification and `mev_mono_dt`'s isotone sign the right one? Is "uniform batch clearing nulls the
sandwich channel" correct, and is the hazard-side composition the right algebra? Is the degeneracy
believable or an artifact of volume-inelasticity? Anywhere a drafted statement would be
economically misleading once machine-checked and cited?

**Verdict: NEEDS WORK.** 1 BLOCKER, 1 MAJOR, 5 MINOR, 1 DOC-LEVEL.

It passed the constrained result's economics, the LP-incidence framing, the cadence identification
and the intra-batch sandwich claim, and confirmed the degeneracy is believable in-model as an
artifact of inelasticity.

## The BLOCKER — found INDEPENDENTLY by both reviewers

Both reviewers, working in parallel without sight of each other, converged on the same defect:
**the prompt's drafted `mevTotal` applied `VolInstrument.probOr` to unbounded hazards**, which is
exactly what the approved document's block M7 forbids in the sentence the prompt itself quotes
verbatim two hundred lines earlier:

> "`⊕` is hazard-side addition — **plain addition of rates** … The `⊗_φ` operation itself acts on
> probabilities in `[0,1]` and is **NOT applied to the unbounded hazards directly**."

`VolInstrument.probOr` **is** that `⊗_φ` operation (`VolInstrument.lean:257`,
`probOr a b = a + b - a * b`).

The executor verified the finding independently against two sources before acting, rather than
taking either reviewer's word:

1. The addendum's M7 text, read directly — quoted above.
2. **The already-proven `VolInstrument.probOr_hazard` (`VolInstrument.lean:295`), which is itself
   the decisive evidence**: it states
   `probOr (1 - exp (-lamM)) (1 - exp (-lamX)) = 1 - exp (-(lamM + lamX))`. The hazard-side image of
   `probOr` *is* `lamM + lamX`. The correspondence lemma the project already owns says the aggregate
   is plain addition.

**Why it would have survived the machine check.** At `λ_sandwich = 0` both reduction theorems hold
under either definition (`probOr a 0 = a` and `a + 0 = a`), so the file compiles green, the axiom
sweep is clean, and 11-05's fidelity diff passes. The defect only detonates when a later consumer
cites `mevTotal` at a nonzero sandwich hazard — where `probOr` subtracts an interaction term
meaningless between two rates, and above 1 stops being monotone entirely (`probOr 2 2 = 0` reports
two active extraction channels as zero total MEV). This is the precise failure mode the gate exists
to catch: a wrong definition of the phase's headline object, shipped under a green build.

**Provenance of the error, recorded rather than absorbed.** The `probOr` form was specified by
**11-04-PLAN.md's own Task-1 action text**, which the executor followed literally. The approved
document contradicts the plan, and the document is binding — the same doc-over-plan adjudication
11-02 made at its `·Δt` BLOCKER. The plan was wrong in one more place than its own authoring caught.

## Resolution

| Severity | Finding | Disposition | Where fixed |
| --- | --- | --- | --- |
| BLOCKER | RC-B1 / QA-B1 (same defect, found independently): `mevTotal` defined as `probOr` of two hazards, contradicting M7's "plain addition of rates" and invisible to the machine check | RESOLVED — redefined as `lamARB + lamSand`, reductions close by `add_zero`; added a new named lemma `mevTotal_probOr_hazard` carrying the `⊗_φ`↔`⊕` correspondence via the already-proven `VolInstrument.probOr_hazard`; deleted the "unfold `probOr` and close by `ring`" fallback that confirmed the wrong intent; added an explicit multi-sentence prohibition explaining why the error is invisible | prompt T30 block |
| MAJOR | RC-M1: T24 outcome 2 permits an added hypothesis that forces the fee path constant — letter-compliant, but banks the trivial constant-σ collapse as the hard result without violating the anti-relabelling clause | RESOLVED — added a binding EXCLUSION paragraph to outcome 2: any added hypothesis forcing `fun t => φfun (σpath t)` constant on `Finset.range T`, including any constancy hypothesis on `σpath`, does not count as outcome 2 and must be reported as "T25 delivered, T24 OPEN" | prompt T24 outcome 2 |
| MAJOR | QA-M1: mandated module docstrings omit M8's SCOPE OF THE AGGREGATE caveat, in the one module that names an object "the total"; two excluded channels (multi-block censoring, cross-batch sandwiching) attack T29 and T30 directly | RESOLVED — added mandated module-docstring caveat (vi) transcribing M8's scope item verbatim in substance, and added an intra-batch bounding clause to T30's docstring requirement | prompt module-docstring section and T30 block |
| MINOR | RC-m1 / QA-m2 (same): `mevNet`'s docstring calls `(1−τ)·mevMulti` the M7(i) LP-net object, conflating `λ_ARB` with `λ_MEV` against the module's own two-symbol rule | RESOLVED — added a TWO-SYMBOL NOTE to the mandated `mevNet` docstring routing the identification explicitly through T30's uniform-clearing reduction | prompt T26 block |
| MINOR | RC-m2: T27's mandated rationale says the equivalence is "vacuous" at `τ = 1`; it is in fact false in general (LHS holds for every `θ`, RHS need not) | RESOLVED — rewritten to state the left side holds trivially for every `θ` and the equivalence fails, with "vacuous" removed | prompt T27 block |
| MINOR | RC-m3: fee-nonnegativity quantifier inconsistent across siblings — `∀ t` in T24 and its negation, `∀ t < T` in T25 | RESOLVED — bounded to `∀ t < T` in T24, in the negation theorem and in the surrounding prose, so all three siblings agree and the hypothesis is the minimal one the sum needs | prompt T24 statement, negation theorem, prose |
| MINOR | QA-m1: T29 is the partial effect through `ptrade` at fixed `a` and `T`, while M3(i)'s weight carries its own `Δt`; and M8's sub-second empirical bound is absent from the cadence-policy theorem | RESOLVED — added two mandated docstring qualifications: the partial-vs-calendar-time reconciliation (same sign in both readings) and M8's ≳1s validity bound with the jump-diffusion note | prompt T29 block |
| MINOR | QA-m3: under the disclosed creator/protocol/LP split, `taxFraction k` is an upper bound on LP incidence, not the LP incidence | RESOLVED — added the consequence to the mandated T28 docstring: LP incidence is `LPshare · k/(k+1)`, so `taxFraction k` is the ceiling attained only in the pure-LP-rebate case | prompt T28 block |
| MINOR | QA-m4: `τ`-invariance of extraction implicitly assumes searcher participation is inelastic in `τ` | RESOLVED — added the searcher-side elasticity caveat to the mandated `mevNet` docstring, explicitly distinguished from the monopoly/collusion caveat (which is about realized `τ`, not about extraction moving) | prompt T26 block |
| MINOR | QA-m5: the volume-inelasticity qualifier is mandated only at module level, but T22 is the individually-citable "no trade-off" theorem | RESOLVED — T22's own docstring now required to carry the qualifier, in the isotone-FLAIR / antitone-hazard terms that make the artifact visible | prompt T22 block |
| DOC-LEVEL | QA: M7(i)'s display juxtaposes `λ_MEV^LP-net = (1−τ)λ_MEV` with `τ(k) = k/(k+1)`, which reads as "LP incidence = full tax fraction", while the doc's own prose two sentences later records a creator/protocol/LP split | ESCALATED to the user at the Task-3 checkpoint; the approved document is NOT edited, and the prompt-side mitigation (QA-m3) is already in place so no theorem statement carries the conflation | escalation only — surfaced in the checkpoint message |

## Mathlib Jensen lookup (11-RESEARCH Open Question Q5 — unverified at research time)

Q5 asked for one grep at bundle-build time, because the finite-sum Jensen lemma name was never
verified. Run against the pinned toolchain at
`lean/.lake/packages/mathlib/Mathlib/Analysis/Convex/Jensen.lean`. The names below **exist** and are
now cited in the prompt with their line numbers rather than guessed:

| Lemma | Line | Shape |
| --- | --- | --- |
| `ConvexOn.map_centerMass_le` | 52 | un-normalized `Finset.centerMass` form; `(h₀ : ∀ i ∈ t, 0 ≤ w i) (h₁ : 0 < ∑ i ∈ t, w i)` |
| `ConvexOn.map_sum_le` | 67 | normalized form; requires `∑ i ∈ t, w i = 1` |
| `StrictConvexOn.map_sum_lt` | 103 | strict form; requires `0 < w i` on the WHOLE index set, plus `∃ j ∈ t, ∃ k ∈ t, p j ≠ p k` |
| `StrictConvexOn.map_sum_eq_iff` / `_iff'` | 182 / 218 | equality case |

The strict lemma's `0 < w i` requirement on the whole index set is what drives T25's positive-weight
hypothesis, and the prompt now says so. Reviewer 1 independently re-verified all four citations
including the line numbers.

## Executor-found, independent of both reviewers

**The plan's T25 as drafted was a triviality, and was corrected before either reviewer saw it.**
11-04-PLAN.md specifies T25 at the SCHEDULE level (`φfun` applied to a constant `σpath`). In that
form the statement is empty: with `σ_t ≡ σ0`, `φfun (σpath t) = φfun σ0` is already constant in `t`,
both sides collapse to `pathWeight w D T * ptrade (φfun σ0) σ0 Δt`, the inequality is an EQUALITY,
and the strict half's non-constancy hypothesis is **unsatisfiable** — so the strict statement is
vacuous. It would have returned "proved" and been banked as the delivered fallback while carrying no
content.

This is not a defect of the document — it is the document's OWN `OPEN` note in M6b, which says in
terms that M6b "does NOT deliver a comparison between fee SCHEDULES, because every schedule in
`Θ_φ` is a function of `σ` alone and therefore already produces a constant path when `σ` is
constant — the strict half has no bite inside `Θ_φ` in this regime."

Resolution: section (B) now introduces path-level carriers `flairPath` / `mevPath` with two
definitional bridge lemmas (`flairPath_schedule`, `mevPath_schedule`) to the existing schedule-level
functionals, and states T25 at the PATH level — which is the document's own quantification, and
where the Jensen argument has real content. T24 stays at the schedule level, where varying `σ` makes
it non-vacuous, and keeps the plan's display verbatim. Reviewer 1 was charged with checking this
move and confirmed it independently: correct, matching M6b word-for-word, nothing lost.

## Notation gate runs — both recorded, the failing one not suppressed

| Target | Result |
| --- | --- |
| `model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` (the approved addendum) | **PASS** |
| bundled doc's extracted `### MEV` section (186 lines) | **PASS** |
| `scratch/aristotle-mev-joint-PROMPT.txt` (informational) | **FAIL — PIT-1** |

The prompt's failure is the anticipated mention-versus-use case and is **not** a defect. Both hits
are the prohibition itself — line 77 "Do NOT introduce an identifier named `η`" and line 778 the
same instruction in the PROHIBITIONS block. The gate is written for documents, where `η` must not
appear as a *used* symbol; a prompt that forbids the glyph necessarily names it. Adjudicated as
benign and recorded rather than suppressed, on the 11-01 precedent where the whole-file gate run
against the plank document failed on that document's own legitimate pricing-kernel `η` and the
failing run was recorded beside the passing extracted-section run.

## Doc fidelity re-verified after every prompt edit

| Check | Result |
| --- | --- |
| bundled doc sha256 == `BUNDLED-DOC-SHA256` from 11-02 | **PASS** — `671000a5…5fba58` |
| bundled doc M-blocks vs approved addendum | **PASS** — empty diff, 181 lines each |
| LIVE plank doc M-blocks vs approved addendum | **PASS** — empty diff |
| whole-file live plank doc sha256 vs approved | **MISMATCH, EXPECTED** — `1763faf9…` vs `671000a5…` |

The live plank file has grown 646 → 745 lines since the 11-02 pin (an endogenous-maturity block,
LEAN annotations, and the decided recalibration law). **Every one of those changes sits OUTSIDE
`### MEV`**, which is why the operative M-block check is empty on all three copies while the
whole-file hash differs. The mismatch is expected and documented; the M-block diff is the gate, and
it holds.

## Verdict

Both reviewers returned NEEDS WORK. Every BLOCKER and MAJOR row is RESOLVED in the prompt; no
blocking row remains open. One DOC-LEVEL finding is escalated to the user rather than fixed, because
the fix would require editing an approved, plank-owned document — and the prompt-side mitigation is
already in place, so no theorem statement can carry the conflation. The prompt is cleared for the
Task-3 submission checkpoint, at which the user's explicit authorization is still required.
