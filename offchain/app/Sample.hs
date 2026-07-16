{-# LANGUAGE OverloadedStrings #-}

module Sample
  ( account
  , order_manager
  , sample_order
  ) where

import Data.Solidity.Prim.Address (Address)

import VolOrder.Types (VolOrder (..))

account :: Address
account = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

order_manager :: Address
order_manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    }
