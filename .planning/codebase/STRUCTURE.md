# Codebase Structure

**Analysis Date:** 2026-06-27

## Directory Layout

```
cfmm-replicationPlank/
├── src/                        # All production code — exclusively .plk files + one stub .sol
│   ├── DynamicCFMM.plk         # Top-level entry point (aggregator, currently stub)
│   ├── ReferenceMarket.plk     # Core pool-state Plank contract
│   ├── MarketState.plk         # Storage slot definitions (keccak addresses)
│   ├── MarketType.plk          # (Empty — placeholder for market type enum)
│   ├── Counter.sol             # Foundry scaffold boilerplate (not part of core system)
│   ├── interfaces/
│   │   ├── IMarketDynamics.plk       # ABI selector constants (mutating ops)
│   │   └── IMarketDynamicsLens.plk   # ABI selector constants (view ops)
│   ├── ldf/
│   │   └── GeometricDistribution.plk # Plank LDF implementation
│   ├── lib/
│   │   ├── BinomialProxy.plk   # On-chain pseudo-random direction sampler
│   │   ├── SwapAmtGen.plk      # Deterministic swap-amount generator
│   │   └── TickUtils.plk       # Signed tick math (minUsableTick, maxUsableTick)
│   └── types/
│       ├── Numerics.plk              # NumberFormat, BoundedValue type constructors
│       └── VolatilityTermStructure.plk # Control-parameter type definition
├── spec/
│   └── entities/
│       └── Types.md            # Formal type kernel (the spec driving both tracks)
├── test/
│   ├── Utils.t.sol             # Primary functional test (deploys & exercises Plank contracts)
│   └── LiquidityDensityFunctionPlankTest.t.sol  # LDF conformance suite (stubs)
├── script/
│   └── Counter.s.sol           # Foundry scaffold script (not part of core system)
├── lib/                        # Git submodules
│   ├── plank-foundry-deployer/ # FFI bridge: PlankDeployer.sol, mini-vm.sol
│   ├── plankified-univ3/       # Plank reimplementation of UniV3 math
│   │   └── plank/lib/          # Importable as `v3::` in .plk files
│   ├── bunni-v2/               # ILiquidityDensityFunction interface + Solidity LDF impls
│   ├── forge-std/              # Forge standard library
│   ├── v3-core/                # Uniswap V3 core (reference)
│   ├── v4-core/                # Uniswap V4 core
│   ├── panoptic-v2-core/       # Panoptic V2 (source of solady, v3-core remaps)
│   ├── unistrata/              # Unistrata hook (referenced in notes/STOCHASTIC_MODEL.md)
│   ├── shizo/                  # Shizo module (referenced in notes/STOCHASTIC_MODEL.md)
│   ├── mochi-yield/            # Mochi yield (referenced in notes/STOCHASTIC_MODEL.md)
│   └── protocol/               # Centrifuge protocol (referenced in notes/STOCHASTIC_MODEL.md)
├── refs/                       # EVM opcode and precompile reference docs (Next.js app)
├── .planning/
│   └── codebase/               # GSD codebase analysis documents (this directory)
├── out/                        # Forge build artifacts (generated, committed)
├── cache/                      # Forge build cache (generated)
├── foundry.toml                # Forge config: ffi=true, runs=10, mainnet RPC endpoint
├── remappings.txt              # Solidity import remappings (45 entries)
├── Makefile                    # Build targets for individual Plank contracts + test runner
├── notes/                      # Binding spec docs: DATA_CONTRACT, UNITS_AND_SCALES, STOCHASTIC_MODEL
└── README.md                   # Project README: identity, submodule map, Foundry/Plank build
```

Vendored GAMS module (`model/`):
```
model/
├── primitives.gms              # Shared scalars: unity=1e18, uintMax, tick bounds
├── PricingKernel.gms           # Price grid: lambda^(tick * tickSpacing) over [-120, 120]
├── LiquidityKernel.gms         # Geometric LDF: xi^k / sum(xi^k) normalization
├── TradingRegion.gms           # CFMM cone: L = X^eta * Y^(1-eta) with variable bounds
├── PayoffModule.gms            # (Stub — payoff replication module)
└── dynamic/
    └── InitState.gms           # Initial inventory: X=100e18, Y=10000e18
```

## Directory Purposes

**`src/` — Production Plank contracts:**
- All files are `.plk` except `Counter.sol` (boilerplate)
- Organized by role: top-level contracts at root, interfaces in `interfaces/`, LDF implementations in `ldf/`, utility libraries in `lib/`, type definitions in `types/`
- Every `.plk` file compiles to a standalone EVM bytecode artifact; there is no Solidity inheritance between them
- Build dependency is declared at compile time via `--dep v3=lib/plankified-univ3/plank/lib/`

**`src/interfaces/` — Plank ABI selector files:**
- Not Solidity interfaces; these are Plank files that declare `const SELECTOR_... = 0x...;` constants
- `IMarketDynamics.plk`: holds `SELECTOR_INIT_VOL_TERM_STRUCTURE = 0xd9c112ef` (mutating)
- `IMarketDynamicsLens.plk`: holds (incomplete) selectors for `getStatePartitionDelta` and `getBaseTick` (views)
- Consumed by other Plank files that need to dispatch cross-contract calls

