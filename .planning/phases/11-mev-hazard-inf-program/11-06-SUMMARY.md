---
phase: 11-mev-hazard-inf-program
plan: 06
subsystem: docs
tags: [traceability, lean4, mev, milionis-moallemi-roughgarden, angstrom, close-out]

# Dependency graph
requires:
  - phase: 11-mev-hazard-inf-program (11-01)
    provides: the approved M0–M8 λ_MEV doc blocks and their sha pins
  - phase: 11-mev-hazard-inf-program (11-03)
    provides: MevOptimization.lean + the T1–T19 fidelity record (T15 corrected, T19 omitted)
  - phase: 11-mev-hazard-inf-program (11-05)
    provides: MevJointProgram.lean + the T20–T30 fidelity record and the T24 = REFUTED verdict
provides:
  - "LEAN_TRACEABILITY §0 MEV notation rows: the three resolved MMR collisions and the binding λ_ARB ≠ λ_MEV distinction"
  - "LEAN_TRACEABILITY §7.1: 14 claim rows binding every proved MEV claim to a grep-verified Lean identifier with a sanctioned status word"
  - "The arb_add_fee_eq_lvr row labelled a bridge identity / ring tautology, explicitly NOT a formalization of MMR Theorem 3/4"
  - "M6a degeneracy recorded as PROVEN-as-the-result; M6b general σ-varying claim recorded REFUTED with the recomputed witness; the Θ_φ-restricted case a separate OPEN row"
  - "LEAN_TRACEABILITY §6 rewritten: the stale 'MEV section (empty in the doc)' clause replaced by five precisely named remaining gaps"
  - "MEV addendum back-annotated M1–M7; block M6b amended OPEN → REFUTED; APPROVED-ADDENDUM-SHA256 staleness recorded"
  - "ROADMAP Phase 11 goal correction propagated and the six-plan list closed with per-plan outcomes"
  - "STATE terminal close-out with the load-bearing decisions, incl. the T24 verdict and the bridge-identity caveat"
  - "11-VALIDATION.md filled from the executed plans, nyquist_compliant: true"
affects: [interior-eta-curvature, FeeSchedule-equilibrium-layer, any-future-consumer-of-lambda_MEV]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Traceability rows carry a sanctioned status word taken from the FIDELITY record, never from the plan's expectation"
    - "Every backticked Lean identifier in a traceability row is verified against a declaration line (^theorem / ^noncomputable def), not a substring"
    - "A refutation is recorded as a REFUTED row with its witness and an independent recomputation, and its scope bounded by a SEPARATE OPEN row"
    - "Tautology-grade bridge identities are labelled on the same line as the identifier they name, so no downstream consumer can inflate them"

key-files:
  created:
    - .planning/phases/11-mev-hazard-inf-program/11-06-SUMMARY.md
  modified:
    - model/vol_markets/LEAN_TRACEABILITY.md
    - model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/phases/11-mev-hazard-inf-program/11-VALIDATION.md

key-decisions:
  - "Status words in §7.1 are taken verbatim from the fidelity records: M6a PROVEN-as-degeneracy, M6b general claim REFUTED, Θ_φ-restricted case a separate OPEN row, M5 CORRECTED → PROVEN, M3(ii) OPEN"
  - "arb_add_fee_eq_lvr is labelled a bridge identity and a ring tautology on its own row line, with an explicit denial that it formalizes MMR Theorem 3/4"
  - "§6's stale MEV clause was REPLACED by five precisely named gaps rather than deleted, so the record still says what is missing"
  - "The plank-owned VOLATILITY_INSTRUMENTS.md was amended in place but NOT committed; plank HEAD df7088f unchanged, handed to ul2inqpl"
  - "The back-annotation intentionally invalidates 11-01-REVIEW.md's APPROVED-ADDENDUM-SHA256; both doc-fidelity gates were already consumed, and the staleness is recorded in the addendum header rather than hidden"
  - "Where the plan's mechanical criteria contradicted the artifacts, the criteria were recorded as defective and the semantic requirement verified properly — the artifacts were not edited to satisfy a regex"

patterns-established:
  - "Close-out plans move the RECORD, not the mathematics: this plan proved nothing new and says so"
  - "Requirement close-out is checked BOTH ways — every ROADMAP CTX id appears in some plan's frontmatter, and no plan carries an id absent from the ROADMAP line"

requirements-completed: [CTX-TRACE]

# Metrics
duration: 34 min
completed: 2026-07-31
---

# Phase 11 Plan 06: λ_MEV traceability and phase close-out Summary

