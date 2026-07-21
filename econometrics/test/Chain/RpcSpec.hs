{-# LANGUAGE OverloadedStrings #-}

-- | Offline specs for "Chain.Rpc". These read ONLY the frozen golden fixture
-- @test/fixtures/premium-acc-golden.json@ (live probes from 10-RESEARCH, frozen)
-- and exercise the pure decode/encode path. __No HTTP transport call, no URL,
-- and no network IO appears in this file__ — the whole suite must pass offline.
--
-- @describe@ titles feed the validation map's @--ta -m@ filters: @"Chain.Rpc"@
-- and @"premium golden"@.
module Chain.RpcSpec (spec) where

import           Data.Aeson (FromJSON (..), eitherDecode, object, withObject,
                             (.:), (.=))
import qualified Data.ByteString.Lazy as BL
import           Data.Text (Text)
import qualified Data.Text as T
import           Numeric (readHex)
import           Test.Hspec

import           Chain.Rpc (blockTagHex, decodeCallResult)

fixturePath :: FilePath
fixturePath = "test/fixtures/premium-acc-golden.json"

-- | One frozen accumulator reading: the recorded currency0 X64 value and the
-- (synthesised) full 32-byte @eth_call@ returndata word.
data Reading = Reading
  { rIsLong   :: !Int
  , rExpected :: !Text  -- ^ expected currency0 X64, as @0x@ hex
  , rResult   :: !Text  -- ^ raw 32-byte returndata word, as @0x@ hex
  } deriving (Show)

instance FromJSON Reading where
  parseJSON = withObject "reading" $ \o ->
    Reading <$> o .: "isLong"
            <*> o .: "expected_currency0_x64"
            <*> o .: "result"

newtype Golden = Golden { readings :: [Reading] }

instance FromJSON Golden where
  parseJSON = withObject "golden" $ \o -> Golden <$> o .: "readings"

-- | Parse a @0x@-prefixed hex string to an 'Integer'.
hexVal :: Text -> Integer
hexVal t = case readHex (dropPfx (T.unpack t)) of
  ((v, _) : _) -> v
  _            -> 0
  where
    dropPfx ('0' : 'x' : r) = r
    dropPfx ('0' : 'X' : r) = r
    dropPfx s               = s

-- | The currency0 (right slot) accumulator decoded from a reading's returndata,
-- through the production 'decodeCallResult' path (wrapped in an @eth_call@
-- result envelope, exactly as the transport delivers it).
currency0Of :: Reading -> Integer
currency0Of r =
  case decodeCallResult (object ["result" .= rResult r]) of
    Right (_left, right) -> right
    Left err             -> error ("fixture decode failed: " ++ err)

spec :: Spec
spec = do
  describe "Chain.Rpc" $ do
    describe "blockTagHex" $ do
      it "renders a block number as minimal lowercase 0x hex (no leading zeros)" $
        -- 44,500,000 = 0x2a70420 (the 10-02 plan literal 0x2a76d80 was arithmetically wrong)
        blockTagHex 44500000 `shouldBe` "0x2a70420"

      it "renders 0 as 0x0 and small numbers without padding" $ do
        blockTagHex 0  `shouldBe` "0x0"
        blockTagHex 1  `shouldBe` "0x1"
        blockTagHex 15 `shouldBe` "0xf"
        blockTagHex 16 `shouldBe` "0x10"

    describe "decodeCallResult (fail loudly)" $ do
      it "empty returndata 0x is a Left, never a decoded zero" $
        decodeCallResult (object ["result" .= ("0x" :: Text)])
          `shouldSatisfy` isLeft

      it "a JSON-RPC error envelope is a Left carrying the message" $ do
        let env = object ["error" .= object ["code" .= (-32000 :: Int)
                                            , "message" .= ("archive not available" :: Text)]]
        case decodeCallResult env of
          Left msg -> msg `shouldContain` "archive not available"
          Right _  -> expectationFailure "expected Left on a JSON-RPC error envelope"

  describe "premium golden" $ do
    it "decodes the block-47M gross reading's currency0 (right) slot" $ do
      rs <- loadReadings
      -- readings[1] = block 47,000,000 gross (short), stored
      currency0Of (rs !! 1) `shouldBe` hexVal "0x3cac79361af8320491"

    it "each reading's decoded currency0 equals its recorded expected value" $ do
      rs <- loadReadings
      mapM_ (\r -> currency0Of r `shouldBe` hexVal (rExpected r)) rs

    it "the first reading's currency0 is the frozen 0x3363c8e16f43182fb" $ do
      rs <- loadReadings
      currency0Of (head rs) `shouldBe` hexVal "0x3363c8e16f43182fb"

    it "invariants: monotone in block height, owed > gross, atTick > stored" $ do
      rs <- loadReadings
      let gross445 = currency0Of (rs !! 0)  -- block 44.5M gross, stored
          gross47  = currency0Of (rs !! 1)  -- block 47M   gross, stored
          owed47   = currency0Of (rs !! 2)  -- block 47M   owed,  stored
          atTick   = currency0Of (rs !! 3)  -- latest, atTick=-200000 gross
      gross445 `shouldSatisfy` (< gross47)       -- monotone increasing
      owed47   `shouldSatisfy` (> gross47)       -- nu*R/N > nu*R^2/(N*T)
      atTick   `shouldSatisfy` (> gross47)       -- extrapolation exceeds stored
      rIsLong (rs !! 2) `shouldBe` 1             -- reading 2 is the long/owed leg

loadReadings :: IO [Reading]
loadReadings = do
  bytes <- BL.readFile fixturePath
  case eitherDecode bytes :: Either String Golden of
    Left err -> error ("golden fixture parse: " ++ err)
    Right g  -> pure (readings g)

isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _        = False
