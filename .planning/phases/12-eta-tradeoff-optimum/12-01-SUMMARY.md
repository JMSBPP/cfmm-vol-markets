---
phase: 12-eta-tradeoff-optimum
plan: 01
subsystem: vol_markets / math spec layer
tags: [curvature, capponi-jia, eta, notation-gate, reviewer-gate, doc-spec]
requires:
  - "Phase 11: MevJointProgram.joint_corner_degeneracy, joint_beta_degeneracy (the contrast)"
  - "VolInstrument.priceEta, priceEta_one; PosSpec.lam, tickPrice"
  - "CFMM.Eta.p_eta, p_eta_eq_P_half_rescaled, P_half, L_eta (read-only reference)"
  - "../plank/refs/mev/CapponiJiaAdoptionDEX.pdf (arXiv:2103.08842v4)"
provides:
  - "The APPROVED curvature-controller spec E0-E8, landed in the plank-owned VOLATILITY_INSTRUMENTS.md"
  - "APPROVED-ETA-SHA256 / APPROVED-ADDENDUM-SHA256 pins that 12-02 and 12-04 grep for"
  - "eta-notation-gate.sh — the INVERTED gate (eta REQUIRED), with kappa_varphi Rules 4b/4c"
  - "The binding notation for 12-02's Aristotle prompt: kappa_varphi, kphiS/kphiI/kphiStar, fee = phi"
  - "The user's CTX-DEGEN scope ruling: no literal de-degeneration theorem"
affects:
  - "12-02 (bundle prompt) — notation, scope ruling, and the doc-fidelity pin all come from here"
  - "12-04 (traceability + plank todo #227 answer)"
  - "../plank/notes/VOLATILITY_INSTRUMENTS.md and ../plank/todo.md (written, NOT committed)"
tech-stack:
  added: []
  patterns:
    - "Inverted notation gate: the protected symbol is REQUIRED, not forbidden"
    - "END-marker-delimited sha pinning, immune to parallel edits elsewhere in the file"
    - "Negative-testing a new gate rule before trusting it"
    - "Payload-standalone gating: gate what LANDS, not only the source file"
key-files:
  created:
    - model/vol_markets/VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md
    - .planning/phases/12-eta-tradeoff-optimum/eta-notation-gate.sh
    - .planning/phases/12-eta-tradeoff-optimum/12-01-REVIEW.md
    - .planning/phases/12-eta-tradeoff-optimum/12-01-SUMMARY.md
  modified:
    - ../plank/notes/VOLATILITY_INSTRUMENTS.md (written, NOT committed — owner ul2inqpl)
    - ../plank/todo.md (written, NOT committed — owner ul2inqpl)
decisions:
  - "Curvature index is kappa_varphi, not chi (USER, 2026-07-31 amendment)"
  - "The fee is phi, not varphi — varphi is the quote-function symbol per M0; a live collision fixed"
  - "Placement: the user-authored ## FLAIR & MEV stub body replaced, title kept"
  - "CTX-DEGEN NARROWED (USER): no literal de-degeneration theorem; binding on 12-02"
  - "The eta bridge ships as TWO claims — exponent identity provable, factor share OPEN"
  - "Welfare (Prop 6 second half) is OPEN, not transcribed — it does not follow from E3+E4"
metrics:
  duration: ~4h
  tasks: 3
  files: 6
  completed: 2026-07-31
---

# Phase 12 Plan 01: ETA Curvature Doc Spec Summary

Capponi–Jia's §5.1 curvature results transcribed as insert-ready LaTeX blocks E0–E8 under the
`κ_φ` remap, reviewer-gated to 3 BLOCKERs and 9 MAJORs, user-approved, and landed sha-pinned in the
plank-owned document — with the phase's headline `η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)` obtained by
inverting a bijection at a KINK, and the de-degeneration claim honestly withdrawn.

## What was built

**`model/vol_markets/VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md`** (260 lines) — nine blocks:

- **E0** the notation map (anchor cite, `k → κ_φ`, `α → ϱ_I`, `β → ϱ_S`, `f ≡ φ`, `θ/κ_*` absorbed
  into `ϖ_A, ϖ_I, ϖ_H, ϖ_D`, `τ₁₂₃ → c₁₂₃`), the standing hypotheses, the not-probabilities
  paragraph, the η bridge as two claims, and the proposed Lean names.
