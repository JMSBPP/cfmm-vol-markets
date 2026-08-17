# 11-02 — Two-reviewer gate on the Aristotle PROMPT

**Artifact under review:** `scratch/aristotle-mev-PROMPT.txt` — the numbered T1–T19 specification
that Aristotle formalizes into `RequestProject/MevOptimization.lean`.

Per 11-RESEARCH PIT-7, the gate is run on the PROMPT and not on the plan: the prompt, not the plan,
is the specification the prover consumes, and the submission is one-shot with no revision after
send.

| Item | Value |
| --- | --- |
| Prompt sha256 AS REVIEWED (pre-fix) | `4adc0d3ef3e87fcbec07c3c18dfaf21453b7da20aeff421432b1c3e2ff17335a` |
| Prompt sha256 AFTER resolutions | `c7ed66e923fadd8880f011bad44d5616f3f4b3c687bf2c5ac78a6a54a5671d54` |
| Bundled doc sha256 | `671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58` (= `APPROVED-DOC-SHA256`) |
| Reviewer verdicts | Reality Checker **NEEDS WORK**; Model QA Specialist **NEEDS WORK** |
| Findings | 2 BLOCKER, 3 MAJOR, 6 MINOR |

## How the gate was run

Both reviewers were launched **in parallel from a single shell invocation** as independent headless
processes, each with **read-only tools only** (`Read Grep Glob Bash`, no write tool), then joined
with `wait`. Neither reviewer could edit the artifact even in principle. Each was handed the prompt,
`lean/vol_markets/FlairOptimization.lean` (the mirror template), the bundled
`RequestProject/VOLATILITY_INSTRUMENTS.md` (the approved document, which is the specification of
record), the approved addendum, `11-01-REVIEW.md` (with an explicit instruction NOT to re-litigate
what was adjudicated there), and `11-RESEARCH.md`.

This reproduces the mechanism used at the 11-01 doc gate (deviation recorded there): this executor
has no subagent `Task` tool, so parallel read-only processes are the substitute. They satisfy the
binding requirements more strictly than a subagent call would — genuine parallelism, genuine
independence, and *tool-level* inability to modify the artifact.

## Specialist pick and reason

**Reviewer 2 is the Model QA Specialist** (`agents/specialized/specialized-model-qa.md`).

It was **chosen because** the plan directs the second reviewer to be the closest available
AI-agency specialist to **quantitative finance / market microstructure** — per PIT-7 the risk in
this artifact is economic misstatement of ARB/LVR, not Lean syntax. The catalog contains no
dedicated quant-finance or microstructure agent; the Model QA Specialist is the closest, its remit
being independent adversarial audit of statistical and mathematical *models* (documentation-vs-
methodology consistency, replication of stated results, challenge of load-bearing assumptions) under
a "guilty until proven sound" posture, with explicit finance-domain audit experience. This is the
same pick, for the same reason, as the 11-01 doc gate — deliberately, so the two gates in this phase
are comparable. Candidates rejected: `blockchain-security-auditor` (contract exploit surface; no
Solidity in this artifact) and the engineering/testing agents (Lean syntax is not the risk).

## Reviewer 1 — Reality Checker

Verified on disk before reporting: bundle inventory (10 `.lean` + 1 `.md`, plus `lakefile.toml`,
`lean-toolchain`, `lake-manifest.json`); the doc-fidelity `diff` (empty); `sha256sum` against
`APPROVED-DOC-SHA256` (match); zero `import vol_markets` hits; and **every Mathlib citation in the
prompt, including its three non-existence claims**, grepped against the local pinned checkout.

- **BLOCKER B1 — T17 is FALSE as written.** Arbitrary `IsCompact Θ` does not yield a minimizer:
  `ptrade` has a pole at negative fees, so `ContinuousOn` fails and `IsCompact.exists_isMinOn` does
  not apply. Counterexample constructed: `T=1, σ=1, Δt=2, a₀=D₀=1, u=0, Θ=[−2,0]×{0}×{0}×{0}` gives
  objective `1/(1+φbar) → −∞` as `φbar ↓ −1`. FLAIR never needed the constraint because `flairMulti`
  is affine, hence continuous on all of `ℝ⁴` — a second place the mirror breaks, beyond the one
  RESEARCH F4 tabulates.
- **MAJOR M1 — M5(iii)'s "strictly exceeds the displayed bound" half has no carrier.** T17 delivered
  existence only. This clause was specifically mandated by 11-01 finding R1-M7.
