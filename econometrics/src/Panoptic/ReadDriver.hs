{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The bulk accumulator read: drive @SFPM.getAccountPremium@ /
-- @getAccountLiquidity@ over a deduplicated read schedule, __checkpointing every
-- row to disk as it arrives__ so an interrupted multi-hour run resumes instead of
-- restarting.
--
-- == The one design requirement (RESEARCH \"Architecture Patterns\")
--
-- A run that only writes at the end is a run you do twice. Phase 9 learned this on
-- the 3-hour swap-log pull; @Panel.Variance.fetchSwapTicks@ streams each chunk to
-- disk as it arrives, and this driver reuses that discipline: 'appendAccumulatorRow'
-- flushes each row the instant its @(premium, liquidity)@ pair is read, and a
-- re-run 'loadAccumulators' + 'pendingRows' skips every key already present.
-- Resumption is the DEFAULT path, not a flag.
--
-- == The second requirement: fail loud, never a zero (RESEARCH Pitfall, Phase 9)
--
-- A public archive endpoint that degrades to \"state not available\" and returns
-- @0x@ must ABORT the run, not decode to zero. 'Chain.Rpc.ethCall' already turns
-- @0x@ into a 'Left'; this driver propagates that 'Left' — after one failover
-- retry on the secondary endpoint — as a fatal, key-naming abort. It NEVER writes
-- a zero in place of a missing value: a hole in the accumulator series becomes a
-- silent wrong premium, which is precisely the class of failure the reconciliation
-- gate cannot catch.
--
-- == Liquidity beside every premium (RESEARCH Pitfall 5)
--
-- @getAccountPremium@ silently returns the STORED accumulator when a chunk's
-- @netLiquidity == 0@, making a flat stretch ambiguous between \"chunk empty\" and
-- \"no fees\". Every row therefore records 'getAccountLiquidity' alongside the
-- premium; 'rsFlagged' counts the @ChunkEmpty@ (net == 0) and @AccFrozen@
-- (capped accumulator) rows so 10-07/10-08 can stratify the gate's error
-- distribution on them.
module Panoptic.ReadDriver
  ( -- * The CSV record
    AccRow (..)
  , AccKey
  , accRowKey
    -- * Cache IO
  , loadAccumulators
  , appendAccumulatorRow
  , accBanner
  , accHeader
    -- * Scheduling
  , pendingRows
  , readRowKey
    -- * The bulk run
  , RowReader
  , liveRowReader
  , runReadSchedule
  , runReadScheduleWith
  , ReadStats (..)
  ) where

import           Data.List       (foldl', intercalate, isPrefixOf)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Maybe      (mapMaybe)
import           Data.Text       (Text)
import qualified Data.Text       as T
import           Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)
import           Data.Time.Format (defaultTimeLocale, formatTime)
import           System.Directory (doesFileExist)
import           System.IO       (hFlush, hPutStrLn, readFile', stderr, stdout)
import           Text.Read       (readMaybe)

import           Chain.Rpc       (BlockTag (..), RpcEnv (..))
import           Panoptic.Chunk  (ChunkKey (..), ReadRow (..), storedValueTick)
import           Panoptic.Premium (isFrozenAcc)
import           Panoptic.Sfpm   (getAccountLiquidity, getAccountPremium,
                                  sfpmAddress, vegoidConst)

-- ---------------------------------------------------------------------------
-- The CSV record
-- ---------------------------------------------------------------------------

-- | One materialised accumulator reading: the pool-wide chunk identity, the block
-- and side it was read at, the extrapolation tick, the X64 accumulators for both
-- currencies, and the chunk liquidity levels that disambiguate an empty chunk.
data AccRow = AccRow
  { acTokenType   :: !Int
  , acTickLower   :: !Int
  , acTickUpper   :: !Int
  , acBlock       :: !Integer
  , acIsLong      :: !Bool
  , acAtTick      :: !Int
  , acAcc0        :: !Integer        -- ^ currency0 (ETH) X64 accumulator.
  , acAcc1        :: !Integer        -- ^ currency1 (USDC) X64 accumulator.
  , acNetLiq      :: !Integer
  , acRemovedLiq  :: !Integer
  , acEpoch       :: !Integer
  , acEndpoint    :: !(Maybe Text)   -- ^ @Just "mint"|"burn"@ endpoint read, else @Nothing@.
  }
  deriving (Show, Eq)

-- | The dedup key: @(tokenType, tickLower, tickUpper, block, isLong, atTick)@ —
-- the pool-wide read identity. Two positions in the same chunk at the same block
-- and side share ONE reading (RESEARCH \"Chunk identity\").
type AccKey = (Int, Int, Int, Integer, Bool, Int)

-- | The key of a materialised row.
accRowKey :: AccRow -> AccKey
accRowKey r =
  (acTokenType r, acTickLower r, acTickUpper r, acBlock r, acIsLong r, acAtTick r)

-- | The key of a scheduled read — identical shape to 'accRowKey', so a schedule
-- row and its written result collide exactly.
readRowKey :: ReadRow -> AccKey
readRowKey r =
  let ck = rrChunkKey r
  in (ckTokenType ck, ckTickLower ck, ckTickUpper ck, rrBlock r, rrIsLong r, rrAtTick r)

-- ---------------------------------------------------------------------------
-- Cache IO
-- ---------------------------------------------------------------------------

-- | The CSV column header (also the string 'loadAccumulators' recognises and
-- skips).
accHeader :: String
accHeader =
  "token_type,tick_lower,tick_upper,block,is_long,at_tick,acc0_x64,acc1_x64,\
  \net_liquidity,removed_liquidity,epoch,endpoint"

-- | The @#@ provenance banner written at the head of a fresh cache. Records the
-- lineage that fixes the reading: build date, RPC endpoints, SFPM address,
-- vegoid, schedule size, and block range. Call count and wall time are NOT here —
-- they are unknown until the run ends and belong to the SUMMARY.
accBanner :: String -> RpcEnv -> RpcEnv -> Int -> (Integer, Integer) -> String
accBanner date primaryEnv failoverEnv scheduleSize (loBlk, hiBlk) = unlines
  [ "# premium-accumulators.csv — SFPM getAccountPremium X64 accumulators, one row per scheduled read"
  , "# built: " ++ date
      ++ "   RPC: " ++ T.unpack (reUrl primaryEnv)
      ++ " (failover " ++ T.unpack (reUrl failoverEnv) ++ ")"
  , "# SFPM: " ++ T.unpack sfpmAddress ++ "   vegoid: " ++ show vegoidConst
  , "# schedule rows: " ++ show scheduleSize
      ++ "   block range: " ++ show loBlk ++ ".." ++ show hiBlk
  , "# accumulators and liquidity are DECIMAL Integer strings (they exceed 2^63; a Double round-trip would lose precision)"
  , "# columns: " ++ accHeader
  ]

-- | Load the accumulator cache into a 'Map' keyed by 'accRowKey'. Lines beginning
-- with @#@ (the banner) and the single header line are skipped; malformed lines
-- are dropped (they cannot be a valid checkpoint). A missing file is an empty map
-- — the base case of a fresh run.
loadAccumulators :: FilePath -> IO (Map AccKey AccRow)
loadAccumulators path = do
  exists <- doesFileExist path
  if not exists
    then pure Map.empty
    else do
      contents <- readFile' path
      let rows = mapMaybe parseAccRow (lines contents)
      pure (Map.fromList [ (accRowKey r, r) | r <- rows ])

-- | Parse one data line into an 'AccRow'. Returns 'Nothing' for the banner, the
-- header, blank lines, and anything that does not have exactly the twelve
-- expected fields.
parseAccRow :: String -> Maybe AccRow
parseAccRow line
  | null line                        = Nothing
  | "#" `isPrefixOf` line             = Nothing
  | "token_type" `isPrefixOf` line    = Nothing
  | otherwise = case splitComma line of
      [tt, tl, tu, bk, il, at, a0, a1, nl, rl, ep, endp] ->
        AccRow
          <$> readMaybe tt
          <*> readMaybe tl
          <*> readMaybe tu
          <*> readMaybe bk
          <*> parseBool il
          <*> readMaybe at
          <*> readMaybe a0
          <*> readMaybe a1
          <*> readMaybe nl
          <*> readMaybe rl
          <*> readMaybe ep
          <*> Just (parseEndpoint endp)
      _ -> Nothing
  where
    parseBool "0" = Just False
    parseBool "1" = Just True
    parseBool _   = Nothing
    parseEndpoint "" = Nothing
    parseEndpoint s  = Just (T.pack s)

-- | Split a line on commas (no quoting — every field here is a decimal integer or
-- a short ASCII tag).
splitComma :: String -> [String]
splitComma s = case break (== ',') s of
  (h, [])       -> [h]
  (h, _ : rest) -> h : splitComma rest

-- | Render one 'AccRow' as a CSV data line. Accumulators and liquidity are
-- 'show'n as DECIMAL 'Integer' strings — never floats, so a value above @2^63@
-- round-trips exactly.
renderAccRow :: AccRow -> String
renderAccRow r = intercalate ","
  [ show (acTokenType r), show (acTickLower r), show (acTickUpper r)
  , show (acBlock r), if acIsLong r then "1" else "0", show (acAtTick r)
  , show (acAcc0 r), show (acAcc1 r), show (acNetLiq r), show (acRemovedLiq r)
  , show (acEpoch r), maybe "" T.unpack (acEndpoint r)
  ]

-- | Append one row to the cache and FLUSH — durability per row, never relying on
-- process-exit buffering (@appendFile@ opens, writes, and closes, so the bytes
-- reach the OS immediately).
appendAccumulatorRow :: FilePath -> AccRow -> IO ()
appendAccumulatorRow path r = appendFile path (renderAccRow r ++ "\n")

-- ---------------------------------------------------------------------------
-- Scheduling
-- ---------------------------------------------------------------------------

-- | The schedule rows NOT already present in the loaded cache — the work a run
-- actually has to do. A fully populated cache yields @[]@, so a re-run costs zero
-- calls.
pendingRows :: Map AccKey AccRow -> [ReadRow] -> [ReadRow]
pendingRows done = filter (\r -> readRowKey r `Map.notMember` done)

-- ---------------------------------------------------------------------------
-- The bulk run
-- ---------------------------------------------------------------------------

-- | A per-row read: given an endpoint and a scheduled row, return
-- @(acc0, acc1, netLiquidity, removedLiquidity)@ or a 'Left' error. Factored out
-- so the spec can inject a deterministic in-memory reader (no network); the
-- production reader is 'liveRowReader'.
type RowReader = RpcEnv -> ReadRow -> IO (Either String (Integer, Integer, Integer, Integer))

-- | The live reader: 'getAccountPremium' at the row's block and tick, then
-- 'getAccountLiquidity' at the same block. The @atTick@ sentinel
-- 'storedValueTick' encodes as @Nothing@ (stored value); any other tick is a live
-- extrapolation. If EITHER call is a 'Left', the row is a 'Left' — never a
-- partial write.
liveRowReader :: RowReader
liveRowReader env row = do
  let ck     = rrChunkKey row
      atTick = if rrAtTick row == storedValueTick then Nothing else Just (rrAtTick row)
      tag    = BlockNumber (rrBlock row)
  ep <- getAccountPremium env ck atTick (rrIsLong row) tag
  case ep of
    Left e             -> pure (Left ("getAccountPremium: " ++ e))
    Right (acc0, acc1) -> do
      el <- getAccountLiquidity env ck tag
      pure $ case el of
        Left e               -> Left ("getAccountLiquidity: " ++ e)
        Right (removed, net) -> Right (acc0, acc1, net, removed)

-- | Run statistics, all recorded into the SUMMARY's @## Bulk Read@ section.
data ReadStats = ReadStats
  { rsCalls         :: !Int          -- ^ rows actually read this run (each = one premium + one liquidity call).
  , rsSkipped       :: !Int          -- ^ rows skipped because already checkpointed (resumption).
  , rsElapsedS      :: !Double       -- ^ wall time, seconds.
  , rsFailoverCalls :: !Int          -- ^ rows that required the failover endpoint after the primary failed.
  , rsFlagged       :: !(Int, Int)   -- ^ (ChunkEmpty rows: net == 0, AccFrozen rows: capped accumulator).
  }
  deriving (Show, Eq)

-- | Drive the schedule with the live reader — the production entry point. See
-- 'runReadScheduleWith'.
runReadSchedule :: RpcEnv -> RpcEnv -> FilePath -> [ReadRow] -> IO (Either String ReadStats)
runReadSchedule = runReadScheduleWith liveRowReader

-- | Drive @schedule@ against @primaryEnv@ (failing over to @failoverEnv@ once per
-- row), checkpointing each successful @(premium, liquidity)@ to @csvPath@.
--
--   * __Resumption is the default:__ 'loadAccumulators' + 'pendingRows' skip every
--     already-read key. A fresh file gets the 'accBanner' + 'accHeader'; an
--     existing one is appended to (never truncated).
--   * __Fail loud:__ on a 'Left' from the primary, the row is retried once on the
--     failover; if that also fails the run STOPS and returns a 'Left' naming the
--     exact key. No zero row is ever written.
--   * __Incremental:__ each row is 'appendAccumulatorRow'd the instant it is read,
--     so an interrupted run leaves N valid rows on disk.
--   * Progress is logged to stderr every 100 rows.
runReadScheduleWith
  :: RowReader -> RpcEnv -> RpcEnv -> FilePath -> [ReadRow]
  -> IO (Either String ReadStats)
runReadScheduleWith reader primaryEnv failoverEnv csvPath schedule = do
  done <- loadAccumulators csvPath
  let pend    = dedupOnKey (pendingRows done schedule)
      total   = length pend
      skipped = length schedule - total

  -- Fresh file: write the provenance banner + header once. Existing file: leave
  -- it alone (rewriting would truncate the checkpointed rows).
  exists <- doesFileExist csvPath
  now0 <- getCurrentTime
  let date  = formatTime defaultTimeLocale "%Y-%m-%d" now0
      blks  = map rrBlock schedule
      range = if null blks then (0, 0) else (minimum blks, maximum blks)
  if not exists
    then writeFile csvPath (accBanner date primaryEnv failoverEnv (length schedule) range ++ accHeader ++ "\n")
    else pure ()

  hPutStrLn stderr ("read-premia: " ++ show total ++ " rows to read, "
                     ++ show skipped ++ " already cached (resumed)")
  start <- getCurrentTime
  let go !_ !calls !fo !empty !frozen [] = do
        elapsed <- elapsedSince start
        pure (Right (ReadStats calls skipped elapsed fo (empty, frozen)))
      go !i !calls !fo !empty !frozen (row : rest) = do
        progress i total calls start
        r1 <- reader primaryEnv row
        outcome <- case r1 of
          Right v  -> pure (Right (v, False))
          Left e1  -> do
            hPutStrLn stderr ("  [failover] key " ++ show (readRowKey row)
                               ++ " primary failed: " ++ take 160 e1)
            r2 <- reader failoverEnv row
            case r2 of
              Right v -> pure (Right (v, True))
              Left e2 -> pure (Left (abortMsg row e1 e2))
        case outcome of
          Left err -> do
            hPutStrLn stderr ("read-premia: ABORT — " ++ err)
            pure (Left err)
          Right ((acc0, acc1, net, removed), usedFailover) -> do
            appendAccumulatorRow csvPath (mkAccRow row acc0 acc1 net removed)
            let empty'  = empty  + if net == 0 then 1 else 0
                frozen' = frozen + if isFrozenAcc acc0 || isFrozenAcc acc1 then 1 else 0
                fo'     = fo     + if usedFailover then 1 else 0
            go (i + 1) (calls + 1) fo' empty' frozen' rest
  go (0 :: Int) (0 :: Int) (0 :: Int) (0 :: Int) (0 :: Int) pend

-- | Build the durable row from the schedule row and the read values.
mkAccRow :: ReadRow -> Integer -> Integer -> Integer -> Integer -> AccRow
mkAccRow row acc0 acc1 net removed =
  let ck = rrChunkKey row
  in AccRow
       { acTokenType  = ckTokenType ck
       , acTickLower  = ckTickLower ck
       , acTickUpper  = ckTickUpper ck
       , acBlock      = rrBlock row
       , acIsLong     = rrIsLong row
       , acAtTick     = rrAtTick row
       , acAcc0       = acc0
       , acAcc1       = acc1
       , acNetLiq     = net
       , acRemovedLiq = removed
       , acEpoch      = rrEpoch row
       , acEndpoint   = rrEndpoint row
       }

-- | The fatal abort message, naming the exact offending key and both endpoints'
-- errors. A hole in the accumulator series is a silent wrong premium, so the run
-- stops here rather than continuing.
abortMsg :: ReadRow -> String -> String -> String
abortMsg row e1 e2 =
  "read failed at key " ++ show (readRowKey row)
    ++ " (block " ++ show (rrBlock row) ++ ", tokenId " ++ T.unpack (rrTokenId row) ++ "): "
    ++ "primary: " ++ take 200 e1 ++ " | failover: " ++ take 200 e2

-- | stderr progress every 100 rows: @[read n/m] calls=… elapsed=…s rate=…/s@.
progress :: Int -> Int -> Int -> UTCTime -> IO ()
progress i total calls start
  | i > 0 && i `mod` 100 == 0 = do
      elapsed <- elapsedSince start
      let rate = if elapsed > 0 then fromIntegral calls / elapsed else 0 :: Double
      hPutStrLn stderr ("  [read " ++ show i ++ "/" ++ show total
                         ++ "] calls=" ++ show calls
                         ++ " elapsed=" ++ showS elapsed ++ "s"
                         ++ " rate=" ++ showS rate ++ "/s")
      hFlush stdout
  | otherwise = pure ()
  where
    showS x = show (fromIntegral (round (x * 100) :: Integer) / 100 :: Double)

-- | Seconds elapsed since a start time.
elapsedSince :: UTCTime -> IO Double
elapsedSince start = do
  end <- getCurrentTime
  pure (realToFrac (diffUTCTime end start))

-- | Keep the first row for each key, preserving order — guards against a schedule
-- that (through 'readScheduleRaw' fan-out) lists the same pool-wide read twice.
dedupOnKey :: [ReadRow] -> [ReadRow]
dedupOnKey = go Map.empty
  where
    go _ [] = []
    go seen (x : xs)
      | k `Map.member` seen = go seen xs
      | otherwise           = x : go (Map.insert k () seen) xs
      where k = readRowKey x
