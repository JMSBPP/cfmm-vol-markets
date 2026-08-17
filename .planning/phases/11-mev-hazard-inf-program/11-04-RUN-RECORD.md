# 11-04 — Aristotle bundle B: submission run record

Provenance for the single serial Aristotle task carrying the JOINT sup-FLAIR / inf-MEV program —
its degeneracy (M6a), the constrained/Jensen program where the trade-off actually lives (M6b), and
the statement-level Angstrom bridge (M7).

## Submission

| Field | Value |
| --- | --- |
| Submit timestamp (UTC) | `2026-07-30T21:43:24Z` |
| **project id** | `19f777ab-e4ca-47ca-86a1-bf64af79fa90` (name `aristotle-mev-joint`) |
| **task id** | `f8840dab-5723-4a09-9632-1391561180c5` |
| Target module | `RequestProject/MevJointProgram.lean` (NEW; namespace `MevJointProgram`) |
| Command | `aristotle submit --project-dir scratch/aristotle-mev-joint "$(cat scratch/aristotle-mev-joint-PROMPT.txt)"` |
| Status at record time | `IN_PROGRESS` |

Exactly ONE submission command — the single row above, and no other — was executed for this plan.
This record contains exactly one occurrence of the submit command string, which is the mechanical
check that the serial-queue rule held. The API key was supplied by sourcing the gitignored worktree
`.env`; it was never printed and appears in no tracked file.

**Submit-time warning, recorded and adjudicated:** the CLI again warned *"Your project contains
.lean files but no .lake folder."* Expected and benign — bundles A (`aristotle-mev`) and the FLAIR
run carried no `.lake` either, and both returned axiom-clean modules. The bundle pins the
environment by `lean-toolchain` + `lakefile.toml` + `lake-manifest.json` instead (11-RESEARCH
PIT-8).

## Authorization

The blocking checkpoint question was put to the user verbatim per the plan's Task 3 step 2. The
verbatim reply, reproduced exactly as received:

```
submit, and in parallel there is much prose on VOLATILITY_INSTRUMNETS, recall to be minimalistic there
```

Read as the `submit` resume signal. The second clause is a standing instruction to the plank-doc
prose pass, which the coordinator is running concurrently and OUTSIDE the `### MEV` M-blocks; it is
recorded here because it arrived in the same authorization, and it did not alter this submission —
see the step-1b re-check below, which proves the M-blocks were untouched at submit time.

Zero unresolved BLOCKER/MAJOR rows existed in `11-04-PROMPT-REVIEW.md` at the time the question was
asked.

## Artifact hashes (the bundle is untracked, so these ARE its identity)

`scratch/` is gitignored project-wide (`.gitignore:57`) and no Aristotle bundle has ever been
tracked. The submitted bytes are therefore pinned here by hash rather than by commit.

```
PROMPT-SHA256:       f471801914b304aa4c2cc44f4412ef7d1a7104d7fe6b6f6ac8c7a8454c819a12
BUNDLED-DOC-SHA256: 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
```

`BUNDLED-DOC-SHA256` is carried forward unchanged from `11-02-RUN-RECORD.md` and still equals
`APPROVED-DOC-SHA256` from `11-01-REVIEW.md`: **the prover received document bytes identical to what
the user approved.**

Prompt: 850 lines. The pre-review prompt hashed
`9a33f2f57d5bf7d2fac6bf90e032611c8d92247df18dc968b16250330521c0a6` (760 lines); the hash above is
the post-reviewer-resolution text, which is what was actually sent.

## Bundle inventory (as submitted)

```
scratch/aristotle-mev-joint/
  lakefile.toml          # name="RequestProject", mathlib rev=v4.28.0
  lake-manifest.json
  lean-toolchain         # leanprover/lean4:v4.28.0
  RequestProject/
    FeeSchedule.lean  FlairOptimization.lean  Flow.lean  GeomProfile.lean
    Main.lean  MevOptimization.lean  Panoptic.lean  PosSpec.lean
    RiskDesign.lean  Upsilon.lean  VolInstrument.lean
    VOLATILITY_INSTRUMENTS.md
```

