{-# LANGUAGE BangPatterns #-}

-- | Shared panel/observation records used across the whole estimation pipeline.
--
-- Every later stage (subgraph fetch, panel build, variance construction, NLS
-- estimation, specification tests) reads and writes these types, so they live in
-- one module to keep the Lean<->Haskell<->spec cross-walk single-sourced.
module Econ.Types
  ( Obs (..)
  , Panel
  , Theta (..)
  ) where

import Data.Text (Text)

-- | One position-epoch observation of the panel.
--
--   * 'obsTokenId'      -- Panoptic @TokenId@ (the clustering unit for robust SEs).
--   * 'obsEpoch'        -- daily epoch index.
--   * 'obsPremium'      -- per-epoch settled premium flow pi_it (delta of the
--                          cumulative @premiaSettled*Total@, NOT the raw total).
--   * 'obsStrikeTick'   -- strike tick i_K (from @Leg.strike@ via i_K = log_lambda K).
--   * 'obsPoolTick'     -- underlying Uniswap pool tick i_t at the epoch.
--   * 'obsSigma2'       -- within-day realized variance sigma^2_t (measured, noisy).
--   * 'obsSigma2Instr'  -- second, independently-windowed variance sigma~^2_t used
--                          as the EIV instrument for sigma^2_t.
data Obs = Obs
  { obsTokenId     :: !Text
  , obsEpoch       :: !Int
  , obsPremium     :: !Double
  , obsStrikeTick  :: !Int
  , obsPoolTick    :: !Int
  , obsSigma2      :: !Double
  , obsSigma2Instr :: !Double
  }
  deriving (Show, Eq)

-- | A panel is just the list of its observations.
type Panel = [Obs]

-- | The three structural parameters of the exponential-moneyness model
-- @pi = b0 + u0 * exp(-kappa * |iK - it|) * sigma^2 + v@.
data Theta = Theta
  { b0    :: !Double
  , u0    :: !Double
  , kappa :: !Double
  }
  deriving (Show, Eq)
