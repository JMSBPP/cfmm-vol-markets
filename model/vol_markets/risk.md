

type RiskDiscount {
	price: Q64.96,
	factor: Q64.96 // harcut/ price
}


// fills the factor value 
fn (haircut:Q0.64, price: Q64.96) -> RiskDiscount

fn (self: RiskDiscount collateralAmt :u256) -> collateralAmount* (self.price/haircut)


type RiskMeasure {
	riskPriceRef :RiskDiscount;
	price: Q64.96;
	measure: Q0.96;
}

// fills the measure value
fn (riskMeasure:RiskMeasure) -> RiskMeasure 

riskAdjustedVegaAmt = fn (self :RiskMeasure,vegaAmt:u256) -> u256 {}
