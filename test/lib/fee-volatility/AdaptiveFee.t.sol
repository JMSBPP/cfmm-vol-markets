// SPDX-License-Identifier: MIT
// ^0.8.0 (not ^0.8.26): AdaptiveFee pins =0.8.20 (project convention, see MarketStatisticsTest).
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {AdaptiveFee} from "./refs/AdaptiveFee.sol"; // byte-identical vendored oracle (see the file header)
import {AlgebraFeeConfiguration} from "@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfiguration.sol";
import {
    AlgebraFeeConfigurationU144,
    AlgebraFeeConfigurationU144Lib
} from "@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfigurationU144.sol";

// Real AdaptiveFee (internal library) exposed for differential testing.
contract AFRef {
    function expXg4(uint256 x, uint16 g) external pure returns (uint256) {
        return AdaptiveFee.expXg4(x, g, uint256(g) ** 4);
    }

    function sigmoid(uint256 x, uint16 g, uint16 alpha, uint256 beta) external pure returns (uint256) {
        return AdaptiveFee.sigmoid(x, g, alpha, beta);
    }

    function pack(uint16 a1, uint16 a2, uint32 b1, uint32 b2, uint16 g1, uint16 g2, uint16 bf)
        external
        pure
        returns (uint256)
    {
        AlgebraFeeConfiguration memory cfg = AlgebraFeeConfiguration(a1, a2, b1, b2, g1, g2, bf);
        return AlgebraFeeConfigurationU144.unwrap(AlgebraFeeConfigurationU144Lib.pack(cfg));
    }

    function getFee(uint88 volatility, uint256 packedConfig) external pure returns (uint16) {
        return AdaptiveFee.getFee(volatility, AlgebraFeeConfigurationU144.wrap(uint144(packedConfig)));
    }

    function validate(uint16 a1, uint16 a2, uint32 b1, uint32 b2, uint16 g1, uint16 g2, uint16 bf)
        external
        pure
        returns (bool)
    {
        AdaptiveFee.validateFeeConfiguration(AlgebraFeeConfiguration(a1, a2, b1, b2, g1, g2, bf));
        return true;
    }

    function initialPacked() external pure returns (uint256) {
        return AlgebraFeeConfigurationU144.unwrap(AlgebraFeeConfigurationU144Lib.pack(AdaptiveFee.initialFeeConfiguration()));
    }
}

