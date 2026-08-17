---
phase: 09-upsilon-econometric-estimation-lean-aware
plan: 09
subsystem: econometrics
tags: [haskell, estimation, live-data, null-result, lean-witness, CTX-ALT]
requires:
  - "econometrics/src/Model/{Upsilon,NLS,EIV,SandwichSE}.hs (09-07, 09-08)"
  - "econometrics/src/Tests/Specification.hs (09-08)"
  - "lean/vol_markets/Upsilon.lean :: exp_family_witnesses_ATMOTM (09-06, PROVED)"
  - "notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md"
provides:
  - "econometrics/src/Alternatives.hs :: runAlternatives (the four locked spec 6.2 alternatives)"
  - "notes/structural-econometrcics/data/estimation-panel.csv (the 09-10 GAMS cross-check input)"
  - "notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates.md (the phase deliverable)"
  - "DATA-SOURCES.md section 5 (authoritative live-schema record)"
affects:
  - "09-10 (GAMS differential cross-check) — consumes estimation-panel.csv"
  - "09-11 (audit-econ gate) — audits the analysis output's lineage"
tech-stack:
  added: [time, filepath]
  patterns:
    - "data-scaled multi-start NLS (kappa's informative scale is set by tick-distance units)"
    - "accrual-spell unit of observation (forced by the live subgraph schema)"
    - "estimators report estIdentified=False with a reason rather than emitting a meaningless number"
key-files:
  created:
    - econometrics/src/Alternatives.hs
    - econometrics/test/AlternativesSpec.hs
    - notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates.md
    - notes/structural-econometrcics/data/estimation-panel.csv
    - notes/structural-econometrcics/data/collateral-flows.csv
  modified:
    - econometrics/src/Panel/Subgraph.hs
    - econometrics/src/Panel/Build.hs
    - econometrics/src/Panel/Variance.hs
    - econometrics/src/Model/NLS.hs
    - econometrics/app/Main.hs
    - econometrics/test/Panel/BuildSpec.hs
    - econometrics/test/fixtures/subgraph-sample.json
    - econometrics/test/Model/NLSSpec.hs
    - notes/structural-econometrcics/data/DATA-SOURCES.md
    - notes/structural-econometrcics/data/panel.csv
    - notes/structural-econometrcics/data/variance.csv
decisions:
  - "Unit of observation changed to the ACCRUAL SPELL: the live subgraph has no per-epoch premium series (TokenId.snapshots absent, premiumSettleds empty, premiaSettled*Total identically zero). Spreading spell premium across days was REJECTED as manufacturing a mechanical null."
  - "Leg.strike is already an int24 tick; the 09-04 round(log K / log 1.0001) map was a bug producing NaN on negative strikes."
  - "premium0 (ETH, 18 dec) converted at the burn-tick price, not premium1 (USDC, 6 dec truncates small premia to zero): 61 usable observations vs 38."
  - "Long positions sign-flipped to the seller-side convention, else the same vega enters with two opposite signs and cancels."
  - "Model.NLS multi-starts from data-scaled values; a fixed kappa=0.2 start is numerically dead when moneyness is measured in ticks."
  - "kappa is reported as STRUCTURALLY UNIDENTIFIED (test vacuous) whenever the fitted vega term is numerically extinguished, rather than reporting a fails-to-reject."
metrics:
  duration_minutes: 195
  tasks: 2
  files_changed: 16
  completed: 2026-07-20
---

# Phase 9 Plan 09: Live Upsilon Estimation Run Summary

Ran the full υ-identification pipeline on live Base Panoptic + Uniswap V4 data and got an **honest null**: the fitted vega level is numerically zero, which leaves κ structurally unidentified and the Lean formal witness unestablished.

## What was built

**`econometrics/src/Alternatives.hs`** — the four locked spec §6.2 alternatives, and only those four: semiparametric υ(moneyness) on a degree-0 B-spline (regressogram) basis over moneyness quantile knots; the seed tick-linearization with the strike centered at the mean pool tick; the tokenId-FE within estimator with κ concentrated over a grid; and the demoted collateral-channel equation. Every estimator carries an `estIdentified` flag and returns a *reason* rather than a number when the design cannot support it.

**A rebuilt panel pipeline.** `Panel.Subgraph` and `Panel.Build` were written in 09-04 against an assumed schema that does not exist. They now query the real one.

**A live analysis output** (`notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates.md`) that is self-describing end to end: endpoint, RPC, block range, cache paths, row counts, epoch definition, seven numbered construction steps, estimator, SE construction, and copy-pasteable reproduce commands.

## What the data actually was

| quantity | value |
|---|---|
| V4 Swap logs pulled | 632,315 (blocks 43,781,657 – 48,879,461; 510 chunked calls) |
| daily variance epochs | 119 |
| OptionMints / OptionBurns / tokenIds | 1447 / 1432 / 768 |
| accrual spells (usable observations) | **61** |
| distinct tokenIds / accounts | 55 / **4** |
| moneyness support | 34 above the money, 27 below |

## Headline result — a null

`υ̂₀ = 2.27e-9` (tokenId-clustered SE 1.26e-4) is numerically zero. Since κ enters the model *only* through `υ₀·exp(−κ·d)·σ̂²`, a vanishing υ₀ extinguishes the whole term and leaves **κ structurally unidentified** (SE 18.8 — three orders of magnitude larger than the estimate). The best fit to the cross-section is a constant premium rate `β̂₀ = 2.36e-4` USD/day (SE 8.8e-5).