- **MAJOR M2 — M1's "increasing in σ" property has no T-statement.** Six of the document's seven
  `P_trade` properties were formalized; the seventh was silently dropped. Traced to the pre-gate
  research draft signature list, which the prompt had corrected elsewhere but not here.
- **MINOR m1** — M4's "convex in the fee" is carried only at the `ptrade` level (T6); no lifted
  `mevMulti`-convexity-in-`φbar`.
- **MINOR m2** — T19's antitonicity is prompt-added rather than doc-stated; reviewer verified it is
  TRUE by hand (`σ ≤ c(2−φ)`, implied by `σ²Δt ≤ 2` and `φ ≤ 1`).
- **MINOR m3** — T14/T15 hypothesis lists lean on the pre-empt block rather than being
  self-contained.

Verified clean: all T9–T12 and T14–T16 inequality reversals against the actual FLAIR statements;
T13 stated as a SUM; T6 demanded as `StrictConvexOn`; guard confined to T19; bundle and fidelity;
and every Mathlib name (positive and negative claims alike).

## Reviewer 2 — Model QA Specialist

Verified directly against the anchor PDF (extracted to text, read at each cited location): MMR
Theorem 1's `P_trade`; LVR as a *rate* (`:880–884`); eq. (12) (`:897`); Corollary 2's kernel and its
`σ²Δt < 8` guard (`:812–838`); §7.1's `Δt^{3/2}` per-block scaling (`:1344–1346`); §7.3 eq. (27)
(`:1482`). Also re-derived the T19 antitonicity condition and the T6 second derivative independently.

- **BLOCKER B1 — T8 dropped the `Δt` factor from M3(i), re-introducing the exact rate-vs-amount
  defect the doc gate already BLOCKER'd and fixed (11-01 finding R2-B2).** The approved document
  displays `a_t = (σ_t²/8)·V_t·Δt`; the prompt stated `a t = (σpath t ^ 2 / 8) * V t`. The prompt
  thereby contradicted **its own** section-(A) docstring instruction. Without `Δt` the summand
  scales as `√Δt` rather than the anchor's `Δt^{3/2}`, misstating the batch-cadence lever by a full
  factor of `Δt`. The Δt-less form traces to the pre-gate research file, not to the spec of record.
- **MAJOR M1 — T17 false as stated** (independently found, same counterexample as Reviewer 1's
  BLOCKER B1). Adjudicated at the higher of the two severities.
- **MAJOR M2 — the `λ_ARB` object carries the aggregate's name** (`mevHazard`/`mevMulti`), against
  the two-symbol convention the prompt itself declares binding, and against the doc-symbol naming
  rule the prompt enforces for T19. Risk: a downstream `mevHazard + sandwich` is the double-count M0
  forbids.
