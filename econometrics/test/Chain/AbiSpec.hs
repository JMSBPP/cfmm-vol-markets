{-# LANGUAGE OverloadedStrings #-}

-- | Offline specs for "Chain.Abi": the ABI codec, two's-complement sign
-- extension, @unchecked@ wraparound ('diffMod'), the three-branch
-- 'feeGrowthInside' identity, and Keccak-256 (proven distinct from SHA3-256 via
-- a known Ethereum topic hash). No network access.
--
-- @describe@ titles are chosen so the validation map's @--ta -m@ filters select
-- them: @"Chain.Abi"@, @"wraparound"@, @"feeGrowthInside"@.
module Chain.AbiSpec (spec) where

import qualified Data.ByteString as BS
import           Test.Hspec

import           Chain.Abi

spec :: Spec
spec = do
  describe "Chain.Abi" $ do
    describe "sign extension (int24)" $ do
      it "decodeWordAt True round-trips encodeInt24 over the int24 range + real ticks" $
        let ticks = [-887272, -200423, -199680, -1, 0, 1, 199680, 887272]
        in mapM_
             (\t -> decodeWordAt True 0 (encodeInt24 t) `shouldBe` fromIntegral t)
             ticks

      it "encodeInt24 (-199680) is a 32-byte word whose leading 29 bytes are 0xff" $ do
        let w = encodeInt24 (-199680)
        BS.length w `shouldBe` 32
        BS.unpack (BS.take 29 w) `shouldBe` replicate 29 0xff
        -- int24 two's-complement of -199680 = 0xfcf400
        BS.unpack (BS.drop 29 w) `shouldBe` [0xfc, 0xf4, 0x00]

      it "decodeWordAt False reads an unsigned top-half word as a large positive" $ do
        -- a 32-byte word of 0xff.. is 2^256 - 1 unsigned, but -1 signed
        let w = encodeInt24 (-1)
        decodeWordAt False 0 w `shouldBe` (2 ^ (256 :: Int) - 1)
        decodeWordAt True  0 w `shouldBe` (-1)

    describe "uint128 LeftRight split" $
      it "decodeUint128Pair puts currency0 in the right slot, currency1 in the left" $ do
        let left  = 0x40929eb1367967c87b  -- currency1 (high 128 bits)
            right = 0x3cac79361af8320491  -- currency0 (low 128 bits)
            word  = left * (2 ^ (128 :: Int)) + right
        decodeUint128Pair word `shouldBe` (left, right)

    describe "dynamic bytes encoding" $
      it "encodeBytesDynamic tail is a 32-byte length word followed by padded data" $ do
        let bs = BS.pack [0xde, 0xad, 0xbe, 0xef]
            (_headPlaceholder, tl) = encodeBytesDynamic bs
        -- length word (32) + one padded 32-byte data slot
        BS.length tl `shouldBe` 64
        decodeWordAt False 0 tl `shouldBe` 4
        BS.unpack (BS.take 4 (BS.drop 32 tl)) `shouldBe` [0xde, 0xad, 0xbe, 0xef]

    describe "keccak256 (Keccak, NOT SHA3-256)" $ do
      it "keccak256Hex of the Transfer signature is the known Ethereum topic" $
        keccak256Hex "Transfer(address,address,uint256)"
          `shouldBe` "ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

      it "keccak256Hex of the empty string is the known Keccak-256 vector" $
        keccak256Hex ""
          `shouldBe` "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"

      it "keccak256Hex of the V4 Swap signature equals Panel.Variance.v4SwapTopic0" $
        keccak256Hex "Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)"
          `shouldBe` "40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f"

      it "selector is 4 bytes and stable across runs" $ do
        let s = selector "getAccountPremium(bytes,address,uint256,int24,int24,int24,uint256,uint256)"
        BS.length s `shouldBe` 4
        selector "getAccountPremium(bytes,address,uint256,int24,int24,int24,uint256,uint256)"
          `shouldBe` s

    describe "hex round-trip" $
      it "bytesToHex . hexToBytes is identity on a 0x word" $
        bytesToHex (hexToBytes "0x3cac79361af8320491")
          `shouldBe` "3cac79361af8320491"

  describe "wraparound" $ do
    it "diffMod 128 is ordinary subtraction when no wrap occurs" $
      diffMod 128 100 40 `shouldBe` 60

    it "diffMod 128 wraps: (5 - (2^128 - 3)) mod 2^128 == 8, never negative" $ do
      let d = diffMod 128 5 (2 ^ (128 :: Int) - 3)
      d `shouldBe` 8
      d `shouldSatisfy` (>= 0)

    it "diffMod 128 result is always in [0, 2^128)" $
      mapM_
        (\(a, b) -> diffMod 128 a b `shouldSatisfy` (\x -> x >= 0 && x < 2 ^ (128 :: Int)))
        [(0, 1), (1, 0), (7, 7), (0, 2 ^ (128 :: Int) - 1), (2 ^ (128 :: Int) - 1, 0)]

    it "diffMod 256 wraps identically at the 2^256 modulus" $ do
      let d = diffMod 256 5 (2 ^ (256 :: Int) - 3)
      d `shouldBe` 8
      d `shouldSatisfy` (\x -> x >= 0 && x < 2 ^ (256 :: Int))

  describe "feeGrowthInside" $ do
    -- Synthetic outside/global levels chosen so each branch has a distinct,
    -- hand-checkable value; all three must be non-negative.
    let global = 1000
        lower  = 200
        upper  = 150
    it "tickCurrent < tickLower : lowerOutside - upperOutside" $
      feeGrowthInside (-10) 0 100 global lower upper
        `shouldBe` diffMod 256 lower upper

    it "tickCurrent >= tickUpper : upperOutside - lowerOutside" $
      feeGrowthInside 200 0 100 global lower upper
        `shouldBe` diffMod 256 upper lower

    it "tickLower <= tickCurrent < tickUpper : global - lower - upper" $
      feeGrowthInside 50 0 100 global lower upper
        `shouldBe` (global - lower - upper) `mod` (2 ^ (256 :: Int))

    it "at the exact upper boundary tickCurrent == tickUpper takes the >= branch" $
      feeGrowthInside 100 0 100 global lower upper
        `shouldBe` diffMod 256 upper lower

    it "every branch is non-negative even when outside levels have wrapped" $ do
      let hi = 2 ^ (256 :: Int) - 5
      feeGrowthInside (-1) 0 100 global 3 hi `shouldSatisfy` (>= 0)  -- lower branch, wraps
      feeGrowthInside 200  0 100 global 3 hi `shouldSatisfy` (>= 0)  -- upper branch
