# Architecture

**Analysis Date:** 2026-06-27

## Pattern Overview

**Overall:** Dual-track research prototype — a Plank (EVM bytecode DSL) simulation layer coupled to an external GAMS algebraic modeling layer, bridged by Solidity/Foundry glue.

**Key Characteristics:**
- All on-chain CFMM logic is written in `.plk` (Plank language), compiled to raw EVM bytecode at test time via FFI
- Solidity files exist only as thin glue: test harnesses, script scaffolding, and the `PlankDeployer` FFI bridge
- The GAMS module (vendored in-repo at `model/`) is the algebraic "solver" that determines optimal parameter values — currently separate from the on-chain code with no automated bridge yet
- `spec/protocol/entities/Types.md` is the shared type kernel that defines the formal type system used by both tracks

## Layers

**Layer 1 — GAMS Algebraic Model:**
- Purpose: Symbolic / numeric computation of CFMM primitives and optimal control parameters
- Location: `model/` (vendored in-repo)
- Contains: `primitives.gms`, `PricingKernel.gms`, `LiquidityKernel.gms`, `TradingRegion.gms`, `PayoffModule.gms`, `dynamic/InitState.gms`
- Depends on: nothing in this repo
- Used by: (intended) Plank layer for parameter seeding; currently manual

**Layer 2 — Plank EVM Contracts:**
- Purpose: Low-level EVM contracts implementing CFMM dynamics, stochastic simulation primitives, and the LDF
- Location: `src/` (`.plk` files only)
- Contains: market state storage, reference pool, geometric LDF, binomial direction proxy, swap-amount generator, tick math utilities
- Depends on: `lib/plankified-univ3/plank/lib/` (imported via `--dep v3=...` at build time)
- Used by: Solidity test harnesses via `PlankDeployer.plankDeployFFI()`

**Layer 3 — Solidity / Foundry Glue:**
- Purpose: Test harnesses, FFI bridge to the `plank` compiler, interface casting, and conformance testing against bunni-v2
- Location: `test/`, `script/`, `lib/plank-foundry-deployer/src/`
- Contains: `UtilsTest`, `LiquidityDensityFunctionPlankTest`, `PlankDeployer`, `CounterScript`
- Depends on: `forge-std`, `bunni-v2`, `plank-foundry-deployer`
- Used by: Forge test runner

**Layer 4 — Library Ecosystem:**
- Purpose: Third-party Solidity and Plank libraries providing math primitives, interfaces, and deployment tooling
- Location: `lib/`
- Key members:
  - `lib/plankified-univ3/plank/lib/` — Plank re-implementation of UniV3 tick math, sqrt price math, swap math
  - `lib/bunni-v2/src/` — `ILiquidityDensityFunction` interface and `GeometricDistribution.sol` (the Solidity reference that `src/ldf/GeometricDistribution.plk` must conform to)
  - `lib/plank-foundry-deployer/src/PlankDeployer.sol` — invokes `plank build` via `vm.ffi()` and deploys bytecode inline

## Data Flow

**Compile-time / deploy-time flow (Plank → EVM):**

1. Forge test or Makefile target invokes `plankDeployFFI("src/foo.plk", opts)` or `plank build src/foo.plk --dep v3=lib/plankified-univ3/plank/lib/ --backend sona`
2. `PlankDeployer.plankBuildFFI()` shells out via `vm.ffi()` calling the `plank` compiler binary
3. Compiler resolves `import v3::...` against the `--dep v3` path, produces raw EVM initcode bytes
4. `PlankDeployer._deploy()` uses inline assembly `create` to deploy; returns the contract address
5. Address is cast to a Solidity interface (e.g., `ILiquidityDensityFunction`) for further calls

**Runtime simulation flow (stochastic swap replay):**