**LEAN_TRACEABILITY §0/§6/§7.1 now bind all 14 proved MEV claims to grep-verified Lean identifiers with fidelity-record status words — the degeneracy recorded as the result, T24 recorded REFUTED with its recomputed witness, the Θ_φ-restricted case kept OPEN, and `arb_add_fee_eq_lvr` labelled a tautology-grade bridge identity rather than a formalization of MMR Theorem 3/4.**

## Performance

- **Duration:** 34 min
- **Started:** 2026-07-31T12:20:00Z
- **Completed:** 2026-07-31T12:54:00Z
- **Tasks:** 2
- **Files modified:** 5 tracked (+1 untracked-by-design in the plank worktree, never committed)

## Accomplishments

- **§7.1 is the deliverable, and it is honest.** Fourteen claim rows, one per proved MEV claim, each
  naming real identifiers. **Every backticked Lean name was verified against a declaration line**
  (`^theorem` / `^noncomputable def`) in `MevOptimization.lean` or `MevJointProgram.lean` — 25 + 27
  names, all resolving. A substring match would have let a row name a lemma that does not exist under
  that name; a declaration-line match will not.
- **The two negative results survived into the record as results.** `M6a → PROVEN`, with the row text
  stating that the program is degenerate and the shape block `(β, γ)` is NOT essential — the phase
  brief's expectation refuted, machine-checked. `M6b general σ-varying schedule claim → REFUTED`,
  carrying `mev_ge_flat_under_flair_budget_false`, the witness, and the independent exact-rational
  recomputation (flat `31/22 ≈ 1.4091` vs tilted `4/3 ≈ 1.3333`). Neither was softened.
- **The refutation's scope is bounded by a separate row, not by a hedge inside it.** The
  `Θ_φ`-restricted isotone case is its own `OPEN` row, with the reason stated (the witness schedule
  decreases in σ; every `Θ_φ`-reachable schedule is isotone, `VolInstrument.multiFee_monotone`) and
  the supporting executor float numerics explicitly labelled NOT machine-checked and merged into no
  claim.
- **The row most at risk of being oversold is the most tightly bounded.** `arb_add_fee_eq_lvr` carries
  the words **bridge identity** and **tautology** on its own line, writes the ring identity
  `x·p + x·(1−p) = x` out, and states that it is NOT a formalization of MMR Theorem 3/4 — those
  asymptotics are quoted in block M2 and formalized nowhere.
- **What is missing is named, not blanketed.** §6's stale `"MEV section (empty in the doc)"` clause was
  replaced by five precise gaps: the continuum path-integral form of `λ_ARB`; the demand-elasticity /
  optimal-fee equilibrium layer (`FeeSchedule`, anchor §7.3 eq. (27)); the Theorem 3/4 asymptotics;
  the exact Corollary-2 CPMM kernel (T19 omitted — the `σ²Δt < 8` guard has no carrier anywhere); and
  the `Θ_φ`-restricted σ-varying comparison. `𝓖_φ` keeps its own OPEN line.
- **Notation is pinned in §0**: rows for `φ`/`φ̄`, `Δt`, `P_trade`, `a_t`, `λ_ARB`, `λ_MEV`, `τ`, plus
  the three resolved MMR collisions (fee `γ` → `φ`; block rate `λ` → `Δt ≜ λ⁻¹`; composite `η`
  deliberately never named) and the binding rule that **`λ_ARB` is a SUMMAND of `λ_MEV`** and the two
  are never interchangeable. The pre-existing `η` reservation sentence is intact.
- **The addendum is back-annotated and self-consistent.** Per-block `> LEAN` lines on M1–M7 following
  the `VOLATILITY_INSTRUMENTS_LEAN_ADDENDUM.md` precedent; **block M6b amended `OPEN` → `REFUTED`**
  with the `Θ_φ`-restricted remainder kept OPEN in the same amendment; and M8's closing caveat updated
  to match, so the document does not contradict itself two pages apart.
- **The plank-owned document received the identical amendment and was NOT committed.** The
  `"bundle B in flight"` placeholder is replaced by the landed T20–T30 annotation. Plank HEAD
  `df7088f` before and after; only the pre-existing working-tree modification was touched. Owner
  `ul2inqpl`.
- **ROADMAP and STATE close out on what happened.** The Phase-11 goal clause is corrected in place
  without deleting the original intent; the planning-correction note is upgraded from "research
  shows" to machine-checked; the six-plan list carries per-plan outcomes including 11-04's and
  11-05's; and STATE records eight `[Phase 11]` decisions, the T24 verdict, and the bridge-identity
  caveat.

## Task Commits

