# UNITS AND SCALES — the canonical table (VolOrder v2 D0; lens spec L2 entry condition)

**Status: v2 — two-step review round 1 done (Reality Checker + Solidity/fixed-point
specialist, both NEEDS WORK); all BLOCKERs/MAJORs resolved below. The core D0 decision
(RAW vega units, X96 for prices only, one-stored-number-plus-named-views) survived both
reviews; the fixes are: the deleverage row's integer form (was off by 2^96), the
accumulator mechanism (was fiction), tense discipline (FACT vs PLANNED marked on every
enforcement cell), the tick-view domain, the RAY conflict with tbd.md, kernel signedness,
and the ΔM rounding direction.**

Conventions of this table: every enforcement cell is marked **[FACT]** (exists in code
today, cite) or **[PLANNED — increment]** (forward commitment, named owner). A row that
mixes the two is a defect.

## 0. Fixed-point conventions in play

| Name | Scale | Meaning |
|---|---|---|
| raw | 1 | plain integer count, no binary/decimal point |
| Q64.96 / X96 | 2^96 | price coordinates; `Q96 = 2^96` (Numerics.plk) |
| Q0.96 | 2^96, value ≤ 1 | haircut h |
| WAD | 1e18 | 18-decimal fixed point |
| RAY | 1e27 | rate/precision accumulators. **STATUS: tbd.md:88's RAY-scaled deleverage delta `∂_(M,v)/Δ` is SUPERSEDED by this table's raw convention (§4) — recorded there is a draft note predating the D0 decision. If a vault Σ-aggregation ever needs RAY, it enters as a NAMED view (raw→RAY = ·1e27, rounding pinned at that time), never a reinterpretation** |
| X64 | 2^64 | Panoptic premium accumulator (per-liquidity) |

## 1. The volatility axis

| Symbol | Storage | Unit (CANONICAL) | Enforced |
|---|---|---|---|
| σ² (realized, windowed) | u88 (`getAverageVolatility` return) | **Algebra vol units** — the window-normalized volatilityCumulative average; time-sum of squared tick deviations per the Algebra kernel, per-second basis. RAW integer. | [FACT] u88-masked throughout the byte-exact port (`RealizedVolatilityStateLib`) |
| σ²_K (VolOrder strike = `TickVolatility.vol`) | u88 packed at bits 16..103 | **THE SAME Algebra vol units, RAW integer** — the volStrike-ambiguity resolution. `σ² − σ²_K` needs no scaling op. | [FACT] `strike_fits_packed` (`VolOrderValidationLib.plk:43-46`) is ALREADY wired into `validate_order` — strict path reverts, batch skips; the pack mask is no longer load-bearing on the manager path. [PLANNED — V2-02] the range TIGHTENS to the placement domain, next row |

**Effective strike range (review: the tick view is a PARTIAL function):** the placement
view `getTickAtSqrtRatio(vol << 96)` REVERTS for `vol ≳ 1.84e19 (≈ 2^64)`
(MAX_SQRT_RATIO). Since placement is a live consumer of every order, the VALIDATED strike
range is `[1, PLACEABLE_MAX]` with `PLACEABLE_MAX` the exact pre-computed bound
[PLANNED — V2-02: the predicate adopts it; a strike that cannot be placed is invalid, not
latent]. **Semantic plausibility (did the user MEAN Algebra units?) is deliberately NOT
an on-chain bound** [DECISION]: the wrapper layer owns vocabulary translation and the
lens's identity check catches unit-confused positions; an on-chain "plausible σ²" band
would hardcode a market regime.

**Views of `TickVolatility.vol` (conversions of the ONE stored raw number):**
`volQ64X96 = vol << 96`; `volWAD = vol · 1e18`;
`tick view = getTickAtSqrtRatio(vol << 96)` — DOMAIN `vol ≲ 1.84e19`, used for order
placement.

> FLAG (owned): whether the tick view is the INTENDED pricing-geometry embedding (vs.
> e.g. mapping through p_vol) is a PriceKernel/#14 design question — **owner: the V2-03
> sizing increment; resolve BEFORE V2-03 code** (a flagged exception with no expiry
> becomes permanent).

## 2. The vega axis — DIMENSION DECISION (ii) [user, 2026-07-30]

The doc carries TWO ΔQ_v-shaped objects and this table assigns each a role:
- **VOLATILITY_INSTRUMENTS line 177** (`π^σ = Σ L(i_K)·𝕀`): the payoff CARRIER is
  liquidity — the vol asset's on-chain embodiment. **THE STORED QUANTITY.** ξ⋆ is a
  liquidity ratio; the accounting layer's `totalShares = ΣQ_v^i` treats Q_v as shares
  (a quantity, priced by p_vol/p_risk).
- **VOLATILITY_INSTRUMENTS line 10** (`ΔQ_v ≡ Δπ^σ/Δ(σ²−σ²_K)⁺`): the greek —
  collateral per vol-unit, a SENSITIVITY. **THE LENS READOUT** (`deltaQv_of_payoff`),
  computed from a position, never stored. The bridge between the two is the Q_M^L range
  conversion (liquidity → token amounts over the leg ranges).

