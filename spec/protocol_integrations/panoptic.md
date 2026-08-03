import [*](../../notes/VOLATILITY_INSTRUMENTS.md ) 
## CONTRACT LEVEL


> This requires the analyticsal formula and a realiable way to test and track on a Lens.sol/plank contract as a state viewer

Using the reactive network. Using the RealizedVolatility LIb we plug in and now track realzied volatility

From there we query something that reads the updated price, thus also 'responds/updates' pn volaitlity and then calculate the vegas

- Volatiltiy can be constructed from the Oracle that panoptic offers


TokenId {
	poolId()
	vegoid()
	tickSpacing()
	
	Legs[4]
	
	width(leg)
	strike(leg)
	riskPartner(leg)
	tokenType(leg)
	optionRatio(leg)
}
### EVENTS

```
event ForcedExercised(exercisor,user,tokenId,exerciseFee);
// note: This has rate structure dfor exerciseFee
event PremiumSettled(user,tokenId,legIndex,settledAmounts);
// note: THis has integral strcuture for settledAmounts
event OptionBurnt(recipient,uint128 positionSize,tokenId,LeftRightSigned[4] premiaByLeg);
event OptionMinted(recipient,tokenId,PositionBalance balanceData);
```
TODO: Assign math notation to each of the events amounts

### STATE

```
OraclePack internal s_oraclePack;
/// option formation: address => tokenId => leg => premiaGrowth.
/// @dev Premia growth is taking a snapshot of the chunk premium in SFPM, which is measuring the amount of fees
/// collected for every chunk per unit of liquidity (net or short, depending on the isLong value of the specific leg index).
mapping(address => mapping(TokenId => LeftRightUnsigned[4])) internal s_options;
```
> One address has MANY chunks

```
/// @notice Per-chunk `last` value that gives the aggregate amount of premium owed to all sellers when multiplied by the total amount of liquidity `totalLiquidity`.
// / @dev `totalGrossPremium = totalLiquidity * (grossPremium(perLiquidityX64) - lastGrossPremium(perLiquidityX64)) / 2**64`
/// @dev Used to compute the denominator for the fraction of premium available to sellers to collect.
/// @dev LeftRight - right slot is token0, left slot is token1.
mapping(bytes32 chunkKey => LeftRightUnsigned lastGrossPremium) internal s_grossPremiumLast;
/// @notice Per-chunk accumulator for tokens owed to sellers that have been settled and are now available.
/// @dev This number increases when buyers pay long premium and when tokens are collected from Uniswap.
    /// @dev It decreases when sellers close positions and collect the premium they are owed.
    /// @dev LeftRight - right slot is token0, left slot is token1.
    mapping(bytes32 chunkKey => LeftRightUnsigned settledTokens) internal s_settledTokens;

    mapping(address account => mapping(TokenId tokenId => PositionBalance positionBalance))
        internal s_positionBalance;
```



    /// @notice Returns accumulated premium, position balances, per-position collateral requirements, and per-position net premia.
    /// @param user Address of the user that owns the positions
    /// @param includePendingPremium If true, include pending (unsettled) premium; if false, only settled
    /// @param positionIdList List of positions. Written as `[tokenId1, tokenId2, ...]`
    /// @return shortPremium Total premium owed to short legs (token0: right, token1: left)
    /// @return longPremium Total premium owed by long legs (token0: right, token1: left)
    /// @return positionBalances PositionBalance data for each position
    /// @return collateralRequirements Net collateral required per position (token0: right, token1: left)
    /// @return netPremiaPerPosition Net premia per position: short minus long (token0: right, token1: left)
    function getFullPositionsData(
        address user,
        bool includePendingPremium,
        TokenId[] calldata positionIdList
    )
        external
        view
        returns (
            LeftRightUnsigned shortPremium,
            LeftRightUnsigned longPremium,
            PositionBalance[] memory positionBalances,
            LeftRightUnsigned[] memory collateralRequirements,
            LeftRightSigned[] memory netPremiaPerPosition
        )
    {
        LeftRightUnsigned[2] memory shortLongPremium;
        int24 currentTick = getCurrentTick();
        (shortLongPremium, positionBalances, netPremiaPerPosition) = _calculateAccumulatedPremia(
            user,
            positionIdList,
            COMPUTE_PREMIA_AS_COLLATERAL,
            includePendingPremium,
            currentTick,
            true
        );
        collateralRequirements = riskEngine().getPerPositionCollateralRequirements(
            positionBalances,
            positionIdList,
            currentTick
        );
        return (
            shortLongPremium[0],
            shortLongPremium[1],
            positionBalances,
            collateralRequirements,
            netPremiaPerPosition
        );
    }
```

> NOTE: This exposes the fact that all position data is uodated once the tick changes. This implies that
once we construct volatility oracle on top given the EMATickOracle provided we can construct accumulators over gthe same window vol is beaing measured and thus get the vega from there



- **REQUIREMENTS**

-  Construct volatilitty iracle from pacoptinc EMATickOracle
   - This uses teh reactive network. 
   
   - Thus assuming and abstracting away funding constrains. HOw to adapt realizedVolLib to EMATickOracle


OraclePack -> Timepoint

insertObservation = write_timepoint

How do we construct a minimal pool
> When \(/i = i_l = i_u\) is not a revert but the leg og the tokenId uses

createPositionInAMM(
        address account,
        PoolKey memory key,
        bool invertedLimits,
        uint128 positionSize,
        TokenId tokenId,
        bool isBurn
)internal returns (LeftRightUnsigned[4] memory collectedByLeg, LeftRightSigned totalMoved) {
        LeftRightSigned itmAmounts;
        LeftRightUnsigned totalCollected;
	    LeftRightUnsigned amountsMoved = PanopticMath.getAmountsMoved(
                        tokenId,
                        positionSize,
                        leg,
                        true
                    );
                           int128 signMultiplier = isLong == 0 ? int128(-1) : int128(1);

                    {
                        uint256 tokenType = tokenId.tokenType(leg);
                        int128 itm0 = tokenType == 1
                            ? int128(0)
                            : signMultiplier * int128(amountsMoved.rightSlot());

                        int128 itm1 = tokenType == 0
                            ? int128(0)
                            : signMultiplier * int128(amountsMoved.leftSlot());

                        itmAmounts = itmAmounts.addToRightSlot(itm0).addToLeftSlot(itm1);
                    }
 


 
