// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
import {PlankDeployBase} from "./PlankDeployBase.s.sol";
import {PoolManager} from "univ4-core/PoolManager.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "univ4-core/types/PoolId.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";
import {HookMiner} from "utils/HookMiner.sol";

/// @notice Stands up the FULL dynamic-fee premium rig: a PoolManager, the Plank
/// DynamicFeeHook CREATE2-mined to a BEFORE_SWAP_FLAG address, a DYNAMIC_FEE pool bound to
/// it, and the hook one-shot-initialized (config + seeded vol buffer). After run(), the
/// printed (poolManager, hook, poolId) triple + the interfaces under src/interfaces/ are
/// everything the off-chain drivers need: swaps on the pool fire beforeSwap -> the hook
/// writes its vol buffer, prices the AdaptiveFee, emits FeeApplied/TimepointWritten with the
/// REAL poolId, and overrides the swap fee.
///
/// TOKEN NOTE: currencies default to two env-provided ERC20s (TOKEN0 < TOKEN1); absent env,
/// two fresh minimal mock tokens are deployed so the rig is self-contained on anvil.
contract DeployDynamicFeeHook is PlankDeployBase {
    using PoolIdLibrary for PoolKey;

    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint160 constant HOOK_FLAGS = uint160(Hooks.BEFORE_SWAP_FLAG);
    uint24 constant DYNAMIC_FEE_FLAG = 0x800000;
    // F2 (issue #17): 20, matching the VolOrder geometry pin (VolOrderValidationLib.plk
    // TICK_SPACING = 20) so the rig pool and the Panoptic leg-mint path agree. The hook is
    // tickSpacing-agnostic; InitSwappableRig.s.sol reconstructs the key with the SAME value.
    int24 constant TICK_SPACING = 20;
    int24 constant INIT_TICK = 0;

    function run() public returns (address hook, address manager, bytes32 poolIdOut) {
        uint256 pk = deployerKey();

        // Build the Plank initcode BEFORE broadcasting (FFI, no chain interaction), then
        // mine a salt so the CREATE2 proxy lands it on a BEFORE_SWAP_FLAG address.
        bytes memory initcode = plankBuildFFI("src/modules/protocol_integrations/DynamicFeeHook.plk", plankOpts());
        (address minedHook, bytes32 salt) = HookMiner.find(CREATE2_DEPLOYER, HOOK_FLAGS, initcode, "");

        vm.startBroadcast(pk);

        PoolManager pm = new PoolManager(vm.addr(pk));

        // CREATE2 proxy call: payload = salt || initcode.
        (bool okDeploy,) = CREATE2_DEPLOYER.call(abi.encodePacked(salt, initcode));
        require(okDeploy, "CREATE2 hook deploy failed");
        require(minedHook.code.length > 0, "hook has no code at mined address");

        (Currency c0, Currency c1) = _currencies();
        PoolKey memory key = PoolKey({
            currency0: c0,
            currency1: c1,
            fee: DYNAMIC_FEE_FLAG,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(minedHook)
        });
        bytes32 pid = PoolId.unwrap(key.toId());

        // ONE-SHOT hook init (research-only open init): manager + bound pool + default
        // Algebra config + seeded vol buffer at (INIT_TICK, now).
        (bool okInit,) = minedHook.call(
            abi.encodeWithSelector(
                bytes4(0xf8a75ae6), // initializeHook(address,bytes32,(uint16,...),int24,uint32)
                address(pm),
                pid,
                uint16(2900), uint16(12000), uint32(360), uint32(60000), uint16(59), uint16(8500), uint16(100),
                int24(INIT_TICK),
                uint32(block.timestamp)
            )
        );
        require(okInit, "initializeHook failed");

        pm.initialize(key, TickMath.getSqrtPriceAtTick(INIT_TICK));

        vm.stopBroadcast();

        hook = minedHook;
        manager = address(pm);
        poolIdOut = pid;

        console.log("PoolManager    :", manager);
        console.log("DynamicFeeHook :", hook);
        console.log("poolId         :", vm.toString(pid));
        console.log("currency0      :", Currency.unwrap(c0));
        console.log("currency1      :", Currency.unwrap(c1));
        console.log("tickSpacing    :", vm.toString(int256(TICK_SPACING)));
        console.log("E5 topic0      : 0x25ea110aac3c0d92bd950f999d2fafed41a751afe912d690a3e721a6eb5a84df");
    }

    function _currencies() internal returns (Currency c0, Currency c1) {
        address t0 = vm.envOr("TOKEN0", address(0));
        address t1 = vm.envOr("TOKEN1", address(0));
        if (t0 == address(0) || t1 == address(0)) {
            t0 = address(new MinimalToken());
            t1 = address(new MinimalToken());
        }
        (t0, t1) = t0 < t1 ? (t0, t1) : (t1, t0);
        c0 = Currency.wrap(t0);
        c1 = Currency.wrap(t1);
    }
}

/// @dev Self-contained rig token: mint-anyone ERC20-minimal (research rig only).
contract MinimalToken {
    string public constant name = "RigToken";
    string public constant symbol = "RIG";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        totalSupply += amt;
        balanceOf[to] += amt;
    }

    function approve(address s, uint256 amt) external returns (bool) {
        allowance[msg.sender][s] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address f, address to, uint256 amt) external returns (bool) {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= amt;
        balanceOf[f] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}