**`src/ldf/` — Liquidity Density Function implementations:**
- Plank implementations that must conform to `ILiquidityDensityFunction` from bunni-v2
- Currently: `GeometricDistribution.plk` only
- Key files to reference: `lib/bunni-v2/src/ldf/GeometricDistribution.sol` and `lib/bunni-v2/src/ldf/LibGeometricDistribution.sol` for the Solidity originals

**`src/lib/` — Plank utility libraries:**
- Stateless math and utility functions used by other Plank contracts
- `TickUtils.plk`: no storage; pure computations; safe to import freely
- `BinomialProxy.plk` / `SwapAmtGen.plk`: stateful (use `@evm_sstore`); deployed as standalone contracts, not imported

**`src/types/` — Plank type definitions:**
- `Numerics.plk`: defines `NumberFormat` (DirectAddressMap), `NumberGroupSpec`, `BoundedValue` as type constructor functions
- `VolatilityTermStructure.plk`: composes `BoundedValue` fields into the control-parameter struct
- Both are imported by other `.plk` files using `import types::numerics::BoundedValue` style paths

**`spec/protocol/entities/Types.md` — Formal type kernel:**
- The specification document that governs the type system for both tracks
- Defines: `NumberFormat`, `BoundedValue<NumberFormat, lowerBound, upperBound>`, `VolatilityTermStructure { priceElasticity, statePartitionDelta, baseTick }`, `VolatilityGrid`, `VolatilityGridLens`
- Any new type added to either the GAMS or Plank track should be specified here first

**`test/` — Forge test contracts:**
- `Utils.t.sol`: the primary integration test; deploys `BinomialProxy`, `SwapAmtGen`, `ReferenceMarket` via `PlankDeployer`; exercises the simulation loop
- `LiquidityDensityFunctionPlankTest.t.sol`: conformance test extending `bunni-v2`'s abstract test suite; test bodies are currently empty stubs

**`refs/` — EVM reference viewer:**
- A Next.js web application (separate node project with its own `package.json`, `node_modules`, `.git`) containing EVM opcode and precompile documentation
- Not part of the smart contract build; used as a local reference tool during development

**`lib/plank-foundry-deployer/` — FFI bridge:**
- Key file: `lib/plank-foundry-deployer/src/PlankDeployer.sol`
- `plankDeployFFI(string path, BuildOptions opts)` — compile and deploy in one call
- `plankBuildFFI(string path, BuildOptions opts) → bytes` — compile only
- `BuildOptions` struct: `backend` (use `"sona"`), `dependencies` (array of `Dependency{name, path}`)

**`lib/plankified-univ3/plank/lib/` — Plank V3 math library:**
- This path is the `v3` namespace; files here are imported as `import v3::util::{...}` in `.plk` sources
- Key modules: `util.plk` (`revert_empty`, `return_u256`, etc.), `math/tick_math.plk`, `math/sqrt_price_math.plk`, `math/swap_math.plk`, `math/full_math.plk`

## Key File Locations

**Entry Points (Plank):**
- `src/DynamicCFMM.plk`: top-level CFMM aggregator (intended final entry point; currently stub)
- `src/ReferenceMarket.plk`: deployable pool-state oracle; primary Plank contract tested today
- `src/ldf/GeometricDistribution.plk`: LDF implementation (the mathematical core)
- `src/lib/BinomialProxy.plk`: random direction sampler
- `src/lib/SwapAmtGen.plk`: swap amount generator

**Entry Points (Solidity):**
- `test/Utils.t.sol`: primary Forge test; run via `make test-utils`
- `test/LiquidityDensityFunctionPlankTest.t.sol`: LDF conformance tests

**Specification:**
- `spec/protocol/entities/Types.md`: canonical type definitions

**Configuration:**
- `foundry.toml`: `ffi = true` (required for Plank FFI), `runs = 10` (fuzz), mainnet RPC endpoint
- `remappings.txt`: all Solidity import remappings
- `Makefile`: `test-utils`, `build-random`, `build-cash`, `build-pool` targets

**Storage Layout:**
- `src/MarketState.plk`: keccak-derived slot constants for pool state
- Slot `SLOT_VOLATILITY_TERM_STRUCTURE = 0xaa65a296...`: VolatilityTermStructure packed storage
- Slot `SLOT_CURRENT_TICK = 7`: current tick (signed int24 in u256)
- Slot `SLOT_MARKET_LIQUIDITY = 10`: total pool liquidity

**Plank–bunni-v2 Interface Binding:**
- Interface: `lib/bunni-v2/src/interfaces/ILiquidityDensityFunction.sol`
- Solidity reference implementation: `lib/bunni-v2/src/ldf/GeometricDistribution.sol`
- Math library: `lib/bunni-v2/src/ldf/LibGeometricDistribution.sol`
- Abstract test: `lib/bunni-v2/test/ldf/LiquidityDensityFunctionTest.sol`

## Naming Conventions

