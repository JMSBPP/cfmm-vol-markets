# Project Research Summary

**Project:** MEV-Tax Set-Point Controller — Verified Design Spec
**Domain:** Verified control-theoretic design specification (Lean 4 / Aristotle machine proof + EVM-feasibility analysis; no implementation)
**Researched:** 2026-08-08
**Confidence:** MEDIUM (high on structural/architectural facts read directly off disk; medium-high on the mathematical refutation findings, most cross-checked by 2+ researchers; low-medium on several literature citations the FRAME researcher could not independently verify)

> **Re-aimed dimensions.** This project's four research dimensions are not GSD's stock set. `FRAME.md` replaces "Stack" (control-theoretic basis, not libraries). `CLAIMS.md` replaces "Features" (proof obligations P1–P4, not product features). `ARCHITECTURE.md` and `PITFALLS.md` are standard. Section headings below are adapted accordingly.

---

## Executive Summary

Four researchers independently examined the same boxed closed form for `τ*_MEV` and its four supporting claims (P1 well-posedness, P2 the 5-factor channel, P3 the sign `Ḡ_(ν,λ_MEV) > 0`, P4 the closed form itself). **All four converge, by different routes, that the derivation as currently written is very likely to fail formal verification** — and per this project's own Core Value (`PROJECT.md`), that is a successful outcome, not a setback. The strongest convergent finding: the P2 "no other path" clause (the claim that `τ_MEV` reaches `π̂^σ` through exactly one channel) is refuted independently by **FRAME** (Mason's gain-formula analysis: the source's own `∇φ` display exhibits ≥2 forward paths), **CLAIMS** (a conditioning contradiction between the boxed objective `|_{λ_MEV}` and the boxed channel, plus the direct monoid path via Rule 12), and **PITFALLS** (four distinct counter-routes read line-by-line from the source), with **ARCHITECTURE** independently corroborating via the source's own additive `∂π^σ` expansion. That is 4 of 4 researchers, at least 3 independent methods.

The recommended frame (FRAME.md) is **static plant inversion / exact feedforward on an event-indexed jump chain**, formalized via controlled-variable selection (Skogestad, self-optimizing control) and discharged with the Implicit Function Theorem + IVT + strict monotonicity — explicitly *not* LQR/LQG/Riccati machinery, which solves for a gain over a horizon, not a value at an operating point. Under this frame, the apparent 1-actuator/2-output underactuation dissolves: `π^σ` is a measured disturbance, not a controlled output, and the true controlled variable is the scalar `c = Hy`, `H = [1,−1]`. PITFALLS reaches structurally the same underlying fact (`π^σ` does not depend on `τ_MEV`) but treats it more cautiously, as one symptom in a cluster suggesting the state-space realization may have `∂_(t+1,t) = 0` (a memoryless map wearing MIMO dress) — a tension in register, not in fact, that the roadmap should resolve explicitly in Phase A.

