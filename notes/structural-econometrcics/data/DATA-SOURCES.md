# DATA-SOURCES — Panoptic υ-identification panel (Phase 09, Plan 02)

**Purpose:** Self-describing record of the confirmed live data path for the
position-epoch panel (Panoptic subgraph) and the underlying-pool variance source
(BigQuery swap logs). Discovery gate for CTX-PANEL / CTX-VAR.

**Status:** RESOLVED — checkpoint (Task 3) closed by user decision on
2026-07-19 ("accept base"). Confirmed market = Base V4 ETH/USDC; variance route =
direct RPC `eth_getLogs` (BigQuery dropped, CONSUMER_SUSPENDED). See §4
"DECISION (resolved checkpoint)" at the bottom — it supersedes the "Open Decision
for the Checkpoint" (§3), which is retained as the discovery record.

**Discovery date:** 2026-07-19
**Docs entry point (user-directed):** `https://panoptic.xyz/docs/subgraph/schema`
and `.../subgraph/queries` (fetched first; they publish only the entity schema
and a single Sepolia endpoint — see below).

---

## 1. Panoptic subgraph endpoint discovery

Discovery started at the official docs and expanded through the Panoptic SDK
(`panoptic-labs/panoptic-sdk`) and the DefiLlama adapter, which reference the
Goldsky project `project_cl9gc21q105380hxuh8ks53k3`. Every candidate endpoint was
probed with a live `_meta { block { number timestamp } hasIndexingErrors }` POST.

### Probe results (all endpoints on Goldsky project `project_cl9gc21q105380hxuh8ks53k3`)

| Subgraph path | HTTP | Live? | Notes |
|---|---|---|---|
| `panoptic-subgraph-base/dev/gn` | 200 | **LIVE** | Base L2 (chainId 8453); block ~48,847,866; `hasIndexingErrors:false` |
| `panoptic-subgraph-sepolia/dev/gn` | 200 | live | Sepolia testnet — NOT acceptable for the panel |
| `panoptic-subgraph-sepolia/beta7-prod/gn` | 404 | dead | the endpoint **published in the docs** — now deleted |
| `panoptic-subgraph-mainnet/prod/gn` | 404 | dead | listed by DefiLlama; deleted |
| `panoptic-subgraph-mainnet/dev/gn` | 404 | dead | listed (commented) in the SDK; deleted |
| `panoptic-subgraph-base/prod/gn` | 404 | dead | listed by DefiLlama; deleted |
| `panoptic-subgraph-unichain/{prod,dev}/gn` | 404 | dead | deleted |
| `panoptic-subgraph-optimism/dev/gn`, `-arbitrum/dev/gn` | 404 | dead | never/no longer present |

**Key finding:** The **only reachable non-Sepolia Panoptic subgraph is Base**
(`panoptic-subgraph-base/dev/gn`). The Ethereum-mainnet Goldsky subgraphs (both
`prod` and `dev` tags) are **deleted (404)**. The current Panoptic SDK
(`chainDeployments.ts`) only wires **Base + Sepolia** production deployments —
consistent with Panoptic V2 currently living on Base + Sepolia, not Ethereum
mainnet. No Ethereum-mainnet Panoptic subgraph was found on The Graph gateway
either (the SDK and DefiLlama point only at Goldsky).

### Chosen (reachable) endpoint

- **Endpoint:** `https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn`
- **Chain:** Base mainnet (L2), chainId 8453 — a production L2 (non-Sepolia).
- **Auth:** NONE — this is a public Goldsky endpoint, no gateway key required.
  (If the user later opts for a gateway-hosted subgraph that needs auth, the key
  goes ONLY into the worktree `.env` under the variable name `GRAPH_API_KEY`
  — same handling as the Aristotle key — and is never printed or committed. This
  note records only that auth *would* be required, never a key value.)

### Deepest ETH/USDC market on the reachable (Base) subgraph

