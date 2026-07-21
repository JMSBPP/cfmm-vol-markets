{-# LANGUAGE OverloadedStrings #-}

-- | Chunk geometry and leg liquidity — the bridge from a subgraph @Leg@ record
-- to the exact @(tokenType, tickLower, tickUpper)@ chunk identity and the
-- @Integer@ liquidity multiplier that @SFPM.getAccountPremium@ and the premium
-- identity @premium = deltaAcc_X64 * L / 2^64@ require.
--
-- == Two non-obvious quantities
--
--   1. __The chunk key__ @(tokenType, tickLower, tickUpper)@ from
--      @PanopticMath.getTicks@ — with a __floor-down / ceil-up asymmetry__ that a
--      symmetric "±half-width" simplification silently breaks for odd
--      @width * tickSpacing@. The subgraph's own @Chunk.tickLower/tickUpper@ is
--      the AUTHORITY; 'getTicks' is the cross-check ('crossCheckChunks'), not the
--      other way round.
--   2. __The leg liquidity__ @L@ from @PanopticMath.getLiquidityChunk@. Get @L@
--      wrong and every premium is off by a constant factor per position — a
--      large, position-specific error the reconciliation gate would surface.
--
-- == No @Double@ upstream of the panel (RESEARCH anti-pattern)
--
-- Every quantity here is @Integer@: 'getSqrtRatioAtTick' is the exact Uniswap
-- @TickMath@ X96 value (a @Double@ carries 53 mantissa bits against a value near
-- @2^96@), and 'getLiquidityForAmount0'/'getLiquidityForAmount1' use floor
-- division on @Integer@ throughout, exactly as the on-chain @FullMath.mulDiv@.
--
-- == Single source of truth for the tick arithmetic (import-cycle note)
--
-- The floor/ceil range arithmetic has ONE implementation:
-- 'Panel.Subgraph.legChunkKey' (validated match-rate 1.0 against the live
-- @Chunk@ records at the 10-01 census). 'getTicks' / 'getRangesFromStrike' here
-- delegate to it, and 'legChunkKey' is re-exported, so the two can never
-- diverge. A literal move of the arithmetic into this module would form an
-- import cycle — @Panoptic.Chunk@ depends on @Panel.Subgraph@ for the @Leg@ /
-- @Chunk@ record types, so the base arithmetic must live in the leaf module.
module Panoptic.Chunk
  ( -- * Chunk identity
    ChunkKey (..)          -- ckTokenType, ckTickLower, ckTickUpper
  , legChunkKey            -- re-export of the canonical tuple geometry
    -- * Tick range (getTicks / getRangesFromStrike)
  , getRangesFromStrike    -- Int {-width-} -> Int {-tickSpacing-} -> (Int, Int)
  , getTicks               -- Int {-strike-} -> Int {-width-} -> Int {-tickSpacing-} -> (Int, Int)
  , crossCheckChunks       -- [Chunk] -> Int -> ([Chunk], [Chunk])
    -- * Liquidity (Integer arithmetic only)
  , getSqrtRatioAtTick     -- Int -> Integer   (X96)
  , getLiquidityForAmount0
  , getLiquidityForAmount1 -- Int -> Int -> Integer -> Integer
  , legLiquidity           -- Leg -> Integer {-positionSize-} -> Int {-tickSpacing-} -> Integer
    -- * Leg -> chunk resolution
  , LegChunk (..)          -- lcLegIndex, lcChunkKey, lcIsLong, lcLiquidity, lcStrike, lcWidth
  , resolveLegChunks       -- Int {-tickSpacing-} -> Integer {-positionSize-} -> [Leg] -> [LegChunk]
  ) where

import           Data.Bits   (shiftR, (.&.))
import           Data.List   (partition)

import           Panel.Subgraph (Chunk (..), Leg (..), legChunkKey)

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

-- | The @sqrtPriceX96@ scale @2^96@.
q96 :: Integer
q96 = 2 ^ (96 :: Int)

-- ---------------------------------------------------------------------------
-- Chunk identity
-- ---------------------------------------------------------------------------

-- | A pool-wide liquidity chunk identity: the tuple that keys the on-chain
-- premium accumulator. @owner@ is the @PanopticPool@ (not the user), so this
-- key is shared across every position in the chunk.
data ChunkKey = ChunkKey
  { ckTokenType :: !Int
  , ckTickLower :: !Int
  , ckTickUpper :: !Int
  }
  deriving (Show, Eq, Ord)

-- ---------------------------------------------------------------------------
-- Tick range (PanopticMath.getRangesFromStrike / getTicks)
-- ---------------------------------------------------------------------------

-- | @(rangeDown, rangeUp)@ for a leg width, mirroring
-- @PanopticMath.getRangesFromStrike@ (contracts L424-432):
--
-- @
-- rangeDown = (width * tickSpacing) \`div\` 2                -- FLOOR down
-- rangeUp   = (width * tickSpacing + 1) \`div\` 2            -- CEIL up
-- @
--
-- __ASYMMETRIC whenever @width * tickSpacing@ is odd__ (floor down, ceil up). Do
-- NOT "clean this up" into a symmetric @±(w*ts) \`div\` 2@ — that silently
-- mismatches every odd-span chunk. Delegates to 'legChunkKey' so the arithmetic
-- is defined exactly once (see the module header import-cycle note).
getRangesFromStrike :: Int -> Int -> (Int, Int)
getRangesFromStrike width tickSpacing =
  let (tl, tu) = getTicks 0 width tickSpacing
  in (negate tl, tu)

-- | @getTicks strike width tickSpacing = (strike - rangeDown, strike + rangeUp)@,
-- mirroring @PanopticMath.getTicks@ (contracts L406-416). The subgraph's own
-- @Chunk.tickLower/tickUpper@ is the authority; this is the cross-check
-- ('crossCheckChunks').
getTicks :: Int -> Int -> Int -> (Int, Int)
getTicks strike width tickSpacing =
  let (_, tl, tu) = legChunkKey strike width 0 tickSpacing
  in (tl, tu)

-- | Recompute @getTicks (chStrike c) (chWidth c) tickSpacing@ for each chunk and
-- partition into @(agrees with chTickLower\/chTickUpper, disagrees)@. The
-- subgraph record is the AUTHORITY — a non-empty mismatch list is a bug in this
-- module, never in the subgraph.
crossCheckChunks :: [Chunk] -> Int -> ([Chunk], [Chunk])
crossCheckChunks chunks tickSpacing = partition agrees chunks
  where
    agrees c = getTicks (chStrike c) (chWidth c) tickSpacing
                 == (chTickLower c, chTickUpper c)

-- ---------------------------------------------------------------------------
-- TickMath.getSqrtRatioAtTick (Integer / X96)
-- ---------------------------------------------------------------------------

-- | Uniswap @TickMath.getSqrtRatioAtTick@ in exact @Integer@ arithmetic,
-- returning the @sqrtPriceX96@ value (Q64.96). This is the bit-decomposition
-- constant table from @TickMath.sol@ verbatim, including the final
-- @(ratio >> 32) + roundUp@ step that converts Q128.128 to Q128.96.
--
-- @getSqrtRatioAtTick 0 == 2^96@ exactly, and the function is strictly monotone
-- increasing in @tick@. A @Double@ @1.0001 ** (tick\/2)@ approximation is
-- forbidden: 53 mantissa bits cannot represent a value near @2^96@ (RESEARCH
-- names @Double@ upstream of the panel as an anti-pattern).
getSqrtRatioAtTick :: Int -> Integer
getSqrtRatioAtTick tick =
  let absTick = abs tick
      r0 = if absTick .&. 0x1 /= 0
             then 0xfffcb933bd6fad37aa2d162d1a594001
             else 0x100000000000000000000000000000000
      ratioMag = foldl step r0 magic
        where
          step r (mask, factor) =
            if absTick .&. mask /= 0
              then (r * factor) `shiftR` 128
              else r
      -- for positive ticks the ratio is the reciprocal in Q128.128
      ratio = if tick > 0 then (2 ^ (256 :: Int) - 1) `div` ratioMag else ratioMag
      (q, m) = ratio `divMod` (2 ^ (32 :: Int))
  in q + (if m == 0 then 0 else 1)
  where
    -- (bit mask, Q128.128 factor) — TickMath.sol L112-131
    magic :: [(Int, Integer)]
    magic =
      [ (0x2,     0xfff97272373d413259a46990580e213a)
      , (0x4,     0xfff2e50f5f656932ef12357cf3c7fdcc)
      , (0x8,     0xffe5caca7e10e4e61c3624eaa0941cd0)
      , (0x10,    0xffcb9843d60f6159c9db58835c926644)
      , (0x20,    0xff973b41fa98c081472e6896dfb254c0)
      , (0x40,    0xff2ea16466c96a3843ec78b326b52861)
      , (0x80,    0xfe5dee046a99a2a811c461f1969c3053)
      , (0x100,   0xfcbe86c7900a88aedcffc83b479aa3a4)
      , (0x200,   0xf987a7253ac413176f2b074cf7815e54)
      , (0x400,   0xf3392b0822b70005940c7a398e4b70f3)
      , (0x800,   0xe7159475a2c29b7443b29c7fa6e889d9)
      , (0x1000,  0xd097f3bdfd2022b8845ad8f792aa5825)
      , (0x2000,  0xa9f746462d870fdf8a65dc1f90e061e5)
      , (0x4000,  0x70d869a156d2a1b890bb3df62baf32f7)
      , (0x8000,  0x31be135f97d08fd981231505542fcfa6)
      , (0x10000, 0x9aa508b5b7a84e1c677de54f3e99bc9)
      , (0x20000, 0x5d6af8dedb81196699c329225ee604)
      , (0x40000, 0x2216e584f5fa1ea926041bedfe98)
      , (0x80000, 0x48a170391f7dc42444e8fa2)
      ]

-- ---------------------------------------------------------------------------
-- LiquidityAmounts (Integer, floor division)
-- ---------------------------------------------------------------------------

-- | @L@ from @amount0@ over @[tickLower, tickUpper]@, mirroring Uniswap
-- @LiquidityAmounts.getLiquidityForAmount0@:
--
-- @
-- intermediate = sqrtA * sqrtB \`div\` Q96
-- L            = amount0 * intermediate \`div\` (sqrtB - sqrtA)
-- @
--
-- All @Integer@, all floor division (as @FullMath.mulDiv@). The two ticks are
-- ordered internally, so passing them out of order is safe.
getLiquidityForAmount0 :: Int -> Int -> Integer -> Integer
getLiquidityForAmount0 tickLower tickUpper amount0 =
  let (sqrtA, sqrtB) = orderedSqrt tickLower tickUpper
      intermediate   = (sqrtA * sqrtB) `div` q96
  in (amount0 * intermediate) `div` (sqrtB - sqrtA)

-- | @L@ from @amount1@ over @[tickLower, tickUpper]@, mirroring Uniswap
-- @LiquidityAmounts.getLiquidityForAmount1@:
--
-- @L = amount1 * Q96 \`div\` (sqrtB - sqrtA)@ — @Integer@, floor division.
getLiquidityForAmount1 :: Int -> Int -> Integer -> Integer
getLiquidityForAmount1 tickLower tickUpper amount1 =
  let (sqrtA, sqrtB) = orderedSqrt tickLower tickUpper
  in (amount1 * q96) `div` (sqrtB - sqrtA)

-- | The two tick sqrt-ratios in ascending order (@sqrtA < sqrtB@).
orderedSqrt :: Int -> Int -> (Integer, Integer)
orderedSqrt tickLower tickUpper =
  let a = getSqrtRatioAtTick tickLower
      b = getSqrtRatioAtTick tickUpper
  in if a > b then (b, a) else (a, b)

-- | Leg liquidity @L@ = @PanopticMath.getLiquidityChunk@ (contracts L358-398):
--
-- @
-- amount = positionSize * optionRatio
-- L      = getLiquidityForAmount0 tickLower tickUpper amount   if asset == 0 (token0)
--        = getLiquidityForAmount1 tickLower tickUpper amount   otherwise     (token1)
-- @
--
-- @positionSize@ is the leg's @PositionBalance@ as an @Integer@ (the underlying
-- value is an integer that the subgraph surfaces as a JSON number; callers
-- @round@ @MintEvent.mePositionSize@ to @Integer@ at the boundary — no @Double@
-- crosses into this module). The token side is taken from the leg's @asset@
-- selector ('legAsset'), never guessed.
legLiquidity :: Leg -> Integer -> Int -> Integer
legLiquidity leg positionSize tickSpacing =
  let (tickLower, tickUpper) = getTicks (legStrikeTick leg) (legWidth leg) tickSpacing
      amount = positionSize * fromIntegral (legOptionRatio leg)
  in if legAsset leg == 0
       then getLiquidityForAmount0 tickLower tickUpper amount
       else getLiquidityForAmount1 tickLower tickUpper amount

-- ---------------------------------------------------------------------------
-- Leg -> chunk resolution
-- ---------------------------------------------------------------------------

-- | One resolved leg: its chunk identity, side, liquidity, and — crucially — its
-- ORIGINAL leg index (retained across the @width == 0@ filter so multi-leg
-- reconciliation can match leg counts, RESEARCH Pitfall 7).
data LegChunk = LegChunk
  { lcLegIndex  :: !Int
  , lcChunkKey  :: !ChunkKey
  , lcIsLong    :: !Bool
  , lcLiquidity :: !Integer
  , lcStrike    :: !Int
  , lcWidth     :: !Int
  }
  deriving (Show, Eq)

-- | Resolve every leg of a position to its 'LegChunk', __dropping every leg with
-- @legWidth == 0@__ — @PanopticPool._getPremia@ (L2250) skips such legs, so they
-- accrue nothing and including them would inject structural zeros into the
-- panel. The original leg index is preserved in 'lcLegIndex'.
resolveLegChunks :: Int -> Integer -> [Leg] -> [LegChunk]
resolveLegChunks tickSpacing positionSize legs =
  [ LegChunk
      { lcLegIndex  = i
      , lcChunkKey  = ChunkKey (legTokenType leg) tickLower tickUpper
      , lcIsLong    = legIsLong leg
      , lcLiquidity = legLiquidity leg positionSize tickSpacing
      , lcStrike    = legStrikeTick leg
      , lcWidth     = legWidth leg
      }
  | (i, leg) <- zip [0 ..] legs
  , legWidth leg /= 0            -- PanopticPool._getPremia L2250 skips width==0 legs
  , let (tickLower, tickUpper) = getTicks (legStrikeTick leg) (legWidth leg) tickSpacing
  ]