1. **Task 1: LEAN_TRACEABILITY §0/§6/§7.1 + addendum back-annotation** — `1d28314` (docs)
2. **Task 2: ROADMAP + STATE close-out, VALIDATION, memory, push** — see plan metadata commit below

**Plan metadata:** recorded in the Task 2 close-out commit (docs: complete plan)

## Files Created/Modified

- `model/vol_markets/LEAN_TRACEABILITY.md` — §0 MEV notation rows + collision resolutions; §6 rewritten
  with five named gaps; new §7.1 with 14 claim rows
- `model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` — `> LEAN` back-annotations on M1–M7,
  M6b amended `OPEN` → `REFUTED`, M8 caveat synced, LEAN-BACKED status header with the
  `APPROVED-ADDENDUM-SHA256` staleness note and the plank handoff
- `.planning/ROADMAP.md` — Phase 11 goal correction, phase outcome paragraph, six-plan list closed
- `.planning/STATE.md` — terminal status/position, `Plan (11-06)` paragraph, eight `[Phase 11]`
  decisions, session continuity pointing at the interior-`η` successor thread
- `.planning/phases/11-mev-hazard-inf-program/11-VALIDATION.md` — per-task verification map for all
  15 tasks across the six plans, `nyquist_compliant: true`
- `../plank/notes/VOLATILITY_INSTRUMENTS.md` — **edited, NOT committed** (plank-owned)
- memory: `phase-11-mev-closed.md` + `MEMORY.md` index row

## Decisions Made

See `key-decisions` in the frontmatter. The load-bearing one: **status words came from the fidelity
records, not from the plan's suggested rows.** The plan offered `PROVEN` phrasing for the constrained
program with `REFUTED` as one branch; `11-05-FIDELITY.md`'s `## T24 verdict` says REFUTED, so the row
says REFUTED, and the surviving constant-σ result got its own row on its own strictly smaller domain
rather than being allowed to stand in for the general case.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's identifier-existence loop reaches into §8, which it was told to leave alone**

