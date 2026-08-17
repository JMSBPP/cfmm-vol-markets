---
phase: 12-eta-tradeoff-optimum
plan: 02
subsystem: vol_markets / Lean4 formalization pipeline
tags: [aristotle, curvature, capponi-jia, eta, reviewer-gate, bundle, sha-pinning, kink]
requires:
  - phase: 12-01
    provides: "The APPROVED E0-E8 curvature spec, APPROVED-ETA-SHA256 4f5362c1..., the kappa_varphi notation, and the NARROWED CTX-DEGEN ruling"
  - phase: 11
    provides: "MevOptimization / MevJointProgram / FlairOptimization as proven bundle inputs and the Theta_phi corner results T29'-T31' contrast against"
provides:
  - "One in-flight Aristotle task: project 4878ca32, task e1c846ae, carrying T1'-T31'"
  - "The 18-module bundle with a PROVEN import closure"
  - "12-02-MODULE-MAP.txt — the module-origin map 12-03's non-uniform inverse rewrite drives from"
  - "12-02-RUN-RECORD.md — submission provenance, sha pins, and the T1'-T31' fidelity checklist with OPTIONAL items flagged"
  - "12-02-PROMPT-REVIEW.md — two-reviewer verdicts and the resolution table"
  - "THREE ESCALATE rows: defects found in the APPROVED, byte-pinned document itself"
affects:
  - "12-03 (landing) — the module map, the sha pins and the fidelity checklist all come from here"
  - "12-04 (traceability) — INHERITS the deferred document amendment for ESC-1/ESC-2/ESC-3"
tech-stack:
  added: []
  patterns:
    - "Non-uniform inverse import rewrite driven by a written module-origin map, not a single sed"
    - "Import closure PROVEN at bundle time rather than trusted from a plan's list"
    - "Verbatim doc-block splicing by script, so quoted specification text is byte-faithful by construction"
    - "Reviewer BLOCKERs that land in the approved DOC are escalated and neutralized in the prompt, never silently fixed"
    - "Amendment ordering: never amend a pinned doc while a task proves against it"
key-files:
  created:
    - .planning/phases/12-eta-tradeoff-optimum/12-02-MODULE-MAP.txt
    - .planning/phases/12-eta-tradeoff-optimum/12-02-PROMPT-REVIEW.md
    - .planning/phases/12-eta-tradeoff-optimum/12-02-RUN-RECORD.md
    - .planning/phases/12-eta-tradeoff-optimum/12-02-SUMMARY.md
    - scratch/aristotle-eta-curvature/ (18 modules + doc; gitignored)
    - scratch/aristotle-eta-curvature-PROMPT.txt (1232 lines; gitignored, sha-pinned)
  modified: []
key-decisions:
  - "Bundle is EIGHTEEN modules, not the plan's seventeen — JitLiquidity landed mid-plan and the binding rule is doc + ALL proved modules"
  - "The bundled doc copy was NOT re-copied at submit time — it is the gated frozen artifact and the live file was under concurrent edit"
  - "cOne ships as a DEFINITION, not a free parameter — freeing it falsifies the T10' branch agreement the peak rests on"
  - "T17'b added as a new REQUIRED item: E5's zero-sum identity, the clean statement T18' can safely omit"
  - "USER: submit now, amend the document later (12-04) — never desync the pinned copy from what Aristotle proves against"
patterns-established:
  - "Independently re-verify a reviewer's counterexample before escalating it — a false escalation costs as much as a missed one"
  - "A prompt may quote a false sentence as approved-doc text provided it also forbids formalizing it"
metrics:
  duration: ~3h
  tasks: 3
  files: 4
  completed: 2026-07-31
---

# Phase 12 Plan 02: Aristotle ETA Curvature Bundle Summary

An 18-module bundle and a 1232-line T1'–T31' specification — Capponi's curvature layer, the
interior optimum, the closed form `η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)` obtained by inverting a
bijection at a kink, and the Phase-11 contrast — submitted as a single in-flight Aristotle task
after a two-reviewer gate that found a typechecking defect on the headline chain, a false theorem
statement, and **a false sentence in the approved, byte-pinned specification itself**.

## What was built

