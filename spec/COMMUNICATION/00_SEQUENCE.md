

## TYPES
Order {
	il,
	iu,
	variance, 
	
	require (0 < i_l < i_u)
	require(\bar \sigma > 0)
}

Notional {
	size: Q24.24,
	strike: i24,
	
> * \(\# (\Delta_i ) = \frac{i_u - i_l}{\Delta_i}\)
}


LiquidityFlow {}

LiquidityStock{
    size: Q128.128;
}

GridGeometry {
	liquidity: LiquidityStock
	tickSpacing:u24
	elasticity: tbd;
}

AssetStock <space :GridGeometry> {
	 space: space;
	 size: Quantity;
}

AssetFlow <space :GridGeometry>{
	space:: space;
	delta:: BalanceDelta;
}


Asset <space :GridGeometry>{
	id:: addr;
	inventoryPtr ::AssetStock<space>;
	balancePtr :: AssetFlow<space>;
	tbd :: (AssetFLow => AssetStock);
}

PriceAmt {
	amt : Q96.96;
}

PriceGrid<numeraire: Asset, underlying: Asset> {
	require(numeraire.space == underlying.space)
	space: numeriare.space
    price(space, asset.id ,tick) -> PriceAmt;
}

Portafolio<valueKernel: PriceGrid, assets: Asset[]> {
	value()
	
	tbdWeight(tick) // \eta_i 
}

Payoff is Accumulator{
	val,
	delta
}


## MODULES

StatePartitionDeltaView {
	\(\Delta_i\)
}



## SEQUENCE 
a -----
       |
       v
   Order{ i_{l}, i_{u}, volLevelAmt) 
       |
       | ----->  Notional.init(Order.i_l, Order.i_u, StatePartitionDeltaView.statePartitionVal())
	   |                   |
       |                    ----> Notional
	   |					         |
       |                             |
	   |
       |-----> 	Payoff.init(Notional,volLevelAmt)
       |
	   |                - INIT PAYOFF IS INITIALIZED AT 0
       |
       |
       | ------> min < -  isMin(i_l) ? i_l : discard
	   | ------> max <-      //(i_u)          //
        
                             |
							 |
							 v
				      -----------			 
                      |     i    |
		              |    i_u   |
					  |    i_-   |
					  |    i_+   |
					  |     di   |  // tickSpacing
					   -----------	  
==============

Given \(N\) agents \(\{a_1 , \, \cdots , a_N \}\) that have submitted their orders we have:


## MODULES
PositionsState{
	agents ===> tokenId // this has the notional info, the strikes, and even a pointer to query
	// the state of the payoff guarded by only querieable by agent permissioned accounts
	agents ==> lastStrikeDiff  // i_k - i_-
}

MarketStatisticsMod{
	strikesDispAcumm
	strikesDispAccummSqx
	tickMean
	
	// require: Updated when an agent submits/claims an order
}
MarketStatisticsLib{

	calcukateVariance(tickSpacing, MarketState.tickMean()) 
}


MarketState {

    tickMin
	tickMax
	tick
	tickMean
	
	tickSpacing
	elasticity
	
	updateBounds() 
	   updateMaxTick()
	   updateMinTick()   
	        --------------- (NotionalLib.makeNotionalSize(tickMin(), tickMax(), tickSpacing())) 
	                                          |
											  |
										 marketExpsosure() // this is retrieved when queried	  
}
