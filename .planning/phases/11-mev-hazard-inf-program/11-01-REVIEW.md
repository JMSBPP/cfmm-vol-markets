# 11-01 — Two-reviewer gate on `VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md`

**Artifact under review:** `model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md`
(as authored by Task 1, commit `265b937`).
**Date:** 2026-07-30.
**Anchor consulted by both reviewers:** `/tmp/mmr.txt`, produced by
`pdftotext -layout ../plank/refs/mev/MilionisMoallemiRoughgardenArbProfitsFees.pdf`
(arXiv:2305.14604v2). Both reviewers were instructed to verify transcriptions against the PAPER,
not against `11-RESEARCH.md`.

**Execution:** both reviewers ran **IN PARALLEL** as two independent read-only processes launched
from a single shell invocation (`claude -p ... --allowedTools Read Grep Glob`, backgrounded, then
`wait`ed). Neither had write tools; neither edited the artifact. Both returned severity-sorted
BLOCKER / MAJOR / MINOR findings.

> **Note on verbatim reproduction:** the reviewer transcripts below are reproduced as returned,
> with ONE mechanical alteration: absolute filesystem paths were rewritten to repo-relative form,
> because this plan's own acceptance gate forbids absolute paths in planning artifacts. No finding
> text, severity, or evidence reference was otherwise changed.

---

## Reviewer 1 — Reality Checker

Mandatory first reviewer per the binding two-step reviewer process. Brief: NEEDS-WORK-by-default,
evidence-based; charged specifically with (a) verifying every transcribed formula against
`/tmp/mmr.txt` rather than the research summary, (b) flagging claims asserted without a theorem
number, (c) flagging any promised trade-off over the fee parameter set without a constraint in the
same sentence, (d) flagging escaped numeric Angstrom constants, (e) checking that the arbitrage
hazard and the aggregate are never used interchangeably and that the aggregate is defined exactly
once.

### Verdict

**NEEDS WORK** — the transcribed MMR formulas are arithmetically faithful, but the fee glyph
collides with a symbol already bound in the parent document, and M6a asserts an argsup/arginf
identity that the document's own M5 (and the parent's FLAIR block) prove is unattained — exactly
the kind of over-claim that becomes a vacuous or false Lean theorem.

### BLOCKER

**R1-B1. Fee glyph `\varphi` collides with the parent document's `\varphi`, and mismatches the
parent's actual fee symbol `\phi`.** The addendum wrote the fee as `\varphi(\sigma_t)`, the
parameter set as `\Theta_{\varphi}`, and the ceiling as `\bar\varphi`. But this is an addendum to
`../plank/notes/VOLATILITY_INSTRUMENTS.md`, where the fee is `\phi(\sigma(i(t));t)` and the
parameter set is `\Theta_{\phi}` (parent lines 353, 361), and where **`\varphi` is already a
different object** — the quote function
`\varphi(i_K; ΔQ, L) = (ΔQ_M^L+ΔQ_M)^{1/2}(ΔQ_X^L+ΔQ_X)^{1/2}` that feeds the sigmoid ratio
`x = \varphi(i_K;ΔQ,0;t)/\varphi(i_K;0,L;t)` (parent lines 305, 353, 364). The addendum even mixed
the two glyphs itself: `\otimes_\phi` in M7 vs `\Theta_{\varphi}` everywhere else. Inserted
verbatim, this binds one glyph to two objects and two glyphs to one object; Aristotle treats
`\phi` and `\varphi` as distinct identifiers. M0's own rule ("the paper's fee `γ` is this
document's `φ`") is violated in spirit: "this document's" fee is `\phi`. **Fix:** replace every
fee-`\varphi` with `\phi` (`\bar\phi`, `\Theta_{\phi}`), leaving `\varphi` to its parent-document
meaning.

