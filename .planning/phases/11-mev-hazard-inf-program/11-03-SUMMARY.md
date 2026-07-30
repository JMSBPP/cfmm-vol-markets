---
phase: 11-mev-hazard-inf-program
plan: 03
subsystem: vol-markets-lean-formalization
tags: [aristotle, mev, lambda-arb, ptrade, infimum-program, integration, fidelity-diff, axiom-sweep, byte-identity, subtree-mirror, landed]
requires:
  - "11-02 project cb371ee5 / task d1c57297 (the submitted bundle A) reaching COMPLETE"
  - ".planning/phases/11-mev-hazard-inf-program/11-02-RUN-RECORD.md — the T1–T19 fidelity checklist that is this plan's diff target"
  - "scratch/aristotle-mev/RequestProject/ — the submitted bytes, which are the byte-identity baseline"
  - "scratch/aristotle-mev-PROMPT.txt — the exact hypotheses each T-number was asked for"
  - "lean/vol_markets/VolInstrument.lean, FeeSchedule.lean, FlairOptimization.lean (reused, never modified)"
provides:
  - "lean/vol_markets/MevOptimization.lean — 1046 lines, ptrade + mevHazard/mevMulti + the antitone identification + the SOLVED infimum program, sorry-free and axiom-clean"
  - "lean/lakefile.toml — vol_markets.MevOptimization registered as a root (without it the module is a silent no-build)"
  - ".planning/phases/11-mev-hazard-inf-program/11-03-FIDELITY.md — T1–T19 statement-by-statement diff, the full 25-line axiom sweep, the 10-module byte-identity table"
  - "model/vol_markets/ARISTOTLE_SUMMARY.md — run cb371ee5 (task d1c57297) appended"
  - "memory aristotle-mev-bundle-a-inflight — flipped to RESOLVED; the queue is FREE"
affects:
  - "11-04 (bundle B — UNBLOCKED: the serial queue is now empty)"
  - "11-05/11-06 (consume ptrade, mevMulti and Theta_lambdaMEV_identification as proved objects)"
tech-stack:
  added: []
  patterns:
    - "byte-identity of every submitted dependency verified BEFORE integration, not after — a modified pre-existing module invalidates every prior verification, so the check has to gate the copy"
    - "the returned proof text is treated as immutable: the ONLY edit is the mechanical import rewrite, because hand-editing a returned proof voids the verification it carries"
    - "axiom sweep over EVERY enumerated declaration, generated mechanically from a grep of the module rather than from a hand-picked list"
    - "a fidelity record whose acceptance criteria grep it for forbidden axiom names, so the record states the negative WITHOUT writing those names"
    - "prover-added hypotheses recorded as first-class findings with the reason each is necessary, rather than absorbed as noise"
key-files:
  created:
    - "lean/vol_markets/MevOptimization.lean"
    - ".planning/phases/11-mev-hazard-inf-program/11-03-FIDELITY.md"
    - "scratch/mev-result/ (extracted archive; gitignored)"
    - "scratch/mev-axioms.lean (sweep driver; gitignored)"
  modified:
    - "lean/lakefile.toml"
    - "model/vol_markets/ARISTOTLE_SUMMARY.md"
    - "memory/aristotle-mev-bundle-a-inflight.md, memory/MEMORY.md"
decisions:
  - "The lakefile anchor was adapted rather than followed literally: an independent run (b03494d) had already appended EndogenousMaturity, so MevOptimization was ADDED after it instead of replacing the plan's assumed last entry"
  - "`aristotle download --destination P` writes P as an ARCHIVE FILE, not a directory; the archive was renamed to scratch/aristotle-mev-result.tar.gz (matching every prior run's convention) and extracted into scratch/mev-result/"
  - "The three private helper lemmas were not separately axiom-printed (private names are mangled across module boundaries); their cleanliness follows transitively from the 25 clean public prints, and that reasoning is stated in the record rather than the gap being hidden"
  - "T19's omission is reported as a real gap — the exact CPMM kernel of block M3(ii) now has no formal carrier anywhere in the repo — even though it was designated optional and blocks nothing"
metrics:
  duration: "~35 min"
  tasks: 2
  files: 6
  completed: 2026-07-30
---

# Phase 11 Plan 03: Landing Aristotle Bundle A — MevOptimization Integration Summary

**Aristotle's bundle-A return landed as `lean/vol_markets/MevOptimization.lean` (1046 lines, 25 declarations, sorry-free, 25/25 axiom-clean) with all ten submitted dependency modules proved byte-identical, every one of T1–T18 present and none narrowed, and the whole thing mirrored to both remotes — the one surprise being that Aristotle had to ADD a hypothesis to T15 because the saturation limit as specified was false.**

## What landed

