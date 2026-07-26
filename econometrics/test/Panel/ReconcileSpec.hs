{-# LANGUAGE OverloadedStrings #-}

-- | Offline spec for 'Panel.Reconcile' — the reconciliation gate's arithmetic.
--
-- Every case runs against SYNTHETIC accumulator maps and synthetic spells built
-- in this file. There is no network access and no URL literal anywhere: the gate
-- itself is a network CLI (10-VALIDATION is explicit that it belongs outside the
-- hspec suite), but the arithmetic it rests on is proven here, deterministically.
module Panel.ReconcileSpec (spec) where

import           Data.List           (sort)
import           Data.Map.Strict     (Map)
import qualified Data.Map.Strict     as Map
import           Data.Maybe          (fromMaybe)
import qualified Data.Text           as T
import           Test.Hspec

import           Panel.Reconcile
import           Panel.Subgraph      (BurnEvent (..), MintEvent (..))
import           Panoptic.Chunk      (ChunkKey (..), LegChunk (..), storedValueTick)
import           Panoptic.Premium    (PremiumFlag (..), telescope)
import           Panoptic.ReadDriver (AccKey, AccRow (..), accRowKey)

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- | @2^64@ — the X64 accumulator scale.
q64 :: Integer
q64 = 2 ^ (64 :: Int)

mintBlk, burnBlk :: Integer
mintBlk = 44500000
burnBlk = 44700000

-- | A chunk key, distinct per index so a multi-leg position touches distinct
-- accumulator series.
ck :: Int -> ChunkKey
ck i = ChunkKey (i `mod` 2) (-201120 - 10 * i) (-198720 + 10 * i)

-- | One leg in that chunk, with an explicit liquidity multiplier.
leg :: Int -> Bool -> Integer -> LegChunk
leg i isLong l = LegChunk
  { lcLegIndex  = i
  , lcChunkKey  = ck i
  , lcIsLong    = isLong
  , lcLiquidity = l
  , lcStrike    = -199920
  , lcWidth     = 240
  }

-- | An accumulator reading. @net@ is non-zero and @atTick@ is the stored-value
-- sentinel unless a case wants a flag.
accRow :: ChunkKey -> Integer -> Bool -> Integer -> Maybe T.Text -> AccRow
accRow c blk isLong acc0 endp = AccRow
  { acTokenType  = ckTokenType c
  , acTickLower  = ckTickLower c
  , acTickUpper  = ckTickUpper c
  , acBlock      = blk
  , acIsLong     = isLong
  , acAtTick     = storedValueTick
  , acAcc0       = acc0
  , acAcc1       = 0
  , acNetLiq     = 1000000
  , acRemovedLiq = 0
  , acEpoch      = 492876
  , acEndpoint   = endp
  }

accMapOf :: [AccRow] -> Map AccKey AccRow
accMapOf rs = Map.fromList [ (accRowKey r, r) | r <- rs ]

mint :: MintEvent
mint = MintEvent
  { meTokenId      = "tok"
  , meAccount      = "0xacct"
  , meTimestamp    = 1000
  , meBlock        = mintBlk
  , meTickAt       = -199482
  , mePositionSize = 1.0e15
  }

-- | A burn carrying a ground-truth @premium0@ in RAW 18-decimal units.
burnRaw :: Double -> BurnEvent
burnRaw p0 = BurnEvent
  { beTokenId      = "tok"
  , beAccount      = "0xacct"
  , beTimestamp    = 2000
  , beBlock        = burnBlk
  , beTickAt       = -200340
  , bePremium0     = p0
  , bePremium1     = 0
  , bePositionSize = 1.0e15
  }

spellOf :: T.Text -> BurnEvent -> [LegChunk] -> SpellInput
spellOf tid be lcs = (tid, mint, be { beTokenId = tid }, lcs)

-- | The single-leg short fixture: the accumulator moves by @delta@ over the
-- spell, with @L@ a multiple of @2^64@ so the premium is exactly @delta * L\/2^64@.
--
-- @L@ is sized so the premium lands at a REALISTIC @~1.2e13@ wei (≈ 1.2e-5 ETH),
-- the order of magnitude this market actually produces. That matters: the
-- ground-truth unit is CLASSIFIED from the reported magnitude, so a toy fixture
-- of a few thousand \"wei\" would be (correctly) read as whole tokens.
singleLegDelta :: Integer
singleLegDelta = 4096

singleLegL :: Integer
singleLegL = 3000000000 * q64

singleLegAccs :: Map AccKey AccRow
singleLegAccs = accMapOf
  [ accRow (ck 0) mintBlk False 1000 (Just "mint")
  , accRow (ck 0) burnBlk False (1000 + singleLegDelta) (Just "burn")
  ]

-- | The exact expected premium of that fixture, in wei.
singleLegWei :: Integer
singleLegWei = singleLegDelta * singleLegL `div` q64

-- ---------------------------------------------------------------------------

spec :: Spec
spec = describe "Panel.Reconcile" $ do

  describe "reconstructSpell" $ do
    it "returns exactly delta * L / 2^64 wei on a single-leg short spell" $ do
      let r = reconstructSpell singleLegAccs
                (spellOf "tok" (burnRaw (fromInteger singleLegWei))
                         [leg 0 False singleLegL])
      srReconWei r `shouldBe` singleLegWei
      srReconWei r `shouldBe` 12288000000000  -- 4096 * 3e9
      srLegCount r `shouldBe` 1
      srIsLong r `shouldBe` False

    it "sums over legs and reports legCount = 3 on a 3-leg position" $ do
      let deltas = [100, 250, 700] :: [Integer]
          ls     = [1000000000 * q64, 2000000000 * q64, 5000000000 * q64]
          rows   = concat
            [ [ accRow (ck i) mintBlk False 500 (Just "mint")
              , accRow (ck i) burnBlk False (500 + d) (Just "burn") ]
            | (i, d) <- zip [0 ..] deltas ]
          lcs    = [ leg i False l | (i, l) <- zip [0 ..] ls ]
          expect = sum (zipWith (\d l -> d * l `div` q64) deltas ls)
          r      = reconstructSpell (accMapOf rows)
                     (spellOf "tok3" (burnRaw (fromInteger expect)) lcs)
      srLegCount r `shouldBe` 3
      srLegCountTruth r `shouldBe` 3
      srReconWei r `shouldBe` expect
      srReconWei r `shouldBe` (100 + 500 + 3500) * 1000000000

    it "negates the premium of a long leg" $ do
      let rows = [ accRow (ck 0) mintBlk True 1000 (Just "mint")
                 , accRow (ck 0) burnBlk True (1000 + singleLegDelta) (Just "burn") ]
          r = reconstructSpell (accMapOf rows)
                (spellOf "tokL" (burnRaw (fromInteger (negate singleLegWei)))
                         [leg 0 True singleLegL])
      srReconWei r `shouldBe` negate singleLegWei
      srIsLong r `shouldBe` True

    it "keeps exact Integer wei past the 2^53 Double mantissa" $ do
      -- L chosen so the premium exceeds 2^53: a Double round-trip would round it.
      let bigL   = 12345 * q64
          rows   = [ accRow (ck 0) mintBlk False 0 (Just "mint")
                   , accRow (ck 0) burnBlk False (2 ^ (40 :: Int) + 1) (Just "burn") ]
          expect = (2 ^ (40 :: Int) + 1) * 12345 :: Integer
          r      = reconstructSpell (accMapOf rows)
                     (spellOf "tokBig" (burnRaw 0) [leg 0 False bigL])
      (expect > 2 ^ (53 :: Int)) `shouldBe` True
      srReconWei r `shouldBe` expect

    it "prefers the endpoint-tagged reading over an interior row at the same block" $ do
      let interior = (accRow (ck 0) burnBlk False 999999 Nothing) { acAtTick = -200340 }
          rows = [ accRow (ck 0) mintBlk False 1000 (Just "mint")
                 , interior
                 , accRow (ck 0) burnBlk False (1000 + singleLegDelta) (Just "burn") ]
          r = reconstructSpell (accMapOf rows)
                (spellOf "tok" (burnRaw 0) [leg 0 False singleLegL])
      srReconWei r `shouldBe` singleLegWei

  describe "leg-count mismatch" $
    it "reports a MISMATCH rather than silently reconciling a missing leg" $ do
      -- Two legs in the position; only leg 0 has endpoint readings.
      let rows = [ accRow (ck 0) mintBlk False 1000 (Just "mint")
                 , accRow (ck 0) burnBlk False (1000 + singleLegDelta) (Just "burn") ]
          lcs  = [ leg 0 False singleLegL, leg 1 False singleLegL ]
          rep  = reconcileSpells [] (accMapOf rows)
                   [ spellOf "tokMiss" (burnRaw (fromInteger singleLegWei)) lcs ]
      map srLegCount (rrSpells rep) `shouldBe` [1]
      map srLegCountTruth (rrSpells rep) `shouldBe` [2]
      map srTokenId (rrMismatches rep) `shouldBe` ["tokMiss"]
      -- A mismatch is not a passing gate even though the one readable leg is exact.
      rrPassed rep `shouldBe` False

  describe "relError" $ do
    it "is |recon - truth| / |truth|" $ do
      -- truth = 12288 + 1024 wei, recon = 12288 wei.
      let truth = singleLegWei + 1024
          r = reconstructSpell singleLegAccs
                (spellOf "tok" (burnRaw (fromInteger truth)) [leg 0 False singleLegL])
      srSignedErrorWei r `shouldBe` negate 1024
      fromMaybe (0 / 0) (srRelError r)
        `shouldSatisfy` \x -> abs (x - 1024 / fromInteger truth) < 1e-12

    it "is Nothing (excluded and counted) when the ground truth is zero" $ do
      let r = reconstructSpell singleLegAccs
                (spellOf "tok" (burnRaw 0) [leg 0 False singleLegL])
          d = errorDist [r]
      srRelError r `shouldBe` Nothing
      edN d `shouldBe` 0
      edZeroTruth d `shouldBe` 1

  describe "errorDist" $ do
    it "reports median, IQR, p90, max and the signed-error sign counts" $ do
      let d = errorDist (map synth [0.001, 0.002, 0.003, 0.004, 0.005
                                   , 0.006, 0.007, 0.008, 0.009, 0.010])
      edN d `shouldBe` 10
      abs (edMedian d - 0.0055) `shouldSatisfy` (< 1e-12)
      abs (edP25 d - 0.003)     `shouldSatisfy` (< 1e-12)
      abs (edP75 d - 0.008)     `shouldSatisfy` (< 1e-12)
      abs (edP90 d - 0.009)     `shouldSatisfy` (< 1e-12)
      abs (edMax d - 0.010)     `shouldSatisfy` (< 1e-12)

    it "separates over- from under-reconstruction in the sign counts" $ do
      -- Two spells reconstruct ABOVE truth, one BELOW.
      let over  = synthSigned 1
          under = synthSigned (-1)
          d     = errorDist [over, over, under]
      edPosCount d `shouldBe` 2
      edNegCount d `shouldBe` 1

    it "gives NaN quantiles on an empty set, never a 0 that reads as a pass" $ do
      let d = errorDist []
      edN d `shouldBe` 0
      isNaN (edMedian d) `shouldBe` True
      isNaN (edMax d) `shouldBe` True

  describe "stratify" $
    it "partitions into short and long with independent distributions" $ do
      let shorts = [ synth 0.001, synth 0.002, synth 0.003 ]
          longs  = [ (synth 0.40) { srIsLong = True }, (synth 0.60) { srIsLong = True } ]
          (s, l) = stratify (shorts ++ longs)
      edN s `shouldBe` 3
      edN l `shouldBe` 2
      abs (edMedian s - 0.002) `shouldSatisfy` (< 1e-12)
      abs (edMedian l - 0.50)  `shouldSatisfy` (< 1e-12)
      -- The long stratum's wide error does NOT leak into the short verdict.
      edMedian s `shouldSatisfy` (<= gateTolerance)
      edMedian l `shouldSatisfy` (>  gateTolerance)

  describe "gateTolerance" $ do
    it "is 1%, the single named constant the gate is scored against" $
      gateTolerance `shouldBe` 0.01

    it "passes a short stratum inside it and fails one outside it" $ do
      let mk e = reconcileSpellsOf [ (synth e) ]
      rrPassed (mk 0.005) `shouldBe` True
      rrPassed (mk 0.02)  `shouldBe` False

  describe "telescoping consistency" $
    it "endpoint reconstruction equals the sum of the per-epoch interior deltas" $ do
      -- A monotone accumulator chain across the spell. With L a multiple of 2^64
      -- there is no per-delta flooring loss, so the decomposition is EXACT.
      let chain = [1000, 1750, 3900, 3900, 91000] :: [Integer]
          l     = 7 * q64
          firstAcc = 1000
          lastAcc  = 91000
          rows  = [ accRow (ck 0) mintBlk False firstAcc (Just "mint")
                  , accRow (ck 0) burnBlk False lastAcc  (Just "burn") ]
          r     = reconstructSpell (accMapOf rows)
                    (spellOf "tokT" (burnRaw 0) [leg 0 False l])
      srReconWei r `shouldBe` telescope chain l False
      srReconWei r `shouldBe` (lastAcc - firstAcc) * 7

  describe "ground-truth unit determination" $ do
    it "classifies raw 18-decimal magnitudes as RawWei" $ do
      classifyGroundTruthUnit [burnRaw 5.43e12, burnRaw 2.56e12]
        `shouldBe` RawWei
      groundTruthWei RawWei (burnRaw 5.43e12) `shouldBe` 5430000000000

    it "classifies whole-token magnitudes as WholeEth and scales by 1e18" $ do
      classifyGroundTruthUnit [burnRaw 5.43e-6, burnRaw 2.56e-6]
        `shouldBe` WholeEth
      groundTruthWei WholeEth (burnRaw 5.43e-6) `shouldBe` 5430000000000

    it "names the converting expression so the determination is auditable" $ do
      groundTruthExpr RawWei   `shouldSatisfy` T.isInfixOf "round(premium0)"
      groundTruthExpr WholeEth `shouldSatisfy` T.isInfixOf "1e18"

  describe "flags" $
    it "carries ChunkEmpty and Extrapolated up from the endpoint readings" $ do
      let mintRow = (accRow (ck 0) mintBlk False 1000 (Just "mint")) { acNetLiq = 0 }
          burnRow = (accRow (ck 0) burnBlk False (1000 + singleLegDelta) (Just "burn"))
                      { acAtTick = -200340 }
          r = reconstructSpell (accMapOf [mintRow, burnRow])
                (spellOf "tokF" (burnRaw 0) [leg 0 False singleLegL])
      sort (srFlags r) `shouldBe` [ChunkEmpty, Extrapolated]

  describe "renderReconReport" $
    it "emits the strata, the per-spell table, the median line and a verdict" $ do
      let rep = reconcileSpellsOf [ synth 0.004 ]
          out = renderReconReport rep
      out `shouldSatisfy` T.isInfixOf "median_rel_error:"
      out `shouldSatisfy` T.isInfixOf "GATE_TOLERANCE"
      out `shouldSatisfy` T.isInfixOf "| short |"
      out `shouldSatisfy` T.isInfixOf "| long |"
      out `shouldSatisfy` T.isInfixOf "GATE: PASS"
      out `shouldSatisfy` T.isInfixOf "ETH wei"

-- ---------------------------------------------------------------------------
-- Synthetic SpellRecon helpers (distribution-level cases)
-- ---------------------------------------------------------------------------

-- | A short spell whose relative error is exactly @e@, reconstructed ABOVE truth.
synth :: Double -> SpellRecon
synth e = SpellRecon
  { srTokenId        = T.pack ("tok" ++ show e)
  , srIsLong         = False
  , srLegCount       = 1
  , srLegCountTruth  = 1
  , srReconWei       = truth + err
  , srTruthWei       = truth
  , srRelError       = Just e
  , srSignedErrorWei = err
  , srFlags          = []
  , srMintBlock      = mintBlk
  , srBurnBlock      = burnBlk
  }
  where
    truth = 1000000000000 :: Integer
    err   = round (e * fromInteger truth) :: Integer

-- | 'synth' with an explicit signed-error direction.
synthSigned :: Integer -> SpellRecon
synthSigned s = (synth 0.005) { srSignedErrorWei = s * 5000000000 }

-- | Wrap a ready-made list of 'SpellRecon' into a report through the REAL
-- verdict rule ('reportOf') — never a re-implementation of it here, so the spec
-- and the CLI can never disagree about what passing means.
reconcileSpellsOf :: [SpellRecon] -> ReconReport
reconcileSpellsOf = reportOf [] RawWei
