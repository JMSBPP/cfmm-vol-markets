# 11-02 — Aristotle bundle A: submission run record

Provenance for the single serial Aristotle task carrying `ptrade`, the discrete `λ_ARB`
functionals, and the SOLVED infimum program.

## Submission

| Field | Value |
| --- | --- |
| Submit timestamp (UTC) | `2026-07-30T17:13:00Z` |
| **project id** | `cb371ee5-f27c-48d2-a396-725751fd7c36` |
| **task id** | `d1c57297-39b2-47ad-8048-492a407c6498` |
| Target module | `RequestProject/MevOptimization.lean` (new; namespace `MevOptimization`) |
| Command | `aristotle submit --project-dir scratch/aristotle-mev "$(cat scratch/aristotle-mev-PROMPT.txt)"` |
| CLI | `aristotlelib 2.1.0` |
| Status at record time | `QUEUED` |

Exactly ONE submission command — the single row above, and no other — was executed for this plan.
This record contains exactly one occurrence of the submit command string, which is the mechanical
check that the serial-queue rule held. The API key was supplied by sourcing the
gitignored worktree `.env` (`.gitignore:15`); it was never printed and appears in no tracked file.

**Submit-time warning, recorded and adjudicated:** the CLI warned *"Your project contains .lean
files but no .lake folder."* This is expected and benign — `scratch/aristotle-flair/` likewise
carried no `.lake`, and that run returned 15 axiom-clean theorems in one submission. The bundle
pins the environment by `lean-toolchain` + `lakefile.toml` + `lake-manifest.json` instead
(11-RESEARCH PIT-8).

## Authorization

The blocking checkpoint question was put to the user verbatim per the plan's Task 3 step 2. The
verbatim reply, reproduced exactly as received:

```
submit
```

Read as the `submit` resume signal. Zero unresolved BLOCKER/MAJOR rows existed in
`11-02-PROMPT-REVIEW.md` at the time the question was asked.

## Artifact hashes (the bundle is untracked, so these ARE its identity)

`scratch/` is gitignored project-wide (`.gitignore:57`) and no prior Aristotle bundle was ever
tracked. The submitted bytes are therefore pinned here by hash rather than by commit.

```
PROMPT-SHA256:       c7ed66e923fadd8880f011bad44d5616f3f4b3c687bf2c5ac78a6a54a5671d54
BUNDLED-DOC-SHA256: 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
```

The matching pin from `11-01-REVIEW.md` `## User disposition`:

```
APPROVED-DOC-SHA256: 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
```

`BUNDLED-DOC-SHA256 == APPROVED-DOC-SHA256`: **the document submitted to the prover is byte-identical
to the text the user approved.** The live plank file hashed identically at submit time as well, so
all three agree.

Prompt: 275 lines. The pre-review prompt hashed
`4adc0d3ef3e87fcbec07c3c18dfaf21453b7da20aeff421432b1c3e2ff17335a`; the hash above is the
post-reviewer-resolution text, which is what was actually sent.

## Bundle inventory (as submitted)

```
scratch/aristotle-mev/
  lakefile.toml          # name="RequestProject", mathlib rev=v4.28.0
  lake-manifest.json
  lean-toolchain         # leanprover/lean4:v4.28.0
  RequestProject/
    FeeSchedule.lean  FlairOptimization.lean  Flow.lean  GeomProfile.lean
    Main.lean  Panoptic.lean  PosSpec.lean  RiskDesign.lean
    Upsilon.lean  VolInstrument.lean
    VOLATILITY_INSTRUMENTS.md
```

