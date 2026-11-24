// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {
    PoolKey,
	PoolKeyPeriphery,
    Context,
	PoolId, PoolIdLibrary,
    IEnv,
	IMarketBuilder,
	IMarketLens,
	Currency
} from "@test/BaseTest.t.sol";

import {PlankTestBase} from "@test/PlankTestBase.sol";
import {ITickSpacing} from "@test/TickSpacing.t.sol";
import {IWindow} from "@test/Window.t.sol";

import {console2} from "forge-std/console2.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ControlContext} from "@test/ExecFrame/ExecFrame.t.sol";

interface ISysSetter{
    function setSys(address) external;
}

interface IStateObserverSetter {
    function setStateObserver(address) external;
}


uint256 constant MIN_WINDOW_LEN = 1;
contract LiveContext is CommonBase {
    bool marketKeySet;
    
    function globalContext() internal returns (Context memory ctx) {
	string memory json = vm.readFile(
					 "./foundry-scripts/out/deploy/global-context.json"
	);

	ctx.poolManager =
	    abi.decode(vm.parseJson(json, "$['pool-manager']"), (address));
	ctx.io = abi.decode(vm.parseJson(json, ".io"), (address));
	// TODO: This is tmp 
	ctx.args.windowLen = MIN_WINDOW_LEN;
	ctx.marketKey = marketKeySet ? marketKey() : emptyKey();
    }

    function marketKey() internal returns (PoolKey memory _marketKey) {

	// note: try is becuase globalContext queries before market.json is written
	string memory json = vm.readFile("./foundry-scripts/out/deploy/market.json");
	(address token0, address token1) = SortedAddresses(abi.decode(vm.parseJson(json, "$['underlying']"), (address)), abi.decode(vm.parseJson(json, "$['numeraire']"), (address)));
	_marketKey.currency0 = Currency.wrap(token0);
	_marketKey.currency1 = Currency.wrap(token1);
	_marketKey.tickSpacing = int24(int256(abi.decode(vm.parseJson(json, "$['tick-spacing']"), (uint256))));
	    // TODO: When premium rate is in include it, as well as hooks
   }
    
    function emptyKey() internal returns (PoolKey memory res) {}
    
    function SortedAddresses(address a1, address a2) internal returns(address sa1, address sa2) {
	(sa1,sa2) = (a1,a2);
	if (uint160(a1) > uint160(a2)) {
	    sa1 = a2;
	    sa2 = a1;
	}
    }

    function controlContext() internal returns (ControlContext memory ctx) {
	string memory json = vm.readFile(
					 "./foundry-scripts/out/deploy/control-context.json"
	);

	ctx.sys = abi.decode(vm.parseJson(json, ".sys"), (address));
	ctx.observer =
        abi.decode(vm.parseJson(json, "$['state-observer']"), (address));
    }

}
    
contract VolMarketsDeploy is Script, PlankTestBase, LiveContext {
    
    uint24 DEFAULT_TICK_SPACING = uint24(60);
    uint256 DEFAULT_WINDOW_LEN = 5;
    
    function deployBase() public {
	vm.serializeAddress("global-context", "pool-manager", 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543);
	vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	string memory global_json = vm.serializeAddress("global-context", "io", deployCode(compilePlank("src/Main.plk")));

	vm.writeJson(global_json, "./foundry-scripts/out/deploy/global-context.json");
	vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
        vm.serializeAddress("control-context", "sys", deployCode(compilePlank("src/sys/sys.plk")));
	vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	string memory control_json = vm.serializeAddress("control-context", "state-observer", deployCode(compilePlank("src/sys/observer.plk")));
	vm.writeJson(control_json, "./foundry-scripts/out/deploy/control-context.json");
    }
    

    function deployAndSetMarket() public {
	Context memory ctx = globalContext();
	ControlContext memory control_ctx = controlContext();
	console2.log("pmAddress",globalContext().poolManager);
	
	vm.startBroadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	IEnv(ctx.io).setPoolManager(ctx.poolManager);
	IEnv(control_ctx.sys).setIO(ctx.io);
	IEnv(control_ctx.sys).setPoolManager(ctx.poolManager);

	ISysSetter(ctx.io).setSys(control_ctx.sys);
	IStateObserverSetter(control_ctx.sys).setStateObserver(control_ctx.observer);
	
	address underlying = deployCode( compilePlank("src/utils/Token/Transfer.plk"));
	address numeraire = deployCode(compilePlank("src/utils/Token/Transfer.plk"));
	vm.serializeAddress("market", "underlying", underlying);
	vm.serializeAddress("market", "numeraire", numeraire);

	IMarketBuilder(ctx.io).setPair(underlying,numeraire,true);
	ITickSpacing(ctx.io).set_tick_spacing(DEFAULT_TICK_SPACING);
	vm.serializeUint("market", "tick-spacing", uint256(ITickSpacing(ctx.io).read_tick_spacing()));
	PoolKey memory marketKey = abi.decode(IMarketLens(ctx.io).getMarketKey(), (PoolKey));
	string memory market_json = vm.serializeBytes32("market", "market-id", PoolId.unwrap(PoolIdLibrary.toId(marketKey)));

	vm.writeJson(market_json,"./foundry-scripts/out/deploy/market.json");
	marketKeySet = true;
        PoolKeyPeriphery memory marketKeyPeriphery = abi.decode(IMarketLens(ctx.io).getMarketKey(), (PoolKeyPeriphery));

        ctx.marketKey = marketKey;
        ctx.marketKeyPeriphery = marketKeyPeriphery;

	IWindow(ctx.io).set_window(DEFAULT_WINDOW_LEN);
	
	vm.stopBroadcast();

    }

}
