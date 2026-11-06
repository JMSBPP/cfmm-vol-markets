// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SemiFungiblePositionManagerV4} from "panoptic-v2-core/contracts/SemiFungiblePositionManagerV4.sol";
import {LiquidityChunk, LiquidityChunkLibrary} from "panoptic-v2-core/contracts/types/LiquidityChunk.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TokenId} from "panoptic-v2-core/contracts/types/TokenId.sol";
import {LeftRightSigned, LeftRightUnsigned} from "panoptic-v2-core/contracts/types/LeftRight.sol";
import {Errors} from "panoptic-v2-core/contracts/libraries/Errors.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

/// @dev Single deployed contract = Draft + SFPM. Seed and createLeg both `unlock` as
///      `address(this)`, so Uniswap V4 positions are owned by this contract (not an external CREATE).
contract CreateLegHarness is SemiFungiblePositionManagerV4 {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    uint24 internal constant FEE = 500;
    int24 internal constant TICK_SPACING = 200;
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint128 internal constant DEFAULT_LIQUIDITY = 100e18;
    uint8 internal constant VEGOID = 2;
    uint256 internal constant LEG = 1;
    /// @dev tokenType 1 = CALL (token1)
    uint256 internal constant TOKEN_TYPE_CALL = 1;
    // Must sit inside SFPM enforced tick bounds (vegoid-dependent; ~±518738 for vegoid=2).
    int24 internal constant TICK_LOWER = -500000;
    int24 internal constant TICK_UPPER = 500000;

    Currency public currency0;
    Currency public currency1;
    PoolId public poolId;
    PoolKey public poolKey;
    uint64 public panopticPoolId;

    constructor(IPoolManager manager)
        SemiFungiblePositionManagerV4(manager, 2100000000000000000000, 2100000000000000000000, 10000)
    {}

    /// @dev PoolManager is immutable in SFPM ctor; kept for Draft.plk / test ABI compatibility.
    function setPoolManager(address) external {}

    /// @notice Deploy two Transfer fake-ERCs from Plank initcode, init V4 pool + SFPM pool mapping.
    function initialize(bytes memory transferInitcode) external {
        address a = _deploy(transferInitcode);
        address b = _deploy(transferInitcode);
        if (uint160(a) > uint160(b)) (a, b) = (b, a);
        currency0 = Currency.wrap(a);
        currency1 = Currency.wrap(b);
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });
        poolId = poolKey.toId();
        POOL_MANAGER_V4.initialize(poolKey, SQRT_PRICE_1_1);
        panopticPoolId = this.initializeAMMPool(poolKey, VEGOID);
    }

    function getLiquidity() external view returns (uint128) {
        return POOL_MANAGER_V4.getLiquidity(poolId);
    }

    /// @notice Test-only ledger credit (right slot = sold liquidity).
    function setAccountLiquidity(bytes32 positionKey, uint128 soldLiquidity) external {
        s_accountLiquidity[positionKey] = LeftRightUnsigned.wrap(soldLiquidity);
    }

    function getAccountLiquidity(bytes32 positionKey) external view returns (LeftRightUnsigned) {
        return s_accountLiquidity[positionKey];
    }

    /// @dev Empty call / unknown selector → seed full-range short LP on *this* (owner = this).
    fallback() external {
        _createLegOnSelf(_shortTokenId(), false);
    }

    /// @notice Long CALL burn on *this*. `bytes` ignored (no external SFPM CREATE).
    function createLeg(bytes calldata)
        external
        returns (LeftRightSigned moved, LeftRightUnsigned collectedSingleLeg)
    {
        return _createLegOnSelf(_longCallTokenId(), false);
    }

    function createLeg(
        address acct,
        PoolKey memory key,
        TokenId tokenId,
        LiquidityChunk liquidityChunk
    ) public returns (LeftRightSigned moved, LeftRightUnsigned collectedSingleLeg) {
        return abi.decode(
            POOL_MANAGER_V4.unlock(abi.encode(acct, key, tokenId, liquidityChunk)),
            (LeftRightSigned, LeftRightUnsigned)
        );
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(POOL_MANAGER_V4)) revert Errors.UnauthorizedUniswapCallback();
        (address acct, PoolKey memory key, TokenId tokenId, LiquidityChunk liquidityChunk) =
            abi.decode(data, (address, PoolKey, TokenId, LiquidityChunk));

        (LeftRightSigned moved, LeftRightUnsigned collectedSingleLeg) =
            _createLegInAMM(acct, key, tokenId, LEG, liquidityChunk, false, VEGOID);

        // Mirror SFPM._createPositionInAMM settlement (ERC-6909 claims).
        LeftRightSigned cumulativeDelta = moved.sub(collectedSingleLeg);
        _settleDelta(acct, key.currency0, cumulativeDelta.rightSlot());
        _settleDelta(acct, key.currency1, cumulativeDelta.leftSlot());

        return abi.encode(moved, collectedSingleLeg);
    }

    function _createLegOnSelf(TokenId tokenId, bool)
        internal
        returns (LeftRightSigned moved, LeftRightUnsigned collectedSingleLeg)
    {
        LiquidityChunk chunk = LiquidityChunkLibrary.createChunk(TICK_LOWER, TICK_UPPER, DEFAULT_LIQUIDITY);
        return createLeg(address(this), poolKey, tokenId, chunk);
    }

    function _shortTokenId() internal view returns (TokenId) {
        // poolId in low 64 bits only (isLong=0)
        return TokenId.wrap(uint256(panopticPoolId));
    }

    function _longCallTokenId() internal view returns (TokenId) {
        // isLong @ leg1 + CALL tokenType @ leg1
        uint256 id = uint256(panopticPoolId);
        id += (LONG_BIT << (64 + LEG * 48 + 8));
        id += (TOKEN_TYPE_CALL << (64 + LEG * 48 + 9));
        return TokenId.wrap(id);
    }

    uint256 internal constant LONG_BIT = 1;

    function _settleDelta(address acct, Currency currency, int128 delta) internal {
        if (delta > 0) {
            POOL_MANAGER_V4.burn(acct, uint160(Currency.unwrap(currency)), uint128(delta));
        } else if (delta < 0) {
            POOL_MANAGER_V4.mint(acct, uint160(Currency.unwrap(currency)), uint128(-delta));
        }
    }

    function _deploy(bytes memory initcode) internal returns (address addr) {
        assembly ("memory-safe") {
            addr := create(0, add(initcode, 0x20), mload(initcode))
        }
        require(addr != address(0), "deploy failed");
    }
}
