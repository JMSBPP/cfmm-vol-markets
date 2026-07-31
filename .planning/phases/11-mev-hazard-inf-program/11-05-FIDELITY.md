# 11-05 — Aristotle bundle B: statement-fidelity record

Integration record for the returned joint sup-FLAIR / inf-MEV program. Format reproduces
`11-03-FIDELITY.md`.

| Field | Value |
| --- | --- |
| Project id | `19f777ab-e4ca-47ca-86a1-bf64af79fa90` (`aristotle-mev-joint`) |
| Task id | `f8840dab-5723-4a09-9632-1391561180c5` |
| Status at download | `COMPLETE` |
| Download timestamp (UTC) | `2026-07-31T11:50Z` |
| Returned module | `RequestProject/MevJointProgram.lean` — the requested name, no rename needed |
| Integrated as | `lean/vol_markets/MevJointProgram.lean` |
| Size | 481 lines; **22 theorems + 5 defs = 27 declarations** |
| Archive sha256 | `db37c8f705d622f718e2e344f6d7c46c68ce3a1a6f43985c30edbc1791d853ad` |
| Returned module sha256 | `9dd34d9e7161beafa9136ab0ff2cedd688d1e0a92450b26c9f6c5dcc3fe123f7` |
| Integrated module sha256 | `ee458320b28e58b2857e9ff79874cef354a0c0d9434096b9c76484886ce87a68` |
| Prompt sha256 (verified) | `f471801914b304aa4c2cc44f4412ef7d1a7104d7fe6b6f6ac8c7a8454c819a12` |

The prompt hash re-verified at integration time **equals the pin recorded in `11-04-RUN-RECORD.md`**.
The statement diffs below are therefore against the bytes that were actually sent, not against a
reconstruction.

## The only edit made to the returned proof

```
2,3c2,3
< import RequestProject.MevOptimization          > import vol_markets.MevOptimization
< import RequestProject.FlairOptimization        > import vol_markets.FlairOptimization
```

Two import lines. Nothing else — hand-editing a returned proof voids the verification it carries.

## Byte-identity of the eleven submitted dependencies

Checked **before** anything was integrated. All eleven modules came back **byte-identical**:

```
IDENTICAL: PosSpec.lean            IDENTICAL: Flow.lean          IDENTICAL: RiskDesign.lean
IDENTICAL: Main.lean               IDENTICAL: Panoptic.lean      IDENTICAL: Upsilon.lean
IDENTICAL: GeomProfile.lean        IDENTICAL: FeeSchedule.lean   IDENTICAL: VolInstrument.lean
IDENTICAL: FlairOptimization.lean  IDENTICAL: MevOptimization.lean
BYTE-IDENTITY RESULT: PASS  (11 modules, 11 empty diffs)
```

The bundled `VOLATILITY_INSTRUMENTS.md` also returned byte-identical, so the prover's document copy
was never mutated mid-run.

Corroborated from the repository side: `git status --porcelain lean/` listed exactly two entries
(`lakefile.toml` modified, `MevJointProgram.lean` untracked), and
`git diff --stat lean/vol_markets/{MevOptimization,FlairOptimization,VolInstrument}.lean` is EMPTY.
`MevOptimization.lean` — itself a proven artifact since 11-03 — was not touched.

## Build

```
$ cd lean && lake build vol_markets
⚠ [8038/8039] Built vol_markets.MevJointProgram (27s)
Build completed successfully (8039 jobs).            exit 0

$ cd lean && lake build
Build completed successfully (8063 jobs).            exit 0
```

`Built vol_markets.MevJointProgram (27s)` is the evidence the module was actually **elaborated** and
not skipped by an unregistered root, which would have made the green build vacuous. The root was
APPENDED to the `vol_markets` roots list in `lean/lakefile.toml`; nothing was removed (the list
already ended with `vol_markets.EndogenousMaturity`, `vol_markets.MevOptimization` from an
independent parallel run and from 11-03).

## Axiom sweep — all 27 declarations, none omitted

The sweep file was **generated from a grep of the module**, so it cannot silently skip a
declaration. Every `#print axioms` resolved (no unknown-identifier errors), and the run exited 0.