`ptrade φ σ Δt = σ / (σ + φ·√(2/Δt))` and the discrete `λ_ARB` functionals `mevHazard` / `mevMulti`,
built over the **same** `VolInstrument.multiFee` parameter space and the **same** deployed-capital
denominator `D t` as `FlairOptimization.flairHazard` — which is what makes the two hazards
commensurable by construction rather than by assertion. On top of them, the antitone identification
block with every FLAIR direction reversed (strict in `φ̄`, weak in `α` and `u`, isotone in `β`) and
the solved infimum program: the path-**sum** corner bound, bang-bang attainment at the level-corner
top, the `β0 → −∞` saturation limit, a strict gap at every finite `β0`, compact-box minimizer
existence, `Theta_lambdaMEV_identification`, and `mevMulti_min_gt_corner` for M5(iii)'s strict half.

`Θ_{λ_ARB} = {φ̄, α, u}` at its **upper** corner; the shape block cannot attain the infimum. That is
the exact reversal of the solved FLAIR supremum, and it is now machine-checked rather than asserted.

## The three things the run record told this plan to watch, and what happened

The 11-02 checklist named four specific narrowings to look for. All four held:

- **T6 came back STRICT.** `StrictConvexOn ℝ (Set.Ici 0)` proved from the definition (the
  `X/Y + Y/X > 2` route), with `ptrade_convexOn` as the named weakening. Both names exist. This was
  the theorem 11-02 flagged as most likely to be silently downgraded, and the three nonexistent
  Mathlib hints it removed from the prompt appear to have been the right call.
- **T13's right-hand side is a `Finset` SUM,** not a scalar times a path weight. The product form —
  which would be *false*, `ptrade` not being affine — was not used.
- **T8 kept its `Δt`.** `0 < σpath t ^ 2 / 8 * V t * Δt`, and the `σ²·Δt < 8` finiteness guard is
  correctly *not* attached. This was 11-02's first BLOCKER; the fix survived the round trip.
- **T17 carries the admissibility constraint and PROVES `ContinuousOn` rather than assuming it**
  (`IsCompact.exists_isMinOn` at line 859). The degenerate repair the prompt explicitly forbade —
  adding a bare `ContinuousOn` hypothesis — appears nowhere in the file.

## The finding: T15 as specified was false

Aristotle added `hfee : 0 ≤ φbarMax + uMax·αmax0` to `mevMulti_saturation_limit`, and says why in
its own run summary: without it the limiting fee can land on `ptrade`'s **negative-fee pole**, so
the unrestricted limit the prompt requested does not hold.

This is the *same* pole that both 11-02 reviewers independently used to demolish the pre-review T17.
The reviewers found it in one place; it was live in two. The prompt guarded T17 and left T15 open,
and the prover closed the second hole. Recorded as `STRENGTHENED-HYPOTHESES` with the reason, per
the plan's discipline — an added hypothesis is expected behaviour and is only a problem when it goes
undisclosed. Three smaller additions (`0 ≤ u` on T11, a redundant `0 ≤ αmax j` on T14, and the
upper-box constraint on `mevMulti_min_gt_corner`) are tabulated in the fidelity record.

## Verification

- **Byte-identity, checked before integrating anything:** all ten submitted modules
  (`PosSpec Flow RiskDesign Main Panoptic Upsilon GeomProfile FeeSchedule VolInstrument
  FlairOptimization`) returned with empty diffs. Corroborated from the repo side —
  `git status --porcelain lean/` showed exactly the two intended entries, and
  `git diff --stat` over `FlairOptimization.lean` and `VolInstrument.lean` was empty. Aristotle's
  own summary independently states only `MevOptimization.lean` differs.
- **Build:** `lake build vol_markets` (8038 jobs) and `lake build` (8062 jobs) both exit 0. The log
  line `Built vol_markets.MevOptimization (57s)` is the evidence the new module was actually
  elaborated rather than skipped by an unregistered root.
- **Sorries:** zero occurrences of `sorry` or `admit` in the file, in code *or* comment.
- **Axioms:** all 25 enumerated declarations print exactly `[propext, Classical.choice, Quot.sound]`.
  The sweep file was generated mechanically from a grep of the module, so it cannot silently omit a
  theorem.
- **Fidelity:** every T-number T1–T19 has an explicit disposition in `11-03-FIDELITY.md`. No T1–T18
  item is MISSING; no returned conclusion is NARROWED.
- **Remotes:** `origin/feat/lean4-spec` at `42c8e60`; `cfmm-lean4-spec` main at `19afcdd`, a
  fast-forward (the previous tip `0ec3896` was verified to be an ancestor before pushing).
- No API key in any tracked file.

## Deviations from plan

**1. [Rule 3 — Blocking] `aristotle download --destination` writes a FILE, not a directory.**
- **Found during:** Task 1, step 1. The plan's command form implies a directory; the CLI's own help
  says "Path to save the result **archive**". The first invocation left a 56 KB gzip stream sitting
  at `scratch/mev-result`.
