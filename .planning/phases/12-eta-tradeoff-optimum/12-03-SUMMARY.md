---
phase: 12-eta-tradeoff-optimum
plan: 03
subsystem: vol_markets / Lean4 formalization pipeline
tags: [aristotle, curvature, capponi-jia, eta, out-of-budget, repair-bundle, axiom-sweep, fidelity, kink]
requires:
  - phase: 12-02
    provides: "The 18-module bundle, 12-02-MODULE-MAP.txt (the non-uniform inverse import rewrite), PROMPT-SHA256 6f28c64f..., BUNDLED-ETA-SHA256 4f5362c1..., and the T1'-T31' fidelity checklist with its OPTIONAL flags"
  - phase: 12-01
    provides: "The APPROVED E0-E8 curvature spec and the NARROWED CTX-DEGEN ruling that bounds what could be asked"
  - phase: 11
    provides: "MevOptimization / MevJointProgram as bundled inputs and as the Theta_phi corner results E7 contrasts against"
provides:
  - "lean/vol_markets/EtaCurvature.lean — 1269 lines, 51 declarations, 0 sorries, all axiom-clean; the 15th vol_markets root"
  - "The interior optimum kphiStar_eq_kphiI + lpExcess_isMaxOn: a KINK, established by two one-sided monotonicity results, with no first-order condition anywhere"
  - "The headline closed form etaStar and the bridge equation curvIndex_etaStar"
  - "The eta-identity EXPONENT half (T28'a): priceEta_eq_p_eta_half / priceEta_eq_P_half"
  - "12-03-PARTIAL-RETURN.md — the OUT_OF_BUDGET record and the sanctioned repair submission"
  - "12-03-FIDELITY.md — input integrity, the 13/15-verbatim + 2-AMENDED statement record, and the requirement-closure verdicts"
affects:
  - "12-04 (traceability) — every status word in the traceability rows comes from 12-03-FIDELITY.md"
  - "plank todo #227 — etaStar is the controller law the note asked for"
tech-stack:
  added: []
  patterns:
    - "OUT_OF_BUDGET is a RECORDABLE OUTCOME, not a failure: record the partial, do not integrate a sorry-carrying module, do not hand-prove the gap"
    - "Scoped repair bundle: original inputs + the partial as working base, prompt covering ONLY the gaps, submitted as a NEW project"
    - "Budget PRIORITY ORDER in the repair prompt, so a second truncation degrades gracefully instead of losing the headline"
    - "Declaration-list identity between the submitted partial and the repair return is the check that catches a silent rename or drop"
    - "Map-driven non-uniform inverse import rewrite (exp.* vs vol_markets.*), never a blanket sed"
key-files:
  created:
    - lean/vol_markets/EtaCurvature.lean
    - .planning/phases/12-eta-tradeoff-optimum/12-03-PARTIAL-RETURN.md
    - .planning/phases/12-eta-tradeoff-optimum/12-03-FIDELITY.md
    - scratch/aristotle-eta-b/ (18 inputs + the partial as working base; gitignored)
    - scratch/aristotle-eta-b-PROMPT.txt (623 words, scoped to the 15 gaps; gitignored)
  modified:
    - lean/lakefile.toml
    - model/vol_markets/LEAN_TRACEABILITY.md
key-decisions:
  - "The OUT_OF_BUDGET partial (36/51, 15 sorries) was NOT integrated — lean/vol_markets/ requires sorry-free, axiom-clean modules and hand-proving the gap is barred"
  - "USER: submit the scoped repair bundle (`submit eta -b`) — 12-CONTINGENCY's option 1 over option 2 (honest OPEN rows)"
  - "No second two-reviewer gate on the repair prompt: the 15 statements are Aristotle's OWN, already type-correct and already building, so the transcription-defect class the gate exists to catch cannot recur"
  - "The two AMENDED statements were ACCEPTED, not re-submitted: both add hypotheses and leave the conclusions intact, and both added hypotheses are correct (E0's own ordering; Mathlib's Real.log = log|x|)"
  - "T28'b absent as pre-authorized ⟹ the user's eta-identity decision is PARTIALLY discharged, and is recorded that way rather than as closed"
patterns-established:
  - "A repair prompt states a priority order over the remaining gaps so budget exhaustion loses the least valuable item, not the headline"
  - "Verify the returned declaration LIST against the submitted partial, not just the count — renames and drops are invisible to a count"
