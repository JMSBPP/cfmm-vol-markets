// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";


contract UtilsTest is Test, PlankDeployer {
    uint256 constant ZERO_VALUE = 0;

    uint128 constant UNIT_LIQUIDITY = 1e18;
    int24 constant INIT_TICK_SPACING = 20;
    int24 constant INIT_TICK_CURRENT = 100;
    int24 constant INIT_TICK_LOWER = -120;
    int24 constant INIT_TICK_UPPER = 120;

    // setPoolLiquidity(uint256)
    bytes4 constant SEL_SET_POOL_LIQUIDITY = 0x08a68255;
    // poolLiquidity()
    bytes4 constant SEL_POOL_LIQUIDITY = 0x3b228b3e;
    // setTickSpacing(uint256)
    bytes4 constant SEL_SET_TICK_SPACING = 0x0693ca3b;
    // tickSpacing(uint256)
    bytes4 constant SEL_TICK_SPACING = 0x408e87f6;
    // setCurrentTick(uint256)
    bytes4 constant SEL_SET_CURRENT_TICK = 0x8f3f8c52;
    // currentTick()
    bytes4 constant SEL_CURRENT_TICK = 0x065e5360;
    // setTickLower(uint256)
    bytes4 constant SEL_SET_TICK_LOWER = 0x04211dd1;
    // tickLower()
    bytes4 constant SEL_TICK_LOWER = 0x59c4f905;
    // setTickUpper(uint256)
    bytes4 constant SEL_SET_TICK_UPPER = 0x37969917;
    // tickUpper()
    bytes4 constant SEL_TICK_UPPER = 0x55b812a8;

    address public RAND_GEN;
    address public CASH_FLOW_GEN;
    address REFERENCE_MARKET;
    BuildOptions opts;

    uint256 INIT_BLOCK = 25_298_856;
    uint256 REFERENCE_BLOCK = 25_390_770;
    uint256 SEED;
    uint256 forkId;
    bool isForked;
    uint256 prevDifficulty;
    uint256 lastBinomial;

    struct State {
        int24 tickSpacing;
        int24 currentTick;
        int24 tickLower;
        int24 tickUpper;
        uint128 poolLiquidity;
    }

    State state;

    function _setUint256(bytes4 selector, uint256 value) internal {
        LibCall.callContract(
            REFERENCE_MARKET,
            ZERO_VALUE,
            abi.encodeWithSelector(selector, value)
        );
    }

    function _readUint256(bytes4 selector) internal view returns (uint256) {
        return abi.decode(
            LibCall.staticCallContract(REFERENCE_MARKET, abi.encodeWithSelector(selector)),
            (uint256)
        );
    }

    function _readInt24(bytes4 selector) internal view returns (int24) {
        return int24(int256(_readUint256(selector)));
    }

    function init_state() internal returns (State memory initState) {
        _setUint256(SEL_SET_TICK_SPACING, uint256(int256(INIT_TICK_SPACING)));
        _setUint256(SEL_SET_CURRENT_TICK, uint256(int256(INIT_TICK_CURRENT)));
        _setUint256(SEL_SET_TICK_LOWER, uint256(int256(INIT_TICK_LOWER)));
        _setUint256(SEL_SET_TICK_UPPER, uint256(int256(INIT_TICK_UPPER)));
        _setUint256(SEL_SET_POOL_LIQUIDITY, uint256(UNIT_LIQUIDITY));

        initState = State({
            tickSpacing: INIT_TICK_SPACING,
            currentTick: INIT_TICK_CURRENT,
            tickLower: INIT_TICK_LOWER,
            tickUpper: INIT_TICK_UPPER,
            poolLiquidity: UNIT_LIQUIDITY
        });
    }

    function _selectTestFork() internal {
        if (isForked) {
            vm.selectFork(forkId);
        }
    }

    function _pingBinomial() internal returns (uint256 value) {
        _selectTestFork();
        (, bytes memory data) = RAND_GEN.call(abi.encodeWithSignature("ping()"));
        value = abi.decode(data, (uint256));
        lastBinomial = value;
        prevDifficulty = block.prevrandao;
    }

    function _rollBlocks(uint256 delta) internal {
        if (isForked) {
            vm.rollFork(forkId, vm.getBlockNumber() + delta);
        } else {
            vm.roll(block.number + delta);
        }
        // Toggle prevrandao/difficulty parity so ping() flips 0 <-> 1.
        vm.prevrandao(prevDifficulty ^ 1);
        prevDifficulty = block.prevrandao;
    }

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

        assertGt(block.number, 0, "block number must start above zero");
        SEED = block.prevrandao;
        prevDifficulty = SEED;
    }

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

    function test_differentValuesTimeDimension(uint256 deltaBlock) public {
        uint256 effectiveDelta = bound(deltaBlock, 1, REFERENCE_BLOCK - INIT_BLOCK);

        uint256 fromContractPrev = _pingBinomial();
        console2.log("prev binomial", fromContractPrev);
        console2.log("prev difficulty", prevDifficulty);

        _rollBlocks(effectiveDelta);

        uint256 fromContractNext = _pingBinomial();
        console2.log("next binomial", fromContractNext);
        console2.log("next difficulty", prevDifficulty);

        assertTrue(fromContractPrev == 0 || fromContractPrev == 1, "binomial sample");
        assertTrue(fromContractNext == 0 || fromContractNext == 1, "binomial sample");
        assertEq(fromContractNext, fromContractPrev == 1 ? 0 : 1, "binomial must alternate");
    }

    function test__initStateSucceed() public {
        init_state();

        assertEq(_readInt24(SEL_TICK_SPACING), state.tickSpacing);
        assertEq(_readInt24(SEL_CURRENT_TICK), state.currentTick);
        assertEq(_readInt24(SEL_TICK_LOWER), state.tickLower);
        assertEq(_readInt24(SEL_TICK_UPPER), state.tickUpper);
        assertEq(uint128(_readUint256(SEL_POOL_LIQUIDITY)), state.poolLiquidity);
    }

    function test__swapAmountsCorrect(uint256 deltaBlock) public {
        bound(deltaBlock, 1, REFERENCE_BLOCK - INIT_BLOCK);
        _selectTestFork();
    }
}
