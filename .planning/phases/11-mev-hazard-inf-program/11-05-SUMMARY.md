---
phase: 11-mev-hazard-inf-program
plan: 05
subsystem: vol-markets-lean-formalization
tags: [aristotle, mev, joint-program, degeneracy, jensen, refutation, counterexample, angstrom, integration, axiom-sweep, doc-fidelity]
requires:
  - "11-04 submitting bundle B (Aristotle project 19f777ab / task f8840dab) and pinning the prompt sha256"
  - ".planning/phases/11-mev-hazard-inf-program/11-04-RUN-RECORD.md — the T20-T30 fidelity checklist this plan diffs against"
  - "scratch/aristotle-mev-joint/RequestProject/ — the 11-module byte-identity baseline"
  - "lean/vol_markets/{MevOptimization,FlairOptimization,VolInstrument}.lean (reused, never modified)"
provides:
  - "lean/vol_markets/MevJointProgram.lean — 481 lines, 22 theorems + 5 defs, sorry-free, 27/27 axiom-clean"
  - "lean/lakefile.toml — vol_markets roots including vol_markets.MevJointProgram"
  - ".planning/phases/11-mev-hazard-inf-program/11-05-FIDELITY.md — byte-identity evidence, full axiom sweep, T20-T30 diff, the T24 verdict"
  - "model/vol_markets/ARISTOTLE_SUMMARY.md — run 19f777ab / task f8840dab appended"
  - "THE T24 VERDICT: REFUTED (counterexample) — mev_ge_flat_under_flair_budget_false"
  - "memory aristotle-mev-bundle-b-inflight flipped to RESOLVED — the queue is FREE"
affects:
  - "11-06 (close-out) — inherits a REQUIRED doc amendment: block M6b must change OPEN -> FALSE, plus a REFUTED traceability row"
  - "any downstream citation of a general varying-sigma flat-fee optimality claim — there is none to cite"
tech-stack:
  added: []
  patterns:
    - "verify byte-identity of every returned dependency BEFORE integrating — a modified proven module invalidates prior verification, and the check is worthless after the fact"
    - "generate the axiom-sweep file from a grep of the module, so no declaration can be silently omitted from its own audit"
    - "recompute a returned counterexample independently, outside the prover, before reporting it as a result"
    - "a grep acceptance criterion requiring a comment marker at line start FALSE-FAILS on Lean block-docstring continuation lines; verify the semantics with a comment-aware scanner and record the criterion as wrong"
    - "a refutation's REACH is a separate question from its validity — state which quantification it settles and which it leaves open"
    - "executor numerics that support a conclusion are labelled NOT machine-checked and are never merged into the verified claim"
key-files:
  created:
    - "lean/vol_markets/MevJointProgram.lean"
    - ".planning/phases/11-mev-hazard-inf-program/11-05-FIDELITY.md"
    - "scratch/mev-joint-result/ (gitignored)"
  modified:
    - "lean/lakefile.toml"
    - "model/vol_markets/ARISTOTLE_SUMMARY.md"
    - "memory/aristotle-mev-bundle-b-inflight.md, memory/MEMORY.md"
decisions:
  - "T24 is recorded as REFUTED (counterexample), Aristotle's outcome 3 — a machine-checked negation theorem, not an OPEN row and not a T25 relabelling"
  - "the refutation's REACH is bounded explicitly: it settles the general schedule-level claim, and the Theta_phi-restricted varying-sigma case is recorded as still OPEN because the witness schedule is sigma-DEcreasing while every Theta_phi schedule is isotone"
  - "supporting numerics showing the violation persists for isotone multiFee schedules are recorded as EXECUTOR EXPLORATION, explicitly not machine-checked, rather than folded into the verified result"
  - "the plan's tax-constant acceptance regex is recorded as WRONG (it cannot recognise Lean block-docstring continuation lines) and the requirement was verified with a comment-aware scanner instead"
  - "three UNUSED hypotheses returned by Aristotle were kept rather than removed — the theorems are stronger than specified, and editing a returned proof voids its verification"
  - "per-task atomic commits were used over the plan's single-commit step, which its own <verify> block (git log -3) already assumes"
metrics:
  duration: "~35 min"
  tasks: 2
  files: 6
  completed: 2026-07-31
---

# Phase 11 Plan 05: Landing Bundle B — The Joint Program and an Unsoftened Refutation Summary