requirements-completed: [CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN]
metrics:
  duration: "~4h 10m (commit span 2026-08-01 10:25 → 14:36; the two Aristotle runs are not included)"
  tasks: 3
  files: 4
  completed: 2026-08-01
---

# Phase 12 Plan 03: Land EtaCurvature Summary

**`lean/vol_markets/EtaCurvature.lean` — 1269 lines, 51 declarations, 0 sorries, all axiom-clean — landed in TWO runs: the first exhausted its budget at 36/51 with 15 `sorry`s and was NOT integrated; a scoped repair bundle carrying the partial as its working base closed the remaining 15, including the headline `curvIndex_etaStar`, the entire optimality family, and the de-degeneration analogue.**

> **RECORDED RETROACTIVELY (2026-08-02).** The work below was executed manually by the phase
> orchestrator rather than by a plan executor, so its per-task commits exist but this SUMMARY did
> not. Everything stated here is verifiable in git and on disk; the verification commands are named
> inline and were re-run at write time. This is itself the plan's largest deviation and is recorded
> as such below.

## Performance

- **Duration:** ~4h 10m of observable commit span (`2f5310c` 2026-08-01 10:25 → `b02caf7` 14:36). The two Aristotle runs' own wall time is not included and was not instrumented.
- **Started:** 2026-08-01T14:25:02Z (`2f5310c`, the OUT_OF_BUDGET record)
- **Completed:** 2026-08-01T18:35:49Z (`b02caf7`)
- **Tasks:** 3 (download + byte-identity + integrate + build; axiom sweep + fidelity; commit + push)
- **Files modified:** 4 tracked (1 created under `lean/`, 1 lakefile, 2 planning records) + 1 traceability section

## Accomplishments

- **The interior optimum is proven.** `kphiStar_eq_kphiI` locates it, `kphiStar_mem_Ioo_iff` gives interiority (`φ < ϱ_I`), and `lpExcess_isMaxOn` establishes that it IS the maximum — from the **two one-sided strict monotonicity results** `lpExcess_strictMonoOn` / `lpExcess_strictAntiOn`, **with no first-order condition anywhere**, because `κ_φ⋆` is a kink.
- **The headline closed form landed as an EQUALITY.** `curvIndex_etaStar` proves `κ_φ(η⋆, Δi) = κ_φ⋆` with `etaStar`'s closed form `ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)` in the statement — obtained by INVERTING the bijection `curvIndex`, not by an optimisation argument.
- **The comparative statics are strict:** `etaStar_pos_iff`, `etaStar_strictMono_premInv`, `etaStar_strictAnti_fee`, `etaStar_strictAnti_spacing`. The fee one is the coupling: raising the fee LOWERS the optimal curvature.
- **The η-side transport landed** (`lpExcessEta_isMaxOn` / `_strictMonoOn` / `_strictAntiOn`), so the optimum is available in η and not only in `κ_φ`.
- **T28'a — the η-identity EXPONENT half — is DISCHARGED**: `priceEta_eq_p_eta_half`, `priceEta_eq_P_half`.
- **The de-degeneration analogue** `eta_no_common_argmax` kept its CONJUNCTION (both `arbLossRatio` and `surplusRatio` strictly fall in η), and `etaStar_coupled_to_fee_corner` carries the coupling — both under the NARROWED CTX-DEGEN scope the user ruled at 12-01.
- **Input integrity held across BOTH runs:** all 18 bundled modules byte-identical to submission. The prover modified nothing outside its target in either run.

## Task Commits

1. **OUT_OF_BUDGET recorded, integration refused** — `2f5310c` (docs) — `12-03-PARTIAL-RETURN.md`: project `4878ca32`, task `e1c846ae`, 723 lines / 51 declarations / **15 `sorry`s**, partial preserved at `scratch/eta-partial-return/` (gitignored), 36 proven declarations enumerated, the two sanctioned 12-CONTINGENCY repairs stated.
2. **Repair bundle submitted** — `93a7122` (chore) — project `c3a617f3-fac9-4ddb-bb7b-a903f10a26c8`, task `4ec89173-19dd-4f9e-b206-9bd99940a699`; bundle = the original 18 inputs (byte-identical, re-verified) + the partial `EtaCurvature.lean` as working base; prompt `scratch/aristotle-eta-b-PROMPT.txt` (623 words) scoped to the 15 sorried declarations only.
3. **Integration + fidelity** — `4ee4234` (feat) — `lean/vol_markets/EtaCurvature.lean` (1269 lines), `lean/lakefile.toml` (root APPENDED after `vol_markets.TauMevAlgebra`), `12-03-FIDELITY.md`.
4. **Traceability §13** — `b02caf7` (docs) — `model/vol_markets/LEAN_TRACEABILITY.md` gained `## 13. ETA — THE INTERIOR CURVATURE CONTROLLER`, the per-E-block claim table.