**11 `.lean` modules** — bundle A's ten plus the newly PROVEN `MevOptimization.lean` — plus the
approved document. Verified before submit: zero `import vol_markets` occurrences anywhere in the
bundle (imports rewritten to `import RequestProject.`); the bundled `MevOptimization.lean` is
byte-identical to the committed `lean/vol_markets/MevOptimization.lean` modulo that mechanical
rewrite; zero `sorry` / `admit` in any dependency.

`EndogenousMaturity.lean` exists in the repo (independent parallel run) but is deliberately NOT in
this bundle: nothing in T20–T30 references it, and the plan's literal 11-module inventory governs.

## Queue-empty evidence (PIT-9; memory `aristotle-no-queue`)

Checked immediately before submitting:

```
$ aristotle list --status RUNNING --limit 100
No projects found.

$ aristotle list --limit 6
128b24ae-c674-4aae-bd09-e71a516e7839  3 hours ago  aristotle-endog-maturity       IDLE
cb371ee5-f27c-48d2-a396-725751fd7c36  4 hours ago  aristotle-mev                  IDLE
78bac8dd-3004-4881-a223-8b686b16cb25  3 days ago   aristotle-flair                IDLE
da1c9fce-641b-42ab-a32e-4854532a6ca6  4 days ago   aristotle-vol-instrument       IDLE
664d9abb-e523-41f0-a13c-564830c234c2  5 days ago   aristotle-geom-fee             IDLE
f9865d3a-a202-49de-8fd7-3ea968856783  1 week ago   aristotle-panoptic-upsilon-... IDLE

$ aristotle tasks cb371ee5-f27c-48d2-a396-725751fd7c36
d1c57297-39b2-47ad-8048-492a407c6498  4 hours ago  FORMALIZE AND SOLVE the lam...  COMPLETE
```

No project RUNNING, no task QUEUED, and **bundle A's task `d1c57297` reached `COMPLETE`** — the
serial-queue precondition. Corroborated from the repository side: `git log` shows commit `5dd94e9`
touching `lean/vol_markets/MevOptimization.lean`, i.e. bundle A is not merely complete but LANDED
and committed.

Confirmed after submitting, that exactly one task is in flight:

```
$ aristotle list --limit 3
19f777ab-e4ca-47ca-86a1-bf64af79fa90  20 secs ago  aristotle-mev-joint       RUNNING
128b24ae-c674-4aae-bd09-e71a516e7839  3 hours ago  aristotle-endog-maturity  IDLE
cb371ee5-f27c-48d2-a396-725751fd7c36  4 hours ago  aristotle-mev             IDLE
```

## Step-1b fidelity re-check (run immediately before submit)

The plank document is live, uncommitted, owned by agent `ul2inqpl`, and was being edited
CONCURRENTLY by the coordinator's prose-minimization pass while this submission was prepared. The
gate was therefore re-run against all three copies at submit time:

```
BUNDLED-DOC-SHA256  : 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
11-02 pin           : 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
STEP 1b HASH: PASS

$ diff <M-blocks of approved addendum> <M-blocks of bundled doc>      -> EMPTY (181 lines each)
$ diff <M-blocks of approved addendum> <M-blocks of LIVE plank doc>   -> EMPTY (181 lines each)
STEP 1b M-BLOCK DIFF: PASS on both
```

**Whole-file live-doc hash MISMATCHES and this is EXPECTED, not a failure.** The live plank file is
now `1763faf976052bb2e4e046beea2dffbd99293bdf2ace1dc7fbfb4ab522c48e2c`, 745 lines against the
bundled copy's 646 — it has gained an endogenous-maturity block, LEAN annotations, and the decided
recalibration law since the 11-02 pin. **Every one of those changes sits OUTSIDE `### MEV`.** The
operative check is the M-block extraction diff, which is empty across all three copies; the
whole-file hash is not the gate and would fire on any unrelated edit to a 745-line living document.