The κ>0 test is therefore **vacuous**, not "fails to reject", and the output says so in a call-out box. The formal witness of the proved `Upsilon.exp_family_witnesses_ATMOTM` **does not obtain**; the analysis states plainly that this says nothing about the conjecture, which remains open — the Lean theorem is still proved and axiom-clean.

Alternatives: semiparametric profile **not interpretable** (non-monotone, bins dwarfed by their SEs); seed-linear γ = +5.5e-4, the *opposite* sign to what κ>0 predicts; position-FE **not identified** (11 observations across 5 multi-spell tokenIds, minimizer on the grid boundary); collateral channel estimated but on *deposited* collateral, not the protocol's required Q_M.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 + Rule 3 — Bug/Blocker] The panel pipeline queried a schema that does not exist**

- **Found during:** Task 2, before any data could be pulled.
- **Issue:** Plan 09-04 assumed `TokenId.snapshots` carrying cumulative `premiaSettledInUsdTotal`, and a price-valued `Leg.strike`. Live introspection: `TokenId` has no `snapshots` field; there is no `premiaSettledInUsdTotal` anywhere; `premiumSettleds` is empty and `AccountBalance.premiaSettled{0,1}Total` is identically zero across the entire market; `Leg.strike` is already an int24 tick, so `round(log K / log 1.0001)` was taking the logarithm of a negative number and yielding NaN.
- **Fix:** Rewrote `Panel.Subgraph` against the real collections (`optionMints`, `optionBurns`, `tokenIds { legs }`, collateral flows) with timestamp-cursor pagination; rewrote `Panel.Build` to assemble accrual spells; rebuilt the fixture and `BuildSpec`.
- **Commit:** `b8b49aa`

**2. [Rule 1 — Bug] The NLS optimizer was returning a start-value artifact, not an estimate**

- **Found during:** Task 2, reviewing the first live run (which reported κ = 0.384, υ₀ = −209).
- **Issue:** κ enters as `exp(−κ·d)` with `d` a *tick* distance (live median 153, max 2954). The fixed start κ = 0.2 evaluates `exp(−0.2·153) ≈ 5e−14`: the model is numerically zero at the start point, `∂f/∂υ₀` and `∂f/∂κ` both vanish, and Levenberg–Marquardt cannot move. This was the single most dangerous defect found — it produced a plausible-looking positive κ that was pure numerical noise.
- **Fix:** `Model.NLS.multiStarts` derives start values from the data (κ ~ 1/median(d), υ₀ ~ median(π)/median(σ̂²), both signs) and `fitGSLCov` keeps the lowest-SSE finite solution. Added an `NLSSpec` regression at live tick scale that the old fixed start cannot pass.
- **Commit:** `bb15a96`

**3. [Rule 2 — Missing critical functionality] RPC robustness for a ~500-call pull**

- **Found during:** Task 2. The first full-history attempt completed 509 of 510 chunks and then threw all of it away, because `--to` was past the chain head and the resulting error is non-transient.
- **Fix:** bounded exponential backoff on `eth_getLogs`; `toBlock` clamped to the chain head less a 60-block safety margin; per-chunk streaming to the tick cache; progress reporting.
- **Commits:** `dab55c7`, `b8b49aa`

**4. [Rule 2 — Missing critical functionality] Honest-reporting guards in the generated prose**

- **Found during:** Task 2, reviewing the generated analysis output rather than assuming it was right.
- **Issues found and fixed:** the witness section reported `hu SATISFIED` for υ₀ = 2e-9 while the verdict two lines later said it failed (a self-contradiction); the semiparametric read-off claimed the profile "DECLINES — the direction the conjecture predicts" off a curve that is non-monotone and dwarfed by its SEs; the seed-linear note asserted "γ<0 is the linear echo of κ>0" while the estimate was γ = +5.5e-4; position-FE reported an identified κ that was sitting on the grid boundary; the collateral channel reported a υ̂ without the caveat that its Q_M is deposited collateral, not required margin.
- **Commit:** `bb15a96`

### Judgement call flagged for the 09-11 audit

**The unit of observation changed from position-epoch to accrual spell.** This is a genuine departure from the binding spec (§1, §4.4), not a bug fix, and it was made because the spec's object is not constructible from the live data. It was taken under the plan's explicit instruction to "report what the data actually supports" and is documented loudly in the module header, the panel CSV banner, `DATA-SOURCES.md` §5, and as section 1 and threat 1 of the analysis output.

The cost is real and is stated: there is no within-position time variation, so υ₀ is identified off cross-spell covariation rather than the within-position covariation spec §4.4 intends, and the position-FE selection diagnostic is unavailable. **The audit should scrutinize this decision specifically.** The alternative — spreading each spell's premium uniformly across its days — was rejected because a constant π against a varying σ̂² would manufacture a mechanical null.

## Authentication gates

None. The Goldsky Base subgraph and the public Base RPC are both keyless; no `GRAPH_API_KEY` was needed, requested, or committed.

## Verification

- `stack test` — **59 examples, 0 failures** (was 40; +19 across `AlternativesSpec`, the rebuilt `BuildSpec`, and the NLS tick-scale regression).
- `lake build vol_markets` — exit 0, 8032 jobs. The witness cites a real, proved, axiom-clean lemma.
- No home-absolute paths, no secrets in any tracked output.
- The 570k-row raw tick cache is gitignored (regenerable); the derived per-epoch `variance.csv` is tracked.

## Self-Check: PASSED

All created files verified present on disk; all commit hashes verified in `git log`.
