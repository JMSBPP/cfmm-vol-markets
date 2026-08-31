# Panoptic Binning (𝓑) — Plank design

**Date:** 2026-08-31  
**Status:** DRAFT — chunk review  
**Spec source:** `spec/src/Panoptic/Binning.hs`  
**Depends on:** `types/Ladder.plk` (T1), `types/pos_spec/VolOrder.plk`, `lib/panoptic/Binning.plk` (new)  
**Haskell anchor:** README § REPLICATION_THEORY Def 8, Corollary 1; `ladderFromVolOrder`, `binNotionals`, `binToLegs`, `mintPlanFromLadder`

---

## 0. Scope

𝓑 maps a T1 geometric ladder + its originating `VolOrder` into a 4-leg Panoptic mint:

1. **Ladder construction** — `ladderFromVolOrder` (approved, §2)
2. **Bin notionals** — per-leg token1 sums over rung chunks (`binNotionals`)
3. **Option-ratio quantization** — `binToLegs` → `OptionRatios` + `position_size`
4. **Mint plan** — `mintPlanFromLadder` (blocked on variable `optionRatio` tokenId path)

**Out of scope (later):** `quantizationReport`, full `mintPlanFromLadder` wiring in production `vol_order_to_mint`.

**Approach (approved):** pure library module `lib/panoptic/Binning.plk` with typed result structs; no new ladder phantom types.

---

## 1. Problem

Haskell `Panoptic.Binning` closes the gap between T1 (`Payoffs.LadderPosition`) and T2 (4-leg Panoptic `MintPlan`). Plank has `Ladder(V)` and rung/chunk materialization, but sizing today follows `PanopticTokenIdSetterLib` (`position_size_for_target_vega`, `average_density_chunks`, `optionRatio = 1`). Binning replaces that with rung-derived token1 notionals and computed option ratios per spec.

---

## 2. Ladder construction (`ladderFromVolOrder`)

### 2.1 Spec semantics

```haskell
ladderFromVolOrder vo =
  let (iL, iU, ts) = tickBucketFromVolOrder vo
      iStar = roundTick (tickVolatilityTick (volStrike vo)) ts
  in  ladderFromSpan iL iU ts iStar (volTargetVega vo)
```

Projection only — same `Ladder` record as explicit span construction. Spacing `ts` is **not** stored on Plank `Ladder(V)`; derived from `VolMarketKey(V)` at use sites (existing T1 design).

### 2.2 Type identity (Approach A — approved)

- `Ladder(V)` — `V` is **always** a venue (`V3` | `V4` | `Algebra`).
- Construction provenance is a **comptime geometry tag** `G` on the value constructor, not a second ladder type parameter.
- `G ∈ { VolOrder(R), VegaTarget(0,0,0), ExplicitSpan }`.

### 2.3 Module placement (3+2 — approved)

| Module | Symbol | Role |
|--------|--------|------|
| `types/pos_spec/VolOrder.plk` | `vol_order_ladder_geometry(R, vo)` | Pure projection → `(lo, hi, star, vega)`. Uses `tick_bucket_from_vol_order_in`, `round_tick(tick_volatility_tick(strike), ts)`, `vega_amount(targetVega)`. **No venue, no `Ladder`.** |
| `types/Ladder.plk` | `ladder_from_span(V, ts, lo, hi, star, vega)` | Shared invariant gate (`i_L < i* < i_U`, tick alignment, `vega ∈ (0, U128_MAX]`, `ι ≥ 1`). Mirrors Haskell `ladderFromSpan`. |
| `types/Ladder.plk` | `ladder(V, G, market, …)` | Comptime dispatch on `G`. VolOrder branch: completeness checks, `ts == vol_market_key_tick_spacing(V, market)`, then `ladder_from_span` with geometry from helper. |
| `lib/panoptic/Binning.plk` | `ladder_from_vol_order(V, R, market, vo)` | **Spec export** — one-liner forward to `ladder(V, VolOrder(R), market, vo)`. |

### 2.4 Call graph

```
ladder_from_vol_order(V, R, market, vo)          [Binning.plk — public]
  └─ ladder(V, VolOrder(R), market, vo)         [Ladder.plk]
       ├─ vol_order_ladder_geometry(R, vo)     [VolOrder.plk]
       └─ ladder_from_span(V, ts, lo, hi, star, vega)
```

### 2.5 Preconditions / errors

Same as current `ladder_from_vol_order` + `ladder_new`:

- `vol_order` completeness (`vol_range_width`, `skew`, `vol_strike`, `target_vega`)
- `vo.rangeWidth.tickSpacing == vol_market_key_tick_spacing(V, market)`
- `lo < star < hi`, ticks Δ-aligned, `vega > 0`, `vega ≤ U128_MAX`, `(hi - lo) / ts ≥ 1`

### 2.6 Migration

- Remove standalone `ladder_from_vol_order` from `Ladder.plk` once Binning re-export lands (or keep as `deprecated` alias for one phase).
- `test/types/LadderHarness.plk` — fixtures may keep calling `ladder_from_span` / explicit `ladder_new`; binning tests import `ladder_from_vol_order` from `Binning.plk`.

### 2.7 Tests (RED first)

- Harness selector: `ladderFromVolOrder` projecting a fixture `VolOrder` → `(lo, hi, star, vega)` vs Haskell oracle vectors.
- Does **not** require chunk materialization — geometry-only slice.
