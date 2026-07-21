{-# LANGUAGE OverloadedStrings #-}

-- | Offline specs for 'Panoptic.Chunk' (plan 10-04).
--
-- The load-bearing case is 'crossCheckChunks' against the FROZEN
-- @test/fixtures/chunks-sample.json@ (frozen in 10-01): every subgraph @Chunk@
-- record must reproduce its own @tickLower@\/@tickUpper@ from @(strike, width)@
-- under 'getTicks' at @tickSpacing = 10@. No network.
module Panoptic.ChunkSpec (spec) where

import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict      as Map
import           Data.Maybe           (isJust, isNothing)
import           Data.Text            (Text)
import           Test.Hspec

import           Chain.BlockIndex (EpochBlock (..))
import           Panel.Subgraph   (BurnEvent (..), Leg (..), MintEvent (..),
                                   parseChunks)
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

-- | A mint at a given block and pool tick (other fields irrelevant to the
-- schedule, which takes resolved legs directly).
mkMint :: Text -> Integer -> Int -> MintEvent
mkMint tid blk tick = MintEvent tid "acct" 0 blk tick 0

-- | A burn at a given block and pool tick.
mkBurn :: Text -> Integer -> Int -> BurnEvent
mkBurn tid blk tick = BurnEvent tid "acct" 0 blk tick 0 0 0

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

  describe "read schedule" $ do
    -- Synthetic block index: epochs 100..105 at blocks 1000,1100,..,1500.
    let blockIx = Map.fromList
          [ (e, EpochBlock e (fromIntegral (1000 + (e - 100) * 100)) 0)
          | e <- [100 .. 105] ]
        tickIx  = Map.fromList [ (e, -200000 - (e - 100)) | e <- [100 .. 105] ]
        legA    = mkLeg (-199680) 240 1 0     -- shared between spells A and C
        legsB   = [ mkLeg (-198480) 240 1 0   -- kept
                  , mkLeg (-199680)   0 1 0 ]  -- width 0 -> dropped
        chunksA = resolveLegChunks ts 1000000000000000 [legA]
        chunksB = resolveLegChunks ts 1000000000000000 legsB
        -- (tokenId, mint block/tick, burn block/tick, resolved legs)
        spellA  = ("A", mkMint "A" 1050 (-200000), mkBurn "A" 1350 (-200100), chunksA)
        spellB  = ("B", mkMint "B" 1050 (-200000), mkBurn "B" 1150 (-200050), chunksB)
        spellC  = ("C", mkMint "C" 1050 (-200000), mkBurn "C" 1350 (-200100), chunksA)

    it "emits one interior row per (leg, epoch) for epochs in [mint..burn]" $ do
      let rows      = buildReadSchedule blockIx tickIx [spellA]
          interior  = filter (isNothing . rrEndpoint) rows
      -- epochs whose boundary block lies in [1050, 1350] = 101, 102, 103
      map rrEpoch interior     `shouldBe` [101, 102, 103]
      map rrBlock interior     `shouldBe` [1100, 1200, 1300]
      -- interior atTick comes from the tick index, never the stored-value sentinel
      map rrAtTick interior    `shouldBe` [-200001, -200002, -200003]

    it "emits the two exact-block spell endpoints, tagged mint/burn" $ do
      let rows      = buildReadSchedule blockIx tickIx [spellA]
          endpoints = filter (isJust . rrEndpoint) rows
      map rrEndpoint endpoints `shouldBe` [Just "mint", Just "burn"]
      map rrBlock endpoints    `shouldBe` [1050, 1350]
      map rrAtTick endpoints   `shouldBe` [-200000, -200100]

    it "excludes width == 0 legs entirely" $ do
      let rows = buildReadSchedule blockIx tickIx [spellB]
      -- only the kept (width 240) chunk appears; no degenerate zero-width chunk
      rows `shouldSatisfy` all (\r -> ckTickLower (rrChunkKey r)
                                        <  ckTickUpper (rrChunkKey r))
      -- the kept chunk of B is getTicks (-198480) 240 -> (-199680, -197280)
      map (ckTickLower . rrChunkKey) rows `shouldSatisfy` all (== (-199680))

    it "dedups distinct (chunk, block, isLong, atTick) reads across spells" $ do
      -- A and C share one chunk over identical blocks: raw fans out to 2x, the
      -- pool-wide dedup collapses them back to one read each.
      let raw   = readScheduleRaw   blockIx tickIx [spellA, spellC]
          sched = buildReadSchedule blockIx tickIx [spellA, spellC]
      length raw   `shouldBe` 10    -- (3 interior + 2 endpoint) x 2 spells
      length sched `shouldBe` 5     -- deduplicated to a single spell's worth
      -- and the DISTINCT read count stays well within the RESEARCH ~15000 budget
      length sched `shouldSatisfy` (< 15000)
