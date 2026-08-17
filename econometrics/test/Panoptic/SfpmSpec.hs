{-# LANGUAGE OverloadedStrings #-}

-- | Offline specs for 'Panoptic.Sfpm': the @getAccountPremium@ calldata layout
-- (dynamic @bytes poolKey@ head/tail split, derived selector, sign-extended
-- ticks), and the decode of the FROZEN live returndata in
-- @test/fixtures/premium-acc-golden.json@. No network access, no URL literals.
--
-- @describe@ titles: @"Panoptic.Sfpm"@ and @"premium golden"@ (the validation
-- map's @--ta -m@ filters).
module Panoptic.SfpmSpec (spec) where

import           Data.Aeson (Value, eitherDecodeFileStrict)
import qualified Data.Aeson.Types as AT
import qualified Data.ByteString  as BS
import           Data.Text        (Text)
import qualified Data.Text        as T
import           Test.Hspec

import           Chain.Abi (bytesToInteger, decodeWordAt, hexToBytes,
                            keccak256Hex)
import           Panoptic.Chunk (ChunkKey (..))
import           Panoptic.Sfpm

-- The known poolId — keccak256(poolKeyBytes), VERIFIED in 10-RESEARCH.
knownPoolId :: Text
knownPoolId = "96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a"

goldenPath :: FilePath
goldenPath = "test/fixtures/premium-acc-golden.json"

-- A representative chunk from the frozen probes: tokenType 0, [-199680, -197280].
chunkTT0 :: ChunkKey
chunkTT0 = ChunkKey 0 (-199680) (-197280)

spec :: Spec
spec = do
  describe "Panoptic.Sfpm" $ do

    describe "poolKey encoding" $ do
      it "keccak256(poolKeyBytes) equals the known poolId (byte-for-byte proof)" $
        keccak256Hex poolKeyBytes `shouldBe` knownPoolId

      it "poolKeyBytes is exactly 160 bytes (five 32-byte words)" $
        BS.length poolKeyBytes `shouldBe` 160

    describe "getAccountPremium calldata" $ do
      let cd = getAccountPremiumCalldata chunkTT0 Nothing False

      it "is 4 + 8*32 + 32 + 160 = 452 bytes (selector, 8 head slots, dynamic tail)" $
        BS.length cd `shouldBe` (4 + 8 * 32 + 32 + 160)

      it "the first head slot is 0x100 (256), the byte offset to the dynamic tail" $
        decodeWordAt False 0 (BS.drop 4 cd) `shouldBe` 256

      it "the dynamic tail begins with the poolKey length word (160)" $
        -- after selector (4) + 8 head slots (256) = 260 bytes, the length word
        decodeWordAt False 0 (BS.drop 260 cd) `shouldBe` 160

      it "negative tickLower/tickUpper appear sign-extended (leading 0xff) in their head slots" $ do
        let slot i = BS.take 32 (BS.drop (4 + i * 32) cd)
        BS.unpack (BS.take 4 (slot 3)) `shouldBe` replicate 4 0xff
        BS.unpack (BS.take 4 (slot 4)) `shouldBe` replicate 4 0xff
        decodeWordAt True 3 (BS.drop 4 cd) `shouldBe` (-199680)
        decodeWordAt True 4 (BS.drop 4 cd) `shouldBe` (-197280)

      it "atTick = Nothing encodes the stored-value sentinel 8388607 in head slot 5" $
        decodeWordAt True 5 (BS.drop 4 cd) `shouldBe` 8388607

      it "atTick = Just t encodes t (live extrapolation) in head slot 5" $ do
        let cd' = getAccountPremiumCalldata chunkTT0 (Just (-200000)) False
        decodeWordAt True 5 (BS.drop 4 cd') `shouldBe` (-200000)

      it "isLong = True encodes 1 and vegoid encodes 8 in head slots 6 and 7" $ do
        let cdL = getAccountPremiumCalldata chunkTT0 Nothing True
        decodeWordAt False 6 (BS.drop 4 cdL) `shouldBe` 1
        decodeWordAt False 7 (BS.drop 4 cdL) `shouldBe` 8

    describe "decodeAccountPremium" $ do
      it "on empty (0x) returndata returns Left" $
        decodeAccountPremium (hexToBytes "0x") `shouldSatisfy` isLeft

      it "on a single LeftRight-packed word puts currency0 in the right slot" $ do
        let cur0 = 0x3cac79361af8320491 :: Integer
            cur1 = 7 :: Integer
            word = cur1 * (2 ^ (128 :: Int)) + cur0
        decodeAccountPremium (encode32 word) `shouldBe` Right (cur0, cur1)

  describe "premium golden" $
    it "each frozen fixture reading decodes to its recorded currency0 X64 (right slot)" $ do
      readings <- loadReadings
      null readings `shouldBe` False
      mapM_ checkReading readings

-- ---------------------------------------------------------------------------
-- Golden fixture loading
-- ---------------------------------------------------------------------------

-- One reading: the raw @result@ hex and the expected currency0 accumulator.
data Reading = Reading { rResult :: Text, rExpected :: Text }

loadReadings :: IO [Reading]
loadReadings = do
  ev <- eitherDecodeFileStrict goldenPath :: IO (Either String Value)
  case ev of
    Left err -> error ("premium-acc-golden.json parse failed: " ++ err)
    Right v  -> case AT.parseMaybe readingsP v of
      Just rs -> pure rs
      Nothing -> error "premium-acc-golden.json: could not extract readings"
  where
    readingsP = AT.withObject "golden" $ \o -> do
      arr <- o AT..: "readings"
      mapM (AT.withObject "reading" $ \r ->
              Reading <$> r AT..: "result" <*> r AT..: "expected_currency0_x64") arr

checkReading :: Reading -> Expectation
checkReading (Reading resultHex expectedHex) =
  case decodeAccountPremium (hexToBytes resultHex) of
    Left err        -> expectationFailure ("decode failed: " ++ err)
    Right (cur0, _) -> cur0 `shouldBe` hexToInteger expectedHex

-- | Parse a @0x@-prefixed hex quantity to an 'Integer', padding an odd nibble
-- count (the frozen accumulators are odd-length, e.g. @0x3363c8e16f43182fb@;
-- 'hexToBytes' requires even length).
hexToInteger :: Text -> Integer
hexToInteger = bytesToInteger . hexToBytes . pad . strip
  where
    strip t | "0x" `T.isPrefixOf` t = T.drop 2 t
            | otherwise             = t
    pad t = if odd (T.length t) then "0" <> t else t

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- 32-byte big-endian encoding of a non-negative Integer (for the packed word).
encode32 :: Integer -> BS.ByteString
encode32 n0 = BS.pack (reverse (go (32 :: Int) n0))
  where
    go 0 _ = []
    go k n = fromIntegral (n `mod` 256) : go (k - 1) (n `div` 256)

isLeft :: Either a b -> Bool
isLeft (Left _)  = True
isLeft (Right _) = False
