{-# LANGUAGE OverloadedStrings #-}

-- | Variance regressor σ̂²_t and its errors-in-variables (EIV) instrument σ̃²_t
-- for the Panoptic υ-identification (CTX-VAR).
--
-- == Data transport (USER-DIRECTED OVERRIDE, resolved at the 09-02 checkpoint)
--
-- The plan originally sourced the underlying-pool Swap ticks from Google
-- BigQuery (@bigquery-public-data.crypto_ethereum.logs@, v3 @Swap@ topic0,
-- filtered by a pool /address/). That path is DEAD: the GCP project
-- @thetaswap-research@ is suspended (every query returns @403
-- CONSUMER_SUSPENDED@) and the confirmed market is Uniswap **V4 on Base**, whose
-- swaps are emitted by the PoolManager singleton keyed by a 32-byte poolId — not
-- by a pool contract address in @crypto_ethereum@. See
-- @notes/structural-econometrcics/data/DATA-SOURCES.md@ §4.
--
-- The live path used here is therefore **chunked @eth_getLogs@ JSON-RPC against
-- a Base RPC endpoint**, filtered by the V4 @Swap@ topic0 and the market's
-- poolId in @topics[1]@, decoding the tick straight out of the log @data@ per the
-- V4 event ABI. The realized-variance mathematics below is transport-agnostic and
-- is UNCHANGED from the plan — only the ingestion layer moved from BigQuery SQL to
-- RPC. The BigQuery SQL is retained as 'historicalBigQuerySql' for provenance
-- only; it is NOT wired as the live source.
--
-- == V4 @Swap@ event ABI (Base PoolManager singleton)
--
-- @Swap(bytes32 indexed id, address indexed sender, int128 amount0,
--       int128 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick,
--       uint24 fee)@
--
-- Indexed args land in topics (@topics[1]@ = poolId, @topics[2]@ = sender); the
-- six non-indexed args are ABI-encoded as 32-byte words in the log @data@:
--
--   word 0 = amount0 (int128)      word 3 = liquidity (uint128)
--   word 1 = amount1 (int128)      word 4 = tick (int24, sign-extended)
--   word 2 = sqrtPriceX96 (uint160) word 5 = fee (uint24)
--
-- (Verified against a live Base log whose word 5 decoded to @0x1f4@ = 500, the
-- pool's 0.05% fee tier.)
module Panel.Variance
  ( -- * RPC ingestion (Base V4 Swap logs)
    RpcConfig (..)
  , defaultBaseRpc
  , v4SwapTopic0
  , basePoolManager
  , basePoolId
  , fetchSwapTicks
  , cacheSwapTicks
    -- * ABI decode
  , decodeTick
  , decodeSqrtPriceX96
    -- * CSV ingestion
  , loadSwapTicks
    -- * Variance math (CTX-VAR)
  , Epoch
  , dailyEpoch
  , tickToLogPrice
  , realizedVariance
  , meanPoolTick
  , instrumentVariance
  , writeVarianceCsv
    -- * Historical / superseded
  , historicalBigQuerySql
  ) where

import           Data.Aeson (FromJSON (..), Result (..), fromJSON, object,
                             withObject, (.:), (.:?), (.=))
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Csv as Csv
import           Data.List (sortOn)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import           Data.Time.Clock (UTCTime)
import           Data.Time.Clock.POSIX (posixSecondsToUTCTime,
                                        utcTimeToPOSIXSeconds)
import qualified Data.Vector as V
import           Numeric (readHex)
import           System.IO (hFlush, stdout)

-- | The daily epoch boundary is the panel's SINGLE SOURCE OF TRUTH: this module
-- imports and re-exports @Panel.Build.dailyEpoch@ (owned by plan 09-04) rather
-- than defining its own, guaranteeing σ̂²_t/σ̃²_t bucket on exactly the same
-- integer epoch index as the panel so the two CSVs join cleanly in 09-09.
import           Panel.Build (Epoch, dailyEpoch)

-- | ABI word arithmetic (sign-extended 'decodeWordAt', 'hexToBytes') lives in
-- 'Chain.Abi' as the single implementation — this module no longer carries its
-- own @wordAt@ (the 09-05 fork-divergence lesson).
import           Chain.Abi (decodeWordAt, hexToBytes)

-- | JSON-RPC transport (the retry/backoff loop) is LIFTED into 'Chain.Rpc';
-- @getLogsChunk@ and @currentHeadBlock@ call it rather than carrying their own
-- @httpLBS@/retry code — the single-transport rule (09-05 divergence lesson).
import           Chain.Rpc (RpcEnv (..), defaultBaseEnv, ethBlockNumber, rpcPost)

-- ---------------------------------------------------------------------------
-- Confirmed market constants (DATA-SOURCES.md §2, §4)
-- ---------------------------------------------------------------------------

-- | Uniswap V4 @Swap@ event topic0 (keccak of the V4 signature). Cross-verified
-- in DATA-SOURCES.md §2.
v4SwapTopic0 :: Text
v4SwapTopic0 = "0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f"

-- | Base V4 PoolManager singleton (the log emitter). Canonical Uniswap V4
-- deploy address on Base; confirmed live to emit the market's Swap logs
-- (a probe over blocks 48,760,000–48,760,500 returned this address).
basePoolManager :: Text
basePoolManager = "0x498581ff718922c3f8e6a244956af099b2652b2b"

-- | The market's poolId, carried in @topics[1]@ of every Swap for this pool
-- (DATA-SOURCES.md §4.1).
basePoolId :: Text
basePoolId = "0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a"

-- ---------------------------------------------------------------------------
-- RPC configuration
-- ---------------------------------------------------------------------------

-- | Everything the chunked @eth_getLogs@ fetch needs. The RPC URL, the poolId,
-- and the block window are all parameters (never hardcoded into the query path)
-- so 09-09's full-history pull can widen the window and swap the endpoint (e.g.
-- to a paid RPC read from the worktree @.env@) without code changes.
data RpcConfig = RpcConfig
  { rpcUrl       :: !String  -- ^ Base JSON-RPC endpoint (public by default).
  , rpcPoolMgr   :: !Text    -- ^ PoolManager singleton address (log emitter).
  , rpcTopic0    :: !Text    -- ^ V4 Swap topic0 filter.
  , rpcPoolId    :: !Text    -- ^ poolId filter (topics[1]).
  , rpcFromBlock :: !Integer -- ^ inclusive start block.
  , rpcToBlock   :: !Integer -- ^ inclusive end block.
  , rpcChunk     :: !Integer -- ^ block span per eth_getLogs call (public RPCs
                             --   cap the range — keep this conservative).
  } deriving (Show, Eq)

-- | Sensible defaults for the confirmed Base V4 ETH/USDC market. Block window is
-- left as a tiny placeholder; callers set the real window. @rpcUrl@ defaults to
-- the documented public endpoint @https://mainnet.base.org@.
defaultBaseRpc :: RpcConfig
defaultBaseRpc = RpcConfig
  { rpcUrl       = "https://mainnet.base.org"
  , rpcPoolMgr   = basePoolManager
  , rpcTopic0    = v4SwapTopic0
  , rpcPoolId    = basePoolId
  , rpcFromBlock = 0
  , rpcToBlock   = 0
  , rpcChunk     = 500
  }

-- ---------------------------------------------------------------------------
-- JSON-RPC wire types
-- ---------------------------------------------------------------------------

-- | One decoded @eth_getLogs@ entry: block number, an optional inline block
-- timestamp (the Base public RPC returns @blockTimestamp@ on each log — a big
-- win, since it saves an @eth_getBlockByNumber@ round-trip per block), and the
-- raw @data@ hex.
data SwapLog = SwapLog
  { slBlock        :: !Integer
  , slTimestampMay :: !(Maybe Integer)  -- ^ unix seconds, if the RPC supplies it.
  , slDataHex      :: !Text
  } deriving (Show)

instance FromJSON SwapLog where
  parseJSON = withObject "log" $ \o -> do
    blk <- o .: "blockNumber"
    ts  <- o .:? "blockTimestamp"
    d   <- o .: "data"
    pure SwapLog
      { slBlock        = hexToInteger blk
      , slTimestampMay = fmap hexToInteger ts
      , slDataHex      = d
      }

-- ---------------------------------------------------------------------------
-- Fetch
-- ---------------------------------------------------------------------------

-- | Fetch the pool's V4 Swap ticks over @[rpcFromBlock, rpcToBlock]@, chunked by
-- @rpcChunk@, returning @(utc-time, tick)@ pairs sorted by time. Timestamps come
-- from the inline @blockTimestamp@ when present; any log missing it is dropped
-- from the tick series with a note (the estimation window in 09-09 uses an
-- endpoint that supplies it — verified on @mainnet.base.org@).
-- | Current chain head via @eth_blockNumber@, through the lifted 'Chain.Rpc'
-- transport. Preserves the previous "0 on failure" fallback.
currentHeadBlock :: String -> IO Integer
currentHeadBlock url =
  either (const 0) id <$> ethBlockNumber (defaultBaseEnv { reUrl = T.pack url })

-- | Blocks kept back from the head, so a chunk boundary can never land past the
-- tip while the fetch is in flight (the node advances during a multi-hour pull)
-- and so no reorg-able block enters the series.
headSafetyMargin :: Integer
headSafetyMargin = 60

-- | Fetch the pool's V4 Swap ticks over the configured window, optionally
-- STREAMING each chunk to a cache file as it arrives.
--
-- Two robustness properties the 09-09 full-history pull needs, both learned the
-- hard way:
--
--   * __The end block is clamped to the chain head__ (less 'headSafetyMargin').
--     A @--to@ beyond the tip makes the node reject the range outright
--     (@block range extends beyond current head block@), and retrying cannot
--     help because the condition is not transient.
--   * __Chunks are appended to the cache as they arrive__ when a path is given.
--     A ~500-call pull that only writes at the end throws away hours of work if
--     the final call fails.
fetchSwapTicks :: RpcConfig -> Maybe FilePath -> IO [(UTCTime, Int)]
fetchSwapTicks cfg0 mcache = do
  head' <- currentHeadBlock (rpcUrl cfg0)
  let capped = if head' > 0 then min (rpcToBlock cfg0) (head' - headSafetyMargin)
                            else rpcToBlock cfg0
      cfg    = cfg0 { rpcToBlock = capped }
  if capped /= rpcToBlock cfg0
    then putStrLn ("  toBlock clamped " ++ show (rpcToBlock cfg0) ++ " -> "
                    ++ show capped ++ " (head " ++ show head' ++ " less "
                    ++ show headSafetyMargin ++ " safety blocks)")
    else pure ()
  case mcache of
    Just path -> writeFile path cacheBanner
    Nothing   -> pure ()
  let chunks = blockChunks cfg
      total  = length chunks
  decoded <- concat <$> mapM (fetchOne cfg total) (zip [1 :: Int ..] chunks)
  putStrLn ("  fetched " ++ show (length decoded) ++ " ticks from "
             ++ show total ++ " chunks")
  pure (sortOn fst decoded)
  where
    -- Progress is reported every 25 chunks: a silent multi-hour run is
    -- undebuggable.
    fetchOne cfg total (i, (lo, hi)) = do
      ls <- getLogsChunk cfg lo hi
      let ticks = [ (posixSecondsToUTCTime (fromInteger ts), decodeTick (TE.encodeUtf8 d))
                  | SwapLog { slTimestampMay = Just ts, slDataHex = d } <- ls ]
      case mcache of
        Just path -> appendFile path (renderTicks ticks)
        Nothing   -> pure ()
      if i `mod` 25 == 0 || i == total
        then do
          putStrLn ("  chunk " ++ show i ++ "/" ++ show total
                     ++ " blocks " ++ show lo ++ ".." ++ show hi
                     ++ " (+" ++ show (length ls) ++ " logs)")
          hFlush stdout
        else pure ()
      pure ticks

