# External Integrations

**Analysis Date:** 2026-06-27

## Plank Toolchain (Core Integration)

The most unusual integration in this repo: Foundry tests compile and deploy Plank bytecode
on the fly using Foundry's FFI mechanism.

**How it works:**
1. Test contract inherits `PlankDeployer` (`lib/plank-foundry-deployer/src/PlankDeployer.sol`)
2. At test `setUp()`, `plankDeployFFI(path, opts)` is called
3. This shells out via `vm.ffi(["plank", "build", <file.plk>, "--backend", "sona", "--dep", "v3=..."])` 
4. The Plank compiler writes raw EVM initcode to stdout
5. Foundry captures the bytes and deploys the contract via inline `CREATE` assembly
6. The deployed address is stored and called via low-level `LibCall.callContract` / `LibCall.staticCallContract`

**Plank compiler installation:**
- Binary: `~/.plank/bin/plank` (v0.1.1)
- Install: `curl -L install.plankevm.org | bash && plankup`
- Source: `lib/plank-monorepo/plankc/` (Rust/Cargo workspace)
- GitHub: `https://github.com/plankevm/plank-monorepo`

**FFI requirement:**
- `ffi = true` in `foundry.toml` is mandatory for all Plank-compiled tests to run.
- The `plank` binary must be in `$PATH` during `forge test` execution.

**Plank standard library:**
- Runtime stdlib: `~/.plank/stdlib/` (installed with the binary)
- Source: `lib/plank-monorepo/std/` — modules include `abi.plk`, `constructor.plk`,
  `math.plk`, `mem.plk`, `storage.plk`, `utils.plk`, `addr.plk`, etc.

**Plankified Uniswap V3 math library:**
- Location: `lib/plankified-univ3/plank/lib/`
- GitHub: `https://github.com/plankevm/plankified-univ3`
- Provides Uniswap V3 math ported to Plank:
  `tick_math.plk`, `sqrt_price_math.plk`, `full_math.plk`, `swap_math.plk`,
  `bit_math.plk`, `fixed_point_96.plk`, `fixed_point_128.plk`, `liquidity_math.plk`,
  `safe_cast.plk`, `unsafe_math.plk`
- Also provides `util.plk` — revert helpers (`revert_empty`, `return_u256`, etc.)
- Imported in Plank sources as `import v3::util::{...};` and `import v3::math::...;`
- Passed to the compiler via `--dep v3=lib/plankified-univ3/plank/lib/`

## Uniswap V3 / V4 Protocol Dependencies

**Uniswap V3 Core:**
- Submodule: `lib/v3-core` (branch `0.8`, rev 6562c52)
- GitHub: `https://github.com/uniswap/v3-core`
- Remapped as `v3-core/=lib/panoptic-v2-core/lib/v3-core/contracts/` and
  `univ3-core/=lib/panoptic-v2-core/lib/v3-core/contracts/`
- Also transitive via `lib/panoptic-v2-core/lib/v3-core/`
- Provides: `UniswapV3Pool`, `IUniswapV3Pool`, tick/sqrtPrice math interfaces

**Uniswap V3 Periphery:**
- Transitive via `lib/panoptic-v2-core/lib/v3-periphery/`
- Remapped as `v3-periphery/` and `univ3-periphery/`

**Uniswap V4 Core:**
- Submodule: `lib/v4-core` (untracked; provides `PoolManager` and core types)
- GitHub: implied by content
- Remapped as `v4-core/=lib/v4-core/src/`
- Provides: `IPoolManager`, `PoolKey`, `PoolId`, `BalanceDelta`, `Currency`,
  `Hooks`, `StateLibrary`, `TickMath`, `LPFeeLibrary`, `SwapParams`,
  `ModifyLiquidityParams`, `PoolManager`
- Used directly by hook contracts in `lib/unistrata/`, `lib/shizo/`, `lib/mochi-yield/`

**Uniswap V4 Periphery:**
- Transitive via `lib/unistrata/lib/uniswap-hooks/lib/v4-periphery/`
- Remapped as `v4-periphery/`

