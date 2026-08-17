---
phase: 11-mev-hazard-inf-program
plan: 02
subsystem: vol-markets-lean-formalization
tags: [aristotle, mev, lambda-arb, ptrade, infimum-program, prompt-gate, two-reviewer-gate, serial-queue, doc-fidelity, in-flight]
requires:
  - "11-01 APPROVED-DOC-SHA256 (the pinned bytes the bundle must prove it carries)"
  - "model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md blocks M0–M5 (the statements the prompt specifies)"
  - "lean/vol_markets/FlairOptimization.lean (the PROVEN mirror template, 15 theorems)"
  - "lean/vol_markets/VolInstrument.lean, FeeSchedule.lean (multiFee / logistic — reuse, never redefine)"
  - "scratch/aristotle-flair/ + aristotle-flair-PROMPT.txt (the working bundle layout and prompt skeleton)"
provides:
  - "scratch/aristotle-mev/ — bundle A: 10 rewritten modules + the approved doc, both fidelity gates PASS"
  - "scratch/aristotle-mev-PROMPT.txt — the T1–T19 numbered specification, sha256 c7ed66e9…"
  - ".planning/phases/11-mev-hazard-inf-program/11-02-PROMPT-REVIEW.md — both verdicts, 2 BLOCKER / 3 MAJOR / 6 MINOR, all blocking rows resolved"
  - ".planning/phases/11-mev-hazard-inf-program/11-02-RUN-RECORD.md — project/task ids, hashes, queue evidence, the T1–T19 fidelity checklist"
  - "memory aristotle-mev-bundle-a-inflight — the in-flight task + landing checklist"
affects:
  - "11-03 (integration: diffs the returned module against this plan's T1–T19 checklist)"
  - "11-04 (bundle B — BLOCKED until this task reaches a terminal state; the queue is serial)"
tech-stack:
  added: []
  patterns:
    - "doc fidelity proved TWICE and independently — sha256 against the approval pin AND a byte diff of the extracted M-blocks — before a one-shot submission is spent"
    - "the two-reviewer gate run on the PROMPT (the artifact the prover consumes), not on the plan"
    - "reviewers as parallel headless read-only processes: genuine independence plus tool-level inability to edit the artifact"
    - "Mathlib hint names verified by grep against the pinned checkout before being offered to the prover"
    - "untracked (gitignored) submission bundles pinned by sha256 in a committed run record"
key-files:
  created:
    - "scratch/aristotle-mev/ (10 .lean + the approved doc; gitignored, pinned by hash)"
    - "scratch/aristotle-mev-PROMPT.txt (275 lines; gitignored, pinned by hash)"
    - ".planning/phases/11-mev-hazard-inf-program/11-02-PROMPT-REVIEW.md"
    - ".planning/phases/11-mev-hazard-inf-program/11-02-RUN-RECORD.md"
    - "memory/aristotle-mev-bundle-a-inflight.md"
  modified:
    - "memory/MEMORY.md (index entry for the in-flight task)"
decisions:
  - "The approved DOC, not the plan's task text, is the specification — the plan's T8 draft had dropped the doc's ·Δt factor and was corrected against the doc"
  - "T17 was rewritten with an admissibility constraint: it is FALSE for arbitrary compact Θ because ptrade has a pole at negative fees; a bare ContinuousOn hypothesis is explicitly forbidden as a repair"
  - "Three Mathlib hints supplied by the plan do not exist at v4.28.0 (strictConvexOn_inv, StrictConvexOn.comp_affineMap, StrictConvexOn.smul); replaced with verified routes and the non-existences stated so the prover does not hunt for them"
  - "mevHazard/mevMulti identifiers KEPT despite naming the aggregate for a λ_ARB object — renaming would break the plan's acceptance criteria and 11-03's integration keys; a mandatory docstring caveat carries the summand relation instead"
  - "Submission bundles are not committed (scratch/ is gitignored, and no prior Aristotle bundle was tracked); the run record's sha256 pins are their identity"