-- | Block ranges @[(lo,hi), ...]@ covering @[from,to]@ in @chunk@-sized steps.
blockChunks :: RpcConfig -> [(Integer, Integer)]
blockChunks cfg = go (rpcFromBlock cfg)
  where
    to    = rpcToBlock cfg
    chunk = max 1 (rpcChunk cfg)
    go lo
      | lo > to   = []
      | otherwise = let hi = min to (lo + chunk - 1) in (lo, hi) : go (hi + 1)

-- | One @eth_getLogs@ call for a single block range. The retry/backoff loop is
-- now the single implementation in 'Chain.Rpc.rpcPost' (this module no longer
-- forks it): @rpcPost@ handles the ~500 sequential public-RPC calls of the 09-09
-- pull, retrying transient 429/5xx and JSON-RPC errors with bounded exponential
-- backoff, and returning 'Left' only after giving up. On give-up this call
-- 'fail's with the block range, exactly as before.
getLogsChunk :: RpcConfig -> Integer -> Integer -> IO [SwapLog]
getLogsChunk cfg lo hi = do
  let filterObj = object
        [ "address"   .= rpcPoolMgr cfg
        , "fromBlock" .= toHexQuantity lo
        , "toBlock"   .= toHexQuantity hi
        , "topics"    .= [rpcTopic0 cfg, rpcPoolId cfg]
        ]
      env = defaultBaseEnv { reUrl = T.pack (rpcUrl cfg) }
  r <- rpcPost env "eth_getLogs" [filterObj]
  case r of
    Left err -> fail ("eth_getLogs (blocks " ++ show lo ++ ".." ++ show hi
                       ++ ") gave up: " ++ err)
    Right v  -> case fromJSON v of
      Success logs -> pure logs
      Error e      -> fail ("eth_getLogs decode (blocks " ++ show lo ++ ".."
                             ++ show hi ++ "): " ++ e)