The architecture is a four-layer pipeline spanning three git worktrees, of which this project owns only the first two (source math + spec layer); every proof submission, Lean landing, and entry-point-doc edit crosses into peer-owned territory (Lean4+Math session, Plank owner `ul2inqpl`). The pitfalls research identifies seven BLOCKER-severity defects in the current derivation (a wrong target equation, the falsified "no other path" clause, a substituted/sign-inconsistent gain, an implicit fixed-point equation, an invalid differentiation step, a channel that is provably zero under the entry-point doc's own Rule 9, and three unacknowledged non-differentiabilities), plus a corrected misquotation already flagged in `PROJECT.md` itself and independently confirmed by two of the four researchers. Four notation collisions block all formalization work until a user rules on them — this is the single highest-leverage, lowest-cost gate identified across all four documents, and it is unanimous.

---

## Key Findings

### Recommended Frame (from FRAME.md)

**Verdict:** Frame the problem as *static plant inversion at an operating point*, in the language of controlled-variable selection / self-optimizing control (Skogestad 2000; Jäschke, Cao & Kariwala 2017; Halvorsen et al. 2003), on the embedded jump chain of a piecewise-deterministic event process (Davis 1984). Well-posedness is discharged via the Implicit Function Theorem + IVT + strict monotonicity — all present in Mathlib today — not a controllability Gramian or a Riccati equation. The 5-factor channel claim is exactly a "one forward path, no touching loops" statement in the language of Mason's gain formula (Mason 1953).

**Explicitly excluded:** LQR/LQG/servo tracking, root locus, Bode/Nyquist, PID, the Kalman controllability rank test as a well-posedness tool, and the phrase "static output feedback" (a name-collision trap — that phrase means `u=−Ky` and its synthesis is NP-hard, per Blondel & Tsitsiklis 1997).

**Open modelling question the researcher could not resolve:** whether `t` indexes swaps or blocks, and whether the event-averaged objects (`ΔQ_M`, `ΔQ_X`) can be legitimately combined with time-averaged objects (`π^LVR·Δt`, `σ²`, `λ`). FRAME argues PASTA/ASTA (Wolff 1982) does **not** hold in a CFMM because arbitrage arrivals anticipate the state — this is reported as the one genuinely open item gating everything else, HIGH confidence that the question must be answered, MEDIUM that it is fatal.

**Sourcing caveat (FRAME's own disclosure):** the arXiv MCP tools were unavailable to this researcher; citations were instead verified via the arXiv API directly or web search, each tagged with a confidence level. Five items are explicitly flagged UNVERIFIED and must be re-checked before entering the spec: Skogestad & Postlethwaite's internal chapter/section numbering, Silverman (1969)'s volume number, Fukasawa's hitting-time-partition factor, the Bertsimas–Kogan–Lo error-rate exponent, and Tabuada (2007) citation details.

### Proof Obligations — What We Deliver (from CLAIMS.md)

Three of the four obligations (P1, P2, P4) look **REFUTABLE as literally stated**, and CLAIMS states plainly this is the useful outcome:

| Obl. | Headline | CLAIMS's bet |
|------|----------|---------------|
| P1 | The `∂`-partition is not linear: output carries a kink `(σ²−σ_K²)⁺`, the `φ`-row carries a non-affine logistic gate | Refute the linear reading; salvage a *saturated* set-point |
| P2 | The two boxed displays contradict each other (conditioning `|_{λ_MEV}` vs. the channel's own mechanism), and Rule 12 gives `τ_MEV` a **direct** monoid path the chain omits | "No other path" is FALSE — high confidence |
| P3 | `Ḡ_(ν,λ_MEV) := ∂ν/∂λ_MEV > 0` cannot be proved in-tree — no map `λ_MEV ↦ ν` exists, and the model deliberately carries no demand elasticity (the omitted MMR §7.3 eq. (27) term) | Not provable; formalize as a named hypothesis |
| P4 | The box is not a closed form (τ appears on both sides via `∂ν/∂τ_MEV`) and, under P3's own sign, the RHS bracket is negative, giving `τ*_MEV > 1` — outside the fee-monoid carrier `[0,1]` | Refute on admissibility — this is the project's headline candidate |

CLAIMS also documents that **the tree contains essentially no differential-calculus infrastructure** — a grep for `HasDerivAt`/`deriv`/`Differentiable` across all 23 Lean files returns real use in exactly one place. P2, P3, P4 are all derivative statements; CLAIMS's recommendation is to restate the sign claims in the tree's native `Monotone`/`StrictAntiOn`/`ConvexOn` idiom rather than build a derivative layer from scratch, which is both cheaper and, for the refutation path, strictly stronger (a sign contradiction needs no differentiability at all).

Four notation collisions (NC-1 through NC-4) are named as **hard prerequisites, not research** — they gate five downstream claims and cost nothing to resolve. A registry-fact correction: `PROJECT.md` stated `lean/vol_markets/` holds 37 files; CLAIMS counted 23 `.lean` files (10,651 lines) directly. *(Corrected in `PROJECT.md` at commit `fcb6d10`.)*

### Architecture Approach (from ARCHITECTURE.md)

This is not a software system but a **four-layer artifact pipeline spanning three git worktrees**: L0 source math + L1 spec layer (this project owns both, in `evm-controller`), L2 proof layer (`lean4-spec`, owned by the Lean4+Math peer session), L3 human entry point (`plank`, owned by peer `ul2inqpl`). **The single most important structural fact:** of the 11 steps in the Aristotle proving sequence, this project executes zero in its own worktree — rows 1–6 of the integration-points table are all one peer's territory, so the correct shape is a single frozen, sha-pinned PROOF-REQUEST hand-off artifact per bundle, not direct execution.

**Major components (spec/ directory):** `CONTROL-FRAME.md` (the derivation, frame, notation map), `PROOF-OBLIGATIONS.md` (P1–P4 as formal claims, frozen and sha-pinned at submit time), `PROOF-LEDGER.md` (verdicts only, written at landing — deliberately never merged with OBLIGATIONS because their lifetimes differ), `EVM-FEASIBILITY.md` (the on-chain object, signatures only, no implementation), `GAP-REGISTER.md` (hand-off to the implementation milestone), `TAU-MEV-SETPOINT-SPEC.md` (thin consolidation, written last).

**What transfers from v2-controller:** the thin-consolidated-doc pattern, the "saturate never revert" hard rule, the "controller defined only where its proof holds" discipline, signatures-only for missing primitives. **What does not transfer:** the `C2-PROOF-CASE.md` document type, the 10-controller catalog, the GAMS leg, and — flagged explicitly as **stale and misleading if reused** — `LEAN-MAP.md` (claims "exactly one Lean source file exists"; actually 23) and `EVM-CONTROL-PRIMITIVES-MAP.md` (dated 2026-06-28; this worktree's `src/` is a confirmed stale mirror of `cfmm-wt/plank/src/`).

**Recommended build order:** Phase A (frame + transcription + the two hard notation blockers — user-approval exit, no external spend) → Phase B (P1 + P2 in ONE Aristotle bundle) → **halt gate**: if P2 is REFUTED, skip C/D/E1 entirely → Phase C (P3 + a τ↔λ bridge lemma) → Phase D (P4, statement not writable until B and C return) → Phase E (E0 primitive-inventory refresh, parallelizable with A; E1 EVM feasibility of the *verified* form, must wait for D) → Phase F (consolidate, gap register, hand-off, doc summarization pass).

### Critical Pitfalls (from PITFALLS.md)

PITFALLS reverse-engineers the boxed law: the box is algebraically equivalent to `∂π̂^σ/∂τ_MEV = ΔQ_v*`, **not** to the stated replication relation `π^σ ≡^R π̂^σ` — the payoff factor `(σ²−σ_K²)⁺` has vanished entirely from the boxed form. Seven BLOCKER-severity findings, all status CONFIRMED:

1. **B1** — the box solves the wrong equation; `(σ²−σ_K²)⁺` disappears.
2. **B2** — the "no other path" clause is false; four independent counter-routes are enumerated from the source's own text.
3. **B3** — `∂ν/∂λ_MEV > 0` is silently substituted for `∂ν/∂τ_MEV`; composing with proved Lean results shows the true factor is **negative**, flipping the sign of the entire box and driving `τ* > 1`.
4. **B4** — the "closed form" is an implicit fixed-point equation (`τ` appears on both sides).
5. **B5** — the derivation adds two directional derivatives taken along two *different, incompatible* sections of a non-invertible 3→1 map; "the single highest-leverage line in the derivation."
6. **B6** — `∂L(i_K)/∂π^φ` is identically zero under the entry-point doc's own Rule 9; the channel is live only on the collateral-constrained branch.
7. **B7** — three non-differentiabilities sit exactly where the derivation differentiates, and the OTM branch (half the state space) has no interior solution at all.

Plus ten MAJOR findings, the most consequential being **M2** — a corrected misquotation independently confirmed against the Lean tree (`mevMulti_mono_beta` proves the *opposite* for `β`), and **M7** — four live notation collisions, one of which (`π^φ̃`, minted in `PROJECT.md` itself) is a self-inflicted violation of the project's own binding-notation constraint. *(Both corrected in `PROJECT.md` at commits `fcb6d10` and `02b4543`.)*

---

## Convergent Findings

### 1. P2's "no other path" clause is refutable — 4 of 4 researchers, ≥3 independent routes
FRAME (Mason's gain formula on the source's own `∇φ` display), CLAIMS (conditioning contradiction + direct monoid path), ARCHITECTURE (source's own additive `∂π^σ` expansion + `TauMevAlgebra` proof), PITFALLS (four enumerated counter-routes, CONFIRMED). Confidence calibration differs — FRAME MEDIUM-HIGH vs. CLAIMS/PITFALLS near-certain — preserved rather than flattened.

### 2. The boxed closed form (P4) is defective — 4 of 4 researchers, different specific defects
FRAME (FINDING B, implicit dependence, MEDIUM), CLAIMS (C-P4-2/3, not closed-form + admissibility `τ*>1`), ARCHITECTURE (three concrete defects in Build Order §), PITFALLS (B1+B4+B5, wrong target equation + implicit fixed point + root-cause invalid section-sum). PITFALLS's B5 explains the mechanistic root cause of both FRAME's and CLAIMS's independently-found symptoms.

### 3. P1's linear/state-space reading is not tenable as written — 3 of 4
(FRAME, CLAIMS, PITFALLS; ARCHITECTURE inherits without re-deriving)

### 4. P3's sign claim rests on an unprovable, undefined elasticity — 3 of 4
(CLAIMS, PITFALLS, corroborated by PITFALLS's own R5/absence-of-evidence section; FRAME discusses load-bearing role but doesn't independently investigate provability)

### 5. Notation is a hard, zero-cost blocker — 4 of 4
(FRAME implicitly via binding-notation discipline, CLAIMS's NC-1–4, ARCHITECTURE's two hard blockers, PITFALLS's M7 with the self-inflicted `π^φ̃` instance)

---

## Conflicts and Tensions (preserved, not smoothed over)

**Underactuation:** FRAME resolves it as "apparent, not real" via CV-selection theory (`H=[1,−1]`, square 1×1 problem). PITFALLS (M3) reaches the same underlying fact but treats it as one item in an unresolved cluster suggesting `∂_(t+1,t)` may be structurally zero, recommending explicit entrywise matrix verification before trusting any Ogata-derived literature applies. Not factually contradictory, but different register and different downstream instruction — the roadmap should run PITFALLS's check before adopting FRAME's resolution.

**Confidence calibration on P2:** FRAME states MEDIUM–HIGH; CLAIMS and PITFALLS effectively near-certain. No contradiction, but the spread should be preserved, not collapsed to one number.

**Non-aligned claim taxonomies:** CLAIMS uses `P1–P4`/`C-P#-#`/`A1–A10`; PITFALLS uses `B1–B7`/`M1–M10`/`N1–N5`/`R1–R8`; FRAME uses prose `FINDING A/B`/`W1–W7`; ARCHITECTURE references `P1–P4` directly. **No crosswalk exists between these in the source documents** — building one is a prerequisite for `PROOF-OBLIGATIONS.md`.

---

## Verdict Landscape (P1–P4 plus the τ↔λ bridge)

| Obligation | Likely verdict | Strongest evidence | Found by |
|---|---|---|---|
| P1 | REFUTE literal linear/LTI reading; salvage saturated set-point | Kink at strike; non-affine gate; possible `∂_(t+1,t)=0` | FRAME, CLAIMS, PITFALLS |
| P2 | REFUTE | ≥2 forward paths (4 independent demonstrations) | **4 of 4** |
| P3 | NOT PROVABLE as stated; provable only as a negative-sign composition | Missing `λ_MEV↦ν` map; composed sign is negative | CLAIMS, PITFALLS |
| P4 | REFUTE (admissibility `τ*>1` and/or implicit fixed point) | Sign-flip arithmetic; missing payoff factor; invalid section-sum | **4 of 4**, different mechanisms |
| τ↔λ bridge (newly surfaced) | Not yet formally stated; machinery nearly assembled from existing proved lemmas | `tau_intensity_effect_strict` + `mevMulti_anti_phibar` under uniform clearing | ARCHITECTURE, CLAIMS, PITFALLS |

---

## Blocking User Decisions (13 items, collected from all four documents)

1. `π^{\varphi}` symbol collision (CLAIMS NC-1, ARCHITECTURE, PITFALLS M7)
2. Leg pairing in `π^φ` (CLAIMS NC-2, PITFALLS M7)
3. Schedule's gate argument missing from display (CLAIMS NC-3)
4. `ν` vs. `u` (CLAIMS NC-4)
5. τ-vs-λ substitution / bridge legitimacy (ARCHITECTURE, PITFALLS B3)
6. Which relation the boxed form solves — level, vega-matching, or as-written (PITFALLS B1)
7. The `L` overload — ladder vs. aggregate pool (PITFALLS B6)
8. How `∂π^φ/∂φ` is sectioned (PITFALLS B5)
9. `e^σ`'s status — constraint or objective (FRAME W4, PITFALLS B7)
10. `Δt` — exogenous constant or endogenous (PITFALLS M6)
11. Grid map vs. marginal price for leg conversion (PITFALLS M9)
12. Entry-point-doc section/tag choice (ARCHITECTURE)
13. Import-or-assume decision on demand elasticity (PITFALLS M5)

---

## Corrections to the Record

1. The "(β_j,γ_j) does not control λ_MEV" theorem does not exist — already flagged in `PROJECT.md` itself, independently re-confirmed by CLAIMS (A1) and PITFALLS (M2) against `mevMulti_mono_beta`.
2. `PROJECT.md`'s file-count claim was wrong (37 vs. actual 23 `.lean` files) — CLAIMS.
3. `v2-controller`'s `LEAN-MAP.md` is stale ("exactly one Lean source file" vs. actual 23) — ARCHITECTURE.
4. `v2-controller`'s `EVM-CONTROL-PRIMITIVES-MAP.md` is stale (dated 2026-06-28, this worktree's `src/` confirmed a different, stale tree) — ARCHITECTURE.
5. `arb_add_fee_eq_lvr` must never be cited as "MMR Theorem 3 formalized" — CLAIMS (A3), PITFALLS (R8, M10).
6. The two-step review deferral debt from v2-controller (SPEC-04) is still open — ARCHITECTURE, PITFALLS.

---

## Absence of Evidence

- No literature bridges Carr–Madan/Breeden–Litzenberger spanning to control-theoretic set-point selection (FRAME, searched specifically).
- Five FRAME citations explicitly UNVERIFIED (arXiv MCP unavailable to that researcher): S&P chapter numbering, Silverman (1969) volume, Fukasawa's hitting-time factor, Bertsimas–Kogan–Lo rate, Tabuada (2007) details.
- No Lean declaration for the `υ` non-identification verdict — lives on the planning record only (PITFALLS R5).
- No map `λ_MEV ↦ ν` exists anywhere in the tree — a definitional gap (CLAIMS C-P3-1).
- Aristotle turnaround time is not instrumented anywhere — explicitly tagged "NOT EVIDENCED" (ARCHITECTURE).
- `DOC` Proposition 10 (grid vs. marginal price) marked "unproved in-tree" (PITFALLS M9).
- The tree contains essentially no differential-calculus infrastructure — one use of `HasDerivAt` across 23 files (CLAIMS §2.4).
- CLAIMS's own C-P4-1 reconstruction is explicitly self-flagged MEDIUM confidence, not confirmation.

---

## Implications for Roadmap

Six phases, adopted from ARCHITECTURE.md's build order (cross-checked against CLAIMS's dependency graph and PITFALLS's pitfall-to-phase mapping):

**Phase A — Frame, Transcription, Notation Rulings.** Delivers `CONTROL-FRAME.md` v1, entrywise `∂`-matrix construction, resolution of all 13 blocking decisions. Avoids M7, M3, S3, S4/S5. Exit: user approval + sha-pin.

**Phase B — P1 + P2 (one Aristotle bundle).** Shared definitional payload; P2 is the 4-of-4 highest-risk refutation and a hard halt gate. REFUTED ⟹ skip to F.

**Phase C — P3 sign + τ↔λ bridge lemma.** Small, focused bundle; state in native `StrictAnti`/`StrictMono` idiom, no derivative layer needed.

**Phase D — P4 verdict.** Not writable until B, C return. Headline candidate: admissibility refutation (`τ*>1`) or branch-split salvage (mirroring `EndogenousMaturity.dQvFunded_maximal`/`Flow.schedule_isLeast`).

**Phase E — EVM feasibility.** E0 (primitive refresh) parallel to A; E1 (law-specific) strictly after D.

**Phase F — Consolidation, gap register, hand-off.** Written last; `REFUTED`/`CORRECTED` verdicts feed back and re-freeze `CONTROL-FRAME.md`.

### Research Flags

Needs research: Phase A (event↔wall-clock/PASTA-ASTA bridge — FRAME's one genuinely open item), Phase C (demand-elasticity import/assume decision), Phase E1 (stale Plank primitive inventory)
Standard patterns: Phase B/C/D's Aristotle mechanics (fully evidenced), Phase F's document skeleton (transfers from v2-controller)

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Frame | MEDIUM-HIGH | Frame choice HIGH; two findings MEDIUM; event↔time bridge OPEN; 5 citations UNVERIFIED |
| Proof obligations | MEDIUM-HIGH | HIGH on existing-Lean verdicts; MEDIUM on box reconstruction |
| Architecture | HIGH / MEDIUM | HIGH on pipeline/ownership; MEDIUM on doc decomposition; MEDIUM-LOW on EVM-feasibility content (stale inventory) |
| Pitfalls | HIGH / MEDIUM | HIGH on mathematical traps; MEDIUM on process/scope traps |

**Overall confidence:** MEDIUM-HIGH on refutation findings (cross-checked); MEDIUM on frame/architecture (single-researcher, well-precedented).

### Gaps to Address

- The event↔wall-clock clock bridge (FRAME's one genuinely open item)
- Five UNVERIFIED FRAME citations
- No crosswalk between the four documents' claim-ID taxonomies
- CLAIMS's C-P4-1 reconstruction needs an author/user ruling
- The FRAME/PITFALLS tension on whether underactuation is already resolved — run PITFALLS's entrywise check first

---

## Sources

See each source document's own Sources section for full detail. Primary (HIGH): direct reads of the derivation, the entry-point doc, all 23 Lean files by declaration/line, `lean4-spec` Aristotle run records, arXiv-API-verified citations (2103.14769, 2111.13740, 1805.09877, 2103.11329, 1905.06291, 1204.0637/1004.2107), Ogata TOC, Skogestad/Jäschke/Halvorsen/Alstad/Mason/Davis/Wolff/Kreindler-Sarachik/Brockett-Mesarović/Fiacco/Rugh-Shamma, Demeterfi et al. (vendored PDF). Secondary (MEDIUM): Skogestad & Postlethwaite chapter internals, Silverman (1969) volume, Melamed & Whitt, v2-controller prior art. Tertiary (LOW/UNVERIFIED): Fukasawa hitting-time factor, Bertsimas–Kogan–Lo rate, Tabuada (2007) details.

---
*Research completed: 2026-08-08*
*Synthesized by gsd-research-synthesizer; written to disk by the orchestrator (the agent's Write tool was blocked for report paths).*
