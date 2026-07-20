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
import           Data.List            (sortOn)
import           Test.Hspec

import           Panel.Build          (Spell (..), assembleSpells, premiumUsd,
                                       tickToPrice)
import           Panel.Subgraph       (BurnEvent (..), parseBurns, parseLegs,
                                       parseMints)

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
