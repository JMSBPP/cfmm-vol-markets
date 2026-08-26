# Testing Patterns

**Analysis Date:** 2026-06-27

## Test Framework

**Runner:**
- Foundry / Forge (version pinned by `foundry.lock`)
- Config: `foundry.toml`

**Assertion Library:**
- Forge `std` DSTest assertions (`assertEq`, `assertTrue`, `assertGt`, `assertApproxEqRel`)

**Run Commands:**
```bash
forge test -vvv          # Run all tests (CI uses this)
forge test --watch       # Watch mode (not configured, use manually)
forge coverage           # Coverage (not configured in CI)
forge build --sizes      # Build with size output (CI step)
```

**Fuzz Configuration:**
```toml
[fuzz]
runs = 10
fail_on_revert = false
```

`runs = 10` is a very low count — intentionally low for development speed. `fail_on_revert = false` means fuzz runs that revert are not counted as failures (needed because Plank contracts revert on unrecognized selectors).

---

## Test File Organization

**Location:**
- All test files co-located in `test/` directory (not alongside source)
- `.plk` source in `src/`, test harnesses in `test/`

**Naming:**
- Solidity test files: `<Name>.t.sol` — `Utils.t.sol`, `LiquidityDensityFunctionPlankTest.t.sol`
- Test contract naming: `<Subject>Test` — `UtilsTest`, `LiquidityDensityFunctionPlankTest`
- No `Test` prefix on contract names (suffix only)

**Structure:**
```
test/
├── Utils.t.sol                          # Base test utility contract + integration tests
└── LiquidityDensityFunctionPlankTest.t.sol  # LDF fuzz test suite stub
```

The project does not have a `test/` subdirectory hierarchy yet. There is one output artifact `out/Utils.t.sol` generated from compilation (not a test file).

---

## Test Contract Architecture

### Inheritance Pattern

Test contracts use multiple inheritance to compose base utilities with upstream abstract test suites:

```solidity
// Pattern 1: Base utility contract (used by other tests)
contract UtilsTest is Test, PlankDeployer { ... }

// Pattern 2: Concrete Plank LDF test
contract LiquidityDensityFunctionPlankTest is PlankDeployer, LiquidityDensityFunctionTest { ... }
```

`LiquidityDensityFunctionTest` (from `bunni-v2/test/ldf/LiquidityDensityFunctionTest.sol`) is an abstract base contract that defines the standard LDF test interface. The `LiquidityDensityFunctionPlankTest` overrides `_setUpLDF()` to deploy a Plank-compiled LDF contract.

### setUp Pattern

Every test contract implements `setUp()` as a public or internal function. The lifecycle is:

1. Deploy Plank contracts via FFI in `setUp` — `plankDeployFFI("src/....plk", opts)`
2. Initialize fork: attempt mainnet fork, fall back to local chain
3. Initialize contract state via selector-encoded calls

```solidity
function setUp() public {
    opts.backend = "sona";
    Dependency[] memory deps = new Dependency[](1);
    deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
    opts.dependencies = deps;

    _bootstrapChain();

    RAND_GEN = plankDeployFFI("src/lib/BinomialProxy.plk", opts);
    CASH_FLOW_GEN = plankDeployFFI("src/lib/SwapAmtGen.plk", opts);
    REFERENCE_MARKET = plankDeployFFI("src/ReferenceMarket.plk", opts);
    if (isForked) {
        vm.makePersistent(RAND_GEN, CASH_FLOW_GEN, REFERENCE_MARKET);
    }

    state = init_state();
}
```

The `BuildOptions` struct is configured once in `setUp` and reused across all `plankDeployFFI` calls.

---

## Plank Contract Deployment in Tests

Tests interact with Plank contracts via `PlankDeployer` (from `lib/plank-foundry-deployer/src/PlankDeployer.sol`). This contract uses Foundry's `ffi` cheatcode to invoke `plank build` and deploy the resulting bytecode:

```solidity
// Deploy a Plank contract from source file path
address addr = plankDeployFFI("src/lib/BinomialProxy.plk", opts);

// Call a Plank contract using raw selector + ABI encoding
(bool succ, bytes memory data) = RAND_GEN.call(abi.encodeWithSignature("ping()"));

// Or via LibCall for more ergonomic encoding
LibCall.callContract(REFERENCE_MARKET, ZERO_VALUE, abi.encodeWithSelector(selector, value));
bytes memory result = LibCall.staticCallContract(REFERENCE_MARKET, abi.encodeWithSelector(selector));
```

Because Plank contracts have no ABI metadata, all calls are made via explicit 4-byte selectors stored as `bytes4` constants in the test:

```solidity
bytes4 constant SEL_SET_POOL_LIQUIDITY = 0x08a68255; // setPoolLiquidity(uint256)
bytes4 constant SEL_POOL_LIQUIDITY     = 0x3b228b3e; // poolLiquidity()
bytes4 constant SEL_SET_TICK_SPACING   = 0x0693ca3b; // setTickSpacing(uint256)
```

`ffi = true` must be set in `foundry.toml` for `plankDeployFFI` to work.

---

## Fork Testing Pattern

Tests support both mainnet-forked and local-chain modes with a graceful fallback:

```solidity
function _bootstrapChain() internal {
    try vm.createSelectFork(vm.rpcUrl("mainnet")) returns (uint256 _forkId) {
        forkId = _forkId;
        vm.rollFork(INIT_BLOCK);
        isForked = true;
    } catch {
        console2.log("Unable to fork mainnet; using local chain");
        isForked = false;
        vm.roll(INIT_BLOCK);
        vm.prevrandao(uint256(keccak256("local-utils-test-seed")));
    }
}
```

Key block numbers are stored as named constants:
- `INIT_BLOCK = 25_298_856` — starting block for the test scenario
- `REFERENCE_BLOCK = 25_390_770` — upper bound for block-delta fuzzing

Forked contracts are made persistent across fork switches with `vm.makePersistent(...)`. Block progression is simulated with `vm.rollFork(forkId, block + delta)` or `vm.roll(block + delta)`.

`prevrandao` toggling is used to control the output of `BinomialProxy.plk` (which reads `block.difficulty` / `block.prevrandao` to generate a binary random sample):

```solidity
function _rollBlocks(uint256 delta) internal {
    ...
    vm.prevrandao(prevDifficulty ^ 1);  // flip parity → binomial flips 0 ↔ 1
    prevDifficulty = block.prevrandao;
}
```

---

## Fuzz Testing

### Foundry Native Fuzz

Fuzz tests use Foundry's built-in property-based fuzzer. Any `test_*` function with parameters is automatically fuzzed:

```solidity
// In test/Utils.t.sol
function test_differentValuesTimeDimension(uint256 deltaBlock) public {
    uint256 effectiveDelta = bound(deltaBlock, 1, REFERENCE_BLOCK - INIT_BLOCK);
    ...
}

// In test/LiquidityDensityFunctionPlankTest.t.sol
function test_liquidityDensity_sumUpToOne(
    int24 tickSpacing,
    int24 minTick,
    int24 length,
    uint256 alpha
) external virtual { ... }
```

**`bound()`** is used for clamping fuzz inputs into valid ranges — not `vm.assume()` (which discards runs). `vm.assume()` is used only for single-value exclusions:

```solidity
alpha = bound(alpha, MIN_ALPHA, MAX_ALPHA);
vm.assume(alpha != 1e8); // 1e8 is a special case that causes overflow
tickSpacing = int24(bound(tickSpacing, MIN_TICK_SPACING, MAX_TICK_SPACING));
```

### Fuzz Test Naming

Fuzz tests follow the same `test_` prefix convention. There is no separate naming to distinguish fuzz vs unit tests. Fuzz tests are distinguished only by having function parameters.

---

## Test Function Naming

Functions follow the pattern: `test_<subject>[_<scenario>]`

