{-# LANGUAGE OverloadedStrings #-}

-- | Position panel assembler (CTX-PANEL, plan 09-04; rebuilt at the 09-09 live
-- run against the real subgraph schema; the position-epoch unit RESTORED at
-- plan 10-09).
--
-- == PHASE 10 RESTORED THE POSITION-EPOCH UNIT (read this first)
--
-- The 09-09 note below is retained verbatim because it records a real constraint
-- that was real at the time — but it is __no longer the binding one__. Phase 10
-- obtained the per-epoch premium series that the subgraph could not supply, by
-- reading the accumulator off CHAIN STATE instead:
--
--   * @SFPM.getAccountPremium@ was read at every HOURLY epoch boundary inside
--     each spell's block window, plus the exact mint and burn blocks
--     (8,910 archive @eth_call@s, plan 10-06);
--   * the per-epoch premium is the X64 accumulator difference times the leg
--     liquidity ('Panoptic.Premium.premiumWei'), the SAME arithmetic
--     @PanopticPool._getPremia@ uses;
--   * that reconstruction was scored against the protocol's own
--     @OptionBurn.premium0@ on all 61 spells in Integer wei and __PASSED__ at a
--     short-stratum median relative error of exactly 0.0, 53 of 61 exact to the
--     wei (plan 10-08, @gateTolerance = 0.01@ untouched).
--
-- So 'assembleEpochPanel' below produces the spec §1 unit — one row per
-- (tokenId, epoch) — on the HOURLY grid the 10-01 census selected, and the
-- within-position time variation that Phase 9 had exactly zero of exists again.
--
-- __'assembleSpells' is retained and is still THE gate's ground truth.__ The
-- spell panel is the population the 1%-wei gate reconciles against, and
-- 'assembleEpochPanel' is validated by summing its rows back to that panel's
-- endpoint totals. Do not delete the spell path to \"clean up\" the module: it is
-- the independent check on the thing that replaced it.
--
-- == The unit of observation (CHANGED at 09-09, SUPERSEDED at 10-09)
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
  ( -- * The epoch grid (re-exported from "Panel.Epoch", the leaf that owns it)
    Epoch
  , dailyEpoch
  , epochOfSeconds
  , hourlyEpoch
    -- * The accrual spell (Phase 9; retained as the gate's ground truth)
  , Spell (..)
  , assembleSpells
  , assembleSpellsWithWindows
  , assembleSpellRaws
  , tickToPrice
  , premiumUsd
  , writePanelCsv
    -- * The position-epoch panel (Phase 10; the spec §1 unit, restored)
  , EpochObs (..)
  , VarianceRow (..)
  , assembleEpochPanel
  , epochPanelHeader
  , writeEpochPanelCsv
  ) where

import qualified Data.ByteString.Lazy   as BL
import qualified Data.Csv               as Csv
import           Data.List              (intercalate, nub, sort, sortOn)
import           Data.Map.Strict        (Map)
import qualified Data.Map.Strict        as Map
import           Data.Maybe             (mapMaybe)
import           Data.Text              (Text)
import qualified Data.Text              as T
import           Data.Time.Clock        (UTCTime)
import           Data.Time.Clock.POSIX  (posixSecondsToUTCTime, utcTimeToPOSIXSeconds)

import           Model.Upsilon          (moneyness)
import           Panel.Epoch            (Epoch, epochOfSeconds, hourlyEpoch)
import           Panel.Subgraph         (BurnEvent (..), Leg (..), MintEvent (..))
import           Panoptic.Chunk         (LegChunk (..))
import           Panoptic.Premium       (PremiumObs (..))

-- | Bucket a UTC instant into its daily epoch. Boundary fixed at 00:00 UTC; the
-- SAME definition is used by the variance window in "Panel.Variance".
--
-- __Deliberately defined here and nowhere else, byte-identical since 09-04.__
-- The generalized 'Panel.Epoch.epochOfSeconds' (re-exported above) must agree
-- with it pointwise at width 86400, and "Panel.BuildSpec" asserts that.
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
  map fst (assembleSpellsWithWindows decimalShift mints burns legs)

-- | 'assembleSpells', but each spell is paired with the EXACT @(mintUnix,
-- burnUnix)@ second-resolution window the pairing rule selected.
--
-- 'assembleSpells' is defined as @map fst@ of this function, so there is exactly
-- ONE implementation of the mint↔burn pairing rule. Callers that need sub-daily
-- resolution (the 10-01 hourly census) take the raw window from here rather than
-- re-deriving the pairing, and callers that only need the daily panel keep the
-- original signature. @spMintEpoch@/@spBurnEpoch@ of the returned 'Spell' remain
-- DAILY indices — the window is the extra information, not a replacement.
assembleSpellsWithWindows
  :: Int -> [MintEvent] -> [BurnEvent] -> [(Text, [Leg])] -> [(Spell, (Integer, Integer))]
assembleSpellsWithWindows decimalShift mints burns legs =
  [ (sp, win) | (sp, win, _, _) <- assembleSpellFull decimalShift mints burns legs ]

-- | The mint↔burn pairing with the RAW paired events retained, keyed by tokenId.
-- Consumed by the 10-06 read driver, which needs the actual 'MintEvent' /
-- 'BurnEvent' blocks and ticks (not the derived 'Spell') to build the accumulator
-- read schedule. A projection of 'assembleSpellFull', so there is still exactly
-- ONE pairing rule shared with 'assembleSpellsWithWindows'.
assembleSpellRaws
  :: Int -> [MintEvent] -> [BurnEvent] -> [(Text, [Leg])] -> [(Text, MintEvent, BurnEvent)]
assembleSpellRaws decimalShift mints burns legs =
  [ (spTokenId sp, m, b) | (sp, _, m, b) <- assembleSpellFull decimalShift mints burns legs ]

-- | The single pairing implementation: for each burn, its position's legs, the
-- last mint before it (same tokenId+account), and the derived 'Spell', the
-- second-resolution @(mintUnix, burnUnix)@ window, and the raw paired events.
-- 'assembleSpellsWithWindows' and 'assembleSpellRaws' are projections of this, so
-- the pairing and the @days>0 ∧ usd≠0@ acceptance filter are defined exactly once.
assembleSpellFull
  :: Int -> [MintEvent] -> [BurnEvent] -> [(Text, [Leg])]
  -> [(Spell, (Integer, Integer), MintEvent, BurnEvent)]
assembleSpellFull decimalShift mints burns legs =
  sortOn (\(sp, _, _, _) -> spBurnEpoch sp) (mapMaybe toSpell burns)
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
          window = (meTimestamp m, beTimestamp b)
          sp = Spell
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
      if days <= 0 || usd == 0 || isNaN usd || isInfinite usd
        then Nothing
        else Just (sp, window, m, b)

    lastMay [] = Nothing
    lastMay xs = Just (last xs)

-- ---------------------------------------------------------------------------
-- The position-epoch panel (plan 10-09) — the spec §1 unit of observation
-- ---------------------------------------------------------------------------

-- | One row of the variance series, as the panel consumes it: σ̂²_t, the EIV
-- instrument σ̃²_t, the mean pool tick i_t, and the swap count behind them.
data VarianceRow = VarianceRow
  { varSigma2      :: !Double
  , varSigma2Instr :: !Double
  , varPoolTick    :: !Int     -- ^ i_t, ROUNDED to the tick grid the strike lives on.
  , varNSwaps      :: !Int     -- ^ increments behind σ̂² is @varNSwaps − 1@.
  }
  deriving (Show, Eq)

-- | One position-epoch observation: the spec §1 unit. @π_it@ with its moneyness
-- anchor and the epoch's variance regressors, ready for @Model.Upsilon.model@.
data EpochObs = EpochObs
  { eoTokenId     :: !Text
  , eoAccount     :: !Text
  , eoEpoch       :: !Epoch
  , eoPremiumWei  :: !Integer  -- ^ CANONICAL. Integer wei, currency0 (ETH).
  , eoPremiumEth  :: !Double   -- ^ @eoPremiumWei \/ 1e18@ — the regression LHS.
  , eoStrikeTick  :: !Int      -- ^ i_K. 'Leg.strike' IS an int24 tick already.
  , eoPoolTick    :: !Int      -- ^ i_t, from the epoch's mean pool tick.
  , eoMoneyness   :: !Double   -- ^ @Model.Upsilon.moneyness eoStrikeTick eoPoolTick@.
  , eoIsLong      :: !Bool
  , eoLegCount    :: !Int      -- ^ legs contributing to this row's premium.
  , eoFlags       :: ![Text]
  , eoSigma2      :: !Double   -- ^ σ̂²_t for this epoch.
  , eoSigma2Instr :: !Double   -- ^ σ̃²_t, the disjoint-window EIV instrument.
  , eoNSwaps      :: !Int      -- ^ swaps behind this epoch's σ̂².
  }
  deriving (Show, Eq)

-- | __Assemble the position-epoch panel and join it to the variance series.__
--
-- Inputs:
--
--   * @epochSeconds@ — the grid width. 3600 for Phase 10 (the 10-01 HOURLY
--     re-scope); 86400 reproduces the daily design. Bucketing goes through
--     'Panel.Epoch.epochOfSeconds', never a local divisor.
--   * the variance series, keyed on the SAME integer epoch index;
--   * the spells, for each position's account, stratum, strike and epoch window;
--   * the per-(leg, epoch) premium observations — produced by
--     'Panoptic.Premium.buildSpellPremiumObs' (which decomposes the SAME X64
--     accumulator arithmetic 'Panoptic.Premium.buildPremiumObs' /
--     @PanopticPool._getPremia@ use). This function does __no premium arithmetic
--     of its own__; it aggregates and joins.
--
-- Returns @(rows, unmatchedEpochs)@.
--
-- == The unmatched list is RETURNED, not filtered
--
-- @unmatchedEpochs@ is every distinct epoch that carried a premium observation
-- but has NO variance row. It is surfaced rather than quietly dropped because a
-- silent drop is precisely how the 09-05 40587-offset bug survived: the two sides
-- bucketed onto different grids, the join threw away everything that did not
-- match, and what came out the far end looked like a small clean panel instead of
-- like a catastrophe. __The caller must treat a non-empty list as a hard error.__
--
-- == Two independent window guards
--
-- A premium observation is admitted only if its epoch lies inside one of its
-- position's @[epoch_mint, epoch_burn]@ windows. That is deliberately redundant
-- with the block-window restriction in 'Panoptic.Premium.buildSpellPremiumObs':
-- the block guard uses the read schedule's blocks, this one uses the subgraph's
-- event timestamps, and they can only agree if the epoch↔block index is sound.
--
-- == Multi-leg positions
--
-- Premium is SUMMED over the position's legs within the epoch (that is what the
-- scalar @OptionBurn.premium0@ ground truth also is), and @eoLegCount@ records
-- how many contributed. @eoStrikeTick@ and @eoIsLong@ come from the position's
-- FIRST resolved leg — the same rule 'assembleSpells' and the 10-08 gate's
-- stratum use, so the three cannot disagree. For a genuine two-strike position
-- that single strike is an approximation of the position's moneyness, which is
-- why @leg_count@ is carried in the artifact rather than dropped.
assembleEpochPanel
  :: Int
  -> Map Epoch VarianceRow
  -> [(Text, MintEvent, BurnEvent, [LegChunk])]
  -> [PremiumObs]
  -> ([EpochObs], [Epoch])
assembleEpochPanel epochSeconds varMap spells obs = (rows, unmatched)
  where
    epochOfUnix' :: Integer -> Epoch
    epochOfUnix' = epochOfSeconds epochSeconds . posixSecondsToUTCTime . fromInteger

    -- tokenId -> the account that held it (the coarser cluster).
    accountOf = Map.fromList [ (tid, meAccount m) | (tid, m, _, _) <- spells ]

    -- tokenId -> every [mintEpoch, burnEpoch] window it was open in. A tokenId
    -- can be minted and burned more than once (61 spells over 55 tokenIds), so
    -- this is a LIST of windows, not one interval.
    windowsOf = Map.fromListWith (++)
      [ (tid, [(epochOfUnix' (meTimestamp m), epochOfUnix' (beTimestamp b))])
      | (tid, m, b, _) <- spells ]

    -- tokenId -> (strike tick, is_long) of its FIRST resolved leg.
    firstLegOf = Map.fromList
      [ (tid, (lcStrike lc, lcIsLong lc))
      | (tid, _, _, lcs) <- spells, lc <- take 1 (sortOn lcLegIndex lcs) ]

    inWindow tid e = case Map.lookup tid windowsOf of
      Nothing -> False
      Just ws -> or [ e >= lo && e <= hi | (lo, hi) <- ws ]

    admitted = [ o | o <- obs
               , let e = fromIntegral (poEpoch o)
               , inWindow (poTokenId o) e ]

    grouped :: Map (Text, Epoch) [PremiumObs]
    grouped = Map.fromListWith (++)
      [ ((poTokenId o, fromIntegral (poEpoch o)), [o]) | o <- admitted ]

    unmatched = sort (nub [ e | ((_, e), _) <- Map.toList grouped
                          , not (Map.member e varMap) ])

    rows =
      [ mkRow tid e os vr
      | ((tid, e), os) <- Map.toAscList grouped
      , Just vr <- [Map.lookup e varMap] ]

    mkRow tid e os vr =
      let wei          = sum (map poPremiumWei0 os)
          (ik, isLong) = Map.findWithDefault (0, False) tid firstLegOf
          it           = varPoolTick vr
      in EpochObs
           { eoTokenId     = tid
           , eoAccount     = Map.findWithDefault "" tid accountOf
           , eoEpoch       = e
           , eoPremiumWei  = wei
           , eoPremiumEth  = fromInteger wei / 1e18
           , eoStrikeTick  = ik
           , eoPoolTick    = it
             -- THE estimator's own function, never a local |iK - it|: the panel
             -- and Model.Upsilon.model cannot drift apart if they share it.
           , eoMoneyness   = moneyness ik it
           , eoIsLong      = isLong
           , eoLegCount    = length (nub (map poLegIndex os))
           , eoFlags       = map (T.pack . show) (nub (sort (concatMap poFlags os)))
           , eoSigma2      = varSigma2 vr
           , eoSigma2Instr = varSigma2Instr vr
           , eoNSwaps      = varNSwaps vr
           }

-- | The position-epoch panel's column header. A single definition, so the writer
-- and any acceptance grep read the same string.
epochPanelHeader :: String
epochPanelHeader =
  "token_id,account,epoch,premium_wei,premium_eth,strike_tick,pool_tick,\
  \moneyness,is_long,leg_count,flags,sigma2,sigma2_instrument,n_swaps"

-- | Write the position-epoch panel, preceded by a caller-supplied @#@ provenance
-- banner.
--
-- @premium_wei@ is written as an exact 'Integer' — it is the canonical quantity
-- and the one that must sum back to the gate. @premium_eth@ is the 'Double'
-- convenience column the regression reads. σ̂² and σ̃² ARE stored here (unlike the
-- Phase-9 spell panel, which joined them at estimation time) because the join is
-- exactly what this plan validates: freezing the joined result is what makes
-- @UNMATCHED_EPOCHS@ a property of the committed artifact rather than of a
-- re-run.
writeEpochPanelCsv :: FilePath -> [String] -> [EpochObs] -> IO ()
writeEpochPanelCsv fp bannerLines rows =
  writeFile fp (unlines bannerLines ++ epochPanelHeader ++ "\n" ++ body)
  where
    body = unlines
      [ intercalate ","
          [ T.unpack (eoTokenId r)
          , T.unpack (eoAccount r)
          , show (eoEpoch r)
          , show (eoPremiumWei r)
          , show (eoPremiumEth r)
          , show (eoStrikeTick r)
          , show (eoPoolTick r)
          , show (eoMoneyness r)
          , if eoIsLong r then "1" else "0"
          , show (eoLegCount r)
          , intercalate ";" (map T.unpack (eoFlags r))
          , show (eoSigma2 r)
          , show (eoSigma2Instr r)
          , show (eoNSwaps r)
          ]
      | r <- rows ]

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