## Bunni V2

- Submodule: `lib/bunni-v2` (v1.2.1, rev 000f79a)
- GitHub: `https://github.com/Bunniapp/bunni-v2`
- Remapped as `bunni-v2/=lib/bunni-v2/`
- What it provides:
  - `ILiquidityDensityFunction` interface — the main LDF abstraction this project is
    implementing in Plank (`src/ldf/GeometricDistribution.plk`)
  - `LiquidityDensityFunctionTest` — base fuzz test contract used in
    `test/LiquidityDensityFunctionPlankTest.t.sol`
  - Reference LDF implementations: `GeometricDistribution.sol`, `DoubleGeometricDistribution.sol`,
    `UniformDistribution.sol`, etc. in `lib/bunni-v2/src/ldf/`
  - `BunniHub.sol`, `BunniHook.sol`, `BunniToken.sol` — full AMM protocol built on Uniswap v4
- Transitive deps from bunni-v2: `biddog/`, `create3-factory/`, `flood-contracts/`,
  `leb128-nooffset/`, `multicaller/`, `permit2/`, `forge-gas-snapshot/`

## Panoptic V2 Core

- Submodule: `lib/panoptic-v2-core` (rev 5555b32)
- GitHub: `https://github.com/panoptic-labs/panoptic-v2-core`
- Remapped as `panoptic-v2-core/=lib/panoptic-v2-core/`
- Brings a large tree of transitive dependencies:
  - `solady` — `lib/panoptic-v2-core/lib/solady/src/` (remapped `solady/`)
  - `clones-with-immutable-args` — `lib/panoptic-v2-core/lib/clones-with-immutable-args/src/`
  - `panoptic-helper` — `lib/panoptic-v2-core/lib/panoptic-helper/`
  - `v3-core`, `v3-periphery` as above
- Used via `@base/`, `@contracts/`, `@libraries/`, `@tokens/`, `@types/`, `@scripts/`,
  `@helper/`, `@test_periphery/`, `@uniswap/` remapping prefixes
- Currently used in `notes/STOCHASTIC_MODEL.md` design notes for Centrifuge integration test scaffolding

## Centrifuge Protocol

- Submodule: `lib/protocol` (v3.2.0, rev 41e1997)
- GitHub: `https://github.com/centrifuge/protocol`
- Remapped as (none — not yet remapped in `remappings.txt`)
- A multi-chain, permissioned protocol for tokenizing financial products (6 chains live)
- Referenced in `notes/STOCHASTIC_MODEL.md` for `BalanceSheetTestDeposit` integration testing
  (`testDepositERC6909`, `testDepositERC20`)
- Not yet integrated into any `.plk` or `.sol` in this project's `src/` or `test/`

## Unistrata (Uniswap v4 Hook with Reactive Network)

- Submodule: `lib/unistrata` (untracked, no entry in `.gitmodules`)
- Content: `lib/unistrata/src/UnistrataHook.sol`, `lib/unistrata/src/libraries/`
  (`VarianceLib.sol`, `NavLib.sol`, `WaterfallLib.sol`), `lib/unistrata/src/StratumToken.sol`
- Remapped as `unistrata/=lib/unistrata/src/`
- What it does: Uniswap v4 hook that splits LP impermanent loss into senior (Bedrock) /
  junior (Sediment) tranches, with settlement triggered cross-chain by a **Reactive
  Smart Contract** (Reactive Network chain ID 5318007, Lasna testnet)
- Transitive deps:
  - `hookmate/=lib/unistrata/lib/hookmate/src/`
  - `v4-periphery/=lib/unistrata/lib/uniswap-hooks/lib/v4-periphery/`
  - `reactive-lib/=lib/shizo/lib/reactive-lib/` (shared with shizo)

## Schizō / ILBond Hook (Uniswap v4 + Reactive Network)

