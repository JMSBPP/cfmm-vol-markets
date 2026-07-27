{-# LANGUAGE OverloadedStrings #-}

-- | Fixture-driven tests for the accrual-spell assembler (CTX-PANEL, rebuilt at
-- plan 09-09 against the REAL Panoptic subgraph schema).
--
-- The fixture @test/fixtures/subgraph-sample.json@ mirrors the live response
-- shape for @optionMints@, @optionBurns@ and @tokenIds { legs }@. The behaviours
-- under test are exactly the ones the live run depends on:
--
--   1. each burn pairs with the LATEST preceding mint of the same
--      (tokenId, account) — that pair is the accrual spell;
--   2. @Leg.strike@ is carried through as an int24 TICK, NOT log-converted
--      (09-04's @round(log K \/ log 1.0001)@ was a bug: live strikes are negative
--      and the logarithm produced NaN);
--   3. π is a per-day RATE (spell premium / spell days), with long positions
--      sign-flipped to the seller-side convention;
--   4. burns with a zero premium, or with no prior mint, are dropped.
module Panel.BuildSpec (spec) where

import qualified Data.ByteString.Lazy as BL
import           Data.List            (nub, sortOn)
import qualified Data.Map.Strict      as Map
import           Data.Text            (Text)
import           Test.Hspec

import           Data.Time.Clock.POSIX (posixSecondsToUTCTime)

import           Model.Upsilon        (moneyness)
import           Panel.Build          (EpochObs (..), Spell (..),
                                       VarianceRow (..), assembleEpochPanel,
                                       assembleSpells,
                                       assembleSpellsWithWindows, dailyEpoch,
                                       epochOfSeconds, epochPanelHeader,
                                       hourlyEpoch, premiumUsd, tickToPrice)
import           Panel.Subgraph       (BurnEvent (..), MintEvent (..),
                                       parseBurns, parseLegs, parseMints)
import           Panoptic.Chunk       (ChunkKey (..), LegChunk (..))
import           Panoptic.Premium     (PremiumFlag (..), PremiumObs (..))

fixturePath :: FilePath
fixturePath = "test/fixtures/subgraph-sample.json"

-- | token0 decimals − token1 decimals for ETH(18)/USDC(6).
shift :: Int
shift = 12

fixtureSpells :: IO [Spell]
fixtureSpells = do
  bytes <- BL.readFile fixturePath
  mints <- either fail pure (parseMints bytes)
  burns <- either fail pure (parseBurns bytes)
  legs  <- either fail pure (parseLegs bytes)
  pure (assembleSpells shift mints burns legs)

spec :: Spec
spec = describe "Panel.Build (CTX-PANEL, accrual spells)" $ do

  it "converts a pool tick to a USDC-per-ETH price on the λ=1.0001 grid" $
    -- tick −200,340 on an 18/6-decimal pair is ≈ 1992 USDC per ETH
    tickToPrice shift (-200340) `shouldSatisfy` (\x -> x > 1900 && x < 2100)

  it "carries Leg.strike through as a TICK (no log conversion, no NaN)" $ do
    spells <- fixtureSpells
    let ticks = map spStrikeTick spells
    ticks `shouldSatisfy` all (< 0)
    ticks `shouldSatisfy` all (\t -> t > -210000 && t < -190000)

  it "pairs each burn with the LATEST preceding mint of the same position" $ do
    spells <- fixtureSpells
    -- tokenId 1001 is minted twice; the burn attaches to the SECOND mint, so the
    -- spell is 1 day, not the 3 days the first mint would give.
    map spDays (filter ((== "1001") . spTokenId) spells) `shouldBe` [1.0]

  it "expresses pi as a per-day rate over the spell" $ do
    spells <- fixtureSpells
    spells `shouldSatisfy` all
      (\s -> abs (spPremiumRate s * spDays s - spPremiumUsd s) < 1e-12)

  it "sign-flips LONG positions to the seller-side premium convention" $ do
    -- the protocol emits a NEGATIVE premium0 for a long position; after the flip
    -- the spell's premium is positive, on the same scale as a short's.
    let b = BurnEvent { beTokenId = "x", beAccount = "a", beTimestamp = 0
                      , beBlock = 0, beTickAt = -200000
                      , bePremium0 = -1.0e12, bePremium1 = 0, bePositionSize = 1 }
    premiumUsd shift True  b `shouldSatisfy` (> 0)
    premiumUsd shift False b `shouldSatisfy` (< 0)

  it "yields a positive premium for the long spell in the fixture" $ do
    spells <- fixtureSpells
    let longs = filter spIsLong spells
    length longs `shouldBe` 1
    map spPremiumUsd longs `shouldSatisfy` all (> 0)

  it "drops zero-premium burns and burns with no prior mint" $ do
    bytes  <- BL.readFile fixturePath
    burns  <- either fail pure (parseBurns bytes)
    spells <- fixtureSpells
    -- 4 burns: one zero-premium (1003), one orphan (1004), two good.
    length burns  `shouldBe` 4
    length spells `shouldBe` 2

  it "emits spells ordered by burn epoch" $ do
    spells <- fixtureSpells
    let es = map spBurnEpoch spells
    es `shouldBe` sortOn id es

  -- The 09-05 40587-offset trap: a second definition of the day index silently
  -- de-aligned the panel from the variance series. 'epochOfSeconds' generalizes
  -- the bucket width for the 10-01 hourly census, so it must be pinned to agree
  -- with 'dailyEpoch' at 86400 — otherwise the generalization reintroduces
  -- exactly the drift 'dailyEpoch' exists to prevent.
  it "epochOfSeconds 86400 agrees with dailyEpoch (the single source of truth)" $ do
    let instants = [ 0, 1, 86399, 86400, 86401, 1774352661, 1774352661 + 3599
                   , 1739059200, 2147483647 ] :: [Integer]
        t u = posixSecondsToUTCTime (fromInteger u)
    map (epochOfSeconds 86400 . t) instants `shouldBe` map (dailyEpoch . t) instants

  it "hourlyEpoch refines dailyEpoch exactly 24-to-1" $ do
    let instants = [ 0, 3599, 3600, 86399, 86400, 1774352661 ] :: [Integer]
        t u = posixSecondsToUTCTime (fromInteger u)
    map ((`div` 24) . hourlyEpoch . t) instants `shouldBe` map (dailyEpoch . t) instants

  panelJoinSpec

  -- The hourly census reads its sub-daily windows from here rather than
  -- re-deriving the mint<->burn pairing; if the two ever diverged the census
  -- would be measuring a different spell set than the panel.
  it "assembleSpellsWithWindows agrees with assembleSpells and carries the raw window" $ do
    bytes  <- BL.readFile fixturePath
    mints  <- either fail pure (parseMints bytes)
    burns  <- either fail pure (parseBurns bytes)
    legs   <- either fail pure (parseLegs bytes)
    spells <- fixtureSpells
    let withWins = assembleSpellsWithWindows shift mints burns legs
    map fst withWins `shouldBe` spells
    -- the window is second-resolution and reproduces the spell's own duration
    map (\(s, (m, b)) -> abs (fromInteger (b - m) / 86400 - spDays s) < 1e-9) withWins
      `shouldSatisfy` and

-- ---------------------------------------------------------------------------
-- The position-epoch panel and its variance join (plan 10-09)
-- ---------------------------------------------------------------------------

-- | Synthetic three-epoch position on the HOURLY grid (epoch = hour since the
-- Unix epoch). Epochs 100, 101, 102; the position is open across all three.
--
-- Everything here is constructed rather than fixture-loaded because the property
-- under test is the JOIN, not the parse: what matters is that a premium
-- observation lands on the variance row for the epoch it accrued in, that a
-- missing variance row is REPORTED instead of silently dropping the observation,
-- and that the epoch rows sum back to the spell total.
hourSecs :: Int
hourSecs = 3600

synthMint :: Text -> Integer -> MintEvent
synthMint tid e = MintEvent
  { meTokenId = tid, meAccount = "0xacct"
  , meTimestamp = e * fromIntegral hourSecs, meBlock = e
  , meTickAt = -200000, mePositionSize = 1.0e15 }

synthBurn :: Text -> Integer -> BurnEvent
synthBurn tid e = BurnEvent
  { beTokenId = tid, beAccount = "0xacct"
  , beTimestamp = e * fromIntegral hourSecs, beBlock = e
  , beTickAt = -200000, bePremium0 = 3.0e12, bePremium1 = 0
  , bePositionSize = 1.0e15 }

synthLeg :: Int -> Int -> Bool -> LegChunk
synthLeg ix strike isLong =
  LegChunk { lcLegIndex = ix
           , lcChunkKey = ChunkKey 0 (strike - 1200) (strike + 1200)
           , lcIsLong = isLong, lcLiquidity = 1000, lcStrike = strike
           , lcWidth = 240 }

-- | A premium observation for @(tokenId, legIndex, epoch)@ carrying @wei@.
synthObs :: Text -> Int -> Integer -> Integer -> [PremiumFlag] -> PremiumObs
synthObs tid ix e wei flags = PremiumObs
  { poTokenId = tid, poLegIndex = ix, poEpoch = e
  , poPremiumWei0 = wei, poPremiumWei1 = 0
  , poIsLong = False, poStrikeTick = -199920, poFlags = flags }

varRow :: Double -> Double -> Int -> Int -> VarianceRow
varRow s2 s2i tick n = VarianceRow s2 s2i tick n

-- | Variance rows for epochs 100..102.
synthVar :: Map.Map Int VarianceRow
synthVar = Map.fromList
  [ (100, varRow 1.0e-4 1.2e-4 (-200100) 150)
  , (101, varRow 2.0e-4 2.2e-4 (-200200) 160)
  , (102, varRow 3.0e-4 3.2e-4 (-200300) 170)
  ]

-- | One three-hour position with a single short leg at strike −199920.
synthSpells :: [(Text, MintEvent, BurnEvent, [LegChunk])]
synthSpells = [("tok1", synthMint "tok1" 100, synthBurn "tok1" 102,
                [synthLeg 0 (-199920) False])]

synthObsList :: [PremiumObs]
synthObsList =
  [ synthObs "tok1" 0 100 1000 []
  , synthObs "tok1" 0 101 2000 [ChunkEmpty]
  , synthObs "tok1" 0 102 3000 []
  ]

panelJoinSpec :: Spec
panelJoinSpec = describe "panel join" $ do

  it "produces one row per (tokenId, epoch)" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    length rows `shouldBe` 3
    map (\r -> (eoTokenId r, eoEpoch r)) rows
      `shouldBe` [("tok1", 100), ("tok1", 101), ("tok1", 102)]

  it "reports ZERO unmatched epochs when every epoch has a variance row" $ do
    let (_, unmatched) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    unmatched `shouldBe` []

  -- The 09-05 40587-offset trap, in the form it would take here: a premium epoch
  -- with no variance row must SURFACE, not vanish into a smaller clean panel.
  it "REPORTS an epoch missing from the variance map instead of dropping it silently" $ do
    let gappy      = Map.delete 101 synthVar
        (rows, um) = assembleEpochPanel hourSecs gappy synthSpells synthObsList
    um `shouldBe` [101]
    map eoEpoch rows `shouldBe` [100, 102]

  it "excludes epochs outside the position's [epoch_mint, epoch_burn] window" $ do
    let outside = synthObsList ++ [ synthObs "tok1" 0 99  500 []
                                  , synthObs "tok1" 0 103 500 [] ]
        wider   = Map.insert 99 (varRow 1 1 (-200000) 10)
                    (Map.insert 103 (varRow 1 1 (-200000) 10) synthVar)
        (rows, um) = assembleEpochPanel hourSecs wider synthSpells outside
    um `shouldBe` []
    map eoEpoch rows `shouldBe` [100, 101, 102]

  -- The telescoping property, now at PANEL level: the per-epoch rows are a
  -- decomposition of the spell total the 10-08 gate validated.
  it "sums premium_wei over a tokenId's epoch rows to the spell total EXACTLY" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    sum (map eoPremiumWei rows) `shouldBe` (1000 + 2000 + 3000 :: Integer)

  it "sums legs within an epoch and records the leg count" $ do
    let twoLeg = [("tok1", synthMint "tok1" 100, synthBurn "tok1" 102,
                   [synthLeg 0 (-199920) False, synthLeg 1 (-198960) False])]
        obs    = [ synthObs "tok1" 0 100 1000 []
                 , synthObs "tok1" 1 100  250 [] ]
        (rows, _) = assembleEpochPanel hourSecs synthVar twoLeg obs
    map eoPremiumWei rows `shouldBe` [1250]
    map eoLegCount   rows `shouldBe` [2]

  it "computes moneyness with Model.Upsilon.moneyness, not a local reimplementation" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    map eoMoneyness rows
      `shouldBe` [ moneyness (-199920) t | t <- [-200100, -200200, -200300] ]

  it "carries Leg.strike straight through as an int24 tick (no log remap, no NaN)" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    map eoStrikeTick rows `shouldBe` [-199920, -199920, -199920]
    map eoMoneyness  rows `shouldSatisfy` all (not . isNaN)

  it "retains flagged rows and marks them rather than dropping them" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
        flagged   = [ r | r <- rows, not (null (eoFlags r)) ]
    length flagged `shouldBe` 1
    map eoEpoch flagged `shouldBe` [101]
    map eoFlags flagged `shouldBe` [["ChunkEmpty"]]

  -- The identification claim of the whole phase: WITHIN-position variation.
  -- Phase 9 had exactly zero of it (one window-averaged sigma^2 per spell).
  it "gives at least one tokenId more than one epoch row (within-position variation)" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
        perTok    = Map.fromListWith (+) [ (eoTokenId r, 1 :: Int) | r <- rows ]
    length [ () | c <- Map.elems perTok, c > 1 ] `shouldSatisfy` (> 0)
    -- and the regressor genuinely MOVES across those rows
    length (nub (map eoSigma2 rows)) `shouldSatisfy` (> 1)

  it "carries the epoch's sigma2 / instrument / swap count onto the row" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    map eoSigma2      rows `shouldBe` [1.0e-4, 2.0e-4, 3.0e-4]
    map eoSigma2Instr rows `shouldBe` [1.2e-4, 2.2e-4, 3.2e-4]
    map eoNSwaps      rows `shouldBe` [150, 160, 170]

  it "carries the holding account (the coarser cluster) onto every row" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    map eoAccount rows `shouldBe` ["0xacct", "0xacct", "0xacct"]

  it "premium_eth is premium_wei / 1e18" $ do
    let (rows, _) = assembleEpochPanel hourSecs synthVar synthSpells synthObsList
    map eoPremiumEth rows `shouldBe` [1000 / 1e18, 2000 / 1e18, 3000 / 1e18]

  it "the header names the columns the artifact and its readers agree on" $
    epochPanelHeader `shouldBe`
      "token_id,account,epoch,premium_wei,premium_eth,strike_tick,pool_tick,\
      \moneyness,is_long,leg_count,flags,sigma2,sigma2_instrument,n_swaps"
