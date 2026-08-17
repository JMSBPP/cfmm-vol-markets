-- | The epoch grid — the panel's single source of truth for bucketing an instant
-- into an integer epoch index, as a LEAF module.
--
-- == Why this module exists (plan 10-09)
--
-- The arithmetic here used to live in "Panel.Build". That placed it at the wrong
-- end of the dependency graph:
--
-- @
-- Panel.Build  <-  Chain.BlockIndex  <-  Panoptic.Chunk  <-  Panoptic.Premium
-- @
--
-- every one of those edges existing only to borrow 'Epoch' \/ 'epochOfSeconds'.
-- So when 10-09 came to assemble the position-epoch panel — which must consume
-- 'Panoptic.Premium.buildPremiumObs' output and 'Panoptic.Chunk.LegChunk' inputs
-- inside "Panel.Build" — the import closed a CYCLE and would not compile.
--
-- The fix is to move the grid into a leaf that everything can depend on, rather
-- than to fork a second definition of the epoch index. __Forking is the failure
-- mode this module exists to prevent__: plan 09-05 paid for a second day-index
-- definition with the 40587-offset trap, where the panel and the variance series
-- silently bucketed onto different grids and the join produced rows that looked
-- fine and were wrong.
--
-- 'Panel.Build.dailyEpoch' is deliberately NOT moved. It stays where Phase 9 put
-- it, byte-identical, and remains THE daily index; @epochOfSeconds 86400@ is
-- required to agree with it pointwise and "Panel.BuildSpec" asserts that. Every
-- consumer keeps importing whichever module it already imported — "Panel.Build"
-- re-exports the three names below unchanged.
module Panel.Epoch
  ( Epoch
  , epochOfSeconds
  , hourlyEpoch
  , epochSecondsHourly
  , epochSecondsDaily
  ) where

import Data.Time.Clock       (UTCTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)

-- | An epoch index: whole buckets of some fixed width since the Unix epoch. The
-- WIDTH is not part of the type — it is a property of the artifact, recorded in
-- that artifact's banner. Phase 9 is daily (86400); Phase 10 is hourly (3600)
-- after the 10-01 re-scope.
type Epoch = Int

-- | Bucket a UTC instant into an epoch of arbitrary width, @epochSeconds@ wide,
-- anchored at the Unix epoch: @floor(unixSeconds \/ epochSeconds)@.
--
-- This GENERALIZES 'Panel.Build.dailyEpoch' — it does not replace it.
-- @epochOfSeconds 86400@ is required to agree with 'Panel.Build.dailyEpoch'
-- pointwise, and "Panel.BuildSpec" asserts that agreement so the two can never
-- drift.
--
-- Introduced by plan 10-01 for the HOURLY re-scope of the Wave-0 census: the
-- daily design was closed by its own pre-committed rule (the median accrual spell
-- is 0.25 days and cannot vary within a daily bucket), and re-measuring at a
-- finer resolution requires the bucket width to be a parameter rather than a
-- constant.
epochOfSeconds :: Int -> UTCTime -> Epoch
epochOfSeconds epochSeconds t =
  floor (realToFrac (utcTimeToPOSIXSeconds t) / (fromIntegral epochSeconds :: Double))

-- | Hourly epoch index: whole hours since the Unix epoch. @epochOfSeconds 3600@.
-- THE grid of the Phase-10 panel (10-01 re-scope).
hourlyEpoch :: UTCTime -> Epoch
hourlyEpoch = epochOfSeconds epochSecondsHourly

-- | 3600 — the Phase-10 epoch width in seconds, as a named constant so the
-- panel, the variance series and the block index quote ONE symbol rather than
-- three literals.
epochSecondsHourly :: Int
epochSecondsHourly = 3600

-- | 86400 — the Phase-9 daily epoch width in seconds.
epochSecondsDaily :: Int
epochSecondsDaily = 86400
