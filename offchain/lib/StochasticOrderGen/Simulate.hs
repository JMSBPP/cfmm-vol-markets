module StochasticOrderGen.Simulate
  ( draw_target_vega
  , simulate_batch_count
  ) where

import System.Random.MWC (GenIO, uniformR)
import System.Random.MWC.Distributions (poisson)

import StochasticOrderGen.Types (ArrivalProcess (..), VegaDraw (..))

simulate_batch_count :: GenIO -> ArrivalProcess -> IO Int
simulate_batch_count gen (Poisson lambda_value) = poisson lambda_value gen

-- | Draw one order's @targetVega@ in RAW UNISWAP-L units, log-uniformly on the configured band.
-- The band's derivation and the evidence for the log shape live on 'VegaDraw'; this function is
-- only its mechanism.
--
-- THE TRAILING GUARD IS NOT DEAD CODE. Two distinct things it catches:
--
--   1. @round@ on a 'Double' at the top of the band can land one ulp above @hi@. The value would
--      then be outside the band the caller configured while looking entirely ordinary.
--   2. A MIS-PARAMETERISED law -- swapped bounds, a zero lower bound, a ceiling above u96 -- must
--      not silently produce a plausible number. A @targetVega@ of 0 violates the on-chain
--      @vega_target_is_complete@ @> 0@ predicate, and on the BATCH path an invalid tuple comes
--      back as a @(false, 0)@ that is indistinguishable from an ordinary business rejection.
--      There would be nothing to notice.
--
-- This is the same discipline as "StochasticPriceGen.Simulate"'s @euler_step@ domain guard:
-- fail LOUDLY at the exact step that went wrong, rather than let a silently-wrong value travel.
--
-- SIGNIFICAND NOTE, and it bounds what these values are good for. A 'Double' carries 53
-- significand bits; the top of the band needs 70. A draw near 1e21 therefore has roughly 17
-- forced-zero low bits. That is FINE for VEGA-01, which is about units and magnitude -- but it
-- makes the drawn values a WEAK field-boundary corpus. They must NOT be used as the RPIN-02/03
-- packing corpus; @vega_corners@ in @offchain\/test\/Main.hs@ is the CONSTRUCTED corpus that
-- covers the field boundaries, and the two are deliberately kept separate.
draw_target_vega :: GenIO -> VegaDraw -> IO Integer
draw_target_vega gen (LogUniform lo hi) = do
  u <- uniformR (0, 1) gen :: IO Double
  let v = round (fromIntegral lo * (fromIntegral hi / fromIntegral lo) ** u) :: Integer
  if v >= max 1 lo && v <= min hi (2 ^ (96 :: Int) - 1)
    then pure v
    else fail ("targetVega draw out of band: " ++ show v
                ++ " not in [" ++ show lo ++ ", " ++ show hi ++ "]")
