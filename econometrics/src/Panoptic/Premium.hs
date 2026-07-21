{-# LANGUAGE OverloadedStrings #-}

-- | Accumulator differences → per-(position, epoch) premium in token wei. This
-- is the arithmetic heart of the amended route: given the X64 accumulator read
-- at two blocks, the premium is
--
-- @
-- premium = ((acc(t_end) - acc(t_start)) \`mod\` 2^128) * legLiquidity \`div\` 2^64
-- @
--
-- negated for long legs (@PanopticPool._getPremia@ L2296-2298). Everything here
-- is 'Integer' and load-bearing:
--
--   * __The subtraction is mod-2^128 ('accDelta'\/'Chain.Abi.diffMod'), never a
--     bare @hi - lo@.__ The accumulators are @uint128@ under Solidity
--     @unchecked@ semantics; a naive 'Integer' subtraction yields ~1.15e77
--     instead of the intended small positive delta whenever the value wrapped
--     (RESEARCH Pitfall 3).
--   * __The scale is X64 (@2^64@), NOT X128 or X96.__ RESEARCH Pitfall 2 names
--     \"off by exactly 2^64 / 2^128 / 1e12\" as the diagnostic signature of
--     getting this wrong.
--   * __The telescoping identity is EXACT__ (not approximate): the reconciliation
--     gate's legitimacy is that the panel is a /decomposition/ of the ground
--     truth, so 'telescope' asserts exact equality with the endpoint premium.
--   * __A frozen accumulator ('isFrozenAcc') and an empty chunk ('ChunkEmpty')
--     are each FLAGGED, never silently read as zero fees__ (RESEARCH Pitfalls 5,
--     6). A flagged observation is not auto-dropped, but it is never invisible.
module Panoptic.Premium
  ( -- * Types
    AccReading (..)
  , PremiumObs (..)
  , PremiumFlag (..)
    -- * Accumulator arithmetic
  , accDelta        -- Integer -> Integer -> Integer            (mod 2^128)
  , premiumWei      -- Integer -> Integer -> Integer -> Bool -> Integer
  , telescope       -- [Integer] -> Integer -> Bool -> Integer
  , isFrozenAcc     -- Integer -> Bool
  , multiplierWedge -- Integer -> Integer -> Bool -> Rational
    -- * Fan-out
  , buildPremiumObs -- [LegChunk] -> Map (ChunkKey, Integer, Bool) AccReading -> [PremiumObs]
  ) where

import           Data.List       (sortOn)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Ratio      ((%))
import           Data.Text       (Text)

import           Chain.Abi       (diffMod)
import           Panoptic.Chunk  (ChunkKey, LegChunk (..), storedValueTick)

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

-- | One pool-wide chunk accumulator read at a block: the X64 accumulator for
-- both currencies plus the liquidity levels that disambiguate a flat stretch
-- (RESEARCH Pitfall 5) and the @atTick@ that says whether the value was
-- extrapolated or stored.
data AccReading = AccReading
  { arChunkKey         :: !ChunkKey
  , arBlock            :: !Integer
  , arEpoch            :: !Integer
  , arIsLong           :: !Bool
  , arAtTick           :: !Int      -- ^ 'storedValueTick' = stored value; else a live extrapolation.
  , arAcc0             :: !Integer   -- ^ currency0 (ETH) X64 accumulator.
  , arAcc1             :: !Integer   -- ^ currency1 (USDC) X64 accumulator.
  , arNetLiquidity     :: !Integer
  , arRemovedLiquidity :: !Integer
  , arEndpoint         :: !(Maybe Text)  -- ^ @Just "mint"|"burn"@ endpoint read, else @Nothing@.
  }
  deriving (Show, Eq)

-- | A per-(tokenId, leg, epoch) premium observation in token wei, carrying the
-- flags the gate and the analysis must see.
data PremiumObs = PremiumObs
  { poTokenId     :: !Text
  , poLegIndex    :: !Int
  , poEpoch       :: !Integer        -- ^ tagged to the ENDING epoch of the delta (09-04 convention).
  , poPremiumWei0 :: !Integer        -- ^ currency0 (ETH) premium, wei.
  , poPremiumWei1 :: !Integer        -- ^ currency1 (USDC) premium, wei.
  , poIsLong      :: !Bool
  , poStrikeTick  :: !Int
  , poFlags       :: ![PremiumFlag]
  }
  deriving (Show, Eq)

-- | Conditions that make a zero delta ambiguous, carried through to the panel so
-- a flat stretch is never silently read as \"no fees\".
--
--   * 'ChunkEmpty': @netLiquidity == 0@ at the reading block — @getAccountPremium@
--     silently returned the stored (non-extrapolated) accumulator (Pitfall 5).
--   * 'AccFrozen': the accumulator is within 1% of @2^128 - 1@; once it caps,
--     @LeftRightLibrary.addCapped@ freezes owed and gross together and every
--     delta is 0 forever (Pitfall 6).
--   * 'Extrapolated': the reading used a real @atTick@, not the stored-value
--     sentinel — a live @feeGrowthInside@ extrapolation.
data PremiumFlag = ChunkEmpty | AccFrozen | Extrapolated
  deriving (Show, Eq, Ord)

-- ---------------------------------------------------------------------------
-- Accumulator arithmetic
-- ---------------------------------------------------------------------------

-- | @unchecked@ mod-2^128 accumulator difference. NEVER a bare @hi - lo@: the
-- accumulators are @uint128@ under Solidity @unchecked@ semantics, so a naive
-- 'Integer' subtraction returns a huge negative number whenever the value has
-- wrapped (RESEARCH Pitfall 3). Delegates to the single 'Chain.Abi.diffMod'.
accDelta :: Integer -> Integer -> Integer
accDelta hi lo = diffMod 128 hi lo

-- | Per-leg premium in token wei from two X64 accumulator readings, per
-- @PanopticPool._getPremia@ L2296-2298:
--
-- @
-- premiumWei accHi accLo L isLong = negate? ((accDelta accHi accLo) * L \`div\` 2^64)
-- @
--
-- The @2^64@ is the X64 accumulator scale (NOT @2^128@ = feeGrowth, NOT @2^96@ =
-- sqrtPrice). Result units are token wei; the @/1e18@ (ETH) or @/1e6@ (USDC)
-- conversion happens strictly downstream of the gate. Long legs negate; short
-- legs do not.
premiumWei :: Integer -> Integer -> Integer -> Bool -> Integer
premiumWei accHi accLo legLiquidity isLong =
  let d = accDelta accHi accLo
      p = (d * legLiquidity) `div` (2 ^ (64 :: Int))
  in if isLong then negate p else p

-- | Sum the consecutive-delta premia over a chain of accumulator readings
-- @a0, a1, …, aN@. For a monotone chain and a @legLiquidity@ that is a multiple
-- of @2^64@ (so no per-delta flooring loss), this equals @premiumWei aN a0 L s@
-- EXACTLY — the telescoping identity the reconciliation gate rests on (the panel
-- is a decomposition of the ground truth, not an independent estimate). The same
-- @L@ multiplies every delta, so there is no cross-term drift.
telescope :: [Integer] -> Integer -> Bool -> Integer
telescope readings legLiquidity isLong =
  sum (zipWith step readings (drop 1 readings))
  where
    step lo hi = premiumWei hi lo legLiquidity isLong

-- | True when an accumulator is within 1% of @2^128 - 1@ — the paired-freeze cap
-- (@LeftRightLibrary.addCapped@, RESEARCH Pitfall 6). Any observation whose
-- reading trips this must carry 'AccFrozen'.
isFrozenAcc :: Integer -> Bool
isFrozenAcc a = a >= (2 ^ (128 :: Int) - 1) * 99 `div` 100

-- | The Panoptic ν-multiplier as a 'Rational', for the Lean-vs-Panoptic
-- cross-walk (10-11) — @1 + ν·R/N@ for long legs, @1 + ν·R²/(N·T)@ for short
-- legs, with @ν = 1/8@ and @T = N + R@. This is NOT used to compute the premium
-- (the contract already bakes it into the accumulator); it exists solely to
-- REPORT the measured wedge distribution instead of asserting a bound. It equals
-- exactly @1@ when @R = 0@ and is bounded above by @1 + ν = 1.125@ on the long
-- side.
multiplierWedge :: Integer -> Integer -> Bool -> Rational
multiplierWedge removedLiq netLiq isLong
  | removedLiq == 0 = 1
  | isLong          = 1 + nu * r / n
  | otherwise       = 1 + nu * (r * r) / (n * t)
  where
    nu = 1 % 8
    r  = fromInteger removedLiq
    n  = fromInteger netLiq
    t  = fromInteger (netLiq + removedLiq)

-- ---------------------------------------------------------------------------
-- Fan-out
-- ---------------------------------------------------------------------------

-- | Fan the deduplicated, pool-wide chunk-level readings back out to per-leg,
-- per-epoch 'PremiumObs' by multiplying each chunk delta by that leg's
-- 'lcLiquidity'. For each 'LegChunk', the readings sharing its chunk and side
-- are ordered by epoch and every consecutive pair yields one observation tagged
-- to the ending epoch.
--
-- @poTokenId@ is left blank here: a 'LegChunk' carries no tokenId (the pool-wide
-- accumulator is shared across positions). The driver attaches the tokenId via
-- the @readScheduleRaw@ fan-out (whose @ReadRow@ retains @rrTokenId@); this
-- function owns only the delta → wei arithmetic and the flagging.
buildPremiumObs
  :: [LegChunk]
  -> Map (ChunkKey, Integer, Bool) AccReading
  -> [PremiumObs]
buildPremiumObs legChunks accMap =
  [ mkObs lc rLo rHi
  | lc <- legChunks
  , let readings = sortOn arEpoch
          [ r | ((ck, _ep, il), r) <- Map.toList accMap
              , ck == lcChunkKey lc, il == lcIsLong lc ]
  , (rLo, rHi) <- zip readings (drop 1 readings)
  ]
  where
    mkObs lc rLo rHi =
      PremiumObs
        { poTokenId     = ""
        , poLegIndex    = lcLegIndex lc
        , poEpoch       = arEpoch rHi
        , poPremiumWei0 = premiumWei (arAcc0 rHi) (arAcc0 rLo) (lcLiquidity lc) (lcIsLong lc)
        , poPremiumWei1 = premiumWei (arAcc1 rHi) (arAcc1 rLo) (lcLiquidity lc) (lcIsLong lc)
        , poIsLong      = lcIsLong lc
        , poStrikeTick  = lcStrike lc
        , poFlags       = flagsFor rHi
        }
    flagsFor r = concat
      [ [ChunkEmpty   | arNetLiquidity r == 0]
      , [AccFrozen    | isFrozenAcc (arAcc0 r) || isFrozenAcc (arAcc1 r)]
      , [Extrapolated | arAtTick r /= storedValueTick]
      ]