metrics:
  duration: "~45 min to submit (task still in flight)"
  tasks: 3
  files: 5
  completed: 2026-07-30
---

# Phase 11 Plan 02: Aristotle Bundle A — ptrade, λ_ARB, and the Infimum Program Summary

**A reviewer-gated T1–T19 specification over a structurally complete 10-module bundle — carrying a document copy proved byte-identical to the user-approved text by both an sha256 pin and an independent M-block diff — was submitted as the single in-flight Aristotle task (project `cb371ee5`, task `d1c57297`), with the gate catching two blockers that would each have burned the one-shot submission.**

## What was built

`scratch/aristotle-mev/` reproduces the working FLAIR bundle layout with **10** modules rather than that run's 9 (`FlairOptimization.lean` is added as the mirror template the new module must reverse, not modify), plus `lakefile.toml` / `lean-toolchain` / `lake-manifest.json` all pinned to `v4.28.0`. Imports were rewritten `vol_markets.` → `RequestProject.`; zero occurrences remain; zero `sorry`/`admit` in any dependency.

`scratch/aristotle-mev-PROMPT.txt` (275 lines) is a numbered specification whose statements can be diffed one-for-one against whatever returns — which is precisely what makes a silent narrowing detectable at integration rather than invisible.

## The doc fidelity gate did the job it was designed for

The bundled document is a copy of a **live, uncommitted, plank-owned** file. The only proof it carries what the user approved is 11-01's pin, and it was checked twice over — by hash and, independently of the hash, by diffing the extracted M-blocks:

```
APPROVED-DOC-SHA256 : 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
LIVE plank doc      : 671000a5…fba58     BUNDLED copy : 671000a5…fba58
M-block diff        : empty (181 lines each)
```

Re-run again immediately before submitting, because the plank file could have moved while the reviewers ran. All three agreed at submit time. **`BUNDLED-DOC-SHA256 == APPROVED-DOC-SHA256`: the document the prover received is byte-identical to the text the user approved.**

## The reviewer gate caught two blockers, and both were real

Both reviewers ran **in parallel** from a single shell invocation as independent headless processes with read-only tools — no write tool, so neither *could* edit the artifact. Both returned **NEEDS WORK**: **2 BLOCKER, 3 MAJOR, 6 MINOR**.

1. **T8 had dropped the `·Δt` factor** from the approved doc's M3(i) weight — silently re-introducing the rate-vs-amount defect that 11-01's doc gate had already caught and fixed as *its* BLOCKER 4. The prompt contradicted its own section-(A) docstring instruction. The Δt-less form traces to the pre-gate research file and to the plan's own task text; the approved document says `a_t = (σ_t²/8)·V_t·Δt`. Without it the summand scales as `√Δt` instead of the anchor's `Δt^{3/2}`, misstating the batch-cadence lever — the phase's second non-degenerate lever — by a full factor of `Δt`. **The doc-over-plan rule is what decided this.**

2. **T17 was provably false as written.** Both reviewers independently constructed the same counterexample: `ptrade` has a pole at negative fees, so on an arbitrary compact `Θ` the objective is discontinuous and unbounded below and no minimizer exists (`T=1, σ=1, Δt=2, Θ=[−2,0]×{0}³` gives `1/(1+φ̄) → −∞`). FLAIR needed no such constraint only because `flairMulti` is affine, hence continuous on all of `ℝ⁴` — **a second place the mirror breaks, beyond the one RESEARCH F4 tabulates.** T17 now carries the admissibility constraint, records the counterexample, and explicitly forbids the degenerate "just add `ContinuousOn`" repair, which would be technically true while gutting the theorem.

