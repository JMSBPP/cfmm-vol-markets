# Phase 14 — Kristensen implied-volatility integration

**Requirement:** CTX-IVLEVEL (sole).
**Status:** RESEARCH DONE, GATED. Not executable.
**Depends on:** Phase 13 item (c) — the notation gate must be refreshed before any doc block lands,
and Phase 13 item (g) — the signed-`ΔQ` ruling, which is a Phase-13 doc defect this phase consumes.

**Source:** `../plank/refs/lp-derivatives/kristensen-perpetual_options_uniswap_v3-2024.pdf` §3.4, §3.4.3.
**Research:** `.planning/implied-vol/IV-RESEARCH.md` (to be co-located as `14-RESEARCH-IV.md`).
**Draft blocks:** `model/vol_markets/VOLATILITY_INSTRUMENTS_IV_ADDENDUM.md`, V0–V9, STATUS: DRAFT.

## Findings

**Extraction (eq. 3.16, p. 69):** `σ_IV = 2φ·√(VOL/AMT_tick)`. Two corrections to the premise as
posed: it is **σ, not σ²**, and `VOL/AMT_tick` carries units **day⁻¹**, so σ_IV is per √time.
Source typo found: p. 67 prints `ϕ = 0.0003`; both printed numerics require `0.003`.

**The `2·√` hypothesis is REFUTED as a CES specialization.** `4 = √(8/π · 2π)`, both factors
Gaussian (Erf Taylor from the occupation time; standard-normal density at zero from the ATM
premium); the curve appears nowhere in his derivation. Two genuine specializations survive: the `√`
is `1/(ε_{hold,σ} + ε_{lend,σ})` at unit elasticities, and `φ²` is really `φ·(t_s/20001)` — the
square is an artifact of Uniswap pairing fee tiers with tick spacings.

**Framework-general form — CONDITIONAL, NOT ESTABLISHED:**
`σ_IV^ATM = 2√(φ · (ηΔ_i lnλ)/2 · ν̄)` holds **only when the occupation law supplies `W ∝ 1/σ`**,
which is precisely the open ruling below. Reproduces his numerics to 9 s.f. *under that hypothesis*.
The first draft of this registration stated it unconditionally twenty lines above the gate that
declares it unresolved; corrected here.

**HEADLINE:** his constant-`AMT_tick` assumption (Remark 3.8) holds **exactly iff
`ξ = λ^{−ηΔ_i/2}`** — at `η = 1` precisely the doc's `ξ⋆`, the log-contract ladder. His
"narrow-range approximation" IS the statement that our ladder is the variance-swap ladder. And
`ν_t = w_t/D_t` already IS VOL/AMT per block, so `λ_FLAIR = φW` is his holding return verbatim.

**`VOL/AMT` is not `u`:** AM–GM gives u-arg ≤ VOL/AMT, equality iff leg-balanced. They are the
`ε_{X/M} = 0` and `= 1` members of one ratio family.

**Kristensen's "lending" (§3.4.2) is a false friend** meaning covered-call writing; `p_risk` is a
haircut-inflated collateral price with no time dimension, so it is not a price of risk.

## NEW SYMBOLS — four, not one; all owe user discussion

The first draft named only `r_fix`, which read as the sole mint. The addendum's own header declares
**2 elasticities + 1 parameter + 1 derived**:

| Symbol | Role | Status |
|---|---|---|
| `ε_{hold,σ}` | σ-elasticity of the holding leg | undisclosed to user |
| `ε_{lend,σ}` | σ-elasticity of the writing leg | undisclosed to user |
| `r_fix` | exogenous fixed-income rate | flagged as new |
| `T_c` | derived crossover maturity | undisclosed to user |

Under the binding define-before-writing rule no symbol is minted without discussing it with the user
first and running a freeness check. Three of four have not been discussed. `r_fix` carries an honest
caveat: the rate leg is O(T) vs O(√T), binding only when `σ ≤ r_fix√(2πT)` — conceptually necessary,
quantitatively inert at crypto vols.

Zero **volatility** symbols minted: `σ_IV` already exists in the Greeks blocks. Greeks supply the
SHAPE (`σ_IV(K)/σ_IV^ATM`, declared DIAGNOSTIC), Kristensen supplies the LEVEL.

## Gates

1. **`W`-depends-on-σ ruling.** Kristensen's does (occupation time ∝ 1/σ); ours is measured data.
   Until ruled, `σ_IV^ATM` is either a closed form or a fixed point — different objects, and the
   formalization target is blocked on which. *This is now the only ruling gating this phase*; the
   signed-`ΔQ` ruling moved to Phase 13 (g) where it belongs, as an existing-doc defect.
2. **Phase 13 (c)** — notation gate refreshed.
3. **HEAVY USER APPROVAL** of the V-blocks, discharged by an `APPROVED-IV-SHA256` pin recorded in
   this phase's summary, per the 11-01 / 12-01 precedent.
4. **Ordering constraint with Phase 12.1** — see below.

## Ordering constraint (was wrongly stated as "no execution order")

Phase 12.1 renumbers definitions and renames the replication weights. The V-blocks are already
drafted against the *current* numbering and the *current* `α`. Therefore: **12.1 runs strictly
BEFORE any V-block lands, or strictly AFTER all of them — never interleaved.** Choice not yet made;
must be recorded here before either executes.

**Insertion anchor:** the live doc header is `## IMPLIED VOLATILTIY` (**misspelled in the doc**);
the addendum targets `## IMPLIED VOLATILITY`. Any grep- or sha-anchored insertion misses. Fix the
anchor or the header — deliberately, and record which.

## Definition of done

A V-block set landed in the doc under an `APPROVED-IV-SHA256` pin, stating σ_IV's LEVEL in the
binding notation, with the VOL/AMT ↔ `u` relation carried as a *proved* lemma in `lean/vol_markets/`
(axiom-clean) or an explicit recorded refutation — plus traceability rows. Not "integrated".
