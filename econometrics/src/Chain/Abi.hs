{-# LANGUAGE OverloadedStrings #-}

-- | Minimal, Solidity-faithful ABI codec plus the two pieces of on-chain
-- arithmetic every downstream number in Phase 10 depends on: two's-complement
-- sign extension and @unchecked@ modular subtraction.
--
-- This module is the SINGLE ABI/word-arithmetic implementation in the repo.
-- 'Panel.Variance' previously carried its own @wordAt@; that is now deleted and
-- @Panel.Variance@ re-uses 'decodeWordAt' from here so there is exactly one
-- decoder (the 09-05 divergence lesson: never fork a primitive).
--
-- == Why each primitive is load-bearing
--
--   * __Sign extension__ ('decodeWordAt' with @signed = True@): Solidity ABI-
--     encodes @int24@ by sign-extending it across the full 256-bit word, so a
--     negative tick such as @-199680@ appears as @0xffff…fffcf400@. Read it
--     unsigned and the tick becomes a ~1e77 garbage value.
--   * __Unchecked wraparound__ ('diffMod'): V4 fee growth and Panoptic premium
--     accumulators are @unchecked uint256@/@uint128@; only differences are
--     meaningful. RESEARCH Pitfall 3 — a naive @a - b@ on 'Integer' yields
--     ~-1.15e77 instead of ~1e19 whenever the accumulator has wrapped.
--   * __'feeGrowthInside'__: the three-branch identity that /defines/ the fee a
--     range earned (@Pool.sol@ L488-511). Getting the @>=@/@<@ boundaries wrong
--     silently mis-attributes fees at a tick edge.
--   * __Keccak-256__: Ethereum uses legacy Keccak-256, NOT SHA3-256 (different
--     padding). Using the wrong one produces wrong selectors/topics that /look/
--     plausible.
module Chain.Abi
  ( -- * Word-level codec
    decodeWordAt
  , encodeWord
  , encodeInt24
  , encodeUint256
  , encodeAddress
  , encodeBytesDynamic
  , decodeUint128Pair
    -- * Solidity-faithful arithmetic
  , diffMod
    -- * Uniswap V4 identity
  , feeGrowthInside
    -- * Hashing
  , keccak256Hex
  , selector
    -- * Hex helpers
  , hexToBytes
  , bytesToHex
  , bytesToInteger
  ) where

import           Crypto.Hash (hashWith)
import           Crypto.Hash.Algorithms (Keccak_256 (..))
import qualified Data.ByteArray as BA
import           Data.ByteArray.Encoding (Base (Base16), convertFromBase,
                                          convertToBase)
import           Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

twoPow128, twoPow255, twoPow256 :: Integer
twoPow128 = 2 ^ (128 :: Int)
twoPow255 = 2 ^ (255 :: Int)
twoPow256 = 2 ^ (256 :: Int)

-- ---------------------------------------------------------------------------
-- Word-level decode
-- ---------------------------------------------------------------------------

-- | Read the @i@-th 32-byte word of RAW returndata as an integer. When @signed@
-- is set, values in the top half of the 256-bit range are read as negative
-- two's-complement — this is exactly how the ABI sign-extends @int24@ (a
-- negative tick is sign-extended to 256 bits, e.g. @-199680@ =
-- @0xffff…fffcf400@).
--
-- This generalises the old @Panel.Variance.wordAt@ (which read @ASCII@-hex);
-- callers holding hex text convert once at the boundary via 'hexToBytes'.
-- A word index past the end of the blob reads as @0@ (an absent word), matching
-- the previous behaviour.
decodeWordAt :: Bool -> Int -> ByteString -> Integer
decodeWordAt signed i bs =
  let word = BS.take 32 (BS.drop (i * 32) bs)
      v    = bytesToInteger word
  in if signed && v >= twoPow255 then v - twoPow256 else v

