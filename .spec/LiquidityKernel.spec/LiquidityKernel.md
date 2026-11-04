[\[
	\begin{aligned}
		\bigg (N_K, \Big\{ (i_K, \sigma (i_K), \mu (i_K))\Big\}_{j=1}^{N_K} \bigg)
		\, \overbrace{\leadsto}^{\texttt{LiquidityKernel}} \,
		\Big(
			\big(\Gamma_{\varphi},\; m_{\Gamma}\big),\;
			\ell,\;
			L(i_K),\;
			L(\Gamma_i)
		\Big)
	\end{aligned}
\]](../root.md)

N_K is akin to windowIdx or windowLen


1. How is the liq base encoded in bunni-v2 ?

	- Does the representation need to change considering it will used for constructing coordinates ?


2`. Note that liqBase is a constant whic has the same role as lambda = 1.0001 or the tick base but to build the gamma coordinate

From \(i: \texttt{Tick} (\texttt{ts})\) we want

# TODO


## \(L (i_k )\)
Let's compare how raw liquidity on panoptic compares with liquidity on bunni-v2 and derive the differentiatios or mappiungs between liquidity density functions and the machinery on top of panoptic

Let's start with panoptic.


### SemiFungiblePositionManagerV4.sol


mintTokenizedPosition                        (external)
   |   
    --- _unlockAndCreatePositionInAMM         (internal)
              |
               -- unlockCallback              (external) (only POOL_MANAGER)
                      |
                       --- createPositionInAMM  (internal)
                                  |
                                x 4 createLegInAMM  (internal)


#### **createLegInAMM**
> EXPRESS THIS AS STATE-SPACE

- (i , i_j , L, isBurn) -> (LeftRightSigned moved, LeftRightUnsigned collectedSingleLeg)

[POSITION_KEY]()
positionKey = Hash(i , i_j L)
\[
	\begin{aligned}
		\texttt{key}
	\end{aligned}
\]

[TOKEN_ID]()
uint256 isLong = tokenId.isLong(leg);
uint256 tokenType = tokenId.tokenType(leg);

> THESE ABOVE ARE ENGINEER TO BE GIVEN, NOT INPUTS
[LIQUIDITY_CHUNK]()
uint128 chunkLiquidity = liquidityChunk.liquidity();
int24 tickLower = liquidityChunk.tickLower();
int24 tickUpper = liquidityChunk.tickUpper();

\[
	\begin{aligned}
		u = \begin{bmatrix}
			L_{\texttt{input}} \\
			i_l \\
			i_u \\
		\end{bmatrix}
	\end{aligned}
\]

[PANOPTIC ACCOUNTING](~/apps/vol-markets/.worktrees/type-liquidityKernel/.tmp/panoptic-v2-core/contracts
/SemiFungiblePositionManagerV4.sol::L999)


\[
	\begin{aligned}
		x = \begin{bmatrix}
			   L^{\texttt{onAMM}}_{\texttt{key}} \\
			   L^{\texttt{outAMM}}_{\texttt{key}}
			\end{bmatrix} \\
			\\
		\bar x = A \,x + B \, u
	\end{aligned}
\]


{
	uint128 updatedLiquidity;
	// note: Query the liquidity on AMM
	LeftRightUnsigned currentLiquidity = s_accountLiquidity[positionKey];
	uint128 startingLiquidity = currentLiquidity.rightSlot();  
	// liquidity currently sold (added) in the AMM owned by the user
	[isLong 'moving *from* uniswap to account'](startingLiquidity > chunkLiquidity)
		updatedLiquidity = startingLiquidity - chunkLiquidity;
	[isShort 'moving from account to uniswap'](chunkLiquidity > 0)
		updatedLiquidity = startingLiquidity + chunkLiquidity;
    uint128 removedLiquidity = currentLiquidity.leftSlot(); 
	 // liquidity currently bought (removed) that has been removed from the AMM - the user owes it to a seller
	 [isBurn]()
	 removedLiquidity -= chunkLiquidity
	 [isMint]()
	 removedLiquidity += chunkLiquidity
     s_accountLiquidity[positionKey] = LeftRightUnsigned.wrap(updatedLiquidity)
                                                        .addToLeftSlot(removedLiquidity);
}

[UNISWAP ACCOUNTING](~/apps/vol-markets/.worktrees/type-liquidityKernel/.tmp/panoptic-v2-core/contracts/SemiFungiblePositionManagerV4.sol::L1042)
\[
	\begin{aligned}
		y =  
	\end{aligned}
\]

> The lesson is one can build a hook on top of panoptic
{
	int128 liquidityDelta;
	[isLong AND isMint] liquidityDelta = -int128(chunkLiquidity)
	(BalanceDelta delta, BalanceDelta feesAccrued) = POOL_MANAGER_V4.modifyLiquidity(
		poolKey, tickLower, tickUpper, int256(liquidityDelta),positionKey)
	 moved = LeftRightSigned
                .wrap(0)
                .addToRightSlot(feesAccrued.amount0() - delta.amount0())
                .addToLeftSlot(feesAccrued.amount1() - delta.amount1());
	// NOTE: We are deferring this case for later when we allow for swaps			
	// (premium can only be collected if liquidity existed in the chunk prior to this mint)
    if (currentLiquidity.rightSlot() > 0) {
            collectedSingleLeg = LeftRightUnsigned
                .wrap(0)
                .addToRightSlot(uint128(feesAccrued.amount0()))
                .addToLeftSlot(uint128(feesAccrued.amount1()));
}

### POOL_MANAGER_V4.modifyLiquidity

- Given the tick spacing \(\Delta_i\) we define a liquidity base \(\xi^{\star} = \lambda^{-\Delta_i/2}\) and 
- What we are given on panoptic is that once we add liquidity, \(\bar L_{1/2}\) on a chunk we have the state over the range \([i_l, i_u]\) :

\[
	\begin{aligned}
		\bar L_{1/2} \, &= \, \sum_{i_k = i_l}^{i_u} \, L(i_k) \\
		L(i_k) \, &= \, \bar L_{1/2} \cdot \ell (i_k, \iota, \xi^{\star}) ; \quad \iota > 1 \\
		\\
		\ell (i_k, \iota, \xi^{\star}) =  \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)} \\
		G(\iota) \, = \, \frac{\bar L_{(1/2,\,0)}}{2}\,\frac{1-\xi^{\star}}{1-(\xi^{\star})^{\iota}}
	\end{aligned}
\]

> \(\iota\) is a control parameter

Simulatenously we have defined:

\(\Gamma_{\varphi}(i) \, \equiv \, \xi^{\,-3 \,(i + \Delta_i/2)}\)

Now there is an input \(g > 0\): 

\[
	\begin{aligned}
		G(\iota) \, \ge \, g
	\end{aligned}
\]
Now over a window \(W\) we have that \(i : [i_l, i_u]\) moves and generates:

\[
	\begin{aligned}
		\sigma_{\texttt{RV}}\, (i_j) = \frac{1}{W} \, \sum_{j=1}^{W}\, (i_j - i_{\mu})^{2}
	\end{aligned}
\]
and then ping \(\pi^{\sigma}_{\mathrm{no\,fee}} (i_j)= G(\iota)\,\sigma_{\mathrm{RV}}^{2} \, (i_j)\)

where \(\pi^{\sigma}_{\mathrm{no\,fee}} = \texttt{getAccountPremium}\)


- \(\texttt{getAccountPremium}\) are sophisticated wrappers of \(\texttt{V4StateReader.getFeeGrowthInside}\)

> tokenType is fixed per call and given to filter the positionKey from where feeGrowth will be queried
> isLong is to determine if the premium is owed or accrued
> vegoid,owner, poolKey and tickBounds are fixed

Thus \(\pi^{\sigma}_{\phi} (i_j) = \texttt{getAccountPremium} (i_j)\)

    struct TickInfo {
        // the total position liquidity that references this tick
        uint128 liquidityGross;
        // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left),
        int128 liquidityNet;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }


modifyLiquidity(State storage self, ModifyLiquidityParams memory params) -> return (feeDelta){
    (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
                    getFeeGrowthInside(self, tickLower, tickUpper) {
						getFeeGwothInside (\(i_j\))
					}

	Position.State storage position = self.positions.get(params.owner, tickLower, tickUpper, params.salt);
	(uint256 feesOwed0, uint256 feesOwed1) = position.update(
	                                                       liquidityDelta, 
														   feeGrowthInside0X128, 
														   feeGrowthInside1X128);

} feeDelta(feesOwed0,feesOwed1) 

## \(i_{j+1}\)
The question is how do we make the CFMM reach an arbitrary target tick \(i_{j+1}\) from current tick \(i_j\)
The process is first identify our tools:

- swap interface on poolManager
- controller before and afterSwap
## IPoolManager.swap
### Conventions
- since the poolKey is already given we ommit it to simplify the signature
- hookData is partially considered to be unused



struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified; \(X\)
    uint160 sqrtPriceLimitX96; \(\sqrt{p}_{\texttt{limit}}\)
}

Do first: 
(\(\sqrt{p} (i_{j+1})\))-> SwapParams
- \(\sqrt{p}_{\texttt{limit}} \leftarrow \sqrt{p} (i_{j+1}) \)
> **justification:** If we find that we can solve in one step the inner Pool.swap algo stops at `while (!(amountSpecifiedRemaining == 0 || result.sqrtPriceX96 == params.sqrtPriceLimitX96))`

Let's now find our \(\texttt{zeroForOne}\). Note that a revert condition on Pool.swap is:

```
zeroForOne ^ (params.sqrtPriceLimitX96 >= slot0Start.sqrtPriceX96())
``

