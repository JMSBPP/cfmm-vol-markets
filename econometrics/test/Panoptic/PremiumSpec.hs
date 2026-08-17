{-# LANGUAGE OverloadedStrings #-}

-- | Offline specs for 'Panoptic.Premium': the X64 scaling and long-leg sign of
-- 'premiumWei', mod-2^128 accumulator 'accDelta' wraparound, the EXACT
-- telescoping identity the reconciliation gate rests on, the freeze/empty-chunk
-- flags, and the ν-multiplier wedge. Synthetic accumulator chains plus one case
-- built from the frozen @premium-acc-golden.json@ readings. No network access.
--
-- @describe@ titles: @"premium sign"@, @"telescoping"@, @"wraparound"@ (the
-- validation map's @--ta -m@ filters).
module Panoptic.PremiumSpec (spec) where

import           Data.Aeson (Value, eitherDecodeFileStrict)
import qualified Data.Aeson.Types as AT
import qualified Data.Map.Strict  as Map
import           Data.Ratio       ((%))
import           Data.Text        (Text)
import qualified Data.Text        as T
import           Test.Hspec

import           Chain.Abi      (bytesToInteger, hexToBytes)
import           Panoptic.Chunk (ChunkKey (..), LegChunk (..))
import           Panoptic.Premium

goldenPath :: FilePath
goldenPath = "test/fixtures/premium-acc-golden.json"

-- 2^64 and 2^128 as reusable Integers.
q64, q128 :: Integer
q64  = 2 ^ (64 :: Int)
q128 = 2 ^ (128 :: Int)

spec :: Spec
spec = do

  describe "premium sign" $ do
    -- A short leg is positive; the SAME inputs on a long leg are its negation.
    let accHi = 47 * q64 + 3
        accLo = 12 * q64 + 1
        l     = 5 :: Integer

    it "a short leg (isLong = False) returns a positive wei value" $
      premiumWei accHi accLo l False `shouldSatisfy` (> 0)

    it "a long leg (isLong = True) returns exactly the negation of the short leg" $
      premiumWei accHi accLo l True `shouldBe` negate (premiumWei accHi accLo l False)

    it "matches the closed form ((accHi - accLo) mod 2^128) * L div 2^64" $
      premiumWei accHi accLo l False
        `shouldBe` (accDelta accHi accLo * l) `div` q64

    it "uses the X64 scale, not X128: L = 2^64 recovers the raw delta" $
      premiumWei accHi accLo q64 False `shouldBe` accDelta accHi accLo

  describe "wraparound" $ do
    it "accDelta is mod-2^128: accLo near the cap, accHi wrapped past it, yields a small positive" $ do
      let d = accDelta 5 (q128 - 3)   -- (5 - (2^128 - 3)) mod 2^128 = 8
      d `shouldBe` 8
      d `shouldSatisfy` (> 0)

    it "the wrapped delta is never ~1.15e77 and never negative" $ do
      let d = accDelta 5 (q128 - 3)
      d `shouldSatisfy` (< q128)
      d `shouldSatisfy` (>= 0)

    it "premiumWei over a wrapped delta is a small positive, not a garbage magnitude" $ do
      let p = premiumWei 5 (q128 - 3) q64 False   -- delta 8, L = 2^64 -> 8 wei
      p `shouldBe` 8

  describe "telescoping" $ do
    -- With L a multiple of 2^64 there is no per-delta flooring loss, so the
    -- decomposition is EXACT for any monotone chain (the gate's legitimacy).
    let a0    = 100 * q64
        aN    = 4096 * q64
        chain = [a0, 250 * q64 + 7, 900 * q64 + 3, 1500 * q64 + 42, aN]
        l     = 3 * q64 :: Integer

    it "sum of consecutive-delta premia equals the endpoint premium EXACTLY (short)" $
      telescope chain l False
        `shouldBe` premiumWei aN a0 l False

    it "holds EXACTLY on the long side too (both sides negate consistently)" $
      telescope chain l True
        `shouldBe` premiumWei aN a0 l True

    it "is exact for L = 2^64 (delta sum telescopes to the endpoint difference)" $
      telescope chain q64 False
        `shouldBe` accDelta aN a0

    it "a single-reading chain contributes zero" $
      telescope [42 * q64] l False `shouldBe` 0

  -- 10-09: the panel is licensed ONLY as a decomposition of the gate-validated
  -- endpoint total, so its per-epoch rows must sum back to that total EXACTLY —
  -- for the REAL leg liquidities, which are not multiples of 2^64.
  describe "exact decomposition" $ do
    let a0    = 100 * q64 + 17
        chain = [a0, 250 * q64 + 7, 900 * q64 + 3, 1500 * q64 + 42, 4096 * q64 + 5]
        aN    = last chain
        -- A REAL leg liquidity from chunk-legs.csv, deliberately NOT a multiple
        -- of 2^64: this is exactly the case 'telescope' cannot handle.
        lReal = 761939137362 :: Integer

    it "sums to the endpoint premium EXACTLY for a liquidity that is not a multiple of 2^64" $
      sum (decomposePremium chain lReal False) `shouldBe` premiumWei aN a0 lReal False

    it "holds EXACTLY on the long side" $
      sum (decomposePremium chain lReal True) `shouldBe` premiumWei aN a0 lReal True

    it "yields one increment per interval" $
      length (decomposePremium chain lReal False) `shouldBe` length chain - 1

    -- The motivating defect, demonstrated rather than asserted: per-interval
    -- flooring loses wei, and the loss is bounded by the number of intervals.
    it "telescope UNDERSHOOTS for such a liquidity, which is why this exists" $ do
      let viaTelescope = telescope chain lReal False
          exact        = premiumWei aN a0 lReal False
      viaTelescope `shouldSatisfy` (< exact)
      (exact - viaTelescope) `shouldSatisfy` (<= fromIntegral (length chain - 1))

    it "agrees with telescope when L IS a multiple of 2^64 (no flooring residue)" $
      decomposePremium chain q64 False
        `shouldBe` zipWith (\lo hi -> premiumWei hi lo q64 False) chain (drop 1 chain)

    it "a chain of 0 or 1 readings decomposes to no intervals (never a fabricated zero)" $ do
      decomposePremium []          lReal False `shouldBe` []
      decomposePremium [42 * q64]  lReal False `shouldBe` []

  -- The accrual-interval epoch convention. Chain.BlockIndex maps epoch e to the
  -- block at the START of e, so the delta between boundary(e) and boundary(e+1)
  -- is the premium that accrued DURING hour e and must be tagged e — not e+1, or
  -- the panel regresses hour e's premium on hour e+1's variance.
  describe "accrual-interval epoch tagging" $ do
    let ck  = ChunkKey 0 (-199680) (-197280)
        lc  = LegChunk 0 ck False q64 (-198000) 240
        r e a = (mkReading e a 10) { arBlock = e }
        chain = [r 100 (5 * q64), r 101 (9 * q64), r 102 (20 * q64)]

    it "tags each interval with the epoch it ACCRUED IN (the starting reading)" $
      map poEpoch (premiumObsChain "tok" lc chain) `shouldBe` [100, 101]

    it "carries the tokenId the pool-wide fan-out cannot know" $
      map poTokenId (premiumObsChain "tok" lc chain) `shouldBe` ["tok", "tok"]

    it "orders by BLOCK, not by list order, and sums to the endpoint premium" $ do
      let shuffled = [chain !! 2, chain !! 0, chain !! 1]
          os       = premiumObsChain "tok" lc shuffled
      map poEpoch os `shouldBe` [100, 101]
      sum (map poPremiumWei0 os) `shouldBe` premiumWei (20 * q64) (5 * q64) q64 False

    it "unions the flags of BOTH endpoints of an interval" $ do
      let withEmpty = [ r 100 (5 * q64), (r 101 (9 * q64)) { arNetLiquidity = 0 } ]
      case premiumObsChain "tok" lc withEmpty of
        [o] -> poFlags o `shouldContain` [ChunkEmpty]
        _   -> expectationFailure "expected exactly one observation"

  -- The chunk accumulator is POOL-WIDE, so the reading cache holds other
  -- positions' windows in the same chunk. Attributing those to this position
  -- would both invent premium and break the sum-back-to-the-gate identity.
  describe "spell window restriction" $ do
    let ck  = ChunkKey 0 (-199680) (-197280)
        lc  = LegChunk 0 ck False q64 (-198000) 240
        r e a = (mkReading e a 10) { arBlock = e }
        pool  = [ r 98 q64, r 99 (2 * q64)          -- before the mint (another position)
                , r 100 (5 * q64), r 101 (9 * q64), r 102 (20 * q64)
                , r 103 (99 * q64) ]                -- after the burn (another position)
        byChunk = Map.fromList [((ck, False), pool)]

    it "uses only readings inside [mintBlock, burnBlock]" $ do
      let (os, holes) = buildSpellPremiumObs "tok" (100, 102) [lc] byChunk
      holes `shouldBe` 0
      map poEpoch os `shouldBe` [100, 101]
      sum (map poPremiumWei0 os)
        `shouldBe` premiumWei (20 * q64) (5 * q64) q64 False

    it "COUNTS a leg whose window holds fewer than two readings instead of zeroing it" $ do
      let (os, holes) = buildSpellPremiumObs "tok" (100, 100) [lc] byChunk
      os    `shouldBe` []
      holes `shouldBe` 1

    it "prefers the spell-endpoint row when two readings share a block" $ do
      let dup = [ (r 100 (5 * q64)) { arEndpoint = Just "mint" }
                , (r 100 (77 * q64))                       -- interior row, same block
                , r 101 (9 * q64) ]
          (os, _) = buildSpellPremiumObs "tok" (100, 101) [lc]
                      (Map.fromList [((ck, False), dup)])
      sum (map poPremiumWei0 os)
        `shouldBe` premiumWei (9 * q64) (5 * q64) q64 False

  describe "frozen and empty-chunk detection" $ do
    it "isFrozenAcc is True within 1% of 2^128 - 1, False well below" $ do
      isFrozenAcc (q128 - 1)          `shouldBe` True
      isFrozenAcc ((q128 - 1) * 995 `div` 1000) `shouldBe` True
      isFrozenAcc (q128 `div` 2)      `shouldBe` False
      isFrozenAcc 0                   `shouldBe` False

    it "a PremiumObs from a netLiquidity == 0 reading carries ChunkEmpty" $ do
      let lc  = LegChunk 0 (ChunkKey 0 (-199680) (-197280)) False 1000 (-198000) 240
          rLo = mkReading 100 (5 * q64)  10  -- netLiq 10
          rHi = mkReading 101 (9 * q64)  0   -- netLiq 0 -> ChunkEmpty
          m   = Map.fromList (buildMap (ChunkKey 0 (-199680) (-197280)) False [rLo, rHi])
      case buildPremiumObs [lc] m of
        [o] -> poFlags o `shouldContain` [ChunkEmpty]
        _   -> expectationFailure "expected exactly one observation"

    it "a PremiumObs from a real atTick (not the sentinel) carries Extrapolated" $ do
      let lc  = LegChunk 0 (ChunkKey 0 (-199680) (-197280)) False q64 (-198000) 240
          rLo = (mkReading 100 5 10) { arAtTick = -200000 }  -- acc0 delta = 4
          rHi = (mkReading 101 9 10) { arAtTick = -200000 }
          m   = Map.fromList (buildMap (ChunkKey 0 (-199680) (-197280)) False [rLo, rHi])
      case buildPremiumObs [lc] m of
        [o] -> do
          poFlags o `shouldContain` [Extrapolated]
          poPremiumWei0 o `shouldBe` 4   -- delta 4, L = 2^64 -> 4 wei
          poEpoch o `shouldBe` 101
        _   -> expectationFailure "expected exactly one observation"

  describe "multiplier wedge" $ do
    it "equals exactly 1 when R = 0" $
      multiplierWedge 0 1000 True `shouldBe` 1

    it "is bounded above by 1 + nu = 1.125 on the long side as R -> N" $
      multiplierWedge 1000 1000 True `shouldBe` (9 % 8)

    it "the short-side wedge with R = N is 1 + nu/2 (R^2/(N*T) = 1/2)" $
      multiplierWedge 1000 1000 False `shouldBe` (1 + (1 % 8) * (1 % 2))

  describe "golden-derived premium" $
    it "the frozen 44.5M -> 47M gross delta yields a positive premium; long negates" $ do
      (accLo, accHi) <- loadGrossPair
      accHi `shouldSatisfy` (> accLo)                     -- monotone (fixture invariant)
      let l = 1000000000000 :: Integer                     -- a plausible chunk liquidity
      premiumWei accHi accLo l False `shouldSatisfy` (> 0)
      premiumWei accHi accLo l True  `shouldBe` negate (premiumWei accHi accLo l False)
      -- and it telescopes trivially through the intermediate endpoints
      telescope [accLo, accHi] q64 False `shouldBe` accDelta accHi accLo

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

mkReading :: Integer -> Integer -> Integer -> AccReading
mkReading epoch acc0 netLiq =
  AccReading
    { arChunkKey         = ChunkKey 0 (-199680) (-197280)
    , arBlock            = epoch
    , arEpoch            = epoch
    , arIsLong           = False
    , arAtTick           = 8388607     -- storedValueTick
    , arAcc0             = acc0
    , arAcc1             = 0
    , arNetLiquidity     = netLiq
    , arRemovedLiquidity = 0
    , arEndpoint         = Nothing
    }

-- | Build the (ChunkKey, epoch, isLong) -> AccReading map from a reading list.
buildMap :: ChunkKey -> Bool -> [AccReading]
         -> [((ChunkKey, Integer, Bool), AccReading)]
buildMap ck il = map (\r -> ((ck, arEpoch r, il), r))

-- Load the two gross (short, stored) readings from the frozen fixture:
-- 44,500,000 and 47,000,000. Returns (accLo, accHi).
loadGrossPair :: IO (Integer, Integer)
loadGrossPair = do
  ev <- eitherDecodeFileStrict goldenPath :: IO (Either String Value)
  case ev of
    Left err -> error ("premium-acc-golden.json parse failed: " ++ err)
    Right v  -> case AT.parseMaybe pairP v of
      Just (lo, hi) -> pure (lo, hi)
      Nothing       -> error "premium-acc-golden.json: could not extract the gross pair"
  where
    pairP = AT.withObject "golden" $ \o -> do
      arr <- o AT..: "readings" :: AT.Parser [AT.Object]
      case arr of
        (r0 : r1 : _) -> do
          lo <- r0 AT..: "expected_currency0_x64"
          hi <- r1 AT..: "expected_currency0_x64"
          pure (hexToInteger lo, hexToInteger hi)
        _ -> fail "premium-acc-golden.json: fewer than two readings"

hexToInteger :: Text -> Integer
hexToInteger = bytesToInteger . hexToBytes . pad . strip
  where
    strip t | "0x" `T.isPrefixOf` t = T.drop 2 t
            | otherwise             = t
    pad t = if odd (T.length t) then "0" <> t else t