**T24 did not come back proved, and it did not come back open: it came back FALSE. Aristotle returned `mev_ge_flat_under_flair_budget_false`, a machine-checked negation theorem with explicit numeral witnesses, and an independent recomputation in exact rational arithmetic confirms it — the flat fee path costs `31/22 ≈ 1.4091` against the volatility-responsive path's `4/3 ≈ 1.3333`, so the flat path is strictly WORSE and the phase's most-anticipated positive result does not exist because it is not true.**

## What landed

`lean/vol_markets/MevJointProgram.lean` — 481 lines, **22 theorems + 5 defs = 27 declarations**,
sorry-free, **27/27 `#print axioms` = `[propext, Classical.choice, Quot.sound]`**. The import
rewrite `RequestProject.` → `vol_markets.` was the ONLY edit; `lake build vol_markets` (8039 jobs)
and `lake build` (8063 jobs) both exit 0, with `Built vol_markets.MevJointProgram (27s)` proving the
module was actually elaborated rather than skipped by an unregistered root.

- **(A) THE DEGENERACY, T20–T22.** One admissible point simultaneously maximizes `flairMulti` and
  minimizes `mevMulti`; the same coincidence holds in the shape coordinate, so a single common
  direction `β → −∞` improves both; and no linear scalarization `κ ≥ 0` repairs it. **Unconstrained
  over `Θ_φ` there is no trade-off and the shape block `(β, γ)` is NOT essential** — the expectation
  the phase set out with, now machine-checked as refuted.
- **(B) THE CONSTRAINED PROGRAM, T23–T25.** T23 supplies the linearity half: a FLAIR budget pins the
  mean fee `B/W` and leaves the path SHAPE free. T24 is FALSE (below). T25 survives at the PATH
  level via the new `flairPath`/`mevPath` carriers and their two `rfl` bridges, with a strict
  companion consuming `ptrade_strictConvexOn` — the STRICT form, not the non-strict fallback.