```
'MevJointProgram.joint_corner_degeneracy' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.joint_beta_degeneracy' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.joint_scalarization_degeneracy' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.flairPath' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevPath' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.flairPath_schedule' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevPath_schedule' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.flair_budget_pins_mean_fee' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.flair_budget_mean' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.flairPath_sum' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.flairPath_budget_mean' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mev_ge_flat_under_flair_budget_false' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mev_ge_flat_under_flair_budget_const_sigma' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mev_gt_flat_under_flair_budget_const_sigma' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevNet' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevNet_le_mev' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevNet_anti_tau' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevNet_eq_zero_of_tau_one' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevNet_argmin_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.taxFraction' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.taxFraction_mem_Ico' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.taxFraction_mono' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mev_mono_dt' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevTotal' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevTotal_eq_arb_of_sandwich_zero' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevTotal_mevMulti_eq_of_sandwich_zero' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevJointProgram.mevTotal_probOr_hazard' depends on axioms: [propext, Classical.choice, Quot.sound]
```

**27/27 = `[propext, Classical.choice, Quot.sound]`.** No declaration depends on any additional
axiom; in particular none of the three axiom names this record's own acceptance criterion greps for
(the incomplete-proof axiom and the two compiler-trust axioms) appears anywhere in the output. That
is stated by description rather than by writing the names, because the acceptance criterion for this
file forbids their literal appearance — the same self-contradiction class 11-02 hit at `ptradeCPMM`,
11-03 at its axiom-name grep and 11-04 at its phantom `lean`, resolved the same way.

The refutation route is axiom-clean specifically because it avoids the compiled-evaluation tactic
the prompt forbade: it closes by `norm_num` on explicit numerals.

## Other mechanical sweeps

| Sweep | Result |
| --- | --- |
| `sorry` / `admit` in code | **none** |
| compiled-evaluation tactic in the refutation | **none** (prompt forbade it as not axiom-clean) |
| identifier `η` | **none** (reserved project-wide for `VolInstrument.priceEta`) |
| affine identification of `mevMulti` | **none** |
| numeric Angstrom constant in a statement | **none** — see below |
| unintended files changed under `lean/` | **0** |

### The tax-constant sweep, and a correction to the plan's own criterion

`grep -nE '\b49\b|\b0\.98\b'` returns exactly one hit, line 401:

```
401:`k = 49`, `τ = 0.98`, but live documentation differs on surrounding constants, so claims remain
```

The plan's acceptance criterion additionally requires every such line to match
`^\s*(--|/-|\*|-)`. **Line 401 does not match it, and the criterion is wrong, not the file.** Line
401 is a *continuation* line of the block docstring opened at line 400 (`/-- Parametric auction-tax
ceiling …`) and closed at 405; Lean block docstrings carry no per-line marker, so the criterion's
regex cannot recognise them and would reject any multi-line docstring.

The semantic requirement was therefore verified properly, with a comment-aware scanner that tracks
`/- … -/` nesting and `--` line comments character by character:

```
line 401: match '49'   -> COMMENT/DOCSTRING
line 401: match '0.98' -> COMMENT/DOCSTRING
VERDICT: PASS - no numeric tax constant in any statement
```

`taxFraction` is `k / (k + 1)` with `k` FREE, and its lemmas quantify over `k`. The dated snapshot
values live only in prose, exactly as T28 required.

## T20–T30 fidelity table

Statement comparison is mechanical: each returned signature was whitespace-normalized and compared
against the corresponding fenced `lean` block in the sha-verified prompt.

