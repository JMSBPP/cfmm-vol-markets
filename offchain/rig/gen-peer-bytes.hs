{-# LANGUAGE OverloadedStrings #-}

-- |
-- Generator for @offchain\/rig\/peer-haskell-bytes.json@ (plan 21-05, task 2 part A).
--
-- RUN IT WITH:
--
--     cabal exec -- runghc offchain/rig/gen-peer-bytes.hs | jq . > offchain/rig/peer-haskell-bytes.json
--
-- WHY THIS FILE EXISTS AT ALL. The v4.0 consumer fixture
-- @test\/pos_spec\/fixtures\/vol_order_return_golden.json@ carries a @peer_haskell_bytes@ array of
-- five @PLACEHOLDER -- NOT-PEER-VERIFIED@ entries and a @_peer_status@ recording that this rpc_api
-- workstream never delivered Haskell-produced bytes. Phase 21 is the first moment that gap CAN
-- close. But @test\/@ is the Solidity-testing track's territory, so the values are produced HERE
-- and OFFERED; the fixture is not edited by this track.
--
-- NOTHING IS HAND-TYPED. Every byte string is read from the golden and from the live capture, run
-- through the SHIPPED 'decode_create_orders_result', and printed. A generator that embedded its
-- own expected values would prove only that it agrees with itself -- the same failure this
-- milestone exists to kill.
module Main (main) where

import Data.Aeson (Value (..), eitherDecodeFileStrict, encode, object, toJSON, (.=))
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy.Char8 as L8
import Data.ByteArray.HexString (fromBytes)
import Data.Char (digitToInt, isHexDigit, toLower)
import qualified Data.Foldable as F
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import System.Exit (exitFailure)

import VolOrder.Decode (decode_create_orders_result)

golden_path :: FilePath
golden_path = "test/pos_spec/fixtures/vol_order_return_golden.json"

capture_path :: FilePath
capture_path = "offchain/rig/batch-return-capture.json"

main :: IO ()
main = do
  golden  <- load golden_path
  capture <- load capture_path
  case build golden capture of
    Left err -> putStrLn ("gen-peer-bytes: " ++ err) >> exitFailure
    Right v  -> L8.putStrLn (encode v)

load :: FilePath -> IO Value
load path = do
  decoded <- eitherDecodeFileStrict path
  case decoded of
    Left err -> error (path ++ " did not decode: " ++ err)
    Right v  -> pure v

-- ---------------------------------------------------------------------------------------------
-- Value walking
-- ---------------------------------------------------------------------------------------------

field :: String -> Value -> Either String Value
field name (Object o) =
  maybe (Left ("missing key " ++ show name)) Right (KM.lookup (K.fromString name) o)
field name _ = Left ("expected an object to read " ++ show name)

as_string :: Value -> Either String String
as_string (String t) = Right (T.unpack t)
as_string _          = Left "expected a JSON string"

as_integer :: Value -> Either String Integer
as_integer (Number n) = Right (truncate n)
as_integer _          = Left "expected a JSON number"

as_array :: Value -> Either String [Value]
as_array (Array v) = Right (F.toList v)
as_array _         = Left "expected a JSON array"

-- ---------------------------------------------------------------------------------------------
-- Hex
-- ---------------------------------------------------------------------------------------------

normalise :: String -> String
normalise raw =
  let s = map toLower (filter (`notElem` (" \t\r\n" :: String)) raw)
  in fromMaybe s (stripPrefix "0x" s)

hex_bytes :: String -> Either String BS.ByteString
hex_bytes raw =
  let body = normalise raw
  in if not (null body) && even (length body) && all isHexDigit body
       then Right (BS.pack (unfold body))
       else Left ("not an even-length hex byte string: " ++ show raw)
  where
    unfold (a : b : rest) = fromIntegral (digitToInt a * 16 + digitToInt b) : unfold rest
    unfold _              = []

-- ---------------------------------------------------------------------------------------------
-- The artifact
-- ---------------------------------------------------------------------------------------------

build :: Value -> Value -> Either String Value
build golden capture = do
  names    <- field "names" golden    >>= as_array >>= mapM as_string
  ns       <- field "ns" golden       >>= as_array >>= mapM as_integer
  expected <- field "expected" golden >>= as_array >>= mapM as_string
  live     <- capture_returndata capture
  cases    <- mapM (one live) (zip3 names ns expected)
  pure $
    object
      [ "_generated_by" .=
          T.pack
            ("plan 21-05 task 2 part A, by offchain/rig/gen-peer-bytes.hs. Command: \
             \cabal exec -- runghc offchain/rig/gen-peer-bytes.hs | jq . > \
             \offchain/rig/peer-haskell-bytes.json")
      , "_source_golden" .= T.pack golden_path
      , "_source_capture" .= T.pack capture_path
      , "_decoder" .=
          T.pack
            "VolOrder.Decode.decode_create_orders_result -- the SHIPPED decoder, not a \
            \re-implementation. It computes expected_length = 64 + 64*count and rejects \
            \non-canonical bool words (anything but 0 or 1), matching solc's abi.decode, which \
            \reverts outright on a success word of 2."
      , "_scope" .=
          T.pack
            "This closes the CROSS-LANGUAGE gap for the (bool,uint256)[] RETURN ONLY. A Haskell \
            \decoder is run over bytes produced by an encoder outside this repo (cast \
            \abi-encode / alloy) and the results are recorded. It does NOT exercise a Haskell \
            \ENCODER: nothing here builds create_orders calldata, so the canonical-array-offset \
            \requirement on the INPUT side (offset 0x40 at byte 36, which the module enforces \
            \with an empty revert) remains UNEXERCISED from this side and must not be read as \
            \covered."
      , "_offer_to" .=
          T.pack
            "The Solidity-testing track (owner of test/). These values are OFFERED to fill the \
            \peer_haskell_bytes array in test/pos_spec/fixtures/vol_order_return_golden.json, \
            \whose five entries are still 'PLACEHOLDER -- NOT-PEER-VERIFIED' and whose \
            \_peer_status records that this rpc_api track never delivered Haskell-produced \
            \bytes. This track did NOT edit that fixture: test/ is not its territory. Consume \
            \by copying haskell_decode across, or by pointing the fixture test at this file."
      , "cases" .= cases
      ]

-- | The three case names the live rig capture also covered, as name -> returndata.
capture_returndata :: Value -> Either String [(String, String)]
capture_returndata capture = do
  cases <- field "cases" capture >>= as_array
  mapM (\c -> (,) <$> (field "name" c >>= as_string)
                  <*> (field "returndata" c >>= as_string)) cases

one :: [(String, String)] -> (String, Integer, String) -> Either String Value
one live (name, n, golden_bytes) = do
  raw <- hex_bytes golden_bytes
  let decoded = decode_create_orders_result (fromBytes raw)
      agrees = case decoded of
        Left _      -> False
        Right pairs -> toInteger (length pairs) == n
      decode_value = case decoded of
        Left err    -> object ["error" .= T.pack err]
        Right pairs ->
          -- toJSON on a list builds the Array, so this generator needs no `vector` import.
          toJSON [object ["success" .= s, "orderId" .= i] | (s, i) <- pairs]
      -- null for the two golden cases the live rig capture does not cover
      live_agrees = case lookup name live of
        Nothing  -> Null
        Just got -> Bool (normalise got == normalise golden_bytes)
  pure $
    object
      [ "name" .= T.pack name
      , "n" .= n
      , "haskell_decode" .= decode_value
      , "haskell_agrees_with_golden" .= agrees
      , "live_capture_agrees" .= live_agrees
      ]