**Files:**
- `.plk` suffix: Plank language source; compiles to EVM bytecode via `plank build`
- `.sol` suffix: Solidity source; conventional Foundry usage
- `.t.sol` suffix: Foundry test contracts (must be placed in `test/`)
- `.s.sol` suffix: Foundry deployment scripts (placed in `script/`)
- `.gms` suffix: GAMS source files (algebraic model)
- `.lst` suffix: GAMS compilation output / listing (generated)

**Plank file naming:**
- PascalCase for deployable contracts: `ReferenceMarket.plk`, `DynamicCFMM.plk`, `GeometricDistribution.plk`
- PascalCase for utility libraries: `BinomialProxy.plk`, `SwapAmtGen.plk`, `TickUtils.plk`
- PascalCase prefixed with `I` for interface files: `IMarketDynamics.plk`, `IMarketDynamicsLens.plk`
- PascalCase for type files: `Numerics.plk`, `VolatilityTermStructure.plk`

**Plank import paths:**
- Library namespace imports: `import v3::util::{revert_empty, return_u256};`
- Intra-project imports: `import types::numerics::BoundedValue;`, `import std::constructor:return_runtime;`
- The `v3` namespace resolves to `lib/plankified-univ3/plank/lib/` via `--dep v3=...`

**Solidity conventions (test layer):**
- Constants: `SCREAMING_SNAKE_CASE` (e.g., `SEL_SET_POOL_LIQUIDITY`, `UNIT_LIQUIDITY`)
- Test helpers: `_camelCase` with leading underscore (e.g., `_setUint256`, `_pingBinomial`, `_rollBlocks`)
- Internal state variables: `SCREAMING_SNAKE_CASE` for deployed contract addresses (`RAND_GEN`, `CASH_FLOW_GEN`, `REFERENCE_MARKET`)

**GAMS conventions:**
- Scalars: `camelCase` (`unity`, `lambda`, `tickSpacing`)
- Sets: `camelCase` (`tick`, `inventory`, `xiDomain`)
- Parameters: `camelCase` (`priceKernel`, `liquidityKernel`, `tickVal`)

## Where to Add New Code

**New Plank contract (deployable):**
- Implementation: `src/NewContract.plk`
- Must include `init { return_runtime(); }` and `run { ... @evm_stop(); }` blocks
- Add Makefile target: `build-newcontract: @plank build src/NewContract.plk --dep v3=lib/plankified-univ3/plank/lib/ --backend 'sona'`
- Add deploy call in `test/Utils.t.sol` `setUp()` alongside other `plankDeployFFI(...)` calls

**New Plank utility library (importable, not deployable):**
- Implementation: `src/lib/NewLib.plk`
- No `init{}`/`run{}` blocks; exports `const` functions only
- Imported in other `.plk` files as `import v3::util::NewLib;` if placed in the v3 lib, or via relative path

**New LDF implementation:**
- Plank source: `src/ldf/NewDistribution.plk`
- Must conform to the `ILiquidityDensityFunction` ABI from `lib/bunni-v2/src/interfaces/ILiquidityDensityFunction.sol`
- Reference Solidity implementation for behavior: `lib/bunni-v2/src/ldf/`
- Create conformance test extending `bunni-v2/test/ldf/LiquidityDensityFunctionTest.sol`

**New type definition:**
- Spec first: add to `spec/protocol/entities/Types.md`
- Plank type constructor: `src/types/NewType.plk`
- GAMS equivalent (if applicable): add set/parameter in the relevant `.gms` file

**New GAMS module:**
- Add to `model/`
- Include `primitives.gms` at top: `$include primitives.gms`
- Use `unity = 1e18` for all WAD-denominated values

**New Solidity test:**
- Test file: `test/NewTest.t.sol`
- Inherit from `Test` and `PlankDeployer` to access `plankDeployFFI`
- Call Plank contracts via `LibCall.callContract` / `LibCall.staticCallContract` from `bunni-v2/lib/solady`

**New interface selector constant:**
- Compute `keccak256("functionName(type1,type2)")[:4]` offline
- Add to `src/interfaces/IMarketDynamics.plk` (mutating) or `src/interfaces/IMarketDynamicsLens.plk` (view)
- Mirror the selector as a Solidity `bytes4 constant` in the relevant test file

## Special Directories

**`out/`:**
- Purpose: Forge compilation artifacts (JSON ABIs + bytecode)
- Generated: Yes
- Committed: Yes (present in repo)
- Note: Contains compiled Solidity artifacts only; Plank bytecode is generated at test-time via FFI, not stored here

**`cache/`:**
- Purpose: Forge build cache and test failure records
- Generated: Yes
- Committed: Partially (present in repo)

**`refs/`:**
- Purpose: Local EVM opcode and precompile reference documentation (Next.js webapp)
- Generated: No (source)
- Committed: Yes
- Note: Has its own `.git` repo, `node_modules`, and build system; treat as an embedded sub-project

**`.planning/codebase/`:**
- Purpose: GSD codebase analysis documents consumed by `/gsd:plan-phase` and `/gsd:execute-phase`
- Generated: By GSD mapping agents
- Committed: Yes

---

*Structure analysis: 2026-06-27*
