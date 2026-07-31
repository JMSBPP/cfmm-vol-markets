# 12-02 — Two-reviewer gate on the ARISTOTLE PROMPT

**Artifact reviewed:** `scratch/aristotle-eta-curvature-PROMPT.txt` (the artifact the prover
consumes — not the plan, not the doc).
**Reviewed at:** prompt sha256 `b1deb1a9177e10e36570c430d5d2c59fbd7109a8109b54002d3dc353fceba889` (pre-fix).
**Post-fix sha256:** `6f28c64f0af51a69cef757d99bf8d14f816dff47e610b4d4637f015b49ecade1`.
**Method:** both reviewers spawned as INDEPENDENT OS PROCESSES (`claude -p`), IN PARALLEL, BLIND to
each other. Neither could see the other's prompt or output. Both were given an explicit
final-message requirement, per 12-01's deviation record that `claude -p` returns only the final
assistant message and a run whose last message was an acknowledgement is lost in transport.
**Verdicts:** Reviewer 1 NEEDS WORK, Reviewer 2 NEEDS WORK. Both independently, neither blocked.

## Reviewer 1 — Reality Checker (mandatory, per the global two-step reviewer rule)

Charged with formal correctness: FOC-freedom, the T24' inversion algebra against the landed
`priceEta` rather than against prose, pole enumeration, identifier and signature existence,
T28'a's `Int → ℝ` coercion, T28'b separability, an independent re-derivation of the import
closure, Mathlib citation reality at the pin, false-as-specified hunting, and overclaim against
the approved document.

**Verdict: NEEDS WORK** — "the specification is unusually well-armored (every quoted signature,
every Mathlib citation, and the headline T24' algebra check out), but the displayed definition for
headline item T27' does not typecheck and contradicts T9', and T8' is false exactly as displayed;
both sit on the deliverable path of a one-shot, non-refundable run."

**1 BLOCKER, 1 MAJOR, 4 MINOR.**

- **BLOCKER 1 — T27's `lpExcessEta` does not typecheck and reintroduces `cOne` as a free
  parameter.** It applied EIGHT arguments to the SEVEN-parameter `lpExcess` of T9', and the extra
  parameter shadowed the `cOne` DEFINITION that T9' spends a paragraph insisting is not free. The
  prover would have had to resolve the contradiction unsupervised, and the wrong resolution — an
  `lpExcess` variant with a free `cOne` slot — silently falsifies the T10' branch agreement at
  `kphiI` on which the entire peak depends. This is the headline chain T27' → T28' → T30'.
- **MAJOR 2 — T8' is FALSE as displayed.** The item guards `premShock` against `Real.sqrt`'s junk
  value and MISSES the symmetric guard on `premInv`. Counterexample to the reverse direction:
  `fee = 0`, `premShock = 0`, `premInv = -2` gives `Real.sqrt (1/(-1)) = 0`, hence `kphiI = 1` and
  `kphiS = 0`, so `kphiS ≤ kphiI` holds while `premShock ≤ premInv` is `0 ≤ -2`. T8' was also not
  on the anti-narrowing list, so a quiet weakening of the iff to the forward implication under the
  requested name would have been undetectable downstream.
- MINOR 3 — the pre-empt names only the `1/curv` pole; the `1/(1-curv)` family at `curv = 1` is
  never named, and T17's stated justification for `Set.Icc 0 1` addresses the wrong endpoint.
  All nine sites enumerated and found structurally dead, so no false theorem results.
- MINOR 4 — one sentence ("that is the sentence this module answers") risks the forbidden
  de-degeneration reading under the narrowed CTX-DEGEN ruling.
- MINOR 5 — T17' supplies more concreteness than E5 displays; disclosed and subordinated,
  acceptable, recorded.
- MINOR 6 — T28'b has no machine-checkable acceptance criterion; inherent to a modelling claim,
  mitigated by optional status and the triple merge prohibition.

**Cleared explicitly:** no FOC anywhere; T24' equality and its inversion algebra verified
independently against `VolInstrument.lean:30`; all 18 modules' import closure re-derived and
complete; **every Mathlib citation real and line-exact — the reviewer checked all thirty, not the
six requested, and found zero phantom hints**; the three claimed-nonexistent names confirmed
absent; every quoted signature byte-exact against the landed files; T28'a typechecks with the
coercion; no overclaim relative to E0–E8.

## Reviewer 2 — Model QA Specialist (the specialist pick)

