# 12-01 — Two-reviewer gate on the ETA curvature doc block (E0–E8)

The gate runs on **the artifact the downstream consumer actually reads** — the addendum, which is
what 12-02 bundles to Aristotle and what 12-04 back-annotates. Both reviewers were spawned as
**independent OS processes in parallel** (`claude -p --permission-mode plan`, read-only), each given
the artifact, the anchor PDF, the research file and the Lean tree, and each charged with a distinct
question set. Neither was shown the other's findings, and neither could edit any file.

| Field | Value |
| --- | --- |
| artifact reviewed | `model/vol_markets/VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md` |
| pre-review sha256 | `45b78f22f14fd2b9d4229ecd5c27762851a243a44b620e14e114283a536f3f28` (207 lines) |
| reviewers | Reality Checker (mandatory) + Model QA Specialist |
| verdicts | **NEEDS WORK** and **NEEDS WORK** |
| findings | **3 BLOCKER, 9 MAJOR, 9 MINOR** |
| blocking rows unresolved at close | **0** |
| post-resolution line count | 254 |

**Specialist pick and reason.** Reviewer 2 is the catalog's **Model QA Specialist**
(`.claude/agents/specialized/specialized-model-qa.md`), operated in the quantitative-finance /
market-microstructure register. It was **chosen because** the risk concentrated in this artifact is
*economic misstatement of what curvature does to arbitrage and to investor demand* — not LaTeX, not
Lean syntax — and the catalog holds no closer match to AMM economics, slippage, deposit games and
welfare rankings. It is also **deliberately the same pick as 11-01, 11-02 and 11-04**, so the phase's
gates stay comparable to Phase 11's rather than each measuring something different.

**Transport deviation, recorded.** Reviewer 1's first run completed its review but `claude -p`
returns only the FINAL assistant message, and that run ended with a one-line acknowledgement, so the
findings were lost in transport. Reviewer 1 was re-run with an explicit final-message requirement.
It remained **blind**: it was never shown Reviewer 2's output, and its prompt was byte-identical
apart from the appended transport clause. The parallelism of the first run was real; only its
transport failed.

**Anchor extraction.** Both reviewers extracted and read the PDF themselves rather than trusting the
research summary:
`pdftotext -layout ../plank/refs/mev/CapponiJiaAdoptionDEX.pdf /tmp/capponi-rN.txt`, then §5.1 and
the appendix proofs (A.31)–(A.56). Both independently re-derived the branch-agreement algebra.

---

## Reviewer 1 — Reality Checker

Role file `.claude/agents/testing/testing-reality-checker.md`. Charged with (a) formula-by-formula
transcription fidelity against the PDF including hand re-derivation of branch agreement at both
branch points, (b) citation numbers, (c) premia-not-probabilities, (d) no first-order condition,
(e) the `1/χ` pole, (f) the η-bridge split audited against the code as it exists, (g) existence of
every backticked Lean identifier.

**Verdict: NEEDS WORK.** 1 BLOCKER, 3 MAJOR, 6 MINOR.

### [BLOCKER] E6's "SUPERSEDED" sentence smuggles in the OPEN factor-share identification and contradicts E8(6)

`exp/DynamicsOptimization.lean` has `piPlus w α Δi η = Δi^2 * Sfac w α η` and η enters **only
through the inventory-weight curve `w η j`** — the reserve-side factor share, i.e. claim (ii)'s η,
not `priceEta`'s grid exponent. Its objective is `π⁺`, not `D`. So "supersedes" requires exactly the
identification E0(ii)/E8(6) declare OPEN. Compounding: `foc_eta` and `optimal_controls` are proven,
axiom-clean theorems in this tree, and a spec block asserting they are superseded makes a claim about
existing verified work with no supporting argument anywhere in E0–E8. This is an internal
contradiction between E6 and E8(6) inside the same artifact.
**Fix:** state a NON-relation — different objective, different η, no relation asserted; delete
"SUPERSEDED".

### [MAJOR] E7's headline claim is FALSE as specified: `ϖ_A > 0` is never assumed

E0 declared the four constants "each ≥ 0". Both branch derivatives of `arbLoss` vanish identically
at `ϖ_A = 0`, so `arbLoss ≡ 0`, **every** η is arb-minimal, and E7's "no η is simultaneously
arb-minimal and surplus-maximal" is false. The same gap makes E4's unconditional strict increase
false at `ϖ_I = 0`. The anchor supplies positivity for free: its two idiosyncratic-shock
probabilities lie strictly inside `(0,1)` (eq. (2)), and the investor arrival probability is
strictly positive.
**Fix:** standing hypotheses `0 < ϖ_A`, `0 < ϖ_I`, with the source recorded.