The three MAJORs: M5(iii)'s "strictly exceeds the displayed bound" half had no carrier (a clause 11-01's reviewer specifically fought for) — now a named corollary `mevMulti_min_gt_corner`; M1's "increasing in σ" was the one of seven documented `P_trade` properties left uncarried — now `ptrade_monotoneOn_sigma`; and the `λ_ARB` object carried the aggregate's name, risking a later `mevHazard + sandwich` double-count that M0 forbids — resolved by a mandatory docstring caveat rather than a rename, since renaming would break the plan's own acceptance criteria and 11-03's integration keys.

Notably, the Reality Checker verified **every** Mathlib citation in the prompt, including its three *non*-existence claims, against the pinned checkout — all confirmed.

## Deviations from plan

**1. [Rule 1 — Bug] Three Mathlib hints in the plan do not exist at the pinned v4.28.0.**
- **Found during:** Task 1, verifying the plan's T6 hint list before writing it into the prompt.
- **Issue:** `strictConvexOn_inv`, `StrictConvexOn.comp_affineMap` and `StrictConvexOn.smul` all grep to zero hits in `lean/.lake/packages/mathlib`. Only the non-strict `ConvexOn.comp_affineMap` exists (Function.lean:937); there is no strict affine-precomposition lemma in Mathlib at all.
- **Why it mattered:** T6 is the one theorem the plan flags as load-bearing, where returning `ConvexOn` instead of `StrictConvexOn` is called out as a silent narrowing. Hints naming nonexistent lemmas are exactly what pushes a prover to give up on strictness and return the weak form.
- **Fix:** replaced with verified routes — `strictConvexOn_of_deriv2_pos'` (Deriv.lean:308, signature quoted), `strictConvexOn_zpow` (SpecificFunctions/Deriv.lean:99), `StrictConvexOn.convexOn` (Function.lean:360) — and stated the three non-existences explicitly so the prover does not hunt for them.
- **Commit:** `b8b29be`

**2. [Rule 1 — Bug] The plan's Task-1 action text contradicts its own acceptance criterion.**
- **Found during:** Task 1 acceptance run. The action instructs writing "Do NOT name it `ptradeCPMM`…" into the prompt, while the acceptance criterion is `! grep -q 'ptradeCPMM' <prompt>`. Satisfying either violated the other.
- **Fix:** the prohibition was rephrased to forbid the *class* of name ("no CPMM-suffixed variant of `ptrade`, and nothing else `ptrade`-flavoured") without using the literal string, preserving the semantic intent and passing the mechanical gate.
- **Commit:** `b8b29be`

**3. [Rule 3 — Blocking] No subagent tool; reviewers run as parallel headless processes.**
- **Found during:** Task 2. The plan directs "one message, two agent calls" but this executor has no `Task` tool — the same constraint 11-01 hit.
- **Fix:** both reviewers launched as backgrounded `claude -p` processes from a single shell invocation with read-only tools, then joined. This satisfies the binding requirement more strictly than a subagent call: genuine parallelism, genuine independence, and *tool-level* inability to edit the artifact. Precedent: commit `f6e89bc`.
- **Commit:** `b8b29be`

**4. [Rule 3 — Blocking] The plan's Task-3 commit command would have failed; bundles are not committable.**
- **Found during:** Task 1 commit step. `scratch/` is gitignored (`.gitignore:57`) and **no prior Aristotle bundle was ever tracked** — `git ls-files scratch/` is empty, including for the FLAIR run.
- **Fix:** committed only the `.planning/` artifacts. This is not a workaround but the established mechanism: the plan already requires `BUNDLED-DOC-SHA256` and the prompt sha256 in the run record precisely so untracked bytes have a committed identity. Force-adding would also have committed a copy of a document owned by another agent.
- **Commit:** `e5cb8dd`