The Base subgraph exposes exactly one ETH/USDC Panoptic market (4 panopticPools
total; the others are DEEZ/NUTS, USDC/TTB, USDC/TTA test pairs).

- **panopticPool:** `0xb50e8bb68f5855da742f4579274902a20454174a`
- **fee tier:** 500 (0.05%), tickSpacing 10
- **token0:** ETH (native, `0x0000000000000000000000000000000000000000`, 18 dec)
- **token1:** USDC (`0x833589fcd6edb6e08f4c7c32d4f71b54bda02913`, Base USDC, 6 dec)
- **underlyingPool:** Uniswap **V4** pool (NOT a v3 pool contract)
  - pool-key hash / `id`: `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a`
  - `isV4Pool: true`, `hooks: 0x0000…0000` (no hook), tickSpacing 10
- **History depth (observed):** first OptionMint block 43,781,657
  (2026-03-24T11:44:21Z) → last block 48,760,575 (2026-07-17T17:48:17Z); ~4
  months, **1000+ OptionMints** (query cap hit), **778** legs across all pools,
  but only **7** distinct panopticPoolAccounts on this market (thin cross-section
  for tokenId clustering).

**Consequence for the variance source:** because the underlying pool is Uniswap
**V4 on Base**, the σ̂² source can NOT use the mainnet-v3 path the plan assumed
(`bigquery-public-data.crypto_ethereum` + the v3 Swap topic0 filtered by a pool
*address*). V4 swaps are emitted by the Base **PoolManager singleton** keyed by
the 32-byte poolId, and Base logs live in a Base dataset, not `crypto_ethereum`.
See §2.

---

## 2. BigQuery variance source + Swap topic0

### Swap event topic0 (computed deterministically, cross-verified two ways)

- **Uniswap v3** `Swap(address,address,int256,int256,uint160,uint128,int24)`
  topic0 = `0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67`
  (verified identical via `cast keccak` and Python pycryptodome + eth_utils).
- **Uniswap v4** PoolManager
  `Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)`
  topic0 = `0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f`
  (the V4 form the Base ETH/USDC market actually needs; `topics[OFFSET(1)]` is the
  poolId `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a`).

### Dataset candidates

- **Ethereum mainnet v3 reference:** `bigquery-public-data.crypto_ethereum.logs`
  (columns `address`, `topics` (array), `data`, `block_timestamp`, `block_number`,
  `log_index`). Canonical mainnet ETH/USDC 0.05% v3 pool for the σ̂² reference:
  `0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640`. This is the clean, well-tested
  path — but it only applies if a **mainnet** Panoptic market is used (none is
  currently reachable — see §1).
- **Base V4 (matches the reachable market):** requires a **Base** logs dataset
  (candidate: `bigquery-public-data.goog_blockchain_base_mainnet_us.logs` or an
  equivalent Base export), filtered by the Base V4 PoolManager address, the V4
  Swap topic0, and the poolId in `topics[1]`. Existence/coverage of a public Base
  logs dataset in BigQuery is UNVERIFIED (see blocker).

### BigQuery reachability — BLOCKER (surfaced to the checkpoint)

The BigQuery dry-run (`list-tables` / `describe-table` / the LIMIT-100 row check)
could **not** be executed in this executor session: the `mcp__bigquery__` MCP
tools (and `ToolSearch`) are not present in the executor's toolset, and there is
no `bq`/`gcloud` CLI or credential on this machine. The topic0 values above are
computed and cross-verified, but the "dry-run returns rows for the target pool"
confirmation must be run from the interactive/parent session that has
`mcp__bigquery__` connected. Suggested minimal, cheap probe (mainnet-v3
reference; adapt to the Base dataset if the Base market is chosen):

