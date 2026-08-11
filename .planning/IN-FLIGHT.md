# In-flight and parked work — the resume ledger

**READ THIS FIRST on any session resume, context compaction, or instance restart.**

Why this file exists: the phase files track work that is *being done*. Nothing tracked work that was
**handed off and waiting**, or **parked as a leaf**. That gap is how `EtaTilde.lean` landed with 23
declarations and appeared in no roadmap, how a 43 KB Greeks research track stayed invisible, and how
the θ exponent-sign FLAG sat blocking a definition while nobody was counting it. A phase file answers
"what are we doing"; this file answers **"what are we owed, and what will make us pick it up again."**

Every row carries a **RESUME TRIGGER** — the observable event that reactivates the item. An item with
no trigger does not belong here; give it one or close it.

---

## A. External work in flight (Aristotle)

> **CLI GOTCHA — this has cost time twice.** `aristotle show|tasks` return **HTTP 500 on short
> project ids**. Always pass the **full UUID**. `aristotle list` works and prints full UUIDs. A 500
> is almost never an outage — check `list` before concluding the API is down.

| Project (full UUID) | Name | Submitted | Targets | RESUME TRIGGER | On return |
|---|---|---|---|---|---|
| ~~`7d9a8baa-1c40-49fb-9bcf-708b71dc3297`~~ | `aristotle-phimix` | 2026-08-04 | **CLOSED 2026-08-08 — INTEGRATED** (lean4-spec `d3fca72`, doc plank `d6d5173`). COMPLETE; all 4 targets proved. Gates: 4 statements byte-identical to submission, 3 definitions byte-unchanged, 0 sorries, 4/4 axiom-clean (propext/Classical.choice/Quot.sound), full `lake build` 8074 jobs; only the 2 Aristotle-disclosed `unused variable` warnings (hA/hp retained in M4 because they were part of the requested statement). **M3 `Fmix_eq_phi`** = the separation; **M4 `Fmix_homogeneous_iff` TRUE AS WRITTEN** — refute-and-correct clause UNUSED. Landed as doc **Theorem 28**, DELIBERATELY UNNAMED (a third φ-subscript would assert family membership, which `Fmix_homogeneous_iff` + `canon_Fcap_not_CES` both refute); F/F_0/F_1 now absent from the doc. Anchor price kept as the hatted raw value `p̂` (user ruling: option (a)) — NOT identified with `p_(η,Δ_i)` (Proposition 10 forbids it) and NOT with `p_φ` (would be a second doc→anchor bridge alongside ς_{X/M}). | — | — |
| ~~`4e9109a9-2804-45e9-8be9-3d5eabcc2ad2`~~ | `aristotle-tol-slip` | 2026-08-04 | **CLOSED 2026-08-04 — INTEGRATED** (`5d371a4`, mirror `ca1fec8`; doc verdict plank `e4d32d8`). COMPLETE in 2h4m; gates: defs byte-unchanged, single sorry only inside the commented-out original S4, all active theorems axiom-clean, clean build (8026 jobs). **SPLIT VERDICT:** Θ_φ branch REFUTED (`sandwich_fee_hurdle_false`, 30bp witness; exact frontier `pnlFee_pos_iff` — tol_slip does not enter; CORRECTED: the fee pins admissible TRADE size, `Δ ≤ (φ/(1−φ))Q_M` kills the channel ∀ front-runs); Θ_p branch PROVED as stated (`sandwich_grid_cap` — tol_slip ≤ 1 − r⁻¹ within one marginal-price spacing). | — | — |
| ~~`1f6da52a-f998-471c-84b6-9130d8adbd25`~~ | `aristotle-embed2` | 2026-08-03 | **CLOSED 2026-08-04 — INTEGRATED.** The continue task (`a08b8525`) returned COMPLETE_WITH_ERRORS (cosmetic — one `Try this` info). All gates passed: 0 sorries, both targets axiom-clean (propext/Classical.choice/Quot.sound only), endpoints byte-identical vs the embed base, deps import-rewrite-only, full `lake build` vs current tree (8051 jobs). **VERDICT: interior embedding REFUTED** — `canon_Fcap_not_CES` proved (symmetry ⟹ ε=1/2; (t,1) slice ⟹ ρ=√3/3; 4th derivatives contradict), `kappa_not_reparam_of_rho` by instantiation; only the two endpoints embed. Landed `ca8e4a1` (lean4-spec `8536a31`). Phase 13 (b) branch taken: **MOOT**. | — | — |