-- | Split a single 32-byte return word into @(leftSlot, rightSlot)@ =
-- @(word `div` 2^128, word `mod` 2^128)@ per Panoptic's LeftRight packing.
--
-- Per RESEARCH ("LeftRight packing: right slot = currency0, left slot =
-- currency1"), the __right slot is currency0 (ETH)__ — the reconciliation
-- target. A swap here silently reconciles against USDC and fails the gate for
-- the wrong reason.
decodeUint128Pair :: Integer -> (Integer, Integer)
decodeUint128Pair word = (word `div` twoPow128, word `mod` twoPow128)

-- ---------------------------------------------------------------------------
-- Word-level encode
-- ---------------------------------------------------------------------------

-- | 32-byte big-endian encoding of an unsigned value (taken @mod 2^256@).
encodeWord :: Integer -> ByteString
encodeWord n0 = BS.pack (reverse (go (32 :: Int) (n0 `mod` twoPow256)))
  where
    go 0 _ = []
    go k n = fromIntegral (n `mod` 256) : go (k - 1) (n `div` 256)

-- | @uint256@ encoding — an alias for 'encodeWord'.
encodeUint256 :: Integer -> ByteString
encodeUint256 = encodeWord

-- | 32-byte big-endian two's-complement encoding of an @int24@. Haskell's
-- @`mod` 2^256@ (inside 'encodeWord') already yields the two's-complement
-- representation for negatives, so @encodeInt24 (-199680)@ has its leading 29
-- bytes @0xff@ (int24 is 3 bytes; the remaining 29 are sign extension).
encodeInt24 :: Int -> ByteString
encodeInt24 = encodeWord . fromIntegral

-- | 32-byte left-padded encoding of a @0x@-prefixed 20-byte address.
encodeAddress :: Text -> ByteString
encodeAddress = encodeWord . bytesToInteger . hexToBytes

-- | Encode a DYNAMIC @bytes@ argument, returning @(headSlotPlaceholder, tail)@.
--
-- The @getAccountPremium@ first argument is @bytes poolKey@, a dynamic type: its
-- HEAD slot holds a byte /offset/ into the tail, not the data itself. Getting
-- this wrong yields a silent revert or garbage. The tail is
-- @encodeUint256 (length bs) <> bs@ right-padded to a 32-byte multiple. The head
-- slot is returned as a zero placeholder; the calldata assembler (which alone
-- knows the total head size) substitutes the real offset.
encodeBytesDynamic :: ByteString -> (ByteString, ByteString)
encodeBytesDynamic bs = (encodeWord 0, tailEnc)
  where
    len     = fromIntegral (BS.length bs)
    padN    = (32 - (BS.length bs `mod` 32)) `mod` 32
    padded  = bs <> BS.replicate padN 0
    tailEnc = encodeUint256 len <> padded

-- ---------------------------------------------------------------------------
-- Solidity-faithful arithmetic
-- ---------------------------------------------------------------------------

-- | @unchecked@ modular subtraction: @diffMod n a b = (a - b) `mod` (2 ^ n)@,
-- always in @[0, 2^n)@. This is exactly Solidity's @unchecked@ semantics —
-- Haskell's 'mod' on 'Integer' returns a non-negative result for a positive
-- modulus, so no @if a >= b@ guard and no 'rem' (which can go negative).
--
-- RESEARCH Pitfall 3: a naive @a - b@ produces ~-1.15e77 instead of ~1e19
-- whenever the accumulator has wrapped. @n = 256@ for fee growth, @n = 128@ for
-- the X64 premium accumulators.
diffMod :: Int -> Integer -> Integer -> Integer
diffMod n a b = (a - b) `mod` (2 ^ n)

-- ---------------------------------------------------------------------------
-- Uniswap V4 fee-growth identity
-- ---------------------------------------------------------------------------

-- | The @feeGrowthInside@ three-branch identity (@Pool.sol@ L488-511), argument
-- order @tickCurrent tickLower tickUpper global lowerOutside upperOutside@:
--
-- @
--   tickCurrent <  tickLower  ->  lowerOutside - upperOutside
--   tickCurrent >= tickUpper  ->  upperOutside - lowerOutside
--   otherwise                 ->  global - lowerOutside - upperOutside
-- @
--
-- all @mod 2^256@ (via 'diffMod'), all non-negative. Note the asymmetric
-- boundary: @>=@ on the upper side, @<@ on the lower side — so
-- @tickCurrent == tickUpper@ takes the upper branch, not the middle.
--
-- RESEARCH "tick off-by-one trap": always use the STORED @slot0.tick@ (what the
-- @Swap@ event reports and what @Panel.Variance@ caches), never a re-derivation
-- from @sqrtPriceX96@, which can be one lower after a @zeroForOne@ crossing.
feeGrowthInside
  :: Int      -- ^ tickCurrent (stored slot0.tick)
  -> Int      -- ^ tickLower
  -> Int      -- ^ tickUpper
  -> Integer  -- ^ feeGrowthGlobal
  -> Integer  -- ^ lower tick feeGrowthOutside
  -> Integer  -- ^ upper tick feeGrowthOutside
  -> Integer
feeGrowthInside tickCurrent tickLower tickUpper global lowerOutside upperOutside
  | tickCurrent <  tickLower = diffMod 256 lowerOutside upperOutside
  | tickCurrent >= tickUpper = diffMod 256 upperOutside lowerOutside
  | otherwise                = (global - lowerOutside - upperOutside) `mod` twoPow256

-- ---------------------------------------------------------------------------
-- Hashing (Keccak-256, NOT SHA3-256)
-- ---------------------------------------------------------------------------

-- | Legacy Keccak-256 (Ethereum's hash), hex-encoded without a @0x@ prefix.
-- Uses @crypton@'s 'Keccak_256'; SHA3-256 differs in padding and would produce
-- silently-wrong selectors and topics.
keccak256Hex :: ByteString -> Text
keccak256Hex bs = TE.decodeUtf8 (convertToBase Base16 (hashWith Keccak_256 bs))

-- | 4-byte Solidity function selector: first 4 bytes of the Keccak-256 of the
-- UTF-8 canonical signature.
selector :: Text -> ByteString
selector sig = BS.take 4 (BA.convert (hashWith Keccak_256 (TE.encodeUtf8 sig)))

-- ---------------------------------------------------------------------------
-- Hex helpers
-- ---------------------------------------------------------------------------

-- | Decode a @0x@-prefixed (or bare) even-length hex string to raw bytes.
-- Invalid or odd-length input decodes to the empty 'ByteString'.
hexToBytes :: Text -> ByteString
hexToBytes t =
  case convertFromBase Base16 (TE.encodeUtf8 (stripHexPrefix t)) of
    Right b -> b
    Left _  -> BS.empty

-- | Lowercase hex encoding of raw bytes, WITHOUT a @0x@ prefix.
bytesToHex :: ByteString -> Text
bytesToHex = TE.decodeUtf8 . convertToBase Base16

-- | Big-endian interpretation of raw bytes as a non-negative 'Integer'.
bytesToInteger :: ByteString -> Integer
bytesToInteger = BS.foldl' (\acc w -> acc * 256 + fromIntegral w) 0

stripHexPrefix :: Text -> Text
stripHexPrefix t
  | "0x" `T.isPrefixOf` t = T.drop 2 t
  | "0X" `T.isPrefixOf` t = T.drop 2 t
  | otherwise             = t