Then:
\[
	\begin{aligned}
		( \sqrt{p}_j, \sqrt{p}_{j+1} ) \to \texttt{zeroForOne} \leftarrow \sqrt{p}_j < \sqrt{p}_{j+1}
	\end{aligned}
\]

We have already covered fully 2 out of three on swapParams, the next is \(X\)

We have:
\[
	\begin{aligned}
		\texttt{zeroForOne} \implies X > 0
	\end{aligned}
\]

\(X_{\phi} (X) \geq F (\sqrt{p}_j, \sqrt{p}_{j+1} , L)\)


> How can we reduce the state for our benefit and considering our application ?
struct State {
    Slot0 slot0;
    uint256 feeGrowthGlobal0X128;
    uint256 feeGrowthGlobal1X128;
    uint128 liquidity;
    mapping(int24 tick => TickInfo) ticks;
    mapping(int16 wordPos => uint256) tickBitmap;
    mapping(bytes32 positionKey => Position.State) positions;
}
struct SwapResult {
    uint160 sqrtPriceX96;
    int24 tick;
    uint128 liquidity;
}
struct SwapParams {
    int256 amountSpecified;
    int24 tickSpacing;
    bool zeroForOne;
    uint160 sqrtPriceLimitX96;
    uint24 lpFeeOverride;
}
struct StepComputations {
        uint160 sqrtPriceStartX96;
        int24 tickNext;
        bool initialized;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
        uint256 feeGrowthGlobalX128;
}

