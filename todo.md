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

> note: This has been delegated to haskell_rpc_api
> todo: To inform about this, write an issue on develop branch about this
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



# 27-07-26 CODE_REVIEW

> todo: This is the way we do manual huma review. HOw to integrate it with version control code review 


- **General File Organization**

> todo: 
	- Harness goes on test/<name_space>/ **Harness.plk NOT on src/, relocate accordingly

## TYPES
- **types/protocol_integrations/MarketId.plk**
> todo: 
	- multi-protocol (Algebra/UniV3) generalization (the former `fn(comptime T)` wrapper)


- **types/Portafolio.plk**

> todo:
	- The Portafolio accounting loginc goes on the type lib. This includes a PortalioDelta type which mimics the role of BalanceDelta for v4-core/src/types/BalanceDelta.sol

## LIB

- **lib/protocol_integrations/CallbackRealizedVolatilityLib.plk**

> todo:
	- It needs to know store on the buffer the timepoint

- **lib/protocol_integrations/PanopticTokenIdSetterLib.plk**

> todo: 
 - This is what was intended, instead of replicating the whole tokenId. We want a lib taht does
  (VolOrder) -> (PanopticTokenId)

- **lib/ldf/LDFLib.plk**
> todo: 
 - This needs implementation and interprentation firts


- **lib/ldf/GeometricDistribution.plk**

> todo:
	- The Q96 goes in NUmerics.plk
	- alpha is xi, the notation we use is xi
	- length is iota, the notation we use is iota
	
	- the naming is not the generic `geometric_cumulative_amount{0/1}` BUT `geometric_cumulative_collateral_on_liquidity` matching VOLATILITY_INSTRUMENTS definition for \(Q_M^{L}\) and same for the underlying \(X\)
   
- **lib/ldf/**

> todo: Math libraries go in lib/math not inside a domain specific namespace

- **lib/pricing/EtaSplitKernel.plk**

> todo: 

	- Q96 needs to be placed on Numerics.plk

- **lib/TickUtils.plk**

> todo:
	- This is acctually a type. It needs relocation to types/pricing. INside typers/pricing put PriceBucket coordinate and pair too


- **lib/LiquidityAmounts.plk**

> todo:
	- Q96 and U128_MAX go in Numerics

## MODULES	

- **modules/protocol_integrations/PriceSetterHook.plk**

> todo:
	- This is missing the actual impl that is on PriceSetterHook.sol That is the intended impls Plus the log of PriceUpdate
   
   - The DEST_CHAIN and origin chain are entered on the coisntructor Thus the init block handles that
   
   - The other argument on the constructor is a comptime typed adddress that is guarded to mathc AlgebraFactory interface OR PoolManager interface
> note: 
	- The PriceSetterHookMod.plk uses the CallbackRealizedVolaitiyLib since it is the stateful portion of it AND implements the PriceSetterHook.sol logic as stated above.