### [MAJOR] E1 asserts the χ↔k identification as a definitional fact, contradicting E8(1) (PIT-E8)

The anchor's curvature is the rate of change of the marginal exchange rate **with respect to traded
amount**, and its `k` is the *mixing weight* of `F_k`, not a curvature value; every number placed in
the χ slot (`χ_S`, `χ_I`, `χ*`) is a value of that mixing weight. The document's χ is a rate of
change with respect to *tick index*. E8(1) concedes the equilibrium transfer but does not reach the
prior object-level step, which E1 asserted outright.
**Fix:** χ is a monotone PROXY; the identification is a modelling step; extend E8(1) to cover it.

### [MAJOR] E7's coupling display substitutes `φ̄` into the slot of the Capponi per-trade fee `φ`

`VolInstrument.multiFee n γ β α φbar u σ = φbar + (Σ_j α_j·logistic(γ_j(σ−β_j)))·u`, and
`multiFee_bounds` proves `φbar ≤ multiFee ≤ φbar + (Σα_j)u`. So **`φ̄` is the fee's FLOOR, not the
fee**; the Phase-11 corner pins a σ-indexed fee PATH. The correct object is
`η*(σ) = ln((1+ϱ_I)/(1+multiFee(σ)))/(Δᵢ² ln λ)`, a σ-indexed function, while E1/E6 treat η as a
single design constant and E8's last caveat restricts everything to a FIXED φ. E7 was stated more
strongly than E8 licenses. (The comparative static itself was verified correct.)
**Fix:** state the coupling at a fixed realized fee; add the σ-indexing reconciliation as an OPEN item.

### [MINOR] Proposition 5's displayed hypothesis is strict; the document transcribes the proof's weak form without saying so; at `ϱ_S = ϱ_I` the middle branch collapses.

### [MINOR] Six backticked Lean names do not exist and are not marked as proposed

12/12 existing identifiers resolve at the right names (`joint_corner_degeneracy`
`MevJointProgram.lean:39`, `priceEta` `:30`, `priceEta_one` `:44`, `p_eta`
`EtaReplication.lean:53`, `p_eta_eq_P_half_rescaled` `:80`, `L_eta` `eta.lean:112`, `P_half` `:38`,
`lam` `PosSpec.lean:39`, `tickPrice` `:46`, `mevMulti` `MevOptimization.lean:63`, `multiFee`
`VolInstrument.lean:199`, `foc_eta`/`optimal_controls` `DynamicsOptimization.lean:183,201`).
Not found: `curvIndex`, `curv`, `premInv`, `premShock`, `cOne`, `cTwo`, `cThree`. Also E0 offered
two names for one object, which is not a decision.

### [MINOR] Two citation-precision slips in E7

The shape-block result is `joint_beta_degeneracy` (T21), not `joint_corner_degeneracy` (which fixes
`γ β` and quantifies over levels only); the demand-response sentence is in the **module** docstring,
not the theorem docstring; and neither that docstring nor `LEAN_TRACEABILITY` §6(b) names `ϱ_I`.

### [MINOR] The `1/χ` guard lives in one global prose sentence, not on the displays

Charge (e) answered: **no display quantifies over a region containing χ = 0 on a denominator
branch** — `χ_S > 0` and `χ_I > 0` follow from the strict standing hypotheses, and `χ(η,Δᵢ)` is a
bijection onto `(0,1)` so χ = 0 is unattainable. The residual risk is structural: the guard is
stated globally in prose while E2/E3/E4 are written as unconditional case-splits, which is precisely
how Phase 11's `ptrade` pole reached two theorem statements.

### [MINOR] The curvature family is on p. 23, not p. 22 (the quoted phrase on p. 22 is correct).

### [MINOR] `ϖ_H` is declared but load-bearing nowhere; `ϖ_D ≥ 0` is correct but its source (the anchor's strict ordering of the two shock probabilities, eq. (2)) is unrecorded.

**Reviewer 1 explicitly cleared:** every closed form in E1–E5 against (A.36)/(A.38)/(A.42)/(A.43)/
(A.50)–(A.52)/(A.56), **including all branch DIRECTIONS**; branch agreement re-derived by hand at
`χ_S` for `arbLoss`, at `χ_I` for `surplus`, and — the non-obvious one — at `χ_I` for `D`, where
`c₁/χ_I = c₂(χ_I) = (ϖ_I/2)(√((1+φ)(1+ϱ_I))−1) − (ϖ_A/2)(1+ϱ_S)χ_S²/χ_I` exactly; the E6 inversion
and all comparative-static signs; citation numbers (PIT-E2 cleared, no curvature claim cites Lemma
1); premia-not-probabilities (PIT-E3 cleared, no slip anywhere); **no first-order condition anywhere
(PIT-E7 cleared)**; the exponent identity (f)(i) verified line-by-line against the three definitions
in the tree, including the necessary integer-tick restriction which the document states unprompted;
the `η = 1` / `χ = 1` prohibition honoured twice; and the OPEN labels judged honest rather than
euphemistic.

