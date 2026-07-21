{-# LANGUAGE OverloadedStrings #-}

-- | Offline spec for 'Panoptic.ReadDriver': the checkpointed, resumable,
-- fail-loud bulk read. Every case runs against a temp CSV and an INJECTED,
-- in-memory row reader — no network, no URL literals. The reader is the
-- 'RowReader' seam ('runReadScheduleWith'): a deterministic function of the
-- 'ReadRow', including one that returns 'Left' on a chosen key.
module Panoptic.ReadDriverSpec (spec) where

import qualified Data.Map.Strict   as Map
import           System.Directory  (doesFileExist, getTemporaryDirectory,
                                    removeFile)
import           System.IO         (hClose, openTempFile)
import           Test.Hspec

import           Chain.Rpc         (defaultBaseEnv, drpcFailoverEnv)
import           Panoptic.Chunk    (ChunkKey (..), ReadRow (..), storedValueTick)
import           Panoptic.ReadDriver

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- | A scheduled read for a chunk at a block/side, with a distinct tokenId so the
-- key is exercised across all six components.
mkRow :: Int -> Int -> Int -> Integer -> Bool -> Int -> ReadRow
mkRow tt tl tu blk isLong atTick = ReadRow
  { rrTokenId  = "tok"
  , rrLegIndex = 0
  , rrChunkKey = ChunkKey tt tl tu
  , rrIsLong   = isLong
  , rrEpoch    = blk        -- epoch value is irrelevant to the key; reuse the block
  , rrBlock    = blk
  , rrAtTick   = atTick
  , rrEndpoint = Nothing
  }

-- | A three-row schedule over one chunk at three blocks.
schedule3 :: [ReadRow]
schedule3 =
  [ mkRow 1 (-201120) (-198720) 44500000 False storedValueTick
  , mkRow 1 (-201120) (-198720) 44600000 False storedValueTick
  , mkRow 1 (-201120) (-198720) 44700000 False storedValueTick
  ]

-- | An accumulator ABOVE @2^63@ — the value 'Int' cannot hold, proving the CSV
-- keeps @Integer@ precision.
bigAcc :: Integer
bigAcc = 2 ^ (100 :: Int) + 123456789

-- | An in-memory reader keyed on the block: returns @(acc0, acc1, net, removed)@
-- deterministically, with @acc0@ scaled past @2^63@ so precision is under test.
memReader :: RowReader
memReader _ row =
  let b   = rrBlock row
      a0  = bigAcc + b
      a1  = 42 + b
      net = 1000 + b
      rem' = 7
  in pure (Right (a0, a1, net, rem'))

-- | A reader that succeeds except on a chosen block, where it fails on BOTH the
-- primary and the failover (the same function is used for both envs), forcing an
-- abort.
failingReaderAt :: Integer -> RowReader
failingReaderAt badBlock env row
  | rrBlock row == badBlock = pure (Left "state not available (0x)")
  | otherwise               = memReader env row

-- | Run against a fresh temp CSV, returning the path so the caller can inspect it.
withTempCsv :: (FilePath -> IO a) -> IO a
withTempCsv act = do
  dir <- getTemporaryDirectory
  (path, h) <- openTempFile dir "premium-accumulators-test.csv"
  hClose h
  removeFile path            -- start from a genuinely fresh (absent) file
  act path

-- | Count data rows (non-@#@, non-header, non-blank) in a CSV file.
dataRowCount :: FilePath -> IO Int
dataRowCount path = do
  exists <- doesFileExist path
  if not exists then pure 0 else do
    ls <- fmap lines (readFile path)
    pure (length (filter isData ls))
  where
    isData l = not (null l)
                 && take 1 l /= "#"
                 && take 10 l /= "token_type"

-- ---------------------------------------------------------------------------
-- Spec
-- ---------------------------------------------------------------------------

spec :: Spec
spec = describe "ReadDriver" $ do

  describe "loadAccumulators / appendAccumulatorRow round-trip" $ do
    it "round-trips a row exactly, including an Integer accumulator above 2^63" $
      withTempCsv $ \path -> do
        let row = AccRow
              { acTokenType = 1, acTickLower = -201120, acTickUpper = -198720
              , acBlock = 44500000, acIsLong = True, acAtTick = storedValueTick
              , acAcc0 = bigAcc, acAcc1 = 999, acNetLiq = 12345, acRemovedLiq = 6
              , acEpoch = 12000, acEndpoint = Just "mint"
              }
        appendAccumulatorRow path row
        m <- loadAccumulators path
        Map.lookup (accRowKey row) m `shouldBe` Just row
        -- the big accumulator survived as an exact Integer (no Int overflow)
        fmap acAcc0 (Map.lookup (accRowKey row) m) `shouldBe` Just bigAcc

    it "skips a '#' banner and the header line" $
      withTempCsv $ \path -> do
        let row = AccRow 2 10 20 44000000 False storedValueTick 5 6 7 8 100 Nothing
        writeFile path ("# a banner line\n" ++ accHeader ++ "\n")
        appendAccumulatorRow path row
        m <- loadAccumulators path
        Map.size m `shouldBe` 1
        Map.member (accRowKey row) m `shouldBe` True

    it "an absent file loads as the empty map (a fresh run)" $
      withTempCsv $ \path -> do
        removeFileIfExists path
        m <- loadAccumulators path
        Map.size m `shouldBe` 0

  describe "pendingRows" $ do
    it "returns exactly the rows NOT already in the map" $ do
      -- pre-load the middle row's key
      let mid = schedule3 !! 1
          done = Map.fromList
            [ (readRowKey mid
              , AccRow 1 (-201120) (-198720) 44600000 False storedValueTick 0 0 1 0 0 Nothing) ]
          pend = pendingRows done schedule3
      map rrBlock pend `shouldBe` [44500000, 44700000]

    it "returns [] when the map already covers the whole schedule (a re-run skips everything)" $ do
      let doneMap = Map.fromList
            [ (readRowKey r, AccRow 1 (-201120) (-198720) (rrBlock r) False storedValueTick 0 0 1 0 0 Nothing)
            | r <- schedule3 ]
      pendingRows doneMap schedule3 `shouldBe` []

  describe "runReadScheduleWith — checkpointing and resumption" $ do
    it "writes each row as it arrives and reports the full call count" $
      withTempCsv $ \path -> do
        res <- runReadScheduleWith memReader defaultBaseEnv drpcFailoverEnv path schedule3
        case res of
          Left err -> expectationFailure ("unexpected abort: " ++ err)
          Right st -> do
            rsCalls st   `shouldBe` 3
            rsSkipped st `shouldBe` 0
        n <- dataRowCount path
        n `shouldBe` 3

    it "resumes: a second run over the same schedule makes ZERO calls and skips every row" $
      withTempCsv $ \path -> do
        _   <- runReadScheduleWith memReader defaultBaseEnv drpcFailoverEnv path schedule3
        res <- runReadScheduleWith memReader defaultBaseEnv drpcFailoverEnv path schedule3
        case res of
          Left err -> expectationFailure ("unexpected abort on resume: " ++ err)
          Right st -> do
            rsCalls st   `shouldBe` 0
            rsSkipped st `shouldBe` 3
        n <- dataRowCount path       -- still exactly the original three rows
        n `shouldBe` 3

    it "records chunk liquidity alongside every premium (net read back exactly)" $
      withTempCsv $ \path -> do
        _ <- runReadScheduleWith memReader defaultBaseEnv drpcFailoverEnv path schedule3
        m <- loadAccumulators path
        let k = readRowKey (head schedule3)
        fmap acNetLiq (Map.lookup k m) `shouldBe` Just (1000 + 44500000)

  describe "runReadScheduleWith — fail loud" $ do
    it "a failing read aborts with the offending key and writes NO row for it" $
      withTempCsv $ \path -> do
        -- fail on the 2nd of 3 rows: row 1 is written, then the run stops.
        res <- runReadScheduleWith (failingReaderAt 44600000)
                                   defaultBaseEnv drpcFailoverEnv path schedule3
        case res of
          Right _  -> expectationFailure "expected a Left abort, got success"
          Left err -> do
            -- the message names the offending key (its block appears in the key tuple)
            ("44600000" `isInfixOfStr` err) `shouldBe` True
        n <- dataRowCount path
        n `shouldBe` 1     -- only the first row was checkpointed; the failing row wrote nothing

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

removeFileIfExists :: FilePath -> IO ()
removeFileIfExists path = do
  exists <- doesFileExist path
  if exists then removeFile path else pure ()

isInfixOfStr :: String -> String -> Bool
isInfixOfStr needle hay = any (prefix needle) (tails' hay)
  where
    prefix [] _ = True
    prefix _ [] = False
    prefix (x : xs) (y : ys) = x == y && prefix xs ys
    tails' [] = [[]]
    tails' s@(_ : rest) = s : tails' rest