| T# | requested name | returned name | present? | hypotheses added | narrowed? |
| --- | --- | --- | --- | --- | --- |
| T20 | `joint_corner_degeneracy` | `joint_corner_degeneracy` | YES | **none** — statement byte-identical to spec, `hφ0 : 0 ≤ φbar` PRESENT | NO |
| T21 | `joint_beta_degeneracy` | `joint_beta_degeneracy` | YES | **none** — byte-identical; `hγ : ∀ j < n, 0 < γ j` present; delivered as the monotonicity PAIR, not two `Tendsto` limits | NO |
| T22 | `joint_scalarization_degeneracy` | `joint_scalarization_degeneracy` | YES | **none** — byte-identical; `hκ : 0 ≤ κ`; own docstring carries the volume-inelasticity qualifier | NO |
| — | `flairPath`, `mevPath` | same | YES | n/a (defs) — byte-identical | NO |
| — | `flairPath_schedule`, `mevPath_schedule` | same | YES | **none** — byte-identical; both close by `rfl` as requested | NO |
| T23 | `flair_budget_pins_mean_fee` | `flair_budget_pins_mean_fee` | YES | **none** — byte-identical | NO |
| T23 | mean characterization (unnamed in prompt) | `flair_budget_mean` | YES | none; `hW` present but **UNUSED** (see below) | NO — stronger |
| — | path-level counterparts (optional) | `flairPath_sum`, `flairPath_budget_mean` | YES (extra) | `hW` present but UNUSED | NO — bonus |
| **T24** | `mev_ge_flat_under_flair_budget` | **`mev_ge_flat_under_flair_budget_false`** | **REFUTED — outcome 3** | n/a | **NO — see `## T24 verdict`** |
| T25 | `mev_ge_flat_under_flair_budget_const_sigma` | same | YES | **none** — byte-identical to spec, stated at the PATH level | NO |
| T25 | strictness companion (name free) | `mev_gt_flat_under_flair_budget_const_sigma` | YES | `hw : ∀ t < T, 0 < w t` (strict positivity, one of the two routes the prompt sanctioned) and `hnconst : ∃ t₁ < T, ∃ t₂ < T, φpath t₁ ≠ φpath t₂` — **both pre-authorized and disclosed in the docstring** | NO — consumes `ptrade_strictConvexOn`, the STRICT form, not the non-strict fallback |
| T26 | `mevNet` | `mevNet` | YES | n/a (def) — signature byte-identical | NO |
| T26 | `mevNet_le_mev`, `mevNet_anti_tau`, `mevNet_eq_zero_of_tau_one` | same | YES | none beyond spec; `hτ1` present but UNUSED. Nonnegativity **discharged via `MevOptimization.mevMulti_nonneg`, not assumed** | NO |
| T27 | `mevNet_argmin_invariant` | `mevNet_argmin_invariant` | YES | **none** — byte-identical; `hτ : τ < 1` strict; `IsMinOn` ↔ form; `(φbar, α, β, γ)` packing matches `mevMulti_exists_min_compact` | NO |
| T28 | `taxFraction`, `taxFraction_mem_Ico`, `taxFraction_mono` | same | YES | **none** — byte-identical; `k` FREE; LP-share upper-bound consequence stated in the docstring | NO (no `StrictMonoOn` strengthening — it was optional) |
| T29 | `mev_mono_dt` | `mev_mono_dt` | YES | **none** — byte-identical; ISOTONE; no vacuous second half; partial-effect, two-`Δt` and sub-second caveats all in the docstring | NO |
| T30 | `mevTotal`, `mevTotal_eq_arb_of_sandwich_zero`, `mevTotal_mevMulti_eq_of_sandwich_zero`, `mevTotal_probOr_hazard` | same | YES | **none** — all four byte-identical. **`mevTotal := lamARB + lamSand`, PLAIN ADDITION**; the `probOr` correspondence lives in its own lemma via `probOr_hazard`; intra-batch bound stated | NO |

**Every T-number is accounted for. Not one returned conclusion is narrowed, and not one specified
statement was renamed.** The eleven items the run record told this plan to watch all held.

### Aristotle-added hypotheses

Only on the strict T25 companion (`hw : 0 < w t`, `hnconst`), and both were explicitly pre-authorized
by the prompt, which named `∀ t < T, 0 < w t` as the expected route because Mathlib's
`StrictConvexOn.map_sum_lt` requires `0 < w i` on the whole index set. Aristotle chose strict
positivity over index-set restriction and **said which it did** in the docstring, as instructed.

This contrasts with bundle A, where T15 needed a genuinely new `hfee` guard. Bundle B required no
corrective hypothesis anywhere.

### Hypotheses present but UNUSED (theorems are stronger than specified)

The elaborator's linter reports three unused binders:

| Declaration | Unused | Consequence |
| --- | --- | --- |
| `flair_budget_mean` | `hW : 0 < pathWeight w D T` | holds without it (`x/0 = 0` in Lean makes the degenerate case true) |
| `flairPath_budget_mean` | `hW` | same |
| `mevNet_le_mev` | `hτ1 : τ ≤ 1` | `0 ≤ τ` alone suffices, given `mevMulti_nonneg` |

These are **strengthenings, not narrowings** — the hypotheses were kept because the prompt's
HYPOTHESIS PRE-EMPT asked for them, and keeping them preserves signature symmetry with the rest of
the group. Recorded rather than removed: editing a returned proof to silence a linter would void its
verification.

## T24 verdict

**REFUTED (counterexample)**

