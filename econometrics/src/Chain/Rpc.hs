{-# LANGUAGE OverloadedStrings #-}

-- | Generic JSON-RPC transport for Base archive reads: the SINGLE retry/backoff
-- implementation in the repo. 'Panel.Variance' previously owned the only such
-- loop; it is __lifted__ here (cut, paste, generalise), and @Panel.Variance@ now
-- imports 'rpcPost'. RESEARCH names /forking/ this loop as the mechanism behind
-- the 09-05 divergence — so it lives in exactly one place.
--
-- == Fail loudly (RESEARCH "Architecture Patterns")
--
-- 'ethCall' returns @Either String ByteString@. Empty returndata (@0x@), a
-- missing @result@ key, or a JSON-RPC @error@ object all produce 'Left'. Never
-- decode absent state to @0@: a zero accumulator is indistinguishable from a real
-- zero and would sail through the reconciliation gate as a spurious "this
-- position earned nothing" observation.
module Chain.Rpc
  ( -- * Environment
    RpcEnv (..)
  , defaultBaseEnv
  , drpcFailoverEnv
    -- * Transport
  , rpcPost
    -- * Typed calls
  , ethCall
  , ethGetBlockByNumber
  , ethBlockNumber
    -- * Block tags
  , BlockTag (..)
  , blockTagHex
  , blockTagValue
    -- * Block header
  , BlockHeader (..)
    -- * Offline decode of a call envelope
  , decodeCallResult
  ) where

import           Control.Concurrent (threadDelay)
import           Control.Exception (SomeException, try)
import           Data.Aeson (FromJSON (..), Value (..), eitherDecode, object,
                             withObject, (.:), (.:?), (.=))
import qualified Data.Aeson.Types as AT
import           Data.ByteString (ByteString)
import           Data.Text (Text)
import qualified Data.Text as T
import           Network.HTTP.Simple (getResponseBody, httpLBS, parseRequest,
                                      setRequestBodyJSON)
import           System.IO (hPutStrLn, stderr)

import           Chain.Abi (bytesToHex, bytesToInteger, decodeUint128Pair,
                            hexToBytes)

-- ---------------------------------------------------------------------------
-- Environment
-- ---------------------------------------------------------------------------

-- | JSON-RPC endpoint plus retry policy. @reBackoffMicros@ is the /base/ backoff
-- (microseconds); the actual sleep is @reBackoffMicros * 2^attempt@, capped at
-- 60 s — the exponential schedule lifted verbatim from @getLogsChunk@.
data RpcEnv = RpcEnv
  { reUrl           :: !Text  -- ^ JSON-RPC endpoint.
  , reMaxRetries    :: !Int   -- ^ retries before giving up ('Left').
  , reBackoffMicros :: !Int   -- ^ base backoff in microseconds.
  } deriving (Show, Eq)

-- | The public, keyless, archive-capable Base endpoint (VERIFIED at block
-- 44,000,000 in 10-RESEARCH).
defaultBaseEnv :: RpcEnv
defaultBaseEnv = RpcEnv
  { reUrl           = "https://mainnet.base.org"
  , reMaxRetries    = 6
  , reBackoffMicros = 2000000  -- 2 s base
  }

-- | Failover endpoint, also archive-capable per the RESEARCH probe matrix. The
-- two endpoints RESEARCH measured to fail on archive requests (one 403s on
-- archive, one returns HTML error pages) are deliberately omitted.
drpcFailoverEnv :: RpcEnv
drpcFailoverEnv = defaultBaseEnv { reUrl = "https://base.drpc.org" }

-- ---------------------------------------------------------------------------
-- Wire envelope
-- ---------------------------------------------------------------------------

-- | @{ "result": ..., "error": ... }@ JSON-RPC envelope.
data RpcResponse = RpcResponse (Maybe Value) (Maybe Value)

instance FromJSON RpcResponse where
  parseJSON = withObject "resp" $ \o ->
    RpcResponse <$> o .:? "result" <*> o .:? "error"

-- ---------------------------------------------------------------------------
-- Transport (lifted verbatim from Panel.Variance.getLogsChunk)
-- ---------------------------------------------------------------------------

-- | Generic JSON-RPC POST with bounded exponential backoff. Returns the
-- @result@ 'Value' on success, or 'Left' after 'reMaxRetries' consecutive
-- failures (transport exception, JSON decode error, or a JSON-RPC @error@
-- object). Retries are logged to stderr as @[retry n/max]@ — a multi-hour bulk
-- read that fails silently on a transient 429 is a run you do twice.
rpcPost :: RpcEnv -> Text -> [Value] -> IO (Either String Value)
rpcPost env method params = go (0 :: Int)
  where
    maxRetries = reMaxRetries env

    go attempt = do
      r <- try attemptOnce :: IO (Either SomeException (Either String Value))
      case r of
        Right (Right v) -> pure (Right v)
        Right (Left err)
          | attempt >= maxRetries -> pure (Left (giveUp err))
          | otherwise             -> backoff attempt err >> go (attempt + 1)
        Left e
          | attempt >= maxRetries -> pure (Left (giveUp (show e)))
          | otherwise             -> backoff attempt (show e) >> go (attempt + 1)

    giveUp why = T.unpack method ++ " gave up after " ++ show maxRetries
                   ++ " retries: " ++ why

    backoff attempt why = do
      let secs = min 60000000 (reBackoffMicros env * (2 ^ attempt))
      hPutStrLn stderr ("  [retry " ++ show (attempt + 1) ++ "/" ++ show maxRetries
                         ++ "] " ++ T.unpack method ++ " after "
                         ++ show (fromIntegral secs / 1e6 :: Double) ++ "s: "
                         ++ take 160 why)
      threadDelay secs

    attemptOnce = do
      let body = object
            [ "jsonrpc" .= ("2.0" :: Text)
            , "id"      .= (1 :: Int)
            , "method"  .= method
            , "params"  .= params
            ]
      req0 <- parseRequest ("POST " ++ T.unpack (reUrl env))
      resp <- httpLBS (setRequestBodyJSON body req0)
      pure $ case eitherDecode (getResponseBody resp) :: Either String RpcResponse of
        Left err                          -> Left ("JSON decode: " ++ err)
        Right (RpcResponse _ (Just e))    -> Left ("RPC error: " ++ show e)
        Right (RpcResponse (Just v) _)    -> Right v
        Right (RpcResponse Nothing _)     -> Left "no result field in response"

-- ---------------------------------------------------------------------------
-- Block tags
-- ---------------------------------------------------------------------------

-- | An @eth_call@ / block-parameter tag.
data BlockTag = BlockNumber Integer | Latest deriving (Show, Eq)

-- | Render an 'Integer' block number as a minimal lowercase @0x@ hex string
-- (@eth_call@'s block parameter rejects leading zeros). @blockTagHex 0 == "0x0"@.
blockTagHex :: Integer -> Text
blockTagHex n
  | n <= 0    = "0x0"
  | otherwise = "0x" <> T.pack (go n "")
  where
    go 0 acc = acc
    go k acc = go (k `div` 16) (hexDigit (k `mod` 16) : acc)
    hexDigit d
      | d < 10    = toEnum (fromEnum '0' + fromInteger d)
      | otherwise = toEnum (fromEnum 'a' + fromInteger (d - 10))

-- | The JSON value for a block tag: a hex string for a number, @"latest"@ for
-- 'Latest'.
blockTagValue :: BlockTag -> Value
blockTagValue (BlockNumber n) = String (blockTagHex n)
blockTagValue Latest          = String "latest"

-- ---------------------------------------------------------------------------
-- Block header
-- ---------------------------------------------------------------------------

-- | The two block-header fields the epoch↔block index (10-03) needs.
data BlockHeader = BlockHeader
  { bhNumber    :: !Integer  -- ^ block number.
  , bhTimestamp :: !Integer  -- ^ unix seconds.
  } deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Typed calls
-- ---------------------------------------------------------------------------

-- | @eth_call@ to @to@ with @calldata@ at a block tag, returning RAW returndata
-- bytes. __Fails loudly:__ empty returndata (@0x@) is a 'Left', never a decoded
-- zero.
ethCall :: RpcEnv -> Text -> ByteString -> BlockTag -> IO (Either String ByteString)
ethCall env to calldata tag = do
  let callObj = object [ "to" .= to, "data" .= ("0x" <> bytesToHex calldata) ]
  r <- rpcPost env "eth_call" [callObj, blockTagValue tag]
  pure $ case r of
    Left err        -> Left err
    Right (String h)
      | isEmptyHex h -> Left "empty returndata (0x): state unavailable, refusing to decode as zero"
      | otherwise    -> Right (hexToBytes h)
    Right other     -> Left ("eth_call: unexpected result shape " ++ show other)

-- | @eth_getBlockByNumber(tag, false)@ → the block's number and timestamp.
ethGetBlockByNumber :: RpcEnv -> Integer -> IO (Either String BlockHeader)
ethGetBlockByNumber env n = do
  r <- rpcPost env "eth_getBlockByNumber" [blockTagValue (BlockNumber n), Bool False]
  pure $ case r of
    Left err -> Left err
    Right v  -> case AT.parseMaybe headerP v of
      Just h  -> Right h
      Nothing -> Left "eth_getBlockByNumber: could not parse number/timestamp"
  where
    headerP = withObject "block" $ \o -> do
      num <- o .: "number"
      ts  <- o .: "timestamp"
      pure (BlockHeader (hexTextToInteger num) (hexTextToInteger ts))

-- | @eth_blockNumber@ → the current head as an 'Integer'.
ethBlockNumber :: RpcEnv -> IO (Either String Integer)
ethBlockNumber env = do
  r <- rpcPost env "eth_blockNumber" []
  pure $ case r of
    Left err         -> Left err
    Right (String h) -> Right (hexTextToInteger h)
    Right other      -> Left ("eth_blockNumber: unexpected result " ++ show other)

-- ---------------------------------------------------------------------------
-- Offline decode of a call envelope (the golden-fixture decode path)
-- ---------------------------------------------------------------------------

-- | Decode a JSON-RPC @eth_call@ response envelope into the packed
-- @(currency1 left slot, currency0 right slot)@ accumulator pair.
--
-- Honours the same fail-loud contract as 'ethCall', but works offline on a
-- stored 'Value' (the frozen golden fixture builds these): a JSON-RPC @error@
-- object → 'Left' with the message; empty returndata @0x@ or a missing @result@
-- → 'Left'; otherwise the 32-byte word is split by 'decodeUint128Pair' so the
-- RIGHT slot is currency0 (ETH), the reconciliation target.
decodeCallResult :: Value -> Either String (Integer, Integer)
decodeCallResult v =
  case AT.parseMaybe envelopeP v of
    Just (_, Just e)  -> Left ("RPC error: " ++ show e)
    Just (Just h, _)
      | isEmptyHex h  -> Left "empty returndata (0x): state unavailable, refusing to decode as zero"
      | otherwise     -> Right (decodeUint128Pair (bytesToInteger (hexToBytes h)))
    _                 -> Left "no result field in response"
  where
    envelopeP = withObject "resp" $ \o ->
      (,) <$> (o .:? "result" :: AT.Parser (Maybe Text))
          <*> (o .:? "error"  :: AT.Parser (Maybe Value))

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- | True for an empty @eth_call@ returndata: @""@, @"0x"@, or @"0X"@.
isEmptyHex :: Text -> Bool
isEmptyHex h = h `elem` ["", "0x", "0X"]

-- | Parse a @0x@-prefixed hex quantity 'Text' to an 'Integer' (via raw bytes).
hexTextToInteger :: Text -> Integer
hexTextToInteger = bytesToInteger . hexToBytes . pad
  where
    -- hexToBytes requires even length; pad an odd nibble count with a leading 0.
    pad t = let s = stripPfx t
            in if odd (T.length s) then "0" <> s else s
    stripPfx t
      | "0x" `T.isPrefixOf` t || "0X" `T.isPrefixOf` t = T.drop 2 t
      | otherwise = t
