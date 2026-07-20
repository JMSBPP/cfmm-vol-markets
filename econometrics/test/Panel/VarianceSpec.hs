{-# LANGUAGE OverloadedStrings #-}

-- | CTX-VAR behavioural spec for 'Panel.Variance': the realized-variance
-- regressor σ̂²_t, the disjoint-window EIV instrument σ̃²_t, the panel-aligned
-- daily epoch boundary, and the V4 Swap-log ABI decode.
--
-- Golden values are hand-derived from the frozen fixture
-- @test/fixtures/swap-ticks-sample.csv@ (two UTC days of integer ticks), so the
-- suite is deterministic and network-free. Realized variance here is the sum of
-- squared within-day log-price increments, with logPrice(tick) = tick·ln(1.0001):
--
--   RV_day = (ln 1.0001)² · Σ_k (Δtick_k)²
--
-- Epoch = the panel's dailyEpoch (Panel.Build): whole UTC days since the Unix
-- epoch, i.e. floor(unixSeconds / 86400). Day A = 2021-01-01 → epoch 18628,
-- Day B = 2021-01-02 → epoch 18629.
--
-- Day A (epoch 18628) ticks 100,110,90,130,120,140 → Δ 10,-20,40,-10,20
--   → Σ Δ² = 2600.       Even-swap sub-window 100,90,120 → Δ -10,30 → Σ Δ² = 1000.
-- Day B (epoch 18629) ticks 200,180,220,210 → Δ -20,40,-10
--   → Σ Δ² = 2100.       Even-swap sub-window 200,220 → Δ 20 → Σ Δ² = 400.
module Panel.VarianceSpec (spec) where

import qualified Data.ByteString.Char8 as BC
import           Data.Maybe (fromMaybe)
import qualified Data.Map.Strict as Map
import           Data.Time.Clock (UTCTime)
import           Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import           Test.Hspec

import           Panel.Variance

fixturePath :: FilePath
fixturePath = "test/fixtures/swap-ticks-sample.csv"

-- | ln(1.0001) — the λ = 1.0001 tick grid constant.
c :: Double
c = log 1.0001

utc :: Integer -> UTCTime
utc = posixSecondsToUTCTime . fromInteger

get :: Ord k => k -> Map.Map k Double -> Double
get k = fromMaybe (1/0) . Map.lookup k

approx :: Double -> Double -> Bool
approx expected actual = abs (expected - actual) < 1e-9

-- The exact live V4 Swap-log @data@ captured from mainnet.base.org (poolId
-- 0x96d4…288c0a). Word 5 = 0x1f4 = 500 (the pool's 0.05% fee tier), word 4 =
-- the int24 tick, word 2 = sqrtPriceX96.
liveSwapData :: String
liveSwapData =
  "0x000000000000000000000000000000000000000000000000005b0974ad5d7829\
  \fffffffffffffffffffffffffffffffffffffffffffffffffffffffffd30fba2\
  \00000000000000000000000000000000000000000002cf47f0044977f5d3a173\
  \0000000000000000000000000000000000000000000000000083581db0f0dd99\
  \fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcee3c\
  \00000000000000000000000000000000000000000000000000000000000001f4"

spec :: Spec
spec = describe "Panel.Variance (CTX-VAR)" $ do

  describe "realizedVariance σ̂²_t (golden within-day RV)" $
    it "matches the hand-computed sum of squared log-price increments per day" $ do
      ticks <- loadSwapTicks fixturePath
      let rv = realizedVariance ticks
      get 18628 rv `shouldSatisfy` approx (c * c * 2600)
      get 18629 rv `shouldSatisfy` approx (c * c * 2100)

  describe "instrumentVariance σ̃²_t (disjoint even-swap sub-window)" $ do
    it "matches its own hand-computed value on the even-swap sub-window" $ do
      ticks <- loadSwapTicks fixturePath
      let iv = instrumentVariance ticks
      get 18628 iv `shouldSatisfy` approx (c * c * 1000)
      get 18629 iv `shouldSatisfy` approx (c * c * 400)
    it "differs from σ̂²_t (a genuinely different tick subset)" $ do
      ticks <- loadSwapTicks fixturePath
      let rv = realizedVariance ticks
          iv = instrumentVariance ticks
      abs (get 18628 iv - get 18628 rv) `shouldSatisfy` (> 1e-9)
      abs (get 18629 iv - get 18629 rv) `shouldSatisfy` (> 1e-9)

  describe "dailyEpoch boundary (SAME UTC-midnight bucket as the panel)" $ do
    it "buckets by whole UTC days since the Unix epoch (Panel.Build convention)" $ do
      dailyEpoch (utc 1609459200) `shouldBe` 18628   -- 2021-01-01 00:00:00Z
      dailyEpoch (utc 1609459199) `shouldBe` 18627   -- 2020-12-31 23:59:59Z
      dailyEpoch (utc 1609545600) `shouldBe` 18629   -- 2021-01-02 00:00:00Z
    it "a tick exactly at the day boundary lands in the expected epoch" $ do
      let boundaryTicks = [(utc 1609459200, 10), (utc 1609460000, 20), (utc 1609460100, 30)]
      Map.member 18628 (realizedVariance boundaryTicks) `shouldBe` True

  describe "tickToLogPrice" $
    it "is tick · ln(1.0001)" $
      tickToLogPrice 12345 `shouldSatisfy` approx (12345 * c)

  describe "V4 Swap-log ABI decode" $ do
    it "decodeTick reads the int24 tick (word 4, sign-extended) from live data" $
      decodeTick (BC.pack liveSwapData) `shouldBe` (-201156)
    it "decodeSqrtPriceX96 reads uint160 word 2 from live data" $
      decodeSqrtPriceX96 (BC.pack liveSwapData) `shouldBe` 0x2cf47f0044977f5d3a173
