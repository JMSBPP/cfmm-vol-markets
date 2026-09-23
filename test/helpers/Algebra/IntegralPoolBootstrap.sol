// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Vm} from "forge-std/Vm.sol";
import {FlowToken} from "test/mocks/FlowToken.sol";
import {AlgebraIntegralDeployer} from "test/helpers/Algebra/AlgebraIntegralDeployer.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/interfaces/IAlgebraFactory.sol";
import {IAlgebraPool} from "@cryptoalgebra/integral-core/interfaces/IAlgebraPool.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";

/// @title IntegralPoolBootstrap
/// @notice **Integration bootstrap** — test helper that composes bytecode deploy, token
///         fixtures, and on-chain pool lifecycle (create + initialize) into one ready state.
/// @dev Category (under `test/helpers/Algebra/`):
///      - **Deployer** — pinned bytecode only (`AlgebraIntegralDeployer`).
///      - **Integration bootstrap** — deployer + custom init transactions (this module).
///      - **Plank helper** — `.plk` stubs/callbacks (`NoOpCallback.plk`, etc.).
///      Not a BTT; not imported by production code. Clients read `ReadyPool` after `bootstrap`.
library IntegralPoolBootstrap {
    /// @dev Addresses and pool parameters after `initialize`; safe for mint-style tests.
    struct ReadyPool {
        address entryPoint;
        address pool;
        address token0;
        address token1;
        uint256 fee;
        uint256 tickSpacing;
    }

    /// @dev 1:1 token ratio at tick 0 (`sqrtPriceX96 = 2^96`).
    uint160 internal constant DEFAULT_INITIAL_PRICE = 79228162514264337593543950336;

    function bootstrap(Vm vm) public returns (ReadyPool memory ready) {
        return bootstrapWithPrice(vm, DEFAULT_INITIAL_PRICE);
    }

    function bootstrapWithPrice(Vm vm, uint160 initialPrice) public returns (ReadyPool memory ready) {
        FlowToken tokenA = new FlowToken();
        FlowToken tokenB = new FlowToken();
        address t0;
        address t1;
        if (address(tokenA) < address(tokenB)) {
            t0 = address(tokenA);
            t1 = address(tokenB);
        } else {
            t0 = address(tokenB);
            t1 = address(tokenA);
        }

        AlgebraIntegralDeployer.Deployment memory d = AlgebraIntegralDeployer.deploy(vm);
        ready.entryPoint = d.entryPoint;
        ready.pool = IAlgebraFactory(d.factory).createPool(t0, t1, new bytes(0));
        require(ready.pool != address(0), "createPool failed");
        IAlgebraPool(ready.pool).initialize(initialPrice);

        (, , uint16 fee,, ,) = IAlgebraPoolState(ready.pool).globalState();
        int24 spacing = IAlgebraPoolState(ready.pool).tickSpacing();
        ready.fee = fee;
        ready.tickSpacing = uint256(int256(spacing));
        ready.token0 = t0;
        ready.token1 = t1;
    }
}
