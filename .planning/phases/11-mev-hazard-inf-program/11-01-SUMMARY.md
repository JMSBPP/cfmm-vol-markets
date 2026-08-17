---
phase: 11-mev-hazard-inf-program
plan: 01
subsystem: vol-markets-math-spec
tags: [mev, lambda-mev, hazard-rate, mmr, arbitrage, lvr, doc-spec, notation-gate, two-reviewer-gate, user-approved]
requires:
  - "11-RESEARCH.md F1–F8 (the MMR closed forms, the three notation collisions, the degeneracy, the Jensen result)"
  - "lean/vol_markets/FlairOptimization.lean (the mirror template, PROVEN)"
  - "lean/vol_markets/VolInstrument.lean (multiFee, probOr*)"
  - "../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf (arXiv:2305.14604v2)"
provides:
  - "model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md — the authoritative λ_MEV spec (blocks M0–M8), APPROVED & APPLIED"
  - "../plank/notes/VOLATILITY_INSTRUMENTS.md ### MEV — the Aristotle input document, bytes pinned by APPROVED-DOC-SHA256"
  - ".planning/phases/11-mev-hazard-inf-program/mev-notation-gate.sh — the executable PIT-1/2/3 gate"
  - ".planning/phases/11-mev-hazard-inf-program/11-01-REVIEW.md — both verdicts, resolutions, the verbatim approval, the two sha pins"
affects:
  - "11-02 and 11-04 (they grep APPROVED-DOC-SHA256 before building the Aristotle bundle)"
  - "11-03, 11-05, 11-06 (every downstream plan consumes the M-block statements)"
tech-stack:
  added: []
  patterns:
    - "mechanical notation gate with a bounded, marker-whitelisted escape hatch (rule 7 catches the marker being used to weaken the gate)"
    - "two reviewers run as parallel headless read-only processes; neither holds a write tool"
    - "approved bytes pinned by sha256 so a live, uncommitted, foreign-owned file can be proved faithful downstream"
key-files:
  created:
    - "model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md"
    - ".planning/phases/11-mev-hazard-inf-program/mev-notation-gate.sh"
    - ".planning/phases/11-mev-hazard-inf-program/11-01-REVIEW.md"
  modified:
    - "../plank/notes/VOLATILITY_INSTRUMENTS.md (written, NOT committed — owner ul2inqpl)"
    - "../plank/todo.md (written, NOT committed — owner ul2inqpl)"
    - ".planning/phases/11-mev-hazard-inf-program/11-CONTEXT.md (newly tracked)"
decisions:
  - "The fee is \\phi, never \\varphi — the parent doc already binds \\varphi to the quote function; a reviewer caught this and it would have shipped a wrong Lean module"
  - "λ_ARB and λ_MEV are distinct symbols; the aggregate is defined exactly once, in M7; λ_ARB absorbs the parent index set's 'arb toxicity' entry"
  - "M6b is stated over arbitrary fee PATHS, not over Θ_φ schedules — the schedule-level claim is vacuous at constant σ and is labelled OPEN"
  - "a_t carries an explicit Δt: MMR's LVR is a rate, and the per-block summand must scale Δt^{3/2}"
  - "The Angstrom rebate is an LP-INCIDENCE object; τ redistributes value and does not reduce extraction intensity"
  - "The notation gate against the plank doc was run on an extracted ### MEV section, because the whole doc legitimately contains the pricing-kernel η"
metrics:
  duration: "~2h (across one session interruption)"
  tasks: 3
  files: 6
  completed: 2026-07-30
---

# Phase 11 Plan 01: The λ_MEV Doc Specification Summary

**The λ_MEV mathematical specification exists as ten insert-ready LaTeX blocks anchored to MMR arXiv:2305.14604v2, survived a two-reviewer gate that found and fixed 4 BLOCKERs and 12 MAJORs, was explicitly approved by the user, and is now landed in the plank-owned Aristotle input document with its exact approved bytes pinned by sha256.**

## What was built

`VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` (192 lines, blocks M0–M8) transcribes — never re-derives — the anchor paper's closed forms under three mechanically-enforced notation substitutions, and states the phase's two substantive results as deliberately separate claims:

- **M6a, the DEGENERACY.** Unconstrained over `Θ_φ`, the same corner point and the same saturating direction `β → −∞` simultaneously maximize `λ_FLAIR` and minimize `λ_ARB`, robustly to any linear scalarization. This **REFUTES** the phase brief's expectation that the shape block `(β, γ_j)` becomes essential, and says so in those words rather than quietly dropping it.
- **M6b, the CONSTRAINED result.** Over arbitrary fee *paths* at a fixed FLAIR income, the flat path minimizes `λ_ARB` and any path non-constant on the positive-weight steps is strictly worse. The σ-varying *schedule* comparison is labelled **OPEN**.

The gate script `mev-notation-gate.sh` enforces PIT-1/2/3 mechanically. Its only escape hatch is the `<!-- notation-map -->` marker, and rule 7 bounds that marker to the header and M0 — so the specific weakening of "just mark the offending line" is itself caught.

## Task-by-task

| Task | Commit | Result |
| --- | --- | --- |
| 1. Author the addendum + notation gate | `265b937` | Ten blocks; gate PASS after it caught a real bare-λ violation in M0 |
| 2. Two-reviewer gate, resolve BLOCKER/MAJOR | `f6e89bc` | 4 BLOCKERs + 12 MAJORs + 10 MINORs, all resolved; addendum substantially rewritten |
| 3. User approval, insertion, handoff | `4d66f1f` | Approved; 181 lines landed in plank's doc; bytes pinned; plank HEAD unchanged |

## The reviewer gate did real work

Both reviewers ran **in parallel** as independent read-only processes (`claude -p`, no write tools). Reviewer 1 was the mandatory Reality Checker; Reviewer 2 was the **Model QA Specialist**, picked as the closest catalog specialist to quantitative finance / market microstructure (no dedicated quant agent exists) — the pick and its reason are recorded in the review file.

Both returned **NEEDS WORK**. The four BLOCKERs were not cosmetic:

1. **The fee glyph collided with the parent document.** The draft used `\varphi` for the fee, but the plank doc binds `\varphi` to the quote function at line 305 and uses `\phi` for the fee. Inserted verbatim this would have bound one glyph to two objects, and Aristotle treats them as distinct identifiers. This is a *same-concept/different-glyph* clash — a fourth collision class the notation gate structurally could not see, because no forbidden glyph was involved.
2. **`argsup = arginf` was ill-posed.** Both arg-sets are empty over the unbounded shape block, by the project's own proven `flairMulti_strict_below_saturation`. Restated as three well-posed claims.
3. **M6b's headline was vacuous.** Because `multiFee` depends on σ alone, at constant σ *every* admissible schedule already yields a flat fee path — so "every volatility-responsive schedule is strictly worse" had no instance. The document was claiming in bold the conclusion of its own OPEN problem.
4. **`a_t` was dimensionally wrong.** MMR's `LVR = (σ²/8)V` is a *rate per unit time*; the per-block weight needs `·Δt`. Without it the sum mixed rates with amounts, the advertised commensurability with `λ_FLAIR` was false, and the Δt cadence lever — the phase's second non-degenerate lever — was understated by a full factor of Δt.