T24 did not come back OPEN and it did not come back proved. Aristotle delivered **outcome 3** — a
machine-checked negation theorem, under exactly the name and shape the prompt mandated:

```lean
theorem mev_ge_flat_under_flair_budget_false :
    ¬ (∀ (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (Δt B : ℝ) (T : ℕ),
      0 < Δt → (∀ t < T, 0 < σpath t) → (∀ t < T, 0 ≤ w t) → (∀ t < T, 0 < D t) →
      0 < FlairOptimization.pathWeight w D T →
      (∀ t < T, 0 ≤ φfun (σpath t)) →
      FlairOptimization.flairHazard φfun σpath w D T = B →
      ∑ t ∈ Finset.range T,
          MevOptimization.ptrade (B / FlairOptimization.pathWeight w D T) (σpath t) Δt
            * (w t / D t) ≤
        MevOptimization.mevHazard φfun σpath w D Δt T)
```

Whitespace-normalized, this is **character-for-character the block the prompt specified** for
outcome 3. Nothing was renamed and nothing was weakened.

### The counterexample, and an independent recomputation

The witness is `T = 2`, `Δt = 2`, `B = 2`, with

| | step `t = 0` | step `t = 1` |
| --- | --- | --- |
| `σpath t` | `1` | `10` |
| `w t`, `D t` | `1`, `1` | `1`, `1` |
| `φfun (σpath t)` | `2` | `0` |

so `pathWeight = 2`, the budget `flairHazard = 2·1 + 0·1 = 2 = B` is satisfied, and the flat fee is
`B/W = 1`. With `Δt = 2`, `√(2/Δt) = 1` and `ptrade φ σ 2 = σ/(σ + φ)`.

**Recomputed independently of Lean, in exact rational arithmetic:**

```
flat-path ARB : ptrade(1,1) + ptrade(1,10) = 1/2 + 10/11 = 31/22 = 1.409090...
tilted-path ARB: ptrade(2,1) + ptrade(0,10) = 1/3 + 1     = 4/3   = 1.333333...
claimed  flat <= tilted ?  FALSE   (1.409090 > 1.333333)
```

The flat fee path is **strictly worse** for the arbitrage hazard than the volatility-responsive one.
The claim is not merely unproved: it is false.

Which hypothesis of the constant-σ argument fails at the witness — the module docstring names it —
is that volatility VARIES (`1` versus `10`), so the summands `x ↦ ptrade x (σpath t) Δt` are
DIFFERENT convex functions at different `t` and ordinary Jensen never applies. This is exactly the
non-sign-definite covariance term the prompt anticipated at lines 426–437; the tilt toward the step
where trade probability is steeper drives it negative.

### What this refutes, and what it does not — scope, stated precisely

**Refuted, machine-checked:** the schedule-level claim as stated in T24, quantified over arbitrary
`φfun : ℝ → ℝ` subject only to `0 ≤ φfun (σpath t)`. That is the statement the approved document's
block M6b left labelled OPEN. **It is now FALSE, not open**, and block M6b must be corrected to say
so — carried into 11-06 as a required doc amendment and a `REFUTED` traceability row.

**NOT settled by this theorem:** the witness fee schedule `φfun x = if x = 1 then 2 else 0` is
DECREASING in σ, whereas every schedule reachable inside `Θ_φ` is isotone in σ —
`VolInstrument.multiFee_monotone` proves `Monotone (multiFee n γ β α φbar u)` under `0 < γ j`,
`0 ≤ α j`, `0 ≤ u`. So the machine-checked refutation, on its own, does **not** establish that the
claim fails on the Θ_φ-reachable sub-family.

**Executor numeric observation — NOT machine-checked, and flagged as such.** A grid scan indicates
the violation is not an artifact of the decreasing direction: it persists for isotone fee paths, and
for a genuine `multiFee` schedule. With `multiFee(σ) = 2 + 2·logistic(8·(σ − 1.5))`, `σ = (0.5, 2.5)`,
unit denominators and weights `(2, 2)`:

```
fees  phi(0.5)=2.000671  phi(2.5)=3.999329   (isotone, as Theta_phi forces)
B = 12.0,  W = 4.0,  flat fee B/W = 3.0
flat-path ARB  1.194805      schedule ARB  1.169203      flat - schedule = +0.025602  -> flat is WORSE
```