- **E1** the `F_{κ_φ}` family and `κ_φ(η,Δ_i) = 1 − λ^(−Δ_i²η/2)` from the tick-independent step
  ratio; the bijection `(0,∞)→(0,1)`; `κ_φ` as a monotone **proxy**, not a definitional restatement.
- **E2/E3** Lemma 3(1) and 3(2): both branches, branch points, continuity, strict antitonicity.
- **E4** Proposition 5: three branches, continuity at both points, **`κ_φ^★ = κ_φ,I = 1 − √((1+φ)/(1+ϱ_I))`**,
  the KINK statement, the `c₁ ≤ 0` freeze boundary.
- **E5** deposit efficiency; welfare **OPEN** with the reason; the zero-sum identity; gas.
- **E6** the headline `η*`, comparative statics, admissibility, the exponent identity.
- **E7** the interior optimum against the Phase-11 corner, with the true mechanism.
- **E8** nine numbered **OPEN** items.

**`eta-notation-gate.sh`** — the inverted gate. Rule 1 REQUIRES η (the Phase-11 gate forbids it);
Capponi's externals, first-order-condition language and the CPMM misidentification are forbidden;
λ is admissible only subscripted, power-raised, `\ln`-prefixed, or on the one tick-base declaration.
Rules 4b/4c added by the amendment.

**`12-01-REVIEW.md`** — both verdicts, the resolution table, the user's verbatim approval and
amendment, and the sha pins.

## Key decisions

**The curvature index is `κ_φ` (user amendment), and that surfaced a real collision.** Putting
`\varphi` in the subscript exposed that the draft had been using `\varphi` for the **fee**, directly
contradicting the master document's own M0 (*"Fee `= \phi` …; `\varphi` NOT used (bound to the quote
function)"*). The fee was retyped `\phi` throughout. **Both reviewers missed this and the
pre-amendment gate could not see it** — it took the user's notation caveat to expose it.

**CTX-DEGEN was narrowed by the user and that ruling is binding on 12-02.** There is no literal
de-degeneration theorem. What ships is the interior optimum in the Capponi-anchored model plus the
η-bridge transport, with the Phase-11 contrast as a scope statement.

**The η bridge ships as two claims, not one.** (i) the exponent identity — provable, verified
line-by-line against the tree by the Reality Checker; (ii) the factor-share identification — a
modelling claim, OPEN, and *unavailable* wherever `η* ∉ (0,1)` (at `ϱ_I = 0.05, φ = 0.003`,
`η* ≈ 458/Δi²`, so `Δi = 1` gives 458).

## What the reviewer gate caught

Both reviewers returned NEEDS WORK. **Every BLOCKER was mine, and two of them were defects the PLAN
and the RESEARCH had specified.**

1. **E6's "SUPERSEDED" claim smuggled in the OPEN factor-share identification.**
   `exp/DynamicsOptimization`'s η enters only through the inventory-weight curve — it is claim (ii)'s
   η — and its objective is `π⁺`, not `D`. Now an explicit non-relation.
2. **E7's mechanism was wrong and contradicted E4.** `D` does *not* combine `arbLoss` and `surplus`;
   investor surplus is not a term of `D` at all. The peak comes from the LP revenue term's
   corner→interior regime switch at `κ_φ,I`. The reviewer further showed the "two antitone
   objectives ⇒ interior peak" reading is **unsound**: a nonnegative weighting has branch-constant
   derivative sign, so it peaks at a branch point only by accident of the weights — the same defect
   Phase 11 refuted, reintroduced as the positive story. **This came from 12-RESEARCH F8 and the
   plan's own E7 text.**
3. **The de-degeneration was vacuous under my own E8(3)** — it contrasted two arbitrage objects the
   document itself declares unidentified.

Nine MAJORs, including: `ϖ_A > 0` was never assumed, which made three strictness claims false as
written; `E1` asserted the `κ_φ ↔ k` identification as definitional (**found independently by both
reviewers**); `φ̄` is `multiFee`'s floor, not the fee, so `η*` is σ-indexed; "unbounded η helps
interiority" was backwards (the map covers `(0,1) ⊊ [0,1]`); welfare does not follow from E3+E4.