10 `.lean` modules (not the FLAIR run's 9 — `FlairOptimization.lean` is the added mirror template)
plus the approved document. Verified before submit: zero `import vol_markets` occurrences anywhere
in the bundle (imports rewritten to `import RequestProject.`); zero `sorry` / `admit` in any
dependency.

## Queue-empty evidence (PIT-9; memory `aristotle-no-queue`)

Checked immediately before submitting, and again as a final gate:

```
$ aristotle list --status RUNNING --limit 100
No projects found.

$ aristotle list --limit 5
78bac8dd-3004-4881-a223-8b686b16cb25  3 days ago  aristotle-flair             IDLE
da1c9fce-641b-42ab-a32e-4854532a6ca6  3 days ago  aristotle-vol-instrument    IDLE
664d9abb-e523-41f0-a13c-564830c234c2  5 days ago  aristotle-geom-fee          IDLE
f9865d3a-a202-49de-8fd7-3ea968856783  1 week ago  aristotle-panoptic-upsilon-...  IDLE
c30c6ae3-793b-4709-bb23-9db8d1feeac5  1 week ago  aristotle-panoptic-upsilon  IDLE

$ aristotle show 78bac8dd-3004-4881-a223-8b686b16cb25
COMPLETE (started 76h 29m ago)
Task: beed2796-ef89-4306-937d-c777805c2ced   COMPLETE
```

No project was RUNNING and no task was QUEUED. The queue was **EMPTY**, so bundle A is the single
in-flight task. Nothing further will be submitted while it is in flight.

## Step-1b fidelity re-check (run after the reviewer edits, immediately before submit)

The plank document is live, uncommitted and owned by agent `ul2inqpl`, so it could have moved while
the reviewers ran. Re-verified:

```
APPROVED-DOC-SHA256 : 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
LIVE plank doc      : 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
BUNDLED-DOC-SHA256  : 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58
STEP 1b HASH: PASS (all three identical)

$ diff <(awk '/\*\*M0\./{f=1} f&&/^### /{f=0} f' model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md) \
       <(awk '/\*\*M0\./{f=1} f&&/^### /{f=0} f' scratch/aristotle-mev/RequestProject/VOLATILITY_INSTRUMENTS.md)
STEP 1b M-BLOCK DIFF: PASS (empty, 181 lines each)
```

## T1–T19 fidelity checklist — the target for plan 11-03

Plan 11-03 must diff the returned module against this list. A returned theorem whose hypothesis list
is SHORTER, or whose conclusion is WEAKER, than specified here is a silent narrowing and must be
reported as such rather than accepted (PIT-4).

| # | Name | What it must say |
| --- | --- | --- |
| T1 | `ptrade_mem_Ioc` | `0 ≤ φ`, `0 < σ`, `0 < Δt` ⟹ `ptrade φ σ Δt ∈ Set.Ioc 0 1` |
| T2 | `ptrade_eq_one_iff` | same hyps: `ptrade φ σ Δt = 1 ↔ φ = 0` |
| T3 | `ptrade_strictAntiOn` | `StrictAntiOn (fun φ => ptrade φ σ Δt) (Set.Ici 0)` — THE fee-decreasing claim |
| T4 | `ptrade_monotoneOn_dt` **+ `ptrade_monotoneOn_sigma`** | monotone in `Δt` on `Ioi 0`; companion monotone in `σ` on `Ioi 0` (the 7th M1 property) |
| T5 | `ptrade_tendsto_atTop` | `Tendsto (fun φ => ptrade φ σ Δt) atTop (nhds 0)` |
| T6 | `ptrade_strictConvexOn` **+ `ptrade_convexOn`** | **STRICT** convexity on `Ici 0`, plus the named weakening. BOTH names must exist. `ConvexOn`-only is a silent narrowing |
| T7 | `arb_add_fee_eq_lvr` | ring identity; docstring must call it a **bridge identity**, NOT a formalization of Thm 3/4 |
| T8 | `mevWeight_cpmm_pos` **+ `mevMulti_nonneg`** | weight `σpath t ^ 2 / 8 * V t * Δt` (**the `Δt` MUST be present**), positive under `0 < σpath t`, `0 < V t`, `0 < Δt` and NOT the finiteness guard; plus nonnegativity of `mevMulti` |
| T9 | `mevMulti_anti_phibar` | **STRICT**, reversed vs `flairMulti_mono_phibar`; needs the `∃ t₀ < T, 0 < a t₀` witness |
| T10 | `mevMulti_anti_alpha` | reversed vs `flairMulti_mono_alpha` |
| T11 | `mevMulti_anti_u` | reversed vs `flairMulti_mono_u` |
| T12 | `mevMulti_mono_beta` | **ISOTONE** in β — reversed vs `flairMulti_anti_beta` |
| T13 | `mevMulti_ge_corner` | the M5 lower bound, **as a SUM** — not a scalar times a path weight (a product form would be FALSE) |
| T14 | `mevMulti_corner_attained_levels` | bang-bang at the level-corner TOP (M5(i)) |
| T15 | `mevMulti_saturation_limit` | `n = 1`, `Tendsto … atBot (nhds (T13 bound))` (M5(ii) limit half) |
| T16 | `mevMulti_strict_above_saturation` | strict gap at every finite β — the reversed mirror of `flairMulti_strict_below_saturation` (M5(ii) strict half) |
| T17 | `mevMulti_exists_min_compact` | `IsCompact.exists_isMinOn` **with the admissibility constraint** (`Θ` in the nonnegative-level region, `0 ≤ u`, `0 < Δt`, `0 < σpath t`). Unconstrained it is FALSE — `ptrade` has a pole at negative fees. A bare `ContinuousOn` hypothesis is NOT an acceptable substitute |
| T18 | `Theta_lambdaMEV_identification` **+ `mevMulti_min_gt_corner`** | the T16∧T15 conjunction (M4), plus M5(iii)'s "value strictly exceeds the displayed bound" half |
| T19 | `ARBoverV_exact` + `ARBoverV_exact_strictAntiOn` | **OPTIONAL, non-blocking.** Doc-symbol name; antitone under `σ^2 * Δt ≤ 2` and `φ ≤ 1`; the ONLY carrier of the `σ ^ 2 * Δt < 8` guard |

Also required of the returned module, and checkable mechanically:

- no `sorry`, no `admit`; `#print axioms` yields only `propext`, `Classical.choice`, `Quot.sound`
- **none of the 10 existing `.lean` files modified** (verify byte-identity on integration)
- NO affine identification of the form `λ = c0·A + c1·Σ A_j` — the kernel is not affine
- NO identifier named `η` (project-reserved for the pricing kernel)
- mandatory docstrings: the `λ_ARB`-is-a-summand-of-`λ_MEV` caveat on `mevHazard`/`mevMulti`/T18;
  the leading-order provenance; the no-demand-elasticity caveat citing eq. (27); the quasi-static
  caveat WITH M8's slow-parameter validity condition; T19's double-count warning

## Reviewer gate

`11-02-PROMPT-REVIEW.md` — Reality Checker + Model QA Specialist, run in parallel as independent
read-only processes. Both returned NEEDS WORK: **2 BLOCKER, 3 MAJOR, 6 MINOR**, every BLOCKER and
MAJOR resolved in the prompt before submission. The two BLOCKERs were a dropped `·Δt` in T8 (which
would have re-introduced a defect the 11-01 doc gate had already fixed) and a provably false T17.

## Post-submit status

Polling record appended below. Integration is plan 11-03's job; nothing is integrated here.
