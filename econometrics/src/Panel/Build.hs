{-# LANGUAGE OverloadedStrings #-}

-- | Position-spell panel assembler (CTX-PANEL, plan 09-04; rebuilt at the 09-09
-- live run against the real subgraph schema).
--
-- == The unit of observation (CHANGED at 09-09 — read this)
--
-- The spec (§1) asks for a POSITION-EPOCH panel: one π_it per tokenId per daily
-- epoch, built by diffing cumulative settled-premia snapshots. The live Panoptic
-- Base subgraph cannot deliver that object (see "Panel.Subgraph" for the
-- introspection record):
--
--   * @TokenId@ has no @snapshots@ field — there is no per-epoch premium series;
--   * @premiumSettleds@ is EMPTY and @AccountBalance.premiaSettled{0,1}Total@ is
--     identically ZERO on this market, so the settled-premia channel is silent.
--
-- The only premium the chain actually reports is @OptionBurn.premium{0,1}@: the
-- premium realized over a position's ENTIRE life. The honest unit of observation
-- is therefore the __accrual spell__ — one observation per (mint, burn) pair —
-- with π expressed as a premium RATE PER DAY over the spell and σ̂² averaged over
-- the same window.
--
-- This is a real departure from the spec's stated design and it is NOT hidden:
-- it is reported in the phase analysis output, and it costs within-position time
-- variation, which is why the position-FE alternative is expected to be
-- unidentified. Spreading a spell's premium across its days was REJECTED — a
-- constant π against a varying σ̂² would manufacture a mechanical null.
--
-- == Invariants carried from the spec / research
--
--   * π is a FLOW, never a cumulative stock (spec §4.3; RESEARCH Pitfall 2).
--     The burn premium is already a flow over the spell.
--   * i_K is the strike TICK on the λ=1.0001 grid — the same grid as
--     @PosSpec.lam@ / @PosSpec.tickPrice@ on the Lean side. The subgraph's
--     @Leg.strike@ IS that tick already ('Panel.Subgraph.legStrikeTick').
--   * 'dailyEpoch' buckets a UTC instant into whole days since the Unix epoch at
--     __00:00 UTC__ (@floor(unixSeconds / 86400)@). The SAME boundary is used by
--     the variance window in "Panel.Variance", so σ̂²_t lines up with the spell
--     windows (RESEARCH Pitfall 4).
module Panel.Build
  ( Epoch
  , dailyEpoch
  , Spell (..)
  , assembleSpells
  , tickToPrice
  , premiumUsd
  , writePanelCsv
  ) where

import qualified Data.ByteString.Lazy   as BL
import qualified Data.Csv               as Csv
import           Data.List              (sortOn)
import qualified Data.Map.Strict        as Map
import           Data.Maybe             (mapMaybe)
import           Data.Text              (Text)
import           Data.Time.Clock        (UTCTime)
import           Data.Time.Clock.POSIX  (posixSecondsToUTCTime, utcTimeToPOSIXSeconds)

import           Panel.Subgraph         (BurnEvent (..), Leg (..), MintEvent (..))

-- | Daily epoch index: whole UTC days since the Unix epoch (00:00 UTC bucket).
type Epoch = Int

-- | Bucket a UTC instant into its daily epoch. Boundary fixed at 00:00 UTC; the
-- SAME definition is used by the variance window in "Panel.Variance".
dailyEpoch :: UTCTime -> Int
dailyEpoch t = floor (realToFrac (utcTimeToPOSIXSeconds t) / (86400 :: Double))

-- | Epoch of a unix-second timestamp.
epochOfUnix :: Integer -> Epoch
epochOfUnix = dailyEpoch . posixSecondsToUTCTime . fromInteger

-- ---------------------------------------------------------------------------
-- The accrual spell
-- ---------------------------------------------------------------------------

-- | One position accrual spell: a tokenId held by an account from its mint to
-- its burn, with the premium realized over that window.
data Spell = Spell
  { spTokenId    :: !Text
  , spAccount    :: !Text     -- ^ the position holder (a coarser cluster than tokenId).
  , spMintEpoch  :: !Epoch
  , spBurnEpoch  :: !Epoch
  , spDays       :: !Double   -- ^ spell length in days (burn − mint, in seconds/86400).
  , spPremiumUsd :: !Double   -- ^ TOTAL premium over the spell, USD, seller-side sign.
  , spPremiumRate:: !Double   -- ^ π: premium per DAY = 'spPremiumUsd' / 'spDays'.
  , spStrikeTick :: !Int      -- ^ i_K (the position's first leg's strike tick).
  , spTickAtMint :: !Int
  , spTickAtBurn :: !Int
  , spIsLong     :: !Bool     -- ^ True ⇒ the holder PAID the premium.
  }
  deriving (Show, Eq)

-- | Tick → price of token0 in token1 units, on the λ = 1.0001 grid, adjusted for
-- the decimal difference: @p(i) = 1.0001^i · 10^(dec0 − dec1)@.
--
-- For the confirmed market (ETH 18 dec / USDC 6 dec) the caller passes
-- @decimalShift = 12@, so a pool tick of −200 340 gives ≈ 1992 USDC per ETH.
tickToPrice :: Int -> Int -> Double
tickToPrice decimalShift tick =
  1.0001 ** fromIntegral tick * 10 ** fromIntegral decimalShift

-- | The spell's premium in USD, with the SELLER-SIDE sign convention.
--
-- @premium0@ is the premium denominated in token0 (ETH, 18 decimals); it is
-- converted at the pool price implied by the burn tick. token0 is used rather
-- than token1 because USDC's 6 decimals truncate small premia to zero: on the
-- live market 61 burns carry a non-zero @premium0@ but only 38 a non-zero
-- @premium1@ (the two agree to within a few tenths of a percent where both are
-- non-zero, confirming they are one premium in two denominations).
--
-- The protocol emits premium POSITIVE for short positions (the seller receives)
-- and NEGATIVE for long ones (the buyer pays). Long spells are sign-flipped so
-- π is uniformly "premium accrued to the short side" — otherwise the same vega
-- would enter the regression with two opposite signs and cancel.
premiumUsd :: Int -> Bool -> BurnEvent -> Double
premiumUsd decimalShift isLong b =
  sign * (bePremium0 b / 1e18) * tickToPrice decimalShift (beTickAt b)
  where sign = if isLong then -1 else 1

-- | Assemble accrual spells from the full-history mint/burn/leg pulls.
--
-- Each burn is paired with the LATEST mint of the same (tokenId, account) that
-- strictly precedes it — the spell the burn closes. Burns with no prior mint,
-- with an unknown tokenId, with a zero premium, or with a non-positive duration
-- are dropped; the counts are reported by the CLI so the attrition is visible.
--
-- @decimalShift@ = token0 decimals − token1 decimals (12 for ETH/USDC).
assembleSpells :: Int -> [MintEvent] -> [BurnEvent] -> [(Text, [Leg])] -> [Spell]
assembleSpells decimalShift mints burns legs =
  sortOn spBurnEpoch (mapMaybe toSpell burns)
  where
    legMap = Map.fromList legs

    -- (tokenId, account) → its mints, ascending by timestamp.
    mintIx = Map.fromListWith (flip (++))
               [ ((meTokenId m, meAccount m), [m]) | m <- sortOn meTimestamp mints ]

    toSpell b = do
      ls <- Map.lookup (beTokenId b) legMap
      l  <- case ls of { (x : _) -> Just x; [] -> Nothing }
      ms <- Map.lookup (beTokenId b, beAccount b) mintIx
      m  <- lastMay [ x | x <- ms, meTimestamp x < beTimestamp b ]
      let days   = fromInteger (beTimestamp b - meTimestamp m) / 86400
          isLong = legIsLong l
          usd    = premiumUsd decimalShift isLong b
      if days <= 0 || usd == 0 || isNaN usd || isInfinite usd
        then Nothing
        else Just Spell
          { spTokenId     = beTokenId b
          , spAccount     = beAccount b
          , spMintEpoch   = epochOfUnix (meTimestamp m)
          , spBurnEpoch   = epochOfUnix (beTimestamp b)
          , spDays        = days
          , spPremiumUsd  = usd
          , spPremiumRate = usd / days
          , spStrikeTick  = legStrikeTick l
          , spTickAtMint  = meTickAt m
          , spTickAtBurn  = beTickAt b
          , spIsLong      = isLong
          }

    lastMay [] = Nothing
    lastMay xs = Just (last xs)

-- ---------------------------------------------------------------------------
-- CSV output
-- ---------------------------------------------------------------------------

-- | Self-describing CSV row for @notes/structural-econometrcics/data/panel.csv@.
data PanelRow = PanelRow
  { prTokenId     :: !Text
  , prAccount     :: !Text
  , prMintEpoch   :: !Int
  , prBurnEpoch   :: !Int
  , prDays        :: !Double
  , prPremiumUsd  :: !Double
  , prPremiumRate :: !Double
  , prStrikeTick  :: !Int
  , prTickAtMint  :: !Int
  , prTickAtBurn  :: !Int
  , prIsLong      :: !Int
  }

panelHeader :: Csv.Header
panelHeader = Csv.header
  [ "tokenId", "account", "epoch_mint", "epoch_burn", "spell_days"
  , "premium_usd", "premium_usd_per_day", "strike_tick"
  , "tick_at_mint", "tick_at_burn", "is_long" ]

instance Csv.ToNamedRecord PanelRow where
  toNamedRecord r = Csv.namedRecord
    [ "tokenId"             Csv..= prTokenId r
    , "account"             Csv..= prAccount r
    , "epoch_mint"          Csv..= prMintEpoch r
    , "epoch_burn"          Csv..= prBurnEpoch r
    , "spell_days"          Csv..= prDays r
    , "premium_usd"         Csv..= prPremiumUsd r
    , "premium_usd_per_day" Csv..= prPremiumRate r
    , "strike_tick"         Csv..= prStrikeTick r
    , "tick_at_mint"        Csv..= prTickAtMint r
    , "tick_at_burn"        Csv..= prTickAtBurn r
    , "is_long"             Csv..= prIsLong r
    ]

instance Csv.DefaultOrdered PanelRow where
  headerOrder _ = panelHeader

-- | Write the spell panel to CSV with a header row. σ̂² is NOT stored here — it
-- is joined at estimation time from @variance.csv@ over each spell's epoch
-- window, so there is exactly one source of truth for the variance series.
writePanelCsv :: FilePath -> [Spell] -> IO ()
writePanelCsv fp spells =
  BL.writeFile fp (Csv.encodeDefaultOrderedByName (map toRow spells))
  where
    toRow s = PanelRow
      { prTokenId     = spTokenId s
      , prAccount     = spAccount s
      , prMintEpoch   = spMintEpoch s
      , prBurnEpoch   = spBurnEpoch s
      , prDays        = spDays s
      , prPremiumUsd  = spPremiumUsd s
      , prPremiumRate = spPremiumRate s
      , prStrikeTick  = spStrikeTick s
      , prTickAtMint  = spTickAtMint s
      , prTickAtBurn  = spTickAtBurn s
      , prIsLong      = if spIsLong s then 1 else 0
      }
