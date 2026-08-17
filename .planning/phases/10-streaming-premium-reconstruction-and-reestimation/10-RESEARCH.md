# Phase 10: Streaming Premium Reconstruction and Re-estimation — Research

**Researched:** 2026-07-20
**Domain:** Uniswap V4 fee-growth accounting; Panoptic V2 premium accumulators; Haskell EVM state ingestion
**Confidence:** HIGH on mechanics (read from deployed source + verified by live on-chain probes); MEDIUM on the reconciliation error magnitude (not yet measured)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Reconstruction fidelity — FULL V4 REPLAY**
- Reproduce Uniswap's exact `feeGrowthInside` identity: track `feeGrowthGlobal` increments (fee/liquidity per swap) **and** `feeGrowthOutside` at **every tick boundary crossed**, from the cached swap stream.
- The in-range-fraction approximation is **rejected**: it reintroduces LHS measurement error, which is precisely the defect that killed Phase 9.
- This is the heaviest module of the phase; budget accordingly. Correct-by-construction, and its correctness is checkable against ground truth (see validation gate).

**Premium definition — PANOPTIC PREMIUM (not raw fees)**
- π_it = fee growth **× Panoptic's utilization-based multiplier/spread** — the quantity buyers actually pay, and the same object `OptionBurn.premium` aggregates. This is what makes the validation gate meaningful.
- Consequence to state explicitly in the analysis: π_it is then Panoptic's premium, **not** the bare `streamingPremium`/STREAMING_PREMIUM.md fee-revenue identity that Lean models. The multiplier is a documented wedge between the Lean object and the estimated object — the cross-walk table must record it rather than paper over it.
- The exact multiplier formula must be sourced from Panoptic's contracts/docs during research, not guessed.

**Validation gate — HARD, median relative error ≤ 10%**
- **Estimation does not run** until reconstructed-Σ-over-spell reconciles with observed `OptionBurn.premium` across the 61 Phase-9 spells at **median relative error ≤ 10%**.
- The full error distribution (not just the median) is reported: quantiles, worst cases, and any systematic sign bias.
- If the gate fails: diagnose and fix the reconstruction — do NOT proceed to estimation, and do NOT relax the tolerance to pass. A failed gate is a legitimate phase outcome.
- Rationale: this is the discipline Phase 9 lacked; it converts "did we measure the right thing?" from a post-hoc audit question into a pre-estimation blocker.

