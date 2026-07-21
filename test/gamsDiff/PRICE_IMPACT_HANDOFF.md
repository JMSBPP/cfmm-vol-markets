# Price-Impact Differential Gateway — Handoff to the diff-test author

**From:** gamsdiff session (branch `feat/gamsdiff`, pushed to origin).
**Status:** Gateway READY and offline-VERIFIED. The Foundry `.diff.t.sol` is yours to implement;
everything it consumes is committed on this branch and confirmed correct.

## What this gateway gives you

Diff the GAMS price-impact kernel (post-trade sqrt price, η=1/2) against the on-chain
Uniswap V3 `getNextSqrtPriceFromAmount0RoundingUp` — the building block under `CESLongPayoff`.

### 1. Fixture (committed)
`test/gamsDiff/fixtures/price_impact_kernel.json` — 723 rows (1 spacing × 241 ticks × 3 dx), η=1/2.

| field | type | meaning |
|-------|------|---------|
| `count` | int | 723 |
| `eta` | number | 0.5 (the only EVM-testable weight) |
| `add` | bool | true (token0-input, rounding-up path) |
| `liquidity` | decimal string | 1e18 (uint128 `L̄`) |
| `scale` | string | "Q64.96" |
| `ticks` | int[723] | int24 tick (−120..120), 3 rows per tick |
| `sqrtPX96In` | string[723] | input sqrt price `P_{1/2}(i)` (uint160) |
| `amount0In` | string[723] | input `Δ^I` (uint256): 1e15 / 1e17 / 1e18 |
| `expectedSqrtPriceX96` | string[723] | GAMS post-trade sqrt price (uint256) |

All uint values are **decimal strings** (verified to coerce on forge-std v1.16.1 `parseJsonUintArray`).

### 2. Harness (committed)
`test/gamsUtils/PriceImpactKernelHarness.plk` — pure reader, deploy via `plankDeployFFI` (backend
`"sona"`, dep `v3=lib/plankified-univ3/plank/lib`), exactly like `PriceKernelHarness`.
- ABI: `getNextSqrtPriceFromAmount0RoundingUp(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add) returns (uint256)`
- Selector: `0x157f652f` · calldata words at offsets 4/36/68/100.

### 3. Tolerance — VERIFIED
Use `assertApproxEqRel(actual, expected, EPS)` with **`EPS = 1e3`** (= `1e-15` relative).

I ran an exact-integer EVM replica of `getNextSqrtPriceFromAmount0RoundingUp(add=true)` —
`ceil((L<<96)·sqrtP / ((L<<96) + amount·sqrtP))` — over all 723 fixture rows:
```
rows=723  max_rel_error=2.021e-16  rows_over_EPS(1e-15)=0  headroom=4.9x
worst: tick 60, amount0In 1e18  (actual 3.9673499363600704e28 vs expected ...712e28)
sanity tick0/1e17: actual < 2^96  ✓   |   post-trade < pre-trade for ALL rows  ✓   |   no uint160 overflow
VERDICT: PASS
```
(Note: the GAMS-side spec §D9 suggested 1e-12; I tightened to 1e-15 for stronger regression
detection — the measured floor is 2.02e-16, so it passes with ~5× headroom. Loosen only with
recorded evidence.)

### 4. Casts / scales (safe)
`uint160(sqrtPX96In[i])` (max ~8e28 ≤ 2^160), `uint128(liquidity)` (1e18 ≤ 2^128); `dx·sqrtP ≈ 8e46 ≪ 2^256`
(no overflow / no `add=false` revert path on this grid).

## Build prerequisites (your host, not this worktree)
This worktree leaves submodules uninitialized, so forge can't run here. On the build host / sol-tests
worktree:
- `git submodule update --init --recursive` (needs `plankified-univ3` for `v3::math::sqrt_price_math`,
  and the `bunni-v2`/solady chain for `LibCall`).
- `remappings.txt` must map `v3=`, `bunni-v2=`, `plank-foundry-deployer=`.
- `foundry.toml` already grants `fs_permissions` read for `./test/gamsDiff/fixtures`.

## Reference test (yours to adopt/adapt — you own this file)
`test/gamsDiff/PriceImpactKernelPlank.diff.t.sol`:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";

/// @title PriceImpactKernelPlankdiffTest
/// @notice Diffs the GAMS price-impact kernel (post-trade sqrt price, eta=1/2) against the
///         on-chain Uniswap V3 getNextSqrtPriceFromAmount0RoundingUp (add=true, token0-input).
contract PriceImpactKernelPlankdiffTest is Test, PlankDeployer {
    bytes4 constant SEL = 0x157f652f; // getNextSqrtPriceFromAmount0RoundingUp(uint160,uint128,uint256,bool)
    uint256 constant EPS = 1e3;       // 1e-15 relative; measured floor ~2.02e-16
    uint256 constant TWO_96 = 79228162514264337593543950336;

    address public HARNESS;

    function setUp() public {
        BuildOptions memory opts;
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](1);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        opts.dependencies = deps;
        HARNESS = plankDeployFFI("test/gamsUtils/PriceImpactKernelHarness.plk", opts);
    }

    function _next(uint160 sqrtP, uint128 L, uint256 amount, bool add) internal view returns (uint256) {
        return abi.decode(
            LibCall.staticCallContract(HARNESS, abi.encodeWithSelector(SEL, sqrtP, L, amount, add)),
            (uint256)
        );
    }

    function test_PriceImpact_matches_getNextSqrtPriceFromAmount0RoundingUp() public view {
        string memory json = vm.readFile("test/gamsDiff/fixtures/price_impact_kernel.json");
        int256[] memory ticks = vm.parseJsonIntArray(json, ".ticks");
        uint256[] memory sqrtPIn = vm.parseJsonUintArray(json, ".sqrtPX96In");
        uint256[] memory amount0In = vm.parseJsonUintArray(json, ".amount0In");
        uint256[] memory expected = vm.parseJsonUintArray(json, ".expectedSqrtPriceX96");
        uint256 liquidity = vm.parseJsonUint(json, ".liquidity");
        assertEq(ticks.length, 723);
        assertEq(sqrtPIn.length, 723);
        assertEq(amount0In.length, 723);
        assertEq(expected.length, 723);

        bool sawSanity;
        for (uint256 i = 0; i < ticks.length; i++) {
            uint256 actual = _next(uint160(sqrtPIn[i]), uint128(liquidity), amount0In[i], true);
            assertApproxEqRel(actual, expected[i], EPS);
            if (ticks[i] == 0 && amount0In[i] == 1e17) {
                assertLt(actual, TWO_96, "tick0 medium-dx post-trade price should be < 2^96");
                sawSanity = true;
            }
        }
        assertTrue(sawSanity, "sanity row (tick 0, dx=1e17) not found");
    }
}
```

## Regenerating the fixture (gamsdiff session owns this)
`make gams-fixtures-impact` is not yet wired; for now: `uv run --project tools/gamsdiff gamsdiff-impact`
(needs GAMS 54.1 + the merged `model/PriceImpactKernelFixture.gms`). The fixture is platform-pinned.

## Provenance
- Spec: `docs/superpowers/specs/2026-06-28-price-impact-diff-gateway-design.md`
- Plan: `docs/superpowers/plans/2026-06-28-price-impact-diff-gateway.md`
- GAMS side: PR #1 (feat/gams → develop); GAMS handoff in `../cfmm-wt/gams/.superpowers/sdd/handoff-to-gamsdiff.md`.
- Ping the gamsdiff session if the schema/tolerance needs adjustment before you build against it.
