---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 07
subsystem: validation-gate
tags: [reconciliation, gate, premium, wei, stratification, telescoping, haskell, offline-tests, cli]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 04
    provides: "Panoptic.Chunk: ChunkKey, LegChunk (lcLegIndex/lcChunkKey/lcIsLong/lcLiquidity), resolveLegChunks, storedValueTick"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 05
    provides: "Panoptic.Premium: premiumWei (X64 + long-negate), accDelta (diffMod 128), telescope (EXACT decomposition), PremiumFlag ChunkEmpty/AccFrozen/Extrapolated, isFrozenAcc"
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 06
    provides: "premium-accumulators.csv (8,910 rows incl. 130 exact-block mint/burn endpoint rows) + Panoptic.ReadDriver AccRow/AccKey/loadAccumulators"
provides:
  - "Panel.Reconcile: SpellRecon, reconstructSpell/reconstructSpellWith, AccIndex/buildAccIndex, ErrorDist/errorDist, stratify, reportOf (THE verdict rule), reconcileSpells, reconcile, renderReconReport, gateTolerance = 0.01, GroundTruthUnit/classifyGroundTruthUnit/groundTruthWei/groundTruthExpr"
  - "reconcile CLI subcommand (--endpoint/--pool/--accumulators/--panel/--legs/--report/--limit/--only-short/--max-legs), non-zero exit on GATE: FAIL"
  - "notes/structural-econometrcics/data/reconcile-precheck.md — the 5-spell pre-check: median rel error 0.0, max 2.18e-9, GATE PASS"
  - "The MEASURED ground-truth unit determination: OptionBurn.premium0 is already raw 18-decimal units (RawWei), truthWei = round(premium0)"
