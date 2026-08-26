# Coding Conventions

**Analysis Date:** 2026-06-27

## Language Overview

This codebase uses two distinct languages side by side:

1. **Solidity** — test harnesses, scripts, and one stub contract (`src/Counter.sol`)
2. **Plank (`.plk`)** — all production smart-contract logic (contracts, libraries, types, interfaces)

Conventions for each are documented separately below.

---

## Solidity Conventions

### Version

All project-owned Solidity files use an open caret pragma:

- `pragma solidity ^0.8.13;` — used in `src/Counter.sol`, `test/LiquidityDensityFunctionPlankTest.t.sol`, `script/Counter.s.sol`
- `pragma solidity ^0.8.0;` — used in `test/Utils.t.sol`

No exact pin or `>=` range is used. Scripts follow the same version as source. The `foundry.toml` does not set `solc_version`, so the forge default resolver picks the version.

### Naming

**Contracts:**
- `PascalCase` — `Counter`, `UtilsTest`, `LiquidityDensityFunctionPlankTest`, `CounterScript`

**Functions:**
- `camelCase` for external/public — `setNumber`, `increment`
- `camelCase` prefixed with `_` for internal helpers — `_setUint256`, `_readUint256`, `_readInt24`, `_pingBinomial`, `_rollBlocks`, `_bootstrapChain`, `_selectTestFork`, `_setUpLDF`
- `camelCase` with no prefix for internal setup helpers — `init_state` (one exception: uses snake_case)

**State Variables:**
- `SCREAMING_SNAKE_CASE` for `uint256`/`bytes4` constants — `MIN_ALPHA`, `MAX_ALPHA`, `INIT_BLOCK`, `REFERENCE_BLOCK`, `SEL_SET_POOL_LIQUIDITY`, etc.
- `SCREAMING_SNAKE_CASE` for `uint128`/`int24` constants — `UNIT_LIQUIDITY`, `INIT_TICK_SPACING`, `ZERO_VALUE`
- `PascalCase` or plain `UPPER` for contract-level mutable addresses — `RAND_GEN`, `CASH_FLOW_GEN`, `REFERENCE_MARKET` (all uppercase: treated as effectively-immutable deployment artifacts)
- `camelCase` for mutable state — `state`, `forkId`, `isForked`, `prevDifficulty`, `lastBinomial`

**Structs:**
- `PascalCase` — `State`, `BuildOptions`, `Dependency`

**Struct Fields and Local Variables:**
- `camelCase` — `tickSpacing`, `currentTick`, `poolLiquidity`, `effectiveDelta`, `fromContractPrev`

**Selector Constants:**
- Prefix `SEL_` followed by `SCREAMING_SNAKE_CASE` verb-object — `SEL_SET_POOL_LIQUIDITY`, `SEL_POOL_LIQUIDITY`, `SEL_SET_TICK_SPACING`, `SEL_CURRENT_TICK`

### Interface Conventions

No Solidity interfaces are defined in this project. The `IMarketDynamics.plk` and `IMarketDynamicsLens.plk` files follow the Solidity `I`-prefix convention but are written in Plank (see Plank conventions below). When consuming upstream Solidity interfaces (from bunni-v2), they are imported with named import syntax: `import {ILiquidityDensityFunction} from "bunni-v2/src/interfaces/ILiquidityDensityFunction.sol"`.

### Import Style

Named/grouped imports are preferred:

```solidity
import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {ILiquidityDensityFunction} from "bunni-v2/src/interfaces/ILiquidityDensityFunction.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";
```