```sql
SELECT block_timestamp, block_number, data
FROM `bigquery-public-data.crypto_ethereum.logs`
WHERE address = LOWER('0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640')
  AND topics[OFFSET(0)] = '0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67'
  AND DATE(block_timestamp) = '2024-01-15'
LIMIT 100;
```

---

## 3. Open Decision for the Checkpoint (Task 3)

The plan assumed a *mainnet or production-L2 ETH/USDC market with a clean v3 +
`crypto_ethereum` BigQuery path*. Discovery shows the reachable reality diverges:

1. **Endpoint choice.** The only reachable non-Sepolia Panoptic subgraph is
   **Base** (`panoptic-subgraph-base/dev/gn`, keyless). No live Ethereum-mainnet
   Panoptic subgraph exists on Goldsky or (as far as discovery found) The Graph
   gateway. **A `GRAPH_API_KEY` is NOT required to query the reachable Base data**
   — a key would only matter if the user knows of a specific gateway-hosted
   mainnet/deeper subgraph to point at.
2. **If Base is accepted:** the underlying pool is Uniswap **V4 on Base**, so the
   variance source must switch to a **Base logs dataset + the V4 Swap topic0 +
   poolId filter** (not `crypto_ethereum` + v3 topic0). A public Base dataset must
   be confirmed in the parent session (BigQuery MCP).
3. **BigQuery execution gap:** the dry-run row-check must be run from the session
   that has `mcp__bigquery__` (not available to this executor).

**What the user needs to confirm (resume signal):**
- Accept the **Base** ETH/USDC V4 market (chainId 8453, panopticPool
  `0xb50e8bb68f5855da742f4579274902a20454174a`) as the panel market, OR provide a
  specific mainnet/alternative Panoptic subgraph endpoint (and add `GRAPH_API_KEY`
  to the worktree `.env` only if that endpoint needs gateway auth); AND
- Run / confirm the BigQuery dry-run (mainnet-v3 reference and, if Base is chosen,
  the Base V4 dataset) returns rows for the target pool.
```
Reply e.g.: "endpoint confirmed: base V4 (chainId 8453)" and, if applicable,
"GRAPH_API_KEY added" / "BigQuery Base dataset = <name>, dry-run returns rows".
```

---

## 4. DECISION (resolved checkpoint) — 2026-07-19

The checkpoint (Task 3) was resolved by the user with **"accept base"**. This
section is authoritative; §3 above is retained as the discovery/alternatives
record only.

### 4.1 Confirmed panel market — Base V4 ETH/USDC

- **Chain:** Base mainnet (L2), **chainId 8453** (production L2, non-Sepolia).
- **panopticPool:** `0xb50e8bb68f5855da742f4579274902a20454174a`
  (fee tier 500 = **0.05%**, tickSpacing 10).
- **token0:** ETH (native, `0x0000000000000000000000000000000000000000`, 18 dec).
- **token1:** USDC (`0x833589fcd6edb6e08f4c7c32d4f71b54bda02913`, Base USDC, 6 dec).
- **underlyingPool:** Uniswap **V4** pool (PoolManager singleton, keyed by poolId)
  - poolId (`id`): `0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a`
  - `isV4Pool: true`, `hooks: 0x0000…0000` (no hook), tickSpacing 10.
- **Subgraph endpoint:** `https://api.goldsky.com/api/public/project_cl9gc21q105380hxuh8ks53k3/subgraphs/panoptic-subgraph-base/dev/gn`
  (keyless Goldsky `panoptic-subgraph-base/dev/gn`).
- **Verified-live at resolution:** a `_meta` GraphQL probe at 2026-07-19 returned
  block **48,861,639** (2026-07-20T01:57:05Z), `hasIndexingErrors: false`.

### 4.2 GRAPH_API_KEY — NOT required

The confirmed Base endpoint is a **public** Goldsky endpoint. **No
`GRAPH_API_KEY` is needed** and none was added. (If a gateway-hosted subgraph is
ever substituted, the key would live ONLY in the worktree `.env` as
`GRAPH_API_KEY` — never printed or committed — but that is not the case here.)

