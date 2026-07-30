# DATA CONTRACT — Plank events → subgraph → GAMS database (producer half of DATA-08)

Spec: `.planning/events-subgraph-gams-SPEC.md` (v2, two-step-reviewed). Consumer half (the
`execute_loadDC` reader) is the cfmm-gams repo's work, delegated by issue (EV-06); this
document is written so that agent can implement WITHOUT reading Plank sources.

Notation is binding: doc symbols come from `notes/VOLATILITY_INSTRUMENTS.md` and
`cfmm-gams/model/spec/*.md`; Algebra field names are verbatim from
`AlgebraFeeConfiguration`. No interpretive renames on either side.

## 1. Event catalog

| # | Signature | topic0 (keccak256 of signature) | Emitter | Status |
|---|---|---|---|---|
| E1 | `VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew)` | `0x6a5dc72627af2833e83e355ac3f2217c1ebee6afe8249d81d035bd1e0f9ee1a5` | VolOrderManagerMod (create_order + per-success in create_orders) | LIVE |
| E2 | `PortafolioMinted(uint256 indexed orderId, bytes32 indexed poolId, uint256 tokenId, uint160 xi, uint24 iota, uint128 liquidityBar)` | — (pin at implementation) | mint/replication module (task #14) | SPEC-ONLY |
| E3 | `TimepointWritten(bytes32 indexed poolId, uint32 timestamp, int24 tick, uint88 volatilityCumulative, int24 averageTick, int56 tickCumulative)` | `0x44d3c76a584327df3a91e46e185e97959195c01202945078eebb23b19c161415` | RealizedVolatilityMod (initializeTWAP seed + every write_timepoint, incl. the reactive onPriceUpdate path) | LIVE |
| E4 | `FeeConfigurationChanged(bytes32 indexed poolId, uint16 alpha1, uint16 alpha2, uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2, uint16 baseFee)` | `0x0b849672f272805103d1934909aaee0c4e1400438ff5365f6d9d147cb07ed6cf` | DynamicFeeMod (initializeDynamicFee + changeFeeConfiguration, after validate) | LIVE |
| E5 | `FeeApplied(bytes32 indexed poolId, uint88 sigma, uint24 fee)` | — (pin at implementation) | DynamicFeeHook beforeSwap (task #16) | SPEC-ONLY |
| E6 | `WindowChanged(bytes32 indexed poolId, uint32 window)` | `0x046630eacacfeb3f36a64fd8cb291b41c3e78bcd57f8733e12b9afeb69968b47` | RealizedVolatilityMod (write_window; initializeTWAP routes the default through it) | LIVE |

Emission-order guarantees the indexer may rely on:
- `initializeTWAP` emits `[WindowChanged, TimepointWritten]` in that order, same tx.
- A same-block second write emits NOTHING (no state transition, no event).
- In `create_orders`, events are per-SUCCESS and positionally faithful: a skipped tuple
  emits nothing and does not shift its successors' orderIds.

## 2. Series identity (DATA-06)

- `poolId = bytes32(0)` is a PERMANENT first-class sentinel: "module-global — applies to
  every pool bound to this emitter". The module-keyed emitters (RealizedVolatilityMod,
  DynamicFeeMod) emit 0 forever; the pool-keyed hook (task #16) is a DIFFERENT emitter
  address emitting real v4 PoolIds. No topic ever changes meaning mid-history.
- `seriesIdHash = uint48(keccak256(abi.encode(chainId, emitter, poolId)))` — uint48 < 2^53
  so it survives a GAMS numeric (IEEE-double) load losslessly. Computed identically
  subgraph-side and GAMS-side; it is THE provenance scalar DATA-06 requires. Never load a
  uint256 hash into a GAMS parameter (silent ~200-bit loss).

## 3. Timestamps → `tObs(tAll)` (DATA-02)

`tObs` loads the EMITTED `timestamp` field of E3 (it is what the σ² kernel consumed), NOT
the block timestamp. The subgraph records `event.block.timestamp` alongside as provenance
and flags rows where the two diverge (possible under direct harness-style calls; on the
reactive path the module stamps `block.timestamp & 0xffffffff` itself, so they agree).

## 4. Field → GAMS symbol → scale

| Event.field | ABI type | Doc symbol | GAMS target | Conversion |
|---|---|---|---|---|
| E3.timestamp | uint32 | t | `tObs(tAll)` | none (unix seconds, u32-wrapped) |
| E3.tick | int24 | i | observed-tick series | none (signed integer tick) |
| E3.volatilityCumulative | uint88 | Σσ² accumulator | input to `realized_variance` (DATA-03) | windowed σ² = (vol(t) − vol(t−W)) / W with W from E6; Algebra units: tick²·s |
| E3.averageTick | int24 | ī (window mean) | `mean_tick` cross-check | none |
| E3.tickCumulative | int56 | ∫i dt | tick-series integration cross-check | none |
| E6.window | uint32 | W (rv_bar normalizer, DATA-07) | window parameter of the σ² series | seconds |
| E1.strike | uint88 | σ²_K | vol-strike (VOL-port layer; `FeeSchedule.Params.volStrike` analog) | Algebra vol units (tick²·s) |
| E1.width | uint24 | Δ_i-shaping (order width) | `tickSpacingVal`-adjacent | integer ticks |
| E1.skew | uint16 | skew | instrument-spec side | dimensionless |
| E2.xi | uint160 | ξ⋆ = λ^(−Δ_i/2) | `xiVal` / `xiNorm` | Q96: divide by 2^96 for the dimensionless ξ |
| E2.iota | uint24 | ι | `iotaVal` | integer support length |
| E2.liquidityBar | uint128 | L̄ | `Lbar` (raw) / `LbarQ128` (payoff units) | raw uint128; payoff layer wants ×2^128 of the unit value — see REPR-07 caveat |
| E2.tokenId | uint256 | leg encoding (i_K, widths) | strike grid | decode subgraph-side, §6 |
| E4.alpha1/alpha2 | uint16 | α_j | Θ_φ (VOL-port layer) | pips (fee units) |
| E4.beta1/beta2 | uint32 | β_j | Θ_φ | Algebra vol units |
| E4.gamma1/gamma2 | uint16 | γ_j | Θ_φ | Algebra vol units (s_f = 1/γ) |
| E4.baseFee | uint16 | φ̄ | Θ_φ | pips |
| E5.sigma | uint88 | σ(i(t)) (windowed) | fee-input σ series | Algebra vol units |
| E5.fee | uint24 | φ(σ(i(t)); t) | λ_FLAIR flow-weight series | pips; == joined Swap.fee (§5) |

Constants (not event-fed): λ = 1.0001 (`lambda`/WAD in GAMS); η = 1/2 for the on-chain
pool (`etaWeight`); the Q96/Q128/WAD scale factors above.

## 5. The E5 ↔ PoolManager `Swap` join (per-swap flow data)

NOT "by poolId". The well-defined key: **same transaction, same poolId,
`FeeApplied.logIndex < Swap.logIndex`, nearest-preceding adjacency.** Guaranteed by
v4-core's ordering: the hook emits inside beforeSwap; PoolManager emits `Swap` after the
swap math and deliberately before afterSwap (PoolManager.sol:238 "events are always
emitted in order"), and the manager is locked during the swap.

**Integrity invariant (assert on EVERY joined pair):** `FeeApplied.fee == Swap.fee` —
v4's Swap carries the fee actually used including the hook override, so a wrong join is
instantly detected. Under SFPM multi-swap blocks several E5 share one E3 (same-block
write early-out); E5's sigma is what keeps the per-swap series complete.

## 6. Rows indexed from OTHER contracts (deliberately not re-emitted)

| Quantity | Source event | Doc/GAMS symbol |
|---|---|---|
| swap flows Δ^I, Δ^O, sqrt price, current tick, pool liquidity | PoolManager `Swap(PoolId indexed, ...amount0, amount1, sqrtPriceX96, liquidity, tick, fee)` | `dxVal`, sqrt-price series (Q64.96), i, L̄ |
| reserves X, Y | PoolManager `ModifyLiquidity` / `Initialize` + Swap deltas | `init(inventory)` → time-indexed |
| premia | Panoptic SFPM / PanopticPool events (premia ARE pool swap fees) | premium series (VOL-port layer) |

**TokenId decode (E2.tokenId):** layout pinned to the vendored `lib/panoptic-v2-core`
commit `5555b320663385f0ab0c8fa511c74d4f0e34cb80` (2025-12-c4mr-freeze). int24 strikes
inside the 48-bit leg packing are two's complement and need MANUAL sign extension in
AssemblyScript (`graph-ts` BigInt bit ops). The subgraph decoder MUST validate against
golden vectors exported from the existing Plank/Solidity TokenId tests (same vectors both
sides) before any deployment.

## 7. Join closure and known gaps

- An E1 order row attaches to a pool series ONLY via E2's (orderId, poolId) pair. Until
  task #14 ships E2, σ²_K rows are UNJOINED — index them, but do not fabricate a pool
  linkage.
- E5 does not exist until task #16; the fee series until then is reconstructible from E4
  (config) + E3 (σ inputs) through the AdaptiveFee formula, but the per-swap observed
  series is authoritative once live.
- GAMS-side obligations this contract assumes: DATA-01 (`execute_loadDC`, compiles with
  no data), DATA-02 (`tAll`/`tObs`), DATA-03/05/07 (windowed RV + rv_bar), DATA-04
  (linear lag only), DATA-06 (numeric `seriesIdHash`, §2 here).