| ~~`9786b137-f7e7-4175-af83-738c330b4022`~~ | `aristotle-ell` | 2026-08-10 | **CLOSED 2026-08-10 — INTEGRATED** (lean4-spec `0eb003b`; doc plank `241e051` + `056fc6b`). 12 theorems. Gates: 7/7 defs byte-unchanged, 0 live sorries (2 inside comment blocks preserving the refuted originals), 10/10 axiom-clean, build 8075 jobs. PROVED: the two limits, degree-1 homogeneity, the ρ→1⁻ pole, the constant-product impact law, and state-constancy (`ell_ratio_const_iff` — constancy would force ε=1/3 and ε=1/4 at once). **REFUTED-AND-CORRECTED (guard, not mathematics):** `ellAt_eq_ell_false` / `halfKernel_osculates_false` — `0 < yOf` does NOT place the state inside the level set because `Real.rpow` off the positives carries a cos(π·) factor; the RADICAND guard is the fix and the hand-derived closed form is proved in full. Landed as Def 32 / Thm 29 / Thm 30 / Prop 12, written **\bar L_{(χ,ε)}** (user ruling — it is the generalization of \bar L, so the CPMM case is a notational identity and the ℓ collision never arises); all 37 bare \bar L swept to \bar L_{(1/2,0)}. | — | — |

| ~~`68d1b02a-8a3e-4a48-8f94-0b561b70e658`~~ | `aristotle-geom` | 2026-08-10 | **CLOSED 2026-08-10 — INTEGRATED** (lean4-spec `19d3e07`; doc plank `b541ace`). COMPLETE_WITH_ERRORS (cosmetic). 5 targets + `hasDerivAt_yOf` + `balanced_state_exists`, ALL TRUE AS WRITTEN — refute-clause unused. Gates: 5/5 statements byte-identical, EllIntrinsic dep byte-identical, 4/4 defs unchanged, 0 sorries, 7/7 axiom-clean, build 8076. Doc promotions (user-approved): **Prop 7 → Theorem 31**, **Prop 13 → Theorem 32** (numbers retired, not reused), **Prop 12 SETTLED split-verdict** (map exists iff ε_{X/M}=0 — G4 deficit confirmed FROM GEOMETRY, Phase 15.2 machine-warranted). Def 14's by-fiat footer resolved AT THE BALANCED POINT. **Carry-forwards:** (i) `hasDerivAt_yOf` = cohesion C2a arrived early — single-carrier rule applies when `4d696a77` returns; (ii) the Gaussian-zero rider and Prop 10 were NOT in this bundle and stay owed (staged-bundle row); (iii) general-point elasticity of Def 14 still has no dedicated carrier. | — | — |

| ~~`4d696a77-aa60-4ef1-8da4-248a507d9921`~~ | `aristotle-cohesion` | 2026-08-10 | **CLOSED 2026-08-10 — INTEGRATED** (lean4-spec `2732563`). COMPLETE; 6/6 TRUE AS WRITTEN, refute-clause unused; **`ellP`'s hand-derived bookkeeping CONFIRMED**. Gates: 6/6 statements identical (tangent_slope in term mode), EllIntrinsic byte-identical, 2/2 defs unchanged, 0 sorries, 6/6 axiom-clean, build 8077. The transition channel is PROVED: dx/dp = −ℓ/(2p^{3/2}), dy/dp = ℓ/(2√p), dy/dx = −p, on-curve identity, L(p) = −Γ + price impact, and the pushforward (the field factors through (level, price) alone). Single-carrier rule applied at the DOC level: CanonicalParam carries the channel, PayoffGeometry the envelope/Γ; the cross-namespace `hasDerivAt_yOf` duplicate is recorded in the integration commit. Doc blocks APPROVED and landed: Thm 33 + Def 33 + Thm 34, plank `65eada6` (bare-𝒟 draft defect user-caught, corrected to G0 operator form before landing). | — | — |

| ~~`d1ad6474-7b98-4d19-baee-f9c63fd1e86a`~~ | `aristotle-making` | 2026-08-11 | **CLOSED 2026-08-11 — INTEGRATED** (lean4-spec `863fa05`). COMPLETE; 12 decls, 10/10 axiom-clean, build 8078. **S**: φ^σ = the CONSTANT-GAMMA curve (kit proved); embedding into the CES family REFUTED (`phiSigma_not_CES`, homogeneity forces L² = 0) — the TODO's boxed φ^ν→φ_{(χ,ε)} question is ANSWERED NO. **A**: spread identity proved; **`bidask_labels_inverted` CONFIRMED** (as the TODO labels them, ask < bid on f∈(0,1)); `otimes_is_retention_mul` — ⊗_φ IS multiplication on retained fractions (the which-algebra answer); `ask_comp_otimes` REFUTED (1/4 vs 3/4), corrected law composes through the complement map. **R**: ramp band + Heaviside step pair (δ-pair NOT claimed). **Doc blocks + the Dirac reformulation (D4) now UNBLOCKED — awaiting user approval, incl. the LABELS RULING** (keep TODO's assignments with the inverted-sign fact recorded, or swap to the economic convention ask = P/φ, bid = φP). | — | — |

