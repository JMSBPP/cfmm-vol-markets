
type VolRangeWidth {
	width:u24,
	tickSpacing: u24
}

fn (tickSpacing:u24) -> (tsAwareMinVolRangeWidth:u24, tsAwareMaxVolRangeWidth:u24)

fn (tickSpacing:u24 ,tickLower: i24, tickUpper:24) -> (volRangeWidth:VolRangeWidth)

========================================================================

type SpreadTickAssimetry {
	spread :u16
}

fn ( self :SpreadTickAssimetry, tick:i24) -> [tick << self.spread , tick << (type(u16).max - self.spread) ]

fn (self: SpreadTickAssimetry, tickLower: u24, tickUpper: u24 , dir :bool ) -> [[dir](tickLower << self.spread, tickUpper<< (type(u16).max - self.spread) || (backwards))]

fn (self: SpreadTickAssimetry, tickLower: u24, tickUpper: u24 , dir :bool ) - [[dir] (i = tickLower << self.spread + tickUpper<< (type(u16).max - self.spread) || (backwards))]


=====================================================================================

type TickVolatility {
	vol: u88
}

fn (self: TickVolatility) -> (volX96:Q64.96)
fn (self: TickVolatility) -> (volWAD: WAD)
lnVolX96 = fn (self: TickVolatility) -> (lnVolX96Val: Q64.96)
lnVolWAD = fn (self: TickVolatility) -> (lnVolWADVal : WAD)


======================================================

type VolOrder {
	 rangeWidth:VolRangeWidth;
 	 volStrike:TickVolatility;
	 skew : SpreadTickAssymetry
}


setVolStrike = fn (volStrikeVal:u88) -> VolOrder

setSkew = fn (skewVal:u16) -> VolOrder

setRangeWidthTickSpacing = fn(tickSpacing:u24) -> VolOrder
setRangeWidthVal = fn(width:u24) -> VolOrder
setRangeWidthTickSpacing = fn(tickSpacing :u24) -> VolOrder
setRangeWidth = fn(width: u24, tickSpacing: u24) -> VolOrder


==========================================================
