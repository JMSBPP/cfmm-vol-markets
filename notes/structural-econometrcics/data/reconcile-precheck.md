# Reconciliation — reconstructed spell premium vs `OptionBurn.premium0`

**Units: ETH wei on `premium0`.** No price conversion appears anywhere in the
gate path (token1's 6 decimals truncate small premia, and a conversion factor
is exactly the noise a 1% target cannot absorb).

## Lineage

| what | value |
|---|---|
| measured | `2026-07-26` |
| subgraph endpoint | `https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn` |
| underlying pool (V4 poolId) | `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a` |
| accumulator readings | `notes/structural-econometrcics/data/premium-accumulators.csv` |
| gate population (panel) | `notes/structural-econometrcics/data/panel.csv` |
| per-leg census | `notes/structural-econometrcics/data/chunk-legs.csv` |
| paired spells (subgraph) | `61` |
| spells in the gate population | `61` |
| selection | `short stratum only, at most 1 leg(s), first 5 spells` |
| spells reconciled | `5` |
| is_long label disagreements | `0` |
| chunk-range census mismatches | `0` |
| ground-truth unit | `RawWei` |
| converting expression | `truthWei = round(premium0)                -- premium0 is ALREADY raw 18-decimal units` |
| gate tolerance (`gateTolerance`) | `1.0e-2` |

## Strata

Reported SEPARATELY and never pooled. `_getAvailablePremium` (PanopticPool
L588-599) caps SETTLED long premium at what the pool can pay while the
accumulator reports ACCRUED premium, so a downward long-stratum wedge is
expected. The verdict is scored on the short stratum; the long stratum is
reported in full and neither hidden nor allowed to fail a gate the shorts pass.

| stratum | n | median | p25 | p75 | p90 | max | recon>truth | recon<truth | zero-truth excluded |
|---|---|---|---|---|---|---|---|---|---|
| short | 5 | 0.000000 | 0.000000 | 1.220169e-9 | 2.184691e-9 | 2.184691e-9 | 0 | 2 | 0 |
| long | 0 | n/a | n/a | n/a | n/a | n/a | 0 | 0 | 0 |
| all (diagnostic only) | 5 | 0.000000 | 0.000000 | 1.220169e-9 | 2.184691e-9 | 2.184691e-9 | 0 | 2 | 0 |

## Per-spell

| tokenId | isLong | legs | legs (truth) | recon wei | truth wei | rel error | signed error wei | flags |
|---|---|---|---|---|---|---|---|---|
| `13928862935350657410259648809994` | short | 1 | 1 | 2198627894 | 2198627894 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `13928885602709775184556674550794` | short | 1 | 1 | 1918515357 | 1918515357 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `305488671002481536027468369529866` | short | 1 | 1 | 993545060839 | 993545060839 | 0.000000 | 0 | ChunkEmpty,Extrapolated |
| `305488695927131832613455807417354` | short | 1 | 1 | 130910962607 | 130910962893 | 2.184691e-9 | -286 | ChunkEmpty,Extrapolated |
| `305488725394698685720041940880394` | short | 1 | 1 | 195874484857 | 195874485096 | 1.220169e-9 | -239 | ChunkEmpty,Extrapolated |

## Leg-count mismatches

None — every spell's reconstruction covered exactly the legs the scalar
ground truth sums over.

## Verdict

median_rel_error: 0.000000

- `MEDIAN_REL_ERROR_SHORT`: 0.000000
- `MEDIAN_REL_ERROR_LONG`: n/a
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

### Scaling-signature check

**Clean.** No spell's `|recon| / |truth|` ratio sits within 1% of 2^64, 2^128,
1e12 or 1e18 (or their reciprocals) — the four factor signatures RESEARCH
Pitfall 2 names. The unit stack is not the problem.

### Flags observed

5 of 5 reconciled spells carry a flag. The two that appear here are EXPECTED at spell endpoints and are not defects:

- `ChunkEmpty` — `netLiquidity == 0` at an endpoint block. At the BURN block
  this is the normal state: the burn removed the position's liquidity, so
  `getAccountPremium` returns the STORED accumulator rather than a live
  extrapolation. That stored value is exactly what `_getPremia` itself used,
  which is why these spells still reconcile to the wei.
- `Extrapolated` — the read passed a real `atTick` rather than the
  `8388607` stored-value sentinel.

Neither flag is auto-dropped and neither is invisible (10-05 contract).
