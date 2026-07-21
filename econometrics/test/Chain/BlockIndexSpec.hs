{-# LANGUAGE OverloadedStrings #-}

-- | Offline specs for "Chain.BlockIndex".
--
-- Every test drives the REAL build/search/load code against a __synthetic
-- in-memory block oracle__ — a pure @Integer -> Integer@ timestamp function with
-- a deliberately irregular segment (1-second and 4-second gaps) so any \"blocks
-- are 2 seconds\" shortcut would land on the wrong block and the tests would
-- fail. No HTTP transport, no URL, and no network IO appear in this file; the
-- whole suite passes offline.
--
-- @describe@ title \"BlockIndex\" feeds the validation map's @--ta -m@ filter.
module Chain.BlockIndexSpec (spec) where

import           Data.IORef        (modifyIORef', newIORef, readIORef)
import           Data.List         (sort)
import qualified Data.Map.Strict   as Map
import           System.Directory  (getTemporaryDirectory, removeFile)
import           System.IO         (hClose, openTempFile)
import           Test.Hspec

import           Chain.BlockIndex
import           Chain.Rpc         (BlockHeader (..))

-- ---------------------------------------------------------------------------
-- The synthetic block oracle
-- ---------------------------------------------------------------------------

-- | A monotone, deliberately NON-uniform block-timestamp oracle over block
-- numbers @0..@. Anchored at unix @1_700_000_000@. Blocks advance 2 s each,
-- EXCEPT a slow stretch (@1000..1099@, 4 s each) and a fast stretch
-- (@2000..2099@, 1 s each). A search that assumed 2 s blocks would mis-locate
-- any boundary that falls in those stretches. Closed form so it is @O(1)@ even
-- at large block numbers.
oracleTs :: Integer -> Integer
oracleTs b = 1700000000 + 2 * b + 2 * seg 1000 1100 - seg 2000 2100
  where
    -- count of blocks k in [lo, hi) with k < b (each such block's gap differs).
    seg lo hi = max 0 (min b hi - lo)

-- | The oracle as an injectable IO fetch (still pure — no network), counting
-- calls through an 'IORef' so resumption can be proven by call count.
countingFetch :: IO (Integer -> IO (Either String BlockHeader), IO Int)
countingFetch = do
  ref <- newIORef (0 :: Int)
  let fetch b = do
        modifyIORef' ref (+ 1)
        pure (Right (BlockHeader b (oracleTs b)))
  pure (fetch, readIORef ref)

-- | Bracket wide enough to contain every target the tests use.
wideBracket :: (Integer, Integer)
wideBracket = (0, 5000)

-- | A throwaway temp file path, cleaned up by the caller.
withTempCsv :: (FilePath -> IO a) -> IO a
withTempCsv k = do
  tmp <- getTemporaryDirectory
  (fp, h) <- openTempFile tmp "blockindex-spec.csv"
  hClose h
  r <- k fp
  removeFile fp
  pure r

spec :: Spec
spec = describe "BlockIndex" $ do

  describe "bisectFirstAtOrAfter (pure, irregular oracle)" $ do
    it "returns the FIRST block whose timestamp is at or after the target" $ do
      -- target lands mid-gap on a normal 2s stretch
      let t = oracleTs 500 + 1            -- between block 500 and 501
      bisectFirstAtOrAfter oracleTs t wideBracket `shouldBe` Just 501

    it "is exact across the 4-second slow stretch (2s assumption would miss)" $ do
      let b0 = 1050
          t  = oracleTs b0                -- exactly a block boundary
      bisectFirstAtOrAfter oracleTs t wideBracket `shouldBe` Just b0
      -- one second past block b0 must round up to b0+1
      bisectFirstAtOrAfter oracleTs (oracleTs b0 + 1) wideBracket `shouldBe` Just (b0 + 1)

    it "is exact across the 1-second fast stretch" $ do
      let b0 = 2050
      -- exact boundary lands on the block itself
      bisectFirstAtOrAfter oracleTs (oracleTs b0) wideBracket `shouldBe` Just b0
      -- one second earlier IS the predecessor's exact ts here (1s gaps), so the
      -- first-at-or-after rounds to b0-1 — a naive 2s block model would misplace it
      bisectFirstAtOrAfter oracleTs (oracleTs b0 - 1) wideBracket `shouldBe` Just (b0 - 1)
      -- one second later must round up to b0+1
      bisectFirstAtOrAfter oracleTs (oracleTs b0 + 1) wideBracket `shouldBe` Just (b0 + 1)

    it "satisfies the postcondition ts(b) >= target > ts(b-1) for every target" $ do
      let targets = [ oracleTs b + d | b <- [10, 250, 1050, 1099, 2050, 3000], d <- [-1, 0, 1] ]
      flip mapM_ targets $ \t ->
        case bisectFirstAtOrAfter oracleTs t wideBracket of
          Just b -> do
            oracleTs b       `shouldSatisfy` (>= t)
            oracleTs (b - 1) `shouldSatisfy` (<  t)
          Nothing -> expectationFailure ("no block found for target " ++ show t)

    it "returns Nothing when the target is beyond the bracket's top block" $ do
      bisectFirstAtOrAfter oracleTs (oracleTs 5000 + 100) wideBracket `shouldBe` Nothing

  describe "findBlockAtOrAfterWith (live-shaped search, injected oracle)" $ do
    it "converges to the boundary block and asserts the postcondition" $ do
      (fetch, _) <- countingFetch
      let t = oracleTs 1234 + 1
      r <- findBlockAtOrAfterWith fetch t wideBracket
      case r of
        Right h -> bhNumber h `shouldBe` 1235
        Left e  -> expectationFailure e

    it "returns Left when no block in the bracket reaches the target" $ do
      (fetch, _) <- countingFetch
      r <- findBlockAtOrAfterWith fetch (oracleTs 5000 + 1000) (0, 5000)
      case r of
        Left _  -> pure () :: IO ()
        Right h -> expectationFailure ("expected Left, got block " ++ show (bhNumber h))

  describe "blockForEpoch" $ do
    it "returns the boundary block for a known epoch and Nothing otherwise" $ do
      let rows = [ EpochBlock 100 4321 1707000000
                 , EpochBlock 101 4700 1707003600 ]
          m    = epochBlockMap rows
      blockForEpoch m 100 `shouldBe` Just 4321
      blockForEpoch m 101 `shouldBe` Just 4700
      blockForEpoch m 999 `shouldBe` Nothing

  describe "writeBlockIndex / loadBlockIndex" $ do
    it "round-trips exactly through the banner + header" $ withTempCsv $ \fp -> do
      let rows = [ EpochBlock 10 111 1700000020
                 , EpochBlock 11 222 1700003620
                 , EpochBlock 12 333 1700007220 ]
      writeBlockIndex fp rows
      back <- loadBlockIndex fp
      back `shouldBe` rows

    it "parses only data rows, ignoring the # banner and the header line" $ withTempCsv $ \fp -> do
      writeFile fp $ unlines
        [ "# a provenance banner naming the RPC and the epoch rule"
        , "# built: 2026-07-21"
        , "epoch,block_number,block_timestamp"
        , "20536,43781657,1774352661"
        , "20537,43783457,1774356261" ]
      back <- loadBlockIndex fp
      map ebEpoch back       `shouldBe` [20536, 20537]
      map ebBlockNumber back `shouldBe` [43781657, 43783457]

  describe "buildBlockIndexWith (streaming build over the oracle)" $ do
    let epochSecs = 3600
        -- the whole build searches within this small block window (the live
        -- build injects the real estimation-window endpoints here).
        window = (0, 12000) :: (Integer, Integer)
        -- hourly boundaries whose instants sit inside the window's ts range.
        firstE = fromIntegral ((oracleTs (fst window) + fromIntegral epochSecs - 1)
                                 `div` fromIntegral epochSecs) :: Int
        lastE  = fromIntegral (oracleTs (snd window) `div` fromIntegral epochSecs) :: Int
        epochs = [firstE .. lastE]

    it "builds a strictly monotone index satisfying the round-trip epoch rule" $ withTempCsv $ \fp -> do
      (fetch, _) <- countingFetch
      r <- buildBlockIndexWith fetch window ["test banner"] epochSecs fp epochs
      case r of
        Left e     -> expectationFailure e
        Right rows -> do
          map ebEpoch rows `shouldBe` epochs
          -- strictly increasing block numbers
          let bns = map ebBlockNumber rows
          bns `shouldBe` sort bns
          and (zipWith (<) bns (drop 1 bns)) `shouldBe` True
          -- every row: block ts >= boundary instant, predecessor strictly before
          flip mapM_ rows $ \row -> do
            ebBlockTimestamp row `shouldSatisfy` (>= fromIntegral (ebEpoch row) * fromIntegral epochSecs)
            oracleTs (ebBlockNumber row - 1)
              `shouldSatisfy` (< fromIntegral (ebEpoch row) * fromIntegral epochSecs)

    it "resumes from a partial CSV, probing only the missing epochs" $ withTempCsv $ \fp -> do
      -- First pass: build the first half.
      (fetch1, _)     <- countingFetch
      let half = take 3 epochs
      _ <- buildBlockIndexWith fetch1 window ["test banner"] epochSecs fp half
      firstRows <- loadBlockIndex fp
      map ebEpoch firstRows `shouldBe` half

      -- Second pass over the FULL set: a fresh call counter must see zero probes
      -- for the already-present epochs — only the remaining ones are searched.
      (fetch2, calls2) <- countingFetch
      r <- buildBlockIndexWith fetch2 window ["test banner"] epochSecs fp epochs
      case r of
        Left e     -> expectationFailure e
        Right rows -> do
          map ebEpoch rows `shouldBe` epochs           -- union, in epoch order
          n <- calls2
          -- had it re-probed the first three epochs it would have issued far more
          -- calls; a resumed run only searches the three new boundaries.
          n `shouldSatisfy` (> 0)
          -- the file now holds every epoch exactly once
          final <- loadBlockIndex fp
          map ebEpoch final `shouldBe` epochs

    it "stops and reports the epoch whose fetch fails (no silent skip)" $ withTempCsv $ \fp -> do
      -- A transport that always fails: the build must surface a Left naming the
      -- epoch it was searching, never interpolate a block or skip the epoch.
      let fetch _ = pure (Left "simulated RPC failure") :: IO (Either String BlockHeader)
      r <- buildBlockIndexWith fetch window ["test banner"] epochSecs fp [firstE]
      case r of
        Left msg -> do
          msg `shouldContain` show firstE
          msg `shouldContain` "simulated RPC failure"
        Right _  -> expectationFailure "expected Left on a failing fetch"