1. `UtilsTest.setUp()` deploys three Plank contracts: `RAND_GEN` (BinomialProxy), `CASH_FLOW_GEN` (SwapAmtGen), `REFERENCE_MARKET` (ReferenceMarket)
2. `init_state()` writes canonical starting state `(tickSpacing=20, tick=100, tickLower=-120, tickUpper=120, L=1e18)` to `REFERENCE_MARKET` via ABI-encoded `LibCall.callContract` calls
3. `_pingBinomial()` calls `RAND_GEN.ping()` → `BinomialProxy.gen_rand(block.prevrandao)` → returns 0 or 1 (direction indicator `I_{n,t}`)
4. `_rollBlocks(delta)` advances block number; `vm.prevrandao(prev ^ 1)` toggles the seed so successive calls alternate direction
5. `SwapAmtGen.swapAmount(timeIndex)` computes the deterministic swap-amount proxy: `19e18 + 2 * KERNEL^(timeDecay * t^4)`
6. Direction + amount form a synthetic swap event against the ReferenceMarket state
7. (Planned) `GeometricDistribution.plk` (LDF) is queried at the current tick to re-balance liquidity after each swap

**GAMS → Plank parameter seeding (intended, not yet automated):**

1. GAMS `LiquidityKernel.gms` solves for the geometric ratio `xi` and length `iota` that best replicate a target payoff
2. `TradingRegion.gms` solves the CFMM liquidity cone `L = X^(eta) * Y^(1-eta)` to extract inventory bounds
3. Optimal `(xi, iota)` are read from GAMS output, mapped to Plank contract parameters:
   - `xi` → `priceElasticity` in `VolatilityTermStructure` → `alpha` parameter in `GeometricDistribution.plk`
   - `iota` → `statePartitionDelta` in `VolatilityTermStructure` → `tickSpacing` in `ReferenceMarket`
4. Parameters would be written via `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`) — the connection layer is currently a manual step

**State Management:**
- All Plank contracts manage EVM storage directly via `@evm_sstore`/`@evm_sload` at keccak-addressed slots
- Key slots defined in `src/MarketState.plk`: `SLOT_VOLATILITY_TERM_STRUCTURE` (keccak256 of `"MARKET_STATE.VOLATILITY_TERM_STRUCTURE"`), `SLOT_CURRENT_TICK = 7`, `SLOT_MARKET_LIQUIDITY = 10`
- `SwapAmtGen.plk` uses `SLOT_TIME_DECAY` (keccak-addressed) to persist the time-decay exponent between calls

## Key Abstractions

**VolatilityTermStructure (control surface):**
- Purpose: The three-parameter control vector that the adaptive feedback controller manipulates to replicate a target payoff
- Defined in: `spec/protocol/entities/Types.md` (formal spec), `src/types/VolatilityTermStructure.plk` (Plank type), `src/MarketState.plk` (storage slot)
- Fields: `priceElasticity: BoundedValue<Q64x96, 0, Q96_ONE>`, `statePartitionDelta: BoundedValue<Natural, 1, 200>`, `baseTick: BoundedValue<Integer, -, ...>`
- GAMS counterparts: `xi` (xiDomain), `iota` (iotaDomain), `tick` (baseTick)

**ReferenceMarket (pool state oracle):**
- Purpose: Canonical Plank contract holding the running CFMM simulation state
- File: `src/ReferenceMarket.plk`
- ABI: view selectors `poolLiquidity() 0x3b228b3e`, `tickSpacing() 0x408e87f6`, `currentTick() 0x065e5360`, `tickLower() 0x59c4f905`, `tickUpper() 0x55b812a8`; mutating selectors `setPoolLiquidity 0x08a68255`, `setTickSpacing 0x0693ca3b`, `setCurrentTick 0x8f3f8c52`, `setTickLower 0x04211dd1`, `setTickUpper 0x37969917`
- Pattern: flat `run{}` block with if-else selector dispatch; signed-integer ticks stored as two's-complement in u256

**ILiquidityDensityFunction (LDF interface):**
- Purpose: The bunni-v2 standard interface that any LDF implementation must satisfy; governs how liquidity density is queried over tick space and how swaps are computed
- Solidity source: `lib/bunni-v2/src/interfaces/ILiquidityDensityFunction.sol`
- Plank implementation target: `src/ldf/GeometricDistribution.plk`
- Key methods: `query()` (density + cumulative amounts + surge flag), `computeSwap()` (inverse-CDF lookup for swap routing), `cumulativeAmount0/1()`, `isValidParams()`