**R1-B2. M6a's central display `argsup_{Θ_φ} λ_FLAIR = arginf_{Θ_φ} λ_ARB` is ill-posed — both
arg-sets are empty by the document's own admissions.** M5 said the bound is "approached as
β_j → −∞, strict at every finite β"; the parent's proven FLAIR result says the sup "is a
saturation boundary, not a maximum" (parent lines 456–457, `flairMulti_saturation_limit`,
`flairMulti_strict_below_saturation`). Over unbounded β, neither extremum is attained, so
`argsup = arginf` is at best vacuously `∅ = ∅`; and the follow-on prose "the point maximizing
λ_FLAIR − κλ_ARB is that same point" asserts a point that does not exist. Formalized as stated,
this yields either a vacuous machine-checked theorem or an unprovable one. **Fix:** restate the
degeneracy as two well-posed claims: (i) for every fixed shape block, the level-block argmax of
λ_FLAIR and the level-block argmin of λ_ARB coincide at the corner top; (ii) both objectives
saturate in the same direction β → −∞ (common extremizing sequence).

### MAJOR

**R1-M1. λ_MEV is defined twice, contradicting the exactly-once rule.** M0 wrote
`λ_MEV \coloneqq λ_ARB ⊕ λ_sandwich` — a definitional symbol — in the same sentence that claimed
it is "defined once, in M7"; M7 then defined it again with `\coloneqq`. **Fix:** M0 should
forward-reference without defining.