**5. [Rule 1 — Bug] `aristotle show` blocks; polling must use `aristotle tasks`.**
- **Found during:** Task 3. The plan's step 6 directs polling with `aristotle show`, which streams events and hung a 2-minute call.
- **Fix:** polled with `aristotle tasks <project_id>`, which returns immediately. Recorded in the run record and in memory as a reusable operational fact.
- **Commit:** `e5cb8dd`

**No `DEFER-TO-DOC` rows and no ESCALATE rows.** Both BLOCKERs were *fidelity* failures — the prompt had drifted from the approved document and from what is mathematically true — so resolving them moved the prompt toward the doc. The approved bytes were never touched.

## Verification

- Both fidelity gates PASS at bundle build, after every prompt edit, and again immediately before submit.
- Every Task-1 and Task-2 acceptance grep passes (re-run after the reviewer edits): T1–T19 tags, all target identifiers, `StrictConvexOn`, `mevMulti_nonneg`, `not affine`, the guard literal scoped to T19, the refuted name absent, 275 lines.
- **Queue proven EMPTY before submit** — `aristotle list --status RUNNING` → "No projects found"; all five most recent projects `IDLE`; newest (`78bac8dd`, FLAIR) `COMPLETE`. Exactly one task is in flight.
- `git status --porcelain lean/` **empty across every commit of this plan.** No Lean file touched.
- `git grep 'ARISTOTLE_API_KEY=…'` over tracked files: no match. `.env` is gitignored and the key was never printed.

## Status: the task is STILL IN FLIGHT

| Field | Value |
| --- | --- |
| project id | `cb371ee5-f27c-48d2-a396-725751fd7c36` |
| task id | `d1c57297-39b2-47ad-8048-492a407c6498` |
| status at close | **`IN_PROGRESS`** (~22 min elapsed, 18 polls) |

This is expected, not anomalous: the comparable FLAIR run returned a 439-line, 15-theorem module, and this bundle asks for more. The task is recorded in memory `aristotle-mev-bundle-a-inflight` with its landing checklist so a session restart cannot lose it.

**The plan's stated `<done>` condition is therefore only partly met** — everything through "submitted as the single in-flight task with full provenance recorded and committed" holds; "the run reported COMPLETE with the user cleared to integrate" does not yet. Reporting that plainly rather than declaring the plan finished.

## Honest limitations

- **Nothing is proven yet.** T1–T19 are a specification, not a result. The statements most likely to come back with added hypotheses are T6 (strict convexity), T16 and T17 — and the checklist exists so that is *detected* rather than absorbed.
- **A submit-time warning was accepted, not eliminated:** the CLI flagged the bundle's missing `.lake` folder. Judged benign because the FLAIR bundle also had none and returned 15 axiom-clean theorems; the environment is pinned by toolchain + manifest instead. If this run fails to build server-side, that warning is the first suspect.
- **The plank document remains live and foreign-owned.** The pins hold as of submit time; they say nothing about the future. Any later edit to the `### MEV` section invalidates `APPROVED-DOC-SHA256` and will hard-fail 11-04 rather than drift silently — the intended failure mode.
- **The reviewers are LLM processes, not proof checkers.** They caught two real defects here, one of which I had introduced by following the plan's own text; they are not a guarantee of correctness of the remaining seventeen statements.
- **11-04 is blocked** until this reaches a terminal state. The queue is strictly serial.

## Self-Check: PASSED

All claimed files exist on disk (`scratch/aristotle-mev/` with 10 `.lean` + 1 `.md`, the prompt, both `.planning/` records, both memory files). Both commits resolve: `b8b29be`, `e5cb8dd`. Hashes re-verified from disk rather than restated: prompt `c7ed66e9…5d54`, bundled doc `671000a5…fba58` equal to `APPROVED-DOC-SHA256` ✓. Project and task ids re-read live from `aristotle tasks` ✓. `git status --porcelain lean/` count 0 ✓. Prompt line count 275 ✓. Finding counts (2 BLOCKER / 3 MAJOR / 6 MINOR) match the resolution table's rows ✓.
