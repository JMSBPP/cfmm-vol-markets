

=======================================

type NumberFormat DirectAddressMap {
	Natural -> {min,max,step}
	Rational -> {min,max,step}
    Q64.96 -> {min,max,step}
	Q128.128 -> {min,max,step}
	RAY -> {min,max,step}
	WAD -> {min,max,step}
}

type NumberGroupSpec { min; max; step}

type BoundedValue<NumberFormat, lowerBound, upperBound>
type Set<size:Natural> {}

type Grid is Set {}

====================================


type Asset
type Currency 

type AssetPricer<Currency> -> (Currency/Asset){}

=====================================================
// note: These are control params

type VolatilityTermStructure {
	priceElasticity: BoundedValue<Q64x96, 0, Q96_ONE>; // this number format is to be revised
	statePartitionDelta: BoundedValue<Natural,1,200>; // tickSpacing u24 [1,200]
	baseTick: BoundedValue<Integer, -, ...>
}

type VolatilityGrid is Grid {}

type VolatilityGridLens <VolatilityTermStructure, MarketLens, VolatilityGrid> {
     crossSectionVolatilityValue : calculateValue(VolatilityTermStructure,MarketLens,VolatilityGrid)
}


==============================================