**The bundle** (`scratch/aristotle-eta-curvature/`, gitignored per Phase-11 precedent): 15
`vol_markets` modules + the 3 `CFMM.Eta` modules the η-bridge consumes, plus the user-approved
document. The **import closure was PROVEN, not assumed** — all 14 distinct
`import RequestProject.X` lines resolve to bundled files. This is the check that catches the
`CESLongVolPayoff` omission class: 12-RESEARCH F7.3 proposed 15 modules and missed it, and without
it `EtaReplication` does not elaborate. All 18 copies are byte-identical to the landed modules
under the inverse rewrite.

**`12-02-MODULE-MAP.txt`** — 18 `<module> <origin-library>` rows. This exists because the return
rewrite is **not a single sed**: `import RequestProject.eta` must become `import exp.eta` while
`import RequestProject.VolInstrument` must become `import vol_markets.VolInstrument`. A blanket
substitution produces `import vol_markets.eta`, which does not exist.

**The prompt** — 35 numbered items. E0/E1/E2/E3/E4/E5/E6/E7 are spliced VERBATIM from the bundled
document by script, so the quoted specification is byte-faithful by construction rather than by
careful transcription; a post-splice check confirmed each block appears exactly.

**Submitted:** project `4878ca32-d04c-4e19-9c3b-394a1427fb8b`, task
`e1c846ae-f276-46c3-a3d1-bae9f24266fb`, `IN_PROGRESS`. Queue proven clear first — 20/20 projects
`IDLE`, zero projects matching `eta-curvature`, so this is unambiguously a NEW project.

## What the reviewer gate caught

Reality Checker + Model QA Specialist, independent OS processes, in parallel, blind to each other.
**Both returned NEEDS WORK: 2 BLOCKER, 1 MAJOR, 11 MINOR, 0 rows unresolved.** Both BLOCKERs were
on the deliverable path of a one-shot, non-refundable run.

**1. The headline chain did not typecheck.** `lpExcessEta` applied EIGHT arguments to the
SEVEN-parameter `lpExcess`, and its extra binder `cOne` shadowed the `cOne` DEFINITION that the
same prompt spends a paragraph insisting is not free. That is T27'→T28'→T30'. The prover would
have resolved the contradiction unsupervised, and the wrong resolution — an `lpExcess` with a free
`cOne` slot — **silently falsifies the T10' branch agreement at `kphiI` on which the entire peak
depends**. Written in Task 1, before Task 2 established that `cOne` must be a definition; exactly
the kind of internal drift a whole-artifact review exists to catch.

**2. THE APPROVED DOCUMENT CONTAINS A FALSE SENTENCE, and I had mandated it verbatim into a
permanent Lean docstring.** Block E7 asserts that a nonnegative weighting
`w₁(−arbLoss) + w₂·surplus` has branch-constant derivative sign and so "peaks at a branch point
only by accident of the weights". True on the two OUTER branches. **False on the middle region**,
because the two ratios switch branches at *different* points — `arbLoss` at `κ_φ,S`, `surplus` at
`κ_φ,I` — so on `[κ_φ,S, κ_φ,I]` the derivative is a difference of a decreasing `1/κ_φ²` term and
an increasing `1/(1−κ_φ)²` term.

**I recomputed it rather than trusting the reviewer.** At `φ=0, ϖ_A=1, ϱ_S=0.5, ϱ_I=3, w₁=2,
w₂=1`: `κ_φ,S ≈ 0.183503`, `κ_φ,I = 0.5`, derivative `+0.637` at `0.19` → `−1.403` at `0.45`,
crossing at **`κ_φ ≈ 0.2412` — a stationary interior maximum strictly inside the middle region, at
no branch point.** Confirmed. (The reviewer's own numeric location, `≈0.29`, was slightly off; the
finding was not.) E7's *displayed* formula for `[0, κ_φ,S]` is correct — only the generalization
fails.