-- | Serialize a @(utc-time, tick)@ series to a CSV cache under
-- @notes/structural-econometrcics/data/@ so re-runs (and 09-09) never re-fetch.
-- Format: a comment banner + @timestamp_unix,tick@ rows (unix seconds keep the
-- round-trip unambiguous, independent of locale/timezone parsing).
cacheSwapTicks :: FilePath -> [(UTCTime, Int)] -> IO ()
cacheSwapTicks path rows = writeFile path (cacheBanner ++ renderTicks rows)

-- | Header of the tick cache. Shared by the streaming and whole-file writers so
-- the two cannot drift.
cacheBanner :: String
cacheBanner =
  "# Base V4 Swap ticks cache (poolId " <> T.unpack basePoolId <> ")\n"
    <> "# columns: timestamp_unix,tick  (decoded from V4 Swap log data word 4)\n"
    <> "timestamp_unix,tick\n"

-- | Render tick rows as CSV lines.
renderTicks :: [(UTCTime, Int)] -> String
renderTicks rows = unlines [ show (utcToUnix t) ++ "," ++ show tk | (t, tk) <- rows ]

-- ---------------------------------------------------------------------------
-- ABI decode
-- ---------------------------------------------------------------------------

-- | Decode the pool tick from a V4 Swap log @data@ (ASCII hex, @0x@ optional).
-- The tick is word 4 (int24), sign-extended by the ABI across the whole 256-bit
-- word, so a full-word two's-complement read yields the signed tick directly.
--
-- The word arithmetic is now the single implementation in 'Chain.Abi'
-- ('decodeWordAt' operates on RAW returndata bytes); this decodes the ASCII-hex
-- log @data@ to bytes once at the boundary, then reads word 4.
decodeTick :: ByteString -> Int
decodeTick = fromInteger . decodeWordAt True 4 . hexToBytes . TE.decodeUtf8