**Power / stopping rule — PRE-COMMITTED, result-independent**
- **Success = an informative υ₀ interval**, defined as clustered-CI half-width **≤ ~6.2e-5** (≤ ¼ of Phase 9's ±2.48e-4) — **regardless of κ̂'s sign or significance**. Success is explicitly NOT contingent on the result's direction.
- If κ̂ > 0 with adequate precision: state that the fitted profile satisfies the hypotheses of the **proved, axiom-clean** `Upsilon.exp_family_witnesses_ATMOTM` and therefore witnesses `ATMOTMNullHypothesis` at c = κ̂·Δi.
- If the interval remains uninformative after a passing validation gate: **report that this market cannot identify υ, and STOP.** No respecification, no subsample hunting, no alternative-estimator fishing. (See `anti-fishing-replication` skill — invoke it if anyone, human or agent, proposes moving the goalposts mid-run.)

### Claude's Discretion
- Haskell module layout for the replay engine; caching/checkpointing strategy for the tick-crossing state machine.
- Whether the reconciliation runs on all 61 spells or a stratified subsample first (as a fast pre-check) before the full gate.
- Epoch alignment details, so long as `Panel.Build.dailyEpoch` remains the single source of truth for the join (the 40587-offset trap 09-05 caught).

### Deferred Ideas (OUT OF SCOPE)
- Re-running the GAMS cross-check (09-10) and audit-econ gate (09-11) against Phase 10's results rather than Phase 9's null — sequence after this phase produces an informative estimate
- Multi-market / mainnet extension — still no live mainnet Panoptic deployment exists
- Amending the approved econometric spec text — unnecessary if the position-epoch panel is genuinely restored
- Estimating on raw fee growth (the bare Lean object without the Panoptic multiplier) as an additional specification
</user_constraints>

---

## Summary

Two findings dominate this phase's plan, and both are planning-critical.

**Finding A — the premise of the locked decision does not hold: the cached data cannot support a fee replay.** The "632,315 cached Base V4 Swap logs" are not cached logs. `notes/structural-econometrcics/data/swap-ticks-base-v4-full.csv` is a two-column file, `timestamp_unix,tick`, written by `Panel.Variance.cacheSwapTicks`. It carries **no block number, no `amount0`/`amount1`, no `liquidity`, no `fee`, no `sqrtPriceX96`, and no log index**. `Panel.Variance` decodes only data word 4 (tick) and discards the rest of every log at fetch time. A fee-growth replay needs at minimum the per-swap fee amount and the in-range liquidity; neither survived the Phase-9 pull. **Any replay route therefore starts with a full ~3h re-pull of the same 5.1M-block window, this time retaining all six data words plus `blockNumber` and `logIndex` — plus a second, comparably sized pull of every `ModifyLiquidity` event for the pool since initialization** (needed for per-tick `liquidityNet` and the tick bitmap). This must be stated to the user before planning locks.

**Finding B — the exact object the phase wants is directly readable from chain state, and I verified it live.** Uniswap V4's `PoolManager` exposes all pool state through `extsload`, and Panoptic's deployed `SemiFungiblePositionManagerV4.getAccountPremium(...)` is a `view` function that returns **exactly the per-liquidity Panoptic premium accumulator (X64), utilization multiplier included**, for any chunk, with an `atTick` argument that extrapolates it to the current block via a live `feeGrowthInside` read. The public, keyless endpoint already used by Phase 9 (`https://mainnet.base.org`) **serves archive state** across the entire estimation window. I confirmed this with live `eth_call`s at blocks 44,500,000 / 47,000,000 / 47,840,000 / latest against SFPM `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` on a real chunk of the target market: the accumulator is nonzero, monotone in block height, and the long (owed) accumulator exceeds the short (gross) accumulator exactly as the ν·R/N spread predicts. Cost: **one `eth_call` per position-leg per epoch boundary — on the order of 8k–15k calls, roughly 30–60 minutes**, versus a multi-day replay engine that reimplements `SwapMath`/`SqrtPriceMath`/`TickMath`/`FullMath` in exact 256-bit integer arithmetic and must match Solidity's rounding directions bit-for-bit.

**Primary recommendation:** Build the panel from **archive `eth_call` reads of `SFPM.getAccountPremium` at epoch-boundary blocks** as the primary path, and demote the full V4 replay to an **optional cross-check on a small block window**. This delivers the letter of the locked decision's *intent* — the exact `feeGrowthInside` identity, no in-range-fraction approximation, no LHS measurement error — by evaluating the identity in the contract that defines it, rather than re-deriving it. It is a deviation from the *wording* ("from the cached swap stream"), which is no longer possible anyway (Finding A), so the planner must surface it to the user for arbitration before Wave 1. A knock-on benefit: the validation gate becomes near-tautological, so the honest target is **median relative error ≤ 1%**, not ≤ 10%, and a 10% miss should be treated as a red flag rather than a pass.

---

<phase_requirements>
## Phase Requirements

No formal requirement IDs exist for this phase (`.planning/REQUIREMENTS.md` carries none for Phase 10; CTX-* tags are minted at planning per the Phase-8/9 convention). The context document's four locked decisions are the de facto requirements. Suggested CTX tags and their research support:

| Proposed ID | Requirement | Research Support |
|----|-------------|-----------------|
| CTX-FEE | Reconstruct exact per-chunk fee growth with no approximation | §Uniswap V4 Fee-Growth Accounting (exact identity from `Pool.sol`); §Route B (archive `extsload` reads, verified live) |
| CTX-PREM | π_it = Panoptic premium incl. utilization multiplier, sourced from contracts | §Panoptic Premium Formula (exact code from `SemiFungiblePositionManagerV4._getPremiaDeltas`, VEGOID=8 ⇒ ν=1/8) |
| CTX-GATE | Hard reconciliation gate vs `OptionBurn.premium` before estimation | §Validation Gate Feasibility (the additive-decomposition argument; the four wedges) |
| CTX-PANEL2 | Restore the position-epoch panel and re-run the unchanged estimator | §Data Inventory (Chunk entity gives tickLower/tickUpper/N/R/T); §Effort Decomposition |
| CTX-XWALK | Extend `lean-haskell-crosswalk.md` with the multiplier wedge | §The Lean Wedge |
</phase_requirements>

---

## Uniswap V4 Fee-Growth Accounting — Exact Mechanics

Source: `lib/v4-core/src/libraries/{Pool,Position,StateLibrary}.sol` (v4-core is a submodule of the parent repo; it is **not** initialized in this worktree — read it from a sibling checkout or `git show` it, do not `git submodule update` here). Confidence: **HIGH** — read directly from the deployed-version source.

### The four rules

**1. `feeGrowthGlobal` update — per swap *step*, not per swap** (`Pool.sol` L400-407):

```solidity
if (result.liquidity > 0) {
    step.feeGrowthGlobalX128 +=
        UnsafeMath.simpleMulDiv(step.feeAmount, FixedPoint128.Q128, result.liquidity);
}
```

Only the **input** token's global accumulator moves: `zeroForOne` ⇒ `feeGrowthGlobal0X128`, else `feeGrowthGlobal1X128` (L445-449). `step.feeAmount` is **net of protocol fee** (L385-398): the protocol cut is subtracted from `feeAmount` *before* it enters fee growth. `result.liquidity` is the in-range liquidity **for that step**, which changes at each initialized-tick crossing.

**2. `feeGrowthOutside` flip on crossing** (`Pool.crossTick`, L602-612):

```solidity
info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
```

Note the asymmetry at L416-418: the input token uses the *in-flight* `step.feeGrowthGlobalX128`; the other token uses the *storage* value. Getting this backwards is a classic replay bug.

**3. The `feeGrowthInside` identity** (`Pool.getFeeGrowthInside`, L488-511; mirrored in `StateLibrary.getFeeGrowthInside` L298-322):

```
tickCurrent <  tickLower  →  inside = lower.outside − upper.outside
tickCurrent >= tickUpper  →  inside = upper.outside − lower.outside
otherwise                 →  inside = global − lower.outside − upper.outside
```

All arithmetic is `unchecked` — **deliberate uint256 wraparound**. Only differences are meaningful; absolute levels are not.

**4. Position-level fees owed** (`Position.update`, L88-99):

```
feesOwed = mulDiv(feeGrowthInside − feeGrowthInsideLast, liquidity, Q128)
```

### The `tick` off-by-one trap

`Pool.sol` L409-432: for `zeroForOne`, after crossing, `result.tick = step.tickNext − 1`. The comment is explicit — `slot0.tick` can be **one less** than `getTickAtSqrtPrice(slot0.sqrtPrice)`. Phase 9's tick series inherits this. It does not affect the variance regressor materially but it *does* affect any `tickCurrent < tickLower` branch decision at a boundary. Use `slot0.tick` (the stored value, and the value the `Swap` event reports), never a re-derivation from `sqrtPriceX96`.

---

## Can the Cached Swap Logs Support the Replay?

**No. Confidence: HIGH — verified by direct file and source inspection.**

### What the cache actually contains

`notes/structural-econometrcics/data/swap-ticks-base-v4-full.csv`, 632,318 lines, 12 MB:

```
# Base V4 Swap ticks cache (poolId 0x96d4…288c0a)
# columns: timestamp_unix,tick  (decoded from V4 Swap log data word 4)
timestamp_unix,tick
```

`Panel.Variance.fetchSwapTicks` builds `[(UTCTime, Int)]` and calls `decodeTick` only; `amount0`, `amount1`, `sqrtPriceX96`, `liquidity`, `fee`, `blockNumber`, and `logIndex` are all discarded before the write. **Nothing in the cache can produce a fee amount.**

### Even with a full re-pull, event data alone is insufficient for exact replay

The V4 `Swap` event (`IPoolManager.sol` L91-100) reports, per the NatSpec:

| Field | Semantics |
|-------|-----------|
| `amount0`, `amount1` | pool balance deltas (net over all steps) |
| `sqrtPriceX96` | price **after** the swap |
| `liquidity` | in-range liquidity **after** the swap |
| `tick` | tick **after** the swap |
| `fee` | `swapFee` in pips (LP fee + protocol fee) — a *rate*, not an amount |

So the event gives **final** state only. For a swap that crosses initialized ticks, the fee is split across steps with *different* `liquidity` values. `feeGrowthGlobal` is path-dependent in a way the event does not report. Concretely:

- **`fee` is a rate, not an amount.** `feeAmount = amountIn × fee / (1e6 − fee)` per step (SwapMath's exact-in form), not `amountIn × fee / 1e6`. The naive form is a systematic underestimate.
- **`liquidity` is post-swap.** Using it as the divisor for the whole swap is wrong whenever any tick was crossed.
- **Multi-tick swaps break naive replay outright.** Confirmed by `Pool.sol`'s `while` loop (L344-437).

**What exact replay would actually require:**

1. Re-pull all Swap logs retaining all six data words + `blockNumber` + `logIndex` (~3h, ~5.1M blocks, ~510 chunked `eth_getLogs` calls).
2. Pull **every** `ModifyLiquidity` event for the poolId since the `Initialize` event — all LPs, not just Panoptic — to reconstruct `ticks[].liquidityNet` and the tick bitmap. Volume unknown; plan a discovery task. Topic0 = `keccak("ModifyLiquidity(bytes32,address,int24,int24,int256,bytes32)")`, `topics[1]` = poolId.
3. Pull `Donate` events (donations also move `feeGrowthGlobal`, via `Pool.donate`) and `ProtocolFeeUpdated` events (protocol fee changes the LP share).
4. Reimplement `SwapMath.computeSwapStep`, `SqrtPriceMath`, `TickMath`, `FullMath.mulDiv`, `TickBitmap.nextInitializedTickWithinOneWord` in Haskell over `Integer`, **matching Solidity's rounding directions exactly**. Arbitrary-precision `Integer` makes this tractable, but every rounding direction is load-bearing: one `div` where Solidity rounds up produces a slowly accumulating drift over 632k swaps.
5. Drive the state machine. Note the price endpoints *do* pin the path (start price = previous swap's final price; liquidity mods do not move price), so `amountSpecified` need not be recovered — the sum of per-step `(amountIn + feeAmount)` can be cross-checked against the event's `amount0`/`amount1`, which is a strong self-test.

**Verdict:** technically possible, but it is a multi-week bit-exactness project whose only output is a number the chain will hand you for free. Which brings us to:

---

## Standard Stack

### Route B (RECOMMENDED): archive `eth_call` / `extsload` reads

Verified live against the free public endpoint on 2026-07-20.

| Component | Address / Value | Purpose | Provenance |
|-----------|------|---------|------------|
| Base V4 `PoolManager` | `0x498581ff718922c3f8e6a244956af099b2652b2b` | `extsload` source of truth for `feeGrowthGlobal`, `ticks[].feeGrowthOutside`, `slot0` | `Panel.Variance.basePoolManager` (already in-repo) |
| poolId | `0x96d4b53a…288c0a` | market key | DATA-SOURCES §4.1; **verified** = `keccak256(poolKey)` |
| poolKey (abi-encoded, 160 bytes) | `currency0=0x0` (ETH), `currency1=0x833589fc…2913` (USDC), `fee=500`, `tickSpacing=10`, `hooks=0x0` | argument to SFPM view fns | read live from `PanopticPool.poolKey()` |
| `PanopticPool` | `0xb50e8bb68f5855da742f4579274902a20454174a` | the `owner` in every chunk positionKey | DATA-SOURCES §4.1 |
| **SFPM V4** | `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` | `getAccountPremium`, `getAccountLiquidity` | **discovered live** via `PanopticPool.SFPM()` |
| `RiskEngine` | `0x8bbCE8B1eB64118CFE6c1eAb0afe13b80EA41481` | `vegoid()` | live probe |
| **VEGOID** | **8** ⇒ **ν = 1/8 = 0.125** | the spread parameter | `RiskEngine.sol` L104 `uint8 public constant VEGOID = 8;` |
| RPC | `https://mainnet.base.org` | **archive-capable, keyless** | **verified**: `extsload` and `eth_call` succeed at block 44,000,000 |

**Archive availability — probe results (2026-07-20):**

| Endpoint | `latest` | block 44,000,000 |
|----------|----------|------------------|
| `https://mainnet.base.org` | OK | **OK** |
| `https://base.drpc.org` | OK | **OK** |
| `https://base-rpc.publicnode.com` | OK | 403 — "Archive requests require a personal token" |
| `https://base.llamarpc.com` | HTML error page | — |

Keep `mainnet.base.org` (already wired in `Panel.Variance.defaultBaseRpc`), with `base.drpc.org` as failover. **No paid RPC key is needed. No `.env` secret is introduced.**

### Haskell libraries

| Library | Version | Purpose | Why standard |
|---------|---------|---------|--------------|
| `http-conduit` | in use | JSON-RPC transport | already the Phase-9 ingestion path; reuse `getLogsChunk`'s retry/backoff verbatim |
| `aeson` | in use | RPC envelope | same |
| `cassava` | in use | CSV I/O | same |
| `crypton` (or `cryptonite`) | — | **Keccak-256** for storage-slot and positionKey derivation | needed only if Route B-raw (`extsload`) is used; **not needed** if only `getAccountPremium` is called (the contract hashes internally). Prefer `crypton` (`cryptonite` is deprecated/unmaintained). **Ethereum uses legacy Keccak-256, NOT SHA3-256** — use `Crypto.Hash.Keccak_256`. |
| `hmatrix`, `hmatrix-gsl`, `ad`, `statistics` | in use | estimator — **unchanged** | Phase 9 stack, untouched |

**No new system dependencies.** Prefer `getAccountPremium` over raw `extsload` precisely to avoid adding a hash dependency and hand-rolling slot arithmetic.

### Alternatives considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| `getAccountPremium` eth_call | raw `extsload` + Haskell-side `_getPremiaDeltas` reimplementation | More code, needs Keccak + exact `mulDiv` semantics, no benefit. Use only as the Wave-3 cross-check. |
| Archive reads | Full V4 replay | See above — weeks of bit-exactness work, requires two large new data pulls, strictly worse accuracy. |
| Public RPC | Paid archive (Alchemy/QuickNode) | Only if `mainnet.base.org` rate-limits at ~10k calls. Would introduce an `.env` secret; avoid unless forced. |

---

## Panoptic Premium Formula — From the Deployed Contracts

Source: `lib/panoptic-v2-core/contracts/SemiFungiblePositionManagerV4.sol` (commit `d20b0ae`). Confidence: **HIGH**.

### The multiplier (SFPM V4 L203-307, the accumulator derivation block)

Let, for a chunk: `T` = total liquidity, `R` = removed (long) liquidity, `N = T − R` = net liquidity, `ν = 1/VEGOID`.

```
spread            = ν · R / N
owed  (long, buy) : ∆feeGrowth · r · (1 + ν·R/N)                    (Eqn 1)
gross (short,sell): ∆feeGrowth · t · (1 + ν·R²/(N·T))               (Eqn 2)
```

Accumulator increments, per touch (Eqns 3 & 4):

```
s_accountPremiumOwed  += feesCollected · T/N² · (1 − R/T + ν·R/T)
s_accountPremiumGross += feesCollected · T/N² · (1 − R/T + ν·R²/T²)
```

### The exact code (`_getPremiaDeltas`, L1129-1214)

```solidity
uint256 totalLiquidity = netLiquidity + removedLiquidity;
premium0X64_base = Math.mulDiv(collected0, totalLiquidity * 2**64, netLiquidity ** 2);
// owed:
uint256 numerator = netLiquidity + (removedLiquidity / vegoid);
premium0X64_owed  = mulDiv(premium0X64_base, numerator, totalLiquidity);
// gross:
numerator = totalLiquidity**2 - totalLiquidity*removedLiquidity + (removedLiquidity**2 / vegoid);
premium0X64_gross = mulDiv(premium0X64_base, numerator, totalLiquidity ** 2);
```

`vegoid = 8` on this market ⇒ ν = 0.125. Accumulators are **per unit liquidity, X64** (`2**64` scale, not X128), capped at `2^128 − 1` via `toUint128Capped`, and **frozen in pairs on overflow** (L1114-1120, `LeftRightLibrary.addCapped`). LeftRight packing: **right slot = currency0, left slot = currency1**.

Reference graph cited in-source: `https://www.desmos.com/calculator/mdeqob2m04`.

### Chunk identity and the `atTick` extrapolation

`positionKey = keccak256(poolId ‖ account ‖ tokenType ‖ tickLower ‖ tickUpper)` (L949-957) with **`account` = the `PanopticPool` address**, confirmed by `_getPremia` passing `address(this)` (`PanopticPool.sol` L2263) and by the subgraph `Chunk.id` format `panopticPool#SFPM#poolId#tokenType#tickLower#tickUpper`. The chunk is therefore **pool-wide, not per-user** — per-user attribution lives in `s_options[owner][tokenId][leg]`.

Accumulators are written **only when the chunk is touched** (`_updateStoredPremia`, called from `_createLegInAMM` L1092, and only `if (currentLiquidity.rightSlot() > 0)`). A per-day panel from stored accumulators alone would therefore be a step function. **The `atTick` parameter of `getAccountPremium` solves this** (L1279-1326): if `atTick < type(int24).max` and `netLiquidity != 0`, the function does a *live* `V4StateReader.getFeeGrowthInside` minus the SFPM V4 position's `feeGrowthInsideLast`, converts to `amountToCollect`, runs `_getPremiaDeltas`, and returns the accumulator **as of that block**. This is exactly the smooth per-epoch series the panel needs.

Note the SFPM's underlying V4 position uses `salt = positionKey` and `owner = SFPM` (L1067-1074, L1296-1298) — relevant only if you go the raw-`extsload` route.

### Per-position premium

`PanopticPool._getPremia` (L2272-2298):

```
premiaByLeg[leg] = (acc(now) − s_options[owner][tokenId][leg]) × liquidityChunk.liquidity() / 2**64
if isLong: negate
```

with `acc` = gross accumulator for short legs, owed accumulator for long legs. `OptionBurn.premiaByLeg` is emitted from exactly this quantity (`PanopticPool.sol` L1046). **This is why the panel decomposes additively over epochs and why the gate should be near-exact.**

### The Lean wedge (must be recorded in `lean-haskell-crosswalk.md`)

| Object | Definition |
|--------|-----------|
| Lean `Panoptic.streamingPremium` / `STREAMING_PREMIUM.md` | LP fee revenue per unit liquidity: `∆feeGrowthInside × L` |
| Phase 10 estimated π_it | the above **× the Panoptic multiplier** `(1 + ν·R/N)` for long legs, `(1 + ν·R²/(N·T))` for short legs, ν = 1/8 |

The wedge is **exactly 1 when R = 0** (no long interest in the chunk). It is bounded by `(1 + ν) = 1.125` for `R → N` on the long side. The cross-walk table should carry this bound and, ideally, the realised per-observation multiplier distribution from the panel — that turns a hand-wave into a measured wedge.

---

## Data Inventory — What Supplies Each Input

Confidence: **HIGH** (subgraph introspected live; chain probed live).

| Input | Source | Status |
|-------|--------|--------|
| chunk `tickLower`, `tickUpper` | Panoptic subgraph **`Chunk`** entity — has `tickLower`, `tickUpper`, `strike`, `width`, `tokenType`, `netLiquidity`, `shortLiquidity`, `longLiquidity`, `totalLiquidity` | **Available.** Phase 9 never queried this entity. |
| leg → chunk mapping | `Leg` entity has `strike`, `width`, `tokenType`, `isLong`, `asset`, `optionRatio`, **and a `chunk` relation** | Available. `Leg.width` is present; DATA-SOURCES §5 did not record it. |
| tick range from (strike,width) | `PanopticMath.getTicks`: `rangeDown = (width·tickSpacing)/2`, `rangeUp = ceil(width·tickSpacing/2)`, `[strike − rangeDown, strike + rangeUp]` | Formula in hand; cross-check against `Chunk.tickLower/Upper` rather than trusting the arithmetic. |
| leg liquidity | `PanopticMath.getLiquidityChunk`: `amount = positionSize × optionRatio`, then `Math.getLiquidityForAmount0/1(tickLower, tickUpper, amount)` selected by `asset` | Needs `positionSize` from `OptionMint`'s `PositionBalance` (subgraph `optionMints`) — **discovery task**. |
| premium accumulator per chunk per epoch | `SFPM.getAccountPremium(poolKey, PanopticPool, tokenType, tickLower, tickUpper, atTick, isLong, 8)` at the epoch-boundary block | **Verified working at archive blocks.** |
| `atTick` per epoch boundary | the pool tick at that block — from the existing swap-tick cache, or `StateLibrary.getSlot0` via one `extsload` | Available. |
| epoch boundary → block number | binary search over `eth_getBlockByNumber` (~119 boundaries × ~25 probes ≈ 3k cheap calls), cached to CSV | Needed because **the tick cache has no block numbers**. |
| ground truth | `OptionBurn.premium0/1`, `premiaByLeg`, `tickAt` (61 spells) | In hand from Phase 9. |
| `ν` | `RiskEngine.VEGOID = 8` | Confirmed from source **and** the live `riskEngine()` address. |

### `width = 0` legs — a real trap

The first legs returned by the subgraph all have `width: 0`. `PanopticPool._getPremia` (L2250) **skips any leg with `width == 0`** — such legs accrue no premium at all. A `width_gt: 0` filter is mandatory when assembling the panel, and the planner should have a Wave-0 task counting how many of the 61 spells' legs survive it. If a large share of premium-bearing tokenIds are width-0, the sample gain will be smaller than the ×100 the context anticipates.

**Live probe evidence** (chunk `tokenType=0`, `[-199680, -197280]`, stored accumulators, currency0 slot):

| Block | short (gross) acc | long (owed) acc |
|-------|-------------------|-----------------|
| 44,500,000 | `0x3363c8e16f43182fb` ≈ 5.9e19 | — |
| 47,000,000 | `0x3cac79361af8320491` ≈ 1.12e21 | `0x40929eb1367967c87b` ≈ 1.19e21 |
| latest | same as 47,000,000 (chunk untouched since) | same |
| latest, `atTick = −200000` | `0x42c22ac671fe20c945` ≈ 1.23e21 | — |

Monotone in block height; owed > gross as ν·R/N > ν·R²/(N·T) requires; the `atTick` path returns strictly more than the stored value. All three properties are exactly what the source predicts. **This is the strongest single piece of evidence in this document.**

---

## Architecture Patterns

### Recommended module layout

```
econometrics/src/
├── Chain/
│   ├── Rpc.hs          -- generic JSON-RPC: eth_call, eth_getBlockByNumber, eth_blockNumber
│   │                      (LIFT the retry/backoff/clamp logic out of Panel.Variance —
│   │                       do not fork it; Panel.Variance should end up importing this)
│   ├── Abi.hs          -- minimal encode/decode: int24/uint128/uint256/bytes/address,
│   │                      two's-complement sign handling (generalise Variance.wordAt)
│   └── BlockIndex.hs   -- epoch ↔ block-number map via binary search, CSV-cached
├── Panoptic/
│   ├── Sfpm.hs         -- getAccountPremium / getAccountLiquidity call wrappers
│   ├── Chunk.hs        -- Leg/Chunk subgraph queries; getTicks; getLiquidityForAmount0/1
│   └── Premium.hs      -- accumulator diffs → π per (position, epoch); sign by isLong
├── Panel/
│   ├── Build.hs        -- UNCHANGED dailyEpoch; extended with the position-epoch assembler
│   ├── Variance.hs     -- UNCHANGED
│   └── Reconcile.hs    -- THE GATE: Σ_epochs π vs OptionBurn.premium, full error distribution
└── Model/, Tests/, Alternatives.hs   -- UNCHANGED
```

### Pattern: checkpointed, resumable chain reads

Phase 9 learned this the hard way (`Panel.Variance` streams each chunk to disk as it arrives). **Reuse the pattern:** every `eth_call` result appends to a CSV keyed by `(chunkKey, epoch, isLong, block)`, and the driver skips keys already present. A 10k-call run that only writes at the end is a run you will do twice.

### Pattern: fail loudly on RPC nulls

An archive endpoint that silently degrades to "state not available" and returns `0x` must **fail**, not decode to zero. A zero accumulator is indistinguishable from a real zero, and a silent zero would sail through the gate as an apparent "position earned nothing" observation. Make `Chain.Rpc` return `Either` and treat empty returndata as an error.

### Anti-patterns to avoid

- **Re-deriving the tick from `sqrtPriceX96`.** Off by one after `zeroForOne` crossings (`Pool.sol` L431).
- **`Double` anywhere upstream of the panel.** X128 fee growth reaches ~10^38; X64 accumulators reach ~10^21. `Double` has 53 bits of mantissa. Keep everything `Integer` until the final USD conversion.
- **Checked subtraction on accumulator diffs.** V4 and Panoptic both rely on `unchecked` uint256/uint128 wraparound. In Haskell, take the difference **modulo 2^256** (or 2^128 for the X64 accumulators) before converting — a naive `a - b` on `Integer` will produce a huge negative number instead of the intended small positive one whenever wraparound has occurred.
- **Forking `Panel.Variance`'s RPC code.** Two divergent retry implementations is how the 09-05 offset trap happened. Lift, don't copy.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| `feeGrowthInside` for a range | a tick-crossing state machine over 632k swaps | `StateLibrary.getFeeGrowthInside` via `extsload`, or let `getAccountPremium` do it | The chain computes the identity that *defines* correctness. Any reimplementation can only introduce error. |
| Panoptic premium multiplier | a Haskell port of `_getPremiaDeltas` | `SFPM.getAccountPremium` `eth_call` | Needs exact `mulDiv`, `toUint128Capped`, and paired-overflow-freeze semantics to match. Port it only as a cross-check. |
| `SwapMath` / `SqrtPriceMath` / `TickMath` | a Haskell 256-bit fixed-point port | avoid entirely (Route B) | Every rounding direction is load-bearing over 632k swaps. |
| Keccak-256 | anything | `crypton`'s `Keccak_256` | And note: **Ethereum's Keccak-256 is NOT SHA3-256** (different padding). Only needed for raw `extsload`. |
| Chunk tick ranges | `strike ± width·tickSpacing/2` arithmetic alone | the subgraph `Chunk` entity, with the formula as a **cross-check** | `getRangesFromStrike` uses `floor` down and `ceil` up — asymmetric for odd `width·tickSpacing`. |
| Block ↔ timestamp | assuming 2s Base blocks | binary search over `eth_getBlockByNumber`, cached | Base block time is nominally 2s but not guaranteed; a drift of even 30 blocks straddles an epoch boundary. |

**Key insight:** in this domain, "correct" is *defined* by deployed bytecode. Any reimplementation is at best equal and at worst silently wrong — and silently wrong LHS measurement is precisely the failure mode Phase 9 died of.

---

## Common Pitfalls

### Pitfall 1: The cache cannot do what the phase assumes
**What goes wrong:** planning proceeds assuming 632k logs are on disk, and Wave 1 discovers a two-column tick file.
**Why:** `Panel.Variance` decoded only word 4 and discarded the rest at fetch time.
**Avoid:** Wave 0 task — `head` the cache and assert its schema. Any plan whose first task is "load cached swap amounts" is already wrong.
**Warning sign:** a task description containing "from the cached swap logs, compute the fee."

### Pitfall 2: X128 / X64 / decimals — the unit stack (invoke the `dimensional-analysis` skill)
Four distinct fixed-point scales are in play:

| Quantity | Scale | Unit |
|----------|-------|------|
| `feeGrowthGlobal/Outside/Inside` | **X128** (`2^128`) | token-wei per unit liquidity |
| `s_accountPremium{Owed,Gross}` | **X64** (`2^64`) | token-wei per unit liquidity |
| `sqrtPriceX96` | **X96** (`2^96`) | √(token1/token0) |
| token amounts | — | ETH 18 dec, **USDC 6 dec** |

`premium = Δacc_X64 × liquidity / 2^64` → **wei**. Then `/1e18` for ETH, `/1e6` for USDC. Phase 9 already found that USDC's 6 decimals truncate small premia to zero (38 nonzero `premium1` vs 61 nonzero `premium0`) — **use `premium0` (ETH) as the reconciliation target**, as Phase 9 did.
**Warning sign:** a reconstructed premium off by exactly `2^64`, `2^128`, `1e12`, or `1.0001^tick`.

### Pitfall 3: Unchecked wraparound treated as signed
**What goes wrong:** an accumulator diff comes out as ~1.15e77 instead of ~1e19.
**Why:** Solidity's `unchecked` subtraction wraps mod 2^256 / 2^128; `Integer` does not.
**Avoid:** `diffMod n a b = (a - b) `mod` (2^n)` with `n = 128` for the X64 accumulators, `n = 256` for fee growth. Golden-test it explicitly.

### Pitfall 4: The epoch-offset trap (09-05, already caught once)
`Panel.Build.dailyEpoch = floor(unixSeconds / 86400)` is the **single source of truth**. Any new module must import it, never redefine it. The block index maps `epoch → firstBlockAtOrAfter(epoch × 86400)`.

### Pitfall 5: `atTick` falls back silently when `netLiquidity == 0`
`getAccountPremium` L1279: if `netLiquidity == 0` at that block it returns the **stored** accumulator, not the extrapolated one. For epochs where a chunk is empty this is correct (nothing accrued), but it means a flat stretch in the series is ambiguous between "no fees" and "chunk empty." Record `getAccountLiquidity` alongside every premium read so the two cases are distinguishable in the output.

### Pitfall 6: Accumulator freeze on overflow
`LeftRightLibrary.addCapped` freezes owed and gross **together** for a currency once either hits `2^128 − 1`. A frozen chunk yields Δ = 0 forever — indistinguishable from "no fees" unless you check the level. Add an assertion: flag any read within, say, 1% of `2^128 − 1`.

### Pitfall 7: Multi-leg and partial burns in the gate
`OptionBurn.premiaByLeg` is a `LeftRightSigned[4]`. The scalar `premium0` is the **sum over legs**. Reconciliation must sum over legs on the reconstructed side too, and match leg count. Positions with `width == 0` legs contribute nothing.

---

## Code Examples

### The premium read (verified live — this exact call succeeded)

```
Contract: SFPM 0x8dcAa08cF298F8b4830FAf56d47930981AdE33af  (Base, chainId 8453)
Method:   getAccountPremium(bytes poolKey, address owner, uint256 tokenType,
                            int24 tickLower, int24 tickUpper, int24 atTick,
                            uint256 isLong, uint256 vegoid)
          returns (uint128 premium0X64, uint128 premium1X64)

owner    = 0xb50e8bb68f5855da742f4579274902a20454174a   (the PanopticPool)
vegoid   = 8
atTick   = pool tick at the target block   (or 8388607 = type(int24).max for the stored value)
isLong   = 0 → gross (short/seller) accumulator ; 1 → owed (long/buyer) accumulator
poolKey  = abi.encode(PoolKey{ currency0: 0x0, currency1: 0x833589fc…2913,
                               fee: 500, tickSpacing: 10, hooks: 0x0 })
           -- 160 bytes; keccak256 of it == poolId 0x96d4…288c0a  (VERIFIED)

Transport: POST eth_call {"to": SFPM, "data": <calldata>}, <blockNumberHex>
           to https://mainnet.base.org   -- keyless, archive-capable (VERIFIED at block 44,000,000)
```

### Per-position, per-epoch premium

```haskell
-- π for (position i, epoch t), in token-wei of currency0.
-- accHi/accLo are the X64 accumulators read at the epoch's end/start blocks;
-- legLiquidity is PanopticMath.getLiquidityChunk for that leg.
-- Sign convention (PanopticPool.sol L2296-2298): negate for long legs.
premiumWei :: Integer -> Integer -> Integer -> Integer -> Integer
premiumWei accHi accLo legLiquidity isLong =
  let d = (accHi - accLo) `mod` (2 ^ (128 :: Int))   -- unchecked uint128 wraparound
      p = (d * legLiquidity) `div` (2 ^ (64 :: Int))
  in if isLong == 1 then negate p else p
```

### The exact identity, for reference (`Pool.sol` L488-511)

```
tickCurrent <  tickLower  →  inside = lower.outside − upper.outside
tickCurrent >= tickUpper  →  inside = upper.outside − lower.outside
otherwise                 →  inside = global − lower.outside − upper.outside
                             (all mod 2^256)
```

---

## Validation Gate Feasibility

**Verdict: achievable, and the honest target is far tighter than 10%. Confidence: MEDIUM-HIGH** (the argument is structural; the number is unmeasured).

### Why it should be near-exact

`OptionBurn.premiaByLeg` is, by construction (`PanopticPool._getPremia` L2272-2298),

```
premium = (acc(t_burn) − s_options[owner][tokenId][leg]) × legLiquidity / 2^64
```

and `s_options` is written at mint. The panel's per-epoch π sums **telescopically** over the same accumulator:

```
Σ_{t ∈ spell} [acc(t_end) − acc(t_start)] × legLiquidity / 2^64
  = [acc(t_burn) − acc(t_mint)] × legLiquidity / 2^64
```

The panel is a *decomposition* of the ground truth, not an independent estimate of it. Residual error comes only from the wedges below. **Recommend the plan pre-commit to median relative error ≤ 1% on `premium0` (ETH leg), with the locked ≤10% retained as the hard gate.** A result landing between 1% and 10% should trigger diagnosis, not celebration — it would mean a wedge is unaccounted for.

### Systematic wedges the planner must expect

| Wedge | Mechanism | Expected size | Mitigation |
|-------|-----------|---------------|------------|
| **Long-premium capping** | `_getAvailablePremium` (`PanopticPool` L588-599) caps settled long premium at what the pool can actually pay. `OptionBurn.premium` reports the **settled** amount; the accumulator reports the **accrued** amount. | Can be large on the 8 long tokenIds; zero on the 53 short ones. | **Stratify the gate by `is_long`.** Report short-leg and long-leg error distributions separately. Do not let 8 capped longs fail a gate the 53 shorts pass — but do not hide them either. |
| **Mid-life `s_options` rewrites** | any operation touching a tokenId (partial burn, force-exercise, settle) resets the per-user snapshot mid-spell. | Unknown; `premiumSettleds` is empty on this market (DATA-SOURCES §5.1), which suggests near-zero. | Wave-0 discovery: count non-mint/non-burn touches per tokenId. |
| **Rounding** | integer `div` at each of `mulDiv`, `/2^64`, `/vegoid` | < 1 wei per leg per touch | Negligible relative to 1e-2 ETH premia. |
| **Multi-leg summation** | scalar `premium0` = Σ over ≤4 legs | zero if summed correctly | Match leg counts explicitly; assert. |
| **USD conversion** | Phase 9 converted `premium0` (ETH) → USD at `tickAt` | zero if the gate is run in **ETH wei**, before conversion | **Run the gate in wei, not USD.** Conversion belongs downstream of the gate. |
| **Epoch-boundary block choice** | `acc(t)` read at block *b* vs the burn at block *b'* within the same epoch | small but nonzero at the spell endpoints | Read the spell's endpoint accumulators at the **exact mint/burn block**, not the epoch boundary, for the gate. Use epoch boundaries only for the interior decomposition. |

### Recommended gate procedure

1. **Pre-check (fast):** 5 short single-leg spells, full pipeline, error in wei. If this is not < 1%, stop and debug — do not run 61.
2. **Full gate:** all 61 spells, stratified short/long. Report median, IQR, p90, max, and the signed-error distribution (sign bias is the diagnostic that separates a multiplier bug from a rounding issue).
3. **Publish the distribution regardless of pass/fail**, as CONTEXT requires.

---

## Effort / Feasibility Verdict

**The phase is achievable as scoped in intent, but NOT as scoped in mechanism.** The locked "full V4 replay from the cached swap stream" is impossible — the cached swap stream does not contain fees, liquidity, or block numbers (Finding A). This is a planning-critical finding that must reach the user before Wave 1, not a failure.

### Recommended decomposition

| Wave | Work | Est. |
|------|------|------|
| **0 — Discovery & escalation** | Assert cache schema (proves Finding A). Query `Chunk`/`Leg` with `width_gt: 0`; count surviving legs across the 61 spells. Get `positionSize` from `optionMints`. Confirm archive reads from Haskell. **Escalate the Route A → Route B decision to the user.** | 0.5 day |
| **1 — Chain layer** | `Chain.Rpc` (lift from `Panel.Variance`, don't fork), `Chain.Abi`, `Chain.BlockIndex`. Golden tests against the live values recorded in this document. | 1–1.5 days |
| **2 — Premium reconstruction** | `Panoptic.Chunk` + `Panoptic.Sfpm` + `Panoptic.Premium`. Batch-read accumulators; checkpointed CSV. ~8k–15k calls, 30–60 min wall clock. | 1.5–2 days |
| **3 — THE GATE** | `Panel.Reconcile`. Pre-check on 5 spells, then all 61, stratified. **Hard stop here.** | 1 day |
| **4 — Panel + re-estimation** | Position-epoch panel joined to `variance.csv` on `dailyEpoch`; re-run the **unchanged** estimator + the three tests + the four alternatives. | 1 day |
| **5 — Analysis + cross-walk** | Self-describing output with full lineage; extend `lean-haskell-crosswalk.md` with the ν = 1/8 multiplier wedge and its measured distribution. | 0.5 day |
| *(optional)* **6 — Replay cross-check** | Full V4 replay over a **narrow** block window (e.g. 5,000 blocks), compared against the archive read. Honours the locked decision's spirit at ~5% of its cost. | 2–3 days |

**Route B total: ~6 days.** Route A (full replay as literally worded) is **~3–4 weeks** and begins with two multi-hour data pulls, and would still need Route B's reads as its own correctness oracle.

### Honest risks

- **Sample gain may be smaller than the ×100 hoped.** The `width == 0` filter and the requirement that a chunk have `netLiquidity > 0` in an epoch will both prune. Wave 0 must size this **before** Wave 2 commits.
- **Public RPC rate limits at ~10k sequential calls are untested.** Mitigation: checkpointing (already the Phase-9 pattern) plus `base.drpc.org` failover. Reserve a paid key as a last resort.
- **A passing gate does not guarantee an informative υ₀.** Reconstructing the LHS correctly fixes measurement error; it does not create variation that is not in the market. The pre-committed stopping rule (CI half-width ≤ 6.2e-5, result-independent) governs, and "this market cannot identify υ" remains a legitimate terminal outcome.

---

## State of the Art

| Old approach | Current approach | Impact |
|--------------|------------------|--------|
| V3: fee state in per-pool contracts, `pool.feeGrowthGlobal0X128()` public getter | V4: singleton `PoolManager`, **all** state behind `extsload`; read via `StateLibrary` | Storage-slot arithmetic (`POOLS_SLOT = 6`, `TICKS_OFFSET = 4`, …) or a helper `view` fn is now mandatory. |
| V3: pool address is the log filter | V4: `PoolManager` address + `topics[1] = poolId` | Already handled correctly by `Panel.Variance`. |
| V3 `Position.State` keyed by (owner, tickLower, tickUpper) | V4 adds **`salt`**; Panoptic sets `salt = positionKey` | Needed only for raw-`extsload` position reads. |
| `cryptonite` | **`crypton`** | `cryptonite` is unmaintained; `crypton` is the maintained fork. |

**Deprecated / not applicable here:** BigQuery `crypto_ethereum` (project suspended, and this is Base V4 anyway — retained in `Panel.Variance.historicalBigQuerySql` for provenance only, correctly not wired).

---

## Open Questions

1. **Does the user accept Route B over the literal "full V4 replay"?**
   - Known: the cached stream cannot support a replay; the exact identity is free from the chain; Route B is strictly more accurate.
   - Unclear: whether the locked wording binds the *mechanism* or the *fidelity standard*.
   - **Recommendation:** the planner must put this to the user as a Wave-0 checkpoint. Frame it as "the locked decision's fidelity requirement is met more exactly by reading the identity than by re-deriving it, and the re-derivation input no longer exists." Offer optional Wave 6 as the compromise.

2. **How many of the 61 spells' legs survive `width > 0`?**
   - Known: `_getPremia` skips `width == 0` legs; the first subgraph legs sampled all had `width: 0`.
   - **Recommendation:** Wave-0 blocker. If the surviving count is small, the ×100 sample-gain premise fails and the phase's power calculation needs revisiting *before* Wave 2.

3. **Does `mainnet.base.org` sustain ~10k sequential archive `eth_call`s?**
   - Known: single calls succeed at block 44M; Phase 9 sustained ~510 `eth_getLogs` calls over ~3h.
   - **Recommendation:** Wave-1 task — 200-call burst, measure throughput and 429 rate. Checkpoint regardless.

4. **Are there mid-spell `s_options` rewrites on this market?**
   - Known: `premiumSettleds` is empty (DATA-SOURCES §5.1), suggesting none.
   - **Recommendation:** Wave-0 count of non-mint/non-burn tokenId touches; a nonzero count means the gate must handle sub-spells.

5. **`positionSize` availability.**
   - Known: `OptionMinted` carries `PositionBalance balanceData`; the subgraph indexes `optionMints`.
   - Unclear: whether `positionSize` is exposed as a decoded field or packed.
   - **Recommendation:** Wave-0 introspection of the `OptionMint` entity. Fallback: decode `PositionBalance` bit layout from `contracts/types/PositionBalance.sol`.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`.

### Test framework

| Property | Value |
|----------|-------|
| Framework | **hspec** (via `econometrics:test:unit`, `test/Spec.hs`) |
| Config file | `econometrics/package.yaml` → `tests.unit`; module list is **explicit** under `other-modules` — new spec modules must be added there or they silently do not run |
| Quick run | `stack test econometrics:test:unit --fast` (from `econometrics/`) |
| Full suite | `stack test` — currently **59/0**; must stay green |
| Golden precision | 1e-9 (the 09-08 sandwich-SE precedent) |
| Fixtures | `econometrics/test/fixtures/` (`swap-ticks-sample.csv`, `subgraph-sample.json`) |

### Phase requirements → test map

| Req | Behaviour | Type | Automated command | Exists? |
|-----|-----------|------|-------------------|---------|
| CTX-FEE | `feeGrowthInside` branch logic matches `Pool.sol` L488-511 on all three tick regimes | unit | `stack test econometrics:test:unit --ta '-m "feeGrowthInside"'` | ❌ Wave 0 |
| CTX-FEE | unchecked wraparound: `diffMod 256` and `diffMod 128` behave as Solidity | unit | `… --ta '-m "wraparound"'` | ❌ Wave 0 |
| CTX-FEE | ABI decode of int24/uint128/uint160 incl. sign extension | unit | `… --ta '-m "Chain.Abi"'` | ❌ Wave 0 |
| CTX-FEE | **golden:** frozen live accumulator triple (blocks 44,500,000 / 47,000,000 / latest-at-freeze) for chunk `tt0 [-199680,-197280]` reproduces from the recorded raw returndata | golden | `… --ta '-m "premium golden"'` | ❌ Wave 0 — **freeze the hex returndata as a fixture; do not hit the network in tests** |
| CTX-PREM | `premiumWei` sign convention: long negates, short does not | unit | `… --ta '-m "premium sign"'` | ❌ Wave 0 |
| CTX-PREM | `_getPremiaDeltas` Haskell cross-check (Wave 6) reproduces the on-chain accumulator on the frozen fixture | golden | `… --ta '-m "premia deltas"'` | ❌ optional |
| CTX-PANEL2 | `getTicks(strike, width, tickSpacing)` reproduces `Chunk.tickLower/tickUpper` for every chunk in a frozen subgraph fixture (incl. odd `width·tickSpacing` floor/ceil asymmetry) | unit | `… --ta '-m "getTicks"'` | ❌ Wave 0 |
| CTX-PANEL2 | epoch↔block index is monotone; boundary block timestamp ≥ `epoch × 86400`; **uses `Panel.Build.dailyEpoch`, not a redefinition** | unit | `… --ta '-m "BlockIndex"'` | ❌ Wave 0 |
| CTX-PANEL2 | panel joins to `variance.csv` with zero unmatched epochs | integration | `… --ta '-m "panel join"'` | ❌ Wave 0 |
| CTX-GATE | telescoping identity: Σ over epochs = endpoint difference, on synthetic accumulators | unit | `… --ta '-m "telescoping"'` | ❌ Wave 0 |
| CTX-GATE | the gate itself — median rel. error on 61 spells, stratified short/long | integration (network) | `stack exec econometrics -- reconcile` — **CLI, not the test suite** | ❌ Wave 3 |
| unchanged | Phase-9 estimator, SEs, tests, alternatives still pass | regression | `stack test` (existing 59) | ✅ exists |

### Sampling rate

- **Per task commit:** `stack test econometrics:test:unit --fast`
- **Per wave merge:** `stack test` (full 59 + new), plus `lake build vol_markets` if any Lean file is touched (none expected)
- **Phase gate:** full suite green **and** the reconciliation CLI passes **before** the estimator is run at all

### Wave 0 gaps

- [ ] `econometrics/test/Chain/AbiSpec.hs` — decode + wraparound (CTX-FEE)
- [ ] `econometrics/test/Chain/BlockIndexSpec.hs` — epoch↔block, `dailyEpoch` reuse (CTX-PANEL2)
- [ ] `econometrics/test/Panoptic/PremiumSpec.hs` — sign, X64 scaling, telescoping (CTX-PREM, CTX-GATE)
- [ ] `econometrics/test/Panoptic/ChunkSpec.hs` — `getTicks` vs frozen `Chunk` fixture (CTX-PANEL2)
- [ ] `econometrics/test/fixtures/premium-acc-golden.json` — **frozen raw `eth_call` returndata** from the probes recorded in this document (keeps the suite offline and deterministic)
- [ ] `econometrics/test/fixtures/chunks-sample.json` — frozen `Chunk`/`Leg` subgraph response
- [ ] Register every new module under `package.yaml` → `tests.unit.other-modules` (explicit list; omission = silent skip)
- [ ] No framework install needed — hspec already wired

---

## Sources

### Primary (HIGH confidence)
- `lib/v4-core/src/libraries/Pool.sol` — `swap` L279-463, `getFeeGrowthInside` L488-511, `crossTick` L602-612, `updateTick` L520+
- `lib/v4-core/src/libraries/Position.sol` — `update` L88-99, `calculatePositionKey` L47-68
- `lib/v4-core/src/libraries/StateLibrary.sol` — slot offsets L11-28, `getSlot0` L40-63, `getTickInfo` L74-97, `getFeeGrowthInside` L298-322
- `lib/v4-core/src/interfaces/IPoolManager.sol` — `Swap` L91-100, `ModifyLiquidity` L78-80, `Initialize` L60-69, `Donate` L107
- `lib/v4-core/src/PoolManager.sol` — emission sites L139, L175, L241, L273
- `lib/panoptic-v2-core/contracts/SemiFungiblePositionManagerV4.sol` (`d20b0ae`) — accumulator derivation L203-307, `_createLegInAMM` L937-1094, `_updateStoredPremia` L1100-1121, `_getPremiaDeltas` L1129-1214, `getAccountPremium` L1258-1346
- `lib/panoptic-v2-core/contracts/PanopticPool.sol` — `OptionBurnt` L74-79, `PremiumSettled` L62-67, `_getPremia` L2233-2305, `_updateSettlementPostBurn` L1320+, `s_options` L195
- `lib/panoptic-v2-core/contracts/RiskEngine.sol` — `VEGOID = 8` L104
- `lib/panoptic-v2-core/contracts/libraries/PanopticMath.sol` — `getLiquidityChunk` L358-398, `getTicks` L406-416, `getRangesFromStrike` L424-432
- `lib/panoptic-v2-core/contracts/types/TokenId.sol` — bit layout L117-182
- `econometrics/src/Panel/Variance.hs` — cache schema, decoder, RPC patterns
- `notes/structural-econometrcics/data/{swap-ticks-base-v4-full.csv,DATA-SOURCES.md}`

### Live on-chain probes, 2026-07-20 (HIGH — reproducible)
- `PanopticPool.SFPM()` → `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af`; `riskEngine()` → `0x8bbCE8B1eB64118CFE6c1eAb0afe13b80EA41481`; `poolKey()` → 160-byte blob whose keccak equals poolId `0x96d4…288c0a`
- `PoolManager.extsload(feeGrowthGlobal0 slot)` at `latest` and block **44,000,000** on `mainnet.base.org` → **archive confirmed**
- `SFPM.getAccountPremium(...)` at blocks 44,500,000 / 47,000,000 / 47,840,000 / latest on chunk `tt0 [-199680,-197280]` → monotone, owed > gross, `atTick` path strictly larger
- Endpoint archive matrix (`mainnet.base.org` ✅, `base.drpc.org` ✅, `publicnode` ❌ 403, `llamarpc` ❌)
- Goldsky subgraph introspection: `Chunk` and `Leg` field lists; `width_gt: 0` sample

### Secondary (MEDIUM)
- `https://www.desmos.com/calculator/mdeqob2m04` — Panoptic's own premium-spread graph, cited in-source at `SemiFungiblePositionManagerV4.sol` L1142 (not fetched; cited as the authors' reference)

### Not consulted
- arXiv:2204.14232 — the deployed contracts are strictly more authoritative for the parameterization, and they were available locally. Consult only if a *theoretical* justification of the spread form is needed for the write-up.

---

## Metadata

**Confidence breakdown:**
- V4 fee-growth mechanics: **HIGH** — read from the deployed-version source, line-referenced
- Cache-insufficiency finding: **HIGH** — direct file inspection, unambiguous
- Panoptic premium formula: **HIGH** — exact code + `VEGOID = 8` confirmed from source *and* the live `RiskEngine`
- Route-B feasibility: **HIGH** — live archive `eth_call` probes succeeded across the estimation window
- Reconciliation error magnitude: **MEDIUM** — the telescoping argument is structural, but the number is unmeasured and the long-premium capping wedge is unquantified
- Sample-size gain (×100): **LOW** — the `width == 0` filter is unquantified; Wave-0 blocker

**Research date:** 2026-07-20
**Valid until:** ~2026-08-19 (30 days). Contract source is stable; **RPC archive availability on a free public endpoint is the volatile assumption — re-probe before Wave 2.**