**3. T8' was FALSE as displayed.** It guards `premShock` against `Real.sqrt`'s junk value and
misses the symmetric guard on `premInv`: at `fee=0, premShock=0, premInv=-2`,
`Real.sqrt (1/(-1)) = 0` gives `kphiI = 1` and `kphiS = 0`, so `kphiS ≤ kphiI` holds while
`premShock ≤ premInv` is `0 ≤ -2`. The reverse direction fails. T8' was also not on the
anti-narrowing list, so a quiet weakening of the iff to a one-directional implication under the
requested name would have been undetectable downstream. Both fixed.

All 11 MINORs were fixed too, including a `1/(1−curv)` pole family the pre-empt never named, an
`rfl`-grade `kphiStar_eq_kphiI` whose docstring over-read it (the `arb_add_fee_eq_lvr` failure mode
recurring), a T6'/T18' internal contradiction, and T16' importing `0 < cOne` where the anchor is
unconditional.

**What the reviewers cleared** matters as much: no FOC anywhere; the T24' inversion algebra
re-derived against `VolInstrument.lean:30`; the 18-module closure re-derived independently;
**all thirty Mathlib citations real and line-exact, zero phantom hints**; every quoted signature
byte-exact; `cOne` verified term-by-term to BE the anchor's `τ₁` against (A.50); T17's formula
re-derived from (A.56); no doc-vs-PDF disagreement anywhere.

## The document-amendment ordering decision (USER)

The user was given the full ESC-1 explanation and ruled **PROCEED**, with the amendment
**DEFERRED to after the bundle lands**. That ordering is the substance, not a formality: amending
`## ETA` while the task is in flight would break `APPROVED-ETA-SHA256`, and 12-03's landing-time
fidelity check would then compare the return against bytes that no longer exist. **12-04 inherits
the amendment** for ESC-1 (E7's false sentence), ESC-2 (E0's misattributed `ϖ_I > 0` justification
— the strict increase survives at `ϖ_I = 0`; the PEAK is what fails, via `c₁ < 0`) and ESC-3
(E0 omits `θ < 1`).

The document was NOT edited by this plan. `APPROVED-ETA-SHA256` is intact, plank HEAD is untouched,
and nothing under `../plank/` was committed.

## Deviations from plan

**[Orchestrator-directed] EIGHTEEN modules, not seventeen.** `lean/vol_markets/JitLiquidity.lean`
landed after the plan was written. Under the binding rule (bundle = doc + ALL proved modules) it is
included, so every `17`/`SEVENTEEN` literal reads `18`/`EIGHTEEN`, including the prompt's
"18 existing `.lean` files" and the module map's row count. Its imports are inside the closure, so
it adds no dependency. The plan's acceptance criterion `grep -q '17 existing'` was deliberately
not satisfied; `18 existing` was verified instead.

**[Rule 2 — missing critical content] T17'b added as a new REQUIRED item.** E5's zero-sum identity
— that on the corner branch investor surplus and LP revenue sum to `ϱ_I/2` — is approved,
provable, and is the sharp statement of what curvature does below the peak. The plan did not
number it. It was added because T18' (welfare) is optional and genuinely may be false as weighted,
so without T17'b the phase could return nothing at all from E5's clean content.

**[Rule 1 — bug] `cOne` resolved as a DEFINITION against the plan's own wording.** The plan's T9'
lists `cOne` among the free parameters while also requiring the `kphiI` branch agreement and the
`0 < cOne` restriction. Those are inconsistent: the identity `c₂(κ_φ,I) = c₁/κ_φ,I` holds only for
E4's closed form. Resolved in favour of the definition, which E4 displays; the restriction enters
as a hypothesis. Reviewer 2 independently confirmed this is "the one place where freeing it would
silently break branch agreement".

**Mechanical-criterion defects, recorded not papered over.**

1. **The plan's Mathlib verification grep is broken and reproduces the exact failure it was written
   to prevent.** It anchors `^(theorem|lemma) (StrictMonoOn|StrictAntiOn|MonotoneOn)` against
   `Order/Monotone/Union.lean`, where every gluing lemma is `protected theorem`. Run as written it
   returns NOTHING — the 11-02 phantom-hint signature — and would have caused the central gluing
   route to be dropped. Re-run without the anchor, all six exist at the cited lines
   (29/58/65/71/77/112). The plan's line numbers are right; 12-RESEARCH's are off by one for three
   of them.
