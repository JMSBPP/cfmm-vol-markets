module StochasticOrderGen.Types
  ( ArrivalProcess (..)
  , StochasticOrderGen (..)
  ) where

import VolOrder.Types (VolOrder)

data ArrivalProcess = Poisson
  { lambda :: Double
  }
  deriving (Eq, Show)

data StochasticOrderGen = StochasticOrderGen
  { arrival_process :: ArrivalProcess
  , orders          :: [VolOrder]
  }
  deriving (Eq, Show)
