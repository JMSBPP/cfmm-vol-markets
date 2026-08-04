> **SUPERSEDED IN PART (V2-03, 2026-07-30 — vol-order-v2-target-vega-SPEC.md D4/D0-ADDENDUM).**
> The mass-share rule locked below (`size_k = mulDiv(L̄, w_k, Q96)`) predates the #14 review
> checkpoint; the decision OF RECORD is the user-confirmed AVERAGE DENSITY
> `size_k = L̄·w_k/n_k`, now implemented as `average_density_chunks`
> (PanopticTokenIdSetterLib). V2-03's MEASURED coupling result assigns the roles:
> the PANOPTIC RAIL's canonical realization is the INDUCED ladder
> (`ratios ≡ 1, asset = 1, one positionSize` → `L_k = ps·Q96/dsqrt_k` — what the protocol
> physically deploys; `vol_order_to_mint`); the average-density profile is the LDF/lens-side
> per-COLUMN model. The two coincide within 0.1%/leg on the fine grid (n_k = 1, proven by
> test__coupling__fineGridProfilesCoincide) and diverge structurally on coarse legs (they
> conserve sqrt-range-aggregate vs column-sum respectively — both deliver ΔQ_v★ one-sided
> in total). Sizing from ΔQ_v★: `position_size_for_target_vega`, floor-maximal,
> uint128-guarded.

# CR-I2 Layer 2 — mint sizing design spec

Status: DRAFT. MUST pass the two-step review (Reality Checker + Solidity Smart Contract Engineer)
before code. Scope locked by user: **geometric mass-share sizing** returning **4 Panoptic-compatible
`LiquidityChunk`s** (also closes the "LiquidityChunk must be Panoptic-compatible" type todo).

## 0. Context — the sizing pipeline

```
deposit + riskPrice --issue_shares--> shares  (DONE, VegaIssuanceLib)
shares/collateral/vega --liquidity_for_*--> total L̄  (DONE, LiquidityAmounts.plk: LiquidityChunk.size)
L̄ + weights (Layer 2 §weights, DONE) --THIS--> 4 per-leg Panoptic LiquidityChunks (mint-ready)
```

The geometric weight vector `w_k` (Q96, Σ=Q96) is done (`geometric_leg_weights`). Total liquidity
`L̄` is produced by the existing `liquidity_for_collateral/_vega/_portafolio` as `LiquidityChunk.size`.
Mint sizing is the **weight-driven split**: `(L̄, weights, tick bounds) → 4 per-leg chunks`.

## 1. Objective

Two deliverables:

1. **Panoptic-compatible chunk packing** in `src/types/ldf/LiquidityChunk.plk` — a faithful port of
   `lib/panoptic-v2-core/contracts/types/LiquidityChunk.sol` (`type LiquidityChunk is uint256`):
   ```
   panoptic_create_chunk(tickLower, tickUpper, amount) u256   // (tickLower<<232)+(tickUpper<<208)+amount
   panoptic_chunk_tick_lower(c) u256   // sign-extended int24 @232
   panoptic_chunk_tick_upper(c) u256   // sign-extended int24 @208
   panoptic_chunk_liquidity(c)  u256   // uint128 @0
   ```
   This closes the type's "full compatibility with Panoptic LiquidityChunk" todo. The existing struct
   `LiquidityChunk{size, ldf_params}` (the total-L̄ + LDF carrier, input to the split) is LEFT AS-IS —
   the Panoptic chunk is a distinct packed `u256` (matching Panoptic's own `type ... is uint256`), not
   a replacement of that struct.

2. **`geometric_leg_chunks(l_bar, weights, i_l, m_p, i_star, m_c, i_u) -> LegChunks`** in `LDFLib.plk`
   — the 4 per-leg Panoptic-packed chunks, `LegChunks { c0, c1, c2, c3 }`.

## 2. Sizing rule (locked: geometric mass share)

`size_k = mulDiv(L̄, w_k, Q96)` — leg k gets its geometric weight's share of total liquidity. Within a
leg the geometric profile is approximated as uniform (consistent with the 4-leg truncation already
acknowledged in Layer 1 §7). Grounded in the notes `L(i_K) = L̄·ℓ(ξ,ι;i_K)` summed over the leg's
columns (`notes/VOLATILITY_INSTRUMENTS.md:189`).

**Conservation (exact):** `Σ size_k == L̄`. Because 4 independent `mulDiv` floors would leave `L̄`
short by ≤3 wei, the LAST leg absorbs the dust:
`size_0,1,2 = mulDiv(L̄, w_{0,1,2}, Q96)`, `size_3 = L̄ - (size_0 + size_1 + size_2)`. Leg 3 is the
highest-tick (smallest-mass) leg for ξ<1, so it absorbs ≤3 wei with negligible relative effect.

## 3. Per-leg tick bounds (from the shared split points)

Same tiling Layer 1 emits and Layer 2 weights use (the shared `vol_order_split_points`):

| leg | [tickLower, tickUpper) | tokenType |
|---|---|---|
| 0 | [i_l, m_p]   | put  |
| 1 | [m_p, i*]    | put  |
| 2 | [i*, m_c]    | call |
| 3 | [m_c, i_u]   | call |

The caller passes `(i_l, m_p, i_star, m_c, i_u)` — the SAME values Layer 1 used (via the shared
helper), so the chunks' ranges match the tokenId's legs exactly.

## 4. Algorithm

```
const geometric_leg_chunks = fn (l_bar: u256, w: LegWeights,
    i_l: u256, m_p: u256, i_star: u256, m_c: u256, i_u: u256) LegChunks {
    let s0 = mulDiv(l_bar, w.w0, Q96);
    let s1 = mulDiv(l_bar, w.w1, Q96);
    let s2 = mulDiv(l_bar, w.w2, Q96);
    let s3 = l_bar -% (s0 +% s1 +% s2);            // dust to last leg -> Sum == l_bar exactly
    // each leg's liquidity must fit uint128 (Panoptic liquidity field)
    require(!(s0 > U128_MAX) and !(s1 > U128_MAX) and !(s2 > U128_MAX) and !(s3 > U128_MAX));
    LegChunks {
        c0: panoptic_create_chunk(i_l,    m_p,    s0),
        c1: panoptic_create_chunk(m_p,    i_star, s1),
        c2: panoptic_create_chunk(i_star, m_c,    s2),
        c3: panoptic_create_chunk(m_c,    i_u,    s3)
    }
};
```

`panoptic_create_chunk` masks the ticks to 24 bits (`& 0xffffff`) before shifting, exactly as
`createChunk` casts to `uint24` (LiquidityChunk.sol:75-77). `l_bar` is already ≤ U128_MAX
(`liquidity_for_collateral` guards `size > U128_MAX`, LiquidityAmounts.plk:42), so each `size_k ≤ L̄ ≤
U128_MAX` holds by construction — the require is defense-in-depth (and guards `s3`'s subtraction).

## 5. Preconditions
- `L̄ ≤ U128_MAX` (upstream `liquidity_for_*` guarantees it; re-guarded here).
- Tick bounds are the shared split points (Δ-aligned, ordered `i_l < m_p ≤ i* ≤ m_c < i_u`), passed by
  the caller — NOT re-derived (same contract as `geometric_leg_weights`).
- `w` is the output of `geometric_leg_weights` for the same bounds (Σ w = Q96).

## 6. Known limitations
- **Within-leg uniform approximation:** each leg is one constant-liquidity chunk; the geometric
  variation across a leg's columns is flattened to its mass share. Coarsening consistent with the
  4-leg truncation (Layer 1 §7). NOT an exact amount-preserving sizing (rejected as over-engineered
  for a 4-leg skeleton).
- Mint sizing produces the chunks; it does NOT itself call the SFPM/mint (out of scope — the chunks
  are the mint inputs). `optionRatio` quantization stays deferred (weights live in the chunk
  liquidity, not the tokenId).

## 7. Test plan (TDD — RED first)

Differential vs the real `LiquidityChunk.sol` (imports cleanly — standalone `type ... is uint256` +
library, no OZ). Extend the Layer-2 harness or a sibling.

1. **Chunk packing round-trips vs Panoptic.** `panoptic_create_chunk(tl, tu, amt)` == real
   `LiquidityChunkLibrary.createChunk`, and the getters == `tickLower/tickUpper/liquidity`, over fuzzed
   ticks (incl. negative) + amounts (≤ uint128). This is the compat-todo verification.
2. **Conservation.** `Σ liquidity(c_k) == L̄` EXACTLY (last-leg dust absorption).
3. **Mass share.** `liquidity(c_k) == mulDiv(L̄, w_k, Q96)` for k=0,1,2; `liquidity(c_3) == L̄ −
   Σ_{k<3}` (recompute in Solidity).
4. **Tick bounds.** `(tickLower, tickUpper)` of the 4 chunks == `(i_l,m_p),(m_p,i*),(i*,m_c),(m_c,i_u)`
   — i.e. equal to Layer 1's emitted leg ranges (decode the tokenId's legs and compare).
5. **uint128 guard.** An `L̄` near U128_MAX with a leg size that would overflow reverts (constructed).
6. **Golden.** The CR-I2 golden bucket → 4 chunks with hand-checked ranges + `Σ liquidity == L̄`.

## 8. References
- `lib/panoptic-v2-core/contracts/types/LiquidityChunk.sol` (packing: createChunk :63-80, getters
  :166-188; layout :27-43).
- `notes/VOLATILITY_INSTRUMENTS.md:189` (`L(i_K)=L̄·ℓ(ξ,ι)`).
- `src/lib/LiquidityAmounts.plk` (L̄ from collateral/vega/portafolio; U128_MAX guard).
- `src/lib/ldf/LDFLib.plk` (geometric_leg_weights; shared home).
- `src/types/pricing/TickUtils.plk` (vol_order_split_points — the shared tick bounds).
- `.planning/cr-i2-layer2-geometric-weights-SPEC.md` (the weight vector this sizes).
