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

## 1. Product type: `VolPosition(V, R, CH)`

`CH` is a **clearing-house phantom tag** (`ClearingHouse.plk`; today `Panoptic` only). Same pattern as venue `V` and region `R`: one struct shape, compile-time tag selects which clearing semantics apply.

```plk
VolPosition(V, R, CH) {
    id:     Option(u256),           // None = composed, not cleared; Some(word) = cleared id
    market: VolMarketKey(V),
    order:  VolOrder(R),
    ladder: Ladder(V),
    book:   LegBook(BaseNotional)
}
```

When `CH == Panoptic`, `Some(word)` is **semantically** `PanopticTokenId { tokenId: word }`. The word is computed **in the constructor** via `lib/protocol_integrations/panoptic_v2/VolPositionId.plk` from `VolOrder` + `LegBook` + `PanopticPoolId` (all four legs, book weights as `optionRatio`).

**Constructor (single public entry):**

```plk
vol_position_from_ladder(
    comptime kind, R, V, CH,
    market, vo, l, iota_chunk, out,
    or_min, bound,
    pool_id: PanopticPoolId    // used when CH == Panoptic to derive id
) -> VolPosition(V, R, CH)
```

`vol_position_from_ladder` sets `id = None` for non-Panoptic CH tags (future); for `CH == Panoptic`, `id = Some(vol_position_panoptic_id_word(...))`.

Internally: `book = bin_to_legs(or_min, bound, kind, R, V, l, market, vo, …)`.

**Invariants:**

- `ladder` must be consistent with `order` (same span / star / vega as `ladder_from_vol_order(V, R, market, vo)`). Constructor may `require` equality or document caller obligation.
- On the binning path, **`book.base` is authoritative for mint scale**; `order.targetVega` is T1 intent only.

---

## 2. Projections (Panoptic is a view)

| Projection | Definition |
|------------|------------|
| `vol_position_panoptic_token_id(vp, pool_id)` | Read stored id (`vol_position_panoptic_token_id_from_stored`); set at construct |
| `vol_position_panoptic_token_id(vo, book, pool_id)` | In `panoptic_v2/VolPositionId.plk` — full leg encode + book ratios |
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
| `src/types/pos_spec/ClearingHouse.plk` | `Panoptic`, `is_clearing_house` |
| `src/lib/protocol_integrations/panoptic_v2/VolPositionId.plk` | `vol_order_to_panoptic_token_id*`, `vol_position_panoptic_token_id`, `vol_position_panoptic_id_word` |
| `src/types/pos_spec/VolPosition.plk` | `VolPosition(V,R,CH)`, accessors, `vol_position_panoptic_token_id_from_stored` |
| `src/lib/protocol_integrations/panoptic_v2/Binning.plk` | `vol_position_from_ladder` (or re-export) |
| `src/lib/protocol_integrations/panoptic_v2/VolPositionMint.plk` | `vol_position_to_mint_plan` (Task 3); legacy `vol_order_to_mint` until binning path owns sizing |

---

## 6. Out of scope (this phase)

- `Extra` producer / `vol_order_to_panoptic_token_id` FLAG_PANOPTIC dereference  
- `quantizationReport`  
- Payoff replica wiring (but `ladder` is stored for it)  
- Branch `type/VolPosition` (worktree `vol-markets-type-volposition`)

---

## 7. Success criteria

1. `vol_position_from_ladder` returns quad with `book` matching `bin_to_legs` on wide Spec.hs fixture.  
2. `vol_position_panoptic_token_id` emits non-unity ratios on wide fixture.  
3. `vol_position_position_size` equals `leg_book_base`.  
4. `push-build` / `develop-gate` green on PR.
