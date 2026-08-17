# 11-03 — Aristotle bundle A: integration fidelity record

The statement-by-statement diff between what plan 11-02 **requested** (the T1–T19 checklist in
`11-02-RUN-RECORD.md`, itself derived from `scratch/aristotle-mev-PROMPT.txt` sha256 `c7ed66e9…`)
and what Aristotle **returned**. The point of this file is that a quietly weakened theorem cannot
pass as the claim the approved document makes: every returned statement is compared to its request,
and every hypothesis Aristotle added is named.

## Run identity

| Field | Value |
| --- | --- |
| project id | `cb371ee5-f27c-48d2-a396-725751fd7c36` |
| task id | `d1c57297-39b2-47ad-8048-492a407c6498` |
| terminal status | `COMPLETE` (polled with `aristotle tasks`, per 11-02's operational note) |
| archive | `scratch/aristotle-mev-result.tar.gz`, sha256 `33c68681d952f176d98b2860b7399b1ccb076fe893c39a1dc49e2233ea5694de` |
| returned module (as returned) | `RequestProject/MevOptimization.lean`, sha256 `5969272e83471dafe74d5bf04bc3ea20cdb76ba11a7cd805756ebc4620245fba` |
| integrated module (imports rewritten) | `lean/vol_markets/MevOptimization.lean`, sha256 `681117ed5cb02539ef7ad6cd961b43d5e5682179d726371542bfebad6412b588` |
| lines | 1046 |
| declarations | 3 `noncomputable def` + 22 public `theorem` + 3 `private` helpers = 28 |
| toolchain parity | returned `lean-toolchain` is byte-identical to `lean/lean-toolchain` (`leanprover/lean4:v4.28.0`) |

The ONLY edit made to the returned file was the mechanical import rewrite
`import RequestProject.` → `import vol_markets.` (2 lines, both verified by `diff`). Nothing else
in the proof text was touched — hand-editing a returned proof voids its verification.

## Byte-identity of the 10 bundled dependency modules

Checked **before** integrating anything. Each downloaded `RequestProject/<f>.lean` was diffed
against the submitted `scratch/aristotle-mev/RequestProject/<f>.lean`. **All ten diffs are empty
— the 10 modules came back byte-identical, so nothing previously proven was modified.**

| Module | `diff` exit | sha256 (first 16) |
| --- | --- | --- |
| PosSpec.lean | 0 | `ad171f59d42cc0ba` |
| Flow.lean | 0 | `13a1125f76ca3ebb` |
| RiskDesign.lean | 0 | `cc2caf9022acdecb` |
| Main.lean | 0 | `4c06ebb1aa7fc372` |
| Panoptic.lean | 0 | `79e24553aa48f3d4` |
| Upsilon.lean | 0 | `3c0cde5e15911c03` |
| GeomProfile.lean | 0 | `0af940510251a44f` |
| FeeSchedule.lean | 0 | `dad742786e78bd3f` |
| VolInstrument.lean | 0 | `639ce67fafa730cf` |
| FlairOptimization.lean | 0 | `db0ef67819614d91` |

Corroborated from the repository side: after integration,
`git status --porcelain lean/` listed exactly two entries (`lean/lakefile.toml` modified,
`lean/vol_markets/MevOptimization.lean` untracked) and
`git diff --stat lean/vol_markets/FlairOptimization.lean lean/vol_markets/VolInstrument.lean`
was **empty**. Aristotle's own run summary independently states "Only
`RequestProject/MevOptimization.lean` differs from the original project."

`EndogenousMaturity.lean` (repo commit `b03494d`, an independent parallel run) was **not** in
bundle A and is correctly absent from the returned archive; it is not part of this check.

## Build and sorry sweep

```
$ cd lean && lake build vol_markets     ->  Build completed successfully (8038 jobs)   exit 0
$ cd lean && lake build                 ->  Build completed successfully (8062 jobs)   exit 0
$ grep -nE '\b(sorry|admit)\b' lean/vol_markets/MevOptimization.lean
(no output — zero occurrences in code OR comment)
```

`vol_markets.MevOptimization` was appended to the `vol_markets` `lean_lib` roots in
`lean/lakefile.toml`. Without that entry the file compiles for nobody and the green build would be
vacuous; the build log line `⚠ [8037/8038] Built vol_markets.MevOptimization (57s)` is the evidence
the new module was actually elaborated rather than skipped.

Build warnings are linter-level only (`unused variable`, `unnecessarySeqFocus`) and are listed under
"Unused hypotheses" below, where they are informative rather than defects.

## Axiom sweep — all 25 enumerated declarations, no sampling

Generated `scratch/mev-axioms.lean` (one `#print axioms MevOptimization.<name>` per declaration
enumerated by the plan's regex) and ran `cd lean && lake env lean ../scratch/mev-axioms.lean`.
Full output, unedited:

```
'MevOptimization.ptrade' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevHazard' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_mem_Ioc' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_eq_one_iff' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_strictAntiOn' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_monotoneOn_dt' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_monotoneOn_sigma' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_tendsto_atTop' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_strictConvexOn' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.ptrade_convexOn' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.arb_add_fee_eq_lvr' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevWeight_cpmm_pos' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_nonneg' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_anti_phibar' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_anti_alpha' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_anti_u' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_mono_beta' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_ge_corner' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_corner_attained_levels' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_saturation_limit' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_strict_above_saturation' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_exists_min_compact' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.Theta_lambdaMEV_identification' depends on axioms: [propext, Classical.choice, Quot.sound]
'MevOptimization.mevMulti_min_gt_corner' depends on axioms: [propext, Classical.choice, Quot.sound]
```

**25/25 lines read exactly `[propext, Classical.choice, Quot.sound]`.** Nothing else appears: none of
the three unsound escape hatches — the axiom a `sorry` elaborates to, the kernel's
reduce-a-`Bool`-decision axiom, and the compiler-trust axiom — occurs anywhere in the output. (Those
three names are deliberately not spelled here: this record is itself grepped for them, and writing
them even in a negation would trip that check.)

Three `private` helpers (`sqrt_factor_pos`, `mevMulti_fee_nonneg`, `mevMulti_antitone_of_fee_le`)
are not separately printable from an importing file because private names are mangled. They are not
a gap: axiom dependence is transitive, and every public theorem that consumes them is clean above,
so any axiom they introduced would necessarily have surfaced in the printed lists.

## T1–T19 statement-fidelity diff

Dispositions used: **EXACT** (returned statement matches the request), **STRENGTHENED-HYPOTHESES**
(Aristotle added a hypothesis — expected behaviour, recorded not treated as a defect),
**NARROWED** (conclusion weaker than requested — none occurred), **OMITTED (optional)**,
**MISSING** (T1–T18 absent — none occurred).

| T# | requested name | returned name | present? | hypotheses added by Aristotle | narrowed? |
| --- | --- | --- | --- | --- | --- |
| T1 | `ptrade_mem_Ioc` | `ptrade_mem_Ioc` | YES | none | no — EXACT |
| T2 | `ptrade_eq_one_iff` | `ptrade_eq_one_iff` | YES | none | no — EXACT |
| T3 | `ptrade_strictAntiOn` | `ptrade_strictAntiOn` | YES | none | no — EXACT (`StrictAntiOn` on `Set.Ici 0`, the strict form) |
| T4 | `ptrade_monotoneOn_dt` | `ptrade_monotoneOn_dt` | YES | none | no — EXACT |
| T4 | `ptrade_monotoneOn_sigma` (companion) | `ptrade_monotoneOn_sigma` | YES | none | no — EXACT; the 7th M1 property is carried |
| T5 | `ptrade_tendsto_atTop` | `ptrade_tendsto_atTop` | YES | none | no — EXACT |
| T6 | `ptrade_strictConvexOn` | `ptrade_strictConvexOn` | YES | none | **no — STRICT form obtained.** `StrictConvexOn ℝ (Set.Ici 0) …` proved from the definition (the `X/Y + Y/X > 2` route), not the forbidden `ConvexOn` downgrade |
| T6 | `ptrade_convexOn` (named weakening) | `ptrade_convexOn` | YES | none | no — EXACT; derived via `.convexOn`. **Both names exist**, as required |
| T7 | `arb_add_fee_eq_lvr` | `arb_add_fee_eq_lvr` | YES | none (hypothesis-free ring identity) | no — EXACT; docstring says **"bridge identity"** and "NOT a formalization of those theorems" |
| T8 | `mevWeight_cpmm_pos` | `mevWeight_cpmm_pos` | YES | none | no — EXACT. **`Δt` IS present** (`0 < σpath t ^ 2 / 8 * V t * Δt`) and the `σ²·Δt < 8` finiteness guard is correctly NOT attached |
| T8 | `mevMulti_nonneg` (companion) | `mevMulti_nonneg` | YES | none | no — EXACT; all seven requested hypotheses present verbatim |
| T9 | `mevMulti_anti_phibar` | `mevMulti_anti_phibar` | YES | none | no — EXACT; **STRICT** `<`, with the `∃ t₀ < T, 0 < a t₀` witness |
| T10 | `mevMulti_anti_alpha` | `mevMulti_anti_alpha` | YES | none beyond the request's "plus the positivity hypotheses", spelled out as `0 ≤ φbar`, `∀ j < n, 0 ≤ α j`, `ha`, `hD`, `hσ`, `hΔt` | no — EXACT (weak `≤`, as requested; reversed vs `flairMulti_mono_alpha`) |
| T11 | `mevMulti_anti_u` | `mevMulti_anti_u` | YES | **`hu0 : 0 ≤ u`** — needed to invoke `VolInstrument.multiFee_bounds` and keep the fee off `ptrade`'s pole | no — STRENGTHENED-HYPOTHESES |
| T12 | `mevMulti_mono_beta` | `mevMulti_mono_beta` | YES | none | no — EXACT; **ISOTONE** in β (reversed vs `flairMulti_anti_beta`) |
| T13 | `mevMulti_ge_corner` | `mevMulti_ge_corner` | YES | none | no — EXACT. **The RHS is a `∑ t ∈ Finset.range T, ptrade (φbarMax + uMax * ∑ j, αmax j) (σpath t) Δt * a t / D t` — a genuine path SUM, not a scalar × path weight.** The product form (which would be false, `ptrade` not being affine) was not used |
| T14 | `mevMulti_corner_attained_levels` | `mevMulti_corner_attained_levels` | YES | **`hαmax0 : ∀ j < n, 0 ≤ αmax j`** — logically redundant (it follows from `0 ≤ α j ≤ αmax j`), so it restricts nothing | no — STRENGTHENED-HYPOTHESES (redundant-but-harmless) |
| T15 | `mevMulti_saturation_limit` | `mevMulti_saturation_limit` | YES | **`hfee : 0 ≤ φbarMax + uMax * αmax0`**, plus `hσ`, `hΔt`. Aristotle flags this in its own run summary as *"mathematically necessary … without it the limiting fee can lie at the negative-fee pole of `ptrade`, so the originally requested unrestricted limit is false"*, and repeats it in the theorem docstring | no — STRENGTHENED-HYPOTHESES, **and it is the same pole that made T17 false as originally drafted.** The prompt's T15 was unguarded; this is a genuine correction, disclosed |
| T16 | `mevMulti_strict_above_saturation` | `mevMulti_strict_above_saturation` | YES | exactly the set the prompt itself anticipated: `0 < uMax`, `0 < αmax0`, `0 ≤ φbarMax`, `∃ t₀ < T, 0 < a t₀`, standing positivity | no — EXACT to the requested hypothesis shape; **strict `<` at every finite `β0`**, and the docstring states the reversed-mirror relation to `flairMulti_strict_below_saturation` |
| T17 | `mevMulti_exists_min_compact` | `mevMulti_exists_min_compact` | YES | none beyond the admissibility constraint the prompt itself specified (`hadm : ∀ θ ∈ Θ, 0 ≤ θ.1 ∧ 0 ≤ θ.2.1`, `0 ≤ u`, `0 < Δt`, `∀ t < T, 0 < σpath t`) | no — EXACT. **`IsCompact.exists_isMinOn` is used (line 859) and `ContinuousOn` is PROVED, not assumed** — the forbidden degenerate repair (a bare `ContinuousOn` hypothesis) does not appear anywhere in the file |
| T18 | `Theta_lambdaMEV_identification` | `Theta_lambdaMEV_identification` | YES | none | no — EXACT; literally the conjunction `(∀ β0, bound < mevMulti …) ∧ Tendsto … atBot (nhds bound)`, i.e. T16 ∧ T15, and the docstring carries the mandatory `λ_ARB`-is-a-summand caveat |
| T18 | `mevMulti_min_gt_corner` (M5(iii) second half) | `mevMulti_min_gt_corner` | YES | **`hupper : ∀ θ ∈ Θ, θ.1 ≤ φbarMax ∧ θ.2.1 ≤ αmax0`** (the box's upper corner, required to chain T14) plus `0 < uMax`, `0 < αmax0`, `0 ≤ φbarMax`. The `u` coordinate is instantiated at `uMax` rather than left free | no — STRENGTHENED-HYPOTHESES. See the scope note below |
| T19 | `ARBoverV_exact` + `ARBoverV_exact_strictAntiOn` | — | NO | — | **OMITTED (optional)** — explicitly permitted and non-blocking; Aristotle records "No optional T19, as permitted by the specification" |

**No T1–T18 item is MISSING and no returned conclusion is NARROWED.**

### Scope note on `mevMulti_min_gt_corner`'s fixed `u = uMax`

The corollary proves the strict gap for the objective evaluated at `u := uMax` rather than for an
arbitrary `u ≤ uMax`. This is the *sharp* instance rather than a weakening: raising `u` raises the
multi-sigmoid fee, which lowers `ptrade` and therefore lowers the hazard, so `u = uMax` is the
smallest hazard on the box and hence the hardest case in which to beat the displayed bound. That
reasoning is an **executor argument, not a machine-checked claim** — the Lean statement covers
`u = uMax` and no other `u`, and this record does not assert more than that.

### Unused hypotheses (informative, not defects)

`lake build` reports four `unused variable` warnings inside the module: `hΔt` in `ptrade_mem_Ioc`
(T1), `hΔt` in `ptrade_monotoneOn_sigma` (T4 companion), `hσ` in `ptrade_tendsto_atTop` (T5), and
`hΔt` in `mevMulti_saturation_limit` (T15). In each case Aristotle kept the *requested* hypothesis
in the signature even though its proof did not need it. That direction is safe — the returned
theorem is at least as strong as the requested one — and it is recorded here rather than optimized
away, because deleting a hypothesis from a returned proof is itself a re-verification event.

### Other mechanically-checkable requirements from the run record

| Requirement | Result |
| --- | --- |
| no `sorry`, no `admit` | PASS — zero occurrences, code or comment |
| `#print axioms` = {propext, Classical.choice, Quot.sound} | PASS — 25/25 |
| none of the 10 existing `.lean` files modified | PASS — 10/10 byte-identical |
| NO affine identification `λ = c0·A + c1·Σ A_j` | PASS — no such theorem exists; the single occurrence of the word "affine" is T13's docstring contrast *"Unlike the affine FLAIR bound, the right-hand side remains a path sum"* |
| NO identifier named `η` | PASS — zero `η` characters in the file |
| docstring: `λ_ARB`-is-a-summand-of-`λ_MEV` caveat on `mevHazard` / `mevMulti` / T18 | PASS — the verbatim "SUMMAND of `λ_MEV` … only under block M7's uniform-clearing reduction" sentence appears 3 times, once on each |
| docstring: leading-order provenance | PASS — module docstring plus `mevHazard`/`mevMulti` cite eq. (12) as the SPLIT, and the MAMR `(σ²/8)·V(P)` rate as LVR itself |
| docstring: no-demand-elasticity caveat citing eq. (27) | PASS — module docstring, `E[delta-hedged LP P&L] = E[NT_FEE] - E[ARB]` quoted with the section 7.3 / eq. (27) attribution |
| docstring: quasi-static caveat WITH M8's slow-parameter validity condition | PASS — module docstring, "legitimate only if the parameters move slowly relative to mixing of the mispricing process" |
| docstring: T19's double-count warning | N/A — T19 omitted |
| the new module reuses `VolInstrument.multiFee` (same parameter space as FLAIR) | PASS — `VolInstrument.multiFee` referenced throughout; `VolInstrument.multiFee_bounds` consumed 10 times |

## Verdict

**CTX-PTRADE — SATISFIED.** `ptrade φ σ Δt = σ / (σ + φ·√(2/Δt))` is defined and all seven of block
M1's asserted properties are machine-checked: range in `(0,1]` (T1), the `=1 ↔ φ=0` characterization
(T2), **strict** antitonicity in the fee (T3), monotonicity in `Δt` (T4) and in `σ` (T4 companion),
the `φ → ∞` limit (T5), and **strict** convexity (T6) together with its named non-strict weakening.
The strict forms at T3 and T6 are the ones the document asserts, and both came back strict.

**CTX-MEVHAZ — SATISFIED.** `mevHazard` and `mevMulti` are defined over the *same* `multiFee`
parameter space and the *same* deployed-capital denominator `D t` as `FlairOptimization.flairHazard`,
so the two hazards are commensurable by construction rather than by assertion. The CPMM weight
carries its `Δt` (T8) — the factor whose loss was 11-02's first BLOCKER — and the full antitone
identification block is proved with the FLAIR mirror's directions reversed: strict in `φ̄` (T9),
weak in `α` (T10) and `u` (T11), and isotone in `β` (T12). The mandatory naming caveat that this
object is `λ_ARB`, a *summand* of `λ_MEV`, is carried in all three required docstrings.

**CTX-INF — SATISFIED.** The infimum program is solved as specified: the path-sum lower bound at the
fee ceiling (T13, correctly a sum and not a product), bang-bang attainment at the level-corner top
(T14), the `β0 → -∞` saturation limit (T15), the strict gap at every finite `β0` (T16), existence of
a minimizer on an admissible compact box via `IsCompact.exists_isMinOn` with continuity proved
rather than assumed (T17), and the packaged identification `Theta_lambdaMEV_identification` (T18)
together with M5(iii)'s "strictly exceeds the displayed bound" half as `mevMulti_min_gt_corner`.
The controlling block is `{φ̄, α, u}` at its upper corner and the shape block cannot attain the
infimum — the exact reversal of the solved FLAIR supremum.

**Two qualifications, neither of which unmakes the above.** First, T15 required a hypothesis the
prompt did not specify (`0 ≤ φbarMax + uMax·αmax0`); the unguarded limit as requested is **false**,
for the same negative-fee pole that made the pre-review T17 false. The requirement is therefore
satisfied by a *corrected* statement, and the correction is Aristotle's, disclosed in its own run
summary. Second, T19 (`ARBoverV_exact`) was omitted; it was designated optional and non-blocking at
submission, it is the only carrier of the `σ²·Δt < 8` finiteness guard, and the exact CPMM kernel of
block M3(ii) consequently has **no formal carrier in this repository**. Nothing in CTX-PTRADE,
CTX-MEVHAZ or CTX-INF depends on it — the leading-order kernel carries the whole program — but the
gap is real and is recorded here rather than absorbed.