---

## Reviewer 2 — Model QA Specialist (quantitative finance / market microstructure)

Charged with: is the discrete curvature index a defensible analogue; is the two-sidedness stated
acceptably and is the interior optimum argued correctly (peak from two-sidedness, NOT from
weighting); is the fee↔curvature coupling coherent; is the continuum→tick-grid transfer honestly
bounded; is the "substitution elasticity" phrasing tightened correctly; are the two arbitrage
objects kept apart; is the welfare bound correct; anything else economically misleading once
machine-checked and cited.

**Verdict: NEEDS WORK.** 2 BLOCKER, 6 MAJOR, 3 MINOR.

### [BLOCKER] E7's interior-optimum mechanism is wrong: it is a scalarization story, and the real driver is the investor's corner→interior regime switch

`D` does **not** combine `arbLoss` and `surplus`. Investor surplus never appears in `D`. `D` = LP
revenue from investor flow − `arbLoss`, and the revenue term (A.46) `= ½((1+f)/(1−k) − 1)` is
**increasing** in χ — the opposite sign to `surplus`. Worse, on the corner branch the two objects E7
called opposed are not in conflict at all: surplus + revenue `= ϱ_I/2`, **constant in χ**, so below
χ* curvature is a pure zero-sum transfer and the gains from trade do not shrink. The peak at χ_I is
where that transfer regime ENDS and the investor starts curtailing volume — the anchor's own prose,
and what E4 already said correctly. **E7 contradicted E4.** And the scalarization reading is not
merely imprecise but unsound: on each branch `d/dχ[w₁(−arbLoss) + w₂·surplus]` has a sign constant on
that branch depending only on the weights, so such a combination peaks at a branch point only by
accident. "Two objectives with opposite corners" does **not** imply an interior peak — the same
defect Phase 11 refuted (`joint_scalarization_degeneracy`), reintroduced as the positive story.

### [BLOCKER] The de-degeneration in E7 is vacuous under the document's own E8(3)