**GeometricDistribution LDF:**
- Purpose: Plank re-implementation of the geometric distribution LDF; liquidity at tick `k` decays as `alpha^k` (normalized), where `alpha = xi`
- Plank file: `src/ldf/GeometricDistribution.plk`
- Solidity reference: `lib/bunni-v2/src/ldf/GeometricDistribution.sol` and `lib/bunni-v2/src/ldf/LibGeometricDistribution.sol`
- Test conformance: `test/LiquidityDensityFunctionPlankTest.t.sol` extends `bunni-v2/test/ldf/LiquidityDensityFunctionTest` to enforce behavioral parity

**BinomialProxy (direction generator):**
- Purpose: On-chain pseudo-random direction sampler; models `P(I=+1) = P(I=-1) = 1/2` from the stochastic model in `notes/STOCHASTIC_MODEL.md`
- File: `src/lib/BinomialProxy.plk`
- Mechanism: reads `@evm_difficulty()` (maps to `block.prevrandao` post-merge), returns `(seed & 1)` — 0 or 1
- Selector: `ping()` = `0x5c36b186`

**SwapAmtGen (cash-flow generator):**
- Purpose: Deterministic proxy for the stochastic swap-amount process `Delta_y(t) = sum_n I_{n,t} * Delta_y_{n,t}`
- File: `src/lib/SwapAmtGen.plk`
- Formula: `19e18 + 2 * 1e14^(timeDecay * t^4)` where `timeDecay` is initialized to `-10000e18` and persisted in storage
- Selectors: `swapAmount(uint256) 0xbc4af3dc`, `timeDecay() 0xcaaedea1`, `setDecay(uint256) 0x03ec5467`

**IMarketDynamics / IMarketDynamicsLens (Plank interfaces):**
- Purpose: ABI selector constants for the market dynamics contract — the intended hook target that wraps Plank state and is callable from a Uniswap V4 `beforeSwap` hook
- Files: `src/interfaces/IMarketDynamics.plk` (mutating: `initVolTermStructure 0xd9c112ef`), `src/interfaces/IMarketDynamicsLens.plk` (views: `getStatePartitionDelta`, `getBaseTick`)

**PlankDeployer (FFI bridge):**
- Purpose: Solidity abstract contract that compiles and deploys `.plk` source files from within a Forge test
- File: `lib/plank-foundry-deployer/src/PlankDeployer.sol`
- Key function: `plankDeployFFI(string root, BuildOptions opts) → address`
- Backend used in this repo: `'sona'` (set via `opts.backend`)
- Dependency resolution: `Dependency("v3", "lib/plankified-univ3/plank/lib")` maps import prefix `v3::` to the plankified-univ3 library path

## Entry Points

**Plank compiler entry points (Makefile targets):**
- `src/lib/BinomialProxy.plk` → `make build-random` → deployed as `RAND_GEN`
- `src/lib/SwapAmtGen.plk` → `make build-cash` → deployed as `CASH_FLOW_GEN`
- `src/ReferenceMarket.plk` → `make build-pool` → deployed as `REFERENCE_MARKET`
- `src/ldf/GeometricDistribution.plk` → deployed by `LiquidityDensityFunctionPlankTest._setUpLDF()`
- `src/DynamicCFMM.plk` → top-level aggregator contract (currently stub with empty `init{}`/`run{}`)

**Forge test entry points:**
- `test/Utils.t.sol` → `make test-utils` → `forge test --match-contract UtilsTest -vvvv --via-ir`
- `test/LiquidityDensityFunctionPlankTest.t.sol` → LDF conformance suite (test bodies currently empty/stub)

**Solidity script entry points:**
- `script/Counter.s.sol` → boilerplate Foundry scaffold, not part of the core system

**Plank runtime dispatch pattern (all contracts):**
```plank
run {
    let selector = @evm_shr(224, @evm_calldataload(0));
    if selector == 0xXXXXXXXX { handle_...(args); }
    ...
    @evm_stop();
}
```

