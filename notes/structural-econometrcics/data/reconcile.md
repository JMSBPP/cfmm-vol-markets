# Reconciliation — reconstructed spell premium vs `OptionBurn.premium0`

**Units: ETH wei on `premium0`.** No price conversion appears anywhere in the
gate path (token1's 6 decimals truncate small premia, and a conversion factor
is exactly the noise a 1% target cannot absorb).

## Lineage

| what | value |
|---|---|
| measured | `2026-07-26` |
| git commit | `71267d3` |
| command line | `econometrics reconcile --endpoint https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn --pool 0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a --accumulators notes/structural-econometrcics/data/premium-accumulators.csv --panel notes/structural-econometrcics/data/panel.csv --legs notes/structural-econometrcics/data/chunk-legs.csv --report notes/structural-econometrcics/data/reconcile.md --errors-csv notes/structural-econometrcics/data/reconcile-errors.csv` |
| working directory | `repository root (all paths below are repo-relative)` |
| subgraph endpoint | `https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn` |
| underlying pool (V4 poolId) | `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a` |
| SFPM read target | `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` |
| VEGOID / nu | `8 / 0.125 — applied INSIDE the contract's X64 accumulator; never re-applied here` |
| accumulator readings | `notes/structural-econometrcics/data/premium-accumulators.csv` |
| accumulator rows loaded | `8910` |
| accumulator block range | `43781657..48157721` |
| gate population (panel) | `notes/structural-econometrcics/data/panel.csv` |
| per-leg census | `notes/structural-econometrcics/data/chunk-legs.csv` |
| epoch definition | `floor(unixSeconds/86400) — Panel.Build.dailyEpoch, the panel.csv grid that ORDERS spells. The gate itself compares SPELL-ENDPOINT totals and uses no epoch grid.` |
| paired spells (subgraph) | `61` |
| spells in the gate population | `61` |
| selection | `both strata` |
| spells reconciled | `61` |
| is_long label disagreements | `0` |
| chunk-range census mismatches | `0` |
| per-spell error CSV | `notes/structural-econometrcics/data/reconcile-errors.csv` |
| ground-truth unit | `RawWei` |
| converting expression | `truthWei = round(premium0)                -- premium0 is ALREADY raw 18-decimal units` |
| gate tolerance (`gateTolerance`) | `1.0e-2` |

## Verdict labels (verbatim CLI stdout)

```
SPELLS_RECONCILED: 61
GROUND_TRUTH_UNIT: RawWei
GROUND_TRUTH_EXPR: truthWei = round(premium0)                -- premium0 is ALREADY raw 18-decimal units
MEDIAN_REL_ERROR_ALL: 0.000000
N_SHORT: 53
MEDIAN_REL_ERROR_SHORT: 0.000000
P25_REL_ERROR_SHORT: 0.000000
P75_REL_ERROR_SHORT: 0.000000
P90_REL_ERROR_SHORT: 1.220169e-9
MAX_REL_ERROR_SHORT: 5.447268e-4
SIGNED_BIAS_SHORT: 3/5
N_LONG: 8
MEDIAN_REL_ERROR_LONG: 0.000000
P25_REL_ERROR_LONG: 0.000000
P75_REL_ERROR_LONG: 0.000000
P90_REL_ERROR_LONG: 0.000000
MAX_REL_ERROR_LONG: 0.000000
SIGNED_BIAS_LONG: 0/0
LEGCOUNT_MISMATCHES: 0
ZERO_TRUTH_EXCLUDED: 0
LABEL_DISAGREEMENTS: 0
CENSUS_MISMATCHES: 0
GATE_TOLERANCE: 0.01
GATE: PASS
```

## Strata

Reported SEPARATELY and never pooled. `_getAvailablePremium` (PanopticPool
L588-599) caps SETTLED long premium at what the pool can pay while the
accumulator reports ACCRUED premium, so a downward long-stratum wedge is
expected. The verdict is scored on the short stratum; the long stratum is
reported in full and neither hidden nor allowed to fail a gate the shorts pass.

| stratum | n | median | p25 | p75 | p90 | max | recon>truth | recon<truth | zero-truth excluded |
|---|---|---|---|---|---|---|---|---|---|
| short | 53 | 0.000000 | 0.000000 | 0.000000 | 1.220169e-9 | 5.447268e-4 | 3 | 5 | 0 |
| long | 8 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0.000000 | 0 | 0 | 0 |
| all (diagnostic only) | 61 | 0.000000 | 0.000000 | 0.000000 | 1.299713e-10 | 5.447268e-4 | 3 | 5 | 0 |