affects: [10-08, 10-09, 10-10, 10-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The gate runs in Integer ETH wei end to end; the first Double in the path is srRelError. No price conversion appears anywhere in Reconcile.hs — enforced by an acceptance grep that forbids the string entirely."
    - "gateTolerance is ONE named top-level constant, referenced by the CLI and the spec alike, so relaxing it is a visible reviewable diff rather than an inline edit. Verified untouched after the pre-check run (git diff on Reconcile.hs empty)."
    - "reportOf is the SINGLE verdict rule; reconcileSpells and the spec both go through it, so the pass/fail definition cannot drift between the gate and its test."
    - "The ground-truth unit is CLASSIFIED from observed magnitude and the converting expression is printed into the report — a 1e18 unit error is the cheapest catastrophic failure to rule out first, so it is ruled out explicitly rather than assumed away."
    - "The endpoint lookup key drops atTick: an endpoint read is scheduled at the exact mint/burn block, but the pool-wide dedup can retain an interior row when the two coincide on a block. Keying on the block finds the reading either way, with the endpoint-tagged row preferred."

key-files:
  created:
    - "econometrics/src/Panel/Reconcile.hs"
    - "econometrics/test/Panel/ReconcileSpec.hs"
    - "notes/structural-econometrcics/data/reconcile-precheck.md"
    - ".planning/phases/10-streaming-premium-reconstruction-and-reestimation/deferred-items.md"
  modified:
    - "econometrics/app/Main.hs"
    - "econometrics/package.yaml"
    - "econometrics/test/Spec.hs"

key-decisions:
  - "The VERDICT is scored on the SHORT stratum plus the absence of leg-count mismatches; the long stratum is reported in full but excluded from the pass/fail arithmetic. _getAvailablePremium (PanopticPool L588-599) caps SETTLED long premium while the accumulator reports ACCRUED premium, so a long-stratum wedge is a known protocol behaviour, not a reconstruction defect. RESEARCH's instruction is exact on both halves: do not let capped longs fail a gate the shorts pass, and do not hide them."
  - "A leg-count mismatch fails the gate rather than merely being reported: if the reconstruction did not cover every leg the scalar premium0 sums over, the comparison was not like-for-like and a small relative error would be an accident (RESEARCH Pitfall 7)."
  - "GROUND-TRUTH UNIT DETERMINED, NOT ASSUMED: OptionBurn.premium0 arrives ALREADY in raw 18-decimal units (median non-zero magnitude ~1e11..1e12), so truthWei = round(premium0) with NO 1e18 factor. Corroborated independently by Panel.Build.premiumUsd, which divides bePremium0 by 1e18 before pricing."
  - "The pre-check filter needed a --max-legs option the plan did not list: --only-short --limit 5 selects the short stratum but does not guarantee the SINGLE-LEG cases RESEARCH's procedure prescribes. Added --max-legs N (0 = any) rather than hiding a leg-count preference inside --limit's ordering."
  - "panel.csv is treated as THE gate population (the 61 Phase-9 spells) and the authority on is_long; disagreement with the leg-derived stratum is COUNTED and reported (LABEL_DISAGREEMENTS), never silently resolved in favour of one side. Measured 0."
  - "The diagnosis section (pre-committed bands + the 2^64/2^128/1e12/1e18 scaling-signature check) is rendered from app/Main.hs, not Reconcile.hs, so the tolerance module stays byte-identical across the task-2 commit and the 'was the constant edited?' check is trivially auditable."

patterns-established:
  - "Pre-committed interpretation bands are rendered INTO the artifact by the tool, with the observed band selected mechanically — the reading of a number cannot be renegotiated after seeing it."
  - "An automatic factor-signature check (|recon|/|truth| against 2^64, 2^128, 1e12, 1e18 and their reciprocals) turns RESEARCH Pitfall 2's diagnostic list into a machine check instead of a human habit."

requirements-completed: [CTX-GATE]

# Metrics
duration: ~95min
completed: 2026-07-26
---

# Phase 10 Plan 07: Reconciliation Machinery + 5-Spell Pre-Check Summary

**`Panel.Reconcile` rebuilds each spell's premium from its exact-block mint/burn accumulator readings in Integer ETH wei and scores it against `OptionBurn.premium0` under one named `gateTolerance = 0.01`, stratified short/long and never pooled — and the prescribed 5-spell pre-check returns a median relative error of exactly 0.0 (three spells reconcile to the wei; the worst is 2.18e-9, a −286 wei flooring residual on 1.3e11 wei), so the telescoping decomposition is confirmed sound before the full 61-spell gate is spent.**

## Performance

- **Duration:** ~95 min wall (spanning one session-limit reset; Task 1 landed before it, Task 2 after)
- **Tasks:** 2 (Task 1 TDD/offline, Task 2 live CLI)
- **Files:** 7 (4 created, 3 modified)
- **Suite:** 156 → **176 examples, 0 failures** (+20 offline `Panel.Reconcile` specs)

## Task Commits

1. **Task 1: `Panel.Reconcile` — spell reconstruction, error distribution, stratification** — `a2ad4b6` (feat)
2. **Task 2: `reconcile` CLI and the 5-spell pre-check** — `c7c1bfc` (feat)

## THE PRE-CHECK RESULT

Full CLI stdout, verbatim:

```
reconcile: 1602 mints, 1586 burns, 61 paired accrual spells
SPELLS_RECONCILED: 5
GROUND_TRUTH_UNIT: RawWei
GROUND_TRUTH_EXPR: truthWei = round(premium0)                -- premium0 is ALREADY raw 18-decimal units
MEDIAN_REL_ERROR_ALL: 0.000000
MEDIAN_REL_ERROR_SHORT: 0.000000
MEDIAN_REL_ERROR_LONG: n/a
P90_REL_ERROR_SHORT: 2.184691e-9
MAX_REL_ERROR_SHORT: 2.184691e-9
SIGNED_BIAS_SHORT: 0/2
LEGCOUNT_MISMATCHES: 0
ZERO_TRUTH_EXCLUDED: 0
LABEL_DISAGREEMENTS: 0
CENSUS_MISMATCHES: 0
GATE_TOLERANCE: 0.01
GATE: PASS
reconcile: wrote notes/structural-econometrcics/data/reconcile-precheck.md
```

Per-spell (short stratum, single-leg, first 5 by burn epoch):

| tokenId | recon wei | truth wei | rel error | signed error wei |
|---|---|---|---|---|
| `13928862935350657410259648809994` | 2198627894 | 2198627894 | 0 | 0 |
| `13928885602709775184556674550794` | 1918515357 | 1918515357 | 0 | 0 |
| `305488671002481536027468369529866` | 993545060839 | 993545060839 | 0 | 0 |
| `305488695927131832613455807417354` | 130910962607 | 130910962893 | 2.184691e-9 | −286 |
| `305488725394698685720041940880394` | 195874484857 | 195874485096 | 1.220169e-9 | −239 |

**Diagnosis: band `< 0.01` — the machinery is sound.** Three of five spells reproduce the protocol's own `premiaByLeg` **exactly, to the wei**. The two misses are −286 and −239 wei against premia of ~1.3e11 and ~2.0e11 wei: strictly one-signed (`SIGNED_BIAS_SHORT: 0/2`, both under), which is the signature of the integer-`div` flooring wedge RESEARCH sized at "< 1 wei per leg per touch" accumulating over a spell's touches — **not** a multiplier bug, which would bias both directions or scale with the premium. The automatic scaling-signature check is clean: no spell's `|recon|/|truth|` ratio sits within 1% of 2^64, 2^128, 1e12 or 1e18 or their reciprocals.

**This is the expected shape of a correct result, not a lucky one.** The panel is a *decomposition* of the ground truth (`Panoptic.Premium.telescope` asserts the identity as exact integer equality), so exactness up to flooring is what the structural argument predicts. A median in [0.01, 0.10) would have meant an unaccounted wedge; the pre-check exists precisely to distinguish those two worlds before 61 spells are spent.

## Ground-truth unit determination (verified, not assumed)

`BurnEvent.bePremium0` is a `Double` decoded from the subgraph's BigInt string, so its unit was **measured**: the median non-zero magnitude on this market is ~1e11–1e12, twelve orders of magnitude away from the ~1e-7 an ETH-denominated figure would show. Determination: **`RawWei`** — already raw 18-decimal units — so

```
truthWei = round(premium0)          -- NO 1e18 factor
```

Corroborated independently: `Panel.Build.premiumUsd` divides `bePremium0` by `1e18` before pricing, which only makes sense if the field is raw. Every magnitude here is far under `2^53`, so the `Double` round-trip is exact. The determination and the converting expression are both written into the report.

## Accomplishments

- **Built the gate's arithmetic in exact `Integer` wei.** `reconstructSpell` reads the accumulator at the EXACT mint block and EXACT burn block (the `rrEndpoint = mint|burn` rows 10-06 wrote — not the nearest epoch boundary, which RESEARCH lists as a wedge), takes the gross accumulator for short legs and the owed one for long legs, computes `premiumWei accBurn accMint (lcLiquidity lc) (lcIsLong lc)` per leg and sums over legs. No `Double` appears until `srRelError`. A spec case proves exactness past the `2^53` mantissa (a premium of 1.357e16 wei reconstructed bit-for-bit).
- **Made the short/long split structural, not editorial.** `stratify` produces two independent `ErrorDist`s and `reportOf` scores the verdict on the short one, with the long stratum rendered in full alongside. The report says in prose why: `_getAvailablePremium` caps settled long premium, so the long wedge is protocol behaviour.
- **Surfaced leg-count mismatches as gate failures.** `srLegCount` (legs actually reconstructed) versus `srLegCountTruth` (legs the scalar `premium0` sums over) — a mismatch lands in `rrMismatches`, prints as `LEGCOUNT_MISMATCHES`, and fails the gate, because a like-for-unlike comparison that happens to be close is worse than one that is loudly wrong.
- **Gave the error distribution its diagnostic content.** `errorDist` reports median/p25/p75/p90/max plus over- and under-reconstruction counts (the sign bias that separates a multiplier bug from rounding) plus the count of spells excluded for zero ground truth. An empty set yields NaN quantiles, never a 0 that would read as a perfect gate.
- **Kept the tolerance a single auditable symbol.** `gateTolerance = 0.01` is defined once and referenced by the CLI, the report and the spec. It was not touched during the pre-check: `git diff` on `Reconcile.hs` across the task-2 commit is empty (0 lines matching `gateTolerance.*=`), which is exactly the check the plan pre-committed. The diagnosis renderer lives in `app/Main.hs` specifically to preserve that property.
- **Cross-checked the gate's own inputs.** `panel.csv` supplies the population and the `is_long` labels (`LABEL_DISAGREEMENTS: 0` against the leg-derived stratum) and `chunk-legs.csv` cross-checks the resolved chunk ranges (`CENSUS_MISMATCHES: 0`). Both are reported as counts, so a future drift in the geometry or the labelling is visible in the same block as the verdict.

## Panel.Reconcile public API

```
gateTolerance :: Double                                        -- 0.01, THE constant
data GroundTruthUnit = RawWei | WholeEth
classifyGroundTruthUnit :: [BurnEvent] -> GroundTruthUnit
groundTruthWei  :: GroundTruthUnit -> BurnEvent -> Integer
groundTruthExpr :: GroundTruthUnit -> Text
type SpellInput = (Text, MintEvent, BurnEvent, [LegChunk])
data SpellRecon = SpellRecon { srTokenId, srIsLong, srLegCount, srLegCountTruth
                             , srReconWei, srTruthWei, srRelError, srSignedErrorWei
                             , srFlags, srMintBlock, srBurnBlock }
type AccIndex ; buildAccIndex :: Map AccKey AccRow -> AccIndex
reconstructSpell     :: Map AccKey AccRow -> SpellInput -> SpellRecon
reconstructSpellWith :: GroundTruthUnit -> AccIndex -> SpellInput -> SpellRecon
data ErrorDist = ErrorDist { edN, edMedian, edP25, edP75, edP90, edMax
                           , edPosCount, edNegCount, edZeroTruth }
errorDist :: [SpellRecon] -> ErrorDist
stratify  :: [SpellRecon] -> (ErrorDist, ErrorDist)             -- (short, long)
data ReconReport = ReconReport { rrSpells, rrAll, rrShort, rrLong
                               , rrMismatches, rrPassed, rrUnit, rrLineage }
reportOf          :: [(Text,Text)] -> GroundTruthUnit -> [SpellRecon] -> ReconReport
reconcileSpells   :: [(Text,Text)] -> Map AccKey AccRow -> [SpellInput] -> ReconReport
reconcile         :: FilePath -> [SpellInput] -> IO ReconReport
renderReconReport :: ReconReport -> Text
```

## Verification

- `stack test econometrics:test:unit --fast --ta '-m "Panel.Reconcile"'` — **20/0**.
- `stack test` — **176 examples, 0 failures** (156 baseline + 20).
- `stack exec econometrics -- reconcile --help` — exit 0.
- All Task-1 acceptance greps PASS: `Panel.ReconcileSpec` in `package.yaml`; `gateTolerance ::` and `0.01` present; `stratify` and `srLegCountTruth` present; **no price-unit string anywhere in `Reconcile.hs`**; no URL in the spec.
- All Task-2 acceptance greps PASS: report exists with `median_rel_error`, names the unit (`wei`), carries 5 per-spell data rows, no home-absolute paths; `GATE_TOLERANCE: 0.01` in the captured stdout; `git diff` on `Reconcile.hs` = 0 tolerance lines.
- `stack build` introduced **zero new warnings** (the three `-Wall` warnings in `app/Main.hs` are pre-existing from 09-09/10-03 — logged in `deferred-items.md`, not touched).

## Deviations from Plan

### Auto-fixed / added

**1. [Rule 2 - Missing critical functionality] Added a `--max-legs N` CLI option**
- **Found during:** Task 2, wiring the pre-check invocation.
- **Issue:** RESEARCH's procedure is explicit that the pre-check runs on **5 short SINGLE-LEG spells**, but the plan's option list (`--only-short --limit 5`) selects the short stratum without constraining the leg count. On this market 11 tokenIds carry 2 legs and one carries 3, so the selection was not guaranteed to be single-leg.
- **Fix:** Added `--max-legs N` (0 = any). The pre-check runs `--only-short --max-legs 1 --limit 5`. The alternative — quietly ordering `--limit` to prefer few-leg spells — was rejected as hiding a selection rule inside an unrelated flag.
- **Files:** `econometrics/app/Main.hs`. **Commit:** `c7c1bfc`.

**2. [Rule 1 - Bug] `GATE_TOLERANCE` printed as `1.0e-2`, not `0.01`**
- **Found during:** Task 2 acceptance sweep.
- **Issue:** Haskell's `show (0.01 :: Double)` renders `1.0e-2`. The plan's acceptance criterion greps the CLI stdout for the literal `GATE_TOLERANCE: 0.01`, and gate scripts / the 10-08 checkpoint will do the same. A grep that silently never matches is exactly the failure mode this line exists to prevent.
- **Fix:** `showFFloat Nothing gateTolerance ""` — plain decimal. The constant itself is unchanged.
- **Files:** `econometrics/app/Main.hs`. **Commit:** `c7c1bfc`.

**3. [Test-truthfulness] Pre-check fixtures rescaled to realistic wei magnitudes**
- **Found during:** Task 1, first spec run (`relError` case failed: expected −1024, got −1.33e22).
- **Issue:** The first draft used toy fixtures whose "wei" ground truth was ~1.2e4. Since the ground-truth unit is CLASSIFIED from magnitude, a truth of 12288 is (correctly) read as whole tokens and scaled by 1e18. The test was wrong, not the code — and the failure is itself evidence the classifier works.
- **Fix:** Sized the fixture leg liquidity so the synthetic premium lands at ~1.2e13 wei, the order this market actually produces. Documented in the fixture comment so a future editor does not shrink it back.
- **Files:** `econometrics/test/Panel/ReconcileSpec.hs`. **Commit:** `a2ad4b6`.

**4. [Design] `reportOf` extracted so the verdict rule has ONE definition**
- **Found during:** Task 1, writing the spec.
- **Issue:** The spec needed to build a `ReconReport` from synthetic `SpellRecon`s without going through the accumulator map, and the first draft re-implemented the pass/fail arithmetic in the test file — meaning the spec could pass while disagreeing with the CLI about what a pass is.
- **Fix:** Factored `reportOf` out of `reconcileSpells` and routed both the spec and the CLI through it.
- **Files:** `econometrics/src/Panel/Reconcile.hs`. **Commit:** `a2ad4b6`.

### Additions beyond the plan's letter

- **The `AccIndex` lookup key drops `atTick`.** The plan says to look up "the accumulator at the exact mint block and the exact burn block". Keying on the full 6-tuple including `atTick` would miss a reading whenever `buildReadSchedule`'s pool-wide dedup retained an interior epoch-boundary row (with the epoch's tick) at a block that coincides with a mint/burn. Keying on `(chunk, block, isLong)` and PREFERRING the endpoint-tagged row finds it either way; a spec case pins the preference.
- **Automatic scaling-signature check** rendered into the report (ratio against 2^64 / 2^128 / 1e12 / 1e18 and reciprocals), turning RESEARCH Pitfall 2's diagnostic list into a machine check.
- **`LABEL_DISAGREEMENTS` and `CENSUS_MISMATCHES`** reported alongside the verdict, cross-checking the gate's own inputs against `panel.csv` and `chunk-legs.csv`.