**Pick and reason.** The AI-agency catalog has no quantitative-finance or market-microstructure
agent. `Model QA Specialist` (`~/.claude/agents/specialized/specialized-model-qa.md`) is the
closest match to the charge the plan writes for Reviewer 2 — "is `curvIndex` a defensible discrete
curvature index, and does transporting Capponi's optimum through it preserve the economics or only
the algebra?" That is a model-audit question: an independent auditor who *replicates results,
challenges assumptions and treats every model as guilty until proven sound*, with finance among
its stated domains. It is the same pick 12-01 made for the same reason, which also keeps the
economics reviewer consistent across the phase. Runners-up rejected: Backend Architect and
Solidity Smart Contract Engineer (wrong domain — no code ships here), Security Engineer (no threat
surface), Reality Checker (already Reviewer 1; a second copy would not be independent).

Charged with the economics: index defensibility, the `cOne > 0` boundary, T31's direction, the
arbLoss/λ_ARB identification risk, the peak-mechanism claim, constant absorption, T17' fidelity to
(A.56), the T18' welfare tension, and vacuity risk. It read the anchor PDF directly
(§5.1 and the proofs of Lemma 3, Propositions 5 and 6, A.31–A.58).

**Verdict: NEEDS WORK** — "the transcription of the anchor is faithful and the guardrails on
identification, welfare and de-degeneration are genuinely strong, but block E7's
scalarization-impossibility sentence, mandated verbatim into T29's docstring, is mathematically
false."

**1 BLOCKER, 0 MAJOR, 7 MINOR.**

- **BLOCKER 1 — the E7 scalarization-impossibility claim is FALSE, and the prompt mandated it
  verbatim into a permanent Lean docstring.** E7 asserts that `w₁(-arbLoss) + w₂·surplus` has, on
  each branch, a derivative of constant sign, hence "peaks at a branch point only by accident of
  the weights". True on the two OUTER branches; **false on the middle region `[κ_φS, κ_φI]`**,
  where `arbLoss` has switched to its interior `1/k` form while `surplus` is still in its corner
  `1/(1-k)` form, making the derivative a difference of a decreasing and an increasing term.
  **This finding is in the APPROVED, BYTE-PINNED document, so per the plan it is ESCALATED, not
  silently fixed.**
- MINOR 1 — E0's justification for `ϖ_I > 0` is misattributed: at `probInv = 0` the strict
  INCREASE does not fail (the arb-loss term alone carries it); what fails is the PEAK, because
  `cOne < 0` makes `0 < cOne` unsatisfiable. Also an approved-E0 defect.
- MINOR 2 — T6' ("do not combine the two ratios additively anywhere") contradicts T18', which
  invites a named weighted sum. A literal prover could refuse T18' citing T6'.
- MINOR 3 — T17' over-asks relative to E5's shape-only transcription (disclosed and subordinated,
  defensible), plus a garbled sentence saying "anchor" where it means "document".
- MINOR 4 — T14's `kphiStar_eq_kphiI` is `rfl`-grade; its mandated docstring said "THAT
  COINCIDENCE IS THE ANCHOR'S RESULT" without naming T13' as the actual carrier. Explicitly the
  `arb_add_fee_eq_lvr` failure mode from Phase 11.
- MINOR 5 — T16' imports `0 < cOne` although the anchor states Proposition 5(2) unconditionally,
  and the conclusion in fact survives `cOne ≤ 0`.
- MINOR 6 — (a) E0's `ϖ_A > 0` justification omits that `θ < 1` is also needed; (b) T5's
  zero-loss deliverable was underspecified prose rather than a pinned display.
- MINOR 7 — T29's parallel phrasing invites the object-correspondences arbLoss↔λ_ARB and
  surplus↔λ_FLAIR; safe under the existing bans, but one clause closes the last inch.

**Cleared explicitly:** `cOne` verified term-by-term to BE the anchor's `τ₁` against (A.50); the
`cOne > 0` boundary is the anchor's own split and the prompt is *more* careful than the anchor;
T31's direction economically correct via the investor's corner condition; the T18'b witness
arithmetic recomputed and valid; T17's formula re-derived from (A.56) and faithful, branch
agreement confirmed at `(r·wA + wB)/(wA + wB)`; the peak-mechanism claim correct; constant
absorption sound with no claim depending on a relation between two absorbed constants; the
identification and de-degeneration guardrails layered and enforced; **no doc-vs-PDF disagreement
requiring escalation** — the two defects found are doc-vs-MATHEMATICS defects inside E7 and E0.

## Independent verification of Reviewer 2's BLOCKER before acting on it

The counterexample was recomputed from scratch rather than taken on trust, because a false
escalation is as costly as a missed one. With `fee = 0`, `probArb = 1`, `premShock = 0.5`,
`premInv = 3`, `w₁ = 2`, `w₂ = 1`: `kphiS = 0.183503`, `kphiI = 0.5`, and the weighted derivative
`w₁·probArb·(1+premShock)·kphiS²/(2·curv²) − w₂·(1+fee)/(2·(1−curv)²)` evaluates to