**Plank init pattern (all contracts):**
```plank
const return_runtime = fn () never {
    let buf = @malloc_uninit(@runtime_length());
    @evm_codecopy(buf, @runtime_start_offset(), @runtime_length());
    @evm_return(buf, @runtime_length());
};
init { return_runtime(); }
```

## Error Handling

**Strategy:** Explicit EVM reverts via imported `revert_*` helpers from `lib/plankified-univ3/plank/lib/util.plk`

**Patterns:**
- `revert_empty()` — revert with no data on unrecognized selector
- `revert_with_return_data()`, `revert_R`, `revert_LOK`, `revert_IIA`, `revert_L`, `revert_SPL` — typed reverts mirroring UniV3 error codes
- No Solidity `require`/`revert` strings in Plank code; all error handling is raw EVM

## Cross-Cutting Concerns

**Signed integer handling:** Plank has only `u256`; `int24` ticks are stored as two's-complement patterns in `u256`. All signed arithmetic uses `@evm_sdiv`, `@evm_slt`, etc. The `Tick = u256` type alias in `src/lib/TickUtils.plk` documents this contract.

**Fixed-point arithmetic:** Storage and computation use WAD (`1e18 = unity`) and Q64.96 notation. The `src/types/Numerics.plk` file defines `NumberFormat`, `NumberGroupSpec`, and `BoundedValue` as Plank type constructors. GAMS uses the same `unity = 1e18` scalar.

**Validation:** `isValidParams()` on the LDF checks parameter bounds. `src/types/Numerics.plk` defines `BoundedValue` to encode min/max constraints in the type system.

**Fork testing:** `UtilsTest` attempts to fork mainnet (block `25_298_856`) via `vm.createSelectFork(vm.rpcUrl("mainnet"))` with graceful fallback to local chain if the RPC is unavailable. `RAND_GEN`, `CASH_FLOW_GEN`, `REFERENCE_MARKET` are marked persistent across fork rolls.

## The Plank–GAMS Duality

| Concept | GAMS symbol | Plank / Solidity symbol | Location |
|---|---|---|---|
| Price elasticity / geometric ratio | `xi` (xiDomain, xiNorm) | `priceElasticity` / LDF `alpha` | `LiquidityKernel.gms`, `src/types/VolatilityTermStructure.plk` |
| Tick spacing / range length | `iota` (iotaDomain) | `statePartitionDelta` / `tickSpacing` | `LiquidityKernel.gms`, `src/MarketState.plk` |
| CFMM invariant (liquidity cone) | `L = X^eta * Y^(1-eta)` | geometric LDF shape | `TradingRegion.gms`, `src/ldf/GeometricDistribution.plk` |
| Price grid (tick→price) | `priceKernel(tickSpacing, tick) = lambda^(tick*ts)` | `TickMath.getSqrtRatioAtTick` | `PricingKernel.gms`, `lib/plankified-univ3/plank/lib/math/tick_math.plk` |
| Initial inventory | `init(X) = 100e18, init(Y) = 10000e18` | `(cashStock = 100e18)` in DynamicCFMM INIT_STATE | `dynamic/InitState.gms`, `src/DynamicCFMM.plk` |
| Swap direction indicator | stochastic `I_{n,t} ∈ {-1,+1}` | `BinomialProxy.ping() → {0,1}` | `notes/STOCHASTIC_MODEL.md`, `src/lib/BinomialProxy.plk` |
| Swap amount process | `Delta_y(t) = 19 + 1.0001^(eta*t^4)` | `SwapAmtGen.swapAmount(t)` | `notes/STOCHASTIC_MODEL.md`, `src/lib/SwapAmtGen.plk` |

The intended connection layer:
1. GAMS solves for optimal `(xi*, iota*)` given a target payoff function
2. These values are encoded as `VolatilityTermStructure` bytes and passed to `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`)
3. The Plank `ReferenceMarket` / `GeometricDistribution` contracts read these parameters and simulate the CFMM under the optimized configuration
4. The adaptive feedback controller (not yet implemented: `src/DynamicCFMM.plk` stub) would close the loop by updating `(xi, iota)` as the simulated market evolves

---

*Architecture analysis: 2026-06-27*