Examples:
```solidity
test_differentValuesTimeDimension(uint256 deltaBlock)   // fuzz
test__initStateSucceed()                                 // unit (double underscore)
test__swapAmountsCorrect(uint256 deltaBlock)             // fuzz (double underscore)
test_liquidityDensity_sumUpToOne(...)                    // fuzz
test_query_cumulativeAmounts(...)                        // fuzz
test_inverseCumulativeAmount0(...)                       // fuzz
test_inverseCumulativeAmount1(...)                       // fuzz
test_boundary_static_invalidWhenOutOfBounds(...)         // fuzz
test_boundary_dynamic_boundedWhenDecoding(...)           // fuzz
```

The double-underscore `test__` prefix appears to denote setup/state verification tests. The `test_<noun>_<adjective>` pattern (`test_boundary_static_invalidWhenOutOfBounds`) is used for property/boundary tests, not the BTT (Branching Tree Technique) format. No BTT `.tree` files or `when_`/`given_` subdirectories exist.

---

## Invariant / BTT / Spec-Driven Testing

### Invariant Tests

No Foundry invariant tests (`invariant_*` prefix, `targetContract`) are present in `test/`.

### BTT (Branching Tree Technique)

No BTT test trees are present. There is no `test/` subdirectory structure with `when_`/`given_` naming, and no `.tree` spec files. The `evm-tdd` skill ecosystem and `spec/` directory exist but are not wired to test generation.

### `spec/` Directory

`spec/protocol/entities/Types.md` contains a domain-model type specification written in informal pseudocode. It defines `NumberFormat`, `BoundedValue`, `VolatilityTermStructure`, `VolatilityGrid`, and `VolatilityGridLens` with notational constraints. This spec is used to guide Plank type definitions (see `src/types/Numerics.plk`, `src/types/VolatilityTermStructure.plk`) but is not processed by any test framework. It is a design artifact, not executable.

---

## Abstract Base Tests (Upstream Pattern)

The `LiquidityDensityFunctionTest` from `bunni-v2/test/ldf/LiquidityDensityFunctionTest.sol` is an abstract base contract that defines:

```solidity
abstract contract LiquidityDensityFunctionTest is Test {
    function _setUpLDF() internal virtual;
    function _test_liquidityDensity_sumUpToOne(...) internal view { ... }
    function _test_query_cumulativeAmounts(...) internal view virtual { ... }
    // ...
}
```

Concrete subclasses override `_setUpLDF()` to inject the LDF implementation (Solidity or Plank). This pattern allows testing multiple LDF implementations against the same property suite. The Plank version (`test/LiquidityDensityFunctionPlankTest.t.sol`) provides stub implementations for all virtual fuzz tests — the test bodies are currently empty (`{ }`), meaning the suite is wired but not yet implemented.

---

## Coverage

**Requirements:** None enforced. No coverage threshold in `foundry.toml` or CI.

**View Coverage:**
```bash
forge coverage
```

Coverage is not run in CI (`.github/workflows/test.yml` only runs `forge test -vvv`).

---

## Logging in Tests

`console2` is used for debug logging in tests:

```solidity
import {console2} from "forge-std/console2.sol";

console2.log("prev binomial", fromContractPrev);
console2.log("Unable to fork mainnet; using local chain");
```

CI uses `-vvv` verbosity, so `console2.log` output is visible on test failure but suppressed on success.

---

## Test Types Summary

| Type | Present | Files |
|------|---------|-------|
| Unit tests | Yes | `test/Utils.t.sol` |
| Fuzz tests | Yes (stub bodies in LDF) | `test/LiquidityDensityFunctionPlankTest.t.sol`, `test/Utils.t.sol` |
| Fork tests | Yes | `test/Utils.t.sol` |
| Invariant tests | No | — |
| BTT tests | No | — |
| E2E tests | No | — |
| Differential tests | Intended | `test/LiquidityDensityFunctionPlankTest.t.sol` (vs Solidity LDF) |

---

*Testing analysis: 2026-06-27*