This is floating-point exploration by the executor, **not a theorem and not evidence of the same
standing as the refutation above**. It is recorded because it bears directly on how far M6b's
correction must go, and it is the natural follow-up formalization: a second refutation carrying an
explicit `multiFee` witness would close the Θ_φ-restricted case too. Until such a theorem exists,
the Θ_φ-restricted claim is **OPEN**, and this record does not assert it is false.

### Anti-relabelling check

- T25 was **not** renamed to T24. It exists under its own name with `const_sigma` in it, at the path
  level, and its docstring says in terms that the varying-σ schedule claim is settled by T24.
- No hypothesis forcing the fee path constant was smuggled into anything called T24 — the
  binding EXCLUSION in the prompt's outcome 2 was not exercised at all, because the delivered
  outcome is 3, not 2.
- T25 is **not** described anywhere in this record as satisfying T24 or as covering CTX-JOINT's
  general case.

## Requirement disposition

**CTX-JOINT — SATISFIED, with the headline inverted from what the phase expected.**

The unconstrained joint program is formally DEGENERATE: T20 exhibits one admissible point that
simultaneously maximizes `flairMulti` and minimizes `mevMulti`; T21 gives the same coincidence in the
shape coordinate, so a single common direction `β → −∞` improves both; T22 shows no linear
scalarization `κ ≥ 0` repairs it. **The shape block `(β, γ) `is not essential over `Θ_φ`** — the
phase brief's expectation is refuted, and is now machine-checked as such.

The constrained program is where the trade-off was supposed to live, and here the result is a
NEGATIVE one. T23 supplies the linearity half (a FLAIR budget pins the mean fee `B/W` and leaves the
path shape free). The general varying-σ conclusion, T24, is **FALSE** — that is CTX-JOINT's general
case, and it is settled in the negative rather than delivered. What survives is T25: at CONSTANT
volatility, over fee PATHS, the flat path minimizes the arbitrage hazard, strictly so for any
non-constant path when every weight is positive. That is a genuine result on a strictly smaller
domain, and it is reported as such and not as the general case.

**CTX-ANGSTROM — SATISFIED.** T26 defines the LP-net rebate and proves it lowers LP incidence
(nonnegativity discharged on `mevMulti_nonneg`, never assumed), is antitone in `τ`, and vanishes at
`τ = 1`. T27 is the substantive one: for every `τ < 1` the rebate changes the program's VALUE and not
its SOLUTION, so `τ` is formally a protocol parameter outside `Θ_φ`. T28 keeps the auction tax
parametric — `k/(k+1)` with `k` free, no numeral in any statement, LP incidence disclosed as
`LPshare · k/(k+1)` with `taxFraction k` an upper bound. T29 proves the cadence lever is ISOTONE in
`Δt`. T30 defines `mevTotal` as **plain hazard addition** and carries the `probOr` correspondence as
its own lemma — the BLOCKER the 11-04 two-reviewer gate caught was correctly implemented.

## Honest limitations

- **The refutation is a refutation.** The phase's most-anticipated positive result does not exist,
  because it is false. Nothing downstream may cite a general varying-σ flat-fee optimality claim.
- **The Θ_φ-restricted varying-σ case remains OPEN**, as argued above. The numeric evidence pointing
  the same way is executor exploration, not machine-checked, and is labelled so wherever it appears.
- **T24's refutation and T25 both instantiate the arbitrage measure at the traded-flow weight
  (`a = w`).** That aligned-measure assumption is strong — it forces noise-trader flow to be
  proportional block-by-block to leading-order LVR — and the module docstring says so, adding that
  without it the constrained conclusion can reverse. In T20–T22 `w` and `a` remain two free
  functions, so the assumption stays visible exactly where it is used.
- **Everything here is downstream of the leading-order `ARB ≈ LVR · P_trade` factorization**, carries
  no demand response to the fee, and applies a steady-state `P_trade` quasi-statically along a
  varying-σ path. The degeneracy of T20–T22 in particular is a property of volume-INELASTIC
  objectives, which is why that qualifier sits in T22's own docstring and not only the module's.
- **`λ_MEV` here is two channels, not all MEV.** Backruns, multi-block MEV (which attacks the T29
  cadence lever directly by lengthening effective `Δt`), JIT liquidity and fixed gas costs are all
  outside the aggregate — caveat (vi), present as mandated.
- **Verified proofs are not verified modelling.** Every statement above is a theorem about the
  formalized objectives, not about a market.