**Remotes:** `origin/feat/lean4-spec` at `b02caf7` (equal to local `HEAD`); mirror `lean4-spec main` at **`d25fd755fc82f9f085bef34bce3c26ffcec353ce`**. The mirror carries the `lean/` prefix only, so `b02caf7` (a `model/`-only change) is correctly absent from it.

_Note: the plank-side doc marker for this landing was committed in the plank worktree at `08039da` by its owner, not by this tree._

## Files Created/Modified

- `lean/vol_markets/EtaCurvature.lean` — the curvature layer, the interior optimum, the closed-form `η⋆`, the η transport and the cross-model statement. 51 declarations.
- `lean/lakefile.toml` — `"vol_markets.EtaCurvature"` appended to the `vol_markets` roots (line 34). The `exp` roots were not touched.
- `.planning/phases/12-eta-tradeoff-optimum/12-03-PARTIAL-RETURN.md` — the OUT_OF_BUDGET record plus the repair-submission block.
- `.planning/phases/12-eta-tradeoff-optimum/12-03-FIDELITY.md` — input integrity, the statement-fidelity table, and the per-requirement closure verdicts.
- `model/vol_markets/LEAN_TRACEABILITY.md` — §13.

## Verification (re-run at write time, 2026-08-02)

| Claim | Command | Result |
|---|---|---|
| 51 declarations | `grep -cE '^(theorem\|lemma\|noncomputable def\|def) ' lean/vol_markets/EtaCurvature.lean` | `51` |
| 0 sorries | `grep -nE '\bsorry\b\|\badmit\b' lean/vol_markets/EtaCurvature.lean` | no hits |
| 1269 lines | `wc -l` | `1269` |
| Root registered | `grep -n EtaCurvature lean/lakefile.toml` | line 34 |
| Build green | `cd lean && lake build` | exit 0, **8067 jobs** |
| Mirror | `git ls-remote lean4-spec main` | `d25fd75…` |
| Origin | `git rev-parse origin/feat/lean4-spec` | `b02caf7`, equal to `HEAD` |

**NOT re-verified at write time** (asserted from the fidelity record, which was written at execution
time against the artifacts): the 18-module byte-identity in both runs, the declaration-list identity
against the submitted partial, and the 51/51 `#print axioms` sweep. The `scratch/` bundle
directories still exist, so these remain re-checkable, but this retroactive pass did not re-run
them.

## Decisions Made

1. **The partial was not integrated.** 36/51 with 15 `sorry`s violates the standing `lean/vol_markets/` invariant (sorry-free, axiom-clean), and the workflow rule bars hand-proving the gap locally. Recording it and stopping was the correct outcome, not a failure.
2. **12-CONTINGENCY option 1 over option 2.** The user's `submit eta -b` chose the second bundle over closing the phase with 15 honest `OPEN` rows.
3. **No second two-reviewer gate on the repair prompt.** The 15 statements were Aristotle's own, already type-correct, in a file that already built. The transcription-defect class the original gate existed to catch (wrong arity, missing `Real.sqrt` guards, false-as-displayed statements) cannot recur when no statement is being authored; the prompt added only proof-order guidance. Recorded here because skipping a gate is a decision, not a default.
4. **The two AMENDED statements were accepted rather than re-submitted.** Both add a hypothesis and leave the conclusion intact, and both additions are correct:
   - `lpExcess_strictAntiOn` gains `fee < premShock` and `premShock ≤ premInv` — E0's own standing ordering `0 ≤ φ < ϱ_S ≤ ϱ_I` made explicit, needed so the shock branch point does not sit above the investor switch.
   - `etaStar_pos_iff` gains `-1 < premInv` — **Mathlib's `Real.log` is `log|x|`**, so the unguarded criterion is FALSE; witness `premInv = -3, fee = 0`. This is exactly the log-sign trap the 12-02 Model QA review predicted.
5. **T28'b's absence is a PARTIAL discharge, not a closure.** The exponent identity is proven; the factor-share identification is OPEN (E8(6)) and was NOT satisfied by restating T28'a.

## Deviations from Plan

### 1. [Process] The plan was executed manually by the orchestrator, so this SUMMARY is retroactive