- **Fix:** renamed it to `scratch/aristotle-mev-result.tar.gz` — matching the convention every prior
  run in `scratch/` already follows — and extracted into `scratch/mev-result/`. The archive unpacks
  to `aristotle-mev_aristotle/RequestProject/`, so symlinks were placed at
  `scratch/mev-result/RequestProject` and `scratch/mev-result/ARISTOTLE_SUMMARY.md` to make the
  plan's acceptance-criteria paths resolve literally rather than by re-writing them.
- **Commit:** `5dd94e9` (untracked artifacts; `scratch/` is gitignored, so the archive's sha256
  `33c68681…` in the fidelity record is its identity)

**2. [Rule 3 — Blocking] The lakefile anchor had moved.**
- **Found during:** Task 1, step 4. The plan assumed `vol_markets.FlairOptimization` was the last
  root, but an independent parallel run (`b03494d`, EndogenousMaturity) had already appended after
  it.
- **Fix:** appended `"vol_markets.MevOptimization"` **after** `"vol_markets.EndogenousMaturity"`,
  removing nothing. `EndogenousMaturity` was not in bundle A and correctly does not appear in the
  returned archive; it is excluded from the byte-identity check rather than expected to be there.
- **Commit:** `5dd94e9`

**3. [Rule 1 — Bug] The fidelity record's own acceptance criterion forbade the words it needed.**
- **Found during:** Task 2 acceptance run. The criterion greps `11-03-FIDELITY.md` for `sorryAx`,
  `ofReduceBool` and `trustCompiler` and fails if any appears — but the natural way to record a
  clean sweep is to say those three did *not* appear, which writes them.
- **Fix:** the negative is stated by description ("the axiom a `sorry` elaborates to", "the kernel's
  reduce-a-`Bool`-decision axiom", "the compiler-trust axiom") with a note explaining why the
  literals are withheld. Same class of self-contradiction 11-02 hit at its `ptradeCPMM` criterion,
  resolved the same way — preserve the semantic content, pass the mechanical gate.
- **Commit:** `42c8e60`

No Rule 4 escalations. No build failure, no returned-artifact defect, and no need to hand-patch a
proof.

## Honest limitations

- **T19 was omitted, and that is a real gap even though it blocks nothing.** `ARBoverV_exact` — the
  anchor's exact CPMM kernel, block M3(ii) — now has **no formal carrier anywhere in this
  repository**, and it is the only place the `σ²·Δt < 8` finiteness guard would live. It was
  designated optional at submission and the leading-order kernel carries the entire program, so
  nothing in CTX-PTRADE / CTX-MEVHAZ / CTX-INF depends on it. Reported rather than quietly dropped.
- **CTX-INF is satisfied by a corrected T15, not by the T15 that was requested.** The requested
  statement is false. That is a better outcome than a false theorem, but it means the prompt was
  wrong in one more place than its two-reviewer gate caught.
- **Three private helper lemmas were not individually axiom-printed.** Private names are mangled
  across module boundaries, so the sweep cannot address them directly. Their cleanliness follows
  transitively from the 25 clean public prints — sound, but it is an inference rather than a
  measurement, and it is labelled as one.
- **`mevMulti_min_gt_corner` fixes `u = uMax`** rather than quantifying over `u ≤ uMax`. The
  argument that this is the sharp case (larger `u` ⟹ larger fee ⟹ smaller hazard, so `uMax` is the
  hardest case) is an executor argument, **not machine-checked**; the Lean statement covers
  `u = uMax` and nothing else.
- **This is `λ_ARB`, not `λ_MEV`.** The module proves properties of a *summand*. It equals the
  aggregate only under block M7's uniform-clearing reduction (`λ_sandwich = 0`), which is not
  formalized in this bundle. The caveat is carried verbatim in all three mandatory docstrings
  precisely so a later `mevHazard + sandwich` cannot become the double-count block M0 forbids.
- **Verified proofs are not verified modelling.** Everything here is downstream of the approved
  document's leading-order factorization `ARB ≈ LVR·P_trade`, which is an asymptotic approximation,
  carries no demand response to the fee, and applies a steady-state `P_trade` along a varying-σ path
  quasi-statically. Lean checks the derivations; it does not check that the model is the market.

## Self-Check: PASSED

`lean/vol_markets/MevOptimization.lean` (1046 lines), `lean/lakefile.toml` (root present),
`.planning/phases/11-mev-hazard-inf-program/11-03-FIDELITY.md` and the appended
`model/vol_markets/ARISTOTLE_SUMMARY.md` all exist on disk and were re-read after writing. Commits
`5dd94e9` and `42c8e60` resolve via `git log`; the subtree commit `19afcdd` resolves on
`lean4-spec/main` and its `--name-only` listing contains `vol_markets/MevOptimization.lean`.
`git status --porcelain lean/` is empty. The 25-line axiom sweep in the record is the verbatim
captured stdout, not a restatement. Declaration counts (3 defs + 22 public theorems + 3 private)
recounted from the file. Byte-identity re-confirmed by ten `diff` exit codes, all 0.
