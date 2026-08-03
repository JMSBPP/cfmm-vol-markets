# Design Spec — `liquidity_for_collateral` (LDF shape + token0 collateral → LiquidityChunk)

Status: REVIEWED (Reality Checker + Solidity Smart Contract Engineer, both NEEDS WORK) → RESOLVED. Ready to execute.

## RESOLUTION (post-review)
Both reviewers independently converged. Resolutions:
- **Closed-form dispatch (B1/B4).** The generic O(length) runtime loop is a gas/DoS bomb (`length`=ι is a
  24-bit runtime field) AND redundant for geometric. Instead, for `kind == LDF_GEOMETRIC`:
  `cost_M = geometric_cumulative_amount0(min_tick − Δ, Q96, tick_spacing, min_tick, length, alpha_x96)`
  (already ported + differential-tested; O(1)). Evaluating at `min_tick − Δ` makes its right-exclusive
  range exactly `[i_min, i_max)` (fixes the B3 off-by-one). The generic integrator is deferred to a future
  non-closed-form LDF. Non-geometric `kind` → revert (unsupported this session).
- **Signature (B2/M8/m1): take `PriceCoordinate`, drop `PricePair`.**
  `liquidity_for_collateral(ldf_params: LDFParams, coord: PriceCoordinate, collateral: Collateral)`.
  `tick_spacing = coord.tick_spacing`. Resolves tick_spacing sourcing + the redundant endpoint prices.
- **min_tick sign extension (RC B1):** `min_tick = @evm_signextend(2, word0 & 0xffffff)` (NOT the raw
  24-bit field); `alpha_x96 = @evm_shr(24, word0) & (2^160−1)`; `length = @evm_shr(184, word0) & 0xffffff`.
- **Inversion + rounding (M4/M6):** `cost_M` is `cumulativeAmount0(…, Q96, …)` = the token0 density integral
  (rounded UP inside the closed form → cost is an upper bound). `L̄ = mulDiv(collateral.val, Q96, cost_M)`
  (round DOWN → conservative, never over-issues). Linearity of `cumulativeAmount0` in totalLiquidity makes
  this exact. The Q192/Q96 scaling (M4) is handled inside `cumulativeAmount0`, not re-derived here.