- **Found during:** phase close-out (12-04)
- **Issue:** 12-03's tasks were carried out in the orchestrator's own context rather than by a plan executor. The per-task commits, `12-03-PARTIAL-RETURN.md` and `12-03-FIDELITY.md` all exist; `12-03-SUMMARY.md` and the STATE/ROADMAP bookkeeping did not.
- **Fix:** this file, written from git and on-disk ground truth, with the re-verification table above and an explicit statement of what was NOT re-verified.
- **Impact:** the record is complete but its Performance figures are commit-span estimates rather than instrumented timings, and three fidelity claims are inherited rather than re-run.

### 2. [Rule 3 - Blocking] The first run returned OUT_OF_BUDGET — a two-run landing the plan did not anticipate

- **Found during:** Task 1
- **Issue:** 12-03-PLAN assumed one terminal `COMPLETE` return. Task `e1c846ae` returned **`OUT_OF_BUDGET`** with 36/51 proven and 15 `sorry`s. The plan's contingency covered *narrowed* or *absent sections*, not *resource exhaustion mid-file*.
- **Fix:** classified as 12-CONTINGENCY's "second bundle" branch; escalated to the user, who authorised `submit eta -b`. The repair bundle re-used the original 18 inputs plus the partial as working base and scoped its prompt to the 15 gaps, with a transport hint (`curvIndex_etaStar` first, then 12–14 by composition) and a budget priority order so a second truncation would degrade gracefully.
- **Verification:** the repair returned `COMPLETE`; declaration list identical to the submitted partial (no renames, no drops, no additions), 0 sorries.
- **Committed in:** `2f5310c`, `93a7122`, `4ee4234`

### 3. [Record] Two statements came back AMENDED

- **Found during:** Task 2
- **Issue:** `lpExcess_strictAntiOn` and `etaStar_pos_iff` carry hypotheses the prompt did not request.
- **Fix:** none needed — both are added hypotheses with intact conclusions, both are disclosed in the prover's docstrings, and the second is a genuine correction (the unguarded statement is FALSE). Recorded in the fidelity table with the prover's stated reason. **Zero narrowed statements.**
- **Impact:** an added hypothesis is a FINDING. `etaStar_pos_iff`'s guard is the second time in this project that a Mathlib total-function convention falsified a statement as drafted (after `ptrade`'s negative-fee pole in Phase 11).

### 4. [Record] Traceability landed early, in §13 rather than §7.2

- **Found during:** Task 3
- **Issue:** `b02caf7` added the ETA claim table as `## 13.`, immediately after the module landed, rather than leaving it to 12-04 as `### 7.2`.
- **Impact:** §13 follows the file's own convention (§8 endogenous maturity, §9 τ_MEV, §10 JIT, §11 GREEKS, §12 τ_JIT), which had already abandoned §7.x numbering. 12-04 must therefore ADD what §13 lacks rather than duplicate it — recorded so 12-04 does not create two sources of truth for the same statuses.

---

**Total deviations:** 4 recorded (1 process, 1 blocking-and-escalated, 2 record-only).
**Impact on plan:** the plan's mathematics and its integrity gates all held. What changed was the
number of runs (two, not one) and the ownership of the bookkeeping (orchestrator, not executor).

## Issues Encountered

- **Budget exhaustion is not diagnosable in advance.** The first run proved the definitional, `κ_φ` and exponent-bridge layers and stopped exactly at the optimality family — the expensive part. The mitigation now in the record is the repair prompt's explicit priority order; there is no way to size a bundle against budget beforehand.
- **`APPROVED-ETA-SHA256 4f5362c1…` is now stale against the live plank document.** The ESC-1/2/3 corrections landed at `62220db` (~35 min after submission, at the user's direct instruction) and the plank-side `> LEAN` back-annotation landed at plank `08039da`. Both gates that read that pin were already consumed and both passed. Disclosing this is 12-04's job and is listed in its plan.

## User Setup Required

None.

## Next Phase Readiness

- **CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE SATISFIED; CTX-DEGEN SATISFIED AS NARROWED** (user ruling 2026-07-31: no literal de-degeneration of the `Θ_φ` program).
- **The Aristotle queue is FREE** for this project.
- **Open at hand-off to 12-04:** T28'b / E8(6) — the factor-share identification — and the eight other standing E8 caveats; the ESC pin-invalidation disclosure; and the todo #227 closing answer.

---
*Phase: 12-eta-tradeoff-optimum*
*Completed: 2026-08-01 (recorded retroactively 2026-08-02)*