Where a reviewer contradicted `12-RESEARCH.md`, the PDF and the Lean tree decided. **That happened
three times and the reviewers won each time.**

## Deviations

**[Rule 1 — Bug] The gate caught a packaging defect at insertion time that every content check had
passed.** The anchor citation lived in the addendum's `>` header, *above* `**E0.`, so it did not
travel into the `E0 … END ETA` payload — the section that would have landed in the plank document
carried no citation at all, and the plan's own acceptance criterion would have failed. Insertion was
**reverted** (M-block hash re-verified at baseline after the revert), an ANCHOR line was added inside
E0, and the payload was re-checked to pass the gate **standalone** before re-inserting. Gating the
source file is not the same as gating what lands.

**[Rule 3 — Blocking] Reviewer 1's first run was lost in transport.** `claude -p` returns only the
final assistant message, and that run ended with a one-line acknowledgement. Re-run with an explicit
final-message requirement; it stayed blind to Reviewer 2 and its prompt was otherwise byte-identical.

**[Rule 3 — Blocking] The `claude-peers` MCP tool is not exposed to executor sub-agents.** The peer
notification was routed through `../plank/todo.md` instead — the same channel 11-01 Task 3 used,
carrying the identical payload. **The coordinator should re-send the live notification.**

**Mechanical-criterion defect, recorded not papered over.** The plan's
`[ "$(git status --porcelain lean/ model/exp/ | wc -l)" = "0" ]` criterion **false-fails**:
`model/exp/eta.md` was already modified and `eta_pi_trader_delta_control.md` already untracked before
this plan started — the plan's own `<constants>` says so. Verified the stronger correct property
instead: `lean/` and `model/exp/` are byte-identical to the pre-plan baseline (same porcelain output,
same `git diff` sha256 `679e1aa3…`). Same self-contradiction class as 11-02's `ptradeCPMM`, 11-03's
axiom-name grep and 11-06's home-path grep.

## Not established

- **Nothing is proven.** E0–E8 are a *specification*. No `.lean` file was touched
  (`git status --porcelain lean/` identical to baseline across every commit).
- **The equilibrium transfer and the object-level identification are ASSUMPTIONS** (E8(1)). Every
  result is a theorem about the displayed functions composed with `κ_φ(·,Δ_i)` — nothing is a theorem
  about this project's AMM.
- **The Phase-11 degeneracy is NOT resolved** (E8(7)), per the user's ruling.
- **Welfare is OPEN** (E8(2)); `ϱ_I` is a *candidate* for the §6(b) demand layer, not a closure.
- **`12-RESEARCH.md` carries three defects forward** (F8's mechanism, F8's de-degeneration framing,
  F3's "beyond his range") — flagged for correction at 12-04 so no later plan re-injects them.

## Pre-existing condition in the plank worktree

Another workstream has an **uncommitted prose-compression pass** live on M0–M8. The M-block scope
already differs from plank `HEAD` (`9fcf01d3…` vs `125bb9f7…`), so **the Phase-11 M-block sha pins
are already stale there, independently of Phase 12.** This plan's baseline is the working tree
captured immediately before each insertion, so its check proves exactly — and only — that *these*
insertions moved no M-block byte. Re-pinning is the plank owner's call.

## Verification

| Check | Result |
| --- | --- |
| gate on the addendum | PASS |
| gate on the E0…END-ETA payload standalone | PASS (245 lines) |
| gate on the inserted plank section | PASS |
| PIT-E1 canary (Phase-11 addendum) | FAILS with the Rule-1 message, as required |
| Rules 4b / 4c negative tests | both correctly REJECT |
| M-block integrity M0 → end-of-M8 | `9fcf01d3…` identical before and after both insertions |
| plank `HEAD` before == after | `f379f483…` — this session committed nothing there |
| `lean/` + `model/exp/` | identical to the pre-plan baseline |
| pins match live bytes | `APPROVED-ETA-SHA256` and `APPROVED-ADDENDUM-SHA256` both verified |

## Self-Check: PASSED
