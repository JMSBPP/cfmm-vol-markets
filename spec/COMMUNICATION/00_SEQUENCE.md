

## TYPES
Order {
	il,
	iu,
	variance, 
	
	require (0 < i_l < i_u)
	require(\bar \sigma > 0)
}

Notional {
	il,
	iu,
	val
	
> * \(\# (\Delta_i ) = \frac{i_u - i_l}{\Delta_i}\)
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
        ----->  Notional.init(Order.i_l, Order.i_u, StatePartitionDeltaView.statePartitionVal())
		                   |
                            ---> Notional
							        |
                                    |
	   |
       |-----> 	Payoff.init(Notional,volLevelAmt)

 