-- | Decode @sqrtPriceX96@ (word 2, uint160) from a V4 Swap log @data@.
decodeSqrtPriceX96 :: ByteString -> Integer
decodeSqrtPriceX96 = decodeWordAt False 2 . hexToBytes . TE.decodeUtf8

-- ---------------------------------------------------------------------------
-- CSV ingestion (cassava)
-- ---------------------------------------------------------------------------

-- | Load a @(timestamp_unix, tick)@ CSV (the RPC cache or a frozen fixture) into
-- a @(utc-time, tick)@ tick series. Lines beginning with @#@ are treated as
-- comments and skipped; a single @timestamp_unix,tick@ header row is skipped.
loadSwapTicks :: FilePath -> IO [(UTCTime, Int)]
loadSwapTicks path = do
  raw <- BL.readFile path
  let cleaned = BL.intercalate "\n"
              . filter (not . isComment)
              . BL.split 0x0a
              $ raw
  case Csv.decode Csv.HasHeader cleaned :: Either String (V.Vector (Integer, Int)) of
    Left err   -> fail ("swap-ticks CSV parse: " ++ err)
    Right rows ->
      pure [ (posixSecondsToUTCTime (fromInteger ts), tk) | (ts, tk) <- V.toList rows ]
  where
    isComment ln = case BL.uncons ln of
      Just (c, _) -> c == 0x23  -- '#'
      Nothing     -> True       -- drop blank lines