| `curv` | derivative |
| --- | --- |
| 0.1900 | +0.637097 |
| 0.2200 | +0.221773 |
| 0.2412 | −0.000181 |
| 0.4500 | −1.403459 |

so the sign changes strictly inside `[0.1835, 0.5]` and the weighted objective has a stationary
interior maximum at `curv ≈ 0.2412`, **at no branch point**. The finding is CONFIRMED. (The
reviewer's own numeric location, "k ≈ 0.29", is slightly off; the exact crossing is
`√A/(√A+√B) ≈ 0.24118`. The location differs, the finding does not.) E7's own DISPLAYED formula
for `[0, kphiS]` was separately checked and is CORRECT — the defect is the generalization from
that branch to "each branch", which fails because the two ratios switch branches at DIFFERENT
points.

**Why this does not falsify any theorem.** On the middle branch `lpExcess`'s two terms — LP
revenue and `−arbLossRatio` — both push UP, so the peak at `kphiI` is untouched. The defect is
confined to E7's auxiliary rhetoric. Every item T1'–T31' remains sound.

## ESCALATE — two defects in the APPROVED, BYTE-PINNED document, carried to the Task-3 user gate

Per the plan: *"If a finding says the APPROVED doc overclaims, STOP and escalate to the user
rather than editing the doc — that is 12-01 Task 3's gate, not this one's."* The plank-owned
document was NOT edited by this plan and `APPROVED-ETA-SHA256` is intact.

| # | Where | Defect | Status |
| --- | --- | --- | --- |
| ESC-1 | Block E7, the scalarization paragraph | "Such a combination is piecewise monotone and peaks at a branch point only by accident of the weights" is FALSE on `[κ_φ,S, κ_φ,I]`, with the counterexample above. The displayed `[0, κ_φ,S]` formula is correct; the generalization is not. | ESCALATED to the user at the Task-3 checkpoint. Neutralized inside the prompt: the false sentence is quoted only as approved-document text, an explicit correction note forbids formalizing or restating it, and the mandated T29' docstring now carries the true WEIGHT-INVARIANCE formulation instead. |
| ESC-2 | Block E0, the `ϖ_I > 0` justification | "at `ϖ_I = 0` E4's strict increase fails" is the wrong reason. The strict increase survives; the PEAK is what fails, via `cOne < 0`. | ESCALATED to the user at the Task-3 checkpoint. Neutralized inside the prompt: convention (4) now states the corrected reason and flags the document's version as wrong. |
| ESC-3 | Block E0, the `ϖ_A > 0` justification | Omits that `θ < 1` is also required. | ESCALATED as a completeness note. Nothing in the prompt depends on it. |

**Neither ESC-1 nor ESC-2 falsifies any requested theorem**, and both are neutralized inside the
prompt. Whether to spend the submission before the document is amended is the USER'S CALL at the
Task-3 gate, and Reviewer 2's own recommendation ("do not send until the user rules") is satisfied
by that gate, which is blocking regardless. The amendment itself belongs to a 12-01-style doc pass
or to 12-04's back-annotation, not to this plan.

## Resolution

