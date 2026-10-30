

* Snap to spacing, then clip to the legal tick universe.
$macro normTickVal(tickVal,tickSpacingVal) 
(max(MIN_TICK, min(MAX_TICK, (tickSpacingVal)*floor((tickVal)/(tickSpacingVal)))))


When set_tick is called
	When tickSpacingOn storage is not set
		it should revert
	When tickSpacingOn storage is set
		it should set tickVal to normTickVal
		
	