I did not take these on trust. Five source-dependent findings were re-verified directly against `/tmp/mmr.txt` and the parent document before acting; all five confirmed (LVR-as-rate at :882–884; per-block `Δt^{3/2}` at :1344–1346; eq. (27)'s dropped "delta-hedged" at :1482; the `\varphi` binding at parent :305; Assumption 2 at :548–556).

**Source conflict:** BLOCKER 3 contradicts `11-RESEARCH.md` F6, which asserted the schedule-level claim outright. The reviewer's reading won; the paper is silent (the point concerns the project's own functional, not MMR's). The disposition records which source won.

## Deviations from plan

**1. [Rule 3 — Blocking] No subagent tool; reviewers run as parallel headless processes.**
- **Found during:** Task 2. The plan directs "one message, two agent calls", but this executor has no `Task` tool.
- **Fix:** launched both reviewers as backgrounded `claude -p` processes from a single shell invocation with `--allowedTools Read Grep Glob` (no write tools), then `wait`ed on both. This satisfies the binding requirements more strictly than a subagent call would: genuine parallelism, genuine independence, and *tool-level* inability to edit the artifact.
- **Commit:** `f6e89bc`

**2. [Rule 3 — Blocking] `claude-peers send_message` not exposed to this executor.**
- **Found during:** Task 3 step 5. The MCP server instructions were injected mid-run but the tool is not in this agent's toolset.
- **Fix:** the durable handoff — full block summary, the binding `\phi`-not-`\varphi` correction, the pinned sha and its re-approval condition — is written into `../plank/todo.md` under `## LEAN4 - MATH`, which is the established precedent (commit 489bb43). **Coordinator relay to `ul2inqpl` is requested and is the one open thread from this plan.**
- **Commit:** `4d66f1f`

**3. [Rule 1 — Bug] Gate whitelist regex left as planned despite the glyph change.**
- The plan's rule-3 whitelist matches `Theta_\{?\\?varphi`. After the `\varphi → \phi` fix that alternative is dead, but no line needs it (the only bare-`\gamma` line is whitelisted by `multiFee`), so the gate was left byte-unchanged rather than edited. Verified by re-running all rules by hand.

**No ESCALATE rows.** Every finding had a determinate fix against the paper, the parent document, or the project's own Lean layer; none required user adjudication.

## Verification

- `mev-notation-gate.sh` on the addendum: **PASS**. It caught **three real violations** during authoring and resolution; the addendum was fixed each time and **the gate was never weakened** — still 6 markers, all before the `**M1.` header.
- Gate against the plank doc: the whole-file run **FAILS rule 1** on the doc's own legitimate pricing-kernel `η` (lines 262/263/294/295/388) — exactly the case the plan anticipated. Re-run on an extracted `### MEV` section: **PASS**. Both runs recorded; the failing one is not suppressed.
- Insertion: 464 → 646 lines, **0 deletions** (verified by `diff` against a pre-insertion copy). Both pre-existing bullets survive verbatim.
- `git status --porcelain lean/` **empty across all three commits** — no Lean file touched, no Aristotle task run.
- Plank worktree HEAD `8f43641…` identical before and after; no commit made there by this session.
- Recorded hashes verified to equal the live files at commit time.

## Honest limitations

- **The plank doc is live, uncommitted, and owned by another agent.** The sha pin is the mitigation, not a guarantee: if `ul2inqpl` edits the `### MEV` section before committing, `APPROVED-DOC-SHA256` goes stale and 11-02/11-04 will hard-fail rather than silently drift. That is the intended failure mode.
- **Plank HEAD moved during a session interruption** (`d34846c…` → `8f43641…`) for reasons outside this plan. What is established is only that HEAD is unchanged *across this session's insertion*.
- **Nothing here is proven.** These are doc-level claims awaiting Aristotle. M6a and M6b in particular are the statements most likely to acquire extra hypotheses when formalized.
- **The σ-varying Jensen generalization is OPEN** and is labelled as such, not papered over.

## Context for the next phase

At the approval checkpoint the user designated the post-Phase-11 continuation: **interior η (Capponi–Jia curvature, refs now in `../plank/refs/mev/`) is the degeneracy-breaker**, to be formalized as the next phase. This follows directly from M6a — over `Θ_φ` alone there is no trade-off to control, so the lever must come from outside the fee parameter set. It also answers the standing `\eta` question already sitting in plank's `todo.md`. Recorded at summary level only; it changed nothing in this plan's scope.

## Self-Check: PASSED

Every file claimed created/modified exists; all three commits (`265b937`, `f6e89bc`, `4d66f1f`) resolve. Numeric claims re-derived from disk rather than restated: addendum 192 lines ✓, plank doc 646 lines ✓, 6 notation-map markers ✓, 4 BLOCKER / 12 MAJOR / 10 MINOR resolution rows ✓, `git status --porcelain lean/` count 0 ✓, plank HEAD `8f43641` ✓. Both recorded sha256 pins verified equal to the live files.
