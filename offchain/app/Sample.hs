{-# LANGUAGE OverloadedStrings #-}

module Sample
  ( account
  , order_manager
  , price_setter_hook
  , sample_order
  , sample_orders
  , sample_order_gen
  , sample_price_gen
  , sample_tick
  ) where

import Data.Solidity.Prim.Address (Address)

import StochasticOrderGen.Types (ArrivalProcess (..), StochasticOrderGen (..))
import StochasticPriceGen.Types (ProcessType (..), StochasticPriceGen (..))
import VolOrder.Types (VolOrder (..))

account :: Address
account = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

order_manager :: Address
order_manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

price_setter_hook :: Address
price_setter_hook = "0x78f77B581417489BABC51CC63091db140962B000"

sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    }

-- Ten distinct, always-valid orders -- comfortably more than
-- sample_order_gen's expected batch size (lambda = 3.0), so an ordinary
-- cabal run demo essentially never trips run_order_gen's "N > length orders"
-- guard (StochasticOrderGen.Rpc, decision 4). A rare large Poisson draw
-- exceeding 10 SHOULD fail loudly per that guard -- this is expected
-- behaviour, not a bug, if it ever happens on a demo run.
sample_orders :: [VolOrder]
sample_orders =
  [ VolOrder { vol_target = 1000 + n, range_width = 60, skew = 500 + n }
  | n <- [0, 10 .. 90]
  ]

-- Small lambda relative to sample_orders' length (10) -- deliberately
-- unlikely to trip run_order_gen's "N > length orders" guard on an ordinary
-- demo run, mirroring sample_price_gen's "safe by default" convention.
sample_order_gen :: StochasticOrderGen
sample_order_gen =
  StochasticOrderGen
    { arrival_process = Poisson { lambda = 3.0 }
    , orders          = sample_orders
    }

-- Nonzero and a multiple of the deployed pool's tickSpacing (60), so the demo
-- visibly moves state away from PriceSetterHookScript's initial tick = 0.
sample_tick :: Integer
sample_tick = 60

-- Small sigma relative to dt = 1.0 -- deliberately unlikely to trip
-- StochasticPriceGen.Simulate's domain guard on an ordinary demo run.
-- initial_tick matches sample_tick so the simulated path continues from where
-- the preceding write_price demo call leaves the pool.
sample_price_gen :: StochasticPriceGen
sample_price_gen =
  StochasticPriceGen
    { process      = GBM { mu = 0.0, sigma = 0.05 }
    , size         = 5
    , initial_tick = 60
    , dt           = 1.0
    }
