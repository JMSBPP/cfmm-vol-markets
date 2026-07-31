

Panoptic --> PoolKey/ PoolId
                          |
                          v
                 listen(       ) --->  subscribe (event PriceChange)


=> react (event PriceChange) ->  |        Callback
                                 |           write_timepoint ()