- **(C) THE ANGSTROM BRIDGE, T26–T30.** The rebate and its argmin-invariance (for every `τ < 1` the
  rebate changes the program's VALUE, not its SOLUTION, so `τ` is formally outside `Θ_φ`); the
  parametric tax `k/(k+1)` with `k` FREE; the cadence lever ISOTONE in `Δt`; and `mevTotal` as
  **plain hazard addition** with the `probOr` correspondence in its own lemma — the BLOCKER the
  11-04 two-reviewer gate caught, correctly implemented.

## The T24 verdict: REFUTED, and recorded as a result

The plan existed to get exactly one thing right, and the honest answer turned out to be the third of
the three sanctioned outcomes. The returned negation theorem is, whitespace-normalized,
**character-for-character the block the prompt mandated for outcome 3** — nothing renamed, nothing
weakened.

The witness is `T = 2`, `Δt = 2`, `σ = (1, 10)`, unit weights and denominators, evaluated fees
`(2, 0)`, budget `B = 2`, flat fee `1`. **I recomputed it outside Lean in exact rationals rather
than taking the prover's word**: `ptrade φ σ 2 = σ/(σ+φ)`, so the flat path costs
`1/2 + 10/11 = 31/22` and the tilted path `1/3 + 1 = 4/3`. The claimed inequality is violated. The
failing hypothesis is named in the module's own docstring: volatility VARIES, so the summands are
different convex functions at different `t` and ordinary Jensen never applies — exactly the
non-sign-definite covariance term the prompt anticipated.

It is axiom-clean because it closes by `norm_num` on numerals rather than the compiled-evaluation
tactic the prompt forbade.

**The anti-relabelling apparatus was not needed but was checked anyway:** T25 exists under its own
name with `const_sigma` in it, is nowhere described as satisfying T24, and no constancy hypothesis
was smuggled under T24's name.

### The reach of the refutation — stated, not glossed

The finding I consider most important for 11-06 is not the refutation itself but its **scope**. The
witness schedule `φfun x = if x = 1 then 2 else 0` is DECREASING in σ, whereas every schedule
reachable inside `Θ_φ` is isotone — `VolInstrument.multiFee_monotone` proves
`Monotone (multiFee n γ β α φbar u)` under `0 < γ j`, `0 ≤ α j`, `0 ≤ u`. So the machine-checked
theorem settles the GENERAL schedule-level claim (which approved block M6b had labelled OPEN, and
which must now be corrected to FALSE), but **on its own it does not settle the `Θ_φ`-restricted
case, which is recorded as still OPEN.**

Executor numerics indicate the violation persists there too: a genuine
`multiFee(σ) = 2 + 2·logistic(8·(σ−1.5))` schedule at `σ = (0.5, 2.5)` gives flat `1.194805` against
schedule `1.169203`. **This is floating-point exploration, is labelled NOT machine-checked wherever
it appears, and is not merged into the verified claim.** It is recorded because it bears on how far
M6b's correction must go, and it names the natural follow-up theorem: a second refutation carrying
an explicit `multiFee` witness.

## Fidelity: nothing narrowed, nothing renamed

Every specified statement was whitespace-normalized and compared against the corresponding fenced
block in the prompt — whose sha256 re-verified at integration time **equals the pin in
`11-04-RUN-RECORD.md`**, so the diff is against the bytes actually sent.

**All of T20, T21, T22, T23, the four path carriers, T24's refutation, T25, T26, T27, T28, T29 and
T30's four declarations are byte-identical to specification.** Zero narrowing. Zero renaming.

**Aristotle added no corrective hypothesis anywhere** — a contrast with bundle A, where T15 as
specified was false and needed a new `hfee` guard. The only additions are on T25's strict companion
(`0 < w t` on the whole range, plus a non-constancy witness), and both were pre-authorized by the
prompt, which had named that exact route because Mathlib's `StrictConvexOn.map_sum_lt` requires
`0 < w i` on the whole index set.

Three binders came back UNUSED (`hW` on `flair_budget_mean` and `flairPath_budget_mean`, `hτ1` on
`mevNet_le_mev`), so those theorems are STRONGER than specified. Recorded rather than removed —
editing a returned proof to silence a linter would void its verification.

**Byte-identity held: all eleven bundled dependency modules returned with empty diffs**, checked
BEFORE integrating anything, and corroborated from the repository side (`git status --porcelain
lean/` showing exactly two entries; empty `git diff --stat` over `MevOptimization`,
`FlairOptimization` and `VolInstrument`). The bundled document returned byte-identical too, so the
prover's copy was never mutated mid-run.

## Verification

- 27/27 axiom sweep clean, the sweep file **generated from a grep of the module** so it cannot
  silently omit a declaration; every name resolved and the run exited 0.
- No `sorry`/`admit`, no compiled-evaluation tactic, no identifier `η`, no affine identification of
  `mevMulti`, no unintended file changed under `lean/`.
- All six mandated module-docstring caveats present, including **(vi) M8's SCOPE OF THE AGGREGATE** —
  the caveat the 11-04 gate forced in, in the one module that names an object "the total".
- Pushed to origin (`94e7fa9`) and to `cfmm-lean4-spec` main (subtree `81b2729`), **verified a
  fast-forward before pushing**; the remote tip carries `vol_markets/MevJointProgram.lean`.
- No API key in any tracked file.

## Deviations from plan

**1. [Rule 3 — Blocking] The plan's tax-constant acceptance regex cannot recognise Lean docstrings.**
- **Found during:** Task 1, sweep step 7.
- **Issue:** the criterion requires every line matching `\b49\b|\b0\.98\b` to also match
  `^\s*(--|/-|\*|-)`. The single hit, line 401, is a *continuation* line of the block docstring
  opened at 400 and closed at 405; Lean block docstrings carry no per-line marker, so the criterion
  would reject any multi-line docstring. The criterion is wrong, not the file.
- **Fix:** verified the semantic requirement with a comment-aware scanner that tracks `/- … -/`
  nesting and `--` comments character by character — both hits are inside the docstring, verdict
  PASS, no numeric constant in any statement. Recorded in the fidelity record rather than papered
  over. Same self-contradiction class as 11-02's `ptradeCPMM`, 11-03's axiom-name grep and 11-04's
  phantom `lean`.
- **Commit:** `94e7fa9`

**2. [Rule 3 — Blocking] The download path is one directory deeper than the plan assumes.**
- **Found during:** Task 1, step 1.
- **Issue:** `aristotle download --destination P` writes P as an ARCHIVE FILE (the 11-03 precedent),
  and extraction yields `scratch/mev-joint-result/aristotle-mev-joint_aristotle/RequestProject/`,
  not the `scratch/mev-joint-result/RequestProject/` the plan's criteria reference.
- **Fix:** downloaded to `scratch/mev-joint-result.tar.gz`, extracted, and added a symlink
  `scratch/mev-joint-result/RequestProject → aristotle-mev-joint_aristotle/RequestProject` so the
  plan's literal byte-identity criterion runs as written (it passes, 11/11). `scratch/` is
  gitignored, so this is a local convenience, not a tracked artifact.
- **Commit:** `9e2a587`

**3. [Rule 3 — Blocking] `ARISTOTLE_SUMMARY.md`'s `tail -60` criterion missed the appended block.**
- **Found during:** Task 2, step 6.
- **Issue:** the run-summary block is ~75 lines and names `MevJointProgram` only near its top, so
  `tail -60 … | grep -q 'MevJointProgram'` failed although the summary was correctly appended.
- **Fix:** appended a closing provenance line carrying the integrated artifact's path, sha256 and a
  pointer to the fidelity record — useful in its own right, and the criterion now passes.
- **Commit:** `94e7fa9`

**4. [Rule 3 — Blocking] Per-task commits versus the plan's single-commit step.**
- **Found during:** Task 1 close.
- **Issue:** the plan's Task-2 step 7 stages everything in one commit, and one acceptance criterion
  greps `HEAD` for `MevJointProgram.lean`; the executor protocol requires atomic per-task commits.
- **Fix:** committed per task (`9e2a587` module, `94e7fa9` docs). The plan's own `<verify>` block
  uses `git log --oneline -3 --name-only`, which assumes exactly this, so the plan is internally
  inconsistent and the `<verify>` reading was followed. The subtree criterion is unaffected: the
  docs commit does not touch `lean/`, so `lean4-spec/main`'s tip IS the module commit.
- **Commit:** `94e7fa9`

No Rule 4 escalations were needed. No proof was hand-edited and no failing proof was patched.

## Honest limitations

- **The phase's headline constrained result is a refutation.** Nothing downstream may cite a general
  varying-σ flat-fee optimality claim, because it is false. What survives is the constant-volatility
  path-level statement, which is a genuine result on a strictly smaller domain and is reported as
  such.
- **The `Θ_φ`-restricted varying-σ case is OPEN**, not proved and not refuted. The numerics pointing
  toward refutation are executor exploration and carry none of the standing of the theorem.
- **T24's refutation and T25 both instantiate the arbitrage measure at the traded-flow weight
  (`a = w`).** That aligned-measure assumption is strong — it forces noise-trader flow to be
  proportional block-by-block to leading-order LVR — and without it the constrained conclusion can
  reverse. In T20–T22 `w` and `a` remain two free functions, so the assumption stays visible exactly
  where it is used. Note that in T24/T25 it is imposed by direct substitution rather than as an
  explicit `a = w` hypothesis, which is what the prompt specified but is worth a reader's attention.
- **Everything sits downstream of the leading-order `ARB ≈ LVR · P_trade` factorization**, carries no
  demand response to the fee, and applies a steady-state `P_trade` quasi-statically along a
  varying-σ path. The T20–T22 degeneracy in particular is a property of volume-INELASTIC objectives,
  not a market-equilibrium claim.
- **`λ_MEV` here is two channels, not all MEV.** Backruns, multi-block MEV (which attacks the T29
  cadence lever directly by lengthening effective `Δt`), JIT liquidity and fixed gas costs are all
  outside the aggregate.
- **The bundle remains untracked.** `scratch/` is gitignored project-wide, so the submitted bytes'
  identity rests entirely on the sha256 pins — which is why re-verifying the prompt hash at
  integration time mattered, and it matched.
- **Verified proofs are not verified modelling.** Every statement is a theorem about the formalized
  objectives, not about a market.

## Owed to 11-06

1. **Block M6b must change `OPEN` → `FALSE`** for the varying-σ schedule comparison, with a
   `REFUTED` traceability row citing `mev_ge_flat_under_flair_budget_false`.
2. The `Θ_φ`-restricted varying-σ case should be added as an explicit OPEN row (the project has
   clean precedent for shipping OPEN rows deliberately).
3. The degeneracy (T20–T22) is now machine-checked and the doc's M6a can cite the three theorem
   names.

## Self-Check: PASSED

All six claimed files exist. All three claimed commits resolve (`9e2a587` module, `94e7fa9` docs,
`81b2729` on `cfmm-lean4-spec` main). Numeric claims re-verified against the artifacts: 481 lines,
22 theorems, 5 defs, 27/27 axiom lines matching `[propext, Classical.choice, Quot.sound]` with zero
non-conforming lines. `git status --porcelain lean/` is empty. `lake build` exits 0.