| `589d44ac-d37e-40a1-889c-11bc408e50ad` | `aristotle-gamma-riders` | 2026-08-11 | **4 sorry'd targets in `GammaGrid.lean`** (`scratch/gamma-riders-submit/`, imports proved `EllIntrinsic`): the twice-owed riders finally dispatched + the new Γ-grid law. **G1** = doc Proposition 10 (grid–marginal-price inverse product — elementary reciprocal difference); **G2** = the Gaussian-zero rider (1-homogeneity ⟹ CES Hessian det ≡ 0 via Euler); **G3a/G3b** = the ξ-coordinatization of gamma: Γ_φ(i_K) = −½L̄ ξ^{−3η(i_K+Δ_i/2)}, per-spacing ratio ξ^{−3ηΔ_i} — numerically verified at two η before submission; the 3 = 3/2 × 2. Doc side ALREADY LANDED as Definition 38 + Proposition 14 at the user's PRICING_GEOMETRY marker (plank `0a5ad61`), Prop 14 marked in-flight. | the project returns (OUT_OF_BUDGET ⟹ `continue` on the SAME project) | usual gates; on return promote Prop 14 → Theorem, mark doc Prop 10 proved (two citation sites carry 'still owed' notes to clear), and attach the Gaussian-zero carrier to the Refutation note. |

| `2370c633-d78a-4b79-ba91-7297861f6424` | `aristotle-gamma-coord` | 2026-08-11 | **4 sorry'd targets in `GammaCoordinate.lean`** (`scratch/gamma-coord-submit/`, self-contained): the user's COORDINATE-SPACE proposal — ξ = the liquidity coordinate, γ(i) = −3η(i+Δ_i/2) the DERIVED gamma coordinate, and **K1** the compositional reading Γ_φ(i_K) = −½·L(γ(i_K)) with L(t) = L̄ξ^t (grid-space PRESENTATION of the proved state-space Theorem 32, NOT a replacement — the user's 'Theorem 32 incorrect' point resolves as two readings of one object, K1 being their coincidence); **K2** ladder-gamma single ξ-power; **K3** FLATNESS IFF ηΔ_i = 1/3 — the NEW distinguished grid point; **K4** the flat value −(L̄/2)ξ^{−(i_0/Δ_i+1/2)} — the grid+ladder EMULATING φ^σ (the making bundle's constant-gamma curve). All 4 numerically exact pre-submission. NOTE: defs pGrid/pPhiGrid/xiStar DUPLICATE `aristotle-gamma-riders` (589d44ac) — single-carrier merge at integration if both return. BRIDGES OPENED (recorded for the doc pass): (i) LDF ⟹ gamma design — Phase 15.2's ℓ_LDF chooses the Γ profile through a pure coordinate change; (ii) ηΔ_i = 1/3 as a design point tying the grid to φ^σ; (iii) G5/EVM: Γ as a ξ-exponent lookup, no p^{3/2} mulDiv chain; (iv) one coordinate family for PRICING_GEOMETRY (λ-price, ξ-liquidity, γ-gamma). | the project returns (OUT_OF_BUDGET ⟹ `continue` on the SAME project) | usual gates; on return land Definition 39 (gamma coordinate) + the compositional/ladder/flatness statements next to Def 38/Prop 14, and promote Prop 14 together with the riders. |

**STALE-NOTATION WARNING on the plank handoff.** The Phase-12 close-out handoff appended to plank
`todo.md` (uncommitted, plank-owned) quotes the controller law in PRE-RENAME notation — `κ_φ*`,
"curvature optimum". Under the 2026-08-03 scheme those are `ς_{X/M}` (share-asymmetry) statements
and `κ_{\varphi}` now names the genuine curvature. If `ul2inqpl` reads it post-rename they will
misread it. Owed: a notation postscript on that handoff (plank-owned file — flagged, not edited).

**Superseded, keep for provenance:** `232c8ee4-f99f-4b3c-a65b-0a26de76f5b1` (`aristotle-embed`) —
OUT_OF_BUDGET after 1h26m, 2-of-4 partial, downloaded to `scratch/embed-return/`. Its two proven
endpoint theorems are the working base of `1f6da52a`. **Never integrate this partial** (2 sorries).

