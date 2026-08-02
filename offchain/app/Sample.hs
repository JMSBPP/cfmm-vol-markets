{-# LANGUAGE OverloadedStrings #-}

-- |
-- Sample DATA for the demo driver -- and nothing else.
--
-- Three address literals used to live here. They are gone: every address the demo touches now
-- comes from @offchain\/rig\/rig-manifest.json@, loaded once by @Rig.Manifest.load_rig@ in "Main".
--
-- The reason is measured, not stylistic. Those literals were right only by anvil nonce accident,
-- and one of them had already gone stale against a redeployed rig while still looking perfectly
-- correct -- it named a contract with no bytecode at all. A hardcoded address cannot announce
-- that it stopped being true, which is precisely why none belongs in this file.
module Sample
  ( sample_order
  , sample_order_shapes
  , sample_order_gen
  , sample_price_gen
  , sample_stride
  , sample_tick
  ) where

import StochasticOrderGen.Types
  ( ArrivalProcess (..)
  , OrderShape (..)
  , StochasticOrderGen (..)
  , VegaDraw (..)
  )
import StochasticPriceGen.Types (ProcessType (..), StochasticPriceGen (..))
import VolOrder.Types (VolOrder (..))

-- target_vega is DeltaQ_v* in RAW LIQUIDITY units (Uniswap L), never WAD or X96. 10^18 is one
-- whole 18-decimal token's worth of full-range liquidity on the rig's own pool -- the bottom of
-- the derived admissible band, and a real value rather than a placeholder.
--
-- This order does NOT go through the generator (it is the single-call create_order demo), so it
-- needs a genuine value of its own. The GENERATED orders get theirs drawn -- see
-- sample_order_shapes below, which deliberately carries no target_vega at all.
sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    , target_vega = 10 ^ (18 :: Int)
    }

-- Ten distinct, always-valid order shapes -- comfortably more than
-- sample_order_gen's expected batch size (lambda = 3.0), so an ordinary
-- cabal run demo essentially never trips run_order_gen's "N > length orders"
-- guard (StochasticOrderGen.Rpc, decision 4). A rare large Poisson draw
-- exceeding 10 SHOULD fail loudly per that guard -- this is expected
-- behaviour, not a bug, if it ever happens on a demo run.
--
-- These are SHAPES, not orders: there is no target_vega here to supply, because the generator
-- draws it. A placeholder value in this list would be discarded on every run while still reading
-- as if it meant something.
sample_order_shapes :: [OrderShape]
sample_order_shapes =
  [ OrderShape
      { shape_vol_target  = 1000 + n
      , shape_range_width = 60
      , shape_skew        = 500 + n
      }
  | n <- [0, 10 .. 90]
  ]

-- Small lambda relative to sample_order_shapes' length (10) -- deliberately
-- unlikely to trip run_order_gen's "N > length orders" guard on an ordinary
-- demo run, mirroring sample_price_gen's "safe by default" convention.
--
-- The vega_draw band is likewise safe by default: [1e18, 1e21] raw L is the whole admissible
-- band derived on the rig's own pool, so no ordinary demo draw can trip draw_target_vega's guard.
sample_order_gen :: StochasticOrderGen
sample_order_gen =
  StochasticOrderGen
    { arrival_process = Poisson { lambda = 3.0 }
    , orders          = sample_order_shapes
    , vega_draw       = LogUniform { vega_min = 10 ^ (18 :: Int), vega_max = 10 ^ (21 :: Int) }
    }

-- Nonzero and a multiple of the deployed pool's tickSpacing (60), so the demo
-- visibly moves state away from PriceSetterHookScript's initial tick = 0.
sample_tick :: Integer
sample_tick = 60

-- Seconds of chain time between two driver steps.
--
-- The CORRECTNESS floor is 1, not 12: the oracle's write guard is one timepoint per distinct uint32
-- TIMESTAMP (RealizedVolatilityStateLib compares lastTimepointTimestamp to now for EQUALITY, with
-- no block number anywhere), so any stride >= 1 keeps every step's write. 12 is chosen above that
-- floor because it is mainnet's block cadence, which keeps the oracle's sigma^2 window arithmetic
-- in a realistic regime rather than an artificially dense one -- and it is exactly as deterministic
-- as 1 would be.
--
-- The value is RECORDED in driver-run-capture.json rather than only lived here, so an offline check
-- answers "what stride was this run taken at" from the run's own data instead of from this file.
sample_stride :: Integer
sample_stride = 12

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
