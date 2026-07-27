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
  , decomposePremium -- [Integer] -> Integer -> Bool -> [Integer]  (EXACT decomposition)
    -- * Fan-out
  , buildPremiumObs -- [LegChunk] -> Map (ChunkKey, Integer, Bool) AccReading -> [PremiumObs]
  , premiumObsChain -- Text -> LegChunk -> [AccReading] -> [PremiumObs]
  , buildSpellPremiumObs
  ) where

import           Data.List       (nub, sort, sortOn)
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

-- | __The EXACT per-interval decomposition__ of a chain of accumulator readings
-- @a0, a1, …, aN@ into @N@ premium increments in token wei.
--
-- @
-- sum (decomposePremium [a0..aN] L s) == premiumWei aN a0 L s     -- ALWAYS, for any L
-- @
--
-- == Why this is not @zipWith premiumWei@ ('telescope')
--
-- 'telescope' floors EACH interval separately:
-- @Σ_k floor(Δ_k · L / 2^64)@. Summing floors is not the floor of the sum, so it
-- undershoots @floor((Σ_k Δ_k) · L / 2^64)@ by up to @N − 1@ wei — exact only
-- when @L@ is a multiple of @2^64@, which the real leg liquidities are not.
--
-- A sub-wei-per-interval discrepancy is numerically trivial and
-- __methodologically fatal__: the whole claim licensing this panel is that it is
-- a /decomposition/ of the gate-validated ground truth, so its rows must sum back
-- to that ground truth EXACTLY, not approximately. \"Close enough\" would make
-- the 10-08 gate result non-transferable to the panel.
--
-- So the increments are taken as differences of the CUMULATIVE premium measured
-- from the chain's first reading:
--
-- @
-- P_k = ((a_k - a_0) \`mod\` 2^128) * L \`div\` 2^64        -- negated for long legs
-- increment_k = P_k - P_(k-1)
-- @
--
-- which telescopes to @P_N − P_0 = P_N@ identically, whatever @L@ is. Each
-- increment is still the correctly-rounded premium accrued over its interval; the
-- flooring residue is carried forward instead of being discarded @N@ times.
--
-- Chains of 0 or 1 reading decompose to @[]@ — no interval, therefore no premium,
-- never a fabricated zero.
decomposePremium :: [Integer] -> Integer -> Bool -> [Integer]
decomposePremium readings legLiquidity isLong = case readings of
  []       -> []
  (a0 : _) ->
    let cum a = premiumWei a a0 legLiquidity isLong   -- P_k, exact, mod-2^128 inside
        ps    = map cum readings                      -- P_0 = 0, P_1, …, P_N
    in zipWith subtract ps (drop 1 ps)

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

-- | One leg's readings → its per-epoch 'PremiumObs', using the EXACT
-- 'decomposePremium' and the ACCRUAL-INTERVAL epoch convention.
--
-- == The epoch a premium belongs to (plan 10-09; this CORRECTS 'buildPremiumObs')
--
-- 'buildPremiumObs' tags each delta with @arEpoch@ of the LATER reading (\"the
-- ENDING epoch\", the 09-04 convention). On the hourly grid that is off by one
-- window, and it would de-align the panel from σ̂² in exactly the way the 09-05
-- 40587-offset trap did:
--
-- @Chain.BlockIndex@ maps epoch @e@ to the first block at or after @e * 3600@ —
-- the START of hour @e@. So the accumulator difference between the boundary of
-- @e@ and the boundary of @e+1@ is the premium that accrued DURING hour @e@,
-- while @σ̂²_e@ is the realized variance measured over that same hour @e@. Tagging
-- the difference @e+1@ would regress hour @e@'s premium on hour @e+1@'s variance.
--
-- This function therefore tags each interval with the epoch of its STARTING
-- reading, which is the epoch the premium actually accrued in. It holds at the
-- spell endpoints too: the mint-block reading sits inside hour @m@ and its
-- interval runs to the boundary of @m+1@, so the partial hour is attributed to
-- @m@; the last interval runs from the boundary of @n@ to the burn block inside
-- hour @n@ and is attributed to @n@.
--
-- 'buildPremiumObs' is left exactly as 10-05 wrote it (its ending-epoch tag is
-- harmless for the fan-out shape it is tested on, and "Panoptic.PremiumSpec"
-- pins it).
--
-- Readings are ordered by BLOCK, not by epoch: two readings can share an epoch (a
-- mint landing on an hour boundary), and block order is the physical order in
-- which the accumulator advanced.
--
-- Flags are taken from BOTH endpoints of the interval, because either one can be
-- the reading that makes the difference ambiguous.
premiumObsChain :: Text -> LegChunk -> [AccReading] -> [PremiumObs]
premiumObsChain tokenId lc readings =
  [ PremiumObs
      { poTokenId     = tokenId
      , poLegIndex    = lcLegIndex lc
      , poEpoch       = arEpoch rLo          -- the epoch the premium ACCRUED IN
      , poPremiumWei0 = w0
      , poPremiumWei1 = w1
      , poIsLong      = lcIsLong lc
      , poStrikeTick  = lcStrike lc
      , poFlags       = nubSort (flagsOf rLo ++ flagsOf rHi)
      }
  | ((rLo, rHi), w0, w1) <- zip3 pairs wei0 wei1
  ]
  where
    ordered = sortOn arBlock readings
    pairs   = zip ordered (drop 1 ordered)
    wei0    = decomposePremium (map arAcc0 ordered) (lcLiquidity lc) (lcIsLong lc)
    wei1    = decomposePremium (map arAcc1 ordered) (lcLiquidity lc) (lcIsLong lc)
    flagsOf r = concat
      [ [ChunkEmpty   | arNetLiquidity r == 0]
      , [AccFrozen    | isFrozenAcc (arAcc0 r) || isFrozenAcc (arAcc1 r)]
      , [Extrapolated | arAtTick r /= storedValueTick]
      ]
    nubSort = nub . sort

-- | Every leg of ONE spell → its per-epoch 'PremiumObs', restricted to the
-- spell's own @[mintBlock, burnBlock]@ block window.
--
-- The window restriction is load-bearing. The chunk accumulator is __pool-wide__
-- (@owner@ = the PanopticPool), so the reading cache holds readings for OTHER
-- positions' windows in the same chunk. Including them would attribute premium to
-- a position that did not hold the leg, and would break the sum-back-to-the-gate
-- identity.
--
-- Returns @(observations, legs that could not be decomposed)@. A leg with fewer
-- than two readings inside its window yields NO observation and is COUNTED — a
-- hole in the reading cache must be visible, never a silent zero (RESEARCH
-- Pitfall 5).
--
-- Summing @poPremiumWei0@ over everything this returns equals, EXACTLY, the
-- endpoint reconstruction the 10-08 gate scored:
-- @Σ_legs premiumWei acc(burnBlock) acc(mintBlock) L isLong@ — provided the
-- window's first and last readings are the mint- and burn-block ones, which the
-- 10-06 schedule guarantees by construction (it reads both endpoints explicitly).
buildSpellPremiumObs
  :: Text                              -- ^ tokenId.
  -> (Integer, Integer)                -- ^ @(mintBlock, burnBlock)@, inclusive.
  -> [LegChunk]                        -- ^ the position's resolved legs.
  -> Map (ChunkKey, Bool) [AccReading] -- ^ pool-wide readings, grouped by (chunk, side).
  -> ([PremiumObs], Int)
buildSpellPremiumObs tokenId (mintBlock, burnBlock) legChunks byChunk =
  (concat obsPerLeg, length [ () | c <- chains, length c < 2 ])
  where
    chains =
      [ dedupOnBlock
          [ r | r <- Map.findWithDefault [] (lcChunkKey lc, lcIsLong lc) byChunk
              , arBlock r >= mintBlock, arBlock r <= burnBlock ]
      | lc <- legChunks ]
    obsPerLeg = zipWith (premiumObsChain tokenId) legChunks chains

    -- One reading per block. The 10-06 schedule can carry BOTH an interior
    -- epoch-boundary row and a spell-endpoint row at the same block (a mint that
    -- lands exactly on an hour boundary); the endpoint-tagged row is preferred,
    -- mirroring 'Panel.Reconcile.lookupAt', so the panel's chain starts and ends
    -- on exactly the readings the gate scored.
    dedupOnBlock rs =
      Map.elems (Map.fromListWith preferEndpoint [ (arBlock r, r) | r <- sortOn arBlock rs ])
    preferEndpoint new old = case arEndpoint old of
      Just _  -> old
      Nothing -> new