2. **`! grep -q 'aristotle continue' <run-record>` cannot distinguish an invocation from an
   assertion of absence.** An honest record stating the subcommand was not used fails it. The
   record is phrased to avoid the literal and says so.
3. **`git status --porcelain lean/ model/exp/` false-fails**, as 12-01 already documented:
   `model/exp/eta.md` was modified and `eta_pi_trader_delta_control.md` untracked before this plan
   began. Verified the stronger correct property instead — `lean/` porcelain empty throughout, and
   `model/exp/` byte-identical to the 12-01 baseline (`git diff` sha256 `679e1aa3…`, unchanged
   across every commit).
4. The plan's `grep -qF 'AntitoneOn\` is a NARROWING'` criterion is unbalanced-quoted and cannot
   run; the documented alternative `grep -qi 'must return .StrictAntiOn'` was used.

## Not established

- **Nothing is proven.** The task is `IN_PROGRESS`. No `.lean` file was created or modified by this
  plan, and no mathematical claim in the prompt has been machine-checked. Everything in the
  T1'–T31' checklist is a REQUEST.
- **The three OPTIONAL items may well come back absent** — T18' (welfare), T18'b (the `c₁ ≤ 0`
  refutation), T28'b (the factor-share half of the η identity). An omission of any is a correct,
  recordable outcome and must not be written up as a failure; equally, T28'b must not be scored as
  delivered if satisfied by restating T28'a.
- **The equilibrium transfer and the object-level identification remain ASSUMPTIONS** (E8(1)), and
  the prompt mandates that into the module docstring: every returned theorem is a theorem about the
  displayed functions composed with `curvIndex`, and none is a theorem about this project's AMM.
- **The Phase-11 degeneracy is not resolved and this plan asked nothing that would resolve it.**
  Section (D) is a contrast, per the user's narrowed CTX-DEGEN ruling.
- **ESC-1/ESC-2/ESC-3 are open against the document** until 12-04 amends it.

## Verification

| Check | Result |
| --- | --- |
| bundle module count | 18 `.lean` + 1 doc |
| import closure | PROVEN — 14 distinct imports, all resolve |
| byte-identity vs landed modules | 18/18 identical under inverse rewrite |
| no residual `import vol_markets` / `import exp.` | PASS |
| toolchain pin | `leanprover/lean4:v4.28.0` |
| module map | 18 rows; `eta`/`CESLongVolPayoff`/`EtaReplication` → `exp` |
| DOC FIDELITY (a) section sha vs APPROVED | PASS — `4f5362c1…`, at assembly AND at submit |
| DOC FIDELITY (b) E-block diff vs addendum | PASS — empty, 245 lines |
| live plank ETA section at submit time | identical to the pin, despite two whole-file moves |
| NO first-order condition anywhere | PASS |
| anti-narrowing / pre-empt anchors | all present |
| project + `CFMM.Eta` identifiers exist in landed modules | PASS, guarded against a vacuous pass |
| Mathlib citations | 30/30 real and line-exact (reviewer-confirmed) |
| reviewer gate | 2 BLOCKER, 1 MAJOR, 11 MINOR, 0 unresolved |
| queue at submit | 20/20 IDLE, 0 eta-curvature projects |
| tasks in flight for this project | exactly 1 |
| API key leaked | NO |
| `lean/` | porcelain empty across every commit |
| `model/exp/` | byte-identical to the 12-01 baseline |
| `../plank/` | nothing committed |

## Self-Check: PASSED

- `.planning/phases/12-eta-tradeoff-optimum/12-02-MODULE-MAP.txt` — FOUND
- `.planning/phases/12-eta-tradeoff-optimum/12-02-PROMPT-REVIEW.md` — FOUND
- `.planning/phases/12-eta-tradeoff-optimum/12-02-RUN-RECORD.md` — FOUND
- `scratch/aristotle-eta-curvature-PROMPT.txt` — FOUND (1232 lines, sha `6f28c64f…`)
- `scratch/aristotle-eta-curvature/RequestProject/` — FOUND (18 modules + doc)
- commit `9dbc53d` — FOUND
- commit `0e10fe7` — FOUND
- commit `a69a978` — FOUND
