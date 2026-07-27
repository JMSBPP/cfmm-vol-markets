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

  -- The 10-01 Wave-0 census closed the DAILY design on its own pre-committed
  -- rule and the user re-scoped the phase to EPOCH_HOURS = 1. σ̂²_t, σ̃²_t and
  -- i_t must therefore be re-estimated at HOURLY windows — with the SAME
  -- estimator and the SAME epoch source of truth, or the panel and the regressor
  -- silently de-align (the 09-05 40587-offset trap, one grid finer).
  describe "hourly epoch width (the 10-01 re-scope)" $ do
    -- hour 0: ticks 100,110,90  → Δ 10,-20      → ΣΔ² = 500
    --         evens 100,90      → Δ -10         → ΣΔ² = 100
    -- hour 1: ticks 200,180     → Δ -20         → ΣΔ² = 400
    --         evens 200         → no increment  → 0
    let hourlyTicks =
          [ (utc 0, 100), (utc 60, 110), (utc 120, 90)
          , (utc 3600, 200), (utc 3660, 180) ]

    it "realizedVarianceAt 3600 buckets by the hour and uses the same estimator" $ do
      let rv = realizedVarianceAt 3600 hourlyTicks
      Map.keys rv `shouldBe` [0, 1]
      get 0 rv `shouldSatisfy` approx (c * c * 500)
      get 1 rv `shouldSatisfy` approx (c * c * 400)

    it "instrumentVarianceAt 3600 uses the DISJOINT even-swap sub-window" $ do
      let iv = instrumentVarianceAt 3600 hourlyTicks
      get 0 iv `shouldSatisfy` approx (c * c * 100)
      get 1 iv `shouldSatisfy` approx 0     -- one even swap ⇒ no increment

    it "meanPoolTickAt 3600 averages the ticks inside the hour" $ do
      let mt = meanPoolTickAt 3600 hourlyTicks
      get 0 mt `shouldSatisfy` approx 100    -- (100 + 110 + 90) / 3
      get 1 mt `shouldSatisfy` approx 190    -- (200 + 180) / 2

    it "swapCountsAt reports the increments behind each σ̂² (n_swaps − 1)" $ do
      let ns = swapCountsAt 3600 hourlyTicks
      Map.lookup 0 ns `shouldBe` Just 3
      Map.lookup 1 ns `shouldBe` Just 2

    -- The generalization must not perturb the committed daily series: at 86400
    -- the *At estimators ARE the daily ones. If this ever fails, variance.csv
    -- would no longer be reproducible from the same tick cache.
    it "at 86400 the width-parameterized estimators equal the daily ones" $ do
      ticks <- loadSwapTicks fixturePath
      realizedVarianceAt   86400 ticks `shouldBe` realizedVariance   ticks
      instrumentVarianceAt 86400 ticks `shouldBe` instrumentVariance ticks
      meanPoolTickAt       86400 ticks `shouldBe` meanPoolTick       ticks

    -- The hourly grid must REFINE the daily one exactly 24-to-1: every hourly
    -- bucket belongs to exactly one daily bucket and no swap is lost or double
    -- counted. This is the property that makes the two artifacts comparable.
    it "the hourly buckets partition the daily ones (no swap lost or duplicated)" $ do
      ticks <- loadSwapTicks fixturePath
      let hourly = swapCountsAt 3600  ticks
          daily  = swapCountsAt 86400 ticks
          rolled = Map.fromListWith (+) [ (h `div` 24, n) | (h, n) <- Map.toList hourly ]
      rolled `shouldBe` daily
      sum (Map.elems hourly) `shouldBe` length ticks

  -- One hour of the Base ETH/USDC estimation window (epoch 495112) carries zero
  -- swaps between neighbours carrying 700+. A re-fetch of that block range
  -- reproduced the cache byte-identically, so the hour was still on chain rather
  -- than missed by the pull — and a panel row for it must be able to join.
  describe "quiet-epoch completion" $ do
    let s2   = Map.fromList [(10, 5.0), (12, 7.0)]
        s2i  = Map.fromList [(10, 4.0), (12, 6.0)]
        tick = Map.fromList [(10, -200100), (12, -200300)]
        n    = Map.fromList [(10, 300 :: Int), (12, 400)]
        (s2', s2i', tick', n', quiet) = fillQuietEpochs s2 s2i tick n

    it "fills interior epochs that carry no swap at all" $
      quiet `shouldBe` [11]

    it "gives a quiet epoch sigma2 = 0 (no swap ⇒ no increment ⇒ no movement)" $ do
      Map.lookup 11 s2'  `shouldBe` Just 0
      Map.lookup 11 s2i' `shouldBe` Just 0

    it "carries the pool tick FORWARD (it is a state variable, not a flow)" $
      Map.lookup 11 tick' `shouldBe` Just (-200100)

    it "marks the quiet epoch with n_swaps = 0 so it stays isolable downstream" $
      Map.lookup 11 n' `shouldBe` Just 0

    it "never invents epochs outside the observed range" $ do
      Map.member 9  n' `shouldBe` False
      Map.member 13 n' `shouldBe` False

    it "leaves an already-complete series untouched" $ do
      let full = Map.fromList [(10, 1 :: Int), (11, 2), (12, 3)]
          (a, _, _, d, q) = fillQuietEpochs s2 s2i tick full
      q `shouldBe` []
      a `shouldBe` s2
      d `shouldBe` full

  describe "V4 Swap-log ABI decode" $ do
    it "decodeTick reads the int24 tick (word 4, sign-extended) from live data" $
      decodeTick (BC.pack liveSwapData) `shouldBe` (-201156)
    it "decodeSqrtPriceX96 reads uint160 word 2 from live data" $
      decodeSqrtPriceX96 (BC.pack liveSwapData) `shouldBe` 0x2cf47f0044977f5d3a173
