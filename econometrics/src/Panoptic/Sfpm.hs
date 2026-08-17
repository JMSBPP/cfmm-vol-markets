{-# LANGUAGE OverloadedStrings #-}

-- | @SFPM.getAccountPremium@ / @getAccountLiquidity@ calldata encoding and
-- returndata decoding — the premium READ itself. This module turns a
-- 'ChunkKey' into the exact @eth_call@ calldata the deployed
-- @SemiFungiblePositionManagerV4@ expects, and decodes its packed return into
-- the @(currency0, currency1)@ X64 accumulator pair.
--
-- == Three traps this module handles explicitly (RESEARCH \"Common Pitfalls\")
--
--   1. __@bytes poolKey@ is a DYNAMIC ABI argument.__ Its head slot holds a byte
--      /offset/ (@0x100@ = 8 head slots × 32) into the tail, not the data. The
--      poolKey bytes live in the tail after a length word. Getting this wrong is
--      the single most likely cause of a silent revert; the calldata-length and
--      first-head-slot assertions in 'Panoptic.SfpmSpec' exist to catch it.
--   2. __The selector is DERIVED from the signature string__, never a hardcoded
--      4-byte literal (a hardcoded selector is unverifiable and silently wrong if
--      a comma or type name is off).
--   3. __@getAccountPremium@ silently falls back to the stored accumulator when a
--      chunk's @netLiquidity == 0@__ (RESEARCH Pitfall 5) — indistinguishable
--      from \"no fees\" unless liquidity is recorded alongside. 'getAccountLiquidity'
--      is therefore NOT optional; the driver reads it beside every premium.
--
-- The poolKey encoding is proven byte-for-byte by a single check:
-- @keccak256 poolKeyBytes@ must equal the known poolId
-- @96d4b53a…288c0a@. If that fails, nothing downstream can be trusted and no
-- network call should be made.
module Panoptic.Sfpm
  ( -- * Constants
    sfpmAddress
  , panopticPoolAddress
  , vegoidConst
  , atTickSentinel
    -- * poolKey
  , poolKeyBytes
    -- * Calldata encoding
  , getAccountPremiumCalldata    -- ChunkKey -> Maybe Int {-atTick-} -> Bool {-isLong-} -> ByteString
  , getAccountLiquidityCalldata  -- ChunkKey -> ByteString
    -- * Returndata decoding
  , decodeAccountPremium         -- ByteString -> Either String (Integer, Integer)  -- (currency0, currency1)
  , decodeAccountLiquidity       -- ByteString -> Either String (Integer, Integer)  -- (removed, net)
    -- * Live reads (thread Chain.Rpc)
  , getAccountPremium            -- RpcEnv -> ChunkKey -> Maybe Int -> Bool -> BlockTag -> IO (Either String (Integer, Integer))
  , getAccountLiquidity          -- RpcEnv -> ChunkKey -> BlockTag -> IO (Either String (Integer, Integer))
  ) where

import           Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import           Data.Text (Text)

import           Chain.Abi (decodeUint128Pair, decodeWordAt, encodeAddress,
                            encodeInt24, encodeUint256, encodeWord, selector)
import           Chain.Rpc (BlockTag, RpcEnv, ethCall)
import           Panoptic.Chunk (ChunkKey (..))

-- ---------------------------------------------------------------------------
-- Constants (RESEARCH \"Route B\" table; verified live 2026-07-20)
-- ---------------------------------------------------------------------------

-- | Base V4 SemiFungiblePositionManagerV4 (chainId 8453). The @to@ of every
-- premium/liquidity @eth_call@.
sfpmAddress :: Text
sfpmAddress = "0x8dcAa08cF298F8b4830FAf56d47930981AdE33af"

-- | The PanopticPool — the @owner@ argument in every chunk positionKey. Chunks
-- are POOL-WIDE (not per-user), so this address is shared across all positions.
panopticPoolAddress :: Text
panopticPoolAddress = "0xb50e8bb68f5855da742f4579274902a20454174a"

-- | @RiskEngine.VEGOID = 8@ ⇒ ν = 1/8 = 0.125, the utilization-spread parameter.
vegoidConst :: Integer
vegoidConst = 8

-- | @type(int24).max@. As @atTick@ it tells @getAccountPremium@ to return the
-- STORED accumulator (no live @feeGrowthInside@ extrapolation).
atTickSentinel :: Int
atTickSentinel = 8388607

-- | @getAccountPremium(bytes,address,uint256,int24,int24,int24,uint256,uint256)@.
premiumSig :: Text
premiumSig = "getAccountPremium(bytes,address,uint256,int24,int24,int24,uint256,uint256)"

-- | @getAccountLiquidity(bytes,address,uint256,int24,int24)@.
liquiditySig :: Text
liquiditySig = "getAccountLiquidity(bytes,address,uint256,int24,int24)"

-- ---------------------------------------------------------------------------
-- poolKey
-- ---------------------------------------------------------------------------

-- | The 160-byte @abi.encode(PoolKey{...})@ for the target market — five 32-byte
-- words:
--
--   * @currency0@ = @0x0@ (native ETH)
--   * @currency1@ = @0x833589fc…2913@ (USDC)
--   * @fee@ = @500@
--   * @tickSpacing@ = @10@ (int24)
--   * @hooks@ = @0x0@
--
-- @keccak256 poolKeyBytes@ MUST equal the known poolId
-- @96d4b53a38337a5733179751781178a2613306063c511b78cd02684739288c0a@ (asserted
-- in 'Panoptic.SfpmSpec'). That single identity validates the entire encoding
-- byte-for-byte.
poolKeyBytes :: ByteString
poolKeyBytes =
       encodeWord 0                                              -- currency0 = native ETH (address 0)
    <> encodeAddress "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913" -- currency1 = USDC
    <> encodeUint256 500                                         -- fee
    <> encodeInt24 10                                            -- tickSpacing (int24)
    <> encodeWord 0                                              -- hooks = address 0

-- ---------------------------------------------------------------------------
-- Calldata encoding
-- ---------------------------------------------------------------------------

-- | @getAccountPremium@ calldata for a chunk. Layout:
--
--   * selector (4 bytes) — DERIVED from 'premiumSig', never hardcoded.
--   * 8 head slots, in signature order:
--     @[offsetToTail, owner, tokenType, tickLower, tickUpper, atTick, isLong, vegoid]@.
--     Slot 0 is the @bytes poolKey@ DYNAMIC head: it carries the byte offset
--     @0x100@ (= 8 × 32), NOT the data.
--   * dynamic tail: a 32-byte length word (@160@) followed by 'poolKeyBytes'.
--
-- Total: @4 + 8*32 + 32 + 160 = 452@ bytes.
--
-- @atTick = Nothing@ encodes 'atTickSentinel' (stored value); @Just t@ encodes
-- @t@ (live extrapolation). @isLong = False → 0@ (gross/short), @True → 1@
-- (owed/long).
getAccountPremiumCalldata :: ChunkKey -> Maybe Int -> Bool -> ByteString
getAccountPremiumCalldata ck atTick isLong =
       selector premiumSig
    <> encodeUint256 headBytes                          -- slot 0: offset to dynamic tail (0x100)
    <> encodeAddress panopticPoolAddress                -- slot 1: owner
    <> encodeUint256 (fromIntegral (ckTokenType ck))    -- slot 2: tokenType
    <> encodeInt24 (ckTickLower ck)                     -- slot 3: tickLower
    <> encodeInt24 (ckTickUpper ck)                     -- slot 4: tickUpper
    <> encodeInt24 (maybe atTickSentinel id atTick)     -- slot 5: atTick (sentinel when Nothing)
    <> encodeUint256 (if isLong then 1 else 0)          -- slot 6: isLong
    <> encodeUint256 vegoidConst                        -- slot 7: vegoid
    <> encodeUint256 (fromIntegral (BS.length poolKeyBytes)) -- tail: length word (160)
    <> poolKeyBytes                                     -- tail: the poolKey data
  where
    headBytes = 8 * 32 :: Integer   -- 256 = 0x100

-- | @getAccountLiquidity@ calldata for a chunk (no @atTick@/@isLong@/@vegoid@ —
-- liquidity is a stored value). Five head slots
-- @[offsetToTail, owner, tokenType, tickLower, tickUpper]@ with the dynamic
-- @bytes poolKey@ tail; offset is @5 × 32 = 160 = 0xa0@.
getAccountLiquidityCalldata :: ChunkKey -> ByteString
getAccountLiquidityCalldata ck =
       selector liquiditySig
    <> encodeUint256 headBytes                          -- slot 0: offset to dynamic tail (0xa0)
    <> encodeAddress panopticPoolAddress                -- slot 1: owner
    <> encodeUint256 (fromIntegral (ckTokenType ck))    -- slot 2: tokenType
    <> encodeInt24 (ckTickLower ck)                     -- slot 3: tickLower
    <> encodeInt24 (ckTickUpper ck)                     -- slot 4: tickUpper
    <> encodeUint256 (fromIntegral (BS.length poolKeyBytes)) -- tail: length word (160)
    <> poolKeyBytes                                     -- tail: the poolKey data
  where
    headBytes = 5 * 32 :: Integer   -- 160 = 0xa0

-- ---------------------------------------------------------------------------
-- Returndata decoding
-- ---------------------------------------------------------------------------

-- | Decode @getAccountPremium@ returndata into @(currency0, currency1)@ X64
-- accumulators. __Decodes defensively on the returndata length__:
--
--   * @>= 64@ bytes: the ABI form for two @uint128@ returns — two right-aligned
--     32-byte words @[premium0X64, premium1X64]@ = @(currency0, currency1)@.
--   * @>= 32@ bytes: a single LeftRight-packed word — RIGHT slot (low 128 bits)
--     is currency0 (ETH, the reconciliation target), LEFT is currency1. This is
--     the shape of the frozen golden fixture.
--   * shorter (incl. empty @0x@): 'Left' — a short/absent return is never decoded
--     as a spurious zero (RESEARCH \"fail loudly on RPC nulls\").
decodeAccountPremium :: ByteString -> Either String (Integer, Integer)
decodeAccountPremium bs
  | BS.length bs >= 64 =
      Right (decodeWordAt False 0 bs, decodeWordAt False 1 bs)
  | BS.length bs >= 32 =
      let (cur1, cur0) = decodeUint128Pair (decodeWordAt False 0 bs)
      in Right (cur0, cur1)
  | otherwise =
      Left "decodeAccountPremium: short returndata (< 32 bytes), refusing to decode as zero"

-- | Decode @getAccountLiquidity@ returndata into @(removedLiquidity,
-- netLiquidity)@. The SFPM packs this as a single LeftRight word: LEFT slot =
-- removed, RIGHT slot = net. A short/absent return is 'Left', never a decoded
-- zero — the @netLiquidity == 0@ vs \"no fees\" disambiguation (RESEARCH Pitfall
-- 5) depends on this read being trustworthy.
decodeAccountLiquidity :: ByteString -> Either String (Integer, Integer)
decodeAccountLiquidity bs
  | BS.length bs >= 32 =
      let (removed, net) = decodeUint128Pair (decodeWordAt False 0 bs)
      in Right (removed, net)
  | otherwise =
      Left "decodeAccountLiquidity: short returndata (< 32 bytes), refusing to decode as zero"

-- ---------------------------------------------------------------------------
-- Live reads
-- ---------------------------------------------------------------------------

-- | Issue @getAccountPremium@ against 'sfpmAddress' at a block tag and decode the
-- return, threading 'Chain.Rpc.ethCall''s fail-loud 'Either'.
getAccountPremium
  :: RpcEnv -> ChunkKey -> Maybe Int -> Bool -> BlockTag
  -> IO (Either String (Integer, Integer))
getAccountPremium env ck atTick isLong tag = do
  r <- ethCall env sfpmAddress (getAccountPremiumCalldata ck atTick isLong) tag
  pure (r >>= decodeAccountPremium)

-- | Issue @getAccountLiquidity@ against 'sfpmAddress' at a block tag and decode
-- the return.
getAccountLiquidity
  :: RpcEnv -> ChunkKey -> BlockTag
  -> IO (Either String (Integer, Integer))
getAccountLiquidity env ck tag = do
  r <- ethCall env sfpmAddress (getAccountLiquidityCalldata ck) tag
  pure (r >>= decodeAccountLiquidity)
