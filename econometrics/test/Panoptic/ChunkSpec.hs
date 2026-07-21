{-# LANGUAGE OverloadedStrings #-}

-- | Offline specs for 'Panoptic.Chunk' (plan 10-04).
--
-- The load-bearing case is 'crossCheckChunks' against the FROZEN
-- @test/fixtures/chunks-sample.json@ (frozen in 10-01): every subgraph @Chunk@
-- record must reproduce its own @tickLower@\/@tickUpper@ from @(strike, width)@
-- under 'getTicks' at @tickSpacing = 10@. No network.
module Panoptic.ChunkSpec (spec) where

import qualified Data.ByteString.Lazy as BL
import           Test.Hspec

import           Panel.Subgraph  (Leg (..), parseChunks)
import           Panoptic.Chunk

-- Market tick spacing (poolKey fee = 500).
ts :: Int
ts = 10

-- | A leg carrying only the fields the geometry\/liquidity path reads.
mkLeg :: Int -> Int -> Int -> Int -> Leg
mkLeg strike width optionRatio asset =
  Leg { legStrikeTick  = strike
      , legWidth       = width
      , legIsLong      = False
      , legTokenType   = asset
      , legOptionRatio = optionRatio
      , legAsset       = asset
      }

-- | Representative substantial @(strike, width, optionRatio, positionSize)@ rows
-- drawn from the 10-01 census
-- (notes/structural-econometrcics/data/chunk-legs.csv); positionSize rounded to
-- 'Integer'. These carry enough underlying to yield strictly-positive liquidity
-- on EITHER token side.
censusRows :: [(Int, Int, Int, Integer)]
censusRows =
  [ (-199920, 240, 1, 1000000000000000)   -- 1.0e15
  , (-198960, 240, 1, 1000000000000000)
  , (-200160, 240, 1, 1000000000000000)
  , (-197460, 240, 1, 10000)
  , (-198480, 480, 1, 100000)
  , (-202410,  10, 1, 2068262194104)       -- 2.068262194104e12
  , (-202990,  10, 1, 5671689603391)
  ]

spec :: Spec
spec = do
  describe "getTicks" $ do
    it "is symmetric for EVEN width*tickSpacing" $
      -- 240 * 10 = 2400 (even) -> rangeDown == rangeUp == 1200
      getTicks (-199680) 240 ts `shouldBe` (-200880, -198480)

    it "is floor-down / ceil-up ASYMMETRIC for odd width*tickSpacing" $ do
      -- 3 * 1 = 3 (odd): rangeDown = 1, rangeUp = 2
      let (lo, hi) = getTicks 100 3 1
      (100 - lo) `shouldBe` 1
      (hi - 100) `shouldBe` 2
      -- tickUpper exceeds strike by exactly one more than strike exceeds tickLower
      ((hi - 100) - (100 - lo)) `shouldBe` 1

    it "getRangesFromStrike agrees with getTicks (floor down, ceil up)" $ do
      getRangesFromStrike 240 ts `shouldBe` (1200, 1200)
      getRangesFromStrike 3 1    `shouldBe` (1, 2)

    it "reproduces EVERY frozen Chunk record's tick range (match rate 1.0)" $ do
      bytes  <- BL.readFile "test/fixtures/chunks-sample.json"
      chunks <- either (fail . ("parseChunks: " ++)) pure (parseChunks bytes)
      let (matching, mismatching) = crossCheckChunks chunks ts
      -- an empty fixture must FAIL, not vacuously pass
      length chunks    `shouldSatisfy` (> 0)
      length matching  `shouldSatisfy` (> 0)
      mismatching      `shouldBe` []

  describe "getSqrtRatioAtTick" $ do
    it "equals 2^96 exactly at tick 0" $
      getSqrtRatioAtTick 0 `shouldBe` (2 ^ (96 :: Int))

    it "is strictly monotone increasing across the tick list" $ do
      let tickList = [-887272, -200423, -199680, -1, 0, 1, 887272]
          ratios   = map getSqrtRatioAtTick tickList
      and (zipWith (<) ratios (drop 1 ratios)) `shouldBe` True

  describe "legLiquidity" $ do
    it "is a strictly positive Integer for every substantial positionSize row" $ do
      let ls = [ legLiquidity (mkLeg s w r 0) ps ts | (s, w, r, ps) <- censusRows ]
      ls `shouldSatisfy` all (> 0)
      -- exercise the token1 branch too
      let ls1 = [ legLiquidity (mkLeg s w r 1) ps ts | (s, w, r, ps) <- censusRows ]
      ls1 `shouldSatisfy` all (> 0)

    it "is non-negative even for a degenerate positionSize (floor to 0, as on-chain)" $ do
      -- positionSize == 1 over a token0-selected 100-tick chunk floors to L == 0:
      -- this is Panoptic's exact getLiquidityChunk floor division, NOT a bug.
      legLiquidity (mkLeg (-201880) 10 1 0) 1 ts `shouldBe` 0
      legLiquidity (mkLeg (-201880) 10 1 0) 1 ts `shouldSatisfy` (>= 0)

    it "scales linearly in optionRatio (up to floor rounding of at most 1)" $ do
      let deltas =
            [ let l1 = legLiquidity (mkLeg s w 1 a) ps ts
                  l2 = legLiquidity (mkLeg s w 2 a) ps ts
              in l2 - 2 * l1
            | (s, w, _, ps) <- censusRows, a <- [0, 1] ]
      deltas `shouldSatisfy` all (\d -> d >= 0 && d <= 1)

  describe "resolveLegChunks" $ do
    it "drops every leg with width == 0 and retains the rest" $ do
      let legs = [ mkLeg (-199680) 240 1 0    -- kept
                 , mkLeg (-199680)   0 1 0    -- dropped (width 0)
                 , mkLeg (-198480) 240 1 0 ]  -- kept
          resolved = resolveLegChunks ts 1000000000000000 legs
      map lcLegIndex resolved `shouldBe` [0, 2]   -- original indices preserved
      map lcWidth resolved    `shouldSatisfy` all (/= 0)

    it "returns one chunk key per non-zero-width leg, preserving order" $ do
      let legs = [ mkLeg (-199680) 240 1 0
                 , mkLeg (-198480) 240 1 0
                 , mkLeg (-200160) 240 1 0
                 , mkLeg (-197460) 240 1 0 ]
          resolved = resolveLegChunks ts 1000000000000000 legs
      length resolved            `shouldBe` 4
      map lcLegIndex resolved    `shouldBe` [0, 1, 2, 3]
      map (ckTickLower . lcChunkKey) resolved
        `shouldBe` [ -200880, -199680, -201360, -198660 ]