- **Guards:** `cost_M == 0` → revert; `L̄ > 2^128−1` → revert (Panoptic LiquidityChunk uint128 compat, m12).
- **Price convention (OPEN #3 / m10): CLOSED** — η folds out of the scalar price by `eta_split_kernel_identity`,
  so `p(i) = getSqrtRatioAtTick(i)` (which is what `cumulativeAmount0` uses). Anchor is now an identity.
- **Falsifiability:** EXACT differential test — `L̄ == collateral·Q96 / Bunni.cumulativeAmount0(i_min−Δ, Q96, …)`
  (Bunni ref imports cleanly); plus a round-trip `cumulativeAmount0(i_min−Δ, L̄, …) ≈ collateral` and the
  uint128-overflow revert. The wrong property tests (length≤1 reverts; cost_M monotone) are DROPPED.

---
### Original draft (superseded by RESOLUTION above)

## Purpose
Wire `src/lib/LiquidityAmounts.plk::liquidity_for_collateral`: given an LDF (its *shape*, via a
comptime density function + `LDFParams`) and a collateral amount denominated in **token M / token0**,
compute the total liquidity `L̄` a position with that LDF shape holds when funded by the collateral,
integrated over the LDF's tick support. Returns `LiquidityChunk { size: L̄, ldf_params }`.

Scope this session: `liquidity_for_collateral` only. Out of scope: `liquidity_for_vega`
(needs the `VegaNominal` import path fixed), `liquidity_for_portafolio` / `portafolio_for_liquidity`
(the `Portafolio` type does not exist yet).

## Signature (corrected for Plank semantics)
Plank docs: *"Functions in Plank are values at comptime."* So the density must be a **comptime** param
(the *which-LDF* is fixed at compile time; the tick-count loop runs at runtime, calling that comptime
density each iteration).

```
const liquidity_for_collateral = fn (
    comptime liquidity_density: function,   // fn(rounded_tick, tick_spacing, min_tick, length, alpha_x96) u256, returns ℓ(i) in Q96
    ldf_params: LDFParams,
    price_pair: PricePair,
    collateral: Collateral
) LiquidityChunk
```
The concrete density passed for the geometric LDF is `geometric_liquidity_density_x96`.

## Math (notes/VOLATILITY_INSTRUMENTS.md)
Per-tick token0 amount for **unit** liquidity (Uniswap getAmount0 form):
```
ΔQ_M^unit(i) = ℓ(i) · ( 1/p(i) − 1/p(i+Δ) )        [Q96]
```
where `p(i) = sqrtPrice at tick i`, `Δ = tick_spacing`, and `ℓ(i)` is the normalized density (Q96).
Cumulative cost per unit `L̄ = Q96`:
```
cost_M = Σ_{i = i_min}^{i_max − Δ} ΔQ_M^unit(i)
```
`Q_M^L` is **linear in `L̄`**, so invert:
```
L̄ = collateral.val · Q96 / cost_M
```
Return `LiquidityChunk { size: L̄, ldf_params }`.

## Decode `LDFParams` (geometric)
`word0 = (i_min & 0xffffff) | (xi << 24) | (iota << 184)`:
- `min_tick = i_min` (24-bit signed)
- `alpha_x96 = xi` (Q96, 160-bit field)
- `length = iota` (24-bit)  → `i_max = i_min + length·Δ`

## OPEN ISSUES (flagged for review)
1. **`tick_spacing` is not in `LDFParams` (geometric).** The integrator needs `Δ` for both `ℓ(i)` and
   `p(i)`/`p(i+Δ)`. `PricePair` only carries `geometry: PriceCoordinateId` (a keccak id — tick_spacing
   is NOT recoverable from it) plus `p1`,`p2`. Candidate fixes: add `tick_spacing` to the signature;
   add it to `LDFParams`; or pass the full `PriceCoordinate`. **Likely BLOCKER.**
2. **`price_pair` role vs `ldf_params` support.** The range is the LDF support `[i_min, i_max]` from
   `ldf_params`. What then does `price_pair` contribute — the endpoint prices `p(i_min)`,`p(i_max)`?
   Redundant with `getSqrtRatioAtTick(i_min/i_max)`? Possible signature simplification / redundancy bug.
3. **Price convention.** `p(i) = getSqrtRatioAtTick(i)` (the Δ=½ sqrt kernel, basis 1.0001). The notes'
   `p_(η,Δ)` generalizes with η; for the geometric LDF that matches Bunni, is η folded into indexing, or
   must `price_at_tick` (PriceCoordinate, η) be used instead? Affects whether the geometric anchor below holds.

## Fixed-point / safety
- `1/p(i)` in Q96 = `mulDiv(Q96, Q96, p(i))`; `p(i) ≥ MIN_SQRT_RATIO > 0` → no div-by-zero on prices.
- Guard `cost_M == 0` (degenerate `length ≤ 1`) before the final division (else revert).
- Overflow: `ℓ(i) ≤ Q96`, `(1/p(i) − 1/p(i+Δ)) ≤ ~Q96` → term `≤ Q96`; sum over `≤ length` terms
  `≤ length·Q96`. Use 512-bit `mulDiv` where a product exceeds 256 bits.
- Runtime `while i < length` loop calling the comptime density — verify Plank permits calling a comptime
  function value inside a runtime-bounded loop (docs imply yes; confirm empirically before coding).

## Falsifiability (no external reference — but a geometric anchor exists)
- **Geometric differential anchor:** the notes' `Q_M^L` for the geometric density *is* Bunni's
  `cumulativeAmount0`, which is already ported and differential-tested. So
  `integrator(geometric_density).cost_M · L̄ / Q96` must equal `geometric_cumulative_amount0(i_min, L̄, …)`
  — a real differential check for the geometric instantiation (contingent on OPEN #3 price convention aligning).
- **Property tests:** `L̄` linear in `collateral.val`; round-trip `L̄ · cost_M / Q96 ≈ collateral.val`
  (within fixed-point ULP); degenerate `length ≤ 1` reverts; `cost_M` monotone in `length`.
