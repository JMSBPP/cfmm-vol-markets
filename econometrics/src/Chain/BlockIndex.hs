{-# LANGUAGE OverloadedStrings #-}

-- | The epoch ↔ block-number index every accumulator read is keyed on.
--
-- == Why this module exists
--
-- The Phase-9 swap-tick cache is @timestamp_unix,tick@ only — it carries __no
-- block numbers__. To sample the premium accumulator at the block that closes
-- each epoch we must construct the map @epoch -> firstBlockAtOrAfter(epoch *
-- epochSeconds)@ ourselves.
--
-- RESEARCH (\"Don't Hand-Roll\", Pitfall 4) forbids assuming a 2-second Base
-- block: a drift of even 30 blocks straddles an epoch boundary and silently
-- misattributes a whole epoch of fee accrual. So the boundary block is found by
-- a monotone /search over the actual block timestamps/ (interpolation-assisted
-- bisection over @eth_getBlockByNumber@), and the postcondition
-- @ts(b) >= target && ts(b-1) < target@ is asserted before any row is accepted.
--
-- == The epoch rule is imported, never redefined (Pitfall 4)
--
-- The boundary INSTANT is @epoch * epochSeconds@ and the round-trip check uses
-- 'Panel.Build.epochOfSeconds' — the single source of truth for the epoch grid
-- (at width 86400 it is 'Panel.Build.dailyEpoch'; at 3600 it is the hourly grid
-- this phase runs on). This module NEVER writes its own @floor(ts / width)@; the
-- 09-05 40587-offset trap is exactly what that would reintroduce.
--
-- == Streaming + resumable (the Phase-9 @Panel.Variance@ pattern)
--
-- 'buildBlockIndex' appends each row to disk the instant it is found and skips
-- any epoch already present in the CSV, so a partially completed multi-thousand
-- call run resumes from its file rather than re-probing from scratch. A run that
-- only writes at the end is a run you do twice.
module Chain.BlockIndex
  ( -- * The index row
    EpochBlock (..)
    -- * The search core (pure, testable offline against an irregular oracle)
  , stepSearch
  , SearchStep (..)
  , bisectFirstAtOrAfter
    -- * Live boundary search
  , findBlockAtOrAfter
  , findBlockAtOrAfterWith
    -- * Build / load / persist
  , estimationWindowBlocks
  , buildBlockIndex
  , buildBlockIndexWith
  , loadBlockIndex
  , writeBlockIndex
  , appendBlockIndexRow
    -- * Lookup
  , epochBlockMap
  , blockForEpoch
  ) where

import           Control.Exception     (SomeException, try)
import           Data.IORef            (modifyIORef', newIORef, readIORef)
import           Data.List             (foldl', nub, sort, sortOn)
import qualified Data.Map.Strict       as Map
import           Data.Map.Strict       (Map)
import           Data.Maybe            (mapMaybe)
import           Data.Time.Clock       (getCurrentTime)
import           Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import           Data.Time.Format      (defaultTimeLocale, formatTime)
import qualified Data.Text             as T

import           Chain.Rpc             (BlockHeader (..), RpcEnv (..),
                                        ethGetBlockByNumber)
import           Panel.Build           (Epoch, epochOfSeconds)

-- ---------------------------------------------------------------------------
-- The index row
-- ---------------------------------------------------------------------------

-- | One row of the index: an epoch, the first block whose timestamp is at or
-- after that epoch's boundary instant, and that block's timestamp.
data EpochBlock = EpochBlock
  { ebEpoch          :: !Epoch    -- ^ the epoch (grid-agnostic; hourly for Phase 10).
  , ebBlockNumber    :: !Integer  -- ^ first block with @ts >= epoch * epochSeconds@.
  , ebBlockTimestamp :: !Integer  -- ^ that block's unix-second timestamp.
  } deriving (Show, Eq)

-- | The estimation-window block endpoints (Phase-9 pull). Used ONLY as the
-- initial search bracket — never as a block-time assumption. The boundary block
-- is always converged to by timestamp search inside this bracket.
estimationWindowBlocks :: (Integer, Integer)
estimationWindowBlocks = (43781657, 48879461)

-- ---------------------------------------------------------------------------
-- The search core
-- ---------------------------------------------------------------------------

-- | One step of the boundary search. 'Done' names the answer; 'Probe' names the
-- next block whose timestamp must be fetched. Factored out so the pure driver
-- ('bisectFirstAtOrAfter') and the IO driver ('findBlockAtOrAfterWith') share
-- ONE algorithm and can never diverge.
data SearchStep = Done !Integer | Probe !Integer
  deriving (Show, Eq)

-- | Given the target timestamp and the current bracket endpoints with their
-- timestamps (invariant: @tsLo < target <= tsHi@ and @lo < hi@), decide the
-- next probe. The midpoint is chosen by linear INTERPOLATION on the timestamps
-- (Base blocks are near-uniform, so this converges in a handful of steps) but is
-- always clamped strictly inside @(lo, hi)@, so the bracket shrinks every step
-- and the search terminates regardless of how irregular the block times are.
stepSearch :: Integer -> (Integer, Integer) -> (Integer, Integer) -> SearchStep
stepSearch target (lo, tsLo) (hi, tsHi)
  | hi - lo <= 1 = Done hi
  | otherwise    = Probe mid
  where
    span'  = max 1 (tsHi - tsLo)
    guess  = lo + ((target - tsLo) * (hi - lo)) `div` span'
    mid    = max (lo + 1) (min (hi - 1) guess)

-- | Pure boundary search over an in-memory timestamp oracle: the smallest block
-- @b@ in @[lo, hi]@ with @oracle b >= target@, or 'Nothing' if even @oracle hi@
-- is below the target. Assumes @oracle@ is monotone non-decreasing. This is the
-- exact algorithm the live search runs, exercised offline against a deliberately
-- irregular oracle (1s and 4s gaps) so the \"blocks are 2s\" assumption cannot
-- creep in.
bisectFirstAtOrAfter :: (Integer -> Integer) -> Integer -> (Integer, Integer) -> Maybe Integer
bisectFirstAtOrAfter oracle target (lo0, hi0)
  | oracle hi0 < target  = Nothing
  | oracle lo0 >= target = Just lo0
  | otherwise            = Just (loop (lo0, oracle lo0) (hi0, oracle hi0))
  where
    loop l@(_, _) h@(_, _) =
      case stepSearch target l h of
        Done b    -> b
        Probe mid ->
          let tm = oracle mid
          in if tm >= target then loop l (mid, tm) else loop (mid, tm) h

-- ---------------------------------------------------------------------------
-- Live boundary search
-- ---------------------------------------------------------------------------

-- | 'findBlockAtOrAfterWith' over the live @eth_getBlockByNumber@ transport,
-- with a per-call memo so bracket endpoints are not re-fetched.
findBlockAtOrAfter :: RpcEnv -> Integer -> (Integer, Integer) -> IO (Either String BlockHeader)
findBlockAtOrAfter env target bracket = do
  fetch <- memoFetch (ethGetBlockByNumber env)
  findBlockAtOrAfterWith fetch target bracket

-- | Find the first block whose timestamp is @>= target@ within @(lo, hi)@,
-- driving the shared 'stepSearch' over an injectable @fetch@ (the live transport
-- in production, a pure oracle in the offline spec). The asserted postcondition
-- —@ts(b) >= target@ and, when @b > lo@, @ts(b-1) < target@— is checked against
-- freshly fetched headers before the block is returned; a violation is a 'Left',
-- never a best guess.
findBlockAtOrAfterWith
  :: (Integer -> IO (Either String BlockHeader))
  -> Integer
  -> (Integer, Integer)
  -> IO (Either String BlockHeader)
findBlockAtOrAfterWith fetch target (lo0, hi0)
  | lo0 > hi0 = pure (Left ("empty bracket (" ++ show lo0 ++ ", " ++ show hi0 ++ ")"))
  | otherwise = do
      eHi <- fetch hi0
      case eHi of
        Left e -> pure (Left e)
        Right hHi
          | bhTimestamp hHi < target ->
              pure (Left ("no block at/after target " ++ show target
                           ++ " within bracket (" ++ show lo0 ++ ", " ++ show hi0 ++ ")"))
          | otherwise -> do
              eLo <- fetch lo0
              case eLo of
                Left e -> pure (Left e)
                Right hLo
                  | bhTimestamp hLo >= target -> pure (Right hLo)  -- bracket floor is at/after; caller owns lo
                  | otherwise -> loop (lo0, bhTimestamp hLo) (hi0, bhTimestamp hHi)
  where
    loop l@(lo, _) h =
      case stepSearch target l h of
        Done b    -> verify b lo
        Probe mid -> do
          em <- fetch mid
          case em of
            Left e   -> pure (Left e)
            Right hm
              | bhTimestamp hm >= target -> loop l (mid, bhTimestamp hm)
              | otherwise                -> loop (mid, bhTimestamp hm) h

    -- Confirm the postcondition against real (memoised) headers before accepting
    -- @b@: @ts(b) >= target@ and, unless @b@ is the bracket floor, @ts(b-1) <
    -- target@. A violation is a 'Left', never a best guess.
    verify b lo = do
      eb <- fetch b
      case eb of
        Left e -> pure (Left e)
        Right hb
          | bhTimestamp hb < target ->
              pure (Left ("postcondition ts(" ++ show b ++ ")="
                           ++ show (bhTimestamp hb) ++ " >= " ++ show target ++ " failed"))
          | b <= lo   -> pure (Right hb)
          | otherwise -> do
              ep <- fetch (b - 1)
              case ep of
                Left e -> pure (Left e)
                Right hp
                  | bhTimestamp hp >= target ->
                      pure (Left ("postcondition ts(" ++ show (b - 1) ++ ")="
                                   ++ show (bhTimestamp hp) ++ " < " ++ show target ++ " failed"))
                  | otherwise -> pure (Right hb)

-- | Wrap a fetch with an 'IORef' memo: each block number hits the network at
-- most once for the lifetime of the returned function.
memoFetch
  :: (Integer -> IO (Either String BlockHeader))
  -> IO (Integer -> IO (Either String BlockHeader))
memoFetch fetch = do
  ref <- newIORef (Map.empty :: Map Integer BlockHeader)
  pure $ \b -> do
    m <- readIORef ref
    case Map.lookup b m of
      Just h  -> pure (Right h)
      Nothing -> do
        r <- fetch b
        case r of
          Right h -> modifyIORef' ref (Map.insert b h) >> pure (Right h)
          Left e  -> pure (Left e)

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

-- | Build the index over @epochs@ at bucket width @epochSeconds@, streaming to
-- @csvPath@. Live variant: wraps 'ethGetBlockByNumber' in a memo shared across
-- every epoch (consecutive searches overlap near the boundary, so the shared
-- cache elides most repeat probes) and stamps the file's provenance banner with
-- the RPC URL, the build date, and the epoch rule.
buildBlockIndex :: RpcEnv -> Int -> FilePath -> [Epoch] -> IO (Either String [EpochBlock])
buildBlockIndex env epochSeconds csvPath epochs = do
  now <- getCurrentTime
  let date = formatTime defaultTimeLocale "%Y-%m-%d" now
      provenance =
        [ "epoch-blocks.csv — epoch -> first Base block at or after the boundary instant"
        , "RPC: " ++ T.unpack (reUrl env) ++ "   built: " ++ date
        , "epoch rule: Panel.Build.epochOfSeconds " ++ show epochSeconds
            ++ " (single source of truth); boundary instant = epoch * " ++ show epochSeconds
        , "columns below: epoch, block_number, block_timestamp (unix seconds)"
        ]
  fetch <- memoFetch (ethGetBlockByNumber env)
  buildBlockIndexWith fetch estimationWindowBlocks provenance epochSeconds csvPath epochs

-- | The engine behind 'buildBlockIndex', with the transport, the initial block
-- window, and the banner all injected so the offline spec can drive the FULL
-- build+resume path against a pure oracle and a temp file — no network. Streams
-- each row to disk as it is found; on the first RPC 'Left' it stops and returns
-- 'Left' naming the epoch that failed (a missing epoch is made visible, never
-- interpolated or skipped).
buildBlockIndexWith
  :: (Integer -> IO (Either String BlockHeader))  -- ^ block fetch (may memoize).
  -> (Integer, Integer)                           -- ^ initial (lo, hi) block window.
  -> [String]                                     -- ^ provenance banner lines.
  -> Int                                           -- ^ epoch width in seconds.
  -> FilePath
  -> [Epoch]
  -> IO (Either String [EpochBlock])
buildBlockIndexWith fetch (wLo, wHi) provenance epochSeconds csvPath epochs = do
  mExisting <- loadBlockIndexMaybe csvPath
  existing <- case mExisting of
    Just rows -> pure rows
    Nothing   -> writeFile csvPath (headerBlock provenance) >> pure []
  let doneMap   = epochBlockMap existing
      wanted    = sort (nub epochs)
      remaining = filter (`Map.notMember` doneMap) wanted
      prev0 = if Map.null doneMap then wLo else ebBlockNumber (snd (Map.findMax doneMap))
  eNew <- go prev0 remaining []
  pure $ case eNew of
    Left e     -> Left e
    Right new  -> Right (sortOn ebEpoch (Map.elems doneMap ++ new))
  where
    go _ [] acc = pure (Right acc)
    go prev (e : es) acc = do
      let target = fromIntegral e * fromIntegral epochSeconds :: Integer
      r <- findBlockAtOrAfterWith fetch target (prev, wHi)
      case r of
        Left err -> pure (Left ("epoch " ++ show e ++ ": " ++ err))
        Right h  ->
          let ts  = bhTimestamp h
              bn  = bhNumber h
              rt  = epochOfSeconds epochSeconds (posixSecondsToUTCTime (fromIntegral ts))
          in if rt /= e
               then pure (Left ("epoch " ++ show e ++ ": round-trip epoch mismatch, "
                                 ++ "block ts " ++ show ts ++ " maps to epoch " ++ show rt))
               else if bn < prev
                 then pure (Left ("epoch " ++ show e ++ ": non-monotone block "
                                   ++ show bn ++ " < previous " ++ show prev))
                 else do
                   let row = EpochBlock e bn ts
                   appendBlockIndexRow csvPath row
                   go bn es (row : acc)

-- ---------------------------------------------------------------------------
-- Persist / load
-- ---------------------------------------------------------------------------

-- | The @#@ provenance banner plus the column header, ready to prepend rows to.
headerBlock :: [String] -> String
headerBlock provenance =
  unlines (map ("# " ++) provenance ++ ["epoch,block_number,block_timestamp"])

-- | Default banner for a standalone 'writeBlockIndex' (round-trip / test use).
defaultBanner :: [String]
defaultBanner =
  [ "epoch-blocks.csv — epoch -> first Base block at or after the boundary instant"
  , "columns: epoch, block_number, block_timestamp (unix seconds)"
  , "epoch rule: Panel.Build.epochOfSeconds (single source of truth)"
  ]

-- | Write the whole index with a banner + header, replacing any existing file.
writeBlockIndex :: FilePath -> [EpochBlock] -> IO ()
writeBlockIndex fp rows =
  writeFile fp (headerBlock defaultBanner ++ concatMap renderRow rows)

-- | Append a single data row (the streaming-build primitive).
appendBlockIndexRow :: FilePath -> EpochBlock -> IO ()
appendBlockIndexRow fp = appendFile fp . renderRow

renderRow :: EpochBlock -> String
renderRow eb =
  show (ebEpoch eb) ++ "," ++ show (ebBlockNumber eb) ++ ","
    ++ show (ebBlockTimestamp eb) ++ "\n"

-- | Load the index, ignoring the @#@ banner and the header row. Parse errors and
-- a missing file both yield @[]@ (the build then starts fresh); use
-- 'loadBlockIndexMaybe' when \"file absent\" must be distinguished from \"empty\".
loadBlockIndex :: FilePath -> IO [EpochBlock]
loadBlockIndex fp = maybe [] id <$> loadBlockIndexMaybe fp

-- | 'Nothing' if the file cannot be read (absent), @Just rows@ otherwise.
loadBlockIndexMaybe :: FilePath -> IO (Maybe [EpochBlock])
loadBlockIndexMaybe fp = do
  e <- try (readFile' fp) :: IO (Either SomeException String)
  pure $ case e of
    Left _    -> Nothing
    Right txt -> Just (mapMaybe parseRow (lines txt))
  where
    readFile' p = do { s <- readFile p; length s `seq` pure s }
    parseRow l
      | null l                  = Nothing
      | "#"     `isPfx` l       = Nothing
      | "epoch" `isPfx` l       = Nothing
      | otherwise = case splitCommas l of
          (a : b : c : _) -> EpochBlock <$> readI a <*> readI b <*> readI c
          _               -> Nothing
    isPfx p s = take (length p) s == p

readI :: (Read a) => String -> Maybe a
readI s = case reads s of { [(v, "")] -> Just v; _ -> Nothing }

splitCommas :: String -> [String]
splitCommas s = case break (== ',') s of
  (a, [])      -> [a]
  (a, _ : rest) -> a : splitCommas rest

-- ---------------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------------

-- | Index the rows by epoch for @O(log n)@ lookup.
epochBlockMap :: [EpochBlock] -> Map Epoch EpochBlock
epochBlockMap = foldl' (\m eb -> Map.insert (ebEpoch eb) eb m) Map.empty

-- | The boundary block number for an epoch, or 'Nothing' if the epoch is not in
-- the index.
blockForEpoch :: Map Epoch EpochBlock -> Epoch -> Maybe Integer
blockForEpoch m e = ebBlockNumber <$> Map.lookup e m