**R1-M2. M6b's bold claim leaks the aggregate into an ARB-only block.** M0 states "blocks M3–M6b
are statements about λ_ARB alone," yet M6b's bold sentence ended "…strictly worse for **MEV**"
with no M7-reduction qualifier — unlike M4 and M6a, which both invoke the reduction explicitly.
Without the reduction, "worse for MEV" additionally presumes λ_sandwich is fee-schedule-invariant,
which is not modelled. **Fix:** "strictly worse for λ_ARB" (optionally appending "hence for λ_MEV
under M7's reduction").

**R1-M3. Eq. (27) transcription drops "delta-hedged," producing an identity the paper does not
state.** M8 quoted `E[LP P&L] = E[NT_FEE] − E[ARB]`. The paper:
`LP P&L_N = R_N + NT_FEE_N − ARB_N` (`/tmp/mmr.txt:1475`) and
`E[delta-hedged LP P&L_N] = E[NT_FEE_N] − E[ARB_N]` (27) (`/tmp/mmr.txt:1482`). The unhedged
expectation carries the rebalancing term R_N; the addendum's version is a lookalike, not the
paper's equation. **Fix:** restore "delta-hedged" inside the quoted identity.

**R1-M4. Standing hypotheses of the transcribed results are not recorded.** P_trade's closed form
rests on Assumption 2 — driftless mispricing and a symmetric fee (`/tmp/mmr.txt:548–551`) — and
Theorems 3/4 carry the growth conditions (13)/(15) (`/tmp/mmr.txt:915–920, 946–949`). None
appeared in M0, M1, M2, or M8. A prover-bound spec must carry its hypotheses with its formulas.
**Fix:** record Assumption 2 (noting the paper's Appendix C non-symmetric variant) and the
Theorem 3/4 regularity conditions.

**R1-M5. M3's per-step application of the stationary P_trade to a time-varying path is an
addendum-original hypothesis, not MMR — and it is missing from the caveats.** The paper's P_trade
is a steady-state quantity for constant parameters (`/tmp/mmr.txt:636–642`); M3 sums
`P_trade(φ(σ_t), σ_t, Δt)` over a σ_t-varying path. M8 listed leading-order and no-elasticity
caveats but not this quasi-static extension. **Fix:** add it to M8 as an explicit modelling
hypothesis.

**R1-M6. The nesting λ_ARB ⊂ λ_MEV contradicts the parent's hazard index set.** Parent line 398
decomposes the total as `λ ≡ ⊕ λ_i, i ∈ {lp-competition (FLAIR), arb toxicity, MEV, TBD, …}` —
"arb toxicity" and "MEV" are *sibling* channels. The addendum makes the arbitrage channel a
*component of* λ_MEV. If λ_ARB is the parent's "arb toxicity," the parent's decomposition now
double-counts it. **Fix:** state that "arb toxicity" is absorbed as λ_ARB ⊂ λ_MEV, or state
explicitly that λ_ARB is distinct from the parent's arb-toxicity channel.

**R1-M7. M5's attainment sentence conflates two different attainment claims.** At any *finite* β
the fee cap is not reached (sigmoid < 1, parent line 368), so the *displayed RHS* is attained
nowhere — what the level corner attains is the inf *over the level block* at a strictly larger
value. The parent states this correctly in three separated clauses (parent lines 451–457). As
written, Aristotle may formalize `∃θ: λ_ARB(θ) = RHS`, which is false. **Fix:** split into (i)
level-block inf attained at the corner for fixed shape, (ii) displayed bound approached only as
β → −∞ with a strict gap at every finite β, (iii) minimizer on a compact box exists but its value
strictly exceeds the displayed bound.

### MINOR

**R1-m1.** M1's citation is loose. The P_trade formula is the unnumbered display *following*
Theorem 1 (`/tmp/mmr.txt:636–639`), derived from Theorem 1's stationary distribution; cite as
"from Theorem 1's stationary distribution (§4.1)". Content otherwise verbatim-faithful.

**R1-m2.** M4's heading names the aggregate. "Identification Θ_{λ_MEV}" headed a block whose
result is on λ_ARB; retitling to `Θ_{λ_ARB}` removes the last place a reader (or prover
prompt-slicer) sees the aggregate attached to an M3–M6b result.

**R1-m3.** M7(i): the no-minimizer-motion claim fails at τ = 1. With `τ ∈ [0,1]`, τ = 1 gives
`λ_MEV^net ≡ 0` and every point is a minimizer. State `τ ∈ [0,1)` for that sentence.

**R1-m4.** M6b's equality-iff needs strictly positive weights. With some `w_t = 0`, equality holds
while φ varies on zero-weight steps. State "constant on {t : w_t > 0}".

**R1-m5.** M6b silently uses the identity `λ_FLAIR = Σ_t ν_t φ(σ_t)`. It holds by the parent's
discrete FLAIR display (parent line 443), but the addendum — sent verbatim to the prover — never
stated it. Add it to M6b's hypothesis line.

**R1-m6.** M7's algebra attribution is imprecise. `⊗_φ` is the *fee/probability-side* monoid on
[0,1]; hazards combine by `⊕` (= addition) under `φ = 1 − e^{−λ}`. Should read "on the ⊕ (hazard)
side of the ⊗_φ algebra".

### Reviewer 1 evidence log (condensed)

- Addendum read in full (169 lines at review time).
- `/tmp/mmr.txt`: Assumption 2 at :548–551; Theorem 1 at :561; P_trade
  `≜ π+ + π− = 1/(1+√(2λ)γ/σ)` at :639 — arithmetically equals the addendum's
  `σ/(σ+φ√(2/Δt))` via `λ = Δt⁻¹` ✓; bonding-function independence at :643–644 ✓;
  Corollary 2 at :812–823 with `σ²/8 < λ ⟺ σ²Δt < 8` ✓ matches M3(ii) exactly; eq. (12) at :897;
  Theorem 3 + condition (13) at :909–920; Theorem 4 + condition (15) at :936–949;
  `LVR = σ²/8 × V(P)` at :884–886; LP P&L decomposition at :1475; eq. (27) **delta-hedged** at
  :1482; monopolist-LP fee trade-off quote at :1491–1493; §7.1 block-time lever at :1341–1343.
- Glyph audit: bare `γ/λ/η` confined to marker-tagged lines ✓; all `\lambda` subscripted ✓; the
  forbidden composite written out only on a whitelisted line ✓.
- Parent doc: `\varphi` quote function at :305, :353, :364; fee `\phi` and `\Theta_\phi` at :353,
  :361; hazard index set at :398; `⊗_φ`/`⊕` correspondence at :405–413; discrete λ_FLAIR at :443;
  "saturation boundary, not a maximum" at :451–457.
- Independent calculus: `d²/dφ² [σ/(σ+cφ)] = 2σc²/(σ+cφ)³ > 0` ✓; `τ(49) = 49/50 = 0.98` ✓
  confined to a dated worked instance — no escaped constants found in any claim.

---

## Reviewer 2 — Model QA Specialist

**Specialist pick and reason.** The plan directs the second reviewer to be the closest AI-agency
specialist to **quantitative finance / market microstructure**, because (per 11-RESEARCH PIT-7)
the risk in this artifact is economic misstatement of ARB/LVR and of what the Angstrom mechanism
does, not LaTeX syntax. The agency catalog has no dedicated quant-finance or microstructure agent;
the closest available specialist is the **Model QA Specialist**
(`agents/specialized/specialized-model-qa.md`), and it was **chosen because** its remit is exactly
independent, adversarial audit of statistical and mathematical *models* — documentation-vs-
methodology consistency, replication of stated results, challenge of load-bearing assumptions,
calibration and interpretability — with explicit finance-domain audit experience, and it operates
under a "guilty until proven sound" posture. Candidates rejected: `blockchain-security-auditor`
(smart-contract exploit surface, not model economics — no Solidity exists in this artifact) and
the engineering/testing agents (code quality, not economic semantics).

### Verdict

**NEEDS WORK** — the MMR transcription (M1–M3, M5, M6a, M8) is faithful and unusually honest, but
M6b's bolded economic claim is not supported by the displayed theorem (it is vacuous for the
schedule class the document actually optimizes over), and the weight `a_t` has a dimensional
inconsistency that breaks the advertised FLAIR-commensurability and misstates the Δt lever.

### BLOCKER

**R2-B1. M6b's economic reading is unsupported by its own display — for σ-driven fee schedules at
constant σ, the inequality is an identity and the "strictly worse" clause never bites.**

- *The issue.* The fee schedule throughout this project is a deterministic function of
  instantaneous volatility: `φ(σ_t) = multiFee(n,γ,β,α,φ̄,u)` evaluated at `σ_t` (addendum M3;
  `lean/vol_markets/FlairOptimization.lean:31-33`). M6b was stated at constant `σ_t ≡ σ_0`. But at
  constant σ, **every** volatility-responsive schedule produces a *constant* fee path —
  `φ(σ_t) = φ(σ_0)` for all t. The equality condition "φ(σ_t) constant in t" is then automatically
  satisfied by the entire admissible class, so the bound holds *identically*, and the strict half
  (which the document said "consumes M1's STRICT convexity") never operates. There does not exist
  a single volatility-responsive schedule in the stated regime that is "strictly worse" — because
  there does not exist one that is non-flat.
- *Why it matters economically.* The bolded takeaway is exactly the sentence a protocol designer
  will act on ("don't use dynamic fees, they increase MEV at fixed income"). That comparison only
  has content when σ actually varies — which is precisely the regime the document itself labels
  **OPEN**. As written, the document claims in bold the conclusion of the open problem.
- *Remediation.* Restate M6b as quantifying over **arbitrary time-varying fee paths** `{φ_t}` with
  income B (that statement is true and non-vacuous, and does consume strict convexity), and
  re-word the economic reading so that the schedule comparison moves into the OPEN item.

**R2-B2. Dimensional inconsistency in `a_t`: it is a per-unit-time *rate*, summed as if it were a
per-step *amount* — breaking the claimed commensurability with λ_FLAIR and misstating the Δt
lever.**

- *The issue.* M0 defined `a_t` as "the per-step arbitrage-opportunity weight", and M3(i)
  instantiated `a_t = (σ_t²/8)V_t`. But `(σ²/8)V` is the LVR **rate per unit time**
  (`/tmp/mmr.txt:882–884`: `LVR ≜ lim E[LVR_T]/T = (σ²/8)V(P)`). The per-block LVR is
  `(σ_t²/8)V_t·Δt`. Meanwhile the FLAIR summand uses `w_t` = per-step traded **volume**
  (`FlairOptimization.lean:14-16`) — a per-step amount. So λ_FLAIR summed value ratios while
  λ_ARB summed rate ratios: M0's commensurability claim was false as written, and M6b's aligned
  hypothesis `a ≡ w` equated a rate to a volume.
- *Why it matters economically.* M7(ii) advertises the batch cadence Δt as "the second, genuinely
  non-degenerate lever". With the missing Δt weight, λ_ARB's Δt-sensitivity comes through P_trade
  alone, i.e. ∝ √Δt. The true per-block arbitrage loss scales as **Δt^{3/2}**
  (`/tmp/mmr.txt:1344–1346`: "arbitrage profits per unit time scale according to Δt^{1/2}, while
  arbitrage profits per block scale according to Δt^{3/2}"). Adding the Δt weight reproduces MMR
  exactly; omitting it understates the cadence lever by a full factor of Δt. None of the
  monotonicity/corner results in M4–M6a are affected (the error is a positive per-t rescaling),
  which is why this is fixable rather than fatal.
- *Remediation.* Define `a_t ≜ (σ_t²/8)V_t·Δt` — one symbol change — and verify the corrected
  per-block summand scales Δt^{3/2}.

### MAJOR

**R2-M1. The (1−τ) rebate is framed as reducing the MEV *hazard*; economically it changes who
receives the value, not the extraction intensity.** The top-of-block auction does not prevent the
arbitrage — it *guarantees* it happens (the ToB winner executes it) and routes the winning bid to
LPs. Extraction intensity and P_trade are unchanged; only the incidence of the loss moves. Calling
`(1−τ)λ_MEV` "λ_MEV^net" invites the reading "Angstrom reduces MEV by 98%", which is wrong. As an
LP-incidence functional — the natural analogue of the `E[ARB]` term in eq. (27) — it is right.
**Remediation:** rename to an LP-incidence/net-LP-loss object and state that τ redistributes
extracted value without reducing extraction intensity.

**R2-M2. The searcher-bid mechanism behind τ(k) = k/(k+1) is undisclosed.** The map delivers a
fraction of *MEV* only under (a) searchers expressing their entire bid through the priority fee,
and (b) competition driving total payment to the full arbitrage value under honest priority
ordering. Neither appeared in M7; a monopolist searcher pays ≈ 0 while extracting fully, making
effective τ ≈ 0 at any k. The document was careful about the *numeric* k but silent on the
*structural* assumption. **Remediation:** disclose both assumptions in M7(i).

**R2-M3. The aligned-measure hypothesis `a ≡ w` is disclosed but its restrictiveness is not.**
It forces the traded-volume path (noise + arb flow) to be proportional block-by-block to the
leading-order LVR path — a knife-edge condition that fails whenever noise-trader volume has its
own dynamics (the normal case; it is the content of MMR §7.3). Without alignment the two sides
live under different measures, Jensen does not apply, and the flat-fee conclusion can reverse.
**Remediation:** add a sentence on when it plausibly holds and what breaks without it.

**R2-M4. λ_MEV is declared "the TOTAL" but the decomposition is ARB ⊕ sandwich only.** Omitted:
(i) backruns of noise-trader flow (`/tmp/mmr.txt:1406–1409, 1453–1454`); (ii) multi-block MEV —
MMR §7.1 (`:1373–1378`) models censoring agents who lengthen effective Δt, an attack that directly
targets the document's own Δt lever; (iii) JIT liquidity — the live l2 docs the document cites
carry a `jitMEVTaxFactor`, so the protocol taxes a channel the model does not contain; (iv) fixed
gas fees — MMR §6 shows gas acts as an additive fee changing P_trade. Omission is a legitimate
scoping choice; calling the scoped object "the TOTAL" is not. **Remediation:** rename and list the
omitted channels in M8.

**R2-M5. The Angstrom/l2 bridge sits partly in the regime where MMR's own model is empirically
known to break.** MMR §7.1 (`:1349–1365`) reports the Fritsch–Canidio validation: the √Δt decay
law holds for block times above roughly 1s, but below that "arbitrage profits appear to decline
more slowly than the theoretical model would suggest", because real prices jump. The document's
worked instance is l2-angstrom — an L2 where cadences at or below 1–2s are the operating point.
M8's LEADING ORDER caveat covers the asymptotics but not this empirical validity boundary.
**Remediation:** add the boundary to M8.

### MINOR

**R2-m1.** M6a's `argsup = arginf` uses an unattained supremum — abuse of notation the prover will
not accept. (Independently duplicates R1-B2.)

**R2-m2.** M1 attributes P_trade to Theorem 1 without noting Theorem 1 is stated under Assumption
2 (`/tmp/mmr.txt:548–556`). Disclosure, not error, but a formalization-bound spec should carry the
hypothesis. (Duplicates R1-M4.)

**R2-m3.** M4's "isotone in each β_j" needs the side condition **γ_j > 0**; the companion Lean
theorem `flairMulti_anti_beta` carries exactly this hypothesis. Without it the direction flips.

**R2-m4.** M7 placed the hazard sum "in this document's own ⊗_φ hazard algebra", but ⊗_φ operates
on probabilities in [0,1] while λ_ARB is an unbounded value-per-capital sum — a type mismatch. ⊕
is never defined in the addendum. Define ⊕ explicitly as addition or drop the algebra reference.
(Overlaps R1-m6.)

### Reviewer 2 closing assessment (verbatim)

> Net assessment: the transcription discipline (notation gate, exact-kernel guard, OPEN labels,
> refutation-not-suppression in M6a, the eq-(27) elasticity caveat) is well above the usual
> standard for this kind of artifact. The two blockers are both repairable with localized edits —
> B1 by re-quantifying M6b over fee *paths* and moving the schedule comparison into the OPEN item,
> B2 by a one-symbol redefinition of `a_t` — but neither should survive into user approval or Lean
> formalization as written, because both sit exactly where a practitioner or the prover would
> consume the wrong statement.

---

## Independent verification performed before acting

Executor did not take reviewer claims on trust. The three load-bearing, source-dependent findings
were re-checked against the primary sources directly:

| Finding | Check run | Result |
|---|---|---|
| R2-B2 (LVR is a rate) | `sed -n '878,900p' /tmp/mmr.txt` | CONFIRMED — `LVR ≜ lim_{T→0} E[LVR_T]/T = (σ²/8)×V(P)`, explicitly per unit time |
| R2-B2 (Δt^{3/2} per block) | `sed -n '1340,1350p' /tmp/mmr.txt` | CONFIRMED — "arbitrage profits per unit time scale according to ∆t^{1/2}, while arbitrage profits per block scale according to ∆t^{3/2}" |
| R1-M3 (delta-hedged) | `sed -n '1470,1495p' /tmp/mmr.txt` | CONFIRMED — `LP P&L_N = R_N + NT_FEE_N − ARB_N`, and (27) is `E[delta-hedged LP P&L_N] = E[NT_FEE_N] − E[ARB_N]` |
| R1-B1 (glyph collision) | `grep -n 'varphi' ../plank/notes/VOLATILITY_INSTRUMENTS.md` | CONFIRMED — parent :305 binds `\varphi` to the quote function; :353/:361 use `\phi`, `\bar\phi`, `\Theta_{\phi}` for the fee |
| R1-M4 (Assumption 2) | `sed -n '546,560p' /tmp/mmr.txt` | CONFIRMED — Assumption 2 (Symmetry), called WLOG with the non-symmetric variant in Appendix C |

**Source-conflict adjudication.** R2-B1 sharpens `11-RESEARCH.md` F6, which asserted that "every
volatility-responsive sigmoid schedule delivering the same fee income is strictly worse for MEV".
Reviewer 2 showed that within the project's own schedule class this is vacuous at constant σ,
because `multiFee` depends on `σ` alone (`FlairOptimization.lean:31-33`, verified by executor).
**The reviewer's reading wins over the research summary**; the paper is silent (this concerns the
project's functional, not MMR's). The addendum now states the true path-level claim and moves the
schedule-level comparison into the OPEN item.

---

## Resolution

All 4 BLOCKERs and all 12 MAJORs are resolved by edits to the addendum. MINORs were also all
applied (each was a one-clause fidelity improvement with no cost). The notation gate was re-run
after the edits and passes; the whitelist did not grow (6 markers, all before the `**M1.` header).

| Severity | Finding | Disposition | Where fixed |
|---|---|---|---|
| BLOCKER | R1-B1 fee glyph `\varphi` collides with parent's quote function; parent's fee is `\phi` | FIXED — every fee-`\varphi` replaced by `\phi`/`\bar\phi`/`\Theta_{\phi}`; an explicit disclaimer added naming the collision | M0 notation para; M1, M3, M4, M5, M6a, M6b, M7 displays |
| BLOCKER | R1-B2 `argsup = arginf` ill-posed (arg-sets empty over unbounded shape block) | FIXED — restated as three well-posed claims: fixed-shape level-corner coincidence, common saturating direction, scalarization robustness | M6a (i)(ii)(iii) |
| BLOCKER | R2-B1 M6b bold claim vacuous for the schedule class at constant sigma | FIXED — claim re-quantified over arbitrary fee PATHS; schedule-level comparison moved into the OPEN note with the vacuity reason stated | M6b header line, bold sentence, OPEN para |
| BLOCKER | R2-B2 `a_t` is a rate summed as an amount; breaks commensurability and the cadence lever | FIXED — `a_t = (sigma_t^2/8) V_t Delta t` with the Delta t^{3/2} consistency check recorded against MMR section 7.1 | M0 weight defn; M3(i) display and note |
| MAJOR | R1-M1 aggregate defined twice (M0 used `\coloneqq`) | FIXED — M0 now forward-references only; the single definition is in M7 | M0, M7 |
| MAJOR | R1-M2 M6b leaked "worse for MEV" into an ARB-only block | FIXED — reads "strictly worse for lambda_ARB (hence for lambda_MEV under M7's reduction)" | M6b bold sentence |
| MAJOR | R1-M3 eq. (27) dropped "delta-hedged" | FIXED — delta-hedged form restored and the unhedged rebalancing term noted | M8 bullet 3 |
| MAJOR | R1-M4 standing hypotheses (Assumption 2, conditions (13)/(15)) unrecorded | FIXED — Assumption 2 recorded with the Appendix C note; regularity conditions attached to M2 | M0 final para; M1 citation line; M2 |
| MAJOR | R1-M5 quasi-static use of a steady-state P_trade uncaveated | FIXED — added as an explicit modelling hypothesis of this document, not the paper | M8 bullet 2 |
| MAJOR | R1-M6 nesting contradicts the parent's sibling hazard index set | FIXED — states lambda_ARB ABSORBS the "arb toxicity" entry and warns the index set must not carry both | M0 |
| MAJOR | R1-M7 M5 conflated two attainment claims | FIXED — split into three numbered clauses; the displayed bound is explicitly a boundary value, not a minimum | M5 (i)(ii)(iii) |
| MAJOR | R2-M1 rebate framed as reducing intensity rather than incidence | FIXED — renamed to an LP-incidence object; states tau redistributes and leaves extraction intensity invariant | M7(i) |
| MAJOR | R2-M2 searcher-bid structural assumption undisclosed | FIXED — both assumptions disclosed, with the monopoly/collusion failure mode named | M7(i) |
| MAJOR | R2-M3 restrictiveness of `a == w` undisclosed | FIXED — added a paragraph naming what it forces and that the conclusion can reverse without it | M6b |
| MAJOR | R2-M4 "the TOTAL" overstates a two-channel aggregate | FIXED — renamed "aggregate over the two channels modelled here"; the four omitted channels listed | M0, M7 heading, M8 bullet 4 |
| MAJOR | R2-M5 sub-second empirical validity boundary unrecorded | FIXED — added the roughly-1s validity boundary and the jump-diffusion scope exclusion | M8 bullet 5 |
| MINOR | R1-m1 loose Theorem 1 citation for P_trade | ACCEPTED AND APPLIED — cites "Theorem 1's stationary distribution, section 4.1" | M1 |
| MINOR | R1-m2 M4 heading named the aggregate | ACCEPTED AND APPLIED — heading retitled to the ARB identification; the aggregate appears only in the reduction sentence | M4 heading |
| MINOR | R1-m3 minimizer-invariance fails at tau = 1 | ACCEPTED AND APPLIED — restricted to tau in [0,1) with the degenerate case named | M7(i) |
| MINOR | R1-m4 equality-iff needs positive weights | ACCEPTED AND APPLIED — "constant on the positive-weight steps" | M6b display and prose |
| MINOR | R1-m5 M6b used the FLAIR discrete identity without stating it | ACCEPTED AND APPLIED — the budget identity is now written out in the hypothesis line | M6b |
| MINOR | R1-m6 imprecise `⊗_φ` attribution | ACCEPTED AND APPLIED — merged with R2-m4 fix | M7 |
| MINOR | R2-m1 duplicate of R1-B2 | ACCEPTED AND APPLIED — resolved by the R1-B2 fix | M6a |
| MINOR | R2-m2 duplicate of R1-M4 | ACCEPTED AND APPLIED — resolved by the R1-M4 fix | M0, M1 |
| MINOR | R2-m3 isotone-in-beta needs the positive-slope side condition | ACCEPTED AND APPLIED — "For positive sigmoid slopes gamma_j > 0" opens the block | M4 |
| MINOR | R2-m4 `⊗_φ` type mismatch; `⊕` never defined | ACCEPTED AND APPLIED — `⊕` defined as hazard-side addition, with the [0,1] monoid explicitly not applied to unbounded hazards | M7 |

**Unresolved BLOCKER/MAJOR: none. ESCALATE rows: none** — no finding required a user adjudication
to resolve; every one had a determinate fix against the paper, the parent document, or the
project's own Lean layer.

### Post-resolution gate state

- `bash .planning/phases/11-mev-hazard-inf-program/mev-notation-gate.sh model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` → `MEV NOTATION GATE: PASS`
- Whitelist unchanged at 6 markers, last marker line 16, `**M1.` header line 34 (16 < 34) ✓
- Gate caught two REAL violations during authoring and resolution (a bare hazard glyph in M0's
  root-block-rate sentence, and two bare hazard glyphs in M7's algebra sentence). Both were fixed
  in the ADDENDUM. **The gate was never weakened and no marker was added outside the header/M0.**
- `git status --porcelain lean/` empty across every commit of this plan ✓
- Nothing written to the plank worktree ✓

### Notation rule adopted from this gate (standing)

R1-B1 generalizes into a binding rule for every future doc/prover artifact in this track:
**the USER's / the document's own notation is always preserved; a conflicting EXTERNAL symbol gets
a NEW symbol, never the document's; and every such remap is recorded in the marker-whitelisted
notation-map paragraph.** This is the mechanism that turned three known collisions into a script,
and R1-B1 was the fourth collision the script could not see because it was a same-concept /
different-glyph clash rather than a forbidden glyph.
