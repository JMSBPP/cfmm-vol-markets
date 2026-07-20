{-# LANGUAGE OverloadedStrings #-}

-- | Position-epoch panel assembler (CTX-PANEL, plan 09-04).
--
-- Turns the raw subgraph snapshots ("Panel.Subgraph") into the tokenId × daily
-- panel of "Econ.Types".'Obs' and writes it to CSV. Two invariants carried from
-- the spec / research:
--
--   * π_it is the per-epoch DELTA of the CUMULATIVE @premiaSettled*Total@, never
--     the raw cumulative total (spec §4.3; RESEARCH Pitfall 2).
--   * i_K is the strike tick on the λ=1.0001 grid, @round(log K / log 1.0001)@,
--     the same grid as @PosSpec.lam@ / @PosSpec.tickPrice@ on the Lean side.
--
-- == The daily epoch (defined ONCE)
--
-- 'dailyEpoch' buckets a UTC instant into whole days since the Unix epoch at
-- __00:00 UTC__ (@floor(unixSeconds / 86400)@). This SAME boundary is reused by
-- plan 09-05's within-day variance window, so the σ̂²_t series (joined later)
-- lines up with the premium epochs (avoids the tick-unit mismatch, RESEARCH
-- Pitfall 4).
module Panel.Build
  ( Epoch
  , dailyEpoch
  , deltaPremia
  , strikeToTick
  , assemble
  , writePanelCsv
  ) where

import qualified Data.ByteString.Lazy   as BL
import qualified Data.Csv               as Csv
import           Data.List              (sortOn)
import           Data.Text              (Text)
import           Data.Time.Clock        (UTCTime)
import           Data.Time.Clock.POSIX  (posixSecondsToUTCTime, utcTimeToPOSIXSeconds)

import           Econ.Types             (Obs (..), Panel)
import           Panel.Subgraph         (Leg (..), RawPosition (..), Snapshot (..))

-- | Daily epoch index: whole UTC days since the Unix epoch (00:00 UTC bucket).
type Epoch = Int

-- | Bucket a UTC instant into its daily epoch. Boundary fixed at 00:00 UTC; the
-- SAME definition is reused by the 09-05 variance window.
dailyEpoch :: UTCTime -> Int
dailyEpoch t = floor (realToFrac (utcTimeToPOSIXSeconds t) / (86400 :: Double))

-- | Epoch of a snapshot, from its Unix-seconds timestamp.
epochOf :: Snapshot -> Epoch
epochOf = dailyEpoch . posixSecondsToUTCTime . fromInteger . snapTimestamp

-- | Per-epoch premium flows: sort snapshots by time and diff consecutive
-- CUMULATIVE @premiaSettledInUsdTotal@ values, tagging each flow with the epoch
-- of the ENDING snapshot. @N@ snapshots yield @N−1@ flows.
deltaPremia :: [Snapshot] -> [(Epoch, Double)]
deltaPremia snaps = [ (e, d) | (e, d, _) <- epochRows snaps ]

-- | Like 'deltaPremia' but also carries the pool tick i_t of the ending snapshot.
epochRows :: [Snapshot] -> [(Epoch, Double, Int)]
epochRows snaps =
  [ (epochOf b, snapPremiaUsd b - snapPremiaUsd a, snapPoolTick b)
  | (a, b) <- zip sorted (drop 1 sorted)
  ]
  where
    sorted = sortOn snapTimestamp snaps

-- | Strike price → tick on the λ=1.0001 grid: @i_K = round(log K / log 1.0001)@.
-- Mirrors @PosSpec.lam@ (λ = 1.0001) so the Haskell i_K matches the Lean tick.
strikeToTick :: Double -> Int
strikeToTick strike = round (log strike / log 1.0001)

-- | Placeholder σ̂² for the not-yet-joined variance columns (filled in 09-05).
-- NaN so any accidental use before the join fails loudly rather than silently
-- contributing a 0.
placeholderSigma2 :: Double
placeholderSigma2 = 0 / 0

-- | Assemble raw positions into the panel: one 'Obs' per (tokenId, epoch), with
-- π_it the per-epoch premium delta, i_K the first leg's strike tick, i_t the
-- pool tick at the epoch, and σ̂² left as the 'placeholderSigma2' (09-05 join).
assemble :: [RawPosition] -> Panel
assemble = concatMap posRows
  where
    posRows p =
      [ Obs
          { obsTokenId     = rpTokenId p
          , obsEpoch       = e
          , obsPremium     = d
          , obsStrikeTick  = tick
          , obsPoolTick    = it
          , obsSigma2      = placeholderSigma2
          , obsSigma2Instr = placeholderSigma2
          }
      | (e, d, it) <- epochRows (rpSnapshots p)
      ]
      where
        tick = case rpLegs p of
          (l : _) -> strikeToTick (legStrike l)
          []      -> 0

-- CSV output -----------------------------------------------------------------

-- | Self-describing CSV row for @notes/structural-econometrcics/data/panel.csv@.
data PanelRow = PanelRow
  { prTokenId      :: !Text
  , prEpoch        :: !Int
  , prPremiumDelta :: !Double
  , prStrikeTick   :: !Int
  , prPoolTick     :: !Int
  , prSigma2       :: !Double
  }

instance Csv.ToNamedRecord PanelRow where
  toNamedRecord r =
    Csv.namedRecord
      [ "tokenId"            Csv..= prTokenId r
      , "epoch"              Csv..= prEpoch r
      , "premium_delta"      Csv..= prPremiumDelta r
      , "strike_tick"        Csv..= prStrikeTick r
      , "pool_tick"          Csv..= prPoolTick r
      , "sigma2_placeholder" Csv..= prSigma2 r
      ]

instance Csv.DefaultOrdered PanelRow where
  headerOrder _ =
    Csv.header
      [ "tokenId"
      , "epoch"
      , "premium_delta"
      , "strike_tick"
      , "pool_tick"
      , "sigma2_placeholder"
      ]

-- | Write the panel to CSV with a header row. σ̂² is the placeholder column,
-- joined by 09-05; estimation (09-07/09-09) reads this file.
writePanelCsv :: FilePath -> Panel -> IO ()
writePanelCsv fp panel =
  BL.writeFile fp (Csv.encodeDefaultOrderedByName (map toRow panel))
  where
    toRow o =
      PanelRow
        { prTokenId      = obsTokenId o
        , prEpoch        = obsEpoch o
        , prPremiumDelta = obsPremium o
        , prStrikeTick   = obsStrikeTick o
        , prPoolTick     = obsPoolTick o
        , prSigma2       = obsSigma2 o
        }
