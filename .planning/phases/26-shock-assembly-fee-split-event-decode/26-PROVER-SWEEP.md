---
phase: 26
kind: measurement
status: binding-on-26-04
created: 2026-08-17
runs: 88 (sweep 1) + 72 (sweep 2, classified)
---

# Phase 26 — Prover Sweep: the measured grid for 26-04

> **This resolves RC-B1.** The Reality Checker measured that the pinned Tier-C grid is unrealizable —
> only 1 of 16 planned invocations behaves as the plan says. That finding is CONFIRMED. What it did
> not establish, and this sweep does, is **which grid works** and **why the failures happen**.
>
> Every row here is a real `gams54.1` invocation against the real
> `model/mev_tax_model_one/volume_path.gms`, at the fixture's `sqrtPriceX96 = 2^96`,
> `liquidityRaw = 2^64`, `volTgtWad = 28e18`, `nEvents = 8`.

## The discriminator RC-B2 asked for — found, and it is not the exit code

`gams_admits` cannot be derived from `exit /= 0`: **exit 3 means at least six different things.**
The abort message does **not** reach stdout or stderr (phase 24 measured stderr at 0 bytes in every
mode). It lands in **`volume_path.log`** in `curdir`, and it names the **model's own source line**:

```
*** Error at line 109: Execution halted: abort$1 'dStar outside the half-ellipse: ...'
```

| Line | Meaning | Should Haskell predict it? |
|---|---|---|
| **109** | `dStar` outside the half-ellipse | **YES — this is `ellipse_test`** |
| 91 | equal fees | YES — `distinct_fees` |
| 103 | `kappa` outside a solvable range | no — fixture property |
| **171 / 173** | `solveStat` / `modelStat` — CONOPT infeasible | **NO — solver property, not admissibility** |
| 195–199 | tolerance misses (loop close, δ, r, volume, sign) | no |
| 88/89/90/77 | input-shape aborts | already refused in Haskell |

**So the differential is `haskell_inadmissible ⟺ gams aborts at line 109`, NOT `⟺ gams_exit /= 0`.**
A row that solves and a row that is CONOPT-infeasible are both *admissible*; only line 109 is a
refusal. Deriving `gams_admits` from the exit code alone would report a disagreement on all 29
INFEASIBLE rows below, which is exactly the false phase-BLOCKER RC-B1 predicted.

Pin the line number against the model's sha256 — it is a source line, stable while the file is, and
the freshness oracle already digests that file.

## Classification over 72 classified runs

```
ELLIPSE     26     ← line 109, the admissibility refusal
INFEASIBLE  29     ← lines 171/173, CONOPT could not solve an ADMISSIBLE point
SOLVED      17     ← exit 0, artifact written
UNKNOWN      0
```

## THE HEADLINE: Haskell and GAMS agree at every boundary measured

The last δ\* refused at line 109, and the first δ\* not refused, bracket the true boundary. Compared
against the Haskell boundary the plans pinned independently:

| pair | last ELLIPSE | first non-ellipse | pinned Haskell boundary | agree? |
|---|---|---|---|---|
| (500, 6000) | 82803 | 82804 | **82804** | **YES** |
| (100, 900) | 109768 | 109770 | **109769** | **YES** |
| (700, 800) | 495952 | 495954 | **495953** | **YES** |
| (1000, 3000) | 300000 | 400000 | 300361 | grid too coarse — re-sweep 300300–300400 |

**FEE-02's core claim holds against the real prover.** The corrected composed-fee/full-gap
derivation (`c6c2646`) reproduces GAMS's own admissibility verdict exactly. The arithmetic-mean
misreading, being 2× too large, would have refused ~82,700 pips that GAMS accepts — that would have
shown up here as ELLIPSE rows where GAMS reports INFEASIBLE or SOLVED. It does not.

## The grid 26-04 should pin — every row MEASURED

**No single δ\* solves all four pairs.** Use a per-pair grid.

| pair | SOLVED at δ\* | note |
|---|---|---|
| (500, 6000) | 490000, 492000, 495000, 495952, 495954 | |
| (100, 900) | 490000, 492000, 495000, 495954, 497000 | |
| (1000, 3000) | 490000, 492000, 495000, 495952, 497000 | |
| (700, 800) | **497000, 497971 only** | the outlier; ellipse-refuses everything below 495954 |

- **δ\* = 490000 solves three of four pairs** — (500,6000), (100,900), (1000,3000). This is SC-2's
  original 0.49, which CORRECTION C removed from the differential. **Put it back**; it is the single
  most useful grid point and it is measured, not argued.
- **δ\* = 497000 also solves three of four** — (100,900), (1000,3000), (700,800).
- Together those two cover all four pairs with two δ\* values.

## What each row type is FOR in the differential

- **ELLIPSE rows** are the ones that matter and the ones the plan never asserted. RC-B2: *"no check
  asserts a `boundary − 1` row has `gams_exit /= 0`"* — the four rows where the prover actually
  refuses carried no in-suite assertion at all. **Assert `abort_line == 109` on every
  boundary−1 row.** That is the only place GAMS is ever observed REFUSING, and without it the
  differential can pass having proven nothing.
- **SOLVED rows** prove the pair is realizable and the artifact parses.
- **INFEASIBLE rows** must be recorded as `admissible-but-unsolved`, never as a disagreement. They
  are a property of the fixture's `volTgtWad`/`nEvents`, not of the fee split.

## Reproducing

`sweep2.sh` in the session scratchpad. Per run: a fresh `mktemp -d` as `curdir`, `lo=2 action=ce`,
classify by `grep -oE '\*\*\* Error at line [0-9]+' volume_path.log`. ~2 s per invocation.

**Do not** raise `volTgtWad` to rescue an INFEASIBLE row — the Reality Checker swept six values and
three `nEvents` settings and all still aborted. The model's own header explains why: `δ* = 0.49`
needs `κ ≥ 1.4980`, and the `u.lo/u.up = [1e-3, 1e3]` box bounds what any volume can reach.