Bare (non-named) imports appear only for `forge-std/Test.sol` in the bunni-v2 base test contract (upstream dependency, not this project's code).

### NatSpec / Docstrings

NatSpec is not used in project-owned Solidity files (`src/Counter.sol`, `test/Utils.t.sol`, `test/LiquidityDensityFunctionPlankTest.t.sol`). Inline comments use `//` for single-line explanations of selector values:

```solidity
// setPoolLiquidity(uint256)
bytes4 constant SEL_SET_POOL_LIQUIDITY = 0x08a68255;
```

### Error Handling

No custom Solidity errors (`error Foo()`) are defined. Error signaling in Solidity test code is done through:

- `require(...)` with a string message (in `PlankDeployer.sol` upstream)
- `try/catch` — `_bootstrapChain()` wraps `vm.createSelectFork` in a try block with a fallback log message
- Assembly `revert` — `_deploy()` in `PlankDeployer.sol` uses inline assembly to forward revert data on deployment failure

### SPDX Licenses

Two license identifiers are used:
- `UNLICENSED` — `src/Counter.sol`, `test/LiquidityDensityFunctionPlankTest.t.sol`, `script/Counter.s.sol`
- `MIT` — `test/Utils.t.sol`

---

## Plank (`.plk`) Conventions

### Language Basics

Plank is a statically-typed, expression-oriented language that compiles to EVM bytecode via the Plank compiler (`plankc`). It has no objects or classes; the contract model consists of exactly two top-level entry points:

- `init { ... }` — constructor body
- `run { ... }` — runtime dispatch body (equivalent to the EVM fallback/dispatch loop)

All logic is defined as `const` bindings that can hold scalar values, function literals (`fn`), struct type definitions, or type aliases.

### File Structure

Every non-interface `.plk` file follows this skeleton:

```plank
import <namespace>::<module>::{<items>};   // imports first

const CONSTANT_NAME = <hex_literal>;       // constants (SCREAMING_SNAKE_CASE)

const return_runtime = fn () never { ... }; // always present: runtime-copy helper

const functionName = fn (param: type) returnType { ... };  // functions

init {
    // constructor: typically calls return_runtime() after setup
}

run {
    let selector = @evm_shr(224, @evm_calldataload(0));
    if selector == 0x... { ... }
    // fallthrough to revert
}
```

### Naming in Plank

**Constants and storage slots:**
- `SCREAMING_SNAKE_CASE` for scalar constants and storage slot identifiers:
  - `LOWER_BOUND`, `UPPER_BOUND`, `KERNEL`, `UNITY`, `SLOT_TIME_DECAY`, `INIT_TIME_DECAY`
  - `SLOT_VOLATILITY_TERM_STRUCTURE`, `SLOT_CURRENT_TICK`, `SLOT_MARKET_LIQUIDITY`
  - `SELECTOR_INIT_VOL_TERM_STRUCTURE`, `SELECTOR_GET_STATE_PARTITION_DELTA`

**Functions:**
- `camelCase` — `return_runtime`, `setDecay`, `timeDecay`, `swapAmount`, `gen_rand`, `minUsableTick`, `maxUsableTick`
- Note: `return_runtime` is the one idiom that uses `snake_case`; it is a fixed infrastructure constant present in every contract file
- Math library functions from `plankified-univ3` use `camelCase`: `getSqrtRatioAtTick`, `getTickAtSqrtRatio`, `mulDiv`, `divRoundingUp`

**Type aliases:**
- `PascalCase` — `Tick`, `NumberGroupSpec`, `NumberFormat`, `BoundedValue`, `VolatilityTermStructure`

**Local variables:**
- `camelCase` with descriptive names — `timeIndex`, `newDecay`, `sqrtPX96`, `absTick`, `tickLow`, `tickHi`
- Mutable variables require explicit `mut` annotation: `let mut ratio = ...`
- Prefixing with `_` signals that a local shadows or is a temporary: `let _poolLiquidity`, `let mut _tickSpacing`

**Parameters:**
- `camelCase` — `tickSpacing`, `timeIndex`, `sqrtPX96`, `liquidity`, `amount`

### Interface Files (`.plk`)

Files in `src/interfaces/` follow the Solidity `I`-prefix convention in their filename:
- `IMarketDynamics.plk` — contains `SELECTOR_INIT_VOL_TERM_STRUCTURE`
- `IMarketDynamicsLens.plk` — contains `SELECTOR_GET_STATE_PARTITION_DELTA`, `SELECTOR_GET_BASE_TICK`

Plank "interfaces" are not a language construct; they are files that export only ABI-selector constants (4-byte hex values). Incomplete selectors are left with a bare assignment `const SELECTOR_GET_STATE_PARTITION_DELTA =;` (intentionally unresolved at time of authoring — a WIP marker).

### Import Style

Plank uses a module-path import syntax:

```plank
import v3::util::{revert_empty, revert_with_return_data, revert_R, return_u256};
import v3::math::full_math::{mulDiv, mulDivRoundingUp};
import std::constructor:return_runtime;
import types::numerics::BoundedValue;
```

The `v3` namespace maps to the `plankified-univ3` library (`lib/plankified-univ3/plank/lib`), declared as a dependency in `BuildOptions`:

```solidity
deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
```

### NatSpec in Plank

NatSpec-style `///` doc comments are used selectively. They are most consistently applied in library/utility files with stable APIs:

```plank
/// @title TickUtils
/// @notice Tick helpers ported from Uniswap V4 `TickMath` ...
/// @dev Plank has no native signed or fixed-width integer types ...
/// @notice An `int24` tick encoded as a two's-complement value inside a `u256`.
/// @param tickSpacing The tick spacing (a positive `int24`).
/// @return The greatest multiple of `tickSpacing` that is >= MIN_TICK.
```

In `src/lib/TickUtils.plk`, full `@title`/`@notice`/`@dev`/`@param`/`@return` coverage is present. In other files (`SwapAmtGen.plk`, `BinomialProxy.plk`, `ReferenceMarket.plk`), doc comments are absent or limited to `// note:` inline comments. Upstream `plankified-univ3` uses `///` for function-level comments only (`@notice`, `@dev`).

### Error Handling in Plank

All revert paths are expressed through imported helper functions from `v3::util`:

```plank
revert_empty();            // revert with no data
revert_R();                // revert with "R" string (Uniswap error code)
revert_LOK();              // "LOK" locked error
revert_IIA();              // "IIA" invalid input amount
revert_L();                // "L" liquidity error
revert_SPL();              // "SPL" sqrt price limit error
revert_with_return_data(); // forward previous call's revert data
```

The pattern is: every `run {}` body ends with `revert_empty()` as a fallthrough for unrecognized selectors. View functions that diverge with `return_u256(...)` are typed `never` to signal they cannot return normally. State-mutating handlers call `@evm_return(ptr, 0)` directly after storing.

### Storage Slot Convention

Storage slots use `keccak256` of a namespaced string as the slot key, documented inline:

```plank
// keccak256("MARKET_STATE.VOLATILITY_TERM_STRUCTURE")
const SLOT_VOLATILITY_TERM_STRUCTURE = 0xaa65a296...;

// keccak256("...")
const SLOT_TIME_DECAY = 0xdf6c7b60...;
```

Small sequential slots (0–15 range) also appear for simple state variables (`SLOT_CURRENT_TICK = 7`, `SLOT_MARKET_LIQUIDITY = 10`).

### Selector Dispatch Pattern

Runtime dispatch in `run {}` is always:

```plank
run {
    let selector = @evm_shr(224, @evm_calldataload(0));
    if selector == 0x<4byte_hex> {
        // handle function
    } else if selector == 0x<4byte_hex> {
        // ...
    }
    revert_empty(); // or @evm_stop()
}
```

View functions and state-mutating functions are separated into `isView`, `handle_view`, `handle_state` constants when the contract has both kinds (pattern in `src/ReferenceMarket.plk`).

### Signed Integer Convention

Plank's only numeric primitive is `u256`. Signed integers (`int24` ticks) are stored as two's-complement values in `u256` and operated on with EVM signed builtins (`@evm_sdiv`, `@evm_slt`, `@evm_sar`, `@evm_sgt`). A `Tick` type alias documents this contract at the type level:

```plank
/// @notice An `int24` tick encoded as a two's-complement value inside a `u256`.
const Tick = u256;
```

Sign-extension for calldata values is performed manually: if the top bit of the 24-bit field is set, OR with a mask to sign-extend to 256 bits (see `src/ReferenceMarket.plk` line 61–62).

### Wrapping Arithmetic

Plank distinguishes wrapping operators (`*%`, `+%`, `-%`) from panicking operators (`*`, `+`, `-`). Wrapping is used whenever EVM-level modular arithmetic is intended (hash table indexing, fixed-point multiplication in `tick_math.plk`).

---

## Mathematical / Spec Conventions (`spec/` and `notes/STOCHASTIC_MODEL.md`)

### Spec Layer (`spec/protocol/entities/Types.md`)

The spec uses a custom pseudotype notation (not a formal language):

```
type TypeName { field: BoundedValue<Format, lo, hi>; }
type Alias is BaseType {}
type Generic<A, B> -> result {}
```

Numeric formats are named constants in a `DirectAddressMap`: `Natural`, `Rational`, `Q64.96`, `Q128.128`, `RAY`, `WAD`. `BoundedValue<NumberFormat, lowerBound, upperBound>` is the canonical bounded numeric type.

### notes/STOCHASTIC_MODEL.md Mathematical Notation

`notes/STOCHASTIC_MODEL.md` uses LaTeX-style inline math (`\[...\]`, `\(...\)`) with standard stochastic process notation:

- Greek: `\lambda_t` (arrival rate), `\sigma_{\Delta y}` (log-normal vol), `\bar{\Delta y}_t` (mean swap size)
- Process notation: `N_t | \lambda_t \sim \mathrm{Poisson}(\lambda_t)`, `\Delta y_{n,t} \sim \mathrm{LogNormal}(\mu_t, \sigma^2)`
- Indicator: `\mathbb{I}_{n,t} \in \{+1, -1\}` for buy/sell direction
- Deterministic proxy: `\Delta y(t) = 19 + 1.0001^{\eta t^4}`

The initial market state is always notated as a tuple:
`(di = 20, i = 100, i_l = -120, i_u = 120, L(i) = 1e18, Y = 100e18)`
where `di` = tickSpacing, `i` = current tick, `i_l`/`i_u` = range bounds, `L(i)` = liquidity, `Y` = cash stock.

### Backend Selection

The Plank backend is explicitly set to `'sona'` in test setup:

```solidity
opts.backend = 'sona';
```

The default in `PlankDeployer.sol` is `'sir-debug'`. Production use should always specify `'sona'` explicitly.

---

## Linting and Formatting

- **Solidity:** `forge fmt` is enforced in CI (`forge fmt --check` step in `.github/workflows/test.yml`)
- **Plank:** No formatter is configured in this project. The `plankc` monorepo has a linter with rules (`lib/plank-monorepo/plankc/.agents/lint-ai/LINT_RULES.md`) but it is not wired into CI here
- **CI:** `.github/workflows/test.yml` runs `forge fmt --check`, `forge build --sizes`, `forge test -vvv`

---

*Convention analysis: 2026-06-27*
