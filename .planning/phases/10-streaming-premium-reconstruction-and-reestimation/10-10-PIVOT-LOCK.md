# Pivot Lock: phase10-plan10-10-run2 — locked 2026-07-27 (BEFORE run 2 executes)

New iteration under the anti-fishing discipline. Run 1's pre-registration (`10-10-PLAN.md`) is preserved unedited as historical record; run 1's verdict (UNINFORMATIVE) and its analysis (`2026-07-20-upsilon-estimates-v2.md`, frozen with a CORRECTIONS header) remain on the record permanently.

## The single change (and nothing else)
- **LHS sign normalization to the seller side**, exactly per `Panel.Build.premiumUsd`'s documented Phase-9 convention: rows belonging to LONG tokenIds have `premium_wei` multiplied by −1 before entering the estimator, so long and short vega enter with one sign. Implemented in the CLI/panel-derivation layer ONLY (`econometrics/app/Main.hs` or a derived `estimation-panel-v3.csv`); `econometrics/src/Model/`, `src/Tests/`, `src/Alternatives.hs` remain byte-untouched (empty-diff acceptance criterion carries over).
- The long/short classification source is the frozen `burn-truth.csv` / panel `is_long` column — no reclassification.

## Everything explicitly UNCHANGED (locked)
1. Stopping bar: **6.2e-5, as-is.** Its unit incoherence (defined against Phase 9's USD/day·daily grid) is recorded, not repaired. No rescaling, no reinterpretation.
2. Verdict rule: STOPPING_RULE = (UPSILON0_CI_HALFWIDTH ≤ 6.2e-5), clustered CR0 by tokenId, blind to κ̂'s sign and all p-values. Same `stoppingRuleVerdict` code path.
3. Estimator, tests, alternatives, multi-start protocol, panel rows (6,760), clusters (55), variance join: identical to run 1.
4. No other data edits: no filters, no trims, no re-fetches.

## Pre-registered secondary descriptors (declared NOW, before run 2)
Because the primary bar is unit-incoherent for this panel, the following unit-free descriptors are pre-declared for reporting (they do NOT override the mechanical verdict):
- D1: half-width / |υ̂₀| ratio (run 1: 4.11)
- D2: does the υ₀ CI exclude zero (run 1: no)
- D3: υ̂₀ and SE movement vs run 1 (direction and magnitude)

## Pre-registered interpretation (declared NOW)
- If υ̂₀ moves away from zero and/or its SE narrows materially: consistent with the mixed-sign attenuation mechanism; report both runs side by side.
- If υ̂₀ remains ≈0 / interval still wide: the sign mixing was NOT the binding attenuation source; the market-cannot-identify-υ conclusion stands with BOTH constructions on record.
- **Either way: NO further iterations.** This is the terminal estimation run of Phase 10 (user commitment, 2026-07-27). The κ>0 rejection from run 1 is expected to persist (sign normalization affects υ₀'s level primarily); if it does NOT persist, that fragility is reported plainly.

## Provenance
- Defect: `10-10-DISPOSITION-MEMO.md` (trigger, what was not done, exemption reasoning)
- User pivot enumeration: checkpoint adjudication "escalate-anomaly", 2026-07-27, quoted verbatim in the memo
- Lock integrity: the sha256 of this file at commit time is the pin; any post-commit edit to this file voids the lock
