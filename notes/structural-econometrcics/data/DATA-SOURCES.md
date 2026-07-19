# DATA-SOURCES — Panoptic υ-identification panel (Phase 09, Plan 02)

**Purpose:** Self-describing record of the confirmed live data path for the
position-epoch panel (Panoptic subgraph) and the underlying-pool variance source
(BigQuery swap logs). Discovery gate for CTX-PANEL / CTX-VAR.

**Status:** DISCOVERY COMPLETE — awaiting user endpoint decision (checkpoint,
Task 3). See "Open Decision for the Checkpoint" at the bottom.

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