- **MINOR m1** — "increasing in σ" uncarried (concurs with Reviewer 1's MAJOR M2).
- **MINOR m2** — `ARBoverV_exact` already contains the `P_trade` factor; instantiating it as `a t`
  inside `mevHazard` would double-count. Also `σ²Δt ≤ 2` already implies the `< 8` guard, so the two
  should not be stacked.
- **MINOR m3** — the `a_t` docstring should say "modelled steady-state expectation, not realized
  arbitrage profit", and LVR should be attributed to the rate quoted *before* eq. (12) rather than
  to eq. (12) itself (which is the split).
- **MINOR m4** — module caveat (iii) dropped M8's validity condition on the quasi-static extension.

Passing on its specific charges: guard placement; `Δt` unambiguously the mean interblock time and
`√(2/Δt)` a correct transcription; `ARBoverV_exact` an honest name; the no-demand-response caveat
demanded verbatim with eq. (27) quoted correctly; T7 honestly labelled a ring-tautology bridge.

## Resolution

| Severity | Finding | Disposition | Where fixed |
| --- | --- | --- | --- |
| BLOCKER | R2-B1 — T8 drops `Δt` from M3(i)'s weight; contradicts the approved doc and the prompt's own docstring instruction | FIXED — weight restated as `σpath t ^ 2 / 8 * V t * Δt` with the rate-vs-amount rationale and the `Δt^{3/2}` cross-check; `0 < Δt` added to the positivity hypotheses and "and nothing else" reworded so it does not collide with the guard prohibition | PROMPT §(B) T8 |
| BLOCKER | R1-B1 (= R2-M1) — T17 false for arbitrary compact `Θ`; `ptrade` pole ⇒ `ContinuousOn` fails ⇒ no minimizer | FIXED — T17 now carries the admissibility constraint (`Θ` in the nonnegative-level region, `0 ≤ u`, `0 < Δt`, `0 < σpath t`), records the counterexample, explains why FLAIR needed none, and explicitly forbids the degenerate "just add `ContinuousOn`" repair | PROMPT §(B) T17 |
| MAJOR | R1-M1 — M5(iii)'s strict-exceeds half has no carrier | FIXED — new named corollary `mevMulti_min_gt_corner` demanded, with the T14∘T16 chain spelled out as the proof route | PROMPT §(B) T18 |
| MAJOR | R1-M2 (= R2-m1) — M1's "increasing in σ" property uncarried | FIXED — companion `ptrade_monotoneOn_sigma` added to the T4 item, with the derivative hint and a note that it is non-strict | PROMPT §(B) T4 |
| MAJOR | R2-M2 — `λ_ARB` object carries the aggregate's name | FIXED by the reviewer's own minimal, one-shot-safe option: identifiers kept (11-03 integration and the traceability rows are keyed to `MevOptimization`/`mevMulti`), with a MANDATORY docstring line on `mevHazard`, `mevMulti` and T18 recording that the object is `λ_ARB`, a summand of `λ_MEV`, equal to it only under M7's unformalized reduction. Renaming was rejected: it would break the plan's own acceptance criteria and the downstream integration keys | PROMPT §(A), §(B) T18 |
| MINOR | R2-m2 — `ARBoverV_exact` double-count trap; redundant guard stacking | FIXED — docstring warning demanded, and the prompt now states that `σ^2 * Δt ≤ 2` already implies the `< 8` guard so the two must not be stacked | PROMPT §(C) T19 |
| MINOR | R2-m3 — `a_t` realized-vs-expected ambiguity; LVR mis-attributed to eq. (12) | FIXED — docstring now requires "MODELLED STEADY-STATE EXPECTATION … NOT a realized arbitrage profit" and attributes LVR to the rate quoted before eq. (12), with eq. (12) identified as the split | PROMPT §(A) |
| MINOR | R2-m4 — module caveat (iii) dropped M8's validity condition | FIXED — the quasi-static caveat now carries M8's "legitimate only if the parameters move slowly relative to mixing of the mispricing process" verbatim | PROMPT §(caveats) |
| MINOR | R1-m2 — T19 antitonicity is an addition beyond the approved doc | FIXED — the prompt now records explicitly that the document displays the kernel but asserts no monotonicity for it, so the claim is flagged as specification-added rather than doc-derived | PROMPT §(C) T19 |
| MINOR | R1-m1 — no lifted `mevMulti` convexity in `φbar` for M4's "convex in the fee" | ACCEPTED, not fixed. T6 carries the document's convexity assertion at the kernel level, which is where M1 states it; RESEARCH F4 plans the lift as a separate, lower-risk theorem, and nothing in this bundle consumes it. Adding a further optional item would dilute a one-shot prompt whose optional surface is already fixed at T19 | — |
| MINOR | R1-m3 — T14/T15 hypothesis lists not self-contained | ACCEPTED, not fixed. The mandatory HYPOTHESIS PRE-EMPT paragraph covers exactly these and instructs that they be included up front; the reviewer itself classes this a robustness note rather than a defect | — |

**No `DEFER-TO-DOC` rows.** Every finding was resolvable against the approved document, the anchor
paper, or the project's own proven Lean layer. In particular the two BLOCKERs were *fidelity*
failures — the prompt had drifted from the approved document (T8) and from what is mathematically
true (T17) — so fixing them moved the prompt TOWARD the doc, and no change to the approved document
was needed or made. The user-approved bytes are untouched: the doc-fidelity diff and the
`APPROVED-DOC-SHA256` check were both re-run after every prompt edit and still pass.

## Post-resolution verification

All of Task 1's structural acceptance greps were re-run after the edits and still pass: T1–T19 tags
present; every target identifier present; `StrictConvexOn` and `mevMulti_nonneg` intact; `not affine`
intact; the refuted `ptrade`-flavoured name absent; the guard literal and the T8 guard prohibition
intact; prompt length 275 lines; `git status --porcelain lean/` empty; no API key in the prompt or
the bundle; and the M-block doc-fidelity diff still empty.
