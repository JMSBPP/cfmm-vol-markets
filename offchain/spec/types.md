

 TODO
 
 
 EVENT_LIST
 
ORDER_CREATED {
	order_creator: id
	order_owner: id,
	timestamp: UTC,
	vol_target: u88,
	range_skew: u16,
	range_width: u24
} 
 - 

{
	endpoint: JSONRpc;
	
	
	subscribe (event_signature)
}