swap(State,SwapParams) -> (BalanceDelta swapDelta,amountToProtocol,swapFee,SwapResult)
    {
        result.sqrtPriceX96 = slot0Start.sqrtPriceX96();
        result.tick = slot0Start.tick();
        result.liquidity = self.liquidity;
        StepComputations memory step;
        step.feeGrowthGlobalX128 = zeroForOne ? self.feeGrowthGlobal0X128 : self.feeGrowthGlobal1X128;
> This is an OR stament, meaning we can only fulfill result.sqrtPriceX96 == params.sqrtPriceLimitX96
> This is we can provide some params.amountSpecified which never reaches 0
        while (!(amountSpecifiedRemaining == 0 || result.sqrtPriceX96 == params.sqrtPriceLimitX96)) {
            step.sqrtPriceStartX96 = result.sqrtPriceX96;
           (step.tickNext, step.initialized) =
                self.tickBitmap.nextInitializedTickWithinOneWord(
     		    result.tick, params.tickSpacing, zeroForOne);
            > bounded(step.tickNext)
            // get the price for the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtPriceAtTick(step.tickNext);
            (result.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                result.sqrtPriceX96,
                SwapMath.getSqrtPriceTarget(zeroForOne, step.sqrtPriceNextX96, params.sqrtPriceLimitX96),
                result.liquidity,
                amountSpecifiedRemaining,
                swapFee
            );
> Here `amountSpecifiedRemaining` is give on the computeSwap to derive the next step result.sqrtPriceX96
> Thus if how does it affect the next price result and how can we control it ? well note
computeSwapStep {
	(zeroForOne) ^ 
	(amountRemaining < 0) ^ 
	(FullMath.mulDiv(uint256(-amountRemaining), MAX_SWAP_FEE - _feePips, MAX_SWAP_FEE) >= SqrtPriceMath.getAmount0Delta(sqrtPriceTargetX96, sqrtPriceCurrentX96, liquidity, true))	
} ===> {sqrtPriceNextX96 = sqrtPriceTargetX96; feeAmount = _feePips == MAX_SWAP_FEE } }
            if (result.liquidity > 0) {
                unchecked {
                    // FullMath.mulDiv isn't needed as the numerator can't overflow uint256 since tokens have a max supply of type(uint128).max
                    step.feeGrowthGlobalX128 +=
                        UnsafeMath.simpleMulDiv(step.feeAmount, FixedPoint128.Q128, result.liquidity);
                }
            }
            if (result.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128) = zeroForOne
                        ? (step.feeGrowthGlobalX128, self.feeGrowthGlobal1X128)
                        : (self.feeGrowthGlobal0X128, step.feeGrowthGlobalX128);
                    int128 liquidityNet =
                        Pool.crossTick(self, step.tickNext, feeGrowthGlobal0X128, feeGrowthGlobal1X128);


function crossTick(State storage self, int24 tick, uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128)
        internal
        returns (int128 liquidityNet)
    {
        unchecked {
            TickInfo storage info = self.ticks[tick];
            info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
            info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
            liquidityNet = info.liquidityNet;
        }
    }
}


