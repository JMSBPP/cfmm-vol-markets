1- history test for fetching average on Algebra (done)
2- Implement Average algo using OracleLib of Uni v3 (done)
10. implement spec_order type system (done)
5- history test for fetching volatility on Algebra (done)
4- Plank implmenentation (DONE -- commit e2609ba)

------------
3- Differential test Algebra vs Uni V3 (partial)

----------
5- Differential testing with Plank (NEXT -- plan: .planning/plank-voldiff-plan.md)
6- Implement vol algo using OracleLIb of Uni v3


11. implement risk type system (in progress)
    RiskMeasureLib / RiskDiscount: factor_from_haircut_and_price,
    discounted_vega_amt_from_collateral and risk_measure all have EMPTY bodies.
12. Implement haskell API (in progress)

13. VegaAccountMod -- the only file left in PLANK_SKIP. Pure skeleton: the SLOT_*
    and SELECTOR_DEPOSIT consts have no values and it does not import
    VegaExposure. Needs the deposit(collateral) -> vegaExposure logic authored.


------


### VEGA NOTIONAL SCHEDULER

14. How to track vega from panoptic ?


Once you mint an option and price/ tick starts moving with time, volatility starts realizing and the payoff which is gained via trading fees has a sensitivity to such volatility. 

After idenifying the panoptic adapter payoff form and its relation with nreLIAED VOLATILITY, we need to build a module 'PanopticVegaLens' that tracks this and offers services to connect per strike, etc

We need a StochasticProcess that affects the price at Tx level

ExchangeRateDifussion :: {
	poolId: PoolId,
	config : StochasticConfig
}

(self: ExchangeRateDifussion, nObs) -> Array{size: nObs}[]
(self: ExchangeRateDifussion, nObs) -> void{
	'''
	Tx receipts of the transactions involving the change fo the prices
	'''
}

14.1  Build an entry point for uni v4 poolKey to Plank
14.2  Build an entry point for panoptic to Plank
14.3  Build a pool that ONLY allows arbitrary price setting


15. Build panoptic PanopticTokenId type consistent with the TokenId schema from Panotpic 
16. Build ldf (in progress)
 
17. map builderCode on panoptic with alegebra dynacmi fee code

## 14.2 REACTIVE ENTRY POINT PANOPTIC -> PLANK 

## 16 LDF

Since sqrtPriceCoordinate works as a price coordinate we have a PriceCoordinate type which can instantitate PricePoint types and works to use different mutations.

PriceCoordinate {
	TickBitmap<TickSpacing>;
	basis_points 1.0001;
	subs_elasticity: 
	// opt
	numb_rep: // e.g Q64.96
}
PricePair {
	geometry: PriceCoordinateId
	
}

(PriceCoordinate, p1,p2) -> PricePair
(PriceCoordinate, p1,p2) -> PriceOrderedPair
(PriceCoordinate, p1,pmid,p2) -> PriceBucket

(TickBucket) -> (PriceBucket)

- How the [Option](~/cfmms-playground/cfmm-wt/plank/lib/plank-monorepo/std/option.plk) type works at the EVM level ?
 - How the [Accumulator](~/cfmms-playground/cfmm-wt/plank/lib/plank-monorepo/std/utils.plk) type works at the EVM level  ?
 what advantages comptime offers ?
 what advantages functio  offers ?

- Defining general discrete integral on plank ? What API can it offer ?

- Accumulator can be used for cummulativeAmount when integrating over ticks

- feat/arrays is now on development. This can upgrade the multicall support for vega create order
