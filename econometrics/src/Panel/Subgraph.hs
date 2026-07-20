{-# LANGUAGE OverloadedStrings #-}

-- | Panoptic subgraph GraphQL client for the position-epoch panel (CTX-PANEL).
--
-- Fetches @TokenId@ / @Leg@ / cumulative-premia snapshots for a single confirmed
-- Panoptic market and returns them as typed 'RawPosition' records. The panel
-- assembly (cumulative -> per-epoch delta) lives in "Panel.Build"; this module is
-- purely the transport + JSON decode layer.
--
-- == Confirmed market (see notes/structural-econometrcics/data/DATA-SOURCES.md §4)
--
--   * Chain:        Base mainnet (L2), chainId 8453.
--   * panopticPool: 0xb50e8bb68f5855da742f4579274902a20454174a (ETH/USDC, fee 500).
--   * underlyingPool poolId (Uniswap V4):
--       0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a
--   * Endpoint (keyless, public Goldsky):
--       panoptic-subgraph-base/dev/gn
--
-- The endpoint URL is passed in via 'Endpoint' (from CLI / config — never
-- hardcoded here). An optional gateway key is read at runtime from the
-- @GRAPH_API_KEY@ environment variable (the confirmed Base endpoint needs none;
-- the hook exists only for a future gateway-hosted subgraph). The key is never
-- printed or committed.
module Panel.Subgraph
  ( -- * Endpoint / pool wrappers
    Endpoint (..)
  , PoolAddr (..)
    -- * Decoded records
  , Leg (..)
  , Snapshot (..)
  , RawPosition (..)
    -- * Fetch + parse
  , fetchPositions
  , parsePositions
  , positionsQuery
  ) where

import           Data.Aeson
import           Data.Aeson.Types      (Parser, typeMismatch)
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy  as BL
import           Data.Text             (Text)
import qualified Data.Text             as T
import           Network.HTTP.Simple
import           System.Environment    (lookupEnv)
import           Text.Read             (readMaybe)

-- | Subgraph HTTP(S) endpoint URL. Supplied from config/CLI, never hardcoded.
newtype Endpoint = Endpoint Text
  deriving (Show, Eq)

-- | The @panopticPool@ / underlying-pool identifier used in the query filter.
newtype PoolAddr = PoolAddr Text
  deriving (Show, Eq)

-- | One option leg of a Panoptic @TokenId@.
--
--   * 'legStrike'      — strike as a /price/ ratio (converted to the tick i_K by
--                        "Panel.Build".@strikeToTick@ on the λ=1.0001 grid).
--   * 'legWidth'       — leg width in tick-spacing units (@PosSpec.width_span@).
--   * 'legIsLong'      — long/short flag.
--   * 'legTokenType'   — 0/1 token-type selector.
--   * 'legOptionRatio' — the option ratio multiplier.
data Leg = Leg
  { legStrike      :: !Double
  , legWidth       :: !Int
  , legIsLong      :: !Bool
  , legTokenType   :: !Int
  , legOptionRatio :: !Int
  }
  deriving (Show, Eq)

-- | A daily snapshot of a position's CUMULATIVE settled-premia totals plus the
-- underlying pool tick at that snapshot's block. The panel builder diffs
-- consecutive snapshots into per-epoch flows (never uses the raw cumulative).
data Snapshot = Snapshot
  { snapTimestamp    :: !Integer -- ^ Unix seconds of the snapshot block.
  , snapBlock        :: !Integer -- ^ Block number of the snapshot.
  , snapPremiaUsd    :: !Double  -- ^ Cumulative @premiaSettledInUsdTotal@.
  , snapPremia0      :: !Double  -- ^ Cumulative @premiaSettled0Total@ (ETH leg).
  , snapPremia1      :: !Double  -- ^ Cumulative @premiaSettled1Total@ (USDC leg).
  , snapPoolTick     :: !Int     -- ^ Underlying Uniswap pool tick i_t at the block.
  }
  deriving (Show, Eq)

-- | A single Panoptic position (@TokenId@) with its legs and daily snapshots.
data RawPosition = RawPosition
  { rpTokenId   :: !Text
  , rpPool      :: !Text
  , rpLegs      :: ![Leg]
  , rpSnapshots :: ![Snapshot]
  }
  deriving (Show, Eq)

-- Numeric coercion helpers ---------------------------------------------------
--
-- The subgraph serialises BigInt / BigDecimal scalars as JSON /strings/, while a
-- normalised fixture may use JSON numbers. Accept both.

numDouble :: Value -> Parser Double
numDouble (Number n) = pure (realToFrac n)
numDouble (String s) =
  maybe (fail ("not a number: " ++ T.unpack s)) pure (readMaybe (T.unpack s))
numDouble v = typeMismatch "Double" v

numInt :: Value -> Parser Int
numInt (Number n) = pure (round n)
numInt (String s) =
  maybe (fail ("not an int: " ++ T.unpack s)) pure (readMaybe (T.unpack s))
numInt v = typeMismatch "Int" v

numInteger :: Value -> Parser Integer
numInteger (Number n) = pure (round n)
numInteger (String s) =
  maybe (fail ("not an integer: " ++ T.unpack s)) pure (readMaybe (T.unpack s))
numInteger v = typeMismatch "Integer" v

numBool :: Value -> Parser Bool
numBool (Bool b) = pure b
numBool v        = (/= (0 :: Int)) <$> numInt v

instance FromJSON Leg where
  parseJSON = withObject "Leg" $ \o ->
    Leg
      <$> (o .: "strike"      >>= numDouble)
      <*> (o .: "width"       >>= numInt)
      <*> (o .: "isLong"      >>= numBool)
      <*> (o .: "tokenType"   >>= numInt)
      <*> (o .: "optionRatio" >>= numInt)

instance FromJSON Snapshot where
  parseJSON = withObject "Snapshot" $ \o ->
    Snapshot
      <$> (o .: "timestamp"               >>= numInteger)
      <*> (o .: "blockNumber"             >>= numInteger)
      <*> (o .: "premiaSettledInUsdTotal" >>= numDouble)
      <*> (o .: "premiaSettled0Total"     >>= numDouble)
      <*> (o .: "premiaSettled1Total"     >>= numDouble)
      <*> (o .: "poolTick"                >>= numInt)

instance FromJSON RawPosition where
  parseJSON = withObject "RawPosition" $ \o ->
    RawPosition
      <$> o .: "id"
      <*> o .: "pool"
      <*> o .: "legs"
      <*> o .: "snapshots"

-- | The GraphQL @data@ envelope: @{ "data": { "tokenIds": [...] } }@.
newtype Envelope = Envelope { envTokenIds :: [RawPosition] }

instance FromJSON Envelope where
  parseJSON = withObject "Envelope" $ \o -> do
    d  <- o .: "data"
    ts <- d .: "tokenIds"
    pure (Envelope ts)

-- | The position query. @legs@ carries the strike/width; @snapshots@ is the
-- per-epoch projection of the CUMULATIVE @AccountBalance.premiaSettled*Total@
-- fields at each daily epoch's block, together with the underlying pool tick.
--
-- The live block-height snapshotting (one @accountBalance@ read per epoch block)
-- is finalised at the estimation run (plan 09-09); the frozen fixture encodes
-- this normalised response shape so the assembler and its test can run offline.
positionsQuery :: Text
positionsQuery = T.unlines
  [ "query Positions($pool: String!, $first: Int!, $skip: Int!) {"
  , "  tokenIds(first: $first, skip: $skip, where: { pool: $pool }) {"
  , "    id"
  , "    pool"
  , "    legs { strike width isLong tokenType optionRatio }"
  , "    snapshots(orderBy: timestamp, orderDirection: asc) {"
  , "      timestamp"
  , "      blockNumber"
  , "      premiaSettledInUsdTotal"
  , "      premiaSettled0Total"
  , "      premiaSettled1Total"
  , "      poolTick"
  , "    }"
  , "  }"
  , "}"
  ]

-- | Decode a GraphQL response body into the position list. Pure — used by the
-- offline fixture test as well as 'fetchPositions'.
parsePositions :: BL.ByteString -> Either String [RawPosition]
parsePositions = fmap envTokenIds . eitherDecode

-- | Page size for @first@/@skip@ pagination (the subgraph caps @first@ at 1000).
pageSize :: Int
pageSize = 1000

-- | Fetch all positions for the confirmed pool, paginating with @first@/@skip@.
--
-- Reads an optional @GRAPH_API_KEY@ from the environment (the confirmed Base
-- endpoint is keyless; the header is only attached when the variable is set).
-- The key is never logged.
fetchPositions :: Endpoint -> PoolAddr -> IO [RawPosition]
fetchPositions endpoint pool = go 0 []
  where
    go skip acc = do
      page <- fetchPage endpoint pool pageSize skip
      let acc' = acc ++ page
      if length page < pageSize
        then pure acc'
        else go (skip + pageSize) acc'

-- | Fetch a single @first@/@skip@ page.
fetchPage :: Endpoint -> PoolAddr -> Int -> Int -> IO [RawPosition]
fetchPage (Endpoint url) (PoolAddr pool) first skip = do
  mkey <- lookupEnv "GRAPH_API_KEY"
  req0 <- parseRequest ("POST " <> T.unpack url)
  let payload =
        object
          [ "query"     .= positionsQuery
          , "variables" .= object
              [ "pool"  .= pool
              , "first" .= first
              , "skip"  .= skip
              ]
          ]
      withAuth = case mkey of
        Just k | not (null k) ->
          addRequestHeader "Authorization" (BS8.pack ("Bearer " ++ k))
        _ -> id
      req =
        setRequestBodyJSON payload
          . withAuth
          . setRequestHeader "Content-Type" ["application/json"]
          $ req0
  resp <- httpLBS req
  case parsePositions (getResponseBody resp) of
    Left err -> ioError (userError ("Panel.Subgraph: response decode failed: " ++ err))
    Right ps -> pure ps
