# VolPosition — Plank design

**Date:** 2026-08-31  
**Status:** DRAFT — maintainer review  
**Depends on:** `type/ldf` merged (#92): `Ladder(V)`, `LegBook(BaseNotional)`, `bin_to_legs`, `VolOrder`, `VolMarketKey`  
**Haskell anchor:** `Panoptic.Binning.mintPlanFromLadder`, `Panoptic.NId.volOrderToTokenId`, `TargetVega` (positionSize)

---

## 0. Problem

The pre-binning mint path (`vol_order_to_mint`) sizes from `VegaTarget` via `position_size_for_target_vega` and emits `PanopticTokenId` with structural `optionRatio = 1`. Binning (𝓑) replaces both:

- **Weights** — `round(b · n_k / n_max)` → Panoptic `optionRatio` per leg  
- **Scale** — `⌊n_max / b⌋` → SFPM `positionSize` (spec `TargetVega`)

`MintPlan { token_id, position_size }` is a **Panoptic SFPM adapter**, not the protocol-level positioned product. `PanopticTokenId` is a **projection** of geometry + ratios, not the root type.

---

## 1. Product type: `VolPosition(V)`

```plk
VolPosition(V) {
    market: VolMarketKey(V),
    order:  VolOrder(R),           // R = region tag on order (calldata | memory)
    ladder: Ladder(V),             // T1 geometry — retained for payoff / reports / re-bin
    book:   LegBook(BaseNotional)   // T2 binning — authoritative mint scale + weights
}
```

**Constructor (single public entry):**

```plk
vol_position_from_ladder(
    comptime kind, R, V,
    market: VolMarketKey(V),
    vo: VolOrder(R),
    l: Ladder(V),
    iota_chunk, out,
    or_min: u256,
    bound: LegWeightBound
) -> VolPosition(V)
```

Internally: `book = bin_to_legs(or_min, bound, kind, R, V, l, market, vo, …)`.

**Invariants:**

- `ladder` must be consistent with `order` (same span / star / vega as `ladder_from_vol_order(V, R, market, vo)`). Constructor may `require` equality or document caller obligation.
- On the binning path, **`book.base` is authoritative for mint scale**; `order.targetVega` is T1 intent only.

---

## 2. Projections (Panoptic is a view)

| Projection | Definition |
|------------|------------|
| `vol_position_panoptic_token_id(vp, pool_id)` | `vol_order_to_panoptic_token_id` with ratios from `leg_weight_value(book.w*)`, not `1` |
| `vol_position_position_size(vp)` | `base_notional_value(leg_book_base(vp.book))` |
| `vol_position_to_mint_plan(vp, pool_id)` | **Legacy adapter:** `{ token_id, position_size }` for SFPM callers |

Haskell equivalence:

```haskell
mintPlanFromLadder poolId l vo =
  let (ratios, ps) = binToLegs orMinDefault l vo
  in MintPlan (volOrderToTokenId vo poolId ratios) (createChunk iL iU (unTargetVega ps))
```

Plank:

```text
vp  = vol_position_from_ladder(...)
tid = vol_position_panoptic_token_id(vp, panoptic_pool_id(market))
ps  = vol_position_position_size(vp)
```

`LiquidityChunk` envelope at `[iL, iU]` remains a Panoptic/chunk API concern; Plank `MintPlan` today uses `position_size: u256` only.

---

## 3. Stale paths (do not extend)

| Stale | Replacement |
|-------|-------------|
| `vol_order_to_mint` as primary sizing | `vol_position_from_ladder` |
| `position_size_for_target_vega` on binning path | `leg_book_base` |
| `MintPlan` as root codomain | `VolPosition`; `vol_position_to_mint_plan` adapter |
| `optionRatio = 1` on binning path | weights from `LegBook` |

Keep adapters until callers migrate; mark deprecated in module comments.

---

## 4. `Extra` vs `VolPosition`

| Layer | Role |
|-------|------|
| `VolOrder.extra` | Wire operand **descriptor** (`FLAG_PANOPTIC`: ratios + tokenType + vegoid on calldata bytes) |
| `LegBook(BaseNotional)` | Typed binning result |
| `VolPosition` | Composed mint-ready **semantic** product |

**Phase 3 (later):** pack/unpack `Extra` ↔ `LegBook` for on-chain wire. **This phase:** off-chain compose via `vol_position_from_ladder` (direct tuple).

---

## 5. Module placement

| Module | Symbols |
|--------|---------|
| `src/types/pos_spec/VolPosition.plk` | `VolPosition(V)`, accessors |
| `src/lib/protocol_integrations/panoptic_v2/Binning.plk` | `vol_position_from_ladder` (or re-export) |
| `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk` | `vol_position_panoptic_token_id`, `vol_position_to_mint_plan` |

---

## 6. Out of scope (this phase)

- `Extra` producer / `vol_order_to_panoptic_token_id` FLAG_PANOPTIC dereference  
- `quantizationReport`  
- Payoff replica wiring (but `ladder` is stored for it)  
- Renaming branch `type/VolOrder` (name is historical; type is `VolPosition`)

---

## 7. Success criteria

1. `vol_position_from_ladder` returns quad with `book` matching `bin_to_legs` on wide Spec.hs fixture.  
2. `vol_position_panoptic_token_id` emits non-unity ratios on wide fixture.  
3. `vol_position_position_size` equals `leg_book_base`.  
4. `push-build` / `develop-gate` green on PR.
