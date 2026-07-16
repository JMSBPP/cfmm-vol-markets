module VolOrder.Types
  ( VolOrder(..)
  ) where

import Network.Ethereum.Api.Types (Quantity)

data VolOrder = VolOrder
  { vol_target  :: Quantity
  , range_width :: Quantity
  , skew        :: Quantity
  }