| Severity | Finding | Disposition | Where fixed |
| --- | --- | --- | --- |
| BLOCKER | R1-1: `lpExcessEta` applies 8 args to the 7-param `lpExcess` and reintroduces `cOne` as a free parameter | FIXED IN PROMPT | T27' display: `cOne` removed from the binder list and the application, plus a new paragraph stating there is NO `cOne` slot and that it enters as a hypothesis |
| BLOCKER | R2-1: the E7 scalarization-impossibility sentence is false and was mandated verbatim into T29's docstring | FIXED IN PROMPT and ESCALATED as ESC-1 | T29' mandated docstring rewritten to the true weight-invariance form; a correction-and-provenance note added before T30' with the counterexample; a prohibition row added to the anti-narrowing list |
| MAJOR | R1-2: T8' is false as displayed, missing the symmetric `-1 < premInv` guard | FIXED IN PROMPT | T8' signature carries `(hI : -1 < premInv)`; both counterexamples displayed; T8' added to the anti-narrowing list as "must come back as an IFF" |
| MINOR | R1-3: the `1/(1-curv)` pole family at `curv = 1` is never named; T17's justification addresses the wrong endpoint | FIXED IN PROMPT | New first bullet in the hypothesis pre-empt naming the second pole family, the routing argument, and T17's correct endpoint |
| MINOR | R1-4: "the sentence this module answers" risks the forbidden de-degeneration reading | FIXED IN PROMPT | Reworded to "ADDRESSES BY CONTRAST, WITHOUT CLOSING", with a pointer to the section (D) scope ruling |
| MINOR | R1-5: T17' supplies more than E5 displays | ACCEPTED, disclosed | Already subordinated to the document's shape claims; recorded here and in the RUN-RECORD |
| MINOR | R1-6: T28'b has no machine-checkable criterion | ACCEPTED, inherent | Optional status plus the triple merge prohibition; scored by human review at return |
| MINOR | R2-1: E0's `ϖ_I > 0` justification is misattributed | FIXED IN PROMPT and ESCALATED as ESC-2 | Convention (4) gives the corrected reason and flags the document's version |
| MINOR | R2-2: T6' forbids what T18' invites | FIXED IN PROMPT | T6' carries an explicit one-item carve-out for T18' with explicit weights |
| MINOR | R2-3: garbled "anchor" where "document" is meant | FIXED IN PROMPT | T17' precedence sentence rewritten |
| MINOR | R2-4: T14's docstring over-reads an `rfl`-grade identity | FIXED IN PROMPT | Docstring instruction now names T13' as the carrier and cites the `arb_add_fee_eq_lvr` precedent |
| MINOR | R2-5: T16' imports `0 < cOne` though the anchor is unconditional | FIXED IN PROMPT | T16' instructs delivery without the hypothesis if possible, and recording it as stronger than the anchor otherwise |
| MINOR | R2-6b: T5's zero-loss deliverable underspecified | FIXED IN PROMPT | Both statements pinned as displays with explicit signatures |
| MINOR | R2-7: T29's parallel phrasing invites object-correspondence | FIXED IN PROMPT | Clause added: analogous in ROLE, NOT identified as OBJECTS, citing E8(3) |
| MINOR | R2-6a: E0 omits `θ < 1` from the `ϖ_A > 0` justification | ESCALATED as ESC-3 | Nothing in the prompt depends on it |

**Every BLOCKER and MAJOR is resolved in the prompt.** No row is open, unresolved or deferred.
The two document-level defects are additionally escalated to the user at the Task-3 gate, which is
where the submission decision is taken.

## Post-fix re-verification

Every mechanical criterion was re-run against the edited prompt and passes: all T-tags present;
`lpExcessEta` arity correct with no `cOne` slot anywhere; T8' guard and anti-narrowing row present;
the false scalarization claim absent from the mandated docstring and present ONLY as (a) the
verbatim quoted E7 block, which is byte-pinned approved text and was deliberately NOT edited, and
(b) the correction note and prohibition that neutralize it; NO-FOC still holds; every
anti-narrowing and pre-empt anchor intact; every project and `CFMM.Eta` identifier still resolves
in its landed module. Prompt length 1232 lines.

## Mathlib re-verification record (Task 2 step A, before the prompt was spent)

The plan's own verification command is DEFECTIVE and was corrected: it greps
`^(theorem|lemma) (StrictMonoOn|StrictAntiOn|MonotoneOn)` against
`Mathlib/Order/Monotone/Union.lean`, which returns NOTHING because every one of those lemmas is
declared `protected theorem`. Run as written it reproduces the 11-02 signature exactly — a
plan-supplied citation appearing not to exist — and would have caused the central gluing route to
be dropped. Re-run without the anchor, all six exist at the cited lines:

    protected theorem StrictMonoOn.union         Union.lean:29
    protected theorem StrictMonoOn.Iic_union_Ici Union.lean:58
    protected theorem StrictAntiOn.union         Union.lean:65
    protected theorem StrictAntiOn.Iic_union_Ici Union.lean:71
    protected theorem MonotoneOn.union_right     Union.lean:77
    protected theorem AntitoneOn.union_right     Union.lean:112
    theorem strictMonoOn_of_deriv_pos            Analysis/Calculus/Deriv/MeanValue.lean:374
    theorem strictAntiOn_of_deriv_neg            Analysis/Calculus/Deriv/MeanValue.lean:442

The plan's line numbers are all CORRECT (12-RESEARCH's are off by one for three of them; the plan
is right and the research is wrong). Twenty-two further `Real.*`, `Set.*` and order lemmas were
verified with file and line, scoped to the correct namespace — several of these names also exist
for `ℝ≥0` and `ℝ≥0∞` with DIFFERENT hypotheses, which is why the prompt cites file and line rather
than bare names. Reviewer 1 independently re-checked all thirty and found zero phantom hints.

Three plausible-but-absent names are stated in the prompt so the prover does not hunt for them:
`StrictMonoOn.Icc_union_Icc` / `StrictAntiOn.Icc_union_Icc`, `IsGreatest.isMaxOn`, and
`Real.sqrt_lt_one`. All three confirmed absent by grep over the whole bundled Mathlib, and
confirmed absent independently by Reviewer 1.