### 4.3 Variance route — DIRECT RPC `eth_getLogs` (BigQuery dropped)

The σ̂²_t series and the EIV second window are built from Uniswap **V4
PoolManager `Swap` logs** pulled via **chunked `eth_getLogs`** against a **Base
RPC endpoint** (public by default; a paid RPC key may go into the worktree `.env`
later if rate limits demand — never committed).

- **Filter:** the V4 Swap `topic0`
  `0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f`
  (computed + cross-verified in Task 2), with the **poolId as the indexed topic**
  `topics[1] = 0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a`,
  emitted by the Base V4 PoolManager singleton.
- **BigQuery is UNUSABLE — dropped.** The GCP project `thetaswap-research` is
  **suspended**: every query returns `403 CONSUMER_SUSPENDED`. Verified from the
  parent session on 2026-07-19. Option (a) (fix/authorize a BigQuery project) was
  **not** taken by the user. The reference SQL in §2 (mainnet-v3 `crypto_ethereum`
  path) is retained as **historical / alternative only** — it is not the path the
  pipeline uses.

### 4.4 Downstream implications for Wave-2 plans

- **09-05 (variance builder):** consumes **Base V4 `Swap` logs via RPC
  `eth_getLogs`** (chunked over block ranges), NOT BigQuery SQL. The `crypto_ethereum`
  reference SQL in §2 is historical/alternative and must not be wired as the live
  source. σ̂²_t and the EIV second window derive from these RPC-pulled V4 swaps.
- **09-04 (panel):** **unaffected** except for the market identifiers — it reads
  positions/premia/strikes from the confirmed keyless Base subgraph above
  (panopticPool `0xb50e8bb68f5855da742f4579274902a20454174a`, poolId
  `0x96d4…288c0a`).

---

## 5. SCHEMA FINDINGS AT THE LIVE RUN (plan 09-09, 2026-07-20)

§4 resolved *which* endpoint and market to use. It did **not** verify that the
entities the specification depends on actually exist. They largely do not.
Introspection and live queries at the 09-09 estimation run established the
following; this section is authoritative over any earlier assumption about the
subgraph's shape.

### 5.1 What does NOT exist

| Assumed by | Object | Reality |
|---|---|---|
| plan 09-04 | `TokenId.snapshots` | **No such field.** `TokenId` is `id, idHexString, pool, tokenCount, accountBalances, legs`. There is no per-epoch premium series anywhere in the schema. |
| plan 09-04 / spec §4.3 | `premiaSettledInUsdTotal` | **Does not exist.** `AccountBalance` has `premiaSettled0Total` / `premiaSettled1Total` only. |
| spec §4.3 | a non-trivial settled-premia series | **Identically ZERO.** Every `AccountBalance` on this market reports `premiaSettled0Total = premiaSettled1Total = 0`, and the `premiumSettleds` event collection is **EMPTY**. The settled-premia channel carries no signal on this deployment. |
| plan 09-04 | `Leg.strike` as a PRICE | **It is already an int24 TICK** (observed range −202,990 … −197,280). `round(log K / log 1.0001)` took the logarithm of a negative number and produced NaN. |

### 5.2 What the premium channel actually is

`OptionBurn` carries `premium0`, `premium1`, `premiaByLeg` and `tickAt` — the
premium **realized when a position is closed**, over that position's entire life.
Paired with the position's `OptionMint` (`tickAt`, `timestamp`) this yields an
**accrual spell**, which is the unit of observation the 09-09 panel is built on.

Live counts for the confirmed market (full history, 2026-03-27 → 2026-07-20):