---

## B. Parked leaves — real work, deliberately not being done now

| Item | Where it lives | Why parked | RESUME TRIGGER |
|---|---|---|---|
| ~~PR-SYNC: ETA addendum resync~~ | Ph 13 (d) | — | **CLOSED 2026-08-03** — resynced 1:1, disclosure extended, no new pin (per the 12-04 rule) |
| ~~E4 redo on the ε axis~~ | Ph 13 (b) | — | **CLOSED 2026-08-04 — MOOT** (embedding refuted by `canon_Fcap_not_CES`, commit `ca8e4a1`); E1–E7 stand as SHARE statements (doc Theorem 9) |
| **Item (k): the E1 DIAGNOSIS defect** | Ph 13 (k) | needs a doc edit | `PR-GATE` passes |
| **Item (i): PhiCES notation-map line** | Ph 13 (i) | needs a doc edit | `PR-GATE` passes |
| **Kristensen V0–V9 blocks** | Ph 14 | gated | `PR-WSIGMA` ruled **and** `PR-GATE` passes |
| **Doc definitional re-ordering** | Ph 12.1 | **ACTIVE — pair session running** (Definition 1 landed `fa082b2`; θ sign ruled; PR-CSYM settled `a₁,a₂`) | continuous — statement-by-statement with the user |
| **Greeks bundle (G1 ladders, θ split, G4 deficit lemmas)** | Ph 15 | gated | `PR-CARRY` ruled (θ side now clear — PR-THETA ruled negative) |
| **G2 skew law** | Ph 15 | off-bundle | E8(6) `η_L = η` closes (`PR-ETAL`) |
| **Occupancy `T_ITM/T`** | `.planning/occupancy/` | **ROUND 2 DONE — PROMOTE narrowly, conditionally.** Inception reading well-posed (the never-held objection does not bite: `T_ITM` is `𝔼[∫𝟙]`, unobservable on Kristensen's side too); headline: composing the PROVED `tStar_strictMono_dQvStar` with mean-of-decreasing gives **in-band fraction strictly DECREASING in target vega** (needs only monotonicity — no Erf, no price law). Panoptic has **no boolean `isITM`** — three notions (moneyness/band/swap-ITM), predicate depends on `tokenType`+`strike` only. `ℙ_{[i_l,i_u]}(t) = ℙ_{i≥i_l}(t) − ℙ_{i≥i_u}(t)` — one-sided is primitive, the reserved terminal reading is the `t=T` member | **FOUR user rulings** before any doc block: amend the `ℙ_ITM` reservation to a `t`-indexed family?; the measure; which tick (RiskEngine checks 4 under safeMode, spotTick is an EMA); the ATM convention (Panoptic groups ATM with ITM) |
| **exp-layer Δi-control: the small-trade band-max sorry** | `lean/exp/eta.lean` (1 sorry) + NEW `model/exp/eta_pi_trader_delta_control.md` | REGISTERED 2026-08-03 — was tracked nowhere (the EtaTilde failure class again). PROVEN: `pi_trader_half_strictly_increasing_in_Δi` (project `88d393e7`) — tick spacing is a one-parameter control knob for the trader payoff in the LARGE-trade regime (`L̄ ≤ Δ^I`); small-trade regime is U-shaped (zero at `Δi⋆`), so adaptive control there is piecewise. OPEN: the small-trade **band-max** theorem (max at the endpoint farthest from `Δi⋆`), marked "left as sorry for Aristotle" in-file | an Aristotle submission for that sorry (OUT_OF_BUDGET rule applies: continue, not resubmit) |
| **Proposition (Two-instrument replication) — drafted, user-approved in form, DELIBERATELY NOT LANDED** | 12.1 pair session, statement 2 | User ordering ruling (2026-08-03): first DEFINE `p_{π^call}`, `p_{π^put}` in terms of liquidity and the programs; then how the payoff is replicated by calls/puts; only THEN the price-relationship propositions (is it affine? what functional form?). Also recorded: the additive structure is UNPROVED in-tree — `replicationPrice` only names the affine form; the proved replication is the ξ⋆ ladder | call/put price definitions land in the doc → then the replication structure → then this proposition (and its ladder→two-instrument Aristotle bundle) |
| **STAGED Aristotle bundle — trading-curve geometry (6 items, queue FREE)** | 12.1 pair session, `# TRADING_REGION`/`# CONTROL_OPERATORS` | accumulated 2026-08-04, not yet submitted | user says submit → one bundle: (1) Proposition 7 (κ_φ CES closed form via ε_{p/X} + normalization), (2) Gaussian-zero rider (Hess degenerate by homogeneity), (3) Proposition 10 (grid–marginal-price relation, elementary from Theorem 5), (4) π^φ portfolio-value formalization (conic dual, UNFORMALIZED), (5) ~~tol_slip functional-relationship conjecture~~ **DISPATCHED 2026-08-04 as `aristotle-tol-slip` (§A)**, (6) sandwich kernel Defs 27–28 (𝒮 invariance + π^sandwich, UNFORMALIZED). Older parked targets still separate: θ general closed form, discrete Demeterfi step, single-leg conjecture, band-max sorry |
| **Traceability + φ-gate refresh (12.1 sprint debt)** | `LEAN_TRACEABILITY` (machine-facing twin) + `phi-notation-gate.sh` (Ph 13(c), PR-GATE) | REGISTERED 2026-08-04 — the doc sprint renamed dozens of glyphs under the doc-glyph/Lean-name split (ϖᵢ↔cOne..cThree; hatted raw values↔premInv/premShock; π^LVR↔weights; ν_t↔w_t/D_t; ς_{X/M,S/I}↔kphiS/kphiI; π^trader↔surplusRatio; 𝒮 unformalized; M/E blocks → numbered statements with [M#]/[E#] tags; E8 → TODO register). Twin + gate are now substantially STALE; no automated check may run against the doc before both are regenerated | E-section conversion complete (NOW satisfied) **and** user schedules the pass; the gate half additionally consumes Ph 13(c) |
| **Bunni-v2 LDF port** | G4 future milestone | declared out of scope | user opens the milestone |
| **Shock symbol vs magnitude mismatch (Convention 6)** | doc `VOLATILITY_INSTRUMENTS.md` ~line 1083 | PARKED 2026-08-08 by user ruling — surfaced while settling `p̂` in Theorem 28. The per-period price shock is written on a GRID symbol, `\hat{Δp_(η,Δ_i)/p_(η,Δ_i)}` (Lean `premShock`), but its magnitude is annotated "λ^{ηΔ_i} − 1 **in marginal price**" — and line 1029 confirms λ^{ηΔ_i} is the MARGINAL step, the SQUARE of the grid step per Proposition 10. Symbol and magnitude therefore disagree by one squaring. Consumed by Definition 29's branch point ς_{X/M,S} and Theorem 25's premium order, so a fix moves numbered statements — not a cosmetic rename | the traceability + φ-gate refresh pass runs (same glyph sweep), **or** any statement consuming the shock symbol is restated |

---

## C. Awaiting a USER DECISION — nothing proceeds on these without a ruling

These are the cheapest items on the whole board: no research, no compute, no proving.

| id | The question | What it unblocks if answered |
|---|---|---|
| **PR-EPSTOL** | a symbol for the numerical tolerance that is **not** ε (elasticities), **not** σ (volatilities), **not** δ (Greeks) | `PR-GATE` → and through it FIVE parked doc items |
| **PR-ORIENT** | the canonical **argument order** of `φ` — machine evidence says `(Q_X, Q_M)` with χ on `Q_X`; Theorem 1 currently consumes the other order | `CC-REPL`, `CC-CURV`, and Phase 14's `u` relation |
| **PR-REGION** | are the `ΔQ` legs **signed**? the admissibility region is absent from the page | `CC-REPL` (Theorem 1 is ill-posed without it), Phase 14 |
| **PR-WSIGMA** | does `W` depend on σ? decides closed form vs fixed point | `CC-IV` / Phase 14 |
| ~~PR-THETA~~ | — | **RULED 2026-08-03: negative** — θ Definition, G1 θ_decay, on-chain constant all unblocked |
| **PR-CARRY** | per-event (M6b) vs time-integrated (λ_FLAIR) | Phase 15 — decides *what gets proved* |
| **PR-CSYM** | a free symbol pair for the replication weights (`c₁`/`c₂` are taken) | Phase 12.1 |

---

## Maintenance rules

1. **Hand-off creates a row.** Submitting an Aristotle bundle, dispatching a research agent, or
   parking an item adds a row here in the same action — not afterwards.
2. **Every row has a resume trigger.** No trigger ⟹ it is not parked, it is forgotten.
3. **Closing a row is explicit.** Move it to the phase summary with its disposition; do not delete.
4. **This file is read on resume**, before the roadmap — the roadmap says what the plan is, this says
   what is owed.