- Submodule: `lib/shizo` (untracked, no entry in `.gitmodules`)
- Key file: `lib/shizo/src/ILBondHook.sol`
- Remapped as `shizo/=lib/shizo/src/`
- What it does: Uniswap v4 hook that splits LP positions into FEE-T (yield) and IL-T
  (impermanent loss risk) tokens. IL mark-to-market is computed on every swap by a
  Reactive Smart Contract — no keeper, no off-chain bot
- Reactive Network integration: `AbstractCallback`, `AbstractPayer` from
  `reactive-lib/=lib/shizo/lib/reactive-lib/`
- Live on Reactive Lasna testnet (chain ID 5318007)

## Mochi Yield (Uniswap v4 Hook)

- Submodule: `lib/mochi-yield` (untracked, no entry in `.gitmodules`)
- Remapped as `mochi-yield/=lib/mochi-yield/`
- What it does: Time-aware fixed-income market on Uniswap v4; enforces implied rate
  bounds, time-to-maturity fee decay, and cross-pool PT/YT parity
- Uses `reactive-lib` for cross-chain settlement (same pattern as unistrata/shizo)
- Live at `mochiyeild.xyz`

## Reactive Network

- Not a direct submodule of this repo but integrated transitively through `lib/shizo`
  and `lib/unistrata`
- Base contracts: `reactive-lib/=lib/shizo/lib/reactive-lib/`
- Provides `AbstractCallback`, `AbstractPayer` for writing Reactive Smart Contracts
- Used for trustless, keeper-free cross-chain event-driven settlement

## GAMS Companion (External Research Tool)

- Location: `model/` (vendored in-repo)
- Files: `LiquidityKernel.gms`, `PayoffModule.gms`, `PriceKernel.gms`,
  `PricingKernel.gms`, `primitives.gms`, `TradingRegion.gms`,
  `dynamic/InitState.gms`
- Role: Algebraic modeling / specification of CFMM payoff replication mathematics.
  Provides the formal parameter definitions (tick domains, liquidity kernels, pricing
  primitives) that are then implemented on-chain in Plank. Acts as a research-layer
  spec tool, not integrated at build/test time.
- No bridge or build tooling connects GAMS output to the Foundry/Plank pipeline.

## Ethereum Mainnet RPC (Alchemy)

- Purpose: Fork testing in `test/Utils.t.sol`
- Endpoint: `https://eth-mainnet.g.alchemy.com/v2/${API_KEY}` (configured in `foundry.toml`)
- Auth: `API_KEY` env var (set in `.env`, gitignored)
- Usage: `vm.createSelectFork(vm.rpcUrl("mainnet"))` in `_bootstrapChain()`;
  pinned to block `25_298_856` for deterministic `block.prevrandao` seeding
- Fallback: If fork fails (no API key), tests fall back to a local Anvil chain with
  `vm.roll(INIT_BLOCK)` and synthetic `prevrandao` — all Plank-deployed contracts
  still work in this mode

## CI/CD

- Platform: GitHub Actions
- Workflow: `.github/workflows/test.yml`
- Trigger: push, pull_request, workflow_dispatch
- Runner: `ubuntu-latest`
- Steps:
  1. `actions/checkout@v5` with `submodules: recursive`
  2. `foundry-rs/foundry-toolchain@v1` (installs forge/cast/anvil)
  3. `forge fmt --check`
  4. `forge build --sizes`
  5. `forge test -vvv`
- NOTE: The Plank compiler binary is NOT installed in CI. Any test that calls
  `plankDeployFFI(...)` will fail in CI until `plankup` is added to the workflow.
  The `build-random`, `build-cash`, `build-pool` Makefile targets also require `plank`
  to be in PATH.

## Webhooks & Callbacks

**Incoming:** None in this repo.

**Outgoing:** None directly from this repo. The hook contracts in dependency submodules
(`lib/unistrata`, `lib/shizo`, `lib/mochi-yield`) emit events consumed by Reactive
Network RSCs, but that wiring lives entirely within those submodules.

---

*Integration audit: 2026-06-27*