## Notation gate runs — both recorded, the failing one not suppressed

| Target | Result |
| --- | --- |
| `model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` | **PASS** |
| bundled doc's extracted `### MEV` section (186 lines) | **PASS** |
| `scratch/aristotle-mev-joint-PROMPT.txt` (informational) | **FAIL — PIT-1** |

The prompt's failure is mention-versus-use and is benign: both hits are the prohibition itself
("Do NOT introduce an identifier named `η`"). A prompt that forbids the glyph must name it.
Adjudicated and recorded rather than suppressed, on the 11-01 precedent.

## Reviewer gate

`11-04-PROMPT-REVIEW.md` — Reality Checker (mandatory) + Model QA Specialist, spawned as independent
read-only processes IN PARALLEL, run on THE PROMPT rather than the plan (PIT-7). The specialist pick
is deliberately the same as 11-01 and 11-02 so the three gates are comparable.

Both returned NEEDS WORK: **2 BLOCKER (the same defect, reached independently), 2 MAJOR, 8 MINOR,
1 DOC-LEVEL**; every BLOCKER and MAJOR resolved before the submission was spent.

**The BLOCKER, found independently by both reviewers:** the prompt's drafted `mevTotal` — specified
that way by 11-04-PLAN.md's own action text — applied `VolInstrument.probOr` to unbounded hazards,
which the approved block M7 explicitly forbids ("plain addition of rates … NOT applied to the
unbounded hazards directly"). Verified independently by the executor against M7 and against the
already-proven `VolInstrument.probOr_hazard`, whose statement IS the proof that the hazard-side
image of `probOr` is `lamM + lamX`. It would have been INVISIBLE to the machine check: at
`λ_sandwich = 0` both reduction theorems hold under either definition, the build goes green and the
axiom sweep is clean. Corrected to `lamARB + lamSand` with the correspondence carried as a named
lemma. Doc-over-plan, exactly as 11-02 adjudicated its `·Δt` BLOCKER.

**Executor-found, before either review ran:** the plan's T25 was a TRIVIALITY as drafted. At the
schedule level with `σ_t ≡ σ0`, `φfun (σpath t)` is already constant, both sides collapse to an
EQUALITY, and the strict half's non-constancy hypothesis is unsatisfiable — it would have returned
"proved" and been banked as the delivered fallback while carrying no content. That is the document's
OWN `OPEN` note in M6b. Section (B) now defines path-level carriers `flairPath` / `mevPath` with two
definitional bridge lemmas and states T25 at the PATH level, which is the document's own
quantification and where the Jensen argument has content.

## T20–T30 fidelity checklist — the target for plan 11-05

Plan 11-05 must diff the returned module against this list. A returned theorem whose hypothesis list
is SHORTER, or whose conclusion is WEAKER, than specified here is a silent narrowing and must be
reported as such rather than accepted (PIT-4).

| # | Name | What it must say |
| --- | --- | --- |
| T20 | `joint_corner_degeneracy` | M6a(i). One admissible point simultaneously maximizes `flairMulti` and minimizes `mevMulti`. **MUST carry `hφ0 : 0 ≤ φbar`** — without it the second conjunct is FALSE at `ptrade`'s negative-fee pole |
| T21 | `joint_beta_degeneracy` | M6a(ii). The monotonicity PAIR at fixed levels: lowering `β` raises FLAIR and lowers MEV. Same hypothesis block as T20 plus `0 < γ j`. NOT to be packaged as two `Tendsto` limits |
| T22 | `joint_scalarization_degeneracy` | M6a(iii). For every `κ ≥ 0` the corner also extremizes `flairMulti − κ·mevMulti`. Docstring MUST carry the volume-inelasticity qualifier |
| T23 | `flair_budget_pins_mean_fee` | The linearity half: `flairHazard` is the `ν`-weighted sum, so a fixed budget `B` pins the mean fee `B/W` (requires `0 < W`) |
| T24 | `mev_ge_flat_under_flair_budget` | **PRIMARY, and the phase's main mathematical risk.** σ-VARYING, aligned measure `a = w`, conclusion displayed as a `Finset` sum. THREE acceptable outcomes: proved as stated / proved with disclosed extra hypotheses / **formal refutation `mev_ge_flat_under_flair_budget_false` with explicit numeral witnesses**. An added hypothesis that forces the fee path CONSTANT does NOT count as outcome 2 |
| T25 | `mev_ge_flat_under_flair_budget_const_sigma` | **FALLBACK, REQUIRED REGARDLESS.** Stated at the PATH level (`flairPath` / `mevPath`), constant σ, plus a STRICTNESS companion consuming `ptrade_strictConvexOn`. Must NOT be relabelled as T24 |
| — | `flairPath`, `mevPath`, `flairPath_schedule`, `mevPath_schedule` | The path-level carriers and their two definitional bridges to the schedule-level functionals |
| T26 | `mevNet` + `mevNet_le_mev`, `mevNet_anti_tau`, `mevNet_eq_zero_of_tau_one` | The rebate. Nonnegativity discharged via `mevMulti_nonneg`, NOT assumed. Docstring routes the `λ_ARB` vs `λ_MEV` identification through T30 |
| T27 | `mevNet_argmin_invariant` | For every `τ < 1`, `IsMinOn` iff — the rebate changes the program's VALUE, not its SOLUTION. Packing `(φbar, α, β, γ)` matching `mevMulti_exists_min_compact` |
| T28 | `taxFraction` + `taxFraction_mem_Ico`, `taxFraction_mono` | `k/(k+1)` with **`k` FREE. NO numeric constant in any statement**; `k = 49` permitted only in a dated docstring, with the LP-share upper-bound consequence stated |
| T29 | `mev_mono_dt` | **ISOTONE** in `Δt`. NO second half about `flairMulti` being `Δt`-independent (vacuous — it has no `Δt` argument); one docstring remark instead, plus the partial-vs-calendar-time and sub-second-validity qualifications |
| T30 | `mevTotal` + `mevTotal_eq_arb_of_sandwich_zero`, `mevTotal_mevMulti_eq_of_sandwich_zero`, `mevTotal_probOr_hazard` | **`mevTotal := lamARB + lamSand`, PLAIN ADDITION — NOT `probOr`.** The `probOr` correspondence lives in its own lemma via `probOr_hazard`. Docstring must bound the nulling to INTRA-batch |

Also required of the returned module, and checkable mechanically:

- no `sorry`, no `admit`; `#print axioms` yields only `propext`, `Classical.choice`, `Quot.sound`
  (`native_decide` explicitly forbidden in the refutation route — it is not axiom-clean)
- **none of the 11 existing `.lean` files modified** (verify byte-identity on integration)
- NO identifier named `η`
- NO affine identification of `mevMulti`
- `w` and `a` never silently identified; `a = w` appears only as an explicit hypothesis
- mandated module docstring caveats (i)–(vi), including **(vi) M8's SCOPE OF THE AGGREGATE**

## Post-submit status — IN FLIGHT

```
21:43:24Z  submitted
21:43:43Z  IN_PROGRESS
```

**Do NOT poll with `aristotle show`** — it streams events and blocks. Poll with
`aristotle tasks 19f777ab-e4ca-47ca-86a1-bf64af79fa90`, which returns immediately (reusable
operational fact, established in 11-02).

**Resume procedure:** poll `aristotle tasks 19f777ab-e4ca-47ca-86a1-bf64af79fa90`. On `COMPLETE`,
run `aristotle download` (note: `--destination P` writes P as an ARCHIVE FILE, not a directory —
11-03's deviation 1) and proceed to plan 11-05, diffing the returned statements against the T20–T30
checklist above. On `FAILED`, do NOT resubmit from inside this plan — record the failure text here
and escalate.

Integration is plan 11-05's job; nothing is integrated here, and no Lean file was touched.