| quantity | count |
|---|---|
| `optionMints` | 1,447 |
| `optionBurns` | 1,432 |
| `tokenIds` with legs | 768 |
| burns with **non-zero** `premium0` | 61 |
| burns with non-zero `premium1` | 38 (USDC's 6 decimals truncate small premia to 0) |
| → accrual spells (non-zero premium, paired to a mint) | **61** |
| distinct tokenIds among them | 55 |
| distinct accounts among them | **4** |
| moneyness support | 34 legs above the money, 34 below |

`premium0` (ETH, 18 decimals) is the premium series used, converted to USD at the
pool price implied by `tickAt`. Where both are non-zero, `premium0` and `premium1`
agree to within a few tenths of a percent — confirming they are one premium in two
denominations, not two separate flows.

Sign: the protocol emits premium **positive for short** positions and **negative
for long** ones. Verified exhaustively on the 61: all-short tokens (53) have
positive `premium0`, all-long tokens (8) negative, with no mixed-sign token.

### 5.3 Collateral channel (spec §6.2.4)

The per-position collateral **requirement** `Q_M` is **not in the subgraph**:

- `PanopticPoolAccount.collateral{0,1}Shares` is a **current snapshot only** — no
  historical series.
- `CollateralDayData` carries only `date` and `totalShares`, at **vault level**,
  with no per-account or per-position breakdown.

The closest available series is a reconstruction of per-account **deposited**
collateral share balances from `CollateralDeposit` / `CollateralWithdraw` events
(62 deposits + 45 withdraws across 7 owners, 107 flows total). That is a
*behavioural* quantity, not the protocol's margin requirement, and the 09-09
analysis output labels it as such.

### 5.4 Variance route (unchanged, confirmed working)

Chunked `eth_getLogs` against the public Base RPC, as decided in §4.3. Two
operational constraints discovered at the full-history pull:

- A 10,000-block chunk is accepted and returns ~1,100 logs; `blockTimestamp` is
  present on each log, saving an `eth_getBlockByNumber` round trip per block.
- `toBlock` must be clamped to the current head (the pipeline keeps a 60-block
  safety margin). A range past the tip is rejected with
  `block range extends beyond current head block` — a **non-transient** error that
  retrying cannot clear.

---

## 6. PHASE 10 — the restored position-epoch unit (plan 10-09, 2026-07-27)

**§5 is not superseded. It is extended.** Every finding in §5 still holds *of the
subgraph*: `TokenId` has no `snapshots` field, `premiumSettleds` is empty, and
`AccountBalance.premiaSettled{0,1}Total` is identically zero on this market.
There is still no per-epoch premium series in the subgraph, and this section does
not claim otherwise.

What changed is the **route**. Phase 10 stopped asking the subgraph for the
series and read it off **chain state** instead.

### 6.1 The route: `SFPM.getAccountPremium` archive `eth_call`s

| what | value |
|---|---|
| contract | `SemiFungiblePositionManager` (SFPM) |
| address | `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` (Base) |
| function | `getAccountPremium(address univ3pool, address owner, uint256 tokenType, int24 tickLower, int24 tickUpper, int24 atTick, uint256 isLong)` |
| returns | `(uint128 premiumOwed, uint128 premiumGross)` — X64-scaled accumulators |
| `owner` | the **PanopticPool** `0xb50e8bb68f5855da742f4579274902a20454174a`, NOT the user — the accumulator is **pool-wide per chunk** |
| `vegoid` (ν) | **8** (ν = 1/8), applied INSIDE the contract's accumulator and never re-applied off-chain |
| scale | **X64** (`2^64`) — not X128 (`feeGrowth`), not X96 (`sqrtPrice`) |
| `atTick` | the epoch's pool tick, so the read extrapolates `feeGrowthInside`; `8388607` (`type(int24).max`) requests the STORED value instead |
| endpoints | `https://mainnet.base.org` (primary), `https://base.drpc.org` (failover) — both **archive-capable and keyless** |
| reads issued | **8,910**, deduplicated pool-wide to 52 distinct chunks, blocks 43,781,657 – 48,157,721 |
| artifact | `premium-accumulators.csv` + `premium-accumulators-lineage.md` |

Per-leg premium in token wei, mirroring `PanopticPool._getPremia` L2296-2298:

```
premium = ((acc(t_end) - acc(t_start)) mod 2^128) * legLiquidity / 2^64      (negated for long legs)
```

The `mod 2^128` is load-bearing (the accumulators are `uint128` under Solidity
`unchecked`; a bare `hi - lo` returns ~1.15e77 whenever the value wrapped).

### 6.2 `Leg.width` exists — §5 failed to record it

§5's field inventory omitted `Leg.width`. It **is** in the schema, and it is
selection-relevant: `PanopticPool._getPremia` (L2250) **skips every leg with
`width == 0`**, so such a leg accrues nothing and can never contribute a panel
row. The 10-01 census measured the real population rather than assuming it:
**68 of 68 spell-legs on this market carry `width != 0`**, so the skip does not
thin the usable panel here. `chunk-legs.csv` carries the per-leg census.

`width` also determines the chunk range through `PanopticMath.getTicks`:

```
tickLower = strike - (width * tickSpacing) / 2          -- FLOOR down
tickUpper = strike + (width * tickSpacing + 1) / 2      -- CEIL up
```

The floor/ceil asymmetry matters whenever `width * tickSpacing` is odd; the map
reproduces the protocol's own `Chunk` records on **68/68** legs
(`GETTICKS_MATCH_RATE = 1.0`).

### 6.3 The gate verdict

The reconstruction was scored against the protocol's own `OptionBurn.premium0` on
**all 61 spells**, in Integer ETH wei, stratified short/long
(`reconcile.md`, `reconcile-errors.csv`):

| stratum | n | median rel. error | max |
|---|---|---|---|
| **short** (THE verdict) | 53 | **0.000000** | 5.447268e-4 |
| **long** (reported, not scored) | 8 | **0.000000** | 0.0 |

`GATE: PASS`, `LEGCOUNT_MISMATCHES: 0`, `GATE_TOLERANCE: 0.01` unmodified.
**53 of 61 spells reproduce the ground truth exactly, to the wei.** The residual
on the other 8 is an end-of-block vs at-transaction `eth_call` read wedge,
sub-block on every one of them and irreducible at `eth_call` granularity.

The ground truth is now also frozen as a committed **input**:
`burn-truth.csv`, 61 rows / 55 tokenIds, whose per-tokenId `premium0_wei`
reproduces `reconcile-errors.csv`'s `truth_wei` with **0 mismatches**.

### 6.4 The epoch grid is HOURLY, not daily

The 10-01 Wave-0 census returned **STOP** on the daily grid under its own
pre-committed rule (median 1 usable epoch per position, against a floor of 5):
the median accrual spell is 0.25 days and cannot vary within a daily bucket. The
user re-scoped the phase to `EPOCH_HOURS = 1` **before any estimation**, with the
GO/STOP thresholds untouched, and the hourly re-measurement returned **GO**.

Consequently:

- `variance.csv` (daily, 119 epochs) is **retained unchanged** — the block index
  and the 10-08 gate lineage both reference it.
- `variance-hourly.csv` is the **new** series the panel joins to: **2,833 hourly
  epochs**, the same estimators at a finer bucket, plus an `n_swaps` column.
  Median 177 swaps per hour, max 1,985.
- Exactly **one** hour in the window (epoch 495112) saw **no swap at all**,
  between neighbours carrying 700+. Re-fetching that block range reproduced the
  cached tick series **byte-identically**, so the hour was still on chain rather
  than missed by the pull. It is carried with σ̂² = 0 (no swap ⇒ no increment ⇒ no
  price movement — a *measured* zero), the pool tick carried forward (it is a
  state variable, not a flow), and `n_swaps = 0` so the 3 affected panel rows stay
  isolable downstream.

### 6.5 Row counts: 61 spells → 6,760 position-hour observations

`panel-epoch.csv`, one row per `(tokenId, hourly epoch)`:

| metric | value |
|---|---|
| `PANEL_ROWS` | **6,760** |
| `PANEL_TOKENIDS` (the CLUSTER count) | **55** |
| `PANEL_EPOCHS` | 1,887 |
| `UNMATCHED_EPOCHS` | **0** |
| `TELESCOPE_MISMATCHES` / `PANEL_SUM_MISMATCHES` | **0** / **0** |
| `MULTI_EPOCH_TOKENIDS` | 52 of 55 |
| within-position epochs, median / max | 10 / 1,176 |
| `TOP10_TOKENID_ROW_SHARE` | 0.841 |
| `LEG_READ_HOLES` | 0 |
| Phase-9 baseline / `GAIN_FACTOR` | 61 / **110.8x** |

Reconciliation against the 10-01 census's projected 6,764:

```
6764  (census, per SPELL, hours with >= 2 swaps)
  +3  hour 495112 — excluded by the census as non-estimable, now a measured quiet hour
  -1  hour 492875 — the tick cache's partial leading hour, which has no boundary
      block in the 10-03 index (one spell mints at block 43,781,657, before the
      index's first boundary 43,782,127)
= 6766  SPELL_EPOCH_ROWS
  -6  (tokenId, epoch) collisions: 61 spells over 55 tokenIds, and six of the
      duplicate-tokenId spell pairs share an hour
= 6760  PANEL_ROWS
```

**The row count is not the precision.** Standard errors are tokenId-clustered,
and the cluster count is **unchanged at 55**; 84% of the rows sit in ten
positions. Adding hours to existing positions multiplies rows without multiplying
clusters. Whether this panel identifies υ at the pre-committed CI half-width
(≤ 6.2e-5) is decided in plan 10-10, and a 110x row gain does not prejudge it.

### 6.6 Epoch attribution (the one convention a reader must know)

`Chain.BlockIndex` maps hourly epoch `e` to the first block at or after
`e * 3600` — the **START** of hour `e`. So the accumulator difference between
`boundary(e)` and `boundary(e+1)` is the premium that accrued **during** hour `e`,
and it is tagged `e` — the same hour `σ̂²_e` is measured over. Tagging it `e+1`
(10-05's "ending epoch" convention, correct for the fan-out shape it was written
for) would regress hour `e`'s premium on hour `e+1`'s variance: the 09-05
40587-offset trap, one grid finer.

Both sides bucket through the single `Panel.Epoch.epochOfSeconds`, so the join is
an exact **integer** match — never a timestamp comparison, never an offset
adjustment. Epochs that carry a premium observation but no variance row are
**returned** by the assembler and treated as a hard error by the CLI, not
filtered: silently dropping them is how the 09-05 bug produced a small,
clean-looking, wrong panel.

### 6.7 Artifact index (Phase 10)

| file | what |
|---|---|
| `chunk-legs.csv` | per-(tokenId, leg) census: strike, width, tokenType, chunk range, match flag |
| `panel-size-audit.md` / `panel-size-audit-hourly.md` | the daily STOP and the hourly GO |
| `epoch-blocks.csv` | hourly epoch → first Base block at or after `epoch * 3600` |
| `premium-accumulators.csv` (+ `-lineage.md`) | 8,910 SFPM X64 accumulator readings |
| `reconcile.md` / `reconcile-errors.csv` | THE gate: verdict, both stratum distributions, 61 per-spell rows |
| `burn-truth.csv` | the ground truth frozen as an INPUT (61 rows / 55 tokenIds) |
| `variance-hourly.csv` | σ̂²_t, σ̃²_t, i_t, n_swaps at 2,833 hourly epochs |
| `panel-epoch.csv` | **THE estimation-ready position-hour panel** (6,760 rows) |