| Symbol | Storage | Unit (CANONICAL) | Enforced |
|---|---|---|---|
| ΔQ_v★ (`targetVega`) | u96 packed at bits 152..247 | **RAW LIQUIDITY units — the Uniswap L dimension (u128-native).** The quantity of the priced vol asset. NOT X96, NOT WAD, NOT collateral-denominated. | [PLANNED — V2-01/02] `target_vega_fits_packed` (≤ 2^96 − 1) in `VolOrderValidationLib`, strict reverts / batch skips; `> 0` in the type-level completeness predicate. NOTHING exists today — the field itself is V2-01 |
| `VegaNominal.exposure` (the ONLY real symbol — there is no `VegaExposure.exposure` struct field) | declared u256, comment "u128" | **SAME unit as ΔQ_v★. DEFINITION: 1 "vega-exposure unit" (risk.md §2's phrase) ≡ 1 raw L unit of the vol asset** — closes the dimensional loop of every chain in §4 | [DECISION + PLANNED — V2-01] the enforced bound TIGHTENS to u96; the fit check lives at `VegaNominal` construction sites (the `LiquidityAmounts.plk:42` explicit-guard pattern); the u128 comments in `VegaExposure.plk`/`exposure.md` are updated. Today: UNENFORCED u256 [FACT — `VegaAccount.t.sol:271-274` pins that a 2^200 deposit is accepted] |
| ΔQ_v (the greek, lens output) | not stored; lens view return | collateral base units per Algebra vol unit — computed via the Q_M^L conversion from the position's L(i_K) | lens L1/L2 tests |

**Consequences of (ii) (reviewed rationale updated):**
- **The mint identity becomes LITERAL and quantity-space:** deliver `Σ L(i_K) = ΔQ_v★`
  — exact by the partition of unity Σℓ = 1 (proven, `geomWeight_sum`), up to per-leg
  floor rounding (one-sided ≤). No price enters the SIZING map at all; p_vol/p_risk
  enter at the issuance/admissibility layer only. The mint's collateral requirement is
  the ACTUAL replication cost (the token amounts the mint moves), bounded by
  maxCollateral (the slippage guard against pool-state movement).
- **Headroom:** u96 max ≈ 7.9e28 raw L vs realistic pool liquidity 1e18–1e21 — ≥1e7×
  headroom; the u128-native width is capped u96 by the one-word registry [DECISION;
  `liquidity_for_collateral` already reverts > U128_MAX upstream].
- **Cross-pool comparability:** L is a per-pool dimension — ΔQ_v★ quantities from
  different pools aggregate only through a price (p_vol), exactly as share counts from
  different vaults would. This is natural for a quantity; it was awkward for the greek.
- **Kernel signedness [DECISION, review M1, unchanged]:** the L0 kernel
  `volOptionPayoff(dQv, sig2, sig2K) = dQv·(sig2 − sig2K)⁺` is the CLAMPED positive
  part — a branch (`if σ² ≤ σ²_K → 0`), NEVER a bare checked `−` (which reverts on every
  below-strike evaluation). The kernel is unit-agnostic (the drafted test's contract);
  its collateral-settled instantiation uses the LENS greek, whose derivation routes
  through the Q_M^L conversion.
- **Overflow envelope + THE MECHANISM [corrected — the v1 "u128 checked accumulator" was
  fiction]:** kernel worst case (2^96)·(2^88) = 2^184 < 2^256 — u256 intermediates safe
  [FACT: Plank default ops are checked at u256]. Where results land in bounded
  accounting, the mechanism is **u256 intermediates + an EXPLICIT fit guard**
  (`if x > U128_MAX { revert }` — the `LiquidityAmounts.plk:42` pattern; a checked add
  alone bounds nothing below 2^256) [PLANNED — #13/VegaAccount v2 adds the guard at its
  landing sites; today's `VegaAccountMod` slots are unbounded u256, FACT].

## 3. The price axis

| Symbol | Storage | Unit | Enforced |
|---|---|---|---|
| p_vol(σ̄) (`VegaNominal.priceVolX96`) | u160 | **Q64.96 LINEAR price: collateral base units per 1 raw L unit of the vol asset** — under dimension decision (ii) this is the SAME KIND of object as the LDF cost form (`cost_m`, collateral per unit L̄), which is what makes the issuance conversion a genuine price operation. [DECISION — risk.md §5 explicitly defers p_vol out of its v1 scope; this table EXTENDS risk.md §2's p_risk convention with the (ii) dimension] | [PLANNED] p_vol is NOT needed by the sizing map (the mint is quantity-exact); it prices ISSUANCE/shares and admissibility (v1: carries exogenous p_risk per exposure.md). Zero/staleness guards live where it is consumed |
| p_risk (`RiskPriceX96`) | u256 | Q64.96 linear, = oracle/(1−h) rounds UP (risk.md §3) [FACT] | `p_risk > 0` required (`admissible_iff_mul` hypothesis); **UNBOUNDED ABOVE as h→1** — see §4's mandated mulDiv comparison |
| h (`Haircut`) | Q0.96 | `hX96 < 2^96` | [FACT] checked `−` + zero-denominator revert envelope (risk.md §3) |
| sqrtPriceX96 (pool) | u160 | Q64.96 SQRT price (v4 native) | v4's own |

## 4. The conversion chains (named, rounding pinned, INTEGER FORMS EXACT)

| Chain | Integer form | Rounding |
|---|---|---|
| ΔQ_v★ → the position (mint SIZING, dimension (ii)) | `L(i_K) = ΔQ_v★ · ℓ(ξ⋆, ι; i_K)` per leg; `Σ L(i_K) = ΔQ_v★` exact by Σℓ = 1 | per-leg FLOOR → delivered total ≤ ΔQ_v★, one-sided (the lens identity bound) |
| mint COLLATERAL requirement | the ACTUAL replication cost — the token amounts the SFPM mint moves (`totalSwapped`/deltas), checked against `maxCollateral` | as the AMM computes; `maxCollateral` is the slippage/manipulation guard (exact-output in QUANTITY, bounded input in collateral) |
| ΔQ_v (shares/issuance valuation) → ΔM | `ΔM = mulDivRoundingUp(ΔQ_v, p_volX96, Q96)` — quantity × price = collateral | **UP** [review M3]: charged input rounds AGAINST the requester, composing with p_risk's UP so an exactly-funded issuance sits AT-or-above the admissibility floor |
| ΔM → shares | `mulDiv(deposit, Q96, pRiskX96)` | DOWN [FACT — risk.md §3] |
| ΔM → L̄ → positionSize | `liquidity_for_collateral` chain | DOWN; `> U128_MAX` reverts [FACT — LiquidityAmounts.plk:42,110] |
| **Deleverage admissibility** [CORRECTED — v1 omitted the Q96 scale, both reviewers] | predicate: `ΔQ_v · pRiskX96 ≤ Q_M · 2^96` — EXACT, zero rounding (an advantage: the guard itself never rounds). **MANDATED comparison form: 512-bit/mulDiv-based** (`ΔQ_v ≤ mulDiv(Q_M, Q96, pRiskX96)` or the mulmod 512-bit compare from the VegaIssuance suite) because `pRiskX96` is unbounded above as h→1 and a bare checked `ΔQ_v·pRiskX96` would REVERT-DoS the admissibility check exactly when deleverage is most needed | enforced level `= mulDiv(Q_M, Q96, pRiskX96)` DOWN (exposure down = burn up) |
| implied maturity | `t★ = 2·ΔQ_v/N_σ` | **UNIT: seconds, CONFIRMED** by `EndogenousMaturity.lean` (run 128b24ae): the formal bookkeeping (σ²·t dimensionless, υ time-dimensioned, `tStar_variancePortfolio_upsilon`) forces `[ΔQ_v★] = [N_σ]·time`, so under dimension (ii) **N_σ is L PER SECOND (a liquidity rate, NOT a liquidity)** and t★ is seconds via σ²'s per-second basis. Remaining open on issue #1: only the AUTHOR'S recalibration-law pick (t★_mult / t★_sub / t★_quad, all proven sane) |
| Panoptic premium → tokens (lens L2) | `PanopticPool._getPremia` computes `(acctPremiumDelta × chunkLiquidity) / 2^64` as an **UNCHECKED RAW multiply** (PanopticPool.sol:2293-2315) — NOT a 512-bit mulDiv, and the multiplicand is CHUNK liquidity (not `_getPremiaDeltas`' netLiquidity). **The lens must replicate the RAW form** — a true-mulDiv lens diverges wherever the raw mul would wrap; this is an input to the L2 rounding-tolerance analysis | as Panoptic computes |

## 5. Rules (bind all V2 and lens increments)

1. **One stored number, one canonical unit; other representations are NAMED view
   functions** with declared domains (a partial view states its domain).
2. **No silent masks as validation.** Executable form [review m3]: (i) mask-identity on
   the accepted domain — ∀x accepted by validation, `pack(x)` with and without the mask
   are equal; (ii) round-trip `unpack(pack(x)) == x`; (iii) the mutant that deletes the
   validator but keeps the mask MUST fail the out-of-range fuzz case.
3. **Every cross-base conversion is a single fused mulDiv with a stated rounding
   direction**; comparisons against unbounded-above Q96 quantities use mulDiv/512-bit
   forms, never bare products.
4. **X96 is for PRICES; vol and vega quantities are RAW; RAY is superseded for the
   deleverage delta.** The one flagged exception (the tick-view embedding) has an owner
   and a deadline (§1).
5. **Every enforcement cell is [FACT] with a cite or [PLANNED] with an owner** — a units
   table that mixes fact and plan reproduces the volStrike failure mode at the meta
   level.