- **Found during:** Task 1 (cross-check step)
- **Issue:** The acceptance criterion loops over every backticked identifier in the WHOLE file matching
  `^(ptrade|mev|joint|taxFraction|Theta_lambdaMEV|arb_add|ARBoverV)` and requires each to exist in one
  of the two MEV modules. §8 (an independent run's rows, explicitly out of scope for this plan)
  contains `joint_candidates_disagree`, an `EndogenousMaturity.lean` identifier. The criterion exits 1
  on a row this plan must not touch.
- **Fix:** §8 left untouched, as instructed. `joint_candidates_disagree` verified present in
  `lean/vol_markets/EndogenousMaturity.lean` instead. The criterion's intent — "every Lean name in the
  NEW rows exists" — was verified properly and exhaustively: 25 names checked against declaration
  lines in `MevOptimization.lean` and 27 against `MevJointProgram.lean`, all resolving. Note this is
  strictly STRONGER than the criterion, which only pattern-matches undotted backticked tokens and
  therefore silently skips every module-qualified name such as `MevJointProgram.mev_mono_dt`.
- **Files modified:** none (verification-only)
- **Verification:** the 52-name declaration-line sweep printed above; `joint_candidates_disagree`
  found in `EndogenousMaturity.lean`
- **Committed in:** `1d28314` (Task 1 commit)

**2. [Rule 3 - Blocking] `ARBoverV_exact` cannot be backticked, because it does not exist**

- **Found during:** Task 1
- **Issue:** The plan asks for an OPEN row for the omitted T19 kernel, but its own identifier-existence
  criterion greps for backticked `ARBoverV*` names and requires them to exist. Backticking the name of
  a lemma that was deliberately not delivered would fail the check and, worse, would read as if a
  carrier existed.
- **Fix:** the row names the object in plain prose ("the exact Corollary-2 CPMM kernel", "the optional
  T19 object") and marks it `OPEN — deliberately optional, non-blocking`; the identifier appears
  unbackticked in §6(d) only.
- **Files modified:** `model/vol_markets/LEAN_TRACEABILITY.md`
- **Verification:** identifier loop passes for every `ARBoverV`-prefixed token (there are none)
- **Committed in:** `1d28314`

**3. [Rule 3 - Blocking] The `! grep '/home/'` criterion false-fails on ROADMAP's own scrub-command rows**

- **Found during:** Task 2
- **Issue:** `! grep -rE '/home/|\$HOME' .planning/ROADMAP.md` exits nonzero because Phase 1's
  REPO-05 success criterion and concerns row **quote the scrub command itself**
  (`git grep -InE '/home/[a-z0-9_-]+/'`). Those rows are pre-existing, out of scope, and deleting them
  would destroy the requirement they document.
- **Fix:** pre-existing rows left alone. Verified instead that **this plan's own additions** to
  ROADMAP, STATE, LEAN_TRACEABILITY and the addendum contain no absolute or `$HOME` path — which is
  the criterion's actual intent.
- **Files modified:** none (verification-only)
- **Verification:** `grep -rE '/home/|\$HOME'` returns nothing on `LEAN_TRACEABILITY.md` and the
  addendum; on ROADMAP the only two hits are the pre-existing Phase-1 rows
- **Committed in:** the Task 2 close-out commit

**4. [Rule 1 - Bug] The plan's ROADMAP assumptions were stale: `Requirements: TBD` and `0 plans` were already filled**

- **Found during:** Task 2
- **Issue:** The plan specifies replacing a `**Requirements**: TBD` placeholder and a `- [ ] TBD` plan
  line. A prior pass had already minted the eight CTX ids into the ROADMAP block and written plan lines
  for 11-01…11-06. Blindly following the plan text would have duplicated the requirements line.
- **Fix:** the existing Requirements line was verified to carry all eight ids and left as-is; the work
  reduced to the goal-clause correction, the phase-outcome paragraph, the per-plan outcome text for
  11-04/11-05/11-06, and the progress line. Requirement coverage was still checked BOTH ways as the
  plan directs: every ROADMAP CTX id appears in at least one plan's `requirements:` frontmatter, and no
  plan carries an id absent from the ROADMAP line.
- **Files modified:** `.planning/ROADMAP.md`
- **Verification:** all eight ids grep clean inside the Phase-11 block; `grep -h '^requirements:'`
  across the six plans yields exactly the same set
- **Committed in:** the Task 2 close-out commit

**5. [Rule 1 - Bug] The addendum back-annotation was assumed partly done; it was not**

- **Found during:** Task 1
- **Issue:** The prior coordinator pass had inserted per-block `> LEAN` annotations into the
  **plank-owned** `VOLATILITY_INSTRUMENTS.md`, not into this repo's
  `VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md`, which still carried none. The addendum acceptance criterion
  (`grep -q 'MevOptimization'`) would have failed.
- **Fix:** the full M1–M7 back-annotation was authored in the addendum, matching the plank file's
  content and the `VOLATILITY_INSTRUMENTS_LEAN_ADDENDUM.md` precedent, plus the LEAN-BACKED status
  header, the M6b amendment and the M8 caveat sync.
- **Files modified:** `model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md`
- **Verification:** 8 `> LEAN` lines present; `grep -q 'MevOptimization'` passes
- **Committed in:** `1d28314`

**6. [Rule 3 - Blocking] `requirements mark-complete` is not applicable — CTX ids do not live in REQUIREMENTS.md**

- **Found during:** Task 2
- **Issue:** The executor protocol calls `requirements mark-complete CTX-TRACE`. `.planning/REQUIREMENTS.md`
  is the v1-milestone requirements file (REPO/TOOL/KERN/MAP…) and contains **zero** `CTX-` ids; the
  CTX-* sets have always lived in the per-phase ROADMAP block (same as phases 9 and 10).
- **Fix:** step skipped. `CTX-TRACE` is marked satisfied in the ROADMAP Phase-11 plan line and the
  phase-outcome paragraph, which is the project's established location.
- **Files modified:** none
- **Verification:** `grep -c 'CTX-' .planning/REQUIREMENTS.md` = 0
- **Committed in:** n/a

**7. [Rule 1 - Bug] `roadmap update-plan-progress` clobbered the progress line mid-plan**

- **Found during:** Task 2
- **Issue:** Running the tool before `11-06-SUMMARY.md` existed recomputed the line from disk
  (6 PLANs, 5 SUMMARYs) and overwrote the close-out wording with `5/6 plans executed`.
- **Fix:** the tool was re-run **after** the summary was written, and the final wording set to satisfy
  both the plan's literal criterion and the repo's Phase-10 formatting convention.
- **Files modified:** `.planning/ROADMAP.md`
- **Verification:** `grep -A40 '### Phase 11' .planning/ROADMAP.md | grep '\*\*Plans:\*\* 6 plans'`
- **Committed in:** the Task 2 close-out commit

---

**Total deviations:** 7 auto-fixed (3 blocking, 3 bugs, 1 blocking/skip)
**Impact on plan:** All seven are defects in the plan's own mechanical criteria or stale assumptions
about repo state — the same self-contradiction class as 11-02's `ptradeCPMM`, 11-03's axiom-name grep,
11-04's phantom `lean` and 11-05's docstring regex. Every semantic requirement behind a defective
criterion was verified properly and, in the identifier case, more thoroughly than the criterion asked.
No scope creep; no artifact was edited to satisfy a regex.

## Issues Encountered

**No `.lean` file was touched and none needed to be** — this plan moves the record, not the
mathematics, and `git status --porcelain lean/` was empty throughout. `cd lean && lake build` exits 0
(8063 jobs) at close, as the phase gate requires.

**The subtree push is a no-op by design.** `git subtree push --prefix=lean lean4-spec main` carries
only `lean/`, and this plan changed nothing under `lean/`. The `model/` and `.planning/` changes
therefore reach **`origin` only**; `JMSBPP/cfmm-lean4-spec` is unchanged at `81b2729` and is expected
to be. Anyone looking for §7.1 in the standalone Lean repo will not find it — it lives in the monorepo.

**One handoff is open and is not this session's to close.** The plank-owned
`../plank/notes/VOLATILITY_INSTRUMENTS.md` carries the M6b `OPEN` → `REFUTED` amendment and the landed
T20–T30 annotation as an **uncommitted working-tree change**. Committing it belongs to agent
`ul2inqpl`. Plank HEAD is `df7088f`, identical before and after.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Phase 11 is closed. The milestone's Lean4+math track has no further scheduled work.**

- The designated successor thread is the **interior-`η` curvature layer** (Capponi–Jia; PDFs in
  `../plank/refs/mev/`). It is the direct consequence of M6a: over `Θ_φ` alone there is no trade-off to
  control, so the degeneracy-breaker must come from outside the fee parameter set. That is a phase-brief
  decision for the user, not something this plan schedules.
- Two **optional, non-blocking** formalization follow-ups are named and nothing depends on either:
  (1) a second refutation carrying an explicit `multiFee` witness, which would close the
  `Θ_φ`-restricted σ-varying case; (2) T19's exact Corollary-2 CPMM kernel, the only carrier of the
  `σ²Δt < 8` guard.
- **One concern for any downstream consumer:** everything in §7.1 is downstream of the leading-order
  `ARB ≈ LVR · P_trade` factorization, carries no demand response to the fee, and applies a
  steady-state `P_trade` quasi-statically along a σ-varying path. Verified proofs are not verified
  modelling, and the traceability file's §6(b) says where the missing equilibrium term lives.

## Self-Check: PASSED

- **Files claimed created/modified — all present on disk:** `11-06-SUMMARY.md`, `11-VALIDATION.md`,
  `model/vol_markets/LEAN_TRACEABILITY.md`, `model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md`,
  `.planning/ROADMAP.md`, `.planning/STATE.md`.
- **Commits claimed — both resolve:** `1d28314` (Task 1), `e5f4dd4` (Task 2 close-out).
  `origin/feat/lean4-spec` is at `e5f4dd4`.
- **§7.1 row count:** 14 claim rows, matching the claim above.
- **Identifier check:** 25 names resolved against declaration lines in `MevOptimization.lean`,
  27 against `MevJointProgram.lean`; zero unresolved among the new rows.
- **`lean/` untouched:** `git diff --name-only f39fd07..e5f4dd4 -- lean/` returns 0 files;
  `git subtree push --prefix=lean lean4-spec main` reports "Everything up-to-date" and
  `cfmm-lean4-spec` main remains `81b2729` — as expected and as stated in Issues Encountered.
- **Build:** `cd lean && lake build` exits 0 (8063 jobs).
- **Plank worktree:** HEAD `df7088f` before and after; `notes/VOLATILITY_INSTRUMENTS.md` left as an
  uncommitted working-tree change, as required.
- **Working tree, this plan's scope:** clean. Three entries remain out of scope and were deliberately
  not committed — `model/exp/eta.md` (modified) and `model/exp/eta_pi_trader_delta_control.md`
  (untracked) are another in-progress thread's files, present at session start; `bpp@hotmail.es>` is a
  stray artifact of a malformed shell redirect, also pre-existing. Committing another thread's
  in-progress work to satisfy a clean-tree criterion would be scope creep, so the criterion is recorded
  as met-in-scope rather than met-literally.
- **Commit-content criterion:** the plan expected `LEAN_TRACEABILITY.md` and `ROADMAP.md` in the SAME
  commit (its step 5 stages both at once). The executor's per-task atomic commit protocol splits them:
  `1d28314` carries the traceability + addendum, `e5f4dd4` carries ROADMAP/STATE/VALIDATION/SUMMARY.
  Both are committed and pushed; the intent is satisfied across two atomic commits.

---
*Phase: 11-mev-hazard-inf-program*
*Completed: 2026-07-31*