### Not done (correctly)

- **The full 61-spell gate was NOT run.** That is 10-08's checkpoint, and the plan is explicit that this plan stops at the pre-check.
- **`gateTolerance` was not modified.** It was not close to being needed — the observed median is 0.0 — but the property was checked rather than assumed.

## Authentication Gates

None. The pre-check used the keyless public Goldsky Base subgraph (no `GRAPH_API_KEY` needed, none set) and read accumulators from the committed CSV — no RPC call, no secret, no credential printed.

## Issues Encountered

- One spec failure during iteration (the toy-magnitude ground-truth misclassification above), which was a test-side truthfulness fix surfacing correct behaviour, not a source defect.
- All five pre-check spells carry `ChunkEmpty` + `Extrapolated` flags. Investigated rather than waved through: `ChunkEmpty` fires because `netLiquidity == 0` at the **burn** block — the normal state, since the burn removed the position's liquidity, so `getAccountPremium` returns the STORED accumulator instead of extrapolating. That stored value is exactly what `_getPremia` itself consumed, which is *why* these spells still reconcile to the wei. The explanation is rendered into the report so 10-08 does not re-litigate it.

## Next Phase Readiness

- **10-08 (the hard gate):** run `reconcile` over all 61 spells with no selection flags. The machinery is proven; what 10-08 measures is the *sample*, in particular the 8 long spells where `_getAvailablePremium`'s settlement cap is expected to bite. Read the two strata separately — the short stratum is the verdict, the long stratum is the diagnosis. `gateTolerance` stays 0.01.
- **Expected shape at 61:** the short stratum should stay at the flooring residual (~1e-9). Any short-stratum spell materially above that is a multi-leg summation or a mid-spell `s_options` rewrite, not rounding — the two wedges the pre-check's single-leg population could not exercise.
- **10-09 onward:** the panel may be built on the reconstruction with confidence that it decomposes the ground truth; `PremiumFlag`s continue to flow so the estimation can stratify on them.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-26*

## Self-Check: PASSED

- All 8 claimed files exist on disk (4 created, 3 modified, + this SUMMARY).
- Both task commits (`a2ad4b6`, `c7c1bfc`) exist in history.
- Suite 156 -> 176/0; `gateTolerance = 0.01` present as one named constant and unmodified by the task-2 commit (`git diff HEAD~1 -- econometrics/src/Panel/Reconcile.hs` matches 0 tolerance lines); no price-unit string in `Reconcile.hs`; no URL in `ReconcileSpec.hs`; pre-check report carries `median_rel_error`, the unit determination, 5 per-spell rows and no home-absolute paths.