// The Plank AdaptiveFee port must be byte-identical to Algebra's.
contract AdaptiveFeeTest is PlankTestBase {
    address internal harness;
    AFRef internal ref;

    function setUp() public {
        harness = deployPlank("test/lib/fee-volatility/AdaptiveFeeHarness.plk");
        ref = new AFRef();
    }

    function _expXg4(uint256 x, uint16 g) internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("expXg4(uint256,uint16)", x, g));
        require(ok, "expXg4 reverted");
        return abi.decode(r, (uint256));
    }

    // exp_x_g4 == Algebra's expXg4 exactly over the sigmoid-relevant domain (x in [0, 6g), g in [1, u16]).
    function testFuzz_expXg4_matchesAlgebra(uint256 xR, uint16 gR) public {
        uint16 g = uint16(bound(gR, 1, type(uint16).max));
        uint256 x = bound(xR, 0, 6 * uint256(g)); // sigmoid guards x < 6g before calling
        assertEq(_expXg4(x, g), ref.expXg4(x, g), "exp_x_g4 == Algebra expXg4");
    }

    // golden anchors on the e^k table boundaries (x/g = 0,1,2 exactly) + a mid value.
    function test_expXg4_goldenTableBoundaries() public {
        assertEq(_expXg4(0, 59), ref.expXg4(0, 59), "x=0 -> e^0 branch");
        assertEq(_expXg4(59, 59), ref.expXg4(59, 59), "x/g=1 -> e^1 branch");
        assertEq(_expXg4(118, 59), ref.expXg4(118, 59), "x/g=2 -> e^2 branch");
        assertEq(_expXg4(30, 59), ref.expXg4(30, 59), "x/g~0.5 -> e^0.5 correction branch");
        assertEq(_expXg4(8500 * 5, 8500), ref.expXg4(8500 * 5, 8500), "x/g=5 -> default e^5 branch");
    }

    // ---- Increment 3: sigmoid ----

    function _sigmoid(uint256 x, uint16 g, uint16 alpha, uint256 beta) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("sigmoid(uint256,uint16,uint16,uint256)", x, g, alpha, beta));
        require(ok, "sigmoid reverted");
        return abi.decode(r, (uint256));
    }

    // sigmoid == Algebra exactly across both branches (x>beta / x<=beta) and both guards.
    function testFuzz_sigmoid_matchesAlgebra(uint256 xR, uint16 gR, uint16 alpha, uint32 beta) public {
        uint16 g = uint16(bound(gR, 1, type(uint16).max));
        // x spans below/above beta and beyond the +-6g guard bands
        uint256 x = bound(xR, 0, uint256(beta) + 12 * uint256(g) + 1);
        assertEq(_sigmoid(x, g, alpha, beta), ref.sigmoid(x, g, alpha, beta), "sigmoid == Algebra");
    }

    // guards + branches: x-beta >= 6g -> alpha ; beta-x >= 6g -> 0 ; and the two ratio branches.
    function test_sigmoid_goldenGuards() public {
        // upper guard: x well above beta => saturates to alpha
        assertEq(_sigmoid(60000 + 6 * 59, 59, 2900, 60000), 2900, "x-beta >= 6g -> alpha");
        assertEq(_sigmoid(60000 + 6 * 59, 59, 2900, 60000), ref.sigmoid(60000 + 6 * 59, 59, 2900, 60000), "== Algebra");
        // lower guard: x well below beta => 0
        assertEq(_sigmoid(0, 59, 2900, 60000), 0, "beta-x >= 6g -> 0");
        // mid, upper branch (x just above beta)
        assertEq(_sigmoid(60100, 8500, 12000, 60000), ref.sigmoid(60100, 8500, 12000, 60000), "upper ratio == Algebra");
        // mid, lower branch (x just below beta)
        assertEq(_sigmoid(59900, 8500, 12000, 60000), ref.sigmoid(59900, 8500, 12000, 60000), "lower ratio == Algebra");
    }

    // ---- Increment 4: get_fee (full dynamic fee) ----

    function _getFee(uint88 vol, uint256 packedConfig) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("getFee(uint88,uint256)", vol, packedConfig));
        require(ok, "getFee reverted");
        return abi.decode(r, (uint256));
    }

    // get_fee == Algebra getFee exactly over valid fuzzed configs (alpha1+alpha2+baseFee <= u16 max,
    // gammas != 0) and the full uint88 volatility range.
    function testFuzz_getFee_matchesAlgebra(
        uint88 volatility, uint16 a1R, uint16 a2R, uint32 b1, uint32 b2, uint16 g1R, uint16 g2R, uint16 bfR
    ) public {
        // valid config: gammas >= 1, alpha1+alpha2+baseFee <= 65535
        uint16 a1 = uint16(bound(a1R, 0, 20000));
        uint16 a2 = uint16(bound(a2R, 0, 20000));
        uint16 bf = uint16(bound(bfR, 0, 20000)); // sum <= 60000 < 65535
        uint16 g1 = uint16(bound(g1R, 1, type(uint16).max));
        uint16 g2 = uint16(bound(g2R, 1, type(uint16).max));
        uint256 c = ref.pack(a1, a2, b1, b2, g1, g2, bf);
        assertEq(_getFee(volatility, c), ref.getFee(volatility, c), "get_fee == Algebra getFee");
    }

    // golden: the /15 normalization + cap with Algebra's initialFeeConfiguration
    // (alpha1=2900, alpha2=12000, beta1=360, beta2=60000, gamma1=59, gamma2=8500, baseFee=100).
    function test_getFee_goldenInitialConfig() public {
        uint256 c = ref.pack(2900, 12000, 360, 60000, 59, 8500, 100);
        // low vol -> near baseFee; high vol -> near cap (baseFee+alpha1+alpha2 = 15000)
        assertEq(_getFee(0, c), ref.getFee(0, c), "vol=0 == Algebra");
        assertEq(_getFee(15 * 1000, c), ref.getFee(15 * 1000, c), "vol=15000 == Algebra");
        assertEq(_getFee(type(uint88).max, c), ref.getFee(type(uint88).max, c), "vol=max -> cap == Algebra");
        assertLe(_getFee(type(uint88).max, c), 15000, "fee capped at baseFee+alpha1+alpha2");
    }

    // ---- Increment 5 sub-step 1: validate_fee_configuration + initial_fee_configuration ----

    function _validate(uint16 a1, uint16 a2, uint32 b1, uint32 b2, uint16 g1, uint16 g2, uint16 bf)
        internal
        returns (bool ok)
    {
        (ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "validateConfig(uint16,uint16,uint32,uint32,uint16,uint16,uint16)", a1, a2, b1, b2, g1, g2, bf
            )
        );
    }

    function _initialPacked() internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("initialConfig()"));
        require(ok, "initialConfig reverted");
        return abi.decode(r, (uint256));
    }

    // validate accepts valid configs and reverts on gamma==0 / alpha1+alpha2+baseFee > u16 max, same as Algebra.
    function test_validate_matchesAlgebra() public {
        // valid
        assertTrue(_validate(2900, 12000, 360, 60000, 59, 8500, 100), "valid config passes");
        assertTrue(ref.validate(2900, 12000, 360, 60000, 59, 8500, 100), "valid passes (Algebra)");
        // gamma1 == 0 -> revert both
        assertFalse(_validate(2900, 12000, 360, 60000, 0, 8500, 100), "gamma1==0 reverts");
        try ref.validate(2900, 12000, 360, 60000, 0, 8500, 100) { revert("expected revert"); } catch {}
        // gamma2 == 0 -> revert
        assertFalse(_validate(2900, 12000, 360, 60000, 59, 0, 100), "gamma2==0 reverts");
        // alpha1+alpha2+baseFee > 65535 -> revert (30000+30000+6000 = 66000)
        assertFalse(_validate(30000, 30000, 360, 60000, 59, 8500, 6000), "sum > u16max reverts");
        try ref.validate(30000, 30000, 360, 60000, 59, 8500, 6000) { revert("expected revert"); } catch {}
        // sum exactly == 65535 passes
        assertTrue(_validate(30000, 30000, 360, 60000, 59, 8500, 5535), "sum == u16max passes");
    }

    // initial_fee_configuration packs identically to Algebra's initialFeeConfiguration
    function test_initial_matchesAlgebra() public {
        assertEq(_initialPacked(), ref.initialPacked(), "initial config == Algebra");
        // and equals the packed golden defaults (alpha1=2900,...,baseFee=100)
        assertEq(_initialPacked(), ref.pack(2900, 12000, 360, 60000, 59, 8500, 100), "== golden defaults");
    }
}