## Per-spell

| tokenId | isLong | legs | legs (truth) | recon wei | truth wei | rel error | signed error wei | flags |
|---|---|---|---|---|---|---|---|---|
| `13928819111789696379952065711114` | short | 1 | 1 | 48636641935 | 48636641935 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928847823777912227394964982794` | short | 1 | 1 | 718056392186 | 718056392185 | 1.392648e-12 | 1 | ChunkEmpty,Extrapolated |
| `13928847828500278710264610196490` | long | 1 | 1 | -380147501744 | -380147501744 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928856890721559337113775279114` | short | 1 | 1 | 1499290138 | 1499290138 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928862935350657410259648809994` | short | 1 | 1 | 2198627894 | 2198627894 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928862940073023893129294023690` | long | 1 | 1 | -1163979473 | -1163979473 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928864455971111638359117171722` | short | 1 | 1 | 76256917263 | 76256917263 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928865211549748897502351363082` | short | 1 | 1 | 994177330 | 994177330 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928867468822480965119053958154` | short | 1 | 1 | 13604763017 | 13604763017 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928867473544847447988699171850` | long | 1 | 1 | -7202521597 | -7202521597 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928870491137030001691990723594` | short | 1 | 1 | 642777340353 | 642777340353 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928877300807945043794098424842` | short | 1 | 1 | 9607539145 | 9607539145 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928877305530311526663743638538` | long | 1 | 1 | -5086344253 | -5086344253 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928881069237951629697269402634` | short | 1 | 1 | 7151835272 | 7151835272 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928885602709775184556674550794` | short | 1 | 1 | 1918515357 | 1918515357 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928890136181598739416079698954` | short | 1 | 1 | 76677612971 | 76677612971 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928891647338873257702548081674` | short | 1 | 1 | 43263719609 | 43263719609 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928893158496147775989016464394` | short | 1 | 1 | 2150673791 | 2150673791 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928893914074785035132250655754` | short | 1 | 1 | 894899682 | 894899682 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928894669653422294275484847114` | short | 1 | 1 | 82843884 | 82843884 | 0.000000 | 0 | Extrapolated |
| `13928894669653422294275484847114` | short | 1 | 1 | 919360486 | 919360486 | 0.000000 | 0 | Extrapolated |
| `13928894669653422294275484847114` | short | 1 | 1 | 587950043 | 587950043 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928896180810696812561953229834` | short | 1 | 1 | 3363459397 | 3363459397 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928896945852513781518187400202` | short | 1 | 1 | 60288162 | 60288162 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928901479324337336377592548362` | short | 1 | 1 | 28776357 | 28776357 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928902234902974595520826739722` | short | 1 | 1 | 9731965 | 9731965 | 0.000000 | 0 | Extrapolated |
| `13928902234902974595520826739722` | short | 1 | 1 | 4657427 | 4657427 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928902990481611854664060931082` | short | 1 | 1 | 851616 | 851616 | 0.000000 | 0 | Extrapolated |
| `13928902990481611854664060931082` | short | 1 | 1 | 68134 | 68134 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928904501638886372950529313802` | short | 1 | 1 | 23025484918 | 23025484918 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928905247754343922280763526154` | short | 1 | 1 | 57146686 | 57146686 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928908270068892958853700291594` | short | 1 | 1 | 49044577 | 49044577 | 0.000000 | 0 | Extrapolated |
| `13928909025647530217996934482954` | short | 1 | 1 | 6779769 | 6779769 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928909781226167477140168674314` | short | 1 | 1 | 49120937 | 49120937 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928909790689347186953168653322` | short | 1 | 1 | 3602433914 | 3602433914 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928911292383441995426637057034` | short | 1 | 1 | 23305055 | 23305055 | 0.000000 | 0 | Extrapolated |
| `13928913559119353772856339631114` | short | 1 | 1 | 625437638 | 625437638 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928913568582533482669339610122` | short | 1 | 1 | 889355057 | 889355057 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928916590897082519242276375562` | short | 1 | 1 | 819864 | 819864 | 0.000000 | 0 | Extrapolated |
| `13928916590897082519242276375562` | short | 1 | 1 | 1488635 | 1488635 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928917346475719778385510566922` | short | 1 | 1 | 70487986 | 70487986 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928918102054357037528744758282` | short | 1 | 1 | 809988325 | 809988325 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928918857632994296671978949642` | short | 1 | 1 | 56229 | 56229 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928921124368906074101681523722` | short | 1 | 1 | 21141312857 | 21141312857 | 0.000000 | 0 | Extrapolated |
| `13928921124368906074101681523722` | short | 1 | 1 | 3612956293 | 3612956293 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928921879947543333244915715082` | short | 1 | 1 | 23343268 | 23343268 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928930946891190442963726011402` | short | 1 | 1 | 31238869506 | 31238869506 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928953614250308217260751752202` | short | 1 | 1 | 19165725807 | 19165725807 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928953618972674700130396965898` | long | 1 | 1 | -10146560721 | -10146560721 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `171622313847804664062707064823821437228393466890` | short | 2 | 2 | 147824900806 | 147824902150 | 9.091838e-9 | -1344 | ChunkEmpty,Extrapolated |
| `305488578812443057446254507756554` | short | 1 | 1 | 17640584083185 | 17640586041163 | 1.109928e-7 | -1957978 | ChunkEmpty,Extrapolated |
| `305488671002481536027468369529866` | short | 1 | 1 | 993545060839 | 993545060839 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `305488695927131832613455807417354` | short | 1 | 1 | 130910962607 | 130910962893 | 2.184691e-9 | -286 | ChunkEmpty,Extrapolated |
| `305488725394698685720041940880394` | short | 1 | 1 | 195874484857 | 195874485096 | 1.220169e-9 | -239 | ChunkEmpty,Extrapolated |
| `305488797934970229080662068464650` | long | 1 | 1 | -4191932694290 | -4191932694290 | 0.000000 | 0 | Extrapolated |
| `85987406349980496331175231772960871807994858506` | short | 2 | 2 | 119207906749 | 119211783050 | 3.251609e-5 | -3876301 | ChunkEmpty,Extrapolated |
| `85987420383974868125161971211426355718277073930` | short | 2 | 2 | 5547732786 | 5547732786 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `85987421660028551781636802008240109781758020618` | short | 2 | 2 | 515498413186 | 515498413119 | 1.299713e-10 | 67 | ChunkEmpty,Extrapolated |
| `85987421664016235768991544904585048092953840650` | long | 2 | 2 | -38765159456 | -38765159456 | 0.000000 | 0 | Extrapolated |
| `85987421666674691760561367205659696474224102410` | long | 2 | 2 | -330944046651 | -330944046651 | 0.000000 | 0 | Extrapolated |
| `85987442074312111046374787509641907306580446218` | short | 2 | 2 | 5423227721094 | 5420275151957 | 5.447268e-4 | 2952569137 | ChunkEmpty,Extrapolated |

## Leg-count mismatches

None — every spell's reconstruction covered exactly the legs the scalar
ground truth sums over.

## Verdict

median_rel_error: 0.000000

- `MEDIAN_REL_ERROR_SHORT`: 0.000000
- `MEDIAN_REL_ERROR_LONG`: 0.000000
- `GATE_TOLERANCE`: 1.0e-2
- `LEGCOUNT_MISMATCHES`: 0

**GATE: PASS**

## Diagnosis

Pre-committed bands (plan 10-07, stated BEFORE the measurement):

| median rel. error | reading | action |
|---|---|---|
| `< 0.01` | the machinery is sound | proceed to the full 61-spell gate (10-08) |
| `[0.01, 0.10)` | an unaccounted wedge exists | diagnose against the RESEARCH wedge table (long capping, mid-spell `s_options` rewrites, rounding, multi-leg summation, price conversion, epoch-boundary block choice) before running 61 — do NOT proceed on the theory that the full sample averages out |
| `>= 0.10`, or an error near a factor of 2^64 / 2^128 / 1e12 / 1e18 | a scaling or unit bug (RESEARCH Pitfall 2 lists exactly these signatures) | fix the module; do NOT adjust the tolerance |

**Observed band:** `< 0.01`

The reconstruction reproduces the protocol's own `OptionBurn.premium0` to
well inside the 1% tolerance. The residual is the integer-flooring wedge
RESEARCH predicted (`< 1 wei per leg per touch`), not a structural error:
the reconstruction is a *decomposition* of the ground truth, so exactness
up to flooring is the expected outcome rather than a lucky one.

### Worst 5 spells by relative error

8 of 61 reconciled spells differ from the ground truth by any amount at all; 53 reproduce `OptionBurn.premium0` EXACTLY, to the wei.

| tokenId | stratum | legs | rel error | signed error wei | flags |
|---|---|---|---|---|---|
| `85987442074312111046374787509641907306580446218` | short | 2 | 5.447268e-4 | 2952569137 | ChunkEmpty,Extrapolated |
| `85987406349980496331175231772960871807994858506` | short | 2 | 3.251609e-5 | -3876301 | ChunkEmpty,Extrapolated |
| `305488578812443057446254507756554` | short | 1 | 1.109928e-7 | -1957978 | ChunkEmpty,Extrapolated |
| `171622313847804664062707064823821437228393466890` | short | 2 | 9.091838e-9 | -1344 | ChunkEmpty,Extrapolated |
| `305488695927131832613455807417354` | short | 1 | 2.184691e-9 | -286 | ChunkEmpty,Extrapolated |

### Scaling-signature check

**Clean.** No spell's `|recon| / |truth|` ratio sits within 1% of 2^64, 2^128,
1e12 or 1e18 (or their reciprocals) — the four factor signatures RESEARCH
Pitfall 2 names. The unit stack is not the problem.

### Flags observed

61 of 61 reconciled spells carry a flag. The two that appear here are EXPECTED at spell endpoints and are not defects:

- `ChunkEmpty` — `netLiquidity == 0` at an endpoint block. At the BURN block
  this is the normal state: the burn removed the position's liquidity, so
  `getAccountPremium` returns the STORED accumulator rather than a live
  extrapolation. That stored value is exactly what `_getPremia` itself used,
  which is why these spells still reconcile to the wei.
- `Extrapolated` — the read passed a real `atTick` rather than the
  `8388607` stored-value sentinel.

Neither flag is auto-dropped and neither is invisible (10-05 contract).

---

## Worst-5 wedge attribution (authored analysis, 2026-07-26, commit `71267d3`)

*Authored analysis of the run recorded above, written as plan 10-08 Task 1 step 3
requires. It is analysis, not tool output: re-running the `reconcile` CLI
regenerates everything above this rule and drops this section. It is reproduced
verbatim in `.planning/phases/10-streaming-premium-reconstruction-and-reestimation/10-08-SUMMARY.md`.*

### What had to be explained

53 of 61 spells reproduce `OptionBurn.premium0` **exactly, to the wei**, and the
short-stratum median is 0.0. But the 5-spell pre-check (10-07) established a
flooring floor of ~1e-9, and three spells sit far above it: 5.45e-4, 3.25e-5 and
1.11e-7. 10-07 pre-committed the two suspects that its single-leg population
could not exercise — **multi-leg summation** and **mid-spell `s_options`
rewrites**. Both were tested before this report was published. **Both are
refuted.**

### Suspect 1 — multi-leg summation: REFUTED

| legs | spells | above the 1e-9 floor |
|---|---|---|
| 1 | 54 | 3 |
| 2 | 7 | 3 |

A broken summation over legs would miss on *every* multi-leg spell. Four of the
seven two-leg spells reconcile exactly to the wei, and the third-worst spell in
the sample is **single-leg**. Leg count raises *exposure* (two legs = two chunks
= two endpoint readings that can be wrong) but is not the mechanism.

### Suspect 2 — mid-spell `s_options` rewrite: REFUTED

Every one of the 8 imperfect spells was queried against the subgraph for its
complete `optionMints` / `optionBurns` history. All 8 have **exactly one mint and
exactly one burn**, and `positionSize` at the burn is **identical** to
`positionSize` at the mint in all 8 cases. No intermediate mint, no partial burn,
no roll: `s_options[owner][tokenId][leg]` was written once at the mint and read
once at the burn, which is precisely the configuration the reconstruction assumes.

### What it actually is — an END-OF-BLOCK vs AT-TRANSACTION read wedge

`eth_call` resolves state at the **end of a block**. `_getPremia` evaluated the
same accumulator at the **transaction's position inside** that block. Anything
that moves the accumulator between our endpoint transaction and the end of its
block lands in the reconstruction but not in the ground truth (or vice versa).

The sign is fully determined by *which* endpoint's chunk was still live, and the
observed signs obey the rule without exception:

- a swap after the **mint** tx in the mint block inflates `acc(mint)` ⇒ recon too
  **small** ⇒ **negative** (5 spells);
- a swap after the **burn** tx in the burn block inflates `acc(burn)` ⇒ recon too
  **large** ⇒ **positive** — but *only if the chunk still holds net liquidity
  after the burn*, otherwise the accumulator is frozen and there is no wedge.

**Exactly one spell in the sample has a chunk still alive and in range at its burn
block, and it is exactly the one positive wedge of any size** — the worst spell,
`85987442074312111046374787509641907306580446218`, whose `tokenType=1`
chunk `[-201120, -198720]` reads `netLiquidity = 1.519e9` at burn block
43914219 with the tick at −200340, inside the range. Its second leg
(`tokenType=0`, `[-200160, -197760]`) is both empty and out of range and
contributes nothing.

### Every residual is a sub-block quantity

Sizing each wedge against the spell's own **average per-block** accrual:

| tokenId (truncated) | spell blocks | avg wei/block | signed wedge wei | wedge ÷ avg block |
|---|---|---|---|---|
| `859874420743121110463747…` | 132,562 | 4.09e7 | +2,952,569,137 | 72.17 |
| `859874063499804963311752…` | 3,405 | 3.50e7 | −3,876,301 | 0.11 |
| `305488578812443057446254…` | 651,651 | 2.71e7 | −1,957,978 | 0.07 |
| `171622313847804664062707…` | 390,199 | 3.79e5 | −1,344 | 0.004 |
| `305488695927131832613455…` | 1,239,612 | 1.06e5 | −286 | 0.003 |
| `305488725394698685720041…` | 1,640,143 | 1.19e5 | −239 | 0.002 |
| `859874216600285517816368…` | 2,116,559 | 2.44e5 | +67 | 0.000 |
| `139288478237779122273949…` | 104,244 | 6.89e6 | +1 | 0.000 |

Seven of eight are **strictly smaller than one block's accrual** — sub-block
noise, exactly as a block-granularity read wedge must be.

The eighth, at 72 average blocks, is the same quantity once the liquidity change
is taken into account. The accumulator is **per unit liquidity**: that burn drops
the chunk from `netLiquidity = 3.798e11` to `1.519e9`, a factor of **250**, so
each unit of post-burn fee credits the accumulator 250× faster than it did during
the spell. 72.17 ÷ 250 = **0.29 of one block's fees** at the post-burn liquidity.
Sub-block, like the rest.

### Base rate corroboration

Phase 9 measured 632,315 V4 `Swap` logs over blocks 43,781,657–48,879,461 =
5,097,804 blocks, i.e. **0.124 swaps per block** on this pool. A spell is exposed
at two endpoint blocks, and only the portion of each block *after* our
transaction can bite, so the expected share of spells carrying a wedge is
≈ 2 × 0.124 × ½ ≈ **12%**. Observed: **8 / 61 = 13.1%**. The frequency is what
the swap arrival rate predicts, not what a systematic defect would produce.

### Why this is not a defect, and what fixing it would take

A multiplier, scale or unit bug cannot produce 53 exact-to-the-wei
reconstructions; it would bias every spell. The scaling-signature check is clean
(no `|recon|/|truth|` within 1% of 2^64, 2^128, 1e12 or 1e18) and the sign split
is 3 over / 5 under — two-sided, which is the rounding-and-timing signature, not
the one-sided signature of a multiplier error.

The wedge is **irreducible at block granularity**. `eth_call` cannot address a
point *inside* a block; reading at `burnBlock − 1` merely relocates the same error
to the front of the block, with the opposite sign. Removing it entirely requires
transaction-level state (`debug_traceTransaction` or a state-override replay) —
a different data route, not a correction to this one.

Bounded at **5.45e-4**, the whole effect is **18× inside** `gateTolerance = 0.01`
and it does not touch the median. It is recorded here as a known, quantified,
one-block measurement wedge on the 8 affected spells; `reconcile-errors.csv`
carries the per-spell signed error so 10-09 can carry the flag forward and 10-11
can audit it.

### The long stratum: the expected wedge did not bind

All **8 of 8** long spells reconcile **exactly** (`SIGNED_BIAS_LONG: 0/0`, max rel
error 0.0). The `_getAvailablePremium` settlement cap (PanopticPool L588-599),
which the phase expected to open a downward long-stratum wedge, **did not bind on
any spell in this sample** — the pool always had enough to settle the accrued
long premium. This is reported, not assumed: the long stratum remains excluded
from the pass/fail arithmetic exactly as 10-07 specified, and it happens to have
needed no allowance at all.

### One honest caveat

Two of the smallest residuals (+67 and +1 wei, at 1.3e-10 and 1.4e-12 relative)
are **positive**, whereas 10-07's pre-check characterised the flooring residue as
strictly one-signed downward. At 67 wei on 5.15e11 this changes nothing material,
but the pre-check's "strictly one-signed" claim was a 2-observation
generalisation and the 61-spell sample does not support it. Recorded rather than
smoothed over.