E7 contrasted "the arbitrage-channel minimum" of `joint_corner_degeneracy` (i.e. `mevMulti`) with
"the arb-minimizer at η → ∞" (i.e. Capponi's `arbLoss`) in adjacent sentences of a paragraph whose
whole purpose is to contrast them — while E8(3) states the two are NOT identified. `mevMulti`
contains no η, no χ, no `ϱ_I`; nothing in E1–E6 moves it, so the Θ_φ program's objective is
untouched and no de-degeneration occurs. PIT-E5 names this exact failure and its warning sign.
**Fix:** rename the two minimizers throughout; state honestly that the Phase-11 degeneracy is not
resolved; note that `MevJointProgram`'s module docstring locates the escape in demand response, so
the honest closure is that `ϱ_I` is a candidate for that layer.

### [MAJOR] E1 asserts the discrete index *is* the anchor's curvature; χ contains no liquidity

Slippage per unit traded is (price step)/(liquidity in the tick); two grids with identical χ and
different `L` have different curvature in the anchor's sense. And `k` is not a summary statistic —
it appears structurally in (A.31)/(A.39), from which every closed form is derived. **E1 asserted
what E8(1) concedes is open, and E1 is the sentence a downstream reader will cite.**
*(Converges with Reviewer 1's MAJOR on the same sentence, found independently.)*

### [MAJOR] E7's coupling carries no hypotheses, supplies no mechanism, and its own limit destroys the interior optimum

Sign verified correct. But: the mechanism is never given (fee and curvature are substitute frictions
on the investor's marginal cost, so the drain regime ends at lower curvature); E4's `c₁ > 0` is
dropped and **`c₁` depends on φ**, with `c₁ > 0 ⟺ ϖ_I > ϖ_A√(1+ϱ)` in the symmetric case, so
high-shock/low-flow pools sit in `c₁ ≤ 0` where the LP payoff is flat and no η is optimal; and as
`φ → ϱ_I⁻`, `χ* → 0` and `η* → 0⁺`, i.e. **at a high enough fee corner the curvature controller
switches off**, with nothing bounding `φ̄` away from `ϱ_I`.

### [MAJOR] "our η range does not cap … which HELPS interiority" is backwards

E1's own bijection maps `(0,∞)` onto the OPEN interval `(0,1) ⊊ [0,1]`. Unbounded η buys no
curvature beyond constant product; it only approaches it. So it cannot "help" interiority — and
because χ never attains 0 or 1, **every** χ* ∈ (0,1) pulls back to a finite η*, making "η INTERIOR" a
coordinate property of the reparametrization rather than economic evidence. Relatedly, "strictly
decreasing in Δᵢ²" is definitional, not a comparative static.

### [MAJOR] The welfare bounding mis-describes Proposition 6's structure

Welfare is not a sum of three pieces evaluated at a point; it is a two-period **compounded**
expression with a **freeze indicator** and its own carrier coefficient, whose monotonicity is a
genuine computation. The reduced form points the reader the wrong way: below χ*, LP payoff rises
while surplus falls, so "LP peaked at χ*, surplus antitone" sooner suggests the opposite conclusion.
**Fix:** transcribe the actual carrier, or bound the block to the deposit-efficiency half and mark
welfare OPEN with the reason.

### [MAJOR] Gas: the miners-outside-the-agent-set content is unstated, and it is the assumption this project's MEV block contradicts

Assumption 3 does two things and the document named only one. It also makes arbitrage rent a
**deadweight loss** rather than a transfer, and that holds *only because miners are excluded from the
welfare agent set*. Under any rent recycling (batch-auction ToB, MEV tax) the arbitrageur's payoff is
not zero, the recipient is inside the agent set, and the welfare ranking over χ changes. A downstream
reader can otherwise import a ranking inconsistent with this project's own MEV premises.

### [MAJOR] η* leaves the factor-share range for standard tick spacings, and E0 asserts declaratively what E8(6) lists as OPEN

E0 said flatly "η is a FACTOR SHARE on reserves" while E8(6) lists that identification as OPEN —
self-contradiction in the block that sets the reading for everything downstream. It is also
quantitatively unsafe: at `λ = 1.0001`, `ϱ_I = 0.05`, `φ = 0.003`, `η* ≈ 458 / Δᵢ²`, giving 458,
4.58, 0.127, 0.0115 at Δᵢ = 1, 10, 60, 200. For the two low spacings in standard use the
factor-share reading is **unavailable**, not merely open; `η* ∈ (0,1)` needs `Δᵢ ≳ 21`.

### [MINOR] E3's `surplus` is the per-investor ratio, half Lemma 3(2)'s object, and carries no `ϖ_I` while E2 carries `ϖ_A` — asymmetric conditioning between two blocks that get combined additively.

### [MINOR] Proposition 5's displayed hypothesis is strict; the `ϱ_S = ϱ_I` degenerate case (empty middle branch) is not addressed. *(Converges with Reviewer 1.)*

### [MINOR] "fee revenue" is slippage rent plus fee and is positive at zero fee, so the mechanism cannot be described as a fee-revenue/arb-loss trade-off; the interior optimum exists at φ = 0.

**Reviewer 2 explicitly cleared:** all closed-form transcriptions in E2/E3/E4 exact against the
appendix, including the `(1+ϱ_S)χ_S² = (√(1+ϱ_S)−√(1+φ))²` rewriting; the E4 branch assignment
(and noted that the paper's own text at (A.52) cites "(A.45)" where the resulting coefficient is
plainly built from (A.46) — a source typo the document silently has right); continuity at both
branch points, re-derived by hand; both Lemma 3 monotonicities; **PIT-E7 satisfied, called "the
document's best block"**; the E1 grid algebra and the E6 inversion with all comparative-static signs;
the `η = 1` warning; the NOT PROBABILITIES paragraph; the substitution-elasticity tightening as
economically correct; E5's deposit-efficiency half; **E8(1) as the correct bounding of the
equilibrium transfer with the right force** ("charge 4 is answered: the document does not read as if
Capponi's results were proved for our AMM"); E8(3)'s non-identification wording in isolation; and no
contradiction with the MEV addendum's M0 or the amended M6b.

---

## Resolution

Adjudication rule applied throughout: **where a reviewer finding contradicts `12-RESEARCH.md`, the
PDF and the Lean tree decide.** That happened three times — F8's mechanism, F3's "beyond his range"
claim, and F8's "de-degeneration" framing — and the reviewers won each time. The research file
carries those defects forward and is flagged for correction in 12-04 so the plan cannot re-inject
them.

| Severity | Finding | Disposition | Where fixed |
| --- | --- | --- | --- |
| BLOCKER | R1: E6 "SUPERSEDED" smuggles in the OPEN factor-share identification | RESOLVED. Replaced with an explicit NON-relation: different objective (π⁺ vs D), different η (inventory weight vs grid exponent), no relation asserted, those theorems stand untouched | E6, "RELATION TO THE EXISTING LAYER" |
| BLOCKER | R2: E7's interior-optimum mechanism is a scalarization story; D does not combine arbLoss and surplus | RESOLVED. E4 now states what D is made of; E7 rewritten so the peak comes from the LP revenue term's corner→interior regime switch at χ_I, with the scalarization reading explicitly refuted by its own branch-derivative sign | E4 "WHAT D IS MADE OF", E7 paras 3-4 |
| BLOCKER | R2: the de-degeneration is vacuous under E8(3) — two unidentified arb objects | RESOLVED. E7 retitled, the two minimands named separately and never interchanged, and the section now states plainly that the Phase-11 degeneracy is NOT resolved here; ϱ_I downgraded to a candidate for the §6(b) demand layer; new caveat E8(7) | E7 paras 1, 5; E8(7) |
| MAJOR | R1: ϖ_A > 0 never assumed, so three strictness claims are false as written | RESOLVED. Standing hypotheses now 0 < ϖ_A, 0 < ϖ_I with the anchor's eq. (2) recorded as the source, plus a note that the positivity is load-bearing | E0 constants block |
| MAJOR | R1 + R2 (independent convergence): E1 asserts χ↔k as definitional | RESOLVED. χ is now a monotone PROXY; the liquidity-free character is stated; the identification is named a MODELLING step; E8(1) extended to cover the object level as well as the equilibrium level | E1 para 3; E8(1) |
| MAJOR | R1: E7 substitutes φ̄ (multiFee's floor) for the per-trade fee φ | RESOLVED. Coupling restated at a fixed realized fee; multiFee_bounds cited; the σ-indexed η*(σ) vs fixed grid η reconciliation added as a caveat | E7 third boundary; E8(8) |
| MAJOR | R2: E7's coupling has no hypotheses, no mechanism, and its limit destroys the optimum | RESOLVED. Coupling now carries c₁(φ) > 0 and φ < ϱ_I, states the substitute-frictions mechanism, and lists the c₁ ≤ 0 void and the φ → ϱ_I⁻ switch-off | E7 "THE COUPLING" + boundaries; E8(9) |
| MAJOR | R2: "unbounded η range HELPS interiority" is backwards | RESOLVED. Deleted. E1 now states the parametrization covers (0,1) ⊊ [0,1], never attains the corners, and that interiority is INHERITED from χ* rather than supplied; Δᵢ² relabelled a normalization identity | E1 warning para; E6 comparative statics |
| MAJOR | R2: welfare mis-described as a sum of three pieces | RESOLVED. Welfare is now OPEN with the reason stated (the pieces move in opposite directions below χ*); only the deposit-efficiency half is transcribed; the zero-sum identity added as the sharp positive statement | E5; E8(2) |
| MAJOR | R2: gas — miners outside the welfare agent set, contradicting this project's MEV premises | RESOLVED. Stated in E5 and folded into E8(2), naming rent recycling as the specific incompatibility with the `### MEV` section | E5 gas para; E8(2) |
| MAJOR | R2: η* leaves (0,1) for standard spacings; E0 asserts what E8(6) calls OPEN | RESOLVED. E0's terminology sentence now attributes the factor share to L_eta's own exponent and defers the identification to E8(6); E6 gains the admissibility bound and the worked numbers | E0 TERMINOLOGY; E6 ADMISSIBILITY; E8(6) |
| MINOR | R1 + R2: Prop 5 displays the strict ordering, proof uses the weak form; ϱ_S = ϱ_I collapses the middle branch | ACCEPTED and fixed: both recorded in E0, with E3 recast to say it geometrizes the PROOF's hypothesis | E0 premium ordering; E3 |
| MINOR | R1: six proposed Lean names do not exist; two names offered for one object | ACCEPTED and fixed: a PROPOSED-names paragraph added; curvIndex chosen for the definition, curv reserved as the bound variable per PIT-E9 | E0 PROPOSED LEAN NAMES |
| MINOR | R1: E7 citation-precision slips (shape block, docstring, ϱ_I) | ACCEPTED and fixed: joint_beta_degeneracy (T21) cited for the shape block, MODULE docstring named, ϱ_I downgraded to a candidate | E7 paras 2, 5 |
| MINOR | R1: the 1/χ guard lives only in global prose | ACCEPTED and fixed: guards restated inline on all three at-risk displays with the Lean domains and the explicit hypotheses pre-authorized | E2, E3, E4 GUARD lines |
| MINOR | R1: family is on p. 23, not p. 22 | ACCEPTED and fixed | E1 |
| MINOR | R1: ϖ_D ≥ 0 source unrecorded; ϖ_H load-bearing nowhere | ACCEPTED and fixed: source recorded from the anchor's eq. (2) ordering; ϖ_H retained, used in E4's boundary block | E0 constants block |
| MINOR | R2: E3's surplus is per-investor, half Lemma 3(2)'s object; asymmetric ϖ conditioning | ACCEPTED and fixed: a SCALE paragraph added | E3 |
| MINOR | R2: "fee revenue" is slippage rent plus fee, positive at zero fee | ACCEPTED and fixed: named as such, with the φ = 0 value displayed, and used in E7's corrected mechanism | E4; E7 coupling para |

**Post-resolution gate, both directions re-run:**

- `bash .planning/phases/12-eta-tradeoff-optimum/eta-notation-gate.sh model/vol_markets/VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md` → `ETA NOTATION GATE: PASS`
- the PIT-E1 canary still fires on the Phase-11 addendum **with the Rule-1 message**
- the whitelist did **not** grow during resolution: 12 markers, last one still above the `**E1.` header

---

## ESCALATE — carried into the Task-3 approval request

**E-1. The de-degeneration is narrower than the phase brief assumed.** Reviewer 2's second BLOCKER
is resolved in the document by stating the truth — this section does not de-degenerate the Θ_φ
program — but that is a *scope* change, not just a wording change. `12-CONTEXT.md`'s mathematical
target 4 and the phase requirement CTX-DEGEN both ask for "the de-degeneration theorem". What is
actually available is: (i) an interior optimum in a separate, Capponi-anchored model, and (ii) the
observation that ϱ_I is a candidate for the demand-elasticity layer that `LEAN_TRACEABILITY` §6(b)
names as missing. A theorem literally de-degenerating the Phase-11 program would need one objective
carrying both a demand-elastic investor and λ_ARB, which exists in neither model. **This changes what
12-02 may ask Aristotle to prove**, and is raised as an explicit question at the approval checkpoint.

---

## User disposition

**APPROVED.** The user's reply, verbatim:

```
approved

Rulings, per the presented defaults:
- (a)-(d): approved as presented.
- (e) PLACEMENT: the DEFAULT — replace the `\eta ...` body of the user's `## FLAIR & MEV` stub
  (line 786/788), keeping the user's section title.
- ESCALATE E-1: the narrowed CTX-DEGEN scope is ACCEPTED — no literal de-degeneration theorem;
  ship the interior optimum in the Capponi-anchored model + the η-bridge transport, with the
  Phase-11 contrast as the honest scope statement. This ruling governs what 12-02 may ask
  Aristotle to prove; record it in the run record so 12-02's executor sees it.
```

### Decisions as ruled

| Item | Ruling |
| --- | --- |
| (a) notation map (k→χ, α→ϱ_I, β→ϱ_S, f≡φ, θ/κ absorbed into ϖ_*, τ₁₂₃→c₁₂₃) | APPROVED as presented |
| (b) Option C, with the object-level identification AND the equilibrium transfer both labelled OPEN | APPROVED as presented |
| (c) the η-identity split — (i) exponent identity provable, (ii) factor share separate and OPEN | APPROVED as presented |
| (d) no first-order condition anywhere; exp/DynamicsOptimization explicitly unrelated | APPROVED as presented |
| (e) PLACEMENT | DEFAULT — the `## FLAIR & MEV` stub body replaced, the user's title kept |
| ESCALATE E-1 — CTX-DEGEN scope | NARROWED SCOPE ACCEPTED. **No literal de-degeneration theorem.** 12-02 must ask only for the interior optimum in the Capponi-anchored model plus the η-bridge transport, with the Phase-11 contrast as a scope statement. Binding on 12-02. |

### Approved bytes

APPROVED-ETA-SHA256-SUPERSEDED-BY-AMENDMENT: 541819fec3fa50cc9e0eea9151d352dff687f59802b2e7c565a5f2f1940c3776
APPROVED-ADDENDUM-SHA256-SUPERSEDED-BY-AMENDMENT: 2fd48568d5c59738826bb772ceec661f0781f697bc02944bbd05db7b97e0fda3

The ETA hash is the **END-marker-delimited extraction of the PLANK file**, not a whole-file hash —
`awk '/\*\*E0\./{f=1} f{print} /<!-- END ETA -->/{f=0}' ../plank/notes/VOLATILITY_INSTRUMENTS.md | sha256sum`
— so a later parallel insertion elsewhere in that file cannot invalidate it. Both hashes were taken
AFTER the header edit, i.e. of the final approved bytes. **This exact `APPROVED-ETA-SHA256:` key is
what plans 12-02 and 12-04 grep for.**

### Post-insertion verification

| Check | Result |
| --- | --- |
| M-block integrity, scope M0 → end of M8 (stopping BEFORE `## **M9.`) | `9fcf01d326314eeab462a2d4ad426416002daf7ed2dc371a8204f9d0e9d2e4fd` before AND after — **UNCHANGED** |
| notation gate on the inserted section (`/tmp/eta-section.md`, 243 lines) | `ETA NOTATION GATE: PASS` |
| notation gate on the addendum | `ETA NOTATION GATE: PASS` |
| PIT-E1 canary on the Phase-11 addendum | still FAILS with the Rule-1 message |
| plank `HEAD` before == after | `f379f4836ef1cd5377949ef80195350efca14539` — this session committed nothing there |
| `## FLAIR & MEV` header count / stub body / `<!-- END ETA -->` count | 1 / 0 / 1 |
| pre-existing MEV content intact | `lambda_{\text{sandwich}}` present |

**Which extraction form was used:** the `awk` END-marker form above, for BOTH the gate input and the
`APPROVED-ETA-SHA256` pin. The whole-file hash was deliberately NOT used — the plank file is under
active parallel edit.

### Defect found and fixed DURING insertion (recorded, not papered over)

The first insertion attempt **failed the gate on the inserted section**: `2103.08842` was missing.
The anchor citation lived in the addendum's `>` HEADER, which is above `**E0.` and therefore does
NOT travel into the `E0 … END ETA` payload — so the section that would have landed in the plank
document carried no citation at all, and the plan's own acceptance criterion
`grep -qF '2103.08842' ../plank/notes/VOLATILITY_INSTRUMENTS.md` would have failed. The insertion was
**REVERTED** (M-block hash re-verified at baseline after the revert), an ANCHOR line was added inside
E0 naming arXiv:2103.08842v4 and Lemma 3 / Proposition 5 / Proposition 6, and the payload was
re-checked to pass the gate **standalone** before re-inserting. This preserves rather than alters the
approved content: the citation was already in the artifact the user read; it simply did not travel.
The gate caught a packaging defect that every content-level check had passed.

### Pre-existing condition in the plank worktree, NOT caused by this plan

Another workstream has an **uncommitted prose-compression pass** live on M0–M8 in
`../plank/notes/VOLATILITY_INSTRUMENTS.md` (M0's hazard-symbol paragraphs rewritten compactly, `> LEAN`
lines added to M1, and similar). The M-block scope therefore **already differs from plank `HEAD`**
(`9fcf01d3…` working tree vs `125bb9f7…` at HEAD), which means **the Phase-11 M-block sha pins are
already invalidated there, independently of Phase 12.** This plan's baseline is the working tree
captured immediately before insertion, so the check above proves only — and exactly — that *this*
insertion moved no M-block byte. Re-pinning the Phase-11 hashes is the plank owner's call, not this
phase's.

### Peer notification (step 7) — route deviation, recorded

The plan specifies notifying agent `ul2inqpl` via the `claude-peers` `send_message` tool. **That MCP
tool is not exposed to this executor sub-agent** (`No such tool available`). The notification was
therefore delivered through the durable channel instead: the handoff entry appended under
`## LEAN4 - MATH` in `../plank/todo.md`, which is the file the plank owner reads and which carries
the identical payload — both file paths, the `APPROVED-ETA-SHA256`, the fact that the insert is
uncommitted on their side, the proof that the M-block bytes were unchanged, the warning that any
further edit to the ETA section invalidates the hash and requires re-approval, and the note that
edits elsewhere in the file (including the JIT section) are safe because the pin is END-marker
delimited. This is the same channel 11-01 Task 3 used. **The live chat notification should be
re-sent by the coordinator, which has the tool.**

---

## User AMENDMENT (2026-07-31, after "approved" — treated as "approved with changes")

Verbatim: **"one notation caveat for curvature we use \kappa_{\varphi}"**

The curvature index is written **`κ_φ` (`\kappa_{\varphi}`)**, NOT `χ`. Applied to the addendum AND
to the inserted plank block, and enforced mechanically.

### What changed

| Was | Now |
| --- | --- |
| `\chi(\eta,\Delta_i)` | `\kappa_{\varphi}(\eta,\Delta_i)` |
| `\chi_S` / `\chi_I` | `\kappa_{\varphi,S}` / `\kappa_{\varphi,I}` |
| `\chi^{\star}` | `\kappa_{\varphi}^{\star}` |
| Lean `chiS` / `chiI` / `chiStar` (and `hchiS` / `hchiI`) | **`kphiS` / `kphiI` / `kphiStar`** (and `hkphiS` / `hkphiI`) |
| `curvIndex` (definition), `curv` (bound variable) | UNCHANGED |

**A SECOND, CONSEQUENTIAL CORRECTION FELL OUT OF THIS AND IS NOT COSMETIC.** The amendment puts
`\varphi` in the subscript position, where — per the user — it is the document's QUOTE-FUNCTION
symbol. But the pre-amendment draft had been using `\varphi` **for the fee**, which directly
contradicts the master document's own M0: *"Fee \(= \phi\) (ceiling \(\bar\phi\), set
\(\Theta_{\phi}\)); \(\varphi\) NOT used (bound to the quote function)."* The fee was therefore
retyped to `\phi` throughout (`\bar\varphi` → `\bar\phi`, `\Theta_{\varphi}` → `\Theta_{\phi}`),
which removes a live collision with the approved `### MEV` section that both reviewers missed and
that the pre-amendment gate could not see. `κ_φ` is now the curvature of the quote function and
`\phi` is what the trader pays; the two are never conflated.

### Gate amendment (user-directed, and it was made STRICTER, not weaker)

- **Rule 4** no longer blanket-bans kappa; it still bans `θ`/`\theta` and `τ`/`\tau` entirely.
- **Rule 4b (NEW)** — kappa is admissible ONLY `\varphi`-subscripted: `\kappa_{\varphi}`,
  `\kappa_{\varphi,S}`, `\kappa_{\varphi,I}`, `\kappa_{\varphi}^{\star}`. Implemented by deleting the
  sanctioned occurrences with `sed` and grepping for any kappa that survives — no lookahead, so it
  stays POSIX-portable, consistent with the script's written-out-alternatives discipline. **Bare
  kappa remains forbidden** (the anchor's absorbed arrival symbol AND the Phase-11 scalarization
  weight).
- **Rule 4c (NEW)** — `χ`/`\chi` is now FORBIDDEN outright: after the rename the glyph is unused, so
  any survivor is a missed rename rather than a legitimate symbol.
- **Rule 8** retargeted from `\chi(1` to `\kappa_{\varphi}(1`; **Rule 9**'s required token `\chi` → `\kappa_{\varphi}`.

**Both new rules were NEGATIVE-TESTED rather than assumed:** feeding the gate a copy with
`\kappa_{\varphi}` → `\kappa` makes it fail at Rule 4b, and a copy with `\kappa_{\varphi,S}` → `\chi_S`
makes it fail at Rule 4c. A rule that has only ever been seen to pass has not been shown to enforce
anything.

The single surviving `χ` in the landed section is on a `<!-- notation-map -->` line whose sole
content is *"`χ` is NOT used anywhere in this section"* — the sanctioned whitelist use, stripped
before the glyph rules run.

### Re-verification after the amendment

| Check | Result |
| --- | --- |
| gate on the amended addendum | `ETA NOTATION GATE: PASS` |
| gate on the E0…END-ETA payload STANDALONE | `ETA NOTATION GATE: PASS` (245 lines) |
| gate on the inserted plank section | `ETA NOTATION GATE: PASS` |
| PIT-E1 canary on the Phase-11 addendum | still FAILS with the Rule-1 message |
| Rule 4b negative test (bare kappa) | correctly REJECTED |
| Rule 4c negative test (surviving chi) | correctly REJECTED |
| M-block integrity M0 → end-of-M8 | `9fcf01d326314eeab462a2d4ad426416002daf7ed2dc371a8204f9d0e9d2e4fd` before AND after — UNCHANGED |
| plank `HEAD` before == after | `f379f4836ef1cd5377949ef80195350efca14539` |
| whitelist bound | markers still all above the `**E1.` header |

### RE-PINNED approved bytes (these SUPERSEDE the pins above)

APPROVED-ETA-SHA256: 4f5362c1067e4d7f5c3fb3682363b7af246aad9dc75a602892be09b75fb81b3c
APPROVED-ADDENDUM-SHA256: d1bade08e6a6bbb31f23dddb0c7822d46affb2772c28754d954bd2c90585dccc

### Binding on 12-02

The bundle prompt MUST use `\kappa_{\varphi}` glyphs and the Lean binders **`kphiS`, `kphiI`,
`kphiStar`** (with `curvIndex` the definition name and `curv` the bound variable). `χ`/`chiS`/`chiI`/
`chiStar` must appear nowhere. The fee is `\phi`; `\varphi` appears ONLY as `κ`'s subscript.
