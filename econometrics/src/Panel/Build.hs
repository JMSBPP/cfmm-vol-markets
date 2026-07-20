{-# LANGUAGE OverloadedStrings #-}

-- | RED stub for the position-epoch panel assembler (plan 09-04, Task 2).
--
-- Signatures are fixed here so the fixture-driven test compiles; the bodies are
-- deliberately wrong/empty so the test FAILS (TDD red step). The real
-- implementation lands in the green step.
module Panel.Build
  ( Epoch
  , dailyEpoch
  , deltaPremia
  , strikeToTick
  , assemble
  , writePanelCsv
  ) where

import           Data.Time.Clock  (UTCTime)
import           Econ.Types       (Panel)
import           Panel.Subgraph   (RawPosition, Snapshot)

-- | Daily epoch index (UTC-midnight buckets).
type Epoch = Int

dailyEpoch :: UTCTime -> Int
dailyEpoch = const 0

deltaPremia :: [Snapshot] -> [(Epoch, Double)]
deltaPremia _ = []

strikeToTick :: Double -> Int
strikeToTick _ = 0

assemble :: [RawPosition] -> Panel
assemble _ = []

writePanelCsv :: FilePath -> Panel -> IO ()
writePanelCsv _ _ = pure ()
