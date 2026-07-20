{-# LANGUAGE OverloadedStrings #-}

-- | Panoptic subgraph GraphQL client for the position-epoch panel (CTX-PANEL).
--
-- == SCHEMA CORRECTION (plan 09-09, live run)
--
-- Plan 09-04 wrote this module against an ASSUMED schema in which each
-- @TokenId@ carried daily @snapshots@ of a cumulative @premiaSettledInUsdTotal@,
-- and each @Leg.strike@ was a PRICE to be mapped onto the tick grid. Neither
-- exists. Introspection of the live Base subgraph at the 09-09 run established:
--
--   * @TokenId@ has NO @snapshots@ field. Its fields are
--     @id, idHexString, pool, tokenCount, accountBalances, legs@.
--   * There is NO @premiaSettledInUsdTotal@ anywhere. @AccountBalance@ carries
--     @premiaSettled0Total@/@premiaSettled1Total@, and on the confirmed ETH/USDC
--     market BOTH ARE IDENTICALLY ZERO for every account balance; the
--     @premiumSettleds@ event collection is EMPTY. The settled-premia channel
--     carries no signal on this market.
--   * @Leg.strike@ is ALREADY AN int24 TICK (observed range −202 990 … −197 280),
--     not a price. The old @round(log K / log 1.0001)@ map took the logarithm of
--     a negative number and produced NaN.
--
-- The premium channel that DOES carry signal is @OptionBurn@: @premium0@ /
-- @premium1@ (the premium realized when a position is closed) together with
-- @tickAt@ (the pool tick at the burn). Paired with the position's @OptionMint@
-- this yields an ACCRUAL SPELL — see "Panel.Build" for how the spell becomes the
-- estimation observation, and the phase's analysis output for the consequences
-- for the unit of observation.
--
-- == Confirmed market (see notes/structural-econometrcics/data/DATA-SOURCES.md §4)
--
--   * Chain:        Base mainnet (L2), chainId 8453.
--   * panopticPool: 0xb50e8bb68f5855da742f4579274902a20454174a (ETH/USDC, fee 500).
--   * underlyingPool / @Pool.id@ (Uniswap V4 poolId):
--       0x96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a
--   * Endpoint (keyless, public Goldsky): panoptic-subgraph-base/dev/gn
--
-- The endpoint URL is passed in via 'Endpoint' (from CLI / config — never
-- hardcoded here). An optional gateway key is read at runtime from the
-- @GRAPH_API_KEY@ environment variable (the confirmed Base endpoint needs none).
-- The key is never printed or committed.
module Panel.Subgraph
  ( -- * Endpoint / pool wrappers
    Endpoint (..)
  , PoolAddr (..)
    -- * Decoded records
  , Leg (..)
  , MintEvent (..)
  , BurnEvent (..)
  , CollateralFlow (..)
    -- * Fetch (full history, cursor-paginated)
  , fetchMints
  , fetchBurns
  , fetchLegs
  , fetchCollateralFlows
    -- * Pure decode (fixture-testable)
  , parseMints
  , parseBurns
  , parseLegs
  , parseCollateralFlows
  ) where

import           Data.Aeson
import           Data.Aeson.Key         (Key)
import           Data.Aeson.Types      (Parser, parseEither, typeMismatch)
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

-- | The underlying-pool identifier (@Pool.id@ = the V4 poolId) used to filter
-- every collection below.
newtype PoolAddr = PoolAddr Text
  deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Records
-- ---------------------------------------------------------------------------

-- | One option leg of a Panoptic @TokenId@.
--
--   * 'legStrikeTick'  — the strike as an int24 TICK on the λ=1.0001 grid.
--                        This is i_K directly; no price→tick conversion.
--   * 'legWidth'       — leg width in tick-spacing units (@PosSpec.width_span@).
--   * 'legIsLong'      — long (buyer, PAYS premium) / short (seller, RECEIVES).
--   * 'legTokenType'   — 0/1 token-type selector.
--   * 'legOptionRatio' — the option ratio multiplier.
data Leg = Leg
  { legStrikeTick  :: !Int
  , legWidth       :: !Int
  , legIsLong      :: !Bool
  , legTokenType   :: !Int
  , legOptionRatio :: !Int
  }
  deriving (Show, Eq)

-- | An @OptionMint@: the opening of an accrual spell.
data MintEvent = MintEvent
  { meTokenId      :: !Text
  , meAccount      :: !Text     -- ^ @recipient.id@ — the account cluster.
  , meTimestamp    :: !Integer  -- ^ unix seconds.
  , meBlock        :: !Integer
  , meTickAt       :: !Int      -- ^ pool tick at the mint.
  , mePositionSize :: !Double
  }
  deriving (Show, Eq)

-- | An @OptionBurn@: the close of an accrual spell, carrying the REALIZED
-- premium over the whole spell.
--
-- Sign convention as emitted by the protocol: positive for SHORT positions
-- (the seller receives), negative for LONG positions (the buyer pays).
-- "Panel.Build" normalizes this to a single seller-side sign.
data BurnEvent = BurnEvent
  { beTokenId      :: !Text
  , beAccount      :: !Text
  , beTimestamp    :: !Integer
  , beBlock        :: !Integer
  , beTickAt       :: !Int      -- ^ pool tick at the burn.
  , bePremium0     :: !Double   -- ^ premium in token0 (ETH) raw units (18 dec).
  , bePremium1     :: !Double   -- ^ premium in token1 (USDC) raw units (6 dec).
  , bePositionSize :: !Double
  }
  deriving (Show, Eq)

-- | A signed collateral share flow (deposit positive, withdraw negative) for the
-- collateral-channel alternative (spec §6.2.4).
data CollateralFlow = CollateralFlow
  { cfOwner     :: !Text
  , cfTimestamp :: !Integer
  , cfIndex     :: !Int     -- ^ collateral vault index (0 = token0, 1 = token1).
  , cfShares    :: !Double  -- ^ SIGNED share delta.
  }
  deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Numeric coercion (the subgraph serialises BigInt/BigDecimal as JSON strings)
-- ---------------------------------------------------------------------------

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

-- | @isLong@ arrives as the BigInt string @"0"@/@"1"@.
numBool :: Value -> Parser Bool
numBool (Bool b) = pure b
numBool v        = (/= (0 :: Int)) <$> numInt v

-- | Pull a nested @{ "id": ... }@ reference.
refId :: Object -> Key -> Parser Text
refId o k = o .: k >>= withObject "ref" (.: "id")

instance FromJSON MintEvent where
  parseJSON = withObject "OptionMint" $ \o ->
    MintEvent
      <$> refId o "tokenId"
      <*> refId o "recipient"
      <*> (o .: "timestamp"    >>= numInteger)
      <*> (o .: "blockNumber"  >>= numInteger)
      <*> (o .: "tickAt"       >>= numInt)
      <*> (o .: "positionSize" >>= numDouble)

instance FromJSON BurnEvent where
  parseJSON = withObject "OptionBurn" $ \o ->
    BurnEvent
      <$> refId o "tokenId"
      <*> refId o "recipient"
      <*> (o .: "timestamp"    >>= numInteger)
      <*> (o .: "blockNumber"  >>= numInteger)
      <*> (o .: "tickAt"       >>= numInt)
      <*> (o .: "premium0"     >>= numDouble)
      <*> (o .: "premium1"     >>= numDouble)
      <*> (o .: "positionSize" >>= numDouble)

instance FromJSON Leg where
  parseJSON = withObject "Leg" $ \o ->
    Leg
      <$> (o .: "strike"      >>= numInt)   -- ALREADY a tick
      <*> (o .: "width"       >>= numInt)
      <*> (o .: "isLong"      >>= numBool)
      <*> (o .: "tokenType"   >>= numInt)
      <*> (o .: "optionRatio" >>= numInt)

-- | Envelope for a named GraphQL collection: @{ "data": { "<field>": [...] } }@.
-- Surfaces GraphQL @errors@ rather than silently decoding an empty result.
collection :: FromJSON a => Key -> BL.ByteString -> Either String [a]
collection field bs = do
  v <- eitherDecode bs
  parseEither (withObject "response" go) v
  where
    go o = do
      merrs <- o .:? "errors" :: Parser (Maybe Value)
      case merrs of
        Just e  -> fail ("GraphQL errors: " ++ show (encode e))
        Nothing -> o .: "data" >>= (.: field)

-- | Decode a full response body into its collection (pure; fixture-testable).
parseMints :: BL.ByteString -> Either String [MintEvent]
parseMints = collection "optionMints"

parseBurns :: BL.ByteString -> Either String [BurnEvent]
parseBurns = collection "optionBurns"

-- | @tokenIds@ with their legs, as a @tokenId → legs@ association list.
parseLegs :: BL.ByteString -> Either String [(Text, [Leg])]
parseLegs bs = map unwrap <$> collection "tokenIds" bs
  where unwrap (TokenLegs t ls) = (t, ls)

-- | Internal wrapper for the @tokenIds { id legs { … } }@ shape.
data TokenLegs = TokenLegs !Text ![Leg]

instance FromJSON TokenLegs where
  parseJSON = withObject "TokenId" $ \o ->
    TokenLegs <$> o .: "id" <*> o .: "legs"

-- | Deposits and withdraws, merged into SIGNED share flows.
parseCollateralFlows :: Bool -> BL.ByteString -> Either String [CollateralFlow]
parseCollateralFlows isDeposit bs =
  map toFlow <$> collection (if isDeposit then "collateralDeposits" else "collateralWithdraws") bs
  where
    toFlow (RawFlow o ts ix sh) =
      CollateralFlow o ts ix (if isDeposit then sh else negate sh)

data RawFlow = RawFlow !Text !Integer !Int !Double

instance FromJSON RawFlow where
  parseJSON = withObject "CollateralFlow" $ \o ->
    RawFlow
      <$> refId o "owner"
      <*> (o .: "timestamp" >>= numInteger)
      <*> (o .: "collateral" >>= withObject "collateral" (\c -> c .: "index" >>= numInt))
      <*> (o .: "shares" >>= numDouble)

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- | Page size. @first@ is capped at 1000 by the subgraph; pagination uses a
-- @timestamp_gt@ CURSOR rather than @skip@, because @skip@ is capped at 5000 and
-- the 09-09 pull needs the FULL history.
pageSize :: Int
pageSize = 1000

mintsQuery, burnsQuery, legsQuery, depositsQuery, withdrawsQuery :: Text
mintsQuery = T.unlines
  [ "query M($pool: String!, $first: Int!, $ts: BigInt!) {"
  , "  optionMints(first: $first, where: { pool: $pool, timestamp_gt: $ts },"
  , "              orderBy: timestamp, orderDirection: asc) {"
  , "    timestamp blockNumber tickAt positionSize"
  , "    tokenId { id } recipient { id }"
  , "  }"
  , "}"
  ]

burnsQuery = T.unlines
  [ "query B($pool: String!, $first: Int!, $ts: BigInt!) {"
  , "  optionBurns(first: $first, where: { pool: $pool, timestamp_gt: $ts },"
  , "              orderBy: timestamp, orderDirection: asc) {"
  , "    timestamp blockNumber tickAt positionSize premium0 premium1"
  , "    tokenId { id } recipient { id }"
  , "  }"
  , "}"
  ]

legsQuery = T.unlines
  [ "query L($pool: String!, $first: Int!, $skip: Int!) {"
  , "  tokenIds(first: $first, skip: $skip, where: { pool: $pool }) {"
  , "    id"
  , "    legs { strike width isLong tokenType optionRatio }"
  , "  }"
  , "}"
  ]

depositsQuery = T.unlines
  [ "query D($pool: String!, $first: Int!, $ts: BigInt!) {"
  , "  collateralDeposits(first: $first, where: { pool: $pool, timestamp_gt: $ts },"
  , "                     orderBy: timestamp, orderDirection: asc) {"
  , "    timestamp shares owner { id } collateral { index }"
  , "  }"
  , "}"
  ]

withdrawsQuery = T.unlines
  [ "query W($pool: String!, $first: Int!, $ts: BigInt!) {"
  , "  collateralWithdraws(first: $first, where: { pool: $pool, timestamp_gt: $ts },"
  , "                      orderBy: timestamp, orderDirection: asc) {"
  , "    timestamp shares owner { id } collateral { index }"
  , "  }"
  , "}"
  ]

-- | POST a query and hand the raw body to a pure decoder.
post :: Endpoint -> Text -> Value -> IO BL.ByteString
post (Endpoint url) qry vars = do
  mkey <- lookupEnv "GRAPH_API_KEY"
  req0 <- parseRequest ("POST " <> T.unpack url)
  let payload  = object [ "query" .= qry, "variables" .= vars ]
      withAuth = case mkey of
        Just k | not (null k) ->
          addRequestHeader "Authorization" (BS8.pack ("Bearer " ++ k))
        _ -> id
      req = setRequestBodyJSON payload
              . withAuth
              . setRequestHeader "Content-Type" ["application/json"]
              $ req0
  getResponseBody <$> httpLBS req

-- | Cursor pagination over a timestamp-ordered collection: keep requesting
-- @timestamp_gt = last seen@ until a short page arrives. Ties on a single
-- timestamp beyond a full page would be dropped, which cannot occur here (a
-- page is 1000 events and the market emits far fewer per second).
paginateByTs
  :: Endpoint -> PoolAddr -> Text
  -> (BL.ByteString -> Either String [a])
  -> (a -> Integer)
  -> IO [a]
paginateByTs ep (PoolAddr pool) qry decode tsOf = go 0 []
  where
    go cursor acc = do
      body <- post ep qry (object [ "pool" .= pool
                                  , "first" .= pageSize
                                  , "ts" .= T.pack (show (cursor :: Integer)) ])
      case decode body of
        Left err -> ioError (userError ("Panel.Subgraph: decode failed: " ++ err))
        Right [] -> pure acc
        Right xs ->
          let acc' = acc ++ xs
              next = maximum (map tsOf xs)
          in if length xs < pageSize then pure acc' else go next acc'

-- | All @OptionMint@s for the pool, full history.
fetchMints :: Endpoint -> PoolAddr -> IO [MintEvent]
fetchMints ep pool = paginateByTs ep pool mintsQuery parseMints meTimestamp

-- | All @OptionBurn@s for the pool, full history.
fetchBurns :: Endpoint -> PoolAddr -> IO [BurnEvent]
fetchBurns ep pool = paginateByTs ep pool burnsQuery parseBurns beTimestamp

-- | All @TokenId@ legs for the pool (@skip@ pagination — tokenIds have no
-- timestamp; the market's tokenId count is well under the 5000 skip cap).
fetchLegs :: Endpoint -> PoolAddr -> IO [(Text, [Leg])]
fetchLegs ep (PoolAddr pool) = go 0 []
  where
    go skip acc = do
      body <- post ep legsQuery (object [ "pool" .= pool
                                        , "first" .= pageSize
                                        , "skip" .= skip ])
      case parseLegs body of
        Left err -> ioError (userError ("Panel.Subgraph: legs decode failed: " ++ err))
        Right xs ->
          let acc' = acc ++ xs
          in if length xs < pageSize then pure acc' else go (skip + pageSize) acc'

-- | Signed collateral share flows (deposits positive, withdraws negative) for
-- the collateral-channel alternative.
fetchCollateralFlows :: Endpoint -> PoolAddr -> IO [CollateralFlow]
fetchCollateralFlows ep pool = do
  ds <- paginateByTs ep pool depositsQuery  (parseCollateralFlows True)  cfTimestamp
  ws <- paginateByTs ep pool withdrawsQuery (parseCollateralFlows False) cfTimestamp
  pure (ds ++ ws)
