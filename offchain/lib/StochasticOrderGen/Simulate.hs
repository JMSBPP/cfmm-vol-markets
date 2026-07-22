module StochasticOrderGen.Simulate
  ( simulate_batch_count
  ) where

import System.Random.MWC (GenIO)
import System.Random.MWC.Distributions (poisson)

import StochasticOrderGen.Types (ArrivalProcess (..))

simulate_batch_count :: GenIO -> ArrivalProcess -> IO Int
simulate_batch_count gen (Poisson lambda_value) = poisson lambda_value gen
