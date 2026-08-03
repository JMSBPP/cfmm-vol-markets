module StochasticPriceGen.Types
  ( ProcessType (..)
  , StochasticPriceGen (..)
  ) where

data ProcessType
  = GBM
      { mu    :: Double
      , sigma :: Double
      }
  | CEV
      { mu    :: Double
      , delta :: Double
      , beta  :: Double
      }
  deriving (Eq, Show)

data StochasticPriceGen = StochasticPriceGen
  { process      :: ProcessType
  , size         :: Int
  , initial_tick :: Integer
  , dt           :: Double
  }
  deriving (Eq, Show)
