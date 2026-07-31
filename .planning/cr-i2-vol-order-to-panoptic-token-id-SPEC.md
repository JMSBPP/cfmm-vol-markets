# CR-I2 — `VolOrder → PanopticTokenId` design spec (v3, Layer 1 skeleton)

Status: IMPLEMENTED (Layer 1), v3. Two-step-reviewed (2 rounds), then built via 6 TDD increments
(commits a15d119..a608243 + width-guard/fuzz). 10 CR-I2 tests green + PanopticTokenId regression 4/4.
Layers 2 (geometric weights at mint, ξ⋆=1.0001^(−Δ_i/2)) and 3 (cap/σ²_K payoff) remain future work.

Prior status: DRAFT v3 (post review-round-2). v1 and v2 were each reviewed by Reality Checker + Solidity
Smart Contract Engineer. v2 retired 5 of the v1 findings (σ²_K/cap incoherence, ξ⋆-overclaim,
optionRatio-can't-carry-weights, leg-ordering, packing-only-tests). Round-2 left two blockers
(tickSpacing written 5×; even-width tiling infeasible) — v3 dissolves both with a single **floor-strike
leg-only encoder** and downgrades the Layer-1 claim from "replicates σ²_R" to "**skeleton**" per the
Reality Checker. The parity math is confirmed sound (Solidity review, incl. the negative-tick case).

## 0. Layering (the architecture the reviews forced out)

A `VolOrder` (a variance-swap order) is replicated in three stacked layers. The doc's own
decomposition `π^σ = ΔQ_v·(σ²_R − σ²_K)⁺` (`notes/VOLATILITY_INSTRUMENTS.md`) *is* this stack:

- **Layer 1 — position STRUCTURE / SKELETON (THIS deliverable, CR-I2).** `VolOrder → PanopticTokenId`:
  a 4-leg, all-long Panoptic position whose legs tile the strike support `[i_l, i_u]` and split
  put/call at the skew-center `i*`. It lays out the **strike-support + put/call skeleton on which the
  Layer-2 σ²_R replication is built** — it does NOT itself replicate σ²_R, because in Carr–Madan /
  Demeterfi static replication the strike WEIGHTS (∝1/K², Layer 2) *are* the replication; a uniform
  4-leg skeleton is not yet a variance instrument. Layer 1 carries NO weights and NO variance strike.
  Its correctness criterion is purely structural: **the tokenId is valid and mintable** (passes
  Panoptic `validate()`, reconstructs to tickSpacing-aligned ticks, legs distinct and contiguous) and
  its legs tile `[i_l, i_u]` with the put/call boundary at `i*`.
- **Layer 2 — WEIGHTS at mint (future).** Per-leg `positionSize`/liquidity `= L̄·geomWeight(ξ⋆, ι, ·)`
  with `ξ⋆ = 1.0001^(−Δ_i/2)`, realized when the position is minted ("longing options = providing
  liquidity"). This is where `ξ⋆`, `rpow`, and the geometric profile live — NOT in the tokenId.
- **Layer 3 — vol-option PAYOFF (future).** `π^σ = ΔQ_v·(σ²_R − σ²_K)⁺` — consumes the realized
  variance `σ²_R` the Layer-1 strip delivers, applies the strike `σ²_K` and the `(·)⁺` cap. This is
  where `σ²_K` and the cap live (`Panoptic.volOptionPayoff` is the Layer-3 function).

**Consequence:** `σ²_K` and the cap are not "dropped" — they are Layer 3. The geometric weights are
not in the 7-bit `optionRatio` — they are Layer 2. Layer 1 is a pure structural map (a skeleton), and
makes no variance-replication claim on its own.

## 1. Objective (Layer 1)

Implement in `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk`:

```
vol_order_to_panoptic_token_id : (VolOrder, pool_id) → PanopticTokenId   // 4-leg, all-long, mintable
```

Remove the stray duplicate `PanopticTokenId` struct currently at lines 6–8 of that file (it shadows
the real `types::protocol_integrations::PanopticTokenId`). Import the real type + the tested
leg-encoder primitives and build ON `panoptic_token_id_from_tick_bucket` (do not hand-pack).

## 2. Grounding — Layer-1 claims trace to proven lean statements

Verified present (Reality Checker grep: no `sorry`/`admit`/`axiom` in any cited file).

| Layer-1 claim | Lean lemma / def | File |
|---|---|---|
| `VolOrder{σ̄, #_σ̄/Δ_i, s_v} → (i_l, i_u, i*)`, `i* = s_v·i_l+(1−s_v)·i_u` | `PosSpec.skewTick`, `skewTick_gap_lower/upper`, `width_span` | `vol_markets/PosSpec.lean:49,70,78,86` |
| `i*` (skew-center) = the vol tick (matches `split_tick`) — ASSERTED (algebraic collapse of `skewTick`, not a standalone cited lemma) | `PosSpec.skewTick` + `split_tick` | `PosSpec.lean:49` + `src/types/pos_spec/SpreadTickAssimetry.plk:30` |
| strip legs split put/call at the ATM-forward boundary `p* = i*` | Demeterfi PDF1 p18 (EQ25) | `refs/DemeterfietalVarianceSwaps.pdf` |

Note the **continuous** log contract is a variance instrument (`VolInstrument.logPortfolio:307`,
`variancePortfolio:310`, constant vega `variancePortfolio_upsilon:327`) — but that is a Layer-2/3
fact about the *weighted* contract, NOT a Layer-1 claim that the unweighted skeleton replicates σ²_R.
Layer 1 cites it only as motivation, not as certification of the skeleton.

Layer-2/3 lemmas (`GeomProfile.*`, `strikeWeight_bridge`, `logContractLiquidity_geometric`,
`volOptionPayoff`, `variancePortfolio_upsilon`) are cited by those layers, not here. Note for Layer 2:
`logContractLiquidity_geometric` proves *geometricity given* the `K^(−1/2)` density; the density
premise itself (that `K^(−1/2)` IS the log-contract v3 liquidity) is flagged **future work**
(curvature bridge, `GeomProfile.lean:294–299`) — so Layer 2 must treat ξ⋆ as "geometricity proven,
density premise asserted," not "ξ⋆ proven."

## 3. Locked decisions

- **Instrument (Layer 1):** the all-long **skeleton** of the log-contract strip → all 4 legs LONG
  (`isLong = 1`), puts below `i*`, calls above. (Weights = Layer 2; the capped option = Layer 3.)
- **Strike coverage:** 4 legs are 4 contiguous sub-buckets that **tile** `[i_l, i_u]` (no
  slivers, no gaps), two below `i*` (puts) and two above (calls). Replaces v1's `width=1` point
  ladder. Each sub-bucket is encoded with a **floor-strike leg encoder** (§4) that reconstructs
  exactly for any sign/parity — so NO even-width constraint is needed (that was a v2 workaround).
- **Weights:** NOT in the tokenId. Layer 1 sets a uniform structural `optionRatio = 1`.

## 4. The Layer-1 map (algorithm)

Inputs: `vo: VolOrder`, `pool_id: u256` (the low **48 bits** = univ3 pattern + vegoid; tickSpacing is
added separately — see §5 M1 fix). Precondition: `vo.rangeWidth.tickSpacing` equals the target pool's
tickSpacing (Panoptic matches the pool by the full 64-bit poolId incl. tickSpacing).

**New leg-only encoder** (added to `PanopticTokenId.plk`; fixes BLOCK-A + BLOCK-B). Writes ONLY the
per-leg strike+width — NOT tickSpacing — using the exact floor-strike that Panoptic `getTicks`
reconstructs for any sign/parity:

```
// strike = lo + floor((hi-lo)/2);  width = (hi-lo)/Δ.  reconstructs [lo,hi] EXACTLY (any sign/parity).
const panoptic_add_leg_from_bucket = fn (tid: u256, lo: u256, hi: u256, ts: u256, leg: u256) u256 {
    let span   = hi -% lo;                 // > 0 (aligned bounds, hi > lo)
    let strike = lo +% (span </ 2);        // floor; matches getRangesFromStrike rangeDown = floor(span/2)
    let width  = span </ ts;               // exact (span is a multiple of ts)
    panoptic_add_width(panoptic_add_strike(tid, strike, leg), width, leg)
};
```

Main map:

```
Δ   = vo.rangeWidth.tickSpacing
i*  = round_tick(tick_volatility_tick(vo.volStrike), Δ)           // skew-center / p* boundary
tb  = tick_bucket_from_vol_order(vo)                               // (low=i_l, up=i_u, tickSpacing=Δ)

require distinct-4-leg feasibility (§6 guard):
    (i*  -% i_l) >=s 2*Δ  and  (i_u -% i*) >=s 2*Δ                 // each side splits into 2 non-degenerate legs (width >= 1)
    MIN_POOL_TICK <s i_l  and  i_u <s MAX_POOL_TICK                // §6 m-a (clamped pool bounds, not raw MIN/MAX_TICK)
    (i_u -% i_l) </ Δ  <s  4096*2                                  // §6 m-b: each of 4 legs' width < 4096 (12-bit field)

m_p = round_tick(i_l +% ((i* -% i_l) </ 2), Δ)                     // put-side split point (Δ-aligned; ANY parity ok now)
m_c = round_tick(i*  +% ((i_u -% i*) </ 2), Δ)                     // call-side split point

subs = [ (i_l, m_p), (m_p, i*), (i*, m_c), (m_c, i_u) ]           // 4 contiguous sub-buckets
tokenTypes = [ 0, 0, 1, 1 ]                                        // put, put | call, call  (split at i*)

tid = 0
for L in 0..3:
    (lo, hi) = subs[L]
    tid = panoptic_add_leg_from_bucket(tid, lo, hi, Δ, L)         // strike+width only (NO tickSpacing)
    tid = panoptic_add_token_type(tid, tokenTypes[L], L)
    tid = panoptic_add_is_long(tid, 1, L)
    tid = panoptic_add_option_ratio(tid, 1, L)                    // uniform; weights are Layer 2
    tid = panoptic_add_risk_partner(tid, L, L)                    // self-partner (valid, §5)
    tid = panoptic_add_asset(tid, ASSET, L)                       // §6 open: 0 = token0 default
tid = panoptic_add_pool_id(tid, pool_id & 0xffffffffffff)         // low 48 bits ONLY (M1 fix)
tid = panoptic_add_tick_spacing(tid, Δ)                           // writes bits 48..63 EXACTLY once

return PanopticTokenId { tokenId: tid, num_legs: 4 }             // struct field renamed leg_index→num_legs (§6 m3)
```

No `even_round`, no even-width constraint: `panoptic_add_leg_from_bucket`'s floor-strike reconstructs
`[lo,hi]` exactly for any parity/sign, so the split points only need Δ-alignment (guaranteed by
`round_tick`) and each side ≥ 2Δ (guaranteed by the guard → each leg width ≥ 1).

## 5. Review fixes folded in (through round-2)

- **BLOCK-B / v1-B1 (unmintable / even-width parity)** → resolved by the **floor-strike leg encoder**
  `panoptic_add_leg_from_bucket` (§4): `strike = lo + floor((hi−lo)/2)` reconstructs `[lo,hi]` exactly
  for ANY sign/parity (Solidity review confirmed the parity math, incl. negative ticks). No even-width
  constraint, so the `≥2Δ` guard suffices and no `even_round` is needed.
- **BLOCK-A (tickSpacing written 5×)** → resolved: the new leg encoder writes ONLY strike+width; the
  main map calls `add_tick_spacing(Δ)` exactly once. (The old `panoptic_token_id_from_tick_bucket`
  wrote tickSpacing internally per call — that is why it is NOT reused here.)
- **Latent bug flagged (existing code).** `panoptic_token_id_from_tick_bucket:51` uses
  `sdiv(low+up,2)` (truncate toward zero), which mis-reconstructs **negative odd-span** buckets by +1
  (off-grid). Its single-leg test only covers positive buckets. Out of CR-I2's critical path (we use
  the new encoder), but a follow-up should add a negative-bucket test and switch it to floor-strike.
- **B2 (incoherent instrument)** → resolved by §0 layering: Layer 1 is the skeleton; `σ²_K`/cap are
  Layer 3; weights are Layer 2.
- **M1 (poolId double-write)** → `pool_id` is the **low 48 bits only**; `add_tick_spacing(Δ)` writes
  bits 48–63 exactly once (now truly once, since the leg encoder no longer writes it).
- **M2 (ξ⋆ rpow) / M-optionRatio / MAJOR-2 (overstated ξ⋆)** → out of Layer-1 scope (weights = Layer
  2). No `rpow`, no ξ⋆ here. Debt carried to Layer 2: fractional-exponent `rpow` + `optionRatio ≤ 127`
  saturation policy.
- **MAJOR (RC r2): "replicates σ²_R" overclaim** → downgraded to "skeleton" throughout (§0, §3, §7).
- **M3 (leg ordering/uniqueness)** → guard + strictly increasing split points + distinct
  `riskPartner=L` per leg ⇒ no error-6 chunk collision; contiguous from leg 0; `optionRatio=1 (≠0)`.
- **self-riskPartner** confirmed valid (`TokenId.sol:505–515`, `riskPartnerIndex==i` skips the mutual
  check).

## 6. Open sub-decisions (for re-review)

1. **`asset` numeraire** (token0=0 vs token1=1): denomination of position size; depends on pool token
   order / `Q_M`=token0 convention. Default `0`; confirm.
2. **Sub-bucket split rule.** §4 splits each side at its Δ-aligned midpoint. Alternative: split at
   geometric-weight quantile boundaries so each leg carries ~equal Layer-2 liquidity mass. Midpoint is
   simpler and Layer-1-agnostic (weights are Layer 2); flag for review.
3. **Narrow-bucket behavior.** The §4 guard reverts when a side is `< 2Δ` wide. Alternative: collapse
   to a 2-leg (single put + single call) position. Revert is the conservative Layer-1 default.

### Round-2 minors folded into the §4 guard
- **m-a — clamped pool bounds.** Guard tests `MIN_POOL_TICK <s i_l` / `i_u <s MAX_POOL_TICK`
  (`Constants.sol:12–15`), NOT raw univ3 `MIN/MAX_TICK` — `validate()` error 4 rejects strikes at the
  *clamped* extremes.
- **m-b — width ≤ 4095.** Guard bounds each leg width < 4096 (12-bit field; `getChunkKey` reverts on
  `width ≥ 4096`, `PanopticMath.sol:460`). Since each of the 4 legs is ~¼ of the span, the guard uses
  `(i_u−i_l)/Δ < 2·4096` as the necessary bound (per-leg widths re-checked in the mint-recon test).
- **m-c — silent tickSpacing override.** `pool_id & 0xffffffffffff` discards any tickSpacing the
  caller packed into `pool_id[48..63]`; Δ from the VolOrder governs. Documented so a mismatched
  caller tickSpacing fails loudly upstream (the §4 precondition), not silently here.

### Confirmed non-issues (from review)
- 4-leg = 256-bit packing sound (leg-3 width ends exactly at bit 255).
- `strike` holds the tick directly; signed-24-bit round-trip correct (negative-tick test, §9.6).
- Floor-strike parity confirmed sound for any sign/parity (Solidity r2).

## 7. Known limitations (stated, not hidden)

- **Skeleton ≠ replication (RC r2).** Layer 1 uses UNIFORM `optionRatio=1`; these are NOT the
  log-contract strike weights (∝1/K², Layer 2). So Layer 1 is a structural skeleton, not a variance
  replication — the σ²_R replication only exists once Layer-2 weights are applied. Two distinct error
  sources must not be conflated: (i) the missing-weights gap (Layer 1 is unweighted by design), and
  (ii) the 4-leg truncation below.
- **4-leg truncation.** Tiling `[i_l,i_u]` with only 4 sub-buckets, the (eventual, weighted) exposure
  goes linear beyond `i_l`/`i_u` and is coarse inside → an *approximation* of the ideal strip
  (Demeterfi PDF1 p27–28, Table 4: bias grows with maturity and range-exit). Layer 1 makes no
  exactness claim; it delivers a valid, mintable, correctly-structured 4-leg skeleton.
- **Real-vs-integer rounding.** The `skewTick = vol tick` identity is exact over ℝ; after independent
  `round_tick` of `i_l`/`i_u` it holds up to one tickSpacing. Tests assert bounded (±Δ) tolerance,
  not exact equality (§9).
- **θ mis-citation (lean-spec track, not CR-I2).** `Panoptic.lean thetaAtm`'s "center column" reads
  θ as the implied-tree vol-of-vol; the correct anchor is Demeterfi EQ10/12. De-scoped to lean-spec.

## 8. API surface

```plank
// src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk
import types::protocol_integrations::PanopticTokenId::*;   // struct + panoptic_add_* + new panoptic_add_leg_from_bucket
import types::pos_spec::VolOrder::*;                        // VolOrder, tick_bucket_from_vol_order
import lib::pos_spec::TickVolatilityLib::*;                 // tick_volatility_tick
import types::pricing::TickUtils::{round_tick, TickBucket};

const vol_order_to_panoptic_token_id = fn (vo: VolOrder, pool_id: u256) PanopticTokenId { ... };
```

No `rpow` / `FixedPointMath` import (weights are Layer 2).

## 9. Test plan (TDD — RED first)

Harness `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk`; reuse the trusted
`panoptic_*` decoders. Selectors: `tokenIdFromVolOrder(packedVO, poolId)->uint256`,
`centerTick(packedVO)->int24`, `bucketFromVolOrder(packedVO)->(int24,int24,int24)`.

Layer-1 correctness = **valid + mintable + correctly structured** (NOT variance-replication semantics
— that needs Layers 2+3 and is deferred):

1. **Golden structure.** Fixed VolOrder → decode 4 legs; assert `isLong=1` all, `tokenType`
   `{put,put,call,call}` around `i*`, `tickSpacing=Δ`, legs contiguous from 0, `optionRatio=1`.
2. **Mint-reconstruction (the BLOCK-A/B guard).** For each leg, run its `(strike,width,tickSpacing)`
   through a Solidity replica of Panoptic `getTicks`/`getRangesFromStrike`; assert reconstructed
   `[tickLower,tickUpper]` are **tickSpacing-aligned** and equal the sub-bucket bounds — including
   **odd-span and negative-tick buckets** (the floor-strike correctness case). Also assert decoded
   `tickSpacing == Δ` exactly (catches the 5× write regression). This is the test that would have
   caught v1's unmintable tokenId and v2's tickSpacing accumulation.
   Add a direct unit test of `panoptic_add_leg_from_bucket` over fuzzed `(lo,hi,Δ)` incl. negatives.
3. **Tiling.** The 4 sub-buckets are contiguous and cover `[i_l, i_u]` exactly (leg0.low=i_l,
   leg3.up=i_u, leg_k.up == leg_{k+1}.low), and the put/call boundary is at `i*`.
4. **Panoptic `validate()`.** Feed the tokenId to a Solidity harness calling the real
   `TokenId.validate()` (imports cleanly? if not, inline the checks) → must not revert; assert no
   duplicate chunk (error 6), no extreme-tick strike (error 4).
5. **Distinctness guard.** VolOrders with a `< 2Δ` side revert (or collapse, per §6.3 decision).
6. **Negative-tick round-trip.** Buckets straddling tick 0 → put/call split and signed strikes decode
   correctly (§6 m2).
7. **Bounded fuzz** over (σ̄ tick, #_σ̄, s_v, tickSpacing) in `split_tick`'s safe range: never reverts
   (except the guard), every tokenId passes tests 1–4, `skewTick=vol tick` holds within ±Δ.

## 10. References

- Demeterfi–Derman–Kamal–Zou, *Variance/Volatility Swaps*, GS 1999 — `refs/DemeterfietalVarianceSwaps.pdf`.
- Derman–Kani, *Stochastic Implied Trees*, GS 1997 — `refs/stochastic_implied_tree.pdf`.
- `notes/VOLATILITY_INSTRUMENTS.md` (the `ΔQ_v·(σ²_R−σ²_K)⁺` stack = the 3 layers).
- `../lean4-spec/lean/vol_markets/{PosSpec,GeomProfile,VolInstrument,Panoptic}.lean`.
- Panoptic schema: `lib/panoptic-v2-core/contracts/types/TokenId.sol` (validate 473–518),
  `libraries/PanopticMath.sol:406–466` (getTicks/getRangesFromStrike), `libraries/Constants.sol:12–15`.
- Reused primitives: `src/types/protocol_integrations/PanopticTokenId.plk:24–56`.