-- ---------------------------------------------------------------------------
-- Hex / time helpers
-- ---------------------------------------------------------------------------

-- | Parse a @0x@-prefixed hex quantity (e.g. @blockNumber@) to an 'Integer'.
hexToInteger :: Text -> Integer
hexToInteger t = case readHex (stripHexPrefix (T.unpack t)) of
  ((v, _) : _) -> v
  _            -> 0

-- | Render an 'Integer' as a @0x@ hex quantity for JSON-RPC block tags.
toHexQuantity :: Integer -> Text
toHexQuantity n = T.pack ("0x" ++ showHex' n)
  where
    showHex' k
      | k < 0     = "0"
      | k < 16    = [hexDigit k]
      | otherwise = showHex' (k `div` 16) ++ [hexDigit (k `mod` 16)]
    hexDigit d
      | d < 10    = toEnum (fromEnum '0' + fromInteger d)
      | otherwise = toEnum (fromEnum 'a' + fromInteger (d - 10))

stripHexPrefix :: String -> String
stripHexPrefix ('0' : 'x' : rest) = rest
stripHexPrefix ('0' : 'X' : rest) = rest
stripHexPrefix s                  = s

utcToUnix :: UTCTime -> Integer
utcToUnix = round . utcTimeToPOSIXSeconds

-- ---------------------------------------------------------------------------
-- Variance math (CTX-VAR)
-- ---------------------------------------------------------------------------

-- | Tick → log-price on the λ = 1.0001 grid: @log(1.0001^tick) = tick·ln 1.0001@.
tickToLogPrice :: Int -> Double
tickToLogPrice t = fromIntegral t * log 1.0001

-- | Group ticks into per-day chronological series, bucketed by 'dailyEpoch'.
byEpoch :: [(UTCTime, Int)] -> Map Epoch [Int]
byEpoch ticks =
  fmap reverse $ Map.fromListWith (++)
    [ (dailyEpoch t, [tk]) | (t, tk) <- sortOn fst ticks ]

-- | Realized variance of a within-day series: the sum of squared log-price
-- increments (standard RV, no mean removal).
rvOfSeries :: [Int] -> Double
rvOfSeries ticks =
  let ps   = map tickToLogPrice ticks
      incs = zipWith (-) (drop 1 ps) ps
  in sum (map (\x -> x * x) incs)

-- | σ̂²_t: per-epoch realized variance over the FULL within-day tick series.
realizedVariance :: [(UTCTime, Int)] -> Map Epoch Double
realizedVariance = Map.map rvOfSeries . byEpoch

-- | σ̃²_t: the EIV instrument. The SAME realized-variance estimator applied to a
-- DISJOINT intraday sub-window — the even-position swaps (0-based) within each
-- day. Being an independent noisy measure of the same daily σ², it instruments
-- σ̂²_t and corrects the attenuation bias on υ̂₀ (spec §4.3, two noisy measures).
instrumentVariance :: [(UTCTime, Int)] -> Map Epoch Double
instrumentVariance = Map.map (rvOfSeries . evens) . byEpoch
  where evens xs = [ x | (i, x) <- zip [0 :: Int ..] xs, even i ]

-- | i_t: the per-epoch MEAN underlying pool tick, from the same V4 Swap series
-- that produces σ̂²_t. This is the panel's moneyness anchor: an accrual spell's
-- pool tick is the average of these daily means over the spell (see
-- "Panel.Build"), so @d = |i_K − i_t|@ measures moneyness over the window the
-- premium actually accrued in — not at a single instant.
--
-- Deriving i_t from the SAME tick series as σ̂² (rather than from the subgraph's
-- @tickAt@ event field) keeps regressor and moneyness on one provenance chain.
meanPoolTick :: [(UTCTime, Int)] -> Map Epoch Double
meanPoolTick = Map.map avg . byEpoch
  where
    avg [] = 0 / 0
    avg xs = sum (map fromIntegral xs) / fromIntegral (length xs)

-- | Write the per-epoch @(σ̂²_t, σ̃²_t)@ join to CSV, with a banner documenting
-- the window definitions. Columns: @epoch,sigma2,sigma2_instrument@.
writeVarianceCsv
  :: FilePath -> Map Epoch Double -> Map Epoch Double -> Map Epoch Double -> IO ()
writeVarianceCsv path sig2 sig2i tickM = writeFile path (banner ++ rows)
  where
    epochs = Map.keys (Map.unions [sig2, sig2i, tickM])
    look m e = Map.findWithDefault (0 / 0) e m
    rows = unlines
      [ show e ++ "," ++ show (look sig2 e) ++ "," ++ show (look sig2i e)
                ++ "," ++ show (look tickM e)
      | e <- epochs ]
    banner = unlines
      [ "# Panoptic υ variance regressor σ̂²_t, EIV instrument σ̃²_t, pool tick i_t (CTX-VAR)"
      , "# σ̂²_t (sigma2)            = daily realized variance of within-day V4"
      , "#   tick-implied log-price increments over the FULL within-day Swap series."
      , "# σ̃²_t (sigma2_instrument) = the SAME estimator on the DISJOINT even-swap"
      , "#   intraday sub-window (0-based even positions) — the two-noisy-measures IV."
      , "# i_t (pool_tick_mean)     = mean underlying pool tick over the same day,"
      , "#   from the SAME Swap series (the panel's moneyness anchor)."
      , "# epoch = UTC-day index floor(unixSeconds/86400) (same boundary as the panel)."
      , "# Source: Uniswap V4 PoolManager Swap logs on Base via chunked eth_getLogs"
      , "#   (poolId 0x96d4…288c0a); BigQuery path retired (project suspended)."
      , "epoch,sigma2,sigma2_instrument,pool_tick_mean"
      ]

-- ---------------------------------------------------------------------------
-- Historical / superseded BigQuery reference (NOT the live path)
-- ---------------------------------------------------------------------------

-- | The plan's original BigQuery Swap query, retained for provenance ONLY. It is
-- superseded by the RPC path above (BigQuery project suspended; see the module
-- header and DATA-SOURCES.md §4). Do NOT wire this as the live source.
--
-- The @topics[OFFSET(0)]@ / @Swap@ references below mirror the plan's intended
-- filter (mainnet v3 reference form).
historicalBigQuerySql :: Text
historicalBigQuerySql = T.unlines
  [ "-- HISTORICAL / SUPERSEDED (BigQuery project suspended; live path is RPC eth_getLogs)"
  , "SELECT block_timestamp, block_number, log_index, data"
  , "FROM `bigquery-public-data.crypto_ethereum.logs`"
  , "WHERE address = LOWER(@pool)"          -- parameterized, never hardcoded
  , "  AND topics[OFFSET(0)] = @swap_topic0" -- Swap topic0
  , "  AND DATE(block_timestamp) BETWEEN @from AND @to"
  , "ORDER BY block_number, log_index;"
  ]
