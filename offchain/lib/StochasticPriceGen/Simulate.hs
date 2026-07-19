module StochasticPriceGen.Simulate
  ( simulate_path
  ) where

import System.Random.MWC (GenIO)
import System.Random.MWC.Distributions (standard)

import StochasticPriceGen.Types (ProcessType (..), StochasticPriceGen (..))

simulate_path :: GenIO -> StochasticPriceGen -> IO [Integer]
simulate_path gen config = do
  prices <- generate_prices gen config (tick_to_price (initial_tick config))
  pure (map price_to_tick prices)

generate_prices :: GenIO -> StochasticPriceGen -> Double -> IO [Double]
generate_prices gen config = go (size config)
  where
    go n _ | n <= 0 = pure []
    go n p_current = do
      p_next <- euler_step gen config p_current
      rest <- go (n - 1) p_next
      pure (p_next : rest)

-- Domain guard: p_next is validated positive and finite here, before it is ever
-- used as p_current in the next step's P^beta (drift_diffusion) or fed into
-- price_to_tick's log(P) -- Haskell's (**) and log both silently produce NaN on a
-- non-positive input, and round(NaN) does not throw, it returns implementation-defined
-- garbage. Failing loudly here, at the exact step that went wrong, is the whole point.
euler_step :: GenIO -> StochasticPriceGen -> Double -> IO Double
euler_step gen config p_current = do
  z <- standard gen
  let (drift, diffusion) = drift_diffusion (process config) p_current
      step_dt = dt config
      p_next = p_current + drift * step_dt + diffusion * sqrt step_dt * z
  if p_next > 0 && not (isNaN p_next) && not (isInfinite p_next)
    then pure p_next
    else fail ("simulated price went non-positive or non-finite: " ++ show p_next)

drift_diffusion :: ProcessType -> Double -> (Double, Double)
drift_diffusion (GBM m s) p = (m * p, s * p)
drift_diffusion (CEV m d b) p = (m * p, d * (p ** b))

tick_to_price :: Integer -> Double
tick_to_price t = 1.0001 ** fromIntegral t

price_to_tick :: Double -> Integer
price_to_tick p = round (log p / log 1.0001)
