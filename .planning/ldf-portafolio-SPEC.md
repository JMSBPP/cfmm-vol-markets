# Design Spec — `Portafolio` type + `portafolio_for_liquidity` / `liquidity_for_portafolio`

Status: REVIEWED (both NEEDS WORK) → RESOLVED. Building the forward map first.

## RESOLUTION (post-review)
- **Model (a): full-support BOTH ways; drop `price_bucket`** (both reviewers: keeps the round-trip valid; the
  mid-split model (b) would need the forward to also take a split price + sqrtPrice→tick + active-tick handling).
- **Portafolio** = `{ gross_output_amt: u256 (Q_X, token1/Asset), gross_input_amt: u256 (Q_M, token0/Cash) }`
  (v1 gross-only subset of REQUIREMENTS.md:32). At `src/types/Portafolio.plk`.
- **`portafolio_for_liquidity(coord: PriceCoordinate, liquidity: LiquidityChunk) -> Portafolio`** (forward):
  L̄ = liquidity.size; `ldf_params = liquidity.ldf_params` (embedded, not passed separately — m1); decode
  identically to `liquidity_for_collateral` (sign-extend min_tick, 160-bit alpha, 24-bit length); Δ =
  coord.tick_spacing; `i_max = min_tick +% (length *% Δ)` built with the SAME wrapping arithmetic (m3).
  `gross_input = geometric_cumulative_amount0(min_tick − Δ, L̄, …)`,
  `gross_output = geometric_cumulative_amount1(i_max, L̄, …)`. Non-geometric kind → revert.
- **`liquidity_for_portafolio`** (inverse, LATER): full-support; `L̄ = min(L̄_M, L̄_X)` each rounded DOWN
  (Solidity BLOCKER 2 fund-safety); guard both zero-divisors + uint128 on the min.
- **Test (independent oracle, fixes the circular M2):** differential wiring (gross_input == Bunni.ca0(i_min−Δ),
  gross_output == Bunni.ca1(i_max)) PLUS an INDEPENDENT full-support boundary check
  `Bunni.ca1(i_max) == Bunni.ca1(i_max − Δ)` and `> Bunni.ca1(interior)` (catches a wrong i_max independent of
  the plank impl), plus a golden vector.

---
### Original draft (superseded by RESOLUTION)

## Purpose
Build the missing `Portafolio` type and wire the last two `LiquidityAmounts` functions, so a geometric-LDF
position's liquidity `L̄` and its token amounts `(Q_M, Q_X)` are inter-convertible.

## `Portafolio` type
Per `spec/protocol/REQUIREMENTS.md:32` (`Portafolio<Asset, Cash> { grossOutputAmt: Asset<Quantity>, grossInputAmt:
Cash<Quantity> }`) and the notes' `ΔQ = (ΔQ_M, ΔQ_X)`. v1 concrete record:
```
const Portafolio = struct {
    gross_output_amt: u256,   // Q_X  -- token1 / Asset amount over the support
    gross_input_amt:  u256    // Q_M  -- token0 / Cash (numeraire) amount over the support
};
```
Location: `src/types/Portafolio.plk` (forced by `LiquidityAmounts.plk`'s `types::Portafolio` import).

## `portafolio_for_liquidity` (forward — clean, exact-testable)
`portafolio_for_liquidity(ldf_params: LDFParams, coord: PriceCoordinate, liquidity: LiquidityChunk) -> Portafolio`
Given `L̄ = liquidity.size`, the token amounts a geometric-LDF position of that liquidity holds over the full
support `[i_min, i_max)`:
- decode (geometric): `min_tick` (SIGN-EXTENDED), `alpha_x96 = xi`, `length = iota`; `Δ = coord.tick_spacing`.
- `gross_input_amt (Q_M, token0) = geometric_cumulative_amount0(min_tick − Δ, L̄, Δ, min_tick, length, alpha_x96)`
  (token0 over `[i_min, i_max)`, exactly as in the reviewed `liquidity_for_collateral`).
- `gross_output_amt (Q_X, token1) = geometric_cumulative_amount1(i_max, L̄, Δ, min_tick, length, alpha_x96)`
  where `i_max = min_tick + length·Δ` (token1 over the whole support — Q_X sums to the LEFT).
- **OPEN A (boundary):** verify the exact evaluation point for `cumulativeAmount1` that captures the full
  `[i_min, i_max)` token1 (Bunni's `cumulativeAmount1(roundedTick)` sums `[i_min, roundedTick − Δ]`, and its
  `roundedTick ≥ upper → x = length − 1` clamp). Confirm `i_max` (or `i_max − Δ`) is the right argument by
  differential test against Bunni.

## `liquidity_for_portafolio` (inverse — OPEN, needs a decision)
`liquidity_for_portafolio(ldf_params, coord, price_bucket: PriceBucket, portafolio: Portafolio) -> LiquidityChunk`
`Q_M` and `Q_X` are each linear in `L̄`, so each *independently* determines an `L̄` — the map is
**over-determined**. Open questions for review + user:
- **OPEN B:** which amount sets `L̄`? Candidates: (i) `gross_input_amt` only (token0 side, mirrors
  `liquidity_for_collateral`); (ii) `gross_output_amt` only; (iii) both with a consistency check / `min`.
- **OPEN C:** the `price_bucket` role. `PriceBucket` has `{lower, mid, upper}`. Likely the `mid` is the current
  price splitting the position: token0 funds `[mid, upper]`, token1 funds `[lower, mid]`, so
  `Q_M` inverts `cumulativeAmount0` over `[mid, upper]` and `Q_X` inverts `cumulativeAmount1` over `[lower, mid]`.
  Is that the intent, or is the range the full LDF support (making `price_bucket` redundant, as `PricePair` was)?

## Rounding / guards (carry over from the reviewed collateral spec)
- `L̄` inversion rounds DOWN (conservative); forward amounts use the closed form's internal rounding.
- Guard `L̄ > 2^128 − 1` (Panoptic uint128), and zero-divisor on any inversion.
- `min_tick` sign-extended via `@evm_signextend(2, word0 & 0xffffff)`.
- Non-geometric `kind` → revert (closed-form dispatch only, as decided for collateral).

## Falsifiability
- `portafolio_for_liquidity` — EXACT differential: `gross_input_amt == Bunni.cumulativeAmount0(i_min−Δ, L̄, …)`
  and `gross_output_amt == Bunni.cumulativeAmount1(i_max, L̄, …)` (Bunni imports cleanly).
- Round-trip: `portafolio_for_liquidity(liquidity_for_portafolio(P)) ≈ P` (within one-unit bounds), once OPEN B/C resolved.
